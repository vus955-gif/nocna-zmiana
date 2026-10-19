# Czytelne pickupy — język koloru i sylwetki amunicji, apteczki i przedmiotów

> Plan wykonawczy. Wykonawca: jeden agent w worktree `close-wings` (gałąź `ammo-pickups` od `pietro-1`).
> Źródło: backlog właściciela `docs/backlog-pietro1.md` — #11 („kiepskie rozróżnienie wizualne amunicji do różnych broni"), #43 („pickupy czytelne z daleka, charakterystyczny silhouette/color language, bez podchodzenia na 30 cm"), #54 („nie przesadzić z zasobami" — **ilości bez zmian**), #42 (HUD jako element jednego projektu).
> **Bez okien i bez dźwięku** (właściciel pracuje przy komputerze): tylko `--headless`, `blender -b --no-preview` (bez renderów Cycles), skrypty. Nic nie trafia na GitHub.

**Cel:** każdy rodzaj łupu rozpoznawalny z 10–15 m po **kolorze** (zgodnym ze slotem broni w HUD), po **sylwetce** (dla daltonistów) i po **cyfrze slotu** na przedmiocie z bliska; apteczka wyraźnie inna od amunicji; wszystko czytelne w trzech temperaturach światła muzeum (zimny księżyc, ciepłe lampy, czerwone awaryjne) bez wyglądu arcade'owych power-upów („retro style, not retro quality").

**Architektura:** jedno źródło prawdy — `WeaponPalette` (`src/weapons/weapon_palette.gd`): kolor każdej broni, kolor i sylwetka każdej amunicji, cyfra slotu. Z niej czerpią: `Pickup` (greybox), `ArtLibrary` (kolor rimu i energia emisji na materiałach pickupów), `Hud` (podświetlenie cyfry slotu broni w ręce). Modele Blendera czytają ten sam zestaw z `tools/art/models/_pickup_palette.py` (hex + cyfra); test jednostkowy sprawdza, że oba pliki są zgodne, a wypalone mapy emisji mają odcień palety.

---

## 1. Inwentarz (stan przed zmianą)

| Rodzaj | Klasa / spawn | Model (Blender) | Dziś | Problem |
|---|---|---|---|---|
| naboje do pistoletu (`bullets`, slot 2) | `Pickup.Type.BULLETS`; `Museum._place_loot` (punkty łupu `level.loot_spots`, 60 % co noc), `NightObjective` / `GuardianKeeper` (zaopatrzenie walk), dev-sceny | `ammo_pistol.py` — zielono-kremowe pudełko z czerwonym paskiem, 0,26 × 0,16 | zielone pudełko | identyczne z pudełkiem sztucera (też zielony karton, mosiężne czubki) |
| śrut (`shells`, slot 3) | j.w. | `ammo_shells.py` — czerwone pudełko, łuski w poprzek | czerwone pudełko | ta sama bryła co pistolet |
| taśma kartaczownicy (`rifle`, slot 4) | j.w. | `ammo_rifle.py` — oliwkowa skrzynka z taśmą | oliwkowy | zieleń jak sztucer |
| race (`flares`, slot 5) | j.w. | `ammo_flares.py` — pomarańczowe pudełko, 4 czerwone race | pomarańcz/czerwień | czerwień jak śrut i strzały |
| naboje sztucera (`hunt_rounds`, slot 6) | j.w. | `ammo_rifle_hunt.py` — zielony karton, łódka nabojowa | zielony | jak pistolet |
| harpuny (`harpoons`, slot 7) | j.w. | `ammo_harpoon.py` — dwa harpuny leżące, zwój liny | szaro-czarny | bez koloru |
| ogniste strzały (`rockets`, slot 8) | j.w. | `ammo_hwacha.py` — snop 6 strzał leżący, czerwony jedwab | czerwony | czerwień jak śrut; leżący snop ≈ leżące harpuny |
| apteczka (`medkit`) | j.w. | `medkit.py` — biała puszka, czerwony krzyż | biały | OK, ale bez własnego rimu (wspólny ciepły) |
| paralizator (slot 1) | bateria ładuje się sama — **brak pickupu** | — | — | tylko kolor w HUD |
| bezpieczniki, pieczęcie, odłamki, szachy | `ProgressPickup` (własna lampka w kolorze rodzaju) | `fuse` / kod | złoty, czerwony, kremowy | poza zakresem (mają już swój język) |
| artefakty | `ArtifactPickup` (lampka `ArtifactCatalog.color`) | kod | wg katalogu | poza zakresem |
| bronie | `WeaponPickup` (viewmodel ×2,4, ciepła lampka) | `vm_*` | — | poza zakresem |
| Pył | `DustMote` | kod | złoty | poza zakresem |

