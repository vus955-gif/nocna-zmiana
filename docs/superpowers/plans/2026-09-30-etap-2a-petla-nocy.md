# Etap 2a — Pętla nocy: plan implementacji

> Wykonawca: Claude (główny programista etapu 2a), praca w osobnym drzewie roboczym, commit po każdym zadaniu.
> Projekt nadrzędny: `docs/superpowers/specs/2026-09-30-etap-2-projekt.md` (sekcje 0–4, 10, wiersz 2a sekcji 12, testy 2a z sekcji 13, sekcja 14: „Mysz i pauza”, „Zapisy”, „Tryb okna”) oraz `docs/Nocna-Zmiana-specyfikacja.md` (sekcja 7).

**Cel:** pełna pętla nocy na zastępczym poziomie: menu główne → noc w muzeum (poziom z piaskownicy + kanciapa-przystań) → zabijanie eksponatów, zbieranie Pyłu → śmierć → latarka z Pyłem, ekran „23:00”, noc +1 → odzyskanie latarki → przystań (leczenie, zapis) → terminal ulepszeń → trwałe ulepszenia działają. Do tego ustawienia, lokalizacja, zapis gry, pauza, opcje i dźwięki interfejsu. Wszystko w jakości wydania, z testami bez okna.

**Architektura:** jak w 1a — węzły buduje kod, `.tscn` minimalne, czysta logika w klasach `RefCounted` (lub statycznych), moduły rozmawiają przez `Events`. Nowe autoloady: `Settings` (ustawienia), `GameState` (stan trwały), `RunState` (stan nocy), `SceneFlow` (zmiana scen z wyciemnieniem). `Museum` zależy wyłącznie od kontraktu `Level` (`src/level/level.gd`, wspólny z 2b); w 2a poziomem jest `SandboxLevel` (hala z piaskownicy + kanciapa).

---

## Konwencje (obowiązują jak w 1a)

- Godot: `tools/godot/Godot_v4.7.2-stable_win64_console.exe` (w drzewie roboczym to złącze do katalogu z głównego repo — **nigdy go nie dodawaj do gita**).
- Testy: `bash tools/run_tests.sh` (`--filter=nazwa`). Przebieg nieudany przy porażce testu, linii `ERROR`/`SCRIPT ERROR`/`SHADER ERROR` lub wycieku przy wyjściu.
- Okienkowe uruchomienia zawsze z `--audio-driver Dummy` (skrypty `run_scenario.sh`, `run_sandbox.sh` robią to domyślnie; `SOUND=1` włącza dźwięk).
- Wcięcia: wyłącznie tabulatory. Identyfikatory i komentarze po angielsku. **Każdy tekst dla gracza przez `tr("KLUCZ")`**, klucze w `locale/strings.csv`.
- Warstwy fizyki (`src/core/layers.gd`): 1 `WORLD`, 2 `PLAYER`, 4 `ENEMY`, 8 `HURTBOX`, 16 `DEBRIS`, 32 `PICKUP`, **64 `INTERACT`**, **128 `ENEMY_BLOCK`** (niewidzialne ściany tylko dla wrogów — przystanie).
- Interfejs obrażeń bez zmian: `take_damage(info: DamageInfo)`.
- **Testy nigdy nie dotykają prawdziwego zapisu ani ustawień:** `SavePaths` wykrywa uruchomienie z `res://tests/…` (runner testów, scenariusze) i kieruje zapisy do `res://tests/_out/saves/` (w gitignore); runner czyści ten katalog na starcie. Dodatkowo `--save-dir=<ścieżka>` (argument użytkownika) lub zmienna `NZ_SAVE_DIR` przekierowują zapisy ręcznie.
- Commit po każdym zadaniu: `git commit -m "<temat>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`. Dodawaj tylko swoje pliki (nigdy `git add -A`).

## Mapa plików

| Plik | Odpowiada za | Zadanie |
|---|---|---|
| `src/core/save_paths.gd` | `SavePaths`: katalog zapisu (przenośny obok exe / `user://` / katalog testowy) | 2 |
| `src/core/save_file.gd` | `SaveFile`: zapis atomowy (`.tmp` → rename), odczyt, kwarantanna `.bad`, JSON | 2, 4 |
| `src/core/settings_data.gd` | `SettingsData`: wartości ustawień, domyślne, zakresy, `ConfigFile` | 2 |
| `src/core/settings.gd` | autoload `Settings` (`GameSettings`): stosowanie na żywo, `settings_changed`, F11 | 2 |
| `locale/strings.csv` | wszystkie teksty gracza (`keys,pl,en`) | 3 |
| `src/state/game_state.gd` | autoload `GameState` (`PersistentState`): stan trwały, zapis JSON | 4 |
| `src/state/run_state.gd` | autoload `RunState` (`NightState`): stan jednej nocy, Pył, mnożniki | 4 |
| `src/interaction/interactable.gd` | `Interactable` (Area3D w warstwie INTERACT) | 5 |
| `src/player/interactor.gd` | `Interactor`: promień 2,2 m ze środka ekranu, fokus, `interact` | 5 |
| `src/progression/dust_rules.gd` | `DustRules`: wartość zabicia, dobicie ×1,5, podział na drobiny | 6 |
| `src/progression/dust_mote.gd` | `DustMote`: świecąca drobina, opóźnienie, magnes, czas życia | 6 |
| `src/progression/dust_dropper.gd` | `DustDropper`: zniszczony eksponat → drobiny Pyłu | 6 |
| `src/player/flashlight_battery.gd` | `FlashlightBattery`: bateria latarki (czysta logika) | 7 |
| `src/progression/upgrade_catalog.gd` | `UpgradeCatalog`: 10 ulepszeń / 16 poziomów jako dane | 8 |
| `src/progression/upgrade_effects.gd` | `UpgradeEffects`: poziomy → liczby gracza i kopii `WeaponData` | 8 |
| `src/haven/haven.gd` | `Haven`: strefa przystani, rejestr, ściany tylko dla wrogów | 9 |
| `src/haven/upgrade_terminal.gd` | `UpgradeTerminal`: terminal (Interactable + model) | 9 |
| `src/ui/ui_theme.gd` | `UiTheme`: kolory, czcionki, style paneli i przycisków | 9 |
| `src/ui/upgrade_menu.gd` | `UpgradeMenu`: menu ulepszeń (klawiatura + mysz, pauza) | 9 |
| `src/progression/night_rules.gd` | `NightRules`: śmierć, latarka, przystań, start nocy | 10 |
| `src/progression/loadout.gd` | `Loadout`: bronie i amunicja startowa nocy | 10 |
| `src/game/dropped_lantern.gd` | `DroppedLantern`: latarka z Pyłem w miejscu śmierci | 10 |
| `src/ui/death_screen.gd` | `DeathScreen`: wyciemnienie, „23:00”, budzik | 10 |
| `src/core/scene_flow.gd` | autoload `SceneFlow`: zmiana scen z wyciemnieniem | 11 |
| `src/ui/main_menu.gd` + `.tscn` | menu główne (scena główna projektu) | 11 |
| `src/ui/pause_menu.gd` | `PauseMenu`: Esc, pauza, właściciel pauzy w grze | 11 |
| `src/ui/options_menu.gd`, `src/ui/option_rows.gd` | `OptionsMenu` + wiersze (suwak, wybór, przełącznik) | 11 |
| `src/ui/confirm_dialog.gd` | `ConfirmDialog`: „Nadpisać zapis?” | 11 |
| `src/ui/demo_end.gd` + `.tscn` | ekran końca dema (zaślepka ze statystykami) | 11 |
| `src/level/sandbox_level.gd` | `SandboxLevel extends Level`: hala z 1a + kanciapa | 11 |
| `src/level/weapon_pickup.gd` | `WeaponPickup`: broń do podniesienia (zostaje na zawsze) | 11 |
| `src/game/museum.gd` + `.tscn` | `Museum`: scena gry, noc, śmierć, przystań, wyjście | 11 |
| `tools/run_sandbox.sh` | uruchomienie piaskownicy 1a (dev) | 11 |
| `tools/sfx/gen_sfx.py` | + dust, lantern, buy, deny, interact, alarm, ui_move/confirm/back | 12 |
| `tests/integration/test_night_loop.gd` | test całej pętli bez okna | 13 |
| `tests/scenarios/scenario_runner.gd` | + scenariusz `ui_2a` (zrzuty do `tests/_out/2a/`) | 13 |

