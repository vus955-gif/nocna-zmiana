# Strażnik Asyrii — Lamassu (plan wykonawczy)

> **Dla wykonawcy:** zadania po kolei, TDD (najpierw test, potem kod), commit po każdym zadaniu. Kroki z `- [ ]`.
> Gałąź `guard-lamassu` (od `pietro-1`). Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.2, **§7.4** (wiersz Lamassu + wspólne zasady). Wzorzec: plan Kolosa `docs/superpowers/plans/2026-10-03-straznik-kolos.md` (zestaw ruchu, strefy, opiekun, scenariusz). Model: `docs/art/kit-pietro1-asyria.md` §7. Arena: `src/level/floor1/zones/assyria.gd` (Dziedziniec Pałacu).

**Cel:** drugi prawdziwy strażnik Piętra I — skrzydlaty byk z ludzką głową (ok. 4 m) w Dziedzińcu Pałacu (30,5 × 27 m, 14 m, otwarty strop z księżycem). **Ciężki taran**, inny niż T-Rex: zamiast jednej szarży — szarża, **podmuch skrzydeł**, **tupnięcie** z falą i w fazie 3 **skoki w locie**. Walka 2–3 min w trzech fazach, każdy atak ≥ 0,6 s zapowiedzi. Poprzeczka animacji: **ciężar kamiennego czworonoga** — czterotaktowy stęp z kopytami przyszpilonymi IK do posadzki, przechył tułowia przy ruszaniu i hamowaniu, kiwanie głowy, skrzydła z końcówkami na sprężynach, ogon, kurz spod każdego kopyta, wstrząs kamery zależny od odległości.

