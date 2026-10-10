# Etap 2 — lobby z pełną pętlą: projekt szczegółowy

> Stan: 30 września 2026. Autor decyzji: Claude (praca autonomiczna na prośbę użytkownika — „kontynuuj samodzielnie do końca MVP, potem dopieść jeden obszar do poziomu Steam”). Wszystkie liczby to punkt startowy do strojenia.
> Nadrzędna specyfikacja: `docs/Nocna-Zmiana-specyfikacja.md`. Ten dokument rozstrzyga szczegóły, których tam nie ma.

## 0. Zasady nadrzędne etapu 2

1. **Buduj pod jakość wydania, nie pod prototyp.** Każdy system od początku ma: zapis/odczyt, zachowanie po śmierci, test bez okna, teksty przez `tr()`.
2. **Kod buduje węzły** (jak w 1a), ale poziom opisuje **dane** (tablica pomieszczeń/drzwi/schodów w GDScripcie), a nie ręcznie klikana scena. Etap 3 podmieni szare bryły na modele z Blendera, zachowując ten sam układ.
3. **Rozdział stanu:** `GameState` (trwałe, zapis JSON) ↔ `RunState` (jedna noc). Tylko te dwa miejsca decydują, co przeżywa śmierć.
4. **Deterministyczna noc:** całe losowanie nocy idzie z jednego `RandomNumberGenerator` zasianego ziarnem nocy. Ta sama noc = to samo ziarno.
5. **Ciche uruchomienia deweloperskie:** każde okienkowe uruchomienie z narzędzi ma `--audio-driver Dummy`.

## 1. Przepływ gry i sceny

```
Boot (autoloady) → MainMenu → [Nowa gra | Kontynuuj] → Museum (gra) ⇄ PauseMenu
                                                    → DeathScreen → nowa noc (Museum reload)
                                                    → DemoEnd (po T-Reksie) → MainMenu
```

| Scena | Plik | Opis |
|---|---|---|
| Menu główne | `src/ui/main_menu.gd` + `.tscn` (scena główna projektu) | tytuł, „Kontynuuj” (gdy jest zapis), „Nowa gra” (potwierdzenie nadpisania), „Opcje”, „Wyjście”. Tło: widok z kamery na ciemny hol (od etapu 2b), wcześniej ciemny gradient |
| Gra | `src/game/museum.gd` + `.tscn` | buduje poziom, strażnika, HUD, uruchamia `NightDirector`, obsługuje śmierć i koniec nocy |
| Pauza | `src/ui/pause_menu.gd` | Esc: „Wznów”, „Opcje”, „Wyjdź do menu”. `get_tree().paused = true`; HUD i menu mają `process_mode = ALWAYS` |
| Opcje | `src/ui/options_menu.gd` | czułość myszy, odwrócenie osi Y, pole widzenia (70–110°), głośność: ogólna/efekty/muzyka, pełny ekran, V-Sync, limit klatek, skala renderu (FSR 2 lub zwykła); zapis w `settings.cfg` |
| Ekran śmierci | część `museum.gd` + `src/ui/death_screen.gd` | wyciemnienie 1,2 s, tekst „23:00”, dźwięk budzika, wczytanie nowej nocy |
| Koniec dema | `src/ui/demo_end.gd` | statystyki (noce, śmierci, czas, zebrany Pył, sekrety x/6), „Dziękujemy za grę”, powrót do menu |

Piaskownica z 1a zostaje jako tryb deweloperski (`src/arena/sandbox.tscn`, uruchamiana z `tools/`), nie jest już sceną główną.

## 2. Stan gry

### 2.1 `GameState` (autoload, trwały)

