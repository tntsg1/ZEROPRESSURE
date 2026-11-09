extends SceneTree
# 公测版的反馈 (scripts/demo_feedback.gd, user 2026-11-08 Q4 A): "反馈" in the pause menu of the public
# build only; the page's big letters and its one orange key; the frame from before the menu as a JPG of
# 300 KB at most (a noisy full-HD frame too); 2000 characters at most; a send that fails is kept on this
# computer and goes up on the next start (flush), live against the server. Leaves nothing behind in the
# user folder (the feedback it sends is dropped with tools/codes.mjs drop-machine afterwards).
#   tools/run_test.sh tests/demo_feedback_check.gd --fixed-fps 60

const Gt = preload("res://scripts/demo.gd")
const Fb = preload("res://scripts/demo_feedback.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ids(g) -> Array:
	return g.hud._menu_items().map(func(e): return str(e[0]))


func _clean() -> void:
	for f in Fb.waiting():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Fb.OUTBOX))
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("playtest_") and f.get_extension() in ["json", "cfg", "zip"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))


func _run() -> void:
	Gt.forced = true
	_clean()
	Gt.apply()
	Txt.test_zh = true
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.time = 754.0
	Game.contract = {}
	Game.start_ship = "tug"
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(90)
	g.toggle_menu()
	await _frames(20)
	check(Fb.shot != null and Fb.shot.get_width() >= 640, "the frame before the menu is kept: %s" % (str(Fb.shot.get_size()) if Fb.shot != null else "none"))
	check("feedback" in _ids(g), "the pause menu has 反馈: %s" % str(_ids(g)))
	var shot_b := Fb.jpg(Fb.shot)
	check(shot_b.size() > 1000 and shot_b.size() <= Fb.MAX_SHOT, "the frame as a JPG: %d KB" % (shot_b.size() / 1024))
	var noise := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var px := PackedByteArray()
	px.resize(1920 * 1080 * 3)
	for i in px.size():
		px[i] = rng.randi() % 256
	noise.set_data(1920, 1080, false, Image.FORMAT_RGB8, px)
	var nb := Fb.jpg(noise)
	check(nb.size() > 0 and nb.size() <= Fb.MAX_SHOT, "a noisy full-HD frame still fits: %d KB" % (nb.size() / 1024))
	# the page
	var p = g.open_feedback()
	await _frames(10)
	check(p != null and g.has_meta("feedback_open"), "反馈 opens the page")
	check(p.text_in.get_theme_font_size("font_size") >= 20 and p.note_l.get_theme_font_size("font_size") >= 20, "big letters (%d)" % p.text_in.get_theme_font_size("font_size"))
	check(p.send_b.get_theme_stylebox("normal") is StyleBoxFlat and (p.send_b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(UiSkin.ACCENT), "one orange main key: %s" % p.send_b.text)
	check(p.kind_b.size() == 4 and p.kind == "other", "four kinds, 其他 picked")
	p.kind_b["bug"].pressed.emit()
	check(p.kind == "bug", "a kind picked")
	p.text_in.text = "长".repeat(2100)
	p.text_in.text_changed.emit()
	check(p.text_in.text.length() == Fb.MAX_TEXT, "2000 characters at most (%d)" % p.text_in.text.length())
	preload("res://tests/cap.gd").save(root, "res://tests/out/demo_feedback_page.png")
	# offline: kept on this computer
	p.text_in.text = "自动测试反馈：离线时存在本机，下次启动补发。"
	Fb.fail_in_tests = true
	var ent := InputEventKey.new()
	ent.keycode = KEY_ENTER
	ent.pressed = true
	Input.parse_input_event(ent)
	var n := 0
	while p.result == "" and n < 300:
		await process_frame
		n += 1
	check(p.result == "saved" and p.note_l.text.contains("本机"), "Enter sends; offline it says so: %s" % p.note_l.text)
	var kept := Fb.waiting()
	check(kept.size() == 1, "kept on this computer: %d" % kept.size())
	if kept.size() == 1:
		var d = JSON.parse_string(FileAccess.get_file_as_string(kept[0]))
		check(d is Dictionary and d.kind == "bug" and d.version == Gt.VERSION and int(d.played_s) == 754 and str(d.ship).begins_with("tug") and str(d.machine) == Gt.machine(), "with kind, version, time, ship, machine: %s / %s" % [d.get("ship", ""), d.get("chapter", "")])
		check(str(d.shot).length() > 1000 and Marshalls.base64_to_raw(d.shot).size() <= Fb.MAX_SHOT, "and the picture")
		check(d.has("log"), "and the log's tail (%d chars)" % str(d.get("log", "")).length())
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(5)
	check(not is_instance_valid(p) and not g.has_meta("feedback_open") and g.menu_open, "Esc goes back to the menu")
	g.toggle_menu()
	await _frames(5)
	# the next start: register, then what waits goes up
	Fb.fail_in_tests = false
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request(Gt.URL + "/hello", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"machine": Gt.machine(), "version": Gt.VERSION + "-test"}))
	var hr: Array = await http.request_completed
	check(int(hr[1]) == 200, "this machine registers (HTTP %d)" % int(hr[1]))
	Fb.last_flush = {}
	Fb.flush(self)
	n = 0
	while Fb.last_flush.is_empty() and n < 1800:
		await process_frame
		n += 1
	check(int(Fb.last_flush.get("sent", 0)) == 1 and int(Fb.last_flush.get("left", 1)) == 0, "the next start sends what waited: %s" % str(Fb.last_flush))
	# the full game has no 反馈
	Gt.forced = false
	check(not "feedback" in _ids(g), "the full game's menu has no 反馈: %s" % str(_ids(g)))
	g.queue_free()
	await _frames(5)
	_clean()
	Fb.shot = null
	print("DEMO FEEDBACK %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
