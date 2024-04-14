"""
Overengineered web form to facilitate onboarding users to BILL Spend & Expense
"""

from datetime import datetime, timezone
from email.headerregistry import Address
from re import fullmatch
from typing import Any, Dict, Union

from authlib.integrations.flask_client import OAuth  # type: ignore

from flask import Flask, Response, redirect, render_template, request, session, url_for
from flask.helpers import get_debug_flag

from google.auth.transport import requests  # type: ignore
from google.oauth2 import id_token  # type: ignore

from ldap3 import Connection, Server

from requests import delete, get, post

import sentry_sdk
from sentry_sdk import capture_message, set_user
from sentry_sdk.integrations.flask import FlaskIntegration
from sentry_sdk.integrations.pure_eval import PureEvalIntegration

from werkzeug.exceptions import BadRequest, InternalServerError, Unauthorized


def traces_sampler(sampling_context: Dict[str, Dict[str, str]]) -> bool:
    """
    Ignore ping events, sample all other events
    """
    try:
        request_uri = sampling_context["wsgi_environ"]["REQUEST_URI"]
    except KeyError:
        return False

    return request_uri != "/ping"


sentry_sdk.init(
    debug=get_debug_flag(),
    integrations=[
        FlaskIntegration(),
        PureEvalIntegration(),
    ],
    traces_sampler=traces_sampler,
    attach_stacktrace=True,
    max_request_body_size="always",
    in_app_include=[
        "divvy_onboarding_ux",
    ],
    _experiments={
        "profiles_sample_rate": 1.0,
    },
)

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


@app.get("/")
def index() -> Any:
    """
    Generates the main form or messaging if the user shouldn't fill it out
    """
    if "user_state" not in session:
        return oauth.keycloak.authorize_redirect(url_for("login", _external=True))

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )

    if session["user_state"] == "provisioned":
        session.clear()
        return render_template("provisioned.html")

    if session["user_state"] == "ineligible":
        session.clear()
        return render_template("ineligible.html")

    if session["user_state"] == "requested":
        return render_template("submitted.html")

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
        elm_model={
            "firstName": session["first_name"],
            "lastName": session["last_name"],
            "emailAddress": session["email_address"],
            "emailVerified": session["email_verified"],
            "managerId": session["manager_id"],
            "managerOptions": managers,
            "selfId": session["user_id"],
            "addressLineOne": session["address_line_one"],
            "addressLineTwo": session["address_line_two"],
            "city": session["city"],
            "state": session["address_state"],
            "zip": session["zip_code"],
            "googleMapsApiKey": app.config["GOOGLE_MAPS_FRONTEND_API_KEY"],
            "googleClientId": app.config["GOOGLE_CLIENT_ID"],
            "googleOneTapLoginUri": url_for("verify_google_onetap", _external=True),
        },
    )


