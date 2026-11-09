extends SceneTree
# The public test build (scripts/demo.gd, demo_gate.gd, demo_end.gd; 公测版 2026-11-08) against the live
# server: its own saves and settings, the recorder on by default, the bench hidden, no end date, the
# machine registered on the first start and checked in on the next, offline still in within 3 days of
# the last check-in and held out after, the end card after the hour with its three answers kept beside
# the record, and the record zipped and uploaded by this machine.
#   godot --headless --path . -s tests/demo_check.gd
# (this computer is registered on the server: drop it after with node tools/codes.mjs drop-machine <id>)

const Gt = preload("res://scripts/demo.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _gate() -> Node:
	var gate = preload("res://scripts/demo_gate.gd").new()
	root.add_child(gate)
	return gate


func _wait_gate(gate, secs := 20.0) -> String:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		if not is_instance_valid(gate):
			return "passed"
		if gate.state in ["code", "refused", "expired", "done", "offline", "closed"]:
			return gate.state
	return "timeout"


func _run() -> void:
	Gt.forced = true
	# a clean start for the build's own files
	for f in [Gt.CFG, "user://playtest_save.json", "user://playtest_career.json", "user://playtest_settings.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Gt.apply()
	check(SaveGame.path == "user://playtest_save.json" and Career.path == "user://playtest_career.json" and Txt.cfg_path == "user://playtest_settings.cfg", "its own saves and settings")
	Txt.load_settings(false)
	check(Txt.playtest, "the recorder is on by default")
	check(not Gt.dev_allowed(), "the bench is hidden (no --dev)")
	check(not Gt.expired() and not Gt.CODES, "no end date, no codes")
	check(Gt.machine().length() == 32, "a machine id: %s" % Gt.machine())
	# the first start: it registers and goes straight in
	var g1 := _gate()
	check(not g1.code_in.visible, "no code field")
	check(await _wait_gate(g1) == "passed", "first start: registered online, straight in")
	check(Gt.within_grace(), "the check-in is remembered")
	var g2 := _gate()
	check(await _wait_gate(g2) == "passed", "the next start checks in and goes straight in")
	# offline: in within three days of the last check-in, out after
	Gt.base_url = "http://127.0.0.1:9"
	var g3 := _gate()
	check(await _wait_gate(g3) == "passed", "offline a day later: still in")
	var cf := ConfigFile.new()
	cf.load(Gt.CFG)
	cf.set_value("gate", "last_ok", int(Time.get_unix_time_from_system()) - Gt.GRACE_S - 60)
	cf.save(Gt.CFG)
	var g4 := _gate()
	check(await _wait_gate(g4) == "offline" and (g4.msg.contains("联网") or g4.msg.contains("internet")), "offline past three days: held out: %s" % g4.msg)
	g4.queue_free()
	Gt.base_url = Gt.URL
	check(not Gt.main_line_done() or Career.data.is_empty(), "a fresh career hasn't run the main line out")
	# the end of the first hour
	Txt.test_zh = true
	Txt.zh = true
	Gt.watch_in_tests = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.time = Gt.LIMIT_S + 5.0
	Game.contract = {}
	Game.start_ship = "tug"
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	var card = null
	for ch in g.get_children():
		if ch is CanvasLayer and ch.get_script() == preload("res://scripts/demo_end.gd"):
			card = ch
	check(card != null and paused, "an hour played: the end card, the game paused")
	if card != null:
		card.liked.text = "测试：切开第一刀"
		card.lost.text = "测试：不知道去哪"
		card.score.value = 8
		card._save_answers()
		var a = JSON.parse_string(FileAccess.get_file_as_string(Playtest.root.path_join("answers.json")))
		check(a is Dictionary and int(a.score) == 8 and str(a.liked).contains("第一刀"), "the three answers are kept beside the record")
		check(Gt.finished(), "this computer is marked done")
		var bytes := Gt.zip_records()
		check(bytes.size() > 100, "the record zips (%d bytes)" % bytes.size())
		var http := HTTPRequest.new()
		http.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(http)
		http.request_raw("%s/report?machine=%s" % [Gt.URL, Gt.machine()], ["Content-Type: application/zip"], HTTPClient.METHOD_POST, bytes)
		var r: Array = await http.request_completed
		check(int(r[1]) == 200, "the record uploads by this machine (HTTP %d)" % int(r[1]))
		var g5 := _gate()
		check(await _wait_gate(g5) == "done", "after the end the gate says it is over")
	paused = false
	print("DEMO CHECK %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
