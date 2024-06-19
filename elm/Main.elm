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


studentCenterMailboxRegex : Regex.Regex
studentCenterMailboxRegex =
    Maybe.withDefault Regex.never (Regex.fromString "^\\d{6} georgia tech station$")


graduateLivingCenterMailboxRegex : Regex.Regex
graduateLivingCenterMailboxRegex =
    Maybe.withDefault Regex.never (Regex.fromString "^(apt|apartment) [1-6][0-2][0-9][a-d]$")



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


truckIcon : Svg msg
truckIcon =
    svg [ Svg.Attributes.width "16", Svg.Attributes.height "16", Svg.Attributes.viewBox "1 0 22 20", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; position: relative;" ] [ path [ d "M18,18.5A1.5,1.5 0 0,1 16.5,17A1.5,1.5 0 0,1 18,15.5A1.5,1.5 0 0,1 19.5,17A1.5,1.5 0 0,1 18,18.5M19.5,9.5L21.46,12H17V9.5M6,18.5A1.5,1.5 0 0,1 4.5,17A1.5,1.5 0 0,1 6,15.5A1.5,1.5 0 0,1 7.5,17A1.5,1.5 0 0,1 6,18.5M20,8H17V4H3C1.89,4 1,4.89 1,6V17H3A3,3 0 0,0 6,20A3,3 0 0,0 9,17H15A3,3 0 0,0 18,20A3,3 0 0,0 21,17H23V12L20,8Z" ] [] ]


airplaneIcon : Svg msg
airplaneIcon =
    svg [ Svg.Attributes.width "16", Svg.Attributes.height "16", Svg.Attributes.viewBox "4 3.4 16.7 17.5", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; position: relative;" ] [ path [ d "M20.56 3.91C21.15 4.5 21.15 5.45 20.56 6.03L16.67 9.92L18.79 19.11L17.38 20.53L13.5 13.1L9.6 17L9.96 19.47L8.89 20.53L7.13 17.35L3.94 15.58L5 14.5L7.5 14.87L11.37 11L3.94 7.09L5.36 5.68L14.55 7.8L18.44 3.91C19 3.33 20 3.33 20.56 3.91Z" ] [] ]


airplaneClockIcon : Svg msg
airplaneClockIcon =
    svg [ Svg.Attributes.width "21.5", Svg.Attributes.height "21.5", Svg.Attributes.viewBox "0 0 23 23.5", Svg.Attributes.fill "currentColor", Svg.Attributes.style "top: -0.125em; margin-bottom: -0.6em; margin-right: -0.345em; position: relative;" ] [ path [ d "M16 9C15.09 9 14.23 9.18 13.43 9.5L12.73 6.45L16.62 2.56C17.2 2 17.2 1.03 16.62 .44S15.08-.146 14.5 .44L10.61 4.33L1.41 2.21L0 3.62L7.43 7.5L3.54 11.4L1.06 11.05L0 12.11L3.18 13.87L4.95 17.06L6 16L5.66 13.5L9.55 9.63L10.57 11.59C9.59 12.79 9 14.33 9 16C9 19.87 12.13 23 16 23S23 19.87 23 16 19.87 9 16 9M16 21C13.24 21 11 18.76 11 16S13.24 11 16 11 21 13.24 21 16 18.76 21 16 21M16.5 16.25V12H15V17L18.61 19.16L19.36 17.94L16.5 16.25Z" ] [] ]



-- MAPS


emailProviderIcon : Dict String (Svg msg)
emailProviderIcon =
    Dict.fromList [ ( "robojackets.org", googleIcon ), ( "gatech.edu", microsoftIcon ) ]


emailProviderName : Dict String String
emailProviderName =
    Dict.fromList [ ( "robojackets.org", "Google" ), ( "gatech.edu", "Microsoft" ) ]


statesMap : Dict String String
statesMap =
    Dict.fromList [ ( "AK", "Alaska" ), ( "AL", "Alabama" ), ( "AR", "Arkansas" ), ( "AZ", "Arizona" ), ( "CA", "California" ), ( "CO", "Colorado" ), ( "CT", "Connecticut" ), ( "DC", "District of Columbia" ), ( "DE", "Delaware" ), ( "FL", "Florida" ), ( "GA", "Georgia" ), ( "HI", "Hawaii" ), ( "IA", "Iowa" ), ( "ID", "Idaho" ), ( "IL", "Illinois" ), ( "IN", "Indiana" ), ( "KS", "Kansas" ), ( "KY", "Kentucky" ), ( "LA", "Louisiana" ), ( "MA", "Massachusetts" ), ( "MD", "Maryland" ), ( "ME", "Maine" ), ( "MI", "Michigan" ), ( "MN", "Minnesota" ), ( "MO", "Missouri" ), ( "MS", "Mississippi" ), ( "MT", "Montana" ), ( "NC", "North Carolina" ), ( "ND", "North Dakota" ), ( "NE", "Nebraska" ), ( "NH", "New Hampshire" ), ( "NJ", "New Jersey" ), ( "NM", "New Mexico" ), ( "NV", "Nevada" ), ( "NY", "New York" ), ( "OH", "Ohio" ), ( "OK", "Oklahoma" ), ( "OR", "Oregon" ), ( "PA", "Pennsylvania" ), ( "RI", "Rhode Island" ), ( "SC", "South Carolina" ), ( "SD", "South Dakota" ), ( "TN", "Tennessee" ), ( "TX", "Texas" ), ( "UT", "Utah" ), ( "VA", "Virginia" ), ( "VT", "Vermont" ), ( "WA", "Washington" ), ( "WI", "Wisconsin" ), ( "WV", "West Virginia" ), ( "WY", "Wyoming" ) ]



-- DURATIONS


dayInMilliseconds : Int
dayInMilliseconds =
    1000 * 60 * 60 * 24 * 1



-- TYPES


type ShippingMethod
    = UspsFirstClass
    | FedEx2Day
    | FedExOvernight


type NextAction
    = RedirectToEmailVerification
    | ValidateAddressWithGoogle
    | SubmitForm
    | NoOpNextAction


type CampusAddress
    = StudentCenter
    | GraduateLivingCenter
    | ManufacturingRelatedDisciplinesComplex
    | NotCampusAddress


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
    , orderPhysicalCard : Bool
    , shippingMethod : ShippingMethod
    , addressLineOne : String
    , addressLineTwo : String
    , city : String
    , state : Maybe String
    , zip : String
    , addressLineTwoRequired : Bool
    , addressIsValid : Maybe Bool
    , addressValidationInProgress : Bool
    , formSubmissionInProgress : Bool
    , acknowledgedCardPolicy : Bool
    , acknowledgedReimbursementPolicy : Bool
    , acknowledgedIdentityVerificationPolicy : Bool
    , showValidation : Bool
    , googleMapsApiKey : String
    , googleClientId : String
    , googleOneTapLoginUri : String
    , time : Time.Posix
    , zone : Time.Zone
    , nextAction : NextAction
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
    | OrderPhysicalCardChecked Bool
    | UspsFirstClassClicked
    | FedEx2DayClicked
    | FedExOvernightClicked
    | AddressLineOneInput String
    | AddressLineTwoInput String
    | CityInput String
    | StateInput String
    | ZipInput String
    | AcknowledgeCardPolicyChecked Bool
    | AcknowledgeReimbursementPolicyChecked Bool
    | AcknowledgeIdentityVerificationPolicyChecked Bool
    | NoOpMsg
    | LocalStorageSaved Bool
    | EmailVerificationButtonClicked
    | PlaceChanged Value
    | GoogleAddressValidationResultReceived (Result Http.Error GoogleAddressValidation)
    | SetTime Time.Posix
    | SetZone Time.Zone



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
        [ Task.perform SetTime Time.now
        , Task.perform SetZone Time.here
        , initializeAutocomplete (String.trim (Result.withDefault "" (decodeValue (at [ "serverData", "googleMapsApiKey" ] string) flags)))
        , if showOneTap (buildInitialModel flags) then
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
                            case checkCampusAddress model of
                                StudentCenter ->
                                    SubmitForm

                                GraduateLivingCenter ->
                                    SubmitForm

                                ManufacturingRelatedDisciplinesComplex ->
                                    SubmitForm

                                NotCampusAddress ->
                                    ValidateAddressWithGoogle
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

        OrderPhysicalCardChecked orderPhysicalCard ->
            ( { model
                | orderPhysicalCard = orderPhysicalCard
                , nextAction = NoOpNextAction
              }
            , saveToLocalStorage (stringifyModel { model | orderPhysicalCard = orderPhysicalCard })
            )

        UspsFirstClassClicked ->
            ( { model
                | shippingMethod = UspsFirstClass
                , nextAction = NoOpNextAction
              }
            , saveToLocalStorage (stringifyModel { model | shippingMethod = UspsFirstClass })
            )

        FedEx2DayClicked ->
            ( { model
                | shippingMethod = FedEx2Day
                , nextAction = NoOpNextAction
              }
            , saveToLocalStorage (stringifyModel { model | shippingMethod = FedEx2Day })
            )

        FedExOvernightClicked ->
            ( { model
                | shippingMethod = FedExOvernight
                , nextAction = NoOpNextAction
              }
            , saveToLocalStorage (stringifyModel { model | shippingMethod = FedExOvernight })
            )

        AddressLineOneInput addressLineOne ->
            ( { model
                | addressLineOne = addressLineOne
                , nextAction = NoOpNextAction
                , addressLineTwoRequired = False
              }
            , Cmd.none
            )

        AddressLineTwoInput addressLineTwo ->
            ( { model
                | addressLineTwo = addressLineTwo
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        CityInput city ->
            ( { model
                | city = city
                , nextAction = NoOpNextAction
                , addressLineTwoRequired = False
              }
            , Cmd.none
            )

        StateInput state ->
            ( { model
                | state = Just state
                , nextAction = NoOpNextAction
                , addressLineTwoRequired = False
              }
            , saveToLocalStorage (stringifyModel { model | state = Just state })
            )

        ZipInput zip ->
            ( { model
                | zip = zip
                , nextAction = NoOpNextAction
                , addressLineTwoRequired = False
              }
            , Cmd.none
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
                , addressValidationInProgress =
                    case model.nextAction of
                        ValidateAddressWithGoogle ->
                            True

                        _ ->
                            False
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

                ValidateAddressWithGoogle ->
                    post
                        { url =
                            Url.Builder.crossOrigin
                                "https://addressvalidation.googleapis.com/v1:validateAddress"
                                []
                                [ Url.Builder.string "key" model.googleMapsApiKey ]
                        , body =
                            jsonBody
                                (Json.Encode.object
                                    [ ( "enableUspsCass", Json.Encode.bool True )
                                    , ( "address"
                                      , Json.Encode.object
                                            [ ( "regionCode", Json.Encode.string "US" )
                                            , ( "postalCode", Json.Encode.string (String.trim model.zip) )
                                            , ( "administrativeArea", Json.Encode.string (Maybe.withDefault "" model.state) )
                                            , ( "locality", Json.Encode.string (String.trim model.city) )
                                            , ( "addressLines"
                                              , Json.Encode.list Json.Encode.string
                                                    (List.map String.trim
                                                        (List.filter nonBlankString
                                                            [ model.addressLineOne
                                                            , model.addressLineTwo
                                                            ]
                                                        )
                                                    )
                                              )
                                            ]
                                      )
                                    ]
                                )
                        , expect = expectJson GoogleAddressValidationResultReceived googleAddressValidationResponseDecoder
                        }

                SubmitForm ->
                    submitForm True

                NoOpNextAction ->
                    Cmd.none
            )

        PlaceChanged value ->
            ( { model
                | addressLineOne =
                    String.trim (getAddressComponent (decodePlaceChanged value) "street_number")
                        ++ " "
                        ++ String.trim (getAddressComponent (decodePlaceChanged value) "route")
                , addressLineTwo = String.trim (getAddressComponent (decodePlaceChanged value) "subpremise")
                , city = String.trim (getAddressComponent (decodePlaceChanged value) "locality")
                , state = Just (String.trim (getAddressComponent (decodePlaceChanged value) "administrative_area_level_1"))
                , zip = String.trim (getAddressComponent (decodePlaceChanged value) "postal_code")
                , nextAction = NoOpNextAction
              }
            , Cmd.batch
                [ Task.attempt (\_ -> NoOpMsg) (focus "address_line_two")
                , saveToLocalStorage
                    (stringifyModel
                        { model
                            | addressLineOne =
                                String.trim (getAddressComponent (decodePlaceChanged value) "street_number")
                                    ++ " "
                                    ++ String.trim (getAddressComponent (decodePlaceChanged value) "route")
                            , addressLineTwo = String.trim (getAddressComponent (decodePlaceChanged value) "subpremise")
                            , city = String.trim (getAddressComponent (decodePlaceChanged value) "locality")
                            , state = Just (String.trim (getAddressComponent (decodePlaceChanged value) "administrative_area_level_1"))
                            , zip = String.trim (getAddressComponent (decodePlaceChanged value) "postal_code")
                        }
                    )
                ]
            )

        GoogleAddressValidationResultReceived result ->
            ( { model
                | nextAction = NoOpNextAction
                , addressValidationInProgress = False
                , addressLineTwoRequired =
                    case result of
                        Ok verdict ->
                            if List.member "subpremise" (Maybe.withDefault [] verdict.missingComponentTypes) then
                                True

                            else
                                False

                        Err _ ->
                            False
                , addressIsValid =
                    case result of
                        Ok verdict ->
                            case verdict.addressComplete of
                                Just addressComplete ->
                                    Just addressComplete

                                Nothing ->
                                    if List.member "subpremise" (Maybe.withDefault [] verdict.missingComponentTypes) then
                                        Just True

                                    else
                                        Just False

                        Err _ ->
                            Just True
                , formSubmissionInProgress =
                    case result of
                        Ok verdict ->
                            if Maybe.withDefault False verdict.addressComplete then
                                True

                            else
                                False

                        Err _ ->
                            True
              }
            , case result of
                Ok verdict ->
                    if Maybe.withDefault False verdict.addressComplete then
                        submitForm True

                    else if List.member "subpremise" (Maybe.withDefault [] verdict.missingComponentTypes) then
                        Task.attempt (\_ -> NoOpMsg) (focus "address_line_two")

                    else
                        Cmd.none

                Err _ ->
                    submitForm True
            )

        SetTime time ->
            ( { model
                | time = time
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )

        SetZone zone ->
            ( { model
                | zone = zone
                , nextAction = NoOpNextAction
              }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ localStorageSaved LocalStorageSaved
        , placeChanged PlaceChanged
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
                    [ div [ class "form-check" ]
                        [ input
                            [ id "order_physical_card"
                            , name "order_physical_card"
                            , type_ "checkbox"
                            , class "form-check-input"
                            , Html.Attributes.value "order_physical_card"
                            , onCheck OrderPhysicalCardChecked
                            , checked model.orderPhysicalCard
                            ]
                            []
                        , label [ for "order_physical_card", class "form-check-label" ]
                            [ text "Order a physical card" ]
                        , div [ class "form-text", class "mb-3" ]
                            [ text "We recommend a physical card for everyone. You will only be able to use it once you activate it ", strong [] [ text " and " ], text " are added to a budget. If you choose not to order one now, you can do so within BILL Spend & Expense later." ]
                        ]
                    ]
                , div [ class "col-12", classList [ ( "d-none", not model.orderPhysicalCard ) ] ]
                    [ label [ for "address_line_one", class "form-label" ] [ text "Mailing Address" ]
                    , input
                        [ type_ "text"
                        , class "form-control"
                        , classList
                            [ ( "is-valid", model.showValidation && (isValid (validateAddressLineOne model.addressLineOne) && Maybe.withDefault True model.addressIsValid) )
                            , ( "is-invalid", model.showValidation && (not (isValid (validateAddressLineOne model.addressLineOne)) || not (Maybe.withDefault True model.addressIsValid)) )
                            ]
                        , id "address_line_one"
                        , name "address_line_one"
                        , minlength 1
                        , maxlength 100
                        , required True
                        , placeholder "Street Address"
                        , onInput AddressLineOneInput
                        , on "change" (succeed FormChanged)
                        , Html.Attributes.value model.addressLineOne
                        , preventDefaultOn "keypress" keyDecoder
                        ]
                        []
                    , div [ class "invalid-feedback" ]
                        [ text
                            (if isValid (validateAddressLineOne model.addressLineOne) then
                                feedbackText (validateAddressLineOneGoogleResult model.addressIsValid)

                             else
                                feedbackText (validateAddressLineOne model.addressLineOne)
                            )
                        ]
                    ]
                , div [ class "col-12", classList [ ( "d-none", not model.orderPhysicalCard ) ] ]
                    [ input
                        [ type_ "text"
                        , class "form-control"
                        , classList
                            [ ( "is-valid", model.showValidation && isValid (validateAddressLineTwo model.addressLineTwo model.addressLineTwoRequired (checkCampusAddress model)) && Maybe.withDefault True model.addressIsValid )
                            , ( "is-invalid", model.showValidation && (not (isValid (validateAddressLineTwo model.addressLineTwo model.addressLineTwoRequired (checkCampusAddress model))) || not (Maybe.withDefault True model.addressIsValid)) )
                            ]
                        , id "address_line_two"
                        , name "address_line_two"
                        , maxlength 100
                        , placeholder "Apt, Suite, Unit, etc. (optional)"
                        , onInput AddressLineTwoInput
                        , on "change" (succeed FormChanged)
                        , Html.Attributes.value model.addressLineTwo
                        ]
                        []
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateAddressLineTwo model.addressLineTwo model.addressLineTwoRequired (checkCampusAddress model))) ]
                    ]
                , div [ class "col-md-6", classList [ ( "d-none", not model.orderPhysicalCard ) ] ]
                    [ label [ for "city", class "form-label" ] [ text "City" ]
                    , input
                        [ type_ "text"
                        , class "form-control"
                        , classList
                            [ ( "is-valid", model.showValidation && isValid (validateCity model.city) && Maybe.withDefault True model.addressIsValid )
                            , ( "is-invalid", model.showValidation && (not (isValid (validateCity model.city)) || not (Maybe.withDefault True model.addressIsValid)) )
                            ]
                        , id "city"
                        , name "city"
                        , minlength 1
                        , maxlength 40
                        , placeholder "City"
                        , required True
                        , onInput CityInput
                        , on "change" (succeed FormChanged)
                        , Html.Attributes.value model.city
                        ]
                        []
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateCity model.city)) ]
                    ]
                , div [ class "col-md-3", class "col-8", classList [ ( "d-none", not model.orderPhysicalCard ) ] ]
                    [ label [ for "state", class "form-label" ] [ text "State" ]
                    , select
                        [ class "form-select"
                        , id "state"
                        , name "state"
                        , minlength 1
                        , maxlength 40
                        , required True
                        , classList
                            [ ( "is-valid", model.showValidation && isValid (validateState model.state) && Maybe.withDefault True model.addressIsValid )
                            , ( "is-invalid", model.showValidation && (not (isValid (validateState model.state)) || not (Maybe.withDefault True model.addressIsValid)) )
                            ]
                        , on "change" (Json.Decode.map StateInput targetValue)
                        ]
                        ([ option
                            [ Html.Attributes.value ""
                            , disabled True
                            , selected
                                (case model.state of
                                    Just _ ->
                                        False

                                    Nothing ->
                                        True
                                )
                            ]
                            [ text "Select..." ]
                         ]
                            ++ List.map (stateTupleToHtmlOption model.state) (sortBy second (toList statesMap))
                        )
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateState model.state)) ]
                    ]
                , div [ class "col-md-3", class "col-4", class "mb-3", classList [ ( "d-none", not model.orderPhysicalCard ) ] ]
                    [ label [ for "zip", class "form-label" ] [ text "ZIP Code" ]
                    , input
                        [ type_ "text"
                        , toAttribute (inputmode numeric)
                        , class "form-control"
                        , id "zip_code"
                        , name "zip_code"
                        , placeholder "ZIP Code"
                        , minlength 5
                        , maxlength 5
                        , required True
                        , onInput ZipInput
                        , on "change" (succeed FormChanged)
                        , Html.Attributes.value model.zip
                        , classList
                            [ ( "is-valid", model.showValidation && isValid (validateZipCode model.zip) && Maybe.withDefault True model.addressIsValid )
                            , ( "is-invalid", model.showValidation && (not (isValid (validateZipCode model.zip)) || not (Maybe.withDefault True model.addressIsValid)) )
                            ]
                        ]
                        []
                    , div [ class "invalid-feedback" ]
                        [ text (feedbackText (validateZipCode model.zip)) ]
                    ]
                , div [ class "col-12 mb-3", classList [ ( "d-none", not model.orderPhysicalCard ) ] ]
                    [ label [ class "form-label" ]
                        [ text "Shipping Method" ]
                    , div [ class "list-group" ]
                        (List.map (shippingMethodToListGroupItem model.shippingMethod model.zone model.time) [ UspsFirstClass, FedEx2Day, FedExOvernight ])
                    , div [ class "form-text", class "mb-3", class "mt-2" ]
                        [ text "Estimated delivery dates include 1-2 days to process your request and print your card before the carrier receives it." ]
                    ]
                , input
                    [ type_ "hidden"
                    , name "shipping_method"
                    , Html.Attributes.value
                        (shippingMethodToLabel model.shippingMethod
                            ++ " ("
                            ++ (case shippingMethodToCost model.shippingMethod == 0 of
                                    True ->
                                        "Free"

                                    False ->
                                        "$" ++ String.fromInt (shippingMethodToCost model.shippingMethod)
                               )
                            ++ ")"
                        )
                    ]
                    []
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
                            , a [ href "https://help.bill.com/direct/s/article/5304326" ] [ text "BILL Help Center" ]
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
                        , disabled (model.nextAction /= NoOpNextAction || model.addressValidationInProgress || model.formSubmissionInProgress)
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


