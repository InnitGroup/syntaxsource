local AEBodyColorManager = {}
AEBodyColorManager.__index = AEBodyColorManager

local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local AESetWarningInformation = require(Modules.LuaApp.Thunks.AEThunks.AESetWarningInformation)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)

local BODY_COLOR_MAPPED_PARTS = {
	['Head'] = 'headColorId',

	['Torso'] = 'torsoColorId',
	['UpperTorso'] = 'torsoColorId',
	['LowerTorso'] = 'torsoColorId',

	['Left Arm'] = 'leftArmColorId',
	['LeftUpperArm'] = 'leftArmColorId',
	['LeftLowerArm'] = 'leftArmColorId',
	['LeftHand'] = 'leftArmColorId',

	['Left Leg'] = 'leftLegColorId',
	['LeftUpperLeg'] = 'leftLegColorId',
	['LeftLowerLeg'] = 'leftLegColorId',
	['LeftFoot'] = 'leftLegColorId',

	['Right Arm'] = 'rightArmColorId',
	['RightUpperArm'] = 'rightArmColorId',
	['RightLowerArm'] = 'rightArmColorId',
	['RightHand'] = 'rightArmColorId',

	['Right Leg'] = 'rightLegColorId',
	['RightUpperLeg'] = 'rightLegColorId',
	['RightLowerLeg'] = 'rightLegColorId',
	['RightFoot'] = 'rightLegColorId',
}

local function isBasePart(entity)
	return entity:IsA('BasePart')
end

function AEBodyColorManager.new(store, characterManager)
	local self = {}
	self.store = store
	self.connections = {}
	self.characterManager = characterManager

	setmetatable(self, AEBodyColorManager)

	local defaultClothesIndex = game.Players.LocalPlayer.UserId
		% #store:getState().AEAppReducer.AEDefaultClothingIds.defaultShirtAssetIds + 1
	self.defaultShirtId = store:getState().AEAppReducer.AEDefaultClothingIds.defaultShirtAssetIds[defaultClothesIndex]
	self.defaultPantsId = store:getState().AEAppReducer.AEDefaultClothingIds.defaultPantAssetIds[defaultClothesIndex]
	self.wearingDefaultShirt = false
	self.wearingDefaultPants = false
	self.warningId = 0
	self.checkBodyColors = true
	self.bodyColorsTooSimilar = false
	return self
end

function AEBodyColorManager:start()
	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	table.insert(self.connections, storeChangedConnection)

	self:manageDefaultClothing(self.store:getState().AEAppReducer.AECharacter.AEEquippedAssets)
	self:updateBodyColor(self.store:getState().AEAppReducer.AECharacter.AEBodyColors)
end

function AEBodyColorManager:checkIfWarningIsOpen(warningType)
	local warningInformation = self.store:getState().AEAppReducer.AEWarningInformation
	for _, warning in pairs(warningInformation) do
		if warning.warningType == warningType and warning.open then
			return true
		end
	end
	return false
end

-- Check for a change in body color
function AEBodyColorManager:update(newState, oldState)
	local newBodyColors = newState.AEAppReducer.AECharacter.AEBodyColors
	local oldBodyColors = oldState.AEAppReducer.AECharacter.AEBodyColors
	local newCharacter = newState.AEAppReducer.AECharacter.AECurrentCharacter
	local oldCharacter = oldState.AEAppReducer.AECharacter.AECurrentCharacter
	local curEquipped = newState.AEAppReducer.AECharacter.AEEquippedAssets
	local oldEquipped = oldState.AEAppReducer.AECharacter.AEEquippedAssets

	if newBodyColors ~= oldBodyColors then
		self.checkBodyColors = true
		self:manageDefaultClothing(curEquipped)
		self:updateBodyColor(newBodyColors)
	elseif newCharacter ~= oldCharacter then
		self:updateBodyColor(newBodyColors)
	end

	if curEquipped ~= oldEquipped then
		self:manageDefaultClothing(curEquipped)
	end
end

