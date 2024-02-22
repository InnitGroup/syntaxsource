return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local FramePopOut = require(Modules.LuaApp.Components.FramePopOut)

	local listContents = {}
	listContents["Layout"] = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Name = "Layout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5)
	})

	it("should create and destroy without errors", function()
		local element = Roact.createElement(FramePopOut, {
				itemWidth = 200,
				heightScrollContainer = 50,
				onCancel = nil,
				parentShape = {
					x = 10,
					y = 10,
					width = 100,
					height = 20,
					parentWidth = 600,
					parentHeight = 600,
				},
			},
			listContents
		)

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end