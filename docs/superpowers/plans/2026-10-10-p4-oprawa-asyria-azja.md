# P4 — oprawa skrzydeł: Asyria i Azja

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (zadania po kolei, commit po każdym). Kroki mają pola `- [ ]`.

**Cel:** greybox stref `assyria` i `asia` Piętra I dostaje gotową grafikę, światło i atmosferę **dokładnie tym sposobem i w tej jakości co P2/P3** (hub + Egipt: `2026-10-03-p2-oprawa-hol-egipt.md`; Grecja + Oświecenie: `2026-10-03-p3-oprawa-grecja-oswiecenie.md`). Asyria: **szary alabaster, brąz, cedr** — płyty z reliefami od podłogi do 3 m, malowany fryz, cedrowe belki, Brama Chorsabadu z parą lamassu, Czarny Obelisk na końcu osi, dziedziniec Lamassu w księżycu z krenelażem na niebie; światło **niskie, ostre, czerwone pochodnie** kontra zimny księżyc — ale **nie za ciemno** (playtest właściciela 3.10: „część sal na parterze zdecydowanie za ciemna”). Azja: **czerwony lak, brąz z patyną, porcelana, papierowe lampiony** — wielki Budda w złotym snopie, słupy lakowe, lampiony na sznurach, dzwonnica w Sali Koreańskiej, zbroje na stojakach za świecącymi shoji, ogród japoński pod otwartym dachem (żwir, głazy, kamienne latarnie, staw, kwitnąca wiśnia, elewacje herbaciarni) z Generałem na okapie. Budżet: ≥ 90 kl./s 1080p High na RTX 2080 Ti w najcięższym widoku (§11.3), noc startuje ≤ 10 s.

**Architektura (jak P3):** kolizje i nawigacja zostają z greyboksa (wyjątki jawne w §2, pkt „Greybox”). Wygląd: `LevelArt`/`ArtKit` (pola, pasy, stropy — style sal `assyria_*` i `asia_*` **już są** w `ArtKit.ROOMS`, z zestawów `2026-10-02-art-asyria.md` i `2026-10-03-art-azja.md`) + nowe moduły skrzydeł **`Floor1ArtAssyria`** (`src/style/floor1_art_assyria.gd`) i **`Floor1ArtAsia`** (`src/style/floor1_art_asia.gd`) — czyste fabryki drzew `Node3D` z modeli `ArtLibrary`, bez kolizji; `Floor1Art` deleguje po prefiksie id sali (`piece_look`, `fixture`, `dress`, `portals`, `gate_leaf`, `disguised_gates`, `extra_lights`). Światło: wpisy sal w `Floor1LightRecipe` (mgła, sondy, budżet cieni, zanik, **`lamp_energy` ≥ 1,2** w obu skrzydłach), oprawy (`asy_torch`, `asy_brazier`, `asia_lantern_floor`), światła dodatkowe (pochodnie bramy, trójnogi, zimne wypełnienia, papier za shoji), cząsteczki (kurz, **iskry/żar** nad trójnogami, **płatki wiśni** w ogrodzie). Przycinanie grafem, okludery i presety — bez zmian (obejmują nowe sale same).

**Technologia:** Godot 4.7.2 (Forward+), GDScript ze statycznym typowaniem, tabulatory, angielskie identyfikatory; testy `bash tools/run_tests.sh --filter=…` bez okna; wycieczka tylko `bash tools/run_tour.sh dry`; **żadnych okien, dźwięku, push**; Blender najwyżej jeden proces `-b` (tu niepotrzebny: wszystkie modele są). Pomiar modeli bez okna: skrypt sondujący (`godot --headless -s`) — rozmiary i znaczniki w §3/§4 pochodzą z niego.

**Wejście (wiążące):** projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.2, §5.5, §10.1; katalogi `docs/art/kit-pietro1-asyria.md` (§4–6, §12), `docs/art/kit-pietro1-azja.md` (§2–6, §11); greybox `src/level/floor1/zones/{assyria,asia}.gd`; wzorzec P3: `Floor1ArtGreece`, `Floor1ArtEnlightenment`, `Floor1LightRecipe`, `test_floor1_art_wings.gd`, `tour_scenario.gd`. **Strażnicy (scaleni, muszą działać):** Lamassu (`guardians/lamassu.gd`: cokół `LamassuPlinth` z `dress_arena()` na `guardian_lamassu`, osłony `lamassu_cover_<n>` = cokoły geniuszy i cedry — ich bryły co do milimetra, płyty `lamassu_relief_<n>` fazy 2) i Generał (`guardians/general.gd`: grzęda `general_perch`/`arena_general_perch` na okapie greyboksu; **`_search_roof_perch()` bierze pierwszy węzeł `roof_perch` w poziomie w promieniu 16 m od posta**; `PetalStorm.emitters_for()` bierze węzły `Petals_*` w promieniu 14 m). Testy `--filter=lamassu,general,guardian` budują **greybox** (runner ustawia `dress_default = false`) — oprawa nie może zmienić areny inaczej niż jawnie niżej.

---

## 1. Ograniczenia i zasady (jak P3 §1)

- **Kolizja = greybox.** Żaden model oprawy nie ma kolizji. Bohaterowie stoją tylko: przy ścianie (≤ 0,3 m), wysoko (> 2,4 m), wewnątrz istniejącej bryły kolizji, albo są drobni/płascy. Test `test_collisions_are_the_greyboxes` pilnuje (cały poziom); `test_hero_pieces_stand_out_of_the_way` dostaje nowe id na liście dozwolonych (§2).
- **Greybox zmieniam tylko tam, gdzie katalog tego żąda albo bez tego model nie może stać** (lista zamknięta w §2, pkt „Greybox”); **sale i przejścia bez zmian** → pamięć powłoki bez przeliczania.
- **Model światła prawdziwy:** światła, które realnie oświetlają podłogę, to `LightSpec` układu; przesuwam tylko położenia tam, gdzie oprawa ma swoje miejsce (lampa herbaciarni, latarnie ogrodu), nie liczbę ani grupy. Światła przepisu (pochodnie bramy, trójnogi, wypełnienia, papier) mają małą energię.
- **Areny fair:** w Dziedzińcu Pałacu i w Ogrodzie nic bez kolizji nie staje na podłodze, po której się walczy; osłony Lamassu wyglądają jak osłony (bryły wypełnione), linie strzału i przeskoki bez zmian; grzęda Generała zostaje na okapie.
- **Bez okien i dźwięku.** Kontrole obrazu → lista „Do sprawdzenia w oknie”.

## 2. Decyzje — infrastruktura

