# REDLINE COUNTY

An original coastal cops-and-getaway driving game in development. Current runnable slice: **handling lab + endless Autobahn/turbo mode**, preceded by a separate Milestone A smoke place. This is not the completed first release.

## Open the prototype

In Vinegar Studio, use **File → Open from File** and open:

`/home/ned/Documents/roblox/redline-county/build/redline-county.rbxlx`

If the Wine file chooser needs a Windows-style path, use:

`Z:\home\ned\Documents\roblox\redline-county\build\redline-county.rbxlx`

Press **Play**. Your character and starter Compact appear on a protected on-ramp beside the Autobahn. Walk beside it and press **E**, or tap its prompt. **WASD/arrows** drive, **S** brakes then reverses, **Space or Left Shift**, while turning at speed, drifts, **F** exits, and **R** recovers a stopped/overturned car to a free bay. Touch buttons appear while seated. The three garage buttons select free testing configurations; they are not purchases. Traffic cars are solid: hitting one explodes your car and gives you a replacement at the on-ramp after three seconds. Player-owned cars still ghost through one another. The course edges are open onto surrounding land; vehicles can drive on solid world parts and Terrain outside the course. Water is not drivable.

The course is generated when Play starts. An empty edit view in the prototype file is expected. The separate `build/smoke.rbxlx` contains a coral cube visible in edit mode.

## Autobahn and turbo

You start on a traffic-free on-ramp automatically; accelerate and merge left at the sign. After returning to the garage, sit in your stopped car and click **Autobahn** to re-enter. The night highway loads around drivers and recycles sections for indefinite driving. Headlights stay fixed to the car with constant beam angle/brightness; only their capped range increases with speed; the dashboard shows km/h, mph and trip kilometres. Turbo is enabled by default: accelerate to spool up; **T** or the **Turbo** button toggles it. Watch boost and heat on the dashboard. Stop and press **R** to return to the garage. See [Autobahn controls and acceptance checks](docs/AUTOBAHN.md).

## Commands

Run from this directory, or use the matching **Redline** VS Code tasks:

```bash
bash scripts/project.sh check       # format, lint, logic tests, types, two builds
bash scripts/project.sh serve       # default project, only 127.0.0.1:34872
bash scripts/project.sh format
```

The existing Rokit pins are unchanged. The additional test runtime is Luau 0.738 under ignored `.tools/`. On a fresh checkout, run `rokit install`, then `bash scripts/bootstrap-checks.sh` to fetch checksum-verified test tools. Install the recommended Luau LSP extension; `LUAU_LSP_BIN` can override its local executable path. `roblox.yml` is the project-local Selene Roblox standard-library snapshot generated on 2026-09-14. It allows offline linting; regeneration is explicit with `selene generate-roblox-std`.

- [Ubuntu/Vinegar setup and sync](docs/SETUP.md)
- [Studio playtest checklist](docs/PLAYTEST.md)
- [Current status and next milestone](docs/STATUS.md)
- [Implementation sequence](docs/PLAN.md)

Handling tuning lives in `src/shared/Config.luau`; pure math and lifecycle decisions are in `Driving.luau` and `Rules.luau`. Server modules build the course and vehicles, validate remote input, and enforce lifecycle checks. The client supplies input and renders UI/camera. There are no weapons, third-party models, external asset IDs, economy, persistence or publishing hooks. The server intentionally runs only in Studio at this stage.
