from pathlib import Path

path = Path(r"C:\Users\Luc Klein\Documents\GitHub\DrawForSlots\src\StarterPlayer\StarterPlayerScripts\ShopUI.client.luau")
text = path.read_text(encoding="utf-8")

setup = """
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

local sndCommon   = RS.Sounds.RewardBasic
local sndEpic     = RS.Sounds.RewardMid
local sndLegend   = RS.Sounds.Jackpot
local sndBad      = RS.Sounds.RewardBad
local WIN_SOUNDS  = {Common=sndCommon,Uncommon=sndCommon,Epic=sndEpic,Mythic=sndEpic,Legendary=sndLegend}

local spinStateSignal = nil
task.spawn(function()
\tlocal signals = RS:WaitForChild("ShopSignals", 10)
\tif not signals then return end
\tspinStateSignal = signals:WaitForChild("SpinStateChanged", 5)
end)
local function fireSpinState(state, sound)
\tif spinStateSignal then
\t\tspinStateSignal:Fire(state, sound)
\tend
end

local isSpinning=false; local isSpinning2=false; local isP3=false
local menuOpen=false

for _,obj in ipairs(card:GetDescendants()) do
\tif obj.Name == "TileSweep" then
\t\tobj:Destroy()
\tend
end

do
\tlocal hud = pGui:FindFirstChild("CoinHUDGui")
\tif hud then hud:Destroy() end
end

local function getLobbyCoinLabel()
\tlocal sgMain = pGui:FindFirstChild('HyperSketchGui')
\tif not sgMain then return nil end
\tlocal lobbyCard = sgMain:FindFirstChild('LobbyFrame') and sgMain.LobbyFrame:FindFirstChild('PlayerCard')
\treturn lobbyCard and lobbyCard:FindFirstChild('CoinLabel')
end

local function forceCloseGui()
\tmenuOpen = false
\tsg.Enabled = false
\toverlay.BackgroundTransparency = 1
\toverlay.Active = false
\tcoinBadge.Visible = false
\tinnerCoinLbl.Visible = false
\tlocal lobbyCoin = getLobbyCoinLabel()
\tif lobbyCoin then
\t\tlocal base = pGui:FindFirstChild('Base')
\t\tlocal dailyBusy = base and base:GetAttribute('DailyRewardBusy') == true
\t\tlocal dailyPanel = base and base:FindFirstChild('DailyReward')
\t\tlocal dailyOpen = dailyBusy or (dailyPanel ~= nil and dailyPanel.Visible)
\t\tif not dailyOpen then
\t\t\tlobbyCoin.Visible = true
\t\tend
\tend
end
forceCloseGui()
card.BackgroundTransparency = 0
csw.Visible = false

"""

anchor = "local CASINO_MIN_SIZE = Vector2.new(320, 240)\n\nlocal THEME"
if anchor not in text:
    raise SystemExit("anchor missing")
text = text.replace(anchor, "local CASINO_MIN_SIZE = Vector2.new(320, 240)\n" + setup + "\nlocal THEME", 1)

orphan_start = text.find("applyQueueTheme()\n    overlay.BackgroundColor3")
orphan_end = text.find("\n-- Snapshot pristine transparencies once")
if orphan_start == -1 or orphan_end == -1:
    raise SystemExit(f"orphan block missing start={orphan_start} end={orphan_end}")
# keep first applyQueueTheme() call, drop duplicate theme body
first_call = text.rfind("applyQueueTheme()", 0, orphan_start)
text = text[: first_call + len("applyQueueTheme()")] + text[orphan_end:]

path.write_text(text, encoding="utf-8")
print("ok", len(text.splitlines()), "lines")
