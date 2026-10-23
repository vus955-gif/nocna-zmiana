class_name PlaythroughReport
extends RefCounted
## The playthrough run's report as a self-contained HTML page in Polish
## (for the owner): the outcome, night by night, time per zone, deaths
## and their causes, the steps of progress, the resources over time (inline
## SVG), where the bot got stuck and what it gave up on.

const ZONE_NAMES := {
	"booth": "Kanciapa", "entrance": "Hol wejściowy", "court": "Wielki Dziedziniec", "north_hall": "Hol północny",
	"egypt": "Egipt", "assyria": "Asyria", "greece": "Grecja", "enlightenment": "Oświecenie", "asia": "Azja",
	"americas": "Ameryki", "basement": "Podziemia", "roof": "Dach", "": "(przejścia)",
}
const END_NAMES := {"dawn": "świt", "death": "śmierć", "finished": "koniec piętra", "aborted": "przerwana", "": "?"}
const STEP_NAMES := {
	"pistol_key": "klucz do szafki", "pistol": "pistolet", "flare": "raca", "shotgun": "strzelba", "colossus": "Kolos",
	"rifle_hunt": "sztucer", "planetarium": "Planetarium", "lamassu": "Lamassu", "centaur": "Kentaur", "gatling": "kartaczownica",
	"fuse_basement": "bezpiecznik (podziemia)", "fuse_assyria": "bezpiecznik (Asyria)", "power_north": "prąd",
	"hwacha": "hwacha", "general": "Generał", "harpoon": "harpun", "serpent": "Wąż", "astrolabe": "astrolabium",
	"trex": "T-Rex", "descend": "zejście do krypty",
}


