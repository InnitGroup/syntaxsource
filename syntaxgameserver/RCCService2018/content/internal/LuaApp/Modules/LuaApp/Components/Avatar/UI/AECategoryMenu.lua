local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AEScreenRouter = require(Modules.LuaApp.Components.Avatar.AEScreenRouter)

local AECategoryMenu = Roact.PureComponent:extend("AECategoryMenu")

function AECategoryMenu:didUpdate(prevProps, prevState)
	local finalPosition = self.props.fullView and self.props.fullViewPosition or self.props.position
	if prevProps.deviceOrientation ~= self.props.deviceOrientation then
		self.ref.Position = finalPosition
	elseif prevProps.fullView ~= self.props.fullView then
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)

		TweenService:Create(self.ref, tweenInfo, {
			Position = finalPosition,
		}):Play()
	end
end

function AECategoryMenu:render()
	local deviceOrientation = self.props.deviceOrientation
	local size = self.props.size
	local position = self.props.position
	local zIndex = self.props.zIndex
	local AECategoryMenuOpen = AEScreenRouter:GetView(AEScreenRouter.Intent.AECategoryMenuOpen,
		AEScreenRouter.RouteMaps[deviceOrientation])
	local AECategoryMenuClosed = AEScreenRouter:GetView(AEScreenRouter.Intent.AECategoryMenuClosed,
		AEScreenRouter.RouteMaps[deviceOrientation])
	local isCategoryMenuOpen = self.props.isCategoryMenuOpen == AEConstants.CategoryMenuOpen.OPEN

	return Roact.createElement("Frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,

		[Roact.Ref] = function(rbx)
			self.ref = rbx
		end,
	} , {

		CategoryMenuOpen = Roact.createElement(AECategoryMenuOpen, {
			deviceOrientation = deviceOrientation,
			visible = isCategoryMenuOpen,
		}),

		CategoryMenuClosed = Roact.createElement(AECategoryMenuClosed, {
			deviceOrientation = deviceOrientation,
			visible = not isCategoryMenuOpen,
		})
	})
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			isCategoryMenuOpen = state.AEAppReducer.AECategory.AECategoryMenuOpen,
			fullView = state.AEAppReducer.AEFullView,
		}
	end
)(AECategoryMenu)