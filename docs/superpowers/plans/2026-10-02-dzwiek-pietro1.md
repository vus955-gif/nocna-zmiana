# Dźwięk Piętra I — ambient skrzydeł, warianty muzyki, temat strażników, efekty

> Plan wykonawczy. Wykonawca: Claude (kompozytor i dźwiękowiec, worktree `audio-wings`, gałąź `audio-wings` od `b86f61c`).
> Projekt nadrzędny: `docs/superpowers/specs/2026-10-02-pietro-1-projekt.md` — §10.4 (dźwięk i muzyka), §5 (charakter skrzydeł), §7 (bronie, wrogowie, strażnicy), §4.2 (zamki).
> Zasady jak dotąd: cała synteza skryptami (numpy, kodowanie Ogg przez moduł `aud` Blendera), bez próbek z zewnątrz, wyniki deterministyczne (ziarna). **Zero odsłuchu** — oceniam liczbami (`analyze.py`: LUFS, szczyty, pasma, szwy, spektrogramy) i testami silnika. Dźwięków broni nie robię (inny agent).

**Cel:** każde skrzydło brzmi jak osobny świat, a gra pozostaje jednym utworem: ta sama kołysanka (d-moll) wraca w sześciu skalach i instrumentacjach; muzyka i ambient same idą za strażnikiem po strefach (`Events.room_entered`), strażnicy skrzydeł mają wspólny temat walki w barwach skrzydła, a postęp metroidvanii (pieczęć, odłamek, brama, nowe skrzydło) ma swoje krótkie sygnały.

## Kontrakt i decyzje

- **Strefy** (kontrakt `Floor1Plan`): `court`, `entrance`, `booth`, `egypt`, `assyria`, `greece`, `enlightenment`, `asia`, `americas`, `north_hall`, `basement`, `roof`. Źródło prawdy w dźwięku: sygnał `Events.room_entered(room, zone, first_visit)`.
- **Wariant muzyki** = skrzydło strefy (`egypt` … `americas`); pozostałe strefy grają dotychczasowy „Obchód”. Podstrefy dźwięku (np. `asia_garden`) należą do skrzydła przed podkreśleniem.
- **Wszystko na tonice D** (płynne przenikanie między skrzydłami):

| Skrzydło | Skala | Instrumenty (obchód) | Napięcie | Strażnik (lead w warstwie hi) |
|---|---|---|---|---|
| Egipt | D frygijska dominantowa (hidżaz) | nej, harfa, burdon | darbuka/bębny ramowe, sistrum | ostinato harfy, lead: podwójny stroik (mizmar) |
| Asyria | D frygijska (kurd) | lira, niskie bębny ramowe, burdon | bębny ramowe, brąz | lira, lead: stroik ciemny, chór męski, brąz |
| Grecja | D dorycka | kithara, powietrzny chór, szklane tony | tympanon, tremolo | kithara, lead: trąbka (salpinx), chór |
| Oświecenie | d-moll harmoniczna (barok) | klawesyn, pozytywka, zegary | spiccato, kotły, tykanie | arpeggia klawesynu, lead: organy + zdziczała pozytywka |
| Azja | pentatonika d-moll (+ barwy skali in) | koto, shakuhachi, misa | taiko, kotsuzumi | koto, lead: shakuhachi |
| Ameryki | D eolska (heksatonika) | marimba, gliniane flety, bębny szczelinowe | bębny szczelinowe, grzechotki | marimba, lead: gliniany flet + muszla |

