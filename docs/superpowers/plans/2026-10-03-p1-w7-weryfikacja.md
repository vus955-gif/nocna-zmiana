# P1 / W7 — weryfikacja Piętra I: osiągalność i bot-zwiedzający — plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`, commit po każdym zadaniu. Wykonuje Claude (W7) w drzewie `.claude/worktrees/p1-w7-verify`, gałąź `p1-w7-verify` (z `pietro-1` @ `e9276ca`).
> Wiążące: `docs/superpowers/plans/2026-10-02-p1-fundament.md` (strumień W7, tabele stref / przejść / bram, `ProgressRules`), projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §3 (noce, trwały postęp), §4 (bramy, graf postępu, skróty, przystanie, liczby), **§12** (weryfikacja). Notatki budowniczych: W5a (lina Planetarium liczona od znacznika `planetarium_counterweight`, lina 3–6 m nad nim), W3 (podłoga przystani to osobny region nawigacji — przez przystań nic), W4 (most z czółna poprawiany równolegle na `p1-integ2` — jeśli świątynia jest osiągalna przed `hook_canoe`, to **znalezisko**, nie poprawka).

**Cel:** udowodnić na zbudowanym piętrze (siatka nawigacji, bez okna), że **nie da się utknąć** w żadnym stanie postępu, i **zmierzyć**, ile trwa Piętro I: droga krytyczna, typowy pierwszy gracz (noce po 23 min) i 100% (każda sala, sekret, notatka, figura szachów, znajdźka). Cel właściciela: 45–60 min na każdy zakamarek (dłużej w porządku, jeśli zyskuje gra), pierwsze przejście w ~3–4 krótkich nocach.

**Architektura (jeden akapit):** czysta logika trasy i modelu czasu w `Floor1Route` (kolejności gry z `ProgressRules`, cele kroków, model czasu, noce, podział na skrzydła — bez węzłów, testowana jednostkowo). Siatka jako graf w `Floor1NavGraph` (trójkąty `NavigationMesh` łączone krawędziami tak jak `NavigationServer3D` łączy je na mapie: wierzchołki na siatce komórek mapy; składowe spójności, najbliższy punkt składowej, punkty do stania) — pytanie grafu nigdy nie drukuje błędu silnika (w przeciwieństwie do ścieżki na zamkniętą wyspę, por. `nav_probe.gd`). Strona sceny w `Floor1Survey` (węzeł testowy): raz zbudowane `MuseumFloorLevel` + prawdziwe zamki z `GateController`; zestaw otwartych bram → drzwi bram (otwarte / zaryglowane) + `open_instantly()` zamków + **jedno** synchroniczne wypiekanie regionu chodzenia → graf; wyniki w pamięci podręcznej po kluczu zestawu bram (ten sam zestaw = bez ponownego wypiekania). Zasięg zamka po rodzaju: zasuwa — E z jej strony, pieczęć — E z dowolnej strony, łańcuch/deski — pięść, spękany mur — raca z ≤ 5 m albo salwa, lina — pistolet ≤ 15 m / sztucer, hak — harpunnik ≤ 45 m; dla broni promień fizyczny z oka do strefy trafień zamka (`GateLock.zones`) musi trafić **pierwszy** w zamek. Testy: `test_floor1_reachability` (stany drogi krytycznej i losowe kolejności × przystanie × drzwi nocy, zgodność z `ProgressRules`, stan 100%, lina Planetarium), `test_floor1_reachability_deep` (więcej losowych kolejności; tylko na żądanie), `test_floor1_timing` (bot → `tests/_out/floor1_timing.json` + `.md`).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, tabulatory, `bash tools/run_tests.sh --filter=…` (bez okna, bez dźwięku, jeden Godot naraz; strażnik obcina CPU do połowy).

---

## Pliki

