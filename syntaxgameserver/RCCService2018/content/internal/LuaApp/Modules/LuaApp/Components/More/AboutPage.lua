--[[
About page
_____________________
|                   |
|       TopBar      |
|___________________|
|   AboutPageList   |
|     _________     |
|     | Row 1 |     |
|     | Row 2 |     |
|     | Row 3 |     |
|     | Row 4 |     |
|     | Row 5 |     |
|     |_______|     |
|                   |
|   BuildVersion    |
|___________________|
]]

local RunService = game:GetService("RunService")
local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local AppPage = require(Modules.LuaApp.AppPage)
local Constants = require(Modules.LuaApp.Constants)
local FitChildren = require(Modules.LuaApp.FitChildren)
local MorePageSettings = require(Modules.LuaApp.MorePageSettings)

local FormFactor = require(Modules.LuaApp.Enum.FormFactor)

local TopBar = require(Modules.LuaApp.Components.TopBar)
local MoreList = require(Modules.LuaApp.Components.More.MoreList)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local TABLET_MENU_PADDING = Constants.MORE_PAGE_TABLET_PADDING_HORINZONTAL*2 +
	Constants.MORE_PAGE_EVENT_WIDTH +
	Constants.MORE_PAGE_MENU_EVENT_PADDING
local MORE_PAGE_BG_COLOR = Constants.Color.GRAY6

local VERSION_FONT = Enum.Font.SourceSans
local VERSION_TEXT_SIZE = 18

local robloxVersion = RunService:GetRobloxVersion()

local AboutPage = Roact.PureComponent:extend("AboutPage")

function AboutPage:init()
	self.aboutPageItemList = MorePageSettings.GetMorePageItems(AppPage.About)
end

function AboutPage:render()
	local formFactor = self.props.formFactor
	local topBarHeight = self.props.topBarHeight
	local isTablet = formFactor == FormFactor.TABLET

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = MORE_PAGE_BG_COLOR,
	}, {
		TopBar = Roact.createElement(TopBar, {
			showBuyRobux = true,
			showNotifications = true,
		}),
		Scroller = Roact.createElement(FitChildren.FitScrollingFrame, {
			Position = UDim2.new(0, isTablet and Constants.MORE_PAGE_TABLET_PADDING_HORINZONTAL or 0, 0, topBarHeight),
			Size = UDim2.new(1, isTablet and -TABLET_MENU_PADDING or 0, 1, -topBarHeight),
			CanvasSize = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			ClipsDescendants = false,
			fitFields = {
				CanvasSize = FitChildren.FitAxis.Height,
			},
		}, {
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Constants.MORE_PAGE_SECTION_PADDING),
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, isTablet and Constants.MORE_PAGE_TABLET_PADDING_VERTICAL or
					Constants.MORE_PAGE_SECTION_PADDING),
				PaddingBottom = UDim.new(0, isTablet and Constants.MORE_PAGE_TABLET_PADDING_VERTICAL or
					Constants.MORE_PAGE_SECTION_PADDING),
			}),
			AboutPageList = Roact.createElement(MoreList, {
				LayoutOrder = 1,
				itemList = self.aboutPageItemList,
				rowHeight = Constants.MORE_PAGE_ROW_HEIGHT,
			}),
			BuildVersionText = Roact.createElement(LocalizedTextLabel, {
				Size = UDim2.new(1, 0, 0, VERSION_TEXT_SIZE),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = { "CommonUI.Features.Label.VersionWithNumber", versionNumber = robloxVersion },
				Font = VERSION_FONT,
				TextSize = VERSION_TEXT_SIZE,
				LayoutOrder = 2,
			}),
		}),
		-- TODO: implement EventWidget (MOBLUAPP-663), just a placeholder for now
		Event = isTablet and Roact.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, Constants.MORE_PAGE_EVENT_WIDTH, 0, 120),
			Position = UDim2.new(1, -Constants.MORE_PAGE_TABLET_PADDING_HORINZONTAL,
				0, topBarHeight + Constants.MORE_PAGE_TABLET_PADDING_VERTICAL),
		}),
	})
end

AboutPage = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			formFactor = state.FormFactor,
			topBarHeight = state.TopBar.topBarHeight,
		}
	end
)(AboutPage)

return AboutPage