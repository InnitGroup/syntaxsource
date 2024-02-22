--[[
	{
		"name": string,
		"title": string,
		"imageUrl": string,
		"pageType": string,
		"pageUrl": string
	}
]]

local SponsoredEvent = {}

function SponsoredEvent.new()
	local self = {}
	return self
end

function SponsoredEvent.mock()
	local self = SponsoredEvent.new()
	self.name = "Imagination2018"
	self.title = "Imagination2018"
	self.imageUrl = "https://images.rbxcdn.com/ecf1f303830daecfb69f2388c72cb6b8"
	self.pageType = "Sponsored"
	self.pageUrl = "/sponsored/Imagination2018"
	return self
end

function SponsoredEvent.fromJsonData(sponsoredEventJson)
	local self = SponsoredEvent.new()
	self.name = sponsoredEventJson.Name
	self.title = sponsoredEventJson.Title
	self.imageUrl = sponsoredEventJson.LogoImageURL
	self.pageType = sponsoredEventJson.PageType
	self.pageUrl = sponsoredEventJson.PageUrl
	return self
end

return SponsoredEvent