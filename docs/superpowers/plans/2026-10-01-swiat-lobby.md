# Świat lobby — sekrety, notatki, artefakty, CCTV

> Plan wykonawczy części „treść świata” etapu 2b-2. Projekt nadrzędny: `docs/superpowers/specs/2026-09-30-etap-2-projekt.md` (§4–§7, §10), `docs/Nocna-Zmiana-specyfikacja.md` (§5, §7.4), `docs/superpowers/specs/2026-10-01-rozbudowa-projekt.md` (§5 CCTV) oraz „Dla etapu 2b-2” w planie 2b-1. Równolegle integrator I1 wpina lobby w `Museum` (`src/game/museum.gd`, `src/level/*`, `src/enemies/*`, `src/game/night_*.gd`, `hud.gd`) — tych plików ten plan **nie edytuje**; potrzebne punkty zaczepienia są opisane niżej dla kontrolera.

**Cel:** komplet treści świata lobby jako samodzielne komponenty w `src/world/*`, instalowane jednym wywołaniem przez `Museum`:

```gdscript
LobbyFeatures.install(level: LobbyLevel, museum: Node) -> LobbyFeatures
```

- **6 sekretów** (obraz, szyb wentylacyjny, tabliczka, gablota na kłódkę, notatki ×3, składzik) z komunikatem „Sekret odkryty (n/6)”, dźwiękiem i zapisem w `GameState.secrets`,
- **notatki** (8 tekstów: 3 z zestawu, kartka Heńka o kluczu, 4 w miejscach sekretnych) z czytnikiem „na papierze”, zapis w `GameState.notes`,
- **szuflada kasy i szafka na broń** (klucz do szafki z pistoletem, `GameState.pistol_key`),
- **6 artefaktów** (§7.4) w pojemnikach wylosowanych przez `NightConfig`, z efektami i rzędem ikon na ekranie,
- **CCTV**: ściana monitorów z żywym obrazem z 6 kamer i pełnoekranowy podgląd z pulpitu.

## Konwencje

- Godot 4.7.2 (`tools/godot` = połączenie katalogów do wspólnej instalacji, poza gitem). Testy: `bash tools/run_tests.sh` (bez okna, ~40 s); przebieg nieudany przy porażce testu **albo** linii `ERROR`/wycieku.
- GDScript ze statycznym typowaniem, tabulatory, identyfikatory i komentarze po angielsku. Teksty dla gracza przez `tr()` z `locale/strings.csv` (`keys,pl,en`), z pełnym, porządnym angielskim.
- Okienkowe uruchomienia: `--windowed --audio-driver Dummy` (bez dźwięku).
- Jeden commit na zadanie, stopka `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` jako drugi `-m`; dodawane tylko własne pliki (nigdy `git add -A`, nigdy `tools/godot`).
- Dźwięki: nowe wpisy na końcu `SOUNDS` w `tools/sfx/gen_sfx.py` (ziarno = nazwa dźwięku, więc istniejące pliki WAV zostają bajt w bajt takie same).
- Układ współrzędnych jak w 2b-1: metry, Y w górę, −Z = północ; znaczniki `level.markers` mają początek na obiekcie/podłodze, −Z = front obiektu.

## Architektura

```
Museum (I1) ──► LobbyFeatures.install(level, museum)        src/world/lobby_features.gd
                  │  czyta: level.markers, level.doors, level.loot_spots, level.layout,
                  │         level.night (NightConfig; gdy brak — NightDirector.plan z GameState)
                  ├─ SecretSwitch ×n ─ fałszywe panele (Door.open) ─► discover_secret(id)
                  ├─ CrookedPlaque, PadlockedCase (Hurtbox + klucz woźnego)
                  ├─ NotePaper ×8 ──► NoteReader (CanvasLayer, pauza, stos GameInput)
                  ├─ TicketDrawer (klucz) ─► PistolLocker (pistolet = WeaponPickup)
                  ├─ ArtifactPickup ×(2–3) ─► RunState.artifacts ─► ArtifactEffects
                  ├─ LockedDoorLatch ─ drzwi zamknięte tej nocy + klucz woźnego
                  ├─ Cctv: CctvFeed ×6 (SubViewport + Camera3D + nakładka) → CctvWall,
                  │        CctvConsole (pulpit) → CctvView (pełny ekran)
                  └─ WorldHud (CanvasLayer): baner odkryć/znalezisk + rząd ikon artefaktów
```