| Pole | Typ | Opis |
|---|---|---|
| `night` | int | numer nocy (od 1) |
| `seed_base` | int | losowane raz przy nowej grze; ziarno nocy = hash(`seed_base`, `night`) |
| `upgrades` | Dictionary[StringName,int] | poziom każdego ulepszenia |
| `weapons` | Array[StringName] | znalezione bronie (`pistol`, `shotgun`); pięści i paralizator zawsze |
| `pistol_key` | bool | czy klucz do szafki był już znaleziony (szafka otwarta na zawsze) |
| `secrets` | Array[StringName] | odkryte sekrety |
| `notes` | Array[StringName] | przeczytane notatki |
| `havens` | Array[StringName] | odkryte przystanie (`security` zawsze, `closet` po odkryciu) |
| `start_haven` | StringName | gdzie zaczyna się noc (ostatnia odwiedzona przystań) |
| `lantern` | Dictionary | `{active, position:[x,y,z], dust}` — upuszczony Pył |
| `stats` | Dictionary | `deaths`, `nights`, `dust_earned`, `play_time`, `bosses` |
| `demo_complete` | bool | T-Rex pokonany |
| `night_progress` | Dictionary | noc w toku przy ostatnim zapisie: `{night, killed: [indeks slotu], taken: [indeks miejsca łupu], used: [id], guard: {health, weapons}}` — „Kontynuuj” wznawia noc (zniszczone eksponaty i zabrany łup nie wracają, strażnik ma swoje zdrowie i amunicję); śmierć ją czyści |

API: `new_game()`, `load_game() -> bool`, `save_game()`, `has_save() -> bool`, `night_seed() -> int`, `upgrade_level(id) -> int`, `buy_upgrade(id, run: RunState) -> bool`.

**Zapis:** JSON, wersjonowany (`"version": 1`, z miejscem na migrację starszych wersji). Ścieżka (zasada „wszystko na D:”, nic w `%APPDATA%` na C:): w wersji wyeksportowanej `<katalog exe>/save/` (`save.json`, `settings.cfg`, `logs/godot.log`), przy uruchomieniu binarką edytora (Graj.bat, narzędzia) `tools/godot/editor_data/nz_save/`, w testach i scenariuszach `tests/_out/saves`; `--save-dir=<folder>` / `NZ_SAVE_DIR` wskazują inny folder. Folder użytkownika Godota nie jest używany: log silnika jest wyłączony (gra pisze własny log obok zapisu), wersja wyeksportowana nie trzyma pamięci podręcznej shaderów ani potoków, narzędzia i Graj.bat kierują `APPDATA` do `tools/godot/editor_data/appdata`, a puste `%APPDATA%\Nocna Zmiana`, które silnik zakłada przy każdym starcie, gra od razu usuwa. Jedyny wyjątek: folder gry bez prawa zapisu (Program Files, uruchomienie z wnętrza ZIP-a) — wtedy `%APPDATA%\Nocna Zmiana`. Zapis bezpieczny: `save.json.tmp` (odczytany i porównany) → stary plik jako `save.json.bak` → rename (ponawiany); odczyt próbuje `save.json` → `.tmp` → `.bak`. Uszkodzony plik → przeniesiony jako `save.json.bad` i nowa gra (tylko gdy przeniesienie się udało); plik nieczytelny albo z nowszej wersji gry zostaje nietknięty, menu pokazuje komunikat. Nieudany zapis → ostrzeżenie w HUD.

**Kiedy zapis:** wejście do przystani (najwyżej raz na 30 s), zakup ulepszenia, znalezienie broni, śmierć, pokonanie bossa, wyjście do menu, zamknięcie okna.

### 2.2 `RunState` (autoload, stan jednej nocy)

`dust` (niesiony Pył), `artifacts: Array[StringName]`, `modifier: StringName`, `fuses: int` (0–2 włożone), `fuses_carried: int`, `crystal_phase` (DORMANT → PULSING → FLYING → EMBEDDED → BROKEN), `rng: RandomNumberGenerator`, `time: float`. `begin_night(seed)`, `add_dust(n)` (uwzględnia mnożniki), `has_artifact(id)`.

### 2.3 Co przeżywa śmierć

| Traci się | Zostaje |
|---|---|
| niesiony Pył → trafia do latarki w miejscu śmierci; poprzednia niepodniesiona latarka **przepada** | ulepszenia, bronie, klucz, sekrety, notatki, przystanie |
| artefakty, bezpieczniki, stan kryształu, amunicja ponad start | numer nocy rośnie o 1 |

Start nocy: pełne zdrowie i wytrzymałość; amunicja startowa: pistolet 12+24, strzelba 2+6.

## 3. Pył i ekonomia