static func html(data: Dictionary) -> String:
	var out := PackedStringArray()
	var outcome: Dictionary = data.get("outcome", {})
	var nights: Array = data.get("nights", [])
	out.append("<!doctype html><html lang=\"pl\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
	out.append("<title>Przejście bota — ziarno %d</title>" % int(data.get("seed", 0)))
	out.append("<style>%s</style></head><body><main>" % _css())
	out.append("<header><p class=\"kicker\">Nocna Zmiana · Piętro I · przejście bez oszustw (#60)</p>")
	out.append("<h1>Przejście bota — ziarno %d</h1>" % int(data.get("seed", 0)))
	out.append("<p class=\"meta\">skala czasu ×%s · %s · czas gry %s · czas rzeczywisty %s</p></header>" % [
		str(data.get("time_scale", 1.0)), "piętro ubrane" if bool(data.get("dressed", true)) else "piętro szare (greybox)",
		PlaythroughLog.duration(float(data.get("game_seconds", 0.0))), PlaythroughLog.duration(float(data.get("real_seconds", 0.0)))])
	# the outcome
	var deaths: Array = data.get("deaths", [])
	out.append("<section><h2>Wynik</h2><div class=\"tiles\">")
	out.append(_tile("Ukończone", "tak" if bool(outcome.get("finished", false)) else "nie", "good" if bool(outcome.get("finished", false)) else "bad"))
	out.append(_tile("Noce", str(nights.size()), ""))
	out.append(_tile("Śmierci", str(deaths.size()), "bad" if deaths.size() > 0 else "good"))
	out.append(_tile("Kroki postępu", "%d / %d" % [int(outcome.get("steps_done", 0)), int(outcome.get("steps_total", 20))], ""))
	out.append(_tile("Utknięcia", str((data.get("stuck", []) as Array).size()), ""))
	out.append(_tile("Błędy silnika", str(int(outcome.get("engine_errors", 0))), "bad" if int(outcome.get("engine_errors", 0)) > 0 else "good"))
	out.append("</div>")
	var first: Array = outcome.get("first_errors", [])
	if not first.is_empty():
		out.append("<p class=\"note\">Pierwsze błędy: %s</p>" % _esc("; ".join(PackedStringArray(first))))
	if outcome.has("why"):
		out.append("<p class=\"note\">%s</p>" % _esc(String(outcome["why"])))
	out.append("</section>")
	# night by night
	out.append("<section><h2>Noc po nocy</h2><div class=\"scroll\"><table><thead><tr><th>Noc</th><th>Start</th><th>Koniec</th><th>Zegar</th><th>Postęp tej nocy</th><th>Zabite</th><th>Obrażenia</th><th>Pył</th><th>Zakupy</th><th>Utknięcia</th></tr></thead><tbody>")
	for n: Dictionary in nights:
		var steps: Array = n.get("steps", [])
		var names := PackedStringArray()
		for s in steps:
			names.append(_step_name(String(s)))
		out.append("<tr><td>%d</td><td>%s</td><td class=\"%s\">%s</td><td>%s</td><td>%s</td><td>%d</td><td>%d</td><td>%d → %d</td><td>%s</td><td>%d</td></tr>" % [
			int(n.get("night", 0)), _esc(String(n.get("start_haven", ""))), "bad" if n.get("end") == "death" else "",
			END_NAMES.get(String(n.get("end", "")), String(n.get("end", ""))), _clock(float(n.get("clock", 0.0))),
			_esc(", ".join(names)) if not names.is_empty() else "—", int(n.get("kills", 0)), int(round(float(n.get("damage_taken", 0.0)))),
			int(n.get("dust_start", 0)), int(n.get("dust_end", 0)), _esc(", ".join(PackedStringArray(n.get("bought", [])))) if not (n.get("bought", []) as Array).is_empty() else "—",
			int(n.get("stuck", 0))])
	out.append("</tbody></table></div></section>")
	# zones
	out.append("<section><h2>Czas w strefach</h2>")
	var zones := {}
	for n: Dictionary in nights:
		var z: Dictionary = n.get("zones", {})
		for k in z:
			zones[k] = float(zones.get(k, 0.0)) + float(z[k])
	out.append(_bars(zones))
	out.append("</section>")
	# fights by foe
	out.append("<section><h2>Walki według przeciwnika</h2>")
	out.append(_fights(nights))
	out.append("</section>")
	# pacing
	out.append("<section><h2>Rytm nocy</h2><p class=\"note\">Co 10 s gry: walka (czerwony), droga i zadania (szary), przystań i zakupy (zielony), bezczynność (żółty). Fale napięcia (#55) widać jako przerwy między czerwonymi pasami.</p>")
	out.append(_pacing(data.get("samples", []), nights))
	out.append("</section>")
	# deaths
	out.append("<section><h2>Śmierci</h2>")
	if deaths.is_empty():
		out.append("<p>Bez śmierci.</p>")
	else:
		out.append("<table><thead><tr><th>Noc</th><th>Zegar</th><th>Kto</th><th>Gdzie</th><th>Zadanie</th></tr></thead><tbody>")
		for d: Dictionary in deaths:
			out.append("<tr><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % [int(d.get("night", 0)), _clock(float(d.get("clock", 0.0))),
				_esc(String(d.get("by", "?"))), _esc("%s / %s" % [ZONE_NAMES.get(String(d.get("zone", "")), String(d.get("zone", ""))), String(d.get("room", ""))]), _esc(String(d.get("task", "")))])
		out.append("</tbody></table>")
	out.append("</section>")
	# progress
	out.append("<section><h2>Postęp</h2><table><thead><tr><th>Czas gry</th><th>Noc</th><th>Zegar</th><th>Co</th></tr></thead><tbody>")
	for e: Dictionary in data.get("progress", []):
		out.append("<tr><td>%s</td><td>%d</td><td>%s</td><td>%s</td></tr>" % [PlaythroughLog.duration(float(e.get("t", 0.0))), int(e.get("night", 0)), _clock(float(e.get("clock", 0.0))), _esc(String(e.get("what", "")))])
	out.append("</tbody></table></section>")
	# resources
	out.append("<section><h2>Zasoby w czasie</h2><p class=\"note\">Zdrowie (%% maks.), Pył niesiony i naboje (suma magazynek + zapas, %% ładunku startowego broni) co 10 s gry; pionowe kreski = koniec nocy.</p>")
	out.append(_chart(data.get("samples", []), nights))
	out.append("</section>")
	# stuck and failures
	out.append("<section><h2>Utknięcia i porzucone zadania</h2>")
	var stuck: Array = data.get("stuck", [])
	var failures: Array = data.get("failures", [])
	if stuck.is_empty() and failures.is_empty():
		out.append("<p>Brak.</p>")
	else:
		out.append("<div class=\"scroll\"><table><thead><tr><th>Noc</th><th>Zegar</th><th>Rodzaj</th><th>Szczegóły</th></tr></thead><tbody>")
		for e: Dictionary in stuck:
			out.append("<tr><td>%d</td><td>%s</td><td>utknięcie</td><td>%s</td></tr>" % [int(e.get("night", 0)), _clock(float(e.get("clock", 0.0))), _esc("%s przy %s (zadanie %s, próba %s)" % [str(e.get("at", "")), str(e.get("contacts", [])), str(e.get("task", "")), str(e.get("try", ""))])])
		for e: Dictionary in failures:
			out.append("<tr><td>%d</td><td>%s</td><td>%s</td><td>%s</td></tr>" % [int(e.get("night", 0)), _clock(float(e.get("clock", 0.0))), _esc(String(e.get("kind", ""))), _esc("%s — %s (%s)" % [str(e.get("task", "")), str(e.get("why", "")), str(e.get("area", ""))])])
		out.append("</tbody></table></div>")
	out.append("</section>")
	out.append("<footer>Raport wygenerowany przez <code>tools/run_playthrough.sh</code> (bez okna, bez dźwięku). Dziennik zdarzeń: <code>log.jsonl</code>, dane: <code>report.json</code>.</footer>")
	out.append("</main></body></html>")
	return "\n".join(out)


