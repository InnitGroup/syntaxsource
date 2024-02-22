local Modules = game:GetService("CoreGui").RobloxGui.Modules

local HttpError = require(Modules.LuaApp.Http.HttpError)
local StatusCodes = require(Modules.LuaApp.Http.StatusCodes)

local UNKNOWN_ERROR_STRING = "Feature.Toast.NetworkingError.UnableToConnect"
local LUA_TIME_OUT_STRING = "Feature.Toast.NetworkingError.TimeOut"
local DEFAULT_STRING = "Feature.Toast.NetworkingError.SomethingIsWrong"

local STATUS_CODE_TO_STRING = {
	[StatusCodes.BAD_REQUEST] = "Feature.Toast.NetworkingError.SomethingIsWrong",
	[StatusCodes.UNAUTHORIZED] = "Feature.Toast.NetworkingError.Unauthorized",
	[StatusCodes.FORBIDDEN] = "Feature.Toast.NetworkingError.Forbidden",
	[StatusCodes.NOT_FOUND] = "Feature.Toast.NetworkingError.NotFound",
	[StatusCodes.REQUEST_TIMEOUT] = "Feature.Toast.NetworkingError.TimeOut",
	[StatusCodes.TOO_MANY_REQUESTS] = "Feature.Toast.NetworkingError.TooManyRequests",
	[StatusCodes.INTERNAL_SERVER_ERROR] = "Feature.Toast.NetworkingError.SomethingIsWrong",
	[StatusCodes.NOT_IMPLEMENTED] = "Feature.Toast.NetworkingError.SomethingIsWrong",
	[StatusCodes.BAD_GATEWAY] = "Feature.Toast.NetworkingError.SomethingIsWrong",
	[StatusCodes.SERVICE_UNAVAILABLE] = "Feature.Toast.NetworkingError.ServiceUnavailable",
	[StatusCodes.GATEWAY_TIMEOUT] = "Feature.Toast.NetworkingError.TimeOut",
}

--[[
	returns a localization key that gets displayed to the user when a network
	request has failed.
	Inputs:
		errorKind -- A string. Supported values can be found in HttpError.lua
		errorCode -- number. This is the Http status code returned from web.
]]
local function getLocalizedToastStringFromHttpError(errorKind, errorCode)
	if errorKind == HttpError.Kind.Unknown then
		return UNKNOWN_ERROR_STRING
	end

	if errorKind == HttpError.Kind.LuaTimeout then
		return LUA_TIME_OUT_STRING
	end

	if (errorKind == HttpError.Kind.RequestFailure or errorKind == HttpError.Kind.RequireExternalRetry) and
		errorCode ~= nil and STATUS_CODE_TO_STRING[errorCode] ~= nil then
		return STATUS_CODE_TO_STRING[errorCode]
	end

	return DEFAULT_STRING
end

return getLocalizedToastStringFromHttpError