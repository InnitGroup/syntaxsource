return function()
	local SetHomePageDataStatus = require(script.Parent.SetHomePageDataStatus)

	it("should assert if given a non-string for status", function()
		SetHomePageDataStatus("hello")

		expect(function()
			SetHomePageDataStatus(0)
		end).to.throw()

		expect(function()
			SetHomePageDataStatus(nil)
		end).to.throw()

		expect(function()
			SetHomePageDataStatus({})
		end).to.throw()

		expect(function()
			SetHomePageDataStatus(false)
		end).to.throw()

		expect(function()
			SetHomePageDataStatus(function() end)
		end).to.throw()
	end)
end