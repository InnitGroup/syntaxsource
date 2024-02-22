return function()
	local HttpService = game:GetService("HttpService")

	HACK_NO_XPCALL()

	it("should throw if Url is not a string", function()
		local options = {
			Url = true,
			Method = "GET",
		}

		expect(function()
			HttpService:RequestInternal(options)
		end).to.throw()
	end)

	it("should throw if method is invalid", function()
		local options = {
			Url = "https://google.com",
			Method = "&&&",
		}

		expect(function()
			HttpService:RequestInternal(options)
		end).to.throw()
	end)

	it("should not throw if Url and Method are valid", function()
		local options = {
			Url = "https://google.com",
			Method = "GET",
		}

		expect(HttpService:RequestInternal(options)).to.be.ok()
	end)

	it("should not throw if CachePolicy, Timeout, and Priority are valid", function()
		local options = {
			Url = "https://google.com",
			Method = "GET",
			Timeout = 20,
			Priority = 20,
			CachePolicy = Enum.HttpCachePolicy.Full,
		}
		expect(HttpService:RequestInternal(options)).to.be.ok()
	end)

	it("should be able to be canceled", function()
		local options = {
			Url = "https://google.com",
			Method = "GET",
		}

		local request = HttpService:RequestInternal(options)

		local response = nil
		local success = nil
		request:Start(function(suc, resp)
			success = suc
			response = resp
		end)
		request:Cancel()

		while response == nil do
			wait()
		end

		expect(success).to.equal(false)
		expect(response.HttpError).to.equal(Enum.HttpError.Aborted)
	end)
end