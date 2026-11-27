-- NÁVRH – NENASAZOVAT. Přednost holičů při rozdělování směn (Keksa 27. 11. 2026, CLAUDE.md „Přednost holičů…“).
-- Vyzkoušeno v simulaci web/leden-2027.html (část 6). Nasadí se, až bude v aplikaci rozpis křesel a Keksa to schválí.
--
-- Pravidla:
--   * Tom (majitel) může vybrané holiče upřednostnit, nájem se tím nemění.
--   * Pevný blok: holič dostane konkrétní den v týdnu a čas v provozovně na období od–do, ještě před dražbou
--     a rozdělováním podle přání; nikdo jiný ho nedostane.
--   * Úroveň 1–3: při sporu o blok vyhraje vyšší úroveň, ve stejné úrovni rozhoduje dosavadní algoritmus.
--   * Každá přednost má platnost od–do a poznámku; každá změna se zaznamená (kdo, kdy, co předtím a potom).
--   * Přednost vidí a mění jen admin a majitel. Holiči ji nevidí (vidí jen svůj rozpis).
--   * Ruční úprava rozpisu před schválením: viz tabulka rozpis.uprava – pevný blok jde přesunout jen s potvrzením.
--
-- Vazby na analytika.holic a analytika.provozovna jsou dočasné: až vznikne provozní schéma aplikace
-- (firma → provozovna → holič → zákazník), cizí klíče se přesměrují tam. Schéma rozpis není vystavené přes API,
-- web volá jen funkce public.prednost_*, které ověří roli přes analytika.over_pristup().

create schema if not exists rozpis;
revoke all on schema rozpis from public, anon, authenticated;

-- ===== přednost =====
create table rozpis.prednost (
  id bigint generated always as identity primary key,
  holic_id int not null references analytika.holic(id),
  typ text not null check (typ in ('pevny_blok', 'uroven')),
  uroven smallint check (uroven between 1 and 3),                    -- jen typ 'uroven'
  provozovna_id int references analytika.provozovna(id),             -- jen typ 'pevny_blok'
  den_v_tydnu smallint check (den_v_tydnu between 1 and 7),          -- ISO: 1 = pondělí
  cas_od time,                                                        -- jen typ 'pevny_blok', např. 16:00
  cas_do time,                                                        --                          20:00
  plati_od date not null,
  plati_do date not null,
  poznamka text not null check (length(trim(poznamka)) between 1 and 300),
  autor text not null default lower(coalesce(auth.jwt() ->> 'email', 'administrace')),
  vytvoreno timestamptz not null default now(),
  upraveno timestamptz not null default now(),
  check (plati_do >= plati_od),
  check (
    (typ = 'uroven' and uroven is not null and provozovna_id is null and den_v_tydnu is null and cas_od is null and cas_do is null)
    or
    (typ = 'pevny_blok' and uroven is null and provozovna_id is not null and den_v_tydnu is not null
     and cas_od is not null and cas_do is not null and cas_do > cas_od)
  )
);
create index on rozpis.prednost (holic_id, plati_od, plati_do);
create index on rozpis.prednost (provozovna_id, den_v_tydnu) where typ = 'pevny_blok';

-- ===== záznam změn přednosti (plní trigger, nikdo do něj nepíše ručně) =====
create table rozpis.prednost_zmena (
  id bigint generated always as identity primary key,
  prednost_id bigint not null,                    -- bez cizího klíče, aby záznam zůstal i po smazání přednosti
  akce text not null check (akce in ('pridano', 'zmeneno', 'smazano')),
  pred jsonb,                                     -- řádek před změnou (null u přidání)
  po jsonb,                                       -- řádek po změně (null u smazání)
  kdo text not null,
  kdy timestamptz not null default now()
);
create index on rozpis.prednost_zmena (prednost_id, kdy);

create function rozpis.zaznamenej_prednost() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_kdo text := lower(coalesce(auth.jwt() ->> 'email', 'administrace'));
begin
  if tg_op = 'INSERT' then
    insert into rozpis.prednost_zmena (prednost_id, akce, pred, po, kdo) values (new.id, 'pridano', null, to_jsonb(new), v_kdo);
    return new;
  elsif tg_op = 'UPDATE' then
    new.upraveno := now();
    insert into rozpis.prednost_zmena (prednost_id, akce, pred, po, kdo) values (new.id, 'zmeneno', to_jsonb(old), to_jsonb(new), v_kdo);
    return new;
  else
    insert into rozpis.prednost_zmena (prednost_id, akce, pred, po, kdo) values (old.id, 'smazano', to_jsonb(old), null, v_kdo);
    return old;
  end if;
end $$;
create trigger prednost_zaznam_ins after insert on rozpis.prednost for each row execute function rozpis.zaznamenej_prednost();
create trigger prednost_zaznam_upd before update on rozpis.prednost for each row execute function rozpis.zaznamenej_prednost();
create trigger prednost_zaznam_del after delete on rozpis.prednost for each row execute function rozpis.zaznamenej_prednost();

