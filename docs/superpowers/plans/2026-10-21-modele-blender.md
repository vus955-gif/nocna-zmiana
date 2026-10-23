# Modele Blendera zamiast brył proceduralnych (21.10.2026)

> Gałąź `blender-models` (z `pietro-1` @76bac48b). Ostatnie etapy oprawy (P4, P5, QA wizualne) zbudowały kilka eksponatów
> i sprzętów w GDScripcie z prymitywów (`BoxMesh`, `CylinderMesh`, `SphereMesh`, `TorusMesh`, siatki z `SurfaceTool`),
> bo zestaw nie miał modeli. Ten etap zastępuje je modelami Blendera w tej samej konwencji co reszta sztuki
> (`tools/art/models/*.py`, atlas pikselowy o stałej gęstości, `.glb` z nazwanymi częściami i znacznikami).
> Zasady sesji: tylko `blender -b` i `--headless`, bez okien i dźwięku, jeden Blender naraz, bez renderów Cycles
> (budowy z `--no-preview`), nic na GitHub.

## 1. Inwentarz brył proceduralnych

Kolumny: element (`kit` greyboksa) → gdzie stoi, bryła greyboksa (x × y × z m), kolizja (*pudło* = pudło greyboksa;
*dopasowana* = `Floor1Art.FIT_COLLISION`, `CollisionFit` rysuje graniastosłupy z wyglądu), z czego zbudowany dziś,
priorytet (1 = bohater na widoku).

### 1.1 Do zastąpienia w tym etapie (kolejność = priorytet)

| # | Element | Gdzie | Bryła | Kolizja | Dziś | Model |
|---|---|---|---|---|---|---|
| 1 | `bison` | Sala Ameryki Płn. (−13; 0,4; −50) na cokole 2 × 0,4 × 3,4 | 1,5 × 1,9 × 3,0 | dopasowana | 12 sfer/walców, sierść = kafel żwiru z tintem, kudły = strzecha | `bison` |
| 2 | `chariot` | jama Sali Lwów (−84,5; PIT; −20,5) | 1,8 × 1,6 × 3,2 | dopasowana | 2 bryły, torusy kół, 16 szprych, dyszel | `asy_chariot` |
| 3 | `kayak` + stojak (`pedestal` 1 × 0,9 × 5,4) | Sala Ameryki Płn. (−5,2; 0,9; −44,5) | 0,7 × 0,4 × 5,0 | kajak dopasowana, stojak pudło | kadłub z `SurfaceTool`, pokład, torus, wiosło; kozły z walców | `kayak`, `kayak_stand` |
| 4 | `whaleboat` | Galeria Pacyfiku (−44,2; 0; −79,5) | 1,8 × 1,3 × 7,0 | dopasowana | kadłub z `SurfaceTool`, ławki, kozły, wiosła z walców | `whaleboat` |
| 5 | `tipi` | Sala Ameryki Płn. (−8; 0; −53) | 4,2 × 5,5 × 4,2 | dopasowana | stożek `CylinderMesh` w kaflu tapy, 9 żerdzi, łata drzwi, 2 klapy | `tipi` |
| 6 | sosny (`Pine_*`) ×2 | ogród Azji, nad koroną muru (od 3,15 m) | ~3 × 4 × 3,5 | brak | rury i elipsoidy z `SurfaceTool`, kolory wierzchołków | `garden_pine` |
| 7 | bambus (`Bamboo_*`) ×3 kępy 6 / 4,5 / 3,5 m | ogród Azji, nad koroną muru | kępa × ~8 m | brak | rury i liście z `SurfaceTool` | `garden_bamboo` |
| 8 | `water_tank` | dach, taras techniczny (35,5; Y; 38,2) | 3 × 3,5 × 3 | dopasowana | walce, torusy, drabinka z walców | `roof_water_tank` |
| 9 | `plant_unit` ×2 | dach, taras techniczny | 2,4 × 1,6 × 1,4 | pudło | skrzynia + listwy + walec + torus | `roof_air_handler` |
| 10 | `chimney` ×4 | taras (1,2 × 4,5 × 1,2), naroża kładek (1,5 × 3 × 1,5) | j.w. | pudło | 2 skrzynie + 2 stożki | `roof_chimney_tall`, `roof_chimney_short` |
| 11 | `pigeon_cages` | strych gołębiarzy (`roof_loft`) | 4,2 × 1,8 × 0,6 | pudło | listwy, półki, quad siatki, grzędy z walców | `roof_pigeon_loft` |
| 12 | `cage` ×2 | jama Sali Lwów | 1,8 × 1,8 × 1,8 | pudło | ~40 prętów z walców, deski | `asy_cage` |
| 13 | `scaffold` | Nimrud (−99,2; 0; −46) | 1,2 × 3,2 × 4,0 | dopasowana | stojaki, rygle, stężenia z walców, pomosty | `asy_scaffold` |
| 14 | `dome_lantern` (yaw 0) | szczyt kopuły Czytelni | 3,5 × 1,7 × 3,5 | pudło (poza zasięgiem) | 16 słupków, walec szkła, stożek, iglica | `rr_dome_lantern` |

