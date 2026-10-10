# Katalog grafiki: Piętro I — skrzydło azjatyckie (Chiny, Korea, Japonia)

> Gałąź `art-asia`. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§5.5, §7.3, §7.4, §10). Plan: `docs/superpowers/plans/2026-10-03-art-azja.md`. Greybox: `src/level/floor1/zones/asia.gd` (gałąź `p1-w5-east`).
> Wszystko powstaje skryptami Blendera w tle: `tools/art/models/kit_asia_*.py`, `buddha.py`, `exhibits_asia.py`, `hwacha_display.py`, `samurai_*.py`, `fu_dog.py`, `garden_kit.py`, `cherry_tree.py`, `teahouse.py`; wspólne biblioteki `artlib/asia.py` (materiały, pola), `artlib/asia_paint.py` (malarz pikseli: chmurki ruyi, lotosy, smok, żurawie, taotie, **pędzel kaligrafii z prawdziwymi znakami 山 水 月 i ensō**, pieczęcie), `artlib/asia_geo.py` (wsporniki, bloki dou), `artlib/samurai.py` (części zbroi japońskiej).
> **Osie:** liczby w osiach **Godota** (x w prawo, y w górę, −z = przód modelu). Blender (x, y, z) → Godot (x, z, −y). Każdy model patrzy na **−Z**; lewa strona postaci = **−X**.
> Budowa: `"D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup --python tools/art/build_models.py -- <moduły>` (szybko: `--fast`), tekstury pól: `python tools/art/build_textures.py <nazwy>`. Podglądy: `tests/_out/art/<id>.png` (+ `_closeup`, ujęcia dodatkowe).

## 1. Paleta i gęstości

| Klasa | px/m | Modele |
|---|---|---|
| pola kafelkowe, architektura | 64 | 15 pól `asia_*`, `gravel_*`, `garden_wall`, `tatami`, `cherry_blossom`, `thatch`; pasy, belki, brama księżycowa, kapinos muru, herbaciarnia |
| wsporniki, obramienie drzwi, baza słupa | 96 | `asia_eaves_*`, `asia_doorframe_2x2_6`, `asia_post_base`, kamienie i most ogrodu, dzwonnica |
| meble, gabloty, lampiony, latarnie | 128–192 | `asia_case_*`, `asia_plinth`, `asia_lantern_*`, `toro_*`, `hwacha_display`, wnętrze herbaciarni 96 |
| Budda (≈ 5,5 m) | 112 | `buddha_seated` |
| drobne eksponaty | 256–320 | brązy, porcelana, zwój |
| wrogowie | 192–256 | `fu_dog` 192, `samurai_ashigaru` 256 |
| strażnik | 224 | `samurai_general` (zbroje na stojakach 192) |
| wiśnia | 80 (+ pole kwiatów 64) | `cherry_tree` |

Rampy (słownik `P` w `artlib/asia.py`): lak cynobrowy i czarny, patyna (malachit), azuryt, kupryt, ciemny i wytarty brąz, biel porcelany, kobalt, seledyn, biel księżycowego dzbana, tynk kości, pigmenty malatury (cynober, malachit, azuryt, ochra, biel, róż, oranż), sumi i czerwień pieczęci, washi, jedwab, brokat, plecionka sznurowania (czerwona, granatowa, biała, zielona), hinoki, cedr, tatami, strzecha, kamień ogrodowy, mech, porost, żwir, kora i kwiat wiśni, woda, koi, dachówka, glina muru, szare drewno.

**Materiały (najważniejsze):** lak z siateczką spękań i przetarciem do podkładu na krawędziach (negoro), złocenie na laku (miękkie stare złoto, brud w zagłębieniach, przetarcia do czerwieni), archaiczny brąz (ciągła szarozielona patyna, jasna skorupa w zagłębieniach, wyspy ciemnego metalu, wytarte do ciepłego brązu miejsca dotykane rękami), szkliwo porcelany z kobaltem podszkliwnym („heaped and piled”), seledyn z krakelurą i inkrustacją sanggam, malowane belki (pigment + czarna linia i biała kreska na każdej krawędzi: czytelne z daleka), sznurowanie kebiki odoshi (gęste jedwabne sznurki na czarnych lamelkach — piksel po pikselu).

## 2. Pola kafelkowe (64 px/m, `ArtLibrary.arch_tile`)

