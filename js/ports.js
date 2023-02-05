function initializePorts() {
    app.ports.submitForm.subscribe(function (message) {
        document.getElementsByTagName("form").item(0).submit()
    });

    app.ports.saveToLocalStorage.subscribe(function (message) {
        localStorage.setItem("formFields", message);
        app.ports.localStorageSaved.send(true);
    });
}
