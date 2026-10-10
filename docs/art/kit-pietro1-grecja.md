# Katalog grafiki: Piętro I — skrzydło greckie (Partenon i Pomnik Nereid)

> Gałąź `art-greece`. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§5.3, §7.3, §7.4, §10). Plan: `docs/superpowers/plans/2026-10-02-art-grecja.md`.
> Wszystko powstaje skryptami Blendera w tle: modele `tools/art/models/gr_*.py`, `nereid*.py`, `vases.py`, `casts.py`, `hoplite.py`, `centaur.py`; wspólne `tools/art/artlib/greek.py` (rampy i materiały), `relief.py` (silnik płaskorzeźb 2D), `greek_figures.py` (postacie fryzów), `greek_ornament.py` (ornament), `relief_mesh.py` (wysoki relief jako geometria), `statue.py` (rzeźba z „gliny”), `vase_paint.py` (malatura waz). Budowa: `bash tools/art/build_art.sh <nazwy>` (szybko: `FAST=1`), podglądy Cycles: `tests/_out/art/<id>.png` (+ ujęcia dodatkowe).
> **Osie:** liczby poniżej w osiach **Godota** (x w prawo, y w górę, −z = przód modelu). Blender (x, y, z) → Godot (x, z, −y). Każdy model patrzy na **−Z**. Lewa strona postaci = **−X**.

## 1. Kierunek i gęstości

Najjaśniejsze skrzydło: biały i kremowy marmur pentelicki, który nigdy nie jest płaską bielą — chłodne ciało kamienia z szaroniebieskimi żyłkami, miodowa patyna w plamach, brud w zagłębieniach, jasne „cukrowe” przełomy tam, gdzie kamień pękł, i **ślady pierwotnych barw**: błękit egipski w tle fryzów, metop i kasetonów, czerwień na płaszczach, grzebieniach i tarczach, ochra na włosach, uprzęży i obrzeżach.

| Klasa | px/m | Modele |
|---|---|---|
| pola kafelkowe, architektura | 64 | tekstury pól, `gr_base_*`, `gr_cornice_*`, kolumny, portale, świetlik, kasetony, bordiura, cokoły |
| świątynia Nereid | 96 | `nereid_temple` |
| płaskorzeźby-eksponaty | 128 | `gr_frieze_*`, `gr_bassae_*`, `gr_metope_*`, `nereid_podium`, `cast_frieze_slab`, gabloty |
| rzeźba wolnostojąca | 112–128 | `gr_ped_*` 112, `nereid_a..d` 128, odlewy 96–192 |
| strażnik | 112 | `centaur` |
| wróg, wazy | 256 | `hoplite`, `marble_chips`, `vase_*` |

Rampy (słownik `P`, `artlib/greek.py`): `gr_marble` (chłodny marmur) i `gr_marble_warm` (patyna), `gr_vein`, `gr_grey` (hymetyjski), `gr_grime`, `gr_break` (przełom), `gr_blue` (błękit egipski), `gr_red`, `gr_ochre`, `gr_gold`, `gr_plaster` (gips), `gr_wall_ochre` (czerwień pompejańska), `gr_clay` / `gr_gloss` / `gr_white_slip` / `gr_miltos` (ceramika).

**Jak powstają płaskorzeźby.** `artlib/relief.py` rzeźbi warstwami 2D: każda część postaci to kształt (pole odległości) podniesiony na swoją wysokość z zaokrąglonym brzegiem, który opada na to, co pod nim; dalsze plany niżej, bliższe wyżej (do 5 cm we fryzie Partenonu, ~15 cm w metopach). Fałdy i nacięcia to rowki, grzywy i włosy to tekstura, a na końcu zniszczenia: utrącone głowy (kikut z poszarpanym przełomem), odłamane kończyny, spoiny płyt, wyszczerbienia. Z mapy wysokości liczone są okluzja, krzywizna, krawędzie i wnęki, które maluje `greek.relief_surface`; wysokość trafia do mapy normalnych. Metopy dostają prawdziwą geometrię z tej samej mapy (`relief_mesh.py`, ~4 200 trójkątów), a do normalnych idzie tylko drobny detal. Te same postacie malują wazy (`vase_paint.py`): sylwetki czarnofigurowe z nacięciami albo czerwonofigurowe z konturem i rozcieńczonym szkliwem.

