local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local PADDING_LEFT = 25
local ICON_WIDTH = 26
local ICON_HEIGHT = 25
local ICON_TEXT_PADDING = 15
-- TODO: needs actual font and font size (since we need to run size conversion)
local FONT_SIZE = 22

-- TODO: needs actual assets
local FAVORITE_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-favorite.png"
local FAVORITED_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-favorite-filled.png"

local FavoriteButton = Roact.PureComponent:extend("FavoriteButton")

function FavoriteButton:init()
	self.state = {
		isButtonPressed = false,
	}

	self.onInputBegan = function()
		self:setState({
			isButtonPressed = true
		})
	end

	self.onInputEnded = function()
		self:setState({
			isButtonPressed = false
		})
	end

	self.onPositionChanged = function()
		if self.state.isButtonPressed then
			self:setState({
				isButtonPressed = false
			})
		end
	end
end

function FavoriteButton:render()
	local theme = self._context.AppTheme
	local position = self.props.Position
	local layoutOrder = self.props.LayoutOrder
	local font = self.props.Font
	local isFavorite = self.props.isFavorite
	local onActivated = self.props.onActivated
	local isButtonPressed = self.state.isButtonPressed

	local buttonBackgroundColor = isButtonPressed and theme.ContextualMenu.Cells.Background.OnPressColor or nil
	local buttonBackgroundTransparency = isButtonPressed and
		theme.ContextualMenu.Cells.Background.OnPressTransparency or 1

	return Roact.createElement("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = position,
			LayoutOrder = layoutOrder,
			Text = "",
			BackgroundColor3 = buttonBackgroundColor,
			BackgroundTransparency = buttonBackgroundTransparency,
			[Roact.Event.InputBegan] = self.onInputBegan,
			[Roact.Event.InputEnded] = self.onInputEnded,
			[Roact.Change.AbsolutePosition] = self.onPositionChanged,
			[Roact.Event.Activated] = onActivated,
		}, {
			ListLayout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			LeftPadding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, PADDING_LEFT),
			}),
			Icon = Roact.createElement("ImageLabel", {
				Size = UDim2.new(0, ICON_WIDTH, 0, ICON_HEIGHT),
				Image = isFavorite and FAVORITED_ICON or FAVORITE_ICON,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}),
			IconTextPadding = Roact.createElement("Frame", {
				Size = UDim2.new(0, ICON_TEXT_PADDING, 1, 0),
				LayoutOrder = 2,
				BackgroundTransparency = 1,
			}),
			Text = Roact.createElement(LocalizedTextLabel, {
				Size = UDim2.new(1, -(ICON_WIDTH + ICON_TEXT_PADDING), 0, FONT_SIZE),
				Text = isFavorite and "Feature.Favorites.Label.Favorited"
					or "Feature.Favorites.Label.Favorite",
				Font = font,
				TextSize = FONT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = theme.ContextualMenu.Cells.Content.Color,
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}),
		})
end

return FavoriteButton
