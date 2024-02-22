return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local SocialMediaButton = require(Modules.LuaApp.Components.GameDetails.SocialMediaButton)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			SocialMediaButton = Roact.createElement(SocialMediaButton, {
                socialType = "YouTube",
                socialUrl = "https://www.youtube.com/channel/UCJP8p8a_w5qIQk5PAMNzz8Q",
                Size = UDim2.new(0, 60, 0, 60),
			}),
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end