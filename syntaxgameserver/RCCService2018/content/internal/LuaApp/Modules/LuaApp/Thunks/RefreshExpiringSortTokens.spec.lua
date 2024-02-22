return function()
	local RefreshExpiringSortTokens = require(script.Parent.RefreshExpiringSortTokens)
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local MockRequest = require(Modules.LuaApp.TestHelpers.MockRequest)
	local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	it("should not fetch anything with empty sortGroups arg", function()
		local store = Rodux.Store.new(AppReducer, {
			RequestsStatus = {
				GameSortTokenFetchingStatus = { }
			}
		})

		local networking = MockRequest.simpleSuccessRequest("{}")
		store:dispatch(RefreshExpiringSortTokens(networking, {}))

		local state = store:getState()
		expect(TableUtilities.FieldCount(state.RequestsStatus.GameSortTokenFetchingStatus)).to.equal(0)
	end)

	it("should not fetch anything with non-expired token", function()
		local store = Rodux.Store.new(AppReducer, {
			RequestsStatus = {
				GameSortTokenFetchingStatus = {
					HomeGames = RetrievalStatus.NotStarted
				}
			},
			NextTokenRefreshTime = {
				HomeGames = tick() + 10000
			}
		})

		local networking = MockRequest.simpleSuccessRequest("{}")
		store:dispatch(RefreshExpiringSortTokens(networking, { "HomeGames" }))

		local state = store:getState()
		expect(state.RequestsStatus.GameSortTokenFetchingStatus["HomeGames"]).to.equal(RetrievalStatus.NotStarted)
	end)

	it("should not start a duplicate fetch", function()
		local store = Rodux.Store.new(AppReducer, {
			RequestsStatus = {
				GameSortTokenFetchingStatus = {
					HomeGames = RetrievalStatus.Fetching
				}
			},
			NextTokenRefreshTime = {
				HomeGames = tick() - 10000
			}
		})

		local networking = MockRequest.simpleFailRequest("error")
		store:dispatch(RefreshExpiringSortTokens(networking, { "HomeGames" }))

		-- The simpleFailRequest response would set a failure status, so it's ok to just
		-- check that it is still in fetching state.
		local state = store:getState()
		expect(state.RequestsStatus.GameSortTokenFetchingStatus["HomeGames"]).to.equal(RetrievalStatus.Fetching)
	end)

	it("should start a fetch for expired token", function()
		local store = Rodux.Store.new(AppReducer, {
			RequestsStatus = {
				GameSortTokenFetchingStatus = {
					HomeGames = RetrievalStatus.NotStarted
				}
			},
			NextTokenRefreshTime = {
				HomeGames = tick() - 10000
			},
		})

		local networking = MockRequest.simpleOngoingRequest()
		store:dispatch(RefreshExpiringSortTokens(networking, { "HomeGames" }))

		local state = store:getState()
		expect(state.RequestsStatus.GameSortTokenFetchingStatus["HomeGames"]).to.equal(RetrievalStatus.Fetching)
	end)

	it("should start a fetch for missing token", function()
		local store = Rodux.Store.new(AppReducer, {
			RequestsStatus = {
				GameSortTokenFetchingStatus = {
					HomeGames = RetrievalStatus.NotStarted
				}
			},
			NextTokenRefreshTime = { },
		})

		local networking = MockRequest.simpleOngoingRequest()
		store:dispatch(RefreshExpiringSortTokens(networking, { "HomeGames" }))

		local state = store:getState()
		expect(state.RequestsStatus.GameSortTokenFetchingStatus["HomeGames"]).to.equal(RetrievalStatus.Fetching)
	end)
end
