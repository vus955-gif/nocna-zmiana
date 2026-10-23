# Przypisywanie klawiszy i nakładka wydajności (21.10.2026)

> Gałąź `dev-tools` (z `pietro-1` @6e40254). Uwagi właściciela (`docs/backlog-pietro1.md`):
> **52** — opcje muszą być kompletne (FOV, czułość, odwrócenie Y, V-Sync, limit FPS, skala renderu/FSR, tryby okna, głośności,
> napisy, wstrząs, kołysanie, trudność już są) — **brakuje przypisywania klawiszy**.
> **59** — nakładka wydajności dla developmentu: FPS, czas klatki CPU/GPU, draw calls, aktywne AI, trójkąty/obiekty, pamięć,
> najdroższe systemy. Nie musi być w finalnej grze.
> Zasady sesji: tylko `--headless`, bez okien i dźwięku, nic na GitHub.

## 1. Przypisywanie klawiszy

### Stan przed zmianą
Wszystkie akcje rejestruje `GameInput` z tabel `KEYS` / `MOUSE` / `JOY_BUTTONS` (kody fizyczne klawiszy). Cała gra czyta
akcje (`Input.is_action_*`, `GameInput.fresh_press`), więc zmiana zdarzeń w `InputMap` wystarcza, by gra reagowała.
Nazwy klawiszy w tekstach: `GameInput.key_label()` (podpowiedź `[E]`, F1, mapa, CCTV, notatki, onboarding) — ale tylko
pierwszy **klawisz**, nie przycisk myszy. Na sztywno wpisane w `strings.csv`: ekran pomocy (`HUD_HELP_CONTROLS_P1`: WSAD,
Shift, Ctrl, Spacja, LPM, PPM, V, R, 1–8, F, E, F1, F11, Esc), `HUD_HELP_MAP` („M”), `TERMINAL_HINT_CLOSE` („Esc / E”),
opis ulepszenia ze slugiem („Przytrzymaj R”), numery slotów broni w HUD (1–8).

### Model (`KeyBindings`, czysta logika)
- Akcja ma **2 miejsca** (główne i dodatkowe). Wartość: `0` puste, `> 0` fizyczny kod klawisza, `< 0` ujemny numer przycisku
  myszy (kółko też jest przyciskiem). Domyślne = obecne tabele `KEYS` + `MOUSE` (np. `punch`: V, PPM; `dash`: Ctrl, przycisk
  boczny 1; `fire`: LPM, puste).
- Akcje do przypisania (grupy w menu): ruch (4), skok, sprint, unik, strzał, cios pięścią, przeładowanie, latarka, użyj,
  bronie 1–8, następna/poprzednia broń (domyślnie kółko), mapa, pomoc (F1), pełny ekran (F11), pauza. Akcje deweloperskie
  (F5–F8 w arenach, F3 nakładka) i pad (`JOY_BUTTONS`) zostają jak są — **pad: bez zmian** (przypisywanie padu to osobny punkt).
- **Zawsze jedna akcja na klawisz.** Konflikt = **zamiana**: akcja, która traci klawisz, dostaje to, co przypisywana akcja
  miała w tym miejscu; jeśli miejsce było puste, akcja po prostu traci klawisz, ale **nigdy ostatni** (wtedy odmowa z
  komunikatem). Każda akcja zawsze ma co najmniej jeden klawisz (niezmiennik testowany).
- **Zastrzeżone:** `Esc` (anulowanie w menu; pauza ma `Esc` na stałe w miejscu głównym — dodatkowe wolne, żeby nie dało
  się zamknąć sobie drogi do menu), klawisz Windows, `F3` (nakładka).
- Zapis w `settings.cfg`, sekcja `[bindings]`, **tylko akcje różne od domyślnych** (`akcja=[kod, kod]`) — stary plik bez
  sekcji ładuje domyślne; uszkodzony wpis / powtórzony klawisz w ręcznie edytowanym pliku = wszystkie domyślne (nigdy zły stan).
- Zastosowanie: `Settings` po wczytaniu i po każdej zmianie woła `GameInput.apply_bindings()` — podmienia w `InputMap`
  zdarzenia klawiatury i myszy (zdarzenia padu zostają), kolejność = miejsca. `reset_to_defaults()` przywraca też klawisze.

