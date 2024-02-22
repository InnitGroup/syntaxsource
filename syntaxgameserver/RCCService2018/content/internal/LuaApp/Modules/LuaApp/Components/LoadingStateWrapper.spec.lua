return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local LoadingStateWrapper = require(Modules.LuaApp.Components.LoadingStateWrapper)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local function testLoadingStateWrapper(dataStatus)
		local mockStore = Rodux.Store.new(AppReducer, {})

		local element = mockServices({
			LoadingStateWrapper = Roact.createElement(LoadingStateWrapper, {
				dataStatus = dataStatus,
				onRetry = function()
				end,
				isPage = true,
				renderOnLoaded = function()
					return Roact.createElement("Frame", {
						Size = UDim2.new(0, 50, 0, 50),
					})
				end
			})
		}, {
			includeStoreProvider = true,
			store = mockStore,
			includeThemeProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		mockStore:destruct()
	end

	it("should create and destroy without errors when data is loaded", function()
		testLoadingStateWrapper(RetrievalStatus.Done)
	end)

	it("should create and destroy without errors when data is loading", function()
		testLoadingStateWrapper(RetrievalStatus.Fetching)
	end)

	it("should create and destroy without errors when load fails", function()
		testLoadingStateWrapper(RetrievalStatus.Failed)
	end)
end