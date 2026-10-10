# P2 — oprawa wzorcowa: Wielki Dziedziniec, Czytelnia, hol, kanciapa, korytarz północny i Egipt

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (zadania po kolei, commit po każdym). Kroki mają pola `- [x]`.

**Cel:** greybox centrum (strefy `court`, `entrance`, `booth`, `north_hall`) i skrzydła `egypt` Piętra I dostaje gotową grafikę, światło i atmosferę — wzorzec jakości (etap P2, projekt §13), pierwsze wrażenie właściciela: księżyc przez trójkątną kratownicę szklanego dachu i cienie siatki w mgle, bęben Czytelni z kopułą, Egipt w zimnych snopach przez kamienne kraty i w ciepłych reflektorach na kolosach. Wszystko w budżecie: ≥ 90 kl./s 1080p High na RTX 2080 Ti w najcięższym widoku (§11.3).

**Architektura:** kolizje i nawigacja zostają z greyboksa; wygląd podmienia `LevelArt`/`ArtKit` (pola kafelkowe ścian, pasy, stropy, modele elementów), a to, czego greybox nie ma (dach, bęben, kopuła, belki, kraty, obóz, reflektory), stawia nowy moduł **`Floor1Art`** (czysta logika rozmieszczania, drzewa `Node3D` z modeli `ArtLibrary`, bez kolizji, tylko tam, gdzie nikt nie chodzi albo wewnątrz istniejącej bryły kolizji). Oprawa włącza się **per strefa** (`MuseumFloorLevel.ART_ZONES`): strefy P3 zostają greyboksem, dopóki ich budowniczy nie dopisze swojej strefy. Światło: przepis piętra **`Floor1LightRecipe`** (środowisko, księżyc, mgła/sondy/budżet cieni per sala, oprawy) na tych samych `LightSpec` co model percepcji, plus nieliczne światła tylko-dla-oka (smugi w mgle, podświetlenia) zapisane w danych przepisu. Wydajność: **`RoomCuller`** (sale dalej niż 2 przejścia od kamery: światła, cząsteczki, sondy, mgła, procesy dekoracji wyłączone na poziomie serwera renderowania — węzły zostają „widoczne” dla percepcji i zaciemnienia), **okludery** z brył powłoki, presety Low–Ultra z nowymi efektami.

**Technologia:** Godot 4.7.2 (Forward+), GDScript ze statycznym typowaniem, tabulatory, angielskie identyfikatory, `tr()`; testy `bash tools/run_tests.sh --filter=…` bez okna; scenariusz z oknem tylko jako polecenie dla kontrolera.

**Wejście (wiążące):** projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §5.1, §5.7, §10.1–10.3, §11.3, §12; katalogi `docs/art/kit-pietro1-dziedziniec.md`, `docs/art/kit-pietro1-egipt.md`, `docs/art/styl-przewodnik.html`; wzorzec lobby: `src/level/level_art.gd`, `src/style/art_kit.gd`, `art_library.gd`, `src/level/level_lighting.gd`, `src/style/lobby_light_recipe.gd`; greybox: `src/level/floor1/zones/{court,entrance,booth,north_hall,hub_kit,egypt,west_kit}.gd`, plany W2/W3/W5b (prośba W5b: świetliki dziedzińca pod `roof_glass`); gałąź `guard-colossus` (tron i łamliwe kolumny Kolosa stawia strażnik w `guardian_colossus` / `colossus_column_<n>`).

---

## 1. Ograniczenia i zasady

