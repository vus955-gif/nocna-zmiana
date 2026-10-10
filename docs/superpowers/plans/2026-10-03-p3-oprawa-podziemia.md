# P3 — oprawa podziemi (poziom serwisowy, y = −6)

> **Dla wykonawcy:** zadania po kolei, commit po każdym. Kroki mają pola `- [ ]`.

**Cel:** greybox podziemi Piętra I (21 sal: pierścień korytarzy, tunel do Asyrii, kotłownia z pomostem, krzyż z fundamentami Czytelni, warsztat renowacji, rozdzielnia, magazyny, archiwum, strefa pod holem, trzy sekrety) przestaje być szarymi pudłami — dokładnie wg wzorca holu i Egiptu (`2026-10-03-p2-oprawa-hol-egipt.md` §9): strefa w `ART_ZONES`, style sal w `ArtKit.ROOMS`, wyglądy elementów z istniejących zestawów, przepis światła, wycieczka i testy. **Bez nowych modeli Blendera**: gotowe kafelki i modele (`shelf_unit`, `cast_shelf`, `asy_tablet_shelf`, skrzynie, szafki, biurka, popiersia, wazy, `corridor_pipes_*`, tabliczki skrzydeł) plus kilka brył z prymitywów (kotły, rury, pomost) na kafelkach metalu.

**Wejście (wiążące):** `src/level/floor1/zones/basement.gd` i `service_kit.gd` (kolizje, światła, znaczniki zostają), plan W5b, wzorzec P2 (`Floor1Art`, `Floor1LightRecipe`, `RoomCuller`), tabele kitów (`docs/art/…`). Skrzydła Asyrii, Ameryk i Azji są w tej wersji zamknięte („Otwarcie wkrótce”) — ich drzwi w podziemiach zostają ryglowane; nic do zrobienia.

## 1. Decyzje

| Co | Decyzja |
|---|---|
| Strefa | `MuseumFloorLevel.ART_ZONES += basement`; wszystkie sale podziemi dostają jawny styl w `Floor1Art.ROOM_STYLES` (test: każda sala ubranej strefy ma styl i żaden element nie zostaje greyboksem) |
| Ściany | tynk malowany: cokół (pas do 1,3 m) w kolorze sali, powyżej jasny tynk; nowy klucz stylu `dado_tint` (barwi tylko dolną warstwę ściany podzielonej `upper_from`); kolor cokołu wg kierunku skrzydła: zachód (Egipt) ochra, tunel (Asyria) ceglany, północ (Ameryki/Azja) morski, reszta szaro-zielony; kotłownia — cegła osmalona, krzyż — rustyka kamienna (fundamenty), warsztat — ciepły tynk i deski |
| Posadzki, stropy | beton (korytarze, rozdzielnia), kamienne płyty (kotłownia, krzyż, tunel), deski (warsztat), linoleum i płyty sufitowe (archiwum, magazyn straży: styl lobby `staff_corridor`); w stropach korytarzy pas rur `corridor_pipes_*` (gotowy model), cokolik `skirting_*` |
| Rury skrzydeł | element `pipe` jako walec w kolorze skrzydła z obejmami co 4 m (bez cienia) |
| Elementy | nowy moduł `BasementArt` (`src/style/basement_art.gd`): kotły kornwalijskie (cegła + walec na kaflach żeliwa), komin, drzwiczki paleniska ze żarem, hałda węgla, pomost (płyta stalowa, słupki, balustrada z rur, schody ażurowe), filary krzyża, transformatory z żebrami i izolatorami, stoły warsztatu, studnia, prycze, syrena, filary cegły w tunelu; regały i skrzynie z gotowych modeli (rzędy `cast_shelf`/`asy_tablet_shelf`/`shelf_unit` plecami do siebie, skrzynie na regałach), szafy aktowe `lib_filing_cabinet`, popiersie i waza na cokołach magazynu, połowicznie odnowione eksponaty na stołach warsztatu (odlew torsu, głowa woskowa, urna w skorupach, tarcza) |
| Znaki | tabliczki skrzydeł z istniejących zestawów; tabliczka kanciapy = `sign_room` „TYLKO DLA PERSONELU” |
| Światło | `Floor1LightRecipe.ROOMS` dla 21 sal: mgła niska i zimna (0,004–0,010; kotłownia ciepła), świetlówki bez cienia, mnożnik energii sali (`lamp_energy`), cienie ≤ 2 na salę (kotłownia: dwie żarówki pomostu, krzyż: lampa, warsztat: lampa stołowa), brak sond; czerwone lampy zawsze, żar kotłów na grupie awaryjnej |
| Para | `steam_basement_1…3`: cząsteczki (grupa `quality_particles`, przycinane grafem, skala presetów) |
| Wydajność | przycinanie grafem i okludery działają bez zmian (węzły w grafie sal) |
| Wycieczka | 9 ujęć podziemi (`basement_*`) w `VIEWS`/dry |
| Cache powłoki | pokoje i otwory bez zmian → `bake_shell_cache.sh` nie jest potrzebny |

