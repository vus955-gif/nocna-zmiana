# Katalog grafiki: Piętro I — skrzydło asyryjskie (pałace Niniwy i Nimrud)

> Gałąź `art-assyria`. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§5.2, §7.3, §7.4 — Lamassu, §10). Plan: `docs/superpowers/plans/2026-10-02-art-asyria.md`.
> Wszystko powstaje skryptami Blendera w tle: `tools/art/models/kit_asy_reliefs.py`, `kit_asy_arch.py`, `kit_asy_props.py`, `relief_warrior.py`, `relief_lion.py`, `lamassu.py`, `khorsabad_gate.py`, `asy_chips.py`; wspólne `tools/art/artlib/asy_relief.py` (płaskorzeźba 2D; Grecja ma osobne `relief.py`), `asy.py` (paleta, materiały, tekstury kafelkowe), `asy_figures.py` (postacie), `asy_panels.py` (kompozycje płyt), `asy_mesh.py` (płyty cięte po konturach), `lamassu.py` (lamassu). Budowa: `bash tools/art/build_art.sh <nazwy>` (szybko: `FAST=1`), tekstury pól: `python tools/art/build_textures.py asy_alabaster …`.
> Szybki podgląd rysunków reliefów bez Blendera (sekundy): `python tools/art/asy_preview2d.py [nazwy]` → `tests/_out/art/asy2d_*.png`. Ujęcia nastroju: `blender -b -t 4 --factory-startup --python tools/art/asy_vignette.py -- --samples 64`.
> **Osie:** liczby w osiach **Godota** (x w prawo, y w górę, −z = przód modelu). Blender (x, y, z) → Godot (x, z, −y). Wszystko patrzy na **−Z**; wrogowie i strażnik też (przód = do gracza).

## 1. Jak powstają reliefy (jedno źródło dla płyt i wrogów)

Płaskorzeźba jest rysowana raz, w 2D, jako pole wysokości w metrach (`artlib/asy_relief.py`): kształty SDF (elipsy, wielokąty, stożkowe kapsuły kończyn, krzywe) podnoszone do wysokości z zaokrągloną krawędzią i składane **maksimum** (ramię nad tułowiem daje schodek, daleka noga widać tylko tam, gdzie nic jej nie zasłania) — tak rzeźbi się niski relief. Do tego nacięcia (pasma brody, frędzle, mięśnie łydek, kliny pisma), loki (rzędy kopułek z wierconym środkiem), pióra (łuski pokryw i długie lotki), malatura (czarne włosy i brody, czerwona ochra, białe oczy z czarną źrenicą).

Konwencje oryginałów, trzymane celowo: głowa z profilu z **okiem en face** pod ciężką brwią, kwadratowa broda w piętrach loków, łydka jako podwójny mięsień z nacięciami, frędzle i rozety, Standardowa Inskrypcja Assurnasirpala przecinająca postać geniusza. Pismo klinowe to prawdziwe kształty klinów (poziome, pionowe, ukośne, haczyki) w znakach i liniach z liniaturą — nie da się go przeczytać, ale wygląda właściwie.

Ten sam rysunek daje: (1) **teksturę płyty** (albedo z kroków po rampie alabastru: zagłębienia −2,6, krawędzie +1,4, słaby klucz z lewej góry; normalna z wysokości; ORM), (2) **zarysy płaskich części wroga** (maska części → kontur po krawędziach tekseli → RDP → bryła o grubości warstwy), (3) **postać we wnęce płyty przebudzenia** — w tym samym miejscu i skali co wróg, więc przejście ściana → wróg jest bez skoku.

## 2. Paleta i gęstości

| Klasa | px/m | Modele |
|---|---|---|
| pola kafelkowe, architektura | 64 | tekstury pól, fryz, belki, krenelaż, portal, mur bramy (pole `tile:asy_alabaster`) |
| płyty z reliefem | 128 | `asy_relief_*` (postać 1,9 m = 243 teksele, oko 5 tekseli) |
| bramy, próg, cokoły | 80–160 | `khorsabad_gate` 80, próg i cokoły 96, wrota z Balawat 160, regały 128 |
| strażnik | 112 | `lamassu` (jak T-Rex) |
| wrogowie | 256 | `relief_warrior`, `relief_lion`, odłamki |
| rekwizyty z bliska | 160–256 | pochodnia 192, trójnóg 160, pryzmat 256 |

