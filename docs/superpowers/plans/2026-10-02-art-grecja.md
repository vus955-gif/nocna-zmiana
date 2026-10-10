# Grafika skrzydła greckiego (Partenon i Pomnik Nereid) — plan

> Stan: 2 października 2026. Wykonawca: Claude (worktree `art-greece`, gałąź `art-greece`, równolegle z artystami innych skrzydeł).
> Źródła: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §5.3, §7.3, §7.4 (Kentaur), §10.1–10.2; `docs/art/styl-przewodnik.html`.
> Wynik: modele i tekstury z Blendera (skrypty), rejestracja w `ArtLibrary`, katalog `docs/art/kit-pietro1-grecja.md`. Rozmieszczenie w poziomie i zachowanie wrogów robią inni wykonawcy na podstawie katalogu.

**Cel artystyczny.** Najjaśniejsze, najbardziej „powietrzne” skrzydło: biały i kremowy marmur, który nie jest płaską bielą (żyłki, patyna, zacieki, okruchy), z resztkami pierwotnych barw (błękit egipski w tle fryzów i kasetonów, ochra, czerwień na hełmach i tarczach), w srebrnym świetle księżyca z górnych świetlików. Bryły masywne i czytelne, piksele ostre, gęstości tekseli stałe.

## Zasady wspólne

