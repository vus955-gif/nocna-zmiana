# P1 / W5b — podziemia i dach: plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`, commit po każdym zadaniu. Wykonuje Claude (W5b) w drzewie `.claude/worktrees/p1-w5-below`, gałąź `p1-w5-below` (z `pietro-1`).
> Wiążące: `docs/superpowers/plans/2026-10-02-p1-fundament.md` (bryły stref, przejścia, zasady budowniczych, strumień W5b), projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §3.4, §4.4, §4.5, §5.8, §7.2, §10.1. Wzorce: W2 (`zones/court.gd`, `booth.gd`, `hub_kit.gd`, testy `test_floor1_hub*`), W3 (`zones/egypt.gd`, `greece.gd`, `west_kit.gd`, testy `test_floor1_west*`), integracja W1 (`src/game/floor1/*`).

**Cel:** prawdziwy greybox **podziemi** (y = −6) i **dachu** (y = 22,5) Piętra I. Podziemia to sieć skrótów, dzięki której muzeum „klika”: pierścień korytarzy pod obwodem dziedzińca, krzyż korytarzy z warsztatem renowacji (przystań) w środku, kotłownia z pomostem i pierwszym bezpiecznikiem, rozdzielnia, magazyny z sekretami, tunel pod Salą Kolosa do Asyrii, zejście ze schodów służbowych kanciapy. Dach to opcjonalny, „zapierający dech” spacer: wieża schodów nad kanciapą, taras techniczny, kładki nad szklanym dachem dziedzińca wokół kopuły Czytelni, zasuwa do wieży Oświecenia.

**Architektura:** dwa moduły stref (`zones/basement.gd`, `zones/roof.gd`, `static func build(layout)`) wypełniają `LevelLayout` czystymi danymi przez `Floor1Greybox`; wspólne drobiazgi obu stref w nowym `zones/service_kit.gd` (grupa migających świetlówek, świetlówka-reflektor, rura w kolorze skrzydła, balustrada, brama-sekret). Pomocniki W2/W3 (`hub_kit.gd`: tabliczki skrzydeł, lampy, sloty, patrole; `west_kit.gd`: zasadzka-legowisko, poświata, lampa awaryjna) używane bez zmian. `Floor1Layout` dokłada otwory przejść stref. Testy: jednostkowy na danych (`test_floor1_service.gd`) i integracyjny na zbudowanym piętrze (`test_floor1_service_walk.gd`).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, tabulatory, `bash tools/run_tests.sh --filter=…` (bez okna, bez dźwięku, nigdy dwa Godoty naraz).

---

## Pliki

| Plik | Co robi |
|---|---|
| `src/level/floor1/zones/basement.gd` | moduł podziemi (zastępuje szkielet części A) |
| `src/level/floor1/zones/roof.gd` | moduł dachu (zastępuje szkielet) |
| `src/level/floor1/zones/service_kit.gd` (nowy) | pomocniki obu stref: `FLICKER`, `tube()`, `pipe()`, `rail()`, `secret_gate()` |
| `tests/unit/test_floor1_service.gd` (nowy) | testy danych podziemi i dachu |
| `tests/integration/test_floor1_service_walk.gd` (nowy) | testy na zbudowanym piętrze (siatka, kapsuła, bramy) |
| `locale/strings.csv` | klucze `ROOM_BASEMENT_*`, `ROOM_ROOF_*` — **tylko dopisane na końcu** |
| ten plik | plan + na końcu „jak zbudowano / odstępstwa” |

Nie ruszam: `floor1_plan.gd` (prośby w raporcie), modułów innych stref, plików W1, testów części A (mają zostać zielone).

## Ograniczenia, które kształtują projekt

1. **Wysokości.** Bryła podziemi kończy się na y −0,5, a strop ma 0,5 m (`ShellCarver.ROOF_T`): najwyższy sufit podziemi to **−1,0** (sale do 5 m), korytarze 3,5 m (sufit −2,5). Dach zaczyna się na 22,5 i kończy na 32: sufit kładek 30,0, studnie świetlików do 31,5.
2. **Pomost w kotłowni** musi mieć ≥ 2 m nad sobą (wysokość agenta nawigacji 2,0 m) i ≥ 2,4 m pod sobą (drzwi): pomost na **y −3,2** (płyta 0,4: 2,2 m nad, 2,4 m pod). Drzwi pod pomostem mają 2,4 m.
3. **Skrzydła drzwi.** SWING otwiera się do pokoju B i leży wzdłuż ościeża (ok. 1,4 m w głąb sali przy murze 0,5 m) — przy każdych drzwiach w sali B wolne ≥ 2 m, bez elementów i schodów. Przejście `j_booth_basement` (DOUBLE_SWING, A = kanciapa) otwiera się do **mojego** korytarza: skrzydła mieszczą się w murze 1 m.
4. **Przystań = osobny region nawigacji.** Warsztat ma dwoje drzwi (krzyż ↔ korytarz warsztatowy) — skrót dla gracza, ale **nic nie leży tylko za nim**: każda sala podziemi jest osiągalna z pominięciem warsztatu (test na grafie sal).
5. **Dach dziedzińca to dziś pełna płyta** (szklany dach i kratownica to bryła-bohater P2). Kładki stoją **na** y 22,5 (podłoga sali dachu = płyta nad dziedzińcem); szklane pola między kładkami to elementy `roof_glass` (z kolizją, 5 cm, szkło P2 może je zastąpić 1:1). Nigdzie nie ma dziury w dół: nie da się spaść na dziedziniec (zeskok na balkon y 7 to 15,5 m — nie jest bezpieczny, więc go nie ma). Widok w dół = prośba do P2 (świetliki dziedzińca pod `roof_glass`).
6. **Światło nie przecieka przez stropy:** w podziemiach lampy sufitowe to reflektory w dół (stożek 70–80°), punktowe tylko nisko (czerwone awaryjne, żarówki skrzydeł) z zasięgiem kończącym się pod posadzką parteru; na dachu księżyc to reflektory w dół z zasięgiem kończącym się na y 22 (nic nie świeci w dziedzińcu przez płytę bez cieni).
7. **Migające świetlówki:** `LightSpec` ma jedną grupę na lampę, więc migające świetlówki dostają własną grupę `ServiceKit.FLICKER = &"flicker_lights"` (LevelLighting dodaje światło i oprawę do grupy, gra może nią migać). Prośba do kontrolera: `LightSpec.FLICKER` + zaciemnienie (`blackout`) gasi też tę grupę.
8. **Bez drzwi nocy (LOCKABLE):** reżyser na Piętrze I jeszcze ich nie losuje; dodanie ich zmieniłoby przebieg nocy W1 — opcja na później (raport).

