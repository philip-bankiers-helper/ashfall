# Hosting ASHFALL for friends

Distribute the complete `ASHFALL-Windows-x64` folder to each friend. The executable embeds game content; keep its licenses and launchers with it. The lobby checks a generated code/asset fingerprint so different builds cannot accidentally share a match.

## Host while playing

1. Run `Launch-VR.cmd` or `Launch-Desktop.cmd`.
2. Choose **HOST / JOIN**. Set name, room name, port and optional password. Default UDP port is **24760**.
3. Choose **HOST PRIVATE LOBBY**. Select a map and configure **HOST CONTROLS**. Teams can be cycled beside each player or automatically balanced.
4. Friends enter the host's reachable IP address, the same port and password, then choose **JOIN LOBBY**. They may instead join as a spectator if enabled.
5. Every active player selects **READY**. At least two players are needed, or one with the Practice/catalog preset. A short countdown and loading barrier precede the match.

READY can be cancelled during countdown. The host can remove players, lock joining, return everyone home or rematch. Opening personal settings does not pause a network match. Closing the playing host ends the session; there is no host migration.

## Dedicated server on a separate Windows computer

Run `Launch-Server.cmd`. It starts the same game headlessly with XR disabled and no audio device. The server does not occupy a player slot; the first connected friend becomes lobby administrator. Up to eight players, including spectators, may connect. Example from a terminal in the delivered folder:

```bat
Launch-Server.cmd --port 24760 --password friends --map cyber_bird
```

Map IDs are `valley`, `range`, and `cyber_bird`. Add `--mode respawn` for timed respawns; otherwise revive mode is the default. Lobby controls can subsequently change rules. The server log is `logs\server.log`. Close only this server window when you want to stop it.

## Reaching the host

On the same LAN, use the host's local IPv4 address from `ipconfig`. For remote friends, use a mutually authorized VPN address, or arrange UDP forwarding for the chosen port on the host's network. Windows may request access for this new executable. No firewall/router changes have been made by this update. Godot's [hosting documentation](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#hosting-considerations) explains LAN addressing and UDP forwarding. A VPN such as Tailscale can use direct or relayed connections; its [connection documentation](https://tailscale.com/docs/reference/connection-types) explains the difference. Relay latency can affect play.

For a same-computer desktop check, join `127.0.0.1`. For different computers, `127.0.0.1` refers to the joining computer and will not reach your friend.

If joining fails, confirm the host is still running, both folders are the same build, the IP/UDP port are reachable, and the password matches. A locked/full lobby or a disabled late-join policy displays a reason. Rejoin from the same running client within 30 seconds to reclaim a reserved inventory after a disconnect.

Player preferences live in the new standalone profile. Server preferences use a separate `server-profile` directory. Previous builds and Skyrim are not modified.
