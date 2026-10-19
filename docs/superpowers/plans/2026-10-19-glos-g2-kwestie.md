# Głos — etap G2: wszystkie kwestie (Heniek, System, audioprzewodnik)

> Plan wykonawczy. Wykonawca: jeden agent w worktree `guard-general` (gałąź `voice-g2` od `pietro-1` @2dacf29), 19 października 2026.
> Projekt: `docs/superpowers/specs/2026-10-08-glos-projekt.md` (§2 postacie, §3 kto kiedy mówi, §4 w grze, §5 generowanie, §8 ryzyka). Szkielet: `docs/superpowers/plans/2026-10-08-glos-g1-szkielet.md` (as-built + „Uwagi dla G2”). Ton: `docs/fabula-pietro1.md` §1 i §5 (notatki skrzydeł).
> **Wybór właściciela (8.10):** Heniek = `am_michael` (radio robi szyna `VoiceRadio`), System = `af_nicole` ze **stopniem 2 na co dzień** — nagranie ASMR z zacięciami, niesamowitość zamierzona. **Brzmienia `system_fx.py` nie ruszam.**
> Tryb nocny (19.10): okna tylko przez blokadę `with_window.sh`, **dźwięk wyciszony** — nikt niczego nie odsłuchuje; nagrania oceniam liczbami (długość, głośność, szczyt). Odsłuch należy do właściciela (§5).

**Cel:** gra mówi przez całą noc: Heniek (ciepły, krótko, z humorem, ok. 70 kwestii, każda raz na grę, nigdy nie przerywa walki), System — Wirtualny Kustosz (zimny, uprzejmie złośliwy, biurokratyczny, ok. 45 komunikatów) i audioprzewodnik (12 stanowisk × wersja dzienna A i nocna B). Wszystko po angielsku z napisami PL/EN, nagrane Kokoro, z regułami w danych.

**Architektura:** bez zmian względem G1 — teksty w `locale/strings.csv`, reguły w `data/voice/lines.json`, nagrania `assets/voice/<mówiący>/<klucz>.ogg` + `manifest.json` ze skrótami. Dochodzą małe, addytywne zdarzenia `Events` (sekret, zmęczenie, pełna godzina zegara), nowe pola reguł (`room`, `gate`, `modifier`, `hour`), pseudo-zdarzenie reżysera `idle` (bezruch) i obsługa świtu (kwestia świtu wchodzi od razu). Rekwizyty: głośnik przy wejściu do każdego skrzydła + Dziedziniec ×4, 11 nowych stojaków przewodnika z numerem stanowiska na tabliczce.

---

## 1. Zdarzenia, z których korzystają kwestie (stan gry 19.10)

| Zdarzenie | Skąd | Pola reguły | Kto mówi |
|---|---|---|---|
| `night_started` | `Museum._announce_night` | `night`, `night_min`, **`modifier`** (nowe: `none`/`blackout`/`full_moon`/`calm`) | Heniek (EVENT), System (`delay` 50) |
| `witching_hour` | `NightWatch` 3:00 | `night`, `night_min` | System (EVENT), Heniek (`delay` 3) |
| `dawn_broke` | `Museum._on_dawn` | `night`, `night_min` | jedna krótka kwestia (≤ 7 s, §2.3) |
| **`hour_struck(hour)`** (nowe) | `NightWatch`: zegar przeszedł pełną godzinę (0 = północ … 5) | **`hour`** | System (godziny 0, 1, 2, 4, 5; 3:00 i 6:00 mają własne zdarzenia) |
| `room_entered` (tylko pierwsza wizyta) | `RoomTracker` | `zone`, **`room`** (nowe), `kind` = `haven` dla sal przystani (`Floor1Plan.HAVENS`) | Heniek |
| `guardian_awakened` / `guardian_defeated` | `Guardian` | `guardian` | System przy przebudzeniu (EVENT, komunikat z głośników), Heniek po walce |
| `boss_awakened` / `boss_defeated` | `TRex` | — | System; Heniek po walce |
| `shard_collected` | `ProgressPickup` | `count` | Heniek przy 1., 3., 5., 6. |
| `seal_collected` | `ProgressPickup` | — | System (pierwsza pieczęć) |
| `gate_opened` | `GateController` | **`gate`** (nowe) | System (Brama Chorsabadu, prąd, Czytelnia, korytarz północny, ogród), Heniek (prąd, czółno) |
| **`secret_found(secret, tier, found)`** (nowe) | `WorldFeatures.discover_secret` | `kind` = `small`/`medium`/`great` (próg nagrody), `count` = ile sekretów znaleziono | Heniek (1., średni, 10.), System (skarb muzeum, schowek, 20.) |
| `cafe_entered`, `coffee_drunk(kind)`, `cafe_haywire` | `CafeCorner` | `kind` (kawa) | Heniek (wejście, espresso, duża, po fakcie), System (ekspres wariuje — EVENT, specjał) |
| **`fatigue_rose(stage)`** (nowe) | `Player` po `Fatigue.tick` (poziom 0,35 = stopień 1, 0,6 = stopień 2) | `count` = stopień | Heniek (1), System (2) |
| `death` (pseudo) | reżyser, początek następnej nocy | `night_min` | na zmianę Heniek/System, najwyżej raz na noc |
| `destroyed` (pseudo) | reżyser, licznik ze wszystkich nocy | `count` | System: 10, 50, 100, 200, 400 |
| `stall` (pseudo) | reżyser: 6 min bez postępu, najwyżej co 10 min | `goal` | Heniek: podpowiedź do bieżącego celu (17 celów + ogólna) |
| **`idle`** (pseudo, nowe) | reżyser: kamera nie ruszyła się o 1 m przez 120 s, raz na noc | — | System |

**Nie wykorzystane:** `power_cut` (tylko poziom testowy lobby — na Piętrze I prąd przywraca rozdzielnia, czyli `gate_opened` żaluzji), `night_time` (zostaje w narzędziu; godziny idą teraz po prawdziwym zegarze nocy, który stoi w przystaniach). **Ekologia wrogów** (gałąź `enemy-ecology`, jeszcze nie w `pietro-1`) nie wystawia sygnałów `Events` — nie ma czego podpiąć; do dopisania, gdy pojawi się zdarzenie (np. „stado się zbiera”).

## 2. Decyzje

### 2.1 Kto kiedy mówi (priorytety, opóźnienia)
- **Heniek nie przerywa walki:** wszystkie jego kwestie poza początkiem nocy i świtem mają priorytet 1 (zwykła) albo 0 (poboczna) — czekają na spokój (4 s bez polowania i trafień) bez limitu czasu. Wskazówki do strażników mówi **przy pierwszym wejściu do skrzydła** (jak notatki), nie przy przebudzeniu; po walce komentuje upadek (`delay` 3).
- **System może wejść w walkę:** komunikaty z głośników przy przebudzeniu strażnika i T-Reksa, godzina duchów, ekspres wariuje — priorytet 2 (czeka na spokój najwyżej 10 s). To jego charakter: komunikat z sufitu, który nie pyta.
- **Początek nocy:** Heniek (EVENT) od razu → komentarz po śmierci (poboczny, `delay` 3, gra w luce po Heńku) → modyfikator nocy (`delay` 40) → System (`delay` 50). Bez śmierci i modyfikatora: Heniek, potem System.
- **Kawiarnia:** pierwsze wejście za ladę po 3:00 wywołuje oba zdarzenia naraz — `cafe_haywire` Systemu (priorytet 2) idzie pierwsze, komentarz Heńka do kawiarni (`delay` 2) po 20 s ciszy; jego uwaga o zwariowanym ekspresie jest poboczna.
- **Po strażniku:** Heniek „leży” (`delay` 3) → System o pieczęci (pierwszej) → Heniek o odłamku (1., 3., 5., 6.). Między kwestiami zawsze 20 s ciszy.
- **Zastój:** reguły z celem stoją w pliku przed ogólną, więc gra pierwsza pasująca; ogólna czeka, przepada po 60 s i wraca przy następnym zastoju.

