--[[
				// GamesPaneDetailsView.lua

				// Creates a details view for the currently selected game in the IGG
]]
local TextService = game:GetService("TextService")
local RobloxGui = game:GetService("CoreGui").RobloxGui
local Modules = RobloxGui.Modules

local GameData = require(Modules.Shell.GameData)
local GlobalSettings = require(Modules.Shell.GlobalSettings)
local ThumbnailLoader = require(Modules.Shell.ThumbnailLoader)
local Utility = require(Modules.Shell.Utility)

local VoteFrame = require(Modules.Shell.VoteFrame)

local Strings = require(Modules.Shell.LocalizedStrings)

-- local Object, will handle the rotating of thumbnails.
local function createThumbnailView(thumbIds, parentContainer, faded)
	local this = {}

	local PREVIEW_TIME = 4

	local currentImageColor = faded and Color3.new(0.4, 0.4, 0.4) or Color3.new(1, 1, 1)

	local container = Utility.Create'Frame'
	{
		Name = "ThumbViewContainer";
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = parentContainer;
	}

	local function createImage()
		return Utility.Create'ImageLabel'
		{
			Name = "ThumbImage";
			Size = UDim2.new(1, 0, 1, 0);
			BackgroundTransparency = 1;
			ImageTransparency = 1;
			ImageColor3 = currentImageColor;
			Parent = container;
		}
	end

	local killView = false
	function this:KillView()
		killView = true
		container.Parent = nil
	end

	local thumbs = {}
	if thumbIds and #thumbIds > 0 then
		-- get first thumb loaded right away
		local firstImage = createImage()
		table.insert(thumbs, firstImage)
		local loader = ThumbnailLoader:Create(firstImage, thumbIds[1],
			ThumbnailLoader.Sizes.Large, ThumbnailLoader.AssetType.Icon, false)

		spawn(function()
			loader:LoadAsync(true, true)

			-- start loading the rest
			if #thumbIds > 1 then
				for i = 2, #thumbIds do
					local img = createImage()
					table.insert(thumbs, img)
					local ldr = ThumbnailLoader:Create(img, thumbIds[i],
						ThumbnailLoader.Sizes.Large, ThumbnailLoader.AssetType.Icon, false)
					spawn(function()
						ldr:LoadAsync(true, false)
					end)
				end

				local currentThunbIndex = 1
				while not killView do
					wait(PREVIEW_TIME)
					if killView then
						break
					end

					-- cross fade
					Utility.PropertyTweener(thumbs[currentThunbIndex], 'ImageTransparency', 0, 1, 1, Utility.EaseOutQuad, true)

					currentThunbIndex = currentThunbIndex + 1
					if currentThunbIndex > #thumbIds then
						currentThunbIndex = 1
					end

					Utility.PropertyTweener(thumbs[currentThunbIndex], 'ImageTransparency', 1, 0, 1, Utility.EaseOutQuad, true)
				end
			end
		end)
	end

	function this:SetImageColor(color)
		if not color then return end

		currentImageColor = color
		for i = 1, #thumbs do
			thumbs[i].ImageColor3 = currentImageColor
		end
	end

	return this
end

