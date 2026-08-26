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

print("[Draw for Slots] You are playing as: " .. LocalPlayer.Name)

local function addCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
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

local function loadAvatar(imageLabel, userId)
    local ok, url = pcall(function()
        return Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
    end)
    if ok and url then
        imageLabel.Image = url
    end
end

local function handleLobby(currentCount, maxCount)
    showFrame(lobbyFrame)

    local wl = lobbyFrame:FindFirstChild("WaitingLabel", true)
    if wl then
        wl.Text = "Waiting for players: " .. (currentCount or 1) .. "/" .. (maxCount or 3)
    end

    local card = lobbyFrame:FindFirstChild("PlayerCard")
    local exitBtn = lobbyFrame:FindFirstChild("ExitQueueButton")
    if exitBtn and not exitBtn:GetAttribute("Wired") then
        exitBtn:SetAttribute("Wired", true)
        addClickSound(exitBtn)
        exitBtn.MouseButton1Click:Connect(function()
            LeaveQueueRequest:FireServer()
        end)
    end
    if card then
        local avatarImg = card:FindFirstChild("AvatarImage")
		local nameLabel = card:FindFirstChild("PlayerName")
		local coinLabel = card:FindFirstChild("CoinLabel")
        if nameLabel then nameLabel.Text = LocalPlayer.Name end
        if avatarImg then
            task.spawn(function()
                loadAvatar(avatarImg, LocalPlayer.UserId)
            end)
		end
		if coinLabel then
			task.spawn(function()
				local ok, coins = pcall(function() return GetCoins:InvokeServer() end)
				coinLabel.Text = tostring((ok and coins) or 500) .. " Coins"
			end)
		end
    end
end

local function handleWrite(timeLimit)
    showFrame(writeFrame)

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

    if textBox then textBox.Text = "" ; textBox:CaptureFocus() end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "Submit"
        local conn
        conn = submitBtn.MouseButton1Click:Connect(function()
            if submitted then return end
            submitted = true
            conn:Disconnect()
            local inputTxt = textBox and textBox.Text ~= "" and textBox.Text
            local txt = inputTxt or GetFallbackText:InvokeServer()
            SubmitText:FireServer(txt)
            submitBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
            submitBtn.Text = "Submitted!"
        end)
    end
end

local function handleDraw(timeLimit, roundData)
    showFrame(drawFrame)
    local pl = drawFrame:FindFirstChild("PromptLabel", true)
    if pl then
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

