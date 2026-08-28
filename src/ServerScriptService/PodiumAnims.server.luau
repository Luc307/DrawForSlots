local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local NAMES = {
    Config.PODIUM_DANCE_1,
    Config.PODIUM_DANCE_2,
    Config.PODIUM_DANCE_3,
}

local folder = ReplicatedStorage:FindFirstChild("PodiumAnims")
if not folder then
    folder = Instance.new("Folder")
    folder.Name = "PodiumAnims"
    folder.Parent = ReplicatedStorage
end
for _, c in ipairs(folder:GetChildren()) do
    c:Destroy()
end

local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
local dummy = saves and saves:FindFirstChild("Dummy")
if not dummy then
    warn("[PodiumAnims] ServerStorage.RBX_ANIMSAVES.Dummy missing")
    return
end

for _, name in ipairs(NAMES) do
    if type(name) ~= "string" or name == "" then
        continue
    end
    local src = dummy:FindFirstChild(name)
    if src and src:IsA("KeyframeSequence") then
        local clone = src:Clone()
        clone.Name = name
        clone.Loop = true
        clone.Parent = folder
    else
        warn("[PodiumAnims] missing KeyframeSequence: " .. tostring(name))
    end
end