| Co | Decyzja |
|---|---|
| Strefy | `MuseumFloorLevel.ART_ZONES` += `assyria`, `asia` (Ameryki i dach zostają greyboksem — osobny etap po Wężu). |
| Style sal | `Floor1Art.ROOM_STYLES` (blok „P4: Asyria i Azja”, 21 sal): `assyria_gate/balawat/courtyard/nimrud/lions/lions_gallery/library` → style o tych nazwach (`lions_gallery` → `assyria_lions`); `assyria_freight_stairs` → `assyria_service_stairs`; `assyria_tablets` → `assyria_tablets`; **`assyria_lion_cage` → `assyria_tablets`** (cegła, brak pasów w 3 m klatce); **`assyria_freight_lift` → `assyria_service_stairs`**. `asia_china/porcelain/korea/armor/garden/teahouse` → swoje; **`asia_service_stairs` → `corridor_w`**; **`asia_armory_vault` → `asia_armor`**; **`asia_garden_shrine` → `asia_teahouse`** (glina, deski); **`asia_crate_store` → `closet`**. |
| Delegacja | `Floor1Art.wing_of`: prefiks `assyria_` → `Floor1ArtAssyria`, `asia_` → `Floor1ArtAsia`; `wings()` += oba; `Floor1LightRecipe.create(layout)` dokleja `Floor1ArtAssyria.extra_lights(layout)` i `Floor1ArtAsia.extra_lights(layout)`. |
| Pasy | `ArtKit.ROOMS[&"assyria_lions"]`: fryz `asy_frieze_` z `"at": 3.0` na **6,9** (sala ma podłogę −3: fryz ląduje na 3,9 m świata, tuż nad reliefami galerii pierścienia 0,9–3,9; przy 3,0 leżałby na poziomie podłogi galerii, u stóp). Reszta stylów bez zmian. |
| Portale | `Floor1ArtAsia.portals()`: `asia_china_porcelain`, `asia_porcelain_korea` — lico porcelany gołe (styl porcelany nie ma `frame_4`; dopasowanie 2 × 2,6 rozciągnięte 2× byłoby karykaturą), lica Chin/Korei brama księżycowa; `asia_garden_wall` (pęknięty mur, brama PANEL) — oba lica gołe; `asia_stairs_crates` (pęknięty mur) — gołe. `Floor1ArtAssyria.portals()`: `assyria_library_tablets` (pęknięty mur) — gołe. `Floor1Art.PORTALS` += `j_assyria_americas: {}`; `SEAL_PORTALS` += `j_assyria_americas: [[assyria_balawat, asy_portal_4m, (4, 4.5)]]` (alabastrowy portal wokół brązowych wrót od strony Asyrii). |
| Wrota pieczęci | `SealGate.ART_LEAVES` += `seal_wing: [asy_balawat_leaf_l, asy_balawat_leaf_r, Vector2(2.26, 5.17), 0.0]` (lico dekoracyjne +Z = pokój A = Asyria; model wyśrodkowany, zawias `_l` na −X). |
| Obwody bohaterów | `Floor1LightRecipe.MAINS_MODELS` → id modelu : `true`; `_hero_circuits` bierze salę z meta `kit_room` najbliższego przodka (grupa bohaterów), nie ze słownika. Dopisane: `asia_shoji_2m`, `asia_lattice_window`, `teahouse` (świecące shoji elewacji gasną z zaciemnieniem; `teahouse_interior` w przystani — nie, przystanie zostają). |
| **Greybox (zmiany jawne)** | (1) `assyria.gd`: elementy `lamassu` hali bramy z (1,4 × 4,5 × 4,6) w x −53,3/−48,7 na **(2,0 × 4,5 × 5,0) w x −53,5/−48,5, z −44…−39** (do lica muru) — kolizja wież Bramy Chorsabadu, której katalog §6 żąda od poziomu („x ±1,5…3,5, z −4,6…0”; głowy posągów sięgają 0,16 m od lica); przejście między nimi 3,0 m (było 3,2). (2) `asia.gd`: cokół hwachy z (2,4 × 0,9 × 1,6) w (46,5; −51) na **(3,55 × 0,9 × 1,4) w (47,825; −51)** — pod cały model `hwacha_display` obrócony o π/2 (stojak z poduszką pod znacznikiem `weapon_hwacha`, wóz za nim); znacznik i ambush bez zmian. (3) `asia.gd`: nowy element `pedestal` **(3,3 × 1,0 × 3,7) w (52; 0; −58,3)** w Sali Koreańskiej — kamienna platforma dzwonnicy `temple_bell` (model: podest 3,24 × 0,98 × 3,64 wyśrodkowany; belka bijaka wysoko, do −2,25, nad krawędzią); w rogu SE, z dala od slotów pary brązowej przy wozie (50; −54,5), patrolu (z −43), gablot (z −62) i łupu (54,5; −59,5). (3a) `asia.gd`: cokoły posągów psów Fu przy żaluzji z z −42 na **−41,5** (narożnik wschodniego cokołu wchodził w zad żywego psa ze slotu (20,5; −42,5)). (4) `asia.gd`: światła latarni ogrodu z y 1,45 na **1,36** (`Light` modelu `toro_kasuga`), żarówka przystani herbaciarni z (8; 2,9; −82) na **(7; 2,8; −82)** (lampa papierowa modelu `teahouse_interior`, patrz §4.6). Nic innego; pamięć powłoki bez zmian (bryły powłoki = sale, studnie, przejścia). |
| Testy wspólne | `test_floor1_art_light::test_dust_and_probes…`: „strefa jeszcze nieubrana” = `americas_moai` (nie `assyria_gate`). `test_floor1_art_fit` lista dozwolonych bohaterów += `khorsabad_gate`, `asy_relief_wake`, `asy_relief_wake_lion`, `asy_relief_1m`, `asy_relief_2m`, `asy_threshold_4m`, `asia_shoji_2m`, `asia_lattice_window`, `teahouse`, `teahouse_interior`, `cherry_tree`, `cherry_petals_ground`; `REACHES` += `lantern` (sznur do stropu — nie: tylko pion; zostaje bez), `relief_slab` (płyty 3 m nad bryłą 2,6 — pion, bez), `obelisk` (bez). Nowy test `tests/integration/test_floor1_art_east.gd`. |

## 3. Decyzje — Asyria (`Floor1ArtAssyria`)

### 3.1 Hala Bramy Chorsabadu (`assyria_gate`)
- **Brama** (bohater): `khorsabad_gate` w **(−51; 0; −39)** bez obrotu (lico muru hali, bryła w głąb −Z; posągi patrzą na +Z, do Egiptu). Pomiar: bryła 7,0 × 9,3 × 4,68; posągi `lamassu_l/_r` x ∓(1,42…3,07), z −4,26…−0,17 → w nowych bryłach greyboksu (x −54,5…−52,5 / −49,5…−47,5; z −44…−39,4). **`door_l`, `door_r` ukryte** (przejście zamykają już skrzydła Egiptu `egypt_seal_door_*` od tamtej strony). Elementy `lamassu` → pusty wygląd.
- Pochodnie na północnych licach wież: światła przepisu w `Light_l/Light_r` = **(−54,2; 3,8; −43,95)** i **(−47,8; 3,8; −43,95)**, oprawa `sconce` → `asy_torch` (yaw 0: uchwyt +Z w wieżę), reguła `torch`.
- `relief` ścienne → **pusty wygląd** (pas `asy_relief_hunt_` od podłogi do 3 m robi to sam); `relief_slab` (3 × 2,6 × 0,6) → **stela**: rdzeń z pola `reveal` (alabaster) o rozmiarze bryły, na obu licach (±Z) płyty `asy_relief_<temat>_` z `ArtKit.run` (szer. bryły, wys. 3,0 — 0,4 nad bryłą), czapka 0,08. Temat sali: gate → `hunt`, nimrud → domyślny geniusz / `genie_l` na drugim licu, lions → `lions`.
- `bench` → ławka holu (Floor1Art), `pedestal`/`plinth` → `asy_plinth` (skalowany), progi `asy_threshold_4m` w przejściach (§3.7).

### 3.2 Wrota z Balawat (`assyria_balawat`)
- **Czarny Obelisk** (`obelisk` 1,2 × 4,2 × 1,2 na `pedestal` 2 × 0,6 × 2): rdzeń ciemnego bazaltu (StandardMaterial (0,13; 0,13; 0,15), roughness 0,55) z czterema `asy_relief_text_1m` ×(1,2; 1,33; 1) na licach przyciemnionymi kopią materiału (albedo × (0,32; 0,32; 0,35)) i schodkowym szczytem z trzech malejących bloków; cokół → `asy_plinth_low` ×(0,8; 1,5; 1,54).
- `column` 1,2 × 7,8 (cedrowe słupy) → **kolumna cedrowa** (procedura wspólna z dziedzińcem, §3.3).
- `case` 3 × 1,4 × 1 → gabloty stołowe holu (`ArtKit.piece case`); `plinth` 0,6 × 1 → `asy_plinth` ×0,545.
- **Wrota pieczęci** `j_assyria_americas`: skrzydła `asy_balawat_leaf_*` (SealGate), portal `asy_portal_4m` ×(1; 1,11) na licu Balawat (SEAL_PORTALS).
- **Trójnogi** `asy_brazier` jako oprawy świateł przepisu po bokach obelisku, przy południowej ścianie: płomień **(−53,6; 1,38; −78,55)** i **(−48,4; 1,38; −78,55)** (bryła 0,66 × 0,68 → 0,35 od ściany), reguła `brazier`, grupa MAIN (muzealne „ognie” gasną z prądem).

### 3.3 Dziedziniec Pałacu (`assyria_courtyard`, arena Lamassu)
- **Osłony — bryły nietknięte, wypełnione:** `pedestal` 2,6 × 1,2 × 2,6 → blok alabastru (`_box` w polu `reveal`) z opaską `asy_frieze_` dookoła szczytu (0,58–1,2; `ArtKit.run` na czterech licach przez `face_transform`); `sculpture` 1,4 × 3,2 × 1,0 (geniusz) → **stela**: rdzeń w `reveal` dokładnie w bryle, na licach ±Z płyty `asy_relief_1m` (−Z: włócznik `asy_relief_1m`, +Z: `asy_relief_text_1m`) ×(1; 1,067; 1), czapka. `column` 1,2 × 13,5 → **kolumna cedrowa**: CylinderMesh (r 0,58 → 0,5) w `ArtLibrary.arch_tile("asy_cedar", true)`, baza 1,2 × 0,3 (pole `reveal`), dwie brązowe opaski (CylinderMesh r 0,6, h 0,12, materiał `bronze` kopiowany z `asy_brazier`? — nie: StandardMaterial metallic 1, roughness 0,38, (0,55; 0,42; 0,26)), kapitel z czterech `asy_corbel` plecami do trzonu pod stropem (tu bez stropu: na 13,0 m).
- **Płyty przebudzenia:** na sześciu `relief` 3 × 3 za znacznikami `lamassu_relief_<n>` (ściany W/E/N) → **panel 3 m** 0,13 m przed pasem: `asy_relief_chariot_1m` + **`asy_relief_wake`** (środek, część `figure` zostaje) + `asy_relief_chariot_1m`, wszystkie na z = −0,13 (przed lico pasa 0,12). Wojownicy fazy 2 schodzą 0,6 m przed płytą (opiekun) — rysunek na płycie to ten sam włócznik.
- **Krenelaż na niebie:** `asy_parapet_2m` dookoła krawędzi studni dachu (świetlik x −89…−76, z −68,5…−57) na koronie studni **y = 14 + `LevelLayout.SKYLIGHT_WELL` (1,5) = 15,5**, moduły 2 m rozciągnięte do równej długości (13 → 6 × 2,167; 11,5 → 6 × 1,917), licem do środka dziedzińca.
- **Trójnogi** przy północnej ścianie po bokach cokołu Lamassu: płomień **(−84,0; 1,38; −79,6)** i **(−73,5; 1,38; −79,6)** (poza bryłą cokołu 2,2 × 4,6 w (−78,75; −74) i poza trasą; MAIN).
- **Księżyc:** zostaje `LightSpec` MOON z układu; dodatkowo `cold_fill` z nieba nad studnią (grupa MOON, energia 0,35·√(149/16) ≈ 1,07, kąt 60°) — jak w Grecji.
- Cokół Lamassu stawia strażnik (`LamassuPlinth`, `asy_plinth_low`) — nie dotykam. Znaczniki osłon, nagrody, drzwi — bez zmian.

