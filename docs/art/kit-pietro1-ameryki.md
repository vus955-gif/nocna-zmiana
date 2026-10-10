# Katalog grafiki: Piętro I — skrzydło Ameryk i Oceanii

> Gałąź `art-americas`. Projekt: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§5.6, §7.3, §7.4 — Dwugłowy Wąż, §10.1). Plan: `docs/superpowers/plans/2026-10-03-art-ameryki.md`. Greybox: `src/level/floor1/zones/americas.gd` (gałąź `p1-w4-north`).
> Wszystko powstaje skryptami Blendera w tle: `tools/art/models/kit_americas_walls.py`, `kit_americas_temple.py`, `kit_americas_fixtures.py`, `americas_exhibits.py`, `sun_stone.py`, `moai.py`, `war_canoe.py`, `pacific_exhibits.py`, `totem_poles.py`, `totem.py`, `jaguar.py`, `serpent.py`; wspólne biblioteki `tools/art/artlib/americas.py` (rampy i materiały), `americas_paint.py` (motywy pikselowe), `serpent_head.py` (jedna głowa węża dla schodów, mozaiki i strażnika), `clay.py` (metaballe z prawdziwymi zaokrąglonymi bryłami i bezpieczne `into_part`).
> **Osie:** liczby w osiach **Godota** (x w prawo, y w górę, −z = przód modelu). Blender (x, y, z) → Godot (x, z, −y). Lewa strona postaci = **−X**.
> **Szacunek:** stylizacja muzealna „w duchu” kultur, nie repliki — żadnej kopii Kamienia Słońca, Hoa Hakananai'a, konkretnych masek, słupów czy czółen; bez czaszek i motywów ofiarnych; znaki w kartuszach są wymyślone (kółka, kreski i kropki, spirale, fale, płomienie).

## 1. Paleta, motywy, gęstości

| Klasa | px/m | Modele |
|---|---|---|
| pola kafelkowe, pasy ścian, portal | 64 (cokoły i panele Pacyfiku 96) | `am_*`, `americas_frieze_*`, `americas_cornice_*`, `pacific_beam_*`, `americas_portal_4m` |
| rzeźbione elementy świątyni | 96 | `temple_*`, `pacific_post` |
| duże eksponaty | 96–128 | `totem_pole_*` 96, `war_canoe` 96, `moai` 128, `sun_stone` 128, `tapa_hanging` 128, `whaling_rack` 128 |
| oprawy, gabloty, rekwizyty | 128–192 | `americas_brazier` 128, `harpoon_stand` 160, `pacific_figures` 160, `mask_case` / `feather_case` 192, `americas_torch_lamp` 192 |
| drobne eksponaty | 256 | `turquoise_mask`, `serpent_mosaic`, `clay_figures` |
| wrogowie | 192 / 256 | `totem` 192 (5 m słup, strzela się z dystansu), `jaguar` 256 |
| strażnik | 112 | `serpent` (14,5 m) |

Rampy (`P`, przedrostek `am_`, `artlib/americas.py`): ciemnoczerwony tynk, bazalt, andezyt, stiuk, turkus i turkus zielony, muszla, spondylus (czerwona muszla), obsydian, jadeit, ochra, błękit majański, glina czerwona i płowa, włókno maty i włókno barwione, tapa i jej tusz, ciemne drewno Pacyfiku, drewno rzeźbione, pióra (czerwone, żółte, zielone, niebieskie), lina, żywica, płomień, żar, futro jaguara (`am_pelt`).

**Motywy pikselowe** (`artlib/americas_paint.py`, piksel = teksel): schodkowy meander (xicalcoliuhqui), rzędy paciorków, 12 znaków w kartuszach z kropkowaną obwódką, quincunx, wężowy pas z pióropuszami, piórowe obrzeża, pasy tapy (trójkąty, zygzaki, drabinki, kratka, gwiazdy, liście), splot maty 2/2 z rombami z pasm barwionych. Płótna reliefowe mają poziomy (0 pole, 1 pas, 2 motyw, 3 wysoki relief) i oświetlenie pikselowe `relief_shade` (jasna krawędź z lewej u góry, cień rzucany w prawo w dół).

**Materiały:** tynk polerowany (połysk smug pacy), kamień wulkaniczny z pęcherzykami i śladami dłuta, bazalt (oliwinowe błyski), mozaika (tessery z komórek Voronoi, ciemna żywica w fugach, minimum ~4,5 teksela na tesserę; dla masek rzut płaski `plane="xz"`), muszla, obsydian (lustrzany, muszlowe przełomy na krawędziach), glina polerowana z plamami ognia, drewno rzeźbione (fasety ciosła), pióra, lina, żelazo kute, żar i płomień (emisja).

## 2. Pola kafelkowe (64 px/m, `ArtLibrary.arch_tile` / `tile:<nazwa>`)

