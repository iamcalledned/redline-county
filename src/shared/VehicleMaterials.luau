--!strict
local Materials = {}
function Materials.slot(name: string): string?
	local n = string.lower(name)
	if n == "interior" or n:match("_door_int$") then
		return "Interior"
	end
	if n:match("_wheel$") or n:match("_wheel_trim$") then
		return "Wheels"
	end
	if
		n:find("glass", 1, true)
		or n:find("light", 1, true)
		or n:find("trim", 1, true)
		or n:find("tire", 1, true)
		or n:find("grill", 1, true)
	then
		return nil
	end
	if
		n == "body"
		or n == "trrunk"
		or n:find("fender", 1, true)
		or n:find("bumper", 1, true)
		or n:find("hood", 1, true)
		or n:find("roof", 1, true)
		or n:match("_door$")
		or n:match("_door_mirror$")
	then
		return "Paint"
	end
	return nil
end
return Materials
