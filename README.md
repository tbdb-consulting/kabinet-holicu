# Kabinet holičů – rezervace křesel (T26-09-1)

TBDB Consulting · zákazník T26-09 · kontext: `C:\Projekty TBDB\tbdb\Klienti\Kabinet-holicu\KONTEXT.md`,
data a návrhy: `C:\Users\Dell\Můj disk\Claude AI\TBDB\Zákazníci\T26-09 Kabinet holičů\`.

## Co tu je

| Co | Kde |
|---|---|
| Prototyp aplikace (zatím jen úvodní stránka) | `web/index.html` – kořen webu |
| Dotazník pro holiče (hodiny a směny, bloky 4 h a 3 h, délky, odhady, obsazené hodiny, další fáze) | `web/dotaznik-pro-holice-pronajem-kresel/index.html` – HTML + JS bez sestavování |
| Databáze dotazníku | `supabase/migrations/20261123120000_dotaznik.sql` |
| Přehledy pro Toma a TBDB (přihlášení e-mailem, data z `analytika`) | `web/prehledy/index.html`, funkce `public.prehled_*` v `supabase/migrations/20261127090000_analytika_prehledy.sql` |

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
- **25. 11. 2026:** v sekci 2 i počet směn za měsíc; nové sekce 5 (odhad % volných křesel v provozovně,
  odpracované hodiny za 3 měsíce, obojí jde nechat „nevím“), 6 (nepovinné obsazené hodiny 7–22 po týdnech
  Po–Pá, nejvýš 13 týdnů zpět; pro případ, že nebudou data z Reservanta), 7 (zájem o funkce fází 2 a 3
  a vlastní nápad), poznámka je teď 8. Sloupce `smen`, `odhad_volno`, `hodin_3m`, `sloty_stav`, `sloty`,
  `dalsi`; migrace `20261125120000_dotaznik_smeny_odhady.sql` nasazená přes SQL Editor. Ověřeno curl: stará
  i nová podoba odpovědi se uloží, chybná hodina vrátí chybu; zkušební řádky smazané (tabulka prázdná).
- **25. 11. 2026, adresy:** dotazník se přesunul na https://tbdb-consulting.github.io/kabinet-holicu/dotaznik-pro-holice-pronajem-kresel/,
  kořen webu je místo pro prototyp konečné aplikace (zatím jen úvodní stránka). Další dotazníky každý na vlastní
  popisné adrese (Keksa 25. 11. 2026).
- **25. 11. 2026 odpoledne:** mřížky 3a a 3b mají čtyři stupně (3 určitě chci, 2 spíše chci, 1 spíše nechci,
  0 určitě nechci; dřív 2 chci, 1 můžu, 0 nemůžu), nová nepovinná sekce 3c „Kdy určitě nemůžete“ (Po–Pá × 7–22
  po hodinách, sloupec `nemuzu`), sekce 2 vysvětluje sběr dat ve dvou variantách bloků a hodiny týdně i měsíčně
  (měsíc = 4,3 týdne). Migrace `20261125150000_dotaznik_ctyri_stupne_nemuzu.sql` nasazená přes SQL Editor,
  ověřeno curl (stará i nová podoba se uloží, hodnota 4 a den So vrátí chybu), zkušební řádky smazané.
  Ukázka `leden-2027.html` dál počítá se třemi stupni.
- **25. 11. 2026 večer:** úvod dotazníku se třemi fázemi (1. fáze bez slibu „spravedlivě“, rozvrh na měsíc nebo
  delší období – předmět diskuze), sekce 7 – o nabídkách rozhoduje holič, k zákazníkům i automaticky podle jeho
  nastavení. Otázky do budoucna budou v aplikaci jako měsíční přání (architektura verze 5). Nasazení ve dvou úlohách.
- **26. 11. 2026 (Keksa):** holič nejdřív vybere délku bloku 3, 4, 6 nebo 12 h (nová sekce 2) a vyplní jen jednu
  mřížku pro tuto délku (sekce 4, dřív dvě mřížky 3a/3b). Sekce 3 vysvětluje směnu (= jeden blok) tabulkou
  1–5 směn týdně → hodiny týdně, směny a hodiny měsíčně; zadává se jen počet směn, hodiny se dopočítají.
  Sekce 6 „Kolik hodin v kuse zvládnete“ (nejkratší a nejdelší rezervace) zůstává, nezávazně. Sekce přečíslované 1–10.
  Migrace `20261126090000_dotaznik_delka_bloku.sql` (sloupce `blok`, `prani_blok`, `prani` nepovinné) – nasazená 26. 11. 2026 přes SQL Editor,
  ověřeno curl (správná odpověď 204, blok 5 a neúplná mřížka chyba 400), zkušební řádky smazané. Architektura verze 7.
  Dále: celý dotazník v tykání; v sekci 7 místo „hodiny za poslední 3 měsíce“ otázka „Kolik hodin měsíčně teď
  obvykle stříháš?“ (průměr, 0–300, sloupec `hodin_prumer` ve stejné migraci).
  Sekce 8 zjednodušená (bez vysvětlování): klepnutí střídá „stříhal(a) jsem zákazníka“ a „křeslo jsem měl(a),
  ale bez zákazníka“ (nový sloupec `sloty_rez`, stejná migrace).
- **26. 11. 2026 odpoledne (Keksa):** celý dotazník přátelštěji a kratší, bez vysvětlování (vibe komunity, viz CLAUDE.md).
  Sekce 9 má 5 krátkých nabídek, první a hlavní: zpráva přes WhatsApp zákazníkům, kterým se blíží čas na střih,
  když holiči odpadne zákazník (klíč `moji_zakaznici`); `zruseni` vypadlo (spojené s ním). Databáze beze změny.
- **26. 11. 2026 (Keksa):** sekce „Co by se ti v appce hodilo“ je hned na začátku jako 1 (má nadchnout), ostatní 2–10.
  Nová volba „Appka za mě vyřeší EET“ (klíč `eet`, migrace `20261126140000_dotaznik_volba_eet.sql`, nasazená a ověřená 26. 11.).
- **Cena fáze 1 (Keksa a Tom 26. 11. 2026):** pevně 20 h × 990 Kč/h = 19 800 Kč, nad rámec na režii TBDB;
  fáze 2 a 3 až po osvědčení fáze 1. Hodiny dál do výkazu, bez podrobného rozpisu.
- **Další kroky po schůzce 26. 11. 2026:** doladit znění dotazníku pro holiče; Tom se sejde s holiči, představí
  projekt a nasdílí dotazník (mohou ho vyplňovat společně a diskutovat); Tom dodá data z Reservanta; z odpovědí
  a dat Reservanta fáze 0 a rozhodnutí, kudy dál. Poznámky: složka klienta `Zápisy/261126_poznamky_ze_schuzky.md`.
- **Historická data v databázi (26. 11. 2026):** schéma `analytika` (migrace `20261126160000_analytika_historie.sql`,
  `20261126170000_analytika_holici_z_importu.sql`, nasazeno v SQL Editoru). Nahráno importem CSV v administraci
  Supabase: 81 931 rezervací 2024–2026 z Reservanta, zákazníci jen jako pseudonymy (klíč smazán), 45 holičů.
  Schéma není přes API dostupné (ověřeno: PGRST106). Chybí: přiřazení holičů k provozovnám, počet křesel,
  nájem holičů z přepisu (přiřazení a křesla OP 6 / ZV 4 doplněny migrací 20261126180000; Masna a Naproti bez křesel).
  První obsazenost Po–Pá 9–18 (12 měsíců): Old Place 50 %, Zverimex 58 %. Pozor: špička OP 8 a ZV 5 současných
  rezervací převyšuje počet křesel – ověřit s Tomem (víc křesel, holič jinde, nebo dvojí rezervace).
  Masna a Kabinet Naproti jsou franšízy (Keksa 26. 11.): vlastní firmy v `analytika.firma`, zatím se nevyhodnocují.
  Data jsou jen v Supabase a ve složce klienta `Data\Reservanto`, nikdy v repozitáři.
- **Cíl vyhodnocení (Keksa 23. 11. 2026):** z odpovědí určit atraktivitu bloků; výstupem je dražba bloků,
  nebo cena bloku podle atraktivity (žádanější dražší, méně žádané levnější).
- **Zkušební data (Keksa 23. 11. 2026):** `testdata/generuj_zkusebni.py` vyrobí vymyšlené odpovědi všech 21 holičů
  OP a ZV: poptávka = 80 % kapacity (OP 6 křesel 288 h/týden, ZV 4 křesla 192 h/týden; leden 2027 = 4 týdny,
  Po–Pá 8–20), nejvíc 25 h/týden, nejméně 6 h/týden. Výstupy (`zkusebni_odpovedi.json/.csv`, `zkusebni_souhrn.md`)
  jsou v `.gitignore`, protože u skutečných jmen jsou vymyšlená přání a repozitář je veřejný.
- **Leden 2027 ze zkušebních dat (zveřejněno 23. 11. 2026, Keksa):** https://tbdb-consulting.github.io/kabinet-holicu/leden-2027.html
  (`web/leden-2027.html`, z ukázky v datové složce + `testdata/zkusebni_odpovedi.json`; jen 4h bloky). Výsledek: všichni
  holiči 100 % chtěných hodin, obsazenost 80 %, dražba 33 balíčků, prodáno 31, příplatek 9 760 Kč, Pavel mimo pravidlo ráno/odpoledne.
  Varianta 3h bloků (přepínač, srovnání v „Férovost a nájem“): splnění 99–101 %, dražba 33 z 35, příplatek 7 680 Kč,
  nikdo mimo pravidlo ráno/odpoledne.
- **Leden 2027, úprava (Keksa 23. 11. 2026):** rozdělení skládá souvislé rezervace u jednoho křesla v délce mezi
  nejkratší a nejdelší rezervací holiče pro daný den; nový vzhled modulů 2 (teplotní mapa poptávky, karty holičů)
  a 4 (týdny, křesla × dny, legenda, měsíc vybraného holiče). Výsledek 4h: obsazenost 1 916 h, splnění 96–100 %,
  všech 372 rezervací v povolené délce; 3h: 1 866 h, splnění 88–101 %, 7 z 328 rezervací kratších.
  Stránka se upravuje přímo, `testdata/sestav_leden.py` v ní jen obnoví data.
- **Leden 2027, mobil (Keksa 23. 11. 2026):** aplikace se bude používat hlavně v mobilu. Nápovědy u všech prvků (myš: najetí,
  mobil: klepnutí, zmizí po 4,5 s), výrazný přepínač 4h/3h pod menu a barva podle varianty (modrá 4 h, zelená 3 h),
  na mobilu rozvrh po dnech (křesla × bloky) a férovost na kartách.
- **Leden 2027, přednost holičů (Keksa 27. 11. 2026, rozhodnutí v `CLAUDE.md`; zveřejněno 27. 11. 2026 se souhlasem Keksy, ověřeno na živém webu):**
  nová část „6. Přednost 🔒“ v `web/leden-2027.html`.
  - *Pevný blok* (holič, den v týdnu, čas, platí od–do, poznámka) se přidělí jako první – před dražbou i rozdělením
    podle přání, nikdo jiný ho nedostane. Dražba pak draží jen křesla, která po pevných blocích zůstala volná.
    Čas se zadává v hodinách, takže platí pro obě varianty (16–20 je ve 3h blocích 17–20). Když na pevný blok
    nezbude křeslo, rozpis to hlásí („bez křesla“); když holič v přáních ten čas „nemůže“, seznam ukáže „nemůže!“.
  - *Úroveň 1–3* (platí od–do, poznámka): spravedlivé rozdělení běží nejdřív pro holiče s úrovní 3, pak 2, pak 1
    (jen ve dnech platnosti a do podílu jejich hodin úměrného těm dnům), nakonec pro všechny. Uvnitř úrovně dosavadní
    algoritmus (přednost má, kdo má splněno nejméně). V dražbě rozhoduje úroveň jen při stejné ceně.
  - Náhoda při shodě je nově pevná podle holiče, dne a bloku, takže porovnání s předností a bez ní ukazuje jen dopad
    přednosti. Proto se o pár hodin posunula výchozí čísla (3h bez přednosti 1 893 h místo 1 866 h).
  - *Porovnání* bez přednosti a s ní: dlaždice (kolik hodin se přesunulo, splnění, hodiny ve chtěných blocích,
    obsazenost) a tabulka po holičích (hodiny a bloky bez → s, rozdíl, splněno, ve chtěných). Přepínač „Použít
    přednost v rozpisu“ přepne části 3–5. Záznam změn přednosti i ručních úprav (kdo, kdy, co) pod porovnáním.
  - *Ruční úprava* v části 4: zaškrtnout „✎ Upravit ručně“ a klepnout na blok → vybrat holiče nebo volno
    (u jména je, co zadal v přáních a kolik hodin má). Holič z jiného křesla ve stejný čas se přesune. Pevný blok jde
    přesunout jen po potvrzení upozornění, „nemůže“ podle přání také. Úpravy se dají vrátit; změna pravidel,
    přednosti nebo nová simulace dražby je zruší (zapíše se to).
  - Ukázka (vymyšlená, poznámky „UKÁZKA“): Matěj úroveň 3, Jakub úroveň 2 od 11. 1., Michal pevně pátek 16–20,
    Klára pevně čtvrtek 16–20 do 15. 1. Výsledek 4h: přesunuty jen 4 h (Josef 96 → 92 h), obsazenost 1 916 → 1 912 h,
    splnění dál 96–100 %. 3h: přesunuto 36 h od 5 holičů ke 3, nejhorší splnění 91 → 88 %, obsazenost 1 893 → 1 866 h.
    Při 80% poptávce tedy přednost mění hlavně to, *které* bloky kdo dostane, ne kolik hodin; úroveň pomůže jen
    u bloků, o které se soupeří.
  - V simulaci vidí porovnání každý, kdo stránku otevře (zkušební data). V aplikaci přednost a porovnání jen Tom
    a provozní, holiči jen svůj rozpis bez značek 📌.
  - Návrh databáze: `supabase/migrations/20261127220000_rozpis_prednost_NAVRH.sql` – **nenasazovat**, nevyzkoušeno
    v Postgresu. Schéma `rozpis`: `prednost` (holič, typ pevný blok / úroveň, hodnota, platí od–do, poznámka, autor),
    `prednost_zmena` (záznam změn plněný triggerem: co bylo před a po, kdo, kdy), `uprava` (ruční úpravy rozpisu,
    přesun pevného bloku jen s `potvrzeno`). Přístup jen přes funkce `public.prednost_*` pro roli admin a majitel.
  - **Otevřené pro Keksu/Toma:** má úroveň platit i v dražbě jinak než při stejné ceně? Má holič s pevným blokem
    platit za něj stejnou sazbu (teď ano)? Smí provozní ručně upravovat rozpis, nebo jen Tom?
- **Leden 2027, smíšená křesla 4h a 3h (Keksa 27. 11. 2026):** majitel nebo pověřený pracovník určí, kolik křesel
  v provozovně má 3hodinové bloky a kolik 4hodinové (Pravidla → „Kolik křesel má 4h a kolik 3h bloky“, nebo nahoře
  přepínač Vše 4h / 4h + 3h / Vše 3h; fialová barva = smíšené). Křesla se číslují nejdřív 4h, pak 3h.
  - U 4h křesla se berou přání holiče z mřížky 3a dotazníku, u 3h křesla z 3b. Holič má v jednom dni rezervaci
    jen v křeslech jednoho typu (ruční úpravou jde i jinak). Nejkratší a nejdelší rezervace platí pro hodiny za den.
  - Dražba: pro každý typ křesla zvlášť; zájem o blok se na typ počítá podílem křesel toho typu
    (žádaný, když ho „chce“ víc holičů než je všech křesel provozovny × hranice).
  - Pevný blok z přednosti padne do křesla, jehož bloky čas pokrývají přesně (16–20 → 4h křeslo), jinak 4h, pak 3h.
  - Rozvrh: u křesla značka 4h/3h; v mobilu je den rozložený po hodinách, takže 3h a 4h bloky sedí pod sebou.
    Ruční úpravy se pamatují zvlášť pro každé rozdělení křesel.
  - Srovnání ve „Férovost a nájem“: všechna 4h, všechna 3h a nastavené rozdělení. Čisté varianty dávají stejná
    čísla jako dosud (4h 1 912 h, 3h 1 866 h s ukázkou přednosti). Příklad OP 4+2, ZV 3+1: 1 905 h, splnění
    86–108 %, dražba 35 z 39, příplatek 10 280 Kč. Přesahy nad 100 % jsou 1–2 h ze zaokrouhlení na celé bloky.
- **Otevřené:** po přechodu na Pro probudit vixen-dev.
- **27. 11. 2026 (Keksa):** v sekci 8 nepovinně průměrný měsíční nájem a nájem za poslední 3 celé měsíce zvlášť
  (měsíce se počítají podle dne vyplnění). Sloupec `najem` jsonb `{"prumer":…, "mesice":{"RRRR-MM":…}}`, 0–50 000 Kč.
  Migrace `20261127140000_dotaznik_najem.sql` nasazená přes SQL Editor; ověřeno curl (s nájmem, bez něj i stará podoba
  se uloží, chybný měsíc a 90 000 Kč vrátí chybu), zkušební řádky smazané (tabulka prázdná).

- **27. 11. 2026 (Keksa):** v sekci 8 dotazníku otázka „Máš křeslo jen pro sebe?“ (ano / ano, ale občas na něm stříhá
  i někdo jiný / ne, sdílím; nepovinné). Ukládá se do sloupce `najem` jako klíč `vyhradni` (`ano` / `castecne` / `ne`).
  Migrace `20261127210000_dotaznik_vyhradni_kreslo.sql` mění jen kontrolu ve funkci `odeslat_dotaznik` (parametry stejné),
  nasazená a ověřená (chybná hodnota odmítnuta, správná uložena v transakci s rollbackem, nic nezůstalo).
  Při odpovědi „Ano…“ se ukáže pole „Kolik za něj platíš měsíčně?“ (Kč, nepovinné) → `najem.vyhradni_castka`, 0–50 000;
  migrace `20261127230000_dotaznik_vyhradni_castka.sql` (jen kontrola ve funkci), nasazená a ověřená stejně.

- **27. 11. 2026 (Keksa):** část „6. Přednost 🔒“ na `web/leden-2027.html` se otevře jen po přihlášení (Supabase,
  stejné přihlášení jako přehledy, sdílené na doméně) s rolí admin nebo majitel (`prehled_role`). Bez přihlášení se
  přednost nekreslí a rozpis v částech 3–5 se počítá bez ní. Přihlašuje se v přehledech, pak stačí obnovit stránku.

- **27. 11. 2026 (Keksa):** v přehledech karta „Uživatelé a práva“ (vidí jen admin): seznam účtů z `analytika.opravneni`,
  přidání / změna role, firmy a poznámky, odebrání přístupu. Migrace `20261128090000_analytika_sprava_opravneni.sql`
  (`prehled_opravneni`, `prehled_ulozit_opravneni`, `prehled_smazat_opravneni`, jen pro admina), nasazená a ověřená:
  nejde smazat sám sebe ani odebrat / sesadit posledního admina, neplatný e-mail odmítnut, zkušební účet přidán a smazán.
  Role odpovědný zatím nemá přístup nikam. Odkaz pro přihlášení chodí zatím jen členům týmu Supabase (chybí SMTP).

- **27. 11. 2026 (Keksa):** dotazník má v části „2. Kdo jsi“ povinný e-mail a telefon (na stránce povinné, v databázi
  nepovinné kvůli starším verzím stránky). Sloupce `email` (malými písmeny) a `telefon` (jen číslice a +) v `dotaznik_odpoved`,
  parametry `p_email`, `p_telefon` funkce `odeslat_dotaznik`. Migrace `20261128100000_dotaznik_email_telefon.sql`, nasazená
  a ověřená (chybné odmítnuty, správné uloženy v transakci s rollbackem, starší volání bez kontaktu funguje).
  Kontakty jsou jen v databázi (RLS bez pravidel, z webu je nikdo nečte), do repozitáře ani na web nepatří.
- **Web kabinetholicu.cz (zjištěno 27. 11. 2026):** běží na **Wixu** (generator „Wix.com Website Builder“, DNS na
  ns10/ns11.wixdns.net, www → cdn3.wixdns.net). Doménu má registrovanou INTERNET CZ (Forpsi), držitel „Kabinet Toma holiče“,
  platnost do 14. 4. 2027. Na doméně nejsou MX záznamy (žádný e-mail @kabinetholicu.cz). Přístup: Tom pozve TBDB do webu
  ve Wixu jako spolupracovníka (Nastavení webu → Role a oprávnění), bez sdílení hesla. Přes Wix se mění i DNS (subdoména pro aplikaci).

## Přehledy (27. 11. 2026)

- Stránka `web/prehledy/` (po zveřejnění https://tbdb-consulting.github.io/kabinet-holicu/prehledy/): přihlášení
  odkazem do e-mailu (Supabase Auth, bez hesla), pak dlaždice po provozovnách, obsazenost po dnech a hodinách,
  hodiny po měsících, nájem dnes proti nájmu za hodinu (posuvník sazby a koeficientu bloků) a tabulka holičů.
- Oprávnění: tabulka `analytika.opravneni` (e-mail → role admin / majitel / odpovedny). Funkce `public.prehled_*`
  pustí jen admina a majitele, anon nemá ani právo je volat (ověřeno curl 42501), cizí e-mail dostane chybu 42501.
  E-maily oprávněných se vkládají ručně v SQL Editoru, do repozitáře nepatří. Teď je zapsaný jen admin (Keksa).
- 27. 11. 2026 odpoledne (Keksa): graf vytíženosti po měsících v % s porovnáním provozoven (funkce
  `prehled_vytizenost_mesic`, Po–Pá 9–18 h, migrace `20261127150000_analytika_vytizenost_mesic.sql`, za 12 měsíců
  OP 49,9 %, ZV 58,6 %); tabulka po dnech a hodinách má v políčku čísla všech provozoven „OP / ZV“ a barvy po 10 %
  (stupnice viridis, 0–9 % šedě).
- 27. 11. 2026 později (Keksa): vytíženost se počítá Po–Pá 7–22 h místo 9–18 h (funkce má rozsah hodin jako parametr,
  migrace `20261127160000_analytika_vytizenost_7_22.sql`; za 12 měsíců OP 36,0 %, ZV 44,7 %, při 9–18 h 49,9 % a 58,6 %).
  Tabulka po hodinách: nad ní výběr rozsahu hodin (výchozí 7–22), v políčku čísla oddělená lomítkem, každé s proužkem
  v barvě provozovny.
- 27. 11. 2026 večer (Keksa): karta „Kalkulace nájmu“ místo jednoduchého posuvníku. Varianty: hodinová (výchozí sazba,
  řádky sazeb podle dnů / hodin / provozovny – platí první, který sedí; koeficient bloků, paušál na holiče, změna obsazenosti
  v %) a pásma (jiný měsíční paušál podle hodin). Porovnání všech variant s dneškem (měsíc, rok, rozdíl), rozpad hodinové
  varianty po řádcích sazeb a tabulka „co když“ (sazby × 0,8–1,2, obsazenost ±20 %). Varianty se ukládají do
  `analytika.scenar` přes `prehled_scenare` / `prehled_ulozit_scenar` / `prehled_smazat_scenar` (migrace
  `20261127170000_analytika_scenare_najmu.sql`, ověřeno v SQL Editoru, zkušební varianta smazaná).
- 27. 11. 2026 (Keksa): výběr hodin „od–do“ přesunutý do horního filtru, platí pro dlaždice, graf vytíženosti po měsících
  i tabulku po hodinách. Graf odstříhaných hodin a kalkulace nájmu počítají celý den.
- 27. 11. 2026 (Keksa): tabulka holičů má sloupec „Kč za hodinu“ (nájem podle dnešních pásem / odstříhané hodiny
  za zvolené období). V kalkulačce uložená varianta „Hodinová 72 Kč – stejný příjem jako dnes“ (72 Kč/h, koeficient 1;
  za 11/2025–10/2026 vychází 96 000 Kč měsíčně proti dnešním 92 500–100 200 Kč).
- 27. 11. 2026 (Keksa): nápovědy po najetí myší (v mobilu ťuknutím) u filtrů, čísel v dlaždicích, legend, nadpisů
  i buněk všech tabulek a polí kalkulačky. Texty v objektu `NAP` ve stránce; co má nápovědu, je podtržené tečkami.
- 27. 11. 2026 (Keksa, podle schůzky s Tomem 26. 11.): migrace `20261127180000_analytika_dohody_vychozi_stav.sql`
  (nasazená a ověřená v SQL Editoru): dohody s holiči (`prehled_dohody` / `prehled_ulozit_dohodu` / `prehled_smazat_dohodu`,
  tabulka `analytika.najem_dohoda`), obsazenost bez holičů s výhradním křeslem (`prehled_obsazenost_sdilena`)
  a výchozí stav (`prehled_vychozi_stav` / `prehled_ulozit_vychozi_stav`, tabulka `analytika.vychozi_stav`).
  Stránka: karta „Dohody s holiči“ (zadávání přímo v přehledech, jména holičů jen v databázi), dohoda přepíše nájem
  podle pásem, výhradní křeslo platí ve variantách pevnou částku (pole „Výhradní křeslo Kč/měs“) a jeho hodiny
  se hodinově neúčtují; dlaždice ukazují výhradní a sdílená křesla. Výchozí stav: řádek pod dlaždicemi s tlačítkem
  pro uložení, porovnání v dlaždicích, čárkovaná čára v grafu vytíženosti, řádek v porovnání variant.
  Uložený výchozí stav za 11/2025–10/2026: vytíženost 7–22 h OP 36,0 %, ZV 44,7 %; 9–19 h OP 48,0 %, ZV 57,8 %;
  odstříhané hodiny OP 726, ZV 606 měsíčně. Nájem do výchozího stavu zatím uložený není – až po zadání dohod.
  Varianta „Bloky podle zájmu – návrh 90 / 75 / 40 Kč“ (oblíbené časy 90, ostatní 75, neoblíbené 40 Kč/h;
  97 600 Kč měsíčně proti dnešním 92 500–100 200 Kč). Částky jsou návrh k diskusi, ne Tomovo rozhodnutí.
- 27. 11. 2026 (Keksa): tabulka Holiči se řadí kliknutím na kterýkoli nadpis sloupce (podruhé obráceně, čísla podle hodnoty,
  jména česky) a má řádek filtrů: jméno (bez ohledu na háčky), provozovna, pásmo hodin, s dohodou / bez, u všech číselných
  sloupců od–do. Filtry i řazení zůstávají při změně období.
- 27. 11. 2026 (Keksa): v tabulce „Co když“ je pod každou částkou rozdíl proti dnešnímu nájmu (střed rozpětí pásem
  a dohod), zeleně ▲ víc, červeně ▼ méně; po najetí myší rozpětí a rozdíl za rok.
- 27. 11. 2026 (Keksa): nová stránka `web/prehledy/eet/` (odkaz „EET 2.0 →“ v záhlaví přehledů, přihlášení sdílené
  s přehledy). Porovnává pro každého holiče vlastních provozoven náklady navíc proti dnešku (bez EET): EET OFF
  (+1 400 Kč/měs, jen paušál 1. pásmo a tržba do 1 mil. Kč), MOJE eet (zdarma, čas na zadání plateb), pokladní aplikace
  (cena neznámá) a evidence v naší aplikaci (cena nestanovená). Počet plateb = průměr rezervací za měsíc z Reservanta
  za posledních 12 měsíců. Čas, hodnota hodiny a příprava jsou odhady k úpravě; parametry a režim daně u holičů si
  pamatuje jen prohlížeč. Fakta z rozboru `Claude outputs\261126_KABINET_EET2.html` (Disk, složka klienta).
- 27. 11. 2026 (Keksa): ceny střihů z Reservanta nepoužívat (částku má jen 287 z 30 955 rezervací a nesedí). Platí
  průměr **pánský 500 Kč, dámský 650 Kč**. Migrace `20261127190000_analytika_holici_sluzby.sql` (nasazená, ověřená):
  `prehled_holici_sluzby` = počty dámských / pánských / neurčených střihů na holiče. Neurčený („Střih – Kabinet holičů“,
  většina rezervací) se na stránce EET počítá cenou pánského, jde změnit. Za 11/2025–10/2026: 21 holičů, odhad tržby
  medián asi 404 000 Kč ročně, nad 1 mil. Kč jeden holič, nad 800 000 Kč tři.
- 27. 11. 2026 (Keksa): karta „Poměrová hodinová sazba podle vytíženosti“ v přehledech. Sazba každé hodiny v týdnu =
  koeficient × vytíženost sdílených křesel; koeficient zvlášť pro provozovnu tak, aby vybrala jako dnes (střed rozpětí),
  výhradní křesla pevně. Po zaokrouhlení (1 / 5 / 10 Kč) se koeficient doladí. Za 11/2025–10/2026 (po 5 Kč): OP cíl
  58 250 Kč → 58 276 Kč, průměr 80 Kč/h, nejvíc 115 Kč/h; ZV cíl 38 083 Kč → 38 067 Kč, průměr 63 Kč/h, nejvíc 85 Kč/h.
  Tlačítko uloží sazby jako hodinovou variantu kalkulace (řádky po dnech, sousední hodiny se stejnou sazbou sloučené).
- 27. 11. 2026 (Keksa): poměrová sazba má rozpětí „Nejnižší / Nejvyšší sazba Kč/h“ (sazba = koeficient × vytíženost
  oříznutá na rozpětí, koeficient hledaný bisekcí, aby příjem zůstal jako dnes; když rozpětí dnešní příjem nedovolí,
  stránka to napíše). Nová tabulka „Cena křesla po dnech a hodinách“: řádky hodiny, sloupce dny, průměr hodiny a dne
  (vážený obsazením), výběr provozovny nebo obou dohromady.
- 27. 11. 2026 (Keksa): řádek „Společná sazba obou“ – jedna sazba pro obě provozovny (vytíženost hodiny = obsazená
  křesla obou / všechna sdílená křesla, jeden koeficient na celkový dnešní příjem), pod ním kolik by vybrala každá
  provozovna. V tabulce ceny po dnech a hodinách volba „společná sazba obou provozoven“, druhé tlačítko ji uloží jako variantu.
- 27. 11. 2026 (Keksa): stránka `web/prehledy/simulace/` (odkaz „Simulace nájmu →“ v záhlaví přehledů) pro zkušební
  kalkulace proti dnešku. Posuvníky: příjem Toma proti dnešku, paušál, výhradní křeslo, sklon sazby podle vytíženosti
  (0 = jednotná, 1 = poměrová), nejnižší / nejvyšší sazba, zaokrouhlení, společné / zvláštní sazby, koeficient bloků,
  změna obsazenosti, ceny střihů. Dlaždice (Tom celkem a po provozovnách, průměrná cena hodiny, kolik holičů zaplatí
  víc / méně, výdělek holičů), tabulka holičů dnes → kalkulace (nájem, Kč/h, tržba, výdělek = tržba − nájem, podíl
  nájmu z tržby) a tabulka sazeb po dnech a hodinách. Migrace `20261127200000_analytika_holic_hodiny.sql` (nasazená,
  ověřená, součet 15 991 h sedí s přehledy): `prehled_holic_hodiny` = hodiny holiče po dnech a hodinách, jeden řádek
  na holiče (API vrací najednou nejvýš 1 000 řádků). Nastavení posuvníků si pamatuje jen prohlížeč.
- 27. 11. 2026 (Keksa, výběr z `Otázky\261127_zvyhodneni_holicu_s_vice_hodinami.html`): simulace zvýhodňuje holiče
  s více hodinami – sleva na hodiny nad hranicí (hranice po 10 h, sleva 0–60 %), strop měsíčního nájmu (3 000–20 000 Kč)
  a paušál. Koeficient sazeb se hledá bisekcí na celkovém příjmu včetně slev a stropu. Tabulka holičů má sloupec
  „Zvýhodnění“, nový graf „Nájem podle počtu hodin“ (dnešní pásma, křivka kalkulace při průměrné sazbě, body holičů).
- 27. 11. 2026 (Keksa): EET 2.0 v aplikaci chce Keksa stihnout do 1. 1. 2027 (SOAP 1.1, podpis WS-Security
  RSA-SHA256 / exc-c14n certifikátem holiče, server podporuje CORS – viz popis rozhraní v1.2 na eet.gov.cz).
- Supabase Auth → URL Configuration: Site URL a povolené adresy `…/kabinet-holicu/prehledy/` a `http://127.0.0.1:8787/prehledy/`.
- Další kroky: Tom jako `majitel`, Kuba jako `odpovedny` s omezeným pohledem (zatím nerozhodnuto, co uvidí);
  vlastní odesílání e-mailů (SMTP), protože vestavěné posílá jen členům týmu Supabase a málo zpráv za hodinu.
