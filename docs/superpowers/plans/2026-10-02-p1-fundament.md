# P1 „Fundament” — kontrakty, szkielet piętra i plan dla budowniczych równoległych

> Plan wykonawczy etapu P1 Piętra I. Część A (ten dokument opisuje jej wynik) wykonał architekt na gałęzi `p1-core`; część B wykonuje ok. 6 budowniczych **równolegle**, każdy w swoim drzewie roboczym i na swoich plikach.
> Projekt nadrzędny: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§3, §4, §5, §7.2, §9.1, §11–§13). Stan gry przed etapem: `docs/Nocna-Zmiana-specyfikacja.md` (§5, §7, §10).
> Równolegle (gotowe lub w toku, **nie ruszać**): `p1-ai` — percepcja i terytoria eksponatów (`PerceptionWorld`), `p1-weapons` — sztucer, harpunnik, ognista skrzynia i zamki-bramy (`GateLock`).

**Cel:** stare lobby (88 × 100 m) staje się całym piętrem muzeum (ok. 177 × 139 m): Wielki Dziedziniec z Czytelnią, hol wejściowy, kanciapa, sześć skrzydeł, korytarz północny z kryptą, podziemia (y = −6) i kładki na dachu (y = 22,5). Po P1 całe piętro jest **grywalne w szarości** (greybox w kolorach skrzydeł): prawdziwe przejścia i bramy, trwały postęp metroidvanii, cel na HUD, plan muzeum, sześć przystani, uogólniony reżyser nocy, manekiny strażników, test osiągalności i bot mierzący czas.

**Architektura (w jednym akapicie):** `Floor1Plan` (czyste stałe) definiuje strefy jako rozłączne bryły 3D, przejścia między strefami (*junctions*), obszary postępu, bramy, przystanie, strażników i znajdźki postępu. Każda strefa ma moduł `src/level/floor1/zones/<strefa>.gd` ze `static func build(layout)`, który buduje **tylko w swoich bryłach** i stawia pokój przy swojej stronie każdego przejścia. `Floor1Layout.create()` woła moduły, a potem sam dodaje otwory przejść i ich bramy (pokoje po obu stronach znajduje sam). `MuseumFloorLevel` (kontrakt `Level`) buduje to `LevelBuilder`-em i wypieka nawigację. Postęp żyje w `GameState` (zapis v2 z migracją); `ProgressRules` (czysta logika na grafie obszarów) mówi, co jest osiągalne, jaki jest następny cel i czy stan nie jest blokadą. Moduły rozmawiają przez `Events`.

```
GameState (v2) ──► FloorProgress.from_game() ──► ProgressRules ─► cel HUD/plan, strażnicy w zasięgu, blokady
                                                     ▲
Floor1Plan ── strefy, przejścia, obszary, bramy, przystanie, strażnicy, znajdźki
   │
   ├─► zones/<strefa>.gd ──► Floor1Layout.create() ──► LevelLayout (+ gates, patrols, ambushes)
   │                                                         │
   │                                   MuseumFloorLevel ◄────┘  LevelBuilder (greybox), drzwi, bramy,
   │                                                            nawigacja, opis dla NightDirector
   └─► testy: test_floor1_plan, test_floor1_layout, test_museum_floor_level, test_progress_rules
```

## Konwencje (obowiązują wszystkich)

- Godot 4.7.2 (`tools/godot` = połączenie katalogów do głównej kopii; **nigdy go nie usuwać ani nie zmieniać**). Testy: `bash tools/run_tests.sh [--filter=nazwa]` (bez okna, `--fixed-fps 60`; pierwszy przebieg w świeżym drzewie importuje zasoby kilka minut). Przebieg jest nieudany przy porażce testu **albo** linii `ERROR`. Przy iteracji używaj `--filter`; pełny zestaw raz na koniec zadania (maszyna jest współdzielona).
- **Tylko bez okna i bez dźwięku.** Pracujemy wyłącznie w `D:/ClaudeCode/Doomer Shooter`.
- GDScript ze statycznym typowaniem, **tabulatory**, identyfikatory i komentarze po angielsku, teksty dla gracza przez `tr()` z kluczami w `locale/strings.csv` (`keys,pl,en`; **nowe wiersze tylko na końcu pliku**, nigdy przestawiać; porządny polski z ogonkami i porządny angielski). Konflikty przy scalaniu na końcu pliku rozwiązuje integrator, zostawiając oba bloki.
- Węzły z kodu (`.tscn` = korzeń + skrypt), czysta logika w `RefCounted`/statycznych klasach testowanych bez sceny, komunikacja przez `Events`. Transformacja i statystyki eksponatu ustawiane **przed** `add_child`.
- Commit po każdym zadaniu, ostatnia linia wiadomości: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Dodawaj tylko własne pliki (nigdy `git add -A`), razem z ich `.uid`.
- **Własność plików jest rozłączna** (tabele niżej). `floor1_plan.gd` zmienia tylko kontroler: gdy budowniczy potrzebuje przesunąć przejście albo dodać bramę, opisuje to w raporcie końcowym (albo prosi kontrolera w trakcie), a nie edytuje planu sam.
- Klasa wewnętrzna nie może nazywać się jak klasa globalna (`Haven`, `Pickup` już istnieją) — stąd `HavenPlan`, `PickupPlan` itd. W modułach stref skrót do pomocnika: `const Grey := preload("res://src/level/floor1/floor1_greybox.gd")` (stała z `class_name` nie jest wyrażeniem stałym).

---

## Część A — co jest gotowe (gałąź `p1-core`)

| Commit | Zawartość |
|---|---|
| `932e80b` | kontrakty układu: `GateSpec`, `PatrolSpec`, `AmbushSpec`; `RoomSpec.zone / zone_area / name_key / public`; `SpawnSlot.zone / patrol / ALWAYS_SET` |
| `67a775d` | `Floor1Plan`, `Floor1Greybox`, 12 modułów stref (greybox), `Floor1Layout`, `MuseumFloorLevel`, 116 kluczy tłumaczeń, testy planu, układu i poziomu |
| `4b3edb0` | `GameState` v2: trwały postęp Piętra I + migracja zapisu z lobby |
| `503d08c` | `FloorProgress`, `ProgressRules` (graf obszarów, bramy, kroki, cel, strażnicy, blokady) |
| `746279d` | pomiary budowy i wypiekania w raporcie testu |
| (ten plik) | plan części B |

### Mapa plików części A

| Plik | Odpowiada za |
|---|---|
| `src/level/floor1/floor1_plan.gd` | `Floor1Plan`: strefy (bryły 3D), wysokości, kolory i nazwy stref, obszary, 22 przejścia, 24 bramy, 6 przystani, 6 strażników, 12 znajdziek postępu, pomocnicze `zone_at`, `contains`, `junctions_of`… |
| `src/level/floor1/floor1_greybox.gd` | `Floor1Greybox`: `r()`, `room()`, `box()`, `door()`, `stairwell()` (prosta klatka schodowa), `tower()` (wieża schodów zabiegowych), `top_landing_rect()`, `lamp()` |
| `src/level/floor1/zones/*.gd` | moduł każdej strefy (część A: minimalny greybox; część B: właściwy układ) |
| `src/level/floor1/floor1_layout.gd` | `Floor1Layout.create()`, `build_zone()`, `add_junctions()`, `junction_room()`, `describe()`, `rooms_of_area()`, `rooms_of_zone()`, `problems` |
| `src/level/floor1/museum_floor_level.gd` | `MuseumFloorLevel extends Level` |
| `src/level/layout/gate_spec.gd`, `patrol_spec.gd`, `ambush_spec.gd` | nowe dane układu |
| `src/level/layout/room_spec.gd`, `src/level/spawn_slot.gd`, `src/level/level_layout.gd` | rozszerzenia (zgodne wstecz z lobby) |
| `src/state/game_state.gd` | pola postępu, `VERSION = 2`, `_migrate()` |
| `src/progression/floor_progress.gd`, `progress_rules.gd` | `FloorProgress`, `ProgressRules` |
| `tests/unit/test_floor1_plan.gd`, `test_floor1_layout.gd`, `test_game_state_floor1.gd`, `test_progress_rules.gd`; `tests/integration/test_museum_floor_level.gd` | testy (raport czasu: `tests/_out/floor1_build.json`) |

