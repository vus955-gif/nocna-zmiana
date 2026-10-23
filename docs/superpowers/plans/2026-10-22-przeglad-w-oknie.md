# Przegląd w oknie — noc 22/23.10.2026 (`visual-qa-night`)

> Gałąź `visual-qa-night` (z `pietro-1` @2e59a773, potem `git merge pietro-1` @0b18d63c o 03:05 — weszły m.in.
> fp-anims, perf-cpu, fix-env, fix-env-2, blender-models, playthrough-bot). Worktree `close-wings`.
> Wszystkie okna przez `tools/agents/with_window.sh`, dźwięk wyciszony (`--audio-driver Dummy`), jedno okno naraz.
> **Warunki pomiaru:** równolegle inni agenci puszczali testy headless (obciążenie CPU całego komputera 29–57 %,
> procesy projektu przypięte do 12 logicznych CPU). Liczby czasu klatki są przez to zawyżone po stronie CPU.
> Sprzęt: NVIDIA GeForce RTX 2080 Ti, Vulkan 1.4.329, Forward+.

## 0. Narzędzia dodane tej nocy (tylko sceny QA, nie kod gry)

- `tools/run_tour.sh perf`: oprócz FPS mierzy teraz **czas GPU i CPU renderu** (te same odczyty co wiersze „Render GPU /
  Render CPU” nakładki F3: `RenderingServer.viewport_get_measured_render_time_*`), medianę klatki, lampy i cienie po
  cullingu; do tego **walki** (`fight_colossus`, `fight_general`, `fight_lamassu`, `fight_trex`: strażnik obudzony 10 m
  przed strażnikiem, widok jego oczami z HUD-em) i **zrzut nakładki F3** nad Dziedzińcem (`f3_numbers_court`,
  `f3_systems_court`). Commit `6c158847`.
- `tools/run_visual_qa.sh shots --only=night` (albo części: `night_lamps`, `night_gaze`, `night_tools`,
  `night_devices`): lampy „niesamowitych” zdarzeń w 4 salach we wszystkich trybach (z sumą energii lamp w logu), wzrok
  portretu, każda pułapka otoczenia (zawieszka z 10 i 20 m, ostrzeżenie, ostrzeżenie z góry, upadek, wrak z bliska
  i z góry; w logu „drawn box” — co faktycznie widać z przesuniętego ładunku), urządzenia biomów przed i po działaniu.
  Commity `6c158847`, `0807560b`. Wynik: `tests/_out/visual_qa/night/*.png` + `metrics.json`.
- **Pułapka znaleziona przy okazji (dla każdego, kto robi zrzuty wolną kamerą):** culling pokoi (`RoomCuller`) idzie
  za **bieżącą kamerą**. Scenariusz, który między zrzutami wraca do kamery strażnika stojącego w budce, gasi sale
  oglądane wolną kamerą — pierwsza wersja grupy `night` pokazywała „lampy, które nie wracają po efekcie”, a to był
  tylko artefakt. Grupa `night` trzyma teraz wolną kamerę i czeka 0,8 s po każdym przeniesieniu (`_settle_camera`).

## 1. Pomiar GPU / klatki

`bash tools/run_tour.sh perf --preset=high`, okno 1920×1080, V-Sync wyłączony, bez limitu FPS, kamera lekko się kołysze
4 s na widok. Po scaleniu `pietro-1` (z perf-cpu). GPU = mediana (p95) z `viewport_get_measured_render_time_gpu`.

