local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AELoader = require(Modules.LuaApp.Components.Avatar.AELoader)

local RoactAvatarEditorWrapper = Roact.Component:extend("RoactAvatarEditorWrapper")

function RoactAvatarEditorWrapper:render()
	return Roact.createElement(AELoader, self.props)
end

RoactAvatarEditorWrapper = RoactRodux.connect(function(store, props)
	return {
		store = store
	}
end)(RoactAvatarEditorWrapper)

return RoactAvatarEditorWrapper