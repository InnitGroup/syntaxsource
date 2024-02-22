local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local SetGameDetailsFetchingStatus = require(Modules.LuaApp.Actions.SetGameDetailsFetchingStatus)

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

	if action.type == SetGameDetailsFetchingStatus.name then
		state = Immutable.JoinDictionaries(state, action.statuses)
	end

	return state
end