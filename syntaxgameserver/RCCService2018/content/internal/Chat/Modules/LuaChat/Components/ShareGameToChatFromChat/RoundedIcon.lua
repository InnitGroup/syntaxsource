local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local GAME_BORDER_ICON = "rbxasset://textures/ui/LuaChat/graphic/gr-game-border-60x60.png"

local RoundedIcon = Roact.PureComponent:extend("RoundedIcon")

function RoundedIcon:render()
	local image = self.props.Image
	local size = self.props.Size
	local layoutOrder = self.props.LayoutOrder

	return Roact.createElement("ImageLabel", {
		BackgroundTransparency = 1,
		Image = image,
		Size = size,
		LayoutOrder = layoutOrder,
	}, {
		RoundCornerOverlay = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = GAME_BORDER_ICON,
			Size = UDim2.new(1, 0, 1, 0),
		}),
	})
end

return RoundedIcon