Stan: **trwały** wyłącznie w `GameState` (`secrets`, `notes`, `havens`, `pistol_key`, `weapons`), **nocny** wyłącznie w `RunState` (`artifacts`, mnożnik Pyłu `&"coin"`). Odkrycie sekretu / klucza / notatki zapisuje grę od razu (`NightRules.save_progress`), tak jak podniesienie broni.

**Otwarte raz — otwarte na zawsze.** Sekret odkryty w poprzednich nocach jest przy instalacji od razu otwarty (panele `open(true)`, tabliczka prosto, kłódki nie ma), a jego przełącznik nie powstaje. Artefakty i ich pojemniki są co noc nowe (losuje `NightDirector`).

## Mapa plików

| Plik | Odpowiada za |
|---|---|
| `src/world/lobby_features.gd` | `LobbyFeatures`: punkt wejścia, składanie komponentów, odkrywanie sekretów, sygnały dla `Museum` |
| `src/world/lobby_secrets.gd` | `LobbySecrets`: lista 6 sekretów, liczenie, zapis w `GameState.secrets` (czysta logika) |
| `src/world/world_sounds.gd` | `WorldSounds`: nazwy dźwięków świata + odtwarzanie przez `Sfx` |
| `src/world/world_hud.gd` | `WorldHud`: baner („SEKRET ODKRYTY · 3/6”, artefakt, klucz) i rząd ikon artefaktów |
| `src/world/artifact_icon.gd` | `ArtifactIcon`: rysowana ikona artefaktu (kontrolka w rzędzie `WorldHud`) |
| `src/world/secret_switch.gd` | `SecretSwitch`: `Interactable` na licu fałszywego panelu |
| `src/world/crooked_plaque.gd` | `CrookedPlaque`: krzywa tabliczka w zbrojowni (sekret 3) |
| `src/world/padlocked_case.gd` | `PadlockedCase`: gablota na kłódkę (strzał albo klucz woźnego; sekret 4) |
| `src/world/note_catalog.gd` | `NoteCatalog`: notatki (klucze tekstów, rodzaj papieru, zestaw ×3) |
| `src/world/note_paper.gd` | `NotePaper`: kartka w świecie (leży albo przypięta do ściany) |
| `src/world/note_reader.gd` | `NoteReader`: czytnik na papierze (pauza, Esc/E, bez przebicia klawisza) |
| `src/world/ticket_drawer.gd` | `TicketDrawer`: szuflada kasy biletowej z kluczem do szafki |
| `src/world/pistol_locker.gd` | `PistolLocker`: szafka na broń w kanciapie |
| `src/world/artifact_catalog.gd` | `ArtifactCatalog`: 6 artefaktów (nazwy, efekty, kolory, stałe efektów) |
| `src/world/artifact_pickup.gd` | `ArtifactPickup`: artefakt w pojemniku (model, poświata, podniesienie) |
| `src/world/artifact_effects.gd` | `ArtifactEffects`: efekty artefaktów bez zaczepów w cudzych plikach |
| `src/world/weak_point_glow.gd` | poświata słabych punktów (monokl) — shader obwódki |
| `src/world/locked_door_latch.gd` | `LockedDoorLatch`: zamknięte drzwi nocy + klucz woźnego |
| `src/world/cctv_catalog.gd` | `CctvCatalog`: 6 kamer (pozycja, cel, pomieszczenie, nazwa) + zegar nocy |
| `src/world/cctv_feed.gd` | `CctvFeed`: `SubViewport` + kamera + nakładka (nazwa, REC, czas, RUCH) |
| `src/world/cctv.gd` | `Cctv`: kamery w świecie, ściana monitorów, harmonogram odświeżania |
| `src/world/cctv_console.gd` | `CctvConsole`: pulpit na biurku (interakcja) |
| `src/world/cctv_view.gd` | `CctvView`: pełnoekranowy podgląd (1–6, strzałki, kółko, Esc/E) |
| `src/world/cctv_screen.gdshader`, `cctv_view.gdshader`, `weak_point.gdshader` | szum, linie, winieta; obwódka słabych punktów |
| `tests/unit/test_lobby_secrets.gd`, `test_note_catalog.gd`, `test_artifact_catalog.gd`, `test_cctv_catalog.gd`, `test_world_texts.gd` | logika i teksty |
| `tests/integration/test_world_secrets.gd`, `test_world_notes.gd`, `test_world_artifacts.gd`, `test_world_cctv.gd` | komponenty na zbudowanym lobby |
| `tests/support/world_testbed.gd` | lobby + strażnik + `LobbyFeatures` do testów i scenariusza |
| `tests/scenarios/world_scenario.gd` + `.tscn`, `tools/run_world.sh` | zrzuty do `tests/_out/world/` (okno, bez dźwięku) |

