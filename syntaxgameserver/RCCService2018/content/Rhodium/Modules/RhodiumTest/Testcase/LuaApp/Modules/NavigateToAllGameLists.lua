--to make ScriptAnalyzer Happy
describe = nil
step = nil
expect = nil
include = nil
-------------------------------
local Element = require(game.CoreGui.RobloxGui.Modules.Rhodium.Element)
local MobileAppElements = require(game.CoreGui.RobloxGui.Modules.RhodiumTest.Common.MobileAppElements)

--"My Recent", only if the account played some games
--"Friend Activity", only if the account has friends
local popupMenuText = {"Featured", "Friend Activity", "My Recent", "Popular",
	"Popular Near You", "Recommended", "Top Earning", "Top Rated"}

local function getMenuItem(text)
	return MobileAppElements.filterBy(MobileAppElements.listPickerItem,
		MobileAppElements.getListPickerItem().Text, "Text", text)
end

local function clickMenu(text)
	local path = getMenuItem(text)
	local instance = path:waitForFirstInstance()
	assert(instance)
	Element.new(instance):click()
end

local function checkAllMenuExists()
	for _, text in ipairs(popupMenuText) do
		local path = getMenuItem(text)
		assert(path:waitForFirstInstance())
	end
end

local function isMenuOpen()
	return MobileAppElements.listPicker:getFirstInstance() ~= nil
end

local function getCurrentListDetail()
	--because it takes some time to set old screen as disabled
	wait(0.2)
	local homePath = MobileAppElements.homeScreen
	homePath = MobileAppElements.filterBy(homePath, nil, "Enabled", true)
	local result = homePath:waitForDisappear()
	assert(result)

	local currentGameList = MobileAppElements.currentGameList
	local currentGameListInstance = currentGameList:waitForFirstInstance()
	assert(currentGameListInstance)
	assert(currentGameListInstance.Name ~= "Home")

	local gameListDetail = MobileAppElements.getGameListDetail(currentGameListInstance)
	return gameListDetail
end

local function openMenu()
	if isMenuOpen() then return end
	local element = Element.new(getCurrentListDetail().dropDownText)
	element:click()
end

local function closeMenu()
	if not isMenuOpen() then return end
	local element = Element.new(getCurrentListDetail().dropDownText)
	element:click()
end

local function clickSeeAll(category)
	local recommendedEntry = MobileAppElements.filterBy(MobileAppElements.gameCategoryEntry,
		MobileAppElements.getGameCategoryDetail().title, "Text", category)

	local recommendedEntryInstance = recommendedEntry:waitForFirstInstance()

	assert(recommendedEntryInstance)

	local seeAllButton = MobileAppElements.getGameCategoryDetail(recommendedEntryInstance).seeAllButton

	local seeAllButtonInstance = seeAllButton:waitForFirstInstance()

	assert(seeAllButtonInstance)

	Element.new(seeAllButtonInstance):click()
end

local function checkIsList(name)
	print("checking game list: ", name)
	local gameListDetail = getCurrentListDetail()
	local gameTitle = MobileAppElements.filterBy(gameListDetail.gameTitle, nil, "Text", name)
	local gameTitleInstance = gameTitle:waitForFirstInstance()
	assert(gameTitleInstance)

	assert(gameListDetail.dropDownText:waitForFirstInstance())
	assert(gameListDetail.gameTitle:waitForFirstInstance())
	assert(gameListDetail.gameCard:waitForFirstInstance())

	assert(gameListDetail.dropDownText:waitForFirstInstance().Text == name)
	assert(gameListDetail.gameTitle:waitForFirstInstance().Text == name)
end

local function canNavigateToAllMenu()
	for _, text in ipairs(popupMenuText) do
		step(string.format("should be able to navigate to game list %q ", text), function()
			openMenu()
			clickMenu(text)
			checkIsList(text)
		end)
	end
end

local function gameCardExist()
	local gameListDetail = getCurrentListDetail()
	local gameCard = MobileAppElements.filterBy(gameListDetail.gameCard,
		MobileAppElements.getGameCardDetailFromCarouselItem().gameButton, "ClassName", "TextButton")
	local instance = gameCard:waitForFirstInstance()
	assert(instance)
end

return function()
	describe.protected("should be able to navigate to all game lists", function()
		step("should be able to find the SeeAll button on home page and click it", function()
			clickSeeAll("Recommended")
		end)
		step("should open recommended page after click see all", function()
			checkIsList("Recommended")
		end)
		step("the pop up menu should not show up when switch to that page", function()
			assert(isMenuOpen() == false)
		end)
		step("should have some game cards on this page", function()
			gameCardExist()
		end)
		describe("should be able to navigate to every game list by drop down menu", function()
			include(canNavigateToAllMenu)
		end)
	end)
end