Rampy (słownik `P`, przedrostek `asy_`, żeby nie kolidować z innymi skrzydłami): `asy_alabaster` (szaroniebieski gips z Mosulu, 14 tonów), `asy_alabaster_warm` (tynk, patyna), `asy_paint_black`, `asy_ochre_red`, `asy_lapis`, `asy_glaze_yellow`, `asy_glaze_white`, `asy_cedar`, `asy_mudbrick`, `asy_brick_baked`, `asy_bitumen`, `asy_clay`, `asy_flame`, `asy_gypsum_break` (świeży przełom). Brąz: wspólne `bronze` / `bronze_metal`.

## 3. Pola kafelkowe (64 px/m, `ArtLibrary.arch_tile`)

| Tekstura | Kafel | Co to jest | Gdzie |
|---|---|---|---|
| `asy_alabaster` | 4 × 3 m | lico ortostatów bez reliefu: płyty 1–2 m × 3 m, cienkie spoiny, ślady zębatki, brud u stopy | ściany do 3 m (za płytami, ościeża, gładkie ściany), mur Bramy Chorsabadu |
| `asy_plaster` | 4 × 2 m | tynk glinowo-wapienny nad ortostatami: smugi kielni, rysy, sadza | ściany powyżej 3 m |
| `asy_mudbrick` | 4 × 2 m | cegła suszona 0,4 × 0,14 m w zaprawie glinianej, resztki tynku | dziedziniec powyżej 3 m, magazyn tabliczek |
| `flagstone_asy` | 4 × 4 m | posadzka z płyt gipsowych 1 × 1 i 2 × 1 m, bitumiczne spoiny, wytarte ścieżki | sale (nazwa zaczyna się od „flagstone”: kroki brzmią jak kamień) |
| `tiles_asy_brick` | 2 × 2 m | cegła palona 1/3 m w bitumie, co piąta z ramką królewskiej pieczęci | dziedziniec pałacu, magazyn |
| `asy_cedar` | 2 × 2 m | strop z desek cedrowych 0,25 m, przyciemniony sadzą | stropy sal |

## 4. Style pomieszczeń (`ArtKit.ROOMS`, dopisane)

Wspólne: płyty z reliefem od podłogi do 3 m jako **pas** `asy_relief_` (moduły 2 i 1 m), malowany fryz `asy_frieze_` na 3,0 m, tynk powyżej (`upper_from` 3,0), posadzka `flagstone_asy`, strop `asy_cedar` z belkami `asy_beam_4m` co 4 m i wspornikami `asy_corbel`, portal `asy_portal_4m` (klucz `frame_4`), ościeżnica `asy_doorframe_2x2_6` (`frame_2_6`). **Temat reliefów** w sali wybiera przedrostek zestawu tekstur pasa (`"set": "asy_relief_<temat>_"` → zestawy `asy_relief_<temat>_2m` / `_1m`).

| Pokój | Temat płyt | Uwagi |
|---|---|---|
| `assyria_nimrud` | domyślny: geniusz (2 m) / włócznik (1 m) | Galeria Pałacu Nimrud |
| `assyria_gate` | `hunt` (polowanie na lwy / inskrypcja) | hala Bramy Chorsabadu (stoi w niej `khorsabad_gate`) |
| `assyria_lions` | `lions` (wielki lew, lew w skoku / inskrypcja) | Sala Lwów: płyty `asy_relief_wake_lion` wśród zwykłych |
| `assyria_balawat` | `army` (włócznicy nad łucznikami / włócznik) | Wrota z Balawat |
| `assyria_courtyard` | `chariot` (rydwan króla nad włócznikami / włócznik) | ściany wyżej z cegły suszonej, posadzka z cegły palonej, bez belek (otwarty strop) |
| `assyria_service_stairs` | — | tynk, płyty; bez pasów |
| `assyria_tablets` | — | magazyn tabliczek (sekret): cegła suszona, cegła palona, strop cedrowy |
| `assyria_library` | `text` (inskrypcje) | biblioteka Aszurbanipala nad schodami towarowymi; regały `asy_tablet_shelf`, `asy_prism` na `asy_plinth` |
| `assyria_lions_gallery` | jak `assyria_lions` | pierścień galerii nad dołem |
| `assyria_freight_stairs` | jak `assyria_service_stairs` | schody towarowe |

