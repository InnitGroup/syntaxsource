--[[
			// BatchThumbnailLoader.lua

			// Creates a batch thumbnail loader object that handles the loading
			// of mutiple thumb nails.

			// Thumbnails may not yet be generated, so this will retry and
			// assign the final thumbnail
]]

local CoreGui = game:GetService("CoreGui")
local ContentProvider = game:GetService('ContentProvider')
local Modules = CoreGui.RobloxGui.Modules

local Http = require(Modules.Shell.Http)
local LoadingWidget = require(Modules.Shell.LoadingWidget)
local Utility = require(Modules.Shell.Utility)

local RETRIES = 6
local FADE_IN_TIME = 0.25
local TEMPLATE_DECAL = Instance.new("Decal")
local BATCH_LIMIT = 30
local function preloadThumbnailAsync(assetId)
	TEMPLATE_DECAL.Texture = assetId
	ContentProvider:PreloadAsync({ TEMPLATE_DECAL })
end

local BatchThumbnailLoader = {}
--[[ Sizes ]]--
BatchThumbnailLoader.Sizes =
{
	Small = Vector2.new(100, 100);
	Medium = Vector2.new(250, 250);
	Large  = Vector2.new(576, 324);
}

function BatchThumbnailLoader:Init()
	self._active = true
	self.isLoading = false
	self.isRequesting = false
	self.imageObjects = {}
	self.loadingProps = {}
	self.newRequests = nil
	self.requests = nil
	self.uriMap = {}
	self.loaders = {}
	self.activeTry = 0
end

local function createThumbnailKey(token, size)
	return tostring(token)..tostring(size)
end

function BatchThumbnailLoader:CreateThumbnail(imageObject, token, size, showSpinner, fadeImage, spinnerProperties)
	spinnerProperties = spinnerProperties or {}
	if showSpinner == nil then
		showSpinner = true
	end
	if fadeImage == nil then
		fadeImage = true
	end
	local requestLoad = false
	local thumbnailKey = createThumbnailKey(token, size)
	if not self._active then
		BatchThumbnailLoader:Init()
	end
	if self.isLoading == false then
		requestLoad = true
		if self.newRequests == nil then
			self.newRequests = {}
		end
	end
	if self.newRequests[size] == nil then
		self.newRequests[size] = {}
	end
	table.insert(self.newRequests[size], token)

	if self.imageObjects[thumbnailKey] == nil then
		self.imageObjects[thumbnailKey] = {}
	end
	self.imageObjects[thumbnailKey][imageObject] = imageObject

	--Create the loading spinner.
	self.loadingProps[imageObject] = {}
	self.loadingProps[imageObject].showSpinner = showSpinner
	self.loadingProps[imageObject].fadeImage = fadeImage
	self.loadingProps[imageObject].spinnerProperties = spinnerProperties

	if self.uriMap[thumbnailKey] ~= nil then
		spawn(function()
			preloadThumbnailAsync(self.uriMap[thumbnailKey])
			BatchThumbnailLoader:_loadImage(imageObject, self.uriMap[thumbnailKey])
		end)
		return
	else
		BatchThumbnailLoader:_loadImage(imageObject, nil)
	end

	if requestLoad then
		spawn(function()
			BatchThumbnailLoader:BatchLoadThumbnailsAsync()
		end)
	end
end

function BatchThumbnailLoader:_loadImage(imageObject, imageUri)
	local loaded = imageUri ~= nil
	if imageObject == nil then
		return
	end
	imageObject.Image = ""
	if self.loadingProps[imageObject].fadeImage then
		local tween = Utility.PropertyTweener(imageObject, "ImageTransparency", 1, 1, 0,
				Utility.EaseInOutQuad, true, nil)
	end
	if not loaded then
		if self.loadingProps[imageObject].showSpinner then
			self.loadingProps[imageObject].spinnerProperties['Parent'] = self.loadingProps[imageObject].spinnerProperties['Parent']
																			or imageObject
			self.loaders[imageObject] = LoadingWidget(self.loadingProps[imageObject].spinnerProperties, nil, true)
		end
	else
		if self.loaders[imageObject] then
			self.loaders[imageObject]:Cleanup()
			self.loaders[imageObject] = nil
		end
		imageObject.Image = imageUri
		if self.loadingProps[imageObject].fadeImage then
			local tween = Utility.PropertyTweener(imageObject, "ImageTransparency", 1, 0, FADE_IN_TIME,
					Utility.EaseInOutQuad, true, nil)
		end
	end