### 3.4 Galeria Pałacu Nimrud (`assyria_nimrud`)
- `relief` ścienne → pusty wygląd (pas domyślny: geniusz 2 m / włócznik 1 m); trzy `relief_slab` 4 × 2,6 × 0,6 w osi → stele dwustronne (geniusz / `genie_l`).
- **Rusztowanie konserwatorów** (`scaffold` 1,2 × 3,2 × 4,0): procedura — 4 stalowe stojaki (CylinderMesh r 0,024, stal: metallic 0,9, roughness 0,45, (0,55; 0,56; 0,58)), rygle i poprzeczki na 1,0 / 2,0 / 3,0 m, dwa pomosty z desek (BoxMesh 0,04 w `arch_tile("boards_dark", true)`? — to pole azjatyckie; wezmę `asy_cedar` lokalnie), stężenia skośne; wszystko w bryle.
- `desk` (wózek) → biurko holu; `crate` → skrzynia holu; lampa robocza `bulb` → żarówka holu (konserwatorzy = współczesność).

### 3.5 Sala Lwów (`assyria_lions`, pierścień `assyria_lions_gallery`)
- **Dół (−3…0):** pas `asy_relief_lions_` z stylu; **dwie płyty `asy_relief_wake_lion`** 0,13 przed pasem w miejscach śpiących lwów: środek dolnej krawędzi **(−95,87; −3; −27)** licem na +X i **(−79,13; −3; −14)** licem na −X (lwy budzą się 0,6 m przed nimi).
- **Pierścień:** `relief` 6 / 5 / 4 × 2,4 na 0,9 m → runy `asy_relief_lions_2m/1m` (wys. 3,0, do 3,9 m), nad nimi fryz z stylu (6,9 od podłogi −3 = 3,9). `balcony` (płyty pierścienia) → płyta holu z polem `slab`? — nie: styl `assyria_lions` nie ma `fascia` → `LevelArt` dałby fasadę holu; dopisuję do stylu **`"fascia": "asy_frieze_"`** (`fascia_end` brak → bez zakończeń): malowany fryz na licu płyt pierścienia (0,62 w dół od wierzchu? — fasada stoi na wierzchu płyty: datum fryzu = dolna krawędź → fryz 0…0,62 nad płytą, jak niska balustrada malowana; z poręczą wyżej). `railing` 1,1 × 0,15 → **krenelaż** `asy_parapet_2m` (0,93 wys., 0,58 głęb.; moduły 2 m stretch) — pałacowy parapet galerii; `balcony_post` 0,6 × 2,6 (słupy pod galerią) → kolumna cedrowa (§3.3, r 0,28).
- **Dół:** `relief_slab` 4 × 2,6 → stele (`lions`); **rydwan** (`chariot` 1,8 × 1,6 × 3,2): procedura — skrzynia (BoxMesh 1,0 × 0,9 × 1,1 w cedrze, panele brązu), podłoga, oś (walec), dwa koła (TorusMesh r 0,55, rura 0,06; 8 szprych; piasta) z brązu, dyszel 2,2 m i jarzmo; wszystko w bryle, front −Z. **Klatki** (`cage` 1,8³): rama z 12 prętów (r 0,03) i pręty pionowe co 0,3 m na czterech ścianach + 3 na wierzchu (ciemne żelazo), podłoga z desek. Reflektory `RAKE` zostają.

### 3.6 Biblioteka Aszurbanipala (`assyria_library`), magazyny, sekrety
- `shelf` 4 × 2,4 × 0,6 (biblioteka), 3,5 × 2,2 × 0,6 (magazyn) → `asy_tablet_shelf` × n (moduł 2 m: n = round(w/2), skala (w/n/2; h/2,2; d/0,5)); `case` 2,6 × 1,3 × 1,2 i 1,2 × 1,4 × 1,0 (Tabliczka Potopu) → gabloty holu; `desk` czytelnika → biurko holu + **`asy_prism`** na blacie (x −0,45; notatka `note_assyria_2` leży na x +0,3); `chair` → krzesło holu; `crate` 1 × 0,9 × 1 (magazyn) → **dwie `asy_tablet_crate`** jedna na drugiej (0,45 każda, ×(1,11; 0,94; 1,67)); klatka: `crate` 1,4 × 0,5 × 1,0 → `asy_tablet_crate` ×(1,56; 1,04; 1,67), 1,0 × 0,8 × 1,0 → skrzynia holu; winda: skrzynie holu.
- Schody towarowe i winda: `assyria_service_stairs` (tynk, świetlówki holu).

### 3.7 Oprawy, progi, pasy
- `fixture(sconce, assyria_*)` → `asy_torch` (początek = światło; uchwyt 0,37 w +Z — przy światłach 0,2 od ściany płyta uchwytu znika w pasie reliefów: pochodnia wygląda na przykręconą do płyty); `fixture(brazier)` → `asy_brazier` przesunięty o (0; −1,38; 0); `bulb`/`desk_lamp`/`tube_lamp` → hol.
- **Progi** `asy_threshold_4m` w sześciu przejściach Asyrii (gate–balawat 6 m, gate–nimrud 8 m, nimrud–courtyard 6 m, courtyard–balawat 6 m, nimrud–lions 4 m, gate–library 3 m): bohater płaski na posadzce przejścia (+0,006), skala (szer./4; 1; głęb. muru/1,2).
- Belki i wsporniki z stylu (`dress_ceiling`): hala bramy (10 m), Balawat (8), Nimrud (8), Sala Lwów (9), biblioteka (6). Dziedziniec bez stropu.

## 4. Decyzje — Azja (`Floor1ArtAsia`)

### 4.1 Sala Chin (`asia_china`)
- **Budda:** `pedestal` 7 × 1,5 × 6 → **podest**: blok w polu `floor` (`tiles_golden`, kamień) z pasem `asia_dado_` (lakierowana boazeria 1,1 m) na czterech licach i kamienną czapką 0,4; `sculpture` 5 × 7,5 × 4 (yaw π) → **`buddha_seated`** w skali 1 (3,66 × 7,64 × 4,08, z −2,25…1,83 → w bryle; szczyt 9,14 < 12), na stopniu `Offering` (0; 0,4; −1,95) **`bronze_ding`** ×1,2 (kadzielnica). Światło `Halo`: omni przepisu w (13,5; 6,32; −58,2), złoto 0,6 / 3 m, reguła `paper`.
- `plinth` 1,6 × 1,2 × 1,6 (ołtarz w osi) → blok kamienny + dado; `plinth` 0,6 × 0,9 (szachy) → `asia_plinth` ×0,857.
- **Psy Fu** przy żaluzji: `pedestal` 1,4 × 1,0 × 1,4 → blok kamienny z czapką; `sculpture` 1,0 × 1,8 × 1,4 → **`ArtLibrary.exhibit(&"fu_dog")`** ×0,77 (1,8 m do grzywy; długość 2,46: 0,53 za bryłą po obu stronach — `sculpture` jest w `REACHES`), drugi odbity (`scale.x` −1): lew i lwica.
- **Słupy** 1,2 × 12 × 1,2 (tint LACQUER → bez znaczenia, model) → `asia_post_base` ×(1,33; 1; 1,33), `asia_post_shaft` ×(1,6; 10,4; 1,6) od 0,4, `asia_post_capital` na 12,0 (wisi 1,2).
- **Gabloty** (`case` wzdłuż zachodniej ściany, do 4 m, wys. 2, głęb. 1) → `asia_case_tall` × n (moduł 1 m; skala (w/n/0,97; 2/1,89; 1/0,77)), szkło `_solid_glass`; na `ItemSpot` kolejno `bronze_gu` ×1,6, `vase_blue_white` ×1,3, `bronze_ding` ×0,65, `moon_jar`, `vase_celadon` ×1,3 (ostatnia gablota z łupem — pusta: `_holds_loot`).
- **Lampiony** (`lantern` 0,6 × 0,9 × 0,6, światło 0,4 nad podstawą elementu) → `asia_lantern_red` w (0; 0,4; 0) (początek = światło) + **sznur** do stropu: CylinderMesh r 0,012 od szczytu sznura modelu (y 0,4 + 1,03) do `room.ceiling_y`, czarny lak. Tak samo w porcelanie (światło +0,3), Korei, zbrojowni.
- Lampy czerwone, kamera — bez zmian.