@app.get("/login")
def login() -> Any:  # pylint: disable=too-many-branches,too-many-statements,too-many-locals
    """
    Handles the return from Keycloak and collects default values for the form
    """
    token = oauth.keycloak.authorize_access_token()

    userinfo = token["userinfo"]

    username = userinfo["preferred_username"]
    session["user_id"] = None
    session["username"] = username
    session["first_name"] = userinfo["given_name"]
    session["last_name"] = userinfo["family_name"]
    session["address_line_one"] = ""
    session["address_line_two"] = ""
    session["city"] = ""
    session["address_state"] = None
    session["zip_code"] = ""
    session["manager_id"] = None
    session["sub"] = userinfo["sub"]

    if "googleWorkspaceAccount" in userinfo:
        session["email_address"] = userinfo["googleWorkspaceAccount"]
        session["email_verified"] = False
    else:
        session["email_address"] = userinfo["email"]
        session["email_verified"] = False

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )

    if "roles" in userinfo:
        if "provisioned" in userinfo["roles"]:
            session["user_state"] = "provisioned"
        elif "eligible" in userinfo["roles"]:
            session["user_state"] = "eligible"
        else:
            session["user_state"] = "ineligible"
    else:
        session["user_state"] = "ineligible"

    if session["user_state"] == "ineligible" or session["user_state"] == "eligible":
        apiary_user_response = get(
            url=app.config["APIARY_URL"] + "/api/v1/users/" + username,
            headers={
                "Authorization": "Bearer " + app.config["APIARY_TOKEN"],
                "Accept": "application/json",
            },
            params={"include": "roles,teams,assignments.travel"},
            timeout=(5, 5),
        )

        if apiary_user_response.status_code == 200:
            apiary_user = apiary_user_response.json()["user"]

            session["user_id"] = apiary_user["id"]

            set_user(
                {
                    "id": session["user_id"],
                    "username": session["username"],
                    "email": session["email_address"],
                    "ip_address": request.remote_addr,
                }
            )

            role_check = False

            if "roles" in apiary_user and apiary_user["roles"] is not None:
                for role in apiary_user["roles"]:
                    if role["name"] != "member" and role["name"] != "non-member":
                        role_check = True

            travel_check = False

            if "travel" in apiary_user and apiary_user["travel"] is not None:
                for travel in apiary_user["travel"]:
                    if datetime.now(timezone.utc) < datetime.fromisoformat(
                        travel["travel"]["return_date"]
                    ):
                        travel_check = True

            if (
                apiary_user["is_active"]  # pylint: disable=too-many-boolean-expressions
                and apiary_user["is_access_active"]
                and apiary_user["signed_latest_agreement"]
                and len(apiary_user["teams"]) > 0
                and (role_check or travel_check)
            ):
                session["user_state"] = "eligible"

            if "manager" in apiary_user and apiary_user["manager"] is not None:
                session["manager_id"] = apiary_user["manager"]["id"]
            else:
                session["manager_id"] = None
        else:
            raise InternalServerError("Unable to retrieve user information from Apiary")

    if session["user_state"] == "eligible":  # pylint: disable=too-many-nested-blocks
        with sentry_sdk.start_span(op="ldap.connect"):
            ldap = Connection(
                Server("whitepages.gatech.edu"),
                auto_bind=True,
            )
        with sentry_sdk.start_span(op="ldap.search"):
            result = ldap.search(
                search_base="dc=whitepages,dc=gatech,dc=edu",
                search_filter="(uid=" + username + ")",
                attributes=["postOfficeBox", "homePostalAddress"],
            )

        georgia_tech_mailbox = None
        home_address = None

        if result is True:
            for entry in ldap.entries:
                if (
                    "postOfficeBox" in entry
                    and entry["postOfficeBox"] is not None
                    and entry["postOfficeBox"].value is not None
                ):
                    georgia_tech_mailbox = entry["postOfficeBox"].value
                if (
                    "homePostalAddress" in entry
                    and entry["homePostalAddress"] is not None
                    and entry["homePostalAddress"].value is not None
                    and entry["homePostalAddress"].value != "UNPUBLISHED INFO"
                ):
                    home_address = entry["homePostalAddress"].value

        if georgia_tech_mailbox is not None:
            session["address_line_one"] = "351 Ferst Dr NW"
            session["address_line_two"] = georgia_tech_mailbox.split(",")[0]
            session["city"] = "Atlanta"
            session["address_state"] = "GA"
            session["zip_code"] = "30332"
        elif home_address is not None:
            address_validation_response = post(
                url="https://addressvalidation.googleapis.com/v1:validateAddress",
                params={"key": app.config["GOOGLE_MAPS_BACKEND_API_KEY"]},
                json={
                    "address": {
                        "regionCode": "US",
                        "addressLines": [home_address],
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
                session["address_state"] = None

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
                        session["address_state"] = address_validation_json["result"]["address"][
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
            else:
                capture_message(
                    "Failed to validate homePostalAddress from Whitepages: "
                    + address_validation_response.text
                )

    return redirect(url_for("index"))


@app.get("/verify-email")
def verify_email() -> Any:
    """
    Redirects user to mailbox provider for email address verification
    """
    if "user_state" not in session:
        raise Unauthorized("Not logged in")

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )

    if session["user_state"] != "eligible":
        raise Unauthorized("Not eligible")

    email_address_domain = Address(addr_spec=request.args["emailAddress"]).domain.split(".")[-2:]

    if email_address_domain == ["robojackets", "org"]:
        return oauth.google.authorize_redirect(
            url_for("verify_google_complete", _external=True),
            login_hint=request.args["emailAddress"],
            hd="robojackets.org",
        )

    if email_address_domain == ["gatech", "edu"]:
        return oauth.microsoft.authorize_redirect(
            url_for("verify_microsoft_complete", _external=True),
            login_hint=request.args["emailAddress"],
            hd="gatech.edu",
        )

    raise BadRequest("Unexpected email address domain")


@app.get("/verify-email/google/complete")
def verify_google_complete() -> Response:
    """
    Handles the return from Google and updates session appropriately
    """
    if "user_state" not in session:
        raise Unauthorized("Not logged in")

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )

    token = oauth.google.authorize_access_token()

    userinfo = token["userinfo"]

    session["email_address"] = userinfo["email"]
    session["email_verified"] = True

    return redirect(url_for("index"))  # type: ignore


@app.post("/verify-email/google/complete")
def verify_google_onetap() -> Response:
    """
    Handles a Google One Tap login and updates session appropriately
    """
    if "user_state" not in session:
        raise Unauthorized("Not logged in")

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )

    userinfo = id_token.verify_oauth2_token(
        request.form["credential"], requests.Request(), app.config["GOOGLE_CLIENT_ID"]
    )

    if userinfo["hd"] != "robojackets.org":
        raise Unauthorized("Invalid hd value")

    session["email_address"] = userinfo["email"]
    session["email_verified"] = userinfo["email_verified"]

    return redirect(url_for("index"))  # type: ignore


@app.get("/verify-email/microsoft/complete")
def verify_microsoft_complete() -> Response:
    """
    Handles the return from Microsoft and updates session appropriately
    """
    if "user_state" not in session:
        raise Unauthorized("Not logged in")

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )
    token = oauth.microsoft.authorize_access_token()

    userinfo = token["userinfo"]

    session["email_address"] = userinfo["email"]
    session["email_verified"] = True

    return redirect(url_for("index"))  # type: ignore