- **Kolizja = greybox.** Żaden dodany model nie ma kolizji. Dekoracje bez kolizji stoją tylko: przy ścianie (w grubości pasa ≤ 0,3 m), wysoko (> 2,4 m nad podłogą), wewnątrz istniejącej bryły kolizji albo są drobne (krzesła, słoje). Wyjątek uzgodniony z W2/W5b: **świetliki dziedzińca** (dziury w płycie stropu pod szklanymi polami dachu — szkło `roof_glass` na dachu ma już kolizję) i **portal Czytelni 3 m** zamiast 4 m (szerokość otworu modelu `rr_drum_door`), jeśli testy przejść to przyjmą; inaczej zostaje 4 m i jambs modelu są przesunięte.
- **Testy szybkie:** zestaw buduje Piętro I bez oprawy (`MuseumFloorLevel.dress_default = false` w `_reset_globals()` runnera); oprawa tylko w testach `test_floor1_art*` i w scenariuszach.
- **Model światła prawdziwy:** każde światło, które realnie oświetla podłogę, jest `LightSpec` układu (percepcja je czyta). Księżyc kierunkowy wpada tylko przez świetliki (`RoomSpec.skylights`, percepcja liczy je jako `moon_level`). Światła przepisu (smugi w mgle, podświetlenia gzymsów) mają małą energię na powierzchniach.
- **Strażnik Kolosa:** sala dostaje architekturę, światło i mgłę; tronu i kolosa nie stawiam (przychodzą ze strażnikiem w `guardian_colossus`), reflektory celują w `COLOSSUS_SEAT + 6 m`. Kolumny sali (`column`) ubieram modelem `egypt_column_open`; po scaleniu `guard-colossus` elementów `column` w sali nie ma (są znaczniki) i ubranie znika samo.
- **Bez okien i dźwięku** przy pracy: wszystko bez okna; zrzuty robi kontroler poleceniem z §6.

## 2. Decyzje — infrastruktura

| Co | Decyzja |
|---|---|
| Oprawa per strefa | `LevelBuilder.art_rooms: Dictionary` (pusty = wszystkie). Powłoka: bryła należy do sali `room_of(owner)`; elementy: `spec.room`; schody: `room_low`; przejścia: ościeża tylko po stronie ubranej sali; `LevelArt.dress` tylko dla ubranych sal. `MuseumFloorLevel.ART_ZONES = [court, entrance, booth, north_hall, egypt]`, `art_rooms` = sale tych stref + sale „otwarte niebo” dachu (sufit = niebo: bez wyglądu i bez cienia, żeby księżyc wpadał przez szkło). |
| Style sal | `ArtKit.ROOMS` dostaje style P2 i wpisy `same_as` dla każdego id sali Piętra I (`court_balcony` → `court`, `entrance_hall` → `entrance`, `booth_*` → `staff_corridor`/`security`/`closet`, `north_hall` → `north_hall` (nowy: wapień, pilastry), `egypt_*` → style z katalogu). `ArtKit.style_name(room)` rozwiązuje `same_as` (kolumna holu, schody, ościeża pytają o nazwę stylu, nie o id). Test: każda sala ubranych stref ma jawny styl. |
| Elementy | `ArtKit.piece()` najpierw pyta `Floor1Art.piece(kit, size, room, seed)` (dopasowania per styl sali i rozmiar), potem reguły lobby. Elementy zastąpione przez bohaterów (`wall` bębna, `shelf` Czytelni, płyty balkonu) dostają pusty `Visual`. |
| Oprawy świateł | `ArtKit.fixture(kit, room)`: w Egipcie `sconce` → `egypt_torch_lamp`, `bulb`/`desk_lamp` w obozie → `camp_lamp`; w Czytelni `desk_lamp` bez modelu (lampy są w `rr_desk`). Reflektory (`SPOT` z oprawą `egypt_spotlight`) dostają bazę światła, nie tylko obrót Y. |
| Przejścia | `ArtKit.passage(..., opening_id)` z nadpisaniami `Floor1Art.PORTALS`: `j_court_egypt` od dziedzińca pylon `egypt_portal_great` (6 × 7), od przedsionka `egypt_portal_4m` ×1,5; `j_court_entrance`, `j_court_enlightenment`, `j_court_north` łuki `hall_arch_4m` w skali otworu; `j_egypt_assyria` pylon; łuk 15 m przedsionek → galeria: dwie kolumny papirusowe + architraw z belek; 10 × 10 do Sali Kolosa: portal `egypt_portal_4m` ×2,5/×2,2. |
| Świetliki dziedzińca | `court.skylights` = 8 prostokątów pod szklanymi polami dachu (siatka 0,5 m, wewnątrz pól `roof_glass`): na ćwiartkę x 2…26 / z 16…26 i x 16…26 / z 2…16 (NW do x −21,5 przy szopie). Percepcja: pod nimi `moon_level`. |
| Zestaw tylko dla testów | `MuseumFloorLevel.dress_default` (statyczny, gra: true; runner testów: false). |

