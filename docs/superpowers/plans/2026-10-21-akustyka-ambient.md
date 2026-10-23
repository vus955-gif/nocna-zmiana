# Akustyka sal i opowieść ambientu (Piętro I)

> Plan wykonawczy. Wykonawca: jeden agent w worktree `audio-spaces` (gałąź `audio-spaces` od `pietro-1` @76bac48b).
> Źródło: backlog właściciela `docs/backlog-pietro1.md` — **#40** („Każdy rodzaj broni, przeciwnika i pomieszczenia powinien mieć właściwy charakter akustyczny. Strzał w ogromnym kamiennym holu nie powinien brzmieć tak samo jak w małym magazynie”), **#41** („skrzypienie budynku, wentylacja, odległe kroki, poruszające się eksponaty, szepty, radio ochrony, zegary, dźwięki miasta za oknem… Cisza również powinna być świadomie używana”) i punkt QA „przesłanianie dźwięku ścianami (graf sal + promień)”.
> **Bez okien i bez dźwięku** (właściciel pracuje przy komputerze): niczego nie odtwarzamy. Ocena liczbami (`tools/music/analyze.py`: LUFS, szczyty, true peak, pasma, szwy pętli; czas pogłosu z całkowania Schroedera) i kodem. Nic nie trafia na GitHub.

**Cel:** strzał, wybuch i potwór brzmią w przestrzeni, w której są: kamienny hol dudni sekundami, magazyn klaszcze krótko i pudełkowo, kotłownia dzwoni stalą, dach odpowiada echem kamienic. Co jest za ścianą, słychać stłumione. Między walkami budynek opowiada: skrzypi, wentylacja tyka, ktoś idzie w sąsiedniej sali (nikogo tam nie ma), eksponat przesuwa się na cokole, w Egipcie szepczą, w Oświeceniu ktoś nakręca zegar, za oknem jedzie tramwaj, w niektóre noce deszcz bębni w szklany dach. I są chwile ciszy — w przystaniach, przed strażnikiem, „budynek wstrzymuje oddech” — oraz wszystko ustępuje głosowi.

---

## 1. Inwentarz (stan przed zmianą)

### 1.1 Co już jest

| Element | Gdzie | Co robi |
|---|---|---|
| Strefy pogłosu | `src/audio/reverb_zone.gd` (Area3D, warstwa 20) | 8 presetów: HALL, ROOM, CORRIDOR, VAST, GALLERY, LIBRARY, GARDEN, CONCRETE; dźwięki 3D w strefie wysyłają część sygnału na szynę pogłosu (`Reverb*` → `SFXReturn`) |
| Automatyczne strefy | `Ambience.build_reverb()` | po jednej na część pokoju z `layout.rooms`; preset: `ROOM_REVERB` (lobby) → słowo w id (`ROOM_WORD_REVERB`) → strefa (`ZONE_REVERB`) |
| Pogłos słuchacza | `Ambience._sfx_reverb` | `AudioEffectReverb` dokładany do szyny SFX, parametry z `ReverbZone.LISTENER` (wet 0,05–0,18) — jedyne, co dziś odróżnia strzał strażnika (dźwięk 2D) w holu od strzału w schowku |
| Ambient stref | `Ambience` | 25 warstw (pętle 40 s), mieszanki per strefa, blackout, awaria prądu, godzina duchów, ptaki o świcie |
| Dalekie dźwięki | `Ambience.ZONE_SHOTS` | co 10–24 s (blackout 6–15, po 3:00 7–17) losowy daleki dźwięk strefy w 3D; 23 rodzaje, przestrzeń „wypalona” w próbce |
| Kroki | `src/audio/footsteps.gd` | eksponaty w 3D z pogłosem stref |
| Głos | `VoiceDirector` | przycisza Ambience o −4 dB (`VoiceDuck`), Music o −6 dB |
| Zdarzenia nocy (osobna gałąź `night-escalation`) | `data/night/uncanny.json` | lampy, dalekie łupnięcia, drzwi, PA, radio; sygnały `Events.night_phase_changed(phase)` i `Events.uncanny_event(id, room)` |

### 1.2 Czego brakuje (#40, #41)

