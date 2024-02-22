return function()
	local Root = script.Parent.Parent.Parent

	local CorePackages = game:GetService("CorePackages")
local PurchasePromptDeps = require(CorePackages.PurchasePromptDeps)
	local Roact = PurchasePromptDeps.Roact

	local UnitTestContainer = require(Root.Test.UnitTestContainer)

	local AutoSizedText = require(script.Parent.AutoSizedText)

	it("should create and destroy without errors", function()
		local element = Roact.createElement(UnitTestContainer, nil, {
			Roact.createElement(AutoSizedText, {
				text = "Test",
				width = 0,
				layoutOrder = 0,
			})
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end
