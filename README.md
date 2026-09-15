# REDLINE COUNTY

A Roblox getaway driving game set around **Hopedale, Massachusetts**: take a job, pick an escape route, lose the AI police, bank your haul, and improve a car you keep. Town blocks provide cover, the parkway rewards speed, and a fictional mill yard offers a tighter route through buildings.

This is a **local development build**, with the quality-review recommendations implemented in code. It still needs a fresh Roblox Studio playtest for handling, collisions, audio, device layout and performance. The world is a believable, stylized interpretation of Hopedale, with provisional flat elevation and approximate facades—not a surveyed or photorealistic reconstruction.

## Open and play

On the configured Ubuntu/Vinegar workstation:

```bash
flatpak run org.vinegarhq.Vinegar
```

In Studio, open [build/redline-county.rbxlx](build/redline-county.rbxlx):

```text
/home/ned/Documents/roblox/redline-county/build/redline-county.rbxlx
```

Wine path: `Z:\home\ned\Documents\roblox\redline-county\build\redline-county.rbxlx`.

**Stop the old Play session and reopen the rebuilt file after updating.** Press Play, then **START FIRST GETAWAY**. This supplies your selected car (Electric sedan initially), seats you, and opens your assigned bay. Follow cyan road guidance to the gold pickup. Break police sight for ten seconds, then return home and stop for two seconds to bank the reward. The results screen leads to your next upgrade or job.

To explore, dismiss the welcome screen and use **Menu → Your garage**, or press **E** at a display selector. Use the bay wall switch to open the door and **E** beside your car to enter. Follow the driveway onto Adin Street. The garage, roads and landmarks are also visible before Play.

## Jobs and rewards

| Job | What changes the challenge | Starting heat | Time | Base haul |
| --- | --- | --- | --- | --- |
| Hot Package | One pickup, escape, deliver; the guided first job | 1 | 4 min | $300 |
| Town Hall Run | Five ordered stashes around the town loop | 2 | 6 min | $800 |
| Fragile Cargo | Two stashes; new damage after the first pickup reduces cargo quality by twice the damage increase | 2 | 4½ min | $600 |
| Heat Run | Three parkway pickups; choose **bank** or **continue** after each intermediate pickup | 1, rising to 3 | 7 min | $350 per pickup |

Heat Run offers twelve seconds to decide; no answer chooses banking. **Bank** means lose the police and deliver home, not instant cash. Continuing raises heat and exposes the unbanked haul to failure. The last pickup automatically starts the escape stage. At heat three, a roadblock may be deployed ahead on the parkway, announced by dispatch, with an open opposite lane. A town exit is another way around it.

A successful delivery adds $2 per whole second remaining, applies **Light 1× / Busy 1.5× / Rush 2.2×**, then adds 20% for a damage-free car. Fragile Cargo multiplies that payout by remaining cargo quality. Server-observed position, damage and pursuit state determine progress and rewards; clients cannot submit a payout. Police holding a slow car nearby for five seconds causes a bust. Leaving your working car, running out of time or disabling it loses the job.

Other reasons to drive:

- Continuous parkway laps pay **$100 + max(0, 150 − floor(lap seconds / 2))**. Best lap and completed laps belong to the saved garage. Leaving the course, teleporting or abandoning the car invalidates an attempt.
- Grounded, sustained drifting earns a chain. Straighten out to bank it; an impact loses the chain. Cash is capped at $100 per bank.
- Discover Ballou Park, Bancroft Library, Little Red Shop and the Parklands entrance for a one-time $150 each.
- Speeding near a roaming patrol can trigger a free pursuit. Escaping a free pursuit does not pay a contract reward.

## Roads, traffic and police

The finite district covers **1,600 × 940 metres**. It includes the **917 m town loop**, **1,705 m Redline Parkway** and approximately **484 m Mill Service Loop**, joined to the actual navigation graph. Adin/Parkway Access and Centennial/Mill/North Parkway Access provide independent ways between town and parkway. The mill loop also has a paved central cut-through. New service roads, mill buildings and parkway are explicitly fictional; existing town streets retain their mapped topology.

Mapped scenery includes the pond shore, walk-only Parklands paths, the Freedom Street bridge, Town Hall, Ballou Park, Little Red Shop and Bancroft Library. Houses use footprint-based shells with roofs and selected facade detail. The mill yard adds brick workshops, loading doors, industrial windows and sight-breaking cover. Closed outer branches have barriers and warnings; they do not secretly lead into an infinite town.

