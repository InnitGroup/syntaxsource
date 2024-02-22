--[[
	A limited, simple implementation of a Signal.

	Handlers are fired in order, and (dis)connections are properly handled when
	executing an event.

	Signal uses Immutable to avoid invalidating the 'Fire' loop iteration.
]]

local Immutable = require(script.Parent.Immutable)

local Signal = {}

Signal.__index = Signal

function Signal.new()
	local self = {
		_listeners = {}
	}

	setmetatable(self, Signal)

	return self
end

function Signal:Connect(callback)
	local listener = {
		callback = callback,
		isConnected = true,
	}
	self._listeners = Immutable.Append(self._listeners, listener)

	local function disconnect()
		listener.isConnected = false
		self._listeners = Immutable.RemoveValueFromList(self._listeners, listener)
	end

	return {
		Disconnect = disconnect
	}
end

function Signal:Fire(...)
	for _, listener in ipairs(self._listeners) do
		if listener.isConnected then
			listener.callback(...)
		end
	end
end

return Signal