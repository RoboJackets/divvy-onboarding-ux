const app = Elm.Main.init(
    {
        flags: {
            serverData: window.serverData,
            localData: localStorage.getItem("formFields"),
        }
    }
);

app.ports.submitForm.subscribe(function (message) {
    document.getElementsByTagName("form").item(0).submit()
});

app.ports.saveToLocalStorage.subscribe(function (message) {
    localStorage.setItem("formFields", message);
    app.ports.localStorageSaved.send(true);
});

app.ports.initializeOneTap.subscribe(function (message) {
    script = document.createElement('script');
    script.type = 'text/javascript';
    script.async = true;
    script.src = "https://accounts.google.com/gsi/client";

    document.getElementsByTagName("head").item(0).appendChild(script);
})
