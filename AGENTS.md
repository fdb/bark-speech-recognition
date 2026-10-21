# Bark dictation

Menu bar app: hold right ⌥ to record, release to transcribe with Underdog Bark 3.0 Clean and paste into the focused app.

- Build: `./build.sh` → `build/Bark.app`, signed with the Developer ID identity so Accessibility stays granted across rebuilds.
- Verify: `say -o /tmp/t.wav --data-format=LEI16@16000 "Um, we should meet on Thursday." && build/Bark.app/Contents/MacOS/Bark --transcribe /tmp/t.wav` prints the sentence without "Um".
- Runtime: FluidAudio 0.17.7, `AsrModels.loadLocal(version: .ultra)` on the `bark-3.0-clean` folder of FluidInference/bark-3.0-coreml, pinned to commit ca21bed2. Files and sizes are listed in `ModelStore.swift`. Model lives in `~/Library/Application Support/Bark/`.
- When FluidAudio PR #1054 is released, `.bark3Clean` replaces the manual download and the `<unk>` stripping in `Transcriber.swift`.
- `model.bark` in the repo root is the upstream entropy-coded file (identical to ConwayResearch/Underdog-Bark-3.0-Clean); the app does not read it.
- First load per app bundle compiles the encoder for the Neural Engine (~75 s); later loads take ~0.2 s.
- Hotkey: listen-only CGEventTap, keycode 61 with device flag 0x40. A keyDown while held cancels (⌥ is a typing modifier).
- Insertion: pasteboard + synthetic ⌘V, previous clipboard restored after 0.5 s.
