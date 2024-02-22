return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local CurrentToastMessage = require(Modules.LuaApp.Reducers.CurrentToastMessage)

	local SetCurrentToastMessage = require(Modules.LuaApp.Actions.SetCurrentToastMessage)
	local RemoveCurrentToastMessage = require(Modules.LuaApp.Actions.RemoveCurrentToastMessage)

	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	describe("CurrentToastMessage", function()
		it("should be empty by default", function()
			local state = CurrentToastMessage(nil, {})

			expect(type(state)).to.equal("table")
			expect(TableUtilities.FieldCount(state)).to.equal(0)
		end)

		it("should be unmodified by other actions", function()
			local oldState = CurrentToastMessage(nil, {})
			local newState = CurrentToastMessage(oldState, { type = "not a real action" })

			expect(oldState).to.equal(newState)
		end)

		it("should be changed using SetCurrentToastMessage", function()
			local oldState = CurrentToastMessage(nil, {})
			local newState = CurrentToastMessage(oldState, SetCurrentToastMessage({}))
			expect(oldState).to.never.equal(newState)

			local newToastMessage = "error"
			local currentToastMessage = {
				toastMessage = newToastMessage
			}
			newState = CurrentToastMessage(newState, SetCurrentToastMessage(currentToastMessage))
			expect(newState.toastMessage).to.equal(newToastMessage)
		end)

		it("should be changed using RemoveCurrentToastMessage", function()
			local currentToastMessage = {
				toastMessage = ""
			}
			local oldState = CurrentToastMessage(nil, SetCurrentToastMessage(currentToastMessage))
			local newState = CurrentToastMessage(oldState, RemoveCurrentToastMessage())
			expect(TableUtilities.FieldCount(oldState)).to.equal(1)
			expect(TableUtilities.FieldCount(newState)).to.equal(0)
		end)
	end)


end