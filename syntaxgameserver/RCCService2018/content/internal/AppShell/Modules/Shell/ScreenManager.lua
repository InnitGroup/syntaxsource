local CoreGui = game:GetService("CoreGui")
local RobloxGui = CoreGui.RobloxGui

local Analytics = require(script.Parent.Analytics)
local AppState = require(script.Parent.AppState)
local GlobalSettings = require(script.Parent.GlobalSettings)
local ScreenItem = require(script.Parent.Models.ScreenItem)
local SoundManager = require(script.Parent.SoundManager)
local Utility = require(script.Parent.Utility)

local InsertScreen = require(script.Parent.Actions.InsertScreen)
local RemoveScreen = require(script.Parent.Actions.RemoveScreen)

local ScreenManager = {}

local ScreenMap = {}

local ScreenGuis = {[1] = RobloxGui}

local function getScreenPriority(screen)
	local priority = GlobalSettings.DefaultPriority
	if screen.GetPriority ~= nil then
		priority = screen:GetPriority()
	end
	return priority
end

local function setRBXEventStream_Screen(screen, status)
	if screen and type(screen.GetAnalyticsInfo) == "function" then
		local screenAnalyticsInfo = screen:GetAnalyticsInfo()
		if type(screenAnalyticsInfo) == "table" and screenAnalyticsInfo[Analytics.WidgetNames('WidgetId')] then
			screenAnalyticsInfo.Status = status
			Analytics.SetRBXEventStream("Widget",  screenAnalyticsInfo)
		end
	end
end

function ScreenManager:GetScreenGuiByPriority(priority)
	priority = math.max(1, priority)
	if not ScreenGuis[priority] then
		for i = 1, priority do
			if not ScreenGuis[i] then
				ScreenGuis[i] = Utility.Create'ScreenGui'
				{
					Name = 'AppShell' .. tostring(i);
					Parent = CoreGui;
				}
			end
		end
	end

	return ScreenGuis[priority]
end

function ScreenManager:OpenScreen(screen, hidePrevious)
	if hidePrevious == nil then
		hidePrevious = true
	end

	local data = {
		hidePrevious = hidePrevious,
	}

	local id = tostring(screen)
	ScreenMap[id] = {
		screen = screen,
		isShown = false,
	}

	local screenItem = ScreenItem.new(id, getScreenPriority(screen), data)
	AppState.store:dispatch(InsertScreen(screenItem))
end

function ScreenManager:CloseCurrent()
	local screenList = AppState.store:getState().ScreenList
	local frontScreen = #screenList > 0 and screenList[1]

	if not frontScreen or not ScreenMap[frontScreen.id] then
		return
	end

	AppState.store:dispatch(RemoveScreen(frontScreen))
end

local function handleScreensRemoved(screenList)
	local currentListToMap = {}
	for _, item in ipairs(screenList) do
		currentListToMap[item.id] = true
	end

	local idsToRemove = {}
	for id,_ in pairs(ScreenMap) do
		if not currentListToMap[id] then
			table.insert(idsToRemove, id)
		end
	end

	for _, id in ipairs(idsToRemove) do
		local screenItem = ScreenMap[id]
		if screenItem then
			local screen = screenItem.screen

			screen:RemoveFocus()
			screen:Hide()

			if screen.ScreenRemoved then
				screen:ScreenRemoved()
			end

			setRBXEventStream_Screen(screen, "Close")
		end

		ScreenMap[id] = nil
	end
end

local function handleScreensAdded(screenList)
	for i = #screenList, 1, -1 do
		local screenListItem = screenList[i]

		local screenMapItem = ScreenMap[screenListItem.id]
		if screenMapItem then
			local screen = screenMapItem.screen
			if i > 1 then
				local doHide = true
				local prevListItem = screenList[i - 1]
				if prevListItem and prevListItem.data then
					doHide = prevListItem.data.hidePrevious
				end

				screen:RemoveFocus()
				if doHide then
					screen:Hide()
					screenMapItem.isShown = false
				end

				if not screenMapItem.isShown and not doHide then
					screen:Show()
					screenMapItem.isShown = true
				end
			else
				if not screenMapItem.isShown then
					screen:Show()
					screenMapItem.isShown = true
					setRBXEventStream_Screen(screen, "Show")
				end
				screen:Focus()
				setRBXEventStream_Screen(screen, "Focus")
			end
		end
	end
end

local function update(screenList)
	handleScreensRemoved(screenList)
	handleScreensAdded(screenList)
end

AppState.store.changed:connect(function(newState, oldState)
	local currentScreenList = newState.ScreenList
	local previousScreenList = oldState.ScreenList

	if currentScreenList == previousScreenList then
		return
	end

	update(currentScreenList)
end)

function ScreenManager:ContainsScreen(desiredScreen)
	for _,item in pairs(ScreenMap) do
		if item.screen == desiredScreen then
			return true
		end
	end

	return false
end

function ScreenManager:GetScreenBelow(screen)
	local screenList = AppState.store:getState().ScreenList

	for i,screenItem in ipairs(screenList) do
		if screenItem.id == tostring(screen) then
			local prevScreenItem = screenList[i + 1]
			if prevScreenItem then
				local prevScreen = ScreenMap[prevScreenItem.id]
				if prevScreen then
					return prevScreen.screen
				end
			end
		end
	end

	return nil
end

function ScreenManager:GetTopScreen()
	local screenList = AppState.store:getState().ScreenList
	if screenList and #screenList > 0 then
		local frontScreen = screenList[1]
		return ScreenMap[frontScreen.id].screen
	end

	return nil
end


----- TWEENS -----

local function FadeInElement(element, tweeners)
	if element == nil then return end
	if element:IsA('ImageLabel') or element:IsA('ImageButton') then
		table.insert(tweeners, Utility.PropertyTweener(element, 'ImageTransparency', 1, element.ImageTransparency, 0.5, Utility.EaseOutQuad))
	end
	if element:IsA('GuiObject') then
		table.insert(tweeners, Utility.PropertyTweener(element, 'BackgroundTransparency', 1, element.BackgroundTransparency, 0.5, Utility.EaseOutQuad))
	end
	if element:IsA('TextLabel') or element:IsA('TextBox') or element:IsA('TextButton') then
		table.insert(tweeners, Utility.PropertyTweener(element, 'TextTransparency', 1, element.TextTransparency, 0.5, Utility.EaseOutQuad))
	end
	for _, child in pairs(element:GetChildren()) do
		FadeInElement(child, tweeners)
	end
end

function ScreenManager:FadeInSitu(guiObject)
	local tweeners = {}
	if guiObject then
		FadeInElement(guiObject, tweeners)
	end
	return tweeners
end

function ScreenManager:DefaultFadeIn(guiObject)
	local tweeners = {}

	if guiObject then
		table.insert(tweeners, Utility.PropertyTweener(guiObject, 'Position', guiObject.Position + UDim2.new(0.15, 0, 0, 0), guiObject.Position, 0.5,
			function(t,b,c,d)
				if t >= d then return b + c end
				t = t / d;
				local tComputed = t*(t-2)
				return -UDim2.new(c.X.Scale * tComputed, c.X.Offset * tComputed, c.Y.Scale * tComputed, c.Y.Offset * tComputed) + b
			end))

		FadeInElement(guiObject, tweeners)
	end

	return tweeners
end

function ScreenManager:DefaultCancelFade(tweens)
	if tweens then
		for _, tween in pairs(tweens) do
			tween:Finish()
		end
	end

	return nil
end

function ScreenManager:PlayDefaultOpenSound()
	SoundManager:Play('ScreenChange')
end

return ScreenManager