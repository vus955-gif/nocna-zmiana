# P1 / W5a — Oświecenie i Azja (skrzydła wschodnie): plan wykonawczy

> **Dla wykonawcy:** zadania po kolei, kroki z polami `- [ ]`, najpierw test, potem kod, commit po każdym zadaniu. Wykonuje Claude (W5a) w drzewie `.claude/worktrees/p1-w5-east`, gałąź `p1-w5-east`.
> Wiążące: `docs/superpowers/plans/2026-10-02-p1-fundament.md` (bryły stref, przejścia, bramy, zasady budowniczych, W5a), projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §3.4, §4, **§5.4**, **§5.5**, §7.2, §7.4, §9.1, §10.1. Wzorce: W3 (`zones/egypt.gd`, `greece.gd`, `west_kit.gd`), W2 (`court.gd`, `hub_kit.gd`), W1 (`GateController`, `GuardianKeeper`).

**Cel:** prawdziwy greybox Oświecenia (Biblioteka Królewska 14 × 70 z galerią regałów, gabinety, sztucer, Rotunda Planetarium za liną) i Azji (Sala Chin z Buddą, Sala Koreańska z ognistą skrzynią, porcelana, zbroje, ogród japoński za spękanym murem z herbaciarnią) — przepływ na poziomie Doom/Quake: momenty odsłony, pętle, piony, osłony w arenach, sekrety ryzyko/nagroda, czytelne trasy. Sprawdzone testami jak W2/W3.

**Architektura:** dwa moduły stref (`zones/enlightenment.gd`, `zones/asia.gd`) wypełniają `LevelLayout` czystymi danymi przez `Floor1Greybox`, `hub_kit.gd` (lampy, reflektory, sloty, piechurzy, znaczniki z kierunkiem) i `west_kit.gd` (bramy-sekrety, legowiska, kinkiety, lampy awaryjne, kamery); własny mały `east_kit.gd` tylko na balustrady i rzędy regałów/gablot. `Floor1Layout` dokłada otwory przejść. Testy: jednostkowy `test_floor1_east.gd` (dane) i integracyjny `test_floor1_east_walk.gd` (zbudowane piętro, siatka nawigacji, promienie fizyczne).

**Technologia:** Godot 4.7.2, GDScript ze statycznym typowaniem, tabulatory, `bash tools/run_tests.sh --filter=…` (bez okna, bez dźwięku).

---

## Pliki

| Plik | Co robi |
|---|---|
| `src/level/floor1/zones/enlightenment.gd` | moduł Oświecenia (zastępuje szkielet) |
| `src/level/floor1/zones/asia.gd` | moduł Azji (zastępuje szkielet) |
| `src/level/floor1/zones/east_kit.gd` (nowy) | balustrady, rzędy regałów z przerwami na drzwi |
| `tests/unit/test_floor1_east.gd` (nowy) | dane obu skrzydeł |
| `tests/integration/test_floor1_east_walk.gd` (nowy) | zbudowane piętro: chodzenie, sloty na siatce, sztucer i lina, bramy |
| `locale/strings.csv` | nowe klucze `ROOM_ENLIGHTENMENT_*`, `ROOM_ASIA_*` — **tylko dopisane na końcu** |
| ten plik | plan + na końcu „jak zbudowano” |

Nie ruszam: `floor1_plan.gd` (prośby w raporcie), modułów innych stref, testów części A i W1 (mają zostać zielone).

## Ograniczenia, które kształtują projekt

