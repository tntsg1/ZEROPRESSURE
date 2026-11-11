extends "res://tests/guide_check.gd"
# 炭黑 rollout: the company stores (F3) with a few machines and steel in it, one picked; Chinese or
# English; the frames while it opens; then real clicks on its filters and its close key. Own saves.
#   tools/run_test.sh tests/charcoal_store_shot.gd --fixed-fps 60 -- tag=before [en]
var tag := "after"
var lang_en := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		elif a == "en":
			lang_en = true
	Career.path = "user://zp_test_cstore_career.json"
	SaveGame.path = "user://zp_test_cstore_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _part(uid: String, nk: String, v: float, tag2: String, mass: float) -> Dictionary:
	return {"uid": uid, "nk": nk, "cls": "power", "cond": 1.0, "value": v, "ship": "tug", "tag": tag2, "mass": mass, "job": "TUG-001"}


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.parts = [_part("s1", "p_battery", 2000.0, "BAT-T", 0.4), _part("s2", "p_nav", 4000.0, "NAV-T", 0.25),
		_part("s3", "p_battery", 2100.0, "BAT-T", 0.4), _part("s4", "p_pump", 3000.0, "PUMP-T", 0.5), _part("s5", "p_generator", 9000.0, "GEN-T", 1.2)]
	Career.data.structure_t = 6.0
	Career.data.money = 714573.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


func _snap(name: String) -> void:
	await _frames(3)
	Cap.save(root, "res://tests/out/store_%s_%s_%s.png" % [tag, name, "en" if lang_en else "zh"])


func _click(p: Vector2) -> void:
	var at := root.get_final_transform() * p
	for down in [null, true, false]:
		if down == null:
			var mv := InputEventMouseMotion.new()
			mv.position = at
			mv.global_position = at
			root.push_input(mv)
		else:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = at
			ev.global_position = at
			root.push_input(ev)
		await _frames(2)


func _run() -> void:
	_career()
	await _spawn()
	await _frames(20)
	Txt.zh = not lang_en
	g.open_store()
	var ft: Array = []
	var last := Time.get_ticks_usec()
	for i in 40:
		await process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
	ft.sort()
	print("STORE_FRAMES %s mean=%.2f p95=%.2f" % [tag, ft.reduce(func(x, y): return x + y, 0.0) / ft.size(), ft[int(ft.size() * 0.95)]])
	var sp = g.console_ui
	sp.select("p:s5")
	await _frames(40)
	await _snap("1_main")
	# real clicks: the filters, then the close key
	var bad := 0
	for f in sp.filters():
		await _click(Rect2(sp._btns["f:" + f]).get_center())
		await _frames(6)
		if str(sp.kind) != str(f):
			bad += 1
			print("[FAIL] clicking the %s filter (%s)" % [f, sp.kind])
	await _click(Rect2(sp._btns["f:equip"]).get_center())
	await _frames(20)
	await _snap("2_equip")
	await _click(Rect2(sp._btns["close"]).get_center())
	await _frames(30)
	if g.console_ui != null and is_instance_valid(sp) and g.console_ui == sp:
		bad += 1
		print("[FAIL] clicking the close key")
	print("STORE POINTER %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	quit()