Pozostałe tematy do ręcznego użycia: `genie_l` (geniusz w lewo, do pary z domyślnym — flankują drzwi), `text`, `plain`.

## 5. Zestaw (`ArtLibrary.KIT`, konwencja zestawu: początek w środku podstawy, front −Z)

Liczby z ostatniej pełnej budowy (z AO): trójkąty pliku .glb, atlas, gęstość.

| Id | Części | Trójkąty | Atlas | px/m |
|---|---|---|---|---|
| `asy_relief_2m` (+ 7 zestawów) | 1 | 20 | 352 × 448 | 128 |
| `asy_relief_1m` (+ 7 zestawów) | 1 | 20 | 224 × 448 | 128 |
| `asy_relief_wake` | 2 | 568 | 416 × 576 | 128 |
| `asy_relief_wake_lion` | 2 | 1 078 | 704 × 512 | 128 |
| `asy_frieze_4m` / `_2m` / `_1m` | 1 | 14 | 288 × 96 / 160 × 96 / 96 × 96 | 64 |
| `asy_beam_4m` | 1 | 464 | 352 × 192 | 64 |
| `asy_corbel` | 1 | 272 | 224 × 128 | 64 |
| `asy_parapet_2m` | 1 | 396 | 224 × 352 | 64 |
| `asy_portal_4m` | 1 | 368 | 384 × 704 | 64 |
| `asy_doorframe_2x2_6` | 1 | 132 | 352 × 128 | 128 |
| `asy_threshold_4m` | 1 | 46 | 416 × 416 | 96 |
| `asy_plinth` / `asy_plinth_low` | 1 | 136 / 132 | 448 × 320 / 512 × 512 | 96 |
| `asy_torch` | 1 | 508 | 320 × 160 | 192 |
| `asy_brazier` | 1 | 854 | 512 × 256 | 160 |
| `asy_balawat_leaf_l` / `_r` | 1 | 665 | 672 × 1184 (tył: `tilelocal:asy_cedar`) | 160 |
| `asy_tablet_shelf` | 1 | 1 148 | 1088 × 736 | 128 |
| `asy_tablet_crate` | 1 | 340 | 320 × 512 | 128 |
| `asy_prism` | 1 | 136 | 384 × 224 | 256 |
| `khorsabad_gate` | 7 | 24 868 | 1504 × 1568 (mur: `tile:asy_alabaster`) | 80 |
| `lamassu` (REGISTRY) | 20 | 9 920 | 1376 × 832 (+ `lamassu_cracked`) | 112 |
| `relief_warrior` (REGISTRY) | 8 | 2 220 | 1088 × 640 | 256 |
| `relief_lion` (REGISTRY) | 8 | 2 824 | 1088 × 768 | 256 |
| `asy_gypsum_chips` (REGISTRY) | 8 | 112 | 224 × 192 | 256 |

Budżety w `tests/integration/test_art_kit.gd`: domyślne 1200 dla zestawu, `khorsabad_gate` 26 000, `asy_tablet_shelf` 1500; własny test `tests/integration/test_art_assyria.gd` (strażnik < 16 000, wrogowie < 4000, osie, znaczniki, rozmiary, zestawy tekstur).

