--!strict
local Samples = {}
function Samples.percentile(values: { number }, fraction: number): number
	if #values == 0 then
		return 0
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * fraction), 1, #sorted)]
end
return Samples