end

function BatchThumbnailLoader:_loadThumbnails(tokens, size)
	local batchTokens;
	local reloadBatchList = {}
	local batchCount = 0
	while #tokens > 0 do
		batchCount = batchCount + 1
		batchTokens = {}
		if #tokens <= BATCH_LIMIT then
			batchTokens = tokens
			tokens = {}
		else
			for _=1, BATCH_LIMIT do
				local newToken = table.remove(tokens)
				table.insert(batchTokens, newToken)
			end
		end
		local result = Http.GetAssetThumbnailBatchAsync(batchTokens, size.x, size.y)
		if result then
			for i,v in ipairs(result) do
				local token = batchTokens[i]
				local isFinal = v["final"]
				if isFinal then
					local uri = v["url"]
					local thumbnailKey = createThumbnailKey(token, size)
					self.uriMap[thumbnailKey] = uri
					for _,imageObj in pairs(self.imageObjects[thumbnailKey]) do
						spawn(function()
							preloadThumbnailAsync(self.uriMap[thumbnailKey])
							BatchThumbnailLoader:_loadImage(imageObj, self.uriMap[thumbnailKey])
						end)
					end
				else
					table.insert(reloadBatchList, token)
				end
			end
		else
			for _,token in ipairs(batchTokens) do
				table.insert(reloadBatchList, token)
			end
		end
	end
	return reloadBatchList
end

function BatchThumbnailLoader:_batchLoadThumbnails(batchList)
	if batchList == nil then
		return nil
	end
	local requireReload = false
	local newBatchList = {};
	for size, tokens in pairs(batchList) do
		local reloadBatchList = BatchThumbnailLoader:_loadThumbnails(tokens, size)
		if #reloadBatchList ~= 0 then
			if newBatchList[size] == nil then
				newBatchList[size] = {}
			end
			requireReload = true
			newBatchList[size] = reloadBatchList
		end
	end
	if not requireReload then
		return nil
	end
	return newBatchList
end

-- marge new array into old array
local function mergeArray(newArray, oldArray)
	local mergedArray = {}
	if oldArray ~= nil then
		for size, tokens in pairs(oldArray) do
			mergedArray[size] = {}
			for _,token in ipairs(tokens) do
				table.insert(mergedArray[size], token)
			end
		end
	end
	if newArray ~= nil then
		for size, tokens in pairs(newArray) do
			if mergedArray[size] == nil then
				mergedArray[size] = {}
			end
			for _,token in ipairs(tokens) do
				table.insert(mergedArray[size], token)
			end
		end
	end
	return mergedArray
end

function BatchThumbnailLoader:_tryBatchLoadThumbnails(startTime)
	local activeTry = startTime
	local tryCount = 1
	--retries until the max number of attempts. Or if this is still the most recent batch.
	while tryCount <= RETRIES and activeTry == self.activeTry do
		self.isRequesting = true
		self.requests = BatchThumbnailLoader:_batchLoadThumbnails(self.requests)
		self.isRequesting = false
		if self.requests == nil then
			break
		end
		tryCount = tryCount + 1
		wait(tryCount ^ 2)
	end
end

function BatchThumbnailLoader:BatchLoadThumbnailsAsync()
	repeat
		wait(0.1)
	until self.isRequesting == false and self.isLoading == false
	self.isLoading = true
	if self.newRequests == nil then
		-- No new requests.
		self.isLoading = false
		return
	end
	--Merge the new list of tokens to load.
	self.requests = mergeArray(self.newRequests, self.requests)
	self.newRequests = nil
	self.isLoading = false
	if self.requests ~= nil then
		self.activeTry = tick()
		BatchThumbnailLoader:_tryBatchLoadThumbnails(self.activeTry)
	end
end

function BatchThumbnailLoader:SetTransparency(value, imageObject)
	if self.loaders[imageObject] ~= nil then
		self.loaders[imageObject]:SetTransparency(value)
	end
end

return BatchThumbnailLoader