| Id | Rozmiar (x × y × z) | Opis, oś i datum | Rozmieszczenie |
|---|---|---|---|
| `asy_relief_2m` | 2,0 × 3,0 × 0,12 | płyta ortostatu: lico z reliefem, fazy 14 mm; **ścienna**: początek na podłodze w płaszczyźnie ściany (z = 0), płyta po stronie pokoju (−Z). Zestaw domyślny: skrzydlaty geniusz z szyszką i wiaderkiem, Standardowa Inskrypcja przez postać | pas `asy_relief_` w stylach `assyria_*`; tematy: `asy_relief_<genie_l, army, chariot, hunt, lions, text, plain>_2m` |
| `asy_relief_1m` | 1,0 × 3,0 × 0,12 | jw., domyślnie włócznik naturalnej wielkości pod pasem pisma | dopełnienie pasów; tematy `_1m` |
| `asy_relief_wake` | 1,0 × 3,0 × 0,12 | **płyta przebudzenia**: ten sam włócznik co w `asy_relief_1m`, ale jako część **`figure`** (osobna bryła we wnęce w kształcie postaci, 6 mm przed licem), wokół pęknięcia i szczelina w **mapie emisji** (`EXTRAS` 0,0 = spoczynek). Zapowiedź: `own_materials()` → `emission_energy_multiplier` 3–6. Wyjście: ukryj `figure`, zostaje pusta wnęka z przełomem gipsu; `relief_warrior` staje dokładnie tam: na podłodze w (0,13; 0; −0,1) od początku płyty, w tej samej orientacji co płyta (przód −Z do pokoju) — rysunek wroga pokrywa się wtedy z rysunkiem w płycie | zamiast zwykłego `asy_relief_1m`/`army_1m` (nie do odróżnienia, dopóki nie zaświeci) |
| `asy_relief_wake_lion` | 2,0 × 3,0 × 0,12 | to samo dla Sali Lwów: wielki kroczący lew dolnego rejestru jako `figure` (`relief_lion` na podłodze w (−0,06; 0; −0,1) od początku płyty, orientacja płyty); górny rejestr i pismo jak w `asy_relief_lions_2m` | wśród płyt `lions` |
| `asy_frieze_4m/2m/1m` | L × 0,62 × 0,045 | malowany fryz (malowidła z Nimrud): czerwone i niebieskie palmety z pąkami lotosu na łukach, zygzak, szachownica, czarne linie; **datum = dolna krawędź** (połóż na 3,0 m, na szczytach płyt); wzór co 0,5 m, moduły się łączą | pas `asy_frieze_` na 3,0 m |
| `asy_beam_4m` | 4,0 × 0,44 × 0,36 | belka cedrowa z brązowymi opaskami i rozetami; początek u góry, na płaszczyźnie stropu (wisi) | co 4 m w poprzek sali (`beams` w stylu) |
| `asy_corbel` | 0,5 × 0,62 × 0,6 | schodkowy wspornik gipsowy z cedrową podkładką; ścienny, początek na ścianie na **górze** wspornika (= spód belki) | pod końcami belek (`corbel` w stylu) |
| `asy_parapet_2m` | 2,0 × 0,95 × 0,58 | dwa schodkowe merlony (trzy stopnie) z cegły z wapnem na gipsowym gzymsie; obie strony wykończone; początek na koronie muru | szczyty murów dziedzińca, mury bramy |
| `asy_portal_4m` | 5,6 × 5,5 × 0,17 | obramienie otworu 4 × 4,5 m: alabastrowe węgary z plecionką i kolumną rozet, cedrowe nadproże z brązowymi okuciami, pas **glazurowanej cegły** (lapis, żółte rozety, biały zygzak), gzyms; początek = środek podłogi otworu na licu ściany (jeden na każdą stronę przejścia) | `frame_4`; drzwi 4 × 5–6 m: skaluj Y (×1,11–1,33) |
| `asy_doorframe_2x2_6` | 2,3 × 2,8 × 0,16 | cedrowa opaska z brązowymi rozetami | drzwi 2 × 2,6 (Sala Lwów → schody) |
| `asy_threshold_4m` | 4,0 × 0,015 × 1,2 | rzeźbiony próg-„dywan”: siatka czteropłatkowych rozet w kwadratach, bordiura z pąków i kwiatów | w przejściach; skaluj Z do głębokości muru |
| `asy_plinth` | 1,1 × 1,0 × 1,1 | cokół ekspozycyjny z alabastru, pas rzeźbionych rozet | pod rekwizyty (pryzmat, tabliczki) |
| `asy_plinth_low` | 2,5 × 0,4 × 1,3 | niski cokół | pod większe eksponaty |
| `asy_torch` | 0,2 × 0,55 × 0,45 | lampa-pochodnia: płyta z maską lwa, wygięte ramię, brązowy kosz, płomień ze świecącego szkła (`EXTRAS` 4,5); **oprawa: początek = światło**, uchwyt 0,35 m w +Z do ściany; znacznik `Light` | co 4 m na wysokości ~3,4 m (nad fryzem nie, w paśmie płyt między płytami albo na fryzie) |
| `asy_brazier` | 0,7 × 1,63 × 0,7 | trójnóg z brązu na lwich łapach, misa żaru (emisja) i płomienie; początek na podłodze, znacznik `Light` (płomień, y 1,38) | dziedziniec (arena), przed bramą |
| `asy_balawat_leaf_l` / `_r` | 2,26 × 5,17 × 0,32 | skrzydło **Wrót z Balawat**: deski cedrowe na okrągłym słupie-zawiasie, **7 brązowych pasów** po dwa rejestry miniatur (włócznicy, łucznicy, rydwany, lwy) z rzędami nitów-rozet; **brama Pieczęci Skrzydła**: na stykającym się brzegu połowa brązowej tarczy z gniazdem i rozpostarte skrzydła. Rama skrzydła drzwi (początek w środku podstawy, **lico dekoracyjne +Z** = pokój A, Asyria; `_l` zawias na −X). Znaczniki **`SealSocket`** i `seal_socket` na `_l` (1,0; 1,47; 0,145) | przejście `j_assyria_americas` (4 × 5 m, `seal_balawat`) |
| `asy_tablet_shelf` | 2,0 × 2,2 × 0,5 | regał magazynu: tabliczki stojące w rzędach, leżące w stosach i w tekturowych tackach, papierowe etykiety | magazyn tabliczek (sekret) |
| `asy_tablet_crate` | 0,9 × 0,48 × 0,6 | skrzynia z tabliczkami w słomie, szablon „NINIWA / BRIT.MUS. 1850” | jw. |
| `asy_prism` | 0,5 × 0,43 × 0,34 | sześciokątny gliniany graniastosłup Sanheryba z pismem na stojaku, mosiężna tabliczka „691 P.N.E.” | nagroda/notatka w magazynie, na `asy_plinth` |
| `khorsabad_gate` | 7,0 × 9,4 × 4,95 (24 868 tr.) | **Brama Chorsabadu** (rozdz. 6) | po stronie Asyrii przejścia `j_egypt_assyria` |

