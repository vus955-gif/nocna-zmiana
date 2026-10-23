# Opowieść muzeum: tabliczki, ślady personelu, eksponaty, które reagują (21.10.2026)

> Gałąź `museum-story` (z `pietro-1` @76bac48b), worktree `.claude/worktrees/museum-story`.
> Uwagi właściciela (`docs/backlog-pietro1.md`): **#27** — motyw muzeum ma być wykorzystany znacznie mocniej: eksponaty
> opowiadają mini-historie, są źródłem sekretów, uruchamiają starcia, dają bonusy, czasem ożywają; na tym opiera się
> tożsamość gry. Z listy rozszerzonej: **opowiadanie przestrzenią** (układ sal, ekspozycje, co się stało z personelem —
> *mniej tekstu, krótsze notatki*) i **miejsca z emocjonalnym przywiązaniem** (hub, kawiarnia, monitoring w kanciapie).
> Kanon: `docs/fabula-pietro1.md` (biblia), notatki `NOTE_*`, kwestie `VO_*`, audioprzewodnik `VO_GUIDE_*`.
> Zasady sesji: tylko `--headless`, bez okien i dźwięku, nic na GitHub, bez podagentów.

---

## 1. Przegląd: co muzeum już opowiada (stan 21.10)

### Narzędzia narracji, które już są
| Narzędzie | Gdzie | Co niesie |
|---|---|---|
| **Notatki** (`NOTE_*`, 32 na Piętrze I) | po 4 na skrzydło, hol, kanciapa, podziemia, dach | fabuła (Kopeć 1912, dar bez nadawcy, testament Zawilskiego), wskazówki (słaby punkt strażnika, zamki, sekrety) |
| **Audioprzewodnik** (12 stanowisk, wersja dzienna A i nocna B) | Rosetta, Ramzes, lamassu, potop, metopy, zegary, Budda, zbroje, totemy, moai, astrolabium, T-Rex | fakty o eksponacie; wersja nocna — groza i wskazówka (szachy, sekrety) |
| **Heniek przez radio** (~70 kwestii) | wejście do skrzydła, przystań, strażnik pokonany, odłamki, kawiarnia, utknięcie | słabe punkty, kierunek, ciepło |
| **System z głośników** (~45) | godziny, przebudzenie strażnika, bramy, straty w kolekcji | ton biurokratycznej grozy |
| **Zasadzki „na eksponacie”** | strzelba (mumie), sztucer (wilk i raptor), harpunnik (wachta), hwacha (lwy Fu), bezpiecznik (wojownicy z reliefu), pisarz-automat | eksponaty ożywają, gdy coś się zabierze |
| **CCTV w kanciapie** | ściana monitorów, konsola | tylko RUCH w kadrze, noc, zegar |
| **Kawiarnia** | lada, ekspres, tablica z menu | mechanika (kawa, zmęczenie), szaleństwo ekspresu po 3:00 |

**Czego brakuje we wszystkich skrzydłach:** eksponaty nie mają **ani jednej tabliczki** do przeczytania (poza nazwą sali na
karcie). Personel istnieje wyłącznie w tekście notatek — w przestrzeni nie zostawił żadnego śladu. Żaden eksponat nie
reaguje na gracza poza walką. Hub nie pamięta, co gracz zrobił (poza licznikiem strat w kwestiach Systemu).

