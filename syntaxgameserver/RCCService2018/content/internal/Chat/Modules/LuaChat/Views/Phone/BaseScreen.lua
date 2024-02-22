--[[
	Defines a set of tweens and default lifecycle handlers appropriate for this
	platform.
]]

local BaseScreen = {}

function BaseScreen:Get(...)
	return self.new(...)
end

function BaseScreen:Template()
	local class = {}
	for key, value in pairs(self) do
		class[key] = value
	end
	return class
end

function BaseScreen:Start()
end

function BaseScreen:Stop()
end

function BaseScreen:Resume()
end

function BaseScreen:Pause()
end

function BaseScreen:Destruct()
end

return BaseScreen