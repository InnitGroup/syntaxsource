return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)

	local FitImageTextButton = require(script.parent.FitImageTextButton)

	describe("FitTextButton", function()
		local BUTTON_DEFAULT_HEIGHT = 32

		it("should create and destroy without errors", function()
			local element = Roact.createElement(FitImageTextButton)
			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should expand properly to fit with the text and no left icon properly", function()
			local text = "View Game"
			local minWidth = 200
			local element = Roact.createElement(FitImageTextButton, {
				leftIconEnabled = false,
				maxWidth = 250,
				minWidth = minWidth,
				text = text,
			})

			local container = Instance.new("Folder")
			Roact.mount(element, container, "FitTest")

			expect(container.FitTest.Size.X.Offset).to.equal(minWidth)
			expect(container.FitTest.Size.Y.Offset).to.equal(BUTTON_DEFAULT_HEIGHT)
		end)

		it("should expand to fit with a left icon and empty string properly", function()
			local text = ""
			local minWidth = 95
			local ROBUX_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-robux.png"
			local ROUNDED_BUTTON = "rbxasset://textures/ui/LuaChat/9-slice/input-default.png"

			local element = Roact.createElement(FitImageTextButton, {
				backgroundImage = ROUNDED_BUTTON,
				layoutOrder = 3,
				leftIcon = ROBUX_ICON,
				leftIconEnabled = true,
				maxWidth = 250,
				minWidth = minWidth,
				text = text,
			})

			local container = Instance.new("Folder")
			Roact.mount(element, container, "FitTest")

			expect(container.FitTest.Size.X.Offset).to.equal(minWidth)
			expect(container.FitTest.Size.Y.Offset).to.equal(BUTTON_DEFAULT_HEIGHT)
		end)

		it("should expand to fit with a large left icon properly", function()
			local text = "10,000,000,000"
			local maxWidth = 200
			local ROBUX_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-robux.png"
			local ROUNDED_BUTTON = "rbxasset://textures/ui/LuaChat/9-slice/input-default.png"
			local iconSize = 250

			local element = Roact.createElement(FitImageTextButton, {
				backgroundImage = ROUNDED_BUTTON,
				iconSize = iconSize,
				layoutOrder = 3,
				leftIcon = ROBUX_ICON,
				leftIconEnabled = true,
				maxWidth = maxWidth,
				minWidth = 95,
				text = text,
			})

			local container = Instance.new("Folder")
			Roact.mount(element, container, "FitTest")

			expect(container.FitTest.Size.X.Offset).to.equal(maxWidth)
			expect(container.FitTest.Size.Y.Offset).to.equal(BUTTON_DEFAULT_HEIGHT)
		end)

		it("should expand to fit with a long text properly", function()
			local text = "Test button with a super long string. Should expand properly"
			local maxWidth = 100
			local ROBUX_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-robux.png"
			local ROUNDED_BUTTON = "rbxasset://textures/ui/LuaChat/9-slice/input-default.png"

			local element = Roact.createElement(FitImageTextButton, {
				backgroundImage = ROUNDED_BUTTON,
				layoutOrder = 3,
				leftIcon = ROBUX_ICON,
				leftIconEnabled = true,
				maxWidth = maxWidth,
				minWidth = 10,
				text = text,
			})

			local container = Instance.new("Folder")
			Roact.mount(element, container, "FitTest")

			expect(container.FitTest.Size.X.Offset).to.equal(maxWidth)
			expect(container.FitTest.Size.Y.Offset).to.equal(BUTTON_DEFAULT_HEIGHT)
		end)
	end)
end