# Zestaw Piętra I: Wielki Dziedziniec, Czytelnia, hol wejściowy

Katalog modeli z gałęzi `art-court` (plan: `docs/superpowers/plans/2026-10-02-art-dziedziniec.md`, projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.7, §10). Wszystko powstaje skryptami Blendera w trybie tła (`tools/art/models/court_*.py`, `entrance_kit.py`, `totem_haida.py`), rejestr w `ArtLibrary.KIT` + `ArtLibrary.KIT_COURT` (rozmiar natywny i budżet trójkątów), style pomieszczeń w `ArtKit.ROOMS` (`court`, `reading_room`, `entrance`). Test: `tests/integration/test_art_court.gd`.

## Konwencje

- Osie Godota: x = wschód, y = góra, **−z = północ**; środek dziedzińca = (0, 0, 0) = środek bębna Czytelni.
- **Elementy bębna** (`rr_*`, `court_balcony_seg*`): początek **w środku bębna na podłodze**, zbudowane wokół osi północnej (patrzą na −Z, segment k = 0 to ściana północna). Stawia się je bez skalowania: `Transform3D(Basis(Vector3.UP, deg_to_rad(22.5 * k)), środek_bębna)`. k rośnie przeciwnie do wskazówek zegara patrząc z góry: k = 0 północ, 4 zachód, 8 południe, 12 wschód.
- **Ćwiartka dachu** `court_roof_q`: początek w środku dziedzińca, pokrywa trójkąt między przekątnymi wokół północy; cztery kopie z `rotation.y` = 0°, 90°, 180°, 270°.
- Pozostałe: konwencja zestawu holu (początek = środek podstawy, przód = −Z). `ArtKit.piece(id, rozmiar, pokój)` przyjmuje też **identyfikator modelu jako id elementu** i skaluje model do rozmiaru (rozmiar / `KIT_COURT[id][0]`); elementów bębna nie skalować.
- Szkło jest osobną częścią z materiałem `glass` (bez cienia): kratownica dachu rzuca cień siatki, szyby przepuszczają księżyc.
- Materiały w plikach .glb: nazwa modelu (atlas), `glass`, `rr_books` (wspólna tekstura grzbietów), `tile:<tekstura>` (pole mapowane w świecie, 64 px/m).
- Emisja (`ArtLibrary.EXTRAS`): `rr_drum_door` 3,0 (latarnie), `rr_drum_wall` 2,0 (kilka okien świeci od środka), `rr_dome_sector` 1,2 (lunety w księżycu), `rr_desk` 3,5 (zielone lampy), `court_info_desk` 2,0 (szyld), `court_lamp_post` 4,0 (klosze).

## Liczby

| Co | Wartość |
|---|---|
| Bęben | 16-kąt; lico zewnętrzne w odległości 12,26 m (wierzchołki 12,5), lico wewnętrzne 11,2; ściana 1,06 m |
| Bęben z zewnątrz | cokół 0–0,9 · boniowanie do 6,3 · gzyms balkonu 6,3–6,95 · pilastry i okna 7–15 · belkowanie 15–16,6 · attyka 16,6–20,9 · wieniec 20,9–21,65 (wystaje do r ≈ 13,3) |
| Portale | 4 (k = 0, 4, 8, 12), otwór 3,0 × 4,5 m przez całą ścianę; skrzydła `door_grand_leaf_l/_r` przeskalowane do 1,5 × 4,5 |
| Czytelnia | regały 0–4,55 i 5,12–9,4 · galeria (kładka) 4,8–5,0, 1 m głęb. · gzyms 9,8–10,8 · lunety 10,8–13,2 · kopuła 13,2 → 19,87 (okno w szczycie r 1,8) · studnia światła do 23,6 · latarnia do 26,85 |
| Dach | szkło na y = 19,0 przy murach (|x|, |z| = 30) → 22,4 na pierścieniu bębna (r = 13,0); dolna krawędź dźwigara obrzeża y = 17,85 |
| Balkon | płyta 6,6–7,0, chodnik y = 7,0, od lica bębna (12,26) do 16,5 m; balustrada 1,05 m |
| Schody na balkon | 47 stopni 0,1489 × 0,40 m (20,4°), szerokość 3 m, bieg 18,8 m |

## Jak postawić bęben i dach

