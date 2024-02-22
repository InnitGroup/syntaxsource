return function()
	local SetGamesPageDataStatus = require(script.Parent.SetGamesPageDataStatus)

	it("should assert if given a non-string for status", function()
		SetGamesPageDataStatus("hello")

		expect(function()
			SetGamesPageDataStatus(0)
		end).to.throw()

		expect(function()
			SetGamesPageDataStatus(nil)
		end).to.throw()

		expect(function()
			SetGamesPageDataStatus({})
		end).to.throw()

		expect(function()
			SetGamesPageDataStatus(false)
		end).to.throw()

		expect(function()
			SetGamesPageDataStatus(function() end)
		end).to.throw()
	end)
end