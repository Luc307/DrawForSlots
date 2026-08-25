local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockyDummy = require(ReplicatedStorage.Modules.BlockyDummy)

local RETRY_DELAYS = { 0, 0.5, 1, 2 }

local function applyBlockyLook(character: Model, player: Player)
	BlockyDummy.applyToCharacter(character, player)
end

local function tryApply(character: Model, player: Player)
	for _, delay in RETRY_DELAYS do
		task.delay(delay, function()
			if player.Character == character and character.Parent then
				applyBlockyLook(character, player)
			end
		end)
	end
end

local function bindPlayer(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		tryApply(character, player)
	end)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			tryApply(character, player)
		end)
	end)

	if player.Character then
		tryApply(player.Character, player)
	end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in Players:GetPlayers() do
	bindPlayer(player)
end
