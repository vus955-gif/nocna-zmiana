# Projekt starć — sala jako mały scenariusz (Piętro I)

> Plan wykonawczy (krótki). Wykonawca: Claude (noc 22/23.10, tryb nocny), drzewo `.claude/worktrees/museum-story`, gałąź `encounters` od `pietro-1` @ `f7ec1352`.
> Autorytet: `docs/backlog-pietro1.md` **#20** („starcia jako małe scenariusze: wejście gracza, pierwszy kontakt, zmiana sytuacji, flankowanie, pojawienie się nowego typu przeciwnika, wykorzystanie architektury”), pomocniczo **#21** (wertykalność: ataki z różnych wysokości), **#25** (role bojowe; kontra uczona przy pierwszym spotkaniu), **#24** (reakcje na otoczenie — scenariusz nie może ich zabić), **#13** (trudność odłożona: nie zmieniamy liczb wrogów, Pyłu ani HP).
> Równolegle: gałąź `set-piece` (inny agent, `UncannyDirector`) — **nie ruszamy** `src/game/floor1/uncanny/*`; wspólne pliki (`floor_game.gd`, `strings.csv`, `test_runner.gd`) tylko małe, addytywne zmiany.

## Zasada

Sala ze scenariuszem nie jest „zestawem figur rozstawionych ręcznie”. Reżyser nocy dalej losuje **kto** stoi w sali (zestaw, limit gęstości, noc spokojna, osłabione skrzydło, łagodna noc 1) — scenariusz decyduje **kiedy, skąd i w jakiej kolejności** ci sami wylosowani wchodzą do walki. Scenariusz to krótka lista **taktów** (beats):

1. **wejście** — strażnik wchodzi w obszar startu (zwykle cała sala); to otwiera scenariusz,
2. **pierwszy kontakt** — jeden czytelny przeciwnik (zwykle rola TANK / MELEE) budzi się przy wejściu,
3. **zmiana sytuacji** — po czasie albo po pierwszym padłym: coś nowego (ostrzał z wysokości, dzwon, nowy rodzaj),
4. **flanka** — przeciwnik z innej strony niż wejście (z bocznych drzwi, zza pleców, z dalszego końca galerii),
5. **nowy typ** — inna rola niż dotąd (lew po wojownikach, psy Fu po zbrojach),
6. **architektura** — takt odpalany miejscem (strażnik wchodzi na podium / mija połowę galerii / bierze przedmiot).

Nie każdy scenariusz ma wszystkie sześć — 3–4 takty to norma.

## Format danych

`data/encounters/scenarios.json` (nie kod, nie ręczne pozycje w plikach stref). Na scenariusz:

| Pole | Znaczenie |
|---|---|
| `id` | klucz scenariusza (też w `RunState.used`: `scn_<id>_<takt>`) |
| `on` | `false` = scenariusz wyłączony (dzisiejsze zachowanie sali w 100 %); albo id na liście `"off"` na górze pliku |
| `rooms` | sale, których **wylosowani** eksponaty są obsadą (sala + jej balkon/podium) |
| `absorbs` | zasadzki (`AmbushSpec.id`) przejęte przez scenariusz: ich śpiący stają się obsadą taktu, zasadzka nie działa osobno |
| `from_night` | od której nocy (domyślnie 1) |
| `start` | prostokąt podłogi `[x0, z0, x1, z1]` + `y` `[min, max]`; brak = którakolwiek z `rooms` |
| `entry` | punkt odniesienia wejścia `[x, y, z]` (do wyboru „najbliższy / najdalszy od wejścia”) |
| `points` | nazwane miejsca oczekiwania `[x, y, z, yaw]` (za drzwiami bocznymi, w niszy) |
| `beats[]` | takty po kolei |