### 1.2 Zostają proceduralne (świadomie)

- **Bloki i płyty w polach kafli** (cokoły z bazaltu, alabastru, kamienia; stele z płyt reliefu, Czarny Obelisk, czapy,
  pomost `canoe_bridge`, maty eksponatów, płyty kładek dachu, bęben kopuły): to architektura w polach kafli (`arch_tile`)
  — model nic by nie dodał, a straciłaby się ciągłość wzoru z sąsiednimi ścianami.
- **Barierki dachu i szprosy pól szkła**: jedna scalona `ArrayMesh` na rozmiar (optymalizacja draw calli z P5,
  testy `test_the_roof_shares_its_meshes`); stalowe rury czytają się dobrze jako rury.
- **Sznury lampionów, alfardy schodów Świątyni, wsporniki Dysku** — drobne łączniki dopasowywane do wysokości sali.
- **Kolumny cedrowe Asyrii** (walec + opaski + kapitel z modeli `asy_corbel`): długość zmienna (3–13,5 m), kafel cedru
  mapowany lokalnie — kandydat na model dopiero przy następnym przejściu Asyrii.

### 1.3 Poza zakresem tego etapu (lista na później)

- **Podziemia** (`basement_art.gd`, plan P3): kocioł, transformator, prycze, warsztat, syrena, rozdzielnica, filary,
  rury — to osobne przejście (etap P3 nie należy do wymienionych planów P4/P5/QA).
- **Teleskop obserwatorów** (Oświecenie, `_telescope`, 0,5 × 1,4 × 0,5, punkt widokowy) — mały, mosiądz i dąb z walców;
  następny w kolejce po liście 1.1.
- Ławka i lampion dzwonu w Azji, kufer zbrojmistrza — złożone głównie z modeli, prymitywy to dodatki.

## 2. Konwencja modeli

- Skrypt `tools/art/models/<grupa>.py`, `build()` zwraca listę `kit(...)` (początek = środek podstawy, front Godota −Z,
  budowane frontem do Blendera +Y z `built_final=True` albo frontem −Y i obracane przez `kit()`), skala w metrach.
- Gęstość atlasu: eksponaty bohaterowie (bizon, rydwan, kajak) **256 px/m** (jak jaguar, wilk, maski); duże eksponaty
  (łódź 7 m, tipi 5,5 m) 128 px/m (jak moai); sprzęty dachu i ogrodu 96–128 px/m (jak sprzęty dziedzińca, kamienie ogrodu).
