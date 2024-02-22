local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local AESlider = require(Modules.LuaApp.Components.Avatar.UI.AESlider)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AESendAnalytics = require(Modules.LuaApp.Thunks.AEThunks.AESendAnalytics)
local AESetAvatarScales = require(Modules.LuaApp.Actions.AEActions.AESetAvatarScales)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local AESlidersFrame = Roact.PureComponent:extend("AESlidersFrame")

local View = {
	[DeviceOrientationMode.Portrait] = {
		EXTRA_VERTICAL_SHIFT = 25,
		SLIDER_POSITION_Y = 70,
		SLIDER_VERTICAL_OFFSET = 70,
	},

	[DeviceOrientationMode.Landscape] = {
		EXTRA_VERTICAL_SHIFT = 8,
		SLIDER_POSITION_Y = 56,
		SLIDER_VERTICAL_OFFSET = 67,
	}
}

function AESlidersFrame:init()
	local setScales = self.props.setScales
	local analytics = self.props.analytics
	local sendAnalytics = self.props.sendAnalytics
	local deviceOrientation = self.props.deviceOrientation
	local scrollingFrameRef = self.props.scrollingFrameRef
	local scalesRules = self.props.scalesRules
	scrollingFrameRef.CanvasPosition = Vector2.new(0, 0)

	scrollingFrameRef.CanvasSize = UDim2.new(0, 0, 0, View[deviceOrientation].SLIDER_POSITION_Y
		+ (View[deviceOrientation].SLIDER_VERTICAL_OFFSET * 4) + (View[deviceOrientation].EXTRA_VERTICAL_SHIFT + 25))

	if (settings():GetFFlag("AvatarEditorUseAvatarRulesForScales")) then
		self.scalesInfo = {
			[1] = {
				property = "height",
				title = 'Feature.Avatar.Label.Height',
				min = scalesRules.height.min,
				max = scalesRules.height.max,
				default = 1.0,
				increment = scalesRules.height.increment,
				setScale = function(scale)
					setScales({height = scale})
					sendAnalytics(analytics.setAvatarHeight, scale)
				end,
			},
			[2] = {
				property = "width",
				title = 'Feature.Avatar.Label.Width',
				min = scalesRules.width.min,
				max = scalesRules.width.max,
				default = 1.0,
				increment = scalesRules.width.increment,
				setScale = function(scale)
					setScales({
						width = scale,
						depth = 0.5 * scale + 0.5,
					})
					sendAnalytics(analytics.setAvatarWidth, scale)
				end,
			},
			[3] = {
				property = "head",
				title = 'Feature.Avatar.Label.Head',
				min = scalesRules.head.min,
				max = scalesRules.head.max,
				default = 1,
				increment = scalesRules.head.increment,
				setScale = function(scale)
					setScales({head = scale})
					sendAnalytics(analytics.setAvatarHeadSize, scale)
				end,
			},
			[4] = {
				property = "bodyType",
				title = 'Feature.Avatar.Label.BodyType',
				min = scalesRules.bodyType.min,
				max = scalesRules.bodyType.max,
				default = 0.00,
				increment = scalesRules.bodyType.increment,
				setScale = function(scale)
					setScales({bodyType = scale})
					sendAnalytics(analytics.setAvatarBodyType, scale)
				end,
			},
			[5] = {
				property = "proportion",
				title = 'Feature.Avatar.Label.Proportions',
				min = scalesRules.proportion.min,
				max = scalesRules.proportion.max,
				default = 0.0,
				increment = scalesRules.proportion.increment,
				setScale = function(scale)
					setScales({proportion = scale})
					sendAnalytics(analytics.setAvatarProportion, scale)
				end,
			}
		}
	else
		self.scalesInfo = {
			[1] = {
				property = "height",
				title = 'Feature.Avatar.Label.Height',
				min = 0.90,
				max = 1.05,
				default = 1.0,
				increment = .01,
				setScale = function(scale)
					setScales({height = scale})
					sendAnalytics(analytics.setAvatarHeight, scale)
				end,
			},
			[2] = {
				property = "width",
				title = 'Feature.Avatar.Label.Width',
				min = 0.70,
				max = 1.00,
				default = 1.0,
				increment = .01,
				setScale = function(scale)
					setScales({
						width = scale,
						depth = 0.5 * scale + 0.5,
					})
					sendAnalytics(analytics.setAvatarWidth, scale)
				end,
			},
			[3] = {
				property = "head",
				title = 'Feature.Avatar.Label.Head',
				min = 0.95,
				max = 1.00,
				default = 1,
				increment = .01,
				setScale = function(scale)
					setScales({head = scale})
					sendAnalytics(analytics.setAvatarHeadSize, scale)
				end,
			},
			[4] = {
				property = "bodyType",
				title = 'Feature.Avatar.Label.BodyType',
				min = 0.00,
				max = 0.30,
				default = 0.00,
				increment = 0.01,
				setScale = function(scale)
					setScales({bodyType = scale})
					sendAnalytics(analytics.setAvatarBodyType, scale)
				end,
			},
			[5] = {
				property = "proportion",
				title = 'Feature.Avatar.Label.Proportions',
				min = 0.00,
				max = 1.00,
				default = 0.0,
				increment = 0.01,
				setScale = function(scale)
					setScales({proportion = scale})
					sendAnalytics(analytics.setAvatarProportion, scale)
				end,
			}
		}
	end
end

function AESlidersFrame:render()
	local scrollingFrameRef = self.props.scrollingFrameRef
	local deviceOrientation = self.props.deviceOrientation
	local scalesInfo = self.scalesInfo
	local sliders = {}

	-- Create all the sliders
	for index = 1, #scalesInfo do
		sliders["Slider-" ..index] = Roact.createElement(AESlider, {
			index = index,
			deviceOrientation = deviceOrientation,
			scaleInfo = scalesInfo[index],
			scrollingFrameRef = scrollingFrameRef,
		})
	end

	local backgroundSize = View[deviceOrientation].SLIDER_POSITION_Y * (#scalesInfo + 1)
	sliders["BackgroundImage"] = Roact.createElement("ImageLabel", {
		Position =  UDim2.new(0, 3, 0, View[deviceOrientation].EXTRA_VERTICAL_SHIFT + 5),
		Visible = true,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -6, 0, backgroundSize)
	})

	local SliderFrame = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, backgroundSize),
			BackgroundTransparency = 1,
		},
			sliders)

	scrollingFrameRef.CanvasSize = UDim2.new(0, 0, 0, View[deviceOrientation].SLIDER_POSITION_Y
		+ (View[deviceOrientation].SLIDER_VERTICAL_OFFSET * 4) + (View[deviceOrientation].EXTRA_VERTICAL_SHIFT + 25))

	return SliderFrame
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			scalesRules = state.AEAppReducer.AEAvatarSettings[AEConstants.AvatarSettings.scalesRules],
		}
	end,
	function(dispatch)
		return {
			setScales = function(scales)
				dispatch(AESetAvatarScales(scales))
			end,
			sendAnalytics = function(analyticsFunction, value)
				dispatch(AESendAnalytics(analyticsFunction, value))
			end,
		}
	end
)(AESlidersFrame)