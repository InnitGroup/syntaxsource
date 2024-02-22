return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AppReducer = require(Modules.LuaApp.AppReducer)

	it("has the expected fields, and only the expected fields", function()
		local state = AppReducer(nil, {})

		local expectedKeys = {
			ChatAppReducer = true,
			ConnectionState = true,
			CurrentToastMessage = true,
			CentralOverlay = true,
			DeviceOrientation = true,
			FormFactor = true,
			FriendCount = true,
			Games = true,
			GameSortGroups = true,
			GameSorts = true,
			GameSortsContents = true,
			GameThumbnails = true,
			GameDetails = true,
			GameDetailsPageDataStatus = true,
			InGameUsersByGame = true,
			LocalUserId = true,
			Navigation = true,
			NextTokenRefreshTime = true,
			NotificationBadgeCounts = true,
			Platform = true,
			PlayabilityStatus = true,
			RequestsStatus = true,
			ScreenSize = true,
			Search = true,
			SearchesParameters = true,
			SponsoredEvents = true,
			Startup = true,
			TabBarVisible = true,
			TopBar = true,
			SiteMessage = true,
			Users = true,
			UsersAsync = true,
			UserStatuses = true,
			AEAppReducer = true,
			UniversePlaceInfos = true,
		}

		for key in pairs(expectedKeys) do
			assert(state[key] ~= nil, string.format("Expected field %q", key))
		end

		for key in pairs(state) do
			assert(expectedKeys[key] ~= nil, string.format("Did not expect field %q", key))
		end
	end)
end
