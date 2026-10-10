# W6 — papierowy plan muzeum (M): ulotka dla zwiedzających z ołówkowymi dopiskami strażnika

> **Dla wykonawcy:** REQUIRED SUB-SKILL: superpowers:executing-plans (zadania po kolei, TDD, commit po każdym). Kroki mają pola `- [ ]`.
> Plan nadrzędny (wiążący): `docs/superpowers/plans/2026-10-02-p1-fundament.md`, strumień **W6**; kontrakt W1 (`docs/superpowers/plans/2026-10-03-p1-w1-integracja.md`: `MuseumMap.poster` dla znaczników `museum_map_*`, cel z `ProgressRules.goal`). Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §9.1 (plan), §3.3 (cel), §4 (strefy, bramy), §4.5 (przystanie), §5.7 (dziedziniec, hol, kanciapa).

**Cel:** klawisz **M** (pad: View/Select) otwiera pauzujący grę **plan Piętra I** wyglądający jak prawdziwa, składana ulotka muzeum: złamany w trzy i na pół, lekko zużyty papier, druk w kolorach skrzydeł z legendą PL/EN, nazwą muzeum i zakładkami Parter / Podziemia / Dach — a na nim **ołówkowe dopiski strażnika**: dorysowane pomieszczenia służbowe, ptaszki w odwiedzonych salach, kółka wokół przystani, znaczki znalezisk, wykrzykniki strażników, znaki zapytania przy zamkniętych bramach z rodzajem zamka i strzałka do bieżącego celu. Ten sam druk (bez ołówka, z czerwoną kropką „tu jesteś”) wisi na tablicach w przystaniach (`MuseumMap.poster`).

**Architektura (jeden akapit):** czysta logika w `RefCounted`: `MapState` (migawka zapisu: odwiedzone sale, przystanie, bramy, strażnicy, znaleziska, cel), `MapModel` (z `LevelLayout` + `MapState`: które sale są drukowane, które dorysowane ołówkiem, które niewidoczne; zakładki; obrysy; kotwice podpisów; drzwi, schody, piktogramy; adnotacje i cel), `MapProjection` (świat x, z ↔ arkusz) i `MapView` (przesuw i powiększenie arkusza na ekranie, wygładzanie). Rysowanie (`MapDrawing`) wydaje prymitywy na abstrakcyjne płótno `MapCanvas` z dwoma zapisami: `MapCanvasItem` (prawdziwe `draw_*` w grze) i `MapRecorder` (lista operacji: testy i podglądy). Ekran `MuseumMap` (CanvasLayer) składa arkusz z warstw: papier (tekstura z Pythona), druk (lista rysowania nagrana raz na zakładkę), zagięcia i zużycie (nakładka), ołówek (shader ziarna grafitu), podpisy (zanikają/pojawiają się z powiększeniem, bez przerysowania), „Jesteś tutaj”; na klatkę liczy się tylko transformacja arkusza. Podglądy bez okna: scenariusz zapisuje listę operacji do JSON, `tools/map/render_preview.py` (pycairo) rysuje PNG w `tests/_out/map/`.

**Technologia:** Godot 4.7.2 (GDScript ze statycznym typowaniem, tabulatory), czcionki systemowe (`SystemFont`: Bahnschrift — druk, Georgia — tytuł, Segoe Print / Ink Free — ołówek), Python 3 + numpy + Pillow (tekstury papieru), pycairo (podglądy). Testy: `bash tools/run_tests.sh --filter=…` (bez okna, `--fixed-fps 60`).

---

## Zasady (przypomnienie)

