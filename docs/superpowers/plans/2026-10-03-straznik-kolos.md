# Strażnik Egiptu — Kolos Ramzesa (plan wykonawczy)

> **Dla wykonawcy:** zadania po kolei, TDD (najpierw test, potem kod), commit po każdym zadaniu. Kroki z `- [ ]`.
> Gałąź `guard-colossus` (od `pietro-1`). Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.1, **§7.4**, §6, §10. Baza: `src/game/floor1/guardian.gd`, `guardian_keeper.gd`, plan W1 `docs/superpowers/plans/2026-10-03-p1-w1-integracja.md`. Model: `docs/art/kit-pietro1-egipt.md` §5.

**Cel:** pierwszy prawdziwy strażnik Piętra I zamiast manekina — siedzący, 9-metrowy granitowy kolos w Sali Kolosa (24 × 24 m, 14 m), walka 2–3 min w trzech fazach, czytelna i uczciwa (każdy atak ≥ 0,6 s zapowiedzi), z ciężką, żywą animacją. **Wzorzec dla pięciu kolejnych strażników**: zestaw narzędzi animacji, strefy trafień, rekwizyty areny i scenariusz deweloperski mają się dać użyć ponownie bez zmian.

**Architektura (jeden akapit):** czysta logika w `RefCounted` (bez sceny): `ColossusBrain` (stany, wybór ataku, czasy, fazy, rój), `ColossusGait` (rytm kroków), zestaw ruchu `MotionClip` (klatki kluczowe z krzywymi), `Spring` (sprężyny ruchu wtórnego), `LimbIK` (celowanie kończyną z „ścięgnami światła”, IK nogi w płaszczyźnie). Węzeł `Colossus extends Guardian` składa ciało (`ColossusRig` na modelu `colossus` z `ArtLibrary`, szarość gdy brak modelu), strefy trafień (`GuardianZone` → `take_zone_damage`), wykonuje ataki (dłoń, przedramię, promień, rój, wstawanie, chód, omiatanie) z efektami (`GroundMark`, `ShockwaveRing`, `SunBeam`, kurz, gruz, światło, wstrząs kamery zależny od odległości). Rekwizyty areny stawia strażnikowi `GuardianKeeper` przez statyczne `dress_arena()` skryptu strażnika (także po jego pokonaniu): tron `ColossusThrone` i 7 kolumn `ColossusColumn` (pękają od promienia, po 3. trafieniu kikut i fizyczny gruz). Rój skarabeuszy to prosty `ScarabSwarm extends Enemy` (jedna jednostka, 30 owadów w `MultiMesh`). Upadek: `ColossusFall` przejmuje model i rozsypuje go na fizyczne bryły.

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh [--filter=...]` (bez okna, `--fixed-fps 60`), scenariusz `bash tools/run_guardian.sh colossus --dry` (bez okna).

---

## Decyzja: jak animujemy strażników (wzorzec)

**Wybór: animacja kodem — klatki kluczowe zapisane w GDScripcie (`MotionClip`) + sprężyny (`Spring`) + IK (`LimbIK`), na sztywnych częściach modelu.** Nie eksportujemy akcji z Blendera (`AnimationPlayer`).

Dlaczego:
1. **Ciosy muszą trafiać tam, gdzie stoi strażnik.** Dłoń spada na zablokowany punkt (cień na posadzce), przedramię zamiata pas na wybranym promieniu, promień śledzi gracza, stopy przy chodzie stoją na posadzce. Klip z Blendera zna jedną trajektorię; tu ruch jest *parametryczny* (cel, odległość, strona), więc klatki kluczowe opisują **kształt w czasie** (unieś, napnij, spadnij, odbij się, osiądź), a IK — **gdzie**.
2. **Czas zapowiedzi = czas animacji, z jednego źródła.** Klip jest próbkowany w czasie znormalizowanym etapu (0–1 zapowiedź, 1–2 cios, 2–3 powrót); długości etapów podaje mózg (dla fazy). Zmiana balansu nie rozjeżdża animacji, a test „≥ 0,6 s” mierzy to samo, co widzi gracz.
3. **Model jest zbiorem sztywnych części z osiami w stawach** (projekt §10.2: „modele z rigiem pozy… animacja kodem”), nie skórą na szkielecie; Blender nie daje tu nic, czego nie da sterowanie węzłami — a każda przeróbka modelu nie psuje animacji.
4. **Testowalność bez okna:** poza w danej chwili to czysta funkcja (klip, czas, cel), sprawdzalna w testach jednostkowych (np. „w chwili uderzenia dłoń jest w punkcie cienia”).

Kiedy klatki z Blendera mają sens: długie, nieinteraktywne występy wielu stawów modelu ze skórą (np. przerywnik). Dla obecnych strażników — nie.

**Zasady ruchu (dla wszystkich strażników):** antycypacja przed każdym ruchem (zamach w przeciwną stronę, barki prowadzą ramię), wejście/wyjście z łagodną krzywą (`IN_OUT`), uderzenie z przyspieszeniem (`IN`), przestrzał i osiadanie (`OUT_BACK` + sprężyna), ruch wtórny (głowa śledzi strażnika z opóźnieniem na sprężynie, tułów jeszcze wolniej), oddech kamienia (ledwo widoczny), kurz/gruz/iskry/światło dokładnie w chwili uderzenia, wstrząs kamery malejący z odległością.

**Rozwiązanie zasięgu („ścięgna światła”):** siedzący kolos ma barki na 5,7 m, a ramię 3,35 m — fizycznie nie sięga posadzki. Kamienne człony ramienia rozsuwają się więc w stawach, a szczeliny wypełnia złote światło słońca (to samo co w oczach i pęknięciach): bark, łokieć i nadgarstek odsuwają się wzdłuż osi kości. To czytelny, magiczny podpis „przebudzonego posągu” i zapowiedź (szwy rozjaśniają się przed ciosem).

---

## Liczby walki (Nocna zmiana; Podwójna ×1,2 zdrowia, obrażenia przez `damage_scale` jak eksponaty)

| Element | Wartość |
|---|---|
| Zdrowie | 1100; fazy: 2 < 66 %, 3 < 33 % |
| Obrażenia poza słabymi punktami | ×0,1 (iskry, szary znacznik) |
| Słabe punkty | **ureusz** (zawsze), **pęknięcia 1–3** (po odpadnięciu płyt) — pełne obrażenia + mnożnik broni |
| Płyty na piersi | odpadają w fazie 2; wcześniej każda pęka od 40 obrażeń z wybuchów (raca) |
| Przebudzenie | 2,6 s (oczy zapłon, kurz, tron zgrzyta, tułów obraca się) |
| Przerwa między atakami | 1,7 / 1,3 / 1,2 s (faza 1/2/3) |
| **Dłoń** | zapowiedź 0,95 / 0,85 / 0,8 s (cień dłoni rośnie, ramię wznosi się); 34 obr., promień 2,4 m, odrzut; fala 10 obr. do 7 m (przeskocz); dłoń leży 1,2 / 1,0 / 0,9 s; zasięg 4,5–13,5 m, łuk ±110°, tylko gdy linia bark → cel wolna |
| **Przedramię** | zapowiedź 1,0 / 0,9 s (ramię cofa się, zgrzyt, łuk na posadzce); zamach 0,6 / 0,55 s nisko (0,45 m) w pasie 3,8–8 m; 24 obr. + odrzut w bok; tylko fazy 1–2 |
| **Promień z oczu** | ładowanie 1,2 / 1,0 s; ogień 2,2 / 2,6 s, śledzi 15° / 24° na s, zaczyna od miejsca sprzed 0,3 s; 30 obr./s; zatrzymuje go świat (kolumny, tron) |
| **Kolumny** | 7 osłon; 1. trafienie promieniem: odpryski, 2.: pęknięta tekstura, 3.: kikut 5 m + spadające bębny |
| **Rój** (faza 2+) | zapowiedź 0,9 s (otwór w tronie świeci, szum); rój 40 HP, 6 obr./s w kontakcie, śrut i ogień ×2; co 14 / 11 s, najwyżej 2 / 3 żywe |
| **Przemiana fazy 2** | 2,2 s: kolos odchyla się, płyty odpadają (fizyka), pęknięcia rozbłyskują |
| **Wstawanie** (faza 3) | 3,4 s: antycypacja, podparcie dłońmi, miednica w górę i do przodu, stopy schodzą z cokołu (dwa tąpnięcia), wyprost z przestrzałem; wodospad kurzu, mocny wstrząs |
| **Chód** (faza 3) | krok 1,6 s (stopa w górze 0,75 s = zapowiedź), 1,06 m/s, trzyma 6,5 m; każde tąpnięcie: fala 12 obr. do 8 m (przeskocz) i wstrząs |
| **Omiatanie** (faza 3) | ładowanie 1,1 s (pas na posadzce świeci), łuk 120° w 2,0 s; 28 obr. raz na przejście; osłona albo wyjście z pasu |
| Pokonanie | oczy gasną, pęknięcia rozbłyskują, przewrócenie i rozpad na bryły (fizyka); pieczęć + odłamek na znaczniku `arena_colossus_reward`; 60 Pyłu |

Szacunek czasu: celny pistolet w ureusz ≈ 40 obr./trafienie. Pomiar `bash tools/run_guardian.sh colossus --bot` (strażnik-bot bez uników krąży w 11 m i strzela 2,5 razy na s w widoczny słaby punkt, 45 % trafień): **36 s** do upadku (fazy w 16. i 25. s), 230 obrażeń przyjętych bez uników. Gracz strzela ~35–50 % czasu (uniki, osłony, przeładowania) i trafia rzadziej → ok. **2–3 min**. Do sprawdzenia w grze.

---

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/game/floor1/guardians/motion_clip.gd` (nowy) | `MotionClip`: kanały klatek kluczowych z krzywymi (`LINEAR, IN, OUT, IN_OUT, OUT_BACK, HOLD`), próbkowanie w czasie |
| `src/game/floor1/guardians/spring.gd` (nowy) | `Spring`: tłumiona sprężyna (częstotliwość, tłumienie) dla ruchu wtórnego |
| `src/game/floor1/guardians/limb_ik.gd` (nowy) | `LimbIK`: obrót kości na cel z najmniejszym łukiem, rozsunięcie stawu (ścięgno), IK dwóch kości w płaszczyźnie |
| `src/game/floor1/guardians/ground_mark.gd` (nowy) | `GroundMark`: znak zapowiedzi na posadzce (cień dłoni, łuk, pas), rośnie i ciemnieje z postępem |
| `src/game/floor1/guardians/shockwave_ring.gd` (nowy) | `ShockwaveRing`: rozchodząca się fala przy posadzce; rani raz, gdy przejdzie pod stojącym (skok ratuje) |
| `src/game/floor1/guardian_zone.gd` (nowy) | `GuardianZone`: odbiorca trafień jednej strefy → `Guardian.take_zone_damage(info, zone)` |
| `src/game/floor1/guardian.gd` (zmiana, zgodna wstecz) | `take_zone_damage`, `hit_zone`, hooki `_hit_effects`, `_report_hit`, `reward_point()`, `damage_scale`, `freeze` chowa zapowiedzi (`_on_freeze`) |
| `src/game/floor1/guardian_keeper.gd` (zmiana) | skrypt strażnika z konwencji `guardians/<id>.gd` (rejestr ma pierwszeństwo), `dress_arena()` skryptu (także po pokonaniu), punkt nagrody `arena_<id>_reward` |
| `src/progression/difficulty_rules.gd` (zmiana) | `tune_guardian` ustawia też `damage_scale` |
| `src/level/floor1/zones/egypt.gd` (zmiana) | kolumny areny tylko jako znaczniki (stawia je strażnik), znacznik `arena_colossus_reward` |
| `src/game/floor1/guardians/colossus_brain.gd` (nowy) | `ColossusBrain`: stany, etapy ataku, wybór (zasięg, łuk, wolna linia, wagi, bez powtórek), fazy, rój, wstawanie, liczby walki |
| `src/game/floor1/guardians/colossus_gait.gd` (nowy) | `ColossusGait`: rytm kroków (podniesienie = zapowiedź, postawienie = tąpnięcie) |
| `src/game/floor1/guardians/colossus_rig.gd` (nowy) | `ColossusRig`: model `colossus` (lub szarość), poza → części, ramiona przez `LimbIK` ze ścięgnami światła, nogi IK, oczy/pęknięcia/szwy, płyty odpadają, strefy trafień na częściach |
| `src/game/floor1/guardians/colossus_moves.gd` (nowy) | `ColossusMoves`: klipy ruchów (dłoń, przedramię, promień, rój, przemiana, wstawanie), sprężyny głowy/tułowia, oddech, chód → `ColossusPose` |
| `src/game/floor1/guardians/colossus.gd` (nowy) | `Colossus extends Guardian`: ciało, strefy, ataki i efekty, kolizje siedząc/stojąc, chód, rój, `dress_arena()` |
| `src/game/floor1/guardians/sun_beam.gd` (nowy) | `SunBeam`: wiązka (rdzeń + poświata + światło + iskry), promień przez świat, test odcinek–kapsuła |
| `src/game/floor1/guardians/colossus_throne.gd` (nowy) | `ColossusThrone`: model `colossus_throne`, kolizje, otwory roju, pękanie przy wstawaniu |
| `src/game/floor1/guardians/colossus_column.gd` (nowy) | `ColossusColumn`: kolumna papirusowa (model `egypt_column_open`), 3 trafienia → kikut + spadające bębny |
| `src/game/floor1/guardians/colossus_fall.gd` (nowy) | `ColossusFall`: scena upadku po śmierci (oczy, pęknięcia, przewrócenie, rozpad na bryły) |
| `src/enemies/scarab_swarm.gd` (nowy) | `ScarabSwarm extends Enemy`: rój jako jeden wróg, 30 skarabeuszy w `MultiMesh`, kontakt, ×2 od śrutu i ognia, pętla dźwięku |
| `tests/unit/test_guardian_motion.gd` | `MotionClip`, `Spring`, `LimbIK` |
| `tests/unit/test_colossus_brain.gd` | mózg: przebudzenie, wybór ataku, zapowiedzi ≥ 0,6 s, fazy, rój, wstawanie, reset, chód |
| `tests/integration/test_colossus_parts.gd` | kolumna (3 trafienia), promień (blokada, kapsuła), fala, rig (dłoń w celu, poza stojąca), rój |
| `tests/integration/test_colossus.gd` | walka w prawdziwej Sali Kolosa: budzenie, słabe punkty, fazy, promień za kolumną, wstawanie, upadek → pieczęć i odłamek na zawsze, ucieczka |
| `tests/integration/test_floor1_game_guardians.gd` (zmiana) | testy manekina wymuszają manekina rejestrem (Kolos ma własne testy) |
| `tests/scenarios/guardian_scenario.gd/.tscn`, `tools/run_guardian.sh` (nowe) | arena deweloperska: prawdziwa Sala Kolosa, momenty walki, `--dry` bez okna, `--shots` na później |
| `docs/Nocna-Zmiana-specyfikacja.md` (zmiana) | §4.4 Kolos Ramzesa |

