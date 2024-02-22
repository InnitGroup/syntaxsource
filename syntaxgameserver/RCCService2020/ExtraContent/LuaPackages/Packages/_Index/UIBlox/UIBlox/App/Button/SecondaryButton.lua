local Button = script.Parent
local App = Button.Parent
local UIBlox = App.Parent
local Packages = UIBlox.Parent

local Roact = require(Packages.Roact)

local Images = require(App.ImageSet.Images)
local CursorKind = require(App.SelectionImage.CursorKind)
local withSelectionCursorProvider = require(App.SelectionImage.withSelectionCursorProvider)
local validateButtonProps = require(Button.validateButtonProps)
local GenericButton = require(UIBlox.Core.Button.GenericButton)
local ControlState = require(UIBlox.Core.Control.Enum.ControlState)

local SecondaryButton = Roact.PureComponent:extend("SecondaryButton")

local BUTTON_STATE_COLOR = {
	[ControlState.Default] = "SecondaryDefault",
	[ControlState.Hover] = "SecondaryOnHover",
}

local CONTENT_STATE_COLOR = {
	[ControlState.Default] = "SecondaryContent",
	[ControlState.Hover] = "SecondaryOnHover",
}

SecondaryButton.defaultProps = {
	isDisabled = false,
	isLoading = false,
}

function SecondaryButton:render()
	assert(validateButtonProps(self.props))
	local image = Images["component_assets/circle_17_stroke_1"]
	return withSelectionCursorProvider(function(getSelectionCursor)
		return Roact.createElement(GenericButton, {
			Size = self.props.size,
			AnchorPoint = self.props.anchorPoint,
			Position = self.props.position,
			LayoutOrder = self.props.layoutOrder,
			SelectionImageObject = getSelectionCursor(CursorKind.RoundedRectNoInset),
			icon = self.props.icon,
			text = self.props.text,
			isDisabled = self.props.isDisabled,
			isLoading = self.props.isLoading,
			onActivated = self.props.onActivated,
			onStateChanged = self.props.onStateChanged,
			userInteractionEnabled = self.props.userInteractionEnabled,
			buttonImage = image,
			buttonStateColorMap = BUTTON_STATE_COLOR,
			contentStateColorMap = CONTENT_STATE_COLOR,
		})
	end)
end

return SecondaryButton