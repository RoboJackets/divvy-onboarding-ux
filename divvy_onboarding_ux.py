"""
Overengineered web form to facilitate onboarding users to Divvy
"""

from re import fullmatch
from typing import Any, Dict

from authlib.integrations.flask_client import OAuth  # type: ignore

from flask import Flask, Response, redirect, render_template, request, session, url_for

from ldap3 import Connection, Server

from requests import get, post

from werkzeug.exceptions import InternalServerError, Unauthorized

app = Flask(__name__)
app.config.from_prefixed_env()

oauth = OAuth(app)
oauth.register(
    name="keycloak",
    server_metadata_url=app.config["KEYCLOAK_METADATA_URL"],
    client_kwargs={"scope": "openid email profile"},
)
oauth.register(
    name="google",
    server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
    client_kwargs={"scope": "openid email"},
)
oauth.register(
    name="microsoft",
    server_metadata_url=app.config["MICROSOFT_METADATA_URL"],
    client_kwargs={"scope": "openid email"},
)

states = {
    "AK": "Alaska",
    "AL": "Alabama",
    "AR": "Arkansas",
    "AZ": "Arizona",
    "CA": "California",
    "CO": "Colorado",
    "CT": "Connecticut",
    "DC": "District of Columbia",
    "DE": "Delaware",
    "FL": "Florida",
    "GA": "Georgia",
    "HI": "Hawaii",
    "IA": "Iowa",
    "ID": "Idaho",
    "IL": "Illinois",
    "IN": "Indiana",
    "KS": "Kansas",
    "KY": "Kentucky",
    "LA": "Louisiana",
    "MA": "Massachusetts",
    "MD": "Maryland",
    "ME": "Maine",
    "MI": "Michigan",
    "MN": "Minnesota",
    "MO": "Missouri",
    "MS": "Mississippi",
    "MT": "Montana",
    "NC": "North Carolina",
    "ND": "North Dakota",
    "NE": "Nebraska",
    "NH": "New Hampshire",
    "NJ": "New Jersey",
    "NM": "New Mexico",
    "NV": "Nevada",
    "NY": "New York",
    "OH": "Ohio",
    "OK": "Oklahoma",
    "OR": "Oregon",
    "PA": "Pennsylvania",
    "RI": "Rhode Island",
    "SC": "South Carolina",
    "SD": "South Dakota",
    "TN": "Tennessee",
    "TX": "Texas",
    "UT": "Utah",
    "VA": "Virginia",
    "VT": "Vermont",
    "WA": "Washington",
    "WI": "Wisconsin",
    "WV": "West Virginia",
    "WY": "Wyoming",
}


@app.get("/")
def index() -> Any:
    """
    Generates the main form or messaging if the user shouldn't fill it out
    """
    if "state" not in session:
        return oauth.keycloak.authorize_redirect(url_for("login", _external=True))

    if session["state"] == "provisioned":
        session.clear()
        return render_template("provisioned.html")

    if session["state"] == "ineligible":
        session.clear()
        return render_template("ineligible.html")

    if session["state"] == "requested":
        return render_template("submitted.html")

    email_provider = None
    email_ready_to_verify = False

    if session["email_address"].endswith("@gatech.edu"):
        email_provider = "microsoft"
        email_ready_to_verify = True
    elif session["email_address"].endswith("@robojackets.org"):
        email_provider = "google"
        email_ready_to_verify = True

    apiary_managers_response = get(
        url=app.config["APIARY_URL"] + "/api/v1/users/managers",
        headers={
            "Authorization": "Bearer " + app.config["APIARY_TOKEN"],
            "Accept": "application/json",
        },
        timeout=(5, 5),
    )

    managers = {}

    if apiary_managers_response.status_code == 200:
        apiary_managers_json = apiary_managers_response.json()

        for manager in apiary_managers_json["users"]:
            managers[manager["id"]] = manager["full_name"]
    else:
        raise InternalServerError("Unable to load managers from Apiary")

    return render_template(
        "form.html",
        first_name=session["first_name"],
        last_name=session["last_name"],
        email_address=session["email_address"],
        email_provider=email_provider,
        email_verified=session["email_verified"],
        email_ready_to_verify=email_ready_to_verify,
        manager_id=session["manager_id"],
        managers=dict(sorted(managers.items(), key=lambda item: item[1])),  # type: ignore
        order_physical_card=session["order_physical_card"],
        shipping_option=session["shipping_option"],
        address_line_one=session["address_line_one"],
        address_line_two=session["address_line_two"],
        state=session["state"],
        city=session["city"],
        zip_code=session["zip_code"],
        states=states,
        google_maps_api_key=app.config["GOOGLE_MAPS_API_KEY"],
    )


