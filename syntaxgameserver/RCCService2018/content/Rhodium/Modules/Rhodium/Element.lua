local VirtualInput = require(script.Parent.VirtualInput)
local GuiService = game:GetService("GuiService")
local XPath = require(script.Parent.XPath)

local Element = {}
Element.__index = Element

function Element.new(argument)
	local self = {}
	if type(argument) == "string" then
		self.path = XPath.new(argument)
	elseif type(argument) == "table" and argument.__type == "XPath" then
		self.path = argument
	elseif type(argument) == "userdata" then
		self.rbxInstance = argument
	else
		error("invalid parameter for element")
	end

	setmetatable(self, Element)
	local scrollNums = self:_scrollingFrames(self.rbxInstance)

	self.isInScrollingFrame = scrollNums ~= 0

	return self
end

function Element:getAttribute(name)
	return self:getRbxInstance()[name]
end

function Element:getLocation()
	local guiOffset, _ = GuiService:GetGuiInset()
	return self:getRbxInstance().AbsolutePosition + guiOffset
end

function Element:getRect()
	local topLeft = self:getLocation()
	local bottomRight = self:getSize() + topLeft
	return Rect.new(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y)
end

function Element:getSize()
	return self:getRbxInstance().AbsoluteSize
end

function Element:getCenter()
	return self:getLocation()+self:getSize()/2
end

function Element:getText()
	return self:getRbxInstance().Text
end

function Element:isDisplayed()
	return self:getRbxInstance().Visiable
end

function Element:isSelected()
	return self:getRbxInstance().Selected
end

function Element:getRbxInstance()
	if self.rbxInstance == nil and self.path ~= nil then
		self.rbxInstance = self.path:waitForFirstInstance()
	end
	return self.rbxInstance
end

function Element:_override(class)
	for k, v in pairs(class) do
		if not k:find("^_") then
			self[k] = v
		end
	end
end

function Element:centralizeInstance()
	self:_centralizeInScrollingFrame(self:getRbxInstance())
end

function Element:centralize()
	local instance = self:getRbxInstance()
	if instance then
		self:centralizeInstance()
	else
		self:centralizeWithInfiniteScrolling()
	end
end

function Element:_scrollingFrames(instance)
	if instance == nil or instance == game then return 0 end
	local num = self:_scrollingFrames(instance.Parent)
	if instance.ClassName == "ScrollingFrame" then num = num + 1 end
	return num
end

function Element:_centralizeInScrollingFrame(child, parent)
	if child == game then return end
	parent = parent or child.Parent
	if parent == game then return end

	if parent.ClassName == "ScrollingFrame" then
		self:_centralizeInScrollingFrame(parent, parent.Parent)
		-- this is computational error tolerate.
		local threshold = 2

		--first scroll down to make child appears neas screen,
		--so that we can access child.AbsolutPosition property
		local isChildInScreen = false
		while not isChildInScreen do

			local prevChildPosition = child.AbsolutePosition
			local prevCanvasPosition = parent.CanvasPosition
			-- when scroll too much at one time, the element may move out side of screen immediately
			-- its AbsoluteSize will not update. limit to 300
			local scrollDistance = Vector2.new(math.min(300, parent.AbsoluteSize.X), math.min(300, parent.AbsoluteSize.Y))
			parent.CanvasPosition  = parent.CanvasPosition + scrollDistance
			wait()
			local deltaCanvas = (parent.CanvasPosition - prevCanvasPosition)
			local isBottom = deltaCanvas.Magnitude <= threshold
			local deltaChild = child.AbsolutePosition - prevChildPosition
			isChildInScreen = isBottom or deltaChild.Magnitude > threshold
		end
		--second scroll to centerize the child, at most twice.
		for _ = 1, 2 do
			local frameCenter = parent.AbsolutePosition + parent.AbsoluteSize/2
			local childCenter = child.AbsolutePosition + child.AbsoluteSize/2
			local delta = childCenter - frameCenter
			if delta.Magnitude <= threshold then break end
			parent.CanvasPosition  = parent.CanvasPosition + delta
			wait()
		end
	else
		self:_centralizeInScrollingFrame(child, parent.Parent)
	end
end

function Element:_scrollToFindInstance(scrollingFrame, absPath)
--	first reset scrollingFrame to zero position
	scrollingFrame.CanvasPosition = Vector2.new(0, 0)
	local width = scrollingFrame.AbsoluteSize.X
	local height = scrollingFrame.AbsoluteSize.Y

	local isBottom = false
	local instance
	local threshold = 2
	while not isBottom do
		wait(0.1)
		--if find the element then return
		instance = absPath:getFirstInstance()
		if instance then return instance end
		--scroll
		local oldPosition = scrollingFrame.CanvasPosition
		scrollingFrame.CanvasPosition = scrollingFrame.CanvasPosition + Vector2.new(math.min(width, 300), math.min(height, 300))
		--wait for content to refresh
		local delta = scrollingFrame.CanvasPosition - oldPosition
		isBottom = delta.Magnitude < threshold
		--if it is the bottom, then return not found
	end
	return nil
end

function Element:centralizeWithInfiniteScrolling()
	local instances, lastSeenIndex = self.path:getInstances()
	if #instances > 0 then self:centralizeInstance() end

	local lastSeenPath = self.path:copy()
	while #lastSeenPath.data > lastSeenIndex do
		table.remove(lastSeenPath.data)
	end

	local lastSeenInstance = lastSeenPath:getFirstInstance()
	local lastScrollingFrame = nil
	while true do
		if lastSeenInstance.ClassName == "ScrollingFrame" then
			lastScrollingFrame = lastSeenInstance
			break
		end
		lastSeenInstance = lastSeenInstance.Parent
		if lastSeenInstance == game then break end
	end
	if lastScrollingFrame == nil then return end
	if self:_scrollToFindInstance(lastScrollingFrame, self.path) == nil then return end
	self:_centralizeInScrollingFrame(self:getRbxInstance())
end

function Element:setPluginWindow()
	local window = self.rbxInstance:FindFirstAncestorOfClass("DockWidgetPluginGui")
	VirtualInput.setCurrentWindow(window)
end

function Element:click()
	self:centralize()
	self:setPluginWindow()
	VirtualInput.click(self:getCenter())
end

function Element:sendKey(key)
	self:setPluginWindow()
	VirtualInput.hitKey(key)
end

function Element:sendText(str)
	self:click()
	wait(0)
	VirtualInput.sendText(str)
end

function Element:tap()
	self:centralize()
	VirtualInput.tap(self:getCenter())
end

return Element
