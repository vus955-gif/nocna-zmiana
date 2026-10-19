# Światło parteru — za ciemne sale piętra I (19.10.2026)

> Gałąź `light-pass` (worktree `close-wings`, od `pietro-1` @ `3e4479d`). Wykonawca: jeden agent, tryb nocny (okna przez
> blokadę `with_window.sh`, dźwięk wyciszony). Źródło: uwaga właściciela nr 2 z testu 3.10 („podziemia bardzo ciemne —
> akceptowalnie, ale niektóre sekcje na powierzchni zdecydowanie za ciemne”) i pomiar nocnego QA wizualnego
> (`2026-10-19-qa-wizualne.md`, d4, c5, e1, b5).

## Cel (decyzja kontrolera)

Żaden grywalny widok nad ziemią ciemniejszy niż ~0,045 średniej luminancji, przy zachowanym kontraście i nastroju:
plamy światła, ciemne kąty dozwolone, czytelna podłoga i sylwetki, wrogowie widoczni na tle. Metoda P4 (lampy pokoju
jaśniej + lampy wypełniające w `Floor1LightRecipe`), bez globalnego podbicia ekspozycji. Podziemia bez zmian.

## Co zrobiono

### 1. Mycie podłogi (`Floor1LightRecipe.FLOOR_WASHES`, `floor_washes()`)

Wspólny objaw ciemnych sal: lampy oświetlały ściany i sufity, a podłoga zostawała czarna. Każda ciemna sala dostaje
kilka **miękkich, szerokich reflektorów w dół** (reguła `fill`: bez cienia, bez mgły, bez oprawy — to „odbicie” światła
lamp od ścian, którego renderer nie liczy):

- 4,5 m nad podłogą (niżej pod niskim stropem), po jednym na każde ~10 × 10 m każdej części sali (kąt 70°, zasięg
  1,9 × wysokości, żeby podłoga pod nim leżała głęboko w zasięgu — światło zanika ku jego końcowi);
- kolor: ciepłe odbicie lamp (piaskowiec, papier, kamień) albo chłodne (Zbrojownia: grafit i księżyc);
- energia sali × jej `lamp_energy` (jak wszystkie lampy pokoju) — plamy lamp zostają najjaśniejsze, kąty ciemne;
- **nic nie przechodzi pod podłogę**: lampa bez cienia świeci przez strop, więc nad salą piwnicy mycie kończy zasięg
  przed jej sufitem i wisi niżej (do 3 m), a siatka gęstnieje (Biblioteka Asyryjska nad schodami towarowymi, środek Sali
  Północnej nad kotłownią). Test `test_no_wash_reaches_into_a_room_under_the_floor`; widoki piwnic bez zmian
  (`basement_gantry` 0,002, `basement_boiler_fires` 0,008, `basement_crossing` 0,015, `basement_tunnel` 0,031).
- Sale: Egipt (przedsionek, Wielka Galeria, korytarz grobowców, grobowce, sala sarkofagów), Sala Północna, Oświecenie
  (gabinet przyrodniczy, portrety), Asyria (brama, Balawat, biblioteka, Sala Lwów z galerią — tu 7,5 m nad dnem dołu),
  Azja (Chiny, porcelana, Korea, Zbrojownia), Ameryki (sala północna, świątynia — 9 m nad podłogą, nad dachem ołtarza).
  Razem 93 mycia.

### 2. Lampy pokoju jaśniej (`lamp_energy`)

Egipt (przedsionek, galeria 1,3; sala Kolosa 1,25; grobowce i sala sarkofagów 1,35), Sala Północna 1,3, Oświecenie
(biblioteka i zegary 1,25, gabinet 1,3, portrety 1,35), Zbrojownia 1,2 → 1,3 — jak skrzydła P4.

### 3. Pickupy z daleka (`exhibit.gdshaderinc`, `ArtLibrary.PICKUP_FAR_*`)

