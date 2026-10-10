# P1 / W1 — integracja rdzenia: Piętro I jako prawdziwa gra (plan wykonawczy)

> **Dla wykonawcy:** zadania po kolei, TDD (najpierw test, potem kod), commit po każdym zadaniu. Kroki z `- [ ]`.
> Plan nadrzędny (wiążący): `docs/superpowers/plans/2026-10-02-p1-fundament.md`, strumień **W1**. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §1, §3, §4, §7.1, §7.2, §9.2, §11, §12.

**Cel:** po tym strumieniu `Museum` gra całe Piętro I w szarości: start w kanciapie, bramy jako zamki w świecie (trwałe), sześć przystani, cel dynamiczny na HUD, karta nazwy sali, manekiny strażników z pieczęciami i odłamkami, finał z astrolabium i T-Reksem, reżyser nocy na strefach (gęstość z powierzchni, 55% po strażniku, łagodny start nocy 1), bronie na znacznikach (strzelba na drodze głównej w Egipcie), CCTV z kamer w centrum, a lobby zostaje poziomem testowym (stare testy bez zmian).

**Architektura (jeden akapit):** `Museum` wybiera poziom przez `static var level_id` (`&"floor1"` w grze, `&"lobby"` w testach — ustawia runner). Wszystko, co dotyczy tylko Piętra I, żyje w nowym katalogu `src/game/floor1/` i jest instalowane jednym wywołaniem `FloorGame.setup(museum)`: kontroler bram (fabryka zamków: klasy z `p1-weapons`, gdy istnieją, inaczej zastępcze `GreyLock`; własne `SealGate` dla pieczęci i zdarzeń), śledzenie sal, cel na HUD, strażnicy (`Guardian` → `GuardianStub`), znajdźki (bronie, bezpieczniki, rozdzielnia), zasadzki, finał, świat (notatki, sekrety, szachy, artefakty, CCTV). `NightDirector` zostaje uogólniony na strefy (gęstość z powierzchni sali, `ALWAYS_SET`, 55% w skrzydle po strażniku, łup wg trudności, bezpieczne drzwi nocy z bramami traktowanymi jak otwarte) — łagodna noc 1 z `p1-ai` (trasa pierwszej przystani do sali bossa) działa na piętrze bez duplikowania: kanciapa → hol → dziedziniec. Percepcja (`p1-ai`, scalona 3.10) wprost: `LevelPerception.configure_layout(...)`, `PerceptionWorld.set_difficulty(0/1/2)`, `Enemy.home_room/patrol_route` (trasy `PatrolSpec` przez `NightSpawner`). Wszystko trwałe idzie przez `GameState` (zapis v2), komunikacja przez `Events`.

