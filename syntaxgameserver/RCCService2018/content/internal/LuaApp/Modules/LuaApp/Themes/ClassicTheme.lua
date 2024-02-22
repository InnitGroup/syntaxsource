local Colors = require(script.Parent.Colors)

local theme = {
	Color = {
		Background = Colors.Gray4,
	},

	SecondaryButton = {
		Color = Colors.BluePrimary,
		HoverColor = Colors.BlueHover,
		OnPressColor = Colors.BlueHover,
		OnPressTransparency = 0,
		DisabledColor = Colors.BlueDisabled,
		DisabledTransparency = 0,
	},

	EmptyStatePage = {
		ErrorMessage = {
			Color = Colors.Gray3,
		},
	},

	RetryButton = {
		Color = Colors.Gray1,
		DisabledColor = Colors.Gray3,
		DisabledTransparency = 0,
	},

	ShimmerAnimation = {
		Transparency = 0,
	},
}

return theme