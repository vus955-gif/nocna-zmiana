# Etap 1a — Piaskownica walki: plan implementacji

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Cel:** grywalna szara arena, w której strażnik porusza się (chód, sprint i unik na wytrzymałości, skok) i walczy czterema brońmi (pięści, paralizator, pistolet, strzelba) z trzema typami eksponatów (figura woskowa, wypchany wilk, rycerz w zbroi). Eksponaty rozpadają się zależnie od materiału. Całość ma HUD, dźwięki i „soczyste” strzelanie, a na końcu powstaje samodzielny plik `build/NocnaZmiana.exe`.

**Architektura:** Godot 4.7.2 z GDScriptem. Wszystkie węzły (gracz, wrogowie, broń, HUD, arena) buduje kod, a pliki `.tscn` są minimalne: korzeń plus skrypt. Dane broni leżą w zasobach `.tres`. Czysta logika (wytrzymałość, amunicja, maszyna stanów wroga, tarcza, planista rozpadu, wstrząs kamery) siedzi w klasach `RefCounted`, testowanych bez sceny. Moduły komunikują się przez autoload `Events` (szyna sygnałów). Efekty wizualne i dźwiękowe są usługami-autoloadami `Fx` i `Sfx`.

**Stos:** Godot 4.7.2 (Forward+, fizyka Jolt, interpolacja fizyki), GDScript ze statycznym typowaniem, własny runner testów bez okna, Python 3 (tylko biblioteka standardowa) do generowania efektów dźwiękowych.

**Spec:** `docs/superpowers/specs/2026-09-25-nocna-zmiana-design.html`, sekcje 01, 03, 07, 08 i 09 (etap 1). Ten plan to **etap 1a**. Próbka stylu (**etap 1b**) dostanie osobny plan po testach gracza.

---

## Konwencje (przeczytaj przed pierwszym zadaniem)

