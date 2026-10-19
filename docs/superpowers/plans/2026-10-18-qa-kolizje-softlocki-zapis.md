# QA Piętra I: kolizje, softlocki, zapis (#49, #50, #51) — plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`, commit po każdej poprawce. Wykonuje Claude w drzewie `.claude/worktrees/qa-sweep`, gałąź `qa-sweep` (z `pietro-1` @ `40323a4`).
> Wiążące: `docs/backlog-pietro1.md` #49–#51, plan W7 (`2026-10-03-p1-w7-weryfikacja.md`: osiągalność na siatce, `Floor1Survey`, `Floor1ReachCase`), projekt Piętra I §3 (noce, trwały postęp), §4 (bramy), §7.4 (strażnicy), §7.7 (zapis).
> Równolegle powstają: ekologia wrogów, kawiarnia/zmęczenie (`player.gd`!), nagrody sekretów (pola zapisu), oprawa Ameryk i dachu, muzyka. Poprawki małe i lokalne; **kolizje świątyni Ameryk należą do gałęzi oprawy — tylko je zgłaszam.**

**Cel:** dowieść testami bez okna, że (#49) gracz nie zatrzymuje się na drobnym uskoku, nie zahacza o dekoracje i nie wpada w niewidzialne narożniki; (#50) żadne drzwi, brama, sekret, arena ani zdarzenie nie zostawia gracza w stanie bez wyjścia; (#51) po zapisie i wczytaniu świat jest taki sam jak przed zapisem, a zepsuty lub stary zapis nie wywraca gry.

**Architektura (akapit):** prawdziwy strażnik (`Player`: jego `_physics_process`, kapsuła 0,4 × 1,8 m, `move_and_slide` na Jolt) prowadzony przez bota `Floor1Walker` krok po kroku w ciasnej pętli (1/60 s czasu gry na krok, bez klatek silnika między krokami — świat statyczny; ok. 65 µs na krok). Świat: `Floor1Sweep` buduje scenę gry (`Museum`) na **ubranym** piętrze z wszystkim otwartym (każda brama, drzwi, fałszywy panel, strażnicy i T-Rex pokonani, bronie i bezpieczniki zebrane, prąd włączony), bez eksponatów. Podłoga do chodzenia = siatka nawigacji eksponatów (agent 0,5 m, wspinaczka 0,1 m, nachylenie 40° — wszędzie, gdzie leży, kapsuła gracza się mieści) zamieniona na kratę punktów co 1 m, przefiltrowaną do miejsc, gdzie gracz stoi pewnie (`standing_spot`). Softlocki: maszyneria W7 (`Floor1ReachCase`) + fizyczne „doły" na każdym stanie postępu + testy aren w scenie gry. Zapis: zdjęcie świata (`Floor1WorldSnapshot`) przed zapisem i po wczytaniu w nowej scenie.

---

## Co już jest pokryte (stan 18.10)

| Obszar | Testy | Co sprawdzają |
|---|---|---|
| osiągalność | `test_floor1_reachability(_deep)`, `Floor1Survey`, `Floor1ReachCase` | na siatce: w każdej kolejności gry (HUD + losowe) każdy krok osiągalny pieszo, zamki bram z właściwej strony, obszary = `ProgressRules`, nic tylko za przystanią/sekretem, przystanie nie odcięte, drzwi nocy |
| spacery po strefach | `test_floor1_*_walk` | siatka sięga sal, slotów, łupu, patroli, znaczników |
| oprawa vs kolizja | `test_floor1_art_fit` | wygląd mieści się w pudle kolizji poniżej głowy (odwrotnej strony nie było) |
| strażnicy | `test_floor1_game_guardians`, `test_guardian_keeper` | stoją na znacznikach, smycz (Kolos), nagrody czekają na kolejnych nocach, kraty aren |
| finał | `test_night_boss`, `test_floor1_game_flow` | świt/śmierć/wyjście w locie kryształu i w walce z T-Reksem, brak odpoczynku w walce |
| plik zapisu | `test_game_state(_floor1)`, `test_night_rules` | wersja, `.tmp`/`.bak`, kwarantanna `.bad`, nowsza wersja nietknięta, migracja v1→v2, złe typy → domyślne, postęp nocy |
| wznowienie nocy | `test_floor1_game_flow::test_a_night_left_is_resumed_on_the_floor` | zniszczony eksponat zostaje zniszczony |

## Luki

- **#49:** żaden test nie chodzi **fizyką gracza** — testy spacerów pytają siatkę nawigacji (agent szerszy, inny wspinacz). Nie ma testu „kolizja bez wyglądu" (pudło szersze niż model = niewidzialny narożnik). Kontroler nie ma wchodzenia na stopień: kapsuła sama pokonuje ok. 12 cm, wyżej staje.
- **#50:** W7 nie zna zeskoków (siatka nie ma krawędzi w dół): miejsce, do którego da się **spaść, a nie da się wyjść**, nie jest sprawdzane w żadnym stanie postępu. Areny strażników skrzydeł: smycz sprawdzona tylko dla Kolosa; śmierć, świt, wyjście z gry w trakcie walki, zwolnienie drzwi po upadku — tylko dla T-Reksa.
- **#51:** nie ma testu „świat po wczytaniu = świat przed zapisem" w scenie gry (bramy, strażnicy, nagrody, bronie, przedmioty, sekrety, notatki, szachy, eksponaty, łup, użyte rzeczy, prąd, finał). Plik: obcięty zapis i śmieci binarne nie są sprawdzone wprost.

## Zadania

### Zadanie 1: plan
- [x] Ten plik → commit.

### Zadanie 2: bot i świat przemiatania (#49)
**Pliki:** `tests/support/floor1_walker.gd` (`Floor1Walker`), `tests/support/floor1_sweep.gd` (`Floor1Sweep`).
- [x] Bot: `place`, `step` (prawdziwy kontroler; skok = jego własne `velocity.y = jump_velocity`), `follow` (sterowanie jak gracz, zatrzymanie = brak postępu 0,6 s, spadek, zwolnienia < 55 % prędkości), `standing_spot` (podłoga, kapsuła z 5 cm zapasu, podparcie stóp, poprawka na stok), `blocking_top` (wysokość tego, co zatrzymało).
- [x] Świat: `Museum` ubrany, wszystko otwarte, bez eksponatów; siatka przepieczona po otwarciu drzwi.
- [x] Przemiatania: przejścia (każdy otwór w obie strony, środkiem i ±0,3 m), schody (w górę i w dół, środkiem i 0,55 m od boków), krata co 1 m (pasy wzdłuż x i z w obie strony), przejścia nad przerwą w kracie (uskok między podłogami, niska rzecz na podłodze), doły (spadnę — wyjdę?), niewidzialne kolizje (promień w dół przez obrys pudła na zastępcach-trimeshach wszystkiego, co narysowane).

### Zadanie 3: test kolizji i poprawki (#49)
**Pliki:** `tests/integration/test_floor1_collision.gd`, `test_floor1_collision_floor.gd` (krata 2 m), `test_floor1_collision_floor_deep.gd` (krata 1 m, `--filter=deep`), `tests/integration/test_player_steps.gd`, poprawki w źródłach.
- [x] Każde znalezisko: poprawka (TDD), wpis w `KNOWN*` z powodem albo zgłoszenie dla kontrolera (tabela niżej).
- [x] Asercje: brak zatrzymań na pasach, przejściach i schodach poza `KNOWN`; brak spadku prędkości; brak „niskich" uskoków (≤ krok − 5 cm), których gracz nie pokonuje; uskok podłoga–podłoga do 0,8 m daje się wskoczyć; brak dołów bez wyjścia; brak nowych pudeł ≥ 0,3 m przed rysunkiem (lista Q7 jako punkt odniesienia); stopnie każdego biegu leżą pod jego rampą; na podest astrolabium wchodzi się z każdej strony.

### Zadanie 4: softlocki (#50)
**Pliki:** `tests/integration/test_floor1_softlock_pits.gd` (+ `_deep`), `tests/integration/test_floor1_softlock_arenas.gd`, `tests/support/floor1_reach_case.gd` (`on_state`).
- [x] Doły w każdym stanie kolejności HUD (głęboko: + 6 losowych kolejności): 104 krawędzie, 38 zejść — jedyne doły bez wyjścia w świątyni Ameryk (Q8, zgłoszone).
- [x] Areny wszystkich sześciu strażników: zamknięcie, jedna podłoga (gracz, posterunek, nagroda), smycz otwiera, upadek otwiera, nagroda osiągalna i zapisana; śmierć (Lamassu, Generał), świt (Kentaur), wyjście z gry (Wąż) → następna noc: strażnik śpi na posterunku, arena otwarta, gracz w przystani.
- [x] Strażnik, który wypadł ze świata, porzuca walkę (Q11, poprawione).
- [x] Nic nie ginie: bronie, bezpieczniki, szachy po śmierci i po świcie zostają (`test_floor1_save_world`).

### Zadanie 5: zapis (#51)
**Pliki:** `tests/support/floor1_world_snapshot.gd`, `tests/integration/test_floor1_save_world.gd`.
- [x] Zdjęcie świata + porównanie; noce: pierwsza, po 6/12/17 krokach, epilog, w walce z Kolosem; po śmierci i po świcie noc z pliku = noc z pamięci gry; zegar nocy wraca ±2 s.
- [x] Zapis innej wersji (nieznane id, indeksy poza listami, latarnia poza mapą, liczby poza zakresem) → działająca noc; plik ucięty / śmieci / pusty → `.bad` i świeża gra. Atomowość (`.tmp` → nazwa, `.bak`) była i ma testy (`test_game_state`).
- [x] Test mutacyjny (ręcznie): wyłączone odtwarzanie zabranego łupu → test pada w 5 miejscach.

### Zadanie 6: całość
- [x] `git merge pietro-1` (secrets-rewards scalone czysto), pełny zestaw zielony, raport.

### Zadanie 7: decyzje kontrolera (19.10)
**Pliki:** `src/level/collision_fit.gd` (`CollisionFit`), `LevelBuilder`, `LevelArt`/`Floor1Art` (`FIT_COLLISION`, `FIT_COLUMNS`, `HERO_FIT`), `Player`, `Lamassu`, `ChainedDisplay`, `Floor1ArtAsia`, `DustDropper`/`DustMote`/`NightRules`/`PersistentState`, testy QA.
- [x] Q1: krok 0,35 m zostaje; oko nie „podskakuje” na stopniu (osiadanie okrągłych stóp na krawędzi zjada opóźnienie oka) — test schodów z pełnych stopni w górę i w dół + widok śledzony na każdym biegu piętra.
- [x] Q4: cokół Lamassu jest źródłem nawigacji (test: siatka nie biegnie pod kamieniem).
- [x] Q5: skała narysowana tak duża jak osłona (kolizja bez zmian), piasek osobno, płasko.
- [x] Q7: kolizja z rysunku (`CollisionFit`): pryzmaty pasami wysokości (stopa 0,2 m, potem co 0,25 m do 2,2 m, wyżej co 1 m), obrys wypukły tego, co narysowane w pasie, pasy podobne scalone; łuk katalogu i regały bębna w kolumnach; byki bramy Khorsabadu z rysunku bramy; pomiar na wątkach (`WorkerThreadPool`).
- [x] Q8/Q9: wycofane jako fałszywy alarm testu (niżej); test poprawiony, świątynia sprawdzana jak każda sala.
- [x] Q10: pył leżący zapisany z nocą i położony z powrotem.

---

## Znaleziska (bieżące)

| # | Obszar | Problem | Stan |
|---|---|---|---|
| Q1 | ruch (wszędzie) | kontroler bez wchodzenia na stopień: kapsuła pokonuje ok. 12 cm, wyżej staje — otwarta stopa schodów od boku (lico rampy 15–35 cm), stopnie podestu astrolabium (16 cm) | **poprawione**: `Player.STEP_HEIGHT` 0,35 m (decyzja: zostaje), oko dogania stopień płynnie (2,5 m/s, interpolowane jak ciało); 19.10: po wejściu na stopień okrągłe stopy osiadają na krawędzi — oko opadało o 1–3 cm („bob”), teraz to osiadanie zjada opóźnienie oka; widok śledzony na każdym biegu piętra (bez podskoku pod prąd, bez skoku > 12 cm na krok). Uwaga: schody z pełnych stopni o biegu < 0,45 m nie są wchodzone krokiem (na piętrze ich nie ma: każdy bieg to rampa pod rysunkiem) |
| Q2 | podziemia, kotłownia | schody na pomost narysowane pół biegu wyżej niż rampa (`BasementArt.stairs` bez przesunięcia o pół biegu) — gracz szedł po niewidzialnej rampie nad stopniami | **poprawione** (`LevelArt.stairs_look`) + test „stopnie pod rampą" dla każdego biegu |
| Q3 | Czytelnia | podest astrolabium: kwadratowe pudło 3,5 × 0,3 m pod okrągłymi stopniami (r 2,2/1,75/1,3, po 16 cm) — narożniki 0,27 m poza rysunkiem, stopień 30 cm | **poprawione**: kit `dais` — rampa stożkowa przez krawędzie stopni (jak każdy bieg), nawigacja wchodzi na podest |
| Q4 | Asyria, dziedziniec | `LamassuPlinth` (0,5 m) nie jest źródłem nawigacji: siatka eksponatów biegnie przez cokół (wojownicy z płaskorzeźb w fazie 2 wchodzą w kamień) | **poprawione**: `Lamassu.dress_arena` → `level.add_walk_source(base)`; test areny bierze podłogę przed cokołem (stąd byk schodzi) |
| Q5 | Azja, ogród | skały `rock`: model `garden_rock_a/c` to jedna siatka ze skałą i pierścieniem grabionego żwiru, pudło dopasowane do całości — kolizja ok. 2,5× szersza od narysowanej skały | **poprawione**: osłona Generała bez zmian (głaz), rysunek rozdzielony na skałę (rozciągniętą do głazu) i płaski piasek wokół (1,5× szerokość); test „niewidzialnych kolizji” wcześniej nie widział skał (kapsuła przy pochyłym boku głazu) — teraz widzi: stara oprawa → 6,3 m, nowa → 0 |
| Q6 | Grecja, Partenon | trzy rzeźby wschodniego frontonu: pudła 3 m nad cokołem 2,5 m — nawis 0,25 m na wysokości głowy bez rysunku | **poprawione**: 2,4 m |
| Q7 | wiele sal | 41 rodzajów pudeł (kit@sala) ≥ 0,3 m przed rysunkiem; po scaleniu oprawy Ameryk i dachu +13 | **poprawione**: (1) pomiar: partie MultiMesh w trybie headless nie mają danych w serwerze renderowania — szafki archiwum (18,3 m) i regały piwnic były fałszywym alarmem (`BasementArt` trzyma miejsca egzemplarzy w meta); (2) kolizja z rysunku (`CollisionFit`, lista `Floor1Art.FIT_COLLISION`) dla 25 rodzajów: biurka Czytelni (rysunek 2,7 m szerokości — kolizja była węższa od blatu), regały bębna (głębokość 0,9 → rysunek 0,55, wnęki ślepych portali otwarte), łuk katalogu (4 kolumny), bazy kolumn, balustrada galerii lwów (do parapetu), wystawka gatlinga (`Plinth`: zwężający się stojak; bez działa po jego zabraniu), maszyna parowa, tipi, bizon, kajak, łódź, totemy, rydwan, zegary, rzeźby, gabloty, zbiornik na dachu, wieszak szatni (nic nie narysowane → brak kolizji); (3) byki bramy Khorsabadu z rysunku bramy (`HERO_FIT`). Zostaje 10 wpisów `KNOWN_UNDRAWN` z powodem (namiot z odciągami, zamknięta przestrzeń w bębnie na dachu, rusztowanie, zbiornik na nogach, regały rezerwy, końce balustrad Bassae/Nereid, cokół hwacha, byki, szyna przy schodach kotłowni) + reguła dla szyn wież schodowych (koniec ≤ 1 m przy podeście). Koszt: 61 rysunków, ok. 0,25 s przy pierwszym budowaniu piętra (wątki), potem z pamięci |
| Q8 | Ameryki, świątynia | dolny taras przy (−17,3 / −11,0; 1,5; −77): zeskok 1,5 m z górnego tarasu „bez drogi powrotnej” | **wycofane — mój błąd**: to nie softlock. Z dolnego tarasu strażnik zeskakuje kolejne 1,5 m na posadzkę świątyni (i wchodzi biegiem n1/s1). Test dołów szedł do niższego wyjścia tylko do krawędzi i oceniał go jeszcze na niej; teraz przechodzi za krawędź i ląduje: 4 doły „wpada i wychodzi”, 0 pułapek. Nic nie dobudowane (areną Węża nikt nie musi wracać na górę inaczej niż biegiem) |
| Q9 | Ameryki, świątynia | biegi `americas_temple_n1/s1` 0,9 m od środka: zatrzymanie na poręczy | **rozwiązane** (oprawa Ameryk): biegi przechodzą środkiem i 0,9 m od środka w obie strony; świątynia sprawdzana jak każda sala (bez wyjątku „dla oprawy”) |
| Q10 | zapis | Pył leżący (jeszcze nie zebrany) przy wyjściu przez menu przepada | **poprawione**: `DustDropper.lying()` w postępie nocy (`night_progress.dust`, oczyszczany przy wczytaniu), przy „Kontynuuj” pył wisi tam, gdzie leżał, i leci do strażnika; zdjęcie świata liczy leżący pył |
| Q11 | areny | strażnik, który wypadnie ze świata (błąd fizyki), nigdy nie kończy walki: gracz zamknięty z niczym | **poprawione**: 8 m pod posterunkiem → walka porzucona (jak smycz) |
| Q12 | zapis | opróżniona szuflada kasy po wznowieniu znów zamknięta | oczekiwane (kosmetyka; mówi, że pusta) |
| Q13 | zapis | nieznane id przystani z obcego zapisu zostają na liście (start i tak w kanciapie) | uwaga |

## Decyzje do kontrolera / właściciela

- **Wysokość kroku 0,35 m** (Q1): zmienia czucie ruchu (#48). Wyżej niż stopień schodów (0,2) i podestu (0,16), niżej niż ławka (0,5) i cokoły (≥ 0,5). **Decyzja kontrolera 19.10: zostaje**; do oceny właściciela w grze (wejście na stopień od boku schodów, oko bez podskoku).
- **Q7**: **decyzja 19.10: kolizja dopasowana do modelu.** Zrobione ogólnie (`CollisionFit`): obrys tego, co narysowane, pasami wysokości, zamiast pudła greyboxu — dla rodzajów z listy `Floor1Art.FIT_COLLISION` (+ `HERO_FIT`, `FIT_COLUMNS`). Skutki dla gry: biurka Czytelni zatrzymują przy krzesłach (wcześniej strażnik wchodził w blat i krzesła), regały bębna 0,35 m płytsze (szersze przejście wzdłuż ściany), wieszak w szatni bez kolizji (nic go nie rysuje), wystawka gatlinga to stojak, nie blok. Nowy element na liście = jeden wpis w `FIT_COLLISION`.
- **Wyjście z gry w walce** zaczyna walkę od nowa bez zapasów fazy (jak dla T-Reksa — istniejący test to utrwala).

## Stan prac / co dalej

- 19.10: zadania 1–5 gotowe, commit po każdej poprawce. Pierwsze scalenie `pietro-1` (nagrody sekretów) czyste — **pełny zestaw 2337 zielonych, 0 porażek (26 min 49 s)**. Drugie scalenie (kawiarnia i zmęczenie, muzyka biomów) czyste; test zapisu dostał porównanie liczb z dokładnością do milionowej (zmęczenie zapisane w JSON wraca z innymi ostatnimi cyframi). Przebieg w oknie (tryb nocny, przez blokadę): 6 widoków wycieczki z `--debug-collisions` — wnioski w Q5 i Q7.
- 19.10 (druga sesja): scalenie `pietro-1` z oprawą Ameryk i dachu — pełny zestaw: 2445 zielonych, 3 czerwone (nowe niewidzialne kolizje Ameryk/dachu, stopnie s1 — artefakt promienia na styku stopni, i mój nowy test schodów); wszystko poprawione u źródła (zadanie 7). Decyzje kontrolera wdrożone: Q1, Q4, Q5, Q7, Q10; Q8/Q9 wycofane (fałszywy alarm mojego testu / rozwiązane przez oprawę). Pomiar „niewidzialnych kolizji” poprawiony dwukrotnie (partie MultiMesh bez danych w trybie headless; głaz z pochyłymi bokami). Drugie scalenie `pietro-1` (HUD, ekologia, polish-americas, visual-qa) czyste.
- 19.10 ok. 5:20: scalenie `pietro-1` (głos G2, HUD, trumna, visual QA) — **pełny zestaw 2616 zielonych, 1 czerwony** (`test_floor1_save_world`: noc po śmierci z pliku ≠ noc grana dalej — komentarz śmierci głosu G2 pamiętany tylko w pamięci gry); poprawione u źródła (`voice_state.death_pending` zapisywane ze śmiercią), testy zapisu/głosu zielone (124). Kolejne scalenie (gun-feel, light-pass; konflikt w `tour_scenario.gd` rozwiązany jako suma) — testy dotknięte zielone (310: gracz, zapis, kolizje, oprawa, Lamassu, areny, głos, odrzut), Wąż na sucho 25/0, wycieczka na sucho 145 widoków / 0 problemów. Pełnego zestawu po ostatnim scaleniu nie zdążyłem (koniec nocy).
- Co dalej: pełny zestaw po ostatnim scaleniu; patrz „Do sprawdzenia w oknie” (ocena właściciela); poza zakresem: poręcz/balustrada na wewnętrznej stronie biegów wież schodowych (niewidzialny koniec szyny ≤ 1 m przy podeście — dziś wyjątek w teście) i szyna przy schodach pomostu kotłowni (2,1 m).

## Do sprawdzenia w oknie

- Q1: wejście na stopień — czy oko podnosi się płynnie (0,35 m w ok. 0,14 s), czy krok w bok na stopę schodów nie wygląda jak „teleport".
- Q2 po poprawce: schody kotłowni na pomost — stopnie pod stopami.
- Q3: podest astrolabium — wejście po okrągłych stopniach, stopy na stopniach (rampa przez krawędzie).
- Q7: kilka pudeł z listy z nałożonym podglądem kolizji (`--debug-collisions`) — **zrobione 19.10** (`reading_astrolabe`, `assyria_lions_gallery`, `asia_garden_pond`; `basement_gantry` i `basement_reserve_aisle` za ciemne na zrzucie): katalog i parapet potwierdzone, skały — patrz Q5. **Po poprawkach, 19.10 ok. 4:20 (przez blokadę, `--debug-collisions`, nowa opcja wycieczki `--view=`):** biurko Czytelni — obrys obejmuje blat i wysunięte krzesła; regały bębna — kolizja przy licu regałów, wnęka ślepego portalu otwarta; łuk katalogu — kolizja idzie po łuku (4 kolumny); wystawka gatlinga — podstawa i stojak zamiast bloku; bazy kolumn holu — płyta bazy i okrągły trzon; parapet galerii lwów — kolizja na blankach; skały ogrodu — skała wypełnia głaz, piasek płasko wokół; dolny taras świątyni — bez zmian (Wąż na pierścieniu). Zostaje: regały rezerwy z bliska, schody kotłowni (Q2) w jaśniejszym ujęciu.
- Q1 (właściciel): krok w bok na stopę schodów i wejście na stopień — płynność oka (test nie widzi „czucia”).
- Q8: wycofane (nie softlock) — w grze: z dolnego tarasu świątyni zeskok na posadzkę i powrót biegiem.
