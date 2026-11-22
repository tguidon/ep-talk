# EP Talk

EP Talk turns the Teenage Engineering EP-2350’s squeeze handle into a configurable macOS hold-to-talk shortcut. It reads the same audio input as Handy. Handy records, transcribes, and inserts the text where the cursor is.

## Open the app

Open `dist/EP Talk.app`. The app targets macOS 14 and later and the included build is for this Apple silicon Mac. **Open at login** makes macOS start EP Talk for you. The app remembers whether it was armed and runs from the menu bar when you close the window.

## Set up the mic once

1. Connect the mic’s own USB-C port to your Mac with a data cable and squeeze to power it on. Wait for **FX MIC DISK** in Finder.
2. In EP Talk, open **Mic Setup → Prepare Mic** and select **FX MIC DISK**. The app backs up the volume’s visible files in `~/Library/Application Support/EP Talk/Mic Backups` before writing the signaling files. A conflicting config or startup script leaves the mic untouched.
3. Eject the disk, unplug the USB-C cable, and power-cycle the mic. Replace the front cover. Use two AAA batteries and plug the curly 3.5 mm lead into the pink Sabrent mic jack.
4. In EP Talk, choose the Sabrent input, typically **USB Advanced Audio Device**. Grant Microphone and Accessibility access and click **Arm**. EP Talk needs the adapter configured at **48,000 Hz** in **Audio MIDI Setup**.
5. In Handy, select the same audio input and match EP Talk’s shortcut. The default is **Left Option + Left Command**, matching Handy’s current binding on this Mac. Configure it as a hold-to-talk shortcut. For another dictation app, use that app’s hold-to-talk binding and record the same keys in EP Talk.
6. With the mic on and the paddle released, wait for **Ready**. Click in TextEdit, squeeze and wait for **Transmitting**, then speak. Release the paddle to finish the take. Pauses while holding the paddle leave the shortcut down.

The mic sends short tones through the curly cable for each squeeze and release. EP Talk decodes those tones locally. The startup script, decoder, and sound files are included in this project and the app bundle. A mic prepared by the previous EP Talk build can still be used.

The mic uses its sample playback slots for the control tones during this setup. **Mic Setup → Remove Signals** removes files that match the installed payload. Eject and power-cycle after removal to return to factory behavior.

## Troubleshooting

- **Input level stays flat:** squeeze and speak with the curly lead in the Sabrent’s pink jack. Confirm the adapter is selected. If speech distorts, lower the mic’s output knob.
- **Input level moves and Acquiring link persists:** confirm the signaling files were installed and the mic was power-cycled with USB-C disconnected. The adapter must carry the control tones. Adjust the mic output a little and test again. Use **Refresh Inputs** from the input menu after changing the adapter’s sample rate.
- **Ready never becomes Transmitting:** release the handle fully, then squeeze deliberately. Check EP Talk’s Accessibility permission.
- **Transmitting appears but Handy stays idle:** test the same binding on your keyboard and check that Handy is open and listening to the Sabrent. A target app must support held global shortcuts.
- **The mic has been idle on batteries:** squeeze to wake. If you see **Release paddle**, release once and wait for **Ready**.

## Build

Run `./build.sh` with Swift 6.2 or later. The build produces a locally signed `dist/EP Talk.app`. To build with a signing identity you already have, set `EP_TALK_SIGN_IDENTITY`. macOS may ask for permissions again after an ad-hoc rebuild.

Run `swift test` for the protocol and held-shortcut state tests. The project builds without a separate checkout or package download.

## Credits

EP Talk took inspiration from [FX Talk](https://github.com/bjg4/fx-talk) and includes locally maintained adaptations of its MIT-licensed tone protocol, decoder, device script, and fixtures. The upstream decoder was adapted from [Tingle](https://github.com/tutorintelligence/tingle). The original MIT license notices are included in `ThirdParty` and in the app bundle. The reference hardware test used EP-2350 firmware 1.0.9 and a CableCreation adapter.