**Architektura (jeden akapit):** czysta logika w `RefCounted`: `LamassuBrain` (stany, etapy TELEGRAPH/STRIKE/RECOVER z tabelą czasów na fazę, wybór ataku, ogłuszenie, przemiany faz, wszystkie liczby walki) i `LamassuGait` (kopyta w świecie: kolejność stawiania w stępie i galopie, przewidywanie miejsca lądowania kopyta, poślizg, kroki „na komendę”). Węzeł `Lamassu extends Guardian` składa ciało (`LamassuRig` na modelu `lamassu` z `ArtLibrary`, szarość o tych samych nazwach części, gdy modelu brak), strefy trafień (`GuardianZone`: twarz, korona, kamień, skrzydła), ruch (skradanie z szerokim promieniem skrętu, szarża, poślizg, lot) i efekty (`GroundMark`, `ShockwaveRing`, nowy `WingGust`, kurz, gruz, wstrząs). Choreografia to `LamassuMoves`: klipy `MotionClip` próbkowane w `clip_time()` mózgu + sprężyny (`Spring`) → `LamassuRig.Pose`; nogi rozwiązuje IK dwóch kości (`LimbIK.two_bone`), kopyto trzyma poziom. Cokół, z którego schodzi, stawia `dress_arena()` (`LamassuPlinth`). Upadek: `LamassuFall` przejmuje rig (pęknięcia rozbłyskują, klęka, skrzydła się odłamują, rozpad na bryły).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh [--filter=...]` (bez okna, `--fixed-fps 60`), scenariusz `bash tools/run_guardian.sh lamassu --dry` (bez okna).

---

## Decyzje

1. **Animacja kodem, jak u Kolosa** (klatki kluczowe + sprężyny + IK na sztywnych częściach). Model ma części w stawach (`body` → `head` → `headdress`, `wing_*` → `wing_*_tip`, `tail`, `thigh_*` → `shin_*` → `hoof_*`, znaczniki `contact_*` pod kopytami) — patrz rozdz. 7 katalogu.
2. **Kopyta stoją w świecie, ciało nad nimi** (proceduralny chód, nie klip): `LamassuGait` trzyma pozycje kopyt w świecie; kopyto odrywa się tylko w swojej kolejce i ląduje tam, gdzie będzie jego miejsce pod ciałem za chwilę (przewidywanie z prędkości i skrętu). Stęp czterotaktowy w kolejności bocznej (LT → LP → PT → PP: lewa tylna, lewa przednia, prawa tylna, prawa przednia), zawsze co najmniej trzy kopyta na posadzce; szarża to ciężki galop (pary nóg, faza lotu). Ciało osiada, gdy rozstawione nogi nie sięgają (nogi są proste w spoczynku — kamienne kolumny), więc przechył „rodzi się” z kopyt.
3. **Zgięcia stawów jak u byka:** przednie kolano (nadgarstek) wychodzi do przodu, a podudzie składa się do tyłu; tylny staw skokowy wychodzi do tyłu. Kopyto przy oderwaniu podwija się (zgięcie pęciny).
4. **Szarża a osłony:** byk **widzi ściany** (hamuje przed nimi w poślizgu — bez ogłuszenia), ale **nie zdąży wyhamować przed osłoną** (cokół geniusza, cedrowa kolumna) → zderzenie, ogłuszenie z głową nisko (twarz na wysokości strzału). Tak osłona jest narzędziem, nie przypadkiem. Osłony to znaczniki `lamassu_cover_<n>` (dopisane w strefie Asyrii, `Guardian.points[&"cover"]`).
5. **Podmuch to stożek wiatru**, nie pocisk: zapowiedź = skrzydła rozkładają się i wznoszą (0,8 s) + łuk stożka na posadzce (`GroundMark.arc`); cios = zamach skrzydeł do przodu, strażnik w stożku i bez osłony (promień od piersi byka do jego piersi) zostaje wyrzucony w tył kilka metrów (impuls + wiatr przez 0,5 s) i dostaje garść żwiru (6 obr.). Osłona zatrzymuje wiatr.
6. **Skok w fazie 3** ląduje tam, gdzie strażnik stał na początku zapowiedzi: cień byka pojawia się w miejscu lądowania **1,25 s wcześniej** (≥ 1 s z projektu), lot to balistyczny łuk z biciem skrzydeł; lądowanie = obrażenia pod cieniem + fala do przeskoczenia.
7. **Cokół:** posąg stoi na alabastrowym cokole (0,5 m, 2,2 × 4,6 m) przy północnej ścianie; przebudzenie to zejście z cokołu — stęp `LamassuGait` z wysokością posadzki pod kopytem (`floor_of`: wierzch cokołu nad jego obrysem, posadzka dalej), korzeń ciała prowadzony kinematycznie i opadający nad krawędzią, cztery tąpnięcia; potem zwykła fizyka. **Po przebudzeniu cokół jest dla byka stopniem** (wyjątek kolizji zostaje, kopyta wchodzą na wierzch), nie przeszkodą — inaczej byk klinował się między cokołem a ścianą po szarży na północ.
8. **Wojownicy z reliefów (faza 2) — bez dublowania:** wywołuje ich `GuardianKeeper.PHASE_CALLS` (runda integracji 2) na znacznikach `lamassu_relief_<n>`, raz na noc. Lamassu tylko gra przemianę (staje dęba, ryczy, pęknięcia rozbłyskują w tej samej chwili).
9. **Obrażenia:** twarz ×1,5 (słaby punkt, złoty znacznik), korona ×1 (słaby punkt; po 160 przyjętych obrażeniach odpada jako bryła, kikut zostaje słabym punktem), kamień ×0,1 (odpryski, szary znacznik), skrzydła ×0,1, ale **się wyszczerbiają** (odłamki co 25 obr., końcówka odpada po 120).

---

## Liczby walki (Nocna zmiana; Podwójna ×1,2 zdrowia, obrażenia przez `damage_scale`)

| Element | Wartość |
|---|---|
| Zdrowie | **1900** (strojone botem: `--bot` ok. 34 s; 1500 z planu dawało 24 s); fazy: 2 < 66 %, 3 < 33 % |
| Przebudzenie | 3,0 s: pył się sypie, głowa podnosi się i odwraca, skrzydła rozkładają się ze zgrzytem i trzaskiem, zejście z cokołu (cztery tąpnięcia) |
| Skradanie | 1,6 / 1,9 / 2,2 m/s, skręt 0,9 / 1,05 / 1,2 rad/s; przy ostrym skręcie idzie łukiem (min. 0,9 m/s), podchodzi na ~6,5 m (w zasięg tupnięcia) |
| Przerwa między atakami | 1,9 / 1,5 / 1,2 s |
| **Szarża** | zapowiedź 1,0 / 0,95 / 0,85 s (grzebie kopytem, głowa w dół, śledzi strażnika do 0,3 s przed biegiem); bieg 11,5 / 12,5 / 13 m/s (rozpęd 0,35 s), do 5 m za strażnika (najwyżej 2,4 s); 32 obr. + odrzut w bok; ściana → poślizg (1,0 s); osłona → **ogłuszenie 2,6 / 2,3 / 2,0 s** |
| **Podmuch** | zapowiedź 0,8 / 0,8 / 0,7 s; stożek 13 m, ±32°; impuls 10 m/s + 3,5 m/s w górę, wiatr 18 m/s² przez 0,5 s (≈ 4–5 m odrzutu); 6 obr.; osłona blokuje |
| **Tupnięcie** | zapowiedź 0,75 / 0,7 / 0,65 s (staje dęba); pod kopytami 24 obr. (1,8 m); fala 14 obr. do 10 m, 9 m/s (przeskocz) |
| **Skok** (faza 3) | zapowiedź 1,25 s (przysiad + lot, cień w miejscu lądowania od początku); 6–15 m; pod cieniem 28 obr. (2,4 m); fala 16 obr. do 11 m, 10 m/s |
| Przemiana fazy 2 | 2,4 s: staje dęba, skrzydła w pełni, ryk; pęknięcia rozbłyskują (zestaw `lamassu_cracked`); wojownicy schodzą z reliefów (opiekun) |
| Przemiana fazy 3 | 2,0 s: trzy uderzenia skrzydeł, unosi się nad posadzkę i ciężko opada |
| Wagi wyboru | faza 1: szarża 3, podmuch 2,5, tupnięcie 3 (blisko); faza 2: szarża 3,5; faza 3: **podmuch 4**, skok 3,5, tupnięcie 2,5, szarża 2 |
| Pokonanie | pęknięcia rozbłyskują, klęka (przód, potem tył), skrzydła się odłamują, rozpad na bryły; Pieczęć Skrzydła `seal_wing` + odłamek `shard_assyria` na `arena_lamassu_reward`; 60 Pyłu |

---

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/game/floor1/guardians/lamassu_brain.gd` (nowy) | `LamassuBrain`: stany `DORMANT, WAKING, IDLE, ATTACK, STUNNED, PHASE_SHIFT, DEAD`, ataki `CHARGE, GUST, STOMP, HOP`, etapy i czasy, wybór (zasięg, kąt, wagi na fazę, bez trzech z rzędu), koniec szarży (`end_charge(crashed)`), liczby walki |
| `src/game/floor1/guardians/lamassu_gait.gd` (nowy) | `LamassuGait`: kopyta w świecie, tryby `STAND, WALK, GALLOP, SKID, HOLD, AIR`, kolejki stępu i galopu, przewidywanie lądowania, kroki na komendę (`step_to`), sygnały `lifted`/`planted` |
| `src/game/floor1/guardians/lamassu_rig.gd` (nowy) | `LamassuRig`: model `lamassu` lub szarość, `Pose` → części (tułów z osią obrotu, głowa, skrzydła z końcówkami, ogon, 4 nogi IK z kopytem w poziomie), blask (`awake/glow/flash`), zestaw `lamassu_cracked`, korona i końcówki skrzydeł odpadają |
| `src/game/floor1/guardians/lamassu_moves.gd` (nowy) | `LamassuMoves`: klipy (przebudzenie, grzebanie, bieg, poślizg, ogłuszenie, podmuch, tupnięcie, skok, przemiany), sprężyny (głowa, osiadanie, kołysanie, przechył od przyspieszenia, końcówki skrzydeł, ogon), oddech kamienia |
| `src/game/floor1/guardians/lamassu.gd` (nowy) | `Lamassu extends Guardian`: ciało, strefy, cokół, skradanie, ataki i efekty, przemiany, `dress_arena()` |
| `src/game/floor1/guardians/lamassu_plinth.gd` (nowy) | `LamassuPlinth`: alabastrowy cokół (model `asy_plinth_low` lub szarość), kolizja |
| `src/game/floor1/guardians/wing_gust.gd` (nowy) | `WingGust`: smugi pyłu i drobny gruz lecące stożkiem |
| `src/game/floor1/guardians/lamassu_fall.gd` (nowy) | `LamassuFall`: upadek (pęknięcia, klęczenie, skrzydła odpadają, bryły) |
| `src/level/floor1/zones/assyria.gd` (zmiana) | znaczniki `lamassu_cover_<n>` (6 osłon) i `arena_lamassu_reward` |
| `tests/unit/test_lamassu_brain.gd` | mózg |
| `tests/unit/test_lamassu_gait.gd` | chód: kolejność, ≥ 3 kopyta w stępie, kopyta nie ślizgają się, powrót pod ciało, galop z fazą lotu |
| `tests/integration/test_lamassu_parts.gd` | rig (spoczynek, IK do celu, skrzydła, szarość, pęknięcia, korona/skrzydło odpadają), choreografia (tupnięcie w punkt, głowa nisko w ogłuszeniu), cokół, stożek podmuchu |
| `tests/integration/test_lamassu.gd` | walka w prawdziwym Dziedzińcu: budzenie i zejście z cokołu, zapowiedzi ≥ 0,6 s, słabe punkty, szarża w osłonę → ogłuszenie, szarża w ścianę → poślizg, podmuch vs osłona, fala tupnięcia do przeskoczenia, skok (cień ≥ 1 s), fazy (pęknięcia, reliefy), upadek → nagrody na zawsze, ucieczka, brak strzelania spoza areny |
| `tests/scenarios/guardian_scenario.gd` (zmiana) | momenty Lamassu dla `run_guardian.sh lamassu --dry/--shots/--bot` |
| `docs/Nocna-Zmiana-specyfikacja.md` (zmiana) | §4.7 Lamassu |

