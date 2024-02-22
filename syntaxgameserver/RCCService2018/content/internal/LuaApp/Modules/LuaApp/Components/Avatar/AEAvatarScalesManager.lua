local AEAvatarScalesManager = {}
AEAvatarScalesManager.__index = AEAvatarScalesManager

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local BODY_DEPTH_SCALE = 'BodyDepthScale'
local BODY_HEIGHT_SCALE = 'BodyHeightScale'
local BODY_WIDTH_SCALE = 'BodyWidthScale'
local BODY_TYPE_SCALE = 'BodyTypeScale'
local BODY_PROPORTION_SCALE = 'BodyProportionScale'
local HEAD_SCALE = 'HeadScale'
local HEIGHT_BASE = 0.71

function AEAvatarScalesManager.new(store, characterCFrame)
	local self = {}
	self.store = store
	self.connections = {}
	setmetatable(self, AEAvatarScalesManager)

	self.scaleTags = {}
	self.characterCFrame = characterCFrame

	return self
end

function AEAvatarScalesManager:start()
	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	table.insert(self.connections, storeChangedConnection)

	local scales = self.store:getState().AEAppReducer.AECharacter.AEAvatarScales
	local currentCharacter = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter
	local avatarType = self.store:getState().AEAppReducer.AECharacter.AEAvatarType

	if avatarType == AEConstants.AvatarType.R15 then
		self:applyChanges(scales, currentCharacter)
	end
end

function AEAvatarScalesManager:stop()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}
end

function AEAvatarScalesManager:applyScaleProperty(name, scale, humanoid)
	if not self.scaleTags[name] then
		self.scaleTags[name] = Instance.new('NumberValue')
		self.scaleTags[name].Name = name
		self.scaleTags[name].Parent = humanoid
	end
	self.scaleTags[name].Value = scale
end

function AEAvatarScalesManager:adjustHeightToStandOnPlatform(character)
	local hrp = character.HumanoidRootPart
	local humanoid = character.Humanoid
	local heightBonus = hrp.Size.y * 0.5 + humanoid.HipHeight
	local _,_,_, r0,r1,r2, r3,r4,r5, r6,r7,r8 = hrp.CFrame:components()

	hrp.CFrame = CFrame.new(self.characterCFrame.x, heightBonus + HEIGHT_BASE, self.characterCFrame.z,
		r0,r1,r2, r3,r4,r5, r6,r7,r8)
end

function AEAvatarScalesManager:update(newState, oldState)
	local newScales = newState.AEAppReducer.AECharacter.AEAvatarScales
	local oldScales = oldState.AEAppReducer.AECharacter.AEAvatarScales
	local currentCharacter = newState.AEAppReducer.AECharacter.AECurrentCharacter
	local newAvatarType = newState.AEAppReducer.AECharacter.AEAvatarType
	local oldAvatarType = oldState.AEAppReducer.AECharacter.AEAvatarType

	if newAvatarType == AEConstants.AvatarType.R15 and (newScales ~= oldScales or newAvatarType ~= oldAvatarType) then
		self:applyChanges(newScales, currentCharacter)
	end
end

function AEAvatarScalesManager:applyChanges(newScales)
	local currentCharacter = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter
	local humanoid = currentCharacter.Humanoid

	self:applyScaleProperty(BODY_DEPTH_SCALE, newScales.depth, humanoid)
	self:applyScaleProperty(BODY_HEIGHT_SCALE, newScales.height, humanoid)
	self:applyScaleProperty(BODY_WIDTH_SCALE, newScales.width, humanoid)
	self:applyScaleProperty(HEAD_SCALE, newScales.head, humanoid)
	self:applyScaleProperty(BODY_TYPE_SCALE, newScales.bodyType, humanoid)
	self:applyScaleProperty(BODY_PROPORTION_SCALE, newScales.proportion, humanoid)
	humanoid:BuildRigFromAttachments()
	self:adjustHeightToStandOnPlatform(currentCharacter)
end

return AEAvatarScalesManager