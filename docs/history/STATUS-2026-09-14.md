# Project status — 2026-09-14

**Current slice:** Milestone B+ handling lab, endless Autobahn mode and turbochargers. User confirmed the prior driving/drift/free-roam changes work. Autobahn/turbo are newly implemented and not yet Studio-verified. The complete original cops-and-getaway game is not implemented.

## Current headlight retest

User confirmed the **lit patch on the road** still trails the car after the direct-mount/per-frame-range change. Native lighting delay remains unresolved; do not report the previous fix as successful.

Added a client-only projected road-beam fallback, enabled by default, using 20 reusable Beam strips positioned from the current chassis transform each render frame. The same 36–120 stud speed/range curve applies. Downward raycasts fit the strips to nearby road; forward raycasts truncate each lamp at obstacles. Owned native SpotLights are disabled in this mode to avoid retaining the trailing patch. H or the on-screen mode button switches to native lighting for comparison. Other cars retain native lights. Crash/removal hides the projection and replacement cars are rediscovered.

This is additive road geometry, **not physical illumination**: it does not light vehicle bodies or cast shadows, and coarse centerline sampling can leave gaps near obstacles or spill at road edges. No invented texture assets are used. Full CLI checks pass, including 22 existing logic tests and both place builds; no engine/visual verification is available. Next test: confirm the “H · Headlights: road beam” label, compare modes while accelerating/turning/braking, then crash and cross a highway wrap. Inspect road-marking readability, beam alignment and graphics cost on Vinegar before accepting this workaround.

## Default car asset — 6810376207

Configured Compact (the automatic starter/replacement car) to use public model **2019 Sports Car // Rosh** by BadboyWestern. Public economy metadata verified AssetTypeId 10 and IsPublicDomain true; anonymous asset delivery returned HTTP 401, so contents could not be inspected locally. `VehicleAppearance.luau` loads once through AssetService, reconstructs only visible parts/meshes/decals/surface appearances, discards scripts/seats/controllers/joints, scales to the existing chassis envelope and welds decorative parts without collision or mass. Handling, authoritative collision, turbo, controls and headlight mounts remain the current implementation. Wheels are decorative, not animated by the imported controller.

`Config.DefaultCarAppearance` specifies the asset ID and optional yaw adjustment. The built place includes AssetService.AllowInsertFreeAssets=true (third-party asset loading only; no live DataStore API setting or publishing). Runtime failures preserve the placeholder and emit an Output warning. Car attributes RequestedAppearanceAssetId, AppearanceAssetId and AppearanceStatus expose loading state. Loading is asynchronous and does not block initial driving. Only Compact receives this appearance; Coupe and Interceptor remain unchanged.

Full CLI check passes (22 logic tests, lint, strict types, builds). Studio must still verify successful authorized asset loading, embedded mesh/texture permissions, forward orientation, wheel height, avatar seat fit, performance and crash/respawn appearance. Reopen the rebuilt place, rather than relying only on script sync, to apply the AssetService property. This is configured integration, not a claim of a visually verified imported car.

Reference: https://create.roblox.com/docs/reference/engine/classes/AssetService#LoadAssetAsync

## Implemented

- Original Rokit pins preserved; four required extensions confirmed installed; project-local formatting, Selene Roblox globals, strict Luau settings, automatic Rojo sourcemap and VS Code tasks.
- Separate smoke place with edit-visible coral cube and startup message; prototype place with generated original coastal handling course.
- One raycast-suspension chassis with Compact/Coupe/Interceptor tuning; acceleration, braking/reverse, lateral grip/drift, slope alignment and chase camera.
- Keyboard/touch input, ownership-gated entry, starter spawn, garage car selection, cooldowns, occupied-bay checks, one car/player and 12-car cap, stopped/overturned recovery, timeout/coasting, disconnect/death/abandoned cleanup.
- Server-owned vehicle physics, remote type/range/rate validation and ghost vehicle/character collision groups. No movement/reward trust is delegated to the client. Character movement and remote integration still require engine abuse tests.
- Matching official Rojo 7.7.0 plugin installed in discovered Vinegar user Plugins directory; no existing plugin overwritten. Local server started on 127.0.0.1:34872.

## Checked with command-line tools

`bash scripts/project.sh check` passes: StyLua 2.5.2 formatting, Selene 0.31.0 (zero errors/warnings/parse errors), 22 actual Luau logic tests, Luau LSP 1.69.0 strict Roblox type analysis, standalone pure-module type analysis, sourcemap generation, and Rojo 7.7.0 smoke/prototype builds. CLI type analysis logs an expected file-watch registration warning; this is not a type error.

Logic tests cover malformed/nonfinite inputs, rate limits, speed/braking, drift/reverse/smoothing, moving/remote recovery rejection and spawn distance/cooldown/occupancy decisions. They do not simulate Roblox services or physics. Optional Luau 0.738 runtime and type definitions are checksum-pinned in `scripts/bootstrap-checks.sh`. Plugin installation copy hash verified. Local Rojo status page returned HTTP 200.

