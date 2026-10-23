# Wydajność CPU — wystawy i culling pokojów (21.10.2026)

> Gałąź `perf-cpu` (worktree `voice-g1`, od `pietro-1` @ `76bac48`). Punkt właściciela **#57**: „nie obniżać jakości grafiki
> automatycznie; najpierw sprofilować wąskie gardła CPU/GPU…”. Narzędzie: `bash tools/run_cpu_profile.sh` (plan
> `2026-10-21-sterowanie-nakladka.md`). Zasady sesji: tylko `--headless`, bez okien i dźwięku, nic na GitHub.
> Kolejność pracy: pomiar → zmiana → pomiar; zachowanie bez zmian (pełny zestaw testów + testy porównawcze A/B).

## Diagnoza (pomiar przed)

Pierwsze liczby z `dev-tools` (ubrane piętro I, 164 wystawy, 47,4 tys. węzłów, ms na tyk fizyki 60 Hz, maszyna zajęta):
hol bezczynnie — tyk 14,2, fizyka 12,2, wystawy 8,2; walka w holu — tyk 20,4, fizyka 17,9, wystawy 12,6. Budżet fizyki przy
60 Hz to 16,7 ms — walka była ponad nim.

**Co robi śpiąca wystawa w każdym tyku** (mikropomiar na ubranym piętrze, 155 śpiących; 25–40 µs na wystawę, ~5 ms razem):
cały `Enemy._physics_process` w GDScripcie, choć nic się nie dzieje — sprawdzenie płaszczyzny śmierci, liczniki, ślad
strażnika (`PerceptionWorld.track`), `Haven.shelters`, pięć pól kontekstu mózgu (`_brief_brain`), `brain.update`, `_steer`,
grawitacja, `_check_stuck`, `_update_visuals` — a w nim `visual.rotation.x = …` **co tyk**, co przestawia transformację całego
modelu (propagacja do każdej części i powiadomienie każdej siatki; to szło też do „nieprzypisanego” czasu silnika). Rig
przestawał pozować po 90 klatkach snu, ale nadal był wywoływany. Sama percepcja to ~1 µs na tyk na wystawę.

**Przebudzone** (130–280 µs na tyk z rigiem): ścieżka — `nav.target_position` co 0,25 s planuje ją od nowa (A* po siatce
nawigacji całego piętra; silnik celowo nie sprawdza, czy cel się zmienił) także przy marszu do stałego punktu (patrol,
powrót, szukanie); `FlyingBook._may_attack()` rzucał promień co tyk, także gdy nie było kogo atakować; `room_at` przechodzi
wszystkie 114 sal (~60 µs na zapytanie, a pytają wystawy, pokój strażnika, culler); rig 30–60 µs; raz na klatkę skan
wszystkich ~170 wystaw (tłum, limit polujących) z wywołaniami metod także dla śpiących.

**RoomCuller**: zmiana pokoju przełączała wszystkie 114 sal (1105 lamp, sond i mgieł, 57 pyłów, 15 dekoracji) — 1,3–2,1 ms
headless w jednej klatce (w oknie więcej: prawdziwy serwer renderujący). Skoki 9–13 ms sekcji `level` (idle) z pierwszego
profilu **nie pochodzą z cullera**: zdarzają się też bez żadnej zmiany pokoju (hol bezczynnie) — patrz „Zostaje”.

## Zmiany

