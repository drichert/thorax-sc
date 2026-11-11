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
}, { |error|
    "THORAX_COMPILE_FAILED".postln;
    error.reportError;
    exitCode = 1;
});
exitCode.exit;
)