| Plik | Co robi |
|---|---|
| `tests/support/floor1_nav_graph.gd` (nowy, `Floor1NavGraph`) | graf siatki: krawędzie, składowe, najbliższy punkt składowej, punkty do stania, pomocnicze `room_point` |
| `tests/support/floor1_route.gd` (nowy, `Floor1Route`) | czysta logika: kolejności gry (cel HUD, losowe z ziarna), cel kroku (znacznik + zasięg), model czasu (stałe), noce, skrzydła |
| `tests/support/floor1_reach_case.gd` (nowy, `Floor1ReachCase`) | wspólna część testów osiągalności i bota: kolejność stan po stanie, punkt stały bram, zasięg kroków, znaleziska (`FINDINGS`) |
| `tests/support/floor1_survey.gd` (nowy, `Floor1Survey`) | węzeł: piętro + zamki, zestaw bram → wypiekanie → graf (pamięć podręczna), starty przystani, zasięg zamków i celów, długości ścieżek silnika |
| `tests/unit/test_floor1_nav_graph.gd` (nowy) | graf na sztucznej siatce (dwie płyty, wyspa) |
| `tests/unit/test_floor1_route.gd` (nowy) | kolejności, cele, model czasu, noce |
| `tests/integration/test_floor1_reachability.gd` (nowy) | osiągalność (wariant szybki) |
| `tests/integration/test_floor1_reachability_deep.gd` (nowy) | wariant głęboki (`--filter=deep`) |
| `tests/integration/test_floor1_timing.gd` (nowy) | bot-zwiedzający, raport JSON/MD |
| `tests/test_runner.gd` (mała zmiana) | pliki `*_deep*` tylko, gdy filtr zawiera `deep` |
| `docs/raporty/2026-10-03-czas-przejscia.html` (nowy) | raport dla właściciela (PL) |
| ten plik | plan + „jak zbudowano” |

Nie ruszam: modułów stref, `floor1_plan.gd`, `progress_rules.gd`, plików gry (`src/game/floor1/*`). Znaleziska idą do raportu.

## Ograniczenia, które kształtują projekt

1. **Błąd silnika przy ścieżce na wyspę.** `map_get_path` z podłogi do celu na zamkniętej wyspie siatki (blat, cokół) drukuje `ERROR` i psuje przebieg. Osiągalność liczę więc na własnym grafie (bez pytań do serwera), a ścieżki silnika (długości dla bota) tylko między punktami tej samej składowej, po sprawdzeniu powrotu `NavProbe.connected`.
2. **Graf = mapa silnika.** Wypiekanie daje trójkąty; mapa łączy wielokąty o wspólnej krawędzi z kluczem wierzchołka `floor(p / (0,25; 0,1; 0,25))`; krawędzie wolne łączy tylko między **różnymi** regionami (`edge_connection_margin`). Region chodzenia jest jeden, więc graf odtwarza mapę 1:1 (sprawdzam to próbką ścieżek silnika).
3. **Przystanie = osobny region (warstwa HAVEN).** Liczę wyłącznie na regionie chodzenia: start nocy w przystani = punkt tuż za drzwiami pokoju przystani. Cel leżący w pokoju przystani (szafka z pistoletem w kanciapie) jest osiągalny, gdy osiągalne jest wyjście tej przystani — nic nie może wymagać **przejścia** przez przystań.
4. **Wypiekanie kosztuje ~0,33 s** (4700 trójkątów; samo parsowanie 28 ms). Stan = zestaw otwartych bram; pamięć podręczna po kluczu; jeden poziom na metodę testu (zimne budowanie 4,3 s, ciepłe ~0,3 s dzięki `ShellCarver`). Drzwi odłączam od automatycznego przebudowywania `LevelNavigation` (asynchroniczne wypiekanie w trakcie synchronicznego = błąd silnika).
5. **Bramy-sekrety** (bramy stref spoza `Floor1Plan.GATES`, np. `americas_hook_moai`) w sprawdzaniu drogi krytycznej **zamknięte** — dowód, że nic potrzebnego nie leży za sekretem. W stanie 100% otwieram wszystkie, których zamki są osiągalne.
6. **Drzwi nocy:** reżyser bierze tylko drzwi `LOCKABLE`, a Piętro I dziś ich nie ma (`safe_doors` = []). Test i tak przechodzi po `NightDirector.safe_doors(FloorNight.describe_tonight(...))` dla każdego stanu — gdy drzwi przybędą, sprawdzi je bez zmian.
7. **Lina Planetarium:** odległość liczona od odcinka 3–6 m nad znacznikiem `planetarium_counterweight` do najbliższego punktu siatki poza obszarem `planetarium` (oko 1,6 m) — musi być > 15 m (pistolet nie sięga).
8. **Notatki:** z ~27 znaczników `note_*` Piętra I teksty mają dziś tylko 4 (`NOTE_BASEMENT_1…3`, `NOTE_ROOF_1`); `NoteCatalog` kładzie tylko notatki z tekstem. Bot liczy czytanie z długości tekstu, a dla brakujących średnią istniejących (wariant „docelowy”) — raport podaje oba.
9. **Liczby modelu czasu są założeniami.** Wszystkie w jednym miejscu (`Floor1Route`), zapisane w JSON obok wyników; raport mówi, co jest pomiarem (drogi po siatce), a co szacunkiem (walki, rozglądanie się).

