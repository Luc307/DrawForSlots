local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local TeleportService     = game:GetService("TeleportService")
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
end

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50

-- Queued/in-round players stay hidden; lobby players visible.
local function setCharacterActive(active)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Transparency = active and 0 or 1
            if p ~= root then
                p.CanCollide = active
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
    end
    if humanoid then
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
local HUD_COIN_TEXT = 20

local function ensureHudCoins(): TextLabel
    local existing = screenGui:FindFirstChild("HudCoinsLabel")
    if existing and existing:IsA("TextLabel") then
        existing.TextSize = HUD_COIN_TEXT
        existing.Size = UDim2.new(0, 200, 0, 34)
        return existing
    end

    local lbl = Instance.new("TextLabel")
    lbl.Name = "HudCoinsLabel"
    lbl.AnchorPoint = Vector2.new(1, 0)
    lbl.Position = UDim2.new(1, -16, 0, 12)
    lbl.Size = UDim2.new(0, 200, 0, 34)
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
    setCharacterActive(false)

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
    setCharacterActive(true)
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
    if pl then pl.Text = "✏  Write a sentence..." end

    local textBox   = writeFrame:FindFirstChild("TextInputBox")
    local submitted = false

    if textBox then textBox.Text = "" ; textBox:CaptureFocus() end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "✓ Submit"
        local conn
        conn = submitBtn.MouseButton1Click:Connect(function()
            if submitted then return end
            submitted = true
            conn:Disconnect()
            local inputTxt = textBox and textBox.Text ~= "" and textBox.Text
            local txt = inputTxt or GetFallbackText:InvokeServer()
            SubmitText:FireServer(txt)
            submitBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
            submitBtn.Text = "✓ Submitted!"
        end)
    end
end

local function handleDraw(timeLimit, roundData)
    showFrame(drawFrame)
    local pl = drawFrame:FindFirstChild("PromptLabel", true)
    if pl then
        pl.Text = (roundData and roundData.content)
                  and ("🖌  Draw: \"" .. tostring(roundData.content) .. "\"")
                  or  "🖌  Waiting for prompt..."
    end
    local signals = ReplicatedStorage:FindFirstChild("Signals")
    local ev = signals and signals:FindFirstChild("DrawActiveEvent")
    if ev then ev:Fire(true) end
    local submitBtn = drawFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "✓ Submit"
        addClickSound(submitBtn)
    end
end

