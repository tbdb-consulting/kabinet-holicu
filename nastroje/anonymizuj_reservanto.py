"""Anonymizace exportu událostí z Reservanta (Kabinet holičů, T26-09).

Použití (na počítači, kde leží surový export; surový soubor nikdo jiný neotvírá):
    py anonymizuj_reservanto.py <surovy_export.csv> <vystup.csv> <soubor_se_soli.txt>

Co dělá:
- odstraní sloupce s osobními údaji (jméno, příjmení, e-mail, telefon, poznámky, číslo voucheru, štítky,
  vlastní údaje),
- místo zákazníka doplní pseudonym „Z-xxxxxxxx“ (HMAC-SHA256 z e-mailu, jinak telefonu, jinak jména,
  s tajnou solí) – stejný zákazník = stejný pseudonym, zpátky na kontakt to převést nejde,
- ve zbylých textových sloupcích smaže cokoli, co vypadá jako e-mail nebo telefon,
- na výstup vypíše jen počty a názvy sloupců, nikdy obsah.
Sůl se při prvním spuštění vygeneruje do <soubor_se_soli.txt>; nechte ji u Toma (nebo ve složce klienta),
do repozitáře nikdy. Se stejnou solí jdou pozdější exporty spojit se staršími.
"""
import csv, hashlib, hmac, io, os, re, secrets, sys, unicodedata

OSOBNI = ['křestní jméno', 'příjmení', 'e-mail', 'email', 'telefon', 'poznámka', 'poznámka k platbě',
          'číslo voucheru', 'štítky', 'jméno', 'zákazník', 'adresa', 'vlastní']
RE_MAIL = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')
RE_TEL = re.compile(r'(\+?\d[\d \-]{7,}\d)')


def norm(t):
    return unicodedata.normalize('NFKC', (t or '')).strip().lower()


def nacti(cesta):
    raw = open(cesta, 'rb').read()
    for kod in ('utf-8-sig', 'cp1250'):
        try:
            text = raw.decode(kod)
            break
        except UnicodeDecodeError:
            continue
    dialekt = csv.Sniffer().sniff(text[:5000], delimiters=';,\t')
    return list(csv.reader(io.StringIO(text), dialekt)), dialekt.delimiter


def main(vstup, vystup, sul_soubor):
    if not os.path.exists(sul_soubor):
        open(sul_soubor, 'w', encoding='utf-8').write(secrets.token_hex(32))
    sul = open(sul_soubor, encoding='utf-8').read().strip().encode()
    radky, odd = nacti(vstup)
    hlava, data = radky[0], radky[1:]
    h = [norm(x) for x in hlava]
    idx = lambda *jmena: next((i for i, x in enumerate(h) if x in jmena), None)
    i_mail, i_tel = idx('e-mail', 'email'), idx('telefon')
    i_jm, i_pr = idx('křestní jméno', 'jméno'), idx('příjmení')
    smazat = {i for i, x in enumerate(h) if any(x == o or x.startswith(o) for o in OSOBNI)}
    nechat = [i for i in range(len(hlava)) if i not in smazat]

    def pseudonym(r):
        g = lambda i: norm(r[i]) if i is not None and i < len(r) else ''
        klic = g(i_mail) or re.sub(r'\D', '', g(i_tel))[-9:] or (g(i_jm) + ' ' + g(i_pr)).strip()
        if not klic:
            return ''
        return 'Z-' + hmac.new(sul, klic.encode(), hashlib.sha256).hexdigest()[:10]

    with open(vystup, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f, delimiter=';')
        w.writerow(['zakaznik'] + [hlava[i] for i in nechat])
        zak = set()
        for r in data:
            if not any(c.strip() for c in r):
                continue
            p = pseudonym(r)
            zak.add(p)
            hodnoty = []
            for i in nechat:
                v = r[i] if i < len(r) else ''
                if any(x in h[i] for x in ('začátek', 'konec', 'datum', 'čas', 'vytvoř')):
                    hodnoty.append(v)  # datum a čas nečistit, telefonní vzor by je smazal
                    continue
                v = RE_MAIL.sub('', v)
                v = RE_TEL.sub(lambda m: m.group(0) if len(re.sub(r'\D', '', m.group(0))) < 9 else '', v)
                hodnoty.append(v)
            w.writerow([p] + hodnoty)
    print('řádků:', len(data), '| zákazníků (pseudonymů):', len(zak - {''}))
    print('odstraněné sloupce:', ', '.join(hlava[i] for i in sorted(smazat)))
    print('ponechané sloupce:', ', '.join(hlava[i] for i in nechat))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