local function createGamesPaneDetailsView()
	local this = {}

	local inFocus = false
	this.PlaceId = nil
	local GamesPaneDetailsConns = {}

	local DETAILS_START_POS = UDim2.new(0, 0, 0, 196)
	local DETAILS_FINAL_POS = UDim2.new(0, 0, 0, 116)

	-- GUI Objects
	local viewContainer = Utility.Create"Frame"
	{
		Name = "ViewContainer";
		Size = UDim2.new(0, 1690, 0, 380);
		Position = UDim2.new(0, 0, 0, -84);
		BackgroundTransparency = 1;
	}

	local detailsContainer = Utility.Create"Frame"
	{
		Name = "DetailsContainer";
		Size = UDim2.new(0, 900, 0, 216);
		Position = DETAILS_START_POS;
		BackgroundTransparency = 1;
		Parent = viewContainer;
	}

	local gameTitle = Utility.Create"TextLabel"
	{
		Name = "GameTitle";
		Size = UDim2.new(0, 0, 0, 0);
		Position = UDim2.new(0, 0, 0, 18);
		BackgroundTransparency = 1;
		Font = GlobalSettings.RegularFont;
		FontSize = GlobalSettings.HeaderSize;
		Text = "";
		TextColor3 = GlobalSettings.WhiteTextColor;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = detailsContainer;
	}

	local gameImageContainer = Utility.Create"Frame"
	{
		Name = "GameImageContainer";
		Size = UDim2.new(0, 700, 0, 380);
		Position = UDim2.new(1, -700, 0, 6);
		BackgroundTransparency = 1;
		Parent = viewContainer;
	}

	local gameInfoContainer = Utility.Create"Frame"
	{
		Name = "GameInfoContainer",
		Size = UDim2.new(1, 0, 0, 39),
		Position = UDim2.new(0, 0, 0, 83),
		BackgroundTransparency = 1,
		Parent = detailsContainer,
	}

	local sponsoredContainer = Utility.Create"Frame"
	{
		Name = "SponsoredContainer",
		Size = UDim2.new(0, 287, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gameInfoContainer,
	}

	local sponsoredLabelFrame = Utility.Create"ImageLabel"
	{
		Name = "sponsoredLabelFrame",
		Image = "rbxasset://textures/ui/Shell/Icons/WhiteSquare.png",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(4, 4, 36, 36),
		Parent = sponsoredContainer,
	}

	local sponsoredLabelText = Utility.Create"TextLabel"
	{
		Name = "SponsoredLabelText",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = GlobalSettings.RegularFont,
		TextSize = 30,
		TextColor3 = GlobalSettings.WhiteTextColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = Strings:LocalizedString("SponsoredGameWord"),
		Parent = sponsoredContainer,
	}

	local ratingContainer = Utility.Create"Frame"
	{
		Name = "RatingContainer",
		Size = UDim2.new(0, 287, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gameInfoContainer,
	}

	local separatorOffset = ratingContainer.Position.X.Offset + ratingContainer.Size.X.Offset + 24

	-- Components ordered left to right
	local thumbsUpImage = Utility.Create"ImageLabel"
	{
		Name = "ThumbsUpImage",
		Size = UDim2.new(0, 28, 0, 28),
		Position =  UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/Shell/Icons/ThumbsUpIcon@1080.png",
		Parent = ratingContainer,
	}

	local voteFrame = VoteFrame(ratingContainer, UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))

	local thumbsDownImage = Utility.Create"ImageLabel"
	{
		Name = "ThumbsDownImage",
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/Shell/Icons/ThumbsDownIcon@1080.png",
		Parent = ratingContainer,
	}

	local separatorDot = Utility.Create"ImageLabel"
	{
		Name = "SeparatorDot",
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(0, separatorOffset, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/Shell/Icons/SeparatorDot@1080.png",
		Parent = gameInfoContainer,
	}
	local creatorIcon = Utility.Create"ImageLabel"
	{
		Name = "CreatorIcon",
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(0, separatorDot.Position.X.Offset + separatorDot.Size.X.Offset + 24, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/Shell/Icons/RobloxIcon24.png",
		Parent = gameInfoContainer,
	}
	local creatorName = Utility.Create"TextLabel"
	{
		Name = "CreatorName",
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, creatorIcon.Position.X.Offset + creatorIcon.Size.X.Offset + 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Font = GlobalSettings.RegularFont,
		TextSize = 30,
		TextColor3 = GlobalSettings.WhiteTextColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "";
		Parent = gameInfoContainer;
	}

	local descriptionText = Utility.Create"TextLabel"
	{
		Name = "DescriptionText";
		Size = UDim2.new(1, 0, 0, 92);
		Position = UDim2.new(0, 0, 1, -92);
		BackgroundTransparency = 1;
		Text = "";
		TextColor3 = GlobalSettings.LightGreyTextColor;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Top;
		Font = GlobalSettings.LightFont;
		TextWrapped = true;
		FontSize = GlobalSettings.DescriptionSize;
		Parent = detailsContainer;
	}

	local function setGameTitle(title)
		if not title or title == gameTitle.Text then return end

		local function stringWidth(s)
			return TextService:GetTextSize(s,
				Utility.ConvertFontSizeEnumToInt(gameTitle.FontSize),
				gameTitle.Font,
				Vector2.new(0, 0)).X
		end

		local suffix = ""
		while stringWidth(title..suffix) > gameTitle.Parent.AbsoluteSize.X do
			title = string.sub(title, 1,-2)
			suffix = "..."
		end

		gameTitle.Text = title..suffix
	end

	local function setSponsoredText(show)
		if show then
			sponsoredContainer.Size = UDim2.new(0, sponsoredLabelText.TextBounds.X + 24, 1, 0)
			sponsoredContainer.Visible = true
			separatorOffset = sponsoredContainer.Position.X.Offset + sponsoredContainer.Size.X.Offset + 24
		else
			sponsoredContainer.Visible = false
		end
	end

	local function setVotePanel(voteData)
		if not voteData then
			ratingContainer.Visible = false
			return
		else
			ratingContainer.Visible = true
		end
		local upVotes = voteData and voteData.UpVotes or 0
		local downVotes = voteData and voteData.DownVotes or 0
		if upVotes == 0 and downVotes == 0 then
			voteFrame:SetPercentFilled(nil)
		else
			voteFrame:SetPercentFilled(upVotes / (upVotes + downVotes))
		end
		separatorOffset = ratingContainer.Position.X.Offset + ratingContainer.Size.X.Offset + 24
	end

	local function setCreatorName(newName)
		if newName == nil then
			separatorDot.Visible = false
			creatorIcon.Visible = false
			creatorName.Visible = false
			return
		end
		if not creatorName.Visible then
			separatorDot.Visible = true
			creatorIcon.Visible = true
			creatorName.Visible = true
		end
		creatorName.Text = newName
		separatorDot.Position = UDim2.new(0, separatorOffset, 0.5, 0)
		creatorIcon.Position = UDim2.new(0, separatorDot.Position.X.Offset + separatorDot.Size.X.Offset + 24, 0.5, 0)
		creatorName.Position = UDim2.new(0, creatorIcon.Position.X.Offset + creatorIcon.Size.X.Offset + 8, 0.5, 0)
	end


	local function setDescription(newDescription)
		if not newDescription or newDescription == descriptionText.Text then return end

		descriptionText.Text = newDescription
	end

	local thumbnailView = nil
	local function setThumbnailView(thumbIds, faded)
		if thumbnailView then
			thumbnailView:KillView()
			thumbnailView = nil
		end

		if thumbIds and #thumbIds > 1 then
			thumbnailView = createThumbnailView(thumbIds, gameImageContainer, faded)
		end
	end

	local function setFaded(faded)
		local fadeColor = faded and Color3.new(0.4, 0.4, 0.4) or Color3.new(1, 1, 1)
		local tint = faded and 0.4 or 1

		for _,child in pairs(detailsContainer:GetChildren()) do
			if child:IsA('TextLabel') then
				child.TextColor3 = fadeColor
			elseif child:IsA('ImageLabel') then
				child.ImageColor3 = fadeColor
			end
		end
		voteFrame:SetImageColorTint(tint)
		if thumbnailView then
			thumbnailView:SetImageColor(fadeColor)
		end
	end

	function this:SetParent(newParent)
		viewContainer.Parent = newParent
	end


	function this:TweenTransparency(value, duration)
		local descendants = detailsContainer:GetDescendants()
		for _,child in pairs(descendants) do
			if child:IsA('TextLabel') then
				Utility.PropertyTweener(child, 'TextTransparency', child.TextTransparency, value, duration, Utility.Linear, true)
			elseif child:IsA('ImageLabel') then
				Utility.PropertyTweener(child, 'ImageTransparency', child.ImageTransparency, value, duration, Utility.Linear, true)
			end
		end
	end


	local function ClearGamePreview()
		--Disconnect Events
		Utility.DisconnectEvents(GamesPaneDetailsConns)
		GamesPaneDetailsConns = {}
		this.PlaceId = nil
		setGameTitle("")
		setVotePanel()
		setSponsoredText(false)
		setCreatorName()
		setDescription("")
		setThumbnailView()
	end

	function this:SetGamePreview(placeId, faded, isSponsored)
		Utility.DisconnectEvents(GamesPaneDetailsConns)
		GamesPaneDetailsConns = {}
		local data = GameData:GetGameData(placeId)
		if not data then
			data = GameData:GetGameData(placeId, true)
		end
		if data then
			table.insert(GamesPaneDetailsConns, data.OnGetGameDetailsEnd:
				connect(function(gameData) setDescription(gameData.Description or "")
			end))

			table.insert(GamesPaneDetailsConns, data.OnGetThumbnailIdsEnd:
				connect(function(thumbnailIds) setThumbnailView(thumbnailIds, faded)
			end))
			setGameTitle(data.Name)
			if isSponsored then
				setVotePanel()
				setSponsoredText(isSponsored)
			else
				setSponsoredText(false)
				setVotePanel(data.VoteData)
				--Use signals to make sure that these fetched data corresponds to the game we focus on
				table.insert(GamesPaneDetailsConns, data.OnGetVoteDataEnd:
					connect(function(voteData) setVotePanel(voteData)
				end))
			end
			setCreatorName(data.CreatorName)
			setDescription(data.Description or "")
			setThumbnailView(data.ThumbnailIds, faded)
			setFaded(faded)


			spawn(function()
				if not data.VoteData and inFocus then
					data:GetVoteDataAsync()
				end

				if not data.Description and inFocus then
					data:GetGameDetailsAsync()
				end

				if not data.ThumbnailIds and inFocus then
					data:GetThumbnailIdsAsync()
				end
			end)
		else
			ClearGamePreview()
		end
	end


	function this:Remove()
		viewContainer:Destroy()
	end

	function this:Focus()
		if inFocus then
			return
		end

		inFocus = true
		self:TweenTransparency(0, GlobalSettings.TabDockTweenDuration)
		Utility.PropertyTweener(detailsContainer, 'Position', detailsContainer.Position, DETAILS_FINAL_POS,
			GlobalSettings.TabDockTweenDuration, Utility.SCurveUDim2, true)
	end

	function this:RemoveFocus()
		--Disconnect Events
		Utility.DisconnectEvents(GamesPaneDetailsConns)
		GamesPaneDetailsConns = {}

		if not inFocus then
			return
		end
		this.PlaceId = nil
		inFocus = false
		Utility.PropertyTweener(detailsContainer, 'Position', detailsContainer.Position, DETAILS_START_POS,
			GlobalSettings.TabDockTweenDuration, Utility.SCurveUDim2, true)
		self:TweenTransparency(1, GlobalSettings.TabDockTweenDuration)
		setThumbnailView(nil, false)
	end

	return this
end

return createGamesPaneDetailsView