---

## Kontrakty (dla kolejnych strażników)

```gdscript
# Guardian (baza) — nowe
var hit_zone: StringName            # strefa bieżącego trafienia (w _damage_factor)
var damage_scale: float = 1.0       # trudność: mnożnik obrażeń strażnika
func take_zone_damage(info: DamageInfo, zone: StringName) -> void
func reward_point() -> Vector3      # gdzie padają pieczęć i odłamek (domyślnie global_position)
func _hit_effects(info: DamageInfo) -> void   # hook: iskry / pył przy trafieniu
func _report_hit(info: DamageInfo) -> void    # hook: znacznik trafienia (Events.hit_landed)
func _on_freeze() -> void                     # hook: świt (schowaj zapowiedzi)

# GuardianKeeper — konwencja
#   res://src/game/floor1/guardians/<id>.gd  = prawdziwy strażnik (bez rejestracji)
#   static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]  (opcjonalnie)
#   znacznik arena_<id>_reward = miejsce nagród (opcjonalnie)
static func script_for(id: StringName) -> Script

# GuardianZone
static func make(guardian: Guardian, zone: StringName) -> GuardianZone

# Zestaw ruchu
MotionClip.new().key(&"raise", 0.0, 0.0).key(&"raise", 0.7, 1.0, MotionClip.IN_OUT)
clip.sample(&"raise", t) -> float
Spring.new(frequency_hz, damping).step(target, delta) -> float
LimbIK.aim(rest: Basis, axis: Vector3, direction: Vector3) -> Basis
LimbIK.two_bone(l1, l2, reach) -> Vector2   # (kąt kości 1, kąt kości 2)
GroundMark.disc(radius) / .arc(r0, r1, from, to) ; mark.progress = 0..1
ShockwaveRing.make(center, max_radius, speed, damage, source) ; ring.target
```

