local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat

local PopRoute = require(LuaChat.Actions.PopRoute)
local RemoveRoute = require(LuaChat.Actions.RemoveRoute)
local SetRoute = require(LuaChat.Actions.SetRoute)

local Immutable = require(Common.Immutable)

return function(state, action)
	state = state or {
		current = {},
		history = {}
	}

	if action.type == SetRoute.name then
		local current = state.current
		local history = state.history

		local routeData = {
			intent = action.intent,
			popToIntent = action.popToIntent,
			parameters = action.parameters
		}

		if action.popToIntent then
			local found = false
			for i = #history, 1, -1 do
				local loc = history[i]
				if loc.intent == action.popToIntent then
					history = Immutable.RemoveRangeFromList(history, i + 1, #history - i)
					current = history[#history]
					found = true
					break
				end
			end

			if not found then
				warn("Could not pop to unavailable intent: " .. action.popToIntent)
			end
		end

		if routeData.intent ~= nil then
			current = routeData
			history = Immutable.Append(history, routeData)
		end

		return {
			current = current,
			history = history
		}

	elseif action.type == PopRoute.name then
		local current
		local history = state.history

		if #history <= 1 then
			return state
		end

		history = Immutable.RemoveFromList(history, #history)
		current = history[#history]
		if not current then
			current = {}
		end

		return {
			current = current,
			history = history
		}

	elseif action.type == RemoveRoute.name then
		local intent = action.intent
		local history = state.history

		for i = #history, 1, -1 do
			local loc = history[i]
			if loc.intent == intent then
				history = Immutable.RemoveFromList(history, i)
				break
			end
		end

		local current = history[#history] or {}

		return {
			current = current,
			history = history
		}

	end

	return state
end