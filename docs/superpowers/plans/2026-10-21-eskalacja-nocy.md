# Eskalacja nocy i zmieniający się świat — krzywa nocy, zdarzenia „nie z tego świata”, zapowiedzi, zmiany przy powrocie

> Plan wykonawczy. Wykonawca: jeden agent w worktree `guard-general` (gałąź `night-escalation` od `pietro-1` @6e40254).
> Źródło: backlog właściciela `docs/backlog-pietro1.md` — **#34** („naturalna progresja nocy: początek względnie spokojny i dziwny, potem zdarzenia paranormalne coraz bardziej oczywiste, pod koniec muzeum opanowane przez anomalie; świat ma wizualnie i gameplayowo pokazywać eskalację”), **#35** („powroty do wcześniejszych części muzeum czasami pokazują, że świat się zmienił: eksponat zniknął, drzwi są otwarte, obraz patrzy w inną stronę, ślady, coś przeszło przez korytarz”), **#28** (zapowiedź wrogów: „jeśli później ożyje posąg albo mumia wyjdzie z sarkofagu, wcześniej subtelnie pokazać podobny eksponat albo ślad”), lista rozszerzona „Świat, zdarzenia, narracja” (zdarzenia muzealne niezwiązane z walką — obraz zmienia treść, zegar chodzi wspak, eksponat znika, manekin obraca głowę, radio nadaje coś niepokojącego; część rzadka/warunkowa; **najlepsze momenty ręcznie zaprojektowane**; światło jako mechanika: migotanie, awaryjne, cienie zapowiadające wroga) i „Przeciwnicy i AI” (prosty reżyser tempa steruje **tylko drobnymi rzeczami** — momentem zdarzeń otoczenia; wrogowie widziani, zanim staną się zagrożeniem).
> **Bez okien i bez dźwięku:** tylko `--headless`, skrypty. Nic nie trafia na GitHub. Bez nowych nagrań głosu (G3) i bez nowych dźwięków — zdarzenia używają istniejących efektów `Sfx`.

**Cel:** noc ma krzywą. 23:00–1:00 jest cicho i *dziwnie* (mrugnie lampa, oczy obrazu pójdą za strażnikiem, w sali, z której wyszedł, figura stoi zwrócona do drzwi). 1:00–3:00 robi się niepokojąco (lampy się dławią, za ścianą coś ciężkiego upada i eksponaty idą sprawdzić, drzwi trzaskają same). Od 3:00 (godzina duchów, już istnieje: +20 % szybkości i obrażeń) światła gasną na sekundy, gasną po kolei „pod czymś, co idzie”, sala, do której wraca, stoi ciemna. 5:00–6:00 to kulminacja przed świtem: każda sala, do której wchodzi, łapie zadyszkę światła, znaki WYJŚCIE migają na czerwono. Do tego **zapowiedzi** — każda ważna zasadzka i każdy strażnik skrzydła zdradza się wcześniej (wieko sarkofagu uchylone, pył spod płaskorzeźby, błysk hełmu, zgrzyt kolosa za ścianą) — i **świat zmieniony przy powrocie** (na cokole pusto, popiersie odwrócone do ściany, z portretu zniknęła postać, ławka obrócona), uczciwie: nic nie zastawia drogi, nic nie zabiera przedmiotu, zapis wznowionej nocy pokazuje to samo.

**Architektura:**
1. **Krzywa** — `NightEscalation` (`src/game/night_escalation.gd`, czysta, obok `NightClock`): faza z zegara (CALM 23–1, UNEASY 1–3, WITCHING 3–5, PREDAWN 5–6), natężenie 0..1, odstęp między zdarzeniami tła (maleje z fazą; noc 1 łagodniej, noc ≥ 4 gęściej, noc spokojna rzadziej), skala szansy zmian przy powrocie i skala hałasu (aktywność wrogów).
2. **Dane** — tabela `data/night/uncanny.json` (ręcznie zaprojektowane zdarzenia: wyzwalacz, warunki, gdzie, zapowiedź, czas, rzadkość, dźwięk, hałas, opcjonalna myśl strażnika, łącze z głosem / notatka G3), ładowana i sprawdzana przez `UncannyCatalog`.
3. **Reguły** — `UncannyRules` (czyste): czy zdarzenie pasuje (faza, noc, modyfikator, limity, zasadzka czeka, strażnik nie pokonany…), losowanie ważone, **uczciwość celów** (kawałki dekoracji: nie w arenie / przystani / sali strażnika, żadnego znacznika ani punktu łupu przy nich, obrót tylko o 180° albo wielokrotność 90° przy kwadratowej podstawie — obrys się nie zmienia, więc kolizja i navmesh zostają prawdziwe).
4. **Efekty** — `RoomLamps` (Node: lampy sali — mrugnięcie, migotanie, przygaszenie, zgaśnięcie, „przejście”, znaki wyjścia; tylko energia lamp i blask opraw, nigdy `visible`), `PaintingGaze` (oczy obrazu: model — przesuw UV tęczówek na kopii materiału jak `PortraitRig`; greybox — źrenice), `UncannyEffects` (kawałki: ukryj / obróć; obrazy: podmień / odwróć wzrok; śpiący eksponat zwrócony do drzwi; wieko grobowca uchylone; błysk; pył; zegary wstecz; trzask drzwi; kliknięcie głośnika; radio; dźwięk z hałasem dla percepcji).
5. **Reżyser** — `UncannyDirector` (Node w `FloorGame`): tyka co 0,25 s; zdarzenia tła wg krzywej (tylko gdy spokojnie: strażnik żyje, poza przystanią, nikt nie poluje w pobliżu, nie trwa walka ze strażnikiem / finał); zdarzenia wejścia (`RoomTracker.entered`); zmiany przy powrocie (losowane przy wyjściu z sali, nakładane, gdy strażnik jest daleko i nie patrzy); zmiany nocy (losowane przy starcie nocy dla sal odwiedzonych wcześniejszych nocy); zapis w `RunState.used` i `GameState.uncanny_seen`.
6. **Haki w plikach wspólnych (małe, addytywne):** `Events` (+`night_phase_changed`, +`uncanny_event`), `GameState` (+`uncanny_seen`), `FloorGame` (instalacja reżysera), `VoiceCatalog`/`VoiceDirector` (zdarzenie `uncanny` dla G3), `locale/strings.csv` (kilka myśli strażnika), `export_presets.cfg` (+`data/night/*.json`).

---

## 1. Inwentarz (stan przed zmianą, 21.10)

