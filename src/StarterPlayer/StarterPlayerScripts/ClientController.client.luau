local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local GuiService          = game:GetService("GuiService")
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local Config              = require(ReplicatedStorage:WaitForChild("GameConfig"))
local UiScaler            = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UiScaler"))
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged  = Remotes:WaitForChild("GameStateChanged")
local SubmitText        = Remotes:WaitForChild("SubmitText")
local SubmitRanking     = Remotes:WaitForChild("SubmitRanking")
local UpdateSubmitCount = Remotes:WaitForChild("UpdateSubmitCount")
local SendRoundData     = Remotes:WaitForChild("SendRoundData")
local SendReviewData    = Remotes:WaitForChild("SendReviewData")
local SendResults       = Remotes:WaitForChild("SendResults")
local GetFallbackText   = Remotes:WaitForChild("GetFallbackText")
local GetCoins          = Remotes:WaitForChild("GetCoins")
local SetQueueState     = Remotes:WaitForChild("SetQueueState")
local LeaveQueueRequest = Remotes:WaitForChild("LeaveQueueRequest")
local ReturnToLobby     = Remotes:WaitForChild("ReturnToLobby")

UserInputService.MouseBehavior = Enum.MouseBehavior.Default

local screenGui    = PlayerGui:WaitForChild(Config.MAIN_GUI_NAME)
UiScaler.bind(screenGui)

local function killTouchGui(gui)
    if not gui then return end
    if gui:IsA("LayerCollector") then
        gui.Enabled = false
    end
end
local function disableTouchControls()
    pcall(function()
        GuiService.TouchControlsEnabled = false
    end)
    for _, child in ipairs(PlayerGui:GetChildren()) do
        if child.Name == "TouchGui" then
            killTouchGui(child)
        end
    end
end
disableTouchControls()
pcall(function()
    GuiService:GetPropertyChangedSignal("TouchControlsEnabled"):Connect(function()
        if GuiService.TouchControlsEnabled then
            GuiService.TouchControlsEnabled = false
        end
    end)
end)
PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "TouchGui" then
        killTouchGui(child)
        if child:IsA("LayerCollector") then
            child:GetPropertyChangedSignal("Enabled"):Connect(function()
                if child.Enabled then
                    child.Enabled = false
                end
            end)
        end
    end
end)
local lobbyFrame   = screenGui:WaitForChild("LobbyFrame")
local writeFrame   = screenGui:WaitForChild("WriteFrame")
local drawFrame    = screenGui:WaitForChild("DrawFrame")
local reviewFrame  = screenGui:WaitForChild("ReviewFrame")
local resultsFrame = screenGui:WaitForChild("ResultsFrame")
local allFrames    = {lobbyFrame, writeFrame, drawFrame, reviewFrame, resultsFrame}
local introFrame   = screenGui:WaitForChild("IntroFrame")
local introTitle   = introFrame:WaitForChild("TitleLabel")
local introCommunity = introFrame:FindFirstChild("CommunityLabel")

local CANVAS_W = Config.CANVAS_W
local CANVAS_H = Config.CANVAS_H
local REVIEW = {
    PANEL_W = 0.38,
    GAP = 0.05,
    PAD_Y = 0.09,
    PAD_B = 0.1,
    CORNER = 16,
    CARD_BG = Color3.fromRGB(118, 98, 195),
    CARD_BG2 = Color3.fromRGB(108, 88, 188),
    CARD_STROKE = Color3.fromRGB(210, 190, 255),
    RIGHT_BG = Color3.fromRGB(125, 105, 200),
    TILE = Color3.fromRGB(140, 118, 225),
    TILE_SEL = Color3.fromRGB(45, 210, 130),
    ROW = Color3.fromRGB(155, 130, 235),
    TEXT = Color3.fromRGB(255, 255, 255),
    TEXT_BODY = Color3.fromRGB(248, 248, 255),
    TITLE = Color3.fromRGB(255, 240, 100),
    HINT = Color3.fromRGB(225, 215, 255),
    ENTRY = Color3.fromRGB(135, 115, 215),
    AVATAR = Color3.fromRGB(90, 70, 160),
    BTN_W = 36,
    AV_SIZE = 52,
    AV_GAP = 6,
}
local submitGen = 0

local function reviewStartX()
    return (1 - REVIEW.PANEL_W * 2 - REVIEW.GAP) * 0.5
end

print("[Draw for Slots] You are playing as: " .. LocalPlayer.Name)

local function addCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function addStroke(p, color, thickness)
    local s = p:FindFirstChildOfClass("UIStroke")
    if not s then
        s = Instance.new("UIStroke")
        s.Parent = p
    end
    s.Color = color
    s.Thickness = thickness or 2
    s.Transparency = 0.08
    return s
end

local function styleReviewCard(frame, bg, stroke)
    frame.BackgroundColor3 = bg
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    if not frame:FindFirstChildOfClass("UICorner") then
        addCorner(frame, REVIEW.CORNER)
    end
    addStroke(frame, stroke or REVIEW.CARD_STROKE, 2)
end

local function applyReviewText(lbl, size, useTitleColor)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = size
    lbl.TextColor3 = useTitleColor and REVIEW.TITLE or REVIEW.TEXT
    lbl.TextScaled = true
    lbl.TextWrapped = true
    lbl.TextTruncate = Enum.TextTruncate.None
    local cap = lbl:FindFirstChildOfClass("UITextSizeConstraint")
    if not cap then
        cap = Instance.new("UITextSizeConstraint")
        cap.Parent = lbl
    end
    local wantMax = size
    local function applyCap()
        local h = lbl.AbsoluteSize.Y
        local w = lbl.AbsoluteSize.X
        local maxUse = wantMax
        local minUse = 8
        if h > 2 then
            maxUse = math.min(wantMax, math.max(8, math.floor(h * 0.75)))
        end
        local n = math.max(#(lbl.Text or ""), 1)
        if w > 2 then
            local byW = math.floor(w / math.max(n * 0.28, 4))
            if byW > 0 then
                maxUse = math.min(maxUse, math.max(8, byW))
            end
        end
        cap.MinTextSize = minUse
        cap.MaxTextSize = math.max(minUse, maxUse)
    end
    applyCap()
    if lbl:GetAttribute("HdrFitWired") ~= true then
        lbl:SetAttribute("HdrFitWired", true)
        lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyCap)
        lbl:GetPropertyChangedSignal("Text"):Connect(applyCap)
    end
    local stroke = lbl:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = lbl
    end
    stroke.Color = Color3.fromRGB(15, 8, 40)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
end

local function fitHeaderLabel(lbl, maxSize)
    if not lbl then
        return
    end
    lbl.TextScaled = true
    lbl.TextWrapped = true
    lbl.TextTruncate = Enum.TextTruncate.None
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    applyReviewText(lbl, maxSize or 36, true)
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
end

local function styleReviewTimer(timer, midX)
    timer.BackgroundTransparency = 1
    timer.BorderSizePixel = 0
    timer.ZIndex = 20
    timer.AnchorPoint = Vector2.new(0.5, 1)
    timer.Position = UDim2.new(midX or 0.5, 0, 0.985, 0)
    timer.Size = UDim2.new(0.2, 0, 0.09, 0)

    local timeLbl = timer:FindFirstChild("TimeLabel")
    local submitLbl = timer:FindFirstChild("SubmitLabel")
    if timeLbl and submitLbl then
        timeLbl.AnchorPoint = Vector2.new(0.5, 0)
        timeLbl.Position = UDim2.new(0.5, 0, 0.05, 0)
        timeLbl.Size = UDim2.new(1, 0, 0.48, 0)
        timeLbl.TextXAlignment = Enum.TextXAlignment.Center
        timeLbl.TextScaled = true
        submitLbl.AnchorPoint = Vector2.new(0.5, 0)
        submitLbl.Position = UDim2.new(0.5, 0, 0.52, 0)
        submitLbl.Size = UDim2.new(1, 0, 0.44, 0)
        submitLbl.TextXAlignment = Enum.TextXAlignment.Center
        submitLbl.TextWrapped = true
        submitLbl.TextScaled = true
    end

    for _, lbl in ipairs(timer:GetDescendants()) do
        if lbl:IsA("TextLabel") then
            applyReviewText(lbl, lbl.Name == "TimeLabel" and 26 or 18, false)
        end
    end
end

local function ensureReviewPhaseTitle(reviewFrame)
    local title = reviewFrame:FindFirstChild("ReviewPhaseTitle")
    if not title then
        title = Instance.new("TextLabel")
        title.Name = "ReviewPhaseTitle"
        title.Parent = reviewFrame
    end
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.Position = UDim2.new(0.5, 0, 0.015, 0)
    title.Size = UDim2.new(0.86, 0, 0.06, 0)
    title.Text = "Review & Rank Albums"
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 20
    title.ClipsDescendants = false
    applyReviewText(title, 28, true)
    title.TextScaled = true
    title.TextWrapped = true
end

local clickSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Click") :: Sound
local function playClick()
    clickSound:Play()
end

local function addClickSound(btn)
    btn.MouseButton1Click:Connect(playClick)
end



local function showFrame(frame)
    for _, f in ipairs(allFrames) do f.Visible = false end
    frame.Visible = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text
            if t == "·" or t == "•" or t == "Â·" or t == "|" then
                d.Visible = false
            end
        end
    end
end

local DEFAULT_WALKSPEED = 40 -- do not change this value
local DEFAULT_JUMPPOWER = 50

-- Cache default CanCollide; never force limbs collidable (BallSocket avatars shiver).
local collideCache: { [BasePart]: boolean } = {}

local function cacheCollide(char: Model)
    table.clear(collideCache)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            collideCache[p] = p.CanCollide
        end
    end
end

-- Queued/in-round players stay hidden; lobby players visible.
local function setCharacterActive(active)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    if next(collideCache) == nil then
        cacheCollide(char)
    end

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Transparency = active and 0 or 1
            if active then
                local cached = collideCache[p]
                if cached ~= nil then
                    p.CanCollide = cached
                end
            else
                p.CanCollide = false
            end
        end
        if p:IsA("Decal") or p:IsA("Texture") then
            p.Transparency = active and 0 or 1
        end
        if p:IsA("Humanoid") then
            p.DisplayDistanceType = active
                and Enum.HumanoidDisplayDistanceType.Viewer
                or  Enum.HumanoidDisplayDistanceType.None
        end
    end

    if root then
        root.Transparency = 1
        root.Anchored = not active
        if active then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    if humanoid then
        humanoid.PlatformStand = not active
        humanoid.WalkSpeed = active and DEFAULT_WALKSPEED or 0
        humanoid.JumpPower = active and DEFAULT_JUMPPOWER or 0
    end
end

local INTRO_SHAKE_TIME  = 1
local INTRO_SHAKE_MAG_X = 6
local INTRO_SHAKE_MAG_Y = 4
local INTRO_HOLD_TIME   = 0.3
local INTRO_FADE_TIME   = 0.8

local function setIntroOpaque()
    introFrame.BackgroundTransparency = 0
    introTitle.TextTransparency = 0
    local titleStroke = introTitle:FindFirstChildOfClass("UIStroke")
    if titleStroke then
        titleStroke.Transparency = 0
    end
    if introCommunity then
        introCommunity.TextTransparency = 0
        introCommunity.BackgroundTransparency = 0
    end
end

