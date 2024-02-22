local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Common = Modules.Common
local LuaApp = Modules.LuaApp

local AppGuiService = require(LuaApp.Services.AppGuiService)
local Constants = require(LuaApp.Constants)
local FitChildren = require(LuaApp.FitChildren)
local FormFactor = require(LuaApp.Enum.FormFactor)
local GameButton = require(LuaApp.Components.GameButton)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)
local NotificationType = require(LuaApp.Enum.NotificationType)

local Roact = require(Common.Roact)
local RoactRodux = require(Common.RoactRodux)
local RoactServices = require(LuaApp.RoactServices)
local RoactAnalyticsHomePage = require(LuaApp.Services.RoactAnalyticsHomePage)
local FeatureContext = require(LuaApp.Enum.FeatureContext)
local Text = require(Common.Text)

local GAME_BUTTON_SIZE = 94
local GAME_ICON_SIZE = 90
local PHONE_PADDING = 15
local TABLET_PADDING = 12
local GAME_NAME_LABEL_HEIGHT = 40
local SEPARATOR_HEIGHT = 1
local SEPARATOR_COLOR = Constants.Color.GRAY4

local GAME_TITLE_TOP_PADDING = 12
local GAME_TITLE_BOTTOM_PADDING = 24
local GAME_TITLE_COLOR = Constants.Color.GRAY1

local DEFAULT_BACKGROUND_COLOR = Constants.Color.WHITE
local DEFAULT_BUTTON_HEIGHT = 32
local DEFAULT_TEXT_FONT = Enum.Font.SourceSans
local DEFAULT_TEXT_SIZE = 20

local VIEW_GAME_DETAILS_FROM_ICON = Constants.AnalyticsKeyword.VIEW_GAME_DETAILS_FROM_ICON
local VIEW_GAME_DETAILS_FROM_TITLE = Constants.AnalyticsKeyword.VIEW_GAME_DETAILS_FROM_TITLE

local TextMeasureTemporaryPatch = settings():GetFFlag("TextMeasureTemporaryPatch")

local UserActiveGame = Roact.PureComponent:extend("UserActiveGame")

local function Separator(props)
	local layoutOrder = props.layoutOrder

	return Roact.createElement("Frame", {
		BackgroundColor3 = SEPARATOR_COLOR,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, SEPARATOR_HEIGHT),
	})
end

function UserActiveGame:init()
	self.openGameDetails = function(fromWhere)
		local guiService = self.props.guiService
		local analytics = self.props.analytics
		local friend = self.props.friend
		local index = self.props.index
		local universePlaceInfo = self.props.universePlaceInfo
		local dismissContextualMenu = self.props.dismissContextualMenu
		local featureContext = self.props.featureContext

		local rootPlaceId = universePlaceInfo.universeRootPlaceId
		local placeId = universePlaceInfo.placeId

		if placeId then
			if featureContext == FeatureContext.PeopleList then
				analytics.reportViewProfileFromPeopleList(friend.id, index, rootPlaceId, fromWhere)
			end
			dismissContextualMenu()
			guiService:BroadcastNotification(
				placeId,
				NotificationType.VIEW_GAME_DETAILS_ANIMATED
			)
		end
	end

	self.getGameTitleHeight = function(text, font, textSize, maxWidth)
		local gameTitleHeight = Text.GetTextHeight(text, font, textSize, maxWidth)

		-- TODO(CLIPLAYEREX-1633): We can remove this padding patch after fixing TextService:GetTextSize sizing bug
		-- When the flag TextMeasureTemporaryPatch is on, Text.GetTextHeight() would add 2px to the total height
		-- For getting the correct height, 2px need to subtracting from here.
		if TextMeasureTemporaryPatch then
			gameTitleHeight = gameTitleHeight - 2
		end

		return math.min(GAME_NAME_LABEL_HEIGHT, gameTitleHeight)
	end
end

