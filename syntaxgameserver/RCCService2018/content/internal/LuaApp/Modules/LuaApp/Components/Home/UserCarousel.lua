local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Common = Modules.Common
local LuaApp = Modules.LuaApp

local Roact = require(Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local Constants = require(LuaApp.Constants)
local FitChildren = require(LuaApp.FitChildren)

local LocalizedSectionHeaderWithSeeAll = require(LuaApp.Components.LocalizedSectionHeaderWithSeeAll)
local AddFriendsButton = require(LuaApp.Components.Home.AddFriendsButton)

local NotificationType = require(LuaApp.Enum.NotificationType)
local Url = require(LuaApp.Http.Url)

local UserCarouselEntry = require(LuaApp.Components.Home.UserCarouselEntry)

local CAROUSEL_PADDING_DIM = UDim.new(0, Constants.USER_CAROUSEL_PADDING)

local FRIEND_SECTION_MARGIN = 15 - UserCarouselEntry.horizontalPadding()
local ADD_FRIENDS_BUTTON_WIDTH = Constants.PeopleList.ADD_FRIENDS_FRAME_WIDTH

local LuaHomePageShowFriendAvatarFace = settings():GetFFlag("LuaHomePageShowFriendAvatarFace150By150")

local UserCarousel = Roact.PureComponent:extend("UserCarousel")

UserCarousel.defaultProps = {
	friendCount = 0,
}

function UserCarousel:init()
	local guiService = self.props.guiService

	self.state = {
		cardWindowStart = 1,
		cardsInWindow = 0,
		cardWidth = 0,
	}

	self.onSeeAllFriends = function()
		local url = string.format("%susers/friends", Url.BASE_URL)
		guiService:BroadcastNotification(url, NotificationType.VIEW_PROFILE)
	end

	self.scrollingFrameRefCallback = function(rbx)
		self.scrollingFrameRef = rbx
	end

	self.updateCardWindowBounds = function()
		if not self.scrollingFrameRef then
			return
		end

		local formFactor = self.props.formFactor
		local friends = self.state.friends
		local screenSize = self.props.screenSize

		local containerWidth = screenSize.X - FRIEND_SECTION_MARGIN
		local windowOffset = self.scrollingFrameRef.CanvasPosition.X

		local userCardSizeX = UserCarouselEntry.getCardWidth(formFactor)

		local cardWindowStart = math.max(1, math.floor((windowOffset - ADD_FRIENDS_BUTTON_WIDTH) / userCardSizeX) + 1)
		local cardsInWindow = math.ceil(containerWidth/userCardSizeX) + 1

		local maxOffset = userCardSizeX * #friends + ADD_FRIENDS_BUTTON_WIDTH - self.scrollingFrameRef.AbsoluteSize.X
		local inScrollingBounds = windowOffset >= 0 and windowOffset <= maxOffset

		local shouldUpdate = inScrollingBounds and (cardWindowStart ~= self.state.cardWindowStart
			or cardsInWindow ~= self.state.cardsInWindow
			or userCardSizeX ~= self.state.cardWidth)

		if shouldUpdate then
			self:setState({
				cardWindowStart = cardWindowStart,
				cardsInWindow = cardsInWindow,
				cardWidth = userCardSizeX
			})
		end
	end
end

function UserCarousel:render()
	local formFactor = self.props.formFactor
	local friendCount = self.props.friendCount
	local layoutOrder = self.props.LayoutOrder

	local friendSectionHeight = UserCarouselEntry.height(formFactor)
	local seeAllButtonVisible = friendCount > 0

	local content, headerText
	if friendCount == 0 then
		content = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, friendSectionHeight),
			BackgroundTransparency = 1,
		}, {
			layout = Roact.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			addFriendsButton = Roact.createElement(AddFriendsButton, {
				hasNoFriend = true,
			}),
		})

		headerText = "CommonUI.Features.Label.Friends"
	else
		local setPeopleListFrozen = self.props.setPeopleListFrozen

		local friends = self.state.friends
		local cardStart = self.state.cardWindowStart
		local numCards = self.state.cardsInWindow
		local cardWidth = self.state.cardWidth

		local canvasSizeX = #friends * cardWidth + FRIEND_SECTION_MARGIN + ADD_FRIENDS_BUTTON_WIDTH

		local function createUserEntry(user, count)
			local avatarThumbnailType

			if LuaHomePageShowFriendAvatarFace then
				avatarThumbnailType = Constants.AvatarThumbnailTypes.HeadShot
			else
				avatarThumbnailType = Constants.AvatarThumbnailTypes.AvatarThumbnail
			end

			return Roact.createElement(UserCarouselEntry, {
				user = user,
				formFactor = formFactor,
				count = count - 1,
				highlightColor = Constants.Color.WHITE,
				setPeopleListFrozen = setPeopleListFrozen,
				thumbnailType = avatarThumbnailType,
			})
		end

		local leftPadding = math.max(0, (cardStart - 1) * cardWidth) + FRIEND_SECTION_MARGIN
		if cardStart > 1 then
			leftPadding  = leftPadding + ADD_FRIENDS_BUTTON_WIDTH
		end

		local peopleListItems = {}

		-- First Element is the AddFriendsButton
		if cardStart == 1 then
			local addFriendsButton = Roact.createElement(AddFriendsButton, {
				hasNoFriend = false,
			})

			table.insert(peopleListItems, addFriendsButton)
		end

		for i = math.max(1, cardStart), math.min(#friends,cardStart + numCards) do
			table.insert(peopleListItems, createUserEntry(friends[i], #peopleListItems + 1))
		end

		peopleListItems.Layout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		peopleListItems.Padding = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Size = UDim2.new(0, leftPadding, 1, 0),
		})

		content = Roact.createElement("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, friendSectionHeight),
			ScrollBarThickness = 0,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(0, canvasSizeX, 1, 0),
			ScrollingDirection = Enum.ScrollingDirection.X,

			[Roact.Change.CanvasPosition] = self.updateCardWindowBounds,
			[Roact.Ref] = self.scrollingFrameRefCallback,
		}, peopleListItems)

		headerText = {
			"Feature.Home.HeadingFriends",
			friendCount = friendCount,
		}
	end

	return Roact.createElement(FitChildren.FitFrame, {
			Size = UDim2.new(1, 0, 0, 0),
			fitAxis = FitChildren.FitAxis.Height,
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,
		},
		{
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Container = Roact.createElement(FitChildren.FitFrame, {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				fitFields = {
					Size = FitChildren.FitAxis.Height,
				},
			},
			{
				SidePadding = Roact.createElement("UIPadding", {
					PaddingLeft = CAROUSEL_PADDING_DIM,
					PaddingRight = CAROUSEL_PADDING_DIM,
				}),
				Header = Roact.createElement(LocalizedSectionHeaderWithSeeAll, {
					text = headerText,
					LayoutOrder = 1,
					onSelected = self.onSeeAllFriends,
					seeAllButtonVisible = seeAllButtonVisible,
				}),
			}),
			CarouselFrame = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, friendSectionHeight),
				BackgroundColor3 = Constants.Color.WHITE,
				LayoutOrder = 2,
				BorderSizePixel = 0,
			},
			{
				Content = content,
			}),
		}
	)
end

function UserCarousel.getDerivedStateFromProps(props)
	if not props.peopleListFrozen then
		return {
			friends = props.friends,
		}
	end
end

function UserCarousel:didMount()
	self.updateCardWindowBounds()
end

function UserCarousel:didUpdate(prevProps)
	if self.props.screenSize ~= prevProps.screenSize or self.props.formFactor ~= prevProps.formFactor then
		self.updateCardWindowBounds()
	end
end

UserCarousel = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			screenSize = state.ScreenSize,
		}
	end
)(UserCarousel)

return UserCarousel