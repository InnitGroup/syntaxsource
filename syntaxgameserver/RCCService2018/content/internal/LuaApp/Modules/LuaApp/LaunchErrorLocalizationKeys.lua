local Modules = game:GetService("CoreGui").RobloxGui.Modules
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local PlayabilityStatus = require(Modules.LuaApp.Enum.PlayabilityStatus)
local DEFAULT_KEY = "Default"

local LaunchErrorLocalizationKeys = {}

local LaunchErrorMessages =
{
    [RetrievalStatus.Failed] = "Feature.GamePage.QuickLaunch.LaunchError.RequestFailed",
    [PlayabilityStatus.GuestProhibited] = "Feature.GamePage.QuickLaunch.LaunchError.GuestProhibited",
    [PlayabilityStatus.GameUnapproved] = "Feature.GamePage.QuickLaunch.LaunchError.GameUnapproved",
    [PlayabilityStatus.UniverseRootPlaceIsPrivate] =
        "Feature.GamePage.QuickLaunch.LaunchError.UniverseRootPlaceIsPrivate",
    [PlayabilityStatus.InsufficientPermissionFriendsOnly] =
        "Feature.GamePage.QuickLaunch.LaunchError.InsufficientPermissionFriendsOnly",
    [PlayabilityStatus.InsufficientPermissionGroupOnly] =
        "Feature.GamePage.QuickLaunch.LaunchError.InsufficientPermissionGroupOnly",
    [PlayabilityStatus.DeviceRestricted] = "Feature.GamePage.QuickLaunch.LaunchError.DeviceRestricted",
    [PlayabilityStatus.UnderReview] = "Feature.GamePage.QuickLaunch.LaunchError.UnderReview",
    [PlayabilityStatus.PurchaseRequired] = "Feature.GamePage.QuickLaunch.LaunchError.PurchaseRequired",
    [PlayabilityStatus.AccountRestricted] = "Feature.GamePage.QuickLaunch.LaunchError.AccountRestricted",
    [PlayabilityStatus.TemporarilyUnavailable] = "Feature.GamePage.QuickLaunch.LaunchError.TemporarilyUnavailable",
    [DEFAULT_KEY] = "Feature.GamePage.QuickLaunch.LaunchError.UnplayableOtherReason",
}

setmetatable(LaunchErrorLocalizationKeys,
    {
        __newindex = function(t, key, index)
        end,
        __index = function(t, index)
            assert(index ~= nil, "LaunchErrorLocalizationKeys needs a key")
            return LaunchErrorMessages[index] or LaunchErrorMessages[DEFAULT_KEY]
        end
    })

return LaunchErrorLocalizationKeys