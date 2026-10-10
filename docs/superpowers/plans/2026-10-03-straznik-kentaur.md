# Strażnik Grecji — Kentaur z metopy (plan wykonawczy)

> **Dla wykonawcy:** zadania po kolei, TDD (najpierw test, potem kod), commit po każdym zadaniu. Kroki z `- [ ]`.
> Gałąź `guard-centaur` (od `pietro-1`). Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.3, **§7.4**. Wzorzec: plan Kolosa `docs/superpowers/plans/2026-10-03-straznik-kolos.md` (zestaw ruchu, strefy trafień, opiekun, scenariusz). Model: `docs/art/kit-pietro1-grecja.md` §6.

**Cel:** drugi prawdziwy strażnik Piętra I i przeciwieństwo Kolosa — szybki, ruchliwy pojedynek. Marmurowy kentaur (2,86 m) wyrywa się z metopy na środku Galerii Partenonu (39,5 × 18 m, h 12) i krąży po długiej sali na dystansie: **rzuca oszczepami łukiem** (znak lądowania na posadzce), **staje dęba i kopie** z bliska (a stojącego za nim **wierzga** tylnymi nogami), **szarżuje przez galerię** (cokół, grupa frontonowa albo ściana zatrzymują go i ogłuszają: okno na pierś). Faza 2 woła Lapitów (hoplitów) z frontonów, faza 3 odrywa z boku odłamek metopy i rzuca dwoma oszczepami naraz. Walka 2–3 min, każdy atak ≥ 0,6 s zapowiedzi. **Poprzeczka animacji:** wiarygodny galop (cztery takty, kopyta stoją na posadzce dzięki IK, kołysanie i przechył beczki, ogon i głowa z opóźnieniem), ludzki tułów pochyla się w zakręty, antycypacja przed rzutem i kopnięciem, iskry i kurz spod kopyt, kamera drży, gdy przegalopuje obok.

