"""Zkušební (vymyšlené) odpovědi dotazníku holičů – Kabinet holičů T26-09-1.

Zadání (Keksa 23. 11. 2026): jako by dotazník vyplnili všichni holiči; poptávka vyplní 80 % kapacity
křesel na měsíc; nejvytíženější holič chce 25 h týdně, nejméně vytížený 6 h týdně.

Předpoklady: měsíc leden 2027 = 20 pracovních dnů = 4 týdny; provoz Po–Pá 8–20 (12 h);
Old Place 6 křesel, Zverimex 4 křesla (*ověřit u Toma, otázka B2*). Víkendy se neřeší.
80 % se plní v každé provozovně zvlášť: Old Place 288 h/týden, Zverimex 192 h/týden.

Spuštění:  py -I generuj_zkusebni.py   → zkusebni_odpovedi.json, .csv a zkusebni_souhrn.md vedle skriptu.
Data jsou vymyšlená, jména holičů jsou skutečná (z webu), proto u každé odpovědi poznámka ZKUŠEBNÍ.
"""
import csv, json, random
from pathlib import Path

SEED = 2027
TYDNU = 4                      # leden 2027: 20 pracovních dnů
HODIN_DEN = 12                 # 8–20
KRESLA = {"OP": 6, "ZV": 4}
NAPLNENI = 0.80
MAX_TYDNE, MIN_TYDNE = 25, 6

HOLICI = {"OP": ["Aňa", "Báďa", "Edita", "Ivet", "Jakub", "Jan", "Matěj", "Merlin", "Michal",
                 "Pavel", "Petr", "Tadeáš", "Tom"],
          "ZV": ["Banána", "Can", "Halis", "Josef", "Klára", "Ondřej", "Sebastian", "Vera"]}
DNY = ["Po", "Ut", "St", "Ct", "Pa"]
BLOKY4 = {"R": (8, 12), "S": (12, 16), "O": (16, 20)}
BLOKY3 = {"A": (8, 11), "B": (11, 14), "C": (14, 17), "D": (17, 20)}
# obecná atraktivita (*odhad podle volných termínů v Reservantu: dopoledne volno, večery plné*)
DEN_VAHA = {"Po": 0.85, "Ut": 0.9, "St": 1.0, "Ct": 1.15, "Pa": 1.25}
def hod_vaha(h):
    return {8: .35, 9: .4, 10: .45, 11: .55, 12: .6, 13: .65, 14: .75, 15: .8,
            16: .95, 17: 1.0, 18: 1.0, 19: .9}[h]

R = random.Random(SEED)


def tydenni_hodiny():
    """OP: jeden 25 h a jeden 6 h, součet 288; ZV: součet 192, nejvýš 25 h."""
    cil = {p: round(KRESLA[p] * HODIN_DEN * 5 * NAPLNENI) for p in KRESLA}   # 288, 192
    out = {}
    op = HOLICI["OP"][:]
    R.shuffle(op)
    out[op[0]], out[op[1]] = MAX_TYDNE, MIN_TYDNE
    zbytek = op[2:]
    for p, jm in (("OP", zbytek), ("ZV", HOLICI["ZV"][:])):
        suma = cil[p] - sum(out.get(j, 0) for j in HOLICI[p] if j in out)
        vals = {j: MAX_TYDNE for j in jm}
        prebytek = MAX_TYDNE * len(jm) - suma
        while prebytek > 0:                       # náhodně ubírat po hodině, nejníž na 19 h
            j = R.choice(jm)
            if vals[j] > 19:
                vals[j] -= 1
                prebytek -= 1
        out.update(vals)
    assert sum(out[j] for j in HOLICI["OP"]) == cil["OP"] and sum(out[j] for j in HOLICI["ZV"]) == cil["ZV"]
    return out, cil


def profil():
    typ = R.choices(["ranni", "odpoledni", "flexibilni"], [0.15, 0.55, 0.3])[0]
    posun = {"ranni": lambda h: 1.45 - hod_vaha(h), "odpoledni": lambda h: hod_vaha(h) * 1.2,
             "flexibilni": lambda h: 0.5 + hod_vaha(h) * 0.6}[typ]
    return typ, posun


