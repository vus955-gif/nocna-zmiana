# Zawartość pierwszego obszaru — dwie bronie, dwa eksponaty, osiem ulepszeń: plan implementacji

> Stan: 1 października 2026 (noc 30.09 → 1.10). Wykonawca: Claude (osobny worktree, gałąź od `etap-1a-piaskownica` @ `0930f8d`, równolegle z integratorami I1/I2, oprawą graficzną i dźwiękiem).
> Liczby autorytatywne: `docs/superpowers/specs/2026-10-01-rozbudowa-projekt.md`, sekcje 1 (bronie), 2 (przeciwnicy) i 3 (ulepszenia). Zegar nocy (§4) i CCTV (§5) nie należą do tego planu. Tam, gdzie plan doprecyzowuje albo zmienia projekt, patrz „Odstępstwa” na końcu.

**Cel:** jakość dema na Steam — każda broń czuje się inaczej i daje satysfakcję, każdy eksponat jest czytelny i uczciwy. Nowa zawartość powstaje w **nowych plikach**, zmiany we wspólnych plikach są małe i lokalne (inni agenci pracują równolegle nad `museum.gd`, `src/level/*`, `night_*.gd`, `enemy.gd`, `crowd.gd`, `hud.gd`, `src/world/*`, wyglądem eksponatów i dźwiękiem otoczenia).

**Architektura:** jak dotąd — węzły buduje kod, czysta logika w klasach `RefCounted` testowanych bez sceny, efekty przez `Fx`/`Sfx`/`Events`. Wygląd na razie z prymitywów („greybox”), ale **z nazwanymi węzłami** (np. `barrels`, `crank`, `Muzzle`, `head`, `jaw`, `tail_1`), tak by modele z Blendera mogły je zastąpić przez identyfikator `ArtLibrary` bez zmian w logice.

## Pliki

| Plik | Odpowiada za |
|---|---|
| `src/weapons/data/gatling.tres`, `flare.tres` | liczby obu broni |
| `src/weapons/content_viewmodels.gd` | `ContentViewmodels`: greybox kartaczownicy (6 luf `barrels`, korba `crank`, taśma `belt`) i rakietnicy (łamana lufa `barrel`, raca w lufie `shell`) |
| `src/weapons/gatling_view.gd` | `GatlingView`: obrót luf i korby, żar luf, dym, pętle dźwięku (korba, terkot) |
| `src/weapons/flare_view.gd` | `FlareView`: łamanie lufy przy przeładowaniu, raca widoczna w lufie |
| `src/weapons/flare.gd` | `Flare extends Projectile`: lot łukiem, przyklejenie, wybuch |
| `src/weapons/flare_light.gd` | `FlareLight`: przyklejona raca — światło 12 s, płonięcie wroga, spadanie po jego zniszczeniu, limit aktywnych rac |
| `src/combat/blast.gd` | `Blast`: wybuch o promieniu (trafienia przez hurtboxy, linia wzroku, odrzut, ogień ×2 na wosk, obrażenia własne strażnika tylko do 50% zdrowia) |
| `src/props/chained_display.gd` | `ChainedDisplay`: ekspozycja „Kartaczownica, 1871” zamknięta łańcuchem |
| `src/props/emergency_cabinet.gd` | `EmergencyCabinet`: szafka „W razie pożaru zbić szybkę” z rakietnicą |
| `src/props/found_weapon.gd` | `FoundWeapon`: wspólne „weź znalezioną broń na zawsze” |
| `src/props/painting_art.gd` | `PaintingArt`: 10 wariantów obrazów (proceduralne płótna), rama, oczy, usta; `WallPainting` — zwykły, nieszkodliwy obraz |
| `src/enemies/raptor.gd` | `Raptor`: szkielet raptora (flankowanie, doskok, kości) |
| `src/enemies/raptor_pack.gd` | `RaptorPack`: stado 3–4 na raz + fabryka przywołania dla ryku T-Reksa |
| `src/enemies/portrait.gd` | `Portrait`: portret-zasadzka na ścianie |
| `src/enemies/paint_blob.gd`, `paint_puddle.gd` | `PaintBlob extends Projectile` (plwocina farby), `PaintPuddle` (plama spowalniająca) |
| `src/ui/threat_indicator.gd` | `ThreatIndicator`: wskaźnik „Czujnego ucha” (własny węzeł UI, nie w `hud.gd`) |
| `src/ui/second_wind_fx.gd` | `SecondWindFx`: szarzejący ekran i bicie serca „Drugiego oddechu” |
| `src/dev/content_dev.gd` + `.tscn`, `tools/run_content.sh` | arena deweloperska zawartości |
| `tests/scenarios/content_scenario.gd` + `.tscn` | zrzuty ekranu do `tests/_out/content/` |
| testy `tests/unit/test_gatling_state.gd`, `tests/integration/test_gatling.gd`, `test_flare.gd`, `test_acquisition.gd`, `test_raptor.gd`, `test_portrait.gd`, `test_content_upgrades.gd`, `test_content_dev.gd` | testy |

**Zmiany we wspólnych plikach (małe, lokalne):** `weapon_data.gd` (nowe pola), `weapon_state.gd` (korba, rozgrzanie, taśma), `weapon_holder.gd` (sloty 4–5, spust korby, pociski, kara ruchu, ograniczony wstrząs, pole `weapon` w trafieniu), `viewmodels.gd` (jedna linia delegacji), `damage_info.gd` (`Kind.FIRE`, pole `weapon`), `exhibit_material.gd` (`BONE`, `CANVAS`, mnożnik ognia), `gib_planner.gd` (drobne kości), `upgrade_catalog.gd`, `upgrade_effects.gd`, `loadout.gd`, `dust_mote.gd` (zasięg magnesu od strażnika), `player.gd` (kara ruchu, spowolnienie, drugi oddech, wskaźnik), `game_input.gd` (`weapon_4`, `weapon_5`), `pickup.gd` (`RIFLE`, `FLARES`), `sfx.gd` + `gen_sfx.py` (nowe dźwięki, stare pliki bajt w bajt), `locale/strings.csv`.

