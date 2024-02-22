--rbxsig%YL1mzy/MHYBZIy/YPyTW5a+2IGIvi1rHoU0jlxv53VXzZYPw+HeXMzjSBg7YzXUS9p1Ft5aLlmul1YmvXypBGIcMKU/prdq4y9s9W3RG0/77IvYwMjZgKkTMhLyU8qvz70OKNqvdcCklqNC/fPHV35VvgqQk3we3CLShSXmIyMk=%
--rbxassetid%158948138%
-- Creates the generic "ROBLOX" loading screen on startup
-- Written by Ben Tkacheff, 2014

local frame
local forceRemovalTime = 5
local destroyed = false

Game:GetService("ContentProvider"):Preload("rbxasset://textures/roblox-logo.png")

-- get control functions set up immediately
function removeLoadingScreen()
	if frame then frame:Destroy() end
	if script then script:Destroy() end
	destroyed = true
end

function startForceLoadingDoneTimer()
	wait(forceRemovalTime)
	removeLoadingScreen()
end

function gameIsLoaded()
	if Game.ReplicatedFirst:IsDefaultLoadingGuiRemoved() then
		removeLoadingScreen()
	else
		startForceLoadingDoneTimer()
	end
end

function makeDefaultLoadingScreen()
	if not settings():GetFFlag("NewLoadingScreen") then return end
	if destroyed then return end

	frame = Instance.new("Frame")
	frame.ZIndex = 10
	frame.Active = true
	frame.Size = UDim2.new(1,0,1,0)
	frame.BackgroundColor3 = Color3.new(48/255,90/255,206/255)

	local robloxLogo = Instance.new("ImageLabel")
	robloxLogo.BackgroundTransparency = 1
	robloxLogo.ZIndex = 10
	robloxLogo.Image = "rbxasset://textures/roblox-logo.png"
	robloxLogo.Size = UDim2.new(0,1031,0,265)
	robloxLogo.Position = UDim2.new(0.5,-515,0.5,-132)
	robloxLogo.Name = "RobloxLogo"
	robloxLogo.Parent = frame

	local poweredByText = Instance.new("TextLabel")
	poweredByText.Font = Enum.Font.SourceSansBold
	poweredByText.FontSize = Enum.FontSize.Size24
	poweredByText.TextWrap = true
	poweredByText.TextColor3 = Color3.new(1,1,1)
	poweredByText.BackgroundTransparency = 1
	poweredByText.ZIndex = 10
	poweredByText.Text = "This Game Powered By"
	poweredByText.TextXAlignment = Enum.TextXAlignment.Left
	poweredByText.Size = UDim2.new(1,0,0,40)
	poweredByText.Position = UDim2.new(0,0,0,-50)
	poweredByText.Name = "PoweredByText"
	poweredByText.Parent = robloxLogo

	local exitButton = Instance.new("ImageButton")
	exitButton.ZIndex = 10
	exitButton.BackgroundTransparency = 1
	exitButton.Image = "rbxasset://textures/ui/CloseButton.png"
	exitButton.Size = UDim2.new(0,22,0,22)
	exitButton.Position = UDim2.new(1,-23,0,1)
	exitButton.Name = "ExitButton"
	exitButton:SetVerb("Exit")
	
	UserSettings().GameSettings.FullscreenChanged:connect(function ( isFullScreen )
		if isFullScreen then
			exitButton.Parent = frame
		else
			exitButton.Parent = nil
		end
	end)
	if UserSettings().GameSettings:InFullScreen()then
		exitButton.Parent = frame
	end

	-- put something visible up asap
	frame.Parent = Game.CoreGui.RobloxGui

	local instanceText = Instance.new("TextLabel")
	instanceText.Font = Enum.Font.SourceSansBold
	instanceText.FontSize = Enum.FontSize.Size18
	instanceText.TextWrap = true
	instanceText.TextColor3 = Color3.new(1,1,1)
	instanceText.BackgroundTransparency = 1
	instanceText.ZIndex = 10
	instanceText.Text = ""
	instanceText.Size = UDim2.new(1,0,0,40)
	instanceText.Position = UDim2.new(0,0,1,-60)
	instanceText.Name = "InstanceText"
	instanceText.Parent =  frame

	local loadingText = Instance.new("TextLabel")
	loadingText.Font = Enum.Font.SourceSansBold
	loadingText.FontSize = Enum.FontSize.Size36
	loadingText.TextWrap = true
	loadingText.TextColor3 = Color3.new(1,1,1)
	loadingText.BackgroundTransparency = 1
	loadingText.ZIndex = 10
	loadingText.Text = "Loading"
	loadingText.Size = UDim2.new(1,0,0,40)
	loadingText.Position = UDim2.new(0,0,1,20)
	loadingText.Name = "LoadingText"
	loadingText.Parent =  robloxLogo

	local howManyDots = 0
	local lastUpdateTime = tick()
	local minUpdateTime = 0.3
	local aspectRatio = 1031/265

	function ResolutionChanged( prop )
		if prop == "AbsoluteSize" then
			local size = Game.CoreGui.RobloxGui.AbsoluteSize
			if size.X >= 1031 then
				robloxLogo.Size = UDim2.new(0,1031,0,265)
				robloxLogo.Position = UDim2.new(0.5,-515,0.5,-132)
			else
				local sizeReducer = -0.05
				while size.X < robloxLogo.AbsoluteSize.X do

					robloxLogo.Size = UDim2.new(sizeReducer,1031,0,265)
					local newY = robloxLogo.AbsoluteSize.X * 265/1031
					robloxLogo.Size = UDim2.new(sizeReducer,1031,0,newY)
					robloxLogo.Position = UDim2.new(0.5 - (sizeReducer/2),-515,0.5,-132)

					sizeReducer = sizeReducer - 0.1
				end
			end
		end
	end

	ResolutionChanged("AbsoluteSize")
	Game.CoreGui.RobloxGui.Changed:connect(ResolutionChanged)

	Game:GetService("RunService").RenderStepped:connect(function()
		instanceText.Text = Game:GetMessage()

		if tick() - lastUpdateTime >= minUpdateTime then
			howManyDots = howManyDots + 1
			if howManyDots > 5 then
				howManyDots = 0
			end

			loadingText.Text = "Loading"
			for i = 1, howManyDots do
				loadingText.Text = loadingText.Text .. "."
			end
			lastUpdateTime = tick()
		end
	end)
end

makeDefaultLoadingScreen()

Game.ReplicatedFirst.RemoveDefaultLoadingGuiSignal:connect(function()
	removeLoadingScreen()
end)
if Game.ReplicatedFirst:IsDefaultLoadingGuiRemoved() then
	removeLoadingScreen()
	return
end

Game.Loaded:connect(function()
	gameIsLoaded()
end)

if Game:IsLoaded() then
	gameIsLoaded()
end