| Tekstura | Kafel | Co to jest | Gdzie |
|---|---|---|---|
| `am_red_wall` | 4 × 3 m | polerowany tynk wapienny w głębokiej czerwieni, smugi pacy łapiące lampę, rysy | ściany Meksyku, Ameryki Płn., Sali Totemów |
| `am_frieze` | 8 × 1 m | rzeźbiony fryz z andezytu: paciorki, schodkowe meandry, pary kartuszy, wąż z pióropuszami, quincunksy, wiszące pióra; resztki czerwieni, turkusu, bieli i ochry w zagłębieniach | lico `americas_frieze_*` |
| `am_stone_blocks` | 4 × 3 m | ciosy andezytu 0,5 m (0,5–1,25 m dł.), fugi wapienne, płaty starego stiuku | tarasy świątyni (bryły greyboxa), ościeża, Sala Moai (z odcieniem) |
| `basalt_americas` | 4 × 4 m | polerowane płyty bazaltu 1 × 1 i 2 × 1 m, matowa ścieżka | posadzki Meksyku, Moai, Totemów |
| `am_woven_mat` | 2 × 2 m | mata z pandanu, splot 2/2 pasm 6 cm, schodkowe romby z pasm barwionych | panele `pacific_dado_*`, kapelusze |
| `boards_pacific` | 2 × 2 m | ciemne deski 0,25 m z kołkami | ściany i podłoga Galerii Pacyfiku |
| `am_tapa` | 4 × 4 m | tapa: pola z drukiem w dwóch brązach i czerni | strop Pacyfiku |
| `am_ceiling` | 4 × 2 m | okopcone deski między okrągłymi belkami co 1 m | stropy Meksyku, Moai, Totemów |

Style pomieszczeń dopisane do `ArtKit.ROOMS`: `americas_temple` (fryz na 7 m), `americas_north` (fryz na 4 m), `americas_totems`, `americas_moai` (ciemny kamień, sam cokół), `americas_pacific` (= `americas_pit`), `americas_moai_hideout`, `americas_workshop`. `ArtKit.piece(id_modelu, rozmiar, pokój)` skaluje każdy element z `KIT_AMERICAS` do rozmiaru (rozmiar / natywny).

## 3. Zestaw architektury (`ArtLibrary.KIT` + `KIT_AMERICAS`)

Konwencja pasów jak w holu: x od −W/2 do W/2, płaszczyzna ściany z = 0, dekoracja na −Z; moduły 4 / 2 / 1 / 0,5 m łączą się bez szwu (wzory liczone od lewego końca modułu, cykl 0,5 m lub 1 m).

