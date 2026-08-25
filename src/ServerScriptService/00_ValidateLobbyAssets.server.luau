-- Validates Studio preexisting assets. No runtime Instance.new.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local REQUIRED_SOUNDS = { "Lobby", "RewardBasic", "RewardMid", "RewardBad", "Jackpot", "Click" }
local REQUIRED_SIGNALS = {
	"DrawActiveEvent",
	"RenderStrokesEvent",
	"RequestOpenUI",
	"RequestShowPage",
	"ShowPage",
	"SpinStateChanged",
}
local QUEUE_DUMMIES = { "QueueDummy_3P", "QueueDummy_5P" }

local function need(parent: Instance?, name: string, className: string?): boolean
	if not parent then
		warn("[ValidateLobbyAssets] Missing parent for", name)
		return false
	end
	local child = parent:FindFirstChild(name)
	if not child then
		warn("[ValidateLobbyAssets] Missing:", parent:GetFullName() .. "." .. name)
		return false
	end
	if className and not child:IsA(className) then
		warn("[ValidateLobbyAssets] Wrong class:", child:GetFullName(), "want", className)
		return false
	end
	return true
end

local sounds = ReplicatedStorage:FindFirstChild("Sounds")
need(ReplicatedStorage, "Sounds", "Folder")
if sounds then
	for _, name in REQUIRED_SOUNDS do
		need(sounds, name, "Sound")
	end
end

need(ReplicatedStorage, "Vfx", "Folder")
local vfx = ReplicatedStorage:FindFirstChild("Vfx")
if vfx then
	need(vfx, "GuideArrow", "Model")
end

local signals = ReplicatedStorage:FindFirstChild("Signals")
need(ReplicatedStorage, "Signals", "Folder")
if signals then
	for _, name in REQUIRED_SIGNALS do
		need(signals, name, "BindableEvent")
	end
end

need(StarterGui, "ShopGui", "ScreenGui")
need(SoundService, "GameMusic", "Folder")

local lobby = workspace:FindFirstChild("Floating Lobby")
if not lobby then
	warn("[ValidateLobbyAssets] Missing Floating Lobby")
else
	local folder = lobby:FindFirstChild("Dummies")
	if need(lobby, "Dummies", "Folder") and folder then
		for _, name in QUEUE_DUMMIES do
			local dummy = folder:FindFirstChild(name)
			if not need(folder, name, "Model") then
				continue
			end
			local hrp = dummy and dummy:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") and not hrp:FindFirstChildOfClass("ProximityPrompt") then
				warn("[ValidateLobbyAssets] Missing ProximityPrompt on", name)
			end
		end
	end
end

print("[ValidateLobbyAssets] Done")
