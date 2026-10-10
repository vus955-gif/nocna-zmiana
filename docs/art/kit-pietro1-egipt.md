# Katalog grafiki: Piętro I — skrzydło egipskie

> Gałąź `art-egypt`. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§5.1, §7.3, §7.4, §10). Plan: `docs/superpowers/plans/2026-10-02-art-egipt.md`.
> Wszystko powstaje skryptami Blendera w tle (`tools/art/models/*.py`, wspólne `tools/art/artlib/egypt.py`, `egypt_paint.py`, `face.py`), budowa jednym poleceniem: `bash tools/art/build_art.sh <nazwy>` (szybko: `FAST=1`). Podglądy Cycles: `tests/_out/art/<id>.png` (+ `_closeup`, ujęcia dodatkowe).
> **Osie:** wszystkie liczby poniżej są w osiach **Godota** (x w prawo, y w górę, −z = przód modelu). Blender (x, y, z) → Godot (x, z, −y). Każdy model patrzy na **−Z**. Lewa strona postaci = **−X**.

## 1. Paleta i gęstości

| Klasa | px/m | Modele |
|---|---|---|
| pola kafelkowe, architektura | 64 | tekstury pól, `egypt_*` (pasy, kolumny, portale, okna) |
| drzwi | 96 | `egypt_seal_door_*`, `egypt_plinth` |
| duże eksponaty | 112–160 | `pharaoh_statue` 112, `obelisk` 112, `amenhotep_head` 128, `sarcophagus` 128, `sekhmet` 160, `shabti_case` 160 |
| rekwizyty | 96–192 | obóz 96–128, `coffin` 192, `egypt_torch_lamp` / `egypt_spotlight` 192 |
| drobne eksponaty, wróg | 256 | `canopic_jars`, `camp_lamp`, `mummy` |
| pismo | 384 | `rosetta_stone` |
| strażnik | 112 | `colossus` (tron `colossus_throne` 72) |
| rój | 512 | `scarab*` |

Rampy (słownik `P`, `artlib/egypt.py`): piaskowiec, granit czerwony / różowy skaleń / czarny granodioryt / szary, malatura egipska (błękit, malachit, czerwona i żółta ochra, czerń, wapno, grunt ochrowy, karnacja), turkus (fajans), lapis (strop), kalcyt, len, żywica, sucha skóra, płótno, papier, skarabeusz (opalizujący), żar słońca, płomień.

**Malatura pikselowa** (`artlib/egypt_paint.py`): ~35 hieroglifów jako bitmapy (kolory wg konwencji), skład w kwadraty, kolumny, linie i kartusze; malarz figur w kanonie egipskim (tragarz ofiar, adorant, siedzące bóstwo z głową człowieka / szakala / sokoła, korony chepresz i nemes), bordiura blokowa, fryz chekeru, sema-tawy. Materiały próbkują płótno teksel po tekselu (jeden piksel rysunku = jeden teksel), z łuszczeniem farby i reliefem wklęsłym.

## 2. Pola kafelkowe (64 px/m, `ArtLibrary.arch_tile`)

| Tekstura | Kafel | Co to jest | Gdzie |
|---|---|---|---|
| `sandstone_ashlar` | 6 × 3 m | ciosy piaskowca 0,75 m w wiązaniu, laminacja, zacieki | ściany galerii i Sali Kolosa |
| `sandstone` | 2 × 2 m | piaskowiec gładki | ościeża, progi, gładkie bryły |
| `granite_floor` | 4 × 4 m | polerowane płyty ciemnego granitu 2 × 1 m (odbija księżyc) | posadzki |
| `granite_red` | 2 × 2 m | polerowany czerwony granit | progi, lica cokołów |
| `star_ceiling` | 4 × 4 m | lapis z żółtymi gwiazdami co 0,25 m, łuszczenie | stropy |
| `hieroglyph_band` | 8 × 1 m | fryz: bordiury blokowe, dwie linie dużych znaków, kartusze | lico `egypt_frieze_*` (albo pas ściany o wysokości 1 m na pełnym metrze) |
| `tomb_wall` | 8 × 4 m | malowidło grobowe: chekeru, bóstwa z ołtarzem ofiarnym, procesja tragarzy, czerwony cokół | ściany grobowca (strop na 4 m albo niżej) |

