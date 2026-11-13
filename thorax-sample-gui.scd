// Thorax-SC: non-destructive per-track sample manager.
// Start thorax-v0.scd first, then evaluate this file in SuperCollider IDE.
// Requires no quarks. SoundFile/Buffer decoding supports WAV and AIFF.
//
// Four tracks retain independent live capture histories. Selecting Sample
// reads the loaded mono file buffer; selecting Capture returns to the original
// live ring buffer. The file buffers are freed only after the Synth switches.

(
~thoraxSampleRefresh = {
    if(~thoraxSampleLabels.notNil, {
        ~thoraxSampleLabels.do({ |label, index|
            var status, mode, indicator;
            status = if(~thoraxSampleStatus.notNil, {
                ~thoraxSampleStatus[index]
            }, { "Start the audio engine" });
            mode = if(~thoraxSampleModes.notNil, {
                ~thoraxSampleModes[index]
            }, { 0 });
            indicator = if(mode == 1, { "[SAMPLE] " }, { "[CAPTURE] " });
            label.string_(indicator ++ status);
        });
    });
};

~thoraxOpenSampleGUI = {
    var window, heading, note, labels, makeRow;
    if(~thoraxTracks.isNil or: { ~thoraxTracks.size != 4 }, {
        "Start thorax-v0.scd and wait for all four tracks.".warn;
    }, {
        if(~thoraxSampleWindow.notNil, {
            ~thoraxSampleWindow.front;
        }, {
            window = Window(
                "Thorax-SC | Sample & Capture",
                Rect(210, 165, 960, 380)
            );
            ~thoraxSampleWindow = window;
            heading = StaticText(window, Rect(18, 12, 900, 27));
            heading.string_("THORAX-SC  |  SAMPLES AND LIVE CAPTURE");
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
                        ~thoraxLoadSample.value(index, selectedPath);
                    });
                });

                sampleButton = Button(window, Rect(202, y, 105, 28));
                sampleButton.states_([["Use sample"]]);
                sampleButton.action_({
                    ~thoraxUseSample.value(index);
                });

                captureButton = Button(window, Rect(317, y, 112, 28));
                captureButton.states_([["Use capture"]]);
                captureButton.action_({
                    ~thoraxUseCapture.value(index);
                });

                unloadButton = Button(window, Rect(439, y, 91, 28));
                unloadButton.states_([["Unload"]]);
                unloadButton.action_({
                    ~thoraxUnloadSample.value(index);
                });

                statusLabel = StaticText(window, Rect(540, y, 400, 30));
                labels[index] = statusLabel;
            };
            4.do({ |index| makeRow.value(index); });
            ~thoraxSampleLabels = labels;

            note = StaticText(window, Rect(18, 292, 918, 64));
            note.string_(
                "Load WAV/AIFF (mono, or first channel of a stereo file). Max 60 sec.\n"
                ++ "Sample uses the loaded file; Capture returns to the preserved 8-second live buffer.\n"
                ++ "You can keep loaded files in memory while switching sources. "
                ++ "The sound-shaping and modulation controls still work."
            );

            window.onClose_({
                ~thoraxSampleWindow = nil;
                ~thoraxSampleLabels = nil;
            });
            ~thoraxSampleRefresh.value;
            window.front;
        });
    });
};

if(~thoraxSampleGuiCompileOnly != true, {
    ~thoraxOpenSampleGUI.value;
});
)
