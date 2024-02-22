local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AESlider = require(Modules.LuaApp.Components.Avatar.UI.AESlidersFrame)
local AEBodyColors = require(Modules.LuaApp.Components.Avatar.UI.AEBodyColorsFrame)
local CommonConstants = require(Modules.LuaApp.Constants)
local AERenderAssets = require(Modules.LuaApp.Components.Avatar.UI.AERenderAssets)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

local AEGetRecentAssets = require(Modules.LuaApp.Thunks.AEThunks.AEGetRecentAssets)
local AEGetUserOutfits = require(Modules.LuaApp.Thunks.AEThunks.AEGetUserOutfits)
local AEGetUserInventory = require(Modules.LuaApp.Thunks.AEThunks.AEGetUserInventory)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

local BUTTONS_PER_ROW = 4
local LOAD_MORE_BUFFER = settings():GetFFlag("AvatarEditorCatalogRecommended") and 250 or 125

local AEScrollingFrame = Roact.PureComponent:extend("AEScrollingFrame")

local View = {
	[DeviceOrientationMode.Portrait] = {
		POSITION = UDim2.new(0, 0, 0, 50),
		SIZE = UDim2.new(1, 0, 1, -50),
		GRID_PADDING = 6,
		getAssetButtonSize = function(scrollingFrame)
			local availableWidth = scrollingFrame.AbsoluteSize.X
			return availableWidth / BUTTONS_PER_ROW - 6
		end,
	},

	[DeviceOrientationMode.Landscape] = {
		POSITION = UDim2.new(0, 116, 0, 0),
		SIZE = UDim2.new(1, -128, 1, 0),
		GRID_PADDING = 12,
		getAssetButtonSize = function(scrollingFrame)
			local availableWidth = scrollingFrame.AbsoluteSize.X + 9
			return availableWidth / BUTTONS_PER_ROW - 14
		end,
	},
}