Takt: `id`; **obsada** — `roles` (nazwy `EnemyRoles.Role` małymi literami, `any`), opcjonalnie `kinds`, `room` (tylko eksponaty slotów tej sali), `count` (1–3), `pick` (`near` / `far` od `entry`, `seed` = kolejność ziarna — domyślnie), `fallback` (bierze kogokolwiek, gdy roli brak); **wyzwalacz** (pierwszy spełniony wygrywa) — `after` s od poprzedniego taktu (obowiązkowy w taktach ≥ 1, chyba że jest `pickup`: nic się nie zacina), `down` (tylu z obsady wcześniejszych taktów padło), `area` (prostokąt + `y`: miejsce w architekturze), `pickup` (znacznik podniesionego przedmiotu); **wykonanie** — `from` (punkt oczekiwania: eksponat stoi tam od początku nocy; tylko rodzaje bez „snu-ekspozycji”: nie mumia w grobowcu, relief w płycie, księgi na półce, nie stado), `also_from` (inne punkty: gdy scenariusz się zaczyna, obsada przechodzi **niewidziana** — poza kadrem strażnika albo za ścianą — do punktu najdalszego od niego; flanka nigdy nie czeka przy drzwiach, którymi wszedł), `cue` (dźwięk z `Sfx.SOUNDS` + kurz w miejscu aktorów), `lead` (zapowiedź → pobudka, **≥ 0,6 s**), `ring` (id dzwonu `TempleBell`: dzwon bije sam — mechanika biomu jako takt).

Obsada jest liczona **raz na noc, z ziarna** (`night_seed`, noc, id scenariusza): pula = wylosowani w `rooms` (bez innych zasadzek), kolejność z własnego generatora (reszta nocy się nie przesuwa); takt ≥ 1 bierze tylko śpiących (czuwający i patrole mogą być tylko pierwszym kontaktem). Kto nie trafił do obsady, zachowuje się jak dziś.

## Reguły

- **Deterministycznie:** ta sama noc = ta sama obsada, te same miejsca, ta sama kolejność.
- **Bez hordy:** scenariusz nie dodaje eksponatów — tylko układa wylosowanych (limit gęstości sali reżysera, noc spokojna, osłabione skrzydło działają jak dziś); takty po 1–3; limit polujących `PerceptionWorld` bez zmian.
- **Bez softlocka:** scenariusz niczego nie zamyka i nie blokuje; każdy takt ≥ 1 ma `after` (albo `pickup` — działanie gracza); punkty oczekiwania leżą na podłodze sali albo jej sąsiada (w terytorium eksponatu).
- **Czekający** (obsada taktów ≥ 1) śpią „twardo” (`Enemy.held`: nie słyszą hałasu, nie dają się zbudzić sąsiadom, nie „poruszają się we śnie”, widzą tylko na zmysł bliski 1 m) — inaczej pierwszy strzał zlałby takty w jedną falę. Trafienie budzi ich jak zawsze, a obudzony traci `held` (dalej słyszy jak każdy). Takt zdejmuje `held`, gra zapowiedź (dźwięk + kurz), po `lead` budzi (`EnemyBrain.wake`: wie, gdzie jest strażnik). `sound_asleep` (łagodna noc 1) zostaje nietknięte.
- **Zapowiedzi ≥ 0,6 s** (wymusza walidacja i silnik), potem jeszcze zwykła podejrzliwość mózgu.
- **Wyłącznik jednym wpisem:** `"on": false` albo id w `"off"` — wtedy pozycje, sen i zasadzki sali są jak dziś (test).
- **`museum.free()` + odbudowa:** stan tylko w `RunState.used` (`scn_<id>_<takt>`); wznowiona noc nie powtarza odpalonych taktów, obsada odpalonych śpi zwyczajnie (jak wznowiona zasadzka), reszta czeka dalej.
- **Zapis i przystanie:** obsada po slotach (`killed_slots`, straty stad bez zmian); scenariusz nie stoi w przystani; przerwa w przystani nie odpala taktów (strażnik jest poza salą i jej sąsiadami — zegar taktu stoi, patrz niżej).
- **`pickup`:** podniesienie przedmiotu odpala swój takt **i wszystkie przed nim**, po kolei (to moment scenariusza — jak dawna zasadzka).
- **Nigdy w walce ze strażnikiem / w finale:** gdy `GuardianKeeper.fighting()` albo `FloorFinale.fighting()` — scenariusze stoją (czas też). Areny strażników, przystanie i sekrety nie mają scenariuszy (walidacja).
- **Zegar taktu** liczy tylko, gdy strażnik jest w salach scenariusza albo ich sąsiadach; wyszedł dalej — takty czekają (nie budzą się za jego plecami w drugim końcu skrzydła).
- O świcie (`night_over`) nic już nie odpala.

## Trzy wzorce (zbudowane)

