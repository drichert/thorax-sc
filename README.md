# Thorax-SC

An experimental four-track sound-sculpting instrument written in SuperCollider, inspired by the **behavior**, rather than the hardware interface, of the Torso Electronics S-4.

**Status:** v0.1 exploration. The sound engine has played on the target Latitude 7300 at approximately 18% reported server CPU. A sound-design test panel, an optional draft Akai MPD32 MIDI adapter, and headless compilation checks are included; sound quality and hardware performance are still under evaluation.

## Start playing

1. Install SuperCollider on Linux and configure a working audio server (PipeWire/JACK/ALSA).
2. Open `thorax-v0.scd` in SuperCollider IDE and evaluate the main parenthesized block.
3. Wait for `Thorax-SC v0.1 running` in the post window.
4. Evaluate any of the control examples at the end of the file.
5. For live slider testing, open `thorax-gui.scd` in the SuperCollider IDE and evaluate the parenthesized block after the four tracks are running. The GUI opens automatically.
6. Optional: with an Akai MPD32 connected, evaluate `thorax-mpd32.scd` after starting the tracks; learn your controls following [docs/MPD32.md](docs/MPD32.md).
7. Stop using `~thoraxStop.value;`.

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

## Optional Akai MPD32 MIDI control (draft)

The controller integration is an **optional** file, `thorax-mpd32.scd`, that uses stock SuperCollider MIDI input. No factory MIDI CC, NRPN, or pad note numbers are assumed. Learn one physical control at a time, then print a reusable mapping. The MPD32's endless knobs can use **relative increment/decrement NRPN**; its faders normally remain ordinary 7-bit CC. Conventional absolute 14-bit NRPN is accepted from compatible MIDI senders.

The proposed first-bank layout gives the selected track eight sound-shaping knobs, four independent track-level faders, four effect/mix faders, pads for track selection and capture freeze, and a dedicated SILENCE ALL pad. Hardware bank B, scenes, and modulation macros are reserved for later work. See **[MPD32 setup and layout](docs/MPD32.md)** for learning commands and limitations.

Relative NRPN knobs retain their value per track within the adapter, avoiding the immediate jumps associated with absolute controls. The adapter still sends `Synth.set` values directly and does **not** synchronize with the testing GUI. The adapter has a single `~thoraxMPD32SetParam` function that can be replaced with a unified parameter/macro dispatcher when the modulation architecture is available. The actual MPD32 hardware has not yet been tested.

## Validation

The repository includes `tests/compile.scd` and a GitHub Actions workflow.

From the repository root with `sclang` installed:

```bash
QT_QPA_PLATFORM=offscreen sclang -D tests/compile.scd
```

It compiles the **actual** `\thoraxTrack` SynthDef, including its UGen graph, parses the GUI source without opening a window, and parses plus logic-tests the MPD32 adapter without requiring a MIDI device. The test prints `THORAX_COMPILE_OK`, `THORAX_GUI_COMPILE_OK`, and `THORAX_MPD32_COMPILE_OK` if successful. This does not prove runtime GUI usability or real-time audio behavior.

## Hardware baseline

Initial target: Dell Latitude 7300, 32 GB RAM, Linux, 48 kHz, 256-sample audio buffer. Increase to 512 samples or lower grain density if audio breaks up.

## What is not implemented yet

Sample-file import, scene recall, per-track modulation matrices, unified MIDI/GUI parameter state, cross-track sends, per-stage audio buses, persistent projects, and a production performance GUI. Buffers are mono despite stereo track outputs. The resonator bank has eight modes, not an S-4-equivalent spectral bank.

See [ARCHITECTURE.md](ARCHITECTURE.md) for design principles and next steps.

## References

- [Torso S-4 overview](https://docs.torsoelectronics.com/s4/what-is-the-s4/s4-overview/)
- [SuperCollider GrainBuf](https://doc.sccode.org/Classes/GrainBuf.html)
- [SuperCollider RecordBuf](https://doc.sccode.org/Classes/RecordBuf.html)