Zmieniane pliki 1a: `project.godot`, `.gitignore`, `src/core/{events,game_input,layers}.gd`, `src/player/{player,shake_camera}.gd`, `src/weapons/{weapon_data,weapon_state,weapon_holder}.gd`, `src/weapons/data/*.tres` (tylko `display_name` → klucz), `src/enemies/{enemy,wax_figure,wolf,knight}.gd`, `src/ui/hud.gd`, `src/arena/sandbox.gd`, `src/fx/sfx.gd`, `src/level/level.gd` (jedno pole, wstecznie zgodne), `tests/test_runner.gd`, `tests/unit/test_game_input.gd`, `tests/integration/test_sandbox.gd`, `tools/run_tests.sh`, `tools/run_scenario.sh`, `Graj.bat`.

## Kolejność i zależności

Zadania idą po kolei: 2 (ustawienia, ścieżki zapisu) → 3 (lokalizacja) → 4 (stan i zapis) → 5 (interakcja) → 6 (Pył) → 7 (bateria) → 8 (ulepszenia) → 9 (przystań, terminal, motyw UI) → 10 (śmierć, latarka) → 11 (sceny, menu, `Museum`) → 12 (dźwięki) → 13 (test pętli, zrzuty, eksport). Dźwięki powstają w zadaniu 12; wcześniej kod woła je po nazwie (`Sfx` pomija brakujące pliki), a testy „czy zagrał dźwięk” dochodzą w zadaniu 12.

---

### Zadanie 1: Ten plan

Plik: `docs/superpowers/plans/2026-09-30-etap-2a-petla-nocy.md`. Commit: „Stage 2a plan: night loop systems”.

---

### Zadanie 2: Ustawienia (`Settings`), ścieżki zapisu

**Pliki:** utwórz `src/core/save_paths.gd`, `src/core/save_file.gd`, `src/core/settings_data.gd`, `src/core/settings.gd`; zmień `project.godot` (autoload `Settings` po `GameInput`, tryb okna startowy = pełny ekran), `src/player/player.gd`, `src/player/shake_camera.gd`, `src/arena/sandbox.gd` (bez własnego F11), `tests/test_runner.gd` (czyszczenie katalogu testowego, reset ustawień), `tools/run_scenario.sh` (`--windowed`), `.gitignore` bez zmian (`tests/_out/` już jest).

**Interfejsy:**

```gdscript
class_name SavePaths
static var override_dir: String = ""
static func dir() -> String                # absolutna ścieżka katalogu zapisu (tworzy go)
static func save_file() -> String          # dir()/save.json
static func settings_file() -> String      # dir()/settings.cfg
static func is_test_run() -> bool          # scena startowa z res://tests/ albo --save-dir/NZ_SAVE_DIR
static func clear_test_dir() -> void       # tylko katalog testowy

class_name SaveFile
static func write_text(path: String, text: String) -> bool   # path.tmp → rename (atomowo)
static func read_text(path: String) -> String                # "" gdy brak
static func quarantine(path: String) -> void                 # kopia path.bad

class_name SettingsData extends RefCounted
enum WindowMode { WINDOWED, MAXIMIZED, FULLSCREEN, EXCLUSIVE }
enum Upscaler { BILINEAR, FSR, FSR2 }
const FOV_MIN := 70.0, FOV_MAX := 110.0, SENSITIVITY_MIN := 0.1, SENSITIVITY_MAX := 3.0
const FPS_CHOICES: Array[int] = [0, 30, 60, 120, 144, 165, 240]   # 0 = bez limitu
const RENDER_SCALE_MIN := 0.5, RENDER_SCALE_MAX := 1.0
const VOLUME_KEYS := {&"volume_master": &"Master", &"volume_sfx": &"SFX", ...}
var mouse_sensitivity := 1.0, invert_y := false, fov := 70.0
var volume_master := 1.0, volume_sfx := 1.0, volume_music := 1.0, volume_ambience := 1.0, volume_ui := 1.0
var window_mode := WindowMode.FULLSCREEN, vsync := true, max_fps := 0
var render_scale := 1.0, upscaler := Upscaler.BILINEAR, language := "pl", show_fps := false
static func keys() -> Array[StringName]
func get_value(key: StringName) -> Variant
func set_value(key: StringName, value: Variant) -> void      # z sanitize (clamp, typy)
func sanitize() -> void
func to_config(cfg: ConfigFile) -> void
func from_config(cfg: ConfigFile) -> void                    # złe typy → domyślne

# autoload "Settings"
class_name GameSettings extends Node
signal settings_changed(key: StringName)
const BASE_TURN := 0.0022                                   # rad na piksel przy czułości 1,0
var data: SettingsData
func get_value(key: StringName) -> Variant
func set_value(key: StringName, value: Variant, persist: bool = true) -> void
func save() -> bool
func reload() -> void
func reset_to_defaults(persist: bool = false) -> void
func apply_all() -> void
func toggle_fullscreen() -> void                             # F11 (akcja toggle_fullscreen)
func mouse_turn_per_pixel() -> float
```

**Zachowanie:** głośność suwaka `v` (0–1) ustawia szynę na `bazowe_dB_z_układu + linear_to_db(v)` (SFX zachowuje zapas −4 dB), `v = 0` wycisza szynę. Tryb okna, V-Sync, limit klatek i skala renderu (`scaling_3d_mode` BILINEAR/FSR/FSR2 + `scaling_3d_scale`) stosowane od razu; ustawienia okna pomijane bez ekranu (headless) i w uruchomieniach testowych (scenariusz sam ustawia okno). `Player` przy starcie i na `settings_changed` bierze czułość (`BASE_TURN × czułość`), odwrócenie Y i FOV (`ShakeCamera.base_fov`). F11 obsługuje wyłącznie `Settings` (przełącza pełny ekran ↔ poprzedni tryb okienkowy i zapisuje) — piaskownica traci własną obsługę.

**Testy:**
- `tests/unit/test_settings_data.gd`: `test_defaults_match_the_design` (FOV 70, czułość 1, bez odwrócenia, głośności 1, pełny ekran, V-Sync, bez limitu, skala 1, język pl), `test_values_are_clamped_to_their_ranges` (FOV 200→110, 10→70, czułość −1→0,1, głośność 3→1, skala 0,1→0,5, nieznany tryb okna → domyślny), `test_config_round_trip_keeps_every_value`, `test_wrong_types_in_the_file_fall_back_to_defaults`, `test_unknown_keys_are_rejected`.
- `tests/unit/test_save_paths.gd`: `test_test_runs_never_use_the_real_save_dir` (katalog zawiera `tests/_out/saves`), `test_atomic_write_replaces_the_file_and_leaves_no_tmp`, `test_quarantine_keeps_a_bad_copy`.
- `tests/integration/test_settings.gd`: `test_volume_is_relative_to_the_bus_layout`, `test_zero_volume_mutes_the_bus`, `test_changes_emit_settings_changed`, `test_camera_fov_follows_the_setting_live`, `test_turn_speed_follows_sensitivity_and_invert_y` (ruch myszy przez `Player.look()`), `test_settings_are_saved_next_to_the_save_file`, `test_render_scale_and_upscaler_reach_the_viewport`, `test_toggle_fullscreen_flips_the_window_mode_setting`.

Commit: „Settings: live options, portable save paths, F11 through Settings”.

---

### Zadanie 3: Lokalizacja

**Pliki:** utwórz `locale/strings.csv` (+ `.import` po imporcie; wygenerowane `*.translation` w `.gitignore`); zmień `project.godot` (`[internationalization] locale/translations`, `locale/fallback="pl"`), `src/ui/hud.gd` (wszystkie teksty przez klucze), `src/weapons/data/*.tres` (`display_name` = klucz, np. `WEAPON_PISTOL`), `src/core/settings.gd` (język → `TranslationServer.set_locale`).

**Zachowanie:** klucze WIELKIMI_LITERAMI z prefiksem modułu (`HUD_`, `MENU_`, `OPT_`, `UPG_`, `PROMPT_`, `DEATH_`, `PAUSE_`, …). Angielski pełny (nie kopia polskiego). Teksty z liczbami używają `%d`/`%s`. Domyślny język `pl` (z ustawień, nie z systemu).

