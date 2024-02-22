local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Rodux = require(Modules.Common.Rodux)
local AEAccessoryChangeOnModel = require(Modules.LuaApp.Actions.AEActions.AEAccessoryChangeOnModel)

return Rodux.createReducer(
	{},
{
	[AEAccessoryChangeOnModel.name] = function(state, action)
		return {}
	end,
})