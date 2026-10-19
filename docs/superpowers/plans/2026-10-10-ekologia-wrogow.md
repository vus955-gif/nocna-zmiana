# Ekologia wrogów — rutyny, reakcje na zdarzenia, role bojowe (Piętro I)

> **Dla wykonawcy-agenta:** wymagany pod-skill: superpowers:executing-plans (TDD, commit po zadaniu). Kroki mają pola `- [ ]` do odhaczania.
>
> Stan: 19 października 2026 (zadania 0–15 zrobione; poprawki po przeglądzie 19.10 — patrz „Poprawki po przeglądzie”; plan założony 10.10). Wykonawca: Claude, drzewo robocze `.claude/worktrees/guard-lamassu`, gałąź `enemy-ecology` od `pietro-1` @ `d540ea0`.
> Autorytet: `docs/backlog-pietro1.md` punkty **#8** (rutyny i „inteligencja”, integracja z otoczeniem), **#24** (reakcje na zdarzenia: hałas, strzały, wybuchy, śmierć sąsiada, otwarcie drzwi), **#25** (konkretne role bojowe, nie tylko HP); `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` §7.2 (percepcja, terytoria, limit polujących — **nie wracamy do hordy**: 360°/25 m, łańcuchowe budzenie bez limitu, idealne śledzenie); plan `2026-10-02-p1-percepcja.md` (stany mózgu, liczby). **Odłożone (#13):** trudność i ulepszenia — nie dotykamy `DifficultyRules`, Pyłu ani cen.

**Cel:** wrogowie nie „stoją, aż się podejdzie”. Każdy rodzaj eksponatu ma (a) kontekst wystawienniczy, (b) czytelną przemianę przy pobudce, (c) rutynę na jawie bez polowania, (d) powrót na posterunek, (e) reakcje na zdarzenia w otoczeniu — stopniowane odległością i rodzajem, z limitem na zdarzenie, (f) jawnie nazwaną rolę bojową (dane), a reżyser nocy miesza role w sali. Wszystko czytelne (zapowiedzi ≥ 0,6 s), uczciwe, bez hordy i tanie na klatkę (rutyny tykają co 0,5 s i tylko blisko strażnika).

**Architektura:** (1) **mózg** (`EnemyBrain`, czysta logika) dostaje ramy rutyn: *beat* (patrol z posterunkami: postój + kierunek patrzenia), *roam* (włóczęga w promieniu od domu), stan **FLEE** (ucieczka od punktu, potem do domu); (2) **role i reakcje** w danych (`EnemyRoles`: rodzaj → rola, ciekawość, płochliwość, stróżowanie drzwi, gromadzenie się) i czysta logika decyzji (`ReactionRules.decide`) z **limitem badających na zdarzenie** (`INVESTIGATE_CAP` = 3, najbliższy ciekawy zawsze idzie, dalsi tylko odwracają głowę); (3) **zdarzenia** przez istniejącą szynę hałasu `PerceptionWorld.noise` — nowe źródła: `fall` (upadek eksponatu, `Events.enemy_destroyed`), `door` (otwarcie drzwi, `Door`), `blast` (wybuch w miejscu wybuchu, `Blast`), ślad strażnika (`PerceptionWorld` — okruchy pozycji); (4) **rutyny w `Enemy`**: tyk co `ROUTINE_INTERVAL`, tylko gdy strażnik ≤ `ROUTINE_RANGE` (LOD), *stir* (poruszenie we śnie: eksponat obraca się i przysuwa, gdy strażnik **nie patrzy**), hak `_routine_tick()` dla podklas; (5) po rodzaju: wosk (tableau/poruszenie), wilk (włóczęga po dioramie + węszenie śladu), rycerz/samuraj (posterunek przy drzwiach, obchód, reakcja na drzwi), popiersie (szept-alarm: wsparcie), raptory (jeden „naganiacz” prosto + flankujący), mumia (wraca do grobowca, śpi i odzyskuje zdrowie), skarabeusze (strumień wzdłuż ścian, gromadzą się na padłym, uciekają od wybuchu), hoplici (linia: badają razem), reliefy (wracają w płytę), księgi (płoszą się od strzału), wschód (dane roli, reakcje przez ramy).

**Technologia:** Godot 4.7.2, GDScript statycznie typowany; testy `bash tools/run_tests.sh --filter=<nazwa>` (bez okna, `--fixed-fps 60`); bez dźwięku (żadnych nowych plików wav — używamy istniejących `suspicion`, `bust_grind`, `portrait_creak`, `growl`, `relief_scrape`).

**Zasady pracy (od kontrolera):** tylko drzewo `guard-lamassu` / gałąź `enemy-ecology`; bez okien i dźwięku; bez push; bez pod-agentów; commit po każdym zadaniu (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); przed raportem `git merge pietro-1` i pełny zestaw.

---

## Tabela luk (stan przed pracą)

Legenda: ✔ jest · ◐ częściowo · ✘ brak. Kolumny: (a) kontekst wystawienniczy, (b) czytelna pobudka, (c) rutyna na jawie bez polowania, (d) powrót na posterunek, (e) reakcje na zdarzenia, (f) rola bojowa.

| Rodzaj | (a) | (b) | (c) | (d) | (e) | (f) | Uwagi |
|---|---|---|---|---|---|---|---|
| figura wosk. (`wax`) | ◐ posterunek + zwrot | ◐ oczy, drgnięcie głowy | ◐ tylko slot czuwający: pętla patrolu | ✔ RETURN→DORMANT | ◐ słyszy hałas, budzi ≤ 2 sąsiadów | ✘ niejawna (melee) | nic we śnie; stoi, aż podejdziesz |
| wilk (`wolf`) | ◐ diorama | ◐ warknięcie | ◐ pętla patrolu | ✔ | ◐ hałas | ✘ (skoczek) | nie węszy, nie krąży |
| rycerz (`knight`) | ◐ posterunek | ✘ | ◐ pętla patrolu | ✔ | ◐ hałas | ✘ (tank) | nie pilnuje drzwi, nie reaguje na drzwi |
| popiersie (`bust`) | ◐ na podłodze/cokole | ✔ zgrzyt, unosi się | ◐ pętla | ✔ | ◐ hałas | ✘ (ranged) | brak roli wsparcia/alarmu |
| raptory (`raptor`) | ◐ krąg stada | ✔ skrzek, zbiórka stada | ✘ stado trzyma posterunek | ✔ | ◐ zbiórka przy polowaniu | ◐ flankują wszyscy | brak „naganiacza” |
| portret (`portrait`) | ✔ ściana | ✔ oczy śledzą, rama wychodzi | — (czuwa na stałe) | — | ✘ z założenia (tylko wzrok) | ✘ (ranged) | bardzo udany (właściciel) |
| mumia (`mummy`) | ✔ grobowiec | ✔ wieko, wyjście | ✘ | ◐ wraca na posterunek, **nie kładzie się** | ◐ hałas; ogień = panika | ✘ (melee + bicz) | brak „odpoczynku” |
| skarabeusze (`scarabs`) | ◐ kopczyk | ✔ wzlot chmury | ✘ | ✔ | ◐ hałas | ✘ (rój) | nie płyną wzdłuż ścian |
| hoplita (`hoplite`) | ◐ posąg | ◐ zgrzyt | ◐ pętla; falanga tylko w polowaniu | ✔ | ◐ hałas | ◐ linia w walce | linia nie reaguje razem |
| relief: wojownik / lew | ✔ płyta w ścianie | ✔ pęknięcia, wyjście | ✘ | ◐ wraca pod ścianę, **nie wchodzi w płytę** | ◐ hałas; unik od celowania | ◐ harcownik / skoczek | |
| księgi (`books`) | ✔ półka | ✔ zsuwają się | ◐ krąg stada | ✔ na półkę (udane) | ◐ budzenie stadem | ◐ rój nurkujący | strzał ich nie płoszy |
| totem | ✔ słup | ✔ twarze od dołu | ✔ omiatanie | ✔ | ◐ hałas (INVESTIGATE bez ruchu) | ◐ wieżyczka | |
| jaguar | ◐ posąg | ✔ skrzyp głowy | ✔ oddech, przeniesienie ciężaru (rig) | ✔ | ◐ hałas | ◐ skoczek | |
| pies Fu | ✔ cokół + kula | ✔ łapa z kuli | ✔ oddech, kita | ✔ łapa na kulę | ◐ hałas | ◐ szarża/tank | |
| samuraj | ◐ stojak | ✔ kamae | ✘ | ✔ | ◐ hałas | ◐ tank/włócznia | jak rycerz |

