# P1 / W3 — Egipt i Grecja (skrzydła zachodnie): plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`. Wykonuje Claude (W3) w drzewie `.claude/worktrees/p1-w3-west`, gałąź `p1-w3-west`. Wiążące: `docs/superpowers/plans/2026-10-02-p1-fundament.md` (strefy, przejścia, zasady budowniczych, W3), projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §3.4, §4, §5.1, §5.3, §7.2, §7.4, §9.1, §10.1.

**Cel:** prawdziwy układ greybox Egiptu (wzorcowe skrzydło, pierwsze „wow” gry) i Grecji (jasny kontrapunkt): sale w swoich bryłach, przejścia, sekrety, znaczniki, spotkania, łup i światło według przepisu skrzydła — grywalne i sprawdzone testami.

**Architektura:** dwa moduły stref (`zones/egypt.gd`, `zones/greece.gd`) wypełniają `LevelLayout` czystymi danymi przez `Floor1Greybox`; `Floor1Layout` dokłada otwory przejść. Testy: jednostkowy na danych (`test_floor1_west.gd`: bryły, odstępy, przejścia, znaczniki, zestawy, gęstość, schody, widoczność strzelby jako geometria) i integracyjny na zbudowanym piętrze (`test_floor1_west_walk.gd`: siatka nawigacji, kapsuła, promień fizyczny do strzelby, bramy odcinają).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, testy `bash tools/run_tests.sh --filter=…` (bez okna, bez dźwięku).

---

## Pliki

| Plik | Co robi |
|---|---|
| `src/level/floor1/zones/egypt.gd` | moduł Egiptu (zastępuje szkielet): sale, otwory, bramy-sekrety, elementy, światło, znaczniki, spawny, patrole, zasadzki, łup |
| `src/level/floor1/zones/greece.gd` | moduł Grecji (jw.) |
| `tests/unit/test_floor1_west.gd` | testy danych obu skrzydeł |
| `tests/integration/test_floor1_west_walk.gd` | testy na zbudowanym piętrze (nawigacja, kapsuła, promień) |
| `locale/strings.csv` | nowe klucze `ROOM_EGYPT_*`, `ROOM_GREECE_*` — **tylko dopisane na końcu** |
| ten plik | plan + na końcu odstępstwa „jak zbudowano” |

Nie ruszam: `floor1_plan.gd` (prośby do kontrolera w raporcie), modułów innych stref, testów części A (muszą zostać zielone).

## Ograniczenia, które kształtują projekt

1. **Sekrety za bramami, nie za fałszywymi panelami.** Testy części A (`test_floor1_layout`: graf z otwartymi tylko bramami; `test_museum_floor_level`: siatka z otwartymi bramami do *każdej* sali) traktują łącza `SECRET`/drzwi `PANEL` jako zamknięte. Dlatego każdy sekret to sala za **bramą strefy z prefiksem** (`egypt_*`, `greece_*`) poza drogą krytyczną: łańcuch (ciężkie), spękany mur (wybuch: raca ×3 z bliska, ognista skrzynia), lina (precyzja), hak (harpunnik). To zgodne z projektem (§7.1: raca na woskowe pieczęcie i pajęczyny, §5.3: „sekret z liną”) i daje metroidvanię także w sekretach.
2. **Schody z biegami ≤ 20,6°** (`Floor1Plan.STAIR_SLOPE`): 6 m w pionie = 16 m biegu.
3. **Pokoje się nie stykają** (≥ 0,5 m muru); antresole i podium to sale `carved = false` w wysokich salach (idiom balkonu z lobby).
4. **Nazwy sal a dźwięk** (notatka kontrolera): id z `tomb` dostaje tło grobowca, z `stair`/`corridor` pogłos korytarza.

---

## EGIPT

Strefa: główna bryła x −55…−31, z −38…30 (y −0,5…32); zachodnia x −63…−55, z 0…30; podziemia pod główną (y −6,5…−0,5, bez pasa tunelu z −37…−33).
Przejścia po stronie Egiptu: dziedziniec x = −31, z 20…26 (h 7); Asyria z = −38, x −54…−48 (h 8, pieczęć); Grecja x = −63, z 10…14 (h 3,5, deski); podziemia x = −31, z −12,5…−10,5, y −6 (zasuwa od Egiptu).

### Plan parteru (widok z góry, północ = góra, x rośnie w prawo)

