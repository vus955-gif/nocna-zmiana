# Reaktywne otoczenie i walka otoczeniem (21.10.2026)

> Gałąź `env-combat` (z `pietro-1` @6e40254). Uwagi właściciela (`docs/backlog-pietro1.md`):
> **22** — więcej elementów otoczenia reaguje na gracza i walkę (obrazy, eksponaty, gabloty, posągi, lampy, książki,
> drzwi, zasłony, żyrandole, sarkofagi…); nie wszystko musi być zniszczalne, ale świat ma sprawiać wrażenie miejsca,
> które istnieje. **23** — elementy *environmental combat*: zestrzelenie żyrandola, przewrócenie ciężkiego eksponatu,
> uruchomienie mechanizmu muzealnego, podpalenie czegoś, instalacja elektryczna przeciw przeciwnikom — **opcjonalne,
> nie zastępują klasycznej walki**. **39** — spójny język interakcji: nic nie wygląda na interaktywne, będąc dekoracją,
> a to, co jest interaktywne, musi się tak czytać. Z listy rozszerzonej: „drobna destrukcja z sensem: szyby, ceramika
> (wazy w Grecji, porcelana w Azji)… pule obiektów i sprzątanie odłamków”, „sztucer przez szkło gablot”.
> Zasady pracy: tylko headless, bez okien i dźwięku; testy najpierw; jeden commit na zadanie; małe, addytywne haki w
> plikach stref/sztuki (równolegle pracują gałęzie mechanik biomów i eskalacji nocy).

## 1. Stan przed zmianą (przegląd kodu)

**Co już reaguje:**
- **Zamki bram** (`src/props/locks/`: łańcuch, deski, rygiel, pęknięta ściana, lina, hak, żaluzja) — własny język
  (`LockRules`: która broń co łamie), stan na stałe w zapisie (`GameState.gates_open`).
- **Gun feel** (`Fx.surface_impact` + `Fx.mark`, `Surface`): każdy strzał w poziom rzuca pył/drzazgi/iskry i zostawia
  ślad zależny od powierzchni; wybuchy osmalają. Poziom poza tym **nie drgnie**.
- **Gablota przeciwpożarowa** (`EmergencyCabinet`) i **wystawa z kartaczownicą** (`ChainedDisplay`), **kłódka skrytki**
  (`PadlockedCase`) — pojedyncze, ręcznie zrobione obiekty; szyba gabloty pęka w odłamki własnej siatki
  (`PanelShards`), hałas budzi eksponaty (`Events.noise_made`), stan na noc w `RunState.used`.
- **Żywe eksponaty**: latające księgi wracające na półki, portrety (śpiące wyglądają jak zwykłe `WallPainting`), mumie
  z sarkofagów — to wrogowie, nie otoczenie.
- **Światło**: lampy w grupach (`main/flicker/emergency/haven/moon_lights`), oprawy w `<grupa>_fixtures`,
  `LevelKit.set_lit` gasi poświatę opraw, `NightModifiers.set_lights` przełącza grupę (zaciemnienie), `LampFlicker`,
  `RoomCuller` (ukrywa tylko na serwerze renderowania — `visible` węzła mówi prawdę). Model światła percepcji
  (`LayoutIllumination`) liczy moc **per grupa i sala** — pojedyncza zgaszona lampa nic w nim nie zmienia.
- **Kolumny Kolosa** (`ColossusColumn`) pękają od promienia strażnika — wzór „pęka → łamie się → bębny”.
- Kawiarnia (`CafeCorner`) — własna gałąź.

**Interfejs obrażeń:** `take_damage(DamageInfo)` na odbiorcy strefy `Hurtbox` (warstwa `HURTBOX`). Trafiają w nią:
hitscan broni (`Hitscan.ray/pierce` — sztucer przebija do N odbiorców), rakiety hwachy i harpun (promień), wybuch
(`Blast.explode`: kula po strefach + strażnik z odległości, własny wybuch strażnika nie zbija go poniżej 50 % zdrowia),
cios (najpierw strefa pod celownikiem, potem najbliższa w kuli). `DamageInfo` niesie `impact` (ciężar 0..1 z profilu
broni, `HitFeel.weight`), `explosive`, `weapon`, `source`, kierunek. Materiały: `ExhibitMaterial` (kolory, dźwięki).
Poziom (`LevelKit`): każdy element ma meta `kit`, `kit_size`, `kit_room` i dziecko `Visual`; szkło greyboxu to osobne
instancje z przezroczystym materiałem, szkło modeli — materiał `glass` (`ArtLibrary`).