Z 15 m w cieniu i w ciemnej sali pickupy były kolorowymi kropkami, apteczki nie dało się odróżnić (QA e1). Shader
eksponatów dostał „odczyt z daleka”, który eksponaty mają wyłączony: od 9 m (pełny przy 15 m) obrys (rim) w kolorze
rodzaju rośnie ×3,2, całe ciało lekko świeci tym kolorem (0,16 — poświata, nie lampa; przy 0,2 pudełka na księżycowym
dziedzińcu świeciły jak neon) i czerwony krzyż apteczki jaśnieje (+3 × mapa emisji). Z bliska bez zmian (`close_*`,
`05m` jak przed). Obejrzane w trzech światłach: z 15 m każdy rodzaj czyta się kolorem i obrysem, apteczka to jedyna biała
skrzynka, krzyż widać, gdy obróci się nim do gracza. **Uczciwie:** w ciemnej bibliotece różnica z 15 m jest umiarkowana
(to nadal ~20 pikseli na pudełko) — pomaga głównie apteczce i chłodnym kolorom (cyjan, fiolet, oliwka).

### 4. Wąż: kadry scenariusza w ubranej świątyni (`serpent_moments.gd`)

Kamery z czasów greyboxu chybiały: `ring_closed` stała w północnej ścianie (z = −86,1; przed północnymi schodami są
tylko 3 m podłogi), `heads_rise` była w głowie, `arches` za tarasem. Teraz: `heads_rise` z północno-wschodniego narożnika
podłogi (z dala od dymu misy ognia), `ring_closed` wysoko nad stopą północnej ściany, w dół na tarasy, `arches` spoza
pierścienia do środka. Kadry, które z boku zasłania dom ołtarza albo taras (`spit_burst`, `turned`, `phase_shift`,
`plate_off`), obchodzą przedmiot, aż jest w czystym polu widzenia (`_seen`). Tryb `--dry` scenariusza strażników
wypisuje linię `FRAMING:` dla kamery poza salami, w ścianie albo z zasłoniętym przedmiotem.

## Przed / po (wycieczka, `--preset=high`, średnia luminancja; w nawiasie udział prawie czarnych pikseli)

Pomiar: `bash tools/run_tour.sh shots --preset=high` przez blokadę okna; przed = `pietro-1` @ `3e4479d` (19.10, 03:09),
po = `light-pass` po scaleniu `pietro-1` @ `bee9b06`. Pliki: `tests/_out/light_pass/before|after/metrics_high.json`.

| widok | przed | po |
|---|---|---|
| `egypt_tombs` | 0,019 (88 %) | 0,056 (55 %) |
| `egypt_tomb_hall` | 0,021 (86 %) | 0,062 (49 %) |
| `egypt_vestibule` | 0,021 (85 %) | 0,052 (49 %) |
| `asia_armor_rows` | 0,022 (89 %) | 0,048 (60 %) |
| `assyria_library` | 0,023 (83 %) | 0,072 (46 %) |
| `portraits` (Oświecenie) | 0,023 (87 %) | 0,069 (48 %) |
| `assyria_lions_gallery` | 0,026 (78 %) | 0,084 (36 %) |
| `library_rifle` (gabinet) | 0,029 (80 %) | 0,056 (52 %) |
| `cabinet_dioramas` | 0,032 (77 %) | 0,071 (39 %) |
| `assyria_balawat_doors` | 0,032 (77 %) | 0,062 (56 %) |
| `asia_armor_shoji` | 0,034 (88 %) | 0,056 (60 %) |
| `egypt_colossi_row` | 0,035 (71 %) | 0,065 (44 %) |
| `assyria_axis_obelisk` | 0,036 (73 %) | 0,058 (47 %) |
| `asia_porcelain` | 0,037 (63 %) | 0,070 (35 %) |
| `egypt_gallery_long` | 0,038 (68 %) | 0,060 (49 %) |
| `north_hall` | 0,038 (75 %) | 0,081 (44 %) |
| `americas_temple_disc` | 0,038 (58 %) | 0,050 (49 %) |
| `americas_moai_ring` | 0,040 (64 %) | 0,040 (64 %) — bez zmian, patrz niżej |
| `americas_north_shutter` | 0,041 (61 %) | 0,050 (53 %) |
| `assyria_lions_pit` | 0,041 (67 %) | 0,107 (25 %) |
| `egypt_well_up` (w górę studni) | 0,042 (70 %) | 0,045 (68 %) |
| `library_aisle` | 0,047 (67 %) | 0,052 (64 %) |
| `asia_korea_hwacha` | 0,049 (67 %) | 0,070 (32 %) |
| `egypt_camp` | 0,070 (38 %) | 0,100 (23 %) |

