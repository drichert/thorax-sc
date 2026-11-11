// Opens the real Qt controls in a virtual display, with placeholder tracks.
// No scsynth boot or sound card is required.
(
~thoraxModGuiCompileOnly = true;
thisProcess.interpreter.executeFile("thorax-mod-gui.scd");
~thoraxGuiCompileOnly = true;
thisProcess.interpreter.executeFile("thorax-gui.scd");
if(~thoraxOpenGUI.isNil, {
    "THORAX_GUI_SMOKE_FAILED: loader".postln;
    1.exit;
}, {
    ~thoraxTracks = [nil, nil, nil, nil];
    AppClock.sched(0.1, {
        var status = 0;
        try({
            ~thoraxOpenGUI.value;
            if(~thoraxGuiWindow.isNil, {
                Error("GUI did not create a window").throw;
            });
            if(~thoraxGuiRows.size != 15, {
                Error("Expected 15 slider rows").throw;
            });
            ~thoraxOpenModGUI.value;
            if(~thoraxModWindow.isNil, {
                Error("Modulation GUI did not create a window").throw;
            });
            if(~thoraxModRows.size != 4, {
                Error("Expected four modulator rows").throw;
            });
            if(~thoraxModRows[0][1].items.size != 14, {
                Error("Expected Off and thirteen modulation destinations").throw;
            });
            "THORAX_MOD_GUI_SMOKE_OK".postln;
            ~thoraxModWindow.close;
            "THORAX_GUI_SMOKE_OK".postln;
            ~thoraxGuiWindow.close;
        }, { |error|
            error.reportError;
            "THORAX_GUI_SMOKE_FAILED".postln;
            status = 1;
        });
        status.exit;
        nil;
    });
});
)
