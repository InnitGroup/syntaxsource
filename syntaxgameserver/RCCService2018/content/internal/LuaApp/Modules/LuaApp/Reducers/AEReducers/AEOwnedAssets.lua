local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetOwnedAssets = require(Modules.LuaApp.Actions.AEActions.AESetOwnedAssets)
local AEGrantAsset = require(Modules.LuaApp.Actions.AEActions.AEGrantAsset)
local AERevokeAsset = require(Modules.LuaApp.Actions.AEActions.AERevokeAsset)
local Immutable = require(Modules.Common.Immutable)

--[[
	Add more owned asset ids to the players list. Keep order by checking for duplicates and only
	appending new ones to the list.
]]
return function(state, action)
	state = state or {}

	if action.type == AESetOwnedAssets.name then
		local checkForDups = {}
		local currentAssets = state[action.assetTypeId] and state[action.assetTypeId] or {}

		for _, assetId in pairs(currentAssets) do
			checkForDups[assetId] = assetId
		end

		for _, assetId in pairs(action.assets) do
			if not checkForDups[assetId] then
				currentAssets[#currentAssets + 1] = assetId
			end
		end

		return Immutable.Set(state, action.assetTypeId, currentAssets)
	elseif action.type == AEGrantAsset.name then
		local updatedAssets = {}
		local currentAssets = state[action.assetTypeId] and state[action.assetTypeId] or {}

		updatedAssets[1] = action.assetId

		for _, assetId in ipairs(currentAssets) do
			updatedAssets[#updatedAssets + 1] = assetId
		end

		return Immutable.Set(state, action.assetTypeId, updatedAssets)
	elseif action.type == AERevokeAsset.name then
		local updatedAssets = {}
		local currentAssets = state[action.assetTypeId] and state[action.assetTypeId] or {}

		for _, assetId in ipairs(currentAssets) do
			if assetId ~= action.assetId then
				updatedAssets[#updatedAssets + 1] = assetId
			end
		end

		return Immutable.Set(state, action.assetTypeId, updatedAssets)
	end

	return state
end