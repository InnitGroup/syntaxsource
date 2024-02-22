local VIM = game:GetService("VirtualInputManager")
local RobloxEventSimulator = {}
RobloxEventSimulator.__index = RobloxEventSimulator

function RobloxEventSimulator.sendEvent(namespace, detail, detailType)
	VIM:sendRobloxEvent(namespace, detail, detailType)
end

function RobloxEventSimulator.gotoPage(page)
	RobloxEventSimulator.sendEvent("Navigations", string.format("{\"appName\":\"%s\"}", page), "Destination")
end

RobloxEventSimulator.Enums = {
	pageHome = "Home",
	pageGames = "Games",
	pageAvatarEditor = "AvatarEditor",
	pageChat = "Chat",
	pageMore = "More",
}

return RobloxEventSimulator