## 3. Decyzje — sale

### 3.1 Wielki Dziedziniec (`court`, `court_balcony`)
- **Dach:** 4 × `court_roof_q` (obrót 0/90/180/270°) — stal rzuca cień siatki, szyby bez cienia. Pod polami szkła świetliki w stropie; na dachu `roof_glass` → przezroczyste szkło bez cienia. Sufit sal dachu (`roof_catwalks`, `roof_plant`) = niebo (bez wyglądu, bez cienia); ściany dachu zostają (fasady nad krawędzią szkła).
- **Bęben:** 16 × `rr_drum_wall`/`rr_drum_door` (k = −j, portale co 4), 16 × `rr_dome_sector`, `rr_oculus`, `rr_dome_outer`; greyboksowe `wall` bębna bez wyglądu. Ślepe portale W/S/E: dwa liście `door_grand_leaf_*` 1,5 × 4,5 na obu licach.
- **Ściany:** `portland_ashlar`, cokół, gzyms pasowy na 7 m, **pilastry** co 6 m od 7 do 16,3 m, gzyms koronujący pod dźwigarem dachu (17,85 m, nie pod płytą 22 m).
- **Balkon:** 7 × `court_balcony_seg` (k = −3…3) na płytach pierścienia (płyty i ich balustrady bez wyglądu); podesty boczne: pole `limestone_court` + `court_parapet_2m/1m` na balustradach; słupy pod balkonem `entrance_column` (dorycka, w skali 1 × 6,6).
- **Schody:** zestaw `court_stair_step` × 47, `court_stair_parapet_4m` po wolnych bokach, `court_stair_mass` (styl `court`: `"stairs_kit": "court"`).
- **Wyposażenie:** latarnie `court_lamp_post` (rozmiar natywny), ławki `court_bench`, informacja (model lobby `info_desk` — okrągła lada nie mieści się w kolizji 8 × 2,4), kawiarnia `cafe_counter` (skala X ≤ 1,3) + 4 × `cafe_table` + 3 `cafe_chair` przy każdym, sklep (`shop_front` ×0,732 na licu kiosku, bryła kiosku w polu `portland_ashlar`; krata greyboksu bez wyglądu — roleta jest w modelu), totem `totem_haida` (−135°), plan `court_map_board`, drogowskazy `sign_wing` (Egipt / Oświecenie), tablice nad przejściami `sign_wing_portal_*` w zestawie strefy (dla stref bez zestawu: brak tablicy), sztandary `banner` w kolorze skrzydła (kopie materiału z odcieniem), postument T-Reksa (istniejący `trex_pedestal`).

### 3.2 Czytelnia (`court_reading`)
- 16 × `rr_bookcase`/`rr_bookcase_door` (półki greyboksu bez wyglądu), dywan `carpet_reading`, 6 × `rr_desk` na r 6,5 (lampy w modelu), 4 × `rr_catalogue_arc` (45° + 90° k), astrolabium = model `astrolabe` w `FloorFinale.Astrolabe` (pierścienie obracają się powoli; greybox pierścieni, gdy modelu brak), wystawa „Wiek pary i stali”: `steam_engine` (koło zamachowe i regulator kręcą się — proces dekoracji), `steam_banner` za kartaczownicą, `steam_podium` pod zbrojami w gablotach (bez kolizji, płaski).
- Światło: zielone lampy biurek (LightSpec bez osobnej oprawy), kinkiety galerii, reflektor kartaczownicy, **snop księżyca z latarni** (LightSpec MOON w oculusie) na astrolabium + kurz w nim; podświetlenie kopuły (przepis: 4 słabe reflektory w górę spod gzymsu, bez cienia).