| Id | Rozmiar (x × y × z) | Trójkąty | Opis, datum | Rozmieszczenie |
|---|---|---|---|---|
| `americas_dado_4m/2m/1m/05m` | L × 1,28 × 0,17 | 32 | polerowany czarny bazalt (spoina co 1 m) na bazaltowej stopie, wałek z muszli, pas 0,31 m turkusowych meandrów wpuszczonych w obsydian (cykl 0,5 m), bazaltowa czapa; 96 px/m; datum = podłoga | dół ścian Meksyku, Ameryki Płn., Totemów, Moai |
| `americas_frieze_*` | L × 1,32 × 0,10 | 26 | lico 1 m = pole `am_frieze` między schodkową półką a schodkowym okapem (wystają 0,16 m w dół i w górę); **datum = dolna krawędź lica na pełnym metrze** | 7 m w Świątyni (h 12), 4 m w Sali Ameryki Płn. (h 7) |
| `americas_cornice_*` | L × 0,90 × 0,46 | 198–1 430 | czerwony talud, rząd rzeźbionych schodkowych bloków co 0,25 m (biały stiuk), turkusowa fascja, bazaltowa korona; datum = sufit | pod stropem |
| `pacific_dado_*` | L × 1,40 × 0,13 | 106–722 | panele maty w ramie z ciemnego drewna, słupki co 0,5 m, owijki z liny na górnej listwie; 96 px/m; datum = podłoga | Galeria Pacyfiku |
| `pacific_beam_4m/2m/1m` | L × 0,45 × 0,35 | 132 | malowana krokiew (czerwone i czarne trójkąty między białymi liniami, szewrony na podsufitce), owijki na końcach; datum = sufit | w poprzek Pacyfiku co 2 m |
| `pacific_post` | 0,72 × 4,00 × 0,40 | 2 840 | słup ścienny: płaski tył, karbowane pasy, przysadzista postać przodka w wysokim reliefie z oczami z masy perłowej (paua); części `pacific_post`, `pacific_post_figure`; skalować Y do sali | ściany Pacyfiku co ~6 m |
| `temple_tier_4m/2m/1m` | L × 1,50 × 0,50 | 26 | lico tarasu: talud z ciosów i stiuku, rama tablero (czerwony stiuk), wklęsłe tablero z turkusowymi schodkowymi meandrami i kolumną paciorków (cykl 1 m), cokół-koronka na równi z wierzchem tarasu; 96 px/m; **początek na podłodze na krawędzi bryły tarasu (z = 0), lico 0,5 m na −Z** | po obwodzie brył `temple_tier` (zostawić 0,5 m na narożnik, 3,4 m na bieg) |
| `temple_tier_corner` | 1,00 × 1,50 × 1,00 | 52 | narożnik zewnętrzny: dwa ramiona po 0,5 m (wzdłuż −X licem na −Z i wzdłuż +Z licem na +X), ucięte na skos; obracać co 90° | 4 na taras |
| `temple_stair` | 4,34 × 2,16 × 4,73 | 4 424 | bieg 3 m szerokości, 10 stopni 0,15 × 0,40 (1,5 m na 4 m), balustrady (alfardy) 0,45 m po bokach jako łuskowate ciało węża z koronami na górze; część **`serpent_heads`** = dwie głowy węży z otwartymi paszczami u stóp (wystają 0,7 m przed pierwszy stopień); rama `StairsSpec.frame()` (środek dolnej krawędzi pierwszego stopnia, −Z w górę biegu) | 4 biegi Świątyni; na górnych biegach ukryć `serpent_heads` |
| `temple_shrine` | 2,40 × 2,48 × 2,40 | 1 156 | dom ołtarza: cokół, ściany z czerwonego stiuku, drzwi 0,9 × 1,3 na −Z z rzeźbionym nadprożem (kartusze), płaski dach, schodkowe blanki; w środku palenisko z żarem; znacznik **`Light`** (0; 0,6; 0,25) | górny taras (greybox `shrine`) |
| `temple_altar` | 1,60 × 1,24 × 1,60 | 292 | niski ołtarz: stopień, blok z kartuszami i quincunksem na czterech bokach, płyta, misa z popiołem | `altar` przy ścianach (osłona) |
| `americas_brazier` | 0,87 × 1,47 × 0,91 | 1 395 | misa ogniowa: schodkowy postument, gliniany kocioł z dwoma rzędami guzów, żar; część **`flame`** (języki ognia, emisja: migotać skalą, ukryć przy zgaszeniu); znacznik **`Light`** (0; 1,3; 0) — tam, gdzie greybox `brazier` stawia OmniLight | narożniki Świątyni, sale |
| `americas_torch_lamp` | 0,34 × 0,52 × 0,52 | 673 | ścienna misa ognia na żelaznym wsporniku, część `flame`; **oprawa: początek = światło (`Light`)**, wspornik 0,34 m w +Z do ściany | zamiast `sconce` w skrzydle |
| `americas_portal_4m` | 5,82 × 6,22 × 0,90 | 608 | portal otworu 4 × 4,5: rzeźbione ościeża z pięcioma kartuszami, nadproże z fryzem, schodkowe blanki, stiukowe ościeże 0,5 m w głąb (skalować Z do muru); początek = środek podłogi otworu na licu ściany | `frame_4` stylów `americas_*` |

## 4. Eksponaty (`KIT` + `KIT_AMERICAS`, o ile nie zaznaczono `REGISTRY`)