```
x: -63   -60.5 -57  -55  -50.5 -50        -42.5          -34 -33.5 -31  -30
z-38            ┌────[BRAMA CHORSABADU x-54..-48]────────────────────────┐
                │ ║                                                      │
                │ ║        SALA KOLOSA 24×24, h14   (arena)              │
                │ ○ col1     ▓▓▓▓ KOLOS (x-42.5,z-32.5) ▓▓▓   ○ col5     │
                │ ○ col2    ○ col3            ○ col4          ○ col6     │
                │                 · · świetlik (księżyc) · ·    ○ col7   │
z-14            └──[drzwi]──────────[ PORTAL x-47.5..-37.5 ]─────────────┘
z-13.5          ┌──────┐ ┌───────────────────────────────┐ ┌───┐
                │KORYT.│ │ █ kolos            kolos █    │ │ S │ schody
                │GROB. │=│                               │ │ C │ służbowe
                │      │ │ █ kolos  ☾      ☾  kolos █    │ │ H │ z-13..10.5
z 0             └──┬───┘ │      ┌─OBÓZ 1898─┐ ⚱         │ │ O │ (dół: y-6,
z0.5 ┌──────┐ ┌────┴──┐  │ █    │namiot  ✚  │ ⚱  kolos █│=│ D │  zasuwa →
     │KONSER│=│GROBOW-│  │      └─stół STRZELBA          │ │ Y │  podziemia)
z7   │WATOR │ │ CE    │  │                               │ └───┘
z7.5 └──────┘ │(komory│==│ █ kolos  ☾           kolos █  │ ┌───┐
 ◄GRECJA═deski│ grob.)│  │                               │ │SKŁ│ skład
   z10..14    │       │  │ █ kolos  ☾           kolos █  │ │EKS│ ekspedycji
z15  └[spęk]──┴[drzwi]┘  │                               │ │PED│ (łańcuch)
z15.5┌─────┐ ┌─────────┐ └──[ŁUK x-49.5..-34.5, h7]──────┘ └───┘
     │SERD-│ │  SALA   │ ┌─────────────────────────────────────────┐
     │AB   │ │SARKOFA- │ │   PRZEDSIONEK ROSETTY 19×10.5, h7.5     │◄═ DZIEDZINIEC
z21  └─────┘ │  GÓW    │=│        ▣ Kamień z Rosetty               │   z20..26
z21.5┌─────┐ │         │ │                                         │
     │GRÓB │[hak]      │ │                                         │
     │KAPŁ.│ │         │ │                                         │
z30  └─────┘ └─────────┘ └─────────────────────────────────────────┘
```
`☾` świetliki (zimny księżyc w nawie), `█` kolosy z ciepłymi reflektorami, `⚱` sarkofagi zasadzki, `○` kolumny papirusowe pękające od promienia.

**Widok wejścia:** z drzwi dziedzińca promień na wysokości oczu biegnie przez północno-wschodni róg przedsionka i łuk (15 × 7 m) w głąb galerii aż do stołu obozu — strzelba w ciepłym świetle lamp naftowych widoczna od progu. Rzędy kolosów stoją tak, że nie przecinają tej linii (pierwszy kolos wschodni na z = 12).

**Pętle:** przedsionek → galeria → (drzwi zach.) korytarz grobowy → grobowce → sala sarkofagów → przedsionek; galeria ↔ grobowce środkiem; galeria → arena (portal) i korytarz grobowy → arena (boczne drzwi).

### Sale Egiptu

| Id | Prostokąt(y) (x0, z0 → x1, z1) | y podłogi … sufitu | Nazwa (klucz) | Publiczna | Uwagi |
|---|---|---|---|---|---|
| `egypt_vestibule` | −50, 19,5 → −31, 30 | 0 … 7,5 | `ROOM_EGYPT_VESTIBULE` | tak | wejście z dziedzińca |
| `egypt_gallery` | −50, −13,5 → −34, 19 | 0 … 11 | `ROOM_EGYPT_GALLERY` | tak | 16 × 32,5; 4 świetliki w nawie |
| `egypt_colossus` | −55, −38 → −31, −14 | 0 … 14 | `ROOM_EGYPT_COLOSSUS` | tak | arena; świetlik nad środkiem |
| `egypt_tomb_passage` | −55, −13,5 → −50,5, 0 | 0 … 4 | `ROOM_EGYPT_TOMB_PASSAGE` | tak | boczne wejście na arenę |
| `egypt_tombs` | −56,5, 0,5 → −50,5, 7,5 + −63, 7,5 → −50,5, 15 | 0 … 4 | `ROOM_EGYPT_TOMB` | tak | deski do Grecji |
| `egypt_conservator` | −63, 0,5 → −57, 7 | 0 … 3,5 | `ROOM_EGYPT_CONSERVATOR` | nie | przystań `conservator` |
| `egypt_tomb_hall` | −60, 15,5 → −50,5, 30 | 0 … 4,5 | `ROOM_EGYPT_SARCOPHAGI` | tak | zasadzka mumii |
| `egypt_tomb_serdab` | −63, 15,5 → −60,5, 21 | 0 … 3 | `ROOM_EGYPT_SERDAB` | nie, sekret | spękany mur (wybuch) |
| `egypt_tomb_priest` | −63, 21,5 → −60,5, 30 | 0 … 3 | `ROOM_EGYPT_PRIEST` | nie, sekret | hak (harpunnik) |
| `egypt_service_stairs` | −33,5, −13 → −31, 10,5 | −6 … 3 | `ROOM_SERVICE_STAIRS` | nie | bieg 16 m na +z, podest górny 4,5 m |
| `egypt_cache` | −33,5, 11 → −31, 19 | 0 … 3 | `ROOM_EGYPT_CACHE` | nie, sekret | łańcuch (ciężkie) |

