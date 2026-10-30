extends "res://tests/guide_check.gd"
# 108 号 Q16–Q19: the playtest recorder. Off by default; switched on, every note is written the
# moment it happens — a screenshot beside what the game was doing — into its own folder, and the
# report is rewritten each time. Stuck on a step (20 s, 40 s), over twice a step's time, three
# refusals in 10 s, help opened, an accident, F7 with a line typed; milestones without a picture.
# Own test saves and its own folder (user://zp_test_playtest) only.
#   tools/run_test.sh tests/playtest_check.gd --fixed-fps 60


class FakeGuide extends Node:
	var step := 3
	var step_t := 0.0
	var done := false
	var title := Label.new()
	var body := Label.new()

	func tool_allowed(_n: int) -> bool:
		return true

	func guards(_q) -> bool:
		return false

	func mouth_signs() -> bool:
		return false


func _initialize() -> void:
	Career.path = "user://zp_test_playtest_career.json"
	SaveGame.path = "user://zp_test_playtest_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _entries(kind: String) -> Array:
	return Playtest.I.entries.filter(func(e): return e.kind == kind)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 5000.0
	Career.save()
	# off by default: a game started without the switch has no recorder
	Playtest.force = false
	Txt.playtest = false
	await _spawn()
	await _frames(5)
	check(Playtest.I == null, "off by default: no recorder")
	g.queue_free()
	await _frames(5)
	Playtest.force = true
	Playtest.root = "user://zp_test_playtest"
	await _spawn()
	await _frames(10)
	var pt: Playtest = Playtest.I
	check(pt != null and DirAccess.dir_exists_absolute(pt.dir), "switched on: its own folder (%s)" % (pt.dir if pt != null else "-"))
	if pt == null:
		quit(1)
		return
	# a guide step held 20 s, 40 s and over twice its time
	var fake := FakeGuide.new()
	fake.title.text = "把绞盘切下来"
	g.add_child(fake)
	g.coach = fake
	var kev := InputEventKey.new()
	kev.keycode = KEY_D
	kev.pressed = true
	Input.parse_input_event(kev)
	await _frames(30)
	pt.step_since = pt.now() - 21.0
	await _frames(20)
	check(_entries("stuck").size() == 1, "stuck 20 s on a step: one note")
	var e: Dictionary = _entries("stuck")[0] if not _entries("stuck").is_empty() else {}
	check(str(e.get("state", {}).get("guide", "")).find("把绞盘切下来") >= 0, "the note says which step (%s)" % str(e.get("state", {}).get("guide", "")))
	check(str(e.get("shot", "")) != "" or DisplayServer.get_name() == "headless", "and has a screenshot")
	pt.step_since = pt.now() - 41.0
	await _frames(20)
	check(_entries("stuck").size() == 2, "40 s: the second")
	pt.step_since = pt.now() - 91.0
	await _frames(20)
	check(_entries("slow").size() == 1, "over twice its time: a note")
	# the step moves on: the clock starts again
	fake.step = 4
	await _frames(20)
	check(pt.now() - pt.step_since < 2.0, "a new step starts its own clock")
	# three refusals inside 10 s (the sound and the words of one refusal count once)
	for i in 3:
		g.say("tool_locked", Vector2.ZERO)
		g.sfx.play("deny")
		pt.denies[-1] = pt.now() - 0.5 * (2 - i)
	check(_entries("deny").size() == 1, "three refusals in 10 s: one note")
	var dw: Array = _entries("deny")[0].why if not _entries("deny").is_empty() else []
	check(dw.size() > 0 and str(dw[0]).find("这一步还用不到这件工具") >= 0, "it says what was refused (%s)" % str(dw))
	# help, an accident
	g.codex_hud.open_book()
	await _frames(5)
	if g.codex_hud.page != null:
		g.codex_hud.page.queue_free()
		g.codex_hud.page = null
		get_root().get_tree().paused = false
	check(_entries("help").size() == 1, "help opened: a note")
	g.incident("fire", "T-02")
	check(_entries("accident").size() == 1, "an accident: a note")
	g.incident("fire", "T-03")
	check(_entries("accident").size() == 1, "the same kind again within 30 s: not twice")
	# milestones: money in, without a picture
	Career.data.money = 6400.0
	await _frames(20)
	var ms := _entries("milestone")
	check(ms.size() >= 1 and str(ms[0].title).find("第一笔进账") >= 0 and str(ms[0].shot) == "", "first money: a milestone, no picture")
	# F7: the player's own note, typed
	var ev := InputEventKey.new()
	ev.keycode = KEY_F7
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(5)
	check(pt.note_box != null and get_root().get_tree().paused, "F7 opens a line to type in and holds the game")
	if pt.note_box != null:
		var nr: Rect2 = pt.note_box.get_global_rect()
		check(get_root().get_visible_rect().encloses(nr), "  the line is on screen (%s)" % str(nr))
	if pt.note_box != null:
		pt.note_box.text = "不知道去哪找第二艘船"
		pt.note_box.text_submitted.emit(pt.note_box.text)
	await _frames(5)
	check(_entries("own").size() == 1 and str(_entries("own")[0].why).find("第二艘船") >= 0, "Enter keeps the note with its line")
	# the report, written as it goes
	await _frames(30)
	var html := FileAccess.get_file_as_string(pt.dir + "/report.html")
	check(html.find("卡住") >= 0 and html.find("不知道去哪找第二艘船") >= 0 and html.find("最近的操作") >= 0, "the report holds the notes and their state")
	if DisplayServer.get_name() != "headless":
		check(FileAccess.file_exists(pt.dir + "/shot_001.jpg"), "the first screenshot is on disk")
	if DisplayServer.get_name() != "headless":
		check(pt.shot_us < 12000, "a screenshot holds the main thread %.1f ms (< 12)" % (pt.shot_us / 1000.0))
	print("REPORT ", ProjectSettings.globalize_path(pt.dir + "/report.html"))
	Playtest.force = false
	print("PLAYTEST %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
