# Akai MPD32 control surface (experimental)

The MPD32 is a **likely**, not required, performance interface for Thorax-SC. This first adapter is optional and deliberately does not alter the sound engine. It uses only stock SuperCollider MIDI support.

## Why this shape

The MPD32 has 8 knobs, 8 faders, 8 buttons, 16 velocity/pressure-sensitive pads, 3 control banks, and 4 pad banks. Those banks offer room for later macros, scenes, and modulation routing. For now use **control bank A** and **pad bank A**.

MIDI assignments depend on the MPD32 preset and can be edited on the hardware, so we **do not assume any factory CC or pad note numbers**. The first version learns each physical control from the actual incoming MIDI event. Set pads to send Note On, knobs and faders to send absolute MIDI CC, and buttons are not used yet. Poly-aftertouch, NRPN, MMC transport, and program-change pads are not handled.

Sources:
- [Akai MPD32 reference manual](https://cdn.inmusicbrands.com/akai/attachments/MPD32/mpd32_reference_manual_v1_02_00.pdf)
- [SuperCollider MIDI guide](https://doc.sccode.org/Guides/MIDI.html)

## Proposed performance layout (bank A)

| Physical control | Assignment | Scope |
| --- | --- | --- |
| Knob 1 | Grain read position | Selected track |
| Knob 2 | Scan speed (signed) | Selected track |
| Knob 3 | Position drift | Selected track |
| Knob 4 | Grain density | Selected track |
| Knob 5 | Grain duration | Selected track |
| Knob 6 | Grain pitch (signed) | Selected track |
| Knob 7 | Resonator mix | Selected track |
| Knob 8 | Feedback (0–0.65) | Selected track |
| Faders 1–4 | Output level (0–0.20) | Tracks 1–4 independently |
| Faders 5–8 | Drive, reverb, grain mix, evolve | Selected track |
| Pads 1–4 | Select track 1–4 | Global |
| Pads 5–8 | Toggle capture freeze for track 1–4 | Tracks 1–4 independently |
| Pads 9–15 | Reserved for scenes/macros/modulation | Not active |
| Pad 16 | SILENCE ALL: output levels + feedback to zero | All tracks |

Bank B/C and remaining pads/buttons are explicitly **not mapped** yet. Different banks may emit different numbers and can be learned in a later revision. A pad configured to transmit Program Change will not work as a pad in this version.

## Run and learn

1. Connect the MPD32 by USB and confirm the OS sees its MIDI port. Use the controller's MIDI/CC configuration rather than assuming the default preset.
2. Run `thorax-v0.scd` and let all four tracks boot.
3. Evaluate `thorax-mpd32.scd`. It searches input source names for `mpd32` (case-insensitive) and connects only to that port.
4. In SuperCollider, evaluate `~thoraxMPD32LearnCC.value(\knobs, 0);` then move **physical knob 1**. Repeat for index `1` through `7`. Learn faders with `~thoraxMPD32LearnCC.value(\faders, 0);` and so on.
5. Learn pads by evaluating `~thoraxMPD32LearnPad.value(0);` and pressing **physical pad 1**. Learn indexes 1–7 and 15 for the initial layout. You can leave any unused controls unlearned.
6. Move controls and listen at **low volume**, particularly feedback. Unlearned controls have no action.
7. To record the learned map, evaluate `~thoraxMPD32DumpMap.value;`. Copy the printed `~thoraxMPD32Map = (...);` expression to your own local config file. Evaluate that expression **before** loading the adapter next time, or evaluate it after loading the adapter to replace the empty map.

All index arguments are **zero-based** (first physical knob is index 0). MIDI channels reported in messages are zero-based internally; display output uses channels 1–16.

Useful commands:

```supercollider
~thoraxMPD32Monitor = true;                 // Log incoming CC and pad note-ons
~thoraxMPD32LearnCC.value(\knobs, 0);     // Arm learn for knob 1
~thoraxMPD32LearnCC.value(\faders, 0);    // Arm learn for fader 1
~thoraxMPD32LearnPad.value(0);            // Arm learn for pad 1
~thoraxMPD32CancelLearn.value;            // Disarm MIDI learn
~thoraxMPD32DumpMap.value;                // Print a reusable assignment map
~thoraxMPD32SilenceAll.value;             // Set levels and feedback to zero
~thoraxMPD32Stop.value;                   // Free only this adapter's MIDIdefs
~thoraxMPD32Start.value;                  // Reconnect this adapter
```

If the device isn't discovered, `~thoraxMPD32Start` prints available MIDI input ports with UIDs. Set `~thoraxMPD32SourceUID = <the numeric UID>;` and evaluate `~thoraxMPD32Start.value;`. Do not select an unrelated controller's port.

## Limitations and safety

- **Do not use the MPD32 adapter and slider GUI as synchronized control surfaces yet**: both currently send commands directly to each `Synth`. The GUI doesn't reflect external changes, and MPD32 freeze state assumes the adapter is the only thing changing freeze after startup.
- Hardware faders and knobs send **absolute values**; changing the selected track may cause a parameter jump on the next movement. Soft takeover, relative encoder handling, state feedback, and per-track pickup are future work.
- The adapter doesn't automatically restore prior levels after SILENCE ALL. Moving a learned level fader restores that track's level; the same is true of the selected track's feedback knob.
- MIDI learn stores controller messages in language memory until the interpreter restarts. The exported expression is intentionally explicit; there's no automatic file writing or assumptions about local paths.
- A simple optional injection point, `~thoraxMPD32SetParam.value(trackIndex, key, value)`, keeps hardware dispatch separate from the audio engine. When the modulation layer gets a shared base-value/macro setter, replace that function so hardware, GUI, and automation can feed a consistent parameter state.
- This is a **draft hardware integration**. It has not been tested on a connected MPD32, and tests without hardware cannot certify MIDI port detection or control feel.

## Next hardware check

- [ ] Detect the real MPD32 port on the Latitude 7300.
- [ ] Learn one knob, one fader, and one pad; verify correct CC/note/channel capture.
- [ ] Try rapid track selection and slow knob sweeps; listen for parameter jumping or zippering.
- [ ] Verify per-track freeze and SILENCE ALL at low level.
- [ ] Record a working map from the actual MPD32 preset, then decide on bank B modulation controls and state/pickup behavior.
