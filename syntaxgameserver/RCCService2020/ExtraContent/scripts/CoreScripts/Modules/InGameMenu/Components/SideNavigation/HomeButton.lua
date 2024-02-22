--[[
	This is a temporary icon button until the entire side nav is replaced by uiBlox System Bar
]]

local CorePackages = game:GetService("CorePackages")

local InGameMenuDependencies = require(CorePackages.InGameMenuDependencies)
local t = InGameMenuDependencies.t
local Roact = InGameMenuDependencies.Roact
local UIBlox = InGameMenuDependencies.UIBlox

local ImageSetButton = UIBlox.Core.ImageSet.Button
local Images = UIBlox.App.ImageSet.Images

local HOME_ICON_ON = Images["icons/menu/home_on"]
local HOME_ICON_OFF = Images["icons/menu/home_off"]

local HomeButton = Roact.PureComponent:extend("HomeButton")

HomeButton.validateProps = t.strictInterface({
	on = t.optional(t.boolean),
	anchorPoint = t.optional(t.Vector2),
	position = t.optional(t.UDim2),
	layoutOrder = t.optional(t.integer),
	onActivated = t.callback,
})

HomeButton.defaultProps = {
	on = false,
}

function HomeButton:render()
	local icon = self.props.on and HOME_ICON_ON or HOME_ICON_OFF
	return Roact.createElement("Frame", {
		AnchorPoint = self.props.anchorPoint,
		BackgroundTransparency = 1,
		Position = self.props.position,
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = self.props.layoutOrder,
	}, {
		HomeButton = Roact.createElement(ImageSetButton, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(32, 32),
			[Roact.Event.Activated] = self.props.onActivated,
		})
	})
end

return HomeButton
