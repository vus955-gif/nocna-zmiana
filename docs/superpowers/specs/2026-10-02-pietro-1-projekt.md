# Piętro I — „Wielki Dziedziniec”: projekt pierwszego obszaru

> **Stan:** projekt zatwierdzony 2 października 2026 (decyzje właściciela w rozmowie, reszta: Claude).
> **Cel nadrzędny (słowa właściciela):** pierwszy obszar ma być grą, której nie wstydziłbyś się wystawić na Steam. Duży, złożony, dający frajdę, inspirowany British Museum, z sekcjami-biomami. Po włączeniu gracz ma być **autentycznie pozytywnie zaskoczony**. Pokaz umiejętności: Godot wyciśnięty do granic, Blender jako narzędzie. Pracujemy do skutku.
> **Czas gry:** cel 45–60 min na zwiedzenie każdego zakamarka; **dłużej jest w porządku**, jeśli zyskuje na tym rozgrywka. Realny cel: 60–80 min na 100%, 3–4 noce dla nowego gracza.
> **Gałąź:** `pietro-1` (od `etap-1a-piaskownica` @ `e5f7780`).
> Liczby to punkt startowy do strojenia.

---

## 0. Decyzje właściciela (2.10)

| Pytanie | Decyzja |
|---|---|
| Jak pogodzić 45–60 min z nocą 21 min? | **Kilka krótkich nocy.** Noc zostaje krótka (~21–24 min), obszar otwiera się etapami przez 3–4 noce jak w metroidvanii. Skróty, bronie, sekrety i pokonani strażnicy zostają na zawsze. |
| Co z obecnym holem? | **Hol jako serce:** przebudowany na wzór Great Court (szklany dach, okrągła Czytelnia w środku), skrzydła rozchodzą się z niego, T-Rex zostaje finałem. |
| Skrzydła | **Sześć:** Egipt, Asyria, Grecja, Oświecenie, Azja, Ameryki i Oceania. |
| Bronie | **+3 nowe** (razem 9 slotów: pięści + 8): ciężka, precyzyjna, dziwna. |
| Bossowie | **Strażnik w każdym skrzydle** (6 mini-bossów), każdy pilnuje klucza do dalszej części; **T-Rex = wielki finał**. |
| Orientacja | **Papierowy plan muzeum** (M): zaznacza odwiedzone sale, przystanie, znaleziska; sekretów nie pokazuje, ale ma luki sugerujące ukryte pomieszczenia. |
| Kolejność budowy | Szkic całego piętra → jedno wzorcowe skrzydło → pozostałe równolegle. **Bez pokazywania po drodze** — właściciel gra dopiero w całość. |
| Tryb pracy | Długie autonomiczne sesje; gdy właściciel śpi, wolno używać okien (Godot, Blender, computer use). Dźwięk domyślnie wyciszony. |

---

## 1. Diagnoza z pierwszego testu właściciela i poprawki

