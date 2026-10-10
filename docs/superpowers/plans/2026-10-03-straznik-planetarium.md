# Strażnik Oświecenia — Wielkie Planetarium (plan wykonawczy)

> **Dla wykonawcy:** zadania po kolei, TDD (najpierw test, potem kod), commit po każdym zadaniu. Kroki z `- [ ]`.
> Gałąź `guard-planetarium` (od `pietro-1`). Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.4, **§7.4** (wiersz „Wielkie Planetarium” + wspólne zasady). Wzorzec: Kolos (`docs/superpowers/plans/2026-10-03-straznik-kolos.md`). Model: `docs/art/kit-pietro1-oswiecenie.md` §5. Arena: `src/level/floor1/zones/enlightenment.gd` (`_rotunda`).

**Cel:** strażnik skrzydła Oświecenia zamiast manekina — mosiężne orrery 10 × 9,5 m na środku Rotundy Planetarium (19,5 × 23 m, h 22, okulus). **Dla wielu graczy pierwszy strażnik:** „boss-arena”, który uczy słabych punktów — wolniej i czytelniej niż Kolos. Walka 2–3 min, trzy fazy + finał, każdy atak zapowiedziany ≥ 0,6 s, z ciężką, mechaniczną animacją (luz przekładni, przestrzał przy hamowaniu, kołysanie wiszących księżyców, iskry w łożyskach, płatki słońca otwierane na sprężynie, światło pulsujące w rytmie przekładni).

