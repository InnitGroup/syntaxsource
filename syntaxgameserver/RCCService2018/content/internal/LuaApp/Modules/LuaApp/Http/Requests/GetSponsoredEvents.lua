local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Url = require(Modules.LuaApp.Http.Url)

--[[
	This endpoint returns a promise that resolves to:
	[{
		"Name": "Imagination2018",
		"Title": "Imagination2018",
		"LogoImageURL": "https://images.rbxcdn.com/ecf1f303830daecfb69f2388c72cb6b8",
		"PageType": "Sponsored",
		"PageUrl": "/sponsored/Imagination2018"
	},
	{
		"Name": "JWCreator",
		"Title": "JWCreator",
		"LogoImageURL": "https://images.rbxcdn.com/aad3012235a2365cc5a236802d8fbb25",
		"PageType": "Sponsored",
		"PageUrl": "/sponsored/JWCreator"
	}]
]]--

return function(requestImpl)
	-- TODO(MOBLUAPP-663): Update this url when api endpoint is ready
	local url = string.format("%s/sponsoredpage/list-json", Url.BASE_URL)
	-- return a promise of the result listed above
	return requestImpl(url, "GET")
end