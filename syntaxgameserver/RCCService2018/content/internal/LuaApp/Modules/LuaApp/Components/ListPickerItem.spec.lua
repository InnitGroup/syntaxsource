return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local ListPickerItem = require(script.Parent.ListPickerItem)

	it("should create and destroy without errors on phone", function()
		local item = {
			displayIcon = "rbxasset://textures/ui/LuaApp/icons/ic-chat20x20.png",
			text = "TestItem",
			onSelect = nil,
		}

		local element = Roact.createElement(ListPickerItem, {
			item = item,
			layoutOrder = 1,
			separatorEnabled = false,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

end