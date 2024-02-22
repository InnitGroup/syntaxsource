--[[
Events page
_____________________
|                   |
|       TopBar      |
|___________________|
|                   |
|     EventList     |
|  _______________  |
| |               | |
| | EventButton 1 | |
| | EventButton 2 | |
| | EventButton 3 | |
| |_______________| |
|___________________|
]]

local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)

local Constants = require(Modules.LuaApp.Constants)
local FitChildren = require(Modules.LuaApp.FitChildren)
local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local Url = require(Modules.LuaApp.Http.Url)

local ApiFetchSponsoredEvents = require(Modules.LuaApp.Thunks.ApiFetchSponsoredEvents)

local TopBar = require(Modules.LuaApp.Components.TopBar)
local EventButton = require(Modules.LuaApp.Components.More.EventButton)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local LoadingStateWrapper = require(Modules.LuaApp.Components.LoadingStateWrapper)

local EVENTS_PAGE_BG_COLOR = Constants.Color.GRAY6
local EVENTS_PADDING = 10
local NO_EVENT_FONT = Enum.Font.SourceSans
local NO_EVENT_TEXT_SIZE = 23
local NO_EVENT_TEXT_COLOR = Constants.Color.GRAY3

local EventsPage = Roact.PureComponent:extend("EventsPage")

function EventsPage:init()
	self.dispatchFetchSponsoredEvents = function()
		return self.props.dispatchFetchSponsoredEvents(self.props.networking)
	end
end

function EventsPage:renderOnLoaded()
	local isTablet = self.props.formFactor == FormFactor.TABLET
	local topBarHeight = self.props.topBarHeight
	local sponsoredEvents = self.props.sponsoredEvents

	if sponsoredEvents and #sponsoredEvents > 0 then
		local paddingHorizontal = isTablet and Constants.MORE_PAGE_TABLET_PADDING_HORINZONTAL or
			Constants.MORE_PAGE_SECTION_PADDING
		local paddingVertical = isTablet and Constants.MORE_PAGE_TABLET_PADDING_VERTICAL or
			Constants.MORE_PAGE_SECTION_PADDING
		local eventList = {
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, EVENTS_PADDING),
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, paddingVertical),
				PaddingBottom = UDim.new(0, paddingVertical),
				PaddingLeft = UDim.new(0, paddingHorizontal),
				PaddingRight = UDim.new(0, paddingHorizontal),
			}),
		}

		for index, event in ipairs(sponsoredEvents) do
			eventList["Event"..tostring(index)..event.name] =  Roact.createElement(EventButton, {
				LayoutOrder = index,
				Image = event.imageUrl,
				title = event.title,
				url = Url.BASE_URL..event.pageUrl
			})
		end

		return Roact.createElement(FitChildren.FitScrollingFrame, {
			Position = UDim2.new(0, 0, 0, topBarHeight),
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			CanvasSize = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			ClipsDescendants = false,

			fitFields = {
				CanvasSize = FitChildren.FitAxis.Height,
			},
		}, eventList)
	else
		-- No event is going on, display no event text
		return Roact.createElement(LocalizedTextLabel, {
			Position = UDim2.new(0, 0, 0, topBarHeight),
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "CommonUI.Features.Label.MoreEvents",
			Font = NO_EVENT_FONT,
			TextSize = NO_EVENT_TEXT_SIZE,
			TextColor3 = NO_EVENT_TEXT_COLOR,
			TextWrapped = true,
		})
	end
end

function EventsPage:render()
	local sponsoredEventsFetchingStatus = self.props.sponsoredEventsFetchingStatus

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = EVENTS_PAGE_BG_COLOR,
	}, {
		TopBar = Roact.createElement(TopBar, {
			showBuyRobux = true,
			showNotifications = true,
		}),
		EventsContent = Roact.createElement(LoadingStateWrapper, {
			dataStatus = sponsoredEventsFetchingStatus,
			onRetry = self.dispatchFetchSponsoredEvents,
			isPage = true,
			renderOnLoaded = function()
				return self:renderOnLoaded()
			end,
		}),
	})
end

function EventsPage:didMount()
	if self.props.sponsoredEventsFetchingStatus == RetrievalStatus.NotStarted then
		self.dispatchFetchSponsoredEvents()
	end
end

EventsPage = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			formFactor = state.FormFactor,
			topBarHeight = state.TopBar.topBarHeight,
			sponsoredEvents = state.SponsoredEvents,
			sponsoredEventsFetchingStatus = state.RequestsStatus.SponsoredEventsFetchingStatus,
		}
	end,
	function(dispatch)
		return {
			dispatchFetchSponsoredEvents = function(networking)
				return dispatch(ApiFetchSponsoredEvents(networking))
			end,
		}
	end
)(EventsPage)

return RoactServices.connect({
	networking = RoactNetworking,
})(EventsPage)