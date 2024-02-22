local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local memoize = require(Modules.Common.memoize)
local sortFriendsByPresenceAndRecency = require(Modules.LuaApp.sortFriendsByPresenceAndRecency)
local Constants = require(Modules.LuaApp.Constants)
local JoinableFriendEntry = require(Modules.LuaApp.Components.Home.JoinableFriendEntry)

local ENTRY_HEIGHT = 67
local DIVIDER_HEIGHT = 1

local DIVIDER_POSITION_OFFSET_X = Constants.PlacesList.ContextualMenu.HorizontalOuterPadding
								+ Constants.PlacesList.ContextualMenu.AvatarSize
								+ Constants.PlacesList.ContextualMenu.HorizontalInnerPadding

local JoinableFriendsList = Roact.PureComponent:extend("JoinableFriendsList")

local function CreateDivider(props)
	local layoutOrder = props.layoutOrder

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		BottomDivider = Roact.createElement("Frame", {
			Size = UDim2.new(1, -DIVIDER_POSITION_OFFSET_X, 1, 0),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Constants.Color.GRAY4,
			BorderSizePixel = 0,
		}),
	})
end

JoinableFriendsList.defaultProps = {
	layoutOrder = 0,
}

function JoinableFriendsList:init()
	-- List of friends are stored into the components state when it is created.
	-- This is to 'freeze' the list of users to show once the contextual menu is up.
	-- The list should not change when an in-game user leaves the game, or when a
	-- new friend starts playing the game.
	self.state = {
		friends = self.props.friends,
	}
end

function JoinableFriendsList:render()
	local layoutOrder = self.props.LayoutOrder
	local maxHeight = self.props.maxHeight
	local width = self.props.width
	local universeId = self.props.universeId
	local friends = self.state.friends or {}

	local joinableFriendEntries = {}
	joinableFriendEntries.ListLayout = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	for index, friend in ipairs(friends) do
		local entryLayoutOrder = index * 2
		local hasBottomDivider = index < #friends

		joinableFriendEntries["Entry_" .. friend.name] = Roact.createElement(JoinableFriendEntry, {
			user = friend,
			layoutOrder = entryLayoutOrder,
			entryHeight = ENTRY_HEIGHT,
			entryWidth = width,
			universeId = universeId,
		})

		joinableFriendEntries["Divider_" .. friend.name] = hasBottomDivider and Roact.createElement(CreateDivider, {
			layoutOrder = entryLayoutOrder + 1
		})
	end

	local canvasHeight = ENTRY_HEIGHT * #friends + DIVIDER_HEIGHT * (#friends - 1)
	local scrollingFrameHeight = math.min(maxHeight, canvasHeight)

	return Roact.createElement("ScrollingFrame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, scrollingFrameHeight),
		CanvasSize = UDim2.new(1, 0, 0, canvasHeight),
		BackgroundColor3 = Constants.Color.WHITE,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
	}, joinableFriendEntries)
end

local getSortedFriends = memoize(function(users, mapOfUserIds)
	if not users or not mapOfUserIds then
		return {}
	end

	local allFriends = {}
	for _, userId in pairs(mapOfUserIds) do
		local user = users[userId]
		if user and user.isFriend then
			table.insert(allFriends, user)
		end
	end

	table.sort(allFriends, sortFriendsByPresenceAndRecency)
	return allFriends
end)

JoinableFriendsList = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			friends = getSortedFriends(
				state.Users,
				state.InGameUsersByGame[props.universeId]
			),
		}
	end
)(JoinableFriendsList)

return JoinableFriendsList