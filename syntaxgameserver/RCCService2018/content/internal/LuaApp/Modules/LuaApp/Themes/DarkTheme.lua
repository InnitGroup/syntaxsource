local Colors = require(script.Parent.Colors)

local theme = {
	Color = {
		Background = Colors.Slate,
	},

	SecondaryButton = {
		Color = Colors.Pumice,
		HoverColor = Colors.White,
		OnPressColor = Colors.Pumice,
		OnPressTransparency = 0.5,
		DisabledColor = Colors.Pumice,
		DisabledTransparency = 0.5,
	},

	EmptyStatePage = {
		ErrorMessage = {
			Color = Colors.Graphite,
		},
	},

	ShimmerAnimation = {
		Transparency = 0.65,
	},
}

theme.RetryButton = theme.SecondaryButton

return theme