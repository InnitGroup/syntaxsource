return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)

	it("should create and destroy without errors", function()
		local element = Roact.createElement(ImageSetButton, {
			Size = UDim2.new(0, 8, 0, 8),
			Image = "LuaApp/icons/ic-ROBUX",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end

