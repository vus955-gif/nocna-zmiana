# Nocne QA wizualne — co zbudowano bez okna, obejrzane w oknie (19.10.2026)

> Gałąź `visual-qa` (worktree `close-wings`, od `pietro-1` @ `69f576e`). Wykonawca: jeden agent, tryb nocny (okna przez
> blokadę `with_window.sh`, dźwięk wyciszony). Od 3.10 nikt nie **oglądał** gry: każda funkcja zbudowana bez okna zostawiła
> listę „Do sprawdzenia w oknie”. Ten dokument zbiera te listy w jedną tabelę: pozycja → jak obejrzeć → stan.

## Jak oglądam

- **Wycieczka** (`bash tools/run_tour.sh shots --preset=high`): 97 widoków muzeum + `metrics_high.json` (średnia luminancja,
  udział prawie czarnych pikseli, flaga DARK).
- **Strażnicy** (`bash tools/run_guardian.sh <lamassu|general|serpent> --shots`): 22 / 21 / 25 momentów walki, 1280×720.
- **Nowy scenariusz** `tests/scenarios/visual_qa_scenario.gd` (`bash tools/run_visual_qa.sh dry|shots [--only=…]`), tam, gdzie
  nic nie umiało ustawić kadru. Grupy: `viewmodel` (bronie dwuręczne, przeładowanie sztucera klatka po klatce, łamanie
  strzelby, korba kartaczownicy, przeładowania harpunnika i skrzyni, FOV 110), `looks` (8 wykończeń w księżycu i w lampach,
  3 modyfikacje w spoczynku i w przeładowaniu, błysk inspekcji), `east` (totem, jaguar, pies Fu, zbroja samuraja w swoich
  salach: sen, pobudka, pościg, atak klatka po klatce, oczami strażnika, rozpad), `east_lit` (te same cztery na
  oświetlonym księżycem dziedzińcu — Ameryki to greybox, sale Azji ciemne), `pickups` (8 rodzajów na 5/10/15 m w trzech
  światłach + z bliska), `secrets` (wszystkie 27 wystaw po odkryciu; po jednej z każdego rzędu z bliska, z boku i po
  odbiorze), `hud` (dwa najdłuższe paski strażników obok najdłuższego celu w 1920×1080 i 1280×1024, iskry skrzyni
  ognistych strzał przy obiektywie), `voice` (pasek napisów nad podpowiedzią, trzy głośniki, stojak audioprzewodnika).
  Tryb `dry` (bez okna) sprawdza każdy kadr przed otwarciem okna: kamera w pokoju, nie w ścianie, przedmiot w zasięgu
  wzroku, moment osiągnięty.
- Każdy PNG obejrzany narzędziem Read (arkusze 2×2 / 3×2 i powiększenia fragmentów).

## Tabela

Stan: **ok** (wygląda dobrze) · **poprawione** (commit) · **decyzja** (do właściciela/kontrolera, ze zrzutem) · **uwaga**
(drobne, bez zmian w tej gałęzi). Ścieżki zrzutów względem `tests/_out/` worktree.

### (a) Ręce i przeładowanie (poprawki-viewmodel)