### Otwory Egiptu (moduł; przejścia stref dodaje `Floor1Layout`)

| Id | Prostokąt | y | Pokoje | Styl / łącze |
|---|---|---|---|---|
| `egypt_vestibule_gallery` | −49,5, 19 → −34,5, 19,5 | 0…7 | przedsionek ↔ galeria | łuk |
| `egypt_gallery_colossus` | −47,5, −14 → −37,5, −13,5 | 0…10 | galeria ↔ arena | portal |
| `egypt_passage_colossus` | −54, −14 → −52, −13,5 | 0…3 | korytarz ↔ arena | łuk |
| `egypt_gallery_passage` | −50,5, −8,5 → −50, −6 | 0…3 | galeria ↔ korytarz | łuk |
| `egypt_passage_tombs` | −54, 0 → −52, 0,5 | 0…3 | korytarz ↔ grobowce | łuk |
| `egypt_gallery_tombs` | −50,5, 7,5 → −50, 10 | 0…3,5 | galeria ↔ grobowce | łuk |
| `egypt_tombs_conservator` | −57, 2,5 → −56,5, 4,5 | 0…2,6 | grobowce ↔ konserwator | SWING |
| `egypt_tombs_hall` | −56, 15 → −53,5, 15,5 | 0…3 | grobowce ↔ sala sarkofagów | łuk |
| `egypt_vestibule_hall` | −50,5, 25,5 → −50, 28,5 | 0…3,5 | przedsionek ↔ sala sarkofagów | łuk |
| `egypt_gallery_stairs` | −34, 8,5 → −33,5, 10,5 | 0…2,6 | galeria ↔ schody | SWING |
| `egypt_stairs_cache` | −33,25, 10,5 → −31,25, 11 | 0…2,6 | schody ↔ skład | DOUBLE_SWING, GATE + brama `egypt_chain_cache` (CHAIN, `heavy`) |
| `egypt_tombs_serdab` | −62,5, 15 → −61, 15,5 | 0…2,4 | grobowce ↔ serdab | PANEL, GATE + `egypt_cracked_serdab` (CRACKED, `explosive`) |
| `egypt_hall_priest` | −60,5, 24,5 → −60, 26,5 | 0…2,4 | sala sarkofagów ↔ grób kapłana | GATE, GATE + `egypt_hook_false_door` (HOOK, `harpoon`) |

### Znaczniki Egiptu

| Znacznik | Gdzie | Pokój |
|---|---|---|
| `weapon_shotgun` | stół obozu (−43, 0,85, 3), przód na +z | galeria |
| `guardian_colossus` | (−42,5, 0, −32,5), przód na +z | arena |
| `arena_colossus_start` | (−42,5, 0, −16) | arena |
| `arena_colossus_door_1` / `_2` | środek portalu / bocznych drzwi, −Z w głąb areny | arena |
| `arena_colossus_supply_1…3` | przy wejściu, zachód, wschód | arena |
| `colossus_column_1…7` | podstawy kolumn | arena |
| `rosetta_stone` | gablota (−43, 1, 25,5) | przedsionek |
| `note_egypt_1…4` | stół obozu, biurko konserwatora, ławka przedsionka, skrzynia w składzie | |
| `secret_egypt_1…3` | skład ekspedycji, serdab, grób kapłana | sekrety |
| `chess_2` | cokolik za tronem kolosa (−35,5, 1, −36,5) | arena |
| `cctv_egypt_1` | róg SE galerii, wysoko, patrzy w nawę | galeria |
| `museum_map_conservator` | ściana przystani | konserwator |
| terminal `conservator` | (−62,6, 0, 4), −Z na +x | konserwator |

