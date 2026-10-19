# Kawiarnia Dziedzińca i zmęczenie — za ladę, ekspres, łagodna mechanika

> Plan wykonawczy. Wykonawca: jeden agent w worktree `guard-general` (gałąź `cafe-fatigue` od `pietro-1` @bceeee8).
> Źródło: backlog właściciela `docs/backlog-pietro1.md` — #10 („dać się wejść za ladę; mechanika zmęczenia — stamina z upływem nocy przejmowana przez zmęczenie; kawa z ekspresu ją niweluje"), #32 („kawiarnia jako bezpieczny hub: chwila oddechu między sekcjami, kawa, komentarz do absurdu; rytm walka → eksploracja → oddech → eskalacja"), #33 („zmęczenie subtelnie, nie survival bar: wolniejsza regeneracja, krótszy sprint, lekko gorsza stabilność broni; kawa czasowo cofa; nie karać za to, czego gracz nie może uniknąć"), dopisek kuratora („kawiarnia zmienia się z nocą: ekspres wariuje, etykiety się zmieniają, automat proponuje absurdy; 2–3 rodzaje kawy"), #42 (HUD jednego projektu — stamina i zmęczenie też), #54 (zasoby: lekki nacisk, nie survival).
> **Bez okien i bez dźwięku** (właściciel pracuje przy komputerze): tylko `--headless`, skrypty. Nic nie trafia na GitHub.

**Cel:** Strażnik wchodzi za ladę kawiarni na Dziedzińcu (unosi klapę lady), stoi w zacisznym kącie baristy — eksponaty tam nie wchodzą, broń opada, muzyka cichnie — i robi sobie kawę. Zmęczenie rośnie z nocą i wysiłkiem, **nic nie robi** przez pierwsze półtorej–dwie godziny nocy, a potem **podgryza pasek staminy od prawej** (mniejsza pojemność, wolniejsza regeneracja, odrobina kołysania broni, chłodna winieta i rzadkie mrugnięcie). Kawa cofa je na chwilę: espresso krótko i mocno, duża długo i słabiej; po godzinie duchów ekspres wariuje i nalewa, co chce. Zapis trzyma zmęczenie i kofeinę przez wznowioną noc.

**Architektura:** jedna czysta klasa `Fatigue` (`src/player/fatigue.gd`, RefCounted jak `Stamina`) liczy poziom 0..1, efekty i kofeinę — tykana przez `Player`, karmiona ułamkiem nocy przez `NightWatch`, zapisywana w stanie strażnika (`Museum._guard_state`). `Stamina` dostaje dwa mnożniki (`capacity_factor`, `regen_factor`). Kawiarnia to `CafeCorner` (`src/game/floor1/cafe_corner.gd`, Node w `FloorGame`): przystań-kieszeń z istniejącej klasy `Haven` (bez leczenia i zapisu — nie ma jej w `haven_spots`), klapa lady `CafeFlap`, ekspres `CafeMachine` i termos `CafeUrn` (Interactable), tabliczka z menu (Label3D), stany nocy. Dane kaw w `Coffee` (`src/game/floor1/coffee.gd`, czyste). Nowe sygnały `Events` (`cafe_entered`, `coffee_drunk`, `cafe_haywire`) dla reżysera głosu (G2 nagra kwestie).

---

## 1. Inwentarz (stan przed zmianą)

| Co | Gdzie | Dziś |
|---|---|---|
| Kawiarnia | `src/level/floor1/zones/court.gd` `_court_floor` | `cafe_counter` (−22; 0; −28,75), 5,1 × 1,1 × 2,3 m — **jedna bryła kolizji** (nie da się wejść za ladę); 4 stoliki `cafe_table`; punkt łupu i `note_court_1` **w gablocie z ciastami** (na blacie) |
| Model lady | `tools/art/models/court_props.py` `cafe_counter()` (4,06 × 2,90 × 2,28) | lada 4 × 0,75 × 1,0 (gablota z ciastami, **ekspres** — mosiężny bojler z orłem, kasa), **przejście baristy 1,0 m**, barek przy ścianie 0,5 głęb., 2,9 wys. (słoje, półki, menu kredą „ZAMKNIĘTE DO 9:00”, szyld KAWIARNIA). `Floor1Art._cafe_counter` rozciąga ×1,256 wzdłuż, ×1,14 w głąb (limity 1,3 / 1,15) |
| Przystań | `src/haven/haven.gd` | Area3D: strefa AABB, niewidzialne ściany `ENEMY_BLOCK` na 4 ścianach; `Haven.shelters()` czyta: wrogowie (nie ścigają, szukają 8 s, idą do domu), `NightWatch` (zegar stoi ≤ 60 s na wizytę), `Music` (spokój), `WeaponHolder` (broń opada, bez strzału), `PerceptionWorld` (hałas w przystani niesłyszalny), `Player._remember_floor`. **Leczenie + zapis** robi `Museum._on_haven_entered` tylko dla przystani z `level.haven_spots` |
| Stamina | `src/player/stamina.gd` | 100; sprint 18/s, dash 30; regen 30/s po 0,7 s; wyczerpanie do 30. Ulepszenie „Wytrwałość” +20 / +15 % za poziom (`UpgradeEffects`) |
| Zegar | `src/game/night_clock.gd`, `night_watch.gd` | 23:00–6:00, 180 s/h (21 min), `fraction()` 0..1, godzina duchów 3:00 (`Events.witching_hour`); zapis `clock_<s>` w `RunState.used` |
| Zapis nocy | `Museum._guard_state()` / `_restore_guard()` | `{"health", "weapons"}` w `NightRules.progress_snapshot` („guard”) |
| HUD | `src/ui/hud.gd` | `_stamina_bar` = `ProgressBar` 320 × 8, wypełnienie (0,95; 0,8; 0,3), tło czarne 50 %; czerwienieje przy wyczerpaniu |
| Pył | `RunState.dust`, `UpgradeCatalog` (ceny 20–120) | jedyna waluta — stałe ulepszenia; ginie przy śmierci (latarnia) |
| Głos | `src/audio/voice/voice_director.gd`, `voice_catalog.gd` (`EVENTS`, `RULE_FIELDS`), `voice_rules.gd` | słucha tylko `Events`; `test_voice_data` wymaga, by każde zdarzenie reguły było sygnałem `Events` |
| Kołysanie broni | `src/weapons/weapon_holder.gd` `_process` | bob z prędkości (`sway = min(speed/5,5; 1,5)`), opady (haven, daze, reload) |

