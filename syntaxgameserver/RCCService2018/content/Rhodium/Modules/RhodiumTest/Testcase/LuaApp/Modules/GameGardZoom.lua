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
	describe.protected("game Button should zoom out on its center point when touch and hold it, and resume after release",
		function()
			local myRecentEntry =
				MobileAppElements.filterBy(MobileAppElements.gameCategoryEntry, MobileAppElements.getGameCategoryDetail().title,
				"Text", "My Recent"
			)

			local recentInstance = nil
			local gameFrame = nil
			local gameButton = nil

			local element = nil
			local center = nil

			local oldFrameSize = nil
			local oldGameButtonSize = nil
			local oldGameButtonCenter = nil

			step("should find the carousel and game buttons", function()
				recentInstance = myRecentEntry:waitForFirstInstance()
				expect(recentInstance).to.be.ok()
				gameFrame = recentInstance.Carousel:waitForChild("1")
				gameButton = gameFrame.GameButton
				element = Element.new(gameButton)
				--bring it in screen, if not.
				element:centralize()
				wait(0.5)

				center = element:getCenter()
				oldFrameSize = gameFrame.AbsoluteSize
				oldGameButtonSize = gameButton.AbsoluteSize
				oldGameButtonCenter = element:getCenter()
			end)

			local function similar(v1, v2, limit)
				return (v1 - v2).Magnitude < limit
			end

			step("game Button should zoom out on its center point when touch and hold it", function()
				VirtualInput.mouseLeftDown(center)
				VirtualInput.touchStart(center)
				wait(1) -- wait for animation finish
				local downFrameSize = gameFrame.AbsoluteSize
				local downGameButtonSize = gameButton.AbsoluteSize
				local downGameButtonCenter = Element.new(gameButton):getCenter()

				assert(similar(oldFrameSize, downFrameSize, 2))
				assert(oldGameButtonSize.Magnitude > downGameButtonSize.Magnitude)
				assert(not similar(oldGameButtonSize, downGameButtonSize, 4))
				assert(similar(oldGameButtonCenter, downGameButtonCenter, 2))

				VirtualInput.mouseLeftUp(center)
				VirtualInput.touchStop(center)
			end)

			step("game Button should resume after release", function()
				wait(1) -- wait for animation finish
				local upFrameSize = gameFrame.AbsoluteSize
				local upGameButtonSize = gameButton.AbsoluteSize

				local upGameButtonCenter = Element.new(gameButton):getCenter()

				assert(similar(oldFrameSize, upFrameSize, 2))
				assert(similar(oldGameButtonSize, upGameButtonSize, 2))
				assert(similar(oldGameButtonCenter, upGameButtonCenter, 2))
			end)
	end)
end