---

## PODZIEMIA (y = −6)

Bryły: B1 x −30…30, z −38…30 (pod dziedzińcem i korytarzem północnym); B2 x −16…16, z 30…53 (pod holem); B3 tunel x −55…−30, z −37…−33 (pod Salą Kolosa). Przejścia po mojej stronie:

| Przejście | Otwór | Pokój po mojej stronie |
|---|---|---|
| `j_booth_basement` (deski) | x 16…17, z 37…39 | `basement_corridor_staff` (ściana wsch. x 16) |
| `j_basement_egypt` | x −31…−30, z −12,5…−10,5 | `basement_corridor_west` |
| `j_basement_assyria` | x −56…−55, z −36,5…−34,5 | `basement_tunnel` (zach. koniec) |
| `j_basement_greece` | x −28…−26, z 30…31 | `basement_corridor_south` |
| `j_basement_enlightenment` | x 30…31, z 28…30 | `basement_corridor_south` (wsch. koniec) |
| `j_basement_americas` | x −28…−26, z −39…−38 | `basement_corridor_north` |
| `j_basement_asia` | x 24…26, z −39…−38 | `basement_corridor_north` |

### Plan z góry (−Z = północ; x rośnie w prawo)

```
 x: -55        -30 -26.5 -26     -14.5 -14       -7  -3 0 3  7      14 14.5      26 26.5 30
z-38            ┌──[AMERYKI]───────────────────── KORYTARZ PÓŁNOCNY ────[krata krypty]───[AZJA]──┐
       TUNEL    │                                                    ═ rura turkus / czerwień ═   │
z-37 ┌──────────┤                 [dbl. drzwi x-2..2]                                          │
ASY- │▓▓ skrzynie◄┘                                                                              │
RIA═►│ ZATOKA WINDY   ─ tunel x-55..-30.5 ─                                                      │
z-33 └──────────┘ ┌──┐ ┌──────────────┐ ┌══════ POMOST y-3,2 (cały północ) ══════┐ ┌──────────┐ ┌──┐
z-34              │  │ │ PIWNICA      │ │▲schody      ◊para       ║            │ │ ROZDZIEL-│ │  │
                  │  │ │ MONTAGU HOUSE│ │║x-14..-12   ┌────┐  ┌────┐║noga wsch.  │=│ NIA      │ │  │
                  │  │ │ (sekret,spęk)│ │║  KOTŁOWNIA │KOC.│  │KOC.│║BEZPIECZNIK │ │ ▣panel   │ │  │
z-27.5            │  │ └────[spęk]───┘ │  x-14..14  │ W  │  │ E  │ (koniec,    │ │ trafo    │ │  │
                  │ W│ ┌──────────────┐=│  z-34..-17 └────┘  └────┘  bez barierki)│ │          │ │E │
                  │  │=│ MAGAZYN      │ │        palenisko ◄─ żar ─►            │ │          │ │  │
z-17              │  │ │ COKOŁÓW      │ └──────────[łuk x-3..3]─────────────────┘ │          │ │  │
z-16.5            │  │ │ I GABLOT     │          ┌──────────────────┐            │          │ │  │
z-13              │  │ └────[drzwi]───┘          │ FUNDAMENTY       │            └─[drzwi]──┘ │  │
z-12.5  EGIPT ═►  │  ══════ KORYTARZ POPRZECZNY W ═══│ CZYTELNI (krzyż) │═══ KORYTARZ POPRZECZNY E ═════  │
z-9.5             │  │ ┌────[drzwi]──────────────┐ │ ▪filary ▪        │ ┌────[drzwi]──────────────┐ │  │
z-9               │  │ │ MAGAZYN ZBIORÓW         │ └──[drzwi]─────────┘ │ ARCHIWUM                │ │  │
z-2               │  │ │ (regały w rzędach W–E,  │ ┌──────────────────┐ │ (rzędy szaf N–S)        │=│  │
                  │  │=│  alejki 5 m)            │ │ WARSZTAT         │ │                         │ │  │
                  │  │ │                         │ │ RENOWACJI        │ │                         │ │  │
z 9               │  │ │                         │ └──[drzwi]─────────┘ │                ┌────────┐│  │
z 9.5             │  │ │                         │  ║ KORYTARZ     ║    │      [łańcuch]►│KLATKA  ││  │
                  │  │ │                         │  ║ WARSZTATOWY  ║    │                │DEPOZYT.││  │
z 26              └──┘ └────[drzwi]──────────────┘  ║  x-2..2      ║    └────[drzwi]─────┴────────┘└──┘
z 26.5            ┌──[GRECJA]────────────────── KORYTARZ POŁUDNIOWY ───────────────────────[OŚWIECENIE]═►
z 30              └──────────────────────────────[łuk x-2..2]─────────────────────────────────────┘
                                         ┌──────────┘ └──────────────────────────┐
z 36                          ┌──────────┤  KORYTARZ POD HOLEM  x-12..16, z36..40  ├═► deski: KANCIAPA
z 40                          └─[hak]────┘      └─[drzwi]─┘                      (x 16, z 37..39)
z 40.5                   ┌──────────────┐               ┌──────────────┐
                         │ SCHRON       │               │ MAGAZYN      │
                         │ (sekret)     │               │ STRAŻY       │
z 52                     └──────────────┘               └──────────────┘
                         x -16..-4                      x 4..16
```

