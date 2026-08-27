local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local Config              = require(ReplicatedStorage:WaitForChild("GameConfig"))
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
    PAD_Y = 72,
    PAD_B = 72,
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
    local stroke = lbl:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = lbl
    end
    stroke.Color = Color3.fromRGB(15, 8, 40)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
end

local function styleReviewTimer(timer, midX)
    timer.BackgroundTransparency = 1
    timer.BorderSizePixel = 0
    timer.ZIndex = 20
    timer.AnchorPoint = Vector2.new(0.5, 1)
    timer.Position = UDim2.new(midX or 0.5, 0, 1, -10)
    timer.Size = UDim2.new(0, 220, 0, 84)

    local timeLbl = timer:FindFirstChild("TimeLabel")
    local submitLbl = timer:FindFirstChild("SubmitLabel")
    if timeLbl and submitLbl then
        timeLbl.AnchorPoint = Vector2.new(0.5, 0)
        timeLbl.Position = UDim2.new(0.5, 0, 0, 4)
        timeLbl.Size = UDim2.new(1, 0, 0, 40)
        timeLbl.TextXAlignment = Enum.TextXAlignment.Center
        submitLbl.AnchorPoint = Vector2.new(0.5, 0)
        submitLbl.Position = UDim2.new(0.5, 0, 0, 46)
        submitLbl.Size = UDim2.new(1, 0, 0, 36)
        submitLbl.TextXAlignment = Enum.TextXAlignment.Center
        submitLbl.TextWrapped = true
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
    title.Position = UDim2.new(0.5, 0, 0, 14)
    title.Size = UDim2.new(0, 520, 0, 40)
    title.Text = "Review & Rank Albums"
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 20
    applyReviewText(title, 28, true)
end

local _clickSound = nil
local function playClick()
    if not _clickSound then
        _clickSound = game:GetService("SoundService"):FindFirstChild("ClickSound")
    end
    if _clickSound then _clickSound:Play() end
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
local HUD_COIN_W = 260
local HUD_COIN_H = 44

local function ensureHudCoins(): TextLabel
    local existing = screenGui:FindFirstChild("HudCoinsLabel")
    if existing and existing:IsA("TextLabel") then
        existing.TextSize = HUD_COIN_TEXT
        existing.Size = UDim2.new(0, HUD_COIN_W, 0, HUD_COIN_H)
        return existing
    end

    local lbl = Instance.new("TextLabel")
    lbl.Name = "HudCoinsLabel"
    lbl.AnchorPoint = Vector2.new(1, 0)
    lbl.Position = UDim2.new(1, -16, 0, 12)
    lbl.Size = UDim2.new(0, HUD_COIN_W, 0, HUD_COIN_H)
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
            d.CanCollide = false
            d.LocalTransparencyModifier = 0
            if d.Name == "HumanoidRootPart" then
                d.Transparency = 1
                d.Anchored = true
            else
                d.Anchored = false
                if d.Transparency >= 1 then
                    d.Transparency = 0
                end
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

    local head = clone:FindFirstChild("Head")
    local cam = Instance.new("Camera")
    cam.Parent = vp
    vp.CurrentCamera = cam
    if head and head:IsA("BasePart") then
        local lv = head.CFrame.LookVector
        local yaw = math.atan2(lv.X, -lv.Z)
        clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, -yaw, 0))
        head = clone:FindFirstChild("Head")
    end
    head = clone:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local focus = head.CFrame.Position + Vector3.new(0, 0.06, 0)
        cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -1.85), focus, Vector3.yAxis)
    else
        cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, -2.2), Vector3.new(0, 1.5, 0), Vector3.yAxis)
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
    av.ZIndex = zIndex or 5
    av.Parent = parent
    addCorner(av, math.floor(size * 0.5))
    task.spawn(function()
        local uid = resolveUserId(playerName, userId)
        loadAvatar(av, uid, playerName)
    end)
    return av
end