1. **Biblioteka 14 × 70 m przy murze dziedzińca** (x 31…45, z −36…34; zestaw grafiki jest modularny, ale wymiar jest w projekcie i w briefie). Drzwi dziedzińca (z −3…3) trafiają w jej środek — odsłona w obie strony.
2. **Przejście na dach** (x 30…31, z −12…−10,5, **y 22,5**) leży nad biblioteką. Wieża schodów nie zmieści się pod nią, więc: **wieża wisi w paśmie wschodnim od poziomu galerii regałów (y 4) do 22,5** (sześć biegów po 3,08 m), a z jej górnego spocznika **strych biblioteki** (y 22,5) prowadzi na zachód do zasuwy na dach. Zgodne z §4.4 p. 6 („kładki … do górnej galerii Oświecenia”) i z zasadą fundamentu („wieżę wolno przenieść, jeśli górny spocznik dotyka otworu” — tu dotyka go strych, przedłużenie spocznika).
3. **Lina `rope_planetarium` dalej niż 15 m od każdej podłogi, na której strażnik może stanąć przy zamkniętej linie** — liczone ostro, z pominięciem ścian (W7 mierzy od najbliższej podłogi). Rotunda ma tylko 19,5 × 23 m i sąsiaduje z biblioteką, salą zegarów i Salą Koreańską (Azja), więc lina **wisi wysoko**: `RopeLock` (bloczek 6 m nad początkiem, ciężarek 3 m niżej) stoi na **wsporniku pod kopułą (y 14)** w rogu NE rotundy (znacznik `planetarium_counterweight`, `GateSpec.marker`) — lina na wysokości 17…20 m. Strzał czysty z **galerii obserwatorów** (balkon w rotundzie na y ≈ 10,17, wejście z wieży dachowej), z odległości ≥ 19 m; z podłogi biblioteki widać ją przez kratę (też da się trafić, ale między prętami). Pistolet nie sięga z żadnego miejsca (test geometryczny po wszystkich podłogach poza obszarem `planetarium`).
4. **Sekrety za bramami strefy** (ustalenie po W3): CHAIN/BOARDS/CRACKED/ROPE/HOOK, id z prefiksem strefy, znacznik `secret_<strefa>_<n>` w środku.
5. **Skrzydło SWING otwiera się do pokoju B i leży wzdłuż ościeżnicy** — wolne pasy przy drzwiach: Azja → rotunda (x ≈ 52, z −38…−35), podziemia → magazyn (z ≈ 28, x 31…32), dach → strych (z ≈ −12, x 31…31,5), herbaciarnia, gabinet bibliotekarza.
6. **Nic tylko przez przystań** (podłoga przystani to osobny region nawigacji): obie przystanie są ślepymi zaułkami.
7. **Areny:** drzwi aren to znaczniki `arena_<id>_door_<n>` (W1: najbliższe `Door` bez bramy do 3 m, inaczej krata spada w otwór). Herbaciarnia jest drzwiami areny Generała (zamknięta na czas walki — przystań nie może być kryjówką), kapliczka z liną też.
8. **Księżyc:** `LightSpec.MOON` (`Hub.MOON_GROUP`) — świetliki biblioteki, okulus rotundy, ogród.
9. **Nazwy sal a dźwięk:** `enlightenment_clocks` (słowo `clock`), `asia_garden`, `asia_garden_shrine`, `asia_teahouse` (słowa `garden`, `tea`).

---

## OŚWIECENIE

Strefa: x 31…65, z −38…34, y −6,5…32. Przejścia po mojej stronie: dziedziniec x 30…31, z −3…3 (h 7); podziemia x 30…31, z 28…30, **y −6** (zasuwa od Oświecenia); dach x 30…31, z −12…−10,5, **y 22,5** (zasuwa od Oświecenia); Azja z −39…−38, x 48…52 (h 3, zasuwa od Azji, obszar `planetarium`).

### Plan parteru (y = 0; północ u góry)

```
x: 31          38          45 45.5     52.5 53                     65
z-38 ┌───────── (pas 1,5 m) ─────────┐ ┌──────[AZJA x48..52, zasuwa]────────┐
z-36 ├════ galeria N (y4) ══════════╡ │ ROTUNDA PLANETARIUM 19,5×23, h22     │
     ║  bieg N 0→4 (oś, x36,5..39,5)║ │  (obszar planetarium, arena)         │
     ║  ▲  z -33..-22               ║ │          ☼ okulus (księżyc)          │
z-29 ║                         ┃kra-┃═│▓ ORRERY ~10 m (guardian, x55,25)     ▐ wspornik
     ║                         ┃ta  ┃ │   pierścień wolnej posadzki r ≤ 9    ▐ y14 + LINA
z-24 ║  ▒ gabloty w osi ▒      ┃liny┃ │                                      │ (y 17..20)
z-18 ║                              ║ │ [galeria obserwatorów y10,17]         │
z-15 ║                              ║ └────────────────────────────────────────┘
z-14.5║  BIBLIOTEKA KRÓLEWSKA       ║ ┌─ARCHIWUM─┐ ┌──────────────────────┐
     ║  14×70, h10                  ║ │(sekret,  │=│ SALA ZEGARÓW          │
     ║  galeria regałów y4          ║ │ lina)    │ │ I AUTOMATÓW 12×12,5   │
z-9  ║  dookoła (3 m)               ║ ├──────────┤ │ h7                    │
     ║                         ┌────╢=│GABINET   │ │                       │
z-2.5║  ◎ globusy  ☾             │    ║ │BIBLIOT.  │ └────────[łuk]──────────┘
 DZIEDZINIEC ═► skrzyżowanie z -3..3 ═│(przystań)│ ┌────────────────────────────┐
z 0  ║  (drzwi 6×7, mostek galerii) ════════════════► GABINET HISTORII          │
z 1.5║                              ║ └──────────┘ │ NATURALNEJ 19,5×15,5, h7  ═ SZTUCER
     ║  ▒ gabloty w osi ▒           ║              │ dioramy wilków i raptorów  │ (x63,9, z0)
z14  ║                              ║ ┌────────────┴────[łuk]──────────────────┐
z16  ║                         ═════╬═│ GALERIA PORTRETÓW KOLEKCJONERÓW (L) h7  │
z21  ║  bieg S 0→4 (oś)             ║ ├──────────┐                            │
     ║  ▼  z 20..31                 ║ │SCHODY    │= (y0)                      │
     ║                              ║ │SŁUŻB.    │                            │
z31  ╞════ galeria S (y4) ══════════╡ │-6..0     │                            │
z34  └──────────────────────────────┘ └──────────┴────────────────────────────┘
```