local function fadeIntroOut()
    local fadeInfo = TweenInfo.new(INTRO_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tweens = {
        TweenService:Create(introFrame, fadeInfo, {BackgroundTransparency = 1}),
        TweenService:Create(introTitle, fadeInfo, {TextTransparency = 1}),
    }
    local titleStroke = introTitle:FindFirstChildOfClass("UIStroke")
    if titleStroke then
        table.insert(tweens, TweenService:Create(titleStroke, fadeInfo, {Transparency = 1}))
    end
    if introCommunity then
        table.insert(tweens, TweenService:Create(introCommunity, fadeInfo, {
            TextTransparency = 1,
            BackgroundTransparency = 1,
        }))
    end
    for _, tween in ipairs(tweens) do
        tween:Play()
    end
    tweens[1].Completed:Wait()
end

local HUD_COIN_FADE = 0.45
local HUD_COIN_TEXT = 28

local function ensureHudCoins(): TextLabel
    local existing = screenGui:FindFirstChild("HudCoinsLabel")
    if existing and existing:IsA("TextLabel") then
        existing.TextSize = HUD_COIN_TEXT
        existing.AnchorPoint = Vector2.new(1, 0)
        existing.Position = UDim2.new(0.985, 0, 0.02, 0)
        existing.Size = UDim2.new(0.22, 0, 0.05, 0)
        return existing
    end

    local lbl = Instance.new("TextLabel")
    lbl.Name = "HudCoinsLabel"
    lbl.AnchorPoint = Vector2.new(1, 0)
    lbl.Position = UDim2.new(0.985, 0, 0.02, 0)
    lbl.Size = UDim2.new(0.22, 0, 0.05, 0)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = HUD_COIN_TEXT
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    lbl.TextTransparency = 1
    lbl.Text = ""
    lbl.ZIndex = 40
    lbl.Visible = true
    lbl.Parent = screenGui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = lbl

    return lbl
end

local function showHudCoinsAfterIntro()
    local lbl = ensureHudCoins()
    local stroke = lbl:FindFirstChildOfClass("UIStroke")
    lbl.Visible = true
    lbl.TextTransparency = 1
    if stroke then
        stroke.Transparency = 1
    end

    task.spawn(function()
        local ok, coins = pcall(function()
            return GetCoins:InvokeServer()
        end)
        lbl.Text = tostring((ok and coins) or 0) .. " Coins"
        local fadeInfo = TweenInfo.new(HUD_COIN_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(lbl, fadeInfo, { TextTransparency = 0.15 }):Play()
        if stroke then
            TweenService:Create(stroke, fadeInfo, { Transparency = 0.55 }):Play()
        end
    end)
end

local function playIntro()
    introFrame.Visible = true
    setIntroOpaque()
    if screenGui:GetAttribute("InQueue") ~= true then
        setCharacterActive(false)
    end

    task.wait(1)

    local basePos = introTitle.Position
    local shakeEnd = tick() + INTRO_SHAKE_TIME
    while tick() < shakeEnd do
        local dx = math.random(-INTRO_SHAKE_MAG_X, INTRO_SHAKE_MAG_X)
        local dy = math.random(-INTRO_SHAKE_MAG_Y, INTRO_SHAKE_MAG_Y)
        introTitle.Position = basePos + UDim2.new(0, dx, 0, dy)
        task.wait(0.03)
    end
    introTitle.Position = basePos

    task.wait(INTRO_HOLD_TIME)
    fadeIntroOut()

    introFrame.Visible = false
    if screenGui:GetAttribute("InQueue") ~= true then
        setCharacterActive(true)
    end
    showHudCoinsAfterIntro()
end

local function findPlayer(userId, playerName)
    userId = tonumber(userId)
    if userId then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == userId then
                return p
            end
        end
    end
    if type(playerName) == "string" and playerName ~= "" then
        local byName = Players:FindFirstChild(playerName)
        if byName and byName:IsA("Player") then
            return byName
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == playerName or p.DisplayName == playerName then
                return p
            end
        end
    end
    return nil
end

local function resolveUserId(playerName, userId)
    userId = tonumber(userId)
    if userId then
        return userId
    end
    local plr = findPlayer(nil, playerName)
    if plr then
        return plr.UserId
    end
    if type(playerName) ~= "string" or playerName == "" then
        return nil
    end
    local ok, uid = pcall(function()
        return Players:GetUserIdFromNameAsync(playerName)
    end)
    if ok and type(uid) == "number" then
        return uid
    end
    return nil
end

local function clearAvatarViewport(host)
    local old = host:FindFirstChild("AvatarViewport")
    if old then
        old:Destroy()
    end
end

local function fillAvatarFromCharacter(host, character)
    if not host or not character then
        return false
    end
    clearAvatarViewport(host)

    local clone = nil
    local wasArchivable = character.Archivable
    character.Archivable = true
    local okClone, result = pcall(function()
        return character:Clone()
    end)
    character.Archivable = wasArchivable
    if okClone and result then
        clone = result
    else
        local humSrc = character:FindFirstChildOfClass("Humanoid")
        if humSrc then
            local okDesc, desc = pcall(function()
                return humSrc:GetAppliedDescription()
            end)
            if okDesc and desc then
                local okModel, model = pcall(function()
                    return Players:CreateHumanoidModelFromDescription(desc, humSrc.RigType)
                end)
                if okModel and model then
                    clone = model
                end
            end
        end
    end
    if not clone then
        return false
    end

    local vp = Instance.new("ViewportFrame")
    vp.Name = "AvatarViewport"
    vp.Size = UDim2.fromScale(1, 1)
    vp.Position = UDim2.fromScale(0, 0)
    vp.BackgroundTransparency = 1
    vp.BorderSizePixel = 0
    vp.ZIndex = (host.ZIndex or 1) + 1
    vp.Ambient = Color3.fromRGB(200, 200, 210)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-0.4, -1, -0.3)
    vp.Parent = host
    host.ClipsDescendants = true
    local hostCorner = host:FindFirstChildOfClass("UICorner")
    if hostCorner then
        local vc = Instance.new("UICorner")
        vc.CornerRadius = hostCorner.CornerRadius
        vc.Parent = vp
    end

    local world = Instance.new("WorldModel")
    world.Parent = vp

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.LocalTransparencyModifier = 0
            if d.Name == "HumanoidRootPart" then
                d.Transparency = 1
            elseif d.Transparency >= 1 then
                d.Transparency = 0
            end
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 0
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
            d:Destroy()
        end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    clone.Parent = world
    pcall(function()
        local h = clone:FindFirstChildOfClass("Humanoid")
        if h then
            h.EvaluateStateMachine = false
            h.AutoRotate = false
        end
    end)

    local head = clone:FindFirstChild("Head")
    local cam = Instance.new("Camera")
    cam.Parent = vp
    vp.CurrentCamera = cam
    cam.FieldOfView = 46
    if head and head:IsA("BasePart") then
        local att = head:FindFirstChild("FaceFrontAttachment")
        local out
        if att and att:IsA("Attachment") then
            out = att.WorldPosition - head.Position
        end
        if not out or out.Magnitude < 0.04 then
            out = head.CFrame.LookVector
        end
        local flat = Vector3.new(out.X, 0, out.Z)
        if flat.Magnitude < 0.04 then
            flat = Vector3.new(0, 0, -1)
        else
            flat = flat.Unit
        end
        local focus = head.Position + Vector3.new(0, 0.08, 0)
        cam.CFrame = CFrame.lookAt(focus + flat * 3.4, focus, Vector3.yAxis)
    else
        cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, -2.8), Vector3.new(0, 1.5, 0), Vector3.yAxis)
    end
    return true
end

local function loadAvatar(imageLabel, userId, playerName)
    if not imageLabel then
        return
    end
    userId = tonumber(userId) or resolveUserId(playerName, userId)
    imageLabel.ScaleType = Enum.ScaleType.Crop
    imageLabel.ImageTransparency = 0
    clearAvatarViewport(imageLabel)

    local function tryCharacterFallback()
        local plr = findPlayer(userId, playerName)
        if plr and plr.Character then
            if imageLabel:IsA("ImageLabel") then
                imageLabel.Image = ""
            end
            return fillAvatarFromCharacter(imageLabel, plr.Character)
        end
        return false
    end

    if not userId then
        if not tryCharacterFallback() then
            task.delay(0.5, tryCharacterFallback)
        end
        return
    end

    -- Live accounts: rbxthumb. Studio local players (UserId <= 0): character viewport.
    if userId > 0 then
        imageLabel.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
        task.spawn(function()
            if not imageLabel.Parent then
                return
            end
            local sizes = {
                Enum.ThumbnailSize.Size150x150,
                Enum.ThumbnailSize.Size100x100,
                Enum.ThumbnailSize.Size48x48,
            }
            for _, sz in ipairs(sizes) do
                local ok, url = pcall(function()
                    return Players:GetUserThumbnailAsync(
                        userId,
                        Enum.ThumbnailType.HeadShot,
                        sz
                    )
                end)
                if ok and type(url) == "string" and url ~= "" and imageLabel.Parent then
                    imageLabel.Image = url
                    return
                end
            end
            tryCharacterFallback()
        end)
    else
        if not tryCharacterFallback() then
            task.delay(0.5, tryCharacterFallback)
            task.delay(1.5, tryCharacterFallback)
        end
    end
end

local function makeReviewAvatar(parent, size, playerName, zIndex, userId)
    local av = Instance.new("ImageLabel")
    av.Name = "Avatar"
    av.Size = UDim2.new(0, size, 0, size)
    av.BackgroundColor3 = REVIEW.AVATAR
    av.BorderSizePixel = 0
    av.ScaleType = Enum.ScaleType.Crop
    av.Image = ""
    av.Visible = true
    av.BackgroundTransparency = 0
    av.ZIndex = math.max(zIndex or 5, 8)
    av.Parent = parent
    addCorner(av, math.floor(size * 0.5))
    task.spawn(function()
        local uid = resolveUserId(playerName, userId)
        loadAvatar(av, uid, playerName)
    end)
    return av
end

local function layoutIconName(av, nameLbl, avSize, extraRight)
    extraRight = extraRight or 8
    local gap = REVIEW.AV_GAP
    av.SizeConstraint = Enum.SizeConstraint.RelativeXY
    av.AnchorPoint = Vector2.new(0, 0.5)
    av.Size = UDim2.new(0, avSize, 0, avSize)
    av.Position = UDim2.new(0, 8, 0.5, 0)
    if nameLbl then
        nameLbl.AnchorPoint = Vector2.new(0, 0.5)
        nameLbl.Position = UDim2.new(0, 8 + avSize + gap, 0.5, 0)
        nameLbl.Size = UDim2.new(1, -(8 + avSize + gap + extraRight), 1, 0)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextYAlignment = Enum.TextYAlignment.Center
    end
end

local QUEUE_NAME_COLOR = Color3.fromRGB(255, 255, 255)
local QUEUE_COIN_COLOR = Color3.fromRGB(255, 255, 21)
local QUEUE_CARD_W = 340
local QUEUE_OTHER_CARD_W = 250
local QUEUE_CARD_GAP = 10

local queueCardsContainer: Frame? = nil

local function ensureQueueCardsContainer(): Frame
    if queueCardsContainer and queueCardsContainer.Parent then
        return queueCardsContainer
    end

    local container = lobbyFrame:FindFirstChild("QueueCards")
    if not container then
        container = Instance.new("Frame")
        container.Name = "QueueCards"
        container.Parent = lobbyFrame
    end

    container.BackgroundTransparency = 1
    container.AnchorPoint = Vector2.new(0.5, 1)
    container.Position = UDim2.new(0.5, 0, 0.96, 0)
    container.Size = UDim2.new(0, 0, 0.14, 0)
    container.AutomaticSize = Enum.AutomaticSize.X
    container.ZIndex = 2

    local layout = container:FindFirstChildOfClass("UIListLayout")
    if not layout then
        layout = Instance.new("UIListLayout")
        layout.Parent = container
    end
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, QUEUE_CARD_GAP)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

    queueCardsContainer = container :: Frame
    return queueCardsContainer
