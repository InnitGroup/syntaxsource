local CorePackages = game:GetService("CorePackages")
local Enums = require(script.Parent.Enums)
local Expectation = require(CorePackages.TestEZ).Expectation

local TestRunner = {}

local testEnv = {expect = Expectation.new}

local function assign(to, from)
	for key, value in pairs(from) do
		to[key] = value
	end
end

local function setTestEnv(method)
	assign(getfenv(method), testEnv)
end

local function run(testNode, protectionState)
	if testNode.modifiers[Enums.Modifier.Skip] then
		return
	end
	testNode.testTouched = true

	if testNode.modifiers[Enums.Modifier.Protect] then
		-- Update the protection value so that descendant nodes will reference this value
		protectionState = {
			failedNode = protectionState.failedNode
		}
	end

	if testNode.type == Enums.Type.Describe then
		for _, child in ipairs(testNode.children) do
			run(child, protectionState)
		end
	elseif testNode.type == Enums.Type.Step then
		if protectionState and protectionState.failedNode then
			testNode.testSuccess = false
			testNode.errorMessage = string.format(
				"%q failed without execution, because %q failed",
				testNode.text, protectionState.failedNode.text
			)
		else
			setTestEnv(testNode.callback)
			local success, result = pcall(testNode.callback)
			if not success then
				testNode.testSuccess = false
				testNode.errorMessage = result
				protectionState.failedNode = testNode
			end
		end
	end

	if not testNode.loadSuccess then
		testNode.errorMessage = string.format("Error during planning: %q\n%s", testNode.text, testNode.errorMessage)
		testNode.testSuccess = false
	end

	if testNode.parent and not testNode.testSuccess then
		testNode.parent.testSuccess = false
	end
end

function TestRunner.run(testNode)
	-- protected by default, which means when one step failed, all steps after will be skipped by default
	run(testNode, {
		failedNode = nil
	})
	return testNode
end

return TestRunner