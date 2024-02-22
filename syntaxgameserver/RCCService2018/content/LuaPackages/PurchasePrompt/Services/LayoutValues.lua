local strict = require(script.Parent.Parent.strict)

local function makeImageData(path, sliceCenter)
	return {
		Path = "rbxasset://textures/" .. path,
		SliceCenter = sliceCenter,
	}
end

local LayoutValues = {}
LayoutValues.__tostring = function()
	return "Service(LayoutValues)"
end

function LayoutValues.generate(isTenFoot)
	local scaleFactor = isTenFoot and 3 or 1

	local ButtonHeight = 44 * scaleFactor
	local PostTextHeight = 30 * scaleFactor

	local RobuxIconPadding = 6 * scaleFactor
	local RobuxIconWidth = 20 * scaleFactor
	local RobuxIconHeight = 20 * scaleFactor

	local ProductDescriptionPaddingTop = 18 * scaleFactor
	local ProductDescriptionWidth = 210 * scaleFactor
	local ProductDescriptionHeight = 106 * scaleFactor

	local PurchasingAnimationWidth = 96 * scaleFactor
	local PurchasingAnimationHeight = 20 * scaleFactor

	local HorizontalPadding = 25 * scaleFactor
	local ItemPreviewBorder = 2 * scaleFactor
	local ItemPreviewWidth = 64 * scaleFactor
	local ItemPreviewHeight = 64 * scaleFactor

	local ButtonIconPadding = 3 * scaleFactor
	-- Button icons have drop shadow and need a slight offset in order to look centered
	local ButtonIconYOffset = 2 * scaleFactor

	local ItemPreviewBackgroundWidth = ItemPreviewWidth + 2 * ItemPreviewBorder
	local ItemPreviewBackgroundHeight = ItemPreviewHeight + 2 * ItemPreviewBorder

	local ItemPreviewContainerWidth = ItemPreviewBackgroundWidth + 2 * HorizontalPadding
	local ItemPreviewContainerHeight = ItemPreviewBackgroundHeight + 2 * HorizontalPadding

	--[[
		Sizes for UI elements
	]]
	local Size = {
		AdditonalDetailsLabel = UDim2.new(1, 0, 0, PostTextHeight),

		ItemPreview = UDim2.new(0, ItemPreviewWidth, 0, ItemPreviewHeight),
		ItemPreviewWhiteFrame = UDim2.new(0, ItemPreviewBackgroundWidth, 0, ItemPreviewBackgroundHeight),
		ItemPreviewContainerFrame = UDim2.new(0, ItemPreviewContainerWidth, 0, ItemPreviewContainerHeight),

		HorizontalPadding = HorizontalPadding,
		ProductDescription = UDim2.new(0, ProductDescriptionWidth, 0, ProductDescriptionHeight),
		ProductDescriptionPaddingTop = ProductDescriptionPaddingTop,

		RobuxIconContainerFrame = UDim2.new(0, RobuxIconWidth + RobuxIconPadding, 0, RobuxIconHeight + 2 * RobuxIconPadding),
		RobuxIcon = UDim2.new(0, RobuxIconWidth, 0, RobuxIconHeight),
		PriceTextLabel = UDim2.new(1, 0, 0, RobuxIconHeight),

		PurchasingAnimation = UDim2.new(0, PurchasingAnimationWidth, 0, PurchasingAnimationHeight),

		ButtonIconPadding = ButtonIconPadding,
		ButtonIconYOffset = ButtonIconYOffset,
		ButtonHeight = ButtonHeight,
		Dialog = UDim2.new(
			0, ItemPreviewContainerWidth + ProductDescriptionWidth,
			0, math.max(ItemPreviewContainerHeight, ProductDescriptionHeight) + PostTextHeight + ButtonHeight )
	}

	--[[
		Font sizes for UI elements
	]]
	local TextSize = {
		Default = 18 * scaleFactor,
		ProductDescription = 18 * scaleFactor,
		Button = 24 * scaleFactor,
		AdditonalDetails = 14 * scaleFactor,
		Purchasing = 36 * scaleFactor,
	}

	--[[
		Background images, including slice center
	]]
	local Image = {}
	Image.PromptBackground = isTenFoot
		and makeImageData("ui/PurchasePrompt/PurchasePromptBG@2x.png", Rect.new(17, 17, 19, 19))
		or makeImageData("ui/PurchasePrompt/PurchasePromptBG.png", Rect.new(8, 9, 10, 10))
	Image.InProgressBackground = isTenFoot
		and makeImageData("ui/PurchasePrompt/LoadingBG@2x.png", Rect.new(17, 17, 19, 19))
		or makeImageData("ui/PurchasePrompt/LoadingBG.png", Rect.new(9, 9, 11, 11))

	Image.ButtonUpLeft = isTenFoot
		and makeImageData("ui/PurchasePrompt/LeftButton@2x.png", Rect.new(18, 5, 20, 7))
		or makeImageData("ui/PurchasePrompt/LeftButton.png", Rect.new(8, 3, 10, 4))
	Image.ButtonDownLeft = isTenFoot
		and makeImageData("ui/PurchasePrompt/LeftButtonDown@2x.png", Rect.new(18, 5, 20, 7))
		or makeImageData("ui/PurchasePrompt/LeftButtonDown.png", Rect.new(8, 3, 10, 4))
	Image.ButtonUpRight = isTenFoot
		and makeImageData("ui/PurchasePrompt/RightButton@2x.png", Rect.new(3, 5, 5, 7))
		or 	makeImageData("ui/PurchasePrompt/RightButton.png", Rect.new(2, 3, 3, 4))
	Image.ButtonDownRight = isTenFoot
		and makeImageData("ui/PurchasePrompt/RightButtonDown@2x.png", Rect.new(3, 5, 5, 7))
		or makeImageData("ui/PurchasePrompt/RightButtonDown.png", Rect.new(2, 3, 3, 4))
	Image.ButtonUp = isTenFoot
		and makeImageData("ui/PurchasePrompt/SingleButton@2x.png", Rect.new(18, 5, 20, 7))
		or makeImageData("ui/PurchasePrompt/SingleButton.png", Rect.new(8, 3, 10, 4))
	Image.ButtonDown = isTenFoot
		and makeImageData("ui/PurchasePrompt/SingleButtonDown@2x.png", Rect.new(18, 5, 20, 7))
		or makeImageData("ui/PurchasePrompt/SingleButtonDown.png", Rect.new(8, 3, 10, 4))

	--[[
		CLILUACORE-315: Make 2x versions for robux icon and error icon
	]]
	Image.RobuxIcon = isTenFoot
		and makeImageData("ui/RobuxIcon.png")
		or makeImageData("ui/RobuxIcon.png")
	Image.ErrorIcon = isTenFoot
		and makeImageData("ui/ErrorIcon.png")
		or makeImageData("ui/ErrorIcon.png")

	Image.ButtonA = isTenFoot
		and makeImageData("ui/Settings/Help/AButtonDark@2x.png")
		or makeImageData("ui/Settings/Help/AButtonDark.png")
	Image.ButtonB = isTenFoot
		and makeImageData("ui/Settings/Help/BButtonDark@2x.png")
		or makeImageData("ui/Settings/Help/BButtonDark.png")

	local LayoutValues = strict({
		Size = strict(Size, "LayoutValues.Size"),
		TextSize = strict(TextSize, "LayoutValues.TextSize"),
		Image = strict(Image, "LayoutValues.Image"),
	}, "LayoutValues")

	return LayoutValues
end

return LayoutValues