-- This is a very dummy version of the component.
-- Theoratically we're supposed to share this component with
-- the new game card design. We should rewrite this later.

local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactLocalization = require(Modules.LuaApp.Services.RoactLocalization)

local abbreviateCount = require(Modules.LuaApp.abbreviateCount)

local FitChildren = require(Modules.LuaApp.FitChildren)
local FitTextLabel = require(Modules.LuaApp.Components.FitTextLabel)

local TOTAL_HEIGHT = 22
-- TODO: needs actual font and font size (since we need to run size conversion)
local TEXT_FONT_SIZE = 22

local UPVOTE_ICON_RIGHT_PADDING = 5
local PLAYING_ICON_RIGHT_PADDING = 3
local UPVOATE_PLAYING_PADDING = 13
local ICON_SIZE = UDim2.new(0, 17, 0, 17)

-- TODO: replace with actual assets
local UPVOTE_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-thumbs-up.png"
local PLAYING_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-profile.png"

local GameBasicStats = Roact.PureComponent:extend("GameBasicStats")

function GameBasicStats:render()
	local playerCount = self.props.playerCount
	local upVotes = self.props.upVotes
	local downVotes = self.props.downVotes
	local settings = self.props.settings
	local position = self.props.Position
	local layoutOrder = self.props.LayoutOrder
	local localization = self.props.localization

	local playerCountText = abbreviateCount(playerCount, localization:GetLocale())

	local votePercentageText = "--"

	if upVotes == nil or upVotes < 0 then
		upVotes = 0
	end

	if downVotes == nil or downVotes < 0 then
		downVotes = 0
	end

	local totalVotes = upVotes + downVotes

	if totalVotes > 0 then
		votePercentageText = math.floor(upVotes / totalVotes * 100) .. '%'
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, TOTAL_HEIGHT),
		Position = position,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		upVotesIcon = Roact.createElement("ImageLabel", {
			Size = ICON_SIZE,
			BackgroundTransparency = 1,
			Image = UPVOTE_ICON,
			ImageColor3 = settings.Color,
			ImageTransparency = settings.Transparency,
			LayoutOrder = 1,
		}),
		Padding1 = Roact.createElement("Frame", {
			Size = UDim2.new(0, UPVOTE_ICON_RIGHT_PADDING, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}),
		upVotesText = Roact.createElement(FitTextLabel, {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = votePercentageText,
			Font = settings.Font,
			TextSize = TEXT_FONT_SIZE,
			TextColor3 = settings.Color,
			TextTransparency = settings.Transparency,
			fitAxis = FitChildren.FitAxis.Width,
			LayoutOrder = 3,
		}),
		Padding2 = Roact.createElement("Frame", {
			Size = UDim2.new(0, UPVOATE_PLAYING_PADDING, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
		}),
		PlayingIcon = Roact.createElement("ImageLabel", {
			Size = ICON_SIZE,
			BackgroundTransparency = 1,
			Image = PLAYING_ICON,
			ImageColor3 = settings.Color,
			ImageTransparency = settings.Transparency,
			LayoutOrder = 5,
		}),
		Padding3 = Roact.createElement("Frame", {
			Size = UDim2.new(0, PLAYING_ICON_RIGHT_PADDING, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 6,
		}),
		PlayingText = Roact.createElement(FitTextLabel, {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = playerCountText,
			Font = settings.Font,
			TextSize = TEXT_FONT_SIZE,
			TextColor3 = settings.Color,
			TextTransparency = settings.Transparency,
			fitAxis = FitChildren.FitAxis.Width,
			LayoutOrder = 7,
		}),
	})
end

GameBasicStats = RoactServices.connect({
	localization = RoactLocalization,
})(GameBasicStats)

return GameBasicStats