### Interfejs
Wiersz „Klawisze…” w sekcji sterowania opcji otwiera panel `KeyBindingsPanel` (ta sama tablica z `UiTheme`, własna lista z
przewijaniem, ~27 wierszy; osobny panel zamiast 27 wierszy w głównej liście, bo nawigacja klawiaturą/padem po 60 przyciskach
byłaby męcząca). Wiersz: nazwa akcji + dwa przyciski miejsc. Klik / Enter → „naciśnij klawisz…” → następny klawisz lub przycisk
myszy (też kółko) zostaje przypisany; `Esc` anuluje, `Del`/`Backspace` czyści miejsce (nie ostatnie). Pod listą wiersz
komunikatu (zamiana / odmowa), przycisk „Przywróć domyślne”, „Wstecz”. Nazwy klawiszy: `GameInput.key_label()` rozszerzone o
przyciski myszy (LPM, PPM, ŚPM, boczne, kółko) z tłumaczeniem PL/EN.

### Teksty zależne od klawiszy
Ekran pomocy F1 budowany z bieżących przypisań (`ControlsHelp`), podpowiedź „F1 — sterowanie”, `[E]` w HUD (już czyta
`key_label`, odświeża się po zmianie), mapa, CCTV, notatki, sloty broni w HUD, „Esc / E” w terminalu, opis slugu bez nazwy
klawisza.

### Testy
Przypisanie zapisuje się i wraca po `reload()`; konflikt zamienia / odmawia; niezmienniki (unikalność, ≥1 klawisz);
stary plik → domyślne; zepsuty plik → domyślne; `InputMap` reaguje (zdarzenie nowego klawisza uruchamia akcję, stary nie);
`key_label` i podpowiedź `[E]` po zmianie; ekran pomocy po zmianie; panel: przechwycenie klawisza / myszy, `Esc`, `Del`,
przywracanie domyślnych; tłumaczenia PL/EN dla wszystkich nowych kluczy.

## 2. Nakładka wydajności (dev)

### Co pokazuje (`PerfOverlay`, autoload, `F3`)
Mały panel przy prawej krawędzi w stylu HUD (`UiTheme`, odświeżany 4×/s): FPS i czas klatki (średnia / najgorsza z okna +
mały wykres ostatnich ~2 s), czas CPU **tyku fizyki** (`physics_frame` → `process_frame`: `_physics_process` węzłów + krok
serwera fizyki) i **wywołań `_process`** (`process_frame` → `RenderingServer.frame_pre_draw`; headless do następnego tyku) —
liczone z sygnałów drzewa, bo monitory `TIME_PROCESS` / `TIME_PHYSICS_PROCESS` pokazują **najgorszą klatkę z ostatniej sekundy**
(a w oknie `TIME_PROCESS` wlicza czekanie na vsync) — czas renderu CPU i **GPU**
(`RenderingServer.viewport_get_measured_render_time_*`, mierzone tylko gdy nakładka włączona; „—” gdy brak), draw calls,
obiekty i prymitywy w klatce, światła i cienie aktywne (po cullingu pokojów — `RoomCuller.light_stats()`), aktywne AI
(wystawy: czuwające / goniące; strażnicy w walce), ciała fizyki 3D i pary kolizji, pamięć (statyczna, VRAM, tekstury), liczba
węzłów, bieżący pokój i strefa (`Events.room_entered`), koszt percepcji (`PerceptionWorld.stats`).
`F3` kolejny raz: tryb **„systemy”** — rozbicie czasu skryptów na podsystemy (`CpuSections`, patrz niżej) z paskami.
### Kiedy działa
Skrót `F3` działa w buildach deweloperskich (`OS.is_debug_build()`) **albo** gdy włączona jest opcja „Narzędzia deweloperskie
(F3)” w opcjach (interfejs; domyślnie wyłączona). Wyłączona nakładka: niewidoczna, `set_process(false)`, brak pomiarów
(`viewport_set_measure_render_time(false)`, `PerceptionWorld.profiling = false`) — koszt jednego sprawdzenia klawisza.