---

### Zadanie 1: Zestaw ruchu (`MotionClip`, `Spring`, `LimbIK`)

**Pliki:** nowe `motion_clip.gd`, `spring.gd`, `limb_ik.gd`; test `tests/unit/test_guardian_motion.gd`.

- [x] **Krok 1 — testy (czerwone):** klip zwraca wartości kluczy w ich chwilach, między kluczami krzywą następnego klucza (`IN` < liniowa w połowie, `OUT` >, `IN_OUT` = 0,5 w połowie), `OUT_BACK` przekracza cel przed końcem, `HOLD` trzyma do następnego klucza, przed pierwszym / po ostatnim kluczu — wartości skrajne, nieznany kanał → wartość domyślna; `duration()`; sprężyna dochodzi do celu, przy tłumieniu < 1 przestrzeliwuje, przy 1 nie, stabilna przy dużym kroku; `LimbIK.aim` obraca oś kości na kierunek (kąt < 0,01), zostawia skręt najbliższy spoczynkowi; `two_bone` daje kąty, przy których koniec łańcucha jest w zadanej odległości, i prostą nogę dla zasięgu ≥ l1 + l2.
- [x] **Krok 2 — kod**, testy zielone. **Krok 3 — commit.**

### Zadanie 2: Mózg Kolosa (`ColossusBrain`, `ColossusGait`)

