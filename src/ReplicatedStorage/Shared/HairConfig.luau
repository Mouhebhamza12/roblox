local HairConfig = {}

HairConfig.Types = {
	BasicHair = { DisplayName = "Basic Hair", Rarity = "Common", Duration = 30, Reward = 10, Weight = 70, Color = Color3.fromRGB(105, 72, 48) },
	CurlyHair = { DisplayName = "Curly Hair", Rarity = "Uncommon", Duration = 45, Reward = 25, Weight = 25, Color = Color3.fromRGB(55, 35, 25) },
	GoldenHair = { DisplayName = "Golden Hair", Rarity = "Rare", Duration = 60, Reward = 75, Weight = 5, Color = Color3.fromRGB(245, 190, 55) },
}

HairConfig.SpeedMultipliers = { 1, 1.25, 1.5, 2 }
HairConfig.UpgradeCosts = { 100, 250, 500 }
HairConfig.MaximumStage = 5

return HairConfig