## 2. Pola kafelkowe (64 px/m, `ArtLibrary.arch_tile`)

| Tekstura | Kafel | Co to jest | Gdzie |
|---|---|---|---|
| `gr_ashlar` | 6 × 3 m | mur izodomowy z marmuru: warstwy 0,5 m, bloki 1–2 m, gładkie obrzeże i punktowane lico, bloki chłodne i miodowe | ściany wszystkich sal marmurowych |
| `marble_greek` | 8 × 8 m | posadzka: płyty 2 × 1 m kremowego marmuru w wiązaniu, rozsiane płyty szaroniebieskie, połysk i przetarcia | posadzki sal |
| `gr_marble` | 2 × 2 m | gładki marmur | ościeża, progi, podesty, cokół pomnika |
| `gr_plaster` | 2 × 2 m | ciepły tynk wapienny | stropy, studnie świetlików |
| `gr_wall_paint` | 2 × 2 m | czerwień pompejańska (kolor muzealny) | Sala Waz |
| `gr_limewash` | 4 × 2 m | bielona cegła, łuszcząca się do czerwieni | magazyn odlewów (przystań) |

Style pomieszczeń dopisane do `ArtKit.ROOMS`: `greece_gallery` (Galeria Partenonu: pasy `gr_base_` przy posadzce, **fryz `gr_frieze_` na 1,45 m**, gzyms `gr_cornice_` pod stropem, kasetony `gr_coffer_2m`, bordiura `gr_floor_border_`), `greece_nereid`, `greece_metopes` (belkowanie doryckie pod stropem), `greece_vases` (czerwone ściany), `greece_bassae` (fryz z Bassae na 1,2 m), `greece_casts` (bielona cegła, deski, listwa sosnowa). Wszystkie mają `frame_4` = `gr_portal_4m` i/lub `frame_2_8` = `gr_portal_2m`.

**Zmiany w `ArtKit` (zgodne wstecz):** `RUN_SIZES` / `BAND_SPAN` dla prefiksów `gr_`; `VARIED_RUNS` + `varied_set()`: moduły fryzów (`gr_frieze_`, `gr_bassae_`) dobierają zestaw tekstur z `KIT_SETS` po pozycji, więc 16 m fryzu pokazuje różne płyty; róg bordiury bierze `prefix + "corner"` (dla holu nadal `floor_border_corner`).

## 3. Zestaw architektury (`ArtLibrary.KIT`, konwencja zestawu: początek w środku podstawy, front −Z)