local QUEUE_NAME_COLOR = Color3.fromRGB(255, 255, 255)
local QUEUE_COIN_COLOR = Color3.fromRGB(255, 255, 21)
local QUEUE_BOTTOM_PAD = 30
local QUEUE_CARD_W = 280
local QUEUE_CARD_H = 74
local QUEUE_OTHER_CARD_W = 200
local QUEUE_CARD_GAP = 8

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
    container.Position = UDim2.new(0.5, 0, 1, -QUEUE_BOTTOM_PAD)
    container.Size = UDim2.new(0, 0, 0, QUEUE_CARD_H)
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

    card.Size = UDim2.new(0, isLocal and QUEUE_CARD_W or QUEUE_OTHER_CARD_W, 0, QUEUE_CARD_H)
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.Position = UDim2.new(0, 0, 0, 0)

    if nameLabel and nameLabel:IsA("TextLabel") then
        nameLabel.Text = member.name or "?"
        styleQueueLabel(nameLabel, QUEUE_NAME_COLOR)
    end
    if coinLabel and coinLabel:IsA("TextLabel") then
        if isLocal then
            coinLabel.Visible = true
            coinLabel.Text = tostring(member.coins or 0) .. " Coins"
            styleQueueLabel(coinLabel, QUEUE_COIN_COLOR)
        else
            coinLabel.Visible = false
        end
    end
    if avatarImg and avatarImg:IsA("ImageLabel") then
        avatarImg.Visible = true
        avatarImg.ImageTransparency = 0
        avatarImg.ZIndex = math.max(avatarImg.ZIndex, 3)
        loadAvatar(avatarImg, member.userId, member.name)
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
        cd.AnchorPoint = Vector2.new(0.5, 0.5)
        cd.Position = UDim2.new(0.5, 0, 0.82, 0)
        cd.Size = UDim2.new(0, 280, 0, 36)
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
    if exitBtn and not exitBtn:GetAttribute("Wired") then
        exitBtn:SetAttribute("Wired", true)
        addClickSound(exitBtn)
        exitBtn.MouseButton1Click:Connect(function()
            LeaveQueueRequest:FireServer()
        end)
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

    local wfHdr = writeFrame:FindFirstChildOfClass("Frame")
    if wfHdr then
        wfHdr.Size = UDim2.new(0, 460, 0, 40)
        wfHdr.AnchorPoint = Vector2.new(0.5, 0)
        wfHdr.Position = UDim2.new(0.5, 0, 0, 56)
    end

    local ip = writeFrame:FindFirstChild("ImagePreview")
    if ip then ip.Visible = false end

    local tb = writeFrame:FindFirstChild("TextInputBox")
    if tb then
        tb.AnchorPoint = Vector2.new(0.5, 0.5)
        tb.Position    = UDim2.new(0.5, 0, 0.48, 0)
        tb.Size        = UDim2.new(0, 460, 0, 56)
        tb.PlaceholderText = "Write your sentence here..."
    end

    local submitBtn = writeFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.Size = UDim2.new(0, 280, 0, 48)
        submitBtn.AnchorPoint = Vector2.new(0.5, 1)
        submitBtn.Position = UDim2.new(0.5, 0, 1, -60)
    end

    local pl = writeFrame:FindFirstChild("PromptLabel", true)
    if pl then pl.Text = "Write a sentence..." end

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

    if textBox then textBox.Text = "" ; textBox:CaptureFocus() end
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