There are **6 / 12 / 18 civilian targets** across both directions of the town, parkway and mill loops, plus two roaming police. The busiest active job determines the shared traffic target. Cars use physical collision bodies, lane following, headway braking, obstacle checks and short junction reservations. Recovery reverses only with rear clearance. Stranded or excess cars retire at a distance; active pursuits return officers to patrol. Total police are capped at eight per server.

The first responding officer follows. Additional officers project an interception target from observed motion onto the road network. After losing sight, they search branches near the last sighting rather than targeting the hidden player's current position. Officers slow for bends, protect the home driveway and use bounded speeds. Proximity alerts report direction, distance and whether a cruiser is closing. These rules still require traffic-and-contact testing in the engine.

## Cars, upgrades and saving

Three free starter vehicles use bundled, script-free geometry from Roblox's free vehicle collection:

| Vehicle | Role | Source asset |
| --- | --- | --- |
| Electric | Predictable starter sedan | 6418239833 |
| Sport | Agile coupe for slides and fast escapes | 6433323089 |
| Pickup | Heavier, stable truck | 6418225759 |
| Police | AI cruiser | 6418230807 |

Cars have a raycast suspension chassis, finite steering geometry, speed-dependent steering, graduated town damage, cockpit/chase views, turning steering wheels and rolling/steering road wheels. Visible mesh panels receive your paint; imported colored decals no longer override the finish. Glass, lamps, tyres, trim and police livery stay distinct. Vehicle/audio provenance is in [assets/vehicle-sources.json](assets/vehicle-sources.json) and [assets/audio-sources.json](assets/audio-sources.json). Meshes, textures and audio still load through Roblox's asset services.

At home, **Workshop / U** sells three levels of each performance upgrade, per car:

| Upgrade | Effect per level | Prices |
| --- | --- | --- |
| Powertrain | +12% acceleration, +5% top-speed limit | $500 / $1,100 / $2,200 |
| Brakes | +18% braking force | $350 / $800 / $1,600 |
| Tyres | +12% grip, +8% sliding grip | $450 / $950 / $1,900 |
| Suspension | +8% spring rate, +16% damping | $400 / $900 / $1,800 |

Paint, wheel finishes and interior colors cost $180–$350. Purchased finishes can be fitted again without paying twice; equipped choices are stored per car. Purchases require your own car, parked at home, outside a job. There are no paid boosts or real-money purchases.

**Saving depends on how you run the game.** Unpublished local `.rbxlx` files explicitly show **Local practice · saves unavailable**. A published test experience with Studio API access uses the separate `RedlineProfiles_Studio_v1` data store. A live release would use `RedlineProfiles_v1`. Cash, wins, selected car, upgrades, cosmetics, discoveries and lap records are saved together using session leases, serialized writes, retries and periodic/critical saves. A failed or locked load does not create an empty replacement profile. Follow the fault/reconnect tests in [QUALITY-ACCEPTANCE.md](docs/QUALITY-ACCEPTANCE.md).

This shared garage supports **three players**. A fourth connection is rejected with a clear message. Set the experience's maximum player count to three for testing/release. `Config.DevelopmentOnly = true` continues to disable gameplay outside Studio; this update does not publish the game or alter account settings.

## Controls, interface and night driving

| Action | Keyboard / controller / touch |
| --- | --- |
| Drive | WASD or arrows; left stick + RT/LT; touch GAS/BRAKE/arrows |
| Drift | Space / Left Shift; controller X; touch DRIFT |
| Enter/select/open door | E or the Roblox interaction prompt |
| Exit | F; controller Y; touch EXIT |
| Menu | M; controller Start; MENU |
| Jobs / workshop / district map | J / U / P, or Menu |
| Heat choice | B bank / C continue; controller B / A; on-screen buttons |
| Camera | V or Driving settings |
| Night/day | N or Driving settings |
| Turbo | T or Menu → Toggle turbo |
| Recover/repair at home | R or Menu; stop beside/in your car during normal driving. Finished runs offer recovery from their results. |
| Headlights on/off | H or Driving settings |
| Diagnostics / test modes | G, or Menu → Developer tools in Studio |

One interface owns menus so jobs, workshop, settings and results cannot stack. The road stays visible behind a compact objective, police alert, cash, local rotating minimap and speed/boost/temperature/damage instruments. The district map gives an overview. Settings include wider touch buttons, camera, reduced motion, reduced flashing and independent siren volume. Chase view starts enabled; reduced flashing starts enabled. Settings are local to the current play session.