| Sala | Architektura | Takty |
|---|---|---|
| **Nereidy** (`greece_nereid` + podium) | wysokość: podium z portykiem 4,5 m, balkon, schody | wejście (hala lub podium) → **kontakt**: hoplita najbliżej wejścia → **z wysokości**: popiersia z portyku (przejęta zasadzka `greece_podium`) po 5 s / 1 padłym / wejściu na podium → **flanka**: hoplita / popiersie zza drzwi metop (punkt w sali metop), a gdy strażnik wszedł od metop — zza drzwi Bassae, po 8 s / 2 padłych |
| **Galeria Nimrud** (`assyria_nimrud`) | długa galeria (36 m), reliefy w ścianach | wejście od bramy → **kontakt z dystansu**: wojownik z reliefu na **dalekim** końcu → **flanka / nowy typ**: lew z reliefu **najbliżej wejścia** (za plecami idącego w głąb) po 7 s / 1 padłym / minięciu połowy → **architektura**: bezpiecznik (`pickup`, przejęta zasadzka `assyria_fuse`) budzi oba reliefy przy nim |
| **Zbrojownia** (`asia_armor`) | dwie wyspy zbroi, dzwon nad środkiem | wejście → **kontakt**: zbroja najbliżej wejścia → **mechanika biomu**: dzwon zbrojowni bije sam (`ring`), budzą się psy Fu / reszta zbroi — dzwon wabi do środka, a strażnik uczy się kontry (uderz w dzwon, gdy są pod nim: oszołomienie) → **tył sali**: dwie zbroje straży skarbca (przejęta zasadzka `asia_armor_guard`) po 9 s / wejściu w ich obszar |

## Pozostałe sale — pomysł na scenariusz (jedno zdanie)

**Dziedziniec i hol**
- `entrance_hall` — (noc ≥ 2) figura woskowa w szatni obraca się, gdy strażnik idzie do dziedzińca; druga wychodzi zza kolumnady za jego plecami.
- `entrance_gallery` — popiersie na końcu galerii budzi się, gdy strażnik wejdzie po schodach z dachu; flanka z drugich schodów.
- `court` — (noc ≥ 2, nigdy w finale) wosk przy wejściu, po 1 padłym figury z balkonu (`court_balcony`) — ostrzał z góry; flanka z czytelni.
- `court_balcony` — część scenariusza dziedzińca (ostrzał z wysokości), osobno: figura na szczycie łuku (`court_balcony_apex`).
- `court_reading` — rycerze przy gablocie kartaczownicy (zasadzka) jako ostatni takt po dwóch woskach między regałami.
- `north_hall` — patrol idzie ku kracie; wilki z obu końców holu (zasadzka bramy) jako flanka z dwóch stron.
- `north_hall_crypt` / `north_hall_crypt_vault` — schodzenie w dół: dźwięk z krypty jako zapowiedź, przeciwnik czeka na dnie, drugi schodzi za strażnikiem.

**Egipt** (poza drogą nocy 1 lub od nocy 2 — trasa bota)
- `egypt_vestibule` — wosk-archeolog przy wejściu; mumia z bocznej sali sarkofagów jako nowy typ.
- `egypt_gallery` — (już: obóz przy strzelbie) skarabeusze z dalszego końca nawy po pierwszym padłym; mumie obozu jako finał na `pickup`.
- `egypt_tomb_passage` — wąski korytarz: rój z przodu, mumia z tyłu (flanka w ciasnocie).
- `egypt_tombs` — płyta klątwy jako takt: chodzący eksponat nadeptuje płytę, strzałki przecinają drogę.
- `egypt_tomb_hall` — (już: sarkofagi) wieka otwierają się po kolei, nie naraz — każde z zapowiedzią.
- `egypt_service_stairs` / `egypt_service_corridor` — coś schodzi za strażnikiem z galerii; skarabeusze z dołu.

**Asyria**
- `assyria_gate` — reliefy bramy (zasadzka) jako kontakt; lew z Balawat wchodzi drzwiami z boku.
- `assyria_balawat` — patrol wojownika, lwy z reliefów przy drugich drzwiach po 1 padłym.
- `assyria_lions` — dół łowów: lwy z dołu (−3 m), wojownik strzela z galerii nad nim (wysokość w drugą stronę); sieć jako kontra.
- `assyria_lions_gallery` — galeria nad dołem: wojownik z reliefu naprzeciwko, lew z dołu wbiega schodami.
- `assyria_library` — tabliczki: wojownik w głębi, lew z drzwi galerii lwów (flanka).
- `assyria_freight_stairs` — schody w dół: przeciwnik czeka w tunelu, drugi schodzi z sali łowów.

