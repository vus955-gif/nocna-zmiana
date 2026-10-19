# Nagrody sekretów — trzy poziomy wartości, trwałe bonusy, unikalne wykończenia i modyfikacje broni

> Plan wykonawczy. Wykonawca: jeden agent w worktree `close-wings` (gałąź `secrets-rewards` od `pietro-1` @ `3ecb3b6`).
> Źródło: backlog właściciela `docs/backlog-pietro1.md` — **#5** („sekretne pokoje nic nie dają, a często trzeba zużyć zasoby, by je otworzyć — sekret musi dawać nagrodę: boost statystyk, unikalny wygląd broni, trwały bonus"), **#29** („sekrety powinny mieć różne poziomy wartości: małe → ammo/HP, większe → trwałe bonusy, bardzo dobrze ukryte → unikalna broń, alternatywny wygląd, perk albo specjalna modyfikacja"), **#30** (2–3 znaczące modyfikacje broni zamiast procentów), **#31** (ulepszenia widoczne na modelu), **#9** (animacja oglądania broni po ulepszeniu — zostaje i ma działać też dla nagród), **#13** (**trudność i przebudowa ulepszeń ODŁOŻONE** — nagrody mają być addytywne i skromne, bez ruszania cen ulepszeń i Pyłu z wrogów).
> **Bez okien i bez dźwięku** (właściciel pracuje przy komputerze): tylko `--headless`, skrypty. Nic nie trafia na GitHub.

**Cel:** każdy z 27 sekretów Piętra I ma przypisaną nagrodę o jednym z trzech poziomów, **widoczną w pokoju** (eksponat na poduszce pod mosiężną tabliczką, w gablocie lub w żelaznej kasetce; reflektor zapala się w chwili odkrycia), **ogłaszaną** istniejącym banerem sekretu (z dopiskiem poziomu) i osobnym banerem przy odbiorze, **trwałą między nocami** (zapis), **liczoną** na ekranie świtu i na ekranie końca piętra. Każdy sekret, którego otwarcie kosztuje zasoby (spękany mur = race / salwa; żelazne ucho = harpun), oddaje więcej, niż kosztuje. Nagrody nie ruszają katalogu ulepszeń ani Pyłu z wrogów.

**Architektura:** jedno źródło prawdy — `SecretRewards` (`src/world/secret_rewards.gd`): tabela *sekret → poziom, rodzaj, parametr*, kroki bonusów, teksty. Trwały stan: `GameState.secret_rewards` (lista odebranych id; stare zapisy bez pola wczytują się z pustą listą). Bonusy, wykończenia i modyfikacje wchodzą do gry **jedną drogą**: `SecretRewards.effective_levels(game)` = `game.upgrades` + klucze `bonus_*`, `look_<broń>_<id>`, `mod_<id>` — słownik, który i tak krąży przez `Player.apply_upgrades()` → `UpgradeEffects` (liczby), `WeaponHolder.upgrade_levels` → `WeaponLook`/`ViewmodelRig.apply_look()` (wygląd, inspekcja). Dzięki temu nagroda z sekretu zachowuje się jak zakup w terminalu: broń jest oglądana przy następnym dobyciu, wykończenie mistrzowskie składa się z wykończeniem z sekretu.

---

## 1. Inwentarz (stan przed zmianą)

Mechanika: `WorldFeatures` (`src/world/world_features.gd`) buduje sekrety z markerów `secret_*` układu. Marker w **pokoju sekretnym** (za bramą strefy albo fałszywym panelem) liczy się przy **wejściu** do pokoju; marker w pokoju otwartym → luźny kamień (`SecretCache`, E) albo panel w zasięgu 4 m. Zapis: `GameState.secrets` (id markerów), zapisywany od razu (`NightRules.save_progress`). HUD: `WorldHud.banner("Sekret odkryty (n/m)", nazwa sali)` + dźwięk `secret`. Ekran końca piętra (`DemoEnd`) i `FloorCompletion` liczą sekrety; **ekran świtu nie**. Zawartość pokoi sekretnych dziś: 1 punkt łupu „kontener" (NightDirector woli go dla 2–3 artefaktów nocy — więc **czasem** artefakt, zwykle 60 % szansy na losowe pudełko amunicji / apteczkę), 0–1 luźny punkt łupu (60 %), notatka (fabuła), zasadzka (jeden śpiący eksponat → Pył). **Nic trwałego.**

Koszty otwarcia (`LockRules`, `src/props/locks/lock_rules.gd`): **CHAIN** (łańcuch) — strzelba 25 obrażeń w 0,4 s (≈ 1 nabój) **albo 3 ciosy pięścią (za darmo)**; **BOARDS** (deski) — jak łańcuch, 5 ciosów, albo dowolny wybuch; **CRACKED** (spękany mur) — **40 obrażeń wybuchowych w 0,3 s** (salwa ognistej skrzyni) **albo 3 race z 5 m** — to jedyna brama, która realnie zjada rzadkie zasoby (start nocy: 4 race w zapasie); **ROPE** (lina) — 1 nabój sztucera z dowolnej odległości lub pistoletu z 15 m; **HOOK** (żelazne ucho) — 1 harpun (broń z Ameryk, późna).

