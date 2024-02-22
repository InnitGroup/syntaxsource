local CoreGui = game:GetService("CoreGui")
local InsertService = game:GetService('InsertService')
local ContentProvider = game:GetService("ContentProvider")
local Modules = CoreGui.RobloxGui.Modules
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)
local AEPlayingSwimAnimation = require(Modules.LuaApp.Actions.AEActions.AEPlayingSwimAnimation)
local AvatarEditorFixLoadAnimation = settings():GetFFlag("AvatarEditorFixLoadAnimation")

local AEAnimationManager = {}
AEAnimationManager.__index = AEAnimationManager

local animTabIndexToAnimType = {
	[1] = 51,	-- Idle
	[2] = 55,	-- Walk
	[3] = 53,	-- Run
	[4] = 52,	-- Jump
	[5] = 50,	-- Fall
	[6] = 48,	-- Climb
	[7] = 54,	-- Swim
}

local ANIMATION_PAGE = 4
local RECENTS_PAGE = 1

local function isSwimAnimation(animationTrack)
	if animationTrack.Parent.Name == "swim" then
		return true
	else
		return false
	end
end

function AEAnimationManager.new(store)
	local self = {}
	self.store = store
	self.animationConnections = {}
	self.currentAnimationPreview = nil
	self.toolHoldAnimationTrack = nil
	self.animationData = {}
	self.currentId = 1
	self.loopId = 0
	self.indexOffset = false
	self.initialized = false
	self.lookAroundStopConnection = nil
	self.lookAroundLoopConnection = nil
	setmetatable(self, AEAnimationManager)
	return self
end

function AEAnimationManager:start()
	local currentCategoryIndex = self.store:getState().AEAppReducer.AECategory.AECategoryIndex
	local currentTab = self.store:getState().AEAppReducer.AECategory.AETabsInfo[currentCategoryIndex]
	self.initialized = true
	self.indexOffset = false
	spawn(function()
		local curEquipped = self.store:getState().AEAppReducer.AECharacter.AEEquippedAssets
		if curEquipped[AEConstants.AssetTypes.Gear] and curEquipped[AEConstants.AssetTypes.Gear][1] then
			self:setToolAnimation(true)
		end
		if currentCategoryIndex == ANIMATION_PAGE then
			self:playAnimation(self:getEquippedOrDefaultAnim(animTabIndexToAnimType[currentTab], currentCategoryIndex), true)
		else
			self:playAnimation(self:getEquippedOrDefaultAnim(AEConstants.animAssetTypes.idleAnim, RECENTS_PAGE), true)
		end
	end)
end

function AEAnimationManager:stopLastAnimation()
	if self.lookAroundTrack then
		self.lookAroundTrack:Stop()
	end

	if self.animationData[self.currentId] and self.animationData[self.currentId].currentTrack then
		if self.animationData[self.currentId].currentTrack.IsPlaying then
			self.animationData[self.currentId].currentTrack:Stop()
		end
		self.animationData[self.currentId].currentTrack:Destroy()
	end
	self.animationData[self.currentId] = nil
end

function AEAnimationManager:getRandomTrack(options, totalWeight)
	local chosenValue = math.random() * totalWeight
	for animation, weight in next, options do
		if chosenValue <= weight then
			return animation
		else
			chosenValue = chosenValue - weight
		end
	end
end