### Spotkania Egiptu (rodzaje: zastępca + docelowy)

`mummy` → `[&"wax", &"mummy"]`, `scarabs` → `[&"wolf", &"scarabs"]`, archeolog woskowy → `[&"wax"]`.

| Sala | Zawsze (`ALWAYS_SET`) | Zestawy 0…2 | Patrol / zasadzka |
|---|---|---|---|
| przedsionek | — | 0: 2 archeologów; 1: archeolog + mumia | — |
| galeria | 3 mumie + 1 rój przy sarkofagach obozu | 0: archeolog na patrolu + mumia; 1: 2 mumie przy kolosach + rój; 2: archeolog na patrolu + rój | `egypt_gallery_nave` (wzdłuż wschodniej strony nawy); zasadzka `egypt_camp` przy podniesieniu strzelby |
| korytarz grobowy | — | 0: rój; 1: mumia | — |
| grobowce | — | 0: 2 mumie; 1: mumia + rój | `egypt_tombs_walk` |
| sala sarkofagów | 2 mumie w sarkofagach | 0: mumia; 1: rój | zasadzka `egypt_sarcophagi` (obszar środka sali) |
| skład / serdab / grób kapłana | rój / mumia / mumia | — | zasadzki obszarowe w środku |
| arena, przystań, schody | — | — | (arena: strażnik i jego wezwania) |

### Światło Egiptu (§10.1: zimny księżyc + ciepłe reflektory; najciemniejsze skrzydło)

Świetliki (księżyc) w nawie galerii i nad środkiem areny; reflektory SPOT (ciepłe, 22–30°) na każdy kolos i na Kolosa; ciepła wyspa obozu (dwie lampy naftowe, jedna z cieniem); przedsionek: reflektor na Kamień z Rosetty + słaba zimna lampa; grobowce: pojedyncze przygaszone „pochodnie” (prawie ciemno — skradanie); czerwone lampy awaryjne; przystań: lampy `haven_lights`.

---

## GRECJA

Strefa: główna bryła x −112…−64, z −2…53; pas x −64…−17, z 31…53; y −6,5…32.
Przejścia po stronie Grecji: Egipt x = −64, z 10…14 (deski); Asyria z = −2, x −90…−87 (zasuwa od Asyrii); hol x = −17, z 50…52, **y 6** (zasuwa od Grecji); podziemia z = 31, x −28…−26, **y −6** (zasuwa od Grecji).

### Plan parteru (y = 0)

```
x: -112 -106.5 -106          -86.5 -86                         -64 | pas x-64..-17
z-2  ┌─────┐ ┌───────[ASYRIA x-90..-87]┐ ┌────────────────────────┐
     │STRYCH│ │ SALA Z BASSAE         │ │  POMNIK NEREID 22×27   │
     │(y4.5)│ │ ═antresola y4.5 (U)═  │=│ ═balkon y4.5═╗ schody  │
     │ lina │ │                        │ │ ▓PODIUM▓ ║            │◄═ EGIPT (deski)
z16  └─────┘ │       schody ↑         │ │ ▓świąt.▓   ☾☾        │    z10..14
z16.5        ├───────[drzwi]──────────┤ │ ▓ (y4.5)▓            │
             │ SALA WAZ 19.5×19.5     │=│                       │
z25.5        │                        │ └────────[drzwi 7m]─────┘
z26          │                        │ ┌────────────────────────┐
z36          │      [spęk]            │=│ SALA METOP (L)         │      PARTENON 39.5×18, h12
z36.5        └──────┬──────┬──────────┘ │                        │ ┌──────────────────────────┬──────┐
             ┌──────┴──────┐           │            ┌───────────┤═│ ▭ ▭ ▭   ☾  ☾  ☾  ☾  ▭ ▭ │WIEŻA │
             │MAGAZYN SKORUP│          │ ┌──────┐   │           │ │  KENTAUR (-44,43)  ▭▭▭▭▭ │-6..6 │◄═ HOL
z44.5        └─────────────┘          │ │MAGAZ.│===│ (cz.płd.) │ │ ▭ ▭ ▭      fronton W/E   │      │  y6
z45     ┌──────────────┐               │ │ODLEW.│   │           │ └────[dz.y0]───────────────┴──────┘
        │ZAPLECZE (hak)│===============│ │przyst│   │           │       (pod spodem y-6: korytarz
z52     └──────────────┘               └─┴──────┘───┴───────────┘        służbowy → podziemia z=31)
```

### Antresole (y = 4,5)