| Co | Gdzie | Dziś |
|---|---|---|
| Zegar nocy | `NightClock`, `NightWatch` | 23:00–6:00, 180 s/h (21 min); godzina duchów 3:00 (`Events.witching_hour`, eksponaty ×1,2 szybkość i obrażenia); `Events.hour_struck` co godzinę; zapis `clock_<s>` w `RunState.used`; stoi w przystani ≤ 60 s na wizytę |
| Reżyser nocy | `NightDirector.plan` (+`FloorNight`) | deterministyczny z ziarna: modyfikator (noc 1 brak; potem none 40 / blackout 20 / full moon 20 / calm 20), zestawy spotkań, łup, bezpieczniki, portrety (2–4 z 14 miejsc), czuwający (osobny generator), łagodna noc 1. Nic nie zmienia się **w trakcie** nocy |
| Modyfikatory | `NightModifiers` | blackout: lampy `main_lights` zgaszone (`visible=false`), ambient ×0,3; pełnia: księżyc ×1,6, eksponaty +25 %; calm: ~60 % eksponatów |
| Światło | `LevelLighting`, `LightSpec`, `LampFlicker`, `RoomCuller` | grupy: main, emergency (zawsze), haven, moon, flicker (piwnica — `LampFlicker` zmienia tylko energię); lampy mają meta `room`, oprawy grupę `<grupa>_fixtures` (`LevelKit.set_lit`); culler ukrywa lampy na serwerze renderingu, **nie** zmienia `visible` (model światła percepcji czyta `visible`) |
| Ekologia wrogów | `PerceptionWorld`, `ReactionRules`, `Enemy` | hałas `Events.noise_made` → reakcje stopniowane, **limit 3 badających** na miejsce i 6 s, limit polujących wg trudności; „poruszenie we śnie” (wosk, popiersia) gdy strażnik nie patrzy ≤ 1,5 m od posterunku; `Enemy.face()`, `guard_watching()`, `PerceptionWorld.hunters_near()` |
| Zasadzki | `AmbushSpec` (42 na piętrze), `FloorEncounters` | budzą się razem przy wejściu w obszar / podniesieniu przedmiotu; raz na noc (`ambush_<id>`); mumie zasadzek śpią w grobowcach (`Mummy.entombed`, `MummyTomb.lid`) |
| Strażnicy skrzydeł | `GuardianKeeper` | 6 (kolos, lamassu, kentaur, planetarium, generał, wąż) + T-Rex (finał); znaczniki `guardian_<id>`, `arena_<id>_*` |
| Obrazy | `Museum._hang_paintings`, `WallPainting`, `Portrait`, `PaintingArt` | 14 miejsc `portrait_*` (dziedziniec 4, hol północny 2, galeria portretów 8): portrety tej nocy to wrogowie, reszta to `WallPainting` (twarz `ids()[i % 10]`); model: oczy = łatka z materiałem `portrait_eyes` (UV tęczówek), greybox: `pupil_l/r` |
| Zegary | `Floor1ArtEnlightenment._clock` | sala zegarów: 5 zegarów, `DecorSpinner` „Clockwork” (wahadło, wskazówki), grupa `floor1_decor`, meta `kit_room`; tylko w wersji z oprawą |
| Drzwi | `Door`, `MuseumFloorLevel._reset_doors` | zwykłe drzwi (SWING, bez bramy) **zawsze otwarte** i nie da się ich otworzyć z powrotem po zamknięciu (brak klamki); bramy = postęp; piętro I nie ma drzwi „zamykanych na noc” (LOCKABLE) |
| Głos | `VoiceDirector`, `data/voice/lines.json` | 140 kwestii z nagraniami; test wymaga nagrania dla każdej kwestii → **nowych kwestii nie dodajemy** (G3) |
| Kawiarnia | `CafeCorner` | po 3:00 ekspres wariuje (`cafe_haywire`) — wzór: zegar przez `Callable`, `RunState.used` na „widziane tej nocy” |
| Co przetrwa noc | `GameState` | postęp, sekrety, `rooms_visited`, `voice_heard`; zapis nocy w toku: `night_progress` (`killed`, `taken`, `used`, strażnik, pył) |

## 2. Decyzje projektowe

### 2.1 Krzywa nocy (`NightEscalation`)

| Faza | Zegar | Charakter | Odstęp zdarzeń tła (s) | Zmiany przy powrocie (×szansa) | Hałas dla wrogów (×promień) | Światło |
|---|---|---|---|---|---|---|
| **CALM** „spokojnie i dziwnie” | 23:00–1:00 | dwuznaczne drobiazgi | 100–160 | ×0,5 | brak | pojedyncze mrugnięcie |
| **UNEASY** „niepokojąco” | 1:00–3:00 | rzeczy, których nie da się zbyć | 70–110 | ×0,8 | ×0,8 | migotanie, przygaszenie |
| **WITCHING** „godzina duchów” | 3:00–5:00 | jawne anomalie (+istniejące ×1,2) | 45–75 | ×1,0 | ×1,0 | zgaśnięcia na sekundy, „przejście” |
| **PREDAWN** „przed świtem” | 5:00–6:00 | muzeum opanowane | 28–45 | ×1,0 | ×1,2 | zadyszka lamp przy każdym wejściu, znaki WYJŚCIE |

- **Noc:** noc 1 — odstępy ×1,35 (pierwsza noc to nauka); noce 2–3 ×1,0; noc ≥ 4 ×0,85. **Modyfikator:** calm ×1,3 (spokojna noc jest spokojna), pełnia ×0,9, blackout ×1,0 (zdarzenia lamp głównych wypadają — lampy są zgaszone; zostają znaki wyjścia, dźwięki, obrazy).
- **Natężenie 0..1** (dla muzyki/ambientu w przyszłości): 0,1 → 0,35 → 0,65 → 0,9 → 1,0 o świcie, liniowo w fazie. `Events.night_phase_changed(faza)` przy przejściu (i przy wznowieniu nocy).
- **Pierwsze zdarzenie tła** najwcześniej po 45 s nocy (×czynnik nocy); po wznowieniu nocy cisza przez 20 s (zapis/wczytanie nie odpala niczego w pierwszych klatkach).
- **Odstęp minimalny** między dowolnymi dwoma zdarzeniami: 8 s.
- **Bramka „nie w walce” (backlog: zdarzenia niezwiązane z walką):** zdarzenia tła i wejścia tylko gdy strażnik żyje, noc trwa, nie jest w przystani (`Haven.shelters` — także kawiarnia), `PerceptionWorld.hunters_near(strażnik) == 0`, nie trwa walka ze strażnikiem skrzydła ani finał (`FloorGame.blocks_rest()`). Zajęte w chwili terminu → ponowna próba za 3 s.
- **Aktywność wrogów w limitach ekologii:** jedyną drogą jest istniejąca szyna hałasu (`Events.noise_made`, źródło `fall`). Odpowiadają tylko ci, którzy słyszą, najwyżej 3 badających na miejsce i 6 s, bez gwarancji (upadek — rzut decyduje), limit polujących bez zmian. Zdarzenia z hałasem dzieją się **w sąsiedniej sali**, nigdy przy strażniku.

