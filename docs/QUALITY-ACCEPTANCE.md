# Quality update acceptance

Implemented September 15, 2026. **Engine tests below have not been run by the coding agent.** Available tools provide source/build validation, not Roblox Studio gameplay. Do not equate automated passes with finished handling, balance or a measured frame rate.

## Bust, cockpit and headlight regression pass (September 15)

- Get caught in each starter car. Click **RETRY THIS JOB**: player and car return to the reserved bay, damage clears, the correct job/difficulty starts at its first pickup, the bay opens and the player is seated. Repeat after timeout, 100% damage and avatar respawn. Double-click retry: only one new attempt starts and no extra money is credited.
- From results choose another job, choose upgrades and press R separately. Each returns home before opening the appropriate menu. Test with the bay obstructed: no overlap/teleport, and a visible explanation above the menu. Clear the obstruction and retry. On-foot recovery must bring the avatar home too. While a run is active, a forged RetryMission/ReturnHome request must not teleport or restart it.
- Drive Electric, Sport and Pickup in cockpit view. See the road above the dashboard, below the roof and through clear glass. Compare all three eye-height settings, turn, drift, reverse and switch V repeatedly. No doubled wheel, avatar obstruction or camera position trailing. On exit/respawn, the avatar and exterior glass restore. Also verify late-loading accessories and appearance replacements.
- At night press H off/on while stopped and at 50/180/300 km/h. Feedback and settings must agree. H remains on/off with menus open (except text entry) and works without HighwayTraffic loaded. N changes town daylight; Autobahn explains its night lock.
- On a clear straight, confirm the extended illumination starts at the front bumper and reaches roughly 184 m at 180 km/h / 284 m at 300 km/h. Turn sharply and cross a highway wrap: no detached patch. Check asphalt, road paint, bridge and garage. Park close to another vehicle/wall: near-road light remains and forward projection stops at the obstacle. Real lights should illuminate the nearby vehicle. Inspect at low and high graphics quality; offline tests cannot certify visibility.
- Compare frame captures before/after this fix on the same route and device. The road effect now uses 32 strips and the streaming target is 1,536 studs. Check geometry arrival, frame time and memory at speed; no performance improvement is claimed. Developers can set the local NativeHeadlights attribute for a short-range-only comparison; it is not the H control or a player setting.

## Start clean

Stop Play, reopen `build/redline-county.rbxlx`, start one client. Old Play sessions do not pick up source changes in the rebuilt file. Start with a fresh unpublished local practice session; then repeat persistence tests in a published private test experience. Do not publish to players as part of this check.

## First five minutes and interface

1. Without adult coaching, select Start first getaway. Confirm a sedan spawns, the avatar sits, the bay opens, the camera looks down the road and no roof/head blocks either camera.
2. Collect the gold package, notice the approaching officer and break sight using town buildings. Confirm SEARCHING progresses to ten seconds only after the police respond and lose sight.
3. Stop at home for two seconds. Confirm one result card, one payout, current cash and an affordable next upgrade. Fit brakes and start another job.
4. Check menus one at a time: jobs, cars, workshop, settings, map and results. No stacked full-screen panels; opening a menu clears held acceleration and hides touch controls. Confirm closing it does not accelerate until pressed again.
5. Test desktop, a phone in both orientations, a tablet and a controller. Validate safe areas, scrolling, selected buttons, RT/LT/left stick, X drift, Y exit and B/A heat choices. Try the wider-touch setting. Record actual device names and viewport sizes.
6. Toggle camera, night, headlights, reduced flashing, steady camera and siren volume; inspect first-person wheel alignment, windows and nearby warnings.

## Routes and physical traffic

Drive both directions around town, parkway and mill. Use Adin/Parkway Access in one direction and Centennial/Mill/North Parkway Access back. Try both sides of the mill circuit and its central shortcut. Check all junctions at Light, Busy and Rush (6/12/18 civilian targets across all three districts).

Brake in front of a queue, then drive away. Verify headway and restart. Obstruct a turn and watch controlled reversing only when the rear is clear. Officers returning from a job should rejoin a route, not disappear in front of you. No car should phase through a player, building or another NPC. Check bends with a pickup as well as the sedan. The simplified offline controllers do not reproduce contact, suspension or network ownership.

Inspect the garage floor at several zoom levels and camera angles in day/night. There must be no alternating terrain/garage surfaces. Check every new road transition for seams, poles, foliage and parked cars intruding into the lane.

## Pursuit and job variants