function AEBodyColorManager:checkBodyColorsForDefaultClothes()
	if not self.checkBodyColors then
		return self.bodyColorsTooSimilar
	end

	local minDeltaEDifference = self.store:getState().AEAppReducer
		.AEAvatarSettings[AEConstants.AvatarSettings.minDeltaBodyColorDifference]
	local rightLegColor = Color3.new(0, 0, 0)
	local leftLegColor = Color3.new(0, 0, 0)
	local torsoColor = Color3.new(0, 0, 0)
	local bodyColors = self.store:getState().AEAppReducer.AECharacter.AEBodyColors

	for index, value in pairs(bodyColors) do
		if index == "rightLegColorId" then
			rightLegColor = BrickColor.new(value).Color
		elseif index == "leftLegColorId" then
			leftLegColor = BrickColor.new(value).Color
		elseif index == "torsoColorId" then
			torsoColor = BrickColor.new(value).Color
		end
	end

	local minDeltaE = math.min(
		AEUtils.delta_CIEDE2000(rightLegColor, torsoColor),
		AEUtils.delta_CIEDE2000(leftLegColor, torsoColor))

	self.checkBodyColors = false
	self.bodyColorsTooSimilar = minDeltaE <= minDeltaEDifference
	return self.bodyColorsTooSimilar
end

function AEBodyColorManager:manageDefaultClothing(curEquipped)
	local wearingShirt = (curEquipped[AEConstants.AssetTypes.Shirt]
		and #curEquipped[AEConstants.AssetTypes.Shirt] > 0) and true or false
	local wearingPants = (curEquipped[AEConstants.AssetTypes.Pants]
		and #curEquipped[AEConstants.AssetTypes.Pants] > 0) and true or false
	local putOnDefaultClothing, tookOffDefaultClothing = false, false
	local bodyColorsTooSimilar = self:checkBodyColorsForDefaultClothes()

	if not self.wearingDefaultShirt and (not wearingShirt and not wearingPants) and bodyColorsTooSimilar then
		self.wearingDefaultShirt = true
		self.characterManager:loadAndEquipAsset(self.defaultShirtId, AEConstants.AssetTypes.Shirt, true)
		putOnDefaultClothing = true
	elseif self.wearingDefaultShirt and ((wearingShirt or wearingPants) or not bodyColorsTooSimilar) then
		self.wearingDefaultShirt = false
		self.characterManager:unequipAsset(self.defaultShirtId, AEConstants.AssetTypes.Shirt, false)
		tookOffDefaultClothing = true
	end
	if not self.wearingDefaultPants and not wearingPants and bodyColorsTooSimilar then
		self.wearingDefaultPants = true
		self.characterManager:loadAndEquipAsset(self.defaultPantsId, AEConstants.AssetTypes.Pants, true)
		putOnDefaultClothing = true
	elseif self.wearingDefaultPants and (wearingPants or not bodyColorsTooSimilar) then
		self.wearingDefaultPants = false
		self.characterManager:unequipAsset(self.defaultPantsId, AEConstants.AssetTypes.Pants, false)
		tookOffDefaultClothing = true
	end

	if putOnDefaultClothing then
		self.store:dispatch(AESetWarningInformation(true, AEConstants.WarningType.DEFAULT_CLOTHING))
	elseif tookOffDefaultClothing and self:checkIfWarningIsOpen(AEConstants.WarningType.DEFAULT_CLOTHING) then
		self.store:dispatch(AESetWarningInformation(false, AEConstants.WarningType.DEFAULT_CLOTHING))
	end
end

-- Loop through the character to find its body parts and update them.
function AEBodyColorManager:updateBodyColor(bodyColors)
	local currentCharacter = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter

	for _, part in pairs(currentCharacter:GetChildren()) do
		local validPart = BODY_COLOR_MAPPED_PARTS[part.Name]
		if isBasePart(part) and validPart then
			local bodyColorNumber = bodyColors[validPart]
			part.BrickColor = BrickColor.new(bodyColorNumber)
		end
	end
end

function AEBodyColorManager:stop()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}
end

return AEBodyColorManager