| # | Pozycja | Jak obejrzeć | Stan i co widać |
|---|---|---|---|
| a1 | Lewa ręka pod łożem: sztucer, strzelba, harpunnik, hwacha; kartaczownica (pkt 1, 5) | `--only=viewmodel` → `visual_qa/viewmodel/vm_*_idle` | **ok** — nadgarstki proste, rękaw schodzi w dół-lewo, nic nie wygląda na złamane; lewa ręka kartaczownicy poza kadrem, prawa na korbie przy krawędzi |
| a2 | Przeładowanie sztucera: ręka całkiem pod kadrem, łódka w pięści, wkładanie, pstryknięcie (pkt 2) | `vm_rifle_reload_08…90` | **poprawione** (`bb1ce53`) — sztucer podnosił się do oka: zamek 0,33 m od oka, lewa pięść zasłaniała pół ekranu i łódkę, przy ładownicy wystawał szczyt pięści. Teraz broń idzie w dół i do przodu (zamek ~0,6 m pod linią oczu, pięść ~1/5 wysokości kadru, łódka widoczna w prowadnicach), przy ładownicy pięść cała pod kadrem. Test: `test_viewmodel_anatomy::test_the_rifle_reload_keeps_the_fist_a_fair_size_under_the_eye_line` |
| a3 | Rękaw przy przenosie nie przecina łoża (pkt 3) | `vm_rifle_reload_42…62` | **ok** |
| a4 | Łamanie strzelby: rękaw zgięty w łokciu, koniec poza kadrem (pkt 4) | `vm_shotgun_break_25/50/80` | **ok** |
| a5 | Zegarek na lewym rękawie (pkt 6) | `vm_rifle_reload_50`, `vm_shotgun_idle` | **decyzja** — zegarek (brązowa tarcza po wewnętrznej stronie nadgarstka) widać przy każdym przeładowaniu sztucera i w spoczynku strzelby; zostawić czy przenieść na grzbiet |
| a6 | Prawa ręka w cyklu zamka sztucera | `vm_rifle_bolt_cycle`, `vm_rifle_reload_bolt_home` | **poprawione** (`d3761ed`, gałąź `polish-misc`) — pięść na gałce podchodziła na 0,16 m od oka, do połowy poza prawy dolny róg; teraz przy pracy zamkiem sztucer odchodzi od ramienia (0,17 m do przodu, trochę w lewo i w dół) i pięść zostaje w kadrze. Test: `test_viewmodel_anatomy::test_the_rifle_bolt_cycle_keeps_the_right_fist_in_the_frame` |
| a7 | FOV 110 (sztucer, strzelba, przeładowanie) | `vm_*_fov_max`, `vm_rifle_reload_24/62_fov_max` | **ok** — broń mniejsza, łokcie nadal poza kadrem |

### (b) Trzej nowi strażnicy

| # | Pozycja | Jak obejrzeć | Stan i co widać |
|---|---|---|---|
| b1 | Lamassu: zejście z cokołu, IK kopyt, skrzydła, podmuch, tupnięcie, skok (cień/lot/lądowanie), ogłuszenie, upadek, znaczniki (straznik-lamassu 1–8) | `run_guardian.sh lamassu --shots` → `guardian_lamassu/*` | **ok** — kopyta na cokole i posadzce, skok z pierścieniem cienia i falą, pęknięcia świecą, upadek na bryły z żarem; ogłuszenie: twarz przy podstawie geniusza |
| b2 | Lamassu: faza 2 (wojownicy z reliefów) (pkt 10) | `relief_warriors` | **uwaga** — kadr scenariusza za ciasny, wyjście z płyty słabo widać; do obejrzenia w grze |
| b3 | Generał: składanie zbroi, dobycie, jodan, doskok z błyskiem, salwa z okapu, faza 3 (zwód), upadek | `run_guardian.sh general --shots` → `guardian_general/*` | **poprawione** (`f14b2e0`) — po pobudce **kołczan wisiał w powietrzu obok stojaka, a pochwa leżała na żwirze** i oba chodziły za nim w tej odległości do końca walki (części nieposuwane przez pozę zostawały tam, gdzie zostawiła je ostatnia klatka lotu). Reszta **ok**: pozy miecza, doskok z pasem, łuk na okapie, upadek |
| b4 | Generał: płatki fazy 3 (gęstość, wir, fantom) | `feint_figures`, `phantom_burst` | **poprawione** (`3a949e2`) — płatki burzy i opadające w ogrodzie były **płaskimi różowymi prostokątami** (z bliska jak konfetti z kwadratów); teraz mają kształt płatka (owal z wcięciem) |
| b5 | Wąż: pierścień, brama, plucie, wypad, omiatanie, upadek z mozaiką (straznik-waz) | `run_guardian.sh serpent --shots` → `guardian_serpent/*` | **ok** w tym, co widać (głowy, plucie z pierścieniami, upadek ze świecącymi płytkami); **uwaga**: świątynia Ameryk to dziś greybox (ubiera ją inna gałąź), część kamer `serpent_moments` (`ring_closed`, `arches`, `heads_rise`) nie trafia w przedmiot — do przeliczenia po ubraniu sali |
| b6 | Pistolet strażnika „wisiał” w kadrach kamery swobodnej | `guardian_*` | **poprawione** (`86d4007`) — scenariusz chowa broń pierwszoosobową na czas zrzutu |