### 3.3 Hol wejściowy (`entrance_*`), kanciapa (`booth_*`), korytarz północny (`north_hall*`)
- Hol: styl `entrance` (boniowanie do 6 m, ciosy, `marble_hall`, kasetony 3 m), kolumny `entrance_column`, **mozaika** `entrance_mosaic` w osi (0; 0; 42), drzwi główne `entrance_door_l/_r` + `entrance_door_sign`, galeria (płyta, fasada, kasetony pod nią w stylu holu), balustrada kamienna, kasa `ticket_booth`, szatnia `cloakroom_counter` (×0,9, front na zachód), wieszak (`coat_rack` → stojak z płaszczami z modelu szatni; brak osobnego modelu: zostaje szatnia), schody z zestawu holu.
- Kanciapa: style lobby `staff_corridor`/`security` (jak kanciapa lobby: CCTV, szafki, biurko, krzesło), schody służbowe i stróżówka: `corridor_w`/`closet`.
- Korytarz północny: nowy styl `north_hall` (wapień, cokół, gzyms, pilastry z elementów `pilaster` → `hall_pilaster_*`), gabloty, popiersia, ławki, tablice skrzydeł (Ameryki, Azja), krata krypty (`grate_leaf_4m` + `grate_frame_8m` w drzwiach-bramie 5 m: skala), krypta: `stone_rubble`, sarkofagi.

### 3.4 Egipt (`egypt_*`)
- Style z katalogu: galeria/przedsionek `egypt_gallery`, Sala Kolosa `egypt_colossus_hall`, grobowce `egypt_tomb` (niski strop: pas `tomb_wall` 8 × 4 m), pokój konserwatora: `closet`+tynk (przystań, ciepło), schody i magazyn służbowy: `corridor_w`, sekrety: `egypt_tomb`.
- **Galeria:** belki `egypt_beam_4m` w poprzek co 4 m; **kraty clerestorium** `egypt_clerestory_3m` położone poziomo w 4 studniach światła (3 × 2 m — dokładnie okno) i 3 × 4 = 12 krat w studni Sali Kolosa (9 × 8 m) → pasiaste snopy księżyca kierunkowego; na ścianie wschodniej (od strony dziedzińca) 4 okna clerestorium jako wysunięte obramienia z nocnym niebem za szybą (dekor; smuga w mgle z przepisu, bez cienia).
- **Szpaler:** 8 × `pharaoh_statue` na `egypt_plinth` (rzeźby greyboksu 2 × 6 × 2 na postumentach 2,6 × 1 × 2,6), reflektory `egypt_spotlight` na LightSpec (bazą światła), sekhmet × 6 rzędem przy ścianie zachodniej między kolosami (w pasie ≤ 0,7 m? — nie: sekhmet ma 1,2 m głębokości; tylko tam, gdzie stoją postumenty: brak — rezygnacja), `amenhotep_head` na podeście przedsionka? — **nie** (brak bryły kolizji); sarkofagi obozu na `plinth` (`sarcophagus` ×0,89), obelisk przedsionka = rzeźba 1 × 5,5 × 1.
- **Przedsionek:** `rosetta_case` + `rosetta_stone` w `StoneSpot` (gablota greyboksu 2,2 × 2 × 1,6), ławka, obelisk, czerwona lampa.
- **Obóz 1898:** namiot `camp_tent` (×1,1, wejście na południe) na bryle 3,5 × 2,4 × 3, stół `camp_table` (biurko), skrzynie `camp_crate`/`camp_crate_b`, `camp_rifle_rack` przy stole (strzelba leży na stole — marker), lampy naftowe `camp_lamp` na oprawach `bulb`/`desk_lamp`, krzesło `camp_chair`.
- **Grobowce:** sarkofagi/trumny na `plinth` (na przemian `sarcophagus`, `sarcophagus_red`), stojące trumny `coffin`/`coffin_black` na skrzyniach 0,8 × 2 × 0,7 w korytarzu grobowym, pochodnie `egypt_torch_lamp`, `canopic_jars` i `shabti_case` przy ścianach sal grobowych tam, gdzie stoją skrzynie/postumenty.
- **Sala Kolosa:** kolumny `egypt_column_open` (13 m: skala Y 1,18), fryz na 10 m, belki, portal `egypt_portal_great` + skrzydła `egypt_seal_door_l/_r` w bramie Chorsabadu (wygląd `SealGate` dla `seal_sun`, gdy model jest), dwa reflektory na tron, księżyc przez kratę stropu, pochodnie.

## 4. Decyzje — światło i atmosfera (`Floor1LightRecipe`, §10.1, §10.3)