**Grecja**
- `greece_nereid_podium` — część scenariusza Nereid (wysokość).
- `greece_bassae` + `greece_bassae_gallery` — antresola: popiersie strzela z antresoli, hoplita wychodzi spod niej, gdy strażnik pod nią stanie.
- `greece_vases` — długi przejściowy pokaz: hoplita idzie nawą, popiersia z gablot budzą się po kolei „falą” od wejścia.
- `greece_metopes` — (już: lapici) linia hoplitów jako kontakt, popiersia z kąta po 1 padłym; lampa Heliosa jako kontra.
- `greece_service_corridor` / `greece_service_stairs` — pionowa pętla: popiersie w dole, hoplita schodzi z góry.

**Oświecenie**
- `enlightenment_library` — długa sala z galerią: księgi z dalszych regałów, potem z galerii nad strażnikiem (wysokość); zasadzka czytelni jako finał.
- `enlightenment_library_gallery` — część scenariusza biblioteki (ataki z góry), osobno: księgi wracają na półki i znów zrywają się za plecami.
- `enlightenment_cabinet` — (już: raptory przy sztucerze) wilk w kontakcie, stado raptorów na `pickup` sztucera.
- `enlightenment_clocks` — Regulator: takty walki w rytmie zegara (wróg budzi się na „tyk”).
- `enlightenment_portraits` — portrety otwierają oczy po kolei wzdłuż ściany, raptor z korytarza schodów jako flanka.
- `enlightenment_stacks` / `enlightenment_service_stairs` — ciasny magazyn: wilk w dole, księgi spadają z regałów za strażnikiem.
- `enlightenment_roof_stairs` / `enlightenment_observatory` / `enlightenment_attic` — wspinaczka: przeciwnik schodzi z góry klatki schodowej, drugi dogania z dołu.

**Azja**
- `asia_china` — Budda: zbroja przy wejściu, dzwon Chin bije sam, psy Fu spod posągu (zasadzka) jako nowy typ.
- `asia_porcelain` — wąska sala gablot: zbroja z przodu, pies Fu wpada z drzwi Korei (flanka).
- `asia_korea` — pawilon dzwonu: patrol zbroi, przy `pickup` hwachy straż (zasadzka); dzwon jako kontra.
- `asia_service_stairs` — pies Fu z dołu, zbroja z góry.

**Ameryki**
- `americas_north` — misy ognia: totem widzi w blasku; jaguar flankuje w ciemnej części po zgaszeniu misy.
- `americas_totems` — totem jako wieżyczka na końcu, jaguar z warsztatu jako flanka.
- `americas_moai` — (już: jaguar przy Moai) jaguar z kryjówki za posągiem po 1 padłym.
- `americas_pacific` — wielorybnicy (zasadzka na harpun) jako finał na `pickup`; totem w kontakcie.
- `americas_pit` — dół: jaguar wskakuje z dołu, totem patrzy z krawędzi (wysokość).
- `americas_undercroft` / `americas_service_stairs` — korytarz pod salą: patrol jaguara, drugi zeskakuje z dołu.

**Podziemia**
- `basement_corridor_north` / `_west` / `_east` / `_south` — pierścień: patrol z przodu, „uciekinier” z bocznego magazynu za plecami (flanka w korytarzu).
- `basement_tunnel` — tunel towarowy: zasadzka na końcu jako kontakt, nic z tyłu (oddech).
- `basement_boiler` (+ `basement_boiler_catwalk`) — para z zaworów jako takt (cykl), rycerz z kładki nad strażnikiem; zasadzka bezpiecznika na `pickup`.
- `basement_crossing` — skrzyżowanie: po jednym z każdej odnogi, w odstępach.
- `basement_store_plinths` / `basement_reserve` / `basement_archive` — magazyny: eksponaty pod płachtami budzą się falą od drzwi w głąb.
- `basement_switchboard` — (już: rycerz przy rozdzielni) rycerz po włączeniu prądu (zdarzenie jako wyzwalacz).
- `basement_corridor_spine_w` / `_spine_e` / `basement_corridor_workshop` / `basement_corridor_staff` / `basement_store_guards` — krótkie przejścia: jeden przeciwnik, zapowiedź z sąsiedniej sali.

**Dach i służbowe**
- `roof_catwalks` (+ `roof_plant`, `roof_stairs`) — kładki nad kopułą: patrol w rynnie, popiersie z drugiej kładki (wysokość, wiatr).
- `booth_corridor` / `booth_stairs` / `booth_staff` — bez scenariusza (łagodny początek nocy 1, przystań obok).