| Źródło | Pył |
|---|---|
| figura woskowa | 3 |
| wilk | 4 |
| popiersie | 5 |
| rycerz | 8 |
| dobicie pięścią | ×1,5 (zaokrąglone w górę) |
| pełnia | ×1,5 |
| Moneta z fontanny | ×1,5 (mnoży się z pełnią) |
| T-Rex | 100 |

Pył wypada jako 1–4 świecące drobiny (`DustMote`), które po 0,6 s lecą do strażnika w promieniu 6 m (magnes) i znikają po 30 s. HUD pokazuje licznik z krótką animacją „+n”.

**Ulepszenia (16):**

| id | Nazwa | Poziomy | Ceny | Efekt na poziom |
|---|---|---|---|---|
| `health` | Kondycja | 3 | 25 / 50 / 90 | +20 max zdrowia |
| `stamina` | Wytrwałość | 3 | 20 / 45 / 80 | +20 max, +15% regeneracji |
| `battery` | Bateria latarki | 2 | 20 / 45 | +50% czasu świecenia |
| `fists` | Twarde pięści | 2 | 25 / 55 | +40% obrażeń pięści, +25% leczenia z dobicia |
| `taser_charge` | Szybsze ładowanie | 1 | 40 | ładowanie ×1,6 |
| `taser_chain` | Przeskok łuku | 1 | 70 | łuk przeskakuje na 2. wroga w 5 m |
| `pistol_damage` | Amunicja wzmocniona | 1 | 50 | +30% obrażeń |
| `pistol_mag` | Powiększony magazynek | 1 | 40 | magazynek 18 |
| `shotgun_spread` | Dławik | 1 | 50 | rozrzut −35% |
| `shotgun_slug` | Pocisk „slug” | 1 | 80 | alternatywna amunicja: przeładowanie z przytrzymaniem R przełącza śrut/slug; slug = 1 promień × 70, słaby punkt ×2 |

Suma: ok. 800 Pyłu na wszystko (dokładnie 785); jedna noc przy dobrej grze daje 120–220 Pyłu, więc pełne ulepszenie to 4–7 nocy. Ulepszenia broni działają przez **kopię** `WeaponData` (`duplicate()`) z modyfikatorami — zasoby `.tres` nigdy nie są zmieniane w czasie gry.

## 4. Interakcja, przystanie, latarka strażnika

- Nowa akcja `interact` (klawisz **E**). `Interactable` (Area3D w warstwie `INTERACT` = 64) z `prompt: String` i `interact(player)`. Strażnik co klatkę rzuca promień 2,2 m ze środka ekranu; HUD pokazuje „[E] Podnieś bezpiecznik”.
- **Przystań** (`Haven`): strefa, której wejście zapisuje grę i odnawia zdrowie — najwyżej raz na 30 s nocy (start nocy w przystani liczy się jako odpoczynek), żeby wchodzenie i wychodzenie w drzwiach nie było stacją leczenia. W środku broń jest opuszczona (bez strzałów i ciosów): przystań to schronienie, nie wieżyczka. W niej: **terminal ulepszeń** (interakcja → menu z listą, ceną, opisem, blokadą gdy za mało Pyłu), wróg nie wchodzi (drzwi przystani zamykają się za graczem? nie — wrogowie po prostu mają zakaz wejścia: przystań to region nawigacji z flagą „tylko gracz”).
- **Szafka na broń** w kanciapie: zamknięta, dopóki `pistol_key` nie jest znaleziony; po otwarciu pistolet leży w środku raz na zawsze (kolejne noce — pistolet już jest w ekwipunku).
- **Latarka strażnika** (`DroppedLantern`): leży w miejscu śmierci (ostatnia bezpieczna pozycja na podłodze, nie w przepaści), świeci ciepło, widoczna przez mgłę; dotknięcie zwraca Pył. Pojawia się na monitorze CCTV.
- **Latarka gracza dostaje baterię:** 120 s świecenia, ładuje się 2× wolniej niż się rozładowuje, gdy wyłączona; przy <15% miga. Pasek pod paskiem wytrzymałości.

## 5. Lobby — układ (metry; Y w górę, −Z = północ, środek holu = 0,0,0)