## 6. Brama Chorsabadu (`khorsabad_gate`)

Przejście z Egiptu (`j_egypt_assyria`, otwór 6 × 8 m w murze 1 m). Brama stoi **po stronie asyryjskiej** (w hali `assyria_gate`), początek = środek podłogi otworu na licu muru, bryła w pokoju (−Z). Dwa lamassu 4,5 m (pięcionogie: z przodu stoją, z boku kroczą) stoją **w szerokości otworu** (osie x ∓2,25), twarzami do Egiptu: kto otworzy pieczęć, widzi dwie twarze w wysokich koronach, a między ich bokami 3,1 m przejścia. Za nimi bloki z inskrypcją (widać ją między nogami), na koronach wieże z murem pola `tile:asy_alabaster`, nad wewnętrznym końcem łuk z glazurowanej cegły, schodkowe merlony do 9,4 m (hala ma 10 m).

| Część / znacznik | Oś (Godot) | Uwagi |
|---|---|---|
| `khorsabad_gate` | (0; 0; 0) | mur, cokoły, inskrypcje, łuk, merlony — statyczne, kolizja z poziomu (dwa prostopadłościany wież: x ±1,5…3,5, z −4,6…0; cokoły posągów x ±1,55…2,95) |
| `lamassu_l`, `lamassu_r` | (∓2,25; 0,25; −2,25) | posągi (nogi, skrzydła, korona); `lamassu_*_body` (dzieci) — tułów i głowa |
| `door_l`, `door_r` | (∓1,5; 0; −4,1) | **opcjonalne** kamienne skrzydła pod łukiem (rama skrzydła: oś na zawiasie), rzeźbiony „dywan” rozet, po połowie tarczy słońca z promieniami. Egipt (`egypt_seal_door_*`) już zamyka to przejście od swojej strony — wtedy te dwa ukryć (albo odwrotnie). Otwieranie: obrót wokół Y o ±70° w głąb hali |
| `seal_socket`, `SealSocket` | (0; 1,6; −3,92) | środek gniazda tarczy słońca, przed drzwiami |

