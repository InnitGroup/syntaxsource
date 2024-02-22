local GuiService = game:GetService("GuiService")
local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local Immutable = require(Modules.Common.Immutable)
local GetImageSetData = require(Modules.LuaApp.GetImageSetData)

local LuaAppUseImageSets = settings():GetFFlag("LuaAppUseImageSets")

local ImageSetLabel = Roact.PureComponent:extend("ImageSetLabel")

function ImageSetLabel:render()
	if not LuaAppUseImageSets then
		if self.props.Image and
		  string.sub(self.props.Image, 1, 3) ~= "rbx" and
		  string.sub(self.props.Image, 1, 4) ~= "http" then
			local newProps = Immutable.RemoveFromDictionary(self.props, "Image")
			newProps.Image = "rbxasset://textures/ui/" .. self.props.Image .. ".png"
			return Roact.createElement("ImageLabel", newProps)
		end
		return Roact.createElement("ImageLabel", self.props)
	end

	local imageSetData, intScale = GetImageSetData(GuiService:GetResolutionScale())
	local imageData = imageSetData[self.props.Image]

	-- If the image URI is not available in a image-set, let engine handle this
	if not imageData then
		return Roact.createElement("ImageLabel", self.props)
	end

	local newProps = Immutable.RemoveFromDictionary(self.props, "Image", "ImageRectOffset", "ImageRectSize", "SliceCenter")

	if self.props.Image then
		newProps.Image = "rbxasset://textures/ui/ImageSet/" .. imageData.ImageSet .. ".png"
	end

	if self.props.ImageRectOffset then
		newProps.ImageRectOffset = Vector2.new(
			imageData.ImageRectOffset.X + self.props.ImageRectOffset.X * intScale,
			imageData.ImageRectOffset.Y + self.props.ImageRectOffset.Y * intScale
		)
	else
		newProps.ImageRectOffset = imageData.ImageRectOffset
	end

	if self.props.ImageRectSize then
		newProps.ImageRectSize = Vector2.new(
			self.props.ImageRectSize.X * intScale,
			self.props.ImageRectSize.Y * intScale
		)
	else
		newProps.ImageRectSize = imageData.ImageRectSize
	end

	if self.props.SliceCenter then
		newProps.SliceCenter = Rect.new(
			self.props.SliceCenter.Min.X * intScale,
			self.props.SliceCenter.Min.Y * intScale,
			self.props.SliceCenter.Max.X * intScale,
			self.props.SliceCenter.Max.Y * intScale
		)
		if self.props.SliceScale then
			newProps.SliceScale =  self.props.SliceScale / intScale
		else
			newProps.SliceScale =  1 / intScale
		end
	end

	return Roact.createElement("ImageLabel", newProps)
end

return ImageSetLabel