### Pomiary szkieletu (bez okna, greybox, RTX 2080 Ti nieistotna)

| Pomiar | Wynik |
|---|---|
| `Floor1Layout.create()` | **ok. 5 ms** |
| rzeźbienie skorupy (`ShellCarver`, zimne) | **2,4–2,7 s** (729 brył; siatka 0,5 m na całym prostokącie 177 × 139 m) |
| `MuseumFloorLevel.build()` bez nawigacji | **2,3–3,6 s** (≈ 90% to rzeźbienie; drugie i kolejne budowanie w tym samym procesie bierze skorupę z pamięci podręcznej `ShellCarver` → ok. 0,3 s) |
| wypiekanie nawigacji (jeden region + przystanie) | **0,13–0,22 s**; 991 wielokątów, 973 wierzchołki |
| układ | 54 pokoje, 67 otworów (22 przejścia stref), 18 biegów schodów, 24 bramy, 44 punkty spawnu, 34 punkty łupu, 22 elementy |
| łączność | z holu wejściowego dochodzi się pieszo (siatka, wszystkie bramy otwarte) do **każdego** z 48 pokoi poza przystaniami; przez każde przejście w obie strony |

**Wniosek dla nawigacji (§11.3):** w części A jest jeden region chodzenia + region przystani, jak w lobby — wypiekanie całego szkieletu jest tanie. Plan na część B (W1): gdy oprawa i elementy podniosą koszt wypiekania (budżet: ≤ 1 s na całe piętro przy starcie nocy, ≤ 0,2 s na przebudowę po bramie), przejść na **region na bryłę strefy**: jedno `NavigationServer3D.parse_source_geometry_data()` z całego `walk_root`, potem dla każdej bryły `bake_from_source_geometry_data()` z `filter_baking_aabb` = bryła i `border_size = agent_radius` (krawędzie kafli się zgadzają, regiony łączy `edge_connection_margin`); otwarcie bramy przebudowuje tylko dwie strefy przejścia. Rzeźbienie (2,4 s) można zapisać do pliku przy eksporcie (suma kontrolna układu) albo liczyć raz na proces — dziś `ShellCarver` trzyma wynik w statycznej pamięci, więc każda kolejna noc jest szybka.

---

## Mapa Piętra I (wiążąca; doprecyzowanie §4.1)

Metry, Y w górę, −Z = północ, początek w środku Wielkiego Dziedzińca. Parter y = 0, podziemia y = −6, dach y = 22,5, podest holu y = 6. Między sąsiednimi strefami jest **ściana 1 m**; otwór przejścia wypełnia ją dokładnie.

### Strefy (bryły; x0, z0 → x1, z1; zakres y)

| Strefa | Bryły | Uwagi i zmiany względem §4.1 |
|---|---|---|
| `court` | −30, −30 → 30, 30; y −0,5…22,5 | bez zmian; ponad 22,5 jest dach |
| `entrance` | −16, 31 → 16, 53; y −0,5…32 | przesunięty o 1 m (ściana z dziedzińcem) |
| `booth` | 17, 36 → 38, 48; y −6,5…4 | ponad nim (y ≥ 4) wieża schodów dachu |
| `north_hall` | −30, −38 → 30, −31 (y −0,5…32); **krypta** −3, −70 → 3, −39 (y −14…32) | korytarz tylko na szerokość dziedzińca; krata prowadzi na północ, w pas między Amerykami a Azją, schodami w dół do krypty |
| `egypt` | −55, −38 → −31, 30 (y −0,5…32) + to samo pod spodem do y −6,5 **bez** tunelu podziemi (z −37…−33); −63, 0 → −55, 30 (y −6,5…32) | szerokość 24 m: galeria 16 m + pas grobowców; Sala Kolosa na północnym końcu; z −36 → −38 (rozłączne z Asyrią i korytarzem) |
| `assyria` | −112, −39 → −56, −3; −112, −86 → −47, −39; y −6,5…32 | kształt L; Brama Chorsabadu w północnej ścianie Sali Kolosa |
| `greece` | −112, −2 → −64, 53; **−64, 31 → −17, 53** (Galeria Partenonu wzdłuż południowej strony Egiptu, aż do holu); y −6,5…32 | skrót do holu na podeście y = 6 |
| `enlightenment` | 31, −38 → 65, 34; y −6,5…32 | Planetarium na północy (styk z Azją), wieża schodów na dach przy ścianie dziedzińca |
| `americas` | −46, −86 → −4, −39; y −6,5…32 | |
| `asia` | 4, −86 → 56, −39; y −6,5…32 | rozszerzona do x = 56 (styk z Planetarium) |
| `basement` | −30, −38 → 30, 30; −16, 30 → 16, 53; **tunel** −55, −37 → −30, −33; y −6,5…−0,5 | pod dziedzińcem, korytarzem, holem; tunel pod Salą Kolosa do Asyrii |
| `roof` | −30, −30 → 30, 30 (y 22,5…32); 17, 30 → 30, 36 (y 4…32); 17, 36 → 38, 53 (y 4…32) | kładki nad szklanym dachem + wieża schodów nad kanciapą |

Między bryłami są puste pasy (mur): nikt tam nie buduje. Zasięg całości: 177 × 139 m.

### Przejścia (otwór = cała grubość muru; budowniczy obu stron stawia pokój tuż przy nim)