| Id | Rozmiar | Trójkąty | Części / znaczniki | Rozmieszczenie, uwagi |
|---|---|---|---|---|
| `sun_stone` | 3,60 × 4,05 × 1,10 | 2 392 | `sun_stone` (kołyska), `sun_stone_disc` | dysk 3,6 m z bazaltu w schodkowej kołysce: spokojna twarz słońca, cztery panele ze spiralami, 20 kartuszy, pierścień paciorków, 8 dużych i 8 małych promieni, dwa węże na obwodzie (głowy u dołu, ogony pod kwadratowym kartuszem u góry); resztki farby głównie w zagłębieniach, stary przełom na prawym dolnym brzegu; tabliczka „DYSK SŁONECZNY / MEKSYK” | ściana Galerii Meksyku, światło z dołu |
| `mask_case` | 2,42 × 1,60 × 1,02 | 9 172 | `mask_case`, `mask_case_glass`, **`mask_1..3`** (maski jako części: gra może je wyrzucić przy stłuczeniu) | czarna lakierowana gablota z czerwoną opaską, tabliczka „MASKI MOZAIKOWE / MEKSYK”: maska turkusowa, jadeitowa z pasem obsydianu i złota, muszlowa z pasem spondylusa; oczy z muszli, źrenice z obsydianu, czerwone usta, zęby, złote nauszniki | `case` (2,4 × 1,6 × 1) Sali Ameryki Płn. i Meksyku |
| `turquoise_mask` | 0,26 × 0,44 × 0,17 | 2 816 | `turquoise_mask`, `turquoise_mask_stand` | ta sama maska osobno na stojaku | na cokołach, w zbliżeniach |
| `serpent_mosaic` | 1,31 × 1,76 × 0,60 | 4 560 | `serpent_mosaic` (cokół, pręty, okucia), `serpent_body`, `serpent_mosaic_glass` | dwugłowy wąż z turkusowej mozaiki (W-kształt, 1,1 m) z czerwonymi paszczami i zębami z muszli pod szklanym kloszem; tabliczka „WĄŻ DWUGŁOWY / MOZAIKA TURKUSOWA” — zapowiedź strażnika | przy wejściu do Świątyni |
| `clay_figures` | 1,60 × 1,41 × 1,00 | 3 810 | `clay_figures`, `clay_figures_pieces` | schodkowy czerwony podest: pulchny pies z polerowanej gliny, siedząca postać z nausznikami, stojący wojownik z maczugą (glina płowa), trójnożna misa; „GLINA / ZACHODNI MEKSYK” | Galeria Meksyku |
| `feather_case` | 2,22 × 1,80 × 0,82 | 1 920 | `feather_case`, `feather_case_glass`, `feather_pieces` | gablota przyścienna: okrągła tarcza z piór (niebieski meander na żółtym, czerwony obrzeże, frędzle zielonych piór, złote dzwoneczki) i wachlarz z długich zielonych piór; „PIÓROPUSZE / MEKSYK” | `case` 2,2 × 1,8 × 1 |
| `moai` — **`REGISTRY`** | 2,46 × 3,73 × 2,46 | 5 910 | `moai_plinth` (korzeń), **`moai`** (oś (0; 1,2; 0) na wierzchu cokołu, dziecko cokołu), znaczniki **`hook_ring`** (0; 1,415; 0,9) i `face` (0; 3,14; −0,3), dzieci `moai` | patrz §6 |
| `war_canoe` — **`REGISTRY`** | 3,32 × 4,60 × 14,38 | 6 872 | patrz §7 | czółno nad zapadniętą podłogą |
| `whaling_rack` — **`REGISTRY`** | 3,04 × 2,00 × 0,20 | 2 008 | `whaling_rack`, **`weapon_spot`** (0; 0,62; −0,17) | tablica wielorybnicza na ścianę: trzy harpuny z ruchomym ostrzem, lanca, łopata do krojenia tranu, zwój liny, tabliczka „WIELORYBNICTWO / XIX WIEK”, pusta podpórka z filcem = miejsce HARPUNNIKA (lufą wzdłuż X); początek na płaszczyźnie ściany pośrodku dolnej krawędzi | greybox `harpoon_rack` (3 × 2 × 0,15 na y 1,2) |
| `harpoon_stand` — **`REGISTRY`** | 0,70 × 1,06 × 0,50 | 394 | `harpoon_stand`, **`weapon_spot`** (0; 1,06; 0) | tekowy stojak z widełkami obszytymi filcem, „HARPUNNIK / 1890” | greybox `plinth` + `weapon_harpoon` (HARPOON y 1,0) |
| `tapa_hanging` | 2,40 × 3,84 × 0,17 | 1 584 | jedna siatka; zestawy **`tapa_hanging_b`, `tapa_hanging_c`** | tapa 2 × 3 m na rzeźbionym drążku na dwóch sznurach, miękkie fałdy; początek = środek drążka na płaszczyźnie ściany (wisi w dół, sznury 0,75 m w górę) | ściany Pacyfiku, gabloty tapy |
| `pacific_figures` | 1,02 × 1,80 × 1,02 | 3 872 | `pacific_figures`, `pacific_figures_glass`, `pacific_figures_pieces` | wysoka gablota z dwiema rzeźbami z ciemnego drewna: smukła postać przodka z żebrami i haczykowatym nosem, przysadzista postać z wielką głową; oczy z muszli i obsydianu; „RZEŹBY PRZODKÓW / OCEANIA” | `case` 1 × 1,8 × 1 w Sali Moai |
| `totem_pole_memorial` | 1,20 × 8,71 × 1,40 | 5 310 | jedna siatka | gładki trzon z spiralnymi śladami ciosła, na szczycie orzeł ze złożonymi skrzydłami (formline czarny i turkus), żółty dziób, szpony na krawędzi | greybox `totem_pole` (1 × 10 × 1) |
| `totem_pole_house` | 1,70 × 9,05 × 1,10 | 6 638 | jedna siatka | słup frontowy domu: Niedźwiedź u stóp z **owalnym przejściem 0,8 × 1,5 m przez brzuch** (przechodnie), Bóbr z siekaczami i patykiem, okrągła twarz Księżyca na górze; płaski tył, formline (owoidy, U-formy) na płycie | ściana Sali Totemów |
| `totem_pole_welcome` | 2,39 × 4,10 × 1,12 | 4 040 | jedna siatka | postać powitalna z jednego pnia: kapelusz z kory, ramiona szeroko w górę, malowany koc z formline | przy wejściu do Sali Totemów |
| `totem_log` | 6,00 × 1,51 × 1,48 | 2 380 | jedna siatka | nieskończony słup: pień 6 m na dwóch kozłach, zgrubnie wyciosana pierwsza twarz z liniami kredy, wióry na podłodze, cieślica na pniu; leży wzdłuż X | greybox `totem_log` w warsztacie (sekret) |

