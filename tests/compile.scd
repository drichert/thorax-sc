// Run from the repository root with: sclang -D tests/compile.scd
// This compiles the SynthDef graph without starting the audio server.
(
~thoraxCompileOnly = true;
thisProcess.interpreter.executeFile("thorax-v0.scd");
if(~thoraxMakeTrackDef.isNil, {
    Error("Thorax track SynthDef factory was not loaded").throw;
});
~thoraxMakeTrackDef.value.asBytes;
"THORAX_COMPILE_OK".postln;
0.exit;
)