local function handleDescribe(timeLimit, roundData)
    showFrame(writeFrame)

    local pl = writeFrame:FindFirstChild("PromptLabel", true)
    if pl then pl.Text = "Describe this image:" end

    local CANVAS_ASPECT = 540 / 410
    local screenH = writeFrame.AbsoluteSize.Y
    if screenH <= 0 then screenH = 600 end
    local screenW = writeFrame.AbsoluteSize.X
    if screenW <= 0 then screenW = 800 end

    local marginX = math.floor(screenW * 0.08)
    local marginY = math.floor(screenH * 0.08)
        local gap = math.max(22, math.floor(screenH * 0.028))
    local hdrH = 44
    local textH = math.max(56, math.floor(screenH * 0.07))
    local btnH = math.max(48, math.floor(screenH * 0.06))

    local maxImgW = screenW - marginX * 2
    local usedH = hdrH + gap + textH + gap + btnH
    local maxImgH = screenH - marginY * 2 - usedH
    maxImgH = math.min(maxImgH, math.floor(screenH * 0.48))

    local imgH = maxImgH
    local imgW = math.floor(imgH * CANVAS_ASPECT)
    if imgW > maxImgW then
        imgW = maxImgW
        imgH = math.floor(imgW / CANVAS_ASPECT)
    end

    local stackH = hdrH + gap + imgH + gap + textH + gap + btnH
    local stackTop = math.floor((screenH - stackH) * 0.42)
    stackTop = math.max(marginY, stackTop)

    local wfHdr = writeFrame:FindFirstChildOfClass("Frame")
    if wfHdr and wfHdr.Name ~= "ImagePreview" and wfHdr.Name ~= "TimerContainer" then
        wfHdr.Size        = UDim2.new(0, imgW, 0, hdrH)
        wfHdr.AnchorPoint = Vector2.new(0.5, 0)
        wfHdr.Position    = UDim2.new(0.5, 0, 0, stackTop)
    end

    local ip = writeFrame:FindFirstChild("ImagePreview")
    if ip then
        ip.Visible     = true
        ip.Size        = UDim2.new(0, imgW, 0, imgH)
        ip.AnchorPoint = Vector2.new(0.5, 0)
        ip.Position    = UDim2.new(0.5, 0, 0, stackTop + hdrH + gap)
        ip.ClipsDescendants = true
        ip.ZIndex = 3
        for _, c in ipairs(ip:GetChildren()) do
            if c:IsA("Frame") and (c.Name == "Dot" or c.Name == "Seg") then c:Destroy() end
        end
        if roundData and roundData.content then
            local signals = ReplicatedStorage:FindFirstChild("Signals")
            local renderEv = signals and signals:FindFirstChild("RenderStrokesEvent")
            if renderEv then
                task.spawn(function()
                    task.wait(0.1)
                    renderEv:Fire(ip, roundData.content)
                end)
            end
        end
    end

    local yText = stackTop + hdrH + gap + imgH + gap

    local tb2 = writeFrame:FindFirstChild("TextInputBox")
    if tb2 then
        tb2.Size            = UDim2.new(0, imgW, 0, textH)
        tb2.AnchorPoint     = Vector2.new(0.5, 0)
        tb2.Position        = UDim2.new(0.5, 0, 0, yText)
        tb2.PlaceholderText = "Describe the image..."
        tb2.TextXAlignment  = Enum.TextXAlignment.Center
    end

    local submitBtn = writeFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.Size        = UDim2.new(0, imgW, 0, btnH)
        submitBtn.AnchorPoint = Vector2.new(0.5, 0)
        submitBtn.Position    = UDim2.new(0.5, 0, 0, yText + textH + gap)
    end

    local textBox  = writeFrame:FindFirstChild("TextInputBox")
    local submitted = false

    if textBox then textBox.Text = ""; textBox:CaptureFocus() end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "Submit"
        local conn
        conn = submitBtn.MouseButton1Click:Connect(function()
            if submitted then return end
            submitted = true
            conn:Disconnect()
            local txt = (textBox and textBox.Text ~= "") and textBox.Text or "Jokes on me: I was too silly to write anything!"
            SubmitText:FireServer(txt)
            submitBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
            submitBtn.Text = "Submitted!"
        end)
    end