1. **Strzał strażnika nie zna sali.** Gra płasko (2D); jedyny ślad przestrzeni to lekki pogłos słuchacza (Godot `AudioEffectReverb`, wet ≤ 0,18). Pistolet w Dziedzińcu (79 000 m³) i w szatni (50 m³) różni się ledwie słyszalnie. Próbki broni są suche (pistolet −24 dB po 0,2 s), więc to sala musi dać ogon.
2. **Brak przesłaniania.** Ryk mumii za ścianą brzmi jak w tej samej sali, tylko ciszej (tłumienie z odległości).
3. **Brak presetów** dla małych magazynów (dziś ROOM), stalowej kotłowni (dziś CONCRETE) i dachu pod gołym niebem (dziś GARDEN).
4. **Ambient nie opowiada.** Dalekie dźwięki są losowym „szumem tła”: nie zależą od fazy nocy, nie mają przerw, nie ma szeptów, kroków-widm, przesuwających się eksponatów, radia, nakręcania zegarów, miasta, deszczu.
5. **Cisza nie jest używana.** Dalekie dźwięki grają też w przystaniach, tuż przed strażnikiem i w trakcie kwestii głosu.

---

## 2. Architektura (decyzje)

### 2.1 Profile akustyczne — dane, nie kod

Jeden plik **`data/audio/acoustics.json`** (czyta go i gra, i generator w Pythonie):

- `profiles` — 11 klas przestrzeni (8 dotychczasowych + **STORE**, **STEEL**, **OPEN**). Każda ma: preset `ReverbZone`, parametry szyny pogłosu Godota (`bus`: room_size, damping, spread, hipass, predelay, sprzężenie predelay, wet — **plik wygrywa z `default_bus_layout.tres`**: `Acoustics.ensure_buses()` ustawia je przy starcie i tworzy brakujące szyny), parametry ogona do generatora (`tail`: RT60, predelay, liczba/rozpiętość/siła pierwszych odbić, ciemność, bas, echo trzepoczące między równoległymi ścianami, dyskretne echa, rezonanse stali) i głośność ogona w grze (`tail_db`).
- `rooms` — **każda z 114 sal Piętra I** → [profil, wysyłka]. Kolejność wyboru presetu w `Ambience.reverb_for()`: `ROOM_REVERB` (lobby) → **`rooms` z pliku** → słowo w id → strefa. Nowe sale innych gałęzi dostają profil z reguł słów i stref, jak dotąd.
- `tails` — dźwięk → [klasa ogona, dB]: broń strażnika (2D) i wybuchy/uderzenia (3D).
- `weapons` — broń bez dźwięku na strzał (gatling: grzechot to pętla) → ogon co najwyżej co N s, z `Events.weapon_fired`.
- `occlusion` — dwa poziomy przesłaniania (szyny, filtr, spadek głośności).

Dlaczego JSON, a nie stałe GDScript: to tabela strojenia (jak `data/voice/lines.json`, `data/night/uncanny.json`), jedna dla gry i generatora — RT60 ogona i parametry szyny nie mogą się rozjechać.

### 2.2 Ogony sal (strzały, wybuchy)

Standard strzelanek (warstwa „close” + warstwa „tail” zależna od otoczenia): suchy strzał gra jak dotąd, a obok, w tej samej klatce, **ogon sali** — gotowa próbka „ta sala po huku”: splot pobudzenia klasy (krótki trzask, huk, wybuch) z odpowiedzią impulsową profilu (sama część mokra, z predelay i pierwszymi odbiciami). 11 profili × 3 klasy = **33 próbki stereo** (Ogg 96 kbit/s, ok. 1,5 MB).

- **crack** — pistolet, sztucer, harpun, gatling: krótki szerokopasmowy impuls + niski „klap” lufy,
- **boom** — strzelba, rakietnica, odpalenie hwachy, trzaśnięcie drzwi, ciężkie łupnięcie: więcej dołu, dłuższy impuls,
- **blast** — wybuch racy, uderzenia strażników (Kolos, Lamassu, T-Rex), rozpad strażnika, walący się mur: 0,1–0,2 s dudnienia z subbasem.

Gdzie gra ogon: broń strażnika (dźwięk 2D na SFX) → ogon **sali słuchacza** płasko na `SFXReturn` (obok SFX, żeby nie przeszedł drugi raz przez pogłos słuchacza; suwak efektów obejmuje go, bo `SFXReturn` idzie za SFX). Dźwięk 3D (wybuch, uderzenie) → ogon **sali źródła** w 3D w miejscu źródła, przez szynę swojego poziomu przesłaniania (huk w sąsiedniej sali słychać jej pogłosem przez drzwi). Strażnik bez strefy pogłosu (sandbox, menu) — bez ogona.