---

## Kontrakty (nowe)

```gdscript
LamassuBrain.stage_length(kind, stage, phase) -> float
brain.clip_time() -> float              # 0..1 zapowiedź, 1..2 cios, 2..3 powrót
brain.end_charge(crashed: bool)         # węzeł: bieg się skończył (osłona → STUNNED)
LamassuGait.place(root: Transform3D)    # cztery kopyta pod ciałem
gait.update(delta, root, velocity, turn_rate, mode)
gait.step_to(leg, world_point, seconds) # krok na komendę (zejście z cokołu)
gait.feet[leg] / gait.planted(leg)      # leg: 0 fl, 1 fr, 2 bl, 3 br
LamassuRig.Pose / rig.apply(pose, delta) / rig.contact(leg) -> Vector3
Lamassu.cover_hit(point) -> bool        # punkt zderzenia leży przy osłonie
Lamassu.gust_reaches(origin, forward, point) -> bool   # statycznie: stożek
```

---

### Zadanie 1: Mózg (`LamassuBrain`)

**Pliki:** nowy `lamassu_brain.gd`; test `tests/unit/test_lamassu_brain.gd`.

- [x] **Krok 1 — testy (czerwone):** przebudzenie trwa `WAKE_TIME`, potem IDLE i atak po przerwie; daleko i na wprost → szarża, blisko → tupnięcie/podmuch, za plecami → nic (obraca się); każda zapowiedź każdego ataku w każdej fazie ≥ `Guardian.MIN_TELEGRAPH`, skok ≥ 1,0 s; ten sam atak nigdy 3 razy z rzędu (300 losowań); `end_charge(true)` → STUNNED na `STUN_TIME`, potem IDLE; `end_charge(false)` → poślizg (RECOVER); faza 2 → PHASE_SHIFT po bieżącym ataku (i po ogłuszeniu); faza 3 → skok dostępny, podmuch częstszy (udział w 400 losowaniach); `reset()` → DORMANT, faza 1; ten sam seed → ta sama sekwencja.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 2: Chód (`LamassuGait`)

