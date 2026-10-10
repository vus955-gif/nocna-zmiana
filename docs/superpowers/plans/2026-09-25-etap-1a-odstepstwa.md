# Approved deviations from the stage-1a plan (from code reviews)

Files listed here intentionally differ from the plan's code blocks. A later
`extract_files.py --check` will report them as DIFFERS — expected.
If a later task rewrites one of these files in full, re-apply the change.

| Task | File | Change | Why |
|---|---|---|---|
| 1 | tools/run_tests.sh | grep also matches `SHADER ERROR` and `leaked at exit` | plain ObjectDB leaks are WARNING-level and slipped through; baseline of all 21 tasks has zero leak lines, so safe |
| 1 | tests/test_case.gd | `_same`: int vs int compared exactly | is_equal_approx made 1000000 == 1000001, lost int64 precision |
| 1 | tests/test_runner.gd | zero tests found -> "NO TESTS RAN", exit 1 | a --filter typo silently "passed" |

## Notes for later (not changed)
- T3 review: in player.gd (T12) a click that recaptures the mouse also fires one shot (Input 'fire' is set by the same click). Common in shooters; ask in playtest if annoying.
- T2 review: DamageInfo.source is a non-owning ref; check is_instance_valid if infos are ever stored.
- Commit 94ee73d (Task 2) has footer "Claude Sonnet 5" instead of "Claude Opus 5.5" — cosmetic, history not rewritten. Later implementers are told to use the plan's footer.

## Execution tooling (docs/superpowers/plans/tools/)
- `python docs/superpowers/plans/tools/split_plan.py <plan.md> <outdir>` -> conventions.md + task-NN.md
- `python docs/superpowers/plans/tools/extract_files.py <task-NN.md> --list | <paths> | --all | --check`
  copies the plan's code blocks byte-for-byte (tabs preserved); `--check` diffs repo vs plan.
- Baseline check: extracting tasks 01..21 in order into a scratch dir + `python tools/sfx/gen_sfx.py`
  + running the runner gave 119 passed, 0 failed, no leak/warning lines (2026-09-25, also with the Task 1 fixes).

## Poprawki po przeglądach modułów (30.09)
Grupy A (core/combat/fx) i B (bronie/gracz). Suite: 119 -> 146 testów, wszystkie zielone.

- A1 `default_bus_layout.tres`: Master z AudioEffectHardLimiter (sufit -0,5 dB), szyny SFX (-4 dB), Music, Ambience, UI -> Master; `Sfx.play/play_at` grają na szynie SFX; 3D `max_db = 0`.
- A2 `sfx.gd`: pełna pula (32) kradnie najstarszy głos zamiast gubić nowy dźwięk; max 3 kopie jednego dźwięku (kradnie najstarszą kopię); `play_at` dalej niż 60 m od aktywnej kamery jest pomijane.
- A3 `hitscan.gd`: `hit_from_inside = true` (strzał z przyłożenia trafia hurtbox, w którym startuje promień); `Fx.bullet_hole` ignoruje zerową normalną.
- A4/B3 `weapon_holder.gd`: pięść pomija hurtbox, gdy promień WORLD od kamery do niego trafia w ścianę (strona wrogów — osobno, poza tym pakietem).
- A5 `fx.gd`: `SceneTree.scene_changed` -> `Fx.clear()`.
- A6 `fx.gd`: timery efektów (`_free_after`, `_shrink_and_free`) stoją podczas pauzy.
- A7 `fx.gd`: nakładające się hitstopy trwają do najpóźniejszego końca i przywracają time_scale sprzed pierwszego; krótszy nie ucina dłuższego.
- A8 `sfx.gd`: wszystkie SOUNDS ładowane w `_ready`; flaga `_quitting` wycisza play/play_at przy wyjściu; `quit_cleanly` czeka 0,2 s realnego czasu po `stop_all`.
- A9 `stamina.gd`: wyczerpanie kończy się przy `minf(recover_at, maximum)`.
- A10 `test_runner.gd`: `_reset_globals` woła `Sfx.stop_all()` i odpauzowuje drzewo; przed `quit` czeka 0,2 s (wątek audio zwalnia playbacki później — koniec wycieków w `--filter=pickup`/`hud`).
- A11 `fx.gd`: ParticleProcessMaterial cache'owany (kolor/prędkość co 0,5/rozrzut/grawitacja); kierunek wybuchu = obrót emitera wzdłuż normalnej.
- B1 `player.gd`: rozglądanie przez `screen_relative` (czułość niezależna od rozmiaru okna).
- B2 `player.gd`: `respawn` zabija tween śmierci, zeruje dash (czas i cooldown), bufor skoku, coyote, sprint; głowa od razu na wysokości oczu.
- B4 `weapon_state.gd`: `WeaponState` trzyma `weapon.duplicate()` (także pięści) — współdzielony .tres nietknięty.
- B5 `weapon_state.gd`: `can_fire` przy cooldownie <= 1e-4 (bez przenoszenia reszty między strzałami).
- B6 `weapon_state.gd`: `reload_time = 0` przeładowuje natychmiast.
- B7 `weapon_state.gd`: `add_ammo` nigdy ujemne (`maxi(max_reserve - reserve, 0)`).
- B8 `weapon_holder.gd`: strzał przy `pressed` LUB `just_pressed` (krótki klik w zaciętej klatce nie ginie).
- B9 `player.gd`: yaw zawijany `wrapf(-PI, PI)`.
- B10 `player.gd`: `floor_constant_speed = true` (step-up / niewidzialne rampy na schodach — etap 2).
- B11 `weapon_holder.gd`: nowy cios zabija tween poprzedniego.
- B12 testy: skok, coyote, bufor skoku, reset przy respawnie (dash/sprint/oczy), cios przez ścianę, strzał z wnętrza hurtboxa, kradzież głosów, limit kopii, zasięg słyszenia, szyny/limiter, hitstopy, pauza, zmiana sceny, współdzielone materiały cząstek, kopia danych broni, amunicja/przeładowanie/cooldown, stamina.

