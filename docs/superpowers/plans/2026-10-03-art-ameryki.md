# Plan: grafika skrzydła Ameryk i Oceanii (Piętro I)

> **Gałąź:** `art-americas` (drzewo robocze `.claude/worktrees/art-americas`, od `pietro-1`). **Projekt:** `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §5.6, §7.3 (Totem, Wojownik-jaguar), §7.4 (Dwugłowy Wąż), §10.1–10.2. **Greybox:** `src/level/floor1/zones/americas.gd` (gałąź `p1-w4-north`): Sala Ameryki Północnej, Sala Totemów (12 m), Sala Moai (9 m, jedna głowa w ciemności), Galeria Pacyfiku (10 m, wieloryby i harpunnik, czółno nad zapadniętą podłogą), Świątynia Węża (12 m, schodkowe tarasy 1,5 + 1,5 m, biegi 3 m).
> **Wzorce jakości i konwencji:** `docs/art/kit-pietro1-egipt.md`, `docs/art/kit-pietro1-dziedziniec.md`, `docs/art/kit-pietro1-oswiecenie.md`.
> **Zasady:** wszystko skryptami Blendera w tle (`-b -t 4`, jeden proces naraz, `--fast` przy iteracji), „styl retro, nie jakość retro”, stała gęstość tekseli, każdy podgląd Cycles obejrzany przed commitem, Godot tylko `--headless`, bez okien i bez dźwięku. Wspólne rejestry (`ALL`, `ArtLibrary.KIT/REGISTRY/EXTRAS/EXHIBIT_RIM`, `ArtKit.ROOMS`, `TILES`, budżety w testach) tylko dopisujemy. **Szacunek dla kultur:** stylizacja muzealna, żadnych replik obiektów sakralnych (bez kopii Kamienia Słońca, Hoa Hakananai'a, konkretnych masek czy słupów), bez czaszek i motywów ofiarnych.

## Kierunek artystyczny
- **Paleta:** ciemnoczerwone ściany (polerowany tynk wapienny barwiony czerwienią), szarobrązowy kamień wulkaniczny rzeźbionych fryzów i tarasów, czerń obsydianu i bazaltu, turkus mozaik jako akcent; Pacyfik: ciemne drewno, plecionki, tapa w brązach i czerni; ogień jako główne światło.
- **Motywy (wymyślone, nie kopiowane):** schodkowy meander (xicalcoliuhqui), rzędy paciorków, kartusze z abstrakcyjnymi znakami (kółka, kreski i kropki, spirale), wężowe zwoje, piórowe obrzeża; na Pacyfiku: trójkąty, zygzaki, kratki, gwiazdki tapy.
- **Światło (dla integratora):** teatralne, z dołu i z ognia: misy ogniowe (`Light`), reflektory przy podłogach, jeden snop księżyca na ołtarz Świątyni.

## Gęstości tekseli
pola kafelkowe i architektura 64 px/m · rzeźbione elementy świątyni 96 · duże eksponaty (Kamień Słońca, moai, totemy, czółno) 96–128 · rekwizyty i gabloty 128–192 · maski, figurki, mozaika węża 256 · Totem (wróg) 192 · Wojownik-jaguar 256 · Dwugłowy Wąż (strażnik, ~14 m) 112.

## Zadania

### A0. Wspólna biblioteka `tools/art/artlib/americas.py` + `americas_paint.py`
- [x] Rampy palety z przedrostkiem `am_` (czerwony tynk, bazalt, andezyt, stiuk, turkus, muszla, spondylus, obsydian, jadeit, ochra, glina, włókno, tapa, drewno Pacyfiku, pióra, lina, ogień).
- [x] Malarz motywów na płótnach kodów (piksel = teksel): meander schodkowy, paciorki, kartusze ze znakami, quincunx, piórowe obrzeża, wzory tapy, splot maty.
- [x] Funkcje materiałów: tynk czerwony, kamień rzeźbiony (relief z płótna + resztki farby), bazalt pęcherzykowy, mozaika (tessery z komórek, ciemna żywica w fugach, połysk), obsydian, drewno rzeźbione (ślady ciosła), glina wypalana i polerowana, pióra, splot maty, tapa, lina, żar i płomień.

### A1. Tekstury kafelkowe (64 px/m, `build_textures.py`)
- [x] `am_red_wall` (ciemnoczerwony tynk), `am_frieze` 8 × 1 (rzeźbiony fryz z meandrami i kartuszami), `am_stone_blocks` (ciosy tarasów ze stiukiem), `basalt_americas` (polerowane płyty bazaltu), `am_woven_mat` (mata z pandanu), `boards_pacific` (ciemne deski), `am_tapa` (tapa na strop Pacyfiku), `am_ceiling` (okopcone belki). Sprawdzenie szwów (`view_texture.py`).

### A2. Zestaw architektury — commit
- [x] Pasy ścian Meksyku: `americas_dado_*` (bazaltowy cokół z turkusowym meandrem), `americas_frieze_*` (lico 1 m = pole `am_frieze`), `americas_cornice_*` (schodkowy gzyms), moduły 4 / 2 / 1 / 0,5 m.
- [x] Pacyfik: `pacific_dado_*` (panele plecionki w drewnianej ramie), `pacific_beam_*` (malowane krokwie), `pacific_post` (rzeźbiony słup ścienny).
- [x] Świątynia: `temple_tier_4m/2m/1m` (lico tarasu 1,5 m: talud + tablero), `temple_tier_corner`, `temple_stair` (bieg 3 m, 1,5 / 4 m, balustrady z głowami węży u stóp), `temple_shrine` (dom ołtarza), `temple_altar`.
- [x] Oprawy: `americas_brazier` (misa ogniowa 0,8 × 1,0, `Light`), `americas_torch_lamp` (ścienna misa, `Light`), portal `americas_portal_4m`.

### A3. Eksponaty Meksyku — commit
- [x] `mask_case` (gablota z trzema maskami mozaikowymi, szyba osobno) + `turquoise_mask`, `serpent_mosaic` (dwugłowy wąż z mozaiki na stojaku), `sun_stone` (rzeźbiony dysk ~3,6 m, stylizacja), `clay_figures` (figurki z gliny na podeście), `feather_case` (tarcza i wachlarz z piór).

### A4. Rapa Nui i Pacyfik — commit
- [x] `moai` (~2,5 m, bazalt; części `moai_plinth` i `moai`, oś obrotu na cokole, żelazne ucho i znacznik `hook_ring`).
- [x] `war_canoe` (~12 m, rzeźbiony dziób, pływak z wysięgnikami; liny jako części, znaczniki `hook_ring`, oś do wychylenia w most).
- [x] Ekspozycja wielorybnicza: `whaling_rack` (stojak z harpunami, `weapon_spot`), `harpoon_stand` (stojak na harpunnik, `weapon_spot`); `tapa_hanging` (+ zestawy tekstur), `pacific_figures` (gablota z rzeźbami).

### A5. Sala Totemów — commit
- [x] Słupy dekoracyjne inne niż Haida z dziedzińca: `totem_pole_house` (słup frontowy z owalnym przejściem), `totem_pole_memorial` (gładki trzon z jedną figurą), `totem_pole_welcome` (postać powitalna), `totem_log` (nieskończony słup w warsztacie).

### A6. Wrogowie i strażnik — commit po każdym
- [x] `totem` (wróg): 5 twarzy jako osobne części ułożone w łańcuch (`face_1..5` od dołu, osie u podstaw), oczy `eyes_1..5` (zapowiedź), znaczniki `face_<n>`, `mouth_<n>`, czapa `cap`; malowane drewno.
- [x] `jaguar` (Wojownik-jaguar ~1,8 m): drewno i turkus, hełm-paszcza jaguara, maczuga z obsydianowymi zębami, rig do skradania, sprintu i skoku; znacznik `face`.
- [x] `serpent` (Dwugłowy Wąż ~14 m): 14 segmentów `segment_1..14` w łańcuchu, skorupy mozaiki `tiles_1..14`, głowy `head_a` / `head_b` z żuchwami, znaczniki `seg_<n>`, `head_a`, `head_b`, `mouth_a`, `mouth_b`.

### A7. Rejestracja, testy, katalog — commit
- [x] `ArtLibrary`: KIT + `KIT_AMERICAS` (rozmiar natywny, budżet), REGISTRY (moai, czółno, wielorybnicy, wrogowie, strażnik), EXTRAS (emisja), EXHIBIT_RIM; `ArtKit`: style `americas_*` (pola i pasy) i skalowanie elementów po id modelu — tylko dopisane wpisy.
- [x] Test `tests/integration/test_art_americas.gd` (rozmiary, budżety, łańcuchy, osie, znaczniki) + linijka budżetu w `test_art_kit.gd`.
- [x] Ujęcia poglądowe z Blendera (`tools/art/americas_vignette.py`): Świątynia z Wężem, Sala Moai, Galeria Pacyfiku z czółnem, Sala Totemów.
- [x] Katalog `docs/art/kit-pietro1-ameryki.md`: id, rozmiary, osie, znaczniki, rozmieszczenie, trójkąty, podglądy, rigi i pozy.
- [x] `git merge pietro-1`, rejestry jako suma, `bash tools/run_tests.sh` zielone.

## Stan (3.10)
Wszystkie zadania zrobione; liczby, osie, znaczniki, pozy i ujęcia w `docs/art/kit-pietro1-ameryki.md`. Wspólne narzędzia, które powstały po drodze: `artlib/clay.py` (zaokrąglone bryły metaballi i `into_part` odporne na przetasowanie ścian po fazowaniu — w `sculpt.into_part` nowe ściany nie zawsze są na końcu listy, co po `box(bevel=…)` dawało złe materiały), `artlib/serpent_head.py` (jedna głowa węża dla schodów, mozaiki i strażnika). Do uzgodnienia z greyboxem: skala czółna (12 m) i moai (2,45 m).