```
                         N (−Z)
        ┌────────────── BALKON y=6 (W, N, E; 4 m głęb.) ──────────────┐
        │   [Składzik na miotły 4×3, ukryty, za fałszywym panelem N]   │
 ┌──────┴──────┐  ┌──────────── HOL GŁÓWNY 36×44, sufit 14 ────────────┐  ┌──────┴──────┐
 │ GALERIA     │  │  krata do podziemi (N, 6×5) + skrzynka bezpieczn.  │  │ ZBROJOWNIA  │
 │ RZEŹBY      ├──┤  T-Rex na postumencie 12×6 (środek-N)              ├──┤             │
 │ 20×28, h7   │  │  schody W i E wzdłuż ścian, z z=+6 do z=−6         │  │ 20×28, h7   │
 │ bezp. A     │  │  kasa biletowa (SW), informacja (środek-S)          │  │ bezp. B     │
 └──────┬──────┘  └─────────────────────┬──────────────────────────────┘  └──────┬──────┘
        │ korytarz techniczny W          │ drzwi S (4 m)                korytarz techn. E │
        └──────────────┐   ┌─────────────┴──────────────┐   ┌──────────────────────┘
                       └───┤ DIORAMA PRZYRODY 28×20, h8 ├───┘
                           └─────────────┬──────────────┘
                                korytarz służbowy (3×10)
                           ┌─────────────┴──────────────┐
                           │ KANCIAPA OCHRONY 10×8, h3  │  start, przystań #1
                           └────────────────────────────┘
```

| Pomieszczenie | Prostokąt (x0,z0 → x1,z1) | Podłoga / sufit | Zawartość |
|---|---|---|---|
| Hol główny | (−18,−22) → (18,22) | 0 / 14 | T-Rex (postument (−6,−14)→(6,−8), h 1,2), krata N w (0,−22) szer. 6, skrzynka bezpieczników (4,−21,5), kasa (−13,14)→(−8,19), lada informacji (−4,6)→(4,9), 4 kolumny (±10, ±8), ławki; świetliki w dachu (3 pasy) |
| Balkon | pas 4 m wzdłuż W, N, E na y=6, balustrada 1,1 m | 6 / 14 | wejście z dwóch schodów; na N za panelem składzik |
| Schody | W: (−17,6)→(−13,−6) wznoszą się na północ; E symetrycznie | 0 → 6 | szer. 4 |
| Galeria rzeźby | (−40,−14) → (−20,14) | 0 / 7 | drzwi do holu (−18/−20, z=0, szer. 4); cokoły z popiersiami (osłony), bezpiecznik A na końcu W, 1 gablota kandydata na kryształ, obraz z przejściem (sekret) |
| Zbrojownia | (20,−14) → (40,14) | 0 / 7 | drzwi do holu (18/20, z=0); stojaki na zbroje (osłony), bezpiecznik B, **ukryta gablota ze strzelbą** za fałszywą ścianą z tabliczką (sekret), 1 gablota kandydat |
| Diorama przyrody | (−14,24) → (14,44) | 0 / 8 | drzwi do holu (0,22 szer. 4); wybiegi z „trawą”, skały (osłony), 1 gablota kandydat, szyb wentylacyjny (sekret) |
| Korytarz tech. W | (−34,14)→(−30,30) + (−30,26)→(−14,30) | 0 / 3,5 | łączy galerię z dioramą (pętla) |
| Korytarz tech. E | symetrycznie | 0 / 3,5 | łączy zbrojownię z dioramą |
| Korytarz służbowy | (−1,5,44) → (1,5,54) | 0 / 3 | dioramę z kanciapą |
| Kanciapa | (−5,54) → (5,62) | 0 / 3 | krzesło (spawn), terminal ulepszeń, szafka z pistoletem, ściana monitorów CCTV |
| Składzik | (−2,−26) → (2,−23) na y=6 | 6 / 9 | przystań #2; wejście: fałszywy panel na balkonie N (interakcja) |

**Pętle i wymuszanie tras:** trzy drogi między dioramą a skrzydłami (przez hol, przez korytarz W, przez korytarz E). `NightDirector` zamyka co noc 0–1 drzwi z listy `lockable` (drzwi korytarzy tech. i drzwi hol↔skrzydło), zawsze sprawdzając w grafie pomieszczeń, że każdy cel pozostaje osiągalny. Klucz woźnego (artefakt) otwiera zamknięte drzwi.

