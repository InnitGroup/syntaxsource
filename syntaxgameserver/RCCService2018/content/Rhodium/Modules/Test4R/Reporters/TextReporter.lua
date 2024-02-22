local TestService = game:GetService("TestService")
local TextReporter = {}
local INDENT = (" "):rep(3)

local function treeToString(testNode)
	local result = {}

	local function callback(node, level)
		local symbol = node.testTouched and (node.testSuccess and "+" or "-") or "~"
		local line = ("%s[%s] %s"):format(
			INDENT:rep(level),
			symbol,
			node.text
		)
		table.insert(result, line)
	end

	testNode:visit(callback)
	return table.concat(result, "\n")
end

function TextReporter.report(results)
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

return TextReporter