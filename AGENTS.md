# Bark dictation

Menu bar app: hold right ⌥ to record, release to transcribe with Underdog Bark 3.0 Clean and paste into the focused app.

- Git: commit straight to `main`; no deploy step.
- Build: `./build.sh` → `build/Bark.app`, signed with the Developer ID identity so Accessibility stays granted across rebuilds.
- Verify: `say -o /tmp/t.wav --data-format=LEI16@16000 "Um, we should meet on Thursday." && build/Bark.app/Contents/MacOS/Bark --transcribe /tmp/t.wav` prints the sentence without "Um".
- Release: bump `CFBundleShortVersionString` in `Resources/Info.plist`, `./build.sh`, zip with `ditto -c -k --keepParent build/Bark.app build/Bark-X.Y.Z.zip`, `xcrun notarytool submit … --keychain-profile bark-notary --wait`, `xcrun stapler staple build/Bark.app`, zip again, `gh release create vX.Y.Z`.
- Icons: edit `artwork/bark-mark.svg` (the dog; `bark-app-icon.svg` embeds it), `artwork/bark-menubar.svg` (template silhouette), then `artwork/build-icons.sh` (needs resvg). The generated `Resources/AppIcon.icns` and `MenuBarIcon(@2x).png` are committed so `build.sh` does not need resvg.
- Runtime: FluidAudio 0.17.7, `AsrModels.loadLocal(version: .ultra)` on the `bark-3.0-clean` folder of FluidInference/bark-3.0-coreml, pinned to commit ca21bed2. Files and sizes are listed in `ModelStore.swift`. Model lives in `~/Library/Application Support/Bark/`.
- When FluidAudio PR #1054 is released, `.bark3Clean` replaces the manual download and the `<unk>` stripping in `Transcriber.swift`.
- `model.bark` in the repo root is the upstream entropy-coded file (identical to ConwayResearch/Underdog-Bark-3.0-Clean); the app does not read it.
- First load per app bundle compiles the encoder for the Neural Engine (~85 s, done by the system ANE compiler so Bark itself looks idle); later loads take ~0.2 s. The compiled cache is `~/Library/Caches/be.debleser.Bark/com.apple.e5rt.e5bundlecache/<OS build>/`; move its entries aside to reproduce a cold start.
- Hotkey: listen-only CGEventTap, keycode 61 with device flag 0x40. A keyDown while held cancels (⌥ is a typing modifier).
- Insertion: pasteboard + synthetic ⌘V, previous clipboard restored after 0.5 s.
- Spacing: a transcript gets a leading space when the previous paste went to the same app and no key or click happened since. Bark tags its own ⌘V with `eventSourceUserData` so the tap ignores it.