## 2. Zadania

### Zadanie 1: plan — commit
- [x] Plan.

### Zadanie 2: strefa, style sal, kolory cokołów
- [x] `ART_ZONES += basement`, `Floor1Art.ROOM_STYLES` dla 21 sal, style `basement_*` w `ArtKit.ROOMS`, `dado_tint` w `ArtKit.field`.
- [x] Test: każda sala podziemi ma jawny styl; commit.

### Zadanie 3: wyglądy elementów i opraw (`BasementArt`)
- [x] Kotłownia, pomost, rury, krzyż, rozdzielnia, warsztat, magazyny, sekrety, tabliczki.
- [x] Test: żaden element podziemi nie zostaje greyboksem, każdy model istnieje, wyglądy w obrysie kolizji; commit.

### Zadanie 4: światło, mgła, para
- [x] Wpisy `Floor1LightRecipe.ROOMS`, budżet cieni, mnożnik energii, para w znacznikach.
- [x] Testy: budżet ≤ 2, mgła w salach, para jest, przycinanie; commit.

### Zadanie 5: wycieczka i testy
- [x] 9 ujęć `basement_*` w `tour_scenario.gd` (dry w całości, shots dla kontrolera).
- [x] `git merge pietro-1` (unia `ART_ZONES`, stylów, wycieczki), pełny zestaw, raport; commit.

## 3. Ryzyka

| Ryzyko | Odpowiedź |
|---|---|
| Nie widzę obrazu (bez okna) | wartości światła z analogii do kanciapy i Egiptu; `bash tools/run_tour.sh shots --only=basement_corridor_ring,…` dla kontrolera, mnożnik `lamp_energy` w jednym miejscu |
| Zmiana `Floor1Art.ROOM_STYLES`/`ART_ZONES` równolegle z Grecją i Oświeceniem | rozwiązać jako sumę |
| Kolizje | bez zmian: wyglądy mieszczą się w obrysach (test `floor1_art_fit`) |

## 4. Jak zbudowano (3.10)

### Liczby (pomiar bez okna)

| Co | Wartość |
|---|---|
| Budowa piętra z oprawą | 3,5 s na zimno, 0,63 s na ciepło; węzły siatek 7 789 (hub + Egipt + podziemia; P2: 6 799, greybox 5 056) |
| Cienie lamp podziemi (budżet / użyte) | kotłownia 2/2 (żarówki pomostu), krzyż 1/1, warsztat 2/2, reszta 0; nigdzie > 2 |
| Przycinanie grafem (High, głębokość 2) | z korytarza północnego 22 sal / 169 lamp, z kotłowni 15 / 105, z krzyża 14 / 107, z warsztatu 8 / 59, z magazynu zbiorów 14 / 121, z tunelu 12 / 93; para 3 × 40 cząsteczek tylko tam, gdzie kotłownia w zasięgu |
| Wycieczka | `bash tools/run_tour.sh dry`: 37 widoków OK (9 nowych `basement_*`) |

### Odstępstwa i odkrycia

