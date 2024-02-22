local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Common = Modules.Common
local Roact = require(Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local SocialMediaButton = require(Modules.LuaApp.Components.GameDetails.SocialMediaButton)

local MEDIA_BUTTON_SIZE = 44
local MEDIA_BUTTON_INTERVAL = 20

local SocialMediaGroup = Roact.PureComponent:extend("SocialMediaGroup")

function SocialMediaGroup:render()
	local layoutOrder = self.props.LayoutOrder
	local socialLinks = self.props.socialLinks

	if not socialLinks or #socialLinks == 0 then
		return nil
	end

	local socialButtons = {
		ListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, MEDIA_BUTTON_INTERVAL),
		})
	}

	for i, item in ipairs(self.props.socialLinks) do
		local elementName = "SocialButton_" .. item.type
		socialButtons[elementName] = Roact.createElement(SocialMediaButton, {
			Size = UDim2.new(0, MEDIA_BUTTON_SIZE, 0, MEDIA_BUTTON_SIZE),
			LayoutOrder = i,
			socialType = item.type,
			socialUrl = item.url,
		})
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, MEDIA_BUTTON_SIZE),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
	}, socialButtons)
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			socialLinks = state.GameSocialLinks[props.universeId],
		}
	end
)(SocialMediaGroup)