**Wspólne luki:** brak reakcji na **upadek sąsiada**, **otwarcie drzwi**, **wybuch w jego miejscu** (strzał z racy jest słyszany u strażnika, nie tam, gdzie wybucha); hałas słyszany = **każdy** w zasięgu idzie badać (bez stopniowania, bez limitu — nie horda, bo to nie polowanie, ale zbieg 8 figur na jeden strzał); role tylko domyślne w liczbach.


## Tabela luk (stan po pracy, 18.10)

Ta sama legenda. Pogrubione = zmiana tej gałęzi; „bez zmian” = jak przed pracą.

| Rodzaj | (a) | (b) | (c) | (d) | (e) | (f) | Uwagi |
|---|---|---|---|---|---|---|---|
| figura wosk. (`wax`) | ◐ posterunek + zwrot | ◐ oczy, drgnięcie głowy | ✔ **we śnie: poruszenie, gdy strażnik nie patrzy (zwrot + ≤ 1,5 m ku niemu)**; czuwający: pętla patrolu; **czuwający reżysera** | ✔ | ✔ **stopniowane: strzał (część), upadek sąsiada (gromadzi się), drzwi (tylko patrzy); limit 3 / 20 m / 6 s** | ✔ **MELEE_PRESSURE** | |
| wilk (`wolf`) | ◐ diorama | ◐ warknięcie | ✔ **włóczęga 5 m po dioramie + węszenie śladu (nos przy ziemi; ślad ≥ 3 s, ≤ 6 m)** | ✔ | ✔ **węszy ślad (cicho, nie poluje); ucieka od wybuchu (0,5)** | ✔ **FLANKER** | |
| rycerz (`knight`) | ◐ posterunek | ✔ **gotowość: tarcza przed siebie, miecz cofnięty, hełm w górę, zbroja drży 0,5 s (rig; bez nowego dźwięku)** | ✔ **obchód z posterunkami 6–10 s, twarzą w kierunku posterunku** | ✔ | ✔ **drzwi: idzie do progu (0,6; nigdy „na pewno”) i wraca na obchód** | ✔ **TANK** | |
| popiersie (`bust`) | ◐ podłoga/cokół | ✔ zgrzyt, unosi się | ✔ **we śnie obraca się na cokole (nie schodzi)**; pętla | ✔ | ✔ | ✔ **SUPPORT: alarm co 8 s (≤ 2 śpiących, cicho; nie, gdy sala już poluje)** | |
| raptory (`raptor`) | ◐ krąg stada | ✔ skrzek, zbiórka | ✔ **włóczęga 2,5 m** | ✔ | ✔ zbiórka stada; płochliwe 0,2 | ✔ **naganiacz (najbliższy, prosto) + flankujący ±1; role rozdawane od nowa przy każdym nowym polowaniu; padły naganiacz od razu zastąpiony** | zapowiedź skoku **0,6 s** (było 0,3 — podniesiona po przeglądzie) |
| portret (`portrait`) | ✔ ściana | ✔ | — | — | ✘ z założenia | ✔ RANGED (dane) | bez zmian |
| mumia (`mummy`) | ✔ grobowiec | ✔ wieko, wyjście | ✔ **odpoczynek w grobowcu: 2,5 HP/s** | ✔ **kładzie się w otwartym grobowcu; nowa pobudka = wyjście od nowa** | ◐ hałas (0,3); ogień = panika | ✔ MELEE_PRESSURE (bicz) | nigdy czuwający |
| skarabeusze (`scarabs`) | ◐ kopczyk | ✔ wzlot chmury | ✔ **raz poruszone: strumień wzdłuż ścian sali** | ✔ | ✔ **gromadzą się na padłym, uciekają od wybuchu (0,8); przywołane nie uciekają** | ✔ **SWARM** | |
| hoplita (`hoplite`) | ◐ posąg | ◐ zgrzyt | ✔ **obchód z posterunkami** | ✔ | ✔ **linia (ten, który usłyszał, + 2 najbliższych) bada razem, rusza naraz** | ✔ **TANK (linia)** | |
| relief: wojownik / lew | ✔ płyta | ✔ pęknięcia | — (w płycie) | ✔ **wsuwa się z powrotem w płytę; pobudka = pęknięcia od nowa** | ✔ | ✔ RANGED / FLANKER | nigdy czuwający |
| księgi (`books`) | ✔ półka | ✔ | ◐ krąg stada | ✔ na półkę | ✔ **huk płoszy spokojne stado** | ✔ SWARM | nigdy czuwający |
| totem | ✔ słup | ✔ | ✔ omiatanie | ✔ | ✔ **tylko odwraca twarze (ciekawość 0)** | ✔ **TURRET** | |
| jaguar | ◐ posąg | ✔ skrzyp głowy | ✔ oddech + **włóczęga 3 m** | ✔ | ✔ | ✔ **FLANKER** | |
| pies Fu | ✔ cokół + kula | ✔ łapa z kuli | ✔ oddech, kita + **obchód z posterunkami** | ✔ | ✔ **drzwi (0,5)** | ✔ **TANK (szarża)** | |
| samuraj | ◐ stojak | ✔ kamae | ✔ **obchód z posterunkami** | ✔ | ✔ **drzwi (0,6)** | ✔ **TANK (włócznia)** | |

**Wspólne po pracy:** upadek sąsiada, otwarcie drzwi (w dwóch salach, które drzwi łączą) i wybuch słychać w ich miejscu; reakcje stopniowane rodzajem i odległością (patrzy / bada / ucieka), limit 3 badających na miejsce i czas; drzwi i upadek nikogo nie posyłają „na pewno”; rutyny tylko blisko strażnika (36 m i ≤ 2 przejścia); każdy rodzaj ma rolę w danych (`EnemyRoles`). Kolumna (a) — kontekst wystawienniczy — to sprawa ubrania sal (maty, tabliczki), nie tej gałęzi.

---

## Liczby (punkt startowy do strojenia)