**Wniosek:** brakuje warstwy, która nada *zwykłym* elementom (gabloty, lampy, popiersia, obrazy, sztandary, półki,
ceramika) odpowiedź na trafienie, i kilku *celowych* narzędzi walki otoczeniem w skrzydłach — z jednym, czytelnym
znakiem.

## 2. Projekt

### 2a. Warstwa reaktywna (tło: świat żyje, nie jest bronią)

Jedna instalacja na noc piętra: `EnvLayer.install(level, museum)` (hak w `FloorGame.setup`, jedna linia). Przegląda
zbudowany poziom (elementy po meta `kit`, oprawy lamp w `level.lights`, obrazy `WallPainting` muzeum) i dokłada do nich
lekkie węzły `EnvProp` (strefa `Hurtbox` + logika). **Bezczynny rekwizyt nic nie liczy** (`_process` wyłączony), budzi się
na trafienie i zasypia, gdy się uspokoi.

| rodzaj | gdzie | trafienie | ciężkie trafienie / wybuch | stan na noc |
|---|---|---|---|---|
| **gablota** (`EnvGlass`) | element `case` ze szkłem (greybox: przezroczysty materiał; modele: materiał `glass`) | każdy pocisk/cios/wybuch (paralizator nie) — szkło pęka od razu: odłamki, `glass_break`, hałas 14 m (eksponaty przychodzą zobaczyć); odłamki tną eksponaty tuż obok (8); **sztucer przechodzi przez szybę i dalej przez bryłę gabloty** (`Hitscan.pierce`) | — | zbita |
| **lampa wisząca** (`EnvLamp`) | oprawy `ceiling_lamp`, `bulb`, latarnie `lantern` (wiszą na sznurze od stropu) | kołysze się (wahadło, światło kołysze się z nią — cienie tańczą); żarówka pęka od razu (ciemno, bez spadania) | suma obrażeń ≥ wytrzymałości oprawy albo ciężar ≥ 0,75 albo wybuch → klosz **skrzypi 0,7 s** (znak na podłodze, iskry przy mocowaniu), spada: szkło, gaśnie światło (także w modelu percepcji), cios 25 w kręgu 0,9 m (strażnik 10); papierowa latarnia spada bez ostrzeżenia, bo nie rani | zestrzelona |
| **popiersie na cokole** (`EnvBust`) | `bust_plinth` | chybocze się | ciężar ≥ 0,45 / wybuch / suma ≥ 40 → przechyla się przez krawędź od strzału (0,35 s), spada i roztrzaskuje się w marmurowe odłamki własnej siatki, cios 12 tam, gdzie spadnie (zapowiedź żywych popiersi; strażnika nie rani, więc bez telegrafu) | strącone |
| **posąg na cokole** (`EnvStatue`) | `sculpture` 1–2,6 m stojąca na podstawie (≥ 0,3 m nad podłogą), poza arenami i świątynią Nereid | ciężkie trafienie (≥ 0,45) — chybocze się | ciężar ≥ 0,75 / wybuch / suma ≥ 90 → **chwieje się 0,7 s** (pas upadku na podłodze — może zranić), przewraca się od strzału z podstawy na podłogę i pęka: cios 60 na pasie (strażnik 15); podstawa zostaje | przewrócony |
| **obraz** (`EnvPainting`) | `WallPainting` (portrety-wrogowie mają swoje) | przekrzywia się na gwoździu (sprężyna), kolejne trafienia sumują przechył | ciężar ≥ 0,75 / wybuch / przechył ≥ 22° → zsuwa się po ścianie i staje oparty o nią na podłodze | na podłodze |
| **sztandar / zwój** (`EnvBanner`) | `banner` (dziedziniec, zbrojownia Azji) | faluje | 3 trafienia / ciężar ≥ 0,75 / ogień / wybuch → zrywa się i opada zmięty | zerwany |
| **półka z książkami/tabliczkami** (`EnvShelf`) | `shelf` w salach z książkami (Czytelnia, Oświecenie) i tabliczkami (biblioteka Asyrii) | sypią się kartki (`PageFlutter`) i grzbiety / glina — bez zmiany stanu (limit stron jest w `PageFlutter`) | więcej kartek | — |
| **ceramika** (`EnvCeramic`) | mała rzeźba (`sculpture` ≤ 1 m, bez kolizji, na cokole): wazy, księżycowy dzban, seladon | pęka od razu w skorupy, hałas 10 m | — | stłuczona |

Świadomie **poza** warstwą: drzwi (mają własne skrzypienie i nawigację), sarkofagi (to wrogowie), zasłony (na piętrze
nie ma elementu zasłony — sztandary i zwoje grają tę rolę), krzesła i ławki (przesunięcie statycznego ciała po
zapieczonej nawigacji to ryzyko softlocka za mały zysk).

