# Poprawki modeli pierwszoosobowych: anatomia rąk i przeładowanie sztucera (10.10.2026)

> Gałąź `fix-viewmodel` (z `pietro-1`). Uwagi właściciela z testu 3.10 (`docs/backlog-pietro1.md`): **1** — przy broniach
> długich lewa ręka pod lufą „wygięta jak złamana"; **3** — łódka sztucera lewituje, nie wkłada jej żadna ręka.
> Zachowane: **9** — animacja oglądania broni po ulepszeniu (nietknięta, test `test_weapon_look_rig` dalej zielony).
> Praca bez okna i bez dźwięku: zmiany sprawdzone liczbowo (testy headless), oględziny w oknie poniżej.

## Przyczyna (zmierzona, nie zgadywana)

Ręce to sztywne pięści z metaball (`tools/art/artlib/hands.py`), ustawiane na broni macierzą `hand_matrix(…)`, plus rękaw
jako rura w ręcznie podanym kierunku. W rzeźbie oś chwytu (wokół której zaciskają się palce) była **dokładnie prostopadła**
do linii nadgarstka — a prawdziwa dłoń trzyma kij **po przekątnej** (od kłębu do nasady palca wskazującego), więc kij
tworzy z przedramieniem ~120–135°, nie 90°. Skutek: żeby rękaw szedł do łokcia, nadgarstek musiał się złamać.

Kąty nadgarstka (przedramię względem ręki; zgięcie dłoniowe +, odchylenie łokciowe −), stan przed poprawką:

| ręka | zgięcie | odchylenie | uwaga |
|---|---|---|---|
| sztucer, lewa (pod łożem) | +12° | **−46°** | to widzi gracz — „złamana" |
| strzelba / harpunnik, lewa | 0° | **−46°** | j.w. |
| kartaczownica, lewa | +42° | −37° | |
| hwacha, lewa | +32° | −37° | |
| sztucer, prawa (chwyt pistoletowy) | +64° | −79° | pod kadrem |
| strzelba / harpunnik, prawa | **+170° / +180°** | −114° / −121° | rękaw wychodził przez palce; pod kadrem |

Granice ludzkie: zgięcie/wyprost ±70° (w teście trzymam ±45°, bo pięść zgięta 70° czyta się jako złamana), odchylenie
promieniowe +20°, łokciowe −30°.

Łódka: część `clip` była animowana jako spadający z 6 cm nad mostkiem klocek; żadna ręka się nie ruszała.

## Co się zmieniło

### Modele (Blender, `tools/art/`)
- `artlib/hands.py`: parametr **`cant`** (przekątna chwytu) — przesuwa kulkę nadgarstka i korzeń rękawa na linię chwytu
  przekątnego (o `cant` w stronę małego palca); pięść na broni bez zmian. Pomocnik **`arm()`** buduje pięść, rękaw jako
  **osobną część `sleeve_l/_r`** z osią w nadgarstku i znaczniki dla gry: `Wrist_*` (baza: X = grzbiet dłoni, Y = ku
  palcom, −Y = proste przedramię), `Grip_*` (baza = układ dłoni, Z = oś chwytu/kciuk), `Elbow_*` (łokieć w spoczynku).
  `wrist_angles()` liczy kąty i wypisuje je w logu budowy. `scene.add_markers` przyjmuje znacznik z bazą.
- `vm_rifle_hunt`, `vm_shotgun`, `vm_harpoon`, `vm_gatling`, `vm_hwacha`: cant 35° (lewe, chwyty łoża/uchwytów; prawe
  kartaczownicy i hwachy), 45° (prawa sztucera na chwycie pistoletowym), 70° (prawe strzelby i harpunnika na prostej
  szyjce kolby — przedramię przedłuża linię kolby, rękaw biegnie wzdłuż niej do tyłu); kierunki rękawów dobrane tak, by
  nadgarstki były w granicach (po poprawce, z logu budowy: lewe 4–20° zgięcia, ≤5° odchylenia; prawe ≤21° zgięcia,
  odchylenie −20…+7°). Atlas i glb przebudowane (pełne AO, bez podglądów Cycles; ~1–2 min na model).
- Strzelba: przy łamaniu lewa ręka jedzie z lufami, ale przechyla się tylko w 55 % kąta łamania (`FORE_HAND_TIP`) —
  resztę daje nadgarstek, a przedramię wychyla się w łokciu; inaczej nadgarstek wychodził na +26° (granica +20°).
- Jednoręczne (pistolet, paralizator, rakietnica) i pięści: **bez zmian** (właściciel ich nie zgłaszał; ręka na krawędzi
  kadru). Mają te same 33°/−46° — do zrobienia tą samą metodą, jeśli będzie przeszkadzać.

### Gra (`src/weapons/viewmodel_rig.gd`)
- **Ramiona**: co klatkę rękaw obracany z nadgarstka w stronę łokcia (łokieć spoczynkowy przesunięty o połowę ruchu
  nadgarstka, `ELBOW_FOLLOW`, albo łokieć zadany przez animację). Dzięki temu ręka, która się rusza (lewa strzelby z
  lufami, prawa kartaczownicy na korbie, lewa sztucera przy przeładowaniu), ma przedramię zginające się w łokciu, a nie
  sztywny rękaw wleczony za dłonią. `wrist_angles(side)` zwraca pozowane kąty; `wrist_within_limits()` — granice.
