local ReplicatedStorage = game:GetService('ReplicatedStorage')
local InsertService = game:GetService('InsertService')
local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local AEAnimationManager = require(Modules.LuaApp.Components.Avatar.AEAnimationManager)
local AESetCurrentCharacter = require(Modules.LuaApp.Actions.AEActions.AESetCurrentCharacter)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEBodyColorManager = require(Modules.LuaApp.Components.Avatar.AEBodyColorManager)
local AEAvatarScalesManager = require(Modules.LuaApp.Components.Avatar.AEAvatarScalesManager)
local AvatarEditorFixTShirtGraphic = settings():GetFFlag("AvatarEditorFixTShirtGraphic")

local AECharacterManager = {}
AECharacterManager.__index = AECharacterManager

local r15ModelFolder = 'R15ArtistIntent'
local r6ModelFolder = 'R6'

local function isFolder(entity)
	return entity:IsA('Folder')
end

local function isAccessory(entity)
	return entity:IsA('Accessory')
end

local function isTool(entity)
	return entity:IsA('Tool')
end

local function isScript(entity)
	return entity:IsA('Script')
end

local function disableScripts(tool)
	for _, child in pairs(tool:GetChildren()) do
		if isScript(child) then
			child.Disabled = true
		end
	end
end

function AECharacterManager.new(store, r6, r15)
	local self = {}
	self.store = store
	self.connections = {}
	setmetatable(self, AECharacterManager)

	self.initialized = false
	self.defaultR6 = r6
	self.defaultR15 = r15
	self.r6 = r6:clone()
	self.r15 = r15:clone()
	self.r15.HumanoidRootPart.Anchored = true
	self.currentCharacter = self.r15
	self.store:dispatch(AESetCurrentCharacter(self.currentCharacter))
	self.characterRoot = Instance.new("Folder")
	self.characterRoot.Name = "CharacterRoot"
	self.characterRoot.Parent = game.Workspace
	self.characterCFrame = self.r6.PrimaryPart.CFrame
	self.r15:SetPrimaryPartCFrame(self.characterCFrame)
	self.head = self.currentCharacter.Head.Mesh
	self.face = self.currentCharacter.Head.face
	self.shirt = nil
	self.pants = nil
	self.tShirtGraphic = nil

	self.equippedAccessoryModels = {}
	self.equippedToolModels = {}

	self.r6Children = {}
	self.r15Children = {}
	local characterParts = self.r15:GetChildren()
	for _, part in pairs(characterParts) do
		self.r15Children[part.name] = part
	end

	self.defaultR15Children = {}
	characterParts = self.defaultR15:GetChildren()
	for _, part in pairs(characterParts) do
		self.defaultR15Children[part.name] = part
	end

	self.scalesManager = AEAvatarScalesManager.new(store, self.characterCFrame)
	self.animationManager = AEAnimationManager.new(store)
	self.bodyColorManager = AEBodyColorManager.new(store, self)

	return self
end

function AECharacterManager:start()
	local currentAvatarType = self.store:getState().AEAppReducer.AECharacter.AEAvatarType
	if (currentAvatarType == AEConstants.AvatarType.R6 and self.currentCharacter ~= self.r6)
	or (currentAvatarType == AEConstants.AvatarType.R15 and self.currentCharacter ~= self.r15) then
		self:switchAvatarType(currentAvatarType)
	end

	self.currentCharacter.Parent = self.characterRoot

	if not self.initialized then
		self:buildRig()
	end

	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	table.insert(self.connections, storeChangedConnection)

	self.animationManager:start()
	self.bodyColorManager:start()

	self.initialized = true
	self.scalesManager:start()
end

-- returns items that are in first table and missing from the second one.
local function findMissingIds(firstTable, secondTable)
	local missingIds = {}
	if (firstTable == nil) or (not next(firstTable)) then
		return missingIds
	end
	for _, assetId in ipairs(firstTable) do
		local found = false
		if secondTable and next(secondTable) then
			for _, id in ipairs(secondTable) do
				if id == assetId then
					found = true
					break
				end
			end
		end
		if not found then
			table.insert(missingIds, assetId)
		end
	end
	return missingIds
