-- Colorful clean casino theme: dim stage, raised blue game panels
local CasinoUiTheme = {}

CasinoUiTheme.THEME = {
	BG = Color3.fromRGB(0, 0, 0),
	OVERLAY_T = 0,
	CARD = Color3.fromRGB(16, 28, 62),
	GAME_BG = Color3.fromRGB(30, 88, 190),
	PANEL = Color3.fromRGB(48, 92, 180),
	PANEL_DARK = Color3.fromRGB(28, 42, 82),
	STROKE = Color3.fromRGB(90, 210, 255),
	ACCENT = Color3.fromRGB(80, 220, 255),
	ACCENT_WARM = Color3.fromRGB(255, 196, 70),
	TEXT = Color3.fromRGB(230, 238, 255),
	TITLE = Color3.fromRGB(255, 255, 255),
	GHOST = Color3.fromRGB(255, 255, 255),
	GHOST_T = 0.8,
	GHOST_TEXT = Color3.fromRGB(235, 240, 255),
	CORNER = 16,
	STROKE_W = 2,
	BUSY = Color3.fromRGB(40, 55, 100),
	TILE_SLOTS1 = Color3.fromRGB(255, 158, 48),
	TILE_SLOTS2 = Color3.fromRGB(150, 100, 255),
	TILE_PLINKO = Color3.fromRGB(48, 210, 150),
	TILE_WHEEL = Color3.fromRGB(255, 90, 120),
	TILE_MINES = Color3.fromRGB(70, 180, 255),
	TEXT_MIN = 16,
	TEXT_MAX = 26,
	TITLE_MIN = 22,
	TITLE_MAX = 40,
	BTN_MIN = 16,
	BTN_MAX = 28,
	RESULT_BG = Color3.fromRGB(12, 18, 40),
	RESULT_WIN_BG = Color3.fromRGB(16, 58, 40),
	RESULT_LOSS_BG = Color3.fromRGB(58, 16, 28),
	RESULT_WIN = Color3.fromRGB(90, 255, 140),
	RESULT_LOSS = Color3.fromRGB(255, 105, 105),
	RESULT_WIN_STROKE = Color3.fromRGB(70, 220, 130),
	RESULT_LOSS_STROKE = Color3.fromRGB(255, 110, 120),
}

local THEME = CasinoUiTheme.THEME

local function ensureCorner(obj, radius)
	local c = obj:FindFirstChildOfClass("UICorner")
	if not c then
		c = Instance.new("UICorner")
		c.Parent = obj
	end
	c.CornerRadius = UDim.new(0, radius)
	return c
end

local function ensureStroke(obj, color, thickness)
	local s = obj:FindFirstChildOfClass("UIStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Parent = obj
	end
	s.Color = color
	s.Thickness = thickness or THEME.STROKE_W
	s.Transparency = 0
	return s
end

function CasinoUiTheme.fitText(obj, minSize, maxSize)
	if not obj or not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		return
	end
	obj.TextScaled = true
	obj.TextWrapped = false
	local c = obj:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c.Parent = obj
	end
	c.MinTextSize = minSize or THEME.TEXT_MIN
	c.MaxTextSize = maxSize or THEME.TEXT_MAX
	return c
end

function CasinoUiTheme.styleGhostBtn(btn)
	if not btn or not btn:IsA("GuiButton") then
		return
	end
	btn.BackgroundColor3 = THEME.GHOST
	btn.BackgroundTransparency = THEME.GHOST_T
	btn.TextColor3 = THEME.GHOST_TEXT
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.Gotham
	CasinoUiTheme.fitText(btn, THEME.BTN_MIN, THEME.BTN_MAX)
	ensureCorner(btn, 12)
	ensureStroke(btn, THEME.STROKE, 1.5)
end

function CasinoUiTheme.stylePrimaryBtn(btn)
	if not btn or not btn:IsA("GuiButton") then
		return
	end
	btn.BackgroundColor3 = THEME.ACCENT_WARM
	btn.BackgroundTransparency = 0
	btn.TextColor3 = Color3.fromRGB(30, 22, 10)
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBlack
	CasinoUiTheme.fitText(btn, 20, 42)
	ensureCorner(btn, THEME.CORNER)
	ensureStroke(btn, Color3.fromRGB(255, 230, 140), THEME.STROKE_W)
	local grad = btn:FindFirstChildOfClass("UIGradient")
	if not grad then
		grad = Instance.new("UIGradient")
		grad.Parent = btn
	end
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 165, 55)),
	})
	grad.Rotation = 90