validateAddressLineOne : String -> ValidationResult
validateAddressLineOne addressLineOne =
    if blankString addressLineOne then
        Invalid "Please enter your street address"

    else if String.length (String.trim addressLineOne) > 100 then
        Invalid "Your street address may be a maximum of 100 characters"

    else
        Valid


validateAddressLineOneGoogleResult : Maybe Bool -> ValidationResult
validateAddressLineOneGoogleResult maybeIsValid =
    case maybeIsValid of
        Just False ->
            Invalid "This doesn't appear to be a valid address"

        _ ->
            Valid


validateAddressLineTwo : String -> Bool -> CampusAddress -> ValidationResult
validateAddressLineTwo addressLineTwo required campusAddress =
    if String.length (String.trim addressLineTwo) > 100 then
        Invalid "Your second address line may be a maximum of 100 characters"

    else if blankString addressLineTwo && (required || campusAddress /= NotCampusAddress) then
        Invalid
            ("This address requires "
                ++ (case campusAddress of
                        StudentCenter ->
                            "a mailbox"

                        GraduateLivingCenter ->
                            "an apartment"

                        ManufacturingRelatedDisciplinesComplex ->
                            "a room"

                        NotCampusAddress ->
                            "an apartment or unit"
                   )
                ++ " number"
            )

    else if
        campusAddress
            == StudentCenter
            && not (Regex.contains studentCenterMailboxRegex (String.trim (String.toLower addressLineTwo)))
    then
        Invalid "This doesn't appear to be a valid mailbox number"

    else if
        campusAddress
            == GraduateLivingCenter
            && not (Regex.contains graduateLivingCenterMailboxRegex (String.trim (String.toLower addressLineTwo)))
    then
        Invalid "This doesn't appear to be a valid apartment number"

    else if
        campusAddress
            == ManufacturingRelatedDisciplinesComplex
            && String.trim (String.toLower addressLineTwo)
            /= "rm 1312"
            && String.trim (String.toLower addressLineTwo)
            /= "room 1312"
            && String.trim (String.toLower addressLineTwo)
            /= "mrdc rm 1312"
            && String.trim (String.toLower addressLineTwo)
            /= "mrdc room 1312"
    then
        Invalid "For delivery to the MRDC loading dock, use Room 1312"

    else
        Valid


