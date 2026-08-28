-- ShopUI: Uses pre-built ShopGui from StarterGui (paste from Draw for Slots).
-- Wired to Paddle Remotes.Events + PlayerData Coins via Data remote.
local Players=game:GetService('Players'); local RS=game:GetService('ReplicatedStorage')
local SoundController=require(RS.Modules.SoundController)
local CasinoUiTheme=require(RS.Modules.CasinoUiTheme)
local TweenSvc=game:GetService('TweenService'); local RunSvc=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local player=Players.LocalPlayer; local pGui=player:WaitForChild('PlayerGui')

local Remotes = RS:WaitForChild('Remotes')
local GameConfig = require(RS:WaitForChild('GameConfig'))

local Signals = RS:WaitForChild("Signals")
local requestOpenUI = Signals:WaitForChild("RequestOpenUI") :: BindableEvent
local spinStateSignal = Signals:WaitForChild("SpinStateChanged") :: BindableEvent

local CLICK_MAX_DIST = 32

-- Responsive layout: game panel fills most of screen
local REF_VIEWPORT_SHORT = 720
local MIN_UI_SCALE = 0.55
local MAX_UI_SCALE = 1.0
local MOBILE_BREAKPOINT = 700
local CARD_ASPECT = 1.33
local DESKTOP_CARD_WIDTH = 0.9
local MOBILE_CARD_WIDTH = 0.94
local DESKTOP_CARD_SIZE = UDim2.new(DESKTOP_CARD_WIDTH, 0, DESKTOP_CARD_WIDTH / CARD_ASPECT, 0)
local MOBILE_CARD_SIZE = UDim2.new(MOBILE_CARD_WIDTH, 0, MOBILE_CARD_WIDTH / CARD_ASPECT, 0)
local CARD_POS_SHOW = UDim2.new(0.5, 0, 0.5, 0)
local CARD_POS_HIDE = UDim2.new(0.5, 0, 0.68, 0)
local BADGE_SIZE = UDim2.new(0, 180, 0, 44)
local CASINO_MAX_SIZE = Vector2.new(1500, 1000)
local CASINO_MIN_SIZE = Vector2.new(360, 280)
local GAME_AREA_TOP = 0.16
local GAME_AREA_HEIGHT = 0.54
local CONTROLS_TOP = 0.78
local CONTROLS_HEIGHT = 0.16

-- ── Wait for pre-built ShopGui ────────────────────────────
local sg       = pGui:WaitForChild("ShopGui")
local overlay  = sg:WaitForChild("Overlay")
local card     = sg:WaitForChild("MainFrame")
local coinBadge= sg:WaitForChild("InnerCoinBadge")
local innerCoinLbl = coinBadge:WaitForChild("InnerCoinLbl")
local pages    = card:WaitForChild("Pages")
local sheen    = card:WaitForChild("Sheen")
local particleCanvas = card:WaitForChild("ParticleCanvas")
local closeBtn = card:WaitForChild("CloseBtn")
local csw      = card:WaitForChild("ShimmerSweep")

local tilesPage  = pages:WaitForChild("TilesPage")
local slotsPage  = pages:WaitForChild("Slots1Page")
local slots2Page = pages:WaitForChild("Slots2Page")
local slots3Page = pages:WaitForChild("Slots3Page")

local function makeLabel(parent, name, text, size, pos)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.Size = size
	l.Position = pos
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextScaled = true
	l.ZIndex = 20
	l.Parent = parent
	return l
end

local function makeBtn(parent, name, text, size, pos)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = pos
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(48, 92, 180)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.BorderSizePixel = 0
	b.ZIndex = 20
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	return b
end

local function ensureCasinoPage(pageName: string): Frame
	local page = pages:FindFirstChild(pageName)
	if page and page:IsA("Frame") then
		return page
	end
	page = Instance.new("Frame")
	page.Name = pageName
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.ZIndex = 6
	page.Parent = pages
	return page
end

local function ensureTile(tileName: string, labelText: string, iconText: string): TextButton?
	local tileRow = tilesPage:FindFirstChild("TileRow")
	if not tileRow then
		return nil
	end
	local existing = tileRow:FindFirstChild(tileName)
	if existing and existing:IsA("TextButton") then
		return existing
	end
	local template = tileRow:FindFirstChild("Slots3Tile") or tileRow:FindFirstChildWhichIsA("TextButton")
	if not template or not template:IsA("TextButton") then
		return nil
	end
	local tile = template:Clone()
	tile.Name = tileName
	tile.Parent = tileRow
	local nameLbl = tile:FindFirstChild("NameLabel", true)
	if nameLbl and nameLbl:IsA("TextLabel") then
		nameLbl.Text = labelText
	end
	local icon = tile:FindFirstChild("PreviewIcon", true)
	if icon and icon:IsA("TextLabel") then
		icon.Text = iconText
		icon.Font = Enum.Font.GothamBlack
		icon.TextScaled = true
	end
	return tile
end

local wheelPage = ensureCasinoPage("WheelPage")
local minesPage = ensureCasinoPage("MinesPage")
ensureTile("WheelTile", "Lucky Wheel", "W")
ensureTile("MinesTile", "Mines", "M")
do
	local tileRow = tilesPage:FindFirstChild("TileRow")
	if tileRow then
		local layout = tileRow:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0.012, 0)
		end
		for _, tile in ipairs(tileRow:GetChildren()) do
			if tile:IsA("GuiButton") then
				tile.Size = UDim2.new(0.18, 0, 0.9, 0)
			end
		end
	end
end

-- Build Wheel page chrome once
do
	if not wheelPage:FindFirstChild("WheelStage") then
		local stage = Instance.new("Frame")
		stage.Name = "WheelStage"
		stage.AnchorPoint = Vector2.new(0.5, 0.5)
		stage.Position = UDim2.new(0.5, 0, 0.43, 0)
		stage.Size = UDim2.new(0.4, 0, 0.53, 0)
		stage.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
		stage.BorderSizePixel = 0
		stage.ClipsDescendants = true
		stage.ZIndex = 10
		stage.Parent = wheelPage
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(1, 0)
		sc.Parent = stage
		local disc = Instance.new("Frame")
		disc.Name = "WheelDisc"
		disc.Size = UDim2.fromScale(1, 1)
		disc.BackgroundTransparency = 1
		disc.ZIndex = 11
		disc.Parent = stage
		local betRow = Instance.new("Frame")
		betRow.Name = "BetRow"
		betRow.Size = UDim2.new(0.34, 0, 0.15, 0)
		betRow.Position = UDim2.new(0.06, 0, 0.85, 0)
		betRow.AnchorPoint = Vector2.new(0, 0.5)
		betRow.BackgroundTransparency = 1
		betRow.ZIndex = 20
		betRow.Parent = wheelPage
		makeBtn(betRow, "MinusBtn", "-", UDim2.new(0.18, 0, 0.85, 0), UDim2.new(0, 0, 0.5, 0))
		local betIn = Instance.new("TextBox")
		betIn.Name = "BetInput"
		betIn.Size = UDim2.new(0.34, 0, 0.85, 0)
		betIn.Position = UDim2.new(0.2, 0, 0.5, 0)
		betIn.AnchorPoint = Vector2.new(0, 0.5)
		betIn.Text = "100"
		betIn.Font = Enum.Font.GothamBold
		betIn.TextScaled = true
		betIn.BackgroundColor3 = Color3.fromRGB(28, 42, 82)
		betIn.TextColor3 = Color3.fromRGB(255, 255, 255)
		betIn.BorderSizePixel = 0
		betIn.ZIndex = 20
		betIn.Parent = betRow
		local bic = Instance.new("UICorner")
		bic.CornerRadius = UDim.new(0, 12)
		bic.Parent = betIn
		makeBtn(betRow, "PlusBtn", "+", UDim2.new(0.18, 0, 0.85, 0), UDim2.new(0.56, 0, 0.5, 0))
		makeBtn(betRow, "MaxBtn", "MAX", UDim2.new(0.24, 0, 0.85, 0), UDim2.new(0.76, 0, 0.5, 0))
		for _, n in ipairs({ "MinusBtn", "PlusBtn", "MaxBtn" }) do
			local b = betRow:FindFirstChild(n)
			if b and b:IsA("GuiObject") then
				b.AnchorPoint = Vector2.new(0, 0.5)
			end
		end
		local riskBtn = makeBtn(wheelPage, "RiskBtn", "RISK: OFF", UDim2.new(0.13, 0, 0.15, 0), UDim2.new(0.42, 0, 0.85, 0))
		riskBtn.AnchorPoint = Vector2.new(0, 0.5)
		local spinBtn = makeBtn(wheelPage, "SpinBtn", "SPIN", UDim2.new(0.15, 0, 0.15, 0), UDim2.new(0.56, 0, 0.85, 0))
		spinBtn.AnchorPoint = Vector2.new(0, 0.5)
		local resultBg = Instance.new("Frame")
		resultBg.Name = "ResultBg"
		resultBg.Size = UDim2.new(0.22, 0, 0.15, 0)
		resultBg.Position = UDim2.new(0.96, 0, 0.85, 0)
		resultBg.AnchorPoint = Vector2.new(1, 0.5)
		resultBg.BackgroundColor3 = Color3.fromRGB(12, 18, 40)
		resultBg.Visible = false
		resultBg.ZIndex = 25
		resultBg.Parent = wheelPage
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 12)
		rc.Parent = resultBg
		makeLabel(resultBg, "CoinsLbl", "", UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0))
		makeLabel(resultBg, "MultLbl", "", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.55))
	end
	-- Clean stale hand-built caption that overlaps MinusBtn on pre-existing ShopGui
	local betRowWheel = wheelPage:FindFirstChild("BetRow")
	if betRowWheel then
		local strayCaption = betRowWheel:FindFirstChild("TextLabel")
		if strayCaption then
			strayCaption:Destroy()
		end
	end
end

