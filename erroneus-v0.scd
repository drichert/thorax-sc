// Erroneus v0.3: experimental four-track granular feedback instrument.
// Stock SuperCollider only. Start with low output volume.
//
// Evaluate the entire parenthesized block in SuperCollider, or execute this file.
// For headless compilation, set ~erroneusCompileOnly = true before loading.

(
~erroneusMakeTrackDef = {
    SynthDef(\erroneusTrack, {
        |out = 0, buf = 0, sampleBuf = 0, sampleMode = 0, voice = 0, sourceMode = 0, inputGain = 0.25,
         amp = 0.13, grainMix = 0.8, density = 15,
         grainDur = 0.22, pitch = 1, position = 0.35,
         scanHz = 0, spray = 0.025,
         ringMix = 0.35, root = 110, ringTime = 0.15,
         drive = 0.15, space = 0.35, feedback = 0.2,
         freeze = 0, evolve = 0.25,
         mod1Wave = 0, mod1Target = 0, mod1Rate = 0.12, mod1Depth = 0,
         mod2Wave = 2, mod2Target = 0, mod2Rate = 0.30, mod2Depth = 0,
         mod3Wave = 3, mod3Target = 0, mod3Rate = 0.60, mod3Depth = 0,
         mod4Wave = 4, mod4Target = 0, mod4Rate = 1.00, mod4Depth = 0|

        var base, internal, external, material, captureMaterial, sampleDirect;
        var samplePhase, activeBuf, sampleOn, phase, readPos;
        var recordEnabled, captureWriteHead, captureReadPos, absoluteReadPos;
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
        // Use the SAME run gate for recording and the mirrored capture head.
        // Both hold their position during freeze or sample mode.
        recordEnabled = (1 - freeze.clip(0, 1)) * (1 - sampleOn);
        captureWriteHead = A2K.kr(
            Phasor.ar(0, recordEnabled, 0, BufFrames.kr(buf))
        ) / BufFrames.kr(buf);
        activeBuf = Select.kr(sampleOn, [buf, sampleBuf]);
        samplePhase = Phasor.ar(
            0, BufRateScale.kr(activeBuf), 0, BufFrames.kr(activeBuf)
        );
        sampleDirect = BufRd.ar(1, activeBuf, samplePhase, 1, 4) ! 2;
        material = (captureMaterial * (1 - sampleOn)) + (sampleDirect * sampleOn);

        // Scan and drift offset either reference system. Scan Hz 0 holds
        // a constant delay behind the live-input write head.
        phase = Phasor.kr(0, effectiveScan / ControlRate.ir, 0, 1);
        drift = LFNoise1.kr(0.2 + (evolve * 2)).range(effectiveSpray.neg, effectiveSpray);
        absoluteReadPos = (phase + effectivePosition + drift).wrap(0.002, 0.998);
        // Only live INPUT capture measures Position behind the write head.
        // Synth capture and loaded samples retain absolute buffer positions.
        // Freeze holds captureWriteHead alongside the actual recorder.
        captureReadPos = (captureWriteHead - effectivePosition + phase + drift)
            .wrap(0.002, 0.998);
        readPos = Select.kr(
            sourceMode.clip(0, 1) * (1 - sampleOn),
            [absoluteReadPos, captureReadPos]
        );

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
            recordEnabled, 1, 1
        );

        outputSignal = FreeVerb2.ar(
            colored[0], colored[1], effectiveSpace, 0.72, 0.4
        );
        outputSignal = Limiter.ar(LeakDC.ar(outputSignal * amp), 0.7);
        Out.ar(out, outputSignal);
    })
};

// A GUI may install ~erroneusSampleRefresh. Refresh only on AppClock.
~erroneusSampleNotify = {
    if(~erroneusSampleRefresh.notNil, {
        { ~erroneusSampleRefresh.value; }.defer;
    });
};

~erroneusSampleValidTrack = { |track|
    ~erroneusTracks.notNil and: {
        track.isInteger and: { (track >= 0) and: { track < 4 } }
    }
};

