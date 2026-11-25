-- Dotazník: směny za měsíc, odhady (volná křesla, hodiny za 3 měsíce), obsazené hodiny
-- po týdnech a zájem o funkce dalších fází (Keksa 25. 11. 2026).
-- Starší verze stránky ukládají dál, nové sloupce = null.

alter table public.dotaznik_odpoved
  add column smen integer,
  add column odhad_volno integer,
  add column hodin_3m integer,
  add column sloty_stav text,
  add column sloty jsonb,
  add column dalsi jsonb;

comment on column public.dotaznik_odpoved.smen is 'Kolik směn (rezervací křesla v kuse) za měsíc holič chce.';
comment on column public.dotaznik_odpoved.odhad_volno is 'Odhad holiče: kolik % křesel je v jeho provozovně teď běžně volných (null = neví).';
comment on column public.dotaznik_odpoved.hodin_3m is 'Odhad holiče: odpracované hodiny za poslední 3 měsíce celkem (null = neví).';
comment on column public.dotaznik_odpoved.sloty_stav is 'ano = vyplnil obsazené hodiny, ne = přeskočil, null = neodpověděl.';
comment on column public.dotaznik_odpoved.sloty is 'Obsazené hodiny: {"YYYY-MM-DD" (pondělí): {"Po": [9, 10], ...}}, hodina = začátek 7–21, nejvýš 13 týdnů.';
comment on column public.dotaznik_odpoved.dalsi is 'Zájem o další fáze: {"funkce": [kódy], "napad": text}.';

drop function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb);

create function public.odeslat_dotaznik(
  p_jmeno text, p_provozovna text, p_hodin integer, p_prani jsonb,
  p_poznamka text default null, p_delka jsonb default null, p_prani3 jsonb default null,
  p_smen integer default null, p_odhad_volno integer default null, p_hodin_3m integer default null,
  p_sloty_stav text default null, p_sloty jsonb default null, p_dalsi jsonb default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d text;
  b text;
  w text;
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
  if p_smen is not null and (p_smen < 0 or p_smen > 60) then
    raise exception 'chybný počet směn';
  end if;
  if p_odhad_volno is not null and (p_odhad_volno < 0 or p_odhad_volno > 100) then
    raise exception 'chybný odhad volných křesel';
  end if;
  if p_hodin_3m is not null and (p_hodin_3m < 0 or p_hodin_3m > 1500) then
    raise exception 'chybné hodiny za 3 měsíce';
  end if;
  if p_sloty_stav is not null and p_sloty_stav not in ('ano', 'ne') then
    raise exception 'chybný stav obsazených hodin';
  end if;
  if p_sloty is not null then
    if jsonb_typeof(p_sloty) <> 'object' or (select count(*) from jsonb_object_keys(p_sloty)) > 13 then
      raise exception 'sloty musí být objekt s nejvýš 13 týdny';
    end if;
    for w in select jsonb_object_keys(p_sloty) loop
      if w !~ '^\d{4}-\d{2}-\d{2}$' or jsonb_typeof(p_sloty -> w) <> 'object' then
        raise exception 'chybný týden %', w;
      end if;
      for d in select jsonb_object_keys(p_sloty -> w) loop
        if d not in ('Po','Ut','St','Ct','Pa') or jsonb_typeof(p_sloty -> w -> d) <> 'array'
           or jsonb_array_length(p_sloty -> w -> d) > 15 then
          raise exception 'chybný den % %', w, d;
        end if;
        if exists (select 1 from jsonb_array_elements(p_sloty -> w -> d) x
                   where jsonb_typeof(x) <> 'number' or (x::text)::numeric not between 7 and 21) then
          raise exception 'chybná hodina % %', w, d;
        end if;
      end loop;
    end loop;
  end if;
  if p_dalsi is not null then
    if jsonb_typeof(p_dalsi) <> 'object' or length(p_dalsi::text) > 2000 then
      raise exception 'chybné další fáze';
    end if;
    if p_dalsi ? 'funkce' and (jsonb_typeof(p_dalsi -> 'funkce') <> 'array' or exists (
        select 1 from jsonb_array_elements_text(p_dalsi -> 'funkce') f
        where f not in ('chat','nabidnout','prevzit','moji_zakaznici','zruseni','interval'))) then
      raise exception 'neznámá funkce';
    end if;
  end if;
  -- omezení zahlcení: nejvýš 20 odpovědí za minutu celkem
  if (select count(*) from public.dotaznik_odpoved where vytvoreno > now() - interval '1 minute') >= 20 then
    raise exception 'příliš mnoho odpovědí, zkuste to za chvíli';
  end if;
  insert into public.dotaznik_odpoved (jmeno, provozovna, hodin, prani, poznamka, delka, prani3,
                                       smen, odhad_volno, hodin_3m, sloty_stav, sloty, dalsi)
  values (trim(p_jmeno), p_provozovna, p_hodin, p_prani, nullif(trim(p_poznamka), ''), p_delka, p_prani3,
          p_smen, p_odhad_volno, p_hodin_3m, p_sloty_stav, p_sloty, p_dalsi);
end;
$$;

revoke all on function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb, integer, integer, integer, text, jsonb, jsonb) from public;
grant execute on function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb, integer, integer, integer, text, jsonb, jsonb) to anon, authenticated;

-- pohled (select *) se při přidání sloupce sám nerozšíří
create or replace view public.dotaznik_posledni
with (security_invoker = true) as
select distinct on (lower(jmeno)) *
from public.dotaznik_odpoved
order by lower(jmeno), vytvoreno desc;

revoke all on public.dotaznik_posledni from anon, authenticated;
