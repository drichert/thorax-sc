// Erroneus: non-destructive per-track sample manager.
// Start erroneus-v0.scd first, then evaluate this file in SuperCollider IDE.
// Requires no quarks. SoundFile/Buffer decoding supports WAV and AIFF.
//
// Four tracks retain independent live capture histories. Selecting Sample
// reads the loaded mono file buffer; selecting Capture returns to the original
// live ring buffer. The file buffers are freed only after the Synth switches.

(
~erroneusSampleRefresh = {
    if(~erroneusSampleLabels.notNil, {
        ~erroneusSampleLabels.do({ |label, index|
            var status, mode, indicator;
            status = if(~erroneusSampleStatus.notNil, {
                ~erroneusSampleStatus[index]
            }, { "Start the audio engine" });
            mode = if(~erroneusSampleModes.notNil, {
                ~erroneusSampleModes[index]
            }, { 0 });
            indicator = if(mode == 1, { "[SAMPLE] " }, { "[CAPTURE] " });
            label.string_(indicator ++ status);
        });
    });
};

~erroneusOpenSampleGUI = {
    var window, heading, note, labels, makeRow;
    if(~erroneusTracks.isNil or: { ~erroneusTracks.size != 4 }, {
        "Start erroneus-v0.scd and wait for all four tracks.".warn;
    }, {
        if(~erroneusSampleWindow.notNil, {
            ~erroneusSampleWindow.front;
        }, {
            window = Window(
                "Erroneus | Sample & Capture",
                Rect(210, 165, 960, 380)
            );
            ~erroneusSampleWindow = window;
            heading = StaticText(window, Rect(18, 12, 900, 27));
            heading.string_("ERRONEUS  |  SAMPLES AND LIVE CAPTURE");
            heading.font_(Font.default.boldVariant);

            labels = Array.newClear(4);
            makeRow = { |index|
                var y, trackLabel, loadButton, sampleButton;
                var captureButton, unloadButton, statusLabel;

                y = 54 + (index * 58);
                trackLabel = StaticText(window, Rect(18, y, 70, 24));
                trackLabel.string_("Track " ++ (index + 1));

                loadButton = Button(window, Rect(92, y, 100, 28));
                loadButton.states_([["Load file..."]]);
                loadButton.action_({
                    Dialog.openPanel({ |selectedPath|
                        ~erroneusLoadSample.value(index, selectedPath);
                    });
                });

                sampleButton = Button(window, Rect(202, y, 105, 28));
                sampleButton.states_([["Use sample"]]);
                sampleButton.action_({
                    ~erroneusUseSample.value(index);
                });

                captureButton = Button(window, Rect(317, y, 112, 28));
                captureButton.states_([["Use capture"]]);
                captureButton.action_({
                    ~erroneusUseCapture.value(index);
                });

                unloadButton = Button(window, Rect(439, y, 91, 28));
                unloadButton.states_([["Unload"]]);
                unloadButton.action_({
                    ~erroneusUnloadSample.value(index);
                });

                statusLabel = StaticText(window, Rect(540, y, 400, 30));
                labels[index] = statusLabel;
            };
            4.do({ |index| makeRow.value(index); });
            ~erroneusSampleLabels = labels;

            note = StaticText(window, Rect(18, 292, 918, 64));
            note.string_(
                "Load WAV/AIFF (mono, or first channel of a stereo file). Max 60 sec.\n"
                ++ "Sample uses the loaded file; Capture returns to the preserved 8-second live buffer.\n"
                ++ "You can keep loaded files in memory while switching sources. "
                ++ "The sound-shaping and modulation controls still work."
            );

            window.onClose_({
                ~erroneusSampleWindow = nil;
                ~erroneusSampleLabels = nil;
            });
            ~erroneusSampleRefresh.value;
            window.front;
        });
    });
};

if(~erroneusSampleGuiCompileOnly != true, {
    ~erroneusOpenSampleGUI.value;
});
)
