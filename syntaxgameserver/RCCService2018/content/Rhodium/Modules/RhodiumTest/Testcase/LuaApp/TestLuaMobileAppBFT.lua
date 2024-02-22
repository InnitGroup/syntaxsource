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

local AllTabsSwitch = require(script.Parent.Modules.BVT.AllTabsSwitch)


local function test()
	describe.protected("Mobile Place Rhodium Basic Functional Test", function()
		--include(YourFunctionalTest)
	end)
end

function run()
	startTest(test, reporter)
end
return run
