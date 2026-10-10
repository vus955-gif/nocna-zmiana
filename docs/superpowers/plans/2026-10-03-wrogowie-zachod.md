# Wrogowie zachodnich skrzydeł Piętra I — plan implementacji

> **Dla wykonawcy-agenta:** wymagany pod-skill: superpowers:subagent-driven-development (zalecany) albo superpowers:executing-plans. Kroki mają pola `- [ ]` do odhaczania.
>
> Stan: 3 października 2026. Wykonawca: Claude, drzewo robocze `.claude/worktrees/enemies-west`, gałąź `enemies-west` od `pietro-1` @ `2187615`.
> Autorytet: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.1 (mumia), §5.2 (wojownik i lew z reliefu), §5.3 (hoplita), §7.2 (percepcja, terytoria, limit polujących), §7.3, §8.3 (Pył). Grafika: `docs/art/kit-pietro1-egipt.md` §6 (mumia, szczątki), §4 (`sarcophagus`, `coffin`). Dźwięk: `docs/audio/dzwiek-przewodnik.html` §11.

**Cel:** trzy nowe rodzaje zwykłych wrogów zachodnich skrzydeł — **mumia** (Egipt), **hoplita** (Grecja), **wojownik i lew z reliefu** (Asyria) — z mięsistą, uczciwą i czytelną walką, animacjami z antycypacją, wybrzmieniem i ciężarem, na nowej percepcji (§7.2), wpięte w spawner Piętra I.