- **Długości:** obchód skrzydła ≈ 96 s (pętla, dwa stemy), temat strażnika 64 s (120 BPM, 32 takty, dwa stemy; długość, którą silnik raportuje co do próbki), sygnały 3–7 s. Muzyka skrzydeł kodowana 128 kbit/s (rozmiar repozytorium); dotychczasowe pliki bez zmian (bajt w bajt).
- **Głośność:** obchód skrzydła −22 LUFS, z napięciem −19 (jak „Obchód”: przenikanie bez skoku); strażnik −18 / pełny −16,5; sygnały −19…−21 z przyciszeniem muzyki pod nimi.
- **Strażnicy:** `guardian_awakened(node, id)` → stan `GUARDIAN` z wariantem skrzydła: `colossus`→Egipt, `lamassu`→Asyria, `centaur`→Grecja, `orrery`→Oświecenie, `samurai`→Azja, `serpent`→Ameryki (też przedrostek `colossus_…` i id będące nazwą skrzydła; nieznane → skrzydło bieżącej strefy). Faza ≥ 2 (sygnał `phase_changed` węzła, jeśli jest) lub żar walki → warstwa hi. `guardian_defeated` → krótki sygnał upadku strażnika, potem obchód. Gdy ten sam węzeł ogłosi też `boss_awakened` (pasek HUD), wygrywa temat strażnika, nie T-Rex.
- **Sygnały nakładane** (pod nimi muzyka ścisza się o kilka dB): pieczęć/odłamek (`seal_collected`, `shard_collected`), brama (`gate_opened`), nowe skrzydło (pierwsze `room_entered` z `first_visit` w strefie skrzydła, której jeszcze nie było w tej sesji; nie w walce).
- **Bez restartów:** powrót do tej samej strefy nie zaczyna utworu od nowa (rodzina gra dalej albo wraca z zapamiętanego miejsca); zmiana wariantu po krótkim ustaleniu strefy (bez migotania na progu).

## Zadania

### Z1. Plan (ten dokument) — commit

### Z2. Nowe instrumenty i skale (`tools/music/instruments.py`, `tools/music/modes.py`)
- Głosy: nej / shakuhachi / gliniany flet (jeden model fletu: alikwoty + szum oddechu przy alikwotach, podjazdy, vibrato, „meri”), podwójny stroik, lira i kithara, koto (z dociśnięciem struny), klawesyn (8′ + 4′, piórko, opadnięcie skoczka), marimba (mody 1 : 3,9 : 9,2 + rezonator), bęben szczelinowy, bęben ramowy (doum/tek), grzechotka/sistrum, misa, muszla.
- `modes.py`: skale skrzydeł, nuty ze stopni, kołysanka w stopniach.
- Weryfikacja: arkusz próbek → `analyze.py` (pasma, obwiednie, wysokość z widma) i spektrogramy. Istniejące głosy bez zmian (te same ziarna → te same pliki).

### Z3. Obchód skrzydeł (`tools/music/gen_wings.py`, cel `gen_music.py wings`)
- Sześć utworów, każdy: `explore_<skrzydło>` + `explore_<skrzydło>_tension`, renderowane kołowo, jeden obrót szwu na rodzinę.
- Sprawdzenie: LUFS ±0,3, szczyt ≤ −1,5 dBFS, szew, udział pasm, spektrogram (motyw widoczny), kontrola dysonansów melodii względem akordu.

### Z4. Temat strażników i sygnały
- `guardian_<skrzydło>` + `guardian_<skrzydło>_hi` (wspólna kompozycja w stopniach skali, instrumentacja skrzydła).
- `guardian_sting`, `seal_sting`, `gate_sting`, `wing_sting_<skrzydło>` (6 krótkich zawołań skrzydeł).
- Kodowanie (`encode_ogg.py`: 128 kbit/s dla muzyki skrzydeł), import, `build_audio.sh check`.

### Z5. Muzyka w grze (`src/audio/music_director.gd`, `src/audio/music.gd`)
- `MusicDirector`: strefa → wariant (ustalenie 1 s, natychmiast poza obchodem), stan `GUARDIAN` (dopisany na końcu enumu), mapa strażników, rodzaj zwycięstwa (T-Rex / strażnik), czyste funkcje `wing_of_zone()`, `guardian_wing()`.
- `Music`: rodziny wariantów (jedna rodzina na skrzydło i warstwę logiczną), przenikanie wariantów (`CROSSFADE`), wznawianie każdej rodziny obchodu z jej miejsca, sygnały nakładane z przyciszaniem (`DUCK_DB`), sygnały z `Events` (`room_entered`, `guardian_*`, `seal_collected`, `shard_collected`, `gate_opened`).
- Testy: jednostkowe dyrektora (mapa stref, mapa strażników, ustalanie wariantu, GUARDIAN, fazy, zwycięstwo strażnika, boss + strażnik), integracyjne `Music` (przenikanie wariantów bez restartu, powrót do strefy, temat strażnika, sygnały i przyciszenie), `test_audio_assets` (długości pętli, rodziny).