| Element | Wartość startowa |
|---|---|
| Środowisko | jak lobby (SDFGI 4 kaskady, komórka 0,2 m — piętro 178 × 138 m; SSR, SSAO, SSIL, glow, AgX, mgła tylko w objętościach, 40 m froksli), ambient 0,08 (Egipt ciemniejszy) |
| Księżyc | kierunek (−0,36; −0,86; −0,30) — od wschodu-południa: przez szkło dziedzińca (smugi przesunięte ~9 m na NW) i przez kraty studni Egiptu (pasy na zachodnim szpalerze i lewym boku tronu); 2,2 energii, mgła × 9, cienie 100 m (preset) |
| Mgła per sala | dziedziniec 0,010 (jasna, chłodna), Czytelnia 0,014 (ciepła, kurz książek), hol 0,012, korytarz pn. 0,014, galeria 0,018 (piaskowa (0,86; 0,78; 0,62)), Sala Kolosa 0,022, grobowce 0,03, służbowe 0,008 |
| Sondy odbić | dziedziniec (posadzka z wapienia, 2 sondy: N i S od bębna — box 60 × 22 × 30), Czytelnia, hol, galeria (granit polerowany), Sala Kolosa; UPDATE_ONCE, wnętrze |
| Budżet cieni | dziedziniec 4 (reflektor T-Reksa, 2 latarnie przy holu, +1), Czytelnia 2, hol 3, galeria 3 (obóz + 2 reflektory szpaleru), Sala Kolosa 2 (reflektor tronu + pochodnia), grobowce 1, kanciapa (przystań) 1, reszta 0; globalnie w zasięgu przycinania ≤ 10 |
| Oprawy | `egypt_spotlight` (cień, mgła 0,25 — ciepły stożek w pyle), `egypt_torch_lamp` (bez cienia, mgła 0,3), `court_lamp_post` (cień tylko dwóch przy holu), `desk_lamp` Czytelni (bez cienia, mgła 0,1), MOON-pule (mgła 2,0 — snop) |
| Awaryjne | czerwone lampy jak dotąd (zawsze), mgła 0,6 |
| Cząsteczki | kurz w snopach dziedzińca (4 emitery pod polami szkła, ~140 drobin każdy, tylko w presecie ≥ Medium), kurz w snopie Czytelni, **piasek** w galerii (2 emitery nad nawą, opadający drobny pył, ciepły) i w Sali Kolosa (1), drobiny w studniach Egiptu; materiał `ArtLibrary.billboard("dust_mote", 4)`, `visibility_aabb` na salę, przycinanie grafem |

## 5. Wydajność (§11.3)

- **RoomCuller** (`src/level/room_culler.gd`, `Node`): co 0,25 s sala kamery (`layout.room_at`, z sal-gości jak balkon → gospodarz), BFS po przejściach (wszystkie, otwarte czy nie; sala-gość ↔ gospodarz = 0), aktywne ≤ 2. Dla nieaktywnych: `RenderingServer.instance_set_visible(rid, false)` dla świateł (węzeł zostaje `visible` → percepcja i zaciemnienie bez zmian; sygnał `visibility_changed` ponawia ukrycie), cząsteczki (`emitting = false` + ukrycie), sondy, objętości mgły, procesy dekoracji (`process_mode = DISABLED`). Księżyc i światła awaryjne w sąsiedztwie zostają zgodnie z zasadą (awaryjne też są w salach). Test: przełączanie i nietknięte `visible`.
- **Okludery:** jeden `OccluderInstance3D` z `ArrayOccluder3D` ze ścian/stropów/podłóg powłoki (bryły ≥ 0,4 m grubości, pomniejszone o 0,05 m; bez brył „nieba”) dla całego piętra; `rendering/occlusion_culling/use_occlusion_culling = true`.
- **Zasięgi:** drobne rekwizyty (krzesła, słoje, skrzynie) `visibility_range_end` 40 m; belki, pasy i kasetony bez cienia (jak lobby); posągi i bryły-bohaterowie z cieniem.
- **Presety** (`GraphicsQuality.PRESETS`): nowe klucze `particles` (Low 0, Medium 0,5, High 1, Ultra 1,5 — mnożnik `amount_ratio`), `probes` (Low off), `cull_depth` (Low 1, reszta 2), `occlusion` (wszędzie on). `apply_level` stosuje je do węzłów w grupach `quality_particles`, `quality_probes`.
- **Pomiar bez okna:** czas budowy piętra z oprawą i bez (ms), liczba węzłów, siatek, trójkątów ubranych stref, świateł i cieni per sala → tabela w §8; **pomiar z oknem** (kontroler): `run_tour.sh perf` w 8 najcięższych miejscach.

