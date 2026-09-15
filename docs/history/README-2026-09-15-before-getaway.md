# REDLINE COUNTY

A Roblox driving prototype now centered on **Hopedale, Massachusetts**: walk through a fictional home garage, choose a car, open the door, drive past historic Hopedale Town Hall, cruise a connected neighborhood loop and return home. The existing nighttime Autobahn and handling lab remain separate development modes.

**Current delivery:** an editor-visible first Hopedale slice, implemented and command-line checked, with Studio driving acceptance still pending. This is a Studio-only prototype, not a finished town reconstruction or pursuit game.

## Game interpretation and direction

REDLINE COUNTY is being built as a **driving sandbox rooted in a familiar place**, with a garage that gives every outing a beginning and an end. The central experience is:

> “I walk through my garage, choose a car, open the door, pull onto the street, drive past Hopedale Town Hall, cruise familiar roads, and return home.”

The garage is part of the experience: you arrive on foot, see the collection, select a vehicle, and prepare to leave. The current implementation represents that home as one shared fictional workshop with three reserved bays. It establishes the home-base routine; individual persistent homes and saved collections remain future work.

The intended play loop is to choose a car, drive out onto Adin Street, explore the neighborhood, complete the Town Hall loop, and return to park or change vehicles. Players choose their own pace and destination within the current map boundary. There are no required races, mission objectives, rewards, or progression systems in this build.

The driving should make ordinary trips enjoyable: manageable parking and low-speed turns, predictable braking, less steering authority at speed, and a useful view from either the cockpit or chase camera. Pickup, Electric, and Sport are provisional collection choices with different configured dimensions and handling. Their appearance and measured driving feel still need refinement. Turbo is an optional performance feature on supported cars.

The three environments have distinct purposes:

| Environment | Intended experience | Current implementation |
| --- | --- | --- |
| **Hopedale home and neighborhood** | Everyday driving, exploration, and returning to your garage | Daylight, a bounded geographic street loop, a custom Town Hall exterior, and garage/vehicle systems awaiting full Studio acceptance. Local traffic is not enabled yet. |
| **Autobahn** | Fast nighttime driving, traffic avoidance, turbo, and limited headlight visibility | A separate highway mode with recycled sections, a protected on-ramp, and traffic collisions that destroy the car. |
| **Handling lab** | Learn and tune how each car accelerates, brakes, and turns | An isolated test area with optional driving diagnostics. |

The longer-term direction is a multiplayer pursuit game built on these streets and vehicle systems. The immediate priority is to make the complete garage-to-town-and-back trip dependable, then refine the neighborhood and add limited local traffic. Police roles, pursuit AI, arrests, missions, and an economy are still unimplemented.

**Current playtest reality:** the first Hopedale test exposed an obstructed starting camera and difficulty entering a car. The latest source and rebuilt place include repairs for spawn clearance, camera initialization, selection prompts, and entry obstruction checks. Automated checks pass; the repaired startup and complete driving loop still need confirmation in Studio.

![Hopedale route and boundary](docs/previews/hopedale-route.png)

## Open and play

On the configured Ubuntu/Vinegar workstation:

```bash
flatpak run org.vinegarhq.Vinegar
```

In Studio, choose **File → Open from File** and open [build/redline-county.rbxlx](build/redline-county.rbxlx):

```text
/home/ned/Documents/roblox/redline-county/build/redline-county.rbxlx
```

Wine-style path if needed:

```text
Z:\home\ned\Documents\roblox\redline-county\build\redline-county.rbxlx
```

The local map and garage are visible **before Play**. Press Play to spawn on foot inside the garage. Start in a clear side aisle with a close walking camera. Press **E** at the green selector beside a display, or click **Pickup / Electric / Sport** in the menu. The selected drivable car replaces the display in **your assigned bay** (shown in the status message). Walk to that bay's wall switch and press **E** to open its door, then return beside your car and press **E** at **Drive**. Drive along the driveway onto Adin Street. Head west on Adin, turn right onto Hopedale Street, and pass Town Hall. Turn right at Union, right at Dutcher, then right at Adin to complete the loop; follow Adin east to return home.

After an update, stop Play, reopen the rebuilt file and start a fresh Play session. [build/smoke.rbxlx](build/smoke.rbxlx) remains the independent setup test with an edit-visible coral cube.

## Controls

| Action | Control |
| --- | --- |
| Select a displayed vehicle, enter a car, operate a garage door | **E** at the relevant prompt; touch/tap supported |
| Accelerate | **W / Up**; touch **GAS** |
| Brake, then reverse | **S / Down**; touch **BRAKE** |
| Steer | **A/D / Left/Right**; touch arrows |
| Drift | **Space / Left Shift** while turning at speed; touch **DRIFT** |
| Exit | **F**; touch **EXIT** |
| Switch cockpit/chase camera | **V** or **Camera** |
| Show/reset driving diagnostics | **G** or **Diagnostics** |
| Expand vehicle and test-mode menu | **M** or **Menu** |
| Toggle available turbo | **T** or **Turbo** |
| Exceptional recovery/repair to home | **R** or **Recover**, subject to stopped/overturned, reach and occupancy checks |
| Enter the preserved test modes | **Menu → Autobahn / HandlingLab**, while seated and stopped |
| Compare night headlight rendering | **H** or **Headlights** mode button |