### Per skrzydło: co opowiada, czego brakuje
| Skrzydło | Co już opowiada | Luka (do zrobienia) |
|---|---|---|
| **Hub** (Dziedziniec, hol, kanciapa, korytarz płn.) | notatki Heńka, kustosza, kasjerki, Kopcia; stanowiska 11–12; T-Rex, astrolabium | kanciapa nie „widzi” postępów; kawiarnia bez ludzi; nic nie liczy, ile eksponatów „wróciło do spoczynku”; fundator tylko w testamencie |
| **Egipt** | obóz 1898 (strzelba → mumie), zlecenie Gila nr 203 (Kolos), spis skrzyń (serce) | serdab i fałszywe drzwi tylko w notatkach; Gil nie zostawił śladu w przestrzeni |
| **Asyria** | karta lamassu z dopiskami, przekład Mireckiego, winda Gila, raport Mazura z klatki | noc Mazura w klatce lwów jest tylko w notatce ukrytej *w* klatce — dół polowania nic nie pokazuje |
| **Grecja** | Lipski (Kentaur), gołębiarz Turek (strych), książka raportów, zlecenie 248 | gołębie Turka i strych tylko w notatce na strychu |
| **Oświecenie** | regulamin Kosteckiej, testament Zawilskiego, obserwacje Sztern, teczka introligatora | **złamana noga Heńka (raptor) — początek całej historii gracza — nie ma żadnego śladu**; podróżne astrolabium fundatora tylko w testamencie |
| **Azja** | etykieta hwachy, Okamura, karta płatnerza Kowalika, list Rudnickiego | los Kowalika (jego karta leży w skarbcu za łańcuchem) bez śladu w sali zbroi |
| **Ameryki** | bosman 1851, scenariusz nocnego oprowadzania Bieleckiej, kryjówka Heńka, zarządzenie 1931 | nocne oprowadzanie istnieje tylko jako scenariusz w notatce |

### Notatki za długie (właściciel: krótsze)
Powyżej 125 słów PL (czytnik pomniejsza kartkę): `NOTE_BOOTH_1` (153), `NOTE_ASIA_1` (149), `NOTE_ASSYRIA_1` (148),
`NOTE_ENLIGHTENMENT_1` (148), `NOTE_EGYPT_1` (147), `NOTE_AMERICAS_2` (146), `NOTE_COURT_2` (142),
`NOTE_ENLIGHTENMENT_2` (138), `NOTE_GREECE_1` (135), `NOTE_ASSYRIA_2` (134). Skracam do ≤ 120 słów PL, **zachowując
każdą wskazówkę i każdy fakt fabularny** (biblia §5); EN równolegle. Test pilnuje limitu na przyszłość.

---

## 2. Projekt

### 2.1 Tabliczki eksponatów (`ExhibitLabels`, `ExhibitLabel`, `ExhibitCard`)
- Mosiężna tabliczka (model `plaque_brass`) **na ścianie** albo na **słupku** (model `stanchion_post` + tabliczka pod
  kątem, jak w prawdziwym muzeum) przy kluczowych eksponatach. **E** otwiera kartę eksponatu (bez pauzy): numer
  inwentarzowy i skrzydło (małe kapitaliki), nazwa (szeryf), 2–3 krótkie zdania kursywą — ton katalogu muzealnego
  z mrocznym zwrotem. Karta znika po czasie czytania, po odejściu na > 3,5 m albo po ponownym E.
- **Część tabliczek to wskazówki** (pole `clue` w katalogu): słaby punkt strażnika (`weakness` → znacznik
  `guardian_*`), sekret (`secret` → znacznik `secret_*` + brama, która go zamyka), narzędzie zamka (`tool` → brama
  i jej wymaganie: `harpoon`, wybuch, celny strzał, ciężki cios, sztucer). Test: każdy odnośnik istnieje w układzie
  Piętra I, a narzędzie zgadza się z wymaganiem bramy.
- Teksty `LABEL_<ID>_TITLE` / `LABEL_<ID>_TEXT` (PL+EN), numer inwentarzowy w danych (nie tłumaczony).
- ~22 tabliczki: po 3–4 na skrzydło, 3 w hubie (T-Rex, astrolabium, kartaczownica) i krypta.

### 2.2 Ślady personelu — po jednej winiecie na skrzydło (`StoryVignettes`)
Każda winieta to kilka rekwizytów ułożonych w ślad, który **kończy się w ważnym miejscu**, i **jeden** rekwizyt do
obejrzenia (E → 1–2 zdania). Bez nowych notatek: ślad prowadzi do notatki, która już istnieje.
| Skrzydło | Kto | Ślad | Kończy się |
|---|---|---|---|
| Egipt | konserwator **R. Gil** | otwarta skrzynka narzędziowa, stetoskop na gwoździu, kreda: kreski i krzyżyk na spękanej ścianie, lampka | spękana ściana serdabu (sekret: wybuch) |
| Asyria | stróż **St. Mazur** | czapka przy rydwanie, latarka wciąż świeci w stronę klatki, ślady pazurów | klatka lwów królewskich (sekret: lina; jego raport w środku) |
| Grecja | gołębiarz **E. Turek** | kosz na gołębie, rozsypane ziarno, pióra wzdłuż antresoli | klapa strychu na linie (sekret; notatka Turka) |
| Oświecenie | **Heniek** — noc, w której raptor złamał mu nogę | latarka Heńka, krzesło przewrócone przy dioramie raptorów, ślady pazurów, szyna z linijki i bandaż | drzwi gabinetu bibliotekarza (przystań — „przystań wytrzymała”) |
| Azja | płatnerz **W. Kowalik** | puszka oliwy, szmata, rozsypane łuski zbroi | skarbiec za łańcuchem — łańcuch założony **od strony sali** |
| Ameryki | przewodniczka **H. Bielecka** | półkole stołków przed totemami, jeden przewrócony, chorągiewka przewodnika, rozsypane ulotki | schody do magazynu zabitego deskami (totem nr 3 śpiewa pod podłogą) |

