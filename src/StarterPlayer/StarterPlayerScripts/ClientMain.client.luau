local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local harvestRemote = remotes:WaitForChild("HarvestHair")
local upgradeRemote = remotes:WaitForChild("BuyUpgrade")
local updateRemote = remotes:WaitForChild("UpdateGrowth")

local gui = Instance.new("ScreenGui")
gui.Name = "HairGrowerUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(290, 220)
panel.Position = UDim2.new(0, 16, 0, 16)
panel.BackgroundColor3 = Color3.fromRGB(32, 37, 44)
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local function makeLabel(name, y, height, text, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, -24, 0, height)
	label.Position = UDim2.fromOffset(12, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = size or 16
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = panel
	return label
end

local coinsLabel = makeLabel("Coins", 10, 26, "Coins: ...", 18)
local hairLabel = makeLabel("Hair", 42, 24, "Hair: Bald")
local progressLabel = makeLabel("Progress", 70, 24, "Growth: 0%")
local timerLabel = makeLabel("Timer", 98, 24, "Time: --")
local speedLabel = makeLabel("Speed", 126, 24, "Growth speed: 1x")

local function makeButton(name, y, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0.5, -18, 0, 36)
	button.Position = UDim2.new(0, 12, 0, y)
	button.BackgroundColor3 = Color3.fromRGB(73, 147, 99)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = text
	button.Visible = false
	button.Parent = panel
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 7)
	buttonCorner.Parent = button
	return button
end

local harvestButton = makeButton("Harvest", 170, "Harvest")
local upgradeButton = makeButton("Upgrade", 170, "Upgrade")
upgradeButton.Position = UDim2.new(0.5, 6, 0, 170)

harvestButton.Activated:Connect(function()
	harvestRemote:FireServer()
end)

upgradeButton.Activated:Connect(function()
	upgradeRemote:FireServer()
end)

updateRemote.OnClientEvent:Connect(function(state)
	coinsLabel.Text = "Coins: " .. tostring(state.Coins)
	hairLabel.Text = "Hair: " .. tostring(state.HairName)
	progressLabel.Text = string.format("Growth: %d%%", math.floor(state.Progress * 100 + 0.5))
	if state.HairName == "Bald" then
		timerLabel.Text = "Use your plot prompt to grow"
	elseif state.Ready then
		timerLabel.Text = "Ready to harvest!"
	else
		timerLabel.Text = "Time: " .. tostring(state.RemainingSeconds) .. "s"
	end
	speedLabel.Text = string.format("Growth speed: %gx (Level %d)", state.SpeedMultiplier, state.SpeedLevel)
	harvestButton.Visible = state.Ready
	upgradeButton.Visible = not state.MaximumSpeed
	if state.UpgradeCost then
		upgradeButton.Text = "Upgrade: " .. tostring(state.UpgradeCost) .. " coins"
	end
end)
