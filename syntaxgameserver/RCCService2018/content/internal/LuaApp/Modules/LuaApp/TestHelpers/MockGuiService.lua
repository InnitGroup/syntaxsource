local MockGuiService = {}
MockGuiService.__index = MockGuiService

function MockGuiService.new()
	local self = {
		broadcasts = {},
	}
	setmetatable(self, {
		__index = MockGuiService,
	})
	return self
end

function MockGuiService:BroadcastNotification(data, notification)
	self.broadcasts[#self.broadcasts+1] = {
		data = data,
		notification = notification,
	}
end

function MockGuiService:SetGlobalGuiInset(x1, y1, x2, y2)
end

function MockGuiService:SafeZoneOffsetsChanged()
end

return MockGuiService