Night and headlights start enabled. **H turns your headlights on/off**, with immediate feedback; **N switches town night/day**. Both also have settings buttons. Nearby native lights illuminate cars and scenery, while a road overlay follows the chassis every rendered frame, above the asphalt and painted markings. Its reach is 120 studs plus three seconds of current speed, capped at 1,400 studs: approximately **184 m at 180 km/h** and **284 m at 300 km/h** on a clear straight. Nearby obstacles shorten that reach. Native lights retain their separate 90–120-stud range. The road overlay is a visibility aid, not a photorealistic light or a guaranteed stopping distance; actual rendering and native-light delay still require Studio validation. Thirty-two reusable strips and nearby-light limits bound the effects; the streaming target is 1,536 studs to cover the longer preview.

**After a bust, wreck or timeout, use RETRY THIS JOB** on the results screen. The server recovers you and your car to your garage bay, repairs it and starts a fresh attempt with the previous contract and difficulty. Choose another job or an upgrade to return home before opening that menu. R also works from results. Normal recovery returns the avatar as well as the car, including after losing the vehicle. Occupied bays, respawning and cooldowns now show feedback even with a menu open.

The bundled sedan, pickup and sports car position the interior camera inside their own windshield opening. V switches views; **Driving settings → Interior eye height** offers normal/high/low within safe window bounds. Cockpit mode clears local window tint, hides the local avatar, uses a smaller steering wheel and removes chassis roll from the horizon. Exiting restores visibility.

Audio follows vehicle speed/load and tyre slip, adds impacts, positional pursuit sirens and short dispatch cues. Nearby voice and light counts are bounded. Actual availability, loop quality and volume balance need a listening test in the target experience.

The separate **Autobahn** test mode retains recycled highway segments, traffic collisions/explosions, a protected on-ramp, faster legacy cars and turbo spool/heat/cooldown. **Handling lab** remains available for repeatable measurements. Both are in Developer tools; the normal game starts in Hopedale. The earlier requested asset **6810376207** remains the legacy Compact appearance, not the starter sedan. See [AUTOBAHN.md](docs/AUTOBAHN.md).

## Development and verification

```bash
rokit install
bash scripts/bootstrap-checks.sh
python3 -m pip install --target .tools/gis -r scripts/gis-requirements.txt
bash scripts/project.sh map          # offline map/landmark bake
bash scripts/project.sh check        # format, lint, tests, types and both place builds
bash scripts/project.sh serve        # Rojo at 127.0.0.1:34872
```

Other commands: `build`, `map-test`, `test`, `typecheck`, `format`, `lint`, `smoke-serve`. The smoke place is [build/smoke.rbxlx](build/smoke.rbxlx). Pinned tools are in `rokit.toml`; Luau LSP is required for type checks. Scripts target this Ubuntu workstation; `LUAU_LSP_BIN` can override its extension path. Geographic downloads are explicit via `scripts/download-hopedale.sh`; ordinary generation and builds stay offline.

`src/` owns gameplay; `geo/source/` holds the OSM cache; `geo/curated/` owns authored policy/landmarks; `geo/generated/` and `assets/generated/` hold the bake; `assets/handcrafted/` preserves independent Studio work. Both rebuilt place files belong in version control with source. Tools, credentials, caches and sourcemaps are ignored.

Offline coverage includes mission/purchase rules, save leases and corrupt profiles, cargo/heat choices, steering/suspension/drift, lane controllers, route connectivity, both independent parkway connections, actual baked road clearances, garage-floor overlap, map determinism, asset safety and source-to-place consistency. The map contains **11,913 baked parts**, below the existing 12,000-part ceiling. NPC decisions run at 10 Hz. Cosmetic wheel transforms animate locally; headlights, audio and animation have distance/count budgets.

**No measured FPS or engine playtest result is claimed.** Studio's Developer tools can capture frame-time percentiles and memory to Output; anonymous session counters and run events appear as `[REDLINE PLAYTEST]`, and traffic/pursuit have MicroProfiler labels. The [acceptance checklist](docs/QUALITY-ACCEPTANCE.md) covers reconnect faults, three clients, all routes, audio, controller/touch, night and a repeatable ten-minute performance run. [STATUS.md](docs/STATUS.md) records the latest verification. The earlier [quality review](docs/GAME-QUALITY-REVIEW.md) explains the design direction; its proposed exit conditions still require player testing.

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL 1.0. Geographic source and attribution details: [HOPEDALE.md](docs/HOPEDALE.md). Getaway activity and new districts are fictional and do not describe real businesses or crimes.
