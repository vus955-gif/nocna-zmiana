# Pełne przejście bota bez oszustw (#60) — plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`, commit po każdym zadaniu. Wykonuje Claude w drzewie `.claude/worktrees/guard-serpent`, gałąź `playthrough-bot` (z `pietro-1` @ `6e40254`).
> Wiążące: `docs/backlog-pietro1.md` **#60** (pełny playthrough bez debug tools, noclipu, god mode i ręcznego teleportowania między sekcjami — „tak, jak będzie ją przechodził gracz od początku do końca”), **#55** (rytm: fale napięcia), **#54** (zasoby: lekka presja, nie survival), plan W7 (`2026-10-03-p1-w7-weryfikacja.md`: model czasu, „100 % ≈ 2 h 39 min”, droga krytyczna 57 min), plan QA (`2026-10-18-qa-kolizje-softlocki-zapis.md`: `Floor1Walker` prowadzi prawdziwego strażnika). Bez okna, bez dźwięku, bez wypychania na GitHub, bez pod-agentów.

**Cel:** bot bez okna przechodzi **prawdziwą grę** od świeżego zapisu przez kolejne noce aż do pokonania T-Reksa i zejścia do krypty — wyłącznie wejściami gracza (akcje wejścia, obrót głowy jak myszą, klik w terminalu) i według reguł gry: chodzi po siatce nawigacji jak gracz (bez teleportu), zbiera klucze, broń i amunicję, otwiera zamki właściwym narzędziem, walczy z eksponatami i strażnikami prostą, kompetentną taktyką (celuje „jak aimbot”, ale obrywa normalnie — bez god mode), odpoczywa i zapisuje w przystaniach, wydaje Pył na ulepszenia, ginie lub przeżywa i gra następną noc jak gracz (śmierci dozwolone — raportowane), szanuje świt. Wynik: dziennik przebiegu + raport (noce, czas na noc i strefę, śmierci i przyczyny, zasoby w czasie — amunicja, zdrowie, Pył — gdzie utknął, softlocki, błędy). Ziarna deterministyczne; tryb szybki (`--fixed-fps 60` + skala czasu), żeby całe przejście trwało minuty, nie godziny.

**Architektura (akapit):** scenariusz `tests/scenarios/playthrough_scenario.gd` gra jak `SceneFlow`: świeży zapis (własny folder zapisu przebiegu), noc = nowa scena `Museum` (śmierć/świt → `next_night_requested` → następna scena), koniec = `demo_end_requested`. W scenie siedzi węzeł `PlaythroughBot` (fizyka **przed** strażnikiem: `process_physics_priority`), który co krok fizyki: patrzy (eksponaty, strażnik, zegar, cel HUD = `ProgressRules.next_step` z zapisu — to, co gracz widzi na HUD), decyduje (`PlaythroughBrain`: czysta logika, testy jednostkowe) i działa przez `PlaythroughPilot` — **tylko** `Input.action_press/release` (ruch w osiach głowy, sprint, skok, strzał, cios, E, przeładowanie), zdarzenia `weapon_N` (`Input.parse_input_event`) i `Player.look()` (obrót jak mysz, z limitem prędkości). Droga: `PlaythroughNav` — ścieżka po siatce gry (`LevelNavigation.find_path` liczona „od celu do startu”, bo zapytanie w drugą stronę na wyspę siatki drukuje `ERROR` — por. `NavProbe`), prowadzenie z wykrywaniem utknięcia (skok, krok w bok, nowa ścieżka) i szukanie miejsca do stania (E w zasięgu `Interactor.REACH`, strzał w strefę zamka trafiający **pierwszy**: `Hitscan.ray`). Nic poza tym: bot nie woła `take_damage`, `heal`, `global_position =`, `open()`, `GameState.*` zapisów (wyjątek: `UpgradeMenu` — wybór wiersza i „kup” to klik gracza; zamknięcie menu = E/Esc). Zapis zdarzeń i próbek `PlaythroughLog` → `tests/_out/playthrough/<ziarno>/` (`log.jsonl`, `report.json`, `report.html`).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, tabulatory; `bash tools/run_tests.sh --filter=…`, `bash tools/run_playthrough.sh …` (bez okna, `--audio-driver Dummy`).

---

## Pomiar wstępny (21.10, przed kodem)