Style pomieszczeń dopisane do `ArtKit.ROOMS`: `egypt_gallery` (= `egypt_vestibule`), `egypt_colossus_hall`, `egypt_tomb` (pola, pasy, ościeżnice). Belki `egypt_beam_4m` kładzie poziom (poprzecznie co 4 m).

## 3. Zestaw architektury (`ArtLibrary.KIT`, konwencja zestawu: początek w środku podstawy, front −Z)

| Id | Rozmiar (x × y × z) | Trójkąty | Opis, oś i datum | Rozmieszczenie |
|---|---|---|---|---|
| `egypt_dado_4m/2m/1m/05m` | L × 1,2 × 0,15 | 30 | cokół: czarny granit, polerowane płyty czerwonego granitu (spoina co 1 m), malowany wałek; datum = podłoga, płaszczyzna ściany z = 0 | dół ścian galerii, Sali Kolosa |
| `egypt_frieze_*` | L × 1,14 × 0,1 | 46 | fryz: lico 1 m mapowane w świecie polem `hieroglyph_band` między wałkami; **datum = dolna krawędź lica, na pełnym metrze** (np. 7,0); wałki wystają 0,07 m | ok. 7 m (galeria), 10 m (Sala Kolosa) |
| `egypt_cornice_*` | L × 1,0 × 0,72 | 44 | gzyms kawetowy z malowanymi liśćmi (cykl 0,5 m: moduły łączą się bez szwu); datum = sufit (początek u góry) | pod stropem |
| `egypt_beam_4m/2m/1m` | L × 0,7 × 0,6 | 44 | malowana belka-architraw: bordiury, linia znaków na żółtym pasie, gwiazdy na podsufitce; datum = sufit | w poprzek galerii co 4 m |
| `egypt_column` | 2,1 × 11 × 2,1 | 2 712 | kolumna papirusowa wiązkowa, kapitel zamknięty, malowane liście u stopy i opaski; skalować Y do stropu | dwa rzędy w galerii |
| `egypt_column_open` | 3,1 × 11 × 3,1 | 2 712 | kolumna kielichowa (Karnak): na bębnie król przed bogami, kartusze; kapitel otwarty | Sala Kolosa (14 m: skala Y 1,27) |
| `*_cracked` (zestawy tekstur) | — | — | `egypt_column_cracked`, `egypt_column_open_cracked`: pęknięcia i odpryski po 1. trafieniu promieniem | podmiana materiału |
| `egypt_column_stump`, `egypt_column_open_stump` | jw. × 3,6–4,0 | 678 / 582 | kolumna złamana (świeży przełom) po 2. trafieniu | podmiana modelu |
| `egypt_column_drums` | ok. 3,5 × 1,7 × 3 | 292 | gruz: części `drum_a`, `drum_b`, `chunk_a..c` (osie w środkach) | odłamki fizyczne przy upadku |
| `egypt_portal_4m` | 6,3 × 6,6 × 0,9 | 546 | portal egipski otworu 4 × 4,5: ościeża z królem i kolumnami tekstu, wałek, nadproże z uskrzydloną tarczą słońca, gzyms kawetowy; początek = środek podłogi otworu na licu ściany | wejścia do galerii |
| `egypt_doorframe_2x2_8` | 3,2 × 4,1 × 0,7 | 546 | to samo dla drzwi 2 × 2,8 | sale boczne |
| `egypt_portal_great` | 10,9 × 10,3 × 1,3 | 522 | pylon do Bramy Chorsabadu, otwór 6 × 7,5, skośne ościeża z dwoma rejestrami scen | północna ściana Sali Kolosa |
| `egypt_seal_door_l/_r` | 3,0 × 7,5 × 0,33 | 1 756 | skrzydła bramy pieczęci: cedr, brązowe pasy z nitami, złocone obrzeże; na styku po połowie tarczy słońca z gniazdem i uskrzydlonej tarczy u góry. Rama skrzydła jak w zestawie drzwi (początek w środku podstawy, **lico dekoracyjne +Z** = pokój A, Sala Kolosa; zawias na zewnętrznej krawędzi). Znacznik **`SealSocket`** (lewe skrzydło, (1,5; 1,6; 0,165)) | brama zapieczętowana Pieczęcią Słońca |
| `egypt_boarded_doorway` | 2,4 × 2,9 × 0,2 | 528 | zabite deskami przejście 2 × 2,8 „REMONT / ZAKAZ WSTĘPU”: rdzeń z listwami, **`plank_1..8`** i **`sign`** jako osobne części (osie w środkach) do strącania; deski po stronie pokoju (−Z) | grobowiec → Grecja |
| `egypt_clerestory_3m` | 3,3 × 2,1 × 0,7 | 490 | okno clerestorium 3 × 2: kamienna krata z 4 płyt (pasiaste snopy), ościeże 0,6 (skalować Z do muru), pręty, szyba `egypt_clerestory_3m_glass` bez cienia; początek = środek dolnej krawędzi otworu na licu ściany | 8–10 m w ścianach galerii |
| `egypt_plinth` | 1,0 × 0,6 × 1,0 | 114 | cokół posągu (czarny cokół, czerwony granit, wałek); skalować do rozmiaru | pod eksponaty |
| `egypt_torch_lamp` | 0,2 × 0,8 × 0,35 | 474 | lampa-pochodnia: mosiężna płyta z lotosem, ramię, kielich, żarówka-płomień (emisja); **oprawa: początek = światło**, uchwyt 0,32 m w +Z do ściany; znacznik `Light` | ściany co 8 m, 3,6 m nad podłogą |
| `egypt_spotlight` | 0,4 × 0,6 × 0,5 | 852 | reflektor muzealny w jarzmie z klamrą; początek = środek soczewki, światło w −Z, klamra 0,45 m w górę; znacznik `Light` | ciepłe snopy na kolosy (na belkach) |