### 4.2 Galeria Porcelany (`asia_porcelain`)
- `case` 1,2 × 1,9 × 1,2 → `asia_case_tall` ×(1,24; 1,0; 1,56) + porcelana na `ItemSpot` (meiping, maebyeong, dzban księżycowy, gu, meiping) ×1,25; `plinth` 0,7 × 1,1 × 0,7 → `asia_plinth` ×(1; 1,22; 1); `sculpture` 0,5 × 0,8 × 0,5 → `moon_jar` ×1,05 / `vase_celadon` ×1,8 na zmianę. Portale: lico porcelany gołe (§2).

### 4.3 Sala Koreańska (`asia_korea`)
- **Hwacha:** `pedestal` (3,55 × 0,9 × 1,4 — §2) → **`hwacha_display`** w skali 1 obrócony o π/2 (front −Z modelu → −X świata, do łuku porcelany), początek świata **(47,4; 0; −51)**: `weapon_spot` (0; 0,83; −0,9) ląduje w (46,5; 0,83; −51) = znacznik `weapon_hwacha` (0,9) — OGNISTA SKRZYNIA unosi się nad poduszką; stojak z −1,34…−0,46, wóz 0,21…2,19 (świat x 46,06…49,59 ⊂ cokół 46,05…49,6). Wygląd elementu to ten model w ramie elementu (przesunięty o −0,425 wzdłuż osi).
- **Maty wystawowe pod żywymi eksponatami** (uwaga kontrolera 10.10: gałąź `enemies-east` ożywia sloty `[wolf, fu_dog]` i `[knight, samurai_armor]`; eksponat stojący na gołej podłodze to jedna ze skarg właściciela): pod każdym slotem Azji bez patrolu (psy Fu, zbroje; ~25) bohater **`ExhibitMat`** — pod zbroją lakowana płyta 1,3 × 1,3 z cynobrowym obrzeżem, pod lwem kamienna płyta 1,6 × 3,8 (środek 0,22 za slotem: tułów −1,83…+1,38), oba 1,5 cm, z mosiężną tabliczką `plaque_brass` leżącą przy przedniej krawędzi; obrót = `yaw` slotu. Bez kolizji i bez podwyższenia (podniesiony cokół wymagałby podniesienia `y` slotów — to gałąź wrogów). Pozycje slotów nietknięte; statyczne rekwizyty odsunięte od ciał (§2, 3 i 3a); test sprawdza, że żaden rekwizyt nie wchodzi w bryłę 1,4 × 1,2 × 1,4 nad slotem.
- **Dzwonnica:** `pedestal` 3,3 × 1,0 × 3,7 w (52; −58,3) (§2; 0,85 m od łupu (54,5; −59,5), 0,55 m od zadu psa ze slotu (50; −54,5), 0,45 m od gablot — z belką bijaka) → **`temple_bell`** w skali 1 bez przesunięcia (podest modelu ±1,62 × ±1,82 ⊂ bryła ±1,65 × ±1,85; belka bijaka 1,4–3,4 m nad podłogą wystaje 0,4 za krawędź północną); `bell` kołysze się ledwo (`DecorSpinner.swing` wokół X, 0,015 rad, 7 s; proces dekoracji sali — przycinany). Ciepłe światło przepisu w pawilonie (52; 2,2; −57,3), 0,8 / 4,5 m, `paper`.
- `case` północnej ściany → `asia_case_tall` × n z seledynami i dzbanami; `plinth` 0,9 × 1,0 → `asia_plinth` ×(1,29; 1,11; 1,29) + `moon_jar` ×1,5 (`sculpture` 0,7³).
- **Parawany** (`painting` 3,2 × 2,2 × 0,08 na 2,4 m, wschodnia ściana) → **tryptyk zwojów**: 4 × `scroll_hanging` (zestawy 山 / 水 / 月 / ensō) na hakach w y 2,2 (ramy elementu), x −1,2 / −0,4 / 0,4 / 1,2, lico 0,02 przed ścianą.
- **Fałszywe okna** `asia_lattice_window` (zestaw `_lit`) wysoko na południowej ścianie (z −39,04; y 3,6; x 42 / 46,5 / 51), za każdym ciepłe światło przepisu (`paper`, 0,5 / 3,5 m, 0,4 od ściany).

### 4.4 Sala Zbroi (`asia_armor`)
- `armor_rack` 0,8 × 2,2 × 0,6 → **`samurai_armor_stand`** w skali 1 (1,16 × 2,44 × 0,82: 0,18 / 0,11 za bryłą — w luzie 0,3), zestawy `""` / `_blue` / `_white` na zmianę (index); `pedestal` 6 × 0,4 × 2 (wyspy) → **podest z czarnego laku** (`_box` w polu `reveal`); `plinth` 1,4 × 1,0 × 1,4 (bęben) → lakowa skrzynia (blok `reveal` + czapka 0,05 w `asia_lacquer` — łup leży na niej).
- `banner` 1,4 × 4 (tint LACQUER) → **wielki zwój** `scroll_hanging` ×(1,87; 1,97; 1) (山 na zachodzie, 月 na wschodzie) z haka na szczycie bryły.
- **Shoji** `asia_shoji_2m` (zestaw `_lit`) płasko na ścianach (bohater, 0,12 grubości): wschodnia ściana aneksu x 55,94 (z −65 / −69 / −73, lico na −X), północna z −62,56 (x 42,5 / 49,5), zachodnia x 30,56 (z −67 / −81); za każdym światło przepisu `paper` (0,45 / 3,5 m, 0,4 od ściany, ciepły papier (1; 0,86; 0,66)). **Andony** `asia_lantern_floor` jako oprawy świateł przepisu (`andon`) w rogach przy ścianach: (31,0; 0,42; −85,5), (55,5; 0,42; −63,0); reguła `paper`.
- Lampiony jak w Chinach; reflektor złoty na zbroje zostaje.

### 4.5 Ogród japoński (`asia_garden`, arena Generała)
- `floor` żwir 11,5 × 23,5 → **pusty wygląd** (pole `gravel_raked` sali); `floor` staw 5 × 4 → **`garden_pond`** ×(0,75; 0,5; 0,91) (kamienie brzegu 0,13 wys., woda +0,015).
- **Głazy** (`rock` 2,2 × 1,8|1,4 × 1,8, yaw do posta): 1,8 → `garden_rock_a` ×(0,77; 1,05; 0,77) (bryła 2,86 × 1,72 × 2,34 → dokładnie bryła); 1,4 → `garden_rock_c` ×(0,85; 1,69; 0,69) (omszały głaz). Kolizja = bryła greyboksu (osłona Generała bez zmian).
- **Latarnie kamienne** (`pedestal` 0,7 × 1,7 × 0,7) → `toro_kasuga` ×1 (stopa 0,62 × 0,7, dach 1,04 → 0,17 za bryłą), światło układu na 1,36 (§2).
- **Wiśnia** (bohater): `cherry_tree` w (23; 0; −76,5) (pień y < 1,9: 1,2 × 1,14 wokół bryły `column` 0,6; `Petals_1..10` 2,8–5,4 m nad żwirem, ≤ 6 m od posta (17,5; −75) → `PetalStorm.emitters_for` bierze je), `cherry_petals_ground` pod drzewem (+0,004); `column` i `tree_crown` → pusty wygląd.
- **Herbaciarnia — elewacje** (bohater, patrz §4.6): model `teahouse` wpasowany w dwa ogrodowe lica (x 12,5; z −77,5). **Okap greyboksu** (`balcony`, 2 elementy, 3,5–3,9 m) → **górny okap ze strzechy** (płyta w polu `thatch` na deskowanej podsufitce, cedrowa listwa czołowa): krawędź strzechy modelu wisi nisko (2,28 m; po obniżeniu 1,88 m), więc Generał na grzędzie 3,9 m stałby 1,6 m nad nią — płyta okapu greyboksu ubrana w strzechę daje dach **dwuspadowy piętrowy (mokoshi)**: niska spódnica modelu nad werandą i wyższy okap, na którym stoi Generał i który zatrzymuje strzały (kolizja = wygląd).
- **Grzęda Generała:** węzeł **`roof_perch`** (Node3D) w grupie bohaterów ogrodu dokładnie w `PERCH` greyboksu **(13,6; 3,9; −76,6)** (narożnik okapu, na strzesze modelu), zwrócony na post; **węzły `roof_perch`/`roof_perch_eave` modelu przemianowane** (`roof_perch_model`, `roof_perch_eave_model`) — kalenica modelu (7,2 m nad pokojem herbaciarni) leży w litej masie powłoki nad stropem 3,5 (ściana ogród–herbaciarnia idzie do 14 m) i jest z areny niewidoczna. Generał bierze więc **moją** grzędę = tę samą, którą testy greyboksu sprawdzają (`test_general_roof`: grzęda ≤ 0,05 od `arena_general_perch`).
- Światło: trzy pule księżyca układu zostają; `cold_fill` z trzech studni (MOON); czerwona lampa.