### 2b. Walka otoczeniem — narzędzia ze znakiem

**Znak (jeden w całej grze): czerwona zawieszka konserwatora na obluzowanym mocowaniu.** Stalowa śruba z pulsującym
czerwonym pierścieniem (świeci w półmroku, widać ją z 20–30 m) i biało-czerwona kartka „USTERKA — NIE DOTYKAĆ” na
sznurku. Tylko narzędzia ją mają; nic innego w muzeum nie używa czerwonego pierścienia. Pierwsze wycelowanie w
zawieszkę (raz na noc) daje podpowiedź na HUD („Czerwona zawieszka: obluzowane mocowanie — strzał je zrywa”).
Trafienie zawieszki (dowolna broń, wybuch obok) uruchamia narzędzie od razu; trafienia samego obiektu sumują się
(żyrandol spadnie też po serii w korpus) — zawieszka to droga szybka i czytelna.

**Uczciwość (telegraf):** każde narzędzie, które może zranić, najpierw **ostrzega ≥ 0,6 s** (tu 1,0 s): skrzyp/zgrzyt,
pył z mocowania, drżenie obiektu, a na podłodze znak strefy (`GroundMark` — ten sam język co telegrafy strażników:
ciemniejący cień, rozżarzający się brzeg). Uderzenie dopiero po ostrzeżeniu. Strażnik w strefie dostaje obrażenia jak od
**własnego wybuchu** (`Blast.GUARD_FLOOR`: narzędzie uruchomione przez niego nie zbije go poniżej 50 % zdrowia, zawsze
popchnie). Eksponaty dostają pełny cios (zabicie liczy się strażnikowi: Pył, statystyki) i reagują hałasem.

| skrzydło | sala | narzędzie | uruchomienie | efekt |
|---|---|---|---|---|
| hol / dziedziniec | `entrance_hall` | **żyrandol** (istniejąca oprawa nad środkiem holu) — ZRZUT | zawieszka przy haku w stropie / seria w korpus | spada: krąg 2,4 m — eksponaty 150 + mocne pchnięcie, strażnik 35; iskry, szkło, **gaśnie główne światło holu** (też w modelu percepcji) |
| Egipt | `egypt_gallery` | **lampa sztormowa ekspedycji** na długim łańcuchu z belki nad obozem — ZRZUT + OGIEŃ | zawieszka na haku | spada i rozlewa płonącą naftę: krąg 1,5 m płonie 6 s — podpala eksponaty (mumie w lnie i wosk płoną podwójnie), strażnik w ogniu 4 / 0,5 s |
| Grecja | `greece_vases` | **pęknięty fragment kolumny** (trzy bębny i kapitel na kołysce konserwatorskiej pod zachodnią ścianą, podparte drewnianą zastrzałą) — PRZEWRÓCENIE | zawieszka na klinie zastrzału | zastrzał odskakuje, kolumna przewraca się na wschód między rzędy gablot: pas 1,3 × 4,7 m — eksponaty 140, strażnik 35; górny bęben pęka, reszta leży |
| Oświecenie | `enlightenment_library` | **wysoki regał** (regał przy zachodniej ścianie, z = −17, pod galerią) — PRZEWRÓCENIE | zawieszka na górnym kotwieniu do ściany | przewraca się w nawę: pas 5 × 3,4 m — eksponaty 110 + ogłuszenie 1,5 s, strażnik 30; lawina kartek |
| Asyria | `assyria_nimrud` | **wciągnik łańcuchowy z płytą reliefu** przy rusztowaniu konserwatorów (zachodni koniec sali) — ZRZUT | zawieszka na zapadce wciągnika | płyta spada: krąg 1,4 m — eksponaty 180, strażnik 40; płyta pęka |
| Azja | `asia_korea` | **skrzynia zapasowych strzał ogniowych hwachy** (sala hwachy, przy północnej ścianie) — SALWA | zawieszka na pokrywie (lont) | lont syczy i iskrzy 1,0 s (wachlarz na podłodze), potem 6 rakiet co 0,09 s w wachlarzu ±20° przez salę: każda to strzała hwachy (wybuch, podpalenie); skrzynia zostaje pusta i osmalona |
| Ameryki | `americas_north` | **kamienne koło** (odlew tarczy kalendarza między dwoma kozłami pod południową ścianą, zaklinowane belką i palikiem) — TOCZENIE | zawieszka na paliku | koło kołysze się o klin 1,0 s, potem toczy się 6,5 m na północ (ok. 1,4 s, przyspiesza; było 9 m — patrz sekcja 6, poprawka 3), miażdży każdą rzecz raz (160, strażnik 40), na końcu przewraca się płasko i pęka |

