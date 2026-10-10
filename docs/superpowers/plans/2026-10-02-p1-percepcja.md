# Percepcja i terytoria eksponatów — plan implementacji (P1)

> **Dla wykonawcy-agenta:** wymagany pod-skill: superpowers:executing-plans albo superpowers:subagent-driven-development. Kroki mają pola `- [ ]` do odhaczania.
>
> Stan: 2 października 2026 (noc). Wykonawca: Claude, drzewo robocze `.claude/worktrees/p1-ai`, gałąź `p1-ai` od `pietro-1` @ `b86f61c`.
> Autorytet: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §7.2 (percepcja i terytoria), §1 (diagnoza „hordy”), §7.5 (trudność), §12 (testy percepcji). Doprecyzowania i odstępstwa — na końcu planu.

**Cel:** eksponaty przestają rzucać się hordą na strażnika zaraz po wyjściu z kanciapy. Widzą stożkiem i zależnie od światła, słyszą przez otwarte przejścia, gubią ślad, przeszukują, wracają na posterunek, trzymają się terytorium, a polujących naraz jest najwyżej 8.

**Architektura:** czysta maszyna stanów `EnemyBrain` (RefCounted, testowana bez sceny) dostaje nowe stany i kontekst ustawiany co klatkę przez `Enemy`. Geometria percepcji, zasięgi, słuch przez graf sal, smycz i trasy patroli to czyste funkcje `PerceptionRules`. Świat percepcji poziomu (`PerceptionWorld`: jasność, sala punktu, graf, drzwi, trudność, rejestr eksponatów, limit polujących, rozsyłanie hałasu) to statyczny kontrakt, który inne poziomy konfigurują (`LayoutIllumination` + `LevelPerception` dla lobby; nowe piętro — ten sam interfejs). `Enemy` łączy jedno z drugim i porusza ciałem.

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh` (bezokienkowo, `--fixed-fps 60`).

---

## Liczby (punkt startowy do strojenia)

| Co | Wartość | Skąd |
|---|---|---|
| Stożek wzroku | 120° (popiersie, portret: 160°) | §7.2 |
| Wyczucie bliskie | 3,5 m dookoła | §7.2 |
| Zasięg: oświetlony / półmrok / ciemność | 22 / 12 / 7 m | §7.2 |
| Progi jasności (model `LayoutIllumination`, 0..1) | oświetlony ≥ 0,45; półmrok ≥ 0,15 | strojenie (patrz „Model jasności”) |
| Latarka włączona | zawsze „oświetlony” | §7.2 |
| Raca w pobliżu | jak lampa: 3,4 energii, 10 m | `FlareLight` |
| Księżyc pod świetlikiem | 0,3 (półmrok); pełnia 0,5 | doprecyzowanie |
| **Śpiący eksponat (DORMANT)** | **×0,6 zasięgu i wyczucia** (13 / 7 / 4 m, wyczucie 2,1 m) | **doprecyzowanie** (patrz niżej) |
| Sprawdzanie wzroku | co 0,2 s, rozłożone; śpiący daleko (> 32 m) co 0,6 s | §7.2, wydajność |
| Podejrzliwość (SUSPICIOUS) | wosk 0,8 s, rycerz 1,0, wilk 0,6, raptor 0,6, popiersie 0,8; portret 1,5 (jego „śledzenie oczami”) | §7.2: 0,6–1,0 s |
| Pamięć po utracie wzroku | 1,5 s (zna pozycję strażnika) | §7.2 |
| Przeszukiwanie | dojście ≤ 10 s, potem rozglądanie 6–10 s (nowy punkt co 2,5 s, ≤ 3 m) | §7.2 |
| Przystań | przeszukiwanie przy drzwiach 8 s, potem powrót | §7.2 |
| Powrót | ≤ 40 s, potem „osiada” tam, gdzie stoi | zabezpieczenie |
| Tempo (część `move_speed`) | polowanie 1,0; sprawdzanie 0,7; przeszukiwanie 0,55; powrót 0,6; patrol 0,45 | strojenie |
| Słuch (m) | pięści, paralizator 6; pistolet 18; sztucer 24; strzelba 22; harpunnik 12; kartaczownica, ognista skrzynia, wybuch 30; rakietnica 15; sprint / lądowanie 7; szkło, szafka pożarowa 16 | §7.2 |
| Tłumienie | ×0,6 na każde otwarte przejście; zamknięte blokuje; najwyżej 4 przejścia | §7.2 |
| Smycz | 28 m od domu albo sala spoza terytorium; wilki i raptory 40 m; wezwani — bez smyczy | §7.2 |
| Terytorium domyślne | dom + sale za przejściami OPEN/LOCKABLE (bez tajnych i krat) | §7.2 |
| Łańcuchowe budzenie | ta sama sala, linia wzroku, 8 m, ≤ 2 na budzącego, budzeni idą sprawdzić (nie polują od razu) i nie budzą dalej | §7.2 |
| Limit polujących | 8 w promieniu 30 m od strażnika; nadmiarowi czekają 10 m od niego | §7.2 |
| Trudność | wzrok ×0,75 / ×1,0 / ×1,15; limit 8 / 8 / 10 | §7.5 |
| Łagodna noc 1 | sale na drodze kanciapa → sala bossa: bez wilków i raptorów (→ wosk), najwyżej 2 czuwające (patrol), reszta śpi | §7.2 „Pierwsze 3 minuty nocy 1” |

**Dlaczego śpiący widzi gorzej (doprecyzowanie):** §7.2 mówi o eksponacie, który „śpi jako eksponat”. Bez osłabienia śpiący wosk w oświetlonej sali budziłby się na 22 m, gdy tylko strażnik minie go od przodu, i sala pełna figur wstawałaby naraz — dokładnie to, co mamy usunąć. Śpiący widzi tym samym stożkiem, ale na 0,6 zasięgu; obudzony (patrol, sprawdzanie, polowanie) — na pełny. Skradanie się obok śpiących (bez latarki, bez biegu, bez strzałów) staje się możliwe i czytelne.

## Model jasności (`LayoutIllumination`)

Dla punktu (pierś strażnika, 1 m nad stopami):
- bierzemy lampy tej samej sali (balkon, który nie jest wycięty w bryle, dzieli światło z holem, w którym wisi); punkt poza salami — wszystkie lampy w zasięgu,
- wkład lampy: `energia × luminancja(koloru) × (1 − (d/zasięg)²)`, 0 poza zasięgiem i poza stożkiem reflektora; lampa liczy się, tylko gdy jej grupa w tej sali ma prąd (`powered(group, room)`),
- suma ograniczona do 1, plus księżyc (`moon_level`) pod świetlikiem sali.

Lobby (zasilane): galeria, zbrojownia i hol ≥ 0,45 (oświetlone), środek dioramy ~0,35 (półmrok), w awarii prądu hol ~0 (ciemność) poza pasami świetlików (0,3) i czerwonymi lampami awaryjnymi (luminancja 0,3 → półmrok tuż przy nich).

## Pliki

| Plik | Odpowiada za |
|---|---|
| `src/enemies/enemy_brain.gd` (przepisany) | `EnemyBrain`: stany DORMANT, SUSPICIOUS, INVESTIGATE, HUNT, SEARCH, RETURN, PATROL, ATTACK, STUNNED, DESTROYED; pamięć, cele marszu, przystań, smycz, limit, patrol |
| `src/enemies/perception/perception_rules.gd` (nowy) | `PerceptionRules`: stałe i czyste funkcje — stożek, światło → zasięg, hałas broni, słuch przez graf, terytorium, smycz, trasa patrolu |
| `src/enemies/perception/perception_world.gd` (nowy) | `PerceptionWorld`: `configure()`/`reset()` (kontrakt), trudność, rejestr eksponatów, jasność strażnika w klatce (latarka, race), limit polujących, rozsyłanie hałasu (`Events.weapon_fired`, `Events.noise_made`) |
| `src/enemies/perception/layout_illumination.gd` (nowy) | `LayoutIllumination`: jasność z `LightSpec`-ów + zasilanie grup + księżyc pod świetlikami |
| `src/enemies/perception/level_perception.gd` (nowy) | `LevelPerception`: podłączenie poziomu z `LevelLayout` (lobby, później piętro), dom i trasy patroli z gniazd spawnu |
| `src/enemies/enemy.gd` | percepcja (stożek, światło, LOS), dom/terytorium/smycz, słuch, łańcuchowe budzenie ≤ 2, ruch w nowych stanach, reakcje na stany (dźwięk, obrót głowy), wezwani |
| `src/enemies/portrait.gd`, `bust.gd`, `raptor.gd`, `raptor_pack.gd`, `wolf.gd`, `knight.gd`, `wax_figure.gd` | czasy podejrzliwości, smycz łowców, stado raptorów (budzi się razem), portret: własna reguła budzenia, nigdy nie śpi z powrotem |
| `src/enemies/crowd.gd` | rozpychanie wszystkich idących (nie tylko „CHASE”) |
| `src/enemies/visuals/exhibit_rig.gd`, `raptor_rig.gd` | oczy rozbłyskują w SUSPICIOUS; syk raptora w SUSPICIOUS |
| `src/game/night_spawner.gd` | dom (`home_room`), czuwający = PATROL z trasą (nie pościg) |
| `src/game/night_director.gd` | łagodna noc 1 (`_gentle_first_night`) |
| `src/game/museum.gd` | konfiguracja percepcji na starcie nocy, reset na wyjściu |
| `src/game/night_objective.gd`, `src/enemies/trex/boss_dev.gd`, `src/arena/sandbox.gd` | wezwani (`summoned`): polują od razu, bez smyczy |
| `src/props/emergency_cabinet.gd` | szkło = hałas 16 m przez `Events.noise_made` |
| `src/player/player.gd` | hałas sprintu i lądowania (7 m) |
| `src/weapons/flare_light.gd` | `lit_positions()` dla jasności |
| `src/audio/music.gd` | „zagrożenie” = czujni, „walka” = polujący |
| `src/fx/sfx.gd`, `tools/sfx/gen_sfx.py`, `assets/sfx/suspicion.wav` | dźwięk podejrzliwości |
| `tests/test_runner.gd` | `PerceptionWorld.reset()` + trudność w `_reset_globals()` |
| testy: `tests/unit/test_enemy_brain.gd` (przepisany), `tests/unit/test_perception_rules.gd`, `tests/unit/test_layout_illumination.gd`, `tests/integration/test_perception.gd`, `tests/integration/test_lobby_perception.gd` | nowe testy; istniejące testy wrogów aktualizowane świadomie |
| `docs/Nocna-Zmiana-specyfikacja.md` §4.2, §13.3 | opis nowej percepcji |

**Konwencje:** tabulatory, typowanie statyczne, angielskie identyfikatory i komentarze, teksty gracza przez `tr()`, `bash tools/run_tests.sh` zielony po każdym zadaniu (bez linii `ERROR`), commit po zadaniu ze stopką `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, nigdy `git add -A` (złącze `tools/godot`). Żadnych okien ani dźwięku.

