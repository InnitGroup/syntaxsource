return function()
	local SetGameThumbnails = require(script.Parent.SetGameThumbnails)

	it("should assert if given a non-table for thumbnailsTable", function()
		SetGameThumbnails({})

		expect(function()
			SetGameThumbnails("Blargle!")
		end).to.throw()

		expect(function()
			SetGameThumbnails(0)
		end).to.throw()

		expect(function()
			SetGameThumbnails(nil)
		end).to.throw()

		expect(function()
			SetGameThumbnails(false)
		end).to.throw()

		expect(function()
			SetGameThumbnails(function() end)
		end).to.throw()
	end)
end