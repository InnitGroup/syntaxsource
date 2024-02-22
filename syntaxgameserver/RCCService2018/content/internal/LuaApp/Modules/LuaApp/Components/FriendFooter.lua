local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local memoize = require(Modules.Common.memoize)
local Constants = require(Modules.LuaApp.Constants)
local sortFriendsByPresenceAndRecency = require(Modules.LuaApp.sortFriendsByPresenceAndRecency)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local FriendIcon = require(Modules.LuaApp.Components.FriendIcon)

local ICON_PADDING = 3

local ICON_SIZE_LARGE = 32
local ICON_SIZE_SMALL = 24
local PREFERRED_NUMBER_OF_CIRCLES_MIN = 3

local NUMBERED_CIRCLE = "LuaApp/graphic/gr-counter-slot-32x32"
local NUMBERED_ICON_FONT = Enum.Font.SourceSans
local NUMBERED_ICON_FONT_COLOR = Constants.Color.GRAY2
local NUMBERED_ICON_FONT_SIZE = 15

local function NumberedIcon(props)
	local width = props.size
	local height = props.size
	local layoutOrder = props.layoutOrder
	local count = props.count

	return Roact.createElement(ImageSetLabel, {
		Size = UDim2.new(0, width, 0, height),
		LayoutOrder = layoutOrder,
		Image = NUMBERED_CIRCLE,
		BackgroundTransparency = 1,
	}, {
		Count = Roact.createElement("TextLabel", {
			Size = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Font = NUMBERED_ICON_FONT,
			TextSize = NUMBERED_ICON_FONT_SIZE,
			Text = "+" .. count,
			TextColor3 = NUMBERED_ICON_FONT_COLOR,
			BackgroundTransparency = 1,
		}),
	})
end

local FriendFooter = Roact.PureComponent:extend("FriendFooter")

function FriendFooter:render()
	local width = self.props.width
	local height = self.props.height
	local layoutOrder = self.props.layoutOrder
	local friends = self.props.friends
	local topPadding = self.props.topPadding

	local numberedIconValue = 0

	if #friends <= 0 then
		return nil
	end

	local function GetMaxNumberOfIconsInWidth(iconSize, availableWidth)
		return math.floor((availableWidth + ICON_PADDING) / (iconSize + ICON_PADDING))
	end

	local availableHeight = height - topPadding
	local friendIconSize

	if availableHeight >= ICON_SIZE_LARGE
		and GetMaxNumberOfIconsInWidth(ICON_SIZE_LARGE, width) >= PREFERRED_NUMBER_OF_CIRCLES_MIN then
		friendIconSize = ICON_SIZE_LARGE
	elseif availableHeight >= ICON_SIZE_SMALL then
		friendIconSize = ICON_SIZE_SMALL
	else
		friendIconSize = availableHeight
	end

	local maxNumberOfIcons = GetMaxNumberOfIconsInWidth(friendIconSize, width)

	if #friends > maxNumberOfIcons then
		numberedIconValue = #friends - (maxNumberOfIcons - 1)
	end

	local listOfIcons = {}
	listOfIcons.ListLayout = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ICON_PADDING),
	})

	listOfIcons.Padding = Roact.createElement("UIPadding", {
		PaddingTop = UDim.new(0, topPadding),
	})

	local maxFriendIndex = numberedIconValue > 0 and maxNumberOfIcons - 1
							or math.min(maxNumberOfIcons, #friends)
	for index = 1, maxFriendIndex do
		local user = friends[index]
		listOfIcons["FriendIcon"..index] = Roact.createElement(FriendIcon, {
			user = user,
			itemSize = friendIconSize,
			layoutOrder = index,
		})
	end

	listOfIcons.NumberedIcon = numberedIconValue > 0 and Roact.createElement(NumberedIcon, {
		size = friendIconSize,
		layoutOrder = maxNumberOfIcons,
		count = numberedIconValue,
	})

	return Roact.createElement("Frame", {
		Size = UDim2.new(0, width, 0, height),
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
	}, listOfIcons)
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

FriendFooter = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			friends = getSortedFriends(
				state.Users,
				state.InGameUsersByGame[props.universeId]
			),
		}
	end
)(FriendFooter)

return FriendFooter