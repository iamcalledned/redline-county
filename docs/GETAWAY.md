# Getaway implementation

Updated September 15, 2026. See the [README](../README.md#jobs-and-rewards) for current jobs/economy and [QUALITY-ACCEPTANCE.md](QUALITY-ACCEPTANCE.md) for the complete, not-yet-run Studio test procedure.

`GetawayRules` is the pure server-sampled lifecycle: pickup → run → escape → deliver → complete; invalid vehicle, deadline or bust ends the job. Pickup radius is 22 studs with a vertical check. Police sight is at most 260 studs and requires an unobstructed solid-geometry ray. Escape needs ten unseen seconds after police respond. Bust needs five seconds within 24 studs while below 12 studs/s. Delivery needs two stopped seconds below 2 studs/s within 35 studs of home. A three-second initial grace covers automatic seating. Terminal rewards cannot repeat.

`MissionVariants` adds cargo quality and Heat Run decisions. Fragile Cargo loses twice the increase in car damage after collecting; repairs/repeated samples cannot restore or repeatedly deduct cargo. Heat Run counts actual pickups, allows one validated bank/continue decision after each intermediate pickup, and defaults to bank after twelve seconds. Continuation raises heat up to three. Banking still requires escape and delivery. Hot Package and Town Hall Run retain the ordinary ordered-pickup lifecycle.

`Getaway` directs physical police on `RoadGraph`: the first follows, later units project observed velocity ahead onto roads. Searching visits branches near last sighting. The router updates every half second and advances its cached path between replans. Corner braking and clear-rear reversing retain physical contacts. Patrols are reused before a fallback road-node spawn; fallback candidates are 180–1,100 studs away and screened for occupied space and approach visibility using heading/rays. Those proxies cannot guarantee screen invisibility for every camera position and need engine inspection.

`Roadblock` may place one temporary half-width parkway barrier at heat three, away from all players and occupied space. It announces the location, leaves the opposite side open, and expires after 55 seconds or at job cleanup. It is a tactical obstacle, not a fully simulated police deployment animation. The mill route and second parkway connection offer another escape choice.

The shared population cap is eight officers, including patrol and pursuit, across three players. Jobs can reach three responding officers, subject to that shared cap. Ending a job returns officers to traffic instead of deleting them. Home braking is a protected approach policy, not a force field; collisions/inertia still need testing.

`Interface` owns the welcome, jobs, map, workshop and result modals. A local rotating minimap and pooled road breadcrumbs use the same directed graph as police. Keyboard, touch and controller paths share server requests. `PlaytestMetrics` prints anonymous Studio session events; `Performance` captures frame-time percentiles. No live analytics backend, player police role, weapons or jail system is included.

Saved progression is handled by `ProfileStore`/`ProfileRules`; unpublished local files use explicit temporary practice data. Published Studio tests use a separate data store from live release. The local build retains its Studio-only guard. All of these runtime integrations still require the acceptance pass.
