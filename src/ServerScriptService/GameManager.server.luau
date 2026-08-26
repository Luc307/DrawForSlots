local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")

local Config  = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GiveCoinsFunc = script.Parent:WaitForChild("CoinService"):WaitForChild("GiveCoinsFunc")

local GameStateChanged  = Remotes:WaitForChild("GameStateChanged")
local SubmitText        = Remotes:WaitForChild("SubmitText")
local SubmitDrawing     = Remotes:WaitForChild("SubmitDrawing")
local SubmitRanking     = Remotes:WaitForChild("SubmitRanking")
local UpdateSubmitCount = Remotes:WaitForChild("UpdateSubmitCount")
local SendRoundData     = Remotes:WaitForChild("SendRoundData")
local SendReviewData    = Remotes:WaitForChild("SendReviewData")
local SendResults       = Remotes:WaitForChild("SendResults")
local SyncTimer         = Remotes:WaitForChild("SyncTimer")
local GetFallbackText   = Remotes:WaitForChild("GetFallbackText")

local FALLBACK_TEXTS = {
    "Tung Tung Tung Sahur",
    "Mona Lisa",
    "A simple landscape",
    "Speed face from the side",
    "Chessboard",
    "A cat sitting on a cloud",
    "A robot eating spaghetti",
    "Two suns at sunset",
    "A house on a tiny island",
    "A fish wearing a hat",
    "Rocket launching from a pizza",
	"A snail racing a sports car",
	"67 with sunglases"
}

local fallbackPool = {}

