local CorePackages = game:GetService("CorePackages")
local TextService = game:GetService("TextService")
local Roact = require(CorePackages.Roact)

local Constants = require(script.Parent.Parent.Parent.Constants)
local FONT_SIZE = Constants.DefaultFontSize.MainWindow
local FONT = Constants.Font.Log
local ICON_PADDING = Constants.LogFormatting.IconHeight
local FRAME_HEIGHT = Constants.LogFormatting.TextFrameHeight
local LINE_PADDING = Constants.LogFormatting.TextFramePadding
local MAX_STRING_SIZE = Constants.LogFormatting.MaxStringSize
local MAX_STR_MSG = " -- Could not display entire %d character message because message exceeds max displayable length of %d"

local LogOutput = Roact.Component:extend("LogOutput")

function LogOutput:init(props)
	local initLogOutput = props.initLogOutput and props.initLogOutput()

	self.onCanvasChange = function()
		local canvasPos = self.ref.current.CanvasPosition
		local absSize = self.ref.current.AbsoluteSize
		if self.state.canvasPos ~= canvasPos or 
			self.state.absSize ~= absSize then
			self:setState({
				canvasPos = canvasPos,
				absSize = absSize,
			})
		end
	end

	self.ref = Roact.createRef()

	self.state = {
		logData = initLogOutput,
		absSize = Vector2.new(),
		canvasPos = UDim2.new(),
		wordWrap = true,
	}
end

function LogOutput:willUpdate(nextProps, nextState)
	self._canvasSignal:Disconnect()
	self._absSizeSignal:Disconnect()
end

function LogOutput:didUpdate()
	self._canvasSignal = self.ref.current:GetPropertyChangedSignal("CanvasPosition"):Connect(self.onCanvasChange)
	self._absSizeSignal = self.ref.current:GetPropertyChangedSignal("AbsoluteSize"):Connect(self.onCanvasChange)
end

function LogOutput:didMount()
	self.logConnector = self.props.targetSignal:Connect(function(data)
		self:setState({
			logData = data
		})
	end)

	self._canvasSignal = self.ref.current:GetPropertyChangedSignal("CanvasPosition"):Connect(self.onCanvasChange)
	self._absSizeSignal = self.ref.current:GetPropertyChangedSignal("AbsoluteSize"):Connect(self.onCanvasChange)

	--[[
		in some cases, the absolute size is not valid at this point. But in the 
		case that it is, we want to update the absolute size here since the 
		absolute size was changed prior to the absSizeSignal being set up
	--]]
	local absSize = self.ref.current.AbsoluteSize
	if absSize.Magnitude > 0 then
		self:setState({
			absSize = self.ref.current.AbsoluteSize,
		})
	end
end

function LogOutput:willUnmount()
	self.logConnector:Disconnect()
	self.logConnector = nil
end

function LogOutput:render()
	local layoutOrder = self.props.layoutOrder
	local size = self.props.size

	local logData = self.state.logData
	local absSize = self.state.absSize
	local canvasPos = self.state.canvasPos
	local wordWrap = self.state.wordWrap

	if self.ref.current then
		canvasPos = self.ref.current.CanvasPosition
	end

	local elements = {}

	local messageCount = 1
	local scrollingFrameHeight = 0

	if self.ref.current and logData then
		-- FRAME_HEIGHT is used to offset the text for the icon
		local frameWidth = absSize.X - FRAME_HEIGHT
		local paddingHeight = -1
		local usedFrameSpace = 0

		local msgIter = logData:iterator()
		local message = msgIter:next()
		while message do
			local fmtMessage = message.Message
			local charCount = message.CharCount

			local msgDimsY = message.Dims.Y
			if wordWrap then
				msgDimsY = message.Dims.Y * math.ceil(message.Dims.X / frameWidth)
			end

			messageCount = messageCount + 1

			if scrollingFrameHeight + msgDimsY >= canvasPos.Y then
				if usedFrameSpace < absSize.Y then
					local color = Constants.Color.Text
					local image = ""

					if message.Type == Enum.MessageType.MessageOutput.Value then
						color = Constants.Color.Text
					elseif message.Type == Enum.MessageType.MessageInfo.Value then
						color = Constants.Color.HighlightBlue
						image = Constants.Image.Info
					elseif message.Type == Enum.MessageType.MessageWarning.Value then
						color = Constants.Color.WarningYellow
						image = Constants.Image.Warning
					elseif message.Type == Enum.MessageType.MessageError.Value then
						color = Constants.Color.ErrorRed
						image = Constants.Image.Errors
					end

					elements[messageCount] = Roact.createElement("Frame", {
						Size = UDim2.new(1, 0, 0, msgDimsY),
						BackgroundTransparency = 1,
						LayoutOrder = messageCount,
					}, {
						image = Roact.createElement("ImageLabel", {
							Image = image,
							Size = UDim2.new(0, ICON_PADDING , 0, ICON_PADDING),
							Position = UDim2.new(0, ICON_PADDING / 4, .5, -ICON_PADDING / 2),
							BackgroundTransparency = 1,
						}),
						msg = Roact.createElement("TextLabel", {
							Text = fmtMessage,
							TextColor3 = color,
							TextSize = FONT_SIZE,
							Font = FONT,
							TextXAlignment = Enum.TextXAlignment.Left,

							TextWrapped = wordWrap,

							Size = UDim2.new(1, 0, 0, msgDimsY),
							Position = UDim2.new(0, FRAME_HEIGHT, 0, 0),
							BackgroundTransparency = 1,
						})
					})
				end

				if paddingHeight < 0 then
					paddingHeight = scrollingFrameHeight
				else
					usedFrameSpace = usedFrameSpace + msgDimsY + LINE_PADDING
				end
			end

			scrollingFrameHeight = scrollingFrameHeight + msgDimsY + LINE_PADDING

			if charCount < MAX_STRING_SIZE then
				message = msgIter:next()
			else
				local maxStrMsg = string.format(MAX_STR_MSG, charCount, MAX_STRING_SIZE)
				message = {
					Message = maxStrMsg,
					CharCount = #maxStrMsg,
					Type = message.Type,
					Dims = TextService:GetTextSize(maxStrMsg, FONT_SIZE, FONT, Vector2.new())
				}
			end
		end
		elements["UIListLayout"] = Roact.createElement("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, LINE_PADDING),
		})

		elements["WindowingPadding"] = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, paddingHeight),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		Size = size,
		BackgroundTransparency = 1,
		VerticalScrollBarInset = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(1, 0, 0, scrollingFrameHeight),
		LayoutOrder = layoutOrder,

		[Roact.Ref] = self.ref,
	}, elements)
end

return LogOutput