| Tekstura | Kafel | Co to jest | Gdzie |
|---|---|---|---|
| `asia_plaster` | 2 × 2 | tynk wapienny w kolorze kości | ściany sal (z `wall_tint` w porcelanie) |
| `asia_plaster_dark` | 2 × 2 | grafitowy tynk | Sala Zbroi |
| `asia_band` | 4 × 1 | malowany fryz: złote i barwne linie, rozety lotosu na malachicie, pary chmurek ruyi | lico `asia_frieze_*` (pas 1 m na pełnym metrze) |
| `tiles_golden` | 4 × 4 | szare „złote cegły” 0,5 m w wiązaniu, polerowane | posadzka Sali Chin |
| `stone_slate` | 4 × 4 | polerowany zielonoszary łupek 1 × 0,5 m | galeria porcelany, progi |
| `asia_coffers` | 4 × 4 | malowany strop kasetonowy 1 m (zielone żebra, złote gwoździe, chmurki, lotos na błękicie) | strop Sali Chin |
| `asia_lacquer` / `asia_lacquer_black` | 2 × 2 | lak cynobrowy / czarny | pnie słupów, ościeża, strop zbrojowni |
| `boards_dark` | 2 × 2 | ciemna podłoga z desek 0,2 m | Korea, Sala Zbroi, sufit herbaciarni |
| `gravel_raked` / `gravel_plain` | 4 × 4 / 2 × 2 | żwir grabiony w proste bruzdy co 12,5 cm (wzdłuż x) / gładki | ogród |
| `garden_wall` | 4 × 3 | glina muru tsuiji, słoma, zacieki | dół ścian ogrodu (do 3 m), ściany herbaciarni |
| `tatami` | 4 × 2 | maty 2 × 1 m w wiązaniu koszykowym z czarnymi lamówkami | podłoga herbaciarni |
| `cherry_blossom` | 2 × 2 | kwiaty somei-yoshino | chmury kwiatów wiśni (`tile:` w modelu) |
| `thatch` | 4 × 4 | strzecha z kępami mchu | dach herbaciarni (`tile:` w modelu) |

**Style pomieszczeń** (`ArtKit.ROOMS`): `asia_china` (tynk, cokół, fryz na 5 m, gzyms wspornikowy, „złote cegły”, strop kasetonowy; `frame_4` brama księżycowa, `frame_2_6` obramienie), `asia_porcelain` (tynk przyciemniony na błękitno, łupek, czarny strop), `asia_korea` (deski, fryz na 4 m, belki co 4 m z wspornikami `asia_corbel`), `asia_armor` (grafitowy tynk, deski, czarny strop), `asia_garden` (glina do 3 m, nad nią kamień portlandzki, kapinos `asia_wallcap_*` na 3 m, żwir), `asia_teahouse` (glina, tatami, sufit z desek). `RUN_SIZES`/`BAND_SPAN` dopisane dla `asia_dado_`, `asia_frieze_`, `asia_eaves_`, `asia_wallcap_`.

## 3. Zestaw architektury (`ArtLibrary.KIT`; początek w środku podstawy, front −Z)

