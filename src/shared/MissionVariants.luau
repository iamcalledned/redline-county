--!strict
-- Extra mission rules consume server-observed damage and checkpoint events only.
local Variants = {}
export type State = {
	mode: string,
	quality: number,
	damage: number,
	collected: number,
	choice: boolean,
	deadline: number,
	heat: number,
}
function Variants.new(mode: string, damage: number, heat: number): State
	return {
		mode = mode,
		quality = 100,
		damage = damage,
		collected = 0,
		choice = false,
		deadline = 0,
		heat = heat,
	}
end
function Variants.damage(s: State, damage: number)
	if damage ~= damage then
		return
	end
	local delta = math.max(0, damage - s.damage)
	s.damage = math.max(s.damage, damage)
	if s.mode == "cargo" and s.collected > 0 then
		s.quality = math.max(0, s.quality - delta * 2)
	end
end
function Variants.pickup(s: State, more: boolean, now: number)
	s.collected += 1
	if s.mode == "heat" then
		s.choice = more
		s.deadline = now + 12
	end
end
function Variants.choose(s: State, choice: string): boolean
	if not s.choice or (choice ~= "bank" and choice ~= "continue") then
		return false
	end
	s.choice = false
	if choice == "continue" then
		s.heat = math.min(3, s.heat + 1)
	end
	return true
end
function Variants.base(s: State, base: number): number
	return if s.mode == "heat" then base * math.max(1, s.collected) else base
end
function Variants.payout(s: State, amount: number): number
	return math.floor(math.max(0, amount) * (if s.mode == "cargo" then s.quality / 100 else 1))
end
return Variants
