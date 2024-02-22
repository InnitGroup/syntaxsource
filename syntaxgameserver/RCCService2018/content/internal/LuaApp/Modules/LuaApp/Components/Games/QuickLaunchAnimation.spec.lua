return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local QuickLaunchAnimation = require(Modules.LuaApp.Components.Games.QuickLaunchAnimation)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			quickLaunchAnimation = Roact.createElement(QuickLaunchAnimation, {
				gameCardHeight = 150,
				rewindAnimation = false,
				onAnimationDoneCallback = function() end,
				onRewindDoneCallback = function() end,
			})
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors when rewind", function()
		local element = mockServices({
			quickLaunchAnimation = Roact.createElement(QuickLaunchAnimation, {
				gameCardHeight = 150,
				rewindAnimation = true,
				onAnimationDoneCallback = function() end,
				onRewindDoneCallback = function() end,
			})
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end