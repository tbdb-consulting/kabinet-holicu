# Sestaví web/leden-2027.html z ukázky v datové složce (Claude outputs261123_KABINET_ukazka_rezervace.html)
# a ze zkušebních odpovědí testdata/zkusebni_odpovedi.json; varianty 4h a 3h bloků. Spuštění: py -I sestav_leden.py
import json, sys
src = r"C:\Users\Dell\Můj disk\Claude AI\T26-09 Kabinet holičů\Claude outputs\261123_KABINET_ukazka_rezervace.html"
data = json.load(open(r"C:\Projekty TBDB\kabinet-holicu\testdata\zkusebni_odpovedi.json", encoding="utf-8"))
out = r"C:\Projekty TBDB\kabinet-holicu\web\leden-2027.html"
t = open(src, encoding="utf-8").read()
def rep(a, b, n=1):
    global t
    assert t.count(a) == n, (a[:60], t.count(a))
    t = t.replace(a, b)
H = [{"j": o["jmeno"], "p": o["provozovna"], "h": o["hodin"],
      "x": [[o["prani"][d][b] for b in "RSO"] for d in ["Po","Ut","St","Ct","Pa"]],
      "y": [[o["prani3"][d][b] for b in "ABCD"] for d in ["Po","Ut","St","Ct","Pa"]]} for o in data]
rep('<meta charset="utf-8">', '<meta charset="utf-8">\n<meta name="robots" content="noindex,nofollow">')
rep('<title>Kabinet holičů – ukázka rezervace křesel</title>', '<title>Kabinet holičů – leden 2027 (zkušební data)</title>')
rep('<h1>Kabinet holičů – rezervace křesel <span class="vym">UKÁZKA · VYMYŠLENÁ DATA</span></h1>',
    '<h1>Kabinet holičů – rozdělení křesel a dražba <span class="vym">ZKUŠEBNÍ DATA</span></h1>')
rep('· holiči, přání a ceny jsou vymyšlené · TBDB Consulting',
    '· holiči z webu, jejich přání a ochota platit jsou <b>vymyšlené</b>, dotazník zatím nikdo nevyplnil · TBDB Consulting')
rep('<p>Ukázka přehraje jeden měsíc rezervace křesel od začátku do konce. Všechno počítá prohlížeč, nic se nikam neukládá ani neodesílá.</p>',
    '<p><b>Zkušební data:</b> jako by dotazník vyplnilo všech 21 holičů z Old Place a Zverimexu. Dohromady chtějí 80 % kapacity křesel (Old Place 1 152 z 1 440 h, Zverimex 768 z 960 h), nejvíc 25 h týdně, nejméně 6 h týdně. Přání jsou vymyšlená, <b>nejde o skutečné odpovědi holičů</b>.</p>\n<p>Stránka přehraje rozdělení ledna 2027 od začátku do konce. Všechno počítá prohlížeč, nic se nikam neukládá ani neodesílá.</p>')
rep('<p class="mala">Pro jednoduchost ukázka počítá jen se 4h bloky',
    '<p class="mala">Rozdělení počítá se 4h bloky (8–12, 12–16, 16–20), přání ve 3h blocích a nejkratší/nejdelší rezervaci ze zkušebních odpovědí zatím nepoužívá. Pro jednoduchost jen pracovní dny')
rep('(8–12, 12–16, 16–20) v pracovní dny. Šestihodinové', '. Šestihodinové')
rep('<button class="btn sv" onclick="novaData()">Vymyslet jiné holiče a přání</button>',
    '<button class="btn sv" onclick="novaData()">Jiná simulace dražby</button>')
rep('<label>Zaplněnost: kolik hodin chtějí holiči dohromady, v % kapacity<input id="pZaplneni" type="number" value="90" min="30" max="130"></label>\n', '')
rep('„Kolik by dal“ je vymyšlené a jen simuluje, kdy holič v dražbě klikne. Ve skutečnosti ho nikdo nezadává.',
    '„Kolik by dal“ je vymyšlené a jen simuluje, kdy holič v dražbě klikne. Ve skutečnosti ho nikdo nezadává. „Jiná simulace dražby“ ho vylosuje znovu, přání holičů zůstávají.')
