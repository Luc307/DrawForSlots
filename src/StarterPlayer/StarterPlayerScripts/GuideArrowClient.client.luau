local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Signals = ReplicatedStorage:WaitForChild("Signals")
local SetQueueState = Remotes:WaitForChild("SetQueueState")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local SpinStateChanged = Signals:WaitForChild("SpinStateChanged") :: BindableEvent

local player = Players.LocalPlayer

local BUTTON_4P = "4 Player Game"
local BUTTON_CASINO = "Diamond Mines"
local ARROW_TEMPLATE_PATH = { "Vfx", "GuideArrow" }
local ARROW_NEAR_HIDE_DISTANCE = 4
local SPAWN_INTERVAL = 0.12
local ARROW_SPEED = 14
local CHEST_OFFSET = Vector3.new(0, 0, 0)
local MAX_ACTIVE_ARROWS = 36
local START_TRANSPARENCY = 0.15
local END_FADE_DISTANCE = 6
local COLOR_A = Color3.fromRGB(30, 180, 220)
local COLOR_B = Color3.fromRGB(40, 230, 150)
local COLOR_PULSE_SPEED = 2.8

type ArrowState = {
	model: Model,
	parts: { BasePart },
	progress: number,
}

local targetButtonName = BUTTON_4P
local isQueued = false
local finishedGameThisSession = false
local casinoPlayedThisSession = false
local template: Model? = nil
local folder: Folder? = nil
local active: { ArrowState } = {}
local spawnAccum = 0

local function getTemplate(): Model?
	if template and template.Parent then
		return template
	end
	local node: Instance = ReplicatedStorage
	for _, name in ARROW_TEMPLATE_PATH do
		local nextNode = node:FindFirstChild(name)
		if not nextNode then
			return nil
		end
		node = nextNode
	end
	if node:IsA("Model") then
		template = node
		return template
	end
	return nil
end

local function getChestPart(model: Model): BasePart?
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function getTargetButtonPart(): BasePart?
	local lobby = workspace:FindFirstChild("Floating Lobby")
	if not lobby then
		return nil
	end
	local buttons = lobby:FindFirstChild("PhysicalButtons")
	if not buttons then
		return nil
	end
	local model = buttons:FindFirstChild(targetButtonName, true)
	if not model or not model:IsA("Model") then
		return nil
	end
	local button = model:FindFirstChild("Button")
	if button and button:IsA("BasePart") then
		return button
	end
	return model.PrimaryPart
end

local function getTargetChest(): BasePart?
	return getTargetButtonPart()
end

local function getPlayerChest(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return getChestPart(character)
end

local function ensureFolder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local existing = camera:FindFirstChild("LocalGuideArrows")
	if existing and existing:IsA("Folder") then
		folder = existing
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "LocalGuideArrows"
	created.Parent = camera
	folder = created
	return folder
end

local function clearAllArrows()
	for _, state in active do
		if state.model then
			state.model:Destroy()
		end
	end
	table.clear(active)
	spawnAccum = 0
end

local function shouldShow(): boolean
	if isQueued then
		return false
	end
	if finishedGameThisSession and casinoPlayedThisSession then
		return false
	end
	local chest = getPlayerChest()
	local target = getTargetChest()
	if not chest or not target then
		return false
	end
	local dist = (chest.Position - target.Position).Magnitude
	return dist > ARROW_NEAR_HIDE_DISTANCE
end

local function spawnArrow(chest: BasePart, target: BasePart)
	local tmpl = getTemplate()
	local parent = ensureFolder()
	if not tmpl or not parent then
		return
	end

	if #active >= MAX_ACTIVE_ARROWS then
		local oldest = table.remove(active, 1)
		if oldest and oldest.model then
			oldest.model:Destroy()
		end
	end

	local clone = tmpl:Clone()
	clone.Name = "GuideArrow"
	local parts: { BasePart } = {}
	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.CastShadow = false
			table.insert(parts, desc)
		end
	end

	local startPos = chest.Position + CHEST_OFFSET
	local targetPos = target.Position + CHEST_OFFSET
	local lookAt = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	clone:PivotTo(CFrame.lookAt(startPos, lookAt))
	clone.Parent = parent

	table.insert(active, {
		model = clone,
		parts = parts,
		progress = 0,
	})
end

local function updateArrows(dt: number)
	if not shouldShow() then
		if #active > 0 then
			clearAllArrows()
		end
		return
	end

	local chest = getPlayerChest()
	local target = getTargetChest()
	if not chest or not target then
		return
	end

	spawnAccum += dt
	while spawnAccum >= SPAWN_INTERVAL do
		spawnAccum -= SPAWN_INTERVAL
		spawnArrow(chest, target)
	end

	local targetPos = target.Position + CHEST_OFFSET
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * COLOR_PULSE_SPEED)
	local color = COLOR_A:Lerp(COLOR_B, pulse)

	local i = 1
	while i <= #active do
		local state = active[i]
		local model = state.model
		if not model or not model.Parent then
			table.remove(active, i)
			continue
		end

		local startPos = chest.Position + CHEST_OFFSET
		local toTarget = targetPos - startPos
		local dist = toTarget.Magnitude
		if dist < 0.1 then
			model:Destroy()
			table.remove(active, i)
			continue
		end

		state.progress += (ARROW_SPEED * dt) / dist
		if state.progress >= 1 then
			model:Destroy()
			table.remove(active, i)
			continue
		end

		local pos = startPos:Lerp(targetPos, state.progress)
		model:PivotTo(CFrame.lookAt(pos, targetPos))

		local remaining = (1 - state.progress) * dist
		local fade = if remaining < END_FADE_DISTANCE
			then math.clamp(remaining / END_FADE_DISTANCE, 0, 1)
			else 1
		local transparency = START_TRANSPARENCY + (1 - fade) * (1 - START_TRANSPARENCY)

		for _, part in state.parts do
			if part and part.Parent then
				part.Color = color
				part.Transparency = transparency
			end
		end

		i += 1
	end
end

SetQueueState.OnClientEvent:Connect(function(queued)
	local wasQueued = isQueued
	isQueued = queued
	if queued then
		clearAllArrows()
	elseif wasQueued and not finishedGameThisSession then
		targetButtonName = BUTTON_4P
	end
end)

GameStateChanged.OnClientEvent:Connect(function(phase)
	if phase == "results" then
		finishedGameThisSession = true
		targetButtonName = BUTTON_CASINO
	end
end)

SpinStateChanged.Event:Connect(function(state)
	if state ~= "stop" and state ~= "reward" then
		return
	end
	if not finishedGameThisSession then
		return
	end
	casinoPlayedThisSession = true
	clearAllArrows()
end)

RunService.RenderStepped:Connect(function(dt)
	updateArrows(dt)
end)

player.CharacterAdded:Connect(function()
	clearAllArrows()
	folder = nil
end)
