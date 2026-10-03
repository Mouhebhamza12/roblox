local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HairConfig = require(game:GetService("ReplicatedStorage").Shared.HairConfig)
local Store = DataStoreService:GetDataStore("HairGrower_Phase1_v1")
local DataService = {}
local RETRIES = 3

local function retry(operation)
	local lastError
	for attempt = 1, RETRIES do
		local ok, result = pcall(operation)
		if ok then return true, result end
		lastError = result
		if attempt < RETRIES then task.wait(attempt) end
	end
	return false, lastError
end

local function makeDefaultData()
	return {
		Coins = 100,
		GrowthSpeedLevel = 1,
		GrowthStartTime = nil,
		GrowthDuration = nil,
		HairType = nil,
	}
end

function DataService.Load(player)
	local ok, data = retry(function()
		return Store:GetAsync("Player_" .. player.UserId)
	end)
	if not ok then
		warn("Could not load data for " .. player.Name .. ": " .. tostring(data))
		if RunService:IsStudio() then
			-- Studio may run without API access; never write these guessed defaults back.
			local defaultData = makeDefaultData()
			defaultData.DoNotSave = true
			return defaultData
		end
		return nil
	end
	if type(data) ~= "table" then
		return makeDefaultData()
	end
	local level = math.clamp(math.floor(tonumber(data.GrowthSpeedLevel) or 1), 1, 4)
	local startTime = tonumber(data.GrowthStartTime)
	local duration = tonumber(data.GrowthDuration)
	local hairType = type(data.HairType) == "string" and data.HairType or nil
	if not startTime or not duration or duration <= 0 or not hairType or not HairConfig.Types[hairType] then
		startTime = nil
		duration = nil
		hairType = nil
	end
	return {
		Coins = math.max(0, math.floor(tonumber(data.Coins) or 100)),
		GrowthSpeedLevel = level,
		GrowthStartTime = startTime,
		GrowthDuration = duration,
		HairType = hairType,
	}
end

function DataService.Save(player, data)
	if data.DoNotSave then
		return false
	end

	local payload = {
		Coins = data.Coins,
		GrowthSpeedLevel = data.GrowthSpeedLevel,
		GrowthStartTime = data.GrowthStartTime,
		GrowthDuration = data.GrowthDuration,
		HairType = data.HairType,
	}
	local ok, err = retry(function()
		return Store:UpdateAsync("Player_" .. player.UserId, function()
			return payload
		end)
	end)
	if not ok then warn("Could not save data for " .. player.Name .. ": " .. tostring(err)) end
	return ok
end

return DataService