## Poprawki po przeglądach modułów — wrogowie, arena, HUD (30.09)
- C1 enemy.gd, wolf.gd: atak startuje tylko, gdy wróg widzi strażnika (bez linii wzroku mózg dostaje dystans INF); cios sprawdza zasięg 3D, kąt w poziomie i linię wzroku, ugryzienie wilka w locie też — koniec ciosów przez ściany i stropy.
- C2 wolf.gd: po lądowaniu okno ugryzienia się zamyka, odpoczynek wilka jest bezbronny.
- C3 sandbox_arena.gd, project.godot: navmesh `cell_height` 0,1 i `agent_max_climb` 0,1 (+ `navigation/3d/default_cell_height=0.1`), więc siatka nie łączy podłogi z bokiem rampy.
- C3 enemy.gd: `path_desired_distance` 0,7 → 0,35 (poza zakresem recenzji: przy 0,7 wróg ścinał narożnik u stóp rampy i dreptał w miejscu).
- C3 enemy.gd: wyjście z zablokowania — w pościgu średnio < 0,3 m/s przez 0,75 s → krok ok. 1 m w bok (strony na zmianę), potem nowa ścieżka; liczony postęp, nie chwilowa prędkość, bo zablokowany wróg potrafi drgać tam i z powrotem.
- C4 enemy.gd: `_configure()` wołane z `_init()`, więc statystyki ustawione przez spawner przed `add_child` zostają.
- C5 enemy.gd: gdy cel zniknie, wróg przy najbliższym spojrzeniu odnajduje strażnika (grupa "player").
- C6 enemy.gd: budzenie grupy wymaga czystej linii (WORLD) między eksponatami; okrzyk `notice` gra tylko pierwszy przebudzony.
- C7 enemy.gd: losowe początkowe liczniki wzroku i ścieżki (grupa nie liczy wszystkiego w jednej klatce).
- C8 enemy.gd: emisja telegrafu zapisywana tylko przy zmianie; `face()` resetuje interpolację fizyki; wrogowie nie atakują martwego strażnika (stoją, dopóki się nie odrodzi).
- C8 wax_figure.gd: topnienie obniża też strefy trafień (głowa, tułów), więc strzał w widoczną głowę to nadal trafienie w głowę.
- C8 shield_guard.gd, knight.gd: tarcza nie blokuje stromych strzałów z góry (kierunek y < −0,7) — decyzja projektowa: nagroda za grę z antresoli.
- D2 pickup.gd: dotyk sprawdzany co klatkę fizyki (zamiast `body_entered`), więc strażnik stojący na apteczce dostaje ją, gdy tylko stanie się przydatna.
- D3 Graj.bat: `set "GODOT=..."` w cudzysłowie, komunikat i `pause` przy braku silnika, `echo` przed importem.
- D4 gen_sfx.py: ziarno losowania z nazwy dźwięku (nowy dźwięk nie zmienia pozostałych), nasycenie (`drive`) pistoletu, strzelby i paralizatora, poziomy per dźwięk (notice −7 dB, pickup −5 dB, break_wax −2 dB), bez trzasku w pickup w 70 ms; WAV-y wygenerowane na nowo (szczyt ≤ −0,92 dBFS).
- D5 pickup.gd, sandbox.gd: timery powrotu pickupu i odrodzenia strażnika stoją w pauzie (`create_timer(t, false)`); `respawn_time` ≤ 0 = pickup nie wraca.
- D6 hud.gd: ciemna obwódka kropki celownika; `is_instance_valid(player)` zamiast `== null`.
- D7 greybox.gd: filtrowanie anizotropowe tekstury siatki.
- D8 sandbox.gd: punkt spawnu (19,5; −6) → (20; −6) i stała `GROUP_SCATTER`; recenzja proponowała 20,5, ale przy rozrzucie ±1,5 m grupa wchodziłaby w ścianę (x 22).
- Testy: +20 (wilk, rycerz, tarcza, figura woskowa, arena, pickup, HUD, piaskownica); test pościgu na antresolę przyspiesza symulację 8× (krok fizyki nadal 1/60 s).
