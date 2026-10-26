# Build ASHFALL from source

Players should download the ready-to-run Windows release and follow the main README. An editor or compiler is not required to play.

For development, use the official **Godot 4.7.2** Windows editor and the matching Windows export templates. This release was built with `v4.7.2.stable.official.ed1daf0bf`. Install templates through the editor's **Manage Export Templates** command or use the official self-contained editor/template layout. Do not substitute templates from another Godot version.

1. Clone this repository.
2. Follow the README to obtain and verify the matching asset pack. The asset pack is necessary for the full models, materials, audio and UI; it is separate from Git to keep the source repository manageable.
3. Open PowerShell in the repository and run:

   ```powershell
   .\tools\build.ps1 -GodotPath 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
   ```

The build script imports resources, runs distribution-specific checks, and exports `build\Ashfall.exe` with the game data embedded. Logs and the executable's SHA-256 are in `build\logs`. The checks cover audio routing and playable original replacement sounds, inventory capacity, supply definitions, and a distinct multiplayer content ID. They do not validate headset appearance or physical controls.

An optional output/log location can be supplied with `-OutputDirectory` and `-LogDirectory`. The script isolates its user profile for the build and restores its process environment afterward. It never launches VR or changes the system's OpenXR runtime.

For a bounded test of the exact executable without initializing a headset:

```powershell
.\build\Ashfall.exe --headless --xr-mode off --audio-driver Dummy -- --desktop --extended --playtest-catalog --smoke
```

A successful run exits with code zero and prints `SMOKE_OK`; any `SCRIPT ERROR:` or `ERROR:` needs investigation. Repeat with `--low-poly` and `--alternate-models` after `--` when changing model selection or asset packaging. XR-off tests do not establish VR performance, controller fit, comfort, sound balance, or Internet multiplayer acceptance.

The public audio bank contains newly authored procedural cues rather than recordings extracted from another game. Legacy resource filenames remain for compatibility with interaction timing and routing. Model and material licenses remain separate from the Apache-2.0 license for original project code; see the license notices accompanying the asset pack and release.