- Materiały z palet skrzydła: Ameryki `artlib/americas.py` (drewno `am_wood`, skóra, bazalt), Asyria `artlib/asy.py`
  (cedr, brąz z patyną, alabaster), Azja `artlib/asia.py` (kora, kamień), dach `artlib/court_materials.py` (żeliwo, stal
  dziedzińca, kamień portlandzki) i `materials.py` (stal, cegła).
- Rejestracja: `ArtLibrary.KIT` (części, znaczniki) + nowa tabela **`ArtLibrary.KIT_PROPS`** (rozmiar natywny, budżet
  trójkątów) — test `test_art_props.gd` ładuje każdy model, sprawdza rozmiar ±(0,05 + 2 %), budżet, materiały, części.
- Podmiana w module sztuki: ta sama bryła — model skalowany do pudła greyboksa (`size / native`), ten sam obrót co bryły
  proceduralne; kolizje: pudło zostaje albo `CollisionFit` rysuje je z nowego wyglądu (lista `FIT_COLLISION` bez zmian).

## 3. Testy

- `test_art_props.gd` (nowy): każdy model ładuje się z częściami i znacznikami, rozmiar natywny, budżet, ubrany.
- Na ubranym piętrze: wygląd każdego podmienionego elementu w jego pudle greyboksa (± tolerancja) — rozszerzenie testów
  skrzydeł; pod koroną muru ogrodu nic z roślin, nic w przejściach (istniejący test ogrodu).
- Bez zmian, muszą zostać zielone: `test_floor1_art_fit`, `test_floor1_collision*`, `test_floor1_softlock*`,
  `test_floor1_art_rewards`, `test_reward_spots`, testy Świątyni Węża (`test_floor1_art_americas`).

## 4. Stan prac / co dalej (23.10, noc — cała lista §1.1 zastąpiona)

**Zastąpione (zielone, zatwierdzone):** 1 `bison`, 2 `asy_chariot` + 12 `asy_cage`, 3 `kayak` + `kayak_stand`,
4 `whaleboat`, 5 `tipi`, 6–7 `garden_pine` / `garden_bamboo`. Modele: `tools/art/models/bison.py`, `asy_lion_pit.py`,
`americas_boats.py`, `tipi.py`, `garden_plants.py` (w `build_models.ALL`); rejestr `ArtLibrary.KIT` + `KIT_PROPS`;
dopasowanie do pudła `Floor1Art.fit_model`; test `tests/integration/test_art_props.gd`.

**Noc 23.10 (osobny commit na każdy model, testy skrzydła + `floor1_collision` zielone po każdym):**

| # | Model | Skrypt | Trójkąty | Atlas | Uwagi |
|---|---|---|---|---|---|
| 8 | `roof_water_tank` | `roof_water_tank.py` | 2898 | 128 px/m | nitowany zbiornik z 3 pierścieni na kratownicy z kątowników, stężenia, drabinka na froncie (−Z), przelew, wskaźnik pływakowy, zawór; kolizja dopasowana |
| 9 | `roof_air_handler` (×2) | `roof_air_handler.py` | 1820 | 128 px/m | centrala z lat 60. na płozach: żaluzje, drzwiczki, wentylator pod kratką poza środkiem (łup na dachu pierwszej) |
| 10 | `roof_chimney_tall` / `_short` | `roof_chimneys.py` | 576 / 894 | 96 px/m | cegła w wiązaniu angielskim (bez łat tynku z kafla), wspornikowy gzyms, czapa, nasady z sadzą, zwód odgromowy |
| 11 | `roof_pigeon_loft` (×2) | `roof_pigeon_loft.py` | 1086 | 128 px/m | 18 przegródek, drzwiczki z siatki = karty z własnym zestawem `pigeon_door` (256 px/m, alpha scissor w `EXTRAS`) |
| 13 | `asy_scaffold` | `asy_scaffold.py` | 1892 | 96 px/m | rusztowanie rurowo-złączkowe, pomost, drabina na otwartym końcu, płachta, tabliczka „KONSERWACJA / NIE WCHODZIĆ” od strony sali (+X) |
| 14 | `rr_dome_lantern` (+ `_glass`) | `rr_dome_lantern.py` | 2194 | 64 px/m | 16 słupków, szklany bęben, ołowiana kopułka, iglica pod czerwoną lampą; sufit latarni z lekką ciepłą emisją (`EXTRAS` 1,0) |