**Testy** `tests/unit/test_localization.gd`: `test_every_key_has_polish_and_english_text`, `test_polish_is_the_default_locale` (`tr("MENU_NEW_GAME") == "Nowa gra"`), `test_english_switches_the_texts`, `test_every_key_used_in_code_exists` (skan `src/**/*.gd` i `.tres` po `tr("…")`/`_key = "…"`/`display_name`), `test_hud_help_is_translated` (tekst pomocy ≠ klucz).

Commit: „Localization: strings.csv (pl/en), HUD and weapon names through tr()”.

---

### Zadanie 4: Zapis, `GameState`, `RunState`

**Pliki:** utwórz `src/state/game_state.gd`, `src/state/run_state.gd`; zmień `src/core/save_file.gd` (JSON), `project.godot` (autoloady `GameState`, `RunState`), `tests/test_runner.gd` (reset obu między testami).

**Interfejsy:**

```gdscript
# autoload "GameState"
class_name PersistentState extends Node
signal saved
signal upgrade_bought(id: StringName, level: int)
const VERSION := 1
const DEFAULT_HAVEN := &"security"
var night := 1, seed_base := 0
var upgrades: Dictionary = {}          # StringName -> int
var weapons: Array[StringName] = []    # znalezione (pistol, shotgun); pięści i paralizator zawsze
var pistol_key := false
var secrets: Array[StringName] = [], notes: Array[StringName] = []
var havens: Array[StringName] = [DEFAULT_HAVEN], start_haven := DEFAULT_HAVEN
var lantern := {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
var stats := {"deaths": 0, "nights": 0, "dust_earned": 0, "play_time": 0.0, "bosses": 0}
var demo_complete := false
var run_dust := 0                      # niesiony Pył z chwili ostatniego zapisu (patrz Odstępstwa)
var file_path := ""                    # "" = SavePaths.save_file() (testy podają własną)
var last_load_error := ""              # "", "missing", "corrupt"
func new_game() -> void
func reset() -> void                   # jak new_game, bez losowania ziarna i bez dysku (testy)
func load_game() -> bool
func save_game() -> bool
func has_save() -> bool
func night_seed() -> int               # deterministyczny mix(seed_base, night)
func upgrade_level(id: StringName) -> int
func buy_upgrade(id: StringName, run: NightState) -> bool     # zadanie 8
func has_weapon(id: StringName) -> bool
func add_weapon(id: StringName) -> void
func discover_haven(id: StringName) -> void
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void                       # tolerancyjny: złe typy → domyślne

# autoload "RunState"
class_name NightState extends Node
signal dust_changed(total: int, delta: int)
enum CrystalPhase { DORMANT, PULSING, FLYING, EMBEDDED, BROKEN }
var dust := 0, artifacts: Array[StringName] = [], modifier := &"none"
var fuses := 0, fuses_carried := 0, crystal_phase := CrystalPhase.DORMANT
var rng := RandomNumberGenerator.new(), time := 0.0, running := false
var multipliers: Dictionary = {}       # źródło (&"full_moon", &"coin") -> mnożnik Pyłu
func begin_night(seed: int) -> void
func end_night() -> void
func reset() -> void
func dust_multiplier() -> float
func scaled_dust(amount: int) -> int                    # ceil(amount × mnożniki)
func add_dust(amount: int, multiplied: bool = true) -> int
func spend_dust(amount: int) -> bool
func has_artifact(id: StringName) -> bool
func take_unsaved_time() -> float                       # czas gry od ostatniego zapisu
```

**Zachowanie:** zapis JSON z `"version": 1`, atomowo (`save.json.tmp` → rename). Brak pliku → `has_save() == false`. Uszkodzony plik (JSON nie parsuje się, korzeń nie jest słownikiem, brak/zła wersja) → kopia `save.json.bad`, gra startuje od nowa (`new_game()`), `last_load_error = "corrupt"`, bez wysypania. Gdy `save.json` brak, a `save.json.tmp` jest poprawny (przerwany zapis) → odczyt z `.tmp`. Pola o złych typach → wartości domyślne; poziomy ulepszeń przycinane do katalogu (zadanie 8). Ziarno nocy: mieszanie typu splitmix64 z `seed_base` i `night` (niezależne od wersji silnika).

**Testy:**
- `tests/unit/test_game_state.gd`: `test_new_game_defaults`, `test_save_then_load_restores_an_identical_state`, `test_save_is_versioned_json`, `test_save_leaves_no_tmp_file`, `test_corrupt_file_is_kept_as_bad_and_a_fresh_game_starts`, `test_wrong_types_fall_back_to_defaults`, `test_missing_file_means_no_save`, `test_interrupted_save_is_recovered_from_tmp`, `test_night_seed_is_deterministic_and_differs_per_night`, `test_new_game_draws_a_new_seed_base`.
- `tests/unit/test_run_state.gd`: `test_begin_night_resets_and_seeds_the_rng`, `test_add_dust_applies_multipliers_rounding_up`, `test_multipliers_stack`, `test_raw_dust_ignores_multipliers`, `test_spend_dust_refuses_when_short`, `test_dust_changed_reports_total_and_delta`, `test_time_runs_only_during_a_night`.

Commit: „GameState/RunState: versioned atomic JSON save, corruption-safe load, night seed”.

---

### Zadanie 5: Interakcja

**Pliki:** utwórz `src/interaction/interactable.gd`, `src/player/interactor.gd`; zmień `src/core/game_input.gd` (`interact` = E, `key_label(action)`), `src/core/layers.gd` (`INTERACT := 64`), `project.godot` (`3d_physics/layer_7="interact"`), `src/player/player.gd`, `src/ui/hud.gd` (podpowiedź środek-dół), `tests/unit/test_game_input.gd`.

```gdscript
class_name Interactable extends Area3D
signal interacted(by: Node)
@export var prompt_key: String = ""
var enabled := true
func prompt() -> String                          # tr(prompt_key)
func can_interact(by: Node) -> bool              # enabled (nadpisywalne)
func interact(by: Node) -> void                  # domyślnie emituje interacted
func add_box(size: Vector3, offset := Vector3.ZERO) -> void

class_name Interactor extends Node
signal focus_changed(target: Interactable)
const REACH := 2.2
var focus: Interactable = null
static func probe(space: PhysicsDirectSpaceState3D, from: Vector3, forward: Vector3, exclude: Array[RID] = []) -> Interactable
func update(space, from: Vector3, forward: Vector3) -> void
func try_interact(by: Node) -> bool
```

**Zachowanie:** strażnik co klatkę fizyki rzuca promień 2,2 m ze środka kamery w maskę `WORLD | INTERACT` (ściana zasłania). Fokus tylko żywy strażnik i tylko przy wejściu z gry (nie w menu). E wywołuje `interact(player)`. HUD pokazuje „[E] …” (etykieta klawisza z mapy wejścia, więc zgadza się z układem klawiatury).

**Testy** `tests/integration/test_interaction.gd`: `test_interactable_sits_on_the_interact_layer`, `test_guard_focuses_an_interactable_within_reach`, `test_nothing_is_focused_beyond_reach`, `test_walls_block_interaction`, `test_interact_key_calls_interact_with_the_guard`, `test_disabled_interactable_is_ignored`, `test_dead_guard_cannot_interact`, `test_hud_shows_the_prompt_with_the_key`. W `test_game_input.gd` dochodzi `interact`.

Commit: „Interaction: E key, Interactable areas, guard's 2.2 m probe, HUD prompt”.

---

### Zadanie 6: Pył

**Pliki:** utwórz `src/progression/dust_rules.gd`, `src/progression/dust_mote.gd`, `src/progression/dust_dropper.gd`; zmień `src/enemies/enemy.gd` (`@export var dust_value`), `wax_figure.gd` (3), `wolf.gd` (4), `knight.gd` (8), `src/core/events.gd` (`dust_collected(amount: int)`), `src/ui/hud.gd` (licznik prawy górny róg z „+n”).

```gdscript
class_name DustRules
const FINISHER_MULTIPLIER := 1.5
const MAX_MOTES := 4
static func kill_value(base: int, finisher: bool) -> int      # ceil(base × 1,5) przy dobiciu
static func split(total: int) -> Array[int]                    # 1–4 drobiny, suma = total

class_name DustMote extends Node3D
signal collected(value: int)
const MAGNET_DELAY := 0.6, MAGNET_RADIUS := 6.0, COLLECT_RADIUS := 0.7
var value := 1, target: Node3D, lifetime := 30.0

class_name DustDropper extends Node
var target: Node3D                   # strażnik
var parent: Node                     # gdzie trafiają drobiny
```

