local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESelectCategoryTab = require(Modules.LuaApp.Thunks.AEThunks.AESelectCategoryTab)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local CommonConstants = require(Modules.LuaApp.Constants)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local AEGetUserInventory = require(Modules.LuaApp.Thunks.AEThunks.AEGetUserInventory)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local AETabButton = Roact.PureComponent:extend("AETabButton")

local TAB_HEIGHT = 90
local FIRST_TAB_BONUS_WIDTH = 45
local PROP_KEYS = {
	tabListRef = "tabListRef",
	avatarType = "avatarType",
}

function AETabButton:getDivider()
	local index = self.props.index

	if index > 1 then
		return Roact.createElement("Frame", {
			BackgroundColor3 = CommonConstants.Color.GRAY4,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -12, 0, 1),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
		})
	end

	return nil
end

function AETabButton:render()
	self.index = self.props.index
	self.currentTabPage = self.props.currentTabPage
	self.categoryIndex = self.props.categoryIndex
	local page = self.props.page
	local divider = self:getDivider()
	local avatarType = self.props.avatarType
	local frame = {}
	local nameLabel = {}
	local imageFrame = {}
	local notFirstTabBonusWidth = self.index ~= 1 and FIRST_TAB_BONUS_WIDTH or 0
	local firstTabBonusWidth = self.index == 1 and FIRST_TAB_BONUS_WIDTH or 0
	local imageInfo = self.index == self.currentTabPage
		and AESpriteSheet.getImage(page.iconImageSelectedName) or AESpriteSheet.getImage(page.iconImageName)

	frame.size = UDim2.new(1, 0, 0, TAB_HEIGHT + firstTabBonusWidth)
	frame.position = UDim2.new(0, 0, 0, (self.index - 1) * (TAB_HEIGHT + 1) + notFirstTabBonusWidth)

	if self.index == self.currentTabPage then
		frame.backgroundColor3 = CommonConstants.Color.ORANGE

		if page.pageType == AEConstants.PageType.Scale and avatarType == AEConstants.AvatarType.R6 then
			frame.backgroundColor3 = CommonConstants.Color.BROWN_WARNING
		end

		nameLabel.textColor3 = CommonConstants.Color.WHITE
		frame.backgroundTransparency = 0
	else
		nameLabel.textColor3 = CommonConstants.Color.GRAY2
		frame.backgroundTransparency = 1

		if page.pageType == AEConstants.PageType.Scale and avatarType == AEConstants.AvatarType.R6 then
			frame.backgroundColor3 = CommonConstants.Color.GRAY3
			frame.backgroundTransparency = 0
		end
	end

	imageFrame.size = UDim2.new(0, 28, 0, 28)
	imageFrame.position = UDim2.new(.5, -14, .5, -20)

	if self.index == 1 then
		imageFrame.position = imageFrame.position + UDim2.new(0, 0, 0, FIRST_TAB_BONUS_WIDTH * 0.5 - 6)
	end

	nameLabel.position = UDim2.new(0, 5, imageFrame.position.Y.Scale,
		imageFrame.position.Y.Offset + imageFrame.size.Y.Offset + 4)

	return Roact.createElement("ImageButton", {
		Name = frame.name,
		Image = frame.image,
		BackgroundColor3 = frame.backgroundColor3,
		BackgroundTransparency = frame.backgroundTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = frame.size,
		Position = frame.position,

		[Roact.Event.Activated] = self.dispatchFunction
	} , {
		ImageLabel = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 28, 0, 28),
			Position = imageFrame.position,
			ImageRectSize = imageInfo.imageRectSize,
			ImageRectOffset = imageInfo.imageRectOffset,
			Image = imageInfo.image,
		}),
		TextLabel = Roact.createElement(LocalizedTextLabel, {
			Text = page.titleLandscape or page.title,
			BackgroundTransparency = 1,
			Position = nameLabel.position,
			Size = UDim2.new(1, -10, 1, 0),
			Font = Enum.Font.SourceSans,
			FontSize = Enum.FontSize.Size14,
			TextColor3 = nameLabel.textColor3,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}),
		Divider = divider,
	})
end

function AETabButton:checkForUpdate()
	local page = self.props.page
	local getUserInventory = self.props.getUserInventory
	local initializedTabs = self.props.initializedTabs

	-- Check if this tab has been accessed before. If not, dispatch an action for a web call.
	if page.assetTypeId and not initializedTabs[page.assetTypeId] and self.currentTabPage == self.index then
		getUserInventory(page.assetTypeId)
	end
end

function AETabButton:didUpdate()
	self:checkForUpdate()
end

-- Tabs should only re-render with changes to these props.
function AETabButton:shouldUpdate(nextProps, nextState)
	local index = self.index
	local tab = self.props.currentTabPage
	local nextTab = nextProps.currentTabPage

	if self.props[PROP_KEYS.tabListRef] ~= nextProps[PROP_KEYS.tabListRef]
		or self.props[PROP_KEYS.avatarType] ~= nextProps[PROP_KEYS.avatarType]
		or index == tab or index == nextTab then
		return true
	else
		return false
	end
end

function AETabButton:init()
	local selectCategoryTab = self.props.selectCategoryTab
	self.currentTabPage = self.props.currentTabPage
	self.index = self.props.index

	self.dispatchFunction = function()
		if self.currentTabPage ~= self.index then
			selectCategoryTab(self.categoryIndex, self.index)
		end
	end

	self:checkForUpdate()
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			avatarType = state.AEAppReducer.AECharacter.AEAvatarType,
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
			initializedTabs = state.AEAppReducer.AECategory.AEInitializedTabs,
		}
	end,

	function(dispatch)
		return {
			getUserInventory = function(assetType)
				dispatch(AEGetUserInventory(assetType))
			end,
			selectCategoryTab = function(categoryIndex, tabIndex)
				dispatch(AESelectCategoryTab(categoryIndex, tabIndex))
			end,
		}
	end
)(AETabButton)