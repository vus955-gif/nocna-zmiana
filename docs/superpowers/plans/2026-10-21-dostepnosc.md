# Dostępność (21.10.2026)

> Gałąź `accessibility` (z `pietro-1` @0b0552aa, worktree `qa-sweep`). Zakres: rozmiar HUD, napisy, ograniczenie błysków,
> paleta dla daltonistów, sprint przełączany. **Bez celowania wspomaganego** (nie było w zakresie). Przysiad w grze nie istnieje.
> Zasady sesji: tylko `--headless`, bez okien i dźwięku (w trybie nocnym okna tylko przez `tools/agents/with_window.sh`), nic na GitHub.

## 0. Opcje (wszystkie w `SettingsData`, zapisywane w `settings.cfg`, stary plik ładuje domyślne)

| Klucz | Typ / zakres | Domyślnie | Gdzie w menu | Zastosowanie |
|---|---|---|---|---|
| `hud_scale` | 0,75–1,5, krok 0,05 | 1,0 | Dostępność | na żywo: `Hud.apply_scale()` |
| `subtitle_size` | mały / średni / duży | średni | Dostępność | na żywo: `SubtitleBar` |
| `subtitle_backing` | 0–1, krok 0,05 | 0 (brak) | Dostępność | na żywo: ciemny pas pod napisem |
| `reduce_flashing` | bool | wyłączone | Dostępność | czytają `Flashing` i źródła błysków (§3) |
| `colour_vision` | standardowa / deuteranopia / protanopia / tritanopia | standardowa | Dostępność | `ColourVision` (§4) |
| `sprint_toggle` | bool | wyłączone | Sterowanie | `Player._wants_sprint()` (§5) |

Każdy klucz ma wiersz w `OptionsMenu` (test „każde ustawienie ma wiersz”) i teksty PL/EN w `locale/strings.csv` (`OPT_*`).

## 5. Sprint przełączany (zrobione)

Przytrzymanie (domyślnie) bez zmian. Przy `sprint_toggle` jedno naciśnięcie (`GameInput.fresh_press`) włącza sprint, kolejne
wyłącza. Przełącznik spada: gdy skończy się wytrzymałość lub broń zabrania sprintu (nie wraca sam po odpoczynku), gdy menu
przejmie sterowanie, po `Player.SPRINT_IDLE_GRACE` (0,4 s) bez kroku (Shift tuż przed W nadal działa), przy wyłączeniu opcji i
po respawnie. Sprint nie rusza gracza w miejscu — przełącznik czeka na ruch. Przysiadu w grze nie ma, więc nie ma jego opcji.

## 1. Rozmiar HUD (zrobione)

`Hud` jest `CanvasLayer` ze `scale = hud_scale`; korzeń (`_root`) ma rozmiar `canvas_size()` = obszar widoku / skala, więc cały układ
liczy się nadal w „jednostkach HUD”. Krawędzie oddawane innym warstwom (`top_left_bottom`, `top_middle_bottom`, `hint_clearance`,
nowe `bottom_clearance`) są w jednostkach płótna (×skala). Poprawki układu wymuszone przez małe płótno (150 % na 1920×1080 = 1280×720):
karta nocy zawsze pod stosem (boss/toast/karta pokoju), pasek podpowiedzi podnosi się nad narożne tabliczki, gdy by w nie wszedł
(`_hint_bottom`), napisy podnoszą się nad tabliczki narożne (`SubtitleBar._place`). Testy: `test_hud_scale` (wszystkie skale × 4 okna:
na ekranie, bez nakładania, F1, napisy, narożniki), `test_hud_layout` i `test_hud_style` biegną na każdej skali (0,75–1,5).

## 2. Napisy (zrobione)

`subtitle_size` (`SubtitleBar.SIZES`: 22/26/38 pt, szerokość 960/1100/1500), `subtitle_backing` (czarny pas `BACKING_PAD` wokół
tabliczki, alfa ≤ `BACKING_ALPHA`); na żywo. Mówca: kolor **i** nazwa na tabliczce (HENIEK / SYSTEM / PRZEWODNIK, każda inna, test).
Kontrast: tabliczka sama > 4,5:1 na białym marmurze, z pełnym tłem > 7:1.