| Id | Rozmiar (x × y × z) | Trójkąty | Opis, oś i datum | Rozmieszczenie |
|---|---|---|---|---|
| `gr_base_4m/2m/1m/05m` | L × 0,6 × 0,13 | 38 | cokół z szarego marmuru hymetyjskiego (spoina co 1 m), wałek, scotia, astragal z paciorkami; datum = podłoga, płaszczyzna ściany z = 0 | dół ścian wszystkich sal marmurowych |
| `gr_frieze_4m` (+ `_b … _f`) | 4 × 1,19 × 0,18 | 28 | **fryz Partenonu**: płyta 12 cm przed ścianą na listwie, korona; relief 1 m (128 px/m) w 6 zestawach: kawalkada, przygotowania (koń stający dęba, marszałek), kwadryga z apobatą, jałówki do ofiary, nosiciele hydrii i kitarzyści, dziewczęta z czarami; **datum = dolna krawędź pasa** | 1,45 m nad posadzką w Galerii Partenonu, dookoła |
| `gr_frieze_2m` (+ `_b`, `_c`) | 2 × 1,19 × 0,18 | 28 | dwaj jeźdźcy / młodzieniec z koniem / starcy | dopasowanie biegu |
| `gr_frieze_1m`, `gr_frieze_05m` | 1 / 0,5 × 1,19 | 28 | gładka płyta (zaginiony fragment fryzu) | dopasowanie biegu |
| `gr_cornice_4m/2m/1m/05m` | L × 1,2 × 0,41 | 316 / 188 / 124 / 92 | gzyms joński: architraw z 3 fasciami, **fryz z malowanym antemionem** (palmety i lotosy w błękicie, czerwieni i ochrze), ząbki co 0,125 m, kymation (jajownik), korona z kapinosem, sima; datum = sufit (wisi) | pod stropem |
| `gr_cornice_doric_4m/2m/1m` | L × 1,6 × 0,49 | 498 / 266 / 150 | belkowanie doryckie: architraw, tenia z regulami i gutami, **tryglify co 1 m na półmetrach** (moduły trzymają rytm; ślady ciemnego błękitu), gładkie metopy z czerwienią, geison z mutulami; datum = sufit | Sala Metop, Sala z Bassae |
| `gr_column_doric` | 2,0 × 8,2 × 2,0 | 2 086 | kolumna Partenonu: blok stylobatu 0,2, trzon ⌀1,5 m z entazą, 20 kanelur o ostrych krawędziach, spoiny bębnów co ~1,15 m, 3 annulusy, echinus, abakus 1,8 m; skalować (lub tylko Y) | osłony / podział Galerii (opcjonalnie) |
| `gr_column_ionic` | 1,1 × 7,0 × 1,0 | 5 266 | jońska: plinta, baza attycka, 24 kanelury z listewkami, jajownik, **spiralne woluty** z przodu i z tyłu, poduszki z przewiązką | sale boczne, portyk |
| `gr_drum` | 1,0 × 1,4 × 1,5 | 520 | przewrócony bęben kolumny (świeży przełom na jednym końcu, guz montażowy) | osłona w Galerii |
| `gr_capital_doric` | 1,8 × 0,9 × 1,8 | 690 | kapitel Partenonu na posadzce, odłupany narożnik | osłona / eksponat |
| `gr_portal_4m` | 5,9 × 5,85 × 0,36 | 1 870 | portal jak drzwi Erechtejonu dla otworu 4 × 4,5: trzy fascie z „uszami”, rozety, fryz z malowanym antemionem, gzyms na dwóch konsolach z wolutami; jedna twarz, początek = środek podłogi otworu na licu ściany, obramienie w −Z | przejścia skrzydła |
| `gr_portal_2m` | 3,3 × 3,75 × 0,27 | 1 742 | to samo dla 2 × 2,8 | drzwi boczne |
| `gr_skylight_4m` | 4,6 × 2,1 × 4,6 | 274 | studnia świetlika 4 × 4 m: profilowana rama na stropie, dwa uskoki (malowany meander na pierwszym), żeliwna krata co 0,5 m, **szkło `gr_skylight_4m_glass`** (bez cienia: księżyc przechodzi, krata tnie snopy); początek = środek otworu na płaszczyźnie stropu, studnia w +Y | strop Galerii co 8 m wzdłuż osi, Sala Nereid |
| `gr_coffer_2m` | 2 × 0,32 × 2 | 74 | kaseton: stopniowane ramy, złocony wałek, **pole błękitu egipskiego ze złotą gwiazdą**; początek na płaszczyźnie stropu, wisi; każdy moduł niesie pół belki | strop Galerii (`coffer` w stylu) |
| `gr_floor_border_4m/2m/1m/05m`, `_corner` | L × 1,0 | 2 | bordiura 1 m: biegnący meander z szarego marmuru na białym, pasy brzegowe; 4 mm nad posadzką; jak bordiura holu (róg 1 × 1) | wzdłuż ścian (`border` w stylu) |
| `gr_plinth_low` | 4,4 × 0,5 × 1,6 | 118 | niski cokół grup frontonowych: szare ciało, białe profile, brązowa tabliczka | końce Galerii (arena) |
| `gr_plinth_block` | 1,0 × 1,1 × 1,0 | 74 | postument pod wazę, głowę, odlew | wszędzie |

## 4. Rzeźba architektoniczna i eksponaty (`ArtLibrary.KIT`, front −Z)

