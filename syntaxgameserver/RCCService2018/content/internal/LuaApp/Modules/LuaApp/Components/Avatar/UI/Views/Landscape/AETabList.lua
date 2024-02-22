local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AETabButton = require(Modules.LuaApp.Components.Avatar.UI.Views.Landscape.AETabButton)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local CommonConstants = require(Modules.LuaApp.Constants)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)
local Constants = require(Modules.LuaApp.Constants)

local AETabList = Roact.PureComponent:extend("AETabList")

local FIRST_TAB_BONUS_WIDTH = 45
local TAB_HEIGHT = 90
local TAB_PREFIX = "Tab-"

local tweenInfo = {
	TAB_LIST_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	TAB_LIST_TWEEN_INFO_FAST = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),

	IMAGE_INVISIBLE = { ImageTransparency = 1 },
	BACKGROUND_INVISIBLE = { BackgroundTransparency = 1 },
	TEXT_INVISIBLE = { TextTransparency = 1 },

	IMAGE_VISIBLE = { ImageTransparency = 0 },
	BACKGROUND_VISIBLE = { BackgroundTransparency = 0 },
	TEXT_VISIBLE = { TextTransparency = 0 },
}

function AETabList:getPageName()
	local categoryIndex = self.props.categoryIndex
	local tabIndex = self.props.tabsInfo[categoryIndex]
	local categoryPages = AECategories.categories[categoryIndex].pages
	local pageName = categoryPages[tabIndex].name
	return pageName
end

-- Get the UI of all the tabs in this category.
function AETabList:getTabsUI()
	local categoryIndex = self.props.categoryIndex
	local currentTabPage = self.props.tabsInfo[categoryIndex]
	local category = AECategories.categories[categoryIndex]
	local tabs = {}

	-- Loop through the tabs in props and create each one
	for index, page in pairs(category.pages) do
		tabs[TAB_PREFIX ..page.name] = Roact.createElement(AETabButton, {
			index = index,
			page = page,
			currentTabPage = currentTabPage,
		})
	end

	return tabs
end

function AETabList:didUpdate(prevProps, prevState)
	local categoryIndex = self.props.categoryIndex
	local tabInfo = self.props.tabsInfo[categoryIndex]

	-- Check if the menu opened or closed
	if self.props.categoryMenuOpen ~= prevProps.categoryMenuOpen and self.tabListRef.current then
		if self.props.categoryMenuOpen == AEConstants.CategoryMenuOpen.OPEN then
			TweenService:Create(self.tabListContainerFrame.current.TabListBackground,
				tweenInfo.TAB_LIST_TWEEN_INFO,
				tweenInfo.IMAGE_INVISIBLE):Play()

			for _, obj in next, self.tabListRef.current.Contents:GetChildren() do
				if obj.ClassName == 'ImageButton' then
					if obj.Name == TAB_PREFIX ..self:getPageName() then
						local objTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
						TweenService:Create(obj, objTweenInfo, tweenInfo.BACKGROUND_INVISIBLE):Play()
					else
						local objTweenInfo = TweenInfo.new(0)
						TweenService:Create(obj, objTweenInfo, tweenInfo.BACKGROUND_INVISIBLE):Play()
					end

					TweenService:Create(obj.ImageLabel,
						tweenInfo.TAB_LIST_TWEEN_INFO,
						tweenInfo.IMAGE_INVISIBLE):Play()
					TweenService:Create(obj.TextLabel,
						tweenInfo.TAB_LIST_TWEEN_INFO,
						tweenInfo.TEXT_INVISIBLE):Play()
				else
					TweenService:Create(obj,
						tweenInfo.TAB_LIST_TWEEN_INFO,
						tweenInfo.BACKGROUND_INVISIBLE):Play()
				end
			end
		else
			for _, obj in next, self.tabListRef.current.Contents:GetChildren() do
				if obj.ClassName == 'ImageButton' then
					if obj.Name == TAB_PREFIX ..self:getPageName() then
						TweenService:Create(obj, tweenInfo.TAB_LIST_TWEEN_INFO,
							tweenInfo.BACKGROUND_VISIBLE,
							tweenInfo.BACKGROUND_INVISIBLE):Play()
					end
					TweenService:Create(obj.ImageLabel, tweenInfo.TAB_LIST_TWEEN_INFO,
						tweenInfo.IMAGE_VISIBLE,
						tweenInfo.IMAGE_INVISIBLE):Play()
					TweenService:Create(obj.TextLabel, tweenInfo.TAB_LIST_TWEEN_INFO,
						tweenInfo.TEXT_VISIBLE,
						tweenInfo.TEXT_INVISIBLE):Play()
				else
					TweenService:Create(obj, tweenInfo.TAB_LIST_TWEEN_INFO,
						tweenInfo.BACKGROUND_VISIBLE,
						tweenInfo.BACKGROUND_INVISIBLE):Play()
				end
			end

			TweenService:Create(self.tabListContainerFrame.current.TabListBackground, tweenInfo.TAB_LIST_TWEEN_INFO,
				tweenInfo.IMAGE_VISIBLE,
				tweenInfo.IMAGE_INVISIBLE):Play()
		end
	end

	if self.props.categoryIndex ~= prevProps.categoryIndex then
		self.tabListRef.current.CanvasPosition =
			Vector2.new(0, TAB_HEIGHT * (tabInfo - 1))
	end
end

function AETabList:render()
	local categoryIndex = self.props.categoryIndex
	local category = AECategories.categories[categoryIndex]
	local canvasSize = UDim2.new(0, 0, 0, #(category.pages) * (TAB_HEIGHT + 1) + FIRST_TAB_BONUS_WIDTH - 1)

	local tabs = self:getTabsUI()

	local tabList = Roact.createElement("Frame", {
		Size = UDim2.new(0, 78, 1, -75),
		Position = UDim2.new(0, 21, 0, 60),
		Visible = true,
		BackgroundColor3 = CommonConstants.Color.WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 1,

		-- Used for tweening
		[Roact.Ref] = self.tabListContainerFrame,
	}, {
		TabList = Roact.createElement("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -6),
			ClipsDescendants = true,
			BackgroundColor3 = CommonConstants.Color.GRAY3,
			BorderSizePixel = 1,
			BackgroundTransparency = 1,
			CanvasSize = canvasSize,
			ScrollBarThickness = 0,

			-- Used for tweening and keeping CanvasPosition between categories.
			[Roact.Ref] = self.tabListRef,
		}, {
			Contents = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			},
				tabs),
		}),
		TabListBackground = Roact.createElement("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.WHITE,
		}),
	})

	return tabList
end

function AETabList:init()
	self.tabListContainerFrame = Roact.createRef()
	self.tabListRef = Roact.createRef()
end

function AETabList:didMount()
	if not self.state.initialized then
		self:setState({ initialized = true })
	end
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
			tabsInfo = state.AEAppReducer.AECategory.AETabsInfo,
			categoryMenuOpen = state.AEAppReducer.AECategory.AECategoryMenuOpen,
		}
	end
)(AETabList)