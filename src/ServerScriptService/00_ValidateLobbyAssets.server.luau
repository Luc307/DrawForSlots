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
local QUEUE_BUTTONS = { "3 Player Game", "5 Player Game" }
local CASINO_BUTTONS = { "LuckyWheel", "Plinko", "1RowSlots", "5ReelSlots", "Diamond Mines" }

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
	local root = lobby:FindFirstChild("PhysicalButtons")
	if need(lobby, "PhysicalButtons", "Folder") and root then
		local gamemodes = root:FindFirstChild("Gamemodes")
		local casino = root:FindFirstChild("CasinoGames")
		need(root, "Gamemodes", "Folder")
		need(root, "CasinoGames", "Folder")
		if gamemodes then
			for _, name in QUEUE_BUTTONS do
				local model = gamemodes:FindFirstChild(name)
				if need(gamemodes, name, "Model") and model then
					need(model, "Button", "BasePart")
					need(model, "InvisPart", "BasePart")
				end
			end
		end
		if casino then
			for _, name in CASINO_BUTTONS do
				local model = casino:FindFirstChild(name)
				if need(casino, name, "Model") and model then
					need(model, "Button", "BasePart")
					need(model, "InvisPart", "BasePart")
				end
			end
		end
	end
end

print("[ValidateLobbyAssets] Done")
