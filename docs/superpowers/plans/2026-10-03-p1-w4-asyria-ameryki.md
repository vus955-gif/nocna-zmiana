# P1 / W4 — Asyria oraz Ameryki i Oceania (skrzydła północno-zachodnie): plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`. Wykonuje Claude (W4) w drzewie `.claude/worktrees/p1-w4-north`, gałąź `p1-w4-north` (od `pietro-1`, z wmergowanym hubem W2). Wiążące: `docs/superpowers/plans/2026-10-02-p1-fundament.md` (strefy, przejścia, zasady budowniczych, W4), projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §3.4, §4, §5.2, §5.6, §7.2, §7.4, §9.1, §10.1. Wzorzec jakości i konwencji: W3 (`zones/egypt.gd`, `zones/greece.gd`, `docs/superpowers/plans/2026-10-03-p1-w3-egipt-grecja.md`).

**Cel:** prawdziwy układ greybox Asyrii (pałac wokół dziedzińca: Brama Chorsabadu, Galeria Nimrud z drugim bezpiecznikiem, zatopiona Sala Lwów z galerią, Wrota z Balawat, arena Lamassu pod otwartym niebem, biblioteka i schody towarowe do podziemi) oraz Ameryk i Oceanii (Sala Ameryki Północnej od żaluzji, Sala Totemów, ciemna Sala Moai z kryjówką za głową, Galeria Pacyfiku z harpunnikiem i czółnem nad zapadniętą podłogą, Świątynia Węża na schodkowych tarasach dostępna tylko po moście z czółna) — z przejściami, sekretami, znacznikami, spotkaniami, łupem i światłem według przepisów skrzydeł; grywalne i sprawdzone testami.

**Architektura:** dwa moduły stref (`zones/assyria.gd`, `zones/americas.gd`) wypełniają `LevelLayout` czystymi danymi przez `Floor1Greybox`, pomocniki W3 (`west_kit.gd`: bramy-sekrety, legowiska, reflektory, kinkiety, lampy awaryjne, kamery) i W2 (`hub_kit.gd`: lampy z oprawą, reflektory w dowolnej grupie, `MOON_GROUP`, sloty i chodzący eksponat) oraz mały własny `northwest_kit.gd` (balustrady, płyty galerii, podświetlenie od dołu, ogień w misie). `Floor1Layout` dokłada otwory przejść. Testy: jednostkowy na danych (`test_floor1_northwest.gd`) i integracyjny na zbudowanym piętrze (`test_floor1_northwest_walk.gd`).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh --filter=…` (bez okna, bez dźwięku, nigdy dwa Godoty naraz — maszyna się grzeje).

---

## Pliki

| Plik | Co robi |
|---|---|
| `src/level/floor1/zones/assyria.gd` | moduł Asyrii (zastępuje szkielet): sale, otwory, bramy-sekrety, elementy, światło, znaczniki, spawny, patrole, zasadzki, łup |
| `src/level/floor1/zones/americas.gd` | moduł Ameryk i Oceanii (jw.) + brama wewnętrzna `hook_canoe` |
| `src/level/floor1/zones/northwest_kit.gd` | pomocniki obu skrzydeł (nowy plik, tylko dane) |
| `tests/unit/test_floor1_northwest.gd` | testy danych obu skrzydeł |
| `tests/integration/test_floor1_northwest_walk.gd` | testy na zbudowanym piętrze (nawigacja, kapsuła, promienie, brama czółna) |
| `locale/strings.csv` | nowe klucze `ROOM_ASSYRIA_*`, `ROOM_AMERICAS_*` — **tylko dopisane na końcu** |
| ten plik | plan + na końcu „Jak zbudowano” |

Nie ruszam: `floor1_plan.gd` (prośby w raporcie), modułów i pomocników innych stref (`west_kit.gd`, `hub_kit.gd` tylko czytam przez `preload`), testów części A, W2 i W3 (muszą zostać zielone).

## Ograniczenia, które kształtują projekt

1. **Przejścia stałe** (od strony Asyrii / Ameryk): Chorsabad z = −39, x −54…−48 (h 8, pieczęć Słońca); Balawat x = −47…−46, z −66…−62 (h 5, pieczęć Skrzydła); Bassae z = −3, x −90…−87 (h 3, zasuwa od Asyrii); podziemia Asyrii x = −56, z −36,5…−34,5, **y −6** (zasuwa od Asyrii); żaluzja z = −39, x −20…−14 (h 5, zasilanie); podziemia Ameryk z = −39, x −28…−26, **y −6** (zasuwa od Ameryk). Pokój mojej strony przylega do otworu na całej szerokości.
2. **Skrzydło drzwi SWING** otwiera się do pokoju B i leży wzdłuż ościeżnicy, ok. 1 m w głąb pokoju B. Dla przejść do podziemi pokój B to mój: w Asyrii skrzydło leży przy z ≈ −34,5 na dolnym podeście schodów towarowych (11,5 m długości — miejsca dość), w Amerykach przy x ≈ −28 pod górnym podestem wieży (bieg pierwszy jest w drugim pasie).
3. **Sekrety za bramami strefy** (nie za fałszywymi panelami — testy części A traktują `SECRET`/`PANEL` jak zamknięte): po trzy na skrzydło, rodzaje CHAIN / BOARDS / CRACKED / ROPE / HOOK, wymagania `heavy` / `explosive` / `precise` / `harpoon`.
4. **Świątynia tylko przez most:** brama `hook_canoe` (HOOK, `harpoon`) na otworze `americas_canoe_bridge` między pokojem obszaru `americas` (zapadnięta podłoga) a `americas_temple`. Zamek `HookLock` z `p1-weapons` w trybie SWING to czółno stojące na rufie po **dalszej** stronie szczeliny, które pada w stronę strażnika i zostaje mostem. Dlatego szczelina leży **przed** otworem bramy (po stronie galerii), a otwór — po drugiej stronie dołu. W greyboksie (zanim W1 postawi zamek) most to płyta `canoe_bridge` nad dołem: z zamkniętą bramą (kraty) da się dojść do kraty, nie dalej. **W1 przy podpinaniu `HookLock` usuwa płytę `canoe_bridge`** (jego zamek ma własny pokład; długość szczeliny: 5,5 m + 2 × 0,5 m muru).
5. **Pokoje się nie stykają** (≥ 0,5 m muru albo płyty); galeria Sali Lwów to pokój `carved = false` (idiom balkonu z lobby i antresol W3).
6. **Schody 0,15 / 0,40** (20,6°): 3 m w pionie = 8 m biegu, 6 m = 16 m.
7. **Księżyc** (dziedziniec pałacu, snop nad ołtarzem świątyni) w grupie `hub_kit.MOON_GROUP` (dziś `emergency_lights`, zawsze zasilane) — W1 dodaje grupę `moon`; wtedy wystarczy zmienić stałą W2.
8. **Nazwy sal a dźwięk:** podstrefy dźwięku tylko z istniejących słów (`garden`, `boiler`, `clock`, `tomb`); `stair` daje pogłos korytarza (schody towarowe, wieża). Id z prefiksem strefy.

---

## ASYRIA — Pałace Niniwy i Nimrud

Strefa: bryła B x −112…−47, z −86…−39; bryła A x −112…−56, z −39…−3; y −6,5…32.
Pomysł: pałac wokół **dziedzińca** (arena Lamassu), z dwiema pętlami na parterze (brama → Nimrud → dziedziniec → Balawat → brama; brama → biblioteka → galeria Sali Lwów → Nimrud → brama), **pionem** w Sali Lwów (galeria y 0 nad dołem łowieckim y −3, z dołu schody towarowe do podziemi y −6) i skrótem przez zasuwę do Grecji.

### Plan parteru (widok z góry, północ = góra, x rośnie w prawo)

```
x: -112  -104   -100 -96.5 -96 -94          -82   -79 -78.5     -63.5 -63            -47
z-86  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
z-80                    ┌─────────────────────────────────────┐
                        │ DZIEDZINIEC PAŁACU 30,5 × 27, h 14   │ ┌──────────────────┐ z-79
                        │  ┃kol.        ◆LAMASSU      ┃kol.    │ │ WROTA Z BALAWAT  │
                        │   ▣ geniusz                ▣ geniusz │ │  ▮ Czarny Obelisk │ (♟4 za nim)
                        │      ░░░░ otwarty strop ░░░░         │═│     (oś x -51)    │═► AMERYKI
                        │   ▣ geniusz                ▣ geniusz │ │  ▭ gabloty pasów  │  z-66..-62