| Id | Rozmiar | Trójkąty | Opis | Rozmieszczenie |
|---|---|---|---|---|
| `gr_metope_a … d` | 1,29 × 1,32 × 0,34 | 4 215 | **metopy południowe** (Lapici i centaury) w wysokim reliefie: (a) Lapita chwyta stającego dęba centaura, płaszcz opada w tło; (b) centaur triumfuje nad powalonym, skóra pantery; (c) zapaśnicy, kolano w końskim boku; (d) centaur z dzbanem nad Lapitą za tarczą. Głowy Lapitów utrącone, błękit w tle; początek = środek dołu na płaszczyźnie ściany | Sala Metop, dół na ~1,6 m (albo w belkowaniu doryckim) |
| `gr_bassae_2m` (+ `_b`, `_c`), `gr_bassae_1m` | 2 × 0,78 × 0,15 | 24 | fryz z Bassae: Amazonomachia (hoplita i Amazonka z peltą, Amazonka konna), upadek Amazonki z konia, Kentauromachia; datum = dolna krawędź | Sala z Bassae, ~1,2 m nad antresolą |
| `gr_ped_reclining` | 2,2 × 1,12 × 0,9 | 6 842 | leżący młodzieniec („Dionizos”/„Ilissos”) na skale z płaszczem, bez głowy i prawej ręki | na `gr_plinth_low`, końce Galerii |
| `gr_ped_goddesses` | 3,4 × 1,34 × 1,32 | 9 142 | trzy boginie wschodniego frontonu: siedząca, siedząca zwrócona, leżąca na jej łonie; bez głów | jw. |
| `gr_ped_seated` | 1,8 × 1,38 × 1,29 | 7 131 | dwie siedzące na skrzyniach („Demeter i Kora”), ramię jednej na barkach drugiej | jw. |
| `gr_ped_horse` | 1,3 × 1,04 × 0,55 | 4 244 | głowa konia Selene: rozdęte nozdrza, otwarty pysk, przełom szyi na bloku | jw. |
| `gr_ped_torso` | 1,07 × 2,22 × 0,6 | 4 264 | tors kolosa („Posejdon”) na żelaznym pręcie na bloku | jw., przy ścianach |
| `nereid_podium` | 7,52 × 4,4 × 4,16 | 70 | podium Pomnika Nereid: stopień, ściany `tile:gr_ashlar`, **fryz bitwy** (0,9 m: hoplici z grzebieniami i okrągłymi tarczami przeciw Lykijczykom, jeźdźcy, polegli) dookoła frontu i boków, **fryz marszu** (0,55 m: żołnierze z tarczami i włóczniami), korona; tył przy ścianie sali | Sala Nereid, przy ścianie, środek na osi |
| `nereid_temple` | 7,8 × 6,81 × 4,23 | 16 575 | świątynia jońska na podium (**postawić na y = 4,4**): stylobat, 4 kolumny z przodu i 2 narożne (części `nereid_column_1..6`), cella z brązowymi drzwiami, architraw, fryz uczty, ząbki, gzyms, fronton z reliefem (władca na tronie i dwór), akroteria; całość 11,2 m (10,3 m do szczytu frontonu) | jw. (sala ≥ 12,5 m) |
| `nereid_a … d` | 0,84–0,9 × 1,91–2,03 × 0,91–1,44 | 8 374 | **nereidy** biegnące po falach w chitonach przyklejonych wiatrem, spódnice strumieniem do tyłu, płaszcze jak żagle; bez głów i rąk; na delfinie / krabie / ptaku / rybie nad rzeźbionymi falami | między kolumnami świątyni: x = −2,07, 0, +2,07, z = −1,65 od środka (na stylobacie y = 4,7, skala 0,95), jedna w sali na `gr_plinth_block` |
| `vase_amphora_bf` | 0,37 × 0,6 × 0,34 | 1 046 | amfora czarnofigurowa: czarne ciało, dwa pola (hoplici nad poległym / jeździec), promienie, języki, palmety | gabloty Sali Waz |
| `vase_amphora_rf` | 0,32 × 0,62 × 0,32 | 1 046 | amfora szyjowa czerwonofigurowa: kitarzysta i młodzieniec, jeździec, meander | jw. |
| `vase_krater` | 0,51 × 0,48 × 0,51 | 952 | krater kielichowy: korowód młodzieńców w himationach, wieniec, wnętrze w czarnym szkliwie | jw. |
| `vase_volute` | 0,52 × 0,88 × 0,4 | 1 230 | krater wolutowy czarnofigurowy: kawalkada, fryz kwadryg, promienie, wysokie ucha z wolutami | na `gr_plinth_block` (eksponat sali) |
| `vase_hydria` | 0,4 × 0,44 × 0,34 | 994 | hydria czerwonofigurowa: kobiety z hydriami | gabloty |
| `vase_kylix` | 0,44 × 0,12 × 0,32 | 728 | czara z oczami (czarnofigurowa), w tondzie biegnący wojownik | gabloty (górne półki) |
| `vase_lekythos` | 0,13 × 0,36 × 0,13 | 602 | lekyt białogruntowy: żałobniczka przy steli, rysunek liniowy | jw. |
| `vase_case_tall` | 0,82 × 1,95 × 0,82 | 770 | gablota jednej wazy (orzech, mosiądz, szkło `vase_case_tall_glass`), znacznik **`VaseSpot`** (0; 0,96; 0) = gdzie stawiać wazę | Sala Waz, wolnostojące |
| `vase_case_wall_2m` | 2,04 × 2,3 × 0,64 | 880 | gablota przyścienna: podstawa z orzecha, tkanina w tle, lampka w gzymsie (emisja), szkło z dwiema półkami `vase_case_wall_2m_glass`; znaczniki **`Shelf_0`** (y 0,91), **`Shelf_1`** (1,45), **`Shelf_2`** (1,95), wszystkie z = −0,3; tył na płaszczyźnie ściany | ściany Sali Waz |
| `cast_frieze_slab` | 1,42 × 1,2 × 0,6 | 274 | gipsowy odlew płyty fryzu w sosnowej ramie na nóżkach, numer „GIPS 214” | magazyn odlewów (przystań) |
| `cast_head` | 0,4 × 0,92 × 0,4 | 3 244 | odlew głowy Ateny w hełmie korynckim na klocku, szwy formy | jw. (na regale lub skrzyni) |
| `cast_torso` | 0,75 × 1,48 × 0,6 | 3 664 | odlew torsu na palecie, pręt zbrojenia z szyi | jw. |
| `cast_shelf` | 2,0 × 2,2 × 0,6 | 3 870 | regał z odlewami fragmentów (stopa, dłoń, maska, woluta, głowa konia) i workiem; przy ścianie | jw. |
| `cast_crate` | 1,2 × 1,35 × 0,96 | 2 252 | otwarta skrzynia z wiórami, z której wystaje gipsowa ręka; szablon „GIPS / OSTROŻNIE” | jw. |