// OSC ordering matters: never free a sample buffer until its replacement
// has been installed in the playing Synth. This also works from GUI callbacks.
~erroneusSampleFreeLater = { |buffer|
    if(buffer.notNil, {
        Routine({
            buffer.server.sync;
            buffer.free;
        }).play(SystemClock);
    });
};

~erroneusUseCapture = { |track|
    if(~erroneusSampleValidTrack.value(track), {
        ~erroneusTracks[track].set(\sampleMode, 0);
        ~erroneusSampleModes[track] = 0;
        ~erroneusSampleNotify.value;
    });
};

~erroneusUseSample = { |track|
    if(~erroneusSampleValidTrack.value(track), {
        if(~erroneusSampleBuffers[track].notNil, {
            ~erroneusTracks[track].set(
                \sampleBuf, ~erroneusSampleBuffers[track].bufnum, \sampleMode, 1
            );
            ~erroneusSampleModes[track] = 1;
            ~erroneusSampleNotify.value;
        }, {
            ("Track " ++ (track + 1) ++ ": load a sample first.").warn;
        });
    });
};

~erroneusUnloadSample = { |track|
    var old;
    if(~erroneusSampleValidTrack.value(track), {
        ~erroneusSampleGeneration[track] = ~erroneusSampleGeneration[track] + 1;
        old = ~erroneusSampleBuffers[track];
        ~erroneusSampleBuffers[track] = nil;
        ~erroneusSamplePaths[track] = nil;
        ~erroneusSampleModes[track] = 0;
        ~erroneusSampleStatus[track] = "Capture (no file)";
        // Restore the valid capture buffer ID before freeing the sample.
        ~erroneusTracks[track].set(
            \sampleMode, 0, \sampleBuf, ~erroneusBuffers[track].bufnum
        );
        ~erroneusSampleNotify.value;
        ~erroneusSampleFreeLater.value(old);
    });
};

// Load only the first channel for the current mono granular engine.
// Files longer than one minute are truncated to keep memory bounded.
~erroneusSampleMaxSeconds = 60;
~erroneusLoadSample = { |track, path|
    var soundFile, frames, maxFrames, generation, session, filePath;
    if(~erroneusSampleValidTrack.value(track).not, {
        "Start Erroneus before loading samples; track must be 0-3.".warn;
    }, {
        filePath = path.asString;
        soundFile = SoundFile.new;
        if(soundFile.openRead(filePath).not, {
            ("Cannot open audio file: " ++ filePath).warn;
        }, {
            maxFrames = (~erroneusSampleMaxSeconds * soundFile.sampleRate).asInteger;
            frames = soundFile.numFrames.min(maxFrames);
            soundFile.close;
            if(frames < 2, {
                ("Sample is empty or invalid: " ++ filePath).warn;
            }, {
                generation = ~erroneusSampleGeneration[track] + 1;
                ~erroneusSampleGeneration[track] = generation;
                session = ~erroneusSampleSession;
                ~erroneusSampleStatus[track] = "Loading: "
                    ++ PathName.new(filePath).fileName;
                ~erroneusSampleNotify.value;
                Buffer.readChannel(
                    s, filePath, numFrames: frames, channels: [0],
                    action: { |newBuffer|
                        var old;
                        if(
                            (~erroneusSampleSession == session) and: {
                                ~erroneusSampleGeneration.notNil and: {
                                    ~erroneusSampleGeneration[track] == generation
                                }
                            } and: { ~erroneusSampleValidTrack.value(track) },
                            {
                                old = ~erroneusSampleBuffers[track];
                                ~erroneusSampleBuffers[track] = newBuffer;
                                ~erroneusSamplePaths[track] = filePath;
                                ~erroneusSampleModes[track] = 1;
                                ~erroneusSampleStatus[track] = "Sample: "
                                    ++ PathName.new(filePath).fileName
                                    ++ " (" ++ (newBuffer.duration.round(0.1)).asString
                                    ++ " sec)";
                                ~erroneusTracks[track].set(
                                    \sampleBuf, newBuffer.bufnum, \sampleMode, 1
                                );
                                ~erroneusSampleNotify.value;
                                ~erroneusSampleFreeLater.value(old);
                            },
                            { newBuffer.free; }
                        );
                    }
                );
            });
        });
    });
};