**Pliki:** nowy `lamassu_gait.gd`; test `tests/unit/test_lamassu_gait.gd`.

- [x] **Krok 1 — testy:** po `place()` kopyta pod znacznikami `contact_*` spoczynku; stęp: kolejność oderwań LT, LP, PT, PP, nigdy mniej niż 3 kopyta na posadzce, kopyto przyszpilone nie rusza się w świecie, a lądujące jest przed swoim miejscem; po zatrzymaniu kopyta wracają pod ciało (≤ 0,2 m) i chód staje; obrót w miejscu przestawia kopyta; galop: oderwania parami (tył, potem przód) i chwila bez kopyt na posadzce; `SKID`: kopyta jadą z ciałem; `step_to` prowadzi kopyto w zadanym czasie.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 3: Ciało (`LamassuRig`), cokół, znaczniki areny

**Pliki:** nowe `lamassu_rig.gd`, `lamassu_plinth.gd`; zmiana `assyria.gd`; test `tests/integration/test_lamassu_parts.gd`.

- [x] **Krok 1 — testy:** poza spoczynku = model w spoczynku (co do centymetra); IK: przy obniżonym i pochylonym tułowiu znaczniki `contact_*` leżą ≤ 3 cm od celów, kolano przednie wychodzi do przodu, staw skokowy do tyłu, kopyto poziomo; skrzydła rozłożone: końcówki wyżej i dalej na boki niż w spoczynku; szarość ma te same nazwy części i łańcuchy; `crack(true)` przełącza materiały na `lamassu_cracked`; korona i końcówka skrzydła odpadają jako ciała fizyczne; cokół ma kolizję (wierzch 0,5 m); w strefie Asyrii jest 6 znaczników osłon i `arena_lamassu_reward`.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 4: Choreografia (`LamassuMoves`)

