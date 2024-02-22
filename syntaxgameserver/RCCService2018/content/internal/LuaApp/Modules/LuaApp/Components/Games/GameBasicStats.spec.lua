return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local GameBasicStats = require(Modules.LuaApp.Components.Games.GameBasicStats)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local function testGameBasicStats(upVotes, downVotes, voteText)
		local element = mockServices({
			GameBasicStats = Roact.createElement(GameBasicStats, {
				playerCount = 100,
				upVotes = upVotes,
				downVotes = downVotes,
				settings = {
					Color = Color3.fromRGB(0, 0, 0),
					Transparency = 0.3,
					Font = Enum.Font.SourceSans,
				},
			})
		})

		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "GameBasicStats")

		local voteTextLabel = container.GameBasicStats:FindFirstChild("upVotesText", false)
		expect(voteTextLabel ~= nil).to.equal(true)
		expect(voteTextLabel.Text).to.equal(voteText)

		Roact.unmount(instance)
	end

	it("should display correctly when both votes are non zero", function()
		testGameBasicStats(90, 10, "90%")
	end)

	it("should display correctly when both votes are 0", function()
		testGameBasicStats(0, 0, "--")
	end)

	it("should display correctly when one vote is 0 and the other is not", function()
		testGameBasicStats(0, 2, "0%")
		testGameBasicStats(2, 0, "100%")
	end)

	it("should create and destroy without errors when there're no votes", function()
		testGameBasicStats(nil, nil, "--")
	end)
end