- **Przeładowanie sztucera** (`RELOAD_KEYS`, 2,2 s bez zmiany danych broni): lewa ręka schodzi pod kadr do ładownicy
  (0–0,37 s), wraca z łódką zwisającą z pięści od strony małego palca (pociski do przodu; łódka jedzie na znaczniku
  `Grip_l`, nie lewituje), stawia ją pionowo w prowadnicach (1,1 s), wciska 2 cm (1,2–1,4 s), unosi i **pstryka** pustą
  łódkę (leci w prawo-górę i znika, 1,6–1,8 s), wraca pod łoże (do 2,2 s). Rygiel otwiera się płynnie na początku
  (zamiast skoku), a po włożeniu łódki **prawa ręka chwyta gałkę i dosyła zamek** końcówką cyklu. Przerwane przeładowanie
  (zmiana broni) ściąga rękę płynnie.
- Oglądanie po ulepszeniu (pkt 9) i widoczność części ulepszeń: nietknięte (`_finish_pose` tylko dokłada celowanie rękawów).
- `Viewmodels.HANDS` / `HANDS_NOT_POLISHED`: rękawy należą do strażnika (znikają z broni leżącej w świecie, nie dostają
  wykończenia mistrzowskiego). `ArtLibrary.REGISTRY`: nowe części i znaczniki pięciu modeli.

### Testy
- `tests/integration/test_viewmodel_anatomy.gd`: każdy dwuręczny model ma ramiona i znaczniki (osie sprawdzone geometrycznie);
  każdy nadgarstek w granicach w spoczynku; **w każdej klatce** łamania strzelby, kręcenia korbą, cyklu rygla i całego
  przeładowania sztucera; łódka w pięści (szczyt łódki ≤ 4 cm od punktu chwytu, zwisa w dół) przez cały przenos, stoi
  prosto w prowadnicach w chwili włożenia, odlatuje po pstryknięciu, znika na końcu; ręka schodzi ≥ 20 cm pod spoczynek
  i wraca; łokieć zawsze poniżej broni (poza kadrem); zamek dosyłany po przeładowaniu; przerwane przeładowanie bez skoku.
- Stare testy sztucera (`test_new_weapon_rigs`) bez zmian: łódka widoczna w połowie przeładowania, niewidoczna po.

## Do sprawdzenia w oknie (gdy właściciel pozwoli)
1. `bash tools/run_weapons.sh` / scenariusz z sztucerem: lewa ręka pod łożem — czy nadgarstek czyta się jako prosty
   (rękaw schodzi w dół-lewo do łokcia pod bronią); to samo strzelba, harpunnik, kartaczownica (lewa na uchwycie), hwacha.
2. Przeładowanie sztucera (R przy pustym magazynku): ręka schodzi **całkiem** pod kadr (czy nie wystaje szczyt pięści),
   łódka wyraźnie w pięści, pociski do przodu, wkładanie nad otwartym zamkiem czytelne, pstryknięcie widoczne na środku
   ekranu, powrót bez „pływania"; zamek dosyłany prawą ręką bez skoku gałki.
3. Czy rękaw lewej ręki nie przecina łoża/komory przy przenosie (przechodzi z lewej strony, broń przechylona 18°).
4. Łamanie strzelby: rękaw lewej ręki zgina się w łokciu zamiast obracać z lufami — czy koniec rękawa nie wchodzi w kadr.
5. Kartaczownica: rękaw prawej ręki na korbie (góra obrotu) — koniec rękawa poza kadrem.
6. Zegarek na lewym rękawie: został po stronie wewnętrznej nadgarstka (widoczny dla gracza, jak dotąd) — zostawić czy
   przenieść na grzbiet (wtedy schowany pod przedramieniem)?
7. Podglądy `tools/art/build_art.sh vm_rifle_hunt vm_shotgun vm_harpoon vm_gatling vm_hwacha` (z Cycles, gdy wolno):
   arkusze `tests/_out/art/vm_*_fp.png`.

## Stan prac / co dalej
- Zrobione: analiza (skrypt liczący kąty), rzeźba z cantem, rękawy jako części, znaczniki, przebudowa pięciu modeli,
  rig ramion, choreografia przeładowania, testy, ten dokument.
- Pełny zestaw testów po scaleniu `pietro-1` (wrogowie wschodu): **2179 zaliczonych, 0 nie**, bez błędów silnika.
  Nowy plik testów: `test_viewmodel_anatomy` (8 testów, w tym próbkowanie każdej klatki przeładowania sztucera).
- Otwarte: jednoręczne bronie i pięści tą samą metodą (cant + kierunek rękawa); ewentualnie wykorzystanie markerów
  `Elbow_*` do pełnego IK dwukościowego, gdyby ramiona miały kiedyś robić większe ruchy (sprint, melee).
