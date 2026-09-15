--!strict
-- Pure lifecycle decisions shared by server checks and command-line tests.
local Rules = {}
export type Limits = {
	GarageRadius: number,
	StopSpeed: number,
	ResetReach: number,
	FlippedUp: number,
	FlippedSpeed: number,
}
export type Bucket = { tokens: number, updated: number }

function Rules.consume(bucket: Bucket, now: number, rate: number, burst: number): boolean
	bucket.tokens = math.min(burst, bucket.tokens + math.max(0, now - bucket.updated) * rate)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function Rules.canReset(
	speed: number,
	up: number,
	driving: boolean,
	distance: number,
	limits: Limits
): boolean
	return (driving or distance <= limits.ResetReach)
		and (speed <= limits.StopSpeed or (up < limits.FlippedUp and speed <= limits.FlippedSpeed))
end

function Rules.canSpawn(
	distance: number,
	speed: number,
	occupiedByOther: boolean,
	now: number,
	nextSpawn: number,
	limits: Limits
): boolean
	return distance <= limits.GarageRadius
		and speed <= limits.StopSpeed
		and not occupiedByOther
		and now >= nextSpawn
end

return Rules
