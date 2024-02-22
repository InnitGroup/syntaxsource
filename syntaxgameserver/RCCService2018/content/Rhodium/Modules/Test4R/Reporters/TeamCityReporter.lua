local TestService = game:GetService("TestService")
local Enums = require(script.Parent.Parent.Enums)
local TeamCityReporter = {}

local function teamCityEscape(str)
	str = string.gsub(str, "([]|'[])","|%1")
	str = string.gsub(str, "\r", "|r")
	str = string.gsub(str, "\n", "|n")
	return str
end

local function teamCityEnterSuite(suiteName)
	return string.format("##teamcity[testSuiteStarted name='%s']", teamCityEscape(suiteName))
end

local function teamCityLeaveSuite(suiteName)
	return string.format("##teamcity[testSuiteFinished name='%s']", teamCityEscape(suiteName))
end

local function teamCityEnterCase(caseName)
	return string.format("##teamcity[testStarted name='%s']", teamCityEscape(caseName))
end

local function teamCityLeaveCase(caseName)
	return string.format("##teamcity[testFinished name='%s']", teamCityEscape(caseName))
end

local function teamCityFailCase(caseName, errorMessage)
	return string.format("##teamcity[testFailed name='%s' message='%s']",
		teamCityEscape(caseName), teamCityEscape(errorMessage))
end

local function reportNode(node, buffer, level)
	buffer = buffer or {}
	level = level or 0
	if not node.testTouched then
		return buffer
	end
	if node.type == Enums.Type.Describe then
		table.insert(buffer, teamCityEnterSuite(node.text))
		for _, child in ipairs(node.children) do
			reportNode(child, buffer, level + 1)
		end
		table.insert(buffer, teamCityLeaveSuite(node.text))
	elseif node.type == Enums.Type.Step then
		table.insert(buffer, teamCityEnterCase(node.text))
		if not node.testSuccess then
			table.insert(buffer, teamCityFailCase(node.text, node.errorMessage))
		end
		table.insert(buffer, teamCityLeaveCase(node.text))
	end
end

local function treeToString(testNode)
	local result = {}
	for _, child in ipairs(testNode.children) do
		reportNode(child, result)
	end
	return table.concat(result, "\n")
end

function TeamCityReporter.report(results)
	local resultBuffer = {
		"Test results:",
		treeToString(results.testNode),
		string.format(
			"%d passed, %d failed, %d skipped",
			results.successCount,
			results.failureCount,
			results.skippedCount
		)
	}
	print(table.concat(resultBuffer, "\n"))

	if results.failureCount > 0 then
		print(("%d test nodes reported failures."):format(results.failureCount))
	end

	if #results.errors > 0 then
		print("Errors reported by tests:\n")

		for _, message in ipairs(results.errors) do
			TestService:Error(message)
			print("")
		end
	end
end

return TeamCityReporter