**Zachowanie:** zniszczony eksponat → `total = RunState.scaled_dust(DustRules.kill_value(dust_value, finisher))` (mnożniki nocy/artefaktów przez `RunState`) → `split(total)` drobin, które wyskakują łukiem i unoszą się. Po 0,6 s drobina, której strażnik (żywy) jest bliżej niż 6 m, leci do jego piersi z przyspieszeniem; w promieniu 0,7 m dodaje `value` do `RunState` (bez ponownych mnożników), emituje `Events.dust_collected`, gra `dust`. Po 30 s znika (ostatnie 2 s miga). HUD: licznik z ikoną, „+n” wyskakuje i gaśnie, licznik lekko pulsuje.

**Testy:**
- `tests/unit/test_dust_rules.gd`: `test_exhibits_carry_their_dust_values` (woskowa 3, wilk 4, rycerz 8), `test_finisher_multiplies_and_rounds_up` (3→5, 4→6, 8→12), `test_split_gives_one_to_four_motes_that_sum_up`, `test_night_multipliers_apply_after_the_finisher`.
- `tests/integration/test_dust.gd`: `test_destroyed_exhibit_drops_its_dust_as_motes`, `test_motes_wait_before_flying`, `test_motes_fly_to_a_guard_within_six_metres`, `test_motes_ignore_a_distant_guard`, `test_motes_expire`, `test_finisher_kill_drops_more_dust`, `test_hud_shows_the_total_and_a_gain_pop`.

Commit: „Dust: exhibit values, finisher bonus, magnetic motes, HUD counter”.

---

### Zadanie 7: Bateria latarki

**Pliki:** utwórz `src/player/flashlight_battery.gd`; zmień `src/player/player.gd`, `src/ui/hud.gd` (pasek pod wytrzymałością).

```gdscript
class_name FlashlightBattery extends RefCounted
const BASE_CAPACITY := 120.0          # sekundy świecenia
const RECHARGE_RATIO := 0.5           # ładowanie 2× wolniej niż rozładowanie
const FLICKER_BELOW := 0.15
const RELIGHT_AT := 0.05              # pusta bateria: włączenie dopiero od 5%
var capacity := BASE_CAPACITY, charge := BASE_CAPACITY, on := false
func tick(delta: float) -> void
func toggle() -> bool
func set_on(value: bool) -> bool
func fraction() -> float
func is_flickering() -> bool
func set_capacity(seconds: float) -> void           # zachowuje ułamek naładowania
```

**Zachowanie:** włączona zużywa 1 s/s, wyłączona ładuje 0,5 s/s. Rozładowana gaśnie sama; włączenie możliwe od 5%. Poniżej 15% światło migocze (energia z szumem). Pasek w HUD miga na czerwono poniżej 15%.

**Testy** `tests/unit/test_flashlight_battery.gd`: `test_full_battery_lasts_120_seconds`, `test_recharges_twice_as_slow_when_off`, `test_empty_battery_turns_the_light_off_until_recharged`, `test_flickers_below_15_percent`, `test_capacity_change_keeps_the_charge_fraction`. W `tests/integration/test_player.gd`: `test_flashlight_key_uses_the_battery`, `test_drained_flashlight_goes_dark`.

Commit: „Flashlight battery: 120 s, slow recharge, low-charge flicker, HUD bar”.

---

### Zadanie 8: Ulepszenia (10 ulepszeń, 16 poziomów)

**Pliki:** utwórz `src/progression/upgrade_catalog.gd`, `src/progression/upgrade_effects.gd`; zmień `src/weapons/weapon_data.gd` (pola `chain_range`, `alt_pellets`, `alt_damage`, `alt_spread_deg`, `alt_weak_point_multiplier`, `alt_name`), `weapon_state.gd` (`base`, `alt_data`, `use_alt`, `apply_upgrades`, `shot_data`, `toggle_alt`), `weapon_holder.gd` (ulepszenia kopii, łańcuch paralizatora, przytrzymanie R), `src/player/player.gd` (`apply_upgrades`), `src/state/game_state.gd` (`buy_upgrade`, przycinanie poziomów), `src/core/events.gd` (`upgrade_bought`).

```gdscript
class_name UpgradeCatalog
class Entry:
	var id: StringName, name_key: String, desc_key: String
	var category: StringName            # &"guard", &"taser", &"pistol", &"shotgun"
	var prices: Array[int]
	func max_level() -> int
static func all() -> Array[Entry]
static func find(id: StringName) -> Entry
static func max_level(id: StringName) -> int
static func price(id: StringName, current_level: int) -> int     # -1 = maks.

class_name UpgradeEffects
static func level(levels: Dictionary, id: StringName) -> int
static func max_health(levels) -> float          # 100 + 20/poz.
static func stamina_max(levels) -> float         # 100 + 20/poz.
static func stamina_regen(levels) -> float       # 30 × (1 + 0,15/poz.)
static func battery_capacity(levels) -> float    # 120 × (1 + 0,5/poz.)
static func fist_damage_multiplier(levels) -> float   # 1 + 0,4/poz.
static func finisher_heal(levels) -> float       # 15 × (1 + 0,25/poz.)
static func apply_to_weapon(data: WeaponData, levels: Dictionary) -> void
static func alt_profile(data: WeaponData) -> WeaponData          # null bez slugów
```

| id | Efekt na kopii danych |
|---|---|
| `taser_charge` | `battery_recharge_per_sec × 1,6` |
| `taser_chain` | `chain_range = 5` — łuk przeskakuje na najbliższego innego wroga (widocznego z miejsca trafienia) w 5 m, te same obrażenia i ogłuszenie |
| `pistol_damage` | `damage × 1,3` |
| `pistol_mag` | `magazine_size = 18` |
| `shotgun_spread` | `spread_deg × 0,65` |
| `shotgun_slug` | `alt_pellets = 1`, `alt_damage = 70`, `alt_spread_deg = 0`, `alt_weak_point_multiplier = 2` |
| `fists` | pięści: `damage × (1 + 0,4/poz.)`; strażnik: leczenie z dobicia `× (1 + 0,25/poz.)` |

**Zachowanie:** `WeaponState` trzyma nietknięty `base` (.tres) i kopię `data = base.duplicate()` z nałożonymi ulepszeniami; zakup w trakcie nocy przebudowuje kopie posiadanych broni. Strzelba ze slugiem: krótkie R przeładowuje, **przytrzymanie R (0,35 s)** przełącza śrut/slug — naboje z magazynka wracają do zapasu i zaczyna się przeładowanie; oba ładunki biorą ten sam zapas łusek. `GameState.buy_upgrade(id, run)`: cena z katalogu, odmowa przy braku Pyłu lub maks. poziomie, `run.spend_dust`, poziom +1, zapis gry, `Events.upgrade_bought`.

**Testy:**
- `tests/unit/test_upgrade_catalog.gd`: `test_ten_upgrades_with_sixteen_levels`, `test_prices_match_the_design` (cała tabela), `test_price_is_minus_one_at_max_level`, `test_names_and_descriptions_are_translated`.
- `tests/unit/test_upgrade_effects.gd`: `test_guard_numbers_per_level`, `test_weapon_copies_get_upgrades_and_the_tres_stays_untouched`, `test_slug_builds_a_one_ray_profile`, `test_no_upgrades_means_base_numbers`.
- `tests/unit/test_game_state.gd` (dopisane): `test_buying_spends_dust_and_raises_the_level`, `test_buying_is_refused_without_enough_dust`, `test_buying_is_refused_at_max_level`, `test_buying_saves_the_game`, `test_loaded_levels_are_clamped_to_the_catalog`.
- `tests/unit/test_weapon_state.gd` (dopisane): `test_apply_upgrades_rebuilds_the_copy_from_the_base`, `test_toggle_alt_unloads_and_reloads`, `test_toggle_alt_needs_the_slug_upgrade`.
- `tests/integration/test_upgrades.gd`: `test_guard_gets_health_stamina_battery_and_finisher_upgrades`, `test_taser_arc_jumps_to_a_second_enemy_within_5_m`, `test_slug_fires_one_heavy_ray`, `test_holding_reload_toggles_slugs_and_tapping_reloads`, `test_pistol_magazine_upgrade_reloads_to_18`, `test_upgrades_bought_mid_night_reach_owned_weapons`, `test_stronger_fists_hit_harder`.

