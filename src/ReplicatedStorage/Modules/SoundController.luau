local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LOBBY_VOLUME = 0.22
local MUSIC_FADE_TIME = 0.7
local INTRO_FADE_IN_TIME = 1.4

local SoundController = {}

local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local clickSound = soundsFolder:WaitForChild("Click") :: Sound

local lobbySound = soundsFolder:WaitForChild("Lobby") :: Sound
lobbySound.Looped = true
lobbySound.Volume = 0

local started = false
local inRound = false
local gambleMuted = false
local lobbyTween: Tween? = nil

local function wantLobby(): boolean
	return not inRound and not gambleMuted
end

local function fadeTo(sound: Sound, targetVolume: number, existingTween: Tween?): Tween?
	if existingTween then
		existingTween:Cancel()
	end
	sound.Looped = true
	if targetVolume > 0 and not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	if math.abs(sound.Volume - targetVolume) < 0.005 then
		sound.Volume = targetVolume
		return nil
	end
	local dur = if targetVolume > 0 and sound.Volume <= 0.01 then INTRO_FADE_IN_TIME else MUSIC_FADE_TIME
	local tween = TweenService:Create(sound, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = targetVolume,
	})
	tween:Play()
	return tween
end

local function applyMusic()
	local vol = if wantLobby() then LOBBY_VOLUME else 0
	lobbyTween = fadeTo(lobbySound, vol, lobbyTween)
end

function SoundController.beginGamble()
	if inRound then return end
	gambleMuted = true
	applyMusic()
end

function SoundController.cancelGamble()
	gambleMuted = false
	applyMusic()
end

function SoundController.endGambleAfterReward(rewardSound: Sound?)
	gambleMuted = false
	if rewardSound then
		local waitTime = rewardSound.TimeLength
		if typeof(waitTime) ~= "number" or waitTime < 0.05 then
			waitTime = 2.5
		end
		task.delay(waitTime, applyMusic)
	else
		applyMusic()
	end
end

function SoundController.playSfx(sound: Sound?)
	if not sound or not sound:IsA("Sound") then return false end
	sound:Play()
	return true
end

function SoundController.playClick()
	clickSound:Play()
end

function SoundController.start()
	if started or not RunService:IsClient() then return end
	started = true

	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	Remotes:WaitForChild("SetQueueState").OnClientEvent:Connect(function(isQueued)
		inRound = isQueued == true
		if inRound then gambleMuted = false end
		applyMusic()
	end)

	Remotes:WaitForChild("GameStateChanged").OnClientEvent:Connect(function(phase)
		if phase ~= "lobby" then
			inRound = true
			gambleMuted = false
			applyMusic()
		end
	end)

	task.spawn(function()
		local signals = ReplicatedStorage:WaitForChild("Signals", 10)
		local spinState = signals and signals:WaitForChild("SpinStateChanged", 10)
		if spinState and spinState:IsA("BindableEvent") then
			spinState.Event:Connect(function(state, rewardSound)
				if state == "start" then
					SoundController.beginGamble()
				elseif state == "reward" then
					local snd = if typeof(rewardSound) == "Instance" and rewardSound:IsA("Sound") then rewardSound else nil
					SoundController.endGambleAfterReward(snd)
				elseif state == "cancel" then
					SoundController.cancelGamble()
				end
			end)
		end
	end)

	applyMusic()
	task.spawn(function()
		while started do
			task.wait(1.5)
			if wantLobby() and not lobbySound.IsPlaying then
				applyMusic()
			end
		end
	end)
end

return SoundController
