# P3 — oprawa skrzydeł: Grecja i Oświecenie

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (zadania po kolei, commit po każdym). Kroki mają pola `- [ ]`.

**Cel:** greybox stref `greece` i `enlightenment` Piętra I dostaje gotową grafikę, światło i atmosferę (etap P3, projekt §13) **dokładnie tym sposobem i w tej jakości co wzorzec P2** (hub + Egipt, plan `2026-10-03-p2-oprawa-hol-egipt.md`). Grecja: **najjaśniejsze skrzydło** — srebrny księżyc przez świetliki z żeliwną kratą, czyste powietrze, mało mgły, biały marmur z fryzami i resztkami błękitu. Oświecenie: **ciepłe plamy lamp z zielonymi kloszami**, długie cienie regałów, kurz i luźne kartki w powietrzu, zimne snopy księżyca ze studni w stropie. Budżet: ≥ 90 kl./s 1080p High na RTX 2080 Ti w najcięższym widoku (§11.3), noc startuje ≤ 10 s.

**Architektura (jak P2):** kolizje i nawigacja zostają z greyboksa. Wygląd: `LevelArt`/`ArtKit` (pola, pasy, stropy) + `Floor1Art` (dopasowania elementów, bohaterowie). Nowe moduły skrzydeł, żeby równoległe P3 innych skrzydeł nie walczyły o jeden plik: **`Floor1ArtGreece`** (`src/style/floor1_art_greece.gd`) i **`Floor1ArtEnlightenment`** (`src/style/floor1_art_enlightenment.gd`) — czyste fabryki drzew `Node3D` z modeli `ArtLibrary`, bez kolizji; `Floor1Art` deleguje do nich po prefiksie id sali (`piece_look`, `fixture`, `dress`). Światło: wpisy sal w `Floor1LightRecipe` (mgła, sondy, budżet cieni, zanik), oprawy, światła dodatkowe, kurz, **kartki** (nowy emiter z siatki `flying_book_page`). Przycinanie grafem, okludery i presety — bez zmian (obejmują nowe sale same).

**Technologia:** Godot 4.7.2 (Forward+), GDScript ze statycznym typowaniem, tabulatory, angielskie identyfikatory; testy `bash tools/run_tests.sh --filter=…` bez okna; wycieczka (`tools/run_tour.sh`) z oknem tylko jako polecenie dla kontrolera (nocna sesja), bez okna tryb `dry`; kontrola obrazu: eksport poziomu do glTF i render gliny w Blenderze w tle.