## Zadania

### Zadanie 1 — ten plan
Commit dokumentu.

### Zadanie 2 — rdzeń i sekrety przestrzenne
`LobbyFeatures` (instalacja, `discover_secret`), `LobbySecrets`, `WorldSounds` + 10 nowych dźwięków w `gen_sfx.py`, `WorldHud` (baner), `SecretSwitch`, `CrookedPlaque`; sekrety: obraz (`panel_painting`), szyb (`panel_vent_in`/`panel_vent_out`, przełączniki na obu licach), tabliczka (`panel_plaque`), składzik (`panel_closet` → `GameState.discover_haven(&"closet")`, sygnał `haven_discovered`).

Testy: odkrycie liczy się raz i trafia do `GameState.secrets` (+ zapis); baner „SEKRET ODKRYTY · n/6”; interakcja z obrazem otwiera panel i odkrywa sekret; szyb odkrywany z każdej kratki, obie otwierają się; tabliczka prostuje się i ściana odjeżdża; składzik dodaje przystań i emituje sygnał; odkryte wcześniej sekrety są otwarte od razu po instalacji i nie mają przełączników; `WorldSounds.NAMES` mają pliki.

### Zadanie 3 — notatki, szuflada i szafka
`NoteCatalog`, `NotePaper`, `NoteReader`, `TicketDrawer`, `PistolLocker`; 8 notatek: `note_1..3` (zestaw, sekret 5), `note_key` (biurko w kanciapie, dopóki klucz nieznaleziony), `note_chamber`, `note_niche`, `note_vent`, `note_closet`.

Testy: przeczytanie zapisuje `GameState.notes` raz; trzy notatki zestawu = sekret `notes`; czytnik pauzuje grę i trzyma wejście, zamyka się na Esc i na E, a zamknięcie klawiszem E nie otwiera notatki ponownie (klawisz musi zostać puszczony); teksty PL/EN istnieją; szuflada daje klucz raz; szafka bez klucza odmawia, z kluczem otwiera się i wydaje pistolet; po znalezieniu klucza kartka Heńka znika.

### Zadanie 4 — artefakty
`ArtifactCatalog`, `ArtifactPickup`, `ArtifactEffects`, poświata słabych punktów, `PadlockedCase`, `LockedDoorLatch`, rząd ikon w `WorldHud`.

Efekty (bez zaczepów w cudzych plikach):
- **Skarabeusz** — dobicie leczy +100%: na `Events.enemy_destroyed` z `finisher` strażnik dostaje drugie `finisher_heal`,
- **Monokl kustosza** — `Hurtbox.weak_point` eksponatów dostaje świecącą obwódkę (shader, bez prześwitu przez ściany),
- **Moneta z fontanny** — `RunState.set_multiplier(&"coin", 1.5)`,
- **Ogarek świecy** — na `Events.hit_landed` z `stun_time > 0` ogłuszenie przedłużane do ×1,5 (`EnemyBrain.stun` bierze dłuższy czas),
- **Ząb wilka** — `player.sprint_speed` ×1,2,
- **Klucz woźnego** — otwiera zamknięte drzwi nocy (`LockedDoorLatch`: `unlock()` + `open()`) i gablotę na kłódkę.

Testy: pojemniki wg `night.loot` dostają właściwe artefakty; podniesienie → `RunState.artifacts`, baner, ikona; każdy efekt osobno; kłódka pęka od strzału (Hurtbox) → sekret `case` i dostępny artefakt; klucz woźnego otwiera kłódkę i drzwi nocy; bez klucza drzwi odmawiają; po `RunState.reset()` ikony znikają.

### Zadanie 5 — CCTV
`CctvCatalog`, `CctvFeed`, `Cctv` (kamery w świecie, 6 ekranów na `cctv_wall`), `CctvConsole`, `CctvView`, shadery.

