-- // Server script for handling admin remotes
-- // Path: ServerScriptService.Game.AdminRemotes
local Modules = game:GetService("ServerScriptService"):WaitForChild("Modules")
local SharedModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Network = require(Modules.Network)
local Admins = require(SharedModules.Admins)

Network.BindEvent("Add Cash", function(Client, Arguments)
	local Amount = Arguments[1];
	
	if not table.find(Admins, Client.UserId) then
		return 
	end
	
	local Leaderstats = Client:WaitForChild("leaderstats", 3)
	
	if not Leaderstats then
		return 
	end
	
	local Cash = Leaderstats:FindFirstChild("Cash")
	
	if not Cash then
		return 
	end
	
	Cash.Value += Amount 
end)