### `CpuSections` (wspólne z narzędziem CPU)
Pomiar czasu wywołań **bez zmiany kodu gry**: grupa węzłów podsystemu dostaje wspólny `process_priority` /
`process_physics_priority`, a przed i po grupie stoją węzły-znaczniki o priorytecie o 1 mniejszym / większym; różnica czasu
między znacznikami = czas wywołań `_process` / `_physics_process` całej grupy w tej klatce (dokładnie, bo silnik wykonuje
węzły w kolejności priorytet → drzewo). Zajmowane są **wszystkie** węzły sekcji (też silnikowe: agenci nawigacji, źródła
dźwięku 3D, animacje, cząsteczki przetwarzają się same). Podsystemy (`MuseumSections`): najpierw węzły silnikowe jednego rodzaju
(nawigacja, dźwięk 3D, animacje, cząsteczki), potem gracz, wystawy (wrogowie), strażnicy, HUD i menu, poziom (światła, drzwi,
culling), logika piętra (`FloorGame`), `Fx`, muzyka (`Music` + `MusicDirector`), ambient/foley, głos (`VoiceDirector`), reszta
świata, usługi gry (autoloady). Uwagi: wywołania z sygnałów liczą się do emitującego; czasu serwera fizyki i timerów nie ma w
podsystemach (raport pokazuje „silnik + nieprzypisane” = suma − podsystemy); zmiana priorytetów lekko zmienia kolejność
węzłów w klatce (tylko w trybie „systemy” / narzędziu).

## 3. `tools/run_cpu_profile.sh`

Scenariusz `tests/scenarios/cpu_profile.tscn` (headless, `--fixed-fps 60` = każda klatka to dokładnie jeden tyk 1/60 s, dźwięk
Dummy; czas tyku z sygnałów `physics_frame` / `process_frame`): buduje **ubrane** muzeum Floor I
(`Museum.level_id = floor1`, `MuseumFloorLevel.dress_default = true`), włącza muzykę i głos (w testach wyłączone), potem
odcinki nocy: (1) hol bezczynnie, (2) marsz strażnika przez dziedziniec do skrzydła egipskiego (pokoje się wybudzają),
(3) walka w holu — pobudzone wystawy gonią strażnika, ogień z pistoletu i kartaczownicy (zniszczenia, odłamki, Fx),
(4) walka ze strażnikiem skrzydła, jeśli da się ją zainscenizować bez okna. Dla każdego odcinka: ms na tyknięcie (średnia,
p95, najgorsza) tyku fizyki i wywołań `_process` łącznie oraz **wg podsystemów** (sterownik scenariusza, który strzela, ma własną
sekcję `driver`), koszt percepcji (`look_usec`: tylko sprawdzenia wzroku, w czasie fizyki wystaw), spis węzłów, liczniki (wystawy, czuwające,
goniące, węzły) → `tests/_out/cpu_profile.json` + tabela na stdout. Pomiar GPU w oknie jest wykluczony (zasady sesji) — nakładka
F3 ma to uzupełnić, gdy właściciel odpali grę.

## Kolejność prac (TDD, jeden commit na zadanie)
1. `KeyBindings` + testy jednostkowe.
2. Integracja z `SettingsData`/`Settings`/`GameInput` (zapis, odczyt, `InputMap`, etykiety myszy).
3. `KeyBindingsPanel` + wejście z opcji + teksty PL/EN.
4. Ekran pomocy i podpowiedzi zależne od klawiszy.
5. `PerfStats` + `RoomCuller.light_stats()`.
6. `CpuSections`.
7. `PerfOverlay` + opcja + akcja `toggle_perf`.
8. `run_cpu_profile.sh` + pierwsze liczby; dokumentacja; scalenie z `pietro-1`; pełny zestaw.

## Do sprawdzenia w oknie (nie robione — zasady sesji)
- Panel klawiszy: wygląd, przewijanie, fokus padem/klawiaturą, przechwycenie myszy (w tym kółka) w prawdziwym oknie,
  czytelność etykiet w 21:9.
- Nakładka F3: układ w 1920×1080 i 21:9, **czas GPU** (czy sterownik zwraca pomiar), wykres klatek, tryb „systemy” w walce.
- `Esc` zamyka panel klawiszy → opcje → pauzę (kolejność), klik w wiersz podczas przechwytywania.
- **Przegląd w oknie 23.10** (`2026-10-22-przeglad-w-oknie.md` §1): nakładka F3 w 1920×1080 OK, czas GPU mierzony (RTX 2080 Ti: 4–7 ms); 21:9 i panel klawiszy nie sprawdzone.

## Pierwsze liczby (headless, `bash tools/run_cpu_profile.sh`, 21.10, Ryzen 9 3900X, maszyna zajęta innymi agentami)

