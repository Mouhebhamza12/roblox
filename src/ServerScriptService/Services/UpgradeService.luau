local HairConfig = require(game:GetService("ReplicatedStorage").Shared.HairConfig)
local CurrencyService = require(script.Parent.CurrencyService)
local UpgradeService = {}

function UpgradeService.GetNextCost(data)
	return HairConfig.UpgradeCosts[data.GrowthSpeedLevel]
end

function UpgradeService.Buy(data)
	local cost = UpgradeService.GetNextCost(data)
	if not cost or data.GrowthSpeedLevel >= #HairConfig.SpeedMultipliers then return false, "Maximum speed reached" end
	if not CurrencyService.Spend(data, cost) then return false, "Not enough coins" end
	data.GrowthSpeedLevel += 1
	return true, nil
end

return UpgradeService
