--[[
Just a movement client script.
Total code lines: ~380
]]

-- variables
local player = script.Parent.Parent -- script >> playerscripts >> player
local camera = workspace.CurrentCamera

-- services
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

-- needed for raycasting
local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {camera, player}

-- create screengui for movement UI elements
local movementGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui", 5))
movementGui.IgnoreGuiInset = true 
movementGui.ResetOnSpawn = false 
movementGui.Name = "MovementGui"

-- utility functions
local function checkWalls(part, distance)
	-- return nil if not part or part not an instance or part is not from basepart family 
	if not (part and typeof(part) == "Instance" and part:IsA("BasePart")) then return nil end 
	
	local direction = part.CFrame.lookVector * distance -- forward direction of part * scan distance
	local origin = part.Position
	
	local raycast = workspace:Raycast(origin, direction, rayParams)
	
	return raycast and raycast.Instance -- return raycast.instance if raycast table is exist
end

local function nextKeyCode(ignore)
	local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	if ignore then 
		chars = chars:gsub(ignore.Name, "") -- remove ignored keycode.name from chars string
	end
	
	local index = math.random(1, #chars) -- select one random letter from chars string
	local letter = chars:sub(index, index) -- remove other letters with string.sub

	return Enum.KeyCode[letter]  -- return letter converted to keycode
end

-- springs
local springs = {}

springs.__index = springs -- if theres no method in spring object, it will look for it in springs table

function springs.create(target : number)
	target = target or 0 
	
	local spring = {
		target = target,
		position = target,
		velocity = 0
	}
	
	return setmetatable(spring, springs) -- setmetatable to use custom methods on spring object
end

function springs:update(dt : number)
	local deltaRatio = dt / (1 / 60) -- 60 fps
	
	local positionDelta = self.position - self.target
	local force = (-0.025 * positionDelta) - (0.3 * self.velocity)
	
	self.velocity += force * deltaRatio -- increase velocity by force & deltaRatio
	self.position += self.velocity * deltaRatio -- move position
	
	return self.position -- return position if needed
end

function springs:impulse(amount : number)
	self.velocity += amount -- just increase velocity
end

-- movement controller
local config = {
	dashRange = 10,
	dashSpeed = 125,
	dashCooldown = 2.5,
	climbStepRange = 5,
	maxClimbDistance = 5,
	maxWallDamage = 90,
	sprintSpeed = 20
} -- global movement config

local keys = {
	["Dash"] = Enum.KeyCode.Q,
	["Sprint"] = Enum.KeyCode.LeftShift
} -- keybinds for actions

local validMoveStates = {"Idle", "Moving", "Dash", "Jumping", "Climbing", "Injured"}
local controller = {
	object = nil 
}

controller.__index = controller -- if theres no method in controller.object, it will look for it in controller table

local function attachClimbModel(model) -- utility
	if not (model and typeof(model) == "Instance" and model:IsA("Model")) then return end 
	
	local interactPart = model:FindFirstChild("Interact")
	local targetPart = model:FindFirstChild("ClimbPart")
	local destinationPart = model:FindFirstChild("Destination")
	if not (interactPart and targetPart and destinationPart) then return end -- if needed parts didnt found in model, return 
	
	local proximityPrompt = Instance.new("ProximityPrompt", interactPart) -- create proximity prompt in interaction part
	proximityPrompt.ActionText = "Climb"
	proximityPrompt.MaxActivationDistance = config.maxClimbDistance
	
	proximityPrompt.Triggered:Connect(function(_) -- this signal triggers when someone interacted with proximityprompt
		if not controller.object then return end 
		local angle = math.atan2(targetPart.Position.Z, targetPart.Position.X) -- get only x,z angle using math.atan2
		controller.object.root.CFrame *= CFrame.Angles(0, angle, 0) -- rotate root to this angle
		controller.object.actions.startClimb(controller.object, targetPart, destinationPart ) -- try to start climbing
		
		--[[if error then
			local text = error[1]
			local color = error[2]
			makeError(text, color)
		end]]
	end)
end

function controller.new(object : Player)
	local character = object.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	
	if not (humanoid and root) then -- return if theres no humanoid or root
		return 
	end
	
	local self = setmetatable({
		connections = {},
		actions = {},
		collisions = {},
		springs = {
			x = springs.create(),
			y = springs.create()
		},
		pointer = object,
		character = character,
		humanoid = humanoid,
		root = root,
		sprinting = false,
		lastDash = tick(),
		health = humanoid.Health,
		maxHealth = humanoid.MaxHealth,
		moveState = "Idle"
	}, controller) -- setmetatable for custom methods
	
	function self.collisions.wallHit(object, speedPercent)
		local oldState = object.moveState -- cache old character movestate
		local success = object:changeState("Injured") 
		if not success then return end 

		local walkSpeed = object.humanoid.WalkSpeed 
		local minSpeed = walkSpeed / 10 
		local damage = config.maxWallDamage * speedPercent
		local baseSpeed = math.clamp(object.humanoid.WalkSpeed / 10, minSpeed, walkSpeed) -- clamp too prevent very high walkspeed

		object.humanoid:TakeDamage(damage) -- apply damage to humanoid 
		object.humanoid.WalkSpeed = baseSpeed / speedPercent -- apply calculated walkspeed
		
		local blur = Instance.new("BlurEffect", lighting) -- create blur effect to player's screen
		local blurSize = 56 * speedPercent -- blur size is based on speedpercent 
		local camX = object.springs.x
		local camY = object.springs.y
		-- update camera springs
		camX:impulse(0.8 * speedPercent)
		camY:impulse(0.6 * speedPercent)
		
		-- update blur size
		blur.Size = blurSize 
		tweenService:Create(humanoid, TweenInfo.new(8 * speedPercent, Enum.EasingStyle.Linear), {WalkSpeed = baseSpeed * 10}):Play()
		local tween = tweenService:Create(blur, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
			Size = 0 
		})

		tween:Play()
	
		-- use rbxscriptsignal:connect because we dont want to block current thread for 3+ seconds
		tween.Completed:Connect(function()
			blur:Destroy()
			object:changeState(oldState)
		end)
	end
	
	--function self.collisions.fallDamage(object, height)
		
	--end
	
	function self.actions.startClimb(object, part, destination)
		local topPosition = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
		local delta = (object.root.Position - topPosition).magnitude
		local progress = 0 
		local maxProgress = math.floor(delta / config.climbStepRange)
		
		if maxProgress > 10 then -- return if maxprogress is 10 (very high)
			return --{"Too High!", Color3.new(1,0,0)}
		end
		
		local success = object:changeState("Climbing")
		
		if not success then -- if state is not changed then return 
			return
		end
		
		-- create ui elements
		local background = Instance.new("Frame", movementGui)
		background.Size = UDim2.new(1, 0, 1, 0)
		background.ZIndex = -1
		background.BackgroundColor3 = Color3.new()
		background.BackgroundTransparency = 0.5
		
		local progressBar = Instance.new("Frame", background)
		progressBar.Size = UDim2.new(0, 200, 0, 50)
		progressBar.BackgroundColor3 = Color3.new()
		progressBar.Position = UDim2.new(0.5, 0, 0.9, 0)
		progressBar.BorderSizePixel = 0 
		
		local barFill = Instance.new("Frame", progressBar)
		barFill.Size = UDim2.new(0, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.new(0, 1, 0)
		barFill.BackgroundTransparency = 0 
		barFill.BorderSizePixel = 0
		
		local progressText = Instance.new("TextLabel", progressBar)
		progressText.Size = UDim2.new(1, 0, 1, 0)
		progressText.TextXAlignment = Enum.TextXAlignment.Center
		progressText.Text = progress.."/"..maxProgress
		progressText.TextColor3 = Color3.new(1,1,1)
		progressText.TextStrokeTransparency = 0
		progressText.Font = Enum.Font.ArimoBold
		progressText.BackgroundTransparency = 1
		progressText.TextScaled = true
		
		local function renderKeybind(keycode) -- render keybind circleeee
			local time = 5 - progress / 5
			local str = tostring(keycode):gsub("Enum.KeyCode.", "")
			local circle = Instance.new("TextLabel", background)
			circle.ZIndex = 2
			circle.BackgroundColor3 = Color3.new(0, 0.7, 0)
			circle.Text = str
			circle.TextScaled = true 
			circle.Font = Enum.Font.GothamBold
			circle.TextColor3 = Color3.new(1,1,1)
			circle.TextStrokeTransparency = 0 
			circle.Size = UDim2.new(0, 75, 0, 75)
			
			circle.Position = UDim2.new(math.random(3, 8) / 10, 0, math.random(3, 8) / 10, 0)
			
			Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0) -- dont need variable for it
			return circle -- return circle to do manipualtions with it outside of this function
		end
		
		local root = object.root
		local humanoid = object.humanoid 
		root.Anchored = true -- anchor root 
		humanoid.PlatformStand = true -- remove freefall animation
		local connection, debounce -- variables that will be used multiple times
		
		local function handleKeybind(keycode) -- main keybind function
			local circle = renderKeybind(keycode) -- render keybind circle
			
			connection = userInputService.InputBegan:Connect(function(input, fromGame) -- connect rbxscriptsignal
				if input.KeyCode == keycode and not (fromGame and debounce) then
					debounce = true -- set debounce to prevent spamming & getting many progress at once
					progress += 1 -- increase progress
					-- update progress bar
					progressText.Text = progress.."/"..maxProgress
					local percent = progress / maxProgress
					barFill:TweenSize(UDim2.new(percent, 0, 1, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.15)
					
					-- update root cframe
					root.CFrame = root.CFrame * CFrame.new(0, config.climbStepRange, 0)
					
					local tween = tweenService:Create(circle, TweenInfo.new(0.15, Enum.EasingStyle.Circular), {
						BackgroundTransparency = 1,
						TextTransparency = 1
					})
					tween:Play()
					tween.Completed:Wait()
					
					-- remove connection
					connection:Disconnect()
					connection = nil 
					
					if progress >= maxProgress then
						-- if object reached max progress then finish climbing
						object:changeState("Idle") -- default state
						local finalPos = destination.Position + Vector3.new(0, root.Size.Y, 0)
						local finalCF = CFrame.new(finalPos, finalPos + root.CFrame.lookVector)
						local tween = tweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Circular), {
							CFrame = finalCF 
						})
						tween:Play()
						tween.Completed:Connect(function()
							root.Anchored = false
							humanoid.PlatformStand = false
							background:Destroy()
						end)
						
						return 
					end
					
					handleKeybind(nextKeyCode(keycode)) -- continue keybinds if not returned
				end
			end)
		end
		
		handleKeybind(nextKeyCode()) -- start keybinds game 
	end
	
	function self.actions.dash(object) -- dash function
		if tick() - object.lastDash < config.dashCooldown then return end  -- check for cooldown 
		if object.moveState ~= "Moving" then return end  -- prevent dash while idle or climbing or other 
		
		-- initialization before dashing
		local direction = object.root and object.root.CFrame.lookVector * config.dashRange
		if not direction then return end 

		local success = object:changeState("Dash")
		if not success then return end 
		
		object.lastDash = tick()
		
		local speed = config.dashSpeed 
		
		local root = object.root
		local humanoid = object.humanoid 
		local oldWalkSpeed = humanoid.WalkSpeed
		
		humanoid.WalkSpeed = 0.01
		
		local connection -- define variable before connecting to disconnect it inside connection
		connection = runService.Heartbeat:Connect(function(delta)
			local distance = speed * delta 
			object.root.CFrame *= CFrame.new(0, 0, -distance)
			speed -= 4

			local wall = checkWalls(object.root, 5) -- if theres a wall infront of character then start wall collision
			if wall then
				humanoid.WalkSpeed = oldWalkSpeed
				
				local speedPercent = speed / config.dashSpeed 
				object.collisions.wallHit(object, speedPercent)
				
				--tweenService:Create(humanoid, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {WalkSpeed = oldWalkSpeed}):Play()
				connection:Disconnect()
				connection= nil 
			end

			-- stop dashing when speed is <= 1
			if speed <= 1  then
				tweenService:Create(humanoid, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {WalkSpeed = oldWalkSpeed}):Play()
				connection:Disconnect()
				connection = nil 
			end
		end)
	end
	
	-- return self & set controller.object
	controller["object"] = self 
	return self 