function UserActiveGame:createGameNameButton(height, gameName, textXAlignment, textYAlignment)
	return Roact.createElement("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = DEFAULT_TEXT_FONT,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, height),
		Text = gameName,
		TextColor3 = GAME_TITLE_COLOR,
		TextSize = DEFAULT_TEXT_SIZE,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = true,
		TextXAlignment = textXAlignment,
		TextYAlignment = textYAlignment,

		[Roact.Event.Activated] = function()
			self.openGameDetails(VIEW_GAME_DETAILS_FROM_TITLE)
		end,
	})
end

function UserActiveGame:renderPhone()
	local layoutOrder = self.props.layoutOrder
	local width = self.props.width
	local universeId = self.props.universeId
	local friend = self.props.friend
	local index = self.props.index
	local dismissContextualMenu = self.props.dismissContextualMenu
	local featureContext = self.props.featureContext
	local gameThumbnail = self.props.gameThumbnail
	local universePlaceInfo = self.props.universePlaceInfo
	local headerRef = self.props[Roact.Ref]

	local gameName = universePlaceInfo and universePlaceInfo.name or ""

	local maxWidth = width - 2 * PHONE_PADDING
	local gameNameHeight = self.getGameTitleHeight(gameName, DEFAULT_TEXT_FONT, DEFAULT_TEXT_SIZE, maxWidth)
	local iconPadding = (GAME_BUTTON_SIZE - GAME_ICON_SIZE) / 2
	local widthOffset = -2 * PHONE_PADDING

	return Roact.createElement(FitChildren.FitFrame, {
		BackgroundTransparency = 1,
		fitAxis = FitChildren.FitAxis.Height,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 0),
		[Roact.Ref] = headerRef,
	}, {
		GameContent = Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			fitAxis = FitChildren.FitAxis.Height,
			Size = UDim2.new(1, 0, 0, 0),
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			GameIcon = Roact.createElement("Frame", {
				BackgroundColor3 = DEFAULT_BACKGROUND_COLOR,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.new(0, GAME_BUTTON_SIZE, 0, GAME_BUTTON_SIZE),
			}, {
				Icon = Roact.createElement(ImageSetButton, {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = gameThumbnail,
					Position = UDim2.new(0, iconPadding, 0, iconPadding),
					Size = UDim2.new(0, GAME_ICON_SIZE, 0, GAME_ICON_SIZE),

					[Roact.Event.Activated] = function()
						self.openGameDetails(VIEW_GAME_DETAILS_FROM_ICON)
					end,
				}),
			}),

			GameName = Roact.createElement(FitChildren.FitFrame, {
				BackgroundTransparency = 1,
				fitAxis = FitChildren.FitAxis.Height,
				LayoutOrder = 2,
				Size = UDim2.new(1, widthOffset, 0, 0),
			},{
				Layout = Roact.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				}),

				NameButton = self:createGameNameButton(
					gameNameHeight,
					gameName,
					Enum.TextXAlignment.Center,
					Enum.TextYAlignment.Center
				),

				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, GAME_TITLE_TOP_PADDING),
				}),
			}),

			InteractiveButton = Roact.createElement(FitChildren.FitFrame, {
				BackgroundTransparency = 1,
				fitAxis = FitChildren.FitAxis.Height,
				LayoutOrder = 3,
				Size = UDim2.new(1, widthOffset, 0, 0),
			},{
				Layout = Roact.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				}),

				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, GAME_TITLE_BOTTOM_PADDING),
				}),

				Button = Roact.createElement(GameButton, {
					maxWidth = maxWidth,
					universeId = universeId,
					friend = friend,
					index = index,
					callbackOnOpenGameDetails = dismissContextualMenu,
					callbackOnJoinGame = dismissContextualMenu,
					featureContext = featureContext,
				}),
			}),

			Separator = Roact.createElement(FitChildren.FitFrame, {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 5,
				fitAxis = FitChildren.FitAxis.Height,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				Line = Roact.createElement(Separator, {
					layoutOrder = 2,
				}),

				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, GAME_TITLE_BOTTOM_PADDING - SEPARATOR_HEIGHT),
				})
			}),
		}),

		Background = Roact.createElement("Frame", {
			BackgroundColor3 = DEFAULT_BACKGROUND_COLOR,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -GAME_BUTTON_SIZE / 2),
			Position = UDim2.new(0, 0, 0, GAME_BUTTON_SIZE / 2),
		}),
	})
