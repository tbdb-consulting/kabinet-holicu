# Kabinet holičů – rezervace křesel (T26-09-1)

TBDB Consulting · zákazník T26-09 · kontext: `C:\Projekty TBDB\tbdb\Klienti\Kabinet-holicu\KONTEXT.md`,
data a návrhy: `C:\Users\Dell\Můj disk\Claude AI\T26-09 Kabinet holičů\`.

## Co tu je

| Co | Kde |
|---|---|
| Dotazník pro holiče (kolik hodin, mřížka Po–Pá × 8–12/12–16/16–20 chci/můžu/nemůžu) | `web/index.html` – HTML + JS bez sestavování |
| Databáze dotazníku | `supabase/migrations/20261123120000_dotaznik.sql` |

- Stránka bez nastavené databáze (nebo s `?test=1`) běží ve zkušebním režimu: nic neodešle, jen ukáže data.
- Odpovědi se ukládají jen přes funkci `odeslat_dotaznik` (kontrola všech 15 políček, limit 20 odpovědí za minutu).
  Tabulka `dotaznik_odpoved` má RLS bez pravidel, z webu ji nikdo nečte. Vyhodnocení: pohled `dotaznik_posledni`
  (poslední odpověď podle jména), čte jen TBDB přes správcovský přístup.
- Seznam holičů v dotazníku je z kabinetholicu.cz/objednavka (23. 11. 2026), jen Old Place a Zverimex.

## Stav (23. 11. 2026)

- **Databáze:** projekt Supabase `kabinet-holicu` (`bgnzfrxnvkifvpmrilgd`, Frankfurt) v organizaci **TBDB**
  (`vfkpmpulmxdwinsaizmg`), zatím tarif Free, přechod na Pro do pár dní (Keksa 23. 11. 2026). Kvůli limitu
  2 bezplatných projektů je do té doby uspaný vixen-dev. Při založení vypnuté „Grant API access to new tables
  automatically“ a zapnuté automatické RLS.
- Migrace nasazená ručně přes SQL Editor (propojení Supabase v Claudovi vidí jen organizaci Keksa), proto
  není v `supabase_migrations`. Ověřeno 23. 11. 2026: chybná přání vrátí chybu, anon tabulku ani pohled
  nepřečte (401), platná odpověď z webu se uloží (2 zkušební odpovědi pak smazané, id od 1).
- Bezpečnostní kontrola: 0 chyb; upozornění „Public/Signed-In Users Can Execute SECURITY DEFINER Function“
  u `odeslat_dotaznik` je záměr (jediná cesta zápisu), u `rls_auto_enable()` jde o funkci od Supabase;
  „RLS Enabled No Policy“ je záměr.
- **Zveřejněno 23. 11. 2026:** https://tbdb-consulting.github.io/kabinet-holicu/ (repozitář
  `tbdb-consulting/kabinet-holicu`, veřejný; workflow `.github/workflows/nasadit.yml` nasazuje složku `web`).
  Publishable klíč je v `.gitleaksignore` jako schválená výjimka (Keksa 23. 11. 2026).
- **23. 11. 2026 večer:** sekce 4 „Jak dlouhou rezervaci křesla chcete“ (nejkratší a nejdelší rezervace
  po dnech Po–Pá, 2–12 h) a sloupec `delka`; migrace `20261123200000_dotaznik_delka.sql` nasazená přes
  SQL Editor, stará verze stránky ukládá dál (`delka` = null). Ověřeno odesláním, zkušební odpovědi smazané.
- **23. 11. 2026 večer, druhá úprava:** sekce 3 je teď 3a (4h bloky R/S/O) a 3b (3h bloky A 8–11, B 11–14,
  C 14–17, D 17–20, sloupec `prani3`), obě povinné. Migrace `20261123210000_dotaznik_prani3.sql`, starší verze
  stránky ukládají dál. Ověřeno odesláním, zkušební odpovědi smazané.
- **Cíl vyhodnocení (Keksa 23. 11. 2026):** z odpovědí určit atraktivitu bloků; výstupem je dražba bloků,
  nebo cena bloku podle atraktivity (žádanější dražší, méně žádané levnější).
- **Zkušební data (Keksa 23. 11. 2026):** `testdata/generuj_zkusebni.py` vyrobí vymyšlené odpovědi všech 21 holičů
  OP a ZV: poptávka = 80 % kapacity (OP 6 křesel 288 h/týden, ZV 4 křesla 192 h/týden; leden 2027 = 4 týdny,
  Po–Pá 8–20), nejvíc 25 h/týden, nejméně 6 h/týden. Výstupy (`zkusebni_odpovedi.json/.csv`, `zkusebni_souhrn.md`)
  jsou v `.gitignore`, protože u skutečných jmen jsou vymyšlená přání a repozitář je veřejný.
- **Leden 2027 ze zkušebních dat (zveřejněno 23. 11. 2026, Keksa):** https://tbdb-consulting.github.io/kabinet-holicu/leden-2027.html
  (`web/leden-2027.html`, z ukázky v datové složce + `testdata/zkusebni_odpovedi.json`; jen 4h bloky). Výsledek: všichni
  holiči 100 % chtěných hodin, obsazenost 80 %, dražba 33 balíčků, prodáno 31, příplatek 9 760 Kč, Pavel mimo pravidlo ráno/odpoledne.
- **Otevřené:** po přechodu na Pro probudit vixen-dev.