z-53                    └───────────[x -82..-76]──────────────┘ └──[łuk x-54..-48]─┘ z-57.5
z-52.5  ┌──────────────────────────────────────────────────────┐ ┌──────────────────┐ z-57
        │ GALERIA PAŁACU NIMRUD 36,5 × 13, h 8                  │ │ BRAMA CHORSABADU │
        │ ⚡ bezpiecznik  ▭relief     ▭relief     ▭relief        │═│  16 × 18, h 10   │
        │ (rusztowanie)   (płyty-osłony na osi z -46)           │ │ ♞lamassu ♞lamassu│
z-39.5  └──────────[x -90..-86]───────────────────────────────┘ └─[-62..-59]─[BRAMA]┘ z-39
z-38.5         ┌───────────────────────┐ ┌──────────────────────────────┐  ▲ EGIPT
               │ SALA LWÓW Z NINIWY    │ │ BIBLIOTEKA ASSURBANIPALA     │    (Sala Kolosa)
  ┌─────────┐  │ ═galeria y 0 (pierścień 3 m)═ │ 22 × 16,5, h 6 (y 0)   │
  │ KLATKA  │  │ ║┌─────────────────┐║ │═│ ▭ ▭ ▭ gabloty tabliczek     │
  │ LWÓW    │lina║│ DÓŁ ŁOWIECKI y -3│║ │ │ ▭ ▭ ▭    ▣ Tablica Potopu   │
  │ y -3..0 │  │ ║│ rydwan, klatki,  │║ │ │ (pod nią: schody towarowe)  │
  └─────────┘  │ ║│ płyty reliefów   │║ │ └──────────[spęk x-70..-68]───┘ z-22
               │ ═══════════════════ │   ┌──────────────┐ z-21.5
z-3            └──[zasuwa x -90..-87]┘   │ MAGAZYN      │
                       ▼ GRECJA          │ TABLICZEK    │ z-14
                     (Sala z Bassae)     └──────────────┘
```

### Sala Lwów w przekroju (z = −20, widok z południa)

```
 y 9  ┌─────────────────────────────────────┐
      │                                     │
 y 0 ═╪═══ galeria (płyta 0,4) ═╗     ╔═ galeria ══╪═ drzwi do biblioteki (y 0)
      │  │słupek            bieg B│     │słupek   │
 y-3  ┴──┴──────────────────────┴─dół─┴─────────┴═ łuk do schodów towarowych (y -3, pod galerią)
     x-96 -93                              -82   -79
