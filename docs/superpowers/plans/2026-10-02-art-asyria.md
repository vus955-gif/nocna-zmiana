# Grafika skrzydła Asyrii — pałace Niniwy i Nimrud (Piętro I)

> Plan wykonawczy artysty 3D skrzydła Asyrii. Projekt nadrzędny: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` (§2, **§5.2**, §7.3, **§7.4 — Lamassu**, **§10.1–10.2**). Przewodnik stylu: `docs/art/styl-przewodnik.html` („styl retro, nie jakość retro”). Gałąź `art-assyria` w drzewie `.claude/worktrees/art-assyria`; poza tym drzewem nic nie czytam i nie zapisuję.

**Cel:** komplet modeli i tekstur skrzydła, z którego budowniczy strefy `assyria` (x −112…−64, z −86…−4) ubierze sale bez dodatkowej pracy graficznej:

- **zestaw pałacowy** (płyty z płaskorzeźbami w wielu tematach, fryz, cedrowe belki, krenelaż, portale, progi, pochodnie, wrota z Balawat, regały z tabliczkami, cokoły) + tekstury kafelkowe 64 px/m,
- **Brama Chorsabadu**: para lamassu 4,5 m, portal z łukiem z glazurowanej cegły i kamienne wrota pieczęci z gniazdem tarczy słonecznej,
- **Lamassu** — strażnik z rigiem pozy (nogi w trzech stawach, skrzydła w dwóch częściach, głowa z koroną, ogon, znaczniki trafień i kopyt),
- **Wojownik z reliefu** i **Lew z reliefu** — płaskie wrogi z rigiem z płaskich części, **odłamki gipsu**,
- wpisy w `ArtLibrary` (tylko dopisywanie) i katalog `docs/art/kit-pietro1-asyria.md`.

## Konwencje

- Wszystko skryptami: `tools/art/models/<nazwa>.py` (jeden moduł = rodzina modeli), wspólny kod w `tools/art/artlib/`. Nowe nazwy **dopisywane na końcu** `ALL` w `tools/art/build_models.py`, tekstury kafelkowe na końcu `TILES` w `tools/art/build_textures.py`.
- Blender 5.1 zawsze `-b`; budowanie `bash tools/art/build_art.sh <nazwy>` (`FAST=1` przy szybkich próbach). Podglądy Cycles: `tests/_out/art/<nazwa>.png` — **każdy oglądam** i poprawiam do skutku. Rendery w rozsądnym rozmiarze (inni artyści renderują równolegle).
- Godot tylko bez okna (`--headless`), bez dźwięku. Na koniec `bash tools/run_tests.sh` musi być zielony.
- Rejestry wspólne (`ALL`, `TILES`, `ArtLibrary.KIT`, `KIT_SETS`, `REGISTRY`, `EXTRAS`, `EXHIBIT_RIM`): **tylko dopisywanie**. Identyfikatory zestawu mają przedrostek `asy_` (brak kolizji z innymi skrzydłami); bohaterowie i wrogowie: `khorsabad_gate`, `lamassu`, `relief_warrior`, `relief_lion`.
- Commit po każdej rodzinie modeli; stopka `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Dodaję tylko własne pliki (nigdy `git add -A`, nigdy `tools/godot`).

### Gęstość tekseli (przewodnik)

| Klasa | px/m | Co |
|---|---|---|
| architektura | 64 | tekstury kafelkowe, belki, krenelaż, fryz, portale, brama (mur) |
| płyty z reliefem | 128 | reliefy oglądane z 1–3 m: postać 1,9 m = 243 teksele, oko 4–5 tekseli |
| meble / rekwizyty | 128–160 | wrota z Balawat, regały, tabliczki, pochodnie, cokoły |
| posągi bramy, strażnik | ~96–112 | jak boss (T-Rex 112): oglądane z 3–15 m |
| wrogowie | 256 | wojownik i lew z reliefu (gracz walczy z 1–5 m) |

### Paleta skrzydła (§10.1: szary alabaster, brąz, cedr; niskie, ostre światło, pochodnie)

Nowe rampy w słowniku `P` (kroki po rampie, jak w całym projekcie): `alabaster` (szaroniebieski gips z Mosulu), `alabaster_warm` (zażółcenia, patyna), `paint_black` (ślady czarnej farby na włosach i brodach), `ochre_red` (ślady czerwieni), `lapis` i `glaze_yellow` / `glaze_white` (glazurowana cegła, ślady błękitu), `cedar`, `mudbrick`, `brick_baked`, `bitumen`, `clay` (tabliczki), `flame` (płomień pochodni, emisja).

## Architektura rozwiązania

