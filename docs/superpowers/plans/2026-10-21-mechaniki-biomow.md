# Mechaniki biomów — każde skrzydło gra inaczej (Piętro I)

> **Dla wykonawcy-agenta:** TDD, commit po każdej mechanice, pola `- [ ]` do odhaczania.
>
> Stan: 21 października 2026 (plan założony 21.10). Wykonawca: Claude, drzewo robocze `.claude/worktrees/close-wings`,
> gałąź `biome-mechanics` od `pietro-1` @ `6e40254`. Równolegle: `env-combat` (walka środowiskowa, #23) i
> `night-escalation` (eskalacja nocy, #34) — oba powiadomione o tym planie (wiadomość 21.10).
> Autorytet: `docs/backlog-pietro1.md` **#26** („każdy biom/epoka powinien mieć … własne mechaniki gameplayowe. Egipt może
> wykorzystywać pułapki, klątwy i sarkofagi … mechaniczne konstrukcje … przeciwników korzystających ze specyficznych
> zachowań. Chodzi o to, żeby zmiana sekcji faktycznie zmieniała sposób gry”), pomocniczo **#21** (wertykalność),
> **#38** (czytelna nawigacja), **#23** (opcjonalne, nie zastępują klasycznej walki), **#13** (Pyłu NIE zmieniać).

**Cel:** jedna mocna, czytelna mechanika na skrzydło (+ podziemia), która zmienia *czasownik* gry w tej sekcji — nie
kolejny przeciwnik ani kolejne HP. Każda: zasady, zapowiedź (≥ 0,6 s tam, gdzie zagraża graczowi), wpływ na wrogów
(ekologia/percepcja), uczciwość, koszt, brak softlocków, dlaczego to frajda.

**Zasady techniczne (wspólne):**
- Wszystko w **nowych plikach** `src/game/floor1/biomes/*`, z własnymi danymi położeń (id sal z plików stref +
  współrzędne); **żadnych edycji plików stref** (równoległe gałęzie). Haki we wspólnych plikach: jedna linia w
  `FloorGame.setup()` (instalacja), dodatkowy hak światła w `PerceptionWorld` (źródła światła spoza lamp poziomu),
  napisy w `locale/strings.csv`.
- **Żadnych nowych przeszkód na podłodze** (nic nie zmienia navmeshu ani testów kolizji/bota): urządzenia wiszą na
  ścianach, pod sufitem albo leżą płasko w posadzce; trafiane przez `Hurtbox` (warstwa HURTBOX), używane przez
  `Interactable` (warstwa INTERACT).
- Żadne urządzenie nie stoi na arenie strażnika (sala Kolosa, dziedziniec Lamassu, Partenon, Planetarium, ogród
  Generała, świątynia Węża) ani nie blokuje drogi.
- O świcie (`Events.dawn_broke`) wszystko staje. Stan „zużyty na tę noc” → `RunState.used` (zapis/wznowienie, QA #51);
  reszta to cykle czasowe, po wczytaniu startują od nowa (jak lampy i rutyny wrogów).
- W nazwach pól urządzeń **nie** używamy `state`, `active`, `is_open`, `locked`… (`Floor1WorldSnapshot.STATE`) — stan
  cykli nie może udawać „świata” w teście zapis/wczytanie.
- Dźwięki tylko z istniejących (bez nowych plików, bez odsłuchu): `harpoon_fire`, `lock_bolt_slide`, `gate_jam`,
  `witching_bell`, `orrery_gears`, `lock_rope_snap`, `flare_burn`, `lamassu_gust`, `rubble`, `dust`…
- Koszt klatki: urządzenia tykają ≤ 10 Hz i tylko przy strażniku (≤ ~40 m); przegląd wrogów przez
  `PerceptionWorld.exhibits()`.

---

## Przegląd skrzydeł (stan przed pracą, 21.10)

| Skrzydło | Sale (bez areny) | Wrogowie | Strażnik / arena | Co już jest w przestrzeni |
|---|---|---|---|---|
| Egipt | przedsionek, Wielka Galeria, korytarz grobowców, komory grobowe, sala sarkofagów, schody służbowe | mumie (wosk→mumia), skarabeusze, „archeolodzy” (wosk) | Kolos / sala Kolosa | najciemniejsze, niskie grobowce z pochodniami; zasadzki przy sarkofagach |
| Asyria | brama Chorsabadu, Balawat, galeria Nimrud, Sala Łowów (dół −3 m + galeria), biblioteka, schody towarowe | wojownicy i lwy z reliefów (wychodzą ze ścian, wędrują w nich) | Lamassu / dziedziniec | wysokie sale, dół pod galerią (jedyna sala dwupoziomowa) |
| Grecja | Nereidy (podium + balkon), Bassae (antresola), wazy, metopy, magazyn odlewów (schron) | hoplici (tarcze, linia), popiersia (dystans, wsparcie) | Centaur / Partenon | najjaśniejsze, srebrny księżyc, pionowa pętla |
| Oświecenie | Biblioteka Królewska (galeria y 4), gabinet, zegary, portrety, schody | księgi, wilki, raptory, automaty, portrety | Wielkie Planetarium | sala zegarów z zegarem astronomicznym pośrodku |
| Azja | Chiny (Budda, 12 m), porcelana, Korea (pawilon dzwonu!), zbrojownia | psy Fu (brąz, szarża), zbroje samurajów | Generał / ogród | dzwon w pawilonie Korei (model `temple_bell`), lampiony |
| Ameryki | sala północna, sala totemów, Moai, Pacyfik, dół | totemy (wieżyczki), jaguary (flankujący) | Wąż / świątynia | misy ogniowe (`brazier`) — ogień z dołu |
| Podziemia | pierścień korytarzy, tunel, kotłownia, skrzyżowanie, magazyny | „uciekinierzy” ze skrzydeł | — | rury w kolorach skrzydeł, para w kotłowni (art) |
| Dach | kładki nad kopułą | 1 przeciwnik | — | wiatr (ambient) |

---

## Mechaniki (projekt)

Czasowniki: **Egipt — patrz pod nogi** · **Asyria — sieć z góry** · **Grecja — celuj światłem** · **Oświecenie — graj
w takt** · **Azja — wabienie dźwiękiem** · **Ameryki — ciemność przeciw wzrokowi** · **Podziemia — wyczucie cyklu
i zawory**. Żadne dwa nie robią tego samego.

### 1. Egipt — „Płyty klątwy” (pułapki grobowców)

- **Zasady:** w posadzce grobowców (korytarz grobowców, komory, sala sarkofagów ×2 — 4 pułapki) leżą płyty z kartuszem.
  Wejście na płytę (strażnik albo chodzący eksponat) → płyta opada z kliknięciem, z „pysków” (szczelin z głową
  szakala) w ścianie sypie się kurz, po **0,7 s** salwa strzałek leci wzdłuż linii (pas 0,9 m szerokości, 0,2–1,9 m
  wysokości) przez całą salę. Każdy na linii: strażnik **12**, eksponat **35** (+ zachwianie). Płyta wraca po **4 s**.
- **Zapowiedź:** płyty jaśniejsze od posadzki, wypukłe, z ciemną szczeliną dookoła i złotym kartuszem; pyski w ścianie
  wskazują linię; klik + zgrzyt + kurz z pysków 0,7 s przed salwą.
- **Wrogowie:** mumie i woskowi archeolodzy uruchamiają płyty, gdy idą zaalarmowani (śpiący, na obchodzie i wracający
  „znają swój grobowiec”); skarabeusze, księgi, popiersia i portrety są za lekkie. Salwa to hałas (10 m, `trap`): budzi śpiące w sarkofagach — „klątwa budzi umarłych”.
  Gracz może wciągnąć mumię na linię.
- **Uczciwość:** linia i płyty widoczne; 0,7 s na zejście z linii; obrażenia niskie; nic nie blokuje drogi; żadnej
  płyty w progu schronu konserwatora ani na trasie patrolu.
- **Frajda:** w najciemniejszej części gry nagle liczy się posadzka; grobowiec walczy po stronie tego, kto go zna.

### 2. Asyria — „Sieci łowów” (łowy Aszurbanipala)

- **Zasady:** pod stropem wiszą zwinięte sieci myśliwskie na linie (rekonstrukcja z reliefów łowów); strzał w linę
  (każda broń) zrzuca sieć: spada w **0,45 s**, przykrywa koło **r 2,6 m**. Eksponat pod nią jest **spętany 4 s**
  (nie idzie, nie atakuje, nie wsiąka w ścianę, lew nie skacze), potem rwie sieć. Strażnik pod nią: spowolnienie 0,45
  na 1,5 s. Każda sieć raz na noc (`RunState.used`, „net_<id>”), ~8 sieci. (Po przeglądzie: spętany bywa tylko
  eksponat, który już coś zauważył — śpiącego i spokojnie chodzącego sieć nie budzi, bo ogłuszenie kończy się polowaniem.)
- **Gdzie:** trzy nad dołem Sali Łowów (strzał z galerii w dół — **#21**), dwie nad nawami Nimrud, po jednej w bramie
  Chorsabadu (nad strefą zasadzki), w Balawat i w bibliotece.
- **Zapowiedź:** zwój sieci z ciężarkami i jasną liną pod lampą; zrzut jest decyzją gracza; spętani szarpią się w
  sieci.
- **Wrogowie:** odpowiedź na ich własne zachowania — wojownik uskakuje przed celowaniem i wsiąka w ściany, lew skacze;
  sieć to zatrzymuje. Spętany = ogłuszony (wykończenie pięścią możliwe).
- **Uczciwość:** sieć nie blokuje przejścia (podarta leży jako dekoracja bez kolizji); zasób ograniczony.
- **Frajda:** łowca z galerii nad dołem lwów; jeden dobry strzał zamienia chaos w egzekucję.

### 3. Grecja — „Lustra Heliosa” (lampa łukowa fotografa)

- **Zasady:** na balkonie sali Nereid wisi lampa łukowa (fotografowie marmurów nocą, lata 1890.); dźwignia (E) zapala
  ją na **20 s** (potem węgle się wypalają, **12 s** stygnięcia). Jej biały promień „światła dnia” odbija się od
  brązowych luster na ścianach (greckie lustra z brązu); lustro obraca się (E albo strzał w obręcz) do następnej z 3
  pozycji: promień przecina wtedy inne przejście (drzwi do Bassae, do waz, do metop, środek sali).
- **Wrogowie w promieniu:** „świt w wiązce” — marmur sztywnieje: spowolnienie ×0,4 i spalanie **14/s** (okresowe,
  bez bloku tarczą). **Strażnik w promieniu** jest jasno oświetlony (wrogowie widzą go z daleka) — to koszt.
- **Zapowiedź:** biała wiązka z pyłem w świetle, iskry na trafionych, buczenie lampy, migotanie przed wypaleniem
  (ostatnie 2 s).
- **Uczciwość:** strażnikowi nic nie robi poza oświetleniem; lampa i lustra na ścianach/balkonie (bez kolizji).
- **Frajda:** zagadka-taktyka w biegu: ustaw lustro na drzwi, z których idzie linia hoplitów, i patrz, jak brną w
  świetle; korzysta z pionu sali (balkon → podłoga).

### 4. Oświecenie — „Regulator” (takt zegara)

- **Zasady:** regulator (zegar precyzyjny w mahoniowej szafce na zachodniej ścianie sali zegarów) trzyma czas skrzydła.
  Co **18 s** (12 s u szczytu nocy — `intensity`) wybija takt: **zapowiedź 1,0 s** (warkot mechanizmu słyszany w całym
  skrzydle, młoteczek się unosi, eksponaty, które trzyma, błyskają mosiądzem), potem **„tik”**: każdy eksponat skrzydła
  **walczący ze strażnikiem** (poluje albo atakuje, ≤ 40 m od niego) staje na **1,0 s**, a po nim **„tak”**: przez
  **2,5 s** jest szybszy ×1,35. Strzał w szybkę szafki zatrzymuje wahadło: takt milknie na **60 s**, ostatnie 2 s
  mechanizm sam się nakręca (warkot).
- **Wrogowie:** rytm dotyczy walczących w salach skrzydła (poza Planetarium); śpiących, ciekawskich i szukających nie
  rusza (ogłuszenie zmieniłoby ich w polujących).
- **Uczciwość:** zawsze ta sama, słyszalna i widoczna zapowiedź; przyspieszenie krótkie; można je wyłączyć.
- **Frajda:** walka „w takt”: okno na celny strzał/wykończenie w „tik”, odskok przed „tak”; mechanizm jako żywa
  maszyneria skrzydła.

### 5. Azja — „Dzwony świątynne” (wabienie dźwiękiem)

- **Zasady:** brązowe dzwony wiszą w salach (pawilon dzwonu w Korei — istniejący model z oprawy; dodatkowe w sali Chin
  i w zbrojowni: dzwon z modelu `temple_bell` na łańcuchu, wysoko, z liną do uchwytu, bez kolizji). Strzał w dzwon albo pociągnięcie linki (E) → dzwon bije:
  **głośny hałas 26 m w miejscu dzwonu** — eksponaty Azji w zasięgu słuchu idą do dzwonu (bez limitu badających:
  dzwon jest święty dla psów Fu), inne jak zwykły hałas; **rezonans**: każdy **obudzony** w promieniu **4 m** od dzwonu w
  chwili uderzenia jest **oszołomiony 1,8 s**. Dzwon kołysze się i brzmi 4 s, znów można uderzyć po **6 s**.
- **Zapowiedź:** dla gracza akcja jest natychmiastowa; wrogowie odwracają głowy ku dzwonowi; fale dźwięku (pierścienie)
  i kołysanie dzwonu.
- **Uczciwość:** strażnik bijący dzwon z bliska dostaje tylko wstrząs kamery; nic nie blokuje.
- **Frajda:** skradanie i kontrola tłumu: odciągnij parę psów Fu od drzwi, zbierz ich pod dzwonem i uderz drugi raz.

### 6. Ameryki — „Święty ogień” (oczy totemów)

- **Zasady:** **totemy widzą strażnika tylko w blasku ognia** (mis ogniowych i pochodni w ich sali) albo gdy świeci
  latarką. Istniejące misy (`brazier`: sala północna ×2, sala totemów ×2, Pacyfik ×1; świątynia Węża — nie) można
  zgasić strzałem: misa się przechyla, ogień gaśnie w dymie (światło, płomień, iskry i dym znikają), sala ciemnieje.
  Misa sama rozpala się po **40 s** (zapowiedź: żar migocze 2 s); raca w promieniu 1,5 m rozpala ją od razu.
- **Wrogowie:** totem poza blaskiem ognia jest ślepy dalej niż na zmysł bliski; jaguary widzą normalnie (polują
  nosem i oczami) — ciemność chroni przed wieżyczkami, ale flankujący są trudniejsi do zobaczenia.
- **Uczciwość:** ogień = widać cię (to już zasada gry: „latarka = jesteś widoczny”); misy zawsze wracają.
- **Frajda:** wybór ciemność czy walka w świetle; latarka znów jest decyzją.

### 7. Podziemia — „Para” (zawory)

- **Zasady:** na rurach pierścienia i tunelu pęknięte zawory co **14 s** wyrzucają parę na **2,5 s** (zapowiedź
  **1,0 s**: syk narasta, wskazówka manometru w czerwone, pierwsze dmuchnięcia). Słup pary w poprzek korytarza parzy:
  strażnik **10/s**, eksponat **zaalarmowany** **16/s** (+ w parze nie widzi; „uciekinierzy” w spoczynku znają rytm
  piwnicy i w parę nie wchodzą). Cykl 14 s (10 s u szczytu nocy). Koło zaworu na ścianie (E) zakręca
  odcinek na **45 s**.
- **Wrogowie:** wchodzą w parę jak w każdą przeszkodę (nie omijają) — wciągnij je; para zasłania im wzrok.
- **Uczciwość:** cykl stały i słyszalny; obrażenia ograniczone; pierścień ma obejścia; nic nie blokuje.
- **Frajda:** skróty piwnicy dostają rytm i decyzję: czekać, zakręcić, czy przebiec.

### Dach — odłożone (uzasadnienie)

Wiatr na kładkach (pchanie) nie zmienia gry: balustrady i szklany dach bez upadków (projekt) odbierają mu stawkę, a
problemem dachu jest **brak treści** (W7: 3570 m², 1 przeciwnik), nie brak mechaniki. Wraca przy przebudowie dachu.

---

## Architektura

- `BiomeMechanics` (`src/game/floor1/biomes/biome_mechanics.gd`): instalowany przez `FloorGame.setup()`
  (`biomes = BiomeMechanics.install(self)` — jedna linia + pole `biomes`), w testach `setup(level, guard_source, run,
  hud)` na gołym `MuseumFloorLevel`. Buduje urządzenia każdego skrzydła z ich danych (`PLACES` / `INSTALLATIONS`,
  ognie Ameryk — z mis `brazier` układu), trzyma listę, zatrzymuje je o świcie (`Events.dawn_broke`), daje
  `intensity` (0..1, dla eskalacji nocy) i podpowiedzi raz na zawsze (niżej).
- `BiomeDevice` (baza): `host`, `room`, `device_id`, `frozen`, `freeze()`, `guard()`.
- Urządzenia: `TombTrap` (Egipt), `HuntingNet` (Asyria), `HeliosLamp` + `BronzeMirror` (Grecja), `Regulator`
  (Oświecenie), `TempleBell` (Azja), `SacredFire` + `TotemSight` (Ameryki), `SteamVent` (podziemia).
- Hak światła: `PerceptionWorld.light_sources: Array[Callable]` — `(point) -> float` dodawane w `light_at()`,
  czyszczone w `reset()` (wiązka Heliosa oświetla strażnika).
- Spowolnienie / przyspieszenie / oślepienie wrogów bez zmian w klasach wrogów: urządzenie wkłada **czynnik** do
  wspólnej tabeli na eksponacie (`ExhibitMods`, meta `biome_mods`; tempo = iloczyn czynników, wzrok = najostrzejsze
  ograniczenie, klucz = id urządzenia) i zdejmuje go, gdy efekt mija (albo urządzenie znika). `move_speed` /
  `sight_range` zmieniają się tylko o stosunek efektu przed i po, więc żaden efekt nie kasuje cudzego (mnożnik
  godziny duchów ×1,2 przeżywa regulator, wiązkę, parę i wzrok totemów w dowolnej kolejności). Wcześniej meta
  trzymały wartości bezwzględne (`helios_speed`, `regulator_speed`, `steam_sight_range`, `biome_sight_range`).
- Podpowiedź raz na zawsze: pierwszy raz w sali, gdzie działa mechanika skrzydła (regulator: całe Oświecenie), jedna
  krótka linijka na HUD (`HINT_BIOME_<SKRZYDŁO>`, flaga `hint_biome_<skrzydło>` w `GameState`).

## Zadania

- [x] 0. Przegląd skrzydeł, projekt, ten plan.
- [x] 1. Szkielet `BiomeMechanics` + hak w `FloorGame` + test instalacji na piętrze.
- [x] 2. Egipt — płyty klątwy.
- [x] 3. Azja — dzwony.
- [x] 4. Ameryki — święty ogień.
- [x] 5. Grecja — lustra Heliosa (+ hak światła).
- [x] 6. Oświecenie — regulator.
- [x] 7. Asyria — sieci.
- [x] 8. Podziemia — para.
- [x] 8a. Oprawa: dzwony z modelu `temple_bell` (sam dzwon), misy Ameryk z własnym płomieniem, iskrami i dymem
  (test na ubranym piętrze); podpowiedzi raz na zawsze.
- [x] 9. `git merge pietro-1`, pełny zestaw, raport.

## Tabela: skrzydło → mechanika → zapowiedź → test

| Skrzydło | Mechanika (gdzie) | Zapowiedź / czytelność | Wpływ na wrogów | Testy |
|---|---|---|---|---|
| Egipt | Płyty klątwy: płyta → salwa strzałek z „pyska” w ścianie (korytarz grobowców, komory, sala sarkofagów ×2) | płyta jaśniejsza, wypukła, złoty kartusz; pysk z trzema szczelinami wskazuje linię; klik + kurz **0,7 s** | zaalarmowani chodzący naciskają płytę; salwa 40 dla eksponatu, 12 dla strażnika; hałas 10 m (`trap`) budzi sarkofagi | `test_biome_egypt` (8), `test_biome_places`, `test_biome_floor` |
| Asyria | Sieci łowów: strzał w zwój → sieć spada na koło r 2,6 m (dół Sali Łowów ×3, Nimrud ×2, brama, Balawat, biblioteka) | zwój z ciężarkami i jasnym węzłem pod sufitem; spętani szarpią się; raz na noc | spętanie 4 s (bez kroku, ataku, ściany, skoku); strażnik pod siecią — potknięcie | `test_biome_assyria` (5), `test_biome_places`, `test_biome_floor` |
| Grecja | Lustra Heliosa: lampa łukowa na balkonie sali Nereid (E) + 2 lustra po 3 znaki | biała wiązka z poświatą; lustro błyska; lampa migocze **2 s** przed wypaleniem; 12 s stygnięcia | w wiązce ×0,4 tempa i 14/s ognia (bez bloku tarczą); strażnik w wiązce w pełni oświetlony | `test_biome_greece` (6), `test_biome_places`, `test_biome_floor` |
| Oświecenie | Regulator: takt co 18 s → „tik” (stop 1 s), „tak” (×1,35 przez 2,5 s); strzał w szybkę — cisza 60 s | warkot w całym skrzydle i mosiężny błysk na trzymanych **1,0 s** przed; młoteczek; dzwonek | tylko walczący (poluje/atakuje); Planetarium bez rytmu | `test_biome_enlightenment` (4), `test_biome_places`, `test_biome_floor` |
| Azja | Dzwony świątynne: strzał / lina (E) → dzwon bije (Chiny, zbrojownia, pawilon Korei) | kołysanie, fale dźwięku, wrogowie odwracają się ku dzwonowi | hałas 26 m w miejscu dzwonu; psy Fu zawsze idą do dzwonu; obudzeni ≤ 4 m oszołomieni 1,8 s; 6 s do kolejnego | `test_biome_asia` (6), `test_biome_places`, `test_biome_floor`, `test_biome_art` |
| Ameryki | Święty ogień: strzał gasi misę (sala północna ×2, totemów ×2, Pacyfik), wraca po 40 s, raca / ogień zapala od razu | płomień, iskry i dym znikają; żar migocze **2 s** przed powrotem | totemy widzą strażnika tylko w blasku ognia albo latarki (inaczej ślepe dalej niż 2,5 m); jaguary bez zmian | `test_biome_americas` (6), `test_biome_places`, `test_biome_floor`, `test_biome_art` |
| Podziemia | Para: 6 pękniętych rur (pierścień ×5, tunel) co 14 s; koło na ścianie zakręca na 45 s | syk i manometr w czerwonym polu **1,0 s** przed; słup pary przez korytarz | zaalarmowani 16/s i ślepi w parze; spoczywający nie wchodzą | `test_biome_basement` (6), `test_biome_places`, `test_biome_floor` |
| Dach | odłożone (uzasadnienie wyżej) | — | — | — |

Wspólne: `test_biome_floor` (instalacja w grze, każda mechanika na prawdziwych ścianach, podpowiedzi raz na zawsze w
obu językach), `test_biome_art` (ubrane piętro), `test_biome_places` (dane położeń kontra układ piętra).

## Poprawki po przeglądzie

> Wykonawca nocny, 22.10: gałąź `fix-biome` od `pietro-1` @ `bebadd6` (to samo drzewo `close-wings`). TDD, commit na
> poprawkę. Poza zakresem: `LayoutIllumination`, pliki `src/**/env*`, logika `SacredFire` (zapalanie / gaszenie) — tam
> pracuje `fix-env`.

| # | Poprawka | Stan |
|---|---|---|
| 1 | Przywracanie tempa / wzroku zapisywało **bezwzględne** wartości (regulator, Helios, para, wzrok totemów) i kasowało mnożnik godziny duchów ×1,2 (i każdy modyfikator nałożony w międzyczasie). Teraz każdy efekt jest czynnikiem mnożnikowym we wspólnym małym stosie na eksponacie (`ExhibitMods`: tempo = iloczyn czynników, wzrok = najostrzejsze ograniczenie), nakładanym i zdejmowanym niezależnie od kolejności. Testy: `test_biome_modifiers` (11; kolejność „godzina duchów przed / w trakcie” dla regulatora i wiązki, wzrok pary i totemów, sama tabela). | **zrobione** |
| 2 | Sieć Asyrii i rezonans dzwonu Azji ogłuszały **śpiących i spokojnie chodzących** (ogłuszenie kończy się polowaniem — budziło ich). Ogłuszenie dotyka tylko tych, którzy już coś zauważyli (`EnemyBrain.is_alerted()` bez ucieczki); dzwon decyduje o tym **przed** własnym hałasem (hałas dzwonu sam budzi śpiących w pobliżu — nie mogą być za to oszołomieni). `BiomeMechanics.stunnable`. Testy: `test_biome_assyria` (+1), `test_biome_asia` (+2). Regulator bez zmian (rusza tylko polujących). | **zrobione** |
| 3 | Tyknięcia ognia wiązki Heliosa (co 0,1 s) przechodziły przez zwykłe `take_damage` → `_alarm`: budziły śpiących i podawały polującym pozycję strażnika przy każdym tyknięciu. Tyknięcie parzy i tyle (`DamageInfo.silent`, honorowane w `Enemy.take_damage`); to samo dla pary (tyknięcie co 0,25 s). Skutek: śpiący w wiązce płonie, ale się nie budzi (projekt nic nie mówi o budzeniu), polujący nie dostaje nowej pozycji strażnika. Testy: `test_biome_greece` (+1, liczy zdarzenia mózgu), `test_biome_basement` (+1). | **zrobione** |
| 4 | Wabienie psów Fu przez dzwon liczyło odległość w linii prostej (26 m) przez ściany. Teraz ten sam słuch co zwykły hałas (`PerceptionWorld.hears`: pokoje, otwarte przejścia, tłumienie; `noise()` używa tych samych dwóch pomocniczych funkcji). Testy: `test_biome_asia` (+1: sąsiednie pomieszczenie słyszy, dwa pomieszczenia dalej i za zamkniętymi drzwiami nie), `test_perception_hears` (3). | **zrobione** |
| 5 | Para parzyła strażnika co 0,25 s ze stałym dźwiękiem `hurt` i wstrząsem kamery przy każdym tyknięciu (spam). Obrażenia bez zmian (10/s); dźwięk, wstrząs i błysk co najwyżej raz na sekundę dla tyknięć okresowych (`Player.take_damage`, `PERIODIC_CUE_GAP` = 1 s; pierwsze tyknięcie krzyczy od razu, zwykłe uderzenie zawsze). Testy: `test_player_periodic` (3), `test_biome_basement` (+1). | **zrobione** |
| 6 | Luki w testach: `PerceptionWorld.light_sources` (reset, rejestracja i wyrejestrowanie lampy, ponowny zapis po resecie), plus testy wynikające z 1 i 2 (`test_biome_modifiers`, nowe przypadki w `test_biome_asia` / `test_biome_assyria`). Nowy `test_biome_light_sources` (4): jedno źródło na lampę i zdjęte, gdy lampa znika (przebudowana noc nie ma starego), ciemno przy zgaszonej lampie i po świcie, reset świata czyści wszystko, a lampa, która reset przeżyła, rejestruje się znów przy zapaleniu (`HeliosLamp._register_light`, jedyna zmiana w kodzie). | **zrobione** |

**Druga fala (przegląd kontrolera, 23.10):**

| # | Poprawka | Stan |
|---|---|---|
| R1 | Sieć nadal chwytała śpiących, których obudził sam strzał tnący linę: `WeaponHolder` woła `take_damage` (zrzut), a dopiero potem `Events.weapon_fired` → `PerceptionWorld.noise()` budzi śpiących w tej samej klatce, a „obudzony” liczono dopiero przy lądowaniu (0,45 s później). Teraz `HuntingNet.drop()` zapisuje, kto był obudzony **w chwili cięcia** (`_awake_at_cut`, w promieniu koła + `CUT_REACH` 4 m, bo polujący może wbiec pod spadającą sieć), a `_land()` chwyta tylko ich. Test: `test_biome_assyria` (+1, po `_shot()` leci `Events.weapon_fired`). | **zrobione** |
| R2 | Bramkowanie krzyku `Player.take_damage` ukrywało obrażenia przed słuchaczami `player_damaged` (bot przejścia sumuje `amount` i wykrywa `killing_blow`). Teraz połknięte tyknięcia sumują się w `_cue_pending` i wychodzą razem z następnym krzykiem (`amount + pending`); tyknięcie, które zabija (`amount >= health`), krzyczy zawsze. Test `test_player_periodic` bierze `Engine.physics_ticks_per_second` (+2 testy: suma krzyków = obrażenia, śmiertelne tyknięcie). Uwaga: bot liczy `killing_blow` jako `health.current - amount <= 0` w chwili sygnału, a połknięte tyknięcia są już odjęte od zdrowia — przy bardzo niskim zdrowiu w parze może więc zgłosić cios śmiertelny o jeden krzyk wcześniej (to tylko notatka w raporcie bota). | **zrobione** |
| R3 | Klucz czynnika w `ExhibitMods` to id urządzenia: dwa **takie same** urządzenia na jednym eksponacie pomnożyłyby tempo (0,4 × 0,4). Nieosiągalne dziś (jedna lampa, jeden regulator); klucz „po rodzaju” byłby gorszy (zdjęcie przez jedno kasowałoby efekt drugiego), więc zostaje klucz urządzenia — **zasada: nie stawiać drugiej lampy Heliosa ani drugiego regulatora w tym samym skrzydle bez przemyślenia nakładania**. | **zrobione** (notatka) |
| R4 | `BiomeMechanics.stunnable` powtarzało listę stanów z `EnemyBrain.is_alerted()` (minus ucieczka) — teraz wprost `is_alerted() and state != FLEE`, żeby nowy stan nie rozjechał obu list. Usunięte zbłąkane tabulatory w `biome_mechanics.gd` i `temple_bell.gd`. Testy bez zmian (zachowanie to samo). | **zrobione** |
| R5 | Notatka: `portrait.gd` `_push_out` zapisuje `sight_range` bezwzględnie (`AWAKE_SIGHT`). Żadne urządzenie nie przycina wzroku portretów (para i totemy działają na inne rodzaje), więc dziś bez skutku; gdyby jakieś miało, ten zapis skasowałby przycięcie — wtedy zamienić na mnożenie. | **zrobione** (notatka) |

**Decyzje (22.10, noc, bez pytań do właściciela; wartości balansu bez zmian):**
- *Czynniki zamiast kopii wartości:* tempo jest iloczynem czynników, wzrok — najostrzejszym ograniczeniem (dwie rzeczy
  oślepiające naraz nie oślepiają bardziej niż gorsza z nich); klucz czynnika to id urządzenia, więc dwie pary na tym
  samym eksponacie nie zdejmują sobie nawzajem efektu. Nic w klasach wrogów się nie zmieniło.
- *Kto jest „obudzony” dla ogłuszenia:* tylko ten, kto już coś zauważył (podejrzliwy, sprawdzający, polujący, szukający,
  atakujący); śpiący, spokojny patrol, powrót do domu i ucieczka przed wybuchem zostają, jak były (ogłuszenie kończy się
  polowaniem). Konsekwencja dla gracza: sieć nad śpiącym lwem jest zmarnowana (zrzut jest raz na noc) — zrzucać na tych,
  którzy już biegną.
- *Wiązka i para nie budzą:* tyknięcia są ciche (`DamageInfo.silent`), więc śpiący w wiązce płonie bez budzenia się, a
  polujący nie dostaje od niej pozycji strażnika. Jeśli właściciel woli jednorazowe obudzenie przy pierwszym dotknięciu
  wiązki, to jedna linia w `HeliosLamp._stiffen` (nowy wpis w `_stiff`); projekt tego nie opisuje, więc nie dodane.
- *Para ma ten sam „cichy” znacznik co wiązka* (poza zakresem listy, ale ta sama wada: tyknięcie co 0,25 s alarmowało
  szukających i sprawdzających).
- *Dzwon a słuch:* wabik psów Fu liczy ten sam słuch co zwykły hałas, mierzony od środka dzwonu (jak `Events.noise_made`);
  zwykły hałas dzwonu i tak działa na wszystkich wokół — zmieniło się tylko „święte” obejście limitu badających, które
  przestało przechodzić przez ściany.
- *Wstrząs i dźwięk pary:* tyknięcie okresowe krzyczy najwyżej raz na sekundę (pierwsze od razu). Dotyczy też innych
  źródeł tyknięć okresowych na strażniku (dziś tylko para).

## Do sprawdzenia w oknie

1. **Egipt:** płyty (2 cm nad posadzką, szczelina, złoty kartusz) i „pyski” (ramka 0,72 × 1,62 m, trzy szczeliny,
   złota belka) na tle ubranych ścian grobowców — czy nie gryzą się z cokołem i fryzem (z-fighting), czy płyty są
   czytelne w półmroku pochodni; smugi strzałek (`Fx.tracer`) i kurz zapowiedzi.
2. **Asyria:** zwoje sieci pod sufitem (wysokość, czy z galerii Sali Łowów widać jasny węzeł), siatka na ziemi
   (tekstura z przezroczystością, „namiot” nad spętanymi, potem płasko), czy nie przenika przez rydwan i płyty w dole.
3. **Grecja:** lampa łukowa na ścianie nad balkonem (bryła, dźwignia pod ręką z balkonu), wiązka (addytywny walec
   r 0,11 + poświaty), obrót lustra (tarcza kręci się w czasie obrotu i „przeskakuje” na nowy kąt), migotanie przy
   wypalaniu; czy wiązka nie wygląda jak laser science fiction (może potrzebny pył w świetle albo miększy stożek).
4. **Oświecenie:** szafka regulatora na zachodniej ścianie sali zegarów (proporcje, tarcza, wahadło za szybą, dzwonek
   i młoteczek); mosiężny błysk na wrogach przed taktem — czy czytelny w walce w bibliotece.
5. **Azja:** dzwony z modelu w sali Chin i w zbrojowni (wysokość, łańcuch, lina z uchwytem), kołysanie pawilonu Korei
   po uderzeniu, fale dźwięku (pierścienie) — czy nie za bardzo „interfejsowe”.
6. **Ameryki:** zgaszona misa (żar, dym), migotanie przed powrotem; czy sala realnie ciemnieje (lampy recepty mogą
   nadal oświetlać miejsce misy — wtedy reguła „ciemno = ślepe totemy” jest nieczytelna na oko).
7. **Podziemia:** strumienie pary (2 emitery: przy rurze 2,95 m i nisko 1,2 m) — czy słup pary zasłania korytarz
   tak, jak działa (±1 m wzdłuż ściany); manometr i koło zaworu.
8. **Dźwięki** (bez odsłuchu tej nocy): klik płyty (`lock_bolt_slide` 0,6), salwa (`shard_fire` 1,35), dzwon
   (`witching_bell` 0,72 / 0,85 — czy nie myli się z dzwonem godziny 3:00?), regulator (`orrery_gears` 1,8,
   `witching_bell` 1,6), lampa (`relay`, `lock_power_on`, `power_dead`), sieć (`lock_rope_snap`, `break_linen`),
   para (`flare_burn`, `lamassu_gust`).
9. Podpowiedzi HUD (długość linii w obu językach, czy nie nakładają się na podpowiedzi nocy 1).
- **Przegląd w oknie 23.10** (`2026-10-22-przeglad-w-oknie.md` §2): wiązka Heliosa czyta się jak laser, fale dzwonu dość „interfejsowe”, zgaszona misa OK; płyty, sieci i regulator nie ocenione (ciemno / kamera).

## Stan prac / co dalej

21.10: wszystkie 7 mechanik (Egipt, Asyria, Grecja, Oświecenie, Azja, Ameryki, podziemia) zrobione TDD, commit na
mechanikę; podpowiedzi raz na zawsze; test na ubranym piętrze. Dach odłożony (uzasadnienie wyżej).

**Odporność ognia na zasilanie (prośba kontrolera, 21.10):** zgaszenie misy nie dotyka już widoczności lampy, płomienia
ani iskier (to kanał zaciemnień, przerw w zasilaniu i „ciemnych sal” eskalacji), tylko energii lampy, przezroczystości
płomienia i `amount_ratio` iskier; przerwa w zasilaniu nie rozpala zgaszonej misy, misa rozpalona w ciemności czeka na
prąd, a misa bez zasilania nie daje totemom światła (`SacredFire.glowing()`). Testy:
`test_a_blackout_neither_relights_a_doused_bowl_nor_is_fought`, `test_the_totems_see_by_a_bowl_only_while_it_has_fire_and_power`.

**Do spięcia po scaleniu gałęzi równoległych:**
- `night-escalation` (jeszcze nie w `pietro-1` przy ostatnim scaleniu): w `UncannyDirector._tick`, odpornie na brak
  węzła: `var b: Variant = floor_game.get("biomes"); if b != null: b.intensity = NightEscalation.intensity(float(clock.call()))`
  (regulator i para przyspieszają); `floor_game.gd` skonfliktuje się na dwóch sąsiednich liniach `var` — zostawić obie.
- `env-combat`: jego `LayoutIllumination.put_out(position)` może dodatkowo przyciemniać zgaszone misy Ameryk w modelu
  światła wrogów (dziś gaśnie lampa, płomień i iskry; reguła totemów liczy własny „blask ognia”). Jego `put_out`
  jest jednokierunkowe (na całą noc): misa, która znów się pali, potrzebuje obok `put_back(position)`; nie ustawiamy
  meta `env_broken` na misach (wtedy `NightModifiers.set_lights` by je pomijał). Uzgodnione
  rozmieszczenie: sieci w Nimrud ≥ 10 m od jego dźwigu (x < −92), żadnych czerwonych pierścieni ani etykiet na moich
  celach (to jego język „usterki”), on nie dotyka dzwonów ani mis.

**Pomysły na dalej (nie w tej gałęzi):** papierowe ściany shoji w Azji (cień przez papier, przestrzał); drugi
zestaw luster w sali Bassae albo metop; widoczny znak ślepoty totemu (przygaszone oczy — wymaga zmiany `Totem`).