- **Pomnik Nereid:** schody wzdłuż północnej ściany (x −78…−66, wznoszą się na zachód) → balkon północny (x −86…−78) → noga zachodnia (x −86…−83, z 1,5…7) → **szczyt podium** (x −86…−79, z 7…17, y 4,5) z portykiem świątyni (cella x −86…−82,5, cztery kolumny jońskie i nereidy na linii x −79,5). Drzwi na wysokości balkonu (x −86,5…−86, z −1…1,5) do antresoli Bassae — **pętla pionowa**.
- **Sala z Bassae:** antresola w kształcie U: noga północna (pełna szerokość, nad drzwiami z Asyrii) + noga zachodnia; schody wzdłuż południowej ściany (x −102,5…−90,5). Z nogi zachodniej drzwi z **liną** (`greece_rope_loft`, precyzja) na **strych** (sekret, x −112…−106,5, z 0…10, y 4,5…8).

### Podziemia (y = −6)

Korytarz służbowy x −28,5…−24,5, z 31…53 pod wschodnim końcem Partenonu: od przejścia do podziemi (z = 31) do dna **wieży schodów** (x −24…−17, z 39…53, 4 biegi po 3 m, spoczniki co 3 m; drzwi na y −6 i y 0 w zachodniej ścianie przy z 50…52, na y 6 wschodnia ściana = przejście do holu).

### Sale Grecji

| Id | Prostokąt(y) | y | Nazwa | Publ. | Uwagi |
|---|---|---|---|---|---|
| `greece_nereid` | −86, −1,5 → −64, 25,5 | 0…14 | `ROOM_GREECE_NEREID` | tak | wejście z Egiptu; świetlik przed pomnikiem |
| `greece_nereid_podium` | −86, −1,5 → −78, 1,5 + −86, 1,5 → −83, 7 + −86, 7 → −79, 17 | 4,5…14 | `ROOM_GREECE_PODIUM` | tak | `carved = false` |
| `greece_bassae` | −106, −2 → −86,5, 16 | 0…10 | `ROOM_GREECE_BASSAE` | tak | zasuwa z Asyrii |
| `greece_bassae_gallery` | −106, −2 → −86,5, 1,5 + −106, 1,5 → −102,5, 16 | 4,5…10 | `ROOM_GREECE_BASSAE_GALLERY` | tak | `carved = false` |
| `greece_bassae_loft` | −112, 0 → −106,5, 10 | 4,5…8 | `ROOM_GREECE_LOFT` | nie, sekret | lina |
| `greece_vases` | −106, 16,5 → −86,5, 36 | 0…7 | `ROOM_GREECE_VASES` | tak | |
| `greece_pottery` | −101, 36,5 → −91, 44,5 | 0…3,5 | `ROOM_GREECE_POTTERY` | nie, sekret | spękany mur |
| `greece_metopes` | −86, 26 → −64,5, 39,5 + −78, 39,5 → −64,5, 51 | 0…9 | `ROOM_GREECE_METOPES` | tak | przedsionek areny |
| `greece_cast_store` | −86, 40 → −78,5, 52 | 0…4,5 | `ROOM_GREECE_CAST_STORE` | nie | przystań `cast_store` |
| `greece_cast_cellar` | −96, 45 → −86,5, 52 | 0…3,5 | `ROOM_GREECE_CELLAR` | nie, sekret | hak |
| `greece_parthenon` | −64, 34 → −24,5, 52 | 0…12 | `ROOM_GREECE_PARTHENON` | tak | arena Kentaura; 4 świetliki |
| `greece_service_stairs` | −24, 39 → −17, 53 | −6…9 | `ROOM_SERVICE_STAIRS` | nie | wieża `Grey.tower` |
| `greece_service_corridor` | −28,5, 31 → −24,5, 53 | −6…−3 | `ROOM_GREECE_UNDERCROFT` | nie | pod galerią |

### Otwory Grecji