## 5. Hoplita (`hoplite`, 256 px/m, 11 014 tr.) i odłamki

Marmurowy hoplita: 2,0 m do szczytu grzebienia (hełm 1,86 m); obrys 0,97 × 2,0 × 2,88 m z włócznią (od −2,05 do +0,83 w z); hełm koryncki z migdałowymi otworami oczu, w środku ciemność i dwa blade żary (**słaby punkt: twarz**); grzebień z resztkami czerwieni; napierśnik mięśniowy z pterygami (ochra, czerwień); nagolenniki; aspis 0,9 m z Pegazem na czerwonym polu i błękitnym obrzeżem na lewym przedramieniu; włócznia 2,4 m z brązowym grotem. Nazwy podstawowe jak u rycerza (`KnightRig` może nim sterować bez zmian), plus przedramiona i golenie.

| Część | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `torso` | (0; 1,00; 0) | — | pas; korzeń |
| `head` | (0; 1,56; 0) | torso | szyja, hełm |
| `plate_crest` | (0; 1,84; 0,02) | head | grzebień: **strącić** przy mocnym trafieniu w głowę |
| `arm_l` | (−0,23; 1,46; 0) | torso | bark tarczy: `rotation.y` = zasłona ±60°, `rotation.x` w dół = tarcza opuszczona (paralizator) |
| `forearm_l` | (−0,29; 1,20; −0,06) | arm_l | łokieć |
| `shield` | (−0,12; 1,18; −0,42) | forearm_l | uchwyt (porpax); falanga: obrót tarczy, by zachodziła na sąsiada |
| `arm_r` | (0,23; 1,46; 0) | torso | bark włóczni |
| `forearm_r` | (0,31; 1,20; −0,04) | arm_r | łokieć |
| `spear` | (0,33; 1,08; −0,30) | forearm_r | uchwyt; drzewce wzdłuż −Z. **Pchnięcie 3 m**: zapowiedź 0,7 s = cofnięcie (`spear.position.z` +0,35, `arm_r.rotation.x` ~+0,3), cios = wysunięcie (`spear.position.z` −0,6, `forearm_r.rotation.x` ~−0,3) |
| `leg_l` / `leg_r` | (∓0,11; 0,92; 0) | — | biodra (jak rycerz) |
| `shin_l` / `shin_r` | (∓0,12; 0,50; −0,03) | leg_* | kolana |
| `plate_greave_l` / `_r` | (∓0,123; 0,32; −0,06) | shin_* | nagolenniki do strącenia |

