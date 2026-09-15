# REDLINE COUNTY — local development status

Updated September 15, 2026. Workspace: `/home/ned/Documents/roblox/redline-county`.

## September 15 bug-fix follow-up

Implemented server-validated results recovery/retry, player-and-car garage recovery, modal-visible error notices and R from results. Finished-run retry eligibility is consumed by a fresh job or return-home action. Fitted bundled-car cockpit eye heights to windshield bounds, added bounded eye-height adjustment, clarified local glass, reduced the wheel and removed cockpit roll. Late accessories hide correctly and visibility restores on exit. H is now headlights ON/OFF with feedback; the brighter hybrid headlight system extends road visibility according to speed and positions the overlay above the visual road/paint. The short native range no longer limits the road preview. Removed lighting initialization's dependency on the highway traffic folder. Streaming target increased to cover the bounded road effect; device performance and visual results remain unmeasured.

## Implemented quality update

- One contextual HUD and modal owner: guided first job, controller/touch/keyboard controls, local rotating minimap, full map, result/upgrade flow and driving/accessibility settings. Roadblock markers, heat/proximity/bust countdown, cargo quality, unbanked haul and clean bonus have explicit feedback.
- Saved cash, wins, selected car, per-car physics upgrades and equipped cosmetics, discovered landmarks and lap records. Leased `UpdateAsync` records, serialized writes, retries, critical/periodic saves and guarded loads. Unpublished local files explicitly use temporary practice data. Three-player capacity is enforced; live gameplay remains disabled by `Config.DevelopmentOnly`.
- Visible paint, wheels and upholstery on the free bundled Roblox cars. Imported colored decals are removed from finishable panels; glass, tyres, lights, trim and police markings remain distinct. Display windows restore their original transparency.
- Engine/load, tyre-slip, impact, positional siren and dispatch audio with free-source metadata. Eight nearby audio-car limit, independent siren volume and reduced flashing. Asset playback/listening still needs Studio validation.
- Town loop (917 m), parkway (1,705 m), mill service loop (484 m), a technical cut-through and two independent town/parkway links. Fictional mill workshops provide cover. New roads avoid mapped building shells and baked colliders.
- Six directional civilian routes across all three districts, Light/Busy/Rush targets 6/12/18, headway/obstacle braking, short junction reservations and clear-rear recovery. Patrols return to circulation; total officers capped at eight.
- Follow/intercept/search roles based on sightings and road-projected motion. Heat three can add one announced temporary parkway roadblock with an open opposite side. Spawns screen distance, occupied space and approach visibility; actual camera/contact behavior needs engine acceptance.
- Hot Package onboarding, five-pickup Town Hall Run, damage-sensitive Fragile Cargo and escalating Heat Run with validated bank/continue choices. Contract rewards, smaller lap/drift income, discoveries and four meaningful handling upgrades.
- Local cosmetic wheel/steering animation removes repeated server wheel-transform replication. Avatar visibility is cached on entry/exit, nearby effects are budgeted, and police lamp animation no longer scans server descendants every physics step. Existing garage-floor cutout and stabilized suspension remain.
- Studio frame-time/memory capture, anonymous session/run events in Output, aggregate funnel attributes and MicroProfiler labels. No measured FPS improvement or player-engagement outcome is claimed.
- README, current implementation/acceptance documentation, geographic route preview and both place builds updated. No commit, push or publication performed as part of this update.

## Verification

`bash scripts/project.sh check` passes:

- Formatting and lint: zero errors/warnings.
- Roblox-aware and engine-independent Luau type analysis.
- **64 Luau rules/controller tests**, including profile lease takeover/stale saves, malformed/future profiles, atomic garage data, cargo/heat choices, material classification, interception, three district lane controllers frame percentile calculations, terminal retry eligibility/fresh starts, speed-based light preview, close-obstacle sampling and windshield camera bounds.
- **9 GIS/garage integration tests**, including independent parkway connections, mill geometry, actual baked collider clearances, garage camera/entry/floor checks, deterministic regeneration and preservation of authored files.
- **4 asset/build tests**, including geometry-only free assets, required gameplay modules and exact source-to-built-script agreement and road-light clearance/streaming-budget integration.
- Main and smoke Rojo builds. **77 automated tests total**.

The map has **11,913 baked parts**, under the existing 12,000-part ceiling. This count excludes runtime cars/effects and is not a device performance measurement. The generated route preview was visually inspected; it is a geographic diagram, not a Roblox screenshot.

## Runtime work still requiring Studio

The complete procedure is [QUALITY-ACCEPTANCE.md](QUALITY-ACCEPTANCE.md). Open the rebuilt place in a fresh Play session, test the first job and each route/difficulty, inspect the cameras and actual collisions, listen to all audio, test touch/controller layouts and three clients, and exercise reconnect/failed-load saves in a private published test experience. Record day/night desktop/phone performance and uncoached young-player observations.

Remaining design limits: flat provisional terrain, approximate facades, simplified traffic/police/collision physics, local session settings, no steering-hand animation, no distant impostor system, no player police/combat/jail role, no monetization and no property instances beyond three bays. Actual headlight brightness, renderer lag and cockpit sightlines still require Studio validation; the extended road overlay has limited lighting/shadow realism. Saving cannot survive arbitrary server failure with a guarantee of preserving the newest unsaved changes. The update is implemented and built locally; it has not established a finished or top-tier player experience.
