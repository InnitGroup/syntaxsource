local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local EmptyStatePage = require(Modules.LuaApp.Components.EmptyStatePage)
local LoadingBar = require(Modules.LuaApp.Components.LoadingBar)
local RetryButton = require(Modules.LuaApp.Components.RetryButton)

local COMPONENT_LOADING_STATE = {
	LOADING_INITIAL = "loading_initial",
	FAILED = "failed",
	LOADED = "loaded"
}

local LoadingStateWrapper = Roact.PureComponent:extend("LoadingStateWrapper")

local StateTransitionTable = {
	[COMPONENT_LOADING_STATE.LOADING_INITIAL] = {
		[RetrievalStatus.NotStarted] = COMPONENT_LOADING_STATE.LOADING_INITIAL,
		[RetrievalStatus.Fetching] = COMPONENT_LOADING_STATE.LOADING_INITIAL,
		[RetrievalStatus.Done] = COMPONENT_LOADING_STATE.LOADED,
		[RetrievalStatus.Failed] = COMPONENT_LOADING_STATE.FAILED,
	},
	[COMPONENT_LOADING_STATE.FAILED] = {
		[RetrievalStatus.NotStarted] = nil,
		[RetrievalStatus.Fetching] = COMPONENT_LOADING_STATE.FAILED,
		[RetrievalStatus.Done] = COMPONENT_LOADING_STATE.LOADED,
		[RetrievalStatus.Failed] = COMPONENT_LOADING_STATE.FAILED,
	},
	[COMPONENT_LOADING_STATE.LOADED] = {
		[RetrievalStatus.NotStarted] = nil,
		[RetrievalStatus.Fetching] = COMPONENT_LOADING_STATE.LOADED,
		[RetrievalStatus.Done] = COMPONENT_LOADING_STATE.LOADED,
		[RetrievalStatus.Failed] = COMPONENT_LOADING_STATE.LOADED,
	},
}

local function getNewLoadingState(currentState, newDataStatus)
	local newState = StateTransitionTable[currentState][newDataStatus]

	if newState == nil then
		error("invalid state transition!")
	end

	return newState
end

function LoadingStateWrapper:init()
	self.state = {
		loadingState = getNewLoadingState(COMPONENT_LOADING_STATE.LOADING_INITIAL, self.props.dataStatus)
	}
end

function LoadingStateWrapper:render()
	local loadingState = self.state.loadingState
	local onRetry = self.props.onRetry
	local isPage = self.props.isPage
	local renderOnLoading = self.props.renderOnLoading
	local renderOnFailed = self.props.renderOnFailed
	local renderOnLoaded = self.props.renderOnLoaded

	if loadingState == COMPONENT_LOADING_STATE.LOADING_INITIAL then
		if renderOnLoading then
			return renderOnLoading()
		else
			return Roact.createElement(LoadingBar)
		end
	elseif loadingState == COMPONENT_LOADING_STATE.FAILED then
		if renderOnFailed then
			return renderOnFailed()
		else
			if isPage then
				return Roact.createElement(EmptyStatePage, {
					onRetry = onRetry,
				})
			else
				return Roact.createElement(RetryButton, {
					onRetry = onRetry,
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
				})
			end
		end
	else
		return renderOnLoaded()
	end
end

function LoadingStateWrapper:didUpdate(prevProps)
	if prevProps.dataStatus ~= self.props.dataStatus then
		local newLoadingState = getNewLoadingState(self.state.loadingState, self.props.dataStatus)

		if newLoadingState ~= self.state.loadingState then
			self:setState({
				loadingState = newLoadingState
			})
		end
	end
end


return LoadingStateWrapper