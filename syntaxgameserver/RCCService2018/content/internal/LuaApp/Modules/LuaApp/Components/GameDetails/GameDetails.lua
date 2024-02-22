local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)

local Colors = require(Modules.LuaApp.Themes.Colors)
local FitChildren = require(Modules.LuaApp.FitChildren)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

local LoadingStateWrapper = require(Modules.LuaApp.Components.LoadingStateWrapper)

local FetchGameDetailsPageData = require(Modules.LuaApp.Thunks.FetchGameDetailsPageData)
local NavigateUp = require(Modules.LuaApp.Thunks.NavigateUp)

-- TODO: replace with actual specs..
local TITLE_FONT_SIZE = 30
local BACK_BUTTON_SIZE = 50
local BACK_BUTTON_IMAGE_SIZE = 24
local BACK_BUTTON_IMAGE = "rbxasset://textures/ui/LuaApp/icons/ic-back.png"
local BACKGROUND_IMAGE = "http://www.roblox.com/asset/?id=1052283313"

local GameDetails = Roact.PureComponent:extend("GameDetails")

function GameDetails:init()
	local universeId = self.props.universeId

	if not universeId or type(universeId) ~= "string" then
		error("Must have a valid universeId to open a game details page!")
	end

	self.backgroundImageRef = Roact.createRef()

	self.onCanvasPositionChanged = function(rbx)
		-- parallax background image with canvas movement
		if self.backgroundImageRef.current ~= nil then
			self.backgroundImageRef.current.Position = UDim2.new(0.5, 0, 0.5, - rbx.CanvasPosition.Y / 50)
		end
	end

	self.fetchGameDetailsPageData = function()
		local networking = self.props.networking
		local universeId = self.props.universeId
		local fetchGameDetailsPageData = self.props.fetchGameDetailsPageData

		return fetchGameDetailsPageData(networking, universeId)
	end
end

function GameDetails:renderOnLoaded()
	local gameDetail = self.props.gameDetail

	return Roact.createElement(FitChildren.FitScrollingFrame, {
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		ScrollBarThickness = 0,
		ClipsDescendants = true,
		fitFields = {
			CanvasSize = FitChildren.FitAxis.Height,
		},
		[Roact.Change.CanvasPosition] = self.onCanvasPositionChanged,
	}, {
		ListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 20),
		}),
		PagePadding = Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		}),
		Header = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, TITLE_FONT_SIZE),
			Font = Enum.Font.SourceSans,
			TextSize = TITLE_FONT_SIZE,
			Text = gameDetail.name,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}),
		ThumbnailAccordion = Roact.createElement("ImageLabel", {
			Size = UDim2.new(0, 300, 0, 200),
			Image = "http://www.roblox.com/asset/?id=1574920860",
			LayoutOrder = 2,
		}),
		Description = Roact.createElement("ImageLabel", {
			Size = UDim2.new(0, 300, 0, 300),
			Image = "http://www.roblox.com/asset/?id=2435253812",
			LayoutOrder = 3,
		}),
		Ratings = Roact.createElement("ImageLabel", {
			Size = UDim2.new(0, 150, 0, 150),
			Image = "http://www.roblox.com/asset/?id=138381488",
			LayoutOrder = 4,
		}),
		Players = nil,
		StatsAndInfo = nil,
		Social = nil,
		More = nil,
		RecommendedGames = nil,
	})
end

function GameDetails:render()
	local statusBarHeight = self.props.statusBarHeight
	local gameDetailsPageDataStatus = self.props.gameDetailsPageDataStatus
	local navigateUp = self.props.navigateUp

	local topBarHeight = statusBarHeight + BACK_BUTTON_SIZE

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Colors.Slate,
		-- Absorb input
		Active = true,
		BorderSizePixel = 0,
	}, {
		TopBar = Roact.createElement("Frame", {
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, topBarHeight),
			BackgroundTransparency = 1,
		}, {
			TouchFriendlyBackButton = Roact.createElement("TextButton", {
				Position = UDim2.new(0, 0, 0, statusBarHeight),
				Size = UDim2.new(0, BACK_BUTTON_SIZE, 0, BACK_BUTTON_SIZE),
				BackgroundTransparency = 1,
				Text = "",
				[Roact.Event.Activated] = navigateUp,
			}, {
				ButtonImage = Roact.createElement("ImageLabel", {
					Size = UDim2.new(0, BACK_BUTTON_IMAGE_SIZE, 0, BACK_BUTTON_IMAGE_SIZE),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Image = BACK_BUTTON_IMAGE,
					BackgroundTransparency = 1,
				})
			}),
		}),
		Contents = Roact.createElement("Frame", {
			Position = UDim2.new(0, 0, 0, topBarHeight),
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
		}, {
			BackgroundImage = Roact.createElement("ImageLabel", {
				Size = UDim2.new(3, 0, 1.2, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Image = BACKGROUND_IMAGE,
				ImageTransparency = 0.8,
				ZIndex = 1,
				[Roact.Ref] = self.backgroundImageRef,
			}),
			GameDetails = Roact.createElement("Frame", {
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 2,
				BackgroundTransparency = 1,
			}, {
				LoadingState = Roact.createElement(LoadingStateWrapper, {
					dataStatus = gameDetailsPageDataStatus,
					isPage = true,
					onRetry = self.fetchGameDetailsPageData,
					renderOnLoaded = function()
						return self:renderOnLoaded()
					end,
				}),
			}),
			ActionBar = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.new(0, 0, 1, -50),
				BackgroundColor3 = Colors.Slate,
				BackgroundTransparency = 0.8,
				ZIndex = 3,
			}),
		}),
	})
end

function GameDetails:didMount()
	local gameDetailsPageDataStatus = self.props.gameDetailsPageDataStatus

	if gameDetailsPageDataStatus == RetrievalStatus.NotStarted then
		self.fetchGameDetailsPageData()
	end
end

GameDetails = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			statusBarHeight = state.TopBar.statusBarHeight,
			gameDetailsPageDataStatus = state.GameDetailsPageDataStatus[props.universeId],
			gameDetail = state.GameDetails[props.universeId],
		}
	end,
	function(dispatch)
		return {
			fetchGameDetailsPageData = function(networking, universeId)
				return dispatch(FetchGameDetailsPageData(networking, universeId))
			end,
			navigateUp = function()
				return dispatch(NavigateUp())
			end,
		}
	end
)(GameDetails)

return RoactServices.connect({
	networking = RoactNetworking,
})(GameDetails)
