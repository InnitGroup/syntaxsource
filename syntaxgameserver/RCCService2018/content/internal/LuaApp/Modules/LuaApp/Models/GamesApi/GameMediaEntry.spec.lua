return function()
	local CorePackages = game:GetService("CorePackages")
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameMediaEntry = require(Modules.LuaApp.Models.GamesApi.GameMediaEntry)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)
	local Logging = require(CorePackages.Logging)

	local function makeTestData()
		local data = {
			id = 42,
			assetTypeId = 1234,
			imageId = 4321,
			videoHash = "test_video_hash",
			videoTitle = "test_video_title",
			approved = true
		}

		return data
	end

	describe("GameMediaEntry", function()
		it("should return empty table on new()", function()
			expect(TableUtilities.FieldCount(GameMediaEntry.new())).to.equal(0)
		end)

		it("should assert for missing required params", function()
			local testData = makeTestData()

			for propertyName, _ in pairs(testData) do
				local dataCopy = makeTestData()
				dataCopy[propertyName] = nil

				if propertyName == "videoHash" or propertyName == "videoTitle" then
					expect(function()
						GameMediaEntry.fromJsonData(dataCopy)
					end).to.be.ok()
				else
					expect(function()
						GameMediaEntry.fromJsonData(dataCopy)
					end).to.throw()
				end
			end
		end)

		it("should assign correct values and types", function()
			local testData = makeTestData()
			local entry = GameMediaEntry.fromJsonData(testData)

			expect(entry.id).to.equal(tostring(testData.id))
			expect(entry.assetTypeId).to.equal(testData.assetTypeId)
			expect(entry.imageId).to.equal(tostring(testData.imageId))
			expect(entry.videoHash).to.equal(testData.videoHash)
			expect(entry.videoTitle).to.equal(testData.videoTitle)
			expect(entry.approved).to.equal(testData.approved)
		end)

		it("should ignore unsupported keys", function()
			local testData = makeTestData()
			testData["foobar"] = true

			local entry = GameMediaEntry.fromJsonData(testData)
			expect(entry["foobar"]).to.equal(nil)
		end)

		it("should warn on invalid assetTypeId", function()
			local logResults = Logging.capture(function()
				local testData = makeTestData()
				testData["assetTypeId"] = 1337

				GameMediaEntry.fromJsonData(testData)
			end)

			expect(#logResults.warnings).to.equal(1)
		end)
	end)
end
