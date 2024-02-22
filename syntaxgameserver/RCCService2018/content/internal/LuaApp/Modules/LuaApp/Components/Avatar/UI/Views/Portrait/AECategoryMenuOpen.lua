local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")

local Roact = require(Modules.Common.Roact)
local AECategoryButton = require(Modules.LuaApp.Components.Avatar.UI.Views.Portrait.AECategoryButton)
local CommonConstants = require(Modules.LuaApp.Constants)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)

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
	local showTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local showPropertyGoals = { Position = UDim2.new(0, -52, 0, -10) }
	self.showTween = TweenService:Create(self.categoryMenuOpenRef.current, showTweenInfo, showPropertyGoals)

	local closeTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local closePropertyGoals = { Position = UDim2.new(0, -300, 0, -10) }
	self.closeTween = TweenService:Create(self.categoryMenuOpenRef.current, closeTweenInfo, closePropertyGoals)
end

function AECategoryMenuOpen:render()
	local categoryScrollerChildren = {}
	local categories = self.state.categories
	local visible = self.props.visible

	for index, category in ipairs(categories) do
		categoryScrollerChildren[category.name] = Roact.createElement(AECategoryButton, {
			index = index,
		})
	end

	local categoryScrollerSizeConstraint = Roact.createElement("UISizeConstraint", {})
	categoryScrollerChildren["SizeConstraint"] = categoryScrollerSizeConstraint

	return Roact.createElement("ImageButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, -300, 0, -10),
		Size = UDim2.new(0, 365, 0, 70),
		ImageColor3 = CommonConstants.Color.WHITE,
		Visible = visible,

		[Roact.Ref] = self.categoryMenuOpenRef,
	}, {
		BackgroundFill = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -34, 0, 60),
			Position = UDim2.new(0, 0, 0, 5),
			Image = "rbxasset://textures/AvatarEditorImages/Portrait/gr-primary-nav-rectangle.png",
			ImageColor3 = CommonConstants.Color.WHITE,
		}),
		RoundedEnd = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -34, 0, 5),
			Size = UDim2.new(0, 29, 0, 60),
			Image = "rbxasset://textures/AvatarEditorImages/Portrait/gr-primary-nav-half-circle.png",
			ImageColor3 = CommonConstants.Color.WHITE,
		}),
		Frame = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, categoryScrollerChildren),
	})
end

return AECategoryMenuOpen