local function handleDescribe(timeLimit, roundData)
    showFrame(writeFrame)

    local pl = writeFrame:FindFirstChild("PromptLabel", true)
    if pl then pl.Text = "Describe this image:" end

    local wfHdr = writeFrame:FindFirstChildOfClass("Frame")
    if wfHdr then
        wfHdr.Size        = UDim2.new(0.56, 0, 0, 40)
        wfHdr.AnchorPoint = Vector2.new(0, 0)
        wfHdr.Position    = UDim2.new(0.02, 0, 0, 52)
    end

    local ip = writeFrame:FindFirstChild("ImagePreview")
    if ip then
        ip.Visible     = true
        ip.Size        = UDim2.new(0.56, 0, 1, -168)
        ip.AnchorPoint = Vector2.new(0, 0)
        ip.Position    = UDim2.new(0.02, 0, 0, 100)
        for _, c in ipairs(ip:GetChildren()) do
            if c:IsA("Frame") and c.Name == "Dot" then c:Destroy() end
        end
        if roundData and roundData.content then
            local signals = ReplicatedStorage:FindFirstChild("Signals")
            local renderEv = signals and signals:FindFirstChild("RenderStrokesEvent")
            if renderEv then
                task.spawn(function()
                    task.wait(0.05)
                    renderEv:Fire(ip, roundData.content)
                end)
            end
        end
    end

    local tb2 = writeFrame:FindFirstChild("TextInputBox")
    if tb2 then
        tb2.Size        = UDim2.new(0.36, 0, 0, 60)
        tb2.AnchorPoint = Vector2.new(1, 0.5)
        tb2.Position    = UDim2.new(0.98, 0, 0.5, 0)
        tb2.PlaceholderText = "Describe the image..."
        tb2.TextXAlignment  = Enum.TextXAlignment.Center
    end

    local submitBtn = writeFrame:FindFirstChild("SubmitButton")
    if submitBtn then
        submitBtn.Size        = UDim2.new(0.36, 0, 0, 48)
        submitBtn.AnchorPoint = Vector2.new(1, 1)
        submitBtn.Position    = UDim2.new(0.98, 0, 1, -68)
    end

    local textBox  = writeFrame:FindFirstChild("TextInputBox")
    local submitted = false

    if textBox then textBox.Text = ""; textBox:CaptureFocus() end
    if submitBtn then
        submitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        submitBtn.Text = "✓ Submit"
        local conn
        conn = submitBtn.MouseButton1Click:Connect(function()
            if submitted then return end
            submitted = true
            conn:Disconnect()
            local txt = (textBox and textBox.Text ~= "") and textBox.Text or "Jokes on me: I was too silly to write anything!"
            SubmitText:FireServer(txt)
            submitBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
            submitBtn.Text = "✓ Submitted!"
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
    end

    local CANVAS_W = 540
    local CANVAS_H = 410
    local ASPECT   = CANVAS_W / CANVAS_H
    local yOffset  = 52

    for _, entry in ipairs(chain.entries) do
        local isDrawing = (entry.type == "drawing")

        local mwW = mainWindow.AbsoluteSize.X
        local mwH = mainWindow.AbsoluteSize.Y
        if mwW <= 0 then mwW = 800 end
        if mwH <= 0 then mwH = 600 end

        local imgW, imgH = 0, 0
        if isDrawing then
            local maxW = mwW - 44
            local maxH = mwH - 100
            imgW = maxW
            imgH = math.floor(imgW / ASPECT)
            if imgH > maxH then
                imgH = maxH
                imgW = math.floor(imgH * ASPECT)
            end
            imgW = math.floor(imgW)
            imgH = math.floor(imgH)
        end

        local itemH = isDrawing and (imgH + 36) or 80

        local item = Instance.new("Frame")
        item.Name              = "EntryItem"
        item.Size              = UDim2.new(1, -20, 0, itemH)
        item.Position          = UDim2.new(0, 10, 0, yOffset)
        item.BackgroundColor3  = Color3.fromRGB(20, 12, 55)
        item.BorderSizePixel   = 0
        item.Parent            = mainWindow
        addCorner(item, 8)
        local iStroke = Instance.new("UIStroke")
        iStroke.Color        = Color3.fromRGB(155, 110, 255)
        iStroke.Thickness    = 3
        iStroke.Transparency = 0
        iStroke.Parent       = item


        local auth = Instance.new("TextLabel")
        auth.Size              = UDim2.new(1,-10,0,22)
        auth.Position          = UDim2.new(0,10,0,4)
        auth.BackgroundTransparency = 1
        auth.TextColor3        = Color3.fromRGB(160,140,220)
        auth.Text              = entry.author
        auth.Font              = Enum.Font.GothamBold
        auth.TextSize          = 12
        auth.TextXAlignment    = Enum.TextXAlignment.Left
        auth.Parent            = item

        if isDrawing then
            local dc = Instance.new("Frame")
            dc.Name             = "DrawPreview"
            dc.Size             = UDim2.new(0, imgW, 0, imgH)
            dc.AnchorPoint      = Vector2.new(0.5, 0)
            dc.Position         = UDim2.new(0.5, 0, 0, 28)
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
            tl.Size              = UDim2.new(1,-20,1,-30)
            tl.Position          = UDim2.new(0,10,0,28)
            tl.BackgroundTransparency = 1
            tl.TextColor3        = Color3.fromRGB(255,255,255)
            tl.Text              = tostring(entry.content)
            tl.Font              = Enum.Font.GothamBold
            tl.TextSize          = 16
            tl.TextXAlignment    = Enum.TextXAlignment.Left
            tl.TextWrapped       = true
            tl.Parent            = item
        end

        yOffset = yOffset + itemH + 10
    end

    if mainWindow:IsA("ScrollingFrame") then
        mainWindow.CanvasSize = UDim2.new(0,0,0,yOffset+20)
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
    local TITLE_H = 34
    local TITLE_Y = 14
    local LIST_Y  = TITLE_Y + TITLE_H + 12
    local BTN_GAP = 18
    local BTN_H   = 42

    local title = Instance.new("TextLabel")
    title.Name = "RankTitle"
    title.Size = UDim2.new(1,-16,0,TITLE_H)
    title.Position = UDim2.new(0,8,0,TITLE_Y)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255,200,0)
    title.Text = "🏆 Rate the others"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = rankingPanel

    local listContainer = Instance.new("Frame")
    listContainer.Name = "RankList"
    listContainer.BackgroundTransparency = 1
    listContainer.Size = UDim2.new(1,0,0,#others*(ROW_H+ROW_GAP))
    listContainer.Position = UDim2.new(0,0,0,LIST_Y)
    listContainer.Parent = rankingPanel

    local rowOrder = {}
    for _, name in ipairs(others) do table.insert(rowOrder, name) end

    local function renderRows()
        for _, c in ipairs(listContainer:GetChildren()) do c:Destroy() end
        for i, name in ipairs(rowOrder) do
            local row = Instance.new("Frame")
            row.Name = "Row_"..i
            row.Size = UDim2.new(1,-8,0,ROW_H)
            row.Position = UDim2.new(0,4,0,(i-1)*(ROW_H+ROW_GAP))
            row.BackgroundColor3 = Color3.fromRGB(35,20,80)
            row.BorderSizePixel = 0
            row.Parent = listContainer
            addCorner(row, 8)
            local st = Instance.new("UIStroke")
            st.Color = Color3.fromRGB(130,90,255); st.Thickness = 2; st.Parent = row

            local rn = Instance.new("TextLabel")
            rn.Size = UDim2.new(0,30,1,0); rn.BackgroundTransparency = 1
            rn.TextColor3 = Color3.fromRGB(255,200,0); rn.Text = "#"..i
            rn.Font = Enum.Font.GothamBold; rn.TextSize = 14; rn.Parent = row

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1,-76,1,0); nl.Position = UDim2.new(0,32,0,0)
            nl.BackgroundTransparency = 1; nl.TextColor3 = Color3.fromRGB(255,255,255)
            nl.Text = name; nl.Font = Enum.Font.Gotham; nl.TextSize = 13
            nl.TextXAlignment = Enum.TextXAlignment.Left; nl.Parent = row

            local as = Instance.new("Frame")
            as.Size = UDim2.new(0,28,1,-10); as.AnchorPoint = Vector2.new(1,0.5)
            as.Position = UDim2.new(1,-6,0.5,0); as.BackgroundTransparency = 1; as.Parent = row

            local up = Instance.new("TextButton")
            up.Size = UDim2.new(1,0,0.5,-2); up.Text = "▲"
            up.Font = Enum.Font.GothamBold; up.TextSize = 11; up.BorderSizePixel = 0
            up.BackgroundColor3 = i==1 and Color3.fromRGB(50,40,90) or Color3.fromRGB(50,180,80)
            up.TextColor3 = Color3.fromRGB(255,255,255); up.Parent = as; addCorner(up,4)

            local dn = Instance.new("TextButton")
            dn.Size = UDim2.new(1,0,0.5,-2); dn.Position = UDim2.new(0,0,0.5,2)
            dn.Text = "▼"; dn.Font = Enum.Font.GothamBold; dn.TextSize = 11
            dn.BorderSizePixel = 0
            dn.BackgroundColor3 = i==#rowOrder and Color3.fromRGB(50,40,90) or Color3.fromRGB(180,50,50)
            dn.TextColor3 = Color3.fromRGB(255,255,255); dn.Parent = as; addCorner(dn,4)

            local ci = i
            addClickSound(up)
            up.MouseButton1Click:Connect(function()
                if ci<=1 then return end
                rowOrder[ci],rowOrder[ci-1]=rowOrder[ci-1],rowOrder[ci]; renderRows()
            end)
            addClickSound(dn)
            dn.MouseButton1Click:Connect(function()
                if ci>=#rowOrder then return end
                rowOrder[ci],rowOrder[ci+1]=rowOrder[ci+1],rowOrder[ci]; renderRows()
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
    submitBtn.Text = "✓ Submit Ranking"
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 13
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = rankingPanel
    addCorner(submitBtn, 8)

    rankingPanel.Size = UDim2.new(1,-6,0, btnY+BTN_H+10)
    rankingPanel.ClipsDescendants = false

    local rankSubmitted = false
    submitBtn.MouseButton1Click:Connect(function()
        if rankSubmitted then return end
        rankSubmitted = true
        SubmitRanking:FireServer(rowOrder)
        submitBtn.BackgroundColor3 = Color3.fromRGB(80,130,80)
        submitBtn.Text = "✓ Submitted!"
    end)
end

local function handleReview(reviewData, playerNames, totalTime)
    showFrame(reviewFrame)

    local leftPanel    = reviewFrame:FindFirstChild("LeftPanel")
    if leftPanel then leftPanel.ClipsDescendants = false end
    local playersPanel = leftPanel and leftPanel:FindFirstChild("PlayersPanel")
    local mainWindow   = reviewFrame:FindFirstChild("MainWindow")
    local rankingPanel = leftPanel and leftPanel:FindFirstChild("RankingPanel")

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
    pad.PaddingTop    = UDim.new(0, 5)
    pad.PaddingBottom = UDim.new(0, 5)
    pad.PaddingLeft   = UDim.new(0, 5)
    pad.PaddingRight  = UDim.new(0, 5)
    pad.Parent        = playersPanel

    local function selectTile(btn, chain)
        for _, t in ipairs(playersPanel:GetChildren()) do
            if t:IsA("TextButton") then
                t.BackgroundColor3 = Color3.fromRGB(45, 28, 110)
            end
        end
        btn.BackgroundColor3 = Color3.fromRGB(0, 150, 85)
        showChainInMainWindow(chain, mainWindow)
    end

    local TILE_H = 52

    for i, chain in ipairs(reviewData) do
        local tile = Instance.new("TextButton")
        tile.Name              = "ChainTile_" .. i
        tile.Size              = UDim2.new(1, -10, 0, TILE_H)
        tile.LayoutOrder       = i
        tile.BackgroundColor3  = Color3.fromRGB(45, 28, 110)
        tile.Text              = ""
        tile.BorderSizePixel   = 0
        tile.Parent            = playersPanel
        addCorner(tile, 10)

        local stroke2 = Instance.new("UIStroke")
        stroke2.Color       = Color3.fromRGB(130, 90, 255)
        stroke2.Thickness   = 2.5
        stroke2.Transparency = 0.1
        stroke2.Parent      = tile

        local av = Instance.new("ImageLabel")
        av.Name             = "TileAvatar"
        av.Size             = UDim2.new(0, 38, 0, 38)
        av.AnchorPoint      = Vector2.new(0, 0.5)
        av.Position         = UDim2.new(0, 7, 0.5, 0)
        av.BackgroundColor3 = Color3.fromRGB(60, 40, 130)
        av.BorderSizePixel  = 0
        av.Image            = ""
        av.Parent           = tile
        addCorner(av, 19)

        local playerName = chain.startPlayerName
        task.spawn(function()
            local ok, uid = pcall(function()
                return Players:GetUserIdFromNameAsync(playerName)
            end)
            if ok and uid then loadAvatar(av, uid) end
        end)

        local nl = Instance.new("TextLabel")
        nl.Size              = UDim2.new(1,-56,1,0)
        nl.Position          = UDim2.new(0,52,0,0)
        nl.BackgroundTransparency = 1
        nl.TextColor3        = Color3.fromRGB(230, 220, 255)
        nl.Text              = chain.startPlayerName
        nl.Font              = Enum.Font.GothamBold
        nl.TextSize          = 15
        nl.TextXAlignment    = Enum.TextXAlignment.Left
        nl.Parent            = tile

        local capturedChain = chain
        addClickSound(tile)
        tile.MouseButton1Click:Connect(function()
            selectTile(tile, capturedChain)
        end)
    end

    if leftPanel then
        local tileCount = #reviewData
        local ppH = math.min(260, tileCount * (TILE_H + 6) + 16)
        local ppFrame = leftPanel:FindFirstChild("PlayersPanel")
        if ppFrame and ppFrame:IsA("ScrollingFrame") then
            ppFrame.Size = UDim2.new(1, 0, 0, ppH)
        end
    end

    task.delay(0.2, function()
        local ft = playersPanel:FindFirstChild("ChainTile_1")
        if ft and reviewData[1] then
            selectTile(ft, reviewData[1])
        end
    end)
end

local function handleResults(results)
    showFrame(resultsFrame)
    local listFrame = resultsFrame:FindFirstChild("ResultsList")
    if not listFrame then return end

    for _, c in ipairs(listFrame:GetChildren()) do c:Destroy() end

    local PODIUM_W  = 620
    local PODIUM_H  = 560
    listFrame.Size        = UDim2.new(0, PODIUM_W, 0, PODIUM_H)
    listFrame.AnchorPoint = Vector2.new(0.5, 0)
    listFrame.Position    = UDim2.new(0.5, 0, 0, 68)
    listFrame.BackgroundTransparency = 1

    local BLOCK_W   = 140
    local GAP       = 10
    local BASE_Y    = 340
    local AVATAR_S  = 58
    local SPACING   = 28

    local top3 = {}
    local rest  = {}
    for i, entry in ipairs(results) do
        if i <= 3 then table.insert(top3, entry)
        else           table.insert(rest, entry) end
    end

    local COL = {
        [1] = { bg = Color3.fromRGB(255, 200, 0),   glow = Color3.fromRGB(255, 235, 100) },
        [2] = { bg = Color3.fromRGB(0, 210, 255),   glow = Color3.fromRGB(120, 240, 255) },
        [3] = { bg = Color3.fromRGB(255, 85, 0),    glow = Color3.fromRGB(255, 155, 60)  },
    }

    local totalW = 3 * BLOCK_W + 2 * GAP
    local startX = (PODIUM_W - totalW) / 2

    local layout = {
        { place = 2, blockH = 138, xIdx = 0 },
        { place = 1, blockH = 196, xIdx = 1 },
        { place = 3, blockH = 103, xIdx = 2 },
    }

    for _, slot in ipairs(layout) do
        local entry = top3[slot.place]
        if not entry then continue end

        local C    = COL[slot.place]
        local bx   = startX + slot.xIdx * (BLOCK_W + GAP)
        local bTop = BASE_Y - slot.blockH

        local block = Instance.new("Frame")
        block.Size             = UDim2.new(0, BLOCK_W, 0, slot.blockH)
        block.Position         = UDim2.new(0, bx, 0, bTop)
        block.BackgroundColor3 = C.bg
        block.BorderSizePixel  = 0
        block.ZIndex           = 4
        block.Parent           = listFrame
        addCorner(block, 6)

        local glow = Instance.new("UIStroke")
        glow.Color = C.glow; glow.Thickness = 3; glow.Parent = block

        local num = Instance.new("TextLabel")
        num.Size = UDim2.new(1,0,1,0); num.BackgroundTransparency = 1
        num.TextColor3 = Color3.fromRGB(255,255,255); num.TextTransparency = 0.15
        num.Text = tostring(slot.place); num.Font = Enum.Font.GothamBlack
        num.TextSize = math.max(42, slot.blockH * 0.36)
        num.TextXAlignment = Enum.TextXAlignment.Center
        num.TextYAlignment = Enum.TextYAlignment.Center
        num.ZIndex = 5; num.Parent = block

        local coinsY  = bTop - SPACING
        local nameY   = coinsY - 26
        local avatarY = nameY  - AVATAR_S - 8

        local av = Instance.new("ImageLabel")
        av.Size = UDim2.new(0, AVATAR_S, 0, AVATAR_S)
        av.Position = UDim2.new(0, bx + BLOCK_W/2 - AVATAR_S/2, 0, avatarY)
        av.BackgroundColor3 = Color3.fromRGB(20,10,50)
        av.BorderSizePixel = 0; av.Image = ""; av.ZIndex = 5; av.Parent = listFrame
        addCorner(av, AVATAR_S/2)
        local avGlow = Instance.new("UIStroke")
        avGlow.Color = C.glow; avGlow.Thickness = 3; avGlow.Parent = av

        task.spawn(function()
            local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(entry.name) end)
            if ok and uid then loadAvatar(av, uid) end
        end)

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(0, BLOCK_W+20, 0, 24)
        nameL.Position = UDim2.new(0, bx-10, 0, nameY)
        nameL.BackgroundTransparency = 1; nameL.TextColor3 = Color3.fromRGB(255,255,255)
        nameL.Text = entry.name; nameL.Font = Enum.Font.GothamBold; nameL.TextSize = 15
        nameL.TextXAlignment = Enum.TextXAlignment.Center
        nameL.TextTruncate = Enum.TextTruncate.AtEnd
        nameL.ZIndex = 5; nameL.Parent = listFrame

        local scoreL = Instance.new("TextLabel")
        scoreL.Size = UDim2.new(0, BLOCK_W+20, 0, 22)
        scoreL.Position = UDim2.new(0, bx-10, 0, coinsY)
        scoreL.BackgroundTransparency = 1; scoreL.TextColor3 = C.glow
        scoreL.Text = "+" .. tostring(entry.reward) .. " Coins"
        scoreL.Font = Enum.Font.GothamBold; scoreL.TextSize = 14
        scoreL.TextXAlignment = Enum.TextXAlignment.Center
        scoreL.ZIndex = 5; scoreL.Parent = listFrame
    end

    if #rest > 0 then
        local REST_Y   = BASE_Y + 14
        local TILE_W   = 140; local TILE_H = 52; local TILE_GAP = 8
        local COLS     = math.floor((PODIUM_W + TILE_GAP) / (TILE_W + TILE_GAP))
        local ROWS     = math.ceil(#rest / COLS)
        local totalTW  = COLS * (TILE_W + TILE_GAP) - TILE_GAP
        local contH    = ROWS * (TILE_H + TILE_GAP) - TILE_GAP + 38

        local outer = Instance.new("Frame")
        outer.Size = UDim2.new(0, PODIUM_W, 0, contH)
        outer.Position = UDim2.new(0, 0, 0, REST_Y)
        outer.BackgroundColor3 = Color3.fromRGB(12,6,40)
        outer.BorderSizePixel = 0; outer.ZIndex = 2; outer.Parent = listFrame
        addCorner(outer, 10)
        local os = Instance.new("UIStroke")
        os.Color = Color3.fromRGB(160, 0, 255); os.Thickness = 2; os.Parent = outer

        local alL = Instance.new("TextLabel")
        alL.Size = UDim2.new(1,-16,0,20); alL.Position = UDim2.new(0,10,0,5)
        alL.BackgroundTransparency = 1; alL.TextColor3 = Color3.fromRGB(200,120,255)
        alL.Text = "Other placements"
        alL.Font = Enum.Font.GothamBold; alL.TextSize = 12
        alL.TextXAlignment = Enum.TextXAlignment.Left; alL.Parent = outer

        local sx = (PODIUM_W - totalTW) / 2
        for j, entry in ipairs(rest) do
            local place = j + 3
            local col = (j-1) % COLS; local row = math.floor((j-1) / COLS)
            local tile = Instance.new("Frame")
            tile.Size = UDim2.new(0, TILE_W, 0, TILE_H)
            tile.Position = UDim2.new(0, sx + col*(TILE_W+TILE_GAP), 0, 26 + row*(TILE_H+TILE_GAP))
            tile.BackgroundColor3 = Color3.fromRGB(22,10,60)
            tile.BorderSizePixel = 0; tile.Parent = outer
            addCorner(tile, 8)
            local ts = Instance.new("UIStroke")
            ts.Color = Color3.fromRGB(130,0,220); ts.Thickness = 1.5; ts.Parent = tile

            local plL = Instance.new("TextLabel"); plL.Size = UDim2.new(0,28,1,0)
            plL.BackgroundTransparency = 1; plL.TextColor3 = Color3.fromRGB(200,120,255)
            plL.Text = tostring(place).."."; plL.Font = Enum.Font.GothamBold
            plL.TextSize = 13; plL.TextXAlignment = Enum.TextXAlignment.Center; plL.Parent = tile

            local avS = Instance.new("ImageLabel"); avS.Size = UDim2.new(0,32,0,32)
            avS.AnchorPoint = Vector2.new(0,0.5); avS.Position = UDim2.new(0,30,0.5,0)
            avS.BackgroundColor3 = Color3.fromRGB(30,15,70)
            avS.BorderSizePixel = 0; avS.Image = ""; avS.Parent = tile
            addCorner(avS, 16)
            task.spawn(function()
                local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(entry.name) end)
                if ok and uid then loadAvatar(avS, uid) end
            end)

            local nL = Instance.new("TextLabel")
            nL.Size = UDim2.new(1,-68,0,20); nL.Position = UDim2.new(0,65,0,6)
            nL.BackgroundTransparency = 1; nL.TextColor3 = Color3.fromRGB(230,220,255)
            nL.Text = entry.name; nL.Font = Enum.Font.GothamBold; nL.TextSize = 12
            nL.TextXAlignment = Enum.TextXAlignment.Left
            nL.TextTruncate = Enum.TextTruncate.AtEnd; nL.Parent = tile

            local cL = Instance.new("TextLabel")
            cL.Size = UDim2.new(1,-68,0,17); cL.Position = UDim2.new(0,65,0,26)
            cL.BackgroundTransparency = 1; cL.TextColor3 = Color3.fromRGB(255,200,0)
            cL.Text = "+" .. tostring(entry.reward) .. " Coins"
            cL.Font = Enum.Font.Gotham; cL.TextSize = 11
            cL.TextXAlignment = Enum.TextXAlignment.Left; cL.Parent = tile
        end

        listFrame.Size = UDim2.new(0, PODIUM_W, 0, REST_Y + contH + 8)
    end

    local TweenService = game:GetService("TweenService")
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

    if returnBtn then
        returnBtn.MouseButton1Click:Connect(function()
            playClick()
            if Config.RETURN_PLACE_ID ~= 0 then
                TeleportService:Teleport(Config.RETURN_PLACE_ID)
            else
                returnBtn.Text = "(No Place ID set)"
            end
        end)
    end
end

GameStateChanged.OnClientEvent:Connect(function(phase, arg1, arg2)
    if     phase == "lobby"    then handleLobby(arg1, arg2)
    elseif phase == "write"    then handleWrite(arg1)
    elseif phase == "draw"     then
        showFrame(drawFrame)
        local pl = drawFrame:FindFirstChild("PromptLabel", true)
        if pl then pl.Text = "🖌  Waiting for prompt..." end
    elseif phase == "describe" then
        showFrame(writeFrame)
        local pl = writeFrame:FindFirstChild("PromptLabel", true)
        if pl then pl.Text = "💬  Waiting for image..." end
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
    setCharacterActive(not isQueued)
    if not isQueued then
        for _, f in ipairs(allFrames) do f.Visible = false end
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

local hasPlayedIntro = false

local function onCharacterAdded()
    task.wait(0.1)
    if not hasPlayedIntro then
        hasPlayedIntro = true
        if Config.INTRO_ENABLED then
            playIntro()
        else
            introFrame.Visible = false
            setCharacterActive(true)
            showHudCoinsAfterIntro()
        end
    else
        setCharacterActive(true)
    end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded()
end

print("[Draw for Slots] Client ready!")
