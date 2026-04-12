--[[ 
Just a movement client script

Features:
sprinting
dashing
wall collision damage/effects
climbing interaction
camera feedback
simple movement UI

This script is designed to run on the client because of movement,
camera effects, and input response that impossible to do on server.
]]

-- variables
local player = script.Parent.Parent -- localplayer reference from playerscripts
local camera = workspace.CurrentCamera

-- services
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

-- raycast settings for wall checks
-- ignore the camera and character so collision checks only detect nearby world geometry
local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {camera, player}

-- container for UI elements
local movementGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui", 5))
movementGui.IgnoreGuiInset = true
movementGui.ResetOnSpawn = false
movementGui.Name = "MovementGui"

-- utility functions
local function checkWalls(part, distance)
	-- validate arguments before casting to avoid runtime errors
	if not (part and typeof(part) == "Instance" and part:IsA("BasePart")) then
		return nil
	end

	-- cast forward from the part to detect walls in front of the player
	local direction = part.CFrame.LookVector * distance
	local origin = part.Position
	local raycast = workspace:Raycast(origin, direction, rayParams)

	return raycast and raycast.Instance
end

local function nextKeyCode(ignore)
	-- generate a random movement prompt key optionally excluding the previous one
	local chars = "ABCDFGHJKLMNPQRSTUVWXYZ"

	if ignore then
		chars = chars:gsub(ignore.Name, "")
	end

	local index = math.random(1, #chars)
	local letter = chars:sub(index, index)

	return Enum.KeyCode[letter]
end

-- spring helper for camera movement
local springs = {}
springs.__index = springs

function springs.create(target : number)
	target = target or 0

	local spring = {
		target = target,
		position = target,
		velocity = 0
	}

	return setmetatable(spring, springs)
end

function springs:update(dt : number)
	-- normalize movement so the spring behaves consistently across frame rates
	local deltaRatio = dt / (1 / 60)

	local positionDelta = self.position - self.target
	local force = (-0.025 * positionDelta) - (0.3 * self.velocity)

	self.velocity += force * deltaRatio
	self.position += self.velocity * deltaRatio

	return self.position
end

function springs:impulse(amount : number)
	-- add sudden camera movement when the character gets hit
	self.velocity += amount
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
}

local keys = {
	["Dash"] = Enum.KeyCode.Q,
	["Sprint"] = Enum.KeyCode.LeftShift
}

local validMoveStates = {"Idle", "Moving", "Dash", "Jumping", "Climbing", "Injured"}
local controller = {
	object = nil
}

controller.__index = controller

local function attachClimbModel(model)
	-- attach a prompt only to valid climb models
	if not (model and typeof(model) == "Instance" and model:IsA("Model")) then
		return
	end

	local interactPart = model:FindFirstChild("Interact")
	local targetPart = model:FindFirstChild("ClimbPart")
	local destinationPart = model:FindFirstChild("Destination")

	-- skip invalid climb setups instead of failing at runtime
	if not (interactPart and targetPart and destinationPart) then
		return
	end

	local proximityPrompt = Instance.new("ProximityPrompt", interactPart)
	proximityPrompt.ActionText = "Climb"
	proximityPrompt.MaxActivationDistance = config.maxClimbDistance

	proximityPrompt.Triggered:Connect(function(_)
		if not controller.object then
			return
		end

		-- rotate the character toward the climb surface before starting the climb game
		local root = controller.object.root
		local offset = targetPart.Position - root.Position
		local angle = math.atan2(offset.X, -offset.Z)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, -angle, 0)

		controller.object.actions.startClimb(controller.object, targetPart, destinationPart)
	end)
end

