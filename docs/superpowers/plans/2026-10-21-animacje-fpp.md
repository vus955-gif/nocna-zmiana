# Animacje pierwszoosobowe: polish pass, clipping, oględziny po znalezieniu (21.10.2026)

> Gałąź `fp-anims` (z `pietro-1` @76bac48b). Uwagi właściciela (`docs/backlog-pietro1.md`):
> **44** — kilka bardzo krótkich animacji oglądania broni także poza ulepszeniem; bez osobnego klawisza, np. po
> pierwszym znalezieniu broni Strażnik przez sekundę ją ogląda. **45** — polish pass animacji FPP: ręce, palce, chwyt,
> przeładowanie, sprint, walka wręcz, interakcje i zmiana broni — klatka po klatce pod kątem anatomii i clippingu.
> **46** — clipping broni i rąk ze ścianami, drzwiami i obiektami, szczególnie przy dużym FOV i w sprincie/przeładowaniu.
> Zachowane bez zmian: oglądanie broni po ulepszeniu (#9, właściciel je lubi), części ulepszeń, sprężyny odrzutu
> (gun-feel), przeładowanie sztucera z łódką, test nadgarstków. Praca bez okna i bez dźwięku: wszystko sprawdzane
> liczbowo w testach headless, oględziny w oknie — lista na końcu.

## 1. Stan przed zmianą (przegląd kodu i pomiar headless)

Jak to jest złożone: `WeaponHolder` (pod kamerą) ustawia węzeł widoku broni (`REST` + bujanie przy chodzie, dryf
zmęczenia, sprężyny odrzutu, zanurzenia: zmiana broni, przeładowanie, schron, oszołomienie, sprint, lądowanie);
`ViewmodelRig` w środku animuje model (części, ramiona z łokciem, przeładowania, oglądanie po ulepszeniu).

| stan | jak było | ocena |
|---|---|---|
| zmiana broni | stara broń **znika w jednej klatce**, nowa wyskakuje 25 cm niżej i jedzie w górę liniowo 1,5 m/s (0,17 s); brak chowania, brak ciężaru (kartaczownica = pistolet) | urwane |
| spoczynek | bujanie przy chodzie, dryf/drżenie zmęczenia; stojąc w miejscu broń stoi idealnie (test tego pilnuje) | OK |
| sprint | wszystkie bronie tak samo: 3,5 cm w dół, lufa 0,2 rad w dół, przechył 0,14 | ubogie, bez różnic |
| strzał | sprężyny odrzutu per broń (gun-feel), zamek pistoletu, kurki strzelby, rygiel sztucera, korba kartaczownicy | OK |
| przeładowanie | wspólne zanurzenie 12 cm; pistolet: **nic poza zanurzeniem**; strzelba/rakietnica: łamanie z wygładzaniem wykładniczym (bez domknięcia „z nadgarstka”); sztucer: pełna animacja lewej ręki z łódką; harpunnik: harpun **wsuwa się sam**; hwacha: strzały pojawiają się w rurach; kartaczownica (zmiana taśmy 0,35 s): tylko zanurzenie | pistolet i harpunnik słabe |
| walka wręcz | lewa pięść na liniowym tweenie (0,07 s tam, 0,16 s z powrotem), obrót „w cios”; broń w ręce nie reaguje; **przy broni dwuręcznej widać dwie lewe ręce** (lewa trzyma łoże, druga lewa wyprowadza cios) | błąd anatomii |
| interakcja (E) | brak gestu | brak |
| oglądanie | tylko po ulepszeniu (1,3 s, błysk) | brak po znalezieniu |
| palce | ręce to sztywne pięści z metaball (`artlib/hands.py`), bez osobnych palców — modele nie pozwalają na pozy palców | poza zakresem (Blender) |

**Clipping — jak działa dziś (sprawdzone w źródłach Godota 4.7):** broń jest rysowana tą samą kamerą co świat, ale jej
materiały mają `fov_override = 55°` (własny kąt widzenia, niezależny od opcji FOV 70–110) i `z_clip_scale = 0,25`.
Silnik robi wtedy w shaderze wierzchołków `gl_Position.z = mix(gl_Position.w, gl_Position.z, 0,25)` (poza przebiegiem
cieni): przy odwróconym Z cała broń trafia w głębię odpowiadającą 5–6,7 cm od oka. Kapsuła strażnika ma promień 0,4 m,
więc **ściana, drzwi czy gablota nigdy nie przykryją broni** — „wchodzenia w ścianę” w sensie bufora głębi nie ma.
Zostają trzy realne problemy:
1. *Wizualny*: przy ścianie bliżej niż lufa broń jest rysowana „na” ścianie, jakby przez nią przechodziła (długie
   bronie: wylot lufy 1,06–1,83 m od oka; pistolet ~0,75 m). Przy FOV 110 obszar ekranu, na którym leży broń, pokazuje
   świat bardziej z prawej i z dołu niż przy FOV 70, więc problem zależy od FOV.
2. *Płaszczyzna bliska* (0,05 m) dalej tnie geometrię: zmierzyłem przecięcia krawędzi siatek z tą płaszczyzną —
   w spoczynku najbliższe leży **9,5× dalej niż brzeg kadru** (rękawy i kolby wychodzą za oko poza kadrem). Ryzyko
   pojawia się dopiero przy dużych pozach (sprint, uderzenie bronią, oglądanie).
3. *Anatomia/przenikanie rąk* (dwie lewe ręce przy ciosie, łokcie w kadrze przy dużych obrotach).

## 2. Projekt

Nowe małe klasy (logika testowalna bez sceny), `WeaponHolder` je składa, `ViewmodelRig` robi animacje wewnątrz modelu:

- **`ViewmodelMotion`** (statyczne dane i krzywe): klasa chwytu każdej broni — *jednoręczna* (paralizator, pistolet,
  rakietnica), *długa* (strzelba, sztucer, harpunnik), *ciężka* (hwacha, kartaczownica) — z czasami chowania/dobycia,
  pozą sprintu, pozą przy ścianie, rodzajem ciosu; krzywe kluczowane (wygładzane między kluczami).
- **`WeaponSwitch`** — automat zmiany broni: każda broń ma „opuszczenie” 0..1; chowana spada z przyspieszeniem i
  znika poza kadrem, dobywana podnosi się na sprężynie (tłumienie per klasa: lekka dobija z małym przerzutem, ciężka
  osiada). Dobycie startuje, gdy chowana zniknie. Szybka zmiana tam i z powrotem jest ciągła (wspólny stan: pozycja +
  prędkość). Strzał w trakcie zmiany ją skraca (gra nie blokuje strzału — boomer shooter ma reagować natychmiast).
- **`WallProbe`** — dwa rzuty kuli (r = 5 cm) z oka po warstwie `WORLD` (ściany, drzwi, meble): prosto przed siebie i
  w kierunku, w którym *na ekranie przy bieżącym FOV* leży wylot lufy (punkt broni przeliczony z FOV 55 na FOV kamery,
  jak `on_screen_like_the_view`). Głębokość trafienia → „przyciągnięcie” 0..1 (od progu klasy: 0,72 / 0,9 / 0,95 m do
  0,42 m), wygładzone. Poza: broń cofa się ku piersi i opuszcza lufę.
- **Gesty** (oś czasu w `WeaponHolder`): cios lewą pięścią po łuku (zamach, uderzenie z dołu po krzywej, ułamek
  sekundy w punkcie, powrót niżej) z reakcją barku broni w prawej ręce; przy broni długiej — **uderzenie bronią**
  (zamach w prawo, pchnięcie z obrotem), przy ciężkiej — pchnięcie; dzięki temu nigdy nie ma drugiej lewej ręki.
  Interakcja (E): lewa ręka sięga przed siebie (sięgnięcie, chwyt z obrotem nadgarstka, powrót); broń jednoręczna
  ustępuje miejsca, dwuręczna na chwilę schodzi z kadru (lewa ręka musi puścić łoże).
- **`FirstLook`** — oględziny po pierwszym znalezieniu: kolejka broni do obejrzenia, czeka na spokój (brak
  polujących eksponatów w promieniu 16 m i strażników w walce, 1 s od strzału, bez przeładowania, sprintu,
  oszołomienia, broń dobyta). Samo oglądanie w `ViewmodelRig` (1,2 s, dwa „takty”: lewy bok, potem przewrót na
  drugą stronę); strzał, cios, przeładowanie, sprint, zmiana broni albo polujący w pobliżu ucinają je płynnie (~0,15 s).
  *Po pomiarach:* przewrót tylko dla broni jednoręcznej; dwuręczna jest w drugim takcie obracana w poprzek (przy
  przewrocie łokieć lewej ręki wchodził w kadr), długa i ciężka oglądają 1,4 s, ucięcie puszcza pozę przez 0,3 s.
- **Wygładzanie (dodane przy uruchomieniu):** warstwy pozy (sprint, spadek przy przeładowaniu, pozy przeładowań,
  sztucer po przeładowaniu) idą na sprężynach krytycznie tłumionych (`ViewmodelMotion.follow`) zamiast wygładzania
  wykładniczego — sprężyna startuje z własną prędkością, więc nowy cel (koniec biegu, przerwane przeładowanie) nie
  szarpie w pierwszej klatce i nie ma przerzutu. Zawias strzelby/rakietnicy idzie dokładnie po kluczach (domknięcie
  zostaje szybkie), a przy przerwaniu różnica wygasa na sprężynie. Podniesienie modelu nad spadkiem uchwytu jedzie na
  tej samej sprężynie co spadek (`WeaponHolder.RELOAD_OMEGA`), więc oba znoszą się klatka w klatkę.
- **Przeładowania** (w `ViewmodelRig`, kluczowane od postępu przeładowania i wygładzane, więc przerwane wraca bez
  skoku): pistolet — przechył do środka, wyrzut magazynka (szarpnięcie w dół), dobicie nowego (podbicie), zwolnienie
  zamka gdy był pusty; strzelba i rakietnica — złamanie, wkładanie naboju (drgnięcia), domknięcie z nadgarstka (szybkie
  podbicie lufy); hwacha — drgnięcie przy każdej osadzonej strzale; kartaczownica — szarpnięcie przy wciągnięciu
  nowej taśmy.

## 3. Zadania (TDD, jeden commit na zadanie)

1. Plan (ten plik).
2. `WallProbe` + przyciąganie broni przy ścianie (FOV 70–110).
3. `WeaponSwitch`: chowanie → dobycie z ciężarem per broń.
4. Sprint per klasa chwytu (z kołysaniem w rytmie kroków).
5. Cios po łuku, uderzenie bronią długą/ciężką.
6. Gest interakcji (E).
7. Przeładowania: pistolet, strzelba, rakietnica, hwacha, kartaczownica + testy nadgarstków i ciągłości.
8. Oglądanie po pierwszym znalezieniu (`FirstLook`).
9. Przegląd całościowy: ciągłość pozy klatka po klatce, łokcie poza kadrem, płaszczyzna bliska we wszystkich stanach.
10. Merge `pietro-1`, pełny zestaw testów.

## Do sprawdzenia w oknie

**Obejrzane w oknie (noc 22/23.10, 2 krótkie przebiegi przez blokadę okna):** `bash tools/run_artint.sh --shots=fp`
łapie każdą animację w jej momencie i zamraża grę do zdjęcia (zmiana broni, sprint per chwyt, klucze przeładowań,
ciosy w punkcie trafienia, sięgnięcia, dwa takty oględzin). Po pierwszym przebiegu poprawione: pistolet w sprincie
(obrócony wokół dłoni, zamek wjeżdżał na środek kadru) i pistolet w przeładowaniu (zasłaniał celownik) — teraz nisko
i w prawo. Reszta póz czyta się dobrze: strzelba przy sięgnięciu znika z kadru (nigdy dwie lewe ręce), oględziny
kartaczownicy pokazują bok z lufami, strzelba łamie się i domyka z podbiciem. Najlepsze ujęcia:
`tests/_out/fp-anims/` (sprint pistoletu, domknięcie strzelby, sięgnięcie ze strzelbą, oględziny kartaczownicy).

**Do obejrzenia w ruchu (stopklatki nie pokazują tempa) — wszystko to dane, łatwe do cofnięcia:**
1. Tempo dobycia (`ViewmodelMotion.HANDLING`, `draw`): broń wjeżdża spod kadru w kilka klatek (przegląd mierzy do
   ok. 15 cm na klatkę) — szybka, „boomer-shooterowa” zmiana. Jeśli wygląda jak wyskakiwanie: `draw` +30–50 %.
2. Cios lewą pięścią trafia nisko (`WeaponHolder.FIST_HIT`, ok. 1/4 kadru pod celownikiem, jak przed zmianą) i
   dochodzi tam po 0,13 s (obrażenia są natychmiast przy naciśnięciu) — czy pięść ma iść bliżej celownika.
3. Domknięcie strzelby „z nadgarstka”: lufy idą na ułamek sekundy w górę przez środek kadru (`BREAK_FLICK`,
   przechył `_keyed_tilt`) — czy nie za mocno.
4. Oględziny długiej broni: drugi takt to obrót w poprzek, nie przewrót (łokieć) — czy czytelnie „druga strona”.
5. Sięgnięcie (E) z bronią dwuręczną trwa ok. 1 s (broń schodzi z kadru i wraca; strzał skraca) — czy nie za długo
   przy częstym E (drzwi, gabloty). Stałe `ViewmodelGesture.TWO_*`.
6. Wejście i wyjście ze sprintu (sprężyna 12 / 18 1/s, strzał w biegu 24 1/s, `WeaponHolder.SPRINT_OMEGA_*`) —
   czy broń wraca do walki dość szybko.
7. Kartaczownica: pchnięcie (cios) — z tyłu widać głównie tylną płytę; czy czyta się jako uderzenie.
8. Rękaw lewej ręki przy ciosie jest duży i szary (model `vm_fists`) — wygląd modelu, nie animacji.
- **Przegląd w oknie 23.10** (`2026-10-22-przeglad-w-oknie.md` §2): stopklatki po scaleniu OK; punkty o tempie (1–7) wymagają ruchu — nie oceniane.

## Stan prac / co dalej

**Gotowe (noc 22/23.10).** WIP `d3bbec98` uruchomiony, naprawiony i rozbity na commity per zadanie (historia gałęzi
przepisana lokalnie — gałąź nigdy nie była wypychana); merge `pietro-1` (@`0c4219be`), pełny zestaw zielony.

- [x] 1. Plan.
- [x] 2. `WallProbe` + przyciąganie przy ścianie — już w `pietro-1` (`47fb529c`).
- [x] 3. `WeaponSwitch` — `cb68ad7e` (z `FpCheck`). Przed nim sprężyna `ViewmodelMotion.follow` — `48de2912`.
- [x] 4. Sprint per klasa chwytu — `aabcf6f9` (na sprężynie: start/stop bez szarpnięcia).
- [x] 5.–6. Cios po łuku, uderzenie/pchnięcie, sięgnięcie (E) — `6282cf17`. Pięść porusza się najwyżej o ok. swoją
  szerokość na klatkę (próg testu 0,11 m zamiast 0,09: przy trafieniu po 0,13 s fizycznie się nie da szybciej).
- [x] 7. Przeładowania kluczowane — `6e4bc56a`. Próg ciągłości zmieniony: zamiast 0,05 m na klatkę dla wszystkiego
  — „brak skoku znikąd” (`FpCheck.spike`: krok > 2,5× sąsiednich i > 2 cm) plus limit ok. pięści na klatkę dla tego,
  co widać w kadrze (`FpCheck.moved_in_sight`; rękaw sztucera schodzący do ładownicy poza kadrem się nie liczy).
  Test zamka pistoletu czekał 1 klatkę — teraz 10 (magazynek zerowany ręcznie, nie strzałem). Sztucer: po
  przeładowaniu ręka najpierw sięga do otwartego zamka (cykl od 0,5, 1,2 s), potem zamek wraca.
- [x] 8. Oględziny po znalezieniu — `22f12924` (pozy per chwyt; dwuręczne bez przewrotu — łokieć w kadrze).
- [x] 9. Przegląd całościowy — `5424bd49` (`test_fp_review`: każda broń przez dobycie, przeładowanie, cios,
  sięgnięcie, oględziny ucięte ciosem, sprint; co klatkę skoki, łokcie, nadgarstki, co 3. klatkę płaszczyzna bliska).
  Znalazł i poprawiono: za szybkie zejście broni dwuręcznej przy sięgnięciu, za szybki zamach lufą przy uderzeniu
  sztucerem, za szybki obrót długiej lufy przy oględzinach, nieco za szybkie dobycie sztucera/harpunnika. Okno:
  `55960469` (pistolet w sprincie i w przeładowaniu).
- [x] 10. Merge `pietro-1`, pełny zestaw jednym procesem. Pierwszy przebieg (@`1a88be82`): 3219 / 2 — dwa
  czerwone od tej gałęzi, naprawione w `3c8eed3b`: `test_art_review` (chowana broń animuje się, dopóki nie zniknie
  z kadru — test czekał 1 klatkę) i `test_gun_feel` (pistolet niesiony niżej w biegu nie wracał po strzale w 12
  klatek: strzał w biegu podnosi broń szybszą sprężyną). Po merge `pietro-1` @`d1628a75`: 3222 / 0; po merge
  `pietro-1` @`0c4219be` (ostatni): **3315 / 0**, bez linii `ERROR`.

**Poprawki po przeglądzie kontrolera (23.10, noc):**
- M1 `eda6f87f` — drugie E albo cios w trakcie sięgnięcia nie wyrywa już broni: E w trakcie sięgnięcia przedłuża je
  (w drodze — leci dalej, w chwycie — dłuższy chwyt, w powrocie — ręka wraca do chwytu, broń dwuręczna w drodze w
  górę schodzi znowu od miejsca, w którym jest); cios przy wolnej ręce w sięgnięciu dwuręcznym to prosty tej ręki,
  a broń zostaje w dole, aż pięść zniknie; reszta skoków wygasa na sprężynach („carry”).
- M2 `f86d1bcb` — testy: burza zmian broni (A→B→C→A), zmiana w trakcie przeładowania; bez cichych `return`, gdy widok
  nie jest modelem.
- L1 `19845a3d` — broń, która znika z kadru, porzuca pół-pozy (przeładowanie, zawias, oględziny); przy chowaniu poza
  zostaje (rakietnica nie domyka się już w chwili schowania).
- L2 — oglądanie po ulepszeniu startuje, gdy broń jest w górze (`WeaponHolder.drawn`), nie pod kadrem. Uwaga:
  scenariusz okienkowy `visual_qa` łapie błysk po stałym czasie od dobycia — może trafić chwilę wcześniej.
- L4 — oględziny tylko dla broni nowej dla strażnika (ponowne podniesienie posiadanej: bez oględzin).
- L5, L6 `d522760f` — obrażenia (`Events.player_damaged`) i oszołomienie ucinają oględziny, nowe nie startują
  przez `QUIET_AFTER` od trafienia.
- Merge `pietro-1` @`2e59a773` (czysty); filtr testów broni/rąk/podnoszenia/obrażeń: 290 / 0.

**Co dalej:** obejrzeć w ruchu punkty z „Do sprawdzenia w oknie”; ewentualne strojenie to zmiany danych
(`ViewmodelMotion.HANDLING/SPRINT`, `ViewmodelGesture`, stałe przeładowań w `ViewmodelRig`).

**Świadomie poza zakresem:** palce (pięści to sztywne bryły metaball — wymaga Blendera); załadunek harpunu lewą ręką
(wylot ~0,3 m przed lewą dłonią, stały rękaw nie pozwala sięgnąć bez wejścia łokcia w kadr — potrzebna iteracja
w oknie; na razie harpun dosuwa się sam, z szarpnięciem „dobity na przybitce”).
