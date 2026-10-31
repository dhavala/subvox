# Subvox

A macOS prototype that tests whether AirPods Pro head-motion data (`CMHeadphoneMotionManager`) carries enough information to turn **silently mouthed words into text**.

The motion decoder uses a small-vocabulary template recognizer, not a language model.
A permutation test checks whether recorded word labels can be distinguished above
chance. This is an experiment, not a validated silent-speech system.

## Build & run

### Recommended: local build

Requires macOS 14 or later and Apple developer tools with Swift 5.9 or later and
a macOS 14+ SDK. The local build works with Command Line Tools; full Xcode,
Homebrew, XcodeGen, and an Apple developer account are not required.

Open Terminal and change into your downloaded or cloned `subvox` directory.
Run these commands from that directory (the one containing this README):

```sh
bash scripts/build-local.sh
open build/Subvox.app
```

If developer tools are missing, run `xcode-select --install` first. The script
compiles the Swift sources, bundles the permission descriptions, and ad-hoc signs
the app for local use. This is not a distribution build. Quit Subvox before
rebuilding, then run the same two commands after source changes.

### Optional: Xcode IDE and tests

To use the Xcode IDE and XCTest suite instead, install the full **Xcode** app,
then generate the project:

```sh
brew install xcodegen   # once
xcodegen generate
open Subvox.xcodeproj   # ⌘R
```

The project defaults to local ad-hoc signing (Sign to Run Locally); no signing
team is required. In Xcode, select the **Subvox** scheme and **My Mac**, then
press **⌘R**. Run **⌘U** for the tests.

If `xcodebuild` reports that the active developer directory is
`/Library/Developer/CommandLineTools`, use the local build above, or select your
installed Xcode with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
(adjust the path if Xcode is installed elsewhere).

Or from the command line:

```sh
xcodebuild -project Subvox.xcodeproj -scheme Subvox -derivedDataPath build build
open build/Build/Products/Debug/Subvox.app
xcodebuild -project Subvox.xcodeproj -scheme Subvox -derivedDataPath build test
```

The local script produces `build/Subvox.app`; Xcode produces
`build/Build/Products/Debug/Subvox.app` with the commands above. Launch the app
from the build method you used. XCTest requires full Xcode and is not run by the
local script.

## First run with AirPods Pro

1. Wear your AirPods Pro and select them in **System Settings → Sound → Output**.
2. Launch Subvox and allow **Motion** access when prompted. Open **Sensors** and
   wait for **Streaming** and moving plots. Move your head
   gently to check the signal, then hold it still for word recordings.
3. Open **Train**, select **yes**, hold Space while silently mouthing “yes,” and
   release. Record 8–10 takes, then do the same for **no**. Keep focus out of text
   fields; alternatively press and hold the large capture area with the mouse.
   The take count should increase after each recording.
4. Click **Evaluate** to inspect accuracy, the confusion matrix, and the p-value.
   Evaluation needs at least two recorded words and at least two takes for every
   word that has recordings. Unrecorded vocabulary entries can remain in the list.
   A low p-value is evidence for this dataset; repeat with fresh recordings to
   check reproducibility.
5. Open **Decode**, use **Hold Space**, and mouth one of the trained words.
   Starting the microphone is optional.

For **Auto-detect**, first click **Calibrate noise floor** in Decode and remain
still for two seconds. Start with Hold Space so you can check recognition before
introducing automatic segmentation.

## Troubleshooting

