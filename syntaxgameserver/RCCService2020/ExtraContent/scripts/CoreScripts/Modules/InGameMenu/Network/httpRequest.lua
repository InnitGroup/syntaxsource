local HttpService = game:GetService("HttpService")

local Promise = require(script.Parent.Parent.Utility.Promise)

local DEFAULT_THROTTLING_PRIORITY = Enum.ThrottlingPriority.Extreme
local DEFAULT_POST_ASYNC_CONTENT_TYPE = Enum.HttpContentType.ApplicationJson

-- httpRequest : (table, optional) an object that implements the same http functions as the data model
return function(httpImpl)

	local function doHttpPost(url, options)
		assert(options.postBody, "Expected a postBody to be specified with this request")
		assert(type(options.postBody) == "string", "Expected postBody to be a string")

		if not options.contentType then
			options.contentType = DEFAULT_POST_ASYNC_CONTENT_TYPE
		end

		if not options.throttlingPriority then
			options.throttlingPriority = DEFAULT_THROTTLING_PRIORITY
		end

		return function()
			return httpImpl:PostAsyncFullUrl(
				url,
				options.postBody,
				options.throttlingPriority,
				options.contentType
			)
		end
	end

	local function doHttpGet(url)
		return function()
			return httpImpl:GetAsyncFullUrl(url, DEFAULT_THROTTLING_PRIORITY)
		end
	end

	-- return the request function
	-- url : (string)
	-- requestMethod : (string) "GET", "POST"
	-- args : (table, optional)
	--     options.throttlingPriority : (Enum.ThrottlingPriority, optional)
	--     options.contentType : (Enum.HttpContentType, optional)
	--     options.postBody : (string, optional ("POST" only))
	-- RETURNS : (promise<HttpResponse or string>)
	return function(url, requestMethod, options)
		assert(type(url) == "string", "Expected url to be a string")
		assert(type(requestMethod) == "string", "Expected requestMethod to be a string")
		assert(not options or type(options) == "table", "Expected options to be a table")
		requestMethod = string.upper(requestMethod)

		local httpFunction
		if requestMethod == "POST" then
			httpFunction = doHttpPost(url, options)
		elseif requestMethod == "GET" then
			httpFunction = doHttpGet(url)
		else
			error(string.format("Unsupported requestMethod : %s", requestMethod or "nil"))
		end

		return Promise.new(function(resolve, reject)
			if httpFunction then
				coroutine.wrap(function()
					local success, response = pcall(httpFunction)

					if success then
						local jsonSuccess, decodedJson = pcall(function()
							return HttpService:JSONDecode(response)
						end)
						if jsonSuccess then
							resolve({
								responseBody = decodedJson,
							})
						else
							reject(decodedJson)
						end
					else
						reject(response)
					end
				end)()
			else
				reject()
			end
		end)
	end
end