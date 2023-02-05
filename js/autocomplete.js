let autocomplete;

function initializeAutocomplete() {
    const addressLineOneInput = document.getElementById("address_line_one");

    autocomplete = new google.maps.places.Autocomplete(addressLineOneInput, {
        "componentRestrictions": {"country": ["us"]},
        "fields": ["address_components"],
        "types": ["address"],
    })

    autocomplete.addListener("place_changed", placeChanged);
}

function placeChanged () {
    app.ports.placeChanged.send(autocomplete.getPlace());
}