Uzgodnione z gałęzią `biome-mechanics` (#26, mechaniki biomów): ona ma płyty z strzałkami w trzech salach grobowców
Egiptu, sieci pod stropami Asyrii (w Nimrud ≥ 6 m od zachodniego narożnika), lampę łukową z lustrami w sali Nereid,
bijący zegar w sali zegarów, **dzwony** w Azji (także pawilon w sali Korei) i **gaszenie mis ogniowych** w Amerykach,
zawory pary w podziemiach — tu tych miejsc i rekwizytów nie ruszam; jej cele strzałów mają mosiężne/linowe wyglądy, bez
czerwieni (czerwony pierścień i zawieszka zostają wyłącznie znakiem tych narzędzi). Instalacje elektryczne pomijam
(podziemia należą do zaworów pary).

Żadne narzędzie nie stoi w arenie strażnika (Kolos, Lamassu, Centaur, Planetarium, Generał, Wąż) — walki z bossami są
projektowane osobno. Narzędzie jest opcjonalne: sala bez jego użycia gra się jak dotąd.

### Język interakcji (#39) — reguły, których gra się trzyma

1. **Czerwona zawieszka = narzędzie: strzel w mocowanie.** Wyłącznie narzędzia ją noszą; podpowiedź raz na noc.
2. **Co wygląda na kruche, pęka; co wisi, kołysze się i spada; co stoi na cokole, można strącić** (szkło, ceramika,
   popiersia, posągi na podstawach, lampy, obrazy, sztandary) — zawsze tak samo, w każdym skrzydle.
3. **Co może zranić, ostrzega** — skrzyp + znak na podłodze (ten sam co u strażników) ≥ 0,6 s; co nie rani (żarówka,
   papierowa latarnia, obraz, sztandar, popiersie), reaguje od razu.
4. **[E] i podpis pod celownikiem** — przedmioty do użycia ręką (bez zmian); **zamki bram** — własny język łańcuchów,
   desek i rygli (bez zmian); **mechaniki biomów** — mosiądz i liny (gałąź `biome-mechanics`), nigdy czerwień.
5. Reszta wystroju (skrzynie, ławki, kolumny nośne, wielkie posągi na podłodze) jest **bryłą**: zatrzymuje kule jak
   ściana i zostawia ślad (gun feel), niczego nie obiecuje.

### 2c. Wydajność, zapis, softlocki

**Budżet:**
- strefy `Hurtbox` — statyczne `Area3D` (`monitoring = false`), po jednej na rekwizyt; gablota i popiersie mają cztery
  kopie zakotwiczone na bokach bryły (wybuch sprawdza „przez powietrze” środek strefy, a szkło siedzi w bryle gabloty):
  ≤ 420 rekwizytów i ≤ 640 stref (test liczy; **pomiar na greyboksie: 230 rekwizytów, 440 stref**, instalacja
  37–50 ms; **na ubranym piętrze: 240 rekwizytów, 474 strefy, 72 ms** — wszystkie 56 gablot ma szkło w modelu);
- koszt na klatkę (profil CPU `tools/run_cpu_profile.sh --quick`, ubrane muzeum, sekcja „environment”): **0,02 ms
  skryptów w _process, 0,003 ms w tyku fizyki** (pulsowanie zawieszek, sprawdzanie podpowiedzi);
- przetwarzanie — tylko rekwizyty w ruchu (kołysanie, przechył, upadek, ostrzeżenie); naraz najwyżej `MAX_ACTIVE` = 16
  (najstarsze kołysanie gaśnie natychmiast, upadki zawsze dochodzą do końca); bezczynny rekwizyt = 0 kosztu na klatkę;
- ciała fizyczne — **żadnych własnych**: upadki to animacja (tween, deterministyczna, testowalna), odłamki idą przez
  `Fx.chunk/Fx.piece` (wspólny limit 80, znikają po 8 s, uśpione przez silnik) i `PageFlutter` (limit 60 kartek);
  jeden upadek dokłada ≤ 8 odłamków;
- culling — światło zestrzelonej lampy jest wyłączone (`visible = false`), `RoomCuller` go nie włączy (pokazuje tylko
  widoczne węzły); oprawy i rekwizyty w dalekich salach nie mają procesów.

**Zapis i wznowienie — wybór: na noc.** To, co pękło, zostaje pęknięte do końca nocy, także po „Kontynuuj”
(`RunState.used`, id `env:<id>`; zapisywane w `night_progress` jak zbite gabloty i zabici z miejsc spawnu); następna noc
zaczyna się od czystego muzeum. Uzasadnienie: (1) pętla nocy odnawia eksponaty i łup — otoczenie odnawia się z nimi,
inaczej muzeum po kilku nocach byłoby pobojowiskiem bez reakcji; (2) narzędzia mają być *językiem*, którego gracz się
uczy i którego używa noc w noc — trwałe zniszczenie zrobiłoby z nich jednorazowy gadżet; (3) trwałe muszą być tylko
set-piece'y zmieniające drogę (#35/#51), a żadne narzędzie tu drogi nie zmienia (z założenia, patrz softlocki), więc nic
nie jest set-piece'em. Wewnątrz nocy powrót do sali pokazuje ślady walki (#35). Stany przejściowe (kołysanie, przechył
wiszącego obrazu) nie są zapisywane.