---

## Zadanie 1: ten plan

- [ ] Zapisać plan, commit `Plan: exhibit perception and territories (P1)`.

## Zadanie 2: `PerceptionRules` — czyste reguły

**Pliki:** utwórz `src/enemies/perception/perception_rules.gd`, test `tests/unit/test_perception_rules.gd`.

- [ ] **Krok 1: test (najpierw czerwony)**

```gdscript
extends TestCase

func test_light_bands_give_the_three_ranges() -> void:
	assert_eq(PerceptionRules.sight_range(1.0), 22.0)
	assert_eq(PerceptionRules.sight_range(0.3), 12.0)
	assert_eq(PerceptionRules.sight_range(0.05), 7.0)
	assert_eq(PerceptionRules.sight_range(0.3, 16.0), 16.0 * 12.0 / 22.0, "an exhibit's own lit range scales the bands")

func test_the_cone_is_120_degrees_in_front() -> void:
	var ahead := Vector3.FORWARD
	assert_true(PerceptionRules.in_cone(ahead, Vector3(0, 0, -5), 120.0))
	assert_true(PerceptionRules.in_cone(ahead, Vector3(4, 0, -3), 120.0), "53 degrees off")
	assert_false(PerceptionRules.in_cone(ahead, Vector3(5, 0, -2), 120.0), "68 degrees off")
	assert_true(PerceptionRules.in_cone(ahead, Vector3(5, 0, -2), 160.0), "a bust's wide cone")
	assert_false(PerceptionRules.in_cone(ahead, Vector3(0, 0, 5), 120.0), "behind")

func test_weapon_noise_radii() -> void:
	assert_eq(PerceptionRules.weapon_noise(&"fists"), 6.0)
	assert_eq(PerceptionRules.weapon_noise(&"pistol"), 18.0)
	assert_eq(PerceptionRules.weapon_noise(&"gatling"), 30.0)
	assert_eq(PerceptionRules.weapon_noise(&"flare"), 15.0)
	assert_eq(PerceptionRules.weapon_noise(&"unknown_gun"), PerceptionRules.DEFAULT_WEAPON_NOISE)

func test_noise_carries_through_open_passages_only() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"d1", &"a", &"b")
	graph.add_door(&"d2", &"b", &"c")
	var open := func(_door: StringName) -> bool: return true
	var rooms := PerceptionRules.hearing_rooms(graph, &"a", open)
	assert_eq(rooms[&"a"], 1.0)
	assert_almost_eq(rooms[&"b"], 0.6)
	assert_almost_eq(rooms[&"c"], 0.36)
	var shut := func(door: StringName) -> bool: return door != &"d2"
	assert_false(PerceptionRules.hearing_rooms(graph, &"a", shut).has(&"c"), "a closed door blocks")

func test_territory_is_home_and_open_neighbours() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"d1", &"hall", &"gallery", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"d2", &"hall", &"diorama")
	graph.add_door(&"p", &"gallery", &"secret", RoomGraph.Kind.SECRET)
	var rooms := PerceptionRules.territory(graph, &"gallery")
	assert_true(rooms.has(&"gallery") and rooms.has(&"hall"))
	assert_false(rooms.has(&"diorama"), "a third room is outside")
	assert_false(rooms.has(&"secret"), "never through a false panel")

func test_leash_and_rooms() -> void:
	var home := Vector3.ZERO
	assert_false(PerceptionRules.out_of_bounds(Vector3(20, 0, 0), home, 28.0, &"b", [&"a", &"b"] as Array[StringName]))
	assert_true(PerceptionRules.out_of_bounds(Vector3(29, 0, 0), home, 28.0, &"b", [&"a", &"b"] as Array[StringName]))
	assert_true(PerceptionRules.out_of_bounds(Vector3(5, 0, 0), home, 28.0, &"c", [&"a", &"b"] as Array[StringName]))
	assert_false(PerceptionRules.out_of_bounds(Vector3(5, 0, 0), home, 28.0, &"", [&"a"] as Array[StringName]), "unknown room: the distance decides")

func test_patrol_route_stays_in_the_home_room() -> void:
	var room_of := func(point: Vector3) -> StringName: return &"hall" if absf(point.x) < 10.0 and absf(point.z) < 4.0 else &"other"
	var route := PerceptionRules.patrol_route(Vector3.ZERO, &"hall", room_of)
	assert_gt(route.size(), 1)
	for point in route:
		assert_eq(room_of.call(point), &"hall")
```

