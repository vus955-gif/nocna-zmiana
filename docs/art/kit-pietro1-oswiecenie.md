# Katalog grafiki: Piętro I — skrzydło Oświecenia

> Gałąź `art-enlight`. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§2, §5.4, §7.3, §7.4 — Wielkie Planetarium, §10.1–10.2). Plan: `docs/superpowers/plans/2026-10-02-art-oswiecenie.md`.
> Wszystko powstaje skryptami Blendera w tle (`tools/art/models/lib_*.py`, `planetarium.py`, `flying_book.py`; wspólne `tools/art/artlib/enl_materials.py`, `enl_books.py`, `enl_geo.py`, `enl_preview.py`). Budowa: `bash tools/art/build_art.sh lib_bookcases lib_walkway …` (szybko: `FAST=1`; jeden model rodziny: `ENL_ONLY=lib_rifle_rack`). Tekstury kafelkowe: `python tools/art/build_textures.py parquet_chevron enl_mahogany enl_bookside enl_oak_boards`.
> Podglądy Cycles: `tests/_out/art/<id>.png` (+ ujęcia dodatkowe), sceny złożone: `blender -b --python tools/art/scene_enlight.py -- [gallery shelves walkway ceiling orrery orrery_close cabinet rifle clocks]` → `tests/_out/art/enl_scene_<ujęcie>.png`.
> **Osie:** liczby poniżej są w osiach **Godota** (x w prawo, y w górę, −z = przód modelu). Blender (x, y, z) → Godot (x, z, −y). Każdy model patrzy na **−Z**; dla postaci i ksiąg „lewa” = −X.
> **Rejestr:** `ArtLibrary.KIT` (nazwy części i znaczników), `ArtLibrary.KIT_ENLIGHTENMENT` (rozmiar natywny + budżet trójkątów: `ArtKit.piece(<id modelu>, size, room)` skaluje element do rozmiaru greyboxa), `KIT_SETS` (zestawy tekstur), `REGISTRY` + `ENLIGHTENMENT_SETS` (strażnik i wróg), `EXTRAS` (emisja), `EXHIBIT_RIM`. Test bez okna: `tests/integration/test_art_enlightenment.gd`.

## 1. Kierunek, paleta, gęstości

Ciemny dąb i mahoń, mosiądz, zielone klosze i zielone sukno; złocenia grzbietów, czerwony maroken, granat emalii Planetarium. Światło: ciepłe plamy z lampek, długie cienie regałów, zimne snopy księżyca ze świetlików w stropie.

| Klasa | px/m | Modele |
|---|---|---|
| pola kafelkowe, strop, gzyms | 64 | tekstury pól, `lib_coffer_2m`, `lib_skylight_well_4m`, `lib_cornice_*` |
| kładka, portale | 96 | `lib_walkway_fascia_*`, `lib_portal_4x4_5`, `lib_stair_stringer_4m`, `lib_diorama_base` |
| regały (grzbiety!) | 144 | `lib_bookcase_*` (pilastry 128) |
| meble, okucia | 128–160 | balustrady, schody, drabina, gabloty historii naturalnej, gabinet bibliotekarza, szafa ze sztucerem |
| gabloty z osobliwościami, globusy, zegary | 192 | `lib_case_*`, `lib_globe_*`, `lib_clock_*`, `lib_antlers` |
| eksponaty z bliska, wróg | 256 | automaty, lampy, `flying_book` (lampa biurowa 384) |
| strażnik | 96 | `planetarium` (rdzeń słońca i wnętrza łupin 48) |

Rampy (`P`, przedrostek `enl_`): mahoń, ciemny dąb, skóry opraw (cielęca, maroken czerwony/zielony/granatowy, czarna, welin), płótna (bordo, oliwka, łupek), papier, atrament, sukno zielone, jedwab, zielone szkło klosza, emalia granatowa, pergamin i laweryjne kolory mapy, tynk chłodny, fryz, stal ciemna, a w modelach: muszle, minerały, srebro, planety (Merkury … Saturn, słońce), słoje, róg, pióra, puder peruki.

**Malarz grzbietów** (`artlib/enl_books.py`): półka jest wypełniana tomami (folio, quarto, octavo, małe), seriami pasujących tomów (ta sama skóra, szyldziki), pojedynczymi tomami, ukośnie opartymi księgami, leżącymi stosikami i lukami. Tomy jednej wysokości łączą się w **bloki geometrii** (przód + wierzch jedną wyspą atlasu, boki tylko tam, gdzie widać), a każdy grzbiet jest malowany w atlasie teksel po tekselu: zaokrąglenie grzbietu, zwięzy (wypukłe pasy), złocone linie, szyldzik z „literami”, numer tomu, ornament w polach, płótna z tytułami, welin z odręcznym napisem, płowienie od słońca, przetarcia, złocone obcięcia. Zestawy `_v2` przemalowują te same tomy w inne serie.

## 2. Pola kafelkowe (64 px/m, `ArtLibrary.arch_tile` / `tile:<nazwa>`)

