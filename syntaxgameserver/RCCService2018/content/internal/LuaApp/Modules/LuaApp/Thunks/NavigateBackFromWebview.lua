local Modules = game:GetService("CoreGui").RobloxGui.Modules
local ApplyNavigateBack = require(Modules.LuaApp.Actions.ApplyNavigateBack)

-- The purpose of this thunk is to ONLY navigate back if the current view is a webview.
--
-- We can't do that check in the place where this would be called, because Rodux doesn't signal updates until
-- the end of the frame, so depending on the timing of the signals recieved a Roact component may not have an
-- up to date state at the moment it needs to decide whether to navigate back.

return function()
	return function(store)
		local state = store:getState()

		local currentRoute = state.Navigation.history[#state.Navigation.history]
		local currentPage = currentRoute[#currentRoute]
		if not currentPage.webview then
			return
		end

		-- This navigation action should never be blocked by debouncing, and in fact should always clear
		-- the debounce timer, so instead of calling the NavigateBack thunk, we call the ApplyNavigateBack
		-- action with 0 for the timeout to clear the timer.
		store:dispatch(ApplyNavigateBack(0))
	end
end