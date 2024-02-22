return function()
	local Rodux = require(script.Parent.Rodux)

	local CorePackages = game:GetService("CorePackages")
	local CorePackagesRodux = require(CorePackages.Rodux)

	local Logging = require(CorePackages.Logging)

	local function NoopReducer(state, action)
		return state
	end

	describe("Rodux compatibility shim", function()
		it("should process thunks by default", function()
			local thunkCallCount = 0
			local thunk = function(store)
				thunkCallCount = thunkCallCount + 1
			end

			local store = Rodux.Store.new(NoopReducer)

			expect(function() store:dispatch(thunk) end).never.to.throw()
			expect(thunkCallCount).to.equal(1)
		end)

		it("should have PascalCase versions of Store API that warn", function()
			local store = Rodux.Store.new(NoopReducer)

			expect(typeof(store.GetState)).to.equal("function")
			expect(typeof(store.Dispatch)).to.equal("function")
			expect(typeof(store.Flush)).to.equal("function")

			local logs = Logging.capture(function()
				store:GetState()
				store:Dispatch({ type = "Foo" })
				store:Flush()
			end)
			print(unpack(logs.warnings))
			expect(string.match(
				logs.warnings[1],
				"^Store:GetState%(%) has been deprecated, use getState%(%)"
			)).to.be.ok()
			expect(string.match(
				logs.warnings[2],
				"^Store:Dispatch%(%) has been deprecated, use dispatch%(%)"
			)).to.be.ok()
			expect(string.match(
				logs.warnings[3],
				"^Store:Flush%(%) has been deprecated, use flush%(%)"
			)).to.be.ok()
		end)

		it("should have PascalCase versions of Signal API for 'changed' signal", function()
			local store = Rodux.Store.new(NoopReducer)

			expect(store.Changed).to.be.ok()
			expect(typeof(store.Changed.Connect)).to.equal("function")

			local connection
			local logs = Logging.capture(function()
				connection = store.Changed:Connect(function()
					-- do nothing
				end)
			end)

			expect(string.match(
				logs.warnings[1],
				"^Signal:Connect%(%) has been deprecated, use connect%(%)"
			)).to.be.ok()

			logs = Logging.capture(function()
				connection:Disconnect()
			end)

			expect(string.match(
				logs.warnings[1],
				"^Connection:Disconnect%(%) has been deprecated, use disconnect%(%)"
			)).to.be.ok()
		end)

		it("should match Rodux's API", function()
			for name, _ in pairs(CorePackagesRodux) do
				expect(Rodux[name]).to.be.ok()
			end

			local corePackagesStore = CorePackagesRodux.Store.new(NoopReducer)
			local shimStore = Rodux.Store.new(NoopReducer)

			for name, _ in pairs(corePackagesStore) do
				expect(shimStore[name]).to.be.ok()
			end
		end)
	end)

	describe("CorePackages Rodux version", function()
		it("should not be overwritten by the compatibility shim", function()
			expect(Rodux).never.to.equal(CorePackagesRodux)
		end)

		it("should not have its Store API overwritten by the compatibility shim", function()
			expect(Rodux.Store).never.to.equal(CorePackagesRodux.Store)
		end)

		it("should not process thunks by default", function()
			local thunkCallCount = 0
			local thunk = function(store)
				thunkCallCount = thunkCallCount + 1
			end

			local store = CorePackagesRodux.Store.new(NoopReducer)

			expect(function() store:dispatch(thunk) end).to.throw()
			expect(thunkCallCount).to.equal(0)
		end)

		it("should accept and use middleware", function()
			local middlewareInitialized = false
			local lastActionProcessed = nil
			local middleware = function(nextDispatch, store)
				middlewareInitialized = true
				return function(action)
					lastActionProcessed = action.type
				end
			end

			local store = CorePackagesRodux.Store.new(NoopReducer, {}, { middleware })

			store:dispatch({ type = "Foo" })

			expect(middlewareInitialized).to.equal(true)
			expect(lastActionProcessed).to.equal("Foo")
		end)
	end)
end