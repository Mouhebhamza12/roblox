local Players = game:GetService("Players")
local PlotService = {}
local plotsByPlayer = {}
local plotsFolder

local function createPlot(index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local base = Instance.new("Part")
	base.Name = "Ground"
	base.Size = Vector3.new(22, 1, 22)
	base.Position = Vector3.new((index - 1) * 30, 0, 0)
	base.Anchored = true
	base.Color = Color3.fromRGB(93, 170, 91)
	base.Parent = model
	local marker = Instance.new("Part")
	marker.Name = "HairPlaceholder"
	marker.Size = Vector3.new(2, 1, 2)
	marker.Position = base.Position + Vector3.new(0, 1, 0)
	marker.Anchored = true
	marker.CanCollide = false
	marker.Color = Color3.fromRGB(105, 72, 48)
	marker.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrowPrompt"
	prompt.ActionText = "Grow Hair"
	prompt.ObjectText = "Your Plot"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Enabled = false
	prompt.Parent = marker
	model.PrimaryPart = base
	model.Parent = plotsFolder
	return { Model = model, Marker = marker, Prompt = prompt, PromptConnection = nil, Owner = nil }
end

function PlotService.Initialize()
	plotsFolder = workspace:FindFirstChild("PlayerPlots")
	if plotsFolder then plotsFolder:Destroy() end
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "PlayerPlots"
	plotsFolder.Parent = workspace
	local plots = {}
	for index = 1, math.max(1, #Players:GetPlayers() + 8) do
		plots[index] = createPlot(index)
	end
	return plots
end

function PlotService.Assign(player, plots)
	for _, plot in ipairs(plots) do
		if not plot.Owner then
			plot.Owner = player
			plotsByPlayer[player] = plot
			plot.Model.Name = "Plot_" .. player.UserId
			return plot
		end
	end
	local plot = createPlot(#plots + 1)
	table.insert(plots, plot)
	plot.Owner = player
	plotsByPlayer[player] = plot
	plot.Model.Name = "Plot_" .. player.UserId
	return plot
end

function PlotService.Get(player)
	return plotsByPlayer[player]
end

function PlotService.Owns(player, plot)
	return plot ~= nil and plotsByPlayer[player] == plot and plot.Owner == player
end

function PlotService.SetPromptConnection(plot, connection)
	if not plot then return end
	if plot.PromptConnection then
		plot.PromptConnection:Disconnect()
	end
	plot.PromptConnection = connection
end

function PlotService.Release(player)
	local plot = plotsByPlayer[player]
	if plot then
		if plot.PromptConnection then
			plot.PromptConnection:Disconnect()
			plot.PromptConnection = nil
		end
		plot.Owner = nil
		plot.Model.Name = "UnclaimedPlot"
		PlotService.SetStage(plot, 0, nil)
		plotsByPlayer[player] = nil
	end
end

function PlotService.SetStage(plot, stage, hairType)
	if not plot then return end
	local heights = { 1, 1.5, 2.5, 3.5, 5, 6.5 }
	local height = heights[math.clamp(stage, 0, 5) + 1]
	plot.Marker.Size = Vector3.new(2 + stage * 0.45, height, 2 + stage * 0.45)
	plot.Marker.Position = plot.Model.Ground.Position + Vector3.new(0, 0.5 + height / 2, 0)
	local definition = hairType and require(game:GetService("ReplicatedStorage").Shared.HairConfig).Types[hairType]
	plot.Marker.Color = definition and definition.Color or Color3.fromRGB(105, 72, 48)
	local isBald = stage == 0
	plot.Prompt.Enabled = isBald and plot.Owner ~= nil
	plot.Prompt.ActionText = isBald and "Grow Hair" or "Growing..."
end

return PlotService
