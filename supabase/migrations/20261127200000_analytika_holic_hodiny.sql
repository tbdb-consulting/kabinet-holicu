-- Simulace nájmu: odstříhané hodiny holičů po dnech v týdnu a hodinách (Keksa 27. 11. 2026).
-- Rezervace rozpadlé na celé hodiny (stejně jako v_obsazenost_hodiny), součet za období.
-- Jeden řádek na holiče, hodiny jako pole [[den, hodina, hodin], ...] (API vrací najednou nejvýš 1 000 řádků).
-- Slouží k výpočtu, kolik by jednotlivý holič platil při hodinových sazbách.

drop function if exists public.prehled_holic_hodiny(date, date);

create function public.prehled_holic_hodiny(p_od date, p_do date)
returns table (holic text, provozovna text, hodiny jsonb)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  with h as (
    select r.holic, r.provozovna, extract(isodow from g)::int as den, extract(hour from g)::int as hod,
           round((sum(extract(epoch from (least(r.konec, g + interval '1 hour') - greatest(r.zacatek, g)))) / 3600.0)::numeric, 2) as hodin
    from analytika.v_rezervace r,
         generate_series(date_trunc('hour', r.zacatek), r.konec - interval '1 second', interval '1 hour') g
    where r.holic is not null and r.provozovna is not null and r.zacatek >= p_od and r.zacatek < p_do + 1
    group by 1, 2, 3, 4
  )
  select h.holic, h.provozovna, jsonb_agg(jsonb_build_array(h.den, h.hod, h.hodin) order by h.den, h.hod)
  from h group by 1, 2 order by 1, 2;
end $$;

revoke all on function public.prehled_holic_hodiny(date, date) from public, anon;
grant execute on function public.prehled_holic_hodiny(date, date) to authenticated;
