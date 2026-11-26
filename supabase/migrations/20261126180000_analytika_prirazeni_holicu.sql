-- Přiřazení holičů k provozovnám a počet křesel (formulář „Kdo stříhá kde“, Keksa 26. 11. 2026).
-- Přiřazení předvyplněné podle objednávkové stránky kabinetholicu.cz (23. 11. 2026), Keksa potvrdil beze změn.
-- Platnost od 2000-01-01 = bereme jako platné pro celé období dat (změny v čase zatím neznáme).
-- Bez přiřazení: SÁRA, ÁĎA, ELVIN, SÁBA, SABA, MARIE a holiči bez rezervací za posledních 12 měsíců.
-- Křesla: Old Place 6, Zverimex 4 (zadání Keksy 23. 11. 2026); Masna a Kabinet Naproti zatím neznámé.
insert into analytika.holic_provozovna (holic_id, provozovna_id, zdroj)
select h.id, p.id, 'formulář Kdo stříhá kde 26. 11. 2026'
from (values
  ('HALIS','Zverimex'),('JOSEF','Zverimex'),('KLARA','Zverimex'),('BANÁNA','Zverimex'),('CAN','Zverimex'),('VERA','Zverimex'),('SEBASTIAN','Zverimex'),
  ('DAN','Kabinet Naproti'),('ORCUN','Kabinet Naproti'),('MARŤAS','Kabinet Naproti'),('FILIP','Kabinet Naproti'),('AHMET','Kabinet Naproti'),
  ('KUBA','Masna'),('KUBI','Masna'),('HUY','Masna'),('NIKČA','Masna'),('ŠTĚPÁNKA','Masna'),('JACK','Masna'),
  ('MERLIN','Old Place'),('JAKUB','Old Place'),('BÁĎA','Old Place'),('TADEÁŠ','Old Place'),('TOM','Old Place'),('IVET','Old Place'),
  ('EDITA','Old Place'),('ANNA','Old Place'),('PAVEL','Old Place'),('MICHAL','Old Place'),('PETR','Old Place'),('MATĚJ','Old Place'),('JAN','Old Place')
) v(jmeno, provozovna)
join analytika.holic h on h.jmeno = v.jmeno
join analytika.provozovna p on p.nazev = v.provozovna;

insert into analytika.kapacita (provozovna_id, kresel, plati_od, zdroj)
select id, k, '2000-01-01', 'Keksa 23. 11. 2026, potvrzeno ve formuláři 26. 11. 2026'
from analytika.provozovna join (values ('Old Place', 6), ('Zverimex', 4)) v(n, k) on nazev = v.n;

-- kontrola
select p.nazev, count(distinct hp.holic_id) as holicu,
       (select kresel from analytika.kapacita k where k.provozovna_id = p.id) as kresel
from analytika.provozovna p left join analytika.holic_provozovna hp on hp.provozovna_id = p.id
group by p.id, p.nazev order by p.id;

-- Ondřej: podle kabinetholicu.cz Zverimex, za posledních 12 měsíců bez rezervací (proto nebyl ve formuláři).
insert into analytika.holic_provozovna (holic_id, provozovna_id, zdroj)
select h.id, p.id, 'kabinetholicu.cz 23. 11. 2026 (za posledních 12 měsíců bez rezervací)'
from analytika.holic h, analytika.provozovna p where h.jmeno = 'ONDŘEJ' and p.nazev = 'Zverimex'
and not exists (select 1 from analytika.holic_provozovna x where x.holic_id = h.id);

-- Výsledek 26. 11. 2026 (27. 11. 2025 – 26. 11. 2026): Old Place 8 789 h, špička 8 křesel (má 6), Po–Pá 9–18 průměrně
-- 3,0 křesla = 50 %, 8–20 44 %; Zverimex 7 202 h, špička 5 (má 4), 9–18 2,32 = 58 %, 8–20 53 %; Masna 8 332 h, špička 6;
-- Kabinet Naproti 5 788 h, špička 3; nepřiřazení 1 021 h.