Chase view is the initial camera. The large selection menu collapses while driving; Camera, Diagnostics and Menu controls remain available. Normal garage-to-town-and-back driving needs no teleport. Recovery and test-mode transfers are explicit exceptions.

## Hopedale neighborhood

- **917.39 m connected loop** on Hopedale Street, Union Street, Dutcher Street and Adin Street, within a **680 × 510 m** extent. Street topology/names and 129 building footprints come from a cached OpenStreetMap extract.
- **Historic Town Hall at 78 Hopedale Street** is the custom landmark. The current municipal offices at 54 are distinguished in the reference notes. Its mapped footprint, street-facing relationship and inspected front photo inform the stone/sandstone exterior, central gable, paired chimneys, window rhythm and arched entrance. Exact height, rear details and interiors are not verified replicas.
- Road surfaces are unioned and triangulated for clean visual junctions over a common flat collision datum. Sidewalks, tagged crosswalks, street names, explicit boundary signs, generic New England building shells, sparse street furniture and mapped greenery establish the first blockout.
- Clear late-afternoon lighting prioritizes visibility. **Elevation is provisional and flat**; actual hills, curb behavior, exact lane widths, most facades and untagged junction controls still require refinement.
- A separate directed lane graph records right-hand navigation, one-way tags, junction connections and stop/yield policy. **Local traffic stays off until the player loop and intersections pass Studio acceptance.** No Autobahn traffic controller was copied onto town streets.

[Map, coordinate system, authoring workflow and acceptance guide](docs/HOPEDALE.md) · [Geographic attribution and reference records](geo/ATTRIBUTION.md)

## Fictional garage and collection

The three-bay workshop is an **added fictional property**, not a claim about a real home or parcel. Its reserved site and driveway avoid mapped building footprints. It contains overhead doors, a turning apron, interior lamps, workbench/tool storage, a lounge/planning corner and three inexpensive anchored vehicle displays.

The collection offers provisional **Pickup**, **Electric sedan**, and **Sport coupe** appearances—not branded replicas or exact trims. Displays are separate from active driving vehicles. The server reserves a home bay and keeps **one active car per player**; selection, door ownership/reach, spawn occupancy, cooldowns and duplicate requests are checked. Doors test clearance before closing and before becoming solid again.

This first shared property supports **three reserved home bays**. Additional players wait for a free reservation; separate private property instances are future work. Vehicle access remains free development access, with no shop or persistence.

## Driving and cameras

The existing raycast-suspension chassis, braking/reverse, drift, remote validation, abandonment cleanup and recovery remain. Collection vehicles have distinct dimensions, density, acceleration/braking and wheelbase. Steering follows wheelbase, reverses when backing up, and loses authority at speed. Visible wheels rotate and the front wheels steer. The cockpit steering wheel also animates; avatar hands do not.

| Collection vehicle | Approx. width × length | Wheelbase | Configured speed limit | Turbo |
| --- | --- | --- | --- | --- |
| Pickup | 2.10 × 5.60 m | 3.42 m | 150 km/h | None |
| Electric | 1.96 × 4.76 m | 2.91 m | 180 km/h | None |
| Sport | 1.96 × 4.48 m | 2.74 m | 210 km/h | Optional +35 km/h |

These are configuration values, not measured performance results. Town driving starts with turbo off. Available turbo still uses spool, boost, heat and cooldown behavior.

**V** toggles cockpit/chase view. The local avatar is hidden only in cockpit view to avoid head/accessory obstruction and restored in chase/on exit. The imported legacy cockpit's earlier scale/pivot correction is preserved; interior fit remains an engine test.

The HUD displays km/h, mph, boost/heat and mode/route information. **G** starts a diagnostic session showing sampled 0–50 time, last stop distance and starting speed, steering angle, suspension ground contacts and damage. Use the isolated HandlingLab for repeatable measurements. The project consistently uses **0.28 m per stud**.

Town impacts accumulate damage rather than universally exploding the car. Parking taps add no damage; harder repeated impacts can disable propulsion until recovery/repair. This approximate collision model needs Studio testing. Player-owned cars remain mutually non-colliding while eventual pursuit collisions are designed separately.

## Preserved Autobahn and legacy cars

**Menu → Autobahn** transfers a stopped, occupied car to the protected highway on-ramp. The highway still has three lanes each way, section loading/recycling across an 8,192-stud route, different lane speeds and up to 72 traffic cars. Scenery repeats. Solid highway traffic impacts retain their explosion and three-second replacement behavior. **R** now returns to the home garage.