**Architektura (jeden akapit):** czysta logika w `RefCounted`: `OrreryBrain` (stany, ataki z etapami TELEGRAPH/STRIKE/RECOVER i tabelą czasów na fazę, `clip_time()`, fazy liczone **zestrzelonymi planetami**, prędkości przelotowe pięter na fazę, wybór: piętro do przyspieszenia, planeta do wypuszczenia, liczba rozbłysków), `OrreryDrive` (napęd jednego piętra: kąt, prędkość, przyspieszenie, cel), `OrreryGeometry` (liczby modelu i test kapsuła–piętro: belki, pręty, planety, wiszące księżyce). Węzeł `Planetarium extends Guardian` składa ciało (`OrreryRig` na modelu `planetarium` z `ArtLibrary`, szarość gdy brak modelu), strefy trafień (`GuardianZone` → `take_zone_damage`: planety, słońce, mosiądz), przelicza obrażenia na pule części (planety, rdzeń), prowadzi ataki i zagrożenia: piętra omiatające arenę (test kapsuły strażnika co klatkę), planetę na orbicie, `RollingPlanet` (zestrzelona planeta toczy się, odbija od ścian, pęka) i `SolarFlare` (pocisk łukiem z `GroundMark`). Choreografia `OrreryMoves` składa pozę rigu ze stanu mózgu, napędów i sprężyn (`Spring`, `MotionClip`). Upadek: `OrreryFall` przejmuje model (zatarcie, płatki odpadają, ramiona pękają na mosiężny gruz). Po pokonaniu `dress_arena()` stawia co noc nieruchome, wygaszone orrery.

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh [--filter=...]` (bez okna, `--fixed-fps 60`), scenariusz `bash tools/run_guardian.sh planetarium --dry` (bez okna).

---

## Decyzje projektowe

1. **Ramiona sięgają 5 m (model bez zmian), arena ma 9,75–11,5 m promienia.** Zewnętrzny pierścień (r 5,5–9,5) jest bezpieczny od ramion, więc presję na zewnątrz dają **planeta na orbicie** (od fazy 1), **toczące się zestrzelone planety** i **rozbłyski słońca** (od fazy 2); środek (r < 5) to taniec z ramionami. Gracz wybiera: zostać na zewnątrz i unikać pocisków, czy wejść między ramiona (przeskoczyć niskie, stanąć w luce pod wysokim, trzymać się > 3,7 m od środkowego). Rogi z instrumentami są osłoną przed toczącymi się planetami (zgodnie z areną).
2. **Wszystkie planety są słabymi punktami od początku** (hojne dla pierwszego bossa); kolejność zestrzeliwania wybiera gracz. „Po kolei” = każda odpada osobno, gdy jej pula się wyczerpie, i od razu staje się zagrożeniem.
3. **Fazy liczone planetami, nie progami zdrowia** (`phase_for` nadpisane): 2 zestrzelone → faza 2, 4 → faza 3, 6 → finał (słońce otwiera się, rdzeń odsłonięty). Pasek zdrowia = suma pul planet + rdzenia; mosiądz (×0,1) ujmuje z puli rdzenia, ale najwyżej 40 % (rdzeń trzeba dobić).
4. **Zagrożenia ramion analitycznie, nie fizyką.** Piętra nie mają kolizji z graczem (obrotowe ciało kinematyczne pchałoby go w ściany); co klatkę kapsuła strażnika (promień i wysokość z jego `CollisionShape3D`) jest sprawdzana z prymitywami piętra w jego układzie (prostopadłościany belek, odcinki prętów, kule planet i księżyców z ich *rzeczywistych* węzłów — kołysanie się liczy). Trafienie: obrażenia × szybkość obwodowa, odrzut po stycznej i na zewnątrz, przerwa 1 s na piętro; wolne ramię (< 0,35 m/s) tylko odpycha.
5. **Wiszące księżyce, Księżyc Ziemi i pierścień Saturna są wycinane z siatek modelu w grze** (`MeshShards.split`: trójkąty wg środków ciężkości, wyniki w pamięci podręcznej): bez przebudowy modelu w Blenderze dostają własne osie (księżyce kołyszą się jak wahadła, Księżyc krąży wokół Ziemi, pierścień się chwieje, a po zestrzeleniu Saturna toczy się osobno jak obręcz).
6. **Bez nowego pliku dźwięku:** dzwonek zapowiedzi to `hit_metal` w wysokości przypisanej piętru (niskie 0,62, środkowe 0,8, wysokie 1,0) — gracz uczy się słyszeć, które ramię przyspieszy; `Sfx.play_at` dostaje opcjonalną wysokość. Przekładnia: pętla `orrery_gears` na własnym odtwarzaczu (wysokość rośnie z prędkością pięter, w zapowiedzi głośniej = klekot), `orrery_sweep` (zamach przy strażniku, wylot planety), `colossus_charge` (słońce zbiera rozbłysk), `flare_blast` (lądowanie), `guardian_wake`/`guardian_crumble` (baza).
7. **Latające księgi pominięte** (prawdziwy wróg jeszcze nie istnieje; pierwszy boss ma być czytelny).

## Liczby walki (Nocna zmiana; Podwójna ×1,2 zdrowia, obrażenia przez `damage_scale`)

| Element | Wartość |
|---|---|
| Zdrowie | 1350 = planety 66 % (Merkury 8, Wenus 10, Ziemia 12, Mars 10, Jowisz 14, Saturn 12 %) + rdzeń słońca 34 % |
| Obrażenia poza słabymi punktami | ×0,1 (iskry, szary znacznik), z puli rdzenia, najwyżej 40 % rdzenia |
| Słabe punkty | **planety 1–6** (zawsze, także w locie), **rdzeń słońca** (gdy odsłonięty) — pełne obrażenia + mnożnik broni |
| Przebudzenie | 3,0 s (zapadki chwytają, pętla przekładni rusza, piętra z luzem ruszają, płatki oddychają światłem, planety zapalają się po kolei) |
| Przerwa między atakami | 2,0 / 1,6 / 1,3 s, finał 1,2 s |
| **Piętra (przelot, rad/s)** | niskie +0,75 / −0,9 / +1,05 / −1,2; środkowe −0,35 / +0,45 / −0,55 / +0,6; wysokie +0,45 / −0,55 / +0,65 / −0,75 (faza 1/2/3/finał; znak = kierunek — każda faza odwraca) |
| **Ramiona (kontakt)** | niskie 14, środkowe 18, wysokie 14 obr. × szybkość obwodowa/2,5 (0,6–1,5), odrzut 10; niskie: przeskocz (belka 0,30–0,55, szczyt skoku 0,83), wysokie: stań w luce r 3,85–4,45 albo dalej niż 5,55 m, środkowe: dalej niż 4,0 m |
| **Przyspieszenie piętra** (atak) | zapowiedź 1,1 / 0,95 / 0,85 s (lampy na końcach ramion, dzwonek piętra, klekot przekładni, drżenie piętra), potem 3,0 / 3,2 / 3,4 s ×2,4 prędkości (od fazy 2 w połowie przypadków odwrócenie ×1,8), powrót 1,2 / 1,0 / 0,9 s |
| **Planeta na orbicie** (atak) | zapowiedź 1,2 / 1,1 / 1,0 s (planeta rozżarza się, lampka gniazda, dzwonek), lot 6,5 / 6,0 / 5,5 s: wylot, pół okrążenia elipsy (ściany − 2,3 m) na 1,25 m wysokości wycentrowane na strażniku, powrót do gniazda; 16 obr. + odrzut 9 raz na lot; można ją ostrzelać (słaby punkt) |
| **Zestrzelona planeta** | spada i toczy się (fizyka, odbicia od ścian i instrumentów), 14 obr. + odrzut 8 w kontakcie (≥ 1,5 m/s), pęka po 9 s albo po zatrzymaniu; 25 obr. rozbija ją wcześniej; małe (≤ 0,8 m) da się przeskoczyć |
| **Rozbłysk słońca** (faza 2+) | zapowiedź 1,3 / 1,1 s (płatki rozchylają się, słońce zbiera światło), lot 1,5 / 1,35 s łukiem, znak na posadzce od wylotu; plusk ognia r 2,0 m: 18 obr.; faza 2: 1, faza 3: 3 (na strażnika i ±3,2 m w poprzek), finał: 4; można zestrzelić |
| **Przemiana fazy** | 2,4 s: piętra hamują z przestrzałem, lampy i akord dzwonków, płatki otwierają się o stopień (0 → 0,35 → 0,55 rad), potem nowe prędkości |
| **Odsłonięcie** (6 planet) | 2,8 s: hamowanie, płatki rozkwitają na sprężynie do 1,6 rad, rdzeń rozbłyska; finał: wszystko szybciej, rozbłyski po 4 |
| Pokonanie | zatarcie: piętra stają z szarpnięciem i przestrzałem, iskry w łożyskach, płatki odpadają jeden po drugim, rdzeń gaśnie, ramiona pękają na mosiężny gruz; Klucz Gwiazd + odłamek na `arena_planetarium_reward`; 60 Pyłu |

Szacunek czasu: `bash tools/run_guardian.sh planetarium --bot` (strażnik-bot bez uników krąży w ~7,7 m i strzela 2,5 razy na s w widoczny słaby punkt, 45 % trafień): **45 s** do upadku (faza 2 w 12., faza 3 w 17. s), 18 obrażeń przyjętych. Bot nie ma kłopotu z ruchomymi planetami, gracz ma — i strzela ~35–50 % czasu → ok. **2–3 min**, wolniej niż Kolos (36 s bota). Do sprawdzenia w grze.

---

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/fx/mesh_shards.gd` (zmiana, zgodna wstecz) | `split(mesh, inside, key)`: trójkąty, których środek spełnia warunek, i reszta — w przestrzeni źródła, z pamięcią podręczną |
| `src/fx/sfx.gd` (zmiana, zgodna wstecz) | `play_at(..., pitch)` — wysokość bazowa |
| `src/game/floor1/guardians/orrery_geometry.gd` (nowy) | `OrreryGeometry`: liczby modelu (piętra, belki, pręty, planety, księżyce, słońce), test kapsuła–prostopadłościan / kula / odcinek |
| `src/game/floor1/guardians/orrery_drive.gd` (nowy) | `OrreryDrive`: napęd piętra (kąt, prędkość, cel, przyspieszenie) |
| `src/game/floor1/guardians/orrery_brain.gd` (nowy) | `OrreryBrain`: stany, ataki, etapy, czasy, fazy wg planet, prędkości przelotowe, wybór ataku/piętra/planety |
| `src/game/floor1/guardians/orrery_rig.gd` (nowy) | `OrreryRig`: model `planetarium` (lub szarość), wycięte księżyce/pierścień, lampy ramion, światło słońca, `apply(Pose)`, poświaty |
| `src/game/floor1/guardians/orrery_moves.gd` (nowy) | `OrreryMoves`: poza z mózgu i napędów: luz przekładni, kołysanie pięter, wahadła księżyców, wirowanie planet, płatki na sprężynach, puls światła, klipy budzenia/przemian |
| `src/game/floor1/guardians/rolling_planet.gd` (nowy) | `RollingPlanet extends RigidBody3D`: zestrzelona planeta (lub pierścień) toczy się, rani w kontakcie, pęka |
| `src/game/floor1/guardians/solar_flare.gd` (nowy) | `SolarFlare extends Projectile`: łuk do celu, znak na posadzce, plusk ognia |
| `src/game/floor1/guardians/orrery_fall.gd` (nowy) | `OrreryFall`: zatarcie, płatki, gruz |
| `src/game/floor1/guardians/planetarium.gd` (nowy) | `Planetarium extends Guardian`: ciało, kolizje podstawy, strefy, pule, ataki, zagrożenia, dźwięk, reset, upadek, `dress_arena()` |
| `src/level/floor1/zones/enlightenment.gd` (zmiana) | znacznik `arena_planetarium_reward` |
| `tests/unit/test_orrery_geometry.gd`, `tests/unit/test_orrery_brain.gd` | geometria, napęd, mózg |
| `tests/integration/test_orrery_parts.gd` | `split`, rig (części, wycięcia, płatki na zewnątrz), toczące się planety, rozbłyski |
| `tests/integration/test_planetarium.gd` | walka w prawdziwej Rotundzie |
| `tests/scenarios/guardian_scenario.gd` (zmiana) | momenty Planetarium (`--dry`), dziennik |
| `docs/Nocna-Zmiana-specyfikacja.md` (zmiana) | §4.5 Wielkie Planetarium, rejestr decyzji |

