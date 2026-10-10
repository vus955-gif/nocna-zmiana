# Piętro I — lista zadań (backlog) od właściciela

> Źródło: uwagi właściciela po pierwszym teście wersji podglądowej (3.10.2026) i lista wymagań „production ready”.
> Wracamy w piątek (od 9.10) w NOWEJ sesji; stan prac i odłożone gałęzie: pamięć projektu `first-area-expansion` / `playtest-2026-10-03`.
> Numeracja jak u właściciela (punkty 14–16 pominięte).
>
> **Długość gry (właściciel, 3.10):** gra może być długa, jeśli ma to sens — nie upychać na siłę w 60 minut; nawet ~180 minut jest w porządku.

## Uwagi z testu (3.10)

1. Przy broniach długich (sztucer) ręka podtrzymująca lufę jest wygięta jak złamana — poprawić anatomię.
2. Podziemia bardzo ciemne (tu ma to sens), ale niektóre sekcje na powierzchni zdecydowanie za ciemne.
3. Przeładowanie sztucera: łódka z nabojami lewituje, brak ręki, która ją wkłada; zadbać o anatomię (nie mil-sim, ale ma się prezentować).
4. Brakuje „stylu” wizualnego całości (wygląda znośnie i ładnie jak na Godot + Blender).
5. Sekretne pokoje nic nie dają, a często trzeba zużyć zasoby, by je otworzyć — sekret musi dawać nagrodę (boost statystyk, unikalny wygląd broni, trwały bonus).
6. Muzyka zróżnicowana według biomu (Egipt: phrygian dominant; Oświecenie: klasyczna), najlepiej metal/elektronika z naleciałościami epoki/kultury.
7. W podziemiach brakowało tekstur (gałąź `dress-basement` nie była scalona w wersji podglądowej; scalona z Grecją i Oświeceniem na gałęzi `fable-test-merge`).
8. Przeciwnicy przez większość czasu stoją, aż się podejdzie; potrzebne rutyny i „inteligencja”, lepsza integracja z otoczeniem. Bardzo udane: ożywające obrazy, latające księgi wracające na półki, mumia wychodząca z sarkofagu.
9. ZOSTAWIĆ krótką animację oglądania broni po ulepszeniu — duży plus.
10. Kawiarnia w holu: dać się wejść za ladę; mechanika zmęczenia (stamina z upływem nocy przejmowana przez zmęczenie), kawa z ekspresu ją niweluje.
11. Kiepskie rozróżnienie wizualne amunicji do różnych broni.
12. Ogólnie dobra droga; tekstury i modele to mocna strona. Ewentualnie z czasem przeniesienie do Unity dla „poważniejszej” gry.
13. Trudność: na początku względnie trudno, potem szybko można się wymaksować. Pyłu wypada wystarczająco — NIE zmieniać. Łatwość może wynikać z bierności przeciwników. **Odłożone:** trudność i przebudowę ulepszeń (więcej poziomów z mniejszymi bonusami / ostatni poziom za Pył Strażnika z bossa biomu) robimy dopiero po zmianie zachowania przeciwników i nowym teście.

## Wymagania właściciela (17–62)

17. Poprawienie animacji przeciwników i lepsze zróżnicowanie ich.

18. Trzeba mocno dopracować ogólny „gun feel”. Każda broń powinna dawać wyraźnie inne odczucie: recoil, muzzle flash, dźwięk, animacja, kamera, czas pomiędzy strzałami, reakcja przeciwnika na trafienie. Strzelba powinna być brutalna i ciężka, pistolet szybki i precyzyjny, sztucer bardzo mocny, ale wolniejszy itd. Nie chcę sytuacji, w której wszystkie bronie są de facto tym samym hitscanem z innym modelem.

19. Trafienia powinny mieć znacznie lepszy feedback. Przeciwnik musi reagować na kierunek i siłę trafienia, powinny istnieć hit reactions, odpowiednie efekty cząsteczkowe, decal na powierzchni, odpowiedni dźwięk i ewentualnie krótkie staggerowanie przy mocnych trafieniach. Przy zabiciu ciężką bronią reakcja powinna być wyraźnie mocniejsza niż przy lekkim pistolecie.