### Piony

```
y 22,5  STRYCH BIBLIOTEKI x31..45, z-14,5..-10 ──► zasuwa na DACH (x30..31, z-12..-10,5)
           ▲ łuk (x45..45,5)
        WIEŻA DACHOWA x45,5..52,5, z-14,5..-2: 6 biegów 4 → 22,5, spoczniki N: 10,17 · 16,33 · 22,5
y 10,17    ├─ łuk w ścianie N (x46..48) ─► GALERIA OBSERWATORÓW (balkon w rotundzie, x45,5..52,5, z-18..-15)
y 4        ◄─ łuk z galerii regałów (x45..45,5, z-14,25..-12,5)
        (pod wieżą: archiwum + gabinet bibliotekarza, h ≤ 3,5)
y 4     GALERIA REGAŁÓW: pierścień W/E (3 m) + galerie N/S nad końcami; dwa biegi w osi (N i S) → pętla
        BIBLIOTEKA ↔ galeria; ukryty GABINET SLOANE'A (y4, x45,5..50,5, z21,5..33,5, hak) nad schodami służbowymi
y -6    MAGAZYN ZAMKNIĘTY x31..45, z25..33,5 (pod południowym końcem biblioteki) ◄─ zasuwa z podziemi (x30..31, z28..30)
        ├─ INTROLIGATORNIA (sekret, deski) x31..38, z17..24,5
        └─ schody służbowe x45,5..50,5, z21,5..33,5 (2 biegi) ─► galeria portretów (y0)
```

**Odsłony:** (1) drzwi dziedzińca → niski przesmyk pod mostkiem galerii (3,6 m) → biblioteka otwiera się 35 m w obie strony, snop księżyca na skrzyżowaniu, a na wprost przez łuk gabinetu **sztucer w ciepłym reflektorze** (34 m, oś z = 0); (2) z galerii obserwatorów pierwszy widok z góry na Orrery w snopie z okulusa i ciężarek liny pod kopułą. **Pętle:** biblioteka ↔ gabinet ↔ portrety ↔ biblioteka (parter), posadzka ↔ galeria regałów (dwa biegi), galeria → wieża → obserwatorzy/strych → z powrotem; podziemia → magazyn → schody → portrety → biblioteka.

### Sale Oświecenia

| Id | Prostokąt(y) | y | Nazwa (klucz) | Publ. | Uwagi |
|---|---|---|---|---|---|
| `enlightenment_library` | 31, −36 → 45, 34 | 0…10 | `ROOM_ENLIGHTENMENT_LIBRARY` | tak | 14 × 70; 5 świetlików w osi |
| `enlightenment_library_gallery` | W 31, −36 → 34, 34; E 42, −36 → 45, 34; N 34, −36 → 42, −33; S 34, 31 → 42, 34 | 4…10 | `ROOM_ENLIGHTENMENT_GALLERY` | tak | `carved = false`, płyty `balcony` |
| `enlightenment_planetarium` | 45,5, −38 → 65, −15 | 0…22 | `ROOM_ENLIGHTENMENT_PLANETARIUM` | tak | obszar `planetarium`; okulus |
| `enlightenment_observatory` | 45,5, −18 → 52,5, −15 | 10,17…22 | `ROOM_ENLIGHTENMENT_OBSERVATORY` | tak | `carved = false` w rotundzie |
| `enlightenment_roof_stairs` | 45,5, −14,5 → 52,5, −2 | 4…25,5 | `ROOM_SERVICE_STAIRS` | nie | `Grey.tower`, 6 biegów |
| `enlightenment_attic` | 31, −14,5 → 45, −10 | 22,5…25,5 | `ROOM_ENLIGHTENMENT_ATTIC` | nie | nad biblioteką |
| `enlightenment_archive` | 45,5, −14,5 → 52,5, −9,5 | 0…3 | `ROOM_ENLIGHTENMENT_ARCHIVE` | nie, sekret | lina z sali zegarów |
| `enlightenment_librarian` | 45,5, −9 → 52,5, −2,5 | 0…3,5 | `ROOM_ENLIGHTENMENT_LIBRARIAN` | nie | przystań `librarian` |
| `enlightenment_clocks` | 53, −14,5 → 65, −2 | 0…7 | `ROOM_ENLIGHTENMENT_CLOCKS` | tak | |
| `enlightenment_cabinet` | 45,5, −1,5 → 65, 14 | 0…7 | `ROOM_ENLIGHTENMENT_CABINET` | tak | sztucer |
| `enlightenment_portraits` | 45,5, 14,5 → 65, 21 + 51, 21 → 65, 34 | 0…7 | `ROOM_ENLIGHTENMENT_PORTRAITS` | tak | portrety |
| `enlightenment_service_stairs` | 45,5, 21,5 → 50,5, 33,5 | −6…3 | `ROOM_SERVICE_STAIRS` | nie | `Grey.tower`, 2 biegi |
| `enlightenment_study` | 45,5, 21,5 → 50,5, 33,5 | 4…7,5 | `ROOM_ENLIGHTENMENT_STUDY` | nie, sekret | hak z galerii regałów |
| `enlightenment_stacks` | 31, 25 → 45, 33,5 | −6…−2,5 | `ROOM_ENLIGHTENMENT_STACKS` | nie | przejście do podziemi |
| `enlightenment_bindery` | 31, 17 → 38, 24,5 | −6…−3 | `ROOM_ENLIGHTENMENT_BINDERY` | nie, sekret | deski |