- [ ] **Krok 2:** `bash tools/run_tests.sh --filter=perception_rules` → FAIL (brak klasy).
- [ ] **Krok 3: implementacja** — stałe z tabeli liczb oraz:

```gdscript
static func sight_range(light: float, lit_range: float = LIT_RANGE) -> float:
	var scale := lit_range / LIT_RANGE
	if light >= LIT_LEVEL:
		return LIT_RANGE * scale
	return (DIM_RANGE if light >= DIM_LEVEL else DARK_RANGE) * scale

static func in_cone(facing: Vector3, to_target: Vector3, cone_deg: float) -> bool:
	var look := Vector2(facing.x, facing.z)
	var to := Vector2(to_target.x, to_target.z)
	if look.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return true
	return look.normalized().dot(to.normalized()) >= cos(deg_to_rad(cone_deg * 0.5))

static func hearing_rooms(graph: RoomGraph, from_room: StringName, door_open: Callable) -> Dictionary:
	var reach := {from_room: 1.0}
	var frontier: Array[StringName] = [from_room]
	for hop in MAX_HOPS:
		var next: Array[StringName] = []
		for room in frontier:
			for door in graph.doors_of_room(room):
				if door_open.is_valid() and not door_open.call(door):
					continue
				var rooms := graph.door_rooms(door)
				var other: StringName = rooms[1] if rooms[0] == room else rooms[0]
				if not reach.has(other):
					reach[other] = pow(PASSAGE_DAMPING, hop + 1)
					next.append(other)
		frontier = next
	return reach
```
`territory()` przechodzi po `doors_of_room(home)` z pominięciem `doors_of_kind(SECRET)` i `(GATE)`; `out_of_bounds()` = odległość płaska > smycz albo (sala znana i spoza listy); `patrol_route()` sprawdza 8 kierunków co 45° na 6 m i 3 m, zostawia punkty w sali domu (`room_of`), zwraca dom + do 3 punktów (pusta tablica, gdy żaden nie pasuje albo brak sal).
- [ ] **Krok 4:** test zielony. **Krok 5:** commit `Perception rules: cone, light bands, hearing graph, territory, leash`.