**Architektura (jeden akapit):** jak u Kolosa: czysta logika w `RefCounted` — `CentaurBrain` (stany, ataki z etapami TELEGRAPH/STRIKE/RECOVER i tabelą czasów na fazę, wybór ataku po odległości i kącie, fazy, Lapici, ogłuszenie, tempo krążenia), `CentaurGait` (chody stęp/kłus/galop jako rozkład taktów czterech nóg w cyklu; kopyto w podporze stoi w świecie, w przenoszeniu leci łukiem do przewidzianego miejsca lądowania; rytm beczki), zestaw ruchu Kolosa (`MotionClip`, `Spring`, `LimbIK` + nowe `LimbIK.joint()` — staw dwóch kości z biegunem). Węzeł `Centaur extends Guardian` składa ciało (`CentaurRig` na modelu `centaur` z `ArtLibrary`, szarość bez modelu), strefy trafień na częściach, sterowanie po sali (sondy promieniami + pokój areny), ataki i efekty; `CentaurMoves` komponuje pozę z warstwy chodu i klipu ataku. Oszczep to `CentaurJavelin` (pocisk balistyczny do znaku, wbija się w posadzkę). Rekwizyty areny stawia `dress_arena()`: `CentaurMetope` (płyta, z której się wyrywa; po walce pusty kikut) i miejsca Lapitów przy frontonach. Upadek `CentaurFall`: potknięcie, nogi się składają, rozpad na marmurowe bryły.

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh [--filter=...]` (bez okna), scenariusz `bash tools/run_guardian.sh centaur --dry` (bez okna), podgląd póz `--poses` (zrzut póz + klatki z Blendera w tle).

---

## Decyzje

1. **Animacja kodem** (jak Kolos): klatki kluczowe `MotionClip` w czasie etapu + sprężyny + IK. U kentaura dochodzi **warstwa chodu**: `CentaurGait` liczy kopyta (świat) i rytm (faza cyklu), `CentaurMoves` kładzie na nią klip ataku (nadpisuje wybrane kanały: dęba, kopnięcie, rzut). Dzięki temu można rzucać w galopie (tułów skręca się nad biegnącą beczką), a kopyta zostają na posadzce przy każdej prędkości i każdym skręcie.
2. **Chody z jednej tabeli:** każdy chód to przesunięcia faz czterech nóg i udział podpory (stęp 4 takty boczne, kłus pary po przekątnej, galop 4 takty poprzeczne z fazą lotu), częstotliwość i długość kroku z prędkości; przejścia płynne (przesunięcia faz gonią cel). Kopyto ląduje tam, gdzie w połowie podpory będzie pod barkiem.
3. **Noga konia = trzy człony:** IK dwóch kości (bark/staw kolanowy → nadgarstek/staw skokowy → pęcina) z biegunem: przednia noga zgina „kolano” do przodu, tylna staw skokowy do tyłu; kopyto (pęcina + puszka) trzyma podeszwę poziomo w podporze, w przenoszeniu podwija się do tyłu. Za mały zasięg w podporze (model ma nogi prawie proste) nadrabia lekko obniżona beczka w biegu i przesuw korzenia nogi w beczce (do 0,1 m, niewidoczny).
4. **Uśpienie = relief:** znacznik `guardian_centaur` obrócony tak, by kentaur stał bokiem do wejścia (twarzą na południe), lewym bokiem przy płycie metopy (błękitne tło), widziany z wejścia jak figura z reliefu. Budzenie: szarpnięcie, płyta pęka, dęba, płyta rozpada się na bryły, ląduje twarzą do strażnika. Po pokonaniu — pusty kikut płyty.
5. **Strefy trafień:** pierś = słaby punkt (pełne obrażenia + mnożnik broni, złoty znacznik; ×1,5 w ogłuszeniu), łeb ×1,25 (biały), ludzki tułów i ręce ×0,5, końskie ciało i nogi ×0,25 (szary znacznik, marmurowe odpryski).
6. **Lapici:** rodzaj `hoplite`, gdy istnieje (`src/enemies/hoplite.gd`, gałąź `enemies-west`), inaczej `knight` (NightSpawner.make), przy grupach frontonowych na obu końcach (miejsca z `dress_arena`).

---

## Liczby walki (Nocna zmiana; Podwójna: zdrowie ×1,2, obrażenia przez `damage_scale`)

| Element | Wartość |
|---|---|
| Zdrowie | 850 (bot: 38 s, jak Kolos); fazy: 2 < 66 %, 3 < 33 % |
| Przebudzenie | 2,8 s: oczy, szarpnięcie, płyta pęka (1,0 s), dęba, płyta rozpada się (1,45 s), lądowanie twarzą do strażnika |
| Krążenie | galop 9,5 / 10,5 / 11,5 m/s (sprint strażnika 8,5), dystans 11 / 10 / 9 m, zmiana kierunku przy przeszkodzie lub co 6–10 s |
| Przerwa między atakami | 1,4 / 1,1 / 0,9 s (blisko strażnika dwa razy szybciej) |
| **Oszczep** | zamach 0,8 / 0,7 / 0,6 s (ramię cofa się, tułów skręca, grot błyska, znak śledzi strażnika z wyprzedzeniem); wypuszczenie = blokada znaku; lot 0,65–1,25 s łukiem (g 18 m/s²) dokładnie w środek znaku; 22 obr. trafionemu w locie lub w znaku (r 1,3 m); wbity w posadzkę 4 s; od 5 m, łuk ±110° od beczki |
| **Dwa oszczepy** (faza 3) | prawa i lewa ręka, 0,15 s odstępu: jeden w przewidziane miejsce, drugi w obecne |
| **Dęba i kopnięcie** | tylko blisko (≤ 4,2 m) z przodu (±75°): 0,7 / 0,7 / 0,65 s (wstaje na tylne nogi, kopyta błyskają, znak pod kopytami); 28 obr. + odrzut w znaku (r 2,2 m, 1,55 m przed środkiem), fala 8 obr. do 4,5 m (przeskocz) |
| **Wierzgnięcie** | blisko (≤ 3,8 m) z tyłu (> 115°): 0,65 / 0,65 / 0,6 s (zad w górę, łeb przez ramię); 24 obr. + odrzut w łuku za zadem |
| **Szarża** | 0,9 / 0,8 / 0,7 s zapowiedzi (staje przodem, tułów nisko, oszczep jak kopia, grzebie kopytem, pas na posadzce do pierwszej przeszkody, blokada 0,25 s przed startem); 15,5 m/s do 30 m; 30 obr. + odrzut 14 w bok; co najmniej 7 s przerwy; od 7 m |
| **Zderzenie** | cokół, grupa frontonowa, kikut metopy, ściana: ogłuszenie 2,6 / 2,3 / 2,0 s, pierś ×1,5; bez zderzenia: poślizg 0,7 s |
| **Wołanie Lapitów** (faza 2+) | 1,0 s (dęba, okrzyk, uniesiony oszczep); 2 / 3 hoplitów przy frontonach; ponownie, gdy wszyscy padli, co 25 s |
| **Oderwanie odłamka** (faza 3) | 0,9 s (lewa ręka sięga do boku), odłamek metopy leci jako bryła, drugi oszczep formuje się w lewej dłoni |
| Pokonanie | oczy gasną, pęknięcia rozbłyskują, potknięcie z rozpędem, przednie nogi się łamią, beczka siada i przewraca się na bok, rozpad na bryły; Pieczęć Sowy + odłamek Grecji na `arena_centaur_reward`; 60 Pyłu |

---

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/game/floor1/guardians/limb_ik.gd` (zmiana) | `LimbIK.joint(root, end, l1, l2, pole)` — staw dwóch kości w płaszczyźnie bieguna |
| `src/game/floor1/guardians/ground_mark.gd` (zmiana) | `GroundMark.lane(width, length)` — pas szarży |
| `src/game/floor1/guardians/centaur_gait.gd` (nowy) | `CentaurGait`: chody, takty, kopyta w świecie, rytm (faza cyklu), zdarzenia `touchdown(leg)` |
| `src/game/floor1/guardians/centaur_brain.gd` (nowy) | `CentaurBrain`: stany `DORMANT, WAKING, ROAM, ATTACK, STUNNED, DEAD`; ataki `THROW, KICK, BUCK, CHARGE, CALL, TEAR`; tabela czasów; wybór; fazy; Lapici; liczby walki |
| `src/game/floor1/guardians/centaur_rig.gd` (nowy) | `CentaurRig`: model `centaur` (lub szarość), `Pose` → części: beczka, nogi IK z kopytami, ogon, tułów, szyja, ręce IK, oszczepy, odłamek, blask |
| `src/game/floor1/guardians/centaur_moves.gd` (nowy) | `CentaurMoves`: warstwa chodu (kołysanie, przechył w zakręcie, kontra tułowia, ogon, głowa na sprężynach) + klipy (budzenie, rzut, dęba, wierzgnięcie, szarża, ogłuszenie, wołanie, oderwanie) → `Pose` |
| `src/game/floor1/guardians/centaur_javelin.gd` (nowy) | `CentaurJavelin`: lot balistyczny do punktu, trafienie strażnika (odcinek–kapsuła), wbicie w posadzkę z drżeniem, zniknięcie |
| `src/game/floor1/guardians/centaur_metope.gd` (nowy) | `CentaurMetope`: płyta reliefu (kolizja), pęknięcia, rozpad na bryły, kikut; miejsca Lapitów |
| `src/game/floor1/guardians/centaur.gd` (nowy) | `Centaur extends Guardian`: ciało, strefy, sterowanie, ataki i efekty, Lapici, `dress_arena()` |
| `src/game/floor1/guardians/centaur_fall.gd` (nowy) | `CentaurFall`: upadek z rozpędem i rozpad |
| `src/level/floor1/zones/greece.gd` (zmiana) | znacznik `guardian_centaur` obrócony (bokiem do wejścia), `arena_centaur_reward`, miejsca Lapitów `centaur_lapith_<n>` |
| `tests/unit/test_centaur_gait.gd`, `tests/unit/test_centaur_brain.gd` | logika chodu i mózgu |
| `tests/integration/test_centaur_parts.gd` | rig (kopyta na posadzce, dęba, rzut), oszczep, metopa |
| `tests/integration/test_centaur.gd` | walka w prawdziwej Galerii Partenonu |
| `tests/scenarios/guardian_scenario.gd` (zmiana), `tools/art/guardian_poses.py` (nowy) | momenty walki kentaura (`--dry`), zrzut póz (`--poses`) → klatki z Blendera |
| `docs/Nocna-Zmiana-specyfikacja.md` (zmiana) | §4.6 Kentaur z metopy |

