// Opens the real Qt controls in a virtual display, with placeholder tracks.
// No scsynth boot or sound card is required.
(
~erroneusModGuiCompileOnly = true;
thisProcess.interpreter.executeFile("erroneus-mod-gui.scd");
~erroneusSampleGuiCompileOnly = true;
thisProcess.interpreter.executeFile("erroneus-sample-gui.scd");
~erroneusGuiCompileOnly = true;
thisProcess.interpreter.executeFile("erroneus-gui.scd");
if(~erroneusOpenGUI.isNil, {
    "ERRONEUS_GUI_SMOKE_FAILED: loader".postln;
    1.exit;
}, {
    ~erroneusTracks = [nil, nil, nil, nil];
    AppClock.sched(0.1, {
        var status = 0;
        try({
            ~erroneusOpenGUI.value;
            if(~erroneusGuiWindow.isNil, {
                Error("GUI did not create a window").throw;
            });
            if(~erroneusGuiRows.size != 16, {
                Error("Expected 16 slider rows including input gain").throw;
            });
            if(~erroneusGuiMakeDefaults.value(0)[\inputGain] != 0.25, {
                Error("Input gain must default to 0.25").throw;
            });
            if(~erroneusGuiMakeDefaults.value(0)[\scanHz] != 0, {
                Error("Scan must default to 0 for stationary input-capture lookback").throw;
            });
            ~erroneusOpenModGUI.value;
            if(~erroneusModWindow.isNil, {
                Error("Modulation GUI did not create a window").throw;
            });
            if(~erroneusModRows.size != 4, {
                Error("Expected four modulator rows").throw;
            });
            if(~erroneusModRows[0][1].items.size != 14, {
                Error("Expected Off and thirteen modulation destinations").throw;
            });
            ~erroneusOpenSampleGUI.value;
            if(~erroneusSampleWindow.isNil, {
                Error("Sample manager GUI failed to open").throw;
            });
            if(~erroneusSampleLabels.size != 4, {
                Error("Expected four sample-control rows").throw;
            });
            "ERRONEUS_SAMPLE_GUI_SMOKE_OK".postln;
            ~erroneusSampleWindow.close;
            "ERRONEUS_MOD_GUI_SMOKE_OK".postln;
            ~erroneusModWindow.close;
            "ERRONEUS_GUI_SMOKE_OK".postln;
            ~erroneusGuiWindow.close;
        }, { |error|
            error.reportError;
            "ERRONEUS_GUI_SMOKE_FAILED".postln;
            status = 1;
        });
        status.exit;
        nil;
    });
});
)