| Widok | Preset / rozdz. | FPS | Klatka mediana / p99 | GPU mediana (p95) | Render CPU | Draw calls | Obiekty | Prymitywy | Lampy (cienie) po cullingu |
|---|---|---|---|---|---|---|---|---|---|
| Dziedziniec SW (`court_wide_sw`) | high / 1920×1080 | 46 | 21,8 / 32,3 ms | 6,6 (7,1) ms | 7,6 ms | 8381 | 18 137 | 8,35 M | 295 (16) z 946 |
| Dziedziniec od wejścia (`court_from_entrance`) | high / 1920×1080 | 44 | 22,0 / 49,5 ms | 6,7 (7,2) ms | 7,3 ms | 7955 | 17 101 | 7,75 M | 208 (11) |
| Biblioteka, galeria (`library_gallery_walk`) | high / 1920×1080 | 51 | 18,3 / 30,2 ms | 6,9 (7,7) ms | 6,4 ms | 3962 | 8 907 | 4,50 M | 232 (13) |
| Galeria Egiptu (`egypt_gallery_long`) | high / 1920×1080 | 54 | 17,9 / 28,0 ms | 6,7 (7,4) ms | 6,1 ms | 7174 | 14 588 | 5,67 M | 205 (12) |
| Walka: T-Rex (`fight_trex`) | high / 1920×1080 | 63 | 15,5 / 30,8 ms | 6,0 (6,7) ms | 5,6 ms | 3728 | 7 352 | 2,76 M | 295 (16) |
| Walka: Kolos (`fight_colossus`) | high / 1920×1080 | 100 | 10,7 / 14,9 ms | 5,3 (5,8) ms | 3,6 ms | 2117 | 4 373 | 1,49 M | 140 (9) |
| Walka: Generał (`fight_general`) | high / 1920×1080 | 123 | 7,1 / 11,9 ms | 5,5 (6,1) ms | 2,3 ms | 704 | 1 400 | 0,63 M | 64 (2) |
| Walka: Lamassu (`fight_lamassu`) | high / 1920×1080 | 136 | 6,2 / 11,5 ms | 4,4 (4,9) ms | 2,2 ms | 469 | 1 446 | 0,12 M | 109 (7) |

**Wniosek:** GPU nigdzie nie przekracza 7,7 ms (p95) — sama karta pozwalałaby na ≥ 130 FPS nawet na Dziedzińcu
z 295 lampami. Wszystkie widoki poniżej ~100 FPS są **ograniczone przez CPU**: render CPU (wywołania rysowania, 7–8 ms
przy ~8 tys. draw calls na Dziedzińcu) plus skrypty i fizyka, a pod dzisiejszym obciążeniem także czekanie na rdzenie
(klatka 22 ms ≫ GPU 6,6 + render CPU 7,6). Najtańszy kierunek dla Dziedzińca to **mniej draw calls** (łączenie siatek
ubranych sal, MultiMesh dla powtarzalnych elementów), nie oszczędzanie GPU.

Przed scaleniem perf-cpu (ten sam przebieg, @2e59a773): Dziedziniec SW 38 FPS (mediana 26,2 ms), od wejścia 40 FPS,
biblioteka 42 FPS, galeria Egiptu 44 FPS, T-Rex 55 FPS; GPU praktycznie bez zmian (6,7–6,9 ms) — zysk jest po stronie CPU.
Pełne liczby: `tests/_out/tour/perf_high.json`, logi `tests/_out/qa_night/tour8.log` (po) i przebieg o 02:10 (przed).

**Nakładka F3 w oknie 1920×1080:** działa, sterownik zwraca czas GPU („Render GPU 7,3 ms” nad Dziedzińcem), wykres,
tryb „systemy” (Wystawy AI 1,93 ms na tyk fizyki, Poziom: światła i drzwi 0,35 ms…) stoi pod paskiem bossa bez
nachodzenia. Zrzuty: `tests/_out/tour/f3_numbers_court.png`, `f3_systems_court.png`.

## 2. Listy „Do sprawdzenia w oknie” — wynik

Oznaczenia: **OK** · **POPRAWIONE** (commit) · **PROBLEM** (zrzut, propozycja) · **NIE SPRAWDZONE** (dlaczego).
Zrzuty w `tests/_out/visual_qa/night/`, `tests/_out/tour/`, `tests/_out/hud_style/`, `tests/_out/guardian_general/`,
kopie sprzed scalenia w `tests/_out/qa_night/` (wszystko w worktree `close-wings`).

