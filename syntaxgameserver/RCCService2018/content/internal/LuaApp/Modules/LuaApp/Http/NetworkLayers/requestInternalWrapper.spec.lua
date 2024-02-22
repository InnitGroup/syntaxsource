return function()
	local request = require(script.Parent.requestInternalWrapper)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local HttpError = require(Modules.LuaApp.Http.HttpError)
	local StatusCodes = require(Modules.LuaApp.Http.StatusCodes)

	HACK_NO_XPCALL()

	local function createTestRequestFunc(testResponse)
		local requestService = {}
		function requestService:RequestInternal()
			local httpRequest = {}
			function httpRequest:Start(callback)
				callback(true, testResponse)
			end
			return httpRequest
		end

		return request(requestService)
	end

	it("should return a function", function()
		expect(request()).to.be.ok()
		expect(type(request())).to.equal("function")
	end)

	it("which returns a promise that resolves to an HttpResponse", function()
		local responseUpval

		local testRequest
		if settings():GetFFlag("TrackCurlTimeProfile") then
			testRequest = createTestRequestFunc({
				StatusCode = 200,
				Stats = {
	                DurationInQueue = 0,
	                DurationNameLookup = 0,
	                DurationConnect = 0,
	                DurationSSLHandshake = 0,
	                DurationMakeRequest = 0,
	                DurationReceiveResponse = 0,
	                RoundTripTime = 0,
				},
	            Body = '{"data" : "foo"}',
			})
		else
			testRequest = createTestRequestFunc({
	            StatusCode = 200,
	            RoundTripTime = 0,
	            Body = '{"data" : "foo"}',
			})
		end
		local httpPromise = testRequest("testUrl", "GET")
		httpPromise:andThen(function(response)
			responseUpval = response
		end)

		wait()

		expect(responseUpval.requestUrl).to.equal("testUrl")
		expect(responseUpval.responseBody.data).to.equal("foo")
		expect(responseUpval.responseCode).to.equal(StatusCodes.OK)
	end)
end