**Pliki:** nowe `colossus_brain.gd`, `colossus_gait.gd`; test `tests/unit/test_colossus_brain.gd`.

Stany `DORMANT, WAKING, IDLE, ATTACK, PHASE_SHIFT, STAND_UP, DEAD`; ataki `SLAM, SWEEP, BEAM, SWARM, BEAM_SWEEP`; etapy `TELEGRAPH, STRIKE, RECOVER` z sygnałami `telegraphed(attack)`, `struck(attack)`, `finished(attack)`. Wejście co klatkę: odległość, kąt do strażnika, wolna linia barku (dłoń), liczba rojów. Przemiany faz czekają na koniec ataku (bez przerwy po nim). Chód: `ColossusGait.update(delta, walking)` → `lifted(side)`, `planted(side)`.

- [x] **Krok 1 — testy:** przebudzenie trwa `WAKE_TIME`, potem IDLE i pierwszy atak po krótkiej przerwie; blisko → dłoń/przedramię, daleko → promień, za plecami (>110°) → nic poza rojem; dłoń nie, gdy linia barku zasłonięta; ten sam atak nigdy 3 razy z rzędu (200 losowań, ziarno); każda zapowiedź każdego ataku w każdej fazie ≥ `Guardian.MIN_TELEGRAPH`; faza 2 → `PHASE_SHIFT` po bieżącym ataku, potem rój (cooldown, limit żywych); faza 3 → `STAND_UP`, potem `standing`, bez przedramienia, z omiataniem; `reset()` → DORMANT, siedzi, faza 1; ten sam seed → ta sama sekwencja; krok: podniesienie ≥ 0,6 s przed postawieniem, stopy na zmianę.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 3: Baza strażnika, strefy, opiekun, arena w strefie Egiptu