end

local function styleQueueLabel(lbl: TextLabel, textColor: Color3)
    lbl.TextColor3 = textColor
    lbl.TextStrokeTransparency = 1
    local stroke = lbl:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke:Destroy()
    end
end

local function clearQueueCards(container: Frame)
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") and child.Name == "QueuePlayerCard" then
            child:Destroy()
        end
    end
end

local function populateQueueCard(card: Frame, member: { userId: number?, name: string?, coins: number? }, isLocal: boolean)
    local avatarImg = card:FindFirstChild("AvatarImage")
    local nameLabel = card:FindFirstChild("PlayerName")
    local coinLabel = card:FindFirstChild("CoinLabel")

    card.Size = UDim2.new(0, isLocal and QUEUE_CARD_W or QUEUE_OTHER_CARD_W, 1, 0)
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.Position = UDim2.new(0, 0, 0, 0)

    local avSize = 72
    if avatarImg and avatarImg:IsA("ImageLabel") then
        avatarImg.Visible = true
        avatarImg.ImageTransparency = 0
        avatarImg.SizeConstraint = Enum.SizeConstraint.RelativeXY
        avatarImg.AnchorPoint = Vector2.new(0, 0.5)
        avatarImg.Position = UDim2.new(0, 10, 0.5, 0)
        avatarImg.Size = UDim2.new(0, avSize, 0, avSize)
        avatarImg.ZIndex = math.max(avatarImg.ZIndex, 3)
        loadAvatar(avatarImg, member.userId, member.name)
    end
    if nameLabel and nameLabel:IsA("TextLabel") then
        nameLabel.Text = member.name or "?"
        nameLabel.TextSize = 22
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.AnchorPoint = Vector2.new(0, 0.5)
        nameLabel.Position = UDim2.new(0, 10 + avSize + 8, 0.5, 0)
        nameLabel.Size = UDim2.new(1, -(10 + avSize + 8 + (isLocal and 96 or 12)), 0.7, 0)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextYAlignment = Enum.TextYAlignment.Center
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        styleQueueLabel(nameLabel, QUEUE_NAME_COLOR)
    end
    if coinLabel and coinLabel:IsA("TextLabel") then
        if isLocal then
            coinLabel.Visible = true
            coinLabel.Text = tostring(member.coins or 0) .. " Coins"
            coinLabel.TextSize = 18
            coinLabel.Font = Enum.Font.GothamBold
            coinLabel.AnchorPoint = Vector2.new(1, 1)
            coinLabel.Position = UDim2.new(1, -10, 1, -6)
            coinLabel.Size = UDim2.new(0.55, 0, 0, 22)
            coinLabel.TextXAlignment = Enum.TextXAlignment.Right
            coinLabel.TextYAlignment = Enum.TextYAlignment.Bottom
            coinLabel.ZIndex = math.max(coinLabel.ZIndex, 4)
            styleQueueLabel(coinLabel, QUEUE_COIN_COLOR)
        else
            coinLabel.Visible = false
        end
    end
end

local function normalizeMemberList(raw)
    if type(raw) ~= "table" then
        return {{
            userId = LocalPlayer.UserId,
            name = LocalPlayer.Name,
        }}
    end

    local list = {}
    if #raw > 0 then
        for _, member in ipairs(raw) do
            if type(member) == "table" then
                table.insert(list, {
                    userId = tonumber(member.userId),
                    name = member.name or member.Name or "?",
                })
            end
        end
    else
        for _, member in pairs(raw) do
            if type(member) == "table" then
                table.insert(list, {
                    userId = tonumber(member.userId),
                    name = member.name or member.Name or "?",
                })
            end
        end
    end

    if #list == 0 then
        return {{
            userId = LocalPlayer.UserId,
            name = LocalPlayer.Name,
        }}
    end
    return list
end

local function handleLobby(currentCount, maxCount, members, countdown)
    showFrame(lobbyFrame)

    local wl = lobbyFrame:FindFirstChild("WaitingLabel", true)
    if wl then
        wl.Text = "Waiting for players: " .. (currentCount or 1) .. "/" .. (maxCount or 3)
    end

    local cd = lobbyFrame:FindFirstChild("QueueCountdown")
    if not cd then
        cd = Instance.new("TextLabel")
        cd.Name = "QueueCountdown"
        cd.BackgroundTransparency = 1
        cd.AnchorPoint = Vector2.new(0.5, 0)
        cd.Position = UDim2.new(0.5, 0, 0, 10)
        cd.Size = UDim2.new(0, 320, 0, 36)
        cd.Font = Enum.Font.GothamBold
        cd.TextSize = 22
        cd.TextColor3 = Color3.fromRGB(255, 240, 120)
        cd.TextTransparency = 0.15
        cd.ZIndex = 8
        cd.Parent = lobbyFrame
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(20, 10, 50)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.25
        stroke.Parent = cd
    end
    cd.AnchorPoint = Vector2.new(0.5, 0)
    cd.Position = UDim2.new(0.5, 0, 0, 10)
    cd.ZIndex = 8
    local n = tonumber(countdown)
    if n and n > 0 then
        cd.Visible = true
        cd.Text = "Starting in " .. n
    else
        cd.Visible = false
        cd.Text = ""
    end

    local template = lobbyFrame:FindFirstChild("PlayerCard")
    local exitBtn = lobbyFrame:FindFirstChild("ExitQueueButton")
    if exitBtn then
        exitBtn.Text = "Leave Queue"
        exitBtn.Font = Enum.Font.Gotham
        exitBtn.TextScaled = false
        exitBtn.TextSize = 18
        exitBtn.TextColor3 = Color3.fromRGB(230, 225, 240)
        exitBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        exitBtn.BackgroundTransparency = 0.85
        exitBtn.AutoButtonColor = true
        exitBtn.AnchorPoint = Vector2.new(1, 0)
        exitBtn.Position = UDim2.new(1, -16, 0, 16)
        exitBtn.Size = UDim2.new(0, 168, 0, 42)
        exitBtn.ZIndex = 12
        if not exitBtn:FindFirstChildOfClass("UICorner") then
            addCorner(exitBtn, 8)
        end
        local es = exitBtn:FindFirstChildOfClass("UIStroke")
        if es then
            es.Thickness = 1
            es.Transparency = 0.4
            es.Color = Color3.fromRGB(220, 210, 240)
        end
        local cap = exitBtn:FindFirstChildOfClass("UITextSizeConstraint")
        if cap then
            cap:Destroy()
        end
        if not exitBtn:GetAttribute("Wired") then
            exitBtn:SetAttribute("Wired", true)
            addClickSound(exitBtn)
            exitBtn.MouseButton1Click:Connect(function()
                LeaveQueueRequest:FireServer()
            end)
        end
    end

    if not template or not template:IsA("Frame") then
        return
    end
    template.Visible = false

    local container = ensureQueueCardsContainer()
    clearQueueCards(container)

    local memberList = normalizeMemberList(members)

    table.sort(memberList, function(a, b)
        local aLocal = a.userId == LocalPlayer.UserId
        local bLocal = b.userId == LocalPlayer.UserId
        if aLocal ~= bLocal then
            return aLocal
        end
        return (a.userId or 0) < (b.userId or 0)
    end)

    for i, member in ipairs(memberList) do
        local card = template:Clone()
        card.Name = "QueuePlayerCard"
        card.Visible = true
        card.LayoutOrder = i
        card.Parent = container

        local isLocal = member.userId == LocalPlayer.UserId
        populateQueueCard(card, member, isLocal)

        if isLocal then
            task.spawn(function()
                local ok, coins = pcall(function()
                    return GetCoins:InvokeServer()
                end)
                local coinLabel = card:FindFirstChild("CoinLabel")
                if coinLabel and coinLabel:IsA("TextLabel") then
                    coinLabel.Text = tostring((ok and coins) or 0) .. " Coins"
                end
            end)
        end
    end
end

local function handleWrite(timeLimit)
    showFrame(writeFrame)
    submitGen += 1
    local gen = submitGen
    local waitTime = timeLimit or Config.WRITE_TIME
    local WRITE_W = 0.55

    local pl = writeFrame:FindFirstChild("PromptLabel", true)
    local wfHdr = pl and pl.Parent
    if wfHdr and wfHdr:IsA("GuiObject") and wfHdr ~= writeFrame then
        wfHdr.Size = UDim2.new(WRITE_W, 0, 0.12, 0)
        wfHdr.AnchorPoint = Vector2.new(0.5, 0)
        wfHdr.Position = UDim2.new(0.5, 0, 0.18, 0)
        wfHdr.ClipsDescendants = false
        local pad = wfHdr:FindFirstChildOfClass("UIPadding")
        if not pad then
            pad = Instance.new("UIPadding")
            pad.Parent = wfHdr
        end
        pad.PaddingLeft = UDim.new(0.03, 8)
        pad.PaddingRight = UDim.new(0.03, 8)
    end
    if pl then
        pl.Text = "What should the next person draw 🤔?"
        pl.Size = UDim2.new(1, 0, 1, 0)
        pl.Position = UDim2.new(0, 0, 0, 0)
        pl.AnchorPoint = Vector2.new(0, 0)
        fitHeaderLabel(pl, 40)
        pl.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    local ip = writeFrame:FindFirstChild("ImagePreview")
    if ip then ip.Visible = false end

    local tb = writeFrame:FindFirstChild("TextInputBox")
    if tb then
        tb.AnchorPoint = Vector2.new(0.5, 0)
        tb.Position    = UDim2.new(0.5, 0, 0.38, 0)
        tb.Size        = UDim2.new(WRITE_W, 0, 0.1, 0)
        tb.PlaceholderText = "Write your sentence here..."
        tb.TextXAlignment = Enum.TextXAlignment.Center
        tb.TextYAlignment = Enum.TextYAlignment.Center
        tb.TextScaled = true
        tb.Font = Enum.Font.GothamBold
        local tbCap = tb:FindFirstChildOfClass("UITextSizeConstraint")
        if not tbCap then
            tbCap = Instance.new("UITextSizeConstraint")
            tbCap.Parent = tb
        end
        tbCap.MinTextSize = 20
        tbCap.MaxTextSize = 32
    end

    local submitBtn = writeFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.Size = UDim2.new(WRITE_W, 0, 0.09, 0)
        submitBtn.AnchorPoint = Vector2.new(0.5, 0)
        submitBtn.Position = UDim2.new(0.5, 0, 0.56, 0)
        submitBtn.TextXAlignment = Enum.TextXAlignment.Center
        submitBtn.TextYAlignment = Enum.TextYAlignment.Center
        submitBtn.TextScaled = true
        submitBtn.Font = Enum.Font.GothamBold
        local sCap = submitBtn:FindFirstChildOfClass("UITextSizeConstraint")
        if not sCap then
            sCap = Instance.new("UITextSizeConstraint")
            sCap.Parent = submitBtn
        end
        sCap.MinTextSize = 20
        sCap.MaxTextSize = 32
    end

    local textBox   = writeFrame:FindFirstChild("TextInputBox")
    local submitted = false

    local function sendWrite()
        if submitted or gen ~= submitGen then return end
        submitted = true
        local inputTxt = textBox and textBox.Text ~= "" and textBox.Text
        local txt = inputTxt
        if not txt then
            local ok, fallback = pcall(function()
                return GetFallbackText:InvokeServer()
            end)
            txt = (ok and fallback) or "A surprise drawing"
        end
        SubmitText:FireServer(txt)
        if submitBtn then
            submitBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
            submitBtn.Text = "Submitted!"
        end
    end

    if textBox then
        textBox.Text = ""
        if textBox:IsA("TextBox") then
            textBox:ReleaseFocus()
        end
    end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "Submit"
        local conn
        conn = submitBtn.MouseButton1Click:Connect(function()
            if conn then conn:Disconnect() end
            sendWrite()
        end)
    end
    task.delay(math.max(0.2, waitTime - 0.35), sendWrite)