### (c) Wrogowie wschodu (wrogowie-wschod)

| # | Pozycja | Jak obejrzeć | Stan i co widać |
|---|---|---|---|
| c1 | Totem: sen, pobudka, oczy, plucie z twarzy, rozpad (kawałki, czapa) | `--only=east,east_lit` → `visual_qa/east*/(lit_)totem_*` | **ok** — twarze czytelne, świecące oczy, pocisk widać, rozpad na bloki i czapę bez przenikania |
| c2 | Jaguar: sprint na czworakach, skok z maczugą, cios | `(lit_)jaguar_*` | **poprawione** (`2449c5c`, `polish-misc`) — w sprincie lewa łapa wisiała 0,38 m nad podłogą, pięść z maczugą 0,51 m, a stopy (0,34 m) i koniec ogona (0,34 m) wchodziły w podłogę. Teraz kłus „na niedźwiedzia”: biodra niżej i pochylone, kręgosłup za poziom, barki zsunięte, każda kończyna sięga swojego miejsca na podłodze (odwrotna kinematyka dwóch kości, pary po przekątnej), maczuga ciągnie się do tyłu, tarcza obrócona i podsunięta, ogon z tyłu. Test: `test_jaguar::test_sprinting_its_paws_reach_the_floor_and_nothing_sinks`; nowy kadr `(lit_)jaguar_sprint_side_*` |
| c3 | Pies Fu: chód, szarża, iskry grzebnięć, kula na cokole, posąg vs żywy | `(lit_)fu_dog_*`, wycieczka `asia_china_columns` | **ok** — kamienny posąg czyta się jako kamień (szary), żywy jako zielony brąz; iskry grzebnięć widoczne |
| c4 | Zbroja samuraja: yari poziome w pchnięciu, sode, żar oczu | `(lit_)samurai_armor_*` | **ok** — drzewce poziome, kapelusz jingasa i żar oczu czytelne |
| c5 | Czytelność wszystkich w świetle sal (Ameryki pn., Chiny, Zbrojownia) | `east/*` | **decyzja** — w swoich salach wrogowie to ciemne sylwetki z rimem; Ameryki to jeszcze greybox, a Zbrojownia ma czarną podłogę (patrz d4) |

### (d) Oprawa Asyrii/Azji i najciemniejsze widoki

| # | Pozycja | Jak obejrzeć | Stan i co widać |
|---|---|---|---|
| d1 | Asyria: Brama Chorsabadu z lamassu, pochodnie, stele, dziedziniec z krenelażem, Nimrud, Sala Lwów (p4 lista) | `tour/assyria_*` | **ok** — brama, posągi w bryłach, łuk z glazury, krenelaż na niebie, pas lwów, rusztowanie |
| d2 | Asyria: widok `assyria_lions_pit` | `tour/assyria_lions_pit` | **poprawione** (`ac71661`, `polish-misc`) — kamera przeniesiona na południowy koniec dołu, między sloty; `run_tour.sh dry` zgłasza teraz widok stojący < 1,2 m przed slotem uśpionego eksponatu (tak znalazły się jeszcze `court_balcony`, `library_gallery_walk`, `library_wall`, `assyria_freight` — przesunięte) |
| d3 | Azja: Budda w snopie, słupy, lampiony, Korea (wóz hwacha, dzwonnica), ogród (herbaciarnia, wiśnia, latarnie, staw) | `tour/asia_*` | **ok** — ogród i dziedziniec Asyrii to najładniejsze kadry piętra |
| d4 | **Najciemniejsze sale parteru** (uwaga właściciela „niektóre sekcje na powierzchni zdecydowanie za ciemne”) | `tour/metrics_high.json` | **decyzja** — 26 z 82 widoków nad ziemią ma flagę DARK; lista i propozycja niżej |
| d6 | Wycieczka: paralizator strażnika „wisiał” w widoku dyżurki | `tour/booth_security` | **poprawione** (`54dd61a`) — scenariusz chowa broń pierwszoosobową w kadrach kamery swobodnej |
| d5 | Wycieczka: zaciemnienie wybudza Kentaura | `tour/blackout_*` | **poprawione** (`ac71661`, `polish-misc`) — strażnik w `blackout_parthenon` patrzy z sali metop przez wylot areny (nie budzi Kentaura); kadry strażnika bez HUD (pasek T-Reksa z `trex_awake` też już nie wisi), obudzony strażnik wraca do snu; dry zgłasza widok, w którym strażnik obudziłby strażnika |

