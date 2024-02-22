local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Actions = Modules.LuaApp.Actions
local SetGameSocialLinks = require(Actions.SetGameSocialLinks)
local Promise = require(Modules.LuaApp.Promise)
local GamesGetSocialLinks = require(Modules.LuaApp.Http.Requests.GamesGetSocialLinks)
local GameSocialLink = require(Modules.LuaApp.Models.GameSocialLink)
local SocialMediaType = require(Modules.LuaApp.Enum.SocialMediaType)

local checkSocialLinkType = function(linkType)
    for _, value in pairs(SocialMediaType) do
        if linkType == value then
            return true
        end
    end
    return false
end

return function(networkImpl, universeId)
    return function(store)
        return GamesGetSocialLinks(networkImpl, universeId):andThen(function(result)
            local data = result.responseBody.data
            local decodedSocialLinks = {}

            for _, socialLink in ipairs(data) do
                local decodedSocialLink = GameSocialLink.fromJsonData(socialLink)
                if not checkSocialLinkType(decodedSocialLink.type) then
                    warn("Can NOT recognize " .. decodedSocialLink.type .. " as a valid Social Link Type!")
                else
                    table.insert(decodedSocialLinks, decodedSocialLink)
                end
            end

            store:dispatch(SetGameSocialLinks(universeId, decodedSocialLinks))
            return Promise.resolve()
        end,

        -- failure handler for request 'GamesGetSocialLinks'
        function(err)
            return Promise.reject(err)
        end)
    end
end