## Strojenie dla właściciela (dane w `data/encounters/scenarios.json`)

Wartości startowe w obecnych zakresach gry (zapowiedzi jak u wrogów 0,6–0,9 s, odstępy jak w zasadzkach): `after` (5–9 s), `down` (1–2), `lead` (0,7–0,9 s), `count` (1–2), `from_night` (1), wybór `near`/`far`. Do decyzji właściciela: czy scenariusze od nocy 1 w wzorcowych salach (poza trasą nocy 1 — tak), czy dzwon zbrojowni ma bić sam (zmienia salę: wabi do środka), czy flanka zza drzwi metop nie jest zbyt „nieuczciwa”.

Stałe w kodzie (nie balans, ale do znania): `FloorScenarios.CHECK` 0,2 s (tyk), `UNSEEN` 30 m (dalej niż to przejście obsady „za kadrem” jest niewidoczne), `CUE_DB` −2 dB (głośność zapowiedzi), `ScenarioCatalog.MIN_LEAD` 0,6 s, `MAX_COUNT` 3, odstęp drugiego czekającego w punkcie 1,2 m (`ScenarioCast`).

## Stan prac / co dalej

Stan 23.10, noc (gałąź `encounters`):

- [x] Plan (ten plik).
- [x] Silnik: `ScenarioCatalog` (dane + walidacja z układem piętra: sale istnieją, punkty oczekiwania ≥ 0,6 m od brył wystroju, nie arena / przystań / sekret, jedna sala = jeden scenariusz, zasadzki w salach scenariusza i grane przez takt, punkty w salach albo u sąsiada, dźwięki z `Sfx.SOUNDS`, dzwony z `TempleBell.PLACES`, rodzaje budowalne, `lead` ≥ 0,6 s, `count` 1–3, takt ≥ 1 z `after` / `pickup`), `ScenarioCast` (obsada z ziarna, trzymana w metadanych `NightConfig`), `FloorScenarios` (węzeł w `FloorGame`, `advance()` do testów, `fight_check`, sygnał `beat_played`), `Enemy.held` (+ pomijany w `PerceptionWorld.noise`), `FloorEncounters` pomija zasadzki przejęte tej nocy, `Museum._tune_exhibit` → `FloorScenarios.tune()`; `export_presets.cfg` + `data/encounters/*.json`.
- [x] Trzy wzorce w danych + testy: `tests/unit/test_scenario_cast.gd` (9: plik pasuje do piętra, walidacja odrzuca krótką zapowiedź / tłum / takt bez końca / arenę / przystań / punkt w bryle wystroju, ta sama noc = ta sama obsada, obsada tylko układa wylosowanych — 90 nocy, nic nie dodaje, po 1. takcie tylko śpiący, punkty tylko dla „ruchomych”, przejęta zasadzka = takt, wyłącznik jednym wpisem, `from_night`), `tests/integration/test_floor_scenarios.gd` (9: kolejność kontakt → portyk → flanka i miejsca, flanka zmienia drzwi niewidziana, czekający nie słyszy strzału / trafienie go budzi, zegar stoi z dala i w walce ze strażnikiem, podium jako wyzwalacz, galeria + bezpiecznik, dzwon zbrojowni, wyłączony scenariusz = sala jak dziś, `free()` + odbudowa idzie od następnego taktu).
- [x] Przejście w oknie (`bash tools/agents/with_window.sh bash tools/run_encounters.sh shots`, zrzuty `tests/_out/encounters/`): wszystkie takty grają same w ubranym piętrze; `bash tools/run_encounters.sh dry` — to samo bez okna.
- [x] `git merge pietro-1` ×4 (dostępność, głos G3, pełne przebiegi bota, stojaki audioprzewodnika — jedyny konflikt: `Enemy._on_state_changed`, obie linie zostały). Pełny zestaw jednoprocesowo po każdym scaleniu: 3284/0, 3309/0, 3394/0 i na końcu na `a966af25`: **3413 zielone, 0 błędów, 0 linii ERROR** (25 min 16 s). Dzienniki: `tests/_out/full_suite.log`, `tests/_out/encounters/suite2–4.log`.
- [x] Pełne przejście bota (`bash tools/run_playthrough.sh 1 2 3`, ×4, piętro ubrane, na `8ebc90f9` — scenariusze grają od nocy 1): 3/3 ziarna przechodzą piętro w 1 noc, 0 śmierci, 20/20 kroków (czas gry 15 min 40 s / 13 min 25 s / 14 min 57 s; przed scenariuszami 14 min 02 s / 14 min 16 s / 13 min 26 s — w granicach wariancji bota). `test_playthrough_night1` zielony w każdym zestawie.

