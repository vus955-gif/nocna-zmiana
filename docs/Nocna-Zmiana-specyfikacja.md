# Nocna Zmiana — pełna specyfikacja projektu

> Tytuł roboczy. Roguelite boomer shooter FPP o nocnym stróżu w muzeum, którego eksponaty budzą się do życia.
> **Stan na 1 października 2026.** Dokument opisuje grę tak, jak jest zbudowana (gałąź `etap-1a-piaskownica` @ `2fdb8c9`), i zbiera wszystkie decyzje od 25 września. Gdy decyzja się zmienia, zmienia się ten plik.
> Wszystkie liczby to punkt wyjścia do strojenia po testach gracza.
>
> Dokumenty źródłowe:
> - [Projekt MVP (HTML, 25.09)](superpowers/specs/2026-09-25-nocna-zmiana-design.html)
> - [Etap 2 — projekt szczegółowy (30.09)](superpowers/specs/2026-09-30-etap-2-projekt.md) · [Rozbudowa pierwszego obszaru (1.10)](superpowers/specs/2026-10-01-rozbudowa-projekt.md)
> - Plany z sekcjami „Odstępstwa” i „Poprawki po przeglądzie”: [1a](superpowers/plans/2026-09-25-etap-1a-piaskownica-walki.md) ([odstępstwa](superpowers/plans/2026-09-25-etap-1a-odstepstwa.md)), [2a](superpowers/plans/2026-09-30-etap-2a-petla-nocy.md), [2b-1](superpowers/plans/2026-09-30-etap-2b1-lobby.md), [2c-1](superpowers/plans/2026-09-30-etap-2c1-popiersie-trex.md), [integracja nocy](superpowers/plans/2026-10-01-integracja-noc.md), [świat lobby](superpowers/plans/2026-10-01-swiat-lobby.md), [zawartość](superpowers/plans/2026-10-01-zawartosc.md)
> - Przewodniki (HTML): [styl graficzny](art/styl-przewodnik.html) · [dźwięk](audio/dzwiek-przewodnik.html)

---

## Spis treści

