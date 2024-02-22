--to make ScriptAnalyzer Happy
describe = nil
step = nil
expect = nil
include = nil
-------------------------------
local XPath = require(game.CoreGui.RobloxGui.Modules.Rhodium.XPath)

local bottomBar = XPath.new("game.CoreGui.BottomBar")
local topBar = XPath.new("game.CoreGui.App.AppRouter.Home.Contents.TopBar.TopBar")
local content = XPath.new("game.CoreGui.App.AppRouter.Home.Contents.Scroller.scrollingFrame.Content")

local MobileAppElements = {
	bottomBar = bottomBar,
	topBar = topBar,
	pageName = topBar:cat(XPath.new("NavBar.Title")),
	robuxButton = topBar:cat(XPath.new("NavBar.RightIcons.Robux")),
	notificationsButton = topBar:cat(XPath.new("NavBar.RightIcons.Notifications")),
	searchInputBox = topBar:cat(XPath.new("NavBar.RightIcons.Search.SearchBar.SearchTouchArea.SearchFrameImage.SearchBox")),
	verticalScrollingFrame = XPath.new("game.CoreGui.App.AppRouter.Home.Contents.Scroller.scrollingFrame"),
	homeScreen = XPath.new("game.CoreGui.App.AppRouter.Home"),

	backButton = topBar:cat(XPath.new("Layout.BackButton")),

	avatarButton = bottomBar:cat(XPath.new("Contents.Frame.AvatarButton.ButtonFrame.Title")),
	catalogButton = bottomBar:cat(XPath.new("Contents.Frame.CatalogButton.ButtonFrame.Title")),
	chatButton = bottomBar:cat(XPath.new("Contents.Frame.ChatButton.ButtonFrame.Title")),
	friendsButton = bottomBar:cat(XPath.new("Contents.Frame.FriendsButton.ButtonFrame.Title")),
	gamesButton = bottomBar:cat(XPath.new("Contents.Frame.GamesButton.ButtonFrame.Title")),
	homeButton = bottomBar:cat(XPath.new("Contents.Frame.HomeButton.ButtonFrame.Title")),
	moreButton = bottomBar:cat(XPath.new("Contents.Frame.MoreButton.ButtonFrame.Title")),

	userNameText = content:cat(XPath.new("TitleSection.BuildersClubUsernameFrame.Username")),
	friendCarousel = content:cat(XPath.new("FriendSection.CarouselFrame.MainFrame.Carousel")),
	friendSeeAllText = content:cat(XPath.new("FriendSection.Container.Header.Spacer.Button.Text")),
	friendTitle = content:cat(XPath.new("FriendSection.Container.Header.Title")),
	gameCategoryEntry = content:cat(XPath.new("GameDisplay.*[.ClassName = Frame]")),
	viewFeedText = content:cat(XPath.new("FeedSection.MyFeedButton.Button.Text")),

	listPicker = XPath.new("game.CoreGui.PortalUI.Contents.AnimatedPopout.Scroller"),
	listPickerItem = XPath.new("game.CoreGui.PortalUI.Contents.AnimatedPopout.Scroller.*"),


	currentGameList = XPath.new("game.CoreGui.App.AppRouter.*[.ClassName = ScreenGui, .Enabled = true]"),

	----avatar editor
	avatarEditorScene = XPath.new("game.Workspace.AvatarEditorScene"),
	character = XPath.new("game.Workspace.Folder.Character"),
	r6r15SwitchFrame = XPath.new("game.CoreGui.ScreenGui.RootGui.AvatarTypeSwitch"),
	r6r15Switch = XPath.new("game.CoreGui.ScreenGui.RootGui.AvatarTypeSwitch.Switch"),

	selectTabButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.SelectedIcon"),
	closeTabButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CloseButton"),

	assetButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.ScrollingFrame.*[.ClassName = ImageButton]"),

	fullViewButton = XPath.new("game.CoreGui.ScreenGui.RootGui.TopFrame.FullViewButton"),
	rightFrame = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame"),
	rightFrameText = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.ScrollingFrame.TextLabel"),

	groupTabs = {
		recentButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryScroller.CategoryButtonRecent"),
		clothingButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryScroller.CategoryButtonClothing"),
		bodyButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryScroller.CategoryButtonBody"),
		animationButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryScroller.CategoryButtonAnimation"),
		outfitsButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryScroller.CategoryButtonOutfits"),
	},

	groupTabs_portrait = {
		recentButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryButtonRecent"),
		clothingButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryButtonClothing"),
		bodyButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryButtonBody"),
		animationButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryButtonAnimation"),
		outfitsButton = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TopMenuContainer.CategoryButtonOutfits"),
	},

	recentTabs = {
		tabAll = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRecent All"),
		tabClothing = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRecent Clothing"),
		tabBody = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRecent Body"),
		tabAnimation = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRecent Animation"),
		tabOutfits = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRecent Outfits"),
	},

	recentTabs_portrait = {
		tabAll = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRecent All"),
		tabClothing = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRecent Clothing"),
		tabBody = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRecent Body"),
		tabAnimation = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRecent Animation"),
	},

	clothingTabs = {
		tabBack = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabBack Accessories"),
		tabFace = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabFace Accessories"),
		tabFront = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabFront Accessories"),
		tabGear = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabGear"),
		tabHair = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabHair"),
		tabHats = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabHats"),
		tabNeck = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabNeck Accessories"),
		tabPants = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabPants"),
		tabShirts = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabShirts"),
		tabShoulder = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabShoulder Accessories"),
		tabWaist = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabWaist Accessories"),
	},

	clothingTabs_portrait = {
		tabBack = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabBack Accessories"),
		tabFace = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabFace Accessories"),
		tabFront = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabFront Accessories"),
		tabGear = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabGear"),
		tabHair = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabHair"),
		tabHats = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabHats"),
		tabNeck = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabNeck Accessories"),
		tabPants = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabPants"),
		tabShirts = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabShirts"),
		tabShoulder = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabShoulder Accessories"),
		tabWaist = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabWaist Accessories"),
	},

	bodyTabs = {
		tabFaces = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabFaces"),
		tabHeads = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabHeads"),
		tabLeftArms = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabLeft Arms"),
		tabLeftLegs = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabLeft Legs"),
		tabRightArms = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRight Arms"),
		tabRightLegs = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRight Legs"),
		tabScale = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabScale"),
		tabSkinTone = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabSkin Tone"),
		tabTorsos = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabTorsos"),
	},

	bodyTabs_portrait = {
		tabFaces = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabFaces"),
		tabHeads = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabHeads"),
		tabLeftArms = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabLeft Arms"),
		tabLeftLegs = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabLeft Legs"),
		tabRightArms = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRight Arms"),
		tabRightLegs = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRight Legs"),
		tabScale = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabScale"),
		tabSkinTone = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabSkin Tone"),
		tabTorsos = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabTorsos"),
	},

	animationTabs = {
		tabClimb = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabClimb Animations"),
		tabFall = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabFall Animations"),
		tabIdle = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabIdle Animations"),
		tabJump = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabJump Animations"),
		tabRun = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabRun Animations"),
		tabSwim = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabSwim Animations"),
		tabWalk = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabWalk Animations"),
	},

	animationTabs_portrait = {
		tabClimb = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabClimb Animations"),
		tabFall = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabFall Animations"),
		tabIdle = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabIdle Animations"),
		tabJump = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabJump Animations"),
		tabRun = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabRun Animations"),
		tabSwim = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabSwim Animations"),
		tabWalk = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabWalk Animations"),
	},

	outfitsTabs = {
		tabOutfits = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabListContainer.TabList.Contents.TabOutfits"),
	},

	outfitsTabs_portrait = {
		tabOutfits = XPath.new("game.CoreGui.ScreenGui.RootGui.Frame.TabList.Contents.TabOutfits"),
	},

	getAvatarTabDetail = function(root)
		return{
			text = XPath.new("TextLabel", root),
		}
	end,

	getGameListDetail = function(root)
		return{
			dropDownText = XPath.new("Contents.Scroller.scrollingFrame.Content.TopSection.DropDown.Text", root),
			gameTitle = XPath.new("Contents.Scroller.scrollingFrame.Content.TopSection.Title", root),
			gameCard = XPath.new("Contents.Scroller.scrollingFrame.Content.*.1.*[.ClassName = Frame]", root),
		}
	end,

	getListPickerItem = function(root)
		return {
			Text = XPath.new("ImageAndText.Text", root)
		}
	end,

	getGameCategoryDetail = function(root)
		return {
			title = XPath.new("Title.Title", root),
			seeAllButton = XPath.new("Title.Spacer.Button.Text", root),
			carousel = XPath.new("Carousel", root),
			carouselItem = XPath.new("Carousel.*", root),
		}
	end,

	getGameCardDetailFromCarouselItem = function(root)
		return {
			gameButton = XPath.new("GameButton", root),
			playerCount = XPath.new("GameButton.GameInfo.PlayerCount", root),
			title = XPath.new("GameButton.GameInfo.Title", root),
			icon = XPath.new("GameButton.Icon", root),
		}
	end,

	filterBy = function(container, relativePath, property, value)
		local rootPath = container:copy()
		local key = "."..property
		if relativePath ~= nil then
			key = "." .. relativePath:toString() .. key
		end
		local filter = {{key = key, value = value}}
		rootPath:mergeFilter(rootPath:size(), filter)
		return rootPath
	end

}

return MobileAppElements