@app.get("/login")
def login() -> Any:  # pylint: disable=too-many-branches,too-many-statements
    """
    Handles the return from Keycloak and collects default values for the form
    """
    token = oauth.keycloak.authorize_access_token()

    userinfo = token["userinfo"]

    username = userinfo["preferred_username"]
    session["first_name"] = userinfo["given_name"]
    session["last_name"] = userinfo["family_name"]
    session["order_physical_card"] = True
    session["shipping_option"] = "standard"
    session["address_line_one"] = ""
    session["address_line_two"] = ""
    session["city"] = ""
    session["state"] = None
    session["zip_code"] = ""

    if "googleWorkspaceAccount" in userinfo:
        session["email_address"] = userinfo["googleWorkspaceAccount"]
        session["email_verified"] = False
    else:
        session["email_address"] = userinfo["email"]
        session["email_verified"] = False

    if "roles" in userinfo:
        if "provisioned" in userinfo["roles"]:
            session["state"] = "provisioned"
        elif "eligible" in userinfo["roles"]:
            session["state"] = "eligible"
        else:
            session["state"] = "ineligible"
    else:
        session["state"] = "ineligible"

    if session["state"] == "ineligible" or session["state"] == "eligible":
        apiary_user_response = get(
            url=app.config["APIARY_URL"] + "/api/v1/users/" + username,
            headers={
                "Authorization": "Bearer " + app.config["APIARY_TOKEN"],
                "Accept": "application/json",
            },
            params={"include": "roles,teams"},
            timeout=(5, 5),
        )

        if apiary_user_response.status_code == 200:
            apiary_user = apiary_user_response.json()["user"]

            role_check = False

            for role in apiary_user["roles"]:
                if role["name"] != "member" and role["name"] != "non-member":
                    role_check = True

            if (
                apiary_user["is_active"]
                and apiary_user["is_access_active"]
                and apiary_user["signed_latest_agreement"]
                and len(apiary_user["teams"]) > 0
                and role_check
            ):
                session["state"] = "eligible"

                if "manager" in apiary_user and apiary_user["manager"] is not None:
                    session["manager_id"] = apiary_user["manager"]["id"]
                else:
                    session["manager_id"] = None

    if session["state"] == "eligible":  # pylint: disable=too-many-nested-blocks
        ldap = Connection(
            Server("whitepages.gatech.edu"),
            auto_bind=True,  # type: ignore
        )
        result = ldap.search(
            search_base="dc=whitepages,dc=gatech,dc=edu",
            search_filter="(uid=" + username + ")",
            attributes=["postOfficeBox", "homePostalAddress"],
        )

        georgia_tech_mailbox = None
        home_address = None

        if result is True:
            for entry in ldap.entries:
                if "postOfficeBox" in entry:
                    georgia_tech_mailbox = entry["postOfficeBox"]
                if (
                    "homePostalAddress" in entry
                    and entry["homePostalAddress"] != "UNPUBLISHED INFO"
                ):
                    home_address = entry["homePostalAddress"]

        if georgia_tech_mailbox is not None and georgia_tech_mailbox.value is not None:
            session["address_line_one"] = "351 Ferst Dr NW"
            session["address_line_two"] = georgia_tech_mailbox.value.split(",")[0]
            session["city"] = "Atlanta"
            session["state"] = "GA"
            session["zip_code"] = "30332"
        elif home_address is not None and home_address.value is not None:
            address_string = home_address.value

            address_validation_response = post(
                url="https://addressvalidation.googleapis.com/v1:validateAddress",
                params={"key": app.config["GOOGLE_MAPS_API_KEY"]},
                json={
                    "address": {
                        "regionCode": "US",
                        "addressLines": [address_string],
                    },
                    "enableUspsCass": True,
                },
                timeout=(5, 5),
            )

            if address_validation_response.status_code == 200:
                address_validation_json = address_validation_response.json()

                session["address_line_one"] = ""
                session["address_line_two"] = ""
                session["city"] = ""
                session["state"] = None

                if (
                    "result" in address_validation_json
                    and "address" in address_validation_json["result"]
                    and "postalAddress" in address_validation_json["result"]["address"]
                ):

                    if (
                        "postalCode"
                        in address_validation_json["result"]["address"]["postalAddress"]
                    ):
                        session["zip_code"] = address_validation_json["result"]["address"][
                            "postalAddress"
                        ]["postalCode"]

                        if fullmatch(r"^\d{5}-\d{4}$", session["zip_code"]):
                            session["zip_code"] = session["zip_code"].split("-")[0]

                    if "locality" in address_validation_json["result"]["address"]["postalAddress"]:
                        session["city"] = address_validation_json["result"]["address"][
                            "postalAddress"
                        ]["locality"]

                    if (
                        "administrativeArea"
                        in address_validation_json["result"]["address"]["postalAddress"]
                    ):
                        session["state"] = address_validation_json["result"]["address"][
                            "postalAddress"
                        ]["administrativeArea"]

                    if (
                        "addressLines"
                        in address_validation_json["result"]["address"]["postalAddress"]
                        and len(
                            address_validation_json["result"]["address"]["postalAddress"][
                                "addressLines"
                            ]
                        )
                        > 0
                    ):
                        session["address_line_one"] = address_validation_json["result"]["address"][
                            "postalAddress"
                        ]["addressLines"][0]

                    if (
                        "addressLines"
                        in address_validation_json["result"]["address"]["postalAddress"]
                        and len(
                            address_validation_json["result"]["address"]["postalAddress"][
                                "addressLines"
                            ]
                        )
                        > 1
                    ):
                        session["address_line_two"] = address_validation_json["result"]["address"][
                            "postalAddress"
                        ]["addressLines"][1]

    return redirect(url_for("index"))