---

## Kontrakty (nowe)

```gdscript
LimbIK.joint(root: Vector3, end: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3
GroundMark.lane(width: float, length: float) -> GroundMark   # od początku znaku w -Z

CentaurGait.update(delta, body: Transform3D, velocity: Vector3) -> void
gait.hoof(leg) -> Vector3          # świat, punkt pęciny (0,17 m nad posadzką w podporze)
gait.swing(leg) -> float           # 0 w podporze, 0..1 w przenoszeniu
gait.cycle -> float                # faza cyklu 0..1 (rytm beczki)
signal touchdown(leg: int)         # 0 = lewa przednia, 1 = prawa przednia, 2 = lewa tylna, 3 = prawa tylna

CentaurBrain.update(delta, distance, bearing) ; .force_attack(kind) ; .crash() ; .clip_time()
CentaurJavelin.make(from, to, flight_time, damage, source, target) -> CentaurJavelin
CentaurJavelin.launch_velocity(from, to, time, gravity) -> Vector3   # static
```

---

### Zadanie 1: Zestaw ruchu: staw z biegunem, pas szarży

**Pliki:** zmiany `limb_ik.gd`, `ground_mark.gd`; testy w `tests/unit/test_guardian_motion.gd`, `tests/integration/test_colossus_parts.gd` (znak).