Budżet: najwyżej `tail_voices` (6) ogonów naraz (najstarszy ustępuje), tej samej klasy nie częściej niż co `tail_gap` s (salwa hwachy, gatling).

Ogony są tylko na **SFX** (głos ich nie przycisza — tak samo jak strzałów).

### 2.3 Przesłanianie (occlusion) — graf sal + jeden promień

`AcousticGraph` z `LevelLayout` (sale, przejścia, schody, sale-goście w gospodarzu jak balkon w Dziedzińcu = 0 przejść; to ta sama logika co `RoomCuller`). Dla dźwięku 3D w chwili startu:

| Sytuacja | `walls` | Co się dzieje |
|---|---|---|
| ta sama sala **albo** promień ucho → źródło (warstwa WORLD) czysty | 0 | jak dotąd (SFX, pogłos strefy) |
| sąsiednia sala, bez linii wzroku (za węgłem, przez drzwi) | 1 | **przeszkoda (obstruction)**: suchy sygnał przez dolnoprzepustowy ~1,5 kHz, −4 dB; pogłos sali źródła zostaje (słychać ją przez otwór) |
| dwie i więcej sal dalej | 2 | **przesłonięcie (occlusion)**: ~480 Hz, −10 dB, bez pogłosu strefy źródła, za to ciemny rozproszony pogłos na szynie przesłaniania („coś za ścianami”) |
| poza salami (lobby bez sal, sandbox) | 0/1 | sam promień: czysty → 0, zasłonięty → 1 |

Szyny `SFXObstructed`, `SFXOccluded` (→ SFX) tworzy `Acoustics.ensure_buses()` z danych (nie ma ich w `default_bus_layout.tres` — inne gałęzie dopisujące szyny nie mają z czym kolidować). Koszt: liczone raz, przy starcie dźwięku (jedno `room_at` + BFS z pamięcią + jeden promień); kroki eksponatów co najwyżej co 0,4 s na eksponat. **Nic nie liczy się co klatkę.** Strzał strażnika (2D) nigdy nie jest przesłaniany.

Wpięcie bez dotykania `sfx.gd`: `Ambience` już słucha `Sfx.child_entered_tree` (dokłada warstwę pogłosu każdemu głosowi) — tam `Acoustics.on_voice()` wybiera szynę i ogon. Kroki eksponatów: jedna linia w `Footsteps._play()`.

### 2.4 Warstwa opowieści (scheduler) — `data/audio/ambient_story.json`

`AmbientStory` (czysta logika, testowalna) + `StoryLayer` (węzeł-dziecko `Ambience`, wykonawca). Co `Ambience.POLL` (0,25 s) dostaje stan: strefa, faza nocy, noc, modyfikator, przystań, strażnik blisko, walka, głos, deszcz, ciemność. Zwraca co najwyżej jedno zdarzenie naraz.

- **Odstępy według fazy nocy** (`NightEscalation`: CALM 23–1, UNEASY 1–3, WITCHING 3–5, PREDAWN 5–6; z gałęzi `night-escalation` przez `Events.night_phase_changed`, a bez niej z `Events.hour_struck` / `witching_hour`): spokój 38–75 s, niepokój 28–55, godzina duchów 18–40, przed świtem 14–30. Noc 1 rzadziej (×1,3).
- **Historie** (każda: strefy, fazy, od której nocy, waga, czas odnowienia, limit na noc, gdzie gra, głośność, wysokość):

| Historia | Dźwięk | Gdzie | Kiedy |
|---|---|---|---|
| osiadanie budynku | `settle` | wszędzie pod dachem, 12–25 m | zawsze |
| tykanie kanałów | `vent_knock` | podziemia, korytarze, hol północny, kanciapa, wejście | zawsze |
| podmuch wentylacji | `vent_surge` | podziemia, korytarze, kanciapa | gdy jest prąd |
| kroki-widma | `phantom_steps` | **sąsiednia sala**, źródło idzie 5 m | od nocy 2, od 1:00; poprzedza je martwa cisza |
| eksponat się przesuwa | `shift_stone/wood/metal/soft` wg materiału | **przy prawdziwym śpiącym eksponacie** 8–30 m, poza linią wzroku | zawsze |
| szepty | `whisper` | Egipt, grobowce; 3–7 m, przesuwa się | od nocy 2, od 1:00, w godzinie duchów częściej |
| bicie zegara | `clock_chime` | Oświecenie | zawsze |
| ktoś nakręca zegar | `clock_wind` | Sala Zegarów, Oświecenie | od nocy 2, od 1:00 |
| zegary milkną | (cisza warstwy `clocks` na 4 s) | Sala Zegarów | od 3:00 |
| syrena w mieście | `siren` | Dziedziniec, wejście, dach, kanciapa | do 5:00 |
| tramwaj | `tram` | wejście, Dziedziniec, dach | do 1:00 (ostatnie kursy) |
| radio ochrony | `radio_chatter` | w kanciapie (na biurku), słychać z holu | zawsze; jedyne, co gra w przystani |
| grzmot | `thunder` | Dziedziniec, dach, wejście, ogród | tylko w noc deszczu |

