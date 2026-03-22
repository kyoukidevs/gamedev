-- // Client script that controls client tools
-- // Path: StarterPlayerScripts.ToolContoller

local Client = script.Parent.Parent
local Character 
local PlayerGui = Client:WaitForChild("PlayerGui") 
local ToolGui = PlayerGui:WaitForChild("Tool")

while task.wait() do
	if Client.Character then
		Character = Client.Character 
		break 
	end
end

task.wait(1.5)

Character.ChildAdded:Connect(function(Value)
	if Value:IsA('Tool') then
		ToolGui.Enabled = true 
	end
end)

Character.ChildRemoved:Connect(function(Value)
	if Value:IsA('Tool') then
		ToolGui.Enabled = false 
	end
end)
