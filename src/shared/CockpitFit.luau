--!strict
-- Fit eye height inside the actual windshield opening, not an unscaled avatar offset.
local Fit = {}
function Fit.height(seatY: number, windowY: number?, windowHeight: number?): (number, number, number)
	if windowY and windowHeight and windowHeight > 0.35 then
		local clearance = math.min(0.2, windowHeight * 0.2)
		return windowY, windowY - windowHeight / 2 + clearance, windowY + windowHeight / 2 - clearance
	end
	local y = seatY + 1.8
	return y, y - 0.2, y + 0.2
end
function Fit.adjust(y: number, adjustment: number, minimum: number, maximum: number): number
	return math.clamp(y + adjustment, minimum, maximum)
end
return Fit