> **Zmiana 3.10 (po scaleniu `p1-ai` do `pietro-1`):** zamiast osobnego `FloorDirector` i adaptera `FloorPerception` — uogólnienie `NightDirector`/`NightSpawner` i bezpośrednie API percepcji (polecenie kontrolera). Nazwy w zadaniach 2 i 7 odpowiednio.

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh [--filter=...]` (bez okna, `--fixed-fps 60`).

---

## Zasady scalania (ważne dla kontrolera)

- Równolegle istnieją gałęzie `p1-ai` (percepcja) i `p1-weapons` (zamki, nowe bronie). Obie zmieniają `museum.gd`; `p1-ai` także `night_director.gd`, `night_spawner.gd`, `test_runner.gd`; `p1-weapons` — `hud.gd`, `events.gd`, `strings.csv`.
- W1 **nie dotyka** linii zmienianych przez te gałęzie, gdzie się da: logika piętra w nowych plikach, w `museum.gd` tylko nowe bloki z dala od ich fragmentów, `NightDirector` bez zmian (Piętro I ma `FloorDirector`), `NightSpawner` bez zmian (pola percepcji ustawia `tune` przed wejściem do drzewa).
- Po scaleniu `p1-ai`/`p1-weapons` kroki przełączające opisuje raport końcowy W1 (sekcja „Kroki scalania”).

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/game/museum.gd` (zmiana) | wybór poziomu (`level_id`), `floor_level`, instalacja `FloorGame`, zegar nocy na obu poziomach, przystanie (karta odkrycia), świt/śmierć/wyjście także na piętrze, portrety na dowolnym poziomie, strojenie eksponatów (trudność, pola percepcji) |
| `src/game/night_modifiers.gd` (zmiana) | `apply/set_lights/environment/moons` na dowolnym `Level` z węzłem `lights` |
| `src/game/night_director.gd`, `src/game/night_spawner.gd` (zmiana) | reżyser na strefach: `ALWAYS_SET`, gęstość z powierzchni (`LevelDescription.room_areas/room_zones/zone_density`), skrzydła osłabione (55%), łup wg trudności, drzwi nocy z `always_open`; spawner: trasy `PatrolSpec` |
| `src/level/level_description.gd` (zmiana, zgodna wstecz) | pola stref i `always_open` (bramy/panele liczone jako otwarte przy sprawdzaniu drzwi nocy) |
| `src/game/floor1/floor_game.gd` (nowy) | `FloorGame`: instaluje i łączy moduły piętra; blokada odpoczynku w walce; świt (zamrożenie strażników) |
| `src/game/floor1/gate_locks.gd` (nowy) | `GateLocks`: fabryka zamku dla rodzaju bramy (klasa z `p1-weapons` po nazwie albo rejestr; inaczej `GreyLock`), orientacja i rozmiar na otworze |
| `src/game/floor1/grey_lock.gd` (nowy) | `GreyLock`: zastępczy zamek z kontraktem `GateLock` (gate_id, size, `opened`, `open_instantly()`, `open()`, `blocks_passage()`, `is_open`, `power_on()`), reguły jak `LockRules` (uproszczone) |
| `src/game/floor1/seal_gate.gd` (nowy) | `SealGate`: kamienne wrota z wgłębieniem (SEAL) i krata zdarzenia (EVENT); E z pieczęcią otwiera, bez niej napis `GATE_*` |
| `src/game/floor1/gate_controller.gd` (nowy) | `GateController`: zamek dla każdej `GateSpec`, stan z zapisu, `opened` → `GameState.open_gate` + `level.open_gate` + `Events.gate_opened` + zapis; zasilanie żaluzji |
| `src/game/floor1/switchboard.gd` (nowy) | `Switchboard`: rozdzielnia (E z oboma bezpiecznikami → flaga `power_north`) |
| `src/game/floor1/progress_pickup.gd` (nowy) | `ProgressPickup`: pieczęć, odłamek, bezpiecznik, figura szachowa — trwałe znajdźki z blaskiem |
| `src/game/floor1/floor_pickups.gd` (nowy) | `FloorPickups`: bronie §7.1 na znacznikach, szuflada kasy + szafka z pistoletem, szafka pożarowa, gablota z łańcuchem, bezpieczniki, rozdzielnia; sygnał `taken(marker)` dla zasadzek |
| `src/game/floor1/room_tracker.gd` (nowy) | `RoomTracker`: co 0,25 s sala strażnika → `visit_room` → `Events.room_entered` |
| `src/game/floor1/floor_goal.gd` (nowy) | `FloorGoal`: cel z `ProgressRules.goal`, licznik odłamków, `Events.goal_changed` |
| `src/game/floor1/guardian.gd` (nowy) | `Guardian`: baza prawdziwych strażników (stany, fazy, arena, smycz, sygnały, `Events.guardian_*`) |
| `src/game/floor1/guardian_stub.gd` (nowy) | `GuardianStub`: manekin (cios z zapowiedzią, pociski z zapowiedzią, ruch w fazie 2–3) |
| `src/game/floor1/guardian_keeper.gd` (nowy) | `GuardianKeeper`: stawia strażników, drzwi areny, zaopatrzenie fazy, łupy po zwycięstwie, zapis |
| `src/game/floor1/floor_encounters.gd` (nowy) | `FloorEncounters`: łagodny start (głęboki sen), zasadzki (obszar, znajdźka), patrole i dom eksponatu przez `tune` |
| `src/progression/difficulty_rules.gd` (nowy) | `DifficultyRules`: trudność §7.5 (indeks dla `PerceptionWorld.set_difficulty`, mnożniki obrażeń/zdrowia, skala łupu) |
| `src/game/floor1/floor_finale.gd` (nowy) | `FloorFinale`: astrolabium, kryształ, T-Rex, krata, wyjście, koniec piętra |
| `src/world/world_features.gd` (nowy) | `WorldFeatures`: notatki, sekrety, szachy, artefakty, zatrzaski drzwi nocy, CCTV — z dowolnego układu |
| `src/world/cctv.gd`, `src/world/cctv_catalog.gd` (zmiana) | CCTV na dowolnym poziomie: lista kamer i sala podglądu z zewnątrz; 6 kamer centrum piętra |
| `src/level/floor1/museum_floor_level.gd` (zmiana) | `describe()` z miejscami portretów; `lights`/`doors` jak dotąd |
| `src/ui/hud.gd` (zmiana) | karta sali (kolor strefy), linia odłamków, pasek strażnika z imieniem i tytułem (`Events.guardian_awakened`) |
| `src/ui/demo_end.gd` (zmiana) | tryb „koniec Piętra I” (ukończenie %, sekrety, szachy, czas) |
| `tests/test_runner.gd` (zmiana) | `Museum.level_id = &"lobby"` w `_reset_globals()` |
| `locale/strings.csv` (dopisane na końcu) | klucze `FLOOR_*`, `HUD_ROOM_*`, `PROMPT_SEAL_*`, `SWITCHBOARD_*`, `CHESS_*`, `END_FLOOR1_*`, `NOTE_*` itd. |
| `tests/unit/test_night_director_floor1.gd` | reżyser piętra (czysta logika) |
| `tests/unit/test_floor1_game_locks.gd` | fabryka zamków, `GreyLock`, `SealGate` (bez całego piętra) |
| `tests/integration/test_floor1_game.gd` | noc na piętrze: start, przystanie, cel, karta sali, świt/śmierć/wznowienie |
| `tests/integration/test_floor1_game_gates.gd` | bramy: otwarcie → zapis → następna noc otwarta bez efektów; rozdzielnia |
| `tests/integration/test_floor1_game_guardians.gd` | manekin: walka, łupy, pokonanie zapisane, nie wraca; reset przy ucieczce |
| `tests/integration/test_floor1_game_world.gd` | bronie na znacznikach, zasadzka przy strzelbie, notatki/sekrety/szachy, CCTV |
| `tests/integration/test_floor1_game_flow.gd` | łagodny start (≤ 2 polujących w 30 m przez 60 s), noc od kanciapy do pieczęci (e2e), finał |

