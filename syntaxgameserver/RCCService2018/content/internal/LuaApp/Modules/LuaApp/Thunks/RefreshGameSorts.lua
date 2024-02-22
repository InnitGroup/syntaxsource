-- RefreshGameSorts.lua
-- Created by David Brooks <dbrooks@roblox.com>
-- 7/6/2018

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local ApiFetchSortTokens = require(Modules.LuaApp.Thunks.ApiFetchSortTokens)
local ApiFetchGamesData = require(Modules.LuaApp.Thunks.ApiFetchGamesData)
local Promise = require(Modules.LuaApp.Promise)

local manualRefreshEnabled = settings():GetFFlag("EnableLuaSortTokensManualRefresh")

--[[
	A thunk that updates the cached tokens for one or more game sort groups and then refreshes
	each of the included sorts.
	networking -- networking object
	sortCategories -- An array of sort groups to be refreshed. See GameSortGroups.lua.
	targetSort -- A specific sort to refresh, or nil to refresh all sorts included in sortCategories.
	optionalSettings -- A list of arguments to pass when requesting a list of games. Read by ApiFetchGamesInSort.
]]
return function(networking, sortCategories, targetSort, optionalSettings)
	assert(type(sortCategories) == "table")
	assert(#sortCategories >= 1)

	return function(store)
		local sortCategoriesPromises = {}

		if manualRefreshEnabled then
			for _, category in ipairs(sortCategories) do
				table.insert(sortCategoriesPromises, store:dispatch(ApiFetchSortTokens(networking, category)))
			end
		end

		return Promise.all(sortCategoriesPromises):andThen(function()
			local sortsFetchPromises = {}
			for _, category in ipairs(sortCategories) do
				table.insert(sortsFetchPromises, store:dispatch(ApiFetchGamesData(
					networking,
					category,
					targetSort,
					optionalSettings
				)))
			end

			return Promise.all(sortsFetchPromises)
		end)
	end
end