```
Biegi: **A** x −85…−82, z −35,5…−27,5 (z dołu na północ do galerii N); **B** x −93…−90, z −14…−6 (z dołu na południe do galerii S). Pod płytami galerii 2,6 m przejścia na poziomie dołu (lwy czają się pod galerią).

### Poziom podziemi (y −6 / −3, pod biblioteką)

```
x: -79 -78.5   -75.5          -67.5                       -56 -55
       ┌───────┬──────────────┬────────────────────────────┐
 DÓŁ ═ │podest │ bieg ↓ 8 m   │ podest dolny 11,5 m (y -6)  │═ PODZIEMIA (tunel pod Salą Kolosa)
 LWÓW  │ y -3  │ (y -3 → -6)  │   skrzydło drzwi ↘ z≈-34,5  │  zasuwa od Asyrii
       └───────┴──────────────┴─────[krata windy]───────────┘ z-34
                                    ┌─────────┐ z-33.5
                                    │ KABINA  │ (sekret: łańcuch)
                                    │ WINDY   │ z-29.5
                                    └─────────┘ x -62..-57
```

### Sale Asyrii

| Id | Prostokąt(y) (x0, z0 → x1, z1) | y podłogi … sufitu | Nazwa (klucz) | Publ. | Uwagi |
|---|---|---|---|---|---|
| `assyria_gate` | −63, −57 → −47, −39 | 0 … 10 | `ROOM_ASSYRIA_GATE` | tak | wejście z Egiptu (pieczęć Słońca); para lamassu |
| `assyria_balawat` | −63, −79 → −47, −57,5 | 0 … 8 | `ROOM_ASSYRIA_BALAWAT` | tak | pieczęć Skrzydła do Ameryk; Czarny Obelisk na osi bramy |
| `assyria_courtyard` | −94, −80 → −63,5, −53 | 0 … 14 | `ROOM_ASSYRIA_COURTYARD` | tak | arena Lamassu; świetlik 20,5 × 19 (otwarty strop) |
| `assyria_nimrud` | −100, −52,5 → −63,5, −39,5 | 0 … 8 | `ROOM_ASSYRIA_NIMRUD` | tak | `fuse_assyria`, zasadzka przy podniesieniu |
| `assyria_lions` | −96, −38,5 → −79, −3 | −3 … 9 | `ROOM_ASSYRIA_LIONS` | tak | dół łowiecki; zasuwa do Grecji na galerii |
| `assyria_lions_gallery` | N −96, −38,5 → −79, −35,5; S −96, −6 → −79, −3; W −96, −35,5 → −93, −6; E −82, −35,5 → −79, −6 | 0 … 9 | `ROOM_ASSYRIA_LIONS_GALLERY` | tak | `carved = false`, płyty `balcony` na słupkach |
| `assyria_library` | −78,5, −38,5 → −56,5, −22 | 0 … 6 | `ROOM_ASSYRIA_LIBRARY` | tak | nad schodami towarowymi |
| `assyria_freight_stairs` | −78,5, −38,5 → −56, −34 | −6 … −0,5 | `ROOM_ASSYRIA_FREIGHT` | nie | `Grey.stairwell` y −6 → −3 (bieg na zachód), sufit obniżony do −0,5 |
| `assyria_tablets` | −74, −21,5 → −64, −14 | 0 … 3 | `ROOM_ASSYRIA_TABLETS` | nie, sekret | spękany mur (wybuch) |
| `assyria_lion_cage` | −104, −24 → −96,5, −16 | −3 … 0 | `ROOM_ASSYRIA_LION_CAGE` | nie, sekret | lina (precyzja) |
| `assyria_freight_lift` | −62, −33,5 → −57, −29,5 | −6 … −3 | `ROOM_ASSYRIA_LIFT` | nie, sekret | łańcuch (ciężkie) |

### Otwory Asyrii (moduł; przejścia stref dodaje `Floor1Layout`)

| Id | Prostokąt | y | Pokoje | Styl / łącze |
|---|---|---|---|---|
| `assyria_gate_balawat` | −54, −57,5 → −48, −57 | 0…7 | brama ↔ Balawat | łuk (oś Chorsabad → obelisk) |
| `assyria_gate_nimrud` | −63,5, −52 → −63, −44 | 0…6 | brama ↔ Nimrud | łuk |
| `assyria_gate_library` | −62, −39 → −59, −38,5 | 0…3,5 | brama ↔ biblioteka | łuk |
| `assyria_nimrud_courtyard` | −82, −53 → −76, −52,5 | 0…7 | Nimrud ↔ dziedziniec | łuk (drzwi areny 1) |
| `assyria_courtyard_balawat` | −63,5, −72 → −63, −66 | 0…7 | dziedziniec ↔ Balawat | łuk (drzwi areny 2) |
| `assyria_nimrud_lions` | −90, −39,5 → −86, −38,5 | 0…4 | Nimrud ↔ galeria lwów | łuk |
| `assyria_library_lions` | −79, −30 → −78,5, −27 | 0…3,5 | biblioteka ↔ galeria lwów | łuk |
| `assyria_lions_freight` | −79, −38 → −78,5, −34,5 | −3…−0,6 | dół lwów ↔ schody towarowe | łuk („brama lwów” pod galerią) |
| `assyria_library_tablets` | −70, −22 → −68, −21,5 | 0…2,4 | biblioteka ↔ magazyn tabliczek | PANEL + `assyria_cracked_tablets` (CRACKED, `explosive`) |
| `assyria_lions_cage` | −96,5, −21 → −96, −19 | −3…−0,6 | dół lwów ↔ klatka | GATE + `assyria_rope_cage` (ROPE, `precise`) |
| `assyria_freight_lift_door` | −61, −34 → −59, −33,5 | −6…−3,4 | schody towarowe ↔ kabina windy | GATE (krata windy) + `assyria_chain_lift` (CHAIN, `heavy`) |

### Znaczniki Asyrii

| Znacznik | Gdzie | Pokój |
|---|---|---|
| `fuse_assyria` | wózek konserwatorów przy rusztowaniu (−96,5, 0,9, −44) | Nimrud |
| `guardian_lamassu` | (−78,75, 0, −74), przód na +z (ku drzwiom z Nimrud) | dziedziniec |
| `arena_lamassu_start` | (−79, 0, −55,5) | dziedziniec |
| `arena_lamassu_door_1` / `_2` | środek drzwi z Nimrud / z Balawat | dziedziniec |
| `arena_lamassu_supply_1…3` | rogi SW, SE, NW | dziedziniec |
| `lamassu_relief_1…6` | płaskorzeźby na ścianach areny (W ×2, E ×2, N ×2), przód do środka — stąd w fazie 2 schodzą wojownicy z reliefów | dziedziniec |
| `note_assyria_1…4` | ława w Bramie, biurko w bibliotece, kabina windy, klatka lwów | |
| `secret_assyria_1…3` | magazyn tabliczek, klatka lwów, kabina windy | sekrety |
| `chess_4` | cokolik za Czarnym Obeliskiem | Balawat |
| `cctv_assyria_1` / `_2` | róg NE Bramy (patrzy na bramę) / wschodni koniec Nimrud (patrzy na zachód) | |

### Spotkania Asyrii (zastępca + docelowy)

`RELIEF_WARRIOR` → `[&"wax", &"relief_warrior"]`, `RELIEF_LION` → `[&"wolf", &"relief_lion"]`.

| Sala | Zawsze (`ALWAYS_SET`) | Zestawy | Patrol / zasadzka |
|---|---|---|---|
| Brama | 2 wojowników przy ścianach | 0: wojownik na patrolu; 1: lew + wojownik | `assyria_gate_walk`; zasadzka `assyria_gate_reliefs` (obszar przed lamassu) |
| Nimrud | 2 wojowników przy rusztowaniu | 0: wojownik na patrolu + wojownik; 1: 2 lwy + wojownik; 2: 2 wojowników | `assyria_nimrud_aisle`; zasadzka `assyria_fuse` przy podniesieniu bezpiecznika |
| Balawat | — | 0: 2 wojowników + lew; 1: wojownik na patrolu + 2 lwy; 2: 3 wojowników | `assyria_balawat_round` |
| dół lwów | 2 lwy pod galerią | 0: 3 lwy + wojownik; 1: 2 lwy + 2 wojowników; 2: lew na patrolu + 2 lwy | `assyria_pit_run`; zasadzka `assyria_lion_hunt` (środek dołu) |
| galeria lwów | — | 0: 2 wojowników; 1: wojownik na patrolu (pierścień) + wojownik | `assyria_gallery_round` |
| biblioteka | — | 0: 2 wojowników + lew; 1: 3 wojowników; 2: wojownik na patrolu + lew | `assyria_library_aisle` |
| schody towarowe | — | 0: lew; 1: wojownik | — |
| sekrety | po 1 (legowisko) | — | zasadzki w środku |
| dziedziniec | — | — | (arena: strażnik i jego wezwania z reliefów) |

### Światło Asyrii (§10.1: nisko, ostro, czerwonawe pochodnie)

Pochodnie (kinkiety, kolor ognia z czerwienią) **nisko** na ścianach (y ≈ 2,2–2,6 nad podłogą), zimne ostre reflektory **od podłogi** muskające reliefy i lamassu (długie cienie), księżyc tylko w dziedzińcu (świetlik + zimny snop w `MOON_GROUP`), ciepła lampa robocza przy bezpieczniku (z cieniem), czerwone lampy awaryjne przy drzwiach, świetlówki na schodach towarowych.

---

## AMERYKI I OCEANIA — Meksyk, Rapa Nui, Pacyfik

Strefa: x −46…−4, z −86…−39; y −6,5…32.
Pomysł: dwa wejścia (żaluzja z korytarza północnego do Sali Ameryki Północnej, wrota z Balawat do ciemnej Sali Moai), w środku Sala Totemów łącząca obie połowy, na północy Galeria Pacyfiku: harpunnik w ekspozycji wielorybniczej i — na końcu osi galerii — **czółno wojenne wiszące nad zapadniętą podłogą**, za nim przez kratę żar Świątyni Węża. Spadnięcie do dołu nie zabija: z dna magazyn pod Salą Totemów prowadzi do wieży schodów i drzwi do podziemi (pętla dolna).

### Plan parteru

```
x: -46             -35 -34.5  -31 -30.5    -25 -24.5                          -4
z-86  ┌─────────────────────────────┐  ┌───────┐ ┌──────────────────────────────────┐
z-85.5│ GALERIA PACYFIKU 15 × 12,5   │  │ZAPAD- │ │ ŚWIĄTYNIA WĘŻA 20,5 × 27,5, h 12  │
      │ ⚓ łódź wielorybnicza         │  │ NIĘTA │ │  (obszar americas_temple)         │
      │   ✚ HARPUNNIK (-40.5, -79)   │══│ PODŁ. │#│         ▲ N1, N2                  │
      │        ~~ widok na czółno ~~ │  │ ═══💧═══ │    ┌──────────────┐  T1 y 1,5     │
