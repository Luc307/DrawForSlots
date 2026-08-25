-- CasinoService: Slots1 / Slots2 / Plinko / Wheel / Mines (CoinService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinService = script.Parent:WaitForChild("CoinService")
local AdjustCoinsFunc = CoinService:WaitForChild("AdjustCoinsFunc")
local GetCoinsFunc = CoinService:WaitForChild("GetCoinsFunc")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MIN_BET = 10
local MAX_BET = 10000
local DEFAULT_BET = 100
local MAX_PLINKO_BALLS = 5
local TARGET_RTP = 0.9

local function clampBet(bet: any): number
	bet = tonumber(bet) or DEFAULT_BET
	return math.max(MIN_BET, math.min(math.floor(bet), MAX_BET))
end

local function getCoins(player: Player): number
	return GetCoinsFunc:Invoke(player) :: number
end

local function addCoins(player: Player, delta: number)
	AdjustCoinsFunc:Invoke(player, delta)
end

-- ── Slots2 ───────────────────────────────────────────────
local spinSlots2 = Remotes:WaitForChild("SpinSlots2")
local slotResult2 = Remotes:WaitForChild("SlotResult2")
local confirmSpin2 = Remotes:WaitForChild("ConfirmSpin2")

local SYMBOLS2 = { "🍋", "🍒", "🔔", "🍀", "7️⃣", "💎" }
local OUTCOMES2 = {
	{ name = "diamond_3", weight = 100, factor = 1.60, sym = "💎", cnt = 3 },
	{ name = "diamond_4", weight = 40, factor = 4.43, sym = "💎", cnt = 4 },
	{ name = "diamond_5", weight = 15, factor = 16.02, sym = "💎", cnt = 5 },
	{ name = "seven_3", weight = 250, factor = 1.13, sym = "7️⃣", cnt = 3 },
	{ name = "seven_4", weight = 100, factor = 2.64, sym = "7️⃣", cnt = 4 },
	{ name = "seven_5", weight = 40, factor = 8.86, sym = "7️⃣", cnt = 5 },
	{ name = "bar_3", weight = 600, factor = 0.90, sym = "🍀", cnt = 3 },
	{ name = "bar_4", weight = 250, factor = 1.79, sym = "🍀", cnt = 4 },
	{ name = "bar_5", weight = 120, factor = 4.43, sym = "🍀", cnt = 5 },
	{ name = "bell_3", weight = 1300, factor = 0.71, sym = "🔔", cnt = 3 },
	{ name = "bell_4", weight = 600, factor = 1.13, sym = "🔔", cnt = 4 },
	{ name = "bell_5", weight = 300, factor = 2.64, sym = "🔔", cnt = 5 },
	{ name = "cherry_3", weight = 1700, factor = 0.61, sym = "🍒", cnt = 3 },
	{ name = "cherry_4", weight = 800, factor = 0.99, sym = "🍒", cnt = 4 },
	{ name = "cherry_5", weight = 400, factor = 1.79, sym = "🍒", cnt = 5 },
	{ name = "lemon_3", weight = 1000, factor = 0.44, sym = "🍋", cnt = 3 },
	{ name = "lemon_4", weight = 400, factor = 0.71, sym = "🍋", cnt = 4 },
	{ name = "lemon_5", weight = 200, factor = 1.13, sym = "🍋", cnt = 5 },
	{ name = "near", weight = 1200, factor = 0.09, sym = nil, cnt = 2 },
	{ name = "loss", weight = 585, factor = 0.0, sym = nil, cnt = 0 },
}

local function pickOutcome2()
	local r = math.random(1, 10000)
	local cum = 0
	for _, o in ipairs(OUTCOMES2) do
		cum += o.weight
		if r <= cum then
			return o
		end
	end
	return OUTCOMES2[#OUTCOMES2]
end

local function randSym2(exclude)
	local s = SYMBOLS2[math.random(1, #SYMBOLS2)]
	if exclude then
		while s == exclude do
			s = SYMBOLS2[math.random(1, #SYMBOLS2)]
		end
	end
	return s
end

local function buildSyms5(outcome)
	local s5 = {}
	if outcome.sym then
		for i = 1, outcome.cnt do
			s5[i] = outcome.sym
		end
		for i = outcome.cnt + 1, 5 do
			s5[i] = randSym2(outcome.sym)
		end
		for i = 5, 2, -1 do
			local j = math.random(1, i)
			s5[i], s5[j] = s5[j], s5[i]
		end
	elseif outcome.name == "near" then
		local chosen = SYMBOLS2[math.random(1, #SYMBOLS2)]
		s5 = { chosen, chosen, randSym2(chosen), randSym2(chosen), randSym2(chosen) }
		for i = 5, 2, -1 do
			local j = math.random(1, i)
			s5[i], s5[j] = s5[j], s5[i]
		end
	else
		s5[1] = SYMBOLS2[math.random(1, #SYMBOLS2)]
		for i = 2, 5 do
			local sv = SYMBOLS2[math.random(1, #SYMBOLS2)]
			local t = 0
			while t < 10 and sv == s5[i - 1] do
				sv = SYMBOLS2[math.random(1, #SYMBOLS2)]
				t += 1
			end
			s5[i] = sv
		end
		local cts = {}
		for _, v in ipairs(s5) do
			cts[v] = (cts[v] or 0) + 1
		end
		for sym, c in pairs(cts) do
			if c >= 3 then
				for i = 1, 5 do
					if s5[i] == sym and c > 2 then
						s5[i] = randSym2(sym)
						c -= 1
					end
				end
			end
		end
	end
	return s5
end

local pending2: { [number]: { bet: number, factor: number } } = {}

spinSlots2.OnServerEvent:Connect(function(player, bet)
	bet = clampBet(bet)
	local cur = getCoins(player)
	if cur < bet then
		slotResult2:FireClient(player, false, nil, nil, nil, 0, cur)
		return
	end
	addCoins(player, -bet)
	local outcome = pickOutcome2()
	pending2[player.UserId] = { bet = bet, factor = outcome.factor }
	local syms = buildSyms5(outcome)
	slotResult2:FireClient(player, true, outcome.name, outcome.cnt, syms, bet, getCoins(player))
end)

confirmSpin2.OnServerEvent:Connect(function(player)
	local p = pending2[player.UserId]
	if not p then
		return
	end
	pending2[player.UserId] = nil
	addCoins(player, math.floor(p.bet * p.factor))
end)

-- ── Slots1 ───────────────────────────────────────────────
local spinSlots = Remotes:WaitForChild("SpinSlots")
local slotResult = Remotes:WaitForChild("SlotResult")
local confirmSpin = Remotes:WaitForChild("ConfirmSpin")

local RARITIES_SRV = {
	{ name = "Common", weight = 20, factor = 0.095 },
	{ name = "Uncommon", weight = 25, factor = 0.284 },
	{ name = "Epic", weight = 26, factor = 0.682 },
	{ name = "Mythic", weight = 24, factor = 1.412 },
	{ name = "Legendary", weight = 5, factor = 5.875 },
}

local function srvPick()
	local r = math.random(1, 100)
	local cum = 0
	for _, rar in ipairs(RARITIES_SRV) do
		cum += rar.weight
		if r <= cum then
			return rar
		end
	end
	return RARITIES_SRV[1]
end

local pending: { [number]: { bet: number, factor: number } } = {}

spinSlots.OnServerEvent:Connect(function(player, bet)
	bet = clampBet(bet)
	local cur = getCoins(player)
	if cur < bet then
		slotResult:FireClient(player, false, "Not enough Coins", {}, 0, cur)
		return
	end
	addCoins(player, -bet)
	local result = srvPick()
	pending[player.UserId] = { bet = bet, factor = result.factor }
	local seq = {}
	for i = 1, 60 do
		seq[i] = srvPick()
	end
	seq[50] = result
	slotResult:FireClient(player, true, result, seq, bet, getCoins(player))
end)

confirmSpin.OnServerEvent:Connect(function(player)
	local p = pending[player.UserId]
	if not p then
		return
	end
	pending[player.UserId] = nil
	addCoins(player, math.floor(p.bet * p.factor))
end)

-- ── Plinko ───────────────────────────────────────────────
local spinPlinko = Remotes:WaitForChild("SpinPlinko")
local plinkoResult = Remotes:WaitForChild("PlinkoResult")

local P_PROBS = { 1, 4, 10, 12.5, 12.5, 20, 12.5, 12.5, 10, 4, 1 }
local P_MULTS = { 5.544, 2.772, 1.243, 0.717, 0.382, 0.220, 0.382, 0.717, 1.243, 2.772, 5.544 }
local P_CUM = {}
do
	local pa = 0
	for i = 1, 11 do
		pa += P_PROBS[i]
		P_CUM[i] = pa
	end
end

local function pickSlot()
	local r = math.random() * 100
	for i = 1, 11 do
		if r <= P_CUM[i] then
			return i - 1
		end
	end
	return 10
end

local function pathForSlot(slot, rows)
	local path = {}
	for i = 1, rows do
		path[i] = 0
	end
	local idx = {}
	for i = 1, rows do
		idx[i] = i
	end
	for i = 1, slot do
		local j = math.random(i, rows)
		idx[i], idx[j] = idx[j], idx[i]
		path[idx[i]] = 1
	end
	return path
end

spinPlinko.OnServerEvent:Connect(function(player, ballPrice, numBalls, rows, _risk)
	ballPrice = clampBet(ballPrice)
	numBalls = math.max(1, math.min(math.floor(tonumber(numBalls) or 1), MAX_PLINKO_BALLS))
	rows = rows or 10
	local totalBet = ballPrice * numBalls
	local cur = getCoins(player)
	if cur < totalBet then
		plinkoResult:FireClient(player, false)
		return
	end
	addCoins(player, -totalBet)
	local allPaths, allSlots, allFactors = {}, {}, {}
	local totalWon = 0
	for bi = 1, numBalls do
		local slot = pickSlot()
		local factor = P_MULTS[slot + 1]
		totalWon += math.floor(ballPrice * factor)
		allPaths[bi] = pathForSlot(slot, rows)
		allSlots[bi] = slot
		allFactors[bi] = factor
	end
	addCoins(player, totalWon)
	plinkoResult:FireClient(player, true, allPaths, allSlots, allFactors, ballPrice, numBalls, getCoins(player))
end)

-- ── Lucky Wheel ──────────────────────────────────────────
-- Equal 12 segments; sum(mult)/12 = TARGET_RTP
local WHEEL_SAFE = { 0.3, 0.4, 0.5, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.5, 2.4 }
local WHEEL_RISK = { 0, 0, 0, 0, 0, 0, 0.25, 0.5, 1, 1.75, 2.5, 4.8 }
local WHEEL_SEGS = 12

local spinWheel = Remotes:WaitForChild("SpinWheel")
local wheelResult = Remotes:WaitForChild("WheelResult")
local confirmWheel = Remotes:WaitForChild("ConfirmWheel")

local pendingWheel: { [number]: { bet: number, factor: number } } = {}

local function pickWheelIndex(risk: boolean): number
	return math.random(1, WHEEL_SEGS)
end

spinWheel.OnServerEvent:Connect(function(player, bet, risk)
	bet = clampBet(bet)
	risk = risk == true
	local cur = getCoins(player)
	if cur < bet then
		wheelResult:FireClient(player, false, 0, 0, risk, bet, cur)
		return
	end
	if pendingWheel[player.UserId] then
		wheelResult:FireClient(player, false, 0, 0, risk, bet, cur)
		return
	end
	addCoins(player, -bet)
	local idx = pickWheelIndex(risk)
	local table_ = if risk then WHEEL_RISK else WHEEL_SAFE
	local factor = table_[idx]
	pendingWheel[player.UserId] = { bet = bet, factor = factor }
	-- Near-miss hint: index of a high neighbor for client anim bias (display only)
	local nearIdx = idx
	local best = -1
	for d = -1, 1, 2 do
		local n = ((idx - 1 + d) % WHEEL_SEGS) + 1
		if table_[n] > best then
			best = table_[n]
			nearIdx = n
		end
	end
	wheelResult:FireClient(player, true, idx, factor, risk, bet, getCoins(player), nearIdx, table_)
end)

confirmWheel.OnServerEvent:Connect(function(player)
	local p = pendingWheel[player.UserId]
	if not p then
		return
	end
	pendingWheel[player.UserId] = nil
	addCoins(player, math.floor(p.bet * p.factor))
end)

-- ── Diamond Mines ────────────────────────────────────────
local MINES_SIZES = {
	[3] = { cells = 9, bombs = 1 },
	[4] = { cells = 16, bombs = 3 },
	[5] = { cells = 25, bombs = 5 },
}

local startMines = Remotes:WaitForChild("StartMines")
local revealMines = Remotes:WaitForChild("RevealMines")
local collectMines = Remotes:WaitForChild("CollectMines")
local minesUpdate = Remotes:WaitForChild("MinesUpdate")

type MinesSession = {
	bet: number,
	size: number,
	cells: number,
	bombs: number,
	bombSet: { [number]: boolean },
	revealed: { [number]: boolean },
	safeCount: number,
	mult: number,
}

local minesSessions: { [number]: MinesSession } = {}

local function fairSurviveMult(cells: number, bombs: number, safeCount: number): number
	-- Product of conditional safe odds inverted
	local p = 1
	for i = 0, safeCount - 1 do
		local left = cells - i
		local safeLeft = cells - bombs - i
		if safeLeft <= 0 or left <= 0 then
			return 0
		end
		p *= safeLeft / left
	end
	if p <= 0 then
		return 0
	end
	return 1 / p
end

local function minesHouseMult(cells: number, bombs: number, safeCount: number): number
	if safeCount <= 0 then
		return 1
	end
	return TARGET_RTP * fairSurviveMult(cells, bombs, safeCount)
end

local function placeBombs(cells: number, bombs: number): { [number]: boolean }
	local set: { [number]: boolean } = {}
	local left = bombs
	while left > 0 do
		local i = math.random(1, cells)
		if not set[i] then
			set[i] = true
			left -= 1
		end
	end
	return set
end

startMines.OnServerEvent:Connect(function(player, bet, size)
	bet = clampBet(bet)
	size = math.floor(tonumber(size) or 3)
	local cfg = MINES_SIZES[size]
	if not cfg then
		minesUpdate:FireClient(player, "error", { msg = "Bad size" })
		return
	end
	if minesSessions[player.UserId] then
		minesUpdate:FireClient(player, "error", { msg = "Round active" })
		return
	end
	local cur = getCoins(player)
	if cur < bet then
		minesUpdate:FireClient(player, "error", { msg = "Not enough Coins", coins = cur })
		return
	end
	addCoins(player, -bet)
	local session: MinesSession = {
		bet = bet,
		size = size,
		cells = cfg.cells,
		bombs = cfg.bombs,
		bombSet = placeBombs(cfg.cells, cfg.bombs),
		revealed = {},
		safeCount = 0,
		mult = 1,
	}
	minesSessions[player.UserId] = session
	minesUpdate:FireClient(player, "started", {
		bet = bet,
		size = size,
		cells = cfg.cells,
		bombs = cfg.bombs,
		mult = 1,
		coins = getCoins(player),
	})
end)

revealMines.OnServerEvent:Connect(function(player, cellIndex)
	local session = minesSessions[player.UserId]
	if not session then
		minesUpdate:FireClient(player, "error", { msg = "No round" })
		return
	end
	cellIndex = math.floor(tonumber(cellIndex) or 0)
	if cellIndex < 1 or cellIndex > session.cells then
		minesUpdate:FireClient(player, "error", { msg = "Bad cell" })
		return
	end
	if session.revealed[cellIndex] then
		return
	end
	session.revealed[cellIndex] = true
	if session.bombSet[cellIndex] then
		local bombs = {}
		for i = 1, session.cells do
			if session.bombSet[i] then
				table.insert(bombs, i)
			end
		end
		minesSessions[player.UserId] = nil
		minesUpdate:FireClient(player, "bomb", {
			cell = cellIndex,
			bombs = bombs,
			coins = getCoins(player),
		})
		return
	end
	session.safeCount += 1
	session.mult = minesHouseMult(session.cells, session.bombs, session.safeCount)
	local maxSafe = session.cells - session.bombs
	local canCollect = session.safeCount < maxSafe
	minesUpdate:FireClient(player, "safe", {
		cell = cellIndex,
		safeCount = session.safeCount,
		mult = session.mult,
		payout = math.floor(session.bet * session.mult),
		canCollect = canCollect or session.safeCount >= 1,
		autoCollect = session.safeCount >= maxSafe,
	})
	if session.safeCount >= maxSafe then
		local pay = math.floor(session.bet * session.mult)
		minesSessions[player.UserId] = nil
		addCoins(player, pay)
		minesUpdate:FireClient(player, "collected", {
			payout = pay,
			mult = session.mult,
			coins = getCoins(player),
			cleared = true,
		})
	end
end)

collectMines.OnServerEvent:Connect(function(player)
	local session = minesSessions[player.UserId]
	if not session then
		minesUpdate:FireClient(player, "error", { msg = "No round" })
		return
	end
	if session.safeCount < 1 then
		minesUpdate:FireClient(player, "error", { msg = "Reveal first" })
		return
	end
	local pay = math.floor(session.bet * session.mult)
	minesSessions[player.UserId] = nil
	addCoins(player, pay)
	minesUpdate:FireClient(player, "collected", {
		payout = pay,
		mult = session.mult,
		coins = getCoins(player),
		cleared = false,
	})
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player.UserId] = nil
	pending2[player.UserId] = nil
	pendingWheel[player.UserId] = nil
	minesSessions[player.UserId] = nil
end)

print("[CasinoService] Running RTP=" .. TARGET_RTP)
