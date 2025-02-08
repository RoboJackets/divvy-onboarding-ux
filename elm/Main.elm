port module Main exposing (..)

import Browser
import Browser.Dom exposing (..)
import Browser.Navigation as Nav
import Char exposing (isDigit)
import Dict exposing (..)
import Email
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Events.Extra exposing (..)
import Http exposing (..)
import Json.Decode exposing (..)
import Json.Encode
import List exposing (..)
import Maybe exposing (..)
import Regex
import String
import Svg exposing (Svg, path, svg)
import Svg.Attributes exposing (d)
import Task
import Time exposing (..)
import Tuple exposing (..)
import Url
import Url.Builder
import W3.Html exposing (toAttribute)
import W3.Html.Attributes exposing (inputmode, numeric)



-- REGEX


nameRegex : Regex.Regex
nameRegex =
    Maybe.withDefault Regex.never (Regex.fromString "^[a-zA-Z ]+$")



-- STRINGS


noBreakSpace : String
noBreakSpace =
    String.fromChar '\u{00A0}'


emailFeedbackText : String
emailFeedbackText =
    "Please enter a valid email address ending in gatech.edu or robojackets.org"


managerFeedbackText : String
managerFeedbackText =
    "Please select your manager"



-- ICONS


googleIcon : Svg msg
googleIcon =
    svg [ Svg.Attributes.width "16", Svg.Attributes.height "16", Svg.Attributes.viewBox "0 0 16 16", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; position: relative;" ] [ path [ d "M15.545 6.558a9.42 9.42 0 0 1 .139 1.626c0 2.434-.87 4.492-2.384 5.885h.002C11.978 15.292 10.158 16 8 16A8 8 0 1 1 8 0a7.689 7.689 0 0 1 5.352 2.082l-2.284 2.284A4.347 4.347 0 0 0 8 3.166c-2.087 0-3.86 1.408-4.492 3.304a4.792 4.792 0 0 0 0 3.063h.003c.635 1.893 2.405 3.301 4.492 3.301 1.078 0 2.004-.276 2.722-.764h-.003a3.702 3.702 0 0 0 1.599-2.431H8v-3.08h7.545z" ] [] ]


microsoftIcon : Svg msg
microsoftIcon =
    svg [ Svg.Attributes.width "16", Svg.Attributes.height "16", Svg.Attributes.viewBox "0 0 16 16", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; position: relative;" ] [ path [ d "M7.462 0H0v7.19h7.462V0zM16 0H8.538v7.19H16V0zM7.462 8.211H0V16h7.462V8.211zm8.538 0H8.538V16H16V8.211z" ] [] ]


checkIcon : Svg msg
checkIcon =
    svg [ Svg.Attributes.width "16", Svg.Attributes.height "16", Svg.Attributes.viewBox "0 0 16 16", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; position: relative;" ] [ path [ d "M12.736 3.97a.733.733 0 0 1 1.047 0c.286.289.29.756.01 1.05L7.88 12.01a.733.733 0 0 1-1.065.02L3.217 8.384a.757.757 0 0 1 0-1.06.733.733 0 0 1 1.047 0l3.052 3.093 5.4-6.425a.247.247 0 0 1 .02-.022Z" ] [] ]


exclamationCircleIcon : Svg msg
exclamationCircleIcon =
    svg [ Svg.Attributes.width "16", Svg.Attributes.height "16", Svg.Attributes.viewBox "0 0 16 16", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; position: relative;" ] [ path [ d "M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z" ] [], path [ d "M7.002 11a1 1 0 1 1 2 0 1 1 0 0 1-2 0zM7.1 4.995a.905.905 0 1 1 1.8 0l-.35 3.507a.552.552 0 0 1-1.1 0L7.1 4.995z" ] [] ]



-- MAPS


emailProviderIcon : Dict String (Svg msg)
emailProviderIcon =
    Dict.fromList [ ( "robojackets.org", googleIcon ), ( "gatech.edu", microsoftIcon ) ]


emailProviderName : Dict String String
emailProviderName =
    Dict.fromList [ ( "robojackets.org", "Google" ), ( "gatech.edu", "Microsoft" ) ]



-- DURATIONS


dayInMilliseconds : Int
dayInMilliseconds =
    1000 * 60 * 60 * 24 * 1



-- TYPES


type NextAction
    = RedirectToEmailVerification
    | SubmitForm
    | NoOpNextAction


type ValidationResult
    = Valid
    | Invalid String


type alias AddressComponent =
    { value : String
    , types : List String
    }


type alias GoogleAddressValidation =
    { addressComplete : Maybe Bool
    , missingComponentTypes : Maybe (List String)
    }


type alias NameValidation =
    { firstNameResult : ValidationResult
    , lastNameResult : ValidationResult
    }


type alias Model =
    { firstName : String
    , lastName : String
    , emailAddress : String
    , emailVerified : Bool
    , managerOptions : Dict Int String
    , managerId : Maybe Int
    , selfId : Int
    , formSubmissionInProgress : Bool
    , acknowledgedCardPolicy : Bool
    , acknowledgedReimbursementPolicy : Bool
    , acknowledgedIdentityVerificationPolicy : Bool
    , showValidation : Bool
    , googleClientId : String
    , googleOneTapLoginUri : String
    , nextAction : NextAction
    , showRampBanner : Bool
    }


type Msg
    = UrlRequest Browser.UrlRequest
    | UrlChanged Url.Url
    | FormSubmitted
    | FormChanged
    | FirstNameInput String
    | LastNameInput String
    | EmailAddressInput String
    | ManagerInput Int
    | AcknowledgeCardPolicyChecked Bool
    | AcknowledgeReimbursementPolicyChecked Bool
    | AcknowledgeIdentityVerificationPolicyChecked Bool
    | NoOpMsg
    | LocalStorageSaved Bool
    | EmailVerificationButtonClicked
    | DismissRampBanner



-- PLUMBING


main : Program Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequest
        }


init : Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( buildInitialModel flags
    , Cmd.batch
        [ if showOneTap (buildInitialModel flags) then
            initializeOneTap True

          else
            Cmd.none
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequest urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.load (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( model, Cmd.none )

        FormSubmitted ->
            ( { model
                | showValidation = True
                , nextAction =
                    case validateModel model of
                        Invalid _ ->
                            NoOpNextAction

                        Valid ->
                            SubmitForm
              }
            , case validateModel model of
                Invalid fieldId ->
                    Task.attempt (\_ -> NoOpMsg) (focus fieldId)

                Valid ->
                    saveToLocalStorage (stringifyModel model)
            )

        FormChanged ->
            ( { model | nextAction = NoOpNextAction }, saveToLocalStorage (stringifyModel model) )

        FirstNameInput firstName ->
            ( { model
                | firstName = firstName
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        LastNameInput lastName ->
            ( { model
                | lastName = lastName
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        EmailAddressInput emailAddress ->
            ( { model
                | emailAddress = emailAddress
                , emailVerified = False
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        EmailVerificationButtonClicked ->
            ( { model
                | nextAction = RedirectToEmailVerification
              }
            , saveToLocalStorage (stringifyModel model)
            )

        ManagerInput managerId ->
            ( { model
                | managerId = Just managerId
                , nextAction = NoOpNextAction
              }
            , saveToLocalStorage (stringifyModel { model | managerId = Just managerId })
            )

        AcknowledgeCardPolicyChecked acknowledgedCardPolicy ->
            ( { model
                | acknowledgedCardPolicy = acknowledgedCardPolicy
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        AcknowledgeReimbursementPolicyChecked acknowledgedReimbursementPolicy ->
            ( { model
                | acknowledgedReimbursementPolicy = acknowledgedReimbursementPolicy
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        AcknowledgeIdentityVerificationPolicyChecked acknowledgedIdentityVerificationPolicy ->
            ( { model
                | acknowledgedIdentityVerificationPolicy = acknowledgedIdentityVerificationPolicy
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        NoOpMsg ->
            ( { model | nextAction = NoOpNextAction }, Cmd.none )

        LocalStorageSaved _ ->
            ( { model
                | nextAction = NoOpNextAction
                , formSubmissionInProgress =
                    case model.nextAction of
                        SubmitForm ->
                            True

                        _ ->
                            False
              }
            , case model.nextAction of
                RedirectToEmailVerification ->
                    Nav.load
                        (Url.Builder.absolute
                            [ "verify-email" ]
                            [ Url.Builder.string "emailAddress" model.emailAddress ]
                        )

                SubmitForm ->
                    submitForm True

                NoOpNextAction ->
                    Cmd.none
            )

        DismissRampBanner ->
            ( { model
                | showRampBanner = False
                , nextAction = NoOpNextAction
              }
            , saveToLocalStorage (stringifyModel { model | showRampBanner = False })
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ localStorageSaved LocalStorageSaved
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "BILL Spend & Expense Onboarding"
    , body =
        [ div [ class "container", class "mt-md-4", class "mt-3", style "max-width" "48rem" ]
            [ h1 []
                [ text "BILL Spend & Expense Onboarding"
                ]
            , p [ class "mt-4", class "mb-4" ]
                [ text "RoboJackets, Inc. uses "
                , a [ href "https://www.bill.com/product/spend-and-expense" ]
                    [ text "BILL Spend & Expense"
                    ]
                , text " to issue corporate credit cards and manage reimbursements. We need some information from you to create your BILL Spend & Expense account."
                ]
            , div [ class "alert", class "alert-primary", class "alert-dismissible", class "mb-4", classList [ ( "d-none", not model.showRampBanner ) ] ]
                [ text "RoboJackets is currently migrating to "
                , a [ href "https://ramp.com", class "alert-link" ] [ text "Ramp" ]
                , text " to replace BILL Spend & Expense. Please check with your project manager if you should "
                , a [ href "https://ramp.robojackets.org", class "alert-link" ] [ text "request a Ramp account" ]
                , text " instead."
                , button [ type_ "button", class "btn-close", onClick DismissRampBanner ] []
                ]
            , Html.form
                [ class "row"
                , class "g-3"
                , method "POST"
                , action "/"
                , novalidate True
                , onSubmit FormSubmitted
                ]
                [ div [ class "col-6" ]
                    [ label [ for "first_name", class "form-label" ]
                        [ text "First Name" ]
                    , input
                        [ id "first_name"
                        , type_ "text"
                        , classList
                            [ ( "form-control", True )
                            , ( "is-valid", model.showValidation && isValid (validateName model.firstName model.lastName).firstNameResult )
                            , ( "is-invalid", model.showValidation && not (isValid (validateName model.firstName model.lastName).firstNameResult) )
                            ]
                        , name "first_name"
                        , minlength 1
                        , maxlength 18
                        , required True
                        , placeholder "First Name"
                        , on "change" (succeed FormChanged)
                        , onInput FirstNameInput
                        , Html.Attributes.value model.firstName
                        ]
                        []
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateName model.firstName model.lastName).firstNameResult) ]
                    ]
                , div [ class "col-6" ]
                    [ label [ for "last_name", class "form-label" ]
                        [ text "Last Name" ]
                    , input
                        [ id "last_name"
                        , type_ "text"
                        , classList
                            [ ( "form-control", True )
                            , ( "is-valid", model.showValidation && isValid (validateName model.firstName model.lastName).lastNameResult )
                            , ( "is-invalid", model.showValidation && not (isValid (validateName model.firstName model.lastName).lastNameResult) )
                            ]
                        , name "last_name"
                        , minlength 1
                        , maxlength 18
                        , required True
                        , placeholder "Last Name"
                        , on "change" (succeed FormChanged)
                        , onInput LastNameInput
                        , Html.Attributes.value model.lastName
                        ]
                        []
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateName model.firstName model.lastName).lastNameResult) ]
                    ]
                , div [ class "form-text", class "mb-3" ]
                    [ text "Your name must match your government-issued identification, only contain letters and spaces, and be a maximum of 20 characters." ]
                , div [ class "col-12" ]
                    [ label [ for "email_address", class "form-label" ]
                        [ text "Email Address" ]
                    , div [ class "input-group" ]
                        [ input
                            [ id "email_address"
                            , name "email_address"
                            , type_ "email"
                            , classList
                                [ ( "form-control", True )
                                , ( "is-valid", model.showValidation && isValid (validateEmailAddress model.emailAddress model.emailVerified) )
                                , ( "is-invalid", model.showValidation && not (isValid (validateEmailAddress model.emailAddress model.emailVerified)) )
                                ]
                            , minlength 13
                            , required True
                            , placeholder "Email Address"
                            , on "change" (succeed FormChanged)
                            , onInput EmailAddressInput
                            , Html.Attributes.value model.emailAddress
                            ]
                            []
                        , button
                            [ classList
                                [ ( "btn", True )
                                , ( "btn-primary", True )
                                , ( "rounded-end", True )
                                ]
                            , type_ "button"
                            , id "email_verification_button"
                            , disabled
                                (model.emailVerified
                                    || not (Dict.member (withDefault "unknown" (emailAddressDomain model.emailAddress)) emailProviderName)
                                    || (model.nextAction /= NoOpNextAction)
                                )
                            , onClick EmailVerificationButtonClicked
                            ]
                            [ if model.emailVerified then
                                checkIcon

                              else
                                case emailAddressDomain model.emailAddress of
                                    Just domain ->
                                        withDefault exclamationCircleIcon (Dict.get domain emailProviderIcon)

                                    Nothing ->
                                        exclamationCircleIcon
                            , text
                                (noBreakSpace
                                    ++ noBreakSpace
                                    ++ (if model.emailVerified then
                                            "Verified"

                                        else if Dict.member (withDefault "unknown" (emailAddressDomain model.emailAddress)) emailProviderName then
                                            "Verify with "
                                                ++ withDefault "Unknown" (Dict.get (withDefault "unknown" (emailAddressDomain model.emailAddress)) emailProviderName)

                                        else
                                            "Verify"
                                       )
                                )
                            ]
                        , div [ class "invalid-feedback" ]
                            [ text (feedbackText (validateEmailAddress model.emailAddress model.emailVerified)) ]
                        ]
                    ]
                , div [ class "form-text", class "mb-3" ]
                    [ text "You will receive an email invitation to this address once your account has been created." ]
                , div [ class "col-12" ]
                    [ label [ for "manager", class "form-label" ]
                        [ text "Manager" ]
                    , select
                        [ class "form-select"
                        , name "manager"
                        , id "manager"
                        , required True
                        , on "change" (Json.Decode.map ManagerInput targetValueIntParse)
                        , classList
                            [ ( "is-valid", model.showValidation && isValid (validateManager model.managerId (Dict.keys model.managerOptions) model.selfId) )
                            , ( "is-invalid", model.showValidation && not (isValid (validateManager model.managerId (Dict.keys model.managerOptions) model.selfId)) )
                            ]
                        ]
                        ([ option
                            [ Html.Attributes.value ""
                            , disabled True
                            , selected
                                (case model.managerId of
                                    Just managerId ->
                                        model.selfId == managerId

                                    Nothing ->
                                        True
                                )
                            ]
                            [ text "Select your manager..." ]
                         ]
                            ++ List.map (managerTupleToHtmlOption model.managerId model.selfId) (sortBy second (toList model.managerOptions))
                        )
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateManager model.managerId (Dict.keys model.managerOptions) model.selfId)) ]
                    , div [ class "form-text", class "mb-3" ]
                        [ text "Your manager will be responsible for reviewing your credit card transactions and reimbursement requests. This should typically be your project manager." ]
                    ]
                , div [ class "col-12" ]
                    [ div [ class "form-check", style "cursor" "not-allowed" ]
                        [ input
                            [ id "order_physical_card"
                            , name "order_physical_card"
                            , type_ "checkbox"
                            , class "form-check-input"
                            , Html.Attributes.value "order_physical_card"
                            , checked False
                            , disabled True
                            ]
                            []
                        , label [ for "order_physical_card", class "form-check-label", style "cursor" "not-allowed" ]
                            [ text "Order a physical card" ]
                        , div [ class "form-text", class "mb-3" ]
                            [ text "Physical BILL Spend & Expense cards are no longer available to order. If you need a physical card, please "
                            , a [ href "https://ramp.robojackets.org", class "text-secondary" ] [ text "request a Ramp card" ]
                            , text " instead."
                            ]
                        ]
                    ]
                , div [ class "col-12", class "mb-3" ]
                    [ div [ class "form-check", class "mb-2" ]
                        [ input
                            [ class "form-check-input"
                            , type_ "checkbox"
                            , id "corporate_card_policy"
                            , required True
                            , onCheck AcknowledgeCardPolicyChecked
                            , classList
                                [ ( "is-valid", model.showValidation && model.acknowledgedCardPolicy )
                                , ( "is-invalid", model.showValidation && not model.acknowledgedCardPolicy )
                                ]
                            ]
                            []
                        , label [ class "form-check-label", for "corporate_card_policy" ]
                            [ text "I have read and agree to the "
                            , a [ href "https://docs.google.com/document/d/e/2PACX-1vRhCOHBpRDb2a6znvSmeET88fmlOzSSnO8xYDwDF5lrm8GzAiWnoSwMYCFh_aIkCQEdLusH1i4ktVkb/pub" ] [ text "RoboJackets, Inc. Corporate Credit Card Policy" ]
                            , text ". I understand that any credit card(s) provided to me are the property of RoboJackets, Inc. and should only be used for preapproved business expenses."
                            ]
                        , div [ class "invalid-feedback" ]
                            [ text "Please read and acknowledge the corporate card policy" ]
                        ]
                    , div [ class "form-check", class "mb-2" ]
                        [ input
                            [ class "form-check-input"
                            , type_ "checkbox"
                            , id "reimbursement_policy"
                            , required True
                            , onCheck AcknowledgeReimbursementPolicyChecked
                            , classList
                                [ ( "is-valid", model.showValidation && model.acknowledgedReimbursementPolicy )
                                , ( "is-invalid", model.showValidation && not model.acknowledgedReimbursementPolicy )
                                ]
                            ]
                            []
                        , label [ class "form-check-label", for "reimbursement_policy" ]
                            [ text "I have read and agree to the "
                            , a [ href "https://docs.google.com/document/d/e/2PACX-1vSjR5MitvqiO9Uc8K0kCHeou04PynqeHmJlzAwq8Cno-urMSKOLv6Nm9RCEuuJyX_P9jjrXDGl31xx2/pub" ] [ text "RoboJackets, Inc. Corporate Reimbursement Policy" ]
                            , text ". I understand that reimbursements are paid at the sole discretion of RoboJackets, Inc."
                            ]
                        , div [ class "invalid-feedback" ]
                            [ text "Please read and acknowledge the reimbursement policy" ]
                        ]
                    , div [ class "form-check", class "mb-2" ]
                        [ input
                            [ class "form-check-input"
                            , type_ "checkbox"
                            , id "identity_verification_policy"
                            , required True
                            , onCheck AcknowledgeIdentityVerificationPolicyChecked
                            , classList
                                [ ( "is-valid", model.showValidation && model.acknowledgedIdentityVerificationPolicy )
                                , ( "is-invalid", model.showValidation && not model.acknowledgedIdentityVerificationPolicy )
                                ]
                            ]
                            []
                        , label [ class "form-check-label", for "identity_verification_policy" ]
                            [ text "I am willing and able to provide my date of birth, Social Security number, and/or passport information to BILL for identity verification, if requested."
                            ]
                        , div [ class "invalid-feedback" ]
                            [ text "Please acknowledge the identity verification policy" ]
                        , div [ class "form-text" ]
                            [ text "This information will only be used for identity verification and will not be visible to anyone within RoboJackets. Read more about BILL Spend & Expense's identity verification policies in the "
                            , a [ href "https://help.bill.com/direct/s/article/5304326", class "text-secondary" ] [ text "BILL Help Center" ]
                            , text "."
                            ]
                        ]
                    ]
                , div [ class "col-12", class "mb-3", class "mb-md-5" ]
                    [ button
                        [ type_ "submit"
                        , class "btn"
                        , class "btn-primary"
                        , id "submit_button"
                        , disabled (model.nextAction /= NoOpNextAction || model.formSubmissionInProgress)
                        ]
                        [ text "Submit Request"
                        ]
                    ]
                ]
            ]
        , div
            [ id "g_id_onload"
            , attribute "data-client_id" model.googleClientId
            , attribute "data-auto_prompt" "true"
            , attribute "data-auto_select" "true"
            , attribute "data-login_uri" model.googleOneTapLoginUri
            , attribute "data-cancel_on_tap_outside" "false"
            , attribute "data-context" "signin"
            , attribute "data-itp_support" "true"
            , attribute "data-login_hint" model.emailAddress
            , attribute "data-hd" "robojackets.org"
            , attribute "data-use_fedcm_for_prompt" "true"
            ]
            []
        ]
    }



-- VALIDATION


validateName : String -> String -> NameValidation
validateName firstName lastName =
    { firstNameResult =
        if blankString firstName then
            Invalid "Please enter your first name"

        else if String.length (String.trim firstName) > 18 then
            Invalid "Your first name may be a maximum of 18 characters"

        else if not (Regex.contains nameRegex firstName) then
            Invalid "Your first name may only contain letters and spaces"

        else if String.length (String.trim firstName) + String.length (String.trim lastName) > 19 then
            Invalid "Your first and last name combined may be a maximum of 19 characters"

        else
            Valid
    , lastNameResult =
        if blankString lastName then
            Invalid "Please enter your last name"

        else if String.length (String.trim lastName) > 18 then
            Invalid "Your last name may be a maximum of 18 characters"

        else if not (Regex.contains nameRegex lastName) then
            Invalid "Your last name may only contain letters and spaces"

        else if String.length (String.trim firstName) + String.length (String.trim lastName) > 19 then
            Invalid "Your first and last name combined may be a maximum of 19 characters"

        else
            Valid
    }


validateEmailAddress : String -> Bool -> ValidationResult
validateEmailAddress emailAddress verified =
    case Email.parse emailAddress of
        Ok addressParts ->
            case getSecondLevelDomain addressParts.domain of
                Just domain ->
                    if not (List.member domain (Dict.keys emailProviderName)) then
                        Invalid emailFeedbackText

                    else if not verified then
                        Invalid ("Please verify your email address with " ++ emailProvider domain)

                    else
                        Valid

                Nothing ->
                    Invalid emailFeedbackText

        Err _ ->
            Invalid emailFeedbackText


validateManager : Maybe Int -> List Int -> Int -> ValidationResult
validateManager selectedManagerId managerOptions selfId =
    case selectedManagerId of
        Just managerId ->
            if managerId == selfId then
                Invalid managerFeedbackText

            else if List.member managerId managerOptions then
                Valid

            else
                Invalid managerFeedbackText

        Nothing ->
            Invalid managerFeedbackText


validateModel : Model -> ValidationResult
validateModel model =
    if not (isValid (validateName model.firstName model.lastName).firstNameResult) then
        Invalid "first_name"

    else if not (isValid (validateName model.firstName model.lastName).lastNameResult) then
        Invalid "last_name"

    else if not (isValid (validateEmailAddress model.emailAddress True)) then
        Invalid "email_address"

    else if not model.emailVerified then
        Invalid "email_verification_button"

    else if
        case model.managerId of
            Just _ ->
                False

            Nothing ->
                True
    then
        Invalid "manager"

    else if not model.acknowledgedCardPolicy then
        Invalid "corporate_card_policy"

    else if not model.acknowledgedReimbursementPolicy then
        Invalid "reimbursement_policy"

    else if not model.acknowledgedIdentityVerificationPolicy then
        Invalid "identity_verification_policy"

    else
        Valid



-- HELPERS


isValid : ValidationResult -> Bool
isValid validation =
    case validation of
        Valid ->
            True

        Invalid _ ->
            False


feedbackText : ValidationResult -> String
feedbackText validation =
    case validation of
        Valid ->
            ""

        Invalid text ->
            text


emailAddressDomain : String -> Maybe String
emailAddressDomain emailAddress =
    case Email.parse emailAddress of
        Ok addressParts ->
            getSecondLevelDomain addressParts.domain

        Err _ ->
            Nothing


getSecondLevelDomain : String -> Maybe String
getSecondLevelDomain domain =
    case take 2 (List.reverse (String.split "." (String.toLower (String.trim domain)))) of
        [ "edu", "gatech" ] ->
            Just "gatech.edu"

        [ "org", "robojackets" ] ->
            Just "robojackets.org"

        _ ->
            Nothing


emailProvider : String -> String
emailProvider domain =
    withDefault "unknown" (Dict.get (String.toLower (String.trim domain)) emailProviderName)


managerTupleToHtmlOption : Maybe Int -> Int -> ( Int, String ) -> Html msg
managerTupleToHtmlOption selectedManagerId selfId ( managerId, managerName ) =
    option
        [ Html.Attributes.value (String.fromInt managerId)
        , selected
            (case selectedManagerId of
                Just selectedId ->
                    selectedId == managerId && selectedId /= selfId

                Nothing ->
                    False
            )
        , disabled (selfId == managerId)
        ]
        [ text managerName ]


stringifyModel : Model -> String
stringifyModel model =
    Json.Encode.encode 0
        (Json.Encode.object
            [ ( "firstName", Json.Encode.string (String.trim model.firstName) )
            , ( "lastName", Json.Encode.string (String.trim model.lastName) )
            , ( "emailAddress", Json.Encode.string (String.trim model.emailAddress) )
            , ( "managerId"
              , case model.managerId of
                    Just managerId ->
                        Json.Encode.int managerId

                    Nothing ->
                        Json.Encode.null
              )
            , ( "showRampBanner", Json.Encode.bool model.showRampBanner )
            ]
        )


buildInitialModel : Value -> Model
buildInitialModel value =
    Model
        (String.trim
            (Result.withDefault
                (Result.withDefault "" (decodeValue (at [ "serverData", "firstName" ] string) value))
                (decodeString (field "firstName" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
            )
        )
        (String.trim
            (Result.withDefault
                (Result.withDefault "" (decodeValue (at [ "serverData", "lastName" ] string) value))
                (decodeString (field "lastName" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
            )
        )
        (if Result.withDefault False (decodeValue (at [ "serverData", "emailVerified" ] bool) value) then
            String.trim
                (Result.withDefault
                    ""
                    (decodeValue (at [ "serverData", "emailAddress" ] string) value)
                )

         else
            String.trim
                (Result.withDefault
                    (Result.withDefault "" (decodeValue (at [ "serverData", "emailAddress" ] string) value))
                    (decodeString (field "emailAddress" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
                )
        )
        (Result.withDefault False (decodeValue (at [ "serverData", "emailVerified" ] bool) value))
        (Dict.fromList (List.filterMap stringStringTupleToMaybeIntStringTuple (Result.withDefault [] (decodeValue (at [ "serverData", "managerOptions" ] (keyValuePairs string)) value))))
        (case decodeString (field "managerId" int) (Result.withDefault "{}" (decodeValue (field "localData" string) value)) of
            Ok managerId ->
                Just managerId

            Err _ ->
                case decodeValue (at [ "serverData", "managerId" ] int) value of
                    Ok managerId ->
                        if Result.withDefault -1 (decodeValue (at [ "serverData", "selfId" ] int) value) == managerId then
                            Nothing

                        else
                            Just managerId

                    Err _ ->
                        Nothing
        )
        (Result.withDefault -1 (decodeValue (at [ "serverData", "selfId" ] int) value))
        False
        False
        False
        False
        False
        (String.trim (Result.withDefault "" (decodeValue (at [ "serverData", "googleClientId" ] string) value)))
        (String.trim (Result.withDefault "" (decodeValue (at [ "serverData", "googleOneTapLoginUri" ] string) value)))
        NoOpNextAction
        (Result.withDefault True (decodeString (field "showRampBanner" bool) (Result.withDefault "{}" (decodeValue (field "localData" string) value))))


stringStringTupleToMaybeIntStringTuple : ( String, String ) -> Maybe ( Int, String )
stringStringTupleToMaybeIntStringTuple ( first, second ) =
    case String.toInt first of
        Just intVal ->
            Just ( intVal, second )

        Nothing ->
            Nothing


nonBlankString : String -> Bool
nonBlankString value =
    not (blankString value)


blankString : String -> Bool
blankString value =
    String.isEmpty (String.trim value)


showOneTap : Model -> Bool
showOneTap model =
    case model.emailVerified of
        True ->
            False

        False ->
            case Dict.get (withDefault "unknown" (emailAddressDomain model.emailAddress)) emailProviderName of
                Just providerName ->
                    if providerName == "Google" then
                        True

                    else
                        False

                Nothing ->
                    False



-- PORTS


port submitForm : Bool -> Cmd msg


port initializeOneTap : Bool -> Cmd msg


port saveToLocalStorage : String -> Cmd msg


port localStorageSaved : (Bool -> msg) -> Sub msg
