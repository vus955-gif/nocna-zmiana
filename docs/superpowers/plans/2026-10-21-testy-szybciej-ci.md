# Testy szybciej i CI — plan wykonawczy

> **Dla wykonawcy:** wykonuje Claude w drzewie `.claude/worktrees/qa-sweep`, gałąź `test-speed` (z `pietro-1` @ `6e40254`). Bez okien, bez dźwięku, nic nie idzie na GitHub: workflow CI jest **przygotowany, nie włączony**.
> Dotyka wspólnych plików: `tests/test_runner.gd`, `tests/test_case.gd`, `tools/run_tests.sh`, `src/core/save_paths.gd` (jedna funkcja), siedem plików `test_floor1_art_*`, pięć testów z budżetem czasu ścianowego. Reszta to pliki nowe.

**Cel:** pełny zestaw (2700 testów, 30 min w jednym procesie) ma dać się przejść w kilka minut, bez osłabiania testów; do tego szybki podzbiór do CI i gotowy plik workflow dla GitHub Actions.

---

## 1. Pomiar przed zmianą

Pełny zestaw, jeden proces Godota (`bash tools/run_tests.sh`), PC współdzielony z innymi agentami (dwa obce procesy Godota po ok. 100 % rdzenia przez cały czas, więc liczby są górne): **30 min 10 s**, 2695 testów, 292 pliki. Czas pliku mierzy teraz sam runner (`TIME` / `SLOW` w wyniku, `--timings=`).

| Gdzie idzie czas | s | udział |
|---|---|---|
| walki ze strażnikami rozegrane do końca (`lamassu`, `colossus`, `planetarium`, `centaur`, `serpent*`, `general*`) | ok. 870 | 48 % |
| całe noce i przemiatania całego piętra (`floor1_game_flow`, `softlock_arenas`, `save_world`, `collision*`, `reachability`, `full_night`, `timing`, `guardians`) | ok. 380 | 21 % |
| ubrane piętro budowane od nowa w każdym teście (`floor1_art_*`) | ok. 115 | 6 % |
| 211 pozostałych plików poniżej 2 s | ok. 100 | 6 % |
| reszta (środkowe pliki 2–10 s) | ok. 330 | 19 % |

Stałe koszty: `--import` 13 s, start procesu Godota ok. 8 s, **pierwsze** ubrane piętro w procesie ok. 9–11 s (zimne wczytanie modeli i tekstur; każde kolejne ok. 1 s). Narzut runnera na jeden test (reset globali, klatka) to kilka ms — nie jest problemem.

