local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEEquipAsset = require(Modules.LuaApp.Components.Avatar.UI.AEEquipAsset)

local AEHatsColumn = Roact.PureComponent:extend("AEHatsColumn")

local HATS = "Hats"
local NUMBER_OF_ALLOWED_HATS = 3

local View = {
	[DeviceOrientationMode.Portrait] = {
		FRAME_SIZE = UDim2.new(0, 60, 0.8, 0),
		FRAME_POSITION = UDim2.new(0.05, 0, 0.1, 0),
		FULLVIEW_POSITION = UDim2.new(0, -70, 0.1, 0),
	},

	[DeviceOrientationMode.Landscape] = {
		FRAME_SIZE = UDim2.new(0, 60, 0, 240),
		FRAME_POSITION = UDim2.new(0, 20, 0, 24),
		FULLVIEW_POSITION = UDim2.new(0, -70, 0, 24),
	}
}

function AEHatsColumn:didUpdate(prevProps, prevState)
	if self.props.fullView and prevProps.deviceOrientation ~= self.props.deviceOrientation then
		self.ref.Position = View[self.props.deviceOrientation].FULLVIEW_POSITION
	elseif prevProps.fullView ~= self.props.fullView then
		local deviceOrientation = self.props.deviceOrientation
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
		local finalPosition = self.props.fullView and
		View[deviceOrientation].FULLVIEW_POSITION or
		View[deviceOrientation].FRAME_POSITION

		TweenService:Create(self.ref, tweenInfo, {
			Position = finalPosition,
		}):Play()
	end
end

function AEHatsColumn:render()
	self.deviceOrientation = self.props.deviceOrientation
	local categoryIndex = self.props.categoryIndex
	local tabsInfo = self.props.tabsInfo
	local analytics = self.props.analytics
	local page = AEUtils.getCurrentPage(categoryIndex, tabsInfo)
	local visible = page.name == HATS
	local hatSlots = {}
	for i = 1, NUMBER_OF_ALLOWED_HATS do
		hatSlots[i] = Roact.createElement(AEEquipAsset, {
			displayType = AEConstants.EquipAssetTypes.HatSlot,
			deviceOrientation = self.deviceOrientation,
			analytics = analytics,
			index = i,
			})
	end

	return Roact.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = View[self.deviceOrientation].FRAME_POSITION,
		Size = View[self.deviceOrientation].FRAME_SIZE,
		Visible = visible,
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),

		[Roact.Ref] = function(rbx)
			self.ref = rbx
		end,
		},
		hatSlots)
end

AEHatsColumn = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
			tabsInfo = state.AEAppReducer.AECategory.AETabsInfo,
			fullView = state.AEAppReducer.AEFullView,
		}
	end
)(AEHatsColumn)

return AEHatsColumn