### 2.2 Eskalacja Systemu ponad stopień 2
Stopień 2 jest codzienny (wybór właściciela), więc eskalację z projektu (§2.2: noc → godzina duchów → awaria) niesie **tekst i tempo**, nie nowy stopień obróbki: komunikat awaryjny (`BLACKOUT`) i późna godzina duchów (`WITCHING_3`) mają tempo 0,88 zamiast 0,95; treść coraz bardziej „wie więcej, niż powinna” (`NIGHT_4`, `DEATH_3`, nocne wersje przewodnika). Stopień 3 w `system_fx.py` zostaje propozycją do odsłuchu właściciela (nie robię go bez ucha).

### 2.3 Świt
Po `dawn_broke` gra pokazuje kartę świtu i po ok. 8 s ładuje następną noc, a `night_started` ucisza głos. Kwestia świtu musi więc wejść **od razu** i trwać **≤ 7 s**: reżyser przy świcie ucisza bieżącą kwestię, czyści kolejkę i traktuje świat jako spokojny (eksponaty i tak zamarły), więc kwestia startuje w następnej klatce. Kwestie świtu są krótkie (test: nagranie ≤ `VoiceDirector.DAWN_AIR`); na świt mieści się jedna kwestia (pozostałe czekają na kolejny świt).

### 2.4 Liczby i lata
Kokoro przez espeak czyta cyfry jako liczby („1822” → „one thousand eight hundred twenty two”), więc **w EN lata i liczby są słowami** („eighteen twenty-two”); napisy PL mają cyfry (czytelność). Poprawiony też G1 `VO_GUIDE_ROSETTA_A` (było „196 BC”, „1822”).

### 2.5 Wymowa (`data/voice/lexicon.json`)
Dochodzą: `Lamassu` (wielką literą — regex słowniczka rozróżnia wielkość liter), `metopes`, `moai`, `Ksawery`, `Okamura`, `Lipski`, `Gil`, `Gilgamesh`. „boathook” pisane „boat hook” (espeak czytał „bout-hook”).

### 2.6 Stanowiska przewodnika i numery
12 stanowisk w kolejności trasy (numer w tekście „Stop one…twelve”, PL „Stanowisko pierwsze…”). Model stojaka miał na tabliczce na sztywno „1” — tabliczka w modelu jest teraz czysta, a numer stanowiska rysuje `AudioguideStand` (Label3D, czarne cyfry na białej emalii) z `AudioguideStand.STOPS`. Test: numer na tabliczce = numer w tekście A i B.

| Nr | Stanowisko (`audioguide_<id>`) | Sala | Eksponat | Wersja B gdy | Wskazówka w wersji B |
|---|---|---|---|---|---|
| 1 | `rosetta` (G1) | Przedsionek Rosetty | Kamień z Rosetty | Kolos pokonany | — |
| 2 | `ramesses` | Wielka Galeria Egiptu | posągi Ramzesa II | Kolos | szachy za tronem |
| 3 | `lamassu` | Brama Chorsabadu | para lamassu | Lamassu | — |
| 4 | `flood` | Biblioteka Assurbanipala | tabliczka o potopie | Lamassu | magazyn tabliczek za spękaną ścianą |
| 5 | `metopes` | Sala Metop | metopy Partenonu | Kentaur | drzwi na linie na galerii sali z Bassae |
| 6 | `clocks` | Sala Zegarów | zegary, chronometr | Planetarium | archiwum za kratą na linie |
| 7 | `buddha` | Sala Chin i Azji Płd. | wielki Budda | Generał | szachy za Buddą |
| 8 | `armour` | Sala Zbroi | zbroje samurajskie | Generał | skrzynie z 1910 za spękaną ścianą u stóp schodów |
| 9 | `totems` | Sala Totemów | słupy totemowe | Wąż | magazyn zabity deskami (totem z 1931) |
| 10 | `moai` | Sala Moai | moai | Wąż | kryjówka Heńka za moai |
| 11 | `astrolabe` | Czytelnia | astrolabium Zawilskiego | po godzinie duchów | — (fundatorzy, schody) |
| 12 | `trex` | balkon Dziedzińca | T-Rex | po godzinie duchów | bęben Czytelni na szarżę |

Fakty w wersjach A są prawdziwe i ostrożne („podobno” przy liczbie dzieci Ramzesa, „według opowieści” przy Buddzie); ludzie muzeum (Zawilski, Okamura, Lipski, Gil, Mazur, Kopeć) są fikcyjni jak w notatkach.

### 2.7 Głośniki
Po jednym przy wejściu do każdego skrzydła (na ścianie wejścia, obok drzwi, nigdy w przejściu), na Dziedzińcu cztery (dwa z G1 + ściana południowa i północna), w holu wejściowym i w korytarzu północnym. Podziemia i dach bez głośników (System słychać tam cicho z zapasowego odtwarzacza 2D, −6 dB — „przez strop”). Wysokość liczona **od podłogi sali** (2,5–5 m; w Bibliotece Królewskiej głośnik wisi nad galerią, sala znacznika to galeria).

## 3. Zadania

- [x] **Task 1:** ten plan (lista kwestii §4).
- [x] **Task 2:** zdarzenia i pola reguł (TDD): `Events.secret_found / fatigue_rose / hour_struck`, emitery (`WorldFeatures`, `Player` + `Fatigue.stage()/take_rise()`, `NightWatch`), reżyser: pola `modifier`, `room` + `kind` przystani, `gate`, `hour`, pseudo-zdarzenie `idle`, świt od razu; `VoiceCatalog.EVENTS/RULE_FIELDS`, `VoiceRules`.
- [x] **Task 3:** numer stanowiska na stojaku (model z czystą tabliczką, `AudioguideStand.STOPS` + Label3D).
- [x] **Task 4:** rozmieszczenie głośników i 11 stojaków w modułach stref + testy (na ścianie, przodem do sali, nie w przejściu, nie w bryle; stojak na podłodze, z dala od drzwi, miejsc wrogów i łupu, przy swoim eksponacie).
- [x] **Task 5:** kwestie: `locale/strings.csv` (PL + EN), `data/voice/lines.json`, `lexicon.json`; testy katalogu (każda kwestia: tekst PL+EN, reguła z istniejącym celem/strefą/bramą/salą/strażnikiem, nagranie, aktualny skrót; stanowisko ma A i B i stojak; świt ≤ 7 s).
- [x] **Task 6:** nagrania `bash tools/tts/build_voice.sh` (Kokoro → obróbka Systemu stopień 2 → Ogg), pomiar głośności i szczytów, commit nagrań + manifestu.
- [x] **Task 7:** dokumentacja (`docs/audio/dzwiek-przewodnik.html` — nowe pola i zdarzenia; nagłówek projektu), przegląd w oknie (zrzuty rekwizytów przez blokadę), scalenie `pietro-1`, pełny zestaw + testy Pythona.

## 4. Lista kwestii (140: Heniek 69, System 47, przewodnik 24)

Kolumna „Kiedy” to reguła z `data/voice/lines.json` (pole `priority`: 2 wydarzenie, 1 zwykła — domyślnie, 0 poboczna; `delay` w sekundach; każda kwestia raz na grę, poza przewodnikiem). Teksty EN (synteza i napisy EN) są w `locale/strings.csv` pod tym samym kluczem.

### Heniek (radio, `am_michael`)


