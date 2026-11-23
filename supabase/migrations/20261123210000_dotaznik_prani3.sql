-- Dotazník: přání i ve 3hodinových blocích A (8–11), B (11–14), C (14–17), D (17–20) (Keksa 23. 11. 2026)
-- Starší verze stránky (bez p_prani3) ukládají dál, prani3 = null.

alter table public.dotaznik_odpoved add column prani3 jsonb;

comment on column public.dotaznik_odpoved.prani3 is
  'Přání ve 3h blocích Po–Pá × A (8–11), B (11–14), C (14–17), D (17–20); 2 = chci, 1 = můžu, 0 = nemůžu.';

drop function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb);

create function public.odeslat_dotaznik(
  p_jmeno text, p_provozovna text, p_hodin integer, p_prani jsonb,
  p_poznamka text default null, p_delka jsonb default null, p_prani3 jsonb default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d text;
  b text;
  v jsonb;
  mi int;
  ma int;
begin
  if jsonb_typeof(p_prani) <> 'object' then
    raise exception 'prani musí být objekt';
  end if;
  foreach d in array array['Po','Ut','St','Ct','Pa'] loop
    foreach b in array array['R','S','O'] loop
      v := p_prani -> d -> b;
      if v is null or jsonb_typeof(v) <> 'number' or (v::text)::int not in (0, 1, 2) then
        raise exception 'chybí nebo je chybná volba % %', d, b;
      end if;
    end loop;
  end loop;
  if p_prani3 is not null then
    if jsonb_typeof(p_prani3) <> 'object' then
      raise exception 'prani3 musí být objekt';
    end if;
    foreach d in array array['Po','Ut','St','Ct','Pa'] loop
      foreach b in array array['A','B','C','D'] loop
        v := p_prani3 -> d -> b;
        if v is null or jsonb_typeof(v) <> 'number' or (v::text)::int not in (0, 1, 2) then
          raise exception 'chybí nebo je chybná volba 3h % %', d, b;
        end if;
      end loop;
    end loop;
  end if;
  if p_delka is not null then
    if jsonb_typeof(p_delka) <> 'object' then
      raise exception 'delka musí být objekt';
    end if;
    for d in select jsonb_object_keys(p_delka) loop
      if d not in ('Po','Ut','St','Ct','Pa') then
        raise exception 'neznámý den %', d;
      end if;
      if jsonb_typeof(p_delka -> d -> 'min') <> 'number' or jsonb_typeof(p_delka -> d -> 'max') <> 'number' then
        raise exception 'chybí délka u dne %', d;
      end if;
      mi := (p_delka -> d ->> 'min')::int;
      ma := (p_delka -> d ->> 'max')::int;
      if mi < 1 or ma > 12 or mi > ma then
        raise exception 'chybná délka u dne %', d;
      end if;
    end loop;
  end if;
  -- omezení zahlcení: nejvýš 20 odpovědí za minutu celkem
  if (select count(*) from public.dotaznik_odpoved where vytvoreno > now() - interval '1 minute') >= 20 then
    raise exception 'příliš mnoho odpovědí, zkuste to za chvíli';
  end if;
  insert into public.dotaznik_odpoved (jmeno, provozovna, hodin, prani, poznamka, delka, prani3)
  values (trim(p_jmeno), p_provozovna, p_hodin, p_prani, nullif(trim(p_poznamka), ''), p_delka, p_prani3);
end;
$$;

revoke all on function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb) from public;
grant execute on function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb) to anon, authenticated;

-- pohled (select *) se při přidání sloupce sám nerozšíří
create or replace view public.dotaznik_posledni
with (security_invoker = true) as
select distinct on (lower(jmeno)) *
from public.dotaznik_odpoved
order by lower(jmeno), vytvoreno desc;

revoke all on public.dotaznik_posledni from anon, authenticated;
