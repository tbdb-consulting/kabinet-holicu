-- Dotazník zájmu holičů o bloky křesel (T26-09-1 Kabinet holičů)
-- Odpovědi se ukládají jen přes funkci odeslat_dotaznik; tabulku nikdo z webu nečte ani nemění.

create table public.dotaznik_odpoved (
  id          bigint generated always as identity primary key,
  vytvoreno   timestamptz not null default now(),
  jmeno       text not null check (char_length(jmeno) between 1 and 60),
  provozovna  text not null check (provozovna in ('OP', 'ZV', 'OBE')),
  hodin       integer not null check (hodin between 0 and 300),
  prani       jsonb not null,
  poznamka    text check (poznamka is null or char_length(poznamka) <= 1000)
);

comment on table public.dotaznik_odpoved is
  'Odpovědi holičů: hodiny měsíčně a přání Po–Pá × bloky R (8–12), S (12–16), O (16–20); 2 = chci, 1 = můžu, 0 = nemůžu. Platí poslední odpověď podle jména.';

alter table public.dotaznik_odpoved enable row level security;
-- žádná pravidla (policies) = anon ani přihlášení uživatelé tabulku přímo nevidí

create or replace function public.odeslat_dotaznik(
  p_jmeno text, p_provozovna text, p_hodin integer, p_prani jsonb, p_poznamka text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d text;
  b text;
  v jsonb;
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
  -- omezení zahlcení: nejvýš 20 odpovědí za minutu celkem
  if (select count(*) from public.dotaznik_odpoved where vytvoreno > now() - interval '1 minute') >= 20 then
    raise exception 'příliš mnoho odpovědí, zkuste to za chvíli';
  end if;
  insert into public.dotaznik_odpoved (jmeno, provozovna, hodin, prani, poznamka)
  values (trim(p_jmeno), p_provozovna, p_hodin, p_prani, nullif(trim(p_poznamka), ''));
end;
$$;

revoke all on function public.odeslat_dotaznik(text, text, integer, jsonb, text) from public;
grant execute on function public.odeslat_dotaznik(text, text, integer, jsonb, text) to anon, authenticated;

-- Vyhodnocení (spouští jen TBDB přes správcovský přístup): poslední odpověď každého holiče
create or replace view public.dotaznik_posledni
with (security_invoker = true) as
select distinct on (lower(jmeno)) *
from public.dotaznik_odpoved
order by lower(jmeno), vytvoreno desc;

revoke all on public.dotaznik_posledni from anon, authenticated;