**Softlocki — niezmiennik: otoczenie nigdy nie dokłada ani nie przesuwa kolizji blokującej.** Spadające i przewrócone
rzeczy tracą kolizję w chwili ruchu (lecą jako obraz), leżą jako niekolizyjny gruz; przejęte elementy poziomu (regał,
obraz) wyłączają swoje ciało. Nowe stojące narzędzia (kolumna, kozły z kołem, skrzynia rakiet) mają kolizję tylko w
swoim obrysie pod ścianą (z dala od przejść, znaczników i slotów eksponatów ≥ 1,25 m — test) i są przeszkodą
w nawigacji eksponatów (źródło `walk_dynamic`, przebudowa wokół nich, gdy ruszą — poprawka 3 w sekcji 6); kolumna i koło
tracą kolizję, gdy ruszą, skrzynia nigdy się nie rusza (stoi, gdzie stała). Pomiar (22.10, bez rekwizytów w arenach):
3055 kształtów blokujących z warstwą, 3044 po zrzuceniu wszystkiego, nic nowego, nic przesuniętego. Testy: (1) po uruchomieniu wszystkiego na piętrze zbiór kształtów
kolizji WORLD/ENEMY tylko maleje (nic nowego, nic przesuniętego); (2) każde narzędzie: w swojej sali, strefa w sali,
obrys z dala od przejść (≥ 1,25 m od prostokąta przejścia), schodów i znaczników; zawieszka widoczna z podłogi sali;
(3) istniejące testy osiągalności/softlocków/zapisu świata zielone.

### Haki w plikach współdzielonych (addytywne)
- `FloorGame.setup` — instalacja warstwy (2 linie; obok linii `BiomeMechanics.install` z gałęzi biomów — przy scaleniu
  suma obu).
- `WeaponHolder` — cios „po omacku” (kula ciosu) pomija rekwizyty otoczenia (cios w eksponat obok gabloty nie zbija
  szyby zamiast trafić eksponat; wycelowany cios w szybę nadal ją zbija).
- `LayoutIllumination` + `PerceptionWorld` — zgaszenie pojedynczej lampy w modelu światła (`put_out`).
- `NightModifiers.set_lights` — lampa zestrzelona zostaje zgaszona przy każdym przełączeniu grupy.
- `Hitscan.pierce` — strefa z meta `pierced_bodies` przepuszcza pocisk przebijający przez wskazane ciała (szkło gabloty →
  dalej przez jej bryłę).
- `locale/strings.csv` — teksty zawieszki i podpowiedzi.

### Styk z „niesamowitymi” zmianami nocy (gałąź `night-escalation`, `UncannyDirector`)

Recenzja wskazała trzy kolizje z jej efektami (zamiana obrazu, ukrycie elementu, obrót elementu). Po stronie tej
gałęzi jest gotowe API (test `test_env_uncanny`); `night-escalation` nie była jeszcze w `pietro-1` przy scaleniu, więc
podpięcie wywołań należy do scalenia obu gałęzi:
- `EnvLayer.of(get_tree())` — warstwa bieżącego poziomu; `claims(node)` — czy otoczenie odpowiada za element
  (najprościej: `fair_pieces` pomija takie elementy);
- `swap_painting`: `env.rebind(old, fresh)` (najlepiej przed zwolnieniem starego; po zwolnieniu też działa — rekwizyt
  odnajduje świeży obraz po ramie, w której stał). Bez wywołania rekwizyt starego obrazu po prostu przestaje odpowiadać
  (bez błędu skryptu), ale nowy obraz nie reaguje;
- `hide_piece` / pokazanie z powrotem: `env.set_present(piece, false/true)` — strefy trafień znikają i wracają (żadnego
  niewidzialnego posągu do zestrzelenia);
