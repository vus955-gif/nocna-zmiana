# Grafika Piętra I — Wielki Dziedziniec, Czytelnia, hol wejściowy

> Plan wykonawczy grafiki strefy `court` + `entrance` (projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md`, §2, §4.1, §5.7, §6, §10.1–10.3). Kopia robocza `art-court` (gałąź `art-court`). Równolegle inne kopie robią skrzydła (Egipt, Asyria, Grecja, Oświecenie) i kod poziomu — wspólne rejestry (`ALL`, `ArtLibrary.KIT`, `ArtKit.ROOMS`, `strings.csv`) **tylko dopisywać na końcu**.

> **Stan (3.10):** zadania zrobione (poza kolumną pod balkonem); katalog z liczbami: `docs/art/kit-pietro1-dziedziniec.md`.

**Cel:** pierwszy duży widok gry ma zachwycić. Szklany dach z trójkątnej kratownicy, którego cień księżyc kładzie w mgle na jasnym wapieniu; bęben Czytelni z portlandzkiego kamienia; w środku niebiesko-złota kopuła z oknem w szczycie, regały, promieniste biurka z zielonymi lampami i astrolabium na odłamki. Do tego wyposażenie dziedzińca (ławki, informacja, kawiarnia, sklep z kratą, totem Haida, drogowskazy w kolorach skrzydeł, schody na balkon) i zestaw holu wejściowego.

## Konwencje

- Blender 5.1 zawsze `-b`; `bash tools/art/build_art.sh <nazwy>` (`FAST=1` do szybkich prób brył). Podglądy Cycles: `tests/_out/art/<nazwa>.png` — **oglądać i poprawiać**.
- Godot tylko `--headless`; na koniec `bash tools/run_tests.sh` na zielono.
- Gęstość tekseli: architektura 64 px/m, meble 96–160, bohaterowie 128–256 (totem, astrolabium).
- Osie: Godot x = wschód, y = góra, −z = północ, środek dziedzińca (0, 0, 0). Blender (x, y, z) → Godot (x, z, −y).
- **Elementy „bębna”** (segmenty ścian, regały, sektory kopuły, łuk katalogu, balkon, schody) mają początek **w środku bębna na podłodze** i są zbudowane wokół osi północnej (−Z Godota). Ustawia się je jednym obrotem: `rotation.y = k · 22,5°` (k = 0 północ, 4 zachód, 8 południe, 12 wschód).
- **Ćwiartka dachu** też ma początek w środku dziedzińca (na podłodze), pokrywa trójkąt między przekątnymi wokół północy; cztery kopie co 90°.
- Pozostałe: konwencja zestawu (początek = środek podstawy, przód = −Z).
- Szkło zawsze osobną częścią z materiałem `glass` (bez cienia) — kratownica dachu rzuca cień, szyby nie.
- Commit po każdej rodzinie modeli; stopka `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Liczby (wspólne dla wszystkich modeli)

| Co | Wartość |
|---|---|
| Bęben | 16-kąt, promień wierzchołków 12,5 m (lico zewn. w odległości 12,26), lico wewn. 11,2 (wierzch. 11,42); ściana ≈ 1,06 m |
| Wysokości bębna (zewn.) | cokół 0–0,9; boniowanie 0,9–6,6; gzyms balkonowy 6,6–7,0; porządek pilastrów 7–15; belkowanie 15–16,6; attyka 16,6–22,0; wieniec pod dach 22,0–22,4 |
| Portale | otwór 4 × 4,5 m (pasują `door_grand_leaf_l/_r`) w segmentach k = 0, 4, 8, 12 |
| Wnętrze | regały 0–4,1 i 4,3–9,2, galeria (kładka) y = 4,1–4,3, głęb. 1 m z balustradą; gzyms 9,2–10,8; okna-lunety 10,8–13,2; kopuła 13,2 → 19,9 (okno w szczycie r 1,8) |
| Dach | obrzeże y = 19,0 na murach dziedzińca (|x|, |z| = 30); pierścień wewn. r = 13,2 na wieńcu bębna y = 22,4; łagodna wypukłość |
| Balkon | y = 7, pierścień r 12,26 → 16,5 wokół północnej połowy bębna (8 segmentów po 22,5°) |
| Schody na balkon | dwa biegi łukowe obiegające bęben od południa, 47 stopni 0,149 × 0,40 m (20,4°), oś biegu r = 14,6 |
| Hol wejściowy | 32 × 22 m, h 12; podest y = 6 (40 stopni 0,15 × 0,40) |

## Zadania

### 1. Tekstury kafelkowe (64 px/m) i rampy
- [x] `limestone_court` — jasny wapień w dużych płytach (pasy 0,75 m, płyty 1,5 / 0,75), cienkie fugi, skamieniałości, polerka.
- [x] `portland_ashlar` — kamień portlandzki (chłodniejszy, jaśniejszy od `limestone`) w ciosach 0,6 m (ściany dziedzińca, pola).
- [x] `court_steel` — jasnoszara malowana stal kratownicy (przetarcia, zacieki).
- [x] `carpet_reading` — granatowy dywan Czytelni ze złotym rombem.
- [x] Rampy: `portland`, `dome_blue`, `cedar`, `formline_red/black/teal`, kolory skrzydeł.

### 2. Szklany dach (`court_roof.py`)
- [x] `court_roof_q`: ćwiartka 60 × 60 m (trójkąt między przekątnymi), kratownica z trzech rodzin prętów (promieniste, pierścienie, przekątne w jodełkę), węzły, belka obrzeża i pierścienia; szyby w osobnej części `court_roof_q_glass`.
- [x] Budżet: ≤ 12 tys. trójkątów na ćwiartkę; stal jako pole `tile:court_steel` (bez atlasu).
- [x] Podgląd złożenia: `tools/art/court_preview.py` — cały dziedziniec z modeli .glb, księżyc + mgła wolumetryczna w Cycles → `tests/_out/art/court_*.png` (cień siatki w mgle).

### 3. Bęben Czytelni z zewnątrz (`court_drum.py`)
- [x] `rr_drum_wall` — segment 22,5°: cokół, boniowanie, gzyms na wysokości balkonu, pilastry na narożach, nisza, belkowanie z gzymsem, attyka z płycinami, wieniec.
- [x] `rr_drum_door` — to samo z portalem (opaska, belkowanie, fronton) i otworem 4 × 4,5 m przez całą grubość muru.
- [x] Kolizje: opis pudeł na segment w katalogu.

### 4. Czytelnia od środka (`court_reading_room.py`)
- [x] `rr_bookcase` / `rr_bookcase_door` — regały dwukondygnacyjne z grzbietami książek, kładka galerii z żeliwną balustradą i wspornikami, gzyms.
- [x] `rr_dome_sector` ×16 — luneta z oknem, sześć rzędów kasetonów (błękit, złoto, rozety), żebra.
- [x] `rr_oculus` — pierścień i przeszklona latarnia w szczycie (snop księżyca na astrolabium).
- [x] `rr_dome_outer` — kopuła z zewnątrz (ołów, żebra) dla trasy po dachu.

### 5. Meble i wystawa Czytelni (`court_rr_props.py`)
- [x] `rr_desk` — promieniste biurko 4 m (dwustronne, przegroda, 4 zielone lampy, krzesła).
- [x] `rr_catalogue_arc` — łuk 45° pierścienia katalogu (szufladki, mosiądz), 8 kopii.
- [x] `astrolabe` — cokół + astrolabium z obracanymi pierścieniami (części), 6 gniazd `Shard_1…6`, `Core`.
- [x] Wystawa „Wiek pary i stali”: `steam_banner` (tablica tytułowa), `steam_podium` (podest pod zbroje), `steam_engine` (maszyna parowa — bohater, jeśli starczy czasu); kartaczownica = istniejący `gatling_display`.

### 6. Wyposażenie dziedzińca (`court_props.py`)
- [x] `court_bench`, `court_info_desk` (INFORMACJA), `cafe_counter` (KAWIARNIA), `cafe_table`, `cafe_chair`, `shop_front` (SKLEP MUZEALNY, część `grille` — roleta), `court_plinth`, `court_lamp_post` (znacznik `Light`).

### 7. Totem Haida (`totem_haida.py`)
- [x] 12 m, piętrowe stworzenia (ptak gromu z rozpostartymi skrzydłami, niedźwiedź, kruk, żaba, orka), stylizowane, malowane w czerwień, czerń i turkus na wyblakłym cedrze; 128 px/m.

### 8. Drogowskazy (`court_signs.py`)
- [x] `sign_wing` (słupek z tablicą + strzałka) i `sign_wing_portal` (tablica nad przejściem) w 6 zestawach tekstur: EGIPT, ASYRIA, GRECJA, OŚWIECENIE, AZJA, AMERYKI I OCEANIA (kolory skrzydeł).
- [x] `court_map_board` — „PLAN MUZEUM” ze schematem piętra.

### 9. Balkon i schody (`court_stairs.py`)
- [x] `court_balcony_seg` / `_open` — segment 22,5° płyty balkonu z fryzem i pełną balustradą (9 kopii, k = −4…4).
- [x] Zestaw schodów zamiast łukowych biegów (łuk wokół bębna kolidowałby z portalami): `court_stair_step`, `court_stair_parapet_4m`, `court_stair_mass`, `court_parapet_2m/_1m`; w podglądzie dwa proste biegi przy bokach bębna.
- [ ] `court_balcony_column` — pominięte (balkon wspornikowy).

### 10. Hol wejściowy (`entrance_kit.py`)
- [x] `entrance_column` (dorycka grecka, 12 m), `entrance_coffer_3m` (kaseton z meandrem), `entrance_door_l/_r` (brąz, zamknięte) + `entrance_door_sign` („Wyjście otwarte od 6:00”), `cloakroom_counter` (SZATNIA), `entrance_mosaic` (mozaika posadzki). Kasa = istniejący `ticket_booth`, schody = istniejące moduły `stair_*` przez `ArtKit.stairs`.

### 11. Krata korytarza północnego (`court_grate.py`)
- [x] `grate_leaf_4m` (22 pręty co 0,18 m) i `grate_frame_8m` — otwór 8 × 5 m (x −4…4).

### 12. Rejestracja, katalog, testy
- [x] `ALL` (dopisać moduły), `ArtLibrary.KIT` (id → części), `ArtLibrary.KIT_COURT` (id → rozmiar natywny, budżet), `KIT_SETS` (zestawy drogowskazów), `EXTRAS` (emisja lamp).
- [x] `ArtKit.ROOMS`: style `court`, `reading_room`, `entrance` (pola: ściany, posadzki).
- [x] Test `tests/integration/test_art_court.gd` (ładowanie, budżety, rozmiary, znaczniki, części).
- [x] Katalog `docs/art/kit-pietro1-dziedziniec.md`: tabela id, rozmiary, osie, znaczniki, rozmieszczenie, podglądy, trójkąty; „jak postawić bęben i dach”.
- [x] `bash tools/run_tests.sh` na zielono; commit.