### Walka otoczeniem (`2026-10-21-srodowisko-walka.md` §4)
- Czytelność zawieszki z 10 / 20 m — **OK** tam, gdzie jest linia wzroku: czerwony pierścień świeci i w ciemnej sali
  widać go nawet wtedy, gdy samego przedmiotu nie widać (kolumna, dźwig w Nimrud, koło). Z 30 m — nie robione.
  (`tool_*_tag_10m.png`, `tool_*_tag_20m.png`)
- Ostrzeżenie 1,0 s + znak na podłodze — **OK** dla żyrandola (pomarańczowy krąg wokół rozety), lampy burzowej, kolumny,
  regału (prostokąt toru), płyty w Nimrud, koła (dwa pasy toru). **PROBLEM (mały):** skrzynia rakiet w Korei — w 0,5 s
  ostrzeżenia widać iskry lontu, ale wachlarza na podłodze nie widać ani z boku, ani z góry
  (`tool_rockets_korea_warning.png`, `_warning_above.png`) — sprawdzić w ruchu, ewentualnie mocniejszy brzeg wachlarza.
- Wygląd upadków — żyrandol **OK** (leży na rozecie, łańcuch wzdłuż posadzki), kolumna **OK** (bębny na posadzce;
  w kadrach z bliska i z góry nic nie przenika przez gablotę), płyta reliefu **OK**, ogień lampy burzowej **OK**. **PROBLEM (duży): regał w bibliotece
  wcale się nie przewraca na oko** — patrz §3.1.
- Żyrandol: wrak czyta się jako żyrandol z bliska; z góry zlewa się z okrągłą rozetą posadzki (ta sama wielkość) —
  **PROBLEM (mały)**, §3.6. Zawieszka przy rozecie z ~14 m — **OK**, widać ją nad koroną.
- Plama ognia — **OK**: płomienie i światło na posadzce, granica czytelna z góry (`tool_storm_lamp_egypt_down_above.png`).
- Kamienne koło (nowe miejsce po fix-env-2) — tor **OK** (dwa pomarańczowe pasy), samo toczenie nie złapane w stopklatkach;
  koło w świetle sali bardzo ciemne (czarny krąg) — potwierdzam uwagę z planu.
- Kołysanie lamp, szkło gablot, posągi na cokołach, obrazy na gwoździu, latarnie w Azji, przycięcie przy pierwszej
  zawieszce, wydajność biblioteki przy serii z kartaczownicy — **NIE SPRAWDZONE** (wymagają ruchu/strzelania; brak
  widoku w scenariuszach; czas).
- Dźwięki — **NIE SPRAWDZONE** (zasada: bez dźwięku).

### Mechaniki biomów (`2026-10-21-mechaniki-biomow.md`)
1. Egipt (płyty, „pyski”) — **NIE SPRAWDZONE** w praktyce: widok `device_tomb_trap_idle` za ciemny, by ocenić
   z-fighting; potrzebny widok z latarką.
2. Asyria (sieci) — **NIE SPRAWDZONE** w praktyce: widok z 7 m w ciemnej jamie lwów, węzła sieci nie widać
   (`device_hunting_net_*.png`) — sam brak „jasnego węzła” z tej odległości może być już odpowiedzią; do obejrzenia z galerii.
3. Grecja (lampa łukowa, wiązka) — **PROBLEM**: wiązka to równy, biały, nieprzezroczysty pręt — czyta się jak laser SF,
   także odbita od lustra (`device_helios_lamp_act_04.png`, `device_bronze_mirror_idle.png`). §3.3.
4. Oświecenie (regulator) — **NIE SPRAWDZONE**: kamera trafiła w ścianę obok szafki (`device_regulator_idle.png`).
5. Azja (dzwony, fale) — dzwon z łańcuchem **OK**; fale to dwa cienkie złote pierścienie — **PROBLEM (gust)**: dość
   „interfejsowe” (`device_temple_bell_act_04.png`). §3.5.