| Tekstura | Kafel | Co to jest | Gdzie |
|---|---|---|---|
| `parquet_chevron` | 2 × 2 m | dąb w jodełkę węgierską: pasy 0,5 m **wzdłuż osi obrazu (= północ, długa oś galerii)**, klepki co 0,125 m pod 45°, ton klepki losowy | posadzki galerii i gabinetów |
| `enl_oak_boards` | 2 × 2 m | polerowane deski ciemnego dębu 12,5 cm w przesuniętym wiązaniu | podłoga kładki (płyta na y = 4), stopnie schodów krętych |
| `enl_mahogany` | 2 × 1 m | mahoń (wstęgowe usłojenie) | ościeża, wnętrza regałów (półki, plecy, boki — modele mapują je w świecie) |
| `enl_bookside` | 2 × 1 m | ciemne okładki widziane z boku w pasach 4 cm | boki bloków książek (w modelach regałów) |

Style pomieszczeń w `ArtKit.ROOMS` (nazwy jak w `src/level/floor1/zones/enlightenment.gd`):

| Styl | Ściana | Posadzka | Strop | Pasy | Ościeżnice |
|---|---|---|---|---|---|
| `enlightenment_library` | `plaster` (nad regałami) | `parquet_chevron` | `plaster` + kasetony `lib_coffer_2m` | `lib_cornice_*` pod stropem | `lib_portal_4x4_5` (4 × 4,5), `lib_doorframe_2x2_8`; `stair`/`slab` = `enl_oak_boards` |
| `enlightenment_cabinet` (= `_portraits`, `_clocks`) | `wallpaper` (zielony adamaszek) | `parquet_chevron` | `plaster` | `gallery_base_*`, `gallery_top_*` (orzechowa boazeria i gzyms galerii holu) | jw. |
| `enlightenment_librarian` | `wallpaper` | `parquet_chevron` | `plaster` | `gallery_base_*` | `lib_doorframe_2x2_8` |
| `enlightenment_planetarium` | `plaster` | `marble_floor` | `star_ceiling` (gwiaździste niebo Egiptu) | `lib_cornice_*` | jw. |

Kroki: `Surface.ROOM_SURFACES` — skrzydło chodzi po parkiecie (`wood`), rotunda po marmurze.

## 3. Zestaw Biblioteki Królewskiej

### 3.1 Regały dwupoziomowe (pasy przyścienne: płaszczyzna ściany z = 0, regał na −Z, x od −W/2 do W/2, początek na podłodze — dolny poziom na posadzce, górny na podłodze kładki y = 4)

| Id | Rozmiar | Trójkąty | Atlas | Opis |
|---|---|---|---|---|
| `lib_bookcase_a_2m`, `_b_2m`, `_c_2m` | 2,0 × 3,6 × 0,56 | 1 934 / 1 814 / 2 038 | ≤1 024×640 | dolny poziom: mahoniowa szafka z mosiężną kratką na zielonym jedwabiu (0–0,92), półka-blat 0,96, **sześć półek** (folio na dole, octavo u góry) ze skórzanymi frędzlami, fryz ze złoconym wałkiem, gzyms 0,56 m; **~330 tomów** w każdym. Zestawy `_v2` (inne serie) |
| `lib_bookcase_1m` | 1,0 × 3,6 × 0,56 | 1 190 | 736×416 | to samo, 1 m (dopasowanie biegu, przy drzwiach) |
| `lib_bookcase_up_a_2m`, `_up_b_2m` | 2,0 × 3,3 × 0,51 | 1 848 / 1 734 | ≤960×512 | górny poziom (na kładce): cokolik, **osiem półek** quarto/octavo |
| `lib_bookcase_up_1m` | 1,0 × 3,3 × 0,51 | 1 118 | 480×480 | jw. 1 m |
| `lib_bookcase_pilaster_low` / `_up` | 0,32 × 3,6 / 3,3 × 0,6 | 484 | ≤448×576 | kanelowany pilaster ze złoconą głowicą: **na każdym styku dwóch regałów i na końcu biegu** (zakrywa boki modułów, które są otwarte — tak oszczędzamy atlas) |

Wnętrza (półki od góry i od dołu, plecy, wewnętrzne boki) i boki bloków książek są polami kafelkowymi (`tile:enl_mahogany`, `tile:enl_bookside`); w atlasie zostają grzbiety, wierzchy książek i lica stolarki. Bok regału bez pilastra jest pusty — **każdy bieg zaczyna i kończy pilaster**.

### 3.2 Kładka (y = 4) i to, co wisi na regałach