### 1. Drzemka śpiących wystaw (`Enemy` + autoload `ExhibitClock`)
Wystawa uśpiona i w spoczynku (DORMANT, `resting()`, bez zachwiania, przechył i zapowiedź wygaszone, rig w pozie spoczynkowej,
`_may_doze()`) **wychodzi z wywołań silnika co klatkę** (jej `_physics_process` i rig wyłączone). `ExhibitClock` (autoload,
pierwszy w klatce) tyka ją tylko w klatce, w której przypada jej następna chwila — sprawdzenie wzroku, tyk rutyny, koniec
twardego snu (`_doze_due()`) — jednym krokiem z całym czasem od ostatniego tyku. To te same spojrzenia, rutyny i odliczania
w tych samych klatkach. Liczniki wzroku i rutyny uznane za wybite w ±1 µs (`DUE_SLACK`): odliczane klatka po klatce albo
jednym krokiem wybijają w tej samej klatce (sumy kroków inaczej się zaokrąglają).
- **Wszystko z zewnątrz najpierw dogania sen** (`end_doze()`: jeden tyk z zaległym czasem, jeszcze śpiąc, potem tyk co klatkę):
  zdarzenia mózgu przez `EnemyBrain.before_event` (wake, alarm, hear, flee, stun, destroy, interrupt, cut_recovery, trasa,
  patrol), trafienia, popchnięcia, hałas (`react`), budzenie przez sąsiada (`rouse`), ustawienie `sound_asleep`;
  wywołujący, którzy piszą pola cudzej wystawy przed zdarzeniem (hoplita do towarzyszy, raptor do stada, księga do stada:
  `brain.quiet`, `_wake_delay`), wołają `end_doze()` sami.
- `ExhibitClock` układa ślad strażnika (`PerceptionWorld.track`), gdy któraś wystawa drzemie — robiła to pierwsza tykająca
  wystawa w klatce, a w klatce, gdy wszystkie śpią, nie tyka żadna; zegar stada ksiąg i ślad liczą czas jednej klatki
  (`get_physics_process_delta_time()`), nie zaległy krok.
- Podklasy: księga dopiero gdy siedzi na półce (nie w trakcie zsuwania, lądowania, odliczania swojej kolejki budzenia stada),
  mumia nie gdy wstaje ani gdy w grobowcu goi rany, relief nie gdy pęka płyta / wychodzi / wraca, totem gdy wszystkie twarze
  wróciły na front, rój skarabeuszy gdy kupka leży (jego `_process` z pozowaniem chodzących żuków odpoczywa w drzemce),
  popiersie gdy jego kołysanie zgasło, rycerz-greybox gdy tarcza wróciła, portret nie w trakcie wysuwania ramy.
- Zamrożenie o świcie kończy drzemkę bez doganiania (kamień na zawsze); wyjście z drzewa ją kasuje.

### 2. LOD wystaw daleko od strażnika
Przebudzona wystawa w spokojnym zajęciu (PATROL, RETURN, SEARCH, INVESTIGATE), niewidząca strażnika, w sali dalej niż
`PerceptionWorld.ROUTINE_HOPS` (2) przejścia od jego sali — tam, gdzie on nic nie widzi ani nie słyszy — jest tykana przez
ten sam zegar **co `LOD_FRAMES` (4) klatki**, z rigiem, z całym czasem od ostatniego tyku; `move_and_slide()` dostaje cały
krok (`_slide()`: prędkość × liczba klatek). Polująca, atakująca, ogłuszona, blisko strażnika albo w świecie bez sal
(areny, testy) — co klatkę jak dotąd. Wszystko z zewnątrz dogania ją jak śpiącą. Warunek sprawdzany co 4 tyki
(`_may_settle()`), nie co tyk.
- **Fazy** (22.10): przebudzone wystawy nocy budzą się razem na jej początku i wchodziły na zegar w tej samej klatce —
  tykane razem co 4. klatkę (w holu ~4 ms skoku co 4. klatkę, trzy pozostałe prawie puste). Każda wystawa ma fazę
  (licznik przy tworzeniu modulo `LOD_FRAMES`); pierwszy tyk LOD w najbliższej klatce swojej fazy (1–4 klatki), potem
  co 4 jak dotąd. Hol: p95 zegara 3,8 → 2,2 ms, najgorsza klatka zegara 18,5 → 3,0 ms. Licznik faz zaczyna od 0 przy
  każdej konfiguracji percepcji poziomu (`PerceptionWorld.configure()` → `Enemy.reset_phases()`; także `reset()`): ta sama
  noc zbudowana drugi raz w jednym procesie (profil z `--seed=`, bot przejścia) tyka w tej samej kolejności.