---

## Model czasu (punkt startowy, `Floor1Route`)

| Składnik | Wartość | Źródło |
|---|---|---|
| chód | 5,5 m/s, droga = ścieżka silnika po siatce (string-pulling) | `Player.walk_speed` |
| rozglądanie się (pierwsza wizyta w sali) | 8 s + 1 s na 25 m² podłogi, najwyżej 45 s; droga krytyczna: połowa w salach mijanych | szacunek |
| eksponaty w sali | oczekiwana liczba z losowania reżysera: średnia po zestawach `min(zestaw, pułap gęstości)` + sloty `ALWAYS_SET` | `NightDirector`, `LevelDescription.room_cap` |
| walka z eksponatem | HP / 25 obr./s + 3 s (rodzaj docelowy ze slotu: mumia 110, hoplita 140, pies Fu 160, totem 4×30, księgi 5×18…) | HP z kodu i §5, skuteczne DPS pierwszego gracza ~25 |
| sala z eksponatami | + 5 s (sprzątanie, łup) | szacunek |
| strażnik | 2 min 45 s (środek 2–3,5 min) | §7.4 |
| T-Rex | 2 min 30 s | zadanie |
| notatka | 4 s + słowa / 3 na s (tekst PL) | `strings.csv` |
| sekret | 20 s szukania | szacunek |
| znajdźka / figura szachów | 5 s; rozdzielnia, astrolabium 8 s | szacunek |
| brama | 4 s na otwarcie | szacunek |
| noc | 23 min 20 s (7 h × 3 min 20 s); start nocy w ostatniej przystani + 30 s przy terminalu + powrót na front po siatce | §3.1 |

Profile: **droga krytyczna** (kolejność celu HUD, tylko sale mijane po drodze), **typowy pierwszy gracz** (droga krytyczna + każda sala niesekretna po drodze otwierania się muzeum, notatki w nich, bez polowania na sekrety i szachy), **100%** (wszystko). Trasa w każdej fazie (stan postępu): nowe cele w kolejności najbliższego sąsiada po długościach ścieżek silnika, potem krok drogi krytycznej.

---

## Zadanie 1: plan

- [x] Ten plik → commit.

## Zadanie 2: `Floor1NavGraph` + test jednostkowy

**Pliki:** `tests/support/floor1_nav_graph.gd`, `tests/unit/test_floor1_nav_graph.gd`.
- [x] Test (czerwony): sztuczna `NavigationMesh` — dwie płyty o wspólnej krawędzi i wyspa nad nimi: 2 składowe, punkt na płycie należy do składowej płyt, najbliższy punkt składowej do punktu nad wyspą leży na płycie, punkty do stania leżą w składowej, wierzchołki w tej samej komórce mapy się łączą.
- [x] Kod: `from_mesh(mesh)`, `component_at(point, max_drop)`, `closest(point, component, radius)`, `stand_points(component, center, radius)`, `polygons_near(point, radius)`, kubełki 4 m.
- [x] `--filter=floor1_nav_graph` zielone → commit.

