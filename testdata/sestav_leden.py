"""Obnoví zkušební odpovědi ve web/leden-2027.html z testdata/zkusebni_odpovedi.json.

Stránka (rozdělení, dražba, varianty 4h/3h, nejkratší/nejdelší rezervace) se dál upravuje přímo
v web/leden-2027.html; tento skript v ní jen přepíše řádek `const ODPOVEDI=…`.
Spuštění:  py -I sestav_leden.py   (po py -I generuj_zkusebni.py)
"""
import json
from pathlib import Path

D = Path(__file__).parent
STRANKA = D.parent / "web" / "leden-2027.html"
DNY = ["Po", "Ut", "St", "Ct", "Pa"]

data = json.loads((D / "zkusebni_odpovedi.json").read_text(encoding="utf-8"))
H = [{"j": o["jmeno"], "p": o["provozovna"], "h": o["hodin"],
      "x": [[o["prani"][d][b] for b in "RSO"] for d in DNY],
      "y": [[o["prani3"][d][b] for b in "ABCD"] for d in DNY],
      "d": [[o["delka"][d]["min"], o["delka"][d]["max"]] if d in o["delka"] else None for d in DNY]}
     for o in data]
t = STRANKA.read_text(encoding="utf-8")
i = t.index("const ODPOVEDI=")
j = t.index("\n", i)
t = t[:i] + "const ODPOVEDI=" + json.dumps(H, ensure_ascii=False, separators=(",", ":")) + ";" + t[j:]
STRANKA.write_text(t, encoding="utf-8")
print("obnoveno:", len(H), "holičů")
