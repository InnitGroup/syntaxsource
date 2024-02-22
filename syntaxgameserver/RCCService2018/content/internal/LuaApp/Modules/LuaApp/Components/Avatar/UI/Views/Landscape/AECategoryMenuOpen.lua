local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")

local Roact = require(Modules.Common.Roact)
local AECategoryButton = require(Modules.LuaApp.Components.Avatar.UI.Views.Landscape.AECategoryButton)
local CommonConstants = require(Modules.LuaApp.Constants)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)
local AECategoryMenuCloseButton = require(Modules.LuaApp.Components.Avatar.UI.Views.AECategoryMenuCloseButton)

local AECategoryMenuOpen = Roact.PureComponent:extend("AECategoryMenuOpen")

function AECategoryMenuOpen:init()
	self.categoryMenuOpenRef = Roact.createRef()
	self.state = {
		categories = AECategories.categories,
	}
end

function AECategoryMenuOpen:willUpdate(nextProps, nextState)
	if nextProps.visible and not self.props.visible then
		self.showTween:Play()
	elseif not nextProps.visible and self.props.visible then
		self.closeTween:Play()
	end
end

function AECategoryMenuOpen:didMount()
	local showTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local showPropertyGoals = { Size = UDim2.new(0, 90, 1, -22) }
	self.showTween = TweenService:Create(self.categoryMenuOpenRef.current, showTweenInfo, showPropertyGoals)

	local closeTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local closePropertyGoals = { Size = UDim2.new(0, 90, 0, 90) }
	self.closeTween = TweenService:Create(self.categoryMenuOpenRef.current, closeTweenInfo, closePropertyGoals)
end

function AECategoryMenuOpen:render()
	local visible = self.props.visible
	local categories = self.state.categories
	local categoryScrollerChildren = {}

	for index, category in pairs(categories) do
		categoryScrollerChildren[category.name] = Roact.createElement(AECategoryButton, {
			index = index,
			category = category,
		})
	end

	local categoryScrollerSizeConstraint = Roact.createElement("UISizeConstraint", {})
	categoryScrollerChildren[#categoryScrollerChildren + 1] = categoryScrollerSizeConstraint

	return Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 15, 0, 15),
			Size = UDim2.new(0, 90, 0, 90),
			Image = "rbxasset://textures/AvatarEditorImages/Landscape/gr-primary-nav-tablet.png",
			ImageColor3 = CommonConstants.Color.WHITE,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 48, 48, 48),
			Visible = visible,

			[Roact.Ref] = self.categoryMenuOpenRef,
		}, {
		CategoryScroller = Roact.createElement("ScrollingFrame", {
			ScrollBarThickness = 0,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 90),
			Size = UDim2.new(1, 0, 1, -135),
			CanvasSize = UDim2.new(1, 0, 0, #AECategories.categories * 90),
		},
			categoryScrollerChildren
		),
		CloseButton = Roact.createElement(AECategoryMenuCloseButton)
	})
end

return AECategoryMenuOpen