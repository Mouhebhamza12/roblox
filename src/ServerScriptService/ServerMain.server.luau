local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local HairService = require(Services.HairService)
local CurrencyService = require(Services.CurrencyService)
local UpgradeService = require(Services.UpgradeService)
local HairConfig = require(ReplicatedStorage.Shared.HairConfig)

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function getRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local harvestRemote = getRemote("HarvestHair", "RemoteEvent")
local upgradeRemote = getRemote("BuyUpgrade", "RemoteEvent")
local updateRemote = getRemote("UpdateGrowth", "RemoteEvent")
local plots = PlotService.Initialize()
local playerData = {}

local function publish(player)
	local data = playerData[player]
	if not data then return end
	local progress, stage = HairService.GetProgress(data)
	local typeDefinition = data.HairType and HairConfig.Types[data.HairType]
	local cost = UpgradeService.GetNextCost(data)
	updateRemote:FireClient(player, {
		Coins = data.Coins,
		HairName = typeDefinition and typeDefinition.DisplayName or "Bald",
		Progress = progress,
		Ready = HairService.IsReady(data),
		RemainingSeconds = data.GrowthStartTime and math.max(0, data.GrowthDuration - (os.time() - data.GrowthStartTime)) or 0,
		SpeedLevel = data.GrowthSpeedLevel,
		SpeedMultiplier = HairConfig.SpeedMultipliers[data.GrowthSpeedLevel],
		UpgradeCost = cost,
		MaximumSpeed = cost == nil,
	})
	local plot = PlotService.Get(player)
	PlotService.SetStage(plot, data.GrowthStartTime and stage or 0, data.HairType)
end

local function onPlayerAdded(player)
	local data = DataService.Load(player)
	if player.Parent ~= Players then return end
	if not data then
		-- Keep the player locked until data can be safely loaded; never save guessed defaults.
		playerData[player] = nil
		player:Kick("Your data could not be loaded. Please rejoin in a moment.")
		return
	end
	playerData[player] = data
	local plot = PlotService.Assign(player, plots)
	local function moveCharacterToPlot(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and PlotService.Owns(player, plot) then
			root.CFrame = plot.Model.Ground.CFrame + Vector3.new(0, 4, 7)
		end
	end
	player.CharacterAdded:Connect(moveCharacterToPlot)
	if player.Character then task.spawn(moveCharacterToPlot, player.Character) end
	local promptConnection = plot.Prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player or not PlotService.Owns(triggeringPlayer, plot) then return end
		local currentData = playerData[triggeringPlayer]
		local character = triggeringPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not currentData or not plot.Prompt.Enabled or not root then return end
		if (root.Position - plot.Marker.Position).Magnitude > 12 then return end
		if HairService.Start(currentData) then publish(triggeringPlayer) end
	end)
	PlotService.SetPromptConnection(plot, promptConnection)
	publish(player)
end

harvestRemote.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	local plot = PlotService.Get(player)
	if not data or not PlotService.Owns(player, plot) then return end
	local success, reward = HairService.Harvest(data)
	if not success then return end
	CurrencyService.Add(data, reward)
	PlotService.SetStage(plot, 0, nil)
	publish(player)
end)

upgradeRemote.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	local plot = PlotService.Get(player)
	if not data or not PlotService.Owns(player, plot) then return end
	local success = UpgradeService.Buy(data)
	if success then publish(player) end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

Players.PlayerRemoving:Connect(function(player)
	local data = playerData[player]
	if data then DataService.Save(player, data) end
	playerData[player] = nil
	PlotService.Release(player)
end)

task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(playerData) do
			if player.Parent == Players then publish(player) end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for player, data in pairs(playerData) do
			if player.Parent == Players then DataService.Save(player, data) end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player, data in pairs(playerData) do
		pending += 1
		task.spawn(function()
			DataService.Save(player, data)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