---

## Kontrakty W1 (dla innych strumieni)

```gdscript
# Museum
static var level_id: StringName = &"floor1"   # &"lobby" = poziom testowy (runner)
var floor_level: MuseumFloorLevel              # null w lobby
var floor_game: FloorGame                      # null w lobby

# GateLocks — rejestr do wypełnienia przy scalaniu (gdy klasy nie mają class_name):
GateLocks.registry[GateSpec.Kind.CHAIN] = preload("res://src/props/locks/chain_lock.gd")
static func make(kind: GateSpec.Kind) -> Node3D   # obiekt z kontraktem GateLock

# Guardian — baza strażników P3
class_name Guardian extends CharacterBody3D
signal awakened; signal phase_changed(phase: int); signal defeated
var guardian_id: StringName; var plan: Floor1Plan.GuardianPlan; var health: Health
var phase: int; var state: State  # DORMANT, FIGHT, DEFEATED
var arena_room: StringName; var room_of: Callable  # (Vector3) -> StringName
func wake() -> void; func reset_fight() -> void; func take_damage(info: DamageInfo) -> void
func display_name() -> String; func title() -> String
# hooki: _build_body(), _fight_process(delta), _on_phase(phase), _on_reset()

# Hud
func show_room_card(room_name: String, zone_name: String, color: Color) -> void
func set_shards(count: int, total: int) -> void   # count < 0 chowa
```

---

### Zadanie 1: Wybór poziomu i noc na Piętrze I (szkielet gry)

**Pliki:** zmiana `src/game/museum.gd`, `src/game/night_modifiers.gd`, `tests/test_runner.gd`; nowy `src/game/floor1/floor_game.gd`, `src/game/floor1/floor_director.gd` (szkielet: `plan()` = losowanie piętra bez reguł stref); test `tests/integration/test_floor1_game.gd`.