```gdscript
const CENTRE := Vector3.ZERO                      # środek dziedzińca = środek bębna
for k in 16:
    var basis := Basis(Vector3.UP, deg_to_rad(22.5 * k))
    var door := k % 4 == 0
    _place(ArtKit.model("rr_drum_door" if door else "rr_drum_wall"), Transform3D(basis, CENTRE))
    _place(ArtKit.model("rr_bookcase_door" if door else "rr_bookcase"), Transform3D(basis, CENTRE))
    _place(ArtKit.model("rr_dome_sector"), Transform3D(basis, CENTRE))
_place(ArtKit.model("rr_oculus"), Transform3D(Basis.IDENTITY, CENTRE))
_place(ArtKit.model("rr_dome_outer"), Transform3D(Basis.IDENTITY, CENTRE))
for k in 4:
    _place(ArtKit.model("court_roof_q"), Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 * k)), Vector3.ZERO))
for k in 4:                                        # pierścień katalogu, przejścia od drzwi zostają wolne
    _place(ArtKit.model("rr_catalogue_arc"), Transform3D(Basis(Vector3.UP, deg_to_rad(45.0 + 90.0 * k)), CENTRE))
```

**Kolizje bębna** (w ramie segmentu, przed obrotem; segment patrzy na −Z):

| Segment | Pudła (środek; rozmiar) |
|---|---|
| ściana `rr_drum_wall` | (0; 10,825; −11,73); (4,88; 21,65; 1,06) — szerokość lica, nakładki w głębi muru są bezpieczne |
| portal `rr_drum_door` | dwa węgary (±1,97; 10,825; −11,73); (0,94; 21,65; 1,06) + nadproże (0; 13,075; −11,73); (3,0; 17,15; 1,06) |
| regał (opcjonalnie, gdy galeria ma być dostępna) | regały (0; 4,9; −10,925); (4,46; 9,8; 0,55); kładka (0; 4,9; −10,15); (4,46; 0,2; 1,0); balustrada (0; 5,5; −9,62); (4,46; 1,2; 0,06) |
| balkon `court_balcony_seg` | płyta: wielokąt w ramie segmentu z = −12,26 … −16,5, y 6,6–7,0 (pudło (0; 6,8; −14,38); (5,8; 0,4; 4,24) + boki trapezu); balustrada przy z = −16,4 |

Czytelnia: pole podłogi `reading_room` = granatowy dywan `carpet_reading`. Snop księżyca przez okno w szczycie (przepis: kierunek (−0,28; −0,9; −0,33)) pada ok. 9–10 m od środka; żeby trafił w astrolabium, warto dodać światło punktowe/reflektor w latarni `rr_oculus` skierowane na `Core`.

## Proponowany układ dziedzińca (tak stoi w podglądzie `tools/art/court_preview.py`)

| Co | Model | Pozycja (x, y, z) | Obrót y |
|---|---|---|---|
| balkon, 9 segmentów | `court_balcony_seg` (k = −3…3), `court_balcony_seg_open` (k = ±4: tam lądują schody) | środek bębna | 22,5° · k |
| biegi schodów | `court_stair_step` × 47 (krok (0; 0,1489; −0,4)), `court_stair_parapet_4m` × 5 na stronę (x ± 1,66; krok (0; 1,4894; −4)), `court_stair_mass` skala (3; 7; 18,8) | stopa biegu (±18,1; 0; 19,4), bieg wznosi się na północ | 0° |
| podest przy otwartym boku balkonu | bryła 3,1 × 7,0 × 3,9 z polem `tile:limestone_court` + `court_parapet_2m` dookoła | środek (±18,1; 7; −1,34) | — |
| T-Rex | `trex_pedestal` (istniejący) + `trex` na y = 1,2 | (0; 0; −22) | −90° (T-Rex) |
| totem | `totem_haida` | (22; 0; −22) — narożnik NE | −135° |
| kawiarnia | `cafe_counter`, 5 × `cafe_table` + 3 × `cafe_chair` przy każdym | (−24; 0; −27), stoliki wokół (−21; 0; −21) | 0° |
| sklep | `shop_front` na ścianie południowej | (24; 0; 29,6) | 180° |
| informacja | `court_info_desk` | (0; 0; 21) | 0° |
| ławki | `court_bench` | wzdłuż osi wschód–zachód, np. (±21; 0; 20) | 0° / 90° |
| latarnie | `court_lamp_post` | (±16; 0; ±16) | 0° |
| drogowskazy | `sign_wing` (zestaw skrzydła) przy wejściu do skrzydła, `sign_wing_portal` nad przejściem | — | przodem do nadchodzącego |
| plan muzeum | `court_map_board` | przy wejściu z holu, np. (5; 0; 25) | 0° |
| wystawa „Wiek pary i stali” (Czytelnia) | `steam_engine`, `steam_banner`, `steam_podium` + `knight`/`armor_stand`, `gatling_display` (istniejący) | ćwiartka SW i SE między biurkami | — |
| biurka | `rr_desk` × 8 na liniach nieparzystych k (22,5° · k), r = 6,5 | (−sin a · 6,5; 0; −cos a · 6,5) | a |
| astrolabium | `astrolabe` | środek bębna | 0° |

