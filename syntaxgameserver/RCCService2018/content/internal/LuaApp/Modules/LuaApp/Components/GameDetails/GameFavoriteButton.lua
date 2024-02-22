local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)

local FavoriteButton = require(Modules.LuaApp.Components.FavoriteButton)

local SetGameFavorite = require(Modules.LuaApp.Actions.SetGameFavorite)
local GamePostFavorite = require(Modules.LuaApp.Thunks.GamePostFavorite)

local GameFavoriteButton = Roact.PureComponent:extend("GameFavoriteButton")

function GameFavoriteButton:init()
	self.onActivated = function()
		local universeId = self.props.universeId
		local isFavorite = self.props.isFavorite
		local gamePostFavorite = self.props.gamePostFavorite
		local setGameFavorite = self.props.setGameFavorite
		local networking = self.props.networking

		setGameFavorite(universeId, not isFavorite)
		gamePostFavorite(networking, universeId, not isFavorite)
	end
end

function GameFavoriteButton:render()
	local theme = self._context.AppTheme
	local position = self.props.Position
	local layoutOrder = self.props.LayoutOrder
	local isFavorite = self.props.isFavorite

	return Roact.createElement(FavoriteButton, {
		Position = position,
		LayoutOrder = layoutOrder,
		Font = theme.GameDetails.Text.Font,
		isFavorite = isFavorite,
		onActivated = self.onActivated,
	})
end

GameFavoriteButton = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			isFavorite = state.GameFavorites[props.universeId] or false,
		}
	end,
	function(dispatch)
		return {
			gamePostFavorite = function(networking, universeId, isFavorite)
				return dispatch(GamePostFavorite(networking, universeId, isFavorite))
			end,
			setGameFavorite = function(universeId, isFavorite)
				return dispatch(SetGameFavorite(universeId, isFavorite))
			end,
		}
	end
)(GameFavoriteButton)


return RoactServices.connect({
	networking = RoactNetworking,
})(GameFavoriteButton)