**Sekrety (6):** (1) przejście za obrazem w galerii → mała komnata z artefaktem, (2) szyb wentylacyjny w dioramie → wyjście na balkon holu, (3) fałszywa ściana z tabliczką w zbrojowni → gablota ze strzelbą, (4) zamknięta gablota w holu (otwiera ją… dobicie rycerza leżącego obok? nie — klucz woźnego lub strzał w kłódkę) → artefakt, (5) notatki strażników ×3 (lore/humor; znalezienie wszystkich = sekret), (6) składzik na miotły. Odkrycie sekretu: dźwięk + napis „Sekret odkryty (n/6)”.

**Klucz do szafki z pistoletem:** w szufladzie kasy biletowej (interakcja). Noc 1 prowadzi do niego notatka na biurku w kanciapie („Klucz od szafki zostawiłem w kasie. — Heniek”).

## 6. `NightDirector` — losowanie nocy

Wejście: ziarno nocy. Wyjście: deterministyczna konfiguracja nocy.

1. **Modyfikator:** noc 1 = brak; dalej losowo `none` 40%, `blackout` 20%, `full_moon` 20%, `calm` 20%.
2. **Kryształ:** jedna z 4 gablot-kandydatów (galeria, zbrojownia, diorama, hol).
3. **Drzwi:** 0–1 zamknięte (patrz wyżej), noc 1 = żadne.
4. **Spotkania:** każde pomieszczenie ma 2–3 zestawy (`EncounterSet`: lista punktów spawnu z typem i flagą „uśpiony/patrol”). Losuje się jeden zestaw na pomieszczenie. `calm` → z każdego zestawu zostaje ~60% wrogów.
5. **Łupy:** punkty łupów (`LootSpot`) w pomieszczeniach; 60% z nich dostaje amunicję/apteczkę wg wag; 2–3 artefakty w losowych pojemnikach (gabloty, sarkofag, komnata sekretna ma artefakt zawsze).
6. **Bezpieczniki:** zawsze w galerii (A) i zbrojowni (B), ale w jednym z 2 punktów każdego skrzydła.

Test: ta sama liczba → identyczny słownik konfiguracji; 200 ziaren → każdy cel osiągalny w grafie.

## 7. Cel nocy

1. **Bezpieczniki:** podniesienie = `RunState.fuses_carried++`, ikona w HUD. Skrzynka przy kracie (interakcja) wkłada wszystkie niesione. Po 2: dźwięk przekaźnika, **gaśnie główne światło holu** (zostają awaryjne czerwone + księżyc), krata unosi się o 40 cm i zacina się, kryształ przechodzi w PULSING.
2. **Kryształ pulsuje:** czerwone światło punktowe w gablocie, dźwięk „bicia serca” słyszalny z 25 m, jego obraz na monitorze CCTV; cel w HUD „Znajdź źródło pulsowania”.
3. **Podejście** (3 m): gablota pęka, kryształ unosi się i leci ścieżką (lista punktów przez drzwi do holu) z prędkością 6 m/s, zatrzymując się, gdy gracz jest dalej niż 14 m (czeka), zostawia świetlistą smugę (`GPUParticles3D` z trail).
4. **Wbicie:** kryształ wlatuje między żebra T-Reksa, ekran drży, ryk, T-Rex budzi się → walka.

## 8. Nowi wrogowie

### 8.1 Lewitujące popiersie (`bust`)

| Parametr | Wartość |
|---|---|
| Zdrowie | 45; słaby punkt: twarz ×2 |
| Ruch | lewituje 1,6 m nad podłogą, bujanie ±0,15 m; utrzymuje dystans 8–14 m od gracza, cofa się, gdy gracz bliżej niż 6 m; 3,0 m/s |
| Atak | zapowiedź 0,7 s (pęka od środka, żarzy się), wystrzeliwuje **jeden** odłamek marmuru: pocisk 9 m/s, 12 obrażeń, widoczny (jasny, ze smugą), co 2,4 s |
| Ogłuszenie | paralizator: spada na ziemię na 3 s (można dobić) |
| Rozpad | marmur: pęka na kanciaste odłamki |
| Pył | 5 |

