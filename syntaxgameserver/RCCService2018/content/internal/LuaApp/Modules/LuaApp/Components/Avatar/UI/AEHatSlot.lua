local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Modules = CoreGui.RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEToggleAssetOptionsMenu = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetOptionsMenu)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local AEHatSlot = Roact.PureComponent:extend("AEHatSlot")

local NUMBER_OF_ALLOWED_HATS = 3

local View = {
	[DeviceOrientationMode.Portrait] = {
		SIZE = 48,
	},

	[DeviceOrientationMode.Landscape] = {
		SIZE = 60,
	}
}

function AEHatSlot:init()
	self.hatSlotRef = Roact.createRef()

	self.toggleEquip = function(rbx)
		local index = self.props.index
		local equippedHats = self.props.equippedHats
		local assetId = equippedHats[index]
		local isOutfit = false
		self.props.toggleEquip(assetId, isOutfit)
	end
end

function AEHatSlot:didMount()
	local ref = self.hatSlotRef.current
	local index = self.props.index
	local basePosition = UDim2.new(0, 0, (index - 1) * 0.35, 0)

	local tweenInfoDown = TweenInfo.new(
		0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
	local tweenInfoUp = TweenInfo.new(
		0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)

	self.tweenDown = TweenService:Create(ref, tweenInfoDown, {
		Position = basePosition + UDim2.new(0, 0, 0, 15)
		})
	self.tweenUp = TweenService:Create(ref, tweenInfoUp, {
		Position = basePosition
		})

	local tweenInfoLeft = TweenInfo.new(
		0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
	local tweenInfoRight = TweenInfo.new(
		0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local tweenInfoMiddle = tweenInfoLeft

	self.tweenLeft = TweenService:Create(ref, tweenInfoLeft, {
			Position = basePosition + UDim2.new(0, -15, 0, 0)
			})
	self.tweenRight = TweenService:Create(ref, tweenInfoRight, {
		Position = basePosition + UDim2.new(0, 15, 0, 0)
		})
	self.tweenMiddle = TweenService:Create(ref, tweenInfoMiddle, {
		Position = basePosition
		})
end

function AEHatSlot:updateSlotAnimation(assetId, nextAssetId)
	local index = self.props.index
	if assetId ~= nextAssetId then
		if nextAssetId then
			local numberOfHatsScale = (index - 1) / (NUMBER_OF_ALLOWED_HATS - 1)
			delay(numberOfHatsScale * 0.25, function()
				self.tweenDown:Play()
				self.tweenDown.Completed:Connect(
					function()
						self.tweenUp:Play()
					end)
			end)
		elseif assetId then
			self.tweenLeft:Play()
			self.tweenLeft.Completed:Connect(
				function()
					self.tweenRight:Play()
				end)
			self.tweenRight.Completed:Connect(
				function()
					self.tweenMiddle:Play()
				end)
		end
	end
end

function AEHatSlot:willUpdate(nextProps, nextState)
	local index = self.props.index
	local currHats = self.props.equippedHats
	local assetId = currHats and currHats[index] or nil

	local nextHats = nextProps.equippedHats
	local nextAssetId = nextHats and nextHats[index] or nil

	self:updateSlotAnimation(assetId, nextAssetId)
end

function AEHatSlot:render()
	local index = self.props.index
	local deviceOrientation = self.props.deviceOrientation
	local equippedHats = self.props.equippedHats
	local assetId = equippedHats and equippedHats[index] or nil
	local cardImage = assetId and AEUtils.getThumbnail(false, assetId)
	local activateFunction = function(rbx) end
	local longPressFunction = function(rbx, touchPoints, inputState) end
	local openAssetMenu = self.props.openAssetMenu
	local fadedHatIcon = AESpriteSheet.getImage("ic-hat")
	local fadeVisible = true

	if assetId then
		activateFunction = self.toggleEquip
		longPressFunction = function(rbx, touchPoints, inputState)
			openAssetMenu(assetId)
		end
		fadeVisible = false
	end

	return Roact.createElement("ImageButton", {
		AutoButtonColor = false,
		Position = UDim2.new(0, 0, (index - 1) * 0.35, 0),
		Size = UDim2.new(0, View[deviceOrientation].SIZE, 0, View[deviceOrientation].SIZE),
		Image = cardImage,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderColor3 = Color3.fromRGB(204, 204, 204),

		[Roact.Ref] = self.hatSlotRef,

		[Roact.Event.Activated] = activateFunction,

		[Roact.Event.TouchLongPress] = longPressFunction,
		}, {
		fadeIcon = Roact.createElement("ImageLabel", {
				Visible = fadeVisible,
				Position = UDim2.new(.25, 0, .25, 0),
				Size = UDim2.new(0, View[deviceOrientation].SIZE / 2, 0, View[deviceOrientation].SIZE / 2),
				BackgroundTransparency = 1,
				Image = fadedHatIcon.image,
				ImageRectOffset = fadedHatIcon.imageRectOffset,
				ImageRectSize = fadedHatIcon.imageRectSize,
				ImageTransparency = .8,
			})
		})
end

AEHatSlot = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			equippedHats = state.AEAppReducer.AECharacter.AEEquippedAssets and
				state.AEAppReducer.AECharacter.AEEquippedAssets[AEConstants.AssetTypes.Hat] or nil,
		}
	end,

	function(dispatch)
		return {
			openAssetMenu = function(assetId)
				dispatch(AEToggleAssetOptionsMenu(true, assetId))
			end,
		}
	end
)(AEHatSlot)

return AEHatSlot