### 3. RoomCuller: tylko sale, które się zmieniają, rozłożone na klatki
Zmiana pokoju kamery dotyka tylko sal, których stan się zmienia: **sala, do której wchodzi, i jej sąsiedzi — od razu**,
najbliższe najpierw (nic nie „wyskakuje” w kadrze); sale dwa przejścia dalej, które się zapalają, a potem gasnące — z kolejki,
`spread_budget_usec` (500 µs) pracy na klatkę, co najmniej jedna sala na klatkę. `near()` liczone raz na salę i głębokość.
`update_from()` i `refresh()` nadal przełączają wszystko od razu (cięcia kamery w menu, testy). Licznik `rooms_switched`,
`room_changes`, `worst_check_usec` (raport profilu).

### 4. `RoomIndex` — `room_at` przez siatkę
`LevelLayout.room_at()` przez siatkę 4 m (`src/level/layout/room_index.gd`): ta sama odpowiedź (najwyższa podłoga wygrywa,
przy remisie pierwsza z listy), ale tylko sale z częściami w komórce punktu zamiast wszystkich 114. Użyte w percepcji
(`LevelPerception.configure_layout`), w cullerze i w `MuseumFloorLevel.room_at()` / `zone_at()` (pokój strażnika co
klatkę). Test: 4000 losowych punktów i wszystkie narożniki sal piętra I — identycznie jak `LevelLayout.room_at()`;
tańszość sprawdzana strukturalnie (`largest_bucket()`: najwięcej sal w jednej komórce < 1/8 sal piętra), nie zegarem
(porównanie czasów było niestabilne pod obciążeniem).

### 5. Drobne, każde ≥ kilka µs na przebudzoną wystawę na tyk
- Przechył (`visual.rotation.x`), kołysanie popiersia, pozy części rigu (`pose_part`) i położenie śledzonych stref trafień
  (`_follow_parts`) ustawiane **tylko gdy się zmieniają** (≥ 1e-5) — każde ustawienie przestawia część z całym poddrzewem,
  a strefa trafień to ciało w serwerze fizyki.
- Ścieżka do **nieruchomego celu** nie jest planowana od nowa co 0,25 s (ten sam cel, ta sama iteracja mapy nawigacji,
  ścieżka nieskończona): plan zostaje; po obejściu przeszkody, nowym celu, zmianie mapy (drzwi) — plan od nowa jak dotąd;
  agent sam planuje od nowa, gdy zepchnięty daleko od ścieżki. Cele ruchome (strażnik, miejsce na pierścieniu) bez zmian.
  **Po przeglądzie (23.10):** plan zostaje tylko, gdy nic jej nie pcha (`_external` zero) i stoi ≤ `OFF_PATH` (1 m, na
  rzucie) od odcinka ścieżki, którym idzie (`_on_path()`); popchnięcie (`shove()`: harpun, podmuch) i każda zmiana stanu
  kasują zapamiętany cel (`_planned_goal = INF`: plan od razu, także dla tego samego punktu); przy zachowanym planie
  `_target_reachable` liczone na nowo z końca ścieżki (tanie, bez zapytania). Wcześniej przesunięcie < 5 m (próg agenta)
  zostawiało ją przy starym punkcie ścieżki, aż `_check_stuck` (0,75 s). Testy: popchnięta planuje od miejsca, gdzie
  stanęła; zmiana stanu planuje od razu; cel ruchomy planowany co interwał; `_target_reachable` odświeżane.
- `_may_attack()` pytane tylko, gdy jest odległość do ataku (cel widoczny) — wynik i tak nie miał znaczenia; dotyczy
  promienia księgi.
- Wystawa przebudzona, ale stojąca na nieruchomej podłodze (czeka na skraju, trzyma posterunek, rozgląda się) — bez
  `move_and_slide()` (jak śpiąca), **ale co `STANDING_SLIDE_TICKS` (16) jej tyków w bezruchu prawdziwy slide** (licznik
  własnych tyków z przesunięciem o fazę, nie numer klatki silnika — noc z drzemką i bez czyta się tak samo):
  podłoga, która znikła, albo coś, co się na niej zamknęło (drzwi, stałe narzędzie środowiska, teleport mumii
  `_lie_down`), daje wypchnięcie albo upadek najpóźniej po ~0,27 s (daleko, w LOD co 4 klatki: ~1 s) — bez tego `is_on_floor()` z ostatniego slide'u
  trzymałoby ją w powietrzu. Test: stojąca przebudzona spada, gdy podłoga znika.