| Id | Rozmiar (x × y × z) | Trójkąty | Opis, oś, datum |
|---|---|---|---|
| `asia_dado_4m/2m/1m/05m` | L × 1,1 × 0,1 | 2034 / 1122 / 666 / 438 | lakierowana boazeria: czarny cokół, cynobrowa rama ze słupkami co 0,5 m, czarne płyciny ze złotą chmurką, złocone okucia narożne; datum = podłoga, płaszczyzna ściany z = 0 |
| `asia_frieze_*` | L × 1,14 × 0,07 | 26 | lico 1 m z polem `tile:asia_band` między lakowymi wałkami; **datum = dolna krawędź lica na pełnym metrze** |
| `asia_eaves_4m/2m/1m` | L × 1,05 × 0,72 | 2796 / 1444 / 768 | gzyms wspornikowy dougong: malowany architraw, **zestaw wsporników co 1 m** (blok lu dou, ramiona gong w dwóch kondygnacjach, małe bloki, ukośna dźwignia ang z dziobem, głowica belki), czerwone płyciny między zestawami, malowana płatew pod stropem; malatura w raporcie 1 m (moduły łączą się bez szwu); datum = strop (wisi 1,05 m) |
| `asia_beam_4m` | 4 × 0,42 × 0,32 | 42 | malowana belka stropowa (obręcze, rozety xuanzi co 1 m); początek = środek górnej krawędzi na płaszczyźnie stropu; `ArtKit.dress_ceiling` kładzie je co 4 m (`beams`) |
| `asia_corbel` | 0,16 × 0,5 × 0,92 | 138 | rzeźbiony wspornik chmurkowy queti pod końcem belki; początek na ścianie u **góry** wspornika (= spód belki, strop − 0,42) |
| `asia_post_base` | 0,9 × 0,4 × 0,9 | 474 | granitowa baza z bębnem lotosu; słup stoi na y = 0,4 |
| `asia_post_shaft` | Ø 0,5 × 1 | 40 | pień z pola `tile:asia_lacquer`: skalować Y do wysokości (strop − 1,2 − 0,4) |
| `asia_post_capital` | 1,3 × 1,2 × 1,3 | 872 | głowica: malowana opaska pnia, belki wiązań w obie strony, blok i krzyżowe wsporniki w dwóch kondygnacjach; początek = strop, wisi 1,2 m |
| `asia_moon_gate_4m` | 4,76 × 4,45 × 0,3 | 744 | brama księżycowa: otwór okrągły Ø 4 m ścięty 0,35 m nad podłogą (2,26 m przejścia przy podłodze), pierścień szarej cegły na białym panelu 4,6 × 4,35, kamienny wałek, kamienna okładzina, **tablica z rytym 山水** („góry i wody”, czytane od prawej). Jedno lico (ArtKit.passage: `frame_4`, otwory 4 × 4,5; przejście Korea → Zbroje 4 × 4 — ręcznie), okładzina 0,25 m w głąb muru; narożniki prostokąta zasłania panel (dać im kolizję) |
| `asia_doorframe_2x2_6` | 2,54 × 2,88 × 0,35 | 1028 | chińska oprawa drzwi 2 × 2,6: cynobrowe słupki i nadproże, ażurowa krata gualuo i wsporniki narożne pod nadprożem (2,32 m w świetle), lakowa okładzina 0,25 m, kamienny próg (`frame_2_6`) |
| `asia_lattice_window` | 1,72 × 1,83 × 0,2 | 1108 | fałszywe okno: kratka „spękanego lodu” w cynobrowej ramie na papierze; zestaw **`asia_lattice_window_lit`** (papier świeci, emisja 1,6) |
| `asia_shoji_2m` | 2,06 × 2,12 × 0,12 | 756 | para shoji (hinoki, kumiko, washi, deska) z prowadnicami; zestaw **`asia_shoji_2m_lit`** |
| `asia_wallcap_4m/2m/1m` | L × 0,55 × 0,62 | 902 / 486 / 278 | kapinos glinianego muru: daszek z rolowanych dachówek, krążki okapowe, płatew; datum = szczyt muru (3,0 m w stylu ogrodu) |
| `asia_lantern_red` | Ø 0,6 × 1,7 | 970 | chiński lampion pałacowy (świecący czerwony jedwab, czarne wieczka, złote pasy, chwost, sznur do haka 1 m nad); **początek = światło**, znacznik `Light` |
| `asia_lantern_floor` | 0,38 × 0,96 × 0,38 | 1014 | andon: ciemna rama, papier świeci; znacznik `Light` (0; 0,42; 0) |
| `asia_case_tall` | 0,94 × 1,9 × 0,74 | 1298 | gablota: czarny lak, złocone okucia, brokat, szkło `asia_case_tall_glass`, brązowa rama; `ItemSpot` (0; 0,89; 0) |
| `asia_case_low` | 1,62 × 0,99 × 0,82 | 1034 | gablota stołowa, szkło osobno; `ItemSpot_1..3` (±0,5 / 0; 0,59; 0) |
| `asia_plinth` | 0,7 × 0,9 × 0,7 | 952 | podstawa z palisandru (fartuch, nogi na chmurkach); `ItemSpot` (0; 0,9; 0) |
| `teahouse` / `cherry_tree` | patrz §6 | | (w KIT, bo mają pola `tile:`) |

Budżety prefiksów dopisane w `test_art_kit.gd` (`asia_eaves` 3500, `asia_dado` 2200, `asia_doorframe` 2400, `asia_moon_gate` 1600, `asia_case` 1600, `asia_lattice` 1400, `teahouse` 4000, `cherry_tree` 7000) i przebiegi w `RUNS`.

## 4. Eksponaty (`ArtLibrary.REGISTRY`, front −Z)