**Najważniejsze znalezisko (niezmienione, do decyzji kontrolera):** pełne muzeum Piętra I w teście to 175 eksponatów, z czego 162 śpi. Bezczynne muzeum kosztuje **ok. 16 ms na klatkę**; po wyłączeniu `_physics_process` eksponatów — **ok. 4 ms**, po ich usunięciu — ok. 2,6 ms. Śpiący eksponat zużywa więc ok. 70 µs klatki (`Enemy._physics_process`: `_look`, `PerceptionWorld.track`, `brain.update`, `_steer`, `_update_visuals` mimo `resting()`, które omija tylko `move_and_slide`), a `_process` rigów dokłada jeszcze ok. 4–5 ms. Walki w testach (jedno muzeum Piętra I na test, zwykle 40–90 s gry) płacą ten koszt co klatkę — ten sam wniosek, z pomiarem samych walk, dała niezależnie gałąź `dev-tools` (`tools/run_cpu_profile.sh`, `docs/superpowers/plans/2026-10-21-sterowanie-nakladka.md`, backlog #57): walka z Colossusem to 20 ms na tyk, z czego wystawy 12 ms (60–65 % fizyki), hol bezczynnie 14 ms, z czego wystawy 8 ms. Wczesne wyjście dla śpiącego, stojącego, odległego od strażnika eksponatu (tylko odliczanie `_sight_timer`) mogłoby skrócić te testy mniej więcej dwu-, trzykrotnie (szacunek: klatka z 16–20 do ok. 6–8 ms) i odciążyłoby klatkę samej gry. **Nie ruszałem:** `src/enemies/enemy.gd` jest gorący w innych gałęziach, a zmiana zmienia zużycie losowości (`randf_range` w `_routine_timer`), więc dotyka też zachowania testów z ziarnem. Do osobnego zadania z własnym przeglądem.

## 2. Co zrobiono

### 2.1 Równoległe przebiegi (`--parallel`, `-j N`)
- `tests/test_runner.gd`: `--shards=N --shard=k` dzieli pliki na N grup o zbliżonym czasie (zachłannie: najcięższy plik do najlżejszej grupy; wagi z `tests/test_durations.tsv`, plik bez wpisu waży medianę). Podział jest deterministyczny, więc każdy proces liczy ten sam.
- Każdy shard ma własny folder zapisów `tests/_out/saves_k` (`SavePaths.test_dir()` czyta `--shard=`) i własny log `tests/_out/shards/k.log`. Raporty w `tests/_out/*.json` mają różne nazwy plików, więc się nie zderzają.
- `tools/run_tests.sh`: `-j N`, `--parallel` (auto: jedna czwarta wątków CPU, od 2 do 6; na tym PC 6), `NZ_TEST_JOBS`. Bez opcji działa jak dotąd (jeden proces). Import raz, potem N procesów w tle, na końcu logi po kolei i jedna linia `N passed, M failed`. Run kończy się porażką, gdy: padł jakikolwiek test, **w którymkolwiek logu jest linia `ERROR` / wyciek**, shard nie wypisał podsumowania (crash), albo nic nie uruchomiono. Ctrl-C zabija shardy. `--timings=<plik>` łączy czasy shardów i przepisuje `tests/test_durations.tsv` (tylko po pełnym, zielonym przebiegu).
- „Przyjazny dla watchdoga CPU”: shardy idą z niskim priorytetem (`BelowNormal` na Windows, dziedziczony po powłoce), nie więcej niż 6 procesów (zmierzony szczyt ok. 3,2 GB RAM na shard przy pełnym zestawie, razem do ok. 19 GB), `NZ_TEST_JOBS` / `-j` pozwalają zejść niżej. **Domyślnie nic się nie zmienia** — równoległość trzeba włączyć; zmiana domyślnej to decyzja kontrolera (inni agenci odpalają testy w swoich drzewach jednocześnie i 6 × 6 procesów to za dużo).
- Budżety czasu ścianowego w testach (`MenuStage` — budowa, start nocy — budowa, `ShellCache` — odczyt, koszt węża, koszt percepcji) mnożone przez `TestCase.time_slack()`: 1 na spokojnym PC, **2** w trybie równoległym (`NZ_TEST_SLACK`), do ustawienia na CI. Bez tego pierwsze ubrane piętro w świeżym procesie (8,5 s przy budżecie 8 s) wywracało `test_menu_stage` w shardzie — w jednym procesie po cichu zapewniała to kolejność plików. Budżety w czasie gry (klatki, sekundy symulacji) nie są ruszane.

### 2.2 Wspólna ubrana podłoga w plikach `floor1_art_*`
- `TestCase.shared_fixture(klucz, builder)`: coś drogiego, na co testy tylko **patrzą**, budowane raz na plik; runner zwalnia po pliku i **po każdym teście sprawdza odcisk** (zbiór węzłów, położenia i widoczność `Node3D`; nie liczą się obrót i miganie natężenia, bo dekoracje kręcą się i migają same). Test, który coś zmienił, **pada** („changed the shared fixture…”), a następny dostaje nowe. Sprawdzone ręcznie na próbnym teście (padł tylko ten, który ruszył).
- `DressedFloor.build(host)` (`tests/support/dressed_floor.gd`) — to samo ubrane piętro bez nawigacji, co dawniej budował `before_each()`. Siedem plików (`east`, `americas`, `basement`, `wings`, `roof`, `light`, `fit`) korzysta ze wspólnego; testy, które zmieniają piętro (zaciemnienie, wygaszanie pokoi `culler`, presety jakości, zdejmowanie części), są na liście `OWN_LEVEL` w pliku i budują własne — razem 14 testów z 87. Nie dotknąłem testów z `Museum` (grają w nim i zmieniają świat), ani `test_floor1_art.gd` (buduje ubrane i szare).
- Zysk: pliki `floor1_art_*` z ok. 115 s do ok. 60 s w jednym procesie (włącznie ze zimnym pierwszym budowaniem).

### 2.3 Podzbiór szybki (`--quick`)
- `tests/quick_tests.txt`: reguły glob nad `dir/plik` (`unit/*`, `integration/*`, potem wyjątki z `-`). Wszystkie testy jednostkowe i wszystkie integracyjne **poza** wolnymi i drogimi (większość powyżej ok. 8 s: walki do końca, całe noce, przemiatania piętra, ubrane piętro od nowa w każdym teście). **ok. 2370 testów z 2707** (253 pliki), ok. 250–280 s czasu jednego procesu na tym PC, **ok. 100 s w czterech shardach** (+ 13 s import).
- Strażnik w `test_runner_selection`: każda reguła musi trafiać w istniejący plik, żaden plik z podzbioru nie może mieć zapisanego czasu ponad 25 s, a cały podzbiór ponad 400 s — nowy wolny plik trzeba dopisać do wyjątków (nowy szybki wchodzi sam).

## 3. Jak używać

| Polecenie | Co robi |
|---|---|
| `bash tools/run_tests.sh` | jak dotąd: wszystko, jeden proces |
| `bash tools/run_tests.sh --parallel` | wszystko w N procesach (auto 2–6) |
| `bash tools/run_tests.sh -j 4` | cztery procesy |
| `bash tools/run_tests.sh --quick -j 4` | szybki podzbiór, cztery procesy |
| `bash tools/run_tests.sh --filter=a,b` | jak dotąd |
| `bash tools/run_tests.sh --no-import` | bez `--import` (oszczędza 13 s; tylko gdy od ostatniego razu nie zmieniły się zasoby, `class_name` ani pliki `.import`) |
| `bash tools/run_tests.sh --parallel --timings=tests/test_durations.tsv` | po dużych zmianach w zestawie: odświeża czasy |
| `GODOT_BIN=/ścieżka/godot`, `NZ_TEST_SLACK=3` | inny binarny Godot (CI), luźniejsze budżety czasu |

## 4. Wyniki (po)

**Cały zestaw**, ten sam PC, współdzielony z innymi agentami:

| tryb | czas | testów |
|---|---|---|
| przed: jeden proces | 30 min 10 s | 2695 |
| po: `--parallel` (6 procesów), pięć przebiegów | 7 min 43 s – 8 min 30 s; końcowy po scaleniu `pietro-1`: **7 min 43 s**, zielony | 2800 |
| po: jeden proces, po scaleniu `pietro-1` (w tym czasie biegły 3–4 obce pełne zestawy) | 35 min 16 s | 2800 |

Przyspieszenie 6 procesami to ok. 3,9× wobec pomiaru z początku (30 min 10 s) i 4,6× wobec jednego procesu z tego samego, obciążonego okresu (35 min 16 s), nie 6×. Czas jednego procesu waha się o ok. 15 % z obciążenia PC (30 min 10 s – 35 min 16 s, a przybyło ok. 100 testów), więc zysk ze wspólnego piętra (ok. 1 min) tonie w szumie; widać go w samych plikach `floor1_art_*` (§2.2): shardy wzajemnie zwalniają się o ok. 50 % (pamięć, hyper-threading, a do tego obce procesy na tym PC), a suma pracy rośnie z 1790 s do ok. 2650 s. Podział jest dobry (najkrótszy i najdłuższy shard różnią się o 10–15 %); dalsza zwłoka to nie podział, tylko łączna praca. Więcej niż 6 procesów nie ma tu sensu. Na wolnym PC z mniejszą liczbą wątków `--parallel` da mniej.

**Podzbiór szybki** (`--quick`, 2370 testów): 102 s w czterech shardach, 141 s w trzech (jak w CI, `NZ_TEST_SLACK=3`); w **świeżym klonie** (bez `.godot`, pierwszy import od zera) cały przebieg 255 s, z czego ok. 2 min to pierwszy import (w CI zbija go cache). Szczyt pamięci: ok. 2,9 GB na proces także w podzbiorze.

## 5. CI (przygotowane, nie włączone)

`.github/workflows/tests.yml`:
- **Wyzwalacze:** `push`, `pull_request`, ręczne `workflow_dispatch` (wybór `quick`/`full` i `windows: true`). `concurrency` kasuje starszy przebieg tej samej gałęzi.
- **Job `linux`** (`ubuntu-latest`): bierze Godota 4.7.2 z oficjalnego wydania `godotengine/godot` — **zasób `Godot_v4.7.2-stable_linux.x86_64.zip` istnieje** (sprawdzone `gh api repos/godotengine/godot/releases/tags/4.7.2-stable`, 77 860 424 B, wydanie z 18.08.2026), weryfikuje jego sha256 (`cadd3204…29e4`, z listy zasobów wydania) i trzyma w cache; `actions/cache` na `.godot` kluczem z treści plików `*.import`, `project.godot`, `locale/strings.csv`; import (`--headless --import`); `bash tools/run_tests.sh -j 3 --quick` (a `full` przy ręcznym uruchomieniu); log do podsumowania zadania; **przy porażce wgrywa** `tests-linux.log` i `tests/_out/shards/*.log`. Akcje: `checkout@v7`, `cache@v6`, `upload-artifact@v7` (aktualne główne wersje, sprawdzone).
- **Job `windows`** (`windows-latest`, tylko ręcznie z `windows: true`): to samo na `Godot_v4.7.2-stable_win64.exe.zip` (sha256 `731980f9…e953`) — odniesienie, gdyby coś różniło się na Linuksie. Koszt: na prywatnych repozytoriach minuty Windows liczą się podwójnie; na publicznym nic. Powolniejszy start (większe pobranie).
- **Nic nie wymaga sekretu.** Plik nie robi nic, dopóki nie trafi na GitHub.

### Czy projekt chodzi na Linuksie? — co sprawdzone, czego nie
- Sprawdzone statycznie: brak `OS.execute`, ścieżek `C:/` `D:/`, plików `.dll`/`.gdextension`/addonów; **10 342 odwołania `res://` zgadzają się co do wielkości liter** z plikami w gicie (Linux jest wrażliwy, Windows nie) — skrypt porównania, 0 niezgodności; zakończenia linii pilnuje `.gitattributes`; `DirAccess.get_files()` zwraca posortowane. `tools/dev_env.sh` używa `pwd -W` (tylko Git Bash) — `run_tests.sh` ładuje go wyłącznie na Windows. `.translation` powstaje z CSV przy imporcie.
- Sprawdzone na Windows w **świeżym klonie** (jak CI: bez `.godot`, bez `.translation`): **jeden** `--import` wystarcza, testy ruszają. Ten przebieg znalazł prawdziwy błąd (statyczna `_release` w `TestCase` zderzyła się z `_release` w `test_gatling_state`; nazwy nowych składowych zmienione na nieprawdopodobne do zderzenia).
- **NIE sprawdzone: faktyczny przebieg na Linuksie** — nie ma tu binarki Linux ani Dockera (jest WSL Ubuntu, ale pobranie `Godot_v4.7.2-stable_linux.x86_64.zip`, 77 MB, wymaga zgody; z nim dałoby się to sprawdzić lokalnie w WSL bez okna). Ryzyka do zweryfikowania na pierwszym przebiegu: (a) Jolt na Linuksie może liczyć nieco inaczej niż na Windows — testy z ciasnymi tolerancjami symulacji (chód bota, strażnicy) mogą się rozjechać; podzbiór `quick` wyłącza największe przemiatania, ale nie wszystko; (b) budżety czasu na wolniejszych runnerach — `NZ_TEST_SLACK` do ustawienia (tu nie ustawione w pliku; dla pierwszego przebiegu proponuję `3`); (c) pamięć: zmierzone ok. 2,9 GB na proces (podzbiór) do 3,2 GB (całość), `-j 3` to ok. 9 GB — runner publiczny (16 GB) wystarcza, prywatny 2-rdzeniowy (7 GB) ledwo nawet przy `-j 2`: wtedy `-j 1`.
- Jeśli Linux się nie uda: przełącznik `windows` w `workflow_dispatch` daje ten sam test na Windows; dla pushy można zmienić `runs-on` joba `linux` na `windows-latest` (koszt wyżej).

### Sugestia znaczka (do decyzji kontrolera; w README celowo NIE dodany)
```markdown
<!-- [![tests](https://github.com/vus955-gif/nocna-zmiana/actions/workflows/tests.yml/badge.svg)](https://github.com/vus955-gif/nocna-zmiana/actions/workflows/tests.yml) -->
```
Przed wypchnięciem: audyt „przed publikacją” (nic z rozmów o pracę, kluczy, nazw, lokalnych ścieżek) — w `tests.yml` nic takiego nie ma; katalog `.github/` pójdzie razem z czystym commitem gałęzi `public-main`.

## 6. Decyzje z kompromisem

- **Równoległość opt-in.** Domyślnie `run_tests.sh` bez opcji jak dotąd; kontroler może ustawić `NZ_TEST_JOBS` w profilu albo zmienić domyślną.
- **Wspólne piętro tylko dla testów „tylko patrzę”**, z odciskiem po każdym teście; odcisk nie widzi zmian materiałów, cząstek czy nasilenia świateł — dlatego lista `OWN_LEVEL` jest zachowawcza (każdy test dotykający `NightModifiers`, `culler`, `GraphicsQuality`, `emitting`, `free` buduje własne). Przy dodawaniu testu do tych plików: jeśli coś zmienia, dopisz jego nazwę do `OWN_LEVEL`.
- **Czasy w `test_durations.tsv` to proporcje**, nie sekundy; przepisywane tylko przez pełny zielony przebieg `--timings=`.
- **`--import` przy każdym przebiegu zostaje** (13 s); `--no-import` tylko na życzenie.
- **Nie zmniejszałem żadnej symulacji** (okna 60 s gry, walki do końca) — to ona jest kosztem; patrz znalezisko w §1.

## Do sprawdzenia w oknie
Nic — wszystko headless.

## Stan prac / co dalej
- [x] Pomiar, runner (czasy, shardy, quick), `run_tests.sh` (`-j`, `--parallel`, `--quick`, `--no-import`, Linux), izolacja zapisów, budżety z `time_slack`, wspólne piętro, `tests.yml`, ten plik.
- [x] Pełny zestaw zielony: równolegle (2708) i w jednym procesie (2708) (§4); podzbiór w świeżym klonie zielony (2370).
- [ ] (kontroler) wypchnąć `.github/workflows/tests.yml` razem z gałęzią publiczną i zobaczyć pierwszy przebieg Linux; ewentualnie zgodzić się na pobranie Linuxowego Godota do WSL, by sprawdzić go lokalnie wcześniej.
- [ ] (kontroler) osobne zadanie: tani tryb dla śpiących, odległych eksponatów w `Enemy._physics_process` (§1) — największy możliwy zysk (testy walk i sama gra).
- [ ] (opcjonalnie) kolejne pliki ze wspólną fikstura: `test_floor1_art.gd`, `test_cafe_corner` (31 testów, ok. 0,7 s na test) — małe zyski.