| Id | Strefy (A ↔ B) | Otwór (x0, z0 → x1, z1) | y podłogi | Wys. | Brama |
|---|---|---|---|---|---|
| `j_court_entrance` | court ↔ entrance | −4, 30 → 4, 31 | 0 | 8 | — |
| `j_court_egypt` | court ↔ egypt | −31, 20 → −30, 26 | 0 | 7 | — |
| `j_court_enlightenment` | court ↔ enlightenment | 30, −3 → 31, 3 | 0 | 7 | — |
| `j_court_north` | court ↔ north_hall | −4, −31 → 4, −30 | 0 | 8 | `gate_north` (pieczęć: Klucz Gwiazd) |
| `j_entrance_booth` | entrance ↔ booth | 16, 41 → 17, 43 | 0 | 2,6 | — |
| `j_entrance_greece` | entrance ↔ greece | −17, 50 → −16, 52 | **6** | 2,6 | `bolt_greece_entrance` (zasuwa od Grecji) |
| `j_entrance_roof` | entrance ↔ roof | 16, 50 → 17, 52 | **6** | 2,6 | `rope_roof_hatch` (lina: pistolet z ≤ 15 m lub sztucer) |
| `j_egypt_greece` | egypt ↔ greece | −64, 10 → −63, 14 | 0 | 3,5 | `boards_tomb` (deski) |
| `j_egypt_assyria` | egypt ↔ assyria | −54, −39 → −48, −38 | 0 | 8 | `seal_khorsabad` (Pieczęć Słońca) |
| `j_assyria_americas` | assyria ↔ americas | −47, −66 → −46, −62 | 0 | 5 | `seal_balawat` (Pieczęć Skrzydła) |
| `j_assyria_greece` | assyria ↔ greece | −90, −3 → −87, −2 | 0 | 3 | `bolt_lions_bassae` (zasuwa od Asyrii) |
| `j_north_americas` | north_hall ↔ americas | −20, −39 → −14, −38 | 0 | 5 | `shutter_americas` (zasilanie) |
| `j_north_asia` | north_hall ↔ asia | 14, −39 → 20, −38 | 0 | 5 | `shutter_asia` (zasilanie) |
| `j_asia_enlightenment` | asia ↔ enlightenment (obszar `planetarium`) | 48, −39 → 52, −38 | 0 | 3 | `bolt_asia_planetarium` (zasuwa od Azji) |
| `j_booth_basement` | booth ↔ basement | 16, 37 → 17, 39 | **−6** | 2,6 | `boards_staff_stairs` (deski „REMONT”) |
| `j_basement_egypt` | basement ↔ egypt | −31, −12,5 → −30, −10,5 | −6 | 2,6 | `bolt_basement_egypt` (od Egiptu) |
| `j_basement_assyria` | basement ↔ assyria | −56, −36,5 → −55, −34,5 | −6 | 2,6 | `bolt_basement_assyria` (od Asyrii; winda towarowa później) |
| `j_basement_greece` | basement ↔ greece | −28, 30 → −26, 31 | −6 | 2,6 | `bolt_basement_greece` (od Grecji) |
| `j_basement_enlightenment` | basement ↔ enlightenment | 30, 28 → 31, 30 | −6 | 2,6 | `bolt_basement_enlightenment` (od Oświecenia) |
| `j_basement_americas` | basement ↔ americas | −28, −39 → −26, −38 | −6 | 2,6 | `bolt_basement_americas` (od Ameryk) |
| `j_basement_asia` | basement ↔ asia | 24, −39 → 26, −38 | −6 | 2,6 | `bolt_basement_asia` (od Azji) |
| `j_roof_enlightenment` | roof ↔ enlightenment | 30, −12 → 31, −10,5 | **22,5** | 2,5 | `bolt_roof_enlightenment` (od Oświecenia) |

Każde skrzydło ma swoje zejście do podziemi (klatka schodowa **we własnej strefie**, na dole drzwi z zasuwą od strony skrzydła). Właz nad Egiptem (§4.4 p. 6) nie jest przejściem (zeskok w jedną stronę): opcja W3 + W5b, przez znaczniki `roof_hatch_egypt_top` (dach) i `roof_hatch_egypt_ledge` (Egipt), dopiero po zgodzie kontrolera (wymaga bryły dachu nad Egiptem).

### Bramy wewnątrz stref (dodaje moduł strefy, na otworze lub przy znaczniku z `INTERNAL_GATE_TARGETS`)

| Id | Strefa | Rodzaj | Wymaganie | Obszary | Cel w greyboksie |
|---|---|---|---|---|---|
| `gate_reading_room` | court | SEAL | `seal_owl` | court ↔ reading_room | otwór `court_reading_door` |
| `chain_gatling` | court | CHAIN | `heavy` | (reading_room) | znacznik `gatling_case` |
| `rope_planetarium` | enlightenment | ROPE | `rifle_hunt` | enlightenment ↔ planetarium | otwór `enlightenment_planetarium_door` (lina **dalej niż 15 m** od miejsca, gdzie stoi strażnik — pistolet nie może jej zerwać) |
| `cracked_garden` | asia | CRACKED | `explosive` | asia ↔ asia_garden | otwór `asia_garden_wall` |
| `hook_canoe` | americas | HOOK | `harpoon` | americas ↔ americas_temple | otwór `americas_canoe_bridge` |
| `grate_crypt` | north_hall | EVENT | `trex_defeated` | north_hall ↔ crypt | otwór `north_hall_grate` |

Wymagania (`ProgressRules.has_requirement`): id broni (`pistol`, `shotgun`, `flare`, `gatling`, `rifle_hunt`, `harpoon`, `hwacha`), przedmiot (`pistol_key`, `fuse_basement`, `fuse_assyria`), pieczęć (`seal_sun`, `seal_wing`, `seal_owl`, `star_key`), flaga (`power_north`, `astrolabe`), oraz `heavy` (zawsze: pięści), `precise` (pistolet lub sztucer), `explosive` (ognista skrzynia lub rakietnica), `shards_6`, `trex_defeated`.

### Przystanie, strażnicy, znajdźki postępu

| Przystań (`haven id`) | Strefa / obszar | Pokój | Terminal |
|---|---|---|---|
| `security` (start) | booth | `booth_security` | `haven_spots[&"security"]` |
| `conservator` | egypt | `egypt_conservator` | |
| `librarian` | enlightenment | `enlightenment_librarian` | |
| `workshop` | basement | `basement_workshop` | |
| `teahouse` | asia / `asia_garden` | `asia_teahouse` | po Generale |
| `cast_store` | greece | `greece_cast_store` | |

| Strażnik | Obszar | Daje | Znacznik |
|---|---|---|---|
| `colossus` (Kolos Ramzesa) | egypt | `seal_sun`, `shard_egypt` | `guardian_colossus` |
| `lamassu` | assyria | `seal_wing`, `shard_assyria` | `guardian_lamassu` |
| `centaur` (Kentaur z metopy) | greece | `seal_owl`, `shard_greece` | `guardian_centaur` |
| `planetarium` (Wielkie Planetarium) | planetarium | `star_key`, `shard_enlightenment` | `guardian_planetarium` |
| `general` (Generał samurajów) | asia_garden | `shard_asia` | `guardian_general` |
| `serpent` (Dwugłowy Wąż) | americas_temple | `shard_americas` | `guardian_serpent` |
| T-Rex (finał) | court | `trex_defeated` → krata | `trex_pedestal`; koniec: `floor1_exit` |

| Znajdźka | Obszar | Wymaga | Znacznik |
|---|---|---|---|
| `pistol_key` | entrance | — | `ticket_drawer` |
| `pistol` | booth | `pistol_key` | `pistol_locker` |
| `flare` | entrance | — | `flare_cabinet` |
| `shotgun` | egypt (**droga główna**, obóz ekspedycji) | — | `weapon_shotgun` |
| `rifle_hunt` | enlightenment (Gabinet Historii Naturalnej) | — | `weapon_rifle_hunt` |
| `gatling` | reading_room | `heavy` (łańcuch) | `gatling_case` |
| `hwacha` | asia (Sala Koreańska) | — | `weapon_hwacha` |
| `harpoon` | americas (Galeria Pacyfiku) | — | `weapon_harpoon` |
| `fuse_basement` | basement (kotłownia) | — | `fuse_basement` |
| `fuse_assyria` | assyria (Galeria Nimrud) | — | `fuse_assyria` |
| `power_north` (flaga) | basement (rozdzielnia) | oba bezpieczniki | `switchboard` |
| `astrolabe` (flaga) | reading_room | `shards_6` | `astrolabe` |

**Droga krytyczna (kolejność celu na HUD, `ProgressRules.STEPS`):** klucz z kasy → pistolet → rakietnica → strzelba → Kolos → sztucer → Planetarium → Lamassu → Kentaur → kartaczownica → bezpiecznik z podziemi → bezpiecznik z Asyrii → zasilanie → ognista skrzynia → Generał → harpunnik → Wąż → astrolabium → T-Rex → zejście. Kolejność jest częściowo dowolna (test losowych przejść: 40 przebiegów, zawsze do końca, bez blokady).

