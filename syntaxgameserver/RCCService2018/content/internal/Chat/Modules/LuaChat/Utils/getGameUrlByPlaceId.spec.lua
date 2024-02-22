return function()
	local getGameUrlByPlaceId = require(script.Parent.getGameUrlByPlaceId)
	local CorePackages = game:GetService("CorePackages")
	local trimCharacterFromEndString = require(CorePackages.AppTempCommon.Temp.trimCharacterFromEndString)

	describe("GetGameUrlByPlaceId", function()
		it("should throw an error if called an a non-string type", function()
			local placeId = 123456
			expect(function()
				getGameUrlByPlaceId(placeId)
			end).to.throw()
		end)

		it("Should return the game Url properly", function()
			local ContentProvider = game:GetService("ContentProvider")

			local BASE_URL = trimCharacterFromEndString(ContentProvider.BaseUrl, "/")
			local len = #BASE_URL
			if BASE_URL:find("https://www.") then
				BASE_URL = BASE_URL:sub(13, len)
			elseif BASE_URL:find("http://www.") then
				BASE_URL = BASE_URL:sub(12, len)
			end
			local WEB_URL = "https://www." .. BASE_URL.."/games/"

			local placeId = "123456"
			local expectedResult = WEB_URL .. placeId
			expect(getGameUrlByPlaceId(placeId)).to.equal(expectedResult)
		end)
	end)
end