- Raz na klatkę: schron strażnika (`PerceptionWorld.guard_sheltered`), a skany wszystkich wystaw (tłum, limit polujących)
  odrzucają śpiące odczytem stanu przed wywołaniem metod. Po przeglądzie: pamięć `guard_sheltered` / `guard_light` /
  `guard_room` kluczowana także **miejscem strażnika** (przestawiony w tej samej klatce — nowa odpowiedź), a
  `Haven.set_active` / wejście / wyjście havenu ją kasują (`PerceptionWorld.shelters_changed()`).

### 6. Szafki bezpieczników: skoki sekcji `level` (22.10, znalezione tymczasowym `zz_level_bench`)
Skoki 6–14 ms sekcji `level` co ~2 s (121 tyków), także w holu bez ruchu i bez zmiany sali: piętro I ma cztery szafki
`FuseBoxArt` (wygląd z kitu), tylko przed jedną stoi skrzynka gry (`FuseBox`); trzy pozostałe co 2 s jej szukały, przechodząc całą
grupę `level_kit` (tysiące elementów) — wszystkie cztery w tej samej klatce. `FuseBox` dołącza do
`FuseBoxArt.BOX_GROUP`, szafki szukają tylko tam (0–1 węzłów); zachowanie to samo (skrzynka do 1,5 m z przodu, szukana
ponownie co 2 s, póki jej nie ma). Najgorsza klatka `level` w holu: 11,8 → 0,5 ms.
Metoda (na przyszłość): scena dziedzicząca po `cpu_profile.gd`, w której poziom jest podzielony na sekcje `CpuSections`
— po jednej na dziecko (`--drill=<węzeł>` schodzi niżej) albo po skrypcie dla wszystkich przetwarzających węzłów
(`--by-script`) — i lista najgorszych tyków z sekcją. Tymczasowa, niecommitowana.

### 7. Sprawdzone i odrzucone: co drugi tyk dla spokojnych przebudzonych poza kadrem (krok 3, 22.10)
Spokojna (patrol, powrót, szukanie, sprawdzanie), niewidząca i nieznająca strażnika, w sali blisko niego, ale poza jego
kadrem (`guard_watching()` z marginesem) — co 2 klatki, a spojrzenia i tyki rutyny w swoich klatkach (zaplanowane na
`min(2 klatki, _doze_due())`; test: każde spojrzenie w tej samej klatce co bez LOD). Telegrafów, ataków i semantyki
testów nie zmienia; przełącznik `Enemy.UNSEEN_LOD`. **Pomiar A/B (3 + 3 na przemian): bez zysku** — walka 8,28 → 8,78 ms
fizyki (w szumie), marsz 5,50 → 5,50; w walce prawie żadna przebudzona wystawa nie spełnia warunku (polują, czekają na
skraju widząc go, są podejrzliwe), a dodatkowe tyki na spojrzenia zjadają resztę. Nie wchodzi; commit zaparkowany na
gałęzi `perf-cpu-unseen-lod` (`ffac03a`, z testami), gdyby kiedyś spokojnych przebudzonych blisko było dużo.

## Jak sprawić, by nowe zachowanie było tanie we śnie (dla innych gałęzi)

1. **Śpiąca wystawa nie tyka co klatkę.** Kod w `_physics_process` podklasy wykonuje się dla śpiącej tylko w jej tykach
   drzemki — z `delta` obejmującym wiele klatek. Liczniki zapisuj jako `x -= delta` / `move_toward` / `maxf(x - delta, 0)`
   (składają się poprawnie), nie licz klatek, nie losuj „co klatkę z prawdopodobieństwem p”.
