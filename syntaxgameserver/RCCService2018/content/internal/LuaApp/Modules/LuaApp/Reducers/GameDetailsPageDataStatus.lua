local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local SetGameDetailsPageDataStatus = require(Modules.LuaApp.Actions.SetGameDetailsPageDataStatus)

local function setDefault (table, default)
	local metatable = {
		__index = function()
			return default
		end
	}
	setmetatable(table, metatable)
end

return function(state, action)
	state = state or {}
	setDefault(state, RetrievalStatus.NotStarted)

	if action.type == SetGameDetailsPageDataStatus.name then
		state = Immutable.Set(state, action.universeId, action.status)
	end

	return state
end