## 3. Ograniczenie błysków (zrobione)

Klasa `Flashing` (`src/core/flashing.gd`) + opcja `reduce_flashing`. Limity: najwyżej 3 błyski na sekundę (WCAG 2.3.1; `Flashing.Gate`),
lampa nie spada poniżej 50 %, błysk światła 50 %, biały błysk trafienia najwyżej 0,4, czerwone brzegi trafienia najwyżej 0,5, puls ×0,5.
Podpięte: `LampFlicker` (rury w piwnicy), `Fx.flash` (krótkie błyski do 0,2 s ograniczane w czasie, długie tylko przyciemniane),
`MuzzleFx` (gwiazda), błysk trafienia w shaderze (8 rigów), `Hud` (czerwone brzegi, alarm latarki stały zamiast mrugania),
`HudGauge` (puls niskiego zdrowia), latarka z niskim akumulatorem, lampa menu głównego, oczy Generała i ostrzeżenie Orrery (stałe).
**`RoomLamps` (lampy sal, eskalacja nocy) — zrobione 22.10.** Każdy spadek (zrzut migotania, mrugnięcie, zająknięcie powrotu po
zgaśnięciu, lampa „przejścia”, mrugnięcie znaku WYJŚCIE) pyta przed startem **jedną bramkę `Flashing.Gate` na efekt** (wszystkie jego
lampy; sala gra naraz jeden efekt, a `UncannyDirector.MIN_GAP` 8 s między zdarzeniami jest dłuższy od najdłuższego efektu lamp 6 s), więc
sala miga najwyżej 3 razy na sekundę bez względu na liczbę lamp (wcześniej limit 4/s dotyczył jednej lampy, a 6 lamp naraz dawało
znacznie więcej); spadek odrzucony przez bramkę się nie odbywa (lampa świeci). Głębokość przez `Flashing.lamp_level()` (≥ 50 %), przy
włączonej opcji spadki nie gaszą opraw (blask zostaje; inaczej oprawa skakałaby 100 → 0 %). Drżenie przygaszenia przez `Flashing.pulse()`.
Samo zgaśnięcie (`out`) i powolne przygaszenie do 30 % zostają: to zdarzenie i spadek trwający sekundę lub dłużej, nie błysk; powrót po
zgaśnięciu liczy się w bramce jako zmiana (zostaje z zająknięcia jeden spadek). Testy w `test_room_lamps`: z opcją każdy tryb ≤ 3 spadki sali
na sekundę, odstęp ≥ `MIN_GAP`, światło ≥ 50 % (poza samym zgaśnięciem), oprawy i znak WYJŚCIE świecą dalej, zgaśnięcie nadal gasi oprawy;
bez opcji sala migocze jak dawniej (> 3/s, głęboko).
Test: `test_reduce_flashing` (15 testów, w tym 60–120 s symulacji rur i 2 s ognia).

## 4. Paleta dla daltonistów (zrobione 22.10)

Metoda: symulacja Machado, Oliveira, Fernandes 2009 (IEEE TVCG 15(6), 1291–1298), macierze dla nasilenia 1,0 w **liniowym** RGB
(macierze sprawdzone z kodem pakietów R `palettecore`/`colorspace`; strona autorów dawała 403), odległość = CIE76 ΔE w Lab (D65) po
symulacji, kontrast WCAG po symulacji. Ta sama matematyka w Pythonie (`tools/accessibility/cvd.py`) i w grze (`ColourVision.simulate`,
`lab`, `delta_e`, `contrast_seen`); test sprawdza, że gra mierzy standardową paletę tak samo jak narzędzie (22,0 / 14,4 / 2,4 / 5,2).