Znaczniki: **`face`** (0; 1,715; −0,11) — dziecko `head`, środek otworów oczu (słaby punkt); **`spear_tip`** (0,33; 1,08; −2,05) — dziecko `spear`, czubek grotu. Emisja (`EXTRAS` 2,5): żary w hełmie. Obwódka eksponatu `EXHIBIT_RIM` 0,34.

`marble_chips` (408 tr.): `chip_1..6` — sześć marmurowych okruchów 5–14 cm (osie w środkach) z bielą przełomu: odpryski przy trafieniach i rozpad hoplity (i popiersi).

## 6. Kentaur z metopy (`centaur`, strażnik, 112 px/m, 21 494 tr.) i oszczep

Centaur 2,86 m do szczytu głowy (obrys 1,31 × 2,86 × 3,74 m z oszczepem) wydarty ze swojej metopy: na lewym boku tkwi odłamany fragment tła płyty (błękit, świeże krawędzie), druga strona ciała obrobiona płasko zębatym dłutem jak tył wysokiego reliefu; miodowa patyna, dzika broda i włosy, świecące oczy, skóra pantery na lewym przedramieniu, oszczep nad prawym barkiem. **Słaby punkt: marmurowa pierś** — trzy pęknięcia od mostka żarzą się od środka (emisja, `EXTRAS` 3,0), dodatkowo łeb.

| Część | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `barrel` | (0; 1,25; 0) | — | końskie ciało; korzeń. **Dęba**: `rotation.x` ~+0,45 i `position.y` +0,35, tylne `leg_b*` `rotation.x` ~−0,45 (kopyta zostają) |
| `leg_fl` / `leg_fr` | (∓0,20; 1,02; −0,62) | barrel | bark: przedramię konia |
| `knee_fl` / `knee_fr` | (∓0,20; 0,56; −0,66) | leg_f* | kolano: nadpęcie |
| `hoof_fl` / `hoof_fr` | (∓0,20; 0,17; −0,68) | knee_f* | pęcina: pęcina i kopyto. **Kopnięcie** z dęba: przednie `leg_f*` w przód-górę, `knee_f*` zgięte |
| `leg_bl` / `leg_br` | (∓0,22; 1,05; 0,70) | barrel | biodro (staw kolanowy konia): podudzie |
| `knee_bl` / `knee_br` | (∓0,22; 0,58; 0,90) | leg_b* | staw skokowy: nadpęcie |
| `hoof_bl` / `hoof_br` | (∓0,22; 0,17; 0,84) | knee_b* | pęcina, kopyto |
| `tail_1` → `tail_2` | (0; 1,55; 1,08) → (0; 1,20; 1,32) | barrel → tail_1 | ogon (machanie, balans przy szarży) |
| `slab` | (−0,37; 1,20; 0) | barrel | fragment metopy: można go odstrzelić jako odłamek w fazie 2 |
| `torso` | (0; 1,62; −0,66) | barrel | pas człowieka: skręt przy rzucie |
| `neck` | (0; 2,42; −0,74) | torso | szyja: głowa, broda, włosy, oczy |
| `arm_l`, `forearm_l`, `wrist_l` | (−0,34; 2,30; −0,68), (−0,50; 2,00; −0,82), (−0,42; 1,86; −1,08) | torso → arm_l → forearm_l | bark, łokieć, nadgarstek (skóra pantery na przedramieniu) |
| `arm_r`, `forearm_r`, `wrist_r` | (0,34; 2,30; −0,68), (0,60; 2,48; −0,60), (0,46; 2,66; −0,74) | torso → arm_r → forearm_r | ramię rzutu |
| `javelin` | (0,42; 2,62; −0,78) | wrist_r | oszczep w dłoni (grot w −Z). **Rzut**: zamach 0,8 s (`arm_r.rotation.x` do tyłu, `torso.rotation.y` skręt), w chwili wypuszczenia ukryć `javelin` i wystrzelić model **`javelin`** z transformu `hand_r`; po chwili pokazać z powrotem (nowy oszczep). Faza 3: dwa naraz = drugi z lewej dłoni (`wrist_l`) |

