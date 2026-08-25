local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Config    = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")
local SyncTimer = Remotes:WaitForChild("SyncTimer")

local syncRemaining = 0
local syncTotal     = 1
local syncTick      = tick()
local timerActive   = false

local function getColor(progress)
    if progress > 0.5 then
        return Color3.fromRGB(80, 230, 120)
    elseif progress > 0.25 then
        return Color3.fromRGB(255, 175, 40)
    else
        return Color3.fromRGB(255, 60, 60)
    end
end

local function findContainer(screenGui)
    for _, frame in ipairs(screenGui:GetChildren()) do
        if frame:IsA("Frame") and frame.Visible then
            local tc = frame:FindFirstChild("TimerContainer")
            if tc then return tc end
            local lp = frame:FindFirstChild("LeftPanel")
            if lp then
                local tc2 = lp:FindFirstChild("TimerContainer")
                if tc2 then return tc2 end
            end
        end
    end
    return nil
end

SyncTimer.OnClientEvent:Connect(function(remaining, total)
    syncRemaining = remaining
    syncTotal     = total
    syncTick      = tick()
    timerActive   = (remaining > 0 and total > 0)
end)

local screenGui = nil

task.spawn(function()
    while true do
        task.wait(0.05)
        if not screenGui then
            screenGui = PlayerGui:FindFirstChild(Config.MAIN_GUI_NAME)
        end
        if not screenGui then continue end
        local container = findContainer(screenGui)
        if not container then continue end
        local tl = container:FindFirstChild("TimeLabel")
        if not tl then continue end
        if not timerActive then
            tl.Text       = "0s"
            tl.TextColor3 = Color3.fromRGB(120, 100, 160)
            continue
        end
        local elapsed   = tick() - syncTick
        local remaining = math.max(0, syncRemaining - elapsed)
        local progress  = remaining / math.max(syncTotal, 1)
        tl.Text       = math.ceil(remaining) .. "s"
        tl.TextColor3 = getColor(progress)
        if remaining <= 0 then
            timerActive   = false
            tl.Text       = "0s"
            tl.TextColor3 = Color3.fromRGB(255, 60, 60)
        end
    end
end)

task.delay(2, function()
    local sg = PlayerGui:WaitForChild(Config.MAIN_GUI_NAME, 10)
    if not sg then return end
    local lf = sg:FindFirstChild("LobbyFrame")
    if not lf then return end
    local wp = lf:FindFirstChild("WaitPanel")
    if not wp then return end

    wp.ClipsDescendants = true

    local SQUARE_COLORS = {
        Color3.fromRGB(120, 180, 255),
        Color3.fromRGB(140, 100, 255),
        Color3.fromRGB(80, 220, 200),
        Color3.fromRGB(180, 140, 255),
    }
    local SIZES  = {11, 8, 6, 5}
    local GAP    = 5
    local MARGIN = 7
    local SPEED  = 240

    local squares = {}
    for i = 1, 4 do
        local sq = Instance.new("Frame")
        sq.Name                   = "OrbitSquare_" .. i
        sq.Size                   = UDim2.new(0, SIZES[i], 0, SIZES[i])
        sq.BackgroundColor3       = SQUARE_COLORS[i]
        sq.BorderSizePixel        = 0
        sq.BackgroundTransparency = 0.10
        sq.ZIndex                 = 6
        sq.Parent                 = wp
        local uc = Instance.new("UICorner")
        uc.CornerRadius = UDim.new(0, 2)
        uc.Parent = sq
        table.insert(squares, sq)
    end

    local function rectPath(t, W, H)
        local perim = 2 * (W + H)
        t = t % perim
        local x, y
        if t < W then
            x = -W * 0.5 + t ; y = -H * 0.5
        elseif t < W + H then
            x = W * 0.5      ; y = -H * 0.5 + (t - W)
        elseif t < 2*W + H then
            x = W * 0.5 - (t - W - H) ; y = H * 0.5
        else
            x = -W * 0.5     ; y = H * 0.5 - (t - 2*W - H)
        end
        return x, y
    end

    local startTime = tick()

    RunService.Heartbeat:Connect(function()
        if not lf.Visible then return end

        local wpSz = wp.AbsoluteSize
        if wpSz.X <= 0 then return end

        local pathW = wpSz.X - MARGIN * 2 - SIZES[1]
        local pathH = wpSz.Y - MARGIN * 2 - SIZES[1]
        if pathW <= 0 or pathH <= 0 then return end

        local cx = wpSz.X * 0.5
        local cy = wpSz.Y * 0.5

        local elapsed = tick() - startTime
        local perim   = 2 * (pathW + pathH)
        local t0      = (elapsed * SPEED) % perim

        local offset = 0
        for i, sq in ipairs(squares) do
            local t = t0 - offset
            local rx, ry = rectPath(t, pathW, pathH)
            sq.Position = UDim2.new(
                0, math.floor(cx + rx - SIZES[i] * 0.5),
                0, math.floor(cy + ry - SIZES[i] * 0.5)
            )
            offset = offset + SIZES[i] + GAP
        end
    end)

    print("[TimerAnimator] Rect squares running (inside WaitPanel)!")
end)

print("[TimerAnimator] Ready!")
