local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local AEWebApi = {}

local BASE_URL = ContentProvider.BaseUrl
for _, word in pairs({"/", "www.", "https:", "http:" }) do
	BASE_URL = string.gsub(BASE_URL, word, "")
end

local AVATAR_URL = "https://avatar." ..BASE_URL
local WEB_URL = "https://www." .. BASE_URL
local CATALOG_URL = "https://www." ..BASE_URL .."/catalog/"

-- local API_URL = "https://api." ..BASE_URL
-- local ASSET_IMAGE_URL_150 = "https://www." ..BASE_URL .."/Thumbs/Asset.ashx?width=150&height=150&assetId="


AEWebApi.Status = {
	PENDING = 0,
	UNKNOWN_ERROR = -1,
	NO_CONNECTIVITY = -2,
	INVALID_JSON = -3,
	BAD_TLS = -4,
	MODERATED = -5,

	OK = 200,
	BAD_REQUEST = 400,
	UNAUTHORIZED = 401,
	FORBIDDEN = 403,
	NOT_FOUND = 404,
	REQUEST_TIMEOUT = 408,
	INTERNAL_SERVER_ERROR = 500,
	NOT_IMPLEMENTED = 501,
	BAD_GATEWAY = 502,
	SERVICE_UNAVAILABLE = 503,
	GATEWAY_TIMEOUT = 504,
}

local function jsonEncode(data)
	return HttpService:JSONEncode(data)
end

local function jsonDecode(data)
	return HttpService:JSONDecode(data)
end

local function httpGet(url)
	return game:HttpGetAsync(url)
end

local function httpPost(url, payload)
	return game:HttpPostAsync(url, payload, "application/json")
end

local function getHttpStatus(response)
	for _, code in pairs(AEWebApi.Status) do
		if code >= 100 and response:find(tostring(code)) then
			return code
		end
	end

	if response:find("2%d%d") then
		return AEWebApi.Status.OK
	end

	if response:find("curl_easy_perform") and response:find("SSL") then
		return AEWebApi.Status.BAD_TLS
	end

	return AEWebApi.Status.UNKNOWN_ERROR
end

local function httpGetJson(url)
	local success, response = pcall(httpGet, url)
	local status = success and AEWebApi.Status.OK or getHttpStatus(response)

	if success then
		success, response = pcall(jsonDecode, response)
		status = success and status or AEWebApi.Status.INVALID_JSON
	end

	return response, status
end

local function httpPostJson(url, payload)
	local success, response = pcall(httpPost, url, payload)
	local status = success and AEWebApi.Status.OK or getHttpStatus(response)

	if success then
		success, response = pcall(jsonDecode, response)
		status = success and status or AEWebApi.Status.INVALID_JSON
	end

	return response, status
end

function AEWebApi.GetAvatarData()
	local url = AVATAR_URL .. "/v1/avatar"

	local result, status = httpGetJson(url)

	return status, result
end

--[[
	Create a web request query string to put on the end of a URL given a data
	table.

	Arrays are handled, but generally data is expected to be flat.
]]
local function makeQueryString(data)
	local params = {}

	for key, value in pairs(data) do
		if value ~= nil then --for optional params
			if type(value) == "table" then
				for i = 1, #value do
					table.insert(params, key .. "=" .. value[i])
				end
			else
				table.insert(params, key .. "=" .. tostring(value))
			end
		end
	end

	return table.concat(params, "&")
end

--Set the avatar's body colors. bodyColorsData: Table of body colors for the avatar.
function AEWebApi.SetBodyColors(bodyColorsData)
	local data = jsonEncode({
		headColorId = bodyColorsData["headColorId"],
		leftArmColorId = bodyColorsData["leftArmColorId"],
		leftLegColorId = bodyColorsData["leftLegColorId"],
		rightArmColorId = bodyColorsData["rightArmColorId"],
		rightLegColorId = bodyColorsData["rightLegColorId"],
		torsoColorId = bodyColorsData["torsoColorId"],
	})

	local url = AVATAR_URL .. "/v1/avatar/set-body-colors"
	local _, status = httpPostJson(url, data)

	return status
end