**Najciemniejsze widoki nad ziemią** (średnia luminancja; podziemia 0,040 to „akceptowalnie ciemne” według właściciela;
Grecja 0,238, dziedziniec 0,242):

| widok | średnia | prawie czarne |
|---|---|---|
| `egypt_tombs` | 0,019 | 89 % |
| `egypt_tomb_hall` | 0,021 | 86 % |
| `egypt_vestibule` | 0,021 | 85 % |
| `assyria_library` | 0,023 | 83 % |
| `portraits` (Oświecenie) | 0,023 | 87 % |
| `assyria_lions_gallery` | 0,027 | 78 % |
| `asia_armor_rows` | 0,027 | 88 % |
| `library_rifle` (Oświecenie) | 0,029 | 80 % |
| `assyria_balawat_doors` | 0,029 | 79 % |
| `cabinet_dioramas` (Oświecenie) | 0,032 | 77 % |
| `asia_armor_shoji` | 0,032 | 89 % |
| `assyria_axis_obelisk` | 0,033 | 76 % |
| `egypt_colossi_row` | 0,034 | 72 % |
| `north_hall` | 0,036 | 76 % |
| `asia_porcelain` | 0,037 | 63 % |
| `egypt_gallery_long` | 0,037 | 68 % |

Średnio na skrzydło: Egipt 0,052 (ciemniej niż połowa podziemi), Oświecenie — sale boczne 0,02–0,03 (sama biblioteka
0,089), Asyria 0,108, Azja 0,168, Grecja 0,238. Wspólny objaw: **czarna podłoga** — lampy oświetlają ściany i sufity
(lampiony, kinkiety, reflektory na eksponatach), światło nie schodzi na posadzkę. **Propozycja** (do decyzji, bo to
smak i całe skrzydła): tą samą metodą co P4 (`floor1_light_recipe.gd`: `lamp_energy` 1,25–1,35 + lampy `fill` bez
mgły i cienia) dla Egiptu (przedsionek, galeria, grobowce), sal bocznych Oświecenia i Zbrojowni; cel ≥ 0,05 średniej
i < 70 % prawie czarnych pikseli, nie ruszając podziemi. Nie robione w tej gałęzi.

### (e) Pickupy, wystawy sekretów, HUD, głos