-- ===== ruční úpravy rozpisu před schválením =====
-- Jedna úprava = jeden blok jednoho křesla v jeden den. Přesun pevného bloku musí mít potvrzeno = true.
create table rozpis.uprava (
  id bigint generated always as identity primary key,
  mesic date not null check (extract(day from mesic) = 1),            -- měsíc rozpisu
  provozovna_id int not null references analytika.provozovna(id),
  den date not null,
  cas_od time not null,
  cas_do time not null check (cas_do > cas_od),
  kreslo smallint not null check (kreslo > 0),
  holic_pred_id int references analytika.holic(id),                   -- null = bylo volno
  holic_po_id int references analytika.holic(id),                     -- null = uvolněno
  byl_pevny_blok boolean not null default false,
  potvrzeno boolean not null default false,
  poznamka text check (length(poznamka) <= 300),
  kdo text not null default lower(coalesce(auth.jwt() ->> 'email', 'administrace')),
  kdy timestamptz not null default now(),
  check (not byl_pevny_blok or potvrzeno),                            -- pevný blok jen vědomě
  check (date_trunc('month', den)::date = mesic)
);
create index on rozpis.uprava (mesic, provozovna_id);

-- ===== zabezpečení: tabulky jen pro service_role, ven jen přes funkce s kontrolou role =====
alter table rozpis.prednost enable row level security;
alter table rozpis.prednost_zmena enable row level security;
alter table rozpis.uprava enable row level security;
revoke all on all tables in schema rozpis from public, anon, authenticated;
revoke all on all functions in schema rozpis from public, anon, authenticated;
grant usage on schema rozpis to service_role;
grant all on all tables in schema rozpis to service_role;

-- seznam přednosti (admin, majitel)
create function public.prednost_seznam(p_den date default current_date)
returns table (id bigint, holic text, typ text, uroven smallint, provozovna text, den_v_tydnu smallint,
               cas_od time, cas_do time, plati_od date, plati_do date, poznamka text, autor text, plati_ted boolean)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup(array['admin', 'majitel']);
  return query
  select p.id, h.jmeno, p.typ, p.uroven, pv.nazev, p.den_v_tydnu, p.cas_od, p.cas_do, p.plati_od, p.plati_do,
         p.poznamka, p.autor, p_den between p.plati_od and p.plati_do
  from rozpis.prednost p join analytika.holic h on h.id = p.holic_id
  left join analytika.provozovna pv on pv.id = p.provozovna_id
  order by h.jmeno, p.plati_od;
end $$;

-- přidat nebo změnit přednost (p_id null = nová)
create function public.prednost_ulozit(p_id bigint, p_holic text, p_typ text, p_uroven smallint,
                                       p_provozovna text, p_den_v_tydnu smallint, p_cas_od time, p_cas_do time,
                                       p_plati_od date, p_plati_do date, p_poznamka text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_holic int; v_prov int; v_id bigint;
begin
  perform analytika.over_pristup(array['admin', 'majitel']);
  select h.id into v_holic from analytika.holic h where h.jmeno = p_holic;
  if v_holic is null then raise exception 'Holič neexistuje.'; end if;
  if p_provozovna is not null then
    select pv.id into v_prov from analytika.provozovna pv where pv.nazev = p_provozovna;
    if v_prov is null then raise exception 'Provozovna neexistuje.'; end if;
  end if;
  if p_id is null then
    insert into rozpis.prednost (holic_id, typ, uroven, provozovna_id, den_v_tydnu, cas_od, cas_do, plati_od, plati_do, poznamka)
    values (v_holic, p_typ, p_uroven, v_prov, p_den_v_tydnu, p_cas_od, p_cas_do, p_plati_od, p_plati_do, trim(p_poznamka))
    returning id into v_id;
  else
    update rozpis.prednost set holic_id = v_holic, typ = p_typ, uroven = p_uroven, provozovna_id = v_prov,
      den_v_tydnu = p_den_v_tydnu, cas_od = p_cas_od, cas_do = p_cas_do, plati_od = p_plati_od, plati_do = p_plati_do,
      poznamka = trim(p_poznamka)
    where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Přednost neexistuje.'; end if;
  end if;
  return v_id;
end $$;

create function public.prednost_smazat(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform analytika.over_pristup(array['admin', 'majitel']);
  delete from rozpis.prednost where id = p_id;
end $$;

-- záznam změn (admin, majitel)
create function public.prednost_zaznam(p_od date default current_date - 90)
returns table (kdy timestamptz, kdo text, akce text, prednost_id bigint, pred jsonb, po jsonb)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform analytika.over_pristup(array['admin', 'majitel']);
  return query select z.kdy, z.kdo, z.akce, z.prednost_id, z.pred, z.po
  from rozpis.prednost_zmena z where z.kdy >= p_od order by z.kdy desc;
end $$;

revoke all on function public.prednost_seznam(date), public.prednost_ulozit(bigint, text, text, smallint, text, smallint, time, time, date, date, text),
  public.prednost_smazat(bigint), public.prednost_zaznam(date) from public, anon;
grant execute on function public.prednost_seznam(date), public.prednost_ulozit(bigint, text, text, smallint, text, smallint, time, time, date, date, text),
  public.prednost_smazat(bigint), public.prednost_zaznam(date) to authenticated;