| Id | Rozmiar | Trójkąty / atlas | Części / znaczniki | Rozmieszczenie, uwagi |
|---|---|---|---|---|
| `buddha_seated` | 3,7 × 7,5 × 3,9 | 16 440 / 2080 × 1152 @112 | `buddha_seated` (cokół sumeru + tron lotosu), `buddha_mandorla`, `buddha_figure` (oś (0; 1,4; 0)), `buddha_head` (szyja (0; 4,05; −0,05), dziecko figury); `Halo` (środek aureoli głowy, miękkie światło), `Offering` (0; 0,4; −1,95) = stopień ofiarny | Szakjamuni w geście dotknięcia ziemi; złocony lak, niebieskie loki (azuryt), czerwony klejnot, urna, malowane oczy i brwi, złota szata z czerwono-zieloną bordiurą, płomienna mandorla. Przy północnej ścianie Sali Chin, twarzą na południe; na `Offering` postawić `bronze_ding` |
| `bronze_ding` | 0,67 × 0,88 × 0,67 | 1560 | — | trójnóg Shang z uchwytami, pas masek taotie w reliefie (wytarty), patyna; też kadzielnica przed Buddą |
| `bronze_gu` | 0,17 × 0,32 × 0,17 | 1190 | — | pucharek gu z kołnierzami i taotie |
| `vase_blue_white` | 0,26 × 0,43 × 0,26 | 866 | — | meiping Ming: kołnierz ruyi, **smok goniący perłę wśród chmur** (kobalt), panele lotosu |
| `vase_celadon` | 0,26 × 0,41 × 0,26 | 810 | — | maebyeong Goryeo: seledyn z krakelurą, **żurawie w podwójnych medalionach i w locie, chmurki** (inkrustacja sanggam), pas chryzantem |
| `moon_jar` | 0,46 × 0,45 × 0,46 | 922 | — | dalhangari Joseon: lekko krzywy, pas łączenia połówek, plamy |
| `scroll_hanging` | 0,75 × 2,03 × 0,04 | 216 | — | zwój wiszący; **początek = hak na ścianie**, wisi 2,05 m w dół. Zestawy (`ArtLibrary.ASIA_SETS`): `scroll_hanging` (山), `_water` (水), `_moon` (月), `_enso` (ensō, do tokonomy) — prawdziwe znaki rysowane pędzlem, dwie pieczęcie |
| `temple_bell` | 4,7 × 5,1 × 4,9 | 4702 / 1664 × 896 @96 | `temple_bell` (dzwonnica), **`bell`** (oś na sworzniu (0; 3,0; 0): kołysanie wokół X), **`striker`** (belka na linach, oś (0; 3,05; −1,2): odciągnąć wokół X i puścić) | koreański dzwon beomjong 1,8 m: smoczy uchwyt i rura dźwiękowa, 4 × 9 brodawek, niebiańskie postacie i lotosowe tarcze w reliefie; pawilon z czterema słupami i dachem z dachówki (dancheong) |
| `hwacha_display` | 1,4 × 1,6 × 3,6 | 4288 | `hwacha_display`, **`weapon_spot`** (0; 0,83; −0,9) | wóz hwacha (koła, rama, skrzynia 10 × 10 otworów z wsuniętymi strzałami singijeon) za lakowym podestem z brokatową poduszką; mosiężna tabliczka „HWACHA / WÓZ OGNISTYCH STRZAŁ / KOREA, XV W.”; nad `weapon_spot` unosi się OGNISTA SKRZYNIA (`WeaponPickup` +0,35 m). Na znaczniku `weapon_hwacha` z asia.gd |
| `samurai_armor_stand` | 1,1 × 2,43 × 0,9 | 9496 | jedna siatka | ō-yoroi na podeście z tabliczką „ZBROJA SAMURAJA / JAPONIA, XVI W.”; zestawy `_blue`, `_white` (czerwone / granatowe / białe sznurowanie) |

## 5. Ogród japoński (`REGISTRY`; `cherry_tree`, `teahouse` w `KIT`)

| Id | Rozmiar | Trójkąty | Części / znaczniki | Uwagi |
|---|---|---|---|---|
| `garden_rock_a..d` | do 2,9 × 1,75 × 2,4 | 356–436 | — | stojący, leżący, omszały głaz, grupa trzech; każdy w **dysku żwiru grabionego w kręgi** (+4 mm nad polem `gravel_raked`) |
| `toro_kasuga` | 1,04 × 2,11 × 1,04 | 1088 | `Light` (0; 1,36; 0) | sześciokątna latarnia; w komorze ognia **wycięte jeleń i księżyc świecą** (emisja 3,5) |
| `toro_yukimi` | 1,24 × 1,16 × 1,24 | 814 | `Light` (0; 0,72; 0) | latarnia „do oglądania śniegu” na trzech nogach |
| `garden_bridge` | 4,8 × 1,9 × 1,8 | 3072 | — | łukowy most (cynober, brązowe giboshi); pokład: łuk y(x) = 0,85·cos(πx/4,4) + 0,1, \|x\| < 2,2 (przęsło wzdłuż X) |
| `garden_pond` | 6,4 × 0,35 × 4,4 | 1470 | `garden_pond`, `garden_pond_water` | ciemna woda +0,03 m z koi pod powierzchnią, kamienie brzegu; wodzie dać kolizję |
| `cherry_tree` | ≈ 8 × 6,3 × 8 | 6602 / 1056 × 1184 @80 | `cherry_tree` (pień, konary), `cherry_blossom` (kiście z 8 małych płatów na opadającej kopule, pole `tile:cherry_blossom`, przy każdym płacie skrzyżowane karty kwiatów z wycięciem alfa); **`Petals_1..10`** (pod chmurami: emitery płatków) | atlas z alfą: `EXTRAS` `alpha_scissor` 0,5 |
| `cherry_petals_ground` | 4 płachty 2 × 2 | 8 | — | opadłe płatki (alfa) wokół drzewa |