```
artlib/asy_relief.py płótno płaskorzeźby 2D w metrach (u w prawo, v w górę): kształty SDF
                     (elipsy, wielokąty, kapsuły kończyn, krzywe), warstwy z wysokością i
                     zaokrągloną krawędzią, części (osobna mapa na część rigu), nacięcia,
                     loki, pióra, frędzle, pismo klinowe; cieniowanie pikselowe; śledzenie
                     konturu maski -> wielokąt (wyciąganie płaskich części w 3D)
artlib/asy.py        rampy, materiały (alabaster, gips łamany, cedr, cegła, glazura, glina,
                     płomień), tekstury kafelkowe skrzydła, pomocnicze bryły (loft przekrojów)
artlib/asy_figures.py  biblioteka postaci: wojownik, łucznik, geniusz ze skrzydłami (szyszka
                     i wiaderko), król, koń, rydwan, lew (biegnący, skaczący, ranny), lwica,
                     święte drzewo, pasy pisma; kompozycje płyt
models/kit_asy_*.py  rodziny zestawu (reliefy, architektura, rekwizyty)
models/khorsabad_gate.py, lamassu.py, relief_warrior.py, relief_lion.py, asy_chips.py
```

Relief jest projektowany **raz** jako rysunek 2D z wysokością. Z tego samego rysunku powstają: (1) tekstura płyty (albedo + normalna z wysokości + ORM) wypiekana na siatkę płyty, (2) zarysy płaskich części wroga (kontur maski części → wielokąt → bryła o grubości 0,18 m), (3) postać wtopiona w płytę „przebudzenia”, w tym samym miejscu i skali co wróg — przejście ściana → wróg jest bez skoku.

## Zadania

### Z1. Podstawy: rampy, materiały, płótno reliefu, podgląd 2D
- `artlib/asy_relief.py`, `artlib/asy.py`; szybki podgląd 2D reliefu oświetlonego nisko z boku (bez Blendera, sekundy na iterację) do `tests/_out/art/asy_relief_*_2d.png`.
- Pismo klinowe: znaki z klinów poziomych, pionowych, ukośnych i haczyków, linie z liniaturą.
- **Odbiór:** podgląd 2D wojownika czytelny w 128 i 256 px/m.

### Z2. Tekstury kafelkowe skrzydła (64 px/m)
`asy_alabaster` (płyty ortostatów 4 × 3 m), `asy_plaster` (tynk górnych ścian), `asy_mudbrick` (cegła suszona: dziedziniec, magazyn tabliczek), `asy_floor_gypsum` (posadzka z płyt gipsowych), `asy_floor_brick` (cegła palona z pieczęciami i bitumicznymi spoinami: dziedziniec), `asy_cedar` (strop z desek cedrowych). Wszystkie na siatce 0,5 m.
- **Odbiór:** arkusz `textures_sheet.png` bez szwów, rytm spoin zgodny z siatką świata.

### Z3. Płyty z reliefami (rodzina `kit_asy_reliefs`)
- `asy_relief_2m` (2 × 3 m, ścienna, płaszczyzna ściany z = 0) z zestawami tekstur: geniusz ze szyszką i wiaderkiem (pas Standardowej Inskrypcji w poprzek), wojownicy w marszu (dwa rejestry + pas pisma), rydwan, polowanie na lwy, lwy, święte drzewo, sama inskrypcja, płyta gładka.
- `asy_relief_1m` (1 × 3 m): włócznik, inskrypcja.
- `asy_relief_wake` (wojownik) i `asy_relief_wake_lion` (lew): płyta-bohater z prawdziwą geometrią — postać jako osobna część `figure` we wnęce w kształcie postaci; pęknięcia wokół zarysu w mapie emisji (spoczynkowo 0, zapowiedź = podniesienie emisji); po wyjściu wroga zostaje pusta wnęka.
- **Odbiór:** podglądy z bliska i pod kątem; tematy czytelne z 3 m; ≤ 1200 trójkątów na płytę.

### Z4. Architektura i rekwizyty pałacu
- `asy_frieze_4m/2m/1m` (malowany fryz nad ortostatami: rozety, palmety, klęczące byki), `asy_beam_4m` (belka cedrowa z brązowymi okuciami), `asy_parapet_2m` (schodkowe merlony), `asy_portal_4m` i `asy_portal_2m` (ościeża z alabastru z geniuszami na węgarach, nadproże z rozetami), `asy_threshold_4m` (próg z kamiennym „dywanem”), `asy_torch` (pochodnia ścienna, znacznik `Light`), `asy_brazier` (trójnóg z misą ognia), `asy_balawat_gate` (dwa skrzydła cedrowe z brązowymi pasami na słupach-zawiasach: części `leaf_l`, `leaf_r`), `asy_tablet_shelf` (regał magazynu z tabliczkami), `asy_tablet_crate`, `asy_prism` (sześciokątny graniastosłup z pismem na stojaku), `asy_plinth` i `asy_plinth_low`.
- **Odbiór:** budżety ≤ 1200 trójkątów (zestaw), osie i fronty wg konwencji zestawu (`ArtKit`).

