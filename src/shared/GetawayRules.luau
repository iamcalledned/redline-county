--!strict
-- Mission progression is decided by server samples, never client-reported results.
local Rules = {}
export type State = {
	phase: string,
	checkpoint: number,
	checkpoints: number,
	remaining: number,
	escape: number,
	busted: number,
	delivery: number,
	heat: number,
}
export type Sample = {
	valid: boolean,
	atCheckpoint: boolean,
	atHome: boolean,
	seen: boolean,
	nearCop: boolean,
	slow: boolean,
	stopped: boolean,
	policeReady: boolean,
}
function Rules.new(checkpoints: number, seconds: number, heat: number): State
	return {
		phase = "pickup",
		checkpoint = 1,
		checkpoints = checkpoints,
		remaining = seconds,
		escape = 0,
		busted = 0,
		delivery = 0,
		heat = heat,
	}
end
function Rules.active(s: State): boolean
	return s.phase == "pickup" or s.phase == "run" or s.phase == "escape" or s.phase == "deliver"
end
function Rules.recoverable(s: State): boolean
	return s.phase == "busted" or s.phase == "failed" or s.phase == "complete"
end
function Rules.step(s: State, dt: number, sample: Sample): string?
	if not Rules.active(s) then
		return nil
	end
	dt = math.clamp(dt, 0, 0.25)
	s.remaining = math.max(0, s.remaining - dt)
	if not sample.valid then
		s.phase = "failed"
		return "vehicle_lost"
	end
	if s.remaining <= 0 then
		s.phase = "failed"
		return "timeout"
	end
	if s.phase == "pickup" then
		if sample.atCheckpoint then
			s.checkpoint = 2
			s.phase = if s.checkpoints >= 2 then "run" else "escape"
			return "alarm"
		end
		return nil
	end
	s.busted = if sample.nearCop and sample.slow then s.busted + dt else math.max(0, s.busted - dt * 2)
	if s.busted >= 5 then
		s.phase = "busted"
		return "busted"
	end
	if s.phase == "run" then
		if sample.atCheckpoint then
			s.checkpoint += 1
			if s.checkpoint > s.checkpoints then
				s.phase = "escape"
			end
			return "checkpoint"
		end
	elseif s.phase == "escape" then
		s.escape = if sample.seen or not sample.policeReady then 0 else s.escape + dt
		if s.escape >= 10 then
			s.phase = "deliver"
			return "escaped"
		end
	elseif s.phase == "deliver" then
		if sample.seen then
			s.phase = "escape"
			s.escape = 0
			s.delivery = 0
			return "spotted"
		end
		s.delivery = if sample.atHome and sample.stopped then s.delivery + dt else 0
		if s.delivery >= 2 then
			s.phase = "complete"
			return "reward"
		end
	end
	return nil
end
return Rules
