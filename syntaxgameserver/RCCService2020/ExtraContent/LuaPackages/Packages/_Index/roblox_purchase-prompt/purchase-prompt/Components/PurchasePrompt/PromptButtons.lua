local Root = script.Parent.Parent.Parent

local LuaPackages = Root.Parent
local Roact = require(LuaPackages.Roact)

local PromptState = require(Root.Enums.PromptState)
local purchaseItem = require(Root.Thunks.purchaseItem)
local launchRobuxUpsell = require(Root.Thunks.launchRobuxUpsell)
local getPlayerPrice = require(Root.Utils.getPlayerPrice)
local connectToStore = require(Root.connectToStore)

local ConfirmButton = require(script.Parent.ConfirmButton)
local CancelButton = require(script.Parent.CancelButton)
local OkButton = require(script.Parent.OkButton)
local withLayoutValues = require(script.Parent.Parent.Connection.withLayoutValues)

local CONFIRM_PURCHASE_KEY = "CoreScripts.PurchasePrompt.ConfirmPurchase.%s"

local PromptButtons = Roact.PureComponent:extend("PromptButtons")

function PromptButtons:render()
	return withLayoutValues(function(values)
		local layoutOrder = self.props.layoutOrder
		local onClose = self.props.onClose
		local promptState = self.props.promptState
		local price = self.props.price

		local onBuy = self.props.onBuy
		local onRobuxUpsell = self.props.onRobuxUpsell

		local children
		if promptState == PromptState.PurchaseComplete
			or promptState == PromptState.Error
		then
			children = {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 4),
				}),
				OkButton = Roact.createElement(OkButton, {
					onClick = onClose,
				}),
			}
		else
			local confirmButtonStringKey = CONFIRM_PURCHASE_KEY:format("BuyNow")
			local leftButtonCallback = onBuy
			if price == 0 then
				confirmButtonStringKey = CONFIRM_PURCHASE_KEY:format("TakeFree")
			elseif promptState == PromptState.RobuxUpsell then
				confirmButtonStringKey = CONFIRM_PURCHASE_KEY:format("BuyRobuxV2")
				leftButtonCallback = onRobuxUpsell
			elseif promptState == PromptState.AdultConfirmation then
				confirmButtonStringKey = "CoreScripts.PurchasePrompt.Button.OK"
				leftButtonCallback = onRobuxUpsell
			end
			children = {
				ConfirmButton = Roact.createElement(ConfirmButton, {
					stringKey = confirmButtonStringKey,
					onClick = leftButtonCallback,
				}),
				CancelButton = Roact.createElement(CancelButton, {
					onClick = onClose,
				}),
			}
		end

		return Roact.createElement("Frame", {
			LayoutOrder = layoutOrder,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, values.Size.ButtonHeight)
		}, children)
	end)
end

local function mapStateToProps(state)
	local isPlayerPremium = state.accountInfo.membershipType == 4
	local price = getPlayerPrice(state.productInfo, isPlayerPremium)
	return {
		promptState = state.promptState,
		price = price,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		onBuy = function()
			dispatch(purchaseItem())
		end,
		onRobuxUpsell = function()
			dispatch(launchRobuxUpsell())
		end,
	}
end

PromptButtons = connectToStore(
	mapStateToProps,
	mapDispatchToProps
)(PromptButtons)

return PromptButtons
