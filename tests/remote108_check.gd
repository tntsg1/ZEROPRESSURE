extends "res://tests/guide_check.gd"
# 108 号 Q8 C / Q12: three routine jobs from anywhere — the parts rack (F4), the grid's dispatch
# (F5), the processing queue (F6) — each once it has been done in person (the rack used at the
# rack, the power / processing district walked; a career that walked the old whole round has all).
# At a terminal: three buttons along its foot, locked ones greyed with the reason. The queue panel
# moves a batch up, down and to the front. Own test saves only.
#   tools/run_test.sh tests/remote108_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_remote108_career.json"
	SaveGame.path = "user://zp_test_remote108_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(6)


func _ui_path() -> String:
	var ui = g.console_ui
	if ui == null or not is_instance_valid(ui) or ui.get_script() == null:
		return ""
	return str(ui.get_script().resource_path).get_file()


func _close_ui() -> void:
	var ui = g.console_ui
	if ui == null:
		return
	if ui.get("on_close") != null and ui.on_close.is_valid():
		ui.on_close.call()
	elif ui.has_method("close"):
		ui.close()
	await _frames(6)


func _lots() -> Array:
	return ProcessQueue.entries().map(func(e): return str(e.lot))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.history = [{"id": "TUG-001", "ship": "tug"}]
	Career.data.walk_job = 99
	Career.data.money = 50000.0
	Career.save()
	await _spawn()
	await _frames(10)
	# ---- locked: nothing opens, it says why
	check(not RemoteOps.ok("rack") and not RemoteOps.ok("grid") and not RemoteOps.ok("queue"), "a new career: none of the three is open yet")
	await _key(KEY_F6)
	check(g.console_ui == null, "F6 before the processing district is walked: nothing opens")
	g.open_console("terminal")
	await _frames(30)
	var box = g.console_ui.remote_box
	check(box != null and box.visible and box.get_child_count() == 3, "the terminal's foot has the three remote jobs")
	var locked := 0
	for b in box.get_children():
		if b.disabled and str(b.tooltip_text) != "":
			locked += 1
	check(locked == 3, "each locked, greyed with its reason (%s)" % box.get_child(1).tooltip_text)
	Cap.save(root, "res://tests/out/remote108_locked_zh.png")
	await _close_ui()
	# ---- the rack used once in person opens it remotely
	g.open_parts_rack()
	await _frames(6)
	check(RemoteOps.ok("rack"), "the rack used at the rack: it opens from anywhere now")
	await _close_ui()
	# ---- the districts walked
	Career.data.seen["walk_power"] = true
	Career.data.seen["walk_process"] = true
	await _key(KEY_F4)
	check(_ui_path() == "parts_rack_panel.gd", "F4 in the berth: the parts rack (%s)" % _ui_path())
	await _close_ui()
	await _key(KEY_F5)
	check(_ui_path() == "power_panel.gd", "F5: the grid's dispatch on the power screen (%s)" % _ui_path())
	await _close_ui()
	# ---- the queue: three batches, the last to the front
	for i in 3:
		ProcessQueue.add("lot%d" % i, ["gr7", "tw64", "m14"][i], "J-%d" % i, 6.0 + i)
	await _key(KEY_F6)
	check(_ui_path() == "queue_panel.gd", "F6: the processing queue (%s)" % _ui_path())
	var qp = g.console_ui
	await _frames(6)
	check(qp.list.get_child_count() == 3, "three batches listed in order")
	qp._move(2, -99)
	await _frames(4)
	check(_lots() == ["lot2", "lot0", "lot1"], "the last to the front: %s" % str(_lots()))
	check(ProcessQueue.next_melt().lot == "lot2", "and the furnace takes it next")
	qp.sel = 0
	qp._move(0, 1)
	check(_lots() == ["lot0", "lot2", "lot1"], "down one: %s" % str(_lots()))
	Cap.save(root, "res://tests/out/remote108_queue_zh.png")
	await _close_ui()
	# ---- from the terminal: its button folds the terminal and opens the panel
	g.open_console("terminal")
	await _frames(30)
	var qb: Button = g.console_ui.remote_box.get_node("Remote_queue")
	check(not qb.disabled, "unlocked at the terminal too")
	Cap.save(root, "res://tests/out/remote108_terminal_zh.png")
	qb.pressed.emit()
	await _frames(10)
	check(_ui_path() == "queue_panel.gd", "the terminal's button opens the queue (%s)" % _ui_path())
	await _close_ui()
	# ---- an old career that walked the whole round
	Career.data.seen.erase("walk_power")
	Career.data.seen.erase("walk_process")
	Career.data.erase("walk_v")
	check(RemoteOps.ok("grid") and RemoteOps.ok("queue"), "an old career that walked the whole 21-step round has all")
	print("REMOTE108 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