### 4.6 Herbaciarnia (`asia_teahouse`, przystań) — dopasowanie modelu
- Pomiar `teahouse`: ściany x ∓3,5, z ∓4,5 (model zakłada pokój x 4…10 — faktyczny 4…12); dach x −3,70…4,80, z −4,70…5,80 (okap 1,3 m za lica wschodnie i południowe, 0,2 za zachodnie/północne), kalenica 7,78; przed licami niskie: weranda 0,42–0,54 (x 3,6…4,67; z 4,6…5,53), kamienie, **misa tsukubai z bambusem** x 5,21…7,30, z −1,35…1,96, do 0,62 wys.
- **Wpasowanie:** początek **(8,215; −0,40; −81,785)**, skala **(1,2329; 1; 0,9589)** → lico wschodnie 12,53 (3 cm przed licem ściany 12,5), zachodnie 3,9 (w grubości zachodniej ściany), południowe −77,47, północne −86,1 (w ścianie); okap do x 14,13 / z −76,2 (pod okapem greyboksu 12,5…14,3 / −77,5…−75,7); **model obniżony o 0,40 m**: weranda równo ze żwirem, kamienie płasko, misa 0,22 wys. (x 14,6…17,2, z −83,1…−79,9 — płytki kamienny zbiornik w rogu areny przy drzwiach przystani, bez kolizji, do przejścia jak brzeg stawu). Dach modelu nad okapem ginie w ścianie 14 m: z ogrodu widać elewacje (shoji świecą, EXTRAS 1,6), werandę, kamienie, misę i pas strzechy 1,3 m jak daszek pulpitowy przy murze.
- **Wnętrze** `teahouse_interior` (6 × 3,5 × 8, `terminal_spot` (−2,6; 0; 0), `Light` (0; 2,8; 0)): początek **(8; 0; −82)**, skala **(1,333; 1; 1)** (tokonoma, palenisko, shoji po bokach drzwi na wschodniej ścianie 12); `terminal_spot` → (4,53; 0; −82) wobec `haven_spots` (4,4; −82) ✓. `floor` maty → pusty wygląd (pole `tatami`); `desk` 1,2 × 0,4 × 0,8 → niska lakowa skrzynia (`_box` w `asia_lacquer_black`, dopasowana do bryły; stolik modelu, jeśli pokrywa bryłę, zostaje pod nią — sprawdzam sondą w zadaniu 4, w razie konfliktu wygląd pusty). Żarówka przystani w (7; 2,8; −82) (§2) z oprawą `bulb` → pusty wygląd (lampa papierowa jest w modelu).
- Sekrety: kapliczka — `plinth` 1,2 × 1,0 × 0,8 → lakowa skrzynia-ołtarz; `sculpture` 1 × 1,6 × 1 (dzwon) → część `bell` modelu `temple_bell` ×0,7 na ramie z dwóch cedrowych słupków i belki (`_rod`, lak), oś dzwonu w 1,55; skarbiec — `armor_rack` → stojaki, `crate` → skrzynia holu; magazyn skrzyń — skrzynie holu, styl `closet`.

## 5. Decyzje — światło i atmosfera (`Floor1LightRecipe`, §10.1)

| Sala | Mgła (gęstość, kolor) | Sonda | Cienie | `lamp_energy` | Uwagi |
|---|---|---|---|---|---|
| Hala Bramy | 0,014 alabaster (0,8; 0,82; 0,88), noise 0,5 | tak | 2 | 1,3 | pochodnie bramy, reflektor RAKE z cieniem |
| Balawat | 0,014 | tak | 1 | 1,3 | trójnogi, blask na wrotach |
| Dziedziniec | 0,010 DUST (chłód) | tak | 2 | 1,25 | księżyc z cieniem (układ), `cold_fill`, trójnogi, krenelaż |
| Nimrud | 0,013 | tak | 2 | 1,35 | RAKE wzdłuż reliefów + lampa robocza |
| Sala Lwów (+ pierścień) | 0,016 kurz dołu, noise 0,6 | tak | 2 | 1,35 | dwa RAKE z narożników dołu |
| Biblioteka | 0,012 PAPER | — | 1 | 1,3 | lampka czytelnika, snop na Tabliczkę |
| Magazyn tabliczek, klatka, winda | 0,02 / 0,022 / 0,012 | — | 0 | 1,3 | przystanie sekretów |
| Schody towarowe | 0,008 | — | 0 | 1,0 | świetlówki |
| Sala Chin | 0,012 kadzidło (0,9; 0,84; 0,76), noise 0,5 | tak | 2 | 1,25 | snop na Buddę z cieniem, `Halo` |
| Porcelana | 0,010 | tak | 1 | 1,25 | lampiony |
| Korea | 0,012 | — | 2 | 1,25 | snop na hwachę, dzwonnica, okna |
| Zbrojownia | 0,016 grafit (0,76; 0,76; 0,8) | — | 1 | 1,2 | shoji i andony świecą; reflektor |
| Ogród | 0,009 DUST | tak (staw) | 1 | 1,3 | pule księżyca (`moon_pool`), latarnie, `cold_fill` |
| Herbaciarnia | 0,012 PAPER | — | 1 | 1,0 | przystań (HAVEN) |
| Kapliczka, skarbiec, magazyn | 0,014 / 0,02 / 0,02 | — | 0 | 1,2 | |
| Schody służbowe Azji | 0,008 | — | 0 | 1,0 | |

- `ROOM_KEYS` += `assyria_lions_gallery → assyria_lions`.
- **Nie za ciemno:** `lamp_energy` 1,2–1,35 (jak podziemia 1,45–1,6, które właściciel uznał za „akceptowalnie ciemne”); **wypełnienia** (`fill`: szerokie reflektory z sufitu bez mgły i cienia, zimna szarość (0,7; 0,74; 0,82), energia 0,6–0,9 — imitacja odbicia od alabastru/tynku) w hali bramy (1), Nimrud (2), Sali Lwów (1), Balawat (1), Chinach (1), Korei (1), Zbrojowni (1); `cold_fill` z nieba w dziedzińcu i ogrodzie. Egipt (bez wypełnień, `lamp_energy` 1,0) zostaje porównaniem: Asyria ma być jaśniejsza od grobowców Egiptu przy tej samej dramaturgii.
- **Oprawy** (`FIXTURES`): `torch` {cień: nie, mgła 0,3, energia 1,2}, `brazier` {nie, 0,35, 1,0}, `paper` {nie, 0,08, 1,0}, `andon` {nie, 0,1, 1,0}, `fill` {nie, 0,0, 1,0}. Lampiony układu bez oprawy → reguła sufitowa (mgła 0,15 ≤ `lamp_fog`).
- **Cząsteczki** (`MOTES`): kurz dziedzińca (2 × 160, DUST, w świetle księżyca), Nimrud (140, alabaster), Sala Lwów (120), hala bramy (120); **żar** nad trójnogami (`"embers": true`: 4 emitery × 14 drobin, 0,02 m, unoszą się 0,6 m/s z turbulencją, materiał z emisją (1; 0,45; 0,15), `make_embers`); Chiny (150 kadzidło), Korea (100); **płatki** w ogrodzie (`"petals": true`: 2 emitery × 36, kwadraty 0,07 m różu (0,98; 0,8; 0,85) dwustronne, `align_y`, opadanie −0,12 m/s, turbulencja, `make_petals`) — codzienny deszcz płatków; burzę fazy 3 robi `PetalStorm` z `Petals_*`. Grupa `quality_particles`.
- **Obwody:** `asy_torch` i `asia_lantern_*` to oprawy (gasną z MAIN); świecące elementy (`toro_*`, lampiony-elementy, `asia_case_*`) — `add_glow_circuits` (automat); bohaterowie `asia_shoji_2m`, `asia_lattice_window`, `teahouse` — `MAINS_MODELS` (§2).

## 6. Wydajność i pomiar

- Największe koszty: pas `asy_relief_` (płyty 2/1 m na wszystkich ścianach: ~400 modułów po 20 trójkątów — tanio), `khorsabad_gate` 24 868, Budda 16 440, psy Fu 2 × 13 118 (×0,77), zbroje 16 × 9 496 ≈ 152 tys., dzwonnica 4 702, wiśnia 6 602, herbaciarnia 3 196 + 1 566. Razem ≈ 0,45 mln trójkątów w strefach (Oświecenie miało ~1,4 mln). Węzły jako zwykłe instancje.
- Pomiar bez okna (§9): czas budowy piętra z oprawą (zimno/ciepło), liczba `MeshInstance3D`, lampy/cienie/drobiny po przycinaniu w widokach wycieczki (`dry`).

## 7. Wycieczka

`tests/scenarios/tour_scenario.gd`: +14 widoków Asyrii (hala bramy z Egiptu i z bliska, oś do obelisku, wrota z Balawat, dziedziniec: cokół w księżycu / szeroko / w górę na krenelaż, Nimrud na długość / reliefy / rusztowanie, galeria Sali Lwów / dół, biblioteka, schody towarowe) i +14 Azji (Budda, słupy, porcelana, hwacha, dzwonnica, zbrojownia rzędy / shoji, ogród: wejście spod pękniętego muru / herbaciarnia / wiśnia / staw / w górę, wnętrze herbaciarni, schody); zaciemnienia: dziedziniec, Sala Chin; `PERF_VIEWS` += `assyria_nimrud_long`, `asia_china_buddha`, `asia_garden_entry`. Uruchamiam tylko `dry`.

## 8. Zadania

### Zadanie 1: plan (ten dokument) — commit
- [x] Plan.