**Początek nocy** (7)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_NIGHT_1` | event=night_started, night=1, priority=2 | Młody? Tu Heniek. Noga w gipsie, ale radio działa. Klucz do szafki jest w kasie, w szufladzie. I słuchaj: jak coś się rusza, a nie powinno, nie dyskutuj z tym. |
| `VO_HENIEK_NIGHT_2` | event=night_started, night=2, priority=2 | Druga noc, Młody. Wróciłeś, więc albo jesteś odważny, albo nie czytałeś umowy. Dobra wiadomość: strażnik, który padnie, już nie wstaje, a drzwi, które otworzysz, zostają otwarte. |
| `VO_HENIEK_NIGHT_3` | event=night_started, night=3, priority=2 | Trzecia noc. Noga swędzi, czyli się goi. Twoja robota jest prosta: sześć odłamków do astrolabium. Nie pytaj kustosza, co potem. On też nie odbiera. |
| `VO_HENIEK_NIGHT_4` | event=night_started, night=4, priority=2 | Czwarta noc, Młody. Trzydzieści lat robiłem tę robotę i bywały noce, że nie wyszedłem dalej niż do kawiarni. Dobrze ci idzie. Tylko nikomu nie mów, że to powiedziałem. |
| `VO_HENIEK_NIGHT_5` | event=night_started, night_min=5, priority=2 | Dalej tu jesteś? To dobrze. Muzeum uczy się twoich kroków, Młody. Ty ucz się jego zwyczajów. Najbardziej uważaj na te ciche. |
| `VO_HENIEK_MOON` | event=night_started, modifier=full_moon, delay=40 | Dziś pełnia. Są silniejsi, ale sypią się w więcej Pyłu. Mój stary szef nazywał to nadgodzinami. Ja nazywałem to bieganiem. |
| `VO_HENIEK_CALM` | event=night_started, modifier=calm, delay=40 | Spokojna noc, Młody. Mniej ich się obudziło. Nie ufaj temu, ale skorzystaj. Idź tam, gdzie wcześniej nie miałeś odwagi. |

**Zegar nocy (godziny, godzina duchów, świt)** (4)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_WITCHING_1` | event=witching_hour, night=1, delay=3 | Słyszysz ten dzwon? Trzecia. Od teraz są szybsi i mocniej biją. Jeśli masz w pobliżu przystań, to dobry moment, żeby sobie przypomnieć, gdzie jest. |
| `VO_HENIEK_WITCHING_2` | event=witching_hour, night_min=2, delay=3 | Znowu trzecia. Za moich czasów tę godzinę przesiadywałem w kawiarni. Dziś kawiarnia też nie usiedzi spokojnie. Zobaczysz. |
| `VO_HENIEK_DAWN_1` | event=dawn_broke, night=1, priority=2 | Szósta, Młody. Udało ci się. Idź do domu i się wyśpij. I nie śnij o Egipcie. |
| `VO_HENIEK_DAWN_3` | event=dawn_broke, night_min=3, priority=2 | Ranek, Młody. O szóstej wszyscy stoją z powrotem na cokołach. Nie pytaj mnie jak. Przestałem pytać. |

**Pierwsze wejścia (strefy, przystań, sale)** (14)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_ZONE_ENTRANCE` | event=room_entered, zone=entrance | Hol wejściowy. Widzisz czerwoną szafkę pożarową? W środku jest rakietnica. Wosk się topi, mumie uciekają, a szybka robi hałas na pół muzeum. Dwa na trzy to niezły wynik. |
| `VO_HENIEK_ZONE_COURT` | event=room_entered, zone=court | Wielki Dziedziniec. Szklany dach, kawiarnia i Rex pośrodku, który udaje, że jest tylko kośćmi. Na razie daj mu spokój. On jest na koniec, nie na początek. |
| `VO_HENIEK_ZONE_NORTH_HALL` | event=room_entered, zone=north_hall | Korytarz północny. Ta krata prowadzi w dół, do krypty. Leżą tam fundatorzy, twarzą do schodów. Nie stój przy niej za długo. Kustosz stał. |
| `VO_HENIEK_ZONE_EGYPT` | event=room_entered, zone=egypt | Egipt. Mumie boją się ognia, a bicz mają z bandaży, więc stój z boku. Na końcu siedzi Kolos. Jak padnie na ciebie cień jego dłoni, uciekaj spod niej. Jak zamachnie się nisko, skacz. |
| `VO_HENIEK_ZONE_ASSYRIA` | event=room_entered, zone=assyria | Asyria. Lwy z reliefów są z boku płaskie jak naleśniki, więc je obchodź. Wielki skrzydlaty byk grzebie kopytem, zanim zaszarżuje, a jak rozłoży skrzydła, schowaj się za kolumnę. |
| `VO_HENIEK_ZONE_GREECE` | event=room_entered, zone=greece | Grecja. Hoplici chodzą parami za tarczami. Porażaj ich albo strzelaj z antresoli. W Galerii Partenonu czeka Kentaur. Celuj w człowieka, nie w konia. |
| `VO_HENIEK_ZONE_ENLIGHTENMENT` | event=room_entered, zone=enlightenment | Skrzydło Oświecenia. Uważaj na książki: jak okładka trzepocze, zaraz zanurkuje. Sztucer w Gabinecie Historii Naturalnej budzi wilki, więc bierz go i od razu się odwróć. |
| `VO_HENIEK_ZONE_ASIA` | event=room_entered, zone=asia | Azja. Lwy Fu trzymają kulę w pysku. Jak zaświeci, ryczą, a ryk zwala z nóg. Strzelaj w kulę. Generał czeka w ogrodzie za spękanym murem. |
| `VO_HENIEK_ZONE_AMERICAS` | event=room_entered, zone=americas | Ameryki. Totemy zapalają oczy, zanim plują. Zestrzeliwuj je od góry: im mniej twarzy, tym są szybsze. A czółno na hakach to twój jedyny most do świątyni. |
| `VO_HENIEK_ZONE_BASEMENT` | event=room_entered, zone=basement | Podziemia. Kotły, skrzynie i rozdzielnia. Dwa bezpieczniki, Młody: jeden tu, w kotłowni, drugi na górze, w Asyrii. Wtedy w korytarzu północnym podniosą się żaluzje. |
| `VO_HENIEK_ZONE_ROOF` | event=room_entered, zone=roof | Na dachu? Uważaj na szkło. Kładki zaprowadzą cię do wieży Oświecenia. I nie patrz za długo w dół. Szkło świeci od spodu na czerwono, najmocniej nad kratą. |
| `VO_HENIEK_HAVEN` | event=room_entered, kind=haven | Znalazłeś przystań? Dobrze. Nic tu nie wejdzie, a zegar na chwilę staje. Wydaj Pył przy terminalu. Tylko nie drzemij. Drzemanie to moja robota. |
| `VO_HENIEK_ROOM_READING` | event=room_entered, room=court_reading | Czytelnia. Tam jest astrolabium, a ten pusty pierścień to miejsce, gdzie siedział kamień. Zawilski chciał, żeby był pusty. Nikt nie słucha zmarłych. A już najmniej kustosze. |
| `VO_HENIEK_ROOM_CRYPT` | event=room_entered, room=north_hall_crypt | Krypta. Fundatorzy, wszyscy twarzą do schodów. Tam na dole pali się światło, Młody. Ja go nie zostawiłem. Nikt nie zostawił. Trzymaj latarkę pod ręką. |

**Strażnicy i T-Rex** (7)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_DOWN_COLOSSUS` | event=guardian_defeated, guardian=colossus, delay=3 | Kolos leży? Młody, dwadzieścia lat odkurzałem temu panu stopy. Weź pieczęć. Słońce na niej pasuje do bramy do Asyrii. |
| `VO_HENIEK_DOWN_LAMASSU` | event=guardian_defeated, guardian=lamassu, delay=3 | Skrzydlaty byk leży. Pięć nóg, a i tak cię nie dogonił. Pieczęć skrzydła otwiera bramę do Ameryk. Uważaj na totemy. |
| `VO_HENIEK_DOWN_CENTAUR` | event=guardian_defeated, guardian=centaur, delay=3 | Położyłeś Kentaura. Lipski zawsze mówił, że nocą pierś mu mięknie. Pierwszy raz Lipski miał rację. Pieczęć Sowy otwiera Czytelnię. |
| `VO_HENIEK_DOWN_PLANETARIUM` | event=guardian_defeated, guardian=planetarium, delay=3 | Planetarium przestało się kręcić? To klucz z gwiazdą jest twój. Otwiera bramę do korytarza północnego. Powiedziałbym: uważaj, ale to samo mówiłem kustoszowi. |
| `VO_HENIEK_DOWN_GENERAL` | event=guardian_defeated, guardian=general, delay=3 | Generał skończył wartę. Sto lat za późno, ale skończył. Herbaciarnia to teraz przystań. Okamura zrobiłby ci herbatę, gdyby był na miejscu. |
| `VO_HENIEK_DOWN_SERPENT` | event=guardian_defeated, guardian=serpent, delay=3 | Obie głowy? Młody, stawiam ci kawę z termosu. Z domowego, nie z tego za moai. Tamten dalej jest mój. |
| `VO_HENIEK_BOSS_DOWN` | event=boss_defeated, delay=5 | Rex leży. Młody… udało ci się. Krata jest otwarta. Powiedziałbym, żebyś tam nie schodził, ale i tak zejdziesz. To idź. I nie wyłączaj radia. |

