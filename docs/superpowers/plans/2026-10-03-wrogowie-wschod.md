# Wrogowie wschodnich i północnych skrzydeł Piętra I — plan implementacji

> **Dla wykonawcy-agenta:** wymagany pod-skill: superpowers:subagent-driven-development (zalecany) albo superpowers:executing-plans. Kroki mają pola `- [ ]` do odhaczania.
>
> Stan: 3 października 2026. Wykonawca: Claude, drzewo robocze `.claude/worktrees/enemies-east`, gałąź `enemies-east` od `pietro-1` (po scaleniu `925a90d`: sztuka Azji, wrogowie zachodu, Planetarium).
> Autorytet: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.4 (latające księgi), §5.5 (pies Fu, zbroja samuraja), §5.6 (totem, wojownik-jaguar), §7.2 (percepcja, terytoria, limit polujących), §7.3, §8.3 (Pył). Grafika: `docs/art/kit-pietro1-oswiecenie.md` §6 (`flying_book`, `flying_book_page`), `docs/art/kit-pietro1-ameryki.md` §8–9 (`totem`, `jaguar`), `docs/art/kit-pietro1-azja.md` §7–8 (`fu_dog`, `samurai_ashigaru`). Dźwięk: `docs/audio/dzwiek-przewodnik.html` §11 (`book_flap`, `book_flock`, `fu_roar`, `totem_spit`, `jaguar_snarl`).

**Cel:** pięć nowych rodzajów zwykłych wrogów — **latające księgi** (Oświecenie), **totem** i **wojownik-jaguar** (Ameryki), **pies Fu z brązu** i **zbroja samuraja** (Azja) — z modelami z Blendera animowanymi kodem (antycypacja, wybrzmienie, ruch drugorzędny), mięsistą, uczciwą i czytelną walką (każdy atak zapowiedziany na wysokości oczu strażnika), na percepcji §7.2, wpięte w spawner Piętra I.

