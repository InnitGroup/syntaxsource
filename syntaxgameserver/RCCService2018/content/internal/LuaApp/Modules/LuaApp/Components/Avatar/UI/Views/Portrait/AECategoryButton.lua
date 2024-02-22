local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESelectCategory = require(Modules.LuaApp.Thunks.AEThunks.AESelectCategory)
local AESetCategoryMenuOpen = require(Modules.LuaApp.Actions.AEActions.AESetCategoryMenuOpen)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local CommonConstants = require(Modules.LuaApp.Constants)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)

local AECategoryButton = Roact.PureComponent:extend("AECategoryButton")

function AECategoryButton:render()
	local position = self.state.position
	local categoryIndex = self.props.categoryIndex
	local index = self.props.index
	local categoryInfo = AECategories.categories[index]
	local image, iconLabel

	if index == categoryIndex then
		image = AESpriteSheet.getImage("gr-orange-circle")
		iconLabel = AESpriteSheet.getImage(categoryInfo.selectedIconImageName)
	else
		image = AESpriteSheet.getImage("gr-category-selector")
		iconLabel = AESpriteSheet.getImage(categoryInfo.iconImageName)
	end

	local element = Roact.createElement("ImageButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.new(0, 52, 0, 52),
		Image = image.image,
		ImageColor3 = CommonConstants.Color.WHITE,
		ImageRectSize = image.imageRectSize,
		ImageRectOffset = image.imageRectOffset,

		[Roact.Event.Activated] = function()
			self.selectCategory(categoryIndex, index)
		end
	}, {
		IconLabel = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, -14, 0.5, -14),
			Size = UDim2.new(0, 28, 0, 28),
			Image = iconLabel.image,
			ImageRectOffset = iconLabel.imageRectOffset,
			ImageRectSize = iconLabel.imageRectSize,
			ImageTransparency = iconLabel.imageTransparency,
		}),
	})

	return element
end

function AECategoryButton:init()
	local setCategoryMenuClosed = self.props.setCategoryMenuClosed
	local selectCategory = self.props.selectCategory
	local index = self.props.index
	local position = UDim2.new(1, - (5 - index + 1) * 61, .5, -26)

	self.selectCategory = function(categoryIndex, index)
		if categoryIndex ~= index then
			selectCategory(index)
		end
		setCategoryMenuClosed()
	end

	self.state = {
		position = position,
	}
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
			resolutionScale = state.AEAppReducer.AEResolutionScale,
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