-- Build Mines page chrome once (fill missing kids if ShopGui partial)
do
	if not minesPage:FindFirstChild("GridFrame") then
		local grid = Instance.new("Frame")
		grid.Name = "GridFrame"
		grid.AnchorPoint = Vector2.new(0.5, 0.5)
		grid.Position = UDim2.new(0.5, 0, 0.43, 0)
		grid.Size = UDim2.new(0.42, 0, 0.55, 0)
		grid.BackgroundColor3 = Color3.fromRGB(28, 42, 82)
		grid.BorderSizePixel = 0
		grid.ZIndex = 10
		grid.Parent = minesPage
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0, 16)
		gc.Parent = grid
	end
	do
		local grid = minesPage:FindFirstChild("GridFrame")
		if grid and not grid:FindFirstChild("GridInner") then
			local inner = Instance.new("Frame")
			inner.Name = "GridInner"
			inner.AnchorPoint = Vector2.new(0.5, 0.5)
			inner.Position = UDim2.fromScale(0.5, 0.5)
			inner.Size = UDim2.fromScale(0.9, 0.92)
			inner.BackgroundTransparency = 1
			inner.ZIndex = 11
			inner.Parent = grid
			local ar = Instance.new("UIAspectRatioConstraint")
			ar.AspectRatio = 1
			ar.DominantAxis = Enum.DominantAxis.Height
			ar.Parent = inner
		end
	end
	local left = minesPage:FindFirstChild("LeftPanel")
	if not left then
		left = Instance.new("Frame")
		left.Name = "LeftPanel"
		left.Size = UDim2.new(0.92, 0, 0.18, 0)
		left.Position = UDim2.new(0.5, 0, 0.76, 0)
		left.AnchorPoint = Vector2.new(0.5, 0)
		left.BackgroundTransparency = 1
		left.ZIndex = 15
		left.Parent = minesPage
	end
	-- Clean stale nested containers from hand-built ShopGui (InfoBox/SizeGroup/Controls
	-- don't match the flat names below, so leaving them causes duplicate overlapping UI)
	local staleInfoBox = left:FindFirstChild("InfoBox")
	if staleInfoBox then
		staleInfoBox:Destroy()
	end
	local staleSizeGroup = left:FindFirstChild("SizeGroup")
	if staleSizeGroup then
		staleSizeGroup:Destroy()
	end

	local win = left:FindFirstChild("WinDisplay")
	if not win then
		win = Instance.new("Frame")
		win.Name = "WinDisplay"
		win.Size = UDim2.new(0.18, 0, 0.9, 0)
		win.Position = UDim2.new(0.98, 0, 0.5, 0)
		win.AnchorPoint = Vector2.new(1, 0.5)
		win.BackgroundColor3 = Color3.fromRGB(12, 18, 40)
		win.BorderSizePixel = 0
		win.ZIndex = 31
		win.Parent = left
		local wc = Instance.new("UICorner")
		wc.CornerRadius = UDim.new(0, 12)
		wc.Parent = win
	end
	if not win:FindFirstChild("MultLbl") and not left:FindFirstChild("MultLbl") then
		makeLabel(win, "MultLbl", "1.00x", UDim2.new(1, -8, 0.48, 0), UDim2.new(0.5, 0, 0.08, 0))
		local ml = win:FindFirstChild("MultLbl")
		if ml and ml:IsA("GuiObject") then
			ml.AnchorPoint = Vector2.new(0.5, 0)
		end
	end
	if not win:FindFirstChild("InfoLbl") and not left:FindFirstChild("InfoLbl") then
		makeLabel(win, "InfoLbl", "Bombs: 1", UDim2.new(1, -8, 0.38, 0), UDim2.new(0.5, 0, 0.92, 0))
		local il = win:FindFirstChild("InfoLbl")
		if il and il:IsA("GuiObject") then
			il.AnchorPoint = Vector2.new(0.5, 1)
		end
	end
	-- Migrate old side-panel labels into WinDisplay
	local oldMult = left:FindFirstChild("MultLbl")
	if oldMult then
		oldMult.Parent = win
	end
	local oldInfo = left:FindFirstChild("InfoLbl")
	if oldInfo then
		oldInfo.Parent = win
	end
	local sizeRow = left:FindFirstChild("SizeRow")
	if not sizeRow then
		sizeRow = Instance.new("Frame")
		sizeRow.Name = "SizeRow"
		sizeRow.Size = UDim2.new(0.22, 0, 0.85, 0)
		sizeRow.Position = UDim2.new(0.02, 0, 0.5, 0)
		sizeRow.AnchorPoint = Vector2.new(0, 0.5)
		sizeRow.BackgroundTransparency = 1
		sizeRow.Parent = left
		makeBtn(sizeRow, "Size3", "3x3", UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0))
		makeBtn(sizeRow, "Size4", "4x4", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.35, 0, 0, 0))
		makeBtn(sizeRow, "Size5", "5x5", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.7, 0, 0, 0))
	end
	local betRow = left:FindFirstChild("BetRow")
	if not betRow then
		betRow = Instance.new("Frame")
		betRow.Name = "BetRow"
		betRow.Size = UDim2.new(0.26, 0, 0.85, 0)
		betRow.Position = UDim2.new(0.26, 0, 0.5, 0)
		betRow.AnchorPoint = Vector2.new(0, 0.5)
		betRow.BackgroundTransparency = 1
		betRow.Parent = left
	end
	local staleControls = betRow:FindFirstChild("Controls")
	if staleControls then
		staleControls:Destroy()
	end
	local staleCaption = betRow:FindFirstChild("TextLabel")
	if staleCaption then
		staleCaption:Destroy()
	end
	if not betRow:FindFirstChild("MinusBtn") then
		makeBtn(betRow, "MinusBtn", "-", UDim2.new(0.22, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	end
	if not betRow:FindFirstChild("BetInput") then
		local existingBox = betRow:FindFirstChildWhichIsA("TextBox")
		if existingBox then
			existingBox.Name = "BetInput"
		else
			local betIn = Instance.new("TextBox")
			betIn.Name = "BetInput"
			betIn.Size = UDim2.new(0.5, 0, 1, 0)
			betIn.Position = UDim2.new(0.25, 0, 0, 0)
			betIn.Text = "100"
			betIn.Font = Enum.Font.GothamBold
			betIn.TextScaled = true
			betIn.BackgroundColor3 = Color3.fromRGB(28, 42, 82)
			betIn.TextColor3 = Color3.fromRGB(255, 255, 255)
			betIn.BorderSizePixel = 0
			betIn.Parent = betRow
			local bic = Instance.new("UICorner")
			bic.CornerRadius = UDim.new(0, 12)
			bic.Parent = betIn
		end
	end
	if not betRow:FindFirstChild("PlusBtn") then
		makeBtn(betRow, "PlusBtn", "+", UDim2.new(0.22, 0, 1, 0), UDim2.new(0.78, 0, 0, 0))
	end
	if not left:FindFirstChild("StartBtn") then
		makeBtn(left, "StartBtn", "START", UDim2.new(0.20, 0, 0.78, 0), UDim2.new(0.62, 0, 0.5, 0))
		local sb = left:FindFirstChild("StartBtn")
		if sb and sb:IsA("GuiObject") then
			sb.AnchorPoint = Vector2.new(0.5, 0.5)
		end
	end
	local staleCollect = left:FindFirstChild("CollectBtn")
	if staleCollect then
		staleCollect:Destroy()
	end
end

local sndCommon   = RS.Sounds.RewardBasic
local sndEpic     = RS.Sounds.RewardMid
local sndLegend   = RS.Sounds.Jackpot
local sndBad      = RS.Sounds.RewardBad
local WIN_SOUNDS  = {Common=sndCommon,Uncommon=sndCommon,Epic=sndEpic,Mythic=sndEpic,Legendary=sndLegend}

local function fireSpinState(state, sound)
	spinStateSignal:Fire(state, sound)
end

local isSpinning=false; local isSpinning2=false; local isP3=false
local isWheelSpinning=false; local isMinesBusy=false; local minesRoundActive=false
local menuOpen=false
local plinkoLayoutHook: (() -> ())? = nil

for _,obj in ipairs(card:GetDescendants()) do
	if obj.Name == "TileSweep" then
		obj:Destroy()
	end
end

do
	local hud = pGui:FindFirstChild("CoinHUDGui")
	if hud then hud:Destroy() end
end

local function getLobbyCoinLabel()
	local sgMain = pGui:FindFirstChild('HyperSketchGui') or pGui:FindFirstChild(GameConfig.MAIN_GUI_NAME)
	if not sgMain then return nil end
	local hud = sgMain:FindFirstChild('HudCoinsLabel')
	if hud and hud:IsA('TextLabel') then
		return hud
	end
	local lobbyCard = sgMain:FindFirstChild('LobbyFrame') and sgMain.LobbyFrame:FindFirstChild('PlayerCard')
	return lobbyCard and lobbyCard:FindFirstChild('CoinLabel')
end

local function forceCloseGui()
	menuOpen = false
	sg.Enabled = false
	overlay.BackgroundTransparency = 1
	overlay.Active = false
	coinBadge.Visible = false
	innerCoinLbl.Visible = false
	local shadow = sg:FindFirstChild("CardShadow")
	if shadow then shadow.Visible = false end
	local lobbyCoin = getLobbyCoinLabel()
	if lobbyCoin then
		local base = pGui:FindFirstChild('Base')
		local dailyBusy = base and base:GetAttribute('DailyRewardBusy') == true
		local dailyPanel = base and base:FindFirstChild('DailyReward')
		local dailyOpen = dailyBusy or (dailyPanel ~= nil and dailyPanel.Visible)
		local mainGui = lobbyCoin.Parent
		local inQueue = mainGui and mainGui:GetAttribute('InQueue') == true
		if not dailyOpen and not inQueue then
			lobbyCoin.Visible = true
		end
	end
end
forceCloseGui()
card.BackgroundTransparency = 0
csw.Visible = false


local THEME = CasinoUiTheme.THEME
local styleGhostBtn = CasinoUiTheme.styleGhostBtn
local stylePrimaryBtn = CasinoUiTheme.stylePrimaryBtn
local stylePanel = CasinoUiTheme.stylePanel
local styleTitle = CasinoUiTheme.styleTitle
local styleSubtext = CasinoUiTheme.styleSubtext
local fitText = CasinoUiTheme.fitText
local setResultContrast = CasinoUiTheme.setResultContrast
local styleResultBox = CasinoUiTheme.styleResultBox
local setResultOutcome = CasinoUiTheme.setResultOutcome
local setResultError = CasinoUiTheme.setResultError
local layoutResultLabels = CasinoUiTheme.layoutResultLabels
local ensureResultLabels = CasinoUiTheme.ensureResultLabels
local ensureGameTitle = CasinoUiTheme.ensureGameTitle
local function applyQueueTheme()
	CasinoUiTheme.applyQueueTheme({
		screenGui = sg,
		overlay = overlay,
		card = card,
		pages = pages,
		closeBtn = closeBtn,
		coinBadge = coinBadge,
		innerCoinLbl = innerCoinLbl,
		tilesPage = tilesPage,
		slotsPage = slotsPage,
		slots2Page = slots2Page,
		slots3Page = slots3Page,
		wheelPage = wheelPage,
		minesPage = minesPage,
	})
end
applyQueueTheme()
local movingBgOrbs = {}
-- Moving casino background lives behind every page.
do
	local bg = card:FindFirstChild("BgPattern")
	if bg then bg:Destroy() end
    local old = card:FindFirstChild("MovingBg")
    if old then old:Destroy() end
    local movingBg = Instance.new("Frame")
    movingBg.Name = "MovingBg"
    movingBg.BackgroundTransparency = 1
    movingBg.Size = UDim2.fromScale(1, 1)
    movingBg.Position = UDim2.fromScale(0, 0)
    movingBg.ZIndex = 1
    movingBg.Parent = card
    local colors = {
        Color3.fromRGB(80, 220, 255),
        Color3.fromRGB(120, 90, 255),
        Color3.fromRGB(255, 196, 70),
    }
    for i, col in ipairs(colors) do
        local orb = Instance.new("Frame")
        orb.Name = "BgOrb" .. i
        orb.AnchorPoint = Vector2.new(0.5, 0.5)
        orb.Size = UDim2.fromScale(0.34, 0.34)
        orb.Position = UDim2.fromScale(0.2 + i * 0.2, 0.28 + i * 0.12)
        orb.BackgroundColor3 = col
        orb.BackgroundTransparency = 0.88
        orb.BorderSizePixel = 0
        orb.ZIndex = 1
        orb.Parent = movingBg
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = orb
        table.insert(movingBgOrbs, { orb = orb, x = orb.Position.X.Scale, y = orb.Position.Y.Scale, phase = i * 1.7 })
    end
end

-- Visible Plinko tile icon
do
    local tile3 = tilesPage:FindFirstChild("TileRow") and tilesPage.TileRow:FindFirstChild("Slots3Tile")
    local icon = tile3 and tile3:FindFirstChild("PreviewIcon", true)
    if icon and icon:IsA("TextLabel") then
        icon.Text = "P"
        icon.TextColor3 = Color3.fromRGB(255, 230, 120)
        icon.Font = Enum.Font.GothamBlack
        icon.TextScaled = true
    end
end

-- ── showPage ─────────────────────────────────────────────
local function showPage(name)
    if pages.Parent ~= card then
        pages.Parent = card
    end
    pages.Visible = true
    pages.Size = UDim2.fromScale(1, 1)
    pages.Position = UDim2.fromScale(0, 0)
    pages.BackgroundTransparency = 1
    pages.ZIndex = 5

    tilesPage.Visible = (name == "tiles")
    slotsPage.Visible = (name == "slots1")
    slots2Page.Visible = (name == "slots2")
    slots3Page.Visible = (name == "slots3")
    wheelPage.Visible = (name == "wheel")
    minesPage.Visible = (name == "mines")

    local active = tilesPage
    if name == "slots1" then
        active = slotsPage
        local rb = slotsPage:FindFirstChild("ResultBg")
        if rb then
            rb.Visible = false
        end
    elseif name == "slots2" then
        active = slots2Page
        local bar = slots2Page:FindFirstChild("BottomBar")
        local winSec = bar and bar:FindFirstChild("WinSection")
        if winSec then
            winSec.Visible = false
        end
        local rb = winSec and winSec:FindFirstChild("ResultBg")
        if rb then
            rb.Visible = false
        end
    elseif name == "slots3" then
        active = slots3Page
        local left = slots3Page:FindFirstChild("LeftPanel")
        local win = left and left:FindFirstChild("WinDisplay")
        if win then
            win.Visible = false
        end
    elseif name == "wheel" then
        active = wheelPage
        local rb = wheelPage:FindFirstChild("ResultBg")
        if rb then
            rb.Visible = false
        end
    elseif name == "mines" then
        active = minesPage
    end

    active.Size = UDim2.fromScale(1, 1)
    active.Position = UDim2.fromScale(0, 0)
    active.ZIndex = 6
    CasinoUiTheme.revealPage(active)
end
tilesPage.Visible = false
slotsPage.Visible = false
slots2Page.Visible = false
slots3Page.Visible = false
wheelPage.Visible = false
minesPage.Visible = false

-- Coin helpers
local cachedCoins = 0
local function setAllCoins(v)
    cachedCoins = tonumber(v) or 0
    local txt = cachedCoins .. ' Coins'
    if innerCoinLbl then innerCoinLbl.Text = txt end
    local bl = getLobbyCoinLabel()
    if bl then bl.Text = txt end
end

local function pulseCoinBadge()
    if not coinBadge.Visible then return end
    TweenSvc:Create(coinBadge, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    task.delay(0.15, function()
        TweenSvc:Create(coinBadge, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
    end)
end

local function refreshCoinsFromServer()
    local ok, coins = pcall(function() return Remotes:WaitForChild('GetCoins'):InvokeServer() end)
    if ok and typeof(coins) == 'number' then
        setAllCoins(coins)
        pulseCoinBadge()
    end
end

local function setShopCoinVisible(open)
    coinBadge.Visible = open
    innerCoinLbl.Visible = open
    local lobbyCoin = getLobbyCoinLabel()
    if lobbyCoin then
        local base = pGui:FindFirstChild('Base')
        local dailyBusy = base and base:GetAttribute('DailyRewardBusy') == true
        local dailyPanel = base and base:FindFirstChild('DailyReward')
        local dailyOpen = dailyBusy or (dailyPanel ~= nil and dailyPanel.Visible)
        local mainGui = lobbyCoin.Parent
        local inQueue = mainGui and mainGui:GetAttribute('InQueue') == true
        local showHud = (not open) and (not dailyOpen) and (not inQueue)
        lobbyCoin.Visible = showHud
        if lobbyCoin.Name == 'HudCoinsLabel' and showHud and lobbyCoin.TextTransparency > 0.9 then
            lobbyCoin.TextTransparency = 0.15
            local stroke = lobbyCoin:FindFirstChildOfClass('UIStroke')
            if stroke then stroke.Transparency = 0.55 end
        end
    end
end

-- ── Responsive scale for mobile / different screens ───────
local UserInputService = game:GetService('UserInputService')
local camera = Workspace.CurrentCamera
local uiScale = card:FindFirstChild('ResponsiveScale')
if not uiScale then
    uiScale = Instance.new('UIScale')
    uiScale.Name = 'ResponsiveScale'
    uiScale.Parent = card
end

-- AbsoluteSize includes ancestor UIScale; Position offsets do not.
local function getLocalSize(gui)
    local abs = gui.AbsoluteSize
    local s = 1
    local p = gui
    while p do
        local us = p:FindFirstChildWhichIsA('UIScale')
        if us then s = s * us.Scale end
        if p:IsA('LayerCollector') then break end
        p = p.Parent
    end
    s = math.max(s, 0.001)
    return abs.X / s, abs.Y / s
end

local function applyResponsiveLayout()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if vp.X < 1 or vp.Y < 1 then return end

    local shortest = math.min(vp.X, vp.Y)
    local scale = math.clamp(shortest / REF_VIEWPORT_SHORT, MIN_UI_SCALE, MAX_UI_SCALE)
    local isMobile = vp.X <= MOBILE_BREAKPOINT or (UserInputService.TouchEnabled and vp.X < 900)

    uiScale.Scale = scale
    card.Size = isMobile and MOBILE_CARD_SIZE or DESKTOP_CARD_SIZE
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = if menuOpen then CARD_POS_SHOW else card.Position

    local aspectLock = card:FindFirstChild('AspectLock')
    if not aspectLock then
        aspectLock = Instance.new('UIAspectRatioConstraint')
        aspectLock.Name = 'AspectLock'
        aspectLock.Parent = card
    end
    aspectLock.AspectRatio = CARD_ASPECT
    aspectLock.DominantAxis = Enum.DominantAxis.Width

    local sizeConstraint = card:FindFirstChildOfClass('UISizeConstraint')
    if not sizeConstraint then
        sizeConstraint = Instance.new('UISizeConstraint')
        sizeConstraint.Parent = card
    end
    sizeConstraint.MaxSize = CASINO_MAX_SIZE
    sizeConstraint.MinSize = CASINO_MIN_SIZE

    -- Card covers about 75% of viewport height, leaving black stage around it.
    local maxH = math.floor(vp.Y * 0.75)
    local maxW = math.floor(vp.X * 0.94)
    sizeConstraint.MaxSize = Vector2.new(
        math.min(CASINO_MAX_SIZE.X, maxW),
        math.min(CASINO_MAX_SIZE.Y, maxH)
    )

    local shadow = CasinoUiTheme.ensureCardShadow(card)
    shadow.Visible = menuOpen and sg.Enabled

    -- Shared pattern: title / play / controls
    local PAD = 0.04
    local TITLE_H = 0.1
    local PLAY_TOP = GAME_AREA_TOP
    local PLAY_H = GAME_AREA_HEIGHT
    local CTRL_TOP = CONTROLS_TOP
    local CTRL_H = CONTROLS_HEIGHT

    local tileRow = tilesPage:FindFirstChild('TileRow')
    if tileRow then
        local list = tileRow:FindFirstChildOfClass('UIListLayout')
        if list then list:Destroy() end
        tileRow.Size = UDim2.new(1 - PAD * 2, 0, 0.62, 0)
        tileRow.Position = UDim2.new(0.5, 0, 0.55, 0)
        tileRow.AnchorPoint = Vector2.new(0.5, 0.5)
        local idx = 0
        for _, tile in ipairs(tileRow:GetChildren()) do
            if tile:IsA('TextButton') then
                tile.Size = UDim2.new(0.3, 0, 1, 0)
                tile.Position = UDim2.new(idx * 0.35 + 0.015, 0, 0, 0)
                tile.AnchorPoint = Vector2.new(0, 0)
                local nameLbl = tile:FindFirstChild('NameLabel', true)
                if nameLbl and nameLbl:IsA('TextLabel') then
                    fitText(nameLbl, THEME.TEXT_MIN, THEME.TEXT_MAX)
                end
                local icon = tile:FindFirstChild('PreviewIcon', true)
                if icon and icon:IsA('TextLabel') then
                    fitText(icon, 22, 48)
                end
                idx += 1
            end
        end
    end
    local shopTitle = tilesPage:FindFirstChild('ShopTitle')
    if shopTitle and shopTitle:IsA('TextLabel') then
        styleTitle(shopTitle)
        shopTitle.Size = UDim2.new(0.8, 0, TITLE_H, 0)
        shopTitle.Position = UDim2.new(0.5, 0, 0.06, 0)
        shopTitle.AnchorPoint = Vector2.new(0.5, 0)
    end
    local divider = tilesPage:FindFirstChild('Divider')
    if divider then
        divider.Size = UDim2.new(0.5, 0, 0, 3)
        divider.Position = UDim2.new(0.5, 0, 0.17, 0)
        divider.AnchorPoint = Vector2.new(0.5, 0.5)
    end

    do
        ensureGameTitle(slotsPage, "One-Row Slots")
        -- One-row: game a bit lower, controls/result a bit higher
        local S1_PLAY_TOP = PLAY_TOP + 0.08
        local S1_CTRL_TOP = CTRL_TOP - 0.07
        local strip = slotsPage:FindFirstChild('StripOuter')
        if strip then
            strip.Size = UDim2.new(1 - PAD * 2, 0, PLAY_H * 0.55, 0)
            strip.Position = UDim2.new(0.5, 0, S1_PLAY_TOP, 0)
            strip.AnchorPoint = Vector2.new(0.5, 0)
            local clip = strip:FindFirstChild('StripClip')
            if clip then clip.ClipsDescendants = true end
        end
        local bet = slotsPage:FindFirstChild('BetRow')
        if bet then
            bet.Size = UDim2.new(0.42, 0, CTRL_H * 0.85, 0)
            bet.Position = UDim2.new(PAD + 0.02, 0, S1_CTRL_TOP + CTRL_H * 0.5, 0)
            bet.AnchorPoint = Vector2.new(0, 0.5)
            bet.ClipsDescendants = true
            for _, child in ipairs(bet:GetChildren()) do
                if child:IsA('TextLabel') or child:IsA('TextButton') or child:IsA('TextBox') then
                    fitText(child, THEME.TEXT_MIN, THEME.TEXT_MAX)
                end
            end
        end
        local spin = slotsPage:FindFirstChild('SpinBtn')
        if spin then
            spin.Size = UDim2.new(0.19, 0, CTRL_H * 0.85, 0)
            spin.Position = UDim2.new(0.52, 0, S1_CTRL_TOP + CTRL_H * 0.5, 0)
            spin.AnchorPoint = Vector2.new(0.5, 0.5)
            fitText(spin, 22, 44)
        end
        local result = slotsPage:FindFirstChild('ResultBg')
        if result then
            result.Size = UDim2.new(0.28, 0, CTRL_H * 0.85, 0)
            result.Position = UDim2.new(1 - PAD - 0.02, 0, S1_CTRL_TOP + CTRL_H * 0.5, 0)
            result.AnchorPoint = Vector2.new(1, 0.5)
            local oldSingle = result:FindFirstChild('ResultLbl')
            if oldSingle and not result:FindFirstChild('CoinsLbl') then
                oldSingle.Name = 'CoinsLbl'
            end
            local coinLbl, multLbl = ensureResultLabels(result, 'CoinsLbl', 'MultLbl')
            styleResultBox(result, { coinLbl, multLbl })
        end
    end

    do
        ensureGameTitle(slots2Page, "5-Reel Slots")
        local reel = slots2Page:FindFirstChild('ReelFrame')
        if reel then
            reel.Size = UDim2.new(1 - PAD * 2, 0, PLAY_H, 0)
            reel.Position = UDim2.new(0.5, 0, PLAY_TOP, 0)
            reel.AnchorPoint = Vector2.new(0.5, 0)
            local inner = reel:FindFirstChild('ReelInner')
            if inner then
                for _, child in ipairs(inner:GetChildren()) do
                    if child.Name:match('^Reel%d+$') then
                        child.ClipsDescendants = true
                    end
                end
            end
        end
        local bar = slots2Page:FindFirstChild('BottomBar')
        if bar then
            bar.AnchorPoint = Vector2.new(0.5, 0)
            bar.Position = UDim2.new(0.5, 0, CTRL_TOP, 0)
            bar.Size = UDim2.new(1 - PAD * 2, 0, CTRL_H, 0)
            local betSec = bar:FindFirstChild('BetSection')
            if betSec then
                local list = betSec:FindFirstChildOfClass('UIListLayout')
                if list then list:Destroy() end
                betSec.Size = UDim2.new(0.38, 0, 0.85, 0)
                betSec.Position = UDim2.new(0.02, 0, 0.5, 0)
                betSec.AnchorPoint = Vector2.new(0, 0.5)
                local betLabel = betSec:FindFirstChild('BetLabel')
                if betLabel then
                    betLabel.Size = UDim2.new(0.2, 0, 1, 0)
                    betLabel.Position = UDim2.new(0, 0, 0.5, 0)
                    betLabel.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(betLabel, THEME.TEXT_MIN, THEME.TEXT_MAX)
                end
                local minus = betSec:FindFirstChild('MinusBtn')
                if minus then
                    minus.Size = UDim2.new(0.14, 0, 0.75, 0)
                    minus.Position = UDim2.new(0.22, 0, 0.5, 0)
                    minus.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(minus, THEME.BTN_MIN, THEME.BTN_MAX)
                end
                local input = betSec:FindFirstChild('BetInput')
                if input then
                    input.Size = UDim2.new(0.26, 0, 0.75, 0)
                    input.Position = UDim2.new(0.37, 0, 0.5, 0)
                    input.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(input, THEME.TEXT_MIN, THEME.TEXT_MAX)
                end
                local plus = betSec:FindFirstChild('PlusBtn')
                if plus then
                    plus.Size = UDim2.new(0.14, 0, 0.75, 0)
                    plus.Position = UDim2.new(0.64, 0, 0.5, 0)
                    plus.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(plus, THEME.BTN_MIN, THEME.BTN_MAX)
                end
                local maxB = betSec:FindFirstChild('MaxBtn')
                if maxB then
                    maxB.Size = UDim2.new(0.18, 0, 0.75, 0)
                    maxB.Position = UDim2.new(0.79, 0, 0.5, 0)
                    maxB.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(maxB, THEME.BTN_MIN, THEME.BTN_MAX)
                end
            end
            local winSec = bar:FindFirstChild('WinSection')
            if winSec then
                winSec.Size = UDim2.new(0.24, 0, 0.85, 0)
                winSec.Position = UDim2.new(0.98, 0, 0.5, 0)
                winSec.AnchorPoint = Vector2.new(1, 0.5)
                local res2 = winSec:FindFirstChild('ResultBg')
                if res2 then
                    res2.Size = UDim2.fromScale(1, 1)
                    res2.Position = UDim2.fromScale(0.5, 0.5)
                    res2.AnchorPoint = Vector2.new(0.5, 0.5)
                    local amt = res2:FindFirstChild('ResultAmountLabel')
                    local sym = res2:FindFirstChild('ResultSymLabel')
                    layoutResultLabels(amt, sym)
                    styleResultBox(res2, { amt, sym })
                end
            end
            local spin2 = bar:FindFirstChild('SpinBtn')
            if spin2 then
                spin2.Size = UDim2.new(0.22, 0, 0.85, 0)
                spin2.Position = UDim2.new(0.55, 0, 0.5, 0)
                spin2.AnchorPoint = Vector2.new(0.5, 0.5)
                fitText(spin2, 22, 44)
            end
        end
    end

    do
        ensureGameTitle(slots3Page, "Plinko")
        local board = slots3Page:FindFirstChild('BoardFrame')
        if board then
            board.Position = UDim2.new(0.5, 0, PLAY_TOP, 0)
            board.Size = UDim2.new(1 - PAD * 2, 0, PLAY_H, 0)
            board.AnchorPoint = Vector2.new(0.5, 0)
            board.ClipsDescendants = true
            local mult = board:FindFirstChild('MultBar')
            if mult then
                mult.AnchorPoint = Vector2.new(0, 1)
                mult.Position = UDim2.new(0, 10, 1, -10)
                mult.Size = UDim2.new(1, -20, 0.12, 0)
            end
            local pin = board:FindFirstChild('PinCanvas')
            if pin then
                pin.Position = UDim2.new(0, 10, 0, 10)
                pin.Size = UDim2.new(1, -20, 0.85, 0)
            end
        end
        local left = slots3Page:FindFirstChild('LeftPanel')
        if left then
            left.Position = UDim2.new(0.5, 0, CTRL_TOP, 0)
            left.Size = UDim2.new(1 - PAD * 2, 0, CTRL_H, 0)
            left.AnchorPoint = Vector2.new(0.5, 0)
            local bet = left:FindFirstChild('BetBox')
            if bet then
                bet.Position = UDim2.new(0.02, 0, 0.5, 0)
                bet.Size = UDim2.new(0.74, 0, 0.9, 0)
                bet.AnchorPoint = Vector2.new(0, 0.5)
                for _, row in ipairs(bet:GetChildren()) do
                    if row.Name == 'BallPriceRow' or row.Name == 'NumBallsRow' then
                        row.Size = UDim2.new(0.28, 0, 0.9, 0)
                        row.AnchorPoint = Vector2.new(0, 0)
                        row.Position = row.Name == 'BallPriceRow' and UDim2.new(0.02, 0, 0.05, 0) or UDim2.new(0.32, 0, 0.05, 0)
                        local lbl = row:FindFirstChild('Label', true)
                        if lbl and lbl:IsA('TextLabel') then
                            lbl.Size = UDim2.new(1, 0, 0.38, 0)
                            lbl.Position = UDim2.new(0.5, 0, 0, 0)
                            lbl.AnchorPoint = Vector2.new(0.5, 0)
                            fitText(lbl, THEME.TEXT_MIN, THEME.TEXT_MAX)
                        end
                        local controls = row:FindFirstChild('Controls')
                        local val = controls and controls:FindFirstChild('ValueLbl')
                        if controls then
                            controls.Size = UDim2.new(1, 0, 0.52, 0)
                            controls.Position = UDim2.new(0.5, 0, 1, 0)
                            controls.AnchorPoint = Vector2.new(0.5, 1)
                            for _, btn in ipairs(controls:GetChildren()) do
                                if btn:IsA('TextButton') then
                                    btn.Size = UDim2.new(0.24, 0, 1, 0)
                                    btn.AnchorPoint = Vector2.new(0, 0.5)
                                    btn.Position = btn.Name == 'MinusBtn' and UDim2.new(0, 0, 0.5, 0) or UDim2.new(0.76, 0, 0.5, 0)
                                    fitText(btn, THEME.BTN_MIN, THEME.BTN_MAX)
                                end
                            end
                            if val then
                                val.Size = UDim2.new(0.48, 0, 1, 0)
                                val.Position = UDim2.new(0.5, 0, 0.5, 0)
                                val.AnchorPoint = Vector2.new(0.5, 0.5)
                                fitText(val, THEME.TEXT_MIN, THEME.TEXT_MAX)
                            end
                        end
                    end
                end
                local betBtn = bet:FindFirstChild('BetBtn')
                if betBtn then
                    betBtn.AnchorPoint = Vector2.new(1, 0.5)
                    betBtn.Position = UDim2.new(0.97, 0, 0.5, 0)
                    betBtn.Size = UDim2.new(0.18, 0, 0.78, 0)
                    fitText(betBtn, 22, 44)
                end
                local separator = bet:FindFirstChild('Separator')
                if separator and separator:IsA('GuiObject') then
                    separator.Visible = false
                end
                local totalRow = bet:FindFirstChild('TotalBetRow')
                if totalRow and totalRow:IsA('GuiObject') then
                    totalRow.Position = UDim2.new(0.61, 0, 0.08, 0)
                    totalRow.Size = UDim2.new(0.16, 0, 0.32, 0)
                    totalRow.AnchorPoint = Vector2.new(0, 0)
                    local label = totalRow:FindFirstChild('Label')
                    if label and label:IsA('TextLabel') then
                        label.Size = UDim2.fromScale(1, 1)
                        label.Position = UDim2.fromScale(0.5, 0.5)
                        label.AnchorPoint = Vector2.new(0.5, 0.5)
                        fitText(label, THEME.TEXT_MIN, THEME.TEXT_MAX)
                    end
                end
                local totalLbl = bet:FindFirstChild('TotalLbl', true)
                if totalLbl then
                    local totalBox = totalLbl.Parent
                    if totalBox and totalBox:IsA('GuiObject') then
                        totalBox.Position = UDim2.new(0.61, 0, 0.94, 0)
                        totalBox.Size = UDim2.new(0.16, 0, 0.48, 0)
                        totalBox.AnchorPoint = Vector2.new(0, 1)
                    end
                    fitText(totalLbl, THEME.TEXT_MIN, THEME.TEXT_MAX)
                end
            end
            local win = left:FindFirstChild('WinDisplay')
            if win then
                win.Position = UDim2.new(0.98, 0, 0.5, 0)
                win.Size = UDim2.new(0.2, 0, 0.9, 0)
                win.AnchorPoint = Vector2.new(1, 0.5)
                local n = win:FindFirstChild('NetLabel')
                local m = win:FindFirstChild('MultsLabel')
                layoutResultLabels(n, m)
                styleResultBox(win, { n, m })
            end
        end
    end

    do
        ensureGameTitle(wheelPage, "Lucky Wheel")
        local side = PLAY_H * 0.78
        local stage = wheelPage:FindFirstChild("WheelStage")
        local stageBottom = PLAY_TOP + PLAY_H * 0.48 + side * 0.5
        if stage and stage:IsA("GuiObject") then
            stage.AnchorPoint = Vector2.new(0.5, 0.5)
            stage.Position = UDim2.new(0.5, 0, PLAY_TOP + PLAY_H * 0.48, 0)
            stage.Size = UDim2.new(side / CARD_ASPECT, 0, side, 0)
            stage.ClipsDescendants = true
            local ar = stage:FindFirstChild("SquareLock")
            if not ar then
                ar = Instance.new("UIAspectRatioConstraint")
                ar.Name = "SquareLock"
                ar.Parent = stage
            end
            ar.AspectRatio = 1
            ar.DominantAxis = Enum.DominantAxis.Height
        end
        local pointer = wheelPage:FindFirstChild("Pointer")
        if pointer and pointer:IsA("GuiObject") then
            pointer.AnchorPoint = Vector2.new(0.5, 1)
            pointer.Position = UDim2.new(0.5, 0, PLAY_TOP + PLAY_H * 0.48 - side * 0.48, 0)
            pointer.Size = UDim2.new(0.045, 0, 0.07, 0)
            pointer.ZIndex = 40
        end
        local wheelBase = wheelPage:FindFirstChild("WheelBase")
        if wheelBase and wheelBase:IsA("GuiObject") then
            wheelBase.AnchorPoint = Vector2.new(0.5, 0)
            wheelBase.Position = UDim2.new(0.5, 0, stageBottom - side * 0.02, 0)
            wheelBase.Size = UDim2.new(side * 0.55 / CARD_ASPECT, 0, side * 0.22, 0)
            wheelBase.ZIndex = 9
            local neck = wheelBase:FindFirstChild("Neck")
            local plate = wheelBase:FindFirstChild("Plate")
            if neck and neck:IsA("GuiObject") then
                neck.Size = UDim2.new(0.42, 0, 0.55, 0)
                neck.Position = UDim2.new(0.5, 0, 0, 0)
                neck.AnchorPoint = Vector2.new(0.5, 0)
            end
            if plate and plate:IsA("GuiObject") then
                plate.Size = UDim2.new(1, 0, 0.28, 0)
                plate.Position = UDim2.new(0.5, 0, 1, 0)
                plate.AnchorPoint = Vector2.new(0.5, 1)
            end
        end
        local ctrlY = CTRL_TOP + CTRL_H * 0.5
        local bet = wheelPage:FindFirstChild("BetRow")
        if bet and bet:IsA("GuiObject") then
            bet.Size = UDim2.new(0.32, 0, CTRL_H * 0.85, 0)
            bet.Position = UDim2.new(PAD, 0, ctrlY, 0)
            bet.AnchorPoint = Vector2.new(0, 0.5)
            bet.ZIndex = 30
            local minus = bet:FindFirstChild("MinusBtn")
            local input = bet:FindFirstChild("BetInput")
            local plus = bet:FindFirstChild("PlusBtn")
            local maxB = bet:FindFirstChild("MaxBtn")
            if minus then
                minus.Size = UDim2.new(0.18, 0, 0.85, 0)
                minus.Position = UDim2.new(0, 0, 0.5, 0)
                minus.AnchorPoint = Vector2.new(0, 0.5)
                fitText(minus, THEME.BTN_MIN, THEME.BTN_MAX)
            end
            if input then
                input.Size = UDim2.new(0.34, 0, 0.85, 0)
                input.Position = UDim2.new(0.2, 0, 0.5, 0)
                input.AnchorPoint = Vector2.new(0, 0.5)
                fitText(input, THEME.TEXT_MIN, THEME.TEXT_MAX)
            end
            if plus then
                plus.Size = UDim2.new(0.18, 0, 0.85, 0)
                plus.Position = UDim2.new(0.56, 0, 0.5, 0)
                plus.AnchorPoint = Vector2.new(0, 0.5)
                fitText(plus, THEME.BTN_MIN, THEME.BTN_MAX)
            end
            if maxB then
                maxB.Size = UDim2.new(0.24, 0, 0.85, 0)
                maxB.Position = UDim2.new(0.76, 0, 0.5, 0)
                maxB.AnchorPoint = Vector2.new(0, 0.5)
                fitText(maxB, THEME.BTN_MIN, THEME.BTN_MAX)
            end
        end
        local risk = wheelPage:FindFirstChild("RiskBtn")
        if risk and risk:IsA("GuiObject") then
            risk.Size = UDim2.new(0.13, 0, CTRL_H * 0.85, 0)
            risk.Position = UDim2.new(0.42, 0, ctrlY, 0)
            risk.AnchorPoint = Vector2.new(0, 0.5)
            risk.ZIndex = 30
            fitText(risk, THEME.BTN_MIN, THEME.BTN_MAX)
        end
        local spin = wheelPage:FindFirstChild("SpinBtn")
        if spin and spin:IsA("GuiObject") then
            spin.Size = UDim2.new(0.15, 0, CTRL_H * 0.85, 0)
            spin.Position = UDim2.new(0.56, 0, ctrlY, 0)
            spin.AnchorPoint = Vector2.new(0, 0.5)
            spin.ZIndex = 30
            fitText(spin, 22, 44)
        end
        local result = wheelPage:FindFirstChild("ResultBg")
        if result and result:IsA("GuiObject") then
            result.Size = UDim2.new(0.22, 0, CTRL_H * 0.85, 0)
            result.Position = UDim2.new(1 - PAD, 0, ctrlY, 0)
            result.AnchorPoint = Vector2.new(1, 0.5)
            result.ZIndex = 30
            local oldSingle = result:FindFirstChild("ResultLbl")
            if oldSingle and not result:FindFirstChild("CoinsLbl") then
                oldSingle.Name = "CoinsLbl"
            end
            local coinLbl, multLbl = ensureResultLabels(result, "CoinsLbl", "MultLbl")
            styleResultBox(result, { coinLbl, multLbl })
        end
    end

    do
        ensureGameTitle(minesPage, "Diamond Mines")
        local grid = minesPage:FindFirstChild("GridFrame")
        if grid and grid:IsA("GuiObject") then
            grid.AnchorPoint = Vector2.new(0.5, 0)
            grid.Position = UDim2.new(0.5, 0, PLAY_TOP, 0)
            grid.Size = UDim2.new(1 - PAD * 2, 0, PLAY_H, 0)
            grid.ClipsDescendants = false
            local inner = grid:FindFirstChild("GridInner")
            if inner and inner:IsA("GuiObject") then
                inner.AnchorPoint = Vector2.new(0.5, 0.5)
                inner.Position = UDim2.fromScale(0.5, 0.5)
                inner.Size = UDim2.fromScale(0.9, 0.92)
            end
        end
        local left = minesPage:FindFirstChild("LeftPanel")
        if left and left:IsA("GuiObject") then
            left.Position = UDim2.new(0.5, 0, CTRL_TOP, 0)
            left.Size = UDim2.new(1 - PAD * 2, 0, CTRL_H, 0)
            left.AnchorPoint = Vector2.new(0.5, 0)
            left.BackgroundTransparency = 1
            left.ZIndex = 30
            local sizeRow = left:FindFirstChild("SizeRow")
            if sizeRow and sizeRow:IsA("GuiObject") then
                sizeRow.Size = UDim2.new(0.20, 0, 0.85, 0)
                sizeRow.Position = UDim2.new(0.00, 0, 0.5, 0)
                sizeRow.AnchorPoint = Vector2.new(0, 0.5)
                for _, btn in ipairs(sizeRow:GetChildren()) do
                    if btn:IsA("TextButton") then
                        local idx = if btn.Name == "Size3" then 0 elseif btn.Name == "Size4" then 1 else 2
                        btn.Size = UDim2.new(0.3, 0, 1, 0)
                        btn.Position = UDim2.new(idx * 0.35, 0, 0.5, 0)
                        btn.AnchorPoint = Vector2.new(0, 0.5)
                        fitText(btn, THEME.BTN_MIN, THEME.BTN_MAX)
                    end
                end
            end
            local bet = left:FindFirstChild("BetRow")
            if bet and bet:IsA("GuiObject") then
                bet.Size = UDim2.new(0.24, 0, 0.85, 0)
                bet.Position = UDim2.new(0.22, 0, 0.5, 0)
                bet.AnchorPoint = Vector2.new(0, 0.5)
                local minus = bet:FindFirstChild("MinusBtn")
                local input = bet:FindFirstChild("BetInput")
                local plus = bet:FindFirstChild("PlusBtn")
                if minus then
                    minus.Size = UDim2.new(0.22, 0, 0.85, 0)
                    minus.Position = UDim2.new(0, 0, 0.5, 0)
                    minus.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(minus, THEME.BTN_MIN, THEME.BTN_MAX)
                end
                if input then
                    input.Size = UDim2.new(0.5, 0, 0.85, 0)
                    input.Position = UDim2.new(0.25, 0, 0.5, 0)
                    input.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(input, THEME.TEXT_MIN, THEME.TEXT_MAX)
                end
                if plus then
                    plus.Size = UDim2.new(0.22, 0, 0.85, 0)
                    plus.Position = UDim2.new(0.78, 0, 0.5, 0)
                    plus.AnchorPoint = Vector2.new(0, 0.5)
                    fitText(plus, THEME.BTN_MIN, THEME.BTN_MAX)
                end
            end
			local startBtn = left:FindFirstChild("StartBtn")
			if startBtn and startBtn:IsA("GuiObject") then
				startBtn.Size = UDim2.new(0.18, 0, 0.85, 0)
				startBtn.Position = UDim2.new(0.48, 0, 0.5, 0)
				startBtn.AnchorPoint = Vector2.new(0, 0.5)
				fitText(startBtn, 18, 36)
			end
			local staleCollect = left:FindFirstChild("CollectBtn")
			if staleCollect then
				staleCollect:Destroy()
			end
			local win = left:FindFirstChild("WinDisplay")
			if not win then
				win = Instance.new("Frame")
				win.Name = "WinDisplay"
				win.Visible = false
				win.Parent = left
			end
			if win and win:IsA("GuiObject") then
				win.Size = UDim2.new(0.28, 0, 0.85, 0)
				win.Position = UDim2.new(1, 0, 0.5, 0)
				win.AnchorPoint = Vector2.new(1, 0.5)
				win.ZIndex = 31
				local coinsLbl = win:FindFirstChild("MultLbl") or left:FindFirstChild("MultLbl")
				local multLbl = win:FindFirstChild("InfoLbl") or left:FindFirstChild("InfoLbl")
				if coinsLbl and coinsLbl:IsA("GuiObject") then
					coinsLbl.Parent = win
				end
				if multLbl and multLbl:IsA("GuiObject") then
					multLbl.Parent = win
				end
				layoutResultLabels(coinsLbl, multLbl)
				styleResultBox(win, { coinsLbl, multLbl })
			end
		end
	end

	coinBadge.AnchorPoint = Vector2.new(1, 0)
    coinBadge.Position = UDim2.new(1, -math.floor(14 * scale), 0, math.floor(12 * scale))
    coinBadge.Size = UDim2.new(0, math.floor(BADGE_SIZE.X.Offset * math.max(scale, 0.8)), 0, math.floor(BADGE_SIZE.Y.Offset * math.max(scale, 0.8)))
    if innerCoinLbl then
        fitText(innerCoinLbl, THEME.TEXT_MIN, THEME.TEXT_MAX)
        innerCoinLbl.Visible = coinBadge.Visible
    end

    if slots3Page.Visible and plinkoLayoutHook then
        task.defer(plinkoLayoutHook)
    end

    applyQueueTheme()
end

task.spawn(function()
    local cam = Workspace:WaitForChild('Camera', 10) or Workspace.CurrentCamera
    camera = Workspace.CurrentCamera
    applyResponsiveLayout()
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(applyResponsiveLayout)
    end
    Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(applyResponsiveLayout)
            applyResponsiveLayout()
        end
    end)
end)

-- ── Open / Close (card-level fade only — never touch child transparencies) ──
local animToken = 0
local OVERLAY_OPEN_T = THEME.OVERLAY_T or 0.32

local function syncCardShadow(visible: boolean?)
    local shadow = CasinoUiTheme.ensureCardShadow(card)
    if visible ~= nil then
        shadow.Visible = visible
    end
    shadow.Size = UDim2.new(card.Size.X.Scale, card.Size.X.Offset + 10, card.Size.Y.Scale, card.Size.Y.Offset + 12)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(
        card.Position.X.Scale,
        card.Position.X.Offset,
        card.Position.Y.Scale,
        card.Position.Y.Offset + 14
    )
    return shadow
end

do
    local leftover = card:FindFirstChild("FadeGroup")
    if leftover then
        if pages.Parent == leftover then
            pages.Parent = card
        end
        leftover:Destroy()
    end
    local extraScale = card:FindFirstChild("OpenScale")
    if extraScale then
        extraScale:Destroy()
    end
end

local function Animate(show)
    animToken += 1
    local token = animToken
    local DUR_IN = 0.42
    local DUR_OUT = 0.46
    local POS_SHOW = CARD_POS_SHOW
    local POS_HIDE = CARD_POS_HIDE
    local TI_RISE = TweenInfo.new(DUR_IN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local TI_DROP = TweenInfo.new(DUR_OUT, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    local TI_FADE_IN = TweenInfo.new(DUR_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local TI_FADE_OUT = TweenInfo.new(DUR_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local cardStroke = card:FindFirstChild("CardGlow") or card:FindFirstChildOfClass("UIStroke")
    local shadow = syncCardShadow(false)

    if show then
        applyResponsiveLayout()
        card.Visible = true
        card.Position = POS_HIDE
        card.BackgroundTransparency = 0
        overlay.BackgroundTransparency = OVERLAY_OPEN_T
        overlay.ZIndex = 0
        card.ZIndex = 10
        if cardStroke then
            cardStroke.Transparency = 1
        end
        coinBadge.BackgroundTransparency = 1
        if innerCoinLbl then
            innerCoinLbl.TextTransparency = 1
        end
        sg.Enabled = true
        overlay.Active = true
        overlay.Visible = true
        setShopCoinVisible(true)
        shadow.Visible = true
        shadow.BackgroundTransparency = 1
        shadow.Position = UDim2.new(POS_HIDE.X.Scale, 0, POS_HIDE.Y.Scale, 14)

        TweenSvc:Create(card, TI_RISE, { Position = POS_SHOW }):Play()
        if cardStroke then
            TweenSvc:Create(cardStroke, TI_FADE_IN, { Transparency = 0 }):Play()
        end
        TweenSvc:Create(coinBadge, TI_FADE_IN, { BackgroundTransparency = 0 }):Play()
        if innerCoinLbl then
            TweenSvc:Create(innerCoinLbl, TI_FADE_IN, { TextTransparency = 0 }):Play()
        end
        TweenSvc:Create(shadow, TI_RISE, {
            Position = UDim2.new(POS_SHOW.X.Scale, 0, POS_SHOW.Y.Scale, 14),
            BackgroundTransparency = 0.5,
        }):Play()
    else
        TweenSvc:Create(card, TI_DROP, { Position = POS_HIDE }):Play()
        task.delay(0.08, function()
            if token == animToken then
                TweenSvc:Create(overlay, TI_FADE_OUT, { BackgroundTransparency = 1 }):Play()
            end
        end)
        if cardStroke then
            TweenSvc:Create(cardStroke, TI_FADE_OUT, { Transparency = 1 }):Play()
        end
        TweenSvc:Create(coinBadge, TI_FADE_OUT, { BackgroundTransparency = 1 }):Play()
        if innerCoinLbl then
            TweenSvc:Create(innerCoinLbl, TI_FADE_OUT, { TextTransparency = 1 }):Play()
        end
        TweenSvc:Create(shadow, TI_DROP, {
            Position = UDim2.new(POS_HIDE.X.Scale, 0, POS_HIDE.Y.Scale, 14),
            BackgroundTransparency = 1,
        }):Play()

        task.delay(DUR_OUT + 0.03, function()
            if token ~= animToken then
                return
            end
            forceCloseGui()
            setShopCoinVisible(false)
            overlay.BackgroundTransparency = 1
            if innerCoinLbl then
                innerCoinLbl.TextTransparency = 0
            end
            coinBadge.BackgroundTransparency = 0
            shadow.Visible = false
        end)
    end
end

local function anyGameBusy()
    return isSpinning or isSpinning2 or isP3 or isWheelSpinning or isMinesBusy or minesRoundActive
end

local function CloseUI()
    -- Main CloseBtn only; blocked while any casino game is spinning
    if anyGameBusy() then return end
    if not menuOpen and not sg.Enabled then return end
    menuOpen=false; player:SetAttribute("UIOpen",false)
    Animate(false)
end
local function OpenUI(pageName)
    pageName = pageName or "tiles"
    if menuOpen and sg.Enabled then
        showPage(pageName)
        applyResponsiveLayout()
        task.spawn(refreshCoinsFromServer)
        return
    end
    menuOpen=true; player:SetAttribute("UIOpen",true)
    showPage(pageName); applyResponsiveLayout(); Animate(true)
    task.spawn(refreshCoinsFromServer)
end

requestOpenUI.Event:Connect(function(pageName)
	OpenUI(pageName)
end)

closeBtn.MouseButton1Click:Connect(CloseUI)

-- ── Alive idle motion (glow pulse, tile breath, divider) ──
do
    local glow = card:FindFirstChild("CardGlow") or card:FindFirstChildOfClass("UIStroke")
    local divider = tilesPage:FindFirstChild("Divider")
    local tiles = {}
    local tileRow = tilesPage:FindFirstChild("TileRow")
    if tileRow then
        for _, tile in ipairs(tileRow:GetChildren()) do
            if tile:IsA("TextButton") then
                local hoverScale = tile:FindFirstChild("HoverScale")
                if not hoverScale then
                    hoverScale = Instance.new("UIScale")
                    hoverScale.Name = "HoverScale"
                    hoverScale.Scale = 1
                    hoverScale.Parent = tile
                end
                table.insert(tiles, { tile = tile, scale = hoverScale })
                tile.MouseEnter:Connect(function()
                    TweenSvc:Create(hoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
                end)
                tile.MouseLeave:Connect(function()
                    TweenSvc:Create(hoverScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
                end)
            end
        end
    end

    local primaryBtns = {}
    for _, btn in ipairs({
        slotsPage:FindFirstChild("SpinBtn"),
        slots2Page:FindFirstChild("BottomBar") and slots2Page.BottomBar:FindFirstChild("SpinBtn"),
        slots3Page:FindFirstChild("LeftPanel")
            and slots3Page.LeftPanel:FindFirstChild("BetBox")
            and slots3Page.LeftPanel.BetBox:FindFirstChild("BetBtn"),
        wheelPage:FindFirstChild("SpinBtn"),
        minesPage:FindFirstChild("LeftPanel") and minesPage.LeftPanel:FindFirstChild("StartBtn"),
    }) do
        if btn and btn:IsA("GuiButton") then
            if btn:IsA("TextButton") then
                btn.TextScaled = true
                btn.TextSize = 32
                fitText(btn, 24, 48)
            end
            table.insert(primaryBtns, btn)
        end
    end

    local idleGradients = {}
    for _, gui in ipairs({ card, tilesPage, slotsPage, slots2Page, slots3Page, wheelPage, minesPage }) do
        local grad = gui and gui:FindFirstChildOfClass("UIGradient")
        if grad then
            table.insert(idleGradients, { gradient = grad, base = grad.Rotation })
        end
    end

    local gamePanels = {
        slotsPage:FindFirstChild("StripOuter"),
        slots2Page:FindFirstChild("ReelFrame"),
        slots3Page:FindFirstChild("BoardFrame"),
        wheelPage:FindFirstChild("WheelStage"),
        minesPage:FindFirstChild("GridFrame"),
    }

    local t0 = tick()
    RunSvc.RenderStepped:Connect(function()
        if not menuOpen or not sg.Enabled then return end
        local t = tick() - t0
        if glow and glow:IsA("UIStroke") and glow.Transparency < 0.9 then
            glow.Thickness = 2 + math.sin(t * 2.2) * 0.55
            glow.Color = Color3.fromRGB(
                70 + math.floor(math.sin(t * 1.4) * 20),
                190 + math.floor(math.sin(t * 1.7) * 30),
                255
            )
        end
        if divider and divider:IsA("GuiObject") and tilesPage.Visible then
            divider.BackgroundTransparency = 0.12 + (math.sin(t * 2.6) * 0.5 + 0.5) * 0.25
            divider.Size = UDim2.new(0.55 + math.sin(t * 1.8) * 0.04, 0, 0, 2)
        end
        for i, entry in ipairs(idleGradients) do
            if entry.gradient.Parent then
                entry.gradient.Rotation = entry.base + math.sin(t * 0.45 + i) * 5
            end
        end
        for _, entry in ipairs(movingBgOrbs) do
            if entry.orb.Parent then
                entry.orb.Position = UDim2.fromScale(
                    entry.x + math.sin(t * 0.28 + entry.phase) * 0.08,
                    entry.y + math.cos(t * 0.22 + entry.phase) * 0.06
                )
                entry.orb.BackgroundTransparency = 0.84 + (math.sin(t * 0.7 + entry.phase) * 0.5 + 0.5) * 0.08
            end
        end
        for i, panel in ipairs(gamePanels) do
            if panel and panel:IsA("GuiObject") and panel.Visible then
                local stroke = panel:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Thickness = 1.6 + (math.sin(t * 1.9 + i) * 0.5 + 0.5) * 1.1
                    stroke.Transparency = 0.08 + (math.sin(t * 1.3 + i) * 0.5 + 0.5) * 0.18
                end
            end
        end
        if tilesPage.Visible and not anyGameBusy() then
            for i, entry in ipairs(tiles) do
                if entry.tile.Parent and entry.scale.Scale < 1.04 then
                    entry.scale.Scale = 1 + math.sin(t * 1.5 + i * 1.2) * 0.012
                end
            end
        end
        if not anyGameBusy() then
            for _, btn in ipairs(primaryBtns) do
                if btn.Parent and btn.Visible then
                    if btn:IsA("TextButton") then
                        btn.TextScaled = true
                        btn.TextSize = 32
                    end
                    local us = btn:FindFirstChild("IdlePulse")
                    if not us then
                        us = Instance.new("UIScale")
                        us.Name = "IdlePulse"
                        us.Parent = btn
                    end
                    us.Scale = 0.98 + (math.sin(t * 3.0) * 0.5 + 0.5) * 0.04
                end
            end
        end
    end)
end

-- External page request: only switch page if already open (never auto-open on join)
task.spawn(function()
    local reqShow = Signals:WaitForChild("RequestShowPage", 10)
    if reqShow then
        reqShow.Event:Connect(function(pageName)
            if sg.Enabled and menuOpen then
                showPage(pageName or "slots1")
            end
        end)
    end
end)

-- ── RARITIES ─────────────────────────────────────────────
local RARITIES={
    Common={color=Color3.fromRGB(150,155,165),factor=0.095},
    Uncommon={color=Color3.fromRGB(70,190,80),factor=0.284},
    Epic={color=Color3.fromRGB(75,150,255),factor=0.682},
    Mythic={color=Color3.fromRGB(170,45,255),factor=1.412},
    Legendary={color=Color3.fromRGB(255,185,20),factor=5.875},
}
local RARITY_ORDER={'Common','Uncommon','Epic','Mythic','Legendary'}
local RARITY_WEIGHTS={55,25,12,6,2}
local function pickRarityName()
    local r=math.random(1,100);local cum=0
    for i,n in ipairs(RARITY_ORDER) do cum=cum+RARITY_WEIGHTS[i];if r<=cum then return n end end
    return 'Common'
end
local function getRar(n) return RARITIES[n] or RARITIES.Common end

-- ── VFX helpers ───────────────────────────────────────────
local function spawnParticle(col,startPos,canvas)
    local p=Instance.new("Frame");p.Size=UDim2.new(0,8,0,8)
    p.Position=startPos;p.AnchorPoint=Vector2.new(0.5,0.5)
    p.BackgroundColor3=col;p.BorderSizePixel=0;p.ZIndex=18;p.Parent=canvas
    local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,99);c.Parent=p
    local vx=(math.random()-0.5)*0.6;local vy=-math.random()*0.5-0.2
    local life=0;local conn
    conn=RunSvc.RenderStepped:Connect(function(dt)
        life=life+dt;vy=vy+0.6*dt
        local nx=p.Position.X.Scale+vx*dt;local ny=p.Position.Y.Scale+vy*dt
        p.Position=UDim2.new(nx,0,ny,0)
        p.BackgroundTransparency=math.min(1,life/0.8)
        if life>0.8 then conn:Disconnect();p:Destroy() end
    end)
end
local function burstParticles(col,count,canvas)
    for _=1,count do task.delay(math.random()*0.15,function()
        local sx=0.3+math.random()*0.4;local sy=0.3+math.random()*0.4
        spawnParticle(col,UDim2.new(sx,0,sy,0),canvas)
    end) end
end
local function flashSheen(col,intensity)
    sheen.BackgroundColor3=col or Color3.new(1,1,1)
    TweenSvc:Create(sheen,TweenInfo.new(0.08),{BackgroundTransparency=1-intensity}):Play()
    task.delay(0.08,function() TweenSvc:Create(sheen,TweenInfo.new(0.35),{BackgroundTransparency=1}):Play() end)
end

-- ── Hover helper ─────────────────────────────────────────
local function bindCoolHover(gui, enterScale)
    if not gui or not gui:IsA('GuiObject') then return end
    local scale = gui:FindFirstChild('HoverScale')
    if not scale then
        scale = Instance.new('UIScale')
        scale.Name = 'HoverScale'
        scale.Parent = gui
    end
    local up = enterScale or 1.06
    local stroke = gui:FindFirstChild('NeonStroke') or gui:FindFirstChildOfClass('UIStroke')
    local baseThickness = stroke and stroke.Thickness or nil
    local baseTransparency = stroke and stroke.Transparency or nil
    gui.MouseEnter:Connect(function()
        TweenSvc:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = up}):Play()
        if stroke and baseThickness then
            TweenSvc:Create(stroke, TweenInfo.new(0.14), {
                Thickness = baseThickness + 1.2,
                Transparency = math.max(0, (baseTransparency or 0.3) - 0.15),
            }):Play()
        end
    end)
    gui.MouseLeave:Connect(function()
        TweenSvc:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        if stroke and baseThickness then
            TweenSvc:Create(stroke, TweenInfo.new(0.16), {
                Thickness = baseThickness,
                Transparency = baseTransparency or stroke.Transparency,
            }):Play()
        end
    end)
    if gui:IsA('GuiButton') then
        gui.MouseButton1Down:Connect(function()
            TweenSvc:Create(scale, TweenInfo.new(0.08), {Scale = 0.94}):Play()
        end)
        gui.MouseButton1Up:Connect(function()
            TweenSvc:Create(scale, TweenInfo.new(0.1), {Scale = up}):Play()
        end)
    end
end

-- ── Tile buttons in TilesPage ─────────────────────────────
local tileRow=tilesPage:WaitForChild("TileRow")
for _,tile in ipairs(tileRow:GetChildren()) do
    if tile:IsA("TextButton") then
        bindCoolHover(tile, 1.05)
        local pageMap={Slots1Tile='slots1',Slots2Tile='slots2',Slots3Tile='slots3',WheelTile='wheel',MinesTile='mines'}
        local pg=pageMap[tile.Name]
        if pg then
            tile.MouseButton1Click:Connect(function()
                showPage(pg)
                applyResponsiveLayout()
            end)
        end
    end
end

local function initSlots1()
-- ════════════════════════════════════════════
-- SLOTS 1 PAGE
-- ════════════════════════════════════════════
local stripOuter= slotsPage:WaitForChild("StripOuter")
local stripClip = stripOuter:WaitForChild("StripClip")
stripClip.ClipsDescendants = true
local strip     = stripClip:WaitForChild("Strip")
local stripGlow = stripOuter:FindFirstChild("StripGlow") or stripOuter:FindFirstChildOfClass("UIStroke")
local betRow    = slotsPage:WaitForChild("BetRow")
local minusBtn  = betRow:WaitForChild("MinusBtn")
local plusBtn   = betRow:WaitForChild("PlusBtn")
local betBox    = betRow:WaitForChild("BetInput")
local maxBtn    = betRow:WaitForChild("MaxBtn")
local spinBtn   = slotsPage:WaitForChild("SpinBtn")
local resultBg  = slotsPage:WaitForChild("ResultBg")
local resultNeon= resultBg:FindFirstChildOfClass("UIStroke")
do
	local old = resultBg:FindFirstChild("ResultLbl")
	if old and not resultBg:FindFirstChild("CoinsLbl") then
		old.Name = "CoinsLbl"
	end
end
local resultCoins, resultMult = ensureResultLabels(resultBg, "CoinsLbl", "MultLbl")
resultBg.Visible = false
styleResultBox(resultBg, { resultCoins, resultMult })

bindCoolHover(spinBtn, 1.05)
bindCoolHover(minusBtn, 1.08)
bindCoolHover(plusBtn, 1.08)
bindCoolHover(maxBtn, 1.06)
bindCoolHover(closeBtn, 1.08)

local ITEM_W=160;local NUM_ITEMS=60;local RES_IDX=50
local function getItemW()
    local w = select(1, getLocalSize(stripClip))
    if w < 80 then return ITEM_W end
    return math.clamp(math.floor(w / 5.5), 100, 180)
end
local spinSlots=Remotes:WaitForChild('SpinSlots')
local slotResult=Remotes:WaitForChild('SlotResult')
local confirmSpin=Remotes:WaitForChild('ConfirmSpin')

local stripFrames={}
local function makeItem(idx,rarName)
    local itemW = getItemW()
    local rar=getRar(rarName);local col=rar.color
    local f=Instance.new("Frame");f.Size=UDim2.new(0,itemW-6,1,-8)
    f.Position=UDim2.new(0,(idx-1)*itemW+3,0,4);f.BackgroundColor3=Color3.fromRGB(12,3,36)
    f.BorderSizePixel=0;f.Parent=strip
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=f
    local bar=Instance.new("Frame");bar.Size=UDim2.new(1,0,0,5);bar.Position=UDim2.new(0,0,1,-5)
    bar.BackgroundColor3=col;bar.BorderSizePixel=0;bar.Parent=f
    local bc=Instance.new("UICorner");bc.CornerRadius=UDim.new(0,3);bc.Parent=bar
    local nl=Instance.new("TextLabel");nl.Size=UDim2.new(1,-4,0,28);nl.Position=UDim2.new(0,2,0.5,-14)
    nl.BackgroundTransparency=1;nl.Text=rarName;nl.TextSize=16;nl.Font=Enum.Font.GothamBold
    nl.TextColor3=col;nl.TextXAlignment=Enum.TextXAlignment.Center;nl.TextWrapped=true;nl.Parent=f
    return f
end
local function buildStrip(resultRarName)
    for _,c in ipairs(strip:GetChildren()) do c:Destroy() end; stripFrames={}
    for i=1,NUM_ITEMS do
        table.insert(stripFrames,makeItem(i,(i==RES_IDX) and resultRarName or pickRarityName()))
    end; strip.Position=UDim2.new(0,0,0,0)
end
buildStrip("Common")

local function getBet() return math.max(10,math.min(tonumber(betBox.Text) or 100,10000)) end
local STEPS={10,50,100,500,1000,5000,10000}
minusBtn.MouseButton1Click:Connect(function() local b=getBet();local n=10;for i=#STEPS,1,-1 do if STEPS[i]<b then n=STEPS[i];break end end;betBox.Text=tostring(n) end)
plusBtn.MouseButton1Click:Connect(function() local b=getBet();local n=10000;for i=1,#STEPS do if STEPS[i]>b then n=STEPS[i];break end end;betBox.Text=tostring(n) end)
maxBtn.MouseButton1Click:Connect(function() betBox.Text=tostring(math.max(10,math.min(math.floor(cachedCoins),10000))) end)
betBox.FocusLost:Connect(function() local n=tonumber(betBox.Text);betBox.Text=tostring(n and math.max(10,math.min(math.floor(n),10000)) or 100) end)

local function pulseStripGlow(col)
    if not stripGlow then return end
    TweenSvc:Create(stripGlow,TweenInfo.new(0.12),{Color=col,Thickness=4}):Play()
    task.delay(0.15,function() TweenSvc:Create(stripGlow,TweenInfo.new(0.6),{Color=Color3.fromRGB(65,105,200),Thickness=1.5}):Play() end)
end
local function pulseWinner(frame,col,onDone)
    task.spawn(function()
        for _=1,4 do
            TweenSvc:Create(frame,TweenInfo.new(0.14,Enum.EasingStyle.Sine),{BackgroundColor3=col,BackgroundTransparency=0}):Play()
            task.wait(0.17)
            TweenSvc:Create(frame,TweenInfo.new(0.14,Enum.EasingStyle.Sine),{BackgroundColor3=Color3.fromRGB(12,3,36),BackgroundTransparency=0}):Play()
            task.wait(0.17)
        end
        TweenSvc:Create(frame,TweenInfo.new(0.18),{BackgroundColor3=col,BackgroundTransparency=0}):Play()
        local ws=Instance.new("UIStroke");ws.Color=Color3.new(1,1,1);ws.Thickness=2.5;ws.Parent=frame
        TweenSvc:Create(ws,TweenInfo.new(0.85,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=0.55}):Play()
        if onDone then onDone() end
    end)
end
local function animateSpin(rarName,betAmount,onDone)
    local itemW = getItemW()
    local visW = select(1, getLocalSize(stripClip))
    if visW <= 0 then visW = 700 end
    local TARGET_X = (visW / 2) - ((RES_IDX - 1) * itemW + itemW / 2)
    strip.Position = UDim2.new(0, 0, 0, 0)
    if stripGlow then TweenSvc:Create(stripGlow,TweenInfo.new(0.3),{Color=Color3.fromRGB(120,180,255),Thickness=3}):Play() end
    local tw=TweenSvc:Create(strip,TweenInfo.new(4.6,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),{Position=UDim2.new(0,TARGET_X,0,0)})
    tw:Play()
    tw.Completed:Connect(function()
        pulseStripGlow(Color3.fromRGB(255,255,255))
        local col=getRar(rarName).color
        local winFrame=stripFrames[RES_IDX]
        local snd=WIN_SOUNDS[rarName] or sndCommon; SoundController.playSfx(snd); fireSpinState("reward", snd)
        local burstCount={Common=6,Uncommon=10,Epic=18,Mythic=26,Legendary=50}
        burstParticles(col,burstCount[rarName] or 8,particleCanvas)
        if rarName=="Epic" or rarName=="Mythic" or rarName=="Legendary" then
            flashSheen(col,rarName=="Legendary" and 0.35 or rarName=="Mythic" and 0.22 or 0.12)
        end
        if winFrame then
            pulseWinner(winFrame,col,function()
                confirmSpin:FireServer()
                task.delay(0.5,function()
                    isSpinning=false
                    refreshCoinsFromServer()
                    local factor=getRar(rarName).factor; local won=math.floor(betAmount*factor)
                    resultBg.Visible=true
                    if resultNeon then
                        if won >= betAmount then
                            resultNeon.Color = THEME.RESULT_WIN_STROKE
                        else
                            resultNeon.Color = THEME.RESULT_LOSS_STROKE
                        end
                    end
                    setResultOutcome(resultBg, resultCoins, resultMult, won, factor, betAmount)
                    if onDone then onDone() end
                end)
            end)
        else confirmSpin:FireServer(); isSpinning=false; fireSpinState("cancel"); if onDone then onDone() end end
    end)
end

spinBtn.MouseButton1Click:Connect(function()
    if isSpinning then return end
    isSpinning=true; resultBg.Visible=false
    fireSpinState("start")
    spinBtn.Text="Spinning..."; spinBtn.BackgroundColor3=THEME.BUSY
    local bet=getBet()
    setAllCoins(math.max(0,cachedCoins-bet)); pulseCoinBadge()
    spinSlots:FireServer(bet)
end)
slotResult.OnClientEvent:Connect(function(success,resultRar,seq,betAmount,afterBet)
    if not success then
        isSpinning=false; spinBtn.Text="Spin"; stylePrimaryBtn(spinBtn)
        fireSpinState("cancel")
        resultBg.Visible=true
        setResultError(resultBg, resultCoins, resultMult, "Not enough Coins")
        if resultNeon then resultNeon.Color=THEME.RESULT_LOSS_STROKE end
        return
    end
    setAllCoins(afterBet)
    local rarName=type(resultRar)=="table" and resultRar.name or tostring(resultRar)
    buildStrip(rarName)
    animateSpin(rarName,betAmount,function() task.wait(1.5); spinBtn.Text="Spin"; stylePrimaryBtn(spinBtn) end)
end)

-- Spin btn pulse
task.spawn(function()
    while spinBtn.Parent do
        local sk=spinBtn:FindFirstChildOfClass('UIStroke');if not sk then task.wait(1);continue end
        TweenSvc:Create(sk,TweenInfo.new(1.0,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Thickness=5.5}):Play(); task.wait(1.05)
        TweenSvc:Create(sk,TweenInfo.new(1.0,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Thickness=2.5}):Play(); task.wait(1.05)
    end
end)

end
initSlots1()

local function initSlots2()
-- ════════════════════════════════════════════
-- SLOTS 2 PAGE (5-reel)
-- ════════════════════════════════════════════
local spinSlots2=Remotes:WaitForChild('SpinSlots2'); local slotResult2=Remotes:WaitForChild('SlotResult2')
local confirmSpin2=Remotes:WaitForChild('ConfirmSpin2')
local reelFrame=slots2Page:WaitForChild('ReelFrame'); local reelInner=reelFrame:WaitForChild('ReelInner')
local bottomBar=slots2Page:WaitForChild('BottomBar')
local betSec=bottomBar:WaitForChild('BetSection')
local minus2=betSec:WaitForChild('MinusBtn'); local plus2=betSec:WaitForChild('PlusBtn')
local betBox2=betSec:WaitForChild('BetInput'); local max2=betSec:WaitForChild('MaxBtn')
local spin2Btn=bottomBar:WaitForChild('SpinBtn')
bindCoolHover(spin2Btn, 1.05)
bindCoolHover(minus2, 1.08)
bindCoolHover(plus2, 1.08)
bindCoolHover(max2, 1.06)
local winSec=bottomBar:WaitForChild('WinSection')
local res2Bg=winSec:WaitForChild('ResultBg')
local res2Neon=res2Bg:FindFirstChildOfClass('UIStroke')
local res2Amount=res2Bg:WaitForChild('ResultAmountLabel'); local res2Sym=res2Bg:WaitForChild('ResultSymLabel')
res2Bg.Visible=false
winSec.Visible=false
styleResultBox(res2Bg, { res2Amount, res2Sym })

local function showSlots2Result(visible)
    winSec.Visible = visible
    res2Bg.Visible = visible
end


local SYMS2={{e='🍋',col=Color3.fromRGB(235,215,0)},{e='🍒',col=Color3.fromRGB(210,40,40)},
    {e='🔔',col=Color3.fromRGB(220,150,20)},{e='🍀',col=Color3.fromRGB(30,175,55)},
    {e='7️⃣',col=Color3.fromRGB(220,55,20)},{e='💎',col=Color3.fromRGB(50,195,255)}}
local OUTCOME_INFO={
    diamond_3={disp='💎 x3 DIAMOND',col=Color3.fromRGB(50,195,255)},diamond_4={disp='💎 x4 DIAMOND!',col=Color3.fromRGB(50,195,255)},diamond_5={disp='💎 x5 JACKPOT!!',col=Color3.fromRGB(50,195,255)},
    seven_3={disp='7️⃣ x3 SEVEN',col=Color3.fromRGB(255,80,40)},seven_4={disp='7️⃣ x4 SEVEN!',col=Color3.fromRGB(255,80,40)},seven_5={disp='7️⃣ x5 SEVEN!!',col=Color3.fromRGB(255,80,40)},
    bar_3={disp='🍀 x3 BAR',col=Color3.fromRGB(30,175,55)},bar_4={disp='🍀 x4 BAR!',col=Color3.fromRGB(30,175,55)},bar_5={disp='🍀 x5 BAR!!',col=Color3.fromRGB(30,175,55)},
    bell_3={disp='🔔 x3 BELL',col=Color3.fromRGB(220,150,20)},bell_4={disp='🔔 x4 BELL!',col=Color3.fromRGB(220,150,20)},bell_5={disp='🔔 x5 BELL!!',col=Color3.fromRGB(220,150,20)},
    cherry_3={disp='🍒 x3 CHERRY',col=Color3.fromRGB(210,40,40)},cherry_4={disp='🍒 x4 CHERRY!',col=Color3.fromRGB(210,40,40)},cherry_5={disp='🍒 x5 CHERRY!!',col=Color3.fromRGB(210,40,40)},
    lemon_3={disp='🍋 x3 LEMON',col=Color3.fromRGB(235,215,0)},lemon_4={disp='🍋 x4 LEMON!',col=Color3.fromRGB(235,215,0)},lemon_5={disp='🍋 x5 LEMON!!',col=Color3.fromRGB(235,215,0)},
    near={disp='Near Miss!',col=Color3.fromRGB(180,160,255)},mixed={disp='No Win',col=Color3.fromRGB(100,80,140)},loss={disp='No Win',col=Color3.fromRGB(100,80,140)},
}
local function symByEmoji(e) for _,s in ipairs(SYMS2) do if s.e==e then return s end end return SYMS2[1] end
local NREELS=5;local NROWS=3;local REEL_LEN=24;local RES_POS=18
local reelClips={};local tapes={};local resultCells={}
for ri=1,NREELS do
    local clip=reelInner:FindFirstChild('Reel'..ri)
    if clip then
        clip.ClipsDescendants = true
        reelClips[ri]=clip
        tapes[ri]=clip:FindFirstChild('Tape2')
    end
end
local function buildTape(ri,centerSym)
    local tape=tapes[ri];local clip=reelClips[ri];if not tape or not clip then return end
    local clipH=math.max(clip.AbsoluteSize.Y,240); local symH=math.floor(clipH/NROWS)
    tape.Size=UDim2.new(1,0,0,symH*REEL_LEN)
    for _,c in ipairs(tape:GetChildren()) do c:Destroy() end; resultCells[ri]=nil
    local centerSData=symByEmoji(centerSym)
    for i=0,REEL_LEN-1 do
        local sym=(i==RES_POS) and centerSData or SYMS2[math.random(1,#SYMS2)]
        local cell=Instance.new('Frame');cell.Size=UDim2.new(1,0,0,symH)
        cell.Position=UDim2.new(0,0,0,i*symH);cell.BackgroundTransparency=1;cell.BorderSizePixel=0;cell.Parent=tape
        local lbl=Instance.new('TextLabel');lbl.Size=UDim2.new(1,0,1,0)
        lbl.TextXAlignment=Enum.TextXAlignment.Center;lbl.TextYAlignment=Enum.TextYAlignment.Center
        lbl.BackgroundTransparency=1;lbl.Text=sym.e;lbl.TextScaled=true;lbl.ZIndex=6;lbl.Parent=cell
        if i==RES_POS then resultCells[ri]=cell end
    end; tape.Position=UDim2.new(0,0,0,0)
end
for ri=1,NREELS do buildTape(ri,SYMS2[((ri-1)%#SYMS2)+1].e) end

local function refreshSlots2Layout()
    applyResponsiveLayout()
    for ri = 1, NREELS do
        local lbl = resultCells[ri] and resultCells[ri]:FindFirstChildOfClass('TextLabel')
        local sym = lbl and lbl.Text or SYMS2[((ri - 1) % #SYMS2) + 1].e
        buildTape(ri, sym)
    end
end
slots2Page:GetPropertyChangedSignal('Visible'):Connect(function()
    if slots2Page.Visible then
        task.defer(refreshSlots2Layout)
    end
end)

local function getBet2() return math.max(10,math.min(tonumber(betBox2.Text) or 100,10000)) end
local STEPS2={10,50,100,500,1000,5000,10000}
minus2.MouseButton1Click:Connect(function() local b=getBet2();local n=10;for i=#STEPS2,1,-1 do if STEPS2[i]<b then n=STEPS2[i];break end end;betBox2.Text=tostring(n) end)
plus2.MouseButton1Click:Connect(function() local b=getBet2();local n=10000;for i=1,#STEPS2 do if STEPS2[i]>b then n=STEPS2[i];break end end;betBox2.Text=tostring(n) end)
max2.MouseButton1Click:Connect(function() betBox2.Text=tostring(math.max(10,math.min(math.floor(cachedCoins),10000))) end)
betBox2.FocusLost:Connect(function() local n=tonumber(betBox2.Text);betBox2.Text=tostring(n and math.max(10,math.min(math.floor(n),10000)) or 100) end)

local function highlightResults(matchSym)
    for ri=1,NREELS do
        local cell=resultCells[ri];if not cell then continue end
        local sym=symByEmoji(matchSym);local cellSym=''
        local lbl=cell:FindFirstChildOfClass('TextLabel');if lbl then cellSym=lbl.Text end
        local isMatch=(matchSym~='' and cellSym==matchSym)
        if isMatch then cell.BackgroundTransparency=0.72;cell.BackgroundColor3=sym.col
            local s=Instance.new('UIStroke');s.Color=sym.col;s.Thickness=2;s.Parent=cell
        else cell.BackgroundTransparency=0.88;cell.BackgroundColor3=Color3.fromRGB(60,60,60) end
    end
end
local function animateReel(ri,startDelay,onDone)
    local tape=tapes[ri];local clip=reelClips[ri];if not tape or not clip then if onDone then task.delay(startDelay+2,onDone) end;return end
    local clipH=math.max(clip.AbsoluteSize.Y,240);local symH=math.floor(clipH/NROWS)
    local TARGET_Y=clipH/2-symH/2-RES_POS*symH
    tape.Position=UDim2.new(0,0,0,0)
    task.delay(startDelay,function()
        local tw=TweenSvc:Create(tape,TweenInfo.new(1.4+ri*0.25,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,0,TARGET_Y)})
        tw:Play(); tw.Completed:Connect(function()
            local ns=Instance.new('UIStroke');ns.Color=Color3.fromRGB(255,220,0);ns.Thickness=3;ns.Parent=clip
            TweenSvc:Create(ns,TweenInfo.new(0.6),{Transparency=1,Thickness=1}):Play()
            task.delay(0.6,function() ns:Destroy() end)
            if onDone then onDone() end
        end)
    end)
end
local pendingOutcome2={}
local function doSpin2(outcomeName,matchCount,syms5,bet)
    while #syms5<NREELS do syms5[#syms5+1]=SYMS2[math.random(1,#SYMS2)].e end
    for ri=1,NREELS do buildTape(ri,syms5[ri]) end
    local done=0
    local function reelDone()
        done=done+1
        if done==NREELS then
            local info=OUTCOME_INFO[outcomeName] or OUTCOME_INFO.loss
            local cts={}; for _,s in ipairs(syms5) do cts[s]=(cts[s] or 0)+1 end
            local needCnt=(outcomeName=='near') and 2 or (matchCount or 0)
            local matchSym=''
            if needCnt>=2 then
                local bestRank=0
                for _,sd in ipairs(SYMS2) do
                    local e=sd.e; if (cts[e] or 0)==needCnt then
                        local rank=0; for ri2,sd2 in ipairs(SYMS2) do if sd2.e==e then rank=ri2 end end
                        if rank>bestRank then bestRank=rank;matchSym=e end
                    end
                end
                if matchSym=='' then local best=0; for s,c in pairs(cts) do if c>best then best=c;matchSym=s end end end
            end
            highlightResults(matchSym); confirmSpin2:FireServer()
            task.delay(0.5,function()
                isSpinning2=false; refreshCoinsFromServer()
                local factor=pendingOutcome2.factor or 0; local won=math.floor(bet*factor)
                showSlots2Result(true)
                setResultOutcome(res2Bg, res2Amount, res2Sym, won, factor, bet)
                if res2Neon then
                    if won >= bet and won > 0 then
                        res2Neon.Color = THEME.RESULT_WIN_STROKE
                    else
                        res2Neon.Color = THEME.RESULT_LOSS_STROKE
                    end
                end
                local tier=0
                local col=info.col
                if outcomeName:find('diamond') then tier=4 elseif outcomeName:find('seven') then tier=3
                elseif outcomeName:find('bar') or outcomeName:find('bell') then tier=2
                elseif outcomeName:find('cherry') or outcomeName:find('lemon') then tier=1 end
                if outcomeName:find('_5') then tier=tier+1 end
                if tier>=1 then burstParticles(col,tier==5 and 70 or tier==4 and 55 or tier==3 and 38 or tier==2 and 20 or 8,particleCanvas) end
                if tier>=2 then flashSheen(col,tier==5 and 0.45 or tier==4 and 0.3 or tier==3 and 0.22 or 0.12) end
                local s2snd=tier>=4 and sndLegend or tier>=3 and sndEpic or tier>=1 and sndCommon or nil
                if s2snd then SoundController.playSfx(s2snd); fireSpinState("reward", s2snd) else fireSpinState("cancel") end
                spin2Btn.Text='SPIN'; stylePrimaryBtn(spin2Btn)
            end)
        end
    end
    for ri=1,NREELS do animateReel(ri,(ri-1)*0.22,reelDone) end
end
spin2Btn.MouseButton1Click:Connect(function()
    if isSpinning2 then return end; isSpinning2=true; showSlots2Result(false)
    fireSpinState("start")
    spin2Btn.Text='...'; spin2Btn.BackgroundColor3=THEME.BUSY
    local bet=getBet2()
    if cachedCoins>=bet then setAllCoins(cachedCoins-bet); pulseCoinBadge() end
    spinSlots2:FireServer(bet)
end)
slotResult2.OnClientEvent:Connect(function(success,outcomeName,matchCount,syms,bet,afterBet)
    if not success then
        isSpinning2=false; spin2Btn.Text='SPIN'; stylePrimaryBtn(spin2Btn)
        fireSpinState("cancel")
        showSlots2Result(true)
        setResultError(res2Bg, res2Amount, res2Sym, 'Not enough Coins')
        if res2Neon then res2Neon.Color=THEME.RESULT_LOSS_STROKE end
        return
    end
    res2Amount.Visible = true
    res2Sym.Visible = true
    pendingOutcome2={factor=0}
    local FACTORS={diamond_3=1.60,diamond_4=4.43,diamond_5=16.02,seven_3=1.13,seven_4=2.64,seven_5=8.86,
        bar_3=0.90,bar_4=1.79,bar_5=4.43,bell_3=0.71,bell_4=1.13,bell_5=2.64,
        cherry_3=0.61,cherry_4=0.99,cherry_5=1.79,lemon_3=0.44,lemon_4=0.71,lemon_5=1.13,near=0.09,loss=0}
    pendingOutcome2.factor=FACTORS[outcomeName] or 0
    setAllCoins(afterBet); doSpin2(outcomeName,matchCount or 0,syms or {},bet)
end)

end
initSlots2()

local function initPlinko()
-- ════════════════════════════════════════════
-- SLOTS 3 PAGE (Plinko)
-- ════════════════════════════════════════════
local spinPlinko=Remotes:WaitForChild('SpinPlinko'); local plinkoResult=Remotes:WaitForChild('PlinkoResult')
local lp3=slots3Page:WaitForChild('LeftPanel'); local bc3=lp3:WaitForChild('BetBox')
local bpRow=bc3:WaitForChild('BallPriceRow'); local nbRow=bc3:WaitForChild('NumBallsRow')
local bpLbl=bpRow.Controls:FindFirstChild('ValueLbl'); local nbLbl=nbRow.Controls:FindFirstChild('ValueLbl')
local bpMinus=bpRow.Controls:WaitForChild('MinusBtn'); local bpPlus=bpRow.Controls:WaitForChild('PlusBtn')
local nbMinus=nbRow.Controls:WaitForChild('MinusBtn'); local nbPlus=nbRow.Controls:WaitForChild('PlusBtn')
local finLbl=bc3:FindFirstChild('TotalBetVal') and bc3.TotalBetVal:FindFirstChild('TotalLbl')
local betBtn3=bc3:WaitForChild('BetBtn')
bindCoolHover(betBtn3, 1.05)
bindCoolHover(bpMinus, 1.08)
bindCoolHover(bpPlus, 1.08)
local wc3=lp3:WaitForChild('WinDisplay')
local wMults3=wc3:WaitForChild('MultsLabel'); local wNet3=wc3:WaitForChild('NetLabel')
local wNeon3=wc3:FindFirstChildOfClass('UIStroke')
styleResultBox(wc3, { wNet3, wMults3 })
wc3.Visible=false
local bf3=slots3Page:WaitForChild('BoardFrame'); local pc3=bf3:WaitForChild('PinCanvas')
local ppc3=pc3:WaitForChild('BallCanvas'); local mb3=bf3:WaitForChild('MultBar')

local function isInsidePlinkoCore(obj)
    return obj == pc3 or obj == ppc3 or obj == mb3 or obj:IsDescendantOf(pc3) or obj:IsDescendantOf(mb3)
end

local function removePlinkoBgDots()
    for _, obj in ipairs(bf3:GetDescendants()) do
        if obj:IsA('GuiObject') and not isInsidePlinkoCore(obj) then
            local sx = obj.Size.X.Offset
            local sy = obj.Size.Y.Offset
            local tiny = sx > 0 and sy > 0 and sx <= 10 and sy <= 10
            local dotName = string.find(string.lower(obj.Name), 'dot') ~= nil
            if tiny or dotName then
                obj:Destroy()
            end
        end
    end
end


local P3_ROWS=10; local P3_RISK='Medium'; local p3BallPrice=100; local p3NumBalls=1
local BALL_PRICES={10,25,50,100,250,500,1000,2500,5000,10000}; local p3BPI=4
local PMULTS3={[10]={Medium={5.544,2.772,1.243,0.717,0.382,0.220,0.382,0.717,1.243,2.772,5.544}}}
local function mCol3(f) if f>=4 then return Color3.fromRGB(255,70,70) end if f>=2 then return Color3.fromRGB(255,145,45) end if f>=1 then return Color3.fromRGB(255,220,70) end if f>=0.6 then return Color3.fromRGB(70,220,105) end return Color3.fromRGB(135,95,255) end
local function mColBright(f) if f>=4 then return Color3.fromRGB(255,100,100) end if f>=2 then return Color3.fromRGB(255,160,60) end if f>=1 then return Color3.fromRGB(255,230,80) end if f>=0.6 then return Color3.fromRGB(80,220,110) end return Color3.fromRGB(140,100,255) end
local function mTextCol3(f) if f>=1 then return Color3.fromRGB(28,24,10) end return Color3.fromRGB(255,255,255) end
local function fmtM(f) if f==math.floor(f) then return math.floor(f)..'x' end return string.format('%.2gx',f) end

local function upP3()
    if bpLbl then bpLbl.Text=tostring(p3BallPrice) end
    if nbLbl then nbLbl.Text=tostring(p3NumBalls) end
    if finLbl then finLbl.Text=tostring(p3BallPrice*p3NumBalls)..' C' end
end; upP3()

bpMinus.MouseButton1Click:Connect(function() p3BPI=math.max(1,p3BPI-1);p3BallPrice=BALL_PRICES[p3BPI];upP3() end)
bpPlus.MouseButton1Click:Connect(function() p3BPI=math.min(#BALL_PRICES,p3BPI+1);p3BallPrice=BALL_PRICES[p3BPI];upP3() end)
nbMinus.MouseButton1Click:Connect(function() p3NumBalls=math.max(1,p3NumBalls-1);upP3() end)
nbPlus.MouseButton1Click:Connect(function() p3NumBalls=math.min(5,p3NumBalls+1);upP3() end)

local pinOb3={};local multOb3={};local bb3done=false

local function getPinLayout3()
    local W, H = getLocalSize(pc3)
    if W < 10 then W = 510 end
    if H < 10 then H = 300 end
    local padX, padY = W * 0.06, H * 0.04
    local usableW, usableH = W - padX * 2, H - padY * 2
    local maxP = P3_ROWS + 2
    local pSX = usableW / (maxP + 1)
    local pSY = usableH / (P3_ROWS + 1)
    local pinSize = math.clamp(math.floor(math.min(pSX, pSY) * 0.35), 6, 14)
    local ballRadius = math.clamp(math.floor(pinSize * 1.05), 5, 16)
    return W, H, padX, padY, usableW, usableH, pSX, pSY, maxP, pinSize, ballRadius
end

local function getBallRadius3()
    return select(11, getPinLayout3())
end

local function bldBoard3()
    removePlinkoBgDots()
    for _,c in ipairs(pc3:GetChildren()) do if c~=ppc3 then c:Destroy() end end
    for _,c in ipairs(mb3:GetChildren()) do c:Destroy() end
    pinOb3={};multOb3={}
    local mults=PMULTS3[P3_ROWS] and PMULTS3[P3_ROWS][P3_RISK] or PMULTS3[10].Medium; local nS=#mults
    local W, H, padX, padY, usableW, usableH, pSX, pSY, maxP, pinSize = getPinLayout3()
    for row=1,P3_ROWS do
        local nP=row+2; local ofs=(maxP-nP)/2; pinOb3[row]={}
        for col=1,nP do
            local cx = padX + (ofs + col) * pSX
            local cy = padY + row * pSY
            local pin=Instance.new('Frame'); pin.Size=UDim2.new(0,pinSize,0,pinSize)
            pin.Position=UDim2.new(0,cx-pinSize/2,0,cy-pinSize/2); pin.BackgroundColor3=Color3.fromRGB(200,205,230)
            pin.BorderSizePixel=0; pin.ZIndex=5; pin.Parent=pc3
            local pc=Instance.new('UICorner'); pc.CornerRadius=UDim.new(0,99); pc.Parent=pin
            local ps=Instance.new('UIStroke'); ps.Color=Color3.fromRGB(120,100,200); ps.Thickness=1; ps.Parent=pin
            pinOb3[row][col]={cx=cx,cy=cy,fr=pin}
        end
    end
    local gapScale=0.01
    for si=1,nS do
        local f=mults[si]; local bg=Instance.new('Frame')
        bg.Size=UDim2.new(1/nS - gapScale, 0, 1, -6)
        bg.Position=UDim2.new((si-1)/nS + gapScale*0.5, 0, 0, 3)
        bg.BackgroundColor3=mCol3(f);bg.BorderSizePixel=0;bg.ZIndex=5;bg.Parent=mb3
        local mc=Instance.new('UICorner');mc.CornerRadius=UDim.new(0,6);mc.Parent=bg
        local lbl=Instance.new('TextLabel');lbl.Size=UDim2.new(1,-4,1,-2);lbl.Position=UDim2.new(0.5,0,0.5,0);lbl.AnchorPoint=Vector2.new(0.5,0.5)
        lbl.BackgroundTransparency=1;lbl.Text=fmtM(f);lbl.Font=Enum.Font.GothamBlack;lbl.ZIndex=6;lbl.TextScaled=true;lbl.Parent=bg
        lbl.TextColor3=mTextCol3(f)
        local tsc=Instance.new('UITextSizeConstraint');tsc.MaxTextSize=22;tsc.MinTextSize=8;tsc.Parent=lbl
        local ls=Instance.new('UIStroke');ls.Color=f>=1 and Color3.fromRGB(255,255,255) or Color3.fromRGB(20,10,60);ls.Thickness=1;ls.Transparency=0.25;ls.Parent=lbl
        multOb3[si]={bg=bg,f=f,tw=(W/nS),si=si}
    end
end
slots3Page:GetPropertyChangedSignal('Visible'):Connect(function()
    if slots3Page.Visible then task.wait(0.08); bldBoard3(); bb3done=true end
end)
pc3:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
    if slots3Page.Visible and bb3done then bldBoard3() end
end)

local function burst3(col,brightCol,px,py,cnt)
    for _=1,cnt do task.delay(math.random()*0.12,function()
        local pSize = math.max(4, math.floor(getBallRadius3() * 0.85))
        local p=Instance.new('Frame');p.Size=UDim2.new(0,pSize,0,pSize);p.AnchorPoint=Vector2.new(0.5,0.5)
        local lw, lh = getLocalSize(pc3)
        local rx=(px/math.max(lw,1))+(math.random()-0.5)*0.06
        local ry=(py/math.max(lh,1))+(math.random()-0.5)*0.06
        p.Position=UDim2.new(rx,0,ry,0);p.BackgroundColor3=brightCol
        p.BorderSizePixel=0;p.ZIndex=18;p.Parent=ppc3
        local pc2=Instance.new('UICorner');pc2.CornerRadius=UDim.new(0,99);pc2.Parent=p
        local vx=(math.random()-0.5)*0.5;local vy=-math.random()*0.45-0.15
        local life=0;local conn2
        conn2=RunSvc.RenderStepped:Connect(function(dt)
            life=life+dt;vy=vy+0.55*dt
            local nx=p.Position.X.Scale+vx*dt;local ny=p.Position.Y.Scale+vy*dt
            p.Position=UDim2.new(nx,0,ny,0);p.BackgroundTransparency=math.min(1,life/0.75)
            if life>0.75 then conn2:Disconnect();p:Destroy() end
        end)
    end) end
end

local function cWpts3(path)
    local mults=PMULTS3[P3_ROWS][P3_RISK];local nS=#mults
    local W, H, padX, padY, usableW, usableH, pSX, pSY, maxP, _, ballR = getPinLayout3()
    local pts={{x=W/2,y=-ballR*2}};local c=0
    for r=1,P3_ROWS do
        local dir=path[r];c=c+dir;local nP=r+2;local ofs=(maxP-nP)/2
        local pinCol=math.min(math.max(1,c+1),nP)
        local pinX=padX+(ofs+pinCol)*pSX;local pinY=padY+r*pSY
        pts[#pts+1]={x=pinX,y=pinY-ballR*0.6}
        if r<P3_ROWS then
            local nP2=(r+1)+2;local ofs2=(maxP-nP2)/2
            local gapX=padX+(ofs2+c+1.5)*pSX;local gapY=padY+(r+0.55)*pSY; pts[#pts+1]={x=gapX,y=gapY}
        end
    end
    local sW=W/nS;local landX=(c+0.5)*sW; pts[#pts+1]={x=landX,y=H-ballR}; return pts,c
end
local pallete3={{220,50,50},{255,140,0},{255,218,55},{50,200,100},{70,160,255},{190,90,255}}
local function spwnBall3(path,finalSlot,ballIdx,onDone)
    local ballR=getBallRadius3()
    local pts,c=cWpts3(path)
    local ball=Instance.new('Frame');ball.Size=UDim2.new(0,ballR*2,0,ballR*2)
    local pc=pallete3[((ballIdx-1)%6)+1]
    ball.BackgroundColor3=Color3.fromRGB(pc[1],pc[2],pc[3])
    ball.BorderSizePixel=0;ball.ZIndex=13;ball.Parent=pc3
    local bc2=Instance.new('UICorner');bc2.CornerRadius=UDim.new(0,99);bc2.Parent=ball
    local bs=Instance.new('UIStroke');bs.Color=Color3.new(1,1,1);bs.Thickness=1.5;bs.Parent=ball
    ball.Position=UDim2.new(0,pts[1].x-ballR,0,pts[1].y-ballR)
    local SEG_T=0.10;local seg=1;local elapsed=0;local lastFlash=0
    local conn;conn=RunSvc.Heartbeat:Connect(function(dt)
        if seg>=#pts then
            conn:Disconnect();ball:Destroy()
            local si=finalSlot+1
            if multOb3[si] then
                local mo=multOb3[si];local orig=mCol3(mo.f);local bc3c=mColBright(mo.f)
                TweenSvc:Create(mo.bg,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(255,248,100)}):Play()
                task.delay(0.25,function() if mo.bg.Parent then TweenSvc:Create(mo.bg,TweenInfo.new(0.2),{BackgroundColor3=orig}):Play() end end)
                local mults=PMULTS3[P3_ROWS][P3_RISK];local W3=select(1, getLocalSize(pc3));if W3<10 then W3=510 end
                local sW2=W3/#mults;local lx=(finalSlot+0.5)*sW2;local ly=select(2, getLocalSize(pc3))+2
                local cnt=mo.f>=5 and 28 or mo.f>=2 and 16 or mo.f>=1 and 10 or 6
                burst3(orig,bc3c,lx,ly-40,cnt)
                local f3=mo.f;local lsnd=f3>=4 and sndLegend or f3>=1.3 and sndEpic or f3>=0.6 and sndCommon or sndBad
                if lsnd then SoundController.playSfx(lsnd); lastP3Snd=lsnd end
            end
            if onDone then task.delay(0.1,onDone) end;return
        end
        elapsed=elapsed+dt;local t=math.min(elapsed/SEG_T,1);local ts=t*t*(3-2*t)
        local p0=pts[seg];local p1=pts[seg+1]
        local bx=p0.x+(p1.x-p0.x)*ts;local by=p0.y+(p1.y-p0.y)*ts
        ball.Position=UDim2.new(0,bx-ballR,0,by-ballR)
        if seg%2==1 and t>0.45 and t<0.55 and lastFlash~=seg then
            lastFlash=seg;local row=math.ceil(seg/2)
            if pinOb3[row] then
                local best,bd=nil,999
                for _,pd in ipairs(pinOb3[row]) do local d=math.abs(pd.cx-p0.x);if d<bd then bd=d;best=pd end end
                if best and best.fr and best.fr.Parent then
                    TweenSvc:Create(best.fr,TweenInfo.new(0.04),{BackgroundColor3=Color3.fromRGB(255,220,80)}):Play()
                    task.delay(0.1,function() if best.fr.Parent then TweenSvc:Create(best.fr,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(200,205,230)}):Play() end end)
                end
            end
        end
        if t>=1 then elapsed=0;seg=seg+1 end
    end)
end
local pendP3={}
local lastP3Snd=nil
wc3.Visible=false
betBtn3.MouseButton1Click:Connect(function()
    if isP3 then return end
    local totalBet3=p3BallPrice*p3NumBalls
    if cachedCoins<totalBet3 then
        wc3.Visible=true
        setResultError(wc3, wNet3, wMults3, 'Not enough Coins')
        if wNeon3 then wNeon3.Color=THEME.RESULT_LOSS_STROKE end
        return
    end
    isP3=true;pendP3={};lastP3Snd=nil;wc3.Visible=false
    fireSpinState("start")
    betBtn3.Text='...';betBtn3.BackgroundColor3=THEME.BUSY
    setAllCoins(cachedCoins-totalBet3);pulseCoinBadge()
    spinPlinko:FireServer(p3BallPrice,p3NumBalls,P3_ROWS,P3_RISK)
end)
plinkoResult.OnClientEvent:Connect(function(ok3,allPaths,allSlots,allFactors,ballPrice,numBalls,afterC)
    if not ok3 then
        isP3=false;betBtn3.Text='BET';stylePrimaryBtn(betBtn3)
        fireSpinState("cancel")
        refreshCoinsFromServer()
        wc3.Visible=true
        setResultError(wc3, wNet3, wMults3, 'Not enough Coins')
        if wNeon3 then wNeon3.Color=THEME.RESULT_LOSS_STROKE end
        return
	end
    local done=0
    local function onDone3(bi)
        pendP3[bi]={slot=allSlots[bi],factor=allFactors[bi]};done=done+1
        if done==numBalls then
            isP3=false;betBtn3.Text='BET';stylePrimaryBtn(betBtn3)
            if lastP3Snd then fireSpinState("reward", lastP3Snd) else fireSpinState("cancel") end
            local totalWon=0;local multSum=0
            for i=1,numBalls do local pd=pendP3[i];if pd then totalWon=totalWon+math.floor(ballPrice*pd.factor);multSum=multSum+(pd.factor or 0) end end
            local totalBet=ballPrice*numBalls;wc3.Visible=true;setAllCoins(afterC);pulseCoinBadge()
            setResultOutcome(wc3, wNet3, wMults3, totalWon, multSum, totalBet)
            if wNeon3 then
                if totalWon >= totalBet and totalWon > 0 then
                    wNeon3.Color = THEME.RESULT_WIN_STROKE
                else
                    wNeon3.Color = THEME.RESULT_LOSS_STROKE
                end
            end
        end
    end
    for bi=1,numBalls do task.delay((bi-1)*0.75,function() spwnBall3(allPaths[bi],allSlots[bi],bi,function() onDone3(bi) end) end) end
end)

	plinkoLayoutHook = function()
		if bb3done then
			bldBoard3()
		end
	end
end
initPlinko()

local function initWheel()
-- ============================================================
-- LUCKY WHEEL
-- ============================================================
local spinWheel = Remotes:WaitForChild("SpinWheel")
local wheelResult = Remotes:WaitForChild("WheelResult")
local confirmWheel = Remotes:WaitForChild("ConfirmWheel")

local stage = wheelPage:WaitForChild("WheelStage")
local disc = stage:WaitForChild("WheelDisc")
local betRow = wheelPage:WaitForChild("BetRow")
local minusBtn = betRow:WaitForChild("MinusBtn")
local plusBtn = betRow:WaitForChild("PlusBtn")
local maxBtn = betRow:WaitForChild("MaxBtn")
local betBox = betRow:WaitForChild("BetInput")
local riskBtn = wheelPage:WaitForChild("RiskBtn")
local spinBtn = wheelPage:WaitForChild("SpinBtn")
local resultBg = wheelPage:WaitForChild("ResultBg")
do
	local old = resultBg:FindFirstChild("ResultLbl")
	if old and not resultBg:FindFirstChild("CoinsLbl") then
		old.Name = "CoinsLbl"
	end
end
local resultCoins, resultMult = ensureResultLabels(resultBg, "CoinsLbl", "MultLbl")
resultBg.Visible = false

CasinoUiTheme.stylePrimaryBtn(spinBtn)
CasinoUiTheme.styleGhostBtn(riskBtn)
CasinoUiTheme.styleGhostBtn(minusBtn)
CasinoUiTheme.styleGhostBtn(plusBtn)
CasinoUiTheme.styleGhostBtn(maxBtn)
styleResultBox(resultBg, { resultCoins, resultMult })
CasinoUiTheme.ensureGameTitle(wheelPage, "Lucky Wheel")

local AssetService = game:GetService("AssetService")
local WHEEL_PX = 512
local RIM_COLOR = Color3.fromRGB(45, 48, 55)
local RIM_THICK = 10
local HUB_OUTER = 0.2
local HUB_INNER = 0.12
local DIVIDER_DEG = 1.1
local WHEEL_COLORS = {
	Color3.fromRGB(230, 55, 55),
	Color3.fromRGB(235, 110, 40),
	Color3.fromRGB(240, 165, 35),
	Color3.fromRGB(245, 210, 45),
	Color3.fromRGB(70, 195, 70),
	Color3.fromRGB(45, 200, 200),
	Color3.fromRGB(50, 130, 220),
	Color3.fromRGB(55, 80, 210),
	Color3.fromRGB(130, 70, 210),
	Color3.fromRGB(200, 55, 180),
	Color3.fromRGB(220, 50, 110),
	Color3.fromRGB(225, 50, 70),
}

local function ensureCornerFull(obj)
	local c = obj:FindFirstChildOfClass("UICorner")
	if not c then
		c = Instance.new("UICorner")
		c.Parent = obj
	end
	c.CornerRadius = UDim.new(1, 0)
end

local function ensureStrokeThick(obj, color, thick)
	local s = obj:FindFirstChildOfClass("UIStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Parent = obj
	end
	s.Color = color
	s.Thickness = thick
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

-- Flat charcoal rim (stage clips face)
stage.BackgroundColor3 = RIM_COLOR
stage.BackgroundTransparency = 0
stage.ClipsDescendants = true
stage.BorderSizePixel = 0
ensureCornerFull(stage)
ensureStrokeThick(stage, RIM_COLOR, RIM_THICK)

local function ensureTeardropPointer()
	local old = wheelPage:FindFirstChild("Pointer")
	if old and not old:IsA("Frame") then
		old:Destroy()
		old = nil
	end
	local ptr = old
	if not ptr then
		ptr = Instance.new("Frame")
		ptr.Name = "Pointer"
		ptr.Parent = wheelPage
	end
	ptr.BackgroundTransparency = 1
	ptr.BorderSizePixel = 0
	ptr.ZIndex = 40
	ptr.AnchorPoint = Vector2.new(0.5, 1)
	for _, c in ipairs(ptr:GetChildren()) do
		c:Destroy()
	end
	local bulb = Instance.new("Frame")
	bulb.Name = "Bulb"
	bulb.AnchorPoint = Vector2.new(0.5, 0)
	bulb.Position = UDim2.new(0.5, 0, 0, 0)
	bulb.Size = UDim2.new(0.72, 0, 0.42, 0)
	bulb.BackgroundColor3 = RIM_COLOR
	bulb.BorderSizePixel = 0
	bulb.ZIndex = 41
	bulb.Parent = ptr
	ensureCornerFull(bulb)
	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.new(0.5, 0, 0.62, 0)
	tip.Size = UDim2.new(0.55, 0, 0.55, 0)
	tip.BackgroundColor3 = RIM_COLOR
	tip.BorderSizePixel = 0
	tip.Rotation = 45
	tip.ZIndex = 41
	tip.Parent = ptr
	return ptr
end
ensureTeardropPointer()

local function ensureWheelBase()
	local base = wheelPage:FindFirstChild("WheelBase")
	if not base then
		base = Instance.new("Frame")
		base.Name = "WheelBase"
		base.Parent = wheelPage
	end
	base.BackgroundTransparency = 1
	base.BorderSizePixel = 0
	base.ZIndex = 9
	local neck = base:FindFirstChild("Neck")
	if not neck then
		neck = Instance.new("Frame")
		neck.Name = "Neck"
		neck.Parent = base
	end
	neck.BackgroundColor3 = RIM_COLOR
	neck.BorderSizePixel = 0
	neck.ZIndex = 9
	local nc = neck:FindFirstChildOfClass("UICorner")
	if not nc then
		nc = Instance.new("UICorner")
		nc.Parent = neck
	end
	nc.CornerRadius = UDim.new(0, 6)
	local plate = base:FindFirstChild("Plate")
	if not plate then
		plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.Parent = base
	end
	plate.BackgroundColor3 = RIM_COLOR
	plate.BorderSizePixel = 0
	plate.ZIndex = 9
	local pc = plate:FindFirstChildOfClass("UICorner")
	if not pc then
		pc = Instance.new("UICorner")
		pc.Parent = plate
	end
	pc.CornerRadius = UDim.new(0, 4)
	return base
end
ensureWheelBase()

local function paintWheelFace(n)
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(WHEEL_PX, WHEEL_PX) })
	end)
	if not ok or not img then
		warn("[LuckyWheel] EditableImage create failed:", img)
		return nil
	end
	local px = WHEEL_PX
	local cx = (px - 1) * 0.5
	local cy = (px - 1) * 0.5
	local radius = px * 0.5 - 2
	local r2 = radius * radius
	local segSpan = 360 / n
	local buf = buffer.create(px * px * 4)
	local colors = table.create(n)
	for i = 1, n do
		local c = WHEEL_COLORS[((i - 1) % #WHEEL_COLORS) + 1]
		colors[i] = {
			math.floor(c.R * 255 + 0.5),
			math.floor(c.G * 255 + 0.5),
			math.floor(c.B * 255 + 0.5),
		}
	end
	local dr = math.floor(RIM_COLOR.R * 255 + 0.5)
	local dg = math.floor(RIM_COLOR.G * 255 + 0.5)
	local db = math.floor(RIM_COLOR.B * 255 + 0.5)
	for y = 0, px - 1 do
		local dy = y - cy
		for x = 0, px - 1 do
			local dx = x - cx
			local i0 = ((y * px) + x) * 4
			local dist2 = dx * dx + dy * dy
			if dist2 > r2 then
				buffer.writeu8(buf, i0, 0)
				buffer.writeu8(buf, i0 + 1, 0)
				buffer.writeu8(buf, i0 + 2, 0)
				buffer.writeu8(buf, i0 + 3, 0)
			else
				local ang = math.deg(math.atan2(dx, -dy))
				if ang < 0 then
					ang += 360
				end
				local edge = ang % segSpan
				local nearEdge = edge < DIVIDER_DEG or edge > (segSpan - DIVIDER_DEG)
				if nearEdge then
					buffer.writeu8(buf, i0, dr)
					buffer.writeu8(buf, i0 + 1, dg)
					buffer.writeu8(buf, i0 + 2, db)
					buffer.writeu8(buf, i0 + 3, 255)
				else
					local seg = math.floor(ang / segSpan) + 1
					if seg > n then
						seg = n
					end
					local col = colors[seg]
					buffer.writeu8(buf, i0, col[1])
					buffer.writeu8(buf, i0 + 1, col[2])
					buffer.writeu8(buf, i0 + 2, col[3])
					buffer.writeu8(buf, i0 + 3, 255)
				end
			end
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(px, px), buf)
	return img
end

local function ensureWheelFace(n)
	local face = disc:FindFirstChild("Face")
	if not face then
		face = Instance.new("ImageLabel")
		face.Name = "Face"
		face.BackgroundTransparency = 1
		face.BorderSizePixel = 0
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromScale(0.5, 0.5)
		face.Size = UDim2.fromScale(0.92, 0.92)
		face.ZIndex = 11
		face.ScaleType = Enum.ScaleType.Fit
		face.Parent = disc
	end
	if face:GetAttribute("PaintedSegs") == n then
		return face
	end
	local img = paintWheelFace(n)
	if img then
		face.ImageContent = Content.fromObject(img)
		face:SetAttribute("PaintedSegs", n)
	end
	return face
end

bindCoolHover(spinBtn, 1.05)
bindCoolHover(riskBtn, 1.05)
bindCoolHover(minusBtn, 1.08)
bindCoolHover(plusBtn, 1.08)

local WHEEL_SAFE = { 0.3, 0.4, 0.5, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.5, 2.4 }
local WHEEL_RISK = { 0, 0, 0, 0, 0, 0, 0.25, 0.5, 1, 1.75, 2.5, 4.8 }
local STEPS_W = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 }
local LABEL_R = 0.38
local LABEL_W = 0.15
local LABEL_H = 0.09
local riskOn = false
local curTable = WHEEL_SAFE
local discRot = 0

local function fmtMult(v)
	if v == 0 then
		return "0x"
	elseif v == math.floor(v) then
		return tostring(math.floor(v)) .. "x"
	else
		return string.format("%.2gx", v)
	end
end

local function rebuildDiscLabels(tbl)
	for _, c in ipairs(disc:GetChildren()) do
		if c.Name ~= "Face" then
			c:Destroy()
		end
	end
	curTable = tbl
	local n = #tbl
	ensureWheelFace(n)
	local maxMult = 0
	for _, mult in ipairs(tbl) do
		if mult > maxMult then
			maxMult = mult
		end
	end
	for i, mult in ipairs(tbl) do
		local ang = (i - 0.5) / n * 360
		local rad = math.rad(ang - 90)
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Seg" .. i
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(LABEL_W, 0, LABEL_H, 0)
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = UDim2.new(0.5 + math.cos(rad) * LABEL_R, 0, 0.5 + math.sin(rad) * LABEL_R, 0)
		lbl.Rotation = ang
		lbl.Text = fmtMult(mult)
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.TextColor3 = if mult == maxMult and maxMult > 0 then Color3.fromRGB(255, 240, 120) elseif mult <= 0 then Color3.fromRGB(255, 230, 230) else Color3.fromRGB(255, 255, 255)
		lbl.ZIndex = 13
		lbl.Parent = disc
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 22, 28)
		stroke.Thickness = 1.6
		stroke.Parent = lbl
	end
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(HUB_OUTER, HUB_OUTER)
	hub.BackgroundColor3 = RIM_COLOR
	hub.BorderSizePixel = 0
	hub.ZIndex = 14
	hub.Parent = disc
	ensureCornerFull(hub)
	local hubIn = Instance.new("Frame")
	hubIn.Name = "HubInner"
	hubIn.AnchorPoint = Vector2.new(0.5, 0.5)
	hubIn.Position = UDim2.fromScale(0.5, 0.5)
	hubIn.Size = UDim2.fromScale(HUB_INNER / HUB_OUTER, HUB_INNER / HUB_OUTER)
	hubIn.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	hubIn.BorderSizePixel = 0
	hubIn.ZIndex = 15
	hubIn.Parent = hub
	ensureCornerFull(hubIn)
end
rebuildDiscLabels(WHEEL_SAFE)

local function getBetW()
	return math.clamp(tonumber(betBox.Text) or 100, 10, 10000)
end

local function setBetW(v)
	betBox.Text = tostring(math.clamp(math.floor(v), 10, 10000))
end

local function stepBetW(dir)
	local cur = getBetW()
	local idx = 1
	for i, s in ipairs(STEPS_W) do
		if s <= cur then
			idx = i
		end
	end
	idx = math.clamp(idx + dir, 1, #STEPS_W)
	setBetW(STEPS_W[idx])
end

minusBtn.MouseButton1Click:Connect(function()
	stepBetW(-1)
end)
plusBtn.MouseButton1Click:Connect(function()
	stepBetW(1)
end)
maxBtn.MouseButton1Click:Connect(function()
	setBetW(math.min(10000, cachedCoins))
end)

local function refreshRiskBtn()
	riskBtn.Text = if riskOn then "RISK: ON" else "RISK: OFF"
	riskBtn.BackgroundColor3 = if riskOn then Color3.fromRGB(180, 50, 70) else Color3.fromRGB(48, 92, 180)
	rebuildDiscLabels(if riskOn then WHEEL_RISK else WHEEL_SAFE)
end

riskBtn.MouseButton1Click:Connect(function()
	if isWheelSpinning then
		return
	end
	riskOn = not riskOn
	refreshRiskBtn()
end)

local function landAngleForIndex(idx, n)
	return -((idx - 0.5) / n * 360)
end

spinBtn.MouseButton1Click:Connect(function()
	if isWheelSpinning then
		return
	end
	local bet = getBetW()
	if cachedCoins < bet then
		resultBg.Visible = true
		setResultError(resultBg, resultCoins, resultMult, "Not enough Coins")
		return
	end
	isWheelSpinning = true
	resultBg.Visible = false
	fireSpinState("start", nil)
	spinWheel:FireServer(bet, riskOn)
end)

wheelResult.OnClientEvent:Connect(function(ok, idx, factor, risk, bet, coinsAfter, _nearIdx, tbl)
	if not ok then
		isWheelSpinning = false
		fireSpinState("stop", nil)
		resultBg.Visible = true
		setResultError(resultBg, resultCoins, resultMult, "Not enough Coins")
		if typeof(coinsAfter) == "number" then
			setAllCoins(coinsAfter)
		end
		return
	end
	if typeof(tbl) == "table" then
		rebuildDiscLabels(tbl)
	end
	setAllCoins(coinsAfter)
	local n = #curTable
	local target = landAngleForIndex(idx, n)
	local spins = 4 + math.random(0, 2)
	local finalRot = discRot - (discRot % 360) + spins * 360 + target
	local overshoot = finalRot + (math.random() > 0.45 and 12 or -8)
	local tw1 = TweenSvc:Create(disc, TweenInfo.new(2.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = overshoot })
	tw1:Play()
	tw1.Completed:Wait()
	local tw2 = TweenSvc:Create(disc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = finalRot })
	tw2:Play()
	tw2.Completed:Wait()
	discRot = finalRot
	disc.Rotation = finalRot

	local payout = math.floor(bet * factor)
	resultBg.Visible = true
	setResultOutcome(resultBg, resultCoins, resultMult, payout, factor, bet)
	if factor <= 0 then
		pcall(function()
			sndBad:Play()
		end)
		fireSpinState("stop", "bad")
	elseif factor >= 3 then
		pcall(function()
			sndLegend:Play()
		end)
		fireSpinState("stop", "jackpot")
	elseif factor >= 1 then
		pcall(function()
			sndEpic:Play()
		end)
		fireSpinState("stop", "mid")
	else
		pcall(function()
			sndCommon:Play()
		end)
		fireSpinState("stop", "basic")
	end
	confirmWheel:FireServer()
	task.wait(0.15)
	refreshCoinsFromServer()
	isWheelSpinning = false
end)
end
initWheel()

local function initMines()
-- ============================================================
-- DIAMOND MINES
-- ============================================================
local startMines = Remotes:WaitForChild("StartMines")
local revealMines = Remotes:WaitForChild("RevealMines")
local collectMines = Remotes:WaitForChild("CollectMines")
local minesUpdate = Remotes:WaitForChild("MinesUpdate")

local gridHost = minesPage:WaitForChild("GridFrame")
local grid = gridHost:FindFirstChild("GridInner") or gridHost
local left = minesPage:WaitForChild("LeftPanel")
local sizeRow = left:WaitForChild("SizeRow")
local betRow = left:WaitForChild("BetRow")
local startBtn = left:WaitForChild("StartBtn")
local betBox = betRow:WaitForChild("BetInput")
local minusBtn = betRow:WaitForChild("MinusBtn")
local plusBtn = betRow:WaitForChild("PlusBtn")
local multLbl = left:FindFirstChild("MultLbl", true) :: TextLabel
local infoLbl = left:FindFirstChild("InfoLbl", true) :: TextLabel
if not multLbl then
	multLbl = left:WaitForChild("MultLbl") :: TextLabel
end
if not infoLbl then
	infoLbl = left:WaitForChild("InfoLbl") :: TextLabel
end
local winDisplay = left:FindFirstChild("WinDisplay") :: Frame?
-- MultLbl = coins line, InfoLbl = mult line (shared result layout)
local minesCoinsLbl = multLbl
local minesMultLbl = infoLbl

CasinoUiTheme.ensureGameTitle(minesPage, "Diamond Mines")
CasinoUiTheme.stylePanel(gridHost, THEME.CORNER)
CasinoUiTheme.stylePrimaryBtn(startBtn)
CasinoUiTheme.styleGhostBtn(minusBtn)
CasinoUiTheme.styleGhostBtn(plusBtn)
if winDisplay then
	styleResultBox(winDisplay, { minesCoinsLbl, minesMultLbl })
end
for _, n in ipairs({ "Size3", "Size4", "Size5" }) do
	local b = sizeRow:FindFirstChild(n)
	if b then
		CasinoUiTheme.styleGhostBtn(b)
		bindCoolHover(b, 1.06)
	end
end
bindCoolHover(startBtn, 1.05)

local STEPS_M = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 }
local BOMBS_FOR = { [3] = 1, [4] = 3, [5] = 5 }
local sizeN = 3
local inRound = false
local cellBtns: { TextButton } = {}
local collectPulse = Instance.new("UIScale")
collectPulse.Name = "PulseScale"
collectPulse.Parent = startBtn

local function getBetM()
	return math.clamp(tonumber(betBox.Text) or 100, 10, 10000)
end

local function setBetM(v)
	betBox.Text = tostring(math.clamp(math.floor(v), 10, 10000))
end

local function stepBetM(dir)
	local cur = getBetM()
	local idx = 1
	for i, s in ipairs(STEPS_M) do
		if s <= cur then
			idx = i
		end
	end
	idx = math.clamp(idx + dir, 1, #STEPS_M)
	setBetM(STEPS_M[idx])
end

minusBtn.MouseButton1Click:Connect(function()
	if not inRound then
		stepBetM(-1)
	end
end)
plusBtn.MouseButton1Click:Connect(function()
	if not inRound then
		stepBetM(1)
	end
end)

local function clearGrid()
	for _, b in ipairs(cellBtns) do
		b:Destroy()
	end
	cellBtns = {}
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") and c.Name ~= "UICorner" and c.Name ~= "UIStroke" then
			c:Destroy()
		end
	end
end

local function buildGrid(cells, size)
	clearGrid()
	local gap = 0.02
	local cell = (1 - gap * (size + 1)) / size
	for i = 1, cells do
		local row = math.floor((i - 1) / size)
		local col = (i - 1) % size
		local btn = Instance.new("TextButton")
		btn.Name = "Cell" .. i
		btn.Size = UDim2.new(cell, 0, cell, 0)
		btn.Position = UDim2.new(gap + col * (cell + gap), 0, gap + row * (cell + gap), 0)
		btn.BackgroundColor3 = Color3.fromRGB(40, 70, 140)
		btn.Text = "?"
		btn.Font = Enum.Font.GothamBlack
		btn.TextScaled = true
		btn.TextColor3 = Color3.fromRGB(200, 220, 255)
		btn.BorderSizePixel = 0
		btn.ZIndex = 12
		btn.Parent = grid
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 10)
		cc.Parent = btn
		btn.MouseButton1Click:Connect(function()
			if not inRound or isMinesBusy then
				return
			end
			if btn:GetAttribute("Opened") then
				return
			end
			isMinesBusy = true
			revealMines:FireServer(i)
		end)
		cellBtns[i] = btn
	end
end

local function setSize(n)
	if inRound then
		return
	end
	sizeN = n
	infoLbl.Text = "Bombs: " .. tostring(BOMBS_FOR[n] or 1)
	for _, child in ipairs(sizeRow:GetChildren()) do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = if child.Name == ("Size" .. n) then Color3.fromRGB(80, 220, 255) else Color3.fromRGB(48, 92, 180)
		end
	end
	buildGrid(n * n, n)
end
sizeRow.Size3.MouseButton1Click:Connect(function()
	setSize(3)
end)
sizeRow.Size4.MouseButton1Click:Connect(function()
	setSize(4)
end)
sizeRow.Size5.MouseButton1Click:Connect(function()
	setSize(5)
end)

local function resetLobby()
	inRound = false
	minesRoundActive = false
	isMinesBusy = false
	multLbl.Text = "1.00x"
	collectPulse.Scale = 1
	startBtn.Text = "START"
	startBtn.Visible = true
	if winDisplay then
		winDisplay.Visible = false
	end
	buildGrid(sizeN * sizeN, sizeN)
end
setSize(3)
resetLobby()

-- StartBtn doubles as Collect once a round is active
startBtn.MouseButton1Click:Connect(function()
	if not inRound then
		local bet = getBetM()
		if cachedCoins < bet then
			if winDisplay then
				winDisplay.Visible = true
			end
			setResultError(winDisplay, minesCoinsLbl, minesMultLbl, "Not enough Coins")
			return
		end
		isMinesBusy = true
		fireSpinState("start", nil)
		startMines:FireServer(bet, sizeN)
	else
		isMinesBusy = true
		collectMines:FireServer()
	end
end)

local function shakeGrid()
	local base = grid.Position
	for _ = 1, 6 do
		grid.Position = base + UDim2.new(0, math.random(-6, 6), 0, math.random(-4, 4))
		task.wait(0.03)
	end
	grid.Position = base
end

minesUpdate.OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "started" then
		inRound = true
		minesRoundActive = true
		isMinesBusy = false
		setAllCoins(data.coins or cachedCoins)
		multLbl.Text = "1.00x"
		infoLbl.Text = "Bombs: " .. tostring(data.bombs or 1)
		buildGrid(data.cells or (sizeN * sizeN), data.size or sizeN)
		startBtn.Text = "COLLECT"
		if winDisplay then
			winDisplay.Visible = false
		end
		return
	end
	if kind == "safe" then
		local cell = data.cell
		local btn = cellBtns[cell]
		if btn then
			btn:SetAttribute("Opened", true)
			btn.Text = "💎"
			btn.BackgroundColor3 = Color3.fromRGB(60, 180, 220)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			local sc = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			sc.Parent = btn
			sc.Scale = 0.7
			TweenSvc:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		local mult = data.mult or 1
		multLbl.Text = string.format("%.2fx", mult)
		collectPulse.Scale = math.clamp(1 + (mult - 1) * 0.08, 1, 1.2)
		pcall(function()
			sndCommon:Play()
		end)
		isMinesBusy = false
		return
	end
	if kind == "bomb" then
		local bombs = data.bombs or {}
		for _, bi in ipairs(bombs) do
			local btn = cellBtns[bi]
			if btn then
				btn.Text = "💣"
				btn.BackgroundColor3 = Color3.fromRGB(160, 40, 50)
			end
		end
		if data.cell and cellBtns[data.cell] then
			cellBtns[data.cell].Text = "💣"
		end
		setResultOutcome(winDisplay, minesCoinsLbl, minesMultLbl, 0, 0, getBetM())
		if winDisplay then
			winDisplay.Visible = true
		end
		pcall(function()
			sndBad:Play()
		end)
		task.spawn(shakeGrid)
		setAllCoins(data.coins or cachedCoins)
		fireSpinState("stop", "bad")
		inRound = false
		minesRoundActive = false
		isMinesBusy = false
		startBtn.Text = "START"
		task.delay(1.2, function()
			if not inRound then
				resetLobby()
			end
		end)
		return
	end
	if kind == "collected" then
		local pay = data.payout or 0
		local mult = data.mult or 1
		local bet = data.bet or getBetM()
		if winDisplay then
			winDisplay.Visible = true
		end
		setResultOutcome(winDisplay, minesCoinsLbl, minesMultLbl, pay, mult, bet)
		if pay >= (bet * 2) then
			pcall(function()
				sndLegend:Play()
			end)
			fireSpinState("stop", "jackpot")
		else
			pcall(function()
				sndEpic:Play()
			end)
			fireSpinState("stop", "mid")
		end
		setAllCoins(data.coins or cachedCoins)
		inRound = false
		minesRoundActive = false
		isMinesBusy = false
		startBtn.Text = "START"
		task.delay(0.9, function()
			if not inRound then
				resetLobby()
			end
		end)
		return
	end
	if kind == "error" then
		if winDisplay then
			winDisplay.Visible = true
		end
		setResultError(winDisplay, minesCoinsLbl, minesMultLbl, data.msg or "Error")
		if data.coins then
			setAllCoins(data.coins)
		end
		isMinesBusy = false
		fireSpinState("stop", nil)
	end
end)
end
initMines()

task.spawn(function()
    task.wait(0.5)
    refreshCoinsFromServer()
end)

print('[ShopUI] loaded')