@app.post("/")
def submit() -> Union[Response, str]:  # pylint: disable=too-many-branches
    """
    Submits the form for fulfillment
    """
    if "user_state" not in session:
        raise Unauthorized("Not logged in")

    set_user(
        {
            "id": session["user_id"],
            "username": session["username"],
            "email": session["email_address"],
            "ip_address": request.remote_addr,
        }
    )

    if session["user_state"] != "eligible":
        raise Unauthorized("Not eligible")

    if not session["email_verified"]:
        raise BadRequest("Email address must be verified")

    manager_response = get(
        url=app.config["APIARY_URL"] + "/api/v1/users/" + request.form["manager"],
        headers={
            "Authorization": "Bearer " + app.config["APIARY_TOKEN"],
            "Accept": "application/json",
        },
        timeout=(5, 5),
    )

    if manager_response.status_code != 200:
        raise InternalServerError("Failed to retrieve manager information from Apiary")

    manager = manager_response.json()["user"]

    keycloak_access_token_response = post(
        url=app.config["KEYCLOAK_SERVER"] + "/realms/master/protocol/openid-connect/token",
        data={
            "client_id": app.config["KEYCLOAK_ADMIN_CLIENT_ID"],
            "client_secret": app.config["KEYCLOAK_ADMIN_CLIENT_SECRET"],
            "grant_type": "client_credentials",
        },
        timeout=(5, 5),
    )

    if keycloak_access_token_response.status_code != 200:
        raise InternalServerError("Failed to retrieve access token for Keycloak")

    if (
        "gmail_address" in manager
        and manager["gmail_address"] is not None
        and manager["gmail_address"].endswith("@robojackets.org")
    ):
        manager_email_address = manager["gmail_address"]
    else:
        keycloak_user_response = get(
            url=app.config["KEYCLOAK_SERVER"]
            + "/admin/realms/"
            + app.config["KEYCLOAK_REALM"]
            + "/users",
            params={
                "username": manager["uid"],
                "exact": True,
            },
            headers={
                "Authorization": "Bearer " + keycloak_access_token_response.json()["access_token"],
            },
            timeout=(5, 5),
        )

        if keycloak_user_response.status_code != 200:
            raise InternalServerError("Failed to search for manager in Keycloak")

        if len(keycloak_user_response.json()) == 0:
            manager_email_address = manager["gt_email"]
        elif len(keycloak_user_response.json()) == 1:
            keycloak_user = keycloak_user_response.json()[0]
            if (
                "attributes" in keycloak_user
                and "googleWorkspaceAccount" in keycloak_user["attributes"]
            ):
                manager_email_address = keycloak_user["attributes"]["googleWorkspaceAccount"][0]
            else:
                manager_email_address = manager["gt_email"]
        else:
            raise InternalServerError("More than one result for manager search in Keycloak")

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
            + ", "
            + manager["full_name"]
            + " < "
            + manager_email_address
            + ">",
            "Subject": request.form["first_name"]
            + " "
            + request.form["last_name"]
            + " requested a BILL Spend & Expense account",
            "TextBody": render_template("email.txt", manager=manager["full_name"]),
            "MessageStream": "outbound",
        },
        timeout=(5, 5),
    )

    if postmark_response.status_code == 200:
        # remove eligible role
        delete(
            url=app.config["KEYCLOAK_SERVER"]
            + "/admin/realms/"
            + app.config["KEYCLOAK_REALM"]
            + "/users/"
            + session["sub"]
            + "/role-mappings/clients/"
            + app.config["KEYCLOAK_CLIENT_UUID"],
            headers={
                "Authorization": "Bearer " + keycloak_access_token_response.json()["access_token"],
            },
            timeout=(5, 5),
            json=[{"id": app.config["KEYCLOAK_CLIENT_ROLE_ELIGIBLE"], "name": "eligible"}],
        )

        # add provisioned role
        post(
            url=app.config["KEYCLOAK_SERVER"]
            + "/admin/realms/"
            + app.config["KEYCLOAK_REALM"]
            + "/users/"
            + session["sub"]
            + "/role-mappings/clients/"
            + app.config["KEYCLOAK_CLIENT_UUID"],
            headers={
                "Authorization": "Bearer " + keycloak_access_token_response.json()["access_token"],
            },
            timeout=(5, 5),
            json=[{"id": app.config["KEYCLOAK_CLIENT_ROLE_PROVISIONED"], "name": "provisioned"}],
        )

        session["user_state"] = "requested"
        return render_template("submitted.html")

    raise InternalServerError(
        "Postmark returned unexpected response code " + str(postmark_response.status_code)
    )


@app.get("/ping")
def ping() -> Dict[str, str]:
    """
    Returns an arbitrary successful response, for health checks
    """
    return {"status": "ok"}