validateCity : String -> ValidationResult
validateCity city =
    if blankString city then
        Invalid "Please enter your city"

    else if String.length (String.trim city) > 40 then
        Invalid "Your city may be a maximum of 40 characters"

    else
        Valid


validateState : Maybe String -> ValidationResult
validateState selectedState =
    case selectedState of
        Just _ ->
            Valid

        Nothing ->
            Invalid "Please select your state"


validateZipCode : String -> ValidationResult
validateZipCode zipCode =
    if String.length zipCode == 5 && String.all isDigit zipCode then
        Valid

    else
        Invalid "Please enter exactly 5 digits"


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

    else if model.orderPhysicalCard && not (isValid (validateAddressLineOne model.addressLineOne)) then
        Invalid "address_line_one"

    else if
        model.orderPhysicalCard
            && not
                (isValid
                    (validateAddressLineTwo
                        model.addressLineTwo
                        model.addressLineTwoRequired
                        (checkCampusAddress model)
                    )
                )
    then
        Invalid "address_line_two"

    else if model.orderPhysicalCard && not (isValid (validateCity model.city)) then
        Invalid "city"

    else if
        model.orderPhysicalCard
            && (case model.state of
                    Just _ ->
                        False

                    Nothing ->
                        True
               )
    then
        Invalid "state"

    else if model.orderPhysicalCard && not (isValid (validateZipCode model.zip)) then
        Invalid "zip_code"

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