## Zadanie 3: `Floor1Route` + test jednostkowy

**Pliki:** `tests/support/floor1_route.gd`, `tests/unit/test_floor1_route.gd`.
- [x] Test: kolejność HUD kończy piętro (20 kroków, `descend` ostatni), losowe kolejności z ziarna są powtarzalne i każda kończy piętro, krok → znacznik i zasięg (pistolet: `pistol_locker`, Kolos: `guardian_colossus`/arena, T-Rex, zejście), model walki (HP/DPS), noc (podział osi czasu na noce z powrotem z przystani), skrzydło strefy.
- [x] Kod → zielone → commit.

## Zadanie 4: `Floor1Survey` (strona sceny)

**Plik:** `tests/support/floor1_survey.gd`.
- [x] `setup(test_node)`: buduje piętro, stawia zamki (`GateController` na `GameState`/`RunState`), odłącza drzwi od przebudowy.
- [x] `use_gates(open: Array[StringName])` → drzwi + zamki + wypiekanie → graf (pamięć podręczna po kluczu; zamek otwarty raz zostaje otwarty — zestawy w ramach jednej kolejności tylko rosną, nowa kolejność = nowe zamki).
- [x] `haven_start(haven_id)`, `lock_reach(gate_id, progress) -> Dictionary` (osiągalny?, punkt, odległość, powód), `target_reach(step)`, `room_point(room)`, `path_length(a, b)`.
- [x] Commit razem z zadaniem 5.

## Zadanie 5: test osiągalności

**Pliki:** `tests/integration/test_floor1_reachability.gd`, `tests/integration/test_floor1_reachability_deep.gd`, `tests/test_runner.gd`.
Dla kolejności (cel HUD; losowe z ziaren) i każdego jej stanu `P_k`:
- [x] punkt stały bram na siatce: od bram otwartych w `P_k` otwieram bramy planu, których wymaganie gracz ma i których zamek jest osiągalny z właściwej strony, aż nic nie przybywa (bramy-sekrety zamknięte);
- [x] `ProgressRules.openable_gates` ∪ otwarte ⊆ bramy otwarte na siatce (**każda brama, którą reguły uznają za otwieralną, ma osiągalny zamek**) i odwrotnie (zgodność grafu obszarów);
- [x] obszary osiągalne na siatce = `ProgressRules.reachable_areas` (sale niebędące przystaniami);
- [x] każdy dostępny krok (`available_steps`, w tym cel HUD) ma cel osiągalny pieszo;
- [x] każda przystań znana w tym stanie: jej wyjście w tej samej składowej co kanciapa (więc ten sam wynik z każdej przystani);
- [x] każde drzwi z `safe_doors` dla tego stanu: z nimi zamkniętymi cel HUD dalej osiągalny ze wszystkich znanych przystani;
- [x] stan 100% (wszystkie kroki, wszystkie bramy z osiągalnym zamkiem, także sekrety): każda sala (przystanie przez wyjście), każdy znacznik `secret_*`, `note_*`, `chess_*` w zasięgu; lina Planetarium > 15 m od siatki poza rotundą; świątynia nieosiągalna przed `hook_canoe`;
- [x] znane znaleziska z równoległych gałęzi jako lista `KNOWN` (wypisywane, nie oblewają; gdy znikną — komunikat „usuń z listy”);
- [x] runner: `*_deep*` tylko z filtrem `deep`; `--filter=floor1_reachability` zielone, czas zapisany → commit.

## Zadanie 6: bot-zwiedzający

