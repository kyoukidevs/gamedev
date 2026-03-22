-- // Client script that controls every ui element
-- // Path: StarterPlayerScripts.UIController

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"))

local Client = script.Parent.Parent 
local PlayerGui = Client:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("Main")
local ToolGui = PlayerGui:WaitForChild("Tool")

task.wait()

-- // MainGui
local CashIndicator = MainGui.TextLabel
local Cash = Client:WaitForChild("leaderstats"):WaitForChild("Cash")
CashIndicator.Text = "Cash: "..Cash["Value"]
local Modules = MainGui.Modules 
local ItemShop = require(Modules.ItemShop)
local ShopFrame = MainGui.ShopFrame 
local TargetPart = Workspace:WaitForChild("Shop"):WaitForChild("OpenUI")
local CachedInstance

ItemShop:CreateButton("Burger")

TargetPart.Touched:Connect(function(HitInstance)
	if HitInstance.Parent and Players:GetPlayerFromCharacter(HitInstance.Parent) == Client and not CachedInstance then
		CachedInstance = HitInstance
		ShopFrame.Visible = true 
	end
end)

TargetPart.TouchEnded:Connect(function(HitInstance)
	if HitInstance == CachedInstance then
		ShopFrame.Visible = false 
		CachedInstance = nil 
	end
end)

Cash:GetPropertyChangedSignal("Value"):Connect(function()
	CashIndicator.Text = "Cash: "..Cash["Value"]
end)

-- // ToolGui 
ToolGui.TextButton.MouseButton1Click:Connect(function()
	Network:Send("Sell Item", {})
end)