### 2.3 Eksponaty, które reagują (`Curio`) — małe, uczciwe, nieobowiązkowe, zapisane
| Eksponat | Skrzydło | Co robi | Nagroda | Zapis |
|---|---|---|---|---|
| **Śpiewający ptak w klatce** (automat, model `lib_bird_cage`) | Oświecenie, Sala Zegarów | E nakręca: ptak obraca się i śpiewa — **sześć krótkich trzepnięć i jeden długi tryl** | wskazówka: Wielkie Planetarium — sześć planet, potem słońce | flaga `curio_bird` (pierwsze nakręcenie); można nakręcać dalej |
| **Podróżne astrolabium fundatora** | Oświecenie, gabinet przyrodniczy | E obraca alidadę o 1/8 obrotu; ustawiona na Gwiazdę Polarną (znak N na tarczy, mówi o tym tabliczka) odsuwa szufladę w podstawie | sakiewka Pyłu + naboje do sztucera (dla gracza bez sztucera — zamiennik jak każdy łup) | flaga `curio_astrolabe` + co zabrano z szuflady (raz na grę) |
| **Portret fundatora**, który odpowiada raz | korytarz północny | E: oczy portretu zapalają się, jedno zdanie Zawilskiego | wskazówka: izba portiera na wschodnim końcu, okiennica na linie (sekret) | flaga `curio_portrait`; potem portret milczy |
| **Waga Sądu Ozyrysa** | Egipt, komory grobowe | E: pusta szala opada, jakby coś na niej leżało; w podstawie otwiera się skrytka | sakiewka Pyłu + apteczka | flaga `curio_scale` + zabrane |

### 2.4 Kotwice emocjonalne
- **CCTV w kanciapie:** ekran stanu na ścianie monitorów przełącza się co kilka sekund na **„Dziennik zmiany”**: każde
  skrzydło — *brak sygnału* (nieodwiedzone) / *czuwa* / *spokój* (strażnik pokonany) i licznik „w spoczynku: N”.
  Kamery w skrzydłach, które są w spokoju, mają na obrazie zielony znacznik SPOKÓJ (gdy nic się tam nie rusza).
- **Kawiarnia:** korkowa **tablica ogłoszeń dla personelu** na ścianie za ladą (tylko z miejsca baristy — „dla
  personelu”). Przypięte karteczki zmieniają się z nocą i z postępem (grafik po wypadku Heńka, zguba Mazura, Gil
  o ekspresie, kasjerka o mleku, po Kolosie, po Reksie…). E czyta tablicę (karta z 3–4 krótkimi ogłoszeniami).
- **Hol (Dziedziniec):** mosiężna tablica „Eksponaty przywrócone do spoczynku: N” (licznik zniszczonych eksponatów
  ze wszystkich nocy, `GameState.voice_state.destroyed`) i „Skrzydła w spokoju: k z 6”; odświeża się na żywo.

### 2.5 Architektura (addytywnie — inne gałęzie edytują pliki stref i sztuki równolegle)
- **Układ:** nowy moduł `src/level/floor1/zones/story.gd` (`Story.build(layout)`) wołany jedną linią w
  `Floor1Layout.create()` po strefach. Dodaje **tylko znaczniki** (`label_*`, `curio_*`, `vignette_*`,
  `cafe_corkboard`, `rest_plaque`) w istniejących salach — bez sal, przejść i kawałków (nie rusza powłoki,
  nawigacji ani kolizji układu; nie trzeba piec `bake_shell_cache`).