Wymaga nowego elementu: `Projectile` (węzeł z prędkością, promieniem trafienia, `DamageInfo`, zniszczenie o ścianę z efektem). Pociski można zestrzelić (hurtbox 0,25 m, 1 trafienie).

### 8.2 Szkielet T-Reksa (boss, `TRex`)

| Parametr | Wartość |
|---|---|
| Rozmiar | ok. 11 m długości, 5 m wysokości; kapsuła kolizji tułowia + kolizja ogona (Area3D do ataku) |
| Zdrowie | 1200; **tylko kryształ** (hurtbox między żebrami, ×1) zadaje pełne obrażenia; kości przyjmują 10% (iskry/odpryski kości, szary znacznik) |
| Faza 1 (100–66%) | krok 3,5 m/s; **szarża** (zapowiedź 1,0 s: grzebie łapą, ryk; bieg 14 m/s po prostej; uderzenie w ścianę → ogłuszenie 2,5 s, kryształ wysunięty i świeci mocniej = okno na obrażenia ×1,5); **ogon** gdy gracz za nim w 7 m (zapowiedź 0,6 s, 25 obr., duży odrzut) |
| Faza 2 (66–33%) | szybszy (4,5 m/s), szarża co ~6 s, **ryk** budzi 4 figury woskowe z puli holu (co 20 s, max 6 żywych) |
| Faza 3 (<33%) | ryk zrzuca z sufitu gruz (3 znaczniki cienia na podłodze, 1 s zapowiedzi, 20 obr.), dwie szarże pod rząd |
| Paralizator | na kryształ: potknięcie 1 s (odnowienie 8 s) |
| Śmierć | kryształ pęka, szkielet rozsypuje się na kości (fizyczne odłamki), krata do podziemi otwiera się w pełni, za nią schody w ciemność → wejście = koniec dema |
| Pył | 100 |

Hol musi dawać przestrzeń: postument T-Reksa „zjeżdża” (T-Rex zeskakuje), kolumny są osłoną przed szarżą (szarża w kolumnę = ogłuszenie).

## 9. Oświetlenie i modyfikatory

- Hol: ciepłe lampy na kolumnach (wyłączalne grupą `main_lights`), czerwone lampy awaryjne (zawsze), księżyc (`DirectionalLight3D` przez świetliki) + mgła wolumetryczna.
- `blackout`: grupa `main_lights` wyłączona od startu w całym lobby, ambient ×0,3; latarka i bateria stają się kluczowe.
- `full_moon`: księżyc ×1,6, niebieskawy odcień, wrogowie +25% zdrowia i obrażeń, Pył ×1,5.
- `calm`: 60% wrogów, cichsza muzyka.

## 10. HUD i UI — dodatki

Pył (prawy górny róg), cel nocy (lewy górny: „Bezpieczniki 1/2”, „Znajdź pulsowanie”, „Pokonaj strażnika holu”), ikony artefaktów, pasek baterii latarki, podpowiedź interakcji (środek-dół), komunikaty (sekret, notatka — notatka otwiera się w czytelnym oknie z tekstem), pasek zdrowia bossa (góra środek). Wszystkie teksty przez `tr()` z pliku `locale/strings.csv` (kolumny `keys,pl,en`; angielski może na razie powtarzać polski — pełne tłumaczenie w etapie szlifu).

## 11. Audio

Szyny: `Master` → `Music`, `SFX`, `Ambience`, `UI`. Suwaki głośności sterują szynami. Nowe dźwięki (generator z 1a rozszerzony): Pył (dzwoneczek), bezpiecznik, przekaźnik, bicie serca kryształu, ryk T-Reksa, kroki T-Reksa, odłamek marmuru, popiersie (zgrzyt kamienia), budzik, drzwi (otwarcie/zamknięte), interakcja, sekret, zakup ulepszenia. Tło: szum budynku (niski, pętla), odległe skrzypienia (losowe). Muzyka (etap 3): ambient eksploracji + utwór walki z bossem.

## 12. Podział na podplany i kolejność