- `turn_piece`: `env.recapture(piece)` — popiersie/posąg/obraz przyjmuje nowe ułożenie za spoczynkowe (bez
  „odskoku” po trafieniu).
Przy okazji: strefy popiersi i posągów siedziały wewnątrz ich brył (pocisk trafiał bryłę) — teraz wystają poza nią.

## 3. Zadania (TDD, commit na zadanie)

1. Plan (ten dokument).
2. `EnvRules` — czyste reguły (progi, ciężar trafienia, ostrzeżenie ≥ 0,6 s, obrażenia strażnika, id zapisu, budżety) +
   testy jednostkowe.
3. `EnvProp` + `EnvLayer` (instalacja, zapis na noc, aktywne/uśpione, budżet) + hak `FloorGame` + test instalacji
   na zbudowanym piętrze i wznowienia.
4. Gabloty i ceramika (szkło, skorupy, hałas, cięcie eksponatów obok) + hak ciosu w `WeaponHolder`.
5. Lampy wiszące (kołysanie z cieniem, zestrzelenie z ostrzeżeniem, gaszenie światła sali + percepcja + odporność na
   przełączanie grupy).
6. Popiersia, obrazy, sztandary, półki.
7. `EnvTool` + `EnvTag` (znak, ostrzeżenie, strefa, obrażenia, uczciwość) + narzędzia: zrzut (żyrandol, lampa z
   ogniem, płyta na wciągniku), przewrócenie (kolumna, regał), salwa (skrzynia rakiet), toczenie (kamienne koło);
   `EnvFire`; katalog na piętrze.
8. Testy na piętrze: rozmieszczenie, widoczność zawieszek, niezmiennik kolizji, zapis/wznowienie (snapshot świata).
9. Podpowiedź na HUD, teksty, telemetria (`EnvLayer.stats()`).
10. Scalenie `pietro-1`, pełny zestaw testów.

## 4. Do sprawdzenia w oknie (później, przez właściciela / sesję z oknem)

- Czytelność zawieszki z 10 / 20 / 30 m w każdej z siedmiu sal (pulsowanie, kolor w świetle sali i przy latarce).
- Ostrzeżenie: czy 1,0 s skrzypienia + znak na podłodze wystarcza, żeby zejść z linii (żyrandol, regał, kolumna).
- Wygląd upadków: żyrandol (skala gruzu na podłodze), regał (obrót przy krawędzi pod galerią), stos bębnów, płyta
  reliefu, przewracana misa — przenikanie przez inne elementy.
- Kołysanie lamp: amplituda i tłumienie, kołyszące się cienie (czy nie mdli).
- Szkło gablot modeli (case_table, display_case, gabloty Asyrii/Oświecenia): czy znikają *tylko* szyby.
- Skrzynia rakiet: czy wachlarz na podłodze czyta się jako „stąd polecą”, iskry lontu, tor rakiet.
- Kamienne koło: toczenie (obrót vs. przesunięcie), czy nie wjeżdża w gabloty/podest bizona, rozpad na końcu; czy odlew
  tarczy nie myli się z oryginałem w świątyni (inny rozmiar, kozły konserwatorskie).
- Plama ognia: wygląd płomieni i światła, czytelność granicy strefy.
- Posągi na cokołach (gabinet osobliwości, metopy, sala Chin): chwianie, upadek z podstawy, czy leżący posąg nie wchodzi
  w ścianę/gablotę; kierunek upadku po „Kontynuuj” (zapis pamięta tylko „przewrócony”, nie kierunek — leży wtedy
  przodem).
- Kolumna grecka: czy zastrzał odskakujący w bok nie wchodzi w gablotę z wazami; kołyska i żelazna obręcz na bębnie.
- Regał w bibliotece: spłaszczony leżący regał (wysokość nad podłogą), kartki wzdłuż nawy.
- Latarnie w Azji: kołysanie na długim sznurze od stropu (wolne), sznur znika przy upadku.
- Żyrandol: czy wrak na podłodze (spłaszczony) czyta się jako zniszczony żyrandol; zawieszka na łańcuchu przy rozecie z 10 m
  (czy nie chowa się w koronie modelu).
- Przycięcie klatki przy pierwszym zbiciu szyby / pierwszej zawieszce w kadrze (od poprawki 7 ich materiały są w
  `ShaderWarmUp`; napis `Label3D` zawieszki i materiały `EnvLooks` narzędzi — nie).