def odpoved(jmeno, prov, tydne):
    typ, posun = profil()
    volnych = 0 if tydne >= 20 else (2 if tydne <= 8 else 1)       # dny, kdy vůbec nemůže
    volnych += R.random() < 0.35
    volne = set(R.sample(DNY, min(volnych, 3)))
    oblibene = {d: R.uniform(0.7, 1.3) for d in DNY}                # osobní oblíbenost dnů
    skore = {d: {h: (0 if d in volne else DEN_VAHA[d] * oblibene[d] * posun(h) * R.uniform(0.9, 1.1))
                 for h in range(8, 20)} for d in DNY}

    def mrizka(bloky):
        sk = {(d, b): sum(skore[d][h] for h in range(*rng)) / (rng[1] - rng[0])
              for d in DNY for b, rng in bloky.items()}
        delka_bloku = next(iter(bloky.values()))
        delka_bloku = delka_bloku[1] - delka_bloku[0]
        poradi = sorted((k for k in sk if sk[k] > 0), key=lambda k: -sk[k])
        chci_n = max(1, round(tydne * R.uniform(1.0, 1.3) / delka_bloku))
        ne_n = round(len(poradi) * (0.15 if tydne >= 20 else 0.35))
        out = {d: {b: 0 for b in bloky} for d in DNY}
        for i, k in enumerate(poradi):
            if i < chci_n:
                out[k[0]][k[1]] = 2
            elif i < len(poradi) - ne_n:
                out[k[0]][k[1]] = 1
        return out

    prani, prani3 = mrizka(BLOKY4), mrizka(BLOKY3)
    delka = {}
    for d in DNY:
        if any(prani[d].values()) or any(prani3[d].values()):
            mi = 3 if tydne < 15 else R.choice([3, 4, 4])
            ma = R.choice([4, 6]) if tydne < 15 else R.choice([6, 8, 8, 12])
            delka[d] = {"min": mi, "max": max(mi, ma)}
    return {"jmeno": jmeno, "provozovna": prov, "hodin": tydne * TYDNU, "hodin_tydne": tydne,
            "prani": prani, "prani3": prani3, "delka": delka, "profil": typ,
            "poznamka": "ZKUŠEBNÍ DATA – vymyšleno, nejde o odpověď holiče"}


def souhrn(odp, cil):
    l = ["# Zkušební odpovědi – souhrn", "",
         "Vymyšlená data (`generuj_zkusebni.py`, seed %d). Leden 2027 = 4 týdny, Po–Pá 8–20, "
         "Old Place 6 křesel, Zverimex 4 křesla. Nejde o odpovědi holičů." % SEED, "",
         "## Kontrola zadání", "",
         "| Provozovna | Kapacita h/týden | Chtěné h/týden | Naplnění |", "|---|---|---|---|"]
    for p in KRESLA:
        kap = KRESLA[p] * HODIN_DEN * 5
        ch = sum(o["hodin_tydne"] for o in odp if o["provozovna"] == p)
        l.append(f"| {p} | {kap} | {ch} | {ch / kap:.0%} |")
    kap = sum(KRESLA.values()) * HODIN_DEN * 5
    ch = sum(o["hodin_tydne"] for o in odp)
    l += [f"| **celkem** | {kap} | {ch} | **{ch / kap:.0%}** |", "",
          f"Nejvíc: {max(o['hodin_tydne'] for o in odp)} h/týden "
          f"({', '.join(o['jmeno'] for o in odp if o['hodin_tydne'] == MAX_TYDNE)}); "
          f"nejméně: {min(o['hodin_tydne'] for o in odp)} h/týden "
          f"({', '.join(o['jmeno'] for o in odp if o['hodin_tydne'] == MIN_TYDNE)}).", "",
          "## Holiči", "", "| Holič | Provozovna | h/týden | h/měsíc | Profil | „chci“ 4h | „chci“ 3h |",
          "|---|---|---|---|---|---|---|"]
    for o in sorted(odp, key=lambda o: (o["provozovna"], -o["hodin_tydne"])):
        c4 = sum(v == 2 for d in o["prani"].values() for v in d.values())
        c3 = sum(v == 2 for d in o["prani3"].values() for v in d.values())
        l.append(f"| {o['jmeno']} | {o['provozovna']} | {o['hodin_tydne']} | {o['hodin']} | {o['profil']} | {c4} | {c3} |")
    for nazev, klic, bloky in (("4h bloky", "prani", BLOKY4), ("3h bloky", "prani3", BLOKY3)):
        l += ["", f"## Poptávka po blocích – {nazev}", "",
              "Číslo = kolik holičů blok **chce** / počet křesel. Nad 1,0 = převis (kandidát na dražbu nebo vyšší cenu).", ""]
        for p in KRESLA:
            l += [f"**{p}** ({KRESLA[p]} křesel)", "", "| Blok | " + " | ".join(DNY) + " |",
                  "|---|" + "---|" * len(DNY)]
            for b, (od, do) in bloky.items():
                row = []
                for d in DNY:
                    n = sum(o[klic][d][b] == 2 for o in odp if o["provozovna"] == p)
                    row.append(f"{n / KRESLA[p]:.2f}")
                l.append(f"| {od}–{do} | " + " | ".join(row) + " |")
            l.append("")
    return "\n".join(l) + "\n"


def main():
    tydne, cil = tydenni_hodiny()
    odp = [odpoved(j, p, tydne[j]) for p in HOLICI for j in HOLICI[p]]
    d = Path(__file__).parent
    (d / "zkusebni_odpovedi.json").write_text(json.dumps(odp, ensure_ascii=False, indent=1), encoding="utf-8")
    with open(d / "zkusebni_odpovedi.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["jmeno", "provozovna", "hodin_mesic", "hodin_tydne", "profil", "den", "typ", "blok", "volba"])
        for o in odp:
            for typ, klic in (("4h", "prani"), ("3h", "prani3")):
                for den, bl in o[klic].items():
                    for b, v in bl.items():
                        w.writerow([o["jmeno"], o["provozovna"], o["hodin"], o["hodin_tydne"], o["profil"],
                                    den, typ, b, ["nemůžu", "můžu", "chci"][v]])
    (d / "zkusebni_souhrn.md").write_text(souhrn(odp, cil), encoding="utf-8")
    print("hotovo:", len(odp), "odpovědí")


if __name__ == "__main__":
    main()
