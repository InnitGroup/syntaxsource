-- RefreshExpiringSortTokens.lua
-- Created by David Brooks <dbrooks@roblox.com>
-- 7/31/2018

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local ApiFetchSortTokens = require(Modules.LuaApp.Thunks.ApiFetchSortTokens)

local REFRESH_THRESHOLD_SECONDS = 600

local function shouldRefreshSortGroup(retrievalStatus, tokenRefreshTime, currentTime)
	return retrievalStatus ~= RetrievalStatus.Fetching
		and currentTime >= tokenRefreshTime - REFRESH_THRESHOLD_SECONDS
end

--[[
	A thunk that updates sort groups when at least one of their tokens will expire soon.
]]
return function(networking, sortGroups)
	return function(store)
		local promises = {}
		local currentTime = tick()
		local state = store:getState()
		for _, sortGroupName in ipairs(sortGroups) do
			local retrievalStatus = state.RequestsStatus.GameSortTokenFetchingStatus[sortGroupName]
			local tokenRefreshTime = state.NextTokenRefreshTime and state.NextTokenRefreshTime[sortGroupName] or 0

			if shouldRefreshSortGroup(retrievalStatus, tokenRefreshTime, currentTime) then
				table.insert(promises, store:dispatch(ApiFetchSortTokens(networking, sortGroupName)))
			end
		end

		return Promise.all(promises)
	end
end