**Plik:** `tests/integration/test_floor1_timing.gd`.
- [x] Trzy profile po stanach kolejności HUD; odcinki: skąd, dokąd, metry, sekundy, strefa (droga dzielona na strefy po punktach ścieżki), składniki (chód, rozglądanie, walki, strażnicy, notatki, sekrety, interakcje, noce).
- [x] `tests/_out/floor1_timing.json` (założenia, profile, odcinki, sumy, skrzydła, sale, noce) + `tests/_out/floor1_timing.md`.
- [x] Asercje tylko na poprawność (każdy odcinek ma skończoną długość, sumy dodatnie, każda sala odwiedzona w 100%); **liczby poza celem to raport, nie poprawka**.
- [x] `--filter=floor1_timing` zielone → commit.

## Zadanie 7: raport i całość

- [x] `docs/raporty/2026-10-03-czas-przejscia.html` (PL): wynik na tle celu, tabela skrzydeł, podział na noce, znaleziska, propozycje (sale za rzadkie, skrzydła za krótkie / za długie).
- [x] Pełny `bash tools/run_tests.sh` zielony bez linii `ERROR`; „jak zbudowano” w tym pliku; commit; raport do kontrolera (≤ 40 linii).

---

## Jak zbudowano (3.10) — odstępstwa i wyniki

| Co | Zmiana względem planu | Dlaczego |
|---|---|---|
| `Floor1ReachCase` (nowy plik) | wspólna baza testu szybkiego, głębokiego i bota | trzy testy dzielą punkt stały bram i zasięg kroków |
| Przejścia, których siatka gry nie łączy | `Floor1Survey` łączy w grafie obie strony otwartego przejścia (kapsuła gracza 0,4 × 1,8 m się mieści) i biegu schodów, gdy mają podłogę w różnych składowych; listuje je w `breaks`, a mapa potwierdza drogę od miejsca lądowania (`entries`) | otwarte skrzydło SWING przy ościeżu zwęża drzwi 1,5 m poniżej agenta 1 m — gracz przechodzi, siatka nie (W7-2); osobny test sprawdza, że to jedyne takie miejsce |
| Punkty do stania | także najbliższy punkt każdego wielokąta (lekko do środka) | duży trójkąt podłogi ma wierzchołki daleko od zamka — przy samych wierzchołkach pieczęć Balawat „nie miała” gdzie stanąć |
| Strzał w zamek | liczy się, gdy trafia w strefę ≤ 0,6 m od punktu celowania (środek strefy albo 3 z 5 punktów) | inaczej promień „z ukosa przez 6-centymetrową szczelinę przy ościeżu” udawał dostęp |
| Ciasna szczelina | `_squeeze_reach`: gdy siatka nie sięga znacznika, kapsuła gracza rzucana prosto z najbliższego punktu siatki (≤ 4 m) | figura `chess_3` stoi za cellą Pomnika Nereid w przejściu węższym niż agent (1 m), a gracz (0,8 m) wchodzi |
| Cel w przystani | ścieżka po regionie przystani (warstwa HAVEN) od jej drzwi | szafka z pistoletem, notatki w przystaniach |
| Zamki z zapisu | `Floor1Survey` czyści bramy i flagi `GameState` przed postawieniem zamków | `GateController` otwiera zamki (i żaluzje po fladze zasilania) z zapisu — stan z poprzedniej kolejności psuł następną |
| Strony zamków | test `test_every_lock_works_from_its_sides`: każdy zamek pytany osobno z każdej strony (gracz przed murem, nie w otworze) | precyzyjna lista W7-1 i tabela do raportu |
| Znaleziska | `FINDINGS` (wypisywane, nie oblewają), `ASSUMED_OPEN` (bramy W7-1 traktowane jak otwarte od strony gracza, żeby sprawdzić resztę piętra), `NAVMESH_FINDINGS`; po poprawce test sam mówi, co usunąć | zestaw ma zostać zielony, a znaleziska widoczne |
| Wariant głęboki | `tests/test_runner.gd`: pliki `*_deep*` tylko z filtrem zawierającym `deep` | 24 losowe kolejności × każda przystań × drzwi nocy trwają ok. 2 min 40 s |
| Nawigacja strefowa (scalona z `pietro-1` w trakcie) | graf z siatek wszystkich kafli (`LevelNavigation.regions`), krawędzie wolne różnych regionów łączone testem marginesu mapy (`Floor1NavGraph.margin_joins`, jak `NavMapBuilder3D`); wypiekanie przez `LevelNavigation.bake_now()` (równolegle, ok. 50 ms na stan); `skip_kits = GateLocks.replaced_kits()` jak w grze; pomost czółna (źródło siatki) usuwany z zamkami | od `pietro-1` @ `a9f2af9` siatka to kafle 16 m, a most to prawdziwy `HookLock` |
| Drzwi nocy | Piętro I nie ma drzwi `LOCKABLE` (`safe_doors` = []), więc ten wymiar jest pusty; kod sprawdza je, gdy przybędą | zgodnie z W5b p. 8 |
| Typowy gracz | sale **publiczne** (nie służbowe, nie sekretne) w miarę otwierania się muzeum, przystanie, notatki w nich | sale służbowe i tak mija po drodze |