- Pracujemy tylko w drzewie `.claude/worktrees/p1-w6-map` (gałąź `p1-w6-map`), bez okien i bez dźwięku, jeden ciężki proces naraz, `--filter` przy iteracji, pełny zestaw na końcu.
- Teksty przez `tr()`, klucze `MAP_*` (+ `PAUSE_MAP`, `HUD_HELP_MAP`) **dopisane na końcu** `locale/strings.csv`, porządny polski i angielski.
- Wejście tylko przez `GameInput` (stos menu, właściciel kursora); plan pauzuje grę jak czytnik notatek i oddaje wejście po puszczeniu klawiszy (`pop_ui_on_release`).
- Commit po każdym zadaniu, ostatnia linia: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; dodajemy tylko własne pliki (+ `.uid`).
- Pliki cudze zmieniane minimalnie: `src/game/floor1/floor_game.gd` (jedna linia instalacji), `src/ui/pause_menu.gd` (przycisk „Plan muzeum”), `src/core/game_input.gd` (akcja `map` — plik W6 według planu nadrzędnego).

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/ui/map/map_state.gd` | `MapState`: migawka postępu dla planu (z `GameState`), cel i jego krok |
| `src/ui/map/map_model.gd` | `MapModel`: zakładki, sale (drukowane / ołówkiem / ukryte, antresole, okrągłe), obrysy sum prostokątów, kotwice podpisów, drzwi, schody, piktogramy, napisy skrzydeł, adnotacje (`Mark`), cel (`Goal`) |
| `src/ui/map/map_projection.gd` | `MapProjection`: świat (x, z) ↔ arkusz (px), dopasowanie z marginesem, północ u góry |
| `src/ui/map/map_view.gd` | `MapView`: powiększenie i przesuw arkusza na ekranie (dopasowanie, granice, zoom wokół kursora, wygładzanie) |
| `src/ui/map/map_style.gd` | `MapStyle`: wymiary arkusza i paneli, zagięcia, paleta druku per strefa, kolory ołówka i czerwieni, rozmiary pisma |
| `src/ui/map/map_fonts.gd` | `MapFonts`: czcionki planu (druk, druk pogrubiony, tytuł, ołówek), pomiar tekstu, łamanie wierszy |
| `src/ui/map/map_canvas.gd`, `map_canvas_item.gd`, `map_recorder.gd` | `MapCanvas` (baza), `MapCanvasItem` (zapis na `CanvasItem`), `MapRecorder` (lista operacji → JSON, zapytania testowe) |
| `src/ui/map/map_drawing.gd` | `MapDrawing`: warstwy druku (podkład budynku, sale, drzwi, schody, piktogramy, nagłówek, legenda z polem „Notatki”, róża wiatrów, podziałka), napisy skrzydeł (miejsce wolne od podpisów), podpisy sal (dopasowane do sali), „Jesteś tutaj”, cień arkusza, zakładki i linia podpowiedzi na ekranie |
| `src/ui/map/map_pencil.gd` | `MapPencil`: ołówek — pociągnięcia z drżeniem i „przestrzeleniem”, kreskowanie, sale i drzwi dorysowane, ptaszki, pętle przystani, szkice znalezisk, „!” i „?” z zamkiem, strzałka celu z „tu!”, notatka i klucz strażnika |
| `src/ui/map/map_sheet_layer.gd` | `MapSheetLayer`: `Control` rysujący jedną warstwę przez `MapDrawing` / `MapPencil` (przerysowanie tylko na żądanie) |
| `src/ui/museum_map.gd` | `MuseumMap` (CanvasLayer): ekran planu (otwieranie M / z pauzy, pauza, zakładki, przesuw i zoom: mysz, klawiatura, pad), `install(floor_game)`, `poster(layout)` |
| `src/ui/map/map_poster.gd` | `MapPoster` (Node3D): tablica na ścianie (deska, arkusz, czerwona kropka), tekstura druku renderowana raz (SubViewport) i trzymana w pamięci |
| `src/ui/map/graphite.gdshader` | ziarno grafitu na warstwie ołówka |
| `assets/ui/map/leaflet_paper.jpg`, `leaflet_wear.png`, `graphite_grain.png` | papier, zagięcia i zużycie, ziarno grafitu (z `tools/map/build_paper.py`) |
| `tools/map/build_paper.py` | generator tekstur papieru (numpy + Pillow, deterministyczny) |
| `tools/map/render_preview.py` | podgląd z listy operacji (pycairo) → PNG |
| `tools/run_map_preview.sh` | scenariusz podglądu: Godot bez okna zapisuje JSON, Python rysuje PNG do `tests/_out/map/` |
| `tests/support/map_preview.gd` | skrypt Godota dla scenariusza podglądu (stany: nowa gra, po Egipcie, po podziemiach, późna gra) |
| `src/core/game_input.gd` (zmiana) | akcja `map`: M + przycisk Back pada |
| `src/ui/pause_menu.gd` (zmiana) | przycisk „Plan muzeum” (gdy jest plan), plan nad menu pauzy |
| `src/game/floor1/floor_game.gd` (zmiana) | `map = MuseumMap.install(self)` |
| `locale/strings.csv` (dopisane) | `MAP_*`, `PAUSE_MAP`, `HUD_HELP_MAP` |
| `tests/unit/test_map_model.gd` | rzutowanie, widok, zakładki, druk/ołówek/ukryte, obrysy, adnotacje, cel |
| `tests/unit/test_map_drawing.gd` | warstwy na `MapRecorder`: druk bez sekretów, kolory stref, ołówek w salach służbowych, strzałka celu, legenda |
| `tests/integration/test_museum_map.gd` | akcja `map`, otwieranie/zamykanie i pauza, Esc bez menu pauzy, z menu pauzy, zakładki, centrowanie na strażniku, tablice na ścianach |

## Kontrakty (API)

```gdscript
class_name MapState extends RefCounted
var rooms_visited, havens, guardians_defeated, gates_open, seals, shards, items, weapons, notes, chess_found, secrets, flags: Array[StringName]
var goal_key: StringName      # ProgressRules.goal(...)
var goal_step: StringName     # ProgressRules.next_step(...) (&"" = brak)
static func from_game(game: PersistentState, closed: Array[StringName] = []) -> MapState

