local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Modules = CoreGui.RobloxGui.Modules
local AEParticleEffect = require(Modules.LuaApp.Components.Avatar.AEParticleEffect)

local AESceneLoader = {}
AESceneLoader.__index = AESceneLoader

function AESceneLoader.new(store)
	local self = {}
	self.store = store
	setmetatable(self, AESceneLoader)

	self.RootScene = ReplicatedStorage:WaitForChild('AvatarEditorScene')
	self.ParticleEffect = AEParticleEffect.new(store)

	return self
end

function AESceneLoader:start()
	self.RootScene.Parent = game.Workspace
	self.ParticleEffect:start()
end

function AESceneLoader:stop()
	self.RootScene.Parent = ReplicatedStorage
	self.ParticleEffect:stop()
end

return AESceneLoader