1. [Wizja](#1-wizja)
2. [Zasady współpracy i ograniczenia](#2-zasady-współpracy-i-ograniczenia)
3. [Zakres MVP](#3-zakres-mvp)
4. [Walka](#4-walka)
5. [Mapa: lobby muzeum](#5-mapa-lobby-muzeum)
6. [Cel nocy: sekwencja przebudzenia](#6-cel-nocy-sekwencja-przebudzenia)
7. [Pętla roguelite i progresja](#7-pętla-roguelite-i-progresja)
8. [Interfejs, sterowanie i opcje](#8-interfejs-sterowanie-i-opcje)
9. [Oprawa graficzna i dźwięk](#9-oprawa-graficzna-i-dźwięk)
10. [Technologia i architektura](#10-technologia-i-architektura)
11. [Testowanie](#11-testowanie)
12. [Etapy realizacji i stan prac](#12-etapy-realizacji-i-stan-prac)
13. [Parametry rozgrywki](#13-parametry-rozgrywki)
14. [Poza zakresem MVP](#14-poza-zakresem-mvp)
15. [Rejestr decyzji](#15-rejestr-decyzji)
16. [Otwarte kwestie dla właściciela](#16-otwarte-kwestie-dla-właściciela)

---

## 1. Wizja

**W jednym zdaniu:** jesteś nocnym stróżem w wielkim muzeum. Co noc eksponaty budzą się do życia i atakują. Żeby to zakończyć, schodzisz coraz niżej, do najgłębszych poziomów muzeum, gdzie ukrywa się źródło przebudzeń.

| Aspekt | Ustalenie |
|---|---|
| **Gatunek** | boomer shooter z mechanikami roguelite, widok z pierwszej osoby |
| **Inspiracje** | klimat filmu *Noc w muzeum*; walka i estetyka Doom 2 i Quake'a; pętla progresji z roguelite'ów; odzyskiwanie waluty z Dark Souls |
| **Ton** | mroczny z przymrużeniem oka: nocne, puste muzeum, latarka, humor w notatkach i opisach. **Im głębiej, tym mroczniej** |
| **Walka** | mięsista i satysfakcjonująca, ale **bez bullet hella** i **nie try-hard**, zwłaszcza na początku. Każdy atak wroga ma czytelną zapowiedź |
| **Ruch** | umiarkowany, „strażnik, nie komandos”. Chód spokojniejszy niż w Doomie, sprint i unik (dash) kosztują wytrzymałość |
| **Gore** | **zależne od materiału**, bez prawdziwej krwi: wosk, trociny, odłamki marmuru, kości, płótno, bandaże, iskry |
| **Rytm nocy** | „nocna zmiana” dosłownie: dyżur trwa od **23:00 do 6:00**. O 3:00 wybija godzina duchów, a świt kończy noc bez śmierci, ale i bez postępu celu |

---

## 2. Zasady współpracy i ograniczenia

- **Podział ról:** użytkownik jest projektantem i graczem. Nie zajmuje się game devem i nie chce się go uczyć. **Claude robi całą grę:** kod, poziomy, modele, tekstury, dźwięki i muzykę. Użytkownik decyduje o wizji i wrażeniach oraz testuje grę.
- **Praca autonomiczna od 30 września.** Na prośbę właściciela („kontynuuj samodzielnie do końca MVP, potem dopieść jeden obszar do poziomu Steam”, a później „rozbuduj istniejącą grę… decyzję pozostawiam tobie”) decyzje podejmował Claude. Wszystkie są w [rejestrze](#15-rejestr-decyzji), a te, które warto potwierdzić, w [sekcji 16](#16-otwarte-kwestie-dla-właściciela).
- **Wszystko na dysku D:.** Dotyczy instalacji, ale też plików gry: zapisu, opcji, logów i pamięci podręcznych silnika (szczegóły w [7.8](#78-gdzie-leżą-pliki)).
- **Tylko darmowe narzędzia**, najlepiej open source. Wszystkie assety (modele, tekstury, efekty, muzyka) powstają ze skryptów w repozytorium. Zewnętrznych paczek nie używamy.
- **Narzędzia na maszynie:**
  - Godot 4.7.2 w `tools/godot/` projektu (w osobnych drzewach roboczych to złącze katalogów, poza gitem),
  - Blender 5.1 (`D:\Program Files\Blender Foundation\Blender 5.1\`), także jego Python z numpy do tekstur i syntezy dźwięku,
  - szablony eksportu Godota dla Windows.
- **Okna:** właściciel pracuje na tym komputerze. Uruchomienia z oknem są rzadkie, krótkie i ciche (`--windowed --audio-driver Dummy`). Wszystko inne działa bez okna (`--headless`).
- **Produkt dla gracza:** samodzielny plik **`build/NocnaZmiana.exe`** (jeden plik z wbudowanymi danymi; obok tworzy folder `save/`). `Graj.bat` uruchamia wersję roboczą.
- **Sposób budowy:** planowanie i budowa w osobnych sesjach. Budowę prowadzą podagenci w osobnych drzewach roboczych, często równolegle (np. 2a, 2b-1 i 2c-1 naraz). Commit po każdym zadaniu, potem przegląd zgodności i przegląd kodu. Każdy plan ma sekcje „Odstępstwa” i „Poprawki po przeglądzie”. Kontroler scala wszystko do `etap-1a-piaskownica` (nazwa historyczna).
- **Dokumenty:** raporty, analizy i przewodniki w HTML. Ten plik jest w Markdown na wyraźną prośbę.

---

## 3. Zakres MVP

MVP ma odpowiedzieć na jedno pytanie: **czy ta pętla jest fajna?** Od 30 września obowiązuje zasada: **najpierw kompletny i dopieszczony pierwszy obszar (lobby), dopiero potem nowe piętra.** Dlatego MVP urosło ponad plan z 29 września.

| Element | Plan z 29.09 | Zbudowane (1.10) |
|---|---|---|
| Poziomy | lobby + kanciapa | lobby: hol z balkonem, 3 sale, 3 korytarze, kanciapa, składzik, 3 kryjówki sekretów, klatka schodowa w dół |
| Bronie | 4 | **6:** pięści, paralizator, pistolet, strzelba, kartaczownica, rakietnica sygnałowa |
| Wrogowie | 4 typy + boss | **6 typów + boss:** figura woskowa, wypchany wilk, rycerz, lewitujące popiersie, stado raptorów, portret; szkielet T-Reksa |
| Przystanie | 2 | 2: kanciapa ochrony, składzik na miotły |
| Ulepszenia trwałe | ok. 15 | **18** (razem 26 poziomów) |
| Artefakty nocy | 6 | 6 |
| Sekrety | 5–6 | **6** + **8 notatek** |
| Modyfikatory nocy | 3 | 3 (awaria prądu, pełnia, spokojna noc) + godzina duchów |
| Zegar nocy | — | 23:00–6:00, godzina duchów o 3:00, świt |
| CCTV | zapowiedź | 6 kamer, ściana monitorów, pełnoekranowy podgląd z pulpitu |
| Opcje | czułość i głośność | pełne menu opcji ([8.3](#83-opcje)); presety jakości grafiki w toku |
| Języki | — | polski i pełny angielski |

**Koniec MVP (dema):** pokonanie T-Reksa, otwarcie kraty i zejście w ciemność schodów do podziemi. Wejście w ciemność pokazuje ekran końca dema.

---

## 4. Walka

### 4.1 Bronie

| Broń | Klawisz | Rola | Charakter | Zdobycie |
|---|---|---|---|---|
| **Pięści** | V / prawy przycisk | szybki cios | słabe, odrzucają; **dobijają ogłuszonych**, a dobicie leczy i daje Pył ×1,5 | od startu |
| **Paralizator** | 1 | kontrola tłumu | krótki zasięg, **ogłusza** na 3 s, bateria ładuje się sama | od startu |
| **Pistolet** | 2 | broń podstawowa | celny, słaby punkt ×2 | szafka na broń w kanciapie; klucz w szufladzie kasy biletowej w holu |
| **Strzelba** | 3 | ciężka artyleria | z bliska rozrywa eksponaty; po ulepszeniu pocisk „slug” | nisza za krzywą tabliczką w zbrojowni (sekret) |
| **Kartaczownica** | 4 | ciągły ogień na tłum | korba: 0,45 s rozkręcania, 14 strzałów/s, taśma bez przeładowania; przy spuście strażnik idzie wolniej i nie sprintuje | ekspozycja „Kartaczownica, 1871” w zbrojowni, zamknięta łańcuchem |
| **Rakietnica sygnałowa** | 5 | światło i ogień | raca leci łukiem, przykleja się i świeci 12 s, pali trafionego; wosk płonie 2× mocniej | szafka ratunkowa „W razie pożaru zbić szybkę” w dioramie |
| **Sztucer ekspedycyjny** (Piętro I) | 6 | precyzja | 85 obrażeń, **przebija do 3 celów** (każdy cel raz), słaby punkt ×3, cykl zamka 1 s; przyrządy otwarte, bez lunety; tnie liny z każdej odległości | Oświecenie, Gabinet Historii Naturalnej |
| **Harpunnik** (Piętro I) | 7 | przyszpila i przyciąga | harpun na linie (40 m/s, lekki opad): lekki eksponat (≤ 60 HP) z ścianą w 6 m za sobą zostaje **przyszpilony** i rozpada się przy ścianie, średni jest **przyciągany** 3 m i ogłuszony 1 s, ciężki i strażnik dostaje tylko 60 obrażeń; ciągnie żelazne ucha | Ameryki i Oceania, Galeria Pacyfiku |
| **Ognista skrzynia** (Piętro I) | 8 | salwa ognia | salwa 6 małych rakiet ognistych w wachlarzu 12° (co 0,08 s): każda 22 + wybuch 1,8 m (14) + krótkie płonięcie, wosk ×2; kruszy spękane mury | Azja, Sala Koreańska |

- **Start:** pięści i paralizator, czyli standardowe wyposażenie ochroniarza. **Znaleziona broń zostaje na zawsze.**
- **Łańcuch kartaczownicy** mówi tym samym językiem co każdy łańcuch w muzeum: zrywa go strzelba (suma co najmniej 25 obrażeń w 0,4 s — śruciny jednego strzału albo obie lufy z dystansu się sumują) albo 3 ciosy pięścią. Inne bronie tylko krzeszą iskry, a pod celownikiem pojawia się napis „Łańcuch — rozbij czymś ciężkim (strzelba, pięści)”. Cios pięścią trafia to, na co patrzy celownik (łańcuch, nawet gdy obok stoi eksponat).
- **Bramy Piętra I (zamki, `src/props/locks/`)** — jeden czytelny język: wygląd, dźwięk i napis przy celowniku; właściwe narzędzie daje efektowne rozbicie (odłamki, dźwięk, wstrząs kamery), złe tylko iskry/kurz i podpowiedź:

| Zamek | Otwiera | Napis |
|---|---|---|
| Łańcuch (krata dwuskrzydłowa z kłódką) | strzelba (suma ≥ 25 w 0,4 s), 3 ciosy | „Łańcuch — rozbij czymś ciężkim (strzelba, pięści)” |
| Deski „REMONT” | strzelba (suma ≥ 25 w 0,4 s), 5 ciosów, dowolny wybuch | „Zabite deskami — rozbij (strzelba, pięści, wybuch)” |
| Spękany mur | wybuchy: suma ≥ 40 w 0,3 s (salwa ognistej skrzyni); raca z ≤ 5 m ×3 | „Spękany mur — potrzeba wybuchu…” |
| Lina z przeciwwagą | sztucer z każdej odległości, pistolet z ≤ 15 m | „Lina — za daleko, żeby sięgnąć…” |
| Żelazne ucho (krata, czółno-most) | harpun (obiekt zostaje przyciągnięty) | „Żelazne ucho — za ciężkie, żeby pociągnąć ręką (harpun)” |
| Zasuwa (drzwi służbowe) | E od strony zasuwy | „Odsuń zasuwę” / „Zaryglowane z drugiej strony” |
| Żaluzja ogniowa | przywrócenie zasilania (`power_on()`) | „Brak zasilania” |
- **Szafka z rakietnicą:** zbicie szybki (E albo strzał) robi hałas, który budzi eksponaty w promieniu 16 m.
- **Synergia (łagodny odpowiednik Doom Eternal):** paralizator ogłusza, pięść dobija, strażnik się leczy. Gra nagradza zbliżenie się do wroga, ale niczego nie wymusza.
- **Źródła zdrowia:** dobicia, apteczki, przystanie.
- **Ogień:** wybuch i płonięcie racy to obrażenia od ognia; wosk dostaje od ognia ×2. Własny wybuch zabiera strażnikowi najwyżej to, co ma powyżej połowy zdrowia.

### 4.2 Wrogowie

| Wróg | Rola | Zachowanie | Materiał | Gdzie |
|---|---|---|---|---|
| **Figura woskowa** | podstawowy | wolna, chodzi grupkami, bije wręcz | wosk: topnieje i pryska; ogień ×2 | wszędzie |
| **Wypchany wilk** | szybki, kruchy | doskakuje z dystansu; po lądowaniu chwilę bezbronny | trociny, szklane oczy | diorama, hol, balkon, korytarze |
| **Rycerz w zbroi** | twardziel | tarcza blokuje ±70° od przodu; wolno się obraca, więc da się go obejść; ogłuszony opuszcza tarczę; **strzał stromo z góry (z balkonu) przechodzi** | metal: iskry, gubi blachy | zbrojownia, hol, balkon |
| **Lewitujące popiersie** | dystansowy | unosi się, trzyma 8–14 m; pęka i żarzy się 0,7 s, potem wypluwa jeden wolny odłamek, który da się zestrzelić; strzela tylko z linią wzroku; po paralizatorze spada i można je dobić | marmur | galeria |
| **Szkielet raptora** | stado 3–4 | członkowie stada flankują na lewo i prawo; przykucnięcie i syk (0,3 s), potem doskok z 4 m | kość: rozsypuje się na kostki | hol, balkon; też z ryku T-Reksa |
| **Portret** | zasadzka | śpi jako zwykły obraz (nietykalny). Gdy strażnik stanie przed nim w 10 m, oczy go śledzą (sygnał dla uważnych), po 1,5 s rama wysuwa się ze ściany. Pluje farbą łukiem; plama spowalnia o 40%. Nie rusza się | płótno, złocona rama | galeria, nad bocznymi balkonami |
| **Szkielet T-Reksa** | boss | [4.3](#43-boss-szkielet-t-reksa) | kość, kryształ | hol |

**Wspólne zasady:** każdy atak ma zapowiedź; nie atakują przez ściany i stropy; nie wchodzą do przystani. Walczący wręcz zajmują miejsca na pierścieniu wokół strażnika, a nadmiarowi czekają z tyłu.

**Percepcja i terytoria** (od 2.10, projekt [Piętra I §7.2](superpowers/specs/2026-10-02-pietro-1-projekt.md); plan `docs/superpowers/plans/2026-10-02-p1-percepcja.md`):
- **Stany:** śpi (`DORMANT`) albo patroluje (`PATROL`) → **podejrzliwy** (odwraca się ku temu, co zauważył, oczy rozbłyskują, dźwięk: pomruk przy widoku strażnika, cichy „suspicion” przy samym hałasie; 0,6–1,0 s) → **poluje** (`HUNT`), gdy go widział, albo **sprawdza** (`INVESTIGATE`), gdy tylko słyszał → po utracie śladu **przeszukuje** (`SEARCH`: idzie do ostatniego punktu, rozgląda się 6–10 s) → **wraca** (`RETURN`) na posterunek albo trasę i znów śpi / patroluje.
- **Wzrok:** stożek 120° (popiersie 160°) i wyczucie 3,5 m dookoła; zasięg zależy od tego, jak oświetlony jest strażnik: w świetle lamp sali 22 m, w półmroku 12 m, w ciemności 7 m; **włączona latarka = zawsze jak w pełnym świetle**, raca obok też oświetla. Śpiący eksponat widzi na 0,6 tego zasięgu. Jasność liczy prosty model lamp poziomu (`LayoutIllumination`: lampy sali z prądem, czerwone awaryjne dają półmrok, księżyc pod świetlikami), więc zaciemnienie i awaria prądu realnie chowają strażnika.
- **Słuch:** strzały (pięść 6 m, pistolet 18, strzelba 22, kartaczownica 30, rakietnica 15…), szkło szafki pożarowej 16 m, sprint i twarde lądowanie 7 m. Hałas słychać w tej samej sali i za **otwartymi** przejściami (×0,6 na przejście), zamknięte drzwi go zatrzymują; hałas daje sprawdzanie, nigdy od razu polowania. Z przystani hałas nie wychodzi.
- **Gubienie śladu:** polujący zna pozycję strażnika tylko, gdy go widzi, i 1,5 s po utracie (podąża najwyżej 5 m dalej), potem przeszukuje.
- **Terytorium i smycz:** dom = sala spawnu, terytorium = dom i sale za zwykłymi drzwiami; trzecia sala albo ponad 28 m od domu (wilki i raptory 40 m) = powrót. Wezwani przez T-Reksa i fale piaskownicy nie mają smyczy i zawsze wiedzą, gdzie jest strażnik.
- **Budzenie sąsiadów:** tylko w tej samej sali, z linią wzroku, w 8 m, najwyżej 2 na budzącego; obudzeni przychodzą sprawdzić (cicho) i nie budzą dalej. Stado raptorów rusza razem.
- **Przystań:** polujący przeszukują drzwi przystani 8 s i wracają do domów; wyjście z przystani nikogo nie przyciąga.
- **Limit polujących:** najwyżej 8 eksponatów naraz poluje w promieniu 30 m od strażnika, reszta czeka 10 m dalej.
- **Czuwający ze spawnu** patrolują trasę w swojej sali (nie biegną przez muzeum).
- **Łagodna noc 1:** na drodze kanciapa → hol nie ma wilków ani raptorów (są figury woskowe), czuwają najwyżej 2, a śpiący przez pierwsze 3 minuty śpią twardo (czują strażnika dopiero w 1 m). Pomiar (pas bez walki, 60 s po wyjściu z kanciapy, 3 gry): dawniej 17–22 polujących w 30 m, pierwszy po ~3 s; teraz noc 1 — 2, noce 2–3 — 3–8. **Rozpad zależy od materiału:** zwykłe zniszczenie daje kilka dużych kawałków, a duży nadmiar obrażeń albo dobicie pięścią rozrywa eksponat na wiele drobnych odłamków.

### 4.3 Boss: szkielet T-Reksa

Stoi na postumencie w holu, na straży zejścia do podziemi. Budzi go kryształ ([sekcja 6](#6-cel-nocy-sekwencja-przebudzenia)). Ma 1200 punktów zdrowia, a obrażenia przyjmuje prawie wyłącznie przez **czerwony kryształ** między żebrami. Trafienie w kryształ daje złoty znacznik, w kości (10% obrażeń) szary.

| Faza | Próg | Co robi |
|---|---|---|
| **1** | > 66% | chód 3,5 m/s, szarża, ogon |
| **2** | ≤ 66% | chód 4,5 m/s, szarże częściej; **ryk co 20 s** przywołuje do 4 eksponatów (najwyżej 6 żywych naraz): z szansą 50% stado raptorów w wolnym narożniku holu, inaczej figury woskowe |
| **3** | ≤ 33% | jak faza 2, a do tego **ryk co 10 s zrzuca gruz** (3 cienie na podłodze, 1 s ostrzeżenia, 20 obrażeń); po szarży, która nie skończyła się na ścianie, druga szarża od razu |

- **Szarża:** 1 s zapowiedzi (grzebie łapą, ryczy, łeb nisko, kryształ rozbłyska). Kierunek zamyka się 0,4 s przed biegiem, więc da się zejść z toru zwykłym krokiem. Bieg 14 m/s po prostej, do 7 m za strażnikiem. Kontakt: 30 obrażeń i odrzut w bok.
- **Uderzenie w ścianę albo kolumnę = ogłuszenie 2,5 s.** Łeb opada na bok, kryształ zjeżdża nisko, żebra się rozchylają, a obrażenia w kryształ rosną ×1,5 (sięgnie go nawet pięść). Kolumny holu są osłoną przed szarżą. Bez ściany boss tylko hamuje (0,9 s).
- **Stanie pod pyskiem się nie opłaca:** gdy strażnik stoi przed nim bliżej niż 6 m, szarża ładuje się dwa razy szybciej.
- **Ogon:** gdy strażnik jest za nim (do 6 m od bioder, w kącie ok. 45° od kierunku „dokładnie z tyłu”). Zapowiedź 0,75 s, 25 obrażeń i duży odrzut. Trafia tam, gdzie naprawdę przechodzą kręgi. Tuż pod nasadą ogona jest martwe pole. Ucieczka: wyjść z pasa ogona chodem w dowolną stronę po zwykłej reakcji; po spóźnionej ratuje sprint albo unik.
- **Paralizator w kryształ:** potknięcie 1 s, które przerywa zapowiedzi i szarżę (odnowienie 8 s).
- **Arena:** gdy boss się budzi, drzwi holu zatrzaskują się, a w holu pojawia się zaopatrzenie (na start oraz przy fazach 2 i 3, raz na noc dla każdej fazy; amunicja tylko do broni, które strażnik ma). Boss nie wchodzi po schodach na balkon, ale gruz spada także tam. Strażnika w przystani nie atakuje.
- **Śmierć:** kryształ pęka, szkielet drży i rozsypuje się na fizyczne kości, które zostają na podłodze. 100 Pyłu. Krata do podziemi rozsuwa się, drzwi holu wracają.
- **Szacunek długości walki** (pomiar bez okna): ok. 2–2,5 minuty z dodatkami. Do sprawdzenia w grze.

### 4.4 Strażnik Egiptu: Kolos Ramzesa (Piętro I)

Pierwszy prawdziwy strażnik skrzydła i wzorzec dla pięciu kolejnych (projekt [Piętra I §7.4](superpowers/specs/2026-10-02-pietro-1-projekt.md), plan `docs/superpowers/plans/2026-10-03-straznik-kolos.md`). Siedzący, 9-metrowy kolos z czerwonego granitu na tronie w Sali Kolosa (24 × 24 m, 14 m) wśród siedmiu kolumn papirusowych. Budzi się, gdy strażnik minie linię startu: oczy zapalają się, sypie się pył, tron zgrzyta, gdy kolos obraca tułów. Ma **1100 punktów zdrowia** (Podwójna zmiana ×1,2), a obrażenia przyjmuje tylko przez **słabe punkty**: **ureusz** na koronie (zawsze) i **pęknięcia na piersi**, gdy odpadną z nich płyty. Granit dostaje 10% obrażeń (iskry, szary znacznik). Wybuch racy (40 obrażeń) zrywa płytę wcześniej.

| Faza | Próg | Co robi |
|---|---|---|
| **1** | > 66% | **uderzenie dłonią**: cień dłoni rośnie na posadzce przez 0,95 s, ramię wznosi się nad bark i spada (34 obrażeń w cieniu), od dłoni rozchodzi się fala (10, przeskocz ją); **zamach przedramieniem** nisko nad posadzką (zapowiedź 1 s: ramię cofa się ze zgrzytem, łuk na posadzce; 24 obrażeń, przeskocz); **promień słońca z oczu** (ładowanie 1,2 s, oczy i sala jaśnieją; potem 2,2 s linii, która zaczyna się tam, gdzie strażnik był 0,3 s wcześniej, i obraca się wolniej niż bieg; 30 obrażeń/s) |
| **2** | ≤ 66% | kolos odchyla się, płyty z piersi odpadają (fizyka), pęknięcia rozbłyskują; z otworów tronu wylewają się **roje skarabeuszy** (co 14 s, najwyżej 2 żywe); promień obraca się szybciej |
| **3** | ≤ 33% | **wstaje** (3,4 s: zapowiedź, dłonie na udach, biodra w górę i do przodu, stopy schodzą z cokołu z dwoma tąpnięciami, wyprost z przestrzałem, wodospad pyłu, mocny wstrząs) i **kroczy** za strażnikiem (1 m/s, krok 1,6 s: stopa wisi 0,95 s, potem tąpnięcie i fala 12 obrażeń, przeskocz); **promień omiata** salę łukiem 120° (pas na posadzce świeci 1,1 s; 28 obrażeń raz), dłoń dalej uderza |

- **Kolumny:** osłona przed promieniem, która się kończy. Każdy promień liczy się raz: 1. odpryski, 2. pęknięta tekstura, 3. kolumna łamie się (kikut ~5 m dalej osłania, bęben trzonu spada fizycznie, gruz zostaje u stopy). Dłoń nie spada na strażnika za kolumną (ramię nie przejdzie).
- **Uczciwość:** każdy atak ma zapowiedź ≥ 0,6 s (testy mierzą ją od zapowiedzi do obrażeń), nic nie trafia bez ostrzeżenia; skok ratuje przed falami i niskim zamachem, wyjście z cienia przed dłonią, bieg w bok lub osłona przed promieniem.
- **Rój skarabeuszy:** jeden wróg (40 punktów zdrowia, 30 owadów w jednym `MultiMesh`), idzie za strażnikiem i gryzie, póki jest na nim (6 obrażeń/s), śrut i ogień ×2.
- **Upadek:** oczy gasną, pęknięcia rozbłyskują, kolos przewraca się i rozpada na fizyczne bryły granitu; pieczęć Słońca i odłamek leżą w świetle księżyca (znacznik `arena_colossus_reward`), 60 Pyłu, zapis. Ucieczka z sali na 6 s: siada z powrotem na tronie, cały i zdrowy.
- **Animacja (wzorzec dla strażników):** kodem, nie klipami z Blendera — klatki kluczowe w GDScripcie (`MotionClip`, krzywe ease, próbkowane w czasie etapu ataku), sprężyny ruchu wtórnego (`Spring`: głowa śledzi strażnika z opóźnieniem, biodra osiadają po kroku, dłoń odbija się od posadzki) i IK (`LimbIK`: dłoń trafia w cień, stopy stoją na posadzce). Siedzący kolos nie sięga posadzki, więc kamienne człony ramienia rozsuwają się w stawach na **ścięgnach złotego światła** (to samo słońce, co w oczach).
- **Arena deweloperska:** `bash tools/run_guardian.sh colossus --dry` (bez okna, 16 sprawdzanych momentów walki), `--shots` (zrzuty, na sesję z oknem), `--bot` (strażnik-bot bez uników strzela w słabe punkty: ok. 36 s przy 45% celności i 2,5 strzału/s; realnie 2–3 min).

### 4.5 Strażnik Oświecenia: Wielkie Planetarium (Piętro I)

Dla wielu graczy **pierwszy strażnik**: „boss-arena”, który uczy słabych punktów — wolniej i czytelniej niż Kolos (projekt [Piętra I §7.4](superpowers/specs/2026-10-02-pietro-1-projekt.md), plan `docs/superpowers/plans/2026-10-03-straznik-planetarium.md`). Mosiężne orrery z granatową emalią, 10 × 9,5 m, na środku Rotundy Planetarium (19,5 × 23 m, okulus). Nie rusza się z miejsca: walczy areną. Budzi się, gdy strażnik minie linię startu: zapadki chwytają, rusza pętla przekładni, piętra z luzem ruszają, płatki słońca oddychają światłem, planety zapalają się po kolei. Ma **1350 punktów zdrowia** (Podwójna zmiana ×1,2) rozdzielonych na **sześć planet** (66%, każda swoja pula) i **rdzeń słońca** (34%). Obrażenia przyjmuje tylko przez **planety** (zawsze, także w locie), a po zestrzeleniu wszystkich — przez **odsłonięty rdzeń**; mosiądz dostaje 10% (iskry, szary znacznik) z puli rdzenia, najwyżej 40% jej.

- **Trzy piętra ramion omiatają posadzkę** (każde dwa ramiona, różne wysokości, prędkości i kierunki, każda faza je odwraca i przyspiesza): **niskie** (belka 0,30–0,55 m, do 5 m) — **przeskocz** (skok w porę czyści je przy prędkości przelotowej od ok. 3,5 m od osi, w przyspieszeniu wszędzie poza bębnem); **środkowe** (1,45–1,75 m, do 3,6 m) — **trzymaj się dalej niż 4 m**; **wysokie** (2,65–2,95 m, wiszące księżyce do 0,95 m) — **stań w luce** między księżycami (r 3,85–4,45) albo dalej niż 5,55 m. Kontakt: 14 / 18 / 14 obrażeń × prędkość ramienia, odrzut po stycznej i na zewnątrz; wolne ramię tylko odpycha. Zderzenie liczone kapsułą strażnika z jego kształtu, z księżycami tam, gdzie się akurat wychyliły.
- **Przyspieszenie piętra** (atak): lampy na końcach jego ramion (bursztynowe niskie, czerwone środkowe, lodowo-błękitne wysokie), **dzwonek w tonie piętra**, klekot przekładni i drżenie belki 1,1 / 0,95 / 0,85 s przed tym, jak napęd zmieni prędkość (×2,4; od fazy 2 w połowie przypadków odwrócenie ×1,8) na 3–3,4 s.
- **Planeta na orbicie** (atak): planeta rozżarza się, wiruje i drży 1,0–1,2 s, potem wylatuje z gniazda na pół okrążenia elipsy przy ścianach (1,25 m nad posadzką), wycentrowane na strażniku, i wraca do gniazda; 16 obrażeń raz na lot (krok w środek lub pod ścianę, albo zestrzel ją).
- **Zestrzelona planeta** spada i **toczy się** (fizyka): odbija się od ścian i instrumentów w rogach (osłona), 14 obrażeń w kontakcie; małe przeskoczysz; 25 obrażeń ją rozbija, sama pęka po 9 s. Pierścień Saturna toczy się osobno jak obręcz, Księżyc Ziemi też.
- **Rozbłyski słońca** (faza 2+): płatki rozchylają się, słońce zbiera światło 1,3 / 1,1 s; potem 1 / 3 / 4 kule ognia łukiem na posadzkę, znak od wylotu; plusk 18 obrażeń w promieniu 2 m; można je zestrzelić.

| Faza | Kiedy | Co się zmienia |
|---|---|---|
| **1** | 6–5 planet | piętra wolno (niskie 0,75 rad/s), przyspieszenia, orbity; słońce zamknięte |
| **2** | 2 planety zestrzelone | przemiana 2,4 s (piętra hamują, lampy i akord dzwonków, płatki uchylają się), piętra odwrotnie i szybciej, pojedyncze rozbłyski |
| **3** | 4 planety zestrzelone | szybciej, rozbłyski po 3 (na strażnika i ±3,2 m w poprzek) |
| **finał** | 6 planet zestrzelonych | odsłonięcie 2,8 s: płatki rozkwitają na sprężynie, rdzeń rozbłyska i staje się słabym punktem; wszystko najszybciej, rozbłyski po 4 |

- **Animacja:** kodem jak u Kolosa — luz przekładni (piętro zostaje za napędem, gdy przyspiesza, i przechodzi za daleko, gdy staje), mosiądz kołysze się w łożyskach, iskry w piastach przy zmianie prędkości, **wiszące księżyce to wahadła** (wycięte w grze z siatki piętra, każdy na swoim pręcie), planety wirują wokół własnych osi (Księżyc krąży wokół Ziemi, pierścień Saturna się chwieje), płatki słońca otwierają się na sprężynach jeden po drugim, światło (rdzeń, poświata planet, płatki) pulsuje w rytmie przekładni, coraz szybszym z fazą.
- **Upadek:** orrery się zaciera — piętra szarpią do zatrzymania, iskry, płatki odpadają jeden po drugim jako mosiężne bryły, księżyce spadają z prętów, rdzeń gaśnie; Klucz Gwiazd i odłamek na znaczniku `arena_planetarium_reward`, 60 Pyłu, zapis. Na kolejnych nocach w rotundzie stoi wygaszone, nieruchome orrery (`dress_arena`). Ucieczka z rotundy na 6 s: wszystkie planety wracają na ramiona, pełne zdrowie, piętra stają. Strzał z galerii obserwatorów odbija się (zasada „bez snajperki”).
- **Arena deweloperska:** `bash tools/run_guardian.sh planetarium --dry` (bez okna, 12 sprawdzanych momentów), `--bot` (strażnik-bot bez uników: ok. 45 s przy 45% celności i 2,5 strzału/s; realnie ok. 2–3 min, wolniej niż Kolos).
### 4.6 Strażnik Grecji: Kentaur z metopy (Piętro I)

Przeciwieństwo Kolosa: szybki, ruchliwy pojedynek (plan `docs/superpowers/plans/2026-10-03-straznik-kentaur.md`). Marmurowy kentaur (2,86 m) stoi na środku Galerii Partenonu (39,5 × 18 m, 12 m) wtopiony w wielką płytę metopy z błękitnym tłem, **bokiem do wejścia** — strażnik widzi go jak figurę z reliefu. Gdy minie linię startu: oczy się zapalają, kentaur szarpie się (po płycie biegną świecące rysy), staje dęba i **wyrywa się z metopy** (płyta rozpada się na ciężkie bloki, zostaje niski kikut), ląduje twarzą do strażnika. **850 punktów zdrowia** (Podwójna ×1,2). Słaby punkt: **marmurowa pierś** (żarzące się pęknięcia: pełne obrażenia, złoty znacznik), łeb ×1,25, ludzki tułów i ręce ×0,5, końskie ciało ×0,25 (szary znacznik, marmurowe odpryski).

| Faza | Próg | Co robi |
|---|---|---|
| **1** | > 66% | **krąży galopem** wokół strażnika (9,5 m/s — szybciej niż sprint, trzyma ~11 m, omija cokoły, nie wychodzi z galerii); **oszczep** w biegu: tułów skręca się i odchyla, ramię cofa oszczep, grot błyska, na posadzce znak śledzi strażnika (z wyprzedzeniem) przez 0,8 s i staje w chwili rzutu; oszczep leci łukiem ≥ 0,65 s dokładnie w znak (22 obrażeń), wbija się w posadzkę na 4 s; cokół zatrzymuje go; **szarża przez galerię** (0,9 s: staje przodem, tułów nisko, oszczep jak kopia, grzebie kopytem; pas na posadzce do pierwszej przeszkody; 15,5 m/s, 30 obrażeń w pasie) — cokół, grupa frontonowa, kikut metopy albo ściana zatrzymują ją i kentaur **słania się** 2,6 s (pierś ×1,5); z bliska **staje dęba** (0,7 s, kopyta błyskają, 28 obrażeń w znaku przed nim, fala do przeskoczenia), a gdy strażnik stoi za nim, **wierzga** tylnymi nogami |
| **2** | ≤ 66% | staje dęba z uniesionym oszczepem i woła: z grup frontonowych na obu końcach schodzi **2 Lapitów** (hoplici z tarczą i włócznią), ponownie, gdy wszyscy padną (co 25 s); szybszy galop, krótsze zamachy |
| **3** | ≤ 33% | **odrywa z boku odłamek metopy** i ciska nim, w lewej dłoni formuje się drugi oszczep: rzuca **dwoma naraz** (jeden z wyprzedzeniem, drugi w miejsce strażnika), zamach 0,6 s; Lapitów 3 |

- **Animacja:** zestaw Kolosa (`MotionClip`, `Spring`, `LimbIK`) plus **warstwa chodu** `CentaurGait`: chody jako tablice taktów czterech nóg (stęp, kłus, galop czterotaktowy poprzeczny z fazą lotu), kopyta stoją w świecie (IK trzech członów: kolano przedniej nogi zgina się do przodu, staw skokowy do tyłu), w przenoszeniu podwijają się; beczka kołysze się jak koń na biegunach i przechyla w zakręcie, ludzki tułów trzyma pion i pochyla się w zakręt, głowa i ogon na sprężynach; kurz i iskry spod kopyt, wstrząs kamery, gdy przegalopuje obok, pętla `centaur_gallop` w rytmie kroków. Podgląd bez okna: `run_guardian.sh centaur --poses` (klatki z Blendera).
- **Upadek:** oczy gasną, pęknięcia rozbłyskują, potyka się z rozpędu, przednie nogi się łamią, siada i przewraca na bok, rozpada się na marmurowe bryły; Pieczęć Sowy i odłamek Grecji na `arena_centaur_reward`, 60 Pyłu, zapis; potem w galerii stoi pusty kikut metopy. Ucieczka z galerii na 6 s: wraca w całą metopę, Lapici znikają.
- **Arena deweloperska:** `bash tools/run_guardian.sh centaur --dry` (18 momentów), `--bot`: ok. 38 s (jak Kolos), realnie 2–3 min.

### 4.7 Strażnik Asyrii: Lamassu (Piętro I)

Ciężki taran (plan `docs/superpowers/plans/2026-10-03-straznik-lamassu.md`). Alabastrowy skrzydlaty byk z ludzką głową (4 m) śpi na cokole (0,5 m) pod północną ścianą Dziedzińca Pałacu (30,5 × 27 m, otwarty strop z księżycem), twarzą do drzwi z Nimrud. Gdy strażnik minie linię startu: sypie się pył, oczy się zapalają, głowa unosi się i odwraca, skrzydła rozchylają się ze zgrzytem, byk **schodzi z cokołu krok po kroku** (cztery tąpnięcia). **1900 punktów zdrowia** (Podwójna ×1,2). Słabe punkty: **ludzka twarz** ×1,5 (złoty znacznik), **korona** ×1 (po 160 obrażeń odpada jako bryła, kikut zostaje słabym punktem); kamień ×0,1 (szary znacznik, odpryski alabastru), skrzydła ×0,1, ale szczerbią się (odłamki co 25 obrażeń, końcówka odpada po 120).

| Faza | Próg | Co robi |
|---|---|---|
| **1** | > 66% | **skrada się** stępem (1,6 m/s, szeroki łuk skrętu, omija geniuszy i cedry, podchodzi na ~6,5 m); **szarża** (1,0 s: głowa w dół, prawe przednie kopyto grzebie posadzkę, pas na posadzce do pierwszej przeszkody; 11,5 m/s, 32 obrażeń i odrzut w bok, do 5 m za strażnika) — **ścianę widzi** i hamuje przed nią w poślizgu, ale **osłony nie wyhamuje** (cokół geniusza, cedrowa kolumna: znaczniki `lamassu_cover_<n>`): zderzenie i **ogłuszenie 2,6 s** z twarzą nisko, na wysokości strzału; **podmuch skrzydeł** (0,8 s: skrzydła rozkładają się i wznoszą, łuk stożka na posadzce — 13 m, ±32°; zamach do przodu: kto stoi w stożku bez osłony, leci kilka metrów w tył — pchnięcie, podrzut i wiatr przez 0,5 s — i dostaje garść żwiru, 6 obrażeń; osłona zatrzymuje wiatr); **tupnięcie** (0,75 s: staje dęba, krążek na posadzce; przednie kopyta spadają na punkt — 24 obrażeń w promieniu 1,8 m — i rusza fala 14 obrażeń do 10 m: przeskocz) |
| **2** | ≤ 66% | przemiana 2,4 s: staje dęba, skrzydła w pełni, ryk, **pęknięcia rozbłyskują** (zestaw `lamassu_cracked`); **wojownicy z reliefów** (6) schodzą ze ścian areny (opiekun, raz na noc); szybsze skradanie, krótsze zapowiedzi, szarża częściej |
| **3** | ≤ 33% | przemiana 2,0 s: trzy uderzenia skrzydeł unoszą go nad posadzkę i ciężko opada; **skok** (1,25 s: cień w miejscu, gdzie stał strażnik, przysiad, lot łukiem z biciem skrzydeł, 6–15 m; pod cieniem 28 obrażeń w promieniu 2,4 m, fala 16 obrażeń do 11 m) — nigdy na osłonę ani poza dziedziniec; podmuch najczęstszy |

- **Animacja:** zestaw Kolosa (`MotionClip`, `Spring`, `LimbIK`) plus `LamassuGait`: kopyta stoją w świecie (stęp czterotaktowy boczny — lewa tylna, lewa przednia, prawa tylna, prawa przednia — zawsze co najmniej trzy kopyta na posadzce; ciężki galop parami z fazą lotu; poślizg; skoki), IK trzech członów (kolano przedniej nogi do przodu, staw skokowy do tyłu, kopyto poziomo, podwija się w przenoszeniu); **ciało osiada na kopytach** — nogi w spoczynku są prostymi kolumnami, więc obniżenie i przechył przy długim kroku rodzą się z kopyt (przód i tył osobno); głowa i ogon na sprężynach, przechył od przyspieszenia (nos w dół przy ruszaniu, zad w dół przy hamowaniu), końcówki skrzydeł z opóźnieniem; kurz spod każdego kopyta, wstrząs kamery zależny od odległości. Cokół jest dla przebudzonego byka stopniem (kopyta wchodzą na niego), nie przeszkodą.
- **Upadek:** oczy gasną, pęknięcia rozbłyskują, klęka (przednie nogi się łamią, skrzydła odłamują się w całości, tylne nogi składają), rozpada się na alabastrowe bryły; Pieczęć Skrzydła i odłamek Asyrii na `arena_lamassu_reward` (środek dziedzińca w księżycu), 60 Pyłu, zapis; potem cokół stoi pusty. Ucieczka z dziedzińca na 6 s: wraca na cokół cały (korona, skrzydła, czysty kamień).
- **Arena deweloperska:** `bash tools/run_guardian.sh lamassu --dry` (22 momenty), `--bot`: ok. 34 s (jak Kolos), realnie 2–3 min.

### 4.8 Strażnik Azji: Generał samurajów (Piętro I)

Pojedynek pod księżycem: precyzyjny, czytelny, filmowy (plan `docs/superpowers/plans/2026-10-03-straznik-general.md`). Pusta ō-yoroi wielkiego pana (2,7 m do hełmu) **wisi na stojaku** 1,2 m za postem na środku ogrodu japońskiego (grabiony żwir, skały i kamienne latarnie jako osłona, wiśnia, staw). Gdy strażnik minie linię startu: części zbroi **zjeżdżają się ze stojaka** po kolei (stopy → nogi → biodra i kusazuri → kirys → ramiona → sode → hełm, stuk przy każdej), oczy-żarzące węgle zapalają się, Generał **dobywa nodachi** z pochwy u lewego biodra (prawa ręka przez ciało, lewa cofa pochwę, zamach do jodan) i wchodzi w chudan. **1000 punktów zdrowia** (Podwójna ×1,2; plan zakładał 1250 — bot scenariusza potrzebował wtedy 85 s). Słabe punkty: **twarz** pod maską menpō (×1,0, złoty znacznik) i **węzeł agemaki na plecach** (×0,75); zbroja ×0,15 (szary znacznik, odpryski laki). **Postawa obronna:** w chudan trafienie z przodu (łuk ±70°) odbija się od klingi (iskry, rykoszet, zgrzyt) — odsłonięty jest w zapowiedzi ataku (jodan: twarz), w powrocie po chybionym doskoku (plecy), w ogłuszeniu i na dachu; prąd przewodzi przez klingę.

| Faza | Próg | Co robi |
|---|---|---|
| **1** | > 66% | **cięcie z doskoku** (zapowiedź 1,15 s: klinga do jodan, zwinięcie bioder, **błysk ostrza 0,85 s przed cięciem**, pas na żwirze śledzi strażnika i zamyka się 0,3 s przed cięciem; doskok 0,25 s przez miejsce strażnika i 2 m dalej, cięcie w przelocie 34 obr. w pasie szerokości 1 m + promień; skała, latarnia lub mur kończą pas 1,2 m wcześniej — osłona; chybienie: zachwianie 1,6 s z **plecami do strażnika**, trafienie: chiburi 0,9 s); **bliskie cięcie** (strażnik < 3,2 m: jodan 0,8 s, kesa-giri w stożek 2,6 m ±50°, 26 obr.); zamiast trzeciego doskoku z rzędu **podchodzi** suri-ashi; **paralizator** ogłusza go z postawy, zapowiedzi i powrotu na 2,2 s (potem 6 s odporności), **pięść** na ogłuszonym dobija raz za 14% zdrowia (zatacza się) |
| **2** | ≤ 66% | **skok na okap herbaciarni** (przysiad 0,5 s + lot 0,9 s), stamtąd **salwy z łuku**: naciąganie 0,8 s ze znakami na żwirze (pierwszy na strażniku z wyprzedzeniem, reszta na pierścieniu 2,4 m z lukami), 4 żarzące się strzały łukiem ≥ 0,75 s dokładnie w znaki (12 obr. w 1,3 m, skały zatrzymują); po 2 salwach albo po trafieniu w twarz **zeskakuje** na zaznaczone miejsce (znak od przysiadu, 1,4 s; 20 obr. w 1,5 m); na dach wraca co ~22 s |
| **3** | ≤ 33% | **przemiana** 2,2 s: wbija miecz, podmuch, wiśnia **sypie płatkami** do końca walki; doskoki jako **zwody**: wir płatków kryje go, wychodzą dwie postacie (fantom bez stref trafień, bez obrażeń), obie z pasem; **błysk tylko u prawdziwego** (0,8 s przed cięciem), fantom rusza 0,25 s wcześniej i rozsypuje się w płatki; krótsze powroty (0,8 / 0,6 s); salwy po 5 strzał |

- **Uczciwość:** każda zapowiedź ≥ 0,6 s (testy mierzą od zapowiedzi do obrażeń), błysk ≥ 0,7 s przed każdym cięciem z doskoku; wyjście z pasa ratuje przed doskokiem, z stożka przed bliskim cięciem, ze znaku przed strzałą i lądowaniem; skała za plecami skraca pas. Okap herbaciarni zatrzymuje strzały jak skała: strażnik przy ścianie herbaciarni pod okapem jest przed salwami osłonięty (świadoma osłona ogrodu). Strzał z Sali Chin przez wybity mur odbija się (zasada „bez snajperki").
- **Animacja:** zestaw Kolosa (`MotionClip`, `Spring`, `LimbIK`) plus `GeneralFootwork` (suri-ashi: stopy stoją w świecie, ślizga się jedna naraz, przednia pierwsza; w doskoku stopy niesione). Miecz jako rama w układzie tułowia (chwyt + oś ostrza), **obie pięści przez IK na rękojeści ≤ 3 cm** w każdej klatce (chudan, jodan, pchnięcie, cięcie poziome, zachwianie, chiburi, kesa, hassō, wbicie, opuszczenie); nogi IK z kolanami do przodu, sode i panele kusazuri na sprężynach (przedni panel unosi się z udem), głowa za strażnikiem na sprężynach, parada klingi przy bloku; łuk w lewej pięści z cięciwą z dwóch odcinków do nasady strzały (wypieczona cięciwa wycięta z siatki), ramiona łuku zginają się z naciągiem. Model `samurai_general` (26 części, 224 px/m).
- **Upadek:** drżenie, klęka i **wbija nodachi** przed sobą (obie pięści na rękojeści), oczy gasną, zbroja **rozpada się od hełmu w dół** na fizyczne bryły, które leżą do rana; miecz zostaje wbity. Odłamek Azji na `arena_general_reward` (bez pieczęci), 60 Pyłu, zapis; na kolejnych nocach obok pustego stojaka klęczy zbroja. **Herbaciarnia** (przystań tuż obok) nie leczy i nie zapisuje, dopóki Generał nie padnie. Ucieczka z ogrodu na 6 s: zbroja wraca na stojak, pełne zdrowie, płatki ustają.
- **Arena deweloperska:** `bash tools/run_guardian.sh general --dry` (21 momentów), `--bot`: ok. 78 s (strzały bota nie niosą kierunku, więc postawa ich nie odbija — to kres dolny; realnie 2–3 min, bo gracz musi obchodzić blok albo czekać na odsłonięcia).

---

## 5. Mapa: lobby muzeum

### 5.1 Układ

```
                                     N (−Z)
                           ┌──────────────────────────┐
                           │ klatka schodowa w dół    │ → koniec dema
                           └────────────┬─────────────┘
                                        │ krata do podziemi
┌────────────┐  ┌───────────────────────┴────────────────────────┐  ┌────────────┐
│ GALERIA    │  │ HOL GŁÓWNY 36 × 44 m, sufit 14 m               │  │ ZBROJOWNIA │
│ RZEŹBY     │  │ balkon y = 6 m: pas N + boki W i E             │  │ 20 × 28 m  │
│ 20 × 28 m  ├──┤ [składzik na miotły nad kratą · przystań #2]   ├──┤ rycerze    │
│ portrety   │  │ skrzynka bezpieczników · T-Rex na postumencie  │  │ kartaczow- │
│ [komnata za│  │ 4 kolumny · schody W i E pod ścianami bocznymi │  │ nica       │
│  obrazem]  │  │ kasa (SW) · informacja (S) · gablota na kłódkę │  │ [strzelba] │
└─────┬──────┘  └───────────────────────┬────────────────────────┘  └──────┬─────┘
      │ korytarz tech. W                │ drzwi S         korytarz tech. E │
      │                          ┌──────┴───────┐                          │
      └──────────────────────────┤ DIORAMA      ├──────────────────────────┘
                                 │ PRZYRODY     │ szafka z rakietnicą
                                 │ 28 × 20 m    │
                                 └──────┬───────┘
                                        │ korytarz służbowy (9 m)
                                 ┌──────┴───────┐
                                 │ KANCIAPA     │ start · przystań #1
                                 │ OCHRONY      │ monitory CCTV
                                 │ 10 × 8 m     │ szafka z pistoletem
                                 └──────────────┘
```

W nawiasach kwadratowych są miejsca ukryte. Szyb wentylacyjny (sekret) biegnie z dioramy za południową ścianą holu i szczeliną między holem a galerią na balkon W.

- **Układ lobby jest stały, opisany danymi w kodzie** (`LobbyLayout`). Losowość rośnie dopiero na głębszych piętrach (poza MVP).
- **Hol to węzeł** z dwiema kondygnacjami. Walka toczy się też w pionie: balkon, schody, strzały z góry.
- **Trzy drogi** łączą dioramę ze skrzydłami: przez hol i przez oba korytarze techniczne. Dzięki temu zamknięte drzwi nocy wymuszają objazd, ale nigdy nie odcinają celu.
- **Oświetlenie:** nocny półmrok, ciepłe lampy (grupa głównych świateł), czerwone lampy awaryjne i znaki wyjścia, księżyc przez trzy pasy świetlików w dachu holu, latarka strażnika.

### 5.2 Pomieszczenia

| Pomieszczenie | Wymiary | Co tam jest |
|---|---|---|
| **Hol główny** | 36 × 44 m, sufit 14 m | T-Rex na postumencie 12 × 6 × 1,2 m; krata do podziemi (ściana N, 6 m, dwa skrzydła) i skrzynka bezpieczników obok; 4 kolumny; kasa biletowa (SW) z szufladą; lada informacji; ławki; gablota na kłódkę pod balkonem E; 3 pasy świetlików |
| **Balkon (antresola)** | y = 6 m: pas N + boki W i E do z = +4 | gablota-kandydat kryształu (W), notatka 3 (E), fałszywy panel do składziku (N), wyjście szybu (W), 4 miejsca na obrazy |
| **Schody holu** | 2 biegi pod ścianami W i E, 16 m, 40 stopni 0,15 × 0,40 m (20,6°) | szczyt przy z = +4, stopa przy z = +20; drzwi do skrzydeł są pod balkonem, obok masywu schodów |
| **Galeria rzeźby** | 20 × 28 m, h 7 m | popiersia i figury; bezpiecznik A (1 z 2 miejsc); gablota-kandydat; obraz z przejściem do komnaty; 8 miejsc na obrazy |
| **Zbrojownia** | 20 × 28 m, h 7 m | rycerze i figury; bezpiecznik B (1 z 2 miejsc); gablota-kandydat; kartaczownica na łańcuchu; krzywa tabliczka i nisza ze strzelbą; notatka 2 |
| **Diorama przyrody** | 28 × 20 m, h 8 m | wilki; gablota-kandydat; kratka szybu wentylacyjnego; szafka ratunkowa z rakietnicą (ściana od holu) |
| **Korytarze techniczne W i E** | h 3,5 m, drzwi przesuwne 2 m | pętle galeria ↔ diorama i zbrojownia ↔ diorama |
| **Korytarz służbowy** | 9 m, h 3 m | szafki personelu, kamera 6 |
| **Kanciapa ochrony** | 10 × 8 m, h 3 m | krzesło (start nocy), terminal ulepszeń, szafka na broń, biurko z pulpitem CCTV, ściana sześciu monitorów, kartka Heńka, notatka 1 |
| **Składzik na miotły** | 4 × 3 m, na y = 6 m | przystań #2 z terminalem; wejście przez fałszywy panel na balkonie N |
| **Komnata za obrazem** | 3 × 5 m | artefakt na cokole (zawsze), list „Do tego, kto tu wszedł” |
| **Nisza ze strzelbą** | 2,5 × 5 m | strzelba, „Instrukcja dla stróża nocnego, 1912” |
| **Szyb wentylacyjny** | szczelina 1 m, strome stopnie na podest y = 6 m | wyjście na balkon W; siatka nawigacji go nie obejmuje, więc wrogowie nie idą za strażnikiem; zlecenie serwisowe |
| **Klatka schodowa w dół** | 4 × 11,5 m, 27 stopni do −4 m | za kratą; strefa końca dema w połowie schodów |

Przejścia hol ↔ skrzydła i hol ↔ diorama mają 4 m szerokości i 4,5 m wysokości (drzwi dwuskrzydłowe). Między stykającymi się pomieszczeniami stoją ściany grubości 0,5 m.

### 5.3 Gdzie leży broń

| Broń | Miejsce | Jak zdobyć |
|---|---|---|
| Pistolet | szafka na broń w kanciapie | klucz leży w szufladzie kasy biletowej w holu; kartka Heńka na biurku („Klucz od szafki z bronią zostawiłem w kasie. W szufladzie.”) leży, dopóki klucz nie zostanie znaleziony |
| Strzelba | nisza za ścianą zbrojowni | wyprostować krzywą tabliczkę: ściana odjeżdża |
| Kartaczownica | ekspozycja na środku zbrojowni, tabliczką do drzwi z holu | zerwać łańcuch strzałem ze strzelby albo 3 ciosami pięścią, potem E |
| Rakietnica | szafka ratunkowa na ścianie dioramy od strony holu | zbić szybkę (E albo strzał; hałas budzi eksponaty w 16 m), potem E |

Klucz do szafki zostaje na zawsze. W kolejne noce szafka świeci zieloną lampką, ale jest zamknięta do pierwszego E, a pistolet czeka w środku, dopóki strażnik go nie weźmie.

### 5.4 Sekrety i notatki

| # | Sekret | Gdzie | Jak | Co daje |
|---|---|---|---|---|
| 1 | Przejście za obrazem | galeria, ściana W | interakcja z obrazem: obraz odjeżdża w bok | komnata z artefaktem (zawsze) i listem |
| 2 | Szyb wentylacyjny | kratka w dioramie | kratka otwiera się z obu stron | skrót z dioramy na balkon W, notatka |
| 3 | Ściana za tabliczką | zbrojownia, ściana E | wyprostować krzywą tabliczkę | nisza ze strzelbą i instrukcją z 1912 |
| 4 | Gablota na kłódkę | hol, pod balkonem E | strzał w kłódkę albo klucz woźnego | artefakt (zawsze) |
| 5 | Notatki nocnej zmiany | kanciapa, zbrojownia, balkon E | przeczytać wszystkie trzy | historia poprzedników |
| 6 | Składzik na miotły | fałszywy panel na balkonie N | interakcja z panelem | przystań #2 z terminalem |

- Odkrycie: dźwięk i napis „Sekret odkryty (n/6)”, zapis od razu. **Otwarte raz, otwarte na zawsze:** w kolejne noce sekret jest już otwarty.
- **Notatki (8):** kartka Heńka o kluczu, trzy notatki nocnej zmiany i cztery w miejscach sekretnych (komnata, nisza, szyb, składzik). Czyta się je w czytniku „na papierze”, który pauzuje grę. Przeczytane notatki można czytać ponownie z menu pauzy.

### 5.5 Eksponaty w salach i portrety

- **Zestawy spotkań:** każde pomieszczenie ma 2–3 zestawy punktów, a reżyser nocy wybiera jeden. Galeria to popiersia i figury, zbrojownia rycerze i figury, diorama wilki, hol i balkon wszystko po trochu (w tym stada raptorów przy ławkach południowych, przed postumentem i na północnym pasie balkonu). Część eksponatów śpi, część patroluje od startu.
- **Portrety:** 12 miejsc na obrazy (8 w galerii, 4 nad bocznymi balkonami). Co noc 2–4 z nich to prawdziwe portrety, reszta to zwykłe obrazy. Każde miejsce ma zawsze tę samą twarz, więc po wyglądzie nie da się zgadnąć, który obraz ożyje.

### 5.6 CCTV

- **Sześć kamer:** hol, galeria, zbrojownia, diorama, balkon, korytarz służbowy.
- **Ściana monitorów w kanciapie** pokazuje żywy obraz, a obok ekran stanu: noc, zegar i pomieszczenia z ruchem (najwyżej 4, reszta jako „+n więcej”). Przy obudzonym eksponacie w kadrze pojawia się napis RUCH.
- **Pulpit na biurku** (E) otwiera widok pełnoekranowy: przełączanie 1–6, strzałkami albo kółkiem; Esc lub E zamyka. **Widok nie pauzuje gry: zegar biegnie, to ryzyko.** Widok zamyka się sam, gdy strażnik oberwie, zginie, o świcie i przy utracie fokusu okna.
- Podglądy odświeżają się tylko wtedy, gdy strażnik jest w kanciapie albo w widoku kamer, więc poza kanciapą nic nie kosztują.

### 5.7 Nocna zmiana: losowanie co noc

Każdą noc losuje `NightDirector` z jednego **ziarna losowości**, więc daną noc da się odtworzyć, np. przy zgłaszaniu błędu. Noc 1 jest łagodna: bez modyfikatora i bez zamkniętych drzwi.

| Co | Reguła |
|---|---|
| **Modyfikator** (od nocy 2) | brak 40%, awaria prądu 20%, pełnia 20%, spokojna noc 20% |
| **Zamknięte drzwi** (od nocy 2) | z szansą 60% jedne drzwi (korytarza technicznego albo hol ↔ skrzydło), tylko gdy każdy cel zostaje osiągalny z każdej przystani i gdy drzwi nie leżą na trasie kryształu |
| **Kryształ** | w jednej z 4 gablot: galeria, zbrojownia, diorama, balkon W |
| **Bezpieczniki** | jeden w galerii i jeden w zbrojowni, każdy w jednym z 2 miejsc |
| **Eksponaty** | jeden zestaw na pomieszczenie; spokojna noc zostawia ok. 60% |
| **Łup** | 60% punktów łupu dostaje amunicję albo apteczkę ([13.4](#134-łup)); amunicja do broni, której strażnik jeszcze nie ma, zamienia się na naboje albo śrut |
| **Artefakty** | 2–3 na noc: zawsze w komnacie za obrazem i w gablocie na kłódkę, trzeci (0–1) w losowej gablocie. Klucz woźnego tylko w noc z zamkniętymi drzwiami (szansa 70%), w osiągalnej, niesekretnej gablocie |
| **Portrety** | 2–4 z 12 miejsc (ostatnie losowanie nocy) |

**Modyfikatory:**
- **Awaria prądu:** główne światła i ich oprawy w całym lobby zgaszone od startu, światło otoczenia ×0,3. Latarka i jej bateria stają się kluczowe, rakietnica też.
- **Pełnia:** księżyc ×1,6 i bardziej niebieski, eksponaty mają +25% zdrowia i obrażeń, Pył ×1,5.
- **Spokojna noc:** mniej eksponatów, cichsza muzyka.

Na starcie każdej nocy HUD pokazuje kartę nocy: numer, nazwę i opis modyfikatora, a bez modyfikatora „23:00 · Dyżur się zaczyna”.

---

## 6. Cel nocy: sekwencja przebudzenia

Cel jest zbudowany jak karty dostępu w Doomie. HUD zawsze pokazuje bieżący krok.

1. **Bezpieczniki: n/2.** Jeden leży w galerii rzeźby, drugi w zbrojowni. Podnosi się je klawiszem E.
2. **Skrzynka przy kracie.** E wkłada wszystkie niesione bezpieczniki. Po drugim słychać przekaźnik: **gasną lampy holu i balkonu** (z mignięciem; zostają czerwone awaryjne i księżyc), krata unosi się o 0,4 m i się zacina.
3. **„Znajdź źródło pulsowania”.** Kryształ, do tej pory niepozorny eksponat w jednej z gablot (notatka 3: „Minerał nieznanego pochodzenia, dar anonimowy”), pulsuje czerwonym światłem. Bicie serca słychać z ok. 25 m.
4. **„Podążaj za kryształem”.** Gdy strażnik podejdzie na 3 m, szyba gabloty pęka, a kryształ wznosi się i leci przez drzwi do holu (6 m/s), zostawiając świetlistą smugę. Gdy strażnik zostaje dalej niż 14 m, kryształ na niego czeka.
5. **„Pokonaj strażnika holu”.** Kryształ wbija się między żebra T-Reksa i staje się jego słabym punktem. Szkielet ryczy na postumencie, zeskakuje, a drzwi holu się zatrzaskują ([4.3](#43-boss-szkielet-t-reksa)).
6. **„Zejdź do podziemi”.** Po zwycięstwie krata rozsuwa się, za nią schody w ciemność. Wejście w ciemność kończy demo.

**Koniec dema:** ekran ze statystykami (noce, śmierci, czas gry, zebrany Pył, sekrety x/6), „Dziękujemy za grę” i powrót do menu. Zwycięstwo zapisuje się od razu. **Każda kolejna noc to epilog:** bez bossa, krata otwarta, cel „Zejdź do podziemi”.

Fabularnie kryształ to pierwszy namacalny ślad źródła przebudzeń, czyli zapowiedź finału gry.

---

## 7. Pętla roguelite i progresja

Przyjęty model to **łagodny roguelite z checkpointami i odzyskiwaniem waluty jak w Dark Souls**.

### 7.1 Noc i zegar

- **Jedna noc = jedno podejście.** Noc zaczyna się w przystani startowej: w kanciapie albo w ostatnio odwiedzonej przystani (składzik, gdy jest odkryty).
- **Zegar:** od 23:00 do 6:00, jedna godzina gry trwa 3 minuty, więc cała noc to ok. 21 minut.
- **Zegar stoi** w menu, w pauzie i w przystani („przerwa w pracy”), ale najwyżej 60 s na wizytę. Pełna minuta wraca dopiero po 20 s poza przystanią, więc krok za próg i z powrotem niczego nie daje. Start nocy w kanciapie liczy się jako wizyta.
- **3:00 — godzina duchów:** dzwon, karta „3:00 · Godzina duchów”, gęstsza muzyka. Do końca nocy eksponaty są o 20% szybsze i zadają o 20% więcej obrażeń (także wezwane później i w nocy wznowionej po 3:00).
- **6:00 — świt:** eksponaty zamierają w pół kroku i szarzeją, przez świetliki wpada światło poranka, ekran „6:00 · ŚWIT”. Noc kończy się **bez śmierci**: niesiony Pył zostaje przy strażniku, ale bezpieczniki i kryształ wracają na miejsca. To bezpieczna ucieczka dla ostrożnych, bez postępu celu. Świt w trakcie walki z bossem też kończy noc.
- Pokonanie T-Reksa kończy noc zwycięstwem bez względu na godzinę; zegar wtedy staje.

### 7.2 Co przeżywa co

| | Śmierć | Świt | Wyjście z gry → „Kontynuuj” |
|---|---|---|---|
| **Niesiony Pył** | trafia do latarki w miejscu śmierci; starsza latarka przepada | zostaje przy strażniku; starsza latarka czeka dalej | zostaje |
| **Numer nocy** | +1 | +1 | ta sama noc trwa dalej |
| **Bezpieczniki i zwarcie** | przepadają | przepadają | zostają (w kieszeni i w skrzynce; hol dalej ciemny) |
| **Lot kryształu i walka z bossem** | przepadają | przepadają | zaczynają się od nowa: kryształ pulsuje w gablocie, boss śpi; zaopatrzenie faz już osiągniętych nie wraca |
| **Zniszczone eksponaty, zabrany łup** | wracają (nowa noc) | wracają | nie wracają; przerwane stado wraca bez swoich martwych |
| **Artefakty** | przepadają | przepadają | zostają, ich gabloty są puste |
| **Drzwi otwarte kluczem woźnego** | nowa noc | nowa noc | zostają otwarte |
| **Zdrowie i amunicja** | pełne zdrowie, amunicja startowa | pełne zdrowie, amunicja startowa | jak przy zapisie |
| **Zegar** | 23:00 | 23:00 | jak przy zapisie |
| **Drugi oddech** | wraca | wraca | zużyty zostaje zużyty |

**Zostaje na zawsze:** kupione ulepszenia, znalezione bronie, klucz do szafki, odkryte sekrety i notatki, odkryte przystanie, statystyki i zwycięstwo nad T-Reksem.

**Bezpieczniki i kryształ odradzają się co noc**: to świadoma decyzja z 25.09, żeby była to prawdziwa pętla roguelite.

### 7.3 Pył: waluta i ryzyko

- Pokonany eksponat rozsypuje się i zostawia **Pył** (nazwa robocza), czyli resztkę ożywiającej go magii: 1–4 świecące drobiny. Po 0,6 s drobiny lecą do strażnika, jeśli jest bliżej niż 6 m (z ulepszeniem do 12 m), a po 30 s znikają.
- Niesiony Pył widać na HUD. W przystaniach wydaje się go na **trwałe** ulepszenia. **Wydany Pył jest bezpieczny.** Ryzykiem jest chodzenie z pełną kieszenią.
- **Śmierć:** ekran „23:00” z budzikiem. W miejscu śmierci (ostatnia bezpieczna pozycja na podłodze, nigdy w przystani) zostaje świecąca **latarka strażnika** z całym niesionym Pyłem. Przy pustej kieszeni latarki nie ma.
- **Odzyskanie:** kto dotknie latarki, odzyskuje Pył. **Kto zginie po drodze, traci go na zawsze.**

| Źródło | Pył |
|---|---|
| figura woskowa, raptor | 3 |
| wilk, portret | 4 |
| popiersie | 5 |
| rycerz | 8 |
| eksponat wezwany rykiem T-Reksa | 1 |
| T-Rex | 100 (12 drobin) |
| dobicie pięścią | ×1,5 (w górę) |
| pełnia, Moneta z fontanny | po ×1,5 (mnożą się) |

**Ekonomia:** pierwsze 10 ulepszeń kosztuje razem **785 Pyłu**, co przy szacowanych 120–220 Pyłu za dobrą noc dawało cel **4–7 nocy**. Po rozbudowie katalog 18 ulepszeń kosztuje razem **1320 Pyłu**, a cen nie przeliczano (patrz [sekcja 16](#16-otwarte-kwestie-dla-właściciela)).

### 7.4 Przystanie

Są dwie: **kanciapa ochrony** (od startu) i **składzik na miotły** (po odkryciu sekretu). W każdej stoi terminal ulepszeń.

- **Wejście** leczy do pełna, odnawia wytrzymałość i baterię latarki oraz zapisuje grę, ale najwyżej raz na 30 s nocy w tej samej przystani (żeby wchodzenie i wychodzenie w drzwiach nie było stacją leczenia).
- **Przystań to schronienie, nie wieżyczka:** w środku broń jest opuszczona, bez strzałów i ciosów (zmiana broni i przeładowanie działają).
- **Wrogowie nie wchodzą:** zatrzymują ich niewidzialne ściany, a strażnika w środku nie widzą i wracają na swoje miejsca. T-Rex też go nie atakuje.
- **Gdy T-Rex nie śpi, przystań nie leczy i nie zapisuje** („Nie teraz — T-Rex nie śpi”). Składzik otwiera się z balkonu holu, więc inaczej byłby odpoczynkiem tuż obok areny.
- Zegar w przystani stoi do 60 s na wizytę ([7.1](#71-noc-i-zegar)).

### 7.5 Ulepszenia trwałe (24)

Kupuje się je za Pył w terminalu przystani. Menu pauzuje grę, pokazuje cenę, poziom i opis, a przy braku Pyłu odmawia. **Ulepszenia broni można kupić przed jej znalezieniem** i działają od chwili znalezienia. Działają na kopii danych broni, więc zasoby `.tres` nigdy się nie zmieniają.

| Ulepszenie | Dla | Ceny | Efekt |
|---|---|---|---|
| Kondycja | strażnik | 25 / 50 / 90 | +20 maks. zdrowia na poziom |
| Wytrwałość | strażnik | 20 / 45 / 80 | +20 wytrzymałości i +15% regeneracji na poziom |
| Bateria latarki | strażnik | 20 / 45 | +50% czasu świecenia na poziom |
| Twarde pięści | strażnik | 25 / 55 | pięść +40%, leczenie z dobicia +25% na poziom |
| Pojemne kieszenie | strażnik | 30 / 60 | zapas amunicji każdej broni +25% / +50% |
| Drugi oddech | strażnik | 120 | raz na noc śmiertelny cios zostawia 1 punkt zdrowia i 1 s nietykalności (szary ekran, bicie serca) |
| Magnes na Pył | strażnik | 25 / 50 | zasięg przyciągania Pyłu 6 → 9 → 12 m |
| Czujne ucho | strażnik | 40 | wskaźnik przy celowniku, gdy eksponat za plecami zaczyna atak |
| Szybsze ładowanie | paralizator | 40 | bateria ładuje się 1,6× szybciej |
| Przeskok łuku | paralizator | 70 | łuk przeskakuje na drugiego wroga w 5 m |
| Amunicja wzmocniona | pistolet | 50 | +30% obrażeń |
| Powiększony magazynek | pistolet | 40 | magazynek 18 |
| Dławik | strzelba | 50 | rozrzut −35% |
| Pocisk „slug” | strzelba | 80 | przytrzymanie R przełącza śrut / slug (te same łuski): jeden pocisk za 70, słaby punkt ×2 |
| Nasmarowana korba | kartaczownica | 50 | rozkręcanie 0,45 → 0,2 s |
| Dłuższa taśma | kartaczownica | 45 | pojemnik 120 → 200 |
| Magnezja | rakietnica | 45 | płonięcie 5 → 8 s, światło 12 → 20 s |
| Podwójna lufa | rakietnica | 70 | 2 race w lufie |
| Lżejszy zamek | sztucer | 60 | cykl zamka 1,0 → 0,7 s |
| Kula ekspansywna | sztucer | 80 | słaby punkt ×3 → ×4 |
| Kołowrotek | harpunnik | 55 | przeładowanie 1,2 → 0,7 s |
| Zadziory | harpunnik | 75 | przyszpila eksponaty do 90 HP (zamiast 60) |
| Szybki lont | ognista skrzynia | 60 | ładowanie skrzyni 2,2 → 1,5 s |
| Większa salwa | ognista skrzynia | 90 | salwa 6 → 9 rakiet |

**Ulepszenia widać na broni** (pomysł właściciela, Piętro I §7.1a): każdy poziom każdego ulepszenia broni włącza nazwaną część modelu w pierwszej osobie (np. pięści: owijki, potem mosiężne kastety; paralizator: dodatkowa cewka z kondensatorem, druga para elektrod; pistolet: grawerowany zamek, wydłużony magazynek; strzelba: dławik, ładownik slugów; kartaczownica: wypolerowana korba, większy bęben; rakietnica: miedziana osłona z magnezją, druga lufa; sztucer: lżejszy zamek z kulką, grawerowane okucia; harpunnik: kołowrotek, zadziory; ognista skrzynia: mosiężne zapalniki, trzeci rząd rur). Wszystkie ulepszenia broni na maks. = **wykończenie mistrzowskie** (zestaw tekstur `_master`: polerowany metal i mosiądz, grawer, ciepły połysk, subtelna poświata części charakterystycznej). Zakup: błysk ekranu terminala i dźwięk; broń w ręku pokazuje zmianę od razu, a przy najbliższym wyjęciu (albo po zamknięciu terminala) krótko ją „ogląda”. Tabela części: `WeaponLook` (`src/weapons/weapon_look.gd`); test pilnuje, by każde ulepszenie broni miało część na każdym poziomie.

### 7.6 Artefakty nocy (6)

Leżą w gablotach i kryjówkach (losuje je reżyser nocy, [5.7](#57-nocna-zmiana-losowanie-co-noc)). Działają do świtu albo do śmierci, a na ekranie widać rząd ich ikon. Sprawiają, że każda noc gra się trochę inaczej.

| Artefakt | Efekt |
|---|---|
| Skarabeusz | dobicia leczą dwa razy mocniej |
| Monokl kustosza | słabe punkty eksponatów świecą (także kryształ w T-Reksie) |
| Moneta z fontanny | Pył ×1,5 |
| Ogarek świecy | ogłuszenie trwa ×1,5 dłużej |
| Ząb wilka | sprint o 20% szybszy |
| Klucz woźnego | otwiera zamknięte tej nocy drzwi i kłódkę gabloty (nie działa na drzwi holu zamknięte na czas walki z bossem) |

### 7.7 Zapis gry

Zapis jest **automatyczny**, bez ręcznego zapisywania. Gra zapisuje się przy:
- wejściu do przystani (najwyżej raz na 30 s),
- zakupie ulepszenia, znalezieniu broni, klucza, sekretu albo notatki,
- śmierci, świcie, pokonaniu bossa,
- wyjściu do menu, wyjściu z gry i zamknięciu okna.

Zapis to wersjonowany plik JSON, pisany bezpiecznie: najpierw `save.json.tmp` (odczytany i porównany), stary plik zostaje jako `save.json.bak`. Uszkodzony plik jest odkładany jako `save.json.bad` i gra zaczyna od nowa. Plik z nowszej wersji gry albo nieczytelny zostaje nietknięty, a menu pokazuje komunikat. Nieudany zapis daje czerwone ostrzeżenie w HUD.

### 7.8 Gdzie leżą pliki

| Uruchomienie | Folder zapisu (`save.json`, `settings.cfg`, `hints.json`, `logs/godot.log`) |
|---|---|
| wyeksportowana gra | `save/` obok `NocnaZmiana.exe` |
| wersja robocza (`Graj.bat`, narzędzia) | `tools/godot/editor_data/nz_save/` |
| testy i scenariusze | `tests/_out/saves` (nigdy prawdziwy zapis) |
| `--save-dir=<folder>` albo `NZ_SAVE_DIR` | wskazany folder |

- Tylko gdy folderu gry nie da się zapisać (np. Program Files albo uruchomienie z wnętrza ZIP-a), gra wraca do `%APPDATA%\Nocna Zmiana`.
- Log silnika jest wyłączony; gra pisze własny obok zapisu. Pusty folder, który silnik zakłada przy każdym starcie w `%APPDATA%`, gra od razu usuwa.
- **Wyeksportowana gra nie trzyma pamięci podręcznej shaderów ani potoków.** Godot umie ją trzymać tylko w folderze użytkownika na C: (tryb przenośny działa tylko dla edytora, a nazwa folderu nie przyjmuje dysku). Koszt: shadery kompilują się przy każdym starcie. Do decyzji w [sekcji 16](#16-otwarte-kwestie-dla-właściciela).
- Narzędzia i `Graj.bat` kierują `APPDATA` i `LOCALAPPDATA` do `tools/godot/editor_data/`, więc także pamięci podręczne silnika i sterownika karty przy pracy deweloperskiej zostają na D:. Poza zasięgiem gry jest tylko własna pamięć podręczna sterownika GPU przy wersji wyeksportowanej.

### 7.9 Pierwsza noc

Trzy krótkie podpowiedzi, każda raz na instalację (zapamiętane w `hints.json`), bez ścian tekstu: interakcja E (przy pierwszym obiekcie w zasięgu), latarka F (po wyjściu z kanciapy; pomijana, gdy gracz sam ją włączy), „znajdź bezpieczniki” (w dioramie albo holu, albo po 14 s poza kanciapą).

---

## 8. Interfejs, sterowanie i opcje

### 8.1 Ekrany

| Ekran | Co pokazuje |
|---|---|
| **Menu główne** | tytuł „NOCNA ZMIANA”, „Kontynuuj” (z numerem nocy i niesionym Pyłem, tylko gdy jest zapis), „Nowa gra” (przy istniejącym zapisie pyta o nadpisanie), „Opcje”, „Wyjście”; komunikaty o uszkodzonym zapisie |
| **Pauza** (Esc, także przy utracie fokusu okna) | „Wznów”, „Opcje”, „Notatki” (gdy jakaś jest przeczytana), „Wyjdź do menu”, „Wyjdź z gry”; linia „Noc · Pył” |
| **Terminal ulepszeń** | lista 18 ulepszeń w grupach, poziomy, ceny, opis, niesiony Pył |
| **Czytnik notatek** | kartka „na papierze”; E, Esc albo klik odkłada |
| **Widok kamer** | pełny ekran z 6 kamer ([5.6](#56-cctv)) |
| **Ekran śmierci** | wyciemnienie, duże „23:00”, „Noc N”, linijka o latarce, budzik |
| **Ekran świtu** | „6:00 · ŚWIT”, przetrwana noc, Pył przy sobie |
| **Koniec dema** | statystyki, podziękowanie, powrót do menu |

Wszystkie teksty idą przez tłumaczenia (`locale/strings.csv`): polski i pełny angielski. Kursor i wejście mają jednego właściciela (`GameInput`), więc żadne menu nie walczy z grą o mysz, a klik wracający do gry nie oddaje strzału.

### 8.2 HUD

Numer nocy z podpowiedzią „F1 — sterowanie” (lewy górny róg), cel nocy z ikonami bezpieczników, zegar, rząd ikon artefaktów, licznik Pyłu z animacją „+n” (prawy górny róg), paski zdrowia, wytrzymałości i baterii latarki, amunicja i bateria paralizatora, podpowiedź interakcji „[E] …” z prawdziwą nazwą klawisza, pasek zdrowia bossa (góra, środek), karta nocy, komunikaty (zapis, sekret, artefakt), znaczniki trafień i winieta obrażeń.

### 8.3 Opcje

| Grupa | Ustawienia (domyślnie) |
|---|---|
| Sterowanie | czułość myszy 0,1–3 (1), odwrócona oś Y (wył.), pole widzenia 70–110° (70°, pionowe) |
| Obraz | tryb okna: okno, okno zmaksymalizowane, **pełny ekran (domyślnie)**, pełny ekran wyłączny; V-Sync (wł.); limit klatek: bez limitu, 30, 60, 120, 144, 165, 240; skala renderu 3D 50–100% ze skalowaniem dwuliniowym, AMD FSR 1.0 albo FSR 2.2 |
| Dźwięk | głośność ogólna, efekty, muzyka, otoczenie, dźwięki menu |
| Interfejs | język (polski / angielski), licznik klatek (wył.) |

Opcje działają na żywo i zapisują się same chwilę po zmianie. F11 przełącza pełny ekran. Wyeksportowana gra pamięta tryb okna w `override.cfg` obok exe, więc nie miga pełnym ekranem przy starcie okienkowym.

**Ustawień jakości grafiki jeszcze nie ma w grze.** Presety Low / Medium / High / Ultra z wierszem w opcjach są zbudowane na gałęzi `level-art-integration` i czekają na scalenie.

### 8.4 Sterowanie

| Akcja | Klawisz |
|---|---|
| Ruch | W / S / A / D |
| Skok | Spacja |
| Sprint | Shift |
| Unik (dash) | Ctrl lub boczny przycisk myszy |
| Strzał | lewy przycisk myszy |
| Cios pięścią | V lub prawy przycisk myszy |
| Przeładowanie / przełączenie slug | R / przytrzymanie R |
| Latarka | F |
| Interakcja | E |
| Bronie 1–8 | 1 paralizator · 2 pistolet · 3 strzelba · 4 kartaczownica · 5 rakietnica · 6 sztucer · 7 harpunnik · 8 ognista skrzynia; kółko myszy; HUD pokazuje numery znalezionych broni |
| Areny deweloperskie | F5 figury · F6 wilki · F7 rycerz · F8 usuń wrogów (klawisze 6–8 to bronie) |
| Pomoc / pełny ekran / pauza | F1 / F11 / Esc |

Klawisze są oparte na fizycznych pozycjach, więc działają na każdym układzie klawiatury. W/S/A/D poruszają też po menu.

---

## 9. Oprawa graficzna i dźwięk

### 9.1 Kierunek: „styl retro, nie jakość retro”

Z lat 90. bierzemy tylko **język wizualny**: czytelne sylwetki, ostre pikselowe tekstury, przemyślaną paletę. Całą resztę robimy nowocześnie. Punkty odniesienia: **Amid Evil, Cultic, Prodeus, Selaco**. Noc ma trzy temperatury światła, które zawsze się spierają: zimny księżyc, ciepłe lampy żarowe i czerwone światło awaryjne.

| Element | Kierunek |
|---|---|
| Rozdzielczość | pełna, natywna, ostry obraz (**bez** sztucznego renderu w 480p) |
| Geometria | stylizowane, masywne formy z wyraźną sylwetką: uproszczone, ale nie prymitywne |
| Tekstury | pikselowe, ostre teksele (filtr „najbliższy” z mipmapami i anizotropią ×16), bezstratne, stała gęstość tekseli na obiekt |
| Światło | dynamiczne cienie, **wolumetryczna mgła** ze snopami księżyca przez świetliki, globalne oświetlenie SDFGI, bloom, okluzja otoczenia, tonemapping AgX |
| Odbicia | marmurowe podłogi i szklane gabloty (SSR + sondy odbić) |
| Antyaliasing | MSAA 4× (bez TAA i FXAA, bo rozmywają teksele) |
| Efekty | cząsteczki i odłamki z fizyką, ślady trafień, rozbłyski, wstrząsy kamery, hitstop |
| Filtry retro | najwyżej jako **opcja** (dziś ich nie ma) |

### 9.2 Potok grafiki

- **Modele** powstają ze skryptów Pythona uruchamianych w Blenderze w tle. Poprawka to zmiana liczby w skrypcie. Części mają osie w stawach i nazwane znaczniki (np. wylot lufy, gniazdo kryształu), więc gra może je animować, strącać i odczytywać.
- **Tekstury** są proceduralne (marmur, wapień, parkiet, tapety, mosiądz, szkło, płótna) i wypiekane do atlasów pikseli przy zadanej gęstości: architektura 64 px/m, meble 128–160, eksponaty i bohaterowie 256, boss 112, broń w pierwszej osobie 384–512.
- **Podglądy** renderuje Cycles. Budowa jest powtarzalna bit w bit.
- **Wymiana bez ruszania logiki:** każdy element poziomu ma identyfikator zestawu, a model podmienia sam wygląd. Kolizje i układ zostają.

### 9.3 Co powstało

| Partia | Zawartość | W grze? |
|---|---|---|
| **Próbka stylu (1b)** | fragment galerii 12 × 10 m w pełnej oprawie: marmur, gabloty, okna z księżycem, kolumny, popiersia, obraz, ławka, figura woskowa | scena próbki; model figury woskowej także w grze |
| **Etap 2** | 17 modeli: wilk, rycerz, popiersie-wróg, szkielet T-Reksa (ok. 21 tys. trójkątów, rig póz), broń w pierwszej osobie (pięści, paralizator, pistolet, dwururka), amunicja, apteczka, terminal, latarka, szafka na broń, ściana monitorów, bezpiecznik, kryształ | tak |
| **Etap 3 (rozbudowa)** | kartaczownica (w ręku i na ekspozycji z łańcuchem), rakietnica, raca i szafka ratunkowa, szkielet raptora, portret z 10 płótnami i ruchomymi oczami, amunicja | tak |
| **Zestaw architektury holu** | 119 modeli (kolumny, portale, balkon z balustradą, schody z tralkami, kasetony, latarnie dachowe, posadzki z medalionem, cokół T-Reksa z mosiężną tablicą, kasa, informacja, drzwi, krata, szyldy z polskimi literami, oprawy świateł, rekwizyty sal) i 16 tekstur kafelkowych 64 px/m; style wszystkich pomieszczeń | **w toku:** zestaw gotowy, ubranie prawdziwego lobby na gałęzi `level-art-integration` |

Uczciwe słabe punkty (twarze z metaballi z bliska, sztywna figura woskowa, wilk na cienkich nogach, „allozaurowa” czaszka T-Reksa, mała broń w kadrze) opisuje [przewodnik stylu](art/styl-przewodnik.html).

### 9.4 Przepis na światło

- **GI: SDFGI.** Nie wymaga wypiekania, więc pasuje do poziomów budowanych w kodzie, obejmuje cały hol i daje ciepły odblask lamp. VoxelGI odrzucone (droższe, wypiekanie przy każdym wczytaniu, bez widocznego zysku), wariant bez GI też (traci ciepły odblask).
- **Mgła:** globalnie zero, gęstość nadają objętości mgły w pomieszczeniach. **Zasada kontrastu:** księżyc oświetla mgłę ok. 9×, lampy tylko 0,12–0,6×. Gdy lampy też mocno świecą we mgle, sala mętnieje i snopy znikają.
- **Cienie tylko tam, gdzie je widać:** w lobby w grze najwyżej 10 świateł z cieniem (księżyc, lampy kolumn holu, reflektory sal, lampka biurka, reflektor na T-Reksie). Lampy bez cienia, których zasięg wychodzi poza pomieszczenie, nie świecą we mgle.
- **Awaria prądu i zwarcie** gaszą lampy i emisję ich opraw; zostają księżyc, lampy awaryjne, znaki WYJŚCIE i latarka.
- Pełny przepis holu (SSR, SSAO, SSIL, sondy, budżety cieni, reflektory za balustradą) jest w `LobbyLightRecipe` i w przewodniku; w grze pojawi się razem z ubranym lobby.

### 9.5 Dźwięk

Cały dźwięk powstaje ze skryptów, bez próbek z zewnątrz.

- **Efekty:** generator proceduralny `tools/sfx/gen_sfx.py` (czysty Python). Każdy dźwięk ma ziarno z nazwy, więc nowy dźwięk nie zmienia starych plików.
- **Muzyka, ambient i kroki:** synteza w numpy (pozytywka, czelesta, fortepian, smyczki, kotły, organy, chór, ksylofon), kodowanie do Ogg Vorbis modułem Blendera, pliki powtarzalne bajt w bajt. Pętle są renderowane kołowo i nie mają szwu (sprawdza to silnik).
- **Szyny:** Master (limiter) ← SFX, Music, Ambience, UI, plus szyny pogłosu. Suwaki opcji sterują szynami.

**Muzyka adaptacyjna** (tonacja d-moll, jeden motyw-kołysanka z pozytywki w każdym utworze):

| Stan | Kiedy | Utwór |
|---|---|---|
| MENU | menu, koniec dema | „Nokturn dozorcy” (pozytywka, czelesta, smyczki) |
| EXPLORE | obchód | „Obchód”: burdon, daleki fortepian, zegar w sąsiedniej sali |
| TENSION | czuwający eksponat w 30 m; po zwarciu do końca celu | warstwa napięcia na obchodzie (cicho pod obchodem także w pełnię i po 3:00) |
| COMBAT | walka w 9 m, trafienia, rany | perkusja z „tykającym zegarem”, warstwa intensywności |
| BOSS | T-Rex się budzi | „Tyranozaur w rotundzie”; od fazy 2 chór i „kościany” ksylofon |
| VICTORY | T-Rex pokonany | stinger w D-dur, potem cichy obchód |
| SILENT | śmierć, inne sceny | stinger śmierci: pozytywka, której kończy się sprężyna |

Spokojna noc i noc 1 grają ciszej. Po zwarciu muzyka na 3 s prawie milknie, potem wchodzi napięcie. O świcie wszystko gaśnie, a za świetlikami odzywają się dalekie ptaki. Kod gry nie woła muzyki wprost: muzyka i ambient słuchają zdarzeń nocy na szynie `Events`.

**Ambient i pogłos:** strefy otoczenia według pomieszczeń (hol, galeria, kanciapa ze świetlówkami i monitorami, korytarze z wentylacją, kryjówki z martwą ciszą), dalekie dźwięki w 3D co 10–24 s, przy awarii prądu milkną warstwy elektryczne i wchodzi niskie dudnienie. Pogłos ma trzy presety (hol, pokój, korytarz) i budowany jest automatycznie z pomieszczeń poziomu.

**Kroki:** strażnik i eksponaty (wosk, wilk, rycerz, raptor) mają własne kroki. Powierzchnię wybiera pomieszczenie: marmur, wapień, płyty, lastryko, beton, linoleum, deski. **Zestaw kroków ma cztery materiały** (kamień, drewno, dywan, metal), więc wszystko poza deskami brzmi jak twarda posadzka.

Szczegóły: [przewodnik dźwięku](audio/dzwiek-przewodnik.html).

---

## 10. Technologia i architektura

### 10.1 Stos

- **Silnik:** Godot **4.7.2**, renderer Forward+, fizyka **Jolt**, interpolacja fizyki, MSAA 4×.
- **Język:** GDScript ze statycznym typowaniem. Wcięcia wyłącznie tabulatorami. Komentarze i identyfikatory po angielsku, teksty dla gracza przez `tr()`.
- **Wersjonowanie:** lokalne repozytorium git, bez wysyłania na zewnątrz. Gałąź zbiorcza: `etap-1a-piaskownica`.
- **Dlaczego Godot, a nie Unity** (25.09): sceny w czytelnych plikach tekstowych, więc grę da się budować i testować bez klikania; lekki, darmowy, open source, już na D:; ma wszystko, czego wymaga kierunek graficzny. Unity odrzucone: ciężka instalacja, zamknięty kod, wymagane konto.

### 10.2 Zasady budowy kodu

- **Węzły buduje kod.** Pliki `.tscn` są minimalne: korzeń plus skrypt.
- **Poziom opisują dane** (`LobbyLayout`: pomieszczenia, przejścia, schody, elementy, światła, punkty spawnu i łupu, znaczniki). `ShellCarver` rzeźbi z pustych brył szczelną skorupę (podłogi, ściany, stropy, nadproża), a `LevelBuilder` stawia elementy przez jedną fabrykę `LevelKit`.
- **Dane broni** leżą w zasobach `.tres`; ulepszenia działają na kopiach.
- **Czysta logika** siedzi w klasach `RefCounted` albo statycznych, testowanych bez sceny (np. maszyny stanów wrogów i bossa, reżyser nocy, zegar, ekonomia, zasady nocy).
- **Komunikacja przez szynę sygnałów `Events`**, np. „wróg zniszczony”, „noc się zaczęła”, „zwarcie”, „godzina duchów”, „świt”, „boss się obudził”.
- **Stan w dwóch miejscach:** `GameState` (trwały, zapis JSON) i `RunState` (jedna noc). Tylko one decydują, co przeżywa śmierć, a reguły są zebrane w `NightRules`.
- **Interfejs obrażeń:** każdy węzeł z metodą `take_damage(info: DamageInfo)` przyjmuje obrażenia.
- **Warstwy fizyki:** 1 `WORLD`, 2 `PLAYER`, 4 `ENEMY`, 8 `HURTBOX`, 16 `DEBRIS`, 32 `PICKUP`, 64 `INTERACT`, 128 `ENEMY_BLOCK` (ściany przystani tylko dla eksponatów), warstwa 20 strefy pogłosu. Broń w pierwszej osobie rysuje się na osobnej warstwie renderowania, którą widzi tylko kamera strażnika.

### 10.3 Autoloady

`Storage` (porządek w folderach, log gry), `Events`, `GameInput` (wejście, stos menu, kursor), `Settings`, `Fx` (cząsteczki, odłamki, smugi, hitstop), `Sfx` (efekty), `GameState`, `RunState`, `SceneFlow` (zmiana scen z wyciemnieniem), `Music`, `Ambience`, `Foley` (kroki).

### 10.4 Moduły

| Katalog | Odpowiada za |
|---|---|
| `src/core`, `src/state` | szyna zdarzeń, wejście, opcje, sceny, zapis i ścieżki, log; stan trwały i nocny |
| `src/player`, `src/weapons`, `src/combat` | strażnik, bronie z danych, hitscan, pociski, wybuchy, strefy trafień, materiały rozpadu |
| `src/enemies` | wspólna maszyna stanów eksponatów, nawigacja, tłum, sześć typów wrogów, T-Rex (`trex/`), rigi modeli |
| `src/level` | dane układu, rzeźbienie skorupy, budowniczy, drzwi, graf pomieszczeń, światło, nawigacja, lobby |
| `src/game` | scena gry `Museum`, reżyser nocy, cel nocy, kryształ, zegar, modyfikatory, wprowadzenie |
| `src/progression`, `src/haven` | Pył, ulepszenia, zasady nocy, wyposażenie startowe, przystanie, terminal |
| `src/world` | treść świata lobby (`LobbyFeatures`): sekrety, notatki, szuflada i szafka, artefakty, CCTV |
| `src/props`, `src/ui` | ekspozycja z łańcuchem, szafka ratunkowa, obrazy; menu, HUD i ekrany |
| `src/audio`, `src/fx`, `src/style` | muzyka, ambient, pogłos, kroki; efekty; biblioteka grafiki, zestaw architektury, przepis na światło, shadery |

### 10.5 Kontrakt `Level` i scena gry

`Museum` zależy tylko od kontraktu `Level`: `player_start`, `haven_spots` (terminale), `haven_zones` (strefy przystani), `spawn_slots`, `loot_spots`, próg śmierci. Spełniają go `LobbyLevel` (gra) i `SandboxLevel` (arena deweloperska).

Kolejność startu nocy: `NightRules.start_night` (ziarno, niesiony Pył, dane wznowienia) → `NightDirector.plan` → `LobbyLevel.build` (zamknięte drzwi znane przed wypieczeniem nawigacji) → modyfikatory → przystanie i terminale → strażnik → eksponaty → łup → bronie w lobby → cel nocy → zegar → podpowiedzi → HUD → `LobbyFeatures.install` (sekrety, notatki, artefakty, CCTV).

Nawigacja jest wypiekana w czasie gry (dwa regiony: zwykły i przystanie) i przepiekana po zmianie drzwi. T-Rex porusza się bez siatki, na czujnikach.

### 10.6 Wydajność (pomiary)

| Pomiar | Wynik |
|---|---|
| Walka w holu: boss w fazie 2, 44 eksponaty, 1920 × 1080, RTX 2080 Ti, bez V-Sync | **158–164 kl./s** średnio, najwolniejsza klatka 14–15 ms |
| Koszt skryptów w tej walce | 6,7 ms fizyki na tik średnio (najgorszy 8,2 ms) |
| Lobby ubrane zestawem architektury, pełna jakość (podgląd) | 140–166 kl./s; preset „low” 258–317 kl./s |
| CCTV w kanciapie | bez mierzalnego kosztu średniego (księżyc niewidoczny dla kamer) |

### 10.7 Eksport

`bash tools/export.sh` buduje `build/NocnaZmiana.exe` (szablony 4.7.2 w `tools/godot/editor_data/export_templates/`) i uruchamia go próbnie bez okna z tymczasowym folderem zapisu (nigdy `build/save`). Wyeksportowana gra startuje w menu.

---

## 11. Testowanie

- **Własny runner bez okna**, bez zewnętrznych bibliotek (GUT odrzucony): `bash tools/run_tests.sh`, a `--filter=nazwa` uruchamia tylko wybrane.
  - **1033 testy** (42 pliki jednostkowe, 78 integracyjnych), ok. **60 s**. Runner działa z `--fixed-fps 60`: każdy krok fizyki to nadal 1/60 s, ale klatki lecą bez czekania na zegar.
  - Przebieg jest nieudany, gdy padnie test, Godot wypisze linię `ERROR` albo wyciek przy wyjściu, albo gdy nie uruchomi się żaden test (np. literówka w filtrze).
  - Testy nigdy nie dotykają prawdziwego zapisu ani opcji. Muzyka i ambient są w nich wyłączone, a nawigacja aktualizuje się synchronicznie.
- **Najważniejsze testy całościowe:** cała noc od kanciapy do końca dema; osiągalność każdego celu po siatce przy każdych drzwiach, które reżyser może zamknąć; przejście prawdziwym strażnikiem przez wszystkie tajne przejścia w obie strony; krawędzie nocy (świt w locie kryształu, boss dobity po świcie, wyjście w trakcie walki, pełnia razem z godziną duchów); determinizm reżysera nocy.
- **Scenariusze wizualne** (`tools/run_*.sh`: `scenario`, `lobby`, `boss`, `night`, `world`, `content`, `audio`, `style`, `art_lineup`, `artint`, `artint2`, `kit_preview`): skryptowany „bot” steruje grą, a gra zapisuje zrzuty i stan do `tests/_out/<nazwa>/`. **Domyślnie są ciche** (`--audio-driver Dummy`; `SOUND=1` włącza dźwięk) i otwierają okno w trybie okienkowym. Wariant `dry` (lobby, boss, noc, świat, zawartość) przechodzi te same momenty bez okna. Część scenariuszy mierzy też FPS.
- **Piaskownica walki z 1a** zostaje narzędziem deweloperskim (`tools/run_sandbox.sh`, klawisze 7/8/9/0 przywołują eksponaty), podobnie areny bossa i zawartości.
- **Testy gracza:** najważniejszy sprawdzian wrażeń. Pełne demo czeka na pierwsze testy właściciela ([sekcja 16](#16-otwarte-kwestie-dla-właściciela)).

---

## 12. Etapy realizacji i stan prac

Kolejność „najpierw odczucia walki, potem pętla, na końcu wygląd” została zachowana, a od 30.09 dochodzi zasada „najpierw kompletny pierwszy obszar, potem nowe piętra”.

| Etap | Zawartość | Stan |
|---|---|---|
| **1a — piaskownica walki** | ruch, 4 bronie, figura, wilk, rycerz, rozpad, HUD, dźwięki, eksport | **gotowe** (30.09; 22 zadania + przeglądy modułów) |
| **1b — próbka stylu** | potok grafiki w Blenderze, galeria w pełnej oprawie, przewodnik stylu, wybór SDFGI | **gotowe** (30.09) |
| **2a — pętla nocy** | menu, opcje, zapis, Pył, latarka, przystanie, ulepszenia, śmierć, lokalizacja | **gotowe** |
| **2b-1 — lobby** | budowniczy poziomu z danych, drzwi, nawigacja, reżyser nocy | **gotowe** |
| **2b-2 — świat lobby** | sekrety, notatki, szuflada i szafka, artefakty, CCTV | **gotowe** |
| **2c-1 — popiersie i T-Rex** | pocisk, popiersie, boss z trzema fazami | **gotowe** |
| **2c-2 — integracja nocy** | lobby jako gra: cel nocy, kryształ, boss, modyfikatory, zegar, świt, koniec dema | **gotowe** (1.10) |
| **Rozbudowa obszaru** | kartaczownica, rakietnica, raptory, portrety, 8 ulepszeń, zegar nocy, CCTV | **gotowe** (1.10) |
| **3 — oprawa** | modele eksponatów, bossa, broni, znajdziek i rekwizytów (w grze); muzyka, ambient, pogłos, kroki (w grze); zestaw architektury holu (gotowy, wpięcie do gry w toku) | **w dużej mierze gotowe** |
| **Szlif** | wydajność (rozgrzewanie efektów i shaderów pod wyciemnieniem na starcie nocy, cienie, tłum), presety jakości grafiki, poprawki po przeglądach | **w toku** |

**Stan na 1.10:** cały zestaw testów zielony dwa razy z rzędu (1033 testy), scenariusze nocy i świata przechodzą, eksport przechodzi.

**Co dalej:**
1. Scalić ubrane lobby i presety grafiki (`level-art-integration`) oraz poprawki wydajności; zrzuty, pomiar FPS, nowy eksport.
2. **Pierwsze testy gracza całego dema** (lista w [sekcji 16](#16-otwarte-kwestie-dla-właściciela)).
3. Strojenie po testach: ekonomia Pyłu, długość nocy, trudność walki z T-Reksem.
4. Potem kolejne piętra (poza MVP).

---

## 13. Parametry rozgrywki

Wartości z kodu na 1.10. **Wszystkie podlegają strojeniu po testach gracza.**

### 13.1 Strażnik

| Parametr | Wartość |
|---|---|
| Zdrowie | 100 (+20 na poziom Kondycji); apteczka +25; dobicie +15 (+25% na poziom Twardych pięści, Skarabeusz ×2) |
| Chód / sprint | 5,5 / 8,5 m/s |
| Dash | 15 m/s przez 0,16 s, odnowienie 0,45 s |
| Skok | 5 m/s (z buforem skoku i „coyote time”) |
| Pole widzenia | 70° (opcje 70–110°), wstrząs kamery i „kopnięcie” FOV przy strzałach |
| Wytrzymałość | 100; sprint 18/s, dash 30; regeneracja 30/s po 0,7 s przerwy; po wyczerpaniu sprint wraca od 30 |
| Latarka | bateria 120 s; wyłączona ładuje się 2× wolniej; poniżej 15% miga; pusta włącza się od 5% |
| Interakcja | promień 2,2 m ze środka ekranu |

### 13.2 Bronie

| Broń | Obrażenia | Zasięg | Odstęp | Amunicja (magazynek · zapas na start · maks.) | Uwagi |
|---|---|---|---|---|---|
| Pięści | 15 | 1,7 m | 0,4 s | — | odrzut, dobija ogłuszonych |
| Paralizator | 4 | 7 m | 0,5 s | bateria 100, strzał 33, ładowanie 22/s po 0,8 s | ogłuszenie 3 s |
| Pistolet | 20 | 120 m | 0,26 s | 12 · 24 · 150; przeładowanie 1,1 s | słaby punkt ×2 |
| Strzelba | 9 × 10 śrucin | 45 m | 0,3 s | 2 · 6 · 50; przeładowanie 1,25 s | rozrzut 7°, słaby punkt ×1,25; slug 1 × 70, ×2 |
| Kartaczownica | 7 na pocisk, 14/s | 80 m | — | taśma 120 · 120 · 360; bez przeładowania | rozkręcanie 0,45 s, wybieg 0,6 s; rozrzut 3° → 5° w serii; ruch ×0,65 przy spuście; słaby punkt ×1,5 |
| Rakietnica | wybuch 20 w 2,5 m + 6/s przez 5 s | raca 28 m/s, łuk | 0,45 s | 1 · 3 · 8; przeładowanie 1,4 s | światło 12 s (10 m), najwyżej 8 rac naraz; wosk ×2 od ognia |

| Sztucer | 85, przebija do 3 celów | 150 m | cykl zamka 1,0 s | 5 · 25 · 40; przeładowanie 2,2 s (łódka) | słaby punkt ×3; bez rozrzutu; wstrząs 0,35 |
| Harpunnik | 60 | lina 45 m; 40 m/s, opad 3 m/s² | 0,3 s | 1 · 12 · 20; przeładowanie 1,2 s | przyszpila ≤ 60 HP przy ścianie w 6 m; przyciąga średnich (≤ 150 HP, opór odrzutu < 0,75) o 3 m + ogłuszenie 1 s; ciężcy: tylko obrażenia; lina widoczna w locie |
| Ognista skrzynia | 6 × (22 + wybuch 14 w 1,8 m) + płonięcie 3/s przez 2 s | 60 m; 32 m/s, opad 2 m/s² | salwa 6 rakiet co 0,08 s w wachlarzu 12° | 1 salwa · 6 · 10; ładowanie 2,2 s | ogień: wosk ×2; własny wybuch jak raca (do połowy zdrowia) |

Pojemne kieszenie podnoszą maksymalny zapas: pistolet 150 → 188 → 225, strzelba 50 → 63 → 75, taśma 360 → 450 → 540, race 8 → 10 → 12, naboje sztucerowe 40 → 50 → 60, harpuny 20 → 25 → 30, salwy 10 → 13 → 15.

### 13.3 Wrogowie

| Wróg | Zdrowie | Prędkość | Atak | Uwagi |
|---|---|---|---|---|
| Figura woskowa | 60 | 2,4 m/s | 12, zamach 0,55 s | podejrzliwość 0,8 s; topnienie obniża też strefy trafień |
| Wypchany wilk | 35 | 6,5 m/s | 10, skok z ok. 6 m | skok do 13 m/s, podejrzliwość 0,6 s, smycz 40 m |
| Rycerz | 180 | 2,0 m/s | 25, zamach 0,95 s | tarcza ±70°; obrót 2,2 rad/s; odporny na odrzut; podejrzliwość 1,0 s |
| Popiersie | 45 | 3,0 m/s | odłamek 12 (9 m/s), co 2,4 s | unosi się 1,6 m; dystans 8–14 m, cofa się < 6 m; zapowiedź 0,7 s; twarz = słaby punkt; stożek 160°, podejrzliwość 0,8 s |
| Raptor | 25 | 7,5 m/s | 8, doskok z 4 m | stado 3–4 (rusza razem); zapowiedź 0,3 s; czaszka = słaby punkt; podejrzliwość 0,6 s, smycz 40 m |
| Portret | 40 | — | farba 10, co 2,6 s | budzi się w 10 m (1,5 s śledzenia), obudzony widzi 16 m; zapowiedź 0,7 s; plama 3 s, −40% prędkości; oczy = słaby punkt |
| T-Rex | 1200 | 3,5 / 4,5 m/s | szarża 30, ogon 25, gruz 20 | kryształ ×1 (×1,5 w ogłuszeniu), kości ×0,1; szarża 14 m/s, odnowienie 9 / 6 / 6,5 s; ogon 6 m, odnowienie 2,5 s |

Modyfikatory: pełnia +25% zdrowia i obrażeń; godzina duchów +20% prędkości i obrażeń (razem: zdrowie ×1,25, obrażenia ×1,25 × 1,2, prędkość ×1,2).

**Percepcja** (`PerceptionRules`, liczby startowe do strojenia): stożek 120° (popiersie 160°; portret ma własną regułę: tylko przed obrazem, 10 m, bez względu na światło), wyczucie 3,5 m; zasięg 22 / 12 / 7 m (jasność ≥ 0,45 / ≥ 0,15 / mniej), śpiący ×0,6, latarka = 22 m; sprawdzanie wzroku co 0,2 s (śpiący dalej niż 32 m od strażnika co 0,6 s); pamięć 1,5 s i najwyżej 5 m podążania; przeszukiwanie: dojście do 10 s + rozglądanie 6–10 s, przy przystani 8 s; tempo (część prędkości): sprawdzanie 0,7, przeszukiwanie 0,55, powrót 0,6, patrol 0,45; smycz 28 m (wilk, raptor 40 m); budzenie sąsiadów 8 m, ≤ 2; limit 8 polujących w 30 m (czekający 10 m od strażnika); trudność: wzrok ×0,75 / ×1 / ×1,15, limit 8 / 8 / 10 (`PerceptionWorld.set_difficulty`). Wydajność (pomiar bez okna, 120 śpiących + 10 patrolujących w lobby): ok. 500 sprawdzeń wzroku i 120 promieni na sekundę, 0,13 ms percepcji na klatkę fizyki.

### 13.4 Łup

- Punkty łupu leżą w pomieszczeniach; co noc 60% z nich dostaje przedmiot według wag: naboje 38, śrut 20, taśma 12, race 8, apteczka 22. Łup nie odradza się w trakcie nocy.
- Ilości: naboje 12, śrut 4, taśma 60, race 2, apteczka +25 zdrowia.

---

## 14. Poza zakresem MVP

- Kolejne piętra (m.in. skrzydło egipskie z mumiami, podziemia, magazyny) z rosnącą losowością układu.
- Więcej broni, ulepszeń, artefaktów i modyfikatorów nocy.
- Fabuła źródła przebudzeń i finałowy boss.
- Filtry retro (pikselizacja, paleta) jako opcja.
- Przygotowanie do wydania (np. Steam): sklep, osiągnięcia, zapis w chmurze.

---

## 15. Rejestr decyzji

| Data | Decyzja | Odrzucone alternatywy |
|---|---|---|
| 25.09 | Motyw: nocny stróż w muzeum, zejście w głąb do źródła przebudzeń | — |
| 25.09 | Roguelite **łagodny z checkpointami**; Pył odzyskiwalny jak w Dark Souls | klasyczny roguelite (jak Hades); prawie bez kary |
| 25.09 | Ton: mroczny z przymrużeniem oka + mięsista walka z wariantu horroru | komediowy; pełny horror / gore |
| 25.09 | Poziomy ręczne: lobby stałe, losowość rośnie w głąb | składane z sal (jak Dead Cells); hybryda |
| 25.09 | Ekonomia: Pył → trwałe ulepszenia, artefakty nocy, sekrety trwałe | — |
| 25.09 | Grafika: Claude robi wszystko (Blender, proceduralne tekstury) | assety użytkownika; generatory AI; sam greybox |
| 25.09 | Ruch umiarkowany z wytrzymałością | szybki klasyczny; wolny taktyczny |
| 25.09 | Kolejność: walka → pętla → oprawa | pełna pętla od razu; najpierw oprawa |
| 25.09 | T-Rex budzony kryształem, który gracz znajduje po włożeniu bezpieczników | — |
| 25.09 | **Bezpieczniki i kryształ odradzają się co noc** | trwałe raz włożone bezpieczniki |
| 25.09 | Bronie znalezione zostają na zawsze; start z pięściami i paralizatorem | — |
| 25.09 | **„Styl retro, nie jakość retro”**, nowoczesne światło; próbka stylu w etapie 1 | render w niskiej rozdzielczości |
| 25.09 | Silnik **Godot 4.7.2**; własny runner testów | Unity; GUT |
| 25.09 | Etap 1 dzielony na 1a (piaskownica) i 1b (próbka stylu) | jeden wspólny plan |
| 25.09 | Produkt końcowy to samodzielny `NocnaZmiana.exe` | tylko uruchamianie z edytora |
| 25.09 | Praca w Blenderze i edytorze przez computer use + skrypty dla powtarzalności | tylko skrypty bez okna |
| 30.09 | **Praca autonomiczna:** Claude decyduje do końca MVP, potem dopieszcza jeden obszar do poziomu dema na Steam (prośba właściciela) | decyzje uzgadniane na bieżąco |
| 30.09 | Etap 2 dzielony na podplany 2a, 2b-1, 2b-2, 2c-1, 2c-2, budowane równolegle w osobnych drzewach roboczych | jeden plan po kolei |
| 30.09 | Tarcza rycerza nie blokuje stromych strzałów z góry: nagroda za grę z balkonu | pełna osłona od przodu |
| 30.09 | Grafika: potok proceduralny w Blenderze (modele ze skryptów, tekstury pikselowe w atlasach), powtarzalny bit w bit | paczki CC0; ręczne modelowanie |
| 30.09 | GI: **SDFGI** (bez wypiekania, cały hol, ciepły odblask) | VoxelGI (droższe, wypiekanie przy każdym wczytaniu); bez GI |
| 30.09 | Poziom opisany **danymi** (`LobbyLayout`), skorupa rzeźbiona z pustych brył, wygląd podmieniany po identyfikatorze elementu | scena klikana ręcznie w edytorze |
| 30.09 | **Schody holu pod ścianami bocznymi**, 16 m biegu, 40 stopni (20,6°) | schody z projektu: 12 m (26,6°) — siatka nawigacji na nich nie powstawała, a bieg zasłaniał drzwi galerii |
| 30.09 | Ściany 0,5 m między stykającymi się pomieszczeniami; kryjówki sekretów dodane do układu | zerowa grubość ścian z projektu |
| 30.09 | Przystań zamknięta dla wrogów fizycznie (ściany tylko dla eksponatów), strażnik w środku dla nich niewidoczny | sama osobna warstwa nawigacji (tłum wpychał się do środka, wilk mógł wskoczyć) |
| 30.09 | **Przystań to schronienie, nie wieżyczka:** broń opuszczona | strzelanie z bezpiecznej strefy |
| 30.09 | Leczenie i zapis w przystani najwyżej raz na 30 s nocy | leczenie przy każdym wejściu (stacja leczenia w drzwiach) |
| 30.09 | **„Kontynuuj” wznawia przerwaną noc** (eksponaty, łup, zdrowie, amunicja) | nowa noc po każdym wyjściu |
| 30.09 | Niesiony Pył przeżywa wyjście do menu | utrata Pyłu przy wyjściu (kara surowsza niż śmierć) |
| 30.09 | Bez latarki przy 0 Pyłu (starsza i tak przepada) | stawianie pustej latarki |
| 30.09 | **Domyślnie pełny ekran** | zmaksymalizowane okno (jak w 1a) |
| 30.09 | Slug to drugi ładunek tych samych łusek (przytrzymanie R) | osobna amunicja |
| 30.09 | Ulepszenia broni do kupienia przed jej znalezieniem | blokada do czasu znalezienia |
| 30.09 | Mnożniki Pyłu liczone raz, przy zabiciu | na każdej drobinie (zaokrąglenia by się mnożyły) |
| 30.09 | Jeden właściciel kursora i wejścia (`GameInput`, stos menu); utrata fokusu okna = pauza (klik powrotu nie strzela) | każde menu samo łapie mysz |
| 30.09 | **Wszystko na D:** zapis, opcje i log obok exe (`save/`); w wersji roboczej `tools/godot/editor_data/nz_save/` | standardowy `user://` (`%APPDATA%` na C:) |
| 30.09 | **Wyeksportowana gra bez pamięci podręcznej shaderów** — Godot umie ją trzymać tylko na C:; koszt: kompilacja przy każdym starcie | pamięć podręczna w `%APPDATA%` na C: |
| 30.09 | Bezpieczny zapis: `.tmp` + `.bak`, zepsuty plik jako `.bad`, plik z nowszej wersji nietknięty | prosty zapis w miejscu |
| 30.09 | T-Rex jako osobna klasa, ruch bez siatki; szarża kończy się 7 m za graczem; ogłuszenie tylko po uderzeniu w ścianę lub kolumnę; uśpiony nie przyjmuje obrażeń; rampy schodów są dla niego ścianą | potomek zwykłego eksponatu; ogłuszenie po każdej szarży; szarża na balkon |
| 30.09 | Szarża z bliska dozwolona, a odnowienie biegnie 2× szybciej, gdy strażnik stoi przed pyskiem bliżej niż 6 m | bezpieczne stanie pod klatką piersiową |
| 30.09 | Ogłuszony T-Rex odkłada łeb na bok, strefa kryształu 0,26 m | łeb na wprost (kryształ zasłonięty z przodu w 97%) |
| 30.09 | **Ogon T-Reksa: 6 m i ok. 45° od kierunku „z tyłu”, zapowiedź 0,75 s**; trafia tam, gdzie przechodzą kręgi; martwe pole pod nasadą | 7 m / 70° / 0,6 s z projektu (trafiał tam, gdzie ogona nie było) |
| 30.09 | Popiersie strzela tylko z linią wzroku także w chwili strzału | strzał po zapowiedzi bez sprawdzenia |
| 30.09 | Testy z `--fixed-fps 60` (ok. 40 s zamiast 3,5 min) | testy w czasie rzeczywistym |
| 30.09 | **Najpierw kompletny pierwszy obszar, potem nowe piętra:** rozbudowa lobby o 2 bronie, 2 wrogów, 8 ulepszeń, zegar nocy i CCTV | od razu kolejne piętra |
| 30.09 | **Zegar nocy 23:00–6:00** (3 min na godzinę), godzina duchów o 3:00, **świt kończy noc bez śmierci i Pył zostaje** | noc bez limitu czasu |
| 30.09 | Zegar stoi w przystani do 60 s na wizytę | zegar zawsze biegnie; przystań jako zamrażarka czasu |
| 30.09 | **Widok kamer nie pauzuje gry** (zegar biegnie, to ryzyko) | pauza na czas podglądu |
| 30.09 | Kartaczownica: taśma bez przeładowania, −35% ruchu i bez sprintu przy spuście, wstrząs z sufitem, żar luf i dym; łańcuch zrywa strzelba albo 3 ciosy | przeładowanie; shader falowania powietrza (gryzie się z FOV broni) |
| 30.09 | Rakietnica: wybuch też jest ogniem (wosk ×2); własny wybuch zabiera najwyżej to, co strażnik ma powyżej połowy zdrowia; najwyżej 8 rac naraz; zbicie szafki budzi eksponaty w 16 m | brak obrażeń własnych |
| 30.09 | Raptory w stadach 3–4 z flankowaniem; ryk T-Reksa woła raptory albo figury 50/50 | pojedyncze raptory |
| 30.09 | Portrety: 2–4 z 12 obrazów, twarz przypisana do miejsca | stałe portrety w stałych miejscach |
| 30.09 | Łup: amunicja do broni, której strażnik nie ma, zamienia się na naboje albo śrut | bezużyteczna amunicja |
| 30.09 | Szuflada z kluczem i szafka na pistolet; kartka Heńka leży, dopóki klucz nie zostanie znaleziony | kartka tylko w noc 1 |
| 30.09 | Bezpieczniki i skrzynka przez E (świadome podniesienie) | podnoszenie dotykiem |
| 30.09 | Walka z T-Reksem w zamkniętym holu, z zaopatrzeniem na start i przy fazach 2 i 3 | otwarty hol (boss klinował się w drzwiach skrzydeł) |
| 30.09 | „Kontynuuj” w trakcie celu: bezpieczniki i zwarcie zostają, lot kryształu i walka zaczynają się od nowa; po zwycięstwie każda noc to epilog | wznowienie w środku walki |
| 30.09 | Wprowadzenie nocy 1: trzy podpowiedzi raz na instalację | raz na grę; osobny samouczek |
| 30.09 | Karta nocy przy każdym starcie, także bez modyfikatora | karta tylko przy modyfikatorze |
| 1.10 | **„Kontynuuj” to nie farma Pyłu:** stado wraca bez martwych, zaopatrzenie raz na fazę na noc, wezwani przez ryk warci 1 Pył | pełne odrodzenie po wznowieniu |
| 1.10 | Minuta zegara w przystani wraca dopiero po 20 s poza nią | każde wejście = nowa minuta |
| 1.10 | Gdy T-Rex nie śpi, przystań nie leczy i nie zapisuje | odpoczynek tuż obok areny |
| 1.10 | Świt od razu odbiera strażnikowi ręce i zatrzymuje cel; boss dobity po świcie albo po śmierci nie daje zwycięstwa | zwłoka do końca animacji świtu |
| 1.10 | Widok kamer zamyka się sam przy ranie, śmierci, świcie i utracie fokusu | widok otwarty do Esc |
| 1.10 | „Kontynuuj” pamięta wzięte artefakty i drzwi otwarte kluczem woźnego; klucz nie otwiera drzwi holu zamkniętych na walkę | — |
| 1.10 | Notatki do ponownego czytania w menu pauzy | tylko w świecie |
| 1.10 | Dźwięk i muzyka w całości syntetyzowane skryptami, Ogg Vorbis powtarzalny bajt w bajt; muzyka adaptacyjna ze stanami i warstwami | biblioteki CC0 z pierwotnego planu |
| 1.10 | Kroki: cztery zestawy materiałów, powierzchnia według podłóg zestawu architektury | osobny zestaw na każdą podłogę |
| 1.10 | Zestaw modułowy architektury holu (119 modeli, kafle 64 px/m mapowane w świecie), stawiany z danych układu | ręcznie składane sale |
| 1.10 | Księżyc niewidoczny dla kamer CCTV (cienie księżyca liczone osobno dla każdej kamery zjadały ok. ¼ klatki) | pełne światło w podglądach |
| 3.10 | Strażnicy animowani kodem: klatki kluczowe w GDScripcie (`MotionClip`) próbkowane w czasie etapu ataku, sprężyny ruchu wtórnego, IK; ciosy celują tam, gdzie stoi strażnik | akcje z Blendera w `AnimationPlayer` |
| 3.10 | Kolos sięga posadzki „ścięgnami światła” (kamienne człony ramienia rozsuwają się w stawach) | realistyczny zasięg (dłoń nie sięga posadzki) albo rozciąganie członów |
| 3.10 | Kolumny Sali Kolosa należą do strażnika (pękają i łamią się), stawiane co noc przez jego skrypt (`dress_arena`); poza wypieczoną siatką nawigacji | elementy poziomu z kolizją |
| 3.10 | Fazy Planetarium liczą zestrzelone planety (2 → faza 2, 4 → faza 3, 6 → odsłonięty rdzeń), pasek zdrowia = suma pul planet i rdzenia | progi zdrowia jak u innych strażników |
| 3.10 | Ramiona Planetarium bez kolizji fizycznej: kapsuła strażnika sprawdzana z belkami, prętami, planetami i wahadłami księżyców co klatkę | obrotowe ciała kinematyczne (pchałyby gracza w ściany) |
| 3.10 | Wiszące księżyce, Księżyc Ziemi i pierścień Saturna wycinane z siatek modelu w grze (`MeshShards.partition`), żeby się kołysały | przebudowa modelu w Blenderze |
| 3.10 | Kentaur chodzi warstwą chodu (`CentaurGait`: takty czterech nóg, kopyta w świecie przez IK), na którą klipy ataków nakładają ruch; śpi w metopie bokiem do wejścia i wyrywa się z niej | klipy chodu z Blendera; przesuwanie modelu bez kroków; kentaur twarzą do wejścia |
| 8.10 | **Generał samurajów: 1000 punktów zdrowia** (strojone botem scenariusza: 1250 z planu dawało 85 s, 1000 daje 78 s; rezerwa, gdyby playtest uznał pojedynek za długi: 850 jak u Kentaura albo słabszy blok ±55° zamiast ±70°); w chudan klinga odbija trafienia z przodu, słabe punkty to twarz i węzeł agemaki | 1250 z planu; blok bez wyjątku; brak postawy obronnej |
| 8.10 | **Faza 2 Generała na okapie herbaciarni**, zrobionym elementem ogrodu (dach greyboxowej herbaciarni jest odcięty ścianą i niewidoczny z areny; punkt `arena_general_perch`, a model `teahouse` z węzłem `roof_perch` przejmuje go po ubraniu); okap zatrzymuje strzały jak skała, więc strażnik tuż przy ścianie herbaciarni pod okapem jest przed salwami osłonięty — świadoma osłona, nie błąd | dach niewidoczny z areny; zmiana pokoi i przebudowa pamięci powłoki; strzały ponad okapem |
| 8.10 | **Herbaciarnia nie leczy i nie zapisuje, dopóki Generał nie padnie** (`GuardianKeeper.HAVEN_GUARDS`, toast „brak odpoczynku”), jak przystań przy T-Reksie; po jego upadku działa jak każda | przystań czynna od początku (odpoczynek tuż obok areny) |

---

## 16. Otwarte kwestie dla właściciela

### 16.1 Do decyzji

1. **Szybszy start gry czy nic na C:?** Wyeksportowana gra nie trzyma pamięci podręcznej shaderów, bo Godot zapisuje ją tylko w folderze Windows na C:. Skutek: dłuższe wczytywanie i możliwe przycięcia przy pierwszych efektach po każdym uruchomieniu (w toku jest rozgrzewanie efektów pod wyciemnieniem na starcie nocy). Można też pozwolić grze na mały folder `%APPDATA%\Nocna Zmiana` na C:.
2. **Zapis przy wydaniu na Steam.** Dziś zapis leży obok exe. Na Steam zwykle używa się standardowego folderu użytkownika (`user://`) i chmury Steam. Decyzja przed przygotowaniem wydania.
3. **Ekonomia Pyłu po rozbudowie.** 18 ulepszeń kosztuje razem 1320 Pyłu (pierwsze 10: 785, cel 4–7 nocy). Przy szacowanych 120–220 Pyłu za noc pełne ulepszenie to dziś ok. 6–11 nocy. Przeliczyć ceny czy zostawić dłuższą progresję?
4. **Pełny ekran domyślnie** (w 1a było zmaksymalizowane okno). Potwierdzić.
5. **Ogon T-Reksa** krótszy i węższy niż w projekcie (6 m i ok. 45° zamiast 7 m i 70°, zapowiedź 0,75 s), za to trafia dokładnie tam, gdzie widać ogon. Potwierdzić po walce.
6. **Kroki.** Zestaw ma cztery materiały (kamień, drewno, dywan, metal). Linoleum w kanciapie, lastryko w dioramie i beton w korytarzach brzmią więc jak kamienna posadzka, a dywanów w lobby nie ma. Dodać zestawy (np. linoleum) albo chodniki w salach?
7. **Obrażenia własne rakietnicy.** Projekt mówi „nie rani strażnika powyżej 50%”. Zbudowane: własny wybuch zabiera najwyżej to, co jest powyżej połowy zdrowia (przy pełnym zdrowiu −20, przy połowie 0), i zawsze odpycha. Czy o to chodziło?
8. **Kierunek graficzny.** Bramką etapu 1b była akceptacja próbki stylu, a nigdzie nie jest zapisana. Prośba o ocenę [próbki i zestawu holu](art/styl-przewodnik.html) (najlepiej po scaleniu ubranego lobby).
9. **Nazwy robocze:** waluta „Pył” i tytuł „Nocna Zmiana”.

### 16.2 Do sprawdzenia w pierwszych testach gracza

- **Długość nocy:** 21 minut do świtu (plus minuty w przystaniach). Pierwsze przejście miało trwać 20–30 minut. Czy świt nie przychodzi za wcześnie dla nowego gracza?
- **Widok kamer bez pauzy:** czy ryzyko jest ciekawe, czy irytujące?
- **Walka z T-Reksem:** długość (szacunek 2–2,5 min), czytelność szarży i ogona, wystarczająco zaopatrzenia?
- **Przystanie:** czy 30 s między leczeniami i minuta zegara na wizytę czują się uczciwie?
- **Trudność pierwszej nocy** i tempo zdobywania broni (pistolet przez kasę, strzelba i kartaczownica w zbrojowni, rakietnica w dioramie).
- **Rozwiązane od 1a:** klik, który przechwytuje mysz z powrotem do gry, nie oddaje już strzału (utrata fokusu otwiera pauzę). Warto potwierdzić w grze.

### 16.3 Uwagi techniczne (bez decyzji)

- Napis wersji w menu głównym (`MENU_VERSION`) wciąż mówi „etap 2a”. Do aktualizacji przy najbliższym szlifie.
- `WeaponPickup` nadal korzysta wprost z autoloadów (dług techniczny z przeglądu 2a, nieszkodliwy).
- Godot 4.7.2 przy zamykaniu sceny z sondą odbić wypisuje ostrzeżenie o „wyciekniętych” teksturach. To znany, nieszkodliwy błąd silnika; testy go nie liczą.
- Kosmetyka historii: commit `94ee73d` ma w stopce innego współautora niż pozostałe. Historii świadomie nie przepisywano.
