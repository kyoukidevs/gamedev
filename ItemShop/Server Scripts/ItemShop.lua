-- // Server script that handles itemshop remotes
-- // Path: ServerScriptService.Game.ItemShop

local ServerStorage = game:GetService("ServerStorage")

local Modules = game:GetService("ServerScriptService"):WaitForChild("Modules")
local SharedModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Items = require(SharedModules.Items)
local Network = require(Modules.Network)

Network.BindFunction("Buy Item", function(Client, Arguments)
	--print("0")
	local Cash = Client.leaderstats.Cash
	
	local ItemData = Items[Arguments[1]]
	local ItemInstance = ServerStorage.Items:FindFirstChild(Arguments[1])
	
	if not (ItemData and ItemInstance) then
		return "Unknown Error"
	end
	
	if Cash.Value > ItemData.Price then
		Cash.Value -= ItemData.Price 
		ItemInstance:Clone().Parent = Client.Backpack
	else
		return "Not Enough Cash"
	end
end)

Network.BindEvent("Sell Item", function(Client, Arguments)
	local Cash = Client.leaderstats.Cash
	local ItemInstance = Client.Character:FindFirstChildOfClass("Tool")
	
	if not ItemInstance then
		return
	end
	
	local ItemData = Items[ItemInstance.Name]
	
	if not ItemData then
		return
	end
	
	Cash.Value += ItemData.Price / 2
	ItemInstance:Destroy()
end)