## Zadanie 3: `EnemyBrain` — nowa maszyna stanów

**Pliki:** przepisz `src/enemies/enemy_brain.gd`, przepisz `tests/unit/test_enemy_brain.gd`.

Kontekst (pola ustawiane przez `Enemy` przed `update()`): `position`, `guard`, `guard_sheltered`, `out_of_bounds`, `guard_in_bounds`, `may_hunt`, `relentless`. Pamięć: `home`, `patrol`, `last_known`, `goal`, `rest_state`. Wejścia: `update(delta, sees_target, distance)`, `wake()` (pełny alarm), `alarm(point)` (trafienie: wie skąd), `hear(point, follow)` (hałas, budzenie przez sąsiada), `stun()`, `destroy()`, `start_patrol()`. Zapytania: `knows_guard()`, `walking()`, `pace()`, `is_awake()`, `is_hunting()`, `is_alerted()`.

- [ ] **Krok 1: testy przejść (czerwone)** — m.in.:

```gdscript
func test_sight_makes_it_suspicious_then_it_hunts() -> void:
	brain.guard = Vector3(0, 0, -8)
	brain.update(0.1, true, 8.0)
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	brain.update(brain.reaction_time, true, 8.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)

func test_a_noise_is_investigated_never_hunted() -> void:
	brain.hear(Vector3(10, 0, 0), true)
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	brain.update(brain.reaction_time + 0.01, false, INF)
	assert_eq(brain.state, EnemyBrain.State.INVESTIGATE)
	assert_eq(brain.goal, Vector3(10, 0, 0))

func test_lost_sight_is_remembered_for_a_moment_then_searched() -> void:
	_to_hunt()
	brain.guard = Vector3(3, 0, -9)
	brain.update(1.0, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	assert_eq(brain.last_known, Vector3(3, 0, -9), "tracked within the memory")
	brain.guard = Vector3(20, 0, -9)
	brain.update(0.6, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	assert_eq(brain.last_known, Vector3(3, 0, -9), "the last tracked point, not where he went")

func test_search_ends_in_return_and_return_ends_at_rest() -> void:
	# search: walk there, look around 6-10 s, then home; home: back to sleep
	...

func test_haven_search_lasts_eight_seconds() -> void:
	_to_hunt()
	brain.guard_sheltered = true
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	brain.update(7.8, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	brain.update(0.2, false, INF)
	assert_eq(brain.state, EnemyBrain.State.RETURN)

func test_the_hunter_cap_makes_it_wait_at_the_edge() -> void:
	brain.may_hunt = false
	brain.position = Vector3(0, 0, 20)
	brain.guard = Vector3.ZERO
	brain.update(0.1, true, 20.0)
	brain.update(brain.reaction_time, true, 20.0)
	assert_eq(brain.state, EnemyBrain.State.INVESTIGATE)
	assert_almost_eq(brain.goal.distance_to(Vector3.ZERO), EnemyBrain.WAIT_EDGE, 0.01)
	brain.may_hunt = true
	brain.update(0.1, true, 12.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)

func test_leaving_its_bounds_sends_it_home() -> void:
	_to_hunt()
	brain.out_of_bounds = true
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN)
	brain.out_of_bounds = false
	brain.guard_in_bounds = false
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN, "a guard beyond its leash is let go")

func test_relentless_never_searches_nor_returns() -> void:
	brain.relentless = true
	_to_hunt()
	brain.out_of_bounds = true
	brain.update(5.0, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
```
plus zachowane: atak tylko w zasięgu, uderzenie raz po zamachu, ogłuszenie przerywa zamach i kończy się polowaniem, dłuższe ogłuszenie wygrywa, zniszczenie ostateczne, sygnały zmian stanu, patrol idzie po trasie z pauzą.
- [ ] **Krok 2:** czerwone. **Krok 3:** implementacja (szkic stanów):