**Pliki:** zmiany `guardian.gd`, `guardian_keeper.gd`, `difficulty_rules.gd`, `egypt.gd`, `test_floor1_game_guardians.gd`; nowy `guardian_zone.gd`.

- [x] **Krok 1 — testy:** (w `test_colossus.gd`) opiekun bierze skrypt z `guardians/colossus.gd`, a rejestr ma pierwszeństwo (manekin wymuszony w starych testach); `dress_arena` stawia tron i 7 kolumn także w noc po pokonaniu; nagrody leżą na `arena_colossus_reward`; trudność „double” → `damage_scale` 1,35; strefa `GuardianZone` przekazuje trafienie z nazwą strefy.
- [x] **Krok 2 — kod** (hooki zgodne wstecz: manekin bez zmian zachowania). **Krok 3 — commit.**

### Zadanie 4: Rekwizyty areny: tron, kolumny, promień, fala, znak na posadzce

**Pliki:** nowe `colossus_throne.gd`, `colossus_column.gd`, `sun_beam.gd`, `shockwave_ring.gd`, `ground_mark.gd`; test `tests/integration/test_colossus_parts.gd`.

- [x] **Krok 1 — testy:** kolumna: jedno trafienie na salwę (ten sam `burst` liczy się raz), po 2 — tekstura pęknięta, po 3 — kikut (kolizja ≈ 5 m), gruz to ciała fizyczne na warstwie DEBRIS; promień zatrzymuje się na kolumnie i zgłasza ją; odcinek–kapsuła (trafia/omija/nad głową); fala rani stojącego raz, skaczącego (stopy > 0,45 m) nie; tron ma kolizję cokołu i siedziska oraz otwory roju.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 5: Rig i ruchy Kolosa (`ColossusRig`, `ColossusMoves`)