---

## Kontrakty (API)

### Dane układu (`src/level/layout/*`, `LevelLayout`)

```gdscript
# RoomSpec (nowe pola; lobby ich nie używa)
var zone: StringName          # Floor1Plan zone id (Floor1Layout uzupełnia sam)
var zone_area: StringName     # obszar postępu, gdy inny niż strefa (&"reading_room"...)
var name_key: StringName      # karta sali, plan muzeum
var public: bool = true       # drukowany na planie dla zwiedzających
func progress_area() -> StringName
func bounds() -> Rect2

# SpawnSlot (nowe)
const ALWAYS_SET := -1        # stawiany co noc niezależnie od losowania zestawu (W1 uczy reżysera)
var zone: StringName          # uzupełnia Floor1Layout
var patrol: StringName        # PatrolSpec id; &"" = stoi na posterunku

class_name GateSpec            # id, kind, opening, marker, requirement, label_key, one_way_side
enum Kind { CHAIN, BOARDS, SEAL, POWER, CRACKED, ROPE, HOOK, BOLT, EVENT }
const HEAVY := &"heavy"; const PRECISE := &"precise"; const EXPLOSIVE := &"explosive"; const NONE := &""
static func make(id, kind, blocks: StringName, needs := NONE, label := &"", bolt_side := &"") -> GateSpec
func opens_from(room: StringName) -> bool
static func kind_name(kind) -> StringName

class_name PatrolSpec          # id, room, points: PackedVector3Array, loop: bool; length()
class_name AmbushSpec          # id, room, trigger (AREA | PICKUP), area: Rect2, y_min, y_max, marker, slots: Array[int]
static func on_area(id, room, rect, y_min, y_max, slots) -> AmbushSpec
static func on_pickup(id, room, marker, slots) -> AmbushSpec
func triggered_by(point: Vector3) -> bool

# LevelLayout (nowe)
var gates: Array[GateSpec]; var patrols: Array[PatrolSpec]; var ambushes: Array[AmbushSpec]
func add_gate(id, kind, blocks, needs := GateSpec.NONE, label := &"", bolt_side := &"") -> GateSpec
func add_patrol(id, room, route: PackedVector3Array, loop := true) -> PatrolSpec
func add_ambush(ambush: AmbushSpec) -> AmbushSpec
func gate(id) -> GateSpec; func gate_of_opening(opening_id) -> GateSpec
func patrol(id) -> PatrolSpec; func ambush(id) -> AmbushSpec; func slot_index(slot) -> int
```

Otwór z bramą ma w grafie sal rodzaj `RoomGraph.Kind.GATE` (zamknięty, dopóki nie jest na liście otwartych). Styl drzwi w greyboksie: SEAL/ROPE/HOOK/EVENT → `GATE` (kraty jako zastępstwo), POWER → `SLIDE`, CHAIN/BOARDS → `DOUBLE_SWING`, BOLT → `SWING`, CRACKED → `PANEL`. `MuseumFloorLevel` zamyka i rygluje drzwi każdej nieotwartej bramy.

### `Floor1Plan` (czytają wszyscy; zmienia tylko kontroler)

```gdscript
const ZONES, WINGS, ZONE_BOXES, FLOOR_Y, ZONE_COLORS, ZONE_NAME_KEYS, MAP_TABS, SUB_AREAS
const JUNCTIONS, GATES, INTERNAL_GATE_TARGETS, HAVENS, GUARDIANS, PICKUPS, SEALS
const BASEMENT_Y := -6.0, ROOF_Y := 22.5, LANDING_Y := 6.0, STAIR_SLOPE := 0.375, STAIR_RISE := 0.15
const TREX_MARKER := &"trex_pedestal", EXIT_MARKER := &"floor1_exit", SHARD_COUNT := 6
static func junctions() -> Array[Junction]; junction(id); junctions_of(zone)
static func gates() -> Array[GatePlan]; gate(id); internal_gates(zone)
static func havens() -> Array[HavenPlan]; haven(id)
static func guardians() -> Array[GuardianPlan]; guardian(id)
static func pickups() -> Array[PickupPlan]; pickup(id); weapon_zone(weapon_id)
static func zone_boxes(zone) -> Array[AABB]; zone_at(point) -> StringName
static func contains(zone, rect, y0, y1) -> bool; zone_rect(zone); bounds()
static func zone_color(zone) -> Color; zone_name_key(zone); areas(); zone_of_area(area)
# Junction: id, zone_a, zone_b, rect, floor_y, top_y, style, gate, area_a, area_b;
#   center(), width(), depth(), height(), side_points(), point_in(zone), other(zone), area_of(zone)
```

### `Floor1Greybox` (pomocnik dla modułów)

```gdscript
static func r(x0, z0, x1, z1) -> Rect2
static func room(layout, id, rects, floor_y, ceiling_y, zone, name_key := &"", public := true, area := &"") -> RoomSpec
static func box(...) -> RoomSpec   # jeden prostokąt
static func door(layout, id, rect, floor_y, top_y, room_a, room_b, style := NONE, kind := OPEN) -> OpeningSpec
static func stairwell(layout, id, rect, low_y, high_y, ascend: Vector2, zone, top_landing := 3.0, name_key := &"ROOM_SERVICE_STAIRS") -> RoomSpec
static func tower(layout, id, rect, low_y, high_y, flights, first_lane, first_up, zone) -> RoomSpec
static func top_landing_rect(rect, flights, high_y, low_y, first_up) -> Rect2
static func lamp(layout, room_id, energy := 1.2) -> void
```

Schody: zawsze 0,15/0,40 (20,6°) — nawigacja łączy stoki do ok. 21,8°. Klatka 6 m w pionie potrzebuje 16 m biegu + spoczniki (≥ 2 m na dole, 3 m na górze). Uwaga: Recast zostawia **zamkniętą wyspę siatki wewnątrz bryły rampy** (pod biegiem); nikt tam nie chodzi, ale testy wybierające punkty nie mogą ich brać spod schodów.

### `Floor1Layout`, `MuseumFloorLevel`

```gdscript
Floor1Layout.create() -> LevelLayout            # moduły w kolejności Floor1Plan.ZONES, potem przejścia
Floor1Layout.build_zone(layout, zone)           # jeden moduł (testy stref)
Floor1Layout.add_junctions(layout)              # otwory + GateSpec bram przejść (BOLT: one_way_side = pokój po stronie zasuwy)
Floor1Layout.junction_room(layout, j, zone) -> StringName
Floor1Layout.describe(layout) -> LevelDescription   # start_rooms = 6 przystani; objective_rooms; boss_room = &"court"
Floor1Layout.rooms_of_area(layout, area); rooms_of_zone(layout, zone)
Floor1Layout.problems: PackedStringArray       # puste dla poprawnego piętra (testowane)

class_name MuseumFloorLevel extends Level
var layout, markers, doors, walk_region, haven_region, structure, lights, navigation
var night: NightConfig                          # przed build(): zamknięte drzwi nocy przed wypiekaniem
var gates_open: Array[StringName]               # przed build(): te bramy otwarte do pierwszego wypiekania
var art := false                                # Piętro I nie ma jeszcze zestawu grafiki
var build_msec, bake_msec
func build(); describe(); room_at(p); zone_at(p)
func is_gate_open(id) -> bool; open_gate(id, instant := false)   # odryglowuje i otwiera drzwi; nawigacja przebudowuje się sama
func apply_night(config); wall_faces()
const KILL_PLANE := -25.0
```