Commit: „Upgrades: catalog of 16 levels, guard stats, per-owner weapon copies, taser chain, slugs”.

---

### Zadanie 9: Przystań i terminal ulepszeń

**Pliki:** utwórz `src/haven/haven.gd`, `src/haven/upgrade_terminal.gd`, `src/ui/ui_theme.gd`, `src/ui/upgrade_menu.gd`; zmień `src/core/layers.gd` (`ENEMY_BLOCK := 128`), `project.godot` (`layer_8="enemy_block"`), `src/enemies/enemy.gd` (maska `ENEMY_BLOCK`, cel w przystani = odwrót do miejsca startu), `src/core/game_input.gd` (stos menu: `push_ui/pop_ui/gameplay_input()`).

```gdscript
class_name Haven extends Area3D
signal guard_entered(player: Player)
var id: StringName, bounds: AABB
static func make(id: StringName, bounds: AABB) -> Haven
static func shelters(point: Vector3) -> bool
static func at(point: Vector3) -> Haven
func contains(point: Vector3) -> bool

class_name UpgradeTerminal extends Interactable
signal opened(by: Node)

class_name UiTheme
const ACCENT, TEXT, MUTED, DISABLED, DANGER, DUST, PANEL_BG, ...
static func theme() -> Theme
static func panel(style := "default") -> StyleBoxFlat
static func title_font() -> Font
static func body_font() -> Font
static func label(text: String, size: int, color := TEXT) -> Label

class_name UpgradeMenu extends CanvasLayer
signal closed
func open(game: PersistentState, run: NightState) -> void
func close() -> void
func select(index: int) -> void
func selected_id() -> StringName
func buy_selected() -> bool
var last_feedback: StringName           # &"buy" / &"deny" (testy)
```

**Zachowanie:** `Haven` to strefa (AABB) z kolizją na gracza; na ścianach AABB stoją niewidzialne ściany w warstwie `ENEMY_BLOCK` (wrogowie je mają w masce, strażnik, promienie broni i odłamki nie). Gdy cel wroga stoi w przystani: wróg go „nie widzi”, nie atakuje i wraca do miejsca, w którym powstał. Terminal: interakcja otwiera `UpgradeMenu`: lista pogrupowana (Strażnik / Paralizator / Pistolet / Strzelba), wiersz = nazwa, kropki poziomów, cena lub „MAKS.”; panel szczegółów: opis, poziom, efekt, cena, niesiony Pył; stany: posiadane, maks., za drogie (cena na czerwono), broń jeszcze nie znaleziona (podpowiedź). Nawigacja: strzałki/W/S/kółko/mysz, Enter/Spacja/klik = kup, Esc/E = zamknij. Otwarte menu pauzuje drzewo i zdejmuje wejście z gry (stos `GameInput`). Dźwięki `buy`/`deny`/`ui_move`.

**Testy:**
- `tests/integration/test_haven.gd`: `test_haven_shelters_points_inside_only`, `test_guard_entering_emits_guard_entered`, `test_enemies_cannot_walk_into_the_haven`, `test_enemies_leave_a_sheltered_guard_alone`, `test_bullets_and_the_guard_pass_the_enemy_walls`.
- `tests/integration/test_upgrade_menu.gd`: `test_terminal_opens_the_menu_and_pauses`, `test_menu_lists_every_upgrade_with_its_price`, `test_buying_with_enough_dust`, `test_buying_is_denied_when_short`, `test_maxed_upgrade_shows_max_and_is_denied`, `test_keyboard_moves_the_selection`, `test_closing_unpauses_and_returns_input`.

Commit: „Haven zone and upgrade terminal with a navigable, pausing menu”.

---

### Zadanie 10: Śmierć i cykl nocy

**Pliki:** utwórz `src/progression/night_rules.gd`, `src/progression/loadout.gd`, `src/game/dropped_lantern.gd`, `src/ui/death_screen.gd`; zmień `src/player/player.gd` (`last_floor_position`), `src/core/events.gd` (`lantern_recovered`).

```gdscript
class_name NightRules
static func on_death(game: PersistentState, run: NightState, drop_at: Vector3) -> void
static func recover_lantern(game: PersistentState, run: NightState) -> int
static func enter_haven(game: PersistentState, run: NightState, haven_id: StringName) -> void
static func start_night(game: PersistentState, run: NightState) -> void
static func save_progress(game: PersistentState, run: NightState) -> bool   # run_dust + czas gry

class_name Loadout
const START_AMMO := {&"pistol": 24, &"shotgun": 6}     # zapas; magazynek pełny
static func equip_night_start(player: Player, game: PersistentState) -> void
static func grant(player: Player, id: StringName, game: PersistentState) -> WeaponState

class_name DroppedLantern extends Area3D
signal recovered(amount: int)
var dust := 0

class_name DeathScreen extends CanvasLayer
signal finished
const FADE_TIME := 1.2
func play(next_night: int, dropped_dust: int) -> void
```

**Zachowanie:** śmierć: niesiony Pył → nowa latarka w ostatniej pozycji strażnika na podłodze (poprzednia niepodniesiona przepada; przy 0 Pyłu latarki nie ma), `night += 1`, `stats.deaths/nights += 1`, zapis. Ekran śmierci: wyciemnienie 1,2 s, duże „23:00”, „Noc N”, linijka o latarce, budzik; po ok. 3,5 s `finished`. Latarka: ciepłe światło o dużej energii we mgle wolumetrycznej, świecąca szybka, delikatny słup światła, dotyk żywego strażnika zwraca Pył (bez mnożników), `Events.lantern_recovered`. Start nocy: `RunState.begin_night(night_seed())`, niesiony Pył z zapisu, pełne zdrowie i wytrzymałość, pięści + paralizator + znalezione bronie, amunicja: pistolet pełny magazynek + 24, strzelba pełny + 6, ulepszenia nałożone.

**Testy:**
- `tests/unit/test_night_rules.gd`: `test_death_moves_carried_dust_into_the_lantern`, `test_an_older_lantern_is_lost`, `test_no_lantern_without_dust`, `test_death_advances_the_night_and_counts_it`, `test_death_saves_the_game`, `test_lantern_returns_its_dust_once`, `test_entering_a_haven_saves_carried_dust_and_sets_the_start`, `test_start_night_seeds_the_run_and_restores_carried_dust`.
- `tests/integration/test_loadout.gd`: `test_new_guard_has_fists_and_taser_only`, `test_found_weapons_start_with_design_ammo`, `test_magazine_upgrade_starts_full_at_18`.
- `tests/integration/test_lantern.gd`: `test_touching_the_lantern_returns_the_dust`, `test_dead_guard_does_not_pick_it_up`, `test_lantern_glows_through_fog`.
- `tests/integration/test_death_screen.gd`: `test_fades_in_then_shows_the_clock`, `test_finishes_after_the_alarm`.
- `tests/integration/test_player.gd`: `test_last_floor_position_follows_the_ground`.

Commit: „Death and night cycle: dropped lantern, 23:00 screen, night start loadout”.

---

### Zadanie 11: Przepływ scen i menu, `Museum`

**Pliki:** utwórz `src/core/scene_flow.gd`, `src/ui/main_menu.gd` + `.tscn`, `src/ui/pause_menu.gd`, `src/ui/options_menu.gd`, `src/ui/option_rows.gd`, `src/ui/confirm_dialog.gd`, `src/ui/demo_end.gd` + `.tscn`, `src/level/sandbox_level.gd`, `src/level/weapon_pickup.gd`, `src/game/museum.gd` + `.tscn`, `tools/run_sandbox.sh`; zmień `project.godot` (scena główna = menu, autoload `SceneFlow`), `src/core/game_input.gd` (`release_mouse` → `pause`, własność kursora), `src/player/player.gd` (bez obsługi kursora; ruch i rozglądanie tylko z wejściem z gry), `src/weapons/weapon_holder.gd` (to samo), `src/arena/sandbox.gd` (menu pauzy), `src/level/level.gd` (+`haven_zones`), `Graj.bat`, `tests/integration/test_sandbox.gd`, `tests/scenarios/scenario_runner.gd` (`GameInput.capture_allowed`).