### 2.2 Wyzwalacze

| Wyzwalacz | Kiedy | Kto wybiera |
|---|---|---|
| `ambient` (tło) | termin z krzywej | ważony los wśród pasujących; `weights` = 4 wagi na fazy (0 = nie w tej fazie) — to krzywa decyduje, *jakie* zdarzenia przychodzą |
| `enter` (wejście) | strażnik wchodzi do sali z listy `rooms` / strefy z `zones` | pierwsze pasujące w kolejności tabeli (ręczny priorytet), `delay` s po wejściu, potem bramka |
| `return` (powrót) | strażnik **wychodzi** z sali → rzut (`chance` × skala fazy); udany → zmiana czeka `away` s | nakładana, gdy strażnik jest gdzie indziej i cel nie jest w jego polu widzenia (łuk kamery jak przy poruszeniu we śnie); wrócił przed czasem → przepada |
| `night` (następna noc) | start świeżej nocy (nie wznowionej) | sale odwiedzone wcześniejszych nocy (`rooms_visited` w chwili startu); rzut z generatora nocy (ziarno nocy × 97 + 13) |

### 2.3 Zapis i wznowienie (#51: „nie mogą się ponownie odpalać wydarzenia”)

- `RunState.used` (zapisywane z nocą w toku):
  - `unc_<id>_<n>` — n-te odpalenie zdarzenia z limitem (zdarzenia bez limitu, np. mrugnięcie, nie zapisują się: są chwilą, nie stanem),
  - `chg_<id>@<cel>` — nałożona zmiana świata (cel: indeks kawałka w `layout.pieces`, miejsce obrazu, sala, slot eksponatu); **przy wznowieniu nakładana od razu, po cichu**,
  - `unc_drawn` — zmiany nocy już wylosowane (wznowiona noc ich nie losuje drugi raz).
- `GameState.uncanny_seen` — zdarzenia „raz na grę” (zapisywane, przetrwają śmierć i wyjście).
- Krzywa wynika z zegara (zapisany `clock_<s>`).
- Obrót śpiącego eksponatu nie jest zapisywany (pozycje eksponatów nie są częścią zapisu — tak samo jak poruszenie we śnie).

### 2.4 Uczciwość zmian (#35: „zawsze uczciwie”)

- **Nigdy nie zastawia drogi:** ukrycie kawałka tylko *zwalnia* miejsce (kolizja wyłączona razem z obrazem — żadnych niewidzialnych ścian); obrót tylko o 180° (dowolny prostokąt) albo o wielokrotność 90° przy kwadratowej podstawie (|x − z| ≤ 0,05 m) — **obrys się nie zmienia**, kolizja i navmesh zostają prawdziwe; ciemna sala tylko z lampami awaryjnymi (nigdy czarna dziura) i z prawdziwym `visible=false` — model światła percepcji to widzi, eksponaty też widzą gorzej.
- **Nigdy nie zabiera przedmiotu:** żadnego znacznika (notatki, sekrety, szachy, bronie, bezpieczniki, pieczęcie, mapy, audioprzewodniki, kamery…) ani punktu łupu w obrysie kawałka + 1,0 m; obrazy-portrety tej nocy (wrogowie) nie są celem; nic nie dotyka bram, drzwi, zamków ani postępu.
- **Nigdy w miejscach walki/odpoczynku:** sale przystani, sale z areną strażnika (`arena_*`, `guardian_*`), sala finału (dziedziniec — tylko obrazy na ścianach, żadnych mebli).
- **Drzwi:** zwykłe drzwi piętra I stoją otwarte i nie mają klamki — trwała zmiana „drzwi zamknięte/otwarte” **zatrzasnęłaby gracza**, a bramy to postęp. Zamiast tego zdarzenie chwilowe „drzwi trzaskają same i otwierają się z powrotem” (prawdziwe `Door.close()` → `open()`, z ich skrzypnięciem dla percepcji, tylko gdy strażnik ≥ 4 m od nich). Odstępstwo od przykładu właściciela — zapisane w §7.
- Zmiana nakładana jest tylko poza wzrokiem strażnika; nic nie znika na jego oczach.

## 3. Tabela zdarzeń (`data/night/uncanny.json`)

Kolumny: **wyzwalacz** · **gdzie** · **fazy / wagi** · **zapowiedź (co widzi/słyszy gracz)** · **czas** · **rzadkość** · **głos** (istniejąca kwestia obok / notatka dla G3).
Fazy: 0 CALM, 1 UNEASY, 2 WITCHING, 3 PREDAWN. „limit” = razy na noc.

### 3.1 Zdarzenia tła (krzywa nocy)

| id | gdzie | wagi 0/1/2/3 | zapowiedź | czas | rzadkość | głos |
|---|---|---|---|---|---|---|
| `lamp_blink` | sala strażnika | 4/2/0/0 | jedna lampa gaśnie dwa razy na ułamek sekundy | 0,6 s | bez limitu | — |
| `lamp_stutter` | sala strażnika | 0/4/3/2 | lampy sali dławią się seriami, cichy trzask przekaźnika | 1,8 s | bez limitu | — |
| `lamp_brownout` | sala strażnika | 0/2/3/3 | lampy przygasają do 30 %, drżą i wolno wracają; brzęczenie gaśnie | 6 s | limit 3 | — |
| `lamp_out` | sala strażnika (z lampami awaryjnymi) | 0/0/2/3 | lampy gasną (oprawy ciemne), zostaje czerwień awaryjnych; wracają zająknięciem | 4,5 s | limit 2 | G3: System „Awaria zasilania w sektorze…” (dziś jest tylko `VO_SYSTEM_BLACKOUT` na noc z modyfikatorem) |
| `lamp_sweep` | sala z ≥ 5 lampami | 0/0/2/2 | lampy gasną po kolei od najdalszej ku strażnikowi i zapalają się w tej samej kolejności — „coś przeszło pod nimi” | ~0,35 s/lampę | limit 1, **najlepszy moment** | — |
| `exit_signs` | sala strażnika | 0/0/0/3 | znaki WYJŚCIE migają czerwienią — budynek nie chce wypuścić | 5 s | limit 1 | — |
| `far_grind` | sala sąsiednia | 2/2/1/0 | w sąsiedniej sali coś kamiennego przesuwa się o centymetr (bez hałasu dla eksponatów) | chwila | limit 2 | — |
| `far_thud` | sala sąsiednia | 0/3/3/3 | ciężkie łupnięcie za ścianą; **hałas 16 m** (upadek) → 0–3 eksponaty idą sprawdzić | chwila | limit 3 | — |
| `far_glass` | sala sąsiednia | 0/0/2/2 | brzęk tłuczonego szkła za ścianą; hałas 18 m | chwila | limit 1 | — |
| `door_slam` | drzwi sali strażnika lub sąsiedniej | 0/2/2/2 | otwarte drzwi same się zatrzaskują i po chwili otwierają; skrzypnięcie słyszą eksponaty | ~2 s | limit 2 | — |
| `pa_click` | głośnik w sali (`loudspeaker_*`) | 0/2/2/1 | głośnik klika, szumi przez 2,5 s… i nikt nic nie mówi | 2,5 s | limit 1 | G3: System, zniekształcone „Muzeum… jest… zamknięte” |
| `radio_breath` | radio strażnika | 0/0/1/1 | trzask krótkofalówki i myśl strażnika: ktoś oddycha na kanale | 4 s | limit 1, szansa 0,5 | G3: Heniek „…to nie ja wołałem” |
| `painting_gaze` | zwykły portret w sali, przed którym stoi strażnik (≤ 16 m) | 3/2/1/0 | oczy obrazu idą za strażnikiem, potem wracają na wprost — **zapowiedź Portretów** | 6 s | limit 2 | — |