# data místo vymýšlení
a = t.index("// ---------- vymyšlení holičů ----------")
b = t.index("// ---------- výpočet měsíce ----------")
t = t[:a] + """// ---------- zkušební odpovědi (testdata/generuj_zkusebni.py, seed 2027) ----------
const ODPOVEDI=""" + json.dumps(H, ensure_ascii=False, separators=(",", ":")) + """;
function vymysli(){
 const r=rng(seed);
 return ODPOVEDI.map((o,i)=>({jmeno:o.j,prov:o.p,pref:VAR===3?o.y:o.x,cil:o.h,id:i,barva:BARVY[i%BARVY.length],wtp:Math.round((50+r()*45)/5)*5}));
}

""" + t[b:]
rep("Měsíc <span id=\"mesicNazev\"></span>", "Měsíc <span id=\"mesicNazev\"></span>")
# --- varianta 3h bloků (vloženo do leden.py) ---
rep("const BLOKY=[{k:'R',t:'8–12',pred:4,po:0},{k:'S',t:'12–16',pred:2,po:2},{k:'O',t:'16–20',pred:0,po:4}];",
    "const BLOKY4=[{k:'R',t:'8–12',pred:4,po:0},{k:'S',t:'12–16',pred:2,po:2},{k:'O',t:'16–20',pred:0,po:4}];\n"
    "const BLOKY3=[{k:'A',t:'8–11',pred:3,po:0},{k:'B',t:'11–14',pred:3,po:0},{k:'C',t:'14–17',pred:0,po:3},{k:'D',t:'17–20',pred:0,po:3}];\n"
    "let VAR=4, BLOKY=BLOKY4, L=4;\n"
    "function nastavVar(v){VAR=v;BLOKY=v===3?BLOKY3:BLOKY4;L=v}")
rep("h.busy=DATA_DNY.map(()=>[false,false,false])", "h.busy=DATA_DNY.map(()=>BLOKY.map(()=>false))")
rep("h.busy[di][b]=true;h.hod+=4;h.pred+=BLOKY[b].pred;h.po+=BLOKY[b].po;if(h.pref[DATA_DNY[di].wd][b]===2)h.chtene+=4;h.najem+=4*cena;if(draz){h.drazHod+=4;h.drazNavic+=4*(cena-P.sazba)}",
    "h.busy[di][b]=true;h.hod+=L;h.pred+=BLOKY[b].pred;h.po+=BLOKY[b].po;if(h.pref[DATA_DNY[di].wd][b]===2)h.chtene+=L;h.najem+=L*cena;if(draz){h.drazHod+=L;h.drazNavic+=L*(cena-P.sazba)}")
rep("[0,1,2,3,4].map(wd=>[0,1,2].map(b=>", "[0,1,2,3,4].map(wd=>BLOKY.map((_,b)=>")
rep("for(let wd=0;wd<5;wd++)for(let b=0;b<3;b++){const n=popt", "for(let wd=0;wd<5;wd++)for(let b=0;b<BLOKY.length;b++){const n=popt")
rep("hod=di.length*4;", "hod=di.length*L;")
rep("h.hod<h.cil);", "h.cil-h.hod>L/2);")
rep("for(let di=0;di<DATA_DNY.length;di++)for(let b=0;b<3;b++){", "for(let di=0;di<DATA_DNY.length;di++)for(let b=0;b<BLOKY.length;b++){")
rep("if(b===0&&predPct<P.rano+5)s+=150; if(b===2&&poPct<P.odpo+5)s+=150;",
    "if(BLOKY[b].po===0&&predPct<P.rano+5)s+=150; if(BLOKY[b].pred===0&&poPct<P.odpo+5)s+=150;")
rep("for(let b=0;b<3;b++)for(let wd=0;wd<5;wd++)s+='<span class=\"p'", "for(let b=0;b<BLOKY.length;b++)for(let wd=0;wd<5;wd++)s+='<span class=\"p'")
rep("kap+=DATA_DNY.length*3*p.kresla*4", "kap+=DATA_DNY.length*12*p.kresla")
rep("const k=DATA_DNY.length*3*p.kresla*4;", "const k=DATA_DNY.length*12*p.kresla;")
# přepínač a srovnání
rep('<h3>Nájem a rozvrh</h3>\n<div class="parametry">',
    '<h3>Nájem a rozvrh</h3>\n<div class="parametry">\n<label>Délka bloků<select id="pVar" onchange="nastavVar(+this.value);prepocitat()"><option value="4">4 hodiny (8–12, 12–16, 16–20)</option><option value="3">3 hodiny (8–11, 11–14, 14–17, 17–20)</option></select></label>')
