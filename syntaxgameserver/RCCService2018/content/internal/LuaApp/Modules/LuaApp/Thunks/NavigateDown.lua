local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local NavigateToRoute = require(Modules.LuaApp.Thunks.NavigateToRoute)
local AppPage = require(Modules.LuaApp.AppPage)

local webviews = {
	[AppPage.GameDetail] = true,
}

return function(page)
	assert(type(page) == "table",
		string.format("NavigateDown thunk expects page to be a table, was %s", type(page)))

	if webviews[page.name] then
		page = Immutable.Set(page, "webview", true)
	end

	return function(store)
		local state = store:getState()

		local currentRoute = state.Navigation.history[#state.Navigation.history]
		local newRoute = Immutable.Append(currentRoute, page)
		store:dispatch(NavigateToRoute(newRoute, webviews[page.name] and (tick() + 1) or nil))
	end
end