Wspólny mechanizm dziś: shader eksponatów (`exhibit.gdshaderinc`) z rimem **jednego** ciepłego koloru (`ArtLibrary.PICKUP_RIM_COLOR`), `rim_fade` 0,8–4 m (pełny od 4 m), `emit_energy` domyślnie 2,0 (pickupy nie mają map emisji). `Pickup` obraca model (1,5 rad/s) i kołysze (±0,08 m). Punkty łupu: `LootSpot` w pokojach, model 0,35 m nad punktem.

## 2. Język (decyzje)

### 2.1 Kolor = slot broni (HUD) = rim i akcent emisyjny pickupu

| Slot | Broń | Amunicja | Kolor (sRGB) | Hex | Odcień | Uzasadnienie |
|---|---|---|---|---|---|---|
| 1 | paralizator | — (bateria) | elektryczny błękit (0,40, 0,80, 1,00) | `#66ccff` | 200° | kolor paska baterii w HUD; tylko w HUD |
| 2 | pistolet | `bullets` | stalowy błękit (0,30, 0,45, 1,00) | `#4d73ff` | 227° | oksydowana stal pistoletu; przedwojenne niebieskie pudełka nabojów |
| 3 | dwururka | `shells` | czerwień (0,92, 0,12, 0,10) | `#eb1f1a` | 1° | czerwone łuski |
| 4 | kartaczownica | `rifle` | oliwkowa żółtozieleń (0,72, 0,85, 0,25) | `#b8d940` | 73° | wojskowa skrzynka, szablon farbą; mosiądz taśmy |
| 5 | rakietnica | `flares` | pomarańcz sygnałowy + białe pasy (1,00, 0,42, 0,05) | `#ff6b0d` | 23° | pomarańczowa rakietnica; wzór sygnałowy |
| 6 | sztucer | `hunt_rounds` | zieleń myśliwska (0,20, 0,72, 0,36) | `#33b85c` | 138° | safari, zielony karton |
| 7 | harpunnik | `harpoons` | morski turkus (0,20, 0,78, 0,85) | `#33c7d9` | 186° | morze, znaki własnościowe wielorybników malowane na harpunach |
| 8 | ognista skrzynia | `rockets` | fiolet jedwabiu (0,68, 0,36, 0,95) | `#ad5cf2` | 272° | fioletowo barwiony papier i jedwab wiązania (jedyny wolny odcień) |
| — | apteczka | HP | biel emalii (1,00, 0,96, 0,90) | `#fff5e6` | — | biała puszka, czerwony krzyż; **jedyny biały rim** |

Najmniejszy odstęp odcieni między amunicjami: 22° (czerwień–pomarańcz) — te dwie dzieli dodatkowo wzór (białe pasy rac) i bryła. Pozostałe ≥ 41°. Pod czerwonym światłem awaryjnym odcienie zlewają się — czytelność niosą wtedy: **rim i akcent emisyjny w kolorze palety** (samoświecące, niezależne od światła), bryła, cyfra.

### 2.2 Sylwetka (dla daltonistów; czytelna przy ~30 px na ekranie)

| Amunicja | Id sylwetki | Bryła |
|---|---|---|
| `bullets` | `box_brick` | **małe, wysokie** pudełko-klocek 0,20 × 0,15 × 0,11 z otwartą klapą, rzędy mosiądzu |
| `shells` | `box_flat` | **szerokie, niskie** pudło 0,26 × 0,16 × 0,09, dwie łuski w poprzek |
| `rifle` | `crate_belt` | **największa** drewniana skrzynka 0,26 × 0,15 × 0,12 z taśmą zwisającą z boku i sznurowymi uchwytami |
| `flares` | `tubes_upright` | 4 grube tuby stojące w płaskim pudełku (0,19 szer., 0,17 wys.) |
| `hunt_rounds` | `box_clip` | **małe, płaskie** pudełko 0,18 × 0,056 × 0,07 + leżąca łódka nabojowa |
| `harpoons` | `bundle_flat` | **długa, leżąca** wiązka 0,45 m z wielkimi grotami, klocek pod spodem, zwój liny |
| `rockets` | `sheaf_upright` | **wysoki, stojący** snop 0,4 m (groty do góry, lotki na dole) — jedyny pionowy pickup |
| apteczka | `tin_handle` | biała puszka 0,30 × 0,22 z uchwytem na górze (jedyny pickup z łukiem) |

### 2.3 Akcenty w ciemności (bez power-upów)

