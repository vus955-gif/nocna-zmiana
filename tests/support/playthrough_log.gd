class_name PlaythroughLog
extends RefCounted
## What the playthrough bot's run saw (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md): events (the night's
## start and end, every step of progress, fights, gates, rests, purchases,
## deaths with their cause, getting stuck, tasks given up) and samples of
## the guard's resources every SAMPLE_EVERY s of game time (health, Dust,
## rounds of every gun, where he is), per night the time spent in each
## zone. Written as it goes to <dir>/log.jsonl (one JSON object a line, so
## a crashed run still tells what happened); at the end report.json and
## report.html (Polish, for the owner).

const SAMPLE_EVERY := 10.0

var dir: String = ""
var seed_value: int = 0
var time_scale: float = 1.0
var dressed: bool = true
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var nights: Array[Dictionary] = []
## Game seconds over all nights so far.
var total: float = 0.0
## Wall-clock milliseconds when the run began.
var started_msec: int = 0
var _file: FileAccess = null


func open(out_dir: String, run_seed: int, scale: float, dressed_floor: bool) -> void:
	dir = out_dir
	seed_value = run_seed
	time_scale = scale
	dressed = dressed_floor
	started_msec = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(dir)
	_file = FileAccess.open(dir.path_join("log.jsonl"), FileAccess.WRITE)


func close() -> void:
	if _file != null:
		_file.close()
		_file = null


## Records [param kind] at night [param night], [param clock] s into it.
func event(kind: StringName, data: Dictionary, night: int, clock: float) -> void:
	var entry := {"t": snappedf(total, 0.1), "night": night, "clock": snappedf(clock, 0.1), "kind": String(kind)}
	entry.merge(data)
	events.append(entry)
	_write(entry)


func sample(data: Dictionary) -> void:
	samples.append(data)
	var line := data.duplicate()
	line["kind"] = "sample"
	_write(line)


func night_done(summary: Dictionary) -> void:
	nights.append(summary)
	var line := summary.duplicate()
	line["kind"] = "night_summary"
	_write(line)


func _write(entry: Dictionary) -> void:
	if _file != null:
		_file.store_line(JSON.stringify(entry))
		_file.flush()


## The whole run as one dictionary (report.json).
func summary(outcome: Dictionary) -> Dictionary:
	var deaths: Array = []
	var stuck: Array = []
	var failures: Array = []
	var steps: Array = []
	for e in events:
		match e["kind"]:
			"death":
				deaths.append(e)
			"stuck":
				stuck.append(e)
			"task_failed", "idle", "softlock":
				failures.append(e)
			"progress":
				steps.append(e)
	return {
		"seed": seed_value, "time_scale": time_scale, "dressed": dressed,
		"outcome": outcome, "nights": nights, "game_seconds": snappedf(total, 0.1),
		"real_seconds": snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1),
		"deaths": deaths, "stuck": stuck, "failures": failures, "progress": steps,
		"samples": samples,
	}


func write_report(outcome: Dictionary) -> void:
	var data := summary(outcome)
	var json := FileAccess.open(dir.path_join("report.json"), FileAccess.WRITE)
	if json != null:
		json.store_string(JSON.stringify(data, "  "))
		json.close()
	var html := FileAccess.open(dir.path_join("report.html"), FileAccess.WRITE)
	if html != null:
		html.store_string(PlaythroughReport.html(data))
		html.close()


## "1 h 02 min", "9 min 41 s" (durations are never decimal hours).
static func duration(seconds: float) -> String:
	var s := int(round(seconds))
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%d min %02d s" % [s / 60, s % 60]
	return "%d s" % s
