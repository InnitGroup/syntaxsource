local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEToggleEquipAsset = require(Modules.LuaApp.Actions.AEActions.AEToggleEquipAsset)
local AEEquipOutfit = require(Modules.LuaApp.Actions.AEActions.AEEquipOutfit)
local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)
local Immutable = require(Modules.Common.Immutable)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AvatarEditorUseNewCostumeLogic = settings():GetFFlag("AvatarEditorUseNewCostumeLogic")

local function checkIfWearingAsset(assets, assetId)
	for _, equippedAssetId in pairs(assets) do
		if equippedAssetId == assetId then
			return true
		end
	end

	return false
end

local function fullOutfitReset(oldState, assets)
	local newState = {}
	local assetTypeIds = {}

	for assetTypeId, _ in pairs(oldState) do
		assetTypeIds[assetTypeId] = true
	end

	for assetTypeId, _ in pairs(assets) do
		assetTypeIds[assetTypeId] = true
	end

	for assetTypeId, _ in pairs(assetTypeIds) do
		local assetsByType = assets[assetTypeId]
		newState[assetTypeId] = assetsByType and assetsByType or {}
	end

	return newState
end

local function replaceOutfitParts(oldState, assets)
	return Immutable.JoinDictionaries(oldState, assets)
end

return function(state, action)
	state = state or nil

	if action.type == AEReceivedAvatarData.name then
		local assets = action.avatarData['assets']
		if assets == nil then
			return state
		end
		state = {}
		for _, asset in ipairs(assets) do
			local assetTypeID = asset.assetType.id
			local entry = state[assetTypeID]
			if entry ~= nil then
				table.insert(entry, asset.id)
			else
				state[assetTypeID] = {asset.id}
			end
		end
		return state
	elseif action.type == AEToggleEquipAsset.name then
		state = state or {}

		if state[action.assetType] and checkIfWearingAsset(state[action.assetType], action.assetId) then
			local assets = state[action.assetType] or {}
			return Immutable.Set(state, action.assetType, Immutable.RemoveValueFromList(assets, action.assetId))
		end

		if action.assetType == AEConstants.AssetTypes.Hat then
			local hats = state[AEConstants.AssetTypes.Hat] or {}
			state = Immutable.Set(state, AEConstants.AssetTypes.Hat, {action.assetId, hats[1], hats[2]})
			return state
		end
		return Immutable.Set(state, action.assetType, {action.assetId}) -- Key: Asset Type, Value: Array of Asset IDs
	elseif action.type == AEEquipOutfit.name then
		state = state or {}

		if AvatarEditorUseNewCostumeLogic then
			if action.fullReset then
				return fullOutfitReset(state, action.assets)
			else
				return replaceOutfitParts(state, action.assets)
			end
		else
			local newState = {}
			local assetTypeIds = {}

			for assetTypeId, _ in pairs(state) do
				assetTypeIds[assetTypeId] = true
			end

			for assetTypeId, _ in pairs(action.assets) do
				assetTypeIds[assetTypeId] = true
			end

			for assetTypeId, _ in pairs(assetTypeIds) do
				local assetsByType = action.assets[assetTypeId]
				newState[assetTypeId] = assetsByType and assetsByType or {}
			end

			return newState
		end
	end

	return state
end