- **Deszcz** w niektóre noce (od nocy 2, szansa 30 %, nie w blackout; deterministycznie z numeru nocy i ziarna): warstwy `rain_glass` (szklany dach Dziedzińca, przytłumiony w holu wejściowym) i `rain_open` (dach, ogród japoński).
- **Cisza celowa** (`silent()` wstrzymuje i historie, i dotychczasowe dalekie dźwięki; `bed_dip_db()` przycisza warstwy):
  - **przystań** — żadnych dalekich dźwięków (poza radiem w kanciapie), warstwy −3 dB;
  - **przed strażnikiem** — w sali obok areny śpiącego strażnika nic nie gra, warstwy −4 dB; w samej arenie −9 dB („cisza przed burzą”), aż strażnik się obudzi;
  - **walka** (muzyka w COMBAT/BOSS/GUARDIAN) — historie czekają;
  - **martwa cisza** — od nocy 2, od 1:00, szansa 20 % zamiast historii: warstwy −10 dB na 5–9 s, potem historia z „wejściem po ciszy” (kroki-widma);
  - **po zdarzeniu niesamowitym** (`Events.uncanny_event`, jeśli gałąź jest wmergowana) 25 s ciszy historii — nie wchodzimy w ich moment; **po upadku strażnika** 40 s.
- **Głos**: historie i dalekie dźwięki nie startują, gdy kwestia jest na antenie, i jeszcze 2 s po niej; wszystko gra na szynie Ambience, więc przyciszanie `VoiceDuck` (−4 dB) działa jak dotąd.

### 2.5 Nowe dźwięki (proceduralnie, numpy, deterministycznie)

`tools/music/acoustics_tails.py` (ogony, czyta `data/audio/acoustics.json`), `tools/music/ambience_story.py` (historie i deszcz), rejestrowane w `gen_ambience.py`; kodowanie `encode_ogg.py` (ogony: `build/audio_src/ambience/tails/` → `assets/ambience/tails/`, stereo 96 kbit/s). Testy Pythona: `tools/music/test_acoustics.py`.

---

## 3. Zadania (TDD, jeden commit na zadanie)

1. **Plan** (ten plik). ✅
2. **Dane** `data/audio/acoustics.json`, `data/audio/ambient_story.json` + `Acoustics` (ładowanie, profil sali, nowe presety STORE/STEEL/OPEN, szyny z danych). Testy: każdy preset ma szynę i parametry z pliku; profil dla każdej sali Piętra I; tabela `rooms` nazywa istniejące sale. ✅
3. **Generator ogonów** + testy Pythona (RT60 Schroedera w ±20 % celu, predelay, trzepot, echa, szczyty, ciche krawędzie, determinizm) + render, analiza, kodowanie. ✅
4. **Generator historii i deszczu** + testy Pythona (szczyty, głośność chwilowa, sylaby szeptu, szwy i brak „gwizdu” w deszczu) + render, analiza, kodowanie. ✅
5. **Przesłanianie**: `AcousticGraph`, `Acoustics.walls_for()`, routing głosów Sfx i kroków. Testy: 0/1/2 ściany (czysta funkcja), graf (przejścia, schody, sale-goście, całe Piętro I), prawdziwa geometria (ściany `StaticBody3D` z drzwiami między kamerą a źródłem). ✅
6. **Ogony w grze**: broń strażnika → ogon sali słuchacza; 3D → ogon sali źródła; gatling przez `weapon_fired`; budżet i odstęp. Testy. ✅
7. **Scheduler** `AmbientStory`: tempo wg fazy, okna ciszy, odnowienia i limity, warunki (noc, faza, deszcz, prąd), głos, martwa cisza, determinizm. Testy czystej logiki. ✅
8. **`StoryLayer` + `Ambience`**: wykonanie historii (pozycje: wokół, blisko, sąsiednia sala, eksponat, ulica, niebo, sala), ruch źródła, deszcz, przyciszanie warstw, zegary milkną, bramka dla dalekich dźwięków. Testy integracyjne. ✅
9. **Dokumentacja**: `docs/audio/dzwiek-przewodnik.html` §13, przewodnik odsłuchu niżej. ✅
10. **Merge `pietro-1`**, pełny zestaw testów + testy Pythona.

