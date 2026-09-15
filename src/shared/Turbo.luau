--!strict
local Turbo = {}
export type State = { boost: number, heat: number, overheated: boolean }
export type Tuning = {
	SpoolSeconds: number,
	DecaySeconds: number,
	HeatRate: number,
	CoolRate: number,
	RestartHeat: number,
	MinSpeed: number,
}

function Turbo.step(
	state: State,
	dt: number,
	enabled: boolean,
	throttle: number,
	speed: number,
	drift: boolean,
	tune: Tuning
)
	dt = math.clamp(dt, 0, 0.1)
	if state.overheated and state.heat <= tune.RestartHeat then
		state.overheated = false
	end
	local loaded = enabled and not state.overheated and throttle > 0.8 and speed > tune.MinSpeed and not drift
	local target = if loaded then 1 else 0
	local rate = if loaded then 1 / tune.SpoolSeconds else 1 / tune.DecaySeconds
	state.boost += math.clamp(target - state.boost, -dt * rate, dt * rate)
	state.heat =
		math.clamp(state.heat + dt * (if loaded then state.boost * tune.HeatRate else -tune.CoolRate), 0, 1)
	if state.heat >= 1 then
		state.overheated = true
	end
	-- Residual spool is displayed, but supplies no power after disabling, lifting or overheating.
	return if loaded and not state.overheated then state.boost else 0
end

return Turbo