20. Do poprawienia jest encounter design. Nie chcę pomieszczeń, w których przeciwnicy zostali po prostu ustawieni ręcznie w kilku miejscach. Starcia powinny być projektowane jako małe scenariusze: wejście gracza, pierwszy kontakt, zmiana sytuacji, flankowanie, pojawienie się nowego typu przeciwnika, wykorzystanie architektury pomieszczenia itd.

21. Trzeba bardziej wykorzystywać wertykalność map. Balkony, schody, galerie, antresole, przejścia nad graczem, przeciwnicy atakujący z różnych wysokości. Lokacje nie powinny przypominać zestawu płaskich korytarzy i pokojów.

22. Więcej elementów środowiska powinno reagować na gracza i walkę. Obrazy, eksponaty, gabloty, posągi, lampy, książki, drzwi, zasłony, żyrandole, sarkofagi itd. Nie wszystko musi być zniszczalne, ale świat powinien sprawiać wrażenie miejsca, które istnieje, a nie statycznego levelu FPS.

23. Warto dodać elementy environmental combat. Przykładowo możliwość zestrzelenia żyrandola, przewrócenia ciężkiego eksponatu, aktywowania mechanizmu muzealnego, podpalenia czegoś albo wykorzystania instalacji elektrycznej przeciwko przeciwnikom. Powinny być opcjonalne i nie zastępować klasycznej walki.

24. Przeciwnicy powinni reagować również na wydarzenia w otoczeniu. Hałas, strzały, eksplozje, śmierć pobliskiego przeciwnika albo otwarcie drzwi powinny przynajmniej czasami powodować reakcję innych przeciwników. Nie chcę sytuacji, w której zabijam kogoś dwa metry od drugiego NPC, a ten nadal stoi bez ruchu, bo nie wszedłem w jego trigger aggro.

25. Poszczególne klasy przeciwników powinny mieć konkretne role bojowe, a nie tylko różną ilość HP. Przykładowo: melee pressure, ranged harassment, flanker, tank, support, summoner, glass cannon itd. Kombinacja przeciwników ma tworzyć dynamikę walki.

26. Każdy biom/epoka powinien mieć nie tylko inne tekstury i muzykę, ale również własne mechaniki gameplayowe. Egipt może wykorzystywać pułapki, klątwy i sarkofagi. Inna epoka może mieć mechaniczne konstrukcje, broń charakterystyczną dla okresu albo przeciwników korzystających ze specyficznych zachowań. Chodzi o to, żeby zmiana sekcji faktycznie zmieniała sposób gry.

27. Museum theme trzeba wykorzystać znacznie mocniej. Eksponaty powinny nie tylko dekorować mapę, ale również opowiadać mini-historie, stanowić źródło sekretów, uruchamiać encountery, dawać bonusy albo czasami ożywać. To jest jeden z najbardziej charakterystycznych elementów konceptu gry i warto oprzeć na nim dużą część identity projektu.

28. Dodać więcej „foreshadowingu” przeciwników. Jeśli np. później ożyje posąg albo mumia wyjdzie z sarkofagu, można wcześniej subtelnie pokazać podobny eksponat albo jakiś ślad sugerujący, że coś jest nie tak. Dzięki temu jumpscare/atak nie jest całkowicie arbitralny.

29. Sekrety powinny mieć różne poziomy wartości. Małe sekrety mogą dawać ammo/HP, większe trwałe bonusy, a bardzo dobrze ukryte miejsca unikalną broń, alternatywny wygląd, perk albo specjalną modyfikację. Nie wszystkie sekrety powinny być równoważne.

30. Można rozważyć ograniczony system ulepszeń broni, ale bez zamieniania gry w looter shootera. Każda broń mogłaby mieć 2–3 znaczące modyfikacje zmieniające sposób działania, zamiast kilkudziesięciu procentowych statystyk typu +4% damage.