- Wydajność w najgęstszej sali (biblioteka Oświecenia: 53 półki, 8 gablot, 8 lamp) przy serii z kartaczownicy: kartki,
  odłamki, kołysanie kilkunastu lamp naraz (budżet 16).
- Obrazy: przechył na gwoździu i zsunięcie po ścianie bez wchodzenia w ścianę.
- Dźwięki (bez nowych plików — dobrane z istniejących: `glass_break`, `portrait_creak`, `bolt_rattle`, `weight_thud`,
  `rubble`, `break_marble`, `hwacha_fire`, `flare_burn`…): głośność i dopasowanie.
- **Przegląd w oknie 23.10** (`visual-qa-night`, `2026-10-22-przeglad-w-oknie.md` §2–3): zawieszki, znaki i upadki OK; **regał w bibliotece przewraca się niewidocznie** (pusty `Visual` kawałka, biegi regałów rysowane osobno); wachlarz skrzyni rakiet niewidoczny w stopklatkach.

## 5. Stan prac / co dalej

- [x] 1. Plan
- [x] 2. EnvRules (`src/world/env/env_rules.gd`, `tests/unit/test_env_rules.gd`)
- [x] 3. EnvProp + EnvLayer + hak `FloorGame.env` (`test_env_layer`)
- [x] 4. Gabloty i ceramika, cios „po omacku” pomija rekwizyty, sztucer przez szybę (`test_env_glass`)
- [x] 5. Lampy: kołysanie, żarówki, zestrzelenie, światło sali i percepcja (`test_env_lamps`)
- [x] 6. Popiersia, obrazy, sztandary, półki (`test_env_props`) + posągi na podstawach (`EnvStatue`)
- [x] 7. Narzędzia: znak, ostrzeżenie, zrzut/przewrócenie/salwa/toczenie, ogień, katalog (`test_env_tools`)
- [x] 8. Piętro: rozmieszczenie, widoczność zawieszek, budżet, brak blokującej kolizji, zapis (`test_env_floor1`,
  `test_env_save`); poprawki z QA kolizji (koło: kolizja jak rysunek)
- [x] 9. Teksty i podpowiedź; telemetria: `EnvLayer.stats()` → `PerfStats.environment()`, wiersz „Otoczenie” nakładki
  F3 i sekcja „environment” widoku systemów / profilu CPU (po scaleniu `dev-tools`)
- [x] 10. Scalenia `pietro-1` (dev-tools, test-speed), pełny zestaw: 2844/2844 po scaleniu dev-tools; po test-speed
  i API „niesamowitych” zmian: **2864/2864** (6 procesów, 9 min 33 s)

Stan zestawu przed zmianą (pietro-1 @6e40254, ta maszyna, obciążona): 2694 zaliczone, 1 niezaliczony
(`test_serpent_fall … heads_at_the_gate…`, czaszka stoczyła się po schodach — fizyka pod obciążeniem, niezwiązane).

Co dalej (poza tą gałęzią): kierunek upadku posągu nie jest zapisywany (po „Kontynuuj” leży przodem). (Zgaszona misa
ogniowa w modelu światła i rozgrzewka materiałów zawieszki/szyby — zrobione w sekcji 6, poprawki 8 i 7.)

## 6. Poprawki po przeglądzie (gałąź `fix-env`, noc 22/23.10)

Stan: **wszystkie 9 poprawek zrobione** (TDD: każdy test najpierw uruchomiony i czerwony z właściwego powodu, potem
kod), `pietro-1` scalona na początku (97 commitów: mechaniki biomów, eskalacja nocy z wywołaniami `EnvLayer.rebind /
set_present / recapture`, perf-cpu, dostępność, akustyka, bot przejścia…) i na końcu — bez konfliktów.

