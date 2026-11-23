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

- Dotazník vyzkoušen lokálně (zkušební režim): kontrola chyb i složení odpovědi funguje.
- **Otevřené:** projekt Supabase (účet Keksa má 2 aktivní projekty Free: vixen-dev, hory-bory), doplnit
  `SUPABASE_URL` a `SUPABASE_ANON_KEY` v `web/index.html`, nasadit migraci a otestovat, zveřejnit přes
  GitHub Pages (skill publikovat-web, jen se souhlasem Keksy).