class_name MapModel extends RefCounted
const GROUND := &"ground"; const BASEMENT := &"basement"; const ROOF := &"roof"
const TABS: Array[StringName] = [GROUND, BASEMENT, ROOF]
const TAB_KEYS := {GROUND: &"MAP_TAB_GROUND", BASEMENT: &"MAP_TAB_BASEMENT", ROOF: &"MAP_TAB_ROOF"}
enum Look { PRINTED, PENCIL, HIDDEN }
class Room: id, zone, name_key, parts: Array[Rect2], tabs: Array[StringName], look: Look, upper: bool, round: bool, visited: bool, haven: StringName, secret: bool, anchor: Vector2, outline: Array[PackedVector2Array]
class Door: id, rect: Rect2, tab, look: Look, room_a, room_b
class Flight: id, rect: Rect2, ascend: Vector2, tab, look: Look
class Picto: kind: StringName, at: Vector2, tab   # &"info", &"cafe", &"shop", &"cloakroom", &"tickets", &"entrance"
enum MarkKind { TICK, HAVEN, WEAPON, SEAL, SHARD, ITEM, NOTE, CHESS, SECRET, GUARDIAN, GATE }
class Mark: kind: MarkKind, id: StringName, at: Vector2, tab, room: StringName, crossed: bool, lock: GateSpec.Kind, item: StringName
class Goal: key: StringName, step: StringName, at: Vector2, tab: StringName, room: StringName, placed: bool
var rooms: Array[Room]; doors: Array[Door]; flights: Array[Flight]; pictos: Array[Picto]; marks: Array[Mark]; goal: Goal
static func build(layout: LevelLayout, state: MapState) -> MapModel
static func tab_of_height(y: float) -> StringName           # y < −2,5 → podziemia, y > 15 → dach, inaczej parter
static func room_tabs(layout: LevelLayout, room: RoomSpec) -> Array[StringName]   # od podłogi do szczytu jej schodów
static func is_printed(room: RoomSpec, layout: LevelLayout) -> bool   # publiczna, nie sekret, parter
static func outline(parts: Array[Rect2]) -> Array[PackedVector2Array]  # obrys sumy prostokątów (odcinki bez wspólnych krawędzi)
static func is_round(room: RoomSpec) -> bool                # ≥ 5 części, kwadratowe granice, pole ≈ π/4 granic
func room(id) -> Room; func rooms_on(tab, look := -1) -> Array[Room]; func marks_on(tab, kind := -1) -> Array[Mark]
func wings_on(tab) -> Array  # [zone, center: Vector2, rotated: bool] napisy skrzydeł

class_name MapProjection extends RefCounted
var world: Rect2; var area: Rect2; var scale: float; var origin: Vector2
static func fit(world: Rect2, area: Rect2, margin_m := 3.0) -> MapProjection
func to_sheet(p: Vector2) -> Vector2; func to_world(p: Vector2) -> Vector2
func rect_to_sheet(r: Rect2) -> Rect2; func point(v: Vector3) -> Vector2   # x, z -> arkusz

class_name MapView extends RefCounted
var sheet_size: Vector2; var screen_size: Vector2; var zoom: float; var center: Vector2   # punkt arkusza w środku ekranu
var target_zoom: float; var target_center: Vector2
func fit_zoom() -> float; func min_zoom() -> float; func max_zoom() -> float
func sheet_to_screen(p) -> Vector2; func screen_to_sheet(p) -> Vector2
func zoom_at(screen_point: Vector2, factor: float) -> void   # punkt pod kursorem stoi
func pan_screen(delta: Vector2) -> void; func look_at(sheet_point: Vector2, zoom := -1.0) -> void
func step(delta: float) -> bool   # wygładzanie; true gdy coś się ruszyło
func transform() -> Transform2D

