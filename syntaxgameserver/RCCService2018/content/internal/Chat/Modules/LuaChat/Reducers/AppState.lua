local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules

local Common = Modules.Common
local LuaChat = Modules.LuaChat

local DeleteAlert = require(LuaChat.Actions.DeleteAlert)
local ShowAlert = require(LuaChat.Actions.ShowAlert)

local Immutable = require(Common.Immutable)
local OrderedMap = require(LuaChat.OrderedMap)

local function getAlertId(alert)
	return alert.id
end

local function alertSortPredicate(alert1, alert2)
	return alert1.createdAt < alert2.createdAt
end

return function(state, action)
	state = state or {}

	if action.type == ShowAlert.name then
		local alert = action.alert
		local alerts = state["alerts"] or OrderedMap.new(getAlertId, alertSortPredicate)
		alerts = OrderedMap.Insert(alerts, alert)
		state = Immutable.Set(state, "alerts", alerts)
	elseif action.type == DeleteAlert.name then
		local alert = action.alert
		local alerts = state["alerts"] or OrderedMap.new(getAlertId, alertSortPredicate)
		alerts = OrderedMap.Delete(alerts, alert.id)
		state = Immutable.Set(state, "alerts", alerts)
	end

	return state
end