Całość (96 widoków parteru bez dachu): poniżej 0,045 — **21 → 1** (`americas_moai_ring`); flaga DARK wycieczki (< 0,06
lub > 55 % czerni) 35 → 20. Średnio: Egipt 0,053 → 0,075, Oświecenie 0,089 → 0,102, Asyria 0,108 → 0,128, Azja 0,168
→ 0,177, Ameryki 0,076 → 0,082; Grecja (0,239) i dziedziniec (0,232) bez zmian.

`americas_moai_ring` (0,040) zostaje: sala Moai jest ciemna z założenia (jedna głowa w snopie), światło ustawiła tej
nocy gałąź `polish-americas` (widok głowy 0,046); kadr pokazuje tylny róg za cokołem z żelaznym kółkiem sekretu w
dwóch własnych lampach.

## Budżet lamp i klatki

`bash tools/run_tour.sh dry` po scaleniu: **124 widoki, 0 problemów**. Cienie bez zmian w każdym widoku (mycia ich nie
rzucają). Lampy włączone przez culling grafu sal (przed → po): Egipt 184 → 205 (grobowce 117 → 131), Sala Północna
197 → 220, Oświecenie 207 → 232, Asyria 103–142 → 131–178, Azja 78–145 → 102–180, Ameryki do 173 — w zakresie
ubranych skrzydeł (41–258). **Wyjątek: widoki dziedzińca** (węzeł, „widzi” najwięcej sal) **258 → 295** — o 37 myć
więcej, niż był dotychczasowy szczyt. Mycia to najtańsze lampy (bez mapy cienia, bez mgły, zasięg ≤ 8,6 m, w Sali Lwów
14 m; gasną z odległością jak lampy sali).

Klatki (`run_tour.sh perf --preset=high`, 17 najcięższych widoków, RTX 2080 Ti, PC obciążony przez inne agenty i pełny
zestaw testów — orientacyjnie): dwie pary naprzemiennie, średnio z myciami / bez: **20,9 / 24,7**, potem **26,1 /
24,4** kl./s. Rozrzut między przebiegami (±15 %) jest większy niż jakakolwiek różnica: kosztu myć nie da się tu
zmierzyć. Pliki: `tests/_out/light_pass/perf_washes_on*.json`, `perf_washes_off*.json`.

## Zrzuty dla właściciela (`tests/_out/light_pass/`, worktree `close-wings`)

1. `01_egipt_grobowce_PRZED_PO.png` — grobowce: czarna podłoga → czytelna posadzka i sarkofagi, czerwień lamp
   awaryjnych i pochodnia zostają.
2. `02_egipt_przedsionek_PRZED_PO.png` — przedsionek z Kamieniem z Rosetty: archeolodzy widoczni na tle.
3. `03_zbrojownia_PRZED_PO.png` — Zbrojownia: deski podłogi, zbroje i wróg (zbroja samuraja) na tle shoji.
4. `04_oswiecenie_portrety_PRZED_PO.png` — sala portretów: parkiet i ławka zamiast czerni.
5. `05_asyria_biblioteka_PRZED_PO.png` — Biblioteka Asyryjska: posadzka i gabloty.
6. `06_pickupy_15m_PRZED_PO.png` — rząd 8 pickupów z 15 m w bibliotece Oświecenia (powiększenie ×4): przed — szara
   apteczka ginie, chłodne kolory ciemne; po — wyraźny obrys w kolorze rodzaju, apteczka biała.

