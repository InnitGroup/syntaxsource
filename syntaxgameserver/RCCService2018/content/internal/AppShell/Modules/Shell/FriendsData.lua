--[[
			// FriendsData.lua

			// Caches the current friends pagination to used by anyone in the app

			// TODO:
				Need polling to update friends. How are we going to handle all the cases
					like the person you're selecting going offline, etc..
]]
local CoreGui = game:GetService("CoreGui")
local PlatformService = nil
pcall(function() PlatformService = game:GetService('PlatformService') end)
local FriendService = nil
pcall(function() FriendService = game:GetService('FriendService') end)
local ThirdPartyUserService = nil
pcall(function() ThirdPartyUserService = game:GetService('ThirdPartyUserService') end)
local isNotConsole = UserSettings().GameSettings:InStudioMode() or game:GetService('UserInputService'):GetPlatform() == Enum.Platform.Windows

local GuiRoot = CoreGui:FindFirstChild("RobloxGui")
local Modules = GuiRoot:FindFirstChild("Modules")
local ShellModules = Modules:FindFirstChild("Shell")

local Http = require(ShellModules:FindFirstChild('Http'))
local Utility = require(ShellModules:FindFirstChild('Utility'))
local EventHub = require(ShellModules:FindFirstChild('EventHub'))
local TableUtilities = require(Modules.LuaApp.TableUtilities)
local ReloaderManager = require(ShellModules:FindFirstChild('ReloaderManager'))
local MakeSafeAsync = require(ShellModules:FindFirstChild('SafeAsync'))
local AppState = require(ShellModules.AppState)
local ResetUserThumbnails = require(ShellModules.Actions.ResetUserThumbnails)
local SetFriendsData = require(ShellModules.Actions.SetFriendsData)
local SetRenderedFriendsData = require(ShellModules.Actions.SetRenderedFriendsData)


-- NOTE: This is just required for fixing Usernames in auto-generatd games
local GameData = require(ShellModules:FindFirstChild('GameData'))
local ConvertMyPlaceNameInXboxAppFlag = settings():GetFFlag("ConvertMyPlaceNameInXboxApp")

local FriendsData = {}

local function OnUserAccountChanged()
	FriendsData.Setup()
end
EventHub:addEventListener(EventHub.Notifications["AuthenticationSuccess"], "FriendsData", OnUserAccountChanged)
if ThirdPartyUserService then
	ThirdPartyUserService.ActiveUserSignedOut:connect(function()
		FriendsData.Reset()
	end)
end

local isOnlineFriendsPolling = false
local isFriendEventsConnected = false
local renderedFriendsUpdateSuspended = false
local cachedFriendsData = nil
local cachedFriendsDataMap = {}
local friendsDataConns = {}

local function filterFriends(friendsData)
	for i = 1, #friendsData do
		local data = friendsData[i]

		if data.gamertag == "" then
			data.gamertag = nil
		end

		if data.robloxuid <= 0 then
			data.robloxuid = nil
		end

		if data.xuid == "" then
			data.xuid = nil
		end

		if data.placeId == 0 then
			data.placeId = nil
		end

		if data.lastLocation == "" then
			data.lastLocation = nil
		end

		if data.robloxName == "" then
			data.robloxName = nil
		end

		local placeId = data.placeId
		local lastLocation = data.lastLocation

		-- If the lastLocation for a user is some user place with a GeneratedUsername in it
		-- then replace it with the actual creator name!
		if ConvertMyPlaceNameInXboxAppFlag and placeId and lastLocation and GameData:ExtractGeneratedUsername(lastLocation) then
			local gameCreator = GameData:GetGameCreatorAsync(placeId)
			if gameCreator then
				lastLocation = GameData:GetFilteredGameName(lastLocation, gameCreator)
			end
		end

		data.placeId = placeId
		data.lastLocation = lastLocation
	end

	return friendsData
end

--[[ Public API ]]--
FriendsData.OnFriendsDataUpdated = Utility.Signal()

function FriendsData.GetOnlineFriendsAsync()
	if not cachedFriendsData then
		--Wait until we get cachedFriendsData from FriendService/FriendEvents disconnect(user sign out)
		while isFriendEventsConnected and not cachedFriendsData do
			wait()
		end
	end

	return cachedFriendsData or {}
end

-- we make connections through this function so we can clean them all up upon
-- clearing the friends data
function FriendsData.ConnectUpdateEvent(cbFunc)
	local cn = FriendsData.OnFriendsDataUpdated:connect(cbFunc)
	table.insert(friendsDataConns, cn)
end

function FriendsData.Reset()
	isOnlineFriendsPolling = false

	for index, cn in pairs(friendsDataConns) do
		Utility.DisconnectEvent(cn)
		friendsDataConns[index] = nil
	end
	isFriendEventsConnected = false

	cachedFriendsData = nil
	cachedFriendsDataMap = {}

	AppState.store:dispatch(ResetUserThumbnails())
	AppState.store:dispatch(SetFriendsData())
	AppState.store:dispatch(SetRenderedFriendsData())
	renderedFriendsUpdateSuspended = false

	if isNotConsole then
		ReloaderManager:removeReloader("FriendsData")
		FriendsData.ReloaderFuncId = nil
	end
end

local function CheckEntryUpdate(newFriendsData)
	local validEntries = {}
	for i = 1, #newFriendsData do
		local data = newFriendsData[i]
		local xuid = data.xuid or ""
		local robloxuid = data.robloxuid or ""
		local idStr = tostring(xuid.."#"..robloxuid)
		validEntries[idStr] = true
		if cachedFriendsDataMap[idStr] then --check whether entry changed
			local differentAttributes = TableUtilities.TableDifference(cachedFriendsDataMap[idStr], data)
			if next(differentAttributes) ~= nil then
				data.isUpdated = true
			end
		end
		cachedFriendsDataMap[idStr] = data
	end

	for idStr in pairs(cachedFriendsDataMap) do
		if not validEntries[idStr] then
			cachedFriendsDataMap[idStr] = nil
		end
	end
