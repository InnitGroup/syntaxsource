local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Url = require(Modules.LuaApp.Http.Url)

--[[
	This endpoint returns a promise that resolves to:

	{
		"Text": "",
		"IsVisible": false
	}
]]--
return function(requestImpl)
	local url = string.format("%salerts/alert-info", Url.API_URL)
	return requestImpl(url, "GET")
end