### Otwory Oświecenia

| Id | Prostokąt | y | Pokoje (A → B) | Styl / brama |
|---|---|---|---|---|
| `enlightenment_library_cabinet` | 45, −1,25 → 45,5, 1,25 | 0…3,5 | biblioteka → gabinet | łuk (oś sztucera) |
| `enlightenment_library_portraits` | 45, 16 → 45,5, 19,5 | 0…3,5 | biblioteka → portrety | łuk |
| `enlightenment_library_librarian` | 45, −6,5 → 45,5, −4,5 | 0…2,6 | biblioteka → przystań | SWING |
| `enlightenment_planetarium_door` | 45, −29 → 45,5, −24 | 0…3,5 | biblioteka → rotunda | GATE + `rope_planetarium` (ROPE, `rifle_hunt`, znacznik `planetarium_counterweight`) |
| `enlightenment_gallery_tower` | 45, −14,25 → 45,5, −12,5 | 4…6,6 | galeria regałów → wieża | łuk |
| `enlightenment_tower_observatory` | 46, −15 → 48, −14,5 | 10,17…12,77 | wieża → obserwatorzy | łuk |
| `enlightenment_tower_attic` | 45, −14,25 → 45,5, −12,5 | 22,5…25 | wieża → strych | łuk |
| `enlightenment_cabinet_clocks` | 57, −2 → 60, −1,5 | 0…4 | gabinet → zegary | łuk |
| `enlightenment_cabinet_portraits` | 57, 14 → 61, 14,5 | 0…4 | gabinet → portrety | łuk |
| `enlightenment_stairs_portraits` | 50,5, 31,75 → 51, 33,25 | 0…2,6 | schody → portrety | SWING |
| `enlightenment_stairs_stacks` | 45, 31,75 → 45,5, 33,25 | −6…−3,4 | schody → magazyn | SWING |
| `enlightenment_clocks_archive` | 52,5, −12,5 → 53, −10,5 | 0…2,6 | zegary → archiwum | GATE + `enlightenment_rope_archive` (ROPE, `precise`) |
| `enlightenment_stacks_bindery` | 33, 24,5 → 35,5, 25 | −6…−3,6 | magazyn → introligatornia | DOUBLE_SWING + `enlightenment_boards_bindery` (BOARDS, `heavy`) |
| `enlightenment_gallery_study` | 45, 26,5 → 45,5, 28,5 | 4…6,4 | galeria regałów → gabinet Sloane'a | GATE + `enlightenment_hook_study` (HOOK, `harpoon`) |

Wszystkie drzwi parteru w ścianach biblioteki mają ≤ 3,5 m (pod płytą galerii regałów, spód 3,6). Biegi do galerii: x 36,5…39,5, z −33…−22 (na północ) i z 20…31 (na południe), 0 → 4 m na 11 m (0,364).

### Znaczniki Oświecenia

| Znacznik | Gdzie | Pokój |
|---|---|---|
| `weapon_rifle_hunt` | stół przed stojakiem (63,9, 0,9, 0), przód na −x | gabinet |
| `guardian_planetarium` | (55,25, 0, −26,5), przód na −x (krata) | rotunda |
| `arena_planetarium_start` | (48,5, 0, −26,5) | rotunda |
| `arena_planetarium_door_1` / `_2` | krata liny (46, 0, −26,5) / drzwi Azji (50, 0, −37) | rotunda |
| `arena_planetarium_supply_1…3` | rogi SW, SE, NE | rotunda |
| `planetarium_counterweight` | wspornik (63,5, 14, −34), przód ku obserwatorom | rotunda |
| `note_enlightenment_1…4` | biurko bibliotekarza, stół sztucera, dziennik obserwatorów, introligatornia | |
| `secret_enlightenment_1…3` | archiwum, introligatornia, gabinet Sloane'a | sekrety |
| `chess_6` | skrzynia na strychu przy drzwiach na dach | strych |
| `cctv_enlightenment_1` / `_2` | biblioteka (koniec S, wzdłuż osi) / gabinet (na sztucer) | |
| `portrait_enlightenment_1…8` | ściany galerii portretów (y 2,1) | portrety |
| `museum_map_librarian`, terminal `librarian` | przystań | |

### Spotkania Oświecenia

Rodzaje: księgi `[wax, books]`, wilk `[wolf]`, raptor `[raptor]`, automat (zegary) `[wax]`; portrety na znacznikach `portrait_*` (reżyser).