**Postęp (odłamki, pieczęcie, bramy, sekrety)** (9)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_SHARD_1` | event=shard_collected, count=1, delay=2 | To odłamek? Czerwony, ciepły i bije jak serce. Nie trzymaj go w tej samej kieszeni co kanapkę. Zostało pięć. |
| `VO_HENIEK_SHARD_3` | event=shard_collected, count=3, delay=2 | Trzy odłamki. Połowa drogi. Stukanie pod kryptą zrobiło się dziś głośniejsze. Albo siada mi radio. Powiedzmy, że to radio. |
| `VO_HENIEK_SHARD_5` | event=shard_collected, count=5, delay=2 | Pięć. Jeszcze jeden i kamień znów będzie cały. Zawilski pisał, że kamień, który się złoży, upomni się o drogę w dół. Tak tylko mówię. |
| `VO_HENIEK_SHARD_6` | event=shard_collected, count=6, delay=2 | To szósty. Włóż je do astrolabium, a Rex się obudzi. Jak szarżuje, stań przy bębnie Czytelni i odskocz w ostatniej chwili. Potem bij w kryształ, nie w kości. |
| `VO_HENIEK_GATE_POWER` | event=gate_opened, gate=shutter_americas | Światło na północy! Gil byłby dumny. No, powiedziałby, że zrobiłeś to źle, ale byłby dumny. Żaluzje do Azji i Ameryk poszły w górę. |
| `VO_HENIEK_GATE_CANOE` | event=gate_opened, gate=hook_canoe | Przyciągnąłeś czółno harpunem? Ja całą zimę próbowałem tego bosakiem. Przed tobą świątynia. Uważaj na obie głowy. |
| `VO_HENIEK_SECRET_1` | event=secret_found, count=1 | Znalazłeś skrytkę? Tu jest ich pełno. Za panelami, pod biurkami, pod podłogą. Pukaj w różne rzeczy, Młody. Grzecznie. |
| `VO_HENIEK_SECRET_MEDIUM` | event=secret_found, kind=medium, priority=0 | To porządne znalezisko. Zatrzymaj je, jest twoje na stałe. Muzeum i tak wisi ci więcej niż pensja. |
| `VO_HENIEK_SECRET_10` | event=secret_found, count=10, priority=0 | Dziesięć skrytek? Młody, znasz ten budynek lepiej niż ci, co go budowali. To nie do końca komplement. |

**Kawiarnia i zmęczenie** (5)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_CAFE` | event=cafe_entered, delay=2 | Za ladą, co? Ekspres działa, jak się go kopnie z lewej. Mleko jest moje. Duży kubek jest mój. Wszystko jest moje, więc się częstuj. |
| `VO_HENIEK_ESPRESSO` | event=coffee_drunk, kind=espresso, priority=0 | Espresso? Krótkie i mocne, jak ja przed raptorem. Długo nie podziała, więc się ruszaj. |
| `VO_HENIEK_LARGE` | event=coffee_drunk, kind=large, priority=0 | Duża. Dobry wybór: na długo trzyma zmęczenie w miejscu. Swoją drogą, to mój kubek. Umyj go. |
| `VO_HENIEK_HAYWIRE` | event=cafe_haywire, priority=0 | Ekspres znowu zwariował? Co noc po trzeciej to samo. Specjał postawi na nogi umarłego. W tym budynku to złe słowa. |
| `VO_HENIEK_TIRED` | event=fatigue_rose, count=1, priority=0 | Brzmisz na zmęczonego, Młody. Słyszę, jak ziewasz przez radio. Kawiarnia jest na Dziedzińcu, a duża kawa trzyma to na dystans. |

**Zastój (podpowiedź do celu)** (18)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_STALL_TICKET_KEY` | event=stall, goal=GOAL_TICKET_KEY, priority=0 | Utknąłeś? Kasa w holu wejściowym. Szuflada. Mówiłem ci, Młody. Nie każ mi przychodzić na jednej nodze. |
| `VO_HENIEK_STALL_PISTOL` | event=stall, goal=GOAL_PISTOL, priority=0 | Masz klucz? Szafka z bronią jest w kanciapie, tam, gdzie zaczynałeś. Tak, cała droga z powrotem. Broń sama nie chodzi. Zazwyczaj. |
| `VO_HENIEK_STALL_SHOTGUN` | event=stall, goal=GOAL_SHOTGUN, priority=0 | Egipt, obóz ekspedycji. Na stole leży strzelba. Jak tylko ją podniesiesz, mumie też wstaną. I tak ją podnieś. |
| `VO_HENIEK_STALL_GUARDIAN_EGYPT` | event=stall, goal=GOAL_GUARDIAN_EGYPT, priority=0 | Sala Kolosa jest na końcu Egiptu, za wielką galerią. Jak się zgubisz, idź za posągami. Jak posągi pójdą za tobą, uciekaj. |
| `VO_HENIEK_STALL_RIFLE` | event=stall, goal=GOAL_RIFLE, priority=0 | Skrzydło Oświecenia, Gabinet Historii Naturalnej. Sztucer leży na stole. Przebija trzech naraz. Okaż mu trochę szacunku. |
| `VO_HENIEK_STALL_GUARDIAN_ENLIGHTENMENT` | event=stall, goal=GOAL_GUARDIAN_ENLIGHTENMENT, priority=0 | Drzwi Planetarium wiszą na linie. Przetnie ją tylko sztucer i tylko z galerii obserwatorów na wieży. |
| `VO_HENIEK_STALL_GUARDIAN_GREECE` | event=stall, goal=GOAL_GUARDIAN_GREECE, priority=0 | Grecja, Galeria Partenonu. Magazyn odlewów to ostatnie bezpieczne drzwi przed nią. Najpierw tam złap oddech. |
| `VO_HENIEK_STALL_GATLING` | event=stall, goal=GOAL_GATLING, priority=0 | Czytelnia otwarta. Kartaczownica stoi w gablocie na łańcuchu. Łańcuch puści, jak się w niego porządnie walnie. Czymś ciężkim, Młody. |
| `VO_HENIEK_STALL_FUSE_BASEMENT` | event=stall, goal=GOAL_FUSE_BASEMENT, priority=0 | Bezpiecznik: kotłownia w podziemiach. Z każdego skrzydła prowadzą tam schody. Uważaj na parę. |
| `VO_HENIEK_STALL_FUSE_ASSYRIA` | event=stall, goal=GOAL_FUSE_ASSYRIA, priority=0 | Drugi bezpiecznik jest w Asyrii, w Galerii Nimrud, na rusztowaniu. Dotkniesz rusztowania, to się obudzi. Nie bierz tego do siebie. |
| `VO_HENIEK_STALL_POWER` | event=stall, goal=GOAL_POWER, priority=0 | Oba bezpieczniki do rozdzielni w podziemiach. Gil wszystko opisał. Gil wszystko opisuje. Wtedy pójdą w górę żaluzje na północy. |
| `VO_HENIEK_STALL_HWACHA` | event=stall, goal=GOAL_HWACHA, priority=0 | Sala Koreańska w Azji. Ognista skrzynia. Jedna salwa i spękanego muru nie ma. Tak, tego też. |
| `VO_HENIEK_STALL_GUARDIAN_ASIA` | event=stall, goal=GOAL_GUARDIAN_ASIA, priority=0 | Spękany mur obok Buddy. Wysadź go, a za nim jest ogród japoński. Czeka tam Generał. Czekać to on umie. |
| `VO_HENIEK_STALL_HARPOON` | event=stall, goal=GOAL_HARPOON, priority=0 | Harpunnik jest w Galerii Pacyfiku. Bierz go przodem do drzwi. Wachta wielorybników budzi się za twoimi plecami. |
| `VO_HENIEK_STALL_GUARDIAN_AMERICAS` | event=stall, goal=GOAL_GUARDIAN_AMERICAS, priority=0 | Czółno na hakach. Zahacz je harpunem i ciągnij. To twój most do świątyni. |
| `VO_HENIEK_STALL_ASTROLABE` | event=stall, goal=GOAL_ASTROLABE, priority=0 | Wszystkie sześć? To do Czytelni i do astrolabium z nimi. A potem się odsuń. Szybko. |
| `VO_HENIEK_STALL_EXPLORE` | event=stall, goal=GOAL_EXPLORE, priority=0 | Rozejrzyj się, Młody. Zamknięte drzwi zawsze czegoś chcą: pieczęci, bezpiecznika, ciężkiej ręki. A zasuwa otwiera się od drugiej strony. |
| `VO_HENIEK_STALL` | event=stall, priority=0 | Cicho tam u ciebie, Młody. Za cicho. Zajrzyj na papierową mapę. Tam, gdzie są ołówkowe kreski, ja bym poszedł. |

**Po śmierci (na zmianę)** (5)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_HENIEK_DEATH_1` | event=death | Wczoraj zamilkłeś mi w radiu, Młody. Nie rób tak. Serce mam już nie to. Latarka do przodu, plecy do ściany. |
| `VO_HENIEK_DEATH_2` | event=death | Dopadli cię? Zdarza się. Mazur kiedyś przegrał z woskowym Napoleonem. Stracił przy tym zegarek po dziadku. Ty straciłeś tylko noc. |
| `VO_HENIEK_DEATH_3` | event=death | Znowu? Oni się ciebie uczą, Młody. Ty ucz się ich. Patrz, co każdy robi tuż przed ciosem. Każdy to zdradza. |
| `VO_HENIEK_DEATH_4` | event=death, night_min=3 | Jak twoje radio milknie, siedzę tu i liczę. Kopeć w 1912 roku nie miał radia. Tylko latarnię. Nigdy jej nie znaleźli. |
| `VO_HENIEK_DEATH_5` | event=death | Znowu na nogach? To dobrze. Muzeum bierze jedną noc, ty bierzesz następną. Taki układ. Ja też go nie podpisywałem. |