### 3.2 Zdarzenia wejścia (ręcznie ustawione chwile)

| id | sala / warunek | fazy | zapowiedź | czas | rzadkość | głos |
|---|---|---|---|---|---|---|
| `court_eyes` | dziedziniec, wejście | 0–1 | **pierwsze dziwne zdarzenie gry:** wszystkie zwykłe portrety dziedzińca patrzą na strażnika; myśl „Te oczy… patrzyły przedtem prosto?” | 7 s | **raz na grę** | G3: Heniek „Nie patrz obrazom w oczy, młody.” |
| `clocks_backwards` | sala zegarów, wejście | 1–3 | wszystkie zegary kręcą wskazówkami wstecz, wahadła stają, lampy drżą; zgrzyt mechanizmu — zapowiedź zasadzki `enlightenment_clockwork` i Planetarium; myśl raz na grę | 6 s | limit 1 | obok: `VO_GUIDE_CLOCKS_B` (nocne nagranie przewodnika w tej sali) |
| `court_bones` | dziedziniec, wejście; T-Rex niepokonany, finał przed walką | 2–3 | grzechot kości szkieletu T-Rexa za plecami, lampy przygasają — zapowiedź bossa | 6 s | limit 1 | obok: `VO_GUIDE_TREX_B` (nocne nagranie po 3:00) |
| `predawn_unrest` | każda sala, wejście | 3 | lampy łapią zadyszkę przy każdym wejściu — muzeum opanowane | 1,5 s | bez limitu, szansa 0,4 | — |

### 3.3 Zapowiedzi zasadzek (prawdziwe zagrożenia; warunek: zasadzka czeka, jej śpiący śpią)

| id | wejście do | zasadzka | zapowiedź | rzadkość |
|---|---|---|---|---|
| `fs_sarcophagi` | korytarz grobowców, grobowce, sala sarkofagów | `egypt_sarcophagi` (mumie w sarkofagach / skarabeusze) | wieko jednego sarkofagu **uchylone na palec**, zgrzyt kamienia, pył z krawędzi; w środku szeleści (gdy tej nocy śpią tam same skarabeusze — tylko szelest) | limit 1 |
| `fs_camp` | przedsionek, galeria Egiptu | `egypt_camp` (mumie przy strzelbie) | jęk mumii, wieko trumny przy strzelbie uchylone | limit 1 |
| `fs_reliefs` | Brama Asyrii | `assyria_gate_reliefs` | trzask kamienia i obłok pyłu spod płaskorzeźby, z której wyjdzie wojownik | limit 1 |
| `fs_lion_hunt` | galeria nad dołem lwów, dół lwów | `assyria_lion_hunt` | pomruk z dołu, pył spod płyty z lwem | limit 1 |
| `fs_lapiths` | wazy, metopy | `greece_lapiths` (hoplici) | brzęk tarczy z sali metop | limit 1 |
| `fs_reading` | biblioteka Oświecenia | `enlightenment_reading` (księgi) | trzepot kartek z półek, lampa mruga | limit 1 |
| `fs_armor_guard` | porcelana, zbrojownia | `asia_armor_guard` (zbroje samurajów) | zimny **błysk w hełmie** jednej zbroi i dźwięk ostrza | limit 1 |
| `fs_north_gate` | hol północny | `north_hall_gate` (wilki) | warknięcie z głębi holu | limit 1 |

### 3.4 Zapowiedzi strażników skrzydeł (warunek: niepokonany, jeszcze nie walczy; pierwsze wejście do skrzydła tej nocy)

| id | skrzydło | zapowiedź (z kierunku areny, z daleka) |
|---|---|---|
| `fs_guardian_colossus` | Egipt | zgrzyt kamiennego kolosa |
| `fs_guardian_lamassu` | Asyria | ciężki tupot skrzydlatego byka |
| `fs_guardian_centaur` | Grecja | galop kopyt po marmurze |
| `fs_guardian_planetarium` | Oświecenie | szum trybów orrery |
| `fs_guardian_general` | Azja | szczęk dobywanego miecza |
| `fs_guardian_serpent` | Ameryki | syk węża |

Głos: każde przebudzenie ma już kwestię Systemu (`VO_SYSTEM_WAKE_*`) — zapowiedź ją poprzedza.

### 3.5 Świat zmieniony przy powrocie (`return`, nakładane pod nieobecność, trwałe do końca nocy)

| id | sale | fazy | zmiana | czekanie | szansa |
|---|---|---|---|---|---|
| `gone_statue` | galeria Egiptu, przedsionek Egiptu, gabinet osobliwości, porcelana | 1–3 | **na cokole pusto** — rzeźba zniknęła (kolizja z nią) | 60 s | 0,6 |
| `bust_turned` | hol północny, Nereidy, wazy, galeria portretów | 0–3 | popiersie **odwrócone twarzą do ściany** (180°) | 45 s | 0,6 |
| `bench_turned` | hol wejściowy, hol północny, galeria portretów, Nereidy | 1–3 | ławka odwrócona tyłem (180°, ten sam obrys) | 45 s | 0,5 |
| `sitter_gone` | dziedziniec, hol północny, galeria portretów | 1–3 | **z portretu zniknęła postać** — w ramie pejzaż (w greyboxie: inna twarz) | 60 s | 0,5 |
| `painting_looks_away` | dziedziniec, hol północny, galeria portretów | 0–3 | **obraz patrzy w inną stronę** (oczy w bok, na drzwi) | 45 s | 0,6 |
| `sleeper_turned` | każda sala ze śpiącą figurą woskową / popiersiem | 0–3 | śpiąca figura stoi **zwrócona do drzwi**, którymi strażnik wyszedł — „manekin obrócił głowę”; prawdziwe zagrożenie | 30 s | 0,5, limit 3 |
| `room_dark` | sale z lampami awaryjnymi (nie przystanie, nie areny) | 2–3 | sala stoi **ciemna** — główne lampy zgaszone naprawdę (eksponaty też widzą gorzej); latarka | 60 s | 0,35, limit 1 |

