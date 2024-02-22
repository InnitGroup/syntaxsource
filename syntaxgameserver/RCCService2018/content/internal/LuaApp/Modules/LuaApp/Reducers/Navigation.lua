local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Rodux = require(Modules.Common.Rodux)
local Immutable = require(Modules.Common.Immutable)
local AppPage = require(Modules.LuaApp.AppPage)
local ApplyNavigateToRoute = require(Modules.LuaApp.Actions.ApplyNavigateToRoute)
local ApplyNavigateBack = require(Modules.LuaApp.Actions.ApplyNavigateBack)

local DEFAULT_PAGE = { name = AppPage.Home }
local DEFAULT_ROUTE = { DEFAULT_PAGE }

local function calcNewLockTimer(oldTime, newTime)
	-- If the new time is 0, we reset the timer
	if newTime == 0 then
		return 0
	end
	-- If the new time is nil, then we're not setting the time and the old time stays
	if newTime == nil then
		return oldTime
	end
	-- Otherwise we need to take whichever time is later (i.e. further in the future)
	return math.max(newTime, oldTime)
end

return Rodux.createReducer({
	history = { DEFAULT_ROUTE },
	lockTimer = 0,
}, {
	[ApplyNavigateToRoute.name] = function(state, action)
		return Immutable.JoinDictionaries(state, {
			history = #action.route == 1 and
				{ action.route } or
				Immutable.Append(state.history, action.route),
			lockTimer = calcNewLockTimer(state.lockTimer, action.timeout),
		})
	end,
	[ApplyNavigateBack.name] = function(state, action)
		if #state.history > 1 then
			state = Immutable.JoinDictionaries(state, {
				history = Immutable.RemoveFromList(state.history, #state.history),
				lockTimer = calcNewLockTimer(state.lockTimer, action.timeout),
			})
		end
		return state
	end,
})