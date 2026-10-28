# Quest 3 validation

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

Map entry, visible gameplay, firing and reloading are now **human-confirmed**.
The running app's telemetry also recorded about 112 seconds with both controllers
ready while XR was focused. No Godot errors were found in the retained app log
at that checkpoint. Telemetry supports controller tracking; the user's report is
the evidence for successful firing and reloading.

The specific map and weapon, movement/turning response, explicit menu-selection
checks, other maps and weapons, audio, comfort and sustained in-game performance
remain to be checked. Internet multiplayer and cross-platform sessions are also
untested. Runtime frame callbacks while unworn do not establish playable frame
rate.

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