### Z6. Ambient stref (`tools/music/gen_ambience.py`)
- Nowe warstwy (pętle 40 s): wiatr na szkle, miasto w oddali, głęboki kamień, sypki piasek, wiatr w szczelinach, cedr, ogień, powietrzna cisza, krople, zegary, biblioteka, dzwonki wietrzne, ogród (woda + świerszcze), szelest papieru, bębny szczelinowe w oddali, kotłownia, wiatr na dachu.
- Nowe dalekie dźwięki (po 3 ujęcia): szkło dachu, piasek, kamień, belka, kropla, kartki, bicie zegara, dzwonki, shishi-odoshi, dzwon świątynny, bęben, żar, para, szyby.
- Sprawdzenie: LUFS warstw, szwy, pasma.

### Z7. Ambient w grze i pogłos (`src/audio/ambience.gd`, `reverb_zone.gd`, `default_bus_layout.tres`)
- Strefy Piętra I (12 + podstrefy `asia_garden`, `basement_boiler`, `enlightenment_clocks`, `egypt_tomb`), strefa z `room_entered` (kolejność: ręczna > `AmbienceZone` > `room_entered` > `room_at` > domyślna), dalekie dźwięki stref.
- Presety pogłosu (dopisane na końcu enumu): `VAST` (szklany dziedziniec), `GALLERY` (długa kamienna galeria), `LIBRARY` (drewniana biblioteka), `GARDEN` (ogród pod gołym niebem), `CONCRETE` (betonowe podziemia) + szyny pogłosu; automatyczne strefy pogłosu z pola `zone` pokoju (`ZONE_REVERB`), gdy id pokoju nie ma w `ROOM_REVERB`.
- Testy: strefa z sygnału, priorytety, warstwy i dalekie dźwięki każdej strefy istnieją, presety i szyny, pogłos ze strefy pokoju.

### Z8. Efekty (`tools/sfx/gen_sfx.py` + `tools/sfx/floor1_sfx.py`, `src/fx/sfx.gd`)
- Zamki: łańcuch, deski (uderzenie, rozbicie), spękany mur (rysa, zawalenie), pieczęć (osadzenie, tarcie kamienia), żaluzja z przekaźnikiem i buczeniem, zasilanie, zasuwa, lina, przeciwwaga, hak.
- Wrogowie: mumia (jęk, bicz z bandaży), rój skarabeuszy (pętla), relief (pęknięcie, tarcie), księgi (trzepot, stado — pętla), pies Fu (metaliczny ryk), totem (plucie), jaguar (warknięcie), hoplita (tarcza, pchnięcie).
- Strażnicy: Kolos (tarcie, uderzenie dłonią, ładowanie i promień), Lamassu (podmuch, tupnięcie, szarża), Kentaur (galop — pętla, oszczep), Planetarium (tryby — pętla, zamach ramienia), Generał (błysk, cięcie, salwa strzał), Wąż (syk, grzechot mozaiki).
- Ziarno z nazwy (dotychczasowe pliki bajt w bajt bez zmian), pętle z `loop_mode` forward w `.import`, wpis w `Sfx.SOUNDS`, testy (pliki, pętle).

### Z9. Przewodnik i zamknięcie
- `docs/audio/dzwiek-przewodnik.html`: strefy Piętra I, warianty muzyki, temat strażników, sygnały, presety pogłosu, tabela efektów (nazwa, opis, długość, pętla) dla budowniczych (`Sfx.play_at(&"…", pozycja)`).
- Pełny zestaw testów zielony; raport.

## Ryzyka

| Ryzyko | Odpowiedź |
|---|---|
| Rozmiar repozytorium (≈ 30–40 MB nowej muzyki) | 128 kbit/s dla wariantów, pętle ≈ 96 s / 69 s, ambient mono tam, gdzie nie ma obrazu stereo; jeden render końcowy (iteracje na WAV-ach w `build/`) |
| Brak odsłuchu | analiza liczbowa, spektrogramy, kontrola dysonansów, tylko sprawdzone techniki syntezy z istniejących utworów |
| Konflikty scalania z agentem broni (`gen_sfx.py`, `sfx.gd`) | nowe efekty w osobnym module `floor1_sfx.py`, w `gen_sfx.py` i `Sfx.SOUNDS` po jednym wyraźnym bloku |
| Strefa ogłoszona przed zmianą sceny | ta sama zasada „ogłoszone w tej samej klatce zostaje” co `NightMood` |