- **Godot:** `tools/godot/Godot_v4.7.2-stable_win64_console.exe` (kopia z zadania 1). Na tej maszynie działa Git Bash, więc polecenia są w składni bash i uruchamiasz je z katalogu głównego repozytorium.
- **Testy:** `bash tools/run_tests.sh` uruchamia wszystkie, a `bash tools/run_tests.sh --filter=stamina` tylko pliki, których nazwa zawiera „stamina”. Skrypt uznaje przebieg za nieudany, jeśli którykolwiek test nie przejdzie **albo** Godot wypisze linię zaczynającą się od `ERROR`, `SCRIPT ERROR` lub `USER ERROR`. Dotyczy to też wycieków obiektów przy wyjściu, więc każdy utworzony węzeł musi trafić do drzewa albo zostać zwolniony.
- **Wcięcia w GDScripcie: wyłącznie tabulatory.** Mieszanie ze spacjami to błąd parsowania.
- **Język:** komentarze i identyfikatory po angielsku, teksty widoczne dla gracza po polsku.
- **Każdy plik w planie podany jest w całości** pod nagłówkiem `**Plik: `ścieżka`**`. Gdy zadanie zmienia istniejący plik, znowu podaje go w całości: zastąp całą zawartość.
- **Warstwy fizyki** (`src/core/layers.gd`): 1 `WORLD`, 2 `PLAYER`, 4 `ENEMY`, 8 `HURTBOX`, 16 `DEBRIS`, 32 `PICKUP`. Promienie broni uderzają w `WORLD | HURTBOX`. Ciała wrogów leżą na `ENEMY`, więc promień przez nie przechodzi i trafia w strefy trafień (`Hurtbox`) w środku.
- **Interfejs obrażeń:** każdy węzeł z metodą `take_damage(info: DamageInfo)` może przyjmować obrażenia. `Hurtbox.receiver` wskazuje taki węzeł.
- **Gałąź:** pracujesz na `etap-1a-piaskownica` (tworzy ją zadanie 1). Commit po każdym zadaniu.
- **Stopka commitów:** każdy commit kończy się linią `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (drugi argument `-m`).

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `project.godot` | ustawienia silnika, autoloady, scena główna |
| `Graj.bat` | uruchomienie wersji roboczej dwuklikiem (podczas budowy) |
| `export_presets.cfg`, `tools/export.sh` | eksport do jednego pliku `build/NocnaZmiana.exe` (gra dla gracza) |
| `tools/run_tests.sh`, `tools/run_scenario.sh` | testy bez okna, scenariusze ze zrzutami ekranu |
| `tools/sfx/gen_sfx.py` | proceduralne efekty dźwiękowe → `assets/sfx/*.wav` |
| `tests/test_case.gd`, `tests/test_runner.gd` + `.tscn` | mini-framework testów |
| `tests/support/target_dummy.gd` | manekin rejestrujący trafienia (testy) |
| `tests/unit/*`, `tests/integration/*` | testy |
| `tests/scenarios/scenario_runner.gd` + `.tscn` | scenariusze wizualne |
| `src/core/layers.gd` | stałe warstw fizyki |
| `src/core/events.gd` | autoload `Events`: szyna sygnałów |
| `src/core/game_input.gd` | autoload `GameInput`: rejestracja akcji wejścia |
| `src/combat/damage_info.gd` | `DamageInfo`: wszystko, co niesie trafienie |
| `src/combat/health.gd` | `Health`: punkty życia |
| `src/combat/hurtbox.gd` | `Hurtbox`: strefa trafienia (Area3D) |
| `src/combat/hitscan.gd` | `Hitscan`: promienie, rozrzut, zamach wręcz |
| `src/combat/exhibit_material.gd` | `ExhibitMaterial`: wosk / trociny / marmur / metal |
| `src/combat/gib_planner.gd` | `GibPlanner`: jak eksponat się rozpada |
| `src/fx/trauma.gd` | `Trauma`: matematyka wstrząsu kamery |
| `src/fx/fx.gd` | autoload `Fx`: cząsteczki, odłamki, smugi, łuki, błyski, dziury, hitstop |
| `src/fx/sfx.gd` | autoload `Sfx`: odtwarzanie dźwięków |
| `src/player/stamina.gd` | `Stamina`: sprint, unik, zmęczenie |
| `src/player/shake_camera.gd` | `ShakeCamera`: kamera ze wstrząsem i kopnięciem FOV |
| `src/player/player.gd` | `Player`: strażnik |
| `src/weapons/weapon_data.gd` | `WeaponData`: liczby broni (zasób) |
| `src/weapons/weapon_state.gd` | `WeaponState`: amunicja, bateria, przeładowanie, odstęp strzałów |
| `src/weapons/weapon_holder.gd` | `WeaponHolder`: arsenał, strzał, zmiana broni, modele w dłoni |
| `src/weapons/viewmodels.gd` | `Viewmodels`: szare modele broni w dłoni |
| `src/weapons/data/*.tres` | pięści, paralizator, pistolet, strzelba |
| `src/enemies/enemy_brain.gd` | `EnemyBrain`: maszyna stanów wroga |
| `src/enemies/shield_guard.gd` | `ShieldGuard`: reguła tarczy rycerza |
| `src/enemies/enemy.gd` | `Enemy`: baza eksponatu |
| `src/enemies/wax_figure.gd`, `wolf.gd`, `knight.gd` | trzy typy wrogów |
| `src/arena/greybox.gd` | `Greybox`: bryły i rampy z siatką |
| `src/arena/sandbox_arena.gd` | `SandboxArena`: układ hali i światło |
| `src/arena/pickup.gd` | `Pickup`: amunicja i apteczki |
| `src/arena/sandbox.gd` + `.tscn` | `Sandbox`: tryb piaskownicy (scena główna) |
| `src/ui/hud.gd` | `Hud`: interfejs |

## Kolejność i zależności

Zadania idą w tej kolejności: każde korzysta tylko z wcześniejszych. Zadania 1–10 to fundamenty. Od zadania 11 elementy składają się w grę, a od zadania 18 da się w nią grać.

---

### Zadanie 1: Szkielet projektu i runner testów

**Pliki:**
- Utwórz: `tools/godot/` (kopia silnika, poza gitem), `.gitattributes`, `docs/.gdignore`, `tools/.gdignore`, `project.godot`, `tests/test_case.gd`, `tests/test_runner.gd`, `tests/test_runner.tscn`, `tools/run_tests.sh`
- Zmień: `.gitignore`
- Test: `tests/unit/test_sanity.gd`

- [ ] **Krok 1: Gałąź i kopia Godota**

```bash
git checkout -b etap-1a-piaskownica
mkdir -p tools/godot
cp "D:/Codex/Gra RTS/tools/godot/Godot_v4.7.2-stable_win64.exe" "D:/Codex/Gra RTS/tools/godot/Godot_v4.7.2-stable_win64_console.exe" tools/godot/
touch tools/godot/_sc_
tools/godot/Godot_v4.7.2-stable_win64_console.exe --version
```

Oczekiwane: `4.7.2.stable.official.ed1daf0bf`. Plik `_sc_` włącza tryb self-contained, więc dane edytora i zapisy gry lądują obok exe, na dysku D:.

- [ ] **Krok 2: Pliki repozytorium**

`.gitignore` do tej pory wykluczał `*.import`. To błąd: w Godot 4 pliki `.import` trzymają ustawienia importu i trzeba je wersjonować.

**Plik: `.gitignore`**
```gitignore
.godot/
/tools/godot/
build/
tests/_out/
```

**Plik: `.gitattributes`**
```gitattributes
* text=auto
*.sh text eol=lf
*.gd text eol=lf
*.bat text eol=crlf
*.wav binary
*.png binary
```

**Plik: `docs/.gdignore`**
```text
```

**Plik: `tools/.gdignore`**
```text
```

Puste pliki `.gdignore` mówią Godotowi, żeby nie skanował tych katalogów.

- [ ] **Krok 3: `project.godot` (wersja startowa, bez autoloadów)**

**Plik: `project.godot`**
```ini
; Engine configuration file.
; Hand-maintained: autoloads and the main scene are listed here.

config_version=5

[application]

config/name="Nocna Zmiana"
config/features=PackedStringArray("4.7", "Forward Plus")

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemy"
3d_physics/layer_4="hurtbox"
3d_physics/layer_5="debris"
3d_physics/layer_6="pickup"

[physics]

3d/physics_engine="Jolt Physics"
common/physics_interpolation=true
common/physics_jitter_fix=0.0

[rendering]

anti_aliasing/quality/msaa_3d=2
```

- [ ] **Krok 4: Framework testów**

**Plik: `tests/test_case.gd`**
```gdscript
class_name TestCase
extends Node
## Base class for tests. The runner (tests/test_runner.gd) creates a fresh
## instance per test method, adds it to the scene tree, then awaits
## before_each(), the test_* method and after_each(). Failed assertions are
## collected, not thrown, so one test reports all its problems at once.

var _failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(value: bool, message: String = "") -> void:
	if not value:
		fail("expected true. " + message)


func assert_false(value: bool, message: String = "") -> void:
	if value:
		fail("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		fail("expected <%s>, got <%s>. %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same(actual, unexpected):
		fail("expected anything but <%s>. %s" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("expected %s (+/- %s), got %s. %s" % [expected, tolerance, actual, message])


func assert_gt(actual: float, limit: float, message: String = "") -> void:
	if not actual > limit:
		fail("expected > %s, got %s. %s" % [limit, actual, message])


func assert_lt(actual: float, limit: float, message: String = "") -> void:
	if not actual < limit:
		fail("expected < %s, got %s. %s" % [limit, actual, message])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected a value, got null. " + message)


## Records every emission of [param sig]. Returns an Array that gains one
## [a, b, c, d] entry per emission (unused arguments are null).
func watch(sig: Signal) -> Array:
	var calls: Array = []
	sig.connect(func(a = null, b = null, c = null, d = null) -> void: calls.append([a, b, c, d]))
	return calls


## Waits [param count] physics frames (use with await).
func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _same(a: Variant, b: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numbers and typeof(b) in numbers:
		return is_equal_approx(float(a), float(b))
	var strings := [TYPE_STRING, TYPE_STRING_NAME]
	if typeof(a) in strings and typeof(b) in strings:
		return str(a) == str(b)
	return typeof(a) == typeof(b) and a == b
```

**Plik: `tests/test_runner.gd`**
```gdscript
extends Node
## Headless test runner. Runs every test_* method of every
## tests/unit/test_*.gd and tests/integration/test_*.gd script, prints a
## report and quits with exit code 0 (all passed) or 1.
## Filter by file name:  bash tools/run_tests.sh --filter=stamina

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _ready() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var passed := 0
	var failed := 0
	for path in _find_test_files(filter):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s  (script does not load)" % path)
			failed += 1
			continue
		for method in _test_methods(script):
			var test := script.new() as TestCase
			if test == null:
				print("FAIL  %s  (does not extend TestCase)" % path)
				failed += 1
				break
			add_child(test)
			await test.before_each()
			await test.call(method)
			await test.after_each()
			if test._failures.is_empty():
				passed += 1
				print("ok    %s :: %s" % [path.get_file(), method])
			else:
				failed += 1
				print("FAIL  %s :: %s" % [path.get_file(), method])
				for failure in test._failures:
					print("        " + failure)
			test.queue_free()
			_reset_globals()
			await get_tree().process_frame
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _find_test_files(filter: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for dir_path in TEST_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.begins_with("test_") and file.ends_with(".gd") and (filter == "" or file.contains(filter)):
				files.append(dir_path.path_join(file))
	files.sort()
	return files


func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


## Undo global side effects a test may leave behind.
func _reset_globals() -> void:
	Engine.time_scale = 1.0
	for action in InputMap.get_actions():
		Input.action_release(action)
	var fx := get_node_or_null(^"/root/Fx")
	if fx != null:
		fx.call(&"clear")
```

**Plik: `tests/test_runner.tscn`**
```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/test_runner.gd" id="1_runner"]

[node name="TestRunner" type="Node"]
script = ExtResource("1_runner")
```

**Plik: `tools/run_tests.sh`**
```bash
#!/usr/bin/env bash
# Imports the project, then runs all headless tests. Extra arguments go to
# the runner, e.g.:  bash tools/run_tests.sh --filter=stamina
# Fails if any test fails OR Godot prints an ERROR line (incl. leaks at exit).
cd "$(dirname "$0")/.." || exit 1
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --path . res://tests/test_runner.tscn -- "$@" 2>&1)
CODE=$?
echo "$OUT"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED -> run treated as failed"
	exit 1
fi
exit $CODE
```

- [ ] **Krok 5: Test samego frameworka**

**Plik: `tests/unit/test_sanity.gd`**
```gdscript
extends TestCase
## Checks the test helpers themselves.

signal pinged(value: int)


func test_numbers_compare_across_int_and_float() -> void:
	assert_eq(3, 3.0)


func test_strings_compare_across_string_and_stringname() -> void:
	assert_eq(&"pistol", "pistol")


func test_watch_records_signal_arguments() -> void:
	var calls := watch(pinged)
	pinged.emit(7)
	assert_eq(calls.size(), 1)
	assert_eq(calls[0][0], 7)


func test_physics_frames_can_be_awaited() -> void:
	var before := Engine.get_physics_frames()
	await physics_frames(2)
	assert_gt(Engine.get_physics_frames(), before)
```

- [ ] **Krok 6: Uruchom**

Run: `bash tools/run_tests.sh`
Oczekiwane: cztery linie `ok    test_sanity.gd :: ...` i na końcu `4 passed, 0 failed`, kod wyjścia 0.

Sprawdź też, że porażka jest wykrywana. Tymczasowo zmień w `test_numbers_compare_across_int_and_float` wartość `3.0` na `4.0`, uruchom (oczekiwane: `FAIL`, `1 failed`, kod 1), po czym przywróć.

- [ ] **Krok 7: Commit**

```bash
git add .gitignore .gitattributes docs/.gdignore tools/.gdignore project.godot tests tools/run_tests.sh
git commit -m "Scaffold Godot project and headless test runner" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 2: Warstwy, DamageInfo i Health

**Pliki:**
- Utwórz: `src/core/layers.gd`, `src/combat/damage_info.gd`, `src/combat/health.gd`
- Test: `tests/unit/test_damage_info.gd`, `tests/unit/test_health.gd`

- [ ] **Krok 1: Napisz testy (na razie nie przejdą)**

**Plik: `tests/unit/test_damage_info.gd`**
```gdscript
extends TestCase


func test_make_fills_amount_kind_and_source() -> void:
	var source := Node.new()
	add_child(source)
	var info := DamageInfo.make(12.5, DamageInfo.Kind.ELECTRIC, source)
	assert_eq(info.amount, 12.5)
	assert_eq(info.kind, DamageInfo.Kind.ELECTRIC)
	assert_eq(info.source, source)


func test_defaults_are_harmless() -> void:
	var info := DamageInfo.new()
	assert_eq(info.stun_time, 0.0)
	assert_eq(info.knockback, 0.0)
	assert_false(info.weak_point)
	assert_false(info.can_finish)
	assert_false(info.blocked)
```

**Plik: `tests/unit/test_health.gd`**
```gdscript
extends TestCase

var health: Health


func before_each() -> void:
	health = Health.new()
	health.max_health = 100.0
	add_child(health)


func test_starts_full() -> void:
	assert_eq(health.current, 100.0)
	assert_false(health.is_dead())


func test_damage_reduces_and_reports_amount_taken() -> void:
	assert_eq(health.apply_damage(30.0), 30.0)
	assert_eq(health.current, 70.0)


func test_overkill_clamps_and_reports_only_what_was_left() -> void:
	health.apply_damage(80.0)
	assert_eq(health.apply_damage(50.0), 20.0)
	assert_eq(health.current, 0.0)
	assert_true(health.is_dead())


func test_depleted_is_emitted_once() -> void:
	var calls := watch(health.depleted)
	health.apply_damage(100.0)
	health.apply_damage(10.0)
	assert_eq(calls.size(), 1)


func test_heal_clamps_to_max() -> void:
	health.apply_damage(10.0)
	assert_eq(health.heal(50.0), 10.0)
	assert_eq(health.current, 100.0)


func test_the_dead_cannot_be_healed() -> void:
	health.apply_damage(100.0)
	assert_eq(health.heal(50.0), 0.0)
	assert_true(health.is_dead())


func test_fraction() -> void:
	health.apply_damage(25.0)
	assert_almost_eq(health.fraction(), 0.75)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=health`
Oczekiwane: `FAIL ... (script does not load)` oraz `SCRIPT ERROR ... Parse Error ... Health`, bo klasa jeszcze nie istnieje.

- [ ] **Krok 3: Implementacja**

**Plik: `src/core/layers.gd`**
```gdscript
class_name Layers
## Physics layer bits (names in [layer_names] of project.godot).

const WORLD := 1
const PLAYER := 2
const ENEMY := 4
const HURTBOX := 8
const DEBRIS := 16
const PICKUP := 32
```

**Plik: `src/combat/damage_info.gd`**
```gdscript
class_name DamageInfo
extends RefCounted
## Everything a hit carries. Created by weapons and enemy attacks and passed
## to take_damage() on the player and on exhibits.

enum Kind { BLUNT, ELECTRIC, BALLISTIC }

var amount: float = 0.0
var kind: Kind = Kind.BLUNT
var stun_time: float = 0.0
var knockback: float = 0.0
## Direction the hit travels (attacker -> target).
var direction: Vector3 = Vector3.ZERO
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var weak_point: bool = false
## Fist hits may finish off a stunned exhibit.
var can_finish: bool = false
## Set by the target when a shield stopped the hit.
var blocked: bool = false
## Who dealt the hit (the player for weapons, the exhibit for its attacks).
var source: Node = null


static func make(amount_: float, kind_: Kind, source_: Node = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount_
	info.kind = kind_
	info.source = source_
	return info
```

**Plik: `src/combat/health.gd`**
```gdscript
class_name Health
extends Node
## Hit points. Emits [signal depleted] exactly once when reaching zero.

signal changed(current: float, maximum: float)
signal depleted

@export var max_health: float = 100.0
var current: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	current = max_health
	changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0.0


## Returns the damage actually taken (never more than what was left).
func apply_damage(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var taken := minf(amount, current)
	current -= taken
	changed.emit(current, max_health)
	if current <= 0.0:
		current = 0.0
		depleted.emit()
	return taken


## Returns the amount actually healed. The dead cannot be healed.
func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var healed := minf(amount, max_health - current)
	current += healed
	changed.emit(current, max_health)
	return healed


func fraction() -> float:
	return current / max_health if max_health > 0.0 else 0.0
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `13 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/core/layers.gd src/combat tests/unit/test_damage_info.gd tests/unit/test_health.gd
git commit -m "Add physics layers, DamageInfo and Health" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 3: Szyna zdarzeń i sterowanie

**Pliki:**
- Utwórz: `src/core/events.gd`, `src/core/game_input.gd`
- Zmień: `project.godot` (autoloady)
- Test: `tests/unit/test_game_input.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/unit/test_game_input.gd`**
```gdscript
extends TestCase

const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump",
	&"sprint", &"dash", &"fire", &"punch", &"reload", &"flashlight",
	&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_next", &"weapon_prev",
	&"toggle_help", &"toggle_fullscreen", &"release_mouse",
	&"spawn_wax", &"spawn_wolf", &"spawn_knight", &"clear_enemies",
]


func test_every_action_exists_and_has_a_binding() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "missing action " + str(action))
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "no binding for " + str(action))


func test_punch_is_on_mouse_and_keyboard() -> void:
	assert_eq(InputMap.action_get_events(&"punch").size(), 2)


func test_event_bus_is_autoloaded() -> void:
	assert_not_null(get_node_or_null(^"/root/Events"))
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=game_input`
Oczekiwane: FAIL (brak akcji i brak `/root/Events`).

- [ ] **Krok 3: Implementacja**

**Plik: `src/core/events.gd`**
```gdscript
extends Node
## Global signal bus (autoload "Events"). Modules announce facts here instead
## of holding references to each other.

## A hit reached an exhibit. [param killed] is true when it destroyed it.
signal hit_landed(target: Node, info: DamageInfo, killed: bool)
## An exhibit was destroyed. [param finisher] = fist finisher on a stunned one.
signal enemy_destroyed(enemy: Node, info: DamageInfo, finisher: bool)
signal player_damaged(amount: float, from_position: Vector3)
signal player_died
signal weapon_fired(weapon_id: StringName)
## Asks the active camera to shake (trauma 0..1).
signal shake_requested(trauma: float)
```

**Plik: `src/core/game_input.gd`**
```gdscript
extends Node
## Registers every input action in code (autoload "GameInput"), so
## project.godot stays readable. Physical keycodes = same key position on
## any keyboard layout.

const KEYS := {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"sprint": [KEY_SHIFT],
	&"dash": [KEY_CTRL],
	&"reload": [KEY_R],
	&"flashlight": [KEY_F],
	&"punch": [KEY_V],
	&"weapon_1": [KEY_1],
	&"weapon_2": [KEY_2],
	&"weapon_3": [KEY_3],
	&"toggle_help": [KEY_F1],
	&"toggle_fullscreen": [KEY_F11],
	&"release_mouse": [KEY_ESCAPE],
	&"spawn_wax": [KEY_7],
	&"spawn_wolf": [KEY_8],
	&"spawn_knight": [KEY_9],
	&"clear_enemies": [KEY_0],
}

const MOUSE := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"punch": [MOUSE_BUTTON_RIGHT],
	&"dash": [MOUSE_BUTTON_XBUTTON1],
	&"weapon_next": [MOUSE_BUTTON_WHEEL_DOWN],
	&"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
}


func _enter_tree() -> void:
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in MOUSE:
		_ensure(action)
		for button in MOUSE[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
```

**Plik: `project.godot`**
```ini
; Engine configuration file.
; Hand-maintained: autoloads and the main scene are listed here.

config_version=5

[application]

config/name="Nocna Zmiana"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]

Events="*res://src/core/events.gd"
GameInput="*res://src/core/game_input.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemy"
3d_physics/layer_4="hurtbox"
3d_physics/layer_5="debris"
3d_physics/layer_6="pickup"

[physics]

3d/physics_engine="Jolt Physics"
common/physics_interpolation=true
common/physics_jitter_fix=0.0

[rendering]

anti_aliasing/quality/msaa_3d=2
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `16 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/core project.godot tests/unit/test_game_input.gd
git commit -m "Add Events bus and code-registered input actions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 4: Wytrzymałość

Sprint zużywa wytrzymałość na sekundę, a unik kosztuje jej porcję. Regeneracja rusza po krótkiej przerwie. Kto opróżni pasek sprintem, jest „zmęczony” i nie sprintuje, dopóki pasek nie wróci do 30. Duży krok `tick()` przenosi nadwyżkę czasu ponad opóźnienie na regenerację, więc wynik nie zależy od liczby klatek.

**Pliki:**
- Utwórz: `src/player/stamina.gd`
- Test: `tests/unit/test_stamina.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/unit/test_stamina.gd`**
```gdscript
extends TestCase

var stamina: Stamina


func before_each() -> void:
	stamina = Stamina.new()


func test_sprint_drains_per_second() -> void:
	assert_true(stamina.spend_sprint(1.0))
	assert_almost_eq(stamina.current, 100.0 - stamina.sprint_cost_per_sec)


func test_regen_waits_for_the_delay() -> void:
	stamina.spend_sprint(1.0)          # 82, regen waits 0.7 s
	stamina.tick(0.5)
	assert_almost_eq(stamina.current, 82.0)
	stamina.tick(0.5)                  # 0.2 s of waiting left, then 0.3 s of regen
	assert_almost_eq(stamina.current, 82.0 + 0.3 * stamina.regen_per_sec)


func test_regen_stops_at_maximum() -> void:
	stamina.current = 95.0
	stamina.tick(5.0)
	assert_eq(stamina.current, 100.0)


func test_running_dry_exhausts_until_recovered() -> void:
	stamina.current = 10.0
	assert_false(stamina.spend_sprint(1.0))
	assert_true(stamina.exhausted)
	assert_false(stamina.can_sprint())
	stamina.tick(1.2)                  # 0.7 s wait + 0.5 s regen -> 15
	assert_true(stamina.exhausted)
	stamina.tick(0.6)                  # -> 33, above recover_at (30)
	assert_false(stamina.exhausted)
	assert_true(stamina.can_sprint())


func test_dash_costs_a_chunk_and_needs_enough() -> void:
	assert_true(stamina.try_dash())
	assert_eq(stamina.current, 70.0)
	stamina.current = 20.0
	assert_false(stamina.try_dash())
	assert_eq(stamina.current, 20.0)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=stamina`
Oczekiwane: FAIL (brak klasy `Stamina`).

- [ ] **Krok 3: Implementacja**

**Plik: `src/player/stamina.gd`**
```gdscript
class_name Stamina
extends RefCounted
## Stamina for sprint and dash (pure logic, ticked by the player).
## Regenerates after a short pause. Running dry while sprinting "exhausts"
## the guard: no sprinting until stamina is back to [member recover_at].

var maximum: float = 100.0
var current: float = 100.0
var sprint_cost_per_sec: float = 18.0
var dash_cost: float = 30.0
var regen_per_sec: float = 30.0
var regen_delay: float = 0.7
var recover_at: float = 30.0
var exhausted: bool = false
var _regen_wait: float = 0.0


func can_sprint() -> bool:
	return not exhausted and current > 0.0


## Spends sprint stamina for this frame. Returns false when sprinting must stop.
func spend_sprint(delta: float) -> bool:
	if not can_sprint():
		return false
	current = maxf(current - sprint_cost_per_sec * delta, 0.0)
	_regen_wait = regen_delay
	if current <= 0.0:
		exhausted = true
		return false
	return true


func try_dash() -> bool:
	if current < dash_cost:
		return false
	current -= dash_cost
	_regen_wait = regen_delay
	return true


## Call once per frame, after any spending.
func tick(delta: float) -> void:
	var regen_time := delta
	if _regen_wait > 0.0:
		regen_time = maxf(delta - _regen_wait, 0.0)
		_regen_wait = maxf(_regen_wait - delta, 0.0)
	current = minf(current + regen_per_sec * regen_time, maximum)
	if exhausted and current >= recover_at:
		exhausted = false


func fraction() -> float:
	return current / maximum
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `21 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/player/stamina.gd tests/unit/test_stamina.gd
git commit -m "Add stamina with regen delay and exhaustion" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 5: Trauma — matematyka wstrząsu kamery

Wstrząs kamery opiera się na „traumie” z zakresu 0..1, a jego siła to trauma do kwadratu. Drobne trafienia ledwo ruszają kamerą, a duże kopią mocno. Trauma zanika liniowo.

**Pliki:**
- Utwórz: `src/fx/trauma.gd`
- Test: `tests/unit/test_trauma.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/unit/test_trauma.gd`**
```gdscript
extends TestCase


func test_add_clamps_to_one() -> void:
	var trauma := Trauma.new()
	trauma.add(0.7)
	trauma.add(0.7)
	assert_eq(trauma.value, 1.0)


func test_decays_to_zero_and_not_below() -> void:
	var trauma := Trauma.new()
	trauma.add(0.5)
	trauma.tick(0.1)
	assert_almost_eq(trauma.value, 0.5 - trauma.decay_per_sec * 0.1)
	trauma.tick(10.0)
	assert_eq(trauma.value, 0.0)


func test_strength_is_trauma_squared() -> void:
	var trauma := Trauma.new()
	trauma.add(0.5)
	assert_almost_eq(trauma.strength(), 0.25)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=trauma`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/fx/trauma.gd`**
```gdscript
class_name Trauma
extends RefCounted
## Screen-shake "trauma" in 0..1. Shake strength is trauma squared, so small
## hits barely move the camera and big ones kick hard. Decays linearly.

var value: float = 0.0
var decay_per_sec: float = 1.6


func add(amount: float) -> void:
	value = clampf(value + amount, 0.0, 1.0)


func tick(delta: float) -> void:
	value = maxf(value - decay_per_sec * delta, 0.0)


func strength() -> float:
	return value * value
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `24 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/fx/trauma.gd tests/unit/test_trauma.gd
git commit -m "Add trauma-based screen shake math" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Zadanie 6: Materiały eksponatów i planista rozpadu

Materiał decyduje o kolorze odłamków, o cząsteczkach (wosk, trociny, pył marmurowy, iskry) i o dźwiękach. Planista rozpadu decyduje, czy eksponat się **rozsypie** (zwykłe zabicie: kilka dużych kawałków), czy zostanie **rozerwany** (duży nadmiar obrażeń albo dobicie pięścią: dużo małych, szybkich kawałków). Zbroja zawsze gubi dwie dodatkowe blachy.

**Pliki:**
- Utwórz: `src/combat/exhibit_material.gd`, `src/combat/gib_planner.gd`
- Test: `tests/unit/test_exhibit_material.gd`, `tests/unit/test_gib_planner.gd`

- [ ] **Krok 1: Testy**

**Plik: `tests/unit/test_exhibit_material.gd`**
```gdscript
extends TestCase


func test_each_material_has_its_own_sounds() -> void:
	var seen := {}
	for kind in ExhibitMaterial.Kind.values():
		var hit := ExhibitMaterial.hit_sound(kind)
		var broken := ExhibitMaterial.break_sound(kind)
		assert_false(seen.has(hit), "duplicate " + str(hit))
		assert_false(seen.has(broken), "duplicate " + str(broken))
		seen[hit] = true
		seen[broken] = true
	assert_eq(seen.size(), 8)
```

**Plik: `tests/unit/test_gib_planner.gd`**
```gdscript
extends TestCase


func test_plain_kill_crumbles_into_a_few_pieces() -> void:
	var plan := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 0.0, 60.0, false)
	assert_false(plan.gibbed)
	assert_eq(plan.chunks, 3)


func test_heavy_overkill_tears_it_apart() -> void:
	var plan := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 40.0, 60.0, false)
	assert_true(plan.gibbed)
	assert_true(plan.chunks >= 7, "chunks %d" % plan.chunks)


func test_finisher_always_tears_it_apart() -> void:
	assert_true(GibPlanner.plan(ExhibitMaterial.Kind.TAXIDERMY, 0.0, 35.0, true).gibbed)


func test_more_overkill_means_more_force_up_to_a_cap() -> void:
	var small := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 30.0, 60.0, false)
	var big := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 90.0, 60.0, false)
	var huge := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 6000.0, 60.0, false)
	assert_gt(big.impulse, small.impulse)
	assert_true(huge.impulse <= GibPlanner.MAX_IMPULSE)
	assert_true(huge.chunks <= GibPlanner.MAX_CHUNKS)


func test_armour_sheds_extra_plates() -> void:
	var wax := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 0.0, 60.0, false)
	var metal := GibPlanner.plan(ExhibitMaterial.Kind.METAL, 0.0, 60.0, false)
	assert_eq(metal.chunks, wax.chunks + 2)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=gib`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/combat/exhibit_material.gd`**
```gdscript
class_name ExhibitMaterial
## What an exhibit is made of. Drives hit particles, debris colour and
## sounds: wax melts and splashes, taxidermy sheds sawdust, marble cracks,
## armour sparks and loses plates.

enum Kind { WAX, TAXIDERMY, MARBLE, METAL }


## Colour of debris chunks.
static func color(kind: Kind) -> Color:
	match kind:
		Kind.WAX:
			return Color(0.93, 0.82, 0.62)
		Kind.TAXIDERMY:
			return Color(0.5, 0.38, 0.25)
		Kind.MARBLE:
			return Color(0.88, 0.88, 0.85)
		Kind.METAL:
			return Color(0.6, 0.62, 0.66)
	return Color.WHITE


## Colour of hit particles: wax drops, sawdust, stone dust, sparks.
static func particle_color(kind: Kind) -> Color:
	match kind:
		Kind.WAX:
			return Color(0.96, 0.78, 0.5)
		Kind.TAXIDERMY:
			return Color(0.86, 0.72, 0.48)
		Kind.MARBLE:
			return Color(0.92, 0.92, 0.9)
		Kind.METAL:
			return Color(1.0, 0.72, 0.3)
	return Color.WHITE


static func hit_sound(kind: Kind) -> StringName:
	match kind:
		Kind.WAX:
			return &"hit_wax"
		Kind.TAXIDERMY:
			return &"hit_sawdust"
		Kind.MARBLE:
			return &"hit_marble"
	return &"hit_metal"


static func break_sound(kind: Kind) -> StringName:
	match kind:
		Kind.WAX:
			return &"break_wax"
		Kind.TAXIDERMY:
			return &"break_sawdust"
		Kind.MARBLE:
			return &"break_marble"
	return &"break_metal"
```

**Plik: `src/combat/gib_planner.gd`**
```gdscript
class_name GibPlanner
## Decides how a destroyed exhibit falls apart. A plain kill makes it crumble
## into a few big pieces; heavy overkill (or a fist finisher) tears it into
## many small, fast ones. Armour always sheds a couple of extra plates.

const GIB_RATIO := 0.5
const MAX_IMPULSE := 10.0
const MAX_CHUNKS := 13


class Plan:
	var gibbed: bool = false
	var chunks: int = 3
	var chunk_size: float = 0.35
	var impulse: float = 2.0
	var particles: int = 24


## [param overkill] = damage beyond the health that was left.
static func plan(kind: ExhibitMaterial.Kind, overkill: float, max_health: float, finisher: bool) -> Plan:
	var result := Plan.new()
	var ratio := maxf(overkill, 0.0) / maxf(max_health, 1.0)
	result.gibbed = finisher or ratio >= GIB_RATIO
	if result.gibbed:
		result.chunks = 7 + mini(int(ratio * 2.0), 4)
		result.chunk_size = 0.22
		result.impulse = minf(5.0 + ratio * 2.5, MAX_IMPULSE)
		result.particles = 64
	else:
		result.chunks = 3
		result.chunk_size = 0.35
		result.impulse = 2.0 + ratio * 2.0
		result.particles = 24
	if kind == ExhibitMaterial.Kind.METAL:
		result.chunks += 2
	result.chunks = mini(result.chunks, MAX_CHUNKS)
	return result
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `30 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/combat/exhibit_material.gd src/combat/gib_planner.gd tests/unit/test_exhibit_material.gd tests/unit/test_gib_planner.gd
git commit -m "Add exhibit materials and gib planner" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 7: Usługi efektów — `Fx` i `Sfx`

`Fx` tworzy cząsteczki trafień, fizyczne odłamki (`RigidBody3D`), smugi pocisków, łuki paralizatora, błyski światła, dziury po kulach i hitstop, czyli ułamkowe zatrzymanie czasu przy mocnym zabiciu. Wszystko, co stworzy, podpina pod siebie i samo sprząta. Liczba odłamków i dziur ma limit. Pozycja każdego węzła jest ustawiana **przed** dodaniem do drzewa, bo przy włączonej interpolacji fizyki inaczej przez jedną klatkę „przelatywałby” z punktu (0,0,0).

`Sfx` odtwarza `res://assets/sfx/<nazwa>.wav` i po cichu pomija brakujące pliki. Przejmuje też zamykanie okna: najpierw wycisza wszystkie dźwięki i dopiero wtedy kończy grę, bo inaczej silnik zgłasza przy wyjściu „wyciekłe” odtwarzania. Dźwięki wygeneruje zadanie 19, a do tego czasu gra jest po prostu cicha.

**Pliki:**
- Utwórz: `src/fx/fx.gd`, `src/fx/sfx.gd`
- Zmień: `project.godot` (autoloady `Fx` i `Sfx`)
- Test: `tests/integration/test_fx.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_fx.gd`**
```gdscript
extends TestCase


func test_impact_adds_a_particle_burst() -> void:
	var before := Fx.get_child_count()
	Fx.impact(Vector3.ZERO, Vector3.UP, ExhibitMaterial.Kind.WAX)
	assert_eq(Fx.get_child_count(), before + 1)


func test_debris_is_capped() -> void:
	var plan := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 1000.0, 60.0, false)
	for i in 20:
		Fx.shatter(Vector3.ZERO, ExhibitMaterial.Kind.WAX, plan, Vector3.FORWARD)
	assert_gt(Fx.chunk_count(), 0)
	assert_true(Fx.chunk_count() <= Fx.MAX_CHUNKS, "chunks %d" % Fx.chunk_count())


func test_hitstop_slows_time_then_restores_it() -> void:
	Fx.hitstop(0.05)
	assert_lt(Engine.time_scale, 1.0)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_tracer_arc_flash_and_hole_spawn_nodes() -> void:
	var before := Fx.get_child_count()
	Fx.tracer(Vector3.ZERO, Vector3(0, 0, -5))
	Fx.arc(Vector3.ZERO, Vector3(0, 0, -3))
	Fx.flash(Vector3.ZERO, Color.WHITE, 1.0, 3.0, 0.1)
	Fx.bullet_hole(Vector3(0, 0, -5), Vector3(0, 0, 1))
	assert_gt(Fx.get_child_count(), before + 3)


func test_missing_sound_is_ignored() -> void:
	var before := Sfx.get_child_count()
	Sfx.play(&"no_such_sound")
	Sfx.play_at(&"no_such_sound", Vector3.ZERO)
	assert_eq(Sfx.get_child_count(), before)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=fx`
Oczekiwane: FAIL (brak `Fx`/`Sfx`).

- [ ] **Krok 3: Implementacja**

**Plik: `src/fx/fx.gd`**
```gdscript
extends Node
## Visual effects service (autoload "Fx"): hit particles, physical debris,
## tracers, taser arcs, light flashes, bullet holes and hitstop. Everything
## it spawns is parented here and removes itself after a while. Transforms
## are set before add_child() so physics interpolation never smears a node
## in from the origin.

const MAX_CHUNKS := 80
const MAX_DECALS := 60
const CHUNK_LIFETIME := 8.0
const DECAL_LIFETIME := 30.0

var _chunks: Array = []
var _decals: Array = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _hole: Texture2D = null
var _hitstop_token: int = 0


## Small burst where a hit lands. [param kind] is an ExhibitMaterial.Kind,
## or -1 for level geometry (grey dust).
func impact(position: Vector3, normal: Vector3, kind: int = -1, strength: float = 1.0) -> void:
	var color := Color(0.62, 0.6, 0.56)
	var glow := false
	var speed := 3.5
	var gravity := 9.8
	if kind >= 0:
		var material_kind := kind as ExhibitMaterial.Kind
		color = ExhibitMaterial.particle_color(material_kind)
		match material_kind:
			ExhibitMaterial.Kind.WAX:
				speed = 2.5
				gravity = 14.0
			ExhibitMaterial.Kind.TAXIDERMY:
				speed = 2.0
				gravity = 3.0
			ExhibitMaterial.Kind.METAL:
				speed = 7.0
				glow = true
	var amount := int(clampf(10.0 * strength, 4.0, 40.0))
	_burst(position, normal, color, glow, amount, speed, 0.7, 40.0, gravity, 0.045)


## Breaks an exhibit apart: a burst of particles plus physical chunks
## flying mostly along [param push].
func shatter(center: Vector3, kind: ExhibitMaterial.Kind, plan: GibPlanner.Plan, push: Vector3) -> void:
	var glow := kind == ExhibitMaterial.Kind.METAL
	_burst(center, Vector3.UP, ExhibitMaterial.particle_color(kind), glow, plan.particles, plan.impulse, 1.2, 180.0, 9.8, 0.06)
	var flat_push := Vector3(push.x, 0.0, push.z).normalized()
	for i in plan.chunks:
		var scatter := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.2), randf_range(-1.0, 1.0))
		var velocity := (flat_push * 0.8 + scatter * 0.7).normalized() * plan.impulse * randf_range(0.7, 1.2)
		var offset := Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.5), randf_range(-0.3, 0.3))
		chunk(center + offset, ExhibitMaterial.color(kind), plan.chunk_size * randf_range(0.7, 1.3), velocity)


## One physical debris piece. Shrinks away after CHUNK_LIFETIME seconds.
func chunk(position: Vector3, color: Color, size: float, velocity: Vector3) -> void:
	var dims := Vector3(size, size * randf_range(0.5, 1.2), size * randf_range(0.6, 1.4))
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var mesh := BoxMesh.new()
	mesh.size = dims
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _solid_material(color)
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = 0.4
	body.position = position
	body.add_child(collider)
	body.add_child(view)
	add_child(body)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
	_chunks.append(body)
	while _chunks.size() > MAX_CHUNKS:
		var oldest = _chunks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_shrink_and_free(body, view, CHUNK_LIFETIME)


## Thin glowing line (bullet trail).
func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.55), width: float = 0.012, duration: float = 0.05) -> void:
	var run := to - from
	if run.length() < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, run.length())
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.material_override = _glow_material(color)
	var up := Vector3.UP if absf(run.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	view.transform = Transform3D(Basis.looking_at(run.normalized(), up), (from + to) * 0.5)
	add_child(view)
	_free_after(view, duration)


## Jagged electric arc for the taser, with a blue flash at the far end.
func arc(from: Vector3, to: Vector3) -> void:
	var points: Array[Vector3] = [from]
	var segments := 7
	for i in range(1, segments):
		var t := float(i) / segments
		var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.12
		points.append(from.lerp(to, t) + jitter)
	points.append(to)
	for i in points.size() - 1:
		tracer(points[i], points[i + 1], Color(0.45, 0.8, 1.0), 0.02, 0.09)
	flash(to, Color(0.5, 0.8, 1.0), 2.5, 4.0, 0.12)


## Short-lived point light (muzzle flash, zap).
func flash(position: Vector3, color: Color, energy: float, light_range: float, duration: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = position
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


## Dark mark where a bullet hit a wall. Oldest ones disappear first.
func bullet_hole(position: Vector3, normal: Vector3) -> void:
	var decal := Decal.new()
	decal.texture_albedo = _hole_texture()
	decal.size = Vector3(0.14, 0.1, 0.14)
	decal.transform = Transform3D(_basis_with_up(normal), position)
	add_child(decal)
	_decals.append(decal)
	while _decals.size() > MAX_DECALS:
		var oldest = _decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_free_after(decal, DECAL_LIFETIME)


## Nearly freezes time for [param duration] real seconds (heavy kills).
func hitstop(duration: float, time_scale: float = 0.05) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func chunk_count() -> int:
	_chunks = _chunks.filter(func(c: Variant) -> bool: return is_instance_valid(c))
	return _chunks.size()


## Removes every effect at once (used between tests).
func clear() -> void:
	for child in get_children():
		child.queue_free()
	_chunks.clear()
	_decals.clear()
	_hitstop_token += 1
	Engine.time_scale = 1.0


func _burst(position: Vector3, direction: Vector3, color: Color, glow: bool, amount: int, speed: float, lifetime: float, spread_deg: float, gravity: float, size: float) -> void:
	var process := ParticleProcessMaterial.new()
	process.direction = direction.normalized() if direction.length() > 0.01 else Vector3.UP
	process.spread = spread_deg
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -gravity, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	process.color = color
	process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process.collision_bounce = 0.15
	process.collision_friction = 0.7
	var particles := GPUParticles3D.new()
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.process_material = process
	particles.draw_pass_1 = _particle_mesh(size, glow)
	particles.position = position
	add_child(particles)
	particles.emitting = true
	_free_after(particles, lifetime + 0.5)


func _particle_mesh(size: float, glow: bool) -> Mesh:
	var key := "%.3f_%s" % [size, glow]
	if not _meshes.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		if glow:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(4.0, 4.0, 4.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size
		mesh.material = material
		_meshes[key] = mesh
	return _meshes[key]


func _solid_material(color: Color) -> StandardMaterial3D:
	var key := "solid_" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		_materials[key] = material
	return _materials[key]


func _glow_material(color: Color) -> StandardMaterial3D:
	var key := "glow_" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0)
		_materials[key] = material
	return _materials[key]


func _hole_texture() -> Texture2D:
	if _hole == null:
		var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				image.set_pixel(x, y, Color(0.05, 0.04, 0.04, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
		_hole = ImageTexture.create_from_image(image)
	return _hole


## Basis whose +Y is [param up] (decals project along their -Y).
static func _basis_with_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var reference := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _free_after(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(node.queue_free)


func _shrink_and_free(body: Node3D, view: Node3D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(body):
		return
	_chunks.erase(body)
	var tween := body.create_tween()
	tween.tween_property(view, "scale", Vector3.ONE * 0.01, 0.6)
	tween.tween_callback(body.queue_free)
```

**Plik: `src/fx/sfx.gd`**
```gdscript
extends Node
## Sound service (autoload "Sfx"). Plays res://assets/sfx/<name>.wav
## (generated by tools/sfx/gen_sfx.py). Missing files are skipped silently,
## so gameplay never depends on audio.

const DIR := "res://assets/sfx/"
const MAX_VOICES := 32
## Every sound the game asks for; gen_sfx.py must produce all of them.
const SOUNDS: Array[StringName] = [
	&"pistol", &"shotgun", &"taser", &"punch", &"punch_hit", &"reload",
	&"empty", &"swing", &"hurt", &"dash", &"notice", &"growl",
	&"hit_marker", &"kill", &"pickup", &"block",
	&"hit_wax", &"break_wax", &"hit_sawdust", &"break_sawdust",
	&"hit_marble", &"break_marble", &"hit_metal", &"break_metal",
]

var _cache: Dictionary = {}


func _ready() -> void:
	# Closing the window goes through quit_cleanly(), so no sound is still
	# playing when the engine shuts down (it would report leaked playbacks).
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_cleanly.call_deferred()   # not while the notification is still propagating


## Silences every sound, lets the audio server settle, then quits.
func quit_cleanly(exit_code: int = 0) -> void:
	stop_all()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(exit_code)


## Non-positional sound (the guard's own weapon, UI).
func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var stream := _stream(sound)
	if stream == null or get_child_count() >= MAX_VOICES:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(player)
	player.play()
	_free_after(player, stream.get_length())


## Positional sound (exhibits, impacts).
func play_at(sound: StringName, position: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.1) -> void:
	var stream := _stream(sound)
	if stream == null or get_child_count() >= MAX_VOICES:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 8.0
	player.max_distance = 60.0
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.position = position
	add_child(player)
	player.play()
	_free_after(player, stream.get_length())


## Stops and removes every sound (clean shutdown: the audio server must not
## hold playbacks when the game quits).
func stop_all() -> void:
	for child in get_children():
		if child.has_method(&"stop"):
			child.call(&"stop")
		remove_child(child)
		child.queue_free()


func _stream(sound: StringName) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + String(sound) + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


func _free_after(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds + 0.25, true, false, true).timeout.connect(node.queue_free)
```

**Plik: `project.godot`**
```ini
; Engine configuration file.
; Hand-maintained: autoloads and the main scene are listed here.

config_version=5

[application]

config/name="Nocna Zmiana"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]

Events="*res://src/core/events.gd"
GameInput="*res://src/core/game_input.gd"
Fx="*res://src/fx/fx.gd"
Sfx="*res://src/fx/sfx.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemy"
3d_physics/layer_4="hurtbox"
3d_physics/layer_5="debris"
3d_physics/layer_6="pickup"

[physics]

3d/physics_engine="Jolt Physics"
common/physics_interpolation=true
common/physics_jitter_fix=0.0

[rendering]

anti_aliasing/quality/msaa_3d=2
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `35 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/fx project.godot tests/integration/test_fx.gd
git commit -m "Add Fx and Sfx effect services" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 8: Greybox i arena piaskownicy

Hala ma 44 × 44 m i ściany wysokie na 8 m. Są w niej cztery filary, podest na środku (0,6 m, da się na niego wskoczyć), skrzynie jako osłony oraz antresola na wysokości 3,75 m wzdłuż północnej ściany z balustradą i rampą. Arena daje walkę w pionie jak hol muzeum. Geometria leży pod `NavigationRegion3D`, a nawigację wypieka się w trakcie gry z kolizji. Tekstura to siatka metrowa, więc łatwo ocenić odległości.

**Pliki:**
- Utwórz: `src/arena/greybox.gd`, `src/arena/sandbox_arena.gd`
- Test: `tests/integration/test_sandbox_arena.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_sandbox_arena.gd`**
```gdscript
extends TestCase

var region: NavigationRegion3D


func before_each() -> void:
	region = NavigationRegion3D.new()
	add_child(region)
	SandboxArena.build(region)


func test_navigation_bakes_into_many_polygons() -> void:
	region.bake_navigation_mesh(false)
	assert_gt(region.navigation_mesh.get_polygon_count(), 10)


func test_floor_and_mezzanine_are_solid_at_expected_heights() -> void:
	await physics_frames(2)
	var space := region.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 10, 12), Vector3(0, -10, 12), Layers.WORLD))
	assert_almost_eq(floor_hit.get("position", Vector3.ONE * 99.0).y, 0.0, 0.01)
	var mezzanine_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-10, 10, -18), Vector3(-10, -10, -18), Layers.WORLD))
	assert_almost_eq(mezzanine_hit.get("position", Vector3.ONE * 99.0).y, SandboxArena.MEZZANINE_Y, 0.01)


func test_ramp_connects_floor_and_mezzanine() -> void:
	region.bake_navigation_mesh(false)
	await physics_frames(6)   # the navigation map syncs a few physics frames after baking
	var goal := Vector3(-10, SandboxArena.MEZZANINE_Y, -18)
	var path := NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(0, 0, 12), goal, true)
	assert_gt(path.size(), 1)
	if path.size() > 0:
		assert_lt(path[path.size() - 1].distance_to(goal), 1.0)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=arena`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/arena/greybox.gd`**
```gdscript
class_name Greybox
## Blockout geometry: static boxes and ramps with a world-aligned 1 m grid
## texture, so distances are easy to judge while the level is grey.

static var _materials: Dictionary = {}
static var _grid: Texture2D = null


## Adds a static box centred at [param center].
static func box(parent: Node, center: Vector3, size: Vector3, color: Color, orientation: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.transform = Transform3D(orientation, center)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material(color)
	body.add_child(view)
	parent.add_child(body)
	return body


## A walkable slab whose top surface runs along its centre line from
## [param from] to [param to].
static func ramp(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, thickness: float = 0.4) -> StaticBody3D:
	var run := to - from
	var orientation := Basis.looking_at(run.normalized(), Vector3.UP)
	var center := (from + to) * 0.5 - orientation.y * (thickness * 0.5)
	return box(parent, center, Vector3(width, thickness, run.length()), color, orientation)


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.albedo_texture = _grid_texture()
		mat.roughness = 0.85
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		_materials[color] = mat
	return _materials[color]


static func _grid_texture() -> Texture2D:
	if _grid == null:
		var image := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
		image.fill(Color(0.92, 0.92, 0.92))
		for i in 64:
			for edge in [0, 63]:
				image.set_pixel(i, edge, Color(0.55, 0.55, 0.55))
				image.set_pixel(edge, i, Color(0.55, 0.55, 0.55))
		image.generate_mipmaps()
		_grid = ImageTexture.create_from_image(image)
	return _grid
```

**Plik: `src/arena/sandbox_arena.gd`**
```gdscript
class_name SandboxArena
## Layout of the grey combat sandbox: a 44 x 44 m hall with four pillars,
## a jumpable dais, cover crates and a mezzanine along the north wall reached
## by a ramp. Also sets up the night lighting and fog.

const FLOOR := Color(0.42, 0.42, 0.45)
const WALL := Color(0.62, 0.6, 0.58)
const ACCENT := Color(0.55, 0.45, 0.35)
## Height of the mezzanine's walkable surface.
const MEZZANINE_Y := 3.75


static func build(region: NavigationRegion3D) -> void:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = Layers.WORLD
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 2.0
	navmesh.agent_max_climb = 0.25
	navmesh.agent_max_slope = 40.0
	region.navigation_mesh = navmesh
	# floor and outer walls
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(44, 1, 44), FLOOR)
	Greybox.box(region, Vector3(0, 4, -22.5), Vector3(46, 8, 1), WALL)
	Greybox.box(region, Vector3(0, 4, 22.5), Vector3(46, 8, 1), WALL)
	Greybox.box(region, Vector3(-22.5, 4, 0), Vector3(1, 8, 44), WALL)
	Greybox.box(region, Vector3(22.5, 4, 0), Vector3(1, 8, 44), WALL)
	# pillars
	for x in [-8.0, 8.0]:
		for z in [-6.0, 6.0]:
			Greybox.box(region, Vector3(x, 4, z), Vector3(1.5, 8, 1.5), WALL)
	# central dais (0.6 m, jumpable) and cover crates
	Greybox.box(region, Vector3(0, 0.3, 0), Vector3(6, 0.6, 6), ACCENT)
	for crate in [Vector3(-14, 0.75, 10), Vector3(13, 0.75, 12), Vector3(-4, 0.75, -12), Vector3(12, 0.75, 2)]:
		Greybox.box(region, crate, Vector3(1.5, 1.5, 1.5), ACCENT)
	# mezzanine (z -22..-13) with a railing gap for the ramp at x 14..18
	Greybox.box(region, Vector3(0, MEZZANINE_Y - 0.25, -17.5), Vector3(44, 0.5, 9), FLOOR)
	Greybox.box(region, Vector3(-4, MEZZANINE_Y + 0.5, -13.1), Vector3(36, 1.0, 0.2), WALL)
	Greybox.box(region, Vector3(20, MEZZANINE_Y + 0.5, -13.1), Vector3(4, 1.0, 0.2), WALL)
	Greybox.ramp(region, Vector3(16, 0, -2), Vector3(16, MEZZANINE_Y, -13), 4.0, ACCENT)


static func add_lighting(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.8, 0.85, 1.0)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	parent.add_child(moon)
	for spot in [Vector3(-8, 6, -5), Vector3(8, 6, -5), Vector3(-8, 6, 7), Vector3(8, 6, 7)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.78, 0.5)
		lamp.light_energy = 1.6
		lamp.omni_range = 14.0
		lamp.shadow_enabled = true
		lamp.position = spot
		parent.add_child(lamp)
	# lets hit particles land on the floor and the mezzanine
	var particle_floor := GPUParticlesCollisionHeightField3D.new()
	particle_floor.size = Vector3(44, 12, 44)
	particle_floor.position = Vector3(0, 5, 0)
	particle_floor.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	parent.add_child(particle_floor)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `38 passed, 0 failed`. Jeśli nie przejdzie `test_ramp_connects_floor_and_mezzanine`, sprawdź, czy górny koniec rampy (z = −13) styka się z krawędzią antresoli.

- [ ] **Krok 5: Commit**

```bash
git add src/arena tests/integration/test_sandbox_arena.gd
git commit -m "Add greybox builder and sandbox arena layout" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 9: Dane broni i stan broni

`WeaponData` to zasób z liczbami. W etapie 2 ulepszenia będą modyfikować jego kopie. `WeaponState` to stan w trakcie gry: magazynek i zapas, bateria, odstęp między strzałami, przeładowanie. Obsługuje trzy tryby amunicji:

- brak (pięści),
- bateria ładująca się sama po chwili (paralizator: trzy strzały z pełnej),
- magazynek plus zapas (pistolet: 12 naboi; strzelba: dwulufowa, 2 naboje).

**Pliki:**
- Utwórz: `src/weapons/weapon_data.gd`, `src/weapons/weapon_state.gd`, `src/weapons/data/fists.tres`, `src/weapons/data/taser.tres`, `src/weapons/data/pistol.tres`, `src/weapons/data/shotgun.tres`
- Test: `tests/unit/test_weapon_state.gd`, `tests/unit/test_weapon_data.gd`

- [ ] **Krok 1: Testy**

**Plik: `tests/unit/test_weapon_state.gd`**
```gdscript
extends TestCase


func _magazine_weapon() -> WeaponData:
	var data := WeaponData.new()
	data.id = &"test_gun"
	data.cooldown = 0.2
	data.ammo_mode = WeaponData.AmmoMode.MAGAZINE
	data.ammo_type = &"bullets"
	data.magazine_size = 3
	data.reload_time = 1.0
	data.start_reserve = 4
	data.max_reserve = 10
	return data


func _battery_weapon() -> WeaponData:
	var data := WeaponData.new()
	data.id = &"test_zapper"
	data.cooldown = 0.1
	data.ammo_mode = WeaponData.AmmoMode.BATTERY
	data.battery_max = 100.0
	data.battery_cost = 33.0
	data.battery_recharge_per_sec = 20.0
	data.battery_recharge_delay = 0.5
	return data


func test_starts_with_full_magazine_and_reserve() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_eq(state.magazine, 3)
	assert_eq(state.reserve, 4)


func test_firing_uses_a_round_and_starts_cooldown() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_true(state.can_fire())
	state.fire()
	assert_eq(state.magazine, 2)
	assert_false(state.can_fire())
	state.tick(0.21)
	assert_true(state.can_fire())


func test_empty_magazine_cannot_fire() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 0
	assert_false(state.can_fire())
	assert_false(state.has_ammo_for_shot())


func test_reload_moves_rounds_from_reserve_after_reload_time() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 1
	assert_true(state.start_reload())
	assert_true(state.is_reloading())
	assert_false(state.can_fire())
	state.tick(0.5)
	assert_eq(state.magazine, 1)
	state.tick(0.6)
	assert_false(state.is_reloading())
	assert_eq(state.magazine, 3)
	assert_eq(state.reserve, 2)


func test_reload_with_short_reserve_takes_what_is_left() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 0
	state.reserve = 1
	state.start_reload()
	state.tick(1.1)
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 0)


func test_no_reload_when_full_or_reserve_empty() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_false(state.start_reload(), "full")
	state.magazine = 1
	state.reserve = 0
	assert_false(state.start_reload(), "no reserve")


func test_cancel_reload_keeps_magazine() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 1
	state.start_reload()
	state.cancel_reload()
	state.tick(2.0)
	assert_eq(state.magazine, 1)


func test_add_ammo_caps_at_max_reserve() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_eq(state.add_ammo(4), 4)
	assert_eq(state.add_ammo(5), 2)
	assert_eq(state.reserve, 10)


func test_battery_gives_three_shots_then_recharges_after_delay() -> void:
	var state := WeaponState.new(_battery_weapon())
	for i in 3:
		assert_true(state.can_fire(), "shot %d" % i)
		state.fire()
		state.tick(0.11)
	assert_false(state.can_fire(), "battery drained")
	state.tick(0.3)
	assert_false(state.can_fire(), "still waiting")
	state.tick(1.8)
	assert_true(state.can_fire(), "recharged")


func test_battery_weapon_ignores_ammo_pickups() -> void:
	var state := WeaponState.new(_battery_weapon())
	assert_eq(state.add_ammo(10), 0)
```

**Plik: `tests/unit/test_weapon_data.gd`**
```gdscript
extends TestCase

const IDS: Array[StringName] = [&"fists", &"taser", &"pistol", &"shotgun"]


func test_all_weapon_files_load_with_matching_ids() -> void:
	for id in IDS:
		var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
		assert_not_null(data, str(id))
		if data != null:
			assert_eq(data.id, id)
			assert_ne(data.display_name, "")


func test_synergy_numbers() -> void:
	var fists: WeaponData = load("res://src/weapons/data/fists.tres")
	var taser: WeaponData = load("res://src/weapons/data/taser.tres")
	var pistol: WeaponData = load("res://src/weapons/data/pistol.tres")
	assert_true(fists.can_finish, "fists finish stunned exhibits")
	assert_gt(taser.stun_time, 0.0)
	assert_eq(taser.damage_kind, DamageInfo.Kind.ELECTRIC)
	assert_gt(pistol.weak_point_multiplier, 1.0)
	assert_eq(int(taser.battery_max / taser.battery_cost), 3)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=weapon`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/weapons/weapon_data.gd`**
```gdscript
class_name WeaponData
extends Resource
## Tunable numbers for one weapon. Stage 2 upgrades will modify copies.

enum AmmoMode { NONE, BATTERY, MAGAZINE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var damage: float = 10.0
@export var damage_kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC
## Rays per shot (shotgun pellets).
@export var pellets: int = 1
## Half-angle of the random cone, in degrees.
@export var spread_deg: float = 0.0
@export var max_range: float = 100.0
## Seconds between shots.
@export var cooldown: float = 0.3
@export var stun_time: float = 0.0
## Push per ray that hits (pellets add up).
@export var knockback: float = 0.0
@export var weak_point_multiplier: float = 1.0
@export var can_finish: bool = false
## > 0 turns the attack into a sphere sweep of this radius (fists).
@export var melee_radius: float = 0.0

@export_group("Ammo")
@export var ammo_mode: AmmoMode = AmmoMode.NONE
## Pickups with this type refill the reserve.
@export var ammo_type: StringName = &""
@export var magazine_size: int = 0
@export var reload_time: float = 0.0
@export var start_reserve: int = 0
@export var max_reserve: int = 0
@export var battery_max: float = 0.0
@export var battery_cost: float = 0.0
@export var battery_recharge_per_sec: float = 0.0
@export var battery_recharge_delay: float = 0.0

@export_group("Feel")
@export var shake: float = 0.15
@export var kick: float = 0.05
@export var sound: StringName = &""
```

**Plik: `src/weapons/weapon_state.gd`**
```gdscript
class_name WeaponState
extends RefCounted
## Runtime state of one owned weapon: magazine and reserve, battery,
## cooldown and reload. Pure logic, ticked by the WeaponHolder.

var data: WeaponData
var magazine: int = 0
var reserve: int = 0
var battery: float = 0.0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _recharge_wait: float = 0.0


func _init(weapon: WeaponData) -> void:
	data = weapon
	magazine = weapon.magazine_size
	reserve = weapon.start_reserve
	battery = weapon.battery_max


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	if data.ammo_mode == WeaponData.AmmoMode.BATTERY:
		var charge_time := delta
		if _recharge_wait > 0.0:
			charge_time = maxf(delta - _recharge_wait, 0.0)
			_recharge_wait = maxf(_recharge_wait - delta, 0.0)
		battery = minf(battery + data.battery_recharge_per_sec * charge_time, data.battery_max)


func is_reloading() -> bool:
	return _reload_left > 0.0


func has_ammo_for_shot() -> bool:
	match data.ammo_mode:
		WeaponData.AmmoMode.BATTERY:
			return battery >= data.battery_cost
		WeaponData.AmmoMode.MAGAZINE:
			return magazine > 0
	return true


func can_fire() -> bool:
	return _cooldown <= 0.0 and not is_reloading() and has_ammo_for_shot()


## Uses ammo and starts the cooldown. Call only after can_fire().
func fire() -> void:
	_cooldown = data.cooldown
	match data.ammo_mode:
		WeaponData.AmmoMode.BATTERY:
			battery -= data.battery_cost
			_recharge_wait = data.battery_recharge_delay
		WeaponData.AmmoMode.MAGAZINE:
			magazine -= 1


func can_reload() -> bool:
	return data.ammo_mode == WeaponData.AmmoMode.MAGAZINE and not is_reloading() \
			and magazine < data.magazine_size and reserve > 0


func start_reload() -> bool:
	if not can_reload():
		return false
	_reload_left = data.reload_time
	return true


func cancel_reload() -> void:
	_reload_left = 0.0


## Adds reserve ammo up to the cap. Returns how much was taken.
func add_ammo(amount: int) -> int:
	if data.ammo_mode != WeaponData.AmmoMode.MAGAZINE:
		return 0
	var taken := clampi(amount, 0, data.max_reserve - reserve)
	reserve += taken
	return taken


func _finish_reload() -> void:
	_reload_left = 0.0
	var moved := mini(data.magazine_size - magazine, reserve)
	magazine += moved
	reserve -= moved
```

**Plik: `src/weapons/data/fists.tres`**
```text
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/weapons/weapon_data.gd" id="1_data"]

[resource]
script = ExtResource("1_data")
id = &"fists"
display_name = "Pięści"
damage = 15.0
damage_kind = 0
max_range = 1.7
cooldown = 0.4
knockback = 6.0
can_finish = true
melee_radius = 0.7
ammo_mode = 0
shake = 0.12
kick = 0.0
sound = &"punch"
```

**Plik: `src/weapons/data/taser.tres`**
```text
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/weapons/weapon_data.gd" id="1_data"]

[resource]
script = ExtResource("1_data")
id = &"taser"
display_name = "Paralizator"
damage = 4.0
damage_kind = 1
max_range = 7.0
cooldown = 0.5
stun_time = 3.0
ammo_mode = 1
battery_max = 100.0
battery_cost = 33.0
battery_recharge_per_sec = 22.0
battery_recharge_delay = 0.8
shake = 0.1
kick = 0.03
sound = &"taser"
```

**Plik: `src/weapons/data/pistol.tres`**
```text
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/weapons/weapon_data.gd" id="1_data"]

[resource]
script = ExtResource("1_data")
id = &"pistol"
display_name = "Pistolet"
damage = 20.0
damage_kind = 2
max_range = 120.0
cooldown = 0.26
knockback = 1.5
weak_point_multiplier = 2.0
ammo_mode = 2
ammo_type = &"bullets"
magazine_size = 12
reload_time = 1.1
start_reserve = 36
max_reserve = 150
shake = 0.12
kick = 0.06
sound = &"pistol"
```

**Plik: `src/weapons/data/shotgun.tres`**
```text
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/weapons/weapon_data.gd" id="1_data"]

[resource]
script = ExtResource("1_data")
id = &"shotgun"
display_name = "Strzelba"
damage = 9.0
damage_kind = 2
pellets = 10
spread_deg = 7.0
max_range = 45.0
cooldown = 0.3
knockback = 1.2
weak_point_multiplier = 1.25
ammo_mode = 2
ammo_type = &"shells"
magazine_size = 2
reload_time = 1.25
start_reserve = 10
max_reserve = 50
shake = 0.45
kick = 0.18
sound = &"shotgun"
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `50 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/weapons tests/unit/test_weapon_state.gd tests/unit/test_weapon_data.gd
git commit -m "Add weapon data resources and weapon state" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 10: Strefy trafień i promienie

`Hurtbox` to `Area3D` na warstwie `HURTBOX`, która przekazuje trafienie do swojego `receiver`. `Hitscan` zawiera trzy narzędzia: promień (świat plus strefy trafień), losowy kierunek w stożku rozrzutu i kulę dla ciosów wręcz. `TargetDummy` to manekin do testów, który zapisuje otrzymane trafienia.

**Pliki:**
- Utwórz: `src/combat/hurtbox.gd`, `src/combat/hitscan.gd`, `tests/support/target_dummy.gd`
- Test: `tests/integration/test_hitscan.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/support/target_dummy.gd`**
```gdscript
class_name TargetDummy
extends Node3D
## Stand-in target for tests: records every hit it receives.

var hits: Array[DamageInfo] = []


func take_damage(info: DamageInfo) -> void:
	hits.append(info)
```

**Plik: `tests/integration/test_hitscan.gd`**
```gdscript
extends TestCase

var dummy: TargetDummy
var head: Hurtbox


func before_each() -> void:
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, -6)
	add_child(dummy)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	head = Hurtbox.make(dummy, sphere, Vector3(0, 1.5, 0), true)
	dummy.add_child(head)


func test_ray_reports_the_hurtbox_it_hits() -> void:
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -20))
	assert_eq(hit.get("hurtbox"), head)
	assert_almost_eq(hit["position"].z, -5.7, 0.01)


func test_walls_block_rays() -> void:
	Greybox.box(self, Vector3(0, 1.5, -3), Vector3(4, 3, 0.5), Color.GRAY)
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -20))
	assert_true(hit.get("hurtbox") == null)
	assert_almost_eq(hit["position"].z, -2.75, 0.01)


func test_spread_stays_inside_the_cone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var forward := Vector3(0, 0, -1)
	var widest := 0.0
	for i in 500:
		var dir := Hitscan.spread_direction(forward, 7.0, rng)
		widest = maxf(widest, rad_to_deg(forward.angle_to(dir)))
		if absf(dir.length() - 1.0) > 0.0001:
			fail("direction not normalized")
			break
	assert_true(widest <= 7.0001, "widest %s" % widest)
	assert_gt(widest, 5.0)


func test_zero_spread_is_exact() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(Hitscan.spread_direction(Vector3(0, 0, -1), 0.0, rng), Vector3(0, 0, -1))


func test_sphere_sweep_finds_close_hurtboxes_only() -> void:
	var near := TargetDummy.new()
	near.position = Vector3(0, 0, -1)
	add_child(near)
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	var near_box := Hurtbox.make(near, box, Vector3(0, 1.5, 0))
	near.add_child(near_box)
	await physics_frames(2)
	var found := Hitscan.sphere_hurtboxes(near.get_world_3d().direct_space_state, Vector3(0, 1.5, -1.2), 0.7)
	assert_eq(found.size(), 1)
	if found.size() == 1:
		assert_eq(found[0], near_box)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=hitscan`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/combat/hurtbox.gd`**
```gdscript
class_name Hurtbox
extends Area3D
## Damage-receiving zone. Weapons look for Hurtboxes and send the hit to
## [member receiver] (a node with take_damage()). Weak points (heads) get
## the weapon's weak_point_multiplier.

@export var weak_point: bool = false
var receiver: Node = null


func _init() -> void:
	collision_layer = Layers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true


## Builds a hurtbox with one shape at a local [param offset].
static func make(receiver_: Node, shape: Shape3D, offset: Vector3, weak: bool = false) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	hurtbox.receiver = receiver_
	hurtbox.weak_point = weak
	hurtbox.position = offset
	var collider := CollisionShape3D.new()
	collider.shape = shape
	hurtbox.add_child(collider)
	return hurtbox
```

**Plik: `src/combat/hitscan.gd`**
```gdscript
class_name Hitscan
## Static helpers for instant-hit weapons and melee sweeps.


## Casts a ray against level geometry and hurtboxes. Returns {} on a miss,
## else {position, normal, collider, hurtbox (null for walls)}.
static func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.HURTBOX)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {
		"position": hit["position"],
		"normal": hit["normal"],
		"collider": hit["collider"],
		"hurtbox": hit["collider"] as Hurtbox,
	}


## Random direction inside a cone around [param forward]
## ([param spread_deg] = half-angle).
static func spread_direction(forward: Vector3, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	var dir := forward.normalized()
	if spread_deg <= 0.0:
		return dir
	var angle := deg_to_rad(spread_deg) * sqrt(rng.randf())
	var spin := rng.randf() * TAU
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var offset := (side * cos(spin) + up * sin(spin)) * tan(angle)
	return (dir + offset).normalized()


## Hurtboxes overlapping a sphere (melee), closest first.
static func sphere_hurtboxes(space: PhysicsDirectSpaceState3D, center: Vector3, radius: float) -> Array[Hurtbox]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = Layers.HURTBOX
	var found: Array[Hurtbox] = []
	for hit in space.intersect_shape(query, 16):
		var hurtbox := hit["collider"] as Hurtbox
		if hurtbox != null and not found.has(hurtbox):
			found.append(hurtbox)
	found.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	return found
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `55 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/combat/hurtbox.gd src/combat/hitscan.gd tests/support tests/integration/test_hitscan.gd
git commit -m "Add hurtboxes and hitscan helpers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Zadanie 11: Arsenał strażnika — `WeaponHolder` i modele w dłoni

`WeaponHolder` siedzi pod kamerą. Jego oś −Z to kierunek celowania. Odpowiada za:

- zmianę broni (1/2/3, kółko), przy czym kolejność slotów to zawsze paralizator, pistolet, strzelba, niezależnie od kolejności znajdowania,
- strzał promieniami: śruciny trafiające ten sam cel sumują się w **jedno** trafienie, żeby planista rozpadu widział prawdziwy nadmiar obrażeń,
- cios pięścią zamachem kulistym (PPM/V, niezależnie od trzymanej broni),
- przeładowanie, w tym automatyczne po opróżnieniu magazynka, anulowane przy zmianie broni,
- amunicję z podnoszonych skrzynek,
- szare modele broni: kołysanie przy chodzie, odrzut, opuszczanie przy zmianie i przeładowaniu.

Materiały modeli w dłoni używają wbudowanych w Godot 4.7 opcji `use_fov_override` i `use_z_clip_scale`. Broń ma własne pole widzenia i spłaszczoną głębię, więc nie wchodzi w ściany.

Wejście z klawiatury i myszy czytane jest tylko przy przechwyconym kursorze. Testy wołają `try_fire()` i `try_punch()` bezpośrednio.

**Pliki:**
- Utwórz: `src/weapons/viewmodels.gd`, `src/weapons/weapon_holder.gd`
- Test: `tests/integration/test_weapon_holder.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_weapon_holder.gd`**
```gdscript
extends TestCase

var user: Node3D
var holder: WeaponHolder
var dummy: TargetDummy


func before_each() -> void:
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.0, 0)
	user.add_child(holder)
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, -6)
	add_child(dummy)
	var body := BoxShape3D.new()
	body.size = Vector3(0.8, 1.2, 0.8)
	dummy.add_child(Hurtbox.make(dummy, body, Vector3(0, 0.9, 0)))
	var head := SphereShape3D.new()
	head.radius = 0.25
	dummy.add_child(Hurtbox.make(dummy, head, Vector3(0, 1.8, 0), true))


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func test_pistol_shot_hits_the_body_for_base_damage() -> void:
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 20.0)
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.BALLISTIC)
		assert_eq(dummy.hits[0].source, user)
		assert_false(dummy.hits[0].weak_point)


func test_pistol_headshot_doubles_damage() -> void:
	holder.position = Vector3(0, 1.8, 0)
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 40.0)
		assert_true(dummy.hits[0].weak_point)


func test_shotgun_pellets_merge_into_one_hit() -> void:
	dummy.position = Vector3(0, 0, -2.5)
	holder.give(_weapon(&"shotgun"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 90.0)
		assert_almost_eq(dummy.hits[0].knockback, 12.0)


func test_taser_hit_is_electric_and_stuns() -> void:
	holder.give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.ELECTRIC)
		assert_eq(dummy.hits[0].stun_time, 3.0)


func test_taser_does_not_reach_far() -> void:
	dummy.position = Vector3(0, 0, -12)
	holder.give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 0)


func test_fists_hit_close_and_can_finish() -> void:
	dummy.position = Vector3(0, 0, -1.3)
	await physics_frames(2)
	assert_true(holder.try_punch())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_true(dummy.hits[0].can_finish)
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.BLUNT)


func test_fists_do_not_reach_far() -> void:
	dummy.position = Vector3(0, 0, -4)
	await physics_frames(2)
	holder.try_punch()
	assert_eq(dummy.hits.size(), 0)


func test_emptying_the_magazine_starts_a_reload() -> void:
	var data: WeaponData = _weapon(&"pistol").duplicate()
	data.cooldown = 0.0
	var state := holder.give(data)
	await physics_frames(2)
	for i in 12:
		holder.try_fire()
	assert_eq(state.magazine, 0)
	assert_true(state.is_reloading())
	assert_false(holder.try_fire())
	state.tick(1.2)
	assert_eq(state.magazine, 12)
	assert_eq(state.reserve, 24)


func test_switching_weapons_cancels_reload() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	holder.give(_weapon(&"shotgun"))
	pistol.magazine = 5
	assert_true(holder.try_reload())
	holder.select_id(&"shotgun")
	assert_false(pistol.is_reloading())
	assert_eq(holder.current_state().data.id, &"shotgun")


func test_slot_order_is_taser_pistol_shotgun() -> void:
	holder.give(_weapon(&"shotgun"))
	holder.give(_weapon(&"taser"))
	holder.give(_weapon(&"pistol"))
	var ids := []
	for state in holder.owned:
		ids.append(state.data.id)
	assert_eq(ids, [&"taser", &"pistol", &"shotgun"])
	assert_eq(holder.current_state().data.id, &"shotgun", "first weapon stays selected")


func test_ammo_pickup_goes_to_the_matching_weapon() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	assert_eq(holder.add_ammo(&"bullets", 10), 10)
	assert_eq(pistol.reserve, 46)
	assert_eq(holder.add_ammo(&"shells", 5), 0, "no shotgun yet")


func test_cycle_wraps_around() -> void:
	holder.give(_weapon(&"taser"))
	holder.give(_weapon(&"pistol"))
	holder.cycle(-1)
	assert_eq(holder.current_state().data.id, &"pistol")
	holder.cycle(1)
	assert_eq(holder.current_state().data.id, &"taser")


func test_disabled_holder_does_not_attack() -> void:
	holder.give(_weapon(&"pistol"))
	holder.enabled = false
	await physics_frames(2)
	assert_false(holder.try_fire())
	assert_false(holder.try_punch())
	assert_eq(dummy.hits.size(), 0)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=weapon_holder`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/weapons/viewmodels.gd`**
```gdscript
class_name Viewmodels
## Greybox first-person weapon models (boxes and cylinders), built in code.
## Every model has a "Muzzle" marker. Materials use the engine's viewmodel
## options (own FOV + squashed depth), so weapons never poke into walls.

const FOV := 55.0

static var _materials: Dictionary = {}


static func build(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = String(id)
	match id:
		&"taser":
			_box(root, Vector3(0.07, 0.08, 0.18), Vector3.ZERO, Color(0.85, 0.7, 0.1))
			_box(root, Vector3(0.05, 0.12, 0.06), Vector3(0.0, -0.08, 0.05), Color(0.22, 0.22, 0.22))
			_box(root, Vector3(0.012, 0.012, 0.04), Vector3(-0.02, 0.01, -0.11), Color(0.8, 0.8, 0.85))
			_box(root, Vector3(0.012, 0.012, 0.04), Vector3(0.02, 0.01, -0.11), Color(0.8, 0.8, 0.85))
			_muzzle(root, Vector3(0.0, 0.01, -0.13))
		&"pistol":
			_box(root, Vector3(0.05, 0.07, 0.22), Vector3.ZERO, Color(0.34, 0.34, 0.37))
			_box(root, Vector3(0.045, 0.13, 0.06), Vector3(0.0, -0.09, 0.07), Color(0.22, 0.16, 0.12), Vector3(-12.0, 0.0, 0.0))
			_muzzle(root, Vector3(0.0, 0.01, -0.12))
		&"shotgun":
			_tube(root, 0.022, 0.62, Vector3(-0.024, 0.0, -0.16), Color(0.3, 0.3, 0.33))
			_tube(root, 0.022, 0.62, Vector3(0.024, 0.0, -0.16), Color(0.3, 0.3, 0.33))
			_box(root, Vector3(0.07, 0.07, 0.34), Vector3(0.0, -0.035, 0.2), Color(0.5, 0.3, 0.15))
			_muzzle(root, Vector3(0.0, 0.0, -0.48))
		&"fist":
			_box(root, Vector3(0.1, 0.09, 0.12), Vector3.ZERO, Color(0.22, 0.17, 0.14))
			_box(root, Vector3(0.09, 0.08, 0.14), Vector3(0.0, -0.005, 0.12), Color(0.15, 0.2, 0.35))
			_muzzle(root, Vector3(0.0, 0.0, -0.08))
	return root


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.45
		mat.metallic = 0.2
		mat.use_fov_override = true
		mat.fov_override = FOV
		mat.use_z_clip_scale = true
		mat.z_clip_scale = 0.25
		_materials[color] = mat
	return _materials[color]


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(parent, mesh, pos, rot_deg, color)


## Cylinder lying along Z (barrels).
static func _tube(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	_add(parent, mesh, pos, Vector3(90.0, 0.0, 0.0), color)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, color: Color) -> void:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = pos
	view.rotation_degrees = rot_deg
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.material_override = material(color)
	parent.add_child(view)


static func _muzzle(parent: Node3D, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = pos
	parent.add_child(marker)
```

**Plik: `src/weapons/weapon_holder.gd`**
```gdscript
class_name WeaponHolder
extends Node3D
## The guard's arsenal: switching, firing (hitscan rays or a melee sweep),
## reloading, ammo pickups and greybox viewmodels. Lives under the camera;
## its -Z axis is the aim direction. Pellets that hit the same target are
## merged into one DamageInfo so overkill (and gibbing) is judged fairly.

signal weapon_changed(state: WeaponState)

const SLOT_ORDER: Array[StringName] = [&"taser", &"pistol", &"shotgun"]
const FISTS: WeaponData = preload("res://src/weapons/data/fists.tres")
const REST := Vector3(0.17, -0.16, -0.55)
## Weapons turn slightly toward the crosshair so their side is visible.
const AIM_YAW := 0.1
const FIST_REST := Vector3(-0.2, -0.32, -0.3)
const FIST_HIT := Vector3(-0.05, -0.14, -0.62)

## The node credited with hits (the player). It is never hit itself.
var user: Node3D = null
var enabled: bool = true
var owned: Array[WeaponState] = []
var current: int = -1
var fists: WeaponState

var _views: Dictionary = {}
var _fist_view: Node3D
var _kick: float = 0.0
var _switch_drop: float = 0.0
var _reload_drop: float = 0.0
var _bob_time: float = 0.0
var _empty_click_cd: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	fists = WeaponState.new(FISTS)
	_fist_view = Viewmodels.build(&"fist")
	_fist_view.position = FIST_REST
	_fist_view.visible = false
	add_child(_fist_view)


## Adds a weapon (no duplicates) keeping slot order; selects it if it is the
## first one. Returns its state.
func give(data: WeaponData) -> WeaponState:
	for state in owned:
		if state.data.id == data.id:
			return state
	var previous := current_state()
	var added := WeaponState.new(data)
	owned.append(added)
	owned.sort_custom(func(a: WeaponState, b: WeaponState) -> bool:
		return SLOT_ORDER.find(a.data.id) < SLOT_ORDER.find(b.data.id))
	var view := Viewmodels.build(data.id)
	view.position = REST
	view.visible = false
	add_child(view)
	_views[data.id] = view
	if previous == null:
		select(owned.find(added))
	else:
		current = owned.find(previous)
	return added


func has_weapon(id: StringName) -> bool:
	return _index_of(id) >= 0


func current_state() -> WeaponState:
	if current < 0 or current >= owned.size():
		return null
	return owned[current]


func select(index: int) -> void:
	if index < 0 or index >= owned.size() or index == current:
		return
	var old := current_state()
	if old != null:
		old.cancel_reload()
		(_views[old.data.id] as Node3D).visible = false
	current = index
	var state := owned[index]
	(_views[state.data.id] as Node3D).visible = true
	_switch_drop = 0.25
	weapon_changed.emit(state)


func select_id(id: StringName) -> void:
	select(_index_of(id))


func cycle(step: int) -> void:
	if owned.size() > 1:
		select(wrapi(current + step, 0, owned.size()))


func try_fire() -> bool:
	var state := current_state()
	if not enabled or state == null:
		return false
	if not state.can_fire():
		if not state.has_ammo_for_shot() and not state.is_reloading() and not _start_reload(state):
			_click_empty()
		return false
	state.fire()
	_attack(state)
	_kick = state.data.kick
	if state.data.ammo_mode == WeaponData.AmmoMode.MAGAZINE and state.magazine == 0:
		_start_reload(state)
	return true


func try_punch() -> bool:
	if not enabled or not fists.can_fire():
		return false
	fists.fire()
	_attack(fists)
	_animate_punch()
	return true


func try_reload() -> bool:
	var state := current_state()
	return enabled and state != null and _start_reload(state)


## Adds reserve ammo to the owned weapon using [param ammo_type].
## Returns how much was taken.
func add_ammo(ammo_type: StringName, amount: int) -> int:
	for state in owned:
		if state.data.ammo_type == ammo_type:
			return state.add_ammo(amount)
	return 0


func _physics_process(delta: float) -> void:
	fists.tick(delta)
	for state in owned:
		state.tick(delta)
	_empty_click_cd = maxf(_empty_click_cd - delta, 0.0)
	if not _input_allowed():
		return
	if Input.is_action_pressed(&"fire"):
		try_fire()
	if Input.is_action_just_pressed(&"punch"):
		try_punch()
	if Input.is_action_just_pressed(&"reload"):
		try_reload()


func _unhandled_input(event: InputEvent) -> void:
	if not _input_allowed():
		return
	if event.is_action_pressed(&"weapon_1"):
		select_id(&"taser")
	elif event.is_action_pressed(&"weapon_2"):
		select_id(&"pistol")
	elif event.is_action_pressed(&"weapon_3"):
		select_id(&"shotgun")
	elif event.is_action_pressed(&"weapon_next"):
		cycle(1)
	elif event.is_action_pressed(&"weapon_prev"):
		cycle(-1)


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-14.0 * delta))
	_switch_drop = move_toward(_switch_drop, 0.0, 1.5 * delta)
	var state := current_state()
	if state == null:
		return
	_reload_drop = lerpf(_reload_drop, 0.12 if state.is_reloading() else 0.0, 1.0 - exp(-12.0 * delta))
	var speed := 0.0
	var body := user as CharacterBody3D
	if body != null:
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	_bob_time += delta * speed * 1.6
	var sway := minf(speed / 5.5, 1.5)
	var bob := Vector3(sin(_bob_time) * 0.012, -absf(cos(_bob_time)) * 0.012, 0.0) * sway
	var view: Node3D = _views[state.data.id]
	view.position = REST + bob + Vector3(0.0, -_switch_drop - _reload_drop, _kick)
	view.rotation = Vector3(_kick * 2.5, AIM_YAW, 0.0)


func _input_allowed() -> bool:
	return enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _index_of(id: StringName) -> int:
	for i in owned.size():
		if owned[i].data.id == id:
			return i
	return -1


func _start_reload(state: WeaponState) -> bool:
	if not state.start_reload():
		return false
	Sfx.play(&"reload", -4.0)
	return true


func _click_empty() -> void:
	if _empty_click_cd <= 0.0:
		_empty_click_cd = 0.35
		Sfx.play(&"empty", -6.0)


func _attack(state: WeaponState) -> void:
	var data := state.data
	var origin := global_position
	var forward := -global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var hits: Dictionary = {}
	if data.melee_radius > 0.0:
		var center := origin + forward * (data.max_range - data.melee_radius)
		for hurtbox in Hitscan.sphere_hurtboxes(space, center, data.melee_radius):
			if hurtbox.receiver != null and hurtbox.receiver != user:
				_accumulate(hits, hurtbox, data, hurtbox.global_position, -forward, forward)
				break
		if not hits.is_empty():
			Sfx.play(&"punch_hit")
	else:
		var muzzle := _muzzle_position(data.id, origin)
		for i in data.pellets:
			var dir := Hitscan.spread_direction(forward, data.spread_deg, _rng)
			var hit := Hitscan.ray(space, origin, origin + dir * data.max_range)
			var end: Vector3 = hit.get("position", origin + dir * data.max_range)
			_trail(data, muzzle, end)
			if hit.is_empty():
				continue
			var hurtbox: Hurtbox = hit["hurtbox"]
			if hurtbox != null:
				_accumulate(hits, hurtbox, data, hit["position"], hit["normal"], dir)
			else:
				Fx.impact(hit["position"], hit["normal"], -1, 0.6)
				if data.damage_kind == DamageInfo.Kind.BALLISTIC:
					Fx.bullet_hole(hit["position"], hit["normal"])
		if data.damage_kind == DamageInfo.Kind.BALLISTIC:
			Fx.flash(muzzle, Color(1.0, 0.8, 0.5), 3.0, 7.0, 0.06)
	for receiver in hits:
		receiver.take_damage(hits[receiver])
	Sfx.play(data.sound)
	Events.shake_requested.emit(data.shake)
	Events.weapon_fired.emit(data.id)


func _accumulate(hits: Dictionary, hurtbox: Hurtbox, data: WeaponData, point: Vector3, normal: Vector3, dir: Vector3) -> void:
	var receiver := hurtbox.receiver
	if receiver == null or receiver == user or not receiver.has_method(&"take_damage"):
		return
	var info: DamageInfo = hits.get(receiver)
	if info == null:
		info = DamageInfo.make(0.0, data.damage_kind, user)
		info.position = point
		info.normal = normal
		info.direction = dir
		info.stun_time = data.stun_time
		info.can_finish = data.can_finish
		hits[receiver] = info
	info.amount += data.damage * (data.weak_point_multiplier if hurtbox.weak_point else 1.0)
	info.knockback += data.knockback
	info.weak_point = info.weak_point or hurtbox.weak_point


func _trail(data: WeaponData, from: Vector3, to: Vector3) -> void:
	if data.damage_kind == DamageInfo.Kind.ELECTRIC:
		Fx.arc(from, to)
	else:
		Fx.tracer(from, to)


func _muzzle_position(id: StringName, fallback: Vector3) -> Vector3:
	var view: Node3D = _views.get(id)
	if view == null:
		return fallback
	var muzzle := view.get_node_or_null(^"Muzzle") as Node3D
	return muzzle.global_position if muzzle != null else fallback


func _animate_punch() -> void:
	_fist_view.visible = true
	_fist_view.position = FIST_REST
	var tween := create_tween()
	tween.tween_property(_fist_view, "position", FIST_HIT, 0.07)
	tween.tween_property(_fist_view, "position", FIST_REST, 0.16)
	tween.tween_callback(func() -> void: _fist_view.visible = false)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `68 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/weapons/viewmodels.gd src/weapons/weapon_holder.gd tests/integration/test_weapon_holder.gd
git commit -m "Add weapon holder with hitscan, melee, reload and viewmodels" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 12: Strażnik — `ShakeCamera` i `Player`

Charakter ruchu to „strażnik, nie komandos”:

| Parametr | Wartość |
|---|---|
| chód | 5,5 m/s |
| sprint | 8,5 m/s, kosztuje wytrzymałość |
| unik | 15 m/s przez 0,16 s, koszt 30 wytrzymałości, odstęp 0,45 s |
| skok | 5 m/s przy grawitacji 15, czyli ok. 0,8 m w górę |
| tolerancje skoku | coyote time i bufor po 0,12 s |

Kamera to osobny węzeł `head` z `top_level = true` i wyłączoną interpolacją. W każdej klatce ustawia się na **interpolowanej** pozycji ciała, a obrót myszą (odchylenie i pochylenie) trafia bezpośrednio do niej. Ruch jest wygładzony interpolacją fizyki, a celowanie nie ma opóźnienia. Kierunek ruchu wynika z obrotu głowy, a ciało gracza się nie obraca.

Śmierć: kamera opada na ziemię i broń się wyłącza. `Events.player_died` informuje o tym tryb gry, a ten wskrzesza strażnika metodą `respawn()`. Dobicie ogłuszonego eksponatu przez tego gracza leczy o 15.

**Pliki:**
- Utwórz: `src/player/shake_camera.gd`, `src/player/player.gd`
- Test: `tests/integration/test_player.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_player.gd`**
```gdscript
extends TestCase

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


func test_lands_on_the_floor() -> void:
	await physics_frames(10)
	assert_true(player.is_on_floor())


func test_walks_forward_with_input() -> void:
	await physics_frames(5)
	Input.action_press(&"move_forward")
	await physics_frames(30)
	Input.action_release(&"move_forward")
	assert_lt(player.global_position.z, -1.5)


func test_sprint_is_faster_and_spends_stamina() -> void:
	await physics_frames(5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await physics_frames(30)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	assert_lt(player.global_position.z, -2.5)
	assert_lt(player.stamina.current, 100.0)


func test_dash_moves_quickly_and_costs_stamina() -> void:
	await physics_frames(5)
	assert_true(player.dash(Vector3.FORWARD))
	assert_eq(player.stamina.current, 70.0)
	assert_false(player.dash(Vector3.FORWARD), "cooldown")
	await physics_frames(12)
	assert_lt(player.global_position.z, -1.5)


func test_damage_then_death_then_respawn() -> void:
	var damaged := watch(Events.player_damaged)
	var died := watch(Events.player_died)
	player.take_damage(DamageInfo.make(30.0, DamageInfo.Kind.BLUNT))
	assert_eq(player.health.current, 70.0)
	assert_eq(damaged.size(), 1)
	player.take_damage(DamageInfo.make(100.0, DamageInfo.Kind.BLUNT))
	assert_false(player.alive)
	assert_false(player.weapons.enabled)
	assert_eq(died.size(), 1)
	player.take_damage(DamageInfo.make(10.0, DamageInfo.Kind.BLUNT))
	assert_eq(damaged.size(), 2, "the dead take no more hits")
	player.respawn(Vector3(3, 0.05, 3))
	assert_true(player.alive)
	assert_eq(player.health.current, 100.0)
	assert_true(player.weapons.enabled)


func test_only_own_finishers_heal() -> void:
	player.health.apply_damage(40.0)
	var own := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, player)
	Events.enemy_destroyed.emit(null, own, false)
	assert_eq(player.health.current, 60.0)
	Events.enemy_destroyed.emit(null, own, true)
	assert_eq(player.health.current, 75.0)
	var other := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, null)
	Events.enemy_destroyed.emit(null, other, true)
	assert_eq(player.health.current, 75.0)


func test_camera_listens_to_shake_requests() -> void:
	Events.shake_requested.emit(0.5)
	assert_almost_eq(player.camera.trauma.value, 0.5)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=player`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/player/shake_camera.gd`**
```gdscript
class_name ShakeCamera
extends Camera3D
## First-person camera: trauma-based shake (see Trauma) driven by
## Events.shake_requested, plus short FOV kicks (dash).

@export var base_fov: float = 70.0
@export var max_offset: float = 0.06
@export var max_roll_deg: float = 2.0

var trauma := Trauma.new()
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _fov_kick: float = 0.0


func _ready() -> void:
	fov = base_fov
	near = 0.05
	_noise.frequency = 18.0
	Events.shake_requested.connect(add_trauma)


func add_trauma(amount: float) -> void:
	trauma.add(amount)


func kick_fov(degrees: float) -> void:
	_fov_kick = maxf(_fov_kick, degrees)


func _process(delta: float) -> void:
	_time += delta
	trauma.tick(delta)
	var strength := trauma.strength()
	h_offset = max_offset * strength * _noise.get_noise_2d(_time, 0.0)
	v_offset = max_offset * strength * _noise.get_noise_2d(0.0, _time)
	rotation.z = deg_to_rad(max_roll_deg) * strength * _noise.get_noise_2d(_time, 50.0)
	_fov_kick = move_toward(_fov_kick, 0.0, 40.0 * delta)
	fov = base_fov + _fov_kick
```

**Plik: `src/player/player.gd`**
```gdscript
class_name Player
extends CharacterBody3D
## The night guard: calm walk, stamina-limited sprint and dash, jump with
## coyote time, mouse look, flashlight, health and the weapon holder.
## The head is a top-level node that follows the interpolated body, so
## mouse look stays instant while movement is smoothed by physics
## interpolation. Movement direction comes from the head's yaw.

## Set false before the player enters the tree to leave the OS cursor free
## (automated scenarios).
static var capture_mouse: bool = true

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var ground_accel: float = 60.0
@export var air_accel: float = 14.0
@export var jump_velocity: float = 5.0
@export var gravity: float = 15.0
@export var dash_speed: float = 15.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.45
@export var mouse_sensitivity: float = 0.0022
@export var eye_height: float = 1.6
@export var finisher_heal: float = 15.0

var health: Health
var stamina := Stamina.new()
var head: Node3D
var camera: ShakeCamera
var weapons: WeaponHolder
var flashlight: SpotLight3D
var alive: bool = true
var sprinting: bool = false

var _eye: float = 1.6
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir := Vector3.ZERO
var _coyote: float = 0.0
var _jump_buffer: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	health = Health.new()
	add_child(health)
	health.depleted.connect(_on_depleted)
	_eye = eye_height
	head = Node3D.new()
	head.top_level = true
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(head)
	head.global_position = global_position + Vector3.UP * _eye
	camera = ShakeCamera.new()
	head.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.15, -0.1, 0.0)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 24.0
	flashlight.light_energy = 3.0
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	weapons = WeaponHolder.new()
	weapons.user = self
	camera.add_child(weapons)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	if capture_mouse and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotation.y -= motion.relative.x * mouse_sensitivity
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
	elif event.is_action_pressed(&"release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"flashlight"):
		flashlight.visible = not flashlight.visible


func _process(_delta: float) -> void:
	head.global_position = get_global_transform_interpolated().origin + Vector3.UP * _eye


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	if not alive:
		var still := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, ground_accel * delta)
		velocity.x = still.x
		velocity.z = still.z
		move_and_slide()
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish := Basis(Vector3.UP, head.rotation.y) * Vector3(input.x, 0.0, input.y)
	sprinting = Input.is_action_pressed(&"sprint") and input.length() > 0.1 and stamina.spend_sprint(delta)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	if Input.is_action_just_pressed(&"dash"):
		dash(wish)
	_update_jump(delta, on_floor)
	if _dash_left > 0.0:
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
	else:
		var target := wish * (sprint_speed if sprinting else walk_speed)
		var accel := ground_accel if on_floor else air_accel
		var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	stamina.tick(delta)
	move_and_slide()


## Dashes along [param direction] (or where the guard looks). Returns false
## while on cooldown, out of stamina or dead.
func dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if not alive or _dash_cd > 0.0 or not stamina.try_dash():
		return false
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.1:
		flat = Basis(Vector3.UP, head.rotation.y) * Vector3.FORWARD
	_dash_dir = flat.normalized()
	_dash_left = dash_time
	_dash_cd = dash_cooldown
	camera.kick_fov(8.0)
	Sfx.play(&"dash", -4.0)
	return true


func take_damage(info: DamageInfo) -> void:
	if not alive:
		return
	Events.player_damaged.emit(info.amount, info.position)
	camera.add_trauma(0.25 + info.amount / 60.0)
	var push := Vector3(info.direction.x, 0.0, info.direction.z)
	if info.knockback > 0.0 and push.length() > 0.01:
		velocity += push.normalized() * info.knockback
	Sfx.play(&"hurt")
	health.apply_damage(info.amount)


func heal(amount: float) -> float:
	return health.heal(amount)


func respawn(at: Vector3, yaw: float = 0.0) -> void:
	global_position = at
	velocity = Vector3.ZERO
	head.rotation = Vector3(0.0, yaw, 0.0)
	_eye = eye_height
	health.reset()
	stamina.current = stamina.maximum
	stamina.exhausted = false
	alive = true
	weapons.enabled = true
	reset_physics_interpolation()


func _update_jump(delta: float, on_floor: bool) -> void:
	_coyote = 0.12 if on_floor else maxf(_coyote - delta, 0.0)
	_jump_buffer = 0.12 if Input.is_action_just_pressed(&"jump") else maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0


func _on_depleted() -> void:
	alive = false
	weapons.enabled = false
	create_tween().tween_property(self, "_eye", 0.4, 0.5)
	Events.player_died.emit()


func _on_enemy_destroyed(_enemy: Node, info: DamageInfo, finisher: bool) -> void:
	if finisher and info != null and info.source == self:
		heal(finisher_heal)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `75 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/player tests/integration/test_player.gd
git commit -m "Add the guard: movement, dash, jump, camera shake, health" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Zadanie 13: Mózg wroga — maszyna stanów

Stany według specu: uśpiony → czujny → pościg → atak → (odzysk) → pościg. Ogłuszenie przerywa każdy stan, a zniszczenie jest końcowe. Atak jest **zapowiedziany**: przez czas zamachu (`windup`) wróg stoi i się odchyla, dopiero potem następuje cios (`strike`). Kto w tym czasie odskoczy, ten uniknie trafienia. Klasa to czysta logika. Węzeł `Enemy` podaje jej co klatkę, czy widzi cel i jak daleko ten jest.

**Pliki:**
- Utwórz: `src/enemies/enemy_brain.gd`
- Test: `tests/unit/test_enemy_brain.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/unit/test_enemy_brain.gd`**
```gdscript
extends TestCase

var brain: EnemyBrain


func before_each() -> void:
	brain = EnemyBrain.new()
	brain.reaction_time = 0.5
	brain.attack_range = 2.0
	brain.windup = 0.6
	brain.recovery = 0.7


func test_stays_dormant_until_it_sees_the_target() -> void:
	brain.update(1.0, false, 3.0)
	assert_eq(brain.state, EnemyBrain.State.DORMANT)
	brain.update(0.1, true, 10.0)
	assert_eq(brain.state, EnemyBrain.State.ALERT)


func test_alert_turns_into_chase_after_reaction_time() -> void:
	brain.wake()
	brain.update(0.3, true, 10.0)
	assert_eq(brain.state, EnemyBrain.State.ALERT)
	brain.update(0.3, true, 10.0)
	assert_eq(brain.state, EnemyBrain.State.CHASE)


func test_chase_attacks_only_in_range() -> void:
	_to_chase()
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.CHASE)
	brain.update(0.1, true, 1.5)
	assert_eq(brain.state, EnemyBrain.State.ATTACK)


func test_strike_fires_once_after_windup_then_recovers_to_chase() -> void:
	var strikes := watch(brain.strike)
	_to_attack()
	brain.update(0.5, true, 1.0)
	assert_eq(strikes.size(), 0)
	assert_almost_eq(brain.windup_progress(), 0.5 / 0.6, 0.01)
	brain.update(0.2, true, 1.0)
	assert_eq(strikes.size(), 1)
	assert_true(brain.has_struck())
	brain.update(0.5, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.ATTACK)
	brain.update(0.3, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.CHASE)
	assert_eq(strikes.size(), 1)


func test_stun_interrupts_windup_and_ends_in_chase() -> void:
	var strikes := watch(brain.strike)
	_to_attack()
	brain.update(0.4, true, 1.0)
	brain.stun(2.0)
	assert_true(brain.is_stunned())
	brain.update(1.0, true, 1.0)
	assert_true(brain.is_stunned())
	brain.update(1.1, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.CHASE)
	assert_eq(strikes.size(), 0)


func test_restun_keeps_the_longer_time() -> void:
	brain.stun(3.0)
	brain.update(1.0, false, 5.0)
	brain.stun(0.5)
	brain.update(1.5, false, 5.0)
	assert_true(brain.is_stunned())


func test_destroyed_is_final() -> void:
	brain.destroy()
	brain.wake()
	brain.stun(2.0)
	brain.update(1.0, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.DESTROYED)


func test_state_changes_are_signalled() -> void:
	var changes := watch(brain.state_changed)
	brain.wake()
	assert_eq(changes.size(), 1)
	assert_eq(changes[0][0], EnemyBrain.State.DORMANT)
	assert_eq(changes[0][1], EnemyBrain.State.ALERT)


func _to_chase() -> void:
	brain.wake()
	brain.update(1.0, true, 10.0)


func _to_attack() -> void:
	_to_chase()
	brain.update(0.01, true, 1.0)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=enemy_brain`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/enemies/enemy_brain.gd`**
```gdscript
class_name EnemyBrain
extends RefCounted
## Exhibit state machine (pure logic). The Enemy node feeds it perception
## every physics frame and reacts to its signals and state:
## DORMANT -> ALERT -> CHASE -> ATTACK (windup, strike, recovery) -> CHASE.
## STUNNED interrupts anything; DESTROYED is final.

signal state_changed(from: State, to: State)
## The damage moment of an attack (end of the windup).
signal strike

enum State { DORMANT, ALERT, CHASE, ATTACK, STUNNED, DESTROYED }

var state: State = State.DORMANT
var reaction_time: float = 0.5
var attack_range: float = 1.6
var windup: float = 0.6
var recovery: float = 0.7
var _timer: float = 0.0
var _struck: bool = false


func wake() -> void:
	if state == State.DORMANT:
		_enter(State.ALERT)


func stun(duration: float) -> void:
	if state == State.DESTROYED or duration <= 0.0:
		return
	if state == State.STUNNED:
		_timer = maxf(_timer, duration)
		return
	_enter(State.STUNNED)
	_timer = duration


func destroy() -> void:
	if state != State.DESTROYED:
		_enter(State.DESTROYED)


func is_stunned() -> bool:
	return state == State.STUNNED


func has_struck() -> bool:
	return state == State.ATTACK and _struck


## 0..1 while winding up an attack (drives the telegraph), else 0.
func windup_progress() -> float:
	if state != State.ATTACK or _struck or windup <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / windup, 0.0, 1.0)


func update(delta: float, sees_target: bool, distance: float) -> void:
	match state:
		State.DORMANT:
			if sees_target:
				wake()
		State.ALERT:
			_timer -= delta
			if _timer <= 0.0:
				_enter(State.CHASE)
		State.CHASE:
			if distance <= attack_range:
				_enter(State.ATTACK)
		State.ATTACK:
			_timer -= delta
			if not _struck and _timer <= 0.0:
				_struck = true
				_timer = recovery
				strike.emit()
			elif _struck and _timer <= 0.0:
				_enter(State.CHASE)
		State.STUNNED:
			_timer -= delta
			if _timer <= 0.0:
				_enter(State.CHASE)


func _enter(next: State) -> void:
	var previous := state
	state = next
	_struck = false
	match next:
		State.ALERT:
			_timer = reaction_time
		State.ATTACK:
			_timer = windup
		_:
			_timer = 0.0
	state_changed.emit(previous, next)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `83 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/enemies/enemy_brain.gd tests/unit/test_enemy_brain.gd
git commit -m "Add enemy state machine with telegraphed attacks and stun" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 14: Baza eksponatu i figura woskowa

`Enemy` to baza wszystkich eksponatów. Zajmuje się:

- **percepcją**: promień widzenia co 0,2 s,
- **pościgiem**: `NavigationAgent3D`, a gdy mapy nawigacji nie ma (testy), prosto do celu,
- **zapowiedzią ataku**: odchylenie i żarzenie się materiału,
- **ciosem**: trafia tylko, jeśli cel jest nadal w zasięgu i przed wrogiem,
- **ogłuszeniem**: wirujący pierścień nad głową,
- **odrzutem**: słabnie na ziemi,
- **obrażeniami**: dobicie pięścią ogłuszonego eksponatu zabija go od razu i zawsze go rozrywa,
- **efektami zależnymi od materiału**.

Kiedy eksponat się budzi, budzi też sąsiadów w promieniu 8 m, bo figury chodzą grupkami.

Figura woskowa ma 60 HP, porusza się z prędkością 2,4 m/s, zadaje 12 obrażeń i topnieje pod ostrzałem: przy spadku zdrowia siada i się rozlewa.

**Pliki:**
- Utwórz: `src/enemies/enemy.gd`, `src/enemies/wax_figure.gd`
- Test: `tests/integration/test_wax_figure.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_wax_figure.gd`**
```gdscript
extends TestCase

var target: TargetDummy
var wax: WaxFigure


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -8)
	add_child(target)
	wax = WaxFigure.new()
	wax.target = target
	add_child(wax)


func _hit(amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, target)
	info.direction = Vector3(0, 0, 1)
	info.position = wax.global_position + Vector3.UP
	return info


func test_three_pistol_shots_destroy_it() -> void:
	var destroyed := watch(Events.enemy_destroyed)
	for i in 3:
		wax.take_damage(_hit(20.0))
	assert_eq(destroyed.size(), 1)
	if destroyed.size() == 1:
		assert_false(destroyed[0][2], "not a finisher")
	assert_true(wax.is_queued_for_deletion())


func test_hits_wake_it_up_and_melt_it() -> void:
	wax.take_damage(_hit(30.0))
	assert_eq(wax.brain.state, EnemyBrain.State.ALERT)
	assert_lt(wax.visual.scale.y, 1.0)


func test_taser_stuns() -> void:
	var zap := _hit(4.0, DamageInfo.Kind.ELECTRIC)
	zap.stun_time = 3.0
	wax.take_damage(zap)
	assert_true(wax.brain.is_stunned())


func test_fist_on_a_stunned_figure_is_a_finisher_that_heals_the_guard() -> void:
	var guard := Player.new()
	guard.position = Vector3(5, 0, 5)
	add_child(guard)
	guard.health.apply_damage(40.0)
	var destroyed := watch(Events.enemy_destroyed)
	var zap := _hit(4.0, DamageInfo.Kind.ELECTRIC)
	zap.stun_time = 3.0
	wax.take_damage(zap)
	var punch := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, guard)
	punch.can_finish = true
	wax.take_damage(punch)
	assert_eq(destroyed.size(), 1)
	if destroyed.size() == 1:
		assert_true(destroyed[0][2], "finisher")
	assert_eq(guard.health.current, 75.0)


func test_awake_figure_walks_toward_the_target() -> void:
	await physics_frames(2)
	var start := wax.global_position.distance_to(target.global_position)
	wax.brain.wake()
	await physics_frames(90)
	assert_lt(wax.global_position.distance_to(target.global_position), start - 1.0)


func test_strike_hurts_a_target_in_reach() -> void:
	target.position = Vector3(0, 0, -1.4)
	await physics_frames(2)
	wax.brain.wake()
	await physics_frames(90)
	assert_gt(target.hits.size(), 0)
	if target.hits.size() > 0:
		assert_eq(target.hits[0].amount, 12.0)


func test_stepping_back_during_the_windup_avoids_the_strike() -> void:
	target.position = Vector3(0, 0, -1.4)
	await physics_frames(2)
	wax.brain.wake()
	for i in 120:
		if wax.brain.state == EnemyBrain.State.ATTACK:
			break
		await get_tree().physics_frame
	assert_eq(wax.brain.state, EnemyBrain.State.ATTACK)
	target.position = Vector3(0, 0, -6)
	await physics_frames(50)
	assert_eq(target.hits.size(), 0)


func test_waking_one_wakes_its_group_but_not_distant_ones() -> void:
	var near := WaxFigure.new()
	near.position = Vector3(2, 0, 0)
	near.target = target
	add_child(near)
	var far := WaxFigure.new()
	far.position = Vector3(20, 0, 0)
	far.target = target
	add_child(far)
	wax.brain.wake()
	assert_ne(near.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(far.brain.state, EnemyBrain.State.DORMANT)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=wax`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/enemies/enemy.gd`**
```gdscript
class_name Enemy
extends CharacterBody3D
## Base class for awakened exhibits. Subclasses set their numbers in
## _configure() and build collider, meshes and hurtboxes in _build_body().
## The base handles perception, chasing, telegraphed melee strikes, stun,
## blocking, knockback, damage, material effects and destruction.

const GRAVITY := 15.0
## How fast knockback and leaps die down on the ground (m/s per second).
const GROUND_FRICTION := 30.0

@export var max_health: float = 60.0
@export var move_speed: float = 2.5
## Radians per second.
@export var turn_speed: float = 8.0
@export var sight_range: float = 25.0
@export var eye_height: float = 1.5
@export var attack_damage: float = 10.0
@export var attack_reach: float = 1.9
## 0 = full knockback, 1 = immovable.
@export var knockback_resist: float = 0.0
@export var wake_radius: float = 8.0
@export var marker_height: float = 2.0
@export var material_kind: ExhibitMaterial.Kind = ExhibitMaterial.Kind.WAX
@export var notice_sound: StringName = &"notice"

var brain := EnemyBrain.new()
var health: Health
## Who this exhibit hunts. Defaults to the node in group "player".
var target: Node3D = null
## Parent of all body meshes; leans during attacks.
var visual: Node3D
var nav: NavigationAgent3D

var _external := Vector3.ZERO
var _sees_target := false
var _sight_timer: float = 0.0
var _repath_timer: float = 0.0
var _stun_marker: MeshInstance3D
var _flash_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMY
	_configure()
	health = Health.new()
	health.max_health = max_health
	add_child(health)
	nav = NavigationAgent3D.new()
	nav.radius = 0.5
	nav.path_desired_distance = 0.7
	nav.target_desired_distance = 0.8
	add_child(nav)
	visual = Node3D.new()
	add_child(visual)
	_build_body()
	_stun_marker = _make_stun_marker()
	add_child(_stun_marker)
	brain.strike.connect(_on_strike)
	brain.state_changed.connect(_on_state_changed)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D


## Subclass hook: set stats and brain timings (brain.attack_range etc.).
func _configure() -> void:
	pass


## Subclass hook: add a collider, meshes (under [member visual]) and hurtboxes.
func _build_body() -> void:
	pass


## Subclass hook: extra reaction to a hit that got through.
func _on_damaged(_info: DamageInfo) -> void:
	pass


## Subclass hook: true when this hit is stopped (e.g. by a shield).
func _blocks(_info: DamageInfo) -> bool:
	return false


func take_damage(info: DamageInfo) -> void:
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	if _blocks(info):
		info.blocked = true
		Fx.impact(info.position, -info.direction, ExhibitMaterial.Kind.METAL, 1.5)
		Sfx.play_at(&"block", info.position)
		brain.wake()
		Events.hit_landed.emit(self, info, false)
		return
	var finisher := info.can_finish and brain.is_stunned()
	var amount := health.current if finisher else info.amount
	var overkill := maxf(amount - health.current, 0.0)
	health.apply_damage(amount)
	_external += _push(info)
	Fx.impact(info.position, info.normal, material_kind, clampf(info.amount / 15.0, 0.5, 3.0))
	Sfx.play_at(ExhibitMaterial.hit_sound(material_kind), info.position)
	_on_damaged(info)
	if health.is_dead():
		_destroy(info, finisher, overkill)
		return
	if info.stun_time > 0.0:
		brain.stun(info.stun_time)
	else:
		brain.wake()
	Events.hit_landed.emit(self, info, false)


## Instantly turns to face a point (used when spawning).
func face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		rotation.y = atan2(-to.x, -to.z)


func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	var has_target := is_instance_valid(target)
	var distance := INF
	if has_target:
		distance = global_position.distance_to(target.global_position)
		_sight_timer -= delta
		if _sight_timer <= 0.0:
			_sight_timer = 0.2
			_sees_target = distance <= sight_range and _has_line_of_sight()
	brain.update(delta, _sees_target, distance)
	var move := Vector3.ZERO
	if has_target:
		match brain.state:
			EnemyBrain.State.CHASE:
				move = _chase_direction(delta) * move_speed
				_face_towards(target.global_position, delta)
			EnemyBrain.State.ALERT:
				_face_towards(target.global_position, delta)
			EnemyBrain.State.ATTACK:
				if not brain.has_struck():
					_face_towards(target.global_position, delta * 0.5)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	velocity.x = move.x + _external.x
	velocity.z = move.z + _external.z
	var friction := GROUND_FRICTION if is_on_floor() else 1.0
	_external = _external.move_toward(Vector3.ZERO, friction * delta)
	move_and_slide()
	_update_visuals(delta)


func _update_visuals(delta: float) -> void:
	var lean := 0.0
	if brain.state == EnemyBrain.State.ATTACK:
		lean = -0.45 if brain.has_struck() else 0.35 * brain.windup_progress()
	visual.rotation.x = lerpf(visual.rotation.x, lean, 1.0 - exp(-14.0 * delta))
	var glow := brain.windup_progress()
	for material in _flash_materials:
		material.emission_energy_multiplier = glow * glow * 2.5
	if _stun_marker.visible:
		_stun_marker.rotate_y(6.0 * delta)


func _on_strike() -> void:
	if not is_instance_valid(target):
		return
	Sfx.play_at(&"swing", global_position)
	var to := target.global_position - global_position
	to.y = 0.0
	var facing := -global_transform.basis.z
	if to.length() <= attack_reach and facing.dot(to.normalized()) > 0.3:
		_deal_damage()


## Hits the target with this exhibit's attack (no range checks).
func _deal_damage() -> void:
	if not is_instance_valid(target) or not target.has_method(&"take_damage"):
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
	info.direction = to.normalized() if to.length() > 0.01 else -global_transform.basis.z
	info.knockback = 5.0
	info.position = global_position + Vector3.UP * eye_height
	target.take_damage(info)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	_stun_marker.visible = to == EnemyBrain.State.STUNNED
	if from == EnemyBrain.State.DORMANT and to != EnemyBrain.State.DESTROYED:
		Sfx.play_at(notice_sound, global_position, -4.0)
		_wake_neighbours()


func _wake_neighbours() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other != null and other != self and other.global_position.distance_to(global_position) <= wake_radius:
			other.brain.wake()


func _destroy(info: DamageInfo, finisher: bool, overkill: float) -> void:
	brain.destroy()
	var plan := GibPlanner.plan(material_kind, overkill, max_health, finisher)
	var center := global_position + Vector3.UP * (eye_height * 0.6)
	Fx.shatter(center, material_kind, plan, info.direction)
	Sfx.play_at(ExhibitMaterial.break_sound(material_kind), center)
	if plan.gibbed:
		Fx.hitstop(0.06)
		Events.shake_requested.emit(0.25)
	Events.hit_landed.emit(self, info, true)
	Events.enemy_destroyed.emit(self, info, finisher)
	queue_free()


func _push(info: DamageInfo) -> Vector3:
	var flat := Vector3(info.direction.x, 0.0, info.direction.z)
	if info.knockback <= 0.0 or flat.length_squared() < 0.0001:
		return Vector3.ZERO
	return flat.normalized() * info.knockback * (1.0 - knockback_resist)


func _has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP * eye_height
	var to := target.global_position + Vector3.UP * 1.4
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _chase_direction(delta: float) -> Vector3:
	var goal := target.global_position
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0:
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = 0.25
			nav.target_position = goal
		if not nav.is_navigation_finished():
			var step := nav.get_next_path_position() - global_position
			step.y = 0.0
			if step.length() > 0.05:
				return step.normalized()
	var straight := goal - global_position
	straight.y = 0.0
	return straight.normalized() if straight.length() > 0.05 else Vector3.ZERO


func _face_towards(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.0001:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), turn_speed * delta)


# --- body-building helpers for subclasses ---

## Per-instance material; all of them glow while an attack winds up.
func body_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.3)
	mat.emission_energy_multiplier = 0.0
	_flash_materials.append(mat)
	return mat


func add_part(mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot_deg
	part.material_override = mat
	visual.add_child(part)
	return part


## Upright capsule collider standing on the origin.
func add_collider(radius: float, height: float) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = capsule_shape(radius, height)
	collider.position.y = height * 0.5
	add_child(collider)


func add_hurtbox(shape: Shape3D, pos: Vector3, weak: bool = false) -> Hurtbox:
	var hurtbox := Hurtbox.make(self, shape, pos, weak)
	add_child(hurtbox)
	return hurtbox


static func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func sphere_shape(radius: float) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return shape


static func capsule_shape(radius: float, height: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape


func _make_stun_marker() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 1.6, 2.2)
	var marker := MeshInstance3D.new()
	marker.mesh = torus
	marker.material_override = mat
	marker.position.y = marker_height
	marker.visible = false
	return marker
```

**Plik: `src/enemies/wax_figure.gd`**
```gdscript
class_name WaxFigure
extends Enemy
## Slow wax figure in a period costume. Walks in groups, hits in melee and
## melts under fire (it sags as it loses health).


func _configure() -> void:
	max_health = 60.0
	move_speed = 2.4
	attack_damage = 12.0
	attack_reach = 1.9
	eye_height = 1.5
	marker_height = 2.0
	material_kind = ExhibitMaterial.Kind.WAX
	brain.reaction_time = 0.6
	brain.attack_range = 1.6
	brain.windup = 0.55
	brain.recovery = 0.7


func _build_body() -> void:
	add_collider(0.35, 1.75)
	var costume := body_material(Color(0.35, 0.18, 0.2))
	var wax := body_material(Color(0.93, 0.82, 0.62))
	var torso := CapsuleMesh.new()
	torso.radius = 0.28
	torso.height = 1.25
	add_part(torso, Vector3(0, 0.72, 0), costume)
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	add_part(head, Vector3(0, 1.55, 0), wax)
	for side in [-1.0, 1.0]:
		add_part(box_mesh(Vector3(0.12, 0.6, 0.12)), Vector3(0.36 * side, 1.0, -0.05), wax)
	add_hurtbox(capsule_shape(0.34, 1.3), Vector3(0, 0.72, 0))
	add_hurtbox(sphere_shape(0.22), Vector3(0, 1.55, 0), true)


func _on_damaged(_info: DamageInfo) -> void:
	var left := health.fraction()
	var spread := 1.0 + (1.0 - left) * 0.1
	visual.scale = Vector3(spread, lerpf(0.8, 1.0, left), spread)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `91 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/enemies/enemy.gd src/enemies/wax_figure.gd tests/integration/test_wax_figure.gd
git commit -m "Add exhibit base class and the wax figure" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 15: Wypchany wilk i rycerz w zbroi

**Wilk** jest szybki (6,5 m/s) i kruchy (35 HP). Z odległości do 6 m przykuca (zapowiedź), a potem skacze łukiem wyliczonym tak, żeby wylądować przy celu. W locie gryzie, a po lądowaniu hamuje i przez 0,9 s jest bezbronny. Sypie trocinami.

**Rycerz** jest twardy (180 HP), powolny i obraca się wolno (2,2 rad/s), więc da się go obejść. Tarcza blokuje trafienia z przedniego łuku ±70°. Prąd paralizatora przechodzi przez metal i ogłusza, a wtedy tarcza opada. Zbroja tłumi 70% odrzutu i przy mocniejszych trafieniach gubi blachy.

**Pliki:**
- Utwórz: `src/enemies/shield_guard.gd`, `src/enemies/wolf.gd`, `src/enemies/knight.gd`
- Test: `tests/unit/test_shield_guard.gd`, `tests/integration/test_wolf.gd`, `tests/integration/test_knight.gd`

- [ ] **Krok 1: Testy**

**Plik: `tests/unit/test_shield_guard.gd`**
```gdscript
extends TestCase

## The knight looks toward -Z. An attacker in front shoots toward +Z.
const FACING := Vector3(0, 0, -1)
const FROM_FRONT := Vector3(0, 0, 1)


func test_blocks_a_hit_from_the_front() -> void:
	assert_true(ShieldGuard.blocks(FACING, FROM_FRONT, DamageInfo.Kind.BALLISTIC, false))


func test_hit_from_behind_gets_through() -> void:
	assert_false(ShieldGuard.blocks(FACING, Vector3(0, 0, -1), DamageInfo.Kind.BALLISTIC, false))


func test_hit_from_the_side_gets_through() -> void:
	assert_false(ShieldGuard.blocks(FACING, Vector3(1, 0, 0), DamageInfo.Kind.BALLISTIC, false))


func test_front_arc_is_seventy_degrees_each_way() -> void:
	var inside := FROM_FRONT.rotated(Vector3.UP, deg_to_rad(60.0))
	var outside := FROM_FRONT.rotated(Vector3.UP, deg_to_rad(80.0))
	assert_true(ShieldGuard.blocks(FACING, inside, DamageInfo.Kind.BLUNT, false))
	assert_false(ShieldGuard.blocks(FACING, outside, DamageInfo.Kind.BLUNT, false))


func test_electricity_passes_through_the_shield() -> void:
	assert_false(ShieldGuard.blocks(FACING, FROM_FRONT, DamageInfo.Kind.ELECTRIC, false))


func test_a_stunned_knight_cannot_block() -> void:
	assert_false(ShieldGuard.blocks(FACING, FROM_FRONT, DamageInfo.Kind.BALLISTIC, true))
```

**Plik: `tests/integration/test_wolf.gd`**
```gdscript
extends TestCase

var target: TargetDummy
var wolf: Wolf


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -5)
	add_child(target)
	wolf = Wolf.new()
	wolf.target = target
	add_child(wolf)


func test_pounce_covers_the_distance_and_bites() -> void:
	await physics_frames(2)
	wolf.brain.wake()
	await physics_frames(90)
	assert_lt(wolf.global_position.distance_to(target.global_position), 2.0)
	assert_gt(target.hits.size(), 0)


func test_two_pistol_shots_kill_a_wolf() -> void:
	var destroyed := watch(Events.enemy_destroyed)
	for i in 2:
		wolf.take_damage(DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target))
	assert_eq(destroyed.size(), 1)
```

**Plik: `tests/integration/test_knight.gd`**
```gdscript
extends TestCase

var knight: Knight


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	knight = Knight.new()
	add_child(knight)


## A 20-damage hit travelling along [param travel].
func _shot(kind: DamageInfo.Kind, travel: Vector3) -> DamageInfo:
	var info := DamageInfo.make(20.0, kind, null)
	info.direction = travel
	info.position = knight.global_position + Vector3.UP
	if kind == DamageInfo.Kind.ELECTRIC:
		info.stun_time = 3.0
	return info


func test_frontal_shot_is_blocked() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, 1))
	knight.take_damage(info)
	assert_true(info.blocked)
	assert_eq(knight.health.current, 180.0)


func test_shot_from_behind_lands() -> void:
	knight.take_damage(_shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, -1)))
	assert_eq(knight.health.current, 160.0)


func test_taser_from_the_front_stuns_and_opens_the_guard() -> void:
	knight.take_damage(_shot(DamageInfo.Kind.ELECTRIC, Vector3(0, 0, 1)))
	assert_true(knight.brain.is_stunned())
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, 1))
	knight.take_damage(info)
	assert_false(info.blocked)
	assert_eq(knight.health.current, 140.0)


func test_heavy_armour_resists_knockback() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, -1))
	info.knockback = 10.0
	knight.take_damage(info)
	assert_almost_eq(knight._external.length(), 3.0, 0.01)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=shield` oraz `--filter=wolf` i `--filter=knight`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/enemies/shield_guard.gd`**
```gdscript
class_name ShieldGuard
## The knight's shield rule: blocks hits arriving from the front arc,
## except electric ones (they conduct through the metal) and while stunned.

const HALF_ARC_DEG := 70.0


## [param facing] = where the knight looks; [param hit_direction] = where
## the hit travels (attacker -> knight).
static func blocks(facing: Vector3, hit_direction: Vector3, kind: DamageInfo.Kind, stunned: bool) -> bool:
	if stunned or kind == DamageInfo.Kind.ELECTRIC:
		return false
	var look := Vector3(facing.x, 0.0, facing.z)
	var toward_attacker := Vector3(-hit_direction.x, 0.0, -hit_direction.z)
	if look.length_squared() < 0.0001 or toward_attacker.length_squared() < 0.0001:
		return false
	return look.normalized().dot(toward_attacker.normalized()) >= cos(deg_to_rad(HALF_ARC_DEG))
```

**Plik: `src/enemies/wolf.gd`**
```gdscript
class_name Wolf
extends Enemy
## Fast, fragile stuffed wolf. Crouches, then pounces from up to 6 m on an
## arc aimed to land on the target, biting mid-air. Skids to a halt on
## landing and is open to punishment while it recovers. Sheds sawdust.

@export var max_leap_speed: float = 13.0
@export var leap_lift: float = 3.5

var _leaping := false
var _leap_hit := false
var _airborne := false


func _configure() -> void:
	max_health = 35.0
	move_speed = 6.5
	turn_speed = 12.0
	attack_damage = 10.0
	attack_reach = 1.7
	eye_height = 0.8
	marker_height = 1.3
	material_kind = ExhibitMaterial.Kind.TAXIDERMY
	notice_sound = &"growl"
	brain.reaction_time = 0.35
	brain.attack_range = 6.0
	brain.windup = 0.45
	brain.recovery = 0.9


func _build_body() -> void:
	add_collider(0.35, 0.9)
	var fur := body_material(Color(0.5, 0.38, 0.25))
	var dark := body_material(Color(0.28, 0.2, 0.14))
	add_part(box_mesh(Vector3(0.38, 0.4, 0.95)), Vector3(0, 0.6, 0), fur)
	add_part(box_mesh(Vector3(0.26, 0.26, 0.34)), Vector3(0, 0.8, -0.6), fur)
	add_part(box_mesh(Vector3(0.14, 0.12, 0.2)), Vector3(0, 0.74, -0.84), dark)
	for x in [-0.13, 0.13]:
		for z in [-0.35, 0.35]:
			add_part(box_mesh(Vector3(0.09, 0.42, 0.09)), Vector3(x, 0.21, z), dark)
	add_part(box_mesh(Vector3(0.08, 0.08, 0.4)), Vector3(0, 0.7, 0.62), fur, Vector3(25.0, 0.0, 0.0))
	add_hurtbox(box_shape(Vector3(0.44, 0.48, 1.0)), Vector3(0, 0.6, 0))
	add_hurtbox(sphere_shape(0.2), Vector3(0, 0.82, -0.62), true)


func _physics_process(delta: float) -> void:
	super(delta)
	if not _leaping:
		return
	if brain.state != EnemyBrain.State.ATTACK:
		_leaping = false
		return
	if not is_on_floor():
		_airborne = true
	elif _airborne:
		_airborne = false
		_external *= 0.25
	if not _leap_hit and is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_reach:
		_leap_hit = true
		_deal_damage()


func _on_strike() -> void:
	if not is_instance_valid(target):
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() <= attack_reach:
		super()
		return
	var airtime := 2.0 * leap_lift / GRAVITY
	_external = to.normalized() * clampf(to.length() / airtime, 4.0, max_leap_speed)
	velocity.y = leap_lift
	_leaping = true
	_leap_hit = false
	_airborne = false
	Sfx.play_at(&"growl", global_position)
```

**Plik: `src/enemies/knight.gd`**
```gdscript
class_name Knight
extends Enemy
## Armoured knight. The shield blocks frontal hits (not electric ones); a
## taser stun drops the guard. Turns slowly, so flanking works. Shrugs off
## most knockback and sheds armour plates when hit hard.

var _shield: MeshInstance3D


func _configure() -> void:
	max_health = 180.0
	move_speed = 2.0
	turn_speed = 2.2
	attack_damage = 25.0
	attack_reach = 2.4
	knockback_resist = 0.7
	eye_height = 1.7
	marker_height = 2.3
	material_kind = ExhibitMaterial.Kind.METAL
	brain.reaction_time = 0.8
	brain.attack_range = 2.0
	brain.windup = 0.95
	brain.recovery = 1.0


func _build_body() -> void:
	add_collider(0.42, 2.0)
	var steel := body_material(Color(0.62, 0.64, 0.68))
	var dark := body_material(Color(0.25, 0.26, 0.3))
	add_part(box_mesh(Vector3(0.62, 0.8, 0.4)), Vector3(0, 1.2, 0), steel)
	add_part(box_mesh(Vector3(0.5, 0.3, 0.35)), Vector3(0, 0.7, 0), dark)
	for x in [-0.15, 0.15]:
		add_part(box_mesh(Vector3(0.18, 0.7, 0.2)), Vector3(x, 0.35, 0), steel)
	add_part(box_mesh(Vector3(0.32, 0.36, 0.34)), Vector3(0, 1.8, 0), steel)
	add_part(box_mesh(Vector3(0.22, 0.04, 0.02)), Vector3(0, 1.82, -0.175), dark)
	add_part(box_mesh(Vector3(0.06, 0.06, 1.0)), Vector3(0.42, 1.2, -0.5), steel)
	_shield = add_part(box_mesh(Vector3(0.7, 1.0, 0.08)), Vector3(-0.1, 1.1, -0.42), body_material(Color(0.55, 0.12, 0.1)))
	add_hurtbox(box_shape(Vector3(0.62, 1.45, 0.45)), Vector3(0, 0.85, 0))
	add_hurtbox(sphere_shape(0.2), Vector3(0, 1.8, 0), true)


func _blocks(info: DamageInfo) -> bool:
	return ShieldGuard.blocks(-global_transform.basis.z, info.direction, info.kind, brain.is_stunned())


func _on_damaged(info: DamageInfo) -> void:
	if info.amount >= 15.0:
		var fling := Vector3(randf_range(-2.0, 2.0), 3.0, randf_range(-2.0, 2.0))
		Fx.chunk(info.position, ExhibitMaterial.color(material_kind), 0.14, fling)


func _update_visuals(delta: float) -> void:
	super(delta)
	var lowered := brain.is_stunned()
	var weight := 1.0 - exp(-10.0 * delta)
	_shield.rotation.x = lerpf(_shield.rotation.x, -1.2 if lowered else 0.0, weight)
	_shield.position.y = lerpf(_shield.position.y, 0.6 if lowered else 1.1, weight)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `103 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/enemies tests/unit/test_shield_guard.gd tests/integration/test_wolf.gd tests/integration/test_knight.gd
git commit -m "Add stuffed wolf (pounce) and armoured knight (shield)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Zadanie 16: Amunicja i apteczki

Skrzynka naboi, skrzynka śrutu i apteczka obracają się i lekko żarzą, żeby było je widać w półmroku. Dotknięcie działa tylko wtedy, gdy się przyda: pełna apteczka nie zniknie przy pełnym zdrowiu. W piaskownicy znajdźka wraca po 15 s.

**Pliki:**
- Utwórz: `src/arena/pickup.gd`
- Test: `tests/integration/test_pickup.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_pickup.gd`**
```gdscript
extends TestCase

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


func _pickup(type: Pickup.Type, amount: int, at: Vector3) -> Pickup:
	var pickup := Pickup.new()
	pickup.type = type
	pickup.amount = amount
	pickup.position = at
	add_child(pickup)
	return pickup


func test_bullets_refill_the_pistol_reserve() -> void:
	var pistol := player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	pistol.reserve = 0
	var box := _pickup(Pickup.Type.BULLETS, 12, Vector3(5, 0.5, 5))
	assert_true(box.apply_to(player))
	assert_eq(pistol.reserve, 12)


func test_medkit_is_not_wasted_at_full_health() -> void:
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(5, 0.5, 5))
	assert_false(kit.apply_to(player))


func test_medkit_heals_a_hurt_guard() -> void:
	player.health.apply_damage(50.0)
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(5, 0.5, 5))
	assert_true(kit.apply_to(player))
	assert_eq(player.health.current, 75.0)


func test_walking_into_a_pickup_uses_it() -> void:
	player.health.apply_damage(50.0)
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(0, 0.5, 0))
	await physics_frames(5)
	assert_false(kit.active)
	assert_eq(player.health.current, 75.0)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=pickup`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/arena/pickup.gd`**
```gdscript
class_name Pickup
extends Area3D
## Ammo box or medkit. Touching it applies it if the guard can use it; in
## the sandbox it comes back after [member respawn_time] seconds.

enum Type { BULLETS, SHELLS, MEDKIT }

@export var type: Type = Type.BULLETS
@export var amount: int = 12
@export var respawn_time: float = 15.0

var active: bool = true
var _model: Node3D
var _time: float = 0.0


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	_model = _build_model()
	_model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_model)
	body_entered.connect(_on_body_entered)


## Applies the pickup to [param player]. False when it would be wasted.
func apply_to(player: Player) -> bool:
	match type:
		Type.BULLETS:
			return player.weapons.add_ammo(&"bullets", amount) > 0
		Type.SHELLS:
			return player.weapons.add_ammo(&"shells", amount) > 0
		Type.MEDKIT:
			return player.heal(amount) > 0.0
	return false


func _process(delta: float) -> void:
	_time += delta
	_model.rotation.y = _time * 1.5
	_model.position.y = sin(_time * 2.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if not active or player == null or not player.alive:
		return
	if apply_to(player):
		active = false
		_model.visible = false
		Sfx.play(&"pickup", -3.0)
		get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	active = true
	_model.visible = true
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _build_model() -> Node3D:
	var root := Node3D.new()
	match type:
		Type.BULLETS:
			_part(root, Vector3(0.32, 0.2, 0.22), Vector3.ZERO, Color(0.85, 0.68, 0.2))
		Type.SHELLS:
			_part(root, Vector3(0.32, 0.2, 0.22), Vector3.ZERO, Color(0.75, 0.15, 0.12))
		Type.MEDKIT:
			_part(root, Vector3(0.42, 0.3, 0.28), Vector3.ZERO, Color(0.92, 0.92, 0.9))
			_part(root, Vector3(0.2, 0.06, 0.02), Vector3(0, 0, -0.145), Color(0.8, 0.1, 0.1))
			_part(root, Vector3(0.06, 0.2, 0.02), Vector3(0, 0, -0.145), Color(0.8, 0.1, 0.1))
	return root


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	view.position = pos
	parent.add_child(view)
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `107 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/arena/pickup.gd tests/integration/test_pickup.gd
git commit -m "Add ammo and medkit pickups" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 17: HUD

Elementy interfejsu:

- **lewy dół**: zdrowie (liczba i pasek) oraz wytrzymałość, pasek czerwienieje przy zmęczeniu,
- **prawy dół**: nazwa broni i amunicja w formacie „magazynek | zapas”, pasek baterii paralizatora, napis „PRZEŁADOWANIE”,
- **środek**: kropka celownika i znacznik trafienia (biały: trafienie, złoty: słaby punkt, czerwony: zabicie, szary: zablokowane przez tarczę),
- **krawędzie ekranu**: czerwona winieta przy obrażeniach,
- **komunikat śmierci**, **licznik FPS**,
- **panel pomocy** ze sterowaniem: widoczny na starcie, przełączany F1.

Interfejs odczytuje stan gracza co klatkę. Trafienia i obrażenia odbiera z `Events` i reaguje tylko na trafienia zadane przez **tego** gracza.

**Pliki:**
- Utwórz: `src/ui/hud.gd`
- Test: `tests/integration/test_hud.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_hud.gd`**
```gdscript
extends TestCase

var player: Player
var hud: Hud


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	hud = Hud.new()
	hud.player = player
	add_child(hud)


func test_shows_full_health_on_start() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(hud._health_label.text.contains("100"), hud._health_label.text)


func test_own_weak_point_hit_shows_a_gold_marker() -> void:
	var info := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, player)
	info.weak_point = true
	Events.hit_landed.emit(null, info, false)
	assert_gt(hud._crosshair.marker_time, 0.0)
	assert_eq(hud._crosshair.marker_color, Hud.WEAK_POINT_COLOR)


func test_hits_by_others_show_no_marker() -> void:
	Events.hit_landed.emit(null, DamageInfo.make(5.0, DamageInfo.Kind.BLUNT, null), false)
	assert_eq(hud._crosshair.marker_time, 0.0)


func test_damage_flashes_the_vignette() -> void:
	Events.player_damaged.emit(20.0, Vector3.ZERO)
	assert_gt(hud._vignette.modulate.a, 0.3)


func test_ammo_shows_magazine_and_reserve() -> void:
	player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	await get_tree().process_frame
	assert_eq(hud._ammo_label.text, "12 | 36")
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=hud`
Oczekiwane: FAIL.

- [ ] **Krok 3: Implementacja**

**Plik: `src/ui/hud.gd`**
```gdscript
class_name Hud
extends CanvasLayer
## Guard HUD built in code: health + stamina (bottom left), weapon + ammo
## (bottom right), crosshair with hit markers, damage vignette, death
## notice, FPS counter and the F1 help panel.

const HIT_COLOR := Color(1.0, 1.0, 1.0)
const WEAK_POINT_COLOR := Color(1.0, 0.8, 0.2)
const KILL_COLOR := Color(1.0, 0.25, 0.2)
const BLOCKED_COLOR := Color(0.6, 0.6, 0.6)
const HELP_TEXT := """STEROWANIE
WSAD — ruch     Shift — sprint     Ctrl / boczny przycisk myszy — unik
Spacja — skok     LPM — strzał     PPM / V — cios pięścią
R — przeładowanie     1 / 2 / 3, kółko — broń     F — latarka

PIASKOWNICA
7 — figury woskowe     8 — wilki     9 — rycerz     0 — usuń wrogów
F1 — pomoc     F11 — pełny ekran     Esc — uwolnij kursor

Paralizator ogłusza, a pięść dobija ogłuszonego i leczy.
Rycerza obejdź albo ogłusz: prąd przechodzi przez tarczę."""

var player: Player

var _health_label: Label
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _weapon_label: Label
var _ammo_label: Label
var _battery_bar: ProgressBar
var _crosshair: Crosshair
var _vignette: TextureRect
var _death_label: Label
var _fps_label: Label
var _help: PanelContainer


class Crosshair extends Control:
	const MARKER_TIME := 0.2
	var marker_time: float = 0.0
	var marker_color: Color = Color.WHITE

	func show_marker(color: Color) -> void:
		marker_color = color
		marker_time = MARKER_TIME
		queue_redraw()

	func _process(delta: float) -> void:
		if marker_time > 0.0:
			marker_time = maxf(marker_time - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 2.5, Color(1.0, 1.0, 1.0, 0.9))
		if marker_time <= 0.0:
			return
		var color := Color(marker_color, marker_time / MARKER_TIME)
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + corner * 7.0, center + corner * 15.0, color, 3.0, true)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette = _make_vignette()
	root.add_child(_vignette)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	var left := VBoxContainer.new()
	_health_label = _label(30)
	_health_bar = _bar(Vector2(320, 14), Color(0.85, 0.2, 0.18))
	_stamina_bar = _bar(Vector2(320, 8), Color(0.95, 0.8, 0.3))
	left.add_child(_health_label)
	left.add_child(_health_bar)
	left.add_child(_stamina_bar)
	_pin(root, left, Control.PRESET_BOTTOM_LEFT)

	var right := VBoxContainer.new()
	_weapon_label = _label(22)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label = _label(40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_battery_bar = _bar(Vector2(220, 12), Color(0.4, 0.8, 1.0))
	right.add_child(_weapon_label)
	right.add_child(_ammo_label)
	right.add_child(_battery_bar)
	_pin(root, right, Control.PRESET_BOTTOM_RIGHT)

	_death_label = _label(56, Color(0.9, 0.2, 0.15))
	_death_label.text = "STRAŻNIK PADŁ"
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.visible = false
	_pin(root, _death_label, Control.PRESET_CENTER)

	_fps_label = _label(16, Color(1.0, 1.0, 1.0, 0.6))
	_pin(root, _fps_label, Control.PRESET_TOP_RIGHT)

	_help = PanelContainer.new()
	var help_label := _label(20)
	help_label.text = HELP_TEXT
	_help.add_child(help_label)
	_pin(root, _help, Control.PRESET_TOP_LEFT)

	Events.player_damaged.connect(_on_player_damaged)
	Events.hit_landed.connect(_on_hit_landed)


func hide_help() -> void:
	_help.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		_help.visible = not _help.visible


func _process(delta: float) -> void:
	_vignette.modulate.a = move_toward(_vignette.modulate.a, 0.0, 1.5 * delta)
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if player == null:
		return
	_health_label.text = "ZDROWIE  %d" % ceili(player.health.current)
	_health_bar.value = player.health.fraction()
	_stamina_bar.value = player.stamina.fraction()
	_stamina_bar.modulate = Color(1.0, 0.45, 0.35) if player.stamina.exhausted else Color.WHITE
	_death_label.visible = not player.alive
	var state := player.weapons.current_state()
	_weapon_label.visible = state != null
	_ammo_label.visible = false
	_battery_bar.visible = false
	if state == null:
		return
	_weapon_label.text = state.data.display_name.to_upper()
	match state.data.ammo_mode:
		WeaponData.AmmoMode.MAGAZINE:
			_ammo_label.visible = true
			_ammo_label.text = "PRZEŁADOWANIE" if state.is_reloading() else "%d | %d" % [state.magazine, state.reserve]
		WeaponData.AmmoMode.BATTERY:
			_battery_bar.visible = true
			_battery_bar.value = state.battery / state.data.battery_max


func _on_player_damaged(amount: float, _from: Vector3) -> void:
	_vignette.modulate.a = clampf(0.35 + amount / 40.0, 0.0, 0.9)


func _on_hit_landed(_target: Node, info: DamageInfo, killed: bool) -> void:
	if player == null or info == null or info.source != player:
		return
	var color := HIT_COLOR
	if info.blocked:
		color = BLOCKED_COLOR
	elif killed:
		color = KILL_COLOR
	elif info.weak_point:
		color = WEAK_POINT_COLOR
	_crosshair.show_marker(color)
	Sfx.play(&"kill" if killed else &"hit_marker", -8.0)


static func _label(font_size: int, color: Color = Color.WHITE) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 6
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	var label := Label.new()
	label.label_settings = settings
	return label


static func _bar(min_size: Vector2, fill: Color) -> ProgressBar:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = fill
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", foreground)
	return bar


## Adds [param node] to [param root] anchored to a screen corner or centre.
static func _pin(root: Control, node: Control, preset: Control.LayoutPreset) -> void:
	root.add_child(node)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 32)
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			node.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_TOP_RIGHT:
			node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			node.grow_horizontal = Control.GROW_DIRECTION_BOTH
			node.grow_vertical = Control.GROW_DIRECTION_BOTH


static func _make_vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.6, 0.0, 0.0, 0.0), Color(0.6, 0.0, 0.0, 1.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return rect
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `112 passed, 0 failed`.

- [ ] **Krok 5: Commit**

```bash
git add src/ui tests/integration/test_hud.gd
git commit -m "Add HUD with hit markers, vignette and help panel" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 18: Tryb piaskownicy — scena główna i `Graj.bat`

Scena główna składa wszystko w całość: hala, strażnik ze wszystkimi trzema brońmi (na start pistolet), HUD, znajdźki i sześć uśpionych eksponatów na start. Są to trzy figury woskowe, dwa wilki i rycerz na antresoli. Klawisze 7/8/9 dokładają grupy (3 figury, 2 wilki, 1 rycerz) w losowym punkcie, a 0 czyści salę. Po śmierci strażnik wraca na start po 2 s. `Graj.bat` pozwala uruchomić grę dwuklikiem.

**Pliki:**
- Utwórz: `src/arena/sandbox.gd`, `src/arena/sandbox.tscn`, `Graj.bat`
- Zmień: `project.godot` (scena główna)
- Test: `tests/integration/test_sandbox.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/integration/test_sandbox.gd`**
```gdscript
extends TestCase

var sandbox: Sandbox


func before_each() -> void:
	Player.capture_mouse = false
	sandbox = (load("res://src/arena/sandbox.tscn") as PackedScene).instantiate() as Sandbox
	add_child(sandbox)


func after_each() -> void:
	Player.capture_mouse = true


func test_starts_with_an_armed_guard_and_six_exhibits() -> void:
	await physics_frames(5)
	assert_not_null(sandbox.player)
	assert_eq(sandbox.enemies_root.get_child_count(), 6)
	assert_eq(sandbox.player.weapons.owned.size(), 3)
	assert_eq(sandbox.player.weapons.current_state().data.id, &"pistol")


func test_spawn_groups_and_clear() -> void:
	sandbox.clear_enemies()
	await physics_frames(1)
	sandbox.spawn_group(&"wax")
	sandbox.spawn_group(&"wolf")
	sandbox.spawn_group(&"knight")
	assert_eq(sandbox.enemies_root.get_child_count(), 6)


func test_guard_stands_on_the_floor() -> void:
	await physics_frames(30)
	assert_true(sandbox.player.is_on_floor())


func test_dead_guard_respawns_at_the_start() -> void:
	await physics_frames(5)
	sandbox.player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	assert_false(sandbox.player.alive)
	await get_tree().create_timer(Sandbox.RESPAWN_DELAY + 0.3).timeout
	assert_true(sandbox.player.alive)
	assert_eq(sandbox.player.health.current, 100.0)
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=sandbox`
Oczekiwane: FAIL (`test_sandbox_arena.gd` nadal przechodzi, `test_sandbox.gd` nie).

- [ ] **Krok 3: Implementacja**

**Plik: `src/arena/sandbox.gd`**
```gdscript
class_name Sandbox
extends Node3D
## Combat sandbox (stage 1a): the grey hall, the guard with all weapons,
## HUD, a starting set of dormant exhibits, number keys to spawn more,
## respawning pickups and a quick respawn after death.

const PLAYER_START := Vector3(0.0, 0.1, 16.0)
const RESPAWN_DELAY := 2.0
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-15.0, 0.1, -8.0), Vector3(19.5, 0.1, -6.0), Vector3(-16.0, 0.1, 4.0),
	Vector3(16.0, 0.1, 6.0), Vector3(0.0, 0.1, -9.0), Vector3(-8.0, 3.9, -18.0),
]
const GROUP_SIZES := {&"wax": 3, &"wolf": 2, &"knight": 1}

var player: Player
var hud: Hud
var enemies_root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var region := NavigationRegion3D.new()
	region.name = "Arena"
	add_child(region)
	SandboxArena.build(region)
	SandboxArena.add_lighting(self)
	region.bake_navigation_mesh(false)
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	player = Player.new()
	player.position = PLAYER_START
	add_child(player)
	for id in [&"taser", &"pistol", &"shotgun"]:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	player.weapons.select_id(&"pistol")
	hud = Hud.new()
	hud.player = player
	add_child(hud)
	_place_pickups()
	_spawn_starting_exhibits()
	Events.player_died.connect(_on_player_died)


## Spawns one exhibit ([param kind] = &"wax", &"wolf" or &"knight").
func spawn(kind: StringName, at: Vector3, awake: bool) -> Enemy:
	var enemy: Enemy
	match kind:
		&"wax":
			enemy = WaxFigure.new()
		&"wolf":
			enemy = Wolf.new()
		&"knight":
			enemy = Knight.new()
		_:
			return null
	enemy.position = at
	enemy.target = player
	enemies_root.add_child(enemy)
	enemy.face(player.global_position)
	if awake:
		enemy.brain.wake()
	return enemy


## Spawns an awake group at a random spawn point.
func spawn_group(kind: StringName) -> void:
	var base: Vector3 = SPAWN_POINTS[_rng.randi_range(0, SPAWN_POINTS.size() - 1)]
	var count: int = GROUP_SIZES.get(kind, 1)
	for i in count:
		var offset := Vector3.ZERO
		if i > 0:
			offset = Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
		spawn(kind, base + offset, true)


func clear_enemies() -> void:
	for enemy in enemies_root.get_children():
		enemies_root.remove_child(enemy)
		enemy.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"spawn_wax"):
		spawn_group(&"wax")
	elif event.is_action_pressed(&"spawn_wolf"):
		spawn_group(&"wolf")
	elif event.is_action_pressed(&"spawn_knight"):
		spawn_group(&"knight")
	elif event.is_action_pressed(&"clear_enemies"):
		clear_enemies()
	elif event.is_action_pressed(&"toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _spawn_starting_exhibits() -> void:
	for at in [Vector3(-6.0, 0.1, -6.0), Vector3(-4.5, 0.1, -7.5), Vector3(-7.5, 0.1, -8.5)]:
		spawn(&"wax", at, false)
	for at in [Vector3(11.0, 0.1, -10.0), Vector3(12.5, 0.1, -9.0)]:
		spawn(&"wolf", at, false)
	spawn(&"knight", Vector3(-10.0, 3.9, -18.0), false)


func _place_pickups() -> void:
	var layout := [
		[Pickup.Type.BULLETS, 12, Vector3(-18.0, 0.5, 18.0)],
		[Pickup.Type.BULLETS, 12, Vector3(18.0, 0.5, 18.0)],
		[Pickup.Type.SHELLS, 4, Vector3(-18.0, 0.5, -10.0)],
		[Pickup.Type.SHELLS, 4, Vector3(18.0, 0.5, 10.0)],
		[Pickup.Type.MEDKIT, 25, Vector3(0.0, 1.1, 0.0)],
		[Pickup.Type.MEDKIT, 25, Vector3(8.0, 4.25, -20.0)],
	]
	for entry in layout:
		var pickup := Pickup.new()
		pickup.type = entry[0]
		pickup.amount = entry[1]
		pickup.position = entry[2]
		add_child(pickup)


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_instance_valid(player) and not player.alive:
		player.respawn(PLAYER_START)
```

**Plik: `src/arena/sandbox.tscn`**
```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/arena/sandbox.gd" id="1_sandbox"]

[node name="Sandbox" type="Node3D"]
script = ExtResource("1_sandbox")
```

**Plik: `project.godot`**
```ini
; Engine configuration file.
; Hand-maintained: autoloads and the main scene are listed here.

config_version=5

[application]

config/name="Nocna Zmiana"
run/main_scene="res://src/arena/sandbox.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]

Events="*res://src/core/events.gd"
GameInput="*res://src/core/game_input.gd"
Fx="*res://src/fx/fx.gd"
Sfx="*res://src/fx/sfx.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemy"
3d_physics/layer_4="hurtbox"
3d_physics/layer_5="debris"
3d_physics/layer_6="pickup"

[physics]

3d/physics_engine="Jolt Physics"
common/physics_interpolation=true
common/physics_jitter_fix=0.0

[rendering]

anti_aliasing/quality/msaa_3d=2
```

**Plik: `Graj.bat`**
```bat
@echo off
rem Nocna Zmiana - piaskownica walki. Dwuklik, zeby zagrac.
set GODOT=%~dp0tools\godot\Godot_v4.7.2-stable_win64
"%GODOT%_console.exe" --headless --path "%~dp0." --import >nul 2>&1
start "" "%GODOT%.exe" --path "%~dp0."
```

- [ ] **Krok 4: Uruchom testy**

Run: `bash tools/run_tests.sh`
Oczekiwane: `116 passed, 0 failed`.

- [ ] **Krok 5: Pierwsze uruchomienie z oknem (sprawdzenie ręczne)**

Run: `tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --quit-after 600`
Oczekiwane: okno z szarą halą, HUD i panelem pomocy. Po ok. 10 s okno zamyka się samo. W konsoli nie ma linii `ERROR`/`SCRIPT ERROR`. Kursor jest przechwycony, a Esc go uwalnia.

- [ ] **Krok 6: Commit**

```bash
git add src/arena/sandbox.gd src/arena/sandbox.tscn project.godot Graj.bat tests/integration/test_sandbox.gd
git commit -m "Add playable combat sandbox as the main scene" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Zadanie 19: Proceduralne efekty dźwiękowe

Skrypt w Pythonie (tylko biblioteka standardowa, stałe ziarno losowości) syntetyzuje 24 efekty z prostych klocków:

- szum przez filtry,
- tony opadające w wysokości,
- metaliczne „klangi” z nieharmonicznych sinusów,
- rozsypane ziarna (kruszenie, grzechot),
- krótkie echo, które daje wrażenie przestrzeni.

Pliki `.wav` trafiają do `assets/sfx/`, a nazwy muszą się zgadzać z `Sfx.SOUNDS`. Wygenerowane pliki i ich `.import` commitujemy, więc gra działa bez uruchamiania Pythona.

**Pliki:**
- Utwórz: `tools/sfx/gen_sfx.py`, `assets/sfx/*.wav` (wygenerowane)
- Test: `tests/unit/test_sfx_files.gd`

- [ ] **Krok 1: Test**

**Plik: `tests/unit/test_sfx_files.gd`**
```gdscript
extends TestCase


func test_every_game_sound_has_a_generated_file() -> void:
	for sound in Sfx.SOUNDS:
		assert_true(ResourceLoader.exists("res://assets/sfx/%s.wav" % sound), "missing " + str(sound))


func test_stop_all_silences_everything() -> void:
	Sfx.play(&"pistol")
	Sfx.play_at(&"block", Vector3.ZERO)
	assert_gt(Sfx.get_child_count(), 0)
	Sfx.stop_all()
	assert_eq(Sfx.get_child_count(), 0)


func test_material_sounds_are_on_the_list() -> void:
	for kind in ExhibitMaterial.Kind.values():
		assert_true(Sfx.SOUNDS.has(ExhibitMaterial.hit_sound(kind)), str(ExhibitMaterial.hit_sound(kind)))
		assert_true(Sfx.SOUNDS.has(ExhibitMaterial.break_sound(kind)), str(ExhibitMaterial.break_sound(kind)))
```

- [ ] **Krok 2: Uruchom, żeby zobaczyć porażkę**

Run: `bash tools/run_tests.sh --filter=sfx_files`
Oczekiwane: `test_every_game_sound_has_a_generated_file` FAIL (24× „missing …”) i `test_stop_all_silences_everything` FAIL (bez plików nie ma czego grać).

- [ ] **Krok 3: Generator**

**Plik: `tools/sfx/gen_sfx.py`**
```python
"""Procedural sound effects for Nocna Zmiana (stage 1a).

Writes 16-bit mono WAV files to assets/sfx/. Standard library only and
seeded, so every run produces the same files. Run from the repo root:

    python tools/sfx/gen_sfx.py

Names must match Sfx.SOUNDS in src/fx/sfx.gd.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "assets" / "sfx"
rng = random.Random(1987)


def n(seconds):
    return max(int(seconds * RATE), 1)


def noise(length):
    return [rng.uniform(-1.0, 1.0) for _ in range(length)]


def lowpass(samples, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    return [x - low for x, low in zip(samples, lowpass(samples, cutoff))]


def env_exp(length, decay, attack=0.002):
    """Quick attack, exponential decay (decay = time constant in seconds)."""
    a = n(attack)
    return [min(i / a, 1.0) * math.exp(-i / (decay * RATE)) for i in range(length)]


def env_hump(length, peak=0.4):
    """Rise to a peak (fraction of the length), then fall to zero."""
    p = max(int(length * peak), 1)
    return [i / p if i < p else max(0.0, 1.0 - (i - p) / max(length - p, 1)) for i in range(length)]


def sweep(length, f0, f1, shape="sine"):
    """Oscillator gliding exponentially from f0 to f1 Hz."""
    out, phase = [], 0.0
    for i in range(length):
        f = f0 * (f1 / f0) ** (i / length)
        phase += 2.0 * math.pi * f / RATE
        if shape == "sine":
            out.append(math.sin(phase))
        elif shape == "square":
            out.append(1.0 if math.sin(phase) >= 0.0 else -1.0)
        else:
            out.append((phase / math.pi) % 2.0 - 1.0)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def mix(*layers):
    """Sum (samples, gain) layers of any lengths."""
    out = [0.0] * max(len(s) for s, _ in layers)
    for s, g in layers:
        for i, x in enumerate(s):
            out[i] += x * g
    return out


def delay(samples, seconds):
    return [0.0] * n(seconds) + samples


def echo(samples, seconds=0.07, feedback=0.3, taps=3):
    """Cheap room: a few decaying repeats."""
    d = n(seconds)
    out = samples + [0.0] * (d * taps)
    for t in range(1, taps + 1):
        g = feedback ** t
        for i, x in enumerate(samples):
            out[i + d * t] += x * g
    return out


def grains(seconds, count, make):
    """Scatter short sounds over a time span (crumbling, clatter)."""
    out = [0.0] * n(seconds)
    for _ in range(count):
        g = make()
        start = rng.randint(0, max(len(out) - len(g), 0))
        for i, x in enumerate(g):
            if start + i < len(out):
                out[start + i] += x
    return out


# --- building blocks -------------------------------------------------------

def thump(seconds, f0, f1, decay):
    length = n(seconds)
    return mul(sweep(length, f0, f1), env_exp(length, decay))


def crack(seconds, cutoff, decay):
    length = n(seconds)
    return mul(highpass(noise(length), cutoff), env_exp(length, decay, 0.0005))


def rumble(seconds, cutoff, decay):
    length = n(seconds)
    return mul(lowpass(noise(length), cutoff), env_exp(length, decay))


def clang(seconds, freqs, decay):
    length = n(seconds)
    tone = mix(*[(sweep(length, f, f * 0.995), 1.0 / (k + 1)) for k, f in enumerate(freqs)])
    return mul(tone, env_exp(length, decay, 0.0005))


def whoosh(seconds, low, high, peak=0.4):
    length = n(seconds)
    return mul(lowpass(highpass(noise(length), low), high), env_hump(length, peak))


def blip(seconds, freq):
    length = n(seconds)
    return mul(sweep(length, freq, freq), env_exp(length, seconds * 0.5))


def taser():
    length = n(0.35)
    buzz = sweep(length, 95, 85, "square")
    hiss = highpass(noise(length), 3000)
    gate, level, step = [], 1.0, n(0.006)
    for i in range(length):
        if i % step == 0:
            level = rng.choice([0.25, 0.6, 1.0])
        gate.append(level)
    return mul(mix((buzz, 0.45), (hiss, 0.55)), mul(gate, env_exp(length, 0.25)))


def growl():
    length = n(0.6)
    wobble = [0.6 + 0.4 * math.sin(2.0 * math.pi * 28.0 * i / RATE) for i in range(length)]
    return mul(mul(lowpass(noise(length), 420), wobble), env_hump(length, 0.3))


def hurt():
    length = n(0.3)
    voice = lowpass(mul(sweep(length, 220, 140, "saw"), env_exp(length, 0.12)), 900)
    return mix((thump(0.3, 90, 40, 0.1), 1.0), (voice, 0.5))


def notice():
    length = n(0.45)
    return mul(mix((sweep(length, 180, 420), 1.0), (sweep(length, 360, 840), 0.3)), env_hump(length, 0.7))


SOUNDS = {
    "pistol": lambda: echo(mix((crack(0.12, 1500, 0.02), 0.8), (thump(0.25, 160, 45, 0.06), 1.0), (rumble(0.3, 900, 0.07), 0.6)), 0.06, 0.25, 3),
    "shotgun": lambda: echo(mix((crack(0.2, 900, 0.04), 0.9), (thump(0.5, 110, 30, 0.14), 1.0), (rumble(0.6, 600, 0.16), 0.9)), 0.08, 0.3, 4),
    "taser": taser,
    "punch": lambda: whoosh(0.18, 300, 2500, 0.35),
    "punch_hit": lambda: mix((thump(0.2, 120, 45, 0.05), 1.0), (crack(0.05, 2000, 0.008), 0.5)),
    "reload": lambda: mix((crack(0.04, 2500, 0.006), 1.0), (clang(0.08, [2400, 3700], 0.02), 0.4),
                          (delay(crack(0.04, 2200, 0.006), 0.28), 0.9), (delay(clang(0.1, [1900, 3100], 0.025), 0.28), 0.4)),
    "empty": lambda: crack(0.03, 3000, 0.004),
    "swing": lambda: whoosh(0.3, 150, 1200, 0.45),
    "hurt": hurt,
    "dash": lambda: whoosh(0.25, 500, 4000, 0.3),
    "notice": notice,
    "growl": growl,
    "hit_marker": lambda: clang(0.05, [3200], 0.01),
    "kill": lambda: mix((clang(0.12, [1800, 2700], 0.03), 1.0), (thump(0.12, 200, 90, 0.04), 0.8)),
    "pickup": lambda: mix((blip(0.07, 880), 1.0), (delay(blip(0.09, 1320), 0.07), 1.0)),
    "block": lambda: mix((clang(0.5, [420, 1030, 1650, 2380], 0.15), 1.0), (crack(0.05, 2000, 0.01), 0.6)),
    "hit_wax": lambda: mix((thump(0.15, 260, 110, 0.04), 1.0), (rumble(0.15, 1200, 0.04), 0.7)),
    "break_wax": lambda: mix((thump(0.35, 180, 60, 0.1), 1.0), (grains(0.5, 14, lambda: rumble(0.05, 1500, 0.015)), 0.6)),
    "hit_sawdust": lambda: mix((rumble(0.2, 700, 0.06), 1.0), (crack(0.08, 3000, 0.02), 0.2)),
    "break_sawdust": lambda: mix((rumble(0.5, 500, 0.15), 1.0), (grains(0.6, 20, lambda: crack(0.02, 1500, 0.006)), 0.4)),
    "hit_marble": lambda: mix((crack(0.08, 2500, 0.01), 1.0), (clang(0.12, [1900, 3100], 0.025), 0.6)),
    "break_marble": lambda: grains(0.7, 26, lambda: mix((crack(0.04, 2000, 0.008), 1.0),
                                                        (clang(0.06, [rng.uniform(1500, 3500)], 0.015), 0.5))),
    "hit_metal": lambda: mix((clang(0.35, [620, 1480, 2330], 0.08), 1.0), (crack(0.03, 3000, 0.005), 0.5)),
    "break_metal": lambda: grains(0.8, 10, lambda: clang(0.3, [rng.uniform(400, 900), rng.uniform(1200, 2500)], 0.07)),
}


def write(name, samples, peak=0.9):
    OUT.mkdir(parents=True, exist_ok=True)
    loudest = max(abs(x) for x in samples) or 1.0
    data = [x * peak / loudest for x in samples]
    fade = min(n(0.01), len(data))
    for i in range(fade):
        data[-1 - i] *= i / fade
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in data)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def main():
    for name, make in SOUNDS.items():
        write(name, make())
        print("wrote", name)


if __name__ == "__main__":
    main()
```

- [ ] **Krok 4: Wygeneruj i uruchom testy**

```bash
python tools/sfx/gen_sfx.py
bash tools/run_tests.sh
```

Oczekiwane: 24 linie `wrote …`, potem `119 passed, 0 failed`. Pliki `assets/sfx/*.wav.import` powstają przy imporcie w `run_tests.sh`.

- [ ] **Krok 5: Posłuchaj (sprawdzenie ręczne)**

Odtwórz kilka plików, np. `start assets/sfx/shotgun.wav`, `start assets/sfx/taser.wav`, `start assets/sfx/break_wax.wav`. Nic nie może trzeszczeć przy końcu pliku (wyciszenie 10 ms) i nie może być tylko cisza. Każdy plik jest normalizowany do 0,9, a proporcje głośności ustawia kod przez `volume_db`.

- [ ] **Krok 6: Commit**

```bash
git add tools/sfx assets tests/unit/test_sfx_files.gd
git commit -m "Add procedural sound effects generator and generated sounds" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 20: Scenariusze wizualne i szlif odczuć

Testy bez okna nie widzą obrazu, więc każdy scenariusz otwiera okno 1280 × 720 (poza `perf`) i robi dwie rzeczy:

1. inscenizuje jedną chwilę walki,
2. zapisuje zrzuty ekranu i stan gry (JSON) do `tests/_out/` (katalog poza gitem).

Scenariusz nie przechwytuje kursora. Zrzuty ogląda się narzędziem do czytania obrazów. To zadanie jest pętlą: uruchom, obejrzyj, popraw liczby, powtórz.

**Pliki:**
- Utwórz: `tests/scenarios/scenario_runner.gd`, `tests/scenarios/scenario_runner.tscn`, `tools/run_scenario.sh`

- [ ] **Krok 1: Runner scenariuszy**

**Plik: `tests/scenarios/scenario_runner.gd`**
```gdscript
extends Node
## Windowed visual check (not part of the headless suite). Loads the
## sandbox, stages one moment, saves screenshots and a JSON state dump to
## tests/_out/. Usage: bash tools/run_scenario.sh <name>, where name is one
## of: overview, shotgun_gib, taser_finisher, knight_block, wolf_pounce, perf.
## All but "perf" run in a 1280x720 window; "perf" keeps the project's
## maximized window and measures the average frame rate.

const OUT_DIR := "res://tests/_out/"

var sandbox: Sandbox
var _scenario := "overview"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			_scenario = arg.trim_prefix("--scenario=")
	Player.capture_mouse = false
	if _scenario != "perf":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	var ignore := FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()
	sandbox = (load("res://src/arena/sandbox.tscn") as PackedScene).instantiate() as Sandbox
	add_child(sandbox)
	await _frames(60)   # let shaders compile before judging anything
	match _scenario:
		"overview":
			await _overview()
		"shotgun_gib":
			await _shotgun_gib()
		"taser_finisher":
			await _taser_finisher()
		"knight_block":
			await _knight_block()
		"wolf_pounce":
			await _wolf_pounce()
		"perf":
			await _perf()
		_:
			print("Unknown scenario: ", _scenario)
	_dump_state()
	Sfx.stop_all()
	await _frames(10)
	get_tree().quit(0)


func _overview() -> void:
	await _shot("help")
	sandbox.hud.hide_help()
	sandbox.player.head.rotation.y = deg_to_rad(40.0)
	await _frames(5)
	await _shot("turned")
	sandbox.player.flashlight.visible = true
	sandbox.player.head.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(-30.0), 0.0)
	await _frames(5)
	await _shot("flashlight")


func _shotgun_gib() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	sandbox.spawn(&"wax", guard.global_position + Vector3(0.0, 0.0, -3.0), false)
	guard.weapons.select_id(&"shotgun")
	guard.head.rotation.x = deg_to_rad(-12.0)   # aim at the torso so every pellet lands
	await _frames(40)
	await _shot("before")
	guard.weapons.try_fire()
	await _frames(2)
	await _shot("t02")
	await _frames(6)
	await _shot("t08")
	await _frames(40)
	await _shot("t48")


func _taser_finisher() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	var wax := sandbox.spawn(&"wax", guard.global_position + Vector3(0.0, 0.0, -1.4), false)
	guard.weapons.select_id(&"taser")
	await _frames(30)
	guard.weapons.try_fire()
	await _frames(3)
	await _shot("zap")
	await _frames(20)
	await _shot("stunned")
	guard.weapons.try_punch()
	await _frames(4)
	await _shot("finisher")
	print("wax destroyed by finisher: ", not is_instance_valid(wax) or wax.is_queued_for_deletion())


func _knight_block() -> void:
	var guard := sandbox.player
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	var knight := sandbox.spawn(&"knight", guard.global_position + Vector3(0.0, 0.0, -4.0), false)
	guard.weapons.select_id(&"pistol")
	await _frames(20)
	guard.weapons.try_fire()
	await _frames(2)
	await _shot("blocked")
	print("knight health after a frontal shot: ", knight.health.current)


func _wolf_pounce() -> void:
	sandbox.hud.hide_help()
	sandbox.clear_enemies()
	sandbox.spawn(&"wolf", sandbox.player.global_position + Vector3(0.0, 0.0, -9.0), true)
	for i in 6:
		await _frames(10)
		await _shot("t%02d" % ((i + 1) * 10))


func _perf() -> void:
	sandbox.hud.hide_help()
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < 4000000:
		await get_tree().process_frame
		frames += 1
	print("average FPS over 4 s at %s: %.0f" % [DisplayServer.window_get_size(), frames / 4.0])


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s_%s.png" % [_scenario, label])
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _dump_state() -> void:
	var enemies: Array = []
	for node in sandbox.enemies_root.get_children():
		var enemy := node as Enemy
		if enemy != null and not enemy.is_queued_for_deletion():
			enemies.append({
				"type": enemy.get_script().get_global_name(),
				"state": EnemyBrain.State.keys()[enemy.brain.state],
				"health": enemy.health.current,
				"position": str(enemy.global_position),
			})
	var state := {
		"scenario": _scenario,
		"fps": Engine.get_frames_per_second(),
		"player": {
			"health": sandbox.player.health.current,
			"stamina": sandbox.player.stamina.current,
			"position": str(sandbox.player.global_position),
		},
		"enemies": enemies,
		"debris_chunks": Fx.chunk_count(),
	}
	var file := FileAccess.open(OUT_DIR.path_join("%s_state.json" % _scenario), FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "  "))
	file.close()
```

**Plik: `tests/scenarios/scenario_runner.tscn`**
```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/scenarios/scenario_runner.gd" id="1_scenario"]

[node name="ScenarioRunner" type="Node"]
script = ExtResource("1_scenario")
```

**Plik: `tools/run_scenario.sh`**
```bash
#!/usr/bin/env bash
# Runs one windowed visual scenario; screenshots + state land in tests/_out/.
# Usage: bash tools/run_scenario.sh overview|shotgun_gib|taser_finisher|knight_block|wolf_pounce|perf
cd "$(dirname "$0")/.." || exit 1
NAME="${1:-overview}"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --path . res://tests/scenarios/scenario_runner.tscn -- --scenario="$NAME" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
```

- [ ] **Krok 2: Uruchom wszystkie scenariusze**

```bash
for s in overview shotgun_gib taser_finisher knight_block wolf_pounce perf; do bash tools/run_scenario.sh $s; done
```

Oczekiwane: każdy scenariusz kończy się bez `ERROR`, a w `tests/_out/` leżą zrzuty `<scenariusz>_*.png` i `<scenariusz>_state.json`. W logu mają się pojawić dwie linie:

- `wax destroyed by finisher: true`,
- `knight health after a frontal shot: 180` (tarcza zablokowała strzał).

Scenariusz `perf` wypisuje `average FPS over 4 s at (szer., wys.): N`. Na komputerze gracza (RTX 2080 Ti, okno 4K, monitor 60 Hz) wychodzi 60 z synchronizacją pionową. Bez niej, z `--disable-vsync` w poleceniu Godota, było ok. 200 przy pisaniu planu.

- [ ] **Krok 3: Obejrzyj zrzuty i porównaj z listą**

| Zrzut | Co ma być widać |
|---|---|
| `overview_help` | szara hala z siatką, antresola, panel pomocy, HUD czytelny w obu dolnych rogach, kropka celownika na środku |
| `overview_turned` | filary, lampy dają ciepłe plamy światła, mgła lekko widoczna, obraz nie jest ani czarny, ani wyblakły |
| `overview_flashlight` | wyraźny stożek latarki z cieniem |
| `shotgun_gib_before` | figura woskowa 3 m przed strażnikiem, dwulufowa strzelba w prawym dolnym rogu, nieucięta i niewchodząca w kamerę |
| `shotgun_gib_t02`, `_t08` | błysk z lufy, smugi śrutu, figura rozerwana na wiele kawałków i chmura woskowych kropel |
| `shotgun_gib_t48` | kawałki leżą na podłodze (fizyka), czerwony znacznik zabicia już wygasł |
| `taser_finisher_zap` | niebieski, poszarpany łuk od paralizatora do figury |
| `taser_finisher_stunned` | wirujący niebieski pierścień nad głową figury |
| `taser_finisher_finisher` | pięść w kadrze, figura się rozpada |
| `knight_block_blocked` | iskry na tarczy, szary znacznik trafienia |
| `wolf_pounce_t10…t60` | wilk przykuca, skacze łukiem i ląduje przy strażniku |

- [ ] **Krok 4: Popraw to, co odstaje, i powtórz krok 2**

Najczęstsze pokrętła:

| Problem | Gdzie |
|---|---|
| za ciemno lub za jasno | `SandboxArena.add_lighting`: `ambient_light_energy`, `light_energy` lamp i księżyca, `volumetric_fog_density` |
| broń za duża, za mała albo źle ustawiona | `WeaponHolder.REST`, `Viewmodels.FOV` |
| broń mimo wszystko wchodzi w ściany | `Viewmodels.material` → `z_clip_scale` (mniej = bliżej kamery) |
| cząsteczki niewidoczne | `Fx.impact`/`Fx.shatter`: `amount`, `size`, prędkości |
| rozerwanie za słabe lub za mocne | `GibPlanner`: `impulse`, `chunks` (testy w `test_gib_planner.gd` pilnują zależności, nie konkretnych liczb) |

Po każdej zmianie uruchom też `bash tools/run_tests.sh`. Wszystko musi przechodzić.

- [ ] **Krok 5: Commit**

```bash
git add tests/scenarios tools/run_scenario.sh src
git commit -m "Add windowed visual scenarios and first feel pass" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 21: Eksport do `.exe`

Ostatecznym produktem ma być zwykły program Windows. Godot eksportuje grę do **jednego** pliku `build/NocnaZmiana.exe` (ok. 105 MB), z danymi gry zapakowanymi w środku (`embed_pck`). Potrzebne są szablony eksportu 4.7.2 dla Windows. Są już na dysku D: w folderze innego projektu, więc nic nie trzeba pobierać. W trybie self-contained Godot szuka ich w `tools/godot/editor_data/export_templates/4.7.2.stable/`. Testy (`tests/*`) nie trafiają do gry.

**Pliki:**
- Utwórz: `export_presets.cfg`, `tools/export.sh`, `tools/godot/editor_data/export_templates/4.7.2.stable/*` (kopia, poza gitem)

- [ ] **Krok 1: Szablony eksportu**

```bash
mkdir -p tools/godot/editor_data/export_templates/4.7.2.stable
cp "D:/Codex/Gra RTS/tools/godot/editor_data/export_templates/4.7.2.stable/"{version.txt,windows_release_x86_64.exe,windows_debug_x86_64.exe} tools/godot/editor_data/export_templates/4.7.2.stable/
cat tools/godot/editor_data/export_templates/4.7.2.stable/version.txt
```

Oczekiwane: `4.7.2.stable`.

- [ ] **Krok 2: Preset i skrypt eksportu**

**Plik: `export_presets.cfg`**
```ini
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*"
export_path="build/NocnaZmiana.exe"

[preset.0.options]

binary_format/embed_pck=true
binary_format/architecture="x86_64"
application/modify_resources=false
application/product_name="Nocna Zmiana"
```

**Plik: `tools/export.sh`**
```bash
#!/usr/bin/env bash
# Builds the standalone game: build/NocnaZmiana.exe (one file, game data
# embedded), then smoke-runs it headless. Needs the 4.7.2 Windows export
# templates in tools/godot/editor_data/export_templates/4.7.2.stable/.
cd "$(dirname "$0")/.." || exit 1
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
mkdir -p build
rm -f build/NocnaZmiana.exe
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --path . --export-release "Windows Desktop" build/NocnaZmiana.exe 2>&1)
if [ ! -f build/NocnaZmiana.exe ] || echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
	echo "$OUT" | grep -E "ERROR|WARNING"
	echo "EXPORT FAILED"
	exit 1
fi
ls -l build/NocnaZmiana.exe
SMOKE=$(build/NocnaZmiana.exe --headless --quit-after 120 2>&1)
if echo "$SMOKE" | grep -qE "SCRIPT ERROR|Parse Error"; then
	echo "$SMOKE"
	echo "EXPORTED GAME HAS SCRIPT ERRORS"
	exit 1
fi
echo "OK: build/NocnaZmiana.exe"
```

- [ ] **Krok 3: Eksport**

Run: `bash tools/export.sh`
Oczekiwane: plik `build/NocnaZmiana.exe` o rozmiarze ok. 105 MB i na końcu `OK: build/NocnaZmiana.exe`.

Test dymny sprawdza tylko błędy skryptów. Wymuszone zamknięcie przez `--quit-after` omija `Sfx.quit_cleanly()`, więc jeśli akurat gra jakiś dźwięk, silnik może wypisać linię o „resources still in use at exit”. To niegroźne, a przy zwykłym zamknięciu okna (X, Alt+F4) nie występuje.

- [ ] **Krok 4: Sprawdzenie ręczne**

Uruchom `build/NocnaZmiana.exe` dwuklikiem. Gra ma wystartować w oknie, z dźwiękami, i zamknąć się bez komunikatów po kliknięciu X (najpierw Esc, żeby uwolnić kursor). Grę można skopiować w dowolne miejsce, bo to jeden samodzielny plik.

- [ ] **Krok 5: Commit**

```bash
git add export_presets.cfg tools/export.sh .gitignore
git commit -m "Add Windows export: build/NocnaZmiana.exe" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Zadanie 22: Weryfikacja końcowa i testy gracza

- [ ] **Krok 1: Pełna weryfikacja**

```bash
bash tools/run_tests.sh
for s in overview shotgun_gib taser_finisher knight_block wolf_pounce perf; do bash tools/run_scenario.sh $s; done
bash tools/export.sh
git status
```

Oczekiwane: `119 passed, 0 failed`, wszystkie scenariusze bez `ERROR`, świeży `build/NocnaZmiana.exe`, czyste drzewo robocze.

- [ ] **Krok 2: Przekazanie graczowi**

Gracz uruchamia `build/NocnaZmiana.exe` dwuklikiem. Przekaż mu po polsku, krótko:

- sterowanie (jest też w grze pod F1),
- sposób na rycerza: paralizator ogłusza przez tarczę albo trzeba go obejść,
- synergię: paralizator ogłusza, pięść dobija ogłuszonego i leczy.

Poproś o wrażenia w tych punktach:

1. **Ruch:** czy chód, sprint i unik są w sam raz? Czy wytrzymałość za szybko się kończy?
2. **Bronie:** czy każda „czuje się” inaczej? Czy strzelba daje satysfakcję? Czy dźwięki pasują?
3. **Wrogowie:** czy widać zapowiedź ataku (odchylenie i żarzenie)? Czy da się jej uniknąć? Czy wilk jest za szybki? Czy rycerz jest za twardy?
4. **Rozpad:** czy rozpadanie się eksponatów jest „mięsiste”?
5. **Czytelność:** HUD, znaczniki trafień, oświetlenie.
6. **Wydajność:** licznik FPS w prawym górnym rogu.

- [ ] **Krok 3: Po testach**

Uwagi gracza zamieniamy na poprawki liczb, najlepiej małymi commitami i z uruchomieniem testów po każdym. Po poprawkach ponownie uruchom `bash tools/export.sh`, żeby `.exe` był aktualny. Potem zamykamy gałąź skillem **superpowers:finishing-a-development-branch**. Następny krok to plan etapu **1b (próbka stylu)**.

---

## Samokontrola planu (wykonana przy pisaniu)

- **Pokrycie specu, etap 1:** ruch z wytrzymałością i unikiem (zad. 4, 12); 4 bronie (9, 11); figura woskowa, wilk i rycerz (14, 15); rozpad zależny od materiału (6, 7, 14); HUD (17); „soczyste” strzelanie, czyli wstrząs, hitstop, błyski, smugi, odrzut modelu, dźwięk (5, 7, 11, 12, 19, 20); synergia ogłusz-dobij-lecz (11, 12, 14); tarcza rycerza obchodzona obejściem lub ogłuszeniem (15); testy bez okna i automatyczne sesje ze zrzutami (1, 20); zapis stanu z automatycznej sesji (20); gra jako samodzielny `.exe` (21).
- **Świadomie poza 1a:** próbka stylu (plan 1b); Pył, przystanie, ulepszenia, lobby i boss (etap 2).
- **Weryfikacja wizualna przy pisaniu planu:** scenariusze wykazały trzy problemy, poprawione już w planie:
  - modele broni stały za nisko i za blisko kamery (teraz `REST` = (0,17; −0,16; −0,55), obrót 0,1 rad w stronę celownika, jaśniejsze kolory),
  - scenariusz kończył się z grającymi dźwiękami, a serwer audio zgłaszał wtedy wyciek (dodano `Sfx.stop_all()`),
  - okno projektu otwierało się zmaksymalizowane w 4K (scenariusz sam ustawia 1280 × 720).

  Wydajność: ok. 200 FPS w oknie 4K bez synchronizacji pionowej na RTX 2080 Ti.
- **Eksport sprawdzony przy pisaniu planu:** `NocnaZmiana.exe` (ok. 105 MB) uruchamia się, wczytuje wszystkie 24 dźwięki i zamyka czysto przez `Sfx.quit_cleanly()`.
- **Weryfikacja kodu planu:** cały kod z zadań 1–19 wyciągnięto z tego dokumentu do czystego projektu i uruchomiono. Wszystkie 119 testów przeszło bez błędów silnika. Scenariusze z zadania 20 uruchomiono z oknem przy pisaniu planu.