**Pliki:** nowe `colossus_rig.gd`, `colossus_moves.gd`; testy w `test_colossus_parts.gd`.

- [x] **Krok 1 — testy:** poza spoczynku = model w spoczynku (oczy tlą się); w chwili uderzenia (czas klipu 1,0) dłoń (`hand_*`) jest ≤ 0,35 m od punktu cienia także 12 m dalej (ścięgna rozsunięte), w zapowiedzi dłoń wyżej niż w spoczynku (antycypacja); przedramię w zamachu przechodzi nisko (dłoń < 0,7 m nad posadzką) na promieniu pasa; poza stojąca: biodra 5,02 m, stopy na posadzce, szczyt korony > 10 m; płyty odpadają jako ciała fizyczne, pęknięcia świecą; szarość ma te same nazwy części.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 6: Kolos — fazy 1–2 w prawdziwej sali (dłoń, przedramię, promień, strefy)

**Pliki:** nowy `colossus.gd`; test `tests/integration/test_colossus.gd`.

- [x] **Krok 1 — testy:** stoi na znaczniku, śpi; strażnik w hali → `guardian_awakened`, pasek z imieniem; 40 s walki z różnych miejsc: każda zapowiedź ≥ 0,6 s od `telegraphed` do `struck`, wszystkie trzy ataki fazy 1; trafienie w ciało ×0,1 (szary znacznik), w ureusz pełne (złoty), w pęknięcie pod płytą ×0,1; raca rozbija płytę wcześniej; promień do strażnika za kolumną: zero obrażeń, kolumna liczy trafienie; na otwartej przestrzeni stojący strażnik dostaje obrażenia, uciekający w bok — nie zawsze (śledzenie ograniczone).
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 7: Faza 2 — płyty, pęknięcia, rój skarabeuszy

**Pliki:** nowy `src/enemies/scarab_swarm.gd`; zmiana `colossus.gd`; testy w `test_colossus.gd`, `test_colossus_parts.gd`.

- [x] **Krok 1 — testy:** < 66 % → przemiana (2,2 s, bez ataków), płyty odpadają, pęknięcia są słabymi punktami; rój wychodzi z otworu tronu po zapowiedzi, jest `ScarabSwarm`, ma 40 HP, śrut i ogień ×2, kontakt ≈ 6 obr./s, idzie do strażnika; najwyżej 2 żywe.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 8: Faza 3 — wstawanie, chód z falami, omiatanie

**Pliki:** zmiany `colossus.gd`, `colossus_moves.gd`, `colossus_rig.gd`; testy w `test_colossus.gd`.

- [x] **Krok 1 — testy:** < 33 % → `STAND_UP` (3,4 s), potem ciało 4,4 m przed tronem, biodra 5,02 m, kolizja stojącego; idzie do strażnika (zbliża się), każde postawienie stopy → fala i `struck(&"stomp")` ≥ 0,6 s po `telegraphed(&"stomp")`; omiatanie: zapowiedź ≥ 0,6 s, strażnik za kikutem bez obrażeń; nie wychodzi z sali.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 9: Upadek, nagrody, ucieczka

**Pliki:** nowy `colossus_fall.gd`; zmiana `colossus.gd`; testy w `test_colossus.gd`.

