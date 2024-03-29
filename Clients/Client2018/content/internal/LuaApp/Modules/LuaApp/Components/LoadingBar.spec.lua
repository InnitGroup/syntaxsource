return function()
	local LoadingBar = require(script.Parent.LoadingBar)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)

	it("should create and destroy without errors", function()
		local element = Roact.createElement(LoadingBar, {
			Position = UDim2.new(0.5, 0, 0.5, 5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end