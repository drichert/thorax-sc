// Headless SynthDef validation. Run from repository root with:
// sclang -D tests/compile.scd
(
var exitCode = 0;
~erroneusCompileOnly = true;
try({
    thisProcess.interpreter.executeFile("erroneus-v0.scd");
    if(~erroneusMakeTrackDef.isNil, {
        Error("Erroneus track SynthDef factory was not loaded").throw;
    });
    ~erroneusMakeTrackDef.value.asBytes;
    "ERRONEUS_COMPILE_OK".postln;
    ~erroneusGuiCompileOnly = true;
    thisProcess.interpreter.executeFile("erroneus-gui.scd");
    if(~erroneusOpenGUI.isNil, {
        Error("Erroneus GUI function was not loaded").throw;
    });
    "ERRONEUS_GUI_COMPILE_OK".postln;
    ~erroneusModGuiCompileOnly = true;
    thisProcess.interpreter.executeFile("erroneus-mod-gui.scd");
    if(~erroneusOpenModGUI.isNil, {
        Error("Erroneus modulation GUI function was not loaded").throw;
    });
    if(~erroneusModTargetNames.size != 14, {
        Error("Expected Off plus 13 modulation destinations").throw;
    });
    if(~erroneusModControlName.value(0, \wave) != \mod1Wave, {
        Error("Modulator control naming mismatch").throw;
    });
    if(~erroneusModControlName.value(3, \depth) != \mod4Depth, {
        Error("Fourth modulator control naming mismatch").throw;
    });
    if(~erroneusModStates.every({ |tracks|
        tracks.every({ |slot| (slot[\depth] == 0) and: { slot[\target] == 0 } })
    }).not, {
        Error("Modulators must start disconnected and silent").throw;
    });
    "ERRONEUS_MOD_COMPILE_OK".postln;
    // The sample manager lives in erroneus-v0.scd and uses the same
    // independently allocated capture buffers regardless of file selection.
    if(~erroneusLoadSample.isNil or: { ~erroneusUseSample.isNil }, {
        Error("Sample loading API was not installed").throw;
    });
    if(~erroneusUseCapture.isNil or: { ~erroneusUnloadSample.isNil }, {
        Error("Sample buffer lifecycle API was not installed").throw;
    });
    if(~erroneusSampleMaxSeconds != 60, {
        Error("Unexpected maximum sample duration").throw;
    });
    if(~erroneusSampleValidTrack.value(0), {
        Error("Track access must be disabled before boot").throw;
    });
    ~erroneusSampleGuiCompileOnly = true;
    thisProcess.interpreter.executeFile("erroneus-sample-gui.scd");
    if(~erroneusOpenSampleGUI.isNil or: { ~erroneusSampleRefresh.isNil }, {
        Error("Sample GUI did not load").throw;
    });
    "ERRONEUS_SAMPLE_COMPILE_OK".postln;
}, { |error|
    "ERRONEUS_COMPILE_FAILED".postln;
    error.reportError;
    exitCode = 1;
});
exitCode.exit;
)