| Sala | Zawsze (`ALWAYS_SET`) | Zestawy 0…2 | Patrol / zasadzka |
|---|---|---|---|
| biblioteka (980 m²) | — | 0: 6 ksiąg + 1 piechur; 1: 5 ksiąg + wilk + piechur; 2: 5 ksiąg + raptor + piechur | `enlightenment_library_aisle` (wschodnia nawa); zasadzka `enlightenment_reading` (zestaw 2, skrzyżowanie) |
| galeria regałów (468 m²) | — | 0: 3 księgi; 1: 2 księgi + piechur; 2: 3 księgi | `enlightenment_gallery_round` (zachodnia galeria) |
| gabinet | wilk + raptor na dioramach | 0: księga; 1: wilk | zasadzka `enlightenment_rifle` przy podniesieniu sztucera |
| zegary | automat-pisarz | 0: automat; 1: księga | zasadzka `enlightenment_clockwork` (środek sali) |
| portrety | — | 0: 2 księgi + wilk; 1: 3 księgi; 2: księga + raptor | — |
| magazyn | — | 0: księga; 1: wilk | — |
| sekrety ×3 | po jednym legowisku | — | zasadzki obszarowe |
| rotunda, obserwatorzy, wieże, strych, przystań | — | — | (rotunda: strażnik) |

### Światło Oświecenia (§10.1: ciepłe lampki, długie cienie regałów)

Biblioteka: lampy wiszące w osi (ciepłe), zielone lampki na gablotach, kinkiety na galerii regałów, dwa nisko ustawione reflektory z cieniem wzdłuż naw (długie cienie regałów), 5 snopów księżyca ze świetlików (`MOON`), czerwone lampy przy drzwiach dziedzińca i kracie. Gabinet: ciepłe lampy + reflektor z cieniem na sztucer. Zegary: ciepłe lampy, cień wahadła. Portrety: małe reflektory nad obrazami. Rotunda: snop księżyca z okulusa na Orrery, mosiężne kinkiety w pierścieniu, reflektor na ciężarek liny, czerwone przy obu drzwiach. Wieża, magazyn, schody: świetlówki. Przystań: `haven_lights`.

---

## AZJA

Strefa: x 4…56, z −86…−39, y −6,5…32. Przejścia po mojej stronie (wszystkie w ścianie z = −39): korytarz północny x 14…20 (h 5, żaluzja zasilania), podziemia x 24…26, **y −6** (zasuwa od Azji), Planetarium x 48…52 (h 3, zasuwa od Azji).

### Plan parteru (y = 0)

```
x: 4        12.5      24 24.5  30 30.5                    50 50.5   56
z-86 ┌────────┬─────────────┬──────┐ ┌───────────────────────┬────────┐
     │HERBA-  │             │KAPLI-│ │                       │SKARBIEC│
     │CIARNIA │             │CZKA  │ │  SALA ZBROI            │ZBROJ-  │
     │(przyst)│  OGRÓD JAPOŃSKI    │ │  (rzędy stojaków,       │MISTRZA │
z-78 └───╥────┘  (arena Generała,  │ │   ashigaru)            │(łańcuch│
         ║       żwir, kamienie,   └─┤                       ╞═ sekret)
         ║       latarnie, wiśnia, ┊ │                       ├────────┤ z-77
         ║       otwarty dach ☾)   ┊ │                       │        │
z-62.5 └─[SPĘKANY MUR x6..10]──────┘ └──[łuk]───────[łuk]────┴────────┘
z-62 ┌──────────────────────┐ ┌──────────────┐ ┌─────────────────────────┐
     │ SALA CHIN            │═│ PORCELANA (L) │═│ SALA KOREAŃSKA           │
     │ ▓ BUDDA (x13,5) ▓    │ └──┬──────┐     │ │                         │
     │ ○ kolumny  ○         │    │SCHODY│     │═│  ▣ OGNISTA SKRZYNIA      │
z-53 │  kadzielnica         │    │-6..0 │PORC.│ │    (46,5, z-51)          │
     │                      │    │      │     │ │                         │
     │  lew Fu   lwica Fu   │    │      ╞═════│ │                         │
z-39.5└────[ŻALUZJA x14..20]─┘    └[pod.]┘─────┘ └──────[ZASUWA x48..52]────┘
           ▲ korytarz północny     y-6: x24..26        ▼ Rotunda Planetarium
                                   (pod Salą Chin: SKŁAD SKRZYŃ, sekret, spękany mur)
```

**Odsłony:** (1) żaluzja się zwija → Sala Chin, wielki Budda w złotym reflektorze patrzy na wejście, czerwone kolumny, lampiony; w ścianie obok Buddy **rysy, przez które sączy się księżyc** (zapowiedź ogrodu); (2) po salwie ognistej skrzyni mur pęka → ogród pod księżycem, wiśnia, żwir, Generał na środku. **Pętla:** Chiny → porcelana → Korea → zbroje → porcelana (ramię N) → Chiny; skrót Korea → rotunda (zasuwa) i Azja → podziemia (zasuwa u stóp schodów).

### Sale Azji