---

## 4. Liczby (zmierzone, bez słuchania)

### 4.1 Ogony sal

RT60 z profilu, T20 zmierzony całkowaniem Schroedera na wyrenderowanym ogonie (pasmo 500–2000 Hz). „Słychać” = jak długo suchy strzał + ogon (z `tail_db`) trzyma się powyżej −40 dB pod szczytem strzału (sam suchy pistolet: ok. 0,25 s). Wszystkie ogony: głośność chwilowa (400 ms) −16 LUFS albo true peak −1,5 dBFS (krótkie, szpiczaste: magazyn, korytarz, ogród).

| Profil | RT60 | T20 | Predelay | Długość pliku | `tail_db` | Pistolet słychać | Strzelba słychać |
|---|---|---|---|---|---|---|---|
| vast | 4,6 s | 4,46 s | 45 ms | 5,1 s | +2 | 2,0 s | 2,45 s |
| hall | 2,8 s | 2,77 s | 28 ms | 3,5 s | 0 | 1,3 s | 1,65 s |
| gallery | 2,2 s | 2,09 s | 18 ms | 2,7 s | −1 | 0,85 s | 1,1 s |
| room | 0,85 s | 0,80 s | 7 ms | 1,0 s | −5 | 0,35 s | 0,6 s |
| store | 0,38 s | 0,36 s | 2 ms | 0,4 s | −6 | 0,3 s | 0,6 s |
| corridor | 1,3 s | 1,13 s | 4 ms | 1,4 s | −3 | 0,45 s | 0,6 s |
| library | 0,9 s | 0,91 s | 9 ms | 1,3 s | −6 | 0,45 s | 0,6 s |
| concrete | 1,8 s | 1,82 s | 5 ms | 1,9 s | −2 | 0,6 s | 0,7 s |
| steel | 2,1 s | 1,87 s | 5 ms | 2,0 s | −2 | 0,65 s | 0,6 s |
| garden | 0,7 s | 0,63 s | 25 ms | 0,7 s | −8 | 0,3 s | 0,6 s |
| open | 0,45 s | (echa) | 40 ms | 1,2 s | −4 | 1,1 s (echa 240–1050 ms) | 1,15 s |

Trzepot: obwiednia ogona galerii powtarza się co 46 ms (szczyt widma obwiedni 4× ponad medianę), korytarza co 21 ms (10,7×). Stal: czas wybrzmienia pasma 2,5–7 kHz ponad 2× dłuższy niż w bibliotece. Rozmiar: 33 pliki, ok. 1 MB.

### 4.2 Historie

Tempo (symulacja `AmbientStory`, 10 nocy po 6 min fazy, noc 3): spokój 6,4 / 6 min (≈ co 56 s), niepokój 8,3, godzina duchów 11,5–11,9, przed świtem 13,9–15,3 (≈ co 24 s). Dotychczasowe dalekie dźwięki stref grają dalej co 10–24 s (w ciszy pomijane). Przykład Egiptu przed świtem (10 nocy): przesunięcia eksponatów 50, osiadanie 37, szepty 32, kroki-widma 20.

Ujęcia (35, mono, Ogg 80 kbit/s, razem z deszczem ok. 3 MB): głośność chwilowa −11…−19 LUFS (szczyty dobrane tak, żeby najgłośniejszy moment każdego rodzaju był w okolicy −16), głośność w grze ustawia `db` historii (−6 grzmot … −14 szepty i syrena). Deszcz: `rain_glass` −33 LUFS, `rain_open` −30 LUFS (jak inne warstwy: −30…−41), szew: skok 0,08 / 0,28 typowego kroku, korelacja kanałów ≈ 0 (deszcz dookoła), brak stałego tonu (widmo Welcha: najwyższy pik 3,8× / 2,6× wobec 1,4× białego szumu; ton byłby ≫ 10×).

