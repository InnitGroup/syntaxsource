local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local AEGrantAsset = require(Modules.LuaApp.Thunks.AEThunks.AEGrantAsset)
local AERevokeAsset = require(Modules.LuaApp.Thunks.AEThunks.AERevokeAsset)

local AvatarEditorEventReceiver = Roact.Component:extend("AvatarEditorEventReceiver")

local GRANT = "Grant"
local REVOKE = "Revoke"

function AvatarEditorEventReceiver:init()
	local robloxEventReceiver = self.props.RobloxEventReceiver
	local grantAsset = self.props.grantAsset
	local revokeAsset = self.props.revokeAsset

	self.tokens = {
		robloxEventReceiver:observeEvent("AvatarAssetOwnershipNotifications", function(detail)
			if detail.Type == GRANT then
				grantAsset(detail.AssetTypeId, detail.AssetId)
			elseif detail.Type == REVOKE then
				revokeAsset(detail.AssetTypeId, detail.AssetId)
			end
		end),
	}
end

function AvatarEditorEventReceiver:render()
end

function AvatarEditorEventReceiver:willUnmount()
	for _, connection in pairs(self.tokens) do
		connection:Disconnect()
	end
end

return RoactRodux.UNSTABLE_connect2(
	nil,
	function(dispatch)
		return {
			grantAsset = function(assetTypeId, assetId)
				return dispatch(AEGrantAsset(assetTypeId, assetId))
			end,
			revokeAsset = function(assetTypeId, assetId)
				return dispatch(AERevokeAsset(assetTypeId, assetId))
			end,
		}
	end
)(AvatarEditorEventReceiver)