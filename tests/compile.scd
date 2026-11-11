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

    // Standard absolute NRPN (CC99/98 address, CC6/38 data).
    ~thoraxMPD32Remember.value(\knobs, 0, 300, 0, \nrpn);
    if(~thoraxMPD32Lookup.value(\knobs, 300, 0, \nrpn) != 0, {
        Error("MPD32 NRPN mapping lookup failed").throw;
    });
    if(~thoraxMPD32Lookup.value(\knobs, 300, 0, \cc).notNil, {
        Error("MPD32 CC and NRPN mappings collided").throw;
    });
    ~thoraxMPD32SelectedTrack = 0;
    ~thoraxMPD32Last = nil;
    ~thoraxMPD32HandleCC.value(2, 99, 0);
    ~thoraxMPD32HandleCC.value(44, 98, 0);
    if(~thoraxMPD32Last.notNil, {
        Error("MPD32 NRPN address bytes dispatched without data").throw;
    });
    ~thoraxMPD32HandleCC.value(64, 6, 0);
    ~thoraxMPD32HandleCC.value(1, 38, 0);
    if(~thoraxMPD32Last[1] != \position or: {
        (~thoraxMPD32Last[2] - (8193.0 / 16383.0)).abs > 0.00001
    }, {
        Error("MPD32 14-bit NRPN scaling or dispatch failed").throw;
    });

    // Increment and decrement operate on the current value, not a fixed
    // hardware position, and preserve independent state for each track.
    ~thoraxMPD32HandleCC.value(0, 96, 0);
    if((~thoraxMPD32Last[2] - ((8193.0 / 16383.0) + (1.0 / 512.0))).abs > 0.00001, {
        Error("MPD32 relative NRPN increment failed").throw;
    });
    ~thoraxMPD32HandleCC.value(0, 97, 0);
    if((~thoraxMPD32Last[2] - (8193.0 / 16383.0)).abs > 0.00001, {
        Error("MPD32 relative NRPN decrement failed").throw;
    });
    ~thoraxMPD32SelectedTrack = 1;
    ~thoraxMPD32HandleCC.value(0, 96, 0);
    if(~thoraxMPD32Last[0] != 1 or: {
        (~thoraxMPD32Last[2] - (0.35 + (1.0 / 512.0))).abs > 0.00001
    }, {
        Error("MPD32 NRPN per-track relative state failed").throw;
    });

    // MIDI channel state must be isolated even when NRPN addresses match.
    ~thoraxMPD32Remember.value(\knobs, 1, 300, 1, \nrpn);
    ~thoraxMPD32Last = nil;
    ~thoraxMPD32HandleCC.value(2, 99, 1);
    ~thoraxMPD32HandleCC.value(44, 98, 1);
    ~thoraxMPD32HandleCC.value(127, 6, 1);
    ~thoraxMPD32HandleCC.value(127, 38, 1);
    if(~thoraxMPD32Last[1] != \scanHz or: {
        (~thoraxMPD32Last[2] - 0.15).abs > 0.00001
    }, {
        Error("MPD32 NRPN channel isolation or upper boundary failed").throw;
    });
    ~thoraxMPD32Last = nil;
    ~thoraxMPD32HandleCC.value(0, 101, 1);
    ~thoraxMPD32HandleCC.value(0, 6, 1);
    if(~thoraxMPD32Last.notNil, {
        Error("MPD32 RPN selection did not cancel NRPN").throw;
    });

    // NRPN learn waits for data, never learns internal CC 99/98/6/38.
    ~thoraxMPD32LearnNRPN.value(\knobs, 3);
    ~thoraxMPD32HandleCC.value(3, 99, 0);
    ~thoraxMPD32HandleCC.value(4, 98, 0);
    if(~thoraxMPD32Learning.isNil, {
        Error("MPD32 NRPN learn completed before data arrived").throw;
    });
    ~thoraxMPD32HandleCC.value(0, 96, 0);
    if(~thoraxMPD32Lookup.value(\knobs, 388, 0, \nrpn) != 3, {
        Error("MPD32 relative NRPN learn failed").throw;
    });
    ~thoraxMPD32LearnCC.value(\knobs, 2);
    ~thoraxMPD32HandleCC.value(0, 99, 0);
    ~thoraxMPD32HandleCC.value(0, 98, 0);
    if(~thoraxMPD32Learning.isNil, {
        Error("MPD32 CC learn incorrectly captured an NRPN address byte").throw;
    });
    ~thoraxMPD32HandleCC.value(76, 70, 0);
    if(~thoraxMPD32Lookup.value(\knobs, 70, 0, \cc) != 2, {
        Error("MPD32 CC learn broke with NRPN support").throw;
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
