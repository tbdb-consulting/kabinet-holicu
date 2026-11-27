-- Přehledy: ukládání variant nájmu z kalkulačky (Keksa 27. 11. 2026).
-- Varianty jsou v analytika.scenar (parametry jsonb), vidí a mění je admin a majitel přes funkce prehled_*.
-- Parametry hodinové varianty: {"typ":"hodiny","vychozi":50,"koef":1.2,"pausal":0,"zmena":0,
--   "pasma":[{"dny":"1-5","od":9,"do":18,"prov":"","sazba":60}, ...]}
-- Parametry varianty s pásmy: {"typ":"pasma","zmena":0,"pasma":[{"od":0,"do":60,"min":3500,"max":3500}, ...]}

alter table analytika.scenar add column autor text, add column upraveno timestamptz not null default now();

create function public.prehled_scenare()
returns table (id int, nazev text, parametry jsonb, autor text, upraveno timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query select s.id, s.nazev, s.parametry, s.autor, s.upraveno from analytika.scenar s order by s.id;
end $$;

create function public.prehled_ulozit_scenar(p_id int, p_nazev text, p_parametry jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare v_id int;
begin
  perform analytika.over_pristup();
  if p_nazev is null or char_length(trim(p_nazev)) not between 1 and 80 then
    raise exception 'Název varianty: 1 až 80 znaků.';
  end if;
  if jsonb_typeof(p_parametry) is distinct from 'object' or length(p_parametry::text) > 20000
     or p_parametry ->> 'typ' not in ('hodiny', 'pasma') then
    raise exception 'Chybné parametry varianty.';
  end if;
  if p_id is null then
    insert into analytika.scenar (nazev, parametry, autor) values (trim(p_nazev), p_parametry, lower(auth.jwt() ->> 'email'))
    returning id into v_id;
  else
    update analytika.scenar set nazev = trim(p_nazev), parametry = p_parametry, autor = lower(auth.jwt() ->> 'email'), upraveno = now()
    where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Varianta neexistuje.'; end if;
  end if;
  return v_id;
end $$;

create function public.prehled_smazat_scenar(p_id int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform analytika.over_pristup();
  delete from analytika.scenar where id = p_id;
end $$;

revoke all on function public.prehled_scenare(), public.prehled_ulozit_scenar(int, text, jsonb),
  public.prehled_smazat_scenar(int) from public, anon;
grant execute on function public.prehled_scenare(), public.prehled_ulozit_scenar(int, text, jsonb),
  public.prehled_smazat_scenar(int) to authenticated;