- [ ] **Krok 1 — test (czerwony):** `test_floor1_game.gd::test_a_new_game_starts_in_the_security_booth_of_floor_one` — `Museum.level_id = &"floor1"`, `GameState.new_game()`, instancja `SceneFlow.MUSEUM`; oczekiwane: `museum.level is MuseumFloorLevel`, `museum.lobby == null`, `museum.objective == null`, strażnik w strefie przystani `security` (`haven_zones`), `museum.havens.size() == 6`, 6 terminali, `museum.watch != null` (zegar nocy biegnie), `museum.floor_game != null`.
- [ ] **Krok 2:** `bash tools/run_tests.sh --filter=test_floor1_game` → FAIL (brak `level_id`).
- [ ] **Krok 3 — kod:** `static var level_id := &"floor1"`; `build_level()` → `MuseumFloorLevel.new()` dla `&"floor1"`, inaczej `LobbyLevel.new()`; przed `build()` piętra `gates_open = game.gates_open.duplicate()` i `night`; `NightModifiers.apply()` na `Level` (pomocnik `lights_of(level)`); `NightWatch` poza blokiem lobby; `FloorGame.new().setup(self)` dla piętra; `plan_night()` → `FloorDirector.plan(...)` dla `MuseumFloorLevel`. `tests/test_runner.gd::_reset_globals()` dopisuje `Museum.level_id = &"lobby"`.
- [ ] **Krok 4:** `--filter=test_floor1_game` PASS; `--filter=test_museum` i `--filter=test_night` PASS (lobby bez zmian).
- [ ] **Krok 5:** commit „Museum plays Floor I (level_id; lobby stays the test level)”.

### Zadanie 2: `NightDirector` na strefach

**Pliki:** `src/game/night_director.gd`, `src/level/level_description.gd`, `src/level/floor1/museum_floor_level.gd` (`describe()`); test `tests/unit/test_night_director_floor1.gd`.

> Po scaleniu `p1-ai` sygnatury poniżej zrealizowane jako `NightDirector.plan(seed, night, level, weakened_zones := [], loot_scale := 1.0)`; dane stref w `LevelDescription` (wypełnia `MuseumFloorLevel.describe()`).

```gdscript
class_name FloorDirector
const DENSITY := {&"court": 0.6, &"entrance": 0.8, &"booth": 0.0, &"north_hall": 0.8, &"egypt": 1.0, &"assyria": 1.0,
		&"greece": 0.9, &"enlightenment": 1.0, &"asia": 1.0, &"americas": 1.1, &"basement": 0.7, &"roof": 0.4}
const WEAKENED_KEEP := 0.55
const GENTLE_AWAKE := 2
const GENTLE_TIME := 180.0
static func plan(night_seed: int, night: int, layout: LevelLayout, progress: FloorProgress = null,
		difficulty: StringName = &"night", known_havens: Array[StringName] = []) -> NightConfig
static func describe(layout: LevelLayout) -> LevelDescription      # + portrait_spots
static func room_cap(room: RoomSpec) -> int                         # max(1, round(area * DENSITY / 100))
static func gentle_rooms(description: LevelDescription) -> Array[StringName]   # kanciapa → … → dziedziniec
static func safe_doors(layout: LevelLayout, description: LevelDescription, progress: FloorProgress, havens: Array[StringName]) -> Array[StringName]
```

- [ ] **Krok 1 — testy (czerwone):** determinizm (`to_dict()` równe dla tego samego ziarna; różne dla innego), `ALWAYS_SET` zawsze stoi, gęstość (żadna sala ponad `room_cap` z losowanych zestawów), skrzydło z pokonanym strażnikiem ma 45–65% eksponatów nocy bez strażnika (średnio z 20 ziaren, liczone na tym samym układzie), łagodna noc 1 (sale `gentle_rooms` bez wilków i raptorów, ≤ 2 nieśpiące), noc 2+ bez reguły łagodnej, `safe_doors` nie zawiera bramy ani mostu w grafie sal (układ syntetyczny z korytarzem jedynej drogi i pętlą), trudność `calm` daje więcej łupu niż `double` (suma z 20 ziaren).
- [ ] **Krok 2:** `--filter=test_night_director_floor1` → FAIL.
- [ ] **Krok 3 — kod:** kolejność losowań: modyfikator → drzwi nocy → zestawy (zestaw sali, przycięcie do gęstości tasowaniem, `ALWAYS_SET`) → spokojna noc → osłabione skrzydła → łup (`NightDirector._loot`) z trudnością → portrety (`NightDirector._portraits`) → łagodna noc 1 (bez losowania).
- [ ] **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 3: Bramy w świecie