| Id | Rozmiar | Trójkąty | Oś / datum | Opis i rozmieszczenie |
|---|---|---|---|---|
| `lib_walkway_fascia_4m/2m/1m` | L × 0,42 × 0,25 | 70 | **górą na krawędzi płyty kładki** (datum = podłoga kładki y = 4), lico na −Z | lico płyty: mahoń, lakierowany zielony fryz ze złotym meandrem, nos gzymsu; belka 0,12 m wchodzi pod płytę. Krawędź płyty ~1,4 m od ściany |
| `lib_walkway_fascia_end` | 0,25 × 0,42 × 0,25 | 114 | jw. | zamknięte końce (przy schodach, przy portalu) |
| `lib_railing_2m`, `_1m` | L × 0,99 × 0,12 | 1 392 / 784 | środek podstawy na osi poręczy, symetryczna | balustrada regencyjna: mahoniowy krawężnik i poręcz na mosiężnej listwie, czarne żeliwne pręty co 0,125 m, w każdym przęśle 0,5 m lira z mosiężną rozetą |
| `lib_railing_post` | 0,2 × 1,15 × 0,2 | 496 | środek podstawy | słupek z mosiężną kulą: końce biegu, co 4 m, głowy schodów |
| `lib_walkway_bracket` | 0,11 × 0,76 × 0,88 | 824 | **górny tylny narożnik** (na licu, do którego jest przykręcony, pod płytą), sięga w −Z | żeliwna konsola z wolutami, mosiężne rozety, żołądź: pod każdym pilastrem (lico pilastra 0,56 m od ściany, góra konsoli na 3,7) |
| `lib_ladder_rail_2m` | 2,0 × 0,09 × 0,13 | 256 | **rama regału dolnego** (początek na podłodze na płaszczyźnie ściany) | mosiężny pręt na wysokości 3,25 m, 0,62 m od ściany, dwa wsporniki |
| `lib_ladder` | 0,57 × 3,23 × 0,95 | 1 024 | na podłodze **pod hakami**: postaw w (x, 0, −0,62) w ramie regału | dębowa drabina z poziomymi stopniami, mosiężne haki na pręt i kółka; stopa 0,85 m dalej (−Z). Przesuwa się po x |
| `lib_bust_bracket` | 0,56 × 0,62 × 0,48 | 458 | na płaszczyźnie ściany, **górą półki** (datum = blat konsoli) | konsola z mahoniu ze złoconym akantem; znacznik **`bust_spot`** (0; 0; −0,24): tam stoi `bust` / `bust_bronze` |

### 3.3 Schody (spadek muzeum: 0,15 × 0,40 m = 20,6°)

| Id | Rozmiar | Trójkąty | Rama | Opis |
|---|---|---|---|---|
| `lib_stair_step_1m` | 1,0 × 0,15 × 0,44 | 32 | `StairsSpec.frame()` jak `stair_step_1m`: stopień i w (0; i·0,15; −i·0,4), skala X do szerokości | dąb, mosiężny nosek, mahoniowy podstopień |
| `lib_stair_stringer_4m` | 0,16 × 1,97 × 4,0 | 44 | jw. (10 stopni na moduł, 0,07 m poza bokiem) | mahoniowa policzka ze złoconym wałkiem |
| `lib_stair_railing_4m` | 0,08 × 2,43 × 4,0 | 340 | jw. | żeliwny pręt na stopień, mosiężny pierścień, mahoniowa poręcz |
| `lib_stair_newel` | 0,26 × 1,44 × 0,26 | 568 | środek podstawy | mahoniowy słupek z mosiężną urną (stopa schodów) |
| **`lib_stair_spiral`** | 3,36 × 5,29 × 3,36 | 3 124 | **oś kolumny na podłodze** | kręte schody żeliwo + dąb, **27 stopni po 0,148 m = 4,0 m**, linia chodu r 1,15 m z biegiem 0,40 m (19,9° na stopień, razem 538°). Pierwszy nosek wzdłuż **+X**, bieg przeciwnie do wskazówek zegara (z góry): wchodzi się w stronę −Z, wychodzi na górny stopień (y 4,0) idąc w +Z. Znaczniki **`stair_bottom`** (1,13; 0,15; −0,2) i **`stair_top`** (−1,13; 4,0; −0,24). Stopnie mapowane w świecie (`tile:enl_oak_boards`), w atlasie tylko żeliwo i noski |

### 3.4 Strop, gzyms, portale, tablice

