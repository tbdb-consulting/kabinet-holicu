-- Masna a Kabinet Naproti jsou franšízy (Keksa 26. 11. 2026), zatím je nevyhodnocujeme.
-- Každá franšíza = vlastní firma (aplikace je pro víc firem); jejich holiči zůstávají přiřazení, data se neztrácí.
insert into analytika.firma (nazev) values ('Masna (franšíza)'), ('Kabinet Naproti (franšíza)');
update analytika.provozovna p set firma_id = f.id, poznamka = coalesce(p.poznamka || '; ', '') || 'franšíza – zatím nevyhodnocovat'
from analytika.firma f where (p.nazev, f.nazev) in (('Masna', 'Masna (franšíza)'), ('Kabinet Naproti', 'Kabinet Naproti (franšíza)'));
update analytika.holic h set firma_id = p.firma_id
from analytika.holic_provozovna hp join analytika.provozovna p on p.id = hp.provozovna_id
where hp.holic_id = h.id and p.nazev in ('Masna', 'Kabinet Naproti');

select f.nazev as firma, p.nazev as provozovna, count(distinct h.id) as holicu
from analytika.provozovna p join analytika.firma f on f.id = p.firma_id
left join analytika.holic h on h.firma_id = f.id
group by 1, 2 order by 1;