**Wejście (wiążące):** projekt `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.3, §5.4, §10.1, §11.3; katalogi `docs/art/kit-pietro1-grecja.md`, `docs/art/kit-pietro1-oswiecenie.md`; greybox `src/level/floor1/zones/{greece,west_kit,enlightenment,east_kit}.gd` (plany W3, W5a); wzorzec P2: `Floor1Art`, `Floor1LightRecipe`, `RoomCuller`, `LevelOccluders`, `tour_scenario`, `test_floor1_art*`. Strażnicy: **Kentaur** (gałąź `guard-centaur`) używa postumentów i grup frontonowych Galerii Partenonu jako ścian ogłuszenia — ich kolizje zostają co do milimetra; **Planetarium** (gałąź `guard-planetarium`) stawia orrery samo (`dress_arena()`) — środek rotundy (r ≥ 9 m od `ORRERY`) zostaje pusty.

---

## 1. Ograniczenia i zasady (jak P2 §1)

- **Kolizja = greybox.** Żaden dodany model nie ma kolizji. Bohaterowie stoją tylko: przy ścianie (≤ 0,3 m), wysoko (> 2,4 m), wewnątrz istniejącej bryły kolizji (regały w bryłach `shelf`, świątynia w podium i celli), albo są drobni. Test `test_collisions_are_the_greyboxes` pilnuje (cały poziom).
- **Model światła prawdziwy:** światła, które realnie oświetlają podłogę, to `LightSpec` układu; zmieniam **tylko ich położenie** tam, gdzie oprawa ma swoje miejsce (kinkiety na pilastrach regałów, lampy na blatach, obrazy), nie liczbę ani grupy. Światła przepisu (smugi, zmywania, niebo w studniach, kinkiety dolnego poziomu) mają małą energię.
- **Bez zmian sal i przejść** → pamięć powłoki (`data/shell_cache`) bez przeliczania; jeśli jednak coś się zmieni — `bash tools/bake_shell_cache.sh`.
- **Bez okien i dźwięku.**

## 2. Decyzje — infrastruktura

| Co | Decyzja |
|---|---|
| Strefy | `MuseumFloorLevel.ART_ZONES` += `greece`, `enlightenment`. |
| Style sal | `Floor1Art.ROOM_STYLES` dostaje **każdą** salę obu stref (blok „P3: Grecja i Oświecenie”): galerie i sale marmurowe → style `greece_*` z katalogu, antresole/podium → styl gospodarza; magazyn odlewów, sekrety → `greece_casts`; schody i korytarz służbowy → `corridor_w`; Biblioteka i jej galeria → `enlightenment_library`; gabinety → `enlightenment_cabinet/clocks/portraits`; gabinet bibliotekarza, ukryty gabinet, archiwum → `enlightenment_librarian`; rotunda i galeria obserwatorów → `enlightenment_planetarium`; poddasze, introligatornia → `closet`; magazyn zamknięty i schody → `corridor_w`. |
| Delegacja | `Floor1Art.piece_look` / `fixture` / `dress` → `Floor1ArtGreece` dla `greece_*`, `Floor1ArtEnlightenment` dla `enlightenment_*`; listy modeli `MODELS` w modułach skrzydeł (test sprawdza rejestr i pliki). |
| Wspólne drobne zmiany | `ArtKit`: `RUN_SIZES` dla `lib_walkway_fascia_`; klucz stylu `stair_rails` (balustrady na schodach poza holem), `fascia`/`fascia_end` (lico płyty balkonu), `middle_set` (moduł środka pasa: dewiza SAPERE AUDE); `LevelArt.stairs_look` z kluczem `stairs_kit: "library"`; `LevelLighting`: oprawy lamp (kinkiet, lampka, żarówka, lampa sufitowa) na reflektorze **wiszą prosto** (celują tylko reflektory jak `egypt_spotlight`); `Floor1Art.PORTALS` przyjmuje zestaw tekstur (trzeci element); `DecorSpinner.swing()` (wahadła); drzwi-bramy z własnym skrzydłem (`Floor1Art.gate_leaf`: regał w ukrytym gabinecie). |

## 3. Decyzje — Grecja (`Floor1ArtGreece`)

### 3.1 Pomnik Nereid (`greece_nereid`, podium `greece_nereid_podium`)
- **Podium** = wygląd elementu `pedestal` (7 × 4,5 × 10): `nereid_podium` obrócony frontem na wschód, korpus dopasowany do bryły (szer. ×1,389, głęb. ×1,75, wys. ×1,023 → góra 4,5 = podłoga podium), stopień wystaje 0,2 m przy posadzce.
- **Świątynia** (bohater): `nereid_temple` frontem na wschód, szer. ×1,129 (cella 7 m = bryła celli z 8,5 do 15,5), głęb. ×1,739 (ściana celli na x = −82,5 = lico bryły celli, tył schowany w ścianie na −86,5), wys. ×1,4 (szczyt 13,6 < 14 m), stylobat 2 cm nad podłogą podium. **Kolumny** `nereid_column_1..4` przestawione na kolumny greyboksa (x −79,7; z 8 / 10,65 / 13,35 / 16), skala skompensowana do okrągłych; narożne `_5/_6` ukryte (stałyby na wolnej podłodze portyku). Elementy `column`, `landing` (cella, dach) → pusty wygląd.
- **Nereidy**: rzeźby portyku → `nereid_a`, `nereid_b`, `nereid_c` (×0,95, frontem na wschód).
- Popiersia na `gr_plinth_block`, ławki `bench_hall`, schody marmurowe z balustradą (`stair_rails`), balkon/antresola: płyta w marmurze, słupy = **kolumny jońskie** `gr_column_ionic`, balustrada kamienna.

### 3.2 Sala z Bassae (`greece_bassae`, antresola)
- Pas fryzu `gr_bassae_` przeniesiony z 1,2 m na **5,7 m** (1,2 m nad antresolą, jak katalog: „~1,2 m nad antresolą”); greyboksowe „obrazy” fryzu → pusty wygląd. Belkowanie doryckie pod stropem.
- Posąg kultowy: `gr_plinth_block` + kolosalny tors `gr_ped_torso` ×1,6 (z Bassae zostały fragmenty akrolitu).
- Świetlik 8 × 7: siatka 2 × 2 `gr_skylight_4m`.

### 3.3 Sala Waz, Sala Metop, magazyn odlewów, sekrety
- **Wazy:** gabloty greyboksa (1,2 × 2 × 1,2) → niski cokół w marmurze na pełny obrys + `vase_case_tall` (×1,0, wys. dopasowana) z wazą w `VaseSpot` (wolutowy krater, amfory, hydria, krater); dwie gabloty z łupem bez wazy. Ściany pompejańskie (styl).
- **Metopy:** obrazy greyboksa → `gr_metope_a..d` na kolejnych miejscach; grupy na postumentach → dwustronne stele: dwie metopy plecami do siebie na `gr_plinth_block`; belkowanie doryckie (styl).
- **Magazyn odlewów (przystań):** regały → `cast_shelf`, stół → biurko, postument z głową → `gr_plinth_block` + `cast_head`; skrzynie w sekretach → `cast_crate`; magazyn skorup: regał → dwie gabloty `vase_case_wall_2m` z naczyniami na półkach.

### 3.4 Galeria Partenonu (`greece_parthenon`, arena Kentaura)
- Styl: fryz `gr_frieze_` na 1,45 m dookoła (zmienne płyty), gzyms joński, kasetony z gwiazdami, bordiura z meandrem; **4 świetliki** `gr_skylight_4m` (krata 0,5 m tnie snopy księżyca); nad wylotem z Sali Metop belkowanie doryckie `gr_cornice_doric_` (12 m, 8–9,6 m).
- **Grupy frontonowe — kolizja nietknięta:** postumenty → `gr_plinth_block` (wschodni 12 m: trzy moduły 4 m); figury tam, gdzie da się je pokazać zgodnie z bryłami: wschód — leżący „Dionizos”, siedzące „Demeter i Kora”, trzy boginie w rzędzie na długim cokole (frontem na zachód, ×1,35); zachód — „Ilissos” oraz głowa konia Selene z torsem „Posejdona” na blokach, które wypełniają poprzeczne bryły rzeźb (stopień do posadzki tam, gdzie bryła wystaje poza postument).
- Niskie postumenty z posągami: `gr_plinth_block` + na zmianę tors i nereidy, frontem do osi galerii.
- Środek galerii zostaje wolny (metopa Kentaura, `guardian_centaur`).

### 3.5 Wieża schodów i korytarz pod galerią
- `corridor_w` jak w Egipcie (tynk, beton, rury), świetlówki z zestawu.

## 4. Decyzje — Oświecenie (`Floor1ArtEnlightenment`)

### 4.1 Biblioteka Królewska (`enlightenment_library` + galeria na y = 4)
- **Regały jako biegi bohaterów** na każdej ścianie, w dwóch poziomach (dolny 3,6 m pod płytą 3,6; górny 3,3 m na y = 4), **każdy bieg zaczyna i kończy pilaster** (boki modułów są otwarte). Bieg = ściana minus przejścia (te same zakresy co greybox; szczeliny 0,5 m między bryłami `shelf` zakryte — nikt się w nich nie mieści). Rytm: przęsło 2,22 m (moduł 2 m + pilaster), przy końcach 1 m; rozciągnięcie modułów ≤ 10 %; warianty `a/b/c` i zestawy `_v2` na zmianę, ściany przeciwległe przesunięte. Elementy `shelf` → pusty wygląd. Rytm liczy jedna funkcja w module strefy (`Enlightenment.bays()`): z niej biorą pozycje i regały, i kinkiety.
- **Galeria:** płyta w dębowych deskach, lico `lib_walkway_fascia_` (z zakończeniami), pod płytą kasetony, **balustrada regencyjna** `lib_railing_2m/1m` ze słupkami `lib_railing_post` co 4 m i na końcach; konsole `lib_walkway_bracket` pod pilastrami górnego poziomu; **kinkiety** `lib_lamp_wall` na pilastrach (żarówka 6,7 m, 1,0 m od ściany — `LightSpec` przesunięte na pilastry).
- **Słupy pod galerią** → kolumny jońskie z polerowanego czerwonego granitu (kopia materiału `gr_column_ionic` z odcieniem).
- **Oś:** gabloty `lib_case_shells/minerals/coins/instruments` (×1,4 w planie, długością wzdłuż osi), lampki bankierskie `lib_lamp_reading` na ich końcach (światła na blacie); **globusy** `lib_globe_terrestrial/celestial` na posadzce w miejscu postumentów (kule obracają się bardzo wolno: proces dekoracji); dwie **lampy stojące** `lib_lamp_standard` między globusami a gablotami (światła z długimi cieniami przeniesione na ich żarówki 1,45 m).
- **Strop:** kasetony `lib_coffer_2m`, 5 studni `lib_skylight_well_4m`, gzyms `lib_cornice_` z dewizą **SAPERE AUDE** w środku obu długich ścian; lampy wiszące `lib_lamp_pendant` (żarówka 8,8 m).
- **Schody na osi:** zestaw `lib_stair_*` (stopnie dębowe z mosiężnym noskiem, policzki, balustrady, słupki z urną u stopy).
- Drabiny `lib_ladder` z prętem w dwóch zakątkach pod mostkami (poza przejściem); popiersia na konsolach `lib_bust_bracket` nad górnymi regałami (wysoko).
- Wejście z dziedzińca (6 × 7 pod mostkiem galerii): portal od dziedzińca bez zmian (P2: łuk holu + tablica skrzydła); od biblioteki goły otwór (portal nie mieści się pod mostkiem) i zielona tablica **BIBLIOTEKA KRÓLEWSKA** nad otworem. Drzwi gabinetów pod galerią: od biblioteki bez obramień (nad otworem 0,1 m do płyty), od gabinetów obramienia z zestawu; tablice `lib_sign_*` pod licem galerii nad wejściami.

### 4.2 Gabinety
- **Historia naturalna:** szafy `lib_nh_shelf_a/b` na biegach greyboksa, rogi `lib_antlers` nad nimi, dioramy `lib_diorama_base` (grunt na wysokości postumentu) z wypchanymi wilkami i szkieletami raptorów (modele eksponatów), **szafa ze sztucerem** `lib_rifle_rack` tyłem do ściany wschodniej za stołem ze znacznikiem sztucera (`weapon_rifle_hunt` zostaje na stole: puste łoża w szafie, sztucer wyjęty na stół, w ciepłym snopie).
- **Zegary i automaty:** zegary szafkowe `lib_clock_longcase` (wahadła chodzą, wskazówki idą), **ściana zegarów** `lib_clock_wall` × 3 na ścianie północnej (stanęły), **zegar astronomiczny** = cztery zegary szafkowe ×1,4 plecami w wieżę na postumencie; stolik pisarza `lib_office_desk` z automatem-pisarzem `lib_automaton_writer` i ptaszkiem w klatce.
- **Portrety:** obrazy greyboksa → pusty wygląd (portrety i obrazy wiesza gra na znacznikach `portrait_enlightenment_*`); nad każdym `lib_lamp_wall` jako lampka obrazu (światła przesunięte 0,45 m od ściany).
- **Gabinet bibliotekarza (przystań):** `lib_office_desk`, `lib_office_chair`, regał → dwa katalogi kartkowe i kartoteka.
- **Rotunda Planetarium:** styl (tynk, marmur, gwiaździsty strop, gzyms), **pilastry** do gzymsu, mosiężny pierścień ekliptyki w posadzce (r 5,5 — obręcz, bez wypełnienia), globusy na postumentach w narożach, konsola przeciwwagi na `lib_walkway_bracket`, oculus `lib_skylight_well_4m`; kinkiety 0,45 m od ścian. Środek wolny.
- **Galeria obserwatorów:** balustrada regencyjna, biurko, lampka, **luneta** (mosiężna rura na trójnogu — prosta bryła proceduralna, brak modelu w zestawie).
- **Sekrety, poddasze, magazyn:** ukryty gabinet Sloane'a — regały górne, biurko, **drzwi-regał** (brama ma skrzydła z regałów zamiast krat); belki poddasza `timber_beam_4m`.

## 5. Decyzje — światło i atmosfera (`Floor1LightRecipe`, §10.1)

| Sala | Mgła (gęstość, kolor) | Sonda | Cienie | Uwagi |
|---|---|---|---|---|
| Galeria Partenonu | 0,005 chłodny kurz | tak | 2 | reflektory na frontony (zachodni dostaje cień), zmywania fryzu z sufitu, niebo w studniach |
| Pomnik Nereid | 0,006 | tak | 1 | reflektor na świątynię, ciepłe zmycie frontonu |
| Bassae / Wazy / Metopy | 0,007 | tak | 1 / 1 / 1 | ciepłe reflektory na metopy, lampki w gablotach — brak (gabloty wolnostojące) |
| Magazyn odlewów | 0,014 gips | — | 1 | przystań |
| Biblioteka | 0,013 papier, smugi | tak | 3 | lampy stojące z cieniem, kinkiety, lampki zielone, księżyc w studniach |
| Rotunda | 0,011 | tak | 1 | snop księżyca przez oculus na orrery (`moon_shaft`) |
| Gabinety, zegary, portrety | 0,012 papier | gabinet | 1 / 1 / 0 | snop na sztucer, snop przez zegar astronomiczny |

- **Grecja = najjaśniejsza:** mgła 0,005–0,007 (Egipt 0,017–0,03), lampy prawie nie świecą w mgle (`lamp_fog` 0,05), księżyc sam robi smugi; w każdej studni świetlika chłodne „niebo” (grupa MOON, bez mgły i cienia).
- **Oświecenie = ciepłe plamy:** `lamp_fog` 0,22 (plamy lamp w kurzu), kinkiety dolnego poziomu jako światła przepisu (mała energia, oprawa `lib_lamp_wall`), księżyc przez studnie jako kałuże.
- **Cząsteczki:** Grecja — tylko drobny srebrny kurz w snopach świetlików (mało); Oświecenie — kurz z książek nad osią i **kartki**: kilkanaście luźnych stron (`flying_book_page`) opadających i trzepoczących w powietrzu Biblioteki; rotunda — kurz w snopie oculusa. Grupa `quality_particles` (Low: brak).
- **Obwody:** wszystko, co świeci w modelach na oprawach (kinkiety, lampy, lampki), gaśnie z zaciemnieniem (grupy `*_fixtures`).

## 6. Wydajność i pomiar

- Regały to najcięższa część (~300 modułów i pilastrów w dwóch poziomach): węzły jako zwykłe instancje (Forward+ łączy równe siatki — P2 zmierzył MultiMesh jako wolniejszy); jeśli liczba wywołań rysowania okaże się zła, biegi jednego modelu na ścianę w `MultiMeshInstance3D`.
- Pomiar bez okna: czas budowy piętra z oprawą (zimno/ciepło), liczba `MeshInstance3D` i trójkątów obu stref, czas startu nocy w grze (scenariusz `dry`), światła i cienie po przycinaniu → §9.

## 7. Wycieczka

`tools/run_tour.sh`: + ~12 widoków Grecji i ~13 Oświecenia (w tym zaciemnienie Galerii Partenonu i Biblioteki), `PERF_VIEWS` + najcięższe nowe (Biblioteka od dziedzińca, galeria regałów, Partenon na długość, Nereidy). Uruchamiam tylko `dry`.

## 8. Zadania

### Zadanie 1: plan (ten dokument) — commit
- [ ] Plan.

### Zadanie 2: szkielet — strefy, style, delegacja, wspólne haki
- [ ] `ART_ZONES`, `ROOM_STYLES` obu stref, moduły skrzydeł (puste), delegacja w `Floor1Art`; klucze `stair_rails`/`fascia`/`middle_set`/`stairs_kit: library`, oprawy wiszące prosto, `PORTALS` z zestawem, `DecorSpinner.swing`, skrzydła bram.
- [ ] `Enlightenment.bays()` + kinkiety na pilastrach, światła przesunięte do opraw (bez zmian kolizji).
- [ ] Testy hubu (`--filter=floor1_art`) zielone (dozwolone listy uzupełnione); commit.

### Zadanie 3: Grecja — elementy i bohaterowie
- [ ] Wszystkie elementy (bez greyboksu), Pomnik Nereid, świetliki, fronton, belkowanie nad wylotem; commit.

### Zadanie 4: Oświecenie — elementy i bohaterowie
- [ ] Regały, galeria, oś, strop, schody, gabinety, rotunda, sekrety; commit.

### Zadanie 5: światło i atmosfera
- [ ] `Floor1LightRecipe`: sale, klucze, oprawy, światła dodatkowe, kurz, kartki; commit.

### Zadanie 6: testy skrzydeł
- [ ] `tests/integration/test_floor1_art_wings.gd`: style, liczby bohaterów (świątynia, świetliki, biegi regałów od pilastra do pilastra), sztucer w szafie przy znaczniku, wolny środek rotundy, kinkiety na pilastrach, Grecja jaśniejsza od Egiptu (mgła), kartki i kurz w Bibliotece, zaciemnienie gasi oprawy; commit.

### Zadanie 7: wycieczka + kontrola obrazu
- [ ] Widoki, `dry`; eksport glTF i render gliny w Blenderze (świątynia, regały); poprawki; commit.

### Zadanie 8: całość
- [ ] Scalić `pietro-1`; `--filter=floor1`, `--filter=art`, potem pełny zestaw raz (bez linii ERROR); §9; commit; raport.

## 9. Jak zbudowano

(uzupełniane na końcu)

## 10. Ryzyka

| Ryzyko | Odpowiedź |
|---|---|
| Kolizje strażników (Kentaur, Planetarium) | nic w ich bryłach nie zmieniam; środek rotundy pusty; test kolizji całego piętra |
| Świątynia nie pasuje do greyboksa (kolumny szerzej niż cella) | kolumny modelu przestawione na kolumny greyboksa, narożne ukryte |
| Koszt regałów | pomiar; w razie potrzeby MultiMesh na ścianę |
| Inne skrzydła P3 równolegle (te same słowniki) | własne pliki modułów; wpisy w słownikach w osobnych blokach |
| Nie widzę obrazu | testy, `dry`, render gliny; zrzuty kontrolera nocą |

## Stan prac / co dalej (WIP, przerwane 3.10 na polecenie koordynatora)

**Zrobione (commity na `dress-gr-enl`):** plan; strefy `greece` i `enlightenment` w `ART_ZONES`, style wszystkich sal, moduły `Floor1ArtGreece` / `Floor1ArtEnlightenment` (elementy, bohaterowie: świątynia Nereid na kolumnach greyboksa, świetliki, frontony wokół brył Kentaura, metopy, wazy, nadproże doryckie; regały od pilastra do pilastra w dwóch poziomach, kładka, balustrady, kolumny granitowe, gabloty, globusy, lampy, schody dębowe, gabinety, zegary z wahadłami, automaty, rotunda z mosiężną ekliptyką, drzwi-regał gabinetu Sloane'a), przepis światła obu skrzydeł (mgła, sondy, budżety cieni, niebo w studniach, zmywania fryzów, kinkiety dolne, kurz, kartki), wspólne haki (`stair_rails`, `fascia`, `middle_set`, oprawy wiszące prosto, `PORTALS` z zestawem, `DecorSpinner.swing`, przycinanie dekoracji w bryłach); testy `test_floor1_art_wings.gd` (10) + poprawione `test_floor1_art_fit/_light` — `--filter=floor1_art`, `floor1_east`, `floor1_west`, `floor1_layout` zielone; wycieczka +26 widoków (`dry`: 56 OK); render gliny w Blenderze sprawdzony (świątynia, regały, Partenon, gabinety).
**Pomiary (bez okna, zimno):** muzeum 7,4 s (P2: 5,55 s), piętro z oprawą 5,4 s (P2: 3,4 s), na ciepło 0,66 s; siatek 9 355 (P2: 6 799; Oświecenie 2 237, Grecja 1 355 w strefach); trójkąty: Oświecenie ~1,4 mln, Grecja ~0,6 mln. Sale w pamięci powłoki bez zmian (bez przeliczania).
**Ostatni commit WIP:** obrazy między portretami w Galerii Kolekcjonerów (testy tego kroku nie były jeszcze uruchomione).
**Co dalej:** uruchomić `--filter=floor1_art`; scalić `pietro-1`; pełny zestaw testów (bez linii ERROR); kontroler: `bash tools/run_tour.sh shots --preset=high && bash tools/run_tour.sh perf --preset=high` (wywołania rysowania przy regałach — w razie potrzeby MultiMesh na ścianę); uzupełnić §9 (jak zbudowano, odstępstwa: fryz Bassae na 5,7 m, światła przesunięte do opraw, lampy stojące na osi, brak portalu od strony biblioteki przy wejściu z dziedzińca).
