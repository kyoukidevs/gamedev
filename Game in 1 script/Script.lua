-- // Simple minigame, run from tsunami to win 

--#region Variables

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage =game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Map = ServerStorage:WaitForChild("Map")

local Waves = {
	["Classic"] = {
		Speed = 20,
		Chance = 65,
		Color = Color3.fromRGB(0, 255, 255)
	},
	["Fast"] = {
		Speed = 35,
		Chance = 25,
		Color = Color3.fromRGB(255, 170, 0)
	},
	["Sonic"] = {
		Speed = 75,
		Chance = 10,
		Color = Color3.fromRGB(255, 0, 0)
	}
}

local Globals = {
	GameStarted = false, 
	RoundStart = nil,
	RoundEnd = tick(),
	RoundTime = 120,
	LobbyTime = 10
}

local PlayingPlayers = {}
local LoadedPlayers = {}

LoadedPlayers.__index = LoadedPlayers -- // For MT
--#endregion

--#region Players Connections

Players.PlayerAdded:Connect(function(Client)
	task.wait(1.5)
	
	local Leaderstats = Instance.new("Folder", Client)
	Leaderstats.Name = "leaderstats"
	
	local Wins = Instance.new("IntValue", Leaderstats)
	Wins.Name = "Wins"
	Wins.Value = 0 
	
	LoadedPlayers[Client] = setmetatable({
		Instance = Client,
		Character = Client.Character,
		Wins = Wins 
	}, LoadedPlayers)
end)

Players.PlayerRemoving:Connect(function(Client)
	if LoadedPlayers[Client] then
		LoadedPlayers[Client]:Remove(true)
	end
end)
--#endregion

--#region LoadedPlayers Methods

LoadedPlayers.Spawn = function(self)
	if self.Character and Globals.Map then 
		local SpawnPoint = Globals.Map:FindFirstChild("SpawnPart")
		if SpawnPoint then 
			self.Character:PivotTo(SpawnPoint.CFrame)
		end
		
		PlayingPlayers[self.Instance] = true 
		
		self.Playing = true   
		
		self.Humanoid.Died:Connect(function()
			self:Remove(false)
		end)
	end
end

LoadedPlayers.Remove = function(self, DestroyData)
	if self.Playing and PlayingPlayers[self.Instance] then
		PlayingPlayers[self.Instance] = nil 
		if self.Humanoid then 
			self.Humanoid:TakeDamage(9e9)
		end
	end
	
	if DestroyData then 
		LoadedPlayers[self.Instance] = nil 
	end
end
--#endregion 

--#region Rounds Logic

