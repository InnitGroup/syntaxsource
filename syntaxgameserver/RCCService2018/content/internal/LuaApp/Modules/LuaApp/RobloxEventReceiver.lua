local CoreGui = game:GetService("CoreGui")

local HttpService = game:GetService("HttpService")
local Modules = CoreGui.RobloxGui.Modules
local Signal = require(Modules.Common.Signal)

local RobloxEventReceiver = {}
RobloxEventReceiver.__index = RobloxEventReceiver

function RobloxEventReceiver:observeEvent(namespace, callback)
	assert(type(namespace) == "string", "Expected namespace to be a string")
	assert(type(callback) == "function", "Expected callback to be a function")

	local signal = self.namespaceTable[namespace]
	if signal == nil then
		signal = Signal.new()
		self.namespaceTable[namespace] = signal
	end
	-- return the signal's connection function
	return signal:connect(callback)
end

function RobloxEventReceiver.new(notificationService)
	local self = {
		namespaceTable = {},
	}
	setmetatable(self, RobloxEventReceiver)

	self.connection = notificationService.RobloxEventReceived:Connect(function(event)
		-- Check and make sure that someone is observing this namespace
		local signal = self.namespaceTable[event.namespace]
		if signal == nil then
			return
		end

		local detail = (event.detail == nil or event.detail == "") and {} or HttpService:JSONDecode(event.detail)

		-- Must pass in detailType as certain events don't have a type field in detail
		-- Don't rely on this behavior in the future
		signal:fire(detail, event.detailType)
		-- These namespaces currently rely on event.detailType, this list is surely not complete
		--		UpdateNotificationBadge
		--		Navigations
	end)
	return self
end


return RobloxEventReceiver