| Co | Wartość | Skąd |
|---|---|---|
| **LOD rutyn** | tyk co **0,5 s** (rozrzut ±20 % na eksponat), tylko gdy strażnik ≤ **36 m** **i** sala eksponatu ≤ **2 przejścia** od sali strażnika (`PerceptionWorld.ROUTINE_HOPS`, jak `RoomCuller`; liczone raz na zmianę sali) | koszt; `FAR_DISTANCE` 32 m wzroku |
| **Poruszenie we śnie (stir)** | strażnik od max(4 m, **zasięg wzroku śpiącego + 1 m**) do 20 m — bliżej eksponat zamiera tam, gdzie patrzył (obrót nie może mu dać „oczu z tyłu głowy”); nie, gdy strażnik jest w schronie; **poza polem widzenia strażnika** — dla kamery strażnika: szersza połowa kadru (fov, `keep_aspect`, proporcje okna) **+ 10°**, nie mniej niż 40° (70° pionowo przy 16:9 → ok. 61°); cel bez kamery: ±40° od jego −Z: co tyk obrót ku niemu o ≤ **0,35 rad** i przesunięcie o **0,25 m** (po navmeshu), najwyżej **1,5 m** od domu; gdy patrzy — zamarza | uncanny; nie zwiększa wzroku (dalej `DORMANT_SCALE`) |
| **Limit badających** | **3** na zdarzenie (najbliżsi), najbliższy ciekawy **zawsze — przy zwykłym hałasie** (strzał, krok, szkło, wybuch); przy **drzwiach i upadku nie ma gwarancji** (rzut decyduje); reszta tylko odwraca głowę (SUSPICIOUS → powrót), **po cichu** (bez budzenia sąsiadów). Słuchaczami nie są: zniszczeni / w kolejce do usunięcia, zamrożeni, polujący i ogłuszeni (liczą się jako „obudzeni”, nie zajmują miejsca) | §7.2 bez hordy; przegląd 19.10 |
| **Limit w czasie i miejscu** | te same **3** na wszystkie hałasy w promieniu **20 m** przez **6 s** (`ReactionRules.SEND_AREA` / `SEND_WINDOW`); liczą się tylko wstający z odpoczynku (śpi / obchód / tylko patrzy) — eksponat już na nogach idzie za nowym hałasem „za darmo”; bez wolnego miejsca nawet najbliższy tylko patrzy. Seria z kartaczownicy = tyle co jeden strzał | dodane po przeglądzie: każdy strzał serii to osobne zdarzenie |
| **Szansa zbadania** | `ciekawość × (0,35 + 0,65 × bliskość)`; bliskość = 1 − dystans / (zasięg × głośność) | #24 „przynajmniej czasami” |
| **Upadek eksponatu** (`fall`) | hałas **12 m** w miejscu padłego; rodzaje „gromadzące się” idą (p = 0,5 + 0,5 × bliskość, **bez gwarancji**), inne odwracają głowę; **twardo śpiący (noc 1, `sound_asleep`) go nie słyszą** | #24 |
| **Drzwi** (`door`) | hałas **10 m** z progu (`Events.door_creaked`: **należy do dwóch sal, które drzwi łączą**, nie do ściany — środek progu leży w żadnej sali, więc słychać go było „znikąd” przez ściany), przy otwarciu nie-natychmiastowym; stróże (rycerz, samuraj **0,6**, pies Fu **0,5**, hoplita **0,4**) idą z p = `stróżowanie × √bliskość`, **bez gwarancji**, inni patrzą; **twardo śpiący go nie słyszą** | #24; waga 0,9 → 0,6 po przeglądzie |
| **Wybuch** (`blast`) | hałas w miejscu wybuchu: **30 m** (`BLAST_NOISE`, rakieta/wybuchy), **15 m dla rakownicy** (`PerceptionRules.blast_noise(&"flare")` — tyle, ile jej strzał); płochliwi (p = płochliwość × bliskość): **FLEE**; inni jak strzał | #24; flara budziła wszystko w 30 m |
| **FLEE** | bieg **8 m** od punktu (pełne tempo), najwyżej 4 s, potem RETURN do domu; nie słyszy w trakcie; **przywołani (relentless) nie uciekają** | nowy stan mózgu |
| **Beat (obchód)** | postój na punkcie **6–10 s** (rycerz), twarzą w kierunku posterunku (dom: `home_yaw`; dalsze punkty: od domu na zewnątrz); między punktami tempo 0,45 | §7.2 patrole |
| **Roam (włóczęga)** | punkt losowy w promieniu **5 m** od domu (wilk; raptory 2,5 m), w sali domu i na navmeshu, postój 2–5 s | |
| **Ślad strażnika** | okruch co **1,5 m** marszu, żyje **25 s**, ≤ 24; wilk na jawie co 3 s węszy: najświeższy okruch **starszy niż 3 s** (`SNIFF_MIN_AGE`) i **≤ 6 m** (`SNIFF_RANGE`) w granicach → INVESTIGATE (cicho) | wilk; było 10 m i bez wieku: „wiem, gdzie stoisz” przez ścianę |
| **Alarm popiersia** | polując z widokiem, co **8 s** budzi ≤ `CHAIN_MAX` (2) śpiących w sali w zasięgu 8 m z linią wzroku → badają (cicho); tylko gdy polujących < połowa limitu | wsparcie |
| **Stado raptorów** | przy starcie **każdego nowego polowania** (nikt ze stada jeszcze nie poluje) najbliższy strażnika = **naganiacz** (`flank_side` 0, prosto), reszta na przemian ±1; padł naganiacz → polująca reszta od razu wybiera nowego | #25 flanker; żyjący naganiacz poprzedniego polowania zostawał nim na zawsze |
| **Mumia: odpoczynek** | po RETURN do grobowca kładzie się (DORMANT w grobowcu), **odzyskuje 2,5 HP/s** (było 4) we śnie; z otwartym wiekiem widzi jak śpiący eksponat (bez wieka: tylko 1,5 m) | #8 „mumia z sarkofagu” |
| **Skarabeusze: strumień** | na jawie bez polowania trasa wzdłuż ścian sali (punkty 0,4 m od ścian — w narożniku od obu, cofnięte wzdłuż promienia; tylko punkty na navmeshu sali), tempo 0,45 (PATROL); `fall` → gromadzą się; `blast` → FLEE | #8 |
| **Hoplici: linia** | gdy hoplita zostaje wysłany badać (od razu przy hałasie, nie po swoim namyśle), zabiera ≤ **2** najbliższych spokojnych towarzyszy w 8 m z sali (cicho; poza limitem 3 — jak stado); towarzysz, który widział strażnika, zostaje przy swoim; **wezwani nie wzywają własnych sąsiadów** (linia = 3 ludzi, nie cały rząd), wołający raz na wyprawę, nie ten, który sam widział strażnika | #25; przegląd 19.10: rekurencja robiła z rzędu 6 jedną linię |
| **Relief: powrót w płytę** | DORMANT po powrocie (z płytą, nie stela): wsuwa się w pustą kieszeń płyty (`SINK_TIME` 0,5 s), figura znów w płycie; pobudka = pęknięcia jak za pierwszym razem | #8 |
| **Księgi** | huk (`ReactionRules.is_bang`: wybuch albo broń ≥ 12 m) słyszany przez stado krążące spokojnie → spłoszenie (`BookFlock.spook`, 0,8 s: szerszy krąg, nikt nie nurkuje); polujące stado nie płoszy się od strzałów | #24 |
| **Reżyser: mieszanie ról** | po losowaniu zestawów, osobnym RNG (ziarno nocy ⊕ sala): w sali z ≥ **`watcher_room(noc)`** wylosowanymi eksponatami (**5 w nocy 1, 3 od nocy 2**) i **bez czuwającego** — jeden (stróż/skoczek/melee, nie wsparcie; nigdy zasadzka, stado, rój ksiąg ani rodzaj, którego sen jest ekspozycją: mumia w grobowcu, relief w płycie) **czuwa** (obchód/włóczęga); noc 1: na trasie z budki **bez czuwających** (tylko patrole poziomu, ≤ 2) | #25, #8; reszta losowania bez zmian |

### Role (dane, `EnemyRoles.ROLES`)
(Kolumna „rutyna na jawie” opisuje, co robi rodzaj — w danych jej już nie ma: pole `idle` i enum `Idle` nie napędzały niczego i zostały usunięte po przeglądzie 19.10; rutynę wybierają `roam`, trasa i podklasy.)
| rodzaj | rola | ciekawość | płochliwość | stróż drzwi | gromadzi się | rutyna na jawie | rutyna we śnie |
|---|---|---|---|---|---|---|---|
| wax | MELEE_PRESSURE | 0,6 | 0 | 0 | tak | beat | stir |
| wolf | FLANKER | 0,9 | 0,5 | 0 | nie | roam + węszenie | — |
| knight | TANK | 0,5 | 0 | 0,6 | tak | beat (posterunek) | — |
| bust | SUPPORT | 0,3 | 0 | 0 | nie | patrol (lot) | stir (obrót na cokole) |
| raptor | FLANKER (szkło) | 0,8 | 0,2 | 0 | nie | roam 2,5 m | — |
| portrait | RANGED | 0 | 0 | 0 | nie | — | — |
| mummy | MELEE (bicz) | 0,3 | 0 | 0 | nie | — | odpoczynek w grobowcu |
| scarabs | SWARM | 0,5 | 0,8 | 0 | tak | strumień | — |
| hoplite | TANK (linia) | 0,6 | 0 | 0,4 | tak | beat; linia | — |
| relief_warrior | RANGED (harcownik) | 0,5 | 0 | 0 | nie | — | w płycie |
| relief_lion | FLANKER | 0,8 | 0,3 | 0 | nie | — | w płycie |
| books | SWARM | 0,4 | 0,7 (spłoszenie) | 0 | nie | krąg | półka |
| totem | TURRET | 0 (tylko patrzy) | 0 | 0 | nie | omiatanie | — |
| jaguar | FLANKER (skoczek) | 0,8 | 0 | 0 | nie | roam 3 m | — |
| fu_dog | TANK (szarża) | 0,4 | 0 | 0,5 | nie | beat | — |
| samurai_armor | TANK (włócznia) | 0,5 | 0 | 0,6 | tak | beat | — |

