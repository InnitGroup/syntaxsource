local CorePackages = game:GetService("CorePackages")
local Color = require(CorePackages.AppTempCommon.Common.Color)

local Colors = {
	Obsidian = Color.Color3FromHex(0x0A0B0B),
	Carbon = Color.Color3FromHex(0x18191B),
	Charcoal = Color.Color3FromHex(0x1F2123),
	Slate = Color.Color3FromHex(0x232527),
	Flint = Color.Color3FromHex(0x393B3D),
	Graphite = Color.Color3FromHex(0x656668),
	Pumice = Color.Color3FromHex(0xBDBEBE),

	Black = Color3.fromRGB(0, 0, 0),
	White = Color3.fromRGB(255, 255, 255),

	Gray1 = Color.Color3FromHex(0x191919),
	Gray2 = Color.Color3FromHex(0x757575),
	Gray3 = Color.Color3FromHex(0xB8B8B8),
	Gray4 = Color.Color3FromHex(0xE3E3E3),

	BluePrimary = Color.Color3FromHex(0x00A2FF),
	BlueHover = Color.Color3FromHex(0x32B5FF),
	BluePressed = Color.Color3FromHex(0x0074BD),
	BlueDisabled = Color.Color3FromHex(0x99DAFF),

	-- TODO: migrate all the colors in Constants.lua to here
}

return Colors