local function shufflePool()
    fallbackPool = {}
    for _, t in ipairs(FALLBACK_TEXTS) do
        table.insert(fallbackPool, t)
    end
    for i = #fallbackPool, 2, -1 do
        local j = math.random(1, i)
        fallbackPool[i], fallbackPool[j] = fallbackPool[j], fallbackPool[i]
    end
    print("[GM] Fallback pool shuffled: " .. #fallbackPool .. " texts")
end

shufflePool()

local function resetFallbackPool()
    shufflePool()
end

GetFallbackText.OnServerInvoke = function(plr)
    if #fallbackPool == 0 then shufflePool() end
    local txt = table.remove(fallbackPool, 1)
    print("[GM] Fallback text for " .. plr.Name .. ": " .. txt)
    return txt
end

local SetQueueState = Remotes:WaitForChild("SetQueueState")

local queueMembers  = {}
local queuedSize    = {}
-- Players hidden/non-colliding while queued or in a live session.
local inactivePlayers = {}
local collideCache = {} -- [Model] = { [BasePart] = boolean }

for _, size in ipairs(Config.QUEUE_SIZES) do
    queueMembers[size] = {}
end

local runSession

local DEFAULT_WALKSPEED = 40 -- do not change this value
local DEFAULT_JUMPPOWER = 50

local function cacheCollide(char)
    local cache = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            cache[p] = p.CanCollide
        end
    end
    collideCache[char] = cache
end

local function findSpawnCFrame()
    local best = nil
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("SpawnLocation") then
            best = inst.CFrame + Vector3.new(0, 5, 0)
            break
        end
    end
    return best
end

local function applyCharacterActive(char, active)
    if not char then return end
    if not collideCache[char] then
        cacheCollide(char)
    end
    local cache = collideCache[char]
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Transparency = active and 0 or 1
            if active then
                local cached = cache[p]
                if cached ~= nil then
                    p.CanCollide = cached
                end
            else
                p.CanCollide = false
            end
        elseif p:IsA("Decal") or p:IsA("Texture") then
            p.Transparency = active and 0 or 1
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
        humanoid.DisplayDistanceType = active
            and Enum.HumanoidDisplayDistanceType.Viewer
            or Enum.HumanoidDisplayDistanceType.None
        humanoid.PlatformStand = not active
        humanoid.WalkSpeed = active and DEFAULT_WALKSPEED or 0
        humanoid.JumpPower = active and DEFAULT_JUMPPOWER or 0
    end
end

local function setPlayerInactive(plr, inactive)
    if inactive then
        inactivePlayers[plr] = true
    else
        inactivePlayers[plr] = nil
    end
    if plr.Character then
        applyCharacterActive(plr.Character, not inactive)
    end
end

local function teleportToSpawn(plr)
    local char = plr.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local spawnCf = findSpawnCFrame()
    if not root or not spawnCf then return end
    root.Anchored = false
    root.CFrame = spawnCf
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function releasePlayer(plr)
    setPlayerInactive(plr, false)
    teleportToSpawn(plr)
    -- Re-apply active after teleport so root stays unanchored at spawn.
    if plr.Character then
        applyCharacterActive(plr.Character, true)
    end
end

local function bindCharacter(plr)
    plr.CharacterAdded:Connect(function(char)
        collideCache[char] = nil
        task.wait(0.1)
        if inactivePlayers[plr] then
            applyCharacterActive(char, false)
        else
            cacheCollide(char)
        end
        char.Destroying:Once(function()
            collideCache[char] = nil
        end)
    end)
    if plr.Character then
        if inactivePlayers[plr] then
            applyCharacterActive(plr.Character, false)
        else
            cacheCollide(plr.Character)
        end
    end
end

Players.PlayerAdded:Connect(bindCharacter)
for _, plr in ipairs(Players:GetPlayers()) do
    bindCharacter(plr)
end

local function broadcastQueueLobby(size)
    local list = queueMembers[size]
    for _, plr in ipairs(list) do
        if plr and plr.Parent then
            GameStateChanged:FireClient(plr, "lobby", #list, size)
        end
    end
end

local function leaveQueue(plr)
    local size = queuedSize[plr]
    if not size then return end
    local list = queueMembers[size]
    for i, p in ipairs(list) do
        if p == plr then
            table.remove(list, i)
            break
        end
    end
    queuedSize[plr] = nil
    SetQueueState:FireClient(plr, false)
    releasePlayer(plr)
    broadcastQueueLobby(size)
end

local function joinQueue(plr, size)
    if not queueMembers[size] then return end
    if queuedSize[plr] then return end
    if inactivePlayers[plr] then return end

    queuedSize[plr] = size
    table.insert(queueMembers[size], plr)

    setPlayerInactive(plr, true)
    SetQueueState:FireClient(plr, true)
    broadcastQueueLobby(size)

    print("[GM] " .. plr.Name .. " joined the " .. size .. "-player queue ("
        .. #queueMembers[size] .. "/" .. size .. ")")

    if #queueMembers[size] >= size then
        local sessionPlayers = queueMembers[size]
        queueMembers[size] = {}
        for _, p in ipairs(sessionPlayers) do
            queuedSize[p] = nil
        end
        task.spawn(runSession, sessionPlayers, size)
    end
end

Players.PlayerRemoving:Connect(function(plr)
    leaveQueue(plr)
    inactivePlayers[plr] = nil
end)

local LeaveQueueRequest = Remotes:WaitForChild("LeaveQueueRequest")
LeaveQueueRequest.OnServerEvent:Connect(function(plr)
    leaveQueue(plr)
end)

local ReturnToLobby = Remotes:WaitForChild("ReturnToLobby")
ReturnToLobby.OnServerEvent:Connect(function(plr)
    if queuedSize[plr] then
        leaveQueue(plr)
        return
    end
    if not inactivePlayers[plr] then return end
    SetQueueState:FireClient(plr, false)
    releasePlayer(plr)
end)

-- Session state is local so multiple queue sizes can run in parallel.
runSession = function(playerList, playerCount)
    local chains      = {}
    local submissions = {}
    local rankings    = {}

    -- Ignore remotes from players outside this session.
    local memberSet = {}
    for _, p in ipairs(playerList) do memberSet[p] = true end

    local function broadcast(remote, ...)
        for _, plr in ipairs(playerList) do
            if plr and plr.Parent then
                remote:FireClient(plr, ...)
            end
        end
    end

    local function runTimer(duration)
        local endTime = tick() + duration
        while tick() < endTime do
            local remaining = math.max(0, math.ceil(endTime - tick()))
            broadcast(SyncTimer, remaining, duration)
            task.wait(1)
        end
        broadcast(SyncTimer, 0, duration)
    end

    local function collectSubmissions(timeLimit)
        submissions = {}
        local count     = 0
        local startTime = tick()

        local conns = {}

        local function sanitizeDrawing(strokeData)
            if typeof(strokeData) ~= "table" then return {} end
            local out = {}
            local total = 0
            local maxPoints = 800
            for _, stroke in ipairs(strokeData) do
                if total >= maxPoints then break end
                if typeof(stroke) ~= "table" or typeof(stroke.points) ~= "table" then
                    continue
                end
                local pts = {}
                for _, pt in ipairs(stroke.points) do
                    if total >= maxPoints then break end
                    if typeof(pt) == "table" and typeof(pt.x) == "number" and typeof(pt.y) == "number" then
                        table.insert(pts, { x = pt.x, y = pt.y })
                        total += 1
                    end
                end
                if #pts > 0 then
                    table.insert(out, {
                        r = tonumber(stroke.r) or 0,
                        g = tonumber(stroke.g) or 0,
                        b = tonumber(stroke.b) or 0,
                        size = tonumber(stroke.size) or 4,
                        points = pts,
                    })
                end
            end
            return out
        end

        conns[1] = SubmitText.OnServerEvent:Connect(function(plr, content)
            if not memberSet[plr] then return end
            if submissions[plr.UserId] then return end
            submissions[plr.UserId] = {type = "text", content = tostring(content)}
            count += 1
            broadcast(UpdateSubmitCount, count, playerCount)
            print("[GM] Text from " .. plr.Name .. " (" .. count .. "/" .. playerCount .. ")")
        end)

        conns[2] = SubmitDrawing.OnServerEvent:Connect(function(plr, strokeData)
            if not memberSet[plr] then return end
            if submissions[plr.UserId] then return end
            submissions[plr.UserId] = {type = "drawing", content = sanitizeDrawing(strokeData)}
            count += 1
            broadcast(UpdateSubmitCount, count, playerCount)
            print("[GM] Drawing from " .. plr.Name .. " (" .. count .. "/" .. playerCount .. ")")
        end)

        while count < playerCount and (tick() - startTime) < timeLimit do
            task.wait(0.3)
        end

        for _, conn in ipairs(conns) do conn:Disconnect() end
        print("[GM] Submissions done: " .. count .. "/" .. playerCount)
    end

    local function getChainIndex(playerIndex, round)
        return ((playerIndex - 1 - round) % playerCount) + 1
    end

    local function distributeRoundData(round, phaseType)
        for i, plr in ipairs(playerList) do
            local chainIdx  = getChainIndex(i, round)
            local chain     = chains[chainIdx]
            local lastEntry = chain.entries[#chain.entries]
            SendRoundData:FireClient(plr, {
                phase    = phaseType,
                chainIdx = chainIdx,
                content  = lastEntry and lastEntry.content or nil,
                author   = lastEntry and lastEntry.author  or nil,
            })
        end
    end

    local function processSubmissions(round, entryType)
        for i, plr in ipairs(playerList) do
            local sub      = submissions[plr.UserId]
            local chainIdx = getChainIndex(i, round)
            table.insert(chains[chainIdx].entries, {
                type    = entryType,
                author  = plr.Name,
                content = sub and sub.content or "",
            })
        end
    end

    print("[Draw for Slots] Game starting with " .. playerCount .. " players!")
    print("[Draw for Slots] Game started!")

    chains = {}
    for i, plr in ipairs(playerList) do
        chains[i] = {startPlayer = plr, entries = {}}
    end

    local totalRounds = playerCount

    resetFallbackPool()
    print("[Draw for Slots] Phase: WRITE (" .. Config.WRITE_TIME .. "s)")
    broadcast(GameStateChanged, "write", Config.WRITE_TIME)
    broadcast(UpdateSubmitCount, 0, playerCount)
    for _, plr in ipairs(playerList) do
        SendRoundData:FireClient(plr, {phase = "write", content = nil})
    end
    local timerThread = task.spawn(runTimer, Config.WRITE_TIME)
    collectSubmissions(Config.WRITE_TIME)
    task.cancel(timerThread)
    processSubmissions(0, "text")

    for round = 1, totalRounds - 1 do
        local isDrawRound = (round % 2 == 1)
        local phaseType   = isDrawRound and "draw" or "describe"
        local timeLimit   = isDrawRound and Config.DRAW_TIME or Config.DESCRIBE_TIME
        local entryType   = isDrawRound and "drawing" or "text"

        print("[Draw for Slots] Phase: " .. phaseType:upper()
              .. " round " .. round .. " (" .. timeLimit .. "s)")
        broadcast(GameStateChanged, phaseType, timeLimit)
        broadcast(UpdateSubmitCount, 0, playerCount)
        distributeRoundData(round, phaseType)
        timerThread = task.spawn(runTimer, timeLimit)
        collectSubmissions(timeLimit)
        task.cancel(timerThread)
        processSubmissions(round, entryType)
    end

    local totalEntries = playerCount * totalRounds
    local reviewTime   = totalEntries * Config.REVIEW_TIME_PER_ENTRY
    print("[GM] Phase: REVIEW (" .. reviewTime .. "s, " .. totalEntries .. " entries)")

    local reviewData = {}
    for i, chain in ipairs(chains) do
        reviewData[i] = {
            startPlayerName = chain.startPlayer.Name,
            entries         = chain.entries,
        }
    end

    local playerNames = {}
    for _, plr in ipairs(playerList) do
        table.insert(playerNames, plr.Name)
    end

        broadcast(GameStateChanged, "review", reviewTime)
    for _, plr in ipairs(playerList) do
        local othersForPlr = {}
        for _, name in ipairs(playerNames) do
            if name ~= plr.Name then
                table.insert(othersForPlr, name)
            end
        end
        SendReviewData:FireClient(plr, reviewData, othersForPlr, reviewTime)
    end
    broadcast(UpdateSubmitCount, 0, playerCount)

    rankings = {}
    local rankCount = 0
    local rankConn = SubmitRanking.OnServerEvent:Connect(function(plr, rankList)
        if not memberSet[plr] then return end
        if rankings[plr.UserId] then return end
        rankings[plr.UserId] = rankList
        rankCount += 1
        broadcast(UpdateSubmitCount, rankCount, playerCount)
        print("[GM] Ranking from " .. plr.Name)
    end)

    local reviewThread = task.spawn(runTimer, reviewTime)
    local t0 = tick()
    while rankCount < playerCount and (tick() - t0) < reviewTime do
        task.wait(0.5)
    end
    task.cancel(reviewThread)
    rankConn:Disconnect()

    local scores = {}
    for _, plr in ipairs(playerList) do scores[plr.Name] = 0 end

    for _, rankList in pairs(rankings) do
        local n = #rankList
        for rank, name in ipairs(rankList) do
            local pts = math.max(0, (n - rank + 1)) * 100
            if scores[name] then scores[name] += pts end
        end
    end

    local sorted = {}
    for name, pts in pairs(scores) do
        table.insert(sorted, {name = name, score = pts})
    end
    table.sort(sorted, function(a, b) return a.score > b.score end)

    local results = {}
    for rank, entry in ipairs(sorted) do
        table.insert(results, {
            rank   = rank,
            name   = entry.name,
            score  = entry.score,
            reward = Config.REWARDS[rank] or 0,
        })
    end

    for _, result in ipairs(results) do
        if result.reward > 0 then
            for _, plr in ipairs(playerList) do
                if plr.Name == result.name then
                    GiveCoinsFunc:Invoke(plr, result.reward)
                    break
                end
            end
        end
    end

    print("[GM] Phase: RESULTS")
    broadcast(GameStateChanged, "results", Config.RESULTS_TIME)
    broadcast(SendResults, results)

    task.wait(Config.RESULTS_TIME)
    if Config.RETURN_PLACE_ID ~= 0 then
        local ids = {}
        for _, plr in ipairs(playerList) do
            if plr and plr.Parent then table.insert(ids, plr) end
        end
        pcall(function() TeleportService:TeleportAsync(Config.RETURN_PLACE_ID, ids) end)
    end
    broadcast(SetQueueState, false)
    for _, plr in ipairs(playerList) do
        if plr and plr.Parent and inactivePlayers[plr] then
            releasePlayer(plr)
        end
    end

    print("[GM] Session finished")
end

-- Physical lobby buttons: server press visual; action only when player stops on button.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local OpenCasinoPage = Remotes:WaitForChild("OpenCasinoPage")

local STOP_SPEED = Config.BUTTON_STOP_SPEED or 1
local PRESS_DEPTH = Config.BUTTON_PRESS_DEPTH or 0.45
local TWEEN_TIME = Config.BUTTON_TWEEN_TIME or 0.05

local ACTION_BY_NAME = {
    ["LuckyWheel"] = { kind = "casino", page = "wheel" },
    ["Plinko"] = { kind = "casino", page = "slots3" },
    ["1RowSlots"] = { kind = "casino", page = "slots1" },
    ["5ReelSlots"] = { kind = "casino", page = "slots2" },
    ["Diamond Mines"] = { kind = "casino", page = "mines" },
    ["3 Player Game"] = { kind = "queue", size = 3 },
    ["5 Player Game"] = { kind = "queue", size = 5 },
}

local lobbyFolder = workspace:WaitForChild("Floating Lobby")
local buttonsRoot = lobbyFolder:WaitForChild("PhysicalButtons")

local function getPlayerFromPart(hit)
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then
        return nil
    end
    return Players:GetPlayerFromCharacter(model)
end

local function setPressed(button, restCF, pressed)
    local goal = if pressed then restCF * CFrame.new(0, -PRESS_DEPTH, 0) else restCF
    TweenService:Create(
        button,
        TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = goal }
    ):Play()
end

local function moveToLocalSpawner(plr, action)
    local char = plr.Character
    if not char then
        return
    end
    local spawner = lobbyFolder:FindFirstChild(action.kind .. "Spawner")
    if not spawner then
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then
        return
    end
    hrp.CFrame = spawner.CFrame * CFrame.new(0, 5, 0)
end

local function activateButton(plr, action)
    if action.kind == "queue" then
        joinQueue(plr, action.size)
    elseif action.kind == "casino" then
        OpenCasinoPage:FireClient(plr, action.page)
    end
end

local function playerOverlapsSensor(plr, sensor)
    local char = plr.Character
    if not char then
        return false
    end
    for _, part in workspace:GetPartsInPart(sensor) do
        if part:IsDescendantOf(char) then
            return true
        end
    end
    return false
end

local function playerIsStopped(plr)
    local char = plr.Character
    if not char then
        return false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then
        return false
    end
    local vel = hrp.AssemblyLinearVelocity
    local horiz = Vector3.new(vel.X, 0, vel.Z).Magnitude
    return horiz <= STOP_SPEED
end

local function prepareButtonModel(model)
    if not model:IsA("Model") then
        return
    end
    if model:GetAttribute("GMButtonWired") then
        return
    end
    local action = ACTION_BY_NAME[model.Name]
    if not action then
        return
    end

    local button = model:FindFirstChild("Button")
    local sensor = model:FindFirstChild("InvisPart")
    if not (button and button:IsA("BasePart") and sensor and sensor:IsA("BasePart")) then
        warn("[GM] Physical button missing Button/InvisPart:", model:GetFullName())
        return
    end

    model:SetAttribute("GMButtonWired", true)

    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    sensor.CanCollide = false
    sensor.CanTouch = true
    sensor.Transparency = 1
    button.CanCollide = true

    local restCF = button.CFrame
    local touching = {}
    local fired = {}
    local visuallyDown = false
    local pollConn = nil

    local function refreshVisual()
        local anyone = next(touching) ~= nil
        if anyone == visuallyDown then
            return
        end
        visuallyDown = anyone
        setPressed(button, restCF, visuallyDown)
    end

    local function stopPoll()
        if pollConn then
            pollConn:Disconnect()
            pollConn = nil
        end
    end

    local function onLeave(plr)
        if not touching[plr] then
            return
        end
        touching[plr] = nil
        fired[plr] = nil
        refreshVisual()
        if next(touching) == nil then
            stopPoll()
        end
    end

    local function ensurePoll()
        if pollConn then
            return
        end
        pollConn = RunService.Heartbeat:Connect(function()
            for plr in pairs(touching) do
                if not playerOverlapsSensor(plr, sensor) then
                    onLeave(plr)
                elseif not fired[plr] and playerIsStopped(plr) then
                    fired[plr] = true
                    moveToLocalSpawner(plr, action)
                    activateButton(plr, action)
                end
            end
        end)
    end

    local function onEnter(plr)
        if touching[plr] then
            return
        end
        touching[plr] = true
        fired[plr] = false
        refreshVisual()
        ensurePoll()
    end

    sensor.Touched:Connect(function(hit)
        if not hit:IsA("BasePart") then
            return
        end
        local plr = getPlayerFromPart(hit)
        if plr then
            onEnter(plr)
        end
    end)

    Players.PlayerRemoving:Connect(function(plr)
        onLeave(plr)
    end)
end

local function wireButtonFolder(folder)
    if not folder then
        return
    end
    for _, child in folder:GetChildren() do
        if child:IsA("Model") then
            prepareButtonModel(child)
        elseif child:IsA("Folder") then
            wireButtonFolder(child)
        end
    end
end

wireButtonFolder(buttonsRoot)
buttonsRoot.DescendantAdded:Connect(function(inst)
    if inst:IsA("Model") and ACTION_BY_NAME[inst.Name] then
        task.defer(function()
            prepareButtonModel(inst)
        end)
    end
end)

print("[Draw for Slots] Physical buttons ready. Queue sizes: " .. table.concat(Config.QUEUE_SIZES, ", "))
