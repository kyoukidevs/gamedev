-- // Script to add cash by clicking on a button
-- // Path: StarterGui.Main.TextButton.LocalScript
local network = require(game:GetService("ReplicatedStorage").Modules.Network)

script.Parent.MouseButton1Click:Connect(function()	
	network:Send("Add Cash", {
		100
	})
end)