### Stan trwały (`GameState`, zapis v2)

```gdscript
const VERSION := 2
const DIFFICULTIES := [&"calm", &"night", &"double"]; const DEFAULT_DIFFICULTY := &"night"
var gates_open, guardians_defeated, seals, shards, items, flags, rooms_visited, chess_found: Array[StringName]
var difficulty: StringName
func open_gate(id) -> bool; is_gate_open(id)
func defeat_guardian(id) -> bool; is_guardian_defeated(id)
func add_seal(id) -> bool; add_shard(id) -> bool; add_item(id) -> bool; has_item(id)
func set_flag(id) -> bool; has_flag(id); visit_room(room) -> bool  # true = pierwszy raz w historii
func find_chess(id) -> bool
```

Dodawanie **nie zapisuje** — zapisuje wywołujący w chwili z §7.7 (broń, sekret, pieczęć, odłamek, brama, strażnik, przystań). **Migracja v1 → v2:** zostają bronie, ulepszenia, klucz do szafki, statystyki, ziarno i Pył (Pył z latarki z lobby dolicza się do niesionego, bo jej miejsce nie istnieje na nowym piętrze); od nowa: numer nocy (pierwsza noc na nowym piętrze jest łagodna), sekrety, notatki, przystanie i start, noc w toku, zakończenie dema.

### Reguły postępu

```gdscript
FloorProgress.from_game(game) -> FloorProgress   # weapons, items (+pistol_key), seals, shards, guardians, gates_open, flags
ProgressRules.has_requirement(progress, token) -> bool
ProgressRules.can_open(progress, gate_id, from_area) -> bool
ProgressRules.reachable_areas(progress, start := &"booth", closed: Array[StringName] = []) -> Dictionary
ProgressRules.start_area(haven_id) -> StringName
ProgressRules.can_do(progress, step) / is_done / apply(progress, step) / available_steps(...)
ProgressRules.goal(progress, start, closed) -> StringName     # klucz GOAL_*; GOAL_EPILOGUE po końcu
ProgressRules.next_step(...) -> StringName
ProgressRules.guardian_reachable(progress, id, ...) / reachable_guardians(...)
ProgressRules.finish(progress, ...) -> FloorProgress; is_complete(progress); is_soft_locked(progress, start, closed)
```

`closed` to przejścia zamknięte tej nocy (id przejścia). Graf obszarów jest zgrubny: wewnętrzne drzwi stref sprawdza na poziomie sal W7 (graf sal + siatka).

### Zdarzenia (`Events`, już są)

`room_entered(room, zone, first_visit)`, `noise_made(position, radius, source)`, `gate_opened(gate)`, `guardian_awakened(guardian, guardian_id)`, `guardian_defeated(guardian_id)`, `seal_collected(seal)`, `shard_collected(shard, count)`, `goal_changed(goal_key)`.

### Kontrakty gałęzi równoległych (projektujemy wokół nich, nie implementujemy)

**`p1-ai` (percepcja):** `Enemy.home_room: StringName`, `Enemy.territory: Array[StringName]` (puste = bez ograniczeń), `Enemy.patrol_route: PackedVector3Array` (puste = stoi na posterunku); statycznie `PerceptionWorld.configure(illumination: Callable /*(Vector3)->float 0..1*/, room_of: Callable /*(Vector3)->StringName*/, graph: RoomGraph, door_open: Callable /*(StringName)->bool*/)` i `PerceptionWorld.reset()` w `src/enemies/perception/perception_world.gd`. Gałąź ma też `LayoutIllumination.from_layout(layout)` (jasność z `LightSpec`, zasilanie grup, księżyc), `LevelPerception` (podłączenie poziomu z `LevelLayout`), `PerceptionRules.territory(graph, home)` (pomija drzwi `SECRET` i `GATE` — bramy Piętra I są więc granicami terytoriów, i dobrze), `PerceptionWorld.set_difficulty(int)` (0/1/2 ↔ `calm`/`night`/`double`).

**`p1-weapons` (bronie i zamki):** id broni `rifle_hunt`, `harpoon`, `hwacha`. Każdy zamek to `GateLock extends Node3D` z `@export var gate_id`, `@export var size: Vector2`, `signal opened` (raz, w grze; nigdy z `open_instantly()`), `func open_instantly()` (stan z zapisu, bez efektów), `func open()`, `func blocks_passage()`, `var is_open`. Klasy: `ChainLock`, `BoardsLock`, `CrackedWall`, `RopeLock`, `HookLock`, `BoltLock`, `PowerShutter` (`power_on()`). Początek zamka na podłodze w środku przejścia, przód (−Z) do strażnika. Zamki mają własne napisy `LOCK_*_PROMPT`; `GateSpec.label_key` (`GATE_*`) służy HUD-owi i planowi muzeum. ROPE: sztucer z każdej odległości, pistolet z ≤ 15 m. BOLT: E od strony zasuwy. POWER: `power_on()`.

---

## Zasady dla budowniczych stref (W2–W5b)

1. **Buduj tylko w bryłach swojej strefy** (`Floor1Plan.contains(zone, part, floor_y, ceiling_y + 0,5)` dla każdej części każdego pokoju; test `test_every_room_lies_in_its_zone`). Pod / nad cudzymi bryłami nie kop i nie nadbudowuj.
2. **Przejścia:** pokój twojej strony musi przylegać do otworu na całej jego szerokości, mieć podłogę na wysokości przejścia i sufit nie niższy niż jego góra. Otworów przejść **nie dodajesz** (robi to `Floor1Layout`), pokoi po drugiej stronie nie dotykasz.
3. **Id pokoi** zaczynają się od id strefy (`egypt_gallery`); pokój przystani ma id z `Floor1Plan.HAVENS`; każdy pokój ma `name_key` (nowe klucze `ROOM_<STREFA>_<NAZWA>` na końcu `strings.csv`) i właściwe `public` (służbowe, klatki, kryjówki: `false`; sekretne: `secret = true`). Pokoje za bramą wewnętrzną dostają `zone_area` z `SUB_AREAS`.
4. **Pokoje się nie stykają** — zawsze ≥ 0,5 m muru i `OpeningSpec` (inaczej `ShellCarver` je zleje, a graf sal zgubi przejście). Wyjątek: części **jednego** pokoju mogą się stykać.
5. **Bramy wewnętrzne** z tabeli: dokładnie te id, rodzaje i wymagania; inne bramy wolno dodać tylko jako miękkie (`CHAIN`/`BOARDS`) albo poza drogą krytyczną (id z prefiksem strefy) — W7 to sprawdza.
6. **Znaczniki** (wiążące nazwy): znajdźki i strażnicy z tabel; terminal przystani `layout.haven_spots[haven_id]` (początek na podłodze, −Z do pokoju); ponadto: `cctv_<strefa>_<n>`, `note_<strefa>_<n>`, `secret_<strefa>_<n>` (3 na skrzydło, §4.6; razem ok. 22), `chess_<n>` (8 na całe piętro: W2 1, W3 2, W4 2, W5a 2, W5b 1), `museum_map_<miejsce>` (plan na ścianie: przystanie i kanciapa), `arena_<guardian>_door_<n>` (drzwi zamykane na czas walki), `portrait_<strefa>_<n>` (miejsca na obrazy). Znacznik leży w pokoju, który podajesz (`add_marker(..., room)`).
7. **Spotkania:** 2–3 zestawy na salę (`set_id` 0..2), gęstość 0,6–1,2 eksponatu na 100 m² powierzchni sali (reżyser przytnie), rodzaje istniejące (`wax`, `wolf`, `knight`, `bust`, `raptor`) — nowe typy przyjdą później, więc w `kinds` wolno dopisać przyszły typ **po** istniejącym (`[&"wax", &"mummy"]`; fallback i tak działa). Patrole (`add_patrol` + `slot.patrol`), zasadzki (`AmbushSpec`, np. mumie przy strzelbie), nic w przystaniach, punkty spawnu i łupu na wolnej podłodze (test kapsułą).
8. **Światło:** każda sala ma światło z przepisu skrzydła (§10.1) w greyboksie wystarczą lampy z kolorem i siłą zbliżoną do przepisu; grupy `main_lights` / `emergency_lights` / `haven_lights` jak w lobby (zasilanie i awaria prądu przełączają grupy). Cienie tylko tam, gdzie je widać.
9. **Greybox, nie oprawa.** Elementy z `LevelKit` (kolumny, gabloty, ławki, cokoły, skrzynie, balkony, balustrady). Kształty nieprostokątne (bęben Czytelni, schodkowa świątynia) jako bryły z elementów w prostokątnym pokoju; kolizja przyjazna nawigacji.
10. **Testy strefy** w `tests/unit/test_floor1_<grupa>.gd`: liczba i wymiary kluczowych sal z §5, przejścia i bramy, znaczniki, zestawy spawnu (każda sala z eksponatami ma ≥ 2 zestawy), gęstość, wysokości schodów ≤ 20,6°, oraz `tests/integration/test_floor1_<grupa>_walk.gd`: siatka nawigacji dochodzi z każdego wejścia strefy do każdej sali (bramy otwarte), a zamknięta brama odcina swoją część. Zawsze zielone: `test_floor1_plan`, `test_floor1_layout`, `test_museum_floor_level`, `test_progress_rules`.

