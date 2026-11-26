-- Schéma analytika: historická data z Reservanta a vyhodnocování (návrh 261126_KABINET_datovy_sklad_navrh.html, v2).
-- Rozhodli Keksa a Tom 26. 11. 2026: přehledy jen Tom a TBDB; data bez jmen a kontaktů zákazníků (pseudonymy Z-…).
-- Schéma není vystavené přes API (PostgREST vidí jen public), anon ani authenticated k němu nemají přístup.

create schema if not exists analytika;
revoke all on schema analytika from public, anon, authenticated;

-- ===== číselníky =====
create table analytika.firma (
  id serial primary key,
  nazev text not null unique
);

create table analytika.provozovna (
  id serial primary key,
  firma_id int not null references analytika.firma(id),
  nazev text not null unique,
  adresa text,
  reservanto_location_id int,
  poznamka text
);

create table analytika.kapacita (
  id serial primary key,
  provozovna_id int not null references analytika.provozovna(id),
  kresel int not null check (kresel > 0),
  oteviraci_doba jsonb,          -- {"Po": [7, 21], ...}, hodiny od–do
  plati_od date not null,
  plati_do date,
  zdroj text
);

create table analytika.holic (
  id serial primary key,
  firma_id int not null references analytika.firma(id),
  jmeno text not null unique,
  aktivni boolean not null default true,
  poznamka text
);

create table analytika.holic_alias (           -- jméno zdroje v Reservantu -> holič
  alias text primary key,
  holic_id int not null references analytika.holic(id)
);

create table analytika.holic_provozovna (
  id serial primary key,
  holic_id int not null references analytika.holic(id),
  provozovna_id int references analytika.provozovna(id),   -- null = nepočítat
  plati_od date not null default '2000-01-01',
  plati_do date,
  zdroj text
);

create table analytika.sazebnik (               -- pásma dnešního nájmu (paušál za měsíc podle odstříhaných hodin)
  id serial primary key,
  hodin_od numeric not null,
  hodin_do numeric,                              -- null = bez horní hranice
  castka_min numeric not null,
  castka_max numeric not null,
  plati_od date not null,
  plati_do date,
  zdroj text
);

create table analytika.najem_dohoda (           -- skutečná dohoda s holičem (z přepisu schůzky, od Toma)
  id serial primary key,
  holic_id int not null references analytika.holic(id),
  zpusob text not null check (zpusob in ('pasmo', 'pevna_castka', 'kreslo_pro_sebe', 'za_hodinu', 'jine')),
  castka numeric,
  plati_od date not null,
  plati_do date,
  zdroj text,
  poznamka text
);

create table analytika.najem_platba (           -- skutečně zaplacený nájem, pokud ho Tom poskytne
  holic_id int not null references analytika.holic(id),
  mesic date not null,
  castka numeric not null,
  zdroj text,
  primary key (holic_id, mesic)
);

-- ===== události =====
create table analytika.import_davka (
  id serial primary key,
  zdroj text not null,
  soubor text not null,
  obdobi_od date,
  obdobi_do date,
  radku int,
  poznamka text,
  vytvoreno timestamptz not null default now()
);

create table analytika.rezervace_hist (
  id bigserial primary key,
  davka_id int not null references analytika.import_davka(id),
  zacatek timestamp not null,                    -- místní čas (Praha)
  konec timestamp not null,
  holic_zdroj text not null,                     -- jméno zdroje v Reservantu, převod přes holic_alias
  sluzba text,
  stav text,
  zaplaceno text,
  typ_uhrady text,
  castka numeric,
  dostavil text,
  zakaznik text,                                  -- pseudonym Z-…, bez klíče
  provozovna_reservanto text
);
create index on analytika.rezervace_hist (zacatek);
create index on analytika.rezervace_hist (holic_zdroj);
create index on analytika.rezervace_hist (zakaznik);

create table analytika.scenar (
  id serial primary key,
  nazev text not null,
  parametry jsonb not null,                       -- {"sazba_kc_h": 50, "koef_bloku": 1.2}
  vytvoreno timestamptz not null default now()
);

create table analytika.vychozi_stav (
  id serial primary key,
  ukazatel text not null,
  provozovna_id int references analytika.provozovna(id),
  holic_id int references analytika.holic(id),
  obdobi_od date not null,
  obdobi_do date not null,
  hodnota numeric not null,
  vytvoreno timestamptz not null default now()
);