- Budowa ubranego Piętra I w scenie gry: ok. 15 s; noc 1 ziarna 1: **185 eksponatów**.
- Krok fizyki bez nikogo w ruchu: **ok. 12 ms** (z eksponatami), **2,6 ms** bez eksponatów — śpiące eksponaty kosztują ok. 50 µs każdy na krok (do raportu jako znalezisko wydajności; #57 każe najpierw profilować — nie ruszam bez pomiaru w oknie).
- Noc = 7 h × 180 s = 1260 s gry = 75 600 kroków po 1/60 s → przy 12 ms ok. **15 min** na noc w czasie rzeczywistym. Stąd tryb szybki: `Engine.time_scale = k` przy `--fixed-fps 60` — liczba kroków na klatkę zostaje 1, krok fizyki trwa k/60 s gry (pomiar: koszt kroku prawie ten sam) → noc ok. 15/k min. Domyślnie **k = 4** (ok. 4 min na noc), `--time-scale=1` do przebiegu kontrolnego „1:1”. Ryzyko dużego kroku (tunelowanie pocisków, okna trafień) sprawdzam porównaniem przebiegów k = 1 i k = 4 na tym samym ziarnie (zadanie 8).

## Pliki

| Plik | Co robi |
|---|---|
| `tests/support/playthrough_brain.gd` (`PlaythroughBrain`) | czysta logika: droga przez obszary i bramy do celu (`ProgressRules`, zasuwa tylko od swojej strony), narzędzie na zamek, broń na odległość i amunicję, kiedy odwrót do przystani, kiedy przystań przed świtem, lista zakupów, wybór celu walki |
| `tests/support/playthrough_pilot.gd` (`PlaythroughPilot`) | „pad” bota: ruch w świecie → osie akcji względem głowy, obrót jak mysz (limit °/s), stuknięcia (E, skok, cios, przeładowanie, unik), wybór broni zdarzeniem `weapon_N`, spust |
| `tests/support/playthrough_nav.gd` (`PlaythroughNav`) | ścieżki po siatce gry (ciche zapytanie wstecz), prowadzenie, utknięcia i wyjścia z nich, miejsca do stania (E, strzał w zamek, cios) |
| `tests/support/playthrough_bot.gd` (`PlaythroughBot`) | agent: zadania (cel HUD → podzadania: droga, bramy, przedmiot, urządzenie, strażnik, T-Rex, zejście), walka, przystanie (odpoczynek, terminal), łup i latarnia, świt |
| `tests/support/playthrough_log.gd` (`PlaythroughLog`) | zdarzenia i próbki → `log.jsonl`, `report.json`, `report.html` |
| `tests/support/playthrough_report.gd` (`PlaythroughReport`) | strona HTML raportu (PL, bez skryptów): wynik, noce, strefy, walki według przeciwnika, rytm nocy, śmierci, postęp, zasoby w czasie (SVG), utknięcia, błędy silnika |
| `tests/scenarios/playthrough_scenario.gd/.tscn` | przebieg: ziarno, noce, skala czasu, pułapy, strażnik czasu (watchdog) |
| `tools/run_playthrough.sh` | uruchamia ziarna po kolei bez okna, zbiera wyniki, oblewa przy `ERROR` silnika |
| `tests/unit/test_playthrough_brain.gd` | TDD logiki decyzji |
| `tests/integration/test_playthrough_pilot.gd` | pilot porusza prawdziwym strażnikiem (ruch, obrót, E, wybór broni, strzał) |
| `tests/integration/test_playthrough_night1.gd` | mały przebieg do CI: noc 1 od świeżego zapisu do pierwszego strażnika |
| `tests/unit/test_playthrough_report.gd` | czas jako „h + min”, tarcza zegara nocy, strona ze wszystkimi sekcjami |
| `tests/integration/test_floor1_tombs.gd` + `src/game/floor1/floor_encounters.gd` | poprawka gry P2: trumny mumii z zasadzki w siatce nawigacji |
| ten plik | plan, wyniki przebiegów, znaleziska, „Stan prac” |

## Zasady „bez oszustw” (sprawdzane w kodzie bota)

1. Ruch: tylko akcje `move_*`, `sprint`, `jump`, `dash`; pozycja strażnika nigdy nie jest ustawiana.
2. Celowanie: tylko `Player.look(piksele)` (to samo, co ruch myszy), najwyżej `TURN_RATE` °/s.
3. Strzał/cios/E/przeładowanie/broń: akcje `fire`, `punch`, `interact`, `reload`, zdarzenia `weapon_N`.
4. Zdrowie i amunicja: tylko z gry (przystań, apteczki, zapasy, łup) — bot ich nie dotyka.
5. Wiedza: bot czyta stan świata jak „gracz z mapą i HUD-em” (cel HUD, przystanie, znaczniki przedmiotów, pozycje eksponatów w zasięgu wzroku/słuchu — pozycje znam z węzłów, to jest „aimbot”, dopuszczony zadaniem); nie zna ukrytych sekretów (nie szuka ich).
6. Menu: terminal ulepszeń — klik w wiersz (`_on_row_pressed`) i zamknięcie klawiszem E; ekrany śmierci/świtu — czeka.

## Zadania

### Zadanie 1: plan
- [x] Ten plik → commit.

### Zadanie 2: `PlaythroughBrain` (TDD)
**Pliki:** `tests/support/playthrough_brain.gd`, `tests/unit/test_playthrough_brain.gd`.
- [x] Droga przez obszary: z obszaru A do B najkrótsza po krawędziach `Floor1Plan` (przejścia + bramy wewnętrzne), bramy zamknięte, które trzeba otworzyć po drodze (z której strony), zasuwa tylko od swojej strony, wymaganie brane z `ProgressRules.has_requirement`; brak drogi → [].
- [x] Narzędzie na zamek: łańcuch/deski — strzelba (z bliska) albo pięść; deski — też wybuch; spękany mur — hwacha albo raca z ≤ 5 m; lina — sztucer, pistolet z ≤ 15 m; hak — harpun; zasuwa/pieczęć — E; zasilanie — nic (rozdzielnia).
- [x] Broń na cel: odległość, amunicja (magazynek + zapas), rodzaj celu (strażnik — słabe punkty; rój — strzelba), pięść/paralizator, gdy pusto.
- [x] Odwrót i świt: zdrowie < próg i brak wroga w zwarciu → najbliższa przystań; zostało < czas drogi + zapas → przystań przed świtem; odpoczynek nie częściej niż `REST_COOLDOWN`.
- [x] Zakupy: lista priorytetów (zdrowie, kieszenie, magnes Pyłu, wytrzymałość, ulepszenia posiadanej broni…), kupuje, co pokrywa Pył.
- [x] `--filter=playthrough_brain` zielone → commit.

### Zadanie 3: `PlaythroughPilot` + test
**Pliki:** `tests/support/playthrough_pilot.gd`, `tests/integration/test_playthrough_pilot.gd`.
- [x] Test (czerwony): strażnik w scenie gry (Piętro I bez oprawy) idzie naprzód i w bok akcjami, obraca się do punktu w limicie, E na szufladzie kasy daje klucz, `weapon_N` wybiera broń, spust strzela (magazynek maleje).
- [x] Kod → zielone → commit.

### Zadanie 4: `PlaythroughNav`
**Plik:** `tests/support/playthrough_nav.gd` (+ przypadki w teście pilota).
- [x] Ścieżka (zapytanie od celu do startu, bez `ERROR`), cele w przystaniach (warstwa HAVEN), prowadzenie z lookahead, utknięcie (brak postępu 1 s → skok, krok w bok, nowa ścieżka; po N razy → zdarzenie „stuck” z miejscem), miejsca do stania (E, strzał, cios).
- [x] Test: z kanciapy na dziedziniec i do szuflady kasy pieszo; commit.

### Zadanie 5: `PlaythroughBot` — agent
**Plik:** `tests/support/playthrough_bot.gd`.
- [x] Cel HUD → zadanie: przedmiot/broń (E, szafka, gablota — zbić szybkę i wziąć), urządzenie (rozdzielnia, astrolabium), brama po drodze (narzędzie z `PlaythroughBrain`), strażnik (start areny → walka → pieczęć i odłamek), T-Rex (kryształ → walka → krata), zejście.
- [x] Walka z eksponatami: przebudzone w zasięgu i w polu widzenia + śpiące tuż przy drodze; strzał tylko, gdy promień trafia cel pierwszy; dystans, krok w tył przed ciosem, przeładowanie w spokoju, zmiana broni przy pustym magazynku, pięść na końcu.
- [x] Strażnicy i T-Rex: krążenie w zasięgu areny, słabe punkty widoczne → strzał, inaczej ciało; zapasy faz, gdy brakuje zdrowia/amunicji.
- [x] Przystanie: odpoczynek (leczenie, zapis), terminal (zakupy), start nocy; łup (amunicja, apteczki) i latarnia, gdy blisko i potrzebne.
- [x] Commit.

### Zadanie 6: dziennik, raport, scenariusz, narzędzie
**Pliki:** `tests/support/playthrough_log.gd`, `tests/scenarios/playthrough_scenario.gd/.tscn`, `tools/run_playthrough.sh`.
- [x] Zdarzenia: start/koniec nocy (świt/śmierć/koniec), kroki postępu (czas gry), bramy, strażnicy (czas walki, obrażenia), śmierci (kto zadał ostatni cios, gdzie), utknięcia, zakupy, odpoczynki; próbki co 10 s gry: zdrowie, amunicja (pełne magazynki), Pył, strefa, sala, wrogowie przebudzeni.
- [x] Raport: noce, czas na noc i strefę, śmierci, zasoby w czasie, utknięcia/softlocki, błędy silnika (z wyjścia, przez narzędzie).
- [x] Narzędzie: `bash tools/run_playthrough.sh [ziarna…] [--time-scale=4] [--nights=12] [--grey]`; commit.

### Zadanie 7: test do CI
**Plik:** `tests/integration/test_playthrough_night1.gd`.
- [x] Noc 1 od świeżego zapisu (Piętro I bez oprawy, jak cały zestaw): bot zdobywa klucz, pistolet, racę i strzelbę i dochodzi do areny Kolosa (budzi go) — bez śmierci i bez utknięcia; czas w granicach.
- [x] `--filter=playthrough` zielone → commit.

### Zadanie 8: przebiegi i poprawki
- [x] Kilka ziaren (k = 4) + jedno kontrolne k = 1 → wyniki w tym pliku i w raporcie HTML (`tests/_out/playthrough/raport_wnioski.html`).
- [x] Błędy gry, które przebieg pokaże i które są ewidentnymi błędami: poprawka TDD, mała, jeden commit na błąd (P3 `eab7f877`, P4 `52328169`).
- [x] Znaleziska projektowe (rytm, presja zasobów, trudność) — lista dla właściciela, **bez** zmiany balansu (raport, rozdz. 7–8).

### Zadanie 9: całość
- [x] `git merge pietro-1`, pełny zestaw zielony (3296/0), żaden mój Godot nie zostaje, raport.

---

## Jak zbudowano (21.10) — odstępstwa i decyzje

| Co | Jak / dlaczego |
|---|---|
| Kolejność w kroku fizyki | węzeł bota ma `process_physics_priority = -100`: pilot naciska klawisze przed krokiem strażnika; obrót głowy (`Player.look`) zanim bot oceni, w co patrzy (`turn_now`), bo przy skali ×4 jeden krok to 0,37 m ruchu w bok (zwykły kąt celu był zawsze „za”) |
| Spust | bot **trzyma** spust, dopóki promień z oka po osi widoku trafia **w część, w którą celuje, albo w słaby punkt** (nie w tarczę hoplity); broń strzela we własnym tempie, kartaczownica rozkręca się, gdy spust trzymany; pusta broń — R (gra przeładowuje sama tylko przy pociągnięciu spustu) |
| Paralizator + pięść | twardy (≥ 100 zdrowia) albo osłonięty wróg (rycerz, hoplita) sam: paralizator z 5–6 m, potem pięść na ogłuszonego = dobicie (`can_finish`, leczy 15) — mechanika gry, bez której bot ginął od rycerzy i falangi hoplitów co noc |
| Ścieżki | zapytanie od celu do startu i odwrócone (zapytanie w drugą stronę na wyspę siatki drukuje `ERROR` — por. `NavProbe`); przystań: do drzwi po siatce chodzenia, w środku po siatce przystani, przez drzwi **prosto i od osi**, z długości skrzydła drzwi w głąb (siatka przystani nie zna otwartego skrzydła drzwi) |
| Przeszkody, których siatka nie zna | wpadnięcie na małą bryłę (≤ 3,5 m) → bot ją zapamiętuje na noc i obchodzi (punkty obok, na siatce); tak wyszło znalezisko P2 |
| Miejsca do stania | E: najbliższy punkt pudła rzeczy do oka (pieczęć Khorsabadu ma 8 m wysokości — środek był poza zasięgiem `Interactor.REACH`); strzał w zamek: pierścienie co ≤ 1,5 m, punkt co ~1,2 m po obwodzie, promień musi trafić strefę zamku **pierwszy**, stanowisko w obszarze, z którego idzie droga (hak czółna z dołu Ameryk, nie zza czółna); podłogi bramy: przejścia i obu jej sal |
| Po otwarciu bramy | „brak ścieżki”, gdy siatka wokół drzwi właśnie się przepieka (asynchronicznie) — bot czeka, nie liczy porażki |
| Zadania porzucone | blokada 45 s; gdy nic innego — najstarsza blokada zdjęta najwyżej raz na 15 s (wcześniej pętla 10 prób na sekundę = 44 ms na krok) |
| Przystanie | odpoczynek < 40 % zdrowia (bez wroga przy nim), ucieczka < 25 % (nawet z wrogiem przy nim, bo nie wejdą do przystani), przystań przed świtem (droga × 1,5 + 45 s), nieznaną przystań w promieniu 35 m — zajrzeć (zapis, start nocy); zakupy przy terminalu: lista życzeń, klik w wiersz menu jak gracz, zamknięcie klawiszem E |
| Pył | bot podchodzi do Pyłu leżącego ≤ 22 m (gaśnie po 30 s; magnes ma 6 m) — bez tego po 38 zabitych wrogach miał 0 Pyłu |
| Determinizm | ziarno gry (`GameState.seed_base`) i bota → ta sama noc (losowanie eksponatów, łupu); przebieg walk **nie** jest powtarzalny co do klatki: gra losuje rozrzut broni (`WeaponHolder._rng.randomize()`), mumie i inni swoje decyzje, a siatka przepieka się na wątkach — dwa przebiegi tego samego ziarna różnią się szczegółami (co raport pokazuje jako wariancję) |
| Tryb szybki | `Engine.time_scale = k` przy `--fixed-fps 60`: krok fizyki = k/60 s gry; domyślnie ×4 (przy obciążonym CPU noc to 5–18 min zamiast 15–70) |
| Błędy silnika | `Logger` w scenariuszu liczy błędy i ostrzeżenia (wątek-bezpiecznie), pierwsze 20 trafia do raportu; narzędzie i tak oblewa przebieg przy linii `ERROR` |
| Szpary siatki (22/23.10) | siatka trzyma agenta 0,5 m od każdej bryły, więc szpara węższa niż ok. 1,1 m jest dla niej zamknięta, a strażnik (0,8 m) przechodzi — podest astrolabium (łuki katalogu) był wyspą siatki. `PlaythroughNav`: gdy droga od celu kończy się przed strażnikiem, najpierw szpary przejdzione tej nocy (`bridges`; z kieszeni wychodzi tą samą drogą), potem szukanie: punkty siatki wokół końca drogi, kierunki ku końcowi drogi, ku celowi i 16 stron świata, pierwszy odcinek poza siatką → siatka za nim (≤ 3,2 m), kapsuła przechodzi, podłoga pod każdym krokiem, na obu końcach da się stać (`_free_at`: stanowisko audioprzewodnika), ostatnie 1,5 m dojść do obu końców wolne, nie po blatach mebli; w ostateczności wyjście z kieszeni, w której stoi, bez znanej szpary. Koszt: szukanie tylko dla przejścia, które bot naprawdę robi (nie dla szacunku długości), dla miejsc do stania tylko dla trzech pierwszych, gdy żadne nie ma zwykłej drogi; ≤ 360 prób; porażka pamiętana 240 kroków. Test `test_playthrough_nav_gap` |
| Ponowne planowanie | nieudana droga (pościg za kryształem, droga do wroga) planowana najwyżej raz na sekundę / raz na 0,6 s, nie co krok; droga do wroga zostaje, dopóki wróg nie odejdzie 1,5 m od jej celu (inaczej wykrywanie utknięcia nigdy nie dobiegało końca) |
| `--human` | przybliżenie gracza: obrót 300°/s (zamiast 540°/s), celowanie „pływa” ok. 1,6° (losowane co 0,35–0,7 s), strzał do nowego celu po 0,25–0,45 s, spust, gdy cel jest w ok. 3° od celownika (nie tylko, gdy promień trafia pierwszy); zamki i paralizator bez zmian; **nie** unika ataków strażników |

## Wyniki przebiegów (22/23.10, piętro ubrane, trudność „Nocna zmiana”)

Szczegóły, wykresy i wnioski: **`docs/raporty/2026-10-23-przejscie-bota.html`** (dla właściciela; to samo co `tests/_out/playthrough/raport_wnioski.html`); raporty pojedynczych przebiegów: `tests/_out/playthrough/<ziarno>/report.html`, rundy wcześniejsze w `_r0` … `_r3`, `_h0`.

| Przebieg | Wynik | Noce | Czas gry | Czas rzecz. | Śmierci | Utknięcia | Błędy silnika |
|---|---|---|---|---|---|---|---|
| ziarno 1, ×4 | przeszedł piętro (20/20) | 1 | 14 min 02 s | 3 min 14 s | 0 | 22 | 0 |
| ziarno 2, ×4 | przeszedł piętro (20/20) | 1 | 14 min 16 s | 2 min 58 s | 0 | 3 | 0 |
| ziarno 3, ×4 | przeszedł piętro (20/20) | 1 | 13 min 26 s | 2 min 53 s | 0 | 22 | 0 |
| ziarno 1, ×1 (cała noc) | przeszedł piętro (20/20) | 1 | 16 min 02 s | 7 min 32 s | 0 | 0 | 0 |
| ziarno 1, ×1 `--until=colossus` (runda 1) | Kolos po 1 min 27 s | 1 | 1 min 27 s | 1 min 04 s | 0 | 0 | 0 |
| ziarno 1, ×4 `--human` | przeszedł piętro (20/20) | 4 | 27 min 07 s | 12 min 27 s | 3 (Kolos ×2, figura woskowa) | — | 0 |
| ziarno 2, ×4 `--human` | nie przeszedł: pętla śmierci przy Kolosie (latarnia z Pyłem w jego sali) | 6 | 3 min 37 s | 2 min 22 s | 6 (Kolos) | — | 0 |
| ziarno 3, ×4 `--human` | przeszedł piętro (20/20) | 2 | 19 min 46 s | 4 min 09 s | 1 (raptor, 2 s po upadku T-Reksa) | — | 0 |

- ×4 a ×1 (ziarno 1): te same kroki i kolejność, całe piętro 14 min 02 s / 16 min 02 s; przy ×4 bot obrywa ok. 3× więcej (156 / 48 punktów, 14 / 3 trafienia) — skala ×4 nadaje się do drogi i tempa, ×1 do presji zdrowia.
- Aimbot: strażnicy w 2–14 s, T-Rex 31–81 s; zdrowie najniżej 55–88 %; naboje po pierwszej minucie średnio 108–122 % ładunku startowego; 14–17 poziomów ulepszeń w 3–4 wizytach przy terminalach, 173–386 Pyłu niewydane na koniec.
- `--human`, ziarno 1, noc 3 (ta, w której robił postęp): 1063 punkty obrażeń w 66 trafieniach, 2 odpoczynki, zdrowie do 1 %, naboje średnio 59 % ładunku startowego; strażnicy 11–59 s, T-Rex ok. 100 s.
- Historia rund: runda 0 — wszystkie ziarna 17/20 w nocy 1, potem „brak drogi do astrolabium” (wyspa siatki); runda 1 — ziarno 1 całą noc w kieszeni siatki w Egipcie, ziarno 2: 24 utknięcia na metopie Kentaura (P4), kontrolny „do Kolosa” — przepełnienie stosu przy zatrzymaniu (poprawione); runda 2 — 3/3 przeszły piętro w 1 noc, ale czas myślenia bota 22–27 ms na krok, a ×1 stracił noc przy stanowisku audioprzewodnika (P5); runda 3 i końcowa — 3/3 w 1 noc, bot ok. 3 ms na krok.

### Wyniki wstępne (21.10, przed wstrzymaniem)

- Ziarno 1, piętro szare, ×4 (przed taktyką paralizator + pięść): śmierć w każdej z 3 nocy (mumie, hoplici, rycerze), 5–10 kroków.
- Ziarno 1, szare, ×4 (z taktyką): **noc 1 bez śmierci do świtu, 16 z 20 kroków** (do Generała włącznie, ok. 15 min gry), potem pętla na haku czółna (naprawiona).
- Próba od herbaciarni (stan zapisu jak po nocy 1): hak czółna z dołu Ameryk → Wąż → astrolabium → T-Rex → zejście do krypty w **5 min 11 s gry** (koniec piętra osiągnięty w grze, bez okna).
- Ziarno 1, **ubrane**, ×4: noc 1 bez śmierci do świtu, 10 kroków (do Kentaura), 7 min 32 s rzeczywistych; noc 2 — pętla na łańcuchu kartaczownicy (naprawiona w `3540b8ed`). Pełne przebiegi ziaren 1–3 (ubrane) przerwane poleceniem kontrolera — **nie ma jeszcze raportu z pełnego przejścia**.
- Obserwacje do raportu (wstępne): bot z celnością „aimbota” przechodzi drogę krytyczną dużo szybciej niż model W7 (57 min) — kroki 1–16 w ~15 min gry; rycerze, falanga hoplitów i mumie zabijają bota bez paralizatora i dobicia (gracz, który nie zna tej mechaniki, zderzy się z tym samym); Pył wypada wystarczająco (po nocy 1 kupione 9–14 poziomów ulepszeń).

## Znaleziska

| # | Obszar | Problem | Stan |
|---|---|---|---|
| P1 | wydajność | śpiące eksponaty: ok. 50 µs na eksponat na krok fizyki bez okna (185 eksponatów nocy 1 ≈ 9 ms na krok; pusta scena 2,6 ms) | do pomiaru narzędziem `tools/run_cpu_profile.sh` (gałąź dev-tools) i w oknie (#57); bez zmian |
| P2 | nawigacja, Egipt | trumny, które mumie z zasadzki stawiają co noc na swoich posterunkach (`Mummy._settle_in_tomb`), są geometrią poziomu (blokują strażnika), ale nie były źródłem siatki: siatka szła przez nie — w galerii Egiptu między cokołem a biurkiem zostawała szczelina węższa niż strażnik; bot i eksponaty planowały drogę przez trumnę | **poprawione** (`FloorEncounters._adopt_tombs`: trumny wśród eksponatów → `add_walk_source`, jak cokół gablotki i Lamassu); mumia nadal kładzie się w swojej (siatka kończy się 0,9 m od środka, `EnemyBrain.ARRIVE` 1,2 m); test `test_floor1_tombs` |

| P3 | błąd gry, Kolos | `ColossusFall` zabierał model Kolosa razem z jego `Hurtbox`ami, których odbiorcy (`GuardianZone`) znikali z Kolosem: każdy promień w spadające kamienie trafiał w zwolniony obiekt (`EnvLayer._check_hint`: „Left operand of is is a previously freed instance”, 48 razy w rundzie 0; to samo sprawdzenie `is` jest w strzale gracza, `WeaponHolder`) | **poprawione** `eab7f877` (strefy zdjęte z modelu jak w upadkach pozostałych strażników); test w `test_colossus` |
| P4 | błąd gry, Grecja | metopa Kentaura (`CentaurMetope`, bryła poziomu na środku Galerii Partenonu, co noc) nie była źródłem siatki: siatka szła przez płytę, drogi bota i eksponatów wchodziły w kamień (ziarno 2: 24 utknięcia) | **poprawione** `52328169` (`Centaur.dress_arena` → `add_walk_source`, jak cokół Lamassu, QA Q4); test `test_its_metope_is_cut_out_of_the_navmesh` |
| P5 | błąd gry (siatka) + układ sali, Czytelnia | stanowiska audioprzewodnika (`AudioguideStand`, 12 na piętrze) są bryłami, ale nie źródłami siatki; to przy astrolabium (0 / −4) stoi w wylocie północnej szpary między łukami katalogu — eksponaty i bot planują drogę przez nie (×1: 205 utknięć, noc stracona) | **poprawione** na gałęzi `fix-guide-stands` (decyzja kontrolera, 23.10): `WorldFeatures` dodaje stanowiska do źródeł siatki (`add_walk_source`), stanowisko w grupie `AudioguideStand.GROUP` (głos dostaje stanowisko przez E, nie po ścieżce węzła); test `test_guide_stands_navmesh` (siatka omija każde z 12, droga obok stanowiska je okrąża, E nadal gra przystanek, strażnik wchodzi na podest astrolabium); ustawienie stanowiska przy astrolabium bez zmian (układ sali — właściciel, P6) |
| P6 | układ sali, Czytelnia | podest astrolabium jest wyspą siatki: szpary między łukami katalogu 1,0–1,2 m (strażnik 0,8 m przechodzi, agent siatki 1,0 m nie); przy ×4 bot przechodził z utknięciami | bot poprawiony; **do sprawdzenia w oknie** i do decyzji właściciela (raport, rekomendacja 2) |
| P7 | projekt | latarnia z Pyłem leży tam, gdzie strażnik zginął — także w arenie strażnika; jej odzyskanie budzi strażnika: `--human` ziarno 2 zginął tak 6 nocy z rzędu | lista dla właściciela (raport, rozdz. 5) |

## Stan prac / co dalej

- 21.10: plan, pomiar wstępny; zadania 1–7 zrobione (mózg, pilot, nawigacja, agent, dziennik, raport HTML, scenariusz, `tools/run_playthrough.sh`, test CI `test_playthrough_night1`); poprawka gry P2 (`d0053f8e`).
- 22/23.10 (noc, tryb nocny): **zadanie 8 zrobione** — przebiegi ziaren 1–3 (×4), kontrolne ×1, `--human`; poprawki gry P3, P4 (TDD); poprawki bota: szpary siatki i kieszenie (`eefeab49`, `5c91056c`, `8f847503`), nieudane drogi planowane raz na sekundę, `--until` bez rekursji, droga do wroga trwała (`7d6e0909`), tryb `--human` (`4cb4c8b6`); scalenie `pietro-1` (`26dec4be`); raport dla właściciela `tests/_out/playthrough/raport_wnioski.html` (poza repozytorium) i jego kopia w repozytorium: **`docs/raporty/2026-10-23-przejscie-bota.html`**. Po drugim scaleniu `pietro-1` (`69146d87`) kontrola ziaren 1–3 przy ×4: 3/3 przejścia w jedną noc (13 min 11 s – 13 min 40 s), bez śmierci i błędów silnika.
- **Zadanie 9 zrobione:** scalenie `pietro-1` (`26dec4be`, `69146d87`, `8d47e009`), pełny zestaw jednoprocesowo na `8d47e009` (trzecie scalenie): **3296/0** (33 min 11 s; wcześniej `69146d87`: 3271/0, `26dec4be`: 3246/0); kontrola ziarna 2 przy ×4 na `8d47e009`: przejście w 1 noc (12 min 32 s). Dzienniki zestawu: `tests/_out/playthrough-bot/`. Żaden mój Godot nie został.
- P5 poprawione na `fix-guide-stands` (23.10): filtry głos/przewodnik/nawigacja/playthrough 187/0, pełny zestaw 3380/0; bot ×4 na ziarnie 1: raz 2 noce z 1 śmiercią (Kolos — bot stał tam, gdzie nie widział ureusza i dostawał promieniem; wariancja walki), powtórka ziarna 1 i ziarno 2: 1 noc, 0 śmierci, 20/20. Nie zrobione: bot nie unika zapowiadanych ataków strażników (tylko T-Reksa) i nie wycofuje się z areny — przy `--human` to główna przyczyna śmierci; bot kupuje tylko przy przystaniach po drodze (stąd Pył niewydany na koniec).
- Uwaga dla wykonawcy: `TaskStop` zadania w tle nie zabija Godota ani pętli `run_playthrough.sh` — zabijać po `CommandLine` z nazwą drzewa (`taskkill /T`). Kilka ziaren naraz: raz `--import`, potem osobne procesy Godota (ok. 3 GB każdy).

## Do sprawdzenia w oknie

- P2: w galerii Egiptu (ok. −41 / −3) trumna mumii stojąca między cokołem a biurkiem — czy eksponaty ją obchodzą i czy mumia po polowaniu kładzie się z powrotem do trumny (siatka kończy się teraz ok. 0,9 m od jej środka).
- Przebieg bota w oknie (zrzuty) — nie robiony (zakaz okien w tej sesji).
- P6: podest astrolabium w ubranej Czytelni — czy gracz wygodnie przechodzi szpary między łukami katalogu (ok. 1,1 m) i czy stanowisko audioprzewodnika w wylocie północnej szpary nie przeszkadza (finał startuje z podestu).
- Kieszeń siatki w galerii Egiptu (ok. −47 / 0): co ją zamyka i czy łup, który tam leży, jest dla gracza osiągalny bez kombinowania.
- **Przegląd w oknie 23.10**: nie sprawdzone (czas; `2026-10-22-przeglad-w-oknie.md`).