| Id | Prostokąt | y | Pokoje | Styl |
|---|---|---|---|---|
| `greece_bassae_nereid` | −86,5, 3 → −86, 6 | 0…3,5 | Bassae ↔ Nereidy | łuk |
| `greece_gallery_podium` | −86,5, −1 → −86, 1,5 | 4,5…7 | antresola ↔ balkon podium | łuk |
| `greece_bassae_vases` | −90, 16 → −87, 16,5 | 0…4 | Bassae ↔ wazy | łuk |
| `greece_nereid_vases` | −86,5, 18 → −86, 21,5 | 0…4 | Nereidy ↔ wazy | łuk |
| `greece_nereid_metopes` | −78, 25,5 → −71, 26 | 0…6 | Nereidy ↔ metopy | łuk |
| `greece_vases_metopes` | −86,5, 30 → −86, 33 | 0…4 | wazy ↔ metopy | łuk |
| `greece_metopes_parthenon` | −64,5, 37 → −64, 49 | 0…8 | metopy ↔ Partenon | łuk (paszcza areny) |
| `greece_metopes_store` | −78,5, 44 → −78, 46 | 0…2,6 | metopy ↔ magazyn | SWING |
| `greece_parthenon_stairs` | −24,5, 50 → −24, 52 | 0…2,6 | Partenon ↔ wieża | SWING |
| `greece_corridor_stairs` | −24,5, 50,5 → −24, 52,5 | −6…−3,4 | korytarz ↔ wieża | SWING |
| `greece_gallery_loft` | −106,5, 3 → −106, 5,5 | 4,5…7 | antresola ↔ strych | GATE + `greece_rope_loft` (ROPE, `precise`) |
| `greece_vases_pottery` | −97, 36 → −95, 36,5 | 0…2,4 | wazy ↔ skorupy | PANEL + `greece_cracked_pottery` (CRACKED, `explosive`) |
| `greece_store_cellar` | −86,5, 47 → −86, 49 | 0…2,4 | magazyn ↔ zaplecze | GATE + `greece_hook_cellar` (HOOK, `harpoon`) |

### Znaczniki Grecji

`guardian_centaur` (−44, 0, 43, przód na −x), `arena_centaur_start` (−60, 0, 43), `arena_centaur_door_1` (paszcza zach.), `arena_centaur_door_2` (drzwi wieży na y 0), `arena_centaur_supply_1…3`; `note_greece_1…4` (magazyn odlewów, strych, ławka metop, skrzynia w korytarzu); `secret_greece_1…3` (strych, skorupy, zaplecze); `chess_3` (szczyt podium za cellą); `cctv_greece_1` (Nereidy), `cctv_greece_2` (Partenon); `museum_map_cast_store`; terminal `cast_store` (−85,6, 0, 43, −Z na +x).

### Spotkania Grecji

`hoplite` → `[&"knight", &"hoplite"]`, popiersie → `[&"bust"]`.

| Sala | Zawsze | Zestawy | Patrol / zasadzka |
|---|---|---|---|
| Nereidy | — | 0: 2 hoplitów przy podium + 2 popiersia; 1: hoplita na patrolu + 3 popiersia; 2: falanga 3 hoplitów + popiersie | `greece_nereid_round` |
| podium | 2 popiersia przy portyku | — | zasadzka `greece_podium` (wejście na szczyt) |
| Bassae / antresola | — | 0: hoplita + popiersie; 1: 2 popiersia (jedno na antresoli) | — |
| wazy | — | 0: 2 popiersia + hoplita na patrolu; 1: 3 popiersia | `greece_vases_aisle` |
| metopy | 2 hoplitów („Lapici”) na cokołach | 0: popiersie + hoplita; 1: 2 popiersia | `greece_metopes_watch`; zasadzka `greece_lapiths` przed paszczą areny |
| korytarz służbowy | — | 0: popiersie; 1: hoplita | — |
| strych / skorupy / zaplecze | popiersie / hoplita / hoplita | — | zasadzki w środku |

### Światło Grecji (§10.1: najjaśniejsze, srebrne)

Świetliki w każdej publicznej sali (Partenon 4 × 4 m ×4), chłodne białosrebrne lampy sufitowe (energia 1,6–2,2), reflektor na fasadę Nereid, czerwone lampy awaryjne, magazyn odlewów ciepły (`haven_lights`), wieża i korytarz: świetlówki.

---

## Zadania

### Zadanie 1: plan (ten dokument)
- [ ] Zapis i commit `docs: P1/W3 plan — Egypt and Greece`.

### Zadanie 2: test danych Egiptu (najpierw czerwony)

**Pliki:** utwórz `tests/unit/test_floor1_west.gd`.