**Architektura:** każdy rodzaj to podklasa `Enemy` (percepcja, terytorium, limit polujących, ogłuszenie, dobijanie z bazy), czysta logika `RefCounted` testowana bez sceny (stado ksiąg, twarze totemu, ruchy jaguara i psa Fu, pchnięcie yari) i rig `ExhibitRig` animowany kodem (części modelu obracane wokół osi). Do ruchu drugorzędnego i ruchów kluczowych używamy zestawu Kolosa: `MotionClip` (klucze z krzywymi), `Spring` (sprężyny: ogon, maczuga, czapa totemu, przechył). Księgi to **stado**: jeden `BookFlock` (kontroler: przywódca, szyk, kolejka nurkowań, rozproszenie, wspólne budzenie, pętla dźwięku) i lekkie księgi-członkowie (każda z własnym zdrowiem i Pyłem, liczona przez muzeum jak członek watahy raptorów).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh --filter=<nazwa>` (bezokienkowo, `--fixed-fps 60`); dźwięki `python tools/sfx/gen_sfx.py <nazwy>` (numpy).

**Zasady pracy (od kontrolera):** tylko drzewo `enemies-east`; bez okien i bez dźwięku; jeden ciężki proces naraz, `--filter` w trakcie, pełny zestaw na końcu; commit po każdym wrogu (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Teksty przez `tr()`, `strings.csv` tylko dopisywane. Spawner: reguła `NightSpawner.preferred()` z gałęzi zachodu (już w `pietro-1`) — dopisujemy tylko nasze rodzaje do `BUILDS`.

---

## Liczby (punkt startowy do strojenia)

### Latające księgi (`books`)
| Co | Wartość | Skąd |
|---|---|---|
| Stado | **4–6** ksiąg z jednego slotu (z ziarna nocy, jak wataha raptorów: ta sama noc = to samo stado) | §5.4 |
| Zdrowie / Pył / materiał | **18** / **2** za księgę / `CANVAS` (papier: strzępy i pył, dźwięk rozdzieranego płótna) | §5.4 |
| Ogień | **×2** (trafienia i tyknięcia palenia) | §5.4 |
| Lot | 4,4 m/s; zawis 1,7–2,6 m nad podłogą (na wysokości strażnika, gdy poluje), kołysanie ±0,18 m (0,9–1,3 Hz) + podskok przy każdym uderzeniu okładek | doprecyzowanie |
| Trzepot | okładki ±0,3 rad wokół spoczynku, 5,5 Hz (wznoszenie 8 Hz ±0,38); kartki drżą | kit §6 |
| Szyk | krąg wokół strażnika, promień 4,5–6 m, obraca się 0,45 rad/s (kierunek na stado), wysokość na członka; separacja 0,8 m | doprecyzowanie |
| **Nurkowanie** | zapowiedź **0,7 s**: zawis, odchylenie w tył (25°), **okładki rozłożone na płasko (±0,6 rad)**, oczy rozbłyskują, kartki szeleszczą, `book_flap`; potem lot po prostej w pierś strażnika z **chwili końca zapowiedzi** (cel zamrożony) 11 m/s, do 1,0 s; kontakt ≤ 0,75 m: **7 obr.**, odrzut 3, okładki zatrzaskują się (ugryzienie); potem poderwanie w górę i w bok | §5.4 |
| Powrót | 1,1 s (wolny, ciężki trzepot, bezbronna), potem z powrotem do szyku | doprecyzowanie |
| Rytm stada | jedno nurkowanie naraz; ≥ 0,5 s przerwy między końcem jednego a początkiem kolejnej zapowiedzi; każda księga ≥ 2,5 s między swoimi; zasięg 8 m, czysta linia | uczciwość |
| Rozproszenie | zniszczona księga: towarzyszki ≤ 4 m odskakują 3,5 m/s, stado „spłoszone” 0,8 s (bez nowych zapowiedzi, krąg +1,5 m) | §5.4 |
| Sen | na najbliższym licu regału (promienie ≤ 3 m na wys. 1,25 m nad slotem): zamknięte, pionowo, grzbietem do sali, w rzędzie co 7,5 cm; bez ściany — stosik na podłodze | zadanie |
| Pobudka | jedna po drugiej (co 0,12 s): wysuwa się z półki 0,35 m, okładki się otwierają, wznosi się | zadanie |
| Gore | trafienie: 1–2 kartki wylatują i opadają jak liście; śmierć: części modelu + **6–9 kartek** opadających wahadłowo (od ognia — przypalone) | §5.4 |
| Limit polujących | stado liczy się jak **jeden** łowca (przywódca); reszta idzie za nim | §7.2 |

### Totem (`totem`)
| Co | Wartość | Skąd |
|---|---|---|
| Twarze | **3–5** (z pozycji slotu, stałe dla miejsca; `faces` w teście) | §5.6 |
| Zdrowie / Pył | **30 na twarz** (zdrowie = 30·n); **Pył 3 na twarz** (3·n przy rozpadzie) | §5.6, §8.3 |
| Materiał | nowy `WOOD` (wióry cedrowe, `hit_wood` / `break_wood`) | §5.6 |
| Od góry | pełne obrażenia ma **górna** twarz (i czapa); trafienie niższej ×0,35 („drewno głuche”); słaby punkt = twarz górnego bloku | §5.6 „zestrzeliwuje się je od góry” |
| Wieżyczki | każdy blok obraca się osobno do strażnika: 0,9–1,5 rad/s (wyżej szybciej); w zapowiedzi strzelająca twarz zwalnia do 40% (zobowiązanie) | doprecyzowanie |
| Strzał | najlepiej wycelowana twarz (±20°, czysta linia z pyska): **oczy świecą 0,7 s**, twarz cofa się (wdech), potem plucie odłamkiem wzdłuż swojego kierunku, pochylenie na pierś strażnika: 8,5 m/s, **9 obr.**, odrzut 2; odłamek zestrzeliwalny | §5.6 |
| Tempo | odstęp po strzale wg pozostałych twarzy: 5 → 2,0 s, 4 → 1,7, 3 → 1,4, 2 → 1,1, 1 → 0,8 („im mniej twarzy, tym szybciej”) | §5.6 |
| Zasięg / wzrok | 20 m; stożek 160° we śnie, przebudzony patrzy wszystkimi twarzami (360°) | §7.2 |
| Utrata twarzy | co 30 obr. górny blok odpada (model w kawałkach + 8 wiórów, `break_wood`), czapa spada na nową górę i odbija się, słup się chwieje, pozostałe oczy rozbłyskują 0,4 s | §5.6 |
| Limit polujących | nie liczy się (nie goni, jak portret) | §7.2 |

### Wojownik-jaguar (`jaguar`)
| Co | Wartość | Skąd |
|---|---|---|
| Zdrowie / Pył / materiał | **70** / **5** / `WOOD` | §5.6 + zadanie |
| Chód | wyprostowany 3,0 m/s (badanie 2,1, patrol 1,35) | doprecyzowanie |
| **Sprint w przysiadzie** | 6,2 m/s, niska sylwetka (miednica −0,35, tułów −35°, na czworakach: lewa ręka jak przednia łapa, maczuga w tyle); strefy trafień idą za modelem | §5.6, kit §9 |
| **Doskok** | z 3–7 m: przysiad **0,6 s** (warknięcie `jaguar_snarl`, maczuga w tył), skok cięższy niż wilk (wznoszenie 3,2 m/s, do 10 m/s poziomo), ląduje **1,4 m przed** strażnikiem; w locie maczuga nad głową | §5.6 |
| **Maczuga po lądowaniu** | osiadanie 0,25 s (kolana amortyzują), cios 0,22 s (ramię +150° → +20°), trafienie na końcu: **18 obr.**, zasięg 2,5 m, stożek ±55°, odrzut 6; potem maczuga w ziemi **0,8 s** (okno kary) | zadanie |
| Maczuga z bliska | strażnik ≤ 2,4 m: zamach nad głowę 0,6 s, ten sam cios | doprecyzowanie |
| Słaby punkt | twarz w paszczy hełmu (`face`) | kit §9 |
| Smycz | łowca (40 m), jak wilk | §7.2 |

### Pies Fu z brązu (`fu_dog`)
| Co | Wartość | Skąd |
|---|---|---|
| Zdrowie / Pył / materiał | **160** / **8** / `METAL` (iskry) | §5.5 |
| Chód / obrót | 2,4 m/s / 2,4 rad/s (ciężki: obejście działa) | doprecyzowanie |
| **Szarża** | zapowiedź **0,8 s**: łeb nisko, prawa łapa dwa razy grzebie (iskry, `fu_scrape`); bieg po prostej (kierunek z końca zapowiedzi, dociąganie ≤ 0,5 rad/s przez 0,3 s) **6 m/s**, do 1,8 s / 10 m; trafienie raz: **22 obr.** (= `attack_damage` · 22 / 14, więc skaluje się z trudnością, pełnią i godziną duchów), odrzut 10; w ścianę: **zderzenie, ogłuszony 1,4 s**; chybienie: poślizg 0,5 s, powrót 0,9 s | §5.5 |
| Zasięg szarży | 4–12 m, czysta linia na wysokości kolan (`FuDog.KNEE_HEIGHT` 0,45 m: niska gablota ją wstrzymuje) | doprecyzowanie |
| **Ryk** | strażnik ≤ 6 m w stożku ±40°: zapowiedź **0,7 s** (**perła w pysku świeci**, łeb w górę, pierś się nadyma), ryk `fu_roar`: w zasięgu, w stożku, z linią wzroku → **strażnik oszołomiony 0,5 s** (bez obrażeń); odnowienie 6 s | §5.5 |
| Perła | słaby punkt (`mouth_ball`); trafienie świecącej perły w zapowiedzi ryku dławi ryk: **ogłuszony 1,2 s** | §5.5 + nagroda za celność |
| Łapa | strażnik ≤ 2,6 m w stożku ±50°: zamach 0,6 s, 14 obr., odrzut 7 | uczciwość (przytulenie nie jest bezpieczne od frontu) |
| **Para** | lew i lwica z sąsiednich slotów (≤ 18 m, ta sama sala): jedna szarża naraz; partner nie zaczyna zapowiedzi szarży, gdy strażnik jest oszołomiony; lwica = lustro modelu (`scale.x = −1`), częściej ryczy (60/40) | §5.5, kit §7 |
| Oszołomienie strażnika | 0,5 s: ruch ×0,2, bez strzału i ciosu, broń opada, wstrząs kamery | §5.5 |

### Zbroja samuraja (`samurai_armor`)
| Co | Wartość | Skąd |
|---|---|---|
| Zdrowie / Pył / materiał | 180 / **8** / `METAL` | §5.5 (rycerz), zadanie |
| Ruch / obrót | 2,0 m/s / 2,2 rad/s (rycerz) | §5.5 |
| Zasłona (sode) | `ShieldGuard` rycerza (±70° od przodu; nie prąd, nie strome z góry, nie ogłuszony) | §5.5 |
| Postawa | śpi jak eksponat z yari pionowo; polując — **kamae**: sode przed piersią, yari poziomo na strażnika | kit §8 |
| **Pchnięcie yari** | zasięg mózgu 2,6 m, sięgnięcie 3,2 m, stożek ±25°; zapowiedź **0,8 s** (yari cofa się do biodra, przednia stopa sunie, w 0,45 s **błysk grotu** + `samurai_glint` cicho), pchnięcie 0,12 s z wypadem 0,5 m: **20 obr.**, odrzut 6; powrót 1,0 s (yari wraca powoli: okno kary) | zadanie |
| Oczy | **żar**: migocące światło w hełmie (0 we śnie), rozbłysk w zapowiedzi | zadanie |
| Płyty | `KnightRig.shed_plate` (5 płyt, bez `plate_pauldron_l`) | kit §8 |

---

## Pliki

| Plik | Odpowiada za |
|---|---|
| `src/game/night_spawner.gd` | `make()` + `BUILDS`: `books`, `totem`, `jaguar`, `fu_dog`, `samurai_armor`; **stado ksiąg z jednego slotu** (`FLOCK`, `group_size()`, `flock_size()`), tak jak wataha raptorów |
| `src/combat/exhibit_material.gd`, `src/combat/gib_planner.gd`, `src/fx/fx.gd` | materiał `WOOD` (wióry, `hit_wood` / `break_wood`; drzazgi: +2 mniejsze kawałki; szybkie, ciężkie wióry w `Fx.impact`) |
| `tools/sfx/floor1_sfx.py`, `src/fx/sfx.gd` | dźwięki `hit_wood`, `break_wood`, `fu_scrape` |
| `src/player/player.gd`, `src/weapons/weapon_holder.gd` | `Player.stagger(seconds)` / `staggered()`; `WeaponHolder.daze(seconds)` (bez strzału, broń opada) |
| `src/fx/page_flutter.gd` (nowy) | `PageFlutter`: kartka opadająca jak liść (wahadło, obrót, ląduje płasko, znika); `PageFlutter.Motion` — czysta fizyka kroku |
| `src/enemies/book_flock.gd` (nowy) | `BookFlock`: członkowie, przywódca, miejsca w kręgu, kolejka nurkowań, rozproszenie, wspólne budzenie, miejsca snu na półce (`perches()`), pętla `book_flock` |
| `src/enemies/flying_book.gd`, `src/enemies/visuals/book_rig.gd` (nowe) | `FlyingBook` (lot, zawis, szyk, nurkowanie, sen na półce, gore), `BookRig` (okładki, kartki, przechyły, zapowiedź) |
| `src/enemies/totem_faces.gd`, `src/enemies/totem.gd`, `src/enemies/visuals/totem_rig.gd` (nowe) | `TotemFaces` (czysta logika: twarze ze zdrowia, tempo, trafienia od góry, wybór twarzy, obrót), `Totem`, `TotemRig` (obroty bloków, oczy, wdech/odrzut, odpadanie twarzy, czapa na sprężynie) |
| `src/enemies/jaguar_moves.gd`, `src/enemies/jaguar.gd`, `src/enemies/visuals/jaguar_rig.gd` (nowe) | `JaguarMoves` (wybór ataku, skok, fazy kombinacji, geometria ciosu), `Jaguar`, `JaguarRig` (chód / sprint na czworakach, przysiad, lot, cios z `MotionClip`, ogon na sprężynach) |
| `src/enemies/fu_dog_moves.gd`, `src/enemies/fu_dog.gd`, `src/enemies/visuals/fu_dog_rig.gd`, `src/fx/roar_wave.gd` (nowe) | `FuDogMoves` (wybór ruchu, stożek ryku, szarża, para), `FuDog`, `FuDogRig` (ciężki chód, galop szarży, grzebanie, ryk, perła, ogon, lustro lwicy, kula na cokole), `RoarWave` (fala ryku) |
| `src/enemies/samurai_armor.gd`, `src/enemies/visuals/samurai_rig.gd` (nowe) | `SamuraiArmor` (na `Knight`: pchnięcie yari, żar oczu), `SamuraiRig` (na `KnightRig`: kamae, cofnięcie, błysk, pchnięcie, powrót) |
| `tests/support/target_dummy.gd` | rejestruje oszołomienia (`stagger()`) |
| testy: `tests/unit/test_book_flock.gd`, `test_page_flutter.gd`, `test_totem_faces.gd`, `test_jaguar_moves.gd`, `test_fu_dog_moves.gd`, `test_samurai_armor.gd`, `test_night_spawner_east.gd`; `tests/integration/test_flying_books.gd`, `test_totem.gd`, `test_jaguar.gd`, `test_fu_dog.gd`, `test_samurai_armor_arena.gd`, `test_player_stagger.gd` | |

---

## Zadanie 0: wspólne — materiał drewna, dźwięki, oszołomienie, kartki, spawner

**Pliki:** jak w tabeli (wiersze 1–6); testy `tests/unit/test_exhibit_material.gd` (+1), `tests/unit/test_gib_planner.gd` (+1), `tests/unit/test_page_flutter.gd`, `tests/integration/test_player_stagger.gd`, `tests/unit/test_night_spawner_east.gd`.

- [x] `ExhibitMaterial.Kind.WOOD` **na końcu** enuma: szczątki (0,52; 0,27; 0,16) (cedr), cząstki (0,8; 0,62; 0,42) (wióry), `hit_wood` / `break_wood`; ogień ×1. `GibPlanner`: drewno +2 kawałki ×0,7. `Fx.impact` dla drewna: 4,5 m/s, grawitacja 12.
- [x] `floor1_sfx.py`: `hit_wood` (twarde stuknięcie w rzeźbione drewno + trzask drzazgi, 0,3 s), `break_wood` (pęknięcie pnia, sypiące się wióry, stuk kawałków, 1,3 s), `fu_scrape` (brązowy pazur po kamieniu: dwa zgrzyty z trzaskiem iskier, 0,8 s); `python tools/sfx/gen_sfx.py hit_wood break_wood fu_scrape` (inne pliki bajt w bajt bez zmian), `Sfx.SOUNDS` += nazwy; import.
- [x] `Player.stagger(seconds)`: przez `seconds` `speed_factor()` ×0,2, `weapons.daze(seconds)`, wstrząs kamery 0,55, zryw FOV −6; `staggered() -> bool`; `respawn()` kasuje. `WeaponHolder.daze(seconds)`: w tym czasie `_physics_process` nie strzela ani nie uderza; broń opada (`_switch_drop` ≥ 0,2).
- [x] `PageFlutter.Motion` (pozycja, prędkość, faza, oś kołysania): grawitacja 9,8 z mocnym oporem (prędkość graniczna ~0,9 m/s), boczne kołysanie wahadłowe ±0,35 m z przechyłem w stronę ruchu, obrót wokół pionu; ląduje płasko na `floor_y`. `PageFlutter.scatter(at, count, push, scorched)` — węzły pod `Fx` (czyści je `Fx.clear()`), najwyżej 60 naraz, leżą 6–9 s, potem maleją i znikają.
- [x] `NightSpawner`: `BUILDS` += `books`, `totem`, `jaguar`, `fu_dog`, `samurai_armor`; `make()` je buduje; `FLOCK := &"books"`; `group_size(config, slot, kind)` (raptor: 3–4, książki: `flock_size()` 4–6 z ziarna, inne 1); `spawn()` i `exhibit_count()` przez `group_size()`; stado budowane przez `BookFlock.make_members(center, yaw, count)`.
- [x] Testy: drewno ma własne dźwięki (istniejący test), plan drewna ma więcej i mniejszych kawałków niż wosk; kartka: prędkość opadania ≤ 1,2 m/s po 1 s, przesuwa się w bok, ląduje na podłodze i leży; oszołomienie: po `stagger(0.5)` gracz idzie ≤ 25% prędkości i nie strzela, po 0,6 s znowu tak; `make(&"books") is FlyingBook`, `make(&"totem") is Totem` …; `preferred([wax, books]) == books`, `preferred([bust, totem]) == totem`, `preferred([wolf, jaguar]) == jaguar`, `preferred([wolf, fu_dog]) == fu_dog`, `preferred([knight, samurai_armor]) == samurai_armor`; slot ksiąg daje 4–6 ksiąg z jednym `BookFlock`, ten sam rozmiar dla tej samej nocy, `exhibit_count` liczy każdą księgę, `losses` przerzedza stado.
- [x] `bash tools/run_tests.sh --filter=exhibit_material`, `--filter=gib_planner`, `--filter=page_flutter`, `--filter=player_stagger`, `--filter=night_spawner` → zielono.

## Zadanie 1: `BookFlock` (czysta logika stada)

**Pliki:** `src/enemies/book_flock.gd`; test `tests/unit/test_book_flock.gd`.

```gdscript
class_name BookFlock extends RefCounted
const MIN_SIZE := 4
const MAX_SIZE := 6
const DIVE_GAP := 0.5          # s między końcem nurkowania a następną zapowiedzią
const OWN_COOLDOWN := 2.5      # s między nurkowaniami jednej księgi
const SPOOK_TIME := 0.8
const SCATTER_RADIUS := 4.0
const SCATTER_SPEED := 3.5
const RING_RADIUS := Vector2(4.5, 6.0)
const RING_SPIN := 0.45        # rad/s
var members: Array             # FlyingBook (słabe: tylko żywe)
var spin_sign := 1.0
var clock := 0.0               # czas stada (s), przesuwa go przywódca
static func make_members(center: Vector3, yaw: float, count: int) -> Array[Enemy]
func join(book) -> void / leave(book) -> void
func lead()                    # pierwsza żywa księga
func is_lead(book) -> bool
func ring_slot(index: int, guard: Vector3) -> Vector3   # miejsce w kręgu (świat; wysokość względna)
func can_dive(book) -> bool / begin_dive(book) / end_dive(book)
func spooked() -> bool
func scatter_from(point: Vector3) -> Dictionary          # book -> pchnięcie (Vector3)
static func perches(center: Vector3, count: int, cast: Callable) -> Array[Transform3D]  # cast(from, to) -> {position, normal} | {}
```
- [x] **Krok 1:** testy: przywódca = pierwsza żywa, po jej odejściu następna; miejsca w kręgu różne i w promieniu 4,5–6 m, obracają się z czasem stada; `can_dive` — tylko jedna naraz, przerwa `DIVE_GAP` po końcu, `OWN_COOLDOWN` dla tej samej księgi, nie w czasie spłoszenia; `scatter_from` pcha tylko księgi ≤ 4 m, od punktu, i płoszy stado; `perches` z „ścianą” (fałszywy `cast`) daje rząd w odstępach 7,5 cm, grzbietem od ściany, na 1,25 m; bez ściany — stosik na podłodze (kolejne o 6 cm wyżej).
- [x] **Krok 2:** implementacja. **Krok 3:** `--filter=book_flock` → zielono.

## Zadanie 2: `FlyingBook` + `BookRig` + kartki

**Pliki:** `src/enemies/flying_book.gd`, `src/enemies/visuals/book_rig.gd`; test `tests/integration/test_flying_books.gd`.

- [x] `FlyingBook` (Enemy): pochodzenie = środek księgi; zderzacz kula 0,17, bez kolizji ze strażnikiem (wyjątek) i z innymi eksponatami; `_apply_gravity`: zawis na sprężynie (cel: podłoga + wysokość członka, polując: wysokość strażnika + wysokość członka), opór w powietrzu na odrzut; śpiąc na półce — przypięta (`resting()`); `counts_as_hunter()` tylko przywódca, pozostali polują, gdy przywódca może.
- [x] Ruch: polując z widokiem — prosto do miejsca w kręgu (separacja 0,8 m), twarzą do strażnika; bez widoku — nawigacja (`path_height_offset`); badanie / patrol — cel przesunięty o miejsce w luźnym szyku; powrót — do swojej grzędy, potem wsunięcie na półkę (0,6 s).
- [x] Atak (mózg: zasięg 8, zamach 0,7, powrót 1,1): `_may_attack()` = `flock.can_dive(self)` i czysta linia; wejście w ATTACK → `begin_dive`; cios → cel zamrożony (pierś strażnika), lot 11 m/s do 1,0 s, kontakt ≤ 0,75 m = obrażenia raz, potem poderwanie; wyjście z ATTACK → `end_dive`.
- [x] Ogień ×2 (`take_damage`); trafienie → 1–2 kartki; śmierć → `PageFlutter.scatter` 6–9 (przypalone od ognia) + rozproszenie stada + `rig.shatter`.
- [x] Pobudka stadem: pierwsza obudzona budzi pozostałe śpiące (pełny alarm, co 0,12 s); wysunięcie z półki 0,35 m; `book_flap` przy pobudce i zapowiedzi; pętla `book_flock` na przywódcy, gdy stado czuwa.
- [x] `BookRig`: okładki (oś Y): spoczynek otwarty, trzepot (częstość wg wznoszenia / prędkości), zapowiedź = płasko ±0,6 i drżenie kartek, nurkowanie = okładki do tyłu (szybowanie) i zatrzaśnięcie przy ugryzieniu, powrót = ciężkie, szerokie uderzenia; sen = zamknięte (∓0,96); przechył w zakrętach (roll z prędkości kątowej), pochylenie z prędkości pionowej; kartki: `rotation.y` / `scale.z` drżą; ogłuszona — okładki opadają, księga wiruje i spada.
- [x] Testy: stado śpi na półce (ściana obok) i budzi się razem; nurkowanie trafia stojący cel (7 obr.), jedno naraz (nigdy dwie zapowiedzi jednocześnie), zapowiedź ≥ 0,6 s przed ciosem (okładki rozłożone ≥ 0,5 rad w trakcie); cel uskakujący w bok po zapowiedzi nie dostaje; strzał niszczy księgę (18), Pył 2, pozostałe się rozpraszają; ogień ×2; stado liczy się jak jeden łowca.

## Zadanie 3: `TotemFaces` (czysta logika totemu)

**Pliki:** `src/enemies/totem_faces.gd`; test `tests/unit/test_totem_faces.gd`.

```gdscript
class_name TotemFaces extends RefCounted
const FACE_HEALTH := 30.0
const LOWER_FACTOR := 0.35
const FIRE_ARC_DEG := 20.0
const BLOCK_BASE := 0.35
const BLOCK_HEIGHT := 0.85
static func faces_left(health: float) -> int
static func interval(faces: int) -> float                 # 5:2.0 … 1:0.8
static func block_at(height: float) -> int               # 0 = pień, 1..5
static func hit_factor(block: int, top: int) -> float     # 1 (górna, czapa) / LOWER_FACTOR
static func count_for(point: Vector3) -> int              # 3..5, stałe dla miejsca
static func turn_rate(block: int) -> float                # 0.9 … 1.5 rad/s
static func pick_face(yaws: PackedFloat32Array, top: int, guard_yaw: float, clear: Callable) -> int  # -1 brak
```
- [x] Testy: `faces_left(150)=5`, `(121)=5`, `(120)=4`, `(1)=1`, `(0)=0`; `interval` maleje z liczbą twarzy (5 → 2,0, 1 → 0,8); `block_at` dla wysokości twarzy 1–5 i pnia; `hit_factor` górna 1, niższa 0,35; `count_for` w 3..5 i stałe dla tego samego punktu; `pick_face` wybiera najlepiej wycelowaną w ±20°, pomija zasłoniętą (`clear` false), −1 gdy żadna.

## Zadanie 4: `Totem` + `TotemRig`

**Pliki:** `src/enemies/totem.gd`, `src/enemies/visuals/totem_rig.gd`; test `tests/integration/test_totem.gd`.

- [x] `Totem` (Enemy): bez ruchu i obrotu (smycz bez znaczenia), `knockback_resist` 1, zdrowie = 30·n, Pył 3·n; `faces` (0 = z pozycji); `take_damage` mnoży wg `TotemFaces.hit_factor` (wysokość trafienia w przestrzeni totemu); po obrażeniach — odpadanie twarzy; strefy: pień, blok na każdą twarz, słaby punkt na znaczniku `face_k` górnej twarzy (przenosi się w dół).
- [x] Ogień: mózg zasięg 20, zamach 0,7, powrót 0,15; `_may_attack()` = odnowienie minęło i jakaś twarz wycelowana (`pick_face`); wejście w ATTACK → zapamiętana twarz; cios → `Projectile` z `mouth_k` wzdłuż kierunku twarzy, pochylenie na pierś strażnika (`WOOD`, cedr + bursztynowa poświata, `hit_wood`), `totem_spit`; potem `attack_range = −1` na `interval(n) − 0,7`.
- [x] Wzrok: 160° śpiąc, 360° po przebudzeniu; `counts_as_hunter()` = false.
- [x] `TotemRig`: obroty `block_k` (łańcuch: obrót względem rodzica), oczy `eyes_k` świecą tylko na twarzy w zapowiedzi (`glow` na tej części), wdech (blok lekko w tył i w górę) i odrzut przy pluciu (sprężyna), drżenie słupa przy trafieniu, odpadanie górnego bloku (kawałki modelu + wióry), czapa spada na nową górę (sprężyna, odbicie, przechył), pobudka: twarze obracają się kolejno od dołu (skrzypienie).
- [x] Testy: 5 twarzy = 150 HP; 30 obr. w górną twarz zdejmuje ją (blok ukryty, czapa niżej), w dolną tylko ×0,35; strzela do strażnika w polu widzenia (pocisk leci, trafia stojący cel), oczy świecą ≥ 0,6 s przed strzałem; **odstępy strzałów krótsze przy mniejszej liczbie twarzy** (pomiar 5 vs 2 twarze); śmierć po zdjęciu wszystkich twarzy, Pył 3·n; nie liczy się do limitu polujących.

## Zadanie 5: `JaguarMoves` (czysta logika jaguara)

**Pliki:** `src/enemies/jaguar_moves.gd`; test `tests/unit/test_jaguar_moves.gd`.

```gdscript
class_name JaguarMoves extends RefCounted
enum Move { NONE, POUNCE, CLUB }
enum Phase { NONE, AIR, SETTLE, SWING, STUCK, DONE }
const CLUB_RANGE := 2.4
const POUNCE_RANGE := Vector2(3.0, 7.0)
const STOP_SHORT := 1.4
const SETTLE := 0.25
const SWING := 0.22
const STUCK := 0.8
static func choose(distance: float) -> Move
static func leap(from: Vector3, to: Vector3, lift: float, gravity: float, max_speed: float) -> Vector3   # pozioma prędkość
static func phase_after_landing(t: float) -> Phase
static func swing_hits(facing: Vector3, to_target: Vector3, reach: float, half_arc_deg: float) -> bool
static func pounce_recovery(lift: float, gravity: float) -> float
```
- [x] Testy: `choose` (1,5 → CLUB, 5 → POUNCE, 2,7 → CLUB, 8 → NONE); `leap` ląduje 1,4 m przed celem w czasie lotu `2·lift/g` (symulacja kroków), nie szybciej niż max; fazy po lądowaniu w kolejności i czasach; `swing_hits` — przód tak, bok 70° nie, za daleko nie; `pounce_recovery` ≥ lot + osiadanie + cios + utknięcie.

## Zadanie 6: `Jaguar` + `JaguarRig`

**Pliki:** `src/enemies/jaguar.gd`, `src/enemies/visuals/jaguar_rig.gd`; test `tests/integration/test_jaguar.gd`.

- [x] `Jaguar` (Enemy): statystyki z tabeli; prędkość wg stanu (polowanie 6,2, inaczej 3,0); wejście w ATTACK: `JaguarMoves.choose` → ruch, `brain.recovery` wg ruchu; cios (koniec przysiadu): POUNCE → skok (`leap`), CLUB → cios od razu; po lądowaniu fazy: osiadanie → cios (`swing_hits`, linia wzroku) → utknięcie; lądowanie: wióry, `weight_thud`, lekki wstrząs blisko; strefy: tułów (z obrotem), miednica, głowa + twarz (słaby punkt).
- [x] `JaguarRig`: wyprostowany chód ↔ sprint na czworakach (mieszanie `_low`), przysiad (kit), lot (maczuga nad głową, nogi zgięte, ogon w tył), osiadanie (głęboko w kolanach), cios `MotionClip` (+150° → +20° → −10° z odbiciem sprężyny), utknięcie (maczuga w ziemi, powolne wstawanie), ogłuszenie (na kolano), głowa śledzi strażnika (±45°), ogon 2 stawy na sprężynach (reaguje na przyspieszenie i skręt), sen = posąg.
- [x] Testy: doskok z 6 m kończy się ciosem maczugą (trafienie 18 po wylądowaniu, nie w locie); maczuga z bliska; uskok w bok w locie = brak trafienia; nisko w sprincie (strefa głowy niżej niż 1,2 m w sprincie, ~1,6 m stojąc); 4 strzały z pistoletu (70) niszczą, Pył 5.

## Zadanie 7: `FuDogMoves` (czysta logika psa Fu)

**Pliki:** `src/enemies/fu_dog_moves.gd`; test `tests/unit/test_fu_dog_moves.gd`.

```gdscript
class_name FuDogMoves extends RefCounted
enum Move { NONE, CHARGE, ROAR, PAW }
const CHARGE_RANGE := Vector2(4.0, 12.0)
const ROAR_RANGE := 6.0
const ROAR_HALF_ARC := 40.0
const PAW_RANGE := 2.6
const PAW_HALF_ARC := 50.0
static func choose(distance: float, off_front_deg: float, roar_ready: bool, charge_ok: bool, roll: float, roar_bias: float) -> Move
static func roar_hits(mouth: Vector3, forward: Vector3, guard: Vector3) -> bool
static func charge_turn(direction: Vector3, to_guard: Vector3, elapsed: float, delta: float) -> Vector3
class Pair: var a; var b; var charging; func may_charge(dog, guard_staggered: bool) -> bool; func begin_charge(dog); func end_charge(dog)
```
- [x] Testy: blisko i od frontu → PAW; ≤ 6 m od frontu i ryk gotowy → ROAR albo CHARGE wg `roll` i `roar_bias`; 4–12 m → CHARGE; bez gotowości ryku i bez zgody na szarżę → NONE; `roar_hits` — przód 5 m tak, 7 m nie, 60° nie; `charge_turn` skręca najwyżej 0,5 rad/s i tylko przez pierwsze 0,3 s; para — jedna szarża naraz, żadna przy oszołomionym strażniku.

## Zadanie 8: `FuDog` + `FuDogRig` + `RoarWave`

**Pliki:** `src/enemies/fu_dog.gd`, `src/enemies/visuals/fu_dog_rig.gd`, `src/fx/roar_wave.gd`; test `tests/integration/test_fu_dog.gd`, `tests/integration/test_player_stagger.gd` (już w zad. 0).

- [x] `FuDog` (Enemy): zderzacz poziomy (kapsuła wzdłuż ciała), plan ruchu co 0,5 s (`choose`) ustawia `attack_range` i `windup` mózgu; szarża po ciosie: prędkość własna, kontakt z przodem ciała raz, ściana → `brain.stun(1.4)` + iskry + wstrząs, koniec → poślizg; ryk po ciosie: `fu_roar`, `RoarWave`, `roar_hits` + linia wzroku → `target.stagger(0.5)`; trafienie w perłę (`info.weak_point`) w zapowiedzi ryku → `brain.stun(1.2)`; łapa — cios jak u rycerza w stożku; para: szuka partnera przy ustawieniu w `_ready` (≤ 18 m, ta sama sala), lwica dostaje lustro (od pierwszej klatki) i `roar_bias` 0,6.
- [x] `FuDogRig`: ciężki chód (pary boczne, kołysanie ciała), galop szarży (przód ±35° naprzemiennie z tyłem, łeb nisko), grzebanie (prawa łapa dwa razy w tył, iskry z pazura), ryk (łeb +20°, szczęka −28°, pierś w górę, ciało do tyłu i do przodu), perła świeci w zapowiedzi ryku (`glow` na `pearl`), łapa (uniesienie i uderzenie z odbiciem), zderzenie / ogłuszenie (łeb trzęsie się, nogi rozjechane), ogon pióropusz na sprężynach; prawa przednia łapa schodzi z kuli przy przebudzeniu, **kula zostaje na cokole** (stała pozycja świata), we śnie łapa na kuli; lustro lwicy bez odbić w odłamkach.
- [x] Testy: szarża po zapowiedzi ≥ 0,75 s trafia stojący cel (22), w ścianę → ogłuszony; ryk oszołamia cel w 5 m od frontu (nie w 8 m, nie z tyłu), perła świeci przed rykiem; strzał w perłę w zapowiedzi → ogłuszony, bez ryku; para — dwa psy nie szarżują naraz; kula zostaje w miejscu, gdy pies idzie.

## Zadanie 9: `SamuraiArmor` + `SamuraiRig`

**Pliki:** `src/enemies/samurai_armor.gd`, `src/enemies/visuals/samurai_rig.gd`; testy `tests/unit/test_samurai_armor.gd`, `tests/integration/test_samurai_armor_arena.gd`.

- [x] `SamuraiArmor extends Knight`: liczby z tabeli, model `samurai_ashigaru` przez `SamuraiRig`; `static func thrust_hits(forward, to_target, reach, half_arc_deg) -> bool`; cios = wypad (`shove`) + `thrust_hits` + linia wzroku; żar oczu: `OmniLight3D` na znaczniku `face` (migotanie, 0 we śnie, rozbłysk w zapowiedzi); `hoplite_thrust` przy pchnięciu, `samurai_glint` (−8 dB) przy błysku.
- [x] `SamuraiRig extends KnightRig`: sen / spokój = yari pionowo (`weapon` +1,45), kamae = sode w górę i do środka, yari poziomo; zapowiedź: ramię w tył z kompensacją drzewca (yari cofa się poziomo), skręt tułowia, szeroka postawa; błysk w 55% zapowiedzi (`Fx.flash` przy `spear_tip`); pchnięcie 0,12 s, przytrzymanie 0,15 s, powolny powrót; ogłuszony = sode opada, grot do ziemi, głowa w dół.
- [x] Testy: `thrust_hits` (przód 3 m tak, 4 m nie, 40° nie); postawa: polując sode podniesione (`arm_l` > 0,3 rad), czołowy strzał zablokowany, z boku trafia, paralizator opuszcza zasłonę; pchnięcie trafia cel 2,8 m przed nim (20), nie trafia celu 2 m z boku; Pył 8.

## Zadanie 10: weryfikacja i raport

- [x] Pełny zestaw `bash tools/run_tests.sh` (jeden proces), zielono i bez linii ERROR.
- [x] Ten plan: dopisać „Stan po wykonaniu” (odstępstwa, strojenie).
- [x] Commity per wróg; raport dla kontrolera.

---

## Samoocena planu

- Pokrycie: §5.4 (stada 4–6, trzepot, nurkowanie z zapowiedzią, 18 HP, ogień ×2, papierowe gore, Pył 2, sen na półkach) — zad. 1–2; §5.6 totem (3–5 twarzy, wieżyczki z zapowiedzią oczami, od góry, szybciej przy mniejszej liczbie, 30 HP/twarz, Pył 3) — zad. 3–4; jaguar (doskok cięższy niż wilk, niska sylwetka, maczuga po lądowaniu, 70 HP, Pył 5) — zad. 5–6; §5.5 pies Fu (160 HP, szarża 6 m/s z zapowiedzią 0,8 s, ryk ogłusza 0,5 s z 6 m, perła świeci 0,7 s, iskry, słaby punkt perła, pary, Pył 8) — zad. 7–8 + oszołomienie w zad. 0; zbroja samuraja (logika rycerza, sode, pchnięcie yari, żar oczu, Pył 8) — zad. 9; §7.2 — wszyscy dziedziczą percepcję `Enemy`; spawner — zad. 0.
- Każdy atak ma zapowiedź ≥ 0,6 s widoczną na wysokości oczu (okładki/oczy ksiąg 1,7–2,6 m, oczy twarzy totemu, maczuga nad głową jaguara, łeb i perła psa, błysk grotu yari) i czytelną ucieczkę (uskok, zasłona, obejście, zestrzelenie).

---

## Stan prac / co dalej (10.10, gałąź `enemies-east`, drzewo `.claude/worktrees/voice-g1`)

**Zrobione i przetestowane — zad. 0–9 (po jednym commicie na wroga), spawner buduje `books`, `totem`, `jaguar`, `fu_dog`, `samurai_armor`** (sloty `[bust, totem]`, `[wolf, jaguar]`, `[wolf, fu_dog]`, `[knight, samurai_armor]` dają teraz rodzaj docelowy). Zad. 0–2 (drewno, dźwięki, oszołomienie, kartki, spawner, `BookFlock`, latające księgi) zrobione na `pietro-1` (gałąź scalona).
- **Totem** (zad. 3–4): `TotemFaces` (`test_totem_faces.gd`, 7), `Totem` + `TotemRig` (`test_totem.gd`, 14 po poprawkach: 150 HP z 5 twarzy i Pył 3·n, strzał od góry zdejmuje twarz (blok ukryty, czapa opada), niższa ×0,35, słaby punkt wędruje w dół, oczy świecą ≥ 0,6 s przed strzałem i odłamek rani strażnika (`Player`), bez strzału przez ścianę, 5 vs 2 twarze: odstęp 2,0 vs 1,1 s, trafienie strzelającej twarzy w zapowiedzi odwołuje strzał, ostatnia twarz = śmierć, pobudka: twarze obracają się po kolei od dołu i wszystkie celują w strażnika).
- **Wojownik-jaguar** (zad. 5–6): `JaguarMoves` (5), `Jaguar` + `JaguarRig` (`test_jaguar.gd`, 8 po poprawkach: doskok z 6 m kończy się ciosem po wylądowaniu (faza STUCK w chwili trafienia), maczuga z bliska 0,22 s po zamachu, uskok 3,5 m w bok w locie = chybienie i powrót do polowania, w sprincie hełm < 1,2 m (strefa idzie za modelem), 4 strzały z pistoletu, posąg budzi się w sekundę).
- **Pies Fu** (zad. 7–8): `FuDogMoves` (6), `FuDog` + `FuDogRig` + `RoarWave` (`test_fu_dog.gd`, 17 po poprawkach: szarża po ≥ 0,75 s zapowiedzi z dwoma grzebnięciami trafia 22, w ścianę → ogłuszony, ryk po perle (≥ 0,6 s) oszołamia 0,5 s i nie przez ścianę, strzał w świecącą perłę dławi ryk, łapa 14 z 0,6 s, para nie szarżuje naraz a lwica jest lustrem (`scale.x = −1`, `roar_bias` 0,6), kula zostaje na cokole gdy lew odchodzi, chybiona szarża kończy się poślizgiem i wczesnym powrotem).
- **Zbroja samuraja** (zad. 9): `SamuraiArmor` + `SamuraiRig` (`test_samurai_armor.gd` 2, `test_samurai_armor_arena.gd` 6: 180 HP na zasadach rycerza, sode blokuje ±70° a paralizator je opuszcza, we śnie yari pionowo (stojak) a polując kamae (yari poziomo, sode w górze, żar oczu), pchnięcie 20 w 2,8 m po 0,8 s z wypadem ~0,5 m, 2 m w bok = chybienie, żar rozbłyska i grot błyska w zapowiedzi).
- Każdy nowy wróg ma kontekst wystawowy i czytelne przejścia (uwaga #8 właściciela): totem śpi twarzami do przodu i budzi się skrzypiąc twarz po twarzy, czuwając omiata salę, zasypia obracając twarze do przodu; jaguar jest posągiem, budzi się skrzypnięciem drewna i zwrotem głowy, bezczynny oddycha, przenosi ciężar i śledzi głową, wraca na posterunek jako posąg; pies Fu śpi z łapą na kuli, budząc się zdejmuje łapę (brzęk brązu) a kula zostaje, bezczynny patrzy, oddycha i macha pióropuszem; samuraj stoi jak na stojaku z yari pionowo, zaalarmowany przyjmuje kamae, spokojny wraca do stojaka.

**Odstępstwa i doprecyzowania**
- Totem: przy równym wycelowaniu strzela **górna** twarz (ta, w którą strażnik celuje — nagroda: trafienie jej w zapowiedzi odwołuje strzał). Zdrowie = `max_health · twarze / 5` po `tune` (mnożnik trudności zachowany; `faces_left` liczy po `max_health / twarze`). Trafienie bez `info.position` liczy się jak w górną twarz. Skrzypienie drewna = `portrait_creak` (brak osobnego dźwięku). Pobudka: twarz k rusza po 0,18·(k−1) s; oczy zapalają się w 12 % zapowiedzi (cała zapowiedź czytelna).
- Jaguar: sprint głębszy niż w kicie (miednica −0,42, kolana −1,3), żeby hełm zjechał pod 1,2 m; skok **zobowiązany** od chwili wybicia (bez docelowania po lądowaniu), cios wypada na końcu zamachu (SETTLE + SWING po lądowaniu), lądowanie ~1,2–1,4 m przed strażnikiem (krok fizyki). `JaguarMoves.choose`: < 3 m maczuga, 3–7 m doskok, dalej NONE (podchodzi).
- Pies Fu: nowa, dopisana metoda `EnemyBrain.cut_recovery(remaining)` — koniec szarży (trafienie/chybienie) skraca odnowienie do poślizgu 0,5 s + powrotu 0,9 s. Stożek ryku liczony od przodu ciała (nie głowy). Strefy trafień jadą za modelem **tylko pozycją** (lustro lwicy: odbita baza nie nadaje się na strefę). W parze lwem jest pies **wstawiony pierwszy** (kolejność `PerceptionWorld.exhibits()`), lwicą drugi. Kula po przebudzeniu przechodzi z modelu pod rodzica wroga (zostaje po jego śmierci). Zderzacz: kapsuła pozioma r 0,55 wzdłuż ciała.
- Samuraj: `SamuraiRig.build_samurai()` (sygnatura `KnightRig.build` jest zajęta), `shed_plate` rycerza bez zmian (5 płyt), `_uses_attack_ring` jak hoplita (trzyma miejsce na pierścieniu w zasięgu yari). Skręt yari kompensuje ruch ramienia, więc drzewce zostaje poziome w cofnięciu i pchnięciu.
- Pliki wspólne: `tests/integration/test_mummy_tomb.gd` („rodzaj, którego jeszcze nie ma” → `[knight, samurai]` z podziemi; po przeglądzie wymyślony `kind_yet_to_come`, żeby test nie zależał od przyszłych rodzajów), `tests/support/floor1_route.gd` (`KIND_HP` jaguar 35 → 70), `src/game/night_spawner.gd` (`BUILDS`, `make()`), `src/enemies/enemy_brain.gd` (`cut_recovery`, dopisane).

**Do sprawdzenia w oknie** (bez okien w tej sesji — do obejrzenia, gdy właściciel pozwoli)
- Totem: lot kawałków bloku i odbicie czapy (czy czapa nie przecina bloku przy spadaniu), czytelność świecących oczu z 20 m i rozbłysk po utracie twarzy, sekwencja skrzypiącej pobudki, omiatanie twarzy w czuwaniu, kolor/poświata odłamka (cedr + bursztyn), wysokość strefy pnia vs. kamienny kołnierz.
- Jaguar: sprint na czworakach (lewa ręka-łapa wisi ~0,45 m nad podłogą — model ma krótsze ramiona), maczuga nad głową w locie i cios z `MotionClip`, poza „maczuga w ziemi”, sprężyny ogona, przejście posąg → żywy, strefy trafień w przysiadzie.
- Pies Fu: prawa przednia noga jest wyrzeźbiona krótsza (uniesiona na kulę) — po przebudzeniu stąpa wysoko, nie sięga podłogi; galop szarży, iskry grzebnięć przy łapie (`_paw()` szacuje pozycję łapy z `shin_fr`), pierścienie `RoarWave` (skala, przezroczystość, czas), normalne lustra lwicy, pozycja kuli względem cokołów z `asia.gd`, poślizg po szarży, poza po zderzeniu ze ścianą.
- Samuraj: czy drzewce yari rzeczywiście zostaje poziome w cofnięciu/pchnięciu, poza sode w kamae vs. łuk blokady ±70°, miejsce i siła żaru oczu przy `face`, błysk grotu `Fx.flash` (jasność), płyty strącane z ashigaru.
- Wszyscy: cokoły/konteksty wystawowe pod slotami (`americas.gd`, `asia.gd` stawiają sloty na podłodze — ewentualne postumenty to robota ubierania sal), czytelność zapowiedzi w świetle Piętra I, Pył i liczniki muzeum (każdy nowy rodzaj to pojedynczy eksponat ze slotu).

**Poprawki po przeglądzie kodu (10.10; commity po przeglądzie, TDD: najpierw test czerwony)**
1. *Totem śpi z twarzami odwróconymi:* po zaśnięciu twarze wracają do przodu z połową szybkości, a `ExhibitRig` przestawał pozować 90 klatek po `DORMANT` — blok zostawał zamrożony w pół obrotu. `TotemRig._physics_process` zeruje `_still_frames`, dopóki któraś `face_yaw(k)` jest niezerowa (test: po 5 s snu bloki modelu stoją w domu; scenariusz: strażnik znika za plecami, słup przeszukuje, wraca, zasypia).
2. *Szarża psa Fu a strojenie nocy:* obrażenia = `FuDog.charge_damage()` = `attack_damage · 22 / 14` (trudność, pełnia i godzina duchów skalują szarżę jak łapę). Test: pies „podwójnej zmiany”, pies po `NightWatch.boost`.
3. *Prędkości:* jaguar nie nadpisuje już `move_speed` co klatkę — `move_speed` zostaje jego chodem (to mnoży strojenie i godzina duchów), a w kroku polowania chwilowo ×`SPRINT / WALK`; szarża psa biegnie z `charge_speed()` = `CHARGE_SPEED · move_speed / WALK`. Odstępstwo od „`_speed_scale` z `_ready`”: mnożnik liczony na żywo, bo `NightWatch.boost` przychodzi PO `_ready` (3:00 w trakcie nocy) — zapamiętany w `_ready` by go zgubił.
4. *Lwica a lustro:* para zawiązuje się przy ustawieniu (`_ready` drugiego psa; lew = pierwszy w `PerceptionWorld.exhibits()`), lustro od pierwszej klatki — wcześniej lustro zakładało się, gdy lew się obudził, nawet gdy ona jeszcze spała (przeskok). Okresowe szukanie partnera w trakcie nocy usunięte. Test: śpiąca lwica jest lustrem, budzenie lwa nic nie zmienia.
5. *Umierająca lwica:* `Fx.piece` przy wyznaczniku bazy < 0 przenosi lustro na siatkę (`view`), ciało fizyczne dostaje właściwy obrót. Testy: `test_fx.gd` (kawałek odbitego modelu) i zabita lwica (brak ciał z det < 0, lustro na siatkach).
6. *Totem a ogień:* tyknięcia palenia (`info.periodic`; płomień siedzi ~0,9 m nad podłogą = blok 1) pomijają współczynnik martwego drewna — ogień zjada cały słup. Test.
7. *Totem czuwający bez bodźca:* bez `brain.last_known` (dokładnie zero = nic nie widział ani nie słyszał) nie omiata świata od początku układu — twarze stoją do przodu. Test.
8. *Pył totemu:* `_configure` ustawia `DUST_FROM_FACES` (−1), `_ready` liczy 3·n tylko wtedy; wartość ustawiona przez wywołującego (np. `CALLED_DUST` strażnika) zostaje. Test.
9. *Kula po psie:* kula zostawiona na cokole jest w grupie `Enemy.PROP_GROUP`; `Museum._on_dawn` szarzeje ją razem z eksponatami (`Enemy.turn_to_stone`, wspólne z `freeze()`), a ginie ze sceną. Test: kula przeżywa psa i jest w grupie; test świtu (`test_night_watch.gd`) sprawdza szarzenie. **Wznowiona noc:** pies zabity wcześniej nie zostawia kuli (była częścią jego modelu, a slot jest pomijany) — pusty cokół; żywy pies wraca uśpiony z łapą na kuli. To kosmetyka, świadomie nieodtwarzana.
10. *Szarża a niskie gabloty:* `charge_ok` wymaga czystej linii na wysokości kolan (`FuDog.KNEE_HEIGHT` 0,45 m, tylko gdy pies w ogóle rozważa szarżę, 4–12 m) — pies nie rozpędza się w niską gablotę, nad którą widzi strażnika. Test.
11. `test_mummy_tomb.gd`: „rodzaj, którego jeszcze nie ma” to wymyślony `kind_yet_to_come`, nie `samurai`.
12. Nowe testy: `EnemyBrain.cut_recovery` (jednostkowe, 2), umierająca lwica, totem wracający do snu, szarża pod trudnością i godziną duchów, śpiąca lwica, niska gablota, kula (patrz wyżej).
13. Plan: zad. 0–2 odhaczone (zrobione na `pietro-1`), „Stan prac” uzupełniony.
14. *Drobiazgi:* `TotemRig` buduje nazwy części raz (nie formatuje napisów co klatkę); zdjęcie ostatniej twarzy / kilku twarzy jednym ciosem daje jedno `break_wood` (zabójczy cios łamie drewno przez `_destroy`). Test liczy głosy `break_wood` w `Sfx`.

**Co dalej**
- Zad. 10 zrobione; po przeglądzie kodu i `git merge pietro-1` pełny zestaw **2171 testów zielonych (2155 przed poprawkami + 16 nowych), 0 błędów, bez linii ERROR**. Dalej: strojenie po pokazie w oknie (lista wyżej), ewentualne cokoły pod slotami przy ubieraniu sal.
