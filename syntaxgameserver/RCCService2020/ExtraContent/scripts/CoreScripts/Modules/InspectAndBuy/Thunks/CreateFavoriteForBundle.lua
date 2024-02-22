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
	return "inspectAndBuy.createFavoriteForBundle." ..tostring(bundleId)
end

--[[
	Favorites a bundle.
]]
local function CreateFavoriteForBundle(bundleId)
	return Thunk.new(script.Name, requiredServices, function(store, services)
		local network = services[Network]
		local analytics = services[Analytics]

		return PerformFetch.Single(keyMapper(bundleId), function()
			return network.createFavoriteForBundle(bundleId):andThen(
				function()
					-- If Promise was resolved, the favorite was a success!
					store:dispatch(SetFavoriteBundle(bundleId, true))
					local currentFavoriteCount = store:getState().bundles[bundleId].numFavorites
					local updatedAssetInformation = BundleInfo.fromGetBundleFavoriteCount(bundleId, currentFavoriteCount + 1)
					store:dispatch(SetBundles({updatedAssetInformation}))
					analytics.reportFavoriteItem("Bundle", bundleId, true, true, "", currentFavoriteCount + 1)
					return Promise.resolve()
				end,
				function(err)
					return Promise.reject(tostring(err.StatusMessage))
				end)
		end)(store):catch(function(err)
			local favoriteCount = store:getState().bundles[bundleId].numFavorites
			analytics.reportFavoriteItem("Bundle", bundleId, true, false, err, favoriteCount)
		end)
	end)
end

return CreateFavoriteForBundle