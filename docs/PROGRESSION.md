# Getaway, drifting and workshop progression

The playable loop is: pick a traffic difficulty, collect loot, escape, deliver, buy a car upgrade, then attempt a more valuable run. Free exploration awards first-visit money at four landmarks. Sustained drifts offer a smaller repeatable skill reward. All money is earned in-game; the prototype has no Robux purchases.

Current source/build checks are described in [STATUS.md](STATUS.md). The complete runtime acceptance procedure is [QUALITY-ACCEPTANCE.md](QUALITY-ACCEPTANCE.md). Fragile Cargo multiplies the ordinary payout by remaining cargo quality; Heat Run uses $350 times collected pickups as its base.

## Risk and reward

| Job setting | Civilian target | Delivery multiplier |
| --- | --- | --- |
| Light | 6 | 1× |
| Busy | 12 | 1.5× |
| Rush hour | 18 | 2.2× |

Population is shared: the busiest active contract sets town density. Each player's payout uses the difficulty selected when their own job began. Returned police and nearby excess traffic leave gradually outside the player proximity guard, so live counts can temporarily exceed the target. Actual civilian count and target are exposed as Workspace attributes for diagnostics.

Payout = floor((contract base + 2 × whole seconds remaining) × difficulty multiplier × clean bonus). The clean bonus is 1.2 if damage is zero, otherwise 1. Hot Package at 60 seconds remaining pays $420 Light, $630 Busy or $924 Rush, before a clean bonus.

Discover Ballou Park, Bancroft Library, Little Red Shop and the Parklands entrance for **$150 each**, once per saved profile (per session in local practice). Discovery triggers near the road frontage. These are sightseeing rewards, not claims of criminal activity at real landmarks.

## Drifting

Hold **Space / Left Shift** (or touch DRIFT), steer and keep forward speed. Handbrake input reduces lateral grip and increases town yaw above 18 studs/s. Releasing it restores normal grip. Skid trails depend on actual lateral motion, and the HUD displays the live chain.

Scoring requires forward speed above 25 studs/s, 10–65° slip, three grounded wheels and at least 1.5 seconds sliding. After 1.25 seconds without a qualifying slide, bank floor(points/10) dollars, capped at $100 per chain. Damage loses the unbanked chain. An unoccupied, airborne, or non-town car cannot earn this reward. The server measures motion; the client cannot submit a score or payout. Power and tyre upgrades alter the feel of the same manoeuvre.

## Workshop [U]

Park the selected car at home after the job. Upgrades belong to each vehicle type independently and reapply when that type respawns. The server checks balance, ownership, proximity, stopped speed, occupancy, active job and level before charging.

| Upgrade | Level 1 / 2 / 3 price | Effect per level, additive from stock |
| --- | --- | --- |
| Powertrain | $500 / $1,100 / $2,200 | +12% acceleration, +5% unboosted top-speed setting |
| Brakes | $350 / $800 / $1,600 | +18% braking force |
| Performance tyres | $450 / $950 / $1,900 | +12% normal grip, +8% sliding grip |
| Suspension | $400 / $900 / $1,800 | +8% spring rate, +16% damping |

These change the forces used by the chassis. They are configuration changes, not certified performance measurements. Level 3 power means 1.36× stock acceleration and 1.15× its speed limit. Existing turbo heat/spool rules remain.