## Fights summed over the nights by foe: fights, seconds, shots, damage
## taken, kills.
static func _fights(nights: Array) -> String:
	var by := {}
	for n: Dictionary in nights:
		var f: Dictionary = n.get("fights_by", {})
		for kind: String in f:
			var e: Array = f[kind]
			var sum: Array = by.get(kind, [0, 0.0, 0, 0.0, 0])
			for i in 5:
				sum[i] = float(sum[i]) + float(e[i])
			by[kind] = sum
	if by.is_empty():
		return "<p>Brak danych.</p>"
	var kinds := by.keys()
	kinds.sort_custom(func(a: Variant, b: Variant) -> bool: return float(by[a][3]) > float(by[b][3]))
	var out := PackedStringArray(["<div class=\"scroll\"><table><thead><tr><th>Przeciwnik</th><th>Walki</th><th>Czas</th><th>Strzały</th><th>Obrażenia przyjęte</th><th>Pokonane</th></tr></thead><tbody>"])
	for kind in kinds:
		var e: Array = by[kind]
		out.append("<tr><td>%s</td><td>%d</td><td>%s</td><td>%d</td><td>%d</td><td>%d</td></tr>" % [_esc(String(kind)), int(e[0]), PlaythroughLog.duration(float(e[1])), int(e[2]), int(round(float(e[3]))), int(e[4])])
	out.append("</tbody></table></div>")
	return "".join(out)


## A strip per night of what the bot did every sample.
static func _pacing(samples: Array, nights: Array) -> String:
	var out := PackedStringArray()
	for n: Dictionary in nights:
		var night := int(n.get("night", 0))
		var cells := PackedStringArray()
		var count := 0
		for sample: Dictionary in samples:
			if int(sample.get("night", -1)) != night:
				continue
			var tone := "walk"
			var task := String(sample.get("task", ""))
			if String(sample.get("foe", "")) != "":
				tone = "fight"
			elif task.begins_with("rest") or task.begins_with("shop") or task.begins_with("dawn") or task.begins_with("flee") or task.begins_with("discover"):
				tone = "haven"
			elif task == "idle" or task == "":
				tone = "idle"
			cells.append("<i class=\"p %s\"></i>" % tone)
			count += 1
		out.append("<div class=\"strip\"><span>noc %d</span><div>%s</div></div>" % [night, "".join(cells)])
	return "".join(out) if not out.is_empty() else "<p>Brak próbek.</p>"