end

local UpdateRenderedFriendsData = function(newFriendsData)
	AppState.store:dispatch(SetRenderedFriendsData(newFriendsData))
	--data for HomePane friend scroller, also from store, but need the CheckEntryUpdate
	CheckEntryUpdate(newFriendsData)
	cachedFriendsData = newFriendsData
	FriendsData.OnFriendsDataUpdated:fire(newFriendsData)
end
function FriendsData:SuspendUpdate()
	renderedFriendsUpdateSuspended = true
end

function FriendsData:ResumeUpdate()
	--Get latest data from store when ResumeUpdate(), don't dispatch if the friends data hasn't been fetched yet
	if AppState.store:getState().Friends.initialized then
		UpdateRenderedFriendsData(AppState.store:getState().Friends.data)
	end
	renderedFriendsUpdateSuspended = false
end

function FriendsData.Setup()
	FriendsData.Reset()
	--We make the conns once user logged in, and once we get the cachedFriendsData from FriendService
	--this func becomes sync call
	if PlatformService and FriendService then
		--Connect FriendsUpdated event to get newFriendsData at intervals
		table.insert(friendsDataConns, FriendService.FriendsUpdated:connect(function(newFriendsData)
			newFriendsData = filterFriends(newFriendsData)
			AppState.store:dispatch(SetFriendsData(newFriendsData))
			if not AppState.store:getState().RenderedFriends.initialized or not renderedFriendsUpdateSuspended then
				UpdateRenderedFriendsData(newFriendsData)
			end
		end))

		isFriendEventsConnected = true

		--Try to get the cachedFriendsData, check if the friends data has been fetched on Friend Service
		local success, result = pcall(function()
			return FriendService:GetPlatformFriends()
		end)
		if success then
			result = filterFriends(result)
			AppState.store:dispatch(SetFriendsData(result))
			if not AppState.store:getState().RenderedFriends.initialized or not renderedFriendsUpdateSuspended then
				UpdateRenderedFriendsData(result)
			end
		end
	else
		if isNotConsole then
			local POLL_DELAY = 30
			local GetRecommendPeopleInStudio = MakeSafeAsync({
				asyncFunc = function()
					local finalRecommendedUsers = {}
					local result = Http.GetRecommendedUsersndsAsync()
					if result and result["recommendedUsers"] then
						local recommendedUsersMap = {}
						local recommendedUsers = result["recommendedUsers"]
						local userIds = {}
						for i = 1, #recommendedUsers do
							local data = recommendedUsers[i]
							local robloxuid = data.userId
							if robloxuid then
								table.insert(userIds, robloxuid)
								recommendedUsersMap[robloxuid] =
								{
									robloxuid = robloxuid,
									robloxName = data.userName
								}
							end
						end

						local presenceInfo = Http.GetUsersPresenceAsync(userIds)
						if presenceInfo and presenceInfo["userPresences"] then
							for _, presence in ipairs(presenceInfo["userPresences"]) do
								local robloxuid = presence.userId
								if robloxuid and recommendedUsersMap[robloxuid] then
									recommendedUsersMap[robloxuid].placeId = presence.rootPlaceId
									recommendedUsersMap[robloxuid].lastLocation = presence.lastLocation
									recommendedUsersMap[robloxuid].friendsSource = "Roblox"
									local robloxStatus = "Offline"
									local rank = 4
									if presence.userPresenceType == 1 then
										robloxStatus = "Online"
										rank = 3
									elseif presence.userPresenceType == 2 then
										if presence.rootPlaceId and presence.rootPlaceId > 0 then
											robloxStatus = "InGame"
											rank = 1
										else
											robloxStatus = "Online"
											rank = 3
										end
									elseif presence.userPresenceType == 3 then
										robloxStatus = "InStudio"
										rank = 2
									end
									recommendedUsersMap[robloxuid].robloxStatus = robloxStatus
									recommendedUsersMap[robloxuid].rank = rank
									table.insert(finalRecommendedUsers, recommendedUsersMap[robloxuid])
								end
							end
						end
						local function sortFunc(a, b)
							if a.rank == b.rank then
								return a.robloxName:lower() < b.robloxName:lower()
							end
							return a.rank < b.rank
						end

						table.sort(finalRecommendedUsers, sortFunc)
					end
					return finalRecommendedUsers
				end,
				callback = function(finalRecommendedUsers)
					finalRecommendedUsers = filterFriends(finalRecommendedUsers)
					AppState.store:dispatch(SetFriendsData(finalRecommendedUsers))
					if not AppState.store:getState().RenderedFriends.initialized or not renderedFriendsUpdateSuspended then
						UpdateRenderedFriendsData(finalRecommendedUsers)
					end
				end,
				userRelated = true
			})

			if not isOnlineFriendsPolling then
				isOnlineFriendsPolling = true
				isFriendEventsConnected = true
				spawn(function()
					ReloaderManager:removeReloader("FriendsData")
					FriendsData.ReloaderFuncId = ReloaderManager:addReloaderFunc("FriendsData", function() GetRecommendPeopleInStudio() end, POLL_DELAY, true)
					ReloaderManager:callReloaderFunc("FriendsData", FriendsData.ReloaderFuncId)
				end)
			end
		end
	end
end

return FriendsData
