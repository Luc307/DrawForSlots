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

for _, size in ipairs(Config.QUEUE_SIZES) do
    queueMembers[size] = {}
end

local runSession

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
    broadcastQueueLobby(size)
end

local function joinQueue(plr, size)
    if not queueMembers[size] then return end
    if queuedSize[plr] then return end

    queuedSize[plr] = size
    table.insert(queueMembers[size], plr)

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

Players.PlayerRemoving:Connect(leaveQueue)

local LeaveQueueRequest = Remotes:WaitForChild("LeaveQueueRequest")
LeaveQueueRequest.OnServerEvent:Connect(function(plr)
    leaveQueue(plr)
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
            submissions[plr.UserId] = {type = "drawing", content = strokeData}
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

    print("[GM] Session finished")
end

-- QueueSize attribute on each ProximityPrompt selects the target queue.
local lobbyFolder = workspace:WaitForChild("Floating Lobby")
local queueDummiesFolder = lobbyFolder:FindFirstChild("Dummies") or lobbyFolder:FindFirstChild("QueueDummies")
if not queueDummiesFolder then
    queueDummiesFolder = lobbyFolder:WaitForChild("Dummies", 10)
end

local function wireDummyPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if prompt:GetAttribute("GMWired") then return end
    local size = prompt:GetAttribute("QueueSize")
    if not size then return end
    prompt:SetAttribute("GMWired", true)
    prompt.Triggered:Connect(function(plr)
        joinQueue(plr, size)
    end)
end

local function wireAllDummies(folder)
    if not folder then return end
    for _, dummy in ipairs(folder:GetChildren()) do
        for _, descendant in ipairs(dummy:GetDescendants()) do
            wireDummyPrompt(descendant)
        end
        dummy.DescendantAdded:Connect(function(descendant)
            wireDummyPrompt(descendant)
        end)
    end
    folder.ChildAdded:Connect(function(dummy)
        task.defer(function()
            for _, descendant in ipairs(dummy:GetDescendants()) do
                wireDummyPrompt(descendant)
            end
            dummy.DescendantAdded:Connect(function(descendant)
                wireDummyPrompt(descendant)
            end)
        end)
    end)
end

wireAllDummies(queueDummiesFolder)
task.defer(function()
    task.wait(1)
    wireAllDummies(queueDummiesFolder)
end)

print("[Draw for Slots] Queue system ready. Sizes: " .. table.concat(Config.QUEUE_SIZES, ", "))