@app.get("/verify-email/google")
def verify_google_redirect() -> Any:
    """
    Redirects user to Google for email address verification
    """
    if "state" not in session:
        raise Unauthorized("Not logged in")

    if session["state"] != "eligible":
        raise Unauthorized("Not eligible")

    return oauth.google.authorize_redirect(
        url_for("verify_google_complete", _external=True),
        login_hint=session["email_address"],
        hd="robojackets.org",
    )


@app.get("/verify-email/google/complete")
def verify_google_complete() -> Response:
    """
    Handles the return from Google and updates session appropriately
    """
    token = oauth.google.authorize_access_token()

    userinfo = token["userinfo"]

    session["email_address"] = userinfo["email"]
    session["email_verified"] = True

    return redirect(url_for("index"))


@app.get("/verify-email/microsoft")
def verify_microsoft_redirect() -> Any:
    """
    Redirects user to Microsoft for email address verification
    """
    if "state" not in session:
        raise Unauthorized("Not logged in")

    if session["state"] != "eligible":
        raise Unauthorized("Not eligible")

    return oauth.microsoft.authorize_redirect(
        url_for("verify_microsoft_complete", _external=True),
        login_hint=session["email_address"],
        hd="gatech.edu",
    )


@app.get("/verify-email/microsoft/complete")
def verify_microsoft_complete() -> Response:
    """
    Handles the return from Google and updates session appropriately
    """
    token = oauth.microsoft.authorize_access_token()

    userinfo = token["userinfo"]

    session["email_address"] = userinfo["email"]
    session["email_verified"] = True

    return redirect(url_for("index"))