### 3.6 Świat zmieniony na następną noc (`night`, sale odwiedzone wcześniej)

| id | sala | od nocy | zmiana | szansa |
|---|---|---|---|---|
| `night_statue_gone` | galeria Egiptu | 2 | rzeźba zniknęła z cokołu od zmierzchu | 0,35 |
| `night_sitter_gone` | galeria portretów | 3 | jeden z portretów pusty | 0,4 |
| `night_benches` | hol wejściowy | 2 | ławki odwrócone | 0,3 |

Razem **41 wpisów**: 13 tła + 4 wejścia (ręczne chwile) + 8 zapowiedzi zasadzek + 6 zapowiedzi strażników + 7 zmian przy powrocie + 3 zmiany nocne (kilka rzadkich: raz na grę, szansa 0,3–0,5). Kolejność w pliku = priorytet zdarzeń wejścia (zapowiedzi przed „zadyszką” świtu).

## 4. Pliki

| Plik | Co |
|---|---|
| `src/game/night_escalation.gd` (nowy) | `NightEscalation`: fazy, natężenie, odstępy, skale |
| `data/night/uncanny.json` (nowy) | tabela zdarzeń |
| `src/game/floor1/uncanny/uncanny_catalog.gd` (nowy) | `UncannyCatalog`: wczytanie, walidacja pól, dostęp |
| `src/game/floor1/uncanny/uncanny_rules.gd` (nowy) | `UncannyRules`: dopasowanie, los, uczciwość celów (czyste) |
| `src/game/floor1/uncanny/room_lamps.gd` (nowy) | `RoomLamps`: efekty lamp sali |
| `src/game/floor1/uncanny/painting_gaze.gd` (nowy) | `PaintingGaze`: wzrok obrazu |
| `src/game/floor1/uncanny/uncanny_effects.gd` (nowy) | `UncannyEffects`: kawałki, obrazy, eksponaty, grobowce, zegary, drzwi, dźwięki |
| `src/game/floor1/uncanny/uncanny_director.gd` (nowy) | `UncannyDirector`: harmonogram, wyzwalacze, zapis |
| `src/core/events.gd` | +`night_phase_changed(phase)`, +`uncanny_event(id, room)` |
| `src/state/game_state.gd` | +`uncanny_seen` |
| `src/game/floor1/floor_game.gd` | +`uncanny` (instalacja po `RoomTracker`) |
| `src/audio/voice/voice_catalog.gd`, `voice_director.gd` | zdarzenie `uncanny` (`kind` = id zdarzenia, `room`) — G3 dopisze tylko dane |
| `locale/strings.csv` | +`UNCANNY_*` (myśli strażnika, PL/EN) |
| `export_presets.cfg` | +`data/night/*.json` w eksporcie |
| testy | `tests/unit/test_night_escalation.gd`, `test_uncanny_catalog.gd`, `test_uncanny_rules.gd`, `tests/integration/test_room_lamps.gd`, `test_uncanny_effects.gd`, `test_uncanny_floor1.gd` |

## 5. Zadania (TDD, jeden commit na zadanie)

- [x] **Zadanie 0:** inwentarz (skrypt headless po układzie piętra I: sale, lampy, znaczniki, drzwi, zasadzki, kawałki), ten plan. Commit `Plan: night escalation, uncanny events and a museum that changes`.
- [x] **Zadanie 1:** `NightEscalation` + `Events.night_phase_changed` — testy: granice faz (0, 359, 360, 720, 1080, 1259 s), natężenie rośnie monotonicznie 0,1 → 1,0, odstępy maleją z fazą, noc 1 rzadziej, noc ≥ 4 gęściej, calm rzadziej, skale zmian i hałasu. Commit `Night escalation curve: four phases from the clock`.
- [x] **Zadanie 2:** `GameState.uncanny_seen` (reset, zapis, odczyt, śmieci odrzucone) + `Events.uncanny_event` — testy zapisu. Commit `Save keeps the uncanny moments seen once per game`.
- [x] **Zadanie 3:** `RoomLamps` — testy na sztucznym korzeniu świateł: każdy tryb wraca dokładnie do energii bazowej; oprawy gasną/zapalają się przy `out`/`sweep`; lampy zgaszone (`visible=false`) nietknięte i nadal zgaszone; lampy `flicker` pominięte; `visible` nigdy nie zmienione; jedna sala = jeden efekt naraz; `sweep` w kolejności od najdalszej. Commit `Room lamps: blink, stutter, brownout, outage, sweep and exit signs`.
- [x] **Zadanie 4:** `PaintingGaze` + `UncannyEffects` (kawałki, obrazy, eksponaty, grobowce, zegary, drzwi, dźwięki) — testy: ukrycie wyłącza kolizję, obrót 180° zachowuje obrys, podmiana obrazu w tym samym miejscu, wzrok (greybox: źrenice; model: kopia materiału — współdzielony nietknięty), śpiący zwraca się do drzwi i dalej śpi, wieko uchylone o kilka cm i `open()` nadal działa, zegary wstecz i z powrotem, drzwi zamykają się i otwierają, hałas trafia do `Events.noise_made`. Commit `Uncanny effects: pieces, paintings, sleepers, tombs, clocks, doors and sounds`.
- [x] **Zadanie 5:** `UncannyCatalog` + `UncannyRules` + `data/night/uncanny.json` — testy danych na prawdziwym układzie piętra I: unikalne id, znane wyzwalacze/efekty/pola, sale/strefy/znaczniki/zasadzki/strażnicy istnieją, dźwięki w `Sfx.SOUNDS`, teksty w `strings.csv` (PL i EN), **każda zmiana ma ≥ 1 uczciwy cel**, żaden cel nie ma znacznika ani łupu w obrysie +1 m, żaden w arenie/przystani; liczności (≥ 20 zdarzeń, ≥ 6 zapowiedzi zasadzek, 6 strażników, ≥ 5 zmian przy powrocie, ≥ 1 raz na grę, ≥ 3 rzadkie); reguły: fazy, noc, modyfikator, limity, los ważony deterministyczny. Commit `Uncanny event table and rules: hand-designed events, fair targets`.
- [x] **Zadanie 6:** `UncannyDirector` — tło i wejścia; instalacja w `FloorGame` — testy na prawdziwym piętrze I (greybox): faza z zegara i sygnał, zdarzenie tła przychodzi w spokoju, **nic** w przystani / przy polującym / w walce, odstępy wg krzywej, wejście do sali zegarów odpala `clocks_backwards` raz, `court_eyes` raz na grę (druga noc nie), wznowiona noc nie powtarza zdarzeń z limitem. Commit `Uncanny director: the night's curve and the rooms' moments`.
- [x] **Zadanie 7:** zmiany świata — `return` i `night`, zapis i wznowienie — testy: wyjście z sali → zmiana nałożona pod nieobecność, nie przy strażniku; powrót przed czasem → przepada; wznowiona noc pokazuje te same zmiany (kawałki ukryte/obrócone, obrazy); zmiany nocne deterministyczne z ziarna i nie losowane drugi raz; świat po zmianach przechodzi testy QA. Commit `The museum changes behind the guard's back: fair room changes kept with the night`.
- [x] **Zadanie 8:** zapowiedzi zasadzek i strażników — testy: zapowiedź przed zasadzką (wieko, pył, błysk, dźwięk), nie po jej odpaleniu, nie dla pokonanego strażnika, raz na noc. Commit `Foreshadowing: ambushes and wing guardians give themselves away`.
- [x] **Zadanie 9:** głos (zdarzenie `uncanny` dla G3), eksport danych, `git merge pietro-1`, pełny zestaw, lista „Do sprawdzenia w oknie”, stan prac. Commit `Uncanny events reach the voice director; plan state`.