```gdscript
enum State { DORMANT, SUSPICIOUS, INVESTIGATE, HUNT, SEARCH, RETURN, PATROL, ATTACK, STUNNED, DESTROYED }

func update(delta: float, sees_target: bool, distance: float) -> void:
	match state:
		State.DORMANT, State.PATROL:
			if sees_target:
				_notice(guard, true)
			elif state == State.PATROL:
				_patrol(delta)
		State.SUSPICIOUS:
			_timer -= delta
			if sees_target:
				_spotted = true
				last_known = guard
			if guard_sheltered and _spotted:
				_search_haven()
			elif _timer <= 0.0:
				if _spotted:
					_hunt_or_wait()
				elif _follow:
					_investigate(last_known)
				else:
					_rest()
		State.INVESTIGATE:
			if sees_target and guard_in_bounds:
				last_known = guard
				_hunt_or_wait()
			elif out_of_bounds and not relentless:
				_go_home()
			elif not _waiting and _travel(delta):
				_search(last_known)
		State.HUNT:
			_track(delta, sees_target)
			if guard_sheltered and not relentless:
				_search_haven()
			elif not relentless and (out_of_bounds or not guard_in_bounds):
				_go_home()
			elif _memory <= 0.0 and not relentless:
				_search(last_known)
			elif distance <= attack_range:
				_enter(State.ATTACK)
		State.SEARCH:
			if sees_target and guard_in_bounds and not guard_sheltered:
				last_known = guard
				_hunt_or_wait()
			elif out_of_bounds and not relentless:
				_go_home()
			else:
				_look_around(delta)
		State.RETURN:
			if sees_target and guard_in_bounds:
				last_known = guard
				_hunt_or_wait()
			else:
				_walk_home(delta)
		State.ATTACK: ...   # jak dotąd, po regeneracji -> HUNT
		State.STUNNED: ...  # po czasie -> HUNT z odświeżoną pamięcią
```
- [ ] **Krok 4:** zielone. **Krok 5:** (razem z zadaniem 6 — mózg zmienia nazwy stanów używane w całej grze, więc commit dopiero, gdy wywołujący są poprawieni).

## Zadanie 4: `LayoutIllumination`

**Pliki:** utwórz `src/enemies/perception/layout_illumination.gd`, test `tests/unit/test_layout_illumination.gd`.

- [ ] **Krok 1: test**

