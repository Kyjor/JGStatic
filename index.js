// game_loop returns 1 to keep running. 0 quits. -1 means startup failed.
window.onModuleReady = function () {
    if (typeof Module._game_loop !== "function") {
        console.error("Missing game_loop — rebuild with ./build_web.sh");
        return;
    }

    function frame() {
        if (Module._game_loop() === 1) {
            requestAnimationFrame(frame);
        }
    }

    requestAnimationFrame(frame);
};
