local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local CorePackages = game:GetService("CorePackages")
local Logging = require(CorePackages.Logging)
local FlagSettings = require(Modules.LuaApp.FlagSettings)

local ClassicTheme = require(Modules.LuaApp.Themes.ClassicTheme)
-- local LightTheme = require(Modules.LuaApp.Themes.LightTheme)
-- local DarkTheme = require(Modules.LuaApp.Themes.DarkTheme)

local remoteThemeCheckEnabled = FlagSettings:IsRemoteThemeCheckEnabled()

local THEME_MAP = {
--	["dark"] = DarkTheme,
--	["light"] = LightTheme,
	["classic"] = ClassicTheme,
}

local function getThemeModuleForString(themeName)
	if themeName ~= nil and #themeName > 0 then
		local mappedTheme = THEME_MAP[string.lower(themeName)]
		if mappedTheme ~= nil then
			return mappedTheme
		else
			Logging.warn("Unrecognized theme name: " .. themeName)
		end
	end

	return ClassicTheme
end

local ThemeProvider = Roact.Component:extend("ThemeProvider")

function ThemeProvider:init(props)
	local theme = props.theme
    local themeName = props.themeName
    self._context.AppTheme = remoteThemeCheckEnabled and getThemeModuleForString(themeName) or theme
end

function ThemeProvider:render()
    return Roact.oneChild(self.props[Roact.Children])
end

return ThemeProvider