31. Ulepszenia powinny być również wizualnie widoczne na modelu broni. Nowa lufa, celownik, magazynek, mechanizm, runy, ozdobniki albo inne elementy zależne od charakteru świata. Broń powinna stopniowo wyglądać jak coś, co gracz rozwijał przez całą noc.

32. Kawiarnia/kiosk może być czymś więcej niż vending machine z kawą. Może stanowić bezpieczny hub, w którym Strażnik między sekcjami robi sobie chwilę przerwy, kupuje kawę, uzupełnia zapasy albo komentuje absurdalną sytuację. To może też pomóc w rytmie gry: walka → eksploracja → chwila oddechu → następna eskalacja.

33. Mechanika zmęczenia powinna wpływać na gameplay subtelnie, żeby nie stała się irytującym survival barem. Przykładowo przy dużym zmęczeniu stamina regeneruje się wolniej, sprint trwa krócej albo lekko pogarsza się stabilność broni. Kawa czasowo cofa zmęczenie. Nie chciałbym jednak karania gracza za coś, czego nie może uniknąć.

34. Warto dodać naturalną progresję nocy. Początek może być względnie spokojny i dziwny, potem paranormalne wydarzenia stają się coraz bardziej oczywiste, a pod koniec muzeum może być już kompletnie opanowane przez anomalie. Świat powinien wizualnie i gameplayowo pokazywać eskalację.

35. Powroty do wcześniejszych części muzeum powinny czasami pokazywać, że świat się zmienił. Eksponat zniknął, drzwi są otwarte, obraz patrzy w inną stronę, pojawiły się ślady walki, coś przeszło przez korytarz itd. Dzięki temu muzeum nie wygląda jak zestaw niezależnych poziomów.

36. Potrzebne są mocniejsze momenty typu set-piece. Nie tylko kolejne areny z przeciwnikami. Np. ucieczka przed wielkim ożywionym eksponatem, walka podczas rozpadającej się ekspozycji, zamknięcie w sali, która zaczyna zmieniać układ, albo wydarzenie obejmujące cały hol muzeum.

37. Przydałby się przynajmniej jeden lub kilka minibossów zaprojektowanych specjalnie pod dane sekcje muzeum. Nie mogą być zwykłym przeciwnikiem z 10x HP. Powinni mieć własne zachowania, animacje, sposób wejścia do walki i wykorzystywać przestrzeń konkretnego biomu.

38. Nawigacja po mapie musi być czytelna bez permanentnych znaczników prowadzących gracza za rękę. Światło, architektura, kolory, charakterystyczne obiekty i framing powinny naturalnie sugerować, gdzie można iść. Jeśli gracz regularnie nie wie, gdzie znajduje się właściwa droga, problemem jest level design, nie brak wielkiej strzałki na HUD.

39. Jednocześnie trzeba ograniczyć przypadki, gdzie przedmiot wyglądający jak drzwi/przejście/element interaktywny jest tylko dekoracją. Język wizualny interakcji powinien być spójny.

40. Audio wymaga osobnego passu. Każdy rodzaj broni, przeciwnika i pomieszczenia powinien mieć właściwy charakter akustyczny. Strzał w ogromnym kamiennym holu nie powinien brzmieć tak samo jak w małym magazynie. Można wykorzystać reverb zones i różne profile akustyczne.

41. Dodać ambient audio i audio storytelling: skrzypienie budynku, wentylacja, odległe kroki, poruszające się eksponaty, szepty, radio ochrony, zegary, dźwięki miasta za oknem itd. Cisza również powinna być świadomie używana.

42. UI/HUD powinien mieć własny spójny styl powiązany z grą. Nie chcę generycznego Godot UI. Ammo, HP, stamina, zmęczenie, interakcje i informacje o sekretach powinny wyglądać jak element jednego projektu artystycznego.

43. Pickupy muszą być czytelne z daleka. Amunicja, HP, kawa, upgrade itd. powinny mieć charakterystyczny silhouette/color language i nie wymagać podchodzenia na 30 cm, żeby rozpoznać przedmiot.