end
local function showChainInMainWindow(chain, mainWindow)
    if not mainWindow then return end
    for _, c in ipairs(mainWindow:GetChildren()) do
        if c.Name == "EntryItem" then c:Destroy() end
    end
    local albumTitle = mainWindow:FindFirstChild("AlbumTitle")
    if albumTitle then
        albumTitle.Text = chain.startPlayerName:upper() .. "'S ALBUM"
        albumTitle.TextSize = 22
        albumTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
        albumTitle.Size = UDim2.new(1, -24, 0, 40)
        albumTitle.Position = UDim2.new(0, 12, 0, 8)
    end

    local CANVAS_W = 540
    local CANVAS_H = 410
    local ASPECT   = CANVAS_W / CANVAS_H
    local yOffset  = 56

    for _, entry in ipairs(chain.entries) do
        local isDrawing = (entry.type == "drawing")

        local mwW = mainWindow.AbsoluteSize.X
        if mwW <= 0 then mwW = 700 end

        local imgW, imgH = 0, 0
        if isDrawing then
            local maxW = mwW - 48
            local maxH = 340
            imgW = maxW
            imgH = math.floor(imgW / ASPECT)
            if imgH > maxH then
                imgH = maxH
                imgW = math.floor(imgH * ASPECT)
            end
        end

        local itemH = isDrawing and (imgH + 52) or 96

        local item = Instance.new("Frame")
        item.Name              = "EntryItem"
        item.Size              = UDim2.new(1, -28, 0, itemH)
        item.Position          = UDim2.new(0, 14, 0, yOffset)
        item.BackgroundColor3  = Color3.fromRGB(72, 52, 140)
        item.BorderSizePixel   = 0
        item.Parent            = mainWindow
        addCorner(item, 10)
        local iStroke = Instance.new("UIStroke")
        iStroke.Color        = Color3.fromRGB(190, 160, 255)
        iStroke.Thickness    = 2
        iStroke.Parent       = item

        local auth = Instance.new("TextLabel")
        auth.Size              = UDim2.new(1,-20,0,28)
        auth.Position          = UDim2.new(0,12,0,6)
        auth.BackgroundTransparency = 1
        auth.TextColor3        = Color3.fromRGB(230, 210, 255)
        auth.Text              = entry.author
        auth.Font              = Enum.Font.GothamBold
        auth.TextSize          = 18
        auth.TextXAlignment    = Enum.TextXAlignment.Center
        auth.Parent            = item

        if isDrawing then
            local dc = Instance.new("Frame")
            dc.Name             = "DrawPreview"
            dc.Size             = UDim2.new(0, imgW, 0, imgH)
            dc.AnchorPoint      = Vector2.new(0.5, 0)
            dc.Position         = UDim2.new(0.5, 0, 0, 36)
            dc.BackgroundColor3 = Color3.fromRGB(255,255,255)
            dc.BorderSizePixel  = 0
            dc.ClipsDescendants = true
            dc.Parent           = item
            addCorner(dc, 6)
            if entry.content then
                local signals = ReplicatedStorage:FindFirstChild("Signals")
                local re = signals and signals:FindFirstChild("RenderStrokesEvent")
                if re then
                    task.spawn(function()
                        task.wait(0.1)
                        re:Fire(dc, entry.content)
                    end)
                end
            end
        else
            local tl = Instance.new("TextLabel")
            tl.Size              = UDim2.new(1,-24,1,-40)
            tl.Position          = UDim2.new(0,12,0,36)
            tl.BackgroundTransparency = 1
            tl.TextColor3        = Color3.fromRGB(255,255,255)
            tl.Text              = tostring(entry.content)
            tl.Font              = Enum.Font.GothamBold
            tl.TextSize          = 22
            tl.TextXAlignment    = Enum.TextXAlignment.Center
            tl.TextYAlignment    = Enum.TextYAlignment.Center
            tl.TextWrapped       = true
            tl.Parent            = item
        end

        yOffset = yOffset + itemH + 14
    end

    if mainWindow:IsA("ScrollingFrame") then
        mainWindow.CanvasSize = UDim2.new(0,0,0,yOffset+24)
        mainWindow.ScrollBarThickness = 8
        mainWindow.BackgroundColor3 = Color3.fromRGB(48, 34, 95)
        mainWindow.BackgroundTransparency = 0.15
    end
end