---

## Pliki

| Plik | Odpowiada za |
|---|---|
| `src/enemies/enemy_roles.gd` (nowy) | `EnemyRoles`: role, profile reakcji i rutyn po rodzaju; `kind_of(enemy)` (po nazwie klasy, z dziedziczeniem) |
| `src/enemies/perception/reaction_rules.gd` (nowy) | `ReactionRules`: `Reaction {NONE, LOOK, INVESTIGATE, FLEE}`, `decide(source, profile, closeness, roll)`, `assign(candidates…)` z limitem i gwarancją najbliższego |
| `src/enemies/enemy_brain.gd` | stan `FLEE` (`flee(from)`), `patrol_dwell` / `patrol_yaw` (beat), `roam_radius` + `roam_point: Callable` (włóczęga), `post_yaw()` |
| `src/enemies/perception/perception_rules.gd` | `FALL_NOISE`, `DOOR_NOISE`, `in_view()`, `wall_route()` |
| `src/enemies/perception/perception_world.gd` | reakcje stopniowane w `noise()`, `enemy_destroyed` → `fall`, ślad strażnika (`trail()`, `freshest_crumb()`), `rooms_near` nie potrzebne (LOD po odległości) |
| `src/combat/blast.gd`, `src/level/door.gd`, `src/core/events.gd` | hałas wybuchu w jego miejscu (zasięg wg broni); skrzypnięcie drzwi (`Events.door_creaked` z salami drzwi) |
| `src/enemies/enemy.gd` | `react()`, tyk rutyn (`ROUTINE_INTERVAL`, `ROUTINE_RANGE`), stir, `_routine_tick()` hak, `_steer` dla FLEE i `post_yaw`, `kind()` |
| `src/enemies/wax_figure.gd`, `wolf.gd`, `knight.gd`, `bust.gd`, `raptor.gd`, `mummy.gd`, `scarab_swarm.gd`, `hoplite.gd`, `relief_wall.gd` (+ `relief_warrior.gd`, `relief_lion.gd`), `flying_book.gd`, `samurai_armor.gd`, `fu_dog.gd`, `jaguar.gd` | rutyny i reakcje po rodzaju |
| `src/game/night_spawner.gd`, `src/game/night_director.gd`, `src/game/night_config.gd` | posterunki (dwell/yaw) z roli; mieszanie ról w sali (`Spawn.watcher`) |
| testy: `tests/integration/test_ecology_floor1.gd` (prawdziwe Piętro I: skrzypnięcie drzwi przez ścianę, brama Wielkiego Dziedzińca w nocy 1), `test_telegraphs.gd` (zapowiedzi ≥ 0,6 s), `tests/unit/test_enemy_roles.gd`, `test_reaction_rules.gd`, `test_enemy_brain.gd` (+beat/roam/flee), `test_night_director.gd` (+mix); `tests/integration/test_enemy_ecology.gd` (reakcje, stir, LOD), `test_wolf.gd` (+węszenie), `test_knight.gd` (+drzwi), `test_bust.gd` (+alarm), `test_raptor.gd` (+naganiacz), `test_mummy_tomb.gd` (+odpoczynek), `test_scarab_swarm.gd` (+strumień/gromadzenie), `test_hoplite.gd` (+linia), `test_relief.gd` (+powrót w płytę), `test_flying_books.gd` (+spłoszenie) | |

---

## Zadanie 0: ten plan
- [x] Zapisać plan, commit `Plan: enemy ecology (routines, event reactions, roles)`.

## Zadanie 1: `EnemyRoles` + `ReactionRules` (dane i czysta logika)
**Pliki:** `src/enemies/enemy_roles.gd`, `src/enemies/perception/reaction_rules.gd`; testy `tests/unit/test_enemy_roles.gd`, `tests/unit/test_reaction_rules.gd`.
- [x] Testy: każdy rodzaj z `NightSpawner.BUILDS` + `portrait` ma profil; `kind_of(SamuraiArmor.new())` = `samurai_armor` (nie `knight`), `kind_of(ReliefLion)` = `relief_lion`; `decide`: totem na strzał → LOOK; wosk tuż przy strzale (bliskość 1, rzut 0,1) → INVESTIGATE, daleko (bliskość 0,05, rzut 0,9) → LOOK; skarabeusze przy wybuchu (rzut 0,2) → FLEE; rycerz przy drzwiach (rzut 0,3) → INVESTIGATE, wosk przy drzwiach → LOOK; `assign` dla 6 kandydatów w jednym zasięgu: najwyżej 3 INVESTIGATE, najbliższy ciekawy zawsze INVESTIGATE, reszta LOOK.
- [x] Implementacja; `--filter=enemy_roles,reaction_rules` → zielono. Commit `Enemy roles and graded reaction rules`.

## Zadanie 2: mózg — beat, roam, FLEE
**Pliki:** `src/enemies/enemy_brain.gd`; test `tests/unit/test_enemy_brain.gd`.
- [x] Testy: rycerz na obchodzie (2 punkty, dwell 6 s, yaw posterunku) stoi 6 s zwrócony na `post_yaw()`, idzie do drugiego punktu, wraca; po hałasie bada i **wraca na obchód** (RETURN → PATROL, najbliższy punkt); roam: bez trasy, `roam_radius` 5 → kolejne cele w ≤ 5 m od domu, różne, filtr `roam_point` respektowany; `flee(from)`: stan FLEE, cel 8 m od punktu w stronę przeciwną, `walking()`, tempo 1,0; po dotarciu (lub 4 s) → RETURN → dom; `hear` w FLEE ignorowane; `is_active()` / `is_alerted()` zawierają FLEE.
- [x] Implementacja; `--filter=enemy_brain` → zielono. Commit `Brain: beats with posts, roaming, a flee state`.

## Zadanie 3: zdarzenia i reakcje w świecie
**Pliki:** `perception_rules.gd`, `perception_world.gd`, `blast.gd`, `door.gd`, `enemy.gd`; test `tests/integration/test_enemy_ecology.gd` (+ istniejące `test_perception.gd` zielone).
- [x] Testy (szara skrzynka, `brain.rng.seed` na eksponat): strzał 15 m od 6 figur → 1–3 badają (INVESTIGATE), ≥ 1 tylko odwraca głowę i wraca do snu, **nikt nie poluje**; upadek figury 5 m od dwóch śpiących → oba reagują, ≥ 1 idzie do padłego; otwarcie drzwi (`Door.open()` nie-natychmiastowe) 6 m od rycerza i figury → rycerz bada, figura patrzy (rzuty ustawione); `Blast.explode` 4 m od roju → rój FLEE i oddala się ≥ 4 m, potem wraca do domu; 20 eksponatów w 30 m od strzału → ≤ 3 badają, 0 polują („nic nie budzi całego piętra”).
- [x] Implementacja: `Enemy.react(point, room, reaction)`; `PerceptionWorld.noise` zbiera kandydatów (jak dziś), `ReactionRules.assign`, `hear` tylko dla zgodności; `_on_enemy_destroyed` (nie `fell_out`) → `noise(fall)`; `Door._arrived` (otwarcie, nie-natychmiastowe) → `noise_made(door)`; `Blast.explode` → `noise_made(blast)`.
- [x] `--filter=enemy_ecology,perception,lobby_perception,door,flare` → zielono. Commit `Event reactions: graded, capped; fallen exhibits, doors and blasts make noise`.

