--to make ScriptAnalyzer Happy
describe = nil
step = nil
expect = nil
include = nil
-------------------------------

local Test = game.CoreGui.RobloxGui.Modules.Test4R
local startTest = require(Test.startTest)
local TextReporter = require(Test.Reporters.TextReporter)
local TeamCityReporter = require(Test.Reporters.TeamCityReporter)
local reporter = _G["TEAMCITY"] and TeamCityReporter or TextReporter

local HomePageLoad = require(script.Parent.Modules.HomePageLoad)
local HomePageScroll = require(script.Parent.Modules.HomePageScroll)
local GameGardZoom = require(script.Parent.Modules.GameGardZoom)
local NavigateToAllGameLists = require(script.Parent.Modules.NavigateToAllGameLists)
local AvatarTest = require(script.Parent.Modules.AvatarTest)
local AllTabsSwitch = require(script.Parent.Modules.BVT.AllTabsSwitch)


local function test()
	describe.protected("Mobile Place Rhodium Test", function()
		include(AllTabsSwitch)
		include(HomePageLoad)
		include(HomePageScroll)
		include(GameGardZoom)
-- gametest1 do not have to much games for testting.
--		include(NavigateToAllGameLists)
		include(AvatarTest)
	end)
end

function run()
	startTest(test, reporter)
end
return run
