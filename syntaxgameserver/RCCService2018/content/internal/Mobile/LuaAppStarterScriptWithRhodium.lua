local scriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")
local RobloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")

scriptContext:AddCoreScriptLocal("LuaAppStarterScript", RobloxGui)

local TestLuaMobileApp = require(RobloxGui.Modules.RhodiumTest.Testcase.LuaApp.TestLuaMobileApp)

-- Run Rhodium test when ctrl+shift+alt+R is pressed
UserInputService.InputEnded:connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard and
		UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and
		UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and
		UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
	then
		if input.KeyCode == Enum.KeyCode.R then
			TestLuaMobileApp()
		end
	end
end)