Wydajność: podglądy odświeżane tylko, gdy strażnik jest w kanciapie albo w widoku pełnoekranowym; po jednym podglądzie na kolejkę (round-robin), ~6 kl./s na kamerę; 320×240; bez cieni punktowych, bez mgły wolumetrycznej, bez MSAA (własne `Environment` kamer — „podczerwień”); w widoku pełnoekranowym główny widok 3D jest wyłączony (`disable_3d`).

Testy: 6 kamer w swoich pomieszczeniach, cel widoczny (promień bez przeszkód); podglądy stoją (`UPDATE_DISABLED`), gdy strażnik poza kanciapą, i ruszają w kanciapie; widok pełnoekranowy: E na pulpicie otwiera, 1–6 / strzałki / kółko przełączają, Esc i E zamykają, stos `GameInput`, `disable_3d` przywracane; znacznik RUCH przy przebudzonym eksponacie w pomieszczeniu kamery; zegar 23:00 + czas nocy.

### Zadanie 6 — scenariusz wizualny i szlif
`tests/support/world_testbed.gd`, `tests/scenarios/world_scenario.gd` + `.tscn`, `tools/run_world.sh`. Zrzuty (`tests/_out/world/`): obraz otwarty + komnata, szyb, ściana z tabliczką otwarta, czytnik notatki (PL), podniesienie artefaktu + ikony, ściana CCTV i widok pełnoekranowy. Przegląd zrzutów, poprawki.

### Zadanie 7 — wyniki
Uzupełnienie sekcji „Wyniki” i „Odstępstwa”, raport dla kontrolera.

## Kontrakt z I1 / kontrolerem

- `Museum._ready()`: po `level.build()`, `_spawn_player()` i `_build_ui()` wywołać `features = LobbyFeatures.install(level as LobbyLevel, self)`. Działa też wcześniej (strażnika szuka leniwie: `museum.player` albo grupa `player`).
- `Museum._place_loot()`: **pomijać** wpisy `night.loot`, które są artefaktami (`ArtifactCatalog.is_artifact(item)`) — artefakty stawia `LobbyFeatures`.
- Pistolet: **nie** stawiać `WeaponPickup` pistoletu — wydaje go `PistolLocker` (po otwarciu kluczem). Strzelbę (`shotgun_case`) stawia I1. Jeśli I1 wolałby własną szafkę: `LobbyFeatures.include_locker = false` przed `install`.
- Sygnały `LobbyFeatures`: `secret_discovered(id, found, total)`, `haven_discovered(id)`, `note_read(id)`, `key_found`, `artifact_taken(id)`; `cctv.view_opened` / `cctv.view_closed`. `LobbyFeatures.of(get_tree())` znajduje instancję (grupa `lobby_features`).
- Notatki do listy w menu pauzy: `NoteCatalog.read_notes(GameState)`, `NoteCatalog.title(id)`, `features.reader.open_note(id)`.
- Opcjonalnie (kontroler): dopisać `WorldSounds.NAMES` do `Sfx.SOUNDS` (dziś ładuje je `WorldSounds.warm()`); modele pierwszoosobowe broni na stałe na warstwie renderowania 20 (`CctvFeed.VIEWMODEL_LAYER`) — dziś przestawia je `Cctv` w czasie gry.

## Odstępstwa od projektu

