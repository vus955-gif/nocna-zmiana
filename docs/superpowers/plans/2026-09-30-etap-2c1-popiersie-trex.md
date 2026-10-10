# Etap 2c-1 — lewitujące popiersie i szkielet T-Reksa: plan implementacji

> Stan: 30 września 2026. Wykonawca: Claude (gałąź robocza w osobnym worktree, równolegle z 2a, 2b-1 i potokiem grafiki).
> Liczby autorytatywne: `docs/superpowers/specs/2026-09-30-etap-2-projekt.md`, sekcje 8.1, 8.2 i 14. Tam, gdzie ten plan je doprecyzowuje albo zmienia, patrz „Odstępstwa od projektu” na końcu.

**Cel:** dwa nowe eksponaty grywalne w arenie deweloperskiej, na poziomie jakości wydania: dystansowe **popiersie** z wielokrotnego użytku **pociskiem** (`Projectile`) oraz **walka z bossem** — szkieletem T-Reksa z czerwonym kryształem, trzema fazami, szarżą, ogonem, rykiem i śmiercią rozsypującą kości.

**Architektura:** jak w 1a — węzły buduje kod, `.tscn` to korzeń plus skrypt, czysta logika w klasach `RefCounted` testowanych bez sceny. Popiersie dziedziczy po `Enemy` (jedyna zmiana w bazie: haczyk grawitacji). T-Rex to **osobna klasa** `TRex extends CharacterBody3D` (siostra `Enemy`, nie potomek): jego maszyna stanów, ruch bez siatki nawigacji i strefy trafień są zbyt odmienne, by wciskać je w `EnemyBrain`. Korzysta ze wspólnych `DamageInfo`, `Hurtbox`, `Health`, `Fx`, `Sfx`, `Events`.

**Pliki (wszystkie nowe, poza wymienionymi zmianami):**

| Plik | Odpowiada za |
|---|---|
| `src/combat/projectile.gd` | `Projectile`: pocisk (prędkość, promień, czas życia, grawitacja opcjonalnie), przemiatanie kulą co klatkę fizyki, obrażenia przez `take_damage`, rozprysk na ścianie, własny hurtbox 0,25 m (1 trafienie niszczy), jasny rdzeń + smuga + światło |
| `src/enemies/bust.gd` | `Bust` (`KIND = &"bust"`, marmur): lewitacja, dystans, zapowiedź pęknięć, strzał odłamkiem, upadek po ogłuszeniu |
| `src/enemies/trex/trex_brain.gd` | `TRexBrain`: czysta maszyna stanów bossa, fazy, odnowienia, reguła obrażeń |
| `src/enemies/trex/trex_skeleton.gd` | `TRexSkeleton`: szara bryła szkieletu z prymitywów (czaszka, żuchwa, szyja, kręgosłup, żebra, ręce, miednica, nogi, ogon), kryształ ze światłem, pozy i animacja proceduralna, strefy trafień, rozpad na fizyczne kości |
| `src/enemies/trex/trex_zone.gd` | `TRexZone`: odbiorca trafień jednej strefy (kryształ / kości) — broń scala śruciny per odbiorca, więc strefy muszą mieć osobnych odbiorców |
| `src/enemies/trex/trex.gd` | `TRex`: węzeł bossa — ruch, szarża, ogon, ryk (przywołanie przez callback, gruz), ogłuszenie, potknięcie, śmierć, sygnały |
| `src/enemies/trex/debris_drop.gd` | `DebrisDrop`: cień na podłodze, spadający głaz, obrażenia w chwili upadku |
| `src/enemies/trex/boss_dev.gd` + `.tscn` | `BossDev`: arena deweloperska — hala 36×44 m, 4 kolumny, postument, strażnik z bronią, klawisze |
| `tools/run_boss.sh` | uruchomienie areny (cicho, `SOUND=1` z dźwiękiem) i scenariusza zrzutów (`--shots`) |
| `tests/scenarios/boss_scenario.gd` + `.tscn` | zrzuty ekranu do `tests/_out/boss/` + pomiar FPS |
| `tests/unit/test_trex_brain.gd`, `tests/integration/test_projectile.gd`, `test_bust.gd`, `test_trex.gd`, `test_debris_drop.gd`, `test_boss_dev.gd` | testy |
| **zmiana** `src/enemies/enemy.gd` | haczyk `_apply_gravity(delta)` zamiast dwóch linii grawitacji |
| **zmiana** `src/core/events.gd` | sygnały `boss_awakened(boss)`, `boss_defeated(boss)` |
| **zmiana** `src/fx/sfx.gd` | nowe nazwy w `SOUNDS` (wczytywane z góry) |
| **zmiana** `tools/sfx/gen_sfx.py` + `assets/sfx/*.wav` | nowe dźwięki; istniejące pliki bajt w bajt bez zmian |