**Pliki:** `gate_locks.gd`, `grey_lock.gd`, `seal_gate.gd`, `gate_controller.gd`, `switchboard.gd`; testy `tests/unit/test_floor1_game_locks.gd`, `tests/integration/test_floor1_game_gates.gd`.

Reguły: zamek stoi na podłodze w środku otworu (`LevelBuilder.passage_frame`), przód (−Z) do pokoju A (BOLT: tył +Z do `one_way_side`), `size` = szerokość × wysokość otworu; brama na znaczniku (gablota kartaczownicy) → `ChainedDisplay` z `FloorPickups` jest jej zamkiem. Gdy zamek ma własne ciało (`blocks_passage()`), drzwi z greyboksu zostają (nawigacja, kolizja), ale niewidoczne. Brama otwarta w zapisie: `level.gates_open` przed `build()` + `open_instantly()`. `opened` → `GameState.open_gate(id)` → `level.open_gate(id)` → `Events.gate_opened.emit(id)` → `NightRules.save_progress`.

- [ ] **Krok 1 — testy (czerwone):** jednostkowe: fabryka zwraca obiekt z kontraktem dla każdego rodzaju (bez `p1-weapons`: `GreyLock`), `open_instantly()` nie emituje `opened`, `GreyLock` CHAIN pęka od 25 obr. strzelby w 0,4 s i od 3 pięści, BOARDS od wybuchu, ROPE od pistoletu z ≤ 15 m (dalej nie), BOLT tylko od strony zasuwy, POWER od `power_on()`; `SealGate`: bez pieczęci napis z `label_key`, z pieczęcią E otwiera. Integracyjne: wszystkie 24 bramy mają zamek; zamknięte drzwi bramy zablokowane; `boards_staff_stairs` rozbite pięściami → zapis ma bramę, `Events.gate_opened`, następna noc (nowe `Museum`) ma drzwi otwarte i zamek otwarty bez sygnału; rozdzielnia z dwoma bezpiecznikami otwiera obie żaluzje.
- [ ] **Krok 2:** FAIL. **Krok 3:** kod. **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 4: Sale, cel, przystanie, HUD

**Pliki:** `room_tracker.gd`, `floor_goal.gd`, zmiany `hud.gd`, `museum.gd` (odkrycie przystani); testy w `test_floor1_game.gd`.

- [ ] **Krok 1 — testy:** wejście do holu → `GameState.rooms_visited` ma `entrance_hall`, `Events.room_entered(…, &"entrance", true)`, karta sali z `ROOM_ENTRANCE_HALL`; drugie wejście bez karty; cel nowej gry = `tr("GOAL_TICKET_KEY")`, po kluczu z kasy → `GOAL_PISTOL` i `Events.goal_changed`; licznik odłamków po pierwszym odłamku `GOAL_SHARDS`; przystań konserwatora: wejście → znana, start następnej nocy przed jej terminalem, karta odkrycia z `HAVEN_CONSERVATOR`.
- [ ] **Kroki 2–5** jak wyżej (commit).

### Zadanie 5: Strażnicy (baza + manekin)

**Pliki:** `guardian.gd`, `guardian_stub.gd`, `guardian_keeper.gd`, `progress_pickup.gd`; test `tests/integration/test_floor1_game_guardians.gd`.