**Szkic W4** stawia w hali dwa elementy `lamassu` (x −53,3 / −48,7, z −41,7, 1,4 × 4,5 × 4,6, obrót π): to dokładnie posągi tego modelu (∓2,25 od osi otworu, ~2,3 m w głąb). Postaw `khorsabad_gate` w (−51; 0; −39) bez obrotu (front −Z = północ, posągi patrzą na południe, do Egiptu) zamiast obu elementów; płyty `relief_slab` i reliefy ścienne `NW.relief` szkicu zastępują `asy_relief_2m/1m` (3 m zamiast 2,6 m: pas `asy_relief_` w stylu sali).
| `Light_l`, `Light_r` | (∓3,2; 3,8; −4,95) | pochodnie na północnych licach wież (`asy_torch` bez obrotu pasuje) |

## 7. Lamassu — strażnik (`lamassu`, 112 px/m)

Skrzydlaty byk z ludzką głową, ok. **4,0 m** do szczytu korony, 3,6 m długości; alabaster ze śladami farby (czarna broda i włosy, czerwony pas korony, malowane oczy) i brązem (kolczyki, rozety korony). Rest = stoi, skrzydła złożone na grzbiecie. Początek na podłodze pod tułowiem; patrzy na −Z.

| Część | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `body` | (0; 1,9; 0) | — | korzeń: szarża, skok, przechył |
| `head` | (0; 2,6; −1,22) | body | szyja: twarz, uszy z kolczykami, broda w piętrach loków, włosy |
| `headdress` | (0; 3,22; −1,5) | head | wysoka korona z trzema parami rogów i piórami — **do strącenia** (faza 3 / obrażenia) |
| `wing_l`, `wing_r` | (∓0,54; 2,18; −0,68) | body | wewnętrzne płyty skrzydeł (pokrywy); **podmuch**: obrót wokół Z (Godot) ±60–75° (w górę i na zewnątrz) |
| `wing_l_tip`, `wing_r_tip` | (∓0,31; 2,76; 0,47) | wing_* | zewnętrzne płyty (lotki), staw nadgarstka; przy rozłożeniu jeszcze ±20–30°; **do odłamania** |
| `tail` | (0; 2,0; 1,46) | body | ogon z kitą loków |
| `thigh_fl/fr` | (∓0,41; 1,55; −0,8) | body | barki |
| `thigh_bl/br` | (∓0,41; 1,65; 0,98) | body | biodra |
| `shin_*` | kolana (∓0,41; 0,72; −0,86) / stawy skokowe (∓0,41; 0,7; 1,2) | thigh_* | zgięcie (rotation.x) |
| `hoof_*` | pęciny (∓0,41; 0,24; −0,9) / (∓0,41; 0,24; 1,1) | shin_* | kopyta (grzebanie przed szarżą: `hoof_fl.rotation.x` ±30° w rytmie) |

**Znaczniki:** `face` (0; 3,07; −1,81) — dziecko `head`, słaby punkt ×1,5 (środek twarzy); `crown` (0; 3,62; −1,5) — dziecko `headdress`, drugi słaby punkt; `contact_fl/fr/bl/br` — pod kopytami na podłodze (dzieci `hoof_*`): kurz, fala tupnięcia, IK.

**Zestawy tekstur:** `lamassu` i **`lamassu_cracked`** (sieć pęknięć z żarem w mapie emisji, `EXTRAS` 2,5): faza 2–3 przez `ArtLibrary.exhibit(&"lamassu", {"lamassu": "lamassu_cracked"})` (`ASSYRIA_SETS`). Obwódka przebudzenia `EXHIBIT_RIM` 0,24.

