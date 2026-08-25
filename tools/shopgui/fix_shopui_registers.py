from pathlib import Path

path = Path(r"C:\Users\Luc Klein\Documents\GitHub\DrawForSlots\src\StarterPlayer\StarterPlayerScripts\ShopUI.client.luau")
text = path.read_text(encoding="utf-8")

needle = "local SoundController=require(RS.Modules.SoundController)"
repl = needle + "\nlocal CasinoUiTheme=require(RS.Modules.CasinoUiTheme)"
if needle not in text:
    raise SystemExit("require anchor missing")
text = text.replace(needle, repl, 1)

start = text.index("local THEME = {")
end = text.index("applyQueueTheme()", start) + len("applyQueueTheme()")
text = (
    text[:start]
    + """local THEME = CasinoUiTheme.THEME
local styleGhostBtn = CasinoUiTheme.styleGhostBtn
local stylePrimaryBtn = CasinoUiTheme.stylePrimaryBtn
local stylePanel = CasinoUiTheme.stylePanel
local styleTitle = CasinoUiTheme.styleTitle
local styleSubtext = CasinoUiTheme.styleSubtext
local function applyQueueTheme()
\tCasinoUiTheme.applyQueueTheme({
\t\toverlay = overlay,
\t\tcard = card,
\t\tpages = pages,
\t\tcloseBtn = closeBtn,
\t\tcoinBadge = coinBadge,
\t\tinnerCoinLbl = innerCoinLbl,
\t\ttilesPage = tilesPage,
\t\tslotsPage = slotsPage,
\t\tslots2Page = slots2Page,
\t\tslots3Page = slots3Page,
\t})
end
applyQueueTheme()"""
    + text[end:]
)

dup_start = text.find("local function ensureCorner")
snap = text.find("-- Snapshot pristine")
if dup_start != -1 and dup_start < snap:
    text = text[:dup_start] + text[snap:]

marker = "-- ════════════════════════════════════════════\n-- SLOTS 1 PAGE"
hook = "local plinkoLayoutHook: (() -> ())? = nil\n\nlocal function initSlots1()\n"
text = text.replace(marker, hook + marker, 1)

s2 = "-- ════════════════════════════════════════════\n-- SLOTS 2 PAGE"
s3 = "-- ════════════════════════════════════════════\n-- SLOTS 3 PAGE"
refresh = "task.spawn(function()\n    task.wait(0.5)\n    refreshCoinsFromServer()\nend)"
wire = "-- ── Lobby casino game dummies"

text = text.replace("\n" + s2, "\nend\ninitSlots1()\n\nlocal function initSlots2()\n" + s2, 1)
text = text.replace("\n" + s3, "\nend\ninitSlots2()\n\nlocal function initPlinko()\n" + s3, 1)
text = text.replace(
    "\n" + refresh,
    "\n\tplinkoLayoutHook = function()\n\t\tif bb3done then\n\t\t\tbldBoard3()\n\t\tend\n\tend\nend\ninitPlinko()\n\n"
    + refresh,
    1,
)

text = text.replace(
    "if slots3Page.Visible and bb3done then\n        task.defer(bldBoard3)\n    end",
    "if slots3Page.Visible and plinkoLayoutHook then\n        task.defer(plinkoLayoutHook)\n    end",
)

if wire in text:
    wire_start = text.index(wire)
    print_end = text.rfind("print('[ShopUI] loaded')")
    text = (
        text[:wire_start]
        + """local function exposeOpenUI()
\tlocal signals = RS:FindFirstChild("ShopSignals")
\tif not signals then
\t\treturn
\tend
\tlocal openEv = signals:FindFirstChild("RequestOpenUI")
\tif not openEv then
\t\topenEv = Instance.new("BindableEvent")
\t\topenEv.Name = "RequestOpenUI"
\t\topenEv.Parent = signals
\tend
\topenEv.Event:Connect(function(pageName)
\t\tOpenUI(pageName)
\tend)
end
exposeOpenUI()

"""
        + text[print_end:]
    )

path.write_text(text, encoding="utf-8")
print("ok", len(text.splitlines()), "lines")
