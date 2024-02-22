local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local AlertsGetAlertInfo = require(Modules.LuaApp.Http.Requests.AlertsGetAlertInfo)
local ProcessSiteAlertInfoPayload = require(Modules.LuaApp.Actions.ProcessSiteAlertInfoPayload)

return function(networkImpl)
	return function(store)
		return AlertsGetAlertInfo(networkImpl):andThen(function(result)
			return store:dispatch(ProcessSiteAlertInfoPayload(result.responseBody or {}))
		end,
		function(error)
			-- If we cannot retrieve site alert info, clear the alert.
			store:dispatch(ProcessSiteAlertInfoPayload({}))
			return Promise.reject(error)
		end)
	end
end