Emisja (`EXTRAS`): `americas_brazier` 4,0, `americas_torch_lamp` 4,0, `temple_shrine` 3,0 (żar), `totem` 2,5, `jaguar` 2,4, `serpent` 2,2. `EXHIBIT_RIM`: `totem` 0,35, `jaguar` 0,5, `serpent` 0,24.

## 5. Proponowany układ (tak stoi w ujęciach `tools/art/americas_vignette.py`)

- **Świątynia Węża** (20 × 27, h 12): czerwone ściany z cokołem, fryzem na 7 m i gzymsem; tarasy greyboxa T1 (11,5 × 13,5 × 1,5) i T2 (7,5 × 5,5 × +1,5) obłożone `temple_tier_*` i narożnikami; po dwa `temple_stair` na licach północnym i południowym (na górnych biegach bez głów); `temple_shrine` na T2; `temple_altar` przy bocznych ścianach; `americas_brazier` w narożach; `sun_stone` i `mask_case` na długich ścianach, `serpent_mosaic` przy wejściu. Światło: reflektory z podłogi na lica tarasów, snop księżyca przez świetlik na dom ołtarza, ogień w misach.
- **Sala Moai**: ciemny kamień, sam cokół; `moai` przodem do sali, jedyne mocne światło: reflektor z podłogi 3 m przed twarzą celujący w znacznik `face`; `pacific_figures` w gablotach, przygaszone pochodnie.
- **Galeria Pacyfiku**: deski i panele maty, strop z tapy, krokwie co 2 m, słupy `pacific_post`; `war_canoe` pod stropem; `whaling_rack` na ścianie północnej z `harpoon_stand` przed nią i latarnią; `tapa_hanging`, `feather_case`.
- **Sala Totemów** (h 12): `totem_pole_house` na ścianie, `totem_pole_memorial`, `totem_pole_welcome`; wrogowie `totem` i `jaguar`; ogień u stóp słupów, światło z dołu.

## 6. Moai i sekret za nim

`moai_plinth` (2,4 × 1,2 × 2,4: ciemne ciosy, profilowana płyta, tabliczka „MOAI / RAPA NUI”) jest korzeniem; **`moai`** (posąg 2,45 m z bazaltu na brązowej tarczy obrotowej 0,08 m) jest jego dzieckiem z osią w środku wierzchu cokołu (0; 1,2; 0). Z tyłu tarczy (+Z) żelazny wspornik z kółkiem: **`hook_ring`** (0; 1,415; 0,9), dziecko `moai` — obraca się razem z głową. Sekret: harpun trafia w kółko, `moai.rotation.y` → np. 90° w 1,5 s (kamienne tarcie), otwierają się drzwi za cokołem. Znacznik `face` (0; 3,14; −0,3) — między oczodołami, cel dla reflektora z dołu (głębokie oczodoły, brew i nos dają mocne cienie). Greybox ma `moai` 2,4 × 5,2 × 2,0 na cokole 1,4 m — model jest niższy (bliżej prawdziwej skali eksponatu 2,4 m); jeśli ma przytłaczać, skalować jednolicie (np. 1,3).

## 7. Czółno wojenne (`war_canoe`, `REGISTRY`)

12 m kadłuba (14,4 m z dziobnicą i rufową stewą), dłubanka z doszywanymi burtami malowanymi w czerwono-czarne trójkąty między białymi liniami, ścieg liny pod burtą, smołowane dno; pokład bojowy z desek wzdłuż osi (góra na y 0,5, szer. 0,8 m, od z −4,6 do 4,6), deska falochronu, dziobnica z ptasią głową (hakowaty dziób, oczy z masy perłowej, pióropusz), rufowa stewa 3,1 m z czerwonymi pióropuszami, pływak wysięgnika na trzech belkach (po +X) z przywiązanymi wiosłami, żelazne kółka na dziobie i rufie; muzealne zawieszenie: belka rozporowa i cztery zawiesia + jedna lina do stropu.

