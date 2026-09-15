--!strict
local GarageRules = {}
function GarageRules.canSelect(
	distance: number,
	speed: number,
	occupiedByOther: boolean,
	busy: boolean,
	now: number,
	nextAllowed: number
): boolean
	return distance <= 85 and speed <= 2 and not occupiedByOther and not busy and now >= nextAllowed
end
function GarageRules.canUseDoor(
	ownerId: number?,
	userId: number,
	distance: number,
	obstructed: boolean
): boolean
	return (ownerId == nil or ownerId == userId) and distance <= 16 and not obstructed
end
function GarageRules.damage(impactKmh: number): number
	return if impactKmh < 12 then 0 elseif impactKmh < 35 then 10 elseif impactKmh < 65 then 30 else 60
end
return GarageRules
