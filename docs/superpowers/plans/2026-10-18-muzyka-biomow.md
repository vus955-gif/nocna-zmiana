# Muzyka biomów — metal i elektronika z kolorem epoki (Piętro I)

> Plan wykonawczy. Wykonawca: jeden agent w worktree `voice-g1` (gałąź `music-biomes` od `pietro-1`).
> Źródło: backlog właściciela `docs/backlog-pietro1.md` — **#6** („muzyka zróżnicowana według biomu (Egipt: phrygian dominant; Oświecenie: klasyczna), najlepiej metal/elektronika z naleciałościami epoki/kultury — nie same miękkie warianty ambientu; warianty skrzydeł są, ale się nie czytają”), **#40** (charakter akustyczny sal; strefy pogłosu są) i punkt QA „muzyka warstwowa ambient → perkusja → walka → kulminacja z przejściami w takt”.
> **Bez okien i bez dźwięku** (właściciel pracuje przy komputerze): niczego nie odtwarzamy. Ocena wyłącznie liczbami (`tools/music/analyze.py`: LUFS, szczyty, true peak, udział pasm, szwy pętli) i czytaniem własnego kodu syntezy. Nic nie trafia na GitHub.

**Cel:** każda strefa Piętra I ma własną tożsamość muzyczną = **rdzeń gatunkowy** (death/thrash, doom, power metal, metal neoklasyczny, darksynth, industrial, blackgaze, groove plemienny) + **kolor kultury** (skala, instrument prowadzący, perkusja). Obchód zostaje do słuchania przez długie minuty — spokojniejszy, ale już w gatunku; walka idzie na całość. Przejścia między poziomami intensywności są z definicji „w takt”, bo wszystkie warstwy strefy to stemy jednej pętli.

---

## 1. Inwentarz (stan przed zmianą)

### 1.1 Co gra i kiedy

| Stan (`MusicDirector`) | Lobby (`level_id = lobby`, testy) | Piętro I (dotychczas) |
|---|---|---|
| EXPLORE | `explore` („Obchód”, 60 BPM) | `explore_<skrzydło>` w 6 skrzydłach; dziedziniec, hol, kanciapa, korytarz północny, podziemia i dach grają **lobby’owy** `explore` |
| TENSION | + `explore_tension` (w synchronie) | + `explore_<skrzydło>_tension` |
| COMBAT | `combat` + `combat_hi` (140 BPM, osobna rodzina, zawsze od początku pętli) | **ten sam** `combat` dla wszystkich skrzydeł |
| GUARDIAN | — | `guardian_<skrzydło>` + `_hi` (jedna kompozycja 120 BPM w 6 kolorach, orkiestrowo-etniczna) |
| BOSS / VICTORY / SILENT | T-Rex, stingery | stinger upadku strażnika, nakładane sygnały pieczęci, bram i odkrycia skrzydła |

Mechanika (`src/audio/music.gd`, `music_director.gd`): rodzina = stemy jednej długości w jednym `AudioStreamSynchronized` (po poprawkach z przeglądu, §10; przedtem osobne odtwarzacze startujące w tej samej klatce i `resync()` co sekundę). Strefa z `Events.room_entered` → `variant` (skrzydło) po 1 s utrzymania (`VARIANT_SETTLE`); obchody zapamiętują miejsce; zmiana skrzydła to przenikanie równej mocy 3,5 s. Intensywność (trafienia, zabicia, rany) steruje `combat_hi`; faza 2 strażnika — `guardian_hi`.

### 1.2 Dlaczego warianty „się nie czytają”

1. **Walka jest wspólna** — a w boomer shooterze to walkę słychać najczęściej i najgłośniej. Egipt i Oświecenie brzmią w niej identycznie.
2. **Obchody to miękki ambient** (burdon, flet, pluski, smyczki, −22 LUFS, 60–90 BPM): różnią się skalą i barwą fletu, ale nie gatunkiem ani energią — pod ambientem sal i efektami zlewają się w „ciche tło muzeum”.
3. **Hub, podziemia i dach** nie mają własnej muzyki (grają obchód z lobby).
4. Strażnicy to jedna kompozycja w sześciu instrumentacjach — bez gitar, bez perkusji rockowej.

### 1.3 Narzędzia (bez zmian w zasadzie działania)

`dsp.py` (filtry FFT o zerowej fazie, kołowe pętle, pogłos splotowy, kompresor, limiter, LUFS BS.1770-4), `instruments.py` (pozytywka… koto, klawesyn, bębny ramowe, szczelinowe), `modes.py` (skale na tonice D), `gen_music.py` (Session, mastering rodzin), `gen_wings.py` (skrzydła, strażnicy, sygnały), `encode_ogg.py` (Blender `aud`, stały numer seryjny Ogg), `analyze.py`. Wszystko deterministyczne (ziarno na utwór).

---

## 2. Architektura (decyzje)

### 2.1 Jedna pętla, cztery stemy na strefę (warstwy pionowe w synchronie)