| Zgłoszenie | Przyczyna w kodzie | Poprawka w tym projekcie |
|---|---|---|
| **„Nigdzie nie znalazłem strzelby”** | strzelba była sekretem: nisza za krzywą tabliczką (8,6°, mosiężna 0,5 × 0,3 m) w ciemnej zbrojowni; jedyna podpowiedź leżała w samej niszy | strzelba leży **na głównej trasie** w Egipcie, w oświetlonym obozie ekspedycji, widoczna z daleka ([5.1](#51-egipt--galeria-rzeźby-egipskiej)). Zasada: **broń podstawowa nigdy nie jest sekretem**. Sekret może dawać rzeczy dodatkowe |
| **„Nie szło kartaczownicy odblokować”** | łańcuch zrywał tylko strzał ze strzelby (≥25 obr. naraz) albo 3 ciosy pięścią; napis „Zamknięte na łańcuch”, E tylko szarpie | **jeden spójny język łańcuchów** w całej grze: napis „Łańcuch — rozbij czymś ciężkim (strzelba, pięści)”, przy pierwszym łańcuchu podpowiedź; łańcuch przyjmuje sumę obrażeń z 0,4 s (śrut z dystansu też działa); cios pięścią w łańcuch zawsze trafia łańcuch, nie stojącego obok wroga |
| **„Horda tuż po wyjściu z kanciapy”** | wzrok 360° na 25 m bez względu na ciemność; łańcuchowe budzenie w 8 m; obudzony eksponat zawsze zna pozycję strażnika i nigdy nie odpuszcza; po wyjściu z przystani wszyscy obudzeni ruszają naraz; w pierwszej sali 4–5 wilków | **nowa percepcja i terytoria** ([7.2](#72-nowe-zachowanie-eksponatów-percepcja-i-terytoria)): stożek widzenia, ciemność i latarka, słuch, gubienie śladu, przeszukiwanie, powrót na posterunek, smycz terytorium, limit polujących; pierwsza godzina gry ma łagodny rozkład spotkań |
| (dodatkowo) „zbrojownia za ciemna” z raportu | — | każda sala dostaje światło z przepisu skrzydła, ze sprawdzeniem jasności na zrzutach |

---

## 2. Wizja obszaru

**W jednym zdaniu:** Piętro I to wielkie, nocne muzeum zbudowane wokół szklanego dziedzińca, z sześcioma skrzydłami-światami, które otwierasz noc po nocy, pokonując strażników i odkrywając skróty, aż wszystkie odłamki kryształu obudzą T-Reksa pod szklanym dachem.

**Co ma zaskoczyć przy pierwszym uruchomieniu:**
1. **Menu główne na żywo:** kamera powoli sunie nad Wielkim Dziedzińcem w świetle księżyca, cienie szklanego dachu w mgle, T-Rex w półmroku.
2. **Pierwsze wejście do Egiptu:** 66 m galerii kolosalnych posągów w snopach księżyca, a na końcu siedzący Kolos, który… patrzy.
3. **Każde skrzydło to inny świat:** inna paleta, inne światło, inna muzyka, inni wrogowie, inny strażnik z własnym pomysłem na walkę.
4. **Muzeum się otwiera:** skrót odblokowany od środka wychodzi nagle w sali z pierwszej nocy. Plan muzeum zapełnia się ołówkowymi dopiskami strażnika.
5. **Finał pod szklanym dachem:** T-Rex szarżuje wokół bębna Czytelni, a każdy filar, gablota i balkon mają znaczenie.

**Nie zmienia się:** ton (mroczny z przymrużeniem oka), materiałowe gore, ruch „strażnik, nie komandos”, łagodny roguelite z Pyłem jak w Dark Souls, czytelne zapowiedzi ataków, brak bullet hella, „styl retro, nie jakość retro”.

---

## 3. Struktura: noce i metroidvania

### 3.1 Noc
- Noc trwa **23:00–6:00**, godzina gry = **3 min 20 s** (noc ok. **23 min**). Godzina duchów o 3:00 i świt jak dotąd.
- Noc zaczyna się w **ostatnio odwiedzonej przystani** (pierwsza noc: kanciapa).
- Śmierć: niesiony Pył zostaje w latarce na miejscu śmierci; następna noc. Świt: noc kończy się bez śmierci, Pył zostaje.

### 3.2 Co zostaje na zawsze (postęp metroidvanii)
**Trwałe (zapis):** znalezione bronie; pokonani **strażnicy** (nie wracają); zdobyte **pieczęcie** i **odłamki kryształu**; **otwarte bramy i skróty**; odkryte sekrety, notatki, przystanie; **odwiedzone sale** (plan); kupione ulepszenia; klucz do szafki.

**Co noc od nowa:** zwykłe eksponaty (nowe losowanie spotkań), łup, artefakty, modyfikator nocy, portrety, zamknięte drzwi nocy (od nocy 2, nigdy na jedynej drodze).

**Ulga po strażniku:** skrzydło, którego strażnik padł, ma od następnej nocy **ok. 55% eksponatów** („magia skrzydła osłabła”). Powroty przez znane skrzydła są szybsze, a postęp jest odczuwalny.

### 3.3 Cel na HUD
Cel nie jest już jednym łańcuchem kroków nocy. HUD pokazuje **najbliższy sensowny cel** wyliczany ze stanu postępu (np. „Zdobądź broń: szafka w kanciapie”, „Strażnik Egiptu czeka w Sali Kolosa”, „Brama Chorsabadu: potrzebna Pieczęć Słońca”, „Odłamki: 3/6”). Plan muzeum (M) pokazuje cel ołówkiem.

### 3.4 Pętla obszaru (pierwsze przejście)
| Noc | Typowy przebieg nowego gracza |
|---|---|
| 1 | kanciapa → hol wejściowy (klucz w kasie, rakietnica w szafce pożarowej) → pistolet → Wielki Dziedziniec → Egipt (strzelba w obozie ekspedycji) → Kolos Ramzesa albo zwiad Oświecenia |
| 2 | Oświecenie (sztucer, Planetarium) i/lub Asyria (za Bramą Chorsabadu); pierwsze skróty przez podziemia |
| 3 | Grecja; Brama Północna → Azja (ognista skrzynia) |
| 4 | Ameryki i Oceania (harpunnik); ostatni strażnicy; odłamki 6/6 → finał z T-Reksem → zejście do podziemi (koniec Piętra I) |

Kolejność jest częściowo dowolna: po nocy 1 gracz wybiera między Asyrią, Grecją i Oświeceniem.

---

## 4. Mapa Piętra I

### 4.1 Plan sytuacyjny (strefy)

Metry, oś Y w górę, **−Z = północ**, początek układu w środku Wielkiego Dziedzińca. Podłoga parteru y = 0, podziemia y = −6, dach y ≈ 22.

```
 x: -112            -50  -46            -4  4             46  48        66
z:-86 ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
      │ ASYRIA        │  │ AMERYKI       │  │ AZJA          │
      │ brama, pałac, │  │ I OCEANIA     │  │ sala Chin,    │
      │ lwy, dziedz.  │  │ Meksyk, moai, │  │ Korea, ogród  │
      │ pałacu        │  │ Pacyfik       │  │ japoński      │
  -38 │               │  └──────┬────────┘══╧═══════┬───────┘   ┌──────────┐
      │               │ ═══════ korytarz północny ════════════════│PLANETAR. │ -36
  -30 │      ┌────────┤  ┌──────┴───── krata ↓ ─────┴──────────┐ │(Oświec.) │
      │      │ EGIPT  │  │ WIELKI DZIEDZINIEC 60×60, dach szkł.│ ├──────────┤
      │      │ galeria├──┤      ┌──────────────┐               ├─┤OŚWIECE-  │
   -4 └──────┤ 16×66  │  │      │  CZYTELNIA   │  T-Rex (N)    │ │NIE       │
   -2 ┌──────┤        │  │      │  bęben r12,5 │               │ │Bibl. Kr. │
      │GRECJA│ grobow-│  │      └──────────────┘               │ │14×70 +   │
      │Partenon,ce, obóz│ │  balkon y=7 wokół bębna (N)        │ │gabinety  │
      │Nereidy│ ekspedy│  └──────────────┬──────────────────────┘ │          │
   30 │wazy  │ cji    │        ┌─────────┴─────────┐              └──────────┘ 34
   48 └──────┴────────┘        │ HOL WEJŚCIOWY     ├─┬─ korytarz ─┐
                               │ 32×22, kasa,      │ │ KANCIAPA    │
                               │ schody, wyjście   │ └─(start)─────┘
                            52 └───────────────────┘
        PODZIEMIA (y = −6): pierścień korytarzy pod obwodem dziedzińca + odnogi do każdego skrzydła,
        warsztat renowacji (przystań), kotłownia, rozdzielnia, magazyny, winda towarowa, krypta pod kratą.
        DACH (y ≈ 22): kładki serwisowe nad szklanym dachem (trasa sekretna i skrót).
```

**Granice stref** (x0, z0 → x1, z1; strefy nie nachodzą na siebie, między nimi ściany 0,5–2 m):

| Strefa | Prostokąt | Uwagi |
|---|---|---|
| Wielki Dziedziniec (`court`) | −30, −30 → 30, 30 | sufit/dach 22 m; bęben Czytelni w środku; balkon y = 7 |
| Hol wejściowy (`entrance`) | −16, 30 → 16, 52 | sufit 12 m |
| Kanciapa i korytarz służbowy (`booth`) | 16, 36 → 38, 48 | przystań startowa |
| Egipt (`egypt`) | −62, −36 → −32, 30 | galeria x −48…−32; sale boczne x −62…−48 tylko dla z 0…30 |
| Asyria (`assyria`) | −112, −86 → −50, −4 | wejście: Brama Chorsabadu przy północnym końcu Egiptu |
| Grecja (`greece`) | −112, −2 → −62, 48 | połączenie z Egiptem przez sale boczne (z ≈ 20) |
| Oświecenie (`enlightenment`) | 32, −36 → 66, 34 | galeria x 34…48; gabinety x 48…66; Planetarium na północy |
| Ameryki i Oceania (`americas`) | −46, −86 → −4, −38 | |
| Azja (`asia`) | 4, −86 → 46, −38 | skrót do Planetarium w rogu SE |
| Korytarz północny (`north_hall`) | −46, −38 → 46, −30 | łączy dziedziniec z Amerykami i Azją; krata do zejścia w środku (x −4…4) |
| Podziemia (`basement`) | pod obwodem, y = −6 | sieć skrótów; krypta i schody w dół za kratą |
| Dach (`roof`) | nad dziedzińcem, y ≈ 22 | kładki; opcjonalna trasa |

Zasięg całości ok. **178 × 138 m** (dla porównania lobby: 88 × 100 m, a sama kubatura sal jest ok. 5× większa).

### 4.2 Bramy (blokady) i klucze

Metroidvania potrzebuje różnych zamków. Każdy ma **jeden czytelny język**: wygląd, dźwięk i napis przy celowniku.

| Rodzaj | Wygląd | Otwiera | Napis |
|---|---|---|---|
| **Łańcuch** | gruby łańcuch z kłódką na drzwiach lub gablocie | strzelba (suma ≥25 obr. w 0,4 s) albo 3 ciosy pięścią | „Łańcuch — rozbij czymś ciężkim” |
| **Deski** | zabite deskami przejście „REMONT” | strzelba, pięści (5 ciosów), wybuch | „Zabite deskami” |
| **Pieczęć** | kamienne / brązowe wrota z wgłębieniem w kształcie symbolu | pieczęć od strażnika (trwała) | „Brama zapieczętowana — potrzebna: Pieczęć Słońca” |
| **Zasilanie** | stalowa żaluzja przeciwpożarowa, czerwona lampka | rozdzielnia w podziemiach (przełącznik po wymianie bezpieczników) | „Brak zasilania” |
| **Spękany mur** | rysy, gruz, prześwit | wybuch (ognista skrzynia, raca z bliska ×3) | „Spękany mur” |
| **Lina / przeciwwaga** | lina w oddali, dzwon, zamek po drugiej stronie przepaści | precyzyjny strzał (sztucer; pistolet z bliska) | „Lina — za daleko, żeby sięgnąć” |
| **Hak** | żelazne ucho / pierścień na obiekcie | harpunnik (przyciąga) | „Żelazne ucho” |
| **Drzwi od środka** | drzwi służbowe z zasuwą | zasuwa od drugiej strony (skrót) | „Zaryglowane z drugiej strony” |

**Zasada bez blokady:** nigdy nie da się utknąć. Każdy zamek na drodze krytycznej ma klucz osiągalny wcześniej; test osiągalności sprawdza to dla każdego stanu postępu ([11](#11-testowanie-i-weryfikacja)).

### 4.3 Graf postępu (droga krytyczna)

```
START kanciapa ─► hol wejściowy ─► (klucz z kasy) ─► pistolet
      │                    └─► szafka pożarowa: RAKIETNICA
      ▼
Wielki Dziedziniec ──W──► EGIPT: STRZELBA (obóz ekspedycji, droga główna)
      │                      └─► Kolos Ramzesa ─► PIECZĘĆ SŁOŃCA + odłamek 1
      │                                   └─► Brama Chorsabadu ─► ASYRIA
      │                                                └─► Lamassu ─► PIECZĘĆ SKRZYDŁA + odłamek 2
      │                                                                └─► przejście Asyria→Ameryki (wrota pieczęci)
      │   EGIPT (grobowiec, deski: strzelba) ──► GRECJA ─► Kentaur ─► PIECZĘĆ SOWY + odłamek 3
      │                                        └─► skrót Grecja→hol wejściowy, KARTACZOWNICA (Czytelnia, łańcuch)
      ├──E──► OŚWIECENIE: SZTUCER ─► Planetarium ─► KLUCZ GWIAZD + odłamek 4
      │                                                   └─► BRAMA PÓŁNOCNA (dziedziniec → korytarz północny)
      ▼
korytarz północny ─E─► AZJA (żaluzja: zasilanie z rozdzielni w podziemiach) ─► OGNISTA SKRZYNIA
      │                         └─► spękany mur ─► ogród japoński ─► Generał ─► odłamek 5
      └─W─► AMERYKI I OCEANIA (wrota Pieczęci Skrzydła od strony Asyrii albo od korytarza po zasilaniu)
                ─► HARPUNNIK ─► most z czółna (hak) ─► Świątynia Węża ─► Dwugłowy Wąż ─► odłamek 6
ODŁAMKI 6/6 ─► Czytelnia: astrolabium ─► kryształ ─► T-REX (dziedziniec) ─► krata ─► zejście (koniec Piętra I)
```

Szczegóły rozmieszczenia może stroić budowniczy szkicu, ale **kolejność zależności** i rodzaje zamków są wiążące.

### 4.4 Skróty (trwałe, otwierane od środka)
1. Podziemia ↔ każde skrzydło (drzwi służbowe z zasuwą od strony skrzydła): 6 skrótów.
2. Grecja → hol wejściowy (podest zachodnich schodów).
3. Asyria → Ameryki (wrota z Pieczęcią Skrzydła).
4. Azja → Planetarium (Oświecenie).
5. Asyria (Sala Lwów) → Grecja (Sala z Bassae): drzwi ryglowane od strony Asyrii, pętla zachodnia.
6. Dach: kładki od podestu holu wejściowego do górnej galerii Oświecenia i włazu nad Egiptem (sekret + skrót).

### 4.5 Przystanie (6)
| Przystań | Strefa | Jak odkryć |
|---|---|---|
| Kanciapa ochrony | booth | start |
| Pokój konserwatora | egypt (sale boczne) | na drodze, noc 1 |
| Gabinet bibliotekarza | enlightenment | na drodze |
| Warsztat renowacji | basement (środek) | pierwsze zejście do podziemi |
| Herbaciarnia | asia (ogród) | po Generale; tu przystań jest w samej herbaciarni |
| Magazyn odlewów | greece | sekret / na drodze do Kentaura |
Każda ma terminal ulepszeń, leczy i zapisuje (zasady jak dotąd: 30 s, zegar stoi do 60 s na wizytę).

### 4.6 Liczby obszaru
- **Pomieszczeń:** ok. 45–55 (z kryjówkami i podziemiami).
- **Sekretów:** 3 na skrzydło + 4 w dziedzińcu, holu, podziemiach i na dachu ≈ **22**.
- **Notatek:** 3–4 na skrzydło + wspólne ≈ **24**.
- **Szachy z Lewis:** 8 ukrytych figur w całym piętrze (kolekcja dla dokładnych; komplet = artefakt na stałe „Hetman z Lewis”).
- **Eksponatów na noc:** ok. 90–120 w całym piętrze, rozłożonych w terytoriach (gęstość jak w lobby albo mniejsza).

---

## 5. Skrzydła

Każde skrzydło ma: **tożsamość wizualną** (paleta, materiały, światło), **3–6 pomieszczeń**, **wroga sygnaturowego**, **strażnika**, **nagrodę** (broń lub narzędzie), **przystań lub skrót**, **3 sekrety**, **3–4 notatki**, **ambient i wariant muzyki**.

### 5.1 Egipt — Galeria Rzeźby Egipskiej
- **Wygląd:** piaskowiec i granit, złoto, turkusowe akcenty, hieroglify (tekstury z pikselowych glifów). Światło: zimny księżyc przez wysokie okna i ciepłe reflektory na kolosach; drobny pył w snopach. Mgła piaskowa.
- **Sale:**
  1. **Przedsionek Rosetty** (wejście z dziedzińca): Kamień z Rosetty w gablocie, pierwszy widok na galerię.
  2. **Wielka Galeria** (16 × 66 m, h 11): szpaler kolosalnych posągów, sarkofagi, obeliski, kolumny papirusowe; w połowie **obóz ekspedycji 1898** (namiot, skrzynie, lampy naftowe): **STRZELBA**, oświetlona i widoczna od wejścia.
  3. **Grobowiec** (sale boczne, ciemne, niski strop): sarkofagi, z których wychodzą mumie; przejście do Grecji (pętla zachodnia).
  4. **Pokój konserwatora** (przystań).
  5. **Sala Kolosa** (północny koniec, 24 × 24, h 14): arena strażnika; za nim Brama Chorsabadu.
- **Wróg sygnaturowy — Mumia:** 110 HP, 1,9 m/s; **bicz z bandaży** (zapowiedź 0,6 s: bandaże się rozwijają) przyciąga strażnika 3 m i spowalnia na 1 s; zwykły cios 16. Ogień ×2 (bandaże płoną, mumia biegnie w panice 2 s). Rozpad: bandaże, kurz, kości. Pył 6.
- **Dodatkowo:** **roje skarabeuszy** (z pęknięć i sarkofagów): chmura 30–40 robaczków jako jeden wróg, 40 HP, 6 obr./s w kontakcie; śrut i ogień ×2; Pył 2.
- **Strażnik — Kolos Ramzesa** ([7.4](#74-strażnicy)).
- **Starzy wrogowie tutaj:** figury woskowe („Archeolodzy — wystawa czasowa”).
- **Nagroda:** strzelba (droga główna). **Pieczęć Słońca** (otwiera Bramę Chorsabadu) + odłamek 1.

### 5.2 Asyria — Pałace Niniwy i Nimrud
- **Wygląd:** szaroniebieski gips alabastrowy, płaskorzeźby na całych ścianach (tekstury reliefów z normal mapą z Blendera), brązowe okucia, ciemne cedrowe belki. Światło: chłodne, ostre, nisko padające; czerwonawe pochodnie (lampy w kształcie pochodni).
- **Sale:** Brama Chorsabadu (para lamassu 4,5 m po bokach), Galeria Pałacu Nimrud (długa, reliefy), **Sala Lwów z Niniwy** (polowanie na lwy: reliefy z lwami, które ożywają), Wrota z Balawat (brązowe pasy), **Dziedziniec Pałacu** (arena, otwarty strop z księżycem), magazyn tabliczek klinowych (sekret).
- **Wróg sygnaturowy — Wojownik z reliefu:** płaska postać, która **odkleja się od ściany** (zapowiedź: relief pęka i świeci). 50 HP, szybki krok w bok, rzut włócznią łukiem (14), cios 12. **Z boku jest prawie płaski** (trafienia w krawędź ×0,5), od frontu słaby punkt: oko. Potrafi wejść z powrotem w ścianę i wyjść 6 m dalej (raz na 8 s). Pył 5.
- **Dodatkowo:** lwy z reliefu (płaskie, zachowanie wilka: doskok).
- **Strażnik — Lamassu.**
- **Nagroda:** **Pieczęć Skrzydła** (wrota Asyria → Ameryki) + odłamek 2; skrót do podziemi.

### 5.3 Grecja — Partenon i Pomnik Nereid
- **Wygląd:** biały i kremowy marmur, ślady pierwotnych barw (błękit, ochra), fryzy. Światło: **najjaśniejsze skrzydło**, srebrny księżyc przez świetliki galerii Partenonu, czyste powietrze, mało mgły. Kontrast dla ciemnego Egiptu.
- **Sale:** Sala Waz (czarno- i czerwonofigurowe), **Pomnik Nereid** (fasada świątyni 1:1 w sali, posągi nereid między kolumnami), **Galeria Partenonu** (40 × 18 m, h 12, fryz dookoła, frontony na końcach: arena Kentaura), Sala Metop (Lapici i centaury), **Sala z Bassae** (antresola po schodach: sekret z liną), Magazyn odlewów (przystań).
- **Wróg sygnaturowy — Hoplita:** marmurowy z tarczą i włócznią (na bazie rycerza): tarcza ±60°, **pchnięcie włócznią z 3 m** (zapowiedź 0,7 s), **falanga**: dwóch-trzech hoplitów obok siebie zachodzi tarczami. Paralizator opuszcza tarczę. 140 HP. Pył 7.
- **Starzy wrogowie tutaj:** lewitujące popiersia.
- **Strażnik — Kentaur z metopy.**
- **Nagroda:** **Pieczęć Sowy** (otwiera ekspozycję w Czytelni → kartaczownica) + odłamek 3; skrót do holu wejściowego.

### 5.4 Oświecenie — Biblioteka Królewska i gabinety osobliwości
- **Wygląd:** ciemny dąb i mahoń, mosiądz, zielone abażury, tysiące grzbietów książek (tekstury atlasów grzbietów), globusy, gabloty z muszlami i skamieniałościami. Światło: ciepłe, punktowe, długie cienie regałów; **górna galeria regałów** na y = 4 (kładka z balustradą).
- **Sale:** **Biblioteka Królewska** (14 × 70 m, h 10, dwa poziomy regałów, gabloty w osi), **Gabinet Historii Naturalnej** (wypchane wilki, skamieniałe raptory, szkielety): **SZTUCER** kolekcjonera, **Galeria Portretów Kolekcjonerów** (portrety), **Sala Zegarów i Automatów** (tykanie, wahadła), Gabinet bibliotekarza (przystań), **Rotunda Planetarium** (arena).
- **Wróg sygnaturowy — Latające księgi:** stadka 4–6; trzepoczą, nurkują (zapowiedź: szelest + rozłożenie okładek), 18 HP każda, ogień ×2, papierowe gore (kartki fruwają). Pył 2 za księgę.
- **Starzy wrogowie tutaj:** wypchane wilki, raptory (z gabloty skamieniałości), portrety.
- **Strażnik — Wielkie Planetarium.**
- **Nagroda:** sztucer; **Klucz Gwiazd** (Brama Północna) + odłamek 4.

### 5.5 Azja — Chiny, Korea, Japonia
- **Wygląd:** czerwony lak, brąz z zieloną patyną, porcelana, papierowe lampiony, złote Buddy. **Ogród japoński** pod otwartym dachem: żwir grabiony, kamienie, kwitnąca wiśnia (płatki jako cząsteczki), herbaciarnia. Światło: ciepłe lampiony + chłodny księżyc w ogrodzie.
- **Sale:** Sala Chin i Azji Południowej (wielki Budda, brązy), **Sala Koreańska**: **OGNISTA SKRZYNIA** (hwacha), Galeria Porcelany (kruche gabloty), Sala Zbroi (zbroje samurajów na stojakach), **Ogród Japoński** (arena, za spękanym murem), Herbaciarnia (przystań).
- **Zasilanie:** żaluzja z korytarza północnego potrzebuje prądu z **rozdzielni w podziemiach** (dwa bezpieczniki z podziemi i Asyrii: dawny mechanizm bezpieczników wraca jako lokalna zagadka).
- **Wróg sygnaturowy — Pies Fu z brązu:** ciężki szarżujący (160 HP, 6 m/s w szarży), **ryk** ogłusza strażnika na 0,5 s z 6 m (zapowiedź: kula w pysku świeci), metalowe iskry; słaby punkt: kula w pysku. Parami (lew i lwica). Pył 8.
- **Starzy wrogowie tutaj:** rycerze → **zbroje samurajów** (ten sam mechanizm tarczy, nowy wygląd: „ashigaru”).
- **Strażnik — Generał samurajów.**
- **Nagroda:** ognista skrzynia + odłamek 5.

### 5.6 Ameryki i Oceania — Meksyk, Rapa Nui, Pacyfik
- **Wygląd:** ciemnoczerwone ściany, turkusowe mozaiki, obsydian, rzeźbione drewno, maski. **Sala Moai**: jedna kamienna głowa w ciemności, oświetlona z dołu. **Galeria Pacyfiku**: wielkie czółno wojenne pod sufitem, wiosła, tapa. Światło: najbardziej teatralne, mocne kontrasty, ogień.
- **Sale:** Galeria Meksyku (schodkowe podesty: **Świątynia Węża**, arena), Sala Moai (sekret: moai obraca się na cokole po trafieniu harpunem w żelazne ucho z tyłu cokołu; za nim schody do kryjówki), **Galeria Pacyfiku** (harpunnik w ekspozycji wielorybniczej: **HARPUNNIK**; czółno na hakach = most nad zapadniętą podłogą), Sala Totemów, Sala Ameryki Północnej.
- **Wróg sygnaturowy — Totem:** nieruchomy słup 3–5 twarzy; każda twarz to wieżyczka (pluje odłamkiem, zapowiedź: oczy się zapalają), zestrzeliwuje się je od góry; im mniej twarzy, tym szybciej strzela. 30 HP na twarz. Pył 3 za twarz.
- **Dodatkowo:** wojownicy-jaguary (zachowanie wilka, wygląd: drewno i turkus).
- **Strażnik — Dwugłowy Wąż.**
- **Nagroda:** harpunnik + odłamek 6.

### 5.7 Wielki Dziedziniec, Czytelnia i hol wejściowy
- **Wielki Dziedziniec** (60 × 60 m): posadzka z jasnego wapienia, **szklany dach z trójkątnej kratownicy** (cienie siatki w mgle = znak rozpoznawczy gry), totem Haida w rogu NE, ławki, sklep muzealny (zamknięty, krata), kawiarnia, punkt informacji. **T-Rex** na postumencie po północnej stronie bębna. **Balkon** (y = 7) wokół północnej połowy bębna, dwa biegi schodów (≤ 20,6°).
- **Czytelnia** (bęben, 16-kąt, promień 12,5 m, wnętrze z kopułą do y ≈ 20): kopuła z kasetonami i oknem w szczycie, promieniste biurka, regały do sufitu, wystawa czasowa **„Wiek pary i stali”**: rycerze, figury woskowe, **kartaczownica** w gablocie z łańcuchem (otwarta po Pieczęci Sowy), w środku **astrolabium** na odłamki (finał).
- **Hol wejściowy** (32 × 22 m, h 12): kasa biletowa (klucz do szafki z pistoletem), szatnia, **szafka pożarowa z rakietnicą**, wielkie schody na podest (y = 6; skrót z Grecji, właz na dach), zamknięte główne drzwi („Wyjście otwarte od 6:00”).
- **Kanciapa** jak dziś (CCTV, szafka na broń, terminal), plus **plan muzeum** na ścianie.

### 5.8 Podziemia
Korytarze służbowe (beton, rury, świetlówki, kratki), pierścień pod obwodem dziedzińca, odnogi do skrzydeł. **Warsztat renowacji** (przystań: stoły z na wpół sklejonymi eksponatami), **kotłownia** (kocioł, para), **rozdzielnia** (bezpieczniki do żaluzji Azji), **magazyny** (skrzynie, regały, sekrety), **winda towarowa** (Asyria ↔ podziemia), **krypta** pod kratą i schody w dół (koniec Piętra I). Wrogowie: mieszanka ze wszystkich skrzydeł („uciekinierzy z magazynu”), mało, w ciasnych korytarzach.

---

## 6. Finał Piętra I
1. Odłamki 6/6 → astrolabium w Czytelni → kryształ się scala i pulsuje.
2. Kryształ wylatuje przez drzwi Czytelni i wbija się w T-Reksa (sekwencja jak dziś).
3. **Walka w dziedzińcu:** drzwi dziedzińca zatrzaskują się, mechanika bossa jak dziś (3 fazy), ale arena jest 60 × 60 m z bębnem w środku: **bęben Czytelni to ściana do ogłuszenia** (szarża w bęben = ogłuszenie), filary kratownicy i totem też. Ryk woła eksponaty z różnych skrzydeł (raptory, mumie, hoplici). Gruz w fazie 3 to **odłamki szklanego dachu** (cienie na posadzce, brzęk).
4. Zwycięstwo → krata w korytarzu północnym → krypta → schody w ciemność → **ekran końca Piętra I** (statystyki, % ukończenia, sekrety, szachy, czas, „Ciąg dalszy nastąpi: Piętro –1”).
5. Po zwycięstwie gra zostaje otwarta: można wrócić i zbierać sekrety (noce epilogu bez bossa).

---

## 7. Walka

### 7.1 Bronie (9 slotów)
| Klawisz | Broń | Gdzie | Rola / narzędzie |
|---|---|---|---|
| V / PPM | pięści | start | dobijanie; łańcuchy i deski |
| 1 | paralizator | start | ogłuszenie |
| 2 | pistolet | kanciapa (klucz w kasie holu wejściowego) | podstawowa |
| 3 | **strzelba** | **Egipt, obóz ekspedycji (droga główna)** | z bliska; łańcuchy, deski |
| 4 | kartaczownica | Czytelnia, gablota z łańcuchem (po Pieczęci Sowy) | tłum |
| 5 | rakietnica | hol wejściowy, szafka pożarowa | światło, ogień; pajęczyny i woskowe pieczęcie (sekrety) |
| 6 | **sztucer** (nowy) | Oświecenie, Gabinet Historii Naturalnej | precyzja; liny, zamki w oddali |
| 7 | **harpunnik** (nowy) | Ameryki i Oceania, Galeria Pacyfiku | przyszpila i przyciąga; haki |
| 8 | **ognista skrzynia** (nowa) | Azja, Sala Koreańska | salwa rakiet; spękane mury |

**Sztucer ekspedycyjny** (`rifle_hunt`): 85 obr., **przebija do 3 celów**, słaby punkt ×3, cykl zamka 1,0 s, magazynek 5, zapas 25 (maks. 40), amunicja „naboje sztucerowe”. Kopnięcie kamery i błysk. Bez celownika optycznego (precyzja zwykłym celownikiem; rozrzut 0).

**Harpunnik** (`harpoon`): harpun na linie (40 m/s, lekki opad). Trafienie: 60 obr.; **lekki wróg** (≤ 60 HP: wilk, księga, raptor, figura) zostaje **przyszpilony** do ściany za nim, jeśli jest w 6 m (ginie); **średni** zostaje **przyciągnięty** 3 m i ogłuszony na 1 s; ciężki i strażnik: tylko obrażenia. Trafienie w **żelazne ucho** ciągnie obiekt (most z czółna, kraty, zbroje strącone ze stojaków). Przeładowanie 1,2 s, 1 w lufie, zapas 12 (maks. 20).

**Ognista skrzynia** (`hwacha`): salwa **6 małych rakiet ognistych** w wachlarzu 12° (0,08 s odstępu), każda 22 obr. + wybuch 1,8 m (14) + ogień; **spękany mur** pęka od salwy. Ładowanie skrzyni 2,2 s, „magazynek” = 1 salwa, zapas 6 salw (maks. 10). Własny wybuch: zasada rakietnicy.

Ulepszenia nowych broni ([8.1](#81-ulepszenia-24)).

### 7.1a Ulepszenia widać na broni (pomysł właściciela, 2.10)
**Każdy poziom każdego ulepszenia broni zmienia trochę jej wygląd w pierwszej osobie**, a po maksymalnym poziomie broń wizualnie czuje się „lepsza”.
- Model broni w pierwszej osobie ma **nazwane części ulepszeń** (osobne węzły z Blendera), włączane według poziomów z `GameState`; zmiana widoczna od razu po zakupie (krótki błysk i dźwięk przy terminalu, a przy następnym wyjęciu broni animacja „oględzin”).
- **Pełne ulepszenie broni** (wszystkie jej ulepszenia na maks.) = **wykończenie mistrzowskie**: polerowany metal i mosiądz, grawer, ciepły połysk, subtelna poświata elementu charakterystycznego.
- Przykłady: pięści → owijki, potem mosiężne kastety; paralizator → dodatkowa cewka ze świecącym kondensatorem, druga para elektrod; pistolet → wydłużony magazynek, grawerowany zamek; strzelba → dławik na lufach, mosiężny ładownik slugów na kolbie; kartaczownica → wypolerowana korba z mosiężną gałką, bęben na dłuższą taśmę; rakietnica → miedziana osłona z magnezją, druga lufa; sztucer → lżejszy zamek z kulką, grawerowane okucia; harpunnik → kołowrotek, zadziory na grocie; ognista skrzynia → szybki lont (mosiężne zapalniki), większa skrzynia na 9 rakiet.
- Dotyczy też kolejnych ulepszeń w przyszłości: każde nowe ulepszenie broni musi mieć część wizualną.

### 7.2 Nowe zachowanie eksponatów: percepcja i terytoria
**Stany:** `DORMANT` (śpi jako eksponat) → `SUSPICIOUS` (podejrzliwy: odwraca głowę, oczy się żarzą, dźwięk; 0,6–1,0 s) → `INVESTIGATE` (idzie sprawdzić ostatni znany punkt) → `HUNT` (widzi strażnika) → `SEARCH` (zgubił: idzie do ostatnio widzianego miejsca, rozgląda się 6–10 s) → `RETURN` (wraca na posterunek albo trasę patrolu, potem `DORMANT` / `PATROL`). Plus `PATROL` (część eksponatów chodzi po trasie w swojej sali).

**Wzrok:**
- **Stożek 120°** przed sobą (portrety, popiersia, totemy: 160°), plus **wyczucie bliskie 3,5 m dookoła**.
- **Zasięg zależy od światła strażnika:** oświetlony (lampy sali, raca obok) 22 m; w półmroku 12 m; w ciemności 7 m. **Latarka włączona = zawsze widoczny jak oświetlony** (światło jest ryzykiem: kompromis eksploracja ↔ ukrycie). Jasność liczona z prostego modelu: świecące lampy w zasięgu (LightSpec + stan zasilania), race, latarka.
- Linia wzroku jak dziś (promień do geometrii), sprawdzana co 0,2 s, rozłożona w czasie między eksponatami.

**Słuch (zdarzenia hałasu na szynie `Events`):**
| Hałas | Zasięg |
|---|---|
| pięść, paralizator | 6 m |
| pistolet / sztucer | 18 / 24 m |
| strzelba, harpunnik | 22 / 12 m |
| kartaczownica, ognista skrzynia, wybuch | 30 m |
| sprint / lądowanie | 7 m |
| tłuczone szkło, szafka pożarowa | 16 m |
- Hałas słyszą tylko eksponaty **w tej samej sali** albo w salach połączonych **otwartymi** przejściami (graf sal), z tłumieniem ×0,6 na każde przejście. Zamknięte drzwi blokują.
- Usłyszany hałas daje `SUSPICIOUS → INVESTIGATE` (idą sprawdzić), **nie** pełne polowanie.

**Gubienie śladu:** w `HUNT` eksponat zna pozycję strażnika tylko gdy go widzi (albo ≤ 1,5 s po utracie z krótką ekstrapolacją). Potem `SEARCH` z ostatnio widzianego punktu.

**Terytorium i smycz:** każdy eksponat ma **dom** (pomieszczenie spawnu) i **terytorium** = dom + sale sąsiednie. Wyjście poza terytorium o więcej niż **28 m** od domu albo do trzeciej sali → `RETURN`. Wyjątki: wilki i raptory (40 m, łowcy), strażnicy (tylko arena), wezwani przez bossa (bez smyczy).

**Łańcuchowe budzenie:** tylko w tej samej sali, z linią wzroku, w 8 m, **najwyżej 2 eksponaty na budzącego**, a obudzeni w ten sposób przechodzą w `SUSPICIOUS`/`INVESTIGATE` (nie od razu `HUNT`).

**Przystań:** wejście strażnika = polujący przechodzą w `SEARCH` przy drzwiach przystani na 8 s, potem wracają do domów. **Wyjście z przystani nikogo nie przyciąga.**

**Limit polujących:** najwyżej **8** eksponatów naraz w `HUNT` w promieniu 30 m; nadmiarowi czekają w `INVESTIGATE` na skraju (tłum jak dziś zarządza pierścieniem ataku).

**Pierwsze 3 minuty nocy 1:** sale na trasie kanciapa → hol wejściowy → dziedziniec mają tylko śpiące eksponaty i 1–2 patrolujące figury (nauka walki), żadnych wilków.

**Projekt spotkań:** zestawy na salę jak dziś, plus:
- **Zasadzki** (`ambush`): śpiące eksponaty budzą się, gdy strażnik wejdzie w strefę lub weźmie przedmiot (np. mumie z sarkofagów przy strzelbie).
- **Patrole** (`patrol`): trasa punktów w obrębie sali/terytorium.
- **Gęstość** wyliczona z powierzchni sali (eksponatów na 100 m²: 0,6–1,2) i tempa skrzydła.

### 7.3 Wrogowie (podsumowanie)
| Wróg | Skrzydło | Nowy? |
|---|---|---|
| Figura woskowa | Egipt (wystawa czasowa), Czytelnia, hol | stary |
| Wypchany wilk | Oświecenie, podziemia | stary |
| Rycerz / zbroja samuraja | Czytelnia (rycerze), Azja (zbroje samurajów) | stary + nowy wygląd |
| Popiersie | Grecja | stary |
| Raptor | Oświecenie (skamieniałości), ryk T-Reksa | stary |
| Portret | Oświecenie (Galeria Portretów), dziedziniec | stary |
| **Mumia** | Egipt | nowy |
| **Rój skarabeuszy** | Egipt | nowy (prosty) |
| **Wojownik z reliefu** (+ lew z reliefu) | Asyria | nowy |
| **Hoplita** | Grecja | nowy (na bazie rycerza) |
| **Latające księgi** | Oświecenie | nowy |
| **Pies Fu z brązu** | Azja | nowy |
| **Totem** | Ameryki i Oceania | nowy |
| **Wojownik-jaguar** | Ameryki | nowy wygląd (zachowanie wilka) |

### 7.4 Strażnicy
Wspólne zasady: arena zamyka się na czas walki (drzwi zatrzaskują się z dźwiękiem, wychodzi pasek zdrowia z imieniem); każda faza ma zaopatrzenie (raz na noc na fazę); **każdy atak ma zapowiedź ≥ 0,6 s** i czytelną ucieczkę; po pokonaniu: kinematyczny rozpad, pieczęć/odłamek do podniesienia, drzwi się otwierają, zapis. Śmierć w walce: strażnik wraca do pełni następnej nocy (pokonany zostaje pokonany na zawsze). Czas walki: 2–3,5 min.

| Strażnik | Arena | Ruch | Ataki (zapowiedź) | Słaby punkt | Fazy |
|---|---|---|---|---|---|
| **Kolos Ramzesa** (Egipt, ok. 9 m, siedzi) | Sala Kolosa z kolumnami | obraca się na tronie; faza 3: wstaje i kroczy | **uderzenie dłonią** (cień dłoni na posadzce 0,9 s); **zamach przedramieniem** nisko (przeskocz); **promień słońca z oczu** (linia, ładowanie 1,2 s, chowaj się za kolumny — kolumny pękają po 2 trafieniach); wypuszcza roje skarabeuszy | **ureusz** (kobra na koronie) + pęknięcia na piersi, które się otwierają | 1: dłonie i promień; 2: skarabeusze, szybszy promień; 3: wstaje, kroczy (wstrząsy), promień omiata |
| **Lamassu** (Asyria) | Dziedziniec Pałacu | szarże, krótkie loty | **szarża** (grzebie kopytem 1 s); **podmuch skrzydeł** odpycha (rozłożenie skrzydeł 0,8 s); **tupnięcie**: pierścień fali uderzeniowej (przeskocz); faza 3: skok i lądowanie z falą | **ludzka twarz** (×1,5), korona | 2: budzą się wojownicy z reliefów na ścianach areny |
| **Kentaur z metopy** (Grecja) | Galeria Partenonu (długa) | szybki, krąży na dystansie | **oszczep** łukiem (zamach 0,8 s), **stanięcie dęba i kopnięcie** z bliska (0,7 s), **szarża przez galerię** | **marmurowy tors** (pierś), łeb | 2: woła Lapitów (hoplici); 3: dwa oszczepy naraz |
| **Wielkie Planetarium** (Oświecenie) | Rotunda | nieruchome; obracające się ramiona | **ramiona** na trzech wysokościach omiatają arenę (niskie: skacz; wysokie: stań w luce); **planety** odczepiają się i toczą / krążą jako pociski | **planety** (odstrzel 6), potem odsłonięte **słońce** | pierwszy strażnik dla wielu graczy: wolne tempo, uczy słabych punktów |
| **Generał samurajów** (Azja) | Ogród japoński | pojedynek, doskoki | **cięcie z doskoku** (błysk ostrza 0,7 s), **postawa obronna** odbija pociski z przodu (obejdź, paralizator), faza 2: **salwy strzał** z dachu herbaciarni, faza 3: **zwody w płatkach wiśni** | twarz pod maską, plecy | 3 fazy; ogłuszony paralizatorem otwiera się na dobicie |
| **Dwugłowy Wąż** (Ameryki) | Świątynia Węża (schodkowe podesty) | długie, segmentowe ciało sunie po podestach | **głowa A pluje** turkusowym odłamkiem, **głowa B kąsa** z wypadem (syk 0,7 s), **ogon** omiata | **głowy** + segmenty, z których odstrzelono mozaikę | 2: zmienia głowy; 3: otacza arenę ciałem |

### 7.5 Trudność (opcja w menu, dla Steam)
| Poziom | Zmiany |
|---|---|
| **Spokojna zmiana** | obrażenia wrogów ×0,6, wzrok −25%, więcej łupu |
| **Nocna zmiana** (domyślna) | wartości bazowe |
| **Podwójna zmiana** | obrażenia ×1,35, zdrowie wrogów ×1,2, wzrok +15%, mniej łupu, polujących najwyżej 10 |

---

## 8. Progresja

### 8.1 Ulepszenia (24)
Istniejące 18 + 6 nowych: **Sztucer:** „Lżejszy zamek” (cykl 1,0 → 0,7 s, 60), „Kula ekspansywna” (słaby punkt ×3 → ×4, 80). **Harpunnik:** „Kołowrotek” (przeładowanie 1,2 → 0,7 s, 55), „Zadziory” (przyszpilenie do 90 HP, 75). **Ognista skrzynia:** „Szybki lont” (ładowanie 2,2 → 1,5 s, 60), „Większa salwa” (6 → 9 rakiet, 90).
Ekonomia: więcej wrogów na noc → przeliczenie cen tak, by pełny katalog wymagał ok. **5–7 nocy** dobrej gry (test z symulacją Pyłu na noc).

### 8.2 Artefakty (6 + 4 nowe)
Nowe: **Oko Horusa** (Egipt: eksponaty w `SUSPICIOUS`/`HUNT` widać przez ściany w 15 m), **Pieczęć cylindryczna** (Asyria: pierwsze trafienie w każdego wroga ×2), **Sowa Ateny** (Grecja: trafienie w słaby punkt oddaje 1 nabój), **Kompas podróżnika** (Oświecenie: plan pokazuje sekrety bieżącego skrzydła). Plus trwały **Hetman z Lewis** za komplet szachów (+10% obrażeń wręcz i +1 drugi oddech na noc).

### 8.3 Pył
Pył za nowych wrogów jak w tabelach wyżej; strażnik skrzydła 60 Pyłu; T-Rex 100.

---

## 9. Interfejs

### 9.1 Plan muzeum (M)
- Wygląd: **składana ulotka dla zwiedzających** na papierze, w kolorach skrzydeł (jak plan British Museum), legenda PL/EN, „Jesteś tutaj” (strzałka), a na tym **ołówkowe dopiski strażnika**: odhaczone odwiedzone sale, kółka wokół przystani, znaczki znalezisk (broń, pieczęć, odłamek), wykrzyknik przy znanym strażniku, znak zapytania przy zamkniętych bramach z rodzajem zamka.
- Drukowany plan pokazuje **tylko sale publiczne**. Korytarze służbowe, podziemia i dach strażnik **dorysowuje ołówkiem** po odkryciu. Sekrety nigdy nie są drukowane: między salami zostają białe luki.
- Rysowany z danych układu (`LevelLayout`): prostokąty sal, kolory skrzydeł, przejścia, poziomy (parter / podziemia / dach jako zakładki).
- Plan pauzuje grę (jak czytnik notatek). W przystani i w kanciapie wisi też na ścianie.

### 9.2 HUD i ekrany
- Cel dynamiczny ([3.3](#33-cel-na-hud)), licznik odłamków, nazwa sali przy wejściu do nowej sali (mała karta „Galeria Rzeźby Egipskiej” z kolorem skrzydła).
- Pasek zdrowia strażnika z imieniem i podtytułem („Kolos Ramzesa — Strażnik Egiptu”).
- Ekran wczytywania nocy z podpowiedzią i plakietką nocy.
- Ekran końca Piętra I ([6](#6-finał-piętra-i)).

### 9.3 Menu i opcje (poziom Steam)
- **Menu główne z żywą sceną** dziedzińca (kamera na szynie, ten sam poziom w uproszczonej oprawie, bez wrogów).
- **Przypisywanie klawiszy** (wszystkie akcje, dwa klawisze na akcję, reset).
- **Pad** (Xbox / PlayStation przez SDL w Godot): ruch, celowanie z lekkim wspomaganiem (spowolnienie celownika na wrogu, opcja), wybór broni (koło broni na przytrzymaniu), nawigacja menu. Podpowiedzi przycisków zależne od urządzenia.
- **Dostępność:** siła wstrząsów kamery, kołysanie widoku, rozmiar i kolor celownika, migotanie świateł (ograniczenie), napisy dla ważnych dźwięków (ryk, zapowiedź ataku za plecami).
- **Trudność** ([7.5](#75-trudność-opcja-w-menu-dla-steam)).
- Statystyki i **ukończenie %** w menu pauzy.

---

## 10. Oprawa: grafika i dźwięk

### 10.1 Kierunek
Zasada „styl retro, nie jakość retro” bez zmian. **Każde skrzydło ma przepis:** paleta (3 kolory dominujące + akcent), materiały (zestaw tekstur 64 px/m), oświetlenie (kolor i siła księżyca, lamp, mgły), cząsteczki (pył, płatki, kartki, iskry), ambient, wariant muzyki.

| Skrzydło | Paleta | Światło | Cząsteczki |
|---|---|---|---|
| Dziedziniec | jasny wapień, stal, szkło | księżyc przez siatkę dachu (snopy w mgle) | kurz w snopach |
| Egipt | piaskowiec, złoto, turkus | zimny księżyc + ciepłe reflektory | piasek, pył |
| Asyria | szary alabaster, brąz, cedr | niskie, ostre, pochodnie | iskry pochodni |
| Grecja | biały marmur, błękit, ochra | najjaśniejsze, srebrne | prawie czyste powietrze |
| Oświecenie | dąb, mahoń, mosiądz, zieleń | ciepłe lampki, długie cienie | kurz z książek, kartki |
| Azja | czerwony lak, brąz, porcelana | lampiony + księżyc w ogrodzie | płatki wiśni |
| Ameryki i Oceania | ciemna czerwień, turkus, obsydian | teatralne, z dołu, ogień | żar, dym |
| Podziemia | beton, rdza, zieleń farby | świetlówki, migotanie | para, krople |

### 10.2 Blender
- **Zestawy architektury na skrzydło** (jak 119-elementowy zestaw holu): ściany, portale, kolumny w porządku skrzydła (egipskie papirusowe, asyryjskie, jońskie, regały), posadzki, stropy, drzwi, oprawy świateł.
- **Bryły-bohaterowie** (unikatowe, duże): szklany dach dziedzińca (kratownica trójkątna), bęben i kopuła Czytelni, Brama Chorsabadu z lamassu, fasada Pomnika Nereid, frontony Partenonu, Kolos, wielki Budda, herbaciarnia, czółno wojenne, moai, totem Haida.
- **Rekwizyty** na skrzydło (20–40): sarkofagi, Kamień z Rosetty, tabliczki klinowe, wazy, globusy, zegary, porcelana, maski, tiki itd.
- **Reliefy i fryzy:** modelowane płaskorzeźby wypiekane do tekstur z normal mapą (fryz Partenonu, polowanie na lwy, hieroglify).
- **Wrogowie i strażnicy:** modele z rigiem pozy jak dotychczasowe (osie w stawach, nazwane znaczniki), animacja kodem.
- **Broń w pierwszej osobie:** sztucer, harpunnik, ognista skrzynia (384–512 px/m).
- Wszystko powtarzalne ze skryptów (`tools/art/models/`), podglądy Cycles.

### 10.3 Godot: jakość obrazu
SDFGI na całe piętro, wolumetryczna mgła z **cieniami kratownicy dachu**, SSR na marmurach i szkle gablot, sondy odbić per sala, SSAO/SSIL, bloom, AgX, cząsteczki GPU, dekale (ślady trafień, zadrapania), fizyczne odłamki, światła z cieniem tylko tam, gdzie je widać (budżet na salę), `visibility_range` i **wyłączanie sal daleko w grafie** (światła, cząsteczki, dekoracje), okludery z brył ścian. Presety jakości Low–Ultra obejmują nowe efekty.

### 10.4 Dźwięk i muzyka
- **Ambient na skrzydło** (Egipt: wiatr w szczelinach, sypiący się piasek; Asyria: skrzypienie cedru; Grecja: echo, cisza; Oświecenie: tykanie zegarów, szelest kartek; Azja: dzwonki wietrzne, woda w ogrodzie; Ameryki: bębny w oddali, trzask ognia; podziemia: kocioł, kapanie).
- **Wariant muzyki na skrzydło**: ta sama kołysanka (motyw), inna skala i instrumentacja (Egipt: skala frygijska dominantowa, flet, harfa; Asyria: niskie bębny, lira; Grecja: kithara, chór; Oświecenie: klawesyn, pozytywka; Azja: pentatonika, koto, shakuhachi; Ameryki: marimba, piszczałki, bębny szczelinowe).
- **Temat strażników** (wspólny, z instrumentacją skrzydła) + finał T-Reksa (dzisiejszy, rozbudowany o chór dziedzińca).
- Dźwięki nowych broni, wrogów, zamków (łańcuch, deski, żaluzja, pieczęć: kamienne tarcie, zasilanie: przekaźnik i buczenie).
- Synteza skryptami jak dotąd (bez próbek z zewnątrz).

---

## 11. Technologia i architektura

### 11.1 Poziom z wielu stref
- `Floor1Layout` składa `LevelLayout` z **modułów stref** (`src/level/floor1/zones/<strefa>.gd`): każdy moduł dodaje sale, przejścia, schody, elementy, światła, spawny, łup, znaczniki i **bramy** tylko w swoim prostokącie strefy. Wspólne stałe (granice stref, punkty styku) są w `floor1_plan.gd` (kontrakt definiowany najpierw, żeby moduły dało się budować równolegle).
- `RoomSpec` dostaje `zone` (strefa) i `wing_color`; `LevelLayout` dostaje `gates` (`GateSpec`: id, rodzaj, klucz, przejście/obiekt) i `patrols`, `ambushes`.
- **Kształty nieprostokątne** (bęben Czytelni, ogród, świątynia) jako bryły-bohaterowie z kolizją wieloboków (16 segmentów płaskich, przyjazne siatce nawigacji), stojące w prostokątnych salach.
- `LobbyLevel` → `MuseumFloorLevel` (ten sam kontrakt `Level`). Stare lobby zostaje w repozytorium jako poziom testowy, dopóki nowe piętro nie przejmie wszystkich testów.

### 11.2 Postęp i stan
- `GameState` (trwały, zapis wersjonowany **z migracją**: stary zapis z lobby → nowe piętro; bronie i ulepszenia zostają, postęp lobby się zeruje) dostaje: `gates_open`, `guardians_defeated`, `seals`, `shards`, `rooms_visited`, `chess_found`, `difficulty`.
- `ProgressRules` (czysta logika, testowana): co otwiera co, cel na HUD, który strażnik jest dostępny, czy stan jest „bez blokady”.
- `NightDirector` uogólniony na strefy: zestawy spotkań per sala, gęstość z powierzchni, mnożnik skrzydła po strażniku, patrole, zasadzki, łagodny start nocy 1.

### 11.3 Nawigacja i wydajność
- **Siatka nawigacji per strefa** (osobne `NavigationRegion3D`, łączone krawędziami), wypiekana **przy eksporcie/budowie** do zasobów z sumą kontrolną układu; w grze wczytywana, a przy niezgodności wypiekana w tle. Bramy i drzwi nocy jako **przełączane regiony / warstwy nawigacji** zamiast ponownego wypiekania.
- **Wyłączanie odległych sal:** sale dalej niż 2 przejścia od strażnika tracą światła, cząsteczki i procesy dekoracji; eksponaty w nich śpią logicznie (tańsza aktualizacja co 0,5 s).
- **Okludery** z prostopadłościanów ścian (OccluderInstance3D z BoxOccluder3D/QuadOccluder3D).
- **Budżety:** ≥ 90 kl./s w najcięższym miejscu przy 1080p High na RTX 2080 Ti; wczytanie nocy ≤ 10 s (w tym wypiekanie, rozgrzewanie shaderów pod wyciemnieniem); preset Low dla słabszych kart.
- Jeżeli budowanie piętra z danych przy każdej nocy będzie za wolne: **wypieczenie gotowego drzewa węzłów do `.scn`** przy eksporcie.

### 11.4 Kod istniejący
Zasady z sekcji 10 specyfikacji obowiązują (węzły z kodu, dane w `.tres`, czysta logika w `RefCounted`, szyna `Events`, tabulatory, angielskie identyfikatory, teksty przez `tr()`, PL/EN).

---

## 12. Testowanie i weryfikacja
- **Osiągalność postępu:** dla każdego stanu postępu z grafu ([4.3](#43-graf-postępu-droga-krytyczna)) i każdej przystani startowej test sprawdza po siatce nawigacji, że następny klucz jest osiągalny (żadnych blokad), także z zamkniętymi drzwiami nocy.
- **Bot-zwiedzający:** skryptowany strażnik (bez wrogów) przechodzi drogę krytyczną i trasę 100% po siatce, mierzy długości tras i szacuje czas (prędkość chodu + czas walk z tabeli) → raport w `tests/_out/floor1_timing.json`; cel 45–80 min na 100%.
- **Testy percepcji:** stożek, ciemność, latarka, hałas przez otwarte/zamknięte drzwi, gubienie śladu, smycz, powrót, przystań bez przyciągania hordy, limit polujących, łagodny start nocy 1 („po wyjściu z kanciapy w promieniu 30 m poluje najwyżej 2 eksponatów przez pierwsze 60 s”).
- **Strażnicy:** testy maszyn stanów (bez sceny) + areny dev (`tools/run_guardian.sh <id>`).
- **Bronie:** testy obrażeń, przebicia, przyszpilenia, salwy, narzędzi (zamki).
- **Zrzuty wizualne:** scenariusz „wycieczka” robi zrzuty każdej sali w nocy (i w awarii prądu), z metryką jasności (średnia luminancja i % pikseli prawie czarnych: alarm, gdy sala jest za ciemna).
- **Wydajność:** scenariusz `perf_floor1` z pomiarem w 8 najcięższych miejscach.
- **Zapis:** migracja starego zapisu, zapis i wczytanie każdego pola postępu.
- **Testy muszą zostać szybkie:** strefy budowane w testach bez oprawy (greybox), pełna oprawa tylko w kilku testach i scenariuszach.

---

## 13. Etapy budowy

| Etap | Zawartość | Wynik |
|---|---|---|
| **P1 — Fundament i szkic całego piętra** | kontrakty (`floor1_plan`, strefy, `GateSpec`, `ProgressRules`, zapis z migracją), nowa percepcja i terytoria eksponatów, szkic wszystkich stref (greybox z kolorami skrzydeł, prawdziwe przejścia i bramy), postęp metroidvanii, cel dynamiczny, plan muzeum (M), przystanie, uogólniony reżyser nocy, nawigacja per strefa, bot-zwiedzający; istniejący wrogowie i bronie rozłożeni w nowych miejscach (strzelba na drodze); strażnicy jako tymczasowe „manekiny” z paskiem zdrowia | grywalne całe piętro w szarości, testy osiągalności i czasu |
| **P2 — Wzorzec: dziedziniec, hol wejściowy, kanciapa, Egipt** | zestawy architektury i bryły-bohaterowie (dach, Czytelnia, galeria egipska, Kolos), światło i mgła, mumia i skarabeusze, **Kolos Ramzesa**, strzelba w obozie, ambient i muzyka Egiptu, menu główne z żywą sceną | pierwsza godzina gry w docelowej jakości; ocena na zrzutach |
| **P3 — Pozostałe skrzydła (równolegle)** | Oświecenie (+sztucer, księgi, Planetarium), Asyria (relief, Lamassu), Grecja (hoplita, Kentaur), Azja (+ognista skrzynia, pies Fu, Generał), Ameryki i Oceania (+harpunnik, totem, Wąż), podziemia, dach | całe piętro w docelowej jakości |
| **P4 — Finał, szlif, wydanie** | finał T-Reksa w dziedzińcu, ekran końca, ulepszenia i artefakty, ekonomia, trudność, przypisywanie klawiszy, pad, dostępność, wydajność, presety, eksport exe, raport HTML dla właściciela | `build/NocnaZmiana.exe` |

**Organizacja:** jak w poprzednich etapach. Kontroler definiuje kontrakty i scala; budowniczowie (podagenci) pracują w osobnych drzewach roboczych, każdy pisze swój plan, TDD, commit po zadaniu; potem przegląd kodu modułami i poprawki z rozłącznym posiadaniem plików. Uruchomienia z oknem tylko w jednej, zbiorczej sesji naraz (nigdy wiele okien równolegle), zawsze bez dźwięku.

---

## 14. Ryzyka i odpowiedzi
| Ryzyko | Odpowiedź |
|---|---|
| Czas budowy poziomu przy każdej nocy | pomiar w P1; wypieczenie nawigacji i ewentualnie drzewa węzłów przy eksporcie |
| Wydajność dużego piętra | wyłączanie sal w grafie, okludery, budżet cieni na salę, presety |
| Zestaw testów spowolni | greybox w testach, oprawa tylko w scenariuszach |
| 12 nowych typów wrogów i strażników to dużo | wspólna baza (`Enemy`, maszyna stanów, `Guardian` z fazami), warianty istniejących zachowań (hoplita = rycerz, jaguar = wilk, zbroja samuraja = rycerz) |
| Postęp się zablokuje | `ProgressRules` + test osiągalności dla każdego stanu |
| Stare zapisy | migracja z zachowaniem broni i ulepszeń |
| Konkurs: jakość pierwszego wrażenia | P2 jako wzorzec jakości przed resztą; menu z żywą sceną; pierwsze 10 minut dopracowane jako pierwsze |

## 15. Poza zakresem Piętra I
Kolejne piętra (Piętro −1 i niżej), fabuła źródła przebudzeń dalej niż kryształ, integracja ze Steamworks (osiągnięcia, chmura), filtry retro.
