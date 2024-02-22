return function()
	local RoundedIcon = require(script.Parent.RoundedIcon)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)

	describe("SHOULD create and destroy without errors", function()
		it("WHEN passed no props", function()
			local element = Roact.createElement(RoundedIcon)

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
		it("WHEN passed an Image", function()
			local element = Roact.createElement(RoundedIcon, {
				Image = "mock-id",
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
		it("WHEN passed a valid Size", function()
			local element = Roact.createElement(RoundedIcon, {
				Size = UDim2.new(1, 0, 1, 0),
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end)
end