| # | Poprawka | Stan |
|---|----------|------|
| 1 | `EnvProp.take_damage`: ukryty `target` (`visible == false`) nie przyjmuje trafień | ZROBIONE (`test_env_uncanny.gd`) |
| 2 | Skan wszystkich rekwizytów (gabloty, ceramika, lampy, popiersia, posągi, obrazy, sztandary, półki) pomija sale aren strażników: `EnvLayer.is_arena(room)` (pamięć podręczna), `EnvLayer.skips(room)` = przystań albo arena; `EnvStatue._arenas` usunięte | ZROBIONE (`test_env_layer.gd`, `test_env_floor1.gd`); na piętrze 232 rekwizyty (było 240) |
| 3 | Narzędzia stojące (kolumna, skrzynia, koło): `EnvTool.solids` + `make_solid()` / `drop_solids()`, `EnvLayer.add_obstacle()` (`level.add_walk_source`, jak płyta Lamassu; bez nawigacji ciało zostaje pod narzędziem) i `clear_obstacle()` (przebudowa nawigacji wokół ciała, gdy narzędzie ruszy — także przy „Kontynuuj”); ciała w `walk_dynamic` sprząta narzędzie przy zwolnieniu. Test niezmiennika porównuje z budową BEZ warstwy (dochodzą wyłącznie 3 ciała narzędzi). Koło stało 1,5 m od slotu jaguara (-16,0; -55,3) → wpis w `EnvCatalog` przesunięty z x = -15,5 na **x = -11,1** (na wschód od gablot z maskami; toczy się między podestem bizona a tipi) | ZROBIONE (`test_env_floor1.gd`: `_way`, `bare`, sloty) |
| 4 | `Hitscan.pierce`: strefy `EnvProp`/`EnvTag` nie liczą się do `max_targets` (`Hitscan.is_prop`), osobny limit kroków `MAX_PROP_ZONES` = 24 | ZROBIONE (`test_env_glass.gd`) |
| 5 | `WeaponHolder._attack` (cios wręcz): celowany rekwizyt dostaje cios, a zamach i tak szuka eksponatu w zasięgu. Test był zielony z ZŁEGO powodu (odłamki szyby cięły manekina) — zawężony do ciosu pięści (`weapon == &"fists"`), potem czerwony, potem kod | ZROBIONE (`test_env_glass.gd`) |
| 6 | `EnvDropTool`: `env_broken` na oprawie żyrandola (`_fixture_out()` w `_landed` i `_rest_down`) — wrak nie świeci po przełączeniu obwodu | ZROBIONE (`test_env_tools.gd`) |
| 7 | `ShaderWarmUp`: `EnvTag.warm_set()` = pierścień (świecący i zgaszony), stal/karta/pasek zawieszki, `EnvBreak.invisible()` | ZROBIONE (`test_env_tools.gd`) |
| 8 | `LayoutIllumination.put_back(position)` + hak w `SacredFire`: zgaszona misa znika z modelu światła eksponatów (`put_out`), zapalona wraca (`put_back`) — sama, od ognia, od flary; bez meta `env_broken` (przełączniki obwodu działają na misę jak dotąd) | ZROBIONE (`tests/unit/test_layout_illumination.gd`, nowy `tests/integration/test_sacred_fire_light.gd`) |
| 9 | Harpun wbity w lampę/żyrandol/narzędzie jedzie z nim (`EnvProp.carrier()`: element, ładunek, kamień koła; `Harpoon._impact`); `EnvStrike._query` w partiach (`Hitscan.shape_hurtboxes`, wspólna pętla z `sphere_hurtboxes`) | ZROBIONE (`test_env_lamps.gd`, `test_env_tools.gd`) |

Sprawdzone w oknie (23.10, `run_tour.sh shots --view=…`, cztery ujęcia: z przodu, z ukosa, od żaluzji z holu
północnego, wzdłuż toru): koło w nowym miejscu stoi między drugą gablotą z maskami a tipi, kozły z wyraźnym odstępem
od gabloty, podstawa tipi nie wchodzi w kozły, zawieszka (czerwony pierścień przy paliku) widoczna od wejścia i z
toru. Przy okazji: po 9 m koło położyłoby się płasko na macie jaguara (slot -10,5; -47,5) → **droga skrócona do
6,5 m** (wpis `distance` w `EnvCatalog`, odwracalny; ok. 1,4 s toczenia), koniec przed matą.

Do sprawdzenia w oknie (dopisane): samo toczenie koła w nowym miejscu (6,5 m — czy wystarcza, czy koniec przed matą
jaguara, czy tor obok podestu bizona nie wygląda na „przez niego”); koło w świetle sali jest bardzo ciemne (czarny
krąg — tak było i wcześniej).

Dopiski po przeglądzie `fix-env` (gałąź `fix-env-2`, 23.10): testy harpuna w płycie reliefu, kolumnie i kamieniu koła
(`test_env_tools.gd`; sprawdzone mutacją — bez `carrier()` padają), zgaszona misa zostaje ciemna dla eksponatów po
zaniku i powrocie zasilania, a zapalona w zaciemnieniu świeci dopiero z zasilaniem (`test_sacred_fire_light.gd`),
koło po stoczeniu leży ≥ 1,25 m od slotów i znaczników (`test_env_floor1.gd`), `clear_obstacle()` z tym samym
warunkiem co `add_obstacle()`. Położenie koła bez zmian.

Uwaga: zapis plików Pythonem w trybie tekstowym zamienia LF na CRLF (repo ma `*.gd eol=lf`) — edytować narzędziem Edit.