Muzeum Floor I ubrane, noc 1: 164 wystawy (większość śpi), 47,4 tys. węzłów (17,5 tys. `MeshInstance3D`, 856 + 393 światła,
562 `GPUParticlesCollisionBox3D`, 940 `Area3D`, 2150 węzłów ze skryptem). Budowa 17–22 s (piętro 10–14 s, nawigacja 0,1 s).
ms na tyk (fizyka = `_physics_process` węzłów + krok serwera fizyki; idle = `_process`, timery, deferred; bez renderowania):

| odcinek | tyk razem | fizyka | idle | wystawy (fizyka) | strażnicy | inne najdroższe |
|---|---|---|---|---|---|---|
| hol bezczynnie (8 s) | 14,2 | 12,2 | 2,0 | 8,2 | 0,78 | świat 0,5 (idle), muzyka 0,19, HUD 0,21 |
| marsz do Egiptu (26 s) | 15,9 | 13,8 | 2,1 | 9,7 | 0,76 | świat 0,45, muzyka 0,20, HUD 0,21 |
| walka w holu (14 s) | 20,4 | 17,9 | 2,4 | 12,6 | 0,69 | sterownik (strzały) 0,63, świat 0,45 |
| Colossus (10 s) | 20,0 | 17,5 | 2,6 | 12,1 | 1,12 | sterownik 0,37 |
| T-Rex (10 s) | 19,3 | 16,7 | 2,5 | 11,3 | 0,96 | logika piętra 0,31, sterownik 0,39 |

Poza podsystemami zostaje ~2,8–3,5 ms fizyki (krok serwera Jolt, węzły bez sekcji) i ~0,4–0,8 ms idle.
Wnioski (do zweryfikowania w oknie, to czas CPU skryptów, nie GPU):
- **Wystawy to ~60–65 % tyku fizyki** także gdy gracz stoi w kanciapie i prawie wszystkie śpią (8 ms na ~165 wystaw ≈ 50 µs na
  wystawę na tyk — pełny `Enemy._physics_process` w GDScripcie: `_steer`, `brain.update`, `_apply_gravity`, `_update_visuals`…).
  Percepcja to z tego tylko 0,06–0,27 ms (sprawdzenia wzroku). Najtańszy zysk: uśpione wystawy daleko od strażnika na
  „lekki tyk” co kilka klatek / wyłączone przetwarzanie (backlog #57: najpierw profil, potem optymalizacja).
- Głos, muzyka, ambient, efekty, HUD: każdy 0,05–0,25 ms idle — bez znaczenia. Agenci nawigacji, dźwięk 3D, cząsteczki,
  animacje: po ok. 0,02–0,04 ms.
- **Skoki**: `level` (idle) 10–13 ms w pojedynczej klatce — to przełączenie kulingu pokojów (`RoomCuller.update_from` →
  `set_room` dla wszystkich lamp), po jednym przy każdej zmianie pokoju; `exhibits` fizyka max 30–37 ms (pojedyncze
  klatki). Warto sprawdzić w oknie, czy wchodzenie do nowego pokoju daje widoczne mrugnięcie.
- Wahania między uruchomieniami ±30–40 % (inne procesy Godota na tej samej maszynie); porównywać odcinki z jednego przebiegu.

## Stan prac / co dalej (21.10)
Wszystko z planu zrobione na gałęzi `dev-tools` (commity na gałęzi; nic nie wypchnięte): `KeyBindings` + `Settings.bind` +
panel klawiszy + `ControlsHelp` (F1, podpowiedzi, sloty), `PerfStats` + `RoomCuller.light_stats` + `CpuSections` +
`MuseumSections` + `PerfOverlay` (F3) + `tools/run_cpu_profile.sh`. Pełny zestaw: 2786 z 2787 zielonych w jednym przebiegu (jedyny błąd — test nakładki zależny od kolejności — poprawiony; potem 151 testów dotkniętych
zmianą zielonych filtrem; scalenie `pietro-1` bez zmian, bo się nie ruszyło).
Zostaje tylko to, czego nie wolno robić bez okna (lista wyżej), oraz — poza zakresem — optymalizacja wystaw wg liczb.
Decyzje: reset opcji (przycisk w opcjach) przywraca też klawisze; pad bez zmian (przypisywanie padu to osobny punkt, `GameInput.JOY_BUTTONS`);
`Esc` zastrzeżony i na stałe jako główny klawisz pauzy; `F3` zastrzeżony.
