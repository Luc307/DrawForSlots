local Players = game:GetService("Players")

local SPAWN_FORCEFIELD_DURATION = 0

local function disableSpawnForceFields()
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") then
			inst.Duration = SPAWN_FORCEFIELD_DURATION
		end
	end

	workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("SpawnLocation") then
			inst.Duration = SPAWN_FORCEFIELD_DURATION
		end
	end)
end

local function stripForceField(character: Model)
	local function remove()
		for _, inst in character:GetDescendants() do
			if inst:IsA("ForceField") then
				inst:Destroy()
			end
		end
	end

	remove()

	local conn = character.DescendantAdded:Connect(function(inst)
		if inst:IsA("ForceField") then
			inst:Destroy()
		end
	end)

	character.Destroying:Once(function()
		conn:Disconnect()
	end)

	for _, delay in { 0.05, 0.15, 0.5, 1 } do
		task.delay(delay, remove)
	end
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(stripForceField)

	if player.Character then
		stripForceField(player.Character)
	end
end

disableSpawnForceFields()

Players.PlayerAdded:Connect(bindPlayer)
for _, player in Players:GetPlayers() do
	bindPlayer(player)
end
