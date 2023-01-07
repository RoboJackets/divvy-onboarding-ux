let saveForm
let addressFormatValidation

const mailboxRegex = new RegExp("^\\d{6} Georgia Tech Station$");

(function () {
    'use strict'

    window.addEventListener('load', function () {
        const form = document.getElementById('form');

        window.showValidation = false

        const firstNameInput = document.getElementById("first_name")
        const firstNameFeedback = document.getElementById("first_name_feedback")

        const lastNameInput = document.getElementById("last_name")
        const lastNameFeedback = document.getElementById("last_name_feedback")

        const emailInput = document.getElementById("email_address");
        const emailFeedback = document.getElementById("email_feedback")
        const emailVerifiedInput = document.getElementById("email_verified");
        const emailVerificationButton = document.getElementById("emailverificationbutton");

        const managerInput = document.getElementById("manager");

        const orderPhysicalCardInput = document.getElementById("order_physical_card");

        const standardShippingRadio = document.getElementById("standard_shipping");
        const expeditedShippingRadio = document.getElementById("expedited_shipping");
        const shippingOptionsDiv = document.getElementById("shipping_options_div");

        const addressLineOneDiv = document.getElementById("address_line_one_div");
        const addressLineOneInput = document.getElementById("address_line_one");

        const addressLineTwoDiv = document.getElementById("address_line_two_div");
        const addressLineTwoInput = document.getElementById("address_line_two");

        const cityDiv = document.getElementById("city_div");
        const cityInput = document.getElementById("city");

        const stateDiv = document.getElementById("state_div");
        const stateInput = document.getElementById("state");

        const zipDiv = document.getElementById("zip_div");
        const zipInput = document.getElementById("zip_code");
        const zipFeedback = document.getElementById("zip_feedback");

        const cardPolicyInput = document.getElementById("corporate_card_policy");
        const reimbursementPolicyInput = document.getElementById("reimbursement_policy");
        const identityVerificationInput = document.getElementById("identity_verification");

        form.addEventListener('submit', function (event) {
            if (form.checkValidity() === false || nameValidation(event) === false || emailValidation(event) === false) {
                event.preventDefault()
                event.stopPropagation()
                window.showValidation = true
                nameValidation(event)
                emailValidation(event)
                managerValidation(event)
                addressFormatValidation(event)
                acknowledgementValidation(event)
            } else {
                document.getElementById('submit_button').setAttribute('disabled', "true");
                if (!(
                    addressLineOneInput.value === "351 Ferst Dr NW" &&
                    mailboxRegex.test(addressLineTwoInput.value) &&
                    cityInput.value === "Atlanta" &&
                    stateInput.value === "GA" &&
                    zipInput.value === "30332"
                )) {
                    event.preventDefault();
                    event.stopPropagation();
                    checkAddressWithGoogle(event)
                }
            }
        }, false)

        saveForm = function(event) {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', '/save');
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.responseType = 'json';
            xhr.send(
                JSON.stringify(
                    {
                        "first_name": firstNameInput.value,
                        "last_name": lastNameInput.value,
                        "email_address": emailInput.value,
                        "manager": managerInput.value,
                        "order_physical_card": orderPhysicalCardInput.checked,
                        "shipping_option": (standardShippingRadio.checked ? "standard" : "expedited"),
                        "address_line_one": addressLineOneInput.value,
                        "address_line_two": addressLineTwoInput.value,
                        "city": cityInput.value,
                        "state": stateInput.value,
                        "zip_code": zipInput.value,
                    }
                )
            );
        }

        const emailVerificationButtonState = function(event) {
            if (emailInput.value.endsWith("@gatech.edu")) {
                emailVerificationButton.innerHTML = "<i class=\"bi-microsoft\"></i>&nbsp&nbspVerify with Microsoft";
                emailVerificationButton.removeAttribute("disabled");
            } else if (emailInput.value.endsWith("@robojackets.org")) {
                emailVerificationButton.innerHTML = "<i class=\"bi-google\"></i>&nbsp&nbspVerify with Google";
                emailVerificationButton.removeAttribute("disabled");
            } else {
                emailVerificationButton.innerHTML = "<i class=\"bi-exclamation-circle\"></i>&nbsp&nbspVerify";
                emailVerificationButton.setAttribute("disabled", "true");
            }
        }

        const emailVerificationButtonAction = function(event) {
            if (emailInput.value.endsWith("@gatech.edu")) {
                window.location.href = "/verify-email/microsoft";
            } else if (emailInput.value.endsWith("@robojackets.org")) {
                window.location.href = "/verify-email/google";
            }
        }

        const nameValidation = function(event) {
            var isValid = true
            if (firstNameInput.validity.tooShort || firstNameInput.value === "") {
                firstNameFeedback.innerText = "Please enter your first name."
            } else if (firstNameInput.validity.tooLong) {
                firstNameFeedback.innerText = "Your first name can be a maximum of 20 characters."
            } else if (firstNameInput.validity.patternMismatch) {
                firstNameFeedback.innerText = "Your first name can only contain letters and spaces."
            } else if ((firstNameInput.value.length + lastNameInput.value.length) > 20) {
                firstNameFeedback.innerText = "Your first and last name combined can be a maximum of 20 characters."
            }

            if (lastNameInput.validity.tooShort || lastNameInput.value === "") {
                lastNameFeedback.innerText = "Please enter your last name."
            } else if (lastNameInput.validity.tooLong) {
                lastNameFeedback.innerText = "Your last name can be a maximum of 20 characters."
            } else if (lastNameInput.validity.patternMismatch) {
                lastNameFeedback.innerText = "Your last name can only contain letters and spaces."
            } else if ((firstNameInput.value.length + lastNameInput.value.length) > 20) {
                lastNameFeedback.innerText = "Your last and last name combined can be a maximum of 20 characters."
            }

            if (window.showValidation) {
                if (firstNameInput.validity.valid && (firstNameInput.value.length + lastNameInput.value.length) <= 20) {
                    firstNameInput.classList.remove("is-invalid")
                    firstNameInput.classList.add("is-valid")
                } else {
                    firstNameInput.classList.remove("is-valid")
                    firstNameInput.classList.add("is-invalid")
                }

                if (lastNameInput.validity.valid && (firstNameInput.value.length + lastNameInput.value.length) <= 20) {
                    lastNameInput.classList.remove("is-invalid")
                    lastNameInput.classList.add("is-valid")
                } else {
                    lastNameInput.classList.remove("is-valid")
                    lastNameInput.classList.add("is-invalid")
                }
            }

            return firstNameInput.validity.valid && lastNameInput.validity.valid && (firstNameInput.value.length + lastNameInput.value.length) <= 20
        }

        const emailValidation = function (event) {
            var isValid = true
            if (emailInput.validity.tooShort || emailInput.validity.typeMismatch || (!emailInput.value.endsWith("gatech.edu") && !emailInput.value.endsWith("robojackets.org"))) {
                emailFeedback.innerText = "Please enter a valid email address ending in @gatech.edu or @robojackets.org.";
                isValid = false;
            } else if (emailVerifiedInput.value !== "true") {
                if (emailInput.value.endsWith("@gatech.edu")) {
                    emailFeedback.innerText = "Please verify your email address with Microsoft.";
                    isValid = false;
                } else {
                    emailFeedback.innerText = "Please verify your email address with Google.";
                    isValid = false;
                }
            }

            if (window.showValidation) {
                if (isValid) {
                    emailInput.classList.remove("is-invalid")
                    emailInput.classList.add("is-valid")
                } else {
                    emailInput.classList.remove("is-valid")
                    emailInput.classList.add("is-invalid")
                }
            }

            return isValid;
        }

        const markEmailUnverified = function (event) {
            emailVerifiedInput.value = false;
        }

        const managerValidation = function (event) {
            if (window.showValidation) {
                if (managerInput.validity.valid) {
                    managerInput.classList.remove("is-invalid")
                    managerInput.classList.add("is-valid")
                } else {
                    managerInput.classList.remove("is-valid")
                    managerInput.classList.add("is-invalid")
                }
            }
        }

        const toggleShippingFields = function (event) {
            if (orderPhysicalCardInput.checked) {
                addressLineOneInput.removeAttribute("disabled");
                addressLineTwoInput.removeAttribute("disabled");
                cityInput.removeAttribute("disabled");
                stateInput.removeAttribute("disabled");
                zipInput.removeAttribute("disabled");

                shippingOptionsDiv.classList.remove("d-none");
                addressLineOneDiv.classList.remove("d-none");
                addressLineTwoDiv.classList.remove("d-none");
                cityDiv.classList.remove("d-none");
                stateDiv.classList.remove("d-none");
                zipDiv.classList.remove("d-none");
            } else {
                shippingOptionsDiv.classList.add("d-none");
                addressLineOneDiv.classList.add("d-none");
                addressLineTwoDiv.classList.add("d-none");
                cityDiv.classList.add("d-none");
                stateDiv.classList.add("d-none");
                zipDiv.classList.add("d-none");

                addressLineOneInput.setAttribute("disabled", "true");
                addressLineTwoInput.setAttribute("disabled", "true");
                cityInput.setAttribute("disabled", "true");
                stateInput.setAttribute("disabled", "true");
                zipInput.setAttribute("disabled", "true");
            }
        }

        addressFormatValidation = function (event) {
            if (window.showValidation) {
                if (addressLineOneInput.validity.valid) {
                    addressLineOneInput.classList.remove("is-invalid")
                    addressLineOneInput.classList.add("is-valid")
                } else {
                    addressLineOneInput.classList.remove("is-valid")
                    addressLineOneInput.classList.add("is-invalid")
                }
                if (addressLineTwoInput.validity.valid) {
                    addressLineTwoInput.classList.remove("is-invalid")
                    addressLineTwoInput.classList.add("is-valid")
                } else {
                    addressLineTwoInput.classList.remove("is-valid")
                    addressLineTwoInput.classList.add("is-invalid")
                }
                if (cityInput.validity.valid) {
                    cityInput.classList.remove("is-invalid")
                    cityInput.classList.add("is-valid")
                } else {
                    cityInput.classList.remove("is-valid")
                    cityInput.classList.add("is-invalid")
                }
                if (stateInput.validity.valid) {
                    stateInput.classList.remove("is-invalid")
                    stateInput.classList.add("is-valid")
                } else {
                    stateInput.classList.remove("is-valid")
                    stateInput.classList.add("is-invalid")
                }
                if (zipInput.validity.valid) {
                    zipInput.classList.remove("is-invalid")
                    zipInput.classList.add("is-valid")
                } else {
                    if (zipInput.validity.patternMismatch) {
                        zipFeedback.innerText = "Please enter exactly 5 digits."
                    } else {
                        zipFeedback.innerText = "Please enter your ZIP code."
                    }
                    zipInput.classList.remove("is-valid")
                    zipInput.classList.add("is-invalid")
                }
            }
        }

        const acknowledgementValidation = function (event) {
            if (window.showValidation) {
                if (cardPolicyInput.validity.valid) {
                    cardPolicyInput.classList.remove("is-invalid")
                    cardPolicyInput.classList.add("is-valid")
                } else {
                    cardPolicyInput.classList.remove("is-valid")
                    cardPolicyInput.classList.add("is-invalid")
                }
                if (reimbursementPolicyInput.validity.valid) {
                    reimbursementPolicyInput.classList.remove("is-invalid")
                    reimbursementPolicyInput.classList.add("is-valid")
                } else {
                    reimbursementPolicyInput.classList.remove("is-valid")
                    reimbursementPolicyInput.classList.add("is-invalid")
                }
                if (identityVerificationInput.validity.valid) {
                    identityVerificationInput.classList.remove("is-invalid")
                    identityVerificationInput.classList.add("is-valid")
                } else {
                    identityVerificationInput.classList.remove("is-valid")
                    identityVerificationInput.classList.add("is-invalid")
                }
            }
        }

        firstNameInput.addEventListener("change", saveForm);
        firstNameInput.addEventListener("input", nameValidation);

        lastNameInput.addEventListener("change", saveForm);
        lastNameInput.addEventListener("input", nameValidation);

        emailInput.addEventListener("change", markEmailUnverified)
        emailInput.addEventListener("input", emailValidation);
        emailInput.addEventListener("input", emailVerificationButtonState);

        emailVerificationButton.addEventListener("click", emailVerificationButtonAction);

        managerInput.addEventListener("change", saveForm);
        managerInput.addEventListener("change", managerValidation);

        orderPhysicalCardInput.addEventListener("change", saveForm);
        orderPhysicalCardInput.addEventListener("change", toggleShippingFields);

        standardShippingRadio.addEventListener("change", saveForm);
        expeditedShippingRadio.addEventListener("change", saveForm);

        addressLineOneInput.addEventListener("change", saveForm);
        addressLineOneInput.addEventListener("input", addressFormatValidation);
        addressLineOneInput.addEventListener("keypress", function (event) {
            if (event.key === "Enter") {
                event.preventDefault();
            }
        })

        addressLineTwoInput.addEventListener("change", saveForm);
        addressLineTwoInput.addEventListener("input", addressFormatValidation);

        cityInput.addEventListener("change", saveForm);
        cityInput.addEventListener("input", addressFormatValidation);

        stateInput.addEventListener("change", saveForm);
        stateInput.addEventListener("input", addressFormatValidation);

        zipInput.addEventListener("change", saveForm);
        zipInput.addEventListener("input", addressFormatValidation);

        cardPolicyInput.addEventListener("change", acknowledgementValidation);
        reimbursementPolicyInput.addEventListener("change", acknowledgementValidation);
        identityVerificationInput.addEventListener("change", acknowledgementValidation);

    }, false)
}())