stateTupleToHtmlOption : Maybe String -> ( String, String ) -> Html msg
stateTupleToHtmlOption selectedState ( stateCode, stateName ) =
    option
        [ Html.Attributes.value stateCode
        , selected
            (case selectedState of
                Just selectedStateCode ->
                    selectedStateCode == stateCode

                Nothing ->
                    False
            )
        ]
        [ text stateName ]


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
            , ( "orderPhysicalCard", Json.Encode.bool model.orderPhysicalCard )
            , ( "shippingMethod"
              , case model.shippingMethod of
                    UspsFirstClass ->
                        Json.Encode.string "UspsFirstClass"

                    FedEx2Day ->
                        Json.Encode.string "FedEx2Day"

                    FedExOvernight ->
                        Json.Encode.string "FedExOvernight"
              )
            , ( "addressLineOne", Json.Encode.string (String.trim model.addressLineOne) )
            , ( "addressLineTwo", Json.Encode.string (String.trim model.addressLineTwo) )
            , ( "city", Json.Encode.string (String.trim model.city) )
            , ( "state"
              , case model.state of
                    Just state ->
                        Json.Encode.string state

                    Nothing ->
                        Json.Encode.null
              )
            , ( "zip", Json.Encode.string (String.trim model.zip) )
            ]
        )


