# Integracja — pełna noc w lobby (od kanciapy do T-Reksa i końca dema)

> Plan wykonawczy. Wykonawca: Claude (integrator rozgrywki, osobny worktree, gałąź z `etap-1a-piaskownica`).
> Projekt nadrzędny: `docs/superpowers/specs/2026-09-30-etap-2-projekt.md` (§5–§9, §14), `docs/superpowers/specs/2026-10-01-rozbudowa-projekt.md` (§4 — zegar nocy), `docs/Nocna-Zmiana-specyfikacja.md` (§5–§7). Uwagi integracyjne z końców planów 2a, 2b-1 i 2c-1.
> Poziom jakości: demo na Steam — noc ma być kompletna, uczciwa i emocjonująca.

**Cel:** lobby staje się grą. `Museum` buduje `LobbyLevel` z nocą wylosowaną przez `NightDirector`, stawia eksponaty (także popiersia), łupy, przystanie, bronie (szafka z pistoletem na klucz z kasy, strzelba w ukrytej gablocie), modyfikator nocy i zegar 23:00→6:00. Cel nocy prowadzi przez bezpieczniki → skrzynkę przy kracie → pulsujący kryształ → lot kryształu przez drzwi do holu → przebudzenie T-Reksa → walkę → otwarcie kraty → schody w ciemność → koniec dema. Najpierw wszystkie poprawki z przeglądu 2b-1 (LA1–LA10, LB1–LB9).

**Równolegle (nie ruszać głęboko):** poprawki 2a (`src/game/scene_flow.gd`, `src/state/*`, `src/core/save_*`, `src/core/settings*`, `src/ui/*` poza `hud.gd`) — po ich scaleniu do `etap-1a-piaskownica` scalam i dopasowuję (dane wznowienia nocy); integrator I2 — sekrety, notatki, artefakty, CCTV w `src/world/*` z wejściem `LobbyFeatures.install(level, museum)`; agent dźwięku (autoloady Music/Ambience); agent grafiki (modele).

## Konwencje

- Godot 4.7.2 (`tools/godot` = połączenie katalogów, poza gitem). Testy: `bash tools/run_tests.sh` (≈ 40 s, `--fixed-fps 60`); przebieg nieudany przy porażce **albo** linii `ERROR`/wycieku.
- GDScript z typowaniem statycznym, tabulatory, identyfikatory i komentarze po angielsku, teksty dla gracza przez `tr()` z `locale/strings.csv` (`keys,pl,en`, porządny angielski). Nowe klucze tylko z przedrostkami sprawdzanymi przez `test_localization.gd` (`HUD_`, `PROMPT_`, `NIGHT_`).
- Transformacja ustawiana przed `add_child` (interpolacja fizyki); statystyki eksponatów (pełnia) też przed `add_child`.
- Okienkowe uruchomienia: cicho (`--audio-driver Dummy`) i `--windowed`.
- Commit po każdym zadaniu, druga linia `-m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`; tylko własne pliki (nigdy `git add -A`, nigdy `tools/godot`). Zestaw zielony po każdym zadaniu.

## Architektura nocy

```
Museum._ready
  NightRules.start_night ── RunState (ziarno nocy, niesiony Pył)
  NightDirector.plan(ziarno, noc, LobbyLayout.describe) ──► NightConfig
  LobbyLevel (night = config przed build(); boss_stand_in = false) ── build()
  NightModifiers.apply(level, config.modifier, RunState)      światła, ambient, księżyc, mnożnik Pyłu
  Haven × haven_zones, UpgradeTerminal × haven_spots, strażnik w przystani startowej
  NightSpawner.spawn(config, sloty, rodzic, strażnik, statystyki)   popiersia = Bust
  łupy z config.loot (amunicja/apteczki; artefakty zostawia I2)
  wznowienie nocy (2a): indeksy slotów i punktów łupu; cel i zegar w RunState.used
  LobbyArmory — strzelba w niszy (klucz, szafka z pistoletem, notatki: LobbyFeatures, I2)
  NightObjective — bezpieczniki → skrzynka → kryształ → lot → boss → krata → schody → koniec dema
  NightClockDriver — NightClock (23:00→6:00, 3 min/h), godzina duchów, świt, pauza w przystani ≤ 60 s
  Onboarding — podpowiedzi nocy 1 (raz, zapamiętane w hints.cfg)
  Hud — cel, bezpieczniki, zegar, karta nocy, pasek bossa, podpowiedzi
  LobbyFeatures.install(level, self)  ← I2 (wywołanie warunkowe przez ResourceLoader)
```

