return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAssetInfo = require(script.Parent.AEAssetInfo)
	local AEAddAssetsInfoAction = require(Modules.LuaApp.Actions.AEActions.AEAddAssetsInfo)
	local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)
	local AEAssetInfoModel = require(Modules.LuaApp.Models.AEAssetInfo)

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AEAssetInfo(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEAssetInfo(nil, {})
		local newState = AEAssetInfo(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should add a single asset", function()
		local assetModel = AEAssetInfoModel.mock()
		local asset = {}
		asset[assetModel.assetId] = assetModel

		local oldState = AEAssetInfo(nil, {})
		local newState = AEAssetInfo(oldState, AEAddAssetsInfoAction(asset))

		expect(newState[assetModel.assetId]).to.be.ok()
		expect(newState[assetModel.assetId].assetId).to.equal(assetModel.assetId)
	end)

	it("should combine multiple tables", function()
		local assets = {}

		local assetModel = AEAssetInfoModel.mock()
		assets[assetModel.assetId] = assetModel
		local newState = AEAssetInfo(nil, AEAddAssetsInfoAction(assets))

		local assetModel2 = AEAssetInfoModel.mock()
		assets[assetModel2.assetId] = assetModel2
		newState = AEAssetInfo(newState, AEAddAssetsInfoAction(assets))

		expect(countChildObjects(newState)).to.equal(2)
		expect(newState[assetModel2.assetId]).to.be.equal(assetModel2)
	end)

	it("should add mulitple assets with AEReceivedAvatarData", function()
		local assetData = {}
		local assetModel = {
			id = 1,
			assetType = { id = 1 }
		}
		local assetModel2 = {
			id = 2,
			assetType = { id = 2 }
		}

		assetData[#assetData + 1] = assetModel
		assetData[#assetData + 1] = assetModel2

		local state = AEAssetInfo(nil, AEReceivedAvatarData({ assets = assetData }))
		expect(countChildObjects(state)).to.equal(2)
		expect(state[assetModel.id].assetId).to.be.equal(assetModel.id)
		expect(state[assetModel2.id].assetId).to.be.equal(assetModel2.id)
	end)
end