-- Přehledy / EET: počet rezervací holičů podle typu střihu (Keksa 27. 11. 2026).
-- Reservanto rozlišuje jen „Dámský střih“ a „Pánský střih“; většina rezervací je obecná „Střih – Kabinet holičů“ (neurčeno).
-- Ceny určuje uživatel na stránce (Keksa 27. 11. 2026: pánský 500 Kč, dámský 650 Kč), částky z Reservanta se nepoužívají.

create function public.prehled_holici_sluzby(p_od date, p_do date)
returns table (holic text, provozovna text, damskych int, panskych int, neurcenych int)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup();
  return query
  select r.holic, r.provozovna,
         (count(*) filter (where r.sluzba ilike '%dámsk%'))::int,
         (count(*) filter (where r.sluzba ilike '%pánsk%'))::int,
         (count(*) filter (where r.sluzba is null or (r.sluzba not ilike '%dámsk%' and r.sluzba not ilike '%pánsk%')))::int
  from analytika.v_rezervace r
  where r.holic is not null and r.zacatek >= p_od and r.zacatek < p_do + 1
  group by 1, 2 order by 1, 2;
end $$;

revoke all on function public.prehled_holici_sluzby(date, date) from public, anon;
grant execute on function public.prehled_holici_sluzby(date, date) to authenticated;