## 6. Herbaciarnia (`teahouse` + `teahouse_interior`)

Rama obu modeli: początek = **środek podłogi pokoju `asia_teahouse`** (Godot (7; 0; −82)), bez obrotu; ogród leży na wschód (+X) i na południe (+Z). Drzwi = otwór greyboxu we wschodniej ścianie (Godot z −2…0 względem środka).

- `teahouse` (3196 tr., 1536 × 1024 @64; strzecha `tile:thatch`, podsufitka `tile:boards_dark`): elewacje na licach ogrodowych ścian wschodniej (x = 3,5) i południowej (z = +4,5): cedrowe słupy, glina, shoji (świecą), drzwi z odsuniętymi skrzydłami; weranda engawa 0,42 m (stopień: kolizja), kamienie do drzwi, **kamienna misa tsukubai z bambusową rynną**, dach czterospadowy ze strzechy (okap 3,6 m, kalenica 7,0 m wzdłuż osi północ–południe, skrzyżowane belki kalenicy). Znaczniki: **`roof_perch`** (0,55; 7,2; 0,55) — miejsce Generała na kalenicy (salwy fazy 2), **`roof_perch_eave`** (3,4; 4,45; −1,0) — na zboczu nad drzwiami, `basin_water` (5,7; 0,3; 1,6) — szmer wody.
- `teahouse_interior` (1566 tr.): słupy, listwa nageshi, **tokonoma** (podest, naturalny pień, miejsce na `scroll_hanging_enso`, kamelia w wazonie), **palenisko ro z żelaznym czajnikiem na łańcuchu**, shoji po obu stronach drzwi, papierowa lampa (`Light` (0; 2,8; 0)), niski stolik; **`terminal_spot`** (−2,6; 0; 0) = `haven_spots[&"teahouse"]` z asia.gd (terminal zwrócony na +X).

## 7. Pies Fu z brązu (`fu_dog`, 192 px/m, 13 118 tr., 14 części)

Lew-strażnik (samiec), 1,6 m w kłębie, ≈ 2,3 m do szczytu grzywy; łapa prawa na haftowanej kuli, **luźna kamienna perła w otwartym pysku** (słaby punkt, ma własną emisję do „zapalenia” przed rykiem), wyłupiaste oczy, płaski nos, kły, grzywa z rzędów płaskich loków, płomienne kępy przy łokciach, obroża z dzwonkiem, ogon-pióropusz. Brąz patynowany, wytarty na głowie, łapach i kuli.

| Część | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `body` | (0; 1,10; 0) | — | korzeń: kołysanie, szarża |
| `head` | (0; 1,55; −0,85) | body | rozglądanie, ryk (głowa w górę: rotation.x +15…+25°) |
| `jaw` | (0; 1,62; −1,25) | head | otwarcie pyska: rotation.x −15…−30° |
| `pearl` | (0; 1,58; −1,58) | head | perła (emisja: `set_instance_shader_parameter(&"glow")`) |
| `leg_fl` / `leg_fr` | (∓0,30; 1,05; −0,60) | body | barki |
| `shin_fl` / `shin_fr` | (−0,33; 0,60; −0,66) / (0,34; 0,78; −0,86) | leg_f* | łokcie (prawa łapa w spoczynku uniesiona na kulę) |
| `leg_bl` / `leg_br` | (∓0,30; 1,05; 0,85) | body | biodra |
| `shin_bl` / `shin_br` | (∓0,33; 0,48; 1,08) | leg_b* | stawy skokowe |
| `tail` | (0; 1,32; 1,05) | body | machanie pióropuszem |
| `ball` | (0,36; 0,29; −1,06) | — (korzeń) | kula pod łapą: zostawić na cokole, gdy lew się budzi |