| Id | Rozmiar | Trójkąty | Oś | Opis |
|---|---|---|---|---|
| `lib_coffer_2m` | 2,2 × 0,23 × 2,2 | 202 | środek płaszczyzny stropu, wisi w dół | gipsowy kaseton 2 × 2: uskok, złocony wałek, pole „kaczego jaja” z malowanym jajownikiem, złocona rozeta. Stawia go `ArtKit.dress_ceiling` w `enlightenment_library` |
| `lib_skylight_well_4m` | 4,64 × 1,47 × 4,64 | 1 600 | środek otworu na płaszczyźnie stropu, studnia w górę | świetlik 4 × 4 m, głęboki 1,3 m: profilowany obrys, płycinowe ościeża, żeliwna krata (4 × 4 szyby), szkło `lib_skylight_well_glass` bez cienia — **tędy wpada księżyc**. Co ~8 m na osi galerii |
| `lib_cornice_4m/2m/1m` | L × 1,2 × 0,67 | 1 152 / 608 / 336 | na suficie na płaszczyźnie ściany (wisi z datum) | architraw, zielony fryz ze złotym meandrem, ząbki, modylony, płyta. Zestaw **`lib_cornice_4m_motto`**: fryz z dewizą Oświecenia **SAPERE AUDE** złotymi literami (po jednym w środku dłuższych ścian) |
| `lib_portal_4x4_5` | 6,1 × 6,62 × 0,34 | 2 268 | środek podłogi otworu na licu ściany (jedna twarz; po jednym na stronę przejścia) | wielki portal skrzydła: mahoniowa opaska, kanelowane pilastry ze złoconymi głowicami, fryz z meandrem, gzyms z ząbkami, przerwany fronton z kartuszem i sferą armilarną. Zestaw **`lib_portal_4x4_5_titled`**: BIBLIOTEKA KRÓLEWSKA na fryzie (wejście z Wielkiego Dziedzińca). Kładka musi kończyć się po obu stronach |
| `lib_doorframe_2x2_8` | 2,48 × 3,45 × 0,14 | 320 | jw. | drzwi gabinetów (mieszczą się pod kładką): opaska, cokoliki, fryz ze złoconymi pateraami, mały fronton |
| `lib_sign` | 1,5 × 0,34 × 0,06 | 152 | na płaszczyźnie ściany w środku | zielona emaliowana tablica, złote litery w mosiężnej ramie. Zestawy: `lib_sign` BIBLIOTEKA KRÓLEWSKA, `_natural` GABINET HISTORII NATURALNEJ, `_collectors` GALERIA KOLEKCJONERÓW, `_clocks` ZEGARY I AUTOMATY, `_orrery` ROTUNDA PLANETARIUM, `_librarian` GABINET BIBLIOTEKARZA |

### 3.5 Lampy z zielonymi kloszami (oprawy: **początek = żarówka**, znacznik `Light` w początku, emisja w mapie `_emit` — przy awarii prądu zgasić emisję jak w holu)

| Id | Rozmiar | Trójkąty | Opis |
|---|---|---|---|
| `lib_lamp_reading` | 0,27 × 0,40 × 0,21 | 426 | lampa bankierska: stopniowana mosiężna stopa 0,31 m pod żarówką, zielony kaptur |
| `lib_lamp_wall` | 0,28 × 0,43 × 0,54 | 592 | kinkiet na pilaster: płytka na płaszczyźnie z = +0,45 od żarówki, łabędzia szyja, zielony stożek ze złotym brzegiem pochylony na półki. Dolny poziom: żarówka 2,6 m nad podłogą, ~1,0 m od ściany; górny: 6,7 m |
| `lib_lamp_pendant` | 0,48 × 1,31 × 0,48 | 810 | wisząca: zielona kopuła, mosiężna galeria, pręt 1 m do rozety (góra 1,25 m nad żarówką); dłużej: `lib_lamp_rod_1m` (44 tr.) pod stropem |
| `lib_lamp_standard` | 0,53 × 1,63 × 0,53 | 890 | stojąca: obciążona stopa 1,45 m pod żarówką, kanelowana kolumna, szeroki dzwon |

Przepis (sprawdzony w scenach złożonych): kinkiety 1,6–2,0× energii kinkietów holu, ciepłe (1,0; 0,72; 0,45), zasięg ~6 m, mgła 0,15; cień tylko co drugi; księżyc przez świetliki jak przez latarnie holu.

### 3.6 Gabloty ze szklanym blatem (192 px/m; mahoniowa witryna 1,8 × 0,8 na toczonych nogach, zielone sukno, szkło jako część `<id>_glass` — gra może ją stłuc; początek w środku podstawy)

| Id | Rozmiar | Trójkąty | Zawartość |
|---|---|---|---|
| `lib_case_shells` | 1,83 × 1,06 × 0,83 | 2 724 | konchy, łodzik, przegrzebki, porcelanki, rozgwiazda, gałązka czerwonego korala, papierowe etykiety |
| `lib_case_minerals` | 1,83 × 0,99 × 0,83 | 2 494 | druza ametystu, kryształy kwarcu, sześciany pirytu, malachit, przecięta geoda na kartonikach |
| `lib_case_coins` | 1,83 × 0,98 × 0,83 | 3 286 | trzy aksamitne tace złotych, srebrnych i miedzianych monet, dwa medale na wstążkach |
| `lib_case_instruments` | 1,83 × 0,98 × 0,83 | 2 078 | sekstant, astrolabium, kompas, mosiężna luneta, cyrkiel, lupa |

## 4. Gabinety (x 48…66)

### 4.1 Historia naturalna i sztucer