---

## Kontrakty (dla kolejnych strażników)

```gdscript
MeshShards.split(mesh, func(centroid: Vector3) -> bool: ..., "key") -> Array  # [reszta, wycięte] (Piece, przestrzeń źródła)
Sfx.play_at(sound, at, volume_db, pitch_jitter, pitch)
OrreryGeometry.capsule_box(feet, radius, height, box: AABB) -> bool   # pionowa kapsuła a prostopadłościan
OrreryGeometry.capsule_sphere(feet, radius, height, center, r) -> bool
Planetarium.tier_touches(tier: int, feet: Vector3, radius: float, height: float) -> bool  # w świecie, teraz
```

---

### Zadanie 1: Zestaw: wycinanie siatek, wysokość dźwięku, geometria i napęd

**Pliki:** zmiany `mesh_shards.gd`, `sfx.gd`; nowe `orrery_geometry.gd`, `orrery_drive.gd`; test `tests/unit/test_orrery_geometry.gd`.

- [x] **Krok 1 — testy:** kapsuła 0,4 × 1,8 stojąca na linii niskiego ramienia (r 3,5) — trafiona; stopy na 0,6 m — wolna; na linii wysokiego ramienia w luce (r 4,1) — wolna, przy księżycu (r 3,3) — trafiona, na końcu (r 5,0) — trafiona, dalej (r 5,7) — wolna; środkowe: r 3,5 trafiona także w skoku, r 4,1 wolna; nad głową (wysoka belka) skaczący mieści się; napęd: przyspiesza do celu z ograniczeniem, odwraca kierunek przez zero, kąt to całka prędkości.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 2: Mózg (`OrreryBrain`)

