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
- [ ] Add audio-recording and live-input tests, with deterministic buffer lifecycle
- [ ] Add stereo capture and stereo granular reading
- [x] Add a first-pass GUI panel for listening to parameter sweeps (not a production GUI)
- [x] Introduce four per-track modulators with source/target/rate/depth routing
- [ ] Evaluate modulation listening, CPU overhead, and control ranges on the Latitude
- [ ] Add modulation-to-modulation routing or per-source envelopes based on listening
- [ ] Introduce scenes, macros, and OSC/MIDI control
- [ ] Explore safe cross-track sends and recursive spectral processing

## Control fluidity experiments

The basic Qt slider panel exists to expose discontinuities and zippering before choosing control smoothing. Keep GUI-driven values distinct from audio-engine smoothing: sliders send numerical Synth.set messages directly, and the engine does not yet apply a dedicated lag stage to every parameter. This is deliberate so audible discontinuities can be identified. The GUI retains the values commanded from that panel per track but does not query parameters back from the Synths.

## First modulation matrix (v0.2)

Each track SynthDef contains four modulation slots with four controls per slot: wave, target, rate, and depth. Default depth and target are zero to preserve the v0.1 sound.

Each slot produces a control-rate waveform. Its selected target determines where it is applied; slots with the same target are summed and clipped to a normalized +/-1. Destination-specific amounts are musical, not unrestricted offsets: relative buffer-position shifts, mix offsets, bounded scan and density changes, octave-like exponential pitch/length/frequency changes.

Final destination limits are enforced after summing modulation, especially feedback. No language-side high-frequency scheduling is required. Stepped random can intentionally produce discontinuities.

Limitations: envelope modes are free-running periodic decays, not audio-following or externally gated; no clock synchronization, modulation-to-modulation routing, phase reset, or persistent scenes.

## Testing strategy

The CI check compiles the actual SynthDef with `.asBytes`, which catches language parsing and SynthDef graph construction errors. Since CI has no reliable audio device, real-time signal behavior and audible feedback stability must be checked separately on a configured SuperCollider server.
