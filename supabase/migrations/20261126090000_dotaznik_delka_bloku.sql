-- Dotazník: holič si nejdřív vybere délku bloku (3, 4, 6 nebo 12 hodin) a vyplní jen jednu mřížku
-- pro tuto délku (Keksa 26. 11. 2026). Dřív se vyplňovaly dvě mřížky (4h = prani, 3h = prani3).
-- Nové sloupce: blok (délka bloku v hodinách), prani_blok {"Po": {"8": 3, "12": 2, ...}, ...},
-- klíč = začátek bloku. Bloky: 3 h 8/11/14/17, 4 h 8/12/16, 6 h 8/14, 12 h 8 (všední dny 8–20).
-- prani a prani3 zůstávají kvůli starším odpovědím, nově jsou nepovinné. V tabulce zatím nejsou žádné odpovědi.

alter table public.dotaznik_odpoved add column blok integer;
alter table public.dotaznik_odpoved add column prani_blok jsonb;
alter table public.dotaznik_odpoved alter column prani drop not null;
-- Sekce 7: místo hodin za poslední 3 měsíce se ptáme na obvyklý počet hodin za měsíc (Keksa 26. 11. 2026).
alter table public.dotaznik_odpoved add column hodin_prumer integer;

comment on column public.dotaznik_odpoved.blok is
  'Délka bloku, ve které chce holič stříhat: 3, 4, 6 nebo 12 hodin.';
comment on column public.dotaznik_odpoved.hodin_prumer is
  'Kolik hodin měsíčně holič teď obvykle stříhá (průměr za poslední dobu, odhad). Dřív hodin_3m = hodiny za 3 měsíce celkem.';
comment on column public.dotaznik_odpoved.prani_blok is
  'Přání v blocích zvolené délky Po–Pá, klíč = začátek bloku (3 h: 8, 11, 14, 17; 4 h: 8, 12, 16; 6 h: 8, 14; 12 h: 8); 3 = určitě chci, 2 = spíše chci, 1 = spíše nechci, 0 = určitě nechci.';

drop function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb, integer, integer, integer, text, jsonb, jsonb, jsonb);

create function public.odeslat_dotaznik(
  p_jmeno text, p_provozovna text, p_hodin integer, p_prani jsonb default null,
  p_poznamka text default null, p_delka jsonb default null, p_prani3 jsonb default null,
  p_smen integer default null, p_odhad_volno integer default null, p_hodin_3m integer default null,
  p_sloty_stav text default null, p_sloty jsonb default null, p_dalsi jsonb default null,
  p_nemuzu jsonb default null, p_blok integer default null, p_prani_blok jsonb default null,
  p_hodin_prumer integer default null)
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
  zac int[];