**Pliki:** nowy `orrery_brain.gd`; test `tests/unit/test_orrery_brain.gd`.

Stany `DORMANT, WAKING, IDLE, ATTACK, SHIFT, UNVEIL, DEAD`; ataki `SURGE, LAUNCH, FLARE`; etapy `TELEGRAPH, STRIKE, RECOVER` z sygnałami `telegraphed/struck/finished`. Wejście co klatkę: odległość strażnika od osi (płasko). Węzeł zgłasza zestrzelenie planety (`planet_lost(k)`), mózg wylicza fazę i czeka z przemianą na koniec ataku.

- [x] **Krok 1 — testy:** przebudzenie trwa `WAKE_TIME`, potem IDLE i pierwszy atak; faza 1: tylko przyspieszenie i orbita, faza 2+: także rozbłysk; orbita tylko z planetą na ramieniu (żadna nie startuje dwa razy naraz, nie zestrzelona); każda zapowiedź każdego ataku w każdej fazie ≥ `Guardian.MIN_TELEGRAPH`; cel napędu piętra zmienia się dopiero w STRIKE; fazy z planet (0,1 → 1; 2,3 → 2; 4,5 → 3; 6 → odsłonięcie); przemiana po bieżącym ataku, prędkości przelotowe odwracają się; ten sam atak nigdy 3× z rzędu; blisko osi przeważa przyspieszenie, daleko orbita/rozbłysk; `reset()`; to samo ziarno → ta sama sekwencja.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 3: Rig i ruch (`OrreryRig`, `OrreryMoves`)

