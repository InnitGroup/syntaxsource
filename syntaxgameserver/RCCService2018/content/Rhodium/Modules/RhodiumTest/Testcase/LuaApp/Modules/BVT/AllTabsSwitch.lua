--to make ScriptAnalyzer Happy
describe = nil
step = nil
expect = nil
include = nil
-------------------------------
local PageNavigation = require(game.CoreGui.RobloxGui.Modules.RhodiumTest.Common.PageNavigation)

return function()
	step("Switching pages", function()
		PageNavigation.gotoGamesPage()
		PageNavigation.gotoCatalogPage()
		PageNavigation.gotoAvatarPage()
		PageNavigation.gotoFriendPage()
		PageNavigation.gotoChatPage()
		PageNavigation.gotoMorePage()
		PageNavigation.gotoHomePage()
	end)
end