Znaczniki: **`mouth_ball`** (0; 1,58; −1,58) — dziecko `head`, środek perły (słaby punkt); **`roar`** (0; 1,62; −1,77) — dziecko `head`, przed pyskiem: stożek ryku startuje stąd wzdłuż −Z głowy. Pary: drugi lew = ten sam model z `scale.x = −1` (lustro; w podglądzie `asia_vignette_hall.png` tak stoją). Pozy: szarża — przednie nogi ±35° wokół X naprzemiennie z tylnymi, `body.rotation.x` −5°, głowa nisko (−10°); ryk — `head.rotation.x` +20°, `jaw.rotation.x` −28°, perła świeci 0,6 s przed (zapowiedź).

## 8. Zbroja samuraja „ashigaru” (`samurai_ashigaru`, 256 px/m, 9062 tr., 13 części)

Pusta zbroja piechura: okegawa-dō w czarnym laku z **herbem mitsudomoe**, spódnica z granatowo sznurowanych lamelek, rękawy z kolczugi z lakowymi szynami, osłony ud i goleni, tabi w sandałach, żelazny **jingasa** nad płócienną kapturą i maską podbródka; w środku ciemność i **dwa żarzące się oczy**. W prawej dłoni **yari** (2,4 m, prosty grot, czerwone drzewce, kitka). Na lewym (prowadzącym) ramieniu **wielki naramiennik sode jako zasłona**.

**Rig = rycerz** (KnightRig steruje bez zmian): `torso` (0; 1,0; 0) korzeń; `head` (0; 1,62; 0); `arm_l` / `arm_r` (∓0,30; 1,52; 0); **`shield`** (−0,36; 1,60; −0,02) = sode, dziecko `arm_l` (postawa obronna: ShieldGuard jak u rycerza, opuszczenie przy ogłuszeniu jak tarcza); `weapon` (0,38; 1,17; −0,27) = chwyt yari, drzewce wzdłuż −Z (lekko w górę), dziecko `arm_r`; `leg_l` / `leg_r` (∓0,12; 0,92; 0) korzenie. Płyty do strącania (nazwy z `KnightRig.PLATES`): `plate_pauldron_r` (mały sode, `arm_r`), `plate_tasset_l/_r` (boczne panele spódnicy, `torso`), `plate_poleyn_l/_r` (nakolanniki, `leg_*`); `plate_pauldron_l` celowo nie ma (jego rolę gra `shield`). Znaczniki: **`face`** (0; 1,78; −0,085) — dziecko `head`, między oczami (strefa głowy rycerza); **`spear_tip`** (0,38; 1,43; −2,11) — dziecko `weapon`. Uderzenie KnightRig (ramię w górę 2,3 rad, cios w dół) czyta się jak cios yari z góry (tataki), typowy dla ashigaru.

## 9. Generał samurajów (`samurai_general`, 224 px/m, 9983 tr., 26 części, atlas 1632 × 1344)

2,7 m do szczytu hełmu, 3,0 m z rogami. Ō-yoroi: czarne lamelki pod **karmazynowym sznurowaniem kebiki**, złocone okucia, skóra napierśnika w szablonowe kwiaty wiśni, wielkie sode, cztery panele kusazuri, rękawy z granatowo-złotego brokatu, buty z niedźwiedziego futra; kabuto z żebrami i **złotymi rogami kuwagata wokół tarczy słońca**, **czerwona maska menpō z białym wąsem**, w szczelinie między daszkiem a maską żarzą się oczy; na plecach **karmazynowy węzeł agemaki**, łuk yumi i kołczan ebira; nodachi 2,15 m w obu dłoniach, pusta pochwa przy lewym biodrze.

| Część | Oś (Godot) | Rodzic |
|---|---|---|
| `pelvis` | (0; 1,29; 0) | — (korzeń) |
| `torso` | (0; 1,43; 0) | pelvis |
| `head` | (0; 2,20; 0) | torso |
| `upperarm_l` / `_r` | (∓0,41; 2,07; 0) | torso |
| `sode_l` / `_r` | (∓0,50; 2,19; 0) | upperarm_* |
| `forearm_l` / `_r` | (−0,33; 1,63; −0,08) / (0,39; 1,70; −0,18) | upperarm_* |
| `hand_l` / `_r` | (0,01; 1,42; −0,24) / (0,16; 1,57; −0,43) | forearm_* |
| `sword` | (0,10; 1,54; −0,49) = chwyt prawej dłoni | hand_r |
| `saya` | (−0,35; 1,36; −0,07) | pelvis |
| `bow` | (0; 1,70; 0,41) | torso |
| `quiver` / `arrow` | (0,27; 1,33; 0,30) / (0,36; 1,41; 0,27) | torso / quiver |
| `thigh_l` / `_r` | (∓0,16; 1,25; 0) | pelvis |
| `shin_l` / `_r` | (∓0,18; 0,71; −0,07) | thigh_* |
| `foot_l` / `_r` | (∓0,18; 0,14; 0) | shin_* |
| `kusazuri_f/_b/_l/_r` | (0; 1,33; ∓0,34) / (∓0,34; 1,33; 0) | pelvis |

