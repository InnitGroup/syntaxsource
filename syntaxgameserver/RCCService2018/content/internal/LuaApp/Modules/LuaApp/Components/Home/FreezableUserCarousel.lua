local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Common = Modules.Common
local LuaApp = Modules.LuaApp

local Immutable = require(Modules.Common.Immutable)
local Roact = require(Common.Roact)

local UserCarousel = require(LuaApp.Components.Home.UserCarousel)

local FreezableUserCarousel = Roact.PureComponent:extend("FreezableUserCarousel")

function FreezableUserCarousel:init()
	self.state = {
		peopleListFrozen = false,
	}

	self.setPeopleListFrozen = function(frozen)
		self:setState({
			peopleListFrozen = frozen,
		})
	end
end

function FreezableUserCarousel:render()
	local props = Immutable.JoinDictionaries(self.props, {
		peopleListFrozen = self.state.peopleListFrozen,
		setPeopleListFrozen = self.setPeopleListFrozen,
	})

	return Roact.createElement(UserCarousel, props)
end

return FreezableUserCarousel