6. Ameryki (zgaszona misa) — **OK**: płomień znika, zostaje żar w misie, dym (`device_sacred_fire_act_04/12.png`);
   ciemnienie całej sali — nie oceniane.
7. Podziemia (para) — słup pary widać w korytarzu (`device_steam_vent_idle.png`), ale kadry „po wybuchu” wyszły ciemne —
   **częściowo**.
8. Dźwięki — **NIE SPRAWDZONE** (bez dźwięku).
9. Podpowiedzi HUD — podpowiedź regulatora (dwie linie PL) mieści się w pasku, nie nachodzi na nic w kadrze
   (`tests/_out/qa_night/run2/gaze_before.png`) — **OK** dla tej jednej; reszty nie przeglądałem.

### Narastanie nocy (`2026-10-21-eskalacja-nocy.md` §6)
1. Lampy — sprawdzone w **galerii Egiptu, bibliotece, galerii portretów i holu północnym**, każdy tryb
   (`lamps_<sala>_<tryb>_<chwila>.png`, energia w logu): przygaszenie do 30 % — **OK** (obraz ok. 40–65 % jasności,
   orientacja zostaje); zgaśnięcie — **OK** w Egipcie, bibliotece i holu (księżyc + czerwień awaryjnych), **PROBLEM**
   w galerii portretów: prawie czarno (średnia jasność 0,004), §3.2; migotanie — **OK** (spadki widać, nie równy puls);
   „przejście” w 0,8 / 1,6 s — gasną pojedyncze dalekie lampy, tempa ze stopklatek nie da się ocenić; znaki WYJŚCIE —
   **NIE SPRAWDZONE**.
2. Oczy obrazów — **PROBLEM**: z 1,6 m przesunięcie tęczówek wyraźne, z 6 m praktycznie niewidoczne (oczy to 2–3 px
   w 1080p, a gdy strażnik patrzy wprost na portret, kropka celownika zasłania twarz) (`gaze_follow_6m.png`,
   `gaze_follow_close.png`). §3.4.
3.–10., 12.–14. (postać znika z portretu, pusty cokół, odwrócone popiersie, zegary wstecz, wieko, błysk hełmu, trzask
   drzwi, myśli strażnika, tempo nocy, ciemna sala) — **NIE SPRAWDZONE** (brak widoków; zmiany świata `force_change`
   wymagają celu, którego API nie zwraca; czas).
11. Dźwięki — **NIE SPRAWDZONE**.

### Animacje FPP (`2026-10-21-animacje-fpp.md`)
- Po scaleniu fp-anims: bezczynność wszystkich broni dwuręcznych, przeładowanie sztucera klatka po klatce, łamanie
  strzelby (25/50/80 %), harpun, korba kartaczownicy, ognista skrzynia, FOV 110° — **OK**, nic nie przenika przez kadr,
  łuski wylatują przy łamaniu (`tests/_out/qa_night/post/viewmodel/`). Porównanie przed/po: `qa_night/pre_merge/`.
- Punkty 1–7 listy (tempo dobycia, cios pięścią, „flick” strzelby, oględziny, sięgnięcie, sprint, pchnięcie
  kartaczownicy) — **NIE SPRAWDZONE**: dotyczą tempa w ruchu, stopklatki go nie pokazują. Punkt 8 (rękaw) — nie oglądany.

### Modele z Blendera (`2026-10-21-modele-blender.md` §5)
- Bizon — **OK** (garb, głowa nisko, rogi; oczy nie świecą za mocno). Tipi — **OK** (pas z dyskami, dysk słońca).
- Kajak — **OK**: szwy skóry, obręcz włazu, zwężony dziób — nie czyta się jak deska; płozy dotykają kadłuba; tabliczka
  na podeście od strony sali. **Wiosła na pokładzie nie widać** z tej strony (`tests/_out/tour/kayak_close.png`, widok
  `--view=`).