| Id | Prostokąt(y) | y | Nazwa | Publ. | Uwagi |
|---|---|---|---|---|---|
| `asia_china` | 4, −62 → 23, −39,5 | 0…12 | `ROOM_ASIA_CHINA` | tak | wejście, Budda |
| `asia_service_stairs` | 23,5, −53 → 28,5, −39 | −6…3 | `ROOM_SERVICE_STAIRS` | nie | `Grey.tower`, 2 biegi |
| `asia_crate_store` | 15, −52 → 23, −40 | −6…−3 | `ROOM_ASIA_CRATES` | nie, sekret | spękany mur |
| `asia_porcelain` | 23,5, −62 → 36,5, −53,5 + 29, −53,5 → 36,5, −39,5 | 0…6 | `ROOM_ASIA_PORCELAIN` | tak | kruche gabloty |
| `asia_korea` | 37, −62 → 56, −39,5 | 0…8 | `ROOM_ASIA_KOREA` | tak | ognista skrzynia, zasuwa |
| `asia_armor` | 30,5, −86 → 50, −62,5 + 50, −76,5 → 56, −62,5 | 0…8 | `ROOM_ASIA_ARMOR` | tak | |
| `asia_armory_vault` | 50,5, −86 → 56, −77 | 0…4 | `ROOM_ASIA_VAULT` | nie, sekret | łańcuch |
| `asia_garden` | 12,5, −86 → 24, −62,5 + 4, −77,5 → 12,5, −62,5 + 24, −80 → 30, −62,5 | 0…14 | `ROOM_ASIA_GARDEN` | tak | obszar `asia_garden`; arena; wielkie świetliki |
| `asia_teahouse` | 4, −86 → 12, −78 | 0…3,5 | `ROOM_ASIA_TEAHOUSE` | nie | przystań `teahouse`, obszar `asia_garden` |
| `asia_garden_shrine` | 24,5, −86 → 30, −80,5 | 0…4 | `ROOM_ASIA_SHRINE` | nie, sekret | lina; obszar `asia_garden` |

### Otwory Azji

| Id | Prostokąt | y | Pokoje (A → B) | Styl / brama |
|---|---|---|---|---|
| `asia_china_porcelain` | 23, −60 → 23,5, −56 | 0…4 | Chiny → porcelana | łuk |
| `asia_garden_wall` | 6, −62,5 → 10, −62 | 0…4 | Chiny → ogród | PANEL + `cracked_garden` (CRACKED, `explosive`) |
| `asia_stairs_porcelain` | 28,5, −41,75 → 29, −39,75 | 0…2,6 | schody → porcelana | SWING |
| `asia_stairs_crates` | 23, −48 → 23,5, −46 | −6…−3,6 | schody → skład | PANEL + `asia_cracked_crates` (CRACKED, `explosive`) |
| `asia_porcelain_korea` | 36,5, −50 → 37, −46 | 0…4 | porcelana → Korea | łuk |
| `asia_porcelain_armor` | 31, −62,5 → 35, −62 | 0…4 | porcelana → zbroje | łuk |
| `asia_korea_armor` | 44, −62,5 → 48, −62 | 0…4 | Korea → zbroje | łuk |
| `asia_armor_vault` | 50, −82 → 50,5, −80 | 0…2,4 | zbroje → skarbiec | DOUBLE_SWING + `asia_chain_vault` (CHAIN, `heavy`) |
| `asia_garden_teahouse` | 12, −83 → 12,5, −81 | 0…2,6 | ogród → herbaciarnia | SWING |
| `asia_garden_shrine_door` | 24, −84 → 24,5, −82 | 0…2,6 | ogród → kapliczka | GATE + `asia_rope_shrine` (ROPE, `precise`) |

### Znaczniki Azji

`weapon_hwacha` (46,5, 0,9, −51) na wózku, przód na −x; `guardian_general` (17,5, 0, −75); `arena_general_start` (8, 0, −65,5); `arena_general_door_1` (spękany mur, 8, 0, −63), `_door_2` (herbaciarnia, 13, 0, −82), `_door_3` (kapliczka, 23,5, 0, −83); `arena_general_supply_1…3`; `note_asia_1…4` (wózek ognistej skrzyni, herbaciarnia, skarbiec, skład); `secret_asia_1…3` (skarbiec, skład, kapliczka); `chess_7` (stoliczek ofiarny za Buddą); `cctv_asia_1` (Chiny), `cctv_asia_2` (Korea); `museum_map_teahouse`, terminal `teahouse`.

### Spotkania Azji

Rodzaje: pies Fu `[wolf, fu_dog]` (parami: lew i lwica), zbroja `[knight, samurai_armor]`.