## Zadanie 4: rutyny w `Enemy` — tyk, LOD, poruszenie we śnie
**Pliki:** `enemy.gd`, `perception_rules.gd` (`in_view`), `wax_figure.gd`, `bust.gd`; test `tests/integration/test_enemy_ecology.gd`.
- [x] Testy: figura 12 m za plecami celu (cel „patrzy” −Z, figura za nim +Z) przez 4 s obraca się ku niemu i przysuwa ≥ 0,5 m, pozostając DORMANT; gdy cel patrzy na nią — nie rusza się; nie dalej niż 1,5 m od domu; figura 50 m od celu nie tyka (`routine_ticks` = 0: LOD); popiersie na cokole obraca się, nie przesuwa.
- [x] Implementacja: `_routine_timer`, `routine_active()`, `_routine_tick()` (hak; baza: stir dla profilu `stir`), `_guard_watching_me()`.
- [x] Zielono; commit `Routine tick with LOD; wax figures and busts stir when unwatched`.

## Zadanie 5: wilk — włóczęga i węszenie śladu
**Pliki:** `perception_world.gd` (ślad), `wolf.gd`, `night_spawner.gd` (roam dla roli); test `tests/integration/test_wolf.gd`.
- [x] Testy: ślad: cel przeszedł 12 m → ≥ 6 okruchów, stare znikają po 25 s; czuwający wilk bez trasy włóczy się (≥ 2 różne cele w 5 m od domu w 20 s); cel przeszedł 8 m od wilka za przegrodą (bez linii wzroku) → w ≤ 4 s wilk INVESTIGATE okruch (węszy), nie HUNT.
- [x] Zielono; commit `Wolves prowl their diorama and sniff the guard's trail`.

## Zadanie 6: rycerz / samuraj / pies Fu — posterunek przy drzwiach, obchód
**Pliki:** `knight.gd`, `night_spawner.gd` (beat z roli: dwell/yaw); test `tests/integration/test_knight.gd`.
- [x] Testy: czuwający rycerz z trasą 2 punktów stoi na posterunku ≥ 6 s zwrócony `home_yaw`, potem idzie; drzwi otwarte 6 m → rycerz do progu (INVESTIGATE do punktu drzwi), potem wraca na obchód.
- [x] Zielono; commit `Knights stand guard at their posts and answer doors`.

## Zadanie 7: popiersie — alarm (wsparcie)
**Pliki:** `bust.gd`; test `tests/integration/test_bust.gd`.
- [x] Testy: polujące popiersie + 2 śpiące figury 5 m za nim (w sali, linia wzroku) → w ≤ 9 s obie czuwają (INVESTIGATE / SUSPICIOUS), nie HUNT, cicho; przy ≥ 4 polujących nie woła.
- [x] Zielono; commit `Busts call sleeping neighbours while they hunt`.

## Zadanie 8: raptory — naganiacz i flankujący; włóczęga stada
**Pliki:** `raptor.gd`; test `tests/integration/test_raptor.gd`.
- [x] Testy: stado 4 budzone → dokładnie jeden `driver()` (najbliższy), reszta ±1 na przemian; w biegu ≥ 1 flankuje i naganiacz nie flankuje; istniejące testy stron zielone.
- [x] Zielono; commit `Raptor packs send a driver straight in and flankers round the sides`.

## Zadanie 9: mumia — powrót do grobowca i odpoczynek
**Pliki:** `mummy.gd`; test `tests/integration/test_mummy_tomb.gd`.
- [x] Testy: mumia z grobowca po polowaniu i powrocie: DORMANT, `in_tomb()`, `rise_phases()` = 0; raniona do 50 HP odzyskuje do ≥ 90 w 10 s snu; obudzona wychodzi znowu (`rising()`); z otwartym wiekiem widzi strażnika z 6 m.
- [x] Zielono; commit `Mummies shuffle back into their tombs to rest and mend`.

## Zadanie 10: skarabeusze — strumień wzdłuż ścian, gromadzenie, ucieczka
**Pliki:** `scarab_swarm.gd`, `perception_rules.gd` (`wall_route`); test `tests/integration/test_scarab_swarm.gd`.
- [x] Testy: czuwający rój w sali 10×10 → trasa ≥ 4 punktów, każdy ≤ 0,6 m od ściany; `fall` 6 m → INVESTIGATE do padłego; `blast` → FLEE.
- [x] Zielono; commit `Scarab swarms stream along the walls, gather on the fallen, flee blasts`.

## Zadanie 11: hoplici — linia bada razem
**Pliki:** `hoplite.gd`; test `tests/integration/test_hoplite.gd`.
- [x] Testy: 3 czuwający hoplici 2 m od siebie, hałas 12 m → wszyscy trzej INVESTIGATE (limit nie dzieli linii), żaden HUNT.
- [x] Zielono; commit `Hoplites of a line investigate together`.

## Zadanie 12: reliefy — powrót w płytę
**Pliki:** `relief_wall.gd`, `relief_warrior.gd`, `relief_lion.gd`; test `tests/integration/test_relief.gd`.
- [x] Testy: wojownik obudzony hałasem, bada, wraca; po DORMANT `wall.state` = IN, `panel.shows_figure()`, nie można go trafić; ponowna pobudka → CRACKING.
- [x] Zielono; commit `Relief figures sink back into their slabs when they rest`.

## Zadanie 13: księgi — spłoszenie od strzału
**Pliki:** `flying_book.gd`; test `tests/integration/test_flying_books.gd`.
- [x] Test: czuwające stado, strzał 6 m → `flock.spooked()`.
- [x] Zielono; commit `A shot spooks a flock of books`.

## Zadanie 14: reżyser nocy — mieszanie ról w sali
**Pliki:** `night_config.gd` (`Spawn.watcher`), `night_director.gd`, `night_spawner.gd`; test `tests/unit/test_night_director.gd`.
- [x] Testy: sala z 3 śpiącymi wax → dokładnie jeden `watcher` (czuwa); sala z czuwającym już — bez zmian; `to_dict` zawiera `watcher`; ten sam ziarno = ten sam wybór; losowanie reszty nocy (loot, drzwi) **identyczne** jak przed (porównanie `to_dict` bez `spawns`).
- [x] Zielono; commit `Night director: one watcher per populated room`.

## Zadanie 15: zamknięcie
- [x] `git merge pietro-1`, konflikty jako suma; pełny zestaw `bash tools/run_tests.sh`; uzupełnić „Stan prac”, tabelę luk po pracy, listę „Do sprawdzenia w oknie”. Commit `Enemy ecology: plan state after the full suite`.

---

## Do sprawdzenia w oknie (gdy okna będą dozwolone)
**Sprawdzone w oknie 19.10 (tryb nocny, `bash tools/run_ecology_poses.sh`, zrzuty w `tests/_out/ecology_poses/`):**
- ✔ Pobudka rycerza: z miecza w dół do gardy (miecz po skosie w górę), tarcza uniesiona, poświata przebudzenia — wyraźna różnica względem snu z 4 m. Drżenia na zrzucie nie widać (ruch) — do oceny w grze.
- ✔ Mumia po polowaniu: stoi w otwartej trumnie, ręce skrzyżowane, wieko leży przed nią — czyta się jako „wróciła na miejsce”. Uwaga poza tą gałęzią: od tyłu zamkniętej trumny wystają przez jej ścianę bandaże mumii (model trumny/mumii; w poziomie trumny stoją zwykle tyłem do ściany) — naprawione w `fix-coffin`, patrz niżej.
- ✔ Wilk na tropie: po poprawce nos przy podłodze (patrz odstępstwo 17).
- ✔ Mumia w zamkniętej trumnie **od tyłu** (19.10, noc, `--shots=mummy_back,mummy_back_low`): przedramiona, dłonie i luźne bandaże mumii **wystają przez skorupę trumny** — potwierdzone; **naprawione w gałęzi `fix-coffin`** (patrz „Stan prac”): po przebudowie trumny od tyłu skorupa jest czysta (te same dwa ujęcia, 19.10, noc).
- ✔ Trumna po przebudowie (`fix-coffin`, 19.10, noc; `--shots=mummy_asleep,mummy_back,mummy_back_low,mummy_rest`, tour `egypt_camp`, `egypt_tomb_passage` — nowe ujęcie, `egypt_tomb_hall`): zamknięta czyta się jak wcześniej (maska, kołnierz, Nut, bogowie; malowanie wieka rozciągnięte na szerszą skórę), od tyłu i z dołu nie wystaje nic; otwarta mieści mumię z łokciami przy ścianach skorupy; trumna przy stole obozu i stojące trumny w korytarzu nie dotykają ścian ani mebli. Sala sarkofagów w tourze jest ciemna (śpiące mumie tam to granitowe skrzynie, nie trumny).