**Etapy celu (`NightObjective.Stage`):** `FUSES` (0–2 znalezione/włożone) → `PULSING` (światła holu gasną, krata 0,4 m i zacięta, kryształ pulsuje) → `FLIGHT` (strażnik ≤ 3 m od gabloty: szkło pęka, kryształ leci trasą z grafu pomieszczeń, 6 m/s, czeka, gdy strażnik > 14 m) → `BOSS` (kryształ w gnieździe, `boss.wake()`, hol zamknięty, zaopatrzenie) → `DESCEND` (boss pokonany: krata rozsuwa się, drzwi holu się otwierają, schody w ciemność) → `DONE` (wejście w ciemność = `DemoEnd`).

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/game/museum.gd` | (zmiana) noc na `LobbyLevel`: reżyser, modyfikator, eksponaty, łupy, przystanie, bronie, cel, zegar, podpowiedzi, HUD, świt, koniec dema, wejście I2 |
| `src/game/night_modifiers.gd` | `NightModifiers`: awaria prądu, pełnia, spokojna noc; mnożnik statystyk eksponatów; opis dla karty nocy |
| `src/game/night_clock.gd` | `NightClock` (czysta logika): czas nocy, godzina, godzina duchów, świt, limit przystani |
| `src/game/night_objective.gd` | `NightObjective`: etapy celu, bezpieczniki, skrzynka, kryształ, boss (przywołanie, zaopatrzenie), krata, wyjście |
| `src/game/fuse_pickup.gd`, `fuse_box.gd` | bezpiecznik (E), skrzynka bezpieczników przy kracie (E) |
| `src/game/crystal_relic.gd` | kryształ: uśpiony w gablocie, pulsowanie (światło, bicie serca), pęknięcie gabloty, lot ze smugą, czekanie |
| `src/game/crystal_route.gd` | `CrystalRoute` (czysta logika): punkty lotu z grafu pomieszczeń (drzwi, wysokość przelotu, podejście do żeber) |
| `src/game/undercroft_exit.gd` | strefa w ciemności schodów — koniec dema |
| `src/game/lobby_armory.gd` | strzelba w niszy za tabliczką (klucz, szafka z pistoletem i notatki należą do świata I2) |
| `src/game/night_watch.gd`, `prop_kit.gd` | zegar nocy w grze (HUD, przystanie, godzina duchów, świt); szare rekwizyty nocy |
| `src/game/onboarding.gd` | podpowiedzi nocy 1 (latarka F, interakcja E, cel „znajdź bezpieczniki”), zapamiętane |
| `src/ui/dawn_screen.gd` | ekran „ŚWIT” (nowy plik, wzorowany na `DeathScreen`) |
| `src/ui/hud.gd` | (zmiana) cel + ikony bezpieczników, zegar, karta nocy, pasek bossa, podpowiedzi |
| `src/level/*` | poprawki LA1–LA10; `LobbyLevel.boss_stand_in`, klatka schodowa pod kratą, krata z dwóch skrzydeł (zacięcie 0,4 m, rozsuwanie) |
| `src/enemies/enemy.gd`, `crowd.gd`, `bust.gd` | poprawki LB1–LB4, LB7, LB9; `freeze()` na świt; mnożnik statystyk |
| `src/game/night_director.gd`, `night_spawner.gd`, `night_config.gd` | poprawki LB1, LB4–LB7 |
| `src/core/events.gd` | (dopisane) `night_started`, `objective_changed`, `power_cut`, `witching_hour`, `dawn_broke` |
| `src/progression/night_rules.gd` | (dopisane) `on_dawn()` |
| `src/fx/sfx.gd`, `tools/sfx/gen_sfx.py`, `assets/sfx/*.wav` | nowe dźwięki nocy (osobny blok na końcu listy) |
| `tests/scenarios/night_scenario.gd` + `.tscn`, `tools/run_night.sh` | zrzuty pełnej nocy do `tests/_out/night/` + pomiar FPS walki w holu |

## Zadania

### Zadanie 1 — ten plan
Commit dokumentu.

### Zadanie 2 — przegląd 2b-1, część A: skorupa, krata, schody, metadane (LA1–LA5)
- **LA1** `ShellCarver._open_cell`: pod najniższą wolną przestrzenią kolumny (próg przejścia wyżej niż podłoga sąsiada) dochodzi ściana od najniższej podłogi sąsiedztwa do spodu progu — koniec dziury w pustkę pod `panel_vent_out`. Test jednostkowy (przejście na wysokości 6 m między pokojami z podłogą 0) + test szczelności całego lobby (przeniesiona logika sondy `carve_check`: zero przecieków bocznych, zero pionowych, zero nakładań).
- **LA2** krata = dwa skrzydła; `jam()` unosi je o 0,4 m (zacięte, przejście dalej zamknięte), `open()` rozsuwa je w bok do kieszeni w ścianie północnej. Test: otwarta krata nie zasłania przejścia do składziku; zacięta zostawia 0,4 m szczeliny, a nawigacja jest dalej przecięta.
- **LA3** schody: liczba stopni z danych (`StairsSpec.step_count()`) trafia do wyglądu (`LevelKit.make(..., params)`, metadana `kit_steps`); test: rysowane stopnice vs trafienia promieni w rampę ≤ wysokość stopnia.
- **LA4** metadane dla etapu 3: `kit_room` i `kit_role` (rola materiału) na każdym elemencie, `kit_tint` także przy podmianie na grafikę; rzeźbiarz podaje rekordy lic ścian (`ShellCarver.wall_faces()` → pokój, normalna, prostokąt); wspólne ściany biorą wygląd pokoju niesekretnego (koniec ciemnego pasa zdradzającego szyb wentylacyjny); oprawy świateł z prawdziwymi rozmiarami.
- **LA5** znaki wyjścia nie wchodzą w niskie stropy (≤ sufit − 0,25 m); test „lampa w swoim pomieszczeniu” obejmuje światła awaryjne.

### Zadanie 3 — przegląd 2b-1, część A: drzwi, światła, zderzacze (LA6–LA10)
- **LA6** drzwi nie zamykają się na ciele (strażnik/eksponat w świetle przejścia) — ponowna próba co 0,4 s.
- **LA7** `apply_night()` przywraca też panele i kratę (zamknięte, odblokowane) — noc na tym samym poziomie jest czysta.
- **LA8** natychmiastowe pozy drzwi nie emitują `moving` i resetują interpolację fizyki.
- **LA9** lampy kolumn: cień `DUAL_PARABOLOID`; lampy bez cieni, których zasięg wychodzi poza pomieszczenie, nie świecą we mgle (`light_volumetric_fog_energy = 0`); pomieszczenia sekretne oświetlone reflektorem w dół o zasięgu, który nie przechodzi przez ścianę.
- **LA10** krata: zderzacz na każdy pręt (pociski przelatują między prętami, ciała nie); kolumna: walec o promieniu rysowanego trzonu + cokół; skrzydła podwójnych drzwi po otwarciu leżą przy ościeżach, nie wchodzą w nie.

### Zadanie 4 — przegląd 2b-1, część B: eksponaty i tłum (LB1–LB4, LB7 w `Enemy`/`EnemyCrowd`, LB9)
- **LB1** `NightSpawner`: `brain.wake()` przebudzonych **przed** `add_child` — nie budzą sąsiadów przy starcie; test na wielu ziarnach: stan każdego eksponatu = wylosowany.
- **LB2** brak uników „utknięcia” u walczącego w pierścieniu bliżej niż 3,5 m celu.
- **LB3** pierścień tylko z linią wzroku i na tym samym piętrze (|dy| ≤ `SAME_FLOOR`).
- **LB4** popiersie na siatce: `path_height_offset = −hover`; bramka osiągalności tylko dla walczących wręcz (`_attacks_from_range()`), porównanie końca ścieżki poziomo + tolerancja pionowa, popiersie zawsze odświeża osiągalność; `NightSpawner`: `&"bust"` → `Bust`.
- **LB7 (część)** podmieniony cel pierścienia w polu; `push_for` tylko po ścigających, bez alokacji `keys()` co klatkę; najbliższy punkt tylko na regionach warstwy chodzenia; próg śmierci z poziomu (`Level.kill_plane_y`); `LevelNavigation.WALK_LAYER` zamiast 1; jawny `cell_size`; `EnemyCrowd.join` w `_enter_tree`.
- **LB9** `face()`/`_face_towards()` w układzie świata (obrócony rodzic).
- **LB8** testy: > 10 walczących wręcz (czekają, nie tańczą), pierścień między piętrami, popiersie na siatce strzela.

### Zadanie 5 — przegląd 2b-1, część B: reżyser nocy (LB5–LB7)
- **LB5** klucz woźnego tylko w noce z zamkniętymi drzwiami, z szansą ~70%, tylko w osiągalnej (przy zamkniętych drzwiach) niesekretnej gablocie, nigdy w miejscach „zawsze artefakt”.
- **LB6** nigdy nie zamyka drzwi na trasie kryształu do holu (trasa z grafu pomieszczeń).
- **LB7** ostrzeżenie + test przy za małej liczbie punktów łupu.

### Zadanie 6 — Muzeum na lobby
`Museum.build_level()` → `LobbyLevel` (bez statycznej atrapy T-Reksa); plan nocy z reżysera przed `build()`; eksponaty z `NightSpawner` (z `slot_<n>` w metadanej), łupy z `config.loot` (`loot_<n>`; artefakty zostawione dla I2 w `museum.artifact_spots()`), przystanie ze stref poziomu, start w przystani startowej (składzik tylko gdy odkryty), `NightProgress`. Testy (`test_museum.gd` przepisany na lobby): kontrakt, start w kanciapie, eksponaty = plan (także popiersia), łupy = plan, przystań leczy i zapisuje, pistolet zostaje na zawsze, wyjście zapisuje Pył, śmierć → latarka, brak wycieków węzłów.

### Zadanie 7 — modyfikatory nocy
`NightModifiers.apply()`: **awaria prądu** — grupa `main_lights` i ich oprawy wyłączone w całym lobby (oprawy ciemne), ambient × 0,3; **pełnia** — księżyc × 1,6 i bardziej niebieski, eksponaty +25% zdrowia i obrażeń (przed `add_child`), Pył × 1,5 przez `RunState.set_multiplier`; **spokojna noc** — przerzedzenie w reżyserze (już jest). HUD: karta nocy na starcie („NOC 3” + nazwa i opis modyfikatora, ~4,5 s). `Events.night_started(night, modifier)` dla muzyki.

### Zadanie 8 — bronie w lobby
Szafka w kanciapie (znacznik `pistol_locker`): zamknięta bez `GameState.pistol_key` („Zamknięte na klucz”, dźwięk odmowy); z kluczem otwiera się i odsłania pistolet (`WeaponPickup`). Klucz w szufladzie kasy (`ticket_drawer`): E → „Klucz do szafki na broń”, `pistol_key = true`, zapis. Notatka nocy 1 na biurku (`note_1`): prosty zaczep tylko, gdy nie ma `LobbyFeatures` (I2). Strzelba: `WeaponPickup` w niszy (`shotgun_case`; fałszywa ściana z tabliczką należy do I2). Znalezione bronie i klucz przeżywają noce (zapis).

### Zadanie 9 — cel nocy, część 1: bezpieczniki i kryształ
Bezpieczniki w wylosowanych punktach (świecący bezpiecznik na skrzyni, E) → `RunState.fuses_carried`; skrzynka przy kracie (E) wkłada niesione (`RunState.fuses`). Po dwóch: przekaźnik, gasną główne światła holu i balkonu (awaryjne zostają), krata unosi się o 0,4 m i zacina, kryształ w wylosowanej gablocie pulsuje (czerwone światło, bicie serca słyszalne do ~25 m), HUD: „Znajdź źródło pulsowania”. `RunState.crystal_phase` = `PULSING`. Testy: podniesienie, włożenie, zgaszenie tylko głównych świateł holu, zacięcie kraty, pulsowanie, HUD.

### Zadanie 10 — cel nocy, część 2: lot, boss, krata, koniec dema
Strażnik ≤ 3 m: gablota pęka, kryształ unosi się i leci trasą `CrystalRoute` (6 m/s, czeka, gdy strażnik > 14 m, świetlista smuga) do `boss.skeleton.crystal_position()` → `boss.wake()` (`RunState.crystal_phase` = `EMBEDDED`). T-Rex na postumencie wg 2c-1 (`(0,5; 1,25; −11)`, `PI/2`). Hol zamyka się (drzwi holu zablokowane na czas walki), zaopatrzenie w holu (amunicja, apteczka; dodatkowe przy fazach 2 i 3). `boss.summon` budzi uśpione figury woskowe z holu i dostawia nowe w slotach holu z dala od strażnika. HUD: pasek bossa przez `Events.boss_awakened`. `Events.boss_defeated` → `stats.bosses++`, `demo_complete`, zapis, krata rozsuwa się, drzwi holu wracają, cel „Zejdź do podziemi”; wejście w ciemność schodów → `DemoEnd`. Ponowne „Kontynuuj” po pokonaniu bossa: noc-epilog (bez bossa, krata otwarta).

### Zadanie 11 — zegar nocy
`NightClock`: 23:00 → 6:00, 3 min na godzinę. 3:00 — godzina duchów: komunikat, `Events.witching_hour`, eksponaty +20% szybkości i obrażeń (także nowe). 6:00 — świt: eksponaty zamierają i szarzeją, światło świtu, noc kończy się bez śmierci (`NightRules.on_dawn`: Pył zostaje, bez latarki, bezpieczniki i kryształ przepadają, noc +1), ekran „ŚWIT”. Zegar stoi w menu/pauzie i w przystani (do 60 s na wizytę). Pokonanie T-Reksa kończy demo bez względu na godzinę.

### Zadanie 12 — wprowadzenie (noc 1)
Krótkie podpowiedzi kontekstowe, każda raz (zapamiętane): latarka (F) na starcie nocy 1, interakcja (E) przy pierwszym obiekcie w zasięgu, „znajdź bezpieczniki” po wyjściu z kanciapy. Bez ścian tekstu.

### Zadanie 13 — testy całej nocy
Test integracyjny bez okna: start w lobby → oba bezpieczniki → skrzynka → podejście do kryształu → lot dociera → boss przebudzony → zabicie bossa przez jego API → krata otwarta → koniec dema. Test świtu. Dymny test wielu nocy: noce 1–5 × 20 ziaren — budowa + eksponaty bez błędów.

### Zadanie 14 — weryfikacja wizualna i FPS
`bash tools/run_night.sh shots` (okno, cicho) → `tests/_out/night/`: start w kanciapie, hol z eksponatami, skrzynka/zgaszenie, pulsujący kryształ, smuga lotu, przebudzenie bossa, walka (szeroki kadr), otwarta krata i schody, świt, awaria prądu. Obejrzeć i poprawić. `bash tools/run_night.sh perf` — FPS walki w holu przy 1920×1080.

### Zadanie 15 — eksport i podsumowanie
`bash tools/export.sh` przechodzi, exe startuje w menu (bez okna). Wyniki i uwagi integracyjne poniżej.

### Zadanie 16 — zawartość rozbudowy w lobby (po scaleniu `120326e`)
Haczyki z `2026-10-01-zawartosc.md` („Haczyki do podpięcia”) podpięte w grze:
- **Portrety:** 12 miejsc na obrazy (`LobbyLayout.PORTRAIT_SPOTS`: 8 w galerii — ściany północna, południowa i od holu; 4 nad bocznymi balkonami), znaczniki na licu ściany, −Z do sali. `NightDirector` losuje z nich 2–4 portrety (**ostatnie losowanie nocy** — reszta nocy bez zmian), `NightConfig.portraits`. Muzeum wiesza w każdym miejscu zawsze tę samą twarz (`PaintingArt.ids()[i % n]`): portret (`Portrait`, eksponat nocy, strojony jak inne) albo zwykły obraz (`WallPainting`). Zniszczony portret: `RunState.used` `portrait_<miejsce>` — po „Kontynuuj” pusta ściana.
- **Raptory:** rodzaj `raptor` w slotach holu (zestaw 1: przy ławkach południowych, zestaw 2: przed postumentem) i balkonu (zestaw 0: północny pas). Slot raptora to **całe stado** 3–4 (`NightSpawner.pack()`, `pack_size()` z ziarna nocy), strony flankowania na przemian, każdy z indeksem slotu; slot jest „zabity” dopiero z ostatnim raptorem stada. `NightSpawner.exhibit_count(config)` — ile eksponatów stawia noc.
- **Ryk T-Reksa:** `NightObjective.summon()` — z szansą 0,5 stado raptorów w jednym z narożników holu ≥ 8 m od strażnika (`summon_raptors`), inaczej figury woskowe (`summon_wax`).
- **Kartaczownica na łańcuchu** (`ChainedDisplay`, znacznik `gatling_display` w zbrojowni (30; 0; 7), tabliczka ku drzwiom z holu) — pod `walk_region`, więc postument jest przeszkodą nawigacji (przebudowa siatki po ustawieniu). **Szafka ratunkowa z rakietnicą** (`EmergencyCabinet`, znacznik `flare_cabinet` na ścianie dioramy od holu (5; 1,4; 24)). Obie w `LobbyArmory`.
- **Łup:** wagi `bullets 38, shells 20, rifle 12, flares 8, medkit 22`; taśma 60, flary 2. `Museum.loot_for_guard()`: taśma → naboje, flary → śrut, dopóki strażnik nie ma kartaczownicy / rakietnicy (decyzja przy rozkładaniu łupu na początku nocy).
- Testy `test_lobby_content` (7) + portrety w `test_night_director`, stado w `test_lobby_night`; zrzuty `gallery_paintings`, `portrait_awake`, `raptor_pack`, `gatling_display`, `flare_cabinet`.

## Odstępstwa od projektu

**Przebieg prac**
1. **Poprawki przeglądu w dwóch commitach, nie czterech:** LA1–LA10 dotykają tych samych plików (`door.gd`, `level_kit.gd`, `shell_carver.gd`), LB1–LB9 — `enemy.gd`, `crowd.gd`, reżysera; zadania 2–3 i 4–5 poszły więc jako jeden commit każde (`5c4c183`, `12ced1d`).
2. **Bronie (zad. 8) po scaleniu I2:** szuflada kasy z kluczem, szafka z pistoletem i notatka Heńka należą do świata I2 (`LobbyFeatures`, polecenie koordynatora); moje wersje (`PistolLocker`, `KeyDrawer`, `NoteHook`) usunięte przy scaleniu (kolizja nazw klas). `LobbyArmory` stawia już tylko strzelbę. Strzelba leży **przed** gablotą w niszy (szklana bryła gabloty jest pełna — promień interakcji by do niej nie dotarł).
3. **Dane wznowienia nocy wg 2a:** indeksy slotów i punktów łupu (`RunState.killed_slots`/`taken_loot`) zamiast identyfikatorów tekstowych; stan celu i zegara w `RunState.used` (`fuse_A`, `fuse_box_2`, `clock_812`) — bez nowych pól w `GameState`.

**Poziom**
4. **Krata (LA2):** dwa skrzydła; `jam()` unosi oba o 0,4 m (dalej zamknięta, nawigacja dalej przecięta), `open()` przetacza je na wysokości zacięcia w bok, do kieszeni w ścianie północnej. Zderzacz na każdy pręt i poprzeczkę (LA10) — kule przelatują między prętami, ciała nie.
5. **Wspólne ściany (LA4):** zamiast dzielenia na połówki — ranga wyglądu: zwykłe pomieszczenie > sekretne > przejście (koniec ciemnego pasa szybu w galerii i dioramie). Lica ścian (`ShellCarver.wall_faces()`, `LobbyLevel.wall_faces()`) liczone z pomieszczeń, nie z pudeł ścian (moduły ścian potrzebują lica od strony pokoju).
6. **Światła (LA9):** `DUAL_PARABOLOID` dla każdej lampy punktowej z cieniem (kolumny + lampka biurka); mgła wyłączona dla każdej lampy bez cienia, której zasięg wychodzi poza jej pomieszczenie; komnata za obrazem i nisza strzelby — wąskie reflektory w dół.
7. **Klatka schodowa pod kratą:** nowe pomieszczenie `stairwell` (−2..2 × −38..−26,5, podłoga −4 m) z łukiem z podziemi i 27 stopniami w dół; strefa końca dema w połowie schodów (znacznik `undercroft_exit`); czerwona lampa nad pierwszymi stopniami, dalej ciemność. Próg śmierci lobby −15 m (`Level.kill_plane()`, LB7).
8. **Statyczna atrapa T-Reksa** pomijana w grze (`LobbyLevel.boss_stand_in = false`); na postumencie stoi żywy boss w `(0; 1,25; −11)`, `rotation.y = −PI/2` (model integracji grafiki patrzy na wschód; polecenie koordynatora). Nad holem reflektor ekspozycyjny na szkielet (grupa `main_lights`, gaśnie przy zwarciu) — świateł z cieniem jest teraz 10 (limit testu < 11).

**Eksponaty i reżyser**
9. **Popiersie strzela z 14 + 1,5 m** (`Bust.RANGE_SLACK`): unosi się 1,6 m, więc przy dystansie 14 m na planie jego prawdziwa odległość przekraczała zasięg — krążyło w nieskończoność bez strzału (znalezione testem LB8).
10. **Klucz woźnego (LB5):** losowany przed pozostałymi artefaktami (szansa 0,7 w noc z zamkniętymi drzwiami); razem nadal 2–3 artefakty. **Trasa kryształu (LB6):** oba zabezpieczenia — reżyser nie zamyka drzwi z trasy, a trasa i tak omija zamknięte drzwi. Złote wartości testu znanych ziaren zaktualizowane (zmiana kolejności losowań).

**Cel nocy**
11. **Bezpieczniki i skrzynka przez E** (`Interactable`), nie przez dotyk — świadome podniesienie, podpowiedź w HUD. Zwarcie gasi lampy **holu i balkonu** (z mignięciem), oprawy ciemnieją, czerwone awaryjne zostają; stan zapisywany od razu.
12. **Walka uczciwa przy skromnej amunicji:** gdy boss się budzi, drzwi holu zatrzaskują się (walka bez wybiegania do skrzydeł — T-Rex i tak by się w nich zaklinował), w holu pojawia się zaopatrzenie (2× naboje, śrut, apteczka) i więcej przy fazach 2 i 3; po zwycięstwie drzwi wracają. Wezwanie ryku budzi najpierw uśpione figury holu, potem stawia nowe na slotach holu ≥ 8 m od strażnika.
13. **Co przeżywa „Kontynuuj”:** zabrane bezpieczniki (w kieszeni lub w skrzynce), zwarcie (hol ciemny, krata zacięta, kryształ pulsuje), czas zegara, zniszczone eksponaty i zabrane łupy (2a). **Co wraca do początku:** lot kryształu i walka z bossem (kryształ znów pulsuje w gablocie, boss uśpiony), zaopatrzenie walki. Po pokonaniu bossa `demo_complete` jest zapisane od razu, a każda kolejna noc to **epilog**: bez bossa, krata otwarta, cel „Zejdź do podziemi”.
14. **Zegar:** start w kanciapie liczy się jako wizyta w przystani (pierwsza minuta nocy stoi); zegar staje na dobre po śmierci bossa; świt w trakcie walki kończy noc (boss też zamiera); wzmocnienie godziny duchów obejmuje eksponaty wezwane później i nocy wznowione po 3:00. Świt: niesiony Pył → `run_dust`, stara latarka zostaje, `stats.nights + 1`.
15. **Wprowadzenie** zapamiętane w `hints.json` obok zapisu (raz na instalację, nie na grę — bez zmiany schematu `GameState`). Kolejność: interakcja (pierwszy obiekt w zasięgu, zwykle terminal lub notatka), latarka (wyjście z kanciapy; pominięta, gdy gracz sam ją włączy), bezpieczniki (diorama/hol albo 14 s poza kanciapą).
16. **Karta nocy przy każdym starcie** (także bez modyfikatora: „23:00 / Dyżur się zaczyna”); godzina duchów pokazuje tę samą kartę („3:00 / Godzina duchów”).

**Zawartość rozbudowy (zad. 16)**
18. **Ryk bez `RaptorPack.summoner()`:** jego raptory wchodzą do drzewa bez strojenia nocy (pełnia, godzina duchów) i mogą stanąć tuż przy strażniku; `NightObjective.summon()` robi ten sam rzut 50/50 (`RunState.rng`), ale stado stawia `NightSpawner.pack()` (strojone przed wejściem do drzewa) w narożniku ≥ 8 m od strażnika. Z tego samego powodu stada ze slotów nie idą przez `RaptorPack.spawn()` (budzi po dodaniu do drzewa i nie stroi).
19. **Stado a „Kontynuuj”:** slot stada jest zapisany jako zniszczony dopiero z ostatnim raptorem; stado przerwane w połowie wraca po wznowieniu w komplecie (indeksy slotów z 2a nie mają miejsca na członków stada).
20. **Portrety tylko w nowych miejscach:** zestawowe `painting` holu i zachodniej ściany galerii zostają zwykłymi ramami (greybox); portrety i `WallPainting` wiszą w 12 miejscach `portrait_*`. Twarz przypisana do miejsca, nie do roli — po wyglądzie nie da się poznać, który obraz się obudzi.
21. **Zamiana amunicji przy rozkładaniu łupu:** broń znaleziona w trakcie nocy nie zmienia już rozłożonych pudełek (do następnej nocy).

**Poprawki w cudzych plikach (klej integracji)**
17. `trex_skeleton.gd`: światło kryształu przy ogłuszeniu ~4 zamiast ~8,5, mgła 0,5 (hol nie tonie w czerwieni — widać na zrzutach walki). `src/world/cctv.gd`, `cctv_view.gd`: `clock_seconds` (Callable) — monitory pokazują zegar nocy. `src/world/world_hud.gd`: ikony artefaktów na y = 138 (pod nowym wierszem celu). `test_menu_input.gd`: strażnik ustawiany przed terminalem z jego transformacji (nie ze współrzędnych piaskownicy).

## Wyniki

- Testy: **770**, wszystkie zielone, bez linii `ERROR`/wycieków (`bash tools/run_tests.sh`, ok. 65 s z testem dymnym 100 nocy). Nowe: `test_lobby_shell`, `test_crowd_behaviour`, `test_crystal_route`, `test_night_modifiers`, `test_lobby_armory`, `test_night_objective`, `test_night_boss`, `test_night_clock`, `test_night_watch`, `test_onboarding`, `test_full_night` (cała noc od kanciapy do końca dema przez haczyki testowe + 100 wylosowanych nocy: noce 1–5 × 20 ziaren, ok. 16 s) i rozszerzone testy drzwi, lobby, świateł, reżysera, grafu.
- Sondy przeglądu po poprawkach: `carve_check` — 0 przecieków bocznych, 0 pionowych, 0 nakładań; szczelność lobby jest teraz testem.
- Zrzuty (okno 1920×1080, cicho): `bash tools/run_night.sh shots` → `tests/_out/night/`: `night_start`, `hall_exhibits`, `fuse_box`, `lights_out`, `crystal_pulsing`, `crystal_flight`, `boss_waking`, `boss_fight`, `boss_fight_guard`, `grate_open`, `dawn_freeze`, `dawn_card`, `blackout` (+ `night.json`). Obejrzane; poprawione po nich: reflektor na T-Reksie, lampa nad schodami w dół, miękka smuga kryształu, przygaszone światło kryształu, kadry bez winiety obrażeń.
- **FPS walki w holu** (boss w fazie 2, 33 eksponaty, wezwane figury, 1920×1080, RTX 2080 Ti): **242 kl./s** średnio bez V-Sync, najwolniejsza klatka 11 ms (z V-Sync równe 60). `bash tools/run_night.sh perf` → `perf.json`.
- `bash tools/export.sh` przechodzi, `build/NocnaZmiana.exe` startuje w menu (bez okna); scena `Museum` jako główna scena bez okna: 900 klatek bez błędów.
- Po scaleniu zawartości (`168d42e`) i zadaniu 16: **857** testów, wszystkie zielone. Zrzuty zawartości obejrzane (`gallery_paintings`, `portrait_awake` — rama wysunięta ze ściany z ciemną niszą i plwocina farby, `raptor_pack`, `gatling_display`, `flare_cabinet`); poprawka po nich: ujęcia kamery scenariusza są cięciem (`reset_physics_interpolation`), nie przejazdem od poprzedniego kadru. FPS walki po zadaniu 16: **158–164 kl./s** średnio bez V-Sync, najwolniejsza klatka 14–15 ms — eksponatów w holu 44 zamiast 33 (stada raptorów, raptory z ryku), koszt rośnie mniej więcej z liczbą eksponatów.

## Dla I2, grafiki i dźwięku

- **I2 (świat):** `Museum._ready()` woła `LobbyFeatures.install(lobby, self)` po zbudowaniu poziomu, strażnika, HUD-u i zegara (`museum.features`). Dostępne dla świata: `museum.night` (ten sam losowany `NightConfig`), `museum.lobby`, `museum.player`, `museum.hud` (`show_toast`, `show_hint`, `show_card`), `museum.watch.clock.elapsed` (sekundy nocy), `museum.objective.stage` + `Events.objective_changed(stage)`, `museum.artifact_spots()`. Łupy: stawiam tylko amunicję i apteczki; artefakty są w całości po stronie I2. `RunState.used` ma moje identyfikatory `fuse_*`, `fuse_box_*`, `clock_*`, `portrait_*` (i zawartości: `gatling_chain`, `flare_cabinet`) — nie używać tych przedrostków.
- **Grafika:** każdy element zestawu ma `kit`, `kit_size`, `kit_role` (floor/wall/ceiling/structure/trim/door/fixture/prop), `kit_room`, `kit_tint`, schody `kit_steps`; lica ścian z `LobbyLevel.wall_faces()` (pokój, normalna, prostokąt). Szare rekwizyty nocy do podmiany: bezpiecznik (`FusePickup.build_fuse`), front skrzynki (`FuseBox`), kryształ (`CrystalRelic.gem_mesh` + smuga), skrzydła kraty (kit `grate`, dwa po 3 m), klatka schodowa `stairwell`. Pęknięcie gabloty ukrywa jej przezroczyste `GeometryInstance3D` (`material_override` z przezroczystością) — model gabloty kryształu powinien mieć szkło jako osobne przezroczyste siatki. Świt szarzy eksponaty przez `material_override` na wszystkich `GeometryInstance3D` pod `visual` (działa z obecnymi rigami). Zawartość w lobby: znaczniki `portrait_1..12`, `gatling_display`, `flare_cabinet` (modele `chained_display`, `emergency_cabinet`, ramy/płótna `portrait_<id>` podmieniają się w samych klasach zawartości).
- **Dźwięk:** haczyki muzyki/otoczenia w `Events`: `night_started(night, modifier)` (spokojna noc = ciszej), `objective_changed(stage)`, `power_cut`, `witching_hour`, `dawn_broke`, `boss_awakened`/`boss_defeated`. Nowe efekty w `gen_sfx.py` (blok „the night in the lobby”, stare pliki bajt w bajt): `fuse_take`, `fuse_insert`, `relay`, `gate_jam`, `gate_open`, `glass_break`, `door_slam`, `witching_bell`, `dawn_chime`, `crystal_rise`.

## Poprawki po przeglądzie (1.10)

Druga runda przeglądu, sekcja R1 (integracja nocy). Gałąź z `etap-1a-piaskownica` @ `0dd3da0`, na końcu scalona z jej nowszym stanem (ścieżka dźwiękowa nocy, modele zawartości, zestaw architektury lobby). NI3 i NI4 (wydajność renderu i procesora) należą do poprawiacza wydajności — tu tylko pomiar dla nich (NIm9).

**Decyzje projektowe (wdrożone jak zapisano)**
- **NI1 — „Kontynuuj” to nie farma Pyłu.** Stado zapisuje straty w `RunState.used` jako `pack_<slot>_<ile>` (`Museum.pack_losses()`, `Museum.mark_pack_loss()`); wznowiona noc stawia rozmiar stada minus straty (`NightSpawner.spawn(..., losses)`, tak samo `exhibit_count()`), slot znika dopiero z ostatnim raptorem. Zaopatrzenie walki raz na noc dla każdej fazy (`supplies_<faza>`): walka zaczęta od nowa po „Kontynuuj” nie zrzuca go drugi raz. Eksponaty wezwane rykiem są warte 1 Pył (`NightObjective.SUMMONED_DUST`).
- **NI2 — minuta przystani bez kręcenia się w drzwiach.** Zegar w przystani znów stoi pełną minutę dopiero po 20 s poza nią (`NightClock.HAVEN_REFILL_AFTER`); krok za próg i z powrotem to ta sama wizyta.
- **NIm11 — bez odpoczynku obok areny.** Gdy T-Rex nie śpi, przystań nie leczy i nie zapisuje (składzik otwiera się z balkonu holu); komunikat „Nie teraz — T-Rex nie śpi” (`HUD_NO_REST_BOSS`).

**Krawędzie nocy**
- **NIm1:** `NightObjective._on_boss_defeated` nic nie robi, gdy noc jest już skończona (`Museum.night_over()` — śmierć, świt, wyjście — albo `RunState.running == false`): szkielet dobity po świcie (np. dopalającą się flarą) albo po śmierci strażnika nie daje zwycięstwa, `demo_complete` ani drugiego przesunięcia nocy.
- **NIm2/NIm3:** świt od razu odbiera strażnikowi wejście (`GameInput.push_ui` w chwili świtu, nie po 2,6 s), wyłącza cel nocy (`objective.process_mode = DISABLED`: kryształ zawisa w locie, boss się nie budzi, sekwencje na zegarach stoją) i węzeł łupów z Pyłem (`pickups_root`): nic zebranego po zapisie świtu nie przepada. Przystanie i terminal ignorują strażnika, gdy noc się kończy (`night_over()`).
- **NIm4:** w noc awarii prądu mignięcie przekaźnika nie zapala żadnej lampy (lampy i tak były ciemne).
- **NIm5:** wznowiona noc mówi muzyce, jak stoją sprawy, w kontrakcie dźwięku (`NightMood` agenta dźwięku): etap PULSING (`objective_changed` z `setup`) i dzwon godziny duchów (emisja dodana przez agenta dźwięku w `NightWatch.setup`, zachowana przy scaleniu) w tej samej ramce co `night_started`. Bez drugiego `Events.power_cut` przy „Kontynuuj” — to chwila włożenia bezpieczników, nie stan (moja wcześniejsza odroczona emisja usunięta po scaleniu).
- **NIm6:** zaopatrzenie walki przez `Museum.supply_for_guard()`: jak `loot_for_guard()`, a do tego amunicja tylko do broni, którą strażnik ma (inaczej do innej, którą ma; bez broni palnej — apteczka).
- **NIm7:** ryk stawia stado tylko w wolnym narożniku holu (zajęty = cokolwiek bliżej niż `RaptorPack.SPREAD + 0,8 m`); gdy wszystkie zajęte, ryk woła figury woskowe.
- **NIm8 (= W7):** zamknięcie holu wstrzymuje zatrzaski klucza woźnego na drzwiach holu (`LockedDoorLatch.held` przez `LobbyFeatures.hold_latches`): klucz się nie przekręca, drzwi odmawiają; po zwycięstwie zatrzaski znów działają (zamiast trwałego wycofania — klucz nadal otwiera drzwi nocy po walce).
- **NIm9:** `bash tools/run_night.sh dry` po wszystkich ujęciach mierzy walkę w holu kosztem skryptów: ms przetwarzania fizyki na tik (średnio i najgorszy) i ms przetwarzania na klatkę; tryb okienkowy `perf` podaje to obok kl./s. Pomiar po scaleniu (44 eksponaty, walka w fazie 2): **6,7 ms/tik** średnio, najgorszy 8,2 ms, 1,2 ms przetwarzania na klatkę — punkt wyjścia dla NI4.
- **NIm12:** ostrzeżenie reżysera o za małej liczbie punktów łupu raz na uruchomienie gry (`NightDirector.warnings`), nie raz na opis poziomu (każda noc dostaje świeży opis); test bossa sprawdza też, że zatrzaśnięte drzwi holu są zamknięte, nie tylko zablokowane.

**Testy (NI5)**
- `test_objectives_reachable` — sondy przeglądu jako stałe testy, w wersji pełniejszej i tańszej: zamiast 100 losowych nocy 7 budów lobby (bez zamkniętych drzwi i z każdymi drzwiami, które reżyser może zamknąć), na każdej ścieżka po siatce (warstwa chodzenia) z korytarza za kanciapą do **wszystkich** punktów bezpieczników, skrzynki i wszystkich gablot kryształu; każdy z czterech punktów bezpiecznika do złapania wzrokiem (E), przy każdej gablocie pierś strażnika w zasięgu kryształu (`CrystalRelic.REACH`).
- `test_night_edges` (14): świt w locie kryształu, boss zabity po świcie, świt odbiera ręce (Pył i przystań/terminal), śmierć w walce, wyjście w locie i w walce → wznowienie w PULSING (z kryształem w gablocie, drzwiami holu otwartymi, bez powtórnego zaopatrzenia faz już osiągniętych), przystań w walce, zaopatrzenie wg broni, klucz przy zamkniętym holu, awaria prądu bez mignięcia, ryk wart 1 Pył i nie na zajętym narożniku, wznowiona noc a muzyka, pełnia × godzina duchów dokładnie raz (zdrowie ×1,25, obrażenia ×1,25×1,2, szybkość ×1,2 — także po wznowieniu po 3:00 i u wezwanych).
- `test_lobby_content`: stado w połowie wybite wraca po „Kontynuuj” bez swoich martwych.
- `test_night_clock`: krok za drzwi przystani nie daje nowej minuty.

Nowe identyfikatory w `RunState.used` (nie używać tych przedrostków gdzie indziej): `pack_<slot>_<n>`, `supplies_<faza>`; po stronie świata `artifact_<id>`, `unlocked_<drzwi>` (plan świata lobby).

**Wyniki:** po scaleniu z `etap-1a-piaskownica` cały zestaw zielony dwa razy z rzędu: **1033 testy**, bez linii `ERROR` i wycieków (przed scaleniem gałęzi: 926 + 1 znany błąd kartaczownicy, naprawiony w `etap-1a-piaskownica`), `run_night.sh dry` i `run_world.sh dry` przechodzą; okienkowe `run_night.sh` obejrzane (świt: eksponaty szare, światło poranka, karta „6:00 / ŚWIT”).