### System (głośniki, `af_nicole`, stopień 2)


**Początek nocy** (5)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_CLOSING_1` | event=night_started, night_min=1, delay=20, priority=1 | Uwaga. Muzeum Miejskie jest zamknięte. Dziękujemy za wizytę. Pracownik ochrony proszony jest o niedotykanie eksponatów. Także tych, które dotykają jego. |
| `VO_SYSTEM_NIGHT_2` | event=night_started, night=2, delay=50 | Dobry wieczór. Muzeum jest zamknięte. Wczorajsze straty w kolekcji zostały oszacowane. Kwota się panu nie spodoba. Nam też się nie spodobała. |
| `VO_SYSTEM_NIGHT_3` | event=night_started, night=3, delay=50 | Dobry wieczór, pracowniku ochrony. Jest pan jedynym pracownikiem na nocnej zmianie. Gratulujemy awansu. Podwyżki nie przewidziano. |
| `VO_SYSTEM_NIGHT_4` | event=night_started, night_min=4, delay=50 | Dobry wieczór. Przypominamy, że kustosz przebywa na bezterminowym urlopie. Bezterminowy oznacza, że nie wiemy, kiedy wróci. Wiemy. |
| `VO_SYSTEM_BLACKOUT` | event=night_started, modifier=blackout, delay=40, speed=0.88 | Komunikat. Brak zasilania sieciowego. Muzeum działa na oświetleniu awaryjnym. Przypominamy pracownikowi ochrony, że latarka to nie zabawka. My też nie. |

**Zegar nocy (godziny, godzina duchów, świt)** (10)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_HOUR_0` | event=hour_struck, hour=0, night=1 | Jest północ. Rozpoczął się nocny program muzeum. Prosimy nie karmić, nie dotykać i nie zachęcać eksponatów. |
| `VO_SYSTEM_HOUR_1` | event=hour_struck, hour=1, night_min=2 | Jest pierwsza. W galeriach włączono tryb oszczędzania energii. Eksponatów nie poinformowano. |
| `VO_SYSTEM_HOUR_2` | event=hour_struck, hour=2, night_min=2 | Jest druga. Przypominamy pracownikom, że spanie w sarkofagach jest zabronione. Sarkofagi są zajęte. |
| `VO_SYSTEM_HOUR_4` | event=hour_struck, hour=4 | Jest czwarta. Eksponaty uprzejmie prosimy o powrót na cokoły. Eksponaty uprzejmie ignorują tę prośbę. |
| `VO_SYSTEM_HOUR_5` | event=hour_struck, hour=5, night_min=2 | Jest piąta. Do otwarcia została godzina. Pracownik ochrony proszony jest o schludny wygląd. I o oznaki życia. |
| `VO_SYSTEM_WITCHING_1` | event=witching_hour, night=1, priority=2 | Jest trzecia. Muzeum weszło w godzinę duchów. To nie jest zaplanowane wydarzenie. Mimo to się odbywa. |
| `VO_SYSTEM_WITCHING_2` | event=witching_hour, night=2, priority=2 | Trzecia. Wszystkie eksponaty działają teraz na stu dwudziestu procentach. Uprzejmie zauważamy, że pan nadal działa na stu. |
| `VO_SYSTEM_WITCHING_3` | event=witching_hour, night_min=3, priority=2, speed=0.88 | Trzecia. Muzeum nie jest już pewne, kto kogo zwiedza. Eksponaty, proszę wrócić na cokoły. Eksponaty. Proszę. Proszę. |
| `VO_SYSTEM_DAWN_2` | event=dawn_broke, night=2, priority=2, speed=1.0 | Szósta. Nocna zmiana dobiegła końca. Dziękujemy. |
| `VO_SYSTEM_DAWN_4` | event=dawn_broke, night_min=4, priority=2, speed=1.0 | Szósta. Światło dnia wchodzi. Coś innego wychodzi. |

**Strażnicy i T-Rex** (8)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_WAKE_COLOSSUS` | event=guardian_awakened, guardian=colossus, priority=2 | Uwaga. Kolosalny posąg w skrzydle egipskim opuścił pozycję siedzącą. Zwiedzających prosimy, by nie stali w jego cieniu. Ani w Egipcie. |
| `VO_SYSTEM_WAKE_LAMASSU` | event=guardian_awakened, guardian=lamassu, priority=2 | Uwaga. Lamassu opuścił Bramę Chorsabadu. Przypominamy, że ma pięć nóg, a pan dwie. Prosimy odpowiednio zaplanować dalsze kroki. |
| `VO_SYSTEM_WAKE_CENTAUR` | event=guardian_awakened, guardian=centaur, priority=2 | Uwaga. Z rzeźb Partenonu zszedł centaur. Jest w galerii. Jest za panem. Muzeum dziękuje za cierpliwość. |
| `VO_SYSTEM_WAKE_PLANETARIUM` | event=guardian_awakened, guardian=planetarium, priority=2 | Uwaga. Wielkie Planetarium jest w ruchu. Nad niskimi ramionami prosimy skakać. Pod wysokimi stawać w lukach. Prosimy nie zostawać księżycem. |
| `VO_SYSTEM_WAKE_GENERAL` | event=guardian_awakened, guardian=general, priority=2 | Uwaga. Zbroja Generała nie jest już eksponatem. Jest na służbie. Przypominamy, że ostrze błyska, zanim tnie. |
| `VO_SYSTEM_WAKE_SERPENT` | event=guardian_awakened, guardian=serpent, priority=2 | Uwaga. Dwugłowy wąż opuścił ołtarz. Jedna głowa patrzy na pana. Druga w dół. Żadna nie odwraca wzroku. |
| `VO_SYSTEM_BOSS_AWAKE` | event=boss_awakened, priority=2 | Uwaga. Tyranozaur nie jest już wymarły. Wielki Dziedziniec zostaje zamknięty do odwołania. Muzeum przeprasza za utrudnienia. Pana. |
| `VO_SYSTEM_BOSS_DOWN` | event=boss_defeated, delay=2 | Tyranozaur wrócił do kolekcji. W częściach. Krypta jest otwarta. Muzeum nie odpowiada za to, co znajduje się pod muzeum. |

**Postęp (odłamki, pieczęcie, bramy, sekrety)** (9)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_SEAL` | event=seal_collected, delay=2 | Przedmiot zabrano z eksponatu bez podpisanej umowy użyczenia. Jego wartość zostanie potrącona z pensji pracownika ochrony. W ratach. Na zawsze. |
| `VO_SYSTEM_GATE_KHORSABAD` | event=gate_opened, gate=seal_khorsabad | Brama Chorsabadu została otwarta bez autoryzacji. Kolekcja asyryjska jest otwarta dla zwiedzających. Nie ma zwiedzających. Jest pan. |
| `VO_SYSTEM_GATE_POWER` | event=gate_opened, gate=shutter_asia, delay=6 | Przywrócono zasilanie w skrzydle północnym. Dziękujemy za naprawę bezpieczników. Nikt pana o to nie prosił. |
| `VO_SYSTEM_GATE_READING` | event=gate_opened, gate=gate_reading_room | Czytelnia jest otwarta. Proszę o ciszę. Astrolabium słucha. |
| `VO_SYSTEM_GATE_NORTH` | event=gate_opened, gate=gate_north | Korytarz północny jest otwarty. Krypta fundatorów nie należy do trasy zwiedzania. Prosimy trzymać się trasy zwiedzania. Nie ma trasy zwiedzania. |
| `VO_SYSTEM_GATE_GARDEN` | event=gate_opened, gate=cracked_garden | Ściana skrzydła azjatyckiego została wyburzona. Ogród japoński ma teraz otwarty plan. Muzeum nie zlecało tego remontu. |
| `VO_SYSTEM_SECRET_GREAT` | event=secret_found, kind=great | Komunikat inwentaryzacyjny. W niezarejestrowanym miejscu odnaleziono skarb muzeum. Prosimy go nie zabierać. Zabierze go pan. |
| `VO_SYSTEM_SECRET_SMALL` | event=secret_found, kind=small, priority=0 | W ścianie znaleziono zapasy. Przypominamy, że gromadzenie zapasów w ścianach jest niezgodne z regulaminem. Mieszkanie w nich również. |
| `VO_SYSTEM_SECRET_20` | event=secret_found, count=20, priority=0 | Odnaleziono dwadzieścia niezarejestrowanych pomieszczeń. Plan muzeum jest w trakcie aktualizacji. Plan muzeum protestuje. |