- **Treść:** `src/world/story/` — katalogi danych (`ExhibitLabels`, `StaffCorkboard.NOTICES`, `StoryVignettes.TRAILS`),
  węzły (`ExhibitLabel`, `ExhibitCard`, krzywe rekwizytów, `Curio` i jego cztery odmiany, `RestPlaque`) oraz instalator
  `MuseumStory`, który `FloorGame.setup()` dokłada jedną linią po kawiarni.
- **Zapis:** `GameState.flags` (`curio_*`, `curio_*_taken_<n>`) — pole już zapisywane; bez zmian formatu zapisu.
- **CCTV:** drobne, addytywne zmiany w `cctv.gd` / `cctv_feed.gd` (druga strona ekranu stanu, znacznik SPOKÓJ);
  treść dziennika liczy czysta funkcja `ShiftLog.lines()`.
- Teksty: `locale/strings.csv` (dopisane na końcu; skrócone notatki w miejscu).

---

## 3. Testy (TDD)
- Katalog tabliczek: każda ma znacznik w układzie i odwrotnie; tytuł i tekst PL+EN; tekst krótki (≤ 3 linijki
  karty); **każda wskazówka wskazuje rzeczy, które istnieją** (znacznik, brama, wymaganie bramy = narzędzie).
- Znaczniki opowieści: w swojej sali, na jej podłodze (stojące) albo przy ścianie (wiszące), z dala od kawałków
  z kolizją, łupów, miejsc wrogów i drzwi.
- Karta eksponatu mieści się na ekranie (PL i EN, 1920×1080 i 1280×720).
- Tabliczka: E pokazuje kartę; odejście ją chowa.
- Każdy eksponat-ciekawostka: działa, zapisuje flagę raz, nagroda raz na grę (po „wczytaniu” — `from_dict` — szuflada
  pusta, portret milczy), teksty istnieją.
- Tablica w kawiarni: ogłoszenia zależą od nocy i postępu; zawsze 2–4; teksty mieszczą się.
- Licznik w holu i dziennik zmiany: liczą z `GameState`; linie mieszczą się na ekranie stanu.
- Notatki Piętra I: każda ≤ 120 słów PL.
- Integracja: `Museum` z Piętrem I instaluje opowieść (tabliczki, ciekawostki, winiety, tablica, licznik).

## 4. Kolejność prac (jeden commit na zadanie)
1. Ten dokument (przegląd + projekt).
2. Katalog tabliczek + znaczniki `story.gd` + testy odnośników i rozmieszczenia.
3. `ExhibitCard` + `ExhibitLabel` + teksty tabliczek + instalator `MuseumStory`.
4. Winiety personelu (rekwizyty, rzeczy do obejrzenia).
5. Ciekawostki: ptak, astrolabium, portret, waga.
6. Kotwice: licznik w holu, tablica w kawiarni, dziennik zmiany w CCTV.
7. Skrócone notatki + test limitu.
8. `git merge pietro-1`, pełny zestaw testów.

## Do sprawdzenia w oknie
- Tabliczki: czy mosiężne płytki nie wiszą w powietrzu / nie wchodzą w dekor ścian (sztuka: pilastry, cokoły); płytka
  na słupku (stanchion + płytka pod kątem 55°) — czy czytelna i ładna; tabliczka Kolosa na ścianie galerii, Orrery na
  filarze galerii biblioteki, moai na cokole; grawer tytułu czytelny z bliska.
- Karta eksponatu po prawej: czy nie zasłania celownika/HUD, czy tempo znikania jest dobre.
- Winiety: skala i wygląd rekwizytów z prymitywów (skrzynka Gila, latarka z fałszywym stożkiem światła, ślady pazurów,
  kosz, łuski zbroi, krzesło na boku, stołki), czy nic nie lewituje / nie tonie w podłodze w wersji ubranej.
- Ptak w klatce: obrót i „dziobanie” podczas śpiewu, kierunek długiego trylu (Planetarium); odsłuch `automaton_song`
  i `dial_click` (właściciel — dźwięku nie odsłuchiwałem).
