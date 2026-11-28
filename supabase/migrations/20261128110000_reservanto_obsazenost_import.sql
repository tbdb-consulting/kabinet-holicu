-- Import z Reservanta pro rozvrh obsazenosti křesel (Keksa 28. 11. 2026, Otázky\261128_import_z_reservanta.html).
-- Ukládá se jen: začátek rezervace po celých hodinách, délka 1 hodina, holič (zdroj v Reservantu) a zákazník ve tvaru
-- „křestní jméno + 3 písmena příjmení“ (např. „Jan Nov“). Obě provozovny dohromady (v Reservantu jsou pod jednou).
-- Zbytek exportu (e-mail, telefon, poznámky, služby…) se zahodí už v prohlížeči, surový soubor se nikam neukládá.
-- Zrušené rezervace se neimportují. Co už v tabulce je (holič + začátek + zákazník), se přeskočí.
-- Ověřeno na historii 11/2025–10/2026: 99,7 % rezervací trvá přesně hodinu, jen 38 z 33 292 nezačíná na celou hodinu.
-- Jména zákazníků smí číst jen admin, majitel a odpovědný pracovník (čtení přijde s rozvrhem).

create table analytika.reservanto_obsazenost (
  id bigserial primary key,
  davka_id int not null references analytika.import_davka(id) on delete cascade,
  zacatek timestamp not null check (date_trunc('hour', zacatek) = zacatek),
  konec timestamp not null,
  holic_zdroj text not null,
  zakaznik text not null default '',
  check (konec > zacatek)
);
create unique index on analytika.reservanto_obsazenost (holic_zdroj, zacatek, zakaznik);
create index on analytika.reservanto_obsazenost (zacatek);
alter table analytika.reservanto_obsazenost enable row level security;
revoke all on analytika.reservanto_obsazenost from public, anon, authenticated;
grant all on analytika.reservanto_obsazenost to service_role;

-- p_radky: [{"z":"2026-11-03T10:00","h":"MERLIN","k":"Jan Nov"}, ...]  (z = začátek po celé hodině, místní čas)
create function public.prehled_import_reservanto(p_soubor text, p_radky jsonb)
returns table (davka int, nacteno int, novych int, uz_bylo int, od date, do_ date)
language plpgsql security definer set search_path = '' as $$
declare v_davka int; v_novych int; v_n int; v_od date; v_do date;
begin
  perform analytika.over_pristup();
  if jsonb_typeof(p_radky) is distinct from 'array' or jsonb_array_length(p_radky) not between 1 and 50000 then
    raise exception 'Prázdný nebo příliš velký import (nejvýš 50 000 řádků).';
  end if;
  if exists (select 1 from jsonb_array_elements(p_radky) x
             where jsonb_typeof(x -> 'z') <> 'string' or jsonb_typeof(x -> 'h') <> 'string'
                or (x ->> 'z') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:00$' or length(x ->> 'h') not between 1 and 60
                or length(coalesce(x ->> 'k', '')) > 40) then
    raise exception 'Chybný řádek importu (začátek po celé hodině, holič, zákazník nejvýš 40 znaků).';
  end if;
  select count(*), min((x ->> 'z')::timestamp)::date, max((x ->> 'z')::timestamp)::date into v_n, v_od, v_do
  from jsonb_array_elements(p_radky) x;
  insert into analytika.import_davka (zdroj, soubor, obdobi_od, obdobi_do, radku, poznamka)
  values ('reservanto_obsazenost', left(coalesce(p_soubor, ''), 200), v_od, v_do, v_n,
          'import ze stránky přehledů, ' || lower(auth.jwt() ->> 'email'))
  returning id into v_davka;
  insert into analytika.reservanto_obsazenost (davka_id, zacatek, konec, holic_zdroj, zakaznik)
  select v_davka, (x ->> 'z')::timestamp, (x ->> 'z')::timestamp + interval '1 hour',
         upper(trim(x ->> 'h')), trim(coalesce(x ->> 'k', ''))
  from jsonb_array_elements(p_radky) x
  on conflict do nothing;
  get diagnostics v_novych = row_count;
  return query select v_davka, v_n, v_novych, v_n - v_novych, v_od, v_do;
end $$;

-- přehled importů a neznámých holičů (bez jmen zákazníků)
create function public.prehled_import_stav()
returns table (davka int, soubor text, od date, do_ date, radku int, kdy timestamptz, kdo text,
               obsazeno_od timestamp, obsazeno_do timestamp, holici_neznami text[])
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  select d.id, d.soubor, d.obdobi_od, d.obdobi_do, d.radku, d.vytvoreno, d.poznamka,
         (select min(o.zacatek) from analytika.reservanto_obsazenost o),
         (select max(o.zacatek) from analytika.reservanto_obsazenost o),
         (select array_agg(distinct o.holic_zdroj order by o.holic_zdroj) from analytika.reservanto_obsazenost o
          where not exists (select 1 from analytika.holic_alias a where upper(a.alias) = o.holic_zdroj))
  from analytika.import_davka d where d.zdroj = 'reservanto_obsazenost'
  order by d.id desc limit 20;
end $$;

-- holiči, které aplikace zná (pro náhled importu)
create function public.prehled_holici_aliasy()
returns table (alias text, holic text, provozovna text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  select upper(a.alias), h.jmeno, p.nazev
  from analytika.holic_alias a join analytika.holic h on h.id = a.holic_id
  left join analytika.holic_provozovna hp on hp.holic_id = h.id and hp.plati_do is null
  left join analytika.provozovna p on p.id = hp.provozovna_id
  order by 1;
end $$;

revoke all on function public.prehled_import_reservanto(text, jsonb), public.prehled_import_stav(),
  public.prehled_holici_aliasy() from public, anon;
grant execute on function public.prehled_import_reservanto(text, jsonb), public.prehled_import_stav(),
  public.prehled_holici_aliasy() to authenticated;