local function buildRankingPanel(rankingPanel, playerNames)
    if not rankingPanel then return end

    for _, c in ipairs(rankingPanel:GetChildren()) do c:Destroy() end

    local others = {}
    for _, name in ipairs(playerNames) do
        if name ~= LocalPlayer.Name then table.insert(others, name) end
    end
    if #others == 0 then others = playerNames end
    if #others == 0 then return end

    local ROW_H   = 52
    local ROW_GAP = 10
    local TITLE_H = 28
    local HINT_H  = 36
    local TITLE_Y = 4
    local LIST_Y  = TITLE_Y + TITLE_H + HINT_H + 8
    local BTN_GAP = 14
    local BTN_H   = 44
    local SWAP_T  = 0.15

    local title = Instance.new("TextLabel")
    title.Name = "RankTitle"
    title.Size = UDim2.new(1,-16,0,TITLE_H)
    title.Position = UDim2.new(0,8,0,TITLE_Y)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255,200,0)
    title.Text = "Rank the others"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = rankingPanel

    local hint = Instance.new("TextLabel")
    hint.Name = "RankHint"
    hint.Size = UDim2.new(1,-16,0,HINT_H)
    hint.Position = UDim2.new(0,8,0,TITLE_Y + TITLE_H)
    hint.BackgroundTransparency = 1
    hint.TextColor3 = Color3.fromRGB(180,160,230)
    hint.Text = "Best at top. Use arrows to reorder, then submit."
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 13
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Parent = rankingPanel

    local listContainer = Instance.new("Frame")
    listContainer.Name = "RankList"
    listContainer.BackgroundTransparency = 1
    listContainer.Size = UDim2.new(1,0,0,#others*(ROW_H+ROW_GAP))
    listContainer.Position = UDim2.new(0,0,0,LIST_Y)
    listContainer.ClipsDescendants = false
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
            row.BackgroundColor3 = Color3.fromRGB(78, 52, 150)
            row.BorderSizePixel = 0
            row.Parent = listContainer
            addCorner(row, 8)
            local st = Instance.new("UIStroke")
            st.Color = Color3.fromRGB(130,90,255); st.Thickness = 2; st.Parent = row

            local rn = Instance.new("TextLabel")
            rn.Size = UDim2.new(0,36,1,0); rn.BackgroundTransparency = 1
            rn.TextColor3 = Color3.fromRGB(255,200,0); rn.Text = i.."."
            rn.Font = Enum.Font.GothamBold; rn.TextSize = 15; rn.Parent = row

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1,-86,1,0); nl.Position = UDim2.new(0,38,0,0)
            nl.BackgroundTransparency = 1; nl.TextColor3 = Color3.fromRGB(255,255,255)
            nl.Text = name; nl.Font = Enum.Font.Gotham; nl.TextSize = 14
            nl.TextXAlignment = Enum.TextXAlignment.Left; nl.Parent = row

            local as = Instance.new("Frame")
            as.Size = UDim2.new(0,32,1,-10); as.AnchorPoint = Vector2.new(1,0.5)
            as.Position = UDim2.new(1,-6,0.5,0); as.BackgroundTransparency = 1; as.Parent = row

            local up = Instance.new("TextButton")
            up.Size = UDim2.new(1,0,0.5,-2); up.Text = "^"
            up.Font = Enum.Font.GothamBold; up.TextSize = 14; up.BorderSizePixel = 0
            up.BackgroundColor3 = i==1 and Color3.fromRGB(90,70,140) or Color3.fromRGB(50,180,80)
            up.TextColor3 = Color3.fromRGB(255,255,255); up.Parent = as; addCorner(up,4)

            local dn = Instance.new("TextButton")
            dn.Size = UDim2.new(1,0,0.5,-2); dn.Position = UDim2.new(0,0,0.5,2)
            dn.Text = "v"; dn.Font = Enum.Font.GothamBold; dn.TextSize = 14
            dn.BorderSizePixel = 0
            dn.BackgroundColor3 = i==#rowOrder and Color3.fromRGB(90,70,140) or Color3.fromRGB(180,50,50)
            dn.TextColor3 = Color3.fromRGB(255,255,255); dn.Parent = as; addCorner(dn,4)

            row.MouseEnter:Connect(function()
                TweenService:Create(st, TweenInfo.new(0.12), { Thickness = 3, Color = Color3.fromRGB(180,140,255) }):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(st, TweenInfo.new(0.12), { Thickness = 2, Color = Color3.fromRGB(130,90,255) }):Play()
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
                        BackgroundColor3 = Color3.fromRGB(55, 35, 120),
                    })
                    local twB = TweenService:Create(b, TweenInfo.new(SWAP_T, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 4, 0, rowY(ci)),
                        BackgroundColor3 = Color3.fromRGB(55, 35, 120),
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
        listContainer.Size = UDim2.new(1,0,0,#rowOrder*(ROW_H+ROW_GAP))
    end

    renderRows()

    local btnY = LIST_Y + #others*(ROW_H+ROW_GAP) + BTN_GAP
    local submitBtn = Instance.new("TextButton")
    submitBtn.Name = "SubmitRankingBtn"
    submitBtn.Size = UDim2.new(1,-16,0,BTN_H)
    submitBtn.Position = UDim2.new(0,8,0,btnY)
    submitBtn.BackgroundColor3 = Color3.fromRGB(60,200,100)
    submitBtn.TextColor3 = Color3.fromRGB(255,255,255)
    submitBtn.Text = "Submit Ranking"
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = rankingPanel
    addCorner(submitBtn, 8)

    rankingPanel.Size = UDim2.new(1,-6,0, btnY+BTN_H+10)
    rankingPanel.ClipsDescendants = false

    local pulse = TweenService:Create(submitBtn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        BackgroundColor3 = Color3.fromRGB(80, 230, 120),
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

    local TOP_SAFE = 72
    local leftPanel    = reviewFrame:FindFirstChild("LeftPanel")
    local playersPanel = leftPanel and leftPanel:FindFirstChild("PlayersPanel")
    local mainWindow   = reviewFrame:FindFirstChild("MainWindow")
    local rankingPanel = leftPanel and leftPanel:FindFirstChild("RankingPanel")

    if leftPanel then
        leftPanel.ClipsDescendants = false
        leftPanel.Size = UDim2.new(0, 320, 1, 0)
        leftPanel.Position = UDim2.new(0, 0, 0, 0)
        leftPanel.BackgroundColor3 = Color3.fromRGB(62, 44, 118)
        leftPanel.BackgroundTransparency = 0

        local header = nil
        for _, c in ipairs(leftPanel:GetChildren()) do
            if c:IsA("Frame") and c.Size.Y.Offset == 46 and c.Position.Y.Offset == 0 then
                header = c
                break
            end
        end
        if not header then
            for _, c in ipairs(leftPanel:GetChildren()) do
                if c:IsA("Frame") and c ~= playersPanel and c ~= rankingPanel
                    and c.Name ~= "TimerContainer" and c.Size.Y.Offset > 0 and c.Size.Y.Offset < 60 then
                    header = c
                    break
                end
            end
        end
        if header then
            header.Position = UDim2.new(0, 0, 0, TOP_SAFE)
            header.Size = UDim2.new(1, 0, 0, 36)
            local hl = header:FindFirstChildOfClass("TextLabel")
            if hl then
                hl.Text = "Albums"
                hl.TextSize = 18
            end
        end
    end

    if mainWindow then
        mainWindow.AnchorPoint = Vector2.new(1, 0)
        mainWindow.Position = UDim2.new(1, -20, 0, 8)
        mainWindow.Size = UDim2.new(0.52, 0, 1, -16)
        mainWindow.ClipsDescendants = true
    end

    if playersPanel and playersPanel:IsA("ScrollingFrame") then
        playersPanel.Position = UDim2.new(0, 3, 0, TOP_SAFE + 40)
        playersPanel.Size = UDim2.new(1, -6, 0, 0) -- height set below
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
    pad.PaddingTop    = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft   = UDim.new(0, 4)
    pad.PaddingRight  = UDim.new(0, 4)
    pad.Parent        = playersPanel

    local guide = reviewFrame:FindFirstChild("ReviewGuide")
    if not guide then
        guide = Instance.new("TextLabel")
        guide.Name = "ReviewGuide"
        guide.BackgroundTransparency = 1
        guide.TextColor3 = Color3.fromRGB(200, 180, 255)
        guide.Font = Enum.Font.Gotham
        guide.TextSize = 13
        guide.Text = "Tap an album | Rank best to worst | Submit"
        guide.Size = UDim2.new(0.52, 0, 0, 22)
        guide.AnchorPoint = Vector2.new(1, 0)
        guide.Position = UDim2.new(1, -20, 0, 14)
        guide.TextXAlignment = Enum.TextXAlignment.Left
        guide.Parent = reviewFrame
    end
    guide.Visible = false

    local function selectTile(btn, chain)
        for _, t in ipairs(playersPanel:GetChildren()) do
            if t:IsA("TextButton") then
                t.BackgroundColor3 = Color3.fromRGB(78, 52, 150)
            end
        end
        btn.BackgroundColor3 = Color3.fromRGB(0, 150, 85)
        showChainInMainWindow(chain, mainWindow)
    end

    local TILE_H = 48

    for i, chain in ipairs(reviewData) do
        local tile = Instance.new("TextButton")
        tile.Name              = "ChainTile_" .. i
        tile.Size              = UDim2.new(1, -8, 0, TILE_H)
        tile.LayoutOrder       = i
        tile.BackgroundColor3  = Color3.fromRGB(78, 52, 150)
        tile.Text              = ""
        tile.BorderSizePixel   = 0
        tile.Parent            = playersPanel
        addCorner(tile, 10)

        local stroke2 = Instance.new("UIStroke")
        stroke2.Color       = Color3.fromRGB(130, 90, 255)
        stroke2.Thickness   = 2
        stroke2.Transparency = 0.1
        stroke2.Parent      = tile

        local av = Instance.new("ImageLabel")
        av.Name             = "TileAvatar"
        av.Size             = UDim2.new(0, 34, 0, 34)
        av.AnchorPoint      = Vector2.new(0, 0.5)
        av.Position         = UDim2.new(0, 7, 0.5, 0)
        av.BackgroundColor3 = Color3.fromRGB(60, 40, 130)
        av.BorderSizePixel  = 0
        av.Image            = ""
        av.Parent           = tile
        addCorner(av, 17)

        local playerName = chain.startPlayerName
        task.spawn(function()
            local ok, uid = pcall(function()
                return Players:GetUserIdFromNameAsync(playerName)
            end)
            if ok and uid then loadAvatar(av, uid) end
        end)

        local nl = Instance.new("TextLabel")
        nl.Size              = UDim2.new(1,-52,1,0)
        nl.Position          = UDim2.new(0,48,0,0)
        nl.BackgroundTransparency = 1
        nl.TextColor3        = Color3.fromRGB(230, 220, 255)
        nl.Text              = chain.startPlayerName
        nl.Font              = Enum.Font.GothamBold
        nl.TextSize          = 16
        nl.TextXAlignment    = Enum.TextXAlignment.Left
        nl.Parent            = tile

        local capturedChain = chain
        addClickSound(tile)
        tile.MouseButton1Click:Connect(function()
            selectTile(tile, capturedChain)
        end)
    end

    local tileCount = #reviewData
    local ppH = math.min(200, tileCount * (TILE_H + 6) + 12)
    if playersPanel:IsA("ScrollingFrame") then
        playersPanel.Size = UDim2.new(1, -6, 0, ppH)
        playersPanel.CanvasSize = UDim2.new(0, 0, 0, tileCount * (TILE_H + 6) + 12)
    end

    if rankingPanel then
        rankingPanel.AnchorPoint = Vector2.new(0, 1)
        rankingPanel.Position = UDim2.new(0, 8, 1, -52)
        rankingPanel.AutomaticSize = Enum.AutomaticSize.Y
    end

    local timer = leftPanel and leftPanel:FindFirstChild("TimerContainer")
    if timer then
        timer.Position = UDim2.new(0, 8, 1, -8)
        timer.AnchorPoint = Vector2.new(0, 1)
        timer.Size = UDim2.new(1, -16, 0, 38)
    end

    task.delay(0.2, function()
        local ft = playersPanel:FindFirstChild("ChainTile_1")
        if ft and reviewData[1] then
            selectTile(ft, reviewData[1])
        end
    end)
end

local function playPodiumAnim(humanoid, animId)
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    if type(animId) ~= "string" or animId == "" then
        return
    end
    local numeric = tonumber(animId)
    if not numeric then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(numeric)
    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if ok and track then
        track.Looped = true
        track:Play()
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

local function attachNameBillboard(model, text, accent)
    local head = model:FindFirstChild("Head") or model.PrimaryPart
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "PodiumName"
    bb.Size = UDim2.new(0, 160, 0, 44)
    bb.StudsOffset = Vector3.new(0, 2.4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0.6, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.4
    lbl.Parent = bb
    local coins = Instance.new("TextLabel")
    coins.Name = "CoinLine"
    coins.Size = UDim2.new(1, 0, 0.45, 0)
    coins.Position = UDim2.new(0, 0, 0.55, 0)
    coins.BackgroundTransparency = 1
    coins.Font = Enum.Font.GothamBold
    coins.TextSize = 13
    coins.TextColor3 = accent
    coins.TextStrokeTransparency = 0.4
    coins.Parent = bb
    return coins
end

local function handleResults(results)
    showFrame(resultsFrame)
    local listFrame = resultsFrame:FindFirstChild("ResultsList")
    if not listFrame then return end

    for _, c in ipairs(listFrame:GetChildren()) do c:Destroy() end

    listFrame.AnchorPoint = Vector2.new(0.5, 0)
    listFrame.Position = UDim2.new(0.5, 0, 0, 68)
    listFrame.Size = UDim2.new(1, -48, 1, -140)
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
    local DANCE = {
        [1] = Config.PODIUM_DANCE_1,
        [2] = Config.PODIUM_DANCE_2,
        [3] = Config.PODIUM_DANCE_3,
    }

    local vp = Instance.new("ViewportFrame")
    vp.Name = "PodiumScene"
    vp.AnchorPoint = Vector2.new(0.5, 0)
    vp.Position = UDim2.new(0.5, 0, 0, 0)
    vp.Size = UDim2.new(0.7, 0, 0.78, 0)
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
    cam.CFrame = CFrame.lookAt(Vector3.new(0, 8.2, 18), Vector3.new(0, 3.2, 0))
    cam.Parent = vp
    vp.CurrentCamera = cam

    -- 1 center, 2 left, 3 right. Heights so characters stand on top.
    local blocks = {
        [1] = { x = 0,    h = 4.6, color = COL[1].bg },
        [2] = { x = -4.6, h = 3.2, color = COL[2].bg },
        [3] = { x = 4.6,  h = 2.2, color = COL[3].bg },
    }
    for place, spec in pairs(blocks) do
        local part = makePodiumPart(world, Vector3.new(3.6, spec.h, 3.6), CFrame.new(spec.x, spec.h * 0.5, 0), spec.color)
        local face = Instance.new("SurfaceGui")
        face.Face = Enum.NormalId.Front
        face.Parent = part
        local nl = Instance.new("TextLabel")
        nl.Size = UDim2.new(1, 0, 1, 0)
        nl.BackgroundTransparency = 1
        nl.Text = tostring(place)
        nl.Font = Enum.Font.GothamBlack
        nl.TextScaled = true
        nl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nl.TextTransparency = 0.12
        nl.Parent = face
    end

    task.spawn(function()
        for place = 1, 3 do
            local entry = top3[place]
            if not entry then continue end
            local spec = blocks[place]
            local ok, uid = pcall(function()
                return Players:GetUserIdFromNameAsync(entry.name)
            end)
            if not ok or not uid then continue end
            local mok, model = pcall(function()
                return Players:CreateHumanoidModelFromUserIdAsync(uid)
            end)
            if not mok or not model then continue end
            model.Parent = world
            standOnPodium(model, spec.x, spec.h)
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                playPodiumAnim(hum, DANCE[place])
            end
            local coinLbl = attachNameBillboard(model, entry.name, COL[place].glow)
            if coinLbl then
                coinLbl.Text = "+" .. tostring(entry.reward) .. " Coins"
            end
        end
    end)

    local function makeSideCard(entry, place, side)
        local TILE_W, TILE_H = 168, 58
        local tile = Instance.new("Frame")
        tile.Size = UDim2.new(0, TILE_W, 0, TILE_H)
        tile.AnchorPoint = side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0)
        tile.Position = side == "left"
            and UDim2.new(0, 12, 0.82, 0)
            or  UDim2.new(1, -12, 0.82, 0)
        tile.BackgroundColor3 = Color3.fromRGB(40, 24, 90)
        tile.BorderSizePixel = 0
        tile.ZIndex = 5
        tile.Parent = listFrame
        addCorner(tile, 8)
        local ts = Instance.new("UIStroke")
        ts.Color = Color3.fromRGB(160, 110, 255)
        ts.Thickness = 1.5
        ts.Parent = tile

        local plL = Instance.new("TextLabel")
        plL.Size = UDim2.new(0, 28, 1, 0)
        plL.BackgroundTransparency = 1
        plL.TextColor3 = Color3.fromRGB(220, 160, 255)
        plL.Text = tostring(place) .. "."
        plL.Font = Enum.Font.GothamBold
        plL.TextSize = 14
        plL.Parent = tile

        local avS = Instance.new("ImageLabel")
        avS.Size = UDim2.new(0, 36, 0, 36)
        avS.AnchorPoint = Vector2.new(0, 0.5)
        avS.Position = UDim2.new(0, 30, 0.5, 0)
        avS.BackgroundColor3 = Color3.fromRGB(50, 30, 100)
        avS.BorderSizePixel = 0
        avS.Parent = tile
        addCorner(avS, 18)
        task.spawn(function()
            local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(entry.name) end)
            if ok and uid then loadAvatar(avS, uid) end
        end)

        local nL = Instance.new("TextLabel")
        nL.Size = UDim2.new(1, -74, 0, 22)
        nL.Position = UDim2.new(0, 70, 0, 6)
        nL.BackgroundTransparency = 1
        nL.TextColor3 = Color3.fromRGB(245, 235, 255)
        nL.Text = entry.name
        nL.Font = Enum.Font.GothamBold
        nL.TextSize = 13
        nL.TextXAlignment = Enum.TextXAlignment.Left
        nL.TextTruncate = Enum.TextTruncate.AtEnd
        nL.Parent = tile

        local cL = Instance.new("TextLabel")
        cL.Size = UDim2.new(1, -74, 0, 18)
        cL.Position = UDim2.new(0, 70, 0, 30)
        cL.BackgroundTransparency = 1
        cL.TextColor3 = Color3.fromRGB(255, 210, 70)
        cL.Text = "+" .. tostring(entry.reward) .. " Coins"
        cL.Font = Enum.Font.Gotham
        cL.TextSize = 12
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
GameStateChanged.OnClientEvent:Connect(function(phase, arg1, arg2)
    if     phase == "lobby"    then handleLobby(arg1, arg2)
    elseif phase == "write"    then handleWrite(arg1)
    elseif phase == "draw"     then
        showFrame(drawFrame)
        local pl = drawFrame:FindFirstChild("PromptLabel", true)
        if pl then pl.Text = "Waiting for prompt..." end
    elseif phase == "describe" then
        showFrame(writeFrame)
        local pl = writeFrame:FindFirstChild("PromptLabel", true)
        if pl then pl.Text = "Waiting for image..." end
    elseif phase == "review"   then showFrame(reviewFrame)
    elseif phase == "results"  then showFrame(resultsFrame)
    end
end)

SendRoundData.OnClientEvent:Connect(function(roundData)
    local phase = roundData and roundData.phase
    if     phase == "write"    then handleWrite(nil)
    elseif phase == "draw"     then handleDraw(nil, roundData)
    elseif phase == "describe" then handleDescribe(nil, roundData)
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
