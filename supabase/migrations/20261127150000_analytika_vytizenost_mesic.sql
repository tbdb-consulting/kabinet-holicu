-- Přehledy: vytíženost křesel po měsících v procentech, porovnání provozoven (Keksa 27. 11. 2026).
-- Vytíženost = obsazené hodiny křesel Po–Pá 9–18 h / (pracovní dny v měsíci × 9 h × počet křesel).
-- Svátky se nepočítají zvlášť. Provozovny bez známého počtu křesel (franšízy) se nevrací.

create function public.prehled_vytizenost_mesic(p_od date, p_do date)
returns table (mesic date, provozovna text, kresel int, obsazeno_h numeric, kapacita_h numeric, procent numeric)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  with o as (
    select v.provozovna_id, v.provozovna, date_trunc('month', v.hodina)::date as mesic, sum(v.obsazeno_kresel) as s
    from analytika.v_obsazenost_hodiny v
    where v.provozovna_id is not null and v.hodina >= p_od and v.hodina < p_do + 1
      and extract(isodow from v.hodina) <= 5 and extract(hour from v.hodina) between 9 and 17
    group by 1, 2, 3
  ), dny as (
    select date_trunc('month', d)::date as mesic, count(*) filter (where extract(isodow from d) <= 5) as n
    from generate_series(p_od::timestamp, p_do::timestamp, interval '1 day') d group by 1
  )
  select o.mesic, o.provozovna, k.kresel, round(o.s, 1), (dny.n * 9 * k.kresel)::numeric,
         round(100 * o.s / nullif(dny.n * 9 * k.kresel, 0), 1)
  from o join dny on dny.mesic = o.mesic
  join analytika.kapacita k on k.provozovna_id = o.provozovna_id
       and k.plati_od <= o.mesic and (k.plati_do is null or k.plati_do >= o.mesic)
  order by 1, 2;
end $$;

revoke all on function public.prehled_vytizenost_mesic(date, date) from public, anon;
grant execute on function public.prehled_vytizenost_mesic(date, date) to authenticated;
