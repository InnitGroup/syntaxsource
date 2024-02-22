--to make ScriptAnalyzer Happy
describe = nil
step = nil
expect = nil
include = nil
-------------------------------
local Element = require(game.CoreGui.RobloxGui.Modules.Rhodium.Element)
local MobileAppElements = require(game.CoreGui.RobloxGui.Modules.RhodiumTest.Common.MobileAppElements)
local VirtualInput = require(game.CoreGui.RobloxGui.Modules.Rhodium.VirtualInput)

return function()
	step("mouse wheel should be able to scroll the vertical scrollframe", function()
		local element = Element.new(MobileAppElements.verticalScrollingFrame)
		wait(0.5)
		VirtualInput.mouseWheel(element:getCenter(), 2)
		wait(0.5) -- wait for one frame to update GUIs.
		assert(MobileAppElements.verticalScrollingFrame:waitForFirstInstance().CanvasPosition.Y > 0)
	end)
end