### 4.3 Koszt

Nic nie liczy się co klatkę: przesłanianie i ogon — raz przy starcie dźwięku (jedno `room_at` po ~114 salach, BFS z pamięcią, jeden promień); kroki eksponatu — co najwyżej co 0,4 s; `StoryLayer` — co 0,25 s (strefa, sala słuchacza, ≤ 6 strażników w grupie, jedno `current_line()`); szyny tworzone raz przy starcie.

---

## 5. Przewodnik odsłuchu (dla właściciela)

**Nic z tego nie zostało odsłuchane.** Wszystkie testy i pomiary (§4) są headless i na plikach, dźwięk w nocnych sesjach był zawsze wyciszony — to pierwszy odsłuch człowieka. Najlepiej na słuchawkach, suwaki efektów i ambientu na domyślnych. Wszystko poniżej da się sprawdzić w jednej nocy na Piętrze I (najlepiej noc 2 lub 3: część historii czeka do nocy 2).

**Odsłuch w trzech przebiegach (od najważniejszego):**
1. **Strzał i ogon** (punkty 1–2 niżej) — tu jest główna niewiadoma ostatniego strojenia (`tail_db` podniesione o 3–5 dB względem pierwszej wersji, patrz §6).
2. **Za ścianą i cisza** (punkty 3, 7, 8) — czy przesłanianie nie ukrywa zagrożenia i czy cisza nie wygląda na błąd dźwięku.
3. **Historie i deszcz** (punkty 4–6, 9) — gęstość i charakter; najlepiej przy okazji zwykłej gry przez całą noc, nie jako osobny test.

1. **Strzał a sala.** Stań na środku Dziedzińca i strzel z pistoletu raz, w ciszy. Ogon powinien „pójść w górę pod szklany dach” i wybrzmiewać ok. 2 s. Potem wejdź do szatni przy holu wejściowym (albo do kanciapy) i strzel: krótki, pudełkowy klask, ogon prawie od razu znika. Kotłownia w podziemiach: metaliczne dzwonienie. Dach (kładki): prawie sucho, za to wyraźne echa od kamienic po ok. ¼ i ½ s. Długa galeria Egiptu: szybki trzepot echa między ścianami. **Zwróć uwagę:** czy ogon nie zagłusza samego strzału, czy w Dziedzińcu nie jest za długi przy serii z gatlinga, czy strzelba w magazynie nie „dudni”.
2. **Wybuch w innej sali.** Wystrzel racę przez drzwi do sąsiedniej, większej sali: huk ma pogłos **tamtej** sali, dochodzący zza drzwi.
3. **Za ścianą.** Obudź eksponat (np. mumię) i odejdź do sąsiedniej sali za węgieł: jęk i kroki powinny stać się stłumione (bez góry), ale z pogłosem jej sali. Dwie sale dalej: głuche, ciemne, „gdzieś w budynku”. Wyjrzyj przez drzwi — dźwięk wraca do pełnego.
4. **Historie.** Postój kilka minut w Egipcie po 1:00 (noc ≥ 2): szepty blisko, przesuwające się wokół. W Oświeceniu: kurant zegara zza ściany, kiedyś grzechotka nakręcania zegara; po 3:00 w Sali Zegarów wszystkie zegary na chwilę milkną. W holu wejściowym i na Dziedzińcu: tramwaj (do 1:00), syrena. W kanciapie: radiostacja na biurku. W podziemiach: tykanie kanałów, podmuch w wentylacji.
5. **Kroki-widma.** Po 1:00, w holu północnym albo w skrzydle: najpierw kilka sekund „martwej ciszy” (tło wyraźnie cichnie), potem ktoś idzie w sąsiedniej sali i staje. **Zwróć uwagę:** czy to niepokoi, ale nie myli z prawdziwym eksponatem (dźwięk jest „zza ściany”, ciemniejszy niż kroki eksponatów).
6. **Eksponat się przesuwa.** Przy śpiących eksponatach poza zasięgiem wzroku: zgrzyt kamienia (popiersia), skrzyp drewna (totemy), brzęk blach (zbroje), szelest (wosk, mumie).
7. **Cisza.** Wejdź do przystani: tło lekko cichnie, żadnych dalekich łupnięć (w kanciapie gra tylko radio). Podejdź pod arenę śpiącego strażnika: w sali obok robi się ciszej, w samej arenie wyraźnie cicho — aż się obudzi.
8. **Głos.** Gdy Heniek mówi, nic z ambientu się nie zaczyna (i 2 s po nim), tło jest przyciszone jak dotąd.
9. **Deszcz.** W noc deszczu (od nocy 2, mniej więcej co trzecia, nigdy przy blackoucie): deszcz bębni o szklany dach Dziedzińca, przytłumiony w holu wejściowym, otwarty na dachu i w ogrodzie japońskim; czasem daleki grzmot.