end

local function fitPaletteScroll(tp)
    if not (tp and tp:IsA("ScrollingFrame")) then
        return
    end
    local maxB = 0
    for _, ch in ipairs(tp:GetChildren()) do
        if ch:IsA("GuiObject") then
            maxB = math.max(maxB, ch.Position.Y.Offset + ch.Size.Y.Offset)
        end
    end
    tp.ScrollingEnabled = true
    tp.ScrollBarThickness = 8
    tp.VerticalScrollBarInset = Enum.ScrollBarInset.None
    tp.AutomaticCanvasSize = Enum.AutomaticSize.None
    tp.CanvasSize = UDim2.new(0, 0, 0, math.max(maxB + 24, 1))
    tp.CanvasPosition = Vector2.new(0, 0)
end

local function handleDraw(timeLimit, roundData)
    showFrame(drawFrame)
    local PAL_W = 150

    local pl = drawFrame:FindFirstChild("PromptLabel", true)
    local hdr = pl and pl.Parent
    if pl then
        pl.Text = (roundData and roundData.content)
                  and ("Draw: \"" .. tostring(roundData.content) .. "\"")
                  or  "Waiting for prompt..."
        fitHeaderLabel(pl, 32)
        pl.TextColor3 = Color3.fromRGB(255, 255, 255)
        if hdr and hdr:IsA("GuiObject") and hdr ~= drawFrame then
            hdr.ClipsDescendants = false
            local pad = hdr:FindFirstChildOfClass("UIPadding")
            if not pad then
                pad = Instance.new("UIPadding")
                pad.Parent = hdr
            end
            pad.PaddingLeft = UDim.new(0.02, 8)
            pad.PaddingRight = UDim.new(0.02, 8)
        end
    end

    local canvas = drawFrame:FindFirstChild("Canvas")
    local submitBtn = drawFrame:FindFirstChild("SubmitButton")
    local toolPanel = drawFrame:FindFirstChild("ToolPanel")

    local function stripLock(gui)
        if not (gui and gui:IsA("GuiObject")) then
            return
        end
        gui.AutomaticSize = Enum.AutomaticSize.None
        for _, c in ipairs(gui:GetChildren()) do
            if c:IsA("UISizeConstraint") or c:IsA("UIAspectRatioConstraint") or c:IsA("UIScale") then
                c:Destroy()
            end
        end
    end
    stripLock(hdr)
    stripLock(canvas)
    stripLock(submitBtn)

    if toolPanel and toolPanel:IsA("GuiObject") then
        local pal = toolPanel:FindFirstChild("PaletteScale")
        if pal then pal:Destroy() end
        local palPad = toolPanel:FindFirstChild("PalettePad")
        if palPad then palPad:Destroy() end
        toolPanel.AnchorPoint = Vector2.new(1, 0.5)
        toolPanel.Position = UDim2.new(0.965, 0, 0.5, 0)
        toolPanel.Size = UDim2.new(0, PAL_W, 0.78, 0)
        toolPanel.VerticalScrollBarInset = Enum.ScrollBarInset.None
        local GAP = 6
        for i = 1, 10 do
            local btn = toolPanel:FindFirstChild("ColorBtn_" .. i)
            if btn and btn:IsA("GuiObject") then
                local leftCol = (i % 2 == 1)
                btn.AnchorPoint = leftCol and Vector2.new(1, 0) or Vector2.new(0, 0)
                btn.Position = UDim2.new(0.5, leftCol and -GAP or GAP, 0, btn.Position.Y.Offset)
                btn.Size = UDim2.fromOffset(56, 56)
            end
        end
        fitPaletteScroll(toolPanel)
    end

    local function layoutCol()
        local ux = select(1, UiScaler.unscaledSize(drawFrame))
        ux = math.max(ux, 1)
        local palFrac = PAL_W / ux + 0.05
        local leftPad = 0.04
        local colW = math.clamp(1 - palFrac - leftPad, 0.45, 0.82)
        local mid = leftPad + colW * 0.5
        local top = 0.05
        local hdrH = 0.08
        local gap = 0.02
        local subH = 0.07
        local timH = 0.07
        local bot = 0.02
        local canvasH = 1 - top - bot - hdrH - subH - timH - gap * 3
        if hdr and hdr:IsA("GuiObject") and hdr ~= drawFrame then
            hdr.AnchorPoint = Vector2.new(0.5, 0)
            hdr.Position = UDim2.new(mid, 0, top, 0)
            hdr.Size = UDim2.new(colW, 0, hdrH, 0)
        end
        if canvas and canvas:IsA("GuiObject") then
            canvas.AnchorPoint = Vector2.new(0.5, 0)
            canvas.Position = UDim2.new(mid, 0, top + hdrH + gap, 0)
            canvas.Size = UDim2.new(colW, 0, canvasH, 0)
        end
        local subY = top + hdrH + gap + canvasH + gap
        if submitBtn and submitBtn:IsA("GuiObject") then
            submitBtn.AnchorPoint = Vector2.new(0.5, 0)
            submitBtn.Position = UDim2.new(mid, 0, subY, 0)
            submitBtn.Size = UDim2.new(colW, 0, subH, 0)
            submitBtn.TextScaled = true
            local sCap = submitBtn:FindFirstChildOfClass("UITextSizeConstraint")
            if not sCap then
                sCap = Instance.new("UITextSizeConstraint")
                sCap.Parent = submitBtn
            end
            sCap.MinTextSize = 14
            sCap.MaxTextSize = 22
        end
        local timer = drawFrame:FindFirstChild("TimerContainer")
        if timer and timer:IsA("GuiObject") then
            timer.AnchorPoint = Vector2.new(0.5, 0)
            timer.Position = UDim2.new(mid, 0, subY + subH + gap, 0)
            timer.Size = UDim2.new(colW, 0, timH, 0)
            timer.ZIndex = 30
            timer.BackgroundTransparency = 1
            local timeLbl = timer:FindFirstChild("TimeLabel")
            local submitLbl = timer:FindFirstChild("SubmitLabel")
            if timeLbl and timeLbl:IsA("GuiObject") then
                timeLbl.AnchorPoint = Vector2.new(0.5, 0)
                timeLbl.Position = UDim2.new(0.5, 0, 0, 0)
                timeLbl.Size = UDim2.new(1, 0, 0.5, 0)
                timeLbl.ZIndex = 31
                timeLbl.Visible = true
            end
            if submitLbl and submitLbl:IsA("GuiObject") then
                submitLbl.AnchorPoint = Vector2.new(0.5, 0)
                submitLbl.Position = UDim2.new(0.5, 0, 0.5, 0)
                submitLbl.Size = UDim2.new(1, 0, 0.5, 0)
                submitLbl.ZIndex = 31
                submitLbl.Visible = true
            end
        end
    end
    layoutCol()
    task.defer(layoutCol)

    local signals = ReplicatedStorage:FindFirstChild("Signals")
    local ev = signals and signals:FindFirstChild("DrawActiveEvent")
    if ev then ev:Fire(true) end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "Submit"
        addClickSound(submitBtn)
    end
end

local function fireStrokes(canvas, content)
    if not canvas or type(content) ~= "table" then return end
    local signals = ReplicatedStorage:FindFirstChild("Signals")
    local renderEv = signals and signals:FindFirstChild("RenderStrokesEvent")
    if not renderEv then return end
    task.spawn(function()
        for _ = 1, 12 do
            if canvas.AbsoluteSize.X > 4 and canvas.AbsoluteSize.Y > 4 then break end
            task.wait(0.05)
        end
        renderEv:Fire(canvas, content)
    end)
end

local function handleDescribe(timeLimit, roundData)
    showFrame(writeFrame)
    submitGen += 1
    local gen = submitGen
    local waitTime = timeLimit or Config.DESCRIBE_TIME

    if writeFrame.AbsoluteSize.X <= 1 then
        task.wait()
    end

    local pl = writeFrame:FindFirstChild("PromptLabel", true)
    if pl then
        pl.Text = "Describe this image:"
        pl.Size = UDim2.new(1, 0, 1, 0)
        pl.Position = UDim2.new(0, 0, 0, 0)
        fitHeaderLabel(pl, 36)
        pl.TextColor3 = Color3.fromRGB(255, 255, 255)
        local hdr = pl.Parent
        if hdr and hdr:IsA("GuiObject") and hdr ~= writeFrame then
            hdr.ClipsDescendants = false
        end
    end
    local CANVAS_ASPECT = CANVAS_W / CANVAS_H
    local DESC_W = 0.55
    local IMG_W = 0.78

    local ip = writeFrame:FindFirstChild("ImagePreview")
    if ip then
        ip.Visible     = true
        ip.Size        = UDim2.new(IMG_W, 0, 0.52, 0)
        ip.AnchorPoint = Vector2.new(0.5, 0)
        ip.Position    = UDim2.new(0.5, 0, 0.15, 0)
        ip.ClipsDescendants = false
        ip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ip.ZIndex = 3
        local ar = ip:FindFirstChildOfClass("UIAspectRatioConstraint")
        if not ar then
            ar = Instance.new("UIAspectRatioConstraint")
            ar.Parent = ip
        end
        ar.AspectRatio = CANVAS_ASPECT
        ar.DominantAxis = Enum.DominantAxis.Width
        for _, c in ipairs(ip:GetChildren()) do
            if c:IsA("Frame") and (c.Name == "Dot" or c.Name == "Seg" or c.Name == "StrokeLayer") then
                c:Destroy()
            end
        end
        local border = ip:FindFirstChild("PreviewStroke")
        if not border then
            border = Instance.new("UIStroke")
            border.Name = "PreviewStroke"
            border.Parent = ip
        end
        border.Color = Color3.fromRGB(40, 30, 80)
        border.Thickness = 2
        border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        fireStrokes(ip, roundData and roundData.content)
    end

    local function placeCentered(gui, yScale, hScale)
        gui.AnchorPoint = Vector2.new(0.5, 0)
        gui.Position = UDim2.new(0.5, 0, yScale, 0)
        gui.Size = UDim2.new(DESC_W, 0, hScale, 0)
    end

    local wfHdr = writeFrame:FindFirstChildOfClass("Frame")
    if wfHdr and wfHdr.Name ~= "ImagePreview" and wfHdr.Name ~= "TimerContainer" then
        wfHdr.ClipsDescendants = true
        placeCentered(wfHdr, 0.04, 0.09)
    end

    local tb2 = writeFrame:FindFirstChild("TextInputBox")
    if tb2 then
        tb2.PlaceholderText = "Describe the image..."
        tb2.TextXAlignment  = Enum.TextXAlignment.Center
        tb2.TextYAlignment  = Enum.TextYAlignment.Center
        tb2.TextWrapped     = true
        tb2.TextScaled      = true
        placeCentered(tb2, 0.74, 0.09)
        local tbCap = tb2:FindFirstChildOfClass("UITextSizeConstraint")
        if not tbCap then
            tbCap = Instance.new("UITextSizeConstraint")
            tbCap.Parent = tb2
        end
        tbCap.MinTextSize = 18
        tbCap.MaxTextSize = 28
    end

    local submitBtn = writeFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.TextXAlignment = Enum.TextXAlignment.Center
        submitBtn.TextScaled = true
        placeCentered(submitBtn, 0.86, 0.07)
        local sCap = submitBtn:FindFirstChildOfClass("UITextSizeConstraint")
        if not sCap then
            sCap = Instance.new("UITextSizeConstraint")
            sCap.Parent = submitBtn
        end
        sCap.MinTextSize = 16
        sCap.MaxTextSize = 26
    end

    local textBox  = writeFrame:FindFirstChild("TextInputBox")
    local submitted = false

    local function sendDescribe()
        if submitted or gen ~= submitGen then return end
        submitted = true
        local txt = (textBox and textBox.Text ~= "") and textBox.Text
            or "Jokes on me: I was too silly to write anything!"
        SubmitText:FireServer(txt)
        if submitBtn then
            submitBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
            submitBtn.Text = "Submitted!"
        end
    end

    if textBox then
        textBox.Text = ""
        if textBox:IsA("TextBox") then
            textBox:ReleaseFocus()
        end
    end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "Submit"
        local conn
        conn = submitBtn.MouseButton1Click:Connect(function()
            if conn then conn:Disconnect() end
            sendDescribe()
        end)
    end
    task.delay(math.max(0.2, waitTime - 0.35), sendDescribe)
