local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)

local SetTopBarHeight = require(Modules.LuaApp.Actions.SetTopBarHeight)
local SetStatusBarHeight = require(Modules.LuaApp.Actions.SetStatusBarHeight)

local Constants = require(Modules.LuaApp.Constants)

local FFlagLuaAppStoreStatusBarHeight = settings():GetFFlag("LuaAppStoreStatusBarHeight")

return function(state, action)
	state = state or {
		topBarHeight = Constants.TOP_BAR_SIZE,
		statusBarHeight = 0,
	}

	if action.type == SetTopBarHeight.name then
		if state.topBarHeight ~= action.topBarHeight then
			local newProperties = {
				topBarHeight = action.topBarHeight,
			}
			state = Immutable.JoinDictionaries(state, newProperties)
		end
	elseif FFlagLuaAppStoreStatusBarHeight and
		action.type == SetStatusBarHeight.name then
		local newProperties = {
			statusBarHeight = action.statusBarHeight,
		}
		state = Immutable.JoinDictionaries(state, newProperties)
	end

	return state
end