| Sekret (marker) | Miejsce | Zamek / koszt | Dziś daje | Jak ukryty → poziom |
|---|---|---|---|---|
| `secret_court_1` | Dziedziniec, skrytka pod ladą informacji | luźny kamień (E), za darmo | nic (kamień wypada, pusta nisza) | w holu, na widoku → **mały** |
| `secret_entrance_1` | hol wejściowy, składzik za szatnią | CRACKED (3 race na starcie gry!) | 1 kontener (60 % pudełko) | pierwsza godzina gry, drogi → **średni** |
| `secret_booth_1` | stróżówka 1912 pod kanciapą | CHAIN (pięści: 0) | kontener, luźny, notatka 1912 | za łańcuchem u stóp schodów → **średni** |
| `secret_north_hall_1` | portiernia przy zamurowanych wrotach północnych | ROPE (1 nabój) | kontener, luźny | widoczna żaluzja → **mały** |
| `secret_basement_1` | podziemia, klatka depozytowa archiwum | CHAIN | kontener, luźny | podziemia → **średni** |
| `secret_basement_2` | piwnica Montagu House (studnia, woskowy założyciel) | CRACKED | kontener, luźny, zasadzka (wosk) | zamurowana, głęboko → **wielki** |
| `secret_basement_3` | schron przeciwlotniczy 1940 | HOOK (harpun) | kontener, luźny, zasadzka | stalowe drzwi, późna broń → **wielki** |
| `secret_roof_1` | dach, gołębnik | ROPE | kontener, luźny | dach (późno dostępny) → **średni** |
| `secret_roof_2` | dach, szopa dekarzy nad kładkami | BOARDS | kontener, luźny, notatka | koniec kładek → **wielki** |
| `secret_egypt_1` | Egipt, skład ekspedycji 1898 | CHAIN (pierwszy łańcuch po strzelbie) | kontener, luźny, notatka, skarabeusze | tuż przy trasie → **mały** |
| `secret_egypt_2` | Egipt, serdab (posąg ka) | CRACKED | kontener, zasadzka (mumia) | szczelina w murze grobowców → **średni** |
| `secret_egypt_3` | Egipt, grobowiec kapłana za fałszywymi drzwiami | HOOK | kontener, zasadzka | ucho widać tylko z bliska, harpun z innego skrzydła → **wielki** |
| `secret_assyria_1` | Asyria, magazyn tabliczek | CRACKED | kontener, luźny, zasadzka | → **średni** |
| `secret_assyria_2` | Asyria, klatka lwów królewskich (dół) | ROPE | kontener, luźny, notatka, zasadzka (lew) | lina nad dołem → **mały** |
| `secret_assyria_3` | Asyria, kabina windy towarowej (y −6) | CHAIN | kontener, notatka, zasadzka | podziemia skrzydła → **wielki** (wykończenie) |
| `secret_greece_1` | Grecja, strych nad Bassae | ROPE | kontener, notatka, zasadzka (popiersie) | właz na antresoli → **mały** |
| `secret_greece_2` | Grecja, magazyn skorup | CRACKED | kontener, zasadzka (hoplita) | → **średni** |
| `secret_greece_3` | Grecja, odlewnia za magazynem skorup | HOOK | kontener, zasadzka | **sekret w sekrecie** → **wielki** (modyfikacja) |
| `secret_enlightenment_1` | Oświecenie, zapieczętowane archiwum | ROPE | kontener, luźny, zasadzka (księgi) | → **średni** |
| `secret_enlightenment_2` | Oświecenie, introligatornia (y −6) | BOARDS | kontener, notatka (zagadka darczyńcy), zasadzka | → **średni** |
| `secret_enlightenment_3` | Oświecenie, ukryty gabinet Sloane'a | HOOK | kontener, luźny, zasadzka (wilk) | ucho na regale górnej galerii → **wielki** |
| `secret_asia_1` | Azja, skarbiec płatnerza | CHAIN | kontener, luźny, notatka, zasadzka (zbroja) | → **średni** |
| `secret_asia_2` | Azja, skład wyprawy 1910 (y −6) | CRACKED | kontener, luźny, notatka, zasadzka (lew Fu) | pod Salą Chin → **wielki** |
| `secret_asia_3` | Azja, kaplica dzwonu za ogrodem | ROPE (po Generale) | kontener, luźny, zasadzka | → **średni** |
| `secret_americas_1` | Ameryki, kryjówka za moai (Heńka) | HOOK | kontener, luźny, notatka, zasadzka (jaguar) | moai obraca się po trafieniu w ucho z tyłu cokołu → **wielki** (modyfikacja) |
| `secret_americas_2` | Ameryki, warsztat rzeźbiarzy totemów | CRACKED | kontener, luźny, zasadzka (totem) | → **wielki** (modyfikacja) |
| `secret_americas_3` | Ameryki, magazyn zbiorów z lat 30. (y −6) | BOARDS | kontener, luźny, notatka, zasadzka | pod salą totemów → **wielki** (wykończenie) |

