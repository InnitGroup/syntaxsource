--[[
	{
		"url": string,
		"title": string,
		"type": string,
	}
]]

local GameSocialLink = {}

function GameSocialLink.new()
	local self = {}
	return self
end

function GameSocialLink.mock()
	local self = GameSocialLink.new()
    self.url = "https://discord.gg/f2vDJse"
    self.title = "Join the discord, to chat with players, and receive updates!"
    self.type = "Discord"
	return self
end

function GameSocialLink.fromJsonData(gameSocialLinkJson)
	local self = GameSocialLink.new()
    self.url = gameSocialLinkJson.url
    self.title = gameSocialLinkJson.title
    self.type = gameSocialLinkJson.type
	return self
end

return GameSocialLink