### Przepływ (Doom/Quake)

- **Pierwsze zejście (noc 1–2):** pięści na deskach „REMONT” w kanciapie → korytarz pod holem (migające świetlówki, jedna śpiąca figura) → łuk na osi x 0 → przez korytarz południowy prosto w **korytarz warsztatowy**: na jego końcu ciepłe światło warsztatu (latarnia przystani widoczna z 20 m) → odkrycie przystani → drzwi północne warsztatu wychodzą na **fundamenty Czytelni** (krzyż) → łuk na północ do **kotłowni** (żar palenisk, para, pomost) → bezpiecznik na końcu pomostu nad kotłami (zasadzka przy podniesieniu; ucieczka zeskokiem przez urwaną barierkę) → rozdzielnia (drzwi wschodnie kotłowni): panel z dwoma gniazdami, jedno puste — „brakuje bezpiecznika z Asyrii”.
- **Później:** zasuwy skrzydeł otwierane od środka skrzydeł wpuszczają do pierścienia; z warsztatu (przystań, start nocy) do drzwi każdego skrzydła jest 36–82 m po siatce (pomiar w teście chodzenia; najdalej Asyria — na końcu 25-metrowego tunelu): Egipt prosto na zachód osią korytarza poprzecznego (drzwi Egiptu leżą naprzeciw jego wylotu — 60 m linii wzroku przez cały krzyż), Grecja i Oświecenie korytarzem południowym, Ameryki i Azja korytarzem północnym, Asyria tunelem.
- **Pętle:** pierścień (4 korytarze) + krzyż (korytarze poprzeczne, kotłownia, warsztat/korytarz warsztatowy) = cztery kwadranty; każdy magazyn ma 2–3 drzwi (pierścień i krzyż), kotłownia 4 wyjścia (pn., krzyż, rozdzielnia, magazyn cokołów). Ślepe zaułki tylko tam, gdzie nagradzają: tunel (zatoka windy, drzwi Asyrii), pomost (bezpiecznik), sekrety.
- **Czytelność:** każde drzwi skrzydła mają czerwoną lampę awaryjną, żarówkę w kolorze skrzydła i tabliczkę w jego kolorze (`sign_basement_<skrzydło>_1`); rury pod stropem w kolorze skrzydła biegną od drzwi skrzydła do krzyża; na wylotach krzyża tabliczki kierunkowe (`sign_basement_<cel>_2`). Krata krypty w ścianie północnej (zamurowane drzwi z kratą, czerwona lampa) — zapowiedź finału, bez przejścia (plan go nie przewiduje).

### Sale podziemi

| Id | Prostokąt(y) (x0, z0 → x1, z1) | y podłogi … sufitu | Nazwa (klucz) | Uwagi |
|---|---|---|---|---|
| `basement_corridor_north` | −30, −38 → 30, −34,5 | −6 … −2,5 | `ROOM_BASEMENT_CORRIDOR_NORTH` | drzwi Ameryk i Azji; krata krypty |
| `basement_corridor_west` | −30, −34 → −26,5, 26 | −6 … −2,5 | `ROOM_BASEMENT_CORRIDOR_WEST` | drzwi Egiptu |
| `basement_corridor_east` | 26,5, −34 → 30, 26 | −6 … −2,5 | `ROOM_BASEMENT_CORRIDOR_EAST` | |
| `basement_corridor_south` | −30, 26,5 → 30, 30 | −6 … −2,5 | `ROOM_BASEMENT_CORRIDOR_SOUTH` | drzwi Grecji i Oświecenia |
| `basement_tunnel` | −55, −37 → −30,5, −33 | −6 … −2,5 | `ROOM_BASEMENT_TUNNEL` | zatoka windy towarowej x −55…−49; drzwi Asyrii |
| `basement_boiler` | −14, −34 → 14, −17 | −6 … −1 | `ROOM_BASEMENT_BOILER` | 28 × 17, h 5; dźwięk „boiler” |
| `basement_boiler_catwalk` | −14, −34 → 14, −32 + 12, −32 → 14, −25 | −3,2 … −1 | `ROOM_BASEMENT_CATWALK` | `carved = false`, pomost w kotłowni |
| `basement_crossing` | −7, −16,5 → 7, −2,5 | −6 … −1 | `ROOM_BASEMENT_CROSSING` | fundamenty Czytelni, 4 filary |
| `basement_corridor_spine_w` | −26, −12,5 → −7,5, −9,5 | −6 … −2,5 | `ROOM_BASEMENT_SPINE` | oś drzwi Egiptu |
| `basement_corridor_spine_e` | 7,5, −12,5 → 26, −9,5 | −6 … −2,5 | `ROOM_BASEMENT_SPINE` | |
| `basement_workshop` | −7, −2 → 7, 9 | −6 … −2 | `ROOM_BASEMENT_WORKSHOP` | **przystań `workshop`** |
| `basement_corridor_workshop` | −2, 9,5 → 2, 26 | −6 … −2,5 | `ROOM_BASEMENT_WORKSHOP_CORRIDOR` | oś hol → warsztat |
| `basement_store_plinths` | −26, −27,5 → −14,5, −13 | −6 … −2 | `ROOM_BASEMENT_PLINTHS` | magazyn cokołów i gablot |
| `basement_old_cellar` | −26, −34 → −14,5, −28 | −6 … −3 | `ROOM_BASEMENT_OLD_CELLAR` | **sekret** (spękany mur) |
| `basement_switchboard` | 14,5, −34 → 26, −13 | −6 … −2 | `ROOM_BASEMENT_SWITCHBOARD` | `switchboard` |
| `basement_reserve` | −26, −9 → −7,5, 26 | −6 … −2 | `ROOM_BASEMENT_RESERVE` | regały, 5 alejek |
| `basement_archive` | 7,5, −9 → 26, 17,5 + 7,5, 17,5 → 19,5, 26 | −6 … −2 | `ROOM_BASEMENT_ARCHIVE` | szafy aktowe |
| `basement_cage` | 20, 18 → 26, 26 | −6 … −3 | `ROOM_BASEMENT_CAGE` | **sekret** (łańcuch) |
| `basement_corridor_staff` | −12, 36 → 16, 40 + −2, 30,5 → 2, 36 | −6 … −2,5 | `ROOM_BASEMENT_STAFF` | od desek kanciapy |
| `basement_store_guards` | 4, 40,5 → 16, 52 | −6 … −2,5 | `ROOM_BASEMENT_GUARDS` | baterie, amunicja |
| `basement_shelter` | −16, 40,5 → −4, 52 | −6 … −3 | `ROOM_BASEMENT_SHELTER` | **sekret** (hak) |