| Sala | Zawsze | Zestawy | Patrol / zasadzka |
|---|---|---|---|
| Chiny (427 m²) | — | 0: para psów przy wejściu + zbroja; 1: para psów przy Buddzie + 2 zbroje; 2: zbroja-piechur + 2 psy | `asia_china_round` (wokół kadzielnicy); zasadzka `asia_buddha` (zestaw 1, podejście do Buddy) |
| porcelana | — | 0: zbroja + pies; 1: 2 zbroje | — |
| Korea | 2 psy + zbroja przy wózku | 0: zbroja-piechur; 1: pies | zasadzka `asia_hwacha` przy podniesieniu ognistej skrzyni |
| zbroje (542 m²) | 2 zbroje przy skarbcu | 0: 2 zbroje + piechur; 1: 2 psy + zbroja; 2: 3 zbroje | `asia_armor_rows`; zasadzka `asia_armor_guard` |
| sekrety ×3 | legowiska | — | zasadzki obszarowe |
| ogród, herbaciarnia, schody | — | — | (ogród: Generał) |

### Światło Azji (§10.1: lampiony + księżyc w ogrodzie)

Lampiony (ciepłe pomarańczowe) w każdej sali, złoty reflektor z cieniem na Buddę, reflektor na ognistą skrzynię, czerwone lampy awaryjne; ogród: trzy snopy księżyca (`MOON`) przez otwarty dach (świetliki) + kamienne latarnie (ciepłe, słabe); herbaciarnia `haven_lights`; schody: świetlówki.

---

## Zadania

### Zadanie 1: plan (ten dokument)
- [x] Zapis i commit `W5a plan: Enlightenment and Asia`.

### Zadanie 2: testy danych (najpierw czerwone)
**Plik:** `tests/unit/test_floor1_east.gd` (każdy test na `Floor1Layout.create()`):
- [x] `test_east_rooms_lie_in_their_zones_with_names` — prefiks strefy, `Floor1Plan.contains`, siatka 0,5 m, przetłumaczony `name_key`, `public = false` dla służbowych/sekretów/przystani, obszary `planetarium` / `asia_garden`, słowa `clock`/`garden`;
- [x] `test_rooms_keep_apart_and_nested_rooms_stand_in_their_hosts`;
- [x] `test_key_rooms_have_their_sizes` — biblioteka 14 × 70 × h 10, galeria y 4, rotunda ≥ 19 × 22 i h ≥ 20, wieża 4 → 22,5, strych 22,5, Sala Chin h ≥ 10, ogród ≥ 400 m² z dachem w świetlikach ≥ 30%;
- [x] `test_junction_rooms_cover_their_doorways`, `test_internal_doorways_join_their_rooms`;
- [x] `test_internal_gates` — `rope_planetarium`, `cracked_garden` (rodzaj, wymaganie, otwór, obszary, znacznik liny w rotundzie);
- [x] `test_the_rope_hangs_out_of_pistol_reach_and_in_rifle_sight` — od odcinka liny do każdej podłogi/płyty/biegu poza obszarem `planetarium` > 16 m (oko 1,6 m); linia z galerii obserwatorów do liny przez wolną przestrzeń bez elementów;
- [x] `test_secret_rooms_sit_behind_zone_gates` (6), `test_three_secrets_three_or_four_notes_and_a_chess_piece_per_wing`;
- [x] `test_markers_lie_in_their_rooms`;
- [x] `test_every_room_with_exhibits_has_two_sets_and_a_sane_density`, `test_slots_and_loot_stand_on_free_floor`;
- [x] `test_patrols_and_ambushes`, `test_stairs_never_steeper_than_the_plan`;
- [x] `test_the_rifle_lies_on_the_main_path_in_plain_view` (graf bez bram + linia wzroku od drzwi dziedzińca), `test_gates_hold_the_planetarium_and_the_garden` (graf);
- [x] `test_havens_are_dead_ends_and_nothing_lies_behind_them`, `test_lights_follow_the_wing_recipes`.
- [x] `--filter=floor1_east` → czerwone.

### Zadanie 3: Oświecenie — bryły, otwory, bramy, wieże, przystań
**Pliki:** `zones/enlightenment.gd`, `zones/east_kit.gd`, `locale/strings.csv`.
- [x] Sale, galeria regałów (płyty, słupy, balustrady, biegi), wieże, strych, otwory, `rope_planetarium` ze znacznikiem, sekrety, `haven_spots[&"librarian"]`.
- [x] `--filter=floor1` → testy brył/przejść Oświecenia zielone; `test_floor1_layout` zielony → commit.

### Zadanie 4: Oświecenie — wnętrza, światło, znaczniki, spotkania, łup
- [x] Regały, gabloty, globusy, dioramy, stojak sztucera, zegary, portrety, Orrery-przestrzeń, światło, znaczniki, sloty, patrole, zasadzki, łup → commit.

### Zadanie 5: Azja — bryły, otwory, bramy, schody, przystań
- [x] Sale, otwory, `cracked_garden`, sekrety, `haven_spots[&"teahouse"]` → commit.

### Zadanie 6: Azja — wnętrza, światło, znaczniki, spotkania, łup
- [x] Budda, kolumny, gabloty porcelany, wózek ognistej skrzyni, stojaki zbroi, ogród (żwir, kamienie, latarnie, wiśnia, staw), herbaciarnia, światło, znaczniki, sloty → `--filter=floor1_east` zielone → commit.