z-73  └──[x-42..-38]─────[-34..-31.5]┘  │ dno y-6│ │    │ ┌──────────┐ │  T2 y 3,0     │
z-72.5┌────────────┐ ┌───────────────┐  └───────┘ │    │ │ ◆WĄŻ  ⌂  │ │  ⌂ ołtarz     │
      │ SALA MOAI   │ │ SALA TOTEMÓW   │ z-83..-75 │    │ └──────────┘ │               │
  ◄═══│ 11 × 20,    │═│ 9,5 × 14,5     │           │    └──────────────┘               │
ASYRIA│ h 9, ciemno │ │ + 12 × 5,5,    │           │         ▼ S2, S1                  │
z-62..│             │ │ h 12           │           └──────────────────────────────────┘ z-58.5
 -66  │    ◉ MOAI   │ │  ┃  ┃  ┃  ┃    ├─────┐ z-58 ┌─────────────────────────────────┐ z-58
      │  (-40.5,-56.6)│               │═════│═════│ SALA AMERYKI PÓŁNOCNEJ 18 × 19,  │
z-52.5└───[hak]─────┘ └──[spęk]───────┘     │      │ h 7: tipi, bizon, kajak, maski   │
z-52  ┌──────────┐  ┌───────────┐ ┌───────┐ │      │                                  │
      │ KRYJÓWKA │  │ PRACOWNIA │ │ WIEŻA │═╝      │                                  │
      │ (y -3)   │  │RZEŹBIARZY │ │ y-6…0 │═══════│ (drzwi z górnego podestu, y 0)   │
