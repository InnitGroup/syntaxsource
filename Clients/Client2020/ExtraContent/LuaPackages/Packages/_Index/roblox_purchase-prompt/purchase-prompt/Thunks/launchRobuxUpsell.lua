local Root = script.Parent.Parent
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ErrorOccurred = require(Root.Actions.ErrorOccurred)
local SetPromptState = require(Root.Actions.SetPromptState)
local UpsellFlow = require(Root.Enums.UpsellFlow)
local PromptState = require(Root.Enums.PromptState)
local PurchaseError = require(Root.Enums.PurchaseError)
local Constants = require(Root.Misc.Constants)
local getUpsellFlow = require(Root.NativeUpsell.getUpsellFlow)
local Analytics = require(Root.Services.Analytics)
local PlatformInterface = require(Root.Services.PlatformInterface)
local Thunk = require(Root.Thunk)
local Promise = require(Root.Promise)

local retryAfterUpsell = require(script.Parent.retryAfterUpsell)

local GetFFlagAdultConfirmationEnabled = require(Root.Flags.GetFFlagAdultConfirmationEnabled)
local GetFFlagAdultConfirmationEnabledNew = require(Root.Flags.GetFFlagAdultConfirmationEnabledNew)

local requiredServices = {
	Analytics,
	PlatformInterface,
}

local function launchRobuxUpsell()
	return Thunk.new(script.Name, requiredServices, function(store, services)
		local analytics = services[Analytics]
		local platformInterface = services[PlatformInterface]
		local state = store:getState()
		local abVars = state.abVariations

		if (GetFFlagAdultConfirmationEnabledNew()
					or (GetFFlagAdultConfirmationEnabled() and (abVars[Constants.ABTests.ADULT_CONFIRMATION] == "Variation1")))
				and state.accountInfo.AgeBracket ~= 0
				and state.promptState ~= PromptState.AdultConfirmation then
			analytics.signalAdultLegalTextShown()
			store:dispatch(SetPromptState(PromptState.AdultConfirmation))
			return
		end

		local upsellFlow = getUpsellFlow(UserInputService:GetPlatform())

		if upsellFlow == UpsellFlow.Web then
			platformInterface.startRobuxUpsellWeb()
			analytics.reportRobuxUpsellStarted()
			store:dispatch(SetPromptState(PromptState.UpsellInProgress))

		elseif upsellFlow == UpsellFlow.Mobile then
			local nativeProductId = store:getState().nativeUpsell.robuxProductId

			analytics.reportNativeUpsellStarted(nativeProductId)
			platformInterface.promptNativePurchase(Players.LocalPlayer, nativeProductId)
			store:dispatch(SetPromptState(PromptState.UpsellInProgress))

		elseif upsellFlow == UpsellFlow.Xbox then
			local nativeProductId = store:getState().nativeUpsell.robuxProductId
			store:dispatch(SetPromptState(PromptState.UpsellInProgress))
			return Promise.new(function(resolve, reject)
				local platformPurchaseResult = platformInterface.beginPlatformStorePurchase(nativeProductId)

				Promise.resolve(platformPurchaseResult)
			end)
				:andThen(function(result)
					if result ~= 0 then
						store:dispatch(retryAfterUpsell)
					end
				end)
		elseif upsellFlow == UpsellFlow.Unavailable then
			store:dispatch(ErrorOccurred(PurchaseError.NotEnoughRobuxNoUpsell))
		else
			warn("Need more Robux: platform not supported for Robux purchase")
		end
	end)
end

return launchRobuxUpsell