Znaczniki: **`face`** (0; 2,41; −0,11, dziecko head — słaby punkt pod maską), **`back`** (0; 1,77; 0,38, dziecko torso — węzeł agemaki), **`blade_tip`** (0,16; 2,67; −1,87) i **`glint`** (0,16; 2,47; −1,68) — dzieci sword (błysk 0,7 s przed cięciem z doskoku), `bow_grip` (bow), `arrow_nock` (arrow), `saya_mouth` (saya: tu wsuwa się klinga przy dobyciu).

**Rest = chudan** (klinga ≈ 37° nad poziomem, czubek na wysokości gardła). Pozy sprawdzone renderem (`asia_vignette_duel.png`, `asia_vignette_garden.png`), w stopniach `rotation_degrees` Godota (x = obrót jak w Blenderze wokół X; y Godota = z Blendera; z Godota = −y Blendera):
- **jodan (zamach z góry):** `upperarm_l/_r.x` = +115 (oba ramiona razem: miecz zostaje w dłoniach i kładzie się za głową), `torso.x` −4, `head.x` −6, `thigh_l.x` −10, `thigh_r.x` +14, `shin_r.x` −14.
- **cięcie (koniec kesa-giri):** `upperarm_*.x` −55, `torso` (−18; −12; 0), `head` (10; 6; 0), wykrok: `thigh_r.x` +30, `shin_r.x` −30, `thigh_l.x` −22, `shin_l.x` +8. Cięcie z doskoku: przejście jodan → cięcie w 0,14 s, `pelvis.position.z` −1,5 (doskok).
- **hasso (postawa obronna / odbijanie pocisków):** `upperarm_*` (85; −10; 0), `torso.y` +35, `head.y` −30, `thigh_l.x` +12, `thigh_r.x` −12.
- **powrót:** z cięcia do chudan w 0,6–0,8 s (otwarcie na paralizator).
- **salwa z łuku (faza 2, kalenica herbaciarni):** `bow.reparent(hand_l)` z `bow_grip` w pięści i łękiem pionowo, `arrow` do `hand_r`; `upperarm_l` (80; 25; 0), `upperarm_r` (78; −25; 0), `forearm_r.y` −60, `torso.y` +15, `head.y` +20. Strzały wylatują z `arrow_nock` wzdłuż −Z łuku. `sword` na ten czas: ukryć albo `reparent` do `saya` (`saya_mouth`).
- **dobycie (faza 1, wejście na arenę):** `sword.reparent(saya)` w punkcie `saya_mouth`, prawa ręka przez ciało do pochwy (`upperarm_r` (40; 45; 0), `forearm_r.y` +70), potem szarpnięcie do jodan.

## 10. Podglądy (najlepsze ujęcia)

- **Nastrój (Cycles, `tools/art/asia_vignette.py`):** `tests/_out/art/asia_vignette_garden.png` (ogród nocą: grabiony żwir, kamienie, latarnie, most nad stawem, kwitnąca wiśnia, świecąca herbaciarnia, **Generał z łukiem na kalenicy**), `asia_vignette_hall.png` (Sala Chin: Budda w snopach reflektorów, lampiony, słupy, para psów Fu, strop kasetonowy), `asia_vignette_armour.png` (Sala Zbroi: **oddział ashigaru z żarzącymi się oczami** przed podświetlonymi shoji, zbroje na stojakach), `asia_vignette_korea.png` (dzwonnica i wóz hwacha), `asia_vignette_duel.png` (pozy Generała), `asia_vignette_fu.png`. Polecenie: `blender -b -t 4 --factory-startup --python tools/art/asia_vignette.py -- garden hall armour korea duel --samples 64` (GPU, ≈ 1 min).
- Modele: `buddha_seated.png`, `_closeup.png` (twarz), `_hands.png`; `fu_dog.png`, `_closeup.png`; `samurai_general.png`, `_closeup.png`, `_back.png`, `_sword.png`; `samurai_ashigaru.png`, `_closeup.png`, `_guard.png`; `samurai_armor_stand.png`; `vase_blue_white.png`, `vase_celadon.png`, `bronze_ding.png`, `temple_bell.png`, `_closeup.png`; `hwacha_display.png`, `_plaque.png`; `toro_kasuga.png`, `garden_bridge.png`, `garden_rock_a.png`, `teahouse.png`, `cherry_tree.png`; zestaw: `asia_lantern_red.png`, `asia_dado_4m.png`, `asia_moon_gate_4m.png`, `asia_doorframe_2x2_6.png`, `asia_lattice_window.png`, `asia_shoji_2m.png`, `asia_wallcap_4m.png`; płótna: `asia_canvas_calligraphy.png`, `asia_canvas_dragon.png`, `asia_canvas_motifs.png`.