| Co | Zmiana | Dlaczego |
|---|---|---|
| Ściany i stropy podziemi | cienka „skóra” (1 cm ściany, 4 cm stropu) w stylu sali: klucze stylu `wall_skin`, `ceiling_skin` | powłoka to jedna bryła z jednym wyglądem: ściany zewnętrzne podziemi biegną w górę przez kamień holu i dachu, a strop to płyta o wyglądzie sali **nad** nim (dziedziniec, Egipt); bez skóry korytarze miałyby kamienne ściany i sufity z góry. Otwory (`holes`) zostają wolne |
| Cokół | `dado_tint` barwi dolną warstwę ściany dzielonej `upper_from`; `upper_from` w stylach podziemi to wysokość **świata** (podłoga −6) | `ArtKit.wall_layers` porównuje z absolutnym y |
| Pas rur w stropie | datum 3,6 m (0,1 m w strop), nie „ceiling” | tabliczki skrzydeł (2,68–3,05 m) nie wchodzą w rury |
| Oprawy spotów w dół | `LevelLighting.add_light`: spot skierowany pionowo w dół ma oprawę obróconą tylko wokół Y | świetlówki i żarówki leżały bokiem (oprawa szła za wiązką); działa też dla dachu |
| `RoomCuller` | gospodarz gościa musi go obejmować w pionie (`guest.floor_y < host.ceiling_y`) | kotłownia „gościła” balkon dziedzińca (ten sam obrys, inne piętro): z dziedzińca 41 sal / 351 lamp włączonych, teraz 27 / 244; z Czytelni 15 / 156 → 9 / 120 |
| Para i cząsteczki | w `Floor1LightRecipe.atmosphere` przy znacznikach `steam_*` | dane układu bez zmian |
| Rozdzielnia | `Switchboard` ubiera szafkę (tablica, manometry, rubieżnik, bezpieczniki, kable), gdy sztuka jest włączona | znacznik `switchboard` rysuje gra, nie układ |
| Nie robię | drzwi dwuskrzydłowych kotłowni (skrzydła z szybą z kitu), wnętrza szybu windy (Asyria) | poza zakresem |
| Jasność | `lamp_energy` 1,3–1,6 (krotność energii lamp sali) i sondy odbić w kotłowni, krzyżu, rozdzielni i pierścieniu | bez okna: wartości z analogii do kanciapy i Egiptu; **do sprawdzenia przez kontrolera**: `bash tools/run_tour.sh shots --only=basement_ring_north,basement_boiler_fires,basement_reserve_aisle` (alarm ciemności: średnia < 0,06) |

### Polecenia
- Zrzuty (kontroler, nocą, bez dźwięku): `bash tools/run_tour.sh shots --preset=high --only=basement_ring_north,basement_wing_door,basement_boiler_fires,basement_gantry,basement_crossing,basement_workshop,basement_reserve_aisle,basement_switchboard,basement_tunnel`
- Kontrola bez okna: `bash tools/run_tour.sh dry`

## 5. Stan prac / co dalej (WIP, 3.10)

**Zrobione:** zadania 1–5 w całości: strefa w `ART_ZONES`, 21 sal ze stylami, `BasementArt` (kotły, pomost, rury, krzyż, rozdzielnia, warsztat, magazyny, sekrety, tabliczki, skrzynka windy towarowej), skóry ścian i stropów, przepis światła z sondami i parą, poprawki `RoomCuller` i oprawy spotów, 9 ujęć `basement_*` (dry OK), testy `test_floor1_art_basement.gd`. Zielone: `floor1_art*` (26), `floor1_service`, `art_kit`, `level_art`, `lobby_lighting`, `bash tools/run_tour.sh dry`. `pietro-1` scalone (ostatnio 177720a).

**Zostało:** (1) **pełny zestaw testów nie został uruchomiony po ostatnim scaleniu** (przerwany na polecenie): `bash tools/run_tests.sh`, oczekiwane: zielony, bez linii ERROR; (2) `git merge pietro-1` jeszcze raz, a gdy gałąź `dress-gr-enl` wejdzie pierwsza, rozwiązać konflikty jako sumę (`ART_ZONES`, `ROOM_STYLES`, `ArtKit.ROOMS`, przepis światła, `level_art`, `level_lighting`: oprawy spotów obie reguły naraz: `UPRIGHT_FITTINGS` lub pionowo w dół); (3) zrzuty z oknem przez kontrolera (jasność `lamp_energy` 1,3–1,6 dobrana z analogii, bez obrazu): `bash tools/run_tour.sh shots --only=basement_ring_north,basement_boiler_fires,basement_reserve_aisle`, ewentualna korekta w `Floor1LightRecipe.ROOMS`; (4) opcjonalnie: drzwi dwuskrzydłowe kotłowni w stylu przemysłowym, wnętrze szybu windy (Asyria).