## 4. Eksponaty i rekwizyty (`ArtLibrary.REGISTRY`, front −Z)

| Id | Rozmiar | Trójkąty | Części / znaczniki | Rozmieszczenie, uwagi |
|---|---|---|---|---|
| `pharaoh_statue` | 1,9 × 6,85 × 2,7 | 7 144 | `pharaoh_statue` (cokół), `pharaoh_figure` | szpaler kroczących królów wzdłuż galerii (czarny granodioryt), co 8 m po obu stronach; strażnik sięga mu do kolana |
| `sekhmet` | 0,6 × 2,15 × 1,2 | 4 458 | `sekhmet`, **`head`** (oś szyi (0; 1,50; 0): rząd posągów może odwracać głowy za strażnikiem) | rząd 6–8 przy ścianie |
| `amenhotep_head` | 1,6 × 2,5 × 1,5 | 4 714 | `amenhotep_head` (blok), `amenhotep_face` | kolosalna głowa, czerwony granit, utrącony nos i korona |
| `obelisk` | 1,5 × 6,3 × 1,5 | 98 | `obelisk` | para przed Salą Kolosa; złocony piramidion |
| `sarcophagus` | 2,7 × 1,5 × 1,4 | 516 | `sarcophagus`, **`lid`** (oś: środek spodu wieka, y 1,05 — przesuwać w X, przechylać w Z), znacznik **`MummySpawn`** (0; 0,28; 0) | zasadzki mumii (obóz, grobowiec); zestaw `sarcophagus_red` |
| `coffin` | 0,8 × 2,0 × 0,7 | 1 796 | `coffin` (skrzynia + stojak), **`lid`** (oś na dolnej przedniej krawędzi (0; 0,12; −0,22): obrót wokół X wywraca wieko do przodu), **`MummySpawn`** (0; 1,07; 0,05) | stojące trumny; zestaw `coffin_black` |
| `rosetta_stone` | 0,8 × 1,12 × 0,3 | 198 | `rosetta_stone` | trzy pisma (hieroglify, demotyka, grecki tekst dekretu), 384 px/m |
| `rosetta_case` | 1,2 × 1,95 × 0,8 | 888 | `rosetta_case`, `rosetta_case_glass` (do stłuczenia), **`StoneSpot`** (0; 0,62; 0) = gdzie stawiać `rosetta_stone` | Przedsionek Rosetty; mosiężna tabliczka „KAMIEŃ Z ROSETTY / 196 P.N.E.” |
| `canopic_jars` | 1,3 × 0,6 × 0,35 | 2 750 | `canopic_jars` (deska), `jar_imsety`, `jar_hapy`, `jar_duamutef`, `jar_qebehsenuef` | w gablocie lub na cokole |
| `shabti_case` | 1,2 × 1,95 × 0,5 | 3 906 | `shabti_case`, `shabti_case_glass` (szyby i półki) | gablota z ~50 figurkami z fajansu |
| `camp_tent` | 2,6 × 2,7 × 3,4 | 882 | `camp_tent`, **`LampHook`** (pod kalenicą z przodu) | obóz 1898 w połowie galerii |
| `camp_crate` / `_long` / `_open` | 0,9 × 0,6 × 0,6 / 1,6 × 0,5 × 0,45 / 1,0 × 0,8 × 0,8 | 462 / 462 / 1 304 | jedna siatka | szablony „EKSPEDYCJA 1898 / TEBY”, „NARZĘDZIA”; zestaw `camp_crate_b` („OSTROŻNIE / NIE RZUCAĆ”, „MUZEUM”) |
| `camp_lamp` | 0,15 × 0,37 × 0,15 | 660 | `camp_lamp`, `camp_lamp_glass`, **`Light`** (płomień, 0,17 m) | na stole, na haku namiotu; ciepłe OmniLight |
| `camp_table` | 1,4 × 0,95 × 0,8 | 814 | jedna siatka | mapa Teb (TEBY, KARNAK, LUKSOR), hełm korkowy, notes, kompas, kubek |
| `camp_rifle_rack` | 1,5 × 1,3 × 0,7 | 840 | `camp_rifle_rack`, **`weapon_spot`** (0; 0,92; −0,22) = miejsce strzelby (pusta podpórka między dwoma karabinami) | tu leży STRZELBA (pickup), oświetlona |
| `camp_chair` | 0,55 × 0,85 × 0,55 | 208 | jedna siatka | przy stole |