Wszystkie `public = false` (plan dla zwiedzających ich nie drukuje — strażnik dorysowuje je ołówkiem).

### Otwory podziemi

| Id | Prostokąt | y | Pokoje (A ↔ B) | Styl / brama |
|---|---|---|---|---|
| `basement_north_west`, `basement_north_east` | −30…−26,5 / 26,5…30, z −34,5…−34 | −6…−2,5 | korytarz pn. ↔ zach. / wsch. | łuk (narożnik) |
| `basement_west_south`, `basement_east_south` | jw., z 26…26,5 | −6…−2,5 | zach. / wsch. ↔ pd. | łuk |
| `basement_north_tunnel` | x −30,5…−30, z −37…−34,5 | −6…−2,5 | pn. ↔ tunel | łuk |
| `basement_north_boiler` | x −2…2, z −34,5…−34 | −6…−3,6 | pn. ↔ kotłownia | DOUBLE_SWING (pod pomostem: 2,4 m) |
| `basement_boiler_crossing` | x −3…3, z −17…−16,5 | −6…−2 | kotłownia ↔ krzyż | łuk 6 × 4 m |
| `basement_boiler_switchboard` | x 14…14,5, z −22…−20 | −6…−3,4 | kotłownia ↔ rozdzielnia | SWING |
| `basement_boiler_store` | x −14,5…−14, z −22…−20 | −6…−3,4 | kotłownia ↔ magazyn cokołów | łuk |
| `basement_west_spine`, `basement_spine_w_crossing`, `basement_crossing_spine_e`, `basement_spine_e_east` | wyloty korytarzy poprzecznych, z −12,5…−9,5 | −6…−2,5 | | łuki |
| `basement_crossing_workshop` | x −1…1, z −2,5…−2 | −6…−3,4 | krzyż ↔ warsztat | SWING |
| `basement_passage_workshop` | x −1…1, z 9…9,5 | −6…−3,4 | korytarz warsztatowy ↔ warsztat | SWING |
| `basement_passage_south` | x −2…2, z 26…26,5 | −6…−2,5 | korytarz warsztatowy ↔ pd. | łuk |
| `basement_south_staff` | x −2…2, z 30…30,5 | −6…−2,5 | pd. ↔ pod holem | łuk |
| `basement_west_plinths`, `basement_spine_plinths` | x −26,5…−26, z −22…−20 / x −22…−20, z −13…−12,5 | −6…−3,4 | → magazyn cokołów | SWING |
| `basement_plinths_cellar` | x −21…−19, z −28…−27,5 | −6…−3,6 | magazyn ↔ piwnica | PANEL, GATE + `basement_cracked_cellar` (CRACKED, `explosive`) |
| `basement_spine_switchboard` | x 19…21, z −13…−12,5 | −6…−3,4 | poprzeczny E ↔ rozdzielnia | SWING |
| `basement_spine_reserve`, `basement_west_reserve`, `basement_south_reserve` | z −9,5…−9 / x −26,5…−26, z 4…6 / z 26…26,5 | −6…−3,4 | → magazyn zbiorów | SWING |
| `basement_spine_archive`, `basement_east_archive`, `basement_south_archive` | x 19…21, z −9,5…−9 / x 26…26,5, z 2…4 / x 12…14, z 26…26,5 | −6…−3,4 | → archiwum | SWING |
| `basement_archive_cage` | x 19,5…20, z 21…23 | −6…−3,6 | archiwum ↔ klatka | DOUBLE_SWING, GATE + `basement_chain_cage` (CHAIN, `heavy`) |
| `basement_staff_guards` | x 9…11, z 40…40,5 | −6…−3,4 | pod holem ↔ magazyn straży | SWING |
| `basement_staff_shelter` | x −9…−7, z 40…40,5 | −6…−3,6 | pod holem ↔ schron | GATE, GATE + `basement_hook_shelter` (HOOK, `harpoon`) |

### Kotłownia (wnętrze)