- Materiały dachu: `tools/art/artlib/roof_materials.py` (malowana blacha z zaciekami rdzy spod szwów, nity, odchody
  gołębi, ocynk, ciemna stal barierek).
- `KNOWN_UNDRAWN["water_tank@roof_plant"]`: po podmianie najdłuższy „goły” odcinek obrysu = 0,97 m (stopa drabinki
  i rura zasilająca poza nogami kratownicy) → wpis podniesiony z 0,7 do **1,0** z nowym uzasadnieniem. Przelew
  poprowadzony pod zbiornikiem i w dół przy nodze, drabinka 15 cm od płaszcza — inaczej odcinek wychodził 1,16 m.
- `KNOWN_UNDRAWN["scaffold@assyria_nimrud"]` 0,7: zmierzone po podmianie 0,69 m — wpis bez zmian.
- Latarnia kopuły nie jest dopasowywana do pudła (stoi na szczycie kopuły, 0,75 m pod pudłem greyboksa):
  `Floor1ArtRoof._lantern` stawia model na `-LANTERN_DROP`; jest w `KIT_PROPS` (rozmiar, budżet), nie w `PIECES`.
- Usunięte martwe pomocniki modułu dachu (`_rod`, `_tile`, `cage_mesh`).
- **Podgląd bez okna:** `tools/art/glb_preview.py` (Python Blendera, numpy): rzuty ortogonalne `.glb` z teksturą,
  alfą i szkłem (`--views=front,side,back,top,34,43` albo `yaw:elev`, `--focus`/`--radius` do zbliżeń), szary pasek
  1,8 m jako skala. Wynik w `tests/_out/art/glb_<model>.png`.
- Rydwan: muzeum pokazuje go **bez jarzma** (dyszel na koziołku), kabina zamknięta z tyłu poza wąskim wejściem,
  kolizja w 3 kolumnach (`FIT_COLUMNS["chariot@assyria_lions"] = 3`) — inaczej wypukły obrys koła + dyszel + jarzmo
  stał 1,6 m „w powietrzu” (`test_floor1_collision`).
- Liście bambusa i igły sosny: karty z własnymi małymi zestawami tekstur (`bamboo_leaves`, `pine_fringe`,
  alpha scissor w `EXTRAS`), nie w atlasie.
- Okno (jeden przebieg przez blokadę, `run_tour.sh shots`): widoki `roof_tower_top` (zbiornik w drzwiach wieży),
  `roof_plant_deck` (centrale od tyłu, wysoki komin), `roof_dome` (latarnia z ciepłą poświatą), `roof_loft`
  (gołębnik), `assyria_scaffold` (tabliczka czytelna) — wszystko czyta się poprawnie; 4 ujęcia w
  `tests/_out/blender-models/` (poza gitem). `roof_gutter_east`: komin narożny ginie w ciemności końca rynny.
- Po oknie: płachta na rusztowaniu przemalowana (miękkie plamy zamiast „moro”, słabsze AO od rur za nią);
  po tym zielone `art_props`, `art_assyria`, `floor1_art_east` (28/28).
- `git merge pietro-1` (@0c4219be): pełny zestaw jednoprocesowo 3266 zaliczonych, 0 błędów (35 min 40 s). Drugi
  `git merge pietro-1` (@2e59a773, głos G3) po przemalowaniu płachty: **pełny zestaw 3291 zaliczonych, 0 błędów**
  (33 min 43 s, bez linii ERROR). `bake_shell_cache.sh` niepotrzebny (sale i otwory bez zmian).