- Łódź wielorybnicza — widać tylko biel burty na skraju kadru `americas_pacific_whaling` — **częściowo**.
- Rydwan, klatki lwów, sosny i bambus — **NIE SPRAWDZONE** z bliska (w widokach `assyria_lions_*`, `asia_garden_*` nie
  w kadrze lub za daleko).
- Dach (nowe z tej nocy): zbiornik wody, centrale (emalia nie za jaskrawa), gołębnik, rusztowanie w Nimrud, latarnia
  kopuły — **OK** w ujęciach `roof_*`, `assyria_scaffold`; kominy i łup nad centralą — nie w kadrze.

### Dostępność (`2026-10-21-dostepnosc.md`)
- HUD w 4 paletach (standard, deuter-, prot-, tritanopia) — **OK**, sprawdzone próbkowaniem pikseli: zdrowie i pasek bossa
  w protanopii `#e6442e`, kofeina w trytanopii `#ff9ea5`/`#ffb7bc`, reszta zgodnie z planem (`night_cv<n>_hud_pl_1920x1080.png`).
  Ikony bezpieczników też zgodnie z planem (deuteranopia: włożony ≈ `#33ff9f`, niesiony ≈ `#e6a92e`; protanopia: niesiony
  ≈ `#b27512`; trytanopia jak standard). Różnice są subtelne na oko, ale kolory w kadrze odpowiadają tabeli z §4 planu.
- Rimy pickupów — z bliska zmiana słaba (zgodnie z uwagą w planie), daleki rząd zmienia kolor kropek — **OK / jak opisano**
  (`night_cv<n>_rims_pl_1920x1080.png`).
- Skala HUD ≠ 100 %, rozmiary napisów, ograniczenie błysków (lampy, piwnica, gatling, menu) — **NIE SPRAWDZONE** (galeria
  HUD nie ma tych ustawień w parametrach; czas).

### Klawisze i nakładka F3 (`2026-10-21-sterowanie-nakladka.md`)
- Nakładka F3 w 1920×1080 i pomiar GPU — **OK** (§1).
- 21:9 — **NIE SPRAWDZONE** (galeria HUD ma tylko 1920×1080 i 1280×1024).
- Panel klawiszy, przechwytywanie myszy, kolejność `Esc` — **NIE SPRAWDZONE** (wymaga interakcji); wiersz „Klawisze …
  Domyślne ›” w opcjach widoczny (`night_options_pl_1920x1080.png`). Przy okazji **PROBLEM (mały):** w opcjach EN lista
  startuje przewinięta o pół wiersza (pierwszy wiersz „Mouse sensitivity” przycięty u góry), w PL nie
  (`night_options_en_1920x1080.png`) — możliwe, że to stan przewinięcia przeniesiony z poprzedniego widoku galerii.

### Opowieść muzeum (`2026-10-21-opowiesc-muzeum.md`)
- **NIE SPRAWDZONE** (tabliczki, karta eksponatu, winiety, ptak, astrolabium, portret fundatora, waga, tablice, CCTV) —
  brak widoków w scenariuszach, czas. Proponowane jako następny przebieg: widoki `--view=` w `run_tour.sh` przy każdej
  tabliczce z `layout.markers`.

### Przejście bota (`2026-10-21-przejscie-bota.md`)
- **NIE SPRAWDZONE** (trumna mumii P2, przebieg bota w oknie) — czas.

### Akustyka — pominięta zgodnie z zadaniem (tylko odsłuch).

### Poza listami (najczęściej widziane przez gracza)
- Dziedziniec, ogród Azji, biblioteka, Egipt, Partenon w ujęciach `run_tour.sh` i `run_promo.sh` (po scaleniu) — **OK**,
  wyglądają bardzo dobrze; bez przenikania i dziur w kadrach.