-- ===== pohledy =====
-- rezervace s holičem a provozovnou platnou v den rezervace
create view analytika.v_rezervace as
select r.*, a.holic_id, h.jmeno as holic, hp.provozovna_id, p.nazev as provozovna,
       extract(epoch from (r.konec - r.zacatek)) / 3600.0 as hodin
from analytika.rezervace_hist r
left join analytika.holic_alias a on a.alias = r.holic_zdroj
left join analytika.holic h on h.id = a.holic_id
left join analytika.holic_provozovna hp on hp.holic_id = a.holic_id
     and r.zacatek::date >= hp.plati_od and (hp.plati_do is null or r.zacatek::date <= hp.plati_do)
left join analytika.provozovna p on p.id = hp.provozovna_id;

-- hodiny holiče po měsících a pásmo dnešního nájmu
create view analytika.v_holic_mesic as
select date_trunc('month', zacatek)::date as mesic, holic_id, holic, provozovna,
       count(*) as rezervaci, round(sum(hodin)::numeric, 1) as hodin,
       count(distinct zacatek::date) as dnu, count(distinct zakaznik) as zakazniku
from analytika.v_rezervace
group by 1, 2, 3, 4;

create view analytika.v_najem_dnes as
select m.*, s.castka_min, s.castka_max
from analytika.v_holic_mesic m
left join analytika.sazebnik s on m.hodin >= s.hodin_od and (s.hodin_do is null or m.hodin < s.hodin_do)
     and m.mesic >= s.plati_od and (s.plati_do is null or m.mesic <= s.plati_do);

-- obsazená křesla po hodinách (rezervace rozpadlé na celé hodiny)
create view analytika.v_obsazenost_hodiny as
select provozovna_id, provozovna, date_trunc('hour', g)::timestamp as hodina,
       round((sum(extract(epoch from (least(r.konec, g + interval '1 hour') - greatest(r.zacatek, g)))) / 3600.0)::numeric, 2) as obsazeno_kresel
from analytika.v_rezervace r,
     generate_series(date_trunc('hour', r.zacatek), r.konec - interval '1 second', interval '1 hour') g
group by 1, 2, 3;

-- scénář: nájem placený za rezervovanou hodinu křesla
create function analytika.najem_scenar(sazba_kc_h numeric, koef_bloku numeric default 1)
returns table (mesic date, provozovna text, hodin numeric, najem numeric)
language sql stable as $$
  select mesic, provozovna, sum(hodin) as hodin, round(sum(hodin) * koef_bloku * sazba_kc_h) as najem
  from analytika.v_holic_mesic group by 1, 2 order by 1, 2;
$$;

-- ===== zabezpečení: jen vlastník databáze (Supabase administrace, service_role) =====
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'analytika' loop
    execute format('alter table analytika.%I enable row level security', t);
  end loop;
end $$;
revoke all on all tables in schema analytika from public, anon, authenticated;
revoke all on all functions in schema analytika from public, anon, authenticated;
grant usage on schema analytika to service_role;
grant all on all tables in schema analytika to service_role;
grant all on all sequences in schema analytika to service_role;

-- ===== výchozí data =====
insert into analytika.firma (nazev) values ('Kabinet holičů');
insert into analytika.provozovna (firma_id, nazev, poznamka) values
  (1, 'Old Place', 'kabinetholicu.cz'), (1, 'Zverimex', 'kabinetholicu.cz'),
  (1, 'Masna', 'Reservanto: HOLIČI MASNA (Tučkova 15)'), (1, 'Kabinet Naproti', 'Reservanto: KABINET NAPROTI - Kotlářská 6');
insert into analytika.sazebnik (hodin_od, hodin_do, castka_min, castka_max, plati_od, zdroj) values
  (0, 60, 3500, 3500, '2000-01-01', 'Tom, schůzka 26. 11. 2026'),
  (60, 120, 6000, 6000, '2000-01-01', 'Tom, schůzka 26. 11. 2026'),
  (120, null, 8000, 10000, '2000-01-01', 'Tom, schůzka 26. 11. 2026');
insert into analytika.import_davka (zdroj, soubor, obdobi_od, obdobi_do, poznamka) values
  ('reservanto_udalosti', 'rezervace_2024_2026_import.csv', '2024-01-01', '2026-11-26',
   'export událostí 26. 11. 2026, anonymizováno nastroje/anonymizuj_reservanto.py, klíč pseudonymů smazán');