- [x] **Krok 1 — testy:** śmierć przez ureusz → `ColossusFall` w drzewie, bryły fizyczne po upadku, pieczęć `seal_sun` + odłamek `shard_egypt` na znaczniku nagrody, `GameState` zapisany, następnej nocy brak Kolosa, tron i kolumny stoją; ucieczka w fazie 3 → z powrotem na tronie, płyty na miejscu, pełne zdrowie, roje znikają.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 10: Arena deweloperska i scenariusz

**Pliki:** nowe `tests/scenarios/guardian_scenario.gd`, `.tscn`, `tools/run_guardian.sh`.

- [x] **Krok 1:** `bash tools/run_guardian.sh colossus --dry` (bez okna): prawdziwa Sala Kolosa, momenty: śpi, budzi się, dłoń (zapowiedź, uderzenie), przedramię, promień w kolumnę, przemiana, rój, wstawanie, chód, omiatanie, upadek; każdy moment sprawdza stan, „MISSED” przy niepowodzeniu, dziennik JSON w `tests/_out/guardian_colossus/`. `--shots` (okno, zrzuty) przygotowany na nocną sesję kontrolera.
- [x] **Krok 2 — commit.**

### Zadanie 11: Dokumentacja i pełny zestaw testów

- [x] Specyfikacja §4.4 (Kolos), stan planu, pełne `bash tools/run_tests.sh` (zielone), commit.

---

## Ryzyka i odpowiedzi
| Ryzyko | Odpowiedź |
|---|---|
| Ramię nie sięga posadzki (proporcje posągu) | ścięgna światła (rozsunięcie stawów) — styl, nie błąd; test „dłoń w celu” |
| Promień nie do uniknięcia | start w miejscu sprzed 0,3 s, ograniczone śledzenie, osłony; test „uciekający w bok” |
| Osłony znikną za szybko | 3 trafienia na kolumnę, kikut 5 m dalej osłania; tron osłania |
| Kolizja kolosa z własnym tronem | wyjątek kolizji siedząc, zdjęty po wstaniu |
| Ciężkie testy z całym piętrem | testy logiki bez sceny; w hali tylko kilka scenariuszy |
| Nawigacja nie zna nowych kolumn | rój przelatuje/ślizga się po walcu; kolumny poza wypieczoną siatką (świadomie) |

---

## Stan wykonania (3.10)

Wszystkie zadania 1–11 wykonane (TDD, commit po zadaniu). Testy: `test_guardian_motion` (7), `test_colossus_brain` (14), `test_colossus_parts` (11), `test_colossus` (11, prawdziwa Sala Kolosa), `test_guardian_keeper` (5); `run_guardian.sh colossus --dry`: 16/16 momentów.

**Odstępstwa od planu (świadome):**
- Zdrowie 1100 zamiast 1000 (górna granica zakresu z polecenia): bot zabijał w 30 s przy 1000.
- Kolos zostaje wyjątkiem kolizji tronu także po wstaniu (zdjęcie wyjątku wypychało stojący zderzacz z cokołu o 0,35 m); od tronu trzyma go sterowanie kroków (`_room_ahead`).
- Fala od dłoni nie trafia tego, kogo trafiła sama dłoń (bez podwójnych obrażeń przy krawędzi cienia).
- Materiały efektów strażników z jednej fabryki `GuardianLooks` i w rozgrzewce shaderów nocy (`ShaderWarmUp`), żeby pierwszy promień nie kompilował shadera w walce.
- Tryb `--bot` w scenariuszu (pomiar długości walki) — poza planem, potrzebny do strojenia.

**Dla kolejnych strażników (do użycia bez zmian):** `Guardian.take_zone_damage` + `GuardianZone` (strefy trafień), `GuardianKeeper` (skrypt w `guardians/<id>.gd`, `dress_arena`, `arena_<id>_reward`), `MotionClip`/`Spring`/`LimbIK` (animacja), `GroundMark`/`ShockwaveRing`/`GuardianLooks` (zapowiedzi i efekty), wzorzec mózgu (`ColossusBrain`: etapy TELEGRAPH/STRIKE/RECOVER z tabelą czasów na fazę, `clip_time()`), scenariusz `tools/run_guardian.sh <id> --dry|--shots|--bot` (strażnik bez własnych momentów dostaje wspólne).
