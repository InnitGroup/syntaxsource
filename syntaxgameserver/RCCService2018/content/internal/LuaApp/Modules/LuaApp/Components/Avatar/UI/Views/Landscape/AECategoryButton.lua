local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESelectCategory = require(Modules.LuaApp.Thunks.AEThunks.AESelectCategory)
local AESetCategoryMenuOpen = require(Modules.LuaApp.Actions.AEActions.AESetCategoryMenuOpen)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local CommonConstants = require(Modules.LuaApp.Constants)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local AECategoryButton = Roact.PureComponent:extend("AECategoryButton")

function AECategoryButton:render()
	local categoryIndex = self.props.categoryIndex
	local index = self.props.index
	local position = self.state.position
	local category = self.props.category
	local iconLabel, circleLabel
	local textLabel = {}

	textLabel.text = category.titleLandscape or category.title
	if index == categoryIndex then
		circleLabel = AESpriteSheet.getImage("icon-border-on")
		iconLabel = AESpriteSheet.getImage(category.selectedIconImageName)
		textLabel.textColor3 = Color3.fromRGB(255, 161, 47)
	else
		circleLabel = AESpriteSheet.getImage("icon-border")
		iconLabel = AESpriteSheet.getImage(category.iconImageName)
	end

	local element = Roact.createElement("ImageButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.new(0, 90, 0, 90),
		ImageColor3 = CommonConstants.Color.WHITE,
		ImageRectSize = Vector2.new(52, 52),
		ScaleType = Enum.ScaleType.Stretch,

		[Roact.Event.Activated] = function()
			self.selectCategory(categoryIndex, index)
		end,
	}, {
		Icon = Roact.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 48, 0, 48),
			Image = circleLabel.image,
			ImageRectOffset = circleLabel.imageRectOffset,
			ImageRectSize = circleLabel.imageRectSize,
			ImageTransparency = circleLabel.imageTransparency,
		}, {
			IconImage = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, -14, 0.5, -14),
				Size = UDim2.new(0, 28, 0, 28),
				Image = iconLabel.image,
				ImageRectOffset = iconLabel.imageRectOffset,
				ImageRectSize = iconLabel.imageRectSize,
				ImageTransparency = iconLabel.imageTransparency,
			}),
		}),
		TextLabel = Roact.createElement(LocalizedTextLabel, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0.5, 28),
			Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.SourceSans,
			Text = textLabel.text,
			TextColor3 = textLabel.textColor3,
			TextSize = 14,
			TextTransparency = textLabel.textTransparency,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
	})

	return element
end

function AECategoryButton:init()
	local index = self.props.index
	local selectCategory = self.props.selectCategory
	local setCategoryMenuClosed = self.props.setCategoryMenuClosed

	self.selectCategory = function(categoryIndex, index)
		if categoryIndex ~= index then
			selectCategory(index)
		end
		setCategoryMenuClosed()
	end

	self.state = {
		position = UDim2.new(0.5, -45, 0, 90 * (index -1))
	}
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
		}
	end,

	function(dispatch)
		return {
			selectCategory = function(index)
				dispatch(AESelectCategory(index))
			end,
			setCategoryMenuClosed = function()
				dispatch(AESetCategoryMenuOpen(AEConstants.CategoryMenuOpen.CLOSED))
			end,
		}
	end
)(AECategoryButton)