### Z5. Brama Chorsabadu (`khorsabad_gate`, bohater)
- Dwa lamassu 4,5 m (pięć nóg, jak w oryginałach; bok w wysokim reliefie na tle bloku, przód w pełnej rzeźbie), mur ościeży, łuk z glazurowanej cegły, krenelaż; kamienne skrzydła `door_l`, `door_r` (osie na zawiasach) z rozetowym „dywanem” i połówkami gniazda tarczy słonecznej, znacznik `seal_socket`; znaczniki `Light_l`, `Light_r` (pochodnie).
- **Odbiór:** sylwetka czytelna z 20 m (z Sali Kolosa), wrota wyraźnie zamknięte pieczęcią.

### Z6. Lamassu — strażnik (`lamassu`)
- ~4 m do szczytu korony; części: `body`, `head`, `headdress`, `wing_l`/`wing_l_tip`, `wing_r`/`wing_r_tip`, `tail`, nogi `thigh_*` → `shin_*` → `hoof_*` (fl, fr, bl, br); znaczniki `face`, `crown`, `contact_*`. Kamień ze śladami farby, brązowe akcenty (opaski, kolczyki, rozety). Zestaw tekstur `lamassu_cracked` (pęknięcia z żarem: fazy 2–3).
- **Odbiór:** podgląd z czterech stron + zbliżenie twarzy; skrzydła rozkładalne bez przenikania; ≤ ~16 000 trójkątów.

### Z7. Wrogowie z reliefu
- `relief_warrior` (1,9 m, 0,18 m): `torso`, `head`, `arm_front`, `arm_back`, `shield`, `spear`, `leg_front`, `leg_back`; znacznik `eye` na licu. Tył: świeży przełom gipsu.
- `relief_lion` (~1 m wysokości): części jak u wilka (`body`, `head`, `jaw`, `leg_fl/fr/bl/br`, `tail`) + znacznik `eye`; osie nóg w płaszczyźnie płyty.
- `asy_gypsum_chips`: 8 odłamków gipsu do fizyki.
- **Odbiór:** zgodność zarysów z postaciami na płytach przebudzenia; budżety ≤ 4000 / 3000.

### Z8. Rejestracja, test, katalog
- `ArtLibrary`: dopisane `KIT`, `KIT_SETS`, `REGISTRY`, `EXTRAS` (emisja pochodni, płyt przebudzenia), `EXHIBIT_RIM`.
- Test `tests/integration/test_art_assyria.gd`: części, osie, znaczniki, rozmiary, budżety, zestawy tekstur.
- Katalog `docs/art/kit-pietro1-asyria.md`: identyfikatory, rozmiary, osie, znaczniki, rozmieszczenie, trójkąty, podglądy, opisy rigów.
- Scena poglądowa skrzydła (Blender, Cycles): kilka sal z płyt, belek, pochodni i lamassu w niskim świetle — zrzuty do katalogu.
- **Odbiór:** `bash tools/run_tests.sh` zielony.

## Ryzyka

| Ryzyko | Odpowiedź |
|---|---|
| Rysunki reliefów kodem wyglądają „programistycznie” | podgląd 2D w sekundach, iteracje do skutku; konwencje asyryjskie (oko en face na profilu, broda w lokach, mięśnie łydek jako ornament) |
| Pismo klinowe przy 128 px/m to szum | kliny jako piksele (główka 2×2 + ogon), linie ≥ 7 cm, liniatura |
| Budżet 1200 trójkątów dla płyt z geometrią | zarysy upraszczane (RDP), brak fazek na cienkich częściach |
| Długie wypieki AO | `ao_stride` 2–3 na dużych bryłach, FAST przy iteracjach kształtu |

## Stan (3.10)

Zrobione Z1–Z8. Odstępstwa od planu, z powodami:
- **Brama Chorsabadu w `ArtLibrary.KIT`** (nie w `REGISTRY`): mur wież to pole `tile:asy_alabaster` (atlas statuy nie musi nieść 200 m² muru); budżet 26 000 trójkątów dopisany do `test_art_kit.gd`. Posągi stoją w szerokości otworu 6 m (osie ∓2,25), bo hala ma tylko 1 m muru na wschód od otworu.
- **Drzwi pieczęci w bramie są opcjonalne**: Egipt (`egypt_seal_door_*`) zamyka już to samo przejście od swojej strony; części `door_l`/`door_r` można ukryć.
- **Wrota z Balawat = brama Pieczęci Skrzydła** (`j_assyria_americas`, 4 × 5 m): dwa skrzydła w ramie drzwi zamiast osobnego eksponatu.
- **Tematy płyt** nazwane `asy_relief_<temat>_2m/_1m`, żeby pasował mechanizm `set` pasów ArtKit; posadzki `flagstone_asy` i `tiles_asy_brick` (pierwsze słowo = materiał kroków w `Surface`).
- Rampy z przedrostkiem `asy_` (kolizje `cedar`, `flame`, `lapis` z Egiptem).
