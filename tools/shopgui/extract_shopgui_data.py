import re
from pathlib import Path

src = Path(r"C:\Users\Luc Klein\.cursor\projects\c-Users-Luc-Klein-Documents-GitHub-DrawForSlots\agent-tools\44811db0-639c-43a5-8ff1-3909cc90db07.txt")
out = Path(r"C:\Users\Luc Klein\Documents\GitHub\DrawForSlots\src\ReplicatedStorage\ShopGuiData.luau")
raw = src.read_text(encoding="utf-8")
m = re.match(r"return \=\=\[(.*)\]\=\]", raw, re.S)
if not m:
    raise SystemExit("JSON wrapper not found")
json_text = m.group(1)
out.write_text("return [=[" + json_text + "]=]\n", encoding="utf-8")
print(f"Wrote {out.stat().st_size} bytes")
