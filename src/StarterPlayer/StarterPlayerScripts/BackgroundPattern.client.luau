-- ============================================================
-- BackgroundPattern.client.lua  |  Animated Gradient Background
-- Fließende Farb-Orbs für alle Phasen
-- ============================================================
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Config      = require(ReplicatedStorage:WaitForChild("GameConfig"))

local ALL_FRAMES = {
    "LobbyFrame", "WriteFrame", "DrawFrame", "ReviewFrame", "ResultsFrame"
}

-- ============================================================
-- BLOB-DEFINITIONEN
-- Jeder Blob: Farbe, Startwinkel, Radius, Geschwindigkeit, Größe
-- ============================================================
local BLOBS = {
    { color = Color3.fromRGB(80,  40, 200),  angle = 0,    r = 0.38, speed = 0.18, size = 0.85 },
    { color = Color3.fromRGB(20, 100, 220),  angle = 2.1,  r = 0.42, speed = 0.13, size = 0.80 },
    { color = Color3.fromRGB(100, 30, 180),  angle = 4.2,  r = 0.30, speed = 0.22, size = 0.70 },
    { color = Color3.fromRGB(40, 150, 255),  angle = 1.0,  r = 0.50, speed = 0.10, size = 0.65 },
    { color = Color3.fromRGB(160, 50, 220),  angle = 3.5,  r = 0.25, speed = 0.28, size = 0.55 },
}

-- Jeder Blob hat auch eine vertikale Lissajous-Bewegung
local BLOB_V = {
    { vy = 0.12, vy_phase = 0    },
    { vy = 0.09, vy_phase = 1.3  },
    { vy = 0.16, vy_phase = 2.6  },
    { vy = 0.07, vy_phase = 0.7  },
    { vy = 0.20, vy_phase = 3.1  },
}

-- Hintergrundfarbe (sehr dunkel)
local BG_COLOR = Color3.fromRGB(8, 5, 30)

-- ============================================================
-- BUILD: Erstellt animierten Hintergrund in einem Frame
-- ============================================================
local function buildAnimatedBG(frame)
    -- Entferne alten Pattern
    local old = frame:FindFirstChild("BgPattern")
    if old then old:Destroy() end

    -- Basis-Container (hinter allem)
    local container = Instance.new("Frame")
    container.Name                   = "BgPattern"
    container.Size                   = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.ClipsDescendants       = true
    container.ZIndex                 = 0
    container.Parent                 = frame

    -- Dunkle Basis-Schicht
    local base = Instance.new("Frame")
    base.Size                   = UDim2.new(1, 0, 1, 0)
    base.BackgroundColor3       = BG_COLOR
    base.BackgroundTransparency = 0
    base.BorderSizePixel        = 0
    base.ZIndex                 = 0
    base.Parent                 = container

    -- Blob-Frames erstellen (übergroß für Überlauf)
    local blobFrames = {}
    for i, blob in ipairs(BLOBS) do
        local sz = blob.size

        -- ImageLabel mit radialer Gradient-Simulation via UIGradient-Rotation
        local bf = Instance.new("Frame")
        bf.Name                   = "Blob_" .. i
        bf.Size                   = UDim2.new(sz * 1.6, 0, sz * 2.2, 0)
        bf.AnchorPoint            = Vector2.new(0.5, 0.5)
        bf.Position               = UDim2.new(0.5, 0, 0.5, 0)
        bf.BackgroundColor3       = blob.color
        bf.BackgroundTransparency = 0.0
        bf.BorderSizePixel        = 0
        bf.ZIndex                 = 1
        bf.Parent                 = container

        -- UICorner: sehr rund → blob-artig
        local uc = Instance.new("UICorner")
        uc.CornerRadius = UDim.new(0.5, 0)
        uc.Parent = bf

        -- UIGradient: radial-ähnlich (von Farbe → transparent nach außen)
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200,200,200)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
        })
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.15),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1,   1.0),
        })
        grad.Rotation = 0
        grad.Parent   = bf

        table.insert(blobFrames, {frame=bf, grad=grad, blobDef=blob, vDef=BLOB_V[i]})
    end

    -- Animation
    local startTime = tick()
    RunService.Heartbeat:Connect(function()
        if not frame.Visible then return end

        local t   = tick() - startTime
        local vpW = container.AbsoluteSize.X
        local vpH = container.AbsoluteSize.Y
        if vpW <= 0 then vpW = 1366 end
        if vpH <= 0 then vpH = 768 end

        for _, b in ipairs(blobFrames) do
            local def  = b.blobDef
            local vDef = b.vDef
            local a    = def.angle + t * def.speed

            -- Horizontale Kreisbahn + vertikale Schwingung
            local nx = 0.5 + def.r * math.cos(a)
            local ny = 0.5 + vDef.vy * math.sin(t * def.speed * 1.7 + vDef.vy_phase)

            b.frame.Position = UDim2.new(nx, 0, ny, 0)

            -- Gradient rotiert langsam für mehr Lebendigkeit
            b.grad.Rotation = (t * 15 * def.speed) % 360
        end
    end)

    return container
end

-- ============================================================
-- STARTUP
-- ============================================================
local screenGui = PlayerGui:WaitForChild(Config.MAIN_GUI_NAME, 10)
if not screenGui then return end

for _, fname in ipairs(ALL_FRAMES) do
    local fr = screenGui:FindFirstChild(fname)
    if fr then
        buildAnimatedBG(fr)
        print("[BackgroundPattern] Animated BG: " .. fname)
    end
end

-- Casino ShopGui: no animated blobs (solid black overlay instead)

print("[BackgroundPattern] Done!")

