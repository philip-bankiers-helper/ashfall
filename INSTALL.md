# Install and run ASHFALL

## Windows PC

Download **ASHFALL-Windows-x64.zip** from this repository's Releases and extract it.
No Python, Git, Godot editor or compiler is needed to play. The executable contains
the game resources. Leave LICENSE, NOTICE, LICENSES and the launchers beside it.
An x64 Windows PC, a working graphics driver and sufficient space for the ZIP plus
its extracted contents are required. A recent gaming GPU is recommended; hardware
minimums have not been benchmarked. Linux, native Quest and macOS are not packaged.

## VR

Connect the headset to the PC using your usual supported PC VR connection. Confirm
that another ordinary OpenXR game works on that connection. Start **Launch-VR.cmd**.
Use the current headset runtime; the launcher does not switch runtime or install
drivers. Exit other VR games before starting ASHFALL. A monitor preview alone does
not establish that the headset session is active.

## First actions

Use the in-game settings and controls display. A quick A tap stows/restores the
held item; hold A to open the item selector. Grip targets to pick them up. The
backpack catalog in playtest mode supplies items. Physical reload gestures differ
by weapon. B marks a surface; holding B opens the mark selector. Hold the build
trigger for a preview and release to place. The game provides calibration/settings
for standalone movement; these are separate from Skyrim's controls.

## Desktop, server and friends

**Launch-Desktop.cmd** opens the desktop preview. **Launch-Server.cmd** starts a
dedicated server; it does not open a VR session. See docs/HOSTING.md for the port,
room settings, practice mode and joining. The release makes no firewall/router
changes. A local desktop check is not an Internet connectivity test.

## Data and removal

New public-release preferences/logs are stored in the extracted folder's
`release-profile` (servers: `server-profile`), separate from development builds.
Logs are under `logs`. To uninstall, close the game and delete its extracted folder.
If you want to retain preferences, copy the profile folder before removal.

## If it does not start

Extract the whole ZIP first; do not run from inside the ZIP. Try the desktop launcher
to separate a game startup issue from a headset connection issue. VR exit codes2/3
mean OpenXR startup/session loss. Keep the log, remove personal data, and report it.
Do not disable antivirus, change security settings or install a different runtime
automatically. The release is unsigned; no security override is required by these
instructions. Builds are supplied with SHA256 checksums for integrity verification.