| Id | Rozmiar | Trójkąty | Opis, części i znaczniki |
|---|---|---|---|
| `lib_nh_shelf_a` | 2,06 × 2,6 × 0,64 | 4 470 | przeszklona szafa: 20 płytkich szuflad z papierowymi etykietami w mosiężnych ramkach, trzy półki za szprosami: amonity na podstawkach, trylobit, płyta z kopalną rybą, czaszka tura, minerały, słoje z okazami w spirytusie; listwa świetlna pod górą (emisja + znacznik **`Light`** (0; 2,38; 0)); szkło `lib_nh_shelf_a_glass`; napis HISTORIA NATURALNA |
| `lib_nh_shelf_b` | jw. | 4 512 | ta sama szafa: czaszki (tur, małpa, wielki kot), rząd słojów, ptak pod kloszem, amonity, trylobity, płyta z rybą |
| `lib_antlers` | 0,99 × 1,17 × 0,36 | 768 | czaszka jelenia z porożem na dębowej tarczy; początek na płaszczyźnie ściany w środku tarczy; tabliczka CERVUS ELAPHUS |
| `lib_diorama_base` | 3,2 × 0,62 × 1,84 | 1 974 | niski postument dioramy: mahoniowy cokół, falujący grunt (0,33 m, pagórek do 0,45) z mchem, głazy, kłoda, kępy suchej trawy; tabliczka FAUNA EUROPY. Znaczniki **`animal_spot_1`** (0,9; 0,33; 0,2) — **wypchany wilk** — i **`animal_spot_2`** (−0,5; 0,33; −0,1) — **szkielet raptora**; grunt pod nimi płaski |
| **`lib_rifle_rack`** | 1,74 × 2,39 × 0,73 | 1 814 | szafa kolekcjonera na broń: zielone sukno, dwa stare długie karabiny na mosiężnych hakach (góra, dół), **puste mosiężne łoża pośrodku**: znacznik **`weapon_spot`** (0; 1,55; 0,06) — tam leży znajdźka sztucera ekspedycyjnego, lufą w +X; tabliczka **SZTUCER EKSPEDYCYJNY**; lampa nad obrazem wysunięta przed otwór: znacznik **`Light`** (0; 2,14; −0,43) — ciepły reflektor w tył i w dół, na łoża (scena `enl_scene_rifle`) |

### 4.2 Globusy (192 px/m; początek w środku podstawy; okrągłe)

| Id | Rozmiar | Trójkąty | Opis |
|---|---|---|---|
| `lib_globe_terrestrial` | 1,18 × 1,45 × 1,18 | 2 658 | globus 0,84 m na mahoniowym trójnogu: stara mapa akwarelowa na zażółconym papierze (**kontynenty z prawdziwego, uproszczonego obrysu** — `artlib/enl_geo.py`, ~30 wielokątów), inkaustowe wybrzeża z kreskowaniem fal, siatka co 30°, równik i zwrotniki, ekliptyka, kartusz na Pacyfiku, róża wiatrów; mosiężny południk, papierowy horyzont z zodiakiem i kalendarzem, kompas w poprzeczce |
| `lib_globe_celestial` | jw. | 2 658 | ten sam stojak ebonizowany ze złoceniami, kula granatowa ze złotymi gwiazdami: **Orion, Wielki Wóz, Kasjopeja, Łabędź, Skorpion, Lew, Krzyż Południa**, Gwiazda Polarna, Syriusz, Wega, Arktur, Kapella, Aldebaran, Kłos Panny; ekliptyka, równik, słaba poświata jasnych gwiazd |

Część **`globe`** (dziecko stojaka), oś w środku kuli (0; 1,0; 0); oś obrotu pochylona o 23,4° w płaszczyźnie południka: kręcić `globe.rotate(Vector3(0.397, 0.918, 0.0), kąt)`.

### 4.3 Zegary i automaty

| Id | Rozmiar | Trójkąty | Części i rig |
|---|---|---|---|
| `lib_clock_longcase` | 0,58 × 2,59 × 0,33 | 1 196 | zegar szafkowy: łukowa mosiężna tarcza (srebrzony pierścień godzin, złocone narożniki, **faza księżyca** w łuku), okienko na wahadło, trzy mosiężne sterczyny. **`hand_hour`**, **`hand_minute`** (oś w środku tarczy (0; 1,95; −0,145)), **`pendulum`** (zawieszenie (0; 1,82; 0,04), soczewka na 0,95 widoczna w okienku). Szkło `lib_clock_longcase_glass` |
| `lib_clock_wall` | 2,76 × 2,19 × 0,16 | 3 278 | ściana siedmiu zegarów (1,05–3,25 m nad podłogą; rama pasa przyściennego: początek na podłodze na płaszczyźnie ściany): dworcowy, regulator wiedeński, złote słońce, ósemkowy szkolny, okrętowy, rokokowy kartel, banjo — **każdy stanął o innej godzinie**. **`hour_1..7`**, **`minute_1..7`** (osie w środkach tarcz), **`pendulum_1`** (regulator), **`pendulum_2`** (banjo) |
| `lib_automaton_writer` | 0,72 × 1,06 × 0,69 | 3 032 | „Pisarz”: chłopiec-automat w czerwonym aksamicie i pudrowanej peruce przy biureczku, porcelanowa twarz z malowanymi rumieńcami, gęsie pióro nad kartką. **`head`** (oś w szyi (0; 0,86; 0,2): `rotation.y` obrót, `rotation.x` skinienie), **`arm_r`** (prawy bark (0,14; 0,8; 0,2): pisanie małym `rotation.x`/`rotation.z`) |
| `lib_bird_cage` | 0,45 × 1,66 × 0,43 | 1 698 | mosiężna klatka z kopułą na mahoniowym postumencie, kluczyk; mechaniczny rudzik na grzędzie: **`bird`** (oś w stopach (0; 1,21; 0)), **`bird_head`** (dziecko, oś w szyi) — przechylanie przy śpiewie |

