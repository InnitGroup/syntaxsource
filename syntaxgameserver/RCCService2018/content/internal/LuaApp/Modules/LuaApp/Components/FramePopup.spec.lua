return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local FramePopup = require(Modules.LuaApp.Components.FramePopup)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local listContents = {}
	listContents["Layout"] = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Name = "Layout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5)
	})

	it("should create and destroy without errors", function()
		local element = mockServices({
			framePopUp = Roact.createElement(FramePopup, {
				heightScrollContainer = 50,
				onCancel = nil,
			},listContents)
		}, {
			includeStoreProvider = false,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end