# ASHFALL Quest Preview — friend install (Quest 3)

Debug-signed development preview for your own Quest 3. Sideload only. Not a store
release and not production-ready. Original code is Apache-2.0. Third-party art
keeps its own license. The Fishbones launcher model is CC-BY-NC-4.0, so the full
art bundle is not licensed for commercial use. See [NOTICE](../NOTICE) and
[LICENSES/](../LICENSES/).

Windows PC VR is a different download. Those steps stay in [INSTALL.md](../INSTALL.md)
under **Windows PC**. This page does not replace them.

Build settings: [QUEST.md](QUEST.md). What was confirmed on a headset:
[QUEST-VALIDATION.md](QUEST-VALIDATION.md).

## Download the APK

| | |
| --- | --- |
| File | `ASHFALL-Quest-Preview.apk` |
| Size | 534682358 bytes |
| SHA256 | `ee544e90ed91d2829cecc992efa715c2c11486d76a612b8a5235787bd3f656c3` |
| Built clean from | `d4cf66e5bc41832ed530a50b01a2ed9e2230a932` |
| Engine | Godot 4.7.2, OpenXR Vendors addon 5.1.0 |
| Package | `dev.philipbankier.ashfallquest` |
| Headset title | **ASHFALL Quest Preview** |

Download [Quest preview 1](https://github.com/philip-bankiers-helper/ashfall/releases/tag/v0.1.0-quest-preview.1). The APK SHA256 and v2 signature were verified before publication. Later documentation updates do not change the tested runtime.

Download that APK. Do not install GitHub's source ZIP or
**ASHFALL-Windows-x64.zip** on the headset.

The APK still contains all 3 maps, 28 active weapon slots, all original modes
and scripts, and 925 original assets. Public distribution checks passed 1,120.
Build, setup, and audit checks passed 22.

## First install

1. Enable Developer Mode using [Meta's device setup guide](https://developers.meta.com/vr/documentation/native/android/mobile-device-setup/).
2. Use a Mac or Windows computer and a USB cable that carries data.
3. When the headset asks, approve USB debugging for your own computer.
4. Open [Meta Quest Developer Hub (MQDH)](https://developers.meta.com/vr/documentation/native/android/ts-mqdh-getting-started/). In **Device Manager → Apps**, drag in the APK or use **Add Build**, following [Meta's APK installation guide](https://developers.meta.com/vr/documentation/unity/ts-mqdh-deploy-build/). Wait for installation to finish.

   If you already use `adb`, the equivalent command is:

   ```bash
   adb install -r ASHFALL-Quest-Preview.apk
   ```

   `install -r` replaces an older copy of this package. These steps do not
   uninstall other apps and do not ask you to change Guardian or proximity
   settings.

After this install, unplug the cable. Standalone play does not need the
computer, USB, Quest Link, or Air Link.

## Start the game

Open **Unknown Sources** and launch **ASHFALL Quest Preview**. Wake both
controllers. If **Switch to Controllers** appears, choose **Continue** while
you are wearing the headset. The first cold load takes about 35–45 seconds.

## What one worn session confirmed (2026-10-28)

Cyber Bird city map entry, a visible game, a gun firing and reloading, and
left-stick move plus right-stick turn that both stop when you release the stick.
The specific weapon was not identified. That session did not clear every menu
or controller action.

Still untested: other maps, other weapons, item switching, modes, audio,
comfort, sustained performance, and Internet or cross-platform multiplayer.
Do not treat a lobby or a long session as already proven.

## Playtest, one step at a time

Stop when something fails and write that down. Skip later steps until the
earlier one is fine. If you feel unwell, take the headset off. Leave Guardian
and proximity as they are.

1. Install and launch as above.
2. Enter a map. Cyber Bird is the one already confirmed.
3. Confirm you can see the game world.
4. Move with the left stick, release it, and confirm movement stops.
5. Turn with the right stick, release it, and confirm turning stops.
6. Fire, then reload. Note the weapon if the game shows its name.
7. Only then try another map, another weapon, item switching, or another mode.
8. Note whether you hear the action you just did.
9. Note comfort and whether the view stays steady for a few minutes. This is
   still an open check, not a pass.

## Report

Report release **v0.1.0-quest-preview.1**,
the map, the weapon, the mode, the steps you took, and what happened.