end

function UserActiveGame:renderTablet()
	local layoutOrder = self.props.layoutOrder
	local width = self.props.width
	local universeId = self.props.universeId
	local friend = self.props.friend
	local index = self.props.index
	local dismissContextualMenu = self.props.dismissContextualMenu
	local featureContext = self.props.featureContext
	local gameThumbnail = self.props.gameThumbnail
	local universePlaceInfo = self.props.universePlaceInfo
	local headerRef = self.props[Roact.Ref]

	local gameName = universePlaceInfo and universePlaceInfo.name or ""

	local maxWidth = width - 3 * TABLET_PADDING - GAME_ICON_SIZE
	local buttonTopPadding = GAME_ICON_SIZE - GAME_NAME_LABEL_HEIGHT - DEFAULT_BUTTON_HEIGHT

	return Roact.createElement(FitChildren.FitFrame, {
		BackgroundColor3 = DEFAULT_BACKGROUND_COLOR,
		BorderSizePixel = 0,
		fitAxis = FitChildren.FitAxis.Height,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(0, width, 0, 0),
		[Roact.Ref] = headerRef,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		GameContent = Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.WHITE,
			fitAxis = FitChildren.FitAxis.Height,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 0),
		},{
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, TABLET_PADDING),
				PaddingLeft = UDim.new(0, TABLET_PADDING),
				PaddingRight = UDim.new(0, TABLET_PADDING),
				PaddingBottom = UDim.new(0, TABLET_PADDING - 1),
			}),

			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, PHONE_PADDING),
			}),

			GameIcon = Roact.createElement(ImageSetButton, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Image = gameThumbnail,
				Size = UDim2.new(0, GAME_ICON_SIZE, 0, GAME_ICON_SIZE),

				[Roact.Event.Activated] = function()
					self.openGameDetails(VIEW_GAME_DETAILS_FROM_ICON)
				end,
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, TABLET_PADDING),
				}),
			}),

			GameInfo = Roact.createElement(FitChildren.FitFrame, {
				BackgroundTransparency = 1,
				fitAxis = FitChildren.FitAxis.Height,
				LayoutOrder = 2,
				Size = UDim2.new(1, -PHONE_PADDING - GAME_ICON_SIZE, 0, 0),
			}, {
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				NameButton = self:createGameNameButton(
					GAME_NAME_LABEL_HEIGHT,
					gameName,
					Enum.TextXAlignment.Left,
					Enum.TextYAlignment.Top
				),

				InteractiveButton = Roact.createElement(FitChildren.FitFrame, {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = 2,
					fitAxis = FitChildren.FitAxis.Height,
				}, {
					Layout = Roact.createElement("UIListLayout", {
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
					}),

					Button = Roact.createElement(GameButton, {
						layoutOrder = 3,
						maxWidth = maxWidth,
						universeId = universeId,
						friend = friend,
						index = index,
						callbackOnOpenGameDetails = dismissContextualMenu,
						callbackOnJoinGame = dismissContextualMenu,
						featureContext = featureContext,
					}),

					Padding = Roact.createElement("UIPadding", {
						PaddingTop = UDim.new(0, buttonTopPadding),
					}),
				}),
			}),
		}),

		Separator = Roact.createElement(Separator, {
			layoutOrder = 2,
		}),
	})
end

function UserActiveGame:render()
	local formFactor = self.props.formFactor

	if formFactor == FormFactor.PHONE then
		return self:renderPhone()
	else
		return self:renderTablet()
	end
end

UserActiveGame = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local universeId = tostring(props.universeId)

		return {
			formFactor = state.FormFactor,
			gameThumbnail = state.GameThumbnails[universeId],
			universePlaceInfo = state.UniversePlaceInfos[universeId],
		}
	end
)(UserActiveGame)

UserActiveGame = RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
	guiService = AppGuiService,
})(UserActiveGame)

return UserActiveGame