Dwa kotły kornwalijskie (bryły `boiler` 7,5 × 3 × 4) x −10…−2,5 i 2,5…10, z −29…−25, paleniskami na południe (żar: lampy awaryjne pomarańczowe — ogień nie ma bezpiecznika); między nimi przejście x −2…2 na osi drzwi północnych. Za kotłami korytarzyk (z −32…−29). **Pomost** (`basement_boiler_catwalk`, y −3,2): galeria wzdłuż całej ściany północnej (z −34…−32) + noga wschodnia nad kotłem E (x 12…14, z −32…−25); schody x −14…−12 wzdłuż ściany zachodniej (z −24,5 → −32, 2,8 m na 7,5 m = 20,5°); słupki, balustrady; **koniec nogi wschodniej bez barierki** (zeskok 2,8 m = ucieczka po zasadzce). `fuse_basement` na skrzynce na końcu nogi, obok syczącego zaworu (`steam_basement_2`). Znaczniki pary `steam_basement_1…3`. Kosz z węglem, stół palacza (notatka), rura parowa pod stropem.

### Znaczniki podziemi

| Znacznik | Gdzie | Pokój |
|---|---|---|
| `fuse_basement` | koniec nogi pomostu (13, −2,4, −25,8) | `basement_boiler_catwalk` |
| `switchboard` | ściana pn. rozdzielni, lico szafy 0,3 m od muru, −Z do sali | `basement_switchboard` |
| terminal `workshop` | ściana zach. warsztatu, −Z na +x | `basement_workshop` |
| `museum_map_workshop` | ściana wsch. warsztatu | `basement_workshop` |
| `note_basement_1…3` | warsztat (lista prac renowatorki), stół palacza (dziennik kotłowni), biurko elektryka (rozdzielnia) | |
| `secret_basement_1…3` | klatka depozytowa, piwnica Montagu House, schron | sekrety |
| `cctv_basement_1` | krzyż, nad łukiem kotłowni, patrzy na drzwi warsztatu | `basement_crossing` |
| `basement_freight_lift` | skrzynka przywołania windy (zach. koniec tunelu) | `basement_tunnel` |
| `basement_crypt_grille` | krata krypty w ścianie pn. (x 0) | `basement_corridor_north` |
| `steam_basement_1…3` | para: za kotłami, przy bezpieczniku, przy drzwiach pn. | kotłownia |
| `sign_basement_<skrzydło>_1` | nad drzwiami każdego skrzydła (6) i nad deskami kanciapy (`booth`) | |
| `sign_basement_<cel>_2` | wyloty krzyża: W — Egipt, Asyria, Grecja; E — Oświecenie; N (kotłownia) — Ameryki, Azja; S (warsztat) — kanciapa | `basement_crossing` |

### Spotkania podziemi („uciekinierzy z magazynu”)

Rodzaje (zastępca + docelowy): wosk `[wax]`, wilk `[wolf]`, rycerz `[knight]`, popiersie `[bust]`, mumia `[wax, mummy]`, hoplita `[knight, hoplite]`, skarabeusze `[wolf, scarabs]`, jaguar `[wolf, jaguar]`, samuraj `[knight, samurai]`. Gęstość na zestaw (z `ALWAYS_SET`): **0,4–0,8 na 100 m²**; sale < 125 m²: najwyżej 1 eksponat.

| Sala | Zawsze (`ALWAYS_SET`) | Zestawy | Patrol / zasadzka |
|---|---|---|---|
| korytarz pn. | — | 0: wosk na patrolu; 1: skarabeusze; 2: hoplita | `basement_north_walk` |
| korytarz zach. | — | 0: mumia przy drzwiach Egiptu; 1: hoplita na patrolu | `basement_west_walk` |
| korytarz wsch. | — | 0: wosk na patrolu; 1: jaguar | `basement_east_walk` |
| korytarz pd. | — | 0: popiersie; 1: samuraj na patrolu | `basement_south_walk` |
| tunel | mumia w skrzyniach | — | zasadzka `basement_freight` (zatoka windy) |
| kotłownia | rycerz przy palenisku + skarabeusze za kotłem | 0: wosk na patrolu; 1: hoplita; 2: popiersie | `basement_boiler_round`; zasadzka `basement_fuse` (podniesienie bezpiecznika) |
| krzyż | — | 0: popiersie; 1: rycerz | — |
| magazyn cokołów | — | 0: wosk; 1: hoplita | — |
| rozdzielnia | rycerz („zbroja elektryka”) | — | zasadzka `basement_switchboard` (przed panelem) |
| magazyn zbiorów | — | 0: 3 (wosk na patrolu, mumia, popiersie); 1: 4; 2: 3 | `basement_reserve_aisle` |
| archiwum | — | 0: 3; 1: 3 (wosk na patrolu); 2: 4 | `basement_archive_aisle` |
| pod holem / magazyn straży | — | po 1 śpiącym (bez wilków: pierwsze zejście) | — |
| piwnica / schron | wosk („założyciel”) / wosk („strażnik OPL”) | — | legowiska `basement_cellar`, `basement_shelter` |
| warsztat, korytarz warsztatowy, poprzeczne, klatka, pomost | — | — | (przystań i przejścia) |

### Światło podziemi (§10.1: świetlówki, migotanie, czerwień awaryjna)

Świetlówki co ~10 m (reflektory w dół, zimna zieleń `TUBE`), co trzecia–czwarta w grupie `flicker_lights`; nad drzwiami skrzydeł czerwona lampa awaryjna + żarówka w kolorze skrzydła; kotłownia: żar palenisk (pomarańczowy, grupa awaryjna), świetlówki nad przejściem, żarówka w koszu na pomoście; krzyż: reflektor w środku + żarówki przy filarach; warsztat: ciepłe lampy `haven_lights` (lampa na stole, świetlówka, lampka przy terminalu); sekrety: wąskie poświaty w dół (nie przenikają do sąsiadów); schron: czerwona lampa z 1940.

