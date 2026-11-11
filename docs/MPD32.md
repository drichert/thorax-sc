# Akai MPD32 control surface (experimental)

The MPD32 is a **likely**, not required, performance interface for Thorax-SC. This first adapter is optional and deliberately does not alter the sound engine. It uses only stock SuperCollider MIDI support.

## Why this shape

The MPD32 has 8 knobs, 8 faders, 8 buttons, 16 velocity/pressure-sensitive pads, 3 control banks, and 4 pad banks. Those banks offer room for later macros, scenes, and modulation routing. For now use **control bank A** and **pad bank A**.

MIDI assignments depend on the MPD32 preset and can be edited on the hardware, so we **do not assume any factory CC or pad note numbers**. The adapter learns controls from incoming MIDI. The MPD32's endless knobs can use increment/decrement NRPN; faders normally send 7-bit CC. Pads should send Note On. Buttons are not used yet. Poly-aftertouch, MMC transport, and program-change pads are not handled.

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
4. For high-resolution relative control, set **knob 1** to **INC/DEC (NRPN)** in the MPD32 EDIT menu, selecting its NRPN Bank M and Bank L number. Evaluate `~thoraxMPD32LearnNRPN.value(\knobs, 0);` and turn the knob. Repeat for other knobs as desired. Alternatively, `~thoraxMPD32LearnControl.value(\knobs, 0);` auto-detects ordinary CC versus NRPN. Learn faders with `~thoraxMPD32LearnCC.value(\faders, 0);`.
5. Learn pads by evaluating `~thoraxMPD32LearnPad.value(0);` and pressing **physical pad 1**. Learn indexes 1–7 and 15 for the initial layout. You can leave any unused controls unlearned.
6. Move controls and listen at **low volume**, particularly feedback. Unlearned controls have no action.
7. To record the learned map, evaluate `~thoraxMPD32DumpMap.value;`. Copy the printed `~thoraxMPD32Map = (...);` expression to your own local config file. Evaluate that expression **before** loading the adapter next time, or evaluate it after loading the adapter to replace the empty map.

All index arguments are **zero-based** (first physical knob is index 0). MIDI channels reported in messages are zero-based internally; display output uses channels 1–16.

Useful commands:

```supercollider
~thoraxMPD32Monitor = true;                 // Log incoming CC and pad note-ons
~thoraxMPD32LearnNRPN.value(\knobs, 0);    // Knob 1 in INC/DEC NRPN mode
~thoraxMPD32LearnControl.value(\knobs, 0); // Auto-learn CC or NRPN
~thoraxMPD32LearnCC.value(\knobs, 0);      // Explicit 7-bit CC mode
~thoraxMPD32LearnCC.value(\faders, 0);     // Fader 1 in CC mode
~thoraxMPD32LearnPad.value(0);            // Arm learn for pad 1
~thoraxMPD32CancelLearn.value;            // Disarm MIDI learn
~thoraxMPD32DumpMap.value;                // Print a reusable assignment map
~thoraxMPD32SilenceAll.value;             // Set levels and feedback to zero
~thoraxMPD32Stop.value;                   // Free only this adapter's MIDIdefs
~thoraxMPD32Start.value;                  // Reconnect this adapter
```

If the device isn't discovered, `~thoraxMPD32Start` prints available MIDI input ports with UIDs. Set `~thoraxMPD32SourceUID = <the numeric UID>;` and evaluate `~thoraxMPD32Start.value;`. Do not select an unrelated controller's port.

## NRPN resolution and MIDI behavior

Akai's manual documents **increment/decrement NRPN for the MPD32's endless knobs only**. It does not claim the faders send absolute 14-bit data.

- **MPD32 knobs in INC/DEC mode:** CC 99/98 select the NRPN parameter, then CC 96/97 increment/decrement Thorax's current value. The adapter remembers the parameter separately per track. The default step is **1/512 of the normalized control range per increment**, not 1/16383. Tune it with `~thoraxMPD32RelativeStep = 1.0 / 1024.0;` (finer) or `1.0 / 256.0;` (faster). Limits remain clamped.
- **Absolute 14-bit NRPN:** a compatible MIDI sender can use CC 99/98 and Data Entry MSB (CC 6) and LSB (CC 38), representing **0–16383**. CC 6 alone gives coarse control, refined when CC 38 arrives. Do not assume that the MPD32's INC/DEC knobs send absolute 14-bit values.
- **Faders:** keep ordinary 0–127 CC. An external MIDI device or translator can supply NRPN to fader mapping slots, but this is not an advertised MPD32 fader feature.
- **Pads:** still send Note On. RPN CC 101/100 cancels NRPN selection. CC 99, 98, 6, 38, 96, 97, 101 and 100 are reserved for this parser and cannot be learned as standalone ordinary CC controls.
- **Learn and state:** the mapping is `[number, channel, \nrpn]` for NRPN or `[number, channel, \cc]` for CC. Old `[number, channel]` entries still mean CC. Learn waits for an NRPN data/increment event; CC 99/98 address bytes alone do not finish learning. Parser state is per MIDI channel and the input is restricted to the detected MPD32 source.

Relative NRPN has software-managed resolution, not 16,384 mechanically addressable positions on the MPD32. The exact movement/acceleration will need actual hardware testing. Parameters changed externally through the GUI or direct `Synth.set` do **not** update this adapter's local accumulator; a unified parameter layer is planned.
## Limitations and safety

- **Do not use the MPD32 adapter and slider GUI as synchronized control surfaces yet**: both currently send commands directly to each `Synth`. The GUI doesn't reflect external changes, and MPD32 freeze state assumes the adapter is the only thing changing freeze after startup.
- **Absolute CC** knobs/faders can still jump when switching tracks. **Relative NRPN** knobs retain independent per-track values within this adapter. Soft takeover for absolute controls and synchronization with the GUI or modulation layer remain future work.
- The adapter doesn't automatically restore prior levels after SILENCE ALL. Moving a learned level fader restores that track's level; the same is true of the selected track's feedback knob.
- MIDI learn stores controller messages in language memory until the interpreter restarts. The exported expression is intentionally explicit; there's no automatic file writing or assumptions about local paths.
- A simple optional injection point, `~thoraxMPD32SetParam.value(trackIndex, key, value)`, keeps hardware dispatch separate from the audio engine. When the modulation layer gets a shared base-value/macro setter, replace that function so hardware, GUI, and automation can feed a consistent parameter state.
- This is a **draft hardware integration**. It has not been tested on a connected MPD32, and tests without hardware cannot certify MIDI port detection or control feel.

## Next hardware check

- [ ] Detect the real MPD32 port on the Latitude 7300.
- [ ] Learn an INC/DEC NRPN knob, a CC fader, and a Note On pad; verify MIDI source, parameter address/number, and channel.
- [ ] Try rapid track selection and slow NRPN knob sweeps; adjust the relative step for useful movement without zippering. Confirm CC faders still work.
- [ ] Verify per-track freeze and SILENCE ALL at low level.
- [ ] Record a working map from the actual MPD32 preset, then decide on bank B modulation controls and state/pickup behavior.