- **Tylko ten worktree.** Nic poza `D:/ClaudeCode/Doomer Shooter`. `tools/godot` to dowiązanie: nie ruszać.
- **Rejestry wspólne tylko przez dopisywanie:** `ALL` w `tools/art/build_models.py`, `ArtLibrary.KIT` / `KIT_SETS` / `REGISTRY` / `EXTRAS` / `EXHIBIT_RIM`, lista `TILES` w `build_textures.py`, budżety w `tests/integration/test_art_kit.gd` (jedna nowa linia przed wpisem domyślnym).
- **Własny kod w nowych plikach**, żeby nie kłócić się z innymi artystami: `tools/art/artlib/greek.py` (rampy i materiały), `tools/art/artlib/relief.py` (silnik płaskorzeźb 2D), modele `tools/art/models/gr_*.py`.
- **Prefiksy identyfikatorów:** `gr_` (zestaw architektury i rzeźby), `nereid_`, `vase_`, `cast_`, wrogowie `hoplite`, `centaur`, `javelin`, `marble_chips`.
- **Gęstość tekseli:** architektura 64 px/m (ściany, gzymsy, kolumny, belkowania, portale, świetliki, podesty), płaskorzeźby-eksponaty 128 px/m (fryzy, metopy, panele z Bassae, fryzy podium), rzeźba wolnostojąca 96–128 px/m (figury frontonów, nereidy: duże i oglądane z 2–8 m), wazy i drobne eksponaty 256–320 px/m, meble i gabloty 128, wrogowie 256 (hoplita), strażnik ok. 112–128 (kentaur, 3 m).
- **Konwencje osi** jak w zestawie holu: początek w środku podstawy, przód = Godot −Z (Blender +Y), pasy przyścienne na płaszczyźnie ściany z = 0, dekoracja po stronie −Z. Wrogowie patrzą na +Y w Blenderze (−Z w Godocie), początek na podłodze.
- **Podgląd:** każdy model ma podgląd Cycles w `tests/_out/art/<id>.png`; oglądam każdy i poprawiam, aż wygląda dobrze. Podglądy rozsądnie (inni renderują równolegle).
- **Testy:** `bash tools/run_tests.sh` zielone na końcu; własny plik `tests/integration/test_art_greece.gd` (części, znaczniki, rozmiary, zestawy tekstur, budżety).
- Commit po każdej rodzinie modeli, stopka `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Zadanie 1: ten plan

Commit samego dokumentu.

## Zadanie 2: silnik płaskorzeźb i materiały greckie

- `artlib/relief.py`: płaskorzeźba z warstw 2D (kształt jako pole odległości + profil wypukłości), łączenie warstw maksimum wysokości (plany bliższe zakrywają dalsze), z tego mapa wysokości w metrach; z niej okluzja (horyzont w ośmiu kierunkach), krzywizna, krawędzie, maska tła. Prymitywy: kapsuła stożkowa, elipsa, wielokąt, krzywa Béziera (fałdy, ogony, płaszcze). Generatory postaci: koń (kłus, galop, stęp, dęba), jeździec w chlamidzie, piechur w szatach, młodzieniec prowadzący, krowa ofiarna, kwadryga z woźnicą i apobatą, hoplita z tarczą, Amazonka, Lapita, kentaur. Uszkodzenia: odbite głowy, ubytki, spoiny płyt, pęknięcia.
- `artlib/greek.py`: rampy (marmur pentelicki ciepły i chłodny, patyna, błękit egipski, ochra, czerwień, terakota, czarny pokost, gips), funkcje materiałów: `marble_pentelic` (żyłki, chmurki, zacieki patyny, okruchy na krawędziach), `relief_face` (malowanie płaskorzeźby z mapy wysokości: marmur + ślady barw w tle), `plaster_cast`, kafle pól.
- Tekstury kafelkowe 64 px/m (`build_textures.py`): `gr_ashlar` (mur izodomowy z marmuru, bloki z obrzeżem anathyrosis), `gr_floor` (posadzka z dużych płyt kremowych i szarych), `gr_marble` (gładki marmur ościeży), `gr_plaster` (strop), `gr_limewash` (bielona cegła magazynu odlewów).

## Zadanie 3: zestaw architektury (64 px/m)

| Id | Rozmiar | Co to |
|---|---|---|
| `gr_base_4m/2m/1m/05m` | pas dolny 0,6 m | cokół ze szarego marmuru z wałkiem i kymationem |
| `gr_frieze_4m` (+ zestawy `_b … _f`), `gr_frieze_2m` (+ `_b`, `_c`), `gr_frieze_blank_1m`, `_05m` | pas 1,1 m, początek na dolnej krawędzi | fryz Partenonu: jeźdźcy, kwadryga, krowy ofiarne, procesja (128 px/m) |
| `gr_cornice_4m/2m/1m/05m` | pas górny 1,0 m | gzyms joński z ząbkami i kymationem, ślady błękitu |
| `gr_cornice_doric_4m/2m/1m` | pas górny 1,6 m | belkowanie doryckie: architraw, tryglify i metopy, gzyms z mutulami |
| `gr_column_doric` | 1,9 × 9 × 1,9 m | kolumna dorycka Partenonu, 20 kanelur, echinus i abakus |
| `gr_column_ionic` | 1,2 × 7 × 1,2 m | kolumna jońska z wolutami, baza attycka |
| `gr_portal_4m`, `gr_portal_2m` | otwór 4 × 4,5 i 2 × 2,8 m | portal jak drzwi Erechtejonu: zwężające się ościeże z fasciami i rozetami, nadproże z gzymsem na konsolach |
| `gr_skylight_4m` | 4 × 4 m, studnia 2 m | świetlik: stopniowane ramy, żeliwna krata, szkło osobnym obiektem |
| `gr_coffer_2m` | 2 × 2 m | kaseton z niebieskim polem i złotą gwiazdą (malatura grecka) |
| `gr_floor_border_4m/2m/1m`, `gr_floor_border_corner` | bordiura 0,8 m | meander z marmurów |
| `gr_plinth_low`, `gr_plinth_block` | 4,4 × 0,5 × 1,6 / 1 × 1,1 × 1 m | niski cokół grup frontonowych, blok pod popiersia i wazy |

## Zadanie 4: rzeźba architektoniczna

- `gr_metope_a … d` (1,25 × 1,25 m, wysoki relief jako geometria z mapy wysokości + mapa normalnych): Lapita i kentaur w czterech kompozycjach.
- `gr_bassae_2m` (+ zestawy `_b`, `_c`): fryz z Bassae (Amazonomachia, Kentauromachia), pas 0,65 m.
- Figury frontonów (marmur, bez głów, masywne): `gr_ped_reclining` (leżący Dionizos/Ilissos), `gr_ped_goddesses` (trzy boginie), `gr_ped_seated` (Demeter i Kora), `gr_ped_horse` (głowa konia Selene na bloku), `gr_ped_torso` (tors Posejdona).

## Zadanie 5: Pomnik Nereid

- `nereid_podium` (ok. 7,4 × 3,6 × 5,2 m): wysokie podium z dwoma fryzami (bitwa, oblężenie) w 128 px/m, ściany podium polem `gr_ashlar`.
- `nereid_temple` (na podium): cztery kolumny jońskie z przodu, ściana celli z drzwiami, belkowanie z ząbkami, fronton z reliefem, akroteria.
- `nereid_a … d`: cztery nereidy 1,6 m na stworzeniach morskich (delfin, krab, ptak, fala), bez głów i rąk jak oryginały, szaty przyklejone wiatrem i płaszcz łopoczący za plecami.

## Zadanie 6: wazy, gabloty, magazyn odlewów

- Wazy z malowaniem pikselowym (2D, mapowanie walcowe): `vase_amphora_bf` (amfora szyjowa, czarnofigurowa), `vase_amphora_rf` (czerwonofigurowa), `vase_krater` (krater kielichowy), `vase_volute` (krater wolutowy), `vase_hydria`, `vase_kylix` (czara na nóżce), `vase_lekythos`.
- Gabloty: `vase_case_tall` (jedna waza), `vase_case_wall_2m` (gablota przyścienna z półkami); szkło osobnym obiektem.
- Magazyn odlewów (przystań): `cast_frieze_slab` (gipsowy odlew płyty fryzu z numerem), `cast_head` (odlew głowy na klocku), `cast_torso`, `cast_shelf` (regał z odlewami), `cast_crate` (skrzynia z wiórami i odlewem).

## Zadanie 7: Hoplita (wróg)

`hoplite`: marmurowy hoplita 1,95 m (z grzebieniem), hełm koryncki z grzebieniem, aspis (okrągła tarcza) z resztkami malowanego godła, włócznia, nagolenniki, pancerz lniany z pterygami. Części jak u rycerza (oś w stawach): `torso`, `head`, `arm_l` → `forearm_l` → `shield`, `arm_r` → `forearm_r` → `spear`, `leg_l` → `shin_l`, `leg_r` → `shin_r`, płyty do strącania `plate_crest`, `plate_greave_l/_r`. Znaczniki `face` (słaby punkt), `spear_tip`. Zgodność z `KnightRig` (te same nazwy podstawowe). Odłamki: `marble_chips` (kilka okruchów jako osobne części).

## Zadanie 8: Kentaur z metopy (strażnik)

`centaur` ok. 3,0 m: koński tułów (`barrel`), cztery nogi po trzy stawy (`leg_*` biodro/bark, `knee_*` kolano/staw skokowy, `hoof_*` pęcina), ludzki tors (`torso`, oś w pasie), szyja i głowa z brodą (`neck`), ręce (`arm_*` bark, `forearm_*` łokieć, `wrist_*` nadgarstek), oszczep w prawej (`javelin`), ogon (`tail_1`, `tail_2`), skóra pantery na lewym ramieniu, odłamany fragment tła metopy przy boku (relief „wyrwał się” ze ściany). Znaczniki `chest` (słaby punkt), `head`, `hand_r`. Pęknięcia na piersi lekko świecą (mapa emisji). Zapasowy oszczep do rzutu: model `javelin`.

## Zadanie 9: rejestracja, testy, katalog, scena

- `ArtLibrary`: dopisane `KIT`, `KIT_SETS`, `REGISTRY`, `EXTRAS`, `EXHIBIT_RIM`.
- `tests/integration/test_art_greece.gd` + jedna linia budżetów w `test_art_kit.gd`.
- `docs/art/kit-pietro1-grecja.md`: id, rozmiary, osie, znaczniki, przeznaczenie, trójkąty, podglądy, opis rigów.
- Scena poglądowa w Blenderze (galeria Partenonu w świetle księżyca ze strażnikiem 1,8 m dla skali): `tests/_out/art/greece_scene_*.png`.
- `bash tools/run_tests.sh` zielone.
