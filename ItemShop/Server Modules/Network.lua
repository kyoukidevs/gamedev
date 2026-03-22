-- // Server Network
-- // Path: ServerScriptService.Modules.Network

local Network = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:WaitForChild("RemoteEvent")
local Function = ReplicatedStorage:WaitForChild("RemoteFunction")

local EventHandlers = {};
local FunctionHandlers = {};

Network.Send = function(self, Client, Name, Arguments)
	Remote:FireClient(Client, Name, Arguments)	
end

Network.Request = function(self, Client, Name, Arguments)
	Function:InvokeClient(Client, Name, Arguments)
end

Network.BindEvent = function(Name, Callback)
	if EventHandlers[Name] then
		return 
	end

	EventHandlers[Name] = Callback 
end

Network.BindFunction = function(Name, Callback)
	if FunctionHandlers[Name] then
		return 
	end

	FunctionHandlers[Name] = Callback 
end

Remote.OnServerEvent:Connect(function(Client, Name, Arguments)
	if EventHandlers[Name] then
		pcall(EventHandlers[Name], Client, Arguments)
	end
end)

Function.OnServerInvoke = function(Client, Name, Arguments)
	if FunctionHandlers[Name] then
		pcall(FunctionHandlers[Name], Client, Arguments)
	end
end

return Network 
