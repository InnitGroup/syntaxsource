local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local Constants = require(Modules.LuaChat.Constants)
local formatInteger = require(Modules.LuaChat.Utils.formatInteger)

local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local TEXT_FONT = Enum.Font.SourceSans

local GAME_NAME_LABEL_HEIGHT = 20
local GAME_NAME_LABEL_TEXT_SIZE = 23
local GAME_NAME_LABEL_TEXT_COLOR = Constants.Color.GRAY1

local CREATOR_NAME_LABEL_HEIGHT = 14
local CREATOR_NAME_LABEL_TEXT_SIZE = 15
local CREATOR_NAME_LABEL_TOP_PADDING = 6
local CREATOR_NAME_LABEL_COLOR = Constants.Color.GRAY2

local SUBTITLE_LABEL_HEIGHT = 14
local SUBTITLE_LABEL_TEXT_SIZE = 14
local SUBTITLE_LABEL_TOP_PADDING = 3
local SUBTITLE_FRAME_HEIGHT = SUBTITLE_LABEL_HEIGHT + SUBTITLE_LABEL_TOP_PADDING

local ROBUX_ICON = "rbxasset://textures/ui/LuaChat/icons/ic-robux.png"
local ROBUX_ICON_SIZE = 12
local ROBUX_TO_PRICE_PADDING = 3

local PRICE_COLOR = Constants.Color.GREEN_PRIMARY

local FFlagLuaChatShareGameToChatFromChatV2 = settings():GetFFlag("LuaChatShareGameToChatFromChatV2")

local GameInformation = Roact.PureComponent:extend("GameInformation")

function GameInformation:render()
	local gameModel = self.props.gameModel
	if not gameModel then
		return nil
	end

	local gameTitle = gameModel.name
	local creatorName = gameModel.creatorName
	-- TODO wait lua app team store the playability of the game, default value is true
	-- Ticket: MOBLUAPP-683, Review http://swarm.roblox.local/reviews/226723/
	-- TODO: SOC-3779 This ticket has been committed since this comment.
	-- * New ticket: https://jira.roblox.com/browse/SOC-3779
	local playable = FFlagLuaChatShareGameToChatFromChatV2 or self.props.gameModel.isPlayable
	local gamePrice = gameModel.price
	local showPrice = gamePrice and playable

	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		Name = Roact.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = TEXT_FONT,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, GAME_NAME_LABEL_HEIGHT),
			Text = gameTitle,
			TextColor3 = GAME_NAME_LABEL_TEXT_COLOR,
			TextSize = GAME_NAME_LABEL_TEXT_SIZE,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),

		Creator = Roact.createElement(LocalizedTextLabel, {
			BackgroundTransparency = 1,
			Font = TEXT_FONT,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, CREATOR_NAME_LABEL_HEIGHT + CREATOR_NAME_LABEL_TOP_PADDING),
			Text = {"Feature.Chat.ShareGameToChat.By", creatorName = creatorName},
			TextColor3 = CREATOR_NAME_LABEL_COLOR,
			TextSize = CREATOR_NAME_LABEL_TEXT_SIZE,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
		}),

		NotAvailableTip = not playable and Roact.createElement(LocalizedTextLabel, {
			BackgroundTransparency = 1,
			Font = TEXT_FONT,
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, SUBTITLE_FRAME_HEIGHT),
			Text = "Feature.Chat.ShareGameToChat.GameNotAvailable",
			TextColor3 = CREATOR_NAME_LABEL_COLOR,
			TextSize = SUBTITLE_LABEL_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
		}),

		GamePrice = showPrice and Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, SUBTITLE_FRAME_HEIGHT),
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, ROBUX_TO_PRICE_PADDING),
			}),

			RobuxIcon = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				Image = ROBUX_ICON,
				LayoutOrder = 1,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.new(0, ROBUX_ICON_SIZE, 0, ROBUX_ICON_SIZE),
			}),

			Price = Roact.createElement("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -(ROBUX_ICON_SIZE + ROBUX_TO_PRICE_PADDING), 1, 0),
				Font = TEXT_FONT,
				LayoutOrder = 2,
				Text = formatInteger(gamePrice),
				TextColor3 = PRICE_COLOR,
				TextSize = SUBTITLE_LABEL_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}),
		}),
	})
end

return GameInformation