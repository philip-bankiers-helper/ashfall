# Quest 3 validation — 2026-10-27

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

## Still requires a person wearing the headset

The headset was unworn; captures were black and the controllers were inactive.
Rendered-menu visibility, controller pointing/selection, locomotion, firing,
reloading, all-map play, audio, comfort and sustained in-game performance are
**not verified**. Runtime frame callbacks while unworn do not establish playable
frame rate. Internet multiplayer and cross-platform sessions are also untested.

First wearing check: wake both controllers, view the Ashfall menu, point at a
button and squeeze/release the trigger. Then enter a map, move, fire and reload.
Test the other maps and a second-player session before inviting friends.

## Host/build checks

The existing public distribution check passed all 1,120 checks (139 routed WAVs).
The APK audit requires real script entries and their compiled targets, only
ARM64 native libraries, the OpenXR loader and the full-content VR launch flags.
Setup was tested on a fresh temporary tree and an identical second run; a
modified template was refused and preserved. Negative artifact checks cover
missing/empty loader, wrong ABI, missing scripts/targets and wrong launch flags.

Build receipts deliberately keep `headset_verified=false`; installation and XR
startup evidence do not substitute for the physical checks above.