---

## Część B — strumienie pracy

Kolejność scalania do `pietro-1`: najpierw `p1-ai` i `p1-weapons`, potem `p1-core` (ten etap A), potem W1 oraz równolegle W2–W5b i W6 (rozłączne pliki), na końcu W7 (może zacząć wcześniej na szkielecie). Pliki wspólne: `locale/strings.csv` (bloki na końcu), `tests/test_runner.gd` (tylko W1), `src/core/events.gd` (tylko W1, w uzgodnieniu), `src/core/game_input.gd` (tylko W6: akcja `map`).

### W1 — integracja rdzenia

**Pliki (własne):** `src/game/museum.gd`, `src/game/night_director.gd`, `src/game/night_config.gd`, `src/game/night_spawner.gd` (po scaleniu `p1-ai`), `src/progression/night_rules.gd`, `src/haven/*`, `src/ui/hud.gd`, `src/world/*` (uogólnienie), `src/level/floor1/museum_floor_level.gd` (od części B), nowy katalog `src/game/floor1/*` (np. `gate_controller.gd`, `guardian_stub.gd`, `room_tracker.gd`, `floor_goal.gd`, `floor_pickups.gd`, `switchboard.gd`, `astrolabe.gd`), `tests/test_runner.gd`, testy `tests/*/test_floor1_game*.gd`, `test_night_director_floor1.gd`.
**Wejście:** wszystkie kontrakty powyżej, `GateLock` z `p1-weapons`, `PerceptionWorld`/`LevelPerception` z `p1-ai`.

Zadania:
1. **Wybór poziomu.** `Museum` gra domyślnie `MuseumFloorLevel`; lobby zostaje poziomem testowym: `static var level_id := &"floor1"` (albo równoważna opcja), a `tests/test_runner.gd::_reset_globals()` ustawia `&"lobby"`, więc istniejące 1000+ testów działają bez zmian; nowe testy Piętra I ustawiają `&"floor1"` same. Moduły tylko-lobby (`NightObjective`, `LobbyArmory`, `Onboarding`, `LobbyFeatures`) działają tylko w lobby; `NightModifiers.apply()` przyjmuje ogólny poziom (oba mają `lights` i grupy świateł).
2. **Bramy.** `GateController`: dla każdego `GateSpec` stawia zamek z `p1-weapons` według rodzaju (CHAIN→`ChainLock`, BOARDS→`BoardsLock`, CRACKED→`CrackedWall`, ROPE→`RopeLock`, HOOK→`HookLock`, BOLT→`BoltLock` po stronie `one_way_side`, POWER→`PowerShutter`) na otworze (`LevelBuilder.passage_frame`) albo przy znaczniku; SEAL i EVENT → drzwi pieczęci (W1: kamienne wrota z wgłębieniem, E otwiera, gdy `ProgressRules.has_requirement`, inaczej napis `GATE_SEAL_*`/`GATE_STAR_KEY`; EVENT otwiera gra). Bramy z `GameState.gates_open` → `open_instantly()` + `level.open_gate(id, true)` przed pierwszym wypiekaniem (lepiej: `level.gates_open` przed `build()`). `opened` → `GameState.open_gate(id)`, `level.open_gate(id)`, `Events.gate_opened.emit(id)`, zapis. Rozdzielnia (`switchboard`): E z oboma bezpiecznikami → `set_flag(&"power_north")`, `power_on()` żaluzji, zapis.
3. **Przystanie ×6:** budowa z `haven_spots`/`haven_zones` jest już ogólna; odkrycie (toast z `HavenPlan.name_key`), start nocy w ostatniej przystani (`start_haven`), plan na ścianie (`museum_map_*`, od W6).
4. **HUD:** cel = `tr(ProgressRules.goal(FloorProgress.from_game(GameState), ProgressRules.start_area(GameState.start_haven), closed))` po każdej zmianie postępu (+ `Events.goal_changed`), licznik odłamków (`GOAL_SHARDS`), karta nazwy sali przy `Events.room_entered` (kolor strefy), pasek strażnika z imieniem i tytułem (`GUARDIAN_*`, `GUARDIAN_*_TITLE`). `RoomTracker`: co 0,25 s `level.room_at(strażnik)`; zmiana → `GameState.visit_room()` → `Events.room_entered(room, zone, first)`.
5. **Manekin strażnika** (`GuardianStub`): stoi na znaczniku strażnika (nie dla pokonanych), pasek zdrowia (`Events.guardian_awakened`), proste ciosy z zapowiedzią ≥ 0,6 s, drzwi areny zamykane na czas walki (opcjonalnie); po śmierci `defeat_guardian`, `Events.guardian_defeated`, pieczęć i odłamek do podniesienia (`add_seal`/`add_shard`, `Events.seal_collected`, `Events.shard_collected(shard, count)`), zapis, 60 Pyłu.
6. **Reżyser nocy na strefach:** zestawy na salę jak dziś; gęstość z powierzchni sali (0,6–1,2/100 m², tempo skrzydła); skrzydło z pokonanym strażnikiem ma ok. 55% eksponatów; **pierwsze 3 minuty nocy 1**: sale trasy kanciapa → hol → dziedziniec tylko śpiące + najwyżej 2 patrolujące figury, bez wilków; `SpawnSlot.ALWAYS_SET`; patrole z `PatrolSpec` (`enemy.patrol_route`), zasadzki z `AmbushSpec` (obszar albo podniesienie znajdźki budzi sloty); zamykane drzwi nocy tylko `LOCKABLE`, nigdy bramy ani przejścia z jedyną drogą (graf sal + `ProgressRules.is_soft_locked(..., closed)` z każdej znanej przystani); determinizm (to samo ziarno = ta sama noc).
7. **Percepcja:** na starcie nocy `PerceptionWorld.configure(...)` (przez `LevelPerception` z `p1-ai` albo bezpośrednio: jasność `LayoutIllumination`, `room_of = level.room_at`, `graph = layout.graph()`, `door_open` = drzwi otwarte); `home_room = slot.room`, `territory = PerceptionRules.territory(...)`, `patrol_route` z `PatrolSpec`; trudność `GameState.difficulty` → `set_difficulty(0/1/2)` i mnożniki z §7.5.
8. **Łup i bronie:** łup po całym piętrze (istniejąca logika + amunicja nowych broni z zamiennikami, gdy strażnik nie ma broni); bronie z §7.1 na znacznikach (`FoundWeapon`, szafka z pistoletem i szuflada kasy przeniesione na znaczniki booth/entrance, szafka pożarowa z rakietnicą, `ChainedDisplay` z kartaczownicą + `chain_gatling`); bezpieczniki jako trwałe przedmioty (`add_item`); **strzelba leży na drodze głównej w Egipcie**.
9. **CCTV, notatki, sekrety:** `LobbyFeatures` → ogólne `WorldFeatures` czytające znaczniki (`cctv_*`, `note_*`, `secret_*`, `chess_*`) z dowolnego układu; lobby dalej działa.
10. **Finał:** T-Rex na `trex_pedestal`, astrolabium (6 odłamków → `set_flag(&"astrolabe")` → kryształ leci do T-Reksa), po zwycięstwie `defeat_guardian(&"trex")`, krata `grate_crypt` się otwiera, `floor1_exit` → ekran końca Piętra I (`DemoEnd` z nowymi statystykami) + `set_flag(&"floor1_complete")`.

