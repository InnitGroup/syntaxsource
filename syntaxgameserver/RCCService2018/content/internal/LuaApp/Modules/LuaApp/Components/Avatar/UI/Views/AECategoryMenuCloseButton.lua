local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESetCategoryMenuOpen = require(Modules.LuaApp.Actions.AEActions.AESetCategoryMenuOpen)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)

local AECategoryMenuCloseButton = Roact.PureComponent:extend("AECategoryMenuCloseButton")

function AECategoryMenuCloseButton:render()
	local setCategoryMenuClosed = self.props.setCategoryMenuClosed

	return Roact.createElement("ImageButton", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 45),
			Size = UDim2.new(0, 90, 0, 90),

			[Roact.Event.Activated] = function(rbx)
				setCategoryMenuClosed()
			end
		} , {
			ImageInfo = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 45, 0, 45),
				Size = UDim2.new(0, 28, 0, 28),
				Image = AESpriteSheet.getImage("ic-close").image,
				ImageRectSize = AESpriteSheet.getImage("ic-close").imageRectSize,
				ImageRectOffset = AESpriteSheet.getImage("ic-close").imageRectOffset,
			})
		})
end

return RoactRodux.UNSTABLE_connect2(
	function() return {} end,
	function(dispatch)
		return {
			setCategoryMenuClosed = function()
				dispatch(AESetCategoryMenuOpen(AEConstants.CategoryMenuOpen.CLOSED))
			end,
		}
	end
)(AECategoryMenuCloseButton)