--Set the avatar's scales. Checks for bodyType and Proportion.
function AEWebApi.SetScales(scalesData)
	local data

	if scalesData.bodyType then
		data = jsonEncode({
			height = string.format("%.4f", scalesData.height),
			width = string.format("%.4f", scalesData.width),
			head = string.format("%.4f", scalesData.head),
			depth = string.format("%.4f", scalesData.depth),
			proportion = string.format("%.4f", scalesData.proportion),
			bodyType = string.format("%.4f", scalesData.bodyType),
		})
	else
		data = jsonEncode({
			height = string.format("%.4f", scalesData.height),
			width = string.format("%.4f", scalesData.width),
			head = string.format("%.4f", scalesData.head),
			depth = string.format("%.4f", scalesData.depth),
		})
	end

	local url = AVATAR_URL .. "/v1/avatar/set-scales"

	local _, status = httpPostJson(url, data)

	return status
end

function AEWebApi.SetPlayerAvatarType(avatarType)
	local data = jsonEncode({
		playerAvatarType = avatarType,
	})

	local url = AVATAR_URL .. "/v1/avatar/set-player-avatar-type"

	local _, status = httpPostJson(url, data)

	return status
end

--Sets the assets being worn by the user.
function AEWebApi.SetWearingAssets(assetsData)
	local data = jsonEncode({
		assetIds = assetsData,
	})

	local url = AVATAR_URL .. "/v1/avatar/set-wearing-assets"

	local result, status = httpPostJson(url, data)

	if status == AEWebApi.Status.OK then
		if not result.success then
			status = AEWebApi.Status.UNKNOWN_ERROR
		end
	end

	return status
end

function AEWebApi.GetOutfit(outfitId)
	local url = AVATAR_URL .. "/v1/outfits/" .. outfitId .. "/details"

	local result, status = httpGetJson(url)

	return result, status
end

function AEWebApi.GetAvatar()
	local url = AVATAR_URL .. "/v1/avatar"

	local result, status = httpGetJson(url)

	return result, status
end

function AEWebApi.GetOutfitImage(outfitId)
	local url = "https://www." ..BASE_URL .."/outfit-thumbnail/image?userOutfitId=" ..tostring(outfitId)
		.."&width=100&height=100&format=png"

	return url
end

function AEWebApi.GetAssetImage(assetId)
	local url = "https://www." ..BASE_URL .."/Thumbs/Asset.ashx?width=110&height=110&assetId=" ..tostring(assetId)

	return url
end

function AEWebApi.GetUserInventory(assetTypeId, itemsPerPage, userId, cursor)
	local query = makeQueryString({
		assetTypeId = assetTypeId,
		itemsPerPage = itemsPerPage,
		userId = userId,
		cursor = cursor
	})

	local url = WEB_URL .. "/users/inventory/list-json?" .. query

	local result, status = httpGetJson(url)

	return result, status
end

function AEWebApi.GetUserOutfits(userId, desiredPageNumber, itemsPerPage)
	local query = makeQueryString({
		page = desiredPageNumber,
		itemsPerPage = itemsPerPage
	})

	local url = AVATAR_URL .. "/v1/users/" .. userId .. "/outfits?" .. query

	local result, status = httpGetJson(url)

	return result, status
end

function AEWebApi.GetAvatarRules()
	local url = AVATAR_URL .. "/v1/avatar-rules"

	local result, status = httpGetJson(url)

	return result, status
end

function AEWebApi.GetRecentItems(category)
	local url = AVATAR_URL .. "/v1/recent-items/" .. category .. "/list"

	local result, status = httpGetJson(url)

	return result, status
end

--[[
function AEWebApi.GetUsername(id)
	local url = API_URL .. "/users/" .. tostring(id)

	local result, status = httpGetJson(url)

	if status == AEWebApi.Status.OK then
		return result.Username
	end

	return result, status
end

]]
function AEWebApi.GetRecommendedAssetListRequest(assetTypeId)
	local query = makeQueryString({
		assetTypeId = assetTypeId,
		numItems = AEConstants.recommendedItems
	})

	local url = WEB_URL .. "/assets/recommended-json?" .. query

	local result, status = httpGetJson(url)

	return result, status
end

function AEWebApi.GetCatalogUrlForAsset(assetId)
	return CATALOG_URL .. assetId
end

return AEWebApi