Cash, wins, discoveries, per-car upgrades/cosmetics and lap records now use the saved garage. Unpublished local files show an explicit practice/no-save status. Published Studio tests require API access and use a separate test data store. Drift chains/best-session drift are temporary. See [save fault acceptance](QUALITY-ACCEPTANCE.md#saved-garage-and-purchase-faults). Paint, wheel and interior finishes are available alongside performance upgrades.

## Traffic and police

Six civilians and two roaming officers populate the town, 1.7 km parkway and mill loops without a mission. Vehicles use separate right-hand lane paths, headway braking and curved occupied-path checks. Short arrival-order reservations coordinate junction entry, with physical occupied-path checks as a second guard. Static obstacles and stationary crossed/head-on cars trigger a short reverse attempt only when the rear path is clear. Stuck vehicles can retire after 60 seconds only when far from every player. This is gameplay traffic, not a simulation of surveyed local traffic controls. Cars collide physically; town contacts use graduated damage, while Autobahn retains its explosion rule.

Nearby ambient patrols can be assigned to a pursuit; clear road-node spawns fill shortages. Officers return to roaming after a terminal job instead of being destroyed in view. Ambient vehicles are persistent streaming models, with retirement restricted to cars far from player characters. Suspension queries ignore all vehicles/characters but physical bodies still collide. Spring forces act at the centre of mass, with an implicit damping calculation, leaving attitude control to the stability servo.

## Studio checks still needed

1. Open the rebuilt place, start a fresh Play session and confirm traffic count rises to 6. Drive east from home onto Parkway Access; see vehicles in both directions and two patrolling cruisers.
2. Start Rush Hour and confirm the civilian target changes to 18. Choose Heat Run. Observe following gaps, access-junction merging and collisions; inspect Output for runtime errors. Record any stuck intersection and low-FPS bounce.
3. Complete or abandon a job while a cruiser is visible. It should resume patrol, with no immediate pop out. Check return from a side street and home protection.
4. Drive Sport, Pickup and Electric; check imported interiors, animated wheels, tyre contact, steering and suspension at both normal and low frame rates. V switches view. Mesh/texture rendering still needs network access to Roblox's content CDN.
5. Sustain a drift, straighten and check a single cash award. Hit an obstacle during a chain; no unbanked reward should survive. Compare the same corner before/after tyre upgrades.
6. Discover a landmark twice (only one discovery payment), return home, buy an upgrade, and measure acceleration/braking using G. Switch away and back: that vehicle keeps its upgrade; verify reconnects in a published test experience. Test insufficient cash and purchases while moving/on a job.
7. Check three clients with different job settings and per-car purchases. Profile Rush Hour on target devices; no FPS result is claimed yet.

## Parkway laps, free pursuits and night

The fictional Redline Parkway is **1,705.48 m**, 12 m wide, and loops in both directions. Follow Adin east from home or start **Heat Run** ($350 per pickup, optional continuation, heat one to three, seven minutes). Traffic difficulty applies to this mission as well as the original town contracts.

A lap starts wherever you enter the circuit. Travel a full loop continuously in one direction to earn `100 + max(0, 150 - floor(lapSeconds / 2))` dollars. Progress is based on server-observed movement with seam wrapping and a displacement limit. Leaving the course, losing wheel contact, exiting, disabling the car or teleporting resets the attempt. Backtracking removes progress. Lap count and best time use the saved profile; completing a lap during a mission can earn both kinds of reward.

Speeding above 80 km/h within 180 studs of a roaming officer with clear sight starts a free pursuit when no contract is active. It uses the normal ten-second escape and five-second slow/proximity bust rules, with a three-minute limit. It grants no delivery payout. New automatic pursuits have a 45-second minimum interval. The police HUD covers 350 studs, prioritizes pursuing officers, shows direction/distance and closing motion, and can pulse red inside 90 studs when reduced flashing is disabled.

Night is the default. **N** or Driving settings changes town/circuit lighting; Autobahn remains night. Adaptive headlights work in both areas. Up to six nearby map lamps and five nearby cars receive active light sources, plus the player's car; Autobahn traffic has a separate six-light limit. Garage interior lamps remain on. **H** compares road-beam and native-light rendering.

Fresh Studio acceptance: complete the course in both directions, wait behind traffic and see it resume, drive Heat Run at Rush Hour, trigger/escape a free pursuit, verify alert directions, toggle N while moving, and inspect the garage floor from low camera angles. No engine frame-time improvement is claimed until measured.
