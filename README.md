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
- **Otevřené:** po přechodu na Pro probudit vixen-dev.