Pełne serie: `tests/_out/light_pass/before/`, `after/` (wycieczka), `tests/_out/guardian_serpent/` (Wąż; stare kadry
w `light_pass/serpent_before/`), `tests/_out/visual_qa/east/`, `visual_qa/pickups/`.

## Do sprawdzenia w oknie (obejrzane tej nocy)

- [x] Ciemne sale parteru po myciach (wszystkie 106 widoków nad ziemią, arkusze 2×2): podłogi czytelne, plamy lamp i
  czerwień awaryjna zostają, sufity i górne ściany ciemne; nic nie świeci płasko ani „szpitalnie”. Dom ołtarza w
  świątyni bez gorącej plamy na dachu.
- [x] Piwnice bez przecieku (gantry, kotłownia, skrzyżowanie, tunel, pierścień północny — średnie jak przed).
- [x] Pickupy 5/10/15 m w księżycu, lampach i czerwieni (`--only=pickups`): z 15 m kolory i apteczka czytelne, z bliska
  jak przed.
- [x] Wrogowie wschodu w swoich salach (`--only=east`): totem i jaguar w sali Ameryk północnych czytelni w całości (nie
  sylwetki), pies Fu w Chinach z rimem na tle, zbroja samuraja w Zbrojowni na oświetlonej podłodze.
- [x] Wąż (`run_guardian.sh serpent --shots`, 25 kadrów, `--dry` bez `FRAMING` i bez `MISSED`): `heads_rise` (obie
  głowy nad północnymi schodami), `ring_closed` (cały pierścień wokół tarasu ołtarza, głowy w bramie), `arches` (łuk
  ciała nad tarasem) trafiają w przedmiot; `turned`, `phase_shift`, `plate_off` pokazują ciało; `spit_burst` pokazuje
  znaczniki i głowę, ale krawędź tarasu zajmuje dół kadru (uwaga, bez zmian).
- [ ] (właściciel) Ocena smaku: czy mycia nie zabrały za dużo grozy w Egipcie (najciemniejsze skrzydło z założenia).

## Stan prac / co dalej

- **Zrobione:** `81b3deb` (mycia + `lamp_energy`), `36c69cd` (pickupy z daleka), `f548b1c` (kadry Węża + kontrola
  kadrów w `--dry`), `7430636` (mycia co 10 m, przełącznik `--washes=off`), scalenie `pietro-1` @ `bee9b06` → `b14beaf`
  (czysto; pełny zestaw **2550 zielonych**), `2a463ab` (obrys pickupów mocniej, poświata słabiej), `ce701ef` (ten plan);
  scalenia `pietro-1` @ `5b76f76` (styl HUD) → `db31dc0` i @ `4ebf292` (głos G2) → `3dacc24`, czysto; na `3dacc24`:
  **pełny zestaw 2596 zielonych, 0 czerwonych**, bez linii ERROR; `run_tour.sh dry` **145 widoków, 0 problemów**;
  `run_guardian.sh serpent --dry` bez `MISSED` i `FRAMING`.
- Testy: `tests/integration/test_floor1_light_pass.gd` (5: lampy jaśniej, mycie całej podłogi, miękkie fill w dół, nic
  pod podłogę, piwnica / haveny / sekrety bez myć), `tests/unit/test_pickup_far_read.gd` (4).
- **Do decyzji:** budżet lamp dziedzińca (258 → 295 włączonych; jeśli to za dużo — mycia sal odległych o 2 przejścia mogą
  gasnąć wcześniej, kosztem błysku przy wejściu); `americas_moai_ring` 0,040 zostawiony (sala ciemna z założenia).
- Nie ruszane: podziemia, Grecja, dziedziniec, dach (bez zmian w pomiarach).