z-39.5└──────────┘  └───────────┘ └───────┘       └────────[żaluzja x -20..-14]──────┘ z-39
      x-46…-38.5    x-37.5…-29.5  x-29…-22.5               ▲ korytarz północny
                                    ▼ podziemia (x -28..-26, y -6)
```

### Poziom podziemi (y −6 … −3)

```
x: -34   -30 -29.5   -25.5                         (dno dołu: x -30.5..-25, z -83..-75, y -6)
z-75                ┌─────┐  ◄─ łuk z dna zapadniętej podłogi
z-74.5              │ M   │
z-72  ┌──────┐      │ A   │
      │MAGAZ.│═desk.│ G.  │   MAGAZYN POD SALĄ TOTEMÓW 4 × 22 (pod podłogą totemów)
      │ZBIORÓW      │     │
z-62  └──────┘      │     │
z-52.5              └──┬──┘
z-52                ┌──┴──────┐ WIEŻA: bieg 1 (pas wsch.) y -6 → -3 na północ,
                    │  WIEŻA  │ bieg 2 (pas zach.) y -3 → 0 na południe; górny podest
z-39                └─[zasuwa]┘ nad drzwiami do podziemi (5,6 m prześwitu pod płytą)
```

### Sale Ameryk

| Id | Prostokąt(y) | y | Nazwa | Publ. | Uwagi |
|---|---|---|---|---|---|
| `americas_north` | −22, −58 → −4, −39 | 0…7 | `ROOM_AMERICAS_NORTH` | tak | wejście od żaluzji |
| `americas_service_stairs` | −29, −52 → −22,5, −39 | −6…3 | `ROOM_SERVICE_STAIRS` | nie | `Grey.tower(…, 2 biegi, pas 1, first_up = false)`; górny podest y 0 na południu |
| `americas_totems` | −34,5, −72,5 → −25, −58 + −34,5, −58 → −22,5, −52,5 | 0…12 | `ROOM_AMERICAS_TOTEMS` | tak | łącznik obu połówek |
| `americas_moai` | −46, −72,5 → −35, −52,5 | 0…9 | `ROOM_AMERICAS_MOAI` | tak | wejście z Asyrii (pieczęć Skrzydła); głowa w ciemności |
| `americas_pacific` | −46, −85,5 → −31, −73 | 0…10 | `ROOM_AMERICAS_PACIFIC` | tak | `weapon_harpoon`, zasadzka przy podniesieniu |
| `americas_pit` | −30,5, −83 → −25, −75 | −6…10 | `ROOM_AMERICAS_PIT` | nie | zapadnięta podłoga; płyta-most `canoe_bridge` na y 0; czółno wisi nad dołem |
| `americas_temple` | −24,5, −86 → −4, −58,5 | 0…12 | `ROOM_AMERICAS_TEMPLE` | tak | obszar `americas_temple`; tarasy T1 (y 1,5) i T2 (y 3); świetlik nad ołtarzem |
| `americas_undercroft` | −29,5, −74,5 → −25,5, −52,5 | −6…−3 | `ROOM_AMERICAS_UNDERCROFT` | nie | pod Salą Totemów: dno dołu ↔ wieża |
| `americas_moai_hideout` | −41,5, −52 → −38,5, −39,5 (klatka) + −46, −49,5 → −41,5, −39,5 (komora) | −3…3 | `ROOM_AMERICAS_HIDEOUT` | nie, sekret | hak (harpunnik) za głową moai; schody w dół do kryjówki |
| `americas_workshop` | −37,5, −52 → −29,5, −44 | 0…3,5 | `ROOM_AMERICAS_WORKSHOP` | nie, sekret | spękany mur (wybuch) w Sali Totemów |
| `americas_store` | −34, −72 → −30, −62 | −6…−3 | `ROOM_AMERICAS_STORE` | nie, sekret | deski (ciężkie) z magazynu pod totemami |

### Otwory Ameryk

| Id | Prostokąt | y | Pokoje | Styl / łącze |
|---|---|---|---|---|
| `americas_stairs_north` | −22,5, −41,25 → −22, −39,75 | 0…2,6 | wieża (A) ↔ Ameryka Płn. (B) | SWING (skrzydło do sali) |
| `americas_undercroft_stairs` | −28,5, −52,5 → −26,5, −52 | −6…−3,4 | magazyn pod totemami ↔ wieża | łuk (pod płytą spocznika) |
| `americas_totems_north` | −22,5, −57,5 → −22, −53 | 0…6 | totemy ↔ Ameryka Płn. | łuk |
| `americas_moai_totems` | −35, −66 → −34,5, −61 | 0…6 | moai ↔ totemy | łuk |
| `americas_moai_pacific` | −42, −73 → −38, −72,5 | 0…6 | moai ↔ Pacyfik | łuk |
| `americas_pacific_totems` | −34, −73 → −31,5, −72,5 | 0…4 | Pacyfik ↔ totemy | łuk |
| `americas_pacific_pit` | −31, −83 → −30,5, −75 | 0…8 | Pacyfik ↔ zapadnięta podłoga | łuk (krawędź zapadliska) |
| `americas_canoe_bridge` | −25, −81 → −24,5, −77 | 0…5 | zapadnięta podłoga ↔ świątynia | GATE + **`hook_canoe`** (HOOK, `harpoon`) — brama planu |
| `americas_pit_undercroft` | −28,5, −75 → −26,5, −74,5 | −6…−3,4 | dno dołu ↔ magazyn pod totemami | łuk |
| `americas_moai_hideout_door` | −41,5, −52,5 → −39,5, −52 | 0…2,4 | moai ↔ kryjówka | GATE + `americas_hook_moai` (HOOK, `harpoon`) |
| `americas_totems_workshop` | −33,5, −52,5 → −31,5, −52 | 0…2,4 | totemy ↔ pracownia | PANEL + `americas_cracked_workshop` (CRACKED, `explosive`) |
| `americas_undercroft_store` | −30, −68 → −29,5, −66 | −6…−3,6 | magazyn pod totemami ↔ magazyn zbiorów | DOUBLE_SWING + `americas_boards_store` (BOARDS, `heavy`) |

### Świątynia Węża — tarasy (widok z góry)

```
x: -24.5    -20      -15.75 -12.75     -8.5      -4
z-86  ┌──────────────────────────────────────────┐
      │ ◇☼        N1 (0→1,5)              ☼◇     │ ☼ misa ognia, ◇ ołtarzyk-osłona