- [x] **Krok 1 — testy:** `joint` daje staw w odległości l1 od korzenia i l2 od końca, po stronie bieguna; za daleko — prosto; pas ma długość i szerokość z argumentów, a jego cień ciemnieje z postępem.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 2: Chód (`CentaurGait`)

**Pliki:** nowy `centaur_gait.gd`; test `tests/unit/test_centaur_gait.gd`.

- [x] **Krok 1 — testy:** w miejscu cztery kopyta stoją; w galopie (10 m/s) na cykl przypadają cztery lądowania w kolejności LT, PT, LP, PP (cztery takty); kopyto w podporze nie ślizga się (świat stały); w przenoszeniu unosi się (> 0,15 m); każde kopyto zawsze w zasięgu nogi (≤ l1 + l2 + luz); w kłusie lądują parami po przekątnej; zakręt w miejscu przestawia nogi (kopyta wracają pod barki); przejście stęp → galop bez skoków kopyt.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 3: Mózg (`CentaurBrain`)

**Pliki:** nowy `centaur_brain.gd`; test `tests/unit/test_centaur_brain.gd`.

- [x] **Krok 1 — testy:** przebudzenie trwa `WAKE_TIME`; daleko z przodu — oszczep lub szarża, nigdy kopnięcie; blisko z przodu — dęba, blisko z tyłu — wierzgnięcie; szarża nie częściej niż co `CHARGE_COOLDOWN`; ten sam atak nigdy 3× z rzędu; każda zapowiedź każdego ataku w każdej fazie ≥ `Guardian.MIN_TELEGRAPH`; faza 2 → wołanie po bieżącym ataku, ponowne, gdy Lapici padli (cooldown); faza 3 → oderwanie odłamka, potem `pair` (dwa oszczepy); szarża zakończona zderzeniem → `STUNNED` na czas fazy, bez zderzenia → koniec; `reset()`; ten sam seed → ta sama sekwencja.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 4: Arena: metopa, znaczniki, Lapici

