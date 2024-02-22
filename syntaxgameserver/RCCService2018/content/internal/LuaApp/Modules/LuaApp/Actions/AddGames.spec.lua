return function()
	local AddGames = require(script.Parent.AddGames)

	it("should assert if given a non-table for games", function()
		AddGames({})

		expect(function()
			AddGames("Blargle!")
		end).to.throw()

		expect(function()
			AddGames(0)
		end).to.throw()

		expect(function()
			AddGames(nil)
		end).to.throw()

		expect(function()
			AddGames(false)
		end).to.throw()

		expect(function()
			AddGames(function() end)
		end).to.throw()
	end)
end