end

function AECharacterManager:update(newState, oldState)
	local curEquipped = newState.AEAppReducer.AECharacter.AEEquippedAssets
	local oldEquipped = oldState.AEAppReducer.AECharacter.AEEquippedAssets
	local equippedIds, unequippedIds
	local equippedIdsWithAssetType, unequippedIdsWithAssetType = {}, {}
	local equippedId, unequippedId = nil, nil
	local assetTypeIdToCheck = 0

	if curEquipped ~= oldEquipped then
		for assetTypeId, curEquippedIds in pairs(curEquipped) do
			local prevEquippedIds = oldEquipped and oldEquipped[assetTypeId] or {}
			-- These tables have at most 3 elements, so time complexity is fine.
			equippedIds = findMissingIds(curEquippedIds, prevEquippedIds)
			unequippedIds = findMissingIds(prevEquippedIds, curEquippedIds)
			equippedIdsWithAssetType[assetTypeId] = equippedIds
			unequippedIdsWithAssetType[assetTypeId] = unequippedIds
			local isPotentialSwap = (#equippedIds > 0)
			for _, assetId in ipairs(unequippedIds) do
				self:unequipAsset(assetId, assetTypeId, isPotentialSwap)
				unequippedId = assetId
				assetTypeIdToCheck = assetTypeId
			end

			for _, assetId in ipairs(equippedIds) do
				self:loadAndEquipAsset(assetId, assetTypeId)
				equippedId = assetId
				assetTypeIdToCheck = assetTypeId
			end
		end
	end

	local newAvatarType = newState.AEAppReducer.AECharacter.AEAvatarType
	local oldAvatarType = oldState.AEAppReducer.AECharacter.AEAvatarType

	if newAvatarType ~= oldAvatarType then
		self:switchAvatarType(newAvatarType)
	end

	if settings():GetFFlag("AvatarEditorUseNewCostumeLogic") then
		self.animationManager:checkForUpdate2(equippedIdsWithAssetType, unequippedIdsWithAssetType, newState, oldState)
	else
		self.animationManager:checkForUpdate(assetTypeIdToCheck, equippedId, unequippedId, newState, oldState)
	end
end

function AECharacterManager:replaceModel(oldModel, newModel)
	newModel.Parent = oldModel.Parent
	oldModel.Parent = nil
	oldModel:Destroy()
	return newModel
end

function AECharacterManager:loadAndEquipAsset(assetId, assetTypeId, isDefault)
	spawn(function()
		local assetModel = nil
		local _, err = pcall(function()
			assetModel = InsertService:LoadAsset(assetId)
		end)
		if err or (not assetModel) then
			warn (err)
			return
		end

		local equippedAssets = self.store:getState().AEAppReducer.AECharacter.AEEquippedAssets
		-- check to see the item is still equipped
		if not AEUtils.isAssetEquipped(assetId, assetTypeId, equippedAssets) and not isDefault then
			warn('Asset unequipped without getting a chance to get equipped.')
			assetModel:Destroy()
		end

		self:equipAsset(assetId, assetTypeId, assetModel)
		self:buildRig()
	end)
end

function AECharacterManager:equipTool(toolModel)
	self.currentCharacter.Humanoid:EquipTool(toolModel)
	self.animationManager:setToolAnimation(true)
end

function AECharacterManager:unequipTools(isPotentialSwap)
	if not isPotentialSwap then
		self.animationManager:setToolAnimation(false)
	end
	self.currentCharacter.Humanoid:UnequipTools()
end

function AECharacterManager:equipAsset(assetId, assetTypeId, assetModel)
	local modelChildren = assetModel:GetChildren()
	if modelChildren == nil then
		error('model is empty.')
	end

	for _, modelChild in pairs(modelChildren) do
		if isFolder(modelChild) then
			if modelChild.name == r15ModelFolder then
				local folderChildren = modelChild:GetChildren()
				for _, folderChild in pairs(folderChildren) do
					local modelToBeReplaced = self.r15Children[folderChild.name]
					if modelToBeReplaced then
						self:replaceModel(modelToBeReplaced, folderChild)
						self.r15Children[folderChild.name] = folderChild
					end
				end
				self.bodyColorManager:updateBodyColor(self.store:getState().AEAppReducer.AECharacter.AEBodyColors)
			elseif modelChild.name == r6ModelFolder then
				local folderChildren = modelChild:GetChildren()
				for _, folderChild in pairs(folderChildren) do
					local modelToBeReplaced = self.r6Children[assetTypeId]
					if modelToBeReplaced then
						self:replaceModel(modelToBeReplaced, folderChild)
					else
						folderChild.Parent = self.r6
					end
					self.r6Children[assetTypeId] = folderChild
				end
			end
		elseif isAccessory(modelChild) then
			local accessory = self.equippedAccessoryModels[assetId]

			if accessory then
				modelChild.Parent = nil
				modelChild:Destroy()
				return
			end

			self.equippedAccessoryModels[assetId] = modelChild
			modelChild.Parent = self.currentCharacter
		elseif isTool(modelChild) then
			disableScripts(modelChild)
			local tool = self.equippedToolModels[assetId]

			if tool then
				modelChild.Parent = nil
				modelChild:Destroy()
				return
			end

			self.equippedToolModels[assetId] = modelChild
			self:equipTool(modelChild)
		elseif assetTypeId == AEConstants.AssetTypes.Head then
			self.head = self:replaceModel(self.head, modelChild)
		elseif assetTypeId == AEConstants.AssetTypes.Face then
			self.face = self:replaceModel(self.face, modelChild)
		elseif assetTypeId == AEConstants.AssetTypes.Shirt then
			if self.shirt then
				self.shirt = self:replaceModel(self.shirt, modelChild)
			else
				self.shirt = modelChild
				self.shirt.Parent = self.currentCharacter
			end
		elseif assetTypeId == AEConstants.AssetTypes.Pants then
			if self.pants then
				self.pants = self:replaceModel(self.pants, modelChild)
			else
				self.pants = modelChild
				self.pants.Parent = self.currentCharacter
			end
		elseif AvatarEditorFixTShirtGraphic and assetTypeId == AEConstants.AssetTypes.TShirt then
			if self.tShirtGraphic then
				self.tShirtGraphic = self:replaceModel(self.tShirtGraphic, modelChild)
			else
				self.tShirtGraphic = modelChild
				self.tShirtGraphic.Parent = self.currentCharacter
			end
		end
	end
end

function AECharacterManager:unequipAsset(assetId, assetTypeId, isPotentialSwap)
	local accessory = self.equippedAccessoryModels[assetId]
	if accessory then
		self.equippedAccessoryModels[assetId] = nil
		accessory.Parent = nil
		accessory:Destroy()
		return
	end
	local tool = self.equippedToolModels[assetId]
	if tool then
		self.equippedToolModels[assetId] = nil
		self:unequipTools(isPotentialSwap)
		tool.Parent = nil
		tool:Destroy()
		return
	end

	if not isPotentialSwap then
		-- replace with default parts
		if assetTypeId == AEConstants.AssetTypes.Head then
			local clonedDefaultR15Head = self.defaultR15.Head.Mesh:Clone()
			self.head = self:replaceModel(self.head, clonedDefaultR15Head)
		elseif assetTypeId == AEConstants.AssetTypes.Face then
			local clonedDefaultR15Face = self.defaultR15.Head.face:Clone()
			self.face = self:replaceModel(self.face, clonedDefaultR15Face)
		elseif assetTypeId == AEConstants.AssetTypes.Shirt and self.shirt then
			self.shirt.Parent = nil
			self.shirt:Destroy()
			self.shirt = nil
		elseif assetTypeId == AEConstants.AssetTypes.Pants and self.pants then
			self.pants.Parent = nil
			self.pants:Destroy()
			self.pants = nil
		elseif AvatarEditorFixTShirtGraphic and assetTypeId == AEConstants.AssetTypes.TShirt
			and self.tShirtGraphic then
			self.tShirtGraphic.Parent = nil
			self.tShirtGraphic:Destroy()
			self.tShirtGraphic = nil
		else
			local r15Parts = AEConstants.R15TypePartMap[assetTypeId]
			if r15Parts then
				for _, partName in ipairs(r15Parts) do
					local defaultPart = self.defaultR15Children[partName]
					local currentPart = self.r15Children[partName]
					if defaultPart then
						local clonedPart = defaultPart:clone()
						self:replaceModel(currentPart, clonedPart)
						self.r15Children[partName] = clonedPart
					end
				end
				self:buildRig()
				self.bodyColorManager:updateBodyColor(self.store:getState().AEAppReducer.AECharacter.AEBodyColors)
			end

			local r6Part = self.r6Children[assetTypeId]
			if r6Part then
				r6Part.Parent = nil
				r6Part:Destroy()
				self.r6Children[assetTypeId] = nil
			end
		end
	end
end

function AECharacterManager:switchAvatarType(newType)
	local currentCharacter, oldCharacter
	if newType == AEConstants.AvatarType.R6 then
		currentCharacter = self.r6
		oldCharacter = self.r15
	else
		currentCharacter = self.r15
		oldCharacter = self.r6
	end
	currentCharacter.Parent = self.characterRoot
	oldCharacter.Parent = ReplicatedStorage
	if self.pants then
		self.pants.Parent = currentCharacter
	end
	if self.shirt then
		self.shirt.Parent = currentCharacter
	end
	if AvatarEditorFixTShirtGraphic and self.tShirtGraphic then
		self.tShirtGraphic.Parent = currentCharacter
	end

	local curHead = currentCharacter.Head.Mesh
	if curHead then
		curHead.Parent = nil
		curHead:Destroy()
	end
	self.head = self.head:clone()
	self.head.Parent = currentCharacter.Head

	local curFace = currentCharacter.Head.face
	if curFace then
		curFace.Parent = nil
		curFace:Destroy()
	end
	self.face = self.face:clone()
	self.face.Parent = currentCharacter.Head

	for _, accessory in pairs(self.equippedAccessoryModels) do
		accessory.Parent = currentCharacter
	end

	oldCharacter.Humanoid:UnequipTools()

	self.currentCharacter = currentCharacter
	self.store:dispatch(AESetCurrentCharacter(self.currentCharacter))

	for _, tool in pairs(self.equippedToolModels) do
		self:equipTool(tool)
	end
	-- New model needs to have the same rotation as the old model.
	local _, _, _, R00, R01, R02, R10, R11, R12, R20, R21, R22 = oldCharacter.HumanoidRootPart.CFrame:components()
	local currentCFrameP = self.currentCharacter.HumanoidRootPart.CFrame.p
	self.currentCharacter.HumanoidRootPart.CFrame = CFrame.new(currentCFrameP.X, currentCFrameP.Y, currentCFrameP.Z,
		R00, R01, R02, R10, R11, R12, R20, R21, R22)
	self:buildRig()
end

function AECharacterManager:buildRig()
	if self.currentCharacter == self.r15 then
		self.currentCharacter.Humanoid:BuildRigFromAttachments()
	end
end

function AECharacterManager:stop()
	self.r6.Parent = ReplicatedStorage
	self.r15.Parent = ReplicatedStorage

	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}

	self.animationManager:stop()
	self.bodyColorManager:stop()
	self.scalesManager:stop()
end

return AECharacterManager