## 6. Scenariusz „wycieczka” (§12)

`tools/run_tour.sh shots|dry|perf [--preset=high] [--only=a,b]` → `tests/scenarios/tour_scenario.tscn`:
- **shots** (okno 1920 × 1080, `--audio-driver Dummy`, Floor I z oprawą w prawdziwej grze, HUD ukryty): ~26 ujęć (dziedziniec: wejście z holu, szeroko spod łuku, z balkonu, w górę na dach, róg totemu, kawiarnia, T-Rex w snopie; Czytelnia: od drzwi, kopuła w górę, astrolabium; hol: od drzwi kanciapy, z galerii; kanciapa; korytarz północny; Egipt: przedsionek z Rosettą, długi widok galerii od łuku, obóz ze strzelbą, szpaler, studnia z kratą, Sala Kolosa, grobowce, sala sarkofagów, przystań konserwatora; awaria prądu: dziedziniec i galeria z latarką; areny: Kolos obudzony (strażnik w sali), T-Rex po astrolabium) → `tests/_out/tour/<ujęcie>[_preset].png` + `metrics_<preset>.json` (średnia luminancja Rec.709 w sRGB, % pikseli prawie czarnych L < 0,04; alarm: średnia < 0,06 albo czarnych > 55 %).
- **dry** (bez okna, `--headless`): ta sama lista ujęć: kamera w sali (`room_at`), nie w bryle, cel widoczny (promień), aktywne światła/cienie/cząsteczki po przycinaniu, czas budowy → `tests/_out/tour/dry.json`; kod wyjścia ≠ 0 przy błędzie.
- **perf** (okno): 8 najcięższych ujęć, średnia kl./s, p99, wywołania rysowania → `perf_<preset>.json`.
Polecenie dla kontrolera (nocą): `bash tools/run_tour.sh shots --preset=high && bash tools/run_tour.sh perf --preset=high`.

## 7. Pliki

| Plik | Co |
|---|---|
| `src/style/floor1_art.gd` (nowy) | dopasowania elementów, bohaterowie dziedzińca/Czytelni/holu/Egiptu, portale, oprawy |
| `src/style/floor1_light_recipe.gd` (nowy) | dane przepisu piętra + światła dodatkowe |
| `src/level/room_culler.gd` (nowy), `src/level/level_occluders.gd` (nowy) | przycinanie grafem, okludery |
| `src/style/art_kit.gd`, `src/level/level_art.gd`, `level_builder.gd`, `level_lighting.gd`, `lobby_light_recipe.gd` | style P2, delegacja do `Floor1Art`, sale per strefa, przepis jako dane |
| `src/level/floor1/museum_floor_level.gd`, `zones/court.gd`, `zones/egypt.gd` | `ART_ZONES`, oprawa, świetliki, oprawy reflektorów |
| `src/core/graphics_quality.gd` | presety: cząsteczki, sondy, głębokość przycinania |
| `src/game/floor1/floor_finale.gd`, `seal_gate.gd` | model astrolabium, skrzydła pieczęci Słońca |
| `tests/integration/test_floor1_art.gd`, `test_floor1_art_light.gd` (nowe), `tests/test_runner.gd` | testy oprawy, światła, przycinania |
| `tests/scenarios/tour_scenario.{gd,tscn}`, `tools/run_tour.sh` (nowe) | wycieczka |

## 8. Zadania

### Zadanie 1: plan (ten dokument) — commit
- [x] Plan.

### Zadanie 2: oprawa per strefa, style sal, świetliki, testy szkieletu
- [x] `LevelBuilder.art_rooms`, `MuseumFloorLevel.ART_ZONES`/`dress_default`, runner testów ustawia `false`.
- [x] Style P2 i `same_as` dla sal stref; `ArtKit.style_name`; sufity „nieba” bez wyglądu i cienia.
- [x] `court.skylights` pod szkłem; (portal Czytelni 3 m, jeśli testy przejść zielone).
- [x] Testy: każda sala ubranych stref ma jawny styl; kolizje z oprawą = bez oprawy; strefy spoza `ART_ZONES` zostają greyboksem; `--filter=floor1` zielone; commit.