Znaczniki: **`chest`** (0; 2,12; −0,92) — dziecko `torso`, środek pękniętej piersi; **`head`** (0; 2,66; −0,80) — dziecko `neck`; **`hand_r`** (0,42; 2,62; −0,78) — dziecko `wrist_r`, uchwyt oszczepu. Obwódka `EXHIBIT_RIM` 0,28.

`javelin` (88 tr., 192 px/m): pocisk 2,2 m, początek w punkcie wyważenia, grot w **−Z**, znacznik **`tip`** (0; 0; −1,45).

**Jak gra prowadzi kentaura** (`src/game/floor1/guardians/centaur_rig.gd`, plan `docs/superpowers/plans/2026-10-03-straznik-kentaur.md`): `barrel` z pozycji i obrotu (rytm galopu, dęba wokół tylnych pęcin, wierzgnięcie wokół przednich); każda noga IK dwóch kości od `leg_*` do osi `hoof_*` (pęciny) z biegunem — przednie „kolano” do przodu, staw skokowy do tyłu — korzeń nogi przesuwa się w beczce do 0,14 m (zasięg łopatki), `hoof_*` trzyma podeszwę poziomo albo podwija się w przenoszeniu; ręce IK od `arm_*` do `wrist_*` z biegunem łokcia, `wrist_r` obraca się tak, by `javelin` leżał na linii rzutu; drugi oszczep to kopia `javelin` w `wrist_l` (faza 3); `slab` znika, gdy kentaur go odrywa (leci jako bryła). Blask: `awake` = oczy, `glow` torsu = pęknięcia piersi, `glow` oszczepu = błysk przed rzutem, `glow` kopyt = błysk przed kopnięciem. Strefy trafień: znacznik `chest` (pierś, słaby punkt), `neck` (łeb ×1,25), tors i ręce ×0,5, reszta ×0,25. Klatki póz bez okna: `bash tools/run_guardian.sh centaur --poses` → `tests/_out/guardian_centaur/poses_*.png`.

## 7. Podglądy (najlepsze ujęcia)