**Kawiarnia i zmęczenie** (3)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_HAYWIRE` | event=cafe_haywire, priority=2 | Ostrzeżenie. Ekspres w kawiarni pracuje poza parametrami. Wszystko inne również. Zapraszamy na specjał godziny duchów. |
| `VO_SYSTEM_SPECIAL` | event=coffee_drunk, kind=special, priority=0 | Spożył pan specjał godziny duchów. Drżenie rąk jest normalne. Drżenie ścian również. |
| `VO_SYSTEM_TIRED` | event=fatigue_rose, count=2, priority=0 | Wydajność pracownika ochrony spadła poniżej dopuszczalnego poziomu. Prosimy odpocząć w wyznaczonej przystani albo wypić coś z kofeiną. Spanie tutaj jest niewskazane. |

**Raporty strat i bezruch** (7)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_LOSSES_10` | event=destroyed, count=10 | Raport o stanie kolekcji. Zniszczono dziesięć eksponatów. Ich wartość zostanie potrącona z pensji pracownika ochrony. |
| `VO_SYSTEM_LOSSES_50` | event=destroyed, count=50 | Raport o stanie kolekcji. Zniszczono pięćdziesiąt eksponatów. W tym tempie za tydzień muzeum będzie puste. Muzeum dziękuje za dodatkowe miejsce. |
| `VO_SYSTEM_LOSSES_100` | event=destroyed, count=100 | Raport o stanie kolekcji. Zniszczono sto eksponatów. Potrącenia z pensji pracownika ochrony sięgają już następnego stulecia. |
| `VO_SYSTEM_LOSSES_200` | event=destroyed, count=200 | Zniszczono dwieście eksponatów. Muzeum aktualizuje polisę ubezpieczeniową. Ubezpieczyciel przestał odbierać telefon. |
| `VO_SYSTEM_LOSSES_400` | event=destroyed, count=400 | Czterysta eksponatów. Muzeum nie raportuje już strat. Muzeum raportuje teraz ocalałych. |
| `VO_SYSTEM_IDLE_1` | event=idle, priority=0 | Czujniki ruchu nie wykrywają ruchu pracownika ochrony. Jeśli pan się chowa, to działa. Jeśli pan śpi, to nie. |
| `VO_SYSTEM_IDLE_2` | event=idle, night_min=2, priority=0 | Stoi pan bez ruchu od dłuższego czasu. Zauważyło to kilka eksponatów. One też tak zaczynały. |

**Po śmierci (na zmianę)** (5)

| Klucz | Kiedy | Napis PL |
|---|---|---|
| `VO_SYSTEM_DEATH_1` | event=death | Witamy z powrotem. Pańska poprzednia zmiana zakończyła się przedwcześnie. Muzeum zakwalifikowało zdarzenie jako dopuszczalne straty. |
| `VO_SYSTEM_DEATH_2` | event=death | Dobry wieczór. Według naszych danych wczoraj pan przegrał. Eksponaty proszą, żeby się pan bardziej postarał. Lubią ruch. |
| `VO_SYSTEM_DEATH_3` | event=death | Poprzedni pracownik ochrony też ciągle wracał. Aż przestał. To nie jest groźba. To jest archiwum. |
| `VO_SYSTEM_DEATH_4` | event=death | Muzeum z zainteresowaniem odnotowuje pański powrót. Niewielu pracowników wraca po takiej nocy. Niewielu pracowników. |
| `VO_SYSTEM_DEATH_5` | event=death, night_min=3 | Raport ze zdarzenia. Przyczyna porażki pracownika ochrony: eksponaty. Zalecane działanie: mniej eksponatów. Wniosek odrzucony. |

### Audioprzewodnik (24, 12 stanowisk × A/B, System stopień 2)

