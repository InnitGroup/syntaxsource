return function()
	local NavigateBackFromWebview = require(script.Parent.NavigateBackFromWebview)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Rodux = require(Modules.Common.Rodux)

	local AppPage = require(Modules.LuaApp.AppPage)
	local AppReducer = require(Modules.LuaApp.AppReducer)

	it("should do nothing if current view is not a webview", function()
		local store = Rodux.Store.new(AppReducer, {
			Navigation = {
				history = {
					{ { name = AppPage.Games } },
					{ { name = AppPage.Games }, { name = AppPage.GamesList, detail = "Popular" } },
				},
				lockTimer = 0,
			},
		})
		store:dispatch(NavigateBackFromWebview())

		local state = store:getState().Navigation
		expect(#state.history).to.equal(2)
		expect(#state.history[1]).to.equal(1)
		expect(state.history[1][1].name).to.equal(AppPage.Games)
		expect(#state.history[2]).to.equal(2)
		expect(state.history[2][1].name).to.equal(AppPage.Games)
		expect(state.history[2][2].name).to.equal(AppPage.GamesList)
		expect(state.history[2][2].detail).to.equal("Popular")
	end)

	it("should remove the current route from the history", function()
		local store = Rodux.Store.new(AppReducer, {
			Navigation = {
				history = {
					{ { name = AppPage.Games } },
					{ { name = AppPage.Games }, { name = AppPage.GamesList, detail = "Popular", webview = true } },
				},
				lockTimer = 0,
			},
		})
		store:dispatch(NavigateBackFromWebview())

		local state = store:getState().Navigation
		expect(#state.history).to.equal(1)
		expect(#state.history[1]).to.equal(1)
		expect(state.history[1][1].name).to.equal(AppPage.Games)
	end)
end