**Nadal do sprawdzenia w grze (ruch, nie zrzut):**
- Figury woskowe: poruszenie we śnie czytelne, ale nie „ślizgające się” (krok 0,25 m co 0,5 s); zamarzają, gdy się na nie patrzy; czy to straszy, nie irytuje.
- Rycerz na posterunku przy drzwiach: zwrot do progu, obchód, powrót; reakcja na otwarcie drzwi (idzie do progu, nie poluje).
- Wilki w dioramie: krążenie i węszenie w ruchu (poza zrzutem: czy szybkie „węszące” ruchy nosa nie drgają nienaturalnie w marszu).
- Mumia wracająca do sarkofagu: moment wejścia (teraz przeskok na miejsce w trumnie po powrocie — bez animacji „wchodzenia”; czy to razi, gdy gracz akurat patrzy), odzysk HP widoczny dopiero po powrocie gracza.
- Skarabeusze wzdłuż ścian: trasa nie wchodzi w gabloty.
- Reakcje na upadek sąsiada: 1–3 zbiegają się, reszta odwraca głowy; brak hordy po strzale z kartaczownicy (30 m).
- Reliefy wracające w płytę: moment wsunięcia i zgaśnięcie pęknięć.
- Alarm popiersia: zgrzyt + budzenie 2 sąsiadów — czy nie za częste (8 s).
- Pobudka rycerza (i aszigaru na tym samym rigu): tarcza w górę, miecz cofnięty, drżenie zbroi 0,5 s — czy czytelne z 10–15 m, czy drżenie nie wygląda na błąd animacji.
- Poruszenie we śnie na krawędzi ekranu: przy szerokim monitorze (21:9) i FOV 90° figura nie może drgnąć w kadrze (łuk liczony z kamery + 10°).
- Seria z kartaczownicy w sali pełnej śpiących: 1–3 wstają, reszta tylko odwraca głowy; po ok. 6 s kolejny strzał znów może kogoś podnieść.
- Czuwający reżysera (jeden w sali z ≥ 3 eksponatami): czy Piętro I nie robi się zbyt „żywe” (4–8 dodatkowych czuwających na noc, patrz uwagi o balansie).
- Księgi: strzał przy krążącym stadzie — pierścień się rozszerza na 0,8 s; czy to czytelne jako spłoszenie.

## Doprecyzowania i odstępstwa
1. **Reakcje probabilistyczne, ale testowalne:** rzut z `brain.rng` (testy ustawiają ziarno); gwarancja „najbliższy ciekawy zawsze bada” i limit 3 dają twarde asercje („niektórzy, nie wszyscy”).
2. **Poruszenie we śnie nie zmienia wzroku śpiącego** (`DORMANT_SCALE` 0,6) — przybliżanie się jest ryzykiem gracza, który odwraca wzrok; to zamierzony kompromis bez hordy.
3. **Reżyser miesza role przez czuwanie jednego eksponatu**, nie przez zamianę rodzajów: sloty Piętra I mają jeden rodzaj (albo parę zastępca→docelowy), więc zamiana rodzaju nic by nie dała. Osobny RNG, by nie ruszyć loot/drzwi/portretów.
4. **Hałas drzwi tylko przy otwarciu animowanym** (`instant = false`): otwarcia przy budowie poziomu i odblokowania skryptowe nie hałasują.
5. **Totem i portret nie badają** (ciekawość 0): totem odwraca twarze, portret nie słyszy (z założenia).
6. **Limit badających liczony w czasie i miejscu** (nie było w planie): limit 3 „na zdarzenie” nie chronił przed hordą przy ogniu ciągłym (każdy strzał serii to nowe zdarzenie — 3 s kartaczownicy podnosiły po kolei wszystkich w zasięgu). Teraz te same 3 miejsca na hałasy w 20 m przez 6 s; liczą się tylko wstający z odpoczynku.
7. **LOD rutyn także po salach** (≤ 2 przejścia od sali strażnika, jak `RoomCuller`), nie tylko 36 m — 36 m przez ścianę to często druga strona piętra.
8. **Linia hoplitów rusza od razu** (przy wysłaniu, nie po namyśle prowadzącego) i ma najwyżej 3 ludzi; bez tego towarzysz kończący własne „patrzenie” klatkę wcześniej siadał i ruszał 0,8 s później.
9. **Naganiacz raptorów zastępowany od razu** po upadku (nie dopiero przy następnej zbiórce stada).
10. **Księgi płoszy huk** (`ReactionRules.is_bang`: wybuch albo broń ≥ 12 m), nie każda reakcja FLEE — strzał nigdy nie dawał FLEE (to tylko wybuch); polujące stado nie płoszy się od ognia strażnika (inaczej kartaczownica wyłączałaby jego nurkowanie). `Enemy.react` dostał 4. argument: źródło hałasu.
11. **Przywołani (boss) nie uciekają od wybuchu**: rój Kolosa po ucieczce szedłby „do domu” (miejsce wysypania) i zasypiał.
12. **Czuwający — wykluczenia:** poza zasadzkami, stadami i rojem ksiąg także rodzaje, których sen jest ekspozycją (mumia w grobowcu, relief w płycie): relief czuwający od zmierzchu straciłby swoje wyjście ze ściany. **Noc 1: na trasie z budki bez czuwających** (test „bez hordy przy wyjściu z budki” złapał trzeciego polującego: czuwający dioramy + patrol i śpiący holu).
13. **Ślad należy do jednego strażnika**: inny strażnik (odrodzenie, kolejny test) zaczyna świeży ślad.
14. **Zapis/wczytanie:** `NightConfig.to_dict()` nie jest nigdzie wczytywany (logi, porównania w testach); zapis trzyma indeksy slotów (`night_progress.killed`, straty stad) i noc losuje się od nowa z ziarna. Czuwający zmienia tylko `dormant` (slot i rodzaj bez zmian), więc stare zapisy wznawiają się poprawnie; 4. pole wiersza (`watcher`) jest po trzech starych (test `test_watcher_rows_extend_the_old_three_fields`).
16. **Poruszenie tylko poza zasięgiem wzroku śpiącego i nie przy strażniku w schronie** (pełny zestaw złapał to w `test_haven`): figura odwrócona plecami, 7 m od strażnika, w kilka sekund obracała się ku niemu, widziała go i budziła się — poruszenie dawało śpiącym wzrok dookoła z czasem, czyli hordę 360° z §7.2. Teraz bliżej niż zasięg wzroku śpiącego + 1 m stoi tak, jak stała; przy strażniku w schronie nic się nie skrada pod drzwi.
17. **Wilk na tropie** (sprawdzone w oknie): głowa była opuszczona tylko o ok. 26° z otwartym pyskiem — teraz 0,75 rad, tułów lekko pochylony, pysk zamknięty, krótkie „węszące” ruchy nosem.
15. **Testy, których oczekiwanie było błędne** (poluzowane z powodem): rój po ucieczce wraca i *patroluje* (raz poruszony już się nie usypia) — dopuszczony PATROL przy domu; pół obrotu poruszenia to 9 tyków po 0,4–0,6 s — zwrot sprawdzany po 6 s, nie 4; strona flankujących raptorów liczona średnią flankujących (z naganiaczem połowa stada to nie „strona”); rój badający punkt 3 m dalej bywa już w SEARCH po sekundzie; `test_every_encounter_room_gets_one_set_with_matching_kinds` — czuwający to jedyny wyjątek od „uśpiony jak slot”.
18. **Skrzypnięcie drzwi ma własny sygnał** (`Events.door_creaked(position, radius, room_a, room_b)`, przegląd 19.10): `noise_made` ma trzy argumenty i punkt, a środek drzwi leży w ścianie (79 z 80 drzwi Piętra I w żadnej sali; jedyny wyjątek, `court_reading_door`, leży w sali Dziedzińca, która sięga w ścianę) — sondowanie ±0,6 m nie zawsze wystarcza (ściana 1,5 m). `PerceptionWorld.noise(at, radius, source, rooms)` bierze sale drzwi (obie z pełną głośnością; dalsze przez otwarte przejścia z tłumieniem), bez sal liczy salę punktu jak dawniej. `Enemy.react` dostaje salę po stronie słuchacza (do granic terytorium).
19. **Bez „darmowego przejścia” przy drzwiach i upadku** (`ReactionRules.cap(..., guaranteed)`, `sends_a_visitor`): gwarancja najbliższego ciekawego zostaje przy zwykłym hałasie (strzał, krok, szkło, wybuch) — leżał tam sens „samotny słuchacz przychodzi” — ale rycerz w 10 m od *jakichkolwiek* drzwi szedł do nich za każdym razem, co psuło łagodność nocy 1. Twardo śpiący (`sound_asleep`, noc 1 na trasie z budki) nie słyszą drzwi, upadku ani kroku (`ReactionRules.is_soft`); strzał i wybuch budzą ich jak dawniej.
20. **Słuchacze, którzy nie mogą odpowiedzieć, nie liczą się** (`PerceptionWorld.noise`): zniszczeni / w kolejce do usunięcia, zamrożeni, polujący, atakujący, ogłuszeni, uciekający — brali miejsce „najbliższego ciekawego” (upadek słyszał sam upadły). Polujący nadal wchodzą do wyniku „obudzeni” (cabinet: `last_heard`).
21. **Gwarancja „polujący + czekający ≤ limit” jest węższa, niż zapisał przegląd**: test z celem *w* hałasie i 20 śpiącymi — gdy żaden nie widzi strażnika (24–29 m, zasięg wzroku 22 m): 3 badających + ich łańcuch (≤ 2 każdy) → w pomiarze polują 3, reszta śpi; gdy widzą go (14–26 m): polują 8 (limit), pozostali widzący czekają 10 m od niego (5 w pomiarze) — **to nie jest „≤ limit”**, tylko stary mechanizm: czekający są *poza* limitem polujących, a każdy, kto widzi strażnika po odwróceniu głowy (SUSPICIOUS widzi na pełny zasięg), jest w grze. Dwa testy pilnują prawdziwych własności: polujących ≤ limit, reszta obudzonych czeka, ci poza światłem strażnika śpią dalej. Nie zmieniałem mechanizmu (poza zakresem; zmiana: wzrok SUSPICIOUS „tylko LOOK” = jak śpiącego).
22. **Linia hoplitów = ten, który usłyszał, i dwóch najbliższych** (przegląd: rekurencja robiła z rzędu 6 jedną linię). Wybrałem 3 ludzi (plan §Liczby), nie „3 wezwanych”: `Hoplite.LINE_MAX` 2 bez zmian; wezwani (cisi) i ci, którzy widzieli strażnika, nie wołają; raz na wyprawę.
23. **Wilk: węszy ślad starszy niż 3 s w 6 m** (`SNIFF_MIN_AGE`, `SNIFF_RANGE`), bez linii wzroku do okruchu (ślad *jest* przez ścianę, to zapach). Dawne 10 m i najświeższy okruch = „wiem, gdzie stoisz”.
24. **Zapowiedzi ≥ 0,6 s** (reguła właściciela): raptor 0,3 → 0,6, wilk 0,45 → 0,6, figura woskowa 0,55 → 0,6, pazury mumii 0,55 → 0,6, cios reliefów 0,5 → 0,6. Rigi (`windup_progress()`) skalują się z czasem same; testy czekające na cios wydłużone (raptor 110, wilk 130 klatek).