## 6. Do sprawdzenia w oknie (gdy okna będą dozwolone)

Wszystko poniżej jest sprawdzone testami tylko logicznie (headless, greybox); wygląd i dźwięk — do obejrzenia.

1. **Lampy** w salach z oprawą (galeria Egiptu, biblioteka Oświecenia, galeria portretów, hol północny): mrugnięcie, migotanie, przygaszenie (czy 30 % nie jest za ciemno/za jasno), zgaśnięcie (oprawy gasną razem z lampą? czerwień awaryjnych wystarcza do orientacji?), „przejście” (czy czyta się jako coś idącego pod lampami — tempo 0,35 s/lampę), znaki WYJŚCIE.
2. **Oczy obrazów** (model): przesuw tęczówek przy `painting_gaze` i `court_eyes` — czy widać z 5–10 m; „obraz patrzy w inną stronę” — czy czytelne, a nie jak błąd.
3. **Postać zniknęła z portretu:** pejzaż / martwa natura w ramie portretu — czy rama i płótno pasują (proporcje płócien scen).
4. **Pusty cokół** (galeria Egiptu, gabinet osobliwości, porcelana): czy czyta się jako „zniknęło”, nie jak brakujący asset; czy obok nie wisi tabliczka/oświetlenie celujące w pustkę w dziwny sposób (to akurat pożądane).
5. **Popiersie / ławka odwrócone o 180°** — czy widać zmianę przy powrocie.
6. **Zegary wstecz** (sala zegarów): ×90 prędkości wskazówek i stojące wahadła — czy widać i czy to nie wygląda jak zawieszenie gry.
7. **Wieko uchylone** (sarkofag 7 cm, trumna 3,4°): czy szczelinę widać z wejścia do sali; pył.
8. **Błysk hełmu** zbroi samuraja (zbrojownia) i pył spod płaskorzeźby (Brama Asyrii, dół lwów).
9. **Trzask drzwi** — tempo (0,7 s zamknięcia + 0,6 s + otwarcie), czy skrzydło nie wypycha strażnika.
10. **Myśli strażnika** (podpowiedź HUD): czy pasek podpowiedzi to dobre miejsce, czy nie zasłania; czy trzy myśli na grę to nie za mało/za dużo.
11. **Dźwięki** (gdy dźwięk będzie dozwolony): głośności zapowiedzi strażników (−12 dB z kierunku areny, ≤ 30 m), łupnięcie/szkło za ścianą, kliknięcie głośnika, jęk mumii; czy istniejące efekty pasują do roli (np. `samurai_slash` jako „dobywanie miecza”).
12. **Tempo całej nocy** (bot w oknie, pełna noc): ile zdarzeń przypada na fazę (oczekiwane ~2–3 / ~4 / ~6 / ~5 przy nocy 2), czy początek jest naprawdę spokojny, a przedświt „opanowany”, czy nic nie przeszkadza w walce.
13. **Ciemna sala** (`room_dark`) — czy latarka i lampy awaryjne wystarczają; czy eksponaty w ciemności nie robią się niesprawiedliwe.
14. **Migotanie lamp po spowolnieniu** (`lamp_stutter`, `clocks_backwards`, `predawn_unrest`; zrzuty co najmniej 0,25 s od siebie): czy nadal czyta się jako „zadyszka sieci”, a nie równy puls; czy suma niezależnych lamp dużej sali nie miga zbyt szybko. `room_dark` ma teraz 23 sale do wyboru (hol północny, Egipt, Asyria, Grecja, Oświecenie, Azja, korytarze piwnicy): czy to dość urozmaicenia.
- **Przegląd w oknie 23.10** (`2026-10-22-przeglad-w-oknie.md` §2): pkt 1 — tryby lamp OK w 4 salach, „zgaśnięcie” w galerii portretów prawie czarne; pkt 2 — wzrok portretu czytelny z ~2 m, z 6 m nie.

## 7. Doprecyzowania i odstępstwa