**Pozy dla kodu:** szarża — `body.rotation.x` −8° (głowa w dół), przednie `thigh` ±35° na przemian, `shin` +40° przy wymachu; grzebanie (zapowiedź 1 s) — `thigh_fr.rotation.x` −25°, `shin_fr` +45°, `hoof_fr` ±25° w rytmie; podmuch (0,8 s) — `wing_l.rotation.z` +70°, `wing_r` −70°, końcówki ±25°, `body.rotation.x` +6°; tupnięcie — oba przednie `thigh` −30° i w dół, kontakt w `contact_f*`; skok — `body.position.y` w górę, nogi podkulone (`thigh` ±40°, `shin` +70°). Ujęcie `asy_vignette_courtyard.png` pokazuje skrzydła i przednią nogę obrócone wyłącznie w stawach.

## 8. Wojownik z reliefu (`relief_warrior`, 256 px/m)

Płaski asyryjski włócznik: płyta gipsu **1,9 m** (z włócznią 2,2 m) i **0,18 m** grubości, wycięta po konturach postaci (ta sama co na płytach 1 m). Z przodu rzeźbione lico (szpiczasty hełm z nausznikiem, broda w lokach, łuskowa koszula, frędzlowa tunika, sznurowane buty, okrągła tarcza z nitami, włócznia), z tyłu i na krawędziach **świeży krystaliczny przełom** — tu oderwał się od ściany. Z boku to deska (trafienia w krawędź ×0,5). Rysunek patrzy w prawo gracza (+X).

| Część | Oś (Godot) | Rodzic | Głębokość (z) |
|---|---|---|---|
| `torso` | (0; 0,98; 0) | — | −0,05…0,09 |
| `head` | (−0,035; 1,47; 0) | torso | −0,055…0,08 |
| `arm_front` | (−0,04; 1,37; 0) bark | torso | −0,09…0,02 (najbliżej gracza) |
| `spear` | (−0,36; 1,12; 0) chwyt | arm_front | −0,06…−0,025 (rzut: odczep i leć łukiem) |
| `arm_back` | (0,02; 1,37; 0) | torso | 0…0,09 |
| `shield` | (−0,19; 1,21; 0) pięść | arm_back | −0,08…0 |
| `leg_front`, `leg_back` | biodra (−0,04 / 0,05; 0,95; 0) | — (jak rycerz) | −0,07…0,06 / −0,01…0,09 |

**Znacznik `eye`** (−0,113; 1,648; −0,065) — dziecko `head`, na licu: słaby punkt z przodu. **Ruch „papierowej lalki”:** wszystkie stawy obracają się wokół **osi Z (normalnej płyty)**: chód `leg_*.rotation.z` ±15°, rzut `arm_front.rotation.z` do −120° (włócznia nad głową), krok w bok = przesunięcie po X. Wejście w ścianę i wyjście 6 m dalej: płyta `asy_relief_wake` (ukryj/pokaż `figure`). Obwódka `EXHIBIT_RIM` 0,4.

## 9. Lew z reliefu (`relief_lion`, 256 px/m)

Wielki kroczący lew z płyt Sali Lwów (Aszurbanipal, Niniwa), wycięty jak wojownik: ok. **1,0 m** do grzywy (ogon 1,2 m), 2,0 m długości, 0,16 m grubości. Grzywa z płomienistych kosmyków, mięśnie i żebra jako nacięcia, otwarta paszcza z kłami. Nazwy części jak u **wilka** (zachowanie: podchodzenie i doskok), ale stawy obracają się wokół **osi Z** (płyta).

| Część | Oś (Godot) | Rodzic |
|---|---|---|
| `body` | (0,12; 0,66; 0) | — |
| `head` (z grzywą) | (−0,42; 0,80; 0) szyja | body |
| `jaw` | (−0,60; 0,76; 0) zawias | head |
| `tail` | (0,66; 0,80; 0) | body |
| `leg_fl`, `leg_fr` | barki (−0,27 / −0,22; 0,66 / 0,68; 0) | body |
| `leg_bl`, `leg_br` | biodra (0,50 / 0,46; 0,70 / 0,72; 0) | body |

