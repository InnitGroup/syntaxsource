return function()
	it("should return a table", function()
		local action = require(script.Parent.RequestCrossPlayEnabled)

		expect(action).to.be.a("table")
	end)

	it("should return a table when called as a function", function()
		local action = require(script.Parent.RequestCrossPlayEnabled)()

		expect(action).to.be.a("table")
	end)

	it("should set the name", function()
		local action = require(script.Parent.RequestCrossPlayEnabled)

		expect(action.name).to.equal("RequestCrossPlayEnabled")
	end)

	it("should set the type", function()
		local action = require(script.Parent.RequestCrossPlayEnabled)()

		expect(action.type).to.equal("RequestCrossPlayEnabled")
	end)
end