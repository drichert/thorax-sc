// Thorax-SC v0.1: experimental four-track granular feedback instrument.
// Stock SuperCollider only. Start with low output volume.
//
// Evaluate the entire parenthesized block in SuperCollider, or execute this file.
// For headless compilation, set ~thoraxCompileOnly = true before loading.

(
~thoraxMakeTrackDef = {
    SynthDef(\thoraxTrack, {
        |out = 0, buf = 0, voice = 0, sourceMode = 0,
         amp = 0.13, grainMix = 0.8, density = 15,
         grainDur = 0.22, pitch = 1, position = 0.35,
         scanHz = 0.015, spray = 0.025,
         ringMix = 0.35, root = 110, ringTime = 0.15,
         drive = 0.15, space = 0.35, feedback = 0.2,
         freeze = 0, evolve = 0.25|

        var base, internal, external, material, phase, readPos;
        var grainTrigger, granular, sound, ring, colored;
        var feedbackSignal, recordSignal, outputSignal, drift;

        // Distinct internal test sources for the four tracks.
        base = 55 * (voice + 1);
        internal = SinOsc.ar([base, base * 1.003], 0, 0.22)
            + BPF.ar(
                PinkNoise.ar([0.24, 0.24])
                  * Decay2.kr(Dust.kr(0.8 + (voice * 0.3)), 0.01, 0.65),
                (base * 6).clip(100, 7000), 0.26
            );
        external = SoundIn.ar([0, 1]);
        material = (internal * (1 - sourceMode.clip(0, 1)))
                 + (external * sourceMode.clip(0, 1));

        // Independent buffer read position; negative scanHz scans backwards.
        phase = Phasor.kr(0, scanHz / ControlRate.ir, 0, 1);
        drift = LFNoise1.kr(0.2 + (evolve * 2)).range(spray.neg, spray);
        readPos = (phase + position + drift).wrap(0.002, 0.998);

        grainTrigger = Dust.kr(
            density.clip(0, 40) *
            (1 + (LFNoise1.kr(0.4) * evolve)).clip(0.1, 1.9)
        );
        granular = GrainBuf.ar(
            2, grainTrigger, grainDur.clip(0.018, 1.3), buf,
            pitch.clip(-4, 4), readPos, 2, LFNoise1.kr(1.5), -1, 32
        ) * 0.65;
        sound = XFade2.ar(
            material, granular, grainMix.clip(0, 1).linlin(0, 1, -1, 1)
        );

        // Eight prototype resonator modes per channel.
        ring = Mix.fill(8, { |i|
            Ringz.ar(
                sound * 0.07, (root * (1.31 ** i)).clip(40, 12000),
                ringTime.clip(0.02, 0.8)
            )
        });
        colored = XFade2.ar(
            sound, ring.tanh, ringMix.clip(0, 1).linlin(0, 1, -1, 1)
        );
        colored = (colored * (1 + (drive.clip(0, 1) * 10))).tanh;
        colored = LeakDC.ar(colored);

        // Buffered recirculation, not zero-delay feedback.
        feedbackSignal = LPF.ar(HPF.ar(Mix.new(colored) * 0.5, 35), 9000);
        recordSignal = Limiter.ar(
            LeakDC.ar(
                (Mix.new(material) * 0.5)
                + (feedbackSignal * feedback.clip(0, 0.85))
            ), 0.8
        );
        RecordBuf.ar(
            recordSignal, buf, 0, 1, 0,
            1 - freeze.clip(0, 1), 1, 1
        );

        outputSignal = FreeVerb2.ar(
            colored[0], colored[1], space.clip(0, 1), 0.72, 0.4
        );
        outputSignal = Limiter.ar(LeakDC.ar(outputSignal * amp), 0.7);
        Out.ar(out, outputSignal);
    })
};

~thoraxStop = {
    if(~thoraxGroup.notNil, {
        ~thoraxGroup.free;
        ~thoraxGroup = nil;
    });
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

            // Clean up any prior prototype instance before replacing buffers.
            if(~thoraxGroup.notNil, { ~thoraxGroup.free; ~thoraxGroup = nil; });
            if(~thoraxBuffers.notNil, {
                ~thoraxBuffers.do({ |b| b.free; });
                ~thoraxBuffers = nil;
            });
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

            "Thorax-SC v0.1 running: four independent tracks.".postln;
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
// ~thoraxTracks[3].set(\sourceMode, 1); // Stereo live input.
// ~thoraxTracks.do({ |t| t.set(\amp, 0.07); });
// ~thoraxStop.value;