**Pliki:** nowy `lamassu_moves.gd`; testy w `test_lamassu_parts.gd`.

- [x] **Krok 1 — testy:** uśpiony = poza spoczynku; w chwili ciosu tupnięcia przednie kopyta na posadzce przy punkcie tupnięcia (≤ 0,35 m), w zapowiedzi wysoko (staje dęba, przód tułowia w górę); podmuch: w zapowiedzi skrzydła wysoko i szeroko, w ciosie końcówki zostają z tyłu (sprężyna); ogłuszenie: twarz niżej niż 2,4 m; grzebanie: prawe przednie kopyto się rusza, głowa w dół.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 5: Lamassu w prawdziwym Dziedzińcu — przebudzenie, skradanie, strefy, szarża, podmuch, tupnięcie

**Pliki:** nowe `lamassu.gd`, `wing_gust.gd`; test `tests/integration/test_lamassu.gd`.

- [x] **Krok 1 — testy:** stoi na cokole na znaczniku, śpi; strażnik za linią startu → `guardian_awakened`, pasek z imieniem, zejście z cokołu na posadzkę; 40 s walki z różnych miejsc: każda zapowiedź ≥ 0,6 s, wszystkie trzy ataki fazy 1; twarz ×1,5 (złoty), korona ×1, kamień ×0,1 (szary), promień z oczu strażnika trafia twarz przed brodą; szarża w strażnika za cokołem geniusza → zderzenie, STUNNED, strażnik cały, twarz nisko; szarża na otwartej przestrzeni → trafia stojącego w pasie, hamuje przed ścianą bez ogłuszenia, nie wychodzi z dziedzińca; podmuch: na otwartej przestrzeni ≥ 3 m odrzutu, za osłoną < 0,5 m; fala tupnięcia rani stojącego, nie skaczącego.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 6: Fazy 2 i 3 — pęknięcia, reliefy, skoki

**Pliki:** zmiany `lamassu.gd`, `lamassu_moves.gd`; testy w `test_lamassu.gd`.

- [x] **Krok 1 — testy:** < 66 % → przemiana (bez ataków), materiały `lamassu_cracked`, 6 eksponatów z reliefów przy znacznikach `lamassu_relief_<n>` (raz na noc); < 33 % → przemiana, potem skok: cień w miejscu lądowania ≥ 1 s przed lądowaniem, lądowanie ≤ 1 m od cienia, fala; skok nie ląduje na osłonie ani poza dziedzińcem.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 7: Upadek, nagrody, ucieczka, strzały spoza areny

**Pliki:** nowy `lamassu_fall.gd`; zmiana `lamassu.gd`; testy w `test_lamassu.gd`.

- [x] **Krok 1 — testy:** śmierć przez twarz → `LamassuFall` (klęka, skrzydła odpadają, > 15 brył), `seal_wing` + `shard_assyria` na `arena_lamassu_reward`, zapis; następnej nocy brak Lamassu, cokół stoi; ucieczka na 6 s → z powrotem na cokole, pełne zdrowie, korona i skrzydła na miejscu, zwykłe materiały; trafienie spoza areny nic nie robi i nie budzi.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 8: Arena deweloperska

**Pliki:** zmiana `tests/scenarios/guardian_scenario.gd`.

- [x] **Krok 1:** `bash tools/run_guardian.sh lamassu --dry`: śpi na cokole, budzi się (skrzydła), schodzi, skrada się, grzebie, szarża, zderzenie i ogłuszenie, poślizg, podmuch, tupnięcie, przemiana 2 (reliefy), przemiana 3, skok (cień, lot, lądowanie), upadek (22 momenty, 0 chybionych); `--bot` mierzy długość walki (strojenie zdrowia: 1500 → 24 s, 2300 → 53 s, 1900 → ok. 34 s). **Krok 2 — commit.**

