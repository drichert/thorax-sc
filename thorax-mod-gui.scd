// Thorax-SC modulation lab: four modulators per selected track.
// Start thorax-v0.scd first. Evaluate this file in the IDE to open the GUI.
// For headless syntax checking: ~thoraxModGuiCompileOnly = true.

(
~thoraxModWaveNames = [
    "Sine", "Triangle", "Stepped random", "Smooth random", "Pulse envelope"
];

~thoraxModTargetNames = [
    "Off", "Position", "Density", "Grain length", "Grain pitch",
    "Scan speed", "Position drift", "Grain mix", "Resonance mix",
    "Resonator pitch", "Resonator decay", "Drive", "Reverb", "Feedback"
];

~thoraxModDefaultStates = {
    Array.fill(4, {
        Array.fill(4, { |index|
            var values;
            values = IdentityDictionary.new;
            values[\wave] = [0, 2, 3, 4][index];
            values[\target] = 0;
            values[\rate] = [0.12, 0.30, 0.60, 1.00][index];
            values[\depth] = 0.0;
            values
        })
    })
};

if(~thoraxModStates.isNil, {
    ~thoraxModStates = ~thoraxModDefaultStates.value;
});

~thoraxModControlName = { |slot, key|
    var suffix;
    suffix = switch(key,
        \wave, { "Wave" },
        \target, { "Target" },
        \rate, { "Rate" },
        \depth, { "Depth" }
    );
    ("mod" ++ (slot + 1).asString ++ suffix).asSymbol
};

~thoraxModUpdate = { |slot, key, value|
    var track;
    track = ~thoraxModSelectedTrack;
    ~thoraxModStates[track][slot][key] = value;
    ~thoraxTracks[track].set(~thoraxModControlName.value(slot, key), value);
};

~thoraxModSendTrack = { |track|
    4.do({ |slot|
        [\wave, \target, \rate, \depth].do({ |key|
            ~thoraxTracks[track].set(
                ~thoraxModControlName.value(slot, key),
                ~thoraxModStates[track][slot][key]
            );
        });
    });
};

~thoraxModRefresh = {
    var states;
    states = ~thoraxModStates[~thoraxModSelectedTrack];
    ~thoraxModRows.do({ |row, slot|
        var state;
        state = states[slot];
        // value_ intentionally does not call the corresponding action.
        row[0].value_(state[\wave]);
        row[1].value_(state[\target]);
        row[2].value_(row[3].unmap(state[\rate]).clip(0, 1));
        row[4].string_(state[\rate].round(0.001).asString ++ " Hz");
        row[5].value_(state[\depth]);
        row[6].string_(state[\depth].round(0.01).asString);
    });
};

~thoraxOpenModGUI = {
    var window, trackSelector, resetButton, disableButton;
    var rateSpec, rows, title, note, rowBuilder;

    if(~thoraxTracks.isNil or: { ~thoraxTracks.size != 4 }, {
        "Start thorax-v0.scd before opening modulation controls.".warn;
    }, {
        if(~thoraxModWindow.notNil, {
            ~thoraxModWindow.front;
        }, {
            ~thoraxModSelectedTrack = 0;
            rows = List.new;
            rateSpec = ControlSpec.new(0.03, 12, \exp);

            window = Window(
                "Thorax-SC | Modulation Lab",
                Rect(190, 140, 890, 520)
            );
            ~thoraxModWindow = window;

            title = StaticText(window, Rect(18, 12, 760, 24));
            title.string_("THORAX-SC  |  FOUR MODULATORS / TRACK");
            title.font_(Font.default.boldVariant);

            StaticText(window, Rect(18, 49, 55, 24)).string_("Track");
            trackSelector = PopUpMenu(window, Rect(76, 49, 138, 24));
            trackSelector.items_([
                "Track 1", "Track 2", "Track 3", "Track 4"
            ]);
            trackSelector.value_(0);

            disableButton = Button(window, Rect(582, 49, 131, 24));
            disableButton.states_([["Disable track"]]);
            disableButton.action_({
                var t;
                t = ~thoraxModSelectedTrack;
                4.do({ |i|
                    ~thoraxModStates[t][i][\depth] = 0;
                    ~thoraxTracks[t].set(
                        ~thoraxModControlName.value(i, \depth), 0
                    );
                });
                ~thoraxModRefresh.value;
            });

            resetButton = Button(window, Rect(725, 49, 148, 24));
            resetButton.states_([["Reset track mods"]]);
            resetButton.action_({
                var defaults, t;
                t = ~thoraxModSelectedTrack;
                defaults = ~thoraxModDefaultStates.value;
                ~thoraxModStates[t] = defaults[t];
                ~thoraxModSendTrack.value(t);
                ~thoraxModRefresh.value;
            });

            StaticText(window, Rect(16, 89, 70, 20)).string_("Slot");
            StaticText(window, Rect(92, 89, 146, 20)).string_("Shape");
            StaticText(window, Rect(246, 89, 176, 20)).string_("Destination");
            StaticText(window, Rect(456, 89, 159, 20)).string_("Rate");
            StaticText(window, Rect(679, 89, 152, 20)).string_("Depth");

            rowBuilder = { |slot|
                var y, label, waveMenu, targetMenu, rateSlider, rateLabel;
                var depthSlider, depthLabel;
                y = 117 + (slot * 80);

                label = StaticText(window, Rect(19, y, 65, 24));
                label.string_("MOD " ++ (slot + 1).asString);

                waveMenu = PopUpMenu(window, Rect(92, y, 146, 26));
                waveMenu.items_(~thoraxModWaveNames);
                waveMenu.action_({ |widget|
                    ~thoraxModUpdate.value(slot, \wave, widget.value);
                });

                targetMenu = PopUpMenu(window, Rect(246, y, 176, 26));
                targetMenu.items_(~thoraxModTargetNames);
                targetMenu.action_({ |widget|
                    ~thoraxModUpdate.value(slot, \target, widget.value);
                });

                rateSlider = Slider(window, Rect(456, y + 2, 144, 20));
                rateLabel = StaticText(window, Rect(605, y, 64, 24));
                rateSlider.action_({ |widget|
                    var hz;
                    hz = rateSpec.map(widget.value);
                    ~thoraxModUpdate.value(slot, \rate, hz);
                    rateLabel.string_(hz.round(0.001).asString ++ " Hz");
                });

                depthSlider = Slider(window, Rect(679, y + 2, 109, 20));
                depthLabel = StaticText(window, Rect(798, y, 75, 24));
                depthSlider.action_({ |widget|
                    ~thoraxModUpdate.value(slot, \depth, widget.value);
                    depthLabel.string_(widget.value.round(0.01).asString);
                });

                rows.add([
                    waveMenu, targetMenu, rateSlider, rateSpec,
                    rateLabel, depthSlider, depthLabel
                ]);
            };

            4.do({ |slot| rowBuilder.value(slot); });
            ~thoraxModRows = rows;

            note = StaticText(window, Rect(18, 444, 846, 62));
            note.string_(
                "Start with a target and low depth (0.1-0.3). " ++
                "Same-target signals combine and clip to +/-1.\n" ++
                "Sine, triangle, and random are bipolar; pulse envelope is positive only.\n" ++
                "Modulation runs in the server; the GUI only configures it."
            );

            trackSelector.action_({ |widget|
                ~thoraxModSelectedTrack = widget.value;
                ~thoraxModRefresh.value;
            });

            window.onClose_({
                ~thoraxModWindow = nil;
                ~thoraxModRows = nil;
            });
            ~thoraxModRefresh.value;
            window.front;
        });
    });
};

if(~thoraxModGuiCompileOnly != true, {
    ~thoraxOpenModGUI.value;
});
)