local function CreateWave()
	if not (Globals.GameStarted and Globals.Map) then
		return 
	end
	
	Globals.LastWave = tick()
	
	local GoalPart = Globals.Map.WinPart
	local StartPart = Globals.Map.WaveStart
	local Wave = Instance.new("Part", Globals.Map)
	Wave.CanCollide = false
	Wave.Anchored = true 
	--local Angle = math.atan2(GoalPart.Position.Z, GoalPart.Position.X)
	Wave.Size = Vector3.new(4, 50, 200)
	Wave.Position = StartPart.Position + Vector3.new(0, 15, 0)
	
	 
	--Wave.CFrame = Wave.CFrame * CFrame.Angles(0, Angle, 0)
	
	local random = math.random(1, 100)
	local PassedWaves = {}
	local SelectedWave 
	
	for Index, Value in Waves do
		if Value.Chance <= random then
			table.insert(PassedWaves, Index)
		end
	end
	
	if #PassedWaves > 0 then 
		SelectedWave = PassedWaves[math.random(1, #PassedWaves)]
	else
		SelectedWave = "Classic"
	end
	
	local WaveData = Waves[SelectedWave]
	Wave.Color = WaveData.Color 
	
	local Speed = WaveData.Speed 
	local Distance = (Wave.Position - Globals.Map.WinPart.Position).Magnitude 
	local TimeToEnd = Distance / Speed 
	
	local Destination = Vector3.new(GoalPart.Position.X, Wave.Position.Y, GoalPart.Position.Z)
	local Tween = TweenService:Create(Wave, TweenInfo.new(TimeToEnd, Enum.EasingStyle.Quad), {
		Position = Destination
	})
	
	Tween:Play()
	
	Wave.Touched:Connect(function(HitInstance)
		if HitInstance and HitInstance.Parent:FindFirstChildOfClass("Humanoid") then
			local Player = LoadedPlayers[Players:GetPlayerFromCharacter(HitInstance.Parent)]
			
			if Player and Player.Playing and HitInstance.Position.Y > 8 then
				Player:Remove(false)
			end
		end
	end)
	Tween.Completed:Connect(function()
		Wave:Destroy()
	end)
end

local function StartRound()
	Globals.Map = Map:Clone()
	Globals.Map.Parent = Workspace 
	
	for Index, Value in LoadedPlayers do
		if type(Value) ~= "function" then 
			Value:Spawn()
		end
	end
	
	Globals.RoundStart = tick()
	Globals.GameStarted = true 
	
	local WinPart = Globals.Map.WinPart 
	local Debounce = false 
	
	WinPart.Touched:Connect(function(HitInstance)
		if not Debounce and HitInstance and HitInstance.Parent:FindFirstChildOfClass("Humanoid") then
			local Player = LoadedPlayers[Players:GetPlayerFromCharacter(HitInstance.Parent)]
			
			if Player and Player.Wins then
				Debounce = true 
				Player.Wins.Value += 1
				Player:Remove()
			end
		end
	end)
end

local function EndRound()
	Globals.LastWave = nil 
	Globals.RoundEnd = tick()
	Globals.GameStarted = false 
	
	if Globals.Map then
		Globals.Map:Destroy()
	end
	
	for Index, Value in PlayingPlayers do
		Value:Remove(false)
	end
end
--#endregion

--#region Loop

RunService.Heartbeat:Connect(function()
	for Index, Value in LoadedPlayers do
		if type(Value) ~= "table" then 
			continue 
		end
		
		Value.Character = Index.Character
		Value.Root = Value.Character and Value.Character:FindFirstChild("HumanoidRootPart")
		Value.Humanoid = Value.Character and Value.Character:FindFirstChildOfClass("Humanoid")
	end
	
	local Indicator = Workspace:FindFirstChild("Indicator")
	if Indicator then
		local Text = Indicator.SurfaceGui.TextLabel
		
		if Globals.GameBlocked and Globals.BlockedReason then
			Text.Text = Globals.BlockedReason 
		end
		
		if not Globals.GameStarted then
			local Elapsed = tick() - Globals.RoundEnd
			local Left = math.max(0, math.floor(Globals.LobbyTime - Elapsed))
			Text.Text = "Intermission in: "..Left.." seconds"
		else
			local Elapsed = tick() - Globals.RoundStart
			Text.Text = "Round: "..math.floor(Globals.RoundTime - Elapsed).." seconds"
		end
	end

	if not Globals.GameBlocked and not Globals.GameStarted and Globals.RoundEnd and (tick() - Globals.RoundEnd >= Globals.LobbyTime) then
		StartRound()
	end
	
	local TotalPlaying = 0 
	
	for Index, Value in PlayingPlayers do
		TotalPlaying += 1 
	end
	
	if (Globals.GameStarted and TotalPlaying == 0) or Globals.RoundStart and tick() - Globals.RoundStart > Globals.RoundTime then
		EndRound()
	end
	
	if Globals.GameStarted then
		if not Globals.LastWave and tick() - Globals.RoundStart > 10 then
			CreateWave()
		end
		
		if Globals.LastWave and tick() - Globals.LastWave > 10 then
			CreateWave()
		end
	end
end)
--#endregion