## 6. Do sprawdzenia w oknie (z dźwiękiem)

- [ ] Proporcja strzał / ogon w każdej z 11 przestrzeni (punkt 1 wyżej) — strojenie: `tail_db` profilu w `data/audio/acoustics.json` (bez renderu). **Ostatnie strojenie (commit WIP, nigdy nie odsłuchane): wielkie sale głośniejsze o 3–5 dB** — najpierw posłuchaj Dziedzińca (vast), holu wejściowego (hall) i galerii Egiptu (gallery): ogon ma być wyraźnie słyszalny, ale suchy strzał nadal wyraźnie pierwszy. Jeśli ogon go zagłusza albo jest „mokro jak w łazience”, wróć do poprzednich wartości (kolumna „było”) albo ustaw coś pośrodku:

  | Profil | vast | hall | gallery | room | store | corridor | library | concrete | steel | garden | open |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | `tail_db` teraz | +2 | 0 | −1 | −5 | −6 | −3 | −6 | −2 | −2 | −8 | −4 |
  | było (pierwsza wersja) | −3 | −4 | −5 | −8 | −10 | −7 | −9 | −6 | −6 | −11 | −9 |

- [ ] Ogony 3D tuż przy graczu (wybuch rakiety / łupnięcie / rozbity marmur blisko): od teraz `max_db = 0` na odtwarzaczu 3D, więc ogon nie „puchnie” z bliska ponad swój poziom. Sprawdź, czy z bliska nie brzmi za cicho albo „płasko” w porównaniu z tym samym wybuchem z drugiego końca sali (poprawka kodu: `spatial.max_db` w `Acoustics.play_tail`).
- [ ] Szczyty przy `tail_db` > 0 (vast +2): salwa z gatlinga albo hwachy w Dziedzińcu nie powinna trzeszczeć ani „pompować” reszty miksu. Szyna `SFXReturn` nie ma własnego limitera — ostatnią zaporą jest twardy limiter na Master, więc przesterowanie byłoby słychać jako ścisk całego miksu; wtedy zmniejsz `tail_db` vast/hall (o 2–3 dB).
- [ ] Seria z gatlinga i salwa hwachy w Dziedzińcu: czy ogony nie tworzą „ściany” (strojenie: odstęp `weapons.gatling`, `tail_voices`, `tail_gap`).
- [ ] Przesłanianie: czy −4 dB / 1,5 kHz za węgłem nie jest za mocne (eksponat w sąsiedniej sali musi być słyszalny jako zagrożenie). Strojenie: `occlusion` w danych.
- [ ] Dotychczasowy pogłos słuchacza na szynie SFX + nowe ogony: czy w wielkich salach nie jest „podwójnie mokro” (ew. obniżyć wet w `ReverbZone.LISTENER`).
- [ ] Szepty: czy są niezrozumiałe i niepokojące, a nie komiczne; czy nie za głośne (`db` −14).
- [ ] Radiostacja w kanciapie: czy nie myli się z krótkofalówką Heńka.
- [ ] Kroki-widma i martwa cisza: czy działają jak napięcie, a nie jak błąd dźwięku.
- [ ] Deszcz na szkle: czy nie brzmi jak szum/smażenie (zbyt gęsty) — strojenie gęstości w `ambience_story.py` (render).
- [ ] Tempo historii w pełnej nocy (21 min): czy przed świtem nie jest za gęsto razem z dalekimi dźwiękami stref.
- [ ] Zegary milknące w Sali Zegarów: czy przerwa jest czytelna (4,5 s).

## 7. Koordynacja z innymi gałęziami (tylko przez dane i sygnały)

