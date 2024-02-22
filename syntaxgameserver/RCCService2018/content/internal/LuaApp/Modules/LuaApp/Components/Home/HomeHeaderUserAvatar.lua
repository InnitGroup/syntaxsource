local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Common = Modules.Common
local LuaApp = Modules.LuaApp

local Constants = require(LuaApp.Constants)
local Roact = require(Common.Roact)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)

local PROFILE_PICTURE_SIZE = 150
local THUMBNAIL_IMAGE_SIZE_ENUM = Constants.AvatarThumbnailSizes.Size150x150
local DEFAULT_THUMBNAIL_ICON = "rbxasset://textures/ui/LuaApp/graphic/ph-avatar-portrait.png"
local OVERLAY_IMAGE_BIG = "rbxasset://textures/ui/LuaApp/graphic/gr-profile-150x150px.png"

local HomeHeaderUserAvatar = Roact.PureComponent:extend("HomeHeaderUserAvatar")

function HomeHeaderUserAvatar:render()
	local localUserModel = self.props.localUserModel
	local thumbnailType = self.props.thumbnailType
	local onActivated = self.props.onActivated

	return Roact.createElement(ImageSetLabel, {
		Size = UDim2.new(0, PROFILE_PICTURE_SIZE, 0, PROFILE_PICTURE_SIZE),
		BackgroundColor3 = Constants.Color.WHITE,
		BorderSizePixel = 0,
		Image = localUserModel and localUserModel.thumbnails and localUserModel.thumbnails[thumbnailType]
			and localUserModel.thumbnails[thumbnailType][THUMBNAIL_IMAGE_SIZE_ENUM] or DEFAULT_THUMBNAIL_ICON,
	}, {
		MaskFrame = Roact.createElement(ImageSetButton, {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = OVERLAY_IMAGE_BIG,
			[Roact.Event.Activated] = onActivated,
		}),
	})
end

return HomeHeaderUserAvatar