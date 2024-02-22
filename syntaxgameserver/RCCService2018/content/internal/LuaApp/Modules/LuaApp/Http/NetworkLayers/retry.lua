--[[
	Implements exponential backoff HTTP request retry.
]]
local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local HttpError = require(Modules.LuaApp.Http.HttpError)


-- seconds : (number) the number of seconds to wait before resuming
local function defer(seconds)
	return Promise.new(function(resolve)
		delay(seconds, function()
			resolve()
		end)
	end)
end

-- httpFunc : (function<promise<HttpResponse>>()) a function that fires a network request until it succeeds
-- retryOptions : (table) retry configuration parameters
--	retryOptions.remainingAttempts : (number) a counter for determining when we've failed
--	retryOptions.maxAttempts : (number) a value to let us know how many attempts we started with
--	retryOptions.backoffRate : (number)
--	retryOptions.shouldRetryFunc : (function<bool>(HttpError)) custom logic
--	retryOptions.shouldImmediateRetry : (bool, TESTING ONLY) when true, disregards backoff rate
local function retryRequest(httpFunc, retryOptions)
	return httpFunc():catch(function(httpError)
		retryOptions.remainingAttempts = retryOptions.remainingAttempts - 1

		-- decide whether to retry
		local shouldRetry = retryOptions.remainingAttempts > 0 and
			(httpError.kind == HttpError.Kind.RequireExternalRetry or
			httpError.kind == HttpError.Kind.LuaTimeout)

		if not shouldRetry then
			return Promise.reject(httpError)
		end

		if retryOptions.shouldImmediateRetry then
			-- In tests, resolve the retry logic immediately.
			-- This functionality should one day be replaced with a service that mocks the passage of time,
			--  that way, tests will be able to resolve synchronously.
			return retryRequest(httpFunc, retryOptions)
		else
			-- wait for an increasing amount of time before retrying
			local nextDelay = retryOptions.backoffRate ^ (retryOptions.maxAttempts - retryOptions.remainingAttempts)
			return defer(nextDelay):andThen(function()
				return retryRequest(httpFunc, retryOptions)
			end)
		end
	end)
end

-- requestFunc : (function<promise<HttpResponse>>(url, requestMethod, options))
-- retryOptions : (table, optional)
--	shouldImmediateRetry : (bool) when true, disregards backoff rate
return function(requestFunc, retryOptions)

	return function(url, requestMethod, options)
		-- default retry delays are 2, 4, 8 seconds
		local retryConfigParams = {
			maxAttempts = 3,
			backoffRate = 2,
			shouldImmediateRetry = false
		}

		if retryOptions and retryOptions.shouldImmediateRetry then
			assert(type(retryOptions.shouldImmediateRetry) == "boolean", "shouldImmediateRetry must be a bool")
			retryConfigParams.shouldImmediateRetry = retryOptions.shouldImmediateRetry
		end

		retryConfigParams.remainingAttempts = retryConfigParams.maxAttempts

		-- wrap the request into a function that can be called multiple times until we succeed
		local function makeRequest()
			return requestFunc(url, requestMethod, options)
		end

		local httpPromise = retryRequest(makeRequest, retryConfigParams)
		return httpPromise
	end
end