### Zadanie 7: test na zbudowanym piętrze
**Plik:** `tests/integration/test_floor1_east_walk.gd`:
- [x] wszystkie bramy otwarte: z każdego przejścia obu skrzydeł do każdej sali (poza przystaniami), galeria ↔ posadzka oboma biegami, wieża y 4 ↔ obserwatorzy ↔ strych ↔ drzwi na dach, schody służbowe y −6 ↔ 0;
- [x] sloty i łup na siatce i w wolnej przestrzeni (kapsuła 0,42 × 2), odcinki patroli proste;
- [x] noc 1 (bramy zamknięte): promień fizyczny z drzwi dziedzińca do sztucera, droga z dziedzińca do stołu, rotunda odcięta, galeria obserwatorów dostępna, promień z niej do liny wolny; ogród i sekrety Azji odcięte od Sali Chin;
- [x] otwarcie samej liny wpuszcza do rotundy; otwarcie samego muru — do ogrodu.
- [x] `--filter=floor1_east_walk`, `--filter=museum_floor` zielone → commit.

### Zadanie 8: całość
- [x] pełny `bash tools/run_tests.sh` zielony; „jak zbudowano” w tym pliku; commit; raport (≤ 40 linii).

---

## Prośby do kontrolera (do potwierdzenia w raporcie)

1. `rope_planetarium` ma `GateSpec.marker = &"planetarium_counterweight"` (wspornik pod kopułą, y 14): `GateController.lock_frame` stawia tam `RopeLock` (bez przesunięcia `ROPE_LEAD`). Krata w otworze jest drzwiami bramy. W7: odległość liny liczyć od znacznika (+3…6 m), nie od otworu.
2. Wieża dachowa Oświecenia zaczyna się na galerii regałów (y 4), a do otworu `j_roof_enlightenment` dochodzi strych biblioteki (y 22,5) — spocznik + strych zamiast wieży przy samym murze.
3. Galeria obserwatorów (obszar `enlightenment`) wisi w rotundzie (obszar `planetarium`) jak balkon dziedzińca; strzał w uśpione Planetarium z galerii budzi je, ale strażnik poza areną → reset po smyczy (W1) — bez sera.
4. Herbaciarnia i kapliczka to drzwi areny Generała (`arena_general_door_2/3`) — zamknięte na czas walki.

---

## Jak zbudowano (3.10) — odstępstwa od planu wyżej

| Co | Zmiana | Dlaczego |
|---|---|---|
| Sala Chin, Sala Koreańska | sięgają do z = −39 (nie −39,5) | pokój przejścia musi przylegać do otworu w murze stref (−39…−38); porcelana zostaje przy −39,5 |
| Biurko w galerii obserwatorów | przy ścianie zachodniej (x 45,6…46,2, z −17,6…−16,4), obrót o 90° | w pierwszej wersji stało w świetle łuku z wieży |
| Trasa piechura w Sali Zbroi | (32,5, −79,5) → (48,5, −77) → (48,5, −68,5) → (32,5, −68,5) | ominięcie wysp ze stojakami |
| Test chodzenia | punkty za przejściem liczone 1 m nad podłogą i opuszczone (jak w `test_museum_floor_level`) | na wysokości podłogi dachu (22,5) `Floor1Plan.zone_at` przypisuje punkt dziedzińcowi (wcześniejsza strefa na liście) |
| Znaczniki drzwi aren | w samym otworze (0,25 m w głąb areny), −Z w głąb areny, X w poprzek otworu | `GuardianKeeper` stawia kratę na transformacji znacznika (test pilnuje kierunku) |
| Znaczniki strażników | `guardian_planetarium` / `arena_planetarium_*`, `guardian_general` / `arena_general_*` | poprawka kontrolera: id strażników z `Floor1Plan` |
| Księżyc | `LightSpec.MOON` (`Hub.MOON_GROUP`) | grupa scalona przez W1 do `pietro-1` przed budową |

**Lina Planetarium (sprawdzone testem):** najbliższe miejsce, w którym strażnik może stanąć poza rotundą (podłoga, płyta, spocznik, bieg — ściany pominięte), jest od liny dalej niż 16 m; galeria obserwatorów widzi ją przez wolne powietrze z ok. 19 m (promień fizyczny na zbudowanym piętrze bez trafienia).

**Wyniki:** Oświecenie 15 sal (z galerią regałów, galerią obserwatorów, dwiema wieżami schodów, strychem, magazynem i 3 sekretami), Azja 10 sal (z 3 sekretami); `test_floor1_east` 18/18, `test_floor1_east_walk` 4/4, wszystkie testy `floor1` 147/147. Najbliższe miejsce do liny Planetarium poza rotundą: Sala Koreańska (55,75, 0, −39,25), 18,0 m od liny. Całe piętro po W5a (pomiar `test_museum_floor_level`): 85 sal, 100 otworów, 626 elementów, 276 slotów, 132 łupy, 39 bram, 30 biegów; rzeźbienie ≈ 3,1 s, budowa ≈ 3,0 s, wypiekanie ≈ 0,25 s (3343 wielokąty).
