# Studio acceptance checklist — not yet executed

Open the local prototype using README instructions. Keep Output visible. No publishing or live API access is required. Record pass/fail and the first relevant Output error rather than assuming a build means success.

## First 10 minutes

1. **Startup:** Play spawns your character and one Compact near the neon garage. Both server/client startup messages appear; no red Output errors. If all four bays are blocked, clear a bay and use Compact again.
2. **Entry:** After loading the rebuilt place, approach the car from either side. The Drive / E prompt should appear without having to see inside the cabin. E/touch prompt seats you. HUD speed begins updating and chase camera takes over. F/touch EXIT returns the walking camera. Repeat after the seat cooldown. Camera must restore after character reset too. Check that an intervening world wall still prevents entry.
3. **Acceleration/braking:** Drive straight toward the far end. Compact should approach 95 studs/s, accelerate smoothly and brake predictably with S; continue holding S only after stopping to reverse. Log time to 60, braking distance from 60, and any oscillation. Slalom should be manageable at 35–60.
4. **Slide:** Circle the turquoise skidpad, reach 40–60 studs/s, hold Space or Left Shift (touch: DRIFT) while steering, then release. Slide should be controllable and grip should return without a violent snap. Check reverse steering and both turn directions.
5. **Crest/recovery:** Cross the ramp slowly, then at 60. Watch for bounce, clipping or uncontrolled flips. At rest use R; while driving fast recovery must be rejected. For an overturned stationary vehicle recovery should work after its cooldown. Recovery must not overlap an occupied garage bay.
6. **Lifecycle:** Change cars at the garage; only one owned car should remain. Away from the garage, changing cars must be rejected. Exit for two minutes: abandoned car is removed. Reset the character and disconnect/reconnect: no duplicate vehicles remain. Stop all input/change window focus: car coasts; it must not keep accelerating.
7. **Camera:** Drive past a barrier, turn tightly, reverse and recover across the course. Camera should avoid walls, stay upright and snap appropriately after teleport recovery. Steering feel and camera lag are separate observations.
8. **Touch:** Use Studio's device emulator with a landscape phone and tablet. Confirm steering + gas + drift work simultaneously, release/cancel stops input, EXIT works, and HUD/buttons remain readable. Test a physical touch device later. Touch layout and native mobile joystick interaction are not yet verified.

## Open driving regression

Drive off each former course boundary onto the surrounding land, then return to the pad. Steering and suspension should continue working. Add an anchored solid Part beside the course directly under Workspace (outside HandlingCourse), with a gently sloped approach, and drive onto it; repeat with solid Terrain. Cars and characters must not act as suspension support. Check camera obstruction against that external part too. The ocean is decorative and non-solid; use stopped recovery on land before driving into water.

## Two local clients

Use Studio's Test controls to launch a local server with two players (not a published server). Both receive independent cars. Try the other player's entry prompt: it must not seat you. Drive through another car and player: neither should be pushed. Occupy all bays and request another car: it must refuse without deleting the current car. Verify that one client's inputs cannot drive the other car and that leaving removes only that player's car. Repeat with network latency emulation to measure server-owned steering delay. This is a vehicle test, **not a pursuit test**; pursuit is not implemented yet.

In a test client's command bar, these malformed requests should cause no errors or unintended state changes:

```lua
local r = game.ReplicatedStorage.Remotes
r.DriveInput:FireServer(0/0, 0, false)
r.DriveInput:FireServer(1, {}, true)
r.VehicleRequest:FireServer("Spawn", "NotACar")
r.VehicleRequest:FireServer("Spawn", {})
for _ = 1, 100 do r.VehicleRequest:FireServer("Reset") end
```

The pure validation/rate-limit decisions are CLI tested. Their Roblox event integration and actual occupied-bay behavior still need this engine test.

## Gate for milestone C

Record entry/control success, acceleration/braking measurements, whether steering or suspension oscillates, camera behavior, touch overlap, two-client latency and any Output errors. Fix handling before expanding the map. Future tests for invalid purchases, duplicate payouts, capture interruption, role-switch/reset/disconnect abuse and DataStore failures belong to C–F; those systems do not exist yet and have not been tested.
