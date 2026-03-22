-- // UI Module that helps to create itemshop 
-- // Path: StarterGui.Main.Modules.ItemShop

local Shop = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Network = require(Modules.Network)
local Frame = script.Parent.Parent.ShopFrame

local Items = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Items"))

Shop.CreateButton = function(self, Name)
	local ItemData = Items[Name]
	
	if not ItemData then
		return 
	end
	
	local Price = ItemData.Price 
	local Image = ItemData.Image 
	
	local Button = script.Template:Clone()
	Button.Name = Name
	Button.Price.Text = Price
	Button.Image.Image = Image
	Button.Parent = Frame 
	
	Button.MouseButton1Click:Connect(function()
		local Error = Network:Request("Buy Item", {
			Name
		})
		
		if Error then
			local old = Button.Price.Text 
			local old2 = Button.Price.TextColor3 
			Button.Price.Text = Error 
			Button.Price.TextColor3 = Color3.new(1,0,0)
			
			task.wait(3)
			
			Button.Price.Text = old 
			Button.Price.TextColor3 = old2 
		end
	end)
end

return Shop 
