-- Přehledy: dohody s holiči (výhradní křeslo, pevná částka), obsazenost sdílených křesel a výchozí stav (Keksa 27. 11. 2026).
-- Podklad: schůzka s Tomem 26. 11. 2026 – ve Zverimexu jsou 2 ze 4 křesel pronajatá výhradně za 10 000 Kč měsíčně.
-- Které holiče se to týká, zadává admin nebo majitel na stránce přehledů (jména holičů do repozitáře nepatří).

-- ===== dohody s holiči =====
create function public.prehled_dohody()
returns table (id int, holic text, zpusob text, castka numeric, plati_od date, plati_do date, poznamka text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query select d.id, h.jmeno, d.zpusob, d.castka, d.plati_od, d.plati_do, d.poznamka
  from analytika.najem_dohoda d join analytika.holic h on h.id = d.holic_id order by h.jmeno, d.plati_od;
end $$;

create function public.prehled_ulozit_dohodu(p_holic text, p_zpusob text, p_castka numeric, p_plati_od date,
                                             p_plati_do date default null, p_poznamka text default null) returns int
language plpgsql security definer set search_path = '' as $$
declare v_holic int; v_id int;
begin
  perform analytika.over_pristup();
  select h.id into v_holic from analytika.holic h where h.jmeno = p_holic;
  if v_holic is null then raise exception 'Holič neexistuje.'; end if;
  if p_zpusob not in ('kreslo_pro_sebe', 'pevna_castka') then raise exception 'Způsob: kreslo_pro_sebe nebo pevna_castka.'; end if;
  if p_castka is null or p_castka < 0 or p_castka > 100000 then raise exception 'Částka 0 až 100 000 Kč.'; end if;
  if p_plati_od is null or (p_plati_do is not null and p_plati_do < p_plati_od) then raise exception 'Chybné období dohody.'; end if;
  insert into analytika.najem_dohoda (holic_id, zpusob, castka, plati_od, plati_do, zdroj, poznamka)
  values (v_holic, p_zpusob, p_castka, p_plati_od, p_plati_do, 'přehledy: ' || lower(auth.jwt() ->> 'email'), left(p_poznamka, 300))
  returning id into v_id;
  return v_id;
end $$;

create function public.prehled_smazat_dohodu(p_id int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform analytika.over_pristup();
  delete from analytika.najem_dohoda where id = p_id;
end $$;

-- ===== obsazenost jen sdílených křesel =====
-- Jako prehled_obsazenost, ale bez rezervací holičů, kteří mají v den rezervace výhradní křeslo.
create function public.prehled_obsazenost_sdilena(p_od date, p_do date)
returns table (provozovna text, den int, hodina int, prumer numeric, spicka numeric)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  with dny as (
    select extract(isodow from d)::int as den, count(*) as n
    from generate_series(p_od::timestamp, p_do::timestamp, interval '1 day') d group by 1
  ), r as (
    select v.* from analytika.v_rezervace v
    where v.provozovna is not null and v.zacatek >= p_od and v.zacatek < p_do + 1
      and not exists (select 1 from analytika.najem_dohoda d where d.holic_id = v.holic_id and d.zpusob = 'kreslo_pro_sebe'
                      and v.zacatek::date >= d.plati_od and (d.plati_do is null or v.zacatek::date <= d.plati_do))
  ), h as (
    select r.provozovna, date_trunc('hour', g) as hodina,
           sum(extract(epoch from (least(r.konec, g + interval '1 hour') - greatest(r.zacatek, g)))) / 3600.0 as obs
    from r, generate_series(date_trunc('hour', r.zacatek), r.konec - interval '1 second', interval '1 hour') g
    group by 1, 2
  ), o as (
    select h.provozovna, extract(isodow from h.hodina)::int as den, extract(hour from h.hodina)::int as hodina,
           sum(h.obs) as s, max(h.obs) as m
    from h group by 1, 2, 3
  )
  select o.provozovna, o.den, o.hodina, round((o.s / dny.n)::numeric, 2), round(o.m::numeric, 2)
  from o join dny on dny.den = o.den
  order by 1, 2, 3;
end $$;

-- ===== výchozí stav (bod 0) =====
create function public.prehled_vychozi_stav()
returns table (ukazatel text, provozovna text, obdobi_od date, obdobi_do date, hodnota numeric, vytvoreno timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query select v.ukazatel, p.nazev, v.obdobi_od, v.obdobi_do, v.hodnota, v.vytvoreno
  from analytika.vychozi_stav v left join analytika.provozovna p on p.id = v.provozovna_id order by 1, 2;
end $$;

-- p_hodnoty: [{"ukazatel":"vytizenost_7_22","provozovna":"Old Place","hodnota":36.0}, ...]
-- Uložené ukazatele nahradí dřívější hodnoty stejného ukazatele (ostatní ukazatele zůstanou).
create function public.prehled_ulozit_vychozi_stav(p_od date, p_do date, p_hodnoty jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare v_n int;
begin
  perform analytika.over_pristup();
  if jsonb_typeof(p_hodnoty) is distinct from 'array' or jsonb_array_length(p_hodnoty) not between 1 and 200 then
    raise exception 'Chybné hodnoty výchozího stavu.';
  end if;
  delete from analytika.vychozi_stav v
  where v.ukazatel in (select x ->> 'ukazatel' from jsonb_array_elements(p_hodnoty) x);
  insert into analytika.vychozi_stav (ukazatel, provozovna_id, obdobi_od, obdobi_do, hodnota)
  select left(x ->> 'ukazatel', 60), p.id, p_od, p_do, (x ->> 'hodnota')::numeric
  from jsonb_array_elements(p_hodnoty) x left join analytika.provozovna p on p.nazev = x ->> 'provozovna';
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke all on function public.prehled_dohody(), public.prehled_ulozit_dohodu(text, text, numeric, date, date, text),
  public.prehled_smazat_dohodu(int), public.prehled_obsazenost_sdilena(date, date),
  public.prehled_vychozi_stav(), public.prehled_ulozit_vychozi_stav(date, date, jsonb) from public, anon;
grant execute on function public.prehled_dohody(), public.prehled_ulozit_dohodu(text, text, numeric, date, date, text),
  public.prehled_smazat_dohodu(int), public.prehled_obsazenost_sdilena(date, date),
  public.prehled_vychozi_stav(), public.prehled_ulozit_vychozi_stav(date, date, jsonb) to authenticated;
