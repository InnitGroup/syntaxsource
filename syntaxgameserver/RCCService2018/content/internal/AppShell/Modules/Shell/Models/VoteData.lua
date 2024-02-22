--[[
	{
		upVotes  :  number ,
		downVotes  :  number ,
		userVote  :  bool or nil,
		canVote  :  bool ,
		cantVoteReason  :  string ,
	}
]]

local VoteData = {}

function VoteData.new()
	local self = {}
	return self
end

function VoteData.fromJsonData(voteJson)
	local self = VoteData.new()
	self.upVotes = voteJson.UpVotes
	self.downVotes = voteJson.DownVotes
	self.userVote = voteJson.UserVote
	self.canVote = voteJson.CanVote
	self.cantVoteReason = voteJson.ReasonForNotVoteable
	return self
end

return VoteData