1. **Obraz nie obraca się na zawiasie, tylko odjeżdża w bok wzdłuż ściany.** Panel `panel_painting` to `Door` stylu PANEL z 2b-1 (przesuw o szerokość przejścia); `door.gd` należy do I1, a przesuwający się obraz czyta się dobrze (zrzuty 02–03).
2. **Szuflada kasy i szafka na broń zrobione tutaj** (nie było ich na liście zadania), bo kartka Heńka bez klucza i szafki byłaby martwa. Szafka wydaje pistolet jako zwykły `WeaponPickup` przed otwartymi drzwiczkami. Wyłącznik: `LobbyFeatures.include_locker = false`.
3. **Efekty artefaktów bez zaczepów w cudzych plikach** (sygnały `Events`, `RunState.multipliers`, `player.sprint_speed`, `EnemyBrain.stun`) — I1 nie musi nic wołać. Gdyby dodał własne efekty (np. mnożnik ogłuszenia w `Enemy`), trzeba usunąć odpowiednik tutaj, żeby nie liczyć podwójnie.
4. **Kartka Heńka leży, dopóki klucz nie zostanie znaleziony** (nie tylko w noc 1) — kto zginął w noc 1 bez klucza, dalej dostaje podpowiedź.
5. **Szyb:** każda z dwóch kratek otwiera się osobno i z obu stron (od środka: „Wypchnij kratkę”); sekret liczy się przy pierwszej otwartej.
6. **Sekret notatek** zalicza się przy odłożeniu trzeciej notatki zestawu (nie w chwili otwarcia), żeby baner nie chował się pod czytnikiem.
7. **Własny baner zamiast `Hud.show_toast`:** `WorldHud` (warstwa 12) pod komunikatem HUD; kolejka komunikatów, krótsze wyświetlanie, gdy czekają kolejne.
8. **Identyfikatory sekretów krótkie** (`painting`, `vent`, `plaque`, `case`, `notes`, `closet`) — jak w teście ekranu końca dema.
9. **Ściana CCTV:** szary wygląd elementu `cctv_wall` jest ukrywany (kolizja zostaje) i zastępowany szafą z 6 monitorami CRT (kamery 1–3 u góry, 4–6 niżej, od lewej), ekranem stanu (noc, zegar, gdzie ruch) i panelem lampek.
10. **Zegar na obrazach kamer** liczony z `RunState.time` (23:00 + 20 s zegara na sekundę gry, stop o 6:00 — rozbudowa §4); zegara nocy w grze jeszcze nie ma, `CctvCatalog.clock_text()` to jedyne miejsce do podmiany.
11. **Modele broni w pierwszej osobie przestawiane na warstwę renderowania 20** przez `Cctv`, gdy działają podglądy (ich własny FOV i spłaszczona głębia rysowały je w kamerach ponad ścianami). Kamera strażnika dalej je widzi.
12. **Dźwięki świata nie są w `Sfx.SOUNDS`** (plik `src/fx` nie jest mój): `WorldSounds` gra przez `Sfx` i ładuje je z góry (`warm()`), test nazw ma własny odpowiednik (`test_lobby_secrets`).
13. **`install()` zwraca węzeł `LobbyFeatures`** (zamiast `void`), żeby `Museum` mogło podłączyć sygnały; wywołanie jako zwykła instrukcja też działa.
14. **Widok pełnoekranowy kamer nie pauzuje gry** (zgodnie z §5 rozbudowy: zegar biegnie, to ryzyko); wejście strażnika jest zablokowane, a główny widok 3D wyłączony na ten czas.

## Wyniki

- Testy: **609** (546 na starcie + 63 nowe: 5 plików jednostkowych, 4 integracyjne), wszystkie zielone, bez linii `ERROR` i wycieków; ~40 s.
- Zrzuty (okno 1280×720, bez dźwięku): `bash tools/run_world.sh` → `tests/_out/world/` (32 obrazy): 01–04 obraz i komnata, 05–08 szyb (kratka, wnętrze, schody, wyjście na antresolę), 09–10 krzywa tabliczka i otwarta nisza, 11–12 biurko i czytnik (zestaw 1/3 i 2/3, karteczka Heńka, instrukcja z 1912, zlecenie serwisowe, list kustosza), 13–15 artefakt w gablocie, rząd ikon, monokl na głowach eksponatów, 16–17 kłódka przed i po strzale, 18–21 szuflada kasy i szafka na broń, 22–27 ściana CCTV i widok kamer (hol, galeria, antresola, przełączanie). `bash tools/run_world.sh dry` — to samo bez okna.
- Poprawki po przeglądzie zrzutów: większe artefakty na aksamitnej poduszce, większa kłódka, jaśniejsza szuflada wysuwana spod lady, kolejka banerów, kolejność monitorów 1-2-3 od lewej, pas pod kanałami w widoku kamer, list kustosza i pieczątka bez nakładania na tekst.
- Koszt CCTV: poza kanciapą zero renderów (test); w kanciapie jeden podgląd 320×240 na klatkę gry w kolejce, 6 obrazów/s na kamerę (36 małych renderów/s), bez MSAA, cieni punktowych, mgły i efektów ekranu; widok pełnoekranowy: 640×480 × 15/s przy wyłączonym głównym 3D.

## Poprawki po przeglądzie (1.10)

Druga runda przeglądu, sekcja R2 (świat lobby), razem z integracją nocy (plan `2026-10-01-integracja-noc.md`, ta sama gałąź).

