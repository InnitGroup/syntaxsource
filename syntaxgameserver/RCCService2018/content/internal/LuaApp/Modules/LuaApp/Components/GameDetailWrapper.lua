local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local WebViewPageWrapper = require(Modules.LuaApp.Components.WebViewPageWrapper)

return function(props)
	local isVisible = props.isVisible
	local placeId = props.placeId

	return Roact.createElement(WebViewPageWrapper, {
		isVisible = isVisible,
		notificationData = tostring(placeId),
		notificationType = NotificationType.VIEW_GAME_DETAILS,
	})
end