--[[createModdableFunction can be used to build a Moddable function in a chain style
	for example:
		validModifiers = {
			protected = Enums.Modifier.Protect,
			skipped = Enums.Modifier.Skip,
		}
		describe = createModdableFunction(validModifiers, callback)
		describe.protected.skipped("description", function() end)
		step.skipped("description", function() end)
]]

local function createModdableFunction(validModifiers, method, appliedModifiers)
	if appliedModifiers == nil then
		appliedModifiers = {}
	end

	return setmetatable({}, {
		__call = function(_, ...)
			return method(appliedModifiers, ...)
		end,
		__index = function(_, key)
			if not validModifiers[key] then
				error(("%q is not a valid modifier"):format(tostring(key)), 2)
			end

			local newAppliedModifiers = {}

			for key, value in pairs(appliedModifiers) do
				newAppliedModifiers[key] = value
			end

			newAppliedModifiers[validModifiers[key]] = true

			return createModdableFunction(validModifiers, method, newAppliedModifiers)
		end,
	})
end

return createModdableFunction