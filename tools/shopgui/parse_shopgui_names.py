import re
from pathlib import Path

t = Path(r"C:\Users\Luc Klein\Documents\GitHub\DrawForSlots\src\ReplicatedStorage\ShopGuiData1.luau").read_text(encoding="utf-8")
names = re.findall(r'"n":"([^"]+)"', t)
for n in names:
    print(n)