## Konwencje

Tabulatory, typowanie statyczne, identyfikatory i komentarze po angielsku, teksty dla gracza przez `tr()` (PL + dobre EN). Transformacja przed `add_child`. `bash tools/run_tests.sh` zielony po każdym zadaniu, bez linii `ERROR` i wycieków. Jeden commit na zadanie, stopka `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (drugie `-m`), do gita tylko własne pliki (nigdy `git add -A`, nigdy złącze `tools/godot`). Okna: `--windowed --audio-driver Dummy`.

---

## Zadanie 1: ten plan

## Zadanie 2: dźwięki zawartości

Nowe nazwy w `Sfx.SOUNDS` i w `gen_sfx.py` (dopisane na końcu, każdy z własnym ziarnem = nazwa, istniejące WAV-y bajt w bajt): `gatling_crank`, `gatling_spin` (pętla), `gatling_rattle` (pętla 1 s = 14 strzałów), `gatling_stop`, `flare_fire`, `flare_burn`, `flare_blast`, `glass_break`, `chain_clank`, `chain_break`, `raptor_hiss`, `raptor_screech`, `portrait_creak`, `paint_spit`, `paint_splat`, `hit_canvas`, `break_canvas`, `heartbeat`, `ear_warn`. Pętle: `edit/loop_mode=2` w pliku `.import`.

## Zadanie 3: Kartaczownica (`gatling`, slot 4)

**Liczby (1.1):** rozkręcanie 0,45 s (korba + terkot), po puszczeniu kręci się jeszcze 0,6 s — w tym czasie ponowny start jest natychmiastowy, potem lufy stają; 14 strz./s (odstęp 1/14 s z przeniesieniem reszty klatki, żeby przy 60 Hz fizyki wyszło naprawdę 14, a nie 12); 7 obr./pocisk; rozrzut 3° rosnący do 5° przy serii (pełny po 1,5 s ciągłego ognia, opada 2× szybciej po puszczeniu); taśma `rifle`: pojemnik 120, zapas maks. 360, **bez przeładowania** — pusty pojemnik od razu dociąga kolejną taśmę z zapasu (licznik HUD „pojemnik | zapas” spada do zera i od razu wraca); podczas trzymania spustu (rozkręcanie i ogień) strażnik chodzi −35% i nie sprintuje.

**Rozwiązanie:**
- `WeaponData`: `spin_up_time`, `spin_down_time`, `spread_max_deg`, `spread_growth_time`, `belt_feed`, `firing_move_factor`, `shake_cap`.
- `WeaponState`: `pull_trigger()` (wołane przez `WeaponHolder.try_fire()` co klatkę trzymania), `spin` 0..1, `coasting()`, `barrel_speed()` (do animacji), `heat` 0..1 → `spread_for(data)`, `trigger_held()`; `can_fire()` wymaga pełnego rozkręcenia; `can_reload()` zawsze fałsz dla taśmy.
- `WeaponHolder`: `SLOT_ORDER` + `gatling`, `flare`; klawisze 4 i 5; `move_factor()` i `allows_sprint()` dla gracza; wstrząs z sufitem (`shake_cap`: trauma rośnie do 0,4 i tam się trzyma — mocno, ale pod kontrolą); każde trafienie niesie `DamageInfo.weapon` (id broni — potrzebne łańcuchowi ekspozycji).
- Widok (`GatlingView` na korzeniu viewmodelu): lufy i korba obracają się z prędkością `barrel_speed()`, drobny rozrzut pozycji przy każdym strzale, lufy żarzą się po długiej serii i dymią przy wybiegu, pętle `gatling_spin` (wysokość dźwięku z prędkością luf) i `gatling_rattle` (tylko w czasie ognia), `gatling_crank` przy starcie, `gatling_stop` przy zatrzymaniu. Zamiast prawdziwego falowania powietrza (shader ekranowy nie zgadza się z własnym FOV viewmodelu) — żar luf i unoszący się dym (patrz „Odstępstwa”).
- `Loadout`: ścieżki `gatling`/`flare`, amunicja startowa. `Pickup`: `RIFLE` (60) i `FLARES` (2).

**Testy:** rozkręcanie 0,45 s (0,2 s z `gatling_spin`), wybieg 0,6 s z natychmiastowym ponownym startem i pełnym rozkręcaniem po nim, 14 strz./s, rozrzut 3° → 5° i powrót, taśma schodzi i dociąga zapas bez stanu przeładowania, R nic nie robi, kara ruchu −35% i brak sprintu przy spuście, zwykła prędkość po puszczeniu.

## Zadanie 4: Rakietnica sygnałowa (`flare`, slot 5)

**Liczby (1.2):** raca 28 m/s, lekki łuk (grawitacja 6 m/s²), przykleja się do wroga/ściany, świeci 12 s (ciepłe `OmniLight3D` bez cieni, zasięg 10 m, migotanie, ostatnie 1,5 s gaśnie), płonięcie 6 obr./s przez 5 s na trafionym (co 0,5 s po 3), wosk ×2 od ognia (`DamageInfo.Kind.FIRE` — nowy rodzaj; mnożnik liczy źródło ognia przez `ExhibitMaterial.fire_factor()`, bez zmian w `enemy.gd`), wybuch 2,5 m / 20 obr. / odrzut, strażnik w zasięgu traci co najwyżej tyle, ile ma powyżej 50% zdrowia; 1 raca w lufie, zapas maks. 8, przeładowanie 1,4 s.

**Rozwiązanie:** `Flare extends Projectile` (hurtbox wyłączony — własne strzały strażnika nie zbijają racy; maska `WORLD | ENEMY`, bez strażnika); przy trafieniu `Blast.explode()` + `FlareLight.stick()`. `FlareLight` nie jest dzieckiem wroga — co klatkę podąża za jego transformacją; gdy wróg zginie albo zniknie, raca spada na podłogę i świeci dalej. Najwyżej 8 aktywnych rac (najstarsza gaśnie przedwcześnie). Pocisk startuje przed okiem i leci w punkt celownika (promień z oka), więc trafia tam, gdzie celujemy.

**Testy:** lot i łuk, przyklejenie do ściany (światło 12 s, potem znika), przyklejenie do wroga (podąża za nim), płonięcie 6/s przez 5 s, wosk ×2 (ogień) i ×1 (inne), wybuch 20 w 2,5 m i nic dalej, odrzut, obrażenia własne tylko do 50%, 1 w lufie, przeładowanie 1,4 s, zapas 8.

## Zadanie 5: zdobywanie broni

- `ChainedDisplay.create(transform)` — początek na podłodze, przód (-Z) do sali; niski postument, kartaczownica na lawecie, łańcuch z kłódką, mosiężna tabliczka „KARTACZOWNICA, 1871”. Łańcuch ma hurtbox: trafienie **strzelbą** (`info.weapon == &"shotgun"`, co najmniej 25 obr. — trzy śruciny; slug też) albo **3 ciosy pięścią** zrywają go; pistolet/inne tylko krzesają iskry (`hit_metal`) — podpowiedź. E przed zerwaniem: grzechot łańcucha i napis „Zamknięte na łańcuch”; po zerwaniu E = „Weź kartaczownicę” → broń na zawsze (`GameState.add_weapon`, zapis). Sygnały `chain_broken`, `taken`. Gdy broń już zdobyta — pusta laweta, bez łańcucha.
- `EmergencyCabinet.create(transform)` — początek na ścianie (środek szafki), przód (-Z) do sali; czerwona szafka, szybka, napis „W RAZIE POŻARU ZBIĆ SZYBKĘ”. E = „Zbij szybkę” (albo strzał w szybkę): brzęk (`glass_break`), odłamki, **budzi eksponaty w promieniu 16 m** (hałas — bez linii wzroku), zapis `RunState.mark_used(&"flare_cabinet")`; potem E = „Weź rakietnicę”. Sygnały `smashed`, `taken`.

**Testy:** strzelba z bliska zrywa łańcuch, pistolet nie; 3 ciosy tak, 2 nie; zabranie daje broń na zawsze; szafka: zbicie budzi uśpione w 16 m, dalsze śpią; zabranie daje rakietnicę; zdobyta broń → pusty mebel.

## Zadanie 6: Szkielet raptora (`raptor`)

**Liczby (2.1):** 1,1 m wysokości, 7,5 m/s, 25 HP, stado 3–4, doskok z 4 m (zapowiedź 0,3 s: przykucnięcie + syk `raptor_hiss`, oczy rozbłyskują), 8 obr., kość (`ExhibitMaterial.Kind.BONE`: rozsypuje się na kostki), Pył 3.

**Rozwiązanie:** `Raptor extends Enemy`, wzór doskoku jak u wilka (łuk z wyliczonym czasem lotu, ugryzienie w locie, bezbronny po lądowaniu). Flankowanie: każdy członek stada ma stronę `flank_side` (+1/−1 na przemian); dalej niż 6 m od strażnika biegnie do punktu 4 m z boku strażnika (względem jego patrzenia; bez gracza — względem kierunku podejścia), przyciągniętego na siatkę nawigacji; bliżej — prosto na cel i doskok. W czasie flankowania patrzy w kierunku biegu. Wszystko na bazowej nawigacji `Enemy` (lobby: warstwa 1). `RaptorPack.spawn(parent, center, count, target, awake)`; `RaptorPack.summoner(parent, spots, target, fallback, chance)` → `Callable(count) -> Array` do `TRex.summon` (50/50 raptory albo `fallback`, np. figury woskowe) — bez zmian w plikach T-Reksa.

**Testy:** dwie strony stada rozchodzą się na lewo i prawo od linii do strażnika; zapowiedź trwa 0,3 s (przykucnięcie i brak ugryzienia przed nią); doskok z 4 m dosięga celu i gryzie za 8; 25 HP (dwa strzały z pistoletu); kość → Pył 3; fabryka przywołania zwraca raptory albo wynik zapasowy.

## Zadanie 7: Portret (`portrait`)

**Liczby (2.2):** uśpiony = zwykły obraz (nietykalny: hurtboxy wyłączone, pociski trafiają płótno jak ścianę); gdy strażnik jest w 10 m z linią wzroku i przed obrazem — oczy zaczynają go śledzić (bez dźwięku, sygnał dla uważnych); po 1,5 s rama wysuwa się 0,5 m ze ściany (skrzypienie, w ścianie zostaje ciemna wnęka, cztery wsporniki) i portret staje się celem; pluje farbą łukiem (zapowiedź 0,7 s: usta się otwierają i świecą kolorem farby), 10 obr., co 2,6 s; plama na podłodze 3 s spowalnia o 40%; 40 HP, oczy = słaby punkt (mnożnik broni, np. pistolet ×2); paralizator 3 s (oczy się zamykają); płótno + złocona rama (`Kind.CANVAS`: drzazgi, strzępy); Pył 4; nigdy się nie rusza.

**Rozwiązanie:** `Portrait extends Enemy` z własnym `EnemyBrain` (budzi go tylko własny wzrok — hałas i sąsiedzi go nie budzą), pozycja przypięta co klatkę, bez grawitacji i obrotu. `Portrait.create_on_wall(transform, painting_id)`: początek = środek płótna na powierzchni ściany, -Z = z ściany do sali. `WallPainting.create(transform, painting_id)` — ten sam wygląd, bez życia (poziom miesza prawdziwe portrety ze zwykłymi). `PaintingArt.VARIANTS` — 10 obrazów (proceduralne płótna 48×64, ostre teksele). Plwocina `PaintBlob` (strzał ją zbija — wtedy bez plamy); plama `PaintPuddle` (decal + `Area3D`) woła `Player.slow(0.6, …)`.

**Testy:** uśpiony nietykalny; strażnik w 10 m z linią wzroku → śledzenie oczami, po 1,5 s wysunięcie i hurtboxy; poza 10 m / za ścianą / za obrazem — śpi; hałas go nie budzi; nie rusza się; plwocina trafia strażnika za 10; plama spowalnia o 40% i znika po 3 s; paralizator ogłusza na 3 s; oczy to słaby punkt.

## Zadanie 8: osiem ulepszeń (§3)

| id | Kategoria | Ceny | Efekt w kodzie |
|---|---|---|---|
| `pockets` | strażnik | 30 / 60 | `max_reserve` każdej broni z zapasem ×1,25 / ×1,5 (zaokrąglone) |
| `second_wind` | strażnik | 120 | śmiertelny cios → 1 HP + 1 s nietykalności, raz na noc (`RunState.used` — przetrwa „Kontynuuj”), `SecondWindFx`: szary ekran + bicie serca |
| `dust_magnet` | strażnik | 25 / 50 | `Player.dust_magnet_radius` 6 → 9 → 12 m, czytany przez `DustMote` |
| `keen_ear` | strażnik | 40 | `ThreatIndicator` (tworzony przez gracza): czerwony klin na brzegu koła wokół celownika w stronę eksponatu, który **za plecami** (> 90° od patrzenia, do 20 m) zaczyna atak, + cichy sygnał `ear_warn` |
| `gatling_spin` | kartaczownica | 50 | rozkręcanie 0,45 → 0,2 s |
| `gatling_belt` | kartaczownica | 45 | pojemnik 120 → 200 |
| `flare_burn` | rakietnica | 45 | płonięcie 5 → 8 s, światło 12 → 20 s |
| `flare_twin` | rakietnica | 70 | 2 race w lufie |

`UpgradeCatalog.CATEGORIES` dostaje `gatling` i `flare`; menu terminala czyta katalog (18 pozycji, przewijane).

**Testy:** efekty wszystkich ośmiu, zapis i odczyt poziomów, drugi oddech raz na noc i po „Kontynuuj”, magnes 9 m, wskaźnik tylko dla ataku z tyłu i tylko z ulepszeniem, menu terminala pokazuje 18 pozycji.

## Zadanie 9: arena deweloperska, balans

`ContentDev extends Sandbox` (`tools/run_content.sh`): wszystkie bronie z amunicją, ekspozycja z łańcuchem i szafka, ściana galerii z 3 portretami wśród zwykłych obrazów, klawisze: 6 — stado raptorów, P — nowe portrety, G — pełna amunicja, L — światło/ciemność (test racy), 7/8/9/0 jak w piaskownicy. Zbiory amunicji `RIFLE`/`FLARES`. Propozycja wag łupu dla `NightDirector` (raport; wprowadza I1).

## Zadanie 10: scenariusz ze zrzutami

`tests/scenarios/content_scenario.gd`: kartaczownica w ogniu (tłum figur), raca oświetla ciemny kąt + płonąca figura woskowa, stado raptorów flankuje (widok z góry), portret się budzi + plwocina w locie, plama, lista terminala. Zrzuty do `tests/_out/content/`, obejrzeć i dopieścić.

---

## Odstępstwa od projektu

1. **Taśma kartaczownicy.** „Pojemnik 120, bez przeładowania” = taśma w broni; gdy się skończy, następna wchodzi z zapasu natychmiast (bez stanu przeładowania, R nic nie robi). „Dłuższa taśma” (200) wydłuża serię bez przerwy w liczniku i podnosi łączny zapas noszony przy broni.
2. **Wybieg luf.** Puszczone przy pełnych obrotach lufy kręcą się jeszcze 0,6 s i przez ten czas strzał jest natychmiastowy; potem stają (pełne 0,45 s od nowa). Puszczone przed pełnymi obrotami zwalniają w tempie rozkręcania.
3. **Kara ruchu** działa przez cały czas trzymania spustu (także w trakcie rozkręcania), nie tylko gdy lecą pociski.
4. **14 strz./s** z przeniesieniem reszty co najwyżej jednej klatki (bez tego 60 Hz fizyki daje 12/s).
5. **Wstrząs**: 0,15 traumy na pocisk z sufitem 0,4 (stały pomruk zamiast narastania do pełnego wstrząsu). **Smuga co 3. pocisk** (inaczej seria wygląda jak laser).
6. **„Falowanie powietrza”** zastąpione żarem luf (od połowy „rozgrzania” serii) i unoszącym się dymem: shader ekranowy nie zgadza się z własnym FOV viewmodelu.
7. **Raca**: grawitacja 6 m/s²; przelatuje przez strażnika i jego własne strzały jej nie zbijają; **wybuch też jest ogniem** (wosk ×2 także od wybuchu, nie tylko od płonięcia); płonięcie tyka co 0,5 s po 3; światło: zasięg 10 m, ostatnie 1,5 s gaśnie; najwyżej 8 rac świeci naraz.
8. **Obrażenia własne**: „nie rani strażnika powyżej 50%” czytane jako: jego własny wybuch zabiera najwyżej to, co ma powyżej połowy zdrowia (strzał pod nogi przy pełnym zdrowiu = −20, przy 50% = 0); zawsze odpycha. Cudze wybuchy ranią w pełni.
9. **Wosk ×2 od ognia** liczy źródło ognia (`Blast.scaled()` → `ExhibitMaterial.fire_factor()`), a nie `Enemy.take_damage` (plik I1). Każde przyszłe źródło ognia powinno użyć `Blast.scaled()`.
10. **Łańcuch ekspozycji** rozpoznaje strzelbę po nowym polu `DamageInfo.weapon` (ustawia je `WeaponHolder`), próg 25 obr. w jednym strzale (≥ 3 śruciny albo slug); pistolet, kartaczownica i raca tylko krzeszą iskry (podpowiedź). Strefa trafień łańcucha = cała broń na lawecie. E przed zerwaniem grzechocze łańcuchem.
11. **Szafka**: szybkę zbija też strzał; hałas budzi w promieniu 16 m bez linii wzroku; portrety na hałas nie reagują.
12. **Raptor**: flankowanie względem kierunku patrzenia strażnika (dla atrapy w testach — względem kierunku, z którego raptor przyszedł); punkt 4 m z boku, flankuje dalej niż 6 m; trasa planowana lokalnie punktami co 7 m (A* na siatce prowadził obie połówki stada tą samą stroną przeszkody); doskok: uniesienie 2,6 m/s (płaściej niż wilk), maks. 12 m/s; odpoczynek 0,75 s; czaszka = słaby punkt (mnożnik broni); ugryzienie z 1,4 m.
13. **Portret**: „nietykalny” = strefy trafień wyłączone + blok na warstwie świata (strzały trafiają płótno jak ścianę) aż do wysunięcia ramy (koniec 1,5 s śledzenia). Budzi go tylko jego wzrok (przed obrazem, 10 m, linia wzroku); obudzony widzi 16 m. Plucie co 2,6 s, zapowiedź 0,7 s; czas lotu z odległości (0,45–1,3 s), grawitacja 9; plama o promieniu 0,9 m, spowolnienie trzyma 0,15 s po zejściu; zestrzelona plwocina nie zostawia plamy. „Oczy ×2” = oczy są słabym punktem z mnożnikiem broni (pistolet ×2 → jeden strzał w oko kończy 40 HP — nagroda za celność).
14. **Drugi oddech**: 1 s łaski; stan w `RunState.used` (`second_wind`) — przetrwa „Kontynuuj”, wraca co noc; efekt ekranu tworzy sam gracz.
15. **Czujne ucho**: `ThreatIndicator` tworzy sam gracz po zakupie (bez zmian w `hud.gd`); odpytuje mózgi eksponatów (bez zmian w `enemy.gd`); jedno ostrzeżenie na atak, eksponat > 90° od patrzenia, do 20 m.
16. **Pojemne kieszenie**: zaokrąglenie `roundi` (pistolet 150 → 188 → 225, strzelba 50 → 63 → 75, taśma 360 → 450 → 540, race 8 → 10 → 12).
17. **Nowe materiały** `BONE` (dźwięki `bone_hit`/`bone_rattle`, 4 kawałki więcej, 0,45 rozmiaru) i `CANVAS` (`hit_canvas`/`break_canvas`, złote drzazgi).
18. **Arena deweloperska** robi znaleziska w trybie `persistent = false`: nic nie zapisuje (inaczej uruchomienie areny nadpisałoby prawdziwy zapis).
19. Napisy w świecie (tabliczka, szafka) mają klucze `EXHIBIT_*`.

## Stan wykonania (1.10)

Zadania 1–10 wykonane, jeden commit na zadanie; zestaw testów zielony. Zrzuty: `tests/_out/content/*.png` (`bash tools/run_content.sh --shots`), logika bez okna: `--dry`.

## Balans (punkt startowy; po przeglądzie 1.10)

Kartaczownica: 7 obr./pocisk, 14 strz./s = 98/s, ale dopiero po rozkręceniu 0,45 s (0,2 s z „Nasmarowaną korbą”; w czasie 0,6 s wybiegu luf — od razu). Rozrzut 3° → 5° po 1,5 s ciągłego ognia: z bliska (≤ 5 m) trafia prawie każdy pocisk; na 10 m w figurę woskową ok. 77% przy 3° i ok. 48% przy 5° (pełna seria), w raptora wyraźnie mniej. Czasy w tabeli liczą rozkręcenie od zera + ogień z bliska.

| | HP | Pistolet (20) | Strzelba (90 z bliska) | Kartaczownica (98/s, z rozkręceniem) | Raca (20 + 6/s, wosk ×2) |
|---|---|---|---|---|---|
| Figura woskowa | 60 | 3 | 1 | 9 pocisków: 0,45 + 0,6 ≈ 1,05 s | ≈ 1,7 s płonięcia |
| Raptor | 25 | 2 (1 w czaszkę) | 1 | 4 pociski (3 w czaszkę): 0,45 + 0,2 ≈ 0,65 s | wybuch + 1 s |
| Portret | 40 | 2 (1 w oko) | 1 | 6 pocisków: 0,45 + 0,35 ≈ 0,8 s | wybuch + 3,3 s |
| Rycerz (tarcza z przodu) | 180 | 9 | 2 | 26 pocisków z boku: 0,45 + 1,8 ≈ 2,25 s | — (płonięcie przechodzi pod tarczą) |

Amunicja na start nocy: kartaczownica 120 w pojemniku + 60 zapasu (≈ 13 s ognia; pusty pojemnik = 0,35 s przerwy na nową taśmę, bez niej z „Dłuższą taśmą”), rakietnica 1 w lufie + 4 race. Zbiory: taśma 50, race 3 (`Museum.LOOT_AMOUNTS` — do podpięcia przez kontroler, patrz niżej). „Pojemne kieszenie” mnożą też zapas na start nocy i każde pudełko (×1,25 / ×1,5, zaokrąglone).

## Haczyki do podpięcia (I1 / kontroler)

- **Ekspozycja z łańcuchem**: `ChainedDisplay.create(Transform3D)` — początek na podłodze w środku postumentu, -Z (tabliczka) do sali, obrys 1,9 × 1,1 m, wys. ok. 1,9 m. Propozycja w zbrojowni: (30, 0, 7) z obrotem +π/2 (tabliczka w stronę drzwi z holu), między stojakami zbroi. Sygnały `chain_broken`, `taken`.
- **Szafka ratunkowa**: `EmergencyCabinet.create(Transform3D)` — początek w środku tylnej ścianki na powierzchni ściany (ok. 1,4 m nad podłogą), -Z do sali. Propozycja w dioramie: ściana od holu (z = 24), (5; 1,4; 24), obrót π (przodem do dioramy) — wilki w 16 m budzą się przy zbiciu. Sygnały `smashed`, `taken`.
- **Portrety**: `Portrait.create_on_wall(Transform3D, id)` i `WallPainting.create(Transform3D, id)` — początek w środku płótna na powierzchni ściany, -Z ze ściany; rama 1,12 × 1,37 m. Warianty: `PaintingArt.ids()` (10). Propozycja: 8–10 miejsc na obrazy w galerii i na antresoli, `NightDirector` losuje z nich 2–4 portrety (ziarno nocy), resztę `WallPainting`. Portrety zastępują w tych miejscach elementy `&"painting"` zestawu poziomu.
- **Raptory**: rodzaj `&"raptor"` w `NightSpawner.make()` / `Museum._make_exhibit()` → `Raptor.new()`; lepiej stado ze slotu: `RaptorPack.spawn(parent, slot.position, 3 lub 4 (rng nocy), gracz, awake)` (strony flankowania ustawia samo). Hol („Velociraptor — stado”) i antresola.
- **Ryk T-Reksa**: `boss.summon = RaptorPack.summoner(exhibits_root, punkty, gracz, <dotychczasowe przywołanie figur>, 0.5, RunState.rng)` — T-Rex woła przywołanie od fazy 2, więc 50/50 raptory/figury zgodnie z §2.1. Pliki T-Reksa bez zmian.
- **Czujne ucho, drugi oddech, magnes**: podpięte przez gracza (`Player.apply_upgrades`), nic do zrobienia.
- **Łup**: `Pickup.Type.RIFLE` (50) i `Pickup.Type.FLARES` (3) — po przeglądzie 1.10; pierwotnie 60 i 2. Propozycja wag `NightDirector.LOOT`: `bullets 38, shells 20, rifle 12, flares 8, medkit 22`; muzeum zamienia `rifle` → `bullets` i `flares` → `shells`, dopóki strażnik nie ma danej broni (amunicja nigdy nie jest bezużyteczna).
- **Oprawa (identyfikatory proponowane)**: `vm_gatling` (węzły `model`, `barrels`, `barrel_0..5`, `crank`, `belt`, `Muzzle`), `vm_flare` (`model`, `barrel`, `shell`, `Muzzle`), `raptor` (`pelvis`, `neck`, `head`, `jaw`, `arm_l/r`, `leg_l/r`, `tail_1..4`), płótna `portrait_<id>` + model ramy, `chained_display`, `emergency_cabinet`, `ammo_rifle`, `ammo_flares`.
- **Dźwięk**: nowe nazwy w `Sfx.SOUNDS` (zadanie 2); pętle `gatling_spin` i `gatling_rattle` grają przez `GatlingView`.

## Poprawki po przeglądzie (1.10)

Druga runda przeglądu, sekcje R3 (zawartość i balans) i R4 (rigi i wydajność oprawy) oraz NI4 z R1. Gałąź z `etap-1a-piaskownica` @ `dc1d39b`, na końcu scalona z jej nowszym stanem (`2fdb8c9`: poprawki nocy i świata). Pomiar zacięć: nowe `bash tools/run_hitch.sh [--warm]` (okno 1920 × 1080 bez dźwięku i bez vsync; wynik w `tests/_out/hitch/`).

**Do podpięcia przez kontroler (pliki poza tą gałęzią)**
- **Rozgrzewka na start nocy** — jedna linia na końcu `Museum._ready()` (pod czarnym przejściem sceny): `Fx.warm_up(self, player.camera)`. Można wołać dwa razy (kolejka cięć jest już pusta, nowa rozgrzewka zastępuje trwającą); bez okna (testy) tylko tnie.
- **Balans łupu** — `Museum.LOOT_AMOUNTS`: `&"rifle": 50` (było 60), `&"flares": 3` (było 2). „Pojemne kieszenie” mnożą te ilości same (`Pickup.apply_to`).

**R4 — rigi i wydajność**
- **AR1:** świt zatrzymuje też model: `Enemy.freeze()` wyłącza przetwarzanie rigu, a `ExhibitRig` nie pozuje zamrożonego eksponatu (wcześniej skamieniały wilk biegł dalej w miejscu).
- **AR4 + AR6 (zacięcia):** `Fx.warm_up(root, camera)` = `MeshShards.drain()` (wszystkie zakolejkowane cięcia odłamków od razu: T-Rex ok. 170 ms, czaszka 35 ms — teraz pod czarnym ekranem, nie w walce) + `ShaderWarmUp`: przed kamerą na 3 klatki staje mała kopia każdego materiału z `ArtLibrary.cached_materials()` (na siatce, na której naprawdę jest rysowany; odłamki i kości T-Reksa także na wyciętym kawałku — inny układ wierzchołków), modele, które noc pokazuje dopiero później (raptor z ryku, łupy, raca), cząstki Fx (zwykłe i świecące), kawałek gruzu, smuga, dziura po kuli i plama farby (atlas naklejek), błysk, pociski w locie (raca, odłamek popiersia, plwocina), iskry, płomień i smuga racy, dym kartaczownicy, drobinka Pyłu. Zamiast przenoszenia cięć na `WorkerThreadPool` albo pieczenia offline wystarczyło przesunąć je pod czarny ekran (koszt wywołania ok. 0,4 s przy budowie nocy).
- **AR5:** liczba plasterków części liczona raz, przy `attach()`, z wymiarów w skali spoczynkowej (bez obrotu, pozy i opadania topniejącego wosku): cięcie przygotowane zawczasu jest tym, którego używa ciężkie zabójstwo (`ExhibitRig.slice_count()`). Portret tnie zawczasu obie liczby drzazg ramy (6 i 8). Kolejka cięć bez duplikatów (dwadzieścia wilków kolejkuje każde cięcie raz).
- **AR7:** shader odłamków nie odwraca już normalnej tylnej ściany drugi raz (Godot robi to sam); zostaje przyciemnienie wnętrza ×0,3.
- **AR15:** `ArtLibrary.exhibit()` ubiera model od razu materiałami eksponatu (bez nieużywanych materiałów ORM) i od razu robi ich dwustronny wariant dla odłamków.
- **AR16:** `ViewmodelRig` przetwarza się tylko widoczny (broń w ręku).
- **Warstwy widoku z pierwszej osoby (prośba kontrolera):** siatki broni, błysk lufy i dym kartaczownicy tylko na warstwie 20 (`ArtLibrary._make_viewmodel`, `ContentViewmodels`, `GatlingDriver`), zgodnie z `Viewmodels.first_person_layer`.

**R3 — zawartość**
- **CC1 (krytyczne):** `Hitscan.sphere_hurtboxes` pyta o 32 wyniki naraz i powtarza zapytanie bez znalezionych już stref (`exclude`), aż partia wróci niepełna; każda strefa raz, najbliższe pierwsze. Kości T-Reksa mają strefy z otoczek wypukłych (`create_convex_shape`) — **poza klatką żeber**, która zostaje dokładną siatką: otoczka zamknęłaby szczeliny między żebrami, przez które strzela się w kryształ (testy „między żebrami” i „otwarta pierś z przodu” przechodzą). Testy regresji: trzy strefy z siatki obok trzech małych kul (wszystkie znalezione, każda raz) i wybuch racy między nogą T-Reksa a figurą woskową (figura dostaje pełne 40).
- **CI1:** model raptora rzuca 7 cieni; greybox (gdy modelu brak) — tylko miednica, czaszka, uda i golenie (6 z ok. 80 brył).
- **CI2:** „Pojemne kieszenie” mnożą też zapas na start nocy (`Loadout`, ograniczony do maksimum) i każde pudełko amunicji (`UpgradeEffects.spare_ammo`); opis ulepszenia zaktualizowany.
- **CI3:** pusty pojemnik kartaczownicy bierze następną taśmę w 0,35 s (`WeaponData.belt_change_time`; liczone jako przeładowanie — HUD i opuszczenie broni to pokazują, lufy kręcą się dalej, słychać przeładowanie); „Dłuższa taśma” daje 200 naboi i podaje taśmę bez przerwy. Opis zaktualizowany.
- **CI4:** „Czujne ucho” ostrzega o ataku poza polem widzenia: połowa poziomego kąta kamery (z proporcji okna) + 10° (przy 70° w pionie i 16:9 — ok. 61°), nie od 90°. Opis: „poza twoim polem widzenia”.
- **CM1:** tyknięcia płonięcia (`DamageInfo.periodic`) spadają pionowo w dół (przechodzą pod tarczą rycerza) i nie dają znacznika trafienia, brzęku tarczy ani dźwięku trafienia (także na kościach T-Reksa); tyknięcie, które niszczy eksponat, zgłasza się jak każde zabicie.
- **CM2:** raca i płonięcie przypisują trafienie `null`, gdy strzelca już nie ma (koniec nocy w locie racy).
- **CM3:** kartaczownica zwalnia strażnika tylko, gdy ma czym strzelać; spowolnienia razem nigdy poniżej 50% (`Player.MIN_SPEED_FACTOR`: kartaczownica w plamie farby = 0,5, nie 0,39); **zryw przy kręceniu korbą jest dozwolony** i ma pełną prędkość.
- **CM4:** co drugi pocisk kartaczownicy przynosi iskry, dziurę i światło wylotu (`WeaponData.effects_every`, `DamageInfo.effects`; dotyczy też trafień w eksponaty i w kryształ/kości T-Reksa) — trafienie zawsze się liczy.
- **CM5:** uśpiony portret nie ma ciała (`collision_layer` 0: raca trafia płótno jak ścianę, nie pali go ani nie rani); po wysunięciu ciało na warstwie wrogów, ale z wyjątkiem kolizji ze strażnikiem — rama na wysokości głowy go nie zatrzymuje. Śpiący portret nie robi kroku fizyki.
- **CM6:** trasa flankowania raptora na warstwie chodzenia (`LevelNavigation.WALK_LAYER` jawnie); po zakończeniu flankowania od razu planuje do strażnika (osiągalność wiadoma przed skokiem).
- **CM7:** `raptor_hiss` może grać w 4 kopiach (`Sfx.COPIES`) — syczy całe stado.
- **CM8:** dziewiąta raca przygasza światło najstarszej, ale ta dopala swój eksponat do końca (po ciemku), dopiero potem znika.
- **CM9:** zepsuta kontynuacja linii w `player.gd` (i taka sama w nowym `Enemy.resting()`) poprawiona.
- **BALANCE:** kartaczownica startuje z 60 nabojami zapasu (było 120), taśma z łupu 50 (było 60 — `Museum.LOOT_AMOUNTS`, patrz wyżej; arena deweloperska już 50), rakietnica startuje z 4 racami zapasu (było 3), paczka rac z łupu daje 3 (było 2 — j.w.). Tabela „Balans” wyżej uwzględnia rozkręcenie i rozrzut.

**R1 — NI4 (koszt procesora walki)**
- `EnemyCrowd.push_for` czyta pozycje goniących raz na klatkę fizyki (`EnemyCrowd.chasers()`), posortowane do siatki komórek o boku promienia rozpychania: każde pchnięcie patrzy na 9 sąsiednich komórek, zamiast pytać każdy węzeł o pozycję. Pomiar w izolacji (30 / 44 goniących): **594 → 258 µs** / **1245 → 380 µs** na klatkę fizyki.
- Śpiący eksponat stojący na podłodze pomija `move_and_slide` (`Enemy.resting()`; trafienie albo przebudzenie kończy spoczynek) — 30 śpiących: ok. 145 µs mniej na klatkę.

**Testy niestabilne (FLAKY)**
- `test_bust` (dryf po ciosie): mierzony bez własnego krążenia popiersia (losowa strona i czas zwrotu dodawały się do dryfu albo go zjadały) — sprawdza sam odrzut.
- `test_acquisition` (szafka): oba eksponaty woskowe krótkowzroczne (pierwsze sprawdzenie wzroku wypada losowo w ciągu 0,2 s), a bliski sprawdzony jako śpiący przed zbiciem szybki — budzi go tylko huk.

**Pomiary (RTX 2080 Ti, okno 1920 × 1080, bez vsync; w tle procesy innych agentów — czasy klatek orientacyjne)**
| | przed (`dc1d39b`, 4 przebiegi) | po (ta gałąź z `Fx.warm_up`, 5 przebiegów) |
|---|---|---|
| Budowa nocy + rozgrzewka | 1,9–2,9 s budowy | budowa bez zmian + 0,40–0,41 s `Fx.warm_up` |
| Pierwsze 5 s nocy | pierwsza klatka 2,2–2,4 s (pierwsze rysowanie sceny, pod czarnym ekranem), potem 2–4 zacięcia 34–53 ms; kompilacje potoków: 18 DRAW, 106 SURFACE | pierwsza klatka 2,4–2,5 s, potem najwyżej jedno zacięcie ok. 35 ms; 18 DRAW, 154 SURFACE (kopie rozgrzewki) |
| Pierwsza walka w holu (6 s: rozerwanie po jednym eksponacie każdego rodzaju, kartaczownica, raca, strzelba) | 357–384 ms przy pierwszym rozerwanym wosku, 45–54 ms przy rycerzu, 67–72 ms przy pierwszej racy; 36 SURFACE, 5 MESH | **0 zacięć**, najgorsza klatka 21–24 ms; 0 SURFACE, 0 MESH, 0 DRAW |

Bez rozgrzewki (same pozostałe poprawki) walka nadal ma 224 ms / 45 ms / 67 ms — znikają dopiero z `Fx.warm_up`. Koszt klatki fizyki w walce w holu (30 eksponatów, 28 goni) w całości: 4,4–5,6 ms przed i po — w granicach szumu (maszyna dzielona z innymi agentami; po scaleniu noc ma więcej logiki); dlatego NI4 zmierzony osobno (wyżej). `run_night.sh dry` po scaleniu: 6,45 ms skryptów na tik (44 eksponaty), wobec 6,7 ms zmierzonych przed NI4 (NIm9).

**Odstępstwa i decyzje**
- Strefy T-Reksa: otoczki wypukłe wszędzie poza żebrami (patrz CC1); pętla zapytania i tak gwarantuje, że wiele trójkątów żeber nie wypycha innych stref.
- Zmiana taśmy liczona jako przeładowanie (`is_reloading()`): R nadal nic nie robi, przełączenie broni ją przerywa, a wraca przy następnym tiku (taśma wchodzi także w kaburze).
- Tyknięcie, które zabija, pokazuje znacznik zabicia (płomień dokończył robotę); pozostałe tyknięcia są ciche.
- NI4: siatka zamiast samej migawki — przy ciasnym tłumie zysk z siatki jest mały (258 vs 264 µs dla 30), przy rozproszonym rośnie.

**Wyniki:** po scaleniu z `etap-1a-piaskownica` (`2fdb8c9`) cały zestaw zielony trzy razy z rzędu: **1062 testy**, bez linii `ERROR` i wycieków; `run_content.sh --dry` i `run_night.sh dry` przechodzą. W jednym wcześniejszym przebiegu (przed ostatnimi zmianami) raz padł `test_music::test_resync_pulls_a_drifted_stem_back` (odczyt pozycji odtwarzania między miksami wątku dźwięku — poza zakresem tej gałęzi; do obserwacji).