**Lobby** (`LobbySecrets`, poziom demo — `Museum.level_id == &"lobby"` tylko w testach i demie): obraz → komnata z artefaktem „zawsze" i notatką; szyb; krzywa tabliczka → nisza (dziś tylko notatka); gablota na kłódkę (strzał / klucz → artefakt nocy); komplet notatek; składzik → **przystań** (trwała). De facto ma już skalę (artefakt / lore / przystań). **Poza zakresem tej zmiany** — gra główna to Piętro I; lobby zostaje bez tabeli nagród (do rozważenia, gdyby demo wróciło do menu).

## 2. Projekt

### 2.1 Trzy poziomy

| Poziom | Nazwa w grze | Co daje | Prezentacja w pokoju | Ile |
|---|---|---|---|---|
| **mały** (`SMALL`) | **Schowek** | **sakiewka Pyłu** (+20, raz na zawsze) + **zapas co noc** w pokojach sekretnych: 1 pudełko amunicji (rodzaj wg skrzydła; amunicja do broni, której strażnik nie ma, zamienia się w znaną — jak każdy łup) + 1 apteczka | żelazna kasetka na podłodze (otwarta klapa, sakiewka w środku); zapas leży obok | 5 (4 z zapasem, dziedziniec bez) |
| **średni** (`MEDIUM`) | **Znalezisko** | **trwały bonus**, jeden krok: +10 maks. zdrowia · +10 maks. kondycji · +20 s baterii latarki · +10 % zapasu amunicji każdej broni · Pył przyciągany z 1,5 m dalej | cokół z aksamitną poduszką, eksponat tematyczny, mosiężna tabliczka z nazwą; wąski reflektor zapala się przy odkryciu | 11 |
| **wielki** (`GREAT`) | **Skarb muzeum** | **unikalne wykończenie** jednej broni (8 — po jednym na każdą broń palną i paralizator) **albo modyfikacja** zmieniająca działanie broni (3) | gablota (drewniany korpus, szkło, mosiężna listwa) z eksponatem na poduszce i tabliczką; reflektor | 11 |