**Pliki:** nowy `centaur_metope.gd`; zmiana `greece.gd`; test w `tests/integration/test_centaur_parts.gd`.

- [x] **Krok 1 — testy:** metopa ma kolizję płyty, pęka (rysy świecą), rozpada się na bryły fizyczne (warstwa DEBRIS), zostaje kikut z niską kolizją; `restore()` przywraca płytę; znaczniki `guardian_centaur` (bokiem), `arena_centaur_reward`, `centaur_lapith_1..4` w sali.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 5: Rig i ruchy (`CentaurRig`, `CentaurMoves`)

**Pliki:** nowe `centaur_rig.gd`, `centaur_moves.gd`; testy w `test_centaur_parts.gd`; narzędzie `tools/art/guardian_poses.py`.

- [x] **Krok 1 — testy:** poza spoczynku = model w spoczynku; kopyta w podporze ≤ 0,05 m od posadzki (galop, zakręt); kolano przedniej nogi zgina się do przodu, staw skokowy do tyłu; dęba: tylne kopyta na posadzce, przednie > 1 m, beczka > 0,5 rad; zamach rzutu: dłoń za barkiem, oszczep grotem w stronę celu i w górę; w chwili wypuszczenia dłoń z przodu; przechył w zakręcie do środka; szarość ma te same nazwy części.
- [x] **Krok 2 — kod;** zrzut póz i klatki z Blendera (galop z boku, zakręt, rzut, dęba, wierzgnięcie, szarża, ogłuszenie, budzenie) — poprawki, aż ruch przekonuje. **Krok 3 — commit.**

### Zadanie 6: Oszczep (`CentaurJavelin`)

**Pliki:** nowy `centaur_javelin.gd`; testy w `test_centaur_parts.gd`.

- [x] **Krok 1 — testy:** prędkość startowa prowadzi grot dokładnie w cel w zadanym czasie; oszczep wbija się w posadzkę w znaku (≤ 0,3 m) i leży `STUCK_TIME`, potem znika; trafia strażnika stojącego w znaku (raz), mija tego, kto wyszedł; zatrzymuje go cokół (kryjówka).
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 7: Kentaur w prawdziwej galerii: przebudzenie, krążenie, strefy, oszczep, kopnięcia

**Pliki:** nowy `centaur.gd`; test `tests/integration/test_centaur.gd`.

- [x] **Krok 1 — testy:** stoi na znaczniku przy metopie, śpi; strażnik za linią startu → przebudzenie, płyta się rozpada, pasek z imieniem; 40 s walki z różnych miejsc: każda zapowiedź ≥ 0,6 s, oszczep i szarża w fazie 1, kentaur nie opuszcza sali i nie wchodzi w cokoły; strefy: pierś pełne + złoty, łeb ×1,25, tułów ×0,5, koń ×0,25 szary; promień z oczu strażnika trafia pierś; oszczep ląduje w znaku i rani stojącego tam; dęba tylko z bliska i rani w znaku; wierzgnięcie za zadem.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 8: Szarża i ogłuszenie; fazy 2–3

**Pliki:** zmiany `centaur.gd`; testy w `test_centaur.gd`.

- [x] **Krok 1 — testy:** szarża w strażnika stojącego przed cokołem, który odskakuje: kentaur wbija się w cokół → `STUNNED`, pierś ×1,5; strażnik w pasie zostaje stratowany (raz); < 66 % → wołanie, 2 Lapitów (hoplita lub rycerz) przy frontonach; < 33 % → oderwanie odłamka, potem rzuty po dwa oszczepy.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 9: Upadek, nagrody, ucieczka

**Pliki:** nowy `centaur_fall.gd`; zmiana `centaur.gd`; testy w `test_centaur.gd`.

- [x] **Krok 1 — testy:** śmierć przez pierś → `CentaurFall`, bryły po upadku, pieczęć `seal_owl` + odłamek `shard_greece` na `arena_centaur_reward`, zapis; następnej nocy brak kentaura, metopa pusta (kikut); ucieczka → z powrotem przy metopie, pełne zdrowie, Lapici znikają, płyta cała.
- [x] **Krok 2 — kod. Krok 3 — commit.**