### Zadanie 2: szkielet — strefy, style, delegacja, przepis sal, testy wspólne
- [x] `ROOM_STYLES` 21 sal; moduły `Floor1ArtAssyria` / `Floor1ArtAsia` (puste); `wing_of`/`wings`; `Floor1LightRecipe.ROOMS` wpisy 21 sal (§5), `ROOM_KEYS`, `create()` dokleja `extra_lights` obu modułów; `test_floor1_art_light` (strefa nieubrana = `americas_moai`). (`ART_ZONES` dostaje każdą strefę w jej zadaniu — 3 i 4 — żeby każdy commit był zielony.)
- [x] Test `test_floor1_art_east.gd`: każda sala obu stref ma styl; każda w przepisie, `lamp_energy` ≥ 1,2, mgła rzadsza niż w grobowcach Egiptu; `test_floor1_art_fit` nie mierzy skrzydeł drzwi (wiszą na zawiasie: wygląd i kolizja po jednej stronie osi); commit.

### Zadanie 3: Asyria — elementy, bohaterowie, oprawy, wrota
- [x] `ART_ZONES` += `assyria`. Greybox: bryły `lamassu` hali (§2). `Floor1ArtAssyria.piece_look`: lamassu (pusty), relief (pusty / runy reliefów na pierścieniu / panele przebudzenia w dziedzińcu), relief_slab (stele), pedestal/sculpture dziedzińca (bloki z fryzem, stele), column/balcony_post (cedr), obelisk, scaffold, chariot, cage, railing (krenelaż), shelf, crate, plinth, desk (pryzmat); `fixture` (torch, brazier); `dress`: brama (drzwi ukryte), lwy przebudzenia w dole, progi, krenelaż studni; `portals`; `SealGate.ART_LEAVES` + `SEAL_PORTALS`/`PORTALS`; `ArtKit.ROOMS[assyria_lions]` fryz 6,9 + pas lwów pod płytami pierścienia (`soffit`); `Floor1Art.wants_fascia` bez Asyrii (płyty pierścienia gładkie pod krenelażem); `extra_lights` (pochodnie bramy, trójnogi, wypełnienia, `cold_fill`).
- [x] Testy (east, 5): brama w (−51; 0; −39), drzwi ukryte, obrysy posągów w bryłach greyboksu, elementy `lamassu` bez siatek; osłony Lamassu mają siatkę na 1 m; 6 paneli przebudzenia przy `lamassu_relief_<n>` płasko na ścianach, 2 lwy w dole licem do dołu; nic z bohaterów na podłodze areny poza pasem przyściennym; pochodnie = kinkiety + 2 na bramie, 4 trójnogi, progi w każdym przejściu, krenelaż na 16 m i na balustradach galerii; zaciemnienie gasi ognie, księżyc dziedzińca zostaje. `--filter=floor1_art,lamassu,guardian,northwest_walk,seal_gate` zielone (79); commit.

### Zadanie 4: Azja — elementy, bohaterowie, oprawy, herbaciarnia
- [x] `ART_ZONES` += `asia`. Greybox: cokół hwachy, platforma dzwonnicy, światła latarni i przystani (§2). `Floor1ArtAsia.piece_look`: pedestal/sculpture/plinth (podest Buddy z dado, Budda z kadzielnicą, psy Fu z `exhibit()`, dzwonnica z kołyszącym się dzwonem, hwacha z lakowym podestem i cokołem między stojakiem a wozem, latarnie, głazy, bloki kamienne i lakowe), column (słupy / pusty pień wiśni), case (gabloty z brązami i porcelaną, puste gdy z łupem), lantern (+ sznur do stropu), painting (tryptyk zwojów), banner (wielki zwój), armor_rack (zestawy sznurowania), floor (żwir pusty, staw, maty puste), rock, tree_crown (pusty), **balcony (górny okap ze strzechy — §4.5)**, desk/crate (lak); `fixture` (bulb herbaciarni pusty, andon); **`door_leaf`** (drzwi herbaciarni = shoji; hak `ArtKit.leaf` → `Floor1Art.door_leaf`); `dress`: wiśnia + płatki na ziemi, elewacje herbaciarni (skala, obniżenie, węzły grzędy przemianowane, własny `roof_perch` na narożniku okapu), wnętrze, shoji ×7, okna kratowe ×3; `portals`; `extra_lights` (Halo, dzwonnica, papier za shoji i oknami, andony, wypełnienia, `cold_fill` ogrodu, lampa przy drzwiach przystani); `MAINS_MODELS` po `kit_room` (shoji, okna, elewacje gasną z prądem).
- [x] Testy (east, 4): jeden `buddha_seated` pod stropem w obrysie bryły, licem do sali; `weapon_spot` hwachy ≤ 0,15/0,1 od `weapon_hwacha`, cały wóz na cokole; podest dzwonnicy w bryle platformy, dzwon kołysze się (proces dekoracji sali); `PetalStorm.emitters_for` daje 10 emiterów w koronie nad ogrodem; dokładnie jeden `roof_perch` w poziomie, na `arena_general_perch`, w powietrzu; model bez węzła `roof_perch`; nic z herbaciarni w arenie nad kolanem; spódnica dachu do krawędzi okapu greyboksu; elewacje na licach ścian; okap ze strzechą; wnętrze z `terminal_spot` przy przystani; lampiony na światłach, shoji ×7, drzwi herbaciarni = shoji, zaciemnienie gasi shoji/lampy, 3 nieba ogrodu zostają. `--filter=floor1_art,general,guardian,east_walk` zielone; commit.

### Zadanie 5: światło i atmosfera
- [x] `FIXTURES` (torch, brazier, paper, andon, fill — w zadaniach 3–4), `MOTES` (kurz: dziedziniec, Nimrud, hala bramy, dół lwów, Chiny, Korea; płatki: dwa ramiona ogrodu), żar nad trójnogami z `Floor1ArtAssyria.BRAZIERS` (`make_embers`: 14 iskier, 2,4 s, w górę, materiał z emisją), `make_petals` (różowe listki 7 × 9 cm, `align_y`, opadanie −0,12, turbulencja; nazwa `PetalFall_*`, nie `Petals_*` — tych szuka `PetalStorm`), `MAINS_MODELS` z `kit_room` (zadanie 4), wartości §5 (zadanie 2).
- [x] Testy (east): wszystkie sale obu stref w `ROOMS`, `lamp_energy` ≥ 1,2, mgła ≤ grobowce Egiptu (zadanie 2); żar nad każdym trójnogiem (4), płatki w ogrodzie (2), kurz w sześciu salach, wszystko w `quality_particles`; przycięcie ogrodu zatrzymuje płatki; zaciemnienia (zadania 3–4); budżety cieni (test wspólny `test_floor1_art_light`). `--filter=floor1_art_east,floor1_art_light,floor1_art_wings,menu_stage` zielone; commit.

### Zadanie 6: wycieczka
- [x] Widoki §7 (14 + 14), zaciemnienia (dziedziniec, Chiny), `PERF_VIEWS` (+3); `bash tools/run_tour.sh dry`: 95 widoków, 0 z problemami, muzeum 11,8 s na zimno; w nowych skrzydłach po przycięciu 47–141 lamp, 2–9 cieni, 220–1456 drobin na widok (jak w ubranych skrzydłach). Maty wystawowe i odsunięte rekwizyty (uwaga kontrolera) — w tym commicie; commit.

### Zadanie 7: całość
- [x] `git merge pietro-1` (czysto, 8 commitów HUD/hwacha/testy, bez styku z plikami P4); pełny zestaw: **2114 zielonych, 1 czerwony** (`test_sandbox_arena :: test_exhibits_reach_a_guard_on_the_mezzanine` — piaskownica holu, czasowy; sam przebiega zielono: 4/4; w pierwszym pełnym biegu był zielony, a czerwone były dwa testy wolnej podłogi Korei — poprawione przesunięciem platformy dzwonnicy), 0 linii ERROR; §9; commit; raport.

## 9. Jak zbudowano (10.10)

### Liczby (pomiar bez okna)

| Co | Wartość |
|---|---|
| Budowa piętra z oprawą | ~7,3 s na zimno (wczytanie modeli), ~0,8 s na ciepło (P3: 5,4 / 0,66 s); muzeum w grze (wycieczka `dry`) 11,9 s na zimno, nawigacja z pamięci 0,08 s |
| Węzły siatek | 11 346 z Asyrią (P3: 10 366), ~12 200 z obiema strefami — pas reliefów to setki tanich płyt (20 trójkątów), bohaterowie: brama 24,9 tys., Budda 16,4 tys., psy Fu 2 × 13,1 tys., stojaki 16 × 9,5 tys., dzwonnica 4,7 tys., wiśnia 6,6 tys., herbaciarnia 3,2 + 1,6 tys. |
| Bohaterowie | brama Chorsabadu, 6 paneli przebudzenia (3 płyty każdy), 2 lwy przebudzenia, 8 progów, 24 merlony nad dziedzińcem + krenelaż 4 balustrad galerii (~37 modułów), trójnogi 4 (oprawy); wiśnia + płatki, elewacje i wnętrze herbaciarni, `roof_perch`, 7 shoji, 3 okna kratowe, 31 mat wystawowych |
| Przycinanie grafem (High, głębokość 2) | z hali bramy 12 sal / 129 lamp / 7 cieni, z dziedzińca 7 / 80 / 6, z Nimrud 12 / 116 / 7, z Sali Lwów 17 / 124 / 5, z Sali Chin 15 / 141 / 6, z Korei 11 / 127 / 5, z ogrodu 6 / 47 / 2, z herbaciarni 4 / 29 / 2 |
| Drobiny | 676 w dziedzińcu, 976 w Nimrud, 1456 w hali bramy (z Egiptem), 708 w Sali Lwów, 1040 w Chinach, 848 w Korei, 220 w ogrodzie (płatki 60 + kurz sąsiadów) |