```gdscript
# autoload "SceneFlow"
const MAIN_MENU := "res://src/ui/main_menu.tscn", MUSEUM := "res://src/game/museum.tscn"
const SANDBOX := "res://src/arena/sandbox.tscn", DEMO_END := "res://src/ui/demo_end.tscn"
const FADE := 0.25
signal changed(path: String)
func goto(path: String) -> void
var busy := false

# GameInput (dopisane)
var capture_allowed := true            # zastępuje Player.capture_mouse (scenariusze: false)
func push_ui(owner: Object) -> void
func pop_ui(owner: Object) -> void
func top_ui() -> Object
func clear_ui() -> void
func gameplay_input() -> bool          # true, gdy żadne menu nie trzyma wejścia
func set_gameplay_scene(active: bool) -> void

class_name PauseMenu extends CanvasLayer
signal quit_requested
func open() -> void
func close() -> void
var is_open := false

class_name OptionsMenu extends Control
signal closed

class_name SandboxLevel extends Level      # player_start w kanciapie, haven_spots/haven_zones, sloty, łupy, bronie

class_name WeaponPickup extends Interactable
var weapon_id: StringName

class_name Museum extends Node3D
signal next_night_requested            # gdy Museum nie jest bieżącą sceną (testy)
signal quit_requested
var level: Level, player: Player, hud: Hud, pause_menu: PauseMenu
func build_level() -> Level            # 2b podmienia tu SandboxLevel na LobbyLevel
func quit_to_menu() -> void
```

**Zachowanie:** menu główne jest sceną główną: tytuł „NOCNA ZMIANA”, „Kontynuuj” (tylko z zapisem), „Nowa gra” (przy istniejącym zapisie pyta o nadpisanie), „Opcje”, „Wyjście”; uszkodzony zapis → komunikat o kopii `.bad`. `SceneFlow` wyciemnia (0,25 s), zmienia scenę, odpauzowuje drzewo, czyści stos menu, rozjaśnia. **Kursor ma jednego właściciela — `GameInput`**: przechwycony tylko w scenie gry, gdy żadne menu nie trzyma wejścia; menu pauzy, terminal i ekran śmierci trzymają wejście przez `push_ui/pop_ui`; ruch, rozglądanie i bronie są wtedy zablokowane. Esc: pauza (drzewo zatrzymane) z „Wznów / Opcje / Wyjdź do menu”; utrata fokusu okna otwiera pauzę. Opcje: wszystkie ustawienia z zadania 2 (+język, licznik klatek), stosowane na żywo, zapis przy wyjściu, „Przywróć domyślne”. `Museum`: buduje poziom przez `build_level()`, przystanie ze stref poziomu, terminale w `haven_spots`, strażnika w przystani startowej, eksponaty ze slotów (2a: stały wybór — zestaw 0 każdej sali; 2b: `NightDirector`), łupy z `loot_spots` (bez odradzania), latarkę z zapisu, `DustDropper`, HUD (noc, Pył, bateria, podpowiedź). Wejście do przystani → `NightRules.enter_haven` + leczenie; śmierć → `NightRules.on_death` + `DeathScreen` → nowa noc (przeładowanie sceny). Wyjście do menu i zamknięcie okna zapisują. `DemoEnd`: statystyki (noce, śmierci, czas, Pył, sekrety x/6), „Dziękujemy za grę”, powrót do menu. Piaskownica zostaje sceną deweloperską (`tools/run_sandbox.sh`).

**Testy:**
- `tests/unit/test_game_input.gd`: `pause` zamiast `release_mouse`, `test_ui_stack_blocks_gameplay_input`.
- `tests/integration/test_scene_flow.gd`: `test_scene_paths_exist`, `test_main_scene_is_the_main_menu`, `test_fade_overlay_starts_clear`.
- `tests/integration/test_main_menu.gd`: `test_title_and_buttons`, `test_continue_needs_a_save`, `test_new_game_over_a_save_asks_first`, `test_corrupt_save_shows_a_notice`, `test_keyboard_focus_starts_on_the_first_button`.
- `tests/integration/test_pause_menu.gd`: `test_escape_pauses_and_blocks_gameplay_input`, `test_resume_restores_play`, `test_guard_does_not_move_or_shoot_while_a_menu_is_open`, `test_options_open_from_pause`.
- `tests/integration/test_options_menu.gd`: `test_every_setting_has_a_row`, `test_rows_apply_changes_live`, `test_back_saves_the_settings`, `test_reset_restores_defaults`.
- `tests/integration/test_museum.gd`: `test_sandbox_level_fulfils_the_level_contract`, `test_night_starts_in_the_haven_with_fists_and_taser`, `test_exhibits_come_from_spawn_slots`, `test_saved_lantern_is_placed`, `test_entering_the_haven_heals_and_saves`, `test_weapon_pickup_is_kept_forever`, `test_quit_to_menu_saves_carried_dust`, `test_night_reload_leaves_no_nodes_behind`.
- `tests/integration/test_demo_end.gd`: `test_shows_the_stats`.
- `tests/integration/test_sandbox.gd`: dostosowany do `GameInput.capture_allowed`.

Commit: „Scene flow and menus: main menu, pause, options, demo end, Museum on the Level contract”.

---

### Zadanie 12: Dźwięki

**Pliki:** zmień `tools/sfx/gen_sfx.py` (+ `dust`, `lantern`, `buy`, `deny`, `interact`, `alarm`, `ui_move`, `ui_confirm`, `ui_back`), `src/fx/sfx.gd` (`SOUNDS`, `play_ui()` na szynie UI i działające w pauzie), menu (dźwięki UI przez `play_ui`), dodaj `assets/sfx/*.wav` nowych dźwięków.

**Zachowanie:** istniejące pliki WAV bajt w bajt bez zmian (ziarno z nazwy dźwięku; sprawdzenie: `git status` nie pokazuje zmian starych plików). Dźwięki menu na szynie `UI`, `process_mode = ALWAYS` (grają w pauzie).

**Testy:** `tests/integration/test_sfx.gd`: `test_ui_sounds_play_on_the_ui_bus_even_when_paused`; `test_upgrade_menu.gd`: `test_buy_and_deny_sounds`; `test_death_screen.gd`: `test_alarm_rings`; istniejący `test_every_game_sound_has_a_generated_file` obejmuje nowe nazwy.

Commit: „Sounds: dust chime, lantern, buy/deny, interact, alarm clock, UI clicks”.

---

### Zadanie 13: Test całej pętli, zrzuty, eksport

**Pliki:** utwórz `tests/integration/test_night_loop.gd`; zmień `tests/scenarios/scenario_runner.gd` (scenariusz `ui_2a`), `tools/run_scenario.sh` (opis), ewentualne poprawki wyglądu UI.

**Test pętli** `test_night_loop.gd :: test_full_night_loop`: nowa gra → `Museum` (jako dziecko testu) → zniszczenie eksponatów → drobiny zebrane (Pył > 0) → śmierć → latarka w zapisie z całym Pyłem, noc 2 → nowa instancja `Museum` → latarka stoi, dotknięcie zwraca Pył → wejście do przystani (zdrowie pełne, zapis) → zakup `health` przez terminal/menu → strażnik ma 120 zdrowia → zapis → nowy `PersistentState` wczytuje plik → `to_dict()` identyczny. Dodatkowo `test_reloaded_night_restores_upgrades_and_weapons`.

**Scenariusz** `bash tools/run_scenario.sh ui_2a` (okno 1920×1080, cicho): `tests/_out/2a/main_menu.png`, `options.png`, `hud.png` (Pył + podpowiedź „[E] …” przy terminalu), `terminal.png`, `death.png`, `pause.png`. Przegląd zrzutów i szlif (spójny styl: ciemne półprzezroczyste panele, mosiężny akcent, oddech). Na koniec `bash tools/export.sh` → `build/NocnaZmiana.exe` startuje w menu (test dymny bez okna).

Commit: „Night loop integration test, 2a UI screenshots and polish”.

---

## Odstępstwa od projektu

Decyzje, w których plan świadomie odchodzi od `2026-09-30-etap-2-projekt.md` (lub go doprecyzowuje), z uzasadnieniem:

1. **Niesiony Pył przeżywa wyjście do menu** (`GameState.run_dust`). Projekt każe zapisywać przy wyjściu do menu, ale nie mówi, co z niesionym Pyłem; strata Pyłu przy wyjściu byłaby karą surowszą niż śmierć (bez latarki). Zapis przy przystani/zakupie/śmierci/wyjściu utrwala aktualny niesiony Pył; po „Kontynuuj” noc jest wznawiana (patrz „Poprawki po przeglądzie 2a”, B3).
2. **Właścicielem kursora jest `GameInput` (stos menu)**, a `PauseMenu`, terminal i ekran śmierci tylko go używają. Jeden punkt decyzji zamiast łańcucha odwołań między menu; cel z sekcji 14 („jeden właściciel”, ruch zablokowany przy wolnym kursorze) spełniony. `Player.capture_mouse` → `GameInput.capture_allowed`.
3. **Brak latarki przy 0 Pyłu** — starsza latarka i tak przepada (zgodnie z zasadą), ale pusta nie jest stawiana.
4. **Domyślny tryb okna: pełny ekran** (w 1a zmaksymalizowane okno) — standard gier; zmiana w opcjach lub F11.
5. **Slug to inny ładunek tych samych łusek** (wspólny zapas), nie osobna amunicja — prościej dla gracza i dla łupów.
6. **Przystań w 2a:** wrogów zatrzymują niewidzialne ściany `ENEMY_BLOCK`, a cel w przystani jest dla nich „niewidoczny” (wracają na miejsce). Wykluczenie z siatki nawigacji przez `navigation_layers` zostaje dla 2b (prawdziwa nawigacja lobby).
7. **FOV** w opcjach to pionowe pole widzenia kamery (jak w 1a), zakres 70–110 zgodnie z projektem.
8. **Kontrakt `Level`:** dodane jedno pole `haven_zones: Dictionary` (id → AABB strefy przystani), wstecznie zgodne — bez niego `Museum` stawia strefę 6×3×6 m przed terminalem.
9. **Ulepszenia broni można kupić przed jej znalezieniem** (działają od chwili znalezienia) — menu to pokazuje.
10. **Dodatkowy punkt zapisu:** znalezienie broni (broń zostaje na zawsze, więc nie może zginąć przy awarii).
11. **Opcje rozszerzone** o język (pl/en) i licznik klatek (domyślnie wyłączony; piaskownica zawsze go pokazuje).
12. **Mnożniki Pyłu liczone przy zabiciu** (drobina niesie wartość końcową), żeby zaokrąglenie w górę nie mnożyło się na każdej drobinie.
13. **„16 ulepszeń”** z projektu to 10 ulepszeń o łącznie 16 poziomach (zgodnie z tabelą).
14. **Pauza ma czwarty przycisk „Wyjdź z gry”** (projekt: Wznów / Opcje / Wyjdź do menu) — każda droga wyjścia (menu, pauza, zamknięcie okna) idzie przez `SceneFlow.quit()` → `Sfx.quit_cleanly()` i zapisuje grę.
15. **W/S/A/D poruszają też po menu** (obok strzałek), a utrata fokusu okna otwiera pauzę — kliknięcie wracające do okna nie oddaje strzału (rozwiązuje uwagę z testów 1a).
16. **HUD:** numer nocy w lewym górnym rogu (z podpowiedzią „F1 — sterowanie”), krótki komunikat „Gra zapisana” po wejściu do przystani, licznik klatek domyślnie ukryty (opcja; piaskownica zawsze go pokazuje).

## Zmiany planu w trakcie realizacji

- **Dodatkowy commit (przegląd 1a):** `Hitscan.ray` pomija trafione obszary, które nie są `Hurtbox` (wyklucza ich RID i rzuca dalej, maks. 4 razy) — strefa na domyślnej warstwie 1 nie „połyka” już strzałów; test `test_trigger_areas_never_stop_a_shot`. Wszystkie nowe obszary 2a mają własne warstwy (INTERACT, PICKUP, maska PLAYER), nigdy WORLD.
- **Zadanie 2:** `ShakeCamera` bez zmian — `Player` ustawia `camera.base_fov` na `settings_changed`. `tools/run_scenario.sh` uruchamia okno z `--windowed` (bez mignięcia pełnym ekranem); scenariusz `perf` sam maksymalizuje okno.
- **Zadanie 3:** `*.csv text eol=lf` w `.gitattributes`; pliki `locale/*.translation` generuje import (w `.gitignore`), `strings.csv.import` jest w repo.
- **Zadanie 5:** `GameInput.key_label()` zapamiętuje nazwy klawiszy i nie pyta serwera wyświetlania w trybie headless.
- **Zadanie 8:** `WeaponHolder.reload_key(pressed, just_pressed, delta)` jest publiczne — test przytrzymania R woła je wprost (w teście bez okna nie ma prawdziwego wejścia).
- **Zadanie 9:** stos menu w `GameInput` (`push_ui/pop_ui/top_ui/gameplay_input`, `capture_allowed`, `set_gameplay_scene`) i polityka dźwięku przyszły już tu, bo menu ich potrzebowało: `Sfx.play_ui()` (szyna UI, gra w pauzie), `Sfx.stop_gameplay()`, a timery sprzątające głosy gry stoją w pauzie (głos nie jest ucinany). Ikona Pyłu to osobny `src/ui/dust_icon.gd`.
- **Zadanie 10:** doszło `Player.refill()` (zdrowie, wytrzymałość, bateria) — start nocy i przystań. `DroppedLantern` leży w warstwie PICKUP.
- **Zadanie 11:** wiersze opcji to jedna klasa `src/ui/option_row.gd` (`OptionRow`: suwak / wybór / przełącznik) zamiast `option_rows.gd`; `src/ui/ui_texts.gd` (`UiTexts`) odświeża stałe teksty menu po zmianie języka. `SceneFlow.is_running(screen)`: ekrany zbudowane w teście emitują sygnały (`navigate`, `next_night_requested`, `quit_requested`) zamiast podmieniać całe drzewo. `Museum._exit_tree()` zatrzymuje dźwięki gry i czyści `Fx` (poza `SceneFlow`, który robi to przed każdą zmianą sceny). Grupy przebudzone od startu stoją daleko od uśpionych (inaczej budziły je od razu). Kontrakt `Level` dostał `haven_zones`.
- **Scalenie z etapem 1b + 2c-1 (etap-1a-piaskownica @ 2e73f83):** popiersie ma `dust_value = 5` wprost (pole istnieje), jego `_chase_direction(delta, goal)` idzie za nową sygnaturą i przy celu w przystani po prostu wraca do domu; `DustDropper` nasłuchuje też `Events.boss_defeated` i rozsypuje `dust_value` bossa (100, przez mnożniki nocy) w `DustRules.BOSS_MOTES` = 12 drobin. Scena `boss_dev` i próbka stylu z graczem dostały menu pauzy i `GameInput.set_gameplay_scene()` (kursor ma jednego właściciela), F11 z `boss_dev` usunięty (obsługuje go `Settings`); testy i scenariusze 2c-1 używają `GameInput.capture_allowed`.
- **Zadanie 13:** zrzutów ekranu nie wykonano — właściciel pracuje na tym komputerze i nie wolno otwierać okien. Scenariusz `ui_2a` jest gotowy (bez okna działa jako próba generalna: `--headless` wypisuje „dry run” dla każdego ujęcia, bez błędów); zrzuty zrobi kontroler poleceniem `bash tools/run_scenario.sh ui_2a` → `tests/_out/2a/{main_menu,options,hud,terminal,pause,hall,death}.png`. Szlif HUD zrobiony „na sucho”: czcionka `UiTheme` we wszystkich etykietach HUD, podpowiedź interakcji jako klawisz-nakładka w mosiężnej ramce.

## Poprawki po przeglądzie 2a

Każda poprawka ma test bez okna; błędy kolejności wejścia są odtwarzane prawdziwymi zdarzeniami (`Input.parse_input_event`, `tests/integration/test_menu_input.gd`), nie wywołaniami metod.

