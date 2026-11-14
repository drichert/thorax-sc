// Headless SynthDef validation. Run from repository root with:
// sclang -D tests/compile.scd
(
var exitCode = 0;
~thoraxCompileOnly = true;
try({
    thisProcess.interpreter.executeFile("thorax-v0.scd");
    if(~thoraxMakeTrackDef.isNil, {
        Error("Thorax track SynthDef factory was not loaded").throw;
    });
    ~thoraxMakeTrackDef.value.asBytes;
    "THORAX_COMPILE_OK".postln;
    ~thoraxGuiCompileOnly = true;
    thisProcess.interpreter.executeFile("thorax-gui.scd");
    if(~thoraxOpenGUI.isNil, {
        Error("Thorax GUI function was not loaded").throw;
    });
    "THORAX_GUI_COMPILE_OK".postln;
    ~thoraxModGuiCompileOnly = true;
    thisProcess.interpreter.executeFile("thorax-mod-gui.scd");
    if(~thoraxOpenModGUI.isNil, {
        Error("Thorax modulation GUI function was not loaded").throw;
    });
    if(~thoraxModTargetNames.size != 14, {
        Error("Expected Off plus 13 modulation destinations").throw;
    });
    if(~thoraxModControlName.value(0, \wave) != \mod1Wave, {
        Error("Modulator control naming mismatch").throw;
    });
    if(~thoraxModControlName.value(3, \depth) != \mod4Depth, {
        Error("Fourth modulator control naming mismatch").throw;
    });
    if(~thoraxModStates.every({ |tracks|
        tracks.every({ |slot| (slot[\depth] == 0) and: { slot[\target] == 0 } })
    }).not, {
        Error("Modulators must start disconnected and silent").throw;
    });
    "THORAX_MOD_COMPILE_OK".postln;
    // The sample manager lives in thorax-v0.scd and uses the same
    // independently allocated capture buffers regardless of file selection.
    if(~thoraxLoadSample.isNil or: { ~thoraxUseSample.isNil }, {
        Error("Sample loading API was not installed").throw;
    });
    if(~thoraxUseCapture.isNil or: { ~thoraxUnloadSample.isNil }, {
        Error("Sample buffer lifecycle API was not installed").throw;
    });
    if(~thoraxSampleMaxSeconds != 60, {
        Error("Unexpected maximum sample duration").throw;
    });
    if(~thoraxSampleValidTrack.value(0), {
        Error("Track access must be disabled before boot").throw;
    });
    ~thoraxSampleGuiCompileOnly = true;
    thisProcess.interpreter.executeFile("thorax-sample-gui.scd");
    if(~thoraxOpenSampleGUI.isNil or: { ~thoraxSampleRefresh.isNil }, {
        Error("Sample GUI did not load").throw;
    });
    "THORAX_SAMPLE_COMPILE_OK".postln;
}, { |error|
    "THORAX_COMPILE_FAILED".postln;
    error.reportError;
    exitCode = 1;
});
exitCode.exit;
)