Zasady: nagroda leży **w pokoju sekretu** (przy markerze `secret_*`), odbiera się ją klawiszem E (`SecretRewardDisplay` — `Interactable`); odebrana raz **zostaje odebrana na zawsze** (`GameState.secret_rewards`); eksponat znika z poduszki, cokół z tabliczką i reflektor **zostają** (muzealny ślad: „to tu było"). Odkrycie sekretu (wejście do pokoju / wyjęcie kamienia) zapala reflektor nad nagrodą (`reveal()`) i dopisuje do baneru sekretu linię „W środku czeka: Znalezisko". Odbiór: dźwięk `artifact`, baner „NAGRODA SEKRETU · SKARB MUZEUM / Fajans i złoto / Wykończenie strzelby…", zapis od razu, a bonus/wykończenie/modyfikacja działa **natychmiast** (`Player.apply_upgrades(effective_levels)` → broń z nowym wykończeniem jest oglądana przy następnym dobyciu, jak po zakupie — #9).

### 2.2 Przypisanie (27 sekretów)

| Sekret | Poziom | Rodzaj | Nagroda (nazwa) | Temat |
|---|---|---|---|---|
| `secret_court_1` | mały | sakiewka (bez zapasu — pokój otwarty) | Napiwki spod lady informacji | hol |
| `secret_north_hall_1` | mały | sakiewka + zapas (naboje, apteczka) | Kasetka portiera | portiernia |
| `secret_egypt_1` | mały | sakiewka + zapas (śrut, apteczka) | Sakiewka ekspedycji 1898 | skrzynie ekspedycji |
| `secret_assyria_2` | mały | sakiewka + zapas (śrut, apteczka) | Zapasy treserów lwów | klatka |
| `secret_greece_1` | mały | sakiewka + zapas (naboje, apteczka) | Skrytka gołębiarza | strych Turka |
| `secret_entrance_1` | średni | zapas +10 % | Ładownica zostawiona w szatni | szatnia (po przeglądzie: było bateria +20 s, patrz reguła kosztów) |
| `secret_booth_1` | średni | kondycja +10 | Manierka stróża Kopcia | 1912 |
| `secret_basement_1` | średni | bateria +20 s | Zapasowe ogniwa z depozytu | depozyt (po przeglądzie: było zapas +10 %) |
| `secret_roof_1` | średni | bateria +20 s | Lampa karbidowa gołębiarza | gołębnik |
| `secret_egypt_2` | średni | zdrowie +10 | Amulet skarabeusza | serdab |
| `secret_assyria_1` | średni | zdrowie +10 | Tabliczka z zaklęciem ochronnym | klinowe |
| `secret_greece_2` | średni | kondycja +10 | Lekyt z oliwą atlety | skorupy |
| `secret_enlightenment_1` | średni | magnet Pyłu +1,5 m | Magnetyt z gabinetu osobliwości | archiwum |
| `secret_enlightenment_2` | średni | zapas +10 % | Fartuch introligatora | introligatornia |
| `secret_asia_1` | średni | zdrowie +10 | Kolczuga płatnerza | skarbiec |
| `secret_asia_3` | średni | kondycja +10 | Dzwonek świątynny | kaplica |
| `secret_basement_2` | wielki | wykończenie **pistoletu** `founder` | Pistolet fundatora (heban i srebro) | Montagu House |
| `secret_basement_3` | wielki | wykończenie **paralizatora** `warden` | Wydanie obrony przeciwlotniczej (khaki, fosfor) | schron 1940 |
| `secret_roof_2` | wielki | wykończenie **rakietnicy** `signal` | Sygnałówka dekarzy (pomarańczowa emalia, mosiądz) | dach |
| `secret_egypt_3` | wielki | wykończenie **strzelby** `faience` | Fajans i złoto | grobowiec kapłana |
| `secret_assyria_3` | wielki | wykończenie **kartaczownicy** `balawat` | Brązy z Balawat (brąz, lapis) | winda / Balawat |
| `secret_enlightenment_3` | wielki | wykończenie **sztucera** `sloane` | Instrument Sloane'a (mahoń, mosiądz) | gabinet |
| `secret_asia_2` | wielki | wykończenie **ognistej skrzyni** `lacquer` | Laka i złoto (urushi, maki-e) | wyprawa 1910 |
| `secret_americas_3` | wielki | wykończenie **harpunnika** `scrimshaw` | Scrimshaw wielorybników (kość, smoła) | magazyn Pacyfiku |
| `secret_greece_3` | wielki | **modyfikacja sztucera** `rifle_peep` | Przeziernik odlewnika | odlewnia (brąz) |
| `secret_americas_1` | wielki | **modyfikacja harpunnika** `harpoon_line` | Linka zwrotna | wielorybnicy, kryjówka Heńka |
| `secret_americas_2` | wielki | **modyfikacja strzelby** `shotgun_choke` | Czok rzeźbiarza | narzędzia rzeźbiarzy |

Reguła kosztów (test pilnuje): sekret za **CRACKED** lub **HOOK** → co najmniej **średni**; za **ROPE/CHAIN/BOARDS** → mały lub wyżej; mały zwraca co noc pudełko + apteczkę, czyli więcej niż 1 nabój / 1 śrut, który kosztuje lina czy łańcuch.

**Po przeglądzie: koszt ≤ wartość, nie tylko „poziom ≥ średni”.** Testy: `test_a_secret_that_costs_resources_pays_back_a_permanent_reward` i `test_no_secret_pays_less_than_its_gate_costs`. Jedna zgrubna skala (cena Pyłu w terminalu za ten sam krok): *wartość* — sakiewka 20; znalezisko = cena 1. poziomu ulepszenia × (krok ÷ efekt poziomu): zdrowie 12,5 · kondycja 10 · zapas 12 · magnet 12,5 · **bateria 6,7 (najsłabszy krok)**; skarb 25. *Koszt* najdroższej bramy sekretu (liczone wszystkie bramy przy pokoju: magazyn skorup ma dwie, spękany mur i ucho do odlewni): CHAIN/BOARDS/BOLT 0 (pięści) · ROPE 3 (nabój sztucera) · HOOK 5 (harpun) · **CRACKED 8** (3 z 4 startowych rac). Wcześniej najsłabszy krok (bateria +20 s, szatnia w hallu) siedział za najdroższą wczesną bramą; zamieniony z klatką depozytową (łańcuch, za darmo): szatnia daje zapas amunicji +10 % (ładownica zostawiona przy wejściu), depozyt ogniwa. Sumy kroków bez zmian (zdrowie 3, kondycja 3, bateria 2, zapas 2, magnet 1).

### 2.3 Modyfikacje (3) — zmieniają działanie, nie procenty

| Id | Broń | Działanie | Implementacja (dane) | Widok na modelu |
|---|---|---|---|---|
| `shotgun_choke` | strzelba | **śrut i breneka przebijają pierwszy cel** i trafiają następny za nim (lekki eksponat nie osłania ciężkiego) | `WeaponData.pierce_targets = 2` (breneka dziedziczy z `alt_profile`) | mosiężny kołnierz czoka na wylocie luf (`Muzzle`) |
| `rifle_peep` | sztucer | **celny strzał trafia w ogniwo**: łańcuchy i deski puszczają od jednego naboju z dowolnej odległości (dziś: strzelba z bliska / pięści) | `WeaponData.lock_breaker = true` → `DamageInfo.lock_breaker` → `LockRules.verdict` CHAIN/BOARDS → `OPEN` | przeziernik (pierścień na słupku) na komorze za zamkiem |
| `harpoon_line` | harpunnik | **harpun wbity w ścianę wraca po lince** do zapasu (chybienie nic nie kosztuje; trafienia bez zmian) | `WeaponData.line_return = true`; `Harpoon` w fazie `STUCK` w ścianie po `RETURN_TIME` 1,2 s → `gun.add_ammo(harpoons, 1)`, dźwięk `hook_pull` | szpulka linki z turkusową nicią przy kołowrotku |

### 2.4 Wykończenia (8) — `WeaponLook.LOOKS`

Wykończenie to **warstwa materiałowa** nakładana w kodzie na model pierwszoosobowy (jak wykończenie mistrzowskie, które podmienia zestaw tekstur `<model>_master` i dodaje połysk): barwa (mnoży albedo), gładkość, metaliczność, kolorowy rim, akcent emisyjny na części-sygnaturze (`WeaponLook.SIGNATURE`). Składa się z mistrzostwem: bazowe materiały → (tekstury `_master` + połysk, gdy wszystkie ulepszenia na maks.) → (barwa i akcent wykończenia). Gdy w `assets/textures` pojawi się zestaw `<model>_<look>` (wypalony w Blenderze), ładowany jest zamiast barwienia — ścieżka na później, bez renderów teraz. Dłonie i rękawy nigdy nie są barwione (`HANDS_NOT_POLISHED`).

| Id | Broń | Barwa (mnożnik albedo) | Gładkość × | Metal | Akcent (emisja sygnatury, rim) |
|---|---|---|---|---|---|
| `faience` | strzelba | (0,55, 0,85, 0,85) turkus glazury | 0,6 | +0,1 | złoto (1,0, 0,8, 0,35) |
| `founder` | pistolet | (0,5, 0,47, 0,47) heban | 0,7 | +0,2 | srebro (0,9, 0,93, 1,0) |
| `warden` | paralizator | (0,75, 0,72, 0,5) khaki | 1,0 | 0 | fosfor (0,6, 1,0, 0,5) |
| `signal` | rakietnica | (1,0, 0,62, 0,3) pomarańczowa emalia | 0,6 | 0 | mosiądz (0,95, 0,75, 0,35) |
| `balawat` | kartaczownica | (0,85, 0,65, 0,4) brąz | 0,8 | +0,2 | lapis (0,3, 0,45, 1,0) |
| `sloane` | sztucer | (0,8, 0,55, 0,45) mahoń | 0,7 | 0 | mosiądz |
| `lacquer` | ognista skrzynia | (0,85, 0,3, 0,25) czerwona laka | 0,5 | 0 | złoto |
| `scrimshaw` | harpunnik | (0,95, 0,92, 0,82) kość | 0,9 | 0 | morski turkus (0,2, 0,78, 0,85) |

### 2.5 Bilans (dlaczego skromnie)

Wszystkie 11 znalezisk razem: **+30 zdrowia** (3 kroki; pełny `health` z katalogu daje +60), **+30 kondycji** (katalog +60), **+40 s baterii** (katalog +120 s), **+20 % zapasu** (katalog +50 %), **+1,5 m magnetu** (katalog +6 m). Czyli komplet sekretów ≈ **pół poziomu–poziom** każdego ulepszenia strażnika, rozłożone na 11 ukrytych pokoi w 6 skrzydłach i na dachu — zauważalne dla kompletysty, niewidoczne w pierwszych nocach, bez wpływu na ceny i tempo Pyłu (#13 odłożone). Sakiewki: 5 × 20 = **100 Pyłu raz na całą grę** (≈ cena jednego ulepszenia średniego); zapasy nocne: 4 pudełka + 4 apteczki (portiernia, skład ekspedycji 1898, klatka lwów, strych Turka) **za bramami daleko od siebie** — mniej niż jedna walka z zasadzką w tych samych pokojach. **To jedyny powtarzalny dochód nagród** (reszta jest jednorazowa); decyzja widoczna dla właściciela, zostaje tak jak jest — do ewentualnej zmiany po grze w oknie. Skarby: 8 wykończeń **bez wpływu na liczby**; 3 modyfikacje zmieniają sposób gry, nie moc: przebicie śrutem (łańcuchy wrogów), sztucer otwierający łańcuchy z dystansu (eksploracja, oszczędność śrutu — po znalezieniu sekretu w sekrecie), zwrot chybionych harpunów (komfort, zero przewagi w walce). Nic z tego nie skraca walk ze strażnikami.

### 2.6 Ogłaszanie i liczenie

- **Odkrycie** (istniejący baner): „SEKRET ODKRYTY (3/27) / Serdab / W środku czeka: Znalezisko" (bez dopisku, gdy nagroda już odebrana).
- **Odbiór**: „NAGRODA SEKRETU · ZNALEZISKO / Amulet skarabeusza / +10 do maksymalnego zdrowia." Dla wykończenia / modyfikacji — baner + inspekcja broni przy dobyciu (glint na nowej części).
- **Świt** (`DawnScreen`): nowa linia „Sekrety: 7/27 (tej nocy +2) · nagrody 5/27" (tylko Piętro I).
- **Koniec piętra** (`DemoEnd`): obok „Sekrety n/m" — „Nagrody sekretów k/m".
- Plan papierowy bez zmian (sekrety już ma jako znaczki).

### 2.7 Gdzie stoi wystawa (po przeglądzie)

Marker `secret_*` mówi tylko „mniej więcej tu”; wystawa stoi tam, gdzie ją ustawi `RewardSpot.place()` (`src/world/reward_spot.gd`, czysta geometria na `LevelLayout`): **na podłodze pokoju** (nie na wysokości markera: marker dziedzińca leżał 30 cm wyżej na froncie lady informacji, kasetka wisiała w powietrzu i tkwiła 13 cm w ladzie), **odsunięta od brył kolidujących** najkrótszą drogą (twierdzenie o osiach rozdzielających, luz 12 cm; pomijane są podłogi i bryły wyżej niż 1,6 m), **tabliczką do najbliższego wejścia** pokoju (otwór, który nie prowadzi dalej do innego pokoju sekretnego — chyba że to jedyny), obrócona do pełnego ćwierć obrotu (równo ze ścianami, tabliczka najwyżej 45° od drogi wejścia) — wcześniej wszystkie tabliczki patrzyły na −Z, w 14 z 27 pokoi bez drzwi po tej stronie, w dwóch drzwi były tuż za plecami. Gdy przed tabliczką stoi lada albo regał (dziedziniec: kasetka za ladą), wystawa obraca się do następnej strony z 0,8 m wolnej podłogi do czytania. Zapas nocny leży obok wystawy w jej układzie (obraca się razem z nią). Testy: `test_reward_spots.gd` (27 wystaw: podłoga, brak przecięć z bryłami kolizji `LevelKit`, w pokoju, poza strefą drzwi 0,8 m, tabliczka ku wejściu, wolna podłoga przed nią) i `test_world_rewards.gd` (rzeczywista scena; zapasy w pokoju i poza bryłami).

## 3. Pliki

| Plik | Zmiana |
|---|---|
| `src/world/secret_rewards.gd` | **nowy**: `SecretRewards` — `Tier`, `TABLE`, kroki (`HEALTH_STEP` 10, `STAMINA_STEP` 10, `BATTERY_STEP` 20, `POCKETS_STEP` 0,10, `MAGNET_STEP` 1,5, `POUCH_DUST` 20), `entry(id)`, `ids()`, `tier_of`, `tier_key`, `name_key`, `desc_key`, `is_claimed`, `claim`, `bonuses(game)`, `effective_levels(game)`, `stash(id)`, `color(tier)` |
| `src/world/secret_reward_display.gd` | **nowy**: `SecretRewardDisplay` (`Interactable`) — kasetka / cokół / gablota, eksponat tematyczny (kod), tabliczka (`Label3D`), reflektor; `reveal()`, `set_taken()`, sygnał `taken(id)`; `footprint(tier)`; bez `_process` do odkrycia sekretu i po odbiorze |
| `src/world/reward_spot.gd` | **nowy** (po przeglądzie): `RewardSpot.place()` — podłoga, odsunięcie od brył, obrót tabliczki do wejścia (§2.7) |
| `src/world/world_features.gd` | budowa wystaw przy markerach, `reveal` przy odkryciu, `claim_reward()`, zapas nocny (`Pickup` + `RunState.used` `stash_<id>_<n>`), dopisek poziomu w banerze, `found_tonight`, `rewards_claimed/total` |
| `src/state/game_state.gd` | `secret_rewards: Array[StringName]`, `claim_reward()`, `to_dict/from_dict/reset` (wersja bez zmian: pole opcjonalne) |
| `src/progression/upgrade_effects.gd` | klucze `bonus_*` w `max_health`, `stamina_max`, `battery_capacity`, `reserve_factor`, `dust_magnet_radius`; modyfikacje w `apply_to_weapon` (`has_mod`) |
| `src/weapons/weapon_data.gd` | `lock_breaker: bool`, `line_return: bool` (grupy Pierce / Harpoon) |
| `src/combat/damage_info.gd` | `lock_breaker: bool` |
| `src/weapons/weapon_holder.gd` | `info.lock_breaker = data.lock_breaker` przy tworzeniu trafienia |
| `src/props/locks/lock_rules.gd` | CHAIN/BOARDS: `info.lock_breaker` → `OPEN` |
| `src/weapons/harpoon.gd` | `line_return`: po wbiciu w ścianę wraca po `RETURN_TIME` do zapasu |
| `src/weapons/weapon_look.gd` | `LOOKS`, `MODS`, `look_of()`, `mods_of()`, `has_mod()`, `key()` z wykończeniem i modyfikacjami, `LOOK_PREFIX`/`MOD_PREFIX` |
| `src/weapons/viewmodel_rig.gd` | `apply_look`: części modyfikacji (`_mod_parts`, glint na nowych), `_refresh_finish()` składające mistrzostwo z wykończeniem (`look_material()`), `look()`; akcent na sygnaturze |
| `src/progression/loadout.gd`, `src/game/museum.gd` | `SecretRewards.effective_levels(game)` zamiast `game.upgrades`; świt przekazuje liczby sekretów |
| `src/ui/dawn_screen.gd`, `src/ui/demo_end.gd` | linia sekretów / nagród |
| `locale/strings.csv` | `REWARD_TIER_*`, `REWARD_CAPTION`, `SECRET_TIER_HINT`, `REWARD_<SEKRET>_NAME/_DESC` ×27, `NIGHT_DAWN_SECRETS`, `END_FLOOR1_REWARDS`, `LOOK_*_NAME` (dopisek na tabliczce) |
| testy | `tests/unit/test_secret_rewards.gd` (nowy), `test_game_state_floor1.gd`, `test_upgrade_effects.gd`, `test_lock_rules.gd`, `test_weapon_look.gd`, `tests/integration/test_locks.gd`, `test_harpoon.gd`, `test_weapon_look_rig.gd`, `test_world_rewards.gd` (nowy, pełna scena Piętra I), `test_demo_end.gd`; po przeglądzie `tests/unit/test_reward_spots.gd` (nowy) |

## 4. Zadania

- [x] **0. Plan** (ten dokument). Commit `1a75603`.
- [x] **1. Dane i zapis (TDD)**: `test_secret_rewards.gd` (każdy marker `secret_*` Piętra I ma wpis; ≥ 3 na poziom; CRACKED/HOOK ≥ średni; sumy kroków w granicach §2.5; teksty PL/EN; wykończenia wskazują istniejące bronie; `claim` raz; `effective_levels` scala) → `SecretRewards`, `GameState.secret_rewards` (round-trip, stary zapis bez pola), teksty. Commit `d383a05`.
- [x] **2. Liczby i modyfikacje (TDD)**: `UpgradeEffects` z `bonus_*`; `WeaponData`/`DamageInfo`/`LockRules`/`Harpoon` dla trzech modyfikacji; `Loadout`/`Museum` przez `effective_levels`; testy jednostkowe + `test_locks` (sztucer z przeziernikiem zrywa łańcuch jednym strzałem z 12 m; bez — iskry i podpowiedź) + `test_harpoon` (chybiony harpun wraca do zapasu po 1,2 s; bez linki zostaje w ścianie). Commit `ec8e57d`.
- [x] **3. Wygląd (TDD)**: `WeaponLook.LOOKS/MODS/look_of/mods_of/key`, `ViewmodelRig` — części modyfikacji (`_mod_part`: kołnierz czoka za czokiem ulepszenia, przeziernik na chwycie za zamkiem, szpulka przed kołowrotkiem; glint na nowej części), wykończenie (`look_material`) składane z mistrzostwem (`_set_finish`) i zdejmowane; `test_weapon_look.gd`, `test_weapon_look_rig.gd`. Commit `874dee4`.
- [x] **4. Wystawa w pokoju i świat (TDD)**: `SecretRewardDisplay` (kasetka / cokół / gablota, 11 eksponatów znalezisk, sakiewka, kaseta prezentacyjna wykończenia, okucie modyfikacji, tabliczka, reflektor), `WorldFeatures` (budowa, reveal, odbiór, zapas nocny, baner z poziomem), `test_world_rewards.gd` na pełnej scenie Piętra I (7 testów). Commit `a289378`.
- [x] **5. Świt i koniec piętra**: `found_tonight`, `DawnScreen.play(..., secrets)` z linią sekretów, `DemoEnd` nagrody; `test_dawn_screen.gd`, `test_demo_end.gd`. Commit `a928852`.
- [~] **6. Pełny zestaw testów, `git merge pietro-1`, ponowny pełny zestaw, raport.** Pełny zestaw przed scaleniem: 2238/1 (jedyna czerwona to asercja dopisana w trakcie biegu, naprawiona w `3e7f59a`: `test_world_rewards` po poprawce 15/0). `git merge pietro-1` → `36be174` bez konfliktów (pietro-1 zmienił tylko wschód i Węża, nic z naszych plików). **Pełny zestaw po scaleniu przerwany na polecenie kontrolera** (limit użycia) — do powtórzenia.

- [x] **7. Poprawki po przeglądzie** (gałąź `secrets-rewards`, worktree `close-wings`): (1) wystawy na podłodze i poza bryłami, test układu wszystkich 27 (`ffe9bb1`); (2) tabliczki do najbliższego wejścia (`ffe9bb1`); (4) koszt ≤ wartość, zamiana szatnia ↔ depozyt, `_gate_kinds` liczy wszystkie bramy sekretu, (6) teksty nagród testowane względem stałych (PL i EN), suma bonusów liczona z tabeli (`6c47595`); (7) wykończenie mnoży albedo części zamiast je zastępować, (8) ciche `if x != null` w testach zamienione na asercje, (9) `set_process(false)` do odkrycia, pomocnik `_fitting_piece` (`d50436f`); przy okazji znaleziony i naprawiony błąd: **pokrywa kasetki otwierała się w dół, do wnętrza skrzynki** (`LID_OPEN` ze złym znakiem; test mierzy wysokość płyty pokrywy nad zawiasem). (3) i (5) to decyzje, nie kod: patrz §5 i §2.5.

## 5. Do sprawdzenia w oknie (gdy właściciel pozwoli)

- [ ] Czytelność **wystaw** w pokojach sekretnych: kasetka / cokół / gablota rozpoznawalne od wejścia; reflektor nie prześwieca przez ścianę do sali publicznej (wąski stożek 26°, zasięg 3,2 m — jak `Kit.glow`); tabliczka czytelna z 1,5 m.
- [ ] Eksponaty tematyczne (amulet, lekyt, manierka, ładownica, magnetyt, dzwonek, pistolet, szpulka, przeziernik, czok, próbki wykończeń) — skala i kolor na aksamicie; czy nie wyglądają jak power-upy.
- [ ] **Wykończenia na modelach pierwszoosobowych**: każda z 8 barw w trzech światłach (księżyc, lampy, czerwone awaryjne) — czy barwienie albedo nie „brudzi" drewna i stali (jeśli tak: wypalić zestawy `<model>_<look>` w Blenderze, ścieżka już obsłużona); czy akcent na sygnaturze nie razi; złożenie z mistrzostwem (`U` w `weapons_dev`).
- [ ] **Części modyfikacji** na modelach: kołnierz czoka na lufach strzelby (nie przecina luf, nie zasłania muszki), przeziernik na komorze sztucera (nie koliduje z zamkiem w cyklu i przeładowaniu, nie wchodzi w rękę), szpulka linki przy kołowrotku harpunnika — podczas idle, biegu, strzału, przeładowania, inspekcji; przy FOV 90–110.
- [ ] Inspekcja po odbiorze skarbu: glint trafia w nową część; przy wykończeniu (bez nowej części) glint na środku broni.
- [ ] Zapas nocny w pokojach małych sekretów: pudełka nie wchodzą w kasetkę ani w skrzynie.
- [ ] Baner świtu z linią sekretów — mieści się na karcie 16:9 i 21:9.
- [ ] **Wystawy to dziś same `Area3D` (E), bez pełnego kolizora**: kamera i strażnik wchodzą w szklaną gablotę i przechodzą przez cokół. **Decyzja:** pełny kolizor (cokół + gablota; wystawy nie są źródłem nawigacji, więc wrogowie ominą je bez przeliczania ścieżek, ale w wąskim pokoju sekretnym 2,5 m kolizor zwęża przejście) **czy zostawić przenikalne** (nic nie blokuje, ale gablota jest „duchem”). Rekomendacja: kolizor tylko na cokole i kasetce (nie na szkle), w pokojach szerszych niż 3 m; w wąskich zostaje sama `Area3D`.
- [ ] **Ustawienie wystaw po poprawkach**: kasetka dziedzińca stoi za ladą informacji (na podłodze, tabliczką na wschód), obok kamienia; każda wystawa patrzy tabliczką na najbliższe wejście i jest czytelna od progu (kąt do drzwi do 45°); plinty ustawione równo ze ścianami; zapas obok kasetki nie wchodzi w ścianę ani w skrzynie.
- [ ] **Pokrywa kasetki**: otwiera się w górę i lekko za pion (nie opada do skrzynki); efekt „odbicia” (`TRANS_BACK`) nie wchodzi w ścianę za kasetką.
- [ ] Teksty po zamianie szatnia ↔ depozyt: „Ładownica zostawiona w szatni” (+10 % zapasu) i „Zapasowe ogniwa z depozytu” (+20 s) pasują do eksponatów (zwinięta ładownica / trzy ogniwa z czerwonymi etykietami).

## 6. Stan prac / co dalej

- 2026-10-10: plan spisany; inwentarz (§1) zrobiony na kodzie `pietro-1 @ 3ecb3b6`.
- 2026-10-10 (wieczór): **zadania 0–5 wykonane** na gałęzi `secrets-rewards` (worktree `close-wings`), po jednym commicie (`1a75603`, `d383a05`, `ec8e57d`, `874dee4`, `a289378`, `a928852`, `3e7f59a`), scalono `pietro-1` (`36be174`, czysto). Zrobione: tabela 27 nagród + zapis, bonusy i 3 modyfikacje w liczbach, 8 wykończeń i okucia modyfikacji na modelach, wystawy w pokojach + odbiór + zapas nocny + banery, świt i ekran końca. Pełny zestaw przed scaleniem: 2238 zielonych, 1 czerwony naprawiony (`3e7f59a`).
- 2026-10-18: pełny zestaw po scaleniu `pietro-1` (`36be174`): **2298 zielonych, 0 czerwonych**. Przegląd (review-secrets) wskazał 9 poprawek.
- 2026-10-19: **poprawki po przeglądzie wykonane** (zadanie 7, commity `ffe9bb1`, `6c47595`, `d50436f`, plan): wystawy na podłodze i poza bryłami (`RewardSpot`), tabliczki do najbliższego wejścia, koszt ≤ wartość (szatnia ↔ depozyt), teksty nagród testowane względem stałych, mnożenie albedo w wykończeniu, `set_process(false)` do odkrycia, liczone asercje zamiast cichych `if`, pomocnik fitingów, do tego naprawiona pokrywa kasetki (otwierała się w dół). `git merge pietro-1`: już scalone (`40323a4`), bez zmian. **Pełny zestaw: 2311 zielonych, 0 czerwonych** (2298 + 13 nowych: `test_reward_spots` 6, `test_secret_rewards` +3, `test_world_rewards` +3, `test_weapon_look_rig` +1). Znane czerwone testy: **brak**.
- **Dokładny następny krok:** nic do kodu. Gałąź `secrets-rewards` gotowa do scalenia do `pietro-1` (kontroler); potem lista „Do sprawdzenia w oknie” (§5), w tym decyzja o kolizorach wystaw.
- Dalej (poza zakresem tej zmiany, do decyzji właściciela): wypalone zestawy tekstur `<model>_<look>` w Blenderze, gdyby barwienie albedo nie wyglądało dobrze w oknie (ścieżka ładowania gotowa); nagrody w lobby (poziom demo); skrót do przystani jako nagroda (odłożone — wymaga zmian układu).