## 5. Kolos Ramzesa (`colossus` + `colossus_throne`)

Siedzący kolos ~9 m (szczyt podwójnej korony 8,96 m) na tronie; czerwony granit z resztkami malatury. **Dwa modele postawione w tym samym miejscu i z tym samym obrotem**: statyczny tron `colossus_throne` (72 px/m, 218 tr., 3,9 × 5,95 × 5,6 m, kolizja z poziomu) i ciało `colossus` (112 px/m, **20 960 tr.**, atlas 2336 × 1280, 23 części). Początek obu: podłoga pod stawami bioder. Cokół tronu ma 0,6 m — stopy kolosa stoją na nim.

### Hierarchia i osie (Godot, rest = siedzi)

| Część | Oś (x; y; z) | Rodzic | Do czego |
|---|---|---|---|
| `pelvis` | (0; 3,30; 0) | — (korzeń ciała) | wstawanie: przesunięcie całego ciała |
| `thigh_l` / `thigh_r` | (∓0,45; 3,30; 0) | pelvis | udo poziomo do przodu (z kiltem na udzie) |
| `shin_l` / `shin_r` | (∓0,48; 3,32; −2,30) | thigh_* | goleń pionowo |
| `foot_l` / `foot_r` | (∓0,50; 1,00; −2,45) | shin_* | stopa |
| `torso` | (0; 4,10; 0,05) | pelvis | tułów, naszyjnik |
| `head` | (0; 6,08; 0,10) | torso | twarz, nemes, podwójna korona, broda |
| `eyes` | (0; 6,87; −0,61) | head | dwie wkładki oczu (emisja): `set_instance_shader_parameter(&"glow", …)` tylko na tej części = ładowanie promienia |
| `uraeus` | (0; 7,18; −0,66) | head | kobra na czole — **słaby punkt** (jej oś = środek kaptura); można ją odstrzelić / ukryć |
| `upperarm_l` / `_r` | (∓1,05; 5,72; 0,12) | torso | bark |
| `forearm_l` / `_r` | (∓1,02; 4,32; −0,20) | upperarm_* | łokieć (przedramię leży na udzie) |
| `palm_l` / `_r` | (∓0,72; 3,98; −1,42) | forearm_* | nadgarstek: lewa dłoń płasko na kolanie, prawa pięść z futerałem mekes |
| `chest_plate_1..3` | (−0,46; 5,02; −0,50), (0,05; 4,68; −0,52), (0,44; 4,36; −0,41) | torso | płyty granitu przykrywające pęknięcia — strącić / ukryć, gdy pęknięcie „otwiera się” |
| `crack_1..3` | jw. (oś = środek pęknięcia na powierzchni piersi) | torso | świecące szczeliny (emisja „słońce”) w zagłębieniach pod płytami; słabe punkty fazy 2–3 |

