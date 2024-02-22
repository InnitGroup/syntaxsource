local Modules = game:GetService("CoreGui").RobloxGui.Modules
local ToastType = require(Modules.LuaApp.Enum.ToastType)
local getLocalizedToastStringFromHttpError = require(Modules.LuaApp.getLocalizedToastStringFromHttpError)
local SetCurrentToastMessage = require(Modules.LuaApp.Actions.SetCurrentToastMessage)

return function(err)
	if err.kind == nil or type(err.kind) ~= "string" or err.message == nil then
		error("Insufficient arguments for SetNetworkingErrorToast!")
	end

	return function(store)
		store:dispatch(SetCurrentToastMessage({
			toastType = ToastType.NetworkingError,
			toastMessage = getLocalizedToastStringFromHttpError(err.kind, tonumber(err.message)),
		}))
	end
end