end

local function showChainInMainWindow(chain, mainWindow)
    if not mainWindow then return end
    for _, c in ipairs(mainWindow:GetChildren()) do
        if c.Name == "EntryItem" or c.Name == "AlbumTitleRow"
            or c:IsA("UIListLayout") or c:IsA("UIPadding") then
            c:Destroy()
        elseif c.Name == "AlbumTitle" then
            c.Visible = false
        end
    end

    local titleRow = Instance.new("Frame")
    titleRow.Name = "AlbumTitleRow"
    titleRow.BackgroundTransparency = 1
    titleRow.Size = UDim2.new(0.94, 0, 0, 56)
    titleRow.LayoutOrder = 0
    titleRow.Parent = mainWindow

    local titleLay = Instance.new("UIListLayout")
    titleLay.FillDirection = Enum.FillDirection.Horizontal
    titleLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    titleLay.VerticalAlignment = Enum.VerticalAlignment.Center
    titleLay.Padding = UDim.new(0, REVIEW.AV_GAP)
    titleLay.SortOrder = Enum.SortOrder.LayoutOrder
    titleLay.Parent = titleRow

    local titleAv = makeReviewAvatar(titleRow, REVIEW.AV_SIZE, chain.startPlayerName, 6, chain.startPlayerUserId)
    titleAv.LayoutOrder = 1
    titleAv.Size = UDim2.new(0, REVIEW.AV_SIZE, 0, REVIEW.AV_SIZE)

    local albumTitle = Instance.new("TextLabel")
    albumTitle.Name = "AlbumTitle"
    albumTitle.LayoutOrder = 2
    albumTitle.AutomaticSize = Enum.AutomaticSize.X
    albumTitle.Size = UDim2.new(0, 0, 1, 0)
    albumTitle.Text = chain.startPlayerName:upper() .. "'S ALBUM"
    albumTitle.TextXAlignment = Enum.TextXAlignment.Left
    albumTitle.TextTruncate = Enum.TextTruncate.None
    albumTitle.ZIndex = 6
    albumTitle.Parent = titleRow
    applyReviewText(albumTitle, 26, true)
    albumTitle.TextScaled = false
    albumTitle.TextSize = 26

    local list = mainWindow:FindFirstChildOfClass("UIListLayout")
    if not list then
        list = Instance.new("UIListLayout")
        list.Parent = mainWindow
    end
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 10)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local pad = mainWindow:FindFirstChildOfClass("UIPadding")
    if not pad then
        pad = Instance.new("UIPadding")
        pad.Parent = mainWindow
    end
    pad.PaddingTop = UDim.new(0.02, 0)
    pad.PaddingBottom = UDim.new(0.02, 0)
    pad.PaddingLeft = UDim.new(0.03, 0)
    pad.PaddingRight = UDim.new(0.03, 0)

    local ASPECT = CANVAS_W / CANVAS_H

    for i, entry in ipairs(chain.entries) do
        local isDrawing = (entry.type == "drawing")
        local authorName = tostring(entry.author or "")
        local authorUserId = entry.authorUserId
        local textBody = ""
        if not isDrawing then
            if type(entry.content) == "string" and entry.content ~= "" then
                textBody = entry.content
            else
                textBody = "(no submission)"
            end
        end

        local item = Instance.new("Frame")
        item.Name              = "EntryItem"
        item.AutomaticSize     = Enum.AutomaticSize.Y
        item.Size              = UDim2.new(1, 0, 0, 0)
        item.BackgroundColor3  = REVIEW.ENTRY
        item.BorderSizePixel   = 0
        item.ClipsDescendants  = false
        item.LayoutOrder       = i
        item.Parent            = mainWindow
        addCorner(item, 12)
        local iStroke = Instance.new("UIStroke")
        iStroke.Color        = REVIEW.CARD_STROKE
        iStroke.Thickness    = 1.5
        iStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        iStroke.Parent       = item

        local itemLay = Instance.new("UIListLayout")
        itemLay.SortOrder = Enum.SortOrder.LayoutOrder
        itemLay.Padding = UDim.new(0, 16)
        itemLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
        itemLay.Parent = item

        local itemPad = Instance.new("UIPadding")
        itemPad.PaddingTop = UDim.new(0, 10)
        itemPad.PaddingBottom = UDim.new(0, 12)
        itemPad.PaddingLeft = UDim.new(0, 12)
        itemPad.PaddingRight = UDim.new(0, 12)
        itemPad.Parent = item

        local header = Instance.new("Frame")
        header.Name = "EntryHeader"
        header.BackgroundTransparency = 1
        header.Size = UDim2.new(1, 0, 0, REVIEW.AV_SIZE)
        header.LayoutOrder = 1
        header.Parent = item

        local authAv = makeReviewAvatar(header, REVIEW.AV_SIZE, authorName, 6, authorUserId)
        local auth = Instance.new("TextLabel")
        auth.Text              = authorName
        auth.TextTruncate      = Enum.TextTruncate.AtEnd
        auth.ZIndex            = 6
        auth.Parent            = header
        applyReviewText(auth, 18, false)
        layoutIconName(authAv, auth, REVIEW.AV_SIZE, 8)

        if isDrawing then
            local dc = Instance.new("Frame")
            dc.Name             = "DrawPreview"
            dc.LayoutOrder      = 2
            dc.Size             = UDim2.new(1, 0, 0, 160)
            dc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            dc.BorderSizePixel  = 0
            dc.ClipsDescendants = false
            dc.Parent           = item
            addCorner(dc, 8)
            local border = Instance.new("UIStroke")
            border.Color = Color3.fromRGB(40, 30, 80)
            border.Thickness = 2
            border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            border.Parent = dc
            task.defer(function()
                if not dc.Parent then return end
                local w = dc.AbsoluteSize.X
                if w > 4 then
                    dc.Size = UDim2.new(1, 0, 0, math.floor(w / ASPECT + 0.5))
                end
            end)
            if type(entry.content) == "table" then
                fireStrokes(dc, entry.content)
            end
        else
            local tl = Instance.new("TextLabel")
            tl.LayoutOrder       = 2
            tl.AutomaticSize     = Enum.AutomaticSize.Y
            tl.Size              = UDim2.new(1, 0, 0, 0)
            tl.Text              = textBody
            tl.TextXAlignment    = Enum.TextXAlignment.Left
            tl.TextYAlignment    = Enum.TextYAlignment.Top
            tl.TextWrapped       = true
            tl.ZIndex            = 6
            tl.Parent            = item
            applyReviewText(tl, 20, false)
            tl.TextScaled = false
        end
    end

    if mainWindow:IsA("ScrollingFrame") then
        mainWindow.AutomaticCanvasSize = Enum.AutomaticSize.Y
        mainWindow.CanvasSize = UDim2.new(0, 0, 0, 0)
        mainWindow.ScrollBarThickness = 8
        mainWindow.BackgroundColor3 = REVIEW.RIGHT_BG
        mainWindow.BackgroundTransparency = 0
        mainWindow.ClipsDescendants = true
        mainWindow.ScrollBarImageColor3 = REVIEW.CARD_STROKE
    end
end