class_name MuseumMap extends CanvasLayer
signal opened; signal closed
const LAYER := 62            # nad menu pauzy (60), pod czytnikiem notatek (65)
var layout: LevelLayout; var game: PersistentState; var guard_source: Callable; var night: NightConfig
var can_open: Callable       # false w czasie śmierci, świtu, końca (menu pauzy niedozwolone)
var is_open: bool; var tab: StringName; var view: MapView; var model: MapModel
func open(at_tab := &"") -> void; func close() -> void; func set_tab(tab) -> void; func next_tab(step := 1) -> void
func center_on_guard() -> void; func guard_sheet_point() -> Vector2
static func install(floor_game: FloorGame) -> MuseumMap
static func poster(layout: LevelLayout) -> PackedScene    # korzeń MapPoster (W1 stawia go na znaczniku)
```

## Decyzje wyglądu (refine §9.1)

- **Arkusz** 2400 × 1700 (proporcja A), złamany na trzy w pionie (x 800, 1600) i na pół w poziomie (y 850); każdy z 6 paneli odrobinę inaczej oświetlony, przetarcia i drobne dziurki na skrzyżowaniach zagięć, pożółkłe brzegi, blady ślad kubka kawy w rogu. Druk ma lekką przezroczystość (ziarno papieru przebija), zagięcia i przetarcia leżą **nad** drukiem, ołówek **nad** zagięciami.
- **Nagłówek:** piktogram portyku, „MUZEUM MIEJSKIE / CITY MUSEUM” (Georgia, rozstrzelone), podtytuł „Plan zwiedzania · Piętro I — Wielki Dziedziniec”, nazwa strony (Parter / Podziemia / Dach), stopka wydania.
- **Parter:** szara bryła budynku (obrys stref) — na niej sale publiczne w kolorach skrzydeł (piasek Egiptu, łupkowy błękit Asyrii, biel z greckim błękitem, zieleń z mosiądzem Oświecenia, czerwony lak Azji, turkus Ameryk, jasny kamień dziedzińca), cienka ciemniejsza krawędź, otwory drzwi między salami publicznymi, schody (stopnie), antresole przerywaną linią, Czytelnia jako koło, piktogramy (informacja, kawiarnia, sklep, szatnia, kasa, wejście), duże rozstrzelone nazwy skrzydeł (pionowo w długich skrzydłach), róża wiatrów, podziałka. Sale służbowe i sekretne to **szara pustka** — luki same podpowiadają ukryte miejsca.
- **Podziemia / Dach:** jasny obrys budynku dla orientacji i nadruk „Wstęp tylko dla personelu” / „Dach — wstęp wzbroniony”; resztę dorysowuje ołówek.
- **Legenda** (prawy panel): kolory skrzydeł, piktogramy, schody, „Jesteś tutaj”, „Prosimy nie dotykać eksponatów”, godziny otwarcia; pod spodem **ołówkiem**: „Na dziś:” + cel i klucz strażnika (✓ byłem, ○ przystań, ! strażnik, ? zamknięte).
- **Ołówek:** grafit (szaroniebieski, półprzezroczysty, ziarno z shadera), linie z płynnym drżeniem i „przestrzeleniem” na rogach, kreskowanie skośne w salach dorysowanych, pismo odręczne lekko pochylone; ikony szkicowane kreską (broń, pieczęć, odłamek, bezpiecznik/klucz, kartka, figura szachowa, gwiazdka sekretu), „!” (przekreślony po pokonaniu), „?” z ikoną zamka (łańcuch, deski, pieczęć, błyskawica, rysa, lina, hak, zasuwa, krata), strzałka celu z „tu!” i kółkiem.
- **Jesteś tutaj:** czerwona drukowana strzałka (kierunek patrzenia) z pulsującym kręgiem i podpisem; na innej zakładce — czerwona kropka przy nazwie zakładki strażnika.
- **Widok:** otwarcie na zakładce strażnika, wyśrodkowane na nim, powiększenie 1,6 × dopasowania; zoom od dopasowania do 5 ×; nazwy sal pojawiają się od powiększenia, przy którym ich pismo ma ≥ 11 px; wielkie nazwy skrzydeł bledną przy dużym zoomie.
- **Sterowanie w planie:** M, Esc, pad B / Back zamyka; Q / E, Tab, 1–3, LB / RB, klik w zakładkę — piętro; kółko, + / −, spusty pada — zoom; przeciąganie myszą, WASD / strzałki, lewa gałka — przesuw; Spacja / pad Y — „gdzie jestem”.
- **Wydajność:** papier i nakładka to tekstury (raz na proces), druk — lista rysowania nagrana raz na zakładkę (przerysowanie tylko przy zmianie zakładki lub języka), ołówek — przy otwarciu, podpisy i skrzydła — przezroczystość warstwy zależna od zoomu (bez przerysowania); co klatkę tylko wygładzanie widoku i puls strzałki. Tablica na ścianie: tekstura renderowana raz na proces (SubViewport → `ImageTexture`, pamięć podręczna wg sygnatury układu i języka).

---

### Zadanie 1: Akcja `map` (M, pad Back)

**Pliki:** `src/core/game_input.gd`; test `tests/integration/test_museum_map.gd`.

- [ ] **Krok 1 — test (czerwony):** `test_map_action_is_bound_to_m_and_the_pad_back_button` — `InputMap.has_action(&"map")`, wśród zdarzeń `InputEventKey` z `physical_keycode == KEY_M` i `InputEventJoypadButton` z `button_index == JOY_BUTTON_BACK`; `GameInput.key_label(&"map") == "M"`.
- [ ] **Krok 2:** `bash tools/run_tests.sh --filter=test_museum_map` → FAIL.
- [ ] **Krok 3 — kod:** `KEYS[&"map"] = [KEY_M]`; nowy słownik `JOY_BUTTONS := {&"map": [JOY_BUTTON_BACK]}` rejestrowany w `_enter_tree()` (`InputEventJoypadButton`, `device = -1`).
- [ ] **Krok 4:** PASS. **Krok 5:** commit „Map action: M and the pad's Back button”.

### Zadanie 2: Rzutowanie i widok

**Pliki:** `src/ui/map/map_projection.gd`, `src/ui/map/map_view.gd`, `src/ui/map/map_style.gd`; test `tests/unit/test_map_model.gd`.

- [ ] **Krok 1 — testy:** `test_projection_fits_the_floor_with_north_up` (granice piętra 177 × 139 m w obszarze mapy: skala jednolita, wszystkie rogi w `area`, mniejsze z → mniejsze y, środek świata ↔ środek obszaru), `test_projection_round_trips` (świat → arkusz → świat, błąd < 1e-4), `test_view_zoom_keeps_the_point_under_the_cursor`, `test_view_clamps_to_the_sheet_and_zoom_limits`, `test_view_smoothing_reaches_the_target` (po 60 krokach 1/60 s błąd < 0,5 px).
- [ ] **Krok 2:** `--filter=test_map_model` → FAIL.
- [ ] **Krok 3 — kod:** `MapProjection.fit()` z marginesem 3 m; `MapView` (zoom wykładniczo wygładzany, `fit_zoom()` = arkusz w 94 % × 86 % ekranu, min = fit, max = 5 × fit; środek przycięty do arkusza, a gdy arkusz węższy niż ekran — wyśrodkowany). `MapStyle`: `SHEET := Vector2(2400, 1700)`, `MAP_AREA := Rect2(50, 230, 1740, 1430)`, `LEGEND_AREA := Rect2(1830, 230, 520, 1430)`, `FOLDS_X := [800.0, 1600.0]`, `FOLD_Y := 850.0`.
- [ ] **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 3: Model — sale, zakładki, druk, ołówek, ukryte

**Pliki:** `src/ui/map/map_state.gd`, `src/ui/map/map_model.gd`; test `tests/unit/test_map_model.gd` (układ: `Floor1Layout.create()`, ok. 5 ms).

- [ ] **Krok 1 — testy:**
  - `test_tabs_follow_the_height` (y −6 → podziemia, 0 i 7 → parter, 22,5 → dach); `test_a_stairwell_shows_on_both_of_its_floors` (`booth_stairs`: parter + podziemia; `roof_stairs`: parter + dach).
  - `test_only_public_ground_rooms_are_printed` — nowa gra: każda sala `public && !secret` parteru ma `look == PRINTED`, żadna z `booth`, `basement`, `roof`, przystani służbowych ani sekretów nie jest drukowana i nie jest widoczna.
  - `test_staff_rooms_are_pencilled_in_once_visited` — `rooms_visited = [booth_corridor, basement_boiler]` → oba `PENCIL` (kotłownia na zakładce podziemi); `basement_switchboard` dalej `HIDDEN`.
  - `test_secret_rooms_never_print_and_pencil_only_after_discovery` — `egypt_cache` ukryta w nowej grze; po wizycie `PENCIL`, nigdy `PRINTED`; przejście do niej (`egypt_stairs_cache`) nie jest drukowane.
  - `test_known_havens_are_pencilled_even_unvisited` — `havens = [security, conservator]` → `booth_security` i `egypt_conservator` `PENCIL` z `haven` ustawionym.
  - `test_outline_drops_shared_edges` — dwa stykające się prostokąty → obrys bez wspólnego odcinka; suma długości = obwód sumy; `test_the_reading_room_is_round` (`court_reading` okrągła, `court` nie); `test_balconies_are_upper_rooms` (`court_balcony`, `entrance_gallery` `upper`).
  - `test_doors_print_only_between_printed_rooms` — `egypt_vestibule_gallery` drukowane; `egypt_tombs_conservator` nie (dopóki konserwator ukryty); `asia_garden_wall` (spękany mur, styl PANEL) nigdy.
  - `test_labels_anchor_inside_their_room` — kotwica każdej sali leży w jej części i poza innymi salami tej zakładki (dziedziniec: poza bębnem).
  - `test_pictograms_come_from_the_pieces` — `info`, `cafe`, `shop`, `cloakroom`, `tickets`, `entrance` na parterze.
  - `test_state_from_game` — `MapState.from_game(GameState)` kopiuje listy i liczy cel nowej gry (`GOAL_TICKET_KEY`, krok `pistol_key`).
- [ ] **Krok 2:** FAIL. **Krok 3 — kod:** jak w kontrakcie (kotwica: siatka 9 × 9 w największej części, maks. odległość od brzegów i od innych sal zakładki). **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 4: Model — adnotacje ołówkiem i cel

**Pliki:** `src/ui/map/map_model.gd`; test `tests/unit/test_map_model.gd`.

- [ ] **Krok 1 — testy:**
  - `test_visited_rooms_get_a_tick` (jeden `TICK` na odwiedzoną widoczną salę, w jej kotwicy; nie dla nieodwiedzonych).
  - `test_havens_get_a_circle` (`HAVEN` dla każdej znanej przystani, na zakładce jej sali).
  - `test_finds_get_icons` — broń (`weapons` → `WEAPON` przy znaczniku `weapon_shotgun`), przedmioty (`fuse_basement` → `ITEM` na podziemiach, `pistol_key` → `ITEM` przy `ticket_drawer`), notatki (`notes` → `NOTE` przy znaczniku; `note_heniek` przez alias `WorldFeatures.NOTE_ALIASES`), szachy (`chess_found` → `CHESS`), sekrety (`secrets` → `SECRET`).
  - `test_guardians_get_an_exclamation_crossed_when_defeated` — arena nieodwiedzona: brak; po wizycie w `egypt_colossus`: `GUARDIAN` nieprzekreślony; po `guardians_defeated += colossus`: przekreślony + `SEAL` i `SHARD` obok.
  - `test_known_closed_gates_get_a_question_mark_with_their_lock` — po wizycie w `egypt_colossus`: `GATE seal_khorsabad` z `lock == SEAL` w środku otworu; po `gates_open += seal_khorsabad` znika; brama nieznana (`shutter_asia` bez wizyt) — brak; `chain_gatling` (brama na znaczniku) przy znaczniku po wizycie w Czytelni.
  - `test_the_goal_points_at_its_place` — nowa gra: `goal.step == pistol_key`, `placed`, `at` = znacznik `ticket_drawer`, zakładka parter; cel `fuse_basement` → zakładka podziemi; po końcu (`floor1_complete`) `GOAL_EPILOGUE` bez miejsca.
- [ ] **Krok 2:** FAIL. **Krok 3 — kod.** **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 5: Papier (Python) i ziarno grafitu

**Pliki:** `tools/map/build_paper.py`, `assets/ui/map/leaflet_paper.jpg`, `assets/ui/map/leaflet_wear.png`, `assets/ui/map/graphite_grain.png` (+ `.import` z mipmapami).

- [ ] **Krok 1:** generator (ziarno `numpy.random.default_rng(1987)`): kremowa baza z wielooktawowym szumem i włóknami, cieniowanie 6 paneli, zagięcia (cień 1 px + światło 1–2 px + miękki gradient, naprzemiennie „góra/dolina”), przetarcia wzdłuż zagięć, wytarte dziurki na skrzyżowaniach, pożółkłe brzegi i rogi, ślad kubka (alfa ≤ 0,08). Nakładka `wear` (RGBA): zagięcia, przetarcia, zabrudzenia — reszta przezroczysta. Ziarno grafitu 256 × 256, kafelkowalne.
- [ ] **Krok 2:** `python tools/map/build_paper.py` → pliki; obejrzeć PNG/JPG (Read); import Godota (`--import`), `.import` z `mipmaps/generate=true`.
- [ ] **Krok 3:** commit „Leaflet paper, folds and wear, graphite grain (generated)”.

### Zadanie 6: Płótno, czcionki i warstwa druku

**Pliki:** `src/ui/map/map_canvas.gd`, `src/ui/map/map_fonts.gd`, `src/ui/map/map_drawing.gd`; test `tests/unit/test_map_drawing.gd`.

- [ ] **Krok 1 — testy (na `MapRecorder`):** `test_print_fills_every_printed_room_in_its_wing_colour` (dla każdej sali `PRINTED` parteru jest wypełnienie w `MapStyle.fill(zone)` pokrywające jej kotwicę), `test_print_never_touches_a_secret_room` (żadne wypełnienie druku nie zawiera środka sali sekretnej poza szarą bryłą budynku — kolor bryły ≠ kolor skrzydła), `test_print_names_the_wings_and_the_museum` (teksty `tr(ZONE_EGYPT).to_upper()`… i `tr(MAP_TITLE)`), `test_legend_lists_every_wing_and_pictogram`, `test_basement_page_prints_only_the_staff_notice` (na zakładce podziemi brak wypełnień w kolorach skrzydeł, jest `MAP_STAFF_ONLY`).
- [ ] **Krok 2:** `--filter=test_map_drawing` → FAIL.
- [ ] **Krok 3 — kod:** `MapCanvas` (`rect`, `polygon`, `polyline`, `circle`, `text` (linia bazowa, kąt), `texture`, `layer`); `MapCanvasItem` (`draw_rect`, `draw_colored_polygon`, `draw_polyline(…, antialiased)`, `draw_circle`, `draw_set_transform` + `draw_string`); `MapRecorder` (`ops: Array[Dictionary]`, `to_json()`, zapytania testowe `fills_at(point)`, `texts()`); `MapDrawing.print_page(canvas, model, projection, tab)`, `header()`, `legend()`, `wings()`, `names()`; `MapFonts` (`print`, `bold`, `title`, `hand`; `width()`, `wrap()`, tekst rozstrzelony znak po znaku).
- [ ] **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 7: Warstwa ołówka

**Pliki:** `src/ui/map/map_drawing.gd`, `src/ui/map/graphite.gdshader`; test `tests/unit/test_map_drawing.gd`.

- [ ] **Krok 1 — testy:** `test_pencil_outlines_and_hatches_staff_rooms` (sala `PENCIL` ma linie ołówka w swoich granicach + co najmniej 3 linie kreskowania), `test_pencil_strokes_wobble_deterministically` (ten sam stan → identyczna lista operacji; linia nie jest prosta: odchyłka > 0,2 px), `test_pencil_marks_every_annotation` (dla każdego `Mark` zakładki jest operacja w promieniu 24 px od jego punktu), `test_goal_arrow_points_at_the_goal` (strzałka kończy się ≤ 20 px od punktu celu; brak na innych zakładkach), `test_guard_notes_write_the_goal` (tekst `tr(goal_key)` w panelu legendy, łamany do szerokości panelu).
- [ ] **Krok 2:** FAIL. **Krok 3 — kod:** pociągnięcia z drżeniem (dwie sinusoidy z ziarnem z id) i „przestrzeleniem” 2–4 px, podwójne cienkie przejście, kreskowanie przycięte do części sali, ikony (`_icon_*`), „!” i „?”, strzałka (krzywa kwadratowa + grot), notatka i klucz strażnika. Shader: `COLOR.a *= mix(0.55, 1.0, ziarno(pozycja arkusza))`.
- [ ] **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 8: Podgląd bez okna

**Pliki:** `tests/support/map_preview.gd`, `tools/map/render_preview.py`, `tools/run_map_preview.sh`.

- [ ] **Krok 1:** skrypt Godota (SceneTree): dla stanów `new_game`, `after_egypt`, `after_basement`, `late_game` i trzech zakładek zapisuje `tests/_out/map/<stan>_<zakładka>.json` (rekorder: papier, druk, zużycie, nazwy, ołówek, „tu jesteś”) + `poster.json`.
- [ ] **Krok 2:** renderer pycairo: tekstury papieru i nakładki, czcionki systemowe (toy API), warstwa ołówka maskowana ziarnem; wyjście `tests/_out/map/<…>.png` (arkusz 1:1) i powiększone wycinki `<…>_zoom.png`.
- [ ] **Krok 3:** `bash tools/run_map_preview.sh` → obejrzeć PNG (Read), poprawiać styl do skutku (kolory, grubości, pismo, czytelność, równowaga strony).
- [ ] **Krok 4:** commit „Map previews without a window (JSON display list → cairo)”.

### Zadanie 9: Ekran planu

**Pliki:** `src/ui/museum_map.gd`, `src/ui/map/map_sheet_layer.gd`; test `tests/integration/test_museum_map.gd` (bez całego muzeum: `MuseumMap` z układem, `GameState` i atrapą strażnika).

- [ ] **Krok 1 — testy:** `test_m_opens_and_pauses_and_m_closes` (wejście: `Input.parse_input_event` akcji `map`; po otwarciu `get_tree().paused`, `GameInput.top_ui() == map`, `not GameInput.gameplay_input()`; drugie M zamyka, pauza zdjęta, wejście oddane po puszczeniu klawisza), `test_escape_closes_without_the_pause_menu`, `test_it_opens_on_the_guards_floor_centred_on_him` (strażnik w kotłowni → zakładka podziemi; punkt strażnika ≈ środek ekranu po wygładzeniu), `test_tabs_switch_and_wrap` (`next_tab`, Q/E, 1–3, klik), `test_wheel_zooms_about_the_cursor_and_drag_pans`, `test_names_fade_in_with_zoom` (przezroczystość warstwy nazw rośnie z zoomem), `test_no_open_while_not_allowed` (`can_open` false).
- [ ] **Krok 2:** FAIL. **Krok 3 — kod:** warstwy jak w „Wydajność”, wejście w `_input` (jak czytnik notatek: zamknięcie i nawigacja nie trafiają do menu pod spodem), `_process` tylko gdy otwarty.
- [ ] **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 10: Podpięcie do gry (Piętro I, menu pauzy, pomoc)

**Pliki:** `src/game/floor1/floor_game.gd`, `src/ui/pause_menu.gd`, `src/ui/museum_map.gd` (`install`); test `tests/integration/test_museum_map.gd`.

- [ ] **Krok 1 — testy:** `test_floor_one_installs_the_map` (muzeum Piętra I: `floor_game.map != null`, menu pauzy ma przycisk planu, linia pomocy `HUD_HELP_MAP`), `test_the_pause_menu_opens_the_map_over_it` (otwarcie z menu: plan nad menu, Esc zamyka plan, menu nadal otwarte, gra nadal w pauzie), lobby: brak planu i przycisku.
- [ ] **Krok 2:** FAIL. **Krok 3 — kod:** `install()` ustawia układ, zapis, strażnika, noc (zamknięte przejście do celu), `can_open` = menu pauzy dozwolone; menu pauzy: `museum_map` jak `note_reader`. **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 11: Plan na ścianie (`MuseumMap.poster`)

**Pliki:** `src/ui/map/map_poster.gd`, `src/ui/museum_map.gd`; testy `tests/integration/test_museum_map.gd`.

- [ ] **Krok 1 — testy:** `test_poster_is_a_board_with_the_printed_map_and_a_red_dot` (instancja sceny: deska, arkusz zwrócony w −Z znacznika, kropka w miejscu rzutu pozycji tablicy), `test_poster_is_cached_per_layout_and_language`, `test_floor_one_hangs_a_map_on_every_museum_map_marker` (muzeum Piętra I: liczba `MapPoster` = liczba znaczników `museum_map_*`).
- [ ] **Krok 2:** FAIL. **Krok 3 — kod:** `MapPoster` (`_ready`: deska i arkusz `QuadMesh` z materiałem; tekstura z pamięci albo SubViewport + `MapSheetLayer` druku → po `RenderingServer.frame_post_draw` kopia do `ImageTexture` i zwolnienie widoku; bez renderera — jasny papier zastępczy). **Krok 4:** PASS. **Krok 5:** commit.

### Zadanie 12: Pełny zestaw, podglądy końcowe, raport

- [ ] `bash tools/run_tests.sh` — cały zestaw zielony (bez linii `ERROR`).
- [ ] `bash tools/run_map_preview.sh` — końcowe podglądy w `tests/_out/map/`.
- [ ] Uzupełnić sekcję „Stan wykonania” poniżej, commit.

---

## Samokontrola planu

- §9.1: ulotka w kolorach skrzydeł (Z6), legenda PL/EN (Z6), „Jesteś tutaj” (Z7/Z9), ołówkowe dopiski: ptaszki, kółka, znaleziska, „!”, „?” z zamkiem (Z4, Z7), tylko sale publiczne drukowane, służbowe/podziemia/dach ołówkiem, sekrety nigdy drukowane — luki (Z3, Z6), rysowane z `LevelLayout` (Z3), zakładki (Z3, Z9), pauza (Z9), plan na ścianie (Z11). §3.3: cel ołówkiem (Z4, Z7). Wymagania kontrolera: M / z pauzy / pad (Z1, Z10), przesuw i zoom (Z9), nazwy przy powiększeniu (Z9), wydajność (Z9, Z11), testy (wszystkie).
- Nazwy spójne: `MapModel.build`, `MapState.from_game`, `MapProjection.fit`, `MapView.zoom_at`, `MapDrawing.print_page`, `MuseumMap.install/poster`, `MapPoster`.

## Stan wykonania (3.10)

Zadania 1–12 wykonane; `pietro-1` scalone raz po zadaniu 11 (wszystkie strefy W2–W5b), plan sprawdzony na prawdziwym piętrze. Testy planu: `test_map_model` (26), `test_map_drawing` (11), `test_museum_map` (15) — zielone; pełny zestaw po scaleniu: **1607 testów zielonych**, bez linii `ERROR`.

**Pomiar otwarcia (bez okna, późna gra):** model 100 ms za pierwszym razem na układ (punkty podpisów; liczone już przy instalacji, w czasie wyciemnienia nocy), potem ok. 10 ms; geometria warstw 18–40 ms; potem nic na klatkę poza przesunięciem arkusza i pulsem strzałki.

**Odstępstwa od planu (świadome):**
1. Rysowanie rozdzielone na `MapDrawing` (druk, podpisy, ekran) i `MapPencil` (ołówek); płótno w trzech plikach (`MapCanvas`, `MapCanvasItem`, `MapRecorder`).
2. Druk na ekranie nie jest bitmapą, lecz listą rysowania nagraną raz na zakładkę (renderer ją trzyma; zoom do 5× bez rozmycia pisma); bitmapy to papier i nakładka zużycia (Python), a tekstura „na ścianę” powstaje raz na proces (SubViewport → `ImageTexture`).
3. Zakładki pięter: strona = strefa dla podziemi i dachu, wysokość dla reszty (próg podziemi −4 m: zapadnięta Sala Lwów z Niniwy, −3 m, zostaje na parterze); znaczniki i cel — na stronie swojej sali; drzwi — na stronie, którą dzielą oba pokoje.
4. Sale sekretne po odkryciu są dorysowane ołówkiem (polecenie kontrolera; plan nadrzędny mówił „nigdy”); drukowane nie są nigdy.
5. Pomieszczenie wysoko nad innym (wieża schodów nad kanciapą, antresole) jest rysowane przerywaną linią.
6. Podpowiedź klawiszy w planie zawsze klawiaturowa (gra nie ma jeszcze podpowiedzi zależnych od pada).

**Otwarte kwestie:** wygląd na GPU (ziarno grafitu z shadera, ostrość pisma przy dużym zoomie) sprawdzony tylko w podglądach pycairo — do obejrzenia w oknie; „!” dla T-Reksa nie jest rysowany (cel prowadzi do niego strzałką).