| Podplan | Zakres | Uwaga |
|---|---|---|
| **2a — pętla nocy** (systemy) | GameState/RunState/zapis, Settings + opcje + szyny audio, `tr()` + CSV, menu główne/pauza/śmierć, interakcja, Pył + magnes + HUD, latarka strażnika, bateria latarki, przystań + terminal ulepszeń + 16 ulepszeń, sceny i przepływ; wszystko najpierw na arenie piaskownicy | nic z lobby |
| **2b — lobby** | `LevelBuilder` (dane → bryły, drzwi, schody, balustrady, świetliki), układ lobby, drzwi (otwarte/zamknięte/fałszywe panele), nawigacja (runtime bake + `NavigationAgent3D` w `Enemy`), `EncounterSet`/`LootSpot`, `NightDirector`, modyfikatory i światła, szafka z pistoletem + klucz, strzelba w ukrytej gablocie, sekrety i notatki, składzik, CCTV, artefakty (6) | `Museum` staje się grą |
| **2c — cel nocy i boss** | `Projectile`, popiersie, bezpieczniki + skrzynka + zgaszenie świateł, sekwencja kryształu, T-Rex (3 fazy), krata i koniec dema, balans, scenariusze pełnej nocy | koniec MVP (wersja szara) |

Po 2c: **etap 3 — oprawa** (w tym próbka stylu 1b jako pierwszy krok): modele i tekstury z Blendera, światło (GI, mgła, odbicia), dźwięk i muzyka. Potem **szlif wydania** (samouczek, balans, wydajność, prekompilacja shaderów, lokalizacja EN, ustawienia grafiki, poprawki).

## 13. Testy etapu 2 (bez okna, obowiązkowe)

- zapis → odczyt daje identyczny stan; uszkodzony plik nie wysypuje gry,
- śmierć: Pył trafia do latarki, stara latarka przepada, podniesienie zwraca Pył,
- zakup ulepszenia: cena, blokada przy braku Pyłu, efekt na kopii danych broni, `.tres` nietknięte,
- `NightDirector`: determinizm, osiągalność celów dla 200 ziaren, noc 1 bez modyfikatora i bez zamkniętych drzwi,
- nawigacja: wróg dociera do gracza przez drzwi i po schodach na balkon,
- sekwencja celu: 2 bezpieczniki → światła gasną → kryształ PULSING → podejście → FLYING → EMBEDDED → boss aktywny,
- boss: obrażenia tylko przez kryształ (kości 10%), fazy przy progach, śmierć → krata otwarta → `demo_complete`.

## 14. Wymagania z przeglądów kodu etapu 1a (do uwzględnienia w 2b/2c)

- **Nawigacja przy istniejącej siatce:** gdy mapa ma regiony nawigacji, wróg nie idzie „na wprost” do gracza poza siatką — czeka na końcu ścieżki. Przystanie wyłączone z nawigacji wrogów przez `navigation_layers`.
- **Schody:** wizualne stopnie osobno, kolizja jako niewidoczna rampa (strażnik i wrogowie nie pokonują stopni ≥ 0,15 m). Siatka nawigacji z komórką 0,1 m i wspinaczką ≤ 0,1 m.
- **Próg śmierci (kill plane)** pod poziomem + limit prędkości spadania; wróg poniżej progu jest niszczony z sygnałem `enemy_destroyed` (logika „sala oczyszczona” się nie zawiesza).
- **Tłum 20–40 wrogów:** unikanie (`avoidance_enabled` + `velocity_computed`) albo proste rozpychanie; atakujący wręcz zajmują punkty na okręgu wokół gracza; losowe przesunięcie timerów ścieżki i wzroku (część już w poprawkach 1a).
- **Popiersie:** grawitacja tylko gdy ogłuszone; strzał dystansowy korzysta z testu linii wzroku.
- **T-Rex:** własna warstwa/promień nawigacji lub ruch bez siatki; zasięg ataku liczony do powierzchni kolizji, nie od środka.
- **Mysz i pauza:** jeden właściciel przechwytywania kursora (menu pauzy); ruch też blokowany, gdy kursor wolny.
- **Zapisy:** `user://` domyślnie trafia do `%APPDATA%` — w wersji wyeksportowanej zapis obok exe (patrz 2.1).
- **Tryb okna:** F11 z piaskownicy nie może walczyć z menu opcji — właścicielem trybu okna są Opcje.
