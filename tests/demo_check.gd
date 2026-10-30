extends SceneTree
# The playtest build (scripts/demo.gd, demo_gate.gd, demo_end.gd) against the live server:
# its own saves and settings, the recorder on by default, the bench hidden, a code that activates
# this machine and is checked again on the next start, a refused code, the end card after the hour
# with its three answers kept beside the record, and the record zipped and uploaded.
# Needs a fresh code: godot --headless --path . -s tests/demo_check.gd -- ZP-XXXX-XXXX
# (the code ends up bound to this computer)

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


func _wait_gate(gate, n := 900) -> String:
	for i in n:
		await process_frame
		if not is_instance_valid(gate):
			return "passed"
		if gate.state in ["code", "refused", "expired", "done"]:
			return gate.state
	return "timeout"


func _run() -> void:
	var code := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ZP-"):
			code = a
	Gt.forced = true
	# a clean start for the build's own files
	for f in [Gt.CFG, "user://playtest_save.json", "user://playtest_career.json", "user://playtest_settings.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Gt.apply()
	check(SaveGame.path == "user://playtest_save.json" and Career.path == "user://playtest_career.json" and Txt.cfg_path == "user://playtest_settings.cfg", "its own saves and settings")
	Txt.load_settings(false)
	check(Txt.playtest, "the recorder is on by default")
	check(not Gt.dev_allowed(), "the bench is hidden (no --dev)")
	check(not Gt.expired(), "not past %s" % Gt.EXPIRES)
	check(Gt.machine().length() == 32, "a machine id: %s" % Gt.machine().substr(0, 8))
	# no code yet: the gate asks
	var g1 := _gate()
	check(await _wait_gate(g1) == "code", "first start: it asks for a code")
	g1.code_in.text = "ZP-AAAA-AAAA"
	g1._activate()
	check(await _wait_gate(g1) == "refused" and str(g1.msg).length() > 0, "a made-up code is refused: %s" % g1.msg)
	if code != "":
		g1.code_in.text = code.to_lower().replace("-", "").substr(2)
		g1._activate()
		check(await _wait_gate(g1) == "passed", "the real code (typed loosely) lets it through")
		check(Gt.code() == code, "the code is remembered")
		var g2 := _gate()
		check(await _wait_gate(g2) == "passed", "the next start checks it online and goes straight in")
	else:
		print("  (no code given: activation not tried)")
		g1.queue_free()
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
		if code != "":
			var http := HTTPRequest.new()
			http.process_mode = Node.PROCESS_MODE_ALWAYS
			root.add_child(http)
			http.request_raw("%s/report?code=%s&machine=%s" % [Gt.URL, code, Gt.machine()], ["Content-Type: application/zip"], HTTPClient.METHOD_POST, bytes)
			var r: Array = await http.request_completed
			check(int(r[1]) == 200, "the record uploads (HTTP %d)" % int(r[1]))
		var g3 := _gate()
		check(await _wait_gate(g3) == "done", "after the end the gate says it is over")
	paused = false
	print("DEMO CHECK %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
