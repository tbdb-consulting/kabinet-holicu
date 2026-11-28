-- Rozvrh obsazenosti křesel z importu Reservanta (Keksa 28. 11. 2026).
-- Čte admin, majitel a odpovědný pracovník – jen oni vidí jména zákazníků („Jan Nov“),
-- výběr z Otázky\261128_import_z_reservanta.html, bod 3.
-- Vrací jeden jsonb (API vrací najednou nejvýš 1 000 řádků, týden obou provozoven jich může mít víc).

create function public.prehled_rozvrh(p_od date, p_do date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb;
begin
  perform analytika.over_pristup(array['admin', 'majitel', 'odpovedny']);
  if p_do < p_od or p_do - p_od > 62 then
    raise exception 'Rozvrh jde zobrazit nejvýš za 2 měsíce.';
  end if;
  select jsonb_build_object(
    'kresla', (select coalesce(jsonb_agg(jsonb_build_object('provozovna', p.nazev, 'kresel',
                 (select k.kresel from analytika.kapacita k where k.provozovna_id = p.id
                   and (k.plati_do is null or k.plati_do >= current_date) order by k.plati_od desc limit 1)) order by p.id), '[]')
               from analytika.provozovna p join analytika.firma f on f.id = p.firma_id
               where f.nazev = 'Kabinet holičů'),
    'data_od', (select min(o.zacatek) from analytika.reservanto_obsazenost o),
    'data_do', (select max(o.zacatek) from analytika.reservanto_obsazenost o),
    'radky', (select coalesce(jsonb_agg(jsonb_build_object(
                 'z', to_char(o.zacatek, 'YYYY-MM-DD"T"HH24:MI'),
                 'h', coalesce(h.jmeno, o.holic_zdroj),
                 'p', pr.nazev,
                 'k', o.zakaznik) order by o.zacatek, coalesce(h.jmeno, o.holic_zdroj)), '[]')
              from analytika.reservanto_obsazenost o
              left join analytika.holic_alias a on upper(a.alias) = o.holic_zdroj
              left join analytika.holic h on h.id = a.holic_id
              left join analytika.holic_provozovna hp on hp.holic_id = h.id and hp.plati_do is null
              left join analytika.provozovna pr on pr.id = hp.provozovna_id
              where o.zacatek >= p_od and o.zacatek < p_do + 1))
  into v;
  return v;
end $$;

revoke all on function public.prehled_rozvrh(date, date) from public, anon;
grant execute on function public.prehled_rozvrh(date, date) to authenticated;
