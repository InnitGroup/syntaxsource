setInterval(function() {
    if (document.hasFocus()) {
        fetch('/presence')
    }
}, 50000);