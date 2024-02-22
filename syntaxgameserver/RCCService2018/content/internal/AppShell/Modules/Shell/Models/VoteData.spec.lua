return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local VoteData = require(Modules.Shell.Models.VoteData)

	it("should set fields without errors", function()
		local testData =
		{
			UpVotes = 10000,
			DownVotes = 1,
			UserVote = false,
			CanVote = true,
			ReasonForNotVoteable = "Some reason."
		}

		local voteData = VoteData.fromJsonData(testData)

		expect(voteData).to.be.a("table")
		expect(voteData.upVotes).to.equal(10000)
		expect(voteData.downVotes).to.equal(1)
		expect(voteData.userVote).to.equal(false)
		expect(voteData.canVote).to.equal(true)
		expect(voteData.cantVoteReason).to.equal("Some reason.")
	end)

end