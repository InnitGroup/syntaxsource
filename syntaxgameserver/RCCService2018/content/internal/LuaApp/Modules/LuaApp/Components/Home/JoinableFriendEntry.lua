local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactAnalyticsHomePage = require(Modules.LuaApp.Services.RoactAnalyticsHomePage)
local RoactLocalization = require(Modules.LuaApp.Services.RoactLocalization)

local Constants = require(Modules.LuaApp.Constants)
local FitImageTextButton = require(Modules.LuaApp.Components.FitImageTextButton)

local User = require(Modules.LuaApp.Models.User)
local FriendIcon = require(Modules.LuaApp.Components.FriendIcon)
local joinGame = require(Modules.LuaChat.Utils.joinGame)

local ROUNDED_BUTTON = "LuaApp/9-slice/input-default"

local FONT_SIZE = 22
local FONT = Enum.Font.SourceSans

local JOIN_BUTTON_HEIGHT = 32
local JOIN_BUTTON_WIDTH_MIN = 60

local AVATAR_SIZE = Constants.PlacesList.ContextualMenu.AvatarSize
local HORIZONTAL_INNER_PADDING = Constants.PlacesList.ContextualMenu.HorizontalInnerPadding
local HORIZONTAL_OUTER_PADDING = Constants.PlacesList.ContextualMenu.HorizontalOuterPadding

local USERNAME_POSITION_X = HORIZONTAL_OUTER_PADDING
							+ AVATAR_SIZE
							+ HORIZONTAL_INNER_PADDING

local JoinableFriendEntry = Roact.PureComponent:extend("JoinableFriendEntry")

JoinableFriendEntry.defaultProps = {
	layoutOrder = 0,
}

function JoinableFriendEntry:init()
	self.state = {
		joinButtonWidth = JOIN_BUTTON_WIDTH_MIN,
	}
	self.joinButtonRef = Roact.createRef()

	self.onJoinButtonActivated = function()
		local analytics = self.props.analytics
		local user = self.props.user
		local universePlaceInfo = self.props.universePlaceInfo

		local placeId = universePlaceInfo.placeId
		local rootPlaceId = universePlaceInfo.universeRootPlaceId

		analytics.reportJoinGameInPlacesList(user.id, placeId, rootPlaceId, user.gameInstanceId)

		joinGame:ByUser(user)
	end

	self.updateJoinButtonWidth = function()
		local buttonRef = self.joinButtonRef.current
		if buttonRef then
			local joinButtonWidth = buttonRef.AbsoluteSize.X
			self:setState({
				joinButtonWidth = joinButtonWidth,
			})
		end
	end

end

function JoinableFriendEntry:didMount()
	self.updateJoinButtonWidth()
end

function JoinableFriendEntry:render()
	local user = self.props.user
	local upToDateUser = self.props.upToDateUser
	local layoutOrder = self.props.layoutOrder
	local entryHeight = self.props.entryHeight
	local entryWidth = self.props.entryWidth
	local universeId = self.props.universeId
	local localization = self.props.localization
	local universePlaceInfo = self.props.universePlaceInfo
	local joinButtonWidth = self.state.joinButtonWidth
	local joinButtonMaxWidth
	local isPlayable = universePlaceInfo and universePlaceInfo.isPlayable or false

	if entryWidth then
		local maxWidth = (entryWidth - HORIZONTAL_INNER_PADDING) / 2 - HORIZONTAL_INNER_PADDING
		joinButtonMaxWidth = math.max(maxWidth, JOIN_BUTTON_WIDTH_MIN)
	else
		joinButtonMaxWidth = JOIN_BUTTON_WIDTH_MIN
	end

	local usernameWidthOffset = HORIZONTAL_OUTER_PADDING * 2
								+ AVATAR_SIZE
								+ HORIZONTAL_INNER_PADDING * 2
								+ joinButtonWidth

	local onJoinButtonActivated
	local joinButtonColor

	if upToDateUser.presence == User.PresenceType.IN_GAME
		and tostring(upToDateUser.universeId) == tostring(universeId)
		and isPlayable then
		onJoinButtonActivated = self.onJoinButtonActivated
		joinButtonColor = Constants.Color.GREEN_PRIMARY
	else
		onJoinButtonActivated = nil
		joinButtonColor = Constants.Color.GREEN_DISABLED
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(0, entryWidth, 0, entryHeight),
		BackgroundColor3 = Constants.Color.WHITE,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		AvatarHolder = Roact.createElement("Frame", {
			Size = UDim2.new(0, AVATAR_SIZE, 0, AVATAR_SIZE),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, HORIZONTAL_OUTER_PADDING, 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Avatar = Roact.createElement(FriendIcon, {
				user = upToDateUser,
				itemSize = AVATAR_SIZE,
				layoutOrder = 1,
			}),
		}),
		Username = Roact.createElement("Frame", {
			Size = UDim2.new(1, -usernameWidthOffset, 1, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, USERNAME_POSITION_X, 0.5, 0),
		}, {
			Text = Roact.createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				Text = user.name,
				TextSize = FONT_SIZE,
				Font = FONT,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
		JoinButton = Roact.createElement(FitImageTextButton, {
			backgroundColor = joinButtonColor,
			backgroundImage = ROUNDED_BUTTON,
			leftIconEnabled = false,
			height = JOIN_BUTTON_HEIGHT,
			minWidth = JOIN_BUTTON_WIDTH_MIN,
			maxWidth = joinButtonMaxWidth,
			text = localization:Format("Feature.Chat.Drawer.Join"),
			textColor = Constants.Color.WHITE,
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -HORIZONTAL_OUTER_PADDING, 0.5, 0),
			onActivated = onJoinButtonActivated,
			[Roact.Ref] = self.joinButtonRef,
			[Roact.Change.AbsoluteSize] = self.updateJoinButtonWidth,
		}),
	})
end

JoinableFriendEntry = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local userId = props.user.id
		local universeId = props.universeId

		return {
			upToDateUser = state.Users[userId],
			universePlaceInfo = state.UniversePlaceInfos[universeId],
		}
	end
)(JoinableFriendEntry)

JoinableFriendEntry = RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
	localization = RoactLocalization,
})(JoinableFriendEntry)

return JoinableFriendEntry