## 2. Decyzje projektowe

### 2.1 Zmęczenie — model (`Fatigue`, poziom F ∈ [0, 1])

| Składnik | Liczba | Uzasadnienie |
|---|---|---|
| Czas nocy | **0,60 za całą noc**, krzywa `x^1,5` (x = ułamek nocy): tempo `0,6·1,5·√x / 1260` na s | sama noc **nigdy** nie przekracza progu zbyt wcześnie: próg 0,35 z samego czasu dopiero ok. 4:00; przyspiesza po północy (dołek dobowy), start nocy jest świeży |
| Sprint | **+0,0006/s** (5 min sprintu w nocy = +0,18) | wysiłek to wybór gracza — uczciwe (#33) |
| Dash | **+0,003** za unik (50 uników = +0,15) | j.w. |
| Odpoczynek w przystani (każdej, kawiarnia też) | **−0,0015/s** (minuta = −0,09) | przystań to oddech — zgodnie z #32; zegar i tak stoi tam ≤ 60 s |
| Próg efektów | **0,35**; siła efektu `t = (F − 0,35)/0,65` liniowo, 0..1 | poniżej progu **nic** — pierwsze 1,5–2 h nocy bez żadnej kary |
| Pojemność staminy | `× (1 − 0,30·t)` → najwyżej **−30 %** | „pasek zjadany od prawej” (#10); łagodne |
| Regeneracja staminy | `× (1 − 0,35·t)` → najwyżej **−35 %** | #33 |
| Kołysanie broni | bob `× (1 + 1,0·t)` + powolny dryf 4 mm·t | „lekko gorsza stabilność” — bez wpływu na celność hitscanu, tylko obraz |
| Winieta | chłodna (granat–czerń) alfa `0,22·t` | subtelna; czerwona winieta obrażeń bez zmian |
| Mrugnięcie | od `t ≥ 0,4`: co `lerp(14; 7; t)` s, 0,4 s, powieki 12 % wysokości ekranu | rzadko i krótko — sygnał, nie kara |
| Limity | F ≤ 1; przy braku kawy i odpoczynku, bez sprintu: F(6:00) = 0,60 → t = 0,38 → pojemność −11,5 %, regen −13,5 % | **nie da się** zostać ukaranym za coś nieuniknionego: samym czasem nie zejdzie się poniżej 88,5 % pojemności |
| Zapis | `Fatigue.to_dict()` w `"guard"` zapisu nocy (`level`, `buff`, `buff_left`, `jitter_left`) | wznowiona noc jak przerwana; nowa noc zaczyna od 0 (`Player.respawn` → `reset()`); leczenie w przystani (`refill`) **nie** zeruje zmęczenia — robi to odpoczynek w czasie i kawa |

### 2.2 Kawa (`Coffee`, czyste dane)

| Rodzaj | Ulga od razu | Kofeina (czas) | Efekt kofeiny | Skąd | Uwagi |
|---|---|---|---|---|---|
| **espresso** | −0,30 | 90 s | regen staminy +25 % | ekspres | „krótko i mocno” |
| **duża** (`large`) | −0,15 | 240 s | **zmęczenie nie rośnie** (czas, sprint, dash), regen +10 % | termos na barku | „długo i słabiej” |
| **specjalność nocy** (`special`) | −0,45 | 60 s | regen +40 %; **12 s trzęsących się rąk** (kołysanie ×2, gaśnie) | ekspres **po 3:00** (zamiast espresso) | absurd godziny duchów: ekspres „nalewa, co chce”; drżenie to wybór gracza, nie kara — widoczne w podpowiedzi |

- **Bez łączenia czasu:** ulga nowej kawy i drżenie rąk liczą się zawsze w pełni; kofeina nie sumuje się — zostaje ta, której zostaje **więcej czasu** (nowa kawa przejmuje ją tylko, gdy trwa co najmniej tyle, ile zostało starej: espresso nie wyrzuca ostatnich minut dużej kawy). F nigdy poniżej 0.
- **Cena: darmo.** Pył to magiczny pył z eksponatów, nie pieniądze; kasa jest „ZAMKNIĘTA DO 9:00”, a Strażnik to pracownik — robi sobie kawę. Płacenie Pyłem za chwilowy bufor podgryzałoby stałą progresję (#54: lekki nacisk). Racjonowanie nie waluta: **ekspres grzeje się 90 s** po każdej kawie (podpowiedź „Ekspres się grzeje”), **termos kapie 150 s** do następnego kubka. Czas gry (pauza wstrzymuje).
- **Dźwignie są po stronie baristy:** użycie ekspresu od strony sali daje tylko podpowiedź („Dźwignie są po drugiej stronie lady”) + `deny` — to wiąże #10 (wejście za ladę) z kawą. Termos stoi na barku — z sali i tak poza zasięgiem (2,2 m).
- **Uzupełnianie zapasów:** nie dodajemy nowych zasobów (#54). Istniejący punkt łupu kawiarni przenosi się **za ladę** (na barek) — nagroda za wejście, bez nowej ekonomii. Otwarte pytanie do właściciela (sekcja 7).

### 2.3 Kawiarnia jako mini-przystań

- **Lada do rogu NW:** `cafe_counter` → środek (−27,4; 0; −28,7), rozmiar 5,1 × 1,1 × **2,6** (głębiej o 0,3 m: przejście baristy 1,0 → **1,14 m**; model rozciąga się ×1,14, w limicie 1,15). Zachodni koniec przy ścianie x = −30 (5 cm luzu), barek przy ścianie z = −30. Przejście ma wtedy **jedno** otwarte wejście — od wschodu.
- **Kolizja lady dzielona** (`LevelKit.collision_shapes` dla `cafe_counter`): lada z przodu (lokalne z ∈ [0,33h; h], h = pół głębokości) i barek (z ∈ [−h; −0,55h], wys. 2,9) — między nimi wolne przejście `LevelKit.cafe_aisle(size)` (jedno źródło prawdy dla kolizji, przystani i testów). Greybox lady = dwie bryły (jak kolizja). `test_collisions_are_the_greyboxes` zostaje zielony (obie wersje biorą te same kształty).
- **Klapa lady** `cafe_flap` — nowy element układu: (−24,6; 0; −28,84), 1,14 × 1,1 × 0,5, yaw −90° (front na wschód). Zamyka wschodni koniec przejścia. W grze `CafeFlap` (Interactable) na bryle elementu: `[E] Unieś klapę` → blat unosi się o hinge przy zachodniej krawędzi, panel pod nim odchyla się przy barku, **kolizja wyłączona** (`collision_layer = 0`); **opada sama** 3 s po tym, jak Strażnik odejdzie > 0,9 m. Siatka nawigacji pieczona z klapą zamkniętą — **nigdy nie prowadzi do przejścia** (zamierzone, bez przepieczeń). Wygląd (art): marmurowy blat, dębowy panel, mosiężna listwa zawiasu (kod, materiały pod kolor lady); greybox: bryła.
- **Przystań `cafe`:** `Haven.make(&"cafe", AABB)` nad przejściem (plus bryła klapy; y 0..2,4). Nie ma jej w `haven_spots`, więc **bez leczenia i zapisu** — ale: eksponaty nie wchodzą (ściany `ENEMY_BLOCK` na końcach; szukają przy klapie 8 s i wracają), nie ścigają, broń opada (bez strzału zza lady — oddech, nie bunkier), muzyka cichnie, zegar stoi ≤ 60 s na wizytę, hałas robienia kawy niesłyszalny, latarnia nigdy nie leży za ladą.
- **Nie podczas finału:** `Haven.active` (nowe pole; `at()`/`shelters()` pomijają nieaktywne, ściany tracą warstwę) — `CafeCorner` wyłącza przystań na `Events.boss_awakened`, włącza na `boss_defeated`. Bez tego lada byłaby schronem przed T-Reksem (jego logika czyta `Haven.shelters`). Straż (`GuardianKeeper.fighting`) nie dotyczy Dziedzińca.
- **Ekspres** (`CafeMachine`, marker `cafe_machine` na bojlerze: (−26,58; 1,03; −28,0), front −Z = strona baristy) z ciepłą lampką bojlera (OmniLight, 0,6 / 3 m): gotowy = lampka ciepła i równa, **grzeje się 90 s po kubku = przygaszona (0,25)**, po 3:00 **wariuje** — lampka migocze (powoli i nierówno, poniżej 3 zmian na sekundę), podpowiedź „Ekspres coś nalewa: <absurd> (ręce drżą)” (5 kluczy, wybór po liczbie nalanych kaw tej nocy — deterministycznie), serwuje `special`. Z sali (strona dźwigni po drugiej stronie lady) tylko podpowiedź „Dźwignie są po drugiej stronie lady” + `deny`.
- **Termos** (`CafeUrn`, marker `cafe_urn` na barku: (−26,4; 0,94; −29,55), front +Z do przejścia): stalowy walec z kranikiem (kod), `large`, kapie 150 s; po 3:00 etykieta absurdalna („Termos coś nalewa: …”), efekt bez zmian. Strefa użycia sięga 0,5 m w stronę przejścia, bo lity blok barku zaczyna się 6 cm przed termosem i zasłaniałby go promieniowi użycia.
- **Tabliczka** (`CafeSlate`, marker `cafe_slate`: (−27,05; 1,03; −27,74), front do sali): 0,40 × 0,30 m, pochylona do tyłu, kreda (czcionka tytułowa `UiTheme`, rozmiar 38, bez cieniowania): „MENU NOCNE / ESPRESSO · DUŻA / DARMO DO 9:00”; po 3:00: „MENU ??? / EKSPRES LEJE / CO CHCE” (EN: „NIGHT MENU / ESPRESSO · LARGE / FREE UNTIL 9:00”, „MENU ??? / MACHINE POURS / WHAT IT WANTS”). Test mierzy szerokość każdej linii czcionką w obu językach (≥ 6 cm luzu). To są „zmieniające się etykiety” — bez przepiekania tekstur modelu.
- **Markery przeniesione:** `note_court_1` na wolny blat między ekspresem a gablotą (−27,6; 1,1; −27,85); punkt łupu z blatu na barek (−25,6; 0,94; −29,68).
- **Zdarzenia głosu** (`Events`, na końcu pliku — scalanie jako unia): `cafe_entered` (pierwsze wejście za ladę tej nocy), `coffee_drunk(kind)` (`kind` ∈ espresso/large/special; reguły filtrują nowym polem `kind`), `cafe_haywire` (pierwsze wejście za ladę po 3:00). `VoiceCatalog.EVENTS` i `RULE_FIELDS` += , `VoiceRules.matches` czyta `kind`. **Bez nowych nagrań** — G2.
- **Dźwięki** (bez odsłuchu; `tools/sfx/gen_sfx.py`, biblioteka standardowa): `cafe_flap` (skrzyp drewna + stuk marmuru), `espresso` (syk pary + kapanie); `deny` dla odmów (istnieje). `Sfx.SOUNDS` += 2.

### 2.4 HUD (#42)

`_stamina_bar` z `ProgressBar` na własny `StaminaBar` (Control, `_draw`, 320 × 8, to samo tło i kolor wypełnienia): od lewej stamina (`fraction`), **od prawej segment „zmęczenia”** (pojemność zjedzona: `1 − cap_fraction`) w przygaszonym łupkowym fiolecie (0,42; 0,38; 0,50; 0,85) z cienkim ukośnym kreskowaniem (czytelne: „zablokowane”, nie „puste”); wyczerpanie czerwieni jak dziś; **kofeina**: wypełnienie przechodzi w kremową śmietankę (crema, `StaminaBar.CAFFEINE` → `CAFFEINE_PEAK`) z wolnym pulsem — jasna i blada, żeby nie była bliźniaczką czerwieni wyczerpania (miedź miała tę samą jasność i odcień obok) — bez ikon. Winieta zmęczenia osobna od czerwonej; mrugnięcie dwoma `ColorRect` (góra/dół). Metody do testów: `stamina_bar.tired_fraction()`, `fatigue_shade()`, `blink_phase()`.

## 3. Pliki

| Plik | Zmiana |
|---|---|
| `src/player/fatigue.gd` | **nowy** `Fatigue`: stałe, `tick(delta, sprinting, resting)`, `night_fraction`, `add_dash()`, `effect()`, `capacity_factor()`, `regen_factor()`, `sway_factor()`, `jitter()`, `drink(kind)`, `caffeinated()`, `buff_left`, `to_dict()/from_dict()`, `reset()` |
| `src/player/stamina.gd` | `capacity_factor`, `regen_factor`, `cap()`, `cap_fraction()`; `tick` używa ich |
| `src/player/player.gd` | `fatigue`; tykanie w `_physics_process` (po staminie), dash → `add_dash`, `respawn` → `reset` |
| `src/game/night_watch.gd` | karmi `player.fatigue.night_fraction` (setup i `_process`) |
| `src/game/museum.gd` | `_guard_state` += `fatigue`; `_restore_guard` |
| `src/weapons/weapon_holder.gd` | kołysanie × zmęczenie, dryf, drżenie po specjalności |
| `src/ui/hud.gd` | `StaminaBar`, winieta zmęczenia, mrugnięcie |
| `src/game/floor1/coffee.gd` | **nowy** `Coffee`: rodzaje, klucze etykiet, `machine_kind(haywire)`, `absurd_label(index)` (efekty czyta się z `Fatigue.COFFEES`) |
| `src/game/floor1/cafe_corner.gd` | **nowy** `CafeCorner` + klasy wewnętrzne `CafeFlap`, `CafeMachine`, `CafeUrn`, `CafeSlate`; `setup(level, guard_source, hud)` |
| `src/game/floor1/floor_game.gd` | `cafe = CafeCorner` w `setup` |
| `src/haven/haven.gd` | `active`, `set_active()` |
| `src/level/level_kit.gd` | kolizja `cafe_counter` (dwie bryły), `cafe_aisle(size)`, greybox lady dwubryłowy, rola `cafe_flap` |
| `src/level/floor1/zones/court.gd` | lada do rogu (2,6 głęb.), `cafe_flap`, markery `cafe_machine`, `cafe_urn`, `cafe_slate`, przeniesione `note_court_1` i łup |
| `src/style/floor1_art.gd` | `&"cafe_flap"` → `_cafe_flap(size)` (Slab, Panel, Hinge) |
| `src/core/events.gd` | `cafe_entered`, `coffee_drunk(kind)`, `cafe_haywire` (na końcu) |
| `src/audio/voice/voice_director.gd`, `voice_catalog.gd`, `voice_rules.gd` | podpięcie, `EVENTS`, `RULE_FIELDS`, pole `kind` |
| `src/fx/sfx.gd`, `tools/sfx/gen_sfx.py`, `assets/sfx/cafe_flap.wav`, `assets/sfx/espresso.wav` | dwa dźwięki |
| `locale/strings.csv` | na końcu: podpowiedzi, toasty, etykiety kaw, absurdy, tabliczka |
| `docs/superpowers/plans/2026-10-10-kawiarnia-zmeczenie.md` | ten plan |

## 4. Zadania (TDD, jeden commit na zadanie)

### Zadanie 1 — Plan
- [x] Ten dokument. Commit `Cafe and fatigue: the plan`.

### Zadanie 2 — `Fatigue` i mnożniki `Stamina`
- Testy `tests/unit/test_fatigue.gd`: sama noc daje 0,60 (±0,01) przy całkowaniu co 1/60 s; w połowie nocy < próg; próg: `effect()` 0 poniżej 0,35, 1 przy F = 1, 0,5 przy 0,675; `capacity_factor` 0,7 i `regen_factor` 0,65 przy F = 1; sprint +0,0006/s, dash +0,003, odpoczynek −0,0015/s, nigdy < 0 ani > 1; espresso: −0,30, 90 s, regen 1,25; duża: −0,15, 240 s, blokuje wzrost (czas, sprint, dash), regen 1,10; specjalność: −0,45, 60 s, 1,40, `jitter()` 1 → 0 w 12 s; druga kawa: ulga zawsze w pełni, zostaje kofeina z większą ilością czasu (czas nie sumuje się); `to_dict/from_dict` wiernie; `reset()`.
- Testy `tests/unit/test_stamina.gd`: `capacity_factor` 0,7 → regen zatrzymuje się na 70, `cap_fraction()` 0,7, `fraction()` liczy od pełnych 100; bieżąca stamina ponad nowym limitem spada do limitu w `tick`; `regen_factor` 0,5 → połowa regeneracji; wyczerpanie kończy się przy `min(recover_at, cap)`.
- Kod: `fatigue.gd`, `stamina.gd`. Commit `Fatigue model: the night's curve, exertion, rest, the three coffees; stamina capacity and regen factors`.

### Zadanie 3 — Strażnik, zegar, zapis
- Testy `tests/integration/test_player.gd` (+): sprint podnosi `fatigue.level`, dash też; `respawn` zeruje; `refill` nie zeruje. `tests/integration/test_night_watch.gd` (+): po przestawieniu `clock.elapsed` na połowę nocy `player.fatigue.night_fraction` ≈ 0,5; zmęczenie rośnie samo poza przystanią, a w kanciapie maleje. `tests/integration/test_museum.gd` (+ w `test_cafe_night.gd`): zmęczenie 0,5 i kofeina `large` 100 s → `quit_to_menu` → `load_game` → nowa scena: level ±0,001, buff `large`, `buff_left` ≈ 100.
- Kod: `player.gd`, `night_watch.gd`, `museum.gd`. Commit `Fatigue in the game: the guard ticks it, the clock feeds it, the save keeps it`.

### Zadanie 4 — HUD
- Testy `tests/integration/test_hud.gd` (+): `tired_fraction()` 0 przy F = 0; 0,3 przy F = 1; kofeina → kolor wypełnienia zmierza do `UiTheme.ACCENT`; `fatigue_shade()` 0 poniżej progu, 0,22 przy F = 1; mrugnięcie: przy F = 1 w 14 s pojawia się faza > 0, przy F = 0 nigdy.
- Kod: `hud.gd` (`StaminaBar`, winieta, powieki). Commit `HUD: the stamina bar eaten from the right by tiredness, caffeine in brass, a cool vignette and a rare blink`.

### Zadanie 5 — Kołysanie broni
- Test `tests/integration/test_weapon_holder.gd` (+): zmęczony (F = 1) strażnik w ruchu — amplituda pozycji widoku większa niż świeżego; w spoczynku dryf > 0 przy F = 1 i 0 przy F = 0; drżenie po specjalności gaśnie.
- Kod: `weapon_holder.gd`. Commit `Weapon sway: a tired guard's hands move a little more, a special coffee shakes them for a moment`.

### Zadanie 6 — Układ kawiarni (lada w rogu, przejście, klapa, markery)
- Testy `tests/unit/test_court_cafe.gd`: lada w rogu NW (zachodni koniec ≤ 0,1 m od x = −30, tył ≤ 0,05 m od z = −30); `LevelKit.collision_shapes(&"cafe_counter", size)` = 2 bryły; `cafe_aisle` szerokie ≥ 1,0 m, wewnątrz obrysu lady; klapa `cafe_flap` zamyka wschodni koniec przejścia (obrys klapy pokrywa przejście w z, styka się z końcem lady w x); markery `cafe_machine`, `cafe_slate` nad ladą z przodu, `cafe_urn` nad barkiem, wszystkie w `court`; `note_court_1` na blacie poza gablotą i ekspresem; żaden slot, punkt łupu na podłodze, punkt patrolu ani marker areny nie leży w przejściu ani w obrysie lady/klapy; łup kawiarni stoi na barku w przejściu (y 0,94). `test_floor1_hub` bez zmian (liczniki `note_` itd.).
- Test `tests/integration/test_floor1_art_fit.gd`: przechodzi (`cafe_flap` w swojej bryle; lada rozciągnięta w limitach). `test_floor1_art::test_the_dressed_zones_wear_the_kit...`: `cafe_flap` ma wygląd (nie greybox).
- Kod: `court.gd`, `level_kit.gd`, `floor1_art.gd`. Commit `The court café moves into the corner: a split counter with a barista's aisle, a counter flap, the machine, urn and slate markers`.

### Zadanie 7 — `CafeCorner`: przystań-kieszeń i klapa
- Testy `tests/integration/test_cafe_corner.gd` (greybox `MuseumFloorLevel` + `Player` + `CafeCorner.setup(level, …)`): `Haven.shelters` prawdziwe w przejściu, fałszywe na podłodze sali przed ladą i za barkiem (w ścianie); strażnik idący na zachód w klapę **zatrzymuje się** przy zamkniętej; po `interact` przechodzi do przejścia; klapa opada 3 s po odejściu (kolizja wraca); obudzona figura woskowa z sali nie wchodzi do przejścia w 4 s; siatka: punkt w przejściu **nie łączy się** z podłogą sali (NavProbe) przy zamkniętej klapie; `boss_awakened` → przystań nieaktywna (`shelters` fałsz), `boss_defeated` → aktywna; `cafe_entered` raz na noc.
- Kod: `haven.gd` (`active`), `cafe_corner.gd` (Haven + `CafeFlap`), `floor_game.gd`. Commit `The café corner: the barista's aisle is a pocket haven (calm, no heal, no save), the counter flap lifts and drops`.

### Zadanie 8 — Kawa: ekspres, termos, tabliczka, stany nocy
- Testy `tests/unit/test_coffee.gd`: trzy rodzaje z liczbami z 2.2; `machine_kind(false)` = espresso, `machine_kind(true)` = special; urn nalewa large; `absurd_label(i)` cyklicznie, klucze istnieją w `strings.csv`. `tests/integration/test_cafe_corner.gd` (+): ekspres użyty z sali → `hint_requested` + brak kawy; z przejścia → `fatigue.level` spada o 0,30, `caffeinated()`, `coffee_drunk(espresso)`; drugie użycie w 90 s odmawia (podpowiedź „grzeje się”), po 90 s znów nalewa; termos: `large`, 150 s; `Events.witching_hour` → ekspres serwuje `special`, podpowiedź z absurdalną etykietą, tabliczka zmienia tekst, lampka migocze (`haywire()`), `cafe_haywire` raz przy wejściu; wznowiona noc po 3:00 (`setup` z zegarem po 3:00) startuje w stanie haywire.
- Kod: `coffee.gd`, `cafe_corner.gd` (`CafeMachine`, `CafeUrn`, `CafeSlate`), `events.gd`, `strings.csv`, `sfx.gd`, `gen_sfx.py` + dwa WAV (bez odtwarzania). Commit `Coffee: the espresso machine and the urn behind the counter, the chalk slate, the machine goes haywire after the witching hour`.

### Zadanie 9 — Zdarzenia głosu
- Testy `tests/integration/test_voice_director.gd` (+): wstrzyknięte reguły (`catalog.add_line`) na `coffee_drunk` z `kind: espresso` i `kind: large` — tylko pasująca wchodzi do kolejki; `cafe_entered`, `cafe_haywire` kolejkują. `test_voice_data` zielony (zdarzenia w `EVENTS` i `Events`).
- Kod: `voice_director.gd`, `voice_catalog.gd`, `voice_rules.gd`. Commit `Voice events for the café: entering the aisle, a coffee drunk (by kind), the haywire machine`.

### Zadanie 10 — Scalenie i stan
- `git merge pietro-1`, konflikty jako unie, pełny zestaw `bash tools/run_tests.sh`, sekcja „Stan prac”. Commit `Café and fatigue: plan status after merging pietro-1`.

## 5. Testy — mapa

| Obszar | Plik |
|---|---|
| krzywa zmęczenia, progi, efekty, kawy, czasy, zapis | `tests/unit/test_fatigue.gd` |
| mnożniki staminy | `tests/unit/test_stamina.gd` |
| katalog kaw, etykiety, klucze | `tests/unit/test_coffee.gd` |
| układ: lada, przejście, klapa, markery, wolna podłoga | `tests/unit/test_court_cafe.gd` |
| przystań-kieszeń, klapa (kolizja), eksponaty, siatka, finał, ekspres, termos, stany nocy, zdarzenia | `tests/integration/test_cafe_corner.gd` |
| strażnik, zegar, zapis wznowionej nocy | `tests/integration/test_player.gd`, `test_night_watch.gd`, `test_cafe_night.gd` |
| HUD | `tests/integration/test_hud.gd` |
| kołysanie | `tests/integration/test_weapon_holder.gd` |
| głos | `tests/integration/test_voice_director.gd`, `tests/unit/test_voice_data.gd` |

## 6. Do sprawdzenia w oknie (zakaz okien — zostaje właścicielowi / kontrolerowi)

- [ ] Lada w rogu NW: czy model nie przecina ściany (5 cm luzu na zachodzie), czy rozciągnięcie ×1,14 w głąb nie psuje proporcji gablot i barku.
- [ ] Przejście 1,14 m: czy chodzenie za ladą jest wygodne (kapsuła 0,8 m), czy kamera nie wchodzi w półki barku.
- [ ] Klapa: animacja uniesienia (blat odchylony do 160°, czyli leży tuż nad poziomem, panel 80°) i opadnięcia; czy opada za szybko/za wolno (3 s po odejściu); dźwięk `cafe_flap` (nikt go nie słyszał).
- [ ] Tabliczka kredą: czytelność z 2–3 m, kolor kredy na łupku, czy tekst nie wychodzi poza tabliczkę w obu językach.
- [ ] Lampka bojlera: ciepło i zasięg (0,6 / 3 m), migotanie po 3:00 — ma być widoczne, nie stroboskopowe.
- [ ] Termos i kranik na barku: skala, czy nie wchodzi w półkę ze słojami.
- [ ] HUD: segment zmęczenia (łupkowy fiolet, kreskowanie) czytelny na 1080p obok czerwieni wyczerpania; kremowa kofeina odróżnialna od żółci staminy i od czerwieni wyczerpania; winieta 0,22 i mrugnięcie — czy nie męczą w praktyce (próg, okres).
- [ ] Kołysanie: czy przy F = 1 broń nie „pływa” za bardzo; drżenie po specjalności (12 s, ok. 10 Hz, amplituda 6 mm — czy to „drżenie rąk”, a nie wibracja).
- [ ] Po poprawkach przeglądu: klapa — blat odchylony do 160° leży nad przejściem na wysokości ok. 1,1–1,3 m: czy nie przecina ręki z bronią ani tułowia przy wejściu (nie ma kolizji, tylko wygląd); czy ruch zawiasu nadal czyta się jako „uniesiona klapa”.
- [ ] Po poprawkach przeglądu: HUD — kremowa kofeina odróżnialna od żółci staminy i od czerwieni wyczerpania na pasku 8 px (1080p, w ruchu); puls nie zbyt jaskrawy.
- [ ] Po poprawkach przeglądu: drżenie rąk ok. 10 Hz (6 mm) — czy to „trzęsące się ręce”, a nie wibracja ekranu; podpowiedź po poziomym spojrzeniu na klapę (oko 1,6) z sali i zza lady.
- [ ] Dźwięk `espresso` (syk + kapanie) — poziom i długość.
- [ ] Przebieg: pełna noc bez kawy — czy zmęczenie w ogóle daje się odczuć (próg 0,35 może być za wysoki lub za niski).

## 7. Decyzje kontrolera (odpowiedzi na pytania otwarte; właściciel może je zmienić)

1. **Cena kawy: DARMO.** Właściciel chce lekkiego nacisku na zasoby i „nie karać za to, czego gracz nie może uniknąć”; Pył zostaje walutą stałej progresji. Racjonowanie wyłącznie czasem (ekspres 90 s, termos 150 s). Zmiana na „kupowanie” = jedna stała (propozycja: 3 Pyłu za espresso / 2 za dużą, pierwsza darmo).
2. **Zapasy: BEZ uzupełniania w kawiarni.** To oddech, nie sklep — ekonomia zostaje bez zmian. Istniejący punkt łupu kawiarni leży za ladą (przeniesiony w zadaniu 6, nic nowego nie przybywa).
3. **Zapis i leczenie: kieszeń BEZ zapisu i BEZ leczenia** (tak jak w projekcie z sekcji 2.3). Uzasadnienie w jednym zdaniu: sześć przystani skrzydeł zostaje jedynym miejscem zapisu i leczenia, więc kawiarnia daje oddech i kawę, ale nie staje się siódmym darmowym apteczkiem tuż przy hubie.
4. **Specjalność nocy zostaje** z krótkim drżeniem rąk (12 s) — to wybór gracza, widoczny w podpowiedzi.
5. **Liczby zmęczenia** (próg 0,35, −30 % pojemności, −35 % regeneracji przy maksimum) — do strojenia po pierwszym playteście (wszystko w stałych `Fatigue`).

## 8. Stan prac / co dalej

> Gałąź `cafe-fatigue` (od `pietro-1` @bceeee8, scalona z `pietro-1` @69f576e — nagrody sekretów, konflikt tylko w `locale/strings.csv`, rozwiązany jako suma), worktree `guard-general`, 18–19 października 2026. **Wszystkie zadania 1–10 zrobione, poprawki po przeglądzie (poniżej) naniesione.** Pełny zestaw po poprawkach i po scaleniu: **2391 zielone, 0 czerwonych** (po samych poprawkach 2344, przed nimi 2334), bez linii `ERROR` silnika. Zostają wyłącznie kontrole w oknie (sekcja 6) i ewentualne strojenie liczb po playteście.

### Zrobione (zadania 1–6, każde zielone w swoim filtrze, jeden commit na zadanie)
- **1** `41493c7` plan.
- **2** `9a7ddbc` `Fatigue` (`src/player/fatigue.gd`) + mnożniki `Stamina` (`capacity_factor`, `regen_factor`, `cap()`, `cap_fraction()`); testy `test_fatigue.gd` (13), `test_stamina.gd` (+3).
- **3** `fc7ea6d` strażnik tyka zmęczenie (`player.gd`), `NightWatch` karmi ułamek nocy, zapis w `Museum._guard_state` / `_restore_guard` + `PersistentState.clean_progress` („fatigue”); testy `test_player.gd` (+3), `test_cafe_night.gd` (3), `test_game_state.gd`.
- **4** `2531e24` HUD: `Hud.StaminaBar` (segment zmęczenia od prawej, kreskowany łupek; kofeina = miedź `(0,9; 0,46; 0,15)` z pulsem), winieta zmęczenia 0,22, mrugnięcie 14→7 s; `test_hud.gd` (+4).
- **5** `8975c16` kołysanie broni (`weapon_holder.gd`: bob × `sway_factor`, dryf 4 mm, drżenie 6 mm po specjalności); `test_weapon_holder.gd` (+2).
- **6** `0ceddd8` układ: lada w rogu NW (−27,4; 0; −28,7), 5,1 × 1,1 × 2,6; `LevelKit.collision_shapes(cafe_counter)` = lada + barek, `LevelKit.cafe_aisle()`; element `cafe_flap` (−24,6; 0; −28,84) z wyglądem w kodzie (`Floor1Art._cafe_flap`); markery `cafe_machine` (−26,58; 1,03; −28,0), `cafe_slate` (−27,05; 1,03; −27,74), `cafe_urn` (−26,4; 0,94; −29,55); `note_court_1` → (−27,6; 1,1; −27,85); łup kawiarni na barek (−25,9; 0,94; −29,42). **Uwaga:** import lustrzy model w x — gablota z ciastami stoi przy ścianie zachodniej, ekspres i kasa przy klapie (sekcja 2.3 pisana przed tym odkryciem). Testy `test_court_cafe.gd` (5), `test_art_court.gd` (+1); zielone też: `test_floor1_hub`, `art_fit`, `test_floor1_art`, `map_model`, `museum_map`, `level_builder`, `hub_walk`, `reachability`.

### Zrobione — zadanie 7 (`CafeCorner`, przystań-kieszeń i klapa)
- `src/game/floor1/cafe_corner.gd` (`CafeCorner` + `CafeFlap`), `Haven.active`/`set_active()`, `FloorGame.cafe`, `Events.cafe_entered/coffee_drunk/cafe_haywire`, `PROMPT_CAFE_FLAP`, dźwięki `cafe_flap` i `espresso` (`gen_sfx.py`, WAV-y; nikt ich nie słyszał), `tests/integration/test_cafe_corner.gd` (6 testów).
- Filtr `cafe_corner,test_haven,test_sfx,audio_assets,localization,floor1_game_world` zielony (51/51) bez poprawek kodu WIP-u: przystań w przejściu (nie ma jej w `haven_spots`, więc `Museum` nie leczy i nie zapisuje), klapa zatrzymuje, unosi się, opada 3 s po odejściu, eksponat nie wchodzi, siatka nie prowadzi do przejścia, finał zamyka kieszeń, `cafe_entered` raz na noc.

### Zrobione — zadanie 8 (kawa: ekspres, termos, tabliczka, stany nocy)
- `src/game/floor1/coffee.gd` (`Coffee`: rodzaje z liczbami z `Fatigue.COFFEES`, `menu(haywire)`, klucze tekstów, `absurd_label`), w `cafe_corner.gd` klasy `CafeMachine`, `CafeUrn`, `CafeSlate` + `CafeCorner.serve/refuse/set_haywire`; `setup(level, guard, hud, clock)` — zegar pozwala wznowionej nocy po 3:00 wystartować w stanie haywire. Teksty PL/EN w `strings.csv` (`PROMPT_COFFEE_*`, `HUD_COFFEE_*`, `COFFEE_ABSURD_1..5`, `SLATE_NORMAL_*`, `SLATE_HAYWIRE_*`), `test_localization` sprawdza klucze budowane w czasie działania (`Coffee.all_keys()`).
- Testy: `test_coffee.gd` (7), `test_cafe_corner.gd` (+20: ekspres z sali/z przejścia, grzanie 90 s, termos 150 s, nowa kawa zastępuje starą, martwy nie pije, haywire po 3:00, special + drżenie, migotanie lampki, `cafe_haywire` raz, wznowiona noc po 3:00, toast w HUD, promień użycia trafia w ekspres i termos zza lady i nie sięga termosu z sali, tabliczka mieści się w obu językach).
- Filtr `cafe,coffee,fatigue,localization,floor1_game_world,floor1_hub,court,art_fit,test_floor1_art,hud,haven,sfx,voice,game_state,test_museum,persistent` zielony (312/312).

### Zrobione — zadanie 9 (zdarzenia głosu; tylko zdarzenia, bez nagrań)
- `VoiceDirector` słucha `Events.cafe_entered`, `coffee_drunk(kind)`, `cafe_haywire`; `VoiceCatalog.EVENTS` += trzy zdarzenia, `RULE_FIELDS` += `"kind"`; `VoiceRules.matches` filtruje po `kind` (reguła bez `kind` pasuje do każdej kawy; ładunek bez `kind` nie pasuje do reguły, która o niego pyta). Testy: `test_voice_director.gd` (+2, wstrzyknięte reguły), `test_voice_data.gd` (+1). Filtr `voice` zielony (57/57).
- **Dla G2 (nagrania):** reguły do `data/voice/lines.json` — np. `{"speaker":"heniek","event":"cafe_entered"}`, `{"event":"coffee_drunk","kind":"large"}`, `{"speaker":"system","event":"cafe_haywire","priority":0}`; `cafe_entered` i `cafe_haywire` mogą paść razem (pierwsze wejście za ladę po 3:00), kolejka puści drugą po `LINE_GAP` (20 s) — rozróżnić priorytetem albo `delay`.

### Zrobione — zadanie 10 (scalenie i stan)
- `git merge pietro-1` (22 commity, strażnik Ameryk — wąż) bez konfliktów; pełny zestaw `bash tools/run_tests.sh`: 2334 zielone, 0 czerwonych. Po tym zadaniu nie ma już nic, co blokowałoby scalenie `cafe-fatigue` do `pietro-1`.

### Poprawki po przeglądzie (18 października 2026, po zadaniu 10)
Osiem uwag z przeglądu, każda z testem pisanym przed kodem; zielone w swoich filtrach, jeden commit na grupę.
1. **Drżenie rąk po specjalności** (`weapon_holder.gd`): szum `FastNoiseLite` miał domyślną częstotliwość 0,01, więc przy próbkowaniu `t × 40` dryfował ok. 1 Hz i ≤ 0,2 mm na klatkę — test przechodził tylko dlatego, że opadanie po zmianie broni jeszcze trwało. Teraz `JITTER_FREQUENCY = 0,25` (ok. 10 Hz, amplituda bez zmian: 6 mm). Test odczekuje 40 klatek, porównuje z tym samym strażnikiem przed kawą (0 mm na klatkę) i liczy zawrócenia ruchu (26 na sekundę zamiast 2).
2. **Kofeina nie przepada** (`fatigue.gd` `drink()`): duża kawa (240 s) i espresso (90 s) nie wyrzucają już ok. 140 s; zostaje kofeina z większą ilością czasu (nowa przejmuje przy `>=`), ulga i drżenie liczą się zawsze. Testy: `test_fatigue.gd` (4: krótsza nie nadpisuje dłuższej, dłuższa przejmuje po spalonej, ta sama kawa startuje od nowa, specjalność po dużej), `test_cafe_corner.gd` (urna, potem ekspres).
3. **Klapa w oczach** (`CafeFlap.SLAB_UP` 95° → 160°; `floor1_art.gd` opis): odchylony blat stał pionowo w wejściu na 1,1–1,6 m (oko 1,6); teraz leży 20° ponad poziomem, jego górna krawędź ok. 1,32 m. Test (`_dressed_flap()`: klapa z wyglądem z `LevelArt.piece_look`, bo zielona podłoga testów ma tylko klocek) sprawdza, że żadna bryła klapy nie wchodzi w pas ±0,2 m wokół oka na całej długości przejścia.
4. **Promień użycia klapy** do 1,9 m (`USE_TOP`): poziomy wzrok (oko 1,6) z sali i z przejścia dostaje podpowiedź. Test z obu stron + „nie na sufit”.
5. **3:00 przy strażniku już za ladą**: `_on_witching_hour` woła `_entered()`, więc `cafe_haywire` pada od razu (raz na noc).
6. **HUD**: kofeina to teraz kremowa śmietanka z pulsem (`CAFFEINE` (0,96; 0,89; 0,72) → `CAFFEINE_PEAK` (1,0; 0,97; 0,88)) zamiast miedzi, która miała tę samą jasność co czerwień wyczerpania (luminancja 0,53 vs 0,54, odległość 0,28). Test mierzy w całym pulsie: odległość od czerwieni > 0,6 oraz jaśniejsza od niej o > 0,2, od żółci > 0,3.
7. **Drobiazgi**: `StaminaBar.show_state` woła `queue_redraw()` tylko przy zmianie (wartość, pojemność, stan, obrót wypełnienia; co klatkę tylko pulsująca kofeina bez wyczerpania; licznik `draws` dla testu). `Coffee.menu()`/`facts()` usunięte (używały ich tylko testy; `test_coffee.gd` czyta `Fatigue.COFFEES` sam).
8. **Luki w testach**: zamknięta klapa użyta od środka (trzyma, da się wycelować, otwarta wypuszcza); eksponat przy **otwartej** klapie też nie wchodzi.

### Co dalej
1. Kontrole w oknie (sekcja 6 + poniżej) — kontroler / właściciel.
2. G2: reguły i nagrania do trzech zdarzeń kawiarni (patrz zadanie 9).
3. Strojenie po playteście: stałe w `Fatigue` (próg 0,35, −30 % / −35 %), `Coffee` (grzanie 90 s, kapanie 150 s), `Fatigue.COFFEES`.

### Do sprawdzenia w oknie
Sekcja 6, a ponadto (po zadaniu 8):
- [ ] Promień użycia: czy `[E]` pojawia się na ekspresie i termosie zza lady z naturalnych miejsc (strefa ekspresu 0,7 × 0,85 × 0,7 m, termosu 0,7 × 0,55 × 0,5 m wysunięta ku przejściu); z sali ekspres odpowiada podpowiedzią „Dźwignie są po drugiej stronie lady”.
- [ ] Tabliczka: kreda 38 pt na 0,40 m — czy czytelna z 2–3 m (mierzone tylko szerokością, nie wyglądem); czy pochylona deska nie wchodzi w podstawę ekspresu.
- [ ] Termos: stalowy walec z kranikiem (kod) — skala i czy kran patrzy na przejście; czy stoi na blacie barku, a nie w półce.
- [ ] Lampka bojlera: przygaszona w czasie grzania (0,25), ciepła gdy gotowy (0,6), po 3:00 migotanie — widoczne, nie stroboskopowe (poniżej 3 zmian na sekundę).
- [ ] Podpowiedź ekspresu po 3:00 („Ekspres coś nalewa: … (ręce drżą)”) — czy mieści się w panelu podpowiedzi.