Manekin: 4,5 m, 900 HP, faza 2 < 66%, faza 3 < 33%; cios (zapowiedź 0,8 s: czerwony krąg na posadzce, potem 28 obr. w 4 m), salwa (zapowiedź 0,9 s: świecące dłonie, 3 wolne pociski `Projectile`), od fazy 2 kroczy do strażnika (wolno), zapowiedzi szybsze w fazie 3 (nigdy < 0,6 s). Budzi się, gdy strażnik wejdzie do sali areny; drzwi areny (`arena_<id>_door_<n>` → najbliższe `Door` do 3 m) zamykane na czas walki; strażnik poza areną 6 s → manekin wraca na znacznik z pełnym zdrowiem, drzwi się otwierają. Zaopatrzenie każdej fazy raz na noc (`RunState.used`). Pokonanie: `GameState.defeat_guardian`, `Events.guardian_defeated`, pieczęć i odłamek (`ProgressPickup`) w miejscu upadku, 60 Pyłu, zapis; pokonany nie wraca (następna noc bez manekina).

- [ ] **Krok 1 — testy:** manekin Kolosa stoi na `guardian_colossus`; wejście do Sali Kolosa → `Events.guardian_awakened` i pasek z `GUARDIAN_COLOSSUS`/`GUARDIAN_COLOSSUS_TITLE`; ciosy mają zapowiedź ≥ 0,6 s (pomiar od początku zapowiedzi do obrażeń); pokonanie → zapis (`guardians_defeated`), łupy leżą; podniesienie → `seals` ma `seal_sun`, `shards` ma `shard_egypt`, `Events.shard_collected(…, 1)`; następna noc: brak manekina; ucieczka z areny → reset zdrowia.
- [ ] **Kroki 2–5** (commit).

### Zadanie 6: Bronie i znajdźki na znacznikach, zasadzki

**Pliki:** `floor_pickups.gd`, `floor_encounters.gd` (zasadzki), zmiana `museum.gd` (`_tune_exhibit`); test `test_floor1_game_world.gd`.

- [ ] **Krok 1 — testy:** nowa gra: strzelba (`WeaponPickup` `shotgun`) przy `weapon_shotgun` w `egypt_gallery`; szuflada kasy przy `ticket_drawer`, szafka z pistoletem przy `pistol_locker`, szafka pożarowa przy `flare_cabinet`, gablota kartaczownicy przy `gatling_case`; broń nieznana `Loadout` (np. `rifle_hunt` bez `p1-weapons`) nie stoi, ostrzeżenie raz; broń posiadana nie leży; podniesienie strzelby budzi sloty zasadzki `egypt_camp`; bezpiecznik z kotłowni → `items` + zapis.
- [ ] **Kroki 2–5** (commit).

### Zadanie 7: Eksponaty piętra: łagodny start, patrole, percepcja, trudność, portrety

**Pliki:** `floor_encounters.gd`, `floor_perception.gd`, zmiany `museum.gd` (`_tune_exhibit`, `_hang_paintings`); test `test_floor1_game_flow.gd`.

- [ ] **Krok 1 — testy:** łagodny start: noc 1, strażnik wychodzi z kanciapy i idzie przez hol na dziedziniec przez 60 s → w promieniu 30 m nigdy > 2 nieśpiących; śpiący na trasie mają obniżony wzrok do końca `GENTLE_TIME`, potem przywrócony; noc 2 bez tego; eksponat ze slotu z `patrol` dostaje trasę (gdy `Enemy` ma pole `patrol_route`; bez `p1-ai` — meta `floor_patrol`); trudność `double` → zdrowie ×1,2 i obrażenia ×1,35.
- [ ] **Kroki 2–5** (commit).

### Zadanie 8: Świat piętra (notatki, sekrety, szachy, artefakty, CCTV)

**Pliki:** `src/world/world_features.gd`, zmiany `src/world/cctv.gd`, `cctv_catalog.gd`; test `test_floor1_game_world.gd`.

- [ ] **Krok 1 — testy:** notatka Heńka (`note_heniek` → `note_key`) leży w kanciapie; znacznik `secret_*` przy panelu otwiera panel i zapisuje sekret; bez panelu — skrytka; figura `chess_*` → `chess_found` + zapis, następnej nocy jej nie ma; CCTV ma 6 kamer na piętrze, ekran ożywa w `booth_security`; lobby: dotychczasowe testy CCTV zielone.
- [ ] **Kroki 2–5** (commit).

### Zadanie 9: Finał (astrolabium → kryształ → T-Rex → krata → krypta → koniec piętra)

**Pliki:** `floor_finale.gd`, zmiana `demo_end.gd`; test `test_floor1_game_flow.gd`.