- **Eskalacja nocy** (`night-escalation`): jeśli `Events` ma `night_phase_changed`, faza historii idzie za nim (dokładnie); bez niego — z zegara. `Events.uncanny_event` → 25 s ciszy historii (nie wchodzimy w ich moment). Ich dźwięki z `Sfx.play_at` (`weight_thud`, `glass_break`, `bust_grind`) dostają przesłanianie, a `weight_thud` i `glass_break` także ogon sali, w której zabrzmiały — „łupnięcie w sąsiedniej sali” będzie stłumione i z pogłosem tamtej sali (ciszej niż ich −4 dB w pliku: zamierzone, do odsłuchu).
- **Gun-feel**: poziom ogona idzie za głośnością strzału (`sound_db` z FeelProfile) — ich strojenie broni automatycznie stroi ogon.
- **Głos**: przyciszanie `VoiceDuck` bez zmian; historie czekają na koniec kwestii.
- `export_presets.cfg`: `include_filter` dostał `data/audio/*.json` (przy merge'u z gałęzią, która dopisała `data/night/*.json` — suma obu).

## 8. Stan prac / co dalej

**Stan na 22.10.2026 (noc, sesja bez właściciela): gotowe do merge'u do `pietro-1`, czeka na odsłuch człowieka.**

- [x] 1–9: zrobione i zacommitowane (dane, ogony, historie i deszcz, przesłanianie, ogony w grze, scheduler, StoryLayer, dokumentacja).
- [x] 10. Merge `pietro-1` (@`bebadd65`) do `audio-spaces`: **bez konfliktów** — `export_presets.cfg` już miał na `pietro-1` sumę (`include_filter="data/voice/*.json,data/night/*.json,data/audio/*.json"`), a ostatni commit tej gałęzi dotykał tylko `data/audio/acoustics.json`, `src/audio/acoustics.gd`, `docs/audio/dzwiek-przewodnik.html` i tego planu.
- [x] **Pełny zestaw headless na stanie po merge'u: 3172 passed, 0 failed**, 349 plików, jeden proces, bez linii `ERROR` i wycieków (`bash tools/run_tests.sh`, ok. 37 min przy obciążonym PC). Czerwonych testów nie było, więc przestrojenie `tail_db` i `max_db = 0` niczego nie zepsuło.
- [x] Dodany brakujący test dla `max_db = 0` (`test_room_tails.gd :: test_a_positional_tail_never_swells_up_close`): sprawdzony czerwony bez tej linii w `Acoustics.play_tail` (`max_db 3.0` = domyślny wzmacniacz bliskiego pola Godota) i zielony z nią. Ponowny pełny zestaw po dodaniu testu (stan przed tym commitem dokumentacji): **3173 passed, 0 failed**, 349 plików, bez `ERROR` i wycieków.
- [x] Testy Pythona: `cd tools/music && "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" -m unittest -v test_acoustics` (Python dołączony do Blendera, bo ma numpy) → **14/14 OK**, w tym sprawdzenia wyrenderowanych ogonów i historii (`build/audio_src/ambience/` istnieje, nic nie pominięte jako „SKIPPED”). Ogony nie wymagały ponownego renderu: `tail_db` jest stosowane w grze, nie w pliku.
- [ ] **Czego nie sprawdzono (nic nie było słuchane):** brzmienia czegokolwiek z §5 i §6. Testy dowodzą, że dźwięki są zagrane na właściwych szynach, we właściwych salach i z właściwymi poziomami z danych, ale nie że brzmią dobrze. Największa niewiadoma to ostatnie podniesienie `tail_db` o 3–5 dB (tabela „teraz / było” w §6, strojenie bez renderu: tylko `data/audio/acoustics.json`).
- [ ] **Dla właściciela:** przewodnik odsłuchu §5 (kolejność: strzał i ogon → za ścianą i cisza → historie i deszcz) i lista §6 z polami do odhaczenia. Jeśli po odsłuchu któryś ogon jest za głośny, najprostszy ruch to wrócić jego `tail_db` do wartości „było”.
- [ ] Opcjonalny pomiar kosztu na prawdziwym Piętrze I: tymczasowy test z `scratchpad/` (`test_zz_bench_acoustics.gd`) nie jest w repozytorium i nie powinien być commitowany; pomiar można powtórzyć dopiero przy odsłuchu w oknie.
- Co dalej (poza zakresem): przesłanianie pętli na własnych odtwarzaczach (rój skarabeuszy, galop kentaura), zamknięte drzwi jako mocniejsze przesłanianie (dziś: zamknięte drzwi zasłaniają promień → 1 ściana), muzyka ciszej przed strażnikiem (należy do reżysera muzyki), osobne ogony dla broni wroga.