end

function CasinoUiTheme.stylePanel(frame, corner)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	frame.BackgroundColor3 = THEME.PANEL
	frame.BackgroundTransparency = 0
	ensureCorner(frame, corner or THEME.CORNER)
	ensureStroke(frame, THEME.STROKE, THEME.STROKE_W)
end

function CasinoUiTheme.styleTitle(lbl)
	if not lbl or not lbl:IsA("TextLabel") then
		return
	end
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = THEME.TITLE
	lbl.Font = Enum.Font.GothamBlack
	CasinoUiTheme.fitText(lbl, THEME.TITLE_MIN, THEME.TITLE_MAX)
end

-- Title row shares Y with close X
function CasinoUiTheme.ensureGameTitle(page: Frame, text: string)
	if not page then
		return nil
	end
	local title = page:FindFirstChild("Title")
	if not title then
		title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Parent = page
	end
	if title:IsA("TextLabel") then
		title.Text = text
		title.Visible = true
		title.ZIndex = 55
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0.025, 0)
		title.Size = UDim2.new(0.7, 0, 0.06, 0)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.TextYAlignment = Enum.TextYAlignment.Center
		CasinoUiTheme.styleTitle(title)
	end
	return title
end

local function styleResultLabel(lbl, minSize, maxSize, font)
	if not lbl or not (lbl:IsA("TextLabel") or lbl:IsA("TextButton")) then
		return
	end
	lbl.BackgroundTransparency = 1
	lbl.TextWrapped = false
	lbl.Font = font or Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	CasinoUiTheme.fitText(lbl, minSize, maxSize)
	local stroke = lbl:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = lbl
	end
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.15
end

function CasinoUiTheme.layoutResultLabels(coinLbl, multLbl)
	if coinLbl and coinLbl:IsA("GuiObject") then
		coinLbl.Size = UDim2.new(1, -12, 0.52, 0)
		coinLbl.Position = UDim2.new(0.5, 0, 0.06, 0)
		coinLbl.AnchorPoint = Vector2.new(0.5, 0)
		coinLbl.Visible = true
		styleResultLabel(coinLbl, 14, 26, Enum.Font.GothamBlack)
	end
	if multLbl and multLbl:IsA("GuiObject") then
		multLbl.Size = UDim2.new(1, -12, 0.36, 0)
		multLbl.Position = UDim2.new(0.5, 0, 0.94, 0)
		multLbl.AnchorPoint = Vector2.new(0.5, 1)
		multLbl.Visible = true
		styleResultLabel(multLbl, 12, 20, Enum.Font.GothamBold)
	end
end

function CasinoUiTheme.ensureResultLabels(frame, coinName, multName)
	if not frame or not frame:IsA("GuiObject") then
		return nil, nil
	end
	local cName = coinName or "CoinsLbl"
	local mName = multName or "MultLbl"
	local coinLbl = frame:FindFirstChild(cName)
	local multLbl = frame:FindFirstChild(mName)
	if not coinLbl then
		coinLbl = Instance.new("TextLabel")
		coinLbl.Name = cName
		coinLbl.BackgroundTransparency = 1
		coinLbl.Text = ""
		coinLbl.ZIndex = (frame.ZIndex or 1) + 1
		coinLbl.Parent = frame
	end
	if not multLbl then
		multLbl = Instance.new("TextLabel")
		multLbl.Name = mName
		multLbl.BackgroundTransparency = 1
		multLbl.Text = ""
		multLbl.ZIndex = (frame.ZIndex or 1) + 1
		multLbl.Parent = frame
	end
	CasinoUiTheme.layoutResultLabels(coinLbl, multLbl)
	return coinLbl, multLbl
end

