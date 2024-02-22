local Workspace = game:GetService("Workspace")

local AEParticleEffect = {}
AEParticleEffect.__index = AEParticleEffect

function AEParticleEffect.new(store)
	local self = {}
	self.store = store
	self.connections = {}
	setmetatable(self, AEParticleEffect)

	local particleTransparency = NumberSequence.new( {
		NumberSequenceKeypoint.new(0, 1, 0),
		NumberSequenceKeypoint.new(0.195, 0, 0),
		NumberSequenceKeypoint.new(0.783, 0.887, 0),
		NumberSequenceKeypoint.new(1, 1, 0) } )

	self.ParticleEmitterContainer = Instance.new('Part')
	self.ParticleEmitterContainer.Position = Vector3.new(14.197, 2.55, -18.644)
	self.ParticleEmitterContainer.Reflectance = 0
	self.ParticleEmitterContainer.Transparency = 1
	self.ParticleEmitterContainer.Name = 'AvatarEditorParticleEffectPart'
	self.ParticleEmitterContainer.Orientation = Vector3.new(0, 15, 0)
	self.ParticleEmitterContainer.Size = Vector3.new(4.2, 4.2, 1.8)
	self.ParticleEmitterContainer.Material = 'Plastic'
	self.ParticleEmitterContainer.Anchored = true
	self.ParticleEmitterContainer.CanCollide = false
	self.ParticleEmitterContainer.Parent = Workspace

	self.particleEmitter1 = Instance.new('ParticleEmitter')
	self.particleEmitter1.Color = ColorSequence.new(Color3.fromRGB(225, 227, 213))
	self.particleEmitter1.LightEmission = 0.35
	self.particleEmitter1.LightInfluence = 0
	self.particleEmitter1.Size = NumberSequence.new(2)
	self.particleEmitter1.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	self.particleEmitter1.Transparency = particleTransparency
	self.particleEmitter1.Speed = NumberRange.new(4, 8)
	self.particleEmitter1.Acceleration = Vector3.new(0,30,0)
	self.particleEmitter1.Lifetime = NumberRange.new(0.3, 0.4)
	self.particleEmitter1.Rate = 100
	self.particleEmitter1.Enabled = false
	self.particleEmitter1.Parent = self.ParticleEmitterContainer

	self.particleEmitter2 = Instance.new('ParticleEmitter')
	self.particleEmitter2.Color = ColorSequence.new(Color3.fromRGB(204, 209, 175))
	self.particleEmitter2.LightEmission = 0.35
	self.particleEmitter2.LightInfluence = 0
	self.particleEmitter2.Size = NumberSequence.new(2)
	self.particleEmitter2.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	self.particleEmitter2.Transparency = particleTransparency
	self.particleEmitter2.Speed = NumberRange.new(3, 6)
	self.particleEmitter2.Acceleration = Vector3.new(0,30,0)
	self.particleEmitter2.Lifetime = NumberRange.new(0.3, 0.4)
	self.particleEmitter2.Rate = 100
	self.particleEmitter2.Enabled = false
	self.particleEmitter2.ZOffset = 1
	self.particleEmitter2.Parent = self.ParticleEmitterContainer

	self.particleEmittionCount = 0

	return self
end

function AEParticleEffect:start()
	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	table.insert(self.connections, storeChangedConnection)
end

function AEParticleEffect:stop()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}
end

function AEParticleEffect:update(newState, oldState)
	local curEquipped = newState.AEAppReducer.AECharacter.AEEquippedAssets
	local oldEquipped = oldState.AEAppReducer.AECharacter.AEEquippedAssets
	local equippedChanged = curEquipped ~= oldEquipped

	local curAvatarType = newState.AEAppReducer.AECharacter.AEAvatarType
	local oldAvatarType = oldState.AEAppReducer.AECharacter.AEAvatarType
	local avatarTypeChanged = curAvatarType ~= oldAvatarType

	local curBodyColors = newState.AEAppReducer.AECharacter.AEBodyColors
	local oldBodyColors = oldState.AEAppReducer.AECharacter.AEBodyColors
	local bodyColorsChanged = curBodyColors ~= oldBodyColors

	if equippedChanged or avatarTypeChanged or bodyColorsChanged then
		self:runParticleEmitter()
	end
end

function AEParticleEffect:runParticleEmitter()
	spawn(function()
		self.particleEmitter1.Enabled = true
		self.particleEmitter2.Enabled = true
		self.particleEmittionCount = self.particleEmittionCount + 1
		local thisParticleEmittionCount = self.particleEmittionCount
		wait(.3)
		if self.particleEmittionCount == thisParticleEmittionCount then
			self.particleEmitter1.Enabled = false
			self.particleEmitter2.Enabled = false
		end
	end)
end

return AEParticleEffect
