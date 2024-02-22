local Modules = game:GetService("CoreGui").RobloxGui.Modules
local HttpService = game:GetService("HttpService")
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local RoactServices = require(Modules.LuaApp.RoactServices)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local SocialMediaType = require(Modules.LuaApp.Enum.SocialMediaType)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)
local Common = Modules.Common
local Roact = require(Common.Roact)

-- TODO: replace with actual asset URIs ...
local ICONS = {
	[SocialMediaType.Twitter] = "rbxasset://textures/ui/LuaApp/icons/ic-twitter.png",
	[SocialMediaType.Facebook] = "rbxasset://textures/ui/LuaApp/icons/ic-facebook.png",
	[SocialMediaType.Discord] = "rbxasset://textures/ui/LuaApp/icons/ic-google.png",
	[SocialMediaType.RobloxGroup] = "rbxasset://textures/ui/LuaApp/icons/ic-google.png",
	[SocialMediaType.YouTube] = "rbxasset://textures/ui/LuaApp/icons/ic-google.png",
}

local SocialMediaButton = Roact.PureComponent:extend("SocialMediaButton")

local function getUriParams(socialType, url)
	-- Facebook needs a separate URI with a PageID to open it via native app
	-- Since we don't have that, just make it open in native browser instead
	-- Twitter uses separate URI to open it via native Twitter app
	if socialType == SocialMediaType.Twitter then
		local username = url:match("twitter.com/+([a-zA-Z0-9_]+)/*")
		if username ~= nil then
			return {
				app_uri = "twitter://user?screen_name=" .. username,
				web_uri = url,
			}
		end
	end
	return {
		app_uri = url,
		web_uri = url,
	}
end

function SocialMediaButton:init()
	self.onActivated = function()
		local socialType = self.props.socialType
		local socialUrl = self.props.socialUrl
		local params = getUriParams(socialType, socialUrl)
		local jsonString = HttpService:JSONEncode(params)
		self.props.guiService:BroadcastNotification(jsonString, NotificationType.OPEN_SOCIAL_MEDIA)
	end
end

function SocialMediaButton:render()
	local size = self.props.Size
	local socialType = self.props.socialType
	local layoutOrder = self.props.LayoutOrder

	return Roact.createElement(ImageSetButton, {
			Size = size,
			LayoutOrder = layoutOrder,
			Image = ICONS[socialType],
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			[Roact.Event.Activated] = self.onActivated,
		})
end

return RoactServices.connect({
	guiService = AppGuiService
})(SocialMediaButton)