2. **Coś musi biec co klatkę także we śnie** (animacja, odliczanie, które czytają inni)? Zwróć `false` z `_may_doze()`, dopóki
   trwa. Ma własną chwilę (np. „za 3 s coś zrobię”)? Dodaj ją do `_doze_due()` (`return minf(super(), moja_chwila)`).
   Własne `_process` (wizualia) wyłącz w `_doze_changed(true)`, włącz w `_doze_changed(false)`.
3. **Zmieniasz wystawę z zewnątrz** (system nocy, pułapka, efekt środowiska, bot)? Używaj metod mózgu i wystawy
   (`brain.wake/alarm/hear/stun/flee`, `take_damage`, `shove`, `react`, `rouse`) — one same doganiają sen. Piszesz pole
   bezpośrednio (`brain.quiet`, licznik podklasy, pozycję przed zdarzeniem)? Najpierw `exhibit.end_doze()`.
4. **Nie wyłączaj wystawy `set_physics_process(false)`** w kodzie gry — drzemka/LOD sterują tą flagą (wystawę ze snu wybudza
   z powrotem); zatrzymanie na stałe to `freeze()`, zatrzymanie gałęzi — `process_mode`.
5. **Daleko od strażnika przebudzona wystawa tyka co 4 klatki** (`_lod_ready()`): logika spokojnych stanów musi znosić
   krok 4× dłuższy; coś, co tego nie znosi, wyłącz `_may_lod()`. Ruch idzie przez `_slide(delta)`, nie bezpośrednio
   `move_and_slide()`.
6. **Nie ustawiaj transformacji co klatkę „na wszelki wypadek”** (`visual.rotation`, `node.transform = …`, położenie stref
   trafień): każde przypisanie przestawia całe poddrzewo; ustawiaj, gdy wartość się zmieniła.
7. **Pokój punktu**: `PerceptionWorld.room_at()` / `level.room_at()` (przez `RoomIndex`), nie `layout.room_at()` w pętli co
   klatkę. Raz na klatkę dla wszystkich: `PerceptionWorld.guard_light/guard_room/guard_sheltered`.
8. Sprawdzaj kosztem: `bash tools/run_cpu_profile.sh --only=hub_idle,fight_hall` (wiersz „dozing”: ile wystaw drzemie,
   ile tyków drzemki na tyk) i `--seed=` dla tej samej nocy.

## Pomiar po — A/B na przemian (22/23.10, noc)

**Warunki: PC pod obciążeniem** (~8 agentów naraz; wszystkie procesy projektu przypięte do 12 wątków logicznych,
priorytet poniżej normalnego) — wartości bezwzględne zawyżone i zaszumione, porównanie tylko stary/nowy w tych samych
warunkach. Metoda: `bash tools/run_cpu_profile.sh --seed=57` (cały profil), na przemian stary, nowy, stary, nowy… po 3;
stary = `src` + `project.godot` z `pietro-1` @ `d1628a7` (ma już drzemkę, culler i LOD), nowy = `perf-cpu` @ `b7bbde6`
(scalony z tym samym `pietro-1`); narzędzie profilu (z `--seed=`) w obu to samo. **Mediana [min–max]**, ms na tyk
60 Hz, headless (bez renderowania). Kontroler mierzy jeszcze na bezczynnym PC.

| segment | miara | stary (`pietro-1`) | nowy (`perf-cpu`) |
|---|---|---|---|
| hol bezczynnie | fizyka | 5,28 [4,33–5,29] | **4,02** [3,96–4,28] |
| | tyk (fizyka + idle) | 7,29 [6,05–7,33] | 5,82 [5,65–6,19] |
| | fizyka p95 | 9,84 [8,17–10,33] | 5,63 [5,41–6,13] |
| | najgorsza klatka sekcji `level` | 11,82 [9,14–12,73] | 0,52 [0,44–0,55] |
| walka w holu | fizyka | 10,12 [8,97–10,54] | **7,73** [7,56–7,97] |
| | tyk | 12,54 [11,17–12,92] | 9,85 [9,68–10,20] |
| | fizyka p95 | 14,82 [13,77–16,31] | 11,13 [10,76–11,37] |
| | wystawy (sekcja) | 5,60 [4,95–5,86] | 4,24 [4,07–4,35] |
| marsz (5 zmian sali) | najgorsza zmiana sali (culler) | 0,37 [0,26–0,40] | **0,20** [0,19–0,50] |
| | fizyka | 6,91 [6,20–7,23] | 4,86 [4,77–5,00] |
| | najgorsza klatka `level` | 13,79 [12,97–17,12] | 8,58 [8,28–8,98] (grobowiec mumii, „Zostaje”) |
| Kolos | fizyka | 9,02 [8,68–9,27] | 6,51 [6,42–6,90] |
| T-Rex | fizyka | 10,84 [10,41–11,26] | 8,26 [8,25–9,03] |