~erroneusStop = {
    // Release synth readers before freeing either the sample or capture buffers.
    if(~erroneusGroup.notNil, {
        ~erroneusGroup.free;
        ~erroneusGroup = nil;
    });
    // Invalidate any outstanding asynchronous file-read completions.
    ~erroneusSampleSession = (~erroneusSampleSession ? 0) + 1;
    if(~erroneusSampleBuffers.notNil, {
        ~erroneusSampleBuffers.do({ |buffer|
            if(buffer.notNil, { buffer.free; });
        });
    });
    ~erroneusSampleBuffers = nil;
    ~erroneusSamplePaths = nil;
    ~erroneusSampleModes = nil;
    ~erroneusSampleGeneration = nil;
    ~erroneusSampleStatus = nil;
    if(~erroneusBuffers.notNil, {
        ~erroneusBuffers.do({ |b| b.free; });
        ~erroneusBuffers = nil;
    });
    ~erroneusTracks = nil;
    "Erroneus stopped".postln;
};

~erroneusStart = {
    s = Server.default;
    s.options.sampleRate = 48000;
    s.options.hardwareBufferSize = 256;
    s.options.memSize = 131072;
    s.options.numOutputBusChannels = 2;
    s.options.numInputBusChannels = 2;

    s.waitForBoot({
        ~erroneusMakeTrackDef.value.add;
        Routine({
            s.sync;

            // Cleanup invalidates pending sample-read callbacks from the old
            // instrument before allocating a new set of capture buffers.
            ~erroneusStop.value;
            s.sync;

            ~erroneusBuffers = Array.fill(4, {
                Buffer.alloc(s, (s.sampleRate * 8).asInteger, 1)
            });
            s.sync;

            ~erroneusGroup = Group.head(s);
            ~erroneusTracks = Array.fill(4, { |i|
                Synth.tail(~erroneusGroup, \erroneusTrack, [
                    \buf, ~erroneusBuffers[i].bufnum,
                    \voice, i,
                    \root, [55, 80, 135, 220][i],
                    \density, [12, 16, 10, 19][i],
                    \pitch, [1, 0.5, 1.5, -0.75][i],
                    \amp, 0.115
                ])
            });

            ~erroneusSampleSession = (~erroneusSampleSession ? 0) + 1;
            ~erroneusSampleBuffers = Array.fill(4, { nil });
            ~erroneusSamplePaths = Array.fill(4, { nil });
            ~erroneusSampleModes = Array.fill(4, { 0 });
            ~erroneusSampleGeneration = Array.fill(4, { 0 });
            ~erroneusSampleStatus = Array.fill(4, { "Capture (no file)" });
            ~erroneusSampleNotify.value;

            "Erroneus v0.3 running: four independent tracks.".postln;
            "Control: ~erroneusTracks[0].set(\\freeze, 1, \\scanHz, 0);".postln;
            "Stop: ~erroneusStop.value;".postln;
        }).play(SystemClock);
    });
};

if(~erroneusCompileOnly != true, { ~erroneusStart.value; });
)

// After startup, evaluate individual lines:
// ~erroneusTracks[0].set(\freeze, 1, \scanHz, 0, \position, 0.22);
// ~erroneusTracks[0].set(\spray, 0.12, \density, 30, \grainDur, 0.09);
// ~erroneusTracks[1].set(\feedback, 0.65, \drive, 0.5, \ringMix, 0.8);
// ~erroneusTracks[2].set(\pitch, -1, \scanHz, -0.02, \space, 0.7);
// ~erroneusTracks[3].set(\sourceMode, 1, \inputGain, 0.25); // Live input at -12 dB approx.
// ~erroneusTracks.do({ |t| t.set(\amp, 0.07); });
// Four independent modulators per track, depth = 0 until enabled.
// ~erroneusTracks[0].set(\mod1Wave, 0, \mod1Target, 1, \mod1Rate, 0.2, \mod1Depth, 0.5);
// ~erroneusStop.value;
