--[[
	// FileName: PlayerCarousel.lua
	// Written by: darthskrill
	// Description: Module for building the UI for the player selection carousel
]]

local PlayerCarousel = {}
PlayerCarousel.__index = PlayerCarousel

-- SERVICES
local GuiService = game:GetService("GuiService")
local CoreGuiService = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- CONSTANTS
local BACKGROUND_SELECTED_COLOR = Color3.fromRGB(0,162,255)
local BACKGROUND_DEFAULT_COLOR = Color3.fromRGB(0,0,0)
local PAGE_LAYOUT_TWEEN_TIME = 0.25

local CAROUSEL_DIVIDER_NAME = "_CarouselDivider"

-- VARIABLES
local RobloxGui = CoreGuiService:WaitForChild("RobloxGui")
local CoreGuiModules = RobloxGui:WaitForChild("Modules")
local AvatarMenuModules = CoreGuiModules:WaitForChild("AvatarContextMenu")
local selectedPlayer = nil
local uiPageLayout = nil
local playerChangedEvent = nil
local buttonToPlayerMap = {}
local playerToButtonMap = {}

local function getSortedCarouselButtons()
	local buttonChildIndexs = {}
	local carouselButtons = {}
	for childIndex, child in ipairs(selectedPlayer:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= CAROUSEL_DIVIDER_NAME then
			table.insert(carouselButtons, child)
			buttonChildIndexs[child] = childIndex
		end
	end
	table.sort(carouselButtons, function(a, b)
		if a.LayoutOrder == b.LayoutOrder then
			return buttonChildIndexs[a] < buttonChildIndexs[b]
		end
		return a.LayoutOrder < b.LayoutOrder
	end)
	return carouselButtons
end

local function CreateMenuCarousel(theme)
	local playerSelection = Instance.new("Frame")
	playerSelection.Name = "PlayerCarousel"
	playerSelection.AnchorPoint = Vector2.new(0.5, 0.5)
	playerSelection.BackgroundTransparency = 1
	playerSelection.Position = UDim2.new(0.5,0,0.5,0)
	playerSelection.Size = UDim2.new(1, 0, 0.28, 0)
	playerSelection.ClipsDescendants = true

		local innerFrame = Instance.new("Frame")
		innerFrame.Name = "InnerFrame"
		innerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		innerFrame.BackgroundTransparency = 1
		innerFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		innerFrame.Size = UDim2.new(0.8, 0, 1, 0)
		innerFrame.ClipsDescendants = true
		innerFrame.Active = true
		innerFrame.Parent = playerSelection

			selectedPlayer = Instance.new("Frame")
			selectedPlayer.Name = "SelectedPlayer"
			selectedPlayer.AnchorPoint = Vector2.new(0.5, 0.5)
			selectedPlayer.BackgroundTransparency = 1
			selectedPlayer.Position = UDim2.new(0.5, 0, 0.5, 0)
			selectedPlayer.Size = UDim2.new(0, 100, 1, -10)
			selectedPlayer.Parent = innerFrame

				uiPageLayout = Instance.new("UIPageLayout")
				uiPageLayout.EasingDirection = Enum.EasingDirection.Out
				uiPageLayout.EasingStyle = Enum.EasingStyle.Quad
				uiPageLayout.Padding = UDim.new(0, 5)
				uiPageLayout.TweenTime = PAGE_LAYOUT_TWEEN_TIME
				uiPageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				uiPageLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				uiPageLayout.TouchInputEnabled = false
				uiPageLayout.Circular = true
				uiPageLayout.SortOrder = Enum.SortOrder.LayoutOrder

				local aspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
				aspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
				aspectRatioConstraint.Parent = selectedPlayer

				playerChangedEvent = Instance.new("BindableEvent")
				playerChangedEvent.Name = "PlayerChanged"

				local lastPage = nil
				uiPageLayout:GetPropertyChangedSignal("CurrentPage"):Connect(function()
					if uiPageLayout.CurrentPage then
						if uiPageLayout.CurrentPage.Name == CAROUSEL_DIVIDER_NAME then
							local carouselButtons = getSortedCarouselButtons()
							if lastPage == carouselButtons[1] then
								uiPageLayout:Previous()
							else
								uiPageLayout:Next()
							end
						else
							uiPageLayout.CurrentPage.BackgroundColor3 = BACKGROUND_DEFAULT_COLOR
							lastPage = uiPageLayout.CurrentPage
						end
					end
					if GuiService.SelectedCoreObject and GuiService.SelectedCoreObject.Parent == uiPageLayout.Parent then
						GuiService.SelectedCoreObject.BackgroundColor3 = BACKGROUND_SELECTED_COLOR
					end
					GuiService.SelectedCoreObject = uiPageLayout.CurrentPage
					if uiPageLayout.CurrentPage then playerChangedEvent:Fire(buttonToPlayerMap[uiPageLayout.CurrentPage]) end
				end)
				uiPageLayout.Parent = selectedPlayer

		local nextButton = Instance.new("ImageButton")
		nextButton.Name = "NextButton"
		nextButton.Image = theme.ScrollRightImage
		nextButton.BackgroundTransparency = 1
		nextButton.AnchorPoint = Vector2.new(1,0.5)
		nextButton.Position = UDim2.new(1,-5,0.5,0)
		nextButton.Size = UDim2.new(0.3,0,0.3,0)
		nextButton.Selectable = false
		nextButton.Parent = playerSelection

			local nextButtonAspectRatio = Instance.new("UIAspectRatioConstraint")
			nextButtonAspectRatio.DominantAxis = Enum.DominantAxis.Width
			nextButtonAspectRatio.Parent = nextButton

		local prevButton = nextButton:Clone()
		prevButton.Name = "PrevButton"
		if theme.ScrollLeftImage ~= "" then
			prevButton.Image = theme.ScrollLeftImage
		else
			prevButton.Rotation = 180
		end
		prevButton.AnchorPoint = Vector2.new(0, 0.5)
		prevButton.Position = UDim2.new(0, 5, 0.5, 0)
		prevButton.Selectable = false
		prevButton.Parent = playerSelection

		local function moveChangePage(goToNext)
			if goToNext then
				uiPageLayout:Next()
			else
				uiPageLayout:Previous()
			end
		end

		nextButton.MouseButton1Click:Connect(function() moveChangePage(true) end)
		prevButton.MouseButton1Click:Connect(function() moveChangePage(false) end)

		local defaultChildrenSize = 3 -- aspectRatioConstraint, PageLayout, first button in pagelayout

		local function checkButtonVisibility()
			local lastInputIsTouch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
			prevButton.Visible = not lastInputIsTouch and (#selectedPlayer:GetChildren() > defaultChildrenSize)
			nextButton.Visible = not lastInputIsTouch and (#selectedPlayer:GetChildren() > defaultChildrenSize)
		end
		checkButtonVisibility()
		UserInputService.LastInputTypeChanged:Connect(checkButtonVisibility)

	return playerSelection
end

function PlayerCarousel:UpdateGuiTheme(theme)
	self.rbxGui.NextButton.Image = theme.ScrollRightImage

	if theme.ScrollLeftImage ~= "" then
		self.rbxGui.PrevButton.Image = theme.ScrollLeftImage
	else
		self.rbxGui.PrevButton.Image = theme.ScrollRightImage
		self.rbxGui.PrevButton.Rotation = 180
	end
end

function PlayerCarousel:FadeTowardsEdges()
	if not uiPageLayout.CurrentPage then
		return
	end

	local carouselButtons = getSortedCarouselButtons()
	local currentPageIndex = 0
	for index, button in ipairs(carouselButtons) do
		if button == uiPageLayout.CurrentPage then
			currentPageIndex = index
			break
		end
	end

	for index, button in ipairs(carouselButtons) do
		local distanceToLeft = (currentPageIndex - index) % #carouselButtons
		local distanceToRight = (index - currentPageIndex) % #carouselButtons
		local distance = math.min(distanceToLeft, distanceToRight)
		if distance >= 2 then
			button.ImageTransparency = 0.7
		elseif distance == 1 then
			button.ImageTransparency = 0.4
		else
			button.ImageTransparency = 0
		end
	end
end

function PlayerCarousel:AddCarouselDivider()
	local carouselDivider = selectedPlayer:FindFirstChild(CAROUSEL_DIVIDER_NAME)
	if carouselDivider then
		carouselDivider:Destroy()
	end

	local buttonCount = #selectedPlayer:GetChildren() - 1
	if buttonCount < 5 then
		return
	end

	carouselDivider = Instance.new("Frame")
	carouselDivider.Name = CAROUSEL_DIVIDER_NAME
	carouselDivider.Size = UDim2.new(1, 0, 1, 0)
	carouselDivider.BackgroundTransparency = 1
	carouselDivider.Parent = selectedPlayer
	carouselDivider.LayoutOrder = 1000000

	local line = Instance.new("Frame")
	line.Name = "line"
	line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	line.BorderSizePixel = 0
	line.Position = UDim2.new(0.25, 0, 0, -3)
	line.Size = UDim2.new(0, 2, 1, 6)
	line.Parent = carouselDivider

	local line2 = line:Clone()
	line2.Position = UDim2.new(0.5, 0, 0, -3)
	line2.Parent = carouselDivider

	local line3 = line:Clone()
	line3.Position = UDim2.new(0.75, 0, 0, -3)
	line3.Parent = carouselDivider
end

function PlayerCarousel:RemovePlayerEntry(player)
	local button = playerToButtonMap[player]

	if button then
		playerToButtonMap[player] = nil
		buttonToPlayerMap[button] = nil

		button:Destroy()
		if uiPageLayout then
			uiPageLayout:ApplyLayout()
		end
		self:FadeTowardsEdges()
	end
end

function PlayerCarousel:ClearPlayerEntries()
	for button in pairs(buttonToPlayerMap) do
		button:Destroy()
	end

	buttonToPlayerMap = {}
	playerToButtonMap = {}
end

function PlayerCarousel:CreatePlayerEntry(player, distanceToLocalPlayer)
	local playerButton = playerToButtonMap[player]
	if playerButton then
		playerButton.LayoutOrder = distanceToLocalPlayer
		return
	end

	local button = Instance.new("ImageButton")
	button.Name = player.Name
	button.BorderSizePixel = 0
	button.LayoutOrder = distanceToLocalPlayer
	button.BackgroundColor3 = Color3.fromRGB(0,0,0)
	button.BackgroundTransparency = 0
	button.Size = UDim2.new(1, 0, 1, 0)

	button.SelectionLost:connect(function() button.BackgroundColor3 = BACKGROUND_DEFAULT_COLOR end)
	button.SelectionGained:connect(function() button.BackgroundColor3 = BACKGROUND_SELECTED_COLOR end)

	local tweenStyle = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true)
	local buttonLoadingTween
	buttonLoadingTween = TweenService:Create(
		button,
		tweenStyle,
		{BackgroundColor3 = Color3.fromRGB(255,255,255)}
	)
	buttonLoadingTween:Play()

	buttonToPlayerMap[button] = player
	playerToButtonMap[player] = button

	button.MouseButton1Click:Connect(function()
		uiPageLayout:JumpTo(button)
	end)

	button.Parent = selectedPlayer

	spawn(function()
		local ContextMenuUtil = require(AvatarMenuModules:WaitForChild("ContextMenuUtil"))
		button.Image = ContextMenuUtil:GetHeadshotForPlayer(player)
		buttonLoadingTween:Cancel()
		buttonLoadingTween = nil
		if button == GuiService.SelectedCoreObject then
			button.BackgroundColor3 = BACKGROUND_SELECTED_COLOR
		else
			button.BackgroundColor3 = BACKGROUND_DEFAULT_COLOR
		end
	end)
end

function PlayerCarousel:SwitchToPlayerEntry(player, dontTween)
	if not player then return end

	local button = playerToButtonMap[player]
	if not button then
		self:CreatePlayerEntry(player, 0)
		button = playerToButtonMap[player]
	end

	if dontTween then
		uiPageLayout.TweenTime = 0
	end
	uiPageLayout:JumpTo(button)
	spawn(function()
		uiPageLayout.TweenTime = PAGE_LAYOUT_TWEEN_TIME
	end)
end

function PlayerCarousel:OffsetPlayerEntry(offset)
	if offset == 0 then return end

	if offset > 0 then
		uiPageLayout:Next()
	else
		uiPageLayout:Previous()
	end
end

function PlayerCarousel:GetSelectedPlayer()
	return buttonToPlayerMap[uiPageLayout.CurrentPage]
end

function PlayerCarousel.new(theme)
	local obj = setmetatable({}, PlayerCarousel)

	obj.rbxGui = CreateMenuCarousel(theme)
	obj.PlayerChanged = playerChangedEvent.Event

	playerChangedEvent.Event:Connect(function()
		obj:FadeTowardsEdges()
	end)

	return obj
end

return PlayerCarousel
