// Headless SynthDef, GUI, and optional MIDI adapter validation.
// Run from repository root with: sclang -D tests/compile.scd
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

    // Parse and exercise the control adapter without accessing a MIDI port.
    ~thoraxMPD32CompileOnly = true;
    thisProcess.interpreter.executeFile("thorax-mpd32.scd");
    if(~thoraxMPD32Start.isNil or: { ~thoraxMPD32HandleCC.isNil }, {
        Error("MPD32 adapter functions were not loaded").throw;
    });
    ~thoraxMPD32Remember.value(\knobs, 0, 74, 0);
    if(~thoraxMPD32Lookup.value(\knobs, 74, 0) != 0, {
        Error("MPD32 CC lookup failed").throw;
    });
    if(~thoraxMPD32Lookup.value(\knobs, 74, 1).notNil, {
        Error("MPD32 CC channel filtering failed").throw;
    });
    ~thoraxMPD32Remember.value(\knobs, 1, 74, 0);
    if(~thoraxMPD32Lookup.value(\knobs, 74, 0) != 1, {
        Error("MPD32 CC relearn did not replace old assignment").throw;
    });
    if(~thoraxMPD32Map[\knobs][0].notNil, {
        Error("MPD32 CC duplicate assignment retained").throw;
    });
    ~thoraxMPD32Remember.value(\knobs, 0, 75, 0);
    ~thoraxMPD32SelectedTrack = 2;
    ~thoraxMPD32Last = nil;
    ~thoraxMPD32SetParam = { |trackIndex, key, value|
        ~thoraxMPD32Last = [trackIndex, key, value];
    };
    ~thoraxMPD32HandleCC.value(127, 75, 0);
    if(~thoraxMPD32Last[0] != 2 or: {
        ~thoraxMPD32Last[1] != \position
    }, {
        Error("MPD32 CC dispatch failed").throw;
    });
    if(~thoraxMPD32Last[2] != 1.0, {
        Error("MPD32 knob scaling failed").throw;
    });
    if(~thoraxMPD32Scale.value(~thoraxMPD32KnobSpecs[7], 127) > 0.65, {
        Error("MPD32 feedback range exceeds safety limit").throw;
    });

    ~thoraxMPD32Remember.value(\pads, 0, 36, 9);
    ~thoraxMPD32HandleNoteOn.value(100, 36, 9);
    if(~thoraxMPD32SelectedTrack != 0, {
        Error("MPD32 pad track selection failed").throw;
    });
    ~thoraxMPD32HandleNoteOn.value(0, 36, 9);
    if(~thoraxMPD32SelectedTrack != 0, {
        Error("MPD32 zero-velocity note should be ignored").throw;
    });
    "THORAX_MPD32_COMPILE_OK".postln;
}, { |error|
    "THORAX_COMPILE_FAILED".postln;
    error.reportError;
    exitCode = 1;
});
exitCode.exit;
)