**Pliki:** nowe `orrery_rig.gd`, `orrery_moves.gd`; test `tests/integration/test_orrery_parts.gd`.

- [x] **Krok 1 — testy:** `split` zachowuje liczbę trójkątów (reszta + wycięte); rig z modelu ma piętra, 6 planet, 6 płatków, rdzeń, 10 wiszących księżyców z osią na górze pręta (wahadło), Księżyc Ziemi, pierścień Saturna; szarość ma te same nazwy; uśpiony = model w spoczynku; obrót piętra przenosi planety i księżyce; płatek otwarty o +1,6 rad odsuwa się od osi (otwiera na zewnątrz); przyspieszenie piętra wychyla księżyce (wahadło), hamowanie daje przestrzał kąta.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 4: Zagrożenia: toczące się planety i rozbłyski

**Pliki:** nowe `rolling_planet.gd`, `solar_flare.gd`; testy w `test_orrery_parts.gd`.

- [x] **Krok 1 — testy:** toczącą się planetę niesie prędkość, toczy się po posadzce, odbija od ściany, rani stojącego raz (nie dwa razy w 1 s), skaczącego nad małą nie; 25 obrażeń ją rozbija (gruz na DEBRIS); rozbłysk ląduje w znaku (±0,5 m), rani w promieniu, nie rani dalej, zestrzelony w locie — bez plusku.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 5: Planetarium — walka w prawdziwej Rotundzie

**Pliki:** nowy `planetarium.gd`; zmiana `enlightenment.gd`; test `tests/integration/test_planetarium.gd`.

- [x] **Krok 1 — testy:** prawdziwe Planetarium na znaczniku, śpi; strażnik za linią startu → `guardian_awakened`, pasek z imieniem; 40 s walki z różnych miejsc: każda zapowiedź ≥ 0,6 s (`telegraphed` → `struck`), przyspieszenie i orbita w fazie 1; cel napędu piętra zmienia się ≥ 0,6 s po zapowiedzi; trafienie w mosiądz ×0,1 (szary), w planetę pełne (złoty), w rdzeń przed odsłonięciem ×0,1; promień z oczu strażnika trafia planetę jako słaby punkt; zestrzelona planeta znika z ramienia i toczy się (`RollingPlanet`), następna — osobno; po 2 → faza 2 i przemiana; kapsuła strażnika (z jego kształtu): stojąc w luce pod przechodzącym wysokim ramieniem — bez obrażeń, przy księżycu — obrażenia; przeskok niskiego ramienia — bez obrażeń, stojąc — obrażenia; faza 2: rozbłysk ląduje w znaku; 6 planet → odsłonięcie, rdzeń słabym punktem.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 6: Upadek, nagrody, smycz

**Pliki:** nowy `orrery_fall.gd`; zmiana `planetarium.gd`; testy w `test_planetarium.gd`.

- [x] **Krok 1 — testy:** śmierć przez rdzeń → `OrreryFall`, płatki i ramiona jako gruz fizyczny; Klucz Gwiazd + odłamek na znaczniku nagrody, zapis, następnej nocy brak strażnika, a w rotundzie stoi wygaszone orrery (z kolizją); strzał z galerii obserwatorów budzi je, smycz po `LEASH_TIME` uspokaja: planety z powrotem na ramionach, pełne zdrowie, piętra w spoczynku, toczące się planety i rozbłyski znikają.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 7: Arena deweloperska

**Pliki:** zmiana `tests/scenarios/guardian_scenario.gd`.

- [x] **Krok 1:** `bash tools/run_guardian.sh planetarium --dry`: momenty: śpi, budzi się, zapowiedź przyspieszenia (lampy), przyspieszenie, orbita, zestrzelona planeta toczy się, przemiana 2, rozbłysk (znak), faza 3, odsłonięcie, upadek; dziennik JSON; `--bot` mierzy długość walki.
- [x] **Krok 2 — commit.**