## Poprawki po przeglądzie (19.10)

Przegląd (`review-ecology`) zmierzył gałąź na prawdziwym Piętrze I i znalazł 12 spraw; wszystkie zrobione testami najpierw (czerwone → zielone), commity `Ecology review fixes 1–3` (+ ten plan):

| # | Waga | Co | Gdzie / test |
|---|---|---|---|
| 1 | wysoka | Skrzypnięcie drzwi należy do dwóch sal, które łączą (słyszane „znikąd” przez ściany w 10 m) | `Events.door_creaked`, `PerceptionWorld.noise(..., rooms)`; `test_ecology_floor1` (przejście Egipt–Grecja: figura w sali słyszy, w bocznej sali za ścianą nie), `test_enemy_ecology` (drzwi z salami) |
| 2 | wysoka | Drzwi i upadek nikogo nie posyłają „na pewno”; twardo śpiący (noc 1) śpią przez drzwi, upadek i krok; wagi drzwi 0,6 / 0,6 / 0,5 / 0,4 | `ReactionRules.cap(guaranteed)`, `is_soft`; `test_ecology_floor1` (ziarna nocy 11 i 90210, rycerze Wielkiego Dziedzińca 4 m od bramy), `test_enemy_ecology`, `test_reaction_rules`, `test_enemy_roles` |
| 3 | średnia | Rakownica słyszana 15 m, rakieta 30 m | `PerceptionRules.blast_noise`, `Blast.explode`; `test_a_flares_burst_is_heard_15_m_round_a_rockets_30` |
| 4 | średnia | Zniszczeni / w kolejce / zamrożeni / polujący nie są słuchaczami | `PerceptionWorld.noise`; trzy testy „… does not take the visitor's place” |
| 5 | niska–średnia | Strażnik *w* hałasie, ~20 śpiących: patrz odstępstwo 21 | dwa testy w `test_enemy_ecology` |
| 6 | niska | Naganiacz raptorów od nowa przy każdym nowym polowaniu | `Raptor._rally_pack`; `test_a_second_hunt_picks_its_driver_again` |
| 7 | niska | Linia hoplitów: 3 ludzi, nie cały rząd (odstępstwo 22) | `Hoplite._rally_line`; `test_a_long_row_of_hoplites_sends_one_line_of_three` |
| 8 | niska | Wilk: 6 m i ślad ≥ 3 s (odstępstwo 23) | `Wolf.SNIFF_*`, `freshest_crumb(min_age)`; trzy testy |
| 9 | niska | `idle` / `Idle` usunięte | `EnemyRoles`; `test_a_profile_carries_nothing_that_drives_nothing` |
| 10 | balans | `WATCHER_ROOM` 5 w nocy 1 / 3 od nocy 2; mumia 2,5 HP/s; zostają `INVESTIGATE_CAP` 3, `SEND_AREA` 20, `SEND_WINDOW` 6, `DOOR_NOISE` 10 | `NightDirector.watcher_room`, `Mummy.REGAIN_PER_SECOND`; testy |
| 11 | reguła właściciela | Zapowiedzi ≥ 0,6 s (odstępstwo 24) | `test_telegraphs`; testy raptora i wilka |
| 12 | opcjonalnie | Bandaże mumii przez skorupę trumny | **naprawione** w `fix-coffin` — trumna skrojona pod pozę mumii; `test_mummy_tomb_fit` |

## Stan prac / co dalej (19.10 — zadania 0–15 i poprawki po przeglądzie zrobione)

**Pełny zestaw po poprawkach i merge `pietro-1`:** **2487 / 0, bez błędów silnika** (`bash tools/run_tests.sh`, po `git merge pietro-1` @ `55b770e` — kawiarnia, muzyka biomów — bez konfliktów; 111 testów więcej niż przed przeglądem i merge: 2376). Przebieg celowany przed merge (`enemy_ecology, ecology_floor1, test_wolf, test_knight, test_bust, test_raptor, mummy, scarab_swarm, test_hoplite, test_relief, flying_books, night_director, enemy_brain, test_perception, enemy_roles, reaction_rules, lobby_perception, door, flare, crowd, wax_figure, telegraphs, haven, art_integration, perception_rules`): 381 / 0.

