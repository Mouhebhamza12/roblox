local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HairConfig = require(ReplicatedStorage.Shared.HairConfig)
local HairService = {}
local random = Random.new()

local function chooseHairType()
	local totalWeight = 0
	for _, definition in pairs(HairConfig.Types) do totalWeight += definition.Weight end
	local choice = random:NextNumber(0, totalWeight)
	for name, definition in pairs(HairConfig.Types) do
		choice -= definition.Weight
		if choice <= 0 then return name end
	end
	return "BasicHair"
end

function HairService.Start(data)
	if data.GrowthStartTime then return false end
	local hairType = chooseHairType()
	local baseDuration = HairConfig.Types[hairType].Duration
	local multiplier = HairConfig.SpeedMultipliers[data.GrowthSpeedLevel]
	data.HairType = hairType
	data.GrowthStartTime = os.time()
	data.GrowthDuration = math.max(1, math.floor(baseDuration / multiplier))
	return true
end

function HairService.GetProgress(data)
	if not data.GrowthStartTime or not data.GrowthDuration or data.GrowthDuration <= 0 then return 0, 0 end
	local elapsed = math.max(0, os.time() - data.GrowthStartTime)
	local progress = math.clamp(elapsed / data.GrowthDuration, 0, 1)
	local stage
	if progress >= 1 then
		stage = 5
	else
		stage = math.clamp(math.floor(progress * 4) + 1, 1, 4)
	end
	return progress, stage
end

function HairService.IsReady(data)
	local progress = HairService.GetProgress(data)
	return data.GrowthStartTime ~= nil and progress >= 1
end

function HairService.Harvest(data)
	if not HairService.IsReady(data) then return false, 0 end
	local definition = HairConfig.Types[data.HairType]
	if not definition then return false, 0 end
	data.GrowthStartTime = nil
	data.GrowthDuration = nil
	data.HairType = nil
	return true, definition.Reward
end

return HairService