## Katalog modeli

Rozmiar = AABB modelu w metrach (osie Godota). Trójkąty z pliku .glb.

### Dach i bęben

| Id | Rozmiar (x, y, z) | Trójkąty | Atlas | Części / znaczniki | Uwagi | Podgląd |
|---|---|---|---|---|---|---|
| `court_roof_q` | 60,07 × 4,57 × 21,34 | 9 996 | — (`tile:court_steel`) | `court_roof_q` (stal, cień), `court_roof_q_glass` (szyby dwustronne) | 24 × 11 oczek, przekątne w jodełkę symetryczną wzgl. osi | `court_roof_q.png`, złożenie: `court_entrance.png`, `court_roof.png` |
| `rr_drum_wall` | 5,29 × 21,65 × 2,11 | 1 708 | 1216 × 800 @ 64 | — | lico wewn. `tile:plaster` | `rr_drum_wall.png`, `_top.png` |
| `rr_drum_door` | 5,29 × 21,65 × 2,11 | 2 906 | 1312 × 1024 @ 64 | `Light_L` (2,165; 3,4; −12,76), `Light_R` (−2,165; 3,4; −12,76) | portal z frontonem, złota tablica CZYTELNIA, latarnie z brązu | `rr_drum_door_portal.png` |

### Czytelnia

| Id | Rozmiar | Trójkąty | Atlas | Części / znaczniki | Uwagi | Podgląd |
|---|---|---|---|---|---|---|
| `rr_bookcase` | 4,46 × 9,80 × 1,56 | 1 758 | 1152 × 864 @ 96 + `rr_books` | — | grzbiety ze wspólnej tekstury `rr_books` (16 półek × 4 m, 128 px/m); balustrada `tile:cast_iron`, kładka `tile:parquet` | `rr_bookcase.png`, `_books.png`, `_gallery.png` |
| `rr_bookcase_door` | 4,46 × 9,80 × 1,65 | 1 900 | 864 × 1216 @ 96 | — | otwór 3 × 4,5, zegar zatrzymany na 3:00 | `rr_bookcase_door_door.png` |
| `rr_dome_sector` | 4,46 × 10,07 × 9,44 | 2 016 | 1152 × 864 @ 64 | `Light_Dome` (0; 10,85; −10,58) | gzyms, luneta, 2 × 6 kasetonów, gwiaździsty pas | `rr_dome_sector_coffers.png`, złożenie `court_rr_dome.png` |
| `rr_oculus` | 6,70 × 7,14 × 6,70 | 1 784 | 1088 × 768 @ 64 | `rr_oculus`, `rr_oculus_glass` | złoty pierścień, rozchylona studnia, przeszklona latarnia | `rr_oculus.png` |
| `rr_dome_outer` | 23,40 × 2,05 × 23,40 | 3 008 | 1216 × 736 @ 32 | — | ołowiana kopuła z żebrami (widok z dachu i przez szkło) | `rr_dome_outer.png` |
| `rr_desk` | 2,70 × 1,67 × 4,00 | 2 736 | 1408 × 896 @ 112 | `Light_1..3` (0; 1,56; 1,3 / 0 / −1,3) | dwustronne biurko, 3 zielone lampy, 6 krzeseł | `rr_desk.png`, `_lamp.png`, `court_rr_desks.png` |
| `rr_catalogue_arc` | 4,31 × 1,20 × 1,59 | 528 | 768 × 576 @ 128 | — | 70° pierścienia r 2,7–3,7; 4 kopie co 90° (od 45°) | `rr_catalogue_arc.png` |
| `astrolabe` | 4,40 × 3,61 × 4,40 | 6 258 | 1248 × 736 @ 160 | części `astrolabe`, `ring_outer`, `ring_middle`, `ring_inner` (osie w (0; 2,35; 0)); znaczniki `Shard_1..6` (r 1,5, y 2,57, co 60° od północy przeciwnie do zegara), `Core` (0; 2,35; 0) | stopnie `tile:marble_dark` | `astrolabe.png`, `_rings.png` |
| `steam_banner` | 2,78 × 3,13 × 0,60 | 372 | 480 × 832 @ 128 | — | „WIEK PARY I STALI / wystawa czasowa”, dwustronny | `steam_banner.png` |
| `steam_podium` | 1,64 × 0,32 × 1,64 | 996 | 448 × 640 @ 128 | — | nitowany podest pod zbroję | `steam_podium.png` |
| `steam_engine` | 1,37 × 2,07 × 3,72 | 1 666 | 800 × 1056 @ 128 | `flywheel` (oś (−0,62; 1,15; −1,0), obrót wokół X), `governor` (oś Y) | maszyna parowa: koło zamachowe, regulator kulowy | `steam_engine.png` |

