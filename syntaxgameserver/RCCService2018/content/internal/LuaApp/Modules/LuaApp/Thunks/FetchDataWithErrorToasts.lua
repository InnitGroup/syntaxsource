local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local SetNetworkingErrorToast = require(script.parent.SetNetworkingErrorToast)

return function(fetchDataThunk)
	return function(store)
		return store:dispatch(fetchDataThunk):andThen(
			function(results)
				return Promise.resolve(results)
			end,
			function(err)
				store:dispatch(SetNetworkingErrorToast(err))
				return Promise.reject(err)
			end
		)
	end
end