### Zadanie 8: Dokumentacja i pełny zestaw testów

- [x] Specyfikacja §4.5 (Planetarium), rejestr decyzji, stan planu; scalenie `pietro-1`; pełne `bash tools/run_tests.sh` (zielone), commit.

---

## Ryzyka i odpowiedzi
| Ryzyko | Odpowiedź |
|---|---|
| Gracz stoi na zewnątrz i ramiona nic nie znaczą | orbita, toczące się planety i rozbłyski naciskają na zewnętrzny pierścień; środek to alternatywa (decyzja 1) |
| Niskie ramię nie do przeskoczenia przy wolnym przelocie | prędkości przelotowe dobrane tak, by od r ≈ 3 przelot trwał krócej niż lot nad belką; w przyspieszeniu wszędzie |
| Luka pod wysokim ramieniem znika, gdy księżyce odchylą się na zewnątrz | wychylenie odśrodkowe ograniczone (~0,1 rad), zagrożenie liczone z rzeczywistych węzłów (test luki w przyspieszeniu) |
| Wenus (r 4,75) zachodzi na lukę wysokiego ramienia | to inne piętro: przelatują w różnych chwilach; czytelność dają lampy i dzwonki pięter; po zestrzeleniu Wenus luka jest wolna |
| Wycinanie siatek kosztuje przy każdym wczytaniu | pamięć podręczna na zasób siatki (model jest współdzielony) |
| Fizyka toczących się planet niestabilna | sfera/walec na DEBRIS, tłumienie, czas życia, pęknięcie przy zatrzymaniu |
| Ciężkie testy z całym piętrem | logika bez sceny; w hali kilka scenariuszy |

---

## Stan wykonania (3.10)

Wszystkie zadania 1–8 wykonane (TDD, commit po zadaniu; `pietro-1` scalone przed pełnym zestawem). Testy: `test_orrery_geometry` (7: kapsuła a ramiona, prawdziwy łuk skoku nad niskim ramieniem przy przelocie i w przyspieszeniu, napęd), `test_orrery_brain` (11), `test_orrery_parts` (11: wycinanie siatek, rig, płatki na zewnątrz, luz i wahadła, toczące się planety, rozbłyski), `test_planetarium` (8, prawdziwa Rotunda); `run_guardian.sh planetarium --dry`: 12/12 momentów.

**Odstępstwa od planu (świadome):**
- `MeshShards.partition` (wycinanie na wiele części w jednym przejściu) zamiast samego `split` — dziesięć księżyców naraz; `split` zostaje jako nakładka.
- Zasada „bez snajperki” z `pietro-1` (trafienie spoza areny nic nie robi i nie budzi) zastąpiła plan „strzał z galerii budzi, smycz uspokaja”: test sprawdza, że strzał z galerii obserwatorów się odbija. `take_zone_damage` pyta `hit_counts()` przed ruszeniem pul planet.
- Odsłonięty rdzeń: płatki po rozkwicie nie osłaniają go już (ich strefy wyłączone, kula rdzenia większa) — bez tego bot (i gracz z posadzki) trafiał w rozłożone płatki: 117 s → 45 s.
- Przy wolnym przelocie (< 0,35 m/s w miejscu strażnika) ramię tylko odpycha; od tej prędkości obrażenia rosną z prędkością (×0,6–1,5).
- Znacznik nagrody `arena_planetarium_reward` 6,25 m od osi w stronę drzwi (poza zasięgiem nieruchomych ramion na kolejnych nocach).
- Nowy dźwięk nie powstał: dzwonek pięter to `hit_metal` w trzech wysokościach (`Sfx.play_at(..., pitch)`), zatarcie to `relay` + `gate_jam`.
- Latające księgi pominięte (jak dopuszczał projekt): pierwszy boss ma być czytelny.

**Dla kolejnych strażników:** `MeshShards.partition` (osie dla części wypieczonych w jednej siatce), `Sfx.play_at(..., pitch)`, wzorzec „zagrożenie analityczne z kapsułą strażnika z jego kształtu” (`OrreryGeometry.capsule_box/sphere/segment`), `SolarFlare` (pocisk łukiem ze znakiem — dowolny „moździerz”), `RollingPlanet` (toczący się gruz-zagrożenie), fazy liczone częściami (`phase_for` nadpisane).
