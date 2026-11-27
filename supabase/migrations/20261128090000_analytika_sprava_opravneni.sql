-- Přehledy: karta „Uživatelé a práva“ – správa tabulky analytika.opravneni ze stránky (Keksa 27. 11. 2026).
-- Smí jen admin. Pojistky: nejde smazat sám sebe a nejde odebrat ani sesadit posledního admina.
-- E-maily se dál do repozitáře nepíšou, zadávají se jen na stránce.

create function public.prehled_opravneni()
returns table (email text, role text, firma text, poznamka text, vytvoreno timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup(array['admin']);
  return query select o.email, o.role, f.nazev, o.poznamka, o.vytvoreno
  from analytika.opravneni o left join analytika.firma f on f.id = o.firma_id
  order by case o.role when 'admin' then 1 when 'majitel' then 2 else 3 end, o.email;
end $$;

create function public.prehled_ulozit_opravneni(p_email text, p_role text, p_firma text default null, p_poznamka text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(p_email)); v_firma int; v_stara text;
begin
  perform analytika.over_pristup(array['admin']);
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 200 then
    raise exception 'Neplatný e-mail.';
  end if;
  if p_role not in ('admin', 'majitel', 'odpovedny') then raise exception 'Role: admin, majitel nebo odpovedny.'; end if;
  if p_firma is not null and p_firma <> '' then
    select f.id into v_firma from analytika.firma f where f.nazev = p_firma;
    if v_firma is null then raise exception 'Firma neexistuje.'; end if;
  end if;
  select o.role into v_stara from analytika.opravneni o where o.email = v_email;
  if v_stara = 'admin' and p_role <> 'admin'
     and (select count(*) from analytika.opravneni o where o.role = 'admin') <= 1 then
    raise exception 'Musí zůstat aspoň jeden admin.';
  end if;
  insert into analytika.opravneni (email, role, firma_id, poznamka)
  values (v_email, p_role, v_firma, nullif(left(trim(coalesce(p_poznamka, '')), 200), ''))
  on conflict (email) do update set role = excluded.role, firma_id = excluded.firma_id, poznamka = excluded.poznamka;
end $$;

create function public.prehled_smazat_opravneni(p_email text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(p_email));
begin
  perform analytika.over_pristup(array['admin']);
  if v_email = lower(auth.jwt() ->> 'email') then raise exception 'Sám sebe smazat nejde.'; end if;
  if (select o.role from analytika.opravneni o where o.email = v_email) = 'admin'
     and (select count(*) from analytika.opravneni o where o.role = 'admin') <= 1 then
    raise exception 'Musí zůstat aspoň jeden admin.';
  end if;
  delete from analytika.opravneni where email = v_email;
end $$;

revoke all on function public.prehled_opravneni(), public.prehled_ulozit_opravneni(text, text, text, text),
  public.prehled_smazat_opravneni(text) from public, anon;
grant execute on function public.prehled_opravneni(), public.prehled_ulozit_opravneni(text, text, text, text),
  public.prehled_smazat_opravneni(text) to authenticated;