local function handleDraw(timeLimit, roundData)
    showFrame(drawFrame)
    local pl = drawFrame:FindFirstChild("PromptLabel", true)
    if pl then
        pl.TextWrapped = true
        pl.Text = (roundData and roundData.content)
                  and ("Draw: \"" .. tostring(roundData.content) .. "\"")
                  or  "Waiting for prompt..."
    end
    local signals = ReplicatedStorage:FindFirstChild("Signals")
    local ev = signals and signals:FindFirstChild("DrawActiveEvent")
    if ev then ev:Fire(true) end
    local submitBtn = drawFrame:FindFirstChild("SubmitButton")
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
        pl.TextWrapped = true
    end

    local CANVAS_ASPECT = CANVAS_W / CANVAS_H
    local screenH = writeFrame.AbsoluteSize.Y
    if screenH <= 0 then screenH = 600 end
    local screenW = writeFrame.AbsoluteSize.X
    if screenW <= 0 then screenW = 800 end

    local marginX = math.floor(screenW * 0.12)
    local marginY = math.floor(screenH * 0.07)
    local gap = math.max(18, math.floor(screenH * 0.024))
    local hdrH = 44
    local textH = math.max(56, math.floor(screenH * 0.07))
    local btnH = math.max(48, math.floor(screenH * 0.06))

    local maxImgW = screenW - marginX * 2
    local usedH = hdrH + gap + textH + gap + btnH
    local maxImgH = screenH - marginY * 2 - usedH
    maxImgH = math.min(maxImgH, math.floor(screenH * 0.52))

    local imgH = maxImgH
    local imgW = math.floor(imgH * CANVAS_ASPECT)
    if imgW > maxImgW then
        imgW = maxImgW
        imgH = math.floor(imgW / CANVAS_ASPECT)
    end

    local stackH = hdrH + gap + imgH + gap + textH + gap + btnH
    local stackTop = math.floor((screenH - stackH) * 0.5)
    stackTop = math.max(marginY, stackTop)

    local wfHdr = writeFrame:FindFirstChildOfClass("Frame")
    if wfHdr and wfHdr.Name ~= "ImagePreview" and wfHdr.Name ~= "TimerContainer" then
        wfHdr.Size        = UDim2.new(0, imgW, 0, hdrH)
        wfHdr.AnchorPoint = Vector2.new(0.5, 0)
        wfHdr.Position    = UDim2.new(0.5, 0, 0, stackTop)
        wfHdr.ClipsDescendants = true
    end

    local ip = writeFrame:FindFirstChild("ImagePreview")
    if ip then
        ip.Visible     = true
        ip.Size        = UDim2.new(0, imgW, 0, imgH)
        ip.AnchorPoint = Vector2.new(0.5, 0)
        ip.Position    = UDim2.new(0.5, 0, 0, stackTop + hdrH + gap)
        ip.ClipsDescendants = true
        ip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ip.ZIndex = 3
        local ar = ip:FindFirstChildOfClass("UIAspectRatioConstraint")
        if not ar then
            ar = Instance.new("UIAspectRatioConstraint")
            ar.Parent = ip
        end
        ar.AspectRatio = CANVAS_ASPECT
        for _, c in ipairs(ip:GetChildren()) do
            if c:IsA("Frame") and (c.Name == "Dot" or c.Name == "Seg" or c.Name == "StrokeLayer") then
                c:Destroy()
            end
        end
        local border = ip:FindFirstChild("PreviewStroke")
        if not border then
            border = Instance.new("UIStroke")
            border.Name = "PreviewStroke"
            border.Color = Color3.fromRGB(40, 30, 80)
            border.Thickness = 2
            border.Parent = ip
        end
        fireStrokes(ip, roundData and roundData.content)
    end

    local yText = stackTop + hdrH + gap + imgH + gap

    local tb2 = writeFrame:FindFirstChild("TextInputBox")
    if tb2 then
        tb2.Size            = UDim2.new(0, imgW, 0, textH)
        tb2.AnchorPoint     = Vector2.new(0.5, 0)
        tb2.Position        = UDim2.new(0.5, 0, 0, yText)
        tb2.PlaceholderText = "Describe the image..."
        tb2.TextXAlignment  = Enum.TextXAlignment.Center
        tb2.TextWrapped     = true
    end

    local submitBtn = writeFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.Size        = UDim2.new(0, imgW, 0, btnH)
        submitBtn.AnchorPoint = Vector2.new(0.5, 0)
        submitBtn.Position    = UDim2.new(0.5, 0, 0, yText + textH + gap)
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

    if textBox then textBox.Text = ""; textBox:CaptureFocus() end
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
        if c.Name == "EntryItem" or c.Name == "AlbumTitleRow" then
            c:Destroy()
        elseif c.Name == "AlbumTitle" then
            c.Visible = false
        end
    end

    local titleRow = Instance.new("Frame")
    titleRow.Name = "AlbumTitleRow"
    titleRow.BackgroundTransparency = 1
    titleRow.Size = UDim2.new(1, -32, 0, 44)
    titleRow.Position = UDim2.new(0, 16, 0, 14)
    titleRow.Parent = mainWindow

    local titleAv = makeReviewAvatar(titleRow, 36, chain.startPlayerName, 6, chain.startPlayerUserId)
    titleAv.AnchorPoint = Vector2.new(0, 0.5)
    titleAv.Position = UDim2.new(0, 0, 0.5, 0)

    local albumTitle = Instance.new("TextLabel")
    albumTitle.Name = "AlbumTitle"
    albumTitle.Size = UDim2.new(1, -44, 1, 0)
    albumTitle.Position = UDim2.new(0, 44, 0, 0)
    albumTitle.Text = chain.startPlayerName:upper() .. "'S ALBUM"
    albumTitle.TextXAlignment = Enum.TextXAlignment.Left
    albumTitle.TextTruncate = Enum.TextTruncate.AtEnd
    albumTitle.ZIndex = 6
    albumTitle.Parent = titleRow
    applyReviewText(albumTitle, 24, true)

    local ASPECT  = CANVAS_W / CANVAS_H
    local yOffset = 68

    local mwW = mainWindow.AbsoluteSize.X
    if mwW <= 1 then mwW = 700 end

    for _, entry in ipairs(chain.entries) do
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

        local imgW, imgH = 0, 0
        if isDrawing then
            local maxW = math.max(120, mwW - 56)
            local maxH = math.min(420, math.floor(mainWindow.AbsoluteSize.Y * 0.55))
            if maxH < 160 then maxH = 280 end
            imgW = maxW
            imgH = math.floor(imgW / ASPECT)
            if imgH > maxH then
                imgH = maxH
                imgW = math.floor(imgH * ASPECT)
            end
        end

        local textH = 96
        if not isDrawing then
            local extra = math.ceil(#textBody / 38) * 24
            textH = math.clamp(72 + extra, 96, 200)
        end
        local itemH = isDrawing and (imgH + 60) or textH

        local item = Instance.new("Frame")
        item.Name              = "EntryItem"
        item.Size              = UDim2.new(1, -32, 0, itemH)
        item.Position          = UDim2.new(0, 16, 0, yOffset)
        item.BackgroundColor3  = REVIEW.ENTRY
        item.BorderSizePixel   = 0
        item.Parent            = mainWindow
        addCorner(item, 12)
        local iStroke = Instance.new("UIStroke")
        iStroke.Color        = REVIEW.CARD_STROKE
        iStroke.Thickness    = 1.5
        iStroke.Parent       = item

        local authAv = makeReviewAvatar(item, 30, authorName, 6, authorUserId)
        authAv.AnchorPoint = Vector2.new(0, 0)
        authAv.Position = UDim2.new(0, 10, 0, 8)

        local auth = Instance.new("TextLabel")
        auth.Size              = UDim2.new(1, -52, 0, 32)
        auth.Position          = UDim2.new(0, 46, 0, 6)
        auth.Text              = authorName
        auth.TextXAlignment    = Enum.TextXAlignment.Left
        auth.TextTruncate      = Enum.TextTruncate.AtEnd
        auth.ZIndex            = 6
        auth.Parent            = item
        applyReviewText(auth, 18, false)

        if isDrawing then
            local dc = Instance.new("Frame")
            dc.Name             = "DrawPreview"
            dc.Size             = UDim2.new(0, imgW, 0, imgH)
            dc.AnchorPoint      = Vector2.new(0.5, 0)
            dc.Position         = UDim2.new(0.5, 0, 0, 42)
            dc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            dc.BorderSizePixel  = 0
            dc.ClipsDescendants = true
            dc.Parent           = item
            addCorner(dc, 8)
            if type(entry.content) == "table" then
                fireStrokes(dc, entry.content)
            end
        else
            local tl = Instance.new("TextLabel")
            tl.Size              = UDim2.new(1, -24, 1, -46)
            tl.Position          = UDim2.new(0, 12, 0, 40)
            tl.Text              = textBody
            tl.TextXAlignment    = Enum.TextXAlignment.Left
            tl.TextYAlignment    = Enum.TextYAlignment.Top
            tl.TextWrapped       = true
            tl.Font              = Enum.Font.GothamMedium
            tl.TextSize          = 22
            tl.TextColor3        = REVIEW.TEXT_BODY
            tl.BackgroundTransparency = 1
            tl.ZIndex            = 6
            tl.Parent            = item
            local tlStroke = Instance.new("UIStroke")
            tlStroke.Color = Color3.fromRGB(15, 8, 40)
            tlStroke.Thickness = 1.2
            tlStroke.Transparency = 0.25
            tlStroke.Parent = tl
        end

        yOffset = yOffset + itemH + 12
    end

    if mainWindow:IsA("ScrollingFrame") then
        mainWindow.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
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

    local ROW_H   = 52
    local ROW_GAP = 8
    local TITLE_H = 26
    local TITLE_Y = 8
    local LIST_Y  = 50
    local BTN_H   = 44
    local BTN_W   = REVIEW.BTN_W
    local BTN_GAP = 4
    local BTN_AREA = BTN_W * 2 + BTN_GAP
    local SWAP_T  = 0.15
    local AVATAR = 34

    local title = Instance.new("TextLabel")
    title.Name = "RankTitle"
    title.Size = UDim2.new(1, -16, 0, TITLE_H)
    title.Position = UDim2.new(0, 8, 0, TITLE_Y)
    title.Text = "Rank the others"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Top
    title.ClipsDescendants = true
    title.ZIndex = 2
    title.Parent = rankingPanel
    applyReviewText(title, 18, true)

    local listContainer = Instance.new("Frame")
    listContainer.Name = "RankList"
    listContainer.BackgroundTransparency = 1
    listContainer.Size = UDim2.new(1, 0, 1, -(LIST_Y + BTN_H + 28))
    listContainer.Position = UDim2.new(0, 0, 0, LIST_Y)
    listContainer.ClipsDescendants = true
    listContainer.ZIndex = 8
    listContainer.Parent = rankingPanel

    local rowOrder = {}
    for _, name in ipairs(others) do table.insert(rowOrder, name) end

    local animating = false

    local function rowY(i)
        return (i - 1) * (ROW_H + ROW_GAP)
    end

    local function renderRows()
        for _, c in ipairs(listContainer:GetChildren()) do c:Destroy() end
        for i, name in ipairs(rowOrder) do
            local row = Instance.new("Frame")
            row.Name = "Row_"..i
            row.Size = UDim2.new(1,-8,0,ROW_H)
            row.Position = UDim2.new(0,4,0,rowY(i))
            row.BackgroundColor3 = REVIEW.ROW
            row.BorderSizePixel = 0
            row.ZIndex = 9
            row.Parent = listContainer
            addCorner(row, 8)
            local st = Instance.new("UIStroke")
            st.Color = REVIEW.CARD_STROKE; st.Thickness = 2; st.Parent = row

            local rn = Instance.new("TextLabel")
            rn.Size = UDim2.new(0, 28, 1, 0)
            rn.BackgroundTransparency = 1
            rn.Text = i .. "."
            rn.TextXAlignment = Enum.TextXAlignment.Center
            rn.Parent = row
            applyReviewText(rn, 17, true)

            local av = makeReviewAvatar(row, AVATAR, name, 6, userIdByName[name])
            av.AnchorPoint = Vector2.new(0, 0.5)
            av.Position = UDim2.new(0, 30, 0.5, 0)

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1, -(30 + AVATAR + BTN_AREA + 16), 1, 0)
            nl.Position = UDim2.new(0, 30 + AVATAR + 6, 0, 0)
            nl.Text = name
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.TextTruncate = Enum.TextTruncate.AtEnd
            nl.Parent = row
            applyReviewText(nl, 17, false)

            local as = Instance.new("Frame")
            as.Size = UDim2.new(0, BTN_AREA, 0, BTN_W)
            as.AnchorPoint = Vector2.new(1, 0.5)
            as.Position = UDim2.new(1, -6, 0.5, 0)
            as.BackgroundTransparency = 1
            as.Parent = row

            local dn = Instance.new("TextButton")
            dn.Size = UDim2.new(0, BTN_W, 1, 0)
            dn.Position = UDim2.new(0, 0, 0, 0)
            dn.Text = "v"
            dn.Font = Enum.Font.GothamBlack
            dn.TextSize = 20
            dn.BorderSizePixel = 0
            dn.BackgroundColor3 = i == #rowOrder and Color3.fromRGB(120, 100, 180) or Color3.fromRGB(220, 70, 90)
            dn.TextColor3 = Color3.fromRGB(255, 255, 255)
            dn.Parent = as
            addCorner(dn, 6)

            local up = Instance.new("TextButton")
            up.Size = UDim2.new(0, BTN_W, 1, 0)
            up.Position = UDim2.new(0, BTN_W + BTN_GAP, 0, 0)
            up.Text = "^"
            up.Font = Enum.Font.GothamBlack
            up.TextSize = 20
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
                        Position = UDim2.new(0, 4, 0, rowY(target)),
                        BackgroundColor3 = Color3.fromRGB(100, 80, 170),
                    })
                    local twB = TweenService:Create(b, TweenInfo.new(SWAP_T, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 4, 0, rowY(ci)),
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
    submitBtn.Size = UDim2.new(1, -16, 0, BTN_H)
    submitBtn.AnchorPoint = Vector2.new(0, 1)
    submitBtn.Position = UDim2.new(0, 8, 1, -8)
    submitBtn.BackgroundColor3 = Color3.fromRGB(55, 215, 120)
    submitBtn.TextColor3 = Color3.fromRGB(255,255,255)
    submitBtn.Text = "Submit Ranking"
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 17
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = rankingPanel
    addCorner(submitBtn, 8)

    rankingPanel.BackgroundTransparency = 1
    rankingPanel.ClipsDescendants = true

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
            Size = UDim2.new(1,-10,0,BTN_H+4),
        }):Play()
        task.delay(0.2, function()
            if submitBtn.Parent then
                TweenService:Create(submitBtn, TweenInfo.new(0.2), {
                    Size = UDim2.new(1,-16,0,BTN_H),
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

    local panelH = 1 - (REVIEW.PAD_Y + REVIEW.PAD_B) / math.max(reviewFrame.AbsoluteSize.Y, 600)
    local startX = reviewStartX()
    local leftX = startX
    local rightX = startX + REVIEW.PANEL_W + REVIEW.GAP

    ensureReviewPhaseTitle(reviewFrame)

    if leftPanel then
        leftPanel.BackgroundTransparency = 1
        leftPanel.BorderSizePixel = 0
        leftPanel.ClipsDescendants = false
        leftPanel.AnchorPoint = Vector2.new(0, 0)
        leftPanel.Position = UDim2.new(leftX, 0, 0, REVIEW.PAD_Y)
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
        albumCard.Size = UDim2.new(1, 0, 0.46, -8)
        albumCard.ZIndex = 3

        local hdr = albumCard:FindFirstChild("AlbumHeader")
        if not hdr then
            hdr = Instance.new("TextLabel")
            hdr.Name = "AlbumHeader"
            hdr.BackgroundTransparency = 1
            hdr.Font = Enum.Font.GothamBold
            hdr.Parent = albumCard
        end
        hdr.Size = UDim2.new(1, -20, 0, 34)
        hdr.Position = UDim2.new(0, 12, 0, 12)
        hdr.Text = "Albums"
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.ZIndex = 4
        applyReviewText(hdr, 20, true)
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
        rankCard.Size = UDim2.new(1, 0, 0.52, -8)
        rankCard.ZIndex = 3
    end

    if playersPanel and albumCard then
        playersPanel.Parent = albumCard
        playersPanel.BackgroundTransparency = 1
        playersPanel.BorderSizePixel = 0
        playersPanel.ScrollBarThickness = 6
        playersPanel.ScrollBarImageColor3 = REVIEW.CARD_STROKE
        playersPanel.Position = UDim2.new(0, 8, 0, 58)
        playersPanel.Size = UDim2.new(1, -16, 1, -66)
        playersPanel.ZIndex = 4
    end

    if rankingPanel and rankCard then
        rankingPanel.Parent = rankCard
        rankingPanel.BackgroundTransparency = 1
        rankingPanel.BorderSizePixel = 0
        rankingPanel.AnchorPoint = Vector2.new(0, 0)
        rankingPanel.Position = UDim2.new(0, 8, 0, 8)
        rankingPanel.Size = UDim2.new(1, -16, 1, -16)
        rankingPanel.AutomaticSize = Enum.AutomaticSize.None
        rankingPanel.ZIndex = 4
    end

    if mainWindow then
        styleReviewCard(mainWindow, REVIEW.RIGHT_BG, REVIEW.CARD_STROKE)
        mainWindow.AnchorPoint = Vector2.new(0, 0)
        mainWindow.Position = UDim2.new(rightX, 0, 0, REVIEW.PAD_Y)
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

    local TILE_H = 50

    for i, chain in ipairs(reviewData) do
        local tile = Instance.new("TextButton")
        tile.Name              = "ChainTile_" .. i
        tile.Size              = UDim2.new(1, -4, 0, TILE_H)
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

        local av = makeReviewAvatar(tile, 36, chain.startPlayerName, 6, chain.startPlayerUserId)
        av.AnchorPoint = Vector2.new(0, 0.5)
        av.Position = UDim2.new(0, 8, 0.5, 0)

        local nl = Instance.new("TextLabel")
        nl.Size              = UDim2.new(1, -54, 1, 0)
        nl.Position          = UDim2.new(0, 50, 0, 0)
        nl.Text              = chain.startPlayerName
        nl.TextXAlignment    = Enum.TextXAlignment.Left
        nl.TextTruncate      = Enum.TextTruncate.AtEnd
        nl.ZIndex            = 6
        nl.Parent            = tile
        applyReviewText(nl, 17, false)

        local capturedChain = chain
        addClickSound(tile)
        tile.MouseButton1Click:Connect(function()
            selectTile(tile, capturedChain)
        end)
    end

    local tileCount = #reviewData
    if playersPanel:IsA("ScrollingFrame") then
        playersPanel.CanvasSize = UDim2.new(0, 0, 0, tileCount * (TILE_H + 6) + 8)
        playersPanel.AutomaticCanvasSize = Enum.AutomaticSize.None
    end

    task.delay(0.25, function()
        local ft = playersPanel:FindFirstChild("ChainTile_1")
        if ft and reviewData[1] then
            selectTile(ft, reviewData[1])
        end
    end)
end

local function playPodiumAnim(humanoid, place)
    if not humanoid then return end
    pcall(function()
        humanoid.EvaluateStateMachine = false
    end)
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
    local r6 = humanoid.RigType == Enum.HumanoidRigType.R6
    local list = r6 and Config.PODIUM_DANCE_R6 or Config.PODIUM_DANCE_R15
    local override = Config["PODIUM_DANCE_" .. tostring(place)]
    local id = ""
    if type(override) == "string" and override ~= "" then
        id = override
    elseif type(list) == "table" then
        id = list[((place - 1) % #list) + 1] or list[1]
    end
    local numeric = tonumber(tostring(id):match("%d+"))
    if not numeric then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(numeric)
    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if ok and track then
        track.Looped = true
        track.Priority = Enum.AnimationPriority.Idle
        track:Play(0.25, 1, 1)
    end
end

local function preparePodiumRig(model)
    if not model then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.EvaluateStateMachine = false
        end)
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

local function decoratePodiumPart(part, place, name, reward, accent)
    local sg = part:FindFirstChildOfClass("SurfaceGui")
    if not sg then
        sg = Instance.new("SurfaceGui")
        sg.Parent = part
    end
    -- Camera sits at +Z; part Front is -Z. Back face is what the camera sees.
    sg.Face = Enum.NormalId.Back
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 40
    sg.LightInfluence = 0
    sg.AlwaysOnTop = false
    sg.ZOffset = 1
    for _, c in ipairs(sg:GetChildren()) do c:Destroy() end

    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.fromScale(1, 1)
    wrap.BackgroundTransparency = 1
    wrap.Parent = sg

    local placeLbl = Instance.new("TextLabel")
    placeLbl.Size = UDim2.new(1, -10, 0.42, 0)
    placeLbl.Position = UDim2.new(0, 5, 0.04, 0)
    placeLbl.BackgroundTransparency = 1
    placeLbl.Font = Enum.Font.GothamBlack
    placeLbl.TextScaled = true
    placeLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    placeLbl.Text = tostring(place)
    placeLbl.Parent = wrap

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -12, 0.28, 0)
    nameLbl.Position = UDim2.new(0, 6, 0.46, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextScaled = true
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.Text = name or ""
    nameLbl.Parent = wrap

    local coinLbl = Instance.new("TextLabel")
    coinLbl.Size = UDim2.new(1, -12, 0.22, 0)
    coinLbl.Position = UDim2.new(0, 6, 0.74, 0)
    coinLbl.BackgroundTransparency = 1
    coinLbl.Font = Enum.Font.GothamBold
    coinLbl.TextScaled = true
    coinLbl.TextColor3 = accent
    coinLbl.Text = "+" .. tostring(reward or 0) .. " Coins"
    coinLbl.Parent = wrap
end

local function createPodiumModel(userId, playerName)
    local plr = findPlayer(userId, playerName)
    if plr and plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local okDesc, desc = pcall(function()
                return hum:GetAppliedDescription()
            end)
            if okDesc and desc then
                local okModel, model = pcall(function()
                    return Players:CreateHumanoidModelFromDescription(desc, hum.RigType)
                end)
                if okModel and model then
                    return model
                end
            end
        end
        local clone = nil
        local wasArchivable = plr.Character.Archivable
        plr.Character.Archivable = true
        local okClone, result = pcall(function()
            return plr.Character:Clone()
        end)
        plr.Character.Archivable = wasArchivable
        if okClone and result then
            clone = result
        end
        if not clone then
            return nil
        end
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
        return clone
    end

    userId = tonumber(userId) or resolveUserId(playerName, userId)
    if userId and userId > 0 then
        local ok, model = pcall(function()
            return Players:CreateHumanoidModelFromUserIdAsync(userId)
        end)
        if ok and model then
            return model
        end
        local okDesc, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
        end)
        if okDesc and desc then
            local okModel, model = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if okModel and model then
                return model
            end
        end
    end
    return nil
end

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
    local podiumParts = {}
    for place, spec in pairs(blocks) do
        local part = makePodiumPart(world, Vector3.new(4.4, spec.h, 4.4), CFrame.new(spec.x, spec.h * 0.5, 0), spec.color)
        podiumParts[place] = part
        decoratePodiumPart(part, place, "", 0, COL[place].glow)
    end

    task.spawn(function()
        for place = 1, 3 do
            local entry = top3[place]
            if not entry then continue end
            local spec = blocks[place]
            local model = createPodiumModel(entry.userId, entry.name)
            if not model then continue end
            model.Parent = world
            preparePodiumRig(model)
            standOnPodium(model, spec.x, spec.h)
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum then
                task.delay(0.05, function()
                    if hum.Parent then
                        playPodiumAnim(hum, place)
                    end
                end)
            end
            decoratePodiumPart(podiumParts[place], place, entry.name, entry.reward, COL[place].glow)
        end
    end)

    local function makeSideCard(entry, place, side)
        local TILE_W, TILE_H = 210, 64
        local tile = Instance.new("Frame")
        tile.Size = UDim2.new(0, TILE_W, 0, TILE_H)
        tile.AnchorPoint = side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0)
        tile.Position = side == "left"
            and UDim2.new(0, 16, 0.86, 0)
            or  UDim2.new(1, -16, 0.86, 0)
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
        avS.Size = UDim2.new(0, 40, 0, 40)
        avS.AnchorPoint = Vector2.new(0, 0.5)
        avS.Position = UDim2.new(0, 10, 0.5, 0)
        avS.BackgroundColor3 = Color3.fromRGB(50, 30, 100)
        avS.BorderSizePixel = 0
        avS.Parent = tile
        addCorner(avS, 20)
        task.spawn(function()
            loadAvatar(avS, entry.userId, entry.name)
        end)

        local nL = Instance.new("TextLabel")
        nL.Size = UDim2.new(1, -62, 0, 24)
        nL.Position = UDim2.new(0, 56, 0, 6)
        nL.BackgroundTransparency = 1
        nL.TextColor3 = Color3.fromRGB(245, 235, 255)
        nL.Text = "#" .. place .. " " .. entry.name
        nL.Font = Enum.Font.GothamBold
        nL.TextSize = 14
        nL.TextXAlignment = Enum.TextXAlignment.Left
        nL.TextTruncate = Enum.TextTruncate.AtEnd
        nL.Parent = tile

        local cL = Instance.new("TextLabel")
        cL.Size = UDim2.new(1, -62, 0, 20)
        cL.Position = UDim2.new(0, 56, 0, 32)
        cL.BackgroundTransparency = 1
        cL.TextColor3 = Color3.fromRGB(255, 210, 70)
        cL.Text = "+" .. tostring(entry.reward) .. " Coins"
        cL.Font = Enum.Font.GothamBold
        cL.TextSize = 13
        cL.TextXAlignment = Enum.TextXAlignment.Left
        cL.Parent = tile
    end

    if rest[1] then makeSideCard(rest[1], 4, "left") end
    if rest[2] then makeSideCard(rest[2], 5, "right") end

    local confColors = {
        Color3.fromRGB(255,40,40),   Color3.fromRGB(0,230,255),
        Color3.fromRGB(255,215,0),   Color3.fromRGB(0,255,110),
        Color3.fromRGB(255,0,230),   Color3.fromRGB(255,120,0),
        Color3.fromRGB(60,255,190),  Color3.fromRGB(255,50,170),
        Color3.fromRGB(130,255,0),   Color3.fromRGB(50,90,255),
        Color3.fromRGB(255,255,80),  Color3.fromRGB(180,0,255),
    }
    local function spawnWave(count, spread)
        for k = 1, count do
            task.spawn(function()
                task.wait(math.random() * spread)
                local r = math.random()
                local conf = Instance.new("Frame")
                if r < 0.4 then
                    conf.Size = UDim2.new(0, math.random(4,8), 0, math.random(16,28))
                elseif r < 0.7 then
                    local sz = math.random(8,15)
                    conf.Size = UDim2.new(0, sz, 0, sz)
                else
                    conf.Size = UDim2.new(0, math.random(14,22), 0, math.random(5,9))
                end
                conf.Position = UDim2.new(math.random()*0.96+0.02, 0, -0.07, 0)
                conf.BackgroundColor3 = confColors[math.random(#confColors)]
                conf.BorderSizePixel = 0
                conf.Rotation = math.random()*360
                conf.ZIndex = 20
                conf.Parent = resultsFrame
                addCorner(conf, 3)
                local fallTime = math.random()*2.4 + 1.2
                local swayX   = math.random(-130, 130)
                local tw = TweenService:Create(conf,
                    TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { Position = UDim2.new(conf.Position.X.Scale, conf.Position.X.Offset + swayX, 1.12, 0),
                      Rotation = conf.Rotation + math.random(-400, 400) })
                tw:Play()
                tw.Completed:Connect(function() conf:Destroy() end)
            end)
        end
    end
    spawnWave(120, 3.0)
    task.delay(2.0, function() spawnWave(80,  2.0) end)
    task.delay(4.0, function() spawnWave(70,  2.0) end)
    task.delay(6.0, function() spawnWave(60,  1.8) end)
    task.delay(8.0, function() spawnWave(50,  1.5) end)

    local returnBtn = resultsFrame:FindFirstChild("ReturnButton")
    if returnBtn and not returnBtn:GetAttribute("WiredReturn") then
        returnBtn:SetAttribute("WiredReturn", true)
        returnBtn.Text = "Back to Lobby"
        addClickSound(returnBtn)
        returnBtn.MouseButton1Click:Connect(function()
            ReturnToLobby:FireServer()
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