Każda strefa muzyczna ma **jedną rodzinę czterech stemów tej samej długości** (jak „clean/heavy” w ULTRAKILL): `explore_<z>`, `explore_<z>_tension`, `combat_<z>`, `combat_<z>_hi`. Wszystkie cztery to warstwy **jednej kompozycji** (te same akordy, takty, tempo), startują razem i grają razem (ciche na −80 dB), więc każde przejście EXPLORE → TENSION → COMBAT → kulminacja trafia w takt i w harmonię — bez kwantyzacji w kodzie.

- EXPLORE: `explore_<z>` (+ `tension` jako tło w pełnię / po 3:00, jak dotąd),
- TENSION: `explore_<z>` + `explore_<z>_tension`,
- COMBAT: **`combat_<z>` sam** (pełny miks ciężkiej wersji) + `combat_<z>_hi` wg intensywności; obchód i napięcie gasną pod nim w tym samym takcie.

Poziomy głośności zostają jak w całej grze (spójne z miksem, przyciszaniem pod głosem −6 dB i pod sygnałami −8 dB): obchód −22 LUFS, z napięciem −19, walka −18, z kulminacją −16,5; szczyty ≤ −1,5 dBFS.

Lobby (testy, `level_id = lobby`) zostaje bez zmian: jego `explore`/`combat`/`boss` to osobne rodziny jak dotąd.

### 2.2 Strefy muzyczne

`MusicDirector.music_zone_of(zone)`: skrzydło → ono samo; `court`, `entrance`, `booth`, `north_hall` → **`court`** (hub); `basement` i podstrefy → **`basement`**; `roof` → **`roof`**. `wing_of_zone()` zostaje (sygnały odkrycia i strażnicy dotyczą tylko skrzydeł). `variant` = strefa muzyczna.

### 2.3 Zmiana strefy w trakcie walki

Walka gra teraz muzykę strefy, więc przejście przez próg w walce nie może przełączać jej w tę i z powrotem: w COMBAT nowa strefa musi się utrzymać **`FIGHT_SETTLE` = 4 s**; przenikanie walki trwa **`FIGHT_CROSSFADE` = 1,5 s** (dwa ciężkie miksy w różnych tempach nie mogą się nakładać 3,5 s). Obchód: jak dotąd 1 s utrzymania; przenikanie obchodów skrócone do 2,5 s (obchody mają już puls).

### 2.4 Strażnicy

`guardian_<skrzydło>` + `_hi` renderowane w gatunku i brzmieniu skrzydła (ten sam „zespół” co walka strefy, aranżacja bossowa: przebudzenie, riff, motyw strażnika M1–M4 jako prowadzenie, kołysanka, kulminacja, nawrót). Długość zależy od tempa skrzydła (60–72 s, całe sekundy — silnik raportuje je co do próbki). Logika bez zmian.

### 2.5 Pogłos muzyki a #40

Muzyka gra na szynie Music (2D), więc strefy pogłosu jej nie dotyczą (i nie powinny: sala ma pogłos efektów, nie partytury). Zamiast tego **pogłos wpisany w stemy naśladuje akustykę strefy**: długi ciemny kamień galerii (Egipt, Asyria, Ameryki ≈ preset GALLERY), krótki stłumiony pokój biblioteki (Oświecenie ≈ LIBRARY), jasny beton z wczesnymi odbiciami (podziemia ≈ CONCRETE), otwarta przestrzeń bez ścian (dach ≈ GARDEN, prawie bez wczesnych odbić), szklany dziedziniec (hub ≈ VAST). W walce pogłos jest krótszy i suchszy (czytelność riffów).

---

## 3. Tożsamość stref

Wszystkie strefy stoją na tonice **D** (gitary w stroju drop D: najniższa struna = D2), więc przenikanie strefa → strefa to zmiana koloru, nie tonacji.