**Poprawki po przeglądzie (23.10, 04:15):** takt `pickup` przedmiotu, który strażnik już ma (bezpiecznik to przedmiot kluczowy na zawsze — od nocy 2 nie leży), liczy się jako podniesiony, a walidacja wymaga `after` także w takcie `pickup` (Nimrud: `fuse` ma `after` 40 s) — obsada przy rusztowaniu nie czeka „twardo” całą noc; zapowiedź `fs_armor_guard` działa dla zasadzki przejętej przez scenariusz (`FloorScenarios.ambush_waits`, jedna zmiana w `UncannyDirector._ambush_sleepers`); `down` liczy tylko upadki od poprzedniego taktu, a między taktami jest co najmniej `MIN_GAP` 2 s (podniesienie przedmiotu gra od razu); podniesienie w czasie walki ze strażnikiem / po nocy czeka, aż wolno grać; stado ksiąg tylko jako pierwszy takt; strażnik `museum.night == null`. Testy: +4 (przedmiot już posiadany, zapowiedź przejętej zasadzki, upadek przed taktem nie skleja taktów, takt `pickup` bez `after` odrzucony). Pełny zestaw na `2bf42a38`: **3416/0**, 0 linii ERROR (23 min 51 s; `tests/_out/encounters/suite5.log`).
**Do zrobienia później (przegląd LOW-5/6):** `FlyingBook._can_see_target` i budzenie stada (`BookFlock`) nie znają `Enemy.held` — dziś stado nie trafia do taktów ≥ 1 (reguła w `ScenarioCast`); jeśli kiedyś ma czekać na takt, te ścieżki muszą uszanować `held`. Podobnie każda podklasa z własnym `_can_see_target` lub własnym budzeniem — przejrzeć przed dopuszczeniem jej do taktów ≥ 1.

**Co dalej (kolejne sesje):**
1. Następne sale z listy wyżej — każda to wpis w JSON (bez kodu), zaczynając od tych z zasadzkami do przejęcia (`court_balcony_apex` + dziedziniec od nocy 2, `egypt_sarcophagi` „po kolei”, `assyria_lion_hunt`, `enlightenment_reading`, `asia_buddha`, `americas_whalers`).
2. Wyzwalacze, których silnik jeszcze nie ma (z listy pomysłów): zdarzenie gry (prąd włączony, płyta klątwy, zgaszona misa), „strażnik patrzy gdzie indziej” (takt dopiero, gdy obsada jest poza kadrem), takt w rytmie Regulatora.
3. Gdy właściciel zagra: strojenie `after` / `down` / `lead` / `count` per sala; decyzja, czy scenariusze od nocy 1 (dziś: tak, poza trasą nocy 1).
4. Ewentualnie: pomoc HUD przy pierwszym dzwonie („uderz w dzwon, gdy stoją pod nim”) — dziś kontra jest tylko w mechanice.

## Do sprawdzenia w oknie

Obejrzane 23.10 (zrzuty `tests/_out/encounters/`, latarka włączona):
- Nereidy: hoplita kontaktu staje przed strażnikiem z tarczą; popiersia na portyku czytelne nad balustradą (ostrzał z wysokości widać). Flanka zza drzwi metop — w półmroku przejścia słabo widoczna; ocenić w grze, czy zapowiedź (tarcza + kurz) wystarcza.
- Nimrud: galeria bardzo ciemna (pochodnie 7 m, światło z posadzki) — wojownik na dalekim końcu praktycznie niewidoczny bez latarki (z latarką widać pękający relief i kurz zapowiedzi w nawie); środkowy rząd płyt zasłania oś. **Do decyzji właściciela:** jaśniejszy koniec galerii (pass świateł) albo kontakt z bliższej części (`pick` bez `far`).
- Zbrojownia: ciemno poza latarnią; zbroja kontaktu dobiega szybko i wypełnia kadr; samoczynne bicie dzwonu — sprawdzić ze słuchawkami (dźwięk wyciszony w nocnych przebiegach), czy czyta się jako „coś się zmieniło”.
- Nieobejrzane: dźwięk zapowiedzi (przebiegi bez audio), walka „naprawdę” (strażnik nieśmiertelny, nie strzela), wejście do Nereid od Bassae / metop w grze.