**Rozgrywka (2a-B)**
- **B1/C2 — E zamykające terminal otwierało go ponownie; klik „Wznów” oddawał strzał.** `GameInput.pop_ui/clear_ui` zapamiętują klatkę fizyki, w której ostatnie menu puściło wejście; `gameplay_input()` jest fałszywe jeszcze przez następny krok fizyki, a `fresh_press(action)` (interakcja, latarka, skok, zryw) to „świeże” wciśnięcie dla gry. E zostaje klawiszem zamykania terminala (podpowiedź „Esc / E”).
- **B2 — przystań nie jest wieżyczką** (decyzja): w przystani broń jest opuszczona (widać ją nisko, bez strzałów i ciosów; zmiana broni i przeładowanie działają). Leczenie + zapis przy wejściu najwyżej raz na 30 s nocy w tej samej przystani; start nocy w przystani liczy się jako odpoczynek.
- **B3 — „Kontynuuj” wznawia noc** (decyzja): zapis trzyma `night_progress` (indeksy zniszczonych slotów, zabranego łupu, użyte obiekty, zdrowie i amunicja strażnika); indeksy slotów i miejsc łupu są stałe dla ziarna nocy (SandboxLevel i `NightConfig` lobby). `Museum` wypełnia go przy każdym zapisie w trakcie nocy (sygnał `GameState.saving`), śmierć go czyści.
- **B5** — łuk paralizatora z bliska skacze od hurtboxa pierwszego celu (nie od lufy) i tylko na eksponaty (grupa `enemies`, strefy T-Reksa), nigdy na pociski.
- **B7** — promień sondy interakcji tworzony raz (`Interactor._query`).
- **B8** — projekt §3: ok. 800 Pyłu (785) na wszystkie ulepszenia, 4–7 nocy.
- B4 i B6 zrobili inni wykonawcy (popiersie, `DustDropper`).

**Interfejs i przepływ (2a-C)**
- **C1** — zmiana języka w trakcie nocy psuła terminal („Parent node is busy”): przebudowa odroczona (`call_deferred`), a `open()` robi ją od razu, jeśli czeka.
- **C3** — kółko myszy przewija listę opcji, nie zmienia suwaka (`HSlider.scrollable = false`).
- **C4** — latarka: `last_floor_position` tylko na podłodze poziomu (krótki promień w dół, warstwa WORLD; nie na eksponacie) i nigdy w przystani; `DroppedLantern.settle()` opuszcza zapisaną latarkę na podłogę w pierwszej klatce fizyki.
- **C5** — `SceneFlow.goto/quit` zwracają `false`, gdy trwa zmiana albo scena nie istnieje; wejście jest połykane w trakcie zmiany; scena ładowana i tworzona przed zdjęciem starej (błąd → wygaszenie wraca, `busy` zdjęte); kursor puszczany przed `clear_ui` (bez mignięcia). Wywołujący sprawdzają `SceneFlow.busy`.
- **C6** — noc zaczęta bez fokusu okna startuje w pauzie; utrata fokusu pauzuje tylko zwykłą grę (nigdy nad terminalem ani ekranem śmierci), a w uruchomieniach testowych i scenariuszach wcale (`GameInput.pause_on_focus_loss`). Na ekranie śmierci kursor jest ukryty (`push_ui(owner, false)`).
- **C7** — bez „GRA ZAPISANA” przy starcie nocy (razem z B2).
- **C8** — linia „Noc · Pył” w pauzie po zmianie języka; najechanie na przycisk bez fokusu nie kradnie fokusu; drganie „odmowy” nie przesuwa panelu; `strong_font()` to `FontVariation` z osią `wght` 600 (Bahnschrift jest czcionką zmienną); wiersze wyboru nie powtarzają się przy przytrzymaniu klawisza, a klik po lewej stronie wartości cofa wybór.
- **C9/A6** — opcje zapisują się chwilę po zmianie (0,75 s), przy zamknięciu okna i przy wyjściu z gry, nie tylko przy wyjściu z menu opcji.
- **C10** — podpowiedź „F1 — sterowanie” 20 px i jaśniejsza; drobiny Pyłu w menu głównym na całą szerokość widoku (ultrawide).
- **C11** — `run_style.sh` uruchamia okno z `--windowed`; wersja wyeksportowana zapisuje tryb okna w `override.cfg` obok exe (silnik czyta go przed otwarciem okna), a `Graj.bat` czyta tryb z `settings.cfg` i podaje `--windowed`/`--maximized` — bez mignięcia pełnym ekranem.
- **C12** — `SandboxLevel` korzysta z `game` przekazanego przez `Museum`. `WeaponPickup` (plik lobby, `src/level/`) nadal używa autoloadów — do przeniesienia przez właściciela lobby.
- **Po zrzutach ui_2a:** panel opcji i okno potwierdzenia były przyklejone w lewym górnym rogu (`set_anchors_preset` w `_ready` rodzica o gotowym rozmiarze) — teraz `set_anchors_and_offsets_preset`; podpowiedź „[E] …” chowa się pod menu.

**Stan i platforma (2a-A)**
- **A1/A4/A10** — `SaveFile`: zapis do `.tmp`, odczyt kontrolny, stary plik jako `.bak`, rename ponawiany (10 × 20 ms); odczyt próbuje main → `.tmp` → `.bak`, dobry `.tmp` bez maina jest promowany. `load_game`: nieczytelny zapis zostaje nietknięty („unreadable”), uszkodzony jest przenoszony (rename) do `.bad`, a nowa gra startuje tylko, gdy to się udało („corrupt” / „corrupt_kept”); `has_save()` nie liczy zepsutego samotnego `.tmp`. Menu główne pokazuje osobny komunikat dla każdego przypadku.
- **A2** — `SavePaths.is_test_run()` rozpoznaje scenę testową w każdej postaci ścieżki (`localize_path`); `test_runner` przerywa (kod 2), jeśli zapisy nie trafiają do folderu testów.
- **A3 — wszystko na D:.** Zapis/opcje/log: exe → `<exe>/save/`, binarka edytora → `tools/godot/editor_data/nz_save/`, testy → `tests/_out/saves`. Log silnika wyłączony (`enable_file_logging.pc=false`), gra pisze własny (`GameLog` przez `OS.add_logger`, autoload `Storage`) do `logs/godot.log` obok zapisu. Folder użytkownika to `%APPDATA%\Nocna Zmiana` (`use_custom_user_dir`); silnik zakłada go pusty przy każdym starcie, `Storage` od razu go usuwa (tylko pusty). Wersja wyeksportowana: bez pamięci podręcznej shaderów i potoków (`.template=false`; koszt: shadery kompilowane przy każdym starcie). Narzędzia (`tools/dev_env.sh`) i `Graj.bat` kierują `APPDATA` i `LOCALAPPDATA` do `tools/godot/editor_data/{appdata,localappdata}`, więc okienkowe uruchomienia deweloperskie trzymają tam cache silnika i sterownika (np. `NVIDIA\ComputeCache`). Tryb self-contained (`_sc_`) działa tylko dla edytora — sprawdzone: plik `_sc_`/`._sc_` obok wyeksportowanego exe nic nie zmienia, a `custom_user_dir_name` nie przyjmuje ścieżki z dyskiem. Poza zasięgiem gry: przy wersji wyeksportowanej własne cache sterownika GPU (NVIDIA w `%APPDATA%\NVIDIA`, `%LOCALAPPDATA%\NVIDIA`) oraz `run_tests.sh`/`run_boss.sh` (innego wykonawcy) do czasu dopisania `. tools/dev_env.sh` — testy i tak nic nie zostawiają na C: (log wyłączony, pusty folder usuwany).
- **A5** — `settings.cfg` z NaN/nieskończonością: wartość odrzucona.
- **A7** — zapis z nowszej wersji gry: nie jest wczytywany ani przenoszony, komunikat w menu; hak `_migrate()` na przyszłe wersje.
- **A8** — nieudany zapis: `save_failed` → czerwone „Nie udało się zapisać gry” w HUD zamiast „Gra zapisana”.
- **A9** — `--save-dir` / `NZ_SAVE_DIR` nie wyłączają już trybu okna ani V-Sync (osobno `is_test_run()` i `is_redirected()`).
- **A11** — testy: nieczytelny zapis, nieudana kwarantanna, odzysk `settings.cfg` z `.tmp`/`.bak`, NaN, nowsza wersja; test lokalizacji sprawdza klucze budowane w czasie gry i zgodność `%d`/`%s` pl/en.
- **A12** — `tools/export.sh` uruchamia próbę exe z tymczasowym `--save-dir` (nie rusza `build/save`); opis w `save_file.gd` zgodny z kodem.
- Uwaga dla testów: w Godot 4.7.2 odwołanie do klasy `UpgradeTerminal` w małym przebiegu z filtrem potrafi zostawić „resources still in use at exit” — `test_menu_input.gd` szuka terminala po nazwie węzła.
