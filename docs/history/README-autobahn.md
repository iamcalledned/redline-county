# REDLINE COUNTY

A Roblox driving game in development, currently focused on a **nighttime Autobahn simulator** with an endless highway, solid traffic, turbocharged cars, and a handling course. The original cops-and-getaway county remains the longer-term plan. This prototype runs in **Roblox Studio only**.

Updated September 15, 2026. Features below describe the current implementation; see [verification and known limits](#verification-and-known-limits) for what still needs playtesting.

## Start playing

On the configured Ubuntu/Vinegar workstation, launch Studio with:

```bash
flatpak run org.vinegarhq.Vinegar
```

Use **File → Open from File** and open [build/redline-county.rbxlx](build/redline-county.rbxlx). Its local path is:

```text
/home/ned/Documents/roblox/redline-county/build/redline-county.rbxlx
```

If the Wine file chooser needs a Windows-style path:

```text
Z:\home\ned\Documents\roblox\redline-county\build\redline-county.rbxlx
```

Press **Play**. Your character and default car start on a protected on-ramp outside the traffic lanes. Walk beside your car, press **E** or tap its prompt, accelerate along the ramp, and merge left at the sign. The default car is still labelled **Compact** in the garage even though it uses the imported sports-car appearance.

The world is generated when Play starts, so an empty edit view is expected. [build/smoke.rbxlx](build/smoke.rbxlx) is a separate setup test with a coral cube visible in edit mode.

After loading an updated build, **stop Play, reopen the place, and start a fresh Play session**. This reloads the cached car asset and applies place settings as well as scripts.

## Controls

| Action | Keyboard or on-screen control |
| --- | --- |
| Enter your car | **E** beside the car, or tap its prompt |
| Accelerate | **W / Up arrow**; touch **GAS** |
| Brake, then reverse | **S / Down arrow**; touch **BRAKE** |
| Steer | **A/D / Left/Right arrows**; touch arrow buttons |
| Drift | Hold **Space / Left Shift** while turning at speed; touch **DRIFT** |
| Exit | **F**; touch **EXIT** |
| Toggle turbo | **T** or **Turbo** button |
| Recover to a free garage bay | **R** or **Recover** button; stop or slow an overturned car first |
| Enter the Autobahn from the garage | **Autobahn** button while seated in your stopped car |
| Switch headlight rendering | **H** or the **Headlights** mode button |
| Change car configuration | **Compact**, **Coupe**, or **Interceptor** at the garage |

Touch driving buttons appear while seated. Car changes are free testing choices, subject to garage, occupancy, and cooldown checks. The cockpit camera switches automatically; there is no manual camera-mode toggle.

## Driving, highway, and traffic

- A divided highway with three lanes in each direction loads sections around drivers and recycles an 8,192-stud route for indefinite driving. Scenery repeats; the route is not infinitely unique.
- A separate acceleration lane and guardrail protect the on-ramp starting area until you merge. The garage and handling course remain accessible through recovery.
- Lane traffic travels in both directions at different lane speeds, with up to 72 traffic cars across the route. Cars are created and removed with active road sections.
- Traffic has solid colliders and server-side swept impact detection. Hitting traffic stops and explodes your car, shows a burning wreck, then replaces the same configuration on the on-ramp after three seconds.
- Explosions affect the crashed car through its recovery system; they do not blast apart the world. Player-owned cars still pass through one another.
- The shared raycast-suspension chassis supports acceleration, braking/reverse, gentler smoothed steering, drifting, slope alignment, and recovery. You can drive on solid world parts and Terrain beyond the handling course; water is not drivable.
- Ownership checks, one car per player, a 12-car cap, request rate limits, spawn/recovery cooldowns, and abandoned-car cleanup protect the prototype's vehicle lifecycle. Physics and traffic impacts are server-managed.

## Turbo and speed

Turbo is enabled by default. Sustained acceleration spools it up, adding acceleration and top speed. Heat builds under boost; overheating temporarily disables boost until the system cools. Releasing the accelerator removes boost power. **T** or the **Turbo** button toggles the system.

The HUD shows **km/h, mph, boost, heat, and Autobahn trip kilometres**. Speed uses horizontal velocity and a configured conversion of 0.28 metres per stud. Acceleration falls off as speed rises.

| Configuration | Unboosted limit | Fully boosted limit |
| --- | --- | --- |
| Compact / imported starter car | 190 km/h | 230 km/h |
| Coupe | 240 km/h | 300 km/h |
| Interceptor | 230 km/h | 280 km/h |

These are configured limits, not measured performance guarantees. This remains an arcade chassis rather than a full vehicle simulation.

## Default car and cockpit

The starter Compact uses **[2019 Sports Car // Rosh](https://create.roblox.com/store/asset/6810376207)** by **BadboyWestern**, asset ID **6810376207**. It retains this project's handling, controls, turbo, and collision systems. Coupe and Interceptor retain their prototype appearances.

The importer fits the car proportionally within an **8.5 × 16 stud** width/length envelope and adjusts the chassis footprint, suspension mounts, and headlight positions. It copies visual geometry and supported surface details while discarding the asset's scripts, controllers, seats, and joints. The built place enables third-party asset loading; the asset and its mesh/texture content must remain available through Roblox. If loading fails, the placeholder car stays usable and Studio's **Output** reports the failure.

The driver position follows the imported model's authored driver seat. Entering the imported car switches to a chassis-mounted **interior camera**; exiting restores the normal character camera. The local avatar is hidden in cockpit view to avoid head/accessory obstruction, while other players can still see the driver. Cars without a loaded cockpit use the chase camera.

An original **animated steering wheel** turns with the smoothed steering input, up to 120° each way. Road tyres and the driver's hands are not animated. The latest fix makes the seat use the same scaling pivot as the car, correcting the calculation that placed the cockpit behind the body. The corrected interior still needs visual validation in Studio.

## Night driving and headlights

The place opens at **00:30**, with subdued ambient lighting, mild bloom, lit highway/on-ramp lamps, road-edge reflectors, and visible traffic lamps. Up to eight nearby traffic cars receive active local headlights.

Player headlight reach increases from **36 studs at rest to 120 studs at 180 km/h**, then stays capped. Beam position follows the chassis without position smoothing; native beam angle and brightness remain fixed. At higher speeds, that finite reach gives less time to react to what is visible ahead.

**H** or the headlight button switches between:

- **Road beam — default:** a frame-updated, raycast-positioned visual patch on the road, added to work around the native light patch trailing behind the car. It is an approximation: it does not illuminate vehicle bodies or cast their shadows, and coarse sampling can leave gaps or spill near edges/obstacles.
- **Native:** Roblox SpotLights mounted directly on the chassis, with range updated every rendered frame. This mode remains available for comparison; visible native-light lag was reported in Studio.

The local car's native lights are disabled in road-beam mode so both effects do not overlap. Headlights shut off on a crash. The road-beam workaround still needs visual and performance testing on Vinegar.

## Development commands

The existing toolchain pins are **Rojo 7.7.0**, **StyLua 2.5.2**, and **Selene 0.31.0**, recorded in [rokit.toml](rokit.toml). On a fresh checkout with Rokit installed:

```bash
rokit install
bash scripts/bootstrap-checks.sh
```

Install the recommended VS Code extensions, including Luau LSP. The bootstrap script downloads checksum-verified Luau 0.738 and Roblox type definitions into ignored `.tools/`. The helper scripts target the configured Ubuntu workstation; elsewhere, put Rokit tools on `PATH` and set `LUAU_LSP_BIN` to the language-server executable if needed. The tracked `roblox.yml` provides the project-local Selene Roblox definitions.

Run from this directory, or use the matching **Redline** VS Code tasks:

```bash
bash scripts/project.sh check        # formatting check, lint, logic tests, types, both builds
bash scripts/project.sh build        # rebuild both tracked .rbxlx files
bash scripts/project.sh serve        # Rojo: 127.0.0.1:34872; connect the Studio plugin
bash scripts/project.sh smoke-serve  # serve the separate smoke project
bash scripts/project.sh format       # apply Luau formatting
bash scripts/project.sh lint
bash scripts/project.sh test
bash scripts/project.sh typecheck
bash scripts/project.sh sourcemap
```

Both `.rbxlx` files under `build/` are tracked in Git so a checkout includes places ready to open. After source changes, rebuild and commit the updated place files alongside the source. Downloaded tools, the generated sourcemap, dependency installations, credentials, and temporary files remain ignored.

## Code and tuning

[Config.luau](src/shared/Config.luau) contains car performance, steering response, turbo, headlight range, highway, crash recovery, and imported-car size/yaw/seat-offset settings.

| Location | Responsibility |
| --- | --- |
| `src/server/` | World generation, traffic, chassis, asset import, cockpit rig, impacts, ownership and lifecycle |
| `src/client/` | Keyboard/touch controls, HUD, cockpit/chase camera, native lighting and road-beam rendering |
| `src/shared/` | Configuration, driving/turbo math, units, highway/traffic calculations, collision sweeps and model-fit math |
| `tests/logic.luau` | Standalone logic regression checks |
| `default.project.json` / `smoke.project.json` | Rojo place structure and settings |
| `scripts/` | Build, check, and test-tool setup commands |

## Verification and known limits

The latest code checks passed **23 standalone logic tests**, formatting, lint, strict Roblox/pure-module type analysis, and both Rojo builds. These checks do not simulate Roblox physics, rendering, services, or multiplayer replication. This README-only update does not change the game builds.

User playtests confirmed entry, basic driving, revised drift/free roam, and imported-car loading. They also exposed headlight lag and incorrect cockpit placement. The latest fixes are implemented, but **cockpit fit/visibility and road-beam tracking still need Studio retests**. High-speed crashes, highway recycle seams, touch layouts, larger-car handling, and multiple separated drivers also need systematic acceptance testing. Server-owned physics may introduce latency.

Traffic follows fixed lanes; it has no lane-changing or avoidance AI. The 12-car limit is an implementation cap, not verified multiplayer capacity. There are no playable police/outlaw roles, pursuit/capture missions, solo delivery/time trials, Hot Car event, currency/shop, persistence, weapons, or monetization yet. The Interceptor is a vehicle configuration, not a working police role. No live DataStore API access is needed for this prototype.

## Further documentation

- [Ubuntu/Vinegar setup and Rojo sync](docs/SETUP.md)
- [Autobahn details and acceptance checks](docs/AUTOBAHN.md)
- [Driving playtest checklist](docs/PLAYTEST.md)
- [Development status and chronological change notes](docs/STATUS.md)
- [Original milestone plan](docs/PLAN.md)
