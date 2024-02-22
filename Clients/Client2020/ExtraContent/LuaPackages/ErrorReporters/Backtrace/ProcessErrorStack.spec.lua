return function()
	local ProcessErrorStack = require(script.Parent.ProcessErrorStack)
	local CorePackages = game:GetService("CorePackages")

	local tutils = require(CorePackages.Packages.tutils)

	local testCasesNormal = {
		ScriptContextError = {
			error = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame, line 98 - field testError\nCoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame, line 111 - field ?\nCorePackages.Packages._Index.roact.roact.SingleEventManager, line 83",
			expectedOutput = {
				stack = {
					[1] = {
						line = "98",
						funcName = "field testError",
						sourceCode = "1",
					},
					[2] = {
						line = "111",
						funcName = "field ?",
						sourceCode = "1",
					},
					[3] = {
						line = "83",
						funcName = "SingleEventManager",
						sourceCode = "2",
					},
				},
				sourceCodeOutput = {
					["1"] = {
						path = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame",
					},
					["2"] = {
						path = "CorePackages.Packages._Index.roact.roact.SingleEventManager",
					},
				},
			},
		},
		ScriptContextErrorLuau = {
			error = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame, line 98\nCoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame, line 111\nCorePackages.Packages._Index.roact.roact.SingleEventManager, line 83",
			expectedOutput = {
				stack = {
					[1] = {
						line = "98",
						funcName = "HomePageWithAvatarViewportFrame",
						sourceCode = "1",
					},
					[2] = {
						line = "111",
						funcName = "HomePageWithAvatarViewportFrame",
						sourceCode = "1",
					},
					[3] = {
						line = "83",
						funcName = "SingleEventManager",
						sourceCode = "2",
					},
				},
				sourceCodeOutput = {
					["1"] = {
						path = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame",
					},
					["2"] = {
						path = "CorePackages.Packages._Index.roact.roact.SingleEventManager",
					},
				},
			},
		},
		DebugTraceback = {
			error = "Stack Begin\nScript 'CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame', Line 100 - field testError\nScript 'CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame', Line 111 - field ?\nScript 'CorePackages.Packages._Index.roact.roact.SingleEventManager', Line 83\nStack End",
			expectedOutput = {
				stack = {
					[1] = {
						line = "100",
						funcName = "field testError",
						sourceCode = "1",
					},
					[2] = {
						line = "111",
						funcName = "field ?",
						sourceCode = "1",
					},
					[3] = {
						line = "83",
						funcName = "SingleEventManager",
						sourceCode = "2",
					},
				},
				sourceCodeOutput = {
					["1"] = {
						path = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame",
					},
					["2"] = {
						path = "CorePackages.Packages._Index.roact.roact.SingleEventManager",
					},
				},
			},
		},
		DebugTracebackLuau = {
			error = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame:100\nCoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame:111\nCorePackages.Packages._Index.roact.roact.SingleEventManager:83",
			expectedOutput = {
				stack = {
					[1] = {
						line = "100",
						funcName = "HomePageWithAvatarViewportFrame",
						sourceCode = "1",
					},
					[2] = {
						line = "111",
						funcName = "HomePageWithAvatarViewportFrame",
						sourceCode = "1",
					},
					[3] = {
						line = "83",
						funcName = "SingleEventManager",
						sourceCode = "2",
					},
				},
				sourceCodeOutput = {
					["1"] = {
						path = "CoreGui.RobloxGui.Modules.LuaApp.Components.Home.HomePageWithAvatarViewportFrame",
					},
					["2"] = {
						path = "CorePackages.Packages._Index.roact.roact.SingleEventManager",
					},
				},
			},
		},
		OneLineError = {
			error = "Script 'Workspace.Script', Line 3",
			expectedOutput = {
				stack = {
					[1] = {
						line = "3",
						funcName = "Script",
						sourceCode = "1",
					},
				},
				sourceCodeOutput = {
					["1"] = {
						path = "Workspace.Script",
					},
				},
			},
		},
		PathWithNumbers = {
			error = "Script 'Workspace1.Script2', Line 3",
			expectedOutput = {
				stack = {
					[1] = {
						line = "3",
						funcName = "Script2",
						sourceCode = "1",
					},
				},
				sourceCodeOutput = {
					["1"] = {
						path = "Workspace1.Script2",
					},
				},
			},
		},
	}

	it("should convert the error strings to the correct format", function()
		for key, testCase in pairs(testCasesNormal) do
			local stack, sourceCodeOutput = ProcessErrorStack(testCase.error)

			expect(tutils.deepEqual(testCase.expectedOutput, {
				stack = stack,
				sourceCodeOutput = sourceCodeOutput,
			}, true)).to.equal(true)
		end
	end)

	local testCasesOther = {
		{},
		123,
		function() error("test") end,
		"",
		" - ",
		", line ",
		", line  - ",
		":",
		" - , line ",
	}

	it("should return empty results with inputs that are not valid stack trace", function()
		for _, testCase in ipairs(testCasesOther) do
			local stack, sourceCodeOutput = ProcessErrorStack(testCase)

			expect(tutils.shallowEqual(stack, {})).to.equal(true)
			expect(tutils.shallowEqual(sourceCodeOutput, {})).to.equal(true)
		end
	end)

	it("should return empty results with nil input", function()
		local stack, sourceCodeOutput = ProcessErrorStack(nil)

		expect(tutils.shallowEqual(stack, {})).to.equal(true)
		expect(tutils.shallowEqual(sourceCodeOutput, {})).to.equal(true)
	end)
end
