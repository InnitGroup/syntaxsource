stds.roblox = {
	read_globals = {
		game = {
			other_fields = true,
		},

		-- Roblox globals
		"script", "workspace",

		-- Extra functions
		"tick", "warn", "spawn",
		"wait", "settings",

		-- Types
		"Vector2", "Vector3",
		"Color3",
		"UDim", "UDim2",
		"Rect",
		"CFrame",
		"Enum",
		"Instance",
		"TweenInfo",
		"Random",
	}
}

stds.testez = {
	read_globals = {
		"describe",
		"it", "itFOCUS", "itSKIP",
		"FOCUS", "SKIP", "HACK_NO_XPCALL",
		"expect",
	}
}

ignore = {
	"212", -- unused arguments
	"421", -- shadowing local variable
	"422", -- shadowing argument
	"431", -- shadowing upvalue
	"432", -- shadowing upvalue argument
}

std = "lua51+roblox"

files["**/*.spec.lua"] = {
	std = "+testez",
}

files["**/*Locale.lua"] = {
	ignore = { "631" }, --Line is too long
}