**Wyniki (bez okna; `--filter=floor1_reachability` ok. 55 s, `--filter=deep` ok. 2 min 40 s, `--filter=floor1_timing` ok. 45 s):**

- Osiągalność: kolejność HUD (20 stanów × każda znana przystań), 2 + 24 losowe kolejności — każdy dostępny krok osiągalny pieszo, bramy otwieralne na siatce = `ProgressRules.openable_gates`, obszary = `ProgressRules.reachable_areas`, nic tylko za przystanią ani za sekretem; świątynia nieosiągalna przed `hook_canoe`; lina Planetarium 18,0 m od najbliższej podłogi poza rotundą; 100%: 108 sal (poza przystaniami), 27 sekretów, 33 notatki, 8 szachów — **przy założeniu poprawki W7-1**.
- **W7-1 (blokada piętra):** zamknięte drzwi bramy (niewidoczne, ale z kolizją) stoją przy licu pokoju A i zasłaniają zamek otwierany od strony A: `boards_tomb` i `bolt_lions_bassae` → Grecja nieosiągalna → piętra nie da się ukończyć; `boards_staff_stairs` (od kanciapy — podziemia otwierają się tylko od Egiptu), `bolt_asia_planetarium` (skrót), łańcuchy sekretów `booth_chain_watch`, `egypt_chain_cache`, `asia_chain_vault`, `basement_chain_cage`. Poprawka po stronie W1 (`gate_controller.gd` / `museum_floor_level.gd`). **Naprawione 3.10 (gałąź `fix-gates`):** zamek z własnym ciałem (`GateLock.blocker`: łańcuch, deski, spękany mur, zasuwa, żaluzja, krata haka) sam trzyma przejście — drzwi przejścia zachowują tylko stan (bez wyglądu i kolizji), a zamek przechodzi do zmiennych źródeł nawigacji (`walk_dynamic`), więc jego ciało tnie siatkę, dopóki jest zamknięty; `FINDINGS` i `ASSUMED_OPEN` są puste — wszystkie sprawdzenia to twarde asercje.
- **W7-2:** `enlightenment_stairs_stacks` — siatka gry nie przechodzi przez otwarte drzwi (eksponaty nie pójdą za graczem). **Naprawione 3.10:** drzwi mają 2 m (z 31,5…33,5), pamięć skorupy wypieczona na nowo; `NAVMESH_FINDINGS` puste.
- Czas (model, `tests/_out/floor1_timing.json`): droga krytyczna **57 min** (2,4 nocy), typowy pierwszy gracz **1 h 43 min = 4,6 nocy**, 100% **2 h 39 min** (6,8 nocy); skrzydła przy 100%: Egipt 20, Asyria 17, Grecja 19, Oświecenie 21, Azja 16, Ameryki 15 min, centrum 29, podziemia 18, dach 5 min. Średnio 176 eksponatów na noc (projekt: 90–120). Raport: `docs/raporty/2026-10-03-czas-przejscia.html`.