Cele z planu: hol fizyka ≲ 5 ms — tak (4,0 pod obciążeniem); walka ≲ 10 ms — tak (7,7); zmiana sali ≲ 3 ms — tak
(0,2 ms headless; w oknie do sprawdzenia). Wcześniejsze A/B tej nocy (stary `pietro-1` @ `bebadd6`, nowy bez szafek
i faz): hol 5,42 → 3,98, walka 11,89 → 9,95, zmiana sali 0,41 → 0,25 — ta sama kolejność wielkości.
Liczby z 21.10 (pojedyncze przebiegi, losowe noce: przed `76bac48` hol 11,6 / walka 19,5; „+ drzemka + culler” 6,4 /
12,4) zostają w historii pliku; wiersz „+ LOD + guardy + RoomIndex” był mierzony z błędem `RoomIndex` (percepcja bez
pokojów — LOD nie działał), nieważny.
Śpiące: ~13–14 tyków drzemki na tyk dla ~171 wystaw (zamiast 171).

## Zostaje (≥ 1 ms, nie ruszone)
- Przebudzone wystawy blisko strażnika w walce: ~4,2 ms na ~30 przebudzonych (rig, `_steer`/nawigacja, `_brief_brain`);
  to polujące, czekające na skraju (widzą go) i podejrzliwe — krok 3 (co drugi tyk poza kadrem) ich nie obejmuje
  i nic nie dał (sekcja 7).
- „Nieprzypisane” (krok Jolta, flush transformacji) ~2,8 ms w walce; strażnicy 0,25–1 ms; sterownik profilu 0,6 ms.
- Jednorazowy skok 6,7–9 ms przy otwarciu grobowca mumii w marszu (`MummyTomb._land`: `Fx.puff` 28 cząstek
  i `Sfx.play_at` → ogon pogłosu w `Acoustics`); niezbadane dalej, która część.
- Pojedyncze skoki 16–70 ms w różnych sekcjach (wystawy, gracz, strażnicy, świat), za każdym razem w innym tyku —
  najpewniej wywłaszczenie przez inne procesy pod obciążeniem; sprawdzić na bezczynnym PC.
- Zegar drzemki: skoki 2,5–3 ms to zmienność liczby tyków śpiących w klatce (średnio ~14) — naturalne.
- ~~(z `audio-spaces`) `src/audio/acoustics.gd:247`, `SCRIPT ERROR` w segmencie Kolosa~~ — **poprawione** w `2aeb89c`
  (na prośbę kontrolera): zwolniony ogon na liście, lambda z typowanym parametrem go nie przyjmowała; teraz parametr
  bez typu i `assign()`, test w `test_acoustics.gd` (samodzielne `Acoustics`, bez ambientu). Profil CPU kończy się
  kodem 0.

## Do sprawdzenia w oknie (nie robione — zasady sesji)
- Wejście do nowej sali: czy nic nie „wyskakuje” (lampy i pył sali, do której się wchodzi, oraz sąsiednich zapalają się w tej
  samej klatce; dalsze — kilka klatek później) i czy w oknie (prawdziwy serwer renderujący) skok zmiany sali jest ≲ 3 ms (F3).
- Wystawa w sali > 2 przejścia od strażnika tyka 15 razy na sekundę: przy interpolacji fizyki ruch powinien być niewidoczny
  (sala zwykle niewidoczna); sprawdzić długie przejrzyste osie (dziedziniec → skrzydło), czy coś „szarpie” w oddali.
  (Fazy LOD: pierwszy tyk po 1–4 klatkach zamiast po 4 — bez widocznej różnicy, ale ta sama obserwacja.)
