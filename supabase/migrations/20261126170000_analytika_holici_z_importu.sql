-- Po nahrání historie (import CSV v administraci Supabase, 26. 11. 2026): holiči a aliasy ze jmen zdrojů v Reservantu.
-- Ověřeno: 81 931 rezervací 2. 1. 2024 – 26. 11. 2026, 45 holičů, žádná rezervace bez holiče;
-- 12 měsíců: 30 862 h, 10 351 zákazníků (sedí s rozborem v Claude outputs\261126_KABINET_vytizenost_reservanto.html).
insert into analytika.holic (firma_id, jmeno)
select distinct 1, holic_zdroj from analytika.rezervace_hist;
insert into analytika.holic_alias (alias, holic_id) select jmeno, id from analytika.holic;
update analytika.import_davka set radku = (select count(*) from analytika.rezervace_hist where davka_id = 1) where id = 1;