```gdscript
func _layout() -> LevelLayout:
	var layout := LevelLayout.new()
	var hall := layout.add_room(&"hall", [Rect2(-10, -10, 20, 20)] as Array[Rect2], 0.0, 8.0, Color.GRAY)
	hall.skylights.append(Rect2(6, -2, 3, 4))
	layout.add_room(&"side", [Rect2(10, -10, 10, 20)] as Array[Rect2], 0.0, 4.0, Color.GRAY)
	layout.add_light(LightSpec.MAIN, Vector3(0, 3, 0), Color(1, 0.8, 0.55), 1.5, 10.0, &"hall")
	layout.add_light(LightSpec.EMERGENCY, Vector3(15, 2, 0), Color(1, 0.12, 0.08), 1.0, 6.0, &"side")
	return layout

func test_lit_under_a_lamp_dark_far_from_it() -> void:
	var light := LayoutIllumination.from_layout(_layout())
	assert_gt(light.at(Vector3(0, 1, 0)), PerceptionRules.LIT_LEVEL)
	assert_lt(light.at(Vector3(-9, 1, -9)), PerceptionRules.DIM_LEVEL)

func test_a_lamp_without_power_gives_nothing() -> void:
	var off := func(group: StringName, _room: StringName) -> bool: return group != LightSpec.MAIN
	assert_lt(LayoutIllumination.from_layout(_layout(), off).at(Vector3(0, 1, 0)), PerceptionRules.DIM_LEVEL)

func test_lamps_do_not_shine_through_walls() -> void:
	# the side room's red lamp is 5 m from a hall point at x 10 - but behind the wall
	assert_lt(LayoutIllumination.from_layout(_layout()).at(Vector3(9.5, 1, 6)), PerceptionRules.DIM_LEVEL)

func test_a_red_emergency_lamp_is_half_dark() -> void:
	var level := LayoutIllumination.from_layout(_layout()).at(Vector3(15, 1, 1))
	assert_gt(level, PerceptionRules.DIM_LEVEL)
	assert_lt(level, PerceptionRules.LIT_LEVEL)

func test_moonlight_falls_under_a_skylight() -> void:
	var light := LayoutIllumination.from_layout(_layout())
	assert_almost_eq(light.at(Vector3(7.5, 1, 0)), LayoutIllumination.MOON_LEVEL, 0.05)
```
- [ ] **Krok 2–4:** czerwone → implementacja (`contribution()`: luminancja `0.2126 r + 0.7152 g + 0.0722 b`, spadek `1 − (d/zasięg)²`, reflektor: kąt do `direction` ≤ `spot_angle`; sale dzielące światło: niewycięta sala ↔ wycięta sala pod nią; `powered_by_nodes(root)` — indeks `Light3D` po grupie i `meta room`, zasilona = któraś widoczna) → zielone.
- [ ] **Krok 5:** commit `Layout illumination: light level from LightSpecs, power and moon`.

## Zadanie 5: `PerceptionWorld` — kontrakt świata percepcji

**Pliki:** utwórz `src/enemies/perception/perception_world.gd`; `tests/test_runner.gd` (`_reset_globals()` woła `PerceptionWorld.reset()` i `PerceptionWorld.set_difficulty(1)`).

```gdscript
class_name PerceptionWorld
extends RefCounted

static func configure(illumination: Callable, room_of: Callable, graph: RoomGraph, door_open: Callable) -> void
static func reset() -> void            # wszystko oświetlone, brak sal, drzwi otwarte
static func set_difficulty(level: int) -> void   # 0 / 1 / 2 -> sight_scale, hunter_cap
static func light_at(point: Vector3) -> float
static func room_at(point: Vector3) -> StringName
static func room_graph() -> RoomGraph
static func is_door_open(passage: StringName) -> bool
static func guard_light(guard: Node3D) -> float      # pamięć na klatkę fizyki; latarka = 1, race
static func territory_of(home_room: StringName, explicit: Array[StringName]) -> Array[StringName]
static func join(enemy: Enemy) / leave(enemy: Enemy) / exhibits() -> Array[Enemy]
static func may_hunt(enemy: Enemy) -> bool           # limit 8 w 30 m (rezerwacja w klatce)
static func noise(at: Vector3, radius: float, source: StringName) -> int   # ilu usłyszało
static func listen() -> void                         # Events.weapon_fired / noise_made
```
Hałas ze środka przystani nie niesie się (bezpieczny pokój). Strzał = hałas w pozycji strażnika.

- [ ] Testy w zadaniu 6 (integracyjne). Commit razem z zadaniem 6.

## Zadanie 6: `Enemy` na nowej percepcji + wszyscy wywołujący

**Pliki:** `src/enemies/enemy.gd`, podklasy, `crowd.gd`, rigi, `music.gd`, `cctv.gd` (bez zmian logiki), `night_spawner.gd`, `night_objective.gd`, `boss_dev.gd`, `sandbox.gd`, `emergency_cabinet.gd`, `raptor_pack.gd`, `flare_light.gd`, `player.gd`; test `tests/integration/test_perception.gd`.

- [ ] **Krok 1: testy integracyjne (szara skrzynka, `PerceptionWorld` skonfigurowany w teście):**
  - za plecami nie widzi (8 m z tyłu), z przodu tak; z bliska (2 m) wyczuwa dookoła,
  - ciemno: rycerz 10 m przed strażnikiem bez latarki nie widzi, z latarką widzi,
  - hałas przez otwarte drzwi słychać, przez zamknięte nie (graf dwóch sal, `door_open` z testu),
  - utrata wzroku → SEARCH w ostatnio widzianym punkcie → RETURN → DORMANT w domu,
  - łańcuchowe budzenie: z 5 śpiących w 8 m budzą się najwyżej 2 i sprawdzają (INVESTIGATE / SUSPICIOUS), nie polują,
  - limit: 12 widzących naraz → najwyżej 8 w HUNT/ATTACK,
  - smycz: pościg za strażnikiem 40 m dalej kończy się powrotem; wezwany (`summoned`) goni dalej,
  - przystań: 8 s przy drzwiach, potem do domu; wyjście nikogo nie przyciąga.