- Astrolabium: kierunek obrotu alidady, gwiazdka u góry, wysuw szuflady i pickup przed nią.
- Portret fundatora: świecące oczy w miejscu oczu modelu `portrait`, tabliczka pod ramą.
- Waga: przechył belki (pusta szala w dół), odsunięcie płytki, apteczka.
- Tablica ogłoszeń przy kawiarni (zachodnia ściana) i tablica „Eksponaty przywrócone do spoczynku” (południowa ściana
  przy łuku) — czy nie kolidują z dekorem dziedzińca; czytelność liczby z daleka.
- CCTV: druga strona ekranu stanu (dziennik zmiany, czcionka 15) i zielony znacznik SPOKÓJ na podglądach.
- **Przegląd w oknie 23.10**: nie sprawdzone (brak widoków; propozycja w `2026-10-22-przeglad-w-oknie.md` §2).

## Stan prac / co dalej
**Stan 23.10 — gotowe do ponownego merge'a w `pietro-1`.** Pełny zestaw (jeden proces): **3209 passed, 0 failed**, bez błędów silnika i wycieków (32 min 35 s, po drugim `git merge pietro-1` @`1a88be82`).

Historia: warstwa opowieści weszła do `pietro-1` jako `1951225d` i została cofnięta (`196188ae`), bo po merge'u proces
testów ginął z kodem 3 bez komunikatu w `test_world_rewards :: test_the_stash_restocks_each_night_but_not_within_one`.
Na gałęzi: `git merge pietro-1` (wnosi ten revert), potem `git revert 196188ae` (= „reapply”: warstwa wraca na bieżące
`pietro-1`), poprawka awarii, krótsze notatki, drugi `git merge pietro-1`. Zwykły merge `museum-story` → `pietro-1`
wnosi revert revertu, więc przywraca całą warstwę (nie trzeba nic cofać ręcznie).

**Przyczyna awarii (znaleziona, usunięta):** to nie był błąd w kodzie opowieści, tylko limit Jolt. Test zwalnia muzeum
i buduje je od nowa w tej samej klatce fizyki. Jolt trzyma węzły drzewa broadphase usuniętych ciał do następnej
aktualizacji (kroku fizyki), a nowe piętro (~4400 ciał i obszarów) dochodzi po jednym ciele; pierwsze zapytanie po
przebudowie optymalizuje drzewo i przy domyślnym `physics/jolt_physics_3d/limits/max_bodies` = 10240 (od niego zależy
pula węzłów) pula się kończy, a Jolt woła `std::abort()` („QuadTree: Out of nodes!”, wersja release tego nie wypisuje)
→ kod wyjścia 3. Warstwa opowieści dokładała tylko kilkadziesiąt ciał i przesunęła piętro za próg. Dowody (z ustalonym
ziarnem treści): z `max_bodies` 20480 test przechodzi; z 9000 pada nawet bez warstwy opowieści; z jednym krokiem fizyki
między zwolnieniem a przebudową przechodzi; na Godot Physics przechodzi. To samo groziło grze przy zmianie sceny
(Godot wyjmuje starą scenę i wstawia nową w jednej klatce, np. menu z żywym Piętrem I → muzeum).
**Poprawka:** `project.godot` → `max_bodies=32768` (~0,7 MB więcej na przestrzeń fizyki). Test
`test_museum_story :: test_the_story_survives_the_museum_freed_and_built_again_in_one_frame`: muzeum zwolnione
i zbudowane dwa razy w jednej klatce ma całą warstwę opowieści, a limit ciał zostaje > 5 × liczba ciał piętra (dziś
4430: zabezpieczenie na przyszły wzrost treści).

Zrobione (commity): przegląd i projekt; 20 tabliczek z podpowiedziami (test odnośników); karta eksponatu; 6 winiet
personelu; 4 ciekawostki (ptak, astrolabium, portret, waga); licznik w holu, tablica ogłoszeń, dziennik zmiany w CCTV;
poprawka awarii (wyżej); **12 najdłuższych notatek skróconych do ≤ 120 słów PL** (10 z planu + skrzynie Egiptu
i dziennik wielorybnika, które też przekraczały limit), każda wskazówka zachowana; test „każda notatka Piętra I ≤ 120
słów PL” (`test_world_texts :: test_every_floor_one_note_is_short`); katalog `opowiesc-muzeum-wip` usunięty.

Co dalej: merge do `pietro-1` (kontroler). Znane czerwone testy: brak.