**Kryteria akceptacji:** nowa gra startuje w kanciapie Piętra I; da się przejść całą drogę krytyczną w szarości (manekiny), postęp przeżywa śmierć, świt i wyjście z gry; cel na HUD zawsze wskazuje wykonalny krok; zestaw zielony (lobby nietknięte). **Testy:** gra na Piętrze I (start, przystanie, cel), brama: otwarcie → zapis → następna noc otwarta bez efektów, manekin: pokonanie zapisane, nie wraca; reżyser: gęstość, 55%, łagodny start („po wyjściu z kanciapy w promieniu 30 m najwyżej 2 polujących przez 60 s”), determinizm, żadne drzwi nocy nie robią blokady.

### W2 — strefy centralne: `court`, `entrance`, `booth`, `north_hall` (z kryptą)

**Pliki:** `src/level/floor1/zones/{court,entrance,booth,north_hall}.gd`, `tests/unit/test_floor1_hub.gd`, `tests/integration/test_floor1_hub_walk.gd`, klucze `ROOM_COURT_*`, `ROOM_ENTRANCE_*`, `ROOM_BOOTH_*`, `ROOM_NORTH_*`.
**Zakres (§5.7):** dziedziniec 60 × 60 (h 22): bęben Czytelni jako 16-kąt (r 12,5, wnętrze do y ≈ 20; drzwi z bramą `gate_reading_room` — do uzgodnienia strona: projekt mówi „przez drzwi Czytelni” do T-Reksa, więc północ), balkon y = 7 wokół północnej połowy bębna z dwoma biegami ≤ 20,6°, postument T-Reksa na północ od bębna (`trex_pedestal`), totem Haida (NE), sklep (krata), kawiarnia, informacja, ławki — osłony i linie strzału na walkę z T-Reksem (bęben jako ściana do ogłuszenia). Czytelnia: promieniste biurka, regały, gablota kartaczownicy z łańcuchem (`gatling_case`), astrolabium w środku. Hol wejściowy 32 × 22 (h 12): kasa (`ticket_drawer`), szatnia, szafka pożarowa (`flare_cabinet`), schody na podest y = 6 do obu drzwi przejść (`j_entrance_greece`, `j_entrance_roof`), zamknięte główne drzwi (`museum_exit`). Kanciapa jak w lobby (CCTV, szafka na broń, terminal, biurko, plan na ścianie) + schody służbowe w dół z deskami przy `j_booth_basement`. Korytarz północny: żaluzje obu skrzydeł, krata `grate_crypt`, schody do krypty, krypta i „schody w ciemność” (`floor1_exit`). Łagodny start: sale trasy kanciapa → hol → dziedziniec mają zestawy ze śpiącymi figurami i ≤ 2 patrolami, bez wilków. Sekrety: 1–2 (dziedziniec/hol), szachy: 1.
**Akceptacja:** wymiary z §5.7, wszystkie przejścia tych stref obsłużone, test chodzenia zielony, `test_floor1_layout` zielony.

### W3 — skrzydła zachodnie: `egypt`, `greece`

**Pliki:** `src/level/floor1/zones/{egypt,greece}.gd`, `tests/unit/test_floor1_west.gd`, `tests/integration/test_floor1_west_walk.gd`, klucze `ROOM_EGYPT_*`, `ROOM_GREECE_*`.
**Zakres (§5.1, §5.3):** Egipt — przedsionek Rosetty (wejście z `j_court_egypt`, pierwszy widok na galerię), Wielka Galeria 16 × 66 (h 11, kolumny papirusowe, szpaler posągów, sarkofagi), **obóz ekspedycji ze strzelbą w połowie galerii, oświetlony i widoczny od wejścia** (`weapon_shotgun`, zasadzka mumii przy podniesieniu), grobowce (niski strop, przejście z deskami do Grecji `j_egypt_greece`), pokój konserwatora (przystań), Sala Kolosa 24 × 24 (h 14, kolumny pękające od promienia — znaczniki `colossus_column_<n>`), Brama Chorsabadu w jej północnej ścianie (`j_egypt_assyria`), klatka do podziemi z zasuwą (`j_basement_egypt`). Grecja — Sala Waz, Pomnik Nereid, Galeria Partenonu (ok. 40 × 18, h 12, arena Kentaura), Sala Metop, Sala z Bassae (antresola po schodach; zasuwa z Asyrii `j_assyria_greece`), magazyn odlewów (przystań), schody na podest y = 6 do holu (`j_entrance_greece`, zasuwa od Grecji), klatka do podziemi (`j_basement_greece`). Grecja najjaśniejsza, Egipt najciemniejszy.
**Akceptacja:** jak W2; strzelba widoczna z przedsionka (test promienia: brak przeszkody między punktem wejścia a znacznikiem na wysokości oczu).

### W4 — skrzydła północno-zachodnie: `assyria`, `americas`

**Pliki:** `src/level/floor1/zones/{assyria,americas}.gd`, `tests/unit/test_floor1_northwest.gd`, `tests/integration/test_floor1_northwest_walk.gd`, klucze `ROOM_ASSYRIA_*`, `ROOM_AMERICAS_*`.
**Zakres (§5.2, §5.6):** Asyria — Brama Chorsabadu z lamassu, Galeria Nimrud (bezpiecznik `fuse_assyria`), Sala Lwów (zasuwa do Grecji), Wrota z Balawat (`j_assyria_americas`), Dziedziniec Pałacu (arena Lamassu, otwarty strop), magazyn tabliczek (sekret), zejście do podziemi (`j_basement_assyria`; dziś schody, winda towarowa opcjonalnie). Ameryki — Sala Moai (sekret: obrót moai po trafieniu harpunem w ucho), Galeria Pacyfiku (harpunnik `weapon_harpoon`, czółno-most `hook_canoe` nad zapadniętą podłogą), Świątynia Węża (schodkowe podesty, arena) dostępna **tylko** przez most, Sala Totemów, Sala Ameryki Północnej (`j_north_americas`), klatka do podziemi (`j_basement_americas`).
**Akceptacja:** jak W2; świątynia nieosiągalna bez `hook_canoe` (test siatki z zamkniętą bramą).