| # | Pozycja | Jak obejrzeć | Stan i co widać |
|---|---|---|---|
| e1 | Pickupy z 5/10/15 m w księżycu, lampach, czerwieni (czytelne-pickupy §5) | `--only=pickups` → `visual_qa/pickups/*` | **ok** z 5 m (rodzaj po kolorze i sylwetce) i z 10 m (kolor); **decyzja** z 15 m: w cieniu dziedzińca i w ciemnej bibliotece tylko kolorowe kropki, apteczki nie odróżnić (rim celowo „widoczny, nie świecący”; opcja: `ArtLibrary.PICKUP_RIM` w górę albo ciemne sale jaśniej — d4) |
| e2 | Cyfry slotów z bliska, tabliczki harpunów/strzał | `pickups_*_close_*` | **ok** — cyfry 2/3/4/5 czytelne z 2,5 m, apteczka biała z krzyżem |
| e3 | HUD: cyfra slotu w kolorze broni | wszystkie kadry z HUD | **ok** — nie gryzie się z bursztynem |
| e4 | Wystawy sekretów: kasetka / cokół / gablota, reflektor, tabliczka (nagrody-sekretow §5) | `--only=secrets` → `visual_qa/secrets/*` | **ok** — wszystkie 27 widać od progu, reflektor nie wychodzi za ścianę; **pokrywa kasetki** otwiera się w górę (`secret_greece_1_close/_side`); zapas nocny (pudełko + apteczka) obok kasetki nie wchodzi w ścianę; po odbiorze zostaje cokół z tabliczką |
| e5 | Wykończenia na broniach (8) w księżycu i lampach | `--only=looks` → `look_*` | **ok** — barwienie nie brudzi drewna i stali |
| e6 | Części modyfikacji: czok, przeziernik, szpulka | `mod_*` | **poprawione** (`920334f`) — kołnierz czoka był **pełnym okrągłym dyskiem 10 cm** wokół luf (złoty talerz u wylotu) i **nie był na lufach**: przy łamaniu strzelby zostawał w powietrzu przed strażnikiem. Teraz owalna obręcz na lufach, 4 mm ponad nimi. Przeziernik i szpulka **ok** |
| e7 | Pasek bossa z najdłuższymi nazwami, cel obok (fix-hud) | `--only=hud` → `hud_bar_*_1920x1080`, `_1280x1024` | **ok** — cel zawija się obok paska, pasek na środku i na ekranie w obu rozdzielczościach |
| e8 | Iskry skrzyni ognistych strzał przy obiektywie (fix-hud) | `hud_firechest_sparks_050…350` | **ok** — bez białych prostokątów przy obiektywie |
| e9 | Pasek napisów nad podpowiedzią (glos-g1) | `--only=voice` → `voice_subtitles_*` | **poprawione** (`4d90772`) — kwestia w dwóch wierszach rosła w dół i wchodziła na pasek podpowiedzi HUD; teraz rośnie w górę |
| e10 | Głośniki na ścianach dziedzińca i przedsionka Rosetty, stojak przy Kamieniu | `voice_loudspeaker_*`, `voice_audioguide_*` | **poprawione** (`2b1d3d7`) — głośnik przedsionka Rosetty „nad drzwiami” wisiał **w powietrzu w środku 7-metrowego łuku** do dziedzińca; przeniesiony na ścianę obok łuku. Głośniki dziedzińca i stojak **ok** (stojak nie zasłania osi przejścia) |

## Zrzuty dla właściciela (`tests/_out/visual_qa/`, worktree `close-wings`)

1. `01_sztucer_przeladowanie_PRZED.png` — przeładowanie sztucera w połowie, przed poprawką: pięść na pół ekranu zasłania łódkę.
2. `02_sztucer_przeladowanie_PO.png` — to samo po poprawce: zamek niżej i dalej, łódka w prowadnicach widoczna.
3. `03_general_kolczan_na_plecach_PO.png` — Generał dobywa miecza; kołczan i pochwa na nim (przed: kołczan wisiał w powietrzu przy stojaku, pochwa na żwirze).
4. `04_general_platki_PO.png` — zwód fazy 3: płatki w kształcie płatków (przed: różowe kwadraty).
5. `05_czok_przy_lamaniu_PO.png` — strzelba z kołnierzem czoka w przeładowaniu: kołnierz na lufach (przed: złoty dysk wiszący w powietrzu).
6. `06_jaguar_cios_dziedziniec.png` — jaguar z maczugą nad głową na dziedzińcu (wróg wschodu w dobrym świetle).
7. `07_ZA_CIEMNO_egipt_grobowce.png` — najciemniejszy widok nad ziemią (średnia 0,019): do decyzji d4.
8. `08_ZA_CIEMNO_zbrojownia.png` — Zbrojownia (0,027): lampiony świecą na sufit, podłoga czarna.
9. `09_pickupy_10m_ksiezyc.png` — 8 pickupów z 10 m w księżycu: kolory czytelne.
10. `10_pickupy_15m_biblioteka.png` — z 15 m w bibliotece: tylko kropki (decyzja e1).
11. `11_kasetka_sekretu_pokrywa.png` — mała wystawa sekretu: kasetka z otwartą pokrywą, zapas nocny obok.
12. `12_napisy_nad_podpowiedzia_PO.png` — kwestia Heńka w dwóch wierszach nad paskiem podpowiedzi (przed: wchodziła na niego).

Pełne serie: `tests/_out/visual_qa/<grupa>/`, `tests/_out/guardian_<id>/`, `tests/_out/tour/` (+ `metrics_high.json`).

## Poprawki po QA (gałąź `polish-misc`, worktree `voice-g1`, 19.10 w nocy)

Od `pietro-1` @ `bee9b06`. Każda poprawka z testem, obejrzana w oknie (przez blokadę), jeden commit. Zrzuty przed/po:
`tests/_out/polish_misc/` (worktree `voice-g1`).