- [ ] **Krok 2: `Enemy`:**
  - eksporty: `sight_range` = zasięg „oświetlony” (22), `sight_cone_deg` (120), `close_sense` (3,5), `leash` (28), `wake_radius` (8); pola kontraktu `home_room`, `territory`, `patrol_route`; `summoned`; `home`, `home_yaw`,
  - `_look()` co 0,2 s (śpiący dalej niż 32 m: co 0,6 s): `PerceptionRules.sight_range(PerceptionWorld.guard_light(target), sight_range) × sight_scale × (0,6 gdy śpi)`, stożek `in_cone(-basis.z, …)` poza wyczuciem bliskim, promień LOS jak dotąd; odświeżenie sali (gdy przeszedł ≥ 0,5 m) i smyczy,
  - kontekst mózgu co klatkę, ruch: HUNT (strażnik, gdy go zna, pierścień ataku jak dziś), INVESTIGATE/SEARCH/RETURN/PATROL (`brain.goal` z `brain.pace()`), SUSPICIOUS (obrót ku `last_known`), RETURN kończy obrotem do `home_yaw`,
  - `hear(point)`, `alarm` przy trafieniu (wie skąd), łańcuchowe budzenie ≤ 2 (`_rouse_neighbours`) tylko przy samodzielnym przebudzeniu,
  - dźwięki: SUSPICIOUS → `suspicion` (cicho), wejście w HUNT po wykryciu i `wake()` → `notice_sound`; budzeni przez sąsiada milczą.
- [ ] **Krok 3: podklasy** — czasy podejrzliwości, `Wolf`/`Raptor` `leash = 40`, `Raptor.pack_id` (stado poluje razem), `Bust` stożek 160°, `Portrait`: własny `_look()` (przód, 10/16 m, bez światła), nie słyszy, po przebudzeniu nie wraca do snu (`relentless`), wysuwa się przy SUSPICIOUS → HUNT.
- [ ] **Krok 4: wywołujący** — `NightSpawner` (dom + PATROL dla czuwających), wezwani (`summoned = true`) w `NightObjective.summon_*`, `RaptorPack.spawn(awake)`, `BossDev`, `Sandbox.spawn(awake)`; szafka pożarowa = `Events.noise_made` 16 m; `Player` — sprint/lądowanie 7 m; `FlareLight.lit_positions()`; `EnemyCrowd` — rozpychanie idących; `Music` — „walka” tylko od polujących; rigi — oczy w SUSPICIOUS.
- [ ] **Krok 5:** pełny zestaw testów; istniejące testy wrogów aktualizowane **świadomie** (stany ALERT → SUSPICIOUS, CHASE → HUNT; testy ścieżek, które zakładały wszechwiedzę, dostają `summoned = true` albo widoczny cel; test przystani opisuje nowe zachowanie). Commit `Exhibit perception: cone, light, hearing, search, return, leash, hunter cap`.

## Zadanie 7: lobby — podłączenie i łagodna noc 1

**Pliki:** `src/enemies/perception/level_perception.gd`, `src/game/museum.gd`, `src/game/night_director.gd`, `src/level/lobby_dev.gd`; testy `tests/integration/test_lobby_perception.gd`, uzupełnienie `tests/unit/test_night_director.gd`.

- [ ] `LevelPerception.configure_layout(layout, doors, lights_root, moon_level)` i `configure_lobby(lobby, modifier)`: jasność `LayoutIllumination` z zasilaniem z prawdziwych lamp (zaciemnienie, awaria prądu, mruganie — wszystko widać po `Light3D.visible`), sala z `layout.room_at`, graf `layout.graph()`, drzwi `Door.is_open` (schody zawsze otwarte); księżyc 0,3, pełnia 0,5.
- [ ] `Museum._ready()`: po `level.build()` i modyfikatorze — `LevelPerception.configure_lobby()`; `_exit_tree()` — `PerceptionWorld.reset()`.
- [ ] `NightDirector`: `_gentle_first_night()` na końcu `plan()` dla nocy 1 — sale na trasie z pierwszej przystani startowej do sali bossa: wilki i raptory → wosk, czuwających najwyżej 2.
- [ ] **Testy w prawdziwym lobby:**
  - „wyjście z kanciapy w noc 1: przez 60 s poluje najwyżej 2 w promieniu 30 m” (strażnik idzie korytarzem i dioramą do drzwi holu, rozgląda się),
  - strzał w holu przy drzwiach galerii: eksponat w galerii słyszy przy otwartych drzwiach, przy zamkniętych nie; strzał w galerii nie dociera do zbrojowni za zamkniętymi drzwiami,
  - zbrojownia bez prądu: rycerz 10 m przed strażnikiem nie widzi go bez latarki, z latarką widzi,
  - noc 1: na trasie kanciapa → hol nie ma wilków ani raptorów.
- [ ] Commit `Lobby perception wiring and a gentle first night`.

## Zadanie 8: dźwięk podejrzliwości

- [ ] `gen_sfx.py`: `suspicion` (krótkie skrzypnięcie + niski, wznoszący się pomruk 0,4 s, −9 dB), dopisane na końcu; `Sfx.SOUNDS` + `suspicion`; uruchomić generator (istniejące pliki bajt w bajt), import. Commit `Suspicion sound`.