**Architektura:** każdy rodzaj to podklasa `Enemy` (percepcja, terytorium, limit polujących, ogłuszenie i dobijanie z bazy) plus czysta logika `RefCounted` testowana bez sceny (wybór ataku, geometria trafienia, liny, falanga, ruchy reliefu) i rig `ExhibitRig` animowany kodem (części modelu obracane wokół osi, bez szkieletów). Ruch drugorzędny (bicz, luźne bandaże) liczy łańcuch Verleta (`RopeChain`) w przestrzeni świata, więc sam z siebie się spóźnia, kołysze i opada. Modele hoplity i reliefów są w gałęziach `art-greece` / `art-assyria`: do ich scalenia rig działa na **szarym modelu złożonym w kodzie z tych samych nazw części**, więc podmiana na model z Blendera nie zmienia logiki.

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh --filter=<nazwa>` (bezokienkowo, `--fixed-fps 60`); dźwięki `python tools/sfx/gen_sfx.py <nazwy>` (numpy).

**Zasady pracy (od kontrolera):** tylko drzewo `enemies-west`; bez okien i bez dźwięku; jeden ciężki proces naraz, `--filter` w trakcie, pełny zestaw na końcu; commit po każdym wrogu (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). **Nie budujemy roju skarabeuszy** (robi go gałąź `guard-colossus`; adopcja później).

---

## Liczby (punkt startowy do strojenia)

### Mumia (`mummy`)
| Co | Wartość | Skąd |
|---|---|---|
| Zdrowie / Pył | 110 / 6 | §5.1 |
| Chód | 1,9 m/s, obrót 3,0 rad/s (powłóczy prawą nogą: zakreśla łuk na zewnątrz, kulejący rytm) | §5.1 + doprecyzowanie |
| Podejrzliwość | 0,9 s (głowa obraca się pierwsza, ciało powoli; oczy się żarzą, światło `EyeGlow`) | §7.2 |
| Cios pazurami | 16 obr., zasięg mózgu 1,7 m, sięgnięcie 1,9 m, zamach 0,55 s, powrót 0,8 s | §5.1 |
| **Bicz z bandaży** | zapowiedź **0,6 s** (ramię w górę i do tyłu, bandaż rozwija się ×1,5 i wznosi falą); zasięg 2,4–4,6 m; stożek ±18°; cel zamrożony na ostatnie 0,15 s zapowiedzi (unik w bok działa); **8 obr.**, **przyciąga 3 m** (najbliżej 1,2 m od mumii) w 0,25 s, **spowolnienie 1 s** (×0,5, minimum gracza); powrót 1,1 s (okno kary), odnowienie 4 s | §5.1 |
| Ogień | **×2** (materiał `LINEN`); trafienie ogniem (nie tyk palenia) podpala bandaże (`Burn` 4 obr./s przez 3 s) i wywołuje **panikę 2 s**: bieg ×1,6 prędkości od strażnika, zakosy co 0,5 s, ręce młócą nad głową, bez ataków; kolejna panika najwcześniej po 5 s | §5.1 |
| Gore | trafienie: kłąb kurzu (cząstki `LINEN`: wolne, wiszące); ≥ 14 obr.: odlatuje strzęp bandaża (`mummy_debris` `scrap_*`, najwyżej co 0,25 s); ≥ 25 obr. albo słaby punkt: odprysk kości; śmierć: części modelu + 2 kości + 3 strzępy + chmura kurzu | §5.1 „bandaże, kurz, kości” |
| Zasadzka z trumny | sloty zasadzek (`AmbushSpec`) dostają mumię **w trumnie** (`coffin` stoi w miejscu slotu, front jak slot); wieko pada do przodu 0,45 s → mumia wychyla się 0,35 s → schodzi ~0,85 m w przód 0,6 s (razem ~1,4 s); z sarkofagu (`sarcophagus`, gdy poziom postawi `MummyTomb` ≤ 2,5 m od slotu): wieko zsuwa się 0,6 s → siada 0,6 s → przekłada nogi i wstaje 0,7 s (~1,9 s). W trakcie: bez ataków i ruchu, trafialna | §5.1, §7.2 „zasadzki” |

### Hoplita (`hoplite`)
| Co | Wartość | Skąd |
|---|---|---|
| Zdrowie / Pył / materiał | 140 / 7 / marmur | §5.3 |
| Tarcza | blokuje ±60° od przodu (nie prąd, nie strome z góry, nie ogłuszony); w falandze +25° w stronę sąsiada; płyta tarczy (hurtbox) zamyka szczelinę między sąsiadami | §5.3 |
| Pchnięcie włócznią | zasięg mózgu 3,0 m, sięgnięcie 3,4 m, stożek ±30°, zapowiedź **0,7 s** (włócznia cofa się nad tarczę, grot błyska), wypad 0,6 m, 18 obr., odrzut 6, powrót 0,9 s | §5.3 + doprecyzowanie obrażeń |
| Falanga | 2–3 obudzonych hoplitów ≤ 4 m od siebie w jednej sali; szereg prostopadle do kierunku na strażnika, odstęp 0,85 m (tarcze ⌀ 0,95 m zachodzą na siebie); tempo najwolniejszego; skręt szeregu ≤ 1,2 rad/s (flankowanie działa); ogłuszony / zniszczony wypada, reszta zwiera szereg | §5.3 |
| Ruch / obrót | 2,1 m/s, 2,6 rad/s | doprecyzowanie (rycerz 2,0 / 2,2) |

### Wojownik i lew z reliefu (`relief_warrior`, `relief_lion`)
| Co | Wartość | Skąd |
|---|---|---|
| Wojownik: zdrowie / Pył | 50 / 5 | §5.2 |
| Wyjście ze ściany | płyta pęka i świeci 0,8 s (`relief_crack`), krok w przód 0,5 s (`relief_scrape`) | §5.2 |
| Płaskość | trafienie z boku (kąt do przodu > 60°) ×0,5; słaby punkt: oko (trafialne od frontu) | §5.2 |
| Unik w bok | 2 m w 0,25 s, gdy strażnik w niego celuje / strzela (co najmniej 1,6 s przerwy) | §5.2 |
| Rzut włócznią | łuk (grawitacja 9), 14 obr., 6–16 m, zamach 0,8 s, odnowienie 3,5 s | §5.2 |
| Cios | 12 obr., zasięg 1,8 m, zamach 0,5 s | §5.2 |
| Wejście w ścianę | raz na 8 s, gdy ściana ≤ 1,5 m za nim: zapada się 0,5 s, wychodzi **6 m dalej wzdłuż ściany** (pęknięcie 0,5 s); w ścianie nietrafialny | §5.2 |
| Lew | zachowanie wilka (doskok); 40 obr., Pył 4, płaski (×0,5 z boku), wychodzi z niskiej płyty | §5.2, §7.3 |

---

## Pliki

| Plik | Odpowiada za |
|---|---|
| `src/enemies/visuals/rope_chain.gd` (nowy) | `RopeChain`: łańcuch Verleta (punkty, długości, grawitacja, tłumienie, przypięcie korzenia, przyciąganie do celów) — bicz i bandaże |
| `src/enemies/mummy_moves.gd` (nowy) | `MummyMoves`: czysta logika mumii — wybór ataku (bicz / pazury), odnowienie, geometria smagnięcia, długość przyciągnięcia, panika (czas, kierunek, odnowienie), oś czasu wyjścia z grobu |
| `src/enemies/mummy.gd` (nowy) | `Mummy`: statystyki, ciało, ataki, przyciągnięcie i spowolnienie, ogień i panika, wyjście z grobu, gore |
| `src/enemies/mummy_tomb.gd` (nowy) | `MummyTomb`: trumna stojąca / sarkofag (model albo szara bryła), wieko, `MummySpawn`, kolizja, animacja otwarcia |
| `src/enemies/visuals/mummy_rig.gd` (nowy) | `MummyRig`: chód z powłóczeniem, głowa „lata”, skrzyżowane ręce eksponatu, obrót głowy w podejrzliwości, pazury, bicz, panika, ogłuszenie, wyjście z trumny i z sarkofagu, bandaże i bicz na `RopeChain`, rozpad z `mummy_debris` i kurzem |
| `src/enemies/enemy.gd`, `enemy_brain.gd` | haki: `_may_attack()`, `EnemyBrain.interrupt()` (przerwanie zamachu) |
| `src/combat/exhibit_material.gd`, `src/fx/fx.gd` | materiał `LINEN` (len: kurz, ogień ×2), `Fx.puff()` (kłąb kurzu) |
| `src/player/player.gd` | `Player.yank(velocity, seconds)` — krótkie wymuszone przesunięcie (bicz) |
| `tools/sfx/floor1_sfx.py`, `src/fx/sfx.gd` | dźwięki `hit_linen`, `break_linen` |
| `src/game/night_spawner.gd`, `src/game/night_director.gd` | nowe rodzaje; **slot `[zastępca, docelowy]` wybiera docelowy, gdy spawner go zna** |
| `src/game/floor1/floor_encounters.gd` | mumie slotów zasadzek śpią w trumnach |
| `src/enemies/phalanx.gd` (nowy) | `Phalanx`: czysta geometria szyku (sloty, front, skręt, zachodzenie tarcz) + rejestr szyków |
| `src/enemies/hoplite.gd`, `src/enemies/visuals/hoplite_rig.gd` (nowe) | `Hoplite` (na zasadzie `ShieldGuard`), rig + szary model z nazwami części rycerza |
| `src/enemies/shield_guard.gd` | `blocks()` z parametrem półkąta (rycerz 70°, hoplita 60°) |
| `src/enemies/relief_moves.gd`, `relief_panel.gd`, `relief_warrior.gd`, `relief_lion.gd`, `visuals/relief_rig.gd` (nowe) | płaskość, uniki, rzut, wejście w ścianę; płyta reliefu; oba rodzaje |
| testy: `tests/unit/test_rope_chain.gd`, `test_mummy_moves.gd`, `test_phalanx.gd`, `test_relief_moves.gd`, `test_night_spawner_kinds.gd`; `tests/integration/test_mummy.gd`, `test_mummy_tomb.gd`, `test_hoplite.gd`, `test_relief.gd` | |

---

## Zadanie 1: `RopeChain` (łańcuch Verleta)

**Pliki:** `src/enemies/visuals/rope_chain.gd`; test `tests/unit/test_rope_chain.gd`.

```gdscript
class_name RopeChain extends RefCounted
var points: PackedVector3Array       # świat; [0] = korzeń
var lengths: PackedFloat32Array      # długość odcinka i (punkt i -> i+1)
var damping := 0.08                  # utrata prędkości na krok (0..1)
var gravity := Vector3(0, -9.8, 0)
static func hanging(root: Vector3, count: int, length: float) -> RopeChain
func step(delta: float, root: Vector3, iterations: int = 4) -> void   # Verlet + więzy, korzeń przypięty
func pull_toward(targets: PackedVector3Array, weights: PackedFloat32Array, delta: float, rate: float) -> void
func span() -> float                  # suma długości
func direction(i: int) -> Vector3     # kierunek odcinka i
```
- [ ] **Krok 1:** testy: wisi prosto w dół po 2 s (koniec ≈ korzeń − Σ długości, ±2 cm); długości trzymają się (±1 cm) po szarpnięciu korzenia; przy nagłym przesunięciu korzenia w bok koniec **spóźnia się** (po 3 klatkach jest dalej od nowego pionu niż punkt 1); `pull_toward` z wagą 1 doprowadza punkty do celów; wydłużenie `lengths` rozwija linę.
- [ ] **Krok 2:** implementacja (pozycje poprzednie, `x += (x - x_prev)·(1 − damping) + g·dt²`, więzy odległości iterowane od korzenia).
- [ ] **Krok 3:** `bash tools/run_tests.sh --filter=rope_chain` → zielono.

## Zadanie 2: materiał `LINEN`, `Fx.puff`, dźwięki

**Pliki:** `src/combat/exhibit_material.gd`, `src/combat/gib_planner.gd`, `src/fx/fx.gd`, `src/fx/sfx.gd`, `tools/sfx/floor1_sfx.py`; testy w `tests/unit/test_exhibit_material.gd`, `tests/unit/test_gib_planner.gd`.

- [ ] `ExhibitMaterial.Kind.LINEN` dopisany **na końcu** enuma (wartości istniejących bez zmian): kolor szczątków lnu (0,62; 0,55; 0,42), cząstki kurzu (0,72; 0,66; 0,54), `hit_linen` / `break_linen`, `fire_factor`: wosk i len ×2.
- [ ] `GibPlanner`: len — +3 kawałki, mniejsze (×0,6).
- [ ] `Fx.impact` dla lnu: wolne (1,6 m/s), prawie bez grawitacji (1,2), więcej cząstek; `Fx.puff(position, color, amount, radius)` — kłąb kurzu unoszący się powoli (rozrzut 180°, grawitacja ujemna −0,4, życie 1,6 s).
- [ ] `floor1_sfx.py`: `hit_linen` (głuche, suche „pff” tkaniny z trzaskiem włókien i sypnięciem piasku, 0,35 s), `break_linen` (zapadnięcie: zgniecione płótno, grzechot kości, opadający pył, 1,4 s); dopisane do `SOUNDS`; `python tools/sfx/gen_sfx.py hit_linen break_linen` (inne pliki bajt w bajt bez zmian), `Sfx.SOUNDS` += nazwy; import.
- [ ] Testy: `test_each_material_has_its_own_sounds` przechodzi z nowym rodzajem; `fire_factor(LINEN, FIRE) == 2`; plan len ma więcej i mniejszych kawałków niż wosk; `test_sfx_files` widzi pliki.

## Zadanie 3: haki bazy, `Player.yank`, spawner

**Pliki:** `src/enemies/enemy.gd`, `src/enemies/enemy_brain.gd`, `src/player/player.gd`, `src/game/night_spawner.gd`, `src/game/night_director.gd`; testy `tests/unit/test_enemy_brain.gd` (+1), `tests/unit/test_night_spawner_kinds.gd`.

- [ ] `Enemy._may_attack() -> bool` (domyślnie `true`): fałsz = odległość do celu liczona jako INF (żaden atak się nie zaczyna). `EnemyBrain.interrupt()`: w ATTACK przed ciosem → HUNT (zamach przerwany), poza tym nic.
- [ ] `Player.yank(velocity: Vector3, seconds: float)`: przez `seconds` pozioma prędkość = `velocity` (jak zryw, ignoruje sterowanie i spowolnienia), `move_and_slide` (ściana zatrzymuje). `respawn()` kasuje.
- [ ] `NightSpawner.make()`: `mummy`, `hoplite`, `relief_warrior`, `relief_lion`; `NightSpawner.builds(kind) -> bool`; `NightSpawner.preferred(kinds, drawn) -> StringName`: przy 2+ rodzajach w slocie ostatni, który spawner umie zbudować (konwencja Piętra I `[zastępca, docelowy]`), inaczej wylosowany. `NightDirector._encounters` losuje jak dotąd (ta sama liczba wywołań RNG — inne losowania nocy bez zmian), potem `preferred()`.
- [ ] Testy: `[wax, mummy] → mummy`, `[wolf, scarabs] → wolf` (rój nieznany), `[knight, hoplite] → hoplite`, `[wax] → wax`; `make(&"mummy") is Mummy`; plan nocy Piętra I z tym samym ziarnem ma te same sloty i łup co przed zmianą (tylko rodzaje docelowe); `interrupt()` przerywa zamach, nie przerywa powrotu po ciosie.

## Zadanie 4: `MummyMoves` (czysta logika mumii)

**Pliki:** `src/enemies/mummy_moves.gd`; test `tests/unit/test_mummy_moves.gd`.

```gdscript
class_name MummyMoves extends RefCounted
enum Move { CLAW, LASH }
const LASH_MIN := 2.4; const LASH_MAX := 4.6; const LASH_CONE_DEG := 18.0
const LASH_COOLDOWN := 4.0; const PULL := 3.0; const PULL_STOP := 1.2; const PULL_TIME := 0.25
const PANIC_TIME := 2.0; const PANIC_COOLDOWN := 5.0; const PANIC_TURN := 0.5
var lash_ready_in := 0.0; var panic_left := 0.0; var panic_ready_in := 0.0
func tick(delta) -> void
func planned(distance: float) -> Move              # LASH gdy gotowy i LASH_MIN < d ≤ LASH_MAX
func attack_range(distance: float) -> float        # LASH_MAX gdy bicz gotowy, inaczej zasięg pazurów
func lash_hits(facing: Vector3, to_guard: Vector3) -> bool   # zasięg + stożek (płasko)
static func pull_distance(distance: float) -> float          # min(PULL, distance - PULL_STOP), ≥ 0
func catch_fire() -> bool                          # true = zaczyna panikę (odnowienie)
func panic_heading(away: Vector3, rng) -> Vector3  # od strażnika ± zakos
static func rise_progress(style, t) -> Dictionary  # fazy wyjścia z grobu (0..1 każda), koniec
```
- [ ] **Krok 1:** testy: z 3,5 m i gotowym biczem → LASH, z 1,5 m → CLAW, z 3,5 m po smagnięciu → CLAW i zasięg mózgu = pazury aż minie 4 s; stożek: 10° trafia, 30° pudłuje, 5 m pudłuje; przyciągnięcie z 4,0 m = 2,8 m, z 2,0 m = 0,8 m, z 1,0 m = 0; ogień: pierwsze podpalenie panikuje 2 s, drugie po 1 s nie, po 5 s tak; kierunek paniki ma składową „od strażnika” > 0; oś czasu trumny kończy się po 1,4 s, sarkofagu po 1,9 s, fazy rosną monotonicznie.
- [ ] **Krok 2:** implementacja; **Krok 3:** zielono (`--filter=mummy_moves`).

## Zadanie 5: `MummyTomb`

**Pliki:** `src/enemies/mummy_tomb.gd`; test `tests/integration/test_mummy_tomb.gd`.

- [ ] `enum Style { COFFIN, SARCOPHAGUS }`; `static func build(style, at: Transform3D) -> MummyTomb` (model `coffin` / `sarcophagus` przez `ArtLibrary.instance`, szara bryła gdy brak modelu: skrzynia + wieko + znacznik); grupa `mummy_tombs`; `StaticBody3D` na warstwie `WORLD` (pudło: trumna 0,78 × 2,02 × 0,72, sarkofag 2,72 × 1,05 × 1,37); `spawn_point() -> Transform3D` (z `MummySpawn`), `exit_point() -> Vector3` (trumna: 0,85 m przed frontem; sarkofag: 1,0 m od osi z boku −Z), `occupant`, `open()` (wieko: trumna — obrót wokół X do −95° z odbiciem i kurzem przy uderzeniu, `weight_thud`; sarkofag — zsuwa się w +Z i przechyla, `lock_seal_grind`, spada z kurzem), `is_open()`, `static func free_near(point, radius) -> MummyTomb`.
- [ ] Testy: trumna z modelu ma `lid` i punkt spawnu ~1,07 m nad ziemią; po `open()` i 1 s wieko leży (oś Y wieka prawie pozioma); sarkofag: wieko po otwarciu przesunięte > 0,8 m; `free_near` znajduje wolny grób w 2,5 m, zajęty pomija.

## Zadanie 6: `Mummy` + `MummyRig`

**Pliki:** `src/enemies/mummy.gd`, `src/enemies/visuals/mummy_rig.gd`; test `tests/integration/test_mummy.gd`.

Rig (części modelu z `docs/art/kit-pietro1-egipt.md` §6; kąty: +x ramienia/nogi = do przodu, −x tułowia/głowy = pochylenie w przód):
- [ ] **chód:** lewa noga wahadło ±0,38 rad; prawa powłóczy: wahadło ±0,18 przesunięte do tyłu, w fazie przenoszenia **odwodzenie** (obrót z na zewnątrz do 0,16 — stopa zakreśla łuk), biodro „siada” na prawej (głębszy dół podskoku), tułów przechyla się nad nogą podporową, garbi (−0,2), skręca; **głowa** na sprężynie (przechył i skłon spóźnione za tułowiem + powolne kiwanie) — „lata”; lewa ręka wyciągnięta przed siebie, prawa (z biczem) zwisa ciężko; tempo kroku z prędkości (`cycle_length` 1,5 m).
- [ ] **sen eksponatu:** ręce skrzyżowane na piersi (dłonie przy przeciwnych barkach), głowa lekko spuszczona, oczy zgaszone; **podejrzliwość:** głowa szybko obraca się ku `last_known` (±1,2 rad), ciało za nią powoli, oczy rozbłyskują (`EyeGlow`: OmniLight 1,6 m, bez cieni, plus `awake` shadera), ręce drgną; **przebudzenie:** ręce rozplatają się z ciężarem (~0,8 s).
- [ ] **pazury:** obie ręce w górę, tułów odchyla się (antycypacja 0,55 s) → cięcie w dół i w przód w 0,1 s → ciężki powrót.
- [ ] **bicz:** zapowiedź — prawe ramię w górę i do tyłu, tułów skręca się w prawo, lewe ramię w bok dla równowagi, bandaż (4 odcinki na `RopeChain`, długości 0,2 → 0,3) unosi się falą nad barkiem; cios — ramię w dół i w przód, tułów odkręca się, odcinki lecą do celu z opóźnieniem 0,025 s na odcinek (koniec dociera ostatni: trzask), długość = dystans/4; trafienie — koniec trzyma strażnika przez 0,25 s przyciągania, ramię szarpie do siebie; pudło — koniec chlasta podłogę (kurz); powrót — cele zwolnione, lina opada grawitacją i wraca do 0,2 m.
- [ ] **panika:** ręce młócą nad głową, głowa się miota, tułów drży, bieg; **ogłuszenie:** zgarbiona, głowa zwisa, ręce bezwładne, kołysanie; **wyjście z trumny / sarkofagu** wg osi czasu `MummyMoves.rise_progress` (leżenie i siadanie przez transformację korzenia modelu wokół biodra); **bandaże** `strip_1..4` na 2-punktowych `RopeChain` (wiszą w dół świata, kołyszą się od ruchu, trafień i obrotów).
- [ ] **rozpad:** części modelu jako szczątki (baza) + `mummy_debris` (2 kości, 3 strzępy) + `Fx.puff`.

Mumia:
- [ ] `_configure()` z tabeli; kapsuła 0,3 × 1,8; strefy: tułów+nogi (kapsuła, śledzi `torso` z obrotem), głowa (słaby punkt, śledzi `head`); `notice_sound = mummy_groan`.
- [ ] co klatkę przed mózgiem: `brain.attack_range / windup / recovery` z planowanego ruchu; przy wejściu w ATTACK ruch zablokowany; zapowiedź bicza śledzi strażnika (obrót ×0,5) do ostatnich 0,15 s; `mummy_lash` gra tak, by trzask (0,44 s pliku) padł ~0,08 s po ciosie.
- [ ] cios pazurami = baza (16 obr.); bicz: `MummyMoves.lash_hits` + linia wzroku z nadgarstka → 8 obr. (BLUNT, bez odrzutu), `yank` ku mumii na `pull_distance`, `slow(0.5, 1.0)`; cel bez `yank` (manekin w testach) dostaje tylko obrażenia.
- [ ] ogień: `take_damage` z FIRE (nie `periodic`) → `Burn.ignite(self, 4, 3)` + panika (`interrupt()`, `_may_attack` fałsz, sterowanie: bieg od strażnika po nawigacji); jęk.
- [ ] grób: `entombed` (ustawiane przed wejściem do drzewa) → w `_ready` szuka wolnego `MummyTomb` ≤ 2,5 m (sarkofag z poziomu), inaczej stawia własną trumnę w miejscu slotu (rodzeństwo w drzewie); wyjątek kolizji z grobem; w grobie widzi tylko z bliska (1,5 m); wyjście z DORMANT → `tomb.open()` + oś czasu wyjścia (pozycja ciała z wnętrza do `exit_point`, bez sterowania i ataków).
- [ ] gore wg tabeli (`_on_damaged`).
- [ ] **Testy integracyjne** (szara podłoga, prawdziwy `Player` tam, gdzie liczy się przyciąganie):
  - statystyki: 110 HP, 1,9 m/s, Pył 6, `LINEN`, model załadowany (rig nie null), głowa = słaby punkt;
  - śpiąca: ręce skrzyżowane (dłonie bliżej przeciwnych barków niż własnych), w podejrzliwości głowa obrócona ku hałasowi (> 0,5 rad), ciało mniej;
  - chód 3 s: średnia prędkość 1,6–2,0 m/s; prawa stopa odchodzi na zewnątrz (x stopy) bardziej niż lewa;
  - **bicz: strażnik 3,6 m przed mumią → po smagnięciu przesunięty o 2,4 m ±0,25 (= 3,6 − 1,2) ku mumii, zdrowie −8, spowolniony ~1 s (prędkość chodu ×0,5 przez 1 s, potem pełna)**; z 4,2 m przesunięcie 3,0 m ±0,25;
  - zapowiedź trwa 0,6 s (od wejścia w ATTACK do ciosu), w jej trakcie koniec bicza wznosi się ponad bark, a lina jest dłuższa niż w spoczynku; w chwili ciosu koniec bicza dochodzi do strażnika (≤ 0,5 m od jego piersi);
  - unik: strażnik zrywem w bok w ostatnich 0,15 s → pudło (bez obrażeń i przyciągnięcia);
  - po smagnięciu przez 4 s tylko pazury: z 1,5 m cios 16;
  - **ogień:** raca (FIRE 10) → 20 obr., płonie (`Burn` dziecko), panika: przez 2 s nie atakuje strażnika w zasięgu pazurów i oddala się od niego (> 1,5 m), po panice znów atakuje;
  - ogłuszenie paralizatorem + pięść = dobicie;
  - śmierć: szczątki `mummy_debris` w `Fx` (≥ 3 kawałki więcej niż części modelu), `Events.enemy_destroyed`.
- [ ] **Testy zasadzki** (`test_mummy_tomb.gd`): mumia `entombed` stoi w trumnie (pozycja ciała w obrysie trumny), nie widzi strażnika 6 m przed sobą przez 3 s; `brain.wake()` → wieko pada, po ~1,4 s mumia stoi przed trumną (≥ 0,6 m przed frontem) i poluje; w trakcie wychodzenia nie zadaje obrażeń strażnikowi w 1 m; sarkofag postawiony obok → mumia wybiera go (leży: oś Y modelu prawie pozioma), wychodzi z boku po ~1,9 s; `FloorEncounters.tune_from_layout` daje `entombed` mumii ze slotu zasadzki, nie innym.
- [ ] Commit `Mummy: bandage lash that pulls and slows, claws, fire panic, sarcophagus and coffin ambush, linen gore`.

## Zadanie 7: hoplita i falanga

**Pliki:** `src/enemies/shield_guard.gd`, `src/enemies/phalanx.gd`, `src/enemies/hoplite.gd`, `src/enemies/visuals/hoplite_rig.gd`; testy `tests/unit/test_phalanx.gd`, `tests/integration/test_hoplite.gd`.

- [ ] `ShieldGuard.blocks(..., half_arc_deg := HALF_ARC_DEG)`; rycerz bez zmian.
- [ ] `Phalanx` (czysta): `slots(center, front, count, spacing) -> PackedVector3Array`, `wheel(front, wanted, delta, rate) -> Vector3`, `shield_overlap(spacing, shield_width) -> float` (> 0 = zachodzą), rejestr: `Phalanx.form(members)`, `of(hoplite)`, `goal_for(hoplite)`, rozpad przy ogłuszeniu / śmierci / > 6 m od szyku.
- [ ] `Hoplite` (marmur 140, Pył 7): `_blocks` = `ShieldGuard.blocks(..., 60 + 25 gdy sąsiad w szyku po stronie trafienia)`; strefa tarczy (płyta 0,95 × 1,05 × 0,1 przed ciałem) — trafienie w nią od przodu = blok; pchnięcie (zapowiedź 0,7 s, wypad 0,6 m, stożek ±30°, 18 obr.); w falandze sterowanie do slotu i patrzenie w front szyku; poza falangą jak rycerz.
- [ ] `HopliteRig` + szary model w kodzie z nazwami części rycerza (`torso`, `head`, `arm_l`, `arm_r`, `shield`, `weapon`, `leg_l`, `leg_r` + grzebień hełmu): ciężki krok, tarcza przy piersi, włócznia nad tarczą; zapowiedź: przysiad za tarczą, włócznia cofa się, grot błyska; pchnięcie z wypadem i skrętem bioder; ogłuszony opuszcza tarczę; `HopliteRig.build()` bierze model `hoplite` z `ArtLibrary`, gdy istnieje.
- [ ] Testy: tarcza blokuje z przodu 50°, nie 70° (sam), w szyku 70° od strony sąsiada tak; strzał między dwoma hoplitami w szyku trafia tarczę (blok), nie przelatuje; paralizator → strzał z przodu przechodzi; pchnięcie z 2,8 m trafia 18 po 0,7 s, z 4 m nie; trzech obudzonych obok siebie ustawia się w szereg (odstępy 0,85 ±0,2, wszyscy patrzą tak samo, ±15°) i idzie na strażnika; ogłuszony wypada, dwaj zwierają szereg.
- [ ] Commit `Hoplite: marble shield bearer with a spear thrust and the phalanx (greybox body until art-greece)`.

## Zadanie 8: relief — wojownik i lew

**Pliki:** `src/enemies/relief_moves.gd`, `src/enemies/relief_panel.gd`, `src/enemies/relief_warrior.gd`, `src/enemies/relief_lion.gd`, `src/enemies/visuals/relief_rig.gd`; testy `tests/unit/test_relief_moves.gd`, `tests/integration/test_relief.gd`.

- [ ] `ReliefMoves` (czysta): `edge_factor(facing, hit_dir) -> float` (0,5 z boku), `wall_slide(origin, along, distance, probe: Callable) -> Variant` (punkt 6 m dalej, gdy ściana i podłoga tam są), `throw_velocity(from, to, speed, gravity) -> Vector3` (łuk; null poza zasięgiem), odnowienia (rzut 3,5 s, ściana 8 s, unik 1,6 s).
- [ ] `ReliefPanel`: płyta na ścianie (szara bryła; model z `art-assyria` później), pęknięcia świecące przy zapowiedzi, pusta wnęka po wyjściu; szuka ściany promieniem za slotem (≤ 1,5 m).
- [ ] `ReliefWarrior` (50 HP, Pył 5, marmur): śpi płasko w płycie; budzi się → pęknięcie 0,8 s → wyjście; unik w bok (gdy strażnik celuje w niego z < 8° albo strzela), rzut włócznią 6–16 m (`Projectile` z grawitacją), cios 12; wejście w ścianę i wyjście 6 m dalej (raz na 8 s); obrażenia z boku ×0,5; oko = słaby punkt.
- [ ] `ReliefLion` (`Wolf`): płaski, z płyty, ×0,5 z boku, 40 HP, Pył 4.
- [ ] Testy: wyjście z płyty po zapowiedzi 0,8 s (wcześniej nietrafialny i bez ataku); trafienie z boku 20 → 10; z przodu w oko → słaby punkt; włócznia łukiem trafia strażnika 10 m dalej (14 obr.); wejście w ścianę: po 8 s znika przy ścianie i pojawia się 6 m ±0,5 dalej wzdłuż niej; lew doskakuje jak wilk.
- [ ] Commit `Relief warrior and lion: flat figures out of the wall panels (greybox until art-assyria)`.

## Zadanie 9: weryfikacja i raport

- [ ] Pełny zestaw `bash tools/run_tests.sh` (jeden proces), poprawki.
- [ ] Ta sekcja planu: stan wykonania, odstępstwa; raport dla kontrolera (≤ 40 wierszy).

---

## Doprecyzowania i odstępstwa

1. **Slot `[zastępca, docelowy]`:** `NightDirector` losuje rodzaj jak dotąd (te same wywołania RNG — reszta nocy bez zmian), a `NightSpawner.preferred()` bierze ostatni rodzaj slotu, który spawner umie zbudować. `[wolf, scarabs]` daje więc wilka, dopóki nie przyjdzie rój.
2. **Mumie zasadzek śpią w trumnach.** Poziom ma na razie szare `plinth` jako sarkofagi; mumia slotu zasadzki stawia własną **stojącą trumnę** (`coffin`, 0,8 × 0,7 m — mieści się w miejscu slotu), a gdy poziom (integracja grafiki) postawi `MummyTomb` z `sarcophagus` ≤ 2,5 m od slotu, mumia kładzie się w nim i z niego wychodzi. Pozostałe mumie śpią jako eksponaty (skrzyżowane ręce).
3. **Bicz trafia w chwili ciosu** (sprawdzenie zasięgu, stożka i linii), a lina leci do celu wizualnie 0,1 s; cel jest zamrożony na ostatnie 0,15 s zapowiedzi, więc zryw w bok albo cofnięcie się poza 4,6 m to uczciwa ucieczka.
4. **Przyciągnięcie** to `Player.yank` (wymuszony ruch 0,25 s), nie odrzut: odrzut zjada przyspieszenie gracza (60 m/s²) i dystans zależałby od wciśniętych klawiszy. Strażnik staje najbliżej 1,2 m od mumii (w zasięgu pazurów — kombinacja; spowolnienie nie obejmuje zrywu, więc ucieczka zostaje).
5. **Obrażenia pchnięcia hoplity = 18** (projekt nie podaje; rycerz ma 25 przy wolniejszym zamachu 0,95 s).
6. **Lew z reliefu ma 40 HP** (projekt: „zachowanie wilka”; wilk 35, kamień trochę twardszy).
7. **Szare ciała hoplity i reliefów** są modelami złożonymi w kodzie z nazwanych części (te same nazwy co docelowe modele), więc rigi działają od razu, a podmiana na model z Blendera to jedna linia w `build()`.
8. **Hoplita na modelu z `art-greece`** (scalony w trakcie): rig ma przedramiona i golenie, spoczynek modelu to postawa gotowości (włócznia poziomo w prawej ręce, aspis na lewym przedramieniu); słaby punkt = twarz w otworach hełmu (znacznik `face`), strąca się grzebień (trafienie w głowę ≥ 20) i nagolenniki (niskie ciosy ≥ 20), odpryski `marble_chips`. Odstęp falangi 0,8 m dla tarczy 0,9 m. Szary model w kodzie (z pierwszego commitu) został usunięty; bez modeli zostaje prosta szara bryła.
9. **Pchnięcie i włócznia nie przechylają całej postaci** jak cios rycerza: `Enemy.windup_lean` / `strike_lean` (domyślnie jak dotąd 0,35 / −0,45; hoplita 0,05 / −0,1, relief 0,08 / −0,12).
10. **Rój skarabeuszy przejęty od Kolosa** (`ScarabSwarm`, gałąź `guard-colossus`): rodzaj `scarabs` w spawnerze; śpiący rój to kupka chrząszczy na podłodze (cicha, nie gryzie), obudzony wzbija się w chmurę, a pętla `scarab_swarm` narasta; chmura płynie (ogon 0,35 s za głową), nisko w biegu, wiruje nad ofiarą; trafienie rozdmuchuje ją i wybija martwe chrząszcze; śmierć = deszcz chrząszczy i pokryw `scarab_debris`. Liczby walki bez zmian (testy Kolosa zielone).
11. **Reliefy na modelach z `art-assyria`:** postać śpi jako **rzeźba płyty przebudzenia** (`asy_relief_wake`, `_lion`, część `figure`), własny model wroga jest wtedy ukryty; zapowiedź = pęknięcia w mapie emisji płyty (0 → 6) + ciepłe światło; po wyjściu zostaje pusta wnęka. Ruch „papierowej lalki” wokół normalnej płyty; rysunek patrzy na −X. **Odstępstwo:** do ataku (rzut, pchnięcie) wojownik **obraca się krawędzią** do strażnika (rysunek przodem do niego) — czytelna zapowiedź, a w tym czasie trafienia w niego to trafienia w krawędź (×0,5); po ciosie wraca licem. Lew pokazuje bok, gdy się skrada, a odwraca łeb do strażnika, gdy na niego biegnie i skacze.
12. **Reliefy budzone od razu (patrol, wezwani) nie stawiają płyty** — są po prostu „na zewnątrz”; płytę dostają tylko śpiący. Bez ściany w zasięgu 1,5 m płyta stoi wolno (stela).
13. **Unik wojownika** reaguje i na celowanie (kamera strażnika w ±8° od niego, sprawdzane co 0,2 s), i na strzał (`Events.weapon_fired`).
14. Testy spawnera (`preferred`) są w `test_mummy_tomb.gd`, `test_hoplite.gd`, `test_scarab_swarm.gd`, `test_relief.gd` zamiast osobnego `test_night_spawner_kinds.gd`.

## Stan wykonania (3.10)

Zadania 1–8 wykonane, model hoplity i reliefów podmieniony po scaleniu `art-greece` i `art-assyria` (przez `pietro-1`), rój skarabeuszy przejęty. Commity: plan, mumia, hoplita (szary), scalenie `pietro-1`, hoplita na modelu, rój, reliefy (szare), scalenie `pietro-1`, reliefy na modelach, porządki `GreyboxArt`.

Pozy sprawdzone liczbowo (bez okna): dłonie mumii przy przeciwnych barkach we śnie, koniec bicza nad barkiem w zapowiedzi i na piersi strażnika po ciosie, koniec bicza nigdy pod podłogą, nogi mumii wychodzącej z sarkofagu prawie nie przechodzą przez ściankę (4 próbki na 130 klatek × 12), stopy ≥ 0; grot hoplity poziomo i cofnięty w zapowiedzi; włócznia wojownika z reliefu wycelowana w strażnika (cos ≥ 0,98) w zapowiedzi rzutu.