| Część / znacznik | Oś / pozycja (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `war_canoe` | (0; 0; 0) = spód stępki w połowie długości | — | kadłub, pokład, wysięgnik, stewy; **oś do obrotu w most** |
| `prow` | (0; 1,0; −6,3) | war_canoe | rzeźba dziobu |
| `sling` | (0; 2,6; 0) środek belki | war_canoe | zawiesia (ukryć, gdy czółno leży jako most) |
| `rope_main` | (0; 2,6; 0) — **oś na DOLE liny** | sling | lina 2 m w górę: co klatkę `scale.y = (strop − y_świata) / 2`, by zawsze sięgała haka |
| `rope_top` | (0; 4,6; 0) | rope_main | górny koniec liny |
| `hook_ring` | (0; 0,72; −6,54) | war_canoe | kółko na dziobie (cel harpuna) |
| `hook_ring_stern` | (0; 0,8; 6,52) | war_canoe | kółko na rufie |
| `deck` | (0; 0,5; 0) | war_canoe | wierzch pokładu (chodzenie) |
| `bridge_bow` / `bridge_stern` | (0; 0; ∓4,6) | war_canoe | punkty oparcia na krawędziach jamy |

**Spoczynek:** wisi poziomo wzdłuż jamy (greybox: długość wzdłuż z, `CANOE` y 6,5). **Ruch w most:** krótkie wahnięcie (`rotation.z` ±8°) przy szarpnięciu, potem obrót `rotation.y` o 90° (dziób ku harpunowi) z opadaniem na krawędzie i lekkim przechyłem, lina się wydłuża; na końcu `sling` ukryty lub luźny. Greybox ma czółno 7,4 m nad jamą 5,5 × 8 m: przy 12 m albo powiększyć jamę / zawiesić czółno w galerii, albo skalować jednolicie ~0,65.

## 8. Totem (wróg, `REGISTRY`)

Słup z czerwonego cedru, pięć twarzy (od dołu): **Niedźwiedź** (szeroki pysk, okrągłe uszy, język między zębami), **Żaba** (wyłupiaste oczy na górze, szeroka paszcza), **Wilk** (długi pysk z otwartą szczęką, spiczaste uszy), **Przodek** (ludzka twarz, ciężkie brwi), **Orzeł** (wielki zakrzywiony dziób); na szczycie kapelusz z kory. Malowanie jaśniejsze niż Haida z dziedzińca (czerń, czerwień, zieleń, biel, ochra), na bokach owoidy i podzielone U-formy. Oczy: bursztynowe z pionową źrenicą, emisja.

| Część / znacznik | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `totem` | (0; 0; 0) | — | pień 0,35 m z kamiennym kołnierzem |
| `block_1..5` | (0; 0,35 + 0,85·(k−1); 0) — dół bloku | `block_1` ← `totem`, `block_k` ← `block_k−1` | twarze-wieżyczki; ukrycie bloku ukrywa wszystko nad nim; twarz można „opuścić” na niższą, przesuwając dziecko o −0,85 |
| `eyes_1..5` | (0; środek oczu; −0,42) | block_k | zapowiedź strzału: `set_instance_shader_parameter(&"glow", …)` tylko na tej części |
| `cap` | (0; 4,6; 0) | totem | kapelusz: `cap.position.y = 0,35 + 0,85·n` gdy zostało n twarzy (albo zrzucić z górną twarzą) |
| `face_1..5` | (0; 0,87 / 1,79 / 2,59 / 3,41 / 4,31; −0,48) | block_k | środek twarzy na powierzchni = słaby punkt / środek trafień |
| `mouth_1..5` | (0; 0,55 / 1,5 / 2,35 / 3,14 / 3,99; −0,62 / −0,56 / −0,74 / −0,58 / −0,72) | block_k | wylot odłamka (strzał wzdłuż −Z bloku) |

Wysokość 5,14 m z kapeluszem, 6 776 trójkątów, atlas 928 × 1568 @ 192. Strzelanie od góry: przy 3 twarzach ukryć `block_4` (z `block_5`) i opuścić `cap`.

## 9. Wojownik-jaguar (wróg, `REGISTRY`)

~1,83 m: rzeźbiona i malowana postać w stroju jaguara (płowe futro z czarnymi rozetami malowane na drewnie, przetarte do drewna na krawędziach), surowa twarz wojownika w otwartej paszczy hełmu (kły nad i pod twarzą, okrągłe uszy, oczy jaguara w turkusowych pierścieniach, ciemny nos), turkusowe nauszniki, mankiety i pektorał, czerwona przepaska, łapy z obsydianowymi pazurami, ogon; w prawej ręce płaska drewniana maczuga z obsydianowymi zębami po obu krawędziach (na wzór macuahuitl), na lewym przedramieniu okrągła tarcza z piór. Oczy wojownika żarzą się (emisja).

| Część | Oś (Godot) | Rodzic | Uwagi |
|---|---|---|---|
| `pelvis` | (0; 0,95; 0) | — | korzeń (biodra, przepaska) |
| `torso` | (0; 1,05; 0) | pelvis | talia |
| `head` | (0; 1,48; 0) | torso | szyja: hełm i twarz |
| `arm_l` / `arm_r` | (∓0,24; 1,40; 0) | torso | barki |
| `forearm_l` / `forearm_r` | (∓0,28; 1,14; 0) | arm_* | łokcie (dłonie w przedramionach) |
| `club` | (0,29; 0,86; −0,05) | forearm_r | uchwyt w prawej dłoni, ostrze w dół |
| `shield` | (−0,34; 1,0; 0,02) | forearm_l | tarcza licem na −X |
| `thigh_l` / `_r` | (∓0,10; 0,93; 0) | pelvis | biodra |
| `shin_l` / `_r` | (∓0,11; 0,50; −0,02) | thigh_* | kolana |
| `foot_l` / `_r` | (∓0,11; 0,09; 0) | shin_* | kostki |
| `tail_1` > `tail_2` | (0; 0,92; 0,11) > (0; 0,55; 0,30) | pelvis | ogon |

Znaczniki: **`face`** (0; 1,60; −0,142), dziecko `head` — środek twarzy (słaby punkt); `club_tip` (0,29; 0,06; −0,08), dziecko `club` — koniec ostrza (strefa ciosu). 10 028 trójkątów, atlas 1024 × 640 @ 256.

**Pozy (sprawdzone w `americas_vignette_totems.png`):** spoczynek = stoi, maczuga wisi. **Przysiad przed skokiem:** `pelvis.position.y` −0,35, `torso.rotation.x` −35° (pochylenie do przodu), `thigh_*.rotation.x` +60°, `shin_*.rotation.x` −95°, `head.rotation.x` +20° (patrzy na strażnika), maczuga w tył: `arm_r.rotation.x` −40°. **Sprint na czworakach jak wilk:** jw. z naprzemiennym `thigh` ±30° i `arm_l` ±35°. **Skok (lot):** `pelvis.position.y` +0,55, `torso.rotation.x` −25°, `arm_r.rotation.x` +150° (maczuga nad głową), `forearm_r.rotation.x` +40°, `thigh_l` +75° / `thigh_r` +40°, `shin_*` −1,4 × kąt uda, `tail_1.rotation.x` −40°. **Cios:** `arm_r.rotation.x` z +150° do +20° w 0,25 s.

## 10. Dwugłowy Wąż (strażnik, `REGISTRY`)

14,5 m węża z turkusowej mozaiki na rzeźbionym drewnianym rdzeniu, głowa na każdym końcu: **głowa A pluje** (zielono-złoty pióropusz), **głowa B kąsa** (czerwono-czarny pióropusz, dłuższe kły ×1,35). Płytki: turkus z łańcuchem białych rombów z muszli w obsydianowej obwódce wzdłuż grzbietu, czerwone zygzaki ze spondylusa na bokach, rzędy złotych paciorków, złote obręcze między segmentami, biały brzuch z muszli; głowy: otwarte szczęki, czerwone wnętrze paszczy, zęby i kły z muszli, obsydianowe oczy w złotych pierścieniach, złoty zwój nosa, wysunięty rozwidlony język. Spoczynek: prosto i poziomo, brzuch na podłodze, głowy uniesione na szyjach.

| Część / znacznik | Oś (Godot) | Rodzic | Do czego |
|---|---|---|---|
| `segment_1..14` | (0; oś ciała; −5,25 + 0,75·(k−1)) — złącze od strony A | `segment_1` korzeń, `segment_k` ← `segment_k−1` | ciało; łańcuch do wyginania lub ustawiania segmentów na ścieżce (`global_transform` po kolei) |
| `tiles_1..14` | jw. | segment_k | **płytki mozaiki**: ukryć (albo wyrzucić jako odłamki), gdy zestrzelone — pod spodem rdzeń z ciemnego drewna i żywicy ze **świecącymi pęknięciami** (słaby punkt) |
| `skull_a` | (0; 0,78; −5,25) szyja | segment_1 | głowa A (patrzy −Z) |
| `jaw_a` | (0; 0,66; −5,48) zawias | skull_a | `rotation.x` < 0 otwiera (spoczynek: 14°) |
| `skull_b` | (0; 0,78; 5,25) | segment_14 | głowa B (patrzy +Z) |
| `jaw_b` | (0; 0,66; 5,48) | skull_b | `rotation.x` > 0 otwiera |
| `seg_1..14` | środek segmentu na osi (y 0,43–0,52) | segment_k | środki trafień segmentów |
| `head_a` / `head_b` | (0; 0,93; ∓6,1) | skull_* | wnętrze czaszki = słaby punkt głowy |
| `mouth_a` / `mouth_b` | (0; 0,59; ∓7,19) | skull_* | wylot odłamka turkusu (A) / punkt ugryzienia (B) |

Promień ciała 0,40 przy szyjach → 0,52 w środku; głowa 1,9 m od szyi do pyska. **Ruch:** fala bocznych skrętów `segment_k.rotation.y = A·sin(ωt − k·φ)` (A ≈ 15–25°, φ ≈ 0,6) przesuwa się od głowy prowadzącej; po tarasach: ustawiać segmenty na ścieżce (znaczniki greyboxa `serpent_path_*`) — segmenty mają po 0,75 m, wznoszenie 1,5 m na biegu da się pokryć pochyleniem `rotation.x` 2–3 segmentów. **Pluć (A):** `skull_a.rotation.x` +15° (unosi), `jaw_a` −35°, odłamek z `mouth_a`. **Wypad (B):** cofnięcie (`skull_b.rotation.x` −10°, syk 0,7 s z `jaw_b` +40°), potem wypad 3 segmentów naprzód. **Ogon** (faza 1–2): koniec przeciwny do aktywnej głowy omiata (ostatnie 4 segmenty `rotation.y` ±40°). 16 524 trójkąty, atlas 2176 × 1248 @ 112.

## 11. Podglądy (Cycles, `tests/_out/art/`)

- **Nastrój całości:** `americas_vignette_temple.png`, `americas_vignette_temple_serpent.png` (wąż upozowany obrotami segmentów), `americas_vignette_moai.png`, `americas_vignette_pacific.png`, `americas_vignette_totems.png` (jaguar w skoku). Skrypt: `"D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup --python tools/art/americas_vignette.py -- [temple moai pacific totems] --samples 64`.
- **Strażnik i wrogowie:** `serpent.png`, `serpent_head_a.png`, `serpent_head_b.png`, `serpent_body.png`, `totem.png`, `totem_top.png`, `totem_bottom.png`, `jaguar.png`, `jaguar_closeup.png`, `jaguar_club.png`.
- **Eksponaty:** `sun_stone.png`, `sun_stone_centre.png`, `moai.png`, `moai_closeup.png`, `moai_below.png`, `moai_ring.png`, `war_canoe.png`, `war_canoe_prow.png`, `mask_case_masks.png`, `turquoise_mask_closeup.png`, `serpent_mosaic_serpent.png`, `clay_figures_pieces.png`, `feather_case_pieces.png`, `pacific_figures_figures.png`, `whaling_rack.png`, `tapa_hanging.png`, `totem_pole_house.png`, `totem_pole_memorial_eagle.png`, `totem_pole_welcome.png`, `totem_log.png`.
- **Zestaw:** `temple_stair.png`, `temple_stair_head.png`, `temple_tier_4m.png`, `temple_tier_corner.png`, `temple_shrine.png`, `temple_altar.png`, `americas_dado_4m.png`, `americas_cornice_4m.png`, `pacific_dado_4m.png`, `pacific_beam_4m.png`, `pacific_post_figure.png`, `americas_brazier.png`, `americas_portal_4m.png`; tekstury: `view_am_frieze.png`, `view_am_woven_mat.png`, `view_am_tapa.png`, `view_am_stone_blocks.png`.

## 12. Uczciwie: słabe punkty

- Postacie i rzeźby to „glina” z metaballi: sylwetki i proporcje czytają się z 3–10 m, z bliska twarze (maski, figurki, słupy) są uproszczone; najmocniejsze są głowy węża (wspólny moduł `serpent_head.py`) i moai.
- Słupy dekoracyjne (zwłaszcza powitalny) są prostsze niż totem Haida z dziedzińca; formline jest malowany, nie rzeźbiony.
- Ciało węża w spoczynku to prosta rura — życie daje mu dopiero animacja (sprawdzona obrotami segmentów w ujęciu Świątyni); płytki to jedna skorupa na segment (zestrzeliwane w całości, nie pojedynczo).
- Skale do uzgodnienia z greyboxem: czółno 12 m (greybox 7,4 m nad jamą 8 m), moai 2,45 m (greybox 5,2 m).
- Sali Ameryki Północnej nie wyposażono w osobne modele (tipi, bizon, kajak zostają greyboxem); ma styl ścian i może brać `mask_case`, `feather_case`, `totem_pole_*`.
- Pole `am_stone_blocks` jest regularne (bliżej muru niż starego tarasu); tarasy ratuje rzeźbione lico `temple_tier_*`.

## 13. Testy i budowa

- `tests/integration/test_art_americas.gd` (bez okna): każdy element `KIT_AMERICAS` w natywnym rozmiarze i budżecie, pola i zestawy tekstur, datumy pasów i ramy świątyni, łańcuch i znaczniki Totemu, stawy jaguara, łańcuch, płytki, głowy i znaczniki węża, moai na tarczy z kółkiem z tyłu, osprzęt czółna, miejsca harpunnika, style pomieszczeń. Budżety elementów: `KIT_AMERICAS` (wpis w `_budget` testu `test_art_kit.gd`).
- Przebudowa wszystkiego (jeden proces Blendera, ~25 min): `"D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup --python tools/art/build_models.py -- kit_americas_walls kit_americas_temple kit_americas_fixtures americas_exhibits sun_stone moai war_canoe pacific_exhibits totem_poles totem jaguar serpent` (`--fast` bez AO), potem `tools/art/import_settings.py` i import Godota. Tekstury pól: `python tools/art/build_textures.py am_red_wall am_frieze am_stone_blocks basalt_americas am_woven_mat boards_pacific am_tapa am_ceiling`.