**Znaczniki** (Node3D): `eye_l` (−0,193; 6,87; −0,625), `eye_r` (0,193; 6,87; −0,625) — dzieci `head`, punkty wyjścia promienia (kierunek: −Z głowy); `hand_l` (−0,66; 3,78; −2,00), `hand_r` (0,66; 3,79; −1,85) — dzieci `palm_*`, pod dłońmi: punkt kontaktu uderzenia (cień dłoni na posadzce rzutować stąd w dół); `swarm_l` (−1,62; 1,0; −0,9), `swarm_r` (1,62; 1,0; −0,9) — dzieci tronu, otwory w bokach tronu, z których wylatują roje skarabeuszy.

### Pozy dla kodu (sprawdzone ujęciem `egypt_vignette_standing.png`)
- **Obrót na tronie (fazy 1–2):** `torso.rotation.y` do ±25°, `head.rotation.y` do ±35°, głowa pochylona `head.rotation.x` +5…+15° (patrzy w dół na strażnika).
- **Uderzenie dłonią:** `upperarm.rotation.x` −40° (unosi), potem +10° (opada), `forearm.rotation.x` ±20°; kontakt w `hand_*`.
- **Zamach przedramieniem nisko:** `upperarm.rotation.z` ±30°, `forearm.rotation.y` ±70° (zamiata przed kolanami).
- **Wstawanie (faza 3):** `pelvis.position` = (0; 5,02; −4,4) (biodra na wysokości stojącego, krok przed tron), `thigh_*.rotation.x` = −90°, `shin_*.rotation.x` = +90° (kolano proste), ramiona w dół: `forearm_*.rotation.x` ≈ −70°. Wzrost stojącego ok. 10,7 m (sala ma 14 m). Chód: przeciwstawne `thigh.rotation.x` ±20° wokół −90°, `shin` 0…+35°.
- Części są sztywne: zagięcia w stawach kryją kopuły końców brył (kilt na udach, naramienniki).

Emisja (`EXTRAS`: 3,0): oczy i szczeliny. W spoczynku shader eksponatu daje 45% (oczy tlą się), `glow` → słońce.