end

-- remove object
function controller:remove()
	if controller.object and controller.object == self then
		controller.object = nil 
	end	
end

-- change state with checks
function controller:changeState(name)
	-- if state is already the same or state is not valid then return false 
	if not table.find(validMoveStates, name) or self.moveState == name then return false end 
	
	self.moveState = name 
	
	-- return true if theres no errors
	return true 	
end

task.wait(2)

controller.new(player)

-- client input controller
userInputService.InputBegan:Connect(function(input, fromGame)
	if fromGame then return end
	
	local dashKey = keys["Dash"]
	local sprintKey = keys["Sprint"]
	local object = controller.object
	
	if (input.KeyCode == dashKey or input.UserInputType == dashKey) and object then
		object.actions.dash(object)
	end
	
	if (input.KeyCode == sprintKey or input.UserInputType == sprintKey) and object and object.moveState == "Moving" then
		object.sprinting = true 
		tweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {
			FieldOfView = 80 	
		}):Play()
	end
end)

userInputService.InputEnded:Connect(function(input, fromGame)
	local sprintKey = keys["Sprint"]
	local object = controller.object
	
	if (input.KeyCode == sprintKey or input.UserInputType == sprintKey) and object and object.moveState == "Moving" then
		print("unsprint")
		controller.object.sprinting = false
		tweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {
			FieldOfView = 70	
		}):Play()
	end
