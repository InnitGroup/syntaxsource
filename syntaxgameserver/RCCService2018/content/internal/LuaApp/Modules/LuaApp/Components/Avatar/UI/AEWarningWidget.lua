local Modules = game:GetService("CoreGui").RobloxGui.Modules
local TweenService = game:GetService("TweenService")
local Roact = require(Modules.Common.Roact)
local Constants = require(Modules.LuaApp.Constants)
local RoactRodux = require(Modules.Common.RoactRodux)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local AEWarningWidget = Roact.PureComponent:extend("AEWarningWidget")

function AEWarningWidget:tweenClosed()
	self.closeWarningText:Play()
	self.closeWarningWidget:Play()
	self.closeWarningIcon:Play()
end

function AEWarningWidget:tweenOpen()
	self:resetWarningWidget()
	self.openWarningWidget:Play()
	self.openWarningIcon:Play()

	-- Text should appear after the warning has expanded
	spawn(function()
		wait(0.15)
		if self.open then
			self.openWarningText:Play()
		end
	end)
end

function AEWarningWidget:resetWarningWidget()
	self.warningWidgetRef.current.WarningText.TextTransparency = 1
	self.warningWidgetRef.current.Size = UDim2.new(0, 70, 0, 70)
	self.warningWidgetRef.current.Position = UDim2.new(0.5, -35, 0.5, -35)
	self.warningWidgetRef.current.WarningIcon.Position = UDim2.new(0.5, -24, 0.5, -24)
	self.warningWidgetRef.current.WarningIcon.ImageTransparency = 1
	self.warningWidgetRef.current.WarningIcon.Rotation = 0
end

function AEWarningWidget:init()
	self.warningWidgetRef = Roact.createRef()
	self.open = false
end

function AEWarningWidget:didMount()
	local warning = self.warningWidgetRef.current
	local tweenInfo = TweenInfo.new(0.3)

	self.openWarningWidget = TweenService:Create(warning, tweenInfo, {
		Size = UDim2.new(0, 300, 0, 70);
		Position = UDim2.new(0.5, -150, 0.5, -35);
		Visible = true
	})
	self.openWarningIcon = TweenService:Create(warning.WarningIcon, tweenInfo, {
		Rotation = -360;
		ImageTransparency = 0;
		Position = UDim2.new(0, 12, 0.5, -24);
	})
	self.openWarningText = TweenService:Create(warning.WarningText, tweenInfo, { TextTransparency = 0 })

	self.closeWarningWidget = TweenService:Create(warning, tweenInfo, {
		Size = UDim2.new(0, 70, 0, 70);
		Position = UDim2.new(0.5, -35, 0.5, -35);
		Visible = false
	})
	self.closeWarningIcon = TweenService:Create(warning.WarningIcon, tweenInfo, {
		Position = UDim2.new(0.5, -24, 0.5, -24),
		ImageTransparency = 1
	})
	self.closeWarningText = TweenService:Create(warning.WarningText, TweenInfo.new(0.1), { TextTransparency = 1 })
end

function AEWarningWidget:didUpdate(prevProps, prevState)
	local warningInformation = self.props.warningInformation[1]
	local fullView = self.props.fullView

	if self.warningWidgetRef.current.Visible and not warningInformation then
		self:tweenClosed()
		self.open = false
	end

	if warningInformation and prevProps.warningInformation[1] ~= warningInformation then
		self:tweenOpen()
		self.open = true
	end

	-- Don't show warning while in full view.
	if self.warningWidgetRef.current and self.warningWidgetRef.current.Visible and fullView then
		self.warningWidgetRef.current.Visible = false
	elseif warningInformation and self.warningWidgetRef.current
		and not self.warningWidgetRef.current.Visible and not fullView then
		self.warningWidgetRef.current.Visible = true
	end
end

function AEWarningWidget:render()
	return Roact.createElement("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 70, 0, 70),
		Position = UDim2.new(.5, -35, .5, -35),
		Visible = false,

		[Roact.Ref] = self.warningWidgetRef
	}, {

		BackgroundFill = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -68, 0, 70),
			Position = UDim2.new(0, 34, 0, 0),
			Image = "rbxasset://textures/AvatarEditorImages/Stretch/gr-tail.png",
			ImageColor3 = Color3.fromRGB(31, 31, 31),
			ImageTransparency = 0.25,
		}),

		RoundedEnd = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 34, 0, 70),
			Position = UDim2.new(1, -34, 0, 0),
			Image = 'rbxasset://textures/AvatarEditorImages/Sheet.png',
			ImageColor3 = Color3.fromRGB(31, 31, 31),
			ImageRectOffset = Vector2.new(1954, 243),
			ImageRectSize = Vector2.new(34, 70),
			ImageTransparency = 0.25,
		}),

		RoundedStart = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 34, 0, 70),
			Image = 'rbxasset://textures/AvatarEditorImages/Sheet.png',
			ImageColor3 = Color3.fromRGB(31, 31, 31),
			ImageRectOffset = Vector2.new(1988, 243),
			ImageRectSize = Vector2.new(-34, 70),
			ImageTransparency = 0.25,
		}),

		WarningIcon = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 48, 0, 48),
			Position = UDim2.new(0.5, -12, 0.5, -24),
			Image = 'rbxasset://textures/ui/ErrorIcon.png',
			ImageTransparency = 1,
			Rotation = 0,
		}),

		WarningText = Roact.createElement(LocalizedTextLabel, {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Text = self.props.warningInformation[1]
				and self.props.warningInformation[1].text or 'Feature.Avatar.Message.NoNetworkConnection',
			TextSize = 18,
			TextColor3 = Constants.Color.WHITE,
			TextWrapped = true,
			TextTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 62, 0, 0),
			Size = UDim2.new(1, -85, 1, 0),
		})
	})
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			warningInformation = state.AEAppReducer.AEWarningInformation,
			fullView = state.AEAppReducer.AEFullView,
		}
	end
)(AEWarningWidget)