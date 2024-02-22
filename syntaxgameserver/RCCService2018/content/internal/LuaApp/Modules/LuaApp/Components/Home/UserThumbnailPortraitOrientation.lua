local Modules = game:GetService("CoreGui").RobloxGui.Modules

local FlagSettings = require(Modules.LuaApp.FlagSettings)
local Roact = require(Modules.Common.Roact)
local User = require(Modules.LuaApp.Models.User)
local UserThumbnail = require(Modules.LuaApp.Components.UserThumbnail)

local isPeopleListV1Enabled = FlagSettings.IsPeopleListV1Enabled()

local MEASUREMENT_CONSTANTS = {
	THUMBNAIL_SIZE = 84,
	MASK_IMAGE = "rbxasset://textures/ui/LuaApp/graphic/gr-avatar mask-84x84.png",
}

MEASUREMENT_CONSTANTS.USERNAME = {
	TEXT_FONT_SIZE = 18,
	TEXT_LINE_HEIGHT = 18,
	TEXT_TOP_PADDING = 3,
}

MEASUREMENT_CONSTANTS.PRESENCE = {
	TEXT_FONT_SIZE = 15,
	TEXT_LINE_HEIGHT = 15,
	TEXT_TOP_PADDING = 3,

	ICONS = {
		[User.PresenceType.ONLINE] = "LuaApp/icons/ic-blue-dot",
		[User.PresenceType.IN_GAME] = "LuaApp/icons/ic-green-dot",
		[User.PresenceType.IN_STUDIO] = "LuaApp/icons/ic-orange-dot",
	},

	BORDER_DIAMETER = 14,
	ICON_OFFSET = 5,
	ICON_SIZE = 10,
}

MEASUREMENT_CONSTANTS.PRESENCE_TEXT_HEIGHT = isPeopleListV1Enabled and MEASUREMENT_CONSTANTS.PRESENCE.TEXT_TOP_PADDING
		+ MEASUREMENT_CONSTANTS.PRESENCE.TEXT_LINE_HEIGHT or 0

local UserThumbnailPortraitOrientation = Roact.PureComponent:extend("UserThumbnailPortraitOrientation")

function UserThumbnailPortraitOrientation.size()
	return MEASUREMENT_CONSTANTS.THUMBNAIL_SIZE
end

function UserThumbnailPortraitOrientation.height()
	return MEASUREMENT_CONSTANTS.THUMBNAIL_SIZE
		+ MEASUREMENT_CONSTANTS.USERNAME.TEXT_TOP_PADDING
		+ MEASUREMENT_CONSTANTS.USERNAME.TEXT_LINE_HEIGHT
		+ MEASUREMENT_CONSTANTS.PRESENCE_TEXT_HEIGHT
end

function UserThumbnailPortraitOrientation:render()
	local user = self.props.user
	local highlightColor = self.props.highlightColor
	local thumbnailType = self.props.thumbnailType

	return Roact.createElement(UserThumbnail, {
		measurements = MEASUREMENT_CONSTANTS,
		user = user,
		highlightColor = highlightColor,
		thumbnailType = thumbnailType,
	})
end

return UserThumbnailPortraitOrientation