**Broń** (`tools/accessibility/palette_search.py --window 30 --min-s 0.5 --identity 0.7`, `--slack 0.05` dla tritanopii): wyżarzanie po
siatce HSV; każdy kolor w oknie ±30° odcienia oryginału, nasycenie ≥ 0,5, **tożsamość**: najbliższym (normalnie) kolorem standardowym
jest jego własny, z zapasem (własny co najwyżej 0,7 odległości do najbliższego cudzego), kontrast ≥ 4,5 ze szkliwem normalnie i w trybie;
wynik = najmniejsza para (z białą apteczką) liczona jako min(ΔE w trybie; 0,8 × ΔE normalnie), potem spośród palet bliskich najlepszej ta
najmniej odchodząca od kolorów standardowych. Przegląd pasków (`swatches.py`, PNG bez okna): okno ±35° bez warunku tożsamości dawało
zamiany (tritanopia: śrutówka pomarańczowa, raca ceglasta) i blade kolory (raca łososiowa) — stąd warunek tożsamości, nasycenie ≥ 0,5
i okno 30°. Kolejność: taser, pistolet, śrutówka, gatling, rakietnica, sztucer, harpun, hwacha:

| Paleta | Kolory | Najmniejsze ΔE w swoim trybie | Normalnie | Standardowa paleta w tym trybie |
|---|---|---|---|---|
| standardowa | `WeaponPalette.COLORS` | — | 22,0 (taser/harpun) | — |
| deuteranopia | `#80d4ff #1975ff #f2184b #ffff4d #ff6e19 #66ff8a #4dbfac #b257d9` | **30,1** (taser/hwacha) | 38,1 | 14,4 |
| protanopia | `#608fbf #808cff #ff584d #c5d941 #f27e18 #57d97e #33e4ff #b433ff` | **28,0** (gatling/rakietnica) | 35,5 | 2,4 |
| tritanopia | `#4d8abf #8d79f2 #f2181f #a3bf13 #ff7519 #7ed96c #66ffff #ae49f2` | **25,1** (taser/pistolet) | 32,7 | 5,2 |

Apteczka biała w każdej palecie (odległość od niej ≥ 26,6 w trybie), najgorszy kontrast cyfry slotu ze szkliwem 4,52.

**Role HUD** (`tools/accessibility/role_search.py`: grupa zostaje standardowa, gdy już spełnia próg; inaczej szukanie ±30° odcienia,
najpierw rozdzielność, potem najmniejsza zmiana; próg: każda para grupy ≥ 40 ΔE w trybie, paski ≥ 3:1 z kanałem — WCAG 1.4.11):
deuteranopia — wytrzymałość `#ffd959` / wyczerpanie `#cc4129` / kofeina `#e6e2c3`, bezpiecznik niesiony `#e6a92e` / włożony `#33ff9f`,
zabicie `#cc2014`; protanopia — zdrowie i boss `#e6442e` (standardowa czerwień ma 2,9:1 z kanałem), wytrzymałość `#ffd959` / `#ff7259` /
`#fff8d9`, bezpieczniki `#b27512` / `#59ff7f`; tritanopia — wytrzymałość `#e9ff80` / `#e6522e` / `#e6aa95`, słaby punkt `#e6ae2e`,
zabicie `#ff4033`. Szczyt pulsu kofeiny = jej kolor w 55 % drogi do bieli; w tritanopii taki szczyt był 18 ΔE od wypełnienia, więc
`#ff9ea5` (`role_search.py --peaks`: każdy punkt pulsu ≥ 40 ΔE od wypełnienia i wyczerpania, w trybie i normalnie). Biel trafienia i szarość zablokowania stałe (36,8 ΔE; dzieli je kształt).

**Podpięcie:** `ColourVision` (`src/style/colour_vision.gd`): `weapon(id, standard)`, `role(name)` czytają `Settings.data.colour_vision`.
`WeaponPalette.color()` (a więc `ammo_color()`, `Pickup.color_of()`, `ArtLibrary.pickup_rim_color()`, slot w ręku) idzie przez nią.
`Settings._apply(&"colour_vision")` woła `ArtLibrary.refresh_pickup_rims()` — rim w buforowanych materiałach `exhibit:` i
`exhibit_debris:` pickupów, więc leżące już pudełka zmieniają się od razu (poświata z daleka `far_body` bierze kolor rimu). Wypalone
nadruki zostają w kolorach standardowych (warunek tożsamości trzyma je zgodne z rimem). Greybox pickupu (tylko bez modeli) bierze kolor przy
budowie. `Hud.apply_palette()` na `settings_changed`: paski zdrowia i bossa, kubek kofeiny, wytrzymałość, bezpieczniki, slot w ręku.