local function buildRankingPanel(rankingPanel, playerNames)
    if not rankingPanel then return end

    for _, c in ipairs(rankingPanel:GetChildren()) do c:Destroy() end

    local function normalizeRankEntry(entry)
        if type(entry) == "string" then
            return entry, nil
        end
        if type(entry) == "table" then
            return entry.name or entry.Name, tonumber(entry.userId)
        end
        return nil, nil
    end

    local others = {}
    local userIdByName = {}
    for _, entry in ipairs(playerNames) do
        local name, uid = normalizeRankEntry(entry)
        if name and name ~= LocalPlayer.Name then
            table.insert(others, name)
            userIdByName[name] = uid
        end
    end
    if #others == 0 then
        for _, entry in ipairs(playerNames) do
            local name, uid = normalizeRankEntry(entry)
            if name then
                table.insert(others, name)
                userIdByName[name] = uid
            end
        end
    end
    if #others == 0 then return end

    local SWAP_T  = 0.15
    local rowCount = math.max(#others, 1)
    local rowScale = math.clamp(0.86 / rowCount - 0.04, 0.18, 0.3)

    local title = Instance.new("TextLabel")
    title.Name = "RankTitle"
    title.Size = UDim2.new(0.94, 0, 0.12, 0)
    title.Position = UDim2.new(0.03, 0, 0.02, 0)
    title.Text = "Rank the others"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.ClipsDescendants = true
    title.ZIndex = 2
    title.Parent = rankingPanel
    applyReviewText(title, 20, true)
    title.TextWrapped = false
    title.TextScaled = true
    title.TextTruncate = Enum.TextTruncate.AtEnd

    local listContainer = Instance.new("Frame")
    listContainer.Name = "RankList"
    listContainer.BackgroundTransparency = 1
    listContainer.Size = UDim2.new(1, 0, 0.54, 0)
    listContainer.Position = UDim2.new(0, 0, 0.22, 0)
    listContainer.ClipsDescendants = false
    listContainer.ZIndex = 8
    listContainer.Parent = rankingPanel
    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 6)
    listPad.PaddingLeft = UDim.new(0, 4)
    listPad.PaddingRight = UDim.new(0, 4)
    listPad.Parent = listContainer

    local rowOrder = {}
    for _, name in ipairs(others) do table.insert(rowOrder, name) end

    local animating = false

    local function rowY(i)
        return (i - 1) * (rowScale + 0.04)
    end

    local function renderRows()
        for _, c in ipairs(listContainer:GetChildren()) do c:Destroy() end
        for i, name in ipairs(rowOrder) do
            local row = Instance.new("Frame")
            row.Name = "Row_"..i
            row.Size = UDim2.new(0.97, 0, rowScale, 0)
            row.Position = UDim2.new(0.015, 0, rowY(i), 0)
            row.BackgroundColor3 = REVIEW.ROW
            row.BorderSizePixel = 0
            row.ZIndex = 9
            row.Parent = listContainer
            addCorner(row, 8)
            local st = Instance.new("UIStroke")
            st.Color = REVIEW.CARD_STROKE
            st.Thickness = 2
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.Parent = row

            local rn = Instance.new("TextLabel")
            rn.Size = UDim2.new(0, 28, 1, 0)
            rn.BackgroundTransparency = 1
            rn.Text = i .. "."
            rn.TextXAlignment = Enum.TextXAlignment.Center
            rn.Parent = row
            applyReviewText(rn, 17, true)
            rn.TextScaled = true

            local av = makeReviewAvatar(row, REVIEW.AV_SIZE, name, 6, userIdByName[name])
            av.AnchorPoint = Vector2.new(0, 0.5)
            av.Size = UDim2.new(0, REVIEW.AV_SIZE, 0, REVIEW.AV_SIZE)
            av.Position = UDim2.new(0, 30, 0.5, 0)

            local nl = Instance.new("TextLabel")
            nl.AnchorPoint = Vector2.new(0, 0.5)
            nl.Size = UDim2.new(0.38, 0, 1, 0)
            nl.Position = UDim2.new(0, 30 + REVIEW.AV_SIZE + REVIEW.AV_GAP, 0.5, 0)
            nl.Text = name
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.TextYAlignment = Enum.TextYAlignment.Center
            nl.TextTruncate = Enum.TextTruncate.AtEnd
            nl.Parent = row
            applyReviewText(nl, 17, false)
            nl.TextScaled = true

            local as = Instance.new("Frame")
            as.Size = UDim2.new(0.28, 0, 0.72, 0)
            as.AnchorPoint = Vector2.new(1, 0.5)
            as.Position = UDim2.new(0.98, 0, 0.5, 0)
            as.BackgroundTransparency = 1
            as.Parent = row

            local dn = Instance.new("TextButton")
            dn.Size = UDim2.new(0.47, 0, 1, 0)
            dn.Position = UDim2.new(0, 0, 0, 0)
            dn.Text = "v"
            dn.Font = Enum.Font.GothamBlack
            dn.TextScaled = true
            dn.BorderSizePixel = 0
            dn.BackgroundColor3 = i == #rowOrder and Color3.fromRGB(120, 100, 180) or Color3.fromRGB(220, 70, 90)
            dn.TextColor3 = Color3.fromRGB(255, 255, 255)
            dn.Parent = as
            addCorner(dn, 6)

            local up = Instance.new("TextButton")
            up.Size = UDim2.new(0.47, 0, 1, 0)
            up.Position = UDim2.new(0.53, 0, 0, 0)
            up.Text = "^"
            up.Font = Enum.Font.GothamBlack
            up.TextScaled = true
            up.BorderSizePixel = 0
            up.BackgroundColor3 = i == 1 and Color3.fromRGB(120, 100, 180) or Color3.fromRGB(55, 200, 110)
            up.TextColor3 = Color3.fromRGB(255, 255, 255)
            up.Parent = as
            addCorner(up, 6)

            row.MouseEnter:Connect(function()
                TweenService:Create(st, TweenInfo.new(0.12), { Thickness = 3, Color = Color3.fromRGB(240, 220, 255) }):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(st, TweenInfo.new(0.12), { Thickness = 2, Color = REVIEW.CARD_STROKE }):Play()
            end)

            local ci = i
            local function swapWith(target)
                if animating or target < 1 or target > #rowOrder then return end
                animating = true
                local a = listContainer:FindFirstChild("Row_" .. ci)
                local b = listContainer:FindFirstChild("Row_" .. target)
                if a and b then
                    local twA = TweenService:Create(a, TweenInfo.new(SWAP_T, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0.015, 0, rowY(target), 0),
                        BackgroundColor3 = Color3.fromRGB(100, 80, 170),
                    })
                    local twB = TweenService:Create(b, TweenInfo.new(SWAP_T, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0.015, 0, rowY(ci), 0),
                        BackgroundColor3 = Color3.fromRGB(100, 80, 170),
                    })
                    twA:Play(); twB:Play()
                    twA.Completed:Wait()
                end
                rowOrder[ci], rowOrder[target] = rowOrder[target], rowOrder[ci]
                animating = false
                renderRows()
            end

            addClickSound(up)
            up.MouseButton1Click:Connect(function()
                swapWith(ci - 1)
            end)
            addClickSound(dn)
            dn.MouseButton1Click:Connect(function()
                swapWith(ci + 1)
            end)
        end
    end

    renderRows()

    local submitBtn = Instance.new("TextButton")
    submitBtn.Name = "SubmitRankingBtn"
    submitBtn.Size = UDim2.new(0.94, 0, 0.16, 0)
    submitBtn.AnchorPoint = Vector2.new(0, 1)
    submitBtn.Position = UDim2.new(0.03, 0, 0.98, 0)
    submitBtn.BackgroundColor3 = Color3.fromRGB(55, 215, 120)
    submitBtn.TextColor3 = Color3.fromRGB(255,255,255)
    submitBtn.Text = "Submit Ranking"
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextScaled = false
    submitBtn.TextSize = 15
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = rankingPanel
    addCorner(submitBtn, 8)

    rankingPanel.BackgroundTransparency = 1
    rankingPanel.ClipsDescendants = false

    local pulse = TweenService:Create(submitBtn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        BackgroundColor3 = Color3.fromRGB(80, 240, 140),
    })
    pulse:Play()

    local rankSubmitted = false
    submitBtn.MouseButton1Click:Connect(function()
        if rankSubmitted then return end
        rankSubmitted = true
        pulse:Cancel()
        SubmitRanking:FireServer(rowOrder)
        submitBtn.BackgroundColor3 = Color3.fromRGB(80,130,80)
        submitBtn.Text = "Submitted!"
        TweenService:Create(submitBtn, TweenInfo.new(0.2), {
            Size = UDim2.new(0.96, 0, 0.18, 0),
        }):Play()
        task.delay(0.2, function()
            if submitBtn.Parent then
                TweenService:Create(submitBtn, TweenInfo.new(0.2), {
                    Size = UDim2.new(0.94, 0, 0.16, 0),
                }):Play()
            end
        end)
    end)
end

local function handleReview(reviewData, playerNames, totalTime)
    showFrame(reviewFrame)

    reviewFrame.BackgroundTransparency = 1
    local grad = reviewFrame:FindFirstChildOfClass("UIGradient")
    if grad then grad.Enabled = false end

    local leftPanel    = reviewFrame:FindFirstChild("LeftPanel")
    local mainWindow   = reviewFrame:FindFirstChild("MainWindow")
    local playersPanel = leftPanel and leftPanel:FindFirstChild("PlayersPanel")
    local rankingPanel = leftPanel and leftPanel:FindFirstChild("RankingPanel")
    local timer        = leftPanel and leftPanel:FindFirstChild("TimerContainer")
        or reviewFrame:FindFirstChild("TimerContainer")

    local panelH = 1 - REVIEW.PAD_Y - REVIEW.PAD_B
    local startX = reviewStartX()
    local leftX = startX
    local rightX = startX + REVIEW.PANEL_W + REVIEW.GAP

    ensureReviewPhaseTitle(reviewFrame)

    if leftPanel then
        leftPanel.BackgroundTransparency = 1
        leftPanel.BorderSizePixel = 0
        leftPanel.ClipsDescendants = false
        leftPanel.AnchorPoint = Vector2.new(0, 0)
        leftPanel.Position = UDim2.new(leftX, 0, REVIEW.PAD_Y, 0)
        leftPanel.Size = UDim2.new(REVIEW.PANEL_W, 0, panelH, 0)
        leftPanel.ZIndex = 2

        for _, c in ipairs(leftPanel:GetChildren()) do
            if c:IsA("Frame") and c.Name ~= "AlbumCard" and c.Name ~= "RankCard"
                and c ~= playersPanel and c ~= rankingPanel and c.Name ~= "TimerContainer" then
                c.Visible = false
            end
        end
    end

    local albumCard = leftPanel and leftPanel:FindFirstChild("AlbumCard")
    if leftPanel and not albumCard then
        albumCard = Instance.new("Frame")
        albumCard.Name = "AlbumCard"
        albumCard.Parent = leftPanel
    end
    if albumCard then
        styleReviewCard(albumCard, REVIEW.CARD_BG, REVIEW.CARD_STROKE)
        albumCard.AnchorPoint = Vector2.new(0, 0)
        albumCard.Position = UDim2.new(0, 0, 0, 0)
        albumCard.Size = UDim2.new(1, 0, 0.46, 0)
        albumCard.ZIndex = 3

        local hdr = albumCard:FindFirstChild("AlbumHeader")
        if not hdr then
            hdr = Instance.new("TextLabel")
            hdr.Name = "AlbumHeader"
            hdr.BackgroundTransparency = 1
            hdr.Font = Enum.Font.GothamBold
            hdr.Parent = albumCard
        end
        hdr.Size = UDim2.new(0.94, 0, 0.16, 0)
        hdr.Position = UDim2.new(0.03, 0, 0.04, 0)
        hdr.Text = "Albums"
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.ZIndex = 4
        applyReviewText(hdr, 20, true)
        hdr.TextScaled = true
    end

    local rankCard = leftPanel and leftPanel:FindFirstChild("RankCard")
    if leftPanel and not rankCard then
        rankCard = Instance.new("Frame")
        rankCard.Name = "RankCard"
        rankCard.Parent = leftPanel
    end
    if rankCard then
        styleReviewCard(rankCard, REVIEW.CARD_BG2, REVIEW.CARD_STROKE)
        rankCard.AnchorPoint = Vector2.new(0, 0)
        rankCard.Position = UDim2.new(0, 0, 0.48, 8)
        rankCard.Size = UDim2.new(1, 0, 0.52, 0)
        rankCard.ZIndex = 3
        rankCard.ClipsDescendants = false
    end

    if playersPanel and albumCard then
        playersPanel.Parent = albumCard
        playersPanel.BackgroundTransparency = 1
        playersPanel.BorderSizePixel = 0
        playersPanel.ScrollBarThickness = 6
        playersPanel.ScrollBarImageColor3 = REVIEW.CARD_STROKE
        playersPanel.Position = UDim2.new(0.03, 0, 0.22, 0)
        playersPanel.Size = UDim2.new(0.94, 0, 0.74, 0)
        playersPanel.ZIndex = 4
    end

    if rankingPanel and rankCard then
        rankingPanel.Parent = rankCard
        rankingPanel.BackgroundTransparency = 1
        rankingPanel.BorderSizePixel = 0
        rankingPanel.AnchorPoint = Vector2.new(0, 0)
        rankingPanel.Position = UDim2.new(0.03, 0, 0.03, 0)
        rankingPanel.Size = UDim2.new(0.94, 0, 0.94, 0)
        rankingPanel.ClipsDescendants = false
        rankingPanel.ZIndex = 4
        for _, c in ipairs(rankCard:GetChildren()) do
            if c ~= rankingPanel and (c:IsA("TextLabel") or c:IsA("TextButton")) then
                c.Visible = false
            end
        end
    end

    if mainWindow then
        styleReviewCard(mainWindow, REVIEW.RIGHT_BG, REVIEW.CARD_STROKE)
        mainWindow.AnchorPoint = Vector2.new(0, 0)
        mainWindow.Position = UDim2.new(rightX, 0, REVIEW.PAD_Y, 0)
        mainWindow.Size = UDim2.new(REVIEW.PANEL_W, 0, panelH, 0)
        mainWindow.ClipsDescendants = true
        mainWindow.ZIndex = 2
        mainWindow.ScrollBarImageColor3 = REVIEW.CARD_STROKE
        local legacyTitle = mainWindow:FindFirstChild("AlbumTitle")
        if legacyTitle then legacyTitle.Visible = false end
    end

    if timer then
        timer.Parent = reviewFrame
        local midX = leftX + REVIEW.PANEL_W + REVIEW.GAP * 0.5
        styleReviewTimer(timer, midX)
    end

    buildRankingPanel(rankingPanel, playerNames)

    if not playersPanel then return end

    for _, c in ipairs(playersPanel:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("UIListLayout") or c:IsA("UIPadding") then c:Destroy() end
    end

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 6)
    layout.Parent    = playersPanel

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft   = UDim.new(0, 2)
    pad.PaddingRight  = UDim.new(0, 2)
    pad.Parent        = playersPanel

    local guide = reviewFrame:FindFirstChild("ReviewGuide")
    if guide then guide.Visible = false end

    local function selectTile(btn, chain)
        for _, t in ipairs(playersPanel:GetChildren()) do
            if t:IsA("TextButton") then
                t.BackgroundColor3 = REVIEW.TILE
            end
        end
        btn.BackgroundColor3 = REVIEW.TILE_SEL
        showChainInMainWindow(chain, mainWindow)
    end

    local TILE_H_SCALE = 0.22

    for i, chain in ipairs(reviewData) do
        local tile = Instance.new("TextButton")
        tile.Name              = "ChainTile_" .. i
        tile.Size              = UDim2.new(0.97, 0, TILE_H_SCALE, 0)
        tile.LayoutOrder       = i
        tile.BackgroundColor3  = REVIEW.TILE
        tile.Text              = ""
        tile.BorderSizePixel   = 0
        tile.ZIndex            = 5
        tile.Parent            = playersPanel
        addCorner(tile, 10)

        local stroke2 = Instance.new("UIStroke")
        stroke2.Color       = REVIEW.CARD_STROKE
        stroke2.Thickness   = 1.5
        stroke2.Transparency = 0.15
        stroke2.Parent      = tile

        local av = makeReviewAvatar(tile, REVIEW.AV_SIZE, chain.startPlayerName, 6, chain.startPlayerUserId)
        local nl = Instance.new("TextLabel")
        nl.Text              = chain.startPlayerName
        nl.TextTruncate      = Enum.TextTruncate.AtEnd
        nl.ZIndex            = 6
        nl.Parent            = tile
        applyReviewText(nl, 17, false)
        nl.TextScaled = true
        layoutIconName(av, nl, REVIEW.AV_SIZE, 8)

        local capturedChain = chain
        addClickSound(tile)
        tile.MouseButton1Click:Connect(function()
            selectTile(tile, capturedChain)
        end)
    end

    if playersPanel:IsA("ScrollingFrame") then
        playersPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
        playersPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end

    task.delay(0.25, function()
        local ft = playersPanel:FindFirstChild("ChainTile_1")
        if ft and reviewData[1] then
            selectTile(ft, reviewData[1])
        end
    end)
