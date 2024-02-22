return function()
	local SendToChatButton = require(script.Parent.SendToChatButton)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)

	describe("SHOULD create and destroy without errors", function()
		it("WHEN passed no props", function()
			local element = Roact.createElement(SendToChatButton)

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end)

	it("SHOULD return a number from getWidth", function()
		local width = SendToChatButton.getWidth()
		expect(type(width)).to.equal("number")
	end)
end