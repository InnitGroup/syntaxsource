return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

	it("should create and destroy without errors", function()
		local element = Roact.createElement(ImageSetLabel, {
			Size = UDim2.new(0, 8, 0, 8),
			Image = "LuaApp/icons/ic-ROBUX",
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end