**Następny krok:** lista §1.1 jest zamknięta. Kolejny w kolejce: teleskop obserwatorów z §1.3 (Oświecenie,
`_telescope`, 0,5 × 1,4 × 0,5, mosiądz i dąb), potem podziemia (osobne przejście). Potok bez zmian: skrypt →
`blender -b ... --no-preview` (najpierw `--fast`) → podgląd `tools/art/glb_preview.py` → import
(`tools/art/import_settings.py` + `--headless --import` ×2) → `KIT`/`KIT_PROPS` + `PIECES` w `test_art_props.gd` →
testy skrzydła + `floor1_collision` → commit.

## 5. Do sprawdzenia w oknie

- **Bizon** (Sala Ameryki Płn.): sylwetka z 5 m (kudły peleryny, garb, głowa nisko, rogi), kolor sierści przy
  reflektorach z podłogi, czy oczy (lekka emisja) nie świecą za mocno.
- **Rydwan** (jama Sali Lwów): czytelność pasa rozet na kabinie z galerii, koła i dyszel na koziołku; czy brak jarzma
  nie razi; czy ruch wokół rydwanu nie zahacza o niewidzialne krawędzie (kolumny kolizji).
- **Klatki lwów**: krata zasuwy zwrócona do jamy (+X), budka dozorcy na dachu, skala przy postaci.
- **Kajak na stojaku**: skóra foki vs. drewno (czy nie czyta się jak deska), wiosło na przednim pokładzie, tabliczka
  „KAJAK / ARKTYKA” od strony sali, czy płozy dotykają kilu.
- **Łódź wielorybnicza**: biel klepek i czarny pas burty w świetle galerii, wiosła/kadzie/harpuny w środku.
- **Tipi**: wzór (pas ziemi z dyskami, góry, dysk na tyle, niebo z gwiazdami) — czy szanuje charakter, proporcje
  z drzwiami, klapy dymne na tyczkach, kopcenie u góry.
- **Sosny i bambus** (ogród Azji): karty igieł/liści z alfą z obu stron, gęstość kępy bambusa, lustrzane moduły
  (czy powtórzenie widać), czy nic nie miga na tle nieba.
- **Zbiornik na wodę** (taras techniczny): szarozielona farba w księżycu, czy zacieki rdzy spod szwów nie są zbyt
  regularne, numer „2” na froncie, drabinka od północy (−Z); czy ruch wokół nóg kratownicy nie zahacza (kolizja
  dopasowana, goły odcinek do 0,97 m przy stopie drabinki).
- **Centrale wentylacyjne**: niebieskoszara emalia obok ciemnych barierek (nie za jaskrawa?), żaluzje i drzwiczki od
  frontu (z wieży widać tył z rurami), łup na pierwszej centrali wisi ok. 4–5 cm nad daszkiem (pudło kolizji 1,6 m).
- **Kominy**: sadza u góry i nasady z bliska; czerwona lampa ostrzegawcza nad wysokim kominem wisi 0,3 m nad
  nasadami bez wspornika (pozycja lampy z poziomu, sprzed podmiany) — ewentualnie maszt w poziomie; kominy narożne
  kładek nie były w kadrze (giną w ciemności końca rynny).
- **Gołębnik**: siatka drzwiczek (alpha scissor z mipmapami) z odległości — czy nie znika/nie miga; trzy otwarte
  przegródki z misami.
- **Rusztowanie** (Nimrud): płachta po przemalowaniu, lampa na statywie, czy drabina na końcu (od +Z) nie wchodzi
  w kolizję przy obchodzeniu.
- **Latarnia kopuły**: proporcje niskiej ołowianej kopułki względem kopuły, ciepła poświata sufitu (emisja 1,0)
  — czy nie za mocna w trybie blackout.
- **Przegląd w oknie 23.10** (`2026-10-22-przeglad-w-oknie.md` §2): bizon, tipi, kajak (bez widocznego wiosła), modele dachu OK; rydwan, klatki, sosny/bambus nie z bliska.
