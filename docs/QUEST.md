# Quest 3 preview export

Friend install steps and the tested APK identity are in [QUEST-INSTALL.md](QUEST-INSTALL.md). What a worn Quest 3 confirmed, and what is still open, is in [QUEST-VALIDATION.md](QUEST-VALIDATION.md). Download the [Quest preview release](https://github.com/philip-bankiers-helper/ashfall/releases/tag/v0.1.0-quest-preview.1).

This is a standalone Meta Quest 3 package of the existing game. It keeps every map, weapon, and mode. It does not enable a low-poly path, replace weapons, drop multiplayer, or change gameplay or the network protocol. Source assets stay on the existing asset manifest.

The Android preset is named **Quest 3**. It exports all resources, ARM64 only, OpenXR on, the Meta OpenXR plugin enabled, package `dev.philipbankier.ashfallquest`, title **ASHFALL Quest Preview**, a signed debug development build, and `INTERNET`. Its non-resource filters also include `assets/*.txt` and `assets/*.md` so provenance and license files ship, and they exclude `android/*`. The Windows preset is unchanged. Launch user arguments are `--require-vr --extended --playtest-catalog`. `--desktop`, `--smoke`, `--low-poly`, `--xr_mode_regular`, and forcing XR off are not part of the device launch.

A previous device install started and then exited because the APK had no `libopenxr_loader.so`. Godot refused XR without that loader. The export now uses the Godot Android Gradle build (`gradle_build/use_gradle_build=true`) and `xr_features/enable_meta_plugin=true`, with the Godot OpenXR Vendors GDExtension in `addons/godotopenxrvendors`. That addon loads from `plugin.gdextension` after import. There is no separate EditorPlugin enable flag. The build runner checks the exported APK for the loader.

`project.godot` has `import_etc2_astc=true`, so the headless import builds the mobile ETC2/ASTC texture variants the Android export uses. The preset does not set per-format texture overrides. Imported resources under `.godot/` stay eligible for export. Tests, tools, reports, build outputs, and private credential files stay excluded. `android/` and `addons/godotopenxrvendors/` are generated install trees and are gitignored.

## Host tools

- Official Godot **4.7.2** editor binary.
- Matching official export templates, `version.txt` equal to `4.7.2.stable`. Download `Godot_v4.7.2-stable_export_templates.tpz` from <https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz> and unpack it. `--templates` is the directory that contains `android_source.zip` and `version.txt`.
- Godot OpenXR Vendors **5.1.0-stable** from <https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable>. The local zip SHA-256 must be `6a838dbdf4115549e4511ebee0da9a5dcc8f9f6258d4cc2f2ee57a907a3e2911`. The addon files live under `asset/addons/godotopenxrvendors/` in that archive, including its license files.
- JDK 17, Android SDK Platform 36, and Android build-tools 36.1.
- A local Android debug signing credential. The preset leaves the debug keystore fields empty so the Godot editor can use its default debug keystore. Do not commit keystores or `export_credentials.cfg`.

Setup reads only those local files. It does not download the template, the vendors archive, or Gradle.

```bash
python3 tools/setup_quest.py --templates /path/to/templates --vendor-zip /path/to/godotopenxr-vendors.zip
```

The installer copies `android_source.zip` to `android/build`, writes `android/.build_version` as `4.7.2.stable`, writes an empty `android/.gdignore` so Godot does not scan or export the Gradle sources, marks `gradlew` executable, and extracts only the vendors addon subtree. Archive paths are checked for traversal and symlinks. If `android/build` or the addon directory already has files, setup continues only when those files are the verified install. After the first export, Gradle modifies its generated tree, so setup deliberately refuses a rerun on that non-pristine tree. The build runner reuses that tree normally. It does not delete or replace anything else.

The first Godot export runs the Gradle wrapper, which downloads the Gradle distribution. Later exports reuse that local Gradle cache.

## Build

From the repository, with the addon and `android/build` already installed:

```bash
python3 tools/build_quest.py --godot /path/to/Godot_v4.7.2-stable --output /path/outside/repo/quest-build
```

`--godot` is expanded and resolved. `--output` must be outside the project and fresh: missing, or an empty directory. The runner does not overwrite an existing APK, log, or receipt. The directory receives `ASHFALL-Quest-Preview.apk`, `logs/`, and `quest-build-result.json` (streaming SHA-256, engine version, source commit, dirty state, ABI, OpenXR loader, decoded launch flags, and script count). `--timeout` must be a positive number of seconds.

The runner stops before export when the vendors `plugin.gdextension` or the `4.7.2.stable` Android template is missing. After export it opens the APK and requires native libraries only under `lib/arm64-v8a/`, including non-empty `libopenxr_loader.so` and `libgodot_android.so`. `assets/_cl_` is little-endian argc plus length-prefixed plain UTF-8. It must include `--xr_mode_openxr`, and `--` must precede `--require-vr`, `--extended`, and `--playtest-catalog`. It must not contain `--desktop`, `--smoke`, `--low-poly`, `--xr-mode off`, or `--xr_mode_regular`. Every source `scripts/*.gd` must be a non-empty `assets/scripts/` file, or a `.gd.remap` whose `path` is `res://scripts/name.gdc` and whose `.gdc` entry is non-empty. The audit reads those archive entries. The receipt records `abi`, `loader`, `flags`, and `script_count`. It does not record keystore passwords or other signing secrets.

A nonzero Godot exit, ANSI-stripped script/parse/`ERROR` output, a missed completion marker, a missing APK, a failed APK audit, or a failure to start the engine fails the run and still writes the receipt when the output directory is usable. Filesystem errors after the output directory exists also try to write that receipt and exit nonzero. Import and public checks run headless with XR off and the dummy audio driver. Public checks print `PUBLIC_CHECKS_OK`.

The final build (build-04) succeeded with the Meta plugin and installed. An Oculus runtime OpenXR session began, and the log showed `ASHFALL_START` with `xr=true` and `MISSION_BEGIN 0`. The exported preview that matches the worn-headset notes is **ASHFALL-Quest-Preview.apk** (534682358 bytes), SHA256 `ee544e90ed91d2829cecc992efa715c2c11486d76a612b8a5235787bd3f656c3`, built clean from `d4cf66e5bc41832ed530a50b01a2ed9e2230a932`. Subsequent commits update documentation only; the runtime is unchanged. It is debug-signed for sideload, not a store release. Public distribution checks passed 1,120. Build, setup, and audit checks passed 22. The APK SHA256 and v2 signature were verified again before publication.

On 2026-10-28 a worn Quest 3 confirmed Cyber Bird city entry, a visible game, gun firing and reloading, and left-stick move plus right-stick turn that both stop when released. The specific weapon is unknown, and that session did not clear every menu or controller action. Comfort, sustained performance, other maps, other weapons, item switching, modes, audio, and Internet or cross-platform multiplayer on a Quest 3 are not validated by this build. `headset_verified` in the receipt stays false. `device_validation` in the receipt stays `pending` because the build runner cannot see the headset. The human result is recorded in [QUEST-VALIDATION.md](QUEST-VALIDATION.md), separate from the receipt.