- [ ] Testy (każdy na `Floor1Layout.create()` w `before_each`):
  - `test_key_rooms_have_their_sizes` — galeria 16 × ≥ 32 × h 11, arena 24 × 24 × h 14, Partenon 39,5 × 18 × h 12, wieża sięga y −6 i y 6;
  - `test_rooms_keep_apart_inside_their_zone` — części różnych sal Egiptu/Grecji (tylko `carved`) nie zachodzą i nie stykają się (odstęp ≥ 0,5 m albo płyta ≥ 0,5 m w pionie); każda część w bryle strefy;
  - `test_junction_rooms_cover_their_doorways` — dla każdego przejścia strefy pokój przy otworze pokrywa cały otwór (szerokość, wysokość);
  - `test_internal_doorways_join_neighbouring_rooms` — każdy otwór modułu leży między swoimi dwoma pokojami (punkty 0,25 m za ścianą po obu stronach należą do pokoi A i B);
  - `test_secret_rooms_sit_behind_zone_gates` — każdy pokój `secret` ma bramę z prefiksem strefy i dozwolonym wymaganiem (`heavy`, `explosive`, `precise`, `harpoon`);
  - `test_markers_lie_in_their_rooms` — wszystkie znaczniki `egypt_*`/`greece_*`/`note_*`/`secret_*`/`chess_*`/`arena_*`/`colossus_column_*`/`cctv_*` w swoim pokoju (rzut i wysokość);
  - `test_three_secrets_and_three_or_four_notes_per_wing`, `test_one_chess_piece_per_wing`;
  - `test_every_room_with_exhibits_has_two_sets_and_a_sane_density` — ≥ 2 zestawy (pomijając sale tylko z zasadzką), 0,6–1,2/100 m² (małe sale: 1–2 eksponaty);
  - `test_patrols_and_ambushes` — punkty patrolu w pokoju, sloty zasadzki w tym pokoju, zasadzka strzelby na `weapon_shotgun`;
  - `test_stairs_never_steeper_than_the_plan` — `rise / run ≤ STAIR_SLOPE + 0,001`;
  - `test_the_shotgun_is_in_plain_view_of_the_court_door` — odcinek od punktu 2,5 m za drzwiami dziedzińca (y 1,6) do strzelby (y 1,0): każdy punkt próbkowany co 0,1 m leży w sali albo otworze (po ścianach) i nie przecina żadnego kolidującego elementu (AABB elementu z obrotem);
  - `test_the_shotgun_needs_no_gate` — graf sal bez otwartych bram: z pokoju przy `j_court_egypt` do pokoju strzelby;
  - `test_lights_follow_the_wing_recipe` — każda publiczna sala ma światło `main_lights`; w Grecji więcej świetlików na 100 m² niż w Egipcie; obóz ma ciepłą lampę z cieniem w 4 m od strzelby.
- [ ] `bash tools/run_tests.sh --filter=floor1_west` → FAIL (szkielet nie spełnia).

### Zadanie 3: Egipt — bryły, otwory, bramy-sekrety, przystań
**Pliki:** `src/level/floor1/zones/egypt.gd` (całość od nowa), `locale/strings.csv` (dopisz klucze Egiptu).
- [ ] Sale, otwory, bramy z tabel wyżej; `haven_spots[&"conservator"]`; świetliki.
- [ ] `--filter=floor1` → testy brył/przejść zielone; `test_floor1_layout` zielony.
- [ ] Commit `Egypt greybox: rooms, doorways, secret gates, haven`.

### Zadanie 4: Egipt — wnętrza, światło, znaczniki, spotkania, łup
- [ ] Elementy (kolosy: `pedestal` + `sculpture`; sarkofagi: `plinth`; obóz: `crate`, `desk`; kolumny: `column`; gablota Rosetty: `case`; ławki), światło, znaczniki, spawny/patrole/zasadzki, łup.
- [ ] `--filter=floor1` zielone (bez testów Grecji) → commit `Egypt greybox: colossi, camp, arena, encounters, lights, markers`.

### Zadanie 5: Grecja — bryły, antresole, wieża, otwory, bramy, przystań
**Pliki:** `src/level/floor1/zones/greece.gd`, `locale/strings.csv`.
- [ ] Sale, antresole (`carved = false`, płyty `balcony`, podium `pedestal`, słupki, balustrady), schody, wieża `Grey.tower(…, 4, 0, false, ZONE)`, korytarz służbowy, otwory, bramy; `haven_spots[&"cast_store"]`.
- [ ] Commit `Greece greybox: rooms, mezzanines, stair tower, gates, haven`.

### Zadanie 6: Grecja — wnętrza, światło, znaczniki, spotkania, łup
- [ ] Świątynia na podium, gabloty waz, metopy, frontony i cokoły Partenonu, światło, znaczniki, spawny, łup.
- [ ] `--filter=floor1` zielone → commit.