Kierunek: wskazówki i wahadła obracają się wokół osi Z Godota (przez tarczę): `rotation.z` rosnące = zgodnie ze wskazówkami zegara, jak widzi strażnik; wahadło ±0,12 rad.

### 4.4 Gabinet bibliotekarza (przystań)

| Id | Rozmiar | Trójkąty | Opis |
|---|---|---|---|
| `lib_office_desk` | 1,7 × 1,06 × 0,79 | 1 652 | biurko partnerskie z mahoniu: zielona skóra ze złoconym tłoczeniem, po trzy szuflady, stos ksiąg rachunkowych, kałamarz z piórem, bibuła, rozsypane karty katalogowe. Znacznik **`terminal_spot`** (0,55; 0,76; 0) na wolnym końcu blatu — tam stoi terminal przystani (komputer z `terminal` bez jego stolika albo inny ekran), front −Z |
| `lib_office_chair` | 0,56 × 0,81 × 0,52 | 780 | dębowe krzesło obrotowe na kółkach, zielone skórzane siedzisko, gięte oparcie na szczeblach |
| `lib_card_catalogue` | 1,24 × 1,46 × 0,71 | 2 388 | szafka katalogu kartkowego: 48 szufladek z ramkami etykiet, jedna wysunięta z kartami; tabliczka KATALOG |
| `lib_filing_cabinet` | 0,52 × 1,38 × 0,69 | 812 | dębowa kartoteka czteroszufladowa, mosiężne uchwyty, taca na papiery |

## 5. Wielkie Planetarium (strażnik, `REGISTRY`, §7.4)

Mosiężne orrery z emalią, **10,2 × 6,8 × 9,5 m**, **12 500 trójkątów** w 17 częściach, atlas 2 208 × 1 184 @ 96 px/m (emisja: rdzeń słońca, EXTRAS 4,0). Początek na podłodze na osi; promieniście symetryczne. Podglądy: `planetarium.png`, `_sun.png`, `_planets.png`, scena `enl_scene_orrery.png`.

| Część / znacznik | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `planetarium` | (0; 0; 0) | — | statyczne: stopniowany bęben r 2,7 (mosiężny fartuch, **złoty zodiak na granatowej emalii**, podium), przekładnia z 9 kół zębatych (pod belką niskiego ramienia), kolumna r 0,28 z kołnierzami, czasza pod słońcem, złoty południk i pochylona **ekliptyka** wokół słońca |
| **`tier_low`** | (0; 0,45; 0) | `planetarium` | piasta z koroną zębatą + dwa ramiona do **r 5,0**; belka (granatowa emalia z gwiazdami, mosiężne pasy) na **0,30–0,55 m nad podłogą: do przeskoczenia** (szczyt skoku 0,83). Na prętach `planet_1` **Merkury** (r 2,4) i `planet_2` **Wenus** (r 4,75, na końcu ramienia), środki ~1,2–1,3 m |
| **`tier_mid`** | (0; 1,6; 0) | `planetarium` | **krótkie** ramiona do **r 3,6**, belka 1,45–1,75 m: nie da się przeskoczyć ani przejść pod nią — trzymać się dalej niż 3,7 m. `planet_3` **Ziemia z Księżycem** na korbie (r 3,3, 2,45 m) i `planet_4` **Mars** (r 3,0, 2,35 m) |
| **`tier_high`** | (0; 2,8; 0) | `planetarium` | ramiona do **r 5,0**, belka 2,65–2,95 m (strażnik 1,8 m mieści się pod nią), na prętach wiszą **księżyce do ~0,95 m** na r 1,2 / 1,9 / 2,6 / 3,3 i 5,0 — **luka między r 3,7 a 4,6 to miejsce do stania**, gdy ramię przechodzi górą. Nad belką `planet_5` **Jowisz** (r 4,5, 3,75 m, Wielka Czerwona Plama) i `planet_6` **Saturn z pierścieniem** (r 4,5, 3,65 m) |
| `planet_1..6` | środki planet | swojego piętra | słabe punkty: ukryć / odczepić i rzucić jako pocisk (toczy się, krąży); Księżyc Ziemi i pierścień Saturna są w swojej planecie |
| `socket_1..6` | = środki planet | swojego piętra | znacznik miejsca na ramieniu (strefa trafienia po odczepieniu, ponowne zaczepienie) |
| `sun_shell_1..6` | zawiasy na dolnej krawędzi łupiny: r 0,95, y 4,45, azymut a_k = 30° + 60°·k | `planetarium` | sześć złoconych łupin słońca z grawerowanymi południkami, pasem emalii z gwiazdami i promieniami. **Otwieranie:** obrót łupiny k o **+1,6 rad** wokół osi stycznej (−sin a_k; 0; −cos a_k) (`rotate(axis, kąt)` albo `quaternion`); w podglądzie sceny 0,75 rad = „pół otwarte” |
| `sun_glow` + **`sun_core`** | (0; 5,0; 0) | `planetarium` | świecący rdzeń (r 0,75, emisja): **słaby punkt po zestrzeleniu 6 planet**; znacznik `sun_core` w jego środku |