## Zadanie 9: wydajność

- [ ] `tests/integration/test_perception_perf.gd`: lobby + 120 śpiących i 10 czuwających eksponatów, strażnik chodzi 10 s; `PerceptionWorld.stats` liczy sprawdzenia wzroku, promienie i czas `_look()` (µs). Wydruk wyników; próg: średnio < 1,5 ms percepcji na klatkę. Wyniki do raportu.

## Zadanie 10: dokumentacja

- [ ] `docs/Nocna-Zmiana-specyfikacja.md` §4.2 „Wspólne zasady” i §13.3 — nowa percepcja (stany, wzrok, słuch, smycz, limit, trudność). Commit `Spec: exhibit perception`.

---

## Doprecyzowania i odstępstwa

1. **Śpiący widzi na 0,6 zasięgu** (wyżej). Wartość do strojenia, w `PerceptionRules.DORMANT_SCALE`.
2. **Hałas ze środka przystani nie niesie się.** Przystań jest poza zasięgiem eksponatów; strzał z niej nie ściąga nikogo pod drzwi (spójne z „wyjście z przystani nikogo nie przyciąga”).
3. **Wezwani (ryk T-Reksa, fale piaskownicy, arena BossDev) zawsze znają pozycję strażnika** i nie mają smyczy — walka z bossem w zamkniętej sali ma zostać intensywna.
4. **Stado raptorów budzi się razem** (poza limitem „2 na budzącego”): stado jest jedną jednostką projektu („poluje stadami”), flankowanie zostaje. Limit polujących nadal obowiązuje.
5. **Trafienie = wie skąd.** Eksponat trafiony (nie ogłuszony) staje się podejrzliwy z punktem strażnika i — widząc go — poluje; ogłuszony po ocknięciu poluje (pamięć odświeżona).
6. **Czuwający ze spawnu (dawniej „pościg od razu”) patrolują** po trasie w swojej sali (punkty generowane przez `PerceptionRules.patrol_route`), a nie biegną przez muzeum.
7. **Strzał w galerii a zbrojownia:** galeria i zbrojownia leżą 40+ m od siebie przez hol — strzału z galerii zbrojownia nie usłyszy nawet przy otwartych drzwiach (×0,36 i dystans). Test „przez zamknięte drzwi” robimy więc też w wersji, która coś sprawdza: strzał w holu przy drzwiach galerii.
8. **Łagodna noc 1 w lobby** obejmuje także hol (odpowiednik „holu wejściowego i dziedzińca” nowego piętra).
9. **Krótka ekstrapolacja = najwyżej 5 m** (`EnemyBrain.EXTRAPOLATE`): przez 1,5 s pamięci polujący podąża za strażnikiem, ale nie dalej niż 5 m od miejsca, gdzie go ostatnio widział; tam zaczyna przeszukiwanie („SEARCH z ostatnio widzianego punktu”, z krótką ekstrapolacją z §7.2).
10. **Twardy sen na drodze nocy 1** (`Enemy.sound_asleep`, `NightDirector.GENTLE_TIME` = 180 s): pomiar pokazał, że sama wymiana wilków na wosk nie wystarcza — śpiący w dioramie stoją przodem do drzwi holu, a strażnik w oświetlonym przejściu jest dla nich widoczny; z budzeniem sąsiadów dawało to 4–6 polujących. Przez pierwsze 3 minuty nocy 1 śpiący na drodze kanciapa → hol nie widzą strażnika (czują go dopiero w 1 m); hałas, trafienie i sąsiedzi budzą ich jak zwykle. To wprost „tylko śpiące eksponaty i 1–2 patrolujące figury” z §7.2.
11. **`PerceptionWorld` trzyma obiekty przekazanych funkcji** (`LayoutIllumination`, `LevelLayout`) do następnego `configure()`/`reset()`: `Callable` nie trzyma `RefCounted` przy życiu, a porzucony model jasności zostawiał lobby zawsze „oświetlone”.
12. **Wzrok co 0,2 s:** między sprawdzeniami eksponat, który widział strażnika, zna jego bieżącą pozycję (najwyżej 0,2 s „za darmo”) — jak w starej grze; niezauważalne przy prędkości strażnika.

## Stan wykonania (3.10)

Zadania 1–10 wykonane. Pomiar „wyjście z kanciapy” (strażnik idzie korytarzem i dioramą do holu i krąży przy jego południowym końcu, bez walki, 60 s, 3 gry): **przed zmianą 17–22 polujących w 30 m, pierwszy po ~3 s; po zmianie noc 1 — najwyżej 2 (pierwszy po ~10 s: patrol w holu), noce 2–3 — 3–8** (limit 8). Wydajność (bez okna, 120 śpiących + 10 patrolujących): ~500 sprawdzeń wzroku/s, ~120 promieni/s, 0,13 ms percepcji na klatkę fizyki (15 µs na sprawdzenie).
