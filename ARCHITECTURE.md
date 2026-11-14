# Thorax-SC architecture

## Goal

Thorax-SC should behave like an instrument, not an effects-rack preset: capture sound continuously, transform it, and selectively feed the resulting audio back into its own history.

The design borrows broad behaviors from the Torso S-4 while leaving routing, modulation, and algorithms open to new experiments.

## v0.1 signal flow

```text
                     +-----------------------------+
                     |                             |
internal/live source |                             v
       |             |                   mono capture buffer
       +----> record mix <--- filtered feedback    |
       |                                           |
       v                                           v
       +------------> direct / granular playback <-+
                              |
                        resonator bank
                              |
                         waveshaper ----> buffered feedback
                              |
                         stereo reverb
                              |
                         output limiter
                              |
                          track out
```

Each of the four tracks is a separate instance of the same SynthDef, with its own capture buffer. `RecordBuf` and `GrainBuf` use the same buffer by design. This is a delayed buffer-history feedback system, not a zero-delay audio cycle.

## Near-term decisions

1. Keep the first version monolithic until the combination of grain, resonance, and recirculation sounds worthwhile.
2. Separate the language-level SynthDef factory from server startup using `~thoraxMakeTrackDef`; this allows headless compilation tests without an audio device.
3. Control DSP on the server; manage buffers, scenes, MIDI/OSC, and persistence in sclang.
4. Add buses and deterministic group ordering as soon as cross-track and per-stage routing enter the engine.
5. Provide a budget for grains/partials and use bounded feedback, DC blocking, and output limiting.
6. Distinguish freeze (stopping buffer writes) from scan (moving the granular read position).

## Near-term roadmap

- [ ] Verify headless SynthDef compilation in GitHub Actions
- [ ] Listen and profile on a Latitude 7300; measure CPU and audio dropouts
- [x] Add non-destructive mono sample loading with a separate buffer per track
- [ ] Exercise audio-recording and live-input paths end-to-end on the Latitude
- [ ] Add stereo capture and stereo granular reading
- [ ] Add click-free sample switching, stereo-to-mono downmix and sample normalization
- [x] Add a first-pass GUI panel for listening to parameter sweeps (not a production GUI)
- [x] Introduce four per-track modulators with source/target/rate/depth routing
- [ ] Evaluate modulation listening, CPU overhead, and control ranges on the Latitude
- [ ] Add modulation-to-modulation routing or per-source envelopes based on listening
- [ ] Introduce scenes, macros, and OSC/MIDI control
- [ ] Explore safe cross-track sends and recursive spectral processing

## Control fluidity experiments

The basic Qt slider panel exists to expose discontinuities and zippering before choosing control smoothing. Keep GUI-driven values distinct from audio-engine smoothing: sliders send numerical Synth.set messages directly, and the engine does not yet apply a dedicated lag stage to every parameter. This is deliberate so audible discontinuities can be identified. The GUI retains the values commanded from that panel per track but does not query parameters back from the Synths.

## Live-input level control

`SoundIn.ar([0, 1])` feeds a per-track `inputGain` control (default 0.25, range 0–2) smoothed by `Lag.kr` over 40 ms. The gain is applied before `material` is used for direct playback, buffer recording, granular processing, and feedback. It does not affect the built-in internal source. This avoids conflating input attenuation with track output level and provides safe testing headroom for external audio.

This is post-capture software gain, **not** an analog interface preamp control. ADC or operating-system clipping must be addressed upstream.

## First modulation matrix (v0.2)

Each track SynthDef contains four modulation slots with four controls per slot: wave, target, rate, and depth. Default depth and target are zero to preserve the v0.1 sound.

Each slot produces a control-rate waveform. Its selected target determines where it is applied; slots with the same target are summed and clipped to a normalized +/-1. Destination-specific amounts are musical, not unrestricted offsets: relative buffer-position shifts, mix offsets, bounded scan and density changes, octave-like exponential pitch/length/frequency changes.

Final destination limits are enforced after summing modulation, especially feedback. No language-side high-frequency scheduling is required. Stepped random can intentionally produce discontinuities.

Limitations: envelope modes are free-running periodic decays, not audio-following or externally gated; no clock synchronization, modulation-to-modulation routing, phase reset, or persistent scenes.

## Loaded samples versus capture history (v0.3)

Each track owns **two kinds of buffer**: an eight-second mono circular
capture buffer (`buf`), plus an optional separate loaded-file
buffer (`sampleBuf`). The server-side `sampleMode`
selects which buffer feeds granular playback and the direct source.
Loaded file playback uses `BufRd` at the file's sample rate;
grain pitch is scaled by `BufRateScale` for files recorded at
non-server sample rates.

The capture buffer is never overwritten by loading a file. While sample mode
is active, the capture `RecordBuf` is paused regardless of
the user's `freeze` value, preserving its history. Returning to
Capture restores that history and the original freeze behavior.

`SoundFile` validates file metadata; `Buffer.readChannel` asynchronously loads
the first audio channel into memory (currently max 60 seconds). File loading
uses generation tokens to ignore stale completion callbacks, plus a session
token invalidated on engine restart. Old buffers are freed only after a server
sync confirms that the playback Synth has been pointed elsewhere.

Limitations: mono first-channel import, no streaming or crossfaded file
transitions, no persistent sample paths across reboot, no automatic peak
normalization. Source switching can be abrupt; audio validation is essential.

## Testing strategy

The CI check compiles the actual SynthDef with `.asBytes`, which catches language parsing and SynthDef graph construction errors. Since CI has no reliable audio device, real-time signal behavior and audible feedback stability must be checked separately on a configured SuperCollider server.