begin
  -- nově: délka bloku + jedna mřížka; postaru: mřížka 4h (+ případně 3h)
  if p_blok is not null or p_prani_blok is not null then
    zac := case p_blok when 3 then array[8,11,14,17] when 4 then array[8,12,16]
                       when 6 then array[8,14] when 12 then array[8] end;
    if zac is null then
      raise exception 'chybná délka bloku';
    end if;
    if jsonb_typeof(p_prani_blok) is distinct from 'object' then
      raise exception 'prani_blok musí být objekt';
    end if;
    foreach d in array array['Po','Ut','St','Ct','Pa'] loop
      if jsonb_typeof(p_prani_blok -> d) is distinct from 'object'
         or (select count(*) from jsonb_object_keys(p_prani_blok -> d)) <> array_length(zac, 1) then
        raise exception 'chybí nebo přebývá volba u dne %', d;
      end if;
      foreach mi in array zac loop
        v := p_prani_blok -> d -> mi::text;
        if v is null or jsonb_typeof(v) <> 'number' or (v::text)::int not in (0, 1, 2, 3) then
          raise exception 'chybí nebo je chybná volba % %', d, mi;
        end if;
      end loop;
    end loop;
  else
    if jsonb_typeof(p_prani) is distinct from 'object' then
      raise exception 'prani musí být objekt';
    end if;
    foreach d in array array['Po','Ut','St','Ct','Pa'] loop
      foreach b in array array['R','S','O'] loop
        v := p_prani -> d -> b;
        if v is null or jsonb_typeof(v) <> 'number' or (v::text)::int not in (0, 1, 2, 3) then
          raise exception 'chybí nebo je chybná volba % %', d, b;
        end if;
      end loop;
    end loop;
  end if;
  if p_prani3 is not null then
    if jsonb_typeof(p_prani3) <> 'object' then
      raise exception 'prani3 musí být objekt';
    end if;
    foreach d in array array['Po','Ut','St','Ct','Pa'] loop
      foreach b in array array['A','B','C','D'] loop
        v := p_prani3 -> d -> b;
        if v is null or jsonb_typeof(v) <> 'number' or (v::text)::int not in (0, 1, 2, 3) then
          raise exception 'chybí nebo je chybná volba 3h % %', d, b;
        end if;
      end loop;
    end loop;
  end if;
  if p_hodin is null or p_hodin < 0 or p_hodin > 300 then
    raise exception 'chybný počet hodin';
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
  if p_hodin_prumer is not null and (p_hodin_prumer < 0 or p_hodin_prumer > 300) then
    raise exception 'chybné obvyklé hodiny za měsíc';
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
  if p_nemuzu is not null then
    if jsonb_typeof(p_nemuzu) <> 'object' then
      raise exception 'nemuzu musí být objekt';
    end if;
    for d in select jsonb_object_keys(p_nemuzu) loop
      if d not in ('Po','Ut','St','Ct','Pa') or jsonb_typeof(p_nemuzu -> d) <> 'array'
         or jsonb_array_length(p_nemuzu -> d) > 15 then
        raise exception 'chybný den nemůže %', d;
      end if;
      if exists (select 1 from jsonb_array_elements(p_nemuzu -> d) x
                 where jsonb_typeof(x) <> 'number' or (x::text)::numeric not between 7 and 21) then
        raise exception 'chybná hodina nemůže %', d;
      end if;
    end loop;
  end if;
  -- omezení zahlcení: nejvýš 20 odpovědí za minutu celkem
  if (select count(*) from public.dotaznik_odpoved where vytvoreno > now() - interval '1 minute') >= 20 then
    raise exception 'příliš mnoho odpovědí, zkuste to za chvíli';
  end if;
  insert into public.dotaznik_odpoved (jmeno, provozovna, hodin, prani, poznamka, delka, prani3,
                                       smen, odhad_volno, hodin_3m, sloty_stav, sloty, dalsi, nemuzu,
                                       blok, prani_blok, hodin_prumer)
  values (trim(p_jmeno), p_provozovna, p_hodin, p_prani, nullif(trim(p_poznamka), ''), p_delka, p_prani3,
          p_smen, p_odhad_volno, p_hodin_3m, p_sloty_stav, p_sloty, p_dalsi, p_nemuzu,
          p_blok, p_prani_blok, p_hodin_prumer);
end;
$$;

revoke all on function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb, integer, integer, integer, text, jsonb, jsonb, jsonb, integer, jsonb, integer) from public;
grant execute on function public.odeslat_dotaznik(text, text, integer, jsonb, text, jsonb, jsonb, integer, integer, integer, text, jsonb, jsonb, jsonb, integer, jsonb, integer) to anon, authenticated;

-- pohled (select *) se při přidání sloupce sám nerozšíří
create or replace view public.dotaznik_posledni
with (security_invoker = true) as
select distinct on (lower(jmeno)) *
from public.dotaznik_odpoved
order by lower(jmeno), vytvoreno desc;

revoke all on public.dotaznik_posledni from anon, authenticated;