- Paralizator w blackoucie świeci jasnożółto (`blackout_*.png`) — sprawdzone A/B z latarką wyłączoną: prawie tak samo jasny
  bez latarki, więc to jego własne światło wypełniające i jasnożółty materiał, nie błąd latarki — **OK / gust**
  (`tests/_out/qa_night/s_torch_ab.png`; przełącznik `--flashlight=off` był tymczasowy, nie został w kodzie).
- Menu główne z żywą sceną (`run_menu_shots.sh shots`) — **NIE SPRAWDZONE**: pod dzisiejszym obciążeniem budowa sceny
  menu trwała 13,9 s i menu zgodnie z założeniem zostało przy statycznym tle („the live scene was given up”). Zapasowe
  tło działa; na słabszym komputerze żywe menu może się nie pojawiać — warto znać próg.

### Strażnicy (telegrafy, `run_guardian.sh general --shots`)
- Generał: błysk ostrza przed doskokiem, pomarańczowy krąg lądowania, smuga bloku — **OK**, czytelne
  (`tests/_out/guardian_general/dash_glint.png`, `leap_down_mark.png`, `guard_block.png`). Kilka kadrów scenariusza ma
  kamerę wewnątrz modelu (`feint_figures`, `phantom_burst`) albo za kamieniem — to kamera narzędzia, nie gra.
- Kolos (`run_guardian.sh colossus --shots`, przed scaleniem): pomarańczowy łuk na posadzce przed uderzeniem i przed
  zamachem, ładowanie promienia, iskry promienia na kolumnie — **OK**, czytelne (`tests/_out/guardian_colossus/slam_raised.png`,
  `sweep_drawn.png`, `beam_on_column.png`). Ten przebieg pokazał też błąd skryptu w grze → **POPRAWIONE** (§4).
- Lamassu (po scaleniu): tor szarży (dwa pomarańczowe pasy), krąg tupnięcia, cień i krąg skoku — **OK**, czytelne
  (`tests/_out/guardian_lamassu/charge_paw.png`, `stomp_land.png`, `hop_shadow.png`); kilka kadrów zasłania kolumna
  (kamera narzędzia).

## 3. Problemy do decyzji (większe niż drobna poprawka)