44. Warto dodać kilka bardzo krótkich animacji inspect dla broni także poza momentem ulepszenia. Nie musi istnieć osobny klawisz inspect, ale np. po pierwszym znalezieniu broni Strażnik może przez sekundę ją obejrzeć.

45. Animacje pierwszoosobowe wymagają osobnego polish passu. Ręce, palce, chwyt broni, reload, sprint, melee, interakcje i przełączanie broni powinny zostać obejrzane klatka po klatce pod kątem anatomii i clippingu.

46. Sprawdzić clipping broni i rąk ze ścianami, drzwiami oraz obiektami. Szczególnie przy dużym FOV i podczas sprintu/reloadu.

47. Dodać sensowną reakcję kamery, ale bez przesady. Delikatny recoil, impulse po eksplozji, movement podczas chodzenia/sprintu i odpowiednie przejścia animacyjne. Nie chcę „drunk camera” ani przesadnego headboba powodującego mdłości.

48. Movement powinien zostać dopracowany jako osobna mechanika. Przyspieszenie, hamowanie, air control, sprint, strafing, skok i ewentualne bunny hopping powinny być świadomie dostrojone. Boomer shooter musi przede wszystkim dobrze się poruszać.

49. Collision i poruszanie po geometrii wymagają testów. Gracz nie powinien zatrzymywać się na centymetrowym uskoku, blokować na dekoracji ani wpadać w niewidzialne narożniki.

50. Dodać pełny pass QA dotyczący softlocków. Każde drzwi, trigger, arena, sekret, elevator, przejście i scripted event powinny zostać sprawdzone pod kątem sytuacji, w której gracz może znaleźć się w stanie uniemożliwiającym dalszą grę.

51. Save/checkpoint system musi być odporny. Po załadowaniu save'a stan przeciwników, sekretów, otwartych przejść, ulepszeń, skryptów i świata powinien być identyczny jak przed zapisem. Nie mogą się resetować encountery albo ponownie odpalać wydarzenia fabularne.

52. Opcje graficzne i gameplayowe powinny być kompletne: resolution, fullscreen/windowed, VSync, FPS limit, FOV, mouse sensitivity, audio volumes, brightness/gamma, motion effects, screen shake itd.

53. Zrobić sensowną skalę trudności. Wyższy difficulty nie powinien polegać wyłącznie na zwiększeniu HP przeciwników. Można zwiększać agresywność AI, częstotliwość specjalnych ataków, liczebność określonych encounterów albo zmniejszać dostępność zasobów.

54. Nie przesadzić z zasobami. Ammo i HP powinny powodować lekką presję, ale nie zmuszać gracza do oszczędzania każdej kuli. To nadal ma być shooter, a nie survival horror.

55. Warto zadbać o rytm całej gry. Nie może być 60 minut ciągłej strzelaniny. Potrzebne są fale napięcia: walka, eksploracja, sekret, storytelling, cisza, większa walka, hub, nowy biom itd.

56. Każdy większy segment powinien mieć przynajmniej jeden moment, który gracz zapamięta. Nie musi to być boss. Może to być niezwykłe pomieszczenie, mechanika, sytuacja albo wizualne wydarzenie charakterystyczne tylko dla tego miejsca.

57. Przy optymalizacji nie obniżaj automatycznie jakości grafiki. Najpierw profiluj bottlenecki CPU/GPU, draw calls, światła, cienie, shadery, particles, AI, physics i liczbę aktywnych obiektów. Dopiero potem optymalizuj konkretny problem. Celem jest zarówno dobra wydajność, jak i maksymalne wykorzystanie Godota.

58. Przy końcowych testach sprawdź różne FOV, rozdzielczości, framerate oraz aspect ratio. Szczególnie 16:9, 21:9 i wysokie FOV, ponieważ błędy viewmodelu i UI często wychodzą właśnie tam.