### Zadanie 9: Dokumentacja, scalenie `pietro-1`, pełny zestaw testów

- [x] Specyfikacja §4.7 (Lamassu), stan planu, scalenie `pietro-1`, pełne `bash tools/run_tests.sh` bez linii ERROR, commit.

---

## Ryzyka i odpowiedzi
| Ryzyko | Odpowiedź |
|---|---|
| Krótkie, proste nogi nie sięgają przy długim kroku (kopyta „pływają”) | ciało osiada do zasięgu nóg (przód i tył osobno → przechył), krok przycięty do zasięgu; test „kontakt ≤ 3 cm” |
| Szarża przenika gracza albo staje na nim | podczas biegu maska kolizji bez gracza; trafienie liczy pas przed piersią (jak T-Rex) |
| Skok kończy się w ścianie/osłonie | miejsce lądowania sprawdzone (pokój areny z marginesem, z dala od osłon), lot kinematyczny |
| Szarża utyka na cokole/geometrii | poślizg przy każdym zderzeniu poza osłoną; skradanie omija osłony (objazdy) |
| Za dużo naraz w fazie 2 (6 wojowników + byk) | przemiana daje 2,4 s oddechu, zaopatrzenie fazy 2 leży na znacznikach |
| Nawigacja nie zna cokołu | cokół jest pod ścianą (poza drogą), zostaje co noc |

---

## Stan prac / co dalej (8.10)

**Zadania 1–9 wykonane, zestaw Lamassu zielony** (brain 15, gait 8, parts 12, integracja 12 = 47 testów), `run_guardian.sh lamassu --dry` 22 momenty bez chybień, `--bot` ok. 34 s przy 1900 zdrowia. Gałąź `guard-lamassu` scalona z `pietro-1` (ostatni stan: `4b3ded2`, „Already up to date" przy oddaniu). **Pełny zestaw:** 1969 zielonych, 1 czerwony — wspólny test `test_floor1_game_guardians :: test_every_guardian_stands_on_its_marker` wymagał strażnika ≤ 0,5 m od znacznika, a Lamassu stoi 0,5 m wyżej na cokole; test poprawiony (odległość w poziomie + tolerancja na cokół), plik przetestowany ponownie (52 zielone razem z zestawem Lamassu). Prace **zakończone na polecenie kontrolera (limit użycia)**.

**Przegląd kodu wykonany, poprawki naniesione (10.10), czeka na scalenie do `pietro-1` (robi kontroler).** Poprawki: `_on_defeated` woła `LamassuFall.make` wprost (bez `ResourceLoader`/`load`/`call`); śmiertelne trafienie w locie (łuk skoku do 2,4 m, unoszenie 0,9 m) najpierw sprowadza byka na posadzkę dziedzińca (`_floor_under`), stawia kopyta (`gait.place` + ponowne `rig.apply`), dopiero potem upadek — dwa nowe testy integracyjne (skok, unoszenie), suma zestawu Lamassu 49 testów; usunięty wrapper `_frozen_now()`; opis pola `time` w `LamassuMoves`; komentarz przy rozgrzewaniu materiału odłamków w `LamassuRig.crack`; nagłówek `guardian_scenario.gd` wymienia Lamassu; wspólny test strażników znów sprawdza wszystkich oprócz Lamassu ściśle (odległość 3D < 0,5 m), a Lamassu — w poziomie i na wysokości cokołu. W kodzie nic nie zostało do zrobienia — zostaje lista „Do sprawdzenia w oknie" poniżej.

**Co dalej (dokładnie):** 1) gdy okna będą dozwolone — `bash tools/run_guardian.sh lamassu --shots` i przejście listy poniżej; 2) ewentualne strojenie po teście właściciela: zdrowie (`Lamassu._init`, 1900), `LamassuBrain.KEEP_DISTANCE` (6,5), wagi wyboru ataków (`LamassuBrain.WEIGHTS`).