- [ ] **Krok 1 — testy:** z 6 odłamkami E na astrolabium → flaga `astrolabe`, kryształ pulsuje; strażnik w 3 m → lot do T-Reksa (`trex_pedestal`), boss się budzi; zabity → `guardians_defeated` ma `trex`, krata `grate_crypt` otwarta i zapisana, strefa wyjścia przy `floor1_exit` uzbrojona → wejście: flaga `floor1_complete`, `demo_end_requested`; ekran końca pokazuje tryb Piętra I; noc epilogu: krata otwarta, bez bossa.
- [ ] **Kroki 2–5** (commit).

### Zadanie 10: Noc od kanciapy do pieczęci (e2e) i reguły nocy na piętrze

**Pliki:** `test_floor1_game_flow.gd`, `test_floor1_game.gd`.

- [ ] **Krok 1 — testy:** e2e: kanciapa → kasa (klucz) → szafka (pistolet) → dziedziniec → Egipt (strzelba) → manekin Kolosa (obrażenia przez API) → pieczęć → E na Bramie Chorsabadu → brama otwarta, zapis, `Events.gate_opened`; śmierć na piętrze: latarka z Pyłem, noc+1, postęp zostaje; świt: noc+1, przystań startowa bez zmian; „Kontynuuj”: zabite sloty i zabrany łup nie wracają.
- [ ] **Krok 2:** pełny zestaw `bash tools/run_tests.sh` zielony. **Krok 3:** commit, raport.

---

## Samokontrola planu

- Pokrycie W1 z planu nadrzędnego: wybór poziomu (Z1), bramy (Z3), przystanie (Z1, Z4), HUD (Z4, Z5), manekin (Z5), reżyser (Z2, Z7), percepcja (Z7), łup i bronie (Z6), CCTV/notatki/sekrety (Z8), finał (Z9), testy akceptacji (Z10). Plan muzeum na ścianie (`museum_map_*`) czeka na W6 — `FloorGame` ma punkt podpięcia (`MuseumMap.poster`, jeśli klasa istnieje).
- Nazwy: `floor_level`, `floor_game`, `FloorDirector.plan/gentle_rooms/safe_doors`, `GateLocks.make/registry`, `Guardian.*` — spójne we wszystkich zadaniach.

---

## Stan wykonania (3.10)

Zadania 1–10 wykonane; po drodze scalone `pietro-1` trzy razy (percepcja `p1-ai`, dźwięk skrzydeł, W3 Egipt i Grecja, W2 centrum) i spełnione prośby W2/W3. Zestaw: **1305+ testów zielonych** (bez linii `ERROR`).

**Odstępstwa od planu (świadome):**
1. Zamiast osobnego `FloorDirector` — `NightDirector` uogólniony (`ALWAYS_SET`, gęstość z `LevelDescription.room_areas/room_zones/zone_density`, skrzydła osłabione, łup wg trudności, `always_open` + `cuts_off()` dla drzwi nocy), a `FloorNight` dokłada to, co wie zapis. Łagodna noc 1 z `p1-ai` działa na piętrze bez drugiej implementacji (trasa `booth_corridor → entrance_hall → court`; pomiar: najwyżej 2 polujących w 30 m przez 60 s).
2. Percepcja wprost (bez adaptera): `LevelPerception.configure_layout(...)`, `PerceptionWorld.set_difficulty(DifficultyRules.index(...))`, trasy `PatrolSpec` przez `tune` (spawner zachowuje trasę ustawioną przez `tune`).
3. Strażnik nie dziedziczy po `Enemy` (jak T-Rex): własna klasa `Guardian` (stany, fazy, smycz areny, zapowiedzi ≥ 0,6 s), bo prawdziwi strażnicy (siedzący Kolos, nieruchome Planetarium, segmentowy Wąż) nie pasują do maszyny eksponatu.
4. Sekret w sekretnej sali liczy się po wejściu do jej sali (prośba W3); poza sekretną salą — fałszywy panel albo luźny kamień (`SecretCache`).
5. Drzwi aren bez `Door` (dziedziniec) — `ArenaGrille` opuszczana w otworze (prośba W2).
6. Nowa grupa świateł `LightSpec.MOON` (`moon_lights`): nigdy nie gaśnie, pełnia ją rozjaśnia; w strefach W2 zmieniona jedna linia (`hub_kit.gd`: `MOON_GROUP := LightSpec.MOON`).