1. **Drzwi „otwarte/zamknięte” jako trwała zmiana — nie na piętrze I.** Zwykłe drzwi stoją otwarte i nie mają klamki (zamknięte = gracz zatrzaśnięty), bramy to postęp (otwarcie = ominięcie zamka), nocnych drzwi zamykanych piętro nie ma. Zamiast tego chwilowy trzask drzwi (`door_slam`). Gdy pojawią się drzwi z klamką (np. w przyszłych piętrach), dojdzie efekt `door_ajar`.
2. **Bez nowych nagrań i dźwięków.** Zdarzenia używają istniejących `Sfx` (przekaźnik, zgrzyty, kroki strażników…); kwestie głosu tylko jako łącze z istniejącą lub notatka dla G3. Myśli strażnika — rzadkie, tekstem (podpowiedź HUD), jak chce lista rozszerzona („rzadkie, krótkie reakcje tekstem”).
3. **Światło: tylko energia lamp + blask opraw**, nigdy `visible` (poza trwałą zmianą `room_dark`). Chwilowe zgaśnięcie nie zmienia więc modelu światła eksponatów — świadomie: zdarzenia dzieją się poza walką i trwają sekundy; trwała ciemna sala jest prawdziwa dla wszystkich.
4. **Zadania 6–8 w kodzie razem:** harmonogram zmian świata (`return`, `night`) i zapowiedzi siedzą w jednym `UncannyDirector` — powstał w zadaniu 6 w całości; commity zadań 7 i 8 to ich testy na prawdziwym piętrze (zmiany pod nieobecność, wznowienie, ziarno; zapowiedzi przed zasadzką, nie po niej, strażnik pokonany milczy).
5. **Trzask drzwi tylko za plecami:** reżyser wybiera drzwi poza polem widzenia strażnika (≥ 4 m) — słyszy trzask, odwraca się, skrzydło już się otwiera; nigdy drzwi, do których idzie (żadnego zderzenia z zamykającym się skrzydłem, bezpieczne dla botów QA).
6. **Punkt sali** omija sale wewnątrz innej (czytelnia w środku Dziedzińca): środek części sali, który `room_at` przypisuje tej sali.
7. **Zapowiedź sarkofagów bez mumii:** tej samej nocy zasadzka `egypt_sarcophagi` bywa samymi skarabeuszami (wylosowane zestawy) — wtedy zostaje szelest bez wieka; z mumią w sarkofagu: wieko + pył + zgrzyt + szelest.

## 8. Stan prac / co dalej

- 21.10: zadania 0–9 zrobione. Commity: `7733596` plan, `1286eb7` krzywa + sygnały, `f920aae` `uncanny_seen`, `8b66325` lampy sal, `2f21875` efekty, `2fe8bff` tabela + reguły (41 zdarzeń), `d77fb5f` reżyser + instalacja w `FloorGame`, `fa4d6b4` testy zmian świata, `defe2e0` testy zapowiedzi, `d504fbf` głos (zdarzenia `night_phase_changed`, `uncanny_event` dla G3).
- Poprawki po pierwszym pełnym przebiegu: `24f68bf` oprawa idzie ze swoją lampą (meta `light` poziomu), znaki WYJŚCIE migają też blaskiem; `a4c1baf` chwila sali (oczy obrazów, zegary, lampy) tylko, gdy strażnik nadal w niej stoi.
- Linia bazowa przed pracą: pełny zestaw 2695/0 (32 min 43 s przy kilku równoległych przebiegach innych agentów). Pierwszy pełny przebieg gałęzi: 2758/2 (dwa testy dopisane w trakcie przebiegu do poprawek powyżej — przebieg miał już wczytaną starszą wersję skryptów; po poprawkach zielone).
- `git merge pietro-1` (@76bac48: przypisywanie klawiszy, nakładka F3, profil CPU) — bez konfliktów; reżyser siedzi pod `FloorGame`, więc nakładka liczy go w sekcji `floor_game`.
- **Pełny zestaw po scaleniu: 2852 zaliczone, 0 niezaliczonych** (39 min 36 s; w tym QA: kolizje, softlocki, zapis świata, osiągalność, determinizm reżysera nocy).
- **Co dalej (poza tą gałęzią):**
  1. **G3 (głos):** kwestie z kolumny „g3” tabeli — reguła `{"event": "uncanny_event", "kind": "<id zdarzenia>"}` albo `{"event": "night_phase_changed", "kind": "predawn"}`; test `test_every_rule_names_something_that_exists` trzeba wtedy rozszerzyć o te rodzaje (`kinds` dla obu zdarzeń).
  2. **Mechaniki biomów** (gałąź `biome-mechanics`): `BiomeMechanics.intensity` (0..1) — po scaleniu obu gałęzi jedna linia w `FloorGame` / reżyserze: `biomes.intensity = NightEscalation.intensity(museum.watch.clock.elapsed)` (uzgodnione z agentem biome-mechanics).
  3. **Muzyka/ambient:** `Events.night_phase_changed` i `NightEscalation.intensity()` są gotowe dla warstw muzyki i ambientu (np. skrzypienie budynku gęstsze przed świtem) — nie podłączone w tej gałęzi.
  4. **Strojenie po teście okienkowym** (sekcja 6): wagi faz, odstępy, szanse zmian.

## 9. Poprawki po przeglądzie (21.10, gałąź `night-escalation`)

Przegląd znalazł sześć rzeczy; każda ma test, który przed poprawką świecił na czerwono.