| Klucz | Wersja B gdy | Napis PL |
|---|---|---|
| `VO_GUIDE_ROSETTA_A` | — | Stanowisko pierwsze. Kamień z Rosetty, 196 rok p.n.e. Ten sam dekret zapisano trzy razy: hieroglifami, pismem demotycznym i po grecku. Dzięki greckiemu tekstowi Jean-François Champollion odczytał hieroglify w 1822 roku. |
| `VO_GUIDE_ROSETTA_B` | colossus | Stanowisko pierwsze. Kamień z Rosetty. Ten sam tekst zapisano trzy razy, bo za pierwszym razem nikt nie słuchał. Za drugim też nie. Proszę nie stać tak blisko. Kamień nie lubi, kiedy się go czyta po zmroku. |
| `VO_GUIDE_RAMESSES_A` | — | Stanowisko drugie. Ramzes II rządził Egiptem przez 66 lat, ponad trzy tysiące lat temu. Wzniósł więcej własnych posągów niż jakikolwiek inny faraon. Podobno miał ponad stu potomków i wielu z nich przeżył. |
| `VO_GUIDE_RAMESSES_B` | colossus | Stanowisko drugie. Ramzes II rządził przez 66 lat. Dziś w nocy rządził trochę dłużej. Jego tron na końcu tej galerii jest teraz pusty. Za nim chowa się mała figurka szachowa. Uciekła z gabloty. Sama nie wróci. |
| `VO_GUIDE_LAMASSU_A` | — | Stanowisko trzecie. Lamassu: duch opiekuńczy z głową człowieka, ciałem byka i skrzydłami ptaka. Ta para stała w bramie pałacu króla Sargona II w Chorsabadzie, około 710 roku p.n.e. Proszę policzyć nogi. Jest ich pięć. |
| `VO_GUIDE_LAMASSU_B` | lamassu | Stanowisko trzecie. Lamassu ma pięć nóg: z przodu stoi, z boku kroczy. Dziś w nocy użył wszystkich pięciu. Jego para wciąż stoi w bramie. Jego para wciąż pana obserwuje. Proszę przejść do następnego stanowiska. Proszę przejść. |
| `VO_GUIDE_FLOOD_A` | — | Stanowisko czwarte. Gliniana tabliczka z biblioteki króla Assurbanipala w Niniwie, VII wiek p.n.e. Opowiada fragment Eposu o Gilgameszu: wielki potop, człowieka, który zbudował łódź, i ptaki wysłane na poszukiwanie suchego lądu. Gołębia, jaskółkę i kruka. |
| `VO_GUIDE_FLOOD_B` | lamassu | Stanowisko czwarte. Kruk nie wrócił, bo znalazł ląd. Coś pod tym muzeum ciągle wysyła rzeczy w górę. Wciąż szuka suchego lądu. Za spękaną ścianą ktoś wciąż zapisuje tabliczki. |
| `VO_GUIDE_METOPES_A` | — | Stanowisko piąte. Metopy z Partenonu w Atenach, wyrzeźbione w V wieku p.n.e. Na południowej stronie świątyni Lapici walczą z centaurami, którzy zakłócili ucztę weselną. Na niektórych płytach wygrywają Lapici. Na innych centaury. |
| `VO_GUIDE_METOPES_B` | centaur | Stanowisko piąte. Na marmurze Lapici wygrywają na jednych płytach, a centaury na innych. Dziś w nocy ta sprawa się rozstrzygnęła. Na galerii sali z Bassae są drzwi zawieszone na linie. Celny strzał je otworzy. |
| `VO_GUIDE_CLOCKS_A` | — | Stanowisko szóste. Sala Zegarów. Przez stulecia żeglarze umieli ustalić, jak daleko są na północ, ale nie na wschód ani na zachód. W XVIII wieku zmienił to chronometr okrętowy: zabierasz czas portu macierzystego, porównujesz ze słońcem, a różnica daje długość geograficzną. |
| `VO_GUIDE_CLOCKS_B` | planetarium | Stanowisko szóste. Wszystkie zegary w tej sali pokazują teraz tę samą godzinę. Nie tutejszą. Tamtą, z dołu. Za kratą na linie archiwum trzyma się wcześniejszej godziny. |
| `VO_GUIDE_BUDDHA_A` | — | Stanowisko siódme. Budda siedzący w medytacji. Prawą dłonią sięga w dół, by dotknąć ziemi. Według opowieści w noc swojego oświecenia został wyzwany i wezwał samą ziemię na świadka. |
| `VO_GUIDE_BUDDHA_B` | general | Stanowisko siódme. Budda wezwał ziemię na świadka. Dziś w nocy ziemia odpowiedziała i wciąż odpowiada. Za Buddą chowa się ktoś mały z tarczą. Gryzie. |
| `VO_GUIDE_ARMOUR_A` | — | Stanowisko ósme. Zbroje samurajskie z okresu Edo. Setki drobnych płytek z żelaza i skóry, lakierowanych i powiązanych jedwabnym sznurem, żeby zbroja poruszała się razem z ciałem. Przez większość tej epoki Japonia żyła w pokoju. Wiele z tych zbroi nigdy nie widziało bitwy. |
| `VO_GUIDE_ARMOUR_B` | general | Stanowisko ósme. Wiele z tych zbroi nigdy nie widziało bitwy. To już nieaktualne. Pod maską Generała coś oddychało. Przestało. U stóp schodów, za spękaną ścianą, czekają skrzynie z 1910 roku. |
| `VO_GUIDE_TOTEMS_A` | — | Stanowisko dziewiąte. Słupy totemowe z północno-zachodniego wybrzeża Ameryki Północnej, wyrzeźbione z czerwonego cedru. Postaci na nich to nie bogowie. To herby: zwierzęta i przodkowie rodu, ustawieni jeden na drugim, żeby każdy wiedział, czyj to dom. |
| `VO_GUIDE_TOTEMS_B` | serpent | Stanowisko dziewiąte. Słupy mówią, czyj to dom. Proszę je policzyć. Słup numer trzy wszedł w ścianę w 1931 roku. Wciąż słychać, jak śpiewa pod podłogą, za magazynem zabitym deskami. |
| `VO_GUIDE_MOAI_A` | — | Stanowisko dziesiąte. Moai z Rapa Nui, Wyspy Wielkanocnej. Wyspiarze wyrzeźbili blisko tysiąc takich postaci. Większość stała na kamiennych platformach wzdłuż wybrzeża, plecami do morza, i czuwała nad wioskami żywych. |
| `VO_GUIDE_MOAI_B` | serpent | Stanowisko dziesiąte. Moai stały plecami do morza, żeby czuwać nad żywymi. Ten stoi twarzą do kraty w korytarzu północnym. Nie czuwa nad panem. Za nim nocny stróż ukrył swój termos. Muzeum zawsze o tym wiedziało. |
| `VO_GUIDE_ASTROLABE_A` | — | Stanowisko jedenaste. Astrolabium naszego fundatora, Ksawerego Zawilskiego. Astrolabium to niebo złożone na mosiężnej tarczy: można z niego odczytać godzinę z gwiazdy albo znaleźć gwiazdę o danej godzinie. Pierścień w jego sercu jest pusty. Testament fundatora prosi, by taki pozostał. |
| `VO_GUIDE_ASTROLABE_B` | po godzinie duchów | Stanowisko jedenaste. Pierścień w sercu astrolabium miał pozostać pusty. Wypełniono go i pękł. Wypełni go pan ponownie. Fundatorzy leżą twarzą do schodów. Pan też kiedyś tak będzie leżał. |
| `VO_GUIDE_TREX_A` | — | Stanowisko dwunaste. Tyrannosaurus rex, król jaszczurów tyranów. Żył u samego schyłku ery dinozaurów, około 66 milionów lat temu, na terenie dzisiejszej Ameryki Północnej. Miał jeden z najsilniejszych zgryzów spośród wszystkich zwierząt lądowych, jakie kiedykolwiek żyły. |
| `VO_GUIDE_TREX_B` | po godzinie duchów | Stanowisko dwunaste. Tyrannosaurus rex, 66 milionów lat. Nie śpi. Czeka na swoje serce. Kiedy szarżuje, słabo skręca. Bęben Czytelni nie skręca wcale. |

## 5. Przewodnik odsłuchu (dla właściciela)

Nagrania: `assets/voice/heniek/*.ogg` (suche — radio dokłada szyna `VoiceRadio` w grze), `assets/voice/system/*.ogg` (System i przewodnik, już po obróbce stopnia 2). Najlepiej słuchać **w grze** (radio, echo głośników, wyciszanie muzyki), ale do szybkiej oceny wystarczą pliki.

1. **Heniek, ton:** `VO_HENIEK_NIGHT_1…5` (ewolucja przez noce), `ZONE_EGYPT` (wskazówka), `DOWN_COLOSSUS` (ciepło), `DEATH_4` (najciemniejsza), `CAFE` (humor), `BOSS_DOWN` (finał). Pytanie: czy `am_michael` niesie żart i ciepło; czy tempo 1,0 nie jest za szybkie (zmiana: `speed` w `speakers.json` albo per kwestia w `lines.json`).
2. **System, ton:** `CLOSING_1`, `WAKE_LAMASSU`, `LOSSES_10`, `HAYWIRE`, `BLACKOUT` i `WITCHING_3` (tempo 0,88 — czy słychać eskalację bez stopnia 3), `NIGHT_4`, `DEATH_3`. Pytanie: czy zacięcia stopnia 2 nie zjadają słów kluczowych (nazwy strażników, liczby).
3. **Wymowa:** `lamassu` (`WAKE_LAMASSU`, `GUIDE_LAMASSU_A`), `metopes` (`GUIDE_METOPES_A`), `moai` (`GUIDE_MOAI_A`), `Ksawery Zawilski` (`GUIDE_ASTROLABE_A`), `Okamura` (`DOWN_GENERAL`), `Kopeć` (`DEATH_4`), `Lipski` (`DOWN_CENTAUR`), `Gil` (`GATE_POWER`, `STALL_POWER`), `Champollion` (`GUIDE_ROSETTA_A`), `Ramesses`, `Ashurbanipal`, `Gilgamesh`. Złą wymowę poprawia `data/voice/lexicon.json` (IPA) + `bash tools/tts/build_voice.sh`.
4. **Przewodnik:** dowolne stanowisko A i B (np. `GUIDE_FLOOD_A/B`) — wersje A mają 21–29 s (cel projektu 15–25 s; `af_nicole` mówi ok. 100 słów/min), B 19–26 s. Czy fakty nie nużą; czy wersja B brzmi „źle” we właściwy sposób.
5. **Świt:** `HENIEK_DAWN_1`, `SYSTEM_DAWN_2` muszą się zmieścić przed następną nocą (≤ 7 s; zmierzone 5,7–6,8 s).
6. **Głośność (liczby, `tools/tts/loudness.py`):** Heniek mediana −17,8 LUFS (rozrzut σ 1,0 dB), System −17,7 LUFS (σ 0,5 dB), szczyty ≤ −1 dBFS. 9 kwestii jest 2–3 dB ciszej od mediany, bo przy normalizacji wygrał limit szczytu (`STALL_TICKET_KEY`, `SHARD_5`, `DEATH_4`, `ZONE_GREECE`, `WITCHING_1`, `STALL_FUSE_ASSYRIA`, `HENIEK_DAWN_1`, `SYSTEM_NIGHT_4`, `WAKE_SERPENT`). U Heńka wyrówna to kompresor szyny radia; jeśli u Systemu słychać różnicę — propozycja: miękki limiter szczytów w `generate_voice.normalize()` + `fx_version` 3 (wszystko na nowo, ok. 15 min). Nie robiłem tego bez ucha.
7. **W grze** (dowolna noc): radio Heńka i kliknięcia, echo między głośnikami Dziedzińca, wyciszanie muzyki pod mową, czy napisy nadążają za tempem `af_nicole`.