## Konwencje

Jak w planie 1a: tabulatory, typowanie statyczne, komentarze po angielsku, teksty dla gracza po polsku, transformacja ustawiana **przed** `add_child` (interpolacja fizyki), `bash tools/run_tests.sh` zielony po każdym zadaniu bez linii `ERROR`/wycieków, commit po każdym zadaniu ze stopką `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, dodawanie do gita tylko własnych plików. Okienkowe uruchomienia zawsze z `--audio-driver Dummy`.

---

## Zadanie 1: ten plan

Commit samego dokumentu.

## Zadanie 2: `Projectile`

**Zachowanie:**
- Konfiguracja przed `add_child`: `velocity` (kierunek × `speed`), `radius` (0,2 m), `lifetime` (6 s), `gravity` (0), `hit_mask` (`WORLD | PLAYER`), `damage: DamageInfo`, `material_kind` (rozprysk), `exclude` (RID strzelca), `light_energy`.
- Co klatkę fizyki: `cast_motion` kulą o promieniu `radius` wzdłuż ruchu; przy kolizji `get_rest_info` w punkcie niebezpiecznym → kto ma `take_damage` (strażnik) dostaje kopię `DamageInfo` z kierunkiem lotu i punktem; w przeciwnym razie to geometria → `Fx.impact` materiału + 2 odłamki + dźwięk `shard_break`, zniszczenie.
- Hurtbox 0,25 m (warstwa `HURTBOX`, odbiorca = pocisk): każde trafienie bronią niszczy pocisk (rozprysk, `hit_landed(…, killed = true)` → czerwony znacznik trafienia u gracza).
- Wygląd: jasny, wydłużony odłamek (emisja), poświata, smuga (dwie skrzyżowane wstęgi z zanikającą alfą, blending addytywny), małe światło punktowe bez cieni. Siatki i materiały współdzielone (statyczna pamięć) — dziesiątki pocisków to tylko węzły.
- Sygnał `finished(reason)` (`HIT`, `WALL`, `SHOT`, `EXPIRED`) — do testów i statystyk.

**Testy (`test_projectile.gd`):** trafia strażnika za 12 i znika; o ścianę znika bez obrażeń; strzał w hurtbox (promień `Hitscan.ray`) niszczy go; wygasa po czasie życia; nie trafia w strzelca (exclude); transformacja ustawiona przed wejściem do drzewa.

## Zadanie 3: `Bust`

**Liczby (8.1):** zdrowie 45, twarz = słaby punkt (×2 z danych broni), lewitacja 1,6 m nad podłogą (od spodu cokołu), bujanie ±0,15 m, dystans 8–14 m, cofanie < 6 m, 3,0 m/s, zapowiedź 0,7 s, odłamek 9 m/s za 12, co 2,4 s, ogłuszenie paralizatorem 3 s (upada, można dobić), marmur, Pył 5.

**Rozwiązanie:**
- Bazowy `Enemy` + nadpisane: `_chase_direction` (utrzymanie dystansu: dalej niż 14 m → podejście przez nawigację bazy; 8–14 m → powolne krążenie; 6–8 m → cofanie z połową prędkości; < 6 m → pełne cofanie z odchyleniem w bok, żeby nie wbijać się w róg; bez linii wzroku → podejście), `_on_strike` (strzał tylko przy czystej linii od twarzy do klatki piersiowej celu w chwili wystrzału), `_apply_gravity` (unoszenie sprężyną nad podłogą z promienia w dół; grawitacja, gdy uśpione, ogłuszone lub zniszczone).
- Rytm strzałów bez zmian w `EnemyBrain`: `attack_range` = 14 m tylko, gdy odnowienie minęło; po strzale 1,6 s odnowienia (zasięg ujemny), w tym czasie popiersie jest w pościgu i się przemieszcza. Cykl: 0,7 zapowiedzi + 0,1 odpoczynku + 1,6 = 2,4 s.
- Zapowiedź: pęknięcia (cienkie bryły na głowie i piersi) żarzą się od środka coraz mocniej, wewnętrzne światło rośnie, popiersie odchyla się do tyłu, zgrzyt `bust_grind`; w chwili strzału wychyla się do przodu (`shard_fire`).
- Ciało: marmurowa głowa (nos, brwi, loki), szyja, pierś z ramionami, mały okrągły cokół pod spodem; kolizja kapsułą nad początkiem układu.
- Uśpione popiersie stoi na swoim cokole (grawitacja), obudzone unosi się.

**Testy (`test_bust.gd`):** unosi się ok. 1,6 m; cofa się przed bliskim celem, podchodzi do dalekiego, trzyma dystans średni; strzela tylko z linią wzroku (ściana → brak pocisku); ogłuszone spada na podłogę i daje się dobić pięścią (finisher); odłamek rani strażnika za 12; słaby punkt z przodu głowy.

## Zadanie 4: T-Rex

### 4.1 Liczby

| Parametr | Wartość |
|---|---|
| Zdrowie | 1200 |
| Strefy | kryształ ×1 (×1,5 przy ogłuszeniu); kości ×0,1; uśpiony nie przyjmuje obrażeń |
| Fazy | 1: > 66%, 2: ≤ 66%, 3: ≤ 33% (przejście = ryk fazy) |
| Chód | 3,5 m/s (faza 1), 4,5 m/s (2–3); obrót 1,3 / 1,7 rad/s — duże zwierzę, łatwo zajść od tyłu |
| Szarża | zapowiedź 1,0 s (w fazie 3 druga 0,7 s): łapa grzebie (pył), ryk, łeb nisko, oczy i kryształ rozbłyskują; odlicza się tylko, gdy stoi przodem (±25°), śledzi gracza 2,6 rad/s, kierunek zamknięty 0,4 s przed biegiem (tyle, by zejść z toru zwykłym krokiem); bieg 14 m/s po prostej na dystans do gracza + 7 m (maks. 2,6 s); uderzenie w ścianę/kolumnę → ogłuszenie 2,5 s; bez ściany → hamowanie 0,9 s; kontakt z graczem (tor ±1,15 m + promień strażnika) 30 obr. + duży odrzut w bok; rampy schodów (> 20°) są dla niego ścianą; odnowienie 9 s / 6 s / 6,5 s (faza 1/2/3), 2× szybciej, gdy gracz stoi przed nim bliżej niż 6 m |
| Ogon | gdy gracz za nim (> 110° od kierunku patrzenia) w 7 m od bioder; zapowiedź 0,6 s (ogon unosi się i zwija, łeb odwraca się, grzechot kości); uderzenie 25 obr. + odrzut 16 m/s w pasie 1,8–7,4 m od bioder, > 70° za nim (ogon opada na wysokość strażnika; tuż pod nasadą ogona przelatuje nad głową); odnowienie 2,5 s |
| Ryk (faza 2+) | 1,6 s, akcja w 0,5 s; przywołanie: co 20 s callback `summon(count) -> Array`, `count = min(4, 6 − żywe przywołane)`; brak miejsca → ryk pominięty, ponowna próba za 5 s |
| Gruz (faza 3) | ryk co 10 s: 3 cienie (pod graczem i 2 obok, 3–4 m), 1 s zapowiedzi (cień ciemnieje i rośnie, głaz widać w locie), 20 obr. w promieniu 1,6 m |
| Paralizator | trafienie w kryształ → potknięcie 1 s (przerywa zapowiedzi i szarżę), odnowienie 8 s |
| Śmierć | kryształ pęka (błysk, odłamki, hitstop, wstrząs), szkielet drży 0,7 s, potem każda kość staje się fizycznym odłamkiem (`RigidBody3D`, warstwa `DEBRIS`) i zostaje na podłodze; `defeated` + `Events.boss_defeated` od razu |
| Pył | 100 (`dust_value`, do podpięcia w 2c-2) |

### 4.2 Stany (`TRexBrain`)

`DORMANT → (wake) → WAKING (3 s: ryk na postumencie, zeskok) → STALK`; ze `STALK`: `TAIL_WINDUP → TAIL_SWIPE`, `CHARGE_WINDUP → CHARGE → (ściana) STUNNED | (czas) SKID | (faza 3, pierwsza) CHARGE_WINDUP`, `ROAR`; `STAGGER` przerywa wszystko poza `STUNNED`, `WAKING`, `DORMANT`; `DEAD` końcowy. Sygnały: `state_changed`, `phase_changed`, `roar_peak(summon, debris)`, `tail_strike`. Wejście co klatkę: `update(delta, distance, angle)` (kąt od kierunku patrzenia do gracza). Reguła obrażeń: `TRexBrain.damage_multiplier(zone, state)`.

### 4.3 Ruch bez siatki nawigacji

Skręt ograniczony prędkością obrotu, ruch zawsze przodem (`forward × speed × max(dot, 0.25)`). Trzy czujniki (promienie `WORLD` na wysokości 1,2 m, 5 m przed ciałem, 0° i ±35°): przeszkoda na wprost → skręt w stronę czystszego czujnika. Zablokowanie (< 0,6 m postępu w 1,2 s) → 1,4 s obchodzenia w bok z odwróconą stroną przy kolejnym razie. Kolizja: kapsuła nóg (do podłogi), pozioma kapsuła tułowia, kula głowy; maska `WORLD | PLAYER` w chodzie, `WORLD` w szarży (przebiega przez strażnika, zadaje obrażenia kontaktem). Figury woskowe go nie blokują.

### 4.4 Wygląd (szary szkielet)

Ok. 11 m od pyska do końca ogona, 5 m wysokości: czaszka z oczodołami (żarzące się czerwone oczy), żuchwa z zębami (otwiera się przy ryku), szyja z 5 kręgów w kształcie litery S, kręgosłup z wyrostkami, 6 par żeber z 3 segmentów (klatka), gastralia, drobne rączki z pazurami, miednica z „butem” łonowym, nogi (udo, piszczel, śródstopie, 3 palce), ogon z 14 kręgów malejących do zera z szewronami. Kryształ między żebrami: fasetowana bryła, emisja + czerwone światło pulsujące jak serce; przy ogłuszeniu zjeżdża niżej, rośnie, świeci mocniej, a żebra rozchylają się. Pozy liczone proceduralnie (chód, zapowiedzi, ryk, ogłuszenie).

**Testy (`test_trex_brain.gd`, `test_trex.gd`, `test_debris_drop.gd`):** obrażenia tylko przez kryształ (kości 10%, ogłuszony ×1,5); progi faz; szarża → ściana → okno ogłuszenia (i ×1,5); szarża rani strażnika raz; ogon tylko od tyłu (z przodu i z boku nie); przywołanie: 4, potem do 6, potem 0; potknięcie po paralizatorze z odnowieniem 8 s; śmierć → `defeated`, `Events.boss_defeated`, fizyczne kości; uśpiony do `wake()` (strzały go nie budzą); gruz: 3 cienie, obrażenia tylko w promieniu po 1 s; nie utyka przy kolumnie.

## Zadanie 5: arena deweloperska

`BossDev` (scena `src/enemies/trex/boss_dev.tscn`): hala 36×44 m, sufit 14 m (bez sufitu — księżyc), 4 kolumny 2×2 m w (±10, ±8), postument (−6,−14)→(6,−8) wys. 1,2 m, T-Rex na postumencie profilem do wejścia, strażnik w (0, 0, 16) z paralizatorem, pistoletem i strzelbą (pełne zapasy), HUD z 1a, apteczki i amunicja na obrzeżach, nakładka deweloperska (życie/faza/stan bossa, klawisze). Klawisze (fizyczne, obsługiwane w `boss_dev.gd`, bez zmian w `GameInput`): **B** obudź, **N** 3 popiersia, **7** figury woskowe, **0** usuń eksponaty, **K** zbij bossa do następnego progu fazy (a na końcu zabij), **T** nowy uśpiony boss. Przywołanie ryku = figury woskowe w 6 punktach przy ścianach. Śmierć strażnika → odrodzenie po 2 s.

## Zadanie 6: dźwięki

Nowe w `gen_sfx.py` (ziarno = nazwa, więc stare pliki bez zmian — sprawdzane sumą SHA przed/po): `shard_fire`, `shard_break`, `bust_grind`, `trex_roar` (głęboki, warstwowy: piła z wibrato, szum formantowy, pisk, pogłos), `trex_bellow` (krótszy ryk zapowiedzi szarży), `trex_step`, `trex_scrape`, `trex_impact`, `tail_whoosh`, `bone_hit`, `bone_rattle`, `bone_collapse`, `crystal_hit`, `crystal_pulse`, `crystal_shatter`, `rubble`. Dopisane do `Sfx.SOUNDS`.

## Zadanie 7: testy wizualne i wydajność

`bash tools/run_boss.sh --shots` (okno) → `tests/_out/boss/`; `--dry` (bez okna, `--headless`) przechodzi te same momenty bez zrzutów i sprawdza, że boss osiąga każdy stan; `--perf` (okno) mierzy FPS. Momenty: `dormant`, `wake_roar`, `charge_telegraph`, `charge_run`, `stunned`, `tail_windup`, `tail_swipe`, `debris`, `death_crystal`, `death_collapse`, `bust_telegraph`, `bust_shard`, plus pomiar FPS w walce (boss + figury + popiersia + pociski). Obejrzeć zrzuty; sylwetka ma od razu czytać się jako szkielet T-Reksa.

---

## Odstępstwa od projektu

1. **Koniec szarży.** Projekt nie mówi, kiedy szarża się kończy. Bieg trwa do dystansu gracza + 7 m (maks. 2,6 s); ogłuszenie tylko po uderzeniu w ścianę albo kolumnę, inaczej krótkie hamowanie (0,9 s bez bonusu). Dzięki temu kolumny naprawdę są „osłoną przed szarżą” (8.2), a ogłuszenie jest nagrodą za ustawienie się, nie za samo przeżycie.
2. **Obrażenia szarży** (brak w projekcie): 30 + mocny odrzut w bok, raz na szarżę.
3. **Dwie szarże w fazie 3:** druga (zapowiedź 0,7 s) tylko wtedy, gdy pierwsza nie skończyła się na ścianie — ogłuszenie ma pierwszeństwo.
4. **Szarża z bliska:** dozwolona z każdej odległości w przednim łuku, a odnowienie biegnie 2× szybciej, gdy strażnik stoi przed pyskiem bliżej niż 6 m — inaczej najbezpieczniej byłoby stać pod klatką piersiową i strzelać w kryształ.
5. **Uśpiony T-Rex nie przyjmuje obrażeń** (w grze kryształu jeszcze w nim nie ma); strzały go nie budzą, tylko `wake()`.
6. **Znaczniki trafień bez zmian w HUD:** trafienie w kryształ ustawia `info.weak_point` (złoty znacznik), w kości `info.blocked` (szary znacznik z projektu). Mnożnik kryształu liczy boss, hurtbox kryształu nie jest „słabym punktem” broni (inaczej pistolet dawałby ×2 zamiast ×1).
7. **Ogłuszony T-Rex osuwa się:** kryształ zjeżdża na ok. 1,7 m i żebra się rozchylają — okno ×1,5 jest czytelne i sięgalne także pięścią (synergia z 1a).
8. **Faza 3:** ryk zrzuca gruz co 10 s; przywołanie figur trwa dalej co 20 s (ten sam ryk robi oba). „Max 6 żywych” liczy figury przywołane przez bossa.
9. **Boss nie emituje `enemy_destroyed`** (ma inną klasę niż `Enemy`; słuchacze 2a mogą rzutować na `Enemy`). Zamiast tego `Events.boss_awakened(boss)` (HUD podpina pasek) i `Events.boss_defeated(boss)` (krata, koniec dema, Pył 100).
10. **Popiersie:** 1,6 m to prześwit pod cokołem (głowa na ok. 2,3 m — wyraźnie „lewituje”); strzał wymaga linii wzroku także w chwili wystrzału (gracz, który schował się w trakcie zapowiedzi, jest nagradzany); uśpione stoi na cokole i unosi się po przebudzeniu.
11. **Ogon ma martwe pole pod nasadą** (< 1,8 m od bioder): tam ogon jest ponad głową strażnika. Daje drugą drogę ucieczki (wejść pod nasadę albo odejść dalej niż 7,8 m), a obraz zgadza się z logiką (bicz opada na wysokość strażnika dopiero dalej od bioder).
12. **Zamknięcie celu szarży 0,4 s przed biegiem** (plan zakładał 0,25 s): przy szarży z bliska 0,25 s nie wystarczało, by zwykłym krokiem zejść z toru (tylko unik ratował) — test to potwierdził.
13. **Rampy schodów są dla T-Reksa ścianą** (maks. nachylenie 20°): bez tego szarża wjeżdżała po rampie na balkon (test: 3,9 m w górę).
14. **Ogłuszony T-Rex odkłada łeb na bok** (losowo w lewo/prawo): z łbem na wprost klatki kryształ był od przodu zasłonięty w 97% (pomiar), więc okno ×1,5 nie działało z przodu. Strefa kryształu 0,26 m (plan: 0,3) — wciąż szersza niż widoczny klejnot, a walka nie kończy się w minutę.

## Stan wykonania (30.09)

- Zadania 1–7 wykonane, commit po każdym; testy bez okna: **zielone** (liczba w raporcie końcowym), bez linii `ERROR`/wycieków.
- Zrzuty i pomiar FPS w oknie **czekają na zbiorcze uruchomienie przez koordynatora** (zasada: agent nie otwiera okien). Polecenia:
  - `bash tools/run_boss.sh --shots` → `tests/_out/boss/*.png` + `shots.json`
  - `bash tools/run_boss.sh --perf` → średni i najgorszy czas klatki w walce fazy 3 (boss + 3 popiersia + 4 figury + gruz) + `perf.json`
  - kontrola logiki bez okna: `bash tools/run_boss.sh --dry` (przechodzi, każdy moment osiągnięty; 91 fizycznych kości po śmierci).
- Pomiar bez renderowania (`--headless --mode=perf`): 128 kl./s średnio, najgorsza klatka 17,6 ms — sama symulacja walki jest tania; koszt GPU do sprawdzenia w oknie.

## Balans: ile trwa walka (szacunek do sprawdzenia w grze)

Pomiar bez okna (400 strzałów pistoletu w kryształ z błędem celowania σ = 0,3 m, czyli ok. 2° z 8 m): w zwykłym stanie kryształ trafia 16–33% strzałów (z przodu najwięcej — ale to tor szarży), kości 55–70%; w ogłuszeniu 40–59% (×1,5). Model: ok. 40% czasu realnie strzela się w kryształ, jedno ogłuszenie na ok. 15 s → ok. 13–14 obrażeń/s → **ok. 1,5 min czystego zadawania obrażeń, 2–2,5 min z dodatkami** (figury, popiersia, ryki, przeładowania, amunicja). Ulepszony gracz (+30% pistolet, slug) — bliżej 2 min. Pokrętła: `TRex.max_health` (1200 z projektu), `TRexSkeleton.CRYSTAL_RADIUS` (0,26 m), czasy w `TRexBrain`.

## Integracja z 2c-2 (lobby, kryształ, krata)

- **Ustawienie:** T-Rex na postumencie (−6,−14)→(6,−8): `position = (0,5; 1,25; −11)`, `rotation.y = PI / 2` (profilem do wejścia S), jak `BossDev.BOSS_START/BOSS_YAW`. Cel domyślnie z grupy `player`.
- **Kryształ → przebudzenie:** uśpiony T-Rex nie ma kryształu (`skeleton.crystal_present == false`), a `boss.skeleton.crystal_position()` podaje punkt docelowy lotu (gniazdo między żebrami) także w uśpieniu. Gdy lecący kryształ dotrze: usunąć go i wywołać `boss.wake()` (pokazuje własny kryształ, ryk na postumencie, zeskok, `Events.boss_awakened`).
- **Przywołanie figur:** `boss.summon = func(count: int) -> Array` — budzi/tworzy do `count` figur z puli holu i zwraca je; boss sam pilnuje limitu 6 żywych.
- **Pasek zdrowia (2a):** `Events.boss_awakened(boss)` → `boss.health.changed(current, max)`, `boss.phase_changed(phase)`, `boss.defeated`.
- **Krata i koniec dema:** `Events.boss_defeated(boss)` (lub `boss.defeated`) w chwili śmierci; kości zostają jako węzeł `TRexRemains` w rodzicu bossa, sam węzeł bossa znika ok. 0,8 s później. Pył: `boss.dust_value` (100) odczytać w obsłudze sygnału.
- **Grupy:** boss jest w grupie `boss`, nie `enemies`, i nie emituje `enemy_destroyed` (licznik „sala oczyszczona” go nie czeka).
- **Balkon:** T-Rex nie wejdzie na balkon (y = 6), ale gruz z fazy 3 spada także tam (znaczniki szukają podłogi pod strażnikiem i sufitu nad nim).
- **Popiersie:** `Bust.KIND = &"bust"`; Pył 5 ustawia się sam, gdy w `Enemy` pojawi się `dust_value` (2a).
- **Scalanie:** `enemy.gd` — jedyna zmiana to haczyk `_apply_gravity(delta)` (jeśli 2b-1 dodaje limit prędkości spadania, niech trafi do bazowej wersji haczyka). `events.gd` — dwa nowe sygnały na końcu. `sfx.gd` i `gen_sfx.py` — dopisane bloki na końcu list (konflikt z 2a do rozwiązania przez zachowanie obu bloków i ponowne wygenerowanie; ziarna per nazwa gwarantują identyczne pliki).

## Poprawki po przeglądach (30.09, wieczór)

Dwa przeglądy kodu 2c-1; wszystkie przyjęte punkty wykonane (osobne commity, test przy każdej zmianie zachowania).

**Szybkość testów**
- **T1** `tools/run_tests.sh` uruchamia zestaw z `--fixed-fps 60`: każdy krok fizyki to nadal 1/60 s, ale klatki lecą bez czekania na zegar. Cały zestaw z importem: ok. 35–40 s (546 testów) zamiast ok. 3,5 min (422 testy). Sceny wizualne i pomiary wydajności dalej w czasie rzeczywistym.
- **T2** Końcowe czekanie runnera to prawdziwe 250 ms zegara (wątek audio zwalnia zatrzymane dźwięki). Bez tego „resources still in use at exit” w co trzecim przebiegu testów popiersia.
- **T3** `test_sandbox_arena.gd` czeka na synchronizację mapy nawigacji (zmiana `map_get_iteration_id()` i podłoga widoczna na mapie, z limitem klatek) zamiast stałych 6 klatek.
- **Dodatkowo:** runner przełącza mapy i regiony nawigacji na aktualizację synchroniczną (`navigation/world/map_use_async_iterations` i `region_use_async_iterations` = false, tylko w testach). Przy klatkach bez czekania asynchroniczna aktualizacja spóźniała się o zmienną liczbę klatek i test zamykanych drzwi lobby (2b-1) padał za każdym razem. Gra zostaje przy asynchronicznej.

**Popiersie i pocisk**
- **F1** Opór powietrza dla odrzutu w locie (`Bust.HOVER_DRAG` = 18 m/s², w `bust.gd`, bez zmian w `enemy.gd`): cios pięścią przesuwa je o ok. pół metra, a nie o kilkadziesiąt (baza hamuje odrzut tylko na podłodze).
- **F10** Nie strzela do strażnika, który w trakcie zapowiedzi schronił się w przystani.
- **F11** `Projectile.create()` i `DebrisDrop.create()` przyjmują położenie w świecie i ustawiają się w nim po wejściu do drzewa, pod dowolnym rodzicem (także przesuniętym i obróconym).

**T-Rex**
- **F2** Gruz, który jeszcze spada, gdy boss ginie (albo znika), ląduje, ale nikogo nie rani.
- **F3** Wezwanie pomija zwolnione i usuwane węzły; `alive_summoned()` nie alokuje, gdy nikogo nie wezwał.
- **F4** Czułki liczą tylko przeszkody między bossem a strażnikiem (zasięg = min(5 m, odległość − 0,9 m)) — ściana za plecami strażnika już go nie odwraca. Nowe przy okazji: czaszka wystaje 5 m przed biodra, więc przy ścianie za strażnikiem boss podchodzi, aż pysk prawie jej dotyka, i staje przodem do niego (zamiast wbijać łeb w ścianę i uciekać bokiem po wykryciu „utknięcia”). Szarża z tego miejsca przygniata strażnika do ściany (trafienie) i ogłusza bossa.
- **F5** Ogon trafia tam, gdzie naprawdę przechodzą kręgi: w każdej klatce smagnięcia (pierwsze 0,25 s zamachu) sprawdzany jest pas zamieciony przez kręgi od poprzedniej klatki (promień kręgu + 0,4 m strażnika), tylko tam, gdzie ogon schodzi poniżej jego głowy (przy nasadzie przechodzi nad nim). Zapowiedź 0,75 s (było 0,6). Wyzwalanie dopasowane do realnego zasięgu: do 6 m i do ok. 45° od kierunku „dokładnie z tyłu” (było 7 m i 70°); strażnika bardziej z boku boss nie smaga, tylko się do niego obraca. Stare `in_tail_zone()` usunięte.
  - **Zamierzona odpowiedź gracza:** po zwykłej reakcji (0,3 s) wystarczy wyjść z pasa ogona chodem w dowolną stronę — dalej niż ok. 6 m, pod nasadę albo w bok. Przy spóźnionej reakcji (0,5 s) chód w kierunku zamachu już nie wystarcza; ratuje sprint albo unik (dash, jeszcze po 0,6 s). Testy: stojący obrywa; chód w tył / pod nasadę / w bok po 0,3 s — unik; chód w bok po 0,5 s — trafienie; sprint w bok po 0,5 s i dash po 0,6 s — unik.
  - Zrzuty `tail_hit` i `tail_hit_top` (`run_boss.sh --shots`) pokazują dokładnie klatkę rejestracji trafienia (boss zatrzymany): zewnętrzne kręgi dotykają kapsuły strażnika (0,4 × 1,8 m). Obejrzane — zgadza się.
- **F6** Szarża nie trafia strażnika za biodrami (tylko przed nimi).
- **F7** Odnowienia wezwania i gruzu liczą się od szczytu ryku: paralizator przed szczytem tylko opóźnia wezwanie (boss ryczy ponownie po potknięciu), nie kasuje go.
- **F8** Umierający szkielet od razu wyłącza strefy trafień (strzały przez 0,8 s drżenia nie znikają w nim bez śladu).
- **F9** Cios kończący nigdy nie daje szarego znacznika; jeden strzał w żebra i kryształ naraz — wygrywa złoty (szary w tej samej klatce od tego samego strzelca jest pomijany, bez zmian w HUD).
- **F10** Strażnik w przystani nie jest celem (odległość nieskończona: bez podchodzenia, szarży, ogona i gruzu; gruz już spadający nie rani w przystani). Boss zderza się z niewidzialnymi ścianami przystani (`Layers.ENEMY_BLOCK`), a czułki je widzą.
- **F11** Boss steruje i liczy namiar we współrzędnych świata (`_bearing` z wektora przodu, obrót w STALK przez `_turn_by`); kości rozpadu dostają `global_transform` po dodaniu do drzewa (+ `reset_physics_interpolation`). Testy bossa i popiersia pod przesuniętym i obróconym rodzicem.
- **F12** Cienie gruzu przy ścianie i w rogu obracają się (co 0,25 rad, na zmianę w obie strony, aż dookoła), dopóki nie znajdą miejsca co najmniej 2,5 m od pozostałych — rozkładają się wzdłuż ściany zamiast spadać na strażnika.
- **F13** Drobne: `BossDev` nie odradza strażnika, gdy arena opuściła drzewo; strażnik czasu w `boss_scenario` (po 120 s `MISSED` i kod 1); uśpiony boss ustawia pozę raz, a nie co klatkę (91 kości i 45 stref stoi w miejscu); nowy sygnał `collapsed(remains)`.
- `tools/run_boss.sh --shots` / `--perf` otwierają okno (`--windowed`), a nie pełny ekran (domyślny w projekcie).

**Poza zakresem (do bazy):** `enemy.gd` — `face()` i `_face_towards()` ustawiają lokalny `rotation.y`, więc popiersie (i każdy eksponat) pod obróconym rodzicem patrzy w złą stronę. Odłamek i tak startuje z właściwego miejsca i leci w strażnika (test), ale obrót trzeba poprawić w `Enemy`.

**Stan:** 546 testów zielonych w 3 pełnych przebiegach; popiersie, pocisk i T-Rex po 10 przebiegów bez błędów; `run_boss.sh --dry` przechodzi (z nowym momentem „tail hit”); zrzuty `--shots` obejrzane.