### Zadanie 7: test na zbudowanym piętrze
**Pliki:** `tests/integration/test_floor1_west_walk.gd`.
- [ ] Jedno budowanie na test (bramy otwarte / zamknięte):
  - `test_every_west_room_is_walkable_from_its_wing_entrances` — z punktu przy każdym przejściu Egiptu i Grecji do środka każdej sali (z bramami otwartymi; sekrety też);
  - `test_slots_and_floor_loot_stand_on_the_navmesh_in_the_clear` — punkt na siatce ≤ 0,5 m, kapsuła 0,42 × 2 m wolna;
  - `test_the_shotgun_is_seen_and_reached_from_the_court_with_every_gate_shut` — promień fizyczny (maska WORLD) od wejścia do strzelby bez trafienia, droga po siatce z dziedzińca do stołu;
  - `test_shut_gates_cut_the_secrets_and_greece_off` — przy zamkniętych bramach brak drogi do sal sekretów i z Egiptu do Grecji;
  - `test_the_mezzanines_and_the_tower_connect_their_levels` — podium ↔ antresola Bassae, wieża: y −6 ↔ y 0 ↔ y 6.
- [ ] `--filter=floor1_west_walk` i `--filter=museum_floor` zielone → commit.

### Zadanie 8: całość
- [ ] `bash tools/run_tests.sh` (pełny) zielony; dopisać „Jak zbudowano / odstępstwa” w tym pliku; commit; raport do kontrolera (≤ 40 linii).

---

## Prośby do kontrolera (do potwierdzenia w raporcie)

1. Numeracja figur szachowych: W2 `chess_1`, **W3 `chess_2` (Egipt), `chess_3` (Grecja)**, W4 `chess_4–5`, W5a `chess_6–7`, W5b `chess_8`.
2. Sekrety to sale za bramami strefy (CHAIN/CRACKED/ROPE/HOOK) — `GateController` (W1) stawia dla nich zamki jak dla bram planu; `WorldFeatures` liczy sekret przy znaczniku `secret_<strefa>_<n>` w sali sekretu.
3. Znaczniki aren (nowe nazwy poza tabelą §6 zasad): `arena_<strażnik>_start`, `arena_<strażnik>_supply_<faza>`, `colossus_column_<n>` (już w planie W3).
4. Zasadzki używają `SpawnSlot.ALWAYS_SET` — do czasu nauczenia reżysera (W1) obecny reżyser losuje −1 jak zwykły zestaw.

---

## Jak zbudowano (3.10) — odstępstwa od planu wyżej

| Co | Zmiana | Dlaczego |
|---|---|---|
| Zejście do podziemi w Egipcie | klatka `egypt_service_stairs` x −33,5…−31, z −10…10,5 (podest górny 2,5 m, drzwi do galerii z 8,25…10,25); **nowa sala** `egypt_service_corridor` (`ROOM_EGYPT_UNDERCROFT`, „Magazyn pod galerią”, y −6…−3, kształt L pod posadzką galerii: x −40…−31, z −13…−10,5 + x −40…−34, z −10,5…−7,5) z drzwiami przejścia `j_basement_egypt`; do klatki łukiem w jej zachodniej ścianie (z −9,75…−8,25) | skrzydło drzwi przejścia (SWING, pokój A = podziemia) otwiera się do pokoju B i leży wzdłuż jego ściany: w klatce 2,5 m odcinało bieg (wykrył test siatki) |
| Drzwi przy schodach | otwory `egypt_gallery_stairs`, `greece_parthenon_stairs`, `greece_corridor_stairs` mają pokój klatki jako A | skrzydło SWING otwiera się do pokoju B — tam, gdzie jest miejsce, nie na podest z biegiem |
| Skład ekspedycji | skrzynie na końcu sali (z ≈ 18,5), łup podłogowy w przejściu | wąska sala 2,5 m: skrzynie wzdłuż ściany zjadały siatkę |
| Zaplecze odlewni (sekret 3 Grecji) | wejście z **magazynu skorup** (hak na drzwiach x −95…−93, z 44,5…45), nie z przystani | podłoga przystani to osobny region nawigacji (nie łączy się z resztą): przez nią bot W7 nie doszedłby do sekretu; teraz „sekret w sekrecie” (wybuch, potem harpunnik) |
| Kolumny areny Kolosa | 7 (`colossus_column_1…7`), nie 8 | przedpole Bramy Chorsabadu zostaje wolne |
| Test przejść | `test_floor1_west_walk` pomija przystanie (osobny region) jak test części A | jw. |

Wyniki: 12 sal Egiptu, 13 sal Grecji (z antresolami i sekretami); `test_floor1_west` 15/15, `test_floor1_west_walk` 3/3, testy części A zielone. Pomiar budowania całego piętra z nowymi skrzydłami: 67 sal, 83 otwory, 176 elementów, 99 slotów, 59 łupów, 30 bram; rzeźbienie ≈ 2,1 s, budowa ≈ 2,3 s, wypiekanie ≈ 0,14 s (1750 wielokątów).