**Krytyczne**
- **W1 — szyb wentylacyjny da się przejść.** Schody `vent_steps` bez poręczy: szczelina ma 1 m, poręcze po obu stronach nie zostawiały strażnikowi miejsca i stawał u stóp stopni (ściany szybu i tak są poręczami). Nowy test `test_secret_passages_walk`: prawdziwy strażnik z wciśniętym `move_forward` (bez teleportów, skręca tylko głową ku kolejnym punktom) przechodzi diorama → szyb → antresola i z powrotem, a także składzik, komnatę za obrazem i niszę strzelby w obie strony.

**Decyzje projektowe (wdrożone jak zapisano)**
- **W2 — widok kamer zamyka się sam**, gdy strażnik oberwie (wraca do biurka zobaczyć, co go trafiło), zginie i o świcie (`CctvView.snap_shut()` — wejście wraca od razu, bez czekania na puszczenie klawiszy). Przy utracie fokusu okna (gdy pauza przy utracie fokusu jest włączona) widok zamyka się i prosi o pauzę: `CctvView.pause_requested` → `Cctv` → `LobbyFeatures.pause_requested` → `Museum` → `pause_menu.open()` (samo menu pauzy nie otworzyłoby się nad widokiem, który trzyma wejście — noc biegłaby dalej bez gracza).
- **W5 — szafka i szuflada w kolejne noce:** klucz jest strażnika, więc lampka szafki świeci na zielono, ale drzwiczki są zamknięte do pierwszego E (pistolet czeka w środku, dopóki go nie weźmie); szuflada kasy znów jest zamknięta i daje się otworzyć — „Bilety ulgowe z 1987 roku i jeden guzik”.
- **W15 — „Kontynuuj” w tej samej nocy pamięta artefakty i drzwi:** wzięte artefakty (`RunState.used`: `artifact_<id>`) wracają do kieszeni, ich gabloty zostają puste; drzwi nocy otwarte kluczem woźnego (`unlocked_<drzwi>`) zostają otwarte, bez zatrzasków.