**Jak gra go porusza** (`src/game/floor1/guardians/colossus_rig.gd`, gałąź `guard-colossus`): ramiona nie obracają się o stałe kąty z listy wyżej, tylko celują łokciem i dłonią w punkty (`LimbIK`). Siedzący kolos ma barki na ~5,7 m, a ramię ~3,35 m, więc do posadzki sięga, **rozsuwając człony w stawach** (bark, łokieć, nadgarstek) — szczeliny wypełnia złote światło. Wstawanie i chód: nogi przez IK dwóch kości (stopy płasko na posadzce, kostka 0,4 m nad nią). Kolumny Sali Kolosa (`egypt_column_open`, skala Y 14/11) stawia skrypt strażnika; po 2. trafieniu promieniem zestaw `egypt_column_open_cracked`, po 3. `egypt_column_open_stump` + `egypt_column_drums` u stopy, a trzon tnie się (`MeshShards.slices`) na spadające bębny.

## 6. Mumia (`mummy`, 256 px/m, 5 968 tr.) i szczątki

Wysoka ok. 1,8 m, lekko przygarbiona; len w spiralnych pasach (cień pod zakładką), plamy żywicy, rozdarcia z wyschniętą skórą, szczelina na oczy z dwoma żarami, rozdarte usta z zębami. Rest = stoi, ręce lekko zgięte w dół (pozę z rękami skrzyżowanymi na piersi w sarkofagu ustawia kod).

| Część | Oś (Godot) | Rodzic | Uwagi |
|---|---|---|---|
| `torso` | (0; 1,00; 0) | — | korzeń |
| `head` | (0; 1,52; −0,02) | torso | słaby punkt |
| `arm_l` / `arm_r` | (∓0,20; 1,43; 0) | torso | bark |
| `forearm_l` / `_r` | (∓0,22; 1,13; −0,02) | arm_* | łokieć; dłoń w przedramieniu |
| `leg_l` / `leg_r` | (∓0,10; 0,92; 0) | — | biodro (jak rycerz) |
| `whip_1 > whip_2 > whip_3 > whip_4` | whip_1 (0,21; 0,84; −0,05), kolejne co 0,2 m w dół | forearm_r | **bicz z bandaża**: cztery odcinki po 0,2 m wiszące prosto w dół z prawego nadgarstka; oś każdego na jego górze. Smagnięcie: `whip_1.rotation.x` → wypad do przodu (−90°…−100°), kolejne segmenty z opóźnieniem (fala), a każdy rozciągnąć wzdłuż (scale.y do ×4 → zasięg ~3 m). Zapowiedź 0,6 s: segmenty falują i „rozwijają się” (scale 1 → 1,5) |
| `strip_1` (head), `strip_2` (arm_l), `strip_3` (torso), `strip_4` (leg_l) | początek pasa | jw. | luźne pasy do kołysania |

Znaczniki: `EyeGlow` (0; 1,646; −0,09) — dziecko głowy, między żarami (miejsce OmniLight / sprite’a oczu); `WeakPoint` (0; 1,63; −0,03) — środek głowy. Emisja (`EXTRAS` 2,2): żary oczu.

`mummy_debris` (408 tr.): `scrap_1..3` (zwinięte bandaże), `bone_1` (kość udowa), `bone_2` (żebra) — osie w środkach, do rozrzucenia przy rozpadzie („bandaże, kurz, kości”).

## 7. Skarabeusze (512 px/m)

| Id | Trójkąty | Opis |
|---|---|---|
| `scarab` | 138 | 6 cm, jedna siatka (pod MultiMesh roju 30–40), zamknięte pokrywy, nogi, ząbkowana tarcza głowy; opalizująca zieleń → turkus → złoto na krawędziach płyt (metaliczny, połysk) |
| `scarab_flying` | 164 | w locie: pokrywy uniesione, błoniaste skrzydła; przemiennie z `scarab` albo trzepot przez skalę X |
| `scarab_debris` | 138 | `shell_l`, `shell_r` (pokrywy), `body` |

## 8. Podglądy (najlepsze ujęcia)