Night mode retains street/ramp lights, reflectors and nearby traffic headlights. Headlight range increases from **36 to 120 studs**, reaching its cap at 180 km/h. **Road beam** remains the default frame-updated road-light approximation; **H** switches to native SpotLights for comparison. The workaround does not illuminate vehicle bodies or cast their shadows, and native-light lag remains a known test issue. Adaptive car headlights are currently active in Autobahn mode; town uses daylight.

Legacy **Compact**, **Coupe** and **Interceptor** remain in the expanded menu at home. Their configured stock/boosted limits remain 190/230, 240/300 and 230/280 km/h. Compact uses [2019 Sports Car // Rosh](https://create.roblox.com/store/asset/6810376207), asset **6810376207**, by **BadboyWestern**. The importer copies visual content while excluding imported scripts/controllers and keeps the project chassis. Runtime asset availability is required; failure keeps the placeholder and reports to Studio Output. Its internal mesh tyres are not rigged for rotation; the new collection placeholders have animated wheels.

[Earlier Autobahn details and checks](docs/AUTOBAHN.md)

## Development and reproducible maps

Pinned tools: **Rojo 7.7.0**, **StyLua 2.5.2**, **Selene 0.31.0** in [rokit.toml](rokit.toml). Install the recommended VS Code extensions, including Luau LSP. For a fresh development checkout with Rokit installed:

```bash
rokit install
bash scripts/bootstrap-checks.sh
python3 -m pip install --target .tools/gis -r scripts/gis-requirements.txt
```

The scripts target the configured Ubuntu workstation. Elsewhere, put Rokit on `PATH` and set `LUAU_LSP_BIN` to the Luau language-server executable if necessary. The bootstrap downloads checksum-verified Luau/type definitions into `.tools/`; GIS dependencies stay project-local too.

```bash
bash scripts/project.sh map          # offline bake from the included geographic cache
bash scripts/project.sh map-test     # projection, connectivity, clearance, repeatability checks
bash scripts/project.sh check        # formatting, lint, logic/GIS tests, types and both builds
bash scripts/project.sh build        # pack existing baked map and source into both places
bash scripts/project.sh serve        # Rojo on 127.0.0.1:34872
bash scripts/project.sh smoke-serve
bash scripts/project.sh format
bash scripts/project.sh lint
bash scripts/project.sh test
bash scripts/project.sh typecheck
```

Geographic downloads are explicit: `bash scripts/download-hopedale.sh`. Ordinary generation/builds do not access the network. [HOPEDALE.md](docs/HOPEDALE.md) documents source, projected coordinates, regeneration and correction rules.

| Location | Responsibility |
| --- | --- |
| `geo/source/` | Cached original OSM extract |
| `geo/curated/` | Authored boundary/route policy and landmark/garage recipe |
| `geo/generated/` | Projected database and separate lane graph |
| `assets/generated/` | Baked editor-visible map/models |
| `assets/handcrafted/` | Independent Studio-authored models preserved during regeneration |
| `src/server/` | Garage validation/doors, vehicles, traffic, impacts and lifecycle |
| `src/client/` | Controls, HUD, cameras and lighting |
| `src/shared/` | Configuration, metrics, driving/garage/geographic math and generated route |
| `tests/` | Standalone logic and offline GIS integration checks |

[Config.luau](src/shared/Config.luau) exposes handling, wheelbase/dimensions, turbo, lights, recovery and legacy asset fitting. Both `.rbxlx` places are tracked: rebuild and include them with source changes. Generated map assets/data are also included so Studio users need not install GIS tooling just to open the place. Tools, credentials, temporary files and sourcemap remain ignored.

## Verification and remaining work

Latest checks: **28 Luau logic tests, five GIS/garage geometry integration tests, formatting, lint, strict type analysis and both Rojo builds**. GIS tests verify the route, scale, driveway clearance, garage arrival/camera/selector clearance, deterministic generation and authored-file preservation. An offline geometry preview was inspected, but it does not reproduce Studio rendering.

**New Hopedale behavior is not yet Studio-verified.** Follow [the acceptance steps](docs/HOPEDALE.md#studio-acceptance--not-yet-run) for garage doors, cockpit/tyres, the complete loop, road seams, impacts, handling measurements, streaming, frame rate and multiple players. About 4,300 baked parts and streaming radii are implementation budgets, not measured performance guarantees. Elevation, facade fidelity, individual property drives, stone walls and local traffic remain unfinished.

The later pursuit game is still future work: no playable police/outlaw roles, arrests, missions, Hot Car event, economy, persistence, weapons or purchases. The Interceptor is only a car configuration. No live DataStore API access is required.

[Current status](docs/STATUS.md) · [Geographic sources/licenses](geo/ATTRIBUTION.md) · [Ubuntu/Vinegar setup](docs/SETUP.md) · [Original milestone plan](docs/PLAN.md)