function CasinoUiTheme.styleResultBox(frame, labels)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	frame.BackgroundColor3 = THEME.RESULT_BG
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	ensureCorner(frame, 12)
	ensureStroke(frame, THEME.STROKE, THEME.STROKE_W)
	local list = labels or {}
	if #list >= 2 then
		CasinoUiTheme.layoutResultLabels(list[1], list[2])
	else
		for _, lbl in ipairs(list) do
			styleResultLabel(lbl, 14, 24, Enum.Font.GothamBold)
		end
	end
end

function CasinoUiTheme.setResultContrast(lbl, accent: Color3?)
	if not lbl or not (lbl:IsA("TextLabel") or lbl:IsA("TextButton")) then
		return
	end
	local col = accent or THEME.TITLE
	local lum = col.R * 0.3 + col.G * 0.59 + col.B * 0.11
	if lum < 0.45 then
		lbl.TextColor3 = Color3.fromRGB(255, 245, 250)
	else
		lbl.TextColor3 = col
	end
	local stroke = lbl:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = lbl
	end
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.15
end

local function paintResultBox(frame, isWin)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	local bg = if isWin then THEME.RESULT_WIN_BG else THEME.RESULT_LOSS_BG
	local strokeCol = if isWin then THEME.RESULT_WIN_STROKE else THEME.RESULT_LOSS_STROKE
	local textCol = if isWin then THEME.RESULT_WIN else THEME.RESULT_LOSS
	frame.BackgroundColor3 = bg
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = strokeCol
		stroke.Thickness = THEME.STROKE_W
		stroke.Transparency = 0
	end
	return textCol
end

function CasinoUiTheme.setResultOutcome(frame, coinLbl, multLbl, coinsWon, multSum, betSpent)
	local payout = math.max(0, math.floor(tonumber(coinsWon) or 0))
	local bet = math.max(0, math.floor(tonumber(betSpent) or 0))
	local mult = tonumber(multSum) or 0
	local isWin = payout > 0 and payout >= bet
	local textCol = paintResultBox(frame, isWin)
	CasinoUiTheme.layoutResultLabels(coinLbl, multLbl)
	if coinLbl and (coinLbl:IsA("TextLabel") or coinLbl:IsA("TextButton")) then
		coinLbl.Text = if payout > 0 then ("+" .. tostring(payout) .. " Coins") else "0 Coins"
		coinLbl.TextColor3 = textCol
		CasinoUiTheme.setResultContrast(coinLbl, textCol)
	end
	if multLbl and (multLbl:IsA("TextLabel") or multLbl:IsA("TextButton")) then
		multLbl.Text = string.format("%.2fx", mult)
		multLbl.TextColor3 = textCol
		CasinoUiTheme.setResultContrast(multLbl, textCol)
	end
end

function CasinoUiTheme.setResultError(frame, coinLbl, multLbl, msg)
	local textCol = paintResultBox(frame, false)
	CasinoUiTheme.layoutResultLabels(coinLbl, multLbl)
	if coinLbl and (coinLbl:IsA("TextLabel") or coinLbl:IsA("TextButton")) then
		coinLbl.Text = msg or "Error"
		coinLbl.TextColor3 = textCol
		CasinoUiTheme.setResultContrast(coinLbl, textCol)
	end
	if multLbl and (multLbl:IsA("TextLabel") or multLbl:IsA("TextButton")) then
		multLbl.Text = ""
		multLbl.Visible = false
	end
end

function CasinoUiTheme.styleSubtext(lbl)
	if not lbl or not lbl:IsA("TextLabel") then
		return
	end
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = THEME.TEXT
	lbl.Font = Enum.Font.GothamBold
	CasinoUiTheme.fitText(lbl, THEME.TEXT_MIN, THEME.TEXT_MAX)
end

function CasinoUiTheme.styleGamePage(page)
	if not page or not page:IsA("GuiObject") then
		return
	end
	page.BackgroundColor3 = THEME.GAME_BG
	page.BackgroundTransparency = 0
	page.BorderSizePixel = 0
	ensureCorner(page, THEME.CORNER - 2)
	local grad = page:FindFirstChildOfClass("UIGradient")
	if not grad then
		grad = Instance.new("UIGradient")
		grad.Parent = page
	end
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 130, 255)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(30, 88, 190)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 54, 140)),
	})
	grad.Rotation = 135