Kartaczownica w gablocie z łańcuchem = istniejący `gatling_display`; zbroje = `knight` / `armor_stand`; słupki z liną = `stanchion`.

### Wyposażenie dziedzińca

| Id | Rozmiar | Trójkąty | Atlas | Części / znaczniki | Uwagi | Podgląd |
|---|---|---|---|---|---|---|
| `court_bench` | 3,00 × 0,47 × 0,56 | 552 | 416 × 736 @ 128 | — | dębowe listwy na kamiennych postumentach | `court_bench.png` |
| `court_info_desk` | 4,15 × 3,34 × 4,08 | 1 054 | 1248 × 864 @ 128 | `Light` (0; 2,95; 0) | okrągła lada, przerwa z tyłu (+Z), świecący szyld INFORMACJA | `court_info_desk.png`, `_sign.png` |
| `cafe_counter` | 4,06 × 2,90 × 2,28 | 2 468 | 1120 × 928 @ 96 | `cafe_counter`, `cafe_counter_glass` | KAWIARNIA, menu kredą („ZAMKNIĘTE DO 9:00”), ekspres, ciasta | `cafe_counter.png`, `_bar.png` |
| `cafe_table` | 0,74 × 0,75 × 0,74 | 312 | 384 × 256 @ 160 | — | marmurowy blat, żeliwna stopa | — |
| `cafe_chair` | 0,44 × 0,93 × 0,44 | 486 | 256 × 224 @ 160 | — | krzesło gięte | `cafe_chair.png` |
| `shop_front` | 8,20 × 4,66 × 0,40 | 690 | 1088 × 992 @ 96 | `shop_front`, `grille` (oś na wałku (0; 3,65; −0,18): podnieść lub ścisnąć w Y) | SKLEP MUZEALNY, roleta z tabliczką ZAMKNIĘTE; płaszczyzna ściany z = 0 | `shop_front.png`, `_sign.png` |
| `court_plinth` | 1,24 × 1,00 × 1,24 | 220 | 672 × 480 @ 128 | — | cokół ekspozycyjny z mosiężną tabliczką | — |
| `court_lamp_post` | 1,58 × 4,62 × 0,68 | 1 068 | 544 × 480 @ 160 | `Light` (0; 4,28; 0), `Light_L` (0,62; 3,74; 0), `Light_R` (−0,62; 3,74; 0) | żeliwna latarnia z trzema kloszami | `court_lamp_post.png` |
| `totem_haida` | 5,44 × 12,57 × 2,50 | 4 110 | 2272 × 1152 @ 128 | — | Niedźwiedź, Orka, Kruk, Strażnik z pierścieniami, Ptak Gromu; stylizacja, nie kopia konkretnego słupa | `totem_haida.png`, `_bear.png`, `_middle.png`, `_top.png` |
| `sign_wing` | 1,33 × 2,70 × 0,40 | 372 | 480 × 352 @ 128 | — | dwustronny słupek; zestawy: `sign_wing` (EGIPT), `_asyria`, `_greece`, `_enlight`, `_asia`, `_americas` | `sign_wing.png`, `sign_wing_sets.png` |
| `sign_wing_portal` | 3,20 × 0,60 × 0,06 | 52 | 448 × 224 @ 128 | — | tablica nad przejściem, płaszczyzna ściany z = 0, początek w środku dolnej krawędzi; te same 6 zestawów (`sign_wing_portal_*`) | `sign_wing_portal_sets.png` |
| `court_map_board` | 1,72 × 2,20 × 0,72 | 440 | 800 × 1152 @ 256 | — | PLAN MUZEUM – PIĘTRO I, strefy w kolorach skrzydeł, TU JESTEŚ | `court_map_board_plan.png` |

