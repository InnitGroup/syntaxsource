local Enums = require(script.Parent.Enums)

local TestResult = {}
TestResult.__index = TestResult

function TestResult.getResult(testNode)
	local result = {
		testNode = testNode,
		successCount = 0,
		failureCount = 0,
		skippedCount = 0,
		errors = {}
	}

	local function callback(node, level)
		if node.type == Enums.Type.Describe then
			if not node.loadSuccess then
				result.failureCount = result.failureCount + 1
				table.insert(result.errors, node.errorMessage)
			end
		elseif node.type == Enums.Type.Step then
			if not node.testTouched then
				result.skippedCount = result.skippedCount + 1
			elseif node.testSuccess then
				result.successCount = result.successCount + 1
			else
				result.failureCount = result.failureCount + 1
				table.insert(result.errors, node.errorMessage)
			end
		end
	end
	testNode:visit(callback)
	return result
end

return TestResult