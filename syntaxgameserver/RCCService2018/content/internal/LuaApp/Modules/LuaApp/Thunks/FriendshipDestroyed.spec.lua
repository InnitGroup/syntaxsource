return function()
	local FriendshipDestroyed = require(script.Parent.FriendshipDestroyed)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local UserModel = require(Modules.LuaApp.Models.User)

	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)

	it("should mark isFriend of the unfriended user false", function()
		local store = Rodux.Store.new(AppReducer, {
			FriendCount = 2,
			Users = {
				["1234"] = UserModel.fromData(1234, "Friend One", true),
				["5678"] = UserModel.fromData(5678, "Friend Two", true),
			},
		})

		local state = store:getState()
		expect(state.Users["1234"].isFriend).to.equal(true)
		expect(state.Users["5678"].isFriend).to.equal(true)

		store:dispatch(FriendshipDestroyed("1234"))

		state = store:getState()
		expect(state.Users["1234"].isFriend).to.equal(false)
		expect(state.Users["5678"].isFriend).to.equal(true)
	end)

	it("should decrement the friend count", function()
		local store = Rodux.Store.new(AppReducer, {
			FriendCount = 2,
			Users = {
				["1234"] = UserModel.fromData(1234, "Friend One", true),
				["5678"] = UserModel.fromData(5678, "Friend Two", true),
			},
		})

		local state = store:getState()
		expect(state.FriendCount).to.equal(2)

		store:dispatch(FriendshipDestroyed("1234"))

		state = store:getState()
		expect(state.FriendCount).to.equal(1)
	end)

	it("should not decrement friend count if target user is already not a friend", function()
		local store = Rodux.Store.new(AppReducer, {
			FriendCount = 2,
			Users = {
				["1234"] = UserModel.fromData(1234, "Friend One", true),
				["5678"] = UserModel.fromData(5678, "Friend Two", true),
			},
		})

		local state = store:getState()
		expect(state.FriendCount).to.equal(2)
		store:dispatch(FriendshipDestroyed("0000"))	-- not in the store

		state = store:getState()
		expect(state.FriendCount).to.equal(2)
		store:dispatch(FriendshipDestroyed("1234"))

		state = store:getState()
		expect(state.FriendCount).to.equal(1)
		store:dispatch(FriendshipDestroyed("1234")) -- already unfriended

		state = store:getState()
		expect(state.FriendCount).to.equal(1)
	end)

	it("should not do anything if target user is not in the store", function()
		local store = Rodux.Store.new(AppReducer, {
			FriendCount = 2,
			Users = {
				["1234"] = UserModel.fromData(1234, "Friend One", true),
				["5678"] = UserModel.fromData(5678, "Friend Two", true),
			},
		})

		local state = store:getState()
		expect(state.FriendCount).to.equal(2)

		store:dispatch(FriendshipDestroyed("0987"))

		state = store:getState()
		expect(state.FriendCount).to.equal(2)
		expect(state.Users["1234"].isFriend).to.equal(true)
		expect(state.Users["5678"].isFriend).to.equal(true)
	end)
end