**Sygnały poza kolorem (dla wszystkich palet):** wyczerpana wytrzymałość = wypełnienie kreskowane ukośnie, w drugą stronę niż
kreskowany segment zmęczenia po prawej; bezpiecznik niesiony = poziome ciemne pasy, włożony = pełny z jasnym żarnikiem pośrodku, brak = obrys; markery
trafień: zwykłe = 4 ukośne kreski, słaby punkt = 4 ukośne dłuższe i grubsze, zabicie = 4 ukośne + krzyż prosty, zablokowane = sam krzyż
prosty. Pasek bossa i poświata zapowiedzi ataku (jasność) bez zmian kształtu.

**Testy:** `tests/unit/test_colour_vision.gd` (symulacja = narzędzie; każdy tryb ma kolor każdej broni; najmniejsze ΔE ≥ 25 w swoim
trybie i ≥ 18 normalnie, poprawa o ≥ 10 względem standardowej; apteczka daleko; cyfra slotu ≥ 4,5:1; tożsamość i okno odcienia; każda
rola w każdym trybie; grupy ról ≥ 40; paski ≥ 3:1 z kanałem i szkliwem; markery i bezpieczniki ≥ 3:1), `tests/integration/test_colour_vision_live.gd`
(opcja zmienia kolor wszędzie, gdzie jest czytany; rimy leżących pickupów i ich odłamków na żywo; HUD na żywo; kształty markerów;
kreskowanie wyczerpania; wygląd bezpieczników).

**Okno:** `bash tools/agents/with_window.sh bash tools/run_hud_gallery.sh shots --tag=cv --views=hud,notice,rims,marker_hit,marker_weak_point,marker_kill,marker_blocked --languages=en --sizes=1920x1080 --palettes=0,1,2,3`
(nowe widoki galerii: `rims` — rząd wszystkich pudełek amunicji i apteczki blisko i daleko; `marker_*` — cztery markery trafień).

## Stan prac / co dalej

**Gałąź `accessibility` (worktree `qa-sweep`), commity lokalne, nic nie wypchnięte.** 22/23.10 (noc): `git merge pietro-1` dwa razy
(112 commitów za, potem @1a88be82; bez konfliktów). Pełny zestaw jednoprocesowy przed pracą: 3173 zaliczone, 2 niezaliczone — oba to
nowe testy `RoomLamps` uruchomione na starym kodzie lamp (czerwone przed poprawką, jak w TDD); poza nimi `pietro-1` + gałąź zielone.
**Pełny zestaw jednoprocesowy po pracy (na `0d6f2644`, scalenie z `pietro-1` @1a88be82): 3190 zaliczone, 0 niezaliczonych, bez linii ERROR (33 min 5 s).**

- [x] Opcje w `SettingsData` + wiersze + teksty PL/EN + testy; §5 sprint przełączany; §1 rozmiar HUD; §2 napisy; §3 błyski.
- [x] §3 kontrakt `RoomLamps` → `Flashing.Gate` (jedna bramka na salę, głębokość ≥ 50 %, oprawy świecą, drżenie przygaszenia ×0,5);
  commit `1014da5a`. Testy w `test_room_lamps` (3 nowe).
- [x] §4 paleta dla daltonistów: `ColourVision`, palety broni i ról HUD z pomiarów (tabela w §4), slot w ręku, rimy pickupów na żywo,
  HUD na żywo, sygnały kształtu (wyczerpanie, bezpieczniki, markery); commit `f9a2c4a0`. Testy: `test_colour_vision` (12 po przeglądzie),
  `test_colour_vision_live` (10). Opcja `colour_vision` **zmienia grę** — wiersz w menu zostaje.
- [x] Galeria HUD (`tools/run_hud_gallery.sh`): opcje `--languages`, `--sizes`, `--palettes`, widoki `rims` i `marker_*`. Zrzuty z okna
  (23.10, 00:00, przez `with_window.sh`): `tests/_out/hud_style/cv_cv{0..3}_{hud,notice,rims,marker_*}_en_1920x1080.png` — obejrzane:
  kształty markerów czytelne, kreskowanie wyczerpania widać, bezpiecznik niesiony w pasy i włożony z żarnikiem widać w każdej palecie,
  slot w ręku i kubek kofeiny w kolorze trybu.