function AEScrollingFrame:pageTitleLabelUI()
	local categoryIndex = self.props.categoryIndex
	local tabsInfo = self.props.tabsInfo
	local page = AEUtils.getCurrentPage(categoryIndex, tabsInfo)

	local PageTitle = Roact.createElement(LocalizedTextLabel, {
		Position = UDim2.new(0, 7, 0, 3),
		Size = UDim2.new(1, -14, 0, 25),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSansLight,
		FontSize = Enum.FontSize.Size18,
		Text = page.title,
		TextColor3 = Color3.fromRGB(65, 78, 89),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	return PageTitle
end

function AEScrollingFrame:render()
	local deviceOrientation = self.props.deviceOrientation
	local borderSizePixel = deviceOrientation == DeviceOrientationMode.Portrait and 1 or 0
	local backgroundTransparency = deviceOrientation == DeviceOrientationMode.Portrait and 0 or 1
	local categoryIndex = self.props.categoryIndex
	local tabsInfo = self.props.tabsInfo
	local analytics = self.props.analytics
	local page = AEUtils.getCurrentPage(categoryIndex, tabsInfo)
	local slider = nil
	local bodyColors = nil
	local pageLabel = nil
	local assetTypeToRender = AEConstants.AvatarAssetGroup.None

	if page.recentPageType then
		assetTypeToRender = AEConstants.AvatarAssetGroup.Recent
	elseif page.assetTypeId then
		assetTypeToRender = AEConstants.AvatarAssetGroup.Owned
	elseif page.pageType == AEConstants.PageType.CurrentlyWearing then
		assetTypeToRender = AEConstants.AvatarAssetGroup.Equipped
	end

	-- Display the page label if on a Phone.
	if deviceOrientation == DeviceOrientationMode.Portrait then
		pageLabel = self:pageTitleLabelUI()
	end

	if page.pageType == AEConstants.PageType.Scale then
		slider = Roact.createElement(AESlider, {
			deviceOrientation = deviceOrientation,
			analytics = analytics,
			scrollingFrameRef = self.frameRef.current,
		})
	elseif page.pageType == AEConstants.PageType.BodyColors then
		bodyColors = Roact.createElement(AEBodyColors, {
			scrollingFrameRef = self.frameRef.current,
			deviceOrientation = deviceOrientation,
			analytics = analytics,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		ClipsDescendants = true,
		Size = View[deviceOrientation].SIZE,
		Position = View[deviceOrientation].POSITION,
		BackgroundTransparency = backgroundTransparency,
		BorderColor3 = CommonConstants.Color.GRAY3,
		BorderSizePixel = borderSizePixel,
		BackgroundColor3 = Color3.fromRGB(227, 227, 227),
		ScrollBarThickness = 0,

		[Roact.Ref] = self.frameRef,
		[Roact.Change.CanvasPosition] = function(rbx)
			self.loadMoreAssets(rbx)
			spawn(self.updateAssetCardIndicies)
		end,
		[Roact.Change.AbsoluteSize] = function(rbx)
			self.assetButtonSize = View[deviceOrientation].getAssetButtonSize(rbx)
			-- Needs a re-render on size change for asset cards.
			spawn(function()
				if self.isMounted and self.assetButtonSize ~= self.state.assetButtonSize then
					self:setState({ assetButtonSize = self.assetButtonSize })
				end
				self.updateAssetCardIndicies()
			end)
		end,
	}, {
		PageLabel = pageLabel,
		Sliders = slider,
		BodyColors = bodyColors,
		RenderedAssets = Roact.createElement(AERenderAssets, {
			scrollingFrame = self.frameRef.current,
			assetButtonSize = self.assetButtonSize,
			analytics = analytics,
			assetTypeToRender = assetTypeToRender,
			page = page,
			deviceOrientation = deviceOrientation,
			assetCardsToRender = self.state.assetCardsToRender,
			assetCardIndexStart = self.state.assetCardIndexStart,
		}),
	})
end

function AEScrollingFrame:didMount()
	self.updateAssetCardIndicies()
	self.isMounted = true
end

function AEScrollingFrame:willUnmount()
	self.isMounted = false
end

function AEScrollingFrame:didUpdate(prevProps, prevState)
	local categoryIndex = self.props.categoryIndex
	local tabsInfo = self.props.tabsInfo
	local page = AEUtils.getCurrentPage(categoryIndex, tabsInfo)
	local getUserOutfits = self.props.getUserOutfits
	local recentAssetsStatus = self.props.recentAssetsStatus
	local getRecentAssets = self.props.getRecentAssets
	local deviceOrientation = self.props.deviceOrientation

	if page.name == AEConstants.OUTFITS then
		getUserOutfits()
	end

	-- When visiting the recent all tab, retry this call if it failed
	if tabsInfo[categoryIndex] ~= prevProps[prevProps.categoryIndex] and page.itemType and
		(not recentAssetsStatus[page.itemType] or recentAssetsStatus[page.itemType] == RetrievalStatus.Failed) then
		getRecentAssets(page.itemType)
	end

	if prevState.absoluteSize ~= self.state.absoluteSize or prevProps.deviceOrientation ~= deviceOrientation then
		self:setState({ absoluteSize = self.frameRef.current.AbsoluteSize })
	end
end

function AEScrollingFrame:init()
	local getUserInventory = self.props.getUserInventory
	self.assetButtonSize = 0
	self.frameRef = Roact.createRef()
	self.state = {
		absoluteSize = nil,
		assetCardIndexStart = 1,
		assetCardsToRender = 0,
	}

	self.loadMoreAssets = function(rbx)
		if rbx.CanvasSize.Y.Offset - rbx.CanvasPosition.Y - LOAD_MORE_BUFFER > rbx.AbsoluteSize.Y then
			return
		end

		local categoryIndex = self.props.categoryIndex
		local tabsInfo = self.props.tabsInfo
		local page = AEUtils.getCurrentPage(categoryIndex, tabsInfo)
		local assetTypeCursor = self.props.assetTypeCursor

		-- Load more assets when the bottom of the page has been reached.
		if page.assetTypeId and assetTypeCursor[page.assetTypeId] ~= AEConstants.REACHED_LAST_PAGE then
			getUserInventory(page.assetTypeId)
		end
	end

	self.updateAssetCardIndicies = function()
		if not self.frameRef.current then
			return
		end

		local windowOffset = self.frameRef.current.CanvasPosition.Y
		local deviceOrientation = self.props.deviceOrientation
		local pageTitleLabelY = deviceOrientation == DeviceOrientationMode.Portrait and 25 or 0
		local assetCardIndexStart = math.max(1, math.floor((windowOffset - pageTitleLabelY)
			/ (self.assetButtonSize + View[deviceOrientation].GRID_PADDING)))
		local cardsPerColumn = deviceOrientation == DeviceOrientationMode.Portrait and 4 or 8
		local assetCardsToRender = (cardsPerColumn + 2) * BUTTONS_PER_ROW

		local shouldUpdate = assetCardIndexStart ~= self.state.assetCardIndexStart
			or assetCardsToRender ~= self.state.assetCardsToRender

		if self.isMounted and shouldUpdate then
			self:setState({
				assetCardIndexStart = assetCardIndexStart,
				assetCardsToRender = assetCardsToRender,
			})
		end
	end
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
			tabsInfo = state.AEAppReducer.AECategory.AETabsInfo,
			assetTypeCursor = state.AEAppReducer.AEAssetTypeCursor,
			recentAssetsStatus = state.AEAppReducer.AERecentAssetsStatus,
			screenSize = state.ScreenSize,
		}
	end,

	function(dispatch)
		return {
			getRecentAssets = function(category)
				dispatch(AEGetRecentAssets(category))
			end,
			getUserInventory = function(assetTypeId)
				dispatch(AEGetUserInventory(assetTypeId))
			end,
			getUserOutfits = function()
				dispatch(AEGetUserOutfits())
			end,
		}
	end
)(AEScrollingFrame)