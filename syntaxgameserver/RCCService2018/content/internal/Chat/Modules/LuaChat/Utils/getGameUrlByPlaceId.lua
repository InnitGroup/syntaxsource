local ContentProvider = game:GetService("ContentProvider")
local CorePackages = game:GetService("CorePackages")
local trimCharacterFromEndString = require(CorePackages.AppTempCommon.Temp.trimCharacterFromEndString)

local BASE_URL = trimCharacterFromEndString(ContentProvider.BaseUrl, "/")
local len = #BASE_URL
if BASE_URL:find("https://www.") then
	BASE_URL = BASE_URL:sub(13, len)
elseif BASE_URL:find("http://www.") then
	BASE_URL = BASE_URL:sub(12, len)
end
local WEB_URL = "https://www." .. BASE_URL.."/games/"

return function(placeId)
	assert(type(placeId) == "string", "getGameUrlByPlaceId expects a string; was given type: " .. type(placeId))

	return WEB_URL .. placeId
end
