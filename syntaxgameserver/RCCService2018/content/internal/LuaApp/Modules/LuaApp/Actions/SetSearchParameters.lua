local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	{
		searchUuid : number
		parameters : table,
    }
]]

return Action(script.Name, function(searchUuid, parameters)
	return {
		searchUuid = searchUuid,
		parameters = parameters,
	}
end)