end

local podiumAnimIds = {}
local podiumClipHold = Instance.new("Folder")
podiumClipHold.Name = "PodiumClipHold"
podiumClipHold.Parent = PlayerGui

local function getPodiumDanceId(place)
    local name = Config["PODIUM_DANCE_" .. tostring(place)]
    if type(name) ~= "string" or name == "" then
        return ""
    end
    if podiumAnimIds[name] then
        return podiumAnimIds[name]
    end
    local folder = ReplicatedStorage:FindFirstChild("PodiumAnims")
        or ReplicatedStorage:WaitForChild("PodiumAnims", 5)
    local seq = folder and folder:FindFirstChild(name)
    if not (seq and seq:IsA("KeyframeSequence")) then
        return ""
    end
    local old = podiumClipHold:FindFirstChild(name)
    if old then
        old:Destroy()
    end
    local clone = seq:Clone()
    clone.Name = name
    clone.Loop = true
    clone.Parent = podiumClipHold
    local function register(fn)
        local ok, id = pcall(fn)
        if not ok or id == nil then
            return ""
        end
        id = tostring(id)
        if id == "" or id == "nil" then
            return ""
        end
        if string.find(id, "rbxassetid://") and not string.match(id, "^rbxassetid://%d%d%d") then
            return ""
        end
        if string.match(id, "^%d+$") then
            return "rbxassetid://" .. id
        end
        return id
    end
    local id = register(function()
        return AnimationClipProvider:RegisterActiveAnimationClip(clone)
    end)
    if id == "" then
        id = register(function()
            return AnimationClipProvider:RegisterAnimationClip(clone)
        end)
    end
    if id ~= "" then
        podiumAnimIds[name] = id
        return id
    end
    return ""
end

local function playPodiumAnim(humanoid, place)
    if not humanoid or not humanoid.Parent then return end
    humanoid.AutoRotate = false
    humanoid.PlatformStand = false
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    pcall(function()
        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
            t:Stop(0)
        end
    end)
    local id = getPodiumDanceId(place)
    if id == "" then return end
    local anim = Instance.new("Animation")
    anim.Name = "PodiumDance"
    anim.AnimationId = id
    anim.Parent = humanoid
    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if ok and track then
        track.Looped = true
        track.Priority = Enum.AnimationPriority.Action4
        track:Play(0.15, 1, 1)
    end
end

local function preparePodiumRig(model)
    if not model then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = false
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = (d == hrp)
            d.CanCollide = false
            d.Massless = true
            d.AssemblyLinearVelocity = Vector3.zero
            d.AssemblyAngularVelocity = Vector3.zero
        elseif d:IsA("Force") or d:IsA("BaseScript") then
            d:Destroy()
        end
    end
    if hrp then
        hrp.Anchored = true
        model.PrimaryPart = hrp
    end
end

local function makePodiumPart(parent, size, cf, color)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

local function standOnPodium(model, x, topY)
    -- Face the camera (camera sits at +Z).
    local facing = CFrame.Angles(0, math.pi, 0)
    model:PivotTo(CFrame.new(x, topY + 3, 0) * facing)
    local cf, size = model:GetBoundingBox()
    if cf and size then
        local bottom = cf.Position.Y - size.Y * 0.5
        local pos = model:GetPivot().Position
        model:PivotTo(CFrame.new(pos.X, pos.Y + (topY - bottom), pos.Z) * facing)
    end
end

local function worldToVp(cam, worldPos, abs)
    local lp = cam.CFrame:PointToObjectSpace(worldPos)
    local depth = -lp.Z
    if depth < 0.05 then
        return 0.5, 0.5
    end
    local aspect = abs.X / math.max(abs.Y, 1)
    local halfH = math.tan(math.rad(cam.FieldOfView) * 0.5)
    local halfW = halfH * aspect
    return 0.5 + (lp.X / depth) / (2 * halfW), 0.5 - (lp.Y / depth) / (2 * halfH)
end