static func _step_name(step: String) -> String:
	return STEP_NAMES.get(step, step)


static func _clock(seconds: float) -> String:
	# the night's clock face: 23:00 + 3 min of play per hour
	var hours := int(seconds / NightClock.SECONDS_PER_HOUR)
	var minutes := int(fmod(seconds, NightClock.SECONDS_PER_HOUR) / NightClock.SECONDS_PER_HOUR * 60.0)
	return "%d:%02d" % [(NightClock.START_HOUR + hours) % 24, minutes]


static func _tile(label: String, value: String, tone: String) -> String:
	return "<div class=\"tile %s\"><span>%s</span><b>%s</b></div>" % [tone, _esc(label), _esc(value)]


static func _bars(values: Dictionary) -> String:
	var keys := values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(values[a]) > float(values[b]))
	var most := 1.0
	for k in keys:
		most = maxf(most, float(values[k]))
	var out := PackedStringArray(["<div class=\"bars\">"])
	for k in keys:
		var share := float(values[k]) / most * 100.0
		out.append("<div class=\"bar\"><span>%s</span><i style=\"width:%.1f%%\"></i><b>%s</b></div>" % [_esc(ZONE_NAMES.get(String(k), String(k))), share, PlaythroughLog.duration(float(values[k]))])
	out.append("</div>")
	return "".join(out)


## Health, Dust and rounds over the run's game time.
static func _chart(samples: Array, nights: Array) -> String:
	if samples.size() < 2:
		return "<p>Za mało próbek.</p>"
	var w := 900.0
	var h := 260.0
	var pad := 36.0
	var t_end := maxf(float((samples.back() as Dictionary).get("t", 1.0)), 1.0)
	var dust_max := 1.0
	for s: Dictionary in samples:
		dust_max = maxf(dust_max, float(s.get("dust", 0)))
	var series := {"health": PackedStringArray(), "dust": PackedStringArray(), "ammo": PackedStringArray()}
	for s: Dictionary in samples:
		var x := pad + float(s.get("t", 0.0)) / t_end * (w - pad * 2.0)
		var hp := float(s.get("health_share", 0.0))
		(series["health"] as PackedStringArray).append("%.1f,%.1f" % [x, h - pad - hp * (h - pad * 2.0)])
		(series["dust"] as PackedStringArray).append("%.1f,%.1f" % [x, h - pad - float(s.get("dust", 0)) / dust_max * (h - pad * 2.0)])
		(series["ammo"] as PackedStringArray).append("%.1f,%.1f" % [x, h - pad - clampf(float(s.get("ammo_share", 0.0)), 0.0, 1.5) / 1.5 * (h - pad * 2.0)])
	var out := PackedStringArray()
	out.append("<svg viewBox=\"0 0 %d %d\" class=\"chart\" role=\"img\" aria-label=\"Zasoby w czasie\">" % [int(w), int(h)])
	out.append("<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" class=\"frame\"/>" % [int(pad), int(pad), int(w - pad * 2.0), int(h - pad * 2.0)])
	var t := 0.0
	for n: Dictionary in nights:
		t += float(n.get("seconds", 0.0))
		var x := pad + t / t_end * (w - pad * 2.0)
		out.append("<line x1=\"%.1f\" y1=\"%d\" x2=\"%.1f\" y2=\"%d\" class=\"night\"/>" % [x, int(pad), x, int(h - pad)])
	out.append("<polyline class=\"hp\" points=\"%s\"/>" % " ".join(series["health"]))
	out.append("<polyline class=\"dust\" points=\"%s\"/>" % " ".join(series["dust"]))
	out.append("<polyline class=\"ammo\" points=\"%s\"/>" % " ".join(series["ammo"]))
	out.append("<text x=\"%d\" y=\"%d\" class=\"lbl\">0</text><text x=\"%d\" y=\"%d\" class=\"lbl\" text-anchor=\"end\">%s</text>" % [int(pad), int(h - 10.0), int(w - pad), int(h - 10.0), PlaythroughLog.duration(t_end)])
	out.append("</svg><p class=\"legend\"><i class=\"k hp\"></i>zdrowie <i class=\"k dust\"></i>Pył (maks. %d) <i class=\"k ammo\"></i>naboje (0–150 %%)</p>" % int(dust_max))
	return "".join(out)


