--to make ScriptAnalyzer Happy
describe = nil
step = nil
expect = nil
include = nil
-------------------------------
local Element = require(game.CoreGui.RobloxGui.Modules.Rhodium.Element)
local MobileAppElements = require(game.CoreGui.RobloxGui.Modules.RhodiumTest.Common.MobileAppElements)
local RobloxEventSimulator = require(game.CoreGui.RobloxGui.Modules.Rhodium.RobloxEventSimulator)

return function()
	describe.protected("Test Avatar", function()
		local function getProjectedPosition(position)
			local Camera = game.workspace.Camera
			local p = Camera.CFrame:pointToObjectSpace(position)
			local ly = math.tan(Camera.FieldOfView / 2 / 180 * math.pi)
			local aspect = Camera.ViewportSize.X / Camera.ViewportSize.Y
			local ry = (p.Y / -p.Z) / ly
			local rx = (p.X / -p.Z) / (ly * aspect)
			return Vector3.new(rx, ry, p.Z)
		end

		local function similar(v1, v2, limit)
			return (v1 - v2).Magnitude < limit
		end

		local function gotoAvatarPage()
-- in changelist 232625, they introduced a flag "useWebPageWrapperForGameDetails"
-- it will disable tool bar button for 1 second after click gamecard.
			wait(2)
-- in studio we can navigate to different page by click on bottom bar
-- in android devices, their is no lua bottom bar, we navigate by simulating roblox event.
			if game:GetService("RunService"):isStudio() then
				Element.new(MobileAppElements.avatarButton):click()
			else
				RobloxEventSimulator.gotoPage(RobloxEventSimulator.Enums.pageAvatarEditor)
			end
		end

		local function loadAvatarPage()
			step("click avatar button on tool bar for studio", gotoAvatarPage)
			step("should have character ", function()
				assert(MobileAppElements.character:waitForFirstInstance(), "did not find character")
			end)
			step("should have r6 r15 switch ", function()
				assert(MobileAppElements.r6r15Switch:waitForFirstInstance(), "did not find r6 r15 switch")
			end)
			step("should have full screen button", function()
				assert(MobileAppElements.fullViewButton:waitForFirstInstance(), "did not find full screen button")
			end)
			step("should have tab button", function()
				assert(MobileAppElements.selectTabButton:waitForFirstInstance(), "did not find tab button")
			end)
			step("should have page title should be \"Avatar\"", function()
				assert(MobileAppElements.pageName:waitForFirstInstance().Text == "Avatar", "page name is not Avatar")
				wait(1)
			end)
		end

		local function fullViewButtonInScreen()
			local button = MobileAppElements.fullViewButton:waitForFirstInstance()
			assert(button)
			local topLeftPos = button.AbsolutePosition()
			local bottomRightPos = topLeftPos + button.AbsoluteSize()
			local screenSize = game.workspace.Camera.ViewportSize
			local minX, minY, maxX, maxY = 0, 0, screenSize.X, screenSize.Y

			local topBar = MobileAppElements.topBar:waitForFirstInstance()
			assert(topBar)
			minY = math.max(minY, topBar.AbsolutePosition.Y + topBar.AbsoluteSize.Y)

			local rightFrame = MobileAppElements.rightFrame:waitForFirstInstance()
			assert(rightFrame)
			maxX = math.min(maxX, rightFrame.AbsolutePosition.X)

			local bottomBar = MobileAppElements.topBarContent:waitForFirstInstance()
			assert(bottomBar)
			maxY = math.min(maxY, bottomBar.AbsolutePosition.Y)

			assert(topLeftPos.X > minX)
			assert(topLeftPos.Y > minY)
			assert(bottomRightPos.X < maxX)
			assert(bottomRightPos.Y < maxY)
		end

		local function testFullViewButtonLandScape()
			local button = MobileAppElements.fullViewButton:waitForFirstInstance()
			local rightFrame = MobileAppElements.rightFrame:waitForFirstInstance()
			assert(button)
			assert(rightFrame)

			fullViewButtonInScreen()
			assert(similar(rightFrame.AbsolutePostion.X), game.workspace.Camera.ViewportSize.X / 2, 100)
			local element = Element.new(button)

			element:click()
			wait(2) -- wait to finish animation
			fullViewButtonInScreen()
			assert(similar(rightFrame.AbsolutePostion.X), game.workspace.Camera.ViewportSize.X, 20)

			element:click()
			wait(2) -- wait to finish animation
			fullViewButtonInScreen()
			assert(similar(rightFrame.AbsolutePostion.X), game.workspace.Camera.ViewportSize.X / 2, 100)

		end

		local function waitForCloseButton()
			return MobileAppElements.closeTabButton:waitForInstance()
		end

		local function waitForCloseButtonDisappear()
			return MobileAppElements.closeTabButton:waitForDisappear()
		end

		local function instanceInScreen(instance)
			local pos = getProjectedPosition(instance.Position)
			return((pos.Z < 0)
			and (pos.X > -1 and pos.X < 1)
			and (pos.Y > -1 and pos.Y < 1))
		end

		local function checkAvatarInScreen()
			local character = MobileAppElements.character:waitForFirstInstance()
			assert(character)
			local rootPart = character.HumanoidRootPart
			local head = character.Head
			assert(rootPart)
			assert(head)
			assert(instanceInScreen(rootPart), "avatar is not inside of screen")
		end

		local function gotoTab(tab)
			assert(waitForCloseButtonDisappear() == true)
			Element.new(MobileAppElements.selectTabButton):click()
			Element.new(tab):click()
			assert(waitForCloseButtonDisappear() == true)
		end

		local function forEachTab(tab, subTabs)
			step("should go to that tab after click", function()
				gotoTab(tab)
			end)

			step("tab should be yellow after click and character should be aways in screen", function()
				for name, path in pairs(subTabs) do
					print(string.format("testing avatar tab %q", name))
					local instance
					instance = path:waitForFirstInstance()
					assert(instance)
					Element.new(instance):click()
					wait(0.2)
					assert(instance.BackgroundColor3.r ~= 255)
					checkAvatarInScreen()
				end
			end)
		end

		local function testAllTabs_Portrait()
			describe.protected("all \"recent\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs_portrait.recentButton, MobileAppElements.recentTabs_portrait)
			end)
			describe.protected("all \"clothing\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs_portrait.clothingButton, MobileAppElements.clothingTabs_portrait)
			end)
			describe.protected("all \"body\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs_portrait.bodyButton, MobileAppElements.bodyTabs_portrait)
			end)
			describe.protected("all \"anomation\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs_portrait.animationButton, MobileAppElements.animationTabs_portrait)
			end)
			describe.protected("all \"outfits\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs_portrait.outfitsButton, MobileAppElements.outfitsTabs_portrait)
			end)
		end

		local function testAllTabs()
			describe.protected("all \"recent\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs.recentButton, MobileAppElements.recentTabs)
			end)
			describe.protected("all \"clothing\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs.clothingButton, MobileAppElements.clothingTabs)
			end)
			describe.protected("all \"body\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs.bodyButton, MobileAppElements.bodyTabs)
			end)
			describe.protected("all \"anomation\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs.animationButton, MobileAppElements.animationTabs)
			end)
			describe.protected("all \"outfits\" tabs should work", function()
				forEachTab(MobileAppElements.groupTabs.outfitsButton, MobileAppElements.outfitsTabs)
			end)
		end

		local function isR15()
			local switchFrame = MobileAppElements.r6r15SwitchFrame:waitForFirstInstance()
			assert(switchFrame)
			local switch = MobileAppElements.r6r15Switch:waitForFirstInstance()
			assert(switch)
			local frameCenter = Element.new(switchFrame):getCenter()
			local switchCenter = Element.new(switch):getCenter()
			return switchCenter.X > frameCenter.X
		end

		local function switchToR15()
			if isR15() == true then return end
			Element.new(MobileAppElements.r6r15Switch):click()
			wait(1)	-- it takes a long time to switch
			assert(isR15())
		end

		local function switchToR6()
			if isR15() == false then return end
			Element.new(MobileAppElements.r6r15Switch):click()
			wait(1)	-- it takes a long time to switch
			assert(not isR15())
		end

		local function switchCharacter()
			if isR15() == true then
				switchToR6()
			else
				switchToR15()
			end
		end

		local function switchTest()
			if isR15() == true then
				switchToR6()
				switchToR15()
			else
				switchToR15()
				switchToR6()
			end
			print("current avatar style is " .. (isR15() and "R15" or "R6"))
		end

		describe("should be able to goto avatar page by navigation button", loadAvatarPage)
		step("switch should work", switchTest)
		describe.protected("test all tabs", testAllTabs)
-- the R6 avatar can move out of screen in studio mode.	
		if false then
			step("should switch to another character", switchCharacter)
			describe.protected("test all tabs after character switched", testAllTabs)
			step("should switch back to old character", switchCharacter)
		end
	end)
end