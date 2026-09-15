# Autobahn + turbo prototype

## Play

Open the rebuilt `build/redline-county.rbxlx` and press Play. Your character and starter car start in a protected on-ramp beside the highway, outside all traffic lanes. Press E beside the car. After recovering to the garage, use **Autobahn** while seated and stopped to re-enter. Drive forward on the right carriageway; there are three lanes in each direction. Use the inner lane to pass. Player-owned cars still ghost through each other. Traffic cars are solid: any contact destroys your car in a visible explosion. A replacement of the same model arrives at a free on-ramp bay after three seconds; nearby players and the road are not damaged.

All three cars have a turbocharger and a visible front intercooler. Turbo starts enabled and spools up automatically above 15 studs/s under full throttle. **T** or the **Turbo** HUD button toggles it. The gauge shows delivered boost and heat. Sustained boost triggers cooling; lift off to cool sooner. Turbo supplies no extra power while braking, reversing, drifting, disabled, or cooling. This is an arcade turbo/thermal model, not a detailed engine simulation or expendable nitrous tank.

Stop and press **R**, or click **Recover**, to return to an available garage bay. Travel/recovery has an eight-second cooldown. Garage car changes still require returning and stopping. Highway entry requires sitting in your own stopped car; it is rejected while moving or already on the highway.

## Endless road implementation

The server creates 512-stud highway sections around cars and characters, loads three sections in each direction, and removes sections nobody needs. This supports driving either way and drivers who exit/park. Shared retention prevents the lead player from removing another player's road. Ambient traffic now travels in all six lanes at 60–90 studs/s, faster on the inside passing lanes. The server retains up to 72 traffic cars only where road sections are loaded and moves them before physics. Traffic bodies collide with player cars; a server-side relative-motion sweep catches fast crossings between simulation steps. The old client-side movement override has been removed to keep visual and collision positions aligned. There are no AI lane changes or avoidance maneuvers yet.

The straight divided route uses four repeating roadside variations with gantries, guardrails, lamps, hills and industrial buildings. Physical space recycles over an 8,192-stud span to avoid ever-growing physics coordinates. At a recycle point the server translates that car while preserving linear/angular velocity, prepares the destination road, and continues the trip counter. The seated camera applies the same translation. This is an indefinitely drivable repeating route, not infinitely unique geography. Other players may briefly see a car disappear/reappear at a recycle seam; seamless multiplayer continuity across that seam is not yet guaranteed.

The trip counter is server-computed longitudinal travel, stored internally in studs and displayed in kilometres; it counts either direction, rejects implausible jumps, and survives recycling. It resets on new highway entry/new car. It is session-only and awards no currency. The dashboard displays km/h and mph using the standard Roblox scale (1 stud = 0.28 m); all tuning is in `src/shared/Config.luau`. The chassis remains an arcade model, not a complete drivetrain simulation.