static func _esc(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


static func _css() -> String:
	return """
:root{--bg:#f6f4ef;--card:#fffdf8;--ink:#1f1d1a;--muted:#6d675e;--line:#e2ddd2;--good:#2f7d4f;--bad:#b3402f;--hp:#c0392b;--dust:#b8892b;--ammo:#2c6e9b;--accent:#5a4632}
@media (prefers-color-scheme: dark){:root{--bg:#151412;--card:#1e1c19;--ink:#ece7de;--muted:#a39b8e;--line:#34302a;--good:#6cc08b;--bad:#e2786a;--hp:#e06656;--dust:#e0b350;--ammo:#6fb0dc;--accent:#d6c3a5}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 Georgia,'Iowan Old Style',serif}
main{max-width:1040px;margin:0 auto;padding:40px 20px 60px}
header{margin-bottom:28px}.kicker{font:600 12px/1.4 system-ui,sans-serif;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);margin:0}
h1{font-size:34px;line-height:1.15;margin:6px 0 8px}h2{font-size:22px;margin:0 0 14px;border-bottom:1px solid var(--line);padding-bottom:6px}
.meta,.note,.legend,footer{color:var(--muted);font:14px/1.5 system-ui,sans-serif}
section{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:20px 22px;margin:0 0 20px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}
.tile{border:1px solid var(--line);border-radius:8px;padding:12px 14px}.tile span{display:block;font:12px system-ui,sans-serif;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.tile b{font-size:26px}.tile.good b{color:var(--good)}.tile.bad b{color:var(--bad)}
.scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font:14px/1.45 system-ui,sans-serif}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:600}
td.bad{color:var(--bad);font-weight:600}
.bars{font:14px system-ui,sans-serif}.bar{display:grid;grid-template-columns:170px 1fr 110px;align-items:center;gap:10px;margin:5px 0}
.bar i{display:block;height:12px;background:var(--accent);border-radius:6px;opacity:.75}.bar b{font-weight:500;color:var(--muted)}
.chart{width:100%;height:auto}.frame{fill:none;stroke:var(--line)}.night{stroke:var(--muted);stroke-dasharray:3 4;opacity:.6}
polyline{fill:none;stroke-width:1.8}.hp{stroke:var(--hp)}.dust{stroke:var(--dust)}.ammo{stroke:var(--ammo)}.lbl{fill:var(--muted);font:11px system-ui,sans-serif}
.k{display:inline-block;width:14px;height:3px;margin:0 6px 3px 14px;vertical-align:middle}.k.hp{background:var(--hp)}.k.dust{background:var(--dust)}.k.ammo{background:var(--ammo)}
code{font-size:13px}footer{margin-top:28px}
.strip{display:grid;grid-template-columns:60px 1fr;gap:8px;align-items:center;margin:4px 0;font:13px system-ui,sans-serif;color:var(--muted)}
.strip div{display:flex;flex-wrap:wrap;gap:1px}.p{display:block;width:5px;height:14px;border-radius:1px}
.p.fight{background:var(--hp)}.p.walk{background:var(--line)}.p.haven{background:var(--good)}.p.idle{background:var(--dust)}
@media (max-width:600px){.bar{grid-template-columns:110px 1fr 80px}h1{font-size:27px}}
"""
