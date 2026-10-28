# Quest 3 validation

Friend sideload steps are in [QUEST-INSTALL.md](QUEST-INSTALL.md). The export settings and host build are in [QUEST.md](QUEST.md). Download the [Quest preview release](https://github.com/philip-bankiers-helper/ashfall/releases/tag/v0.1.0-quest-preview.1).

Tested artifact: **ASHFALL-Quest-Preview.apk**, 534682358 bytes, SHA256 `ee544e90ed91d2829cecc992efa715c2c11486d76a612b8a5235787bd3f656c3`, built clean from `d4cf66e5bc41832ed530a50b01a2ed9e2230a932` (Godot 4.7.2, OpenXR Vendors 5.1.0). Subsequent commits update documentation only; the runtime is unchanged. Package `dev.philipbankier.ashfallquest`, title **ASHFALL Quest Preview**, debug-signed development sideload, not a store release. The APK SHA256 and v2 signature were verified again before publication. Public distribution checks passed 1,120. Build, setup, and audit checks passed 22.

The port preserves the original 925 asset files, all 180 gameplay scripts and the
OpenXR action map byte-for-byte against commit
`5d206e6b5f20618e291b6148a5c311c175cf15bf`. The Windows preset is unchanged.
All three maps (Relay Valley, Sandbox Range, Cyber Bird), 28 active weapon slots,
extended campaign, match modes and multiplayer implementation remain included.
This is content preservation evidence, not a playtest of every feature.

## Observed on a physical Quest 3

The first non-Gradle APK installed but exited because `libopenxr_loader.so` was
missing. The corrected Gradle/Meta OpenXR export includes that library, the
ARM64 Godot/vendor libraries, Quest VR categories and head-tracking metadata.

The corrected build installed and logged:

- `OpenXR: Running on OpenXR runtime: Oculus 207.297.0`
- `ASHFALL_START xr=true device=Adreno (TM) 740`
- `MISSION_BEGIN 0 enemies=4`
- `XR_SESSION session_begun`, `session_visible`, and `session_focussed`

The first cold load reached the XR session after about 45 seconds. It remained
running for several minutes with no Godot error lines. Boundary and normal
proximity sensing remained enabled.

## Physical playtest — 2026-10-28

The first installation check on October 27 was unworn, with black captures and
inactive controllers. During the guided wearing test on October 28, the user
reported: "yes it worked and i could go in and see the map, gun shooting and
reloading worked too".

The user identified the tested map as **Cyber Bird** and confirmed that left-stick
movement and right-stick turning both work and stop correctly when released.
Cyber Bird entry, visible gameplay, firing, reloading, movement and turning are
now **human-confirmed**.
The running app's telemetry also recorded about 112 seconds with both controllers
ready while XR was focused. No Godot errors were found in the retained app log
at that checkpoint. Telemetry supports controller tracking; the user's report is
the evidence for successful firing and reloading.

The specific weapon is unknown. Item switching and explicit menu-selection checks have not been verified. The other maps, the
other weapons, modes, audio, comfort, and sustained in-game performance remain
untested. Internet multiplayer and cross-platform sessions are also untested.
This preview is not production-ready. Runtime frame callbacks while unworn do
not establish playable frame rate. Do not change Guardian or proximity settings
to extend this result; the checked run left boundary and normal proximity
sensing enabled.

## Host/build checks

The existing public distribution check passed all 1,120 checks (139 routed WAVs).
The APK audit requires real script entries and their compiled targets, only
ARM64 native libraries, the OpenXR loader and the full-content VR launch flags.
Setup was tested on a fresh temporary tree and an identical second run; a
modified template was refused and preserved. Negative artifact checks cover
missing/empty loader, wrong ABI, missing scripts/targets and wrong launch flags.

Build receipts deliberately keep `headset_verified=false`: the build runner
cannot perform a physical test. The later human-confirmed results above are
recorded separately from those build-time receipts.