59. Dodaj performance telemetry/debug overlay na potrzeby developmentu: FPS, frametime CPU/GPU, liczba draw calls, liczba aktywnych AI, triangles/objects, pamięć oraz informacje o najdroższych systemach. Nie musi być dostępny w finalnej grze, ale ma pomóc podczas optymalizacji.

60. Po skończeniu prac wykonaj pełny playthrough bez używania debug tools, noclipu, god mode ani ręcznego teleportowania się pomiędzy sekcjami. Gra ma zostać przetestowana tak, jak będzie ją przechodził gracz od początku do końca.

61. Następnie wykonaj osobny polish pass, w którym nie dodajesz już nowych dużych funkcji, tylko szukasz drobnych rzeczy psujących odbiór: clipping, złe przejścia animacji, popping LOD, dziwne cienie, brakujące tekstury, obiekty unoszące się nad ziemią, złe normal mapy, niedopasowane efekty, przypadkowe różnice głośności itd.

62. „Production ready” nie oznacza tylko, że projekt się uruchamia i da się przejść do końca. Oznacza, że główna ścieżka gry działa bez błędów, nie ma znanych blockerów ani softlocków, save/load działa, gameplay jest zbalansowany, framerate jest stabilny, wszystkie główne animacje i assety są poprawne, a całość przeszła pełny playthrough i finalny polish pass.

## Lista rozszerzona (pisana pod Astrę) — selekcja Claude'a (3.10)

> Właściciel dał wolną rękę: wybrać, zmienić, odrzucić. Oznaczenia: **[+]** przyjęte · **[~]** przyjęte ze zmianą · **[x]** odrzucone · **[jest]** już zrobione — do weryfikacji w grze.

### Zasady pracy (przyjęte w całości)
- [+] Nie trzymać się istniejącego kodu za wszelką cenę: słaby system, level, model, shader, animację **przepisać od nowa**, jeśli to szybsze niż łatanie. Zestaw testów (≈1900) zostaje siatką bezpieczeństwa.
- [+] Gameplay ma pierwszeństwo przed efektami; dopracowanie istniejących starć przed nowymi typami wrogów; **bez feature creep** — ale pozostałe 3 skrzydła, 3 strażników i 4 wrogów wschodu to rdzeń obszaru, nie nowe funkcje.
- [+] Nowe funkcje najpierw na liście z oceną: wpływ na gameplay, zgodność z muzeum, koszt, ryzyko destabilizacji, wartość dla gracza; wdrażać tylko te, które realnie poprawiają grę. Research gier (boomer shootery, immersive simy, horror FPS, retro FPS) raz, jako jeden dokument — analiza *dlaczego* coś działa, bez kopiowania.
- [+] Cykl: **ślepe przejście → lista problemów → paczka poprawek → regresja → ponowne przejście**, aż kolejne przejścia nie ujawniają istotnych problemów. [~] „Przejście” = test właściciela + przejście bota w oknie ze zrzutami i telemetrią (gdzie gracz stoi bez postępu, gdzie ginie).
- [+] „Juice” dopiero na końcu i nigdy do maskowania słabego systemu; na koniec „polish beyond necessity”.
- [+] Audyty przed wydaniem: spójność (skala, PBR, gęstość tekseli, światło, materiały, animacje, głośność, UI, nazwy), dezorientacja gracza (poprawiać level designem, światłem, kadrowaniem — **nie** strzałką), śmierci (każda wytłumaczalna), nudy (fragment bez nowej decyzji/informacji/zagrożenia/obrazu przez kilka minut), powtórzeń (dwa starcia/pokoje robiące to samo → połączyć lub zmienić).