let autocomplete;

function initializeAutocomplete() {
    const addressLineOneInput = document.getElementById("address_line_one");

    autocomplete = new google.maps.places.Autocomplete(addressLineOneInput, {
        "componentRestrictions": {"country": ["us"]},
        "fields": ["address_components"],
        "types": ["address"],
    })

    autocomplete.addListener("place_changed", populateAddress);
}

function populateAddress() {
    const addressLineOneInput = document.getElementById("address_line_one");
    const addressLineTwoInput = document.getElementById("address_line_two");
    const cityInput = document.getElementById("city");
    const stateInput = document.getElementById("state");
    const zipInput = document.getElementById("zip_code");

    const place = autocomplete.getPlace();

    let address_line_one = ""
    let city = ""
    let state_code = ""
    let zip_code = ""

    for (const component of place.address_components) {
        const componentType = component.types[0];

        switch (componentType) {
            case "street_number": {
                address_line_one = `${component.long_name} ${address_line_one}`;
                break;
            }
            case "route": {
                address_line_one += component.short_name;
                break;
            }
            case "postal_code": {
                zip_code = component.long_name;
                break;
            }
            case "locality": {
                city = component.long_name;
                break;
            }
            case "administrative_area_level_1": {
                state_code = component.short_name;
                break;
            }
        }
    }

    addressLineOneInput.value = address_line_one
    cityInput.value = city
    stateInput.value = state_code
    zipInput.value = zip_code

    saveForm()
    addressFormatValidation()

    addressLineTwoInput.value = ""
    addressLineTwoInput.focus()
}

