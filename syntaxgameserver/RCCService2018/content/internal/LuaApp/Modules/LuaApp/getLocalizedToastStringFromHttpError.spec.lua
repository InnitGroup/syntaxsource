return function()
	local CoreGui = game:GetService("CoreGui")
	local Modules = CoreGui.RobloxGui.Modules
	local HttpError = require(Modules.LuaApp.Http.HttpError)

	local getLocalizedToastStringFromHttpError = require(script.Parent.getLocalizedToastStringFromHttpError)

	local errorsToStrings = {
		{ HttpError.Kind.Unknown, nil, "Feature.Toast.NetworkingError.UnableToConnect" },
		{ HttpError.Kind.LuaTimeout, nil, "Feature.Toast.NetworkingError.TimeOut" },
		{ HttpError.Kind.InvalidJson, nil, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{ HttpError.Kind.RequestFailure, 400, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{ HttpError.Kind.RequestFailure, 401, "Feature.Toast.NetworkingError.Unauthorized" },
		{ HttpError.Kind.RequestFailure, 403, "Feature.Toast.NetworkingError.Forbidden" },
		{ HttpError.Kind.RequestFailure, 404, "Feature.Toast.NetworkingError.NotFound" },
		{ HttpError.Kind.RequestFailure, 408, "Feature.Toast.NetworkingError.TimeOut" },
		{ HttpError.Kind.RequestFailure, 429, "Feature.Toast.NetworkingError.TooManyRequests" },
		{ HttpError.Kind.RequestFailure, 418, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{ HttpError.Kind.RequireExternalRetry, 500, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{ HttpError.Kind.RequireExternalRetry, 501, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{ HttpError.Kind.RequireExternalRetry, 502, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{ HttpError.Kind.RequireExternalRetry, 503, "Feature.Toast.NetworkingError.ServiceUnavailable" },
		{ HttpError.Kind.RequireExternalRetry, 504, "Feature.Toast.NetworkingError.TimeOut" },
		{ HttpError.Kind.RequireExternalRetry, 505, "Feature.Toast.NetworkingError.SomethingIsWrong" },
		{"WeirdError", nil, "Feature.Toast.NetworkingError.SomethingIsWrong"}
	}

	describe("getLocalizedToastStringFromHttpError", function()
		it("should return the correct error strings", function()
			for _, errorToString in ipairs(errorsToStrings) do
				expect(getLocalizedToastStringFromHttpError(errorToString[1],
					errorToString[2])).to.equal(errorToString[3])
			end
		end)
	end)
end