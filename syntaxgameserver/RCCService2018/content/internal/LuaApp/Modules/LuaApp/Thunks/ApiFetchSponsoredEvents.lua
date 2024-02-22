local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local GetSponsoredEvents = require(Modules.LuaApp.Http.Requests.GetSponsoredEvents)
local SetSponsoredEventsFetchingStatus = require(Modules.LuaApp.Actions.SetSponsoredEventsFetchingStatus)
local SetSponsoredEvents = require(Modules.LuaApp.Actions.SetSponsoredEvents)
local SponsoredEvent = require(Modules.LuaApp.Models.SponsoredEvent)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

return function(networkImpl)
	return function(store)
		store:dispatch(SetSponsoredEventsFetchingStatus(RetrievalStatus.Fetching))

		return GetSponsoredEvents(networkImpl):andThen(function(result)
			local eventsInfo = result.responseBody
			local sponsoredEvents = {}

			-- TODO(MOBLUAPP-663): No need to check if eventsInfo is a table when api endpoint is ready
			if type(eventsInfo) == "table" then
				for index, eventInfo in ipairs(eventsInfo) do
					sponsoredEvents[index] = SponsoredEvent.fromJsonData(eventInfo)
				end
			end

			if #sponsoredEvents > 0 then
				store:dispatch(SetSponsoredEvents(sponsoredEvents))
			end

			store:dispatch(SetSponsoredEventsFetchingStatus(RetrievalStatus.Done))
			return Promise.resolve()
		end,
		function(error)
			store:dispatch(SetSponsoredEventsFetchingStatus(RetrievalStatus.Failed))
			return Promise.reject(error)
		end)
	end
end