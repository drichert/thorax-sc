# Thorax-SC

An experimental four-track sound-sculpting instrument written in SuperCollider, inspired by the **behavior**, rather than the hardware interface, of the Torso Electronics S-4.

**Status:** v0.1 exploration. The sound engine has played on the target Latitude 7300 at approximately 18% reported server CPU. A sound-design test panel and a headless compilation check are included; sound quality and control fluidity are still under evaluation.

## Start playing

1. Install SuperCollider on Linux and configure a working audio server (PipeWire/JACK/ALSA).
2. Open `thorax-v0.scd` in SuperCollider IDE and evaluate the main parenthesized block.
3. Wait for `Thorax-SC v0.1 running` in the post window.
4. Evaluate any of the control examples at the end of the file.
5. For live slider testing, open `thorax-gui.scd` in the SuperCollider IDE and evaluate the parenthesized block after the four tracks are running. The GUI opens automatically.
6. Stop using `~thoraxStop.value;`.

No audio files required: each track has its own simple built-in source. You can switch a track to live stereo input with `~thoraxTracks[3].set(\sourceMode, 1);`.

**Safety:** Start with low headphone/speaker volume. Feedback is clipped and limited, but the instrument is experimental.

## Features in the first prototype

- Four independently controllable stereo-output tracks with eight-second mono circular capture buffers.
- Granular playback with position, scan speed, random drift, density, duration, and pitch.
- An eight-mode per-track resonator bank, smooth distortion, and stereo reverb.
- Filtered and bounded recirculation of processed audio into the recording buffer.
- Capture freeze, independently of the read-head scan.
- A usable self-generating sound source for testing without samples or external hardware.

### Key controls

| Parameter | Meaning |
| --- | --- |
| `freeze` | 1 stops recording, 0 resumes |
| `position` | Normalized grain read position, 0–1 |
| `scanHz` | Signed cycles per second through the capture buffer |
| `spray` | Random position drift as buffer fraction |
| `density` | Average grains per second |
| `grainDur` | Grain duration in seconds |
| `pitch` | Signed grain playback rate |
| `grainMix` | Direct material versus granulated material |
| `ringMix` | Resonator bank mix |
| `root` | Base resonator frequency |
| `ringTime` | Resonator decay |
| `drive` | Distortion strength |
| `space` | Reverb wet mix |
| `feedback` | Bounded return level to the capture buffer |
| `evolve` | Built-in random modulation depth |
| `amp` | Per-track level |
| `sourceMode` | 0 = synthesized internal source; 1 = live stereo input |

## Slider testing panel

The optional `thorax-gui.scd` opens a simple track-selectable control panel, no extra dependencies. It contains 15 continuously adjustable sliders with current numeric values, plus capture freeze, source selection, reset track, and SILENCE ALL buttons.

Choose a track with the top-left menu. Drag sliders and listen to whether changes feel smooth, stepped, or abrupt. The panel keeps separate parameter values for each track when you switch, but it **does not poll the server** for commands changed elsewhere, so it should be the sole control surface during a fluidity test.

**Recommended listening sequence:** isolate grains with `ringMix = 0`, `drive = 0`, `feedback = 0`, `space = 0`, then sweep grain length, pitch, scan, and density. Add resonance, drive, and feedback back one at a time. The SILENCE ALL button sets all track levels and feedback to zero; Reset track restores initial levels and parameters for the selected track. Start at low monitoring volume.

## Four-modulator system (v0.2 experiment)

Each track has **four independent, server-side control-rate modulators**. Every slot has its own waveform, destination, speed, and depth. The modulation GUI is a second panel, so you can keep the original base-parameter sliders visible.

With the audio engine running, open `thorax-mod-gui.scd` in SuperCollider IDE and evaluate its parenthesized block (the same procedure as `thorax-gui.scd`). Use the track menu to select an independent set of four slots.

- **Sources:** sine LFO, triangle LFO, stepped random, smoothly interpolated random, and periodically triggered positive decay envelope.
- **Destinations:** Off, position, density, grain length/pitch, scan speed, position drift, grain mix, resonance mix, resonator pitch/decay, drive, reverb, and feedback.
- **Range:** speed 0.03–12 Hz in the GUI (20 Hz max in the engine), depth 0–1. For the envelope, speed is the repeat-trigger rate. Stepped random is intentionally discontinuous.
- **Safety:** all slots start Off, depth 0. Matching destinations sum and clip to +/-1. Final destinations enforce safe ranges, including feedback at 0–0.85.
- **Architecture:** LFO generation and routing run in scsynth; moving GUI widgets sends parameter updates but no high-rate modulation events.

The panel retains only GUI-originated values; direct `Synth.set` commands do not sync the display. If you restart the engine, re-evaluate the modulation panel to reinitialize its state.

### First listening exercise

On track 1, route sine to **Position**, set rate **0.12 Hz** and depth **0.2**. Slowly increase depth toward 0.5, then compare **Smooth random** and **Stepped random**. Route a **Pulse envelope** to resonance mix at 1–2 Hz for periodic swelling.

Equivalent control message:

```supercollider
~thoraxTracks[0].set(
    \mod1Wave, 0, \mod1Target, 1,
    \mod1Rate, 0.12, \mod1Depth, 0.2
);
```

Set `\mod1Depth` or `\mod1Target` to zero to silence/disconnect that slot. The **Disable track** button zeros all four depths of the selected track; **Reset track mods** restores its defaults. Work at low output level when exploring feedback and drive.

Modulation of other modulators, freeze, input selection, and clock sync are outside this first milestone.

## Validation

The repository includes `tests/compile.scd` and a GitHub Actions workflow.

From the repository root with `sclang` installed:

```bash
QT_QPA_PLATFORM=offscreen sclang -D tests/compile.scd
```

It compiles the actual `\thoraxTrack` SynthDef, including its UGen graph, parses both GUI sources, and opens/closes both windows under a virtual display. It checks `THORAX_COMPILE_OK`, `THORAX_GUI_COMPILE_OK`, `THORAX_MOD_COMPILE_OK` and `THORAX_MOD_GUI_SMOKE_OK`. This does not prove audible modulation or real-time CPU performance.

## Hardware baseline

Initial target: Dell Latitude 7300, 32 GB RAM, Linux, 48 kHz, 256-sample audio buffer. Increase to 512 samples or lower grain density if audio breaks up.

## What is not implemented yet

Sample-file import, scene recall, modulation-to-modulation routing, cross-track sends, per-stage audio buses, persistent projects, and a production performance GUI. Buffers are mono despite stereo track outputs. The resonator bank has eight modes, not an S-4-equivalent spectral bank.

See [ARCHITECTURE.md](ARCHITECTURE.md) for design principles and next steps.

## References

- [Torso S-4 overview](https://docs.torsoelectronics.com/s4/what-is-the-s4/s4-overview/)
- [SuperCollider GrainBuf](https://doc.sccode.org/Classes/GrainBuf.html)
- [SuperCollider RecordBuf](https://doc.sccode.org/Classes/RecordBuf.html)