Obrót pięter: `tier_*.rotation.y` (w dowolną stronę, różne prędkości); planety jadą z piętrem. W pozie spoczynkowej ramiona są rozstawione co 60° (low 0°, mid 60°, high 120°). Zapowiedzi (≥ 0,6 s): rozpalenie emisji gwiazd na belce przez `own_materials`, przyspieszenie przekładni (dźwięk `orrery_gears`).

**Jak gra prowadzi Planetarium** (`src/game/floor1/guardians/orrery_rig.gd`, plan `docs/superpowers/plans/2026-10-03-straznik-planetarium.md`): piętra obraca napęd z luzem i kołysaniem w łożyskach (`rotation.y` + przechył wokół pierwszego ramienia); **dziesięć wiszących księżyców, Księżyc Ziemi i pierścień Saturna są wycinane w grze** z siatek `tier_high`, `planet_3` i `planet_6` (`MeshShards.partition` po środkach ciężkości trójkątów, wynik w pamięci podręcznej) i dostają osie: księżyc na górze swojego pręta (wahadło), Księżyc w środku Ziemi (krąży), pierścień w środku Saturna (chwieje się, po zestrzeleniu toczy się osobno). Na końcach ramion gra dokłada lampki sygnałowe (bursztyn / czerwień / lodowy błękit), w sercu słońca światło. Szczeliny między elementami w modelu są potrzebne grze: luka r 3,85–4,45 pod wysokim ramieniem i belka niskiego pod szczytem skoku są sprawdzane testami z kapsułą strażnika.

## 6. Latające księgi (wróg, `REGISTRY`)

Quarto **0,33 m** (0,44 × 0,33 × 0,19 w pozie), **472 trójkąty**, 256 px/m, emisja oczu (EXTRAS 2,2), obwódka eksponatu 0,5. Leci otwarta jak paszcza: grzbiet z tyłu, okładki-skrzydła na boki i do przodu, w gardle trzepoczą kartki, z rozkładówki patrzą **dwoje iluminowanych oczu z pionową źrenicą**.

| Część / znacznik | Oś (Godot) | Do czego |
|---|---|---|
| `body` | (0; 0; 0) | grzbiet: zaokrąglona skóra, zwięzy, szyldzik, kapitałki |
| `cover_l` / `cover_r` | (∓0,026; 0; 0,02) — zawiasy, oś = Y Godota | okładka + połowa bloku kartek. Spoczynek: każda 55° od zamknięcia. `cover_l.rotation.y` > 0 i `cover_r.rotation.y` < 0 otwierają szerzej; ∓0,96 rad od spoczynku = książka zamknięta. **Trzepot**: ±0,3 rad z częstotliwością lotu; **zapowiedź nurkowania**: rozłożenie prawie na płasko (~±0,6) przez 0,6 s z szelestem |
| `pages` | (0; 0; 0,02) | cztery luźne kartki w wachlarzu: drżenie `rotation.y` / `scale.z` |
| `eye_l`, `eye_r` | (∓0,116; 0,035; −0,069) | znaczniki na oczach (dzieci okładek): celowanie, efekty; tęczówki świecą z mapy emisji, przy przebudzeniu/ataku rozjaśnić przez `own_materials` |

Zestawy tekstur na tej samej siatce (`ENLIGHTENMENT_SETS`): `flying_book` (czerwony maroken), `flying_book_green`, `flying_book_blue`, `flying_book_black` (np. `ArtLibrary.exhibit(&"flying_book", {"flying_book": "flying_book_blue"})`); rozmiary przez skalę węzła 0,8–1,3 (folio, octavo). **Odłamki:** `flying_book_page` (0,21 × 0,31, 60 tr., dwustronna, zadrukowana kartka) — „papierowe gore”, kilka–kilkanaście na zestrzeloną księgę.

## 7. Jak złożyć przęsło Biblioteki (tak buduje je `tools/art/scene_enlight.py`)

