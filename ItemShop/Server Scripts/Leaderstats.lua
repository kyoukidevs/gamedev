-- // Leaderstats server script
-- // Path: ServerScriptService.Init.Leaderstats

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(Client)
	local Leaderstats = Instance.new("Folder", Client)
	Leaderstats.Name = "leaderstats"
	
	local Cash = Instance.new("IntValue", Leaderstats)
	Cash.Name = "Cash"
	Cash.Value = 0 
end)
