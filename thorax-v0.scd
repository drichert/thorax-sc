// Thorax-SC v0.3: experimental four-track granular feedback instrument.
// Stock SuperCollider only. Start with low output volume.
//
// Evaluate the entire parenthesized block in SuperCollider, or execute this file.
// For headless compilation, set ~thoraxCompileOnly = true before loading.

(
~thoraxMakeTrackDef = {
    SynthDef(\thoraxTrack, {
        |out = 0, buf = 0, sampleBuf = 0, sampleMode = 0, voice = 0, sourceMode = 0, inputGain = 0.25,
         amp = 0.13, grainMix = 0.8, density = 15,
         grainDur = 0.22, pitch = 1, position = 0.35,
         scanHz = 0.015, spray = 0.025,
         ringMix = 0.35, root = 110, ringTime = 0.15,
         drive = 0.15, space = 0.35, feedback = 0.2,
         freeze = 0, evolve = 0.25,
         mod1Wave = 0, mod1Target = 0, mod1Rate = 0.12, mod1Depth = 0,
         mod2Wave = 2, mod2Target = 0, mod2Rate = 0.30, mod2Depth = 0,
         mod3Wave = 3, mod3Target = 0, mod3Rate = 0.60, mod3Depth = 0,
         mod4Wave = 4, mod4Target = 0, mod4Rate = 1.00, mod4Depth = 0|

        var base, internal, external, material, captureMaterial, sampleDirect;
        var samplePhase, activeBuf, sampleOn, phase, readPos;
        var grainTrigger, granular, sound, ring, colored;
        var feedbackSignal, recordSignal, outputSignal, drift;
        var waveSignal, modFor, m1, m2, m3, m4;
        var effectivePosition, effectiveScan, effectiveSpray, effectiveDensity;
        var effectiveDuration, effectivePitch, effectiveGrainMix;
        var effectiveRingMix, effectiveRoot, effectiveRingTime;
        var effectiveDrive, effectiveSpace, effectiveFeedback;

        // Four per-track modulators run inside scsynth, not over OSC.
        // Shape indices: 0 sine, 1 triangle, 2 step random,
        // 3 smooth random, 4 triggered positive decay envelope.
        waveSignal = { |hz, shape|
            var rate, envelope;
            rate = hz.clip(0.03, 20);
            envelope = Decay2.kr(
                Impulse.kr(rate), 0.008, (0.40 / rate).clip(0.015, 2.0)
            ).clip(0, 1);
            Select.kr(shape.clip(0, 4), [
                SinOsc.kr(rate), LFTri.kr(rate),
                LFNoise0.kr(rate), LFNoise1.kr(rate),
                envelope
            ])
        };

        m1 = waveSignal.value(mod1Rate, mod1Wave) * mod1Depth.clip(0, 1);
        m2 = waveSignal.value(mod2Rate, mod2Wave) * mod2Depth.clip(0, 1);
        m3 = waveSignal.value(mod3Rate, mod3Wave) * mod3Depth.clip(0, 1);
        m4 = waveSignal.value(mod4Rate, mod4Wave) * mod4Depth.clip(0, 1);

        // Each modulator routes to exactly one destination; different
        // modulators may share a destination, and sums are bounded.
        // A target of zero disables routing. Depth defaults to zero.
        modFor = { |destination|
            (
                (m1 * ((mod1Target - destination).abs < 0.5))
                + (m2 * ((mod2Target - destination).abs < 0.5))
                + (m3 * ((mod3Target - destination).abs < 0.5))
                + (m4 * ((mod4Target - destination).abs < 0.5))
            ).clip(-1, 1)
        };

        // Target IDs match the GUI. Audio-safe domains are retained.
        // Frequencies/time/rate use multiplicative octave scaling.
        effectivePosition = (position + (modFor.value(1) * 0.30)).wrap(0, 1);
        effectiveDensity = (density + (modFor.value(2) * 20)).clip(0, 40);
        effectiveDuration = (grainDur * (2 ** (modFor.value(3) * 2))).clip(0.018, 1.3);
        effectivePitch = (pitch * (2 ** modFor.value(4))).clip(-4, 4);
        effectiveScan = (scanHz + (modFor.value(5) * 0.08)).clip(-0.25, 0.25);
        effectiveSpray = (spray + (modFor.value(6) * 0.12)).clip(0, 0.35);
        effectiveGrainMix = (grainMix + (modFor.value(7) * 0.50)).clip(0, 1);
        effectiveRingMix = (ringMix + (modFor.value(8) * 0.50)).clip(0, 1);
        effectiveRoot = (root * (2 ** (modFor.value(9) * 1.5))).clip(40, 12000);
        effectiveRingTime = (ringTime * (2 ** (modFor.value(10) * 2))).clip(0.02, 0.8);
        effectiveDrive = (drive + (modFor.value(11) * 0.50)).clip(0, 1);
        effectiveSpace = (space + (modFor.value(12) * 0.50)).clip(0, 1);
        effectiveFeedback = (feedback + (modFor.value(13) * 0.35)).clip(0, 0.85);

        // Distinct internal test sources for the four tracks.
        base = 55 * (voice + 1);
        internal = SinOsc.ar([base, base * 1.003], 0, 0.22)
            + BPF.ar(
                PinkNoise.ar([0.24, 0.24])
                  * Decay2.kr(Dust.kr(0.8 + (voice * 0.3)), 0.01, 0.65),
                (base * 6).clip(100, 7000), 0.26
            );
        // Attenuate live audio before it reaches direct playback, capture and feedback.
        // A 40 ms ramp prevents level clicks when using the GUI.
        external = SoundIn.ar([0, 1]) * Lag.kr(inputGain.clip(0, 2), 0.04);
        captureMaterial = (internal * (1 - sourceMode.clip(0, 1)))
                        + (external * sourceMode.clip(0, 1));
        // Capture history is always in buf. Loaded samples occupy a separate
        // mono buffer: switching sources never destroys a recording.
        sampleOn = sampleMode.clip(0, 1);
        activeBuf = Select.kr(sampleOn, [buf, sampleBuf]);
        samplePhase = Phasor.ar(
            0, BufRateScale.kr(activeBuf), 0, BufFrames.kr(activeBuf)
        );
        sampleDirect = BufRd.ar(1, activeBuf, samplePhase, 1, 4) ! 2;
        material = (captureMaterial * (1 - sampleOn)) + (sampleDirect * sampleOn);

        // Independent buffer read position; negative scanHz scans backwards.
        phase = Phasor.kr(0, effectiveScan / ControlRate.ir, 0, 1);
        drift = LFNoise1.kr(0.2 + (evolve * 2)).range(effectiveSpray.neg, effectiveSpray);
        readPos = (phase + effectivePosition + drift).wrap(0.002, 0.998);

        grainTrigger = Dust.kr(
            effectiveDensity *
            (1 + (LFNoise1.kr(0.4) * evolve)).clip(0.1, 1.9)
        );
        granular = GrainBuf.ar(
            2, grainTrigger, effectiveDuration, activeBuf,
            effectivePitch * BufRateScale.kr(activeBuf),
            readPos, 2, LFNoise1.kr(1.5), -1, 32
        ) * 0.65;
        sound = XFade2.ar(
            material, granular, effectiveGrainMix.linlin(0, 1, -1, 1)
        );

        // Eight prototype resonator modes per channel.
        ring = Mix.fill(8, { |i|
            Ringz.ar(
                sound * 0.07, (effectiveRoot * (1.31 ** i)).clip(40, 12000),
                effectiveRingTime
            )
        });
        colored = XFade2.ar(
            sound, ring.tanh, effectiveRingMix.linlin(0, 1, -1, 1)
        );
        colored = (colored * (1 + (effectiveDrive * 10))).tanh;
        colored = LeakDC.ar(colored);

        // Buffered recirculation, not zero-delay feedback.
        feedbackSignal = LPF.ar(HPF.ar(Mix.new(colored) * 0.5, 35), 9000);
        recordSignal = Limiter.ar(
            LeakDC.ar(
                (Mix.new(material) * 0.5)
                + (feedbackSignal * effectiveFeedback)
            ), 0.8
        );
        RecordBuf.ar(
            recordSignal, buf, 0, 1, 0,
            (1 - freeze.clip(0, 1)) * (1 - sampleOn), 1, 1
        );

        outputSignal = FreeVerb2.ar(
            colored[0], colored[1], effectiveSpace, 0.72, 0.4
        );
        outputSignal = Limiter.ar(LeakDC.ar(outputSignal * amp), 0.7);
        Out.ar(out, outputSignal);
    })
};

// A GUI may install ~thoraxSampleRefresh. Refresh only on AppClock.
~thoraxSampleNotify = {
    if(~thoraxSampleRefresh.notNil, {
        { ~thoraxSampleRefresh.value; }.defer;
    });
};

~thoraxSampleValidTrack = { |track|
    ~thoraxTracks.notNil and: {
        track.isInteger and: { (track >= 0) and: { track < 4 } }
    }
};

// OSC ordering matters: never free a sample buffer until its replacement
// has been installed in the playing Synth. This also works from GUI callbacks.
~thoraxSampleFreeLater = { |buffer|
    if(buffer.notNil, {
        Routine({
            buffer.server.sync;
            buffer.free;
        }).play(SystemClock);
    });
};

~thoraxUseCapture = { |track|
    if(~thoraxSampleValidTrack.value(track), {
        ~thoraxTracks[track].set(\sampleMode, 0);
        ~thoraxSampleModes[track] = 0;
        ~thoraxSampleNotify.value;
    });
};

~thoraxUseSample = { |track|
    if(~thoraxSampleValidTrack.value(track), {
        if(~thoraxSampleBuffers[track].notNil, {
            ~thoraxTracks[track].set(
                \sampleBuf, ~thoraxSampleBuffers[track].bufnum, \sampleMode, 1
            );
            ~thoraxSampleModes[track] = 1;
            ~thoraxSampleNotify.value;
        }, {
            ("Track " ++ (track + 1) ++ ": load a sample first.").warn;
        });
    });
};

~thoraxUnloadSample = { |track|
    var old;
    if(~thoraxSampleValidTrack.value(track), {
        ~thoraxSampleGeneration[track] = ~thoraxSampleGeneration[track] + 1;
        old = ~thoraxSampleBuffers[track];
        ~thoraxSampleBuffers[track] = nil;
        ~thoraxSamplePaths[track] = nil;
        ~thoraxSampleModes[track] = 0;
        ~thoraxSampleStatus[track] = "Capture (no file)";
        // Restore the valid capture buffer ID before freeing the sample.
        ~thoraxTracks[track].set(
            \sampleMode, 0, \sampleBuf, ~thoraxBuffers[track].bufnum
        );
        ~thoraxSampleNotify.value;
        ~thoraxSampleFreeLater.value(old);
    });
};

// Load only the first channel for the current mono granular engine.
// Files longer than one minute are truncated to keep memory bounded.
~thoraxSampleMaxSeconds = 60;
~thoraxLoadSample = { |track, path|
    var soundFile, frames, maxFrames, generation, session, filePath;
    if(~thoraxSampleValidTrack.value(track).not, {
        "Start Thorax-SC before loading samples; track must be 0-3.".warn;
    }, {
        filePath = path.asString;
        soundFile = SoundFile.new;
        if(soundFile.openRead(filePath).not, {
            ("Cannot open audio file: " ++ filePath).warn;
        }, {
            maxFrames = (~thoraxSampleMaxSeconds * soundFile.sampleRate).asInteger;
            frames = soundFile.numFrames.min(maxFrames);
            soundFile.close;
            if(frames < 2, {
                ("Sample is empty or invalid: " ++ filePath).warn;
            }, {
                generation = ~thoraxSampleGeneration[track] + 1;
                ~thoraxSampleGeneration[track] = generation;
                session = ~thoraxSampleSession;
                ~thoraxSampleStatus[track] = "Loading: "
                    ++ PathName.new(filePath).fileName;
                ~thoraxSampleNotify.value;
                Buffer.readChannel(
                    s, filePath, numFrames: frames, channels: [0],
                    action: { |newBuffer|
                        var old;
                        if(
                            (~thoraxSampleSession == session) and: {
                                ~thoraxSampleGeneration.notNil and: {
                                    ~thoraxSampleGeneration[track] == generation
                                }
                            } and: { ~thoraxSampleValidTrack.value(track) },
                            {
                                old = ~thoraxSampleBuffers[track];
                                ~thoraxSampleBuffers[track] = newBuffer;
                                ~thoraxSamplePaths[track] = filePath;
                                ~thoraxSampleModes[track] = 1;
                                ~thoraxSampleStatus[track] = "Sample: "
                                    ++ PathName.new(filePath).fileName
                                    ++ " (" ++ (newBuffer.duration.round(0.1)).asString
                                    ++ " sec)";
                                ~thoraxTracks[track].set(
                                    \sampleBuf, newBuffer.bufnum, \sampleMode, 1
                                );
                                ~thoraxSampleNotify.value;
                                ~thoraxSampleFreeLater.value(old);
                            },
                            { newBuffer.free; }
                        );
                    }
                );
            });
        });
    });
};

~thoraxStop = {
    // Release synth readers before freeing either the sample or capture buffers.
    if(~thoraxGroup.notNil, {
        ~thoraxGroup.free;
        ~thoraxGroup = nil;
    });
    // Invalidate any outstanding asynchronous file-read completions.
    ~thoraxSampleSession = (~thoraxSampleSession ? 0) + 1;
    if(~thoraxSampleBuffers.notNil, {
        ~thoraxSampleBuffers.do({ |buffer|
            if(buffer.notNil, { buffer.free; });
        });
    });
    ~thoraxSampleBuffers = nil;
    ~thoraxSamplePaths = nil;
    ~thoraxSampleModes = nil;
    ~thoraxSampleGeneration = nil;
    ~thoraxSampleStatus = nil;
    if(~thoraxBuffers.notNil, {
        ~thoraxBuffers.do({ |b| b.free; });
        ~thoraxBuffers = nil;
    });
    ~thoraxTracks = nil;
    "Thorax-SC stopped".postln;
};

~thoraxStart = {
    s = Server.default;
    s.options.sampleRate = 48000;
    s.options.hardwareBufferSize = 256;
    s.options.memSize = 131072;
    s.options.numOutputBusChannels = 2;
    s.options.numInputBusChannels = 2;

    s.waitForBoot({
        ~thoraxMakeTrackDef.value.add;
        Routine({
            s.sync;

            // Cleanup invalidates pending sample-read callbacks from the old
            // instrument before allocating a new set of capture buffers.
            ~thoraxStop.value;
            s.sync;

            ~thoraxBuffers = Array.fill(4, {
                Buffer.alloc(s, (s.sampleRate * 8).asInteger, 1)
            });
            s.sync;

            ~thoraxGroup = Group.head(s);
            ~thoraxTracks = Array.fill(4, { |i|
                Synth.tail(~thoraxGroup, \thoraxTrack, [
                    \buf, ~thoraxBuffers[i].bufnum,
                    \voice, i,
                    \root, [55, 80, 135, 220][i],
                    \density, [12, 16, 10, 19][i],
                    \pitch, [1, 0.5, 1.5, -0.75][i],
                    \amp, 0.115
                ])
            });

            ~thoraxSampleSession = (~thoraxSampleSession ? 0) + 1;
            ~thoraxSampleBuffers = Array.fill(4, { nil });
            ~thoraxSamplePaths = Array.fill(4, { nil });
            ~thoraxSampleModes = Array.fill(4, { 0 });
            ~thoraxSampleGeneration = Array.fill(4, { 0 });
            ~thoraxSampleStatus = Array.fill(4, { "Capture (no file)" });
            ~thoraxSampleNotify.value;

            "Thorax-SC v0.3 running: four independent tracks.".postln;
            "Control: ~thoraxTracks[0].set(\\freeze, 1, \\scanHz, 0);".postln;
            "Stop: ~thoraxStop.value;".postln;
        }).play(SystemClock);
    });
};

if(~thoraxCompileOnly != true, { ~thoraxStart.value; });
)

// After startup, evaluate individual lines:
// ~thoraxTracks[0].set(\freeze, 1, \scanHz, 0, \position, 0.22);
// ~thoraxTracks[0].set(\spray, 0.12, \density, 30, \grainDur, 0.09);
// ~thoraxTracks[1].set(\feedback, 0.65, \drive, 0.5, \ringMix, 0.8);
// ~thoraxTracks[2].set(\pitch, -1, \scanHz, -0.02, \space, 0.7);
// ~thoraxTracks[3].set(\sourceMode, 1, \inputGain, 0.25); // Live input at -12 dB approx.
// ~thoraxTracks.do({ |t| t.set(\amp, 0.07); });
// Four independent modulators per track, depth = 0 until enabled.
// ~thoraxTracks[0].set(\mod1Wave, 0, \mod1Target, 1, \mod1Rate, 0.2, \mod1Depth, 0.5);
// ~thoraxStop.value;
