local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(universeId, socialLinks)
	assert(type(universeId) == "string",
		string.format("SetGameSocialLinks action expects universeId to be a string, was %s", type(universeId)))
	assert(type(socialLinks) == "table",
		string.format("SetGameSocialLinks action expects socialLinks to be a table, was %s", type(socialLinks)))

	return {
		universeId = universeId,
		socialLinks = socialLinks,
	}
end)