@app.post("/api/save")
def save_draft() -> Dict[str, str]:
    """
    Save a draft of the form (triggered on field change)
    """
    if "state" not in session:
        raise Unauthorized("Not logged in")

    if session["state"] != "eligible":
        raise Unauthorized("Not eligible")

    session["first_name"] = request.json["first_name"]  # type: ignore
    session["last_name"] = request.json["last_name"]  # type: ignore
    session["email_address"] = request.json["email_address"]  # type: ignore
    session["manager_id"] = None if request.json["manager"] == "" else int(request.json["manager"])  # type: ignore  # noqa: E501
    session["order_physical_card"] = request.json["order_physical_card"]  # type: ignore
    session["shipping_option"] = request.json["shipping_option"]  # type: ignore
    session["address_line_one"] = request.json["address_line_one"]  # type: ignore
    session["address_line_two"] = request.json["address_line_two"]  # type: ignore
    session["city"] = request.json["city"]  # type: ignore
    session["state"] = request.json["state"]  # type: ignore
    session["zip_code"] = request.json["zip_code"]  # type: ignore
    return {"status": "ok"}


@app.post("/")
def submit() -> Response:
    """
    Submits the form for fulfillment
    """
    if "state" not in session:
        raise Unauthorized("Not logged in")

    if session["state"] != "eligible":
        raise Unauthorized("Not eligible")

    manager = None
    manager_email = None

    manager_response = get(
        url=app.config["APIARY_URL"] + "/api/v1/users/" + request.form["manager"],
        headers={
            "Authorization": "Bearer " + app.config["APIARY_TOKEN"],
            "Accept": "application/json",
        },
        timeout=(5, 5),
    )

    if manager_response.status_code == 200:
        manager = manager_response.json()["user"]

        if (
            "gmail_address" in manager
            and manager["gmail_address"] is not None
            and manager["gmail_address"].endswith("@robojackets.org")
        ):
            manager_email = manager["full_name"] + " <" + manager["gmail_address"] + ">"
        else:
            manager_email = manager["full_name"] + " < " + manager["gt_email"] + ">"

    physical_card_details = "\nPhysical Card: " + (
        "Yes" if "order_physical_card" in request.form else "No"
    )

    if "order_physical_card" in request.form:
        physical_card_details += (
            "\nShipping Method: " + request.form["shipping_option"].capitalize()
        )
        physical_card_details += "\nAddress:\n" + request.form["address_line_one"]
        if request.form["address_line_two"] != "":
            physical_card_details += "\n" + request.form["address_line_two"]
        physical_card_details += (
            "\n"
            + request.form["city"]
            + ", "
            + request.form["state"]
            + " "
            + request.form["zip_code"]
        )

    postmark_response = post(
        url="https://api.postmarkapp.com/email",
        headers={"X-Postmark-Server-Token": app.config["POSTMARK_TOKEN"]},
        json={
            "From": app.config["POSTMARK_FROM"],
            "To": app.config["POSTMARK_TO_FULFILLMENT"],
            "Cc": request.form["first_name"]
            + " "
            + request.form["last_name"]
            + "<"
            + request.form["email_address"]
            + ">, "
            + app.config["POSTMARK_TO_TREASURER"]
            + (", " + manager_email if manager_email is not None else ""),
            "Subject": request.form["first_name"]
            + " "
            + request.form["last_name"]
            + " requested a Divvy account",
            "TextBody": "Please review the below information and reply-all if it is not correct.\n\nFirst Name: "  # noqa: E501
            + request.form["first_name"]
            + "\nLast Name: "
            + request.form["last_name"]
            + "\nEmail Address: "
            + request.form["email_address"]
            + (
                "\nManager: " + manager["full_name"]
                if manager is not None
                else "\nManager ID: " + request.form["manager"]
            )
            + physical_card_details,
            "MessageStream": "outbound",
        },
        timeout=(5, 5),
    )

    if postmark_response.status_code == 200:
        session["state"] = "requested"
        return render_template("submitted.html")

    raise InternalServerError(
        "Postmark returned unexpected response code " + str(postmark_response.status_code)
    )


@app.get("/ping")
def ping() -> Dict[str, str]:
    return {"status": "ok"}
