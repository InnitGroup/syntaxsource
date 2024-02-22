local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local InsertService = game:GetService('InsertService')

local Modules = CoreGui.RobloxGui.Modules
local AEGetAvatarData = require(Modules.LuaApp.Thunks.AEThunks.AEGetAvatarData)
local AEGetAvatarRules = require(Modules.LuaApp.Thunks.AEThunks.AEGetAvatarRules)
local AECharacterManager = require(script.Parent.AECharacterManager)

local AECharacterLoader = {}
AECharacterLoader.__index = AECharacterLoader

function AECharacterLoader.new(store)
	local self = {}
	self.store = store
	self.connections = {}
	setmetatable(self, AECharacterLoader)

	self.r6 = ReplicatedStorage:WaitForChild('CharacterR6')
	self.r15 = ReplicatedStorage:WaitForChild('CharacterR15New')

	self.characterManager = AECharacterManager.new(store, self.r6, self.r15)
	self.started = false
	self.isLoadingAssets = false
	self.loadComplete = false

	store:dispatch(AEGetAvatarData())
	store:dispatch(AEGetAvatarRules())

	return self
end

function AECharacterLoader:start()
	self.started = true
	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	table.insert(self.connections, storeChangedConnection)

	local equippedAssets = self.store:getState().AEAppReducer.AECharacter.AEEquippedAssets

	if self.loadComplete then
		self.characterManager:start()
	else
		if not equippedAssets then
			-- retry in case previous call has failed.
			-- In the action, we already have enough protection against calling the backend multiple times.
			self.store:dispatch(AEGetAvatarData())
		elseif not self.isLoadingAsset then
			self:LoadEquippedAssets(equippedAssets)
		end
	end
end

function AECharacterLoader:stop()
	self.started = false

	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}
	if self.loadComplete then
		self.characterManager:stop()
	end
end

function AECharacterLoader:update(newState, oldState)
	local curEquipped = newState.AEAppReducer.AECharacter.AEEquippedAssets
	local oldEquipped = oldState.AEAppReducer.AECharacter.AEEquippedAssets

	if (curEquipped) and (not oldEquipped) then
		self:LoadEquippedAssets(curEquipped)
	end
end

local function getTotalEquippedAssetCount(equippedAssets)
	local totalCount = 0
	for _, assetIds in pairs(equippedAssets) do
		totalCount = totalCount + (#assetIds)
	end
	return totalCount
end

function AECharacterLoader:LoadEquippedAssets(equippedAssets)
	if equippedAssets == nil then
		error('Got no assets back from the backend.')
	end
	self.isLoadingAssets = true

	local totalCount = getTotalEquippedAssetCount(equippedAssets)
	if totalCount == 0 then
		self:TriggerEndLoad()
		return
	end
	local curCount = 0
	for assetTypeId, assetIds in pairs(equippedAssets) do
		for _, assetId in ipairs(assetIds) do
			spawn(function()
				if assetId ~= nil then
					local _, err = pcall(function()
						local assetModel = InsertService:LoadAsset(assetId)
						self.characterManager:equipAsset(assetId, assetTypeId, assetModel)
						-- For Debugging:
						-- assetModel.Parent = game.Workspace
					end)
					if err then
						warn (err)
					end
				end
				curCount = curCount + 1
				if curCount == totalCount then
					self:TriggerEndLoad()
				end
			end)
		end
	end
end

function AECharacterLoader:TriggerEndLoad()
	self.isLoadingAssets = false
	self.loadComplete = true

	if self.started then
		self.characterManager:start()
	end
end

return AECharacterLoader