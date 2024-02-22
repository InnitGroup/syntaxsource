local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESetCategoryMenuOpen = require(Modules.LuaApp.Actions.AEActions.AESetCategoryMenuOpen)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local CommonConstants = require(Modules.LuaApp.Constants)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)

local AECategoryMenuClosed = Roact.PureComponent:extend("AECategoryMenuClosed")

function AECategoryMenuClosed:init()
	self.categoryMenuClosedRef = Roact.createRef()
end

function AECategoryMenuClosed:willUpdate(nextProps, nextState)
	if nextProps.visible and not self.props.visible then
		self.showTween:Play()
	elseif not nextProps.visible and self.props.visible then
		self.closeTween:Play()
	end
end

function AECategoryMenuClosed:didMount()
	local showTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local showPropertyGoals = { Position = UDim2.new(0, -300, 0, -10) }
	self.showTween = TweenService:Create(self.categoryMenuClosedRef.current, showTweenInfo, showPropertyGoals)

	local closeTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local closePropertyGoals = { Position = UDim2.new(0, -52, 0, -10) }
	self.closeTween = TweenService:Create(self.categoryMenuClosedRef.current, closeTweenInfo, closePropertyGoals)
end

function AECategoryMenuClosed:render()
	local currentCategory = AECategories.categories[self.props.categoryIndex]
	local setCategoryMenuOpen = self.props.setCategoryMenuOpen
	local visible = self.props.visible

	return Roact.createElement("ImageButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, -300, 0, -10),
		Size = UDim2.new(0, 365, 0, 70),
		ImageColor3 = CommonConstants.Color.WHITE,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = visible,

		[Roact.Ref] = self.categoryMenuClosedRef,
		[Roact.Event.Activated] = setCategoryMenuOpen,
	}, {
		BackgroundFill = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 5),
			Size = UDim2.new(1, -34, 0, 60),
			Image = "rbxasset://textures/AvatarEditorImages/Portrait/gr-primary-nav-rectangle.png",
			ImageColor3 = CommonConstants.Color.WHITE,
		}),
		IndexIndicator = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -59, 0.5, -24),
			Size = UDim2.new(0, 48, 0, 48),
			ZIndex = 2,
			Image = AEConstants.IMAGE_SHEET,
			ImageColor3 = CommonConstants.Color.WHITE,
			ImageRectOffset = AESpriteSheet.getImage(
				'ring'..((currentCategory.positionInCategoryMenu - 1) % 5 + 1)).imageRectOffset,
			ImageRectSize = AESpriteSheet.getImage(
				'ring'..((currentCategory.positionInCategoryMenu - 1) % 5 + 1)).imageRectSize,
		}),
		RoundedEnd = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -34, 0, 5),
			Size = UDim2.new(0, 29, 0, 60),
			Image = "rbxasset://textures/AvatarEditorImages/Portrait/gr-primary-nav-half-circle.png",
			ImageColor3 = CommonConstants.Color.WHITE,
		}),
		SelectedIcon = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -49, 0.5, -14),
			Size = UDim2.new(0, 28, 0, 28),
			ZIndex = 2,
			Image = AEConstants.IMAGE_SHEET,
			ImageColor3 = CommonConstants.Color.WHITE,
			ImageRectOffset = AESpriteSheet.getImage(currentCategory.iconImageName).imageRectOffset,
			ImageRectSize = AESpriteSheet.getImage(currentCategory.iconImageName).imageRectSize,
		}),
	})
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
			setCategoryMenuOpen = function()
				dispatch(AESetCategoryMenuOpen(AEConstants.CategoryMenuOpen.OPEN))
			end,
		}
	end
)(AECategoryMenuClosed)