local function makePodiumOverlay(parent, cam, vp, place, name, reward, accent, spec)
    local abs = vp.AbsoluteSize
    if abs.X < 2 then
        abs = Vector2.new(800, 500)
    end
    local VP_SW, VP_SH = 0.96, 0.92
    local left = 0.5 - VP_SW * 0.5
    local top = 0.46 - VP_SH * 0.5
    local half = 2.2
    local x1 = worldToVp(cam, Vector3.new(spec.x - half, spec.h, 2.2), abs)
    local x2 = worldToVp(cam, Vector3.new(spec.x + half, spec.h, 2.2), abs)
    local sx, sy = worldToVp(cam, Vector3.new(spec.x, spec.h, 2.2), abs)
    local w = math.clamp(math.abs(x2 - x1) * 0.9, 0.08, 0.22)
    local card = Instance.new("Frame")
    card.Name = "PodiumLabel_" .. tostring(place)
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(left + sx * VP_SW, 0, top + (sy + 0.01) * VP_SH, 0)
    card.Size = UDim2.new(w * VP_SW, 0, 0.045 * VP_SH, 0)
    card.BackgroundColor3 = Color3.fromRGB(18, 10, 40)
    card.BackgroundTransparency = 0.55
    card.BorderSizePixel = 0
    card.ZIndex = 12
    card.Parent = parent
    addCorner(card, 6)
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Parent = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.94, 0, 0.52, 0)
    nameLbl.Position = UDim2.new(0.03, 0, 0.04, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextScaled = true
    nameLbl.TextColor3 = Color3.fromRGB(245, 245, 255)
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Text = name or ""
    nameLbl.ZIndex = 13
    nameLbl.Parent = card
    local nCap = Instance.new("UITextSizeConstraint")
    nCap.MinTextSize = 10
    nCap.MaxTextSize = 16
    nCap.Parent = nameLbl

    local coinLbl = Instance.new("TextLabel")
    coinLbl.Size = UDim2.new(0.94, 0, 0.4, 0)
    coinLbl.Position = UDim2.new(0.03, 0, 0.54, 0)
    coinLbl.BackgroundTransparency = 1
    coinLbl.Font = Enum.Font.Gotham
    coinLbl.TextScaled = true
    coinLbl.TextColor3 = Color3.fromRGB(255, 220, 90)
    coinLbl.Text = "+" .. tostring(reward or 0) .. " Coins"
    coinLbl.ZIndex = 13
    coinLbl.Parent = card
    local cCap = Instance.new("UITextSizeConstraint")
    cCap.MinTextSize = 9
    cCap.MaxTextSize = 14
    cCap.Parent = coinLbl
    return card
end

local function createPodiumModel(userId, playerName)
    local desc = nil
    local plr = findPlayer(userId, playerName)
    if plr and plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local okDesc, applied = pcall(function()
                return hum:GetAppliedDescription()
            end)
            if okDesc then
                desc = applied
            end
        end
    end
    userId = tonumber(userId) or resolveUserId(playerName, userId)
    if not desc and userId and userId > 0 then
        local okDesc, fetched = pcall(function()
            return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
        end)
        if okDesc then
            desc = fetched
        end
    end
    if desc then
        local okModel, model = pcall(function()
            return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
        end)
        if okModel and model then
            return model
        end
    end
    return nil
end

local confettiConn = nil

local function handleResults(results)
    showFrame(resultsFrame)
    local listFrame = resultsFrame:FindFirstChild("ResultsList")
    if not listFrame then return end

    for _, c in ipairs(listFrame:GetChildren()) do c:Destroy() end

    listFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    listFrame.Position = UDim2.new(0.5, 0, 0.48, 0)
    listFrame.Size = UDim2.new(0.94, 0, 0.84, 0)
    listFrame.BackgroundTransparency = 1
    listFrame.ClipsDescendants = false

    local top3, rest = {}, {}
    for i, entry in ipairs(results) do
        if i <= 3 then table.insert(top3, entry)
        else table.insert(rest, entry) end
    end

    local COL = {
        [1] = { bg = Color3.fromRGB(255, 200, 0),  glow = Color3.fromRGB(255, 235, 100) },
        [2] = { bg = Color3.fromRGB(0, 210, 255),  glow = Color3.fromRGB(120, 240, 255) },
        [3] = { bg = Color3.fromRGB(255, 85, 0),   glow = Color3.fromRGB(255, 155, 60) },
    }

    local vp = Instance.new("ViewportFrame")
    vp.Name = "PodiumScene"
    vp.AnchorPoint = Vector2.new(0.5, 0.5)
    vp.Position = UDim2.new(0.5, 0, 0.46, 0)
    vp.Size = UDim2.new(0.96, 0, 0.92, 0)
    vp.BackgroundTransparency = 1
    vp.BorderSizePixel = 0
    vp.Ambient = Color3.fromRGB(170, 170, 200)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-0.45, -1, -0.35)
    vp.ZIndex = 4
    vp.Parent = listFrame

    local world = Instance.new("WorldModel")
    world.Parent = vp
    local cam = Instance.new("Camera")
    cam.CFrame = CFrame.lookAt(Vector3.new(0, 7.4, 14.5), Vector3.new(0, 3.6, 0))
    cam.Parent = vp
    vp.CurrentCamera = cam

    -- 1 center, 2 left, 3 right. Heights so characters stand on top.
    local blocks = {
        [1] = { x = 0,    h = 5.4, color = COL[1].bg },
        [2] = { x = -5.6, h = 3.8, color = COL[2].bg },
        [3] = { x = 5.6,  h = 2.6, color = COL[3].bg },
    }
    for place, spec in pairs(blocks) do
        makePodiumPart(world, Vector3.new(4.4, spec.h, 4.4), CFrame.new(spec.x, spec.h * 0.5, 0), spec.color)
    end

    task.spawn(function()
        for _ = 1, 8 do
            if vp.AbsoluteSize.X > 4 then break end
            task.wait(0.05)
        end
        for place = 1, 3 do
            local entry = top3[place]
            if not entry then continue end
            local spec = blocks[place]
            local model = createPodiumModel(entry.userId, entry.name)
            if not model then continue end
            model.Parent = world
            preparePodiumRig(model)
            standOnPodium(model, spec.x, spec.h)
            makePodiumOverlay(
                listFrame,
                cam,
                vp,
                place,
                entry.name,
                entry.reward,
                COL[place].glow,
                spec
            )
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum then
                task.delay(0.2, function()
                    if hum.Parent then
                        playPodiumAnim(hum, place)
                    end
                end)
            end
        end
    end)

    local function makeSideCard(entry, place, side)
        local tile = Instance.new("Frame")
        tile.Size = UDim2.new(0.22, 0, 0.1, 0)
        tile.AnchorPoint = side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0)
        tile.Position = side == "left"
            and UDim2.new(0.02, 0, 0.86, 0)
            or  UDim2.new(0.98, 0, 0.86, 0)
        tile.BackgroundColor3 = Color3.fromRGB(40, 24, 90)
        tile.BorderSizePixel = 0
        tile.ZIndex = 5
        tile.Parent = listFrame
        addCorner(tile, 8)
        local ts = Instance.new("UIStroke")
        ts.Color = Color3.fromRGB(160, 110, 255)
        ts.Thickness = 1.5
        ts.Parent = tile

        local avS = Instance.new("ImageLabel")
        avS.Size = UDim2.new(0.22, 0, 0.7, 0)
        avS.SizeConstraint = Enum.SizeConstraint.RelativeYY
        avS.AnchorPoint = Vector2.new(0, 0.5)
        avS.Position = UDim2.new(0.04, 0, 0.5, 0)
        avS.BackgroundColor3 = Color3.fromRGB(50, 30, 100)
        avS.BorderSizePixel = 0
        avS.Parent = tile
        addCorner(avS, 20)
        task.spawn(function()
            loadAvatar(avS, entry.userId, entry.name)
        end)

        local nL = Instance.new("TextLabel")
        nL.Size = UDim2.new(0.68, 0, 0.42, 0)
        nL.Position = UDim2.new(0.3, 0, 0.08, 0)
        nL.BackgroundTransparency = 1
        nL.TextColor3 = Color3.fromRGB(245, 235, 255)
        nL.Text = "#" .. place .. " " .. entry.name
        nL.Font = Enum.Font.GothamBold
        nL.TextScaled = true
        nL.TextXAlignment = Enum.TextXAlignment.Left
        nL.TextTruncate = Enum.TextTruncate.AtEnd
        nL.Parent = tile

        local cL = Instance.new("TextLabel")
        cL.Size = UDim2.new(0.68, 0, 0.36, 0)
        cL.Position = UDim2.new(0.3, 0, 0.52, 0)
        cL.BackgroundTransparency = 1
        cL.TextColor3 = Color3.fromRGB(255, 210, 70)
        cL.Text = "+" .. tostring(entry.reward) .. " Coins"
        cL.Font = Enum.Font.GothamBold
        cL.TextScaled = true
        cL.TextXAlignment = Enum.TextXAlignment.Left
        cL.Parent = tile
    end

    if rest[1] then makeSideCard(rest[1], 4, "left") end
    if rest[2] then makeSideCard(rest[2], 5, "right") end

    if confettiConn then
        confettiConn:Disconnect()
        confettiConn = nil
    end
    local oldBits = resultsFrame:FindFirstChild("ConfettiPool")
    if oldBits then
        oldBits:Destroy()
    end
    local pool = Instance.new("Folder")
    pool.Name = "ConfettiPool"
    pool.Parent = resultsFrame
    local confColors = {
        Color3.fromRGB(255,40,40),   Color3.fromRGB(0,230,255),
        Color3.fromRGB(255,215,0),   Color3.fromRGB(0,255,110),
        Color3.fromRGB(255,0,230),   Color3.fromRGB(255,120,0),
        Color3.fromRGB(60,255,190),  Color3.fromRGB(255,255,80),
    }
    local emitters = { 0.32, 0.5, 0.68 }
    local GRAV = 1.35
    local bits = {}

    local function launch(p, fromRest)
        local ex = emitters[((p.i - 1) % 3) + 1] + (math.random() - 0.5) * 0.04
        local ey = 0.5 + (math.random() - 0.5) * 0.04
        p.x, p.y = ex, ey
        local spd = 0.7 + math.random() * 1.1
        p.vx = (math.random() * 2 - 1) * spd * 0.7
        p.vy = -(0.45 + math.random() * 0.9)
        p.vr = (math.random() - 0.5) * 520
        p.rot = math.random() * 360
        p.flip = 0.8 + math.random() * 2.2
        p.phase = math.random() * math.pi * 2
        if fromRest then
            p.y += (math.random() - 0.5) * 0.35
        end
        local strip = math.random() < 0.65
        if strip then
            p.gui.Size = UDim2.fromOffset(math.random(4, 7), math.random(12, 20))
        else
            local sz = math.random(7, 12)
            p.gui.Size = UDim2.fromOffset(sz, sz)
        end
        p.gui.BackgroundColor3 = confColors[math.random(#confColors)]
        p.gui.BackgroundTransparency = 0
    end

    for i = 1, 40 do
        local conf = Instance.new("Frame")
        conf.BorderSizePixel = 0
        conf.ZIndex = 20
        conf.Rotation = math.random() * 360
        conf.Parent = pool
        bits[i] = { i = i, gui = conf, x = 0.5, y = 0.5, vx = 0, vy = 0, rot = 0, vr = 0, flip = 1, phase = 0 }
        launch(bits[i], true)
    end
    confettiConn = RunService.Heartbeat:Connect(function(dt)
        if not resultsFrame.Visible or not pool.Parent then
            if confettiConn then
                confettiConn:Disconnect()
                confettiConn = nil
            end
            return
        end
        dt = math.min(dt, 1 / 30)
        for _, p in ipairs(bits) do
            p.vy += GRAV * dt
            p.vx += math.sin(p.phase + p.y * 8) * 0.35 * dt
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.rot += p.vr * dt
            p.phase += p.flip * dt
            local flutter = 0.35 + 0.65 * math.abs(math.sin(p.phase))
            p.gui.BackgroundTransparency = 1 - flutter
            if p.y > 1.12 or p.y < -0.2 or p.x < -0.12 or p.x > 1.12 then
                launch(p, false)
            else
                p.gui.Position = UDim2.new(p.x, 0, p.y, 0)
                p.gui.Rotation = p.rot
            end
        end
    end)

    local returnBtn = resultsFrame:FindFirstChild("ReturnButton")
    if returnBtn and not returnBtn:GetAttribute("WiredReturn") then
        returnBtn:SetAttribute("WiredReturn", true)
        returnBtn.Text = "Back to Lobby"
        addClickSound(returnBtn)
        returnBtn.MouseButton1Click:Connect(function()
            ReturnToLobby:FireServer()
            if confettiConn then
                confettiConn:Disconnect()
                confettiConn = nil
            end
            local bitsFolder = resultsFrame:FindFirstChild("ConfettiPool")
            if bitsFolder then
                bitsFolder:Destroy()
            end
            for _, f in ipairs(allFrames) do f.Visible = false end
            screenGui:SetAttribute("InQueue", false)
            local hud = screenGui:FindFirstChild("HudCoinsLabel")
            if hud and hud:IsA("TextLabel") then
                hud.Visible = true
            end
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end)
    elseif returnBtn then
        returnBtn.Text = "Back to Lobby"
    end
end
local lastPhaseTime = nil

GameStateChanged.OnClientEvent:Connect(function(phase, arg1, arg2, arg3, arg4)
    lastPhaseTime = arg1
    if     phase == "lobby"    then handleLobby(arg1, arg2, arg3, arg4)
    elseif phase == "write"    then handleWrite(arg1)
    elseif phase == "draw"     then
        showFrame(drawFrame)
        local pl = drawFrame:FindFirstChild("PromptLabel", true)
        if pl then
            pl.Text = "Waiting for prompt..."
            pl.TextWrapped = true
        end
    elseif phase == "describe" then
        showFrame(writeFrame)
        local pl = writeFrame:FindFirstChild("PromptLabel", true)
        if pl then
            pl.Text = "Waiting for image..."
            pl.TextWrapped = true
        end
    elseif phase == "review"   then showFrame(reviewFrame)
    elseif phase == "results"  then showFrame(resultsFrame)
    end
end)

SendRoundData.OnClientEvent:Connect(function(roundData)
    local phase = roundData and roundData.phase
    if     phase == "write"    then handleWrite(lastPhaseTime or Config.WRITE_TIME)
    elseif phase == "draw"     then handleDraw(lastPhaseTime or Config.DRAW_TIME, roundData)
    elseif phase == "describe" then handleDescribe(lastPhaseTime or Config.DESCRIBE_TIME, roundData)
    end
end)

SendReviewData.OnClientEvent:Connect(function(reviewData, playerNames, totalTime)
    handleReview(reviewData, playerNames, totalTime)
end)

SendResults.OnClientEvent:Connect(function(results)
    handleResults(results)
end)

UpdateSubmitCount.OnClientEvent:Connect(function(count, total)
    for _, frame in ipairs(allFrames) do
        if not frame.Visible then continue end
        local tc = frame:FindFirstChild("TimerContainer")
        if tc then
            local sl = tc:FindFirstChild("SubmitLabel")
            if sl then sl.Text = "Submitted: "..count.."/"..total end
        end
        local lp2 = frame:FindFirstChild("LeftPanel")
        if lp2 then
            local tc2 = lp2:FindFirstChild("TimerContainer")
            if tc2 then
                local sl2 = tc2:FindFirstChild("SubmitLabel")
                if sl2 then sl2.Text = "Submitted: "..count.."/"..total end
            end
        end
    end
end)

SetQueueState.OnClientEvent:Connect(function(isQueued)
    screenGui:SetAttribute("InQueue", isQueued == true)
    local hud = screenGui:FindFirstChild("HudCoinsLabel")
    if hud and hud:IsA("TextLabel") then
        hud.Visible = not isQueued
    end
    if not isQueued then
        for _, f in ipairs(allFrames) do f.Visible = false end
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

local hasPlayedIntro = false

local function onCharacterAdded()
    table.clear(collideCache)
    task.wait(0.1)
    if LocalPlayer.Character then
        cacheCollide(LocalPlayer.Character)
    end
    -- Server owns inactive/active during queue+round. Only intro may hide locally.
    if not hasPlayedIntro then
        hasPlayedIntro = true
        if Config.INTRO_ENABLED then
            playIntro()
        else
            introFrame.Visible = false
            if screenGui:GetAttribute("InQueue") ~= true then
                setCharacterActive(true)
            end
            showHudCoinsAfterIntro()
        end
    end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded()
end

print("[Draw for Slots] Client ready!")