## 11. Przepis na światło (dla integratora)

- **Sala Chin:** czerwone lampiony `asia_lantern_red` co ≈ 4,5 m na 6 m (OmniLight (1,0; 0,45; 0,28), energia jak kinkiety), dwa ciepłe reflektory na Buddę (z dołu z przodu i z boku z góry: złoto i twarz), słaba mgła; strop kasetonowy niech łapie odbite światło lampionów.
- **Korea:** ciepły snop na `weapon_spot` (OGNISTA SKRZYNIA widoczna od wejścia), światło wewnątrz dzwonnicy, lampiony.
- **Sala Zbroi:** prawie ciemno; świecą shoji (`asia_shoji_2m_lit`) i andony; zimny klucz na drogę ashigaru — ich oczy są wtedy najjaśniejsze.
- **Ogród:** zimny księżyc z góry przez otwarty dach (sun (0,55; 0,67; 1,0)), latarnie `toro_*` (OmniLight 1,0; 0,65; 0,35, mały zasięg) przy `Light`, herbaciarnia świeci od środka (światło przystani + emisja shoji), emitery płatków przy `Petals_*`, rim-light na Generała na kalenicy.

## 12. Uczciwie: słabe punkty

- Ciała Buddy i psa Fu to „glina” z metaballi: sylwetka i proporcje czytają się z daleka; pierś Buddy jest miękka i zaokrąglona bardziej, niż powinna, palce dłoni na kolanie są grube. Twarz Buddy jest rzeźbiona polem przesunięć (jak twarze egipskie) i czyta się dobrze.
- Atlasy: Budda 2080 × 1152, Fu 1792 × 1024, Generał 1632 × 1344, herbaciarnia 1536 × 1024 — duże, ale każdy model jest pojedynczym bohaterem sali.
- Brama księżycowa ma przejście ze ściętym dołem okręgu (grywalność); narożniki prostokątnego otworu zasłania tylko panel (kolizja z greyboxu).
- Kwiaty wiśni: kiście to bryły z małych płatów z kartami alfa na brzegach; z bardzo bliska widać, że płaty są pełne.
- Wody stawu nie ma w głąb (płaszczyzna +3 cm): koi są namalowane.
- Pozy Generała podane jako rotacje części; salwa z łuku i dobycie wymagają `reparent` (łuk do lewej pięści, miecz do pochwy) — przepis w §9, sprawdzony w Blenderze, nie w grze.
- Lamelki sznurowania są malowane (piksel = sznurek), a nie modelowane; z odległości < 0,5 m widać, że to tekstura.

## 13. Testy i budowa

- `tests/integration/test_art_asia.gd` (6 testów, bez okna): każdy model skrzydła (części, znaczniki, budżet, wysokość, materiały), zestawy tekstur `ArtLibrary.ASIA_SETS`, rig psa Fu (łańcuchy, `mouth_ball` w pysku, `roar` przed nim), ashigaru z nazwami rycerza (`shield` na lewym ramieniu z przodu, `face` na 1,78 m, grot z przodu), łańcuchy i znaczniki Generała (twarz, plecy, czubek klingi, dłonie na chwycie), znaczniki eksponatów (stopień ofiarny, `weapon_spot`, dzwon i belka, kalenica, `terminal_spot`, emitery płatków, światła latarni). `test_art_kit.gd`: wszystkie elementy `asia_*` (budżety, datumy, pola 64 px/m).
- Przebudowa: `blender -b -t 4 --factory-startup --python tools/art/build_models.py -- kit_asia_walls kit_asia_fixtures kit_asia_portals buddha exhibits_asia hwacha_display samurai_ashigaru samurai_general samurai_armor_stand fu_dog garden_kit cherry_tree teahouse` (≈ 20 min jednym procesem); pola: `python tools/art/build_textures.py asia_plaster asia_plaster_dark asia_band tiles_golden stone_slate asia_coffers asia_lacquer asia_lacquer_black boards_dark gravel_raked gravel_plain garden_wall tatami cherry_blossom thatch`.