--[[
	Given animation assets, load and play an animation into the humanoid
	forceHeaviestAnim: If true this will never play the look around animation first.
	override: Force a specific animation to play, such as alternating between multiple ones.
]]
function AEAnimationManager:playAnimation(animationAssets, forceHeaviestAnim, override)
	if AvatarEditorFixLoadAnimation and not animationAssets then
		return
	end

	self:stopLastAnimation()
	self:stopAllAnimationConnections() -- Disconnect previous animation connection
	self.currentId = self.currentId + 1
	self.animationData[self.currentId] = {}
	local id = self.currentId -- This id will manage animations in this thread.
	local fadeInTime = 0.1
	self.animationData[id].currentAnimIndex = 1

	if self.indexOffset then
		 self.animationData[id].currentAnimIndex = self.animationData[id].currentAnimIndex % #animationAssets + 1
	end

	-- Get the animation to play (light/heavy animation)
	local animationTrack
	local possibleAnims = animationAssets[self.animationData[id].currentAnimIndex]:GetChildren()
	local options, totalWeight = self:getWeightedAnimations(possibleAnims)
	local firstAnim, firstWeight = nil, 0

	if AvatarEditorFixLoadAnimation then
		firstAnim, firstWeight = next(options)

		if not firstAnim then
			return nil
		end
	end

	if forceHeaviestAnim then
		local heaviestAnimation, heaviestWeight = firstAnim, firstWeight
		for animation, weight in pairs(options) do
			if weight > heaviestWeight then
				heaviestAnimation, heaviestWeight = animation, weight
			end
		end

		animationTrack = heaviestAnimation
	else
		animationTrack = self:getRandomTrack(options, totalWeight)
	end

	if override ~= nil then
		animationTrack = override
	end

	self.animationData[id].currentTrack = self:humanoidLoadAnimation(animationTrack)
	self.animationData[id].currentTrack.Looped = true
	self.animationData[id].currentTrack:Play(fadeInTime)

	local oldPlayingSwimAnimation = self.store:getState().AEAppReducer.AECharacter.AEPlayingSwimAnimation
	local currentPlayingSwimAnimation = isSwimAnimation(animationTrack)
	if oldPlayingSwimAnimation ~= currentPlayingSwimAnimation then
		self.store:dispatch(AEPlayingSwimAnimation(currentPlayingSwimAnimation))
	end

	self.animationConnections[#self.animationConnections + 1] =
		self.animationData[id].currentTrack.DidLoop:Connect(function()
		self.loopId = self.loopId + 1
		local possibleAnims = animationAssets[self.animationData[id].currentAnimIndex]:GetChildren()
		local options, totalWeight = self:getWeightedAnimations(possibleAnims)
		local newAnim = self:getRandomTrack(options, totalWeight)
		local changedOffset = false

		-- If there are multiple animations, switch between them.
		if self.loopId % 4 == 0 then
			if self.indexOffset then
				self.indexOffset = false
			else
				self.indexOffset = true
			end
			changedOffset = true
		end

		-- Check if animation should be switched to a different weight one.
		if changedOffset or newAnim ~= animationTrack then
			self:playAnimation(animationAssets, false, newAnim)
		end
	end)
end

-- Plays the "Look Around" animation, which is the lightest idle animation.
function AEAnimationManager:playLookAround(animationAssets, id)
	self:stopAllAnimationTracks()
	local assets = {}
	local assetId = self.store:getState().AEAppReducer.AECharacter.AEEquippedAssets[AEConstants.animAssetTypes.idleAnim]
	if assetId and assetId[1] then
		assets = self:loadAnimationObjects(assetId[1])
		if AvatarEditorFixLoadAnimation and not assets then
			-- Resume previous animation, don't play a nil look around animation.
			self:playAnimation(animationAssets, true)
			return
		end
	else
		table.insert(assets, self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter.Animations.idle)
	end

	-- Look around animation is the lightest idle animation.
	local options, _ = self:getWeightedAnimations(assets[1]:GetChildren())
	local lightestAnimation, lightestWeight
	for animation, weight in next, options do
		if lightestAnimation == nil or weight < lightestWeight then
			lightestAnimation, lightestWeight = animation, weight
		end
	end

	if self.lookAroundTrack then
		self.lookAroundTrack:Stop()
	end

	ContentProvider:PreloadAsync(animationAssets) -- Load the look around animation so it will play on first run.
	if lightestAnimation then
		self.lookAroundTrack = self:humanoidLoadAnimation(lightestAnimation)
		self.lookAroundTrack:Play(0)

		self.lookAroundStopConnection = self.lookAroundTrack.Stopped:Connect(function()
			self.lookAroundStopConnection:Disconnect()
			self.lookAroundTrack:Destroy()
		end)
		self.lookAroundLoopConnection = self.lookAroundTrack.DidLoop:Connect(function()
			self:playAnimation(animationAssets, true)
			self.lookAroundLoopConnection:Disconnect()
			self.lookAroundTrack:Destroy()
		end)
	end
end

-- Given possible animations, get the weight of each as well as the total weight.
function AEAnimationManager:getWeightedAnimations(possible)
	local options, totalWeight = {}, 0

	for _, animation in next, possible do
		local weight = animation:FindFirstChild('Weight')  and animation.Weight.Value or 1
		options[animation] = weight
		totalWeight = totalWeight + weight
	end

	return options, totalWeight
end

-- Load an animation into the humanoid.
function AEAnimationManager:humanoidLoadAnimation(animation)
	local humanoid = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter.Humanoid
	return humanoid:LoadAnimation(animation)
end

-- Return the default animation from the character model.
function AEAnimationManager:getDefaultAnimationAssets(assetTypeId, currentCharacter)
	local avatarType = self.store:getState().AEAppReducer.AECharacter.AEAvatarType
	local anims = {}

	if assetTypeId == AEConstants.AssetTypes.ClimbAnim then
		table.insert(anims, currentCharacter.Animations.climb)
	elseif assetTypeId == AEConstants.AssetTypes.FallAnim then
		table.insert(anims, currentCharacter.Animations.fall)
	elseif assetTypeId == AEConstants.AssetTypes.IdleAnim then
		table.insert(anims, currentCharacter.Animations.idle)
	elseif assetTypeId == AEConstants.AssetTypes.JumpAnim then
		table.insert(anims, currentCharacter.Animations.jump)
	elseif assetTypeId == AEConstants.AssetTypes.RunAnim then
		table.insert(anims, currentCharacter.Animations.run)
	elseif assetTypeId == AEConstants.AssetTypes.WalkAnim then
		table.insert(anims, currentCharacter.Animations.walk)
	elseif assetTypeId == AEConstants.AssetTypes.SwimAnim then
		if avatarType == AEConstants.AvatarType.R15 then
			table.insert(anims, currentCharacter.Animations.swim)
			table.insert(anims, currentCharacter.Animations.swimidle)
		else
			local swimAnim = currentCharacter.Animations.run:Clone()
			swimAnim.Name = 'swim'

			table.insert(anims, swimAnim)
		end
	end

	return anims
end

-- Pass the type of animation that should be displayed
function AEAnimationManager:getEquippedOrDefaultAnim(animIdType, currentCategoryIndex)
	local currentCharacter = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter
	local equippedAssets = self.store:getState().AEAppReducer.AECharacter.AEEquippedAssets
	local avatarType = self.store:getState().AEAppReducer.AECharacter.AEAvatarType
	local anim = equippedAssets[animIdType]

	if anim and anim[1] and currentCategoryIndex == ANIMATION_PAGE and avatarType == AEConstants.AvatarType.R15 then
		return self:loadAnimationObjects(anim[1])
	elseif currentCategoryIndex == ANIMATION_PAGE then
		return self:getDefaultAnimationAssets(animIdType, currentCharacter)
	else
		if equippedAssets[AEConstants.animAssetTypes.idleAnim] and equippedAssets[AEConstants.animAssetTypes.idleAnim][1]
			and avatarType == AEConstants.AvatarType.R15 then
			return self:loadAnimationObjects(equippedAssets[AEConstants.animAssetTypes.idleAnim][1])
		end
		return { currentCharacter.Animations.idle }
	end
end

-- Given an animation id, get the AnimationTrack.
function AEAnimationManager:loadAnimationObjects(assetId)
	if AvatarEditorFixLoadAnimation then
		if not assetId then
			return nil
		end

		local asset = InsertService:LoadAsset(assetId)

		if not asset or not asset:FindFirstChild("R15Anim") then
			return nil
		end

		return asset.R15Anim:GetChildren() -- Animation objects
	else
		local asset = InsertService:LoadAsset(assetId)
		return asset.R15Anim:GetChildren() -- Animation objects
	end
end

function AEAnimationManager:stopAllAnimationTracks()
	local humanoid = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter.Humanoid
	for _, animation in next, humanoid:GetPlayingAnimationTracks() do
		if animation ~= self.toolHoldAnimationTrack then
			animation:Stop()
		end
	end
end

function AEAnimationManager:setToolAnimation(toolEquipped)
	if self.initialized then
		local currentCharacter = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter
		if self.toolHoldAnimationTrack then
			self.toolHoldAnimationTrack:Stop()
			self.toolHoldAnimationTrack = nil
		end
		if toolEquipped then
			local animationsFolder = currentCharacter.Animations
			if animationsFolder then
				local toolHoldAnimationObject = animationsFolder.Tool
				if toolHoldAnimationObject then
					self.toolHoldAnimationTrack = self:humanoidLoadAnimation(toolHoldAnimationObject)
					self.toolHoldAnimationTrack:Play(0)
				end
			end
		end
	end
end

function AEAnimationManager:checkForUpdate(assetTypeId, equipped, unequipped, newState, oldState)
	local avatarType = newState.AEAppReducer.AECharacter.AEAvatarType
	local currentCategoryIndex = newState.AEAppReducer.AECategory.AECategoryIndex
	local currentTab = newState.AEAppReducer.AECategory.AETabsInfo[currentCategoryIndex]
	local canPlayAnimation = (currentCategoryIndex == ANIMATION_PAGE or currentCategoryIndex == RECENTS_PAGE)
		and avatarType == AEConstants.AvatarType.R15
	local equippedItem, unequippedAnimation, isAnimation, rebuiltCharacter, changedTab = false, false, false, false, false

	if avatarType ~= oldState.AEAppReducer.AECharacter.AEAvatarType then
		rebuiltCharacter = true
		local curEquipped = newState.AEAppReducer.AECharacter.AEEquippedAssets
		local toolEquipped = (curEquipped[AEConstants.AssetTypes.Gear] and curEquipped[AEConstants.AssetTypes.Gear][1])
			and true or false

		self:setToolAnimation(toolEquipped)
	end

	if newState.AEAppReducer.AECategory and oldState.AEAppReducer.AECategory and
		(newState.AEAppReducer.AECategory.AECategoryIndex ~= oldState.AEAppReducer.AECategory.AECategoryIndex or
		newState.AEAppReducer.AECategory.AETabsInfo ~= oldState.AEAppReducer.AECategory.AETabsInfo) then
		changedTab = true
	end

	if equipped then
		if AECategories.AssetTypeIdToCategory[assetTypeId] == AECategories.AssetCategory.ANIMATION then
			isAnimation = true
		else
			equippedItem = true
		end
	elseif unequipped then
		if AECategories.AssetTypeIdToCategory[assetTypeId] == AECategories.AssetCategory.ANIMATION then
			unequippedAnimation = true
		end
	end

	spawn(function()
		if isAnimation and canPlayAnimation then
			self.indexOffset = false
			self:playAnimation(self:loadAnimationObjects(equipped), true)
		elseif equippedItem or rebuiltCharacter then
			-- If an animation is currently equipped, then preview it
			local assets = self:getEquippedOrDefaultAnim(animTabIndexToAnimType[currentTab], currentCategoryIndex)
			self.indexOffset = false
			self:playAnimation(assets, true)
			if currentCategoryIndex ~= ANIMATION_PAGE then
				self:playLookAround(assets, self.currentId)
			end
		elseif changedTab or unequippedAnimation then
			self.indexOffset = false
			self:playAnimation(self:getEquippedOrDefaultAnim(animTabIndexToAnimType[currentTab], currentCategoryIndex), true)
		end
	end)
end

function AEAnimationManager:checkForUpdate2(equippedIds, unequippedIds, newState, oldState)
	local avatarType = newState.AEAppReducer.AECharacter.AEAvatarType
	local currentCategoryIndex = newState.AEAppReducer.AECategory.AECategoryIndex
	local currentTab = newState.AEAppReducer.AECategory.AETabsInfo[currentCategoryIndex]
	local canPlayAnimation = (currentCategoryIndex == ANIMATION_PAGE or currentCategoryIndex == RECENTS_PAGE)
		and avatarType == AEConstants.AvatarType.R15
	local equippedItem, unequippedAnimation, isAnimation, rebuiltCharacter, changedTab = false, false, false, false, false
	local idleAnim = nil
	local equipped = nil

	if avatarType ~= oldState.AEAppReducer.AECharacter.AEAvatarType then
		rebuiltCharacter = true
		local curEquipped = newState.AEAppReducer.AECharacter.AEEquippedAssets
		local toolEquipped = (curEquipped[AEConstants.AssetTypes.Gear] and curEquipped[AEConstants.AssetTypes.Gear][1])
			and true or false

		self:setToolAnimation(toolEquipped)
	end

	if newState.AEAppReducer.AECategory and oldState.AEAppReducer.AECategory and
		(newState.AEAppReducer.AECategory.AECategoryIndex ~= oldState.AEAppReducer.AECategory.AECategoryIndex or
		newState.AEAppReducer.AECategory.AETabsInfo ~= oldState.AEAppReducer.AECategory.AETabsInfo) then
		changedTab = true
	end

	for assetTypeId, assetIds in pairs(equippedIds) do
		for _, assetId in ipairs(assetIds) do
			if AECategories.AssetTypeIdToCategory[assetTypeId] == AECategories.AssetCategory.ANIMATION then
				isAnimation = true
				equipped = assetId
				-- If an outfit had a new idle animation, keep the id to play it.
				if assetTypeId == AEConstants.AssetTypes.IdleAnim then
					idleAnim = assetId
				end
			else
				equippedItem = true
			end
		end
	end

	for assetTypeId, assetIds in pairs(unequippedIds) do
		if #assetIds > 0 and AECategories.AssetTypeIdToCategory[assetTypeId] == AECategories.AssetCategory.ANIMATION then
			unequippedAnimation = true
		end
	end

	spawn(function()
		if isAnimation and canPlayAnimation then
			self.indexOffset = false
			self:playAnimation(self:loadAnimationObjects(equipped), true)
		elseif equippedItem or rebuiltCharacter then
			-- If an animation is currently equipped, then preview it
			local assets = self:getEquippedOrDefaultAnim(animTabIndexToAnimType[currentTab], currentCategoryIndex)
			self.indexOffset = false
			self:playAnimation(assets, true)
			if currentCategoryIndex ~= ANIMATION_PAGE then
				self:playLookAround(assets, self.currentId)
			end
		elseif changedTab or unequippedAnimation then
			self.indexOffset = false
			self:playAnimation(self:getEquippedOrDefaultAnim(animTabIndexToAnimType[currentTab], currentCategoryIndex), true)
		elseif idleAnim then
			self:playAnimation(self:loadAnimationObjects(idleAnim), true)
		end
	end)
end

function AEAnimationManager:stopAllAnimationConnections()
	for _, connection in ipairs(self.animationConnections) do
		connection:Disconnect()
	end
	self.animationConnections = {}
end

function AEAnimationManager:stop()
	self:stopAllAnimationConnections()
end

return AEAnimationManager