local CorePackages = game:GetService("CorePackages")
local Promise = require(CorePackages.AppTempCommon.LuaApp.Promise)
local PerformFetch = require(CorePackages.AppTempCommon.LuaApp.Thunks.Networking.Util.PerformFetch)
local InspectAndBuyFolder = script.Parent.Parent
local Thunk = require(InspectAndBuyFolder.Thunk)
local Network = require(InspectAndBuyFolder.Services.Network)
local Analytics = require(InspectAndBuyFolder.Services.Analytics)
local SetFavoriteBundle = require(InspectAndBuyFolder.Actions.SetFavoriteBundle)
local SetBundles = require(InspectAndBuyFolder.Actions.SetBundles)
local BundleInfo = require(InspectAndBuyFolder.Models.BundleInfo)

local requiredServices = {
	Network,
	Analytics,
}

local function keyMapper(bundleId)
	return "inspectAndBuy.deleteFavoriteForBundle." ..tostring(bundleId)
end

--[[
	Unfavorites a bundle.
]]
local function DeleteFavoriteForBundle(bundleId)
	return Thunk.new(script.Name, requiredServices, function(store, services)
		local network = services[Network]
		local analytics = services[Analytics]

		return PerformFetch.Single(keyMapper(bundleId), function()
			return network.deleteFavoriteForBundle(bundleId):andThen(
				function()
					-- If Promise was resolved, the delete was a success!
					store:dispatch(SetFavoriteBundle(bundleId, false))
					local currentFavoriteCount = store:getState().bundles[bundleId].numFavorites
					local updatedAssetInformation = BundleInfo.fromGetBundleFavoriteCount(bundleId, currentFavoriteCount - 1)
					store:dispatch(SetBundles({updatedAssetInformation}))
					analytics.reportFavoriteItem("Bundle", bundleId, false, true, "", currentFavoriteCount - 1)
					return Promise.resolve()
				end,
				function(err)
					return Promise.reject(tostring(err.StatusMessage))
				end)
		end)(store):catch(function(err)
			local favoriteCount = store:getState().bundles[bundleId].numFavorites
			analytics.reportFavoriteItem("Bundle", bundleId, false, false, err, favoriteCount)
		end)
	end)
end

return DeleteFavoriteForBundle