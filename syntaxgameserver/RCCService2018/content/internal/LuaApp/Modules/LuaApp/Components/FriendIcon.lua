local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local ApiFetchUsersThumbnail = require(Modules.LuaApp.Thunks.ApiFetchUsersThumbnail)
local ChatConstants = require(Modules.LuaChat.Constants)
local Constants = require(Modules.LuaApp.Constants)
local UserModel = require(Modules.LuaApp.Models.User)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local FFlagLuaChatReplacePresenceIndicatorImages = settings():GetFFlag("LuaChatReplacePresenceIndicatorImages")
local FFlagLuaChatReplaceAvatarBorderAndBackground = settings():GetFFlag("LuaChatReplaceAvatarBorderAndBackground")

local IMAGE_DOT_INGAME = "LuaApp/icons/ic-green-dot"
local IMAGE_DOT_ONLINE = "LuaApp/icons/ic-blue-dot"
local IMAGE_DOT_STUDIO = "LuaApp/icons/ic-orange-dot"

local IMAGE_PROFILE_BORDER = "rbxasset://textures/ui/LuaApp/graphic/gr-profile-border-36x36.png"
local IMAGE_PROFILE_NO_BORDER = "rbxasset://textures/ui/LuaApp/graphic/gr-avatar-frame-36x36.png"
local IMAGE_PROFILE_DEFAULT = "LuaApp/icons/ic-profile"

local FriendIcon = Roact.PureComponent:extend("FriendIcon")

function FriendIcon:render()
	local getUserThumbnail = self.props.getUserThumbnail

	local user = self.props.user
	local dotSize = self.props.dotSize
	local itemSize = self.props.itemSize
	local layoutOrder = self.props.layoutOrder

	local isPresenceIndicatorEnabled = dotSize ~= nil

	local maskImage = FFlagLuaChatReplaceAvatarBorderAndBackground and IMAGE_PROFILE_NO_BORDER or IMAGE_PROFILE_BORDER
	local avatarBackgroundColor = FFlagLuaChatReplaceAvatarBorderAndBackground and Constants.Color.GRAY_AVATAR_BACKGROUND
									or Constants.Color.WHITE

	local presenceIndicatorSizeKey = ChatConstants:GetPresenceIndicatorSizeKey(dotSize)

	local imageFriend = nil
	local iconDot = not FFlagLuaChatReplacePresenceIndicatorImages and IMAGE_DOT_ONLINE or nil
	if user then
		if isPresenceIndicatorEnabled then
			if FFlagLuaChatReplacePresenceIndicatorImages then
				iconDot = ChatConstants.PresenceIndicatorImagesBySize[presenceIndicatorSizeKey][user.presence]
			else
				if user.presence == UserModel.PresenceType.IN_GAME then
					iconDot = IMAGE_DOT_INGAME
				elseif user.presence == UserModel.PresenceType.IN_STUDIO then
					iconDot = IMAGE_DOT_STUDIO
				end
			end
		end

		-- Find images for the friend portraits:
		if user.thumbnails and user.thumbnails.HeadShot
			and user.thumbnails.HeadShot.Size48x48 then
			imageFriend = user.thumbnails.HeadShot.Size48x48
		end

		if imageFriend == nil then
			imageFriend = IMAGE_PROFILE_DEFAULT
			getUserThumbnail(user.id)
		end
	end

	return Roact.createElement("Frame", {
		BackgroundColor3 = avatarBackgroundColor,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(0, itemSize, 0, itemSize),
	}, {
		Profile = Roact.createElement(ImageSetLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = imageFriend,
			Size = UDim2.new(0, itemSize, 0, itemSize),
			ZIndex = 1,
		}),

		Mask = Roact.createElement(ImageSetLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = maskImage,
			Size = UDim2.new(0, itemSize, 0, itemSize),
			ZIndex = 2,
		}),

		Dot = isPresenceIndicatorEnabled and Roact.createElement(ImageSetLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = iconDot,
			Position = UDim2.new(1, -dotSize, 1, -dotSize),
			Size = UDim2.new(0, dotSize, 0, dotSize),
			ZIndex = 3,
		}),
	})
end

FriendIcon = RoactRodux.UNSTABLE_connect2(
	nil,
	function(dispatch)
		return {
			getUserThumbnail = function(friendId)
				spawn(function()
					dispatch(ApiFetchUsersThumbnail(nil, { friendId },
						Constants.AvatarThumbnailRequests.FRIEND_CAROUSEL
					))
				end)
			end,
		}
	end
)(FriendIcon)

return FriendIcon