- **Rim w kolorze rodzaju**: `ArtLibrary.PICKUP_RIM_COLORS[model]` zamiast wspólnego ciepłego; siła 1,0 dla amunicji, 0,9 apteczka; bezpiecznik i kryształ zostają ciepłe. Rim działa od 0,8 do 4 m w górę — to główny sygnał na 10–15 m (kolorowy kontur).
- **Wypalona mapa emisji** (`_emit.png`, nowość dla pickupów): zadrukowane pola kartonu / farba szablonu świecą słabo **własnym kolorem** (0,25–0,3 × albedo), cyfra slotu i białe pasy mocniej (0,5). `ArtLibrary.EXTRAS[model]["emission"] = 1.0` (shader: ×1,2 dla `awake=1`) — łącznie ≤ 0,6 wartości koloru: „widoczne w ciemności", nie „lampa". Limit sprawdzany testem (≤ 1,2 energii; w shaderze maks. 4× tylko dla nozzle rakiety).
- **Ruch**: obrót i kołysanie bez zmian (już są).
- **Cyfra slotu** na przedmiocie (pixelfont, bold, skala 2 → ~4–5 cm): pudełka — na obu końcach i na klapie; wiązki (harpuny, strzały) — **muzealna tabliczka inwentarzowa** (karton z mosiężnym oczkiem) z cyfrą zawieszona na wiązaniu. Cyfra = indeks slotu `WeaponHolder.SLOT_ORDER` + 1. Czytelna z 2–4 m jako potwierdzenie (daltonizm), nie z 15 m.
- **HUD**: cyfra slotu broni **w ręce** w kolorze palety broni (zamiast ogólnego `UiTheme.ACCENT`); posiadane i puste bez zmian (bez „tęczy"). Pasek baterii paralizatora już ma kolor slotu 1.

### 2.4 Bez zmian

Ilości (`Museum.LOOT_AMOUNTS`), wagi losowania, zamiana amunicji nieznanej broni na znaną, zasięgi kolizji, `ProgressPickup`/`ArtifactPickup`/`WeaponPickup`/Pył.

## 3. Pliki

| Plik | Zmiana |
|---|---|
| `src/weapons/weapon_palette.gd` | **nowy**: `WeaponPalette` — `COLORS` (broń → kolor), `AMMO` (amunicja → broń), `SILHOUETTES`, `MEDKIT_COLOR`, `MEDKIT_SILHOUETTE`, `color(weapon)`, `ammo_color(ammo)`, `slot(weapon)`, `digit(ammo)`, `hue_gap()` |
| `src/arena/pickup.gd` | `color_of(type)`, `silhouette_of(type)`, greybox w kolorach palety |
| `src/style/art_library.gd` | `PICKUP_RIM_COLORS`, siła rimu 1,0 dla amunicji, `EXTRAS` emisja 1,0 dla 8 pickupów, `pickup_rim_color()` |
| `src/ui/hud.gd` | `_update_slots`: slot w ręce w kolorze `WeaponPalette.color(id)`; `slots_text` po indeksie |
| `src/fx/shader_warm_up.gd` | `LATER_PICKUPS` + `ammo_rifle_hunt`, `ammo_harpoon`, `ammo_hwacha` (dopisane na końcu) |
| `tools/art/models/_pickup_palette.py` | **nowy**: hex + cyfra per model, `ramp(hex)` (7-stopniowa rampa pikselowa), `rgb(hex)` |
| `tools/art/models/ammo_pistol.py` | bryła-klocek 0,20 × 0,15 × 0,11, druk niebieski, kremowa etykieta, cyfra „2", emisja |
| `tools/art/models/ammo_shells.py` | cyfra „3" na końcach i klapie, emisja czerwieni |
| `tools/art/models/ammo_rifle.py` | szablon „NABOJE" i cyfra „4" żółtozieloną farbą, emisja |
| `tools/art/models/ammo_flares.py` | tuby pomarańczowo-białe (2 białe pasy), cyfra „5", emisja |
| `tools/art/models/ammo_rifle_hunt.py` | rampa kartonu → zieleń myśliwska, cyfra „6" na klapie i końcach, emisja |
| `tools/art/models/ammo_harpoon.py` | turkusowe pasy farby na trzonach (znaki własnościowe), tabliczka „7", ppm 320, emisja |
| `tools/art/models/ammo_hwacha.py` | snop **stojący** (groty do góry), papier i jedwab fioletowe, tabliczka „8", emisja |
| `tools/art/models/medkit.py` | emisja krzyża (słaba) i emalii (bardzo słaba) |
| `assets/models/*.glb`, `assets/textures/*` | przebudowane (8 modeli; `_emit.png` nowe) |
| `tests/unit/test_weapon_palette.gd` | **nowy**: unikalność kolorów (odstęp odcieni ≥ 20°) i sylwetek, zgodność z HUD, cyfry = sloty, apteczka daleko od amunicji, rimy i limity emisji w `ArtLibrary`, zgodność z `_pickup_palette.py`, odcień wypalonych map emisji |
| `tests/integration/test_pickup.gd` | każdy typ nosi model z rimem swojego koloru i emisją w limicie |
| `tests/integration/test_hud.gd` | slot w ręce ma kolor palety |
| `tests/integration/test_art_stage3_game.gd` | asercja rimu → kolor rodzaju |

## 4. Zadania

- [x] **0. Plan** (ten dokument).
- [x] **1. Paleta w grze (TDD)**: `test_weapon_palette.gd` → `WeaponPalette`, `Pickup.color_of/silhouette_of`, `ArtLibrary.pickup_rim_color()` (`PICKUP_AMMO`) + `EXTRAS`, HUD, warm-up; testy integracyjne (pickup, hud, stage3). Commit `5d5f0e9`.
- [x] **2. Modele (Blender headless, jeden proces, `--no-preview`)**: `_pickup_palette.py`, 8 skryptów, `build_models.py -- ammo_* medkit --no-preview` (~40 s łącznie), `import_settings.py`, import Godota; testy: zgodność z `_pickup_palette.py`, odcień wypalonych map emisji (≤ 25° od palety, szczyt < 0,75). Commit `2c68135`.
- [x] **3. Pełny zestaw testów, `git merge pietro-1`, raport.** Pełny zestaw: 2185/0 przed scaleniem, 2193/0 po `fix-viewmodel`, 2205/0 po `dress-east` (pietro-1 `d3cf3df`, scalenia bez konfliktów).

## 5. Do sprawdzenia w oknie (gdy właściciel pozwoli)

- [ ] Czytelność z **5 / 10 / 15 m** każdego z 8 pickupów (7 amunicji + apteczka) w trzech światłach: zimny księżyc (dziedziniec przy oknach), ciepłe lampy (galerie), **czerwone awaryjne** (po wyłączeniu obwodu / korytarze serwisowe). Kryterium: z 10 m rozpoznać rodzaj bez podchodzenia; z 15 m co najmniej „amunicja vs apteczka" i kolor.
- [ ] Rim w kolorze rodzaju: czy kontur nie „pływa" przy obrocie, czy fiolet strzał i turkus harpunów nie wyglądają jak power-upy (jeśli tak: `PICKUP_RIM` 1,0 → 0,8, emisja 1,0 → 0,7).
- [ ] Emisja: pudełka nie mają „blasku" — mają być **widoczne**, nie świecące (porównać z bezpiecznikiem, który ma własną lampkę).
- [ ] Cyfry slotów czytelne z 2–3 m (pixelfont skala 2 przy 256–320 px/m); tabliczki inwentarzowe harpunów i strzał nie przecinają geometrii przy obrocie.
- [ ] Stojący snop strzał: nie wchodzi w gablotę/sufit w niskich salach (0,4 m wysokości, model 0,35 m nad punktem) — sprawdzić punkty łupu w podziemiach i tunelach serwisowych.
- [ ] HUD: cyfra slotu w ręce w kolorze broni — czy nie gryzie się z bursztynowym akcentem reszty HUD; czy przejście taser (błękit) ↔ pistolet (stalowy błękit) jest zauważalne.
- [ ] Zrzuty porównawcze „przed/po" dla właściciela (scenariusz `art_lineup_runner` z 8 pickupami w rzędzie przy 5/10/15 m, trzy światła) — tylko gdy okna dozwolone.

## 6. Stan prac / co dalej

- 2026-10-10: zadania 0–3 wykonane na gałęzi `ammo-pickups` (worktree `close-wings`). Pełny zestaw zielony (2205/0) po scaleniu `pietro-1` (`d3cf3df`). Lista okienna (§5) czeka na zgodę właściciela — nic nie było oglądane w oknie, kolory i cyfry sprawdzono tylko na atlasach (`assets/textures/*_albedo.png`, `*_emit.png`) i testami.
- Gdyby wyniki okienne wymagały stonowania: `ArtLibrary.PICKUP_RIM` (1,0 → 0,8), `ArtLibrary.EXTRAS[...]["emission"]` (1,0 → 0,7), `_pickup_palette.PRINT` / `MARK` (0,3 / 0,5) — po zmianie palety w Pythonie przebudować modele (`build_models.py -- ammo_* medkit --no-preview`, ~40 s) i `import_settings.py`.
- Otwarte pytania dla właściciela: (a) fiolet dla strzał ognistej skrzyni — akceptowalny? alternatywa: złoto na czarnej lace (wtedy kartaczownica musi zostać oliwkowa, a odstęp złoto–pomarańcz spada do ~25°); (b) czy cyfra slotu na pudełkach nie jest zbyt „growa" — można zostawić tylko na tabliczkach.
