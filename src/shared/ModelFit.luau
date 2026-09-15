--!strict
local ModelFit = {}

-- ScaleTo scales positions about the model pivot, not about the world origin.
-- Apply exactly that transform before the final chassis-centering translation.
function ModelFit.coordinate(position: number, pivot: number, scale: number, offset: number): number
	return pivot + (position - pivot) * scale - offset
end

return ModelFit