Jak zmienić kwestię: tekst w `locale/strings.csv` (PL i EN) → `bash tools/tts/build_voice.sh` (tylko zmienione) → `bash tools/run_tests.sh --filter=voice`.

## 6. Do sprawdzenia w oknie

Zrzuty z 19.10, 02:00–02:25, przez blokadę (`bash tools/run_tour.sh shots --only=voice_…`, widoki `voice_*` w `tests/scenarios/tour_scenario.gd`, pliki `tests/_out/tour/voice_*.png`), bez dźwięku:
- [x] **Głośniki** (12): Dziedziniec płd./płn. — na gładkiej ścianie między pilastrami; hol wejściowy — na ścianie obok łuku; korytarz północny — nad portretem, między pilastrami; Brama Chorsabadu — nad fryzem, obok drzwi do biblioteki; Sala Nereid — na gładkiej ścianie; Biblioteka Królewska — nad łukiem z Dziedzińca, nad tablicą „Biblioteka Królewska”; Sala Chin — pod fryzem; Ameryka Płn. — **wisiał na malowanym fryzie** (ubrane Ameryki weszły z `pietro-1` w trakcie) → obniżony do 3,3 m, pod fryz (zrzut po poprawce OK).
- [x] **Stojaki** (12): wszystkie stoją na podłodze obok eksponatu, poza przejściem; numer na tabliczce czytelny z 3–4 m (Rosetta, Ramzes, lamassu, tabliczka, metopy, zegary, Budda, zbroje, totemy, moai, astrolabium, T-Rex na balkonie przy balustradzie).
- [ ] **Do obejrzenia przez właściciela:** stojak T-Reksa stoi na balkonie (Rex widoczny w dole) — czy nie przeszkadza w walce z T-Reksem (balkon ma zapasy amunicji); stojak Buddy stoi tuż przy zasadzce lwów Fu (słuchanie przy Buddzie może je obudzić — zamierzone mrugnięcie, do decyzji).
- [ ] **Napisy dwuwierszowe** (poprawka `visual-qa` 4d90772 — po jej scaleniu): czy długie komunikaty Systemu dzielą się na czytelne części.
- **Przy okazji (nie moje):** w Bibliotece Królewskiej zielony znak wyjścia nad łukiem z Dziedzińca zasłania napis tablicy „Biblioteka Królewska” (`tests/_out/tour/voice_library.png`).

## 7. Stan prac / co dalej

**Wynik (19.10, ok. 04:30):** zadania 1–7 zrobione na gałęzi `voice-g2` (od `pietro-1` @2dacf29, scalone z `pietro-1` @5b76f76 — muzyka biomów, ekologia wrogów, ubrane i dopracowane Ameryki, dach, trumna mumii, nowy styl HUD). Pełny zestaw `bash tools/run_tests.sh`: **2587 testów, 0 błędów**, bez linii ERROR; testy Pythona (`tools/tts`) 15/15 OK. Żaden proces Godota/Pythona/Blendera tego agenta nie został uruchomiony w tle.

### Zrobione
- **Zdarzenia (addytywnie):** `Events.secret_found(secret, tier, found)` z `WorldFeatures.discover_secret`, `Events.fatigue_rose(stage)` z `Player` (`Fatigue.stage()` / `take_rise()`, próg 0,35 i `WORN_OUT` 0,6; wznowiona noc nie ogłasza zmęczenia), `Events.hour_struck(hour)` z `NightWatch`. Reżyser: `modifier` przy `night_started`, `room` + `kind: haven` przy `room_entered`, `gate` przy `gate_opened`, `secret_found` (`kind` = próg, `count`), `fatigue_rose` (`count`), `hour_struck` (`hour`), pseudo-zdarzenie `idle` (120 s w promieniu 1 m, raz na noc, tylko z kamerą), świt bez czekania (`DAWN_AIR` 7 s). `VoiceCatalog.EVENTS/RULE_FIELDS`, `VoiceRules` (pola tekstowe i liczbowe).
- **Rekwizyty:** 10 nowych głośników (razem 12), 11 nowych stojaków (razem 12) w funkcjach `_voice()` modułów stref; numer stanowiska na stojaku (Label3D na czystej tabliczce modelu, `AudioguideStand.STOPS`; model przebudowany `PREVIEW=0 bash tools/art/build_art.sh audioguide_stand`, zmieniły się tylko tekstury).
- **Kwestie:** 140 (Heniek 69, System 47, przewodnik 24) w `locale/strings.csv` i `data/voice/lines.json`, słowniczek +9 haseł, nagrania Kokoro + obróbka stopnia 2 + Ogg (`assets/voice`, 17 MB, 32 min mowy: Heniek 11 min, System z przewodnikiem 21 min), `manifest.json`. Poprawiony G1 `VO_GUIDE_ROSETTA_A` (cyfry czytane jako liczby).
- **Testy:** `test_voice_data` (cel każdej reguły istnieje; stanowisko = A + B + stojak + numer w tekście; komentarze śmierci obu mówiących; Heniek nie wchodzi w walkę; świt ≤ 7 s; ogólna podpowiedź zastoju na końcu; zasady tekstów), `test_voice_director` (nowe ładunki, bezruch, świt, śmierć na zmianę na prawdziwym katalogu), `test_voice_props` (rozmieszczenie), `test_fatigue`, `test_player`, `test_floor1_game`, `test_world_rewards`. Narzędzie `tools/tts/loudness.py`.
- **Dokumentacja:** `docs/audio/dzwiek-przewodnik.html` §12 (nowe zdarzenia i pola, świt, głośniki i stojaki, liczby słowami), nagłówek projektu.

### Odstępstwa i decyzje
- Wskazówki do strażników mówi Heniek **przy pierwszym wejściu do skrzydła**, nie przy przebudzeniu (przebudzenie to walka; Heniek nie przerywa walki). Przy przebudzeniu mówi System (komunikat z głośników, priorytet 2).
- Godziny nocy idą po prawdziwym zegarze (`hour_struck`), nie po `night_time` (zegar nocy stoi w przystaniach, licznik reżysera nie).
- System ma 47 kwestii (projekt: 30–40) — raporty strat, godziny i komunikaty o bramach rozłożone na 3–4 noce, każda raz na grę.
- Stopnia 3 obróbki nie ma (eskalacja tekstem i tempem 0,88) — do decyzji po odsłuchu.
- `door_creaked` z ekologii wrogów (doszło przy scaleniu) to sygnał percepcji, nie zdarzenie fabularne — bez kwestii.

### Co dalej (dla właściciela / G3)
- Odsłuch wg §5; ewentualnie limiter szczytów (§5 pkt 6) i stopień 3 Systemu.
- Pogłos głosu przez `SFXReturn` (znany kompromis z G1) — bez zmian.
- Jeśli dojdą nowe zdarzenia fabularne (np. ekologia wrogów: „stado się zbiera”), kwestie dopisuje się wg §12 przewodnika dźwięku.