z-83  │          ┌──────┐                         │
═#════│  ┌───────┤ N2   ├──────────┐              │ ◄ most z czółna (z -81..-77)
z-79  │  │ T1    └──────┘          │              │
z-75  │  │   ┌──────────────────┐  │              │
      │◇ │   │ T2 y 3   ◆   ⌂   │  │ ◇            │ ◆ guardian_serpent, ⌂ ołtarz (♟5 obok)
z-69.5│  │   └──────────────────┘  │              │ snop księżyca nad T2
z-65.5│  │       ┌──────┐ S2       │              │
      │  └───────┤ S1   ├──────────┘              │
z-61.5│ ☼        └──────┘                    ☼    │
z-58.5└──────────────────────────────────────────┘
```
T1 x −20…−8,5, z −79…−65,5 (h 1,5); T2 x −18…−10,5, z −75…−69,5 (h 3); biegi 3 m szerokie (x −15,75…−12,75), każdy 1,5 m na 4 m. Arena ma przejścia 4,5 m wokół tarasów (wąż „otacza arenę ciałem” w fazie 3: znaczniki `serpent_path_1…8` — pętla po przejściach i po tarasie T1).

### Znaczniki Ameryk

| Znacznik | Gdzie | Pokój |
|---|---|---|
| `weapon_harpoon` | na stojaku w ekspozycji wielorybniczej (−40,5, 1,0, −79), przód na +x (ku czółnu) | Pacyfik |
| `americas_canoe` | czółno nad dołem (−27,75, 6,5, −79), −Z ku galerii | zapadnięta podłoga |
| `guardian_serpent` | T2 (−15,5, 3, −72,25), przód na −x (ku mostowi) | świątynia |
| `arena_serpent_start`, `arena_serpent_door_1`, `arena_serpent_supply_1…3` | za kratą mostu; w kratach; rogi SW, NE, SE | świątynia |
| `serpent_path_1…8` | pętla: rogi przejść (y 0) i rogi T1 (y 1,5) | świątynia |
| `note_americas_1…4` | stojak harpunnika, ława w Sali Ameryki Płn., kryjówka, magazyn zbiorów | |
| `secret_americas_1…3` | kryjówka, pracownia, magazyn zbiorów | sekrety |
| `chess_5` | T2 obok ołtarza | świątynia |
| `cctv_americas_1` / `_2` | róg NE Sali Ameryki Płn. (patrzy na żaluzję) / róg SW Pacyfiku (patrzy na harpunnik) | |

### Spotkania Ameryk

`TOTEM` → `[&"bust", &"totem"]`, `JAGUAR` → `[&"wolf", &"jaguar"]`.

| Sala | Zawsze | Zestawy | Patrol / zasadzka |
|---|---|---|---|
| Ameryka Płn. | — | 0: 2 jaguary + totem; 1: jaguar na patrolu + 2 totemy; 2: 3 jaguary | `americas_north_round` |
| totemy | 1 totem (żywy słup w środku) | 0: + jaguar; 1: + totem + jaguar | — |
| moai | 1 jaguar przyczajony przy cokole | 0: + jaguar; 1: + totem + jaguar | zasadzka `americas_moai` (przed głową) |
| Pacyfik | jaguar + totem | 0: + totem; 1: + jaguar | zasadzka `americas_whalers` przy podniesieniu harpunnika |
| zapadnięta podłoga (dno) | — | 0: jaguar; 1: totem | — |
| magazyn pod totemami | — | 0: jaguar; 1: jaguar na patrolu | `americas_undercroft_walk` |
| sekrety | po 1 | — | zasadzki w środku |
| świątynia, wieża | — | — | (arena: strażnik) |

### Światło Ameryk (§10.1: teatralne, od dołu, ogień)

Misy ognia (pomarańczowe lampy nisko, y ≈ 1,2) przy totemach, tarasach i tipi; **reflektory od podłogi** w górę na moai (jedyne światło sali, z cieniem), na słupy totemów, na fasady tarasów; żar na dnie zapadliska podświetla czółno od spodu (z cieniem); latarnia nad harpunnikiem (ciepła, z cieniem); jeden zimny snop księżyca nad ołtarzem świątyni (kontrast); czerwone lampy awaryjne; świetlówki w wieży i magazynie.

---

## Zadania

### Zadanie 1: plan (ten dokument)
- [ ] Zapis i commit `Plan P1/W4: Assyria and the Americas greybox (rooms, secrets behind zone gates, the canoe bridge, encounters, lights, tests)`.

### Zadanie 2: test danych (najpierw czerwony)

**Pliki:** utwórz `tests/unit/test_floor1_northwest.gd`.

- [ ] Testy (każdy na `Floor1Layout.create()` w `before_each`):
  - `test_key_rooms_have_their_sizes` — brama ≥ 16 × 18 i h ≥ 8 (lamassu 4,5 m mieszczą się z zapasem), dziedziniec ≥ 28 × 26, h ≥ 12, świetlik ≥ 40% podłogi; Nimrud co najmniej 2,5 × dłuższy niż szerszy; Sala Lwów: dół 3 m pod galerią (`carved = false`, y 0); schody towarowe sięgają y −6 i dołu (y −3); świątynia ≥ 20 × 26, h 12, obszar `americas_temple`; zapadnięta podłoga ≥ 5 m pod podłogą Pacyfiku; wieża sięga y −6 i y 0;
  - `test_rooms_keep_apart_inside_their_zone`, `test_junction_rooms_cover_their_doorways`, `test_internal_doorways_join_their_rooms` (jak W3, dla `assyria`/`americas`);
  - `test_secret_rooms_sit_behind_zone_gates` — 6 sal sekretnych, każde wejście za bramą z prefiksem strefy i dozwolonym wymaganiem;
  - `test_markers_lie_in_their_rooms` — wszystkie wymagane znaczniki są, każdy znacznik moich sal leży w swojej sali;
  - `test_three_secrets_and_three_or_four_notes_per_wing`, `test_one_chess_piece_per_wing` (`chess_4` Asyria, `chess_5` Ameryki);
  - `test_every_room_with_exhibits_has_two_sets_and_a_sane_density` — jak W3 (gęstość 0,6–1,2/100 m², małe sale 1–2), rodzaj zastępczy pierwszy;
  - `test_patrols_and_ambushes` — punkty patroli w swoich salach, zasadzka bezpiecznika na `fuse_assyria`, harpunnika na `weapon_harpoon` (oba co noc), > 6 zasadzek;
  - `test_stairs_never_steeper_than_the_plan` — ≥ 10 biegów, każdy ≤ 20,6°;
  - `test_the_temple_lies_only_beyond_the_canoe` — `hook_canoe` na `americas_canoe_bridge` (HOOK, `harpoon`) między `americas_pit` (obszar `americas`) a świątynią; graf sal: bez bram świątynia nieosiągalna z żadnej sali Ameryk, z otwartą `hook_canoe` osiągalna; płyta-most leży na y 0 nad dołem od krawędzi do kraty;
  - `test_the_harpoon_fuse_and_lamassu_need_no_inner_gate` — graf bez bram: z sali przy Balawat i z sali przy żaluzji do Pacyfiku (harpunnik), z sali przy Chorsabadzie do Nimrud (bezpiecznik) i dziedzińca (Lamassu);
  - `test_the_khorsabad_axis_and_the_canoe_are_in_plain_view` — odcinek z Egiptu (2,5 m przed bramą, wysokość oczu) do Czarnego Obelisku i od harpunnika do czółna: każdy punkt w sali albo otworze, żadnego kolidującego elementu po drodze;
  - `test_lights_follow_the_wing_recipes` — każda publiczna sala ma lampę `main_lights`; w Asyrii ≥ 70% lamp zwykłych wisi ≤ 3,5 m nad podłogą sali i ma ciepły, czerwonawy kolor; dziedziniec ma księżyc w `MOON_GROUP` i największy świetlik skrzydła; w Amerykach reflektory „od dołu” (kierunek w górę) na moai, totemach i tarasach, żar pod czółnem (poniżej y 0); cieni < 14.
- [ ] `bash tools/run_tests.sh --filter=floor1_northwest` → FAIL (szkielet nie spełnia).

### Zadanie 3: Asyria — bryły, otwory, bramy-sekrety
**Pliki:** `src/level/floor1/zones/northwest_kit.gd`, `src/level/floor1/zones/assyria.gd` (całość od nowa), `locale/strings.csv` (dopisz klucze).
- [ ] Sale, galeria lwów (płyty, słupki, balustrady, dwa biegi), schody towarowe, otwory, bramy-sekrety z tabel wyżej.
- [ ] `--filter=floor1_layout` zielony → commit `Assyria greybox: palace round the courtyard, sunken Lion Hunt hall with its gallery, library over the freight stairs, three gated secrets`.

### Zadanie 4: Asyria — wnętrza, światło, znaczniki, spotkania, łup
- [ ] Lamassu, obelisk, płyty reliefów, rusztowanie z bezpiecznikiem, cokoły i kolumny areny, rydwan i klatki w dole, gabloty biblioteki; światło; znaczniki; spawny / patrole / zasadzki; łup.
- [ ] `--filter=floor1_northwest` (testy Asyrii) zielone → commit.

### Zadanie 5: Ameryki — bryły, otwory, brama czółna, sekrety
**Pliki:** `src/level/floor1/zones/americas.gd`, `locale/strings.csv`.
- [ ] Sale, wieża, zapadnięta podłoga z płytą-mostem, magazyn pod totemami, kryjówka (klatka + komora), otwory, `hook_canoe` i bramy-sekrety.
- [ ] `--filter=floor1_layout` zielony → commit.

### Zadanie 6: Ameryki — wnętrza, światło, znaczniki, spotkania, łup
- [ ] Moai, totemy, ekspozycja wielorybnicza, czółno, tarasy świątyni, misy ognia, ołtarzyki; światło; znaczniki; spawny; łup.
- [ ] `--filter=floor1_northwest` zielone → commit.

### Zadanie 7: test na zbudowanym piętrze
**Pliki:** `tests/integration/test_floor1_northwest_walk.gd`.
- [ ] Dwa budowania:
  - wszystkie bramy otwarte: `test_with_every_gate_open_the_wings_walk_end_to_end` — z każdego wejścia skrzydła do głównego wejścia i do każdej sali (sekrety, dno dołu, kryjówka, tarasy też), pion Sali Lwów (galeria y 0 ↔ dół y −3 ↔ podziemia y −6), wieża (y −6 ↔ y 0), dno zapadliska → magazyn → wieża; `test_slots_and_floor_loot_stand_on_the_navmesh_in_the_clear` (kapsuła 0,42 × 2 m, odcinki patroli proste);
  - stan „pierwszego przyjścia” (otwarte tylko `seal_khorsabad`, `seal_balawat`, `shutter_americas`): `test_on_arrival_the_keys_are_reached_and_the_canoe_holds` — harpunnik osiągalny z żaluzji i z Balawat, bezpiecznik i Lamassu z Chorsabadu, promień fizyczny z Egiptu do obelisku i od harpunnika do czółna bez trafienia; świątynia, sekrety i Grecja (zasuwa) nieosiągalne; `level.open_gate(&"hook_canoe")` → po przebudowie świątynia osiągalna z Pacyfiku po moście.
- [ ] `--filter=floor1_northwest_walk` i `--filter=museum_floor` zielone → commit.

### Zadanie 8: całość
- [ ] `bash tools/run_tests.sh` (pełny) zielony; „Jak zbudowano / odstępstwa” w tym pliku; commit; raport do kontrolera (≤ 40 linii).

---

## Prośby do kontrolera (do potwierdzenia w raporcie)

1. **Most z czółna (W1):** `HookLock` (SWING) na `americas_canoe_bridge`: początek zamka w środku otworu, −Z ku galerii (zachód), długość czółna ≈ 6,5 m (dół 5,5 m + mury). Przy podpięciu zamka **usunąć płytę `canoe_bridge`** (greyboksowy zastępca pokładu); znacznik `americas_canoe` to miejsce wiszącego czółna (sztuka). Pokład zamka ma 0,9 m szerokości — przy promieniu agenta 0,5 m siatka go nie upiecze; do rozważenia szerszy pokład kolizji (2–2,5 m).
2. Księżyc w `MOON_GROUP` z `hub_kit.gd` (dziś `emergency_lights`) — po dodaniu grupy `moon` przez W1 wystarczy zmiana stałej.
3. Nowe znaczniki strażników: `lamassu_relief_<n>` (skąd w fazie 2 schodzą wojownicy z reliefów), `serpent_path_<n>` (pętla ciała Węża), `americas_canoe`.
4. Galeria Sali Lwów (`carved = false`) jest pokojem przy przejściu `j_assyria_greece` (strona zasuwy: `one_way_side = assyria_lions_gallery`).

---

## Jak zbudowano (3.10) — odstępstwa od planu wyżej

| Co | Zmiana | Dlaczego |
|---|---|---|
| Wieża schodów Ameryk | pierwszy bieg w pasie **zachodnim** (`Grey.tower(…, 2, 0, false, …)`): z drzwi do podziemi prosto na północ do płyty y −3, drugi bieg w pasie wschodnim na południe do górnego podestu przy drzwiach do Sali Ameryki Płn. | z pierwszym biegiem w pasie wschodnim Recast nie upiekł na nim siatki (ani na wschodniej połowie płyty y −3): dno wieży i magazyn pod totemami były odcięte od reszty (wykrył test siatki; sprawdzone promieniami — geometria była poprawna) |
| Łup | w Balawat róg NW przesunięty z (−61,8, −78,3) na (−58,5, −78,2); w Sali Totemów z x −33,9 na −33,6 | 0,5-metrowy pas między gablotą a ścianą mógł nie dostać siatki |
| Reflektor pod czółnem | ustawiony przy północnym końcu dołu (−29,5, −5,6, −82,6) | ze środka dołu snop szedł przez płytę-most |
| Znaczniki dodatkowe | `black_obelisk`, `flood_tablet` (miejsca na sztukę), `americas_canoe` | plan sztuki i W1 (most z czółna) |
| Pomocnik `northwest_kit.gd` | reliefy, płyty, balustrady, tarasy, biegi, misy ognia | wspólne dla obu modułów; bramy/legowiska/światła z `west_kit.gd`, `MOON_GROUP`/patrole z `hub_kit.gd` (tylko `preload`, bez zmian w cudzych plikach) |

Wyniki: **Asyria 11 sal** (8 + 3 sekrety), **Ameryki 11 sal** (8 + 3 sekrety); `test_floor1_northwest` 16/16, `test_floor1_northwest_walk` 3/3, wszystkie testy `floor1` (144) zielone, w tym część A, hub W2 i skrzydła W3. Pomiar budowania całego piętra (z hubem W2 i skrzydłami W3–W4, przy ograniczeniu CPU do połowy): 86 sal, 103 otwory, 515 elementów, 32 biegi schodów, 273 sloty, 129 łupów, 39 bram; rzeźbienie ≈ 6,2 s, budowa ≈ 8,7 s, wypiekanie ≈ 0,78 s (3358 wielokątów) — wypiekanie zbliża się do budżetu 1 s z fundamentu (§ nawigacja: region na bryłę strefy).

Notatki `note_assyria_1…4`, `note_americas_1…4` czekają na teksty (`NOTE_NOTE_*_TITLE`, jak notatki W3 — `WorldFeatures` ostrzega i je pomija).
