# Ubuntu / Vinegar setup

Inspected 2026-09-14. Rojo 7.7.0, StyLua 2.5.2 and Selene 0.31.0 run through `/home/ned/.rokit/bin`. Preserved `rokit.toml` byte-for-byte (SHA-256 `d83d6e0017a35e50afaa1af3729d9d125c5a19b5f0c4b16e6131c60206b7f4e3`). All four requested VS Code extensions are already installed. Project settings select the existing Rokit executables; no global editor settings were changed. The read-only sandbox produced a VS Code log-directory warning during extension listing, but the inventory succeeded.

## Rojo plugin

Wine's `Local AppData` registry entry resolves to:

`/home/ned/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata`

Installed the official [Rojo 7.7.0 release](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0) plugin at:

`/home/ned/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/Plugins/Rojo-7.7.0.rbxm`

The directory did not previously exist. The Studio version's `Plugins/Qt5` directory is application content and was left alone. Installed/downloaded plugin SHA-256 matches: `214e5ad84ccdc88f873e0467b6724e4ea9ada8ea340fcb9d4397cb899a67c83f`. This verifies copy integrity, not an independently signed checksum. The asset came directly from the official release.

Save any open place before restarting Studio to load the local plugin. Website authentication is not needed. No account change, live API access, or broader Flatpak permissions were made. Existing Vinegar permissions already include Documents and shared networking.

## Verify synchronization once

1. Open a disposable local copy of `build/smoke.rbxlx` in Studio; never synchronize into an unrelated place.
2. Stop any existing project Rojo process with Ctrl+C in its terminal. Only one project should use port 34872.
3. In the VS Code terminal run `bash scripts/project.sh smoke-serve`.
4. In Studio's Plugins tab open Rojo, connect to `localhost` port `34872`, and review/accept the synchronization into this smoke place.
5. Change `SyncTestCube`'s first Color value in `smoke.project.json` from `1` to `0.3`, save, and confirm that the cube changes color in Studio edit mode. Restore `1` and confirm again.
6. Press Play and confirm Output contains `[REDLINE COUNTY] Milestone A smoke test: server running.` Stop Play.
7. Stop the smoke server, run `bash scripts/project.sh serve`, open `build/redline-county.rbxlx`, and connect Rojo to that place. Press Play for the handling lab. Stop/restart Play after code changes; runtime-created course geometry does not rebuild from a live edit automatically.

Rojo uses `--address 127.0.0.1` explicitly. If the Codex-started server is still running but not in your terminal, its project status page is `http://localhost:34872/`; keep it for the prototype test, or ask Codex to stop its own process before running the smoke server. Do not kill unrelated processes or bind to `0.0.0.0`. If the plugin is absent after restart, use Studio's Plugins Folder action to confirm the path before moving files. Opening the built place and pressing Play works independently of Rojo synchronization.

## API references used

- [Rojo installation](https://rojo.space/docs/v7/getting-started/installation/) and the 7.7.0 release above; installed CLI `serve --help` and `sourcemap --help` were checked directly.
- [Luau LSP configuration](https://github.com/JohnnyMorganz/luau-lsp/blob/main/README.md); settings keys also checked against installed extension 1.69.0.
- [Selene Roblox support](https://kampfkarren.github.io/selene/roblox.html).
- [Roblox network ownership](https://create.roblox.com/docs/physics/network-ownership) and [movement security](https://create.roblox.com/docs/scripting/security/network-ownership): client-owned physics cannot be treated as authoritative movement evidence. The prototype instead keeps vehicle physics on the server.
- [VectorForce](https://create.roblox.com/docs/reference/engine/classes/VectorForce), [AlignOrientation](https://create.roblox.com/docs/reference/engine/classes/AlignOrientation), [VehicleSeat](https://create.roblox.com/docs/reference/engine/classes/VehicleSeat), [ContextActionService](https://create.roblox.com/docs/reference/engine/classes/ContextActionService), and [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService). API/type verification does not replace engine execution.