Kolory skrzydeł: Egipt piasek, Asyria łupkowy błękit, Grecja błękit z bielą, Oświecenie zieleń z mosiądzem, Azja czerwony lak ze złotem, Ameryki i Oceania turkus.

### Balkon i schody

| Id | Rozmiar | Trójkąty | Atlas | Rama | Uwagi | Podgląd |
|---|---|---|---|---|---|---|
| `court_balcony_seg` | 6,64 × 1,96 × 4,42 | 492 | 448 × 576 @ 64 | bęben (k = −4…4) | chodnik `tile:limestone_court`, płycinowy sufit, fryz, pełna balustrada z mosiężnym pochwytem | `court_balcony_seg.png`, złożenie `court_high.png` |
| `court_balcony_seg_open` | 6,64 × 0,86 × 4,42 | 424 | 448 × 416 @ 64 | bęben | bez balustrady (tu ląduje bieg) | — |
| `court_parapet_2m` / `_1m` | 2,00 / 1,00 × 1,10 × 0,53 | 110 / 110 | ≤ 224 × 192 @ 64 | środek podstawy na chodniku, wzdłuż X | końce balkonu, podesty | `court_parapet_2m.png` |
| `court_stair_step` | 3,00 × 0,15 × 0,43 | 22 | 224 × 64 @ 64 | `StairsSpec.frame()` | stopień z wapienia; skala X do innej szerokości | `court_stair_step.png` |
| `court_stair_parapet_4m` | 0,53 × 3,04 × 4,02 | 108 | 320 × 288 @ 64 | j.w., środek 0,16 m poza bokiem biegu | pełna pochyła balustrada, pochwyty po obu stronach | `court_stair_parapet_4m.png`, złożenie `court_corner.png` |
| `court_stair_mass` | 1 × 1 × 1 | 6 | — (`tile:portland_ashlar`) | j.w. | klin pod stopniami, skalować do (szer., wysokość, bieg) | — |

### Hol wejściowy

| Id | Rozmiar | Trójkąty | Atlas | Rama | Uwagi | Podgląd |
|---|---|---|---|---|---|---|
| `entrance_column` | 1,72 × 12,00 × 1,72 | 2 016 | 928 × 480 @ 64 | środek podstawy | grecka dorycka; `ArtKit.piece(&"column", …, &"entrance")` wybiera ją sama | `entrance_column.png`, `_capital.png` |
| `entrance_coffer_3m` | 3,00 × 0,48 × 3,00 | 226 | 256 × 320 @ 64 | środek modułu na płaszczyźnie stropu, wisi w dół | meander, niebieskie pole, złota rozeta; `ArtKit.dress_ceiling(&"entrance", …)` kładzie je co 3 m (`coffer_size`) | `entrance_coffer_3m.png` |
| `entrance_door_l` / `_r` | 2,20 × 5,00 × 0,37 | 2 916 / 2 916 | 1248 × 768 @ 96 | rama liścia `Door` | brąz, 6 płycin, ćwieki, kołatka z głową lwa; _l zawias na −X | `entrance_door_l.png` |
| `entrance_door_sign` | 0,82 × 0,42 × 0,02 | 56 | 448 × 256 @ 256 | tył na płaszczyźnie liścia, patrzy na −Z | „WYJŚCIE / OTWARTE OD 6:00” | — |
| `cloakroom_counter` | 6,03 × 2,65 × 3,94 | 2 620 | 960 × 1344 @ 96 | środek podstawy, przód −Z | SZATNIA, numerki, wieszaki, zostawione płaszcze, stojak z parasolami | `cloakroom_counter.png` |
| `entrance_mosaic` | 8,00 × 0,004 × 6,00 | 2 | 800 × 608 @ 96 | środek na podłodze | meander, warkocz, medalion „MVSEVM / MDCCLIII” (rok założenia BM) | `entrance_mosaic.png` |

Kasa z szufladą = istniejący `ticket_booth` (część `drawer`, znacznik `Light`); wielkie schody holu na podest y = 6 = istniejące moduły `stair_step_4m`, `stair_stringer_4m`, `stair_balustrade_4m`, `stair_newel` przez `ArtKit.stairs` (40 stopni 0,15 × 0,40); balustrada podestu = `balustrade_2m` + `balustrade_pedestal`.

### Krata korytarza północnego