rep('<nav id="nav">', '<div id="varLista" style="background:#eaf1f7;border-bottom:1px solid var(--li,#d5dfe8);padding:8px 16px;font-size:13px;text-align:center">Varianta: <b id="varNazev"></b> · <a href="#" onclick="prepniVar();return false">přepnout na <span id="varJina"></span></a></div>\n<nav id="nav">')
rep('<div class="souhrn" id="souhrn"></div>', '<h3 style="margin-top:0">Srovnání variant 4h a 3h bloků</h3>\n<div id="srovnani" class="posuv"></div>\n<h3>Vybraná varianta</h3>\n<div class="souhrn" id="souhrn"></div>')
rep("Mřížka holiče: sloupce Po–Pá, řádky 8–12 / 12–16 / 16–20.", "Mřížka holiče: sloupce Po–Pá, řádky = bloky zvolené varianty.")
rep("Rozdělení počítá se 4h bloky (8–12, 12–16, 16–20), přání ve 3h blocích a nejkratší/nejdelší rezervaci ze zkušebních odpovědí zatím nepoužívá.",
    "Rozdělení jde přepnout mezi 4h bloky (8–12, 12–16, 16–20) a 3h bloky (8–11, 11–14, 14–17, 17–20), každá varianta bere přání holičů ze své mřížky v dotazníku (3a, nebo 3b). Srovnání obou je v části Férovost a nájem. Nejkratší a nejdelší rezervaci zatím nepoužívá. U 3h bloků se chtěné hodiny dorovnají na nejbližší násobek 3.")
rep("function prepocitat(){\n zastavDrazbu(false);D=spocitej();",
    """function souhrnVar(v){const puv=VAR;nastavVar(v);const d=spocitej();nastavVar(puv);
 const kap=DATA_DNY.length*12*PROV.reduce((a,p)=>a+p.kresla,0),obs=d.H.reduce((a,h)=>a+h.hod,0);
 const prod=d.loty.filter(l=>l.vitez!==null);const sp=d.H.map(h=>h.hod/h.cil*100);
 return {kap,obs,loty:d.loty.length,prod:prod.length,navic:d.H.reduce((a,h)=>a+h.drazNavic,0),najem:d.H.reduce((a,h)=>a+h.najem,0),
  sp:Math.round(Math.min(...sp))+'–'+Math.round(Math.max(...sp))+' %',chtene:Math.round(d.H.reduce((a,h)=>a+h.chtene,0)/obs*100),
  porus:d.H.filter(h=>h.hod&&(h.pred/h.hod*100<d.P.rano||h.po/h.hod*100<d.P.odpo)).length,
  zadane:PROV.reduce((a,p)=>a+d.popt[p.id].flat().filter(n=>n>p.kresla*d.P.prah).length,0)}}
function kresliSrovnani(){const a=souhrnVar(4),b=souhrnVar(3);
 const r=(t,x,y)=>'<tr><td>'+t+'</td><td'+(VAR===4?' style="font-weight:bold"':'')+'>'+x+'</td><td'+(VAR===3?' style="font-weight:bold"':'')+'>'+y+'</td></tr>';
 $('srovnani').innerHTML='<table class="siroka"><tr><th></th><th>4h bloky</th><th>3h bloky</th></tr>'+
 r('Obsazenost křesel',Math.round(a.obs/a.kap*100)+' % ('+a.obs+' h)',Math.round(b.obs/b.kap*100)+' % ('+b.obs+' h)')+
 r('Splnění chtěných hodin (nejhorší–nejlepší)',a.sp,b.sp)+
 r('Přidělené hodiny v blocích „chci“',a.chtene+' %',b.chtene+' %')+
 r('Žádaných bloků v týdnu (převis zájmu)',a.zadane,b.zadane)+
 r('Dražba: prodáno / balíčků',a.prod+' / '+a.loty,b.prod+' / '+b.loty)+
 r('Příplatek z dražby',kc(a.navic),kc(b.navic))+
 r('Nájem celkem',kc(a.najem),kc(b.najem))+
 r('Holičů mimo pravidlo ráno/odpoledne',a.porus,b.porus)+'</table>'}
function prepniVar(){nastavVar(VAR===4?3:4);$('pVar').value=VAR;prepocitat()}
function prepocitat(){
 zastavDrazbu(false);D=spocitej();
 $('varNazev').textContent=VAR+'hodinové bloky';$('varJina').textContent=(VAR===4?3:4)+'hodinové';""")
rep("kresliPrani();kresliRozvrh();kresliFerovost();kresliLog(0);", "kresliPrani();kresliRozvrh();kresliFerovost();kresliSrovnani();kresliLog(0);")
rep("'každý čtvrtek','každý pátek'][l.wd]+' '+BLOKY[l.b].t", "'každý čtvrtek','každý pátek'][l.wd]+' '+BLOKY[l.b].t")

open(out, "w", encoding="utf-8").write(t)
print("ok", len(t), sum(h["h"] for h in H))