---

## DACH (y = 22,5)

Bryły: R1 x −30…30, z −30…30 (y 22,5…32, nad dziedzińcem); R2 x 17…30, z 30…36; R3 x 17…38, z 36…53 (y 4…32, nad kanciapą). Przejścia: `j_entrance_roof` x 16…17, z 50…52, **y 6** (lina, z holu) → pokój `roof_stairs`; `j_roof_enlightenment` x 30…31, z −12…−10,5, y 22,5 (zasuwa od Oświecenia) → pokój `roof_catwalks`.

```
 x: -30 -26.5 -23.5        -1.5 0 1.5              26.5 30      38
z-30 ┌──────┐┌──────────────── RYNNA PN. ─────────────────────┐
     │SZOPA ║│  ░░░ szkło NW ░░░  ║N║  ░░░ szkło NE ░░░        │
z-25 │(sek.)═╡                     ║ ║                          │
     └──────┘   ║ (widok na T-Reksa: roof_view_1)               │
z-26.5 ═════════╝ ┌───── kładka wokół kopuły (ośmiokąt a 15,5) ─┐ ═══ RYNNA WSCH. (x 26.5..30)
     ║            │        ┌───────────┐                       │     ◄═ ZASUWA OŚWIECENIA
     ║ RYNNA ═W═══╡ ♜chess │  KOPUŁA   │                       ╞═E══ (x 30, z -12..-10.5)
     ║ ZACH.      │        │ CZYTELNI  │ ✶ lampa ostrzegawcza   │
     ║            │        └───────────┘                       │
z 26.5 ═══════════└────────────────║S║─────────────────────────┘ ══
     │  ░░░ szkło SW ░░░          ║ ║          ░░░ szkło SE ░░░ ┌──────┐
z 30 └─────────────────── RYNNA PD. ─────────────── [przejście x23..30] ┘
                                                    │ MOSTEK   │ (R2: x 22.5..30, z 30.5..36)
z 36                                     ┌─────────┬┴──────────┴──────────┐
                                         │ GOŁĘB-  │ TARAS TECHNICZNY    │ (x 22.5..38, z 36..44.5)
                                         │ NIK     ◄lina  agregaty  zbiornik│
z 44.5                                   │ (sek.)  │              [drzwi x34.5..36.5]
z 45                                     ├─────────┴────────────────────────┤
                                         │ WIEŻA SCHODÓW y 6 → 22,5 (3 biegi) │◄═ lina: podest holu (x 17, z 50..52)
z 53                                     └──────────────────────────────────┘
                                           x 17                            37
```

### Decyzje

- **Wieża** (`roof_stairs`, x 17…37, z 45…53): `Grey.tower(…, 6, 22,5, 3 biegi, tor 1, w górę)` jak w szkielecie — dolny spocznik przy drzwiach z liną, górny spocznik na wschodzie (x 34,3…37), drzwi na taras (x 34,5…36,5).
- **Taras techniczny** (`roof_plant`: x 22,5…38, z 36…44,5 + mostek x 22,5…30, z 30,5…36): agregaty, zbiornik wody, komin; mostek nad rynną schodzi szerokim przejściem (x 23…30) na dach dziedzińca. Gołębnik (`roof_loft`, sekret, x 17…22) za klapą na **linie** (`roof_rope_loft`, precyzja).
- **Kładki nad szklanym dachem** (`roof_catwalks`, cały R1 bez narożnika NW): **rynna** dookoła (pas 3,5 m), **kładka wokół kopuły** (ośmiokątna balustrada, apotema 15,5), **cztery promieniste kładki** N/E/S/W (3 m) — pętle w każdą stronę. Między nimi cztery **szklane pola** (`roof_glass`, kolizja 5 cm) ogrodzone balustradami z furtką serwisową w każdym (nie da się w nich utknąć). **Kopuła Czytelni** w środku: bęben 16 segmentów (lico 12,26 — ciągnie bęben W2 przez dach), pełny rdzeń, trzy stopnie kopuły i latarnia z czerwoną lampą ostrzegawczą (punkt orientacyjny z każdego miejsca dachu). Kładka N biegnie nad postumentem T-Reksa (`roof_view_1`), S nad łukiem holu (`roof_view_2`) — dla P2: tu szkło ma zostać przejrzyste.
- **Droga główna** (skrót): podest holu → wieża → taras → mostek → rynna wschodnia → zasuwa Oświecenia (ok. 45 m po dachu). **Spacer opcjonalny:** promieniem E na kopułę, dookoła kopuły (za nią `chess_8` na gzymsie od zachodu), promieniem N nad T-Reksa, rynną zachodnią do **szopy dekarzy** (sekret za deskami, `roof_boards_shed`) i z powrotem rynną południową.
- **Światło:** tylko księżyc (`LightSpec.MOON`: reflektory w dół nad rynnami, promieniami i tarasem, zasięg kończy się nad płytą dziedzińca) + dwie małe czerwone lampy ostrzegawcze (latarnia kopuły, komin tarasu; grupa awaryjna — „zawsze świecą”); wieża to wnętrze: świetlówki i czerwona lampa przy drzwiach z liną. Świetliki w stropie sali dachu (studnie do 31,5) — księżyc z nieba i percepcja „pod niebem”.
- **Eksponaty:** 0: figura woskowa na patrolu w rynnie wschodniej (`roof_gutter_walk`); 1: śpiące popiersie na kładce N. Wiatr (`roof_wind` w ambiencie strefy).

### Sale dachu