- **Nastrój:** `tests/_out/art/greece_vignette_gallery.png` (Galeria Partenonu złożona z eksportowanych modeli i pól: fryz w zmiennych płytach, kasetony z gwiazdami, studnie świetlików, grupy frontonowe, falanga hoplitów, kentaur), `greece_vignette_centaur.png`, `greece_vignette_nereid.png` (Pomnik Nereid w snopie księżyca), `greece_vignette_metopes.png` (metopy pod belkowaniem doryckim, hoplita, portal). Skrypt: `"D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup --python tools/art/greece_vignette.py -- --samples 64` (Cycles w tle, ok. 1 min; `--only gallery,centaur,nereid,metopes`). Postać 1,8 m (figura woskowa) w każdym ujęciu dla skali.
- Zestaw: `gr_frieze_4m_face.png`, `gr_frieze_4m.png`, `gr_cornice_4m_detail.png`, `gr_cornice_doric_4m_detail.png`, `gr_column_ionic_capital.png`, `gr_column_doric_capital.png`, `gr_portal_4m_front.png`, `gr_drum.png`, `gr_bassae_2m_face.png`, `gr_metope_a.png` … `gr_metope_d_front.png`.
- Rzeźba: `gr_ped_goddesses.png`, `gr_ped_reclining.png`, `gr_ped_horse.png`, `nereid_temple_pediment.png`, `nereid_podium_frieze.png`, `nereid_a.png` … `nereid_d.png`.
- Wazy: `vase_amphora_bf_front.png`, `vase_volute.png`, `vase_krater_front.png`, `vase_kylix.png`, `vase_lekythos.png`.
- Wrogowie: `hoplite.png`, `hoplite_closeup.png` (hełm, żary), `hoplite_shield.png`, `centaur.png`, `centaur_chest.png`, `centaur_side.png`.

## 8. Sugerowany przepis na światło (dla integratora)

Najjaśniejsze skrzydło: księżyc chłodny (0,6; 0,72; 1,0) stromo przez studnie świetlików (krata 0,5 m tnie snopy na posadzce), mało mgły (gęstość ~0,008: „prawie czyste powietrze”), w każdej studni miękkie chłodne światło powierzchniowe (niebo), ciepłe reflektory (1,0; 0,76; 0,5) na grupy frontonowe, na Pomnik Nereid i na metopy; lampka w gzymsie gablot przyściennych. Biel marmuru niesie światło: wystarczają słabsze lampy niż w Egipcie, a fryz na 1,45 m warto podświetlić z sufitu, bo relief żyje z mapy normalnych.

## 9. Uczciwie: słabe punkty

- Postacie rzeźb wolnostojących (frontony, nereidy, kentaur, hoplita) to gładka „glina” z metaballi: sylwetki, pozy i draperia czytają się z dystansu, anatomia i twarze są uproszczone (głowa kentaura to „bryła z brodą”, zwłaszcza z bliska).
- Fałdy draperii nereid i bogiń to rowki i grzbiety w glinie, miejscami zbyt regularne („piszczałki”).
- Fryzy i metopy to płaskorzeźba z warstw 2D: konie i ludzie są czytelni, ale uproszczeni (głowy koni, dłonie); fryz to tekstura z mapą normalnych (płaski pod ostrym kątem), metopy mają prawdziwą geometrię.
- Atlas podium Nereid (1 888 × 1 248) i świątyni (1 888 × 1 568) jest duży — jedyne takie w skrzydle; świątynia ma 16,6 tys. trójkątów (sześć kolumn).
- Modele nie mają kolizji (jak cały zestaw: kolizje z greyboxa); podium i schody na nie poziom musi zrobić sam.

## 10. Testy i budowa

- `tests/integration/test_art_greece.gd` (5 testów, bez okna): rig hoplity (łańcuchy, tarcza po lewej z przodu, `face`, `spear_tip`, wysokość, budżet), rig kentaura (trzy stawy każdej nogi, ręce, znaczniki, 2,8–3,15 m, budżet), oszczep, stos Pomnika Nereid (4,4 + 6,81 m) i nereidy, biegi fryzu (datum, wysokość, różne płyty w 16 m), style sal i gabloty. Budżety prefiksów `gr_column` (6000), `gr_metope` (5000), `gr_portal` (2500), `gr_ped_` (9500), `cast_` (4500), `nereid_` (17 000), `vase_` (2000) dopisane w `test_art_kit.gd`.
- Przebudowa wszystkiego z Grecji: `bash tools/art/build_art.sh gr_frieze gr_bands gr_orders gr_fittings gr_metopes gr_bassae gr_pediment nereid nereid_statues vases casts hoplite centaur` (ok. 25 min na jednym procesie; `FAST=1` bez AO). Tekstury pól: `python tools/art/build_textures.py gr_ashlar marble_greek gr_marble gr_plaster gr_limewash gr_wall_paint`.