end

function CasinoUiTheme.ensureCardShadow(card: Frame)
	local shadow = card.Parent and card.Parent:FindFirstChild("CardShadow")
	if not shadow then
		shadow = Instance.new("Frame")
		shadow.Name = "CardShadow"
		shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shadow.BackgroundTransparency = 0.5
		shadow.BorderSizePixel = 0
		shadow.ZIndex = math.max(0, (card.ZIndex or 1) - 1)
		shadow.Parent = card.Parent
		ensureCorner(shadow, THEME.CORNER + 4)
	end
	shadow.Size = UDim2.new(card.Size.X.Scale, card.Size.X.Offset + 10, card.Size.Y.Scale, card.Size.Y.Offset + 12)
	shadow.AnchorPoint = card.AnchorPoint
	shadow.Position = UDim2.new(
		card.Position.X.Scale,
		card.Position.X.Offset,
		card.Position.Y.Scale,
		card.Position.Y.Offset + 12
	)
	shadow.Visible = card.Visible
	return shadow
end

-- Force all text/panels on a page readable (fixes stuck fade leftovers)
function CasinoUiTheme.revealPage(page)
	if not page then
		return
	end
	for _, obj in ipairs(page:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			obj.TextTransparency = 0
		end
		if obj:IsA("UIStroke") then
			obj.Transparency = 0
		end
		if (obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ImageLabel"))
			and obj.BackgroundTransparency > 0.95
			and obj:GetAttribute("KeepClear") ~= true
		then
			-- leave intentionally clear frames (NameBg overlays etc. keep their values)
		end
	end
end

export type UiRefs = {
	screenGui: ScreenGui?,
	overlay: Frame,
	card: Frame,
	pages: Frame,
	closeBtn: TextButton,
	coinBadge: Frame,
	innerCoinLbl: TextLabel,
	tilesPage: Frame,
	slotsPage: Frame,
	slots2Page: Frame,
	slots3Page: Frame,
	wheelPage: Frame?,
	minesPage: Frame?,
}

function CasinoUiTheme.applyQueueTheme(ui: UiRefs)
	if ui.screenGui then
		ui.screenGui.IgnoreGuiInset = true
		ui.screenGui.DisplayOrder = 50
	end

	local oldBg = ui.card:FindFirstChild("BgPattern")
	if oldBg then
		oldBg:Destroy()
	end

	ui.overlay.BackgroundColor3 = THEME.BG
	ui.overlay.BorderSizePixel = 0
	ui.overlay.Size = UDim2.new(1, 0, 1, 0)
	ui.overlay.Position = UDim2.new(0, 0, 0, 0)
	ui.overlay.ZIndex = 0
	ui.overlay.Active = false

	ui.card.BackgroundColor3 = THEME.CARD
	ui.card.BackgroundTransparency = 0
	ui.card.ClipsDescendants = true
	ui.card.Visible = true
	ui.card.ZIndex = 10

	local cardGrad = ui.card:FindFirstChildOfClass("UIGradient")
	if not cardGrad then
		cardGrad = Instance.new("UIGradient")
		cardGrad.Parent = ui.card
	end
	cardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 44, 98)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 28, 62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 54, 120)),
	})
	cardGrad.Rotation = 120

	ensureCorner(ui.card, THEME.CORNER)
	local cardStroke = ensureStroke(ui.card, THEME.STROKE, THEME.STROKE_W + 0.5)
	if cardStroke then
		cardStroke.Name = "CardGlow"
	end

	CasinoUiTheme.ensureCardShadow(ui.card)

	ui.pages.ZIndex = 8
	ui.pages.Visible = true
	ui.pages.Size = UDim2.fromScale(1, 1)
	ui.pages.BackgroundTransparency = 1
	ui.closeBtn.Text = "X"
	ui.closeBtn.AnchorPoint = Vector2.new(1, 0)
	ui.closeBtn.Size = UDim2.new(0.065, 0, 0.06, 0)
	ui.closeBtn.Position = UDim2.new(0.975, 0, 0.025, 0)
	ui.closeBtn.ZIndex = 60
	CasinoUiTheme.styleGhostBtn(ui.closeBtn)

	CasinoUiTheme.stylePanel(ui.coinBadge, 12)
	ui.coinBadge.BackgroundColor3 = THEME.ACCENT_WARM
	ensureStroke(ui.coinBadge, Color3.fromRGB(255, 230, 140), THEME.STROKE_W)
	ui.coinBadge.BackgroundTransparency = 0
	ui.innerCoinLbl.TextColor3 = Color3.fromRGB(30, 22, 10)
	ui.innerCoinLbl.Font = Enum.Font.GothamBold
	CasinoUiTheme.fitText(ui.innerCoinLbl, THEME.TEXT_MIN, THEME.TEXT_MAX)

	-- Same pattern: blue game pages + tiles hub
	CasinoUiTheme.styleGamePage(ui.tilesPage)
	CasinoUiTheme.styleGamePage(ui.slotsPage)
	CasinoUiTheme.styleGamePage(ui.slots2Page)
	CasinoUiTheme.styleGamePage(ui.slots3Page)
	if ui.wheelPage then
		CasinoUiTheme.styleGamePage(ui.wheelPage)
	end
	if ui.minesPage then
		CasinoUiTheme.styleGamePage(ui.minesPage)
	end

	for _, page in ipairs({ ui.tilesPage, ui.slotsPage, ui.slots2Page, ui.slots3Page, ui.wheelPage, ui.minesPage }) do
		if page then
			local back = page:FindFirstChild("BackBtn")
			if back then
				back:Destroy()
			end
		end
	end

	local divider = ui.tilesPage:FindFirstChild("Divider")
	if divider and divider:IsA("GuiObject") then
		divider.BackgroundColor3 = THEME.ACCENT
		divider.BackgroundTransparency = 0.1
	end

	CasinoUiTheme.styleTitle(ui.tilesPage:FindFirstChild("ShopTitle"))
	CasinoUiTheme.ensureGameTitle(ui.slotsPage, "One-Row Slots")
	CasinoUiTheme.ensureGameTitle(ui.slots2Page, "5-Reel Slots")
	CasinoUiTheme.ensureGameTitle(ui.slots3Page, "Plinko")
	if ui.wheelPage then
		CasinoUiTheme.ensureGameTitle(ui.wheelPage, "Lucky Wheel")
	end
	if ui.minesPage then
		CasinoUiTheme.ensureGameTitle(ui.minesPage, "Diamond Mines")
	end
	CasinoUiTheme.stylePanel(ui.slotsPage:FindFirstChild("StripOuter"), THEME.CORNER)
	do
		local rb = ui.slotsPage:FindFirstChild("ResultBg")
		if rb then
			local old = rb:FindFirstChild("ResultLbl")
			if old and not rb:FindFirstChild("CoinsLbl") then
				old.Name = "CoinsLbl"
			end
			CasinoUiTheme.styleResultBox(rb, {
				rb:FindFirstChild("CoinsLbl") or rb:FindFirstChild("ResultLbl"),
				rb:FindFirstChild("MultLbl"),
			})
		end
	end
	CasinoUiTheme.stylePrimaryBtn(ui.slotsPage:FindFirstChild("SpinBtn"))
	local betRow1 = ui.slotsPage:FindFirstChild("BetRow")
	if betRow1 then
		for _, btn in ipairs(betRow1:GetChildren()) do
			if btn:IsA("TextButton") then
				CasinoUiTheme.styleGhostBtn(btn)
			end
		end
		local betInput = betRow1:FindFirstChild("BetInput")
		if betInput then
			betInput.BackgroundColor3 = THEME.PANEL_DARK
			betInput.BackgroundTransparency = 0
			betInput.TextColor3 = THEME.TITLE
			ensureCorner(betInput, 12)
			ensureStroke(betInput, THEME.STROKE, 1.5)
			CasinoUiTheme.fitText(betInput, THEME.TEXT_MIN, THEME.TEXT_MAX)
		end
	end

	CasinoUiTheme.stylePanel(ui.slots2Page:FindFirstChild("ReelFrame"), THEME.CORNER)
	local bar2 = ui.slots2Page:FindFirstChild("BottomBar")
	if bar2 then
		local winSec = bar2:FindFirstChild("WinSection")
		CasinoUiTheme.stylePanel(winSec, 12)
		local res2 = winSec and winSec:FindFirstChild("ResultBg")
		if res2 then
			CasinoUiTheme.styleResultBox(res2, {
				res2:FindFirstChild("ResultAmountLabel"),
				res2:FindFirstChild("ResultSymLabel"),
			})
		end
		CasinoUiTheme.stylePrimaryBtn(bar2:FindFirstChild("SpinBtn"))
		local betSec = bar2:FindFirstChild("BetSection")
		if betSec then
			for _, btn in ipairs(betSec:GetChildren()) do
				if btn:IsA("TextButton") then
					CasinoUiTheme.styleGhostBtn(btn)
				end
			end
			local bet2 = betSec:FindFirstChild("BetInput")
			if bet2 then
				bet2.BackgroundColor3 = THEME.PANEL_DARK
				bet2.BackgroundTransparency = 0
				bet2.TextColor3 = THEME.TITLE
				ensureCorner(bet2, 12)
				ensureStroke(bet2, THEME.STROKE, 1.5)
				CasinoUiTheme.fitText(bet2, THEME.TEXT_MIN, THEME.TEXT_MAX)
			end
		end
	end

	local lp = ui.slots3Page:FindFirstChild("LeftPanel")
	if lp then
		CasinoUiTheme.stylePanel(lp:FindFirstChild("BetBox"), THEME.CORNER)
		local winDisp = lp:FindFirstChild("WinDisplay")
		CasinoUiTheme.styleResultBox(winDisp, {
			winDisp and winDisp:FindFirstChild("NetLabel"),
			winDisp and winDisp:FindFirstChild("MultsLabel"),
		})
		local betBox = lp:FindFirstChild("BetBox")
		if betBox then
			CasinoUiTheme.stylePrimaryBtn(betBox:FindFirstChild("BetBtn"))
			for _, row in ipairs(betBox:GetChildren()) do
				local controls = row:FindFirstChild("Controls")
				if controls then
					for _, btn in ipairs(controls:GetChildren()) do
						if btn:IsA("TextButton") then
							CasinoUiTheme.styleGhostBtn(btn)
						end
					end
				end
			end
		end
	end
	CasinoUiTheme.stylePanel(ui.slots3Page:FindFirstChild("BoardFrame"), THEME.CORNER)

	local tileColors = {
		Slots1Tile = THEME.TILE_SLOTS1,
		Slots2Tile = THEME.TILE_SLOTS2,
		Slots3Tile = THEME.TILE_PLINKO,
		WheelTile = THEME.TILE_WHEEL,
		MinesTile = THEME.TILE_MINES,
	}
	local tileRow = ui.tilesPage:FindFirstChild("TileRow")
	if tileRow then
		for _, tile in ipairs(tileRow:GetChildren()) do
			if tile:IsA("TextButton") then
				local col = tileColors[tile.Name] or THEME.PANEL
				tile.BackgroundColor3 = col
				tile.BackgroundTransparency = 0
				ensureCorner(tile, THEME.CORNER)
				local stroke = tile:FindFirstChild("NeonStroke") or tile:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = Color3.new(1, 1, 1)
					stroke.Thickness = 2
					stroke.Transparency = 0.3
				else
					ensureStroke(tile, Color3.new(1, 1, 1), 2)
				end
				local grad = tile:FindFirstChildOfClass("UIGradient")
				if not grad then
					grad = Instance.new("UIGradient")
					grad.Parent = tile
				end
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
				})
				grad.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(1, 0.4),
				})
				grad.Rotation = 110
				CasinoUiTheme.styleSubtext(tile:FindFirstChild("NameLabel", true))
				local nameBg = tile:FindFirstChild("NameBg")
				if nameBg and nameBg:IsA("GuiObject") then
					nameBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					nameBg.BackgroundTransparency = 0.4
				end
			end
		end
	end
end

return CasinoUiTheme
