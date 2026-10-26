# Public release validation

Standalone source baseline: 1000. New public-only original audio, sanitized metadata, a separate preference folder and a distinct multiplayer fingerprint were packaged without modifying the development build.

A fresh Godot 4.7.2 import, 1,120 public-specific checks and fresh export passed. The exact exported executable passed headless XR-off smoke tests in default, low-poly and alternative-model modes, with exit0 and SMOKE_OK. These checks cover resource startup, routed public sounds and supply/inventory contracts; they are not headset or Internet acceptance.

Ashfall.exe SHA256: 2bc575031b8d5eb7612834b1815230d64f3c67afd4da9a82c6319fca17bf5561

Headset appearance, physical interactions, comfort, sound balance, GPU compatibility and remote networking still require human testing. Existing playtest defects are not claimed fixed by packaging. Report the release tag and reproduction in GitHub Issues; remove personal data from logs.

Additional source-protocol loopback verification: 68 session checks, 27 real host/client wire checks, compatible public client admitted, wrong password and private-build fingerprint rejected. These were loopback-only fixtures, not Internet/LAN/headset acceptance.
