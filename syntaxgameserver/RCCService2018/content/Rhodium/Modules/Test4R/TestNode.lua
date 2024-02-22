local TestNode = {}
TestNode.__index = TestNode

function TestNode.new(text, type, modifiers)
	local self = {
		parent = nil,
		children = {},

		text = text,
		type = type,
		modifiers = modifiers or {},
		callback = nil,
		testSuccess = true,
		testTouched = false,
		loadSuccess = true,
		errorMessage = "",
	}
	setmetatable(self, TestNode)
	return self
end

function TestNode:addChild(node)
	node.parent = self
	table.insert(self.children, node)
end

function TestNode:visit(callback, level)
	level = level or 0
	callback(self, level);
	for _, child in ipairs(self.children) do
		child:visit(callback, level + 1)
	end
end

function TestNode:isRoot()
	return self.parent == nil
end

return TestNode