### Zadanie 10: Scenariusz i strojenie

**Pliki:** zmiany `tests/scenarios/guardian_scenario.gd`, `tools/run_guardian.sh`.

- [x] **Krok 1:** `run_guardian.sh centaur --dry`: śpi w reliefie, wyrywa się, galop, zamach, oszczep w locie, wbity oszczep, dęba, wierzgnięcie, szarża (pas), zderzenie i ogłuszenie, wołanie i Lapici, oderwanie odłamka, dwa oszczepy, upadek, rozpad. `--bot` → długość walki; strojenie zdrowia do 2–3 min.
- [x] **Krok 2 — commit.**

### Zadanie 11: Dokumentacja i pełny zestaw testów

- [x] Specyfikacja §4 (Kentaur), katalog sztuki (jak gra prowadzi kentaura), stan planu; scalenie `pietro-1`; pełne `bash tools/run_tests.sh` (zielone); commit.

---

## Ryzyka i odpowiedzi
| Ryzyko | Odpowiedź |
|---|---|
| Nogi modelu prawie proste — kopyto nie sięga posadzki w podporze | obniżona beczka w biegu, przesuw korzenia nogi, krótka podpora w galopie; test „kopyta na posadzce” |
| Szybki strażnik nie do trafienia | ogłuszenie po zderzeniu (pierś ×1,5), zamach rzutu spowalnia, dęba zatrzymuje; bot mierzy czas |
| Oszczep niesprawiedliwy | znak śledzi i staje w chwili wypuszczenia, lot ≥ 0,65 s; kryjówki za cokołami |
| Galop przez cokoły, wyjście z sali | sondy promieniami na dwóch wysokościach + pokój areny; test „nie opuszcza sali” |
| Lapici z innej gałęzi | rodzaj `hoplite`, gdy plik istnieje, inaczej `knight` |
| Ciężkie testy z całym piętrem | logika bez sceny; w galerii kilka scenariuszy |

---

## Stan wykonania (3.10)

Zadania 1–11 wykonane (TDD, commit po zadaniu; po drodze scalony `pietro-1` z mapą, rundą integracji 2 i zasadą „bez strzelania spoza areny”). Testy: `test_guardian_motion` (+2: staw z biegunem, pas szarży), `test_centaur_gait` (6), `test_centaur_brain` (11), `test_centaur_parts` (9: metopa, znaczniki, rig, dęba, rzut, oszczep), `test_centaur` (10, prawdziwa Galeria Partenonu); `run_guardian.sh centaur --dry`: 18/18 momentów; `--bot`: 38 s.

**Odstępstwa od planu (świadome):**
- Zdrowie 850 zamiast 1000: bot (pistolet w pierś, 45 % trafień) potrzebował 50 s przy 1000 — dłużej niż Kolos (36 s ↔ 2–3 min realnie).
- Dęba trafia 1,55 m przed środkiem (nie 1,9 m): nogi modelu dalej nie sięgają z kopytami na posadzce.
- Miejsca Lapitów to punkty strażnika z nowej konwencji opiekuna (`centaur_lapith_<n>` → `Guardian.points[&"lapith"]`), nie znaczniki `arena_*`.
- Lapici: rodzaj `hoplite` (gałąź `enemies-west` scalona z `pietro-1` przed końcowym zestawem testów); bez `src/enemies/hoplite.gd` byłby to `knight`.
- Kentaur nie zderza się ze strażnikiem (maska tylko WORLD): szarża go tratuje (kontakt w pasie), zamiast pchać.
- Dodatkowo: wierzgnięcie (strażnik za zadem) i narzędzie `--poses` (zrzut póz + klatki z Blendera w tle) do oceny animacji bez okna.

**Do sprawdzenia przy sesji z oknem (`--shots`/gra):** czytelność znaku oszczepu w ruchu, siła wstrząsu przy galopie obok, głośność pętli galopu, tempo walki z prawdziwym graczem.