### Zadanie 3: elementy i oprawy (`Floor1Art.piece`, `fixture`, przejścia)
- [x] Tabela dopasowań (dziedziniec, Czytelnia, hol, kanciapa, korytarz pn., Egipt), portale, oprawy per sala, reflektory bazą światła.
- [x] Test: w ubranych strefach żaden element nie nosi greyboksu poza listą dozwolonych; każdy id modelu użyty przez oprawę istnieje w `ArtLibrary` (KIT/KIT_COURT/REGISTRY) i ma plik; commit.

### Zadanie 4: bohaterowie (`Floor1Art.dress`)
- [x] Dach, bęben, kopuła, oculus, regały, balkon, podesty, schody dziedzińca, sklep, kawiarnia, totem.
- [x] Hol: mozaika, drzwi, szatnia; korytarz pn.: pilastry; Egipt: belki, kraty studni, okna clerestorium, obóz, Rosetta, sarkofagi, trumny, portale, kolumny Sali Kolosa; astrolabium; skrzydła pieczęci Słońca.
- [x] Test: liczby bohaterów (16 segmentów bębna, 4 ćwiartki dachu, 16 regałów, 4 + 12 krat), nic z dekoracji nie wchodzi w przestrzeń chodzenia (próbka promieniami po siatce nawigacji: dekoracja bez kolizji poniżej 2 m tylko w dozwolonych miejscach); commit.

### Zadanie 5: światło i atmosfera (`Floor1LightRecipe`)
- [x] Przepis jako dane (lobby bez zmian w zachowaniu), środowisko, księżyc, mgła, sondy, budżety, oprawy, światła dodatkowe; `MuseumFloorLevel` buduje z przepisem przy oprawie.
- [x] Testy: budżet cieni per sala, światła w grupach (MAIN/EMERGENCY/HAVEN/MOON), zaciemnienie gasi oprawy ubranych sal, percepcja: świetliki dziedzińca widziane jako księżyc, testy lobby zielone; commit.

### Zadanie 6: cząsteczki i presety
- [x] Kurz w snopach, piasek w Egipcie, grupy `quality_particles`; presety `particles`/`probes`/`cull_depth`.
- [x] Test: presety zawierają nowe klucze i stosują je do węzłów; commit.

### Zadanie 7: wydajność — przycinanie grafem i okludery
- [x] `RoomCuller`, `LevelOccluders`, ustawienie projektu; pomiar bez okna (czas budowy, liczby) do §9.
- [x] Testy: przełączanie świateł/cząsteczek/sond dalej niż 2 przejścia, `visible` węzłów nietknięte, percepcja bez zmian; commit.

### Zadanie 8: wycieczka
- [x] `tour_scenario` (shots/dry/perf), `run_tour.sh`; uruchomić tylko **dry**; commit.

### Zadanie 9: całość
- [x] `--filter=floor1`, `--filter=art`, `--filter=lobby`, potem pełny `bash tools/run_tests.sh` raz; dopisać §9; commit; raport (≤ 40 linii).

## 9. Jak zbudowano (3.10)

### Liczby (pomiar bez okna)

| Co | Wartość |
|---|---|
| Budowa piętra z oprawą | 6,4 s na zimno (wczytanie modeli), ok. 0,65 s na ciepło; greybox 0,35 s; cała noc w grze (scenariusz) 9,6 s na zimno, nawigacja 0,27 s |
| Węzły siatek | 6 898 z oprawą (hub + Egipt) wobec 5 070 greyboksu |
| Bohaterowie | 4 ćwiartki dachu, 16 segmentów bębna + 16 regałów + 16 sektorów kopuły, oculus, astrolabium, 4 łuki katalogu, 7 segmentów balkonu, 47 × 2 stopnie schodów, 6 belek nawy, 4 + 12 krat studni, 4 okna clerestorium, pylon Chorsabadu |
| Cienie lamp (budżet / użyte) | dziedziniec 4/3, Czytelnia 2/0, hol 3/2, galeria 3/3, Sala Kolosa 2/1, przedsionek 1/1, przystanie 1/1; na całym piętrze 38 (31 w strefach bez oprawy, wg danych W1–W5) |
| Przycinanie grafem (High, głębokość 2) | z dziedzińca 41 sal / 351 lamp włączonych (hub ma 5 wyjść), z galerii 17 / 141, z Sali Kolosa 10 / 99, z kanciapy 6 / 34; cienie w promieniu 50 m: 5–12 |
| Drobiny | 1 490 w zasięgu dziedzińca, 1 650 w galerii (High; Medium połowa, Low brak) |

