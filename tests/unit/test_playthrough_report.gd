extends TestCase
## The playthrough run's report (PlaythroughLog, PlaythroughReport): the
## durations as hours and minutes, the night's clock face, a page with
## every section from a small run's data.


func test_durations_read_as_hours_and_minutes() -> void:
	assert_eq(PlaythroughLog.duration(3725.0), "1 h 02 min")
	assert_eq(PlaythroughLog.duration(581.0), "9 min 41 s")
	assert_eq(PlaythroughLog.duration(42.4), "42 s")


func test_the_clock_face_of_the_night() -> void:
	assert_eq(PlaythroughReport._clock(0.0), "23:00")
	assert_eq(PlaythroughReport._clock(NightClock.SECONDS_PER_HOUR * 1.5), "0:30")
	assert_eq(PlaythroughReport._clock(NightClock.seconds_to_dawn()), "6:00")


func test_the_page_has_every_section() -> void:
	var data := {
		"seed": 7, "time_scale": 4.0, "dressed": false, "game_seconds": 1500.0, "real_seconds": 400.0,
		"outcome": {"finished": false, "steps_done": 5, "steps_total": 20, "why": "a test"},
		"nights": [{"night": 1, "start_haven": "security", "end": "death", "clock": 600.0, "seconds": 600.0, "steps": ["pistol", "colossus"],
			"kills": 12, "damage_taken": 140.0, "dust_start": 0, "dust_end": 0, "bought": ["health"], "stuck": 2,
			"zones": {"egypt": 300.0, "court": 120.0}, "fights_by": {"Mummy": [3, 40.0, 20, 60.0, 3]}}],
		"deaths": [{"night": 1, "clock": 600.0, "by": "Mummy", "zone": "egypt", "room": "egypt_gallery", "task": "step:colossus"}],
		"stuck": [{"night": 1, "clock": 100.0, "at": [1, 0, 2], "contacts": ["plinth@x"], "task": "dust", "try": 1}],
		"failures": [{"night": 1, "clock": 200.0, "kind": "task_failed", "task": "gate:x", "why": "no path", "area": "egypt"}],
		"progress": [{"t": 10.0, "night": 1, "clock": 10.0, "what": "weapon pistol"}],
		"samples": [{"t": 0.0, "night": 1, "health_share": 1.0, "dust": 0, "ammo_share": 1.0, "task": "step:pistol", "foe": ""},
			{"t": 10.0, "night": 1, "health_share": 0.5, "dust": 20, "ammo_share": 0.6, "task": "step:pistol", "foe": "Mummy"}],
	}
	var page := PlaythroughReport.html(data)
	for part: String in ["<title>Przejście bota — ziarno 7</title>", "Wynik", "Noc po nocy", "Czas w strefach", "Walki według przeciwnika",
			"Rytm nocy", "Śmierci", "Postęp", "Zasoby w czasie", "Utknięcia i porzucone zadania", "Mummy", "<svg", "</html>"]:
		assert_true(page.contains(part), "the page has %s" % part)
	assert_false(page.contains("<script"), "no scripts: a page to read")
