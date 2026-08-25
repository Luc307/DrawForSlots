import re
from pathlib import Path

src = Path(r"C:\Users\Luc Klein\.cursor\projects\c-Users-Luc-Klein-Documents-GitHub-DrawForSlots\agent-tools\cf893873-d4b6-43c4-8598-ce2ff6972c2b.txt")
out = Path(r"C:\Users\Luc Klein\Documents\GitHub\DrawForSlots\src\StarterPlayer\StarterPlayerScripts\ShopUI.client.luau")

lines = []
for raw in src.read_text(encoding="utf-8").splitlines():
    m = re.match(r"^\s*\d+→(.*)$", raw)
    lines.append(m.group(1) if m else raw)
text = "\n".join(lines)

old_remotes = """local RemotesFolder = RS:WaitForChild('Remotes')
local Events = RemotesFolder:WaitForChild('Events')
local Functions = RemotesFolder:WaitForChild('Functions')
local DataEvent = Events:WaitForChild('Data')
local DataFunction = Functions:WaitForChild('Data')"""
text = text.replace(old_remotes, "local Remotes = RS:WaitForChild('Remotes')")
text = text.replace("Events:WaitForChild(", "Remotes:WaitForChild(")
text = text.replace(
    "local ok, coins = pcall(function() return DataFunction:InvokeServer('Coins') end)",
    "local ok, coins = pcall(function() return Remotes:WaitForChild('GetCoins'):InvokeServer() end)",
)

text = re.sub(
    r"-- ── Live coin sync via Paddle Data remote ─────────────────\nDataEvent\.OnClientEvent:Connect\(function\(key, value\).*?end\)\n",
    "",
    text,
    flags=re.S,
)

text = re.sub(
    r"-- Paddle already has Base\.Coins — remove casino CoinHUD entirely\ndo\n    local hud = pGui:FindFirstChild\('CoinHUDGui'\)\n    if hud then hud:Destroy\(\) end\nend\n\n",
    "",
    text,
)

coin_helpers = """local function getLobbyCoinLabel()
    local sgMain = pGui:FindFirstChild('DrawForSlotsGui')
    if not sgMain then return nil end
    local card = sgMain:FindFirstChild('LobbyFrame') and sgMain.LobbyFrame:FindFirstChild('PlayerCard')
    return card and card:FindFirstChild('CoinLabel')
end
"""
text = re.sub(
    r"local function getBaseCoinFrame\(\).*?local function getBaseCoinLabel\(\).*?return frame and frame:FindFirstChild\('TextLabel'\)\nend\n",
    coin_helpers,
    text,
    flags=re.S,
)
text = text.replace("getBaseCoinLabel()", "getLobbyCoinLabel()")
text = text.replace("getBaseCoinFrame()", "getLobbyCoinLabel()")
text = text.replace("local baseCoins = getLobbyCoinLabel()", "local lobbyCoin = getLobbyCoinLabel()")
text = text.replace("if baseCoins then", "if lobbyCoin then")
text = text.replace("baseCoins.Visible", "lobbyCoin.Visible")
text = text.replace(
    "if bl then bl.Text = 'Coins: ' .. tostring(cachedCoins) end",
    'if bl then bl.Text = tostring(cachedCoins) .. " Coins" end',
)

text = text.replace("if player:GetAttribute('IntroComplete') ~= true then return end", "")
text = text.replace(
    "local lobby = Workspace:WaitForChild('Lobby', 30)",
    "local lobby = Workspace:WaitForChild('Floating Lobby', 30)",
)
text = re.sub(
    r"player:GetAttributeChangedSignal\('IntroComplete'\):Connect\(function\(\)\n    if player:GetAttribute\('IntroComplete'\) == true then\n        forceCloseGui\(\)\n    end\nend\)\n",
    "",
    text,
)
text = text.replace("-- Only after lobby intro finishes\n    ", "")
text = text.replace("-- ── Coin helpers (Paddle Base.Coins + optional CoinHUD) ──", "-- Coin helpers")

text = text.replace(
    "local base = pGui:FindFirstChild('Base')\n        local dailyBusy = base and base:GetAttribute('DailyRewardBusy') == true\n        local dailyPanel = base and base:FindFirstChild('DailyReward')\n        local dailyOpen = dailyBusy or (dailyPanel ~= nil and dailyPanel.Visible)\n        -- Avoid double labels: Base HUD when closed, shop badge when open\n        baseCoins.Visible = (not open) and (not dailyOpen)",
    "lobbyCoin.Visible = not open",
)
text = re.sub(
    r"    local base = pGui:FindFirstChild\('Base'\)\n    local dailyBusy = base and base:GetAttribute\('DailyRewardBusy'\) == true\n    local dailyPanel = base:FindFirstChild\('DailyReward'\)\n    local dailyOpen = dailyBusy or \(dailyPanel ~= nil and dailyPanel\.Visible\)\n    if not dailyOpen then\n        baseCoins\.Visible = true\n    end",
    "",
    text,
)

out.write_text(text, encoding="utf-8")
print(f"Wrote {out.stat().st_size} bytes")