end)

-- loops

-- physics
runService.Heartbeat:Connect(function(delta)
	debug.profilebegin("character physics step") -- start microprofiler label for debugging
	camera = workspace.CurrentCamera -- update camera
	
	if controller.object then
		local object = controller.object
		local moveState = object.moveState
		local isMoving = (moveState ~= "Climbing" and moveState ~= "Dash") and (userInputService:IsKeyDown(Enum.KeyCode.W) or userInputService:IsKeyDown(Enum.KeyCode.S) or userInputService:IsKeyDown(Enum.KeyCode.D) or userInputService:IsKeyDown(Enum.KeyCode.A))
		
		-- update movestate
		if not isMoving then
			object:changeState("Idle")
			
			if object.sprinting then
				object.sprinting = false 
			end
		else
			object:changeState("Moving")
		end
		
		object.humanoid.WalkSpeed = object.sprinting and config.sprintSpeed or 16 -- if player is sprinting then set walkspeed to config.sprintspeed, else set it to 16
	end
	debug.profileend() -- end microprofiler label 
end)

-- render
local baseCF -- base camera cframe
runService:BindToRenderStep("Render Physics", Enum.RenderPriority.Camera.Value + 1, function(delta)
	debug.profilebegin("render physics step") -- start microprofiler label for debug ging 
	if controller.object then -- check if controller.object is exist
		local object = controller.object
		
		baseCF = camera.CFrame -- cache camera.CFrame 
		
		-- update object springs
		local x = object.springs.x:update(delta) 
		local y = object.springs.y:update(delta)
		
		camera.CFrame = baseCF * CFrame.new(x, y, 0) -- update camera cframe 
	end
	
	debug.profileend()
end)

