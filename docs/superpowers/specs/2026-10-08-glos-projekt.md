# Głos w Nocnej Zmianie — projekt

> **Stan:** 8 października 2026, projekt zatwierdzony przez właściciela w rozmowie (części 1–3). Gałąź docelowa: `pietro-1`.
> **Etap G1 (szkielet) wykonany** na gałęzi `voice-g1` (plan `docs/superpowers/plans/2026-10-08-glos-g1-szkielet.md`, sekcja „Stan prac”): narzędzia, reżyser, kanały, napisy, zapis, opcje, rekwizyty, 4 kwestie próbne. Odstępstwo: obróbka Systemu (§5.3) bez pyworld – własne YIN + TD-PSOLA w numpy (brak Windows SDK na tym komputerze). Czeka na wybór głosów przez właściciela (`build/voice-samples/index.html`).
> **Etap G2 (kwestie) wykonany** na gałęzi `voice-g2` (plan `docs/superpowers/plans/2026-10-19-glos-g2-kwestie.md`): 140 kwestii (Heniek 69, System 47, audioprzewodnik 12 stanowisk × A/B), 12 głośników, 12 stojaków z numerami, nowe zdarzenia (sekret, zmęczenie, pełna godzina, bezruch) i świt bez czekania. Eskalacja Systemu ponad stopień 2 — tekstem i tempem; stopień 3 obróbki czeka na odsłuch właściciela.
> **Etap G3 (zdarzenia niesamowite) wykonany** na gałęzi `voice-g3` (plan `docs/superpowers/plans/2026-10-22-glos-g3.md`): cztery kwestie podpięte do `Events.uncanny_event` (awaria lamp, zniszczone zamknięcie muzeum, Heniek „ale nie on”, uwaga o oczach portretów); nowe pole reguły `expires` i `VoiceDirector.is_free()`.
> **Powiązane:** lista zadań `docs/backlog-pietro1.md` (#32 kawiarnia jako hub, #34 eskalacja nocy, #35 zmieniony świat, #38 nawigacja bez strzałek, #41 audio storytelling, #51 odporny zapis, #52 opcje), fabuła `docs/fabula-pietro1.md`, specyfikacja całości `docs/Nocna-Zmiana-specyfikacja.md`.
> **Zmienia decyzję z 3.10** („osobowość strażnika tekstem, radio bez głosu aktora”): radio i komunikaty muzeum dostają głos syntezowany.

---

## 1. Decyzje

| Temat | Decyzja | Dlaczego |
|---|---|---|
| Język głosu | **Tylko angielski.** W polskiej wersji gry słychać angielski, a napisy są po polsku. | Kokoro-82M v1.0 nie ma polskiego (karta modelu: en-US, en-GB, ja, zh, es, fr, hi, it, pt-br). Właściciel wybrał to zamiast drugiego narzędzia dla PL. |
| Silnik mowy | **Kokoro-82M (ONNX fp16)**, generowanie offline. | Właściciel zna go z innego projektu; licencja Apache 2.0 jest zgodna z wydaniem gry na MIT (wpis w CREDITS). |
| Kto mówi | **Heniek przez krótkofalówkę** oraz **System** (głośniki muzeum i audioprzewodnik). | Oba głosy „przez urządzenie” — syntetyczność TTS pasuje albo jest maskowana filtrem. |
| Kto nie mówi | gracz (Młody), notatki, wrogowie | Poza zakresem (§9). |
| Styl Systemu | **Wystylizowany na chłodną, uprzejmie złośliwą maszynę** w rodzaju GLaDOS z Portala: korporacyjna grzeczność, pasywna agresja, czarny humor, „maszynowa” intonacja. Teksty własne, pod nasze muzeum. | Pomysł właściciela; kontrast z ciepłym Heńkiem. |
| Architektura | **Wariant A:** nagrania generowane z góry skryptem; charakter głosu Systemu wypalany offline, akustyka (radio, głośniki 3D, pogłos) w silniku. | Właściwość postaci powstaje w skrypcie, właściwość miejsca w grze; zmiana filtra radia nie wymaga ponownego generowania. |
| Publikacja | Gra zostaje dwujęzyczna (PL/EN). **Nic nie trafia na GitHub**, dopóki właściciel nie skończy testów i nie powie „wydajemy”. | Decyzja właściciela 8.10. |

---

## 2. Postacie

### 2.1 Heniek (radio)
- Dawny nocny stróż, mentor Młodego; siedzi w domu z nogą w gipsie (raptor) i odzywa się przez krótkofalówkę. Biblia fabuły już wskazała go jako głos podpowiedzi (§7, wątek 12 „Heniek wróci”).
- Mówi jak w swoich karteczkach: krótko, z humorem, wie więcej, niż mówi. **Im później w nocy i głębiej w muzeum, tym mniej żartuje** (zasada tonu z §1 biblii).
- Nie rozstrzyga „prawdy autorskiej” (biblia §2) — sugeruje, nie wyjaśnia.
- Po angielsku nazywa gracza tak, jak robią to angielskie teksty gry (spójnie z `locale/strings.csv`).

### 2.2 System — „Wirtualny Kustosz” (nazwa robocza; EN *Virtual Curator*)
- Automatyczny system obsługi zwiedzających, zainstalowany niedawno; ironia: prawdziwy kustosz jest na bezterminowym urlopie.
- Mówi z **głośników ściennych** w Wielkim Dziedzińcu i przy wejściach do skrzydeł oraz przez **audioprzewodnik** (§2.3).
- **Ton eskaluje z nocą** (#34):
  1. *zamknięcie* — korporacyjna uprzejmość („Muzeum jest zamknięte. Dziękujemy za wizytę.”);
  2. *noc* — pasywna agresja: raporty strat w kolekcji („wartość zniszczonych eksponatów zostanie potrącona z pensji pracownika ochrony”), komentarze do wyników i — na zmianę z Heńkiem — do śmierci gracza;
  3. *godzina duchów i później* — zacięcia, komunikaty kierowane do eksponatów („eksponaty proszone są o powrót na cokoły”), sugestie, że System wie więcej, niż powinien;
  4. *awaria prądu* — cisza (celowa, #41), potem **tryb awaryjny z baterii**: wyraźnie uszkodzony głos.
- Barwa: głos kobiecy Kokoro + obróbka offline (§5.3) w trzech stopniach „zepsucia” (0 — czysty, 1 — maszynowy, 2 — uszkodzony). Stopień jest przypisany do każdej kwestii w danych.

### 2.3 Audioprzewodnik (tryb Systemu)
- Ok. **12 stanowisk** przy najważniejszych eksponatach (np. Kamień z Rosetty, Kolos, lamassu, metopy, szachy z Lewis, astrolabium, moai, T-Rex). Lista w planie, zgodna z §8 biblii (prawdziwe eksponaty, prawdziwe fakty).
- Gracz sam włącza nagranie (interakcja E). Nic nie jest wymuszone.
- Każde stanowisko ma **dwie wersje**:
  - **A, dzienna** (stopień 0): 15–25 s rzeczowych faktów o eksponacie;
  - **B, nocna** (stopień 2): zacina się, mówi rzeczy, których nie powinien; czasem naprowadza na sekret (#27, #29).
- Wersja B włącza się, gdy **strażnik danego skrzydła jest pokonany** (świat się zmienił, #35); stanowiska w hubie — po godzinie duchów.
- Ponowne naciśnięcie zatrzymuje nagranie; odejście poza ok. 12 m też je kończy.

---

## 3. Kiedy kto mówi

Każda kwestia ma w danych: zdarzenie, warunki (noc ≥, faza nocy, strefa), priorytet i flagę **„raz na grę”** (domyślnie tak).

### 3.1 Heniek (ok. 50–70 kwestii)
| Zdarzenie (`Events`) | Kwestia | Uwagi |
|---|---|---|
| `night_started(night, …)` | inna na każdą noc; noc 1 = krótkie wprowadzenie | priorytet wysoki |
| `power_cut`, `witching_hour`, `dawn_broke` | reakcja na wydarzenie | wysoki |
| `room_entered(…, zone, first_visit)` — pierwsze wejście do strefy skrzydła | ostrzeżenie zgodne z notatkami skrzydła | 6 skrzydeł + podziemia + dach |
| `guardian_awakened`, `guardian_defeated` | po jednej na strażnika | 6 + 6 |
| `shard_collected(…, count)` | przy 1., 3. i 6. odłamku | |
| `boss_awakened`, `boss_defeated` (T-Rex) | finał | |
| `player_died` | **czasem** komentarz po powrocie (najwyżej raz na noc, na zmianę z Systemem) | niski |
| zastój | podpowiedź do bieżącego celu (`goal_changed(goal_key)` → jedna podpowiedź na cel) | po ok. 6 min bez postępu, najwyżej raz na 10 min; zastępuje strzałkę na HUD (#38), nie prowadzi za rękę |
| kawiarnia (ekspres) | komentarz | razem z #10/#32 |

„Postęp” dla licznika zastoju: nowa sala, odłamek, pieczęć, otwarta brama albo zmiana celu.

### 3.2 System (ok. 30–40 komunikatów)
- Faza nocy: start nocy, kilka minut po starcie, `witching_hour`, `power_cut` (cisza 30–60 s, potem tryb awaryjny), `dawn_broke`.
- Raporty strat: progi liczby zniszczonych eksponatów (`enemy_destroyed`), np. 10 / 50 / 100 / 200.
- Wybrane `gate_opened` i `seal_collected` („drzwi otwarte bez autoryzacji”).
- Śmierć gracza — na zmianę z Heńkiem (§3.1).

### 3.3 Zasady wspólne
- **Naraz mówi jeden głos.** Kolejność ważności: audioprzewodnik (gracz go włączył) > kwestie wydarzeń > pozostałe.
- **Walka:** kwestie czekają, aż przez ok. 4 s nikt nie poluje na gracza i nic go nie trafia; kwestia samego wydarzenia (np. przebudzenie strażnika) może poczekać najwyżej ok. 10 s.
- **Przeterminowanie:** kwestia o niskim priorytecie, która czeka dłużej niż ok. 60 s, przepada (nie jest oznaczana jako wysłuchana — może wrócić przy kolejnym zdarzeniu).
- **Limit gadatliwości:** między kwestiami pobocznymi (zastój, śmierć, kawiarnia, raporty) co najmniej ok. 3 min; między kwestiami wydarzeń co najmniej ok. 20 s.
- Liczby powyżej to wartości startowe do strojenia w teście.

---

## 4. W grze

### 4.1 Reżyser głosu — `VoiceDirector` (autoload)
- Słucha wyłącznie szyny `Events` (`src/core/events.gd`); kod skrzydeł, wrogów i strażników się nie zmienia. Jeśli brakuje sygnału (np. „gracz w walce”), dokłada się go do `Events` albo czyta istniejący stan percepcji — bez wiązania modułów bezpośrednio.
- Reguły z pliku danych (§5.1), kolejka z priorytetami, warunek spokoju, przeterminowanie, limity (§3.3).
- Odtwarza kwestię właściwym kanałem (§4.2) i wysyła tekst do napisów (§4.3).
- Pauza gry wstrzymuje głos.

### 4.2 Dźwięk
- Nowe kanały: **`Voice`** (→ Master; suwak „Głosy” w opcjach), pod nim **`VoiceRadio`** i **`VoiceSystem`**.
- **Radio Heńka** (2D, `VoiceRadio`): pasmo krótkofalówki (ok. 300–3400 Hz), lekki przester, kompresja; kliknięcie i szum na początku i końcu (syntezowane jak reszta efektów).
- **System** (3D, `VoiceSystem`): odtwarzany z **1–3 najbliższych głośników ściennych** z drobnym przesunięciem w czasie (echo między głośnikami w dużej hali); pogłos ze stref, które już są (`src/audio/reverb_zone.gd`).
- **Audioprzewodnik** (3D): ze stojaka.
- **Wyciszanie pod mową:** Music ok. −6 dB, Ambience ok. −4 dB, wejście ok. 0,25 s, powrót ok. 0,8 s; po kwestii poziomy wracają dokładnie do wartości sprzed niej.

### 4.3 Napisy
- Pasek u dołu ekranu: **nazwa mówiącego w kolorze** (Heniek — ciepły bursztyn, „radio”; System — zimny błękit) + tekst w języku gry, najwyżej 2 wiersze; dłuższa kwestia dzielona na części w czasie proporcjonalnie do liczby znaków.
- Opcja **„Napisy: wł./wył.”**, domyślnie **włączone** (polski gracz ich potrzebuje).
- Wygląd zgodny ze stylem HUD (a gdy powstanie nowy styl HUD z #42 — z nim).

### 4.4 Zapis (#51)
- `GameState` (stan trwały między nocami) zapamiętuje: wysłuchane kwestie „raz na grę”, słyszane wersje stanowisk przewodnika, licznik raportów strat i stan naprzemienności komentarzy po śmierci.
- Po wczytaniu nic się nie powtarza i nic nie przepada.

### 4.5 Opcje
- „Głosy” (głośność, `volume_voice` w `settings_data.gd` → kanał `Voice`) i „Napisy” (wł./wył.).

### 4.6 Rekwizyty (Blender, zestaw jak reszta)
- **Głośnik ścienny** (Dziedziniec ok. 4–6, po jednym przy wejściu do każdego skrzydła) — znaczniki `pa_<strefa>_<n>` w danych stref.
- **Stojak audioprzewodnika** z numerem i dużym przyciskiem, czytelny jako interaktywny (#39) — znaczniki `guide_<id>`.

---

## 5. Proces generowania nagrań

### 5.1 Dane (jedno źródło tekstu)
- **Teksty:** `locale/strings.csv`, klucze `VO_HENIEK_*`, `VO_SYSTEM_*`, `VO_GUIDE_*` (kolumny `pl`, `en`). EN idzie do syntezy, PL/EN na napisy. Obowiązują zasady tekstów gry (bez prostego cudzysłowu i `%`, komplet PL/EN).
- **`data/voice/lines.json`:** klucz → mówiący, stopień obróbki (System), opcjonalnie tempo; reguły odzywania się (§3).
- **`data/voice/speakers.json`:** mówiący → głos Kokoro, tempo, ustawienia obróbki.
- **`data/voice/lexicon.json`:** wymowa polskich nazw w IPA (Heniek, Zawilski, Wróblewski, Kopeć, Mazur, lamassu…); skrypt podmienia te słowa na fonemy przed syntezą (zapis `[słowo](/IPA/)` działa tylko w wersji PyTorch Kokoro, nie w ONNX).

### 5.2 Narzędzia (na D:, poza gitem)
- `tools/tts/` z modelem **`model_fp16.onnx`** (163 MB) i głosami `*.bin` — model i `af_heart` kopiowane z wcześniejszej sesji (`neuron-spike`), pozostałe głosy-kandydaci (ok. 8–10 × 0,5 MB) z oficjalnego repo onnx-community/Kokoro-82M-v1.0-ONNX. Wpis w `.gitignore`.
- Środowisko Pythona 3.11 na D: z tymi samymi pakietami co w `neuron-spike` (kokoro-onnx 0.6.1, onnxruntime, espeakng_loader, soundfile, numpy) — odtworzone bez ponownego pobierania; dochodzi **pyworld** (MIT) — dla Pythona 3.11 na Windows nie ma gotowej paczki, więc kompilacja lokalna (są VS Build Tools 2022); awaryjnie własne spłaszczanie intonacji w numpy (TD-PSOLA).
- Znana pułapka: espeak-ng ma bufor ścieżki ok. 230 znaków — dane wymowy kopiuje się do krótkiej ścieżki (rozwiązanie z `neuron-spike/tts_kokoro.py`).

### 5.3 Skrypt `tools/tts/generate_voice.py`
1. Czyta dane (§5.1), wylicza skrót każdej kwestii: SHA-256 z „głos | tempo | stopień | wersja obróbki | tekst EN”.
2. Generuje **tylko kwestie, których skrót się zmienił**.
3. Kokoro → suche nagranie 24 kHz mono.
4. **System:** pyworld rozkłada głos na wysokość i barwę; wysokość jest spłaszczana i kwantowana (stopień 1: maszynowa, schodkowa intonacja; stopień 2: dodatkowo zacięcia, skoki wysokości, drobne ubytki); składanie z powrotem.
5. Wyrównanie głośności (wspólny poziom RMS, szczyt ≤ −1 dBFS), zapis **Ogg Vorbis** do `assets/voice/<mówiący>/<klucz>.ogg`.
6. `assets/voice/manifest.json`: klucz → skrót, długość nagrania.
7. Ostrzeżenie dla kwestii krótszych niż ok. 25 znaków EN (Kokoro słabo radzi sobie z bardzo krótkimi wypowiedziami — takie kwestie przepisać albo połączyć).
- Nagrania `.ogg` i manifest są w repo; skrypt pozwala każdemu je odtworzyć.
- Rozmiar: ok. 110–135 kwestii → kilka do kilkunastu MB.

### 5.4 Odsłuch głosów
- `tools/tts/voice_samples.py`: te same 2–3 zdania Heńka i Systemu w każdym głosie-kandydacie (System od razu z obróbką stopni 0–2) → pliki do odsłuchania przez właściciela. **Claude niczego nie odtwarza** (cisza w czasie pracy właściciela).
- Właściciel wybiera po jednym głosie dla Heńka i Systemu; wynik trafia do `speakers.json`.

---

## 6. Testy (bez okien i bez dźwięku)

- **Dane:** każdy klucz `VO_*` ma PL i EN, plik `.ogg` i wpis w manifeście, a skrót w manifeście zgadza się z bieżącym tekstem i ustawieniami (ten sam SHA-256 liczony w GDScript) — zmiana tekstu bez ponownego wygenerowania = czerwony test.
- **Reguły:** każda wskazuje istniejący sygnał `Events` i istniejący klucz; każde stanowisko przewodnika ma wersje A i B.
- **Reżyser** (zegar i odtwarzacz podstawione w teście): priorytety, jeden głos naraz, czekanie w walce i limit czekania, przeterminowanie, limity gadatliwości, „raz na grę”, naprzemienność po śmierci, pauza.
- **Zapis:** zapis → wczytanie → żadna kwestia „raz na grę” się nie powtarza; wersje przewodnika zachowane.
- **Napisy:** właściwy język, podział długiej kwestii, wyłączenie opcją.
- **Wyciszanie:** po kwestii Music i Ambience wracają dokładnie do poprzednich poziomów, także gdy kwestie idą jedna po drugiej.
- Przejście w oknie (zrzuty napisów, rozmieszczenie głośników i stojaków) tylko w sesji okienkowej za zgodą właściciela, z wyłączonym dźwiękiem.

---

## 7. Miejsce w kolejce prac

Głos **nie wyprzedza** zaplanowanych prac nad Piętrem I i nie czeka na sam koniec.

1. **Najpierw, zgodnie z planem:** scalenie odłożonych gałęzi (`fable-test-merge` = `dress-basement` + `dress-gr-enl`; strojenie gęstości z `close-wings`, bez reszty tej gałęzi), dokończenie strażników **Lamassu, Węża i Generała**, **wrogów wschodu** oraz ubrania **Asyrii, Azji, Ameryk i dachu** — bez zaślepek.
2. **Równolegle, jeden osobny agent — etap G1, szkielet głosu:** narzędzia (§5.2–5.4), `VoiceDirector`, kanały, napisy, zapis, opcje, rekwizyty, kilka kwestii testowych; **próbki głosów do wyboru dla właściciela**. Pliki rozłączne z pracą nad skrzydłami.
3. **Po ukończeniu skrzydeł — etap G2, treść:** wszystkie kwestie Heńka, Systemu i przewodnika pisane pod gotowe skrzydła i strażników, razem z kawiarnią (#10, #32).
4. **Dalej lista właściciela** (`docs/backlog-pietro1.md`, #1–#62: m.in. ręce i przeładowanie sztucera, za ciemne sekcje, nagrody za sekrety, zachowanie wrogów, muzyka biomów, czytelna amunicja, kawiarnia i zmęczenie, styl wizualny, gun feel, audio pass) → test właściciela → poprawki.

---

## 8. Ryzyka

| Ryzyko | Co robimy |
|---|---|
| Głos Kokoro brzmi zbyt „płasko” dla Heńka | Filtr radia maskuje artefakty; wybór na ucho z kilku głosów; tempo per kwestia. |
| Obróbka Systemu brzmi tanio | Trzy stopnie do odsłuchu przed generowaniem całości; parametry w `speakers.json`. |
| Gadatliwość męczy | Limity z §3.3 strojone w teście; „raz na grę”. |
| Polskie nazwy wymawiane źle | Słowniczek IPA (§5.1), test odsłuchowy właściciela. |
| Rozjazd tekstu i nagrania | Skrót w manifeście + test (§6). |

---

## 9. Poza zakresem

- Polski głos (Kokoro go nie ma; właściciel wybrał EN + napisy).
- Głos gracza (Młodego), notatki czytane na głos, głosy wrogów.
- Synteza mowy w trakcie gry.
- Publikacja na GitHubie i pakiet wydawniczy (LICENSE, CREDITS, README, przegląd historii gita) — dopiero na wyraźne „wydajemy” od właściciela.

## 10. Do ustalenia później

- Wybór głosów (po próbkach, etap G1).
- Ostateczna nazwa Systemu (robocza: „Wirtualny Kustosz” / *Virtual Curator*).
- Dokładna lista stanowisk audioprzewodnika i treść kwestii (etap G2).
