local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local Constants = require(Modules.LuaApp.Constants)

local VOTE_BAR_BACKGROUND_COLOR = Constants.Color.GRAY3
local VOTE_BAR_FOREGROUND_COLOR = Constants.Color.GRAY2

local voteBarImage = "LuaApp/voteBar/bar"
local VOTE_BAR_IMAGE_SIZE = Vector2.new(56, 4)

local GameVoteBar = Roact.PureComponent:extend("GameVoteBar")

function GameVoteBar:render()
	local size = self.props.Size
	local position = self.props.Position
	local votePercentage = self.props.votePercentage
	local voteEmptyPercentage = 1 - votePercentage

	return Roact.createElement(ImageSetLabel, {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = voteBarImage,
		ImageColor3 = VOTE_BAR_BACKGROUND_COLOR,
	}, {
		VotePercentage = Roact.createElement(ImageSetLabel, {
			Size = UDim2.new(votePercentage, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = voteBarImage,
			ImageColor3 = VOTE_BAR_FOREGROUND_COLOR,
			ImageRectSize = VOTE_BAR_IMAGE_SIZE,
			ImageRectOffset = Vector2.new(-VOTE_BAR_IMAGE_SIZE.X * voteEmptyPercentage, 0),
		}),
	})
end

return GameVoteBar