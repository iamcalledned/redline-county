# REDLINE COUNTY: quality review and next playable milestone

Reviewed September 15, 2026. This document preserves the original review. Its implementation is now tracked in [IMPLEMENTATION-PROGRESS.md](IMPLEMENTATION-PROGRESS.md); runtime acceptance remains in [QUALITY-ACCEPTANCE.md](QUALITY-ACCEPTANCE.md). Evidence below describes the pre-update baseline.

## Recommendation

Build a focused New England getaway game: **take a job, choose an escape route, outsmart the police, bank the haul, and improve a car you keep**. Aim for exciting three-to-six-minute runs, readable driving, and a town players learn by landmarks.

The current project has useful underlying systems, but the player experience needs a coordinated design pass. The parkway fixes continuity; an oval with one access road still offers limited tactical choice. More scenery alone will not resolve repetitive objectives, confusing presentation, or lost progression.

Scope of review: current source, generated map layout, README/status, and the user's screenshots; competitor research used official experience listings and developer documentation. No live competitor sessions or fresh Roblox engine playtest were performed. Existing automated checks are useful regression coverage, not evidence of polished driving or a measured frame rate. No popularity ranking or retention outcome is inferred from the reference games.

## Reference games and applicable lessons

| Reference | What the official source establishes | Design lesson for Redline County |
| --- | --- | --- |
| [Jailbreak](https://www.roblox.com/games/606849621/Jailbreak) | Robberies, catching criminals, solo/group play and desirable cars; the current listing also mentions mobile UI placement/size settings. | Make the role and reward immediately understandable. Give players a visible car goal and usable controls across devices. |
| [Mad City](https://www.roblox.com/games/1224212277/Mad-City-Chapter-2) | Role choice and heists are central to its pitch. | Missions should produce different stories. Our small scope can support distinct driving jobs without implementing every role. |
| [Drive World](https://www.roblox.com/games/10704789056/Drive-World) | Driving/drifting/racing rewards, performance upgrades, customization and garage collection. | Make handling and ownership rewarding between missions. Show upgrades on the actual car and explain how they change driving. |
| [Need for Speed Heat](https://www.ea.com/able/resources/need-for-speed/need-for-speed-heat/pc/text-manual) | Day/night events, traffic and police at night, heat and risk/reward, vehicle performance upgrades. | Offer a clear decision to bank a haul or take another job with more police pressure. This is a proposed adaptation, not a reproduction of its economy. |
| [DOORS](https://www.roblox.com/games/6516141723/DOORS) | Its description encourages players to learn from failure. | My inference: make encounters teachable. Players should understand why they were caught and what they could try next; horror is outside this game's direction. |

These are reference patterns, not evidence that copying features will create a successful game. Roblox's [onboarding guidance](https://create.roblox.com/docs/production/game-design/onboarding) recommends teaching essentials, reaching the fun quickly, and exposing future goals. Its [core-loop guidance](https://create.roblox.com/docs/production/game-design/core-loops) connects moment-to-moment actions with progression. Those principles fit the gaps below.

## What is holding this build back

| Priority | Evidence in this project | Player impact and intended correction |
| --- | --- | --- |
| P0 | `Main.client.luau` retains a full-width 104 px panel when collapsed; Getaway adds a 104 px mission banner, separate buttons and minimap. Night, headlights, workshop and police have separate ScreenGuis. | Important driving information competes with menus. Consolidate layout and state; keep only the current objective, heat, route and driving instruments visible. |
| P0 | Recent user screenshots show jams/clipping; current fixes have offline coverage but no recorded engine acceptance or frame-time baseline. | Movement must be dependable. Reproduce and measure cornering, contact recovery, camera and streaming before increasing content density. |
| P0 | `Workshop.init` creates a fresh zero-cash profile; `remove` discards it. | Players cannot build a lasting collection. Add reliable saved cars, cash and upgrades before a public progression release. Never overwrite a profile with defaults after a failed load. |
| P1 | All four contracts vary route, pickup count, time and payout within the same lifecycle. | Repetition arrives quickly. Give three jobs genuinely different driving constraints. |
| P1 | `course_geometry.py` produces a 96-segment ellipse with one town connection. | Continuous driving exists, but route decisions are sparse. Add interlinked escape paths and a second parkway connection. |
| P1 | NPC color changes write `car.Body.Color`; bundled visuals hide that body and retain imported geometry/materials. The procedural paint callback targets fallback parts. | The intended civilian palette does not reach imported bodywork. Tag paintable panels and apply materials consistently; preserve glass, lamps, tyres and trim. |
| P1 | No sound/audio implementation was found under `src`. | Speed, traction loss, nearby police and successful escapes lack sound feedback. Add engine/load, tyre slip, impacts, directional sirens and restrained dispatch cues. |
| P1 | Civilian routes currently use the parkway; three contracts remain in town. | Higher population does not reliably make every job harder. Price risk around traffic actually encountered, and introduce tested town circulation routes. |
| P1 | One/two pursuing cops share the same path-following behavior. | Increased difficulty mainly changes quantity. Give officers distinct chase and interception assignments with visible counterplay. |
| P2 | Three reserved bays bound the current shared garage. | The social/server-size design needs an explicit capacity decision before inviting a larger audience. |

Code areas: `src/client/{Main,Getaway,NightMode,NightLights,PoliceAlert,Workshop}.client.luau`, `src/server/{Vehicle,BundledVehicles,VehicleStyle,TownTraffic,Getaway,Workshop,Circuit}.luau`, `src/shared/{Contracts,Progression}.luau`, and `scripts/course_geometry.py`.

## The first five minutes

Proposed timing targets, not measured results:

1. **0:00–0:20:** show one appealing starter car at the garage and one large “Start first getaway” action. The existing auto-seat/open-bay flow is useful. Keep detailed vehicle selection optional.
2. **0:20–1:00:** follow one clearly marked pickup. Teach acceleration/braking, then steering; introduce drift later. Avoid a wall of key bindings.
3. **1:00–2:30:** one readable police encounter. A siren and compact warning identify the threat. The route offers a visible turn behind a building to demonstrate breaking sight.
4. **2:30–3:30:** escape, return and bank. Show one result card: haul, clean-driving bonus, total cash and progress toward a specific upgrade.
5. **3:30–5:00:** install the first useful upgrade and offer a different job. Save the purchase. A returning player resumes their own garage instead of starting from nothing.

Test this with the intended young players without an adult explaining the controls. A small initial test can expose confusion; it cannot establish market-wide retention.

## Presentation specification

Use a coherent, believable stylized finish: detailed cars that match each other, warm garage lights, restrained vehicle colors, brick/clapboard/stone building materials, and readable night silhouettes. Keep Hopedale landmarks as the game's identity. Concentrate detail around the first mission, junction approaches and places where drivers slow down.

Driving HUD: compact objective at top left; heat/search state at top center only when relevant; cash at top right; a local rotating minimap at bottom left; speed, boost and damage at bottom right. Preserve central road visibility. A map button opens the district overview. Keyboard/touch/controller prompts appear for the current situation. Settings hold camera, day/night and accessibility choices; diagnostics and test-mode controls belong in a developer menu.

Use one UI state owner so jobs, shop, results and settings cannot stack unpredictably. Scale and reposition touch controls. Pair warning colors with words/shapes, and provide reduced flashing and independent siren volume. The supplied HUD concept illustrates proposed states and sample values, not current gameplay or finalized economics. Roblox's [UI guidance](https://create.roblox.com/docs/production/game-design/ui-ux-design) is an implementation reference.

## World and chase design

Connect three driving experiences: tight town blocks for losing sight; the broad parkway for speed and passing; a fictional mill/service-road district for technical shortcuts. Add at least two parkway-to-town connections, and give high-pressure junctions a visible alternate route. Keep existing source landmarks; author new roads explicitly as fictional where needed.

Every signature section needs a decision: short/tight versus long/fast, exposed straight versus cover, or a rough shortcut that favors a suitable car. Avoid mandatory narrow funnels for normal traffic. Add graceful junction turns, tested lane connectors, yield priority and physical vehicle recovery. High density should tighten usable gaps while remaining navigable; it should not merely create deadlocks. Randomize NPC paint and reasonable behavior within bounds, rather than adding arbitrary chaos.

Police progression: patrol notices an offense; one cruiser follows; a second seeks an interception route from last-known information; higher heat can add a clearly telegraphed roadblock with an escape gap. No invisible knowledge, spawning directly in the driver's path, or speed changes designed to cancel every successful escape. Explicit searching and cooldown make success legible. Test whether the current protected home approach makes escape too easy before choosing banking rules.

## Missions and ownership

Proposed initial mission set:

- **Hot Package:** a short pickup/escape/delivery run that teaches the game.
- **Fragile Cargo:** collisions reduce the haul; smooth driving is the skill.
- **Heat Run:** choose to bank or take the next checkpoint for a larger unbanked haul and higher heat.

Keep laps and drift challenges as optional practice/skill income. Balance their earnings per minute against contract risk; unrestricted lap cash can otherwise make missions an inferior route to upgrades. Track completion time, damage, income and retries before tuning prices.

Retain the three current free vehicles until each has verified alignment, interior camera, wheel animation, handling and sound. Give them clear roles: forgiving starter, agile drift car, stable heavier vehicle. Sell visible paint/wheel/interior choices as well as meaningful performance improvements. Present upgrades through understandable outcomes, such as stronger braking or easier drift control, alongside accurate measurements. Avoid stacking upgrades that remove all challenge. Add save reliability before expanding the catalog. Defer paid boosts, daily-streak pressure and large collections until the core game earns repeat play.

## Build order and acceptance gates

| Milestone | Bounded work | Exit condition |
| --- | --- | --- |
| 1. Driving and presentation | Unified HUD; paintable imported panels; one finished starter car; engine/tyre/siren sounds; profiling and critical traffic/camera fixes. | New players can start and finish the existing first job without coaching; no overlapping controls or unexplained vehicle failures in the test route. |
| 2. One excellent getaway | Finish the garage-to-pickup route, add two meaningful escape choices, searching/escape feedback and results/upgrade flow. | Players can explain why they escaped or were caught and independently start another run. |
| 3. Lasting ownership | Saved progression with load-failure protection, retry/session handling and purchase integrity; tune early rewards. | Cash, cars and upgrades survive reconnects; fault/disconnect tests do not reset or duplicate purchases. |
| 4. Replay depth | Second parkway link, technical district loop, two differentiated jobs, traffic-aware difficulty and interception tactics. | Every route is driven both ways with traffic and pursuit; increased risk remains escapable through skill. |

Start with milestone 1 and a single finished first-job route. Date estimates would be unreliable before measuring the engine/asset work.

For performance, record the same ten-minute route in day/night, light/rush traffic and the supported multiplayer setup. Measure frame-time percentiles, memory, physics, scripts, rendering and network traffic on named target devices. Proposed targets: p95 frame time at or below 16.7 ms on the designated desktop and 33.3 ms on the designated lower-end mobile device. These are goals, not current results or guarantees. Count collision-caused stalls and inspect visible popping/floor seams as well as FPS.

Candidate costs to profile include server-owned car physics, replicated wheel transforms, per-frame character descendant scans, repeated lighting scans and persistent NPCs. Optimize the measured bottleneck; visual wheel animation and distant NPC representation may warrant different update rates without weakening authoritative collision/reward checks. Roblox recommends measuring these with [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler) and documents [update-frequency, replication and streaming tradeoffs](https://create.roblox.com/docs/performance-optimization/improve).

Record the player funnel: join, first movement, pickup, pursuit, escape/bust, bank, purchase, second job and later return. Use aggregate playtest results to decide the next change. Success means players understand the game and choose another run; automated test totals and asset counts cannot demonstrate that.
