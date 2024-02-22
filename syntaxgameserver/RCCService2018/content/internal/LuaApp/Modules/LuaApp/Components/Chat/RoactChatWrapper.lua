local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactAnalyticsAppStageLoaded = require(Modules.LuaApp.Services.RoactAnalyticsAppStageLoaded)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local RoactServices = require(Modules.LuaApp.RoactServices)

local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

local ChatMaster = require(Modules.ChatMaster)
local AppPage = require(Modules.LuaApp.AppPage)

local RoactChatWrapper = Roact.PureComponent:extend("RoactChatWrapper")

local PageTypeToChatType = {
	[AppPage.Chat] = ChatMaster.Type.Default,
	[AppPage.ShareGameToChat] = ChatMaster.Type.GameShare,
}

function RoactChatWrapper:init()
	self.isPageOpen = false
	self.currentChatType = nil
end

function RoactChatWrapper:didMount()
	self:updateChat()
end

function RoactChatWrapper:render()
	return nil
end

function RoactChatWrapper:didUpdate()
	self:updateChat()
end

function RoactChatWrapper:willUnmount()
	self.props.chatMaster:Stop(self.currentChatType)
end

function RoactChatWrapper:updateChat()
	local chatMaster = self.props.chatMaster
	local isVisible = self.props.isVisible
	local pageType = self.props.pageType
	local parameters = self.props.parameters
	local analytics = self.props.analytics
	local guiService = self.props.guiService
	local appRoutes = self.props.appRoutes

	if not self.isPageOpen and isVisible then
		local chatType = PageTypeToChatType[pageType]
		chatMaster:Start(chatType, parameters)
		self.isPageOpen = true
		self.currentChatType = chatType

		-- Staging broadcasting of APP_READY to accomodate for unpredictable
		-- delay on the native side.
		-- Once Lua tab bar is integrated, there will be no use for this
		guiService:BroadcastNotification(pageType, NotificationType.APP_READY)
		local currentRoute = appRoutes[#appRoutes]
		local currentSection = currentRoute[1]
		analytics.reportAppReady(currentSection.name)
	elseif self.isPageOpen and not isVisible then
		chatMaster:Stop(self.currentChatType)
		self.isPageOpen = false
		self.currentChatType = nil
	end
end

RoactChatWrapper = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			appRoutes = state.Navigation.history,
		}
	end
)(RoactChatWrapper)

return RoactServices.connect({
	analytics = RoactAnalyticsAppStageLoaded,
	guiService = AppGuiService,
})(RoactChatWrapper)