| Strefa | Gatunek (rdzeń) | Kolor kultury | Skala | Tempo, metrum | Obchód (spokojny, w gatunku) | Napięcie (+) | Walka (sama) | Kulminacja (+) |
|---|---|---|---|---|---|---|---|---|
| **Dziedziniec** (hub: court, hol, kanciapa, korytarz płn.) | darksynth (horror-synthwave) z gitarami w walce | motyw muzeum: kołysanka z pozytywki | d-moll harmoniczna (C#) | 105, 4/4 | miękkie arpeggio syntezatora, ciepły pad, sub-bas, kołysanka na „taśmowej” pozytywce, delikatny bit połówkowy | ósemkowy bas oktawowy, stopa, filtr się otwiera, narastanie | bramkowany werbel, stopa 4/4 + podwójna stopa, przesterowane gitary 16-tkami, bas „reese”, stab’y | piłowy lead z kołysanką, zdziczała pozytywka |
| **Egipt** | orientalny death/thrash (w duchu Nile) | ney, mizmar, darbuka (maqsum), oud, sistrum | D frygijska dominantowa (hidżaz); w prowadzeniu podwójna harmoniczna (C#) | 150, 4/4 | burdon D–A, ney z kołysanką, tremolo oudu, cichy maqsum na bębnie ramowym | darbuka z ozdobnikami, tomy, bas, ciche tremolo gitar na D | tremolo-riffy hidżazu (D–Es–Fis), blasty i podwójna stopa, darbuka w miksie | gitara prowadząca + mizmar unisono, chór „aa”, sistrum |
| **Asyria** | doom/sludge — marsz wojenny | lira, duduk, wielkie bębny ramowe, brąz | D frygijska (kurd) | 90, 4/4 | lira, lament duduka, czyste arpeggio „doom” w pogłosie, uderzenia bębna wojennego | marsz bębnów ramowych, wielki bęben, fuzz na długich D5 | miażdżące riffy D5/Es5, chromatyczne zejścia, podwójna stopa 16-tkami, brąz | duduk + mizmar oktawę wyżej, niski chór „oo”, gitara w kurdzie |
| **Grecja** | epicki heavy/power metal (galop) | aulos (podwójny stroik z burdonem), kithara, tympanon | D dorycka; część B miksolidyjska (Fis — „bohaterskie” rozjaśnienie) | 180, 4/4 (galop) | kithara, aulos z kołysanką, dwie czyste gitary w tercjach, cichy tympanon | galop basu i tomów, kotły | galopujące riffy (Dm–C–G / D–C–G), podwójna stopa w galopie | dwugłosowe prowadzenie w tercjach (twin lead), aulos, chór |
| **Oświecenie** | metal neoklasyczny („barokowy metal”) | klawesyn, organy, zegary, kontrapunkt | d-moll harmoniczna | 140, 4/4 | dwugłosowa inwencja klawesynu ósemkami (sekwencja kwintowa), smyczki, tykanie zegarów, fragmenty kołysanki | organowy pedał, kotły, ciche ósemki gitar na prymach, zegary 16-tkami | klawesyn 16-tkami zdublowany gitarą, riffy na kole kwintowym, podwójna stopa, organy | arpeggia-sweepy gitary w harmonicznej, organy, zdziczała pozytywka |
| **Azja** | taiko-metal z elektroniką | taiko, shamisen, koto, shakuhachi, sho | skala in / miyako-bushi (D–Es–G–A–B) w częściach A i C, pentatonika d-moll (D–F–G–A–C) w B — we wszystkich stemach naraz (przejście obchód → walka nie zgrzyta) | 144, 4/4 | koto i shamisen, shakuhachi z kołysanką, sho, miękki puls sub-basu, daleki taiko | zespół taiko (don–don–doko), ostinato shamisenu 16-tkami | riffy w skali in zdublowane shamisenem, taiko + podwójna stopa | shakuhachi + gitara prowadząca, sho, misa |
| **Ameryki** | plemienny groove metal (w duchu „Roots”) | bębny szczelinowe, huehuetl, gliniane flety, grzechotki, muszla, **gwizdek śmierci** | D eolska (+ frygijskie Es w riffach) | 100, 4/4 | marimba (hemiola), gliniany flet z kołysanką, ciche bębny szczelinowe, grzechotki | plemienne tomy 16-tkami, huehuetl, grzechotki, groove basu | synkopowane riffy groove na D5, plemienne tomy + stopa i werbel, muszla | wrzask gwizdka śmierci na końcach fraz, gliniany flet + gitara, muszla |
| **Podziemia** | industrial metal (w duchu Ministry / NIN / Quake) | kotłownia: rury, młoty, para, kowadła | D frygijska z trytonem (As) | 120, 4/4 | maszynowy puls (syk pary, stuki rur), dalekie młoty, burdon, zardzewiała kołysanka na pozytywce | metalowe uderzenia 16-tkami, zniekształcona stopa, szum narastający | maszyna perkusyjna, mechaniczne riffy z przesterowanym basem syntezatora, kowadła | wyjący lead syntezatora, kołysanka przez bitcrusher, metalowe przeszkadzajki |
| **Dach** | blackgaze / atmosferyczny black metal | nocne niebo nad miastem: dzwony, wiatr | D eolska z „otwartymi” akordami (add9, maj7) | 135, 4/4 | lśniące tremolo czystej gitary w szerokim pogłosie, pad, dalekie dzwony, miękkie tomy | tremolo gitar w średniej głośności, pulsy tomów, narastające talerze | blasty z tremolo-akordami („ściana dźwięku”), podwójna stopa | wysoka melodia (kołysanka długimi nutami nad blastem), chór |

Długości pętli: 96 s (Azja 100 s) — całe sekundy, każda strefa z inną liczbą taktów.

### 3.1 Nowe klocki syntezy (`tools/music/metal.py`)

- **Gitara elektryczna:** sygnał „DI” z modelu Karplusa-Stronga (`ins.pluck`): kostka, struna, wytłumienie dłonią (palm mute: krótki t60, ciemniej), tłumienie po nucie (bramka); akord kwintowy jako dwa–trzy struny z rozstrzałem kostki 3–8 ms. **Wzmacniacz** na całej szynie (nieliniowość musi działać na sumie strun — intermodulacja): wstępny korektor (wycięcie basu, garb 750 Hz jak „tube screamer”), dwa stopnie asymetrycznego `tanh` z **nadpróbkowaniem ×4** (bez aliasingu), stos barwy (wycięty środek 450 Hz, prezencja 2,8 kHz), **symulacja kolumny 4×12** (rezonans ~110 Hz, garby 1,5 / 3 kHz, stromy spadek nad 5 kHz). Podwójne nagranie: dwa niezależne wykonania (inny szum struny, ±4 ms) na lewo i prawo.
- **Gitara prowadząca:** jedna struna z przesterem, wibrato, podjazdy (bend), legato.
- **Gitara czysta:** ta sama struna przez czysty „wzmacniacz” z chorusem.
- **Bas:** kostkowy Karplus-Strong + sinus podbicia, lekki przester, „klank” 800 Hz.
- **Zestaw metalowy:** stopa z klikiem pałki (trigger), werbel z trzaskiem i sprężynami, tomy, hi-hat (6 kwadratowych oscylatorów o nieharmonicznych częstotliwościach, zamknięty/otwarty), ride, crash, china.
- **Syntezatory:** supersaw (lead), reese (bas), pluck (arpeggio), pad; bramkowany pogłos werbla (lata 80.).
- **Kultura:** gwizdek śmierci (turbulentny strumień w komorze: szum przez wędrujące rezonanse + chaotycznie modulowany ton), shamisen (Karplus-Strong z brzęczeniem „sawari” i uderzeniem bachi w skórę), aulos (dwie piszczałki: melodia + burdon), oud (tremolo, krótkie wybrzmienie, pudło), uderzenia metalu (rury, blacha) i syk pary.

### 3.2 Zespół (`tools/music/band.py`)

`Band` (pochodna `Session`): szyny mogą zasilać kilka stemów naraz, poziom szyny ustawiany wg LUFS **po** jej przetworzeniu (wzmacniacz zmienia głośność), wzmacniacz gitarowy jako przetwarzanie szyny (przed EQ), wzorce perkusji (połówkowy, rockowy, d-beat, podwójna stopa, blast, galop, plemienny, industrialny), riffy w krokach szesnastkowych z artykulacją (palm mute / otwarty / akord / pauza), melodia w stopniach skali (`modes.note`). Mastering czterech stemów: para obchodu (−22 / −19) i para walki (−18 / −16,5), każda z limiterem liczonym na sumie pary, **jeden obrót szwu dla całej czwórki** (stemy zostają w synchronie).

---

## 4. Zadania (wykonane)

1. **Plan** — ten dokument.
2. **Klocki syntezy** `tools/music/metal.py` + testy Pythona `tools/music/test_music_gen.py` (deterministyczność, bramka nuty, palm mute krótszy i ciemniejszy, wzmacniacz: cisza zostaje ciszą, obrót pętli = obrót wyjścia, brak DC, środek pasma, kolumna tnie „syk”; perkusja znormalizowana, głosy kultury).
3. **Zespół** `tools/music/band.py` + testy (notacja riffów i perkusji, arpeggia z własnych tonów akordu, mała pętla czterech stemów: powtarzalna, trafia w cele ±0,3 LU, szczyty par ≤ −1,5 dBFS, jedna długość, szew).
4. **Gra (TDD)** — najpierw czerwone testy, potem kod: `MusicDirector.MUSIC_ZONES`, `HUB_ZONES`, `music_zone_of()`, `ZONE_LAYERS` (walka i jej hi w kolorach strefy), `FIGHT_SETTLE` = 4 s; `Music`: rodziny czterech stemów, `track()`/`layer_of()` dla `combat_<strefa>[_hi]`, `CROSSFADE` 3,5 → 2,5 s, `FIGHT_CROSSFADE` = 1,5 s. Testy: `tests/unit/test_music_wings.gd` (+4), `tests/integration/test_music_wings.gd` (+3, 2 przepisane), `tests/unit/test_audio_assets.gd` (długości stref i strażników).
5. **Kompozycje stref** — `biomes_west.py` (Egipt, Asyria, Grecja, Ameryki), `biomes_east.py` (hub, Oświecenie, Azja, podziemia, dach), rejestr `gen_biomes.py`. Trzy przebiegi renderu z poprawkami liczbowymi (niżej).
6. **Strażnicy** — `guardians.py`: ta sama kompozycja w zespole każdego skrzydła.
7. **Kodowanie** (128 kbit/s), import, szwy przez silnik (`build_audio.sh check`: najgorszy stosunek 2,53 < 3), testy zasobów.
8. **Dokumentacja** — `docs/audio/dzwiek-przewodnik.html` §11 (muzyka biomów, strażnicy, regeneracja, rozmiar), ten plan.
9. `git merge pietro-1` + pełny zestaw.

Uporządkowane: z `gen_wings.py` usunięte stare obchody i stary temat strażników (martwy kod); zostały wspólna harmonia (akordy, motyw M1–M4, kołysanka w 4/4, harmonia strażników) i sygnały (bez zmian).

### 4.1 Iteracja „liczbami zamiast uszu”

| Przebieg | Co pokazały liczby | Poprawka |
|---|---|---|
| prototyp (Egipt) | walka: sub 36 % energii (stopa, sinus pod basem, burdon D1) | bas: sinus 0,5 → 0,2, górnoprzepustowy 40 → 50 Hz; stopa krótsza, wyżej (58 Hz), z mocniejszym klikiem; burdon walki od 60 Hz |
| 1. (zachód) | dwa stemy ze skokiem na szwie > 0,6 p99,9 (gęste szesnastki tuż przed „raz”) | obrót szwu szuka cichego miejsca do 0,4 s przed taktem (było 0,15 s) |
| 1. (wschód) | hub i podziemia: sub 44–65 % — basy syntezatorów na D1 (37 Hz) | basy elektroniczne w zakresie A1–G#2 (55–104 Hz) |
| `check_line()` (sucha próba bez syntezy) | dłuższe nuty zgrzytające z akordem: Grecja (kołysanka nie pasowała do galopu), Ameryki, Asyria, Azja | harmonia części B i A2 w Amerykach i Egipcie ułożona pod melodię; Grecja: własny temat strefy, osobna linia drugiej gitary, temat mostu; Azja: kołysanka w skali *in* z tercją podniesioną na G (`insen_up`) |
| 2. (fragment walki przez prawdziwe szyny) | miks ciemny i ciężki w dole: sub 26 / low 36 / high 4 % | stopa −1,5 dB i krótsza, kolumna 6,8 kHz (rząd 3), prezencja +4,5 dB, talerze +1,5 dB powyżej 7 kHz → sub 9 / low 42 / lowmid 22 / mid 19 / high 5 % |
| 3. (silnik) | `combat_asia_hi` — skok 0,10 na szwie po dekodowaniu (WAV ciągły: to koder odbudowuje początek pliku najgorzej, a pod szwem trwał obłok sho i nuta shakuhachi); `guardian_asia` 3,42 | stem hi Azji „oddycha” na szwie; wszyscy strażnicy kończą pętlę krótkim „stopem” (2 szesnastki ciszy przed „raz”) |

## 5. Wyniki (zmierzone `analyze.py`, BS.1770-4)

Cele miksu gry (bez zmian względem dotychczasowej muzyki): obchód −22 LUFS, z napięciem −19, walka −18, z kulminacją −16,5; szczyty ≤ −1,5 dBFS.

| Strefa | Gatunek | Kolor kultury | Tempo | Pętla | Obchód / +napięcie | Walka / +hi | True peak (najgłośniejsza para) | Walka: sub/low/lowmid/mid/high % |
|---|---|---|---|---|---|---|---|---|
| hub (dziedziniec) | darksynth + gitary | kołysanka muzeum, pozytywka | 105 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −4,9 dBFS | 23/50/11/12/3 |
| Egipt | orientalny death/thrash | nej, mizmar, darbuka, oud, sistrum; hidżaz + podwójna harmoniczna | 150 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −5,1 | 8/46/22/18/4 |
| Asyria | doom, marsz wojenny | lira, duduk, bębny ramowe, brąz; kurd | 90 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −3,6 | 22/36/21/17/3 |
| Grecja | heavy metal z galopem | aulos, kithara, tympanon; dorycka / miksolidyjska | 180 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −5,2 | 9/42/23/18/5 |
| Oświecenie | metal neoklasyczny | klawesyn, organy, zegary; harmoniczna | 140 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −5,1 | 11/34/24/24/6 |
| Azja | taiko-metal + elektronika | taiko, shamisen, koto, shakuhachi, sho; *in* / pentatonika | 144 | 100 s | −22,0 / −19,0 | −18,0 / −16,5 | −5,1 | 23/39/16/16/4 |
| Ameryki | plemienny groove | bębny szczelinowe, gliniany flet, gwizdek śmierci, muszla; eolska | 100 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −4,8 | 10/51/19/16/3 |
| podziemia | industrial metal | rury, młoty, para, kowadła; frygijska z trytonem | 120 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −5,6 | 20/51/7/16/4 |
| dach | blackgaze | dzwony, wiatr; eolska, otwarte akordy | 135 | 96 s | −22,0 / −19,0 | −18,0 / −16,5 | −6,2 | 11/36/22/22/6 |

Strażnicy (baza / z hi): wszyscy −18,0 / −16,5 LUFS, true peak −4,5…−5,9 dBFS; Egipt 64 s, Asyria 64 s, Grecja 64 s, Oświecenie 72 s, Azja 60 s, Ameryki 72 s.

Szwy: skok na zawinięciu WAV-a ≤ 0,77 typowego kroku (p99,9), po dekodowaniu przez Godota poniżej 0,8; dekoder za pętlą daje próbka w próbkę to samo co od początku pliku, długości co do ramki (`test_audio_assets`, `build_audio.sh check`). Korelacja kanałów: obchody 0,28 (dach — celowo szeroki) … 0,70, walki 0,56–0,71. Rozmiar: muzyka Piętra I ok. 65 MB (było ok. 29 MB).

Sub w hubie, Asyrii, Azji i podziemiach (20–23 %) zostawiony świadomie: darksynth, doom, taiko i industrial stoją na niskim dole; strefy gitarowe mają 6–11 %.

## 6. Decyzje z kompromisem

- **Walka wchodzi w bieżącym takcie pętli strefy**, nie od jej początku (wcześniej `combat` zawsze startował od „raz”). Zysk: przejście obchód → walka jest w takt i w harmonii; koszt: walka może zacząć się w środku frazy.
- **Walka w drzwiach** trzyma swoją muzykę 4 s (`FIGHT_SETTLE`); bieg przez dwie strefy w czasie walki zmieni muzykę dopiero po utrzymaniu nowej.
- **Lobby bez zmian** (testy, `level_id = lobby`): swój „Obchód” i `combat`. Gra (Piętro I) nie gra już muzyki lobby w żadnej strefie.
- **Sygnały** (pieczęć, brama, odkrycie skrzydła, upadek strażnika) bez zmian — orkiestrowe, krótkie, pod nimi muzyka przyciszana o 8 dB. Do decyzji właściciela, czy mają dostać gitarowe uderzenie.
- **Faza 3 strażnika** (backlog): nadal tylko warstwa hi od fazy 2; trzecia warstwa wymagałaby trzeciego stemu na skrzydło.
- **#40 (akustyka sal)**: muzyka jest 2D i nie przechodzi przez strefy pogłosu sal; zamiast tego pogłos w stemach naśladuje akustykę strefy. Pogłos efektów w salach działa jak dotąd.
- **Zostawione zgrzyty** (zamierzone): Es nad D w hidżazie, C nad D (septyma D7) w Egipcie, przejściowe E kołysanki nad d-moll (hub, Oświecenie), appoggiatury motywu strażnika (b9/9 → 1), w Azji kilka Es nad D5 (skala *in*).
- Pogłos muzyki i **głośność** zgodne z dotychczasowym miksem; odsłuch w grze może pokazać, że walka metalowa przy −18 LUFS „wydaje się” cichsza niż orkiestrowa (gęsty, skompresowany sygnał) — to jedna stała (`band.TARGETS`).

## 7. Do sprawdzenia w oknie (z dźwiękiem, przez właściciela)

- Każda strefa: czy obchód da się słuchać 10 minut bez zmęczenia; czy walka „uderza” (gitary, stopa) i czy kolor kultury słychać także w walce.
- Przejścia: EXPLORE → TENSION → COMBAT → spokój w jednej strefie (powinny być w takt); próg między strefami w obchodzie (2,5 s) i w walce (po 4 s utrzymania, 1,5 s przenikania).
- Głośność walki względem strzałów i głosu (miks gry: muzyka pod efektami).
- Strażnicy: czy temat brzmi jak „boss” danego skrzydła; „stop” przed zawinięciem pętli.
- Brzmienie gitar (wzmacniacz z syntezy, bez próbek) — czy nie jest „plastikowe”; jeśli tak, pierwsze pokrętła: `metal.amp` (`drive`, `presence_db`, `cab`), poziomy szyn `gtr` w tabelach stref.

## 8. Przewodnik odsłuchu (dla właściciela)

Pliki w `assets/music/` (otworzy je każdy odtwarzacz). W grze stemy jednej strefy grają **razem**: `explore_…` sam to obchód, `explore_…` + `explore_…_tension` to napięcie, `combat_…` sam to walka, `combat_…` + `combat_…_hi` to kulminacja. Żeby usłyszeć warstwę jak w grze, odpal dwa pliki naraz od początku (są tej samej długości i w synchronie).

| Pliki | Strefa / warstwa | Na co zwrócić uwagę |
|---|---|---|
| `explore_court`, `_tension`, `combat_court`, `_hi` | hub: dziedziniec, hol, kanciapa, korytarz płn. | obchód: miękkie arpeggio syntezatora i kołysanka na pozytywce (takty 9 i 33); napięcie: ósemkowy bas oktawowy i stopa 4/4; walka: bramkowany werbel lat 80., przesterowane gitary szesnastkami, bas „reese” pompujący pod stopę; hi: piłowy lead z kołysanką + zdziczała pozytywka |
| `…_egypt` | Egipt | obchód: nej z kołysanką w hidżazie, tremolo oudu (takty 17–24), cichy maqsum; walka: riff D–Es–Fis–G na dolnej strunie, blasty w części D (t. 41–48); hi: gitara i mizmar unisono w podwójnej harmonicznej (C#) |
| `…_assyria` | Asyria | obchód: lira, lament duduka, ringujące akordy „doom”; napięcie: marsz bębnów ramowych i wielki bęben; walka: miażdżące D5/Es5 i tryton A–Es, sludge w części C (t. 17–24); hi: duduk + mizmar oktawę wyżej |
| `…_greece` | Grecja | walka: galop (ósemka + dwie szesnastki), część B (t. 17–32) w miksolidyjskiej — jaśniejsza; hi: dwie gitary w tercjach, aulos w moście (t. 33–48) |
| `…_enlightenment` | Oświecenie | obchód: dwugłosowa inwencja klawesynu i zegary; walka: riffy na kole kwintowym (t. 9–24) z klawesynem szesnastkami; hi: sweepy gitary po akordach, organy w części C |
| `…_asia` | Azja | obchód: koto, shamisen, shakuhachi z kołysanką, sho, sub-puls i arpeggio syntezatora w części B; walka: riffy w skali *in* (A, C) i pentatonice (B) z taiko na kicie; hi: shakuhachi + gitara |
| `…_americas` | Ameryki | obchód: marimba 3+3+2, gliniany flet z kołysanką „3 na 4”; walka: groove D5–F5–G5 z plemiennymi tomami, przerwa plemienna (t. 17–24); hi: **gwizdek śmierci** na końcach fraz (t. 8, 16, 24, 32, 40), muszla |
| `…_basement` | podziemia | obchód: maszynowy puls (rury, para, dalekie młoty), zardzewiała pozytywka; walka: automat perkusyjny, synkopowane riffy z trytonem As; hi: wyjący lead z poślizgami |
| `…_roof` | dach | obchód: lśniące tremolo czystej gitary w szerokim pogłosie, dalekie dzwony; walka: blasty pod tremolo otwartych akordów, dolina w części C (t. 17–24); hi: wysoka melodia długimi nutami, chór |
| `guardian_<skrzydło>`, `_hi` | strażnik skrzydła | przebudzenie (uderzenia na raz), riff skrzydła, motyw strażnika na gitarze i głosie kultury, kołysanka nad zwolnionym „miażdżeniem”, kulminacja oktawę wyżej, „stop” przed powrotem |

## 9. Stan prac / co dalej

- [x] 1. Plan
- [x] 2. Klocki syntezy (`metal.py`) + testy
- [x] 3. Zespół (`band.py`) + testy
- [x] 4. Gra (TDD): strefy muzyczne, walka za strefą, `FIGHT_SETTLE`, przenikania
- [x] 5. Kompozycje 9 stref (3 przebiegi poprawek liczbami)
- [x] 6. Strażnicy w zespołach skrzydeł
- [x] 7. Kodowanie, import, szwy przez silnik
- [x] 8. Dokumentacja (przewodnik dźwięku §11, ten plan)
- [x] 9. Merge `pietro-1` (czysty) i pełny zestaw: 2317 zielonych, 0 błędów; testy Pythona `test_music_gen` 14/14

Co dalej (poza zakresem): odsłuch właściciela (§7) i strojenie poziomów; ewentualnie gitarowe sygnały; trzecia warstwa strażnika (faza 3).

## 10. Poprawki po przeglądzie (gałąź `fix-music`)

Przegląd `music-biomes` wskazał pięć rzeczy; wszystkie zrobione, bez ruszania zasobów (muzyka nie była renderowana na nowo).

| # | Znalezisko | Poprawka | Test |
|---|---|---|---|
| 1 | Start ładował wszystkie 55 strumieni + 11 sygnałów: ok. 93 MB rezydentnie (+37 MB względem poprzedniej wersji) i ok. 0,45 s blokady autoloadu | Przy starcie tylko menu, rodziny lobby (`Music.EAGER`) i sygnały: 18 plików, ok. 80 ms, ok. 18 MB. Rodziny stref i strażników ładuje `Music` w tle (`ResourceLoader.load_threaded_request`, odbiór w `_process`) przy `Events.room_entered` (strefa + strażnik skrzydła) i przy przebudzeniu strażnika; zostaje 6 ostatnich (`MAX_FLOOR_FAMILIES`), nigdy grająca ani ta, w której stoi strażnik; scena bez strefy (`forget_zone`) i `reset()` zwalniają wszystkie. Rodzina w drodze nic nie gra (albo gra dalej poprzedni motyw), więc żadna klatka nie czeka, a melodia lobby nie podstawia się pod strefę | `test_music.gd::test_at_boot_only_the_menu_the_lobby_and_the_stings_are_loaded`; `test_music_wings.gd`: ładowanie przy wejściu do skrzydła, samoczynne ładowanie wymaganej rodziny, zwolnienie po wyjściu z piętra, limit 6, cisza podczas ładowania, poprzedni motyw gra dalej, porzucone ładowanie |
| 2 | Cztery osobne `play()` rozjeżdżały stemy o 23–93 ms w ok. 7,5 % startów rodziny; `resync()` przesuwał je do 1 s później (słyszalny skok przy wejściu stemów walki). Pauza przez osobne odtwarzacze mogła rozjechać je tak samo (wniosek z mechanizmu, nie pomiar) | Jedna rodzina = jeden `AudioStreamPlayer` z `AudioStreamSynchronized` (stemy w kolejności `FAMILIES`), głośność stemu przez `set_sync_stream_volume`, przyciszenie pod sygnałem to głośność samego odtwarzacza. Start, pauza i zawinięcie co do próbki; `resync()`, `SYNC_INTERVAL`, `SYNC_TOLERANCE` usunięte | `test_the_stems_of_a_family_share_one_player_and_one_clock`, `test_every_stem_has_its_own_volume_on_the_shared_player`, istniejące testy przenikań, poziomów i wznawiania |
| 3 | Strażnik budzony w trakcie walki: stem walki strefy zalegał ok. 3 s pod jego motywem (`FADE_OUT` walki 4 s) | `fade_out_time()` = `BOSS_FADE` (1 s) w stanach GUARDIAN i BOSS (po śmierci, świcie i ciszy po wyłączeniu prądu, które mają pierwszeństwo) | `test_a_guardian_clears_the_zones_fight_fast`, `test_a_boss_clears_the_walk_and_the_fight_fast` |
| 4 | Nieaktualne nazwy i komentarze: `variant` opisany jako „skrzydło obchodu”, lokalna `wing` trzymająca strefę, klucz rodziny `explore_<strefa>` trzymający też stemy walki, gdy `resumes()` i `set_scene_kind` opierały się na `begins_with("explore")` | Klucz rodziny strefy to `zone_<strefa>` (`Music.zone_family()`, `guardian_family()`), `is_walk()` zamiast `begins_with`; opisy `variant`/`LAYERS` w `MusicDirector` mówią o strefie muzycznej; lokalna `zone` | `test_tracks_map_back_to_their_layers` |
| 5 | Narzędzia Pythona: nieużywane importy i zmienne pętli (`band.py`, `biomes_east.py`, `biomes_west.py`, `guardians.py`, `metal.py`), odstęp w `encode_ogg.py`; `RenderedAssets` przechodziły po cichu bez wyrenderowanych WAV-ów | Usunięte; testy `RenderedAssets` przy braku WAV-ów w `build/audio_src/music` kończą się wyraźnym `SKIPPED: ... NOT run` (komunikat na stderr i powód pominięcia) | `python -m unittest test_music_gen`: 14/14 (z WAV-ami); bez WAV-ów 2 pominięte z komunikatem |

### 10.1 Pomiary (headless, sterownik Dummy)

| | przed | po |
|---|---|---|
| pamięć statyczna po starcie (autoloady, bez sceny) | 251,7 MB | 177,3 MB |
| ładowane przy starcie | 66 plików, ok. 460 ms, +92,9 MB | 18 plików, ok. 80 ms, +18,5 MB |
| rodzina strefy (4 stemy) w grze | w pamięci od startu | ładowana w tle ok. 30 ms (4 klatki, najdłuższa klatka 6,9 ms); po zwiedzeniu 8 stref w pamięci 6 rodzin (ok. 210 MB), po `reset()` ok. 177 MB |

### 10.2 Decyzje z kompromisem

- **Głośność stemu to krok, nie rampa.** `set_sync_stream_volume` działa na strumieniu i wchodzi w życie przy najbliższym miksie (ok. 11 ms), bez wygładzania, jakie mikser daje głośności odtwarzacza. Przy szybkim wejściu walki (0,35 s) pierwsze kroki to ok. 7 % wzmocnienia; przy wolnych przenikaniach (1–5 s) są niesłyszalne. Przyciszenie pod sygnałem idzie głośnością odtwarzacza (wygładzoną). Do sprawdzenia uchem (niżej).
- **Zapas pamięci zamiast sąsiadów:** zamiast grafu sąsiednich stref trzymamy 6 ostatnich rodzin (zwykle 3 skrzydła z ich strażnikami), a ładowanie jednej rodziny (ok. 30 ms w tle) mieści się w 1 s `VARIANT_SETTLE` i 4 s `FIGHT_SETTLE`. Wyjątek to start nocy w piętrze: pierwsza rodzina ładuje się ok. 4 klatki, w tym czasie nie gra nic.
- **Rodziny lobby zostają w pamięci** (menu, `explore`, `combat`, `boss`, sygnały), jak chciał przegląd.

### 10.3 Do sprawdzenia w oknie (z dźwiękiem, przez właściciela)

- Wejście walki w strefie (Egipt, Grecja): czy szybkie wejście `combat_<strefa>` nie „trzeszczy” (głośność stemu zmienia się skokami co ok. 11 ms; spodziewane: niesłyszalne pod gęstym miksem).
- Obudzenie strażnika w trakcie walki: walka strefy gaśnie w ok. 1 s, motyw strażnika wchodzi czysto.
- Start nocy w piętrze: czy między ciszą a pierwszym obchodem strefy nie słychać luki (ok. 4 klatki ładowania) ani kawałka muzyki lobby.
- Pauza i wznowienie w grze: stemy dalej w takt (jeden odtwarzacz, nie powinno być rozjazdu).