keyDecoder : Decoder ( Msg, Bool )
keyDecoder =
    field "key" string
        |> Json.Decode.map
            (\key ->
                ( NoOpMsg, preventDefault key )
            )


preventDefault : String -> Bool
preventDefault key =
    key == "Enter"


decodePlaceChanged : Value -> List AddressComponent
decodePlaceChanged value =
    Result.withDefault []
        (decodeValue
            (field "address_components"
                (Json.Decode.list
                    (Json.Decode.map2 AddressComponent
                        (field "short_name" string)
                        (field "types" (Json.Decode.list string))
                    )
                )
            )
            value
        )


getAddressComponent : List AddressComponent -> String -> String
getAddressComponent components desiredType =
    case List.head (List.filter (addressComponentTypeMatches desiredType) components) of
        Just component ->
            component.value

        Nothing ->
            ""


addressComponentTypeMatches : String -> AddressComponent -> Bool
addressComponentTypeMatches desiredType component =
    List.member desiredType component.types


googleAddressValidationResponseDecoder : Decoder GoogleAddressValidation
googleAddressValidationResponseDecoder =
    Json.Decode.map2 GoogleAddressValidation
        (maybe (at [ "result", "verdict", "addressComplete" ] bool))
        (maybe (at [ "result", "address", "missingComponentTypes" ] (Json.Decode.list string)))