## Verified in Studio

**User-observed:** entry, basic driving, revised drift and open driving area work; user said “we tested all that and it works.” The earlier hidden E prompt was fixed by parenting it to the whole car. These are user playtest reports, not an independent Codex engine test. Native Studio control remains unavailable.

## Autobahn / turbo update

The latest user request adds an Autobahn simulator direction. Implemented a selectable divided highway (three lanes each way), 512-stud procedural sections retained around all cars/characters, preloading at recycle seams, bounded coordinates via an 8,192-stud repeating span, momentum-preserving car relocation, camera translation and a server trip counter. Road scenery repeats; this is indefinite driving, not infinitely unique scenery. The existing handling course remains available. Entry requires a stopped owned/seated car. Recovery returns to an available garage bay.

All three cars have automatic turbo spool, configurable added acceleration/top speed, a visible front intercooler, boost/heat telemetry, T/HUD toggle, and server-owned thermal protection. Physics speed sanity cap increased for the new top speeds. Source tests include long-run wrapping/trip arithmetic, bounded/shared section selection, turbo activation, boost limits, lift/disable and overheat cooldown. No reward or persistence systems were added.

Builds, formatting, linting and strict type checks pass. Autobahn and turbo engine validation remains pending, especially high-speed seams, camera continuity, section replication, thermal feel, touch UI and multiple separated drivers. Read AUTOBAHN.md for exact acceptance steps and design limits. Engine streaming is explicitly off; application-managed chunks are bounded and replicated normally. Multiplayer observers may see a car reappear across a recycle seam. Solid lane traffic and crash explosions are implemented; traffic lane-change/avoidance AI is not.

## Startup / traffic correction

User reported an Autobahn title but no road or traffic. The previous header always said Autobahn even in the garage, while the highway was only generated after a separate entry-button action; traffic was previously absent. Fresh character startup now prepares the highway and places both starter car and character at a free highway launch position. The header reflects actual location. Existing garage recovery and re-entry remain available.

Added server-managed ambient traffic with 12 cars per lane maximum, six lanes, deterministic 60–90 studs/s flow, bounded recycling, section-based creation/removal and smooth client rendering from synchronized time. Traffic is deliberately non-colliding in this pass. Direction, lane spacing and long-run bounds are covered by two additional logic tests. Startup, traffic visibility and rendering remain unverified in Studio; user should reopen the rebuilt place and start a fresh Play session. The observed failure is not claimed resolved by engine testing.

## Solid traffic / protected ramp / speed update

The user requested solid traffic, an explosion on impact, a safe roadside/on-ramp start, and higher speeds. Traffic now has solid colliders in its own collision group and server-authoritative per-simulation movement. Deleted the client-side Traffic animation script so it cannot move solid traffic independently. Added swept relative-motion collision tests on world/car separating axes to detect high-speed crossings and initial overlap; suspension explicitly excludes traffic so cars cannot drive on its roofs.

A traffic hit latches one crash, stops/blackens the car, shows a visible explosion/fire/smoke/debris, rejects input/requests during recovery, and replaces the same car kind at a clear ramp bay after three seconds. Explosion pressure/joint destruction are zero; explicit lifecycle code destroys only that car. Character resets and disconnects use existing state cleanup; integration tests are pending. Replacement/startup no longer depends on a free garage bay.

Start and re-entry now use a lane at X = highway X + 105, outside traffic's ±15/33/51 lanes. A guardrail separates the acceleration lane, which connects to the main road through an actual merge opening. The launch area accommodates 12 spaced vehicles without traffic entering it. Compact top speed is 150/290 boosted, Coupe 180/320, Interceptor 170/310; acceleration, brakes and speed sanity cap were increased. CLI checks and 19 logic tests pass, including swept impacts, misses/vertical separation and crash latch behavior. Ramp merge geometry, crash timing/visuals/replacement, higher-speed handling, and multiplayer replication are NOT yet Studio-verified. See the latest AUTOBAHN.md checks. Earlier ambient/non-colliding traffic notes describe the previous implementation.

## Night / units / steering update

User requested slightly less responsive steering, realistic speed and speed-responsive headlights for night driving. Steering strength reduced 15%, smoothing response 9 → 7. Added standard conversions (1 stud = 0.28 m) for km/h + mph speed display and kilometre trips. Acceleration now fades with speed; car acceleration/braking and turbo power recalibrated. Current stock/boosted limits in km/h: Compact 190/230, Coupe 240/300, Interceptor 230/280. Earlier studs/s limits describe the previous tuning.

Night lighting is set in the place project at 00:30. Two real adaptive SpotLights per car smoothly extend from 36 to 120 studs and narrow from 80° to 42° by 180 km/h. The place enables the 120-stud light-range rollout. Added lit street/ramp lamps, emissive edge reflectors, and distance-limited local traffic beams (eight maximum). Crashed-car lights turn off. Only the owner's headlights cast local shadows; no client physics movement was reintroduced. Builds, format/lint/type checks and 22 logic tests pass. Actual darkness/beam range, lower-graphics performance, new steering/acceleration and multiplayer lighting remain unverified in Studio. See AUTOBAHN.md night acceptance steps. This remains an arcade chassis with physically converted units, not a full vehicle simulation.