**Do decyzji właściciela (z przeglądu i okna 19.10):**
- ✔ **Bandaże mumii wystawały z zamkniętej trumny od tyłu — naprawione w gałęzi `fix-coffin` (19.10).** Decyzja kontrolera: powiększyć trumnę (nie zmniejszać mumii). Pomiar każdego wierzchołka mumii (ciało, luźne pasy, bicz; we śnie i w spoczynku po polowaniu) względem siatki trumny — `tests/integration/test_mummy_tomb_fit.gd` — pokazał, że same ×1,2 / ×1,25 nie wystarczą: przy skrzyżowanych rękach łokcie sięgają |x| ≈ 0,31 na wysokości ok. 1,25–1,3 m, gdzie skorupa miała ok. 0,24 (0,29 to dopiero barki), plecy ≈ 0,18, a pas `strip_1` z głowy ≈ 0,23; do tego wewnętrzna ściana skorupy ma 3,5 cm. Nowy profil (`SECTIONS`, `tools/art/models/coffin.py`): półszerokość 0,16 przy stopach → ok. 0,25 przy łydkach → 0,36–0,38 przy łokciach → 0,33 przy barkach → głowa jak była; skorupa z tyłu do 0,21 głębokości, wieko do 0,25 nad przedramionami (dłonie na wieku siedzą na nowej skórze); mumia stoi na osi trumny (znacznik `MummySpawn` z z = +0,05 na 0, mieści się wtedy po równo w skorupie i w bryle wieka). Wymiary 0,86 × 2,02 × 0,76 (było 0,78 × 2,02 × 0,72): płyta stojaka, kolizje (`MummyTomb.COFFIN_SIZE`) i stojące trumny w korytarzu grobowców (`egypt.gd`, `Floor1Art`) idą z tej samej stałej. Luz: ciało ≥ 1,5 cm od wewnętrznej ściany skorupy, luźne pasy ≥ 1 cm od zewnętrznej, wieko ≥ 1 cm; na starym modelu test pada (do 10,7 cm przez ścianę). Dziewięć trumien zasadzek na piętrze I nie nachodzi na ściany ani elementy (zapytanie fizyki o pudełko stopy trumny w zbudowanym poziomie).
- **Dla właściciela (nie zmieniłem pozy):** trumna jest teraz pękata na wysokości łokci (jak amfora). Wąską, „egipską” sylwetkę dałoby dopiero ściągnięcie łokci mumii przy skrzyżowanych rękach (`CROSS_ARM_*` w `mummy_rig.gd`) — to zmiana animacji, osobna decyzja.

**Stan z 18.10 (zadania 0–15):**

**Wszystkie zadania zrobione i zielone** na `enemy-ecology`. WIP `848f7c8` (zadania 3–14, napisane 10.10 bez uruchomienia) zweryfikowany i naprawiony „do przodu” (rozbicie WIP-u na commity per zadanie nie było praktyczne: wspólne pliki `enemy.gd`, `perception_world.gd`, a stany pośrednie byłyby nieprzetestowane):
- `92d01f1` zadania 3–5, 13 — pierwszy przebieg w ogóle się nie kompilował (`pass` to słowo kluczowe GDScript → runner nie wczytał się, Godot wisiał); źródło hałasu w `Enemy.react`, LOD po salach, ślad jednego strażnika, huk płoszy księgi;
- `fc8c4f4` zadanie 11 (linia hoplitów), `6f3c977` zadanie 8 (naganiacz), `2907c1e` zadanie 10 (trasa wzdłuż ścian), `be75aeb` zadanie 14 (czuwający);
- po przeglądzie wymagań właściciela: `ce172e5` limit badających w czasie i miejscu (seria ognia ≠ horda), `38c816a` przywołani nie uciekają, `1dcbc02` noc 1 bez czuwających na trasie z budki, `d8e098c` łuk „patrzy” z kamery (+10°), `cf1ad38` czytelna pobudka rycerza;
- `a901902` merge `pietro-1` @ `40323a4` (Wąż, ubranie wschodu, amunicja, poprawki) — **bez konfliktów**.

- `d42b0f4` poruszenie tylko poza zasięgiem wzroku śpiącego i nie przy schronie (złapane przez pełny zestaw: `test_haven`);
- `bf804d2` drugi merge `pietro-1` @ `69f576e` (nagrody za sekrety) — **bez konfliktów**;
- `43a34b5` wilk na tropie (poprawka po obejrzeniu w oknie) + narzędzie `tools/run_ecology_poses.sh`.

**Pełny zestaw po merge (`bf804d2`): 2376 / 0, bez błędów silnika** (`bash tools/run_tests.sh`, ok. 29 min na obciążonej maszynie). Pierwszy przebieg po pierwszym merge: 2326 / 1 (`test_haven` → `d42b0f4`). Po `43a34b5` (tylko poza rigu wilka i nowy scenariusz) przebieg celowany `test_wolf, art_integration, art_stage2, enemy_ecology, test_knight`: 58 / 0.

**Filtr zadania** (`enemy_ecology, test_wolf, test_knight, test_bust, test_raptor, mummy_tomb, scarab_swarm, test_hoplite, test_relief, flying_books, night_director, enemy_brain, test_perception` + `enemy_roles, reaction_rules, lobby_perception, door, flare, crowd, wax_figure`): 309/0.

**Liczby czuwających (Piętro I, spis z `NightDirector.plan`, ziarna 11 / 4242 / 90210):** 124–130 eksponatów w 64–67 salach; czuwających reżysera 4–8 na noc (np. noc 1, ziarno 11: 14 na jawie, z czego 7 czuwających; noc 2, ziarno 90210: 19 na jawie, 6 czuwających). Rodzaje: wosk, hoplita, wilk, rycerz, samuraj, pies Fu, jaguar. Do decyzji właściciela po teście (patrz niżej).

**Uwagi o balansie (do testu właściciela):**
1. Czuwający: mniej więcej podwajali liczbę eksponatów na jawie na Piętrze I. **Po przeglądzie (19.10):** noc 1 — sala musi mieć 5 wylosowanych (`WATCHER_ROOM_FIRST_NIGHT`), od nocy 2 — 3 (`WATCHER_ROOM`). Pomiar (`NightDirector.plan` na Piętrze I, ziarna 11 / 4242 / 90210): czuwający w nocy 1 **1 / 2 / 1** (było 7 / 7 / 4), eksponatów na jawie 8 / 7 / 7 (było 14 / 12 / 10); noc 2 bez zmian: czuwających 6 / 8 / 6, na jawie 11 / 14 / 19.
2. Limit badających 3 na 20 m / 6 s: ogień ciągły podnosi mniej eksponatów niż przed gałęzią (wtedy każdy w zasięgu szedł badać po każdym strzale) — walka może być spokojniejsza. Gałki: `ReactionRules.SEND_WINDOW`, `SEND_AREA`, `INVESTIGATE_CAP`.
3. Poruszenie we śnie: figura może podejść 1,5 m bliżej i obrócić się ku graczowi, gdy ten jest dalej niż jej wzrok i nie patrzy — gracz, który potem podejdzie tyłem, wejdzie jej w pole widzenia (świadome ryzyko „nie odwracaj się od figur”).
4. Mumia leczy **2,5 HP/s** (było 4) w grobowcu (110 HP): mumia zbita do połowy, od której gracz odszedł, jest znów pełna po ok. 22 s snu (sama droga do grobowca to SEARCH 6–10 s + powrót) — odpoczynek się liczy, nie jest resetem.
5. Drzwi wołają stróżów (rycerz/samuraj **0,6**, pies Fu **0,5**, hoplita **0,4**; było 0,9 / 0,7 / 0,6) do progu w 10 m, **bez gwarancji** — otwieranie drzwi jest ryzykiem (zasadzka w progu), ale nie pewnością; w nocy 1 twardo śpiący (trasa z budki) nie słyszą drzwi w ogóle.
6. Alarm popiersia (2 śpiących co 8 s, tylko gdy polujących < 4) i linia hoplitów (do 3) wychodzą poza limit 3 — świadomie, jak stado.
7. Zapowiedź skoku raptora **0,6 s** (było 0,3 — poniżej progu 0,6 s właściciela; podniesiona po przeglądzie razem z wilkiem, figurą woskową, pazurami mumii i ciosem reliefów); naganiacz atakuje od frontu (czytelniej), flankujący z boków. Warto zobaczyć w ruchu, czy dłuższy przysiad raptora nadal czyta się jako „skok”, a nie jako stanie.

**Co dalej:** test właściciela w oknie (lista wyżej); ewentualne strojenie gałek z uwag o balansie (po przeglądzie najbardziej na oku: `WATCHER_ROOM_FIRST_NIGHT`, `Wolf.SNIFF_*`, wagi drzwi); decyzja o trumnie.
