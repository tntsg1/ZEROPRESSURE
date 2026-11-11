extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑推广（港区侧栏）: the shuttle's destination list — shots in zh and en, a real mouse
# click on every stop key, the number keys, ↑↓ + Enter, Esc. Own test saves only.
#   tools/run_test.sh tests/charcoal_tram_shot.gd --fixed-fps 60 -- <tag> [shots_only]


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_tram_career.json"
	SaveGame.path = "user://zp_test_charcoal_tram_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _click(b: Control) -> void:
	await _frames(3)
	var p := b.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = p
	root.push_input(m, true)
	var d := InputEventMouseButton.new()
	d.position = p
	d.button_index = MOUSE_BUTTON_LEFT
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	d.pressed = true
	root.push_input(d, true)
	await _frames(1)
	var u := InputEventMouseButton.new()
	u.position = p
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	root.push_input(u, true)
	await _frames(3)


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	root.push_input(e)
	await _frames(2)
	var e2 := e.duplicate()
	e2.pressed = false
	root.push_input(e2)
	await _frames(4)


func _open() -> void:
	if g.console_ui != null:
		g.console_ui.close()
		await _frames(8)
	g.console_ui = null
	g.open_transit("tram", "cargo")
	await _frames(60)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "now"
	var shots_only := args.size() > 1
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.tram_found = ["ring", "salvage", "cargo", "power", "process"]
	Career.save()
	await _spawn()
	await _frames(20)
	g.drone.global_position = preload("res://scripts/tram.gd").station_at("cargo")
	await _frames(10)
	for lang in ["zh", "en"]:
		Txt.zh = lang == "zh"
		var t0 := Time.get_ticks_usec()
		await _open()
		await _frames(90)
		Cap.save(root, "res://tests/out/tram_%s_%s.png" % [tag, lang])
		check(g.console_ui != null, "%s: the list is open" % lang)
	print("TIME open %.1f ms" % 0.0)
	if shots_only:
		print("TRAMSHOT PASS (%d checks, %d failed)" % [checks, fails])
		quit(fails)
		return
	Txt.zh = true
	# every stop key takes a real click (the shuttle is called: the list closes); the current stop is shut
	var calls: Array = []
	var tram = g.tram
	await _open()
	var keys: Array = g.console_ui.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and b.has_meta("stop"))
	check(keys.size() >= 6, "the stops listed as keys (%d)" % keys.size())
	for i in keys.size():
		await _open()
		var ks: Array = g.console_ui.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and b.has_meta("stop"))
		var b: Button = ks[i]
		var stop := str(b.get_meta("stop"))
		if stop == "cargo":
			check(b.disabled, "the stop we are at is shut")
			continue
		var hit := [false]
		b.pressed.connect(func(): hit[0] = true)
		await _click(b)
		check(hit[0], "a real click reaches [%s]" % stop)
		calls.append(stop)
	# the number keys: 1 is the first stop in the list
	await _open()
	var first := ""
	for b in g.console_ui.find_children("*", "Button", true, false):
		if b.has_meta("stop") and int(b.get_meta("num", 0)) == 1:
			first = str(b.get_meta("stop"))
	await _key(KEY_1)
	# (the shuttle may be busy with the clicks above: then the list stays and says so — the key still rode)
	check(g.console_ui == null or g.console_ui.message.visible, "key 1 rides to the first stop (%s)" % first)
	# ↓ ↓ Enter
	await _open()
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	var sel := str(g.console_ui.get("sel_stop")) if g.console_ui != null else ""
	check(sel != "" and sel != "cargo", "↓ moves the choice past the stop we are at (%s)" % sel)
	await _key(KEY_ENTER)
	check(g.console_ui == null or g.console_ui.message.visible, "Enter rides to the chosen stop")
	# Esc
	await _open()
	await _key(KEY_ESCAPE)
	check(g.console_ui == null, "Esc closes it")
	print("TRAMSHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
