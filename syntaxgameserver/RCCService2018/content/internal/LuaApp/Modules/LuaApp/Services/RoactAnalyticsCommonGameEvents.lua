--[[
	This object is designed to abstract all of the events fired by game components.
	Since game carousels, game cards, game lists, and game grids are shared across multiple contexts,
	these elements need a common reporting component.
]]
local Modules = game:GetService("CoreGui").RobloxGui.Modules

local buttonClick = require(Modules.LuaApp.Analytics.Events.buttonClick)
local gameDetailReferral = require(Modules.LuaApp.Analytics.Events.gameDetailReferral)
local gamesPageInteraction = require(Modules.LuaApp.Analytics.Events.gamesPageInteraction)
local gamePlayIntent = require(Modules.LuaApp.Analytics.Events.gamePlayIntent)
local joinGameInPlacesList = require(Modules.LuaApp.Analytics.Events.joinGameInPlacesList)
local peopleListInteraction = require(Modules.LuaApp.Analytics.Events.peopleListInteraction)
local peopleListViewGameDetail = require(Modules.LuaApp.Analytics.Events.peopleListViewGameDetail)
local peopleListJoinGame = require(Modules.LuaApp.Analytics.Events.peopleListJoinGame)
local openModalFromGameTile = require(Modules.LuaApp.Analytics.Events.openModalFromGameTile)
local RoactAnalytics = require(Modules.LuaApp.Services.RoactAnalytics)
local Constants = require(Modules.LuaApp.Constants)

local RoactAnalyticsCommonGameEvents = {}
function RoactAnalyticsCommonGameEvents.get(context, args)
	assert(type(args.createReferralCtx) == "function", "Expected createReferralCtx to be a function")
	assert(type(args.pageName) == "string", "Expected pageName to be a string")

	local analyticsImpl = RoactAnalytics.get(context)

	local createReferralCtx = args.createReferralCtx
	local pageName = args.pageName
	local pageNameSeeAll = pageName .. "SeeAll"

	local CGE = {}

	function CGE.reportSeeAll(sortName, indexOnPage)
		local sortId = Constants.LEGACY_GAME_SORT_IDS[sortName]
		if not sortId then
			sortId = Constants.LEGACY_GAME_SORT_IDS.default
		end

		local evtContext = "SeeAll"
		local actionType = "touch"
		local actionValue = tostring(sortId)
		local selectedIndex = tonumber(indexOnPage)

		gamesPageInteraction(analyticsImpl.EventStream, evtContext, actionType, actionValue, selectedIndex)
	end

	function CGE.reportFilterChange(sortName, indexOnPage)
		local sortId = Constants.LEGACY_GAME_SORT_IDS[sortName]
		if not sortId then
			sortId = Constants.LEGACY_GAME_SORT_IDS.default
		end

		local evtContext = "SFMenu"
		local actionType = "touch"
		local actionValue = tostring(sortId)
		local selectedIndex = tonumber(indexOnPage)

		gamesPageInteraction(analyticsImpl.EventStream, evtContext, actionType, actionValue, selectedIndex)
	end

	local function reportGameDetailReferral(referralPage,
		placeId,
		sortName,
		indexInSort,
		numItemsInSort,
		isAd,
		timeFilter,
		genreFilter)

		-- handle optional values
		if not timeFilter then
			timeFilter = 1
		end

		if not genreFilter then
			genreFilter = 1
		end

		-- lookup the legacy sortId based on the sortName
		local sortId = Constants.LEGACY_GAME_SORT_IDS[sortName]
		if not sortId then
			sortId = Constants.LEGACY_GAME_SORT_IDS.default
		end

		local referralContext = createReferralCtx(indexInSort, sortId, timeFilter, genreFilter)
		gameDetailReferral(analyticsImpl.EventStream, referralContext, referralPage, numItemsInSort, placeId, isAd)
	end

	function CGE.reportOpenGameDetail(placeId, sortName, indexInSort, itemsInSort, isAd, timeFilter, genreFilter)
		reportGameDetailReferral(pageName, placeId, sortName, indexInSort, itemsInSort, isAd, timeFilter, genreFilter)
	end

	function CGE.reportOpenGameDetailFromSeeAll(placeId, sortName, indexInSort, itemsInSort, isAd, timeFilter, genreFilter)
		reportGameDetailReferral(pageNameSeeAll, placeId, sortName, indexInSort, itemsInSort, isAd, timeFilter, genreFilter)
	end

	function CGE.reportPeopleListInteraction(eventName, friendId, position)
		peopleListInteraction(analyticsImpl.EventStream, eventName, friendId, position)
	end

	function CGE.reportViewProfileFromPeopleList(friendId, position, rootPlaceId, fromWhere)
		peopleListViewGameDetail(analyticsImpl.EventStream, friendId, position, rootPlaceId, fromWhere)
	end

	function CGE.reportPeopleListJoinGame(friendId, position, placeId, rootPlaceId, gameInstanceId)
		peopleListJoinGame(analyticsImpl.EventStream, friendId, position, rootPlaceId, gameInstanceId)

		local eventContext = "peopleListInHomePage"
		gamePlayIntent(analyticsImpl.EventStream, eventContext, placeId, rootPlaceId)
	end

	function CGE.reportJoinGameInPlacesList(playerId, placeId, rootPlaceId, gameInstanceId)
		joinGameInPlacesList(analyticsImpl.EventStream, playerId, placeId, rootPlaceId, gameInstanceId)

		local eventContext = "gamePlayIntentInPlacesList"
		gamePlayIntent(analyticsImpl.EventStream, eventContext, placeId, rootPlaceId)
	end

	function CGE.reportOpenModalFromGameTileForPlacesList(placeId)
		openModalFromGameTile(analyticsImpl.EventStream, placeId)
	end

	function CGE.reportButtonClicked(eventContext, buttonName)
		buttonClick(analyticsImpl.EventStream, eventContext, buttonName)
	end

	return CGE
end

return RoactAnalyticsCommonGameEvents