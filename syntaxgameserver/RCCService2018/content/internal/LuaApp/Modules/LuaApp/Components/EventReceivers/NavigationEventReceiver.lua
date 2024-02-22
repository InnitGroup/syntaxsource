local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local AppPage = require(Modules.LuaApp.AppPage)
local NavigateToRoute = require(Modules.LuaApp.Thunks.NavigateToRoute)
local NavigateDown = require(Modules.LuaApp.Thunks.NavigateDown)
local NavigateBack = require(Modules.LuaApp.Thunks.NavigateBack)
local NavigateBackFromWebview = require(Modules.LuaApp.Thunks.NavigateBackFromWebview)

local NavigationEventReceiver = Roact.Component:extend("NavigationEventReceiver")

function NavigationEventReceiver:handleBackButtonPressed()
	local currentPage = self.props.currentRoute[1].name

	-- Currently, AvatarEditor and LuaChat both have their own handlers for
	-- the BackButtonPressed event, and they both send BACK_BUTTON_NOT_CONSUMED.
	-- To avoid sending the notification multiple times, we need to check if
	-- we're on Avatar or Chat page.
	-- TODO: we should remove this code, along with Avatar and Chat's code for
	-- connecting with the back button signal, once they use our AppRouter.
	-- Related ticket: MOBLUAPP-631
	if settings():GetFFlag("AvatarEditorRoactRewrite") then
		if currentPage == AppPage.Chat then
			return
		end
	else
		if currentPage == AppPage.AvatarEditor or currentPage == AppPage.Chat then
			return
		end
	end

	if #self.props.currentRoute > 1 then
		self.props.navigateBack()
	else
		GuiService:BroadcastNotification("", NotificationType.BACK_BUTTON_NOT_CONSUMED)
	end
end

function NavigationEventReceiver:init()
	local robloxEventReceiver = self.props.RobloxEventReceiver

	self.tokens = {
		robloxEventReceiver:observeEvent("Navigations", function(detail, detailType)
			if detailType == "Destination" or detailType == "Reload" then
				if detail.appName == AppPage.ShareGameToChat then
					self.props.navigateDown({
						name = AppPage.ShareGameToChat,
						detail = detail.parameters.placeId,
					})
				elseif detail.appName == AppPage.Chat then
					self.props.setPage({
						name = AppPage.Chat,
						detail = detail.parameters and detail.parameters.conversationId,
					})
				else
					self.props.setPage({
						name = AppPage[detail.appName] or AppPage.None,
					})
				end
			end
		end),
		GuiService.ShowLeaveConfirmation:Connect(function()
			self:handleBackButtonPressed()
		end),
		robloxEventReceiver:observeEvent("AppInput", function(detail, detailType)
			if detailType == "Focused" then
				self.props.navigateBackFromWebview()
			end
		end),
	}
end

function NavigationEventReceiver:render()
end

function NavigationEventReceiver:willUnmount()
	for _, connection in pairs(self.tokens) do
		connection:Disconnect()
	end
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			currentRoute = state.Navigation.history[#state.Navigation.history]
		}
	end,
	function(dispatch)
		return {
			setPage = function(page)
				return dispatch(NavigateToRoute({ page }))
			end,
			navigateDown = function(page)
				return dispatch(NavigateDown(page))
			end,
			navigateBack = function()
				return dispatch(NavigateBack())
			end,
			navigateBackFromWebview = function()
				return dispatch(NavigateBackFromWebview())
			end,
		}
	end
)(NavigationEventReceiver)