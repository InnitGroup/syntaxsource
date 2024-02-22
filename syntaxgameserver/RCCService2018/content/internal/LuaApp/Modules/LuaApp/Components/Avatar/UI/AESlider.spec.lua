return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AESlider = require(Modules.LuaApp.Components.Avatar.UI.AESlider)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		local scalesInfo = {
			{
				property = "height",
				title = 'Feature.Avatar.Label.Height',
				min = 0.95,
				max = 1.05,
				default = 1.0,
				increment = .01,
				setScale = function(scale) end,
			}, {
				property = "width",
				title = 'Feature.Avatar.Label.Width',
				min = 0.70,
				max = 1.00,
				default = 1.0,
				increment = .01,
				setScale = function(scale) end,
			}, {
				property = "head",
				title = 'Feature.Avatar.Label.Head',
				min = 0.95,
				max = 1.00,
				default = 1,
				increment = .01,
				setScale = function(scale) end,
			}, {
				property = "bodyType",
				title = 'Feature.Avatar.Label.BodyType',
				min = 0.00,
				max = 0.30,
				default = 0.00,
				increment = 0.01,
				setScale = function(scale) end,
			}, {
				property = "proportion",
				title = 'Feature.Avatar.Label.Proportions',
				min = 0.00,
				max = 1.00,
				default = 0.0,
				increment = 0.01,
				setScale = function(scale) end,
			}
		}
		it("should create and destroy without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local mockScrollingFrame = Instance.new("ScrollingFrame")

			local element = mockServices({
				slider = Roact.createElement(AESlider, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					index = 1,
					scaleInfo = scalesInfo[1],
					scrollingFrameRef = mockScrollingFrame,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end
end