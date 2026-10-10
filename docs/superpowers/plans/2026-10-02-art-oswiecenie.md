# Grafika skrzydła Oświecenia — plan prac (Biblioteka Królewska, gabinety, Planetarium, Latające księgi)

> **Gałąź:** `art-enlight` (od `pietro-1` @ `aa7c36f`). **Źródło:** `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §2, §5.4, §7.3, §7.4 (Wielkie Planetarium), §10.1–10.2.
> **Zasady:** wszystko skryptami Pythona w Blenderze (`tools/art/models/`, tryb `-b`), atlas pikseli o stałej gęstości, podglądy Cycles w `tests/_out/art/`. Rejestry (`ALL`, `ArtLibrary.KIT/REGISTRY/EXTRAS/KIT_SETS`) tylko dopisujemy. Bez okien Godota, bez dźwięku; na końcu `bash tools/run_tests.sh` zielone.
> **Wynik końcowy:** katalog `docs/art/kit-pietro1-oswiecenie.md`.

## Kierunek wizualny

- **Paleta:** ciemny dąb i mahoń, mosiądz, zielone abażury i zielone sukno; akcenty: złocenia grzbietów, czerwony maroken, granat emalii Planetarium.
- **Światło (dla integratora):** ciepłe plamy z lampek z zielonymi kloszami, długie cienie regałów, snopy księżyca ze świetlików w stropie (10 m) przecinające galerię.
- **Gęstości:** architektura 64 px/m (strop, gzyms, posadzka), meble i regały 128, gabloty z osobliwościami 192, eksponaty-bohaterowie 256, Planetarium ~112, księga-wróg 256.
- **Nazwy:** wszystko z przedrostkiem `lib_` (z wyjątkiem `planetarium`, `flying_book*` i tekstury `parquet_chevron`), rampy kolorów z przedrostkiem `enl_` (żeby nie zderzyć się z innymi skrzydłami budowanymi równolegle).
- **Konwencja zestawu** jak w holu: początek w środku podstawy, przód na −Z Godota; pasy przyścienne na płaszczyźnie ściany z = 0; oprawy z początkiem w punkcie światła.

## Zadania

### 1. Zestaw Biblioteki (galeria 14 × 70 m, h 10, kładka na y = 4)
- [x] `artlib/lib_materials.py`: rampy `enl_*` (mahoń, dąb ciemny, płótna i skóry opraw, sukno zielone, emalia granatowa, papier), malarz grzbietów (tabela książek → kolor, zwięzy, złocone linie i tytuły, szyldziki), okładki, papier z drukiem.
- [x] Regały dwupoziomowe: `lib_bookcase_{a,b,c}_2m` (dolny poziom, 3,6 m: szafka z mosiężną kratką + 6 półek), `lib_bookcase_up_{a,b}_2m` (górny, na kładce), `lib_bookcase_pilaster_{low,up}`; zestawy kolorów `_v2`. Książki jako bloki równej wysokości (lekko!), każdy grzbiet malowany w atlasie.
- [x] Kładka: `lib_walkway_fascia_{4m,2m,1m,end}`, `lib_railing_{2m,1m}`, `lib_railing_post`, `lib_walkway_bracket`.
- [x] Schody (0,15 × 0,40 m = 20,6°): `lib_stair_step_1m`, `lib_stair_stringer_4m`, `lib_stair_railing_4m`, `lib_stair_newel`; bohater: `lib_stair_spiral` (kręte schody 4 m, 27 stopni).
- [x] Strop: `lib_coffer_2m`, `lib_skylight_well_4m` (+ szkło), gzyms `lib_cornice_{4m,2m,1m}` z fryzem (zestaw z dewizą „SAPERE AUDE”).
- [x] Posadzka: tekstura kafelkowa `parquet_chevron` (jodełka węgierska z dębu, 64 px/m, oś wzdłuż galerii).
- [x] Portale: `lib_doorframe_4x4_5` (mahoń, pilastry, przerwany fronton, kartusz z globusem), `lib_doorframe_2x2_6`.
- [x] Lampy (zielone klosze, znacznik `Light`): `lib_lamp_reading`, `lib_lamp_wall`, `lib_lamp_pendant`, `lib_lamp_standard`.
- [x] `lib_ladder` + `lib_ladder_rail_2m`, `lib_bust_bracket` (znacznik `bust_spot`).
- [x] Gabloty ze szklanym blatem i osobliwościami: `lib_case_shells`, `lib_case_minerals`, `lib_case_coins`, `lib_case_instruments` (szkło osobną częścią).

### 2. Gabinety (x 48…66)
- [x] Historia naturalna: `lib_nh_shelf_{a,b}` (skamieniałości, czaszki, minerały, słoje), `lib_antlers`, `lib_diorama_base` (znaczniki `animal_spot_1/2` dla wilka i raptora), `lib_rifle_rack` (znacznik `weapon_spot` + `Light`).
- [x] Globusy: `lib_globe_terrestrial`, `lib_globe_celestial` (kula osobną częścią na osi).
- [x] Zegary i automaty: `lib_clock_longcase` (wahadło, wskazówki), `lib_clock_wall` (ściana zegarów), `lib_automaton_writer` (pisarz przy biurku: głowa, ramię), `lib_bird_cage` (ptak na osi).
- [x] Gabinet bibliotekarza (przystań): `lib_office_desk` (znacznik `terminal_spot`), `lib_office_chair`, `lib_card_catalogue`, `lib_filing_cabinet`.

### 3. Wielkie Planetarium (strażnik, §7.4)
- [x] `planetarium`: mosiężne orrery ~10 m, podstawa z przekładnią, kolumna, **słońce** z 6 łupinami na zawiasach + świecący rdzeń (znacznik `sun_core`), **trzy piętra ramion** (`tier_low` 0,5 m — do przeskoczenia, `tier_mid` 1,6 m — krótsze, `tier_high` 2,8 m — z wiszącymi księżycami i luką do stania), **6 planet** (`planet_1..6`, Saturn z pierścieniem) jako osobne części z gniazdami. Opis rigu w katalogu.

### 4. Latające księgi (wróg)
- [x] `flying_book`: grzbiet z blokiem kartek, okładki `cover_l/cover_r` na zawiasach, `pages` (wachlarz kartek), świecące oko na rozkładówce (zapowiedź); zestawy `flying_book_{green,blue,black}`; odłamki `flying_book_page`.

### 5. Rejestracja, testy, katalog
- [x] `ALL` w `build_models.py`, `ArtLibrary.KIT` / `REGISTRY` / `KIT_SETS` / `EXTRAS` (dopisane na końcu).
- [x] Własny test bez okna `tests/integration/test_art_enlightenment.gd` (części, znaczniki, budżety, rozmiary); `test_art_kit` dostaje budżety dla `lib_`.
- [x] Scena podglądowa Cycles (`tools/art/scene_enlight.py`): przęsło biblioteki złożone z modułów w ciepłym świetle.
- [x] Katalog `docs/art/kit-pietro1-oswiecenie.md`: id, wymiary, osie, znaczniki, rozmieszczenie, trójkąty, podglądy, rigi.
- [x] Commit po każdej rodzinie modeli.