| # | Co | Commit | Jak sprawdzone | Stan i co widać |
|---|---|---|---|---|
| p1 | **Mury ogrodu japońskiego** (arena Generała): 14 m gołego szarego kamienia | `7625d64` | `test_floor1_art_east::test_the_garden_walls_wear_a_tsuiji_and_the_museums_court_front`; wycieczka `asia_garden_*` (+ nowe `asia_garden_south/east/north`), `run_guardian.sh general --shots` i `--dry` (21 momentów, 0 pominiętych) | **poprawione** — do kapinosu mur tsuiji-bei: kamienny cokół, glina między cedrowymi słupami (co ~2,4 m, przy każdym przejściu), cedrowa belka pod dachówką; nad nim fasada muzeum jak piętro holu: gzyms kordonowy 4,5 m, pilastry holu między przęsłami, w każdym przęśle okno skrzynkowe w wapiennym obramieniu (parapet, gzyms nadokienny) i okienko attyki — większość ciemnych (księżyc w szybie), co czwarte świeci, zasłony na różnej wysokości; gzyms wieńczący pod niebem. Południowa ściana (3 lica, 26 m) jednym rytmem. Nad kapinosem dwie sosny (wschód, północ) i trzy kępy bambusa „zza muru” — nic poniżej 3 m, nic bliżej niż 6 m od grzędy Generała, nic w przejściach, bez kolizji (test). Na fasadzie herbaciarni tylko część nad okapem. Czyta się jako ogród na dziedzińcu wewnątrz muzeum; Generał na grzędzie dobrze widoczny na tle jasnego kamienia i okien (`volley_draw`) |
| p2 | Kamery wycieczki: `assyria_lions_pit`, kadry zaciemnienia | `ac71661` | `run_tour.sh dry`: 127 widoków, 0 problemów (stare pozycje: „0,6 m before an exhibit's slot”, „the guard here wakes centaur”) | **poprawione** — patrz d2, d5 |
| p3 | Łapa jaguara w sprincie | `2449c5c` | test jaguara (czerwony przed poprawką), `run_visual_qa.sh shots --only=east_lit` | **poprawione** — patrz c2. W oknie: nisko, głowa do przodu, obie przednie łapy na podłodze, maczuga ciągnie się za prawą łapą (`after_lit_jaguar_sprint_zoom.png`); kadr z boku `lit_jaguar_sprint_side_0` złapał dopiero początek opadania |
| p4 | Prawa pięść w cyklu zamka | `d3761ed` (+ większy odjazd w następnym commicie) | test anatomii (czerwony przed), `--only=viewmodel` | **poprawione** — patrz a6. W oknie (`after_vm_rifle_bolt_cycle`, `_reload_bolt_home`): sztucer mniejszy, pięść dalej od prawej krawędzi, ale wciąż duża przy dolnej krawędzi (to dłoń ćwierć metra od oka) — **decyzja**: zostawić czy dać inną pozę (np. dłoń z boku gałki) |
| p5 | Przemalowana trumna mumii (`egypt_tomb_passage`) | — | wycieczka `egypt_tomb_passage` | **ok, bez zmian** — stoi przy ścianie korytarza jako trumna antropoidalna: kremowy korpus z ciemnymi pasami, kształt czytelny; w czerwonym świetle korytarza malowana twarz nieczytelna z 5 m; obok ciemny pionowy pręt (stojak) — nic nie przebija, nic nie wisi (`coffin_egypt_tomb_passage.png`) |
| p6 | Biblioteka Królewska: zielony znak wyjścia na środku tablicy KING'S LIBRARY (prośba kontrolera) | `d51e6fa`, `fb3e635` | `test_floor1_art_wings::test_the_kings_library_plate_clears_the_doorways_exit_sign` (czerwony przed obiema poprawkami); wycieczka `voice_library` | **poprawione** — tablica podniesiona z 7,5 na 8,2 m (nad znakiem wyjścia, pod gzymsem); wtedy zakryła głośnik Systemu z gałęzi głosu (8,0 m, środek łuku) — głośnik przesunięty o 2,3 m wzdłuż ściany, nadal nad łukiem. W oknie: „BIBLIOTEKA KRÓLEWSKA” czytelna w całości, znak wyjścia pod nią, głośnik obok (`library_plate_before_after_crop.png`) |

**Do sprawdzenia w oknie (zostało):** kadr jaguara z boku w pełnym sprincie (scenariusz łapie go za wcześnie — jaguar szybko
wchodzi w zasięg skoku; poza widać na `after_lit_jaguar_sprint_zoom.png`). Po scaleniu gałęzi głosu nowa kontrola wycieczki
złapała trzy jej widoki przed slotami eksponatów (`voice_asia_shutter`, `voice_stand_buddha`, `voice_stand_metopes`) — przesunięte
o krok (`da23172`), obejrzane w oknie: stojaki i żaluzja w kadrze.
**Uwagi na później:** pasy stropu między świetlikami ogrodu (14–15,5 m) wciąż wyglądają jak gołe belki nad dziedzińcem (widok
`asia_garden_up`, `volley_draw`) — kandydat na kratownicę szklanego dachu albo gzyms wzdłuż ich krawędzi; poza zakresem tej gałęzi.

## Stan prac / co dalej

- **Zrobione:** zbiór list; scenariusz `visual_qa_scenario.gd` + `tools/run_visual_qa.sh` (`edf80d2`, `644c698`); pełna
  wycieczka (97 widoków) i trzy walki strażników nagrane i obejrzane; 7 poprawek z testami (stan „poprawione” w tabeli:
  `f14b2e0` kołczan/pochwa Generała, `bb1ce53` przeładowanie sztucera, `4d90772` napisy, `2b1d3d7` głośnik Rosetty,
  `86d4007` / `54dd61a` broń w kadrach kamery swobodnej (strażnicy, wycieczka), `920334f` kołnierz czoka, `3a949e2`
  płatki) — każda gry obejrzana w oknie po poprawce.
- **Do decyzji właściciela/kontrolera:** a5 (zegarek na rękawie), d4 + c5 (ciemne sale parteru: lista i propozycja wyżej),
  e1 (pickupy z 15 m w cieniu).
- **Uwagi bez zmian:** b2, b5 (kamery `serpent_moments` po ubraniu świątyni). a6, c2, d2, d5 poprawione w gałęzi
  `polish-misc` (sekcja „Poprawki po QA” wyżej), tam też mury ogrodu (p1), trumna (p5) i tablica biblioteki (p6).
- Nie ruszane (inne gałęzie): Ameryki i dach, zachowanie wrogów, kawiarnia/zmęczenie, muzyka.
- **`polish-misc`:** dwa razy `git merge pietro-1` (czysto; ostatnio @ `4ebf292`, głos g2) → pełny zestaw **2590 zielonych**, 1 czerwony: nowy test tablicy biblioteki, bo zestaw wczytał strefę Oświecenia sprzed przesunięcia głośnika (`fb3e635`, w trakcie przebiegu); po zmianie `--filter=floor1_art_wings,voice_props` 22 zielonych. `run_tour.sh dry`: 148 widoków, 0 problemów. `run_guardian.sh general --dry`: 21 momentów, 0 pominiętych.
- `git merge pietro-1` (@ `55b770e`, czysto) → `07bb07a`: pełny zestaw 2403 zielonych; potem `pietro-1` ruszył (scalone
  ubranie Ameryk i dachu, @ `08fda90`, czysto) → `7f021b7`: 2426 zielonych; i jeszcze raz (muzyka, ekologia wrogów,
  @ `pietro-1` z 19.10 rano, czysto) → `fd73ece`: **pełny zestaw 2528 zielonych, 0 czerwonych**, bez linii ERROR.
  Ostatnie scalenie (`polish-americas`, nagrody na podłogach, czysto) → `cd760e7`: zestaw dotkniętych obszarów
  (`--filter=voice_props,subtitle,viewmodel,weapon_look,general,floor1_particles,floor1_art_americas,floor1_art_roof,art_asia`)
  143 zielonych; pełny zestaw na `cd760e7` — przy scalaniu do `pietro-1`.
  Ameryki są już ubrane — kadry totemu i jaguara w ich sali oraz Węża (b5, c5) warto nagrać jeszcze raz
  (`run_visual_qa.sh shots --only=east`, `run_guardian.sh serpent --shots`).