### Odstępstwa od planu i od greyboksu

| Co | Zmiana | Dlaczego |
|---|---|---|
| Bryły `lamassu` hali bramy | 2,0 × 4,5 × 5,0 w x −53,5/−48,5, z −44…−39 (było 1,4 × 4,5 × 4,6) | kolizja wież bramy, której katalog żąda od poziomu; przejście 3,0 m |
| Cokół hwachy | 3,55 × 0,9 × 1,4 w (47,825; −51) (było 2,4 × 0,9 × 1,6 w 46,5) | cały model `hwacha_display` na cokole, poduszka pod znacznikiem |
| Platforma dzwonnicy | nowy `pedestal` 3,3 × 1,0 × 3,7 w (52; −58,3) | model `temple_bell` ma własny kamienny podest; róg sali z dala od slotów, łupu i gablot |
| Cokoły psów Fu | z −42 → −41,5; potem (polish-east) wydłużone: cokół 1,4 × 1,0 × 2,75 i bryła posągu 1,0 × 1,8 × 2,55 w z −40,775 (z −42,15…−39,4, 0,4 m od południowej ściany) | zad żywego psa ze slotu (20,5; −42,5) wchodził w narożnik; posąg (2,5 m od pyska do ogona) wystawał 0,4–0,7 m za bryłę i cokół: dwa metry bryły bez kolizji na wysokości głowy |
| Światła latarni ogrodu, lampa przystani | y 1,45 → 1,36; (8; 2,9) → (7; 2,8) | `Light` modeli `toro_kasuga`, `teahouse_interior` |
| Fryz Sali Lwów | `at` 3,0 → 6,9; pas lwów z `soffit: true` | podłoga dołu −3: fryz nad reliefami galerii (3,9 m), pas pod płytami pierścienia |
| Płyty pierścienia bez fasady holu | `Floor1Art.wants_fascia` bez Asyrii | krenelaż na balustradach, gładki alabaster pod nim |
| Herbaciarnia | model ×(1,233; 1; 0,959), obniżony 0,4; węzły `roof_perch*` modelu przemianowane, własny `roof_perch` na okapie greyboksu; okap greyboksu ze strzechą (dach piętrowy) | kalenica modelu w masie powłoki (ściana do 14 m), krawędź strzechy modelu 1,9 m — grzęda zostaje na okapie 3,9 m; weranda równo ze żwirem |
| Drzwi herbaciarni | (polish-east) naprawione w modelu: drzwi wyśrodkowane (z −1…+1 od środka pokoju), słupki progowe tuż za otworem, nadproże nad 2,6 m, bez progu, słupka i liścia w otworze; dwa liście shoji odsunięte w torach obok | `teahouse.py`: `DOOR = (−1, 1)`; wnętrze (słupki, listwa wschodniej ściany przerwana przy drzwiach) też; skala z 1,0 (było 0,9589), model z −81,97 |
| Misa tsukubai | (polish-east) osobna część modelu `basin` (pivot na ziemi), w ogrodzie ×0,7 i podniesiona o 0,25: pierścień kamienia 12 cm nad żwirem, woda kilka cm wyżej, bambusowa rynienka < 0,3 m; bez kolizji | wcześniej cała misa (rant 0,38 → −0,02 po obniżeniu domu) leżała pod żwirem: widać było tylko bambus |
| Brama Chorsabadu | drzwi `door_l/_r` ukryte | Egipt zamyka przejście swoimi skrzydłami |
| Most ogrodowy `garden_bridge` | nie postawiony | bez kolizji nie da się po nim chodzić; staw w zachodnim ramieniu |
| Rydwan, klatki, rusztowanie | bryły proceduralne (walce, torusy, deski) | zestaw nie ma tych modeli |
| Posągi geniuszy | stele z reliefów na blokach alabastru | zestaw nie ma wolnostojącego geniusza; bryły osłon Lamassu wypełnione co do centymetra |
| Maty wystawowe | płaskie (1,5 cm), bez kolizji | podniesiony cokół wymagałby `y` slotów — gałąź wrogów |

### Polecenia
- Kontrola bez okna: `bash tools/run_tour.sh dry` (95 widoków OK).
- Zrzuty (kontroler, nocą, bez dźwięku): `bash tools/run_tour.sh shots --preset=high --only=assyria_gate_hall,assyria_courtyard_wide,assyria_nimrud_long,assyria_lions_pit,asia_china_buddha,asia_korea_hwacha,asia_armor_shoji,asia_garden_teahouse,asia_garden_entry,blackout_courtyard,blackout_china && bash tools/run_tour.sh perf --preset=high`

## 10. Ryzyka

| Ryzyko | Odpowiedź |
|---|---|
| Kalenica herbaciarni w masie powłoki (ściana ogród–herbaciarnia do 14 m) | grzęda zostaje na okapie (własny `roof_perch` w punkcie greyboksu, węzły modelu przemianowane); pełny dach herbaciarni dopiero po zmianie sal (po etapie dachu) — §9 „Odstępstwa” |
| Misa tsukubai bez kolizji w rogu areny | (polish-east) osobna część, płaski pierścień 12 cm, rynienka < 0,3 m; poza trasami doskoku; „Do sprawdzenia w oknie” |
| Brama księżycowa: dolne narożniki panelu bez kolizji w 4 m otworze | znane z katalogu; przejścia 4 m dla wrogów — zostaje; „Do sprawdzenia w oknie” (przycinanie kamerą przy skraju) |
| Psy Fu z `exhibit()` wyglądają jak śpiący wrogowie | (polish-east) posągi są z szarego kamienia (`Floor1ArtAsia.stone_dog()`: albedo psa w skali szarości, ciepłe, płaski ORM bez metalu, bez emisji — żywy pies to zielony brąz ze świecącymi oczami) |
| Zmiana bryły `lamassu`/cokołu hwachy psuje testy chodzenia greyboksu | `test_floor1_northwest_walk`, `test_floor1_east_walk` w pełnym zestawie; przejście bramy 3,0 m |
| Za ciemno mimo `lamp_energy` | wypełnienia; metryki jasności tylko z okna → kontroler: `run_tour.sh shots --only=assyria_*,asia_*` |
| Inne gałęzie w `assyria.gd`/`asia.gd`/`floor1_art.gd`/`floor1_light_recipe.gd` | zmiany punktowe, bloki na końcu słowników; scalenie `pietro-1` na końcu |

## Do sprawdzenia w oknie

(polecenie dla kontrolera nocą: `bash tools/run_tour.sh shots --preset=high --only=<lista>` i `bash tools/run_tour.sh perf --preset=high`; widoki z zadania 6)

- **Asyria:** Brama Chorsabadu z hali (`assyria_gate_hall`, `assyria_gate_lamassu`): posągi w bryłach, pochodnie na wieżach, łuk z glazury; czy pas reliefów `hunt` nie przecina się z bramą. Pochodnie `asy_torch` przy światłach 0,2 m od ściany: uchwyt w pasie płyt — czy czyta się jak lampa na płycie. Stele (`relief_slab`) w Nimrud i hali: oba lica, czapka. Dziedziniec: bloki geniuszy z fryzem i stele, kolumny cedrowe (kapitele z `asy_corbel` na 13 m), panele przebudzenia 0,13 przed pasem rydwanów (czy „wystają” za bardzo), krenelaż na 16 m na tle nieba (`assyria_courtyard_up`), trójnogi przy północnej ścianie. Sala Lwów: pas lwów pod płytami pierścienia (górne 0,4 m płyt w grubości płyty), fryz na 3,9 m, krenelaż na balustradach, rydwan / klatki / rusztowanie — jakość brył proceduralnych. Czarny Obelisk (przyciemnione płyty tekstu). **Jasność**: Nimrud, hala bramy, Sala Lwów — porównać średnią luminancję z Grecją/Egiptem (`metrics_high.json`): cel ≥ Egipt.
- **Azja:** Budda na podeście (dado wokół, kadzielnica na stopniu), snop i Halo (`asia_china_buddha`); psy Fu z `exhibit()` (czy nie czytają się jak śpiący wrogowie — zamierzone: posągi); słupy (trzon Ø0,8, głowica 1,3 pod stropem 12 m); lampiony na sznurach do stropu (czy sznur 1 cm nie znika z daleka); gabloty z brązami. Korea: wóz hwacha ×1 obrócony do łuku, lakowy cokół między stojakiem a wozem; dzwonnica (belka bijaka nad krawędzią platformy, kołysanie); tryptyki zwojów za „parawany”; okna kratowe świecą. Zbrojownia: stojaki (sznurowanie ×3), shoji świecą, andony w rogach, wielkie zwoje. **Ogród:** herbaciarnia — elewacje na licach (shoji świecą), weranda równo ze żwirem (model obniżony 0,4), misa tsukubai 0,22 wys. bez kolizji (x 14,6…17,2, z −83…−80: czy przeszkadza przy drzwiach przystani), **drzwi**: otwory modelu (−83,4…−82,7 i −81,7…−81,0) a otwór greyboksu −83…−81 — środkowy liść shoji modelu (−82,46…−82,08) bez kolizji w środku otworu (gracz przechodzi przez niego: do poprawy w modelu `tools/art/models/teahouse.py` — przesunąć liść, drzwi na z −1…+1); **dach dwuspadowy piętrowy** (niska spódnica modelu 1,9–3,2 m + strzecha okapu greyboksu 3,5–3,9 — Generał na górnym okapie); wiśnia z kwiatami nad bryłą pnia, płatki na ziemi; głazy (a/c), latarnie Kasuga (światło 1,36), staw (brzeg 0,13); księżyc przez trzy studnie. Wnętrze herbaciarni: rozciągnięte 1,33 w x (tokonoma, palenisko) — czy nie razi; lakowa skrzynia-stolik obok paleniska; lampa papierowa modelu (7; 2,8). Brama księżycowa w 4 m otworach (Chiny–porcelana, porcelana–Korea, Korea–zbrojownia): dolne narożniki panelu bez kolizji — przycinanie przy skraju przejścia.

