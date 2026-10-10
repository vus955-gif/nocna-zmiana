# Rozbudowa pierwszego obszaru — projekt (noc 30.09 → 1.10)

> Decyzje: Claude, na prośbę użytkownika („rozbuduj istniejącą grę: nowe mechaniki, większe muzeum, dodatkowe bronie i przeciwnicy, więcej ulepszeń — decyzję pozostawiam tobie”).
> Zasada nadrzędna: **najpierw kompletny i dopieszczony pierwszy obszar (lobby)**, dopiero potem nowe piętra. Wszystko poniżej dzieje się w lobby i wzmacnia jego pętlę. Liczby = punkt startowy do strojenia.

## 1. Nowe bronie (sloty 4 i 5)

### 1.1 Kartaczownica (Gatling z korbą) — `gatling`
| Parametr | Wartość |
|---|---|
| Rola | ciągły ogień, „piła” na tłum figur woskowych i popiersia |
| Rozkręcanie | 0,45 s zanim zacznie strzelać (dźwięk korby + terkot), po puszczeniu kręci się jeszcze 0,6 s (ponowny start natychmiastowy) |
| Ogień | 14 strzałów/s, 7 obr./pocisk, rozrzut 3° rosnący do 5° przy długiej serii |
| Amunicja | taśma nabojów karabinowych (`rifle`): pojemnik 120, zapas maks. 360; brak przeładowania (taśma ciągła) |
| Ruch | podczas strzelania strażnik chodzi −35% i nie może sprintować |
| Zdobycie | **ekspozycja w zbrojowni** („Kartaczownica, 1871”) — gablota zamknięta łańcuchem; łańcuch pęka od strzału ze strzelby albo 3 ciosów pięścią (zagadka dla uważnych). Raz zdobyta zostaje na zawsze |

### 1.2 Rakietnica sygnałowa — `flare`
| Parametr | Wartość |
|---|---|
| Rola | światło + podpalanie; kluczowa w nocy z awarią prądu |
| Pocisk | wolna raca (28 m/s, lekki łuk), przykleja się do wroga/ściany, **świeci 12 s** (OmniLight, cienie wyłączone), płonie: 6 obr./s przez 5 s na trafionym; **wosk topnieje 2× szybciej** (bonus ×2 obrażeń od ognia na woskowe) |
| Wybuch | przy trafieniu mały wybuch 2,5 m, 20 obr., odrzut; nie rani strażnika powyżej 50% (mała kara za strzał pod nogi) |
| Amunicja | race (`flares`): 1 w lufie, zapas maks. 8, przeładowanie 1,4 s |
| Zdobycie | **szafka ratunkowa w dioramie** (za szybką „W razie pożaru zbić szybkę” — interakcja: zbicie szybki = hałas, budzi wilki w dioramie) |

## 2. Nowi przeciwnicy

### 2.1 Szkielet raptora — `raptor`
Mały (1,1 m wys.), szybki (7,5 m/s), kruchy (25 HP), **polują stadami po 3–4**: flankują (dzielą się na lewo/prawo względem strażnika), doskok z 4 m (zapowiedź 0,3 s: przykucnięcie + syk), 8 obr. Kość: rozsypuje się na kostki. Pył 3. Pojawiają się w holu (ekspozycja „Velociraptor — stado”) i na antresoli. Ryk T-Reksa w fazie 2 może budzić raptory zamiast figur (50/50).

### 2.2 Portret — `portrait`
Obraz na ścianie galerii, **nieruchomy i nietykalny, dopóki się nie „obudzi”**: gdy strażnik przejdzie obok, oczy zaczynają go śledzić (sygnał dla uważnych), po 1,5 s rama wysuwa się ze ściany na 0,5 m. Atak: **pluje farbą** (pocisk łukiem, 10 obr., plama farby na podłodze 3 s spowalnia o 40%). 40 HP, słaby punkt: oczy ×2. Nie porusza się. Paralizator: 3 s ogłuszenia. Materiał: płótno + złocona rama (drzazgi, strzępy płótna). Pył 4. 2–4 portrety na noc w galerii i na antresoli, losowane spośród ~10 obrazów (reszta to zwykłe obrazy — napięcie!).

## 3. Nowe ulepszenia (katalog rośnie z 10 do 18 ulepszeń)
| id | Nazwa | Poziomy | Ceny | Efekt |
|---|---|---|---|---|
| `pockets` | Pojemne kieszenie | 2 | 30 / 60 | zapas amunicji +25% / +50% |
| `second_wind` | Drugi oddech | 1 | 120 | raz na noc śmiertelny cios zostawia 1 HP + 1 s nietykalności (dźwięk bicia serca, ekran szarzeje) |
| `dust_magnet` | Magnes na Pył | 2 | 25 / 50 | zasięg przyciągania Pyłu 6 → 9 → 12 m |
| `keen_ear` | Czujne ucho | 1 | 40 | wskaźnik kierunku na HUD, gdy eksponat za plecami zaczyna atak |
| `gatling_spin` | Nasmarowana korba | 1 | 50 | rozkręcanie 0,45 → 0,2 s |
| `gatling_belt` | Dłuższa taśma | 1 | 45 | pojemnik 120 → 200 |
| `flare_burn` | Magnezja | 1 | 45 | płonięcie 5 → 8 s, światło 12 → 20 s |
| `flare_twin` | Podwójna lufa | 1 | 70 | 2 race w lufie |

## 4. Nowa mechanika: zegar nocy („Nocna zmiana” dosłownie)
- HUD pokazuje zegar od **23:00 do 6:00**; 1 godzina gry = **3 minuty** (cała noc ≈ 21 min).
- **3:00 — godzina duchów:** komunikat, muzyka gęstnieje, eksponaty +20% prędkości i obrażeń do końca nocy.
- **6:00 — świt:** eksponaty zamierają w pół kroku (sztywnieją, szarzeją), światło wschodu przez świetliki. Noc się kończy **bez śmierci**: niesiony Pył **zostaje przy strażniku** (bez latarki), bezpieczniki i kryształ przepadają, numer nocy +1. To bezpieczna „ucieczka” dla ostrożnych, ale bez postępu celu.
- Pokonanie T-Reksa przed świtem = zwycięstwo (koniec dema).
- Zegar staje w menu, pauzie i w przystani (przystań to „przerwa w pracy”) — ale nie dłużej niż 60 s na wizytę, potem rusza (żeby przystań nie była zamrażarką czasu).

## 5. CCTV (część integracji 2b-2)
Ściana monitorów w kanciapie: 6 kamer (hol, galeria, zbrojownia, diorama, antresola, korytarz). Interakcja z pulpitem = widok z kamer (przełączanie 1–6, Esc wyjście; gra pauzuje zegar tylko na 10 s wizyty… nie — zegar biegnie, to ryzyko). Kamery pokazują żywy obraz (SubViewport, niska rozdzielczość, szum, scanlines): widać śpiące eksponaty, pulsujący kryształ, upuszczoną latarkę. Kamery istnieją w świecie (można je zestrzelić? nie w tej wersji).

## 6. Kolejność prac
1. Integracja 2b-2/2c-2 (lobby = gra, cel nocy, boss, sekrety, szafka, notatki, CCTV, artefakty, modyfikatory).
2. Oprawa: modele wrogów i broni, ubranie lobby w elementy z Blendera, światło.
3. Zawartość z tego dokumentu (bronie, wrogowie, ulepszenia, zegar nocy).
4. Muzyka i dźwięk otoczenia (równolegle, osobny tor).
5. Szlif, balans, wydajność, eksport, pełna weryfikacja.
