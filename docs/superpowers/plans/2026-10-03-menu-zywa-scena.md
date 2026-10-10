# Menu główne na żywo — kamera nad Wielkim Dziedzińcem (plan wykonawczy)

> **Dla wykonawcy:** zadania po kolei, commit po każdym. Gałąź `menu-scene` (od `pietro-1`). Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2 pkt 1 i §9.3.

**Cel:** pierwszy ekran gry to żywa scena: wystrojone Piętro I (bez eksponatów, strażnika i systemów gry), nad którym kamera sunie powoli przez cztery ręcznie ułożone ujęcia — szklany dach z cieniami kratownicy we mgle, bęben Czytelni, T-Rex w półmroku, rzut oka w dół galerii egipskiej. Na wierzchu menu (tytuł, podtytuł, wpisy, wersja), czytelne dzięki miękkiemu gradientowi. Właściciel ma być **pozytywnie zaskoczony**, a menu — tanie i odporne.

## Architektura

- `MenuRail` (`src/ui/menu_rail.gd`, czysta logika, `RefCounted`): ujęcia (`Shot`) z punktami kontrolnymi oka i celu; ścieżka **Catmull-Rom** parametryzowana długością łuku (stała prędkość), łagodne wejście/wyjście (`ease`), poprawka kadru (cel w prawej części ekranu, bo menu zajmuje lewą), powolne „drżenie z ręki” (suma sinusów, bez losowości). Testowalna bez sceny.
- `MenuStage` (`src/ui/menu_stage.gd`, `Node3D`): buduje `MuseumFloorLevel` w oprawie (`art = true`, bez nawigacji, zamek z tej samej pamięci podręcznej powłoki co gra), dostawia uśpionego T-Rexa na cokole, kamerę, pętlę ujęć z przyciemnieniem między nimi, życie otoczenia (kurz w snopach księżyca przy kamerze, odległa lampa mrugająca raz na jakiś czas, księżyc przesłaniany cienką chmurą), czujnik wydajności. Pokoje poza dziedzińcem, holem wejściowym i przedsionkiem/galerią Egiptu wyłącza **istniejący `RoomCuller`** (nowe pole `only_rooms`).
- `MainMenu`: układ interfejsu przebudowany pod żywą scenę (gradient po lewej i u dołu, podtytuł „Piętro I — Wielki Dziedziniec”, etykieta wersji „Wersja demonstracyjna · Piętro I”). Statyczne tło zostaje jako **zastępnik**: ekran startuje na nim (ciemny), scena buduje się po kilku klatkach (budowa jest synchroniczna), po rozgrzaniu shaderów statyczne tło wygasa i wchodzi 3D.
- **Zastępnik:** budowa zawiodła (wyjątek, brak modeli = bez oprawy), trwała dłużej niż 8 s albo klatki są wolniejsze niż ok. 14 FPS przez 2 s → scena jest zwalniana, zostaje statyczne tło (przy opadnięciu wydajności płynnie wraca).
- Wydajność: preset grafiki z ustawień (ten sam co w grze: SDFGI, mgła, cienie lamp, drobiny), culler trzyma włączone lampy, mgłę, sondy i drobiny tylko w pokojach menu (dziedziniec, Czytelnia, balkon, hol wejściowy, przedsionek i galeria Egiptu) i najwyżej jedno przejście od kamery — galeria jest o jedno przejście od przedsionka, skąd patrzy ujęcie 4, więc wystarcza na każdym presecie. Rozgrzewka przed odsłonięciem rysuje każde ujęcie w trzech momentach (shadery, światła). Czujnik klatek patrzy na **medianę** (zacięcia kompilacji shaderów nie liczą się).

## Ujęcia (współrzędne świata, −Z = północ, początek w środku dziedzińca)

| # | Nazwa | Ruch | Pokazuje |
|---|---|---|---|
| 1 | `lattice` | z SW rogu pod dachem w głąb dziedzińca, kamera unosi się w stronę szkła | księżycowe słupy w mgle, cienie kratownicy, bęben w tle |
| 2 | `drum` | łuk R = 17 m od wschodu przez południe, wzdłuż ściany bębna | oświetlone od dołu ściany bębna, spiżowy portal, latarnie |
| 3 | `trex` | od wschodu do północnego wschodu, lekko w górę | szkielet T-Rexa na cokole w półmroku, ciepły punkt i księżycowa plama |
| 4 | `egypt` | z dziedzińca przez drzwi do przedsionka, skręt w łuk i w dół nawy | Kamień z Rosetty, rząd kolosów w reflektorach, długa perspektywa |

Między ujęciami ~0,9 s przyciemnienia (cięcie ukryte w czerni). Pętla ok. 80 s.

## Zadania

- [x] **1. `RoomCuller.only_rooms`** + test: pokoje spoza zbioru zawsze wyłączone, niezależnie od odległości kamery.
- [x] **2. `MenuRail`** + `tests/unit/test_menu_rail.gd`: ścieżka ciągła (krok < limitu, brak NaN), przechodzi przez punkty kontrolne, stała prędkość, ease monotoniczny, drżenie ograniczone i ciągłe.
- [x] **3. `MenuStage`** + `tests/integration/test_menu_stage.gd`: buduje się bez błędów headless (szaro i w oprawie), T-Rex na cokole, culler tnie pokoje poza zbiorem, wszystkie ujęcia w pokojach i poza ścianami, cel w zasięgu wzroku, zastępnik przy braku oprawy i przy przekroczeniu budżetu.
- [x] **4. `MainMenu`**: układ, napisy (`strings.csv` tylko dopisywane: `MENU_SUBTITLE`, `MENU_VERSION_FLOOR1`), pętla zastępnika, test wpisów i ścieżki zastępczej.
- [x] **5. Scenariusz** `tests/scenarios/menu_scenario.*` + `tools/run_menu_shots.sh` (`shots` w ciche okno, `dry` bez okna): zrzuty ujęć z interfejsem, kontrola ścieżek na zbudowanym piętrze.
- [ ] **6. Scalenie `pietro-1`, pełny zestaw testów** (zero linii `ERROR`), raport.

## Poza zakresem

Dźwięk (muzyka MENU „Nokturn dozorcy” idzie przez `AudioContext` jak dotąd), nowe opcje (kołysanie widoku — gdy powstaną opcje dostępności, §9.3, drżenie podepnie się pod nie), wystrój skrzydeł innych niż Egipt.
