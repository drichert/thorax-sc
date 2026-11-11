// Optional Akai MPD32 control layer for Thorax-SC.
// Load thorax-v0.scd first, then evaluate this file.
// No factory MIDI CC or note numbers are assumed: use MIDI learn.
// For parsing / logic tests without MIDI hardware, set ~thoraxMPD32CompileOnly = true.

(
~thoraxMPD32Map = ~thoraxMPD32Map ?? {
    (
        knobs: Array.fill(8, nil),
        faders: Array.fill(8, nil),
        pads: Array.fill(16, nil)
    )
};

// Learned mappings are [number, channel, kind]; older [number, channel] maps mean CC.
// NRPN numbers and MIDI channels are 0-based, and kind is \cc or \nrpn.
~thoraxMPD32SelectedTrack = ~thoraxMPD32SelectedTrack ?? { 0 };
~thoraxMPD32FreezeStates = ~thoraxMPD32FreezeStates ?? { Array.fill(4, 0) };
~thoraxMPD32Learning = nil;
~thoraxMPD32Monitor = ~thoraxMPD32Monitor ?? { false };

// Deliberately separate hardware input from the Synth.set transport.
// A future modulation/base-parameter layer can replace this function.
~thoraxMPD32SetParam = ~thoraxMPD32SetParam ?? {
    { |trackIndex, key, value|
        if(~thoraxTracks.notNil and: { trackIndex < ~thoraxTracks.size }, {
            ~thoraxTracks[trackIndex].set(key, value);
        });
    }
};

~thoraxMPD32KnobSpecs = [
    [\position, ControlSpec.new(0.0, 1.0, \lin)],
    [\scanHz, ControlSpec.new(-0.15, 0.15, \lin)],
    [\spray, ControlSpec.new(0.0, 0.25, \lin)],
    [\density, ControlSpec.new(0.0, 40.0, \lin)],
    [\grainDur, ControlSpec.new(0.018, 1.3, \exp)],
    [\pitch, ControlSpec.new(-2.0, 2.0, \lin)],
    [\ringMix, ControlSpec.new(0.0, 1.0, \lin)],
    [\feedback, ControlSpec.new(0.0, 0.65, \lin)]
];

~thoraxMPD32EffectSpecs = [
    [\drive, ControlSpec.new(0.0, 1.0, \lin)],
    [\space, ControlSpec.new(0.0, 1.0, \lin)],
    [\grainMix, ControlSpec.new(0.0, 1.0, \lin)],
    [\evolve, ControlSpec.new(0.0, 1.0, \lin)]
];

~thoraxMPD32AmpSpec = [\amp, ControlSpec.new(0.0, 0.20, \lin)];

// These initial values mirror thorax-v0.scd. They are local adapter state,
// not a live query of the synth: GUI and direct Synth.set remain unsynchronized.
~thoraxMPD32Values = Array.fill(4, { |track|
    var values = IdentityDictionary.new;
    values[\position] = 0.35;
    values[\scanHz] = 0.015;
    values[\spray] = 0.025;
    values[\density] = [12.0, 16.0, 10.0, 19.0][track];
    values[\grainDur] = 0.22;
    values[\pitch] = [1.0, 0.5, 1.5, -0.75][track];
    values[\ringMix] = 0.35;
    values[\feedback] = 0.2;
    values[\amp] = 0.115;
    values[\drive] = 0.15;
    values[\space] = 0.35;
    values[\grainMix] = 0.8;
    values[\evolve] = 0.25;
    values
});

// Relative NRPN ticks move 1/512 of the mapped control range by default.
// Knob velocity/acceleration and feel require tuning with real hardware.
~thoraxMPD32RelativeStep = ~thoraxMPD32RelativeStep ?? { 1.0 / 512.0 };
~thoraxMPD32ResetNRPN = {
    ~thoraxMPD32NRPN = Array.fill(16, {
        var state = IdentityDictionary.new;
        state[\addressMSB] = nil;
        state[\addressLSB] = nil;
        state[\dataMSB] = nil;
        state[\active] = false;
        state
    });
};
~thoraxMPD32ResetNRPN.value;

~thoraxMPD32Scale = { |entry, midiValue|
    entry[1].map(midiValue.clip(0, 127).asFloat / 127.0)
};

~thoraxMPD32Lookup = { |family, number, channel, kind = \cc|
    var found = nil;
    ~thoraxMPD32Map[family].do({ |entry, index|
        if(entry.notNil and: {
            (entry[0] == number) and: {
                (entry[1] == channel) and: {
                    (entry.size < 3).if({ \cc }, { entry[2] }) == kind
                }
            }
        }, { found = index; });
    });
    found
};

// Different MIDI message families may reuse the same numeric address.
// Relearning an address only replaces the same kind/channel/family.
~thoraxMPD32Remember = { |family, index, number, channel, kind = \cc|
    var entries = ~thoraxMPD32Map[family];
    if(entries.notNil and: { (index >= 0) and: { index < entries.size } }, {
        entries.do({ |entry, previousIndex|
            if(entry.notNil and: {
                (entry[0] == number) and: {
                    (entry[1] == channel) and: {
                        (entry.size < 3).if({ \cc }, { entry[2] }) == kind
                    }
                }
            }, { entries[previousIndex] = nil; });
        });
        entries[index] = [number, channel, kind];
        ("MPD32 learned " ++ family.asString ++ " " ++ (index + 1)
            ++ ": " ++ kind.asString ++ " " ++ number
            ++ " on channel " ++ (channel + 1)).postln;
    }, { "MPD32: invalid learn slot".warn; });
};

// Kind can be \cc, \nrpn, or \auto (first complete control movement).
~thoraxMPD32LearnControl = { |family, index, kind = \auto|
    if((family == \knobs) or: { family == \faders }, {
        if((index >= 0) and: { index < 8 }, {
            if([\cc, \nrpn, \auto].includes(kind), {
                ~thoraxMPD32Learning = [kind, family, index];
                ("Move MPD32 " ++ family.asString ++ " " ++ (index + 1)
                    ++ " (" ++ kind.asString ++ ")").postln;
            }, { "MPD32: invalid MIDI control type".warn; });
        }, { "MPD32: control slot must be 0..7".warn; });
    }, { "MPD32: learn controls on \\knobs or \\faders".warn; });
};

~thoraxMPD32LearnCC = { |family, index|
    ~thoraxMPD32LearnControl.value(family, index, \cc);
};

~thoraxMPD32LearnNRPN = { |family, index|
    ~thoraxMPD32LearnControl.value(family, index, \nrpn);
};

~thoraxMPD32LearnPad = { |index|
    if((index >= 0) and: { index < 16 }, {
        ~thoraxMPD32Learning = [\note, \pads, index];
        ("Press MPD32 pad " ++ (index + 1)).postln;
    }, { "MPD32: pad slot must be 0..15".warn; });
};

~thoraxMPD32CancelLearn = { ~thoraxMPD32Learning = nil; };

~thoraxMPD32SilenceAll = {
    4.do({ |i|
        ~thoraxMPD32SetParam.value(i, \amp, 0);
        ~thoraxMPD32SetParam.value(i, \feedback, 0);
    });
    "MPD32: SILENCE ALL (levels and feedback set to zero)".postln;
};

// All control protocols meet at this dispatch point. Keeping normalized
// per-track state lets endless relative knobs continue from the last value
// set through this adapter, including when the selected track changes.
~thoraxMPD32ApplyControl = { |family, index, normalized, isRelative = false|
    var track, entry, key, spec, current, target, value;
    track = ~thoraxMPD32SelectedTrack;
    if(family == \knobs, {
        entry = ~thoraxMPD32KnobSpecs[index];
    }, {
        if(index < 4, {
            entry = ~thoraxMPD32AmpSpec;
            track = index;
        }, {
            entry = ~thoraxMPD32EffectSpecs[index - 4];
        });
    });
    key = entry[0];
    spec = entry[1];
    current = ~thoraxMPD32Values[track][key];
    target = if(isRelative, {
        spec.unmap(current).clip(0.0, 1.0) + normalized;
    }, { normalized });
    target = target.clip(0.0, 1.0);
    value = spec.map(target);
    ~thoraxMPD32Values[track][key] = value;
    ~thoraxMPD32SetParam.value(track, key, value);
};

// Called ONLY after a valid NRPN parameter selection and a data event.
// In relative mode the parameter value lives here, not on the hardware.
~thoraxMPD32DispatchNRPN = { |number, channel, value, isRelative = false|
    var learned = ~thoraxMPD32Learning;
    var knob, fader, normalized;

    if(learned.notNil and: {
        (learned[0] == \nrpn) or: { learned[0] == \auto }
    }, {
        ~thoraxMPD32Remember.value(learned[1], learned[2], number, channel, \nrpn);
        ~thoraxMPD32Learning = nil;
    }, {
        knob = ~thoraxMPD32Lookup.value(\knobs, number, channel, \nrpn);
        fader = ~thoraxMPD32Lookup.value(\faders, number, channel, \nrpn);
        normalized = if(isRelative, {
            value.asFloat * ~thoraxMPD32RelativeStep
        }, {
            value.clip(0, 16383).asFloat / 16383.0
        });
        if(knob.notNil, {
            ~thoraxMPD32ApplyControl.value(\knobs, knob, normalized, isRelative);
        });
        if(fader.notNil, {
            ~thoraxMPD32ApplyControl.value(\faders, fader, normalized, isRelative);
        });
    });
};

// NRPN CC bytes: 99/98 select the 14-bit parameter, 6/38 set its
// absolute 14-bit value, and 96/97 increment/decrement it. State is
// isolated per MIDI channel; RPN selection (101/100) cancels NRPN.
~thoraxMPD32HandleNRPNCC = { |value, number, channel|
    var state = ~thoraxMPD32NRPN[channel];
    var address;
    if(number == 99, {
        state[\addressMSB] = value;
        state[\addressLSB] = nil;
        state[\dataMSB] = nil;
        state[\active] = true;
    });
    if(number == 98, {
        state[\addressLSB] = value;
        state[\dataMSB] = nil;
        state[\active] = true;
    });
    if((number == 101) or: { number == 100 }, {
        state[\active] = false;
        state[\addressMSB] = nil;
        state[\addressLSB] = nil;
        state[\dataMSB] = nil;
    });

    if(state[\active] and: {
        state[\addressMSB].notNil and: { state[\addressLSB].notNil }
    }, {
        address = (state[\addressMSB] * 128) + state[\addressLSB];
        if(number == 6, {
            state[\dataMSB] = value;
            // Coarse fallback for transmitters that never send CC38.
            ~thoraxMPD32DispatchNRPN.value(address, channel, value * 128);
        });
        if((number == 38) and: { state[\dataMSB].notNil }, {
            ~thoraxMPD32DispatchNRPN.value(
                address, channel, (state[\dataMSB] * 128) + value
            );
        });
        if(number == 96, {
            ~thoraxMPD32DispatchNRPN.value(
                address, channel, value.max(1), true
            );
        });
        if(number == 97, {
            ~thoraxMPD32DispatchNRPN.value(
                address, channel, value.max(1).neg, true
            );
        });
    });
};

~thoraxMPD32HandleCC = { |value, number, channel|
    var learned = ~thoraxMPD32Learning;
    var knob, fader;

    if(~thoraxMPD32Monitor, {
        ("MPD32 CC " ++ number ++ " value " ++ value
            ++ " channel " ++ (channel + 1)).postln;
    });

    if([99, 98, 6, 38, 96, 97, 101, 100].includes(number), {
        // Never MIDI-learn NRPN address/data bytes as ordinary CC.
        ~thoraxMPD32HandleNRPNCC.value(value, number, channel);
    }, {
        if(learned.notNil and: {
            (learned[0] == \cc) or: { learned[0] == \auto }
        }, {
            ~thoraxMPD32Remember.value(learned[1], learned[2], number, channel, \cc);
            ~thoraxMPD32Learning = nil;
        }, {
            knob = ~thoraxMPD32Lookup.value(\knobs, number, channel, \cc);
            fader = ~thoraxMPD32Lookup.value(\faders, number, channel, \cc);
            if(knob.notNil, {
                ~thoraxMPD32ApplyControl.value(\knobs, knob, value.asFloat / 127.0);
            });
            if(fader.notNil, {
                ~thoraxMPD32ApplyControl.value(\faders, fader, value.asFloat / 127.0);
            });
        });
    });
};

~thoraxMPD32HandleNoteOn = { |velocity, number, channel|
    var learned = ~thoraxMPD32Learning;
    var pad;

    if(~thoraxMPD32Monitor, {
        ("MPD32 note " ++ number ++ " velocity " ++ velocity
            ++ " channel " ++ (channel + 1)).postln;
    });

    // Some pad presets send noteOn velocity 0 as a note-off.
    if(velocity > 0, {
        if(learned.notNil and: { learned[0] == \note }, {
            ~thoraxMPD32Remember.value(\pads, learned[2], number, channel);
            ~thoraxMPD32Learning = nil;
        }, {
            pad = ~thoraxMPD32Lookup.value(\pads, number, channel);
            if(pad.notNil, {
                if(pad < 4, {
                    ~thoraxMPD32SelectedTrack = pad;
                    ("MPD32 selected track " ++ (pad + 1)).postln;
                });
                if((pad >= 4) and: { pad < 8 }, {
                    ~thoraxMPD32FreezeStates[pad - 4] =
                        1 - ~thoraxMPD32FreezeStates[pad - 4];
                    ~thoraxMPD32SetParam.value(
                        pad - 4, \freeze, ~thoraxMPD32FreezeStates[pad - 4]
                    );
                });
                if(pad == 15, { ~thoraxMPD32SilenceAll.value; });
                // Pads 9-15 are intentionally unassigned for future scenes/macros.
            });
        });
    });
};

~thoraxMPD32DumpMap = {
    (
        "~thoraxMPD32Map = (\n"
        ++ "    knobs: " ++ ~thoraxMPD32Map[\knobs].asCompileString ++ ",\n"
        ++ "    faders: " ++ ~thoraxMPD32Map[\faders].asCompileString ++ ",\n"
        ++ "    pads: " ++ ~thoraxMPD32Map[\pads].asCompileString ++ "\n"
        ++ ");"
    ).postln;
};

~thoraxMPD32Stop = {
    if(~thoraxMPD32CCDef.notNil, {
        ~thoraxMPD32CCDef.free;
        ~thoraxMPD32CCDef = nil;
    });
    if(~thoraxMPD32NoteDef.notNil, {
        ~thoraxMPD32NoteDef.free;
        ~thoraxMPD32NoteDef = nil;
    });
    ~thoraxMPD32Learning = nil;
    ~thoraxMPD32ResetNRPN.value;
    "MPD32 MIDI handlers stopped".postln;
};

~thoraxMPD32Start = {
    var source, label;
    ~thoraxMPD32Stop.value;
    MIDIClient.init;

    source = if(~thoraxMPD32SourceUID.notNil, {
        MIDIClient.sources.detect({ |item| item.uid == ~thoraxMPD32SourceUID })
    }, {
        MIDIClient.sources.detect({ |item|
            label = (item.device.asString ++ " " ++ item.name.asString).toLower;
            label.find("mpd32").notNil
        })
    });

    if(source.isNil, {
        "MPD32 not found. Available MIDI input sources:".warn;
        MIDIClient.sources.do({ |item|
            (item.device.asString ++ " / " ++ item.name.asString
                ++ " | uid " ++ item.uid.asString).postln;
        });
        "Set ~thoraxMPD32SourceUID and retry if device naming differs.".postln;
    }, {
        ~thoraxMPD32Source = source;
        MIDIIn.connect(0, source.uid);
        ~thoraxMPD32CCDef = MIDIdef.cc(\thoraxMPD32CC,
            { |value, number, channel, src|
                ~thoraxMPD32HandleCC.value(value, number, channel);
            }, nil, nil, source.uid
        );
        ~thoraxMPD32NoteDef = MIDIdef.noteOn(\thoraxMPD32NoteOn,
            { |velocity, number, channel, src|
                ~thoraxMPD32HandleNoteOn.value(velocity, number, channel);
            }, nil, nil, source.uid
        );
        ("MPD32 connected: " ++ source.device.asString
            ++ " / " ++ source.name.asString).postln;
        "Use MIDI learn before controlling an unassigned physical control.".postln;
    });
};

if(~thoraxMPD32CompileOnly != true, { ~thoraxMPD32Start.value; });
)
