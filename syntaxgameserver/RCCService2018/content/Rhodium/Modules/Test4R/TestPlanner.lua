local Enums = require(script.Parent.Enums)
local TestNode = require(script.Parent.TestNode)
local createModdableFunction = require(script.Parent.createModdableFunction)

local TestPlanner = {}
TestPlanner.__index = TestPlanner

local function doPlan(currentNode, method, env)
	local currentEnv = getfenv(method)
	for key, value in pairs(env) do
		currentEnv[key] = value
	end

	local success, result = xpcall(method, function(err)
		return err .. "\n" .. debug.traceback()
	end)

	if not success then
		currentNode.loadSuccess = false
		currentNode.errorMessage = result
	end
end

local validModifiers = {
	protected = Enums.Modifier.Protect,
	skipped = Enums.Modifier.Skip,
}

local function createEnv(currentNode)
	local function describe(modifiers, text, callback)
		local testNode = TestNode.new(text, Enums.Type.Describe, modifiers)
		currentNode:addChild(testNode)
		currentNode = testNode
		local success, result = xpcall(callback, function(err)
			return err .. "\n" .. debug.traceback()
		end)
		if not success then
			testNode.loadSuccess = false
			testNode.errorMessage = result
		end
		currentNode = currentNode.parent
	end

	local function step(modifiers, text, callback)
		local testNode = TestNode.new(text, Enums.Type.Step, modifiers)
		testNode.callback = callback
		currentNode:addChild(testNode)
	end

	local env = {}
	env.describe = createModdableFunction(validModifiers, describe)
	env.step = createModdableFunction(validModifiers, step)
	env.skip = function()
		currentNode.modifiers[Enums.Modifier.Skip] = true
	end
	env.include = function(method)
		doPlan(currentNode, method, env)
	end
	return env
end

function TestPlanner.plan(method)
	local currentNode = TestNode.new("Root", Enums.Type.Describe)
	local env = createEnv(currentNode)
	doPlan(currentNode, method, env)

	return currentNode
end

return TestPlanner