Pomiar z oknem: `bash tools/run_tour.sh perf --preset=high` (8 widoków) — do zrobienia przez kontrolera. Render gliny w Blenderze (eksport glTF poziomu, bez okna) potwierdził kratownicę dachu rzucającą siatkę na posadzkę dziedzińca i pasiaste plamy księżyca z krat studni w nawie Egiptu. Pełny zestaw testów po scaleniu: 1622 zielone, bez linii ERROR.

### Odstępstwa od planu i od greyboksu

| Co | Zmiana | Dlaczego |
|---|---|---|
| Portal Czytelni | 3 m zamiast 4 m (test huba poprawiony) | otwór modelu `rr_drum_door` |
| Kawiarnia | lada 5,1 × 2,3 m przy ścianie północnej (z = −28,75), notatka i łup na niej przesunięte | model ma bar z tyłu; inaczej 1 m baru bez kolizji |
| Postument astrolabium | 3,5 × 0,3 × 3,5 | stopnie modelu r 2,2 / 1,75 |
| Świetliki dziedzińca | 8 prostokątów pod polami szkła (W5b) | księżyc przez kratownicę; percepcja widzi tam księżyc |
| Reflektory szpaleru | wiszą pod belkami (z belki, nie z + 1,5), oprawa `egypt_spotlight` | belki omijają studnie |
| Lampka obozu | płomień 1,07 m (na skrzyni) | model lampy naftowej |
| Księżyc | (−0,17; −0,96; −0,22) zamiast niższego | render gliny: niski księżyc padał na ściany i w cień bębna |
| Informacja | model lobby `info_desk` | okrągła `court_info_desk` nie mieści się w kolizji 8 × 2,4 |
| Szatnia | model ścieśniony (60 % głębokości) | wschodnia połowa wolna do pękniętej ściany |
| Nie stawiam | tronu, kolosa i kolumn Sali Kolosa (strażnik: `dress_arena()`), `rr_dome_outer` (dach to P3), słojów kanopskich i gabloty szabti (brak brył kolizji) | |
| Strefy | `ART_ZONES` = hub + Egipt; Grecja i Oświecenie mają style, ale wejdą z P3 (dopisać strefę) | |
| Test chodzenia po dachu | `test_floor1_service_walk` padał na `pietro-1` sprzed scalenia (kładki nieosiągalne); po scaleniu `pietro-1` (3.10) zielony | — |

### Polecenia
- Zrzuty (kontroler, nocą, bez dźwięku): `bash tools/run_tour.sh shots --preset=high && bash tools/run_tour.sh perf --preset=high`
- Kontrola bez okna: `bash tools/run_tour.sh dry` (28 widoków OK)

## 10. Ryzyka

| Ryzyko | Odpowiedź |
|---|---|
| Świetliki dziedzińca zmieniają percepcję (jaśniej pod szkłem) | to zgodne z projektem (§5.7, W5b); testy percepcji i „łagodnego startu” uruchomione; w razie potrzeby `moon_level` dziedzińca jak dziś |
| Nie widzę obrazu (bez okna) | dane sprawdzane testami i trybem dry; przepis oparty na sprawdzonym lobby; druga runda po zrzutach kontrolera |
| Koszt: SDFGI + mgła + cienie na 178 × 138 m | przycinanie grafem, budżety cieni, zanik świateł, okludery, presety; pomiar w perf |
| Kolizja z `guard-colossus` | bez tronu i kolosa; kolumny Sali Kolosa tylko jako ubranie istniejących elementów |
| Strefy P3 obok greyboksu (wspólne ściany w kolorze strefy) | przejściowe; `ART_ZONES` rośnie z P3 |