checkCampusAddress : Model -> CampusAddress
checkCampusAddress model =
    if
        String.toLower (String.trim model.addressLineOne)
            == "351 ferst dr nw"
            && String.toLower (String.trim model.city)
            == "atlanta"
            && Maybe.withDefault "" model.state
            == "GA"
            && String.trim model.zip
            == "30332"
    then
        StudentCenter

    else if
        String.toLower (String.trim model.addressLineOne)
            == "301 10th st nw"
            && String.toLower (String.trim model.city)
            == "atlanta"
            && Maybe.withDefault "" model.state
            == "GA"
            && String.trim model.zip
            == "30318"
    then
        GraduateLivingCenter

    else if
        String.toLower (String.trim model.addressLineOne)
            == "801 ferst dr nw"
            && String.toLower (String.trim model.city)
            == "atlanta"
            && Maybe.withDefault "" model.state
            == "GA"
            && String.trim model.zip
            == "30332"
    then
        ManufacturingRelatedDisciplinesComplex

    else if
        String.toLower (String.trim model.addressLineOne)
            == "801 ferst dr"
            && String.toLower (String.trim model.city)
            == "atlanta"
            && Maybe.withDefault "" model.state
            == "GA"
            && String.trim model.zip
            == "30332"
    then
        ManufacturingRelatedDisciplinesComplex

    else
        NotCampusAddress


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
        (Result.withDefault True (decodeString (field "orderPhysicalCard" bool) (Result.withDefault "{}" (decodeValue (field "localData" string) value))))
        (case decodeString (field "shippingMethod" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)) of
            Ok "FedEx2Day" ->
                FedEx2Day

            Ok "FedExOvernight" ->
                FedExOvernight

            _ ->
                UspsFirstClass
        )
        (String.trim
            (Result.withDefault
                (Result.withDefault "" (decodeValue (at [ "serverData", "addressLineOne" ] string) value))
                (decodeString (field "addressLineOne" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
            )
        )
        (String.trim
            (Result.withDefault
                (Result.withDefault "" (decodeValue (at [ "serverData", "addressLineTwo" ] string) value))
                (decodeString (field "addressLineTwo" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
            )
        )
        (String.trim
            (Result.withDefault
                (Result.withDefault "" (decodeValue (at [ "serverData", "city" ] string) value))
                (decodeString (field "city" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
            )
        )
        (case decodeString (field "state" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)) of
            Ok state ->
                if List.member state (Dict.keys statesMap) then
                    Just state

                else
                    Nothing

            Err _ ->
                case decodeValue (at [ "serverData", "state" ] string) value of
                    Ok state ->
                        if List.member state (Dict.keys statesMap) then
                            Just state

                        else
                            Nothing

                    Err _ ->
                        Nothing
        )
        (String.trim
            (Result.withDefault
                (Result.withDefault "" (decodeValue (at [ "serverData", "zip" ] string) value))
                (decodeString (field "zip" string) (Result.withDefault "{}" (decodeValue (field "localData" string) value)))
            )
        )
        False
        Nothing
        False
        False
        False
        False
        False
        False
        (String.trim (Result.withDefault "" (decodeValue (at [ "serverData", "googleMapsApiKey" ] string) value)))
        (String.trim (Result.withDefault "" (decodeValue (at [ "serverData", "googleClientId" ] string) value)))
        (String.trim (Result.withDefault "" (decodeValue (at [ "serverData", "googleOneTapLoginUri" ] string) value)))
        (Time.millisToPosix 0)
        Time.utc
        NoOpNextAction


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


formatTime : Zone -> Posix -> String
formatTime zone time =
    (case toWeekday zone time of
        Mon ->
            "Monday"

        Tue ->
            "Tuesday"

        Wed ->
            "Wednesday"

        Thu ->
            "Thursday"

        Fri ->
            "Friday"

        Sat ->
            "Saturday"

        Sun ->
            "Sunday"
    )
        ++ ", "
        ++ (case toMonth zone time of
                Jan ->
                    "January"

                Feb ->
                    "February"

                Mar ->
                    "March"

                Apr ->
                    "April"

                May ->
                    "May"

                Jun ->
                    "June"

                Jul ->
                    "July"

                Aug ->
                    "August"

                Sep ->
                    "September"

                Oct ->
                    "October"

                Nov ->
                    "November"

                Dec ->
                    "December"
           )
        ++ " "
        ++ String.fromInt (toDay zone time)


estimateUspsFirstClassDeliveryTime : Zone -> Posix -> Posix
estimateUspsFirstClassDeliveryTime zone time =
    case toWeekday zone (addDays time 20.5) of
        Sun ->
            addDays time 19.5

        _ ->
            addDays time 20.5


estimateFedEx2DayDeliveryTime : Zone -> Posix -> Posix
estimateFedEx2DayDeliveryTime zone time =
    case toWeekday zone (addDays time 4.5) of
        Sat ->
            addDays time 6.5

        Sun ->
            addDays time 5.5

        _ ->
            addDays time 4.5


estimateFedExOvernightDeliveryTime : Zone -> Posix -> Posix
estimateFedExOvernightDeliveryTime zone time =
    case toWeekday zone (addDays time 2.5) of
        Sat ->
            addDays time 4.5

        Sun ->
            addDays time 3.5

        _ ->
            addDays time 2.5


addDays : Posix -> Float -> Posix
addDays input days =
    millisToPosix (posixToMillis input + ceiling (days * toFloat dayInMilliseconds))


shippingMethodToLabel : ShippingMethod -> String
shippingMethodToLabel method =
    case method of
        UspsFirstClass ->
            "USPS First Class"

        FedEx2Day ->
            "FedEx 2Day"

        FedExOvernight ->
            "FedEx Standard Overnight"


shippingMethodToCost : ShippingMethod -> Int
shippingMethodToCost method =
    case method of
        UspsFirstClass ->
            0

        FedEx2Day ->
            20

        FedExOvernight ->
            50


shippingMethodToOnClickMsg : ShippingMethod -> Msg
shippingMethodToOnClickMsg method =
    case method of
        UspsFirstClass ->
            UspsFirstClassClicked

        FedEx2Day ->
            FedEx2DayClicked

        FedExOvernight ->
            FedExOvernightClicked


shippingMethodToDeliveryEstimateFn : ShippingMethod -> (Zone -> Posix -> Posix)
shippingMethodToDeliveryEstimateFn method =
    case method of
        UspsFirstClass ->
            estimateUspsFirstClassDeliveryTime

        FedEx2Day ->
            estimateFedEx2DayDeliveryTime

        FedExOvernight ->
            estimateFedExOvernightDeliveryTime


shippingMethodToTrackingDescription : ShippingMethod -> String
shippingMethodToTrackingDescription method =
    case method of
        UspsFirstClass ->
            "No"

        FedEx2Day ->
            "FedEx"

        FedExOvernight ->
            "FedEx"


shippingMethodToIcon : ShippingMethod -> Svg msg
shippingMethodToIcon method =
    case method of
        UspsFirstClass ->
            truckIcon

        FedEx2Day ->
            airplaneIcon

        FedExOvernight ->
            airplaneClockIcon


shippingMethodToListGroupItem : ShippingMethod -> Zone -> Posix -> ShippingMethod -> Html Msg
shippingMethodToListGroupItem selectedMethod zone time thisMethod =
    div [ class "list-group-item", class "list-group-item-action", classList [ ( "active", selectedMethod == thisMethod ) ], onClick (shippingMethodToOnClickMsg thisMethod), style "cursor" "pointer" ]
        [ h6 [ class "mb-1" ]
            [ shippingMethodToIcon thisMethod
            , text (noBreakSpace ++ noBreakSpace ++ shippingMethodToLabel thisMethod)
            ]
        , p [ class "mb-0" ] [ text ("Estimated delivery by " ++ formatTime zone (shippingMethodToDeliveryEstimateFn thisMethod zone time)) ]
        , small []
            [ text
                ((case shippingMethodToCost thisMethod == 0 of
                    True ->
                        "Free"

                    False ->
                        "$" ++ String.fromInt (shippingMethodToCost thisMethod) ++ " fee paid by RoboJackets"
                 )
                    ++ " • "
                    ++ shippingMethodToTrackingDescription thisMethod
                    ++ " tracking"
                )
            ]
        ]



-- PORTS


port submitForm : Bool -> Cmd msg


port initializeAutocomplete : String -> Cmd msg


port initializeOneTap : Bool -> Cmd msg


port saveToLocalStorage : String -> Cmd msg


port localStorageSaved : (Bool -> msg) -> Sub msg


port placeChanged : (Value -> msg) -> Sub msg
