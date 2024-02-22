local PageNavigation = {}
PageNavigation.__index = PageNavigation

local Element = require(game.CoreGui.RobloxGui.Modules.Rhodium.Element)
local MobileAppElements = require(game.CoreGui.RobloxGui.Modules.RhodiumTest.Common.MobileAppElements)
local RobloxEventSimulator = require(game.CoreGui.RobloxGui.Modules.Rhodium.RobloxEventSimulator)

function PageNavigation:gotoAvatarPage()
	-- in changelist 232625, they introduced a flag "useWebPageWrapperForGameDetails"
	-- it will disable tool bar button for 1 second after click gamecard.
	wait(1.5)
	-- in studio we can navigate to different page by click on bottom bar
	-- in android devices, their is no lua bottom bar, we navigate by simulating roblox event.
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.avatarButton):click()
	else
		RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageAvatarEditor)
	end
	wait(0.5)
end

function PageNavigation:gotoHomePage()
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.homeButton):click()
	else
		RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageHome)
	end
	wait(0.5)
end

function PageNavigation:gotoChatPage()
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.chatButton):click()
	else
		RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageChat)
	end
	wait(0.5)
end

function PageNavigation:gotoGamesPage()
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.gamesButton):click()
	else
		RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageGames)
	end
	wait(0.5)
end

function PageNavigation:gotoMorePage()
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.moreButton):click()
	else
		RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageMore)
	end
	wait(0.5)
end

function PageNavigation:gotoCatalogPage()
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.catalogButton):click()
	else
		--TODO
		--RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageCatalog)
	end
	wait(0.5)
end

function PageNavigation:gotoFriendPage()
	if game:GetService("RunService"):isStudio() then
		Element.new(MobileAppElements.friendsButton):click()
	else
		--TODO
		--RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageFriends)
	end
	wait(0.5)
end

return PageNavigation