- Szafka bezpieczników w holu: lampki (czerwona → zielona) i dźwignia dalej idą za skrzynką gry (test jest, oko nie).
- Śpiąca wystawa obudzona strzałem / sąsiadem / wzrokiem reaguje w tej samej klatce co przedtem (testy A/B), ale warto
  obejrzeć łańcuch budzenia i stado ksiąg na półce.

## Stan prac / co dalej (23.10, ~03:00 — poprawki po przeglądzie zrobione)

**W `pietro-1`**: `a09f726` drzemka, `5961a31` culler, `6181121` LOD.
**Na gałęzi `perf-cpu`** (od `pietro-1` @ `bebadd6`; commit `WIP:` rozpisany na zwykłe commity, potem scalony
`pietro-1` @ `d1628a7` i jeszcze raz @ `0c4219b`):
- `f5dd7e4` `RoomIndex` + podpięcie (z poprawką: tymczasowy indeks ginął przed `PerceptionWorld.configure` — percepcja
  bez pokojów; złapane przez pełny zestaw na WIP: 3170/5, czerwone tylko testy pokojów percepcji),
- `df1260a` tańsze przebudzone wystawy (ścieżka do stałego celu, guardy transformacji, `_may_attack`, `_standing`,
  `guard_sheltered`, skany, `_may_settle`) + test „spacer do stałego punktu trzyma ścieżkę” (stary kod: 14 planów w 3 s),
- `e446d15` profil z `--seed=`, `ff75a22` ten plan,
- `50106c2` szafki bezpieczników (skoki `level`), `72df4ca` fazy LOD (skoki zegara), oba z testami.
Pełny zestaw na końcu (jednoprocesowo, po scaleniu `pietro-1` @ `0c4219b`): **3273 / 0**, bez błędów silnika
(wcześniej, po scaleniu @ `d1628a7`: 3180 / 0).
Krok 3 (co drugi tyk poza kadrem) zmierzony A/B i odrzucony — zaparkowany na gałęzi `perf-cpu-unseen-lod`.
**Przegląd kontrolera** („scalić po poprawkach”, bez HIGH): `2aeb89c` błąd ogonów pogłosu (`acoustics.gd`),
`b8272b2` M1/M2 (ścieżka do stałego celu planowana od nowa po popchnięciu i zmianie stanu, `_target_reachable`
odświeżane), M3 (stojąca przebudzona co 16 tyków prawdziwy slide), L1 (fazy od 0 z każdą percepcją poziomu), L2 (pamięć
`guard_*` kluczowana miejscem strażnika, haven ją kasuje), L3 (test `RoomIndex` strukturalny zamiast zegara);
`60080a0` slide stojącej liczony jej własnymi tykami (test „noc z drzemką = bez drzemki” wychwycił numer klatki).
Uwagi L4/L5 z przeglądu — tylko do notatki (treść w przeglądzie kontrolera), nic nie zmienione.
Po poprawkach (scalone `pietro-1` @ `0110df7`): filtry enemy/navigation/perception/ecology/room_index/room_culler/
doze/lod/playthrough 201 / 0; pełny zestaw jednoprocesowo **3366 / 0**, bez błędów silnika.
Tymczasowy `tests/scenarios/zz_level_bench.*` usunięty (nie do commita; metoda opisana w sekcji 6).

**Co dalej (dla kontrolera / następnej sesji):**
1. Pomiar na bezczynnym PC: ten sam A/B (stary = `pietro-1`, nowy = ta gałąź; `--seed=57`, 3 + 3 na przemian:
   `git checkout <stary> -- src project.godot`, profil, `git checkout HEAD -- src project.godot`, profil…).
2. Okno (F3): zmiana sali ≲ 3 ms, nic nie „wyskakuje”, nic nie szarpie w oddali (lista „Do sprawdzenia w oknie”).
3. Ewentualnie: jednorazowy skok przy otwarciu grobowca mumii (`MummyTomb._land`) — patrz „Zostaje”.