1. **Stała ciemna sala (`room_dark`) nie może trafić w pułapkę ani w cel nocy.** `UncannyRules.dark_rooms` odrzuca teraz: sale ze schodami (`stair_rooms`: oba końce biegu, w tym wieże `*_service_stairs`, `*_freight_stairs`, `booth_stairs`, `roof_stairs`), sale z upadkiem (`drop_rooms`: przejście między podłogami oddalonymi o > 0,5 m, do którego nie dochodzi żaden bieg schodów dolnej sali — dziś tylko dół z `americas_pit`, obie strony), sale celów nocy (nowe `Floor1Layout.objective_rooms`: każdy pickup postępu, strażnicy, piedestał T-Rexa — rozdzielnia, bezpieczniki, astrolabium, bronie; ta sama lista co `describe().objective_rooms` NightDirectora), sale areny i sale leżące w całości wewnątrz areny albo przystani (`inside_rooms`: czytelnia w Dziedzińcu T-Rexa) oraz **wszystkie sale skrzydła Ameryk** (`BIOME_LIT_ZONES`: ogniska staną się mechaniką biomu i sterują światłem i wzrokiem totemów). Zostaje 23 z 114 sal (było 50): hol północny, wejście do Egiptu i Asyrii, kilka sal Grecji, Oświecenia i Azji, korytarze piwnicy. Testy: `test_a_room_left_dark_is_never_one_to_fall_climb_or_finish_the_night_in` (prawdziwe piętro I: nazwane sale + reguły strukturalne) i `test_a_room_with_stairs_a_drop_or_an_arena_inside_it_stays_lit` (mały układ: schody, upadek po obu stronach, sala w arenie; sala obok *schodów w dół* zostaje dozwolona).
2. **Zmiana świata (`_run_pending`) czeka na spokojną chwilę.** Nie nakłada się, gdy eksponat poluje na strażnika w pobliżu albo trwa walka (`floor_game.blocks_rest()`); czeka do `CHANGE_PATIENCE` jak przy spojrzeniu strażnika. Wspólny `_fight_on` dla `is_quiet()` i zmian. Test: `test_a_change_waits_for_a_calm_moment` (prawdziwy łowca, potem T-Rex w stanie walki).
3. **Lampy nie grają w arenie i nie przechodzą w walkę.** Efekt `lamps` (tło i wejście, np. `lamp_*`, `exit_signs`, `predawn_unrest`) nie wybiera sal przystani ani areny (`_no_lamp_rooms` = `excluded_rooms`); `court_bones` zostaje (to zapowiedź T-Rexa w Dziedzińcu, jego lampy dopiero jako dodatek), ale `Events.guardian_awakened` i `Events.boss_awakened` wołają `lamps.stop_all()` — żaden efekt nie przechodzi w walkę. Testy: `test_the_lamps_do_not_play_in_a_room_to_fight_in`, `test_a_waking_guardian_or_boss_puts_every_lamp_back`.
4. **Trzask drzwi tylko w następnej sali.** `_door_to_slam` wybiera drzwi pomiędzy dwiema salami, z których żadna nie jest salą strażnika (dotąd także jej własne drzwi ≥ 4 m od niego). Test przechodzi po wszystkich 114 salach piętra I: `test_a_door_slams_in_the_next_room_never_in_the_guards_own`.
5. **Dostępność: migotanie.** `RoomLamps.STEADY` z (0,05; 0,35) na (0,22; 0,4) s: najkrótszy zrzut (0,03 s) i najkrótszy odpoczynek dają razem 0,25 s, czyli lampa nie zrzuca światła częściej niż 4 razy na sekundę (było do ~12). Test `test_a_flicker_never_flashes_faster_than_four_times_a_second` liczy odstępy między zrzutami dla 8 × 6 lamp × 20 s. Uwaga: limit dotyczy jednej lampy; lampy sali migoczą niezależnie, więc suma świateł sali zmienia się częściej, ale każda zmiana to ułamek światła sali — do oceny w oknie (sekcja 6, pkt 14).
6. **Śpiący obrócony raz na salę także po wznowieniu.** `_sleeper_rooms` zniknęło; zamiast niego wpis `chg_sleeper_turned@<sala>` w `RunState.used` (zapisywany z nocą, jak zmiana `dark`). Obrót samej figury nadal nie jest odtwarzany (eksponaty stawiane od nowa). Test: `test_a_room_whose_sleeper_turned_is_not_turned_again_after_the_night_is_resumed`.

Do sprawdzenia w oknie: sekcja 6, pkt 14.

Stan po poprawkach (21.10): commity `2f4c6a99` (ciemne sale), `bc31f863` (migotanie), `a1ce1dd3` (reżyser: walka, areny, drzwi, śpiący). **Pełny zestaw na `76bac48` + poprawki: 2860 zaliczone, 0 niezaliczonych** (40 min 58 s, jeden proces). Potem `git merge pietro-1` (@0b0552a: test-speed) bez konfliktów; testy `test_uncanny*` i `test_room_lamps` po scaleniu zielone (64/0). Gałąź `env-combat` jeszcze nie w `pietro-1`: jej haki (`rebind`, `set_present`, `recapture`) czekają na scalenie, patrz sekcja 10.

## 10. Zgranie ze środowiskiem (`env-combat`, 21.10)

`env-combat` (reaktywne muzeum: gabloty, lampy, popiersia, posągi, obrazy) przyszło do `pietro-1` przed tą gałęzią i daje efektom nocy trzy haki w `EnvLayer`. `UncannyEffects` woła je teraz same (pomocnik `_env(węzeł)` = `EnvLayer.of(drzewo)`, null poza drzewem):

- `swap_painting` -> `env.rebind(stary, nowy)` przed zwolnieniem starego: rekwizyt obrazu idzie za nowym płótnem (pochylanie, zsuwanie, upadek działają na nowym obrazie),
- `hide_piece` -> `env.set_present(kawałek, false)`: strefy trafień ukrytego posągu znikają razem z nim (niewidzialny posąg nie przyjmuje strzałów ani się nie chwieje); w nocy nie ma odwrotu (ukryte do rana), więc `set_present(…, true)` nie jest potrzebne,
- `turn_piece` -> `env.recapture(kawałek)`: obrócone popiersie / posąg przyjmuje nową pozę jako pozę spoczynku (po trafieniu kołysze się i wraca do obróconej, nie do pierwotnej).

Wybrałem haki zamiast pomijania `env.claims(kawałek)` w `fair_pieces`: `fair_pieces` pracuje na układzie (PieceSpec, bez drzewa) i jest używane przy losowaniu nocy, a pomijanie zubożyłoby zmiany (większość posągów i popiersi to rekwizyty środowiska). Testy: `tests/integration/test_uncanny_env.gd` — trzy na hali próbnej (`EnvTestbed`: zamieniony obraz zostaje reaktywny i spada ze ściany; ukryty posąg nie ma żywych stref; obrócone popiersie po trafieniu spoczywa obrócone) i jeden na prawdziwym piętrze I (posąg `gone_statue` z rekwizytem środowiska traci strefy, portret `sitter_gone` oddaje rekwizyt nowemu płótnu).

## 11. Stan prac / co dalej (zatrzymane 21.10 na prośbę właściciela)

- **Zrobione i zielone:** sześć poprawek po przeglądzie (sekcja 9; commity `2f4c6a99`, `bc31f863`, `a1ce1dd3`) — pełny zestaw na `76bac48` + poprawki: 2860/0. Po scaleniu `pietro-1` (test-speed) testy `test_uncanny*`, `test_room_lamps`: 64/0.
- **Zrobione, sprawdzone tylko częściowo:** zgranie ze środowiskiem (sekcja 10; commit `e662c37e`, dane `EnvLayer` z `env-combat`, które jest już w `pietro-1`; scalone `pietro-1` w `919a4355`). `test_uncanny_env` + `test_uncanny_effects`: 15/0 (próba na gałęzi roboczej z `env-combat`, potem cherry-pick). **Pełny zestaw na scalonym drzewie NIE został dokończony** (przebieg przerwany na prośbę właściciela, bez wyniku).
- **Znane czerwone testy:** brak znanych; nieznane — całość poza `test_uncanny*`, `test_room_lamps`, `test_uncanny_env`, `test_uncanny_effects` na scalonym drzewie nie była uruchamiana.
- **Dokładny następny krok:** `git merge pietro-1` (jeśli się ruszyło), potem jeden pełny przebieg w jednym procesie: `bash tools/run_tests.sh` (ok. 41 min). Jeśli zielone — gałąź `night-escalation` gotowa do scalenia w `pietro-1`. Podejrzane miejsca, gdyby coś świeciło na czerwono: współdziałanie `EnvLayer` z `RoomLamps` (lampy wiszące `EnvLamp` a efekty lamp sali) i z `room_dark`.