## Headlight lag correction

User reported headlights lagging behind the car and clarified that only range should depend on speed. Moved light attachments from welded lens parts directly onto the chassis at fixed local transforms. Removed server speed smoothing and 10 Hz range replication. Each client now updates headlight range every rendered frame from the same car velocity used by the display; cached light references refresh separately. No code interpolates/translates headlight position. Angle stays 60°, brightness stays 3, and range stays capped at 120 studs. Enabled the place's Realistic lighting style and lighting-quality priority to improve moving-light rendering. No machine/driver settings changed.

Updated range-only logic test; all 22 tests and build/lint/type checks pass. Engine-rendered beam tracking at high speed, turns and recycle seams still needs the user's Studio retest. Do not equate the logical mount/range correction with proof that engine lighting updates show no lag on this graphics backend.

## Remaining

First run AUTOBAHN.md acceptance checks; tune the new mode from observations. Decorative wheels currently do not animate. The chassis is an arcade raycast prototype, not a finished wheel simulation; server ownership may introduce noticeable latency. Four launch bays limit simultaneous spawning; users can retry after another driver clears a bay.

C–F remain: solo delivery/time trials; actual roles; server mission state and intermittent police tracking; fair interruptible capture and impound; Hot Car event; compact finished county; cosmetics/shop; validated rewards; versioned, session-locked persistence with failure-safe loads, retries and shutdown handling. No economy or DataStore code exists, so nothing can save to the child's account. Invalid-purchase, duplicate-reward, role-switch and persistence-failure tests are pending implementation, not passed tests.

The user has accepted the driving-course test and explicitly requested the Autobahn expansion. No publishing, remote pushes, paid assets, GPU/kernel changes, account changes or broad Flatpak permission changes occurred. Git status failed because the mounted `.git` is not usable Git metadata; no Git operations were performed. Preserve it and inspect the real host repository before committing.

Next session: read this file, run `bash scripts/project.sh check`, collect the Autobahn/turbo observations in AUTOBAHN.md, and continue the user’s highway-simulator direction. The earlier cops-and-getaway C–F roadmap remains recorded but was not advanced by this request. The prototype is deliberately Studio-only and all three car configurations are free for tuning; this is not production ownership/progression.

## Larger starter car and cockpit driving

User confirmed the imported model loads but is too small. Raised the visual fit from 6 × 9.5 to an 8.5 × 16 stud envelope, preserving proportions. The chassis collision footprint, suspension mounts and headlights now follow that enlarged fit; ground clearance stays unchanged. Driver placement derives from the imported VehicleSeat transformed through the same rotation/scale/translation as the geometry, with a configurable SeatAdjustment and a fallback position when the source lacks a VehicleSeat.

Added a chassis-mounted CockpitEye and automatic interior camera for the imported starter car. The local avatar is hidden in cockpit view to avoid face/accessory obstruction and restored on exit; other players can still see the seated driver. Existing cars without a cockpit retain the chase camera. Added an original motor-driven steering wheel with 120 degrees of steering travel each way, using the actual smoothed steering input. Recognizable imported steering-wheel parts are hidden to avoid overlap. This does not animate road tyres or the avatar's hands. Glass/windshield parts are made sufficiently transparent for cockpit visibility.

Engine acceptance remains pending: avatar seat/roof fit, windshield visibility, wheel placement/direction, larger collision footprint, suspension feel, entry/exit, crash/replacement and highway wraps. Source asset geometry is still unavailable for direct inspection here; an unusual seat hierarchy or unnamed wheel may require further fitting. CLI formatting, lint, existing 22 logic checks, strict types and builds pass; these do not verify the interior visually.

## Cockpit outside the car — pivot correction

User screenshot showed the rear exterior of the car ahead of the cockpit wheel. Found a concrete transform mismatch: Model:ScaleTo scales visual parts about the model pivot, but the authored driver position was multiplied about the world origin. Subtracting the same final centering offset did not correct that mismatch. The resulting wrong seat position also moved CockpitEye and the steering wheel outside the body.

The importer now fixes an explicit bounding-centre pivot and transforms driver coordinates as `pivot + (position - pivot) * scale - centeringOffset`, matching the visual geometry. Named DriveSeat/DriverSeat takes precedence over arbitrary additional VehicleSeats. Added a standalone regression check for displaced positive/negative pivots and preservation of seat/dashboard spacing at multiple scales. Full check now passes 23 logic tests plus formatting, lint, strict types and place builds. Engine view still needs user verification; no claim that mesh visibility or exact eye height has been visually inspected. Reopen the rebuilt place and start a fresh Play session (the imported template is cached once per server).