| Id | Prostokąt(y) | y | Nazwa | Uwagi |
|---|---|---|---|---|
| `roof_stairs` | 17, 45 → 37, 53 | 6 … 25,5 | `ROOM_SERVICE_STAIRS` | wieża, 3 biegi |
| `roof_plant` | 22,5, 36 → 38, 44,5 + 22,5, 30,5 → 30, 36 | 22,5 … 30 | `ROOM_ROOF_PLANT` | taras + mostek |
| `roof_loft` | 17, 36 → 22, 44,5 | 22,5 … 25,5 | `ROOM_ROOF_LOFT` | **sekret** (lina) |
| `roof_catwalks` | −30, −24,5 → 30, 30 + −24,5, −30 → 30, −24,5 | 22,5 … 30 | `ROOM_ROOF_CATWALK` | kładki, kopuła |
| `roof_shed` | −30, −30 → −25, −25 | 22,5 … 25,5 | `ROOM_ROOF_SHED` | **sekret** (deski) |

Otwory: `roof_stairs_plant` (x 34,5…36,5, z 44,5…45, SWING), `roof_plant_catwalks` (x 23…30, z 30…30,5, łuk 4 m), `roof_plant_loft` (x 22…22,5, z 39…41, GATE + ROPE), `roof_catwalks_shed` (x −25…−24,5, z −29…−27, DOUBLE_SWING + BOARDS).
Znaczniki: `secret_roof_1` (gołębnik), `secret_roof_2` (szopa), `note_roof_1` (dziennik dekarza w szopie), `chess_8` (gzyms kopuły od zachodu), `cctv_roof_1` (na rogu tarasu, patrzy w rynnę wsch.), `roof_view_1…2`, `sign_roof_enlightenment_1` (przy zasuwie), `sign_roof_entrance_1` (na tarasie przy wieży).

---

## Zadania

### Zadanie 1: plan (ten dokument)
- [x] Zapis i commit `W5b plan: basement and roof (P1)`.

### Zadanie 2: testy danych (najpierw czerwone)
**Plik:** `tests/unit/test_floor1_service.gd` (na `Floor1Layout.create()` w `before_each`):
- [x] `test_service_rooms_lie_in_their_zones_with_names` — prefiks strefy, `Floor1Plan.contains`, siatka 0,5 m, nazwa przetłumaczona, wszystkie `public = false`, sekrety oznaczone.
- [x] `test_rooms_keep_a_wall_between_them` — wycinane sale nie stykają się (≥ 0,5 m); pomost leży w kotłowni, ponad jej podłogą.
- [x] `test_key_rooms_have_their_sizes` — kotłownia 28 × 17 × 5, pomost y −3,2 (2,2 m nad, 2,4 m pod), warsztat jest przystanią w środku (≤ 12 m od osi x 0, pod obrysem Czytelni), tunel x −55…−30,5, wieża y 6 → 22,5, kładki y 22,5.
- [x] `test_every_service_junction_has_a_flush_room` — 8 przejść podziemi + 2 dachu: pokój pokrywa cały otwór, podłoga = przejście, sufit ≥ góra.
- [x] `test_internal_doorways_join_neighbouring_rooms` — każdy otwór modułu leży między swoimi pokojami (punkty tuż za murem).
- [x] `test_secret_rooms_hide_behind_one_zone_gate` — 3 + 2 sekrety, jeden otwór z bramą strefy, pięć różnych zamków, znacznik w środku.
- [x] `test_markers_are_there_and_inside_their_rooms` — lista i liczby (notatki 3 + 1, sekrety 3 + 2, szachy 1, CCTV 1 + 1, plan 1, tabliczki 7 + 7 + 2…), każdy nad swoją salą.
- [x] `test_the_fuse_and_the_switchboard` — bezpiecznik na pomoście (obszar `basement`), zasadzka przy podniesieniu, rozdzielnia z panelem przodem do sali i ≥ 2 wejściami.
- [x] `test_nothing_lies_only_behind_the_workshop` — graf sal bez drzwi warsztatu: od schodów kanciapy do każdej sali podziemi (bramy otwarte).
- [x] `test_spawn_sets_density_and_free_floor` — ≥ 2 zestawy, 0,4–0,8/100 m² (małe sale: 1), dach 1–2, wolna podłoga dla slotów, łupu i punktów patroli.
- [x] `test_patrols_and_ambushes` — punkty patrolu w sali, jeden piechur na patrol, zasadzki budzą sloty swojej sali.
- [x] `test_stairs_and_the_gantry` — wszystkie biegi ≤ 20,6°, schody pomostu kończą się na płycie pomostu, wieża trzy biegi.
- [x] `test_wing_doors_are_colour_coded` — przy każdych drzwiach skrzydła (≤ 4 m) czerwona lampa awaryjna i żarówka w kolorze skrzydła, tabliczka w kolorze skrzydła.
- [x] `test_lights` — każda sala ma lampę, warsztat ma `haven_lights`, są migające świetlówki, na dachu (poza wieżą) tylko księżyc i czerwone ostrzegawcze, żadna lampa podziemi nie sięga nad y −0,5, żadna lampa dachu pod y 22.
- [x] `--filter=test_floor1_service` → czerwone (szkielety).

### Zadanie 3: podziemia — sale, otwory, bramy-sekrety, przystań
**Pliki:** `zones/service_kit.gd`, `zones/basement.gd`, `locale/strings.csv`.
- [x] Sale, otwory, bramy z tabel; `haven_spots[&"workshop"]`; klucze nazw na końcu `strings.csv`.
- [x] `--filter=floor1` → testy brył/przejść zielone, `test_floor1_layout` zielony; commit.

### Zadanie 4: podziemia — wnętrza, światło, znaczniki, spotkania, łup
- [x] Kotłownia z pomostem, krzyż, warsztat, magazyny, tunel, pod holem; światło; znaczniki; sloty/patrole/zasadzki; łup.
- [x] `--filter=test_floor1_service` (część podziemi) zielone; commit.

