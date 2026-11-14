// Erroneus: minimal performance testing panel.
// Load erroneus-v0.scd first and wait for the four tracks to start.
// Then evaluate this entire file in SuperCollider IDE.
// For headless parser validation, set ~erroneusGuiCompileOnly = true first.

(
~erroneusGuiSpecs = [
    // key, label, min, max, warp, initial
    [\amp,       "Level",        0.0,     0.25, \lin, 0.115],
    [\inputGain, "Input gain x", 0.0,      2.0, \lin, 0.25],
    [\grainMix,  "Grain mix",    0.0,     1.0,  \lin, 0.8],
    [\density,   "Grains / sec", 0.0,    40.0,  \lin, 15.0],
    [\grainDur,  "Grain length", 0.018,   1.3,  \exp, 0.22],
    [\pitch,     "Grain pitch", -4.0,     4.0,  \lin, 1.0],
    [\position,  "Position",     0.0,     1.0,  \lin, 0.35],
    [\scanHz,    "Scan Hz",     -0.20,    0.20, \lin, 0.015],
    [\spray,     "Position drift", 0.0,   0.25, \lin, 0.025],
    [\ringMix,   "Resonance",    0.0,     1.0,  \lin, 0.35],
    [\root,      "Resonator Hz", 40.0, 1000.0,  \exp, 110.0],
    [\ringTime,  "Ring decay",   0.02,    0.8,  \exp, 0.15],
    [\drive,     "Drive",        0.0,     1.0,  \lin, 0.15],
    [\space,     "Reverb",       0.0,     1.0,  \lin, 0.35],
    [\feedback,  "Feedback",     0.0,    0.85,  \lin, 0.2],
    [\evolve,    "Random evolve", 0.0,    1.0,  \lin, 0.25]
];

~erroneusGuiMakeDefaults = { |trackIndex|
    var values;
    values = IdentityDictionary.new;
    ~erroneusGuiSpecs.do({ |entry| values[entry[0]] = entry[5] });
    values[\root] = [55.0, 80.0, 135.0, 220.0][trackIndex];
    values[\density] = [12.0, 16.0, 10.0, 19.0][trackIndex];
    values[\pitch] = [1.0, 0.5, 1.5, -0.75][trackIndex];
    values[\freeze] = 0;
    values[\sourceMode] = 0;
    values
};

~erroneusGuiSet = { |key, value|
    var trackIndex;
    trackIndex = ~erroneusGuiSelectedTrack;
    if(~erroneusTracks.notNil and: { ~erroneusTracks.size > trackIndex }, {
        ~erroneusGuiValues[trackIndex][key] = value;
        ~erroneusTracks[trackIndex].set(key, value);
    });
};

~erroneusGuiRefresh = {
    var trackValues;
    trackValues = ~erroneusGuiValues[~erroneusGuiSelectedTrack];

    ~erroneusGuiRows.do({ |row|
        var value;
        value = trackValues[row[0]];
        // value_ does not trigger slider.action. Switching tracks must
        // never send stale values to the newly selected Synth.
        row[1].value_(row[3].unmap(value).clip(0.0, 1.0));
        row[2].string_(value.round(0.001).asString);
    });
    ~erroneusGuiFreezeButton.value_(trackValues[\freeze].asInteger);
    ~erroneusGuiSourceButton.value_(trackValues[\sourceMode].asInteger);
};

~erroneusOpenGUI = {
    var window, trackSelector, freezeButton, sourceButton, resetButton;
    var silenceButton, title, footer, rows, rowFactory;

    if(~erroneusTracks.isNil or: { ~erroneusTracks.size != 4 }, {
        "Start erroneus-v0.scd and wait for all four tracks before opening the GUI.".warn;
    }, {
        if(~erroneusGuiWindow.notNil, {
            ~erroneusGuiWindow.front;
        }, {
            if(~erroneusGuiValues.isNil, {
                ~erroneusGuiValues = Array.fill(4, { |i|
                    ~erroneusGuiMakeDefaults.value(i)
                });
            });
            ~erroneusGuiSelectedTrack = 0;
            rows = List.new;

            window = Window("Erroneus | Control Fluidity Lab", Rect(160, 100, 790, 690));
            ~erroneusGuiWindow = window;

            title = StaticText(window, Rect(18, 12, 740, 22));
            title.string_("ERRONEUS  |  v0.1 sound-shaping controls");
            title.font_(Font.default.boldVariant);

            StaticText(window, Rect(18, 47, 56, 24)).string_("Track");
            trackSelector = PopUpMenu(window, Rect(77, 47, 130, 24));
            trackSelector.items_(["Track 1", "Track 2", "Track 3", "Track 4"]);
            trackSelector.value_(0);

            freezeButton = Button(window, Rect(218, 47, 150, 24));
            freezeButton.states_([
                ["Capture: ON"],
                ["Capture: FROZEN"]
            ]);
            freezeButton.action_({ |button|
                ~erroneusGuiSet.value(\freeze, button.value);
            });

            sourceButton = Button(window, Rect(378, 47, 152, 24));
            sourceButton.states_([
                ["Source: Synth"],
                ["Source: Input"]
            ]);
            sourceButton.action_({ |button|
                ~erroneusGuiSet.value(\sourceMode, button.value);
            });

            resetButton = Button(window, Rect(540, 47, 112, 24));
            resetButton.states_([["Reset track"]]);
            resetButton.action_({
                var i;
                i = ~erroneusGuiSelectedTrack;
                ~erroneusGuiValues[i] = ~erroneusGuiMakeDefaults.value(i);
                ~erroneusGuiValues[i].keysValuesDo({ |key, value|
                    ~erroneusTracks[i].set(key, value);
                });
                ~erroneusGuiRefresh.value;
            });

            silenceButton = Button(window, Rect(663, 47, 110, 24));
            silenceButton.states_([["SILENCE ALL"]]);
            silenceButton.action_({
                4.do({ |i|
                    ~erroneusGuiValues[i][\amp] = 0;
                    ~erroneusGuiValues[i][\feedback] = 0;
                    ~erroneusTracks[i].set(\amp, 0, \feedback, 0);
                });
                ~erroneusGuiRefresh.value;
            });

            rowFactory = { |entry, index|
                var key, spec, y, label, slider, readout;
                key = entry[0];
                spec = ControlSpec.new(entry[2], entry[3], entry[4]);
                y = 90 + (index * 30);
                label = StaticText(window, Rect(18, y, 132, 24));
                label.string_(entry[1]);
                slider = Slider(window, Rect(153, y + 2, 508, 20));
                readout = StaticText(window, Rect(673, y, 95, 24));
                slider.action_({ |widget|
                    var value;
                    value = spec.map(widget.value);
                    ~erroneusGuiSet.value(key, value);
                    readout.string_(value.round(0.001).asString);
                });
                rows.add([key, slider, readout, spec]);
            };
            ~erroneusGuiSpecs.do({ |entry, index|
                rowFactory.value(entry, index);
            });

            footer = StaticText(window, Rect(18, 601, 755, 61));
            footer.string_(
                "Input gain applies to live input only (0 = mute, 1 = unity, 2 = +6 dB).\n"
                ++ "SILENCE ALL sets every track's level and feedback to zero.\n"
                ++ "Numbers reflect changes made in this panel, not external Synth.set commands."
            );

            ~erroneusGuiRows = rows;
            ~erroneusGuiFreezeButton = freezeButton;
            ~erroneusGuiSourceButton = sourceButton;

            trackSelector.action_({ |widget|
                ~erroneusGuiSelectedTrack = widget.value;
                ~erroneusGuiRefresh.value;
            });
            window.onClose_({
                ~erroneusGuiWindow = nil;
                ~erroneusGuiRows = nil;
                ~erroneusGuiFreezeButton = nil;
                ~erroneusGuiSourceButton = nil;
            });
            ~erroneusGuiRefresh.value;
            window.front;
        });
    });
};

if(~erroneusGuiCompileOnly != true, {
    ~erroneusOpenGUI.value;
});
)