**Pozostałe**
- **W3:** klik zamyka notatkę: korzeń i zasłona czytnika `MOUSE_FILTER_IGNORE`, a E, Esc i klik obsługuje `NoteReader._input` (przed GUI — przy notatce otwartej z menu pauzy klik nie naciśnie przycisku pod kartką). Podpowiedź „E / Escape / klik — odłóż” z nazwami prawdziwych klawiszy.
- **W4:** ekran stanu CCTV wymienia najwyżej 4 pomieszczenia z ruchem, resztę zwija w „+n więcej” (`Cctv.STATUS_ROOMS`, `CCTV_STATUS_MORE`); test sześciu pomieszczeń w obu językach (wysokość i szerokość).
- **W6:** strzał w kłódkę to trafienie, nie zniszczenie: `Events.hit_landed(..., killed = false)`.
- **W7:** jak NIm8 w planie integracji — zamknięty hol wstrzymuje zatrzaski klucza woźnego (`LobbyFeatures.hold_latches`, `LockedDoorLatch.held`), po walce je puszcza.
- **W8 — notatki w menu pauzy:** czytnik na warstwie 65 (nad menu pauzy, 60). W menu pauzy pozycja „Notatki” (tylko w grze z czytnikiem i gdy przeczytano choć jedną): lista tytułów w kolejności czytania (`NoteCatalog.read_notes`, `NoteCatalog.title`), wybór otwiera notatkę ponownie nad menu (`reader.open_note`, gra dalej w pauzie); Esc odkłada kartkę (zostaje lista), drugi Esc wraca do panelu, trzeci wznawia grę. Menu ignoruje Esc, gdy na stosie wejścia leży nad nim coś innego.
- **W9:** kartka wyższa niż ekran (z marginesem na podpowiedź) zmniejsza się, by się zmieścić (`NoteReader.paper_rect()`); test wszystkich ośmiu notatek w obu językach.
- **W10:** rząd ikon artefaktów zawsze pod blokiem HUD-u w lewym górnym rogu (`Hud.top_left_bottom()` → `WorldHud.corner_source`) — także pod długim celem nocy i pod pomocą F1.
- **W11:** modele pierwszoosobowe tylko na warstwie renderowania 20: `Viewmodels.build()` przestawia każdą siatkę widoku (`Viewmodels.first_person_layer`), więc `Cctv` nie musi już co 0,25 s przeszukiwać kamery strażnika. To jedyna zmiana w `src/weapons/*` (kilka linii w `viewmodels.gd`, poza plikami rigów).
- **W12 — pomiar w kanciapie** (okno 1920×1080, bez V-Sync, RTX 2080 Ti, strażnik na krześle przed ścianą): podglądy kosztowały średnio ok. 0,2 ms na klatkę (2,59 ms zamiast 2,38), ale klatka z renderem podglądu ok. +2 ms, z czego kaskady cienia księżyca, rysowane osobno dla każdej kamery, to ok. ¼ czasu i ponad połowa wywołań rysowania (sześć podglądów co klatkę: 14,6 ms i 8168 wywołań → 11,7 ms i 3638 bez księżyca). Księżyc trafia więc na własną warstwę 19 (`CctvFeed.MOON_LAYER`, ustawia ją `Cctv`), której kamery CCTV i widok pełnoekranowy nie widzą — ich bladą „podczerwień” i tak niesie własne otoczenie. Po zmianie podglądy w kanciapie nie mają mierzalnego kosztu średniego (2,41 ms przy działających, 2,49 ms przy zatrzymanych — szum pomiaru).
- **W13 — modele grafiki:** ściana CCTV to `cctv_bank` (dwa rzędy po trzy monitory, każdy ekran z własnym materiałem z `PropArt.screen`; obraz kamery idzie w `albedo_texture` i `emission_texture`, do pierwszej klatki przygaszony obraz czuwania) na regale za biurkiem, na wysokości blatu, ze stojakiem pod spodem; ekran stanu i panel lampek zostają po bokach. Szafka na broń to ścienna szafka `pistol_locker` przykręcona do szafek personelu: drzwiczki przez `PropArt.set_locker_open`, lampka przy zamku, pistolet leży na filcu w `PropArt.locker_spot` z małym ciepłym światłem (jego `WeaponPickup` jest wtedy tylko strefą użycia; po wzięciu pistolet znika z filcu). Bez modeli (`ArtLibrary.models_enabled = false` albo brak pliku) — dotychczasowe szare wersje; testy obu dróg.
- **W14 — spójność:** pistolet `WeaponPickup` dostaje `game`/`run` gry; napisy `Label3D` (szablon na szafce, tabliczka w zbrojowni) i nakładki podglądów (REC, RUCH) idą za zmianą języka; podpowiedzi czytnika i widoku kamer biorą nazwy klawiszy z `GameInput.key_label`; zegar na obrazach kamer liczony ze stałych `NightClock`; ekran końca dema liczy sekrety przez `LobbySecrets.found/total`; monokl podświetla kryształ w żebrach T-Reksa (tylko gdy tam jest), CCTV pokazuje ruch obudzonego T-Reksa; tablice typowane.
- **Teksty:** notatka 3 („Jeśli to znalazłeś: nie wkładaj bezpieczników…”), notatka składzika („A jak go zgubiłem, to leży w jakiejś gablocie — tam w końcu wszystko trafia.”), zlecenie serwisowe („Kratka na antresoli odkręca się też od środka.”); po angielsku „broom cupboard” zamiast „closet” (sekret, przystań, notatka) i „I learnt that the hard way”.

**Testy:** nowe `test_secret_passages_walk` (4), `test_world_in_the_game` (6: lista notatek w menu pauzy, klik nad menu, utrata fokusu w widoku kamer, artefakty i drzwi po „Kontynuuj”, rząd ikon pod HUD-em, kłódka), rozszerzone `test_world_cctv` (model i szara ściana, zwijanie listy, zamykanie widoku, utrata fokusu, ruch T-Reksa, księżyc poza podglądami), `test_world_notes` (kolejne noce, szafka z modelu i szara, klik, kartki na ekranie, warstwa czytnika), `test_world_artifacts` (monokl a T-Rex), `test_pause_menu` (przyciski widoczne bez listy notatek).

**Wyniki:** cały zestaw po scaleniu zielony dwa razy z rzędu (1033 testy); zrzuty `bash tools/run_world.sh` obejrzane po zmianach (ściana z `cctv_bank` z obrazami kamer, szafka zamknięta z zieloną lampką i otwarta z pistoletem na filcu, czytnik z nową podpowiedzią); `run_world.sh dry` przechodzi.