`leg_fl`, `leg_bl` = bliższe (z przodu płyty). **Znacznik `eye`** (−0,69; 0,895; −0,09) — dziecko `head`. Doskok: `body.rotation.z` −20…−25° (przód w górę), przednie `leg_f*` −40°, tylne +20°, `jaw` +20°. Obwódka 0,45.

## 10. Odłamki (`asy_gypsum_chips`)

Osiem kawałków gipsu 3–14 cm (`chip_1` … `chip_8`, osie w środkach, 14 trójkątów każdy): świeże przełomy, na większych kawałek rzeźbionego lica. Do rozrzucenia przy rozpadzie wojownika/lwa i przy wyjściu z płyty przebudzenia (pył + odłamki).

## 11. Podglądy (najlepsze ujęcia, `tests/_out/art/`)

Kopie JPG najważniejszych ujęć leżą w `docs/art/img/asy_*.jpg` (zrzuty z `tests/_out/art/` są poza gitem).

- **Nastrój skrzydła** (Cycles, przepis na światło z rozdz. 12): `asy_vignette_gallery.png` (Galeria Nimrud: płyty w kilku tematach, fryz, belki, pochodnie; płyta pękająca i pusta wnęka, wojownik wychodzący, lew w doskoku), `asy_vignette_gate.png` (Brama Chorsabadu widziana z Egiptu przez otwór), `asy_vignette_gate_hall.png` (od strony hali: łuk z glazury, drzwi), `asy_vignette_courtyard.png` (Lamassu na dziedzińcu w księżycu, krenelaż, trójnogi). Skrypt: `tools/art/asy_vignette.py`.
- **Reliefy:** `asy_panels_sheet.png` (wszystkie kompozycje 2D: geniusz, geniusz w lewo, wojsko, rydwan, polowanie, lwy, inskrypcja, włócznik 1 m), `asy_relief_2m_close.png` (zbliżenie wypieczonej płyty), `asy_relief_2m_rake.png` (pod kątem), `asy_relief_wake_close.png` (pęknięcia z żarem), `asy_relief_wake_lion.png`.
- **Strażnik:** `lamassu.png`, `lamassu_closeup.png` (twarz, broda w lokach, korona z rogami).
- **Brama:** `khorsabad_gate.png`, `khorsabad_gate_approach.png`, `khorsabad_gate_face.png`.
- **Wrogowie:** `relief_warrior.png` (przód, deska z boku, przełom z tyłu), `relief_warrior_closeup.png`, `relief_lion.png`, `asy_gypsum_chips.png`.
- **Zestaw:** `asy_frieze_4m_close.png`, `asy_portal_4m_lintel.png`, `asy_balawat_leaf_l_bands.png` (miniatury na brązie), `asy_torch.png`, `asy_brazier.png`, `asy_tablet_shelf.png`, `asy_prism_closeup.png`, `asy_threshold_4m.png`, `textures_sheet.png` (pola).

## 12. Przepis na światło (dla integratora)

Skrzydło jest **niskie, ostre i czerwone**: pochodnie `asy_torch` co 4 m na ~3,4 m (OmniLight 1,0; 0,42; 0,16, zasięg 7–8 m, cienie tylko przy co drugiej), które kładą długie poziome cienie po reliefach (normalne płyt są mocne — reliefy żyją w świetle z boku); zimne wypełnienie z góry (księżyc przez otwór w stropie dziedzińca i słabe niebieskie światło otoczenia w salach); mgła lekka, iskry nad pochodniami (cząsteczki). Płyty przebudzenia w spoczynku nie świecą — zapowiedź to emisja szczelin podniesiona do 3–6 i krótki migot pochodni obok. Dziedziniec Lamassu: księżyc z wysoka (DirectionalLight z cieniem), trójnogi `asy_brazier` jako ciepłe wyspy, krenelaż `asy_parapet_2m` rysuje się na niebie.