- **Rytm:** moduł 2 m + pilaster 0,22 m = **2,22 m**. Na ścianie: pilaster, regał, pilaster…; dolny poziom na y = 0, górny (`_up`) na y = 4 nad dolnym; różne warianty `a/b/c` i `_v2` na zmianę (na przeciwległych ścianach przesunięte), przy drzwiach `_1m`.
- **Kładka:** płyta (greybox, pole `slab` = `enl_oak_boards`) 0,3 m (3,7–4,0) i ~1,4 m od ściany; na krawędzi `lib_walkway_fascia_*`, za nią `lib_railing_*` (0,1 m dalej od ściany), `lib_railing_post` co 4 m; pod płytą `lib_walkway_bracket` przy każdym pilastrze (góra 3,7, tył na licu pilastra 0,56 m od ściany).
- **Drabiny:** `lib_ladder_rail_2m` w ramie dolnego regału, `lib_ladder` w (x; 0; −0,62) — jedna–dwie na ścianę.
- **Strop 10 m:** `lib_coffer_2m` na siatce 2 m (`ArtKit.dress_ceiling`), `lib_skylight_well_4m` co ~8 m na osi (przerwa w siatce kasetonów), `lib_cornice_*` pod stropem (styl pokoju), w środku dłuższych ścian `lib_cornice_4m_motto`.
- **Oś galerii:** gabloty `lib_case_*` co ~3,4 m, przy nich `lib_lamp_standard` albo `lib_lamp_reading` na stolikach; globusy przy wejściach do gabinetów; `lib_bust_bracket` z popiersiami na pilastrach górnego poziomu.
- **Schody:** `lib_stair_spiral` na końcach galerii (górny stopień = podłoga kładki), albo bieg prosty z `lib_stair_*` wzdłuż ściany (27 stopni, 10,8 m).
- **Portal z Dziedzińca:** `lib_portal_4x4_5` z zestawem `_titled`; kładka kończy się przed nim `lib_walkway_fascia_end`.
- **Budżet:** jedno przęsło jednej ściany (2 regały + 2 pilastry + konsola + lico + balustrada + 1/2 gzymsu + kinkiety) ≈ 8 tys. trójkątów; galeria 36 m = ~16 przęseł × 2 ściany ≈ 0,26 mln. Drobne meble i lampy: `visibility_range_end` ~40 m jak w holu.

## 8. Podglądy (Cycles, `tests/_out/art/`)

- Sceny: `enl_scene_gallery.png` (oś galerii), `enl_scene_shelves.png`, `enl_scene_walkway.png`, `enl_scene_ceiling.png`, **`enl_scene_orrery.png`** (rotunda: pół otwarte słońce, stado ksiąg), `enl_scene_orrery_close.png`, **`enl_scene_cabinet.png`** (diorama z wilkiem i raptorem, szafy, lampy), **`enl_scene_rifle.png`** (puste łoża sztucera w plamie światła), `enl_scene_clocks.png`.
- Modele: `lib_bookcase_a_2m.png` + `_shelf.png` (grzbiety z bliska), `lib_bookcase_up_a_2m.png`, `lib_railing_2m.png`, `lib_walkway_bracket.png`, `lib_ladder.png`, `lib_stair_spiral.png`, `lib_coffer_2m.png`, `lib_skylight_well_4m.png`, `lib_cornice_4m.png`, `lib_portal_4x4_5.png` + `_crown`, `lib_lamp_reading.png`, `lib_lamp_standard.png`, `lib_case_*.png` + `_top`, `lib_nh_shelf_a.png` + `_shelves`, `lib_antlers.png`, `lib_diorama_base.png`, `lib_rifle_rack.png` + `_guns`, `lib_globe_terrestrial.png` + `_globe`, `lib_globe_celestial.png` + `_globe`, `lib_clock_longcase.png` + `_dial`, `lib_clock_wall.png` + `_dials`, `lib_automaton_writer.png` + `_face`, `lib_bird_cage.png` + `_bird`, `lib_office_desk.png`, `lib_card_catalogue.png`, `planetarium.png` + `_sun`, `_planets`, `flying_book.png` + `_eyes`, `flying_book_page.png`.

## 9. Uczciwie: słabe punkty

- **Pamięć tekstur.** Regały mają po ~0,5–0,7 mln tekseli atlasu (144 px/m, grzbiety są malowane, nie powtarzane); z zestawami `_v2` to ok. 12 zestawów map. Planetarium ma atlas 2,6 mln tekseli. Jeśli zrobi się ciasno: normalne i ORM regałów na BC, albedo zostaje bezstratne.
- **Boki modułów regałów są otwarte** (oszczędność atlasu) — bez pilastra na końcu biegu widać wnętrze.
- **Twarde ostrza zamiast rzeźby:** głowy automatu i czaszki to proste bryły i metaballe; z 1 m to lalka, nie rzeźba (dla automatu: zamierzenie).
- **Planety jako kule:** niski poli przy 96 px/m; z bliska widać fasety. Księżyce na wysokim ramieniu są szare i proste.
- **Napisy:** 5 × 7 pikseli — na małych tarczach zegarów zamiast cyfr są pałeczki godzinowe; tylko zegar dworcowy ma cyfry.
- **Mapa świata** jest ręcznie obrysowana z dokładnością kilku stopni (dekoracja, nie atlas).
- **Galeria portretów kolekcjonerów** korzysta z istniejących `portrait` i ram holu — nowych płócien nie malowałem.
- Sceny złożone to podglądy Blendera, nie zrzuty z gry; integracja w poziomie (rozmieszczenie, światła, kolizje kręconych schodów i Planetarium) należy do integratora.