function controller.new(object : Player)
	local character = object.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart

	if not (humanoid and root) then
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
	}, controller)

	function self.collisions.wallHit(object, speedPercent)
		-- cache old movestate to revert it and temporarily switch state to injured 
		local oldState = object.moveState
		local success = object:changeState("Injured")
		if not success then
			return
		end

		-- scale damage and movement penalty based on dash impact speed
		local walkSpeed = object.humanoid.WalkSpeed
		local minSpeed = walkSpeed / 10
		local damage = config.maxWallDamage * speedPercent
		local baseSpeed = math.clamp(object.humanoid.WalkSpeed / 10, minSpeed, walkSpeed)

		object.humanoid:TakeDamage(damage)
		object.humanoid.WalkSpeed = baseSpeed / speedPercent

		-- screen feedback for a hard impact
		local blur = Instance.new("BlurEffect", lighting)
		local blurSize = 56 * speedPercent
		local camX = object.springs.x
		local camY = object.springs.y

		camX:impulse(0.8 * speedPercent)
		camY:impulse(0.6 * speedPercent)

		blur.Size = blurSize

		-- restore walk speed after the hit effect ends
		tweenService:Create(humanoid, TweenInfo.new(8 * speedPercent, Enum.EasingStyle.Linear), {
			WalkSpeed = baseSpeed * 10
		}):Play()

		local tween = tweenService:Create(blur, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
			Size = 0
		})

		tween:Play()

		tween.Completed:Connect(function()
			blur:Destroy()
			object:changeState(oldState)
		end)
	end

	function self.actions.startClimb(object, part, destination)
		-- determine how many climb steps are needed to reach the top
		local topPosition = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
		local delta = (object.root.Position - topPosition).magnitude
		local progress = 0
		local maxProgress = math.floor(delta / config.climbStepRange)

		-- prevent climbing objects that are too high
		if maxProgress > 10 then
			return
		end

		local success = object:changeState("Climbing")
		if not success then
			return
		end

		-- fullscreen overlay while climbing
		local background = Instance.new("Frame", movementGui)
		background.Size = UDim2.new(1, 0, 1, 0)
		background.ZIndex = -1
		background.BackgroundColor3 = Color3.new()
		background.BackgroundTransparency = 0.5

		-- progress panel at the bottom of the screen
		local progressBar = Instance.new("Frame", background)
		progressBar.Size = UDim2.new(0, 200, 0, 50)
		progressBar.BackgroundColor3 = Color3.new()
		progressBar.Position = UDim2.new(0.5, 0, 0.9, 0)
		progressBar.BorderSizePixel = 0

		-- fill element for climb progress
		local barFill = Instance.new("Frame", progressBar)
		barFill.Size = UDim2.new(0, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.new(0, 1, 0)
		barFill.BackgroundTransparency = 0
		barFill.BorderSizePixel = 0

		local progressText = Instance.new("TextLabel", progressBar)
		progressText.Size = UDim2.new(1, 0, 1, 0)
		progressText.TextXAlignment = Enum.TextXAlignment.Center
		progressText.Text = progress .. "/" .. maxProgress
		progressText.TextColor3 = Color3.new(1,1,1)
		progressText.TextStrokeTransparency = 0
		progressText.Font = Enum.Font.ArimoBold
		progressText.BackgroundTransparency = 1
		progressText.TextScaled = true

		-- create a circular key prompt for the next required input
		local function renderKeybind(keycode)
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

			Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

			return circle
		end

		local root = object.root
		local humanoid = object.humanoid
		root.Anchored = true
		humanoid.PlatformStand = true

		local connection, debounce

		local function handleKeybind(keycode)
			-- show the requested key and wait for the matching input
			local circle = renderKeybind(keycode)

			connection = userInputService.InputBegan:Connect(function(input, fromGame)
				if input.KeyCode == keycode and not (fromGame and debounce) then
					debounce = true
					progress += 1
					progressText.Text = progress .. "/" .. maxProgress

					local percent = progress / maxProgress
					barFill:TweenSize(UDim2.new(percent, 0, 1, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.15)

					-- move the character upward one step per successful input
					root.CFrame = root.CFrame * CFrame.new(0, config.climbStepRange, 0)

					local tween = tweenService:Create(circle, TweenInfo.new(0.15, Enum.EasingStyle.Circular), {
						BackgroundTransparency = 1,
						TextTransparency = 1
					})
					tween:Play()
					tween.Completed:Wait()

					connection:Disconnect()
					connection = nil

					-- finish the climb once enough steps were completed
					if progress >= maxProgress then
						object:changeState("Idle")

						local finalPos = destination.Position + Vector3.new(0, root.Size.Y, 0)
						local finalCF = CFrame.new(finalPos, finalPos + root.CFrame.LookVector)

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

					handleKeybind(nextKeyCode(keycode))
				end
			end)
		end

		handleKeybind(nextKeyCode())
	end

	function self.actions.dash(object)
		-- dash is restricted by cooldown and only works while moving
		if tick() - object.lastDash < config.dashCooldown then
			return
		end

		if object.moveState ~= "Moving" then
			return
		end

		local direction = object.root and object.root.CFrame.LookVector * config.dashRange
		if not direction then
			return
		end

		local success = object:changeState("Dash")
		if not success then
			return
		end

		object.lastDash = tick()

		local speed = config.dashSpeed
		local root = object.root
		local humanoid = object.humanoid
		local oldWalkSpeed = humanoid.WalkSpeed

		-- disable normal walking while dash movement is controlling the character
		humanoid.WalkSpeed = 0.01

		local connection
		connection = runService.Heartbeat:Connect(function(delta)
			local distance = speed * delta

			-- move the character forward every frame while dash speed decreases
			object.root.CFrame *= CFrame.new(0, 0, -distance)
			speed -= 4

			local wall = checkWalls(object.root, 5)
			if wall then
				humanoid.WalkSpeed = oldWalkSpeed

				local speedPercent = speed / config.dashSpeed
				object.collisions.wallHit(object, speedPercent)

				connection:Disconnect()
				connection = nil
			end

			if speed <= 1 then
				tweenService:Create(humanoid, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {
					WalkSpeed = oldWalkSpeed
				}):Play()

				connection:Disconnect()
				connection = nil
			end
		end)
	end

	controller["object"] = self
	return self
end

function controller:remove()
	if controller.object and controller.object == self then
		controller.object = nil
	end
end

function controller:changeState(name)
	-- reject invalid or repeated states
	if not table.find(validMoveStates, name) or self.moveState == name then
		return false
	end

	self.moveState = name
	return true
end

task.wait(2)
controller.new(player)

-- input handling
userInputService.InputBegan:Connect(function(input, fromGame)
	if fromGame then
		return
	end

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
		object.sprinting = false
		tweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {
			FieldOfView = 70
		}):Play()
	end
end)

-- physics update
runService.Heartbeat:Connect(function(delta)
	debug.profilebegin("character physics step")
	camera = workspace.CurrentCamera

	if controller.object then
		local object = controller.object
		local moveState = object.moveState
		local isMoving = (
			moveState ~= "Injured" and moveState ~= "Climbing" and moveState ~= "Dash"
		) and (
			userInputService:IsKeyDown(Enum.KeyCode.W)
				or userInputService:IsKeyDown(Enum.KeyCode.S)
				or userInputService:IsKeyDown(Enum.KeyCode.D)
				or userInputService:IsKeyDown(Enum.KeyCode.A)
		)

		-- keep movement state in sync with player input
		if not isMoving then
			object:changeState("Idle")

			if object.sprinting then
				object.sprinting = false
			end
		else
			object:changeState("Moving")
		end

		object.humanoid.WalkSpeed = object.sprinting and config.sprintSpeed or 16
	end

	debug.profileend()
end)

-- camera update
local baseCF
runService:BindToRenderStep("Render Physics", Enum.RenderPriority.Camera.Value + 1, function(delta)
	debug.profilebegin("render physics step")

	if controller.object then
		local object = controller.object
		baseCF = camera.CFrame

		local x = object.springs.x:update(delta)
		local y = object.springs.y:update(delta)

		camera.CFrame = baseCF * CFrame.new(x, y, 0)
	end

	debug.profileend()
end)

attachClimbModel(workspace.Climb)

-- character lifecycle
player.CharacterAdded:Connect(function(_)
	controller.new(player)
end)

player.CharacterRemoving:Connect(function(_)
	if controller.object then
		controller.object:remove()
	end
end)

-- cooldown indicator
local cooldowns = Instance.new("TextLabel", movementGui)
cooldowns.BackgroundTransparency = 1
cooldowns.TextColor3 = Color3.new(1,1,1)
cooldowns.FontFace = Font.fromName("Nunito", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
cooldowns.TextScaled = true
cooldowns.Text = "Cooldowns:"
cooldowns.Size = UDim2.new(0, 211, 0, 50)
cooldowns.Position = UDim2.new(0, 0, 0.585, 0)
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