### W5a — skrzydła wschodnie: `enlightenment`, `asia`

**Pliki:** `src/level/floor1/zones/{enlightenment,asia}.gd`, `tests/unit/test_floor1_east.gd`, `tests/integration/test_floor1_east_walk.gd`, klucze `ROOM_ENLIGHTENMENT_*`, `ROOM_ASIA_*`.
**Zakres (§5.4, §5.5):** Oświecenie — Biblioteka Królewska 14 × 70 (h 10, górna galeria regałów y = 4), Gabinet Historii Naturalnej (sztucer `weapon_rifle_hunt`), Galeria Portretów, Sala Zegarów, gabinet bibliotekarza (przystań), Rotunda Planetarium (arena; lina `rope_planetarium` > 15 m od strażnika), wieża na dach z zasuwą u góry (`j_roof_enlightenment`; wolno ją przenieść w obrębie strefy, jeśli górny spocznik dotyka otworu), klatka do podziemi (`j_basement_enlightenment`). Azja — Sala Chin (`j_north_asia`), Galeria Porcelany, Sala Koreańska (ognista skrzynia `weapon_hwacha`, zasuwa do Planetarium `j_asia_enlightenment`), Sala Zbroi, ogród japoński za spękanym murem (`cracked_garden`, arena Generała) z herbaciarnią (przystań), klatka do podziemi (`j_basement_asia`).
**Akceptacja:** jak W2.

### W5b — `basement` i `roof`

**Pliki:** `src/level/floor1/zones/{basement,roof}.gd`, `tests/unit/test_floor1_service.gd`, `tests/integration/test_floor1_service_walk.gd`, klucze `ROOM_BASEMENT_*`, `ROOM_ROOF_*`.
**Zakres (§5.8, §4.4):** podziemia — pierścień korytarzy (beton, rury, kratki, h 3,5), odnogi do **wszystkich siedmiu** przejść na y = −6, warsztat renowacji (przystań), kotłownia (`fuse_basement`), rozdzielnia (`switchboard`), magazyny (sekrety), tunel pod Salą Kolosa do Asyrii; mało eksponatów w ciasnych korytarzach (mieszanka skrzydeł). Dach — wieża nad kanciapą od `j_entrance_roof`, kładki nad szklanym dachem dziedzińca (widok w dół: dach dziedzińca jest dziś pełną płytą — szklany dach i jego kratownica to bryła-bohater P2; kładki projektuj tak, by stały **nad** y = 22,5), dojście do `j_roof_enlightenment`; 1 sekret, 1 figura szachów; wiatr, brak eksponatów albo 1–2.
**Akceptacja:** jak W2; każde z 7 przejść podziemi osiągalne z warsztatu po siatce (bramy otwarte).

### W6 — papierowy plan muzeum (§9.1)

**Pliki:** `src/ui/museum_map.gd` (ekran), `src/ui/map_model.gd` (czysta logika: co drukowane, co dopisane ołówkiem, co ukryte), `src/ui/map_drawing.gd` (rysowanie), `src/core/game_input.gd` (akcja `map`, klawisz M), testy `tests/unit/test_map_model.gd`, `tests/integration/test_museum_map.gd`, klucze `MAP_*`.
**Wejście:** `LevelLayout` (pokoje: `zone`, `name_key`, `public`, `secret`, części; otwory; schody), `Floor1Plan.ZONE_COLORS`, `MAP_TABS` (parter / podziemia / dach), `GameState.rooms_visited`, `havens`, `guardians_defeated`, `gates_open`, `Floor1Plan.gates()` (znak zapytania z rodzajem zamka przy zamkniętej znanej bramie), `ProgressRules.goal(...)` (cel ołówkiem), pozycja i kierunek strażnika („Jesteś tutaj”).
**Zasady:** drukowane tylko sale publiczne (kolory skrzydeł, legenda PL/EN); sale niepubliczne dopisane ołówkiem po odwiedzeniu; sekrety nigdy (zostają białe luki); odhaczone odwiedzone sale, kółka wokół przystani, znaczki znalezisk, wykrzyknik przy znanym strażniku. Plan pauzuje grę (jak czytnik notatek), Esc/M zamyka. Wersja „na ścianę” (`MuseumMap.poster(layout) -> Texture2D` albo węzeł) dla znaczników `museum_map_*` — podpina W1.
**Testy:** model dla kilku stanów (nowa gra, po Egipcie, po podziemiach), zakładki, pauza i zamknięcie, brak sekretów na planie, kolory stref.

### W7 — weryfikacja: osiągalność i bot-zwiedzający (§12)

**Pliki:** `tests/integration/test_floor1_reachability.gd`, `tests/support/floor1_route.gd` (czysta logika trasy), `tests/integration/test_floor1_timing.gd`, wynik `tests/_out/floor1_timing.json`.
**Osiągalność:** dla każdego stanu drogi krytycznej (`ProgressRules.STEPS`) i kilku losowych kolejności × każda przystań znana w tym stanie × każde drzwi, które reżyser może zamknąć (`NightDirector.safe_doors` na opisie Piętra I) — po siatce nawigacji (bramy otwarte według stanu: `gates_open` + `ProgressRules.openable_gates`) następny krok jest osiągalny. Plus zgodność grafów: zbiór obszarów osiągalnych w grafie sal (z bramami jak wyżej) = `ProgressRules.reachable_areas` dla każdego stanu.
**Bot:** trasa krytyczna i trasa 100% (wszystkie sale, znaczniki sekretów i szachów) po siatce: długości odcinków, czas = droga / 5,5 m/s (chód) + walki z tabeli (strażnik 2–3,5 min, sala z eksponatami: 10–40 s zależnie od gęstości) → `floor1_timing.json` (odcinki, sumy, minuty). Cel: 45–80 min na 100%, droga krytyczna 25–40 min; poza celem — raport do kontrolera, nie „naprawianie” liczb.

---

## Ryzyka i otwarte kwestie

| Ryzyko | Odpowiedź |
|---|---|
| Rzeźbienie skorupy 2,4 s na zimno | pamięć podręczna w procesie (każda kolejna noc ≈ 0,3 s); w P4 zapis wyniku przy eksporcie z sumą kontrolną układu |
| Wypiekanie siatki po dodaniu oprawy | region na bryłę strefy (opis wyżej), bramy przebudowują tylko swoje strefy |
| Konflikty `strings.csv` | każdy dopisuje blokiem na końcu; integrator zostawia oba bloki; klucze z prefiksami strefy nie kolidują |
| Bramy w grafie sal to `GATE` — `PerceptionRules.territory` (p1-ai) ich nie przekracza, także otwartych | zamierzone: bramy są granicami terytoriów; słuch przez otwarte bramy idzie przez `door_open` |
| Zmiana przejścia przez budowniczego | tylko przez kontrolera (`floor1_plan.gd`); testy planu i układu pilnują spójności |
| Lina Planetarium a pistolet z ≤ 15 m (`p1-weapons`) | W5a stawia linę poza zasięgiem pistoletu; W7 sprawdza odległość od najbliższej podłogi |
| Liczby (wymiary, gęstość, czas) | punkt startowy do strojenia; bot W7 mierzy |