1. **Regał w bibliotece (pułapka `bookcase_library`) przewraca się niewidocznie.** Kawałek `shelf` w
   `enlightenment_library` ma pusty `Visual` (`Floor1ArtEnlightenment.piece_look` → `_holder("Visual")`), a regały
   rysuje osobno `bookcases()` jako ciągłe biegi wzdłuż ścian. `EnvToppleTool` obraca więc pusty węzeł: lecą kartki
   i drzazgi, regał na ścianie stoi dalej. Log: `"meshes 0 (0 shown)"` przy `tool_bookcase_library_down`; zrzuty
   `tool_bookcase_library_down_close.png`, `_down_above.png`. Propozycja: przy budowie narzędzia dać jego kawałkowi
   własny wygląd (`_bookcase_piece(size)` z niższymi id `lib_bookcase_*_2m`) i wyciąć ten odcinek z biegu w
   `bookcases()` (pominąć przęsła w zasięgu `near` z `EnvCatalog`), albo przenieść pułapkę na regał z własnym wyglądem
   (np. gabinet Sloane'a). Test: w `test_env_floor1` każdy `load_node` narzędzia ma ≥ 1 widoczną siatkę.
   → **POPRAWIONE** na gałęzi `fix-bookcase` (23.10): kawałek, który przejmuje narzędzie z `EnvCatalog`, ma własny
   wygląd (`Floor1ArtEnlightenment._tool_bookcase`: regały dolnego piętra `lib_bookcase_*_2m`/`_1m` z drabinkową szyną,
   pilastry między nimi, dębowe plecy — leżąc twarzą w dół, pokazuje plecy), a biegi w `bookcases()` omijają jego odcinek
   (`run_clear` = drzwi + `tool_cases`, odcinek z tego samego cięcia co szarość: `Enlightenment.shelf_piece`); kinkiet
   dolnego piętra, który wisiał na pilastrze w tym odcinku, przeszedł na pilaster biegu. Wygląd jest rysowany zawsze
   (także bez warstwy środowiska), więc w ścianie nie ma dziury. Upadły regał leży przodem na posadzce
   (`EnvToppleTool._flatten` spłaszcza go o jego przód). Test `test_floor1_art_wings ::
   test_the_bookcase_the_env_tool_brings_down_is_drawn_and_falls_whole` (siatki w `Visual`, bieg nie zachodzi na
   odcinek, żadna lampa na nim, po upadku nic nie stoi w miejscu regału, regał leży w przejściu). W oknie: log
   `meshes 8 (8 shown), drawn box … S: (3.6, 0.35, 5.1)`; zrzut `13_regal_biblioteki_po_upadku.png` (§5). Kadry
   `tool_bookcase_library_warning`/`_warning_above` narzędzie QA dalej oznacza MISSED (kamera za przeszkodą / w stropie
   galerii) — to kamera narzędzia, nie gra.
2. **Galeria portretów przy „zgaśnięciu” jest prawie czarna** (średnia jasność 0,004; jedyne czerwone światło przy
   dalekich drzwiach) — `lamps_enlightenment_portraits_out_06.png`. Propozycja: lampa awaryjna/znak WYJŚCIE w sali albo
   tryb `out` z dolnym progiem ok. 5–8 % w salach bez lamp awaryjnych (latarka i tak wystarcza do gry — decyzja gustu).
3. **Wiązka Heliosa wygląda jak laser** (równy biały walec, też po odbiciu). Propozycja: zanik ku brzegom (fresnel),
   lekkie zwężenie, cieplejszy odcień, pył w wiązce, mniej kryjący rdzeń.
4. **Wzrok portretu nieczytelny z 6 m** (tęczówki 2–3 px; kropka celownika zasłania twarz, gdy patrzy się wprost).
   Propozycja: większy ruch tęczówek albo odblask w oku, ewentualnie zdarzenie tylko gdy strażnik ≤ 4 m od obrazu.
5. **Fale dzwonu jak element interfejsu** (dwa cienkie złote pierścienie). Propozycja: rozmyte drganie powietrza albo
   pył sypiący się z belek; ewentualnie tylko słabsze/grubsze pierścienie. Sprawa gustu właściciela.
6. Żyrandol: wrak leży dokładnie na rozecie tej samej wielkości i z góry się z nią zlewa. Jego AABB po spłaszczeniu
   sięga 0,43 m pod posadzkę (log `drawn box`; AABB obróconej siatki jest zawyżony, a w kadrze z bliska wrak leży na
   posadzce — więc raczej nic nie tonie). Propozycja: przesunąć wrak o pół metra w bok od środka rozety.
7. Skrzynia rakiet: wachlarz ostrzeżenia niewidoczny w stopklatkach (§2).
8. Opcje EN: pierwszy wiersz przycięty u góry listy (§2).
9. Narzędzia QA (nie gra): `trex_awake` w `run_tour.sh` — T-Rex po przebudzeniu schodzi za kolumnę, kadr pusty;
   `americas_pacific_canoe` nie kadruje kajaka (jest w `americas_north`; dobry widok: `--view=kayak_close@-9.5,1.7,-42.0@-5.2,0.9,-44.5`);
   kamera `guardian_scenario` dla Generała w kilku momentach wchodzi w model.

## 4. Poprawione tej nocy

- `597c4c6a` — **podpowiedź zawieszki (`EnvLayer._check_hint`) sprawdzała strefę trafienia, której właściciel był już
  zwolniony** (`is` na zwolnionej instancji → `SCRIPT ERROR` w każdym sprawdzeniu, gdy upadający Kolos był w polu widzenia).
  TDD: `test_env_layer.gd :: test_the_tag_hint_skips_a_hit_zone_whose_owner_is_gone` (czerwony: błąd skryptu; zielony
  po poprawce).
- Narzędzia QA: `6c158847`, `0807560b` (§0).

## 5. Zrzuty dla właściciela

`D:\ClaudeCode\Doomer Shooter\tests\_out\noc_2026-10-22\shots\`:

| Plik | Co pokazuje |
|---|---|
| `01_dziedziniec_noc_z_poludniowego_zachodu.png` | Dziedziniec nocą (295 lamp), księżyc przez szklany dach, Czytelnia |
| `02_ogrod_azji_wisnia_i_zbroja.png` | Ogród Azji: wiśnia, grabiony żwir, zbroja samuraja |
| `03_general_dobywa_miecza.png` | Generał w ogrodzie dobywa miecza (walka strażnika) |
| `04_fpp_strzelba_wyrzut_lusek.png` | Nowe animacje FPP: łamanie strzelby, łuski w powietrzu |
| `05_lamassu_szarza_sztucer.png` | Lamassu szarżuje, strzał ze sztucera (`run_promo.sh`, po scaleniu) |
| `06_hud_paleta_protanopia.png` | Pełny HUD w palecie dla protanopii (pasek zdrowia i bossa `#e6442e`) |
| `07_zyrandol_ostrzezenie_krag.png` | Pułapka: żyrandol w holu skrzypi, pomarańczowy krąg na posadzce |
| `08_lampa_burzowa_plama_ognia.png` | Pułapka: lampa burzowa spadła na obóz w Egipcie, plama ognia |
| `09_kolumna_grecka_po_upadku.png` | Pułapka: pęknięta kolumna rozsypana na bębny w sali waz |
| `10_lampy_przygaszenie_egipt.png` | Niesamowite zdarzenie: przygaszenie lamp galerii Egiptu |
| `11_nakladka_f3_dziedziniec.png` | Nakładka F3 nad Dziedzińcem: FPS, CPU/GPU, draw calls, lampy |
| `12_ognista_skrzynia_w_bibliotece.png` | Ognista skrzynia (hwacha) w stado książek w bibliotece (`run_promo.sh`) |
| `13_regal_biblioteki_po_upadku.png` | Pułapka: regał biblioteki leży plecami do góry w przejściu, w ścianie goły tynk (po poprawce `fix-bookcase`) |

## 6. Stan prac / co dalej

- Zrobione: §1 (tabela GPU przed i po perf-cpu), §2 (listy), §4 (poprawka + narzędzia), §5 (12 zrzutów).
- **Pełny zestaw jednoprocesowo po ostatniej zmianie kodu** (kod jak w `0807560b`, po scaleniu `pietro-1` @0b18d63c):
  **3392 zaliczone, 0 niezaliczonych**, bez linii ERROR, 26 min 34 s (komputer obciążony testami innych agentów).
  Później tylko dokumenty. `pietro-1` poszedł potem dalej (`0b72abef`, fix-guide-stands) — nie scalałem drugi raz.
- Żaden mój proces Godota nie został, blokada okna zwolniona.
- 23.10, gałąź `fix-bookcase` (problem §3.1, `23acbb43`, z `pietro-1` @21dd9d7c): filtry env/art/kolizje 183/0, pełny
  zestaw jednoprocesowo **3397 zaliczone, 0 niezaliczonych**, bez linii ERROR, 24 min 8 s. Do scalenia do `pietro-1`.
- Następny przebieg w oknie (propozycja): opowieść muzeum (widoki `--view=` przy tabliczkach), zmiany świata
  „niesamowitych” zdarzeń (`apply_change` z celem), skala HUD i napisy, 21:9, regał po naprawie §3.1, wachlarz rakiet
  w ruchu (zrzuty co 0,1 s).
- Uwaga porządkowa: przez pomyłkę w ścieżce względnej powstał pusty folder `D:\qa_night\run2` (poza projektem, pusty) —
  do usunięcia ręcznie (narzędzie odmówiło `rmdir` na tej ścieżce).
