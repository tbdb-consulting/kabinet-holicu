-- Přehledy z analytiky v aplikaci (stránka web/prehledy/), Keksa 27. 11. 2026.
-- Přihlášení e-mailem (odkaz do schránky, bez hesla). Kdo smí co vidět, určuje tabulka analytika.opravneni
-- podle ověřeného e-mailu z přihlášení. Zatím jen admin (Keksa); Tom a odpovědný holič se přidají později.
-- E-maily oprávněných se do repozitáře nepíšou (veřejný) – vkládají se ručně v SQL Editoru.
-- Schéma analytika zůstává nevystavené; web volá jen funkce public.prehled_*, které přístup ověří a vrátí souhrny.

create table analytika.opravneni (
  email text primary key check (email = lower(email)),
  role text not null check (role in ('admin', 'majitel', 'odpovedny')),
  firma_id int references analytika.firma(id),      -- null = všechny firmy
  poznamka text,
  vytvoreno timestamptz not null default now()
);
alter table analytika.opravneni enable row level security;
revoke all on analytika.opravneni from public, anon, authenticated;
grant all on analytika.opravneni to service_role;

-- role přihlášeného (null = nepřihlášený nebo bez oprávnění)
create function analytika.moje_role() returns text
language sql stable security definer set search_path = '' as $$
  select o.role from analytika.opravneni o
  where auth.uid() is not null and o.email = lower(auth.jwt() ->> 'email');
$$;

create function analytika.over_pristup(p_role text[] default array['admin', 'majitel']) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if coalesce(analytika.moje_role(), '') <> all (p_role) then
    raise exception 'Nemáte přístup k přehledům.' using errcode = '42501';
  end if;
end $$;

-- kdo jsem (nevyhazuje chybu, aby stránka mohla říct „nemáte oprávnění“)
create function public.prehled_role() returns table (email text, role text)
language sql stable security definer set search_path = '' as $$
  select lower(auth.jwt() ->> 'email'), analytika.moje_role() where auth.uid() is not null;
$$;

-- provozovny, křesla a rozsah dat
create function public.prehled_provozovny()
returns table (provozovna text, firma text, fransiza boolean, kresel int, data_od date, data_do date)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  select p.nazev, f.nazev, f.nazev <> 'Kabinet holičů',
         (select k.kresel from analytika.kapacita k where k.provozovna_id = p.id
           and (k.plati_do is null or k.plati_do >= current_date) order by k.plati_od desc limit 1),
         (select min(r.zacatek)::date from analytika.rezervace_hist r),
         (select max(r.zacatek)::date from analytika.rezervace_hist r)
  from analytika.provozovna p join analytika.firma f on f.id = p.firma_id
  order by p.id;
end $$;

-- obsazená křesla podle dne v týdnu a hodiny: průměr přes všechny dny období (i prázdné) a nejvyšší hodnota
create function public.prehled_obsazenost(p_od date, p_do date)
returns table (provozovna text, den int, hodina int, prumer numeric, spicka numeric)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  with dny as (
    select extract(isodow from d)::int as den, count(*) as n
    from generate_series(p_od::timestamp, p_do::timestamp, interval '1 day') d group by 1
  ), o as (
    select v.provozovna, extract(isodow from v.hodina)::int as den, extract(hour from v.hodina)::int as hodina,
           sum(v.obsazeno_kresel) as s, max(v.obsazeno_kresel) as m
    from analytika.v_obsazenost_hodiny v
    where v.provozovna is not null and v.hodina >= p_od and v.hodina < p_do + 1
    group by 1, 2, 3
  )
  select o.provozovna, o.den, o.hodina, round(o.s / dny.n, 2), o.m
  from o join dny on dny.den = o.den
  order by 1, 2, 3;
end $$;

-- holiči po měsících: hodiny, rezervace, zákazníci a pásmo dnešního nájmu
create function public.prehled_holici_mesic(p_od date, p_do date)
returns table (mesic date, holic text, provozovna text, rezervaci int, hodin numeric, zakazniku int,
               najem_min numeric, najem_max numeric)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  select n.mesic, n.holic, n.provozovna, n.rezervaci::int, n.hodin, n.zakazniku::int, n.castka_min, n.castka_max
  from analytika.v_najem_dnes n
  where n.holic is not null and n.mesic >= date_trunc('month', p_od)::date and n.mesic <= p_do
  order by 1, 3, 2;
end $$;

revoke all on function analytika.moje_role(), analytika.over_pristup(text[]) from public, anon, authenticated;
revoke all on function public.prehled_role(), public.prehled_provozovny(),
  public.prehled_obsazenost(date, date), public.prehled_holici_mesic(date, date) from public, anon;
grant execute on function public.prehled_role(), public.prehled_provozovny(),
  public.prehled_obsazenost(date, date), public.prehled_holici_mesic(date, date) to authenticated;

-- Admin se vkládá ručně v SQL Editoru (e-mail nepatří do veřejného repozitáře):
-- insert into analytika.opravneni (email, role, poznamka) values ('<e-mail>', 'admin', 'Keksa, TBDB');
