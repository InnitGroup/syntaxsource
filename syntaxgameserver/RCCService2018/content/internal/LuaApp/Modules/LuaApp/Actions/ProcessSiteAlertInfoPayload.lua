local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(data)
	assert(type(data) == "table",
		string.format("UpdateSiteMessageBannerText action expects data to be a table, was %s", type(data)))

	return {
		text = data.Text,
		visible = data.IsVisible or false
	}
end)
