-- // Simple minigame, run from tsunami to win 

--#region Variables

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage =game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Players_Stats = DataStoreService:GetDataStore("Players_Stats")

local Map = ServerStorage:WaitForChild("Map")
local Indicator 
local Debug = false

do -- // Create lobby indicator
	local Part =  Instance.new("Part", Workspace)
	Part.Color = Color3.fromRGB(31,128,29)
	Part.Size = Vector3.new(20, 9, 2)
	Part.Position= Vector3.new(4, 4.5, -8)
	Part.Anchored = true 
	Part.CanCollide = true 
	Part.CFrame *= CFrame.Angles(0, math.pi, 0)
	
	local SurfaceGui = Instance.new("SurfaceGui", Part)
	SurfaceGui.Face = Enum.NormalId.Front
	SurfaceGui.AlwaysOnTop = false 
	SurfaceGui.ResetOnSpawn = false
	SurfaceGui.LightInfluence = 1
	SurfaceGui.PixelsPerStud = 50
	SurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	
	Indicator = Instance.new("TextLabel", SurfaceGui)
	Indicator.Size = UDim2.new(1,0,1,0)
	Indicator.Position = UDim2.new()
	Indicator.BackgroundTransparency = 1
	Indicator.FontFace = Font.fromName("Roboto", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	Indicator.TextColor3 = Color3.new(1,1,1)
	Indicator.TextStrokeTransparency = 0
	Indicator.TextScaled = true 
	Indicator.Text = ""
end

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

-- // Global Vars
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

Players.PlayerAdded:Connect(function(Client) -- // Init Client After Connecting
	task.wait(1.5)

	-- // Create leaderstats & wins
	local Leaderstats = Instance.new("Folder", Client)
	Leaderstats.Name = "leaderstats"

	local Wins = Instance.new("IntValue", Leaderstats)
	Wins.Name = "Wins"
	
	local PlayerStats = Players_Stats:GetAsync(Client.UserId)
	local WinsVal = PlayerStats and PlayerStats.Wins or 0
	
	if not (PlayerStats and PlayerStats.Wins) and Debug then
		warn("Could not get wins for "..Client.Name..", setting to 0")
	end
	
	Wins.Value = WinsVal

	-- // setmetatable for custom methods
	LoadedPlayers[Client] = setmetatable({
		Instance = Client,
		Character = Client.Character,
		Wins = Wins 
	}, LoadedPlayers)
end)

-- // Remove client data when he is removing
Players.PlayerRemoving:Connect(function(Client)
	if LoadedPlayers[Client] then
		local Wins = LoadedPlayers[Client].Wins 
		local Success, Error = pcall(function()
			Players_Stats:SetAsync(Client.UserId, {Wins = Wins.Value})
		end)
		
		if Debug then
			if not Success then
				warn("Error while saving Player_Stats: \n".. Error)
			else
				warn("Succesfully saved data for "..Client.Name)
			end
		end
		
		LoadedPlayers[Client]:Remove(true)
	end
	
	
end)
--#endregion

--#region LoadedPlayers Methods

LoadedPlayers.Spawn = function(self)
	-- // Checks for character ~= nil and theres map in workspace
	if self.Character and Globals.Map then 
		local SpawnPoint = Globals.Map:FindFirstChild("SpawnPart") -- // Find spawnpoint and pivot character to its cframe
		if SpawnPoint then 
			self.Character:PivotTo(SpawnPoint.CFrame)
		end

		PlayingPlayers[self.Instance] = true -- // Insert player to playingplayers

		self.Playing = true  -- // Set playerdata.playing boolean to true

		self.Humanoid.Died:Connect(function()
			self:Remove(false)
		end) -- // Remove from game after player died
	end
end

LoadedPlayers.Remove = function(self, DestroyData)
	if self.Playing and PlayingPlayers[self.Instance] then -- // Checks if player is playing
		PlayingPlayers[self.Instance] = nil 
		if self.Humanoid then -- // Checks for humanoid ~= nil and damaging him by 9e9
			self.Humanoid:TakeDamage(9e9)
		end
	end

	if DestroyData then
		LoadedPlayers[self.Instance] = nil -- // Destroying data if destroydata boolean is true
	end
end
--#endregion 

--#region Rounds Logic

local function CreateWave() -- // create wave func
	if not (Globals.GameStarted and Globals.Map) then
		return -- //return if game is not started and theres no map
	end

	Globals.LastWave = tick() -- // Update lastwave tick

	-- // Create wave part
	local GoalPart = Globals.Map.WinPart
	local StartPart = Globals.Map.WaveStart
	local Wave = Instance.new("Part", Globals.Map)
	Wave.CanCollide = false
	Wave.Anchored = true 
	--local Angle = math.atan2(GoalPart.Position.Z, GoalPart.Position.X)
	Wave.Size = Vector3.new(4, 50, 200)
	Wave.Position = StartPart.Position + Vector3.new(0, 15, 0)


	--Wave.CFrame = Wave.CFrame * CFrame.Angles(0, Angle, 0)

	-- // select random wave
	local random = math.random(1, 100)
	local PassedWaves = {}
	local SelectedWave 

	for Index, Value in Waves do
		if Value.Chance <= random then
			table.insert(PassedWaves, Index)
		end
	end

	if #PassedWaves > 0 then 
		SelectedWave = PassedWaves[math.random(1, #PassedWaves)] -- // random index from passedwaves table
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

	-- // fires signal when wave part getting touched
	Wave.Touched:Connect(function(HitInstance)
		if HitInstance and HitInstance.Parent:FindFirstChildOfClass("Humanoid") then
			-- // if theres a hitinstance and hitinstance.parent (Character) have a humanoid 
			local Player = LoadedPlayers[Players:GetPlayerFromCharacter(HitInstance.Parent)]

			if Player and Player.Playing and HitInstance.Position.Y > 8 then -- // for tall avatars check Y position
				Player:Remove(false) -- // remove player from game without destroying data
			end
		end
	end)
	Tween.Completed:Connect(function()
		Wave:Destroy() -- // destroy wave after tween completed
	end)
end

local function StartRound()
	-- // update glboals
	Globals.Map = Map:Clone()
	Globals.Map.Parent = Workspace 

	for Index, Client in LoadedPlayers do
		if type(Client) == "table" then -- // theres a functions in loadedplayers
			Client:Spawn() -- // spawn player 
		end
	end

	-- // update globals
	Globals.RoundStart = tick() 
	Globals.GameStarted = true 

	local WinPart = Globals.Map.WinPart 
	local Debounce = false 

	-- // debounce to not get multiple wins at once
	WinPart.Touched:Connect(function(HitInstance)
		if not Debounce and HitInstance and HitInstance.Parent:FindFirstChildOfClass("Humanoid") then -- // check for humanoid
			Debounce = true 
			local Player = LoadedPlayers[Players:GetPlayerFromCharacter(HitInstance.Parent)]

			if Player and Player.Wins then
				Player.Wins.Value += 1
				Player:Remove()
			end
			
			Debounce = false
		end
	end)
end

local function EndRound()
	-- // update globals
	Globals.LastWave = nil 
	Globals.RoundEnd = tick()
	Globals.GameStarted = false 

	-- // destroy map
	if Globals.Map then
		Globals.Map:Destroy() -- // Globals.Map will set to nil automatically
	end

	for Index, Value in PlayingPlayers do
		Value:Remove(false) -- // Remove player from game without destryoing data
	end
end
--#endregion

--#region Loop

RunService.Heartbeat:Connect(function()
	for Client, Data in LoadedPlayers do -- // players loop
		if type(Data) ~= "table" then 
			continue 
		end

		-- // update data
		Data.Character = Client.Character
		Data.Root = Data.Character and Data.Character:FindFirstChild("HumanoidRootPart")
		Data.Humanoid = Data.Character and Data.Character:FindFirstChildOfClass("Humanoid")
	end

	-- // update indicator text
	if Indicator then

		if not Globals.GameStarted then
			local Elapsed = tick() - Globals.RoundEnd
			local Left = math.max(0, math.floor(Globals.LobbyTime - Elapsed))
			Indicator.Text = "Intermission in: "..Left.." seconds"
		else
			local Elapsed = tick() - Globals.RoundStart
			Indicator.Text = "Round: "..math.floor(Globals.RoundTime - Elapsed).." seconds"
		end
	end

	-- // start round if game is not started and theres a round end tick and tick - globals.roundede > time in lobby
	if not Globals.GameStarted and Globals.RoundEnd and (tick() - Globals.RoundEnd >= Globals.LobbyTime) then
		StartRound()
	end

	local TotalPlaying = 0 

	for Index, Value in PlayingPlayers do
		TotalPlaying += 1 
	end

	-- // end round if game is started and totalplaying is 0 or theres a round start tick and tick - round start tick > round time
	if (Globals.GameStarted and TotalPlaying == 0) or Globals.RoundStart and tick() - Globals.RoundStart > Globals.RoundTime then
		EndRound()
	end

	-- // create waves
	if Globals.GameStarted then
		if not Globals.LastWave and tick() - Globals.RoundStart > 10 then -- // even if lastwave = nil wait 10 seconds
			CreateWave()
		end

		if Globals.LastWave and tick() - Globals.LastWave > 10 then
			CreateWave()
		end
	end
end)
--#endregion

-- // Save data for every player if game gettin shutdowned
game:BindToClose(function()
	for Client, Data in LoadedPlayers do
		if type(Data) == "table" then
			local Success, Error = pcall(function()
				Players_Stats:SetAsync(Client.UserId, {Wins = Data.Wins.Value})
			end)
			
			if Debug then
				if not Success then
					warn("Error while saving Player_Stats for "..Client.Name..": \n".. Error)
				else
					warn("Succesfully saved data for "..Client.Name)
				end
			end
		end
	end
end)
