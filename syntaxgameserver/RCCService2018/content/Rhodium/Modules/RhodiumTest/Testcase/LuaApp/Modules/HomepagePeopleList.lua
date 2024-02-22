describe = nil
step = nil
expect = nil
include = nil

local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Constants = require(Modules.LuaApp.Constants)
local Element = require(Modules.Rhodium.Element)
local MobileAppElements = require(Modules.RhodiumTest.Common.MobileAppElements)
local PageNavigation = require(Modules.RhodiumTest.Common.PageNavigation)
local VirtualInput = require(Modules.Rhodium.VirtualInput)

local ADD_FRIEND_BUTTON_HEIGHT = 132
local FRIEND_CAROUSEL = {
	Username_Font = Enum.Font.SourceSansLight,
	Username_TextColor = Constants.Color.GRAY1,
	Phone = {
		WIDTH = 115,
		HEIGHT = 153,
		ICON_SIZE = 84,
	},
	Tablet = {
		WIDTH = 105,
		HEIGHT = 161,
		ICON_SIZE = 90,
	}
}

return function()
	local ADD_FRIENDS_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-add.png"
	local ADD_FRIENDS_ICON_PRESSED = "rbxasset://textures/ui/LuaApp/icons/ic-add-down.png"

	describe.protected("Homepage People List Rhodium Test", function()
		-- func step is executed step by step
		local peopleList
		local addFriendsButton
		local firstFriendCarousel

		step("Navigate to homepage", function()
			-- make sure we are at homepage now
			PageNavigation.gotoHomePage()
		end)

		step("Load elements", function()
			peopleList = MobileAppElements.homePagePeopleList:waitForFirstInstance()
			assert(peopleList, "create people list unsuccessfully")

			-- AddFriendsButton
			addFriendsButton = peopleList["1"]
			assert(addFriendsButton, "create AddFriendsButton unsuccessfully")

			-- First friend carousel
			firstFriendCarousel = peopleList["2"]
			assert(firstFriendCarousel)
		end)

		describe.protected("Test AddFriendsButton on People List", function()
			step.protected("AddFriendsButton layout", function()
				-- check button size
				assert(addFriendsButton.AbsoluteSize.x == Constants.PeopleList.ADD_FRIENDS_FRAME_WIDTH, "AddFriendsButton width is wrong")
				assert(addFriendsButton.AbsoluteSize.y == ADD_FRIEND_BUTTON_HEIGHT, "AddFriendsButton height is wrong")
			end)

			step.protected("AddFriendsButton click effect", function()
				-- check button asset
				assert(addFriendsButton.AddButton.Image == ADD_FRIENDS_ICON, "AddFriendsButton's image is wrong")

				-- check button clicked asset
				local centerPoint = Element.new(addFriendsButton):getCenter()
				VirtualInput.touchStart(centerPoint)
				-- wait one frame
				wait()
				assert(addFriendsButton.AddButton.Image == ADD_FRIENDS_ICON_PRESSED, "AddFriendsButton's pressed image is wrong")

				VirtualInput.touchStop(centerPoint)
				wait()
				assert(addFriendsButton.AddButton.Image == ADD_FRIENDS_ICON, "AddFriendsButton's image is wrong")
			end)
		end)

		describe.protected("Test user carousel on people list", function()
			step.protected("User carousel layout", function()
				local headIcon = firstFriendCarousel.ThumbnailFrame.Thumbnail.Image
				local userName = firstFriendCarousel.ThumbnailFrame.Thumbnail.Username

				assert(headIcon, "can not find head icon")
				assert(userName, "can not find username label")

				-- Tablet
				if firstFriendCarousel.AbsoluteSize.x == FRIEND_CAROUSEL.Tablet.WIDTH then
					assert(firstFriendCarousel.AbsoluteSize.y == FRIEND_CAROUSEL.Tablet.HEIGHT)
					assert(headIcon.AbsoluteSize.x == FRIEND_CAROUSEL.Tablet.ICON_SIZE)
				else
					-- Phone
					assert(firstFriendCarousel.AbsoluteSize.x == FRIEND_CAROUSEL.Phone.WIDTH)
					assert(firstFriendCarousel.AbsoluteSize.y == FRIEND_CAROUSEL.Phone.HEIGHT)
					assert(headIcon.AbsoluteSize.x == FRIEND_CAROUSEL.Phone.ICON_SIZE)
				end

				assert(userName.TextColor3 == FRIEND_CAROUSEL.Username_TextColor)
				assert(userName.Font == FRIEND_CAROUSEL.Username_Font)
			end)

			step.protected("User carousel click event", function()
				-- click one of the friend carousel
				Element.new(firstFriendCarousel):click()
				local peopleListContextualMenu = MobileAppElements.peopleListContextualMenu:waitForFirstInstance()
				assert(peopleListContextualMenu, "create peopleList Contextual menu unsuccessfully")

				wait(0.5)

				Element.new(peopleListContextualMenu):click()
				wait(1)
				peopleListContextualMenu = MobileAppElements.peopleListContextualMenu:waitForFirstInstance()
				assert(peopleListContextualMenu == nil, "can not close people list contextual menu")
			end)
		end)

		describe.protected("Test scrolling frame of people list", function()
			step.protected("People List Scrolling test", function ()
				local screenWidth = peopleList.AbsoluteSize.x
				local peopleListContentSize = peopleList.CanvasSize.X.Offset

				local startPoint = Element.new(peopleList):getCenter()
				-- Move to left 100 pixel
				-- This number should be larger.
				-- if it's too small, the scrolling frame would be scrolled
				local endPoint = Vector2.new(startPoint.X - 100, startPoint.Y)
				VirtualInput.swipe(startPoint, endPoint, 0.2)
				wait(0.5)

				if peopleListContentSize > screenWidth then
					assert(peopleList.CanvasPosition.X > 0, "Can not move people list")
				else
					assert(peopleList.CanvasPosition.X == 0, "Can move a non-scrollable people list")
				end
			end)
		end)
	end)
end