### Zadanie 5: dach
- [x] Wieża, taras, mostek, kładki, kopuła, szkło, sekrety, światło, znaczniki, spotkania, łup; commit.

### Zadanie 6: test na zbudowanym piętrze
**Plik:** `tests/integration/test_floor1_service_walk.gd`:
- [x] `test_with_every_gate_open_the_workshop_reaches_every_wing` — z progu warsztatu (krzyż) siatka dochodzi za drzwi każdego z 6 skrzydeł i do tunelu Asyrii, do każdej sali podziemi i dachu (sekrety też; bez przystani), wieża łączy y 6 i 22,5, pomost i bezpiecznik osiągalne; z podestu holu na dach i do zasuwy Oświecenia.
- [x] `test_slots_loot_and_patrols_stand_on_the_navmesh_in_the_clear` — kapsuła 0,42 × 2 m wolna, punkt na siatce; odcinki patroli to proste spacery.
- [x] `test_after_the_boards_the_basement_opens_but_the_bolts_hold` — otwarte tylko deski (i lina dachu): od schodów kanciapy warsztat, bezpiecznik i rozdzielnia osiągalne; za drzwiami skrzydeł nic (zasuwy); sekrety zamknięte; dach osiągalny z holu, ale nie za zasuwą Oświecenia.
- [x] `--filter=test_floor1_service_walk` i `--filter=museum_floor` zielone; commit.

### Zadanie 7: całość
- [x] `--filter=test_floor1`, `test_museum_floor_level`, `test_progress_rules`; pełny `bash tools/run_tests.sh` raz; dopisać „Jak zbudowano / odstępstwa”; commit; raport do kontrolera (≤ 40 linii).

---

## Prośby do kontrolera (do potwierdzenia w raporcie)

1. **`LightSpec.FLICKER`** (`&"flicker_lights"`): grupa migających świetlówek podziemi; gra nią miga (W1), zaciemnienie gasi też ją. Do czasu stałej — `ServiceKit.FLICKER` o tej samej nazwie.
2. **P2 / W2:** świetliki dziedzińca (`court.skylights`) pod polami `roof_glass` i przy `roof_view_1…2` (widok w dół z kładek); szkło `roof_glass` już ma kolizję.
3. **W1:** `CctvCatalog.cameras_from` bierze pierwsze 6 znaczników `cctv_*` alfabetycznie — kamery skrzydeł (`cctv_basement_1`, `cctv_egypt_1`…) wypychają kamery centrum z monitorów kanciapy; lepiej najpierw kamery stref centrum.
4. **Notatki** `note_basement_1…3`, `note_roof_1` mają teksty (`NOTE_<ID>_TITLE/_BODY/_SIGN`, PL/EN, na końcu `strings.csv`); notatka elektryka mówi, gdzie jest drugi bezpiecznik (Galeria Nimrud) — podpowiedź drogi krytycznej.
5. Opcje na później: drzwi nocy (LOCKABLE) w magazynach podziemi; właz nad Egiptem (`roof_hatch_egypt_*`) wymaga bryły dachu nad Egiptem — nie budowany.

---

## Jak zbudowano (3.10) — odstępstwa od planu wyżej

| Co | Zmiana | Dlaczego |
|---|---|---|
| Szopa dekarzy | 5 × 5 m (x −30…−25), druga część sali kładek od x −24,5; balustrady rynny skręcają w rogu NW w punkcie (−22, −22) | przy szopie 6 m przejście rynną dookoła niej miało 1 m (agent 0,5 m: zero siatki); teraz 2,5 m w kształcie L |
| Lampy przy drzwiach skrzydeł | drzwi w narożniku (Oświecenie, z 28…30) dostają obie lampy po stronie korytarza | po drugiej stronie ościeża jest już mur |
| Korytarze poprzeczne i warsztatowy | dostały własne świetlówki, ławkę i łup (`_axes`) | test „każda sala ma lampę” |
| Notatki | teksty `NOTE_BASEMENT_1…3`, `NOTE_ROOF_1` (PL/EN) dopisane | bez tytułu w tłumaczeniach `NoteCatalog` nie kładzie notatki; notatka elektryka to podpowiedź drogi krytycznej (drugi bezpiecznik w Galerii Nimrud) |
| Figura `chess_8` | na gzymsie u stóp kopuły pod namiarem 292,5° (WNW), nie na osi zachodniej | na osi leży wylot kładki W |
| Odległości | z progu warsztatu do drzwi skrzydeł po siatce: Egipt 36, Azja 58, Ameryki 59, Grecja 69, Oświecenie 72, Asyria 82 m; dach: podest holu → zasuwa Oświecenia 126 m | pomiar `test_floor1_service_walk` (zamiast szacunku „≤ 55 m”); gracz przez warsztat (przystań) skraca drogę na południe o ~25 m |

Wyniki: 21 sal podziemi + 5 sal dachu (3 + 2 sekrety), 34 otwory modułów, 5 bram stref (CHAIN, CRACKED, HOOK, ROPE, BOARDS), 8 patroli, 5 zasadzek, ~24 eksponaty na noc najwyżej (gęstość 0,4–0,8/100 m²). `test_floor1_service` 14/14, `test_floor1_service_walk` 3/3, wszystkie testy `floor1` 142/142, pełny zestaw 1343/1343 (bez linii ERROR). Całe piętro (pomiar `test_museum_floor_level`): 93 sale, 118 otworów, 568 elementów, 246 slotów, 142 łupy, 38 bram; rzeźbienie ≈ 2,6 s, budowa ≈ 2,8 s, wypiekanie ≈ 0,24 s (3273 wielokąty).