function checkAddressWithGoogle(event) {
    const addressLineOneInput = document.getElementById("address_line_one");
    const addressLineTwoInput = document.getElementById("address_line_two");
    const cityInput = document.getElementById("city");
    const stateInput = document.getElementById("state");
    const zipInput = document.getElementById("zip_code");

    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'https://addressvalidation.googleapis.com/v1:validateAddress?key='+document.head.querySelector('meta[name="google-maps-api-key"]').content);
    xhr.setRequestHeader("Content-Type", "application/json")
    xhr.setRequestHeader("Accept", "application/json")
    xhr.responseType = 'json';
    xhr.onload = function () {
        if (200 !== xhr.status) {
            document.getElementById('form').submit();
            return;
        }

        console.log(xhr.response)

        if (xhr.response.result.verdict.addressComplete === true) {
            document.getElementById('form').submit();
        } else if (
            Array.isArray(xhr.response.result.address.missingComponentTypes) &&
            xhr.response.result.address.missingComponentTypes.includes("subpremise")
        ) {
            addressLineTwoInput.classList.remove("is-valid");
            addressLineTwoInput.classList.add("is-invalid");
            document.getElementById("address_line_two_feedback").innerText = "This address requires an apartment or unit number.";
            document.getElementById("submit_button").removeAttribute("disabled");
        } else {
            addressLineOneInput.classList.remove("is-valid");
            addressLineOneInput.classList.add("is-invalid");
            addressLineTwoInput.classList.remove("is-valid");
            addressLineTwoInput.classList.add("is-invalid");
            cityInput.classList.remove("is-valid");
            cityInput.classList.add("is-invalid");
            stateInput.classList.remove("is-valid");
            stateInput.classList.add("is-invalid");
            zipInput.classList.remove("is-valid");
            zipInput.classList.add("is-invalid");

            document.getElementById("address_line_one_feedback").innerText = "This doesn't appear to be a valid address."
            document.getElementById("submit_button").removeAttribute("disabled");

            window.showValidation = true
        }
    }
    xhr.onerror = function () {
        document.getElementById('form').submit();
    }
    xhr.send(
        JSON.stringify({
            "address": {
                "regionCode": "US",
                "postalCode": zipInput.value,
                "administrativeArea": stateInput.value,
                "locality": cityInput.value,
                "addressLines": [
                    addressLineOneInput.value,
                    addressLineTwoInput.value,
                ]
            },
            "enableUspsCass": true,
        })
    );
}