**Kroki scalania z `p1-weapons` (dla kontrolera):**
- `museum.gd`: konflikt w stałych `LOOT_*`/`AMMO_WEAPONS` — wziąć wersję `p1-weapons` (W1 ich nie zmieniał).
- `strings.csv`: zostawić oba bloki końcowe. `hud.gd`, `events.gd`: zmiany rozłączne (W1 dopisał na końcu `hud.gd`; `Events.hint_requested` używane przez `has_signal`, więc zadziała samo).
- Zamki: `GateLocks` znajduje `ChainLock`, `BoardsLock`, `CrackedWall`, `RopeLock`, `HookLock`, `BoltLock`, `PowerShutter` po `class_name` — nic nie trzeba przełączać; sprawdzić `test_floor1_game_locks` i `test_floor1_game_gates`. `RopeLock` stoi 1,5 m przed otworem po stronie A z domyślną wysokością 6 m (lina `rope_roof_hatch` na podeście y = 6 — do strojenia). Gablota kartaczownicy: `ChainedDisplay` przyjęty jako zamek `chain_gatling` (`GateController.adopt`).
- Nowe bronie: `FloorPickups` położy `rifle_hunt`, `harpoon`, `hwacha` na ich znacznikach, gdy `Loadout.WEAPON_PATHS` je zna.

---

## Runda 2 (3.10, gałąź `p1-integ2`)

1. **Most z czółna:** prawdziwy `HookLock` (SWING) na `hook_canoe` — długość z geometrii szczeliny (`GateController.gap_span`: 6,5 m), płyta `canoe_bridge` pomijana przy budowie (`GateLocks.STAND_INS` → `MuseumFloorLevel.skip_kits`), pokład 2,2 m jako źródło nawigacji (`add_walk_source`); świątynia nieosiągalna przed harpunem, osiągalna po.
2. **Znaczniki stref:** strażnik dostaje swoje punkty (`<id>_<nazwa>_<n>` → `Guardian.points`): wojownicy z `lamassu_relief_*` w fazie 2 Lamassu (raz na noc), atrapa Węża sunie po `serpent_path_*`; kraty na `arena_*_door_*` zwrócone do areny; **bez snajperki**: trafienie spoza sali areny nic nie robi i nie budzi.
3. **Wskazówki pierwszej nocy na Piętrze I** (latarka, E, droga do broni). 4. **Trudność w UI** (Nowa gra pyta, opcje pokazują; w nocy wzrok od razu, reszta od następnej).
5. **Nawigacja w kafelkach 32 m** zamiast brył stref (bryły zostawiają ściany między strefami, z przejściami, poza każdą bryłą): jeden parse statycznych kolizji, drzwi i źródła zmienne parsowane przy każdym wypiekaniu, kafelki pieczone równolegle z odcinanym brzegiem 1,5 m (krawędzie się spotykają). Pełne wypiekanie 260–310 → 70–110 ms; brama przebudowuje 1 kafelek (13 ms, poza wątkiem głównym). Zapytania o ścieżkę: domyślny limit serwera 4096 wielokątów < ~5300 piętra — eksponaty 12000, testy bez limitu.
6. **Start nocy:** wyrzeźbiona skorupa w pamięci podręcznej na dysku (`ShellCache`, klucz = hash brył; wysyłane w `data/shell_cache` przez `tools/bake_shell_cache.sh`, własne obok zapisu), ekran ładowania z numerem nocy i `TIP_n`. Zimny start 6,3–7,1 → 2,8 s; kolejna noc 1,4–1,6 → 0,9 s. **Po zmianie sal/otworów uruchomić `tools/bake_shell_cache.sh`** (nieaktualna pamięć kosztuje tylko pierwszą noc, nigdy złej skorupy).
7. Dodatki koordynatora: grupa `LightSpec.FLICKER` (mrugają, gasną w blackoucie), CCTV: centrum najpierw na ścianie, wszystkie kamery w konsoli (strony po 6), lista notatek w pauzie (przewijana, wg skrzydeł, z podpisem), szersze kartki zamiast drobnego pisma.