attachClimbModel(workspace.Climb) -- attach model in workspace for climbing

-- character connections
player.CharacterAdded:Connect(function(_)
	controller.new(player)
end)

player.CharacterRemoving:Connect(function(_)
	if controller.object then 
		controller.object:remove()
	end
end)

-- just cooldown indicators
local cooldowns = Instance.new("TextLabel", movementGui)
cooldowns.BackgroundTransparency = 1
cooldowns.TextColor3 = Color3.new(1,1,1)
cooldowns.FontFace= Font.fromName("Nunito", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
cooldowns.TextScaled = true
cooldowns.Text = "Cooldowns:"
cooldowns.Size = UDim2.new(0, 211, 0, 50)
cooldowns.Position= UDim2.new(0,0, 0.585, 0)
cooldowns.BorderSizePixel = 0 

local dash = Instance.new("TextLabel", movementGui)
dash.BackgroundTransparency = 1
dash.TextColor3 = Color3.new(0, 1, 0)
dash.FontFace = cooldowns.FontFace 
dash.TextScaled = true 
dash.Size = cooldowns.Size 
dash.Position = cooldowns.Position + UDim2.fromOffset(0, cooldowns.Size.Y.Offset + 10)
dash.BorderSizePixel = 0 
dash.Text = "Dash: 2.5 seconds"
dash.Visible = false 

-- thread 
while task.wait(0.05) do
	if controller.object then
		local elapsed = tick() - controller.object.lastDash
		if elapsed < 2.5 then
			dash.Visible = true
			local remaining = 2.5 - elapsed
			dash.Text = string.format("Dash: %.1f seconds", remaining)
		else
			dash.Visible = false
		end
	else
		dash.Visible = false
	end
end