Chunk generation/retirement is application-managed. Engine `StreamingEnabled` is explicitly false for this bounded prototype, avoiding a second independent streaming boundary during high-speed wrap teleports. All retained chunks replicate to all clients. Before enabling engine streaming, validate atomic section loading, replication focus and teleport prefetch using the [official streaming guidance](https://create.roblox.com/docs/workspace/streaming). Road memory is bounded by the retained physical section range, not trip length. Performance at 8–12 clients is unverified.

## Studio acceptance — new mode not yet verified

1. Start a fresh Play session and confirm you see the highway and moving traffic immediately beside your starter car. Check that the starting lane is empty of traffic, then follow the merge-left sign through the guardrail opening. Wait at the start for at least a minute to confirm traffic cannot hit a parked starter car. Check that the title shows GARAGE after manual recovery and AUTOBAHN on the highway. Re-enter while stopped; confirm launch onto the right carriageway and rejected entry while moving. Try all three cars. Confirm the six HUD buttons are readable on landscape phone/tablet.
2. Hold throttle. Confirm boost rises gradually and the car exceeds its old top speed. Toggle T off/on, lift, brake and drift; power should respond. Confirm heat reaches COOLING and automatically recovers without repeated toggles bypassing it.
3. Drive for at least two minutes through multiple recycle points. Confirm no holes, fall-through, violent velocity changes or camera jump; trip must increase by travel, never by 8,192 studs at once. Turn around and cross a seam in reverse direction.
4. Inspect `Workspace.Autobahn.LoadedSections` in the server view. It should remain bounded (under 32 sections), including a longer run; an empty highway should unload after all cars/characters leave it.
5. With two local clients, leave one car parked far behind while another continues. Road must remain beneath both. Exit a car and walk while the other drives; your road remains. Verify separate trip/boost gauges and one player's T cannot affect the other car. Test arrival near another parked entry car.
6. Recover to the garage, reset your character, and disconnect. Verify cars are cleaned up and unused highway sections retire. Test desktop/touch camera and controls, and sustained turbo driving under latency emulation.

CLI tests cover turbo spool/heat/disable behavior, long-run coordinate wrapping/trip arithmetic, preload coverage on both sides of a seam, shared section retention and bounded selection. They do not execute Roblox physics, replication, UI or geometry.

Traffic checks: observe opposing flow across the median, passing-lane speeds and stable spacing. Confirm traffic disappears when all highway sections unload and `Workspace.HighwayTraffic.ActiveCars` never exceeds 72. Test rendering with two clients and across recycle seams; visual continuity is still unverified in Studio.

## Crash / speed acceptance (not yet executed in Studio)

- Current top speeds configured in km/h: Compact 190 / 230 boosted; Coupe 240 / 300; Interceptor 230 / 280. Verify acceleration, braking and steering at the new speeds, including heat cooldown.
- Tap a traffic car, rear-end one at full turbo, make a side contact, and test oncoming contact. Each should stop/destroy your car with one blast, briefly show a burning wreck, and replace it at the safe ramp after three seconds. Verify the replacement is the same car configuration. Test while parked in a traffic lane too.
- Pass closely in an adjacent lane without contact: no explosion. Check high-speed recycle points for false collision sweeps. Vertical separation and oriented separating axes are covered in logic tests but need engine validation.
- Mash car-change, Recover, Autobahn and Turbo during crash recovery; requests should not create duplicate cars or cancel the delay. Reset your character or disconnect during recovery; verify no abandoned wreck or duplicate replacement remains. Filling all garage bays must not block the on-ramp replacement.
- Verify the ramp road joins smoothly at the merge opening. Its acceleration lane is outside traffic paths and physically separated by guardrail. Protection is geographic, not temporary invulnerability once you merge.
- In two-client tests, another player's crash blast must not damage your car, avatar, road or traffic. Player-to-player ramming remains disabled. Test traffic replication and crash timing with latency emulation.

Explosions use a visible zero-pressure, zero-joint-destruction effect; only the server's explicit crash lifecycle destroys the involved player car. The detector uses a swept separating-axis test with the current car orientation and a small contact margin. Rapid rotation within a single physics step and severe replication lag still require playtesting.

## Night driving and softer steering — pending Studio validation

Steering strength is 15% lower with smoothing response reduced from 9 to 7. Acceleration now falls off progressively with speed; acceleration and braking were recalibrated instead of only relabeling the old speedometer. Brake acceleration is approximately 9–10 m/s² at the standard unit scale. Gravity/suspension remain the existing arcade chassis tuning.

The place opens at 00:30 with subdued blue ambient light, mild bloom, lit ramp/highway lamps, and luminous road-edge reflectors. Each player car has two actual SpotLights. Their mounts are fixed directly to the chassis. Clients update range every rendered frame from 36 studs at rest to a maximum of 120 studs at 180 km/h. Angle remains 60° and brightness remains 3; neither aim nor light position is smoothed or moved with speed. The place explicitly enables `Lighting.ExtendLightRangeTo120`; actual engine/light rendering must be verified on Vinegar. Headlights remain on while stopped and shut off on a crash. Traffic keeps visible headlights/tail lights; at most eight nearby traffic cars receive an active local beam. Only the local player's headlight beams cast shadows, to limit graphics cost. Local light changes never alter traffic physics.

Reopen the rebuilt place (lighting properties are included in it). Check the ramp is readable before entering your car. Compare the beam at rest, 60, 120 and 180 km/h, then brake: the beam should shorten immediately with speed, while its origin, angle and brightness remain constant. Test steering lane changes at 80 and 180 km/h and drift recovery. Compare speed/distance against server velocity and the standard conversions; reverse speed reads positive and airborne vertical velocity is excluded from the speedometer. Check tail lights/oncoming traffic, post-crash headlight shutdown, replacement lamps, two clients and lower graphics settings. Record darkness/glare, input lag and beam-range problems rather than treating CLI tests as graphics validation.

References: [Roblox standard units](https://create.roblox.com/docs/physics/units), [SpotLight](https://create.roblox.com/docs/reference/engine/classes/SpotLight), [Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting).

Headlight lag retest: reopen the built file to apply Realistic lighting and lighting-quality priority. Accelerate, weave gently, brake and cross a recycle seam; the lit patch should track the front of the car without trailing. Range changes with speed but cannot exceed 120 studs (33.6 metres at the standard scale), so high speed still reduces the time available to react within the illuminated area. This is a finite beam model, not a full stopping-distance or real-world safety simulator. Report any remaining rendered-light lag separately from range behavior.

## Road-patch lag workaround (latest build; engine test pending)

The previous native-light correction failed in the user’s test. The default now uses a frame-updated, raycast-positioned road-beam mesh for the local car, with native lights disabled for that car. **H** or the bottom-left button toggles **road beam / native**. The visible label confirms the updated client is loaded. Range still increases from 36 to 120 studs and then caps; no position smoothing is applied.

This is an additive visual approximation of light on the road, not an actual light source. It cannot illuminate traffic bodies or cast their shadows. Forward obstruction and ground sampling are coarse; inspect guardrails, road edges, slopes and nearby traffic for spill/gaps. Other vehicles use native lighting. The pool contains 20 strips and performs 24 raycasts per frame for one owned car, with no frame-by-frame instance creation. Check performance in Vinegar.

Stop Play, reopen `build/redline-county.rbxlx`, and Play again. In road-beam mode, accelerate to turbo speed, change lanes and brake. Compare with H at the same location/speed. Verify the projected patch follows turns, hides during a crash, returns with the replacement, and never stays behind at a highway wrap. Visual alignment and rendering remain unverified until this Studio test.

API reference: [Roblox Beam](https://create.roblox.com/docs/reference/engine/classes/Beam).
