-- // Client Network
-- // Path: ReplicatedStorage.Modules.Network 

local Network = {}
local Remote = script.Parent.Parent:WaitForChild("RemoteEvent")
local Function = script.Parent.Parent:WaitForChild("RemoteFunction")

local EventHandlers = {};
local FunctionHandlers = {};

Network.Send = function(self, Name, Arguments)
	Remote:FireServer(Name, Arguments)	
end

Network.Request = function(self, Name, Arguments)
	return Function:InvokeServer(Name, Arguments)
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

Remote.OnClientEvent:Connect(function(Name, Arguments)
	if EventHandlers[Name] then
		EventHandlers[Name](Arguments)
	end
end)

Function.OnClientInvoke = function(Name, Arguments)
	if FunctionHandlers[Name] then
		return FunctionHandlers[Name](Arguments)
	end
end

return Network 
