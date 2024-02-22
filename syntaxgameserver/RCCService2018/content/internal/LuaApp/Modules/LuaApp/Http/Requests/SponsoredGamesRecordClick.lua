local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Url = require(Modules.LuaApp.Http.Url)

return function(requestImpl, sponsoredGameCode)
	local url = string.format("%sv1/sponsored-games/click", Url.ADS_URL)

	return requestImpl(url, "POST", { postBody = "\""..sponsoredGameCode.."\"" })
end