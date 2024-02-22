local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local FitChildren = require(Modules.LuaApp.FitChildren)
local FitTextLabel = require(Modules.LuaApp.Components.FitTextLabel)
local GameBasicStats = require(Modules.LuaApp.Components.Games.GameBasicStats)

-- TODO: needs actual font and font size (since we need to run size conversion)
local TITLE_FONT_SIZE = 32

local GameHeader = Roact.PureComponent:extend("GameHeader")

function GameHeader:render()
	local theme = self._context.AppTheme
	local gameDetail = self.props.gameDetail
	local votes = self.props.votes
	local layoutOrder = self.props.LayoutOrder

	local upVotes = votes ~= nil and votes.upVotes or nil
	local downVotes = votes ~= nil and votes.downVotes or nil

	return Roact.createElement(FitChildren.FitFrame, {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		fitAxis = FitChildren.FitAxis.Height,
	}, {
		ListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = Roact.createElement(FitTextLabel, {
			Size = UDim2.new(1, 0, 0, 0),
			Text = gameDetail.name,
			Font = theme.GameDetails.Text.BoldFont,
			TextSize = TITLE_FONT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = theme.GameDetails.Text.Color.Main,
			TextWrapped = true,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}),
		SubTitle = Roact.createElement(GameBasicStats, {
			playerCount = gameDetail.playing,
			upVotes = upVotes,
			downVotes = downVotes,
			settings = theme.GameDetails.GameBasicStats,
			LayoutOrder = 2,
		}),
	})
end

GameHeader = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			gameDetail = state.GameDetails[props.universeId],
			votes = state.GameVotes[props.universeId],
		}
	end
)(GameHeader)

return GameHeader