## Stan prac / co dalej

**Zadania 1–7 zrobione** (10.10): plan, szkielet, Asyria i Azja ubrane (`Floor1ArtAssyria`, `Floor1ArtAsia`, 21 sal w `ROOM_STYLES` i w przepisie światła), kurz / żar / płatki, wycieczka (95 widoków `dry` OK), maty wystawowe pod żywymi eksponatami Azji (uwaga kontrolera 10.10), `pietro-1` scalone, pełny zestaw 2114 zielonych (1 chwiejny piaskownicy, zielony osobno), 0 linii ERROR. Testy skrzydeł: `tests/integration/test_floor1_art_east.gd` (12).

**Co dalej (poza tym etapem):**
- Kontroler nocą: zrzuty i `perf` z §9 „Polecenia”; lista „Do sprawdzenia w oknie” wyżej (jasność Asyrii, herbaciarnia, brama księżycowa).
- (zrobione w gałęzi `polish-east`, niżej) Model `teahouse`: drzwi wyśrodkowane, misa jako osobna część. Zostaje „pełny dach herbaciarni po etapie dachu” (pokój ogrodu nad herbaciarnią, strop 14) i ewentualna kolizja werandy.
- Ameryki i dach: osobny etap po Wężu (nie dotykać `americas.gd`/`roof.gd`).
- Gałąź `enemies-east`: żywe psy Fu / zbroje stają na matach `ExhibitMat_*` (bohaterowie `ExhibitMats_<sala>`); jeśli wrogowie dostaną własne cokoły (podniesione `y` slotów), maty zdjąć (`Floor1ArtAsia._slot_mats`).
- Asyria: wojownicy/lwy z reliefów ze slotów na gołej podłodze (hala bramy, Nimrud, dół) — kontekst wystawowy (płyta za plecami / cokół) do ustalenia z gałęzią wrogów zachodu (wychodzą ze ścian).

### Poprawki po przeglądzie (gałąź `polish-east`, 10.10)

Dziewięć poprawek świeżo ubranych skrzydeł (TDD tam, gdzie sprawdzalne; testy w `test_floor1_art_east`, `test_floor1_art_fit`, nowy `test_floor1_particles`):

1. **Pies Fu zestawu 2 w Chinach** `(6,0; −55,5)` → `(6,6; −55,5)` (`asia.gd`): leżąc na przekątnej wchodził ogonem 8 cm (zasięgiem wzrokowym znacznie głębiej) w zachodnią gablotę (x 4–5). Mata wystawowa idzie za slotem (maty powstają ze slotów); jej zachodni narożnik wchodzi 15 cm pod podstawę gabloty (płaska płyta 1,5 cm, niewidoczna).
2. **Test wolnej przestrzeni żywych eksponatów**: zamiast osiowego pudełka 1,4 × 1,2 × 1,4 — kapsuły ułożone wg `yaw` slotu i `intersect_shape` na kolizji greyboksu oraz na ciałach-zastępnikach wyglądów rekwizytów (pies: kolider wroga r 0,55 / długość 2,4 leżący wzdłuż ciała oraz zasięg wzrokowy modelu r 0,68 / 3,3; zbroja r 0,42 / 2,0). Czerwony na starym slocie, zielony po przesunięciu; żaden inny slot nie wypadł.
3. **`test_floor1_art_fit`**: nie pomija roli `door`; `_reach` dostaje przesunięcie liścia od zawiasu (pozycja `Visual`) jako środek pudełka; test sprawdza też, że zmierzono > 10 liści.
4. **Płatki i kartki**: `alpha_curve` czyta tylko kanał czerwony tekstury (biały gradient = stała 1, listki „wyskakiwały”). `make_petals` i `make_pages` (ten sam błąd) wygaszają teraz przez `color_ramp` (0 → 1 → 0 jak żar), materiał płatka dostał `TRANSPARENCY_ALPHA`, kartka — własną kopię siatki i papieru z przezroczystością (lot wrogich ksiąg zostaje nieprzezroczysty).
5. Martwy kod usunięty: `MAT_KINDS`, `CINNABAR`, `BELL_SHIFT`, `BAND_DEPTH`, nieużywany preload `Assyria` (w `floor1_art_assyria.gd`).
6. **`Floor1Art.door_leaf`** pyta skrzydło przez `wing.has_method(&"door_leaf")` zamiast `wing_of(...) == Floor1ArtAsia`; test przypina hak (Azja ma liść, Asyria i sala bez skrzydła — liście kitu).
7. **Posągi psów Fu są z szarego kamienia** (`Floor1ArtAsia.stone_dog()`): albedo żywego psa w skali szarości, ciepłe, płaski ORM bez metalu, ta sama normalna, bez emisji (żywy: zielony brąz ze świecącymi oczami i perłą). Zestaw tekstur rejestrowany raz w `ArtLibrary` (`register_generated`). Uwaga: w trybie bez okna `Texture2D.get_image()` oddaje własny obraz tekstury — kopia przez `Image.copy_from` (inaczej przerabiało się też żywego psa; w teście tak samo).
8. **Rekwizyty bez kolizji, które wyglądają na lite**: (a) belka bijaka dzwonnicy skrócona w kodzie (`_shorten_striker`, czubek najwyżej 1,7 m od osi, platforma kończy się na 1,85) — nie wisi już nad uliczką 0,85 m na wysokości oczu; (b) cztery trójnogi ognia mają bryłę 0,62 × 1,4 × 0,62 (`assyria.gd` `TRIPODS`, kit `brazier`, wygląd pusty — trójnóg rysuje oprawa); (c) cokoły i bryły posągów psów Fu wydłużone ku południowej ścianie (cokół 2,75, bryła 2,55 w z −40,775): pysk i ogon stoją nad kamieniem i w kolizji, a strona żywych psów bez zmian; model wyśrodkowany w bryle.
9. **Model herbaciarni** (`teahouse.py`, przebudowany headless: Blender `-b`, bez renderów; `teahouse` 3 192 + `basin` 148 trójkątów, wnętrze 1 610): drzwi `DOOR = (−1, 1)` (były 0..2, o metr obok), słupki progowe osie 12 cm za otworem (lico wewnętrzne 4 cm), nadproże (spód 2,6 po obniżeniu), brak progu, słupka i liścia w otworze; dwa liście shoji odsunięte w torach (szyny) przed sąsiednim przęsłem; kamienie schodowe na osi drzwi; wnętrze: listwa wschodniej ściany przerwana przy słupkach drzwi; misa jako osobna część `basin` (pivot na ziemi, znacznik `basin_water` na niej; w rejestrze). Dopasowanie (`Floor1ArtAsia`): skala z 1,0 (było 0,9589; model ma 8 m jak pokój), początek z −81,97; misa ×0,7 i +0,25 (pierścień 12 cm nad żwirem, bambus < 0,3 m; wcześniej leżała pod żwirem). Test: żaden trójkąt domu ani wnętrza nie wchodzi w przejście (x 10,5…14, y 0,1…2,55, z −83…−81) i słupki stoją ≤ 25 cm od krawędzi otworu po obu stronach; grzęda Generała i przystań działają (`--filter=general,haven,floor1_art`).

Pełny zestaw po scaleniu `pietro-1` (3ecb3b6): **2214 zielonych, 0 czerwonych**, 0 linii ERROR.

**Do sprawdzenia w oknie (nowe):** kamienne posągi psów Fu obok żywych (czy różnica czyta się z daleka; zarazem czy szarość nie wygląda na „wyłączone” tekstury); wydłużone cokoły posągów (czy 2,75 m cokół nie razi przy żaluzji); herbaciarnia z ogrodu: drzwi w osi z dwoma odsuniętymi liśćmi i szynami, nadproże, misa jako niski pierścień z bambusową rynienką (czy czyta się, czy za mała); trójnogi (bryła 0,62 — nogi wystają na 0,66, sprawdzić dotyk); dzwonnica z krótszą belką bijaka; płatki w ogrodzie i kartki w bibliotece — miękkie pojawianie się i znikanie (gęstość: ten sam `amount`).
