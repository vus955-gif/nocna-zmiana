# Fabuła Piętra I — biblia dla autorów tekstów

> **Stan:** 3 października 2026, gałąź `lore-notes` (od `pietro-1`). Teksty gry: `locale/strings.csv` (klucze `NOTE_*`, `TIP_*`, `END_FLOOR1_EPILOGUE`, `ROOM_*`).
> **Dla kogo:** dla każdego, kto dopisuje notatki, tabliczki, podpowiedzi albo fabułę Piętra −1. Najpierw ten dokument, potem istniejące teksty.
> Projekt Piętra I: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md`. Specyfikacja całości: `docs/Nocna-Zmiana-specyfikacja.md`.

---

## 1. Ton i zasady pisania

- **Mroczny z przymrużeniem oka.** Puste nocne muzeum, latarka, humor w notatkach i opisach. **Im głębiej, tym mroczniej:** notatki na parterze są zabawne, w kryjówkach i w podziemiach coraz mniej do śmiechu.
- **Notatka to dokument ze świata gry**, nie instrukcja: strona dziennika, zlecenie serwisowe, list, karta informacyjna, regulamin, odpis. Ma autora, epokę i powód, dla którego leży właśnie tam.
- **Każda notatka skrzydła niesie przydatną wskazówkę** — powiedzianą językiem świata („łańcuch puści, jak się w niego porządnie walnie”), zgodną z projektem: słaby punkt strażnika, rodzaj zamka, sekret, skrót. Wskazówki nigdy nie przeczą mechanice.
- **Polski jest pierwszy**, angielski to pełne tłumaczenie, nie streszczenie (brytyjska angielszczyzna: *torch*, *armour*). W polskim cudzysłów „…”, w angielskim “…”. **Bez prostego cudzysłowu `"` i bez znaku `%`** w tekstach (CSV i test symboli zastępczych).
- **Fakt, ekstrapolacja, fikcja.** Prawdziwe eksponaty i fakty historyczne są prawdziwe (lista w §8). Ludzie są **fikcyjni** — nie wkładamy słów w usta postaci historycznych (dlatego gabinet „Sloane'a” stał się gabinetem kolekcjonera, §2).
- **Tajemnica zamiast wykładu.** Notatki pokazują ślady, różne osoby mają różne teorie, żadna nie jest potwierdzona. Gracz składa obraz sam.

### Długość a czytnik
Czytnik (`NoteReader`) pomniejsza kartkę wyższą niż ekran. Pomiar wysokości kartki (szerokość 780 px):

| Papier | Krój | Ile się mieści bez dużego pomniejszenia (ekran 1080p) |
|---|---|---|
| `LINED` (zeszyt), `FORM` (zlecenie) | odręczny, wysokie wiersze | **ok. 100–120 słów PL** (dłuższe EN o ~30%) |
| `TYPED` (maszynopis), `LETTER` (list, dawny rękopis) | maszynowy / szeryfowy kursywą | ok. 130–180 słów PL |
| `STICKY` (karteczka) | odręczny, kwadrat | do ok. 40 słów |

Najdłuższe notatki Piętra I mają ok. 1300–1380 px wysokości (skala ok. 0,65 na 1080p); notatki lobby 500–980 px. Krócej znaczy lepiej. Rodzaj papieru ustawia `NoteCatalog.PAPER` (bez wpisu: `LINED`).

---

## 2. Świat

- **Muzeum Miejskie** — wielkie dziewiętnastowieczne muzeum zbudowane wokół **Wielkiego Dziedzińca** ze szklanym dachem i okrągłą **Czytelnią** w środku. Inspiracja: British Museum, z jego prawdziwymi eksponatami (Kamień z Rosetty, lamassu, szachy z Lewis…). Nazwa i ludzie są polscy i fikcyjni; ślady brytyjskiego pierwowzoru (Biblioteka Królewska, piwnica Montagu House) zostają jako mrugnięcie.
- **Fundatorzy** — założyciele muzeum, pochowani w **krypcie** pod korytarzem północnym, za kratą. Wśród nich **Ksawery Zawilski**, kolekcjoner (zbiory przyrodnicze i astronomiczne, astrolabium, sztucer), pochowany „twarzą do schodów”. Fundatorzy zakazali schodzić niżej krypty. Na ich starych planach pod kryptą jest kondygnacja opisana tylko „−1”; na nowszych planach jej nie ma.
- **Pod kryptą** schody idą „dalej, niż powinny”. Stamtąd od zawsze dochodzi **równe stukanie, jak zegar albo serce** (1912, 1931, dziś). Kiedy stuka głośniej, eksponaty chodzą śmielej.
- **Kryształ** — czerwony kamień, który bije jak serce. „Minerał nieznanego pochodzenia, dar anonimowy”: przyszedł pocztą, bez nadawcy. Kustosz osadził go w pustym pierścieniu astrolabium w Czytelni (pasował co do milimetra), wbrew testamentowi Zawilskiego. **Tamtej nocy** kamień pękł i rozleciał się w sześć czerwonych smug, do sześciu skrzydeł. W każdym skrzydle coś największego połknęło odłamek i zostało **strażnikiem**. Na drzwiach „wyrosły” zamki w kształcie słońca, skrzydła, sowy i gwiazdy (pieczęcie). Sześć odłamków w astrolabium scala kamień; kamień leci do szkieletu T-Reksa; gdy T-Rex pada, kamień pęka drugi raz, a krata do krypty się otwiera.
- **Pył** — to, co zostaje po rozbitym eksponacie. Terminal w przystani „coś za niego daje”.

### Co wie gracz, a co jest prawdą autorską

**Gracz wie (z notatek):** eksponaty budziły się już w 1912; stukanie spod krypty rośnie i słabnie razem z nimi; kamień przyszedł w paczce zaadresowanej ręką stróża Kopcia, który zszedł pod kryptę w 1912, ze stemplem z października 1912; Zawilski zbudował astrolabium z pustym gniazdem i zakazał je wypełniać, bo „kamień, który się złoży, upomni się o drogę w dół”; w Egipcie, Asyrii, Chinach i na Pacyfiku znano opowieści o tym samym kamieniu (serce, którego nie można zważyć; kamień z Apsu; perła smoka; światło w brzuchu kaszalota), zawsze z motywem zejścia pod ziemię.

**Prawda autorska (propozycja, do zatwierdzenia przez właściciela; w grze jeszcze niepotwierdzona):**
- Pod muzeum śpi coś, co bije jak serce. Kryształ jest jego odpryskiem. Różne kultury znajdowały takie odpryski i za każdym razem kończyło się „zejściem w głąb”.
- Kamień budzi to, **co pamięta** — rzeczy, na które patrzyły miliony oczu. Za dnia spojrzenia zwiedzających trzymają eksponaty w miejscu („O szóstej wszystko wraca na swoje miejsce”), nocą nikt nie patrzy. Pył to resztka tej pamięci.
- Fundatorzy wiedzieli. Muzeum jest **pokrywą**: krypta nad zejściem, fundatorzy pochowani twarzą do schodów, astrolabium jako klatka z pustym gniazdem, drzwi do piwnic ryglowane „od strony sal”.
- Kamień chciał zostać złożony i chciał, żeby ktoś zszedł na dół. **Gracz, składając odłamki, robi dokładnie to, przed czym ostrzegał Zawilski.** Paczka napisana ręką Kopcia to przynęta: to, co jest na dole, posługuje się tymi, którzy zeszli wcześniej.
- Piętro −1 może tę prawdę potwierdzić, zniuansować albo odwrócić. Ważne, żeby nie zaprzeczać faktom z notatek (daty, nazwiska, kolejność zdarzeń).

---

## 3. Postacie

| Postać | Kim jest | Epoka | Stan | Gdzie występuje |
|---|---|---|---|---|
| **Heniek** (Henryk) | dawny nocny stróż, mentor „Młodego” (gracza); żartuje, ale wie najwięcej | dziś | **żyje**, na zwolnieniu (noga, raptor); „wróci, jak przestanie swędzieć” | karteczka „Młody!” (`NOTE_KEY`), kawiarnia (`NOTE_COURT_1`), kryjówka za moai (`NOTE_AMERICAS_3`), dopiski „(H.)” w książce raportów (`NOTE_GREECE_3`); w lobby `NOTE_1` |
| **St. Mazur** | stróż pechowiec; przegrał zegarek po dziadku z woskowym Napoleonem; wciąż prosi o zmianę dzienną | dziś | żyje (siedział w klatce lwów) | `NOTE_ASSYRIA_4`, dopiski „(S.M.)” (`NOTE_GREECE_3`, `NOTE_ASSYRIA_1`); w lobby `NOTE_2` |
| **dr A. Wróblewski** | kustosz; zachwycony darem, osadził kamień w astrolabium | dziś | **bezterminowy urlop**; ostatnio widziany przy kracie w korytarzu północnym, jak nasłuchiwał | `NOTE_COURT_2`; w lobby `NOTE_CHAMBER` („mnie się już nie przyda”) |
| **R. Gil** | konserwator (= złota rączka i elektryk), pisze zlecenia serwisowe | dziś | żyje | `NOTE_EGYPT_2`, `NOTE_GREECE_4`, `NOTE_ASSYRIA_3`, `NOTE_BASEMENT_3` (W5b); w lobby `NOTE_VENT` |
| **B. Wierzbicka** | kasjerka; liczy utarg, nie klucze | dziś | żyje | `NOTE_ENTRANCE_1` |
| **J. Kopeć** | stróż nocny | 1912 | **zaginiony** od nocy 17/18 X 1912 — zszedł pod kryptę; latarni nie znaleziono | `NOTE_BOOTH_1`; w lobby `NOTE_NICHE` (instrukcja 1912); w `END_FLOOR1_EPILOGUE` jego latarnia, „jeszcze ciepła” |
| **Ksawery Zawilski** | kolekcjoner, fundator; zapisał muzeum astrolabium i sztucer | zm. ok. 1870 (testament 1869) | pochowany w krypcie twarzą do schodów | `NOTE_ENLIGHTENMENT_2`, wspomniany w `NOTE_COURT_2` |
| **F. Zaręba** i **Profesor** | rysownik i kierownik ekspedycji do Teb; tragarz Hasan | 1898 | — | `NOTE_EGYPT_1`, `NOTE_EGYPT_4` |
| **prof. T. Mirecki** | asyriolog; tłumaczy tabliczkę bez sygnatury | XX w. / dziś | słyszy nocą skrobanie rylców | `NOTE_ASSYRIA_2` |
| **Antoni Lipski** | rzeźbiarz, robił odlewy metop | lata 20. XX w. | — | `NOTE_GREECE_1` |
| **E. Turek** | gołębiarz; gołębnik na dachu | dziś | — | `NOTE_GREECE_2` |
| **mgr I. Kostecka** | bibliotekarka Biblioteki Królewskiej | dziś | — | `NOTE_ENLIGHTENMENT_1` |
| **dr E. Sztern** | obserwatorka (astronom) w galerii obserwatorów Planetarium | dziś | — | `NOTE_ENLIGHTENMENT_3` |
| **T. Bury** | introligator; odkrył, czyją ręką zaadresowano paczkę; zabił introligatornię deskami | dziś | nieznany | `NOTE_ENLIGHTENMENT_4` |
| **Okamura** | mistrz herbaty w herbaciarni ogrodu japońskiego | dziś | — | `NOTE_ASIA_2` |
| **W. Kowalik** | płatnerz muzealny | dziś | — | `NOTE_ASIA_3` |
| **A. Rudnicki** | kierownik wyprawy do Azji | 1910 | — | `NOTE_ASIA_4` |
| **J. Szczygieł** | bosman na wielorybniku „Hope” | 1851 | — | `NOTE_AMERICAS_1` |
| **H. Bielecka** | przewodniczka (nocna wersja oprowadzania) | dziś | — | `NOTE_AMERICAS_2` |
| **W. Pająk** | stróż nocny; jego świeca nie gaśnie (artefakt „Ogarek świecy”) | 1931 | — | `NOTE_AMERICAS_4` |
| Postacie W5b | **M. Lis** (konserwatorka, warsztat renowacji), **Z. Węgiel** (palacz; „Bezpiecznik dalej na pomoście. Ja nie.”), **brygada dekarska nr 2**, woskowy Kopernik | dziś | Węgiel — niejasne | `NOTE_BASEMENT_1…2`, `NOTE_ROOF_1` |
| Lobby (poziom testowy) | **woźny Zdzisław** (gubi klucz do wszystkich drzwi), autor bez podpisu notatki o kamieniu i Reksie | dziś | — | `NOTE_CLOSET`, `NOTE_3`; klucz woźnego (artefakt) |

**Gracz** to „Młody” — nowy nocny stróż, który przejmuje zmianę po Heńku.

---

## 4. Oś czasu

| Kiedy | Co |
|---|---|
| 1851 | Bosman Szczygieł widzi kaszalota ze światłem w brzuchu; później oddaje szalupę i harpunnik do muzeum. |
| ok. 1868–1870 | Fundatorzy budują muzeum nad starymi piwnicami; krypta nad zejściem. Testament Zawilskiego (1869): astrolabium z pustym pierścieniem, sztucer, ukryty gabinet, pochówek twarzą do schodów. |
| 1898 | Ekspedycja do Teb: grób kapłana Amona, puste gniazdo w kształcie serca, papirus „Serce, którego nie można zważyć, zeszło pod ziemię”. Mumie wstają, gdy ktoś zabiera strzelbę ze stołu. Obóz trafia do muzeum w całości. |
| 1910 | Wyprawa do Azji: lwy Fu z „perłą smoka” w pyskach, zbroja Generała, który „nie skończył warty”. Skrzynie w piwnicy pod Salą Chin. |
| 1912, październik | Stróż Kopeć: eksponaty chodzą, spod krypty stuka. 17/18 X schodzi pod kryptę („na dole ktoś zostawił zapalone światło”) i znika. |
| lata 20. | Rzeźbiarz Lipski robi odlewy metop: marmur nocą ciepły, pierś Kentaura miękka. |
| 1931, 11/12 III | Awaria prądu; stróż Pająk przy świecy. Totem nr 3 znika w ścianie i śpiewa pod podłogą. Magazyn pod Salą Totemów zabity deskami. Świeca nie gaśnie. |
| 1939–1940 | Komnata za obrazem zamurowana przed okupantem (lobby); schron przeciwlotniczy w podziemiach (W5b). |
| „dziś”, przed grą | Paczka bez nadawcy: kryształ. Kustosz osadza go w astrolabium. Eksponaty silniejsze („Rex patrzy”). |
| „tamta noc” | Kryształ pęka na sześć; powstają strażnicy i pieczęcie. Heniek łamie nogę (raptor). Kustosz bierze bezterminowy urlop. Introligator oprawia papier z paczki i odkrywa rękę Kopcia. |
| gra (3–4 noce) | Młody zbiera odłamki, scala kryształ, pokonuje T-Reksa i schodzi pod kryptę. |

---

## 5. Notatki Piętra I: co odsłaniają i co podpowiadają

Znaczniki `note_<strefa>_<n>` w `src/level/floor1/zones/*.gd`; teksty `NOTE_<ID>_TITLE / _BODY / _SIGN`. `note_heniek` w kanciapie to karteczka `NOTE_KEY` (znika, gdy klucz jest znaleziony).

### Hol, kanciapa, Dziedziniec

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_BOOTH_1` | stróżówka 1912 pod korytarzem (sekret za łańcuchem u stóp schodów) | LETTER | dziennik stróża Kopcia, X 1912 | eksponaty chodziły już w 1912; stukanie spod krypty; Kopeć schodzi i znika | mumie boją się ognia; łańcuch puszcza od mocnego ciosu; drzwi do piwnic ryglują się od strony sal (skróty) |
| `NOTE_ENTRANCE_1` | kasa biletowa, przy szufladzie | LINED | kartka kasjerki | — (humor; „ktoś inny puka od zewnątrz”) | szuflada z kluczem; szafka pożarowa głośna; raca topi wosk; schowek za ścianą szatni: trzy race z bliska |
| `NOTE_COURT_1` | lada kawiarni (NW) | LINED | Heniek | dar bez nadawcy, astrolabium, rozpad na sześć smug, strażnicy, pieczęcie; kustosz na urlopie, nasłuchiwał przy kracie | T-Rex: szarża w bęben Czytelni ogłusza, wtedy w kryształ; sekret pod ladą informacji |
| `NOTE_COURT_2` | biurko w Czytelni (za Pieczęcią Sowy) | TYPED | notatka służbowa kustosza | testament Zawilskiego, puste gniazdo, wina kustosza („Uważałem.”) | sześć odłamków do astrolabium; słaby punkt T-Reksa: kryształ, nie kości; ryk woła eksponaty; szkło z dachu — patrz na cienie; kartaczownica: łańcuch |

### Egipt

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_EGYPT_1` | stół obozu, przy strzelbie | LETTER | dziennik rysownika, Teby 1898 | mumie wstały, gdy wzięto strzelbę | zasadzka przy strzelbie; bicz z bandaży — stój z boku; ogień: mumia płonie i ucieka |
| `NOTE_EGYPT_2` | biurko w pokoju konserwatora (przystań) | FORM | zlecenie nr 203 (Gil) | — | Kolos: płyty na piersi (wybuch je zrywa), pęknięcia i ureusz; cień dłoni i fala, zamach nisko (skacz); promień, kolumny pękają; skarabeusze (śrut, ogień); ucieczka go uspokaja; serdab (wybuch), fałszywe drzwi (żelazne ucho); szachy za tronem |
| `NOTE_EGYPT_3` | ławka w Przedsionku Rosetty | TYPED | komunikat dyrekcji | — (humor) | figury woskowe łatwopalne; jedna patroluje galerię; strzelba „nienaładowana” |
| `NOTE_EGYPT_4` | skrzynia w składzie ekspedycji (sekret za łańcuchem) | TYPED | spis skrzyń 1898 | puste gniazdo w kształcie serca, papirus o sercu, które „zeszło pod ziemię”; gniazdo = pierścień astrolabium | fałszywe drzwi kapłana mają ucho do transportu (harpun) |

### Grecja

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_GREECE_1` | biurko w magazynie odlewów (przystań) | LETTER | list rzeźbiarza Lipskiego | marmur nocą ciepły | Kentaur: słaby w torsie i głowie; oszczep łukiem, kopnięcie dęba z bliska, szarża przez galerię — chowaj się; Lapici przy wejściu zejdą razem |
| `NOTE_GREECE_2` | strych nad Bassae (sekret na linie) | LINED | gołębiarz Turek | szklany dach świeci od spodu na czerwono, najmocniej nad kratą | Sala Waz: spękana ściana → skorupy → drzwi z uchem (harpun); dach: właz na linie z podestu holu, kładki do wieży Oświecenia |
| `NOTE_GREECE_3` | ławka w Sali Metop | LINED | książka raportów nocnych, str. 112 (Mazur, Heniek, Dyrekcja) | — (humor) | hoplici: tarcza z przodu, paralizator ją opuszcza, strzał z góry przechodzi; pchnięcie na 3 m (grot błyska); popiersia pękają i świecą przed strzałem, odłamek da się zestrzelić; magazyn odlewów = przystań |
| `NOTE_GREECE_4` | korytarz pod Galerią Partenonu (y −6) | FORM | zlecenie nr 248 (Gil) | stukanie „jakby się śmiało” | skrót do podestu holu (zasuwa od Grecji); drzwi do podziemi z każdego skrzydła; żaluzje bez prądu — dwa bezpieczniki |

### Asyria

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_ASSYRIA_1` | ława w Bramie Chorsabadu | TYPED | karta informacyjna o lamassu z dopiskami nocnej zmiany | — (humor: „co to p.n.e.”) | Lamassu: grzebie kopytem przed szarżą, skrzydła = podmuch (za kolumnę), tupnięcie = fala (skacz), słaby w twarz i koronę, w połowie budzą się wojownicy; wojownicy z reliefu: z boku płascy, z przodu w oko, uskakują; bezpiecznik na rusztowaniu w Galerii Nimrud budzi rusztowanie |
| `NOTE_ASSYRIA_2` | biurko w Bibliotece Assurbanipala | LETTER | przekład tabliczki (Mirecki) | kamień z Apsu rozbity „na [sześć]” i rozdany strażnikom; złożony otworzy drogę w dół; ktoś nocą pisze dalej | magazyn tabliczek za spękaną ścianą (wybuch) |
| `NOTE_ASSYRIA_3` | kabina windy towarowej (sekret za łańcuchem, y −6) | FORM | zlecenie nr 311 (Gil) | winda jeździ sama; zamalowany przycisk „−1”; stare plany fundatorów; mokry ciepły piasek | drzwi do podziemi: zasuwa od tej strony (skrót) |
| `NOTE_ASSYRIA_4` | klatka lwów królewskich (sekret na linie) | LINED | raport Mazura z klatki | — (humor) | lwy z reliefu skaczą jak wilki, po skoku bezbronne; z boku płaskie; krata na linie |

### Oświecenie

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_ENLIGHTENMENT_1` | biurko w gabinecie bibliotekarza (przystań) | TYPED | regulamin po zmroku (Kostecka) | introligator coś ukrył | latające księgi (szelest i okładki = nurkowanie; palą się); lina Planetarium: tylko sztucer, z galerii obserwatorów; krata na linie w Sali Zegarów (archiwum); introligatornia za deskami; regał z uchem (gabinet kolekcjonera) |
| `NOTE_ENLIGHTENMENT_2` | stół ze sztucerem | LETTER | testament Zawilskiego (1869) | pierścień astrolabium ma zostać pusty; „kamień, który się złoży, upomni się o drogę w dół”; pochówek twarzą do schodów | sztucer przebija trzech, słaby punkt kładzie jednym strzałem; wilki i raptory wstają, gdy się go weźmie; gabinet na żelaznym uchu |
| `NOTE_ENLIGHTENMENT_3` | biurko w galerii obserwatorów | LINED | dziennik obserwacji (Sztern) | czerwona planeta krąży pod posadzką, „jej słońce głęboko pod nami” | Wielkie Planetarium: ramiona na trzech wysokościach (nisko skacz, wysoko stań w luce), sześć planet do zestrzelenia, potem słońce; lina — sztucer stąd |
| `NOTE_ENLIGHTENMENT_4` | introligatornia (sekret za deskami, y −6) | LINED | teczka introligatora | **rozwiązanie zagadki darczyńcy:** paczka ze stemplem z X 1912, zaadresowana ręką Kopcia; przyszła ciepła | — |

### Azja

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_ASIA_1` | przy ognistej skrzyni w Sali Koreańskiej | TYPED | etykieta hwachy z dopiskami | — (humor: „pokaz sylwestrowy”) | salwa kruszy spękany mur (obok Buddy prześwituje ogród); lwy Fu: kula w pysku świeci przed rykiem, ryk ogłusza, strzelaj w kulę; zbroje jak rycerze; Generał: błysk ostrza przed cięciem, w gardzie odbija z przodu (obejdź, paralizator), słaby w twarz pod maską i w plecy; skrót do Planetarium |
| `NOTE_ASIA_2` | niski stolik w herbaciarni (przystań po Generale) | LETTER | mistrz herbaty Okamura | staw płynie w dół; dzwon uderzany od spodu | kapliczka z dzwonem: krata na linie (celny strzał); przystań wstrzymuje zegar „niedługo” |
| `NOTE_ASIA_3` | skrzynia w skarbcu płatnerza (sekret za łańcuchem) | LINED | karta płatnerza Kowalika | pod maską Generała coś oddycha | zbroje: z przodu zasłonięte, wolno się obracają, paralizator opuszcza gardę, cienkie od góry i od tyłu; skrzynie 1910 za spękaną ścianą u stóp schodów |
| `NOTE_ASIA_4` | skład wyprawy 1910 (sekret za spękaną ścianą, y −6) | LETTER | list Rudnickiego, 1910 | perła smoka spadła w głąb ziemi; lwy pilnują, żeby się „nie stoczyła w dół”; generał nie skończył warty | kula w pysku lwa (słaby punkt) |

### Ameryki i Oceania

| Klucz | Gdzie | Papier | Dokument | Fabuła | Podpowiedź |
|---|---|---|---|---|---|
| `NOTE_AMERICAS_1` | skrzynia przy harpunniku | LETTER | dziennik bosmana, 1851 | kaszalot z czerwonym światłem w brzuchu | harpun: mały cel przyszpila, większy przyciąga i ogłusza, wielki tylko rani; żelazne ucho ciągnie (szalupa, krata, czółno); zabranie harpunnika budzi wachtę |
| `NOTE_AMERICAS_2` | ławka w Sali Ameryki Północnej | TYPED | nocny scenariusz oprowadzania (Bielecka) | druga głowa węża „patrzy w podziemia… i w naszą stronę” | totemy: oczy się zapalają, zestrzeliwać od góry, im mniej twarzy, tym szybciej; jaguary jak wilki; czółno na hakach = jedyna droga do świątyni; Wąż: głowa pluje, druga kąsa po syku, ogon zamiata, celuj w głowy i miejsca bez mozaiki |
| `NOTE_AMERICAS_3` | kryjówka za moai (sekret, harpun) | LINED | Heniek | moai stoi twarzą do kraty i sam się odwraca | Wąż na koniec owija arenę — nie daj się zapędzić w róg; **szachy z Lewis:** za tronem Ramzesa, za obeliskiem, za Buddą, przy ołtarzu Węża |
| `NOTE_AMERICAS_4` | magazyn zabity deskami (sekret, y −6) | TYPED | zarządzenie dyrekcji 4/1931 z raportem stróża Pająka | totem znika w ścianie i śpiewa pod podłogą; świeca, która nie gaśnie | — |

### Podziemia i dach (W5b, gałąź `p1-w5-below`, przed tą biblią)
`NOTE_BASEMENT_1` (lista prac konserwatorki M. Lis), `NOTE_BASEMENT_2` (dziennik kotłowni, palacz Z. Węgiel), `NOTE_BASEMENT_3` (rozdzielnia — UWAGA, elektryk R. Gil; papier `FORM`), `NOTE_ROOF_1` (zeszyt dekarzy). Zgodne z biblią; Gil jest tą samą osobą co konserwator ze zleceń.

### Lobby (poziom testowy)
Notatki lobby (`NOTE_KEY`, `NOTE_1…3`, `NOTE_CHAMBER`, `NOTE_NICHE`, `NOTE_VENT`, `NOTE_CLOSET`) zostają kanonem tam, gdzie nie przeczą Piętru I. W grze leży z nich tylko karteczka Heńka.

---

## 6. Inne teksty

- **Ekran końca Piętra I:** `END_FLOOR1_EPILOGUE` (akapit nad „Ciąg dalszy nastąpi: Piętro −1”): kryształ pęka drugi raz, okruchy toczą się w dół, kamienni fundatorzy w krypcie mają głowy odwrócone ku schodom, na dole pali się światło, obok latarnia z 1912 roku — jeszcze ciepła. Pokazuje go `DemoEnd` (pole `epilogue`).
- **Podpowiedzi ekranu wczytywania:** `TIP_1…TIP_20` (PL/EN). **Ekranu wczytywania jeszcze nie ma** (projekt §9.2) — klucze czekają; wystarczy losować `"TIP_%d" % randi_range(1, 20)`.
- **Nazwy sal** (`ROOM_*`, karta sali pokazuje je wielkimi literami): poprawione na rejestr tabliczki muzealnej — „Stara portiernia”, „Ukryty gabinet kolekcjonera” (zamiast Sloane'a — postać historyczna), „Magazyn zabity deskami”, „Galeria nad jamą lwów”, „Skład wyprawy 1910”, EN „The cloakroom store”.

---

## 7. Wątki otwarte (dla Piętra −1 i dalej)

1. **Kto nadał paczkę?** Ręka Kopcia, stempel z 1912, paczka ciepła. Czy Kopeć żyje na dole, czy coś posługuje się jego ręką?
2. **Latarnia Kopcia** stoi na schodach pod kryptą, ciepła (epilog). Kto ją tam postawił i kiedy?
3. **Kustosz Wróblewski** — „bezterminowy urlop”, ostatnio nasłuchiwał przy kracie. Zszedł?
4. **Poziom „−1” na planach fundatorów**, winda, która jeździ sama, mokry ciepły piasek w kabinie.
5. **Stukanie pod kryptą** (1912, 1931, stetoskop Gila) — serce czego?
6. **Totem nr 3** zniknął w ścianie w 1931 i śpiewa pod podłogą — może czekać na dole.
7. **Czerwona planeta** krąży pod posadzką Planetarium; jej „słońce” jest głęboko.
8. **Staw, który płynie w dół; dzwon uderzany od spodu; perła smoka, która się stoczyła.**
9. **Tabliczka Mireckiego:** „sześć” to domysł; ktoś nocą „pisze dalej” — może dopisuje ciąg dalszy proroctwa.
10. **Fundatorzy** pochowani twarzą do schodów; w epilogu ich posągi patrzą w dół. Woskowy „założyciel” w piwnicy Montagu House (W5b).
11. **Palacz Z. Węgiel** („Ja nie.”) i **introligator T. Bury** — zniknęli czy tylko przestali pisać?
12. **Heniek wróci** (noga) — dobry kandydat na głos podpowiedzi na Piętrze −1. **Mazur** wciąż chce zegarek od Napoleona.
13. **Szachy z Lewis** uciekły z gabloty same — dlaczego i przed czym?

---

## 8. Fakty prawdziwe użyte w tekstach

| Fakt | Gdzie | Uwagi |
|---|---|---|
| Lamassu z pałacu Sargona II w Chorsabadzie, VIII w. p.n.e.; „pięć nóg” (z przodu stoi, z boku kroczy) | `NOTE_ASSYRIA_1` | fakt |
| Bibliotekę Assurbanipala utrwalił pożar Niniwy (wypalone tabliczki) | `NOTE_ASSYRIA_2` | uproszczenie popularne: część tabliczek była wypalona wcześniej |
| Apsu — wody pod ziemią w mitologii mezopotamskiej | `NOTE_ASSYRIA_2` | fakt; tekst tabliczki — fikcja |
| Reliefy polowania Assurbanipala: lwy wypuszczane z klatek | `NOTE_ASSYRIA_2`, `_4` | fakt |
| Kamień z Rosetty: trzy pisma | `NOTE_EGYPT_3` | fakt |
| Ważenie serca w egipskich wierzeniach o zaświatach | `NOTE_EGYPT_4` | fakt; papirus — fikcja |
| Hwacha: wyrzutnia strzał ognistych, Korea, dynastia Joseon, salwa dziesiątek strzał | `NOTE_ASIA_1` | fakt; sześć rur — gra |
| Chińskie lwy-strażnicy: luźna kula wyrzeźbiona w pysku; smok goniący płonącą perłę | `NOTE_ASIA_4` | fakt (w kamieniu); u nas brąz — licentia poetica |
| Moai w większości stoją plecami do morza | `NOTE_AMERICAS_3` | fakt |
| Szachy z Lewis: wieże-berserkowie gryzą tarcze | `NOTE_AMERICAS_3`, `TIP_20` | fakt |
| Dwugłowy wąż z mozaiki turkusowej (Meksyk) i jego interpretacje | `NOTE_AMERICAS_2` | interpretacja oznaczona jako „jedna z interpretacji” |
| Wielorybnictwo na Pacyfiku w XIX w., ambra | `NOTE_AMERICAS_1` | tło prawdziwe; statek i ludzie fikcyjni |

---

## 9. Jak dopisać notatkę (technicznie)

1. Znacznik `note_<strefa>_<n>` w module strefy (`layout.add_marker(&"note_…", pozycja, sala)`); powyżej 1,2 m nad podłogą notatka wisi na ścianie.
2. Trzy wiersze na **końcu** `locale/strings.csv`: `NOTE_<STREFA>_<N>_TITLE`, `_BODY`, `_SIGN` (kolumny `keys,pl,en`; wartości z przecinkiem lub nową linią w cudzysłowie).
3. Papier inny niż zeszyt: wpis w `NoteCatalog.PAPER`.
4. `bash tools/run_tests.sh --filter=texts` — test sprawdza, że każdy znacznik notatki Piętra I ma tytuł, tekst i podpis w obu językach; `--filter=localization` — kształt CSV, duplikaty, symbole zastępcze.
5. Bez tekstu `WorldFeatures` nie kładzie notatki i ostrzega: `no text for the note <znacznik> (NOTE_<ID>_TITLE)`.
