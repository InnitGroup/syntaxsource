local TestPlanner = require(script.Parent.TestPlanner)
local TestRunner = require(script.Parent.TestRunner)
local TestResult = require(script.Parent.TestResult)

local function startTest(method, reporter)
	local testNode = TestPlanner.plan(method)
	testNode = TestRunner.run(testNode)
	local result = TestResult.getResult(testNode)
	reporter.report(result)
end

return startTest