| Id | Rozmiar | Trójkąty | Atlas | Rama | Uwagi | Podgląd |
|---|---|---|---|---|---|---|
| `grate_leaf_4m` | 4,00 × 5,00 × 0,17 | 3 432 | 1376 × 832 @ 128 | rama liścia `Door`; dwa liście na x = ±2 | 22 pręty, środki x = −1,89 + 0,18 k (osobne kolizje prętów: pociski przechodzą w 0,13 m szczelinach), łańcuch z kłódką | `grate_leaf_4m.png` |
| `grate_frame_8m` | 8,80 × 5,55 × 0,52 | 3 396 | 672 × 608 @ 64 | środek podłogi otworu na licu ściany | prowadnice, dźwigar z bębnami, tablica „ZEJŚCIE DO PODZIEMI / WSTĘP WZBRONIONY” | `grate_frame_8m.png` |

`Door` i `LevelKit` znają dziś kratę 6 m (`grate_leaf_3m`, 16 prętów); dla otworu 8 m trzeba w kodzie poziomu dać `grate_leaf_4m` i 22 kolizje prętów na liść.

## Tekstury kafelkowe (64 px/m)

| Tekstura | Kafel | Gdzie |
|---|---|---|
| `limestone_court` | 6 × 6 m | posadzka dziedzińca i balkonu: płyty jasnego wapienia 1 / 1,5 / 2 m w pasach 1 m, włoskowate fugi, muszelki, przetarcia polerki |
| `portland_ashlar` | 4,5 × 3 m | mury dziedzińca: kamień portlandzki, warstwy 0,75 m; masa schodów |
| `court_steel` | 2 × 2 m | stal kratownicy dachu (jasnoszara farba, nieliczne ogniska rdzy) |
| `carpet_reading` | 2 × 2 m | dywan Czytelni: granat ze złotą kratą i kwiatkami |
| `cast_iron` | 2 × 2 m | cienkie żeliwo mapowane w świecie (balustrady galerii) |
| `rr_books` (nie kafel, wspólna tekstura) | 4 × 5,44 m @ 128 | grzbiety książek wszystkich regałów |

Style pomieszczeń: `court` (ściany `portland_ashlar`, posadzka `limestone_court`, pasy holu: cokół, gzyms na 7 m, belkowanie pod stropem), `reading_room` (dywan, tynk), `entrance` (jak hol: boniowanie do 6 m, ciosy wyżej, `marble_hall`, kasetony 3 m).

## Podglądy

Pojedyncze modele: `tests/_out/art/<id>.png` (Cycles, 4 ujęcia) i ujęcia dodatkowe `<id>_<nazwa>.png`. Złożony dziedziniec w świetle księżyca z mgłą (Cycles, bez okna):

```
"D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup --python tools/art/court_preview.py -- entrance roof corner high rr_wide rr_dome rr_desks --samples=64
```

→ `tests/_out/art/court_<ujęcie>.png`. Najlepsze: `court_corner.png` (schody i cień kratownicy), `court_entrance.png` (bęben z portalem), `court_roof.png` (dach od spodu), `court_rr_dome.png` i `court_rr_wide.png` (kopuła Czytelni), `court_rr_desks.png` (zielone lampy, astrolabium).

Budowa: `bash tools/art/build_art.sh court_roof court_drum court_reading_room court_rr_props court_props totem_haida court_signs court_stairs entrance_kit court_grate` (tekstury: `TEXTURES=1` albo `build_textures.py limestone_court portland_ashlar court_steel carpet_reading cast_iron`). Gdzie idzie atlas modelu: `blender -b --python tools/art/atlas_report.py -- <moduł> [model]`.

## Uczciwie: słabe punkty

- Snop księżyca przez okno Czytelni nie trafia w astrolabium przy obecnym kierunku księżyca; potrzebne własne światło w latarni.
- Totem jest czytelny z daleka (sylwetka, skrzydła, oczy), z bliska formline jest uproszczony i malowany, a nie rzeźbiony.
- Lunety kopuły są „ślepe” (ciemne szkło z lekkim blaskiem), za nimi nie ma przestrzeni.
- Regały wszystkich 16 segmentów mają ten sam układ półek (książki wybierają różne odcinki wspólnej tekstury, więc powtórzenie jest słabo widoczne).
- Proponowany układ schodów (proste biegi przy zachodnim i wschodnim boku bębna) to propozycja: kit jest modułowy, łukowych biegów wokół bębna nie ma, bo kolidowałyby z portalami.
