# ASHFALL

ASHFALL is a VR game with physical weapon reloads, swords, consumables,
climbing, flying, construction and experimental friends multiplayer.
This fork adds a standalone Quest 3 preview to
[Al Ingold's original Windows PC VR game](https://github.com/alingold/ashfall).
It is separate from [Skyrim ASHFALL](https://github.com/alingold/skyrim-ashfall).

## Play on Quest 3

Download **ASHFALL-Quest-Preview.apk** from the
[Quest preview release](https://github.com/philip-bankiers-helper/ashfall/releases/tag/v0.1.0-quest-preview.1) and follow the
[Quest install guide](docs/QUEST-INSTALL.md). No game engine or source build is
needed. Install once over USB with Developer Mode enabled, then play untethered.

All three maps, 28 active weapon slots, original modes and multiplayer code remain
included. On October 28, 2026, a player confirmed Cyber Bird map entry, firing,
reloading, movement and turning on a standalone Quest 3. Other content,
sustained performance and Quest multiplayer still need testing. This is a
sideloaded development preview, not a store release.

See [validation details](docs/QUEST-VALIDATION.md) for the exact tested APK and
remaining checks, or [build instructions](docs/QUEST.md) to work on the port.

## Play on Windows PC

1. Open the [original Windows release](https://github.com/alingold/ashfall/releases/tag/v0.1.0-preview).
2. Download **ASHFALL-Windows-x64.zip**, rather than GitHub's automatic source ZIP.
3. Extract the ZIP and keep the extracted folder intact.
4. For PC VR, establish your usual headset connection, then run **Launch-VR.cmd**.
5. For a desktop preview, run **Launch-Desktop.cmd**. Close the game before switching modes.

Read [INSTALL.md](INSTALL.md) for Windows setup and troubleshooting and
[docs/HOSTING.md](docs/HOSTING.md) for the experimental friends lobby.
Everyone in a lobby needs compatible content fingerprints; Quest-to-PC sessions
have not been tested. There is no matchmaking service or host migration.

## Source and assets

Original code is **Apache-2.0**. Third-party art keeps its existing license.
The included Fishbones launcher model is **CC-BY-NC-4.0**, so the complete art bundle
is not licensed for commercial use as a whole. See [NOTICE](NOTICE) and [LICENSES/](LICENSES/).
New procedural audio replaces recordings that could not be publicly redistributed.

Large licensed assets and playable binaries are versioned Release downloads,
not Git history. Contributors: fetch the verified source asset bundle described
in [docs/BUILD.md](docs/BUILD.md) before building. Windows users can run
`tools\Fetch-Assets.ps1`. The manifest points to the original asset release;
no Git LFS account is required.
