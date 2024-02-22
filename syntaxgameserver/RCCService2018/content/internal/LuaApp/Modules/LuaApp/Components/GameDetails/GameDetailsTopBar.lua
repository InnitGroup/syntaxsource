local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local AppPage = require(Modules.LuaApp.AppPage)

local NavigateBack = require(Modules.LuaApp.Thunks.NavigateBack)

local NAVIGATION_BUTTON_LEFT_PADDING = 15
local NAVIGATION_BUTTON_SIZE = 36

-- TODO: Needs more accurate size, color and correct assets
local NAVIGATION_ICON_SIZE = 24
-- local CLOSE_BUTTON_IMAGE = ""
local BACK_BUTTON_IMAGE = "rbxasset://textures/ui/LuaApp/icons/ic-back.png"

local GameDetailsTopBar = Roact.PureComponent:extend("GameDetailsTopBar")

function GameDetailsTopBar:render()
	local theme = self._context.AppTheme
	local statusBarHeight = self.props.statusBarHeight
	local topBarHeight = self.props.topBarHeight
	local isRootGameDetails = self.props.isRootGameDetails
	local navigateBack = self.props.navigateBack

	return Roact.createElement("Frame", {
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, topBarHeight),
		BackgroundTransparency = 1,
	}, {
		TouchFriendlyNavigationButton = Roact.createElement("TextButton", {
			Position = UDim2.new(0, NAVIGATION_BUTTON_LEFT_PADDING, 0, statusBarHeight),
			Size = UDim2.new(0, NAVIGATION_BUTTON_SIZE, 0, NAVIGATION_BUTTON_SIZE),
			BackgroundTransparency = 1,
			Text = "",
			[Roact.Event.Activated] = navigateBack,
		}, {
			NavigationButton = isRootGameDetails and Roact.createElement("TextLabel", {
				Size = UDim2.new(0, NAVIGATION_ICON_SIZE, 0, NAVIGATION_ICON_SIZE),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = "X",
				TextSize = NAVIGATION_ICON_SIZE,
				TextColor3 = theme.GameDetails.TopBar.Icon.Color,
				BackgroundTransparency = 1,
			}) or Roact.createElement("ImageLabel", {
				Size = UDim2.new(0, NAVIGATION_ICON_SIZE, 0, NAVIGATION_ICON_SIZE),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Image = BACK_BUTTON_IMAGE,
				ImageColor3 = theme.GameDetails.TopBar.Icon.Color,
				BackgroundTransparency = 1,
			}),
		}),
	})
end

local function isRootGameDetails(history)
	local currentRoute = history[#history]
	local currentPage = currentRoute[#currentRoute]

	if currentPage.name ~= AppPage.GameDetail then
		error("GameDetailsTopBar is rendered on a non-GameDetails page")
	end

	for index = #currentRoute - 1, 1, -1 do
		if currentRoute[index].name == AppPage.GameDetail then
			return false
		end
	end

	return true
end

GameDetailsTopBar = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			topBarHeight = state.TopBar.topBarHeight,
			statusBarHeight = state.TopBar.statusBarHeight,
			isRootGameDetails = isRootGameDetails(state.Navigation.history),
		}
	end,
	function(dispatch)
		return {
			navigateBack = function()
				return dispatch(NavigateBack())
			end
		}
	end
)(GameDetailsTopBar)

return GameDetailsTopBar