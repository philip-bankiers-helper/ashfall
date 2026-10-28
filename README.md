# ASHFALL

Standalone Windows PC VR game with physical weapon reloads, swords, consumables,
climbing, flying, construction and an experimental friends multiplayer mode.
This repository is separate from [Skyrim ASHFALL](https://github.com/alingold/skyrim-ashfall).

## Play — no development tools required

1. Open [Releases](https://github.com/alingold/ashfall/releases/tag/v0.1.0-preview).
2. Download **ASHFALL-Windows-x64.zip**. Do not choose GitHub's automatic **Source code** ZIP.
3. Right-click the downloaded ZIP → **Extract All**. Keep the extracted folder intact.
4. For VR, establish your usual PC headset connection first, then double-click
   **Launch-VR.cmd**. Godot is embedded in the game; you do not install it separately.
5. For a desktop preview, double-click **Launch-Desktop.cmd**. Close the game normally
   before switching modes. This is PC VR, not a standalone Quest/Android APK.

Read [INSTALL.md](INSTALL.md) for setup and troubleshooting and [docs/HOSTING.md](docs/HOSTING.md)
for a friends lobby. Everybody in a lobby needs the same public release. Public
and earlier private builds deliberately have different content fingerprints.

## Quest 3 development preview

This branch adds a full-content standalone Quest 3 Android export.
See [docs/QUEST.md](docs/QUEST.md) for the pinned toolchain, local dependency
setup and build command. Headset validation results and remaining checks are
recorded in [docs/QUEST-VALIDATION.md](docs/QUEST-VALIDATION.md).

## Source and assets

Original code is **Apache-2.0**. Third-party art keeps its existing license.
The included Fishbones launcher model is **CC-BY-NC-4.0**, so the complete art bundle
is not licensed for commercial use as a whole. See [NOTICE](NOTICE) and LICENSES/.
New procedural audio replaces recordings that could not be publicly redistributed.

Large licensed assets and playable binaries are versioned Release downloads,
not Git history. Contributors: run `tools\Fetch-Assets.ps1` after cloning, then
follow [docs/BUILD.md](docs/BUILD.md). Fetching assets verifies the published SHA256
and refuses path traversal. No Git LFS account is required.

## Current status

First public preview, based on standalone 1000. All imported weapons, physical item
systems, original maps and original CYBER BIRD city code are retained. Public-only
audio, clean-source build and exact exported executable receive offline checks.
Those checks do not prove headset fit, audio feel, Internet play or every GPU/runtime
combination. Multiplayer remains experimental; there is no matchmaking service or
host migration. Report the release version and a short reproduction in Issues.