- Nastrój całości: `tests/_out/art/egypt_vignette_gallery.png` (40 m galerii złożone z eksportowanych modeli i pól), `egypt_vignette_colossus.png`, `egypt_vignette_standing.png` (kolos wstał — poza ustawiona wyłącznie obrotami części). Skrypt: `"D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup --python tools/art/egypt_vignette.py -- --samples 64` (Cycles w tle, ok. 1 min).
- Kolos: `colossus.png`, `colossus_closeup.png` (twarz), `colossus_chest.png`, `colossus_hands.png`, `colossus_crown.png`, tron: `colossus_throne_side.png` (sema-tawy).
- Zestaw: `egypt_column.png`, `egypt_column_open_drum.png`, `egypt_portal_4m.png`, `egypt_portal_great.png`, `egypt_seal_door_l.png`, `egypt_cornice_4m.png`, `egypt_beam_4m.png`, tekstury `view_tomb_wall.png`, `view_hieroglyph_band.png`.
- Eksponaty: `rosetta_stone_closeup.png`, `sarcophagus.png`, `coffin.png`, `pharaoh_statue.png`, `sekhmet.png`, `canopic_jars.png`, `amenhotep_head.png`; obóz: `camp_tent.png`, `camp_table.png`, `camp_rifle_rack.png`; wrogowie: `mummy.png`, `mummy_closeup.png`, `scarab.png`.

## 9. Sugerowany przepis na światło (dla integratora)
Księżyc zimny (0,55; 0,67; 1,0) przez okna clerestorium — kamienne kraty tną go w pasy, mgła wolumetryczna 0,015–0,02 w galerii; ciepłe reflektory `egypt_spotlight` (1,0; 0,72; 0,42) z dołu/z belek na każdego króla szpaleru i silny klucz na Kolosa (twarz, ureusz, złoto); lampy-pochodnie co 8 m; wyspa obozu z lampą naftową (OmniLight 1,0; 0,6; 0,3) i snopem na stojak ze strzelbą; posadzka z polerowanego granitu robi resztę (SSR).

## 10. Uczciwie: słabe punkty
- Ciała kolosa, królów i mumii to gładka „glina” z metaballi: sylwetka i proporcje czytają się z dystansu, ale anatomia jest uproszczona (twarze są lepsze — rzeźbione polem przesunięć, `artlib/face.py`).
- Atlas kolosa jest duży (2336 × 1280, ~66 MB VRAM z 4 mapami i mipmapami) — jedyny taki egzemplarz w grze.
- Kartusze i teksty są pseudo-hieroglificzne (prawdziwe znaki, losowy skład); grecki tekst Rosetty to prawdziwe pierwsze słowa dekretu.
- Kolumny i portale nie mają kolizji (jak cały zestaw: kolizje z greyboxa).

## 11. Testy i budowa
- `tests/integration/test_art_egypt.gd` (5 testów, bez okna): łańcuchy i znaczniki kolosa, płyty nad pęknięciami, tron; rig mumii i bicz; skarabeusze (rozmiar, budżet, jedna siatka); części i znaczniki eksponatów, zestawy tekstur `ArtLibrary.EGYPT_SETS`; datumy pasów, kolumny 11 m, gniazdo pieczęci, deski, znaczniki `Light`. Budżety prefiksów `egypt_column` (4000) i `egypt_seal_door` (2500) dopisane w `test_art_kit.gd`.
- Przebudowa wszystkiego z Egiptu: `bash tools/art/build_art.sh kit_egypt_walls kit_egypt_columns kit_egypt_portals kit_egypt_fixtures colossus pharaoh_statue sekhmet sarcophagus coffin rosetta exhibits_egypt mummy scarab camp_1898` (ok. 30 min na jednym procesie; `FAST=1` bez AO). Tekstury pól: `python tools/art/build_textures.py sandstone_ashlar sandstone granite_floor granite_red star_ceiling hieroglyph_band tomb_wall`.
