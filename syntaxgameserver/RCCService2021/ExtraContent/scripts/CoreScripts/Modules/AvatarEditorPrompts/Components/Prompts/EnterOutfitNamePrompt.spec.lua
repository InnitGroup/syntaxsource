return function()
	local CorePackages = game:GetService("CorePackages")

	local AppDarkTheme = require(CorePackages.AppTempCommon.LuaApp.Style.Themes.DarkTheme)
	local AppFont = require(CorePackages.AppTempCommon.LuaApp.Style.Fonts.Gotham)

	local Roact = require(CorePackages.Roact)
	local Rodux = require(CorePackages.Rodux)
	local RoactRodux = require(CorePackages.RoactRodux)
	local UIBlox = require(CorePackages.UIBlox)

	local AvatarEditorPrompts = script.Parent.Parent.Parent
	local Reducer = require(AvatarEditorPrompts.Reducer)
	local PromptType = require(AvatarEditorPrompts.PromptType)
	local OpenPrompt = require(AvatarEditorPrompts.Actions.OpenPrompt)

	local appStyle = {
		Theme = AppDarkTheme,
		Font = AppFont,
	}

	describe("EnterOutfitNamePrompt", function()
		it("should create and destroy without errors", function()
			local EnterOutfitNamePrompt = require(script.Parent.EnterOutfitNamePrompt)

			local store = Rodux.Store.new(Reducer, nil, {
				Rodux.thunkMiddleware,
			})

			local humanoidDescription = Instance.new("HumanoidDescription")

			store:dispatch(OpenPrompt(PromptType.EnterOutfitName, {
				humanoidDescription = humanoidDescription,
				rigType = Enum.HumanoidRigType.R15,
			}))

			local element = Roact.createElement(RoactRodux.StoreProvider, {
				store = store,
			}, {
				ThemeProvider = Roact.createElement(UIBlox.Style.Provider, {
					style = appStyle,
				}, {
					EnterOutfitNamePrompt = Roact.createElement(EnterOutfitNamePrompt)
				})
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end)
end