### Broń i walka
- [+] Każda broń wokół własnej „fantazji”: po 2–3 strzałach wiadomo bez HUD, czego się używa — rytm, odrzut, penetracja, stagger, zasięg, przeładowanie, dźwięk, efekt na celu (rozszerza #18).
- [~] Stany obsługi broni: idle, chód, sprint, strzał, powrót po odrzucie, pusty spust, przeładowanie taktyczne i z pustego, zmiana, podniesienie, oglądanie — płynne przejścia. **Bez ADS** (boomer shooter; PPM = pięść).
- [+] „Pierwszy strzał”: przy zdobyciu broni od razu sytuacja, w której jej zaleta jest oczywista (strzelba → zasadzka mumii już jest; zaprojektować dla każdej broni).
- [~] Tryb alternatywny dla 2–3 broni na osobnym klawiszu (slug strzelby już jest; np. przebijający strzał sztucera z przytrzymania, krótki wachlarz pistoletu) — tylko jeśli nie rozdmuchuje projektu.
- [jest] Osobliwości epoki (korba kartaczownicy, hwacha, harpunnik, rakietnica) — utrzymać ten kierunek.
- [+] Efekty trafień zależne od materiału **świata i wrogów**: kamień, drewno, metal, szkło, tkanina, ceramika, wosk, kość, marmur — inny dźwięk, cząstki, ślad.
- [~] Penetracja tylko tam, gdzie ma sens: sztucer przez szkło gablot, cienkie drewno i kilku wrogów (częściowo jest).
- [~] Obrażenia lokalne: elementy pancerza do strącenia (rycerz, hoplita — częściowo jest), stagger zależny od trafionej kończyny u wrogów humanoidalnych.
- [jest] Zapowiedzi ataków ≥ 0,6 s — utrzymać; audyt śmierci to sprawdzi.
- [x] Ragdolle → **zamiast nich rozpad materiałowy** (wosk, marmur, bandaże, trociny) — to tożsamość gry. [~] Przejście „animacja śmierci → rozpad” ma być ładne, a impuls odłamków ograniczony (nic nie odlatuje na 300 m).

### Przeciwnicy i AI
- [jest] Stany świadomości (śpi, podejrzliwy, sprawdza, poluje, szuka, wraca) i szukanie ostatniej znanej pozycji — zrobione w P1; problemem z testu jest **bierność w spoczynku** → #8: rutyny, miejsce w ekspozycji, przebudzenie, powrót na miejsce.
- [+] Zmiana pozycji: wrogowie dystansowi wycofują się, szukają linii strzału, zajmują lepsze miejsce, próbują odciąć drogę.
- [+] Ograniczona koordynacja grupy (nie wszyscy robią to samo: jeden flankuje, inny naciska) + **brak korków w drzwiach** (tłum już jest — sprawdzić w przejściach).
- [+] Jasny counterplay dla każdego typu, uczony przy pierwszym spotkaniu; starcia z kombinacji ról (#20, #25).
- [~] Prosty „reżyser tempa”: śledzi kondycję gracza, czas od ostatniej walki i intensywność; steruje **tylko** drobnymi rzeczami (moment zdarzeń otoczenia, część posiłków) — bez oszukiwania, starcia zostają projektowane ręcznie.
- [+] Wrogowie widziani, zanim staną się zagrożeniem: sylwetka za szybą, mumia w gablocie, cień na ścianie (#28).

### Świat, zdarzenia, narracja
- [+] Zdarzenia muzealne niezwiązane z walką: obraz zmienia treść, zegar chodzi wspak, eksponat znika, manekin obraca głowę, radio nadaje coś niepokojącego; część rzadka/warunkowa (różne noce). **Najlepsze momenty ręcznie zaprojektowane**, nie proceduralne.
- [+] Światło jako mechanika: migotanie, awaryjne, reflektory ekspozycji, światło prowadzące, cienie zapowiadające wroga. W celowo ciemnych miejscach gracz ma narzędzie (latarka, raca — sprawdzić, czy wystarczają), nie „podkręć gammę”.
- [+] Opowiadanie przestrzenią: układ sal, ekspozycje, co się stało z personelem — mniej tekstu, krótsze notatki.
- [~] Osobowość strażnika: rzadkie, krótkie reakcje **tekstem** (bez dubbingu), żadnego ciągłego komentowania.
- [~] Radio ochrony / telefon / PA jako narzędzie narracji i gry — tekst + syntezowane trzaski radiowe (bez głosu aktora).
- [+] Kawiarnia zmienia się z nocą (ekspres wariuje, etykiety się zmieniają, automat proponuje absurdy); 2–3 rodzaje kawy (espresso: krótko i mocno; duża: długo i słabiej) — razem z #10, #32, #33.

### Sekrety i nagrody
- [+] Mikronagrody: dźwięk podniesienia, reakcja HUD, mały efekt przy sekrecie, animacja ulepszenia (oglądanie broni — zostaje, #9).
- [+] Sekrety jako mini-zagadki środowiskowe; sekrety łączone w jeden super-sekret (szachy z Lewis już są → rozbudować w ukrytą salę); ukryte starcia tylko dla eksplorujących; nagrody stopniowane (#29).
- [~] Statystyki końcowe nocy i piętra: czas, zabici, sekrety, celność, otrzymane obrażenia, znaleziska (częściowo jest). „Par time” — tylko jako cichy bonus w podsumowaniu.
- [x] Powtarzanie ukończonych sekcji z menu → nie pasuje do jednego połączonego piętra. [~] Zamiast tego: noce-epilogi po finale (są) + opcjonalny rewanż ze strażnikiem w przystani (niski priorytet).

### Jakość techniczna i QA
- [~] Przyjazność speedrunom: szybkie drzwi, wszystkie przerywniki do pominięcia (wejścia strażników przy kolejnych próbach), żadnych długich, nieprzyspieszalnych sekwencji.
- [+] Testy skrajnych zachowań gracza (bunny hop, strzelanie w dekoracje, cofanie się w trakcie zdarzeń, zabicie wroga przed końcem jego wejścia, trigger od tyłu); żadnych założeń o kolejności (W7 już losuje kolejności); każda sekwencja skryptowa ma stan awaryjny.
- [jest] Regresja (≈1900 testów); [+] dodać **dymny test całej nocy** botem po każdej dużej zmianie.
- [+] 5 scen wzorcowych do pomiarów (ciężka walka, hub, najdroższy biom, najwięcej świateł, finał) + **historia wyników wydajności** w pliku per build + budżety (światła, cienie, draw calls, cząstki, AI, fizyka). Optymalizacja po profilowaniu, nie przez wyłączanie cieni (#57).
- [+] Opóźnienie wejścia (input → kamera → broń), surowe wejście myszy niezależne od FPS, bez akceleracji.
- [+] Pad: martwe strefy, czułość, krzywa celowania; przypisywanie wszystkich akcji; dostępność (wstrząsy, kołysanie, FOV, błyski, napisy, audio); HUD czytelny w 4K i ultrawide (#52, #58).
- [+] Wczytywanie bez zamrażania obrazu (dziś budowa poziomu trzyma klatkę ~3 s — przenieść do wątku z animowanym ekranem); [jest] rozgrzewanie shaderów pod wyciemnieniem — sprawdzić przycięcia w prawdziwym przejściu (wraca otwarte pytanie o pamięć shaderów na C:).
- [+] Audio: profilowanie liczby źródeł, **przesłanianie dźwięku** ścianami (graf sal + promień), pogłos według przestrzeni (#40, częściowo jest); muzyka warstwowa ambient → perkusja → walka → kulminacja z przejściami w takt (częściowo jest — rozbudować pod nowy kierunek metal/elektronika, #6); muzyka bossa reaguje na fazy (jest dla fazy 2 — dodać 3).
- [+] Drobna destrukcja z sensem: szyby, ceramika (wazy w Grecji, porcelana w Azji), część eksponatów i rekwizytów; pule obiektów i sprzątanie śladów/odłamków, żeby po 30 min wydajność nie spadała.

### Kierunek graficzny
- [+] Hierarchia wizualna: w walce natychmiast widać wroga, zagrożenie, przedmiot, interakcję, drogę; piękna, ale nieczytelna scena = błąd kierunku graficznego (#4, #43).
- [~] „Biblia” każdego skrzydła (paleta, materiały, światło, **geometria**, ornament, wrogowie, muzyka, opowiadanie przestrzenią) — rozszerzyć §10.1 projektu — **plus wspólny nadrzędny kierunek**, żeby skrzydła nie wyglądały jak paczki z pięciu gier.
- [+] Przegląd sylwetek wrogów (rozpoznawalne w półmroku) i broni w pierwszej osobie; żadnych assetów bez funkcji (gra, narracja, kompozycja).

### Level design (155–215) — przyjęte prawie w całości
- [+] **Zasada nadrzędna (215): mapa może być duża, ale gracz ma czuć, że odkrywa duże miejsce, a nie że chodzi po dużej mapie.**
- [+] 155–158, 172, 183, 203–206: każda duża przestrzeń musi mieć uzasadnienie i wewnętrzną strukturę; żadnego „syndromu poziomu z generatora”. **Konkretnie do przeróbki** (pomiar W7): kładki dachu (3570 m², 1 przeciwnik), pierścień korytarzy podziemi, skrzyżowanie i magazyn cokołów w podziemiach, Sala z Bassae, balkon dziedzińca, galeria nad dołem lwów, galeria porcelany, sala zegarów, 56-metrowy korytarz północny. Mierzyć gęstość treści i decyzji per salę (rozszerzyć bota W7).
- [+] 159, 171–173: różne skale, kompresja i uwolnienie, jeden moment „wow” na segment, ale nie wszystko monumentalne.
- [+] 160: charakterystyczna geometria skrzydeł (Egipt dziś to głównie długa galeria — dodać np. salę hypostylową / zejście do grobowca; Asyria: dziedzińce pałacowe; Grecja: podium świątyni; itd.).
- [jest] 161, 168: sieć, pętle, skróty (podziemia, zasuwy). [+] 162–165, 180: nawigacja przez landmarki, światło, linie wzroku, „pokaż zanim dostępne”, lokalne cele wzrokowe.
- [+] 166–167, 169–170: powroty mają sens (świat się zmienia, #35), hub ewoluuje z nocą (#34), żadnych długich pustych korytarzy do ponownego przejścia.
- [+] 174–179: areny projektowane razem z zachowaniem wrogów, kilka trajektorii ruchu, zachęta do ruchu, żadnego „stań w drzwiach”, zmiana geometrii w trakcie starcia, warstwy treści w dużych salach.
- [+] 181–182: długie proste korytarze tylko z funkcją (napięcie, zapowiedź, narracja); spokojne strefy z atmosferą.
- [+] 184–188: warstwy eksploracji, sekrety oparte na obserwacji („mogłem to zauważyć”), opcjonalne pod-obszary z proporcjonalną nagrodą.
- [+] 189–194: wiarygodne zaplecze (tunele, magazyny, pokoje personelu, warsztat, monitoring, serwerownia, rampa rozładunkowa, archiwum) — muzealne, nie generyczny industrial; kontrast publiczne/zaplecze; **podziemia schodzą w coraz starsze warstwy budynku** — naturalne przejście do Piętra −1.
- [+] 195–198: logiczne relacje sal; 1–3 świadome momenty „niemożliwej architektury” jako zdarzenie paranormalne późnej nocy, nie ciągły gadżet.
- [+] 199: miejsca z emocjonalnym przywiązaniem (hub, kawiarnia, monitoring w kanciapie).
- [~] 200: różne sposoby przemieszczania (schody, winda towarowa, drabiny, wąskie przejścia) — **bez platformówki**.
- [+] 201–202: bez niewidzialnych ścian; widać = można wejść albo widać, dlaczego nie (spójne z #39).
- [+] 207–211: przejścia warstwowe — bez wrogów (sama eksploracja), tylko starcia, tylko sekrety, opowiadanie/kierunek graficzny, na koniec wszystko razem.
- [jest] 212–214: wyłączanie sal, okludery, kafelki nawigacji. [+] Dodać LOD/visibility ranges; nie ograniczać widoczności sztucznie — duże widoki optymalizować, nie usuwać.