**Zrobione (pliki):** `lamassu_brain.gd`, `lamassu_gait.gd`, `lamassu_rig.gd`, `lamassu_moves.gd`, `lamassu.gd`, `lamassu_plinth.gd`, `wing_gust.gd`, `lamassu_fall.gd`; `assyria.gd` (6 znaczników `lamassu_cover_<n>` na geniuszach i cedrach, `arena_lamassu_reward` na środku dziedzińca); `guardian_keeper.gd` (`PHASE_CALLS` relief → `relief_warrior`, bo wróg istnieje po scaleniu `enemies-west`); `guardian_scenario.gd` (sekcja Lamassu dopisana na końcu); specyfikacja §4.7.

**Odstępstwa od planu (świadome):**
- Zdrowie 1900 zamiast 1500 (bot: 1500 → 24 s, 2300 → 53 s; cel ~40 s jak Kolos/Kentaur).
- `KEEP_DISTANCE` 6,5 m zamiast 8 (inaczej tupnięcie o zasięgu 7,5 m nigdy nie wchodziło w grę przy strażniku trzymającym dystans).
- Cokół po przebudzeniu jest dla byka stopniem (stały wyjątek kolizji; kopyta wchodzą na wierzch dzięki `floor_of`), bo byk klinował się między cokołem a północną ścianą po szarży z przelotem i stał tam, szarżując na 1 m.
- Zejście z cokołu: nie cztery kroki „na komendę", lecz stęp `LamassuGait` z wysokością posadzki pod kopytem (korzeń kinematyczny, opadający nad krawędzią); `step_to` zostało w API (test jednostkowy) do użytku przez inne momenty.
- Pęknięcia rozbłyskują w pierwszej odegranej przemianie (do fazy 2 albo od razu do 3, gdy jedno trafienie zbija dwa progi).
- Skrzydła: spread (obrót wokół Z, na zewnątrz) + raise (wokół X, koniec w górę) + beat (wokół Y, do przodu) — sam obrót wokół Z z katalogu nie unosi końców (płyta leży wzdłuż grzbietu), stąd osobny kanał `wing_raise`.

**Do sprawdzenia w oknie** (`bash tools/run_guardian.sh lamassu --shots`, 22 momenty; teraz zakaz okien):
1. Zejście z cokołu: czy kopyta stają na wierzchu cokołu i na posadzce bez pływania, czy przechył tułowia przy krawędzi czyta się jako ciężar.
2. IK na realnym modelu `lamassu`: kolana do przodu, stawy skokowe do tyłu, kopyta poziomo w stępie i galopie; osiadanie ciała przy długim kroku (czy nie za głębokie).
3. Skrzydła: rozłożenie/uniesienie/zamach podmuchu (kąty 1,25 / 1,05 / 2,1 rad), końcówki na sprężynie; czy płyty nie przecinają tułowia; `WingGust` (smugi pyłu wzdłuż stożka, żwir).
4. Tupnięcie: staje dęba (0,8 rad), kopyta lądują na krążku; fala.
5. Skok: cień 1,25 s wcześniej, łuk 2,4 m, lądowanie; przemiana 3 (unoszenie 0,9 m).
6. Ogłuszenie: twarz < 2,4 m, poświata pęknięć; grzebanie kopytem (kurz).
7. Upadek: klęknięcie, odpadanie skrzydeł w całości, rozpad na bryły (2 cięcia na część), światło; także po śmiertelnym trafieniu w locie (łuk skoku) i w unoszeniu (przemiana 3) — czy klęka na posadzce, bez skoku pozy z powietrza.
8. Znaczniki na posadzce (pas szarży, łuk stożka, krążek, cień) czytelne z poziomu oczu; dźwięki `lamassu_charge/gust/stomp`.
9. Cokół jako stopień: czy byk wchodzący kopytami na cokół nie wygląda dziwnie (jeśli tak — alternatywa: kolizja cokołu dla byka tylko w pasie 1 m od ściany).
10. Faza 2: czy wojownicy z reliefów widocznie wychodzą z płyt (pojawiają się 0,6 m od znacznika płyty) — czy nie wyglądają, jakby stali przed płytą od początku.

**Uwagi:** pliki wspólne zmienione minimalnie (`guardian_scenario.gd` — dopisek na końcu i dwa `elif`; `guardian_keeper.gd` — jedna stała; `assyria.gd` — dopisek w `_courtyard`). `LimbIK`, `MotionClip`, `Spring`, `GroundMark`, `ShockwaveRing` użyte bez zmian.