- [x] Poprawki po przeglądzie (23.10): szczyt pulsu kofeiny w tritanopii `#ff9ea5` (dawny `#f4d9cf`, 55 % do bieli, był 18 ΔE od
  zwykłego wypełnienia; `role_search.py --peaks`; test: szczyt w grupie wytrzymałości, każdy punkt pulsu ≥ 40 od wypełnienia i
  wyczerpania); żarnik bezpiecznika na ciemnym obrzeżu (biel na jasnej zieleni miała ~1,3:1; test ≥ 4,5:1 żarnik/obrzeże, ≥ 3:1
  obrzeże/korpus w każdej palecie); serce przy zdrowiu w kolorze paska zdrowia trybu (`apply_palette`); testy: HUD zbudowany przy już
  ustawionej opcji, materiał pickupu utworzony pierwszy raz w trybie niestandardowym, muzeum zwolnione i zbudowane ponownie w innym
  trybie, macierze Machado sprawdzone liczbami z tabeli (kolumny przez barwy podstawowe + kolor bez obcinania).
- Do zrobienia później (poza zakresem tej gałęzi, bez kodu):
  - lampka skrzynki bezpieczników w świecie jest tylko czerwona/zielona (`src/game/fuse_box.gd:91`): dodać sygnał poza barwą (np. miganie
    → stałe, albo kształt/liczba zapalonych gniazd) albo kolory z `ColourVision`;
  - inne źródła migotania poza kontraktem `Flashing`: `EnvFire`, promień Heliosa, święty ogień, rozregulowana lampa kawiarni, zająknięcie
    świateł przy odcięciu prądu (`src/game/night_objective.gd:332`: zgaś 0,12 s → zapal → 0,2 s → zgaś) — każde przez `Flashing.Gate`
    i `lamp_level()` jak `RoomLamps`;
  - bramka `RoomLamps` jest na efekt, nie na salę — bezpieczne, dopóki `UncannyDirector.MIN_GAP` (8 s) > najdłuższy efekt lamp (6 s);
    jeśli ktoś skróci odstęp albo pozwoli nakładać efekty, przenieść bramkę do sali (`RoomLamps._gates[room]`).
- Uwaga z okna: **rim zmienia wygląd pudełka słabo z bliska** (pudełko czyta się głównie wypalonym nadrukiem i albedo, które zostają w
  kolorach standardowych, zgodnie z planem); z daleka (9–15 m, `far_body`) kropki biorą kolor trybu wyraźniej. Jeśli właściciel chce mocniej:
  następny krok to przekolorowanie mapy emisji w shaderze pickupów (jasność nadruku × kolor trybu) albo osobne wypieki na tryb — nie robione.
- Do sprawdzenia w oknie (właściciel): rimy pickupów w trzech paletach w ciemnej sali i pod księżycem, blisko i z 15 m (czy kropki z daleka
  się rozróżniają, czy rim nie gryzie się z nadrukiem); HUD w trzech paletach w ruchu (pasek zdrowia protanopii `#e6442e`, wytrzymałość,
  kofeina, bezpieczniki, markery trafień w walce — czy kształty czytają się w 0,2 s); ostrość tekstu HUD przy skali innej niż 100 %
  (skalowana jest warstwa, nie czcionki; jeśli rozmyte, przejść na skalowanie rozmiarów czcionek); wygląd napisów w trzech rozmiarach i z tłem;
  ograniczone błyski w piwnicy, przy gatlingu i w menu głównym; **lampy sal z „ograniczeniem błysków”**: migotanie (czy nadal „zadyszka
  sieci” przy ≤ 3/s na salę), mrugnięcie (jedno zamiast dwóch), powrót po zgaśnięciu, „przejście” przy 50 % (czy nadal czyta się jak coś
  idącego), znaki WYJŚCIE (2/s, oprawy świecą).
- **Przegląd w oknie 23.10** (`2026-10-22-przeglad-w-oknie.md` §2): HUD w 4 paletach zgodny z tabelą (próbki pikseli), rimy jak opisano; skala HUD, napisy, ograniczenie błysków nie sprawdzone.
