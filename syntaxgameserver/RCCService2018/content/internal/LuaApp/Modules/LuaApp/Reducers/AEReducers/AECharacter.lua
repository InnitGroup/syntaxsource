local Reducers = script.Parent
local AEAvatarType = require(Reducers.AEAvatarType)
local AEAvatarScales = require(Reducers.AEAvatarScales)
local AEBodyColors = require(Reducers.AEBodyColors)
local AEOwnedAssets = require(Reducers.AEOwnedAssets)
local AERecentAssets = require(Reducers.AERecentAssets)
local AEEquippedAssets = require(Reducers.AEEquippedAssets)
local AECurrentCharacter = require(Reducers.AECurrentCharacter)
local AEPlayingSwimAnimation = require(Reducers.AEPlayingSwimAnimation)

return function(state, action)
	state = state or {}

	return {
		AEAvatarType = AEAvatarType(state.AEAvatarType, action),
		AEAvatarScales = AEAvatarScales(state.AEAvatarScales, action),
		AEBodyColors = AEBodyColors(state.AEBodyColors, action),
		AEOwnedAssets = AEOwnedAssets(state.AEOwnedAssets, action),
		AERecentAssets = AERecentAssets(state.AERecentAssets, action),
		AEEquippedAssets = AEEquippedAssets(state.AEEquippedAssets, action),
		AECurrentCharacter = AECurrentCharacter(state.AECurrentCharacter, action),
		AEPlayingSwimAnimation = AEPlayingSwimAnimation(state.AEPlayingSwimAnimation, action),
	}
end
