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

// MIDI learn entries are [MIDI number, channel] pairs (channels are 0-based).
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

~thoraxMPD32Scale = { |entry, midiValue|
    entry[1].map(midiValue.clip(0, 127).asFloat / 127.0)
};

~thoraxMPD32Lookup = { |family, number, channel|
    var found = nil;
    ~thoraxMPD32Map[family].do({ |entry, index|
        if(entry.notNil and: {
            (entry[0] == number) and: { entry[1] == channel }
        }, {
            found = index;
        });
    });
    found
};

// Relearning a MIDI number removes its old assignment in the same family.
~thoraxMPD32Remember = { |family, index, number, channel|
    var entries = ~thoraxMPD32Map[family];
    if(entries.notNil and: { (index >= 0) and: { index < entries.size } }, {
        entries.do({ |entry, previousIndex|
            if(entry.notNil and: {
                (entry[0] == number) and: { entry[1] == channel }
            }, {
                entries[previousIndex] = nil;
            });
        });
        entries[index] = [number, channel];
        ("MPD32 learned " ++ family.asString ++ " " ++ (index + 1)
            ++ ": " ++ number ++ " on channel " ++ (channel + 1)).postln;
    }, {
        "MPD32: invalid learn slot".warn;
    });
};

~thoraxMPD32LearnCC = { |family, index|
    if((family == \knobs) or: { family == \faders }, {
        if((index >= 0) and: { index < 8 }, {
            ~thoraxMPD32Learning = [\cc, family, index];
            ("Move MPD32 " ++ family.asString ++ " " ++ (index + 1)).postln;
        }, { "MPD32: CC slot must be 0..7".warn; });
    }, { "MPD32: learn CC on \\knobs or \\faders".warn; });
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

~thoraxMPD32HandleCC = { |value, number, channel|
    var learned = ~thoraxMPD32Learning;
    var knob, fader, entry, track;

    if(~thoraxMPD32Monitor, {
        ("MPD32 CC " ++ number ++ " value " ++ value
            ++ " channel " ++ (channel + 1)).postln;
    });

    if(learned.notNil and: { learned[0] == \cc }, {
        ~thoraxMPD32Remember.value(learned[1], learned[2], number, channel);
        ~thoraxMPD32Learning = nil;
    }, {
        knob = ~thoraxMPD32Lookup.value(\knobs, number, channel);
        fader = ~thoraxMPD32Lookup.value(\faders, number, channel);
        track = ~thoraxMPD32SelectedTrack;

        if(knob.notNil, {
            entry = ~thoraxMPD32KnobSpecs[knob];
            ~thoraxMPD32SetParam.value(
                track, entry[0], ~thoraxMPD32Scale.value(entry, value)
            );
        });

        if(fader.notNil, {
            if(fader < 4, {
                // Physical faders 1-4 always control individual track levels.
                ~thoraxMPD32SetParam.value(
                    fader, \amp, ~thoraxMPD32Scale.value(~thoraxMPD32AmpSpec, value)
                );
            }, {
                entry = ~thoraxMPD32EffectSpecs[fader - 4];
                ~thoraxMPD32SetParam.value(
                    track, entry[0], ~thoraxMPD32Scale.value(entry, value)
                );
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
