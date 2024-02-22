local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactLocalization = require(Modules.LuaApp.Services.RoactLocalization)
local RoactAnalyticsHomePage = require(Modules.LuaApp.Services.RoactAnalyticsHomePage)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local FeatureContext = require(Modules.LuaApp.Enum.FeatureContext)

local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local PlayabilityStatus = require(Modules.LuaApp.Enum.PlayabilityStatus)

local joinGame = require(Modules.LuaChat.Utils.joinGame)
local formatInteger = require(Modules.LuaChat.Utils.formatInteger)

local Constants = require(Modules.LuaApp.Constants)
local FitImageTextButton = require(Modules.LuaApp.Components.FitImageTextButton)

local DEFAULT_BUTTON_COLOR = Constants.Color.GREEN_PRIMARY
local DEFAULT_BUTTON_TEXT_COLOR = Constants.Color.WHITE
local DEFAULT_BUTTON_WIDTH = 90

local VIEW_GAME_DETAILS_FROM_BUTTON = Constants.AnalyticsKeyword.VIEW_GAME_DETAILS_FROM_BUTTON

local ROBUX_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-ROBUX.png"
local ROUNDED_BUTTON = "rbxasset://textures/ui/LuaChat/9-slice/input-default.png"

local CONFIGURE_BY_FEATURE_DEFAULT_KEY = "Default"

local GameButtonConfigByFeature = {
	[FeatureContext.PeopleList] = {
		ViewDetailsEnabled = true,
		JoinGameEnabled = true,
		BuyToPlayButtonEnabled = true,
	},
	[FeatureContext.PlacesList] = {
		ViewDetailsEnabled = false,
		JoinGameEnabled = false,
		BuyToPlayButtonEnabled = true,
	},
	[CONFIGURE_BY_FEATURE_DEFAULT_KEY] = {
		ViewDetailsEnabled = true,
		JoinGameEnabled = true,
		BuyToPlayButtonEnabled = true,
	},
}

local GameButton = Roact.PureComponent:extend("GameButton")

function GameButton:init()
	self.openGameDetailsFromButton = function()
		local guiService = self.props.guiService
		local analytics = self.props.analytics
		local friend = self.props.friend
		local index = self.props.index
		local universePlaceInfo = self.props.universePlaceInfo
		local callbackOnOpenGameDetails = self.props.callbackOnOpenGameDetails
		local featureContext = self.props.featureContext

		local rootPlaceId = universePlaceInfo.universeRootPlaceId
		local placeId = universePlaceInfo.placeId

		if placeId then
			if featureContext == FeatureContext.PeopleList then
				analytics.reportViewProfileFromPeopleList(friend.id, index, rootPlaceId, VIEW_GAME_DETAILS_FROM_BUTTON)
			end

			if callbackOnOpenGameDetails then
				callbackOnOpenGameDetails()
			end
			guiService:BroadcastNotification(
				placeId,
				NotificationType.VIEW_GAME_DETAILS_ANIMATED
			)
		end
	end

	self.joinGameByUser = function()
		local analytics = self.props.analytics
		local friend = self.props.friend
		local index = self.props.index
		local universePlaceInfo = self.props.universePlaceInfo
		local callbackOnJoinGame = self.props.callbackOnJoinGame
		local featureContext = self.props.featureContext

		local placeId = universePlaceInfo.placeId
		local rootPlaceId = universePlaceInfo.universeRootPlaceId

		if callbackOnJoinGame then
			callbackOnJoinGame()
		end
		if featureContext == FeatureContext.PeopleList then
			analytics.reportPeopleListJoinGame(friend.id, index, placeId, rootPlaceId, friend.gameInstanceId)
		elseif featureContext == FeatureContext.PlacesList then
			analytics.reportJoinGameInPlacesList(friend.id, placeId, rootPlaceId, friend.gameInstanceId)
		end
		joinGame:ByUser(friend)
	end

end

function GameButton:render()
	local localization = self.props.localization
	local layoutOrder = self.props.layoutOrder
	local maxWidth = self.props.maxWidth
	local universePlaceInfo = self.props.universePlaceInfo
	local featureContext = self.props.featureContext
	local featureConfig = GameButtonConfigByFeature[featureContext]
							or GameButtonConfigByFeature[CONFIGURE_BY_FEATURE_DEFAULT_KEY]

	local displayJoinGameButton = false
	local displayBuyToPlayButton = false
	local gamePrice

	if universePlaceInfo then
		displayJoinGameButton = featureConfig.JoinGameEnabled and universePlaceInfo.isPlayable
		displayBuyToPlayButton = featureConfig.BuyToPlayButtonEnabled
									and universePlaceInfo.reasonProhibited == PlayabilityStatus.PurchaseRequired

		gamePrice = universePlaceInfo.price
	end

	local displayViewDetailsButton = featureConfig.ViewDetailsEnabled

	local backgroundColor = DEFAULT_BUTTON_COLOR
	local textColor = DEFAULT_BUTTON_TEXT_COLOR
	local textKey
	local onActivated
	local leftIcon

	if displayJoinGameButton then
		textKey = "Feature.Chat.Drawer.Join"
		onActivated = self.joinGameByUser
	elseif displayBuyToPlayButton then
		onActivated = self.openGameDetailsFromButton
		leftIcon = ROBUX_ICON
	elseif displayViewDetailsButton then
		backgroundColor = Constants.Color.WHITE
		textColor = Constants.Color.GRAY1
		textKey = "Feature.Chat.Drawer.ViewDetails"
		onActivated = self.openGameDetailsFromButton
	else -- Do not create button for an unidentifiable button type.
		return nil
	end

	local text = displayBuyToPlayButton and formatInteger(gamePrice) or localization:Format(textKey)

	return Roact.createElement(FitImageTextButton, {
		backgroundColor = backgroundColor,
		backgroundImage = ROUNDED_BUTTON,
		layoutOrder = layoutOrder,
		leftIconEnabled = (leftIcon ~= nil),
		leftIcon = leftIcon,
		maxWidth = maxWidth,
		minWidth = DEFAULT_BUTTON_WIDTH,
		text = text,
		textColor = textColor,
		onActivated = onActivated,
	})
end

GameButton = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			universePlaceInfo = state.UniversePlaceInfos[tostring(props.universeId)],
		}
	end
)(GameButton)

GameButton = RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
	guiService = AppGuiService,
	localization = RoactLocalization,
})(GameButton)

return GameButton