| Symptom | Next step |
|---|---|
| `scripts/build-local.sh` cannot be found | Change into the repository directory before running the build command. |
| Developer tools are missing | Run `xcode-select --install`, finish installation, then rerun the build. |
| `xcodebuild` requires Xcode | Use `bash scripts/build-local.sh`, or select the full Xcode installation as described above. Command Line Tools alone cannot run XCTest. |
| Compiler reports unavailable APIs or unsupported Swift syntax | Check `xcrun swiftc --version` and `xcrun --sdk macosx --show-sdk-version`; use tools meeting the requirements above. |
| **Waiting for AirPods** | Check that the AirPods are worn, connected to this Mac, and selected as sound output. Reconnect them, then quit and reopen Subvox. |
| **Motion access denied** | Allow Subvox in System Settings → Privacy & Security → Motion & Fitness, then quit and reopen it. |
| **Headphone motion unsupported** | Confirm that your headphones support head tracking and are connected; restart Subvox after connecting. The app cannot capture motion until the system reports support. |
| Space does not record a take | Select a word, check for Streaming, and move focus out of text fields, or use the mouse capture area. Hold for at least a short utterance; very short segments are discarded. |
| Evaluate shows no result | Record at least two takes for each word with recordings and at least two words total; leave at least one feature checkbox enabled. |
| Predictions are faded or incorrect | Faded words failed the distance/confidence thresholds. Collect consistent takes with the AirPods in the same position; check evaluation before adjusting thresholds. |

Microphone and Speech permissions are requested only after **Start Mic**. The
motion decoder works without them. The reference transcript uses on-device speech
recognition when supported and may use server recognition otherwise; the Decode
screen displays which mode is active.

## Screens

| Screen | What it does |
|---|---|
| **Sensors** | Live plots of user acceleration, rotation rate and attitude, the measured sample rate, a mic input picker and level meter, and a recorder for experiment sessions. |
| **Train** | Pick a word, hold **Space**, mouth it, release. Each take is stored as a template. **Evaluate** runs leave-one-out classification and a 500× label-permutation test, then shows accuracy against chance, a p-value and a confusion matrix. The feature checkboxes (acceleration / rotation / attitude) let you test which channels carry the signal. |
| **Decode** | The motion-to-text screen. Hold Space, or use auto-detect after calibrating the noise floor. Each segment is DTW-matched against your templates and added to the transcript. A live mic transcript runs alongside it for comparison. |

## How decoding works

1. **Segmentation** (`CaptureController`). Space-hold, or an energy trigger above a calibrated noise floor with pre-roll and hangover.
2. **Features** (`MotionFeatures`). Per frame: user acceleration (3), rotation rate (3), and attitude change since the start of the segment (3). Each channel is mean-centered, and quiet lead-in and lead-out frames are trimmed.
3. **Matching** (`DTW`, `TemplateClassifier`). Each channel is z-scaled across the training set. Matching is 1-nearest-neighbour per word, using dynamic time warping with a Sakoe–Chiba band. A segment is rejected if the best distance is above *max distance* or the margin to the runner-up is below *min confidence*.
4. **Is it real?** (`Evaluation`). The leave-one-out accuracy is compared with the same procedure run on shuffled labels. If p < 0.05, the motion stream distinguishes your words better than chance.

## Experiment protocol

Use **Record Session** in the toolbar or on the Sensors screen. Recordings go to `~/Documents/Subvox/Sessions/<timestamp>-<condition>/`:

- `motion.csv`: every motion sample. `t` is seconds from session start.
- `audio.caf`: microphone audio, if the mic was running when recording started.
- `events.csv`: every Space-held segment, with its label or prediction.
- `meta.json`: condition, prompt, and the audio start offset for aligning audio with motion.

Suggested runs: the same 5-word script under **Normal speech**, **Whisper** and **Silent mouthing**, 10 reps each. Then, in Train, compare the Evaluate results across feature sets.

The training set lives at `~/Library/Application Support/Subvox/dataset.json`.
Click **Stop Recording** to finalize the session and write `meta.json` before
quitting the app. Session recordings are separate from the training dataset;
recording a Sensors session does not automatically create training templates.

## Known limits

- Headphone motion is processed and low-rate (roughly 25 Hz on AirPods). The speech-detecting accelerometer and the inward mic are not exposed. Expect jaw and head movement, not vocal vibration.
- Templates are user- and session-specific. Re-seating the AirPods can shift the signal.
- Choosing AirPods as the mic input switches them to the Bluetooth headset (HFP) profile.