- Hot Package: one officer; a slow car held nearby for five seconds is busted. Escape requires ten unseen seconds, then stopped delivery. Recovering/abandoning cannot pay.
- Fragile Cargo: compare an untouched run to impacts after the first pickup. Quality and final payout must decrease; damage before collecting does not damage a nonexistent package. Repeatedly sampling the same damage must not repeatedly deduct quality.
- Heat Run: collect one pickup, choose bank, escape and deliver. Repeat with continue, then bank. Repeat all three pickups for heat three. Repeated/invalid decision requests cannot increase heat or haul. Waiting twelve seconds defaults to bank.
- Interception: the second officer seeks a point ahead on a road. Turn behind a building; it must not track hidden movement through the block. Search follows last-seen road branches.
- Roadblock: at heat three on the parkway, watch for the dispatch cue well ahead. Opposite lane and town exits remain counterplay. Deployment is skipped if near another player or occupied. Inspect spawn visibility in both cameras; server visibility uses heading/line-of-sight proxies, not the client's camera. Confirm cleanup after the job or its 55-second lifetime.
- A free speeding pursuit grants no contract money. Complete/failed job handling must happen once. Check laps and drifting remain less lucrative than repeated successful contracts at comparable skill.

## Cars, finishes and sound

Fit each paint, wheel and interior option on each of the three cars. Verify actual body panels change, old colored decals disappear, glass/tyres/lights remain distinct and police markings remain intact. Hide/restore a garage display by selecting/recovering/leaving; windows must retain transparency. Inspect wheel rotation/steering while driving forward, reversing and sliding. The local wheel animation must not change chassis physics.

Listen to speed/load-dependent engine layers, drift/slip, impact and positional police sirens with headphones. Check low speed, high speed, reverse and stopping. Confirm no siren during ordinary patrol and no stuck loops after despawning. Test muted and maximum siren volume, dispatch cue spacing and default reduced flashing. Audio IDs are sourced from the free Creator Store/Roblox pack, but playback permission, moderation and loop quality must be checked in the actual experience. Replace an unavailable ID through `AudioCatalog.luau`; do not hide load failures in Output.

## Saved garage and purchase faults

The unpublished `.rbxlx` path deliberately cannot save. Its settings screen must say **Local practice · saves unavailable**. This is not an error or a promise of reconnect persistence.

For persistence testing, use a private published **test** experience and enable Studio API access. Studio uses `RedlineProfiles_Studio_v1`, distinct from the live name. Keep `Config.DevelopmentOnly=true` during Studio testing. Set maximum players to three before any eventual live release; changing that flag/publishing is outside this implementation.

1. Earn cash, buy a performance upgrade and finish, change car, make a discovery, complete a lap. Wait for Garage saved, leave and rejoin. Verify all values/ownership, selected car and applied appearance/physics.
2. Double-click purchase and repeat an owned finish. Exactly one charge per tier purchase; three tiers maximum, no duplicate finish charge. Reject while moving, away from home, on a job, without enough money or using another player's car.
3. Disable API access before loading: join must fail clearly; the existing record must not be replaced with defaults. Restore access and verify the old garage.
4. Use isolated test records to exercise corrupt/future versions and an active foreign lease. Loads must fail safely. A stopped server's lease expires after 180 seconds; a subsequent owner can acquire it, and an old owner cannot commit over that new owner.
5. Test disconnect immediately after reward/purchase, normal server shutdown and throttled saves. Verify serialized retries/status and compare the record before/after. Network failure can delay/lose the newest unsaved changes; this implementation does not claim transactional delivery across arbitrary server loss.
6. Run three clients: independent cash/cars/bays, shared traffic demand, simultaneous jobs, leave/rejoin reservation release. A fourth client receives the capacity message without taking someone else's bay.

## Performance and engagement evidence

Use the same ten-minute drive: garage → town loop → mill → full parkway lap → pursuit → garage. Repeat day/night and Light/Rush, one and three players, desktop and designated lower-end phone.

In Studio **Menu → Developer tools → Performance capture**, start and stop a capture. Copy `[REDLINE PERFORMANCE]` JSON from Output: duration, frames, p50/p95/p99 frame time, total memory, traffic, night and player count. Add device, quality settings, screen resolution, driver/car and test conditions. This aggregate capture is not a replacement for MicroProfiler rendering/physics/network inspection. Inspect `Redline.Traffic` and `Redline.PoliceMissions` labels and Roblox's engine counters.

Targets from the review remain **p95 ≤16.7 ms** on the designated desktop and **≤33.3 ms** on the lower-end phone. They are targets, not measurements. Count stalls, recovery reverses, pops, major impacts, failed loads, mission completion times and earnings per minute.

`[REDLINE PLAYTEST]` reports anonymous join/movement/job/pickup/escape/bust/bank/purchase events in Studio Output; `Workspace.Funnel_*` counts them for the session. No analytics backend or player identity is sent by this instrumentation. Invite the intended young players to try the first five minutes without coaching. Record whether they independently escape, understand failure, install an upgrade and choose another run. This observation is required before describing the experience as engaging or top tier.
