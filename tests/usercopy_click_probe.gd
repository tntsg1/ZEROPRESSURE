extends SceneTree
# 2026-11-10 (user: "电网调度和仓库……一点都打不开"): the terminal's foot keys tried on a COPY of the
# user's own career (user://zp_test_usercopy_career.json, copied by hand; the real one is never
# opened here) with the developer mode on: the three values the keys hang on, then mouse clicks
# and F3/F5 on the home screen.
#   tools/run_test.sh tests/usercopy_click_probe.gd --fixed-fps 60
var g
const Cap = preload("res://tests/cap.gd")


# CanvasLayers at 61+ holding a page (a leaving page's picture that never went away)
func _ghosts() -> Array:
	var out: Array = []
	for n in root.get_children():
		if n is CanvasLayer and n.layer > 60 and n.layer < 80 and n.get_child_count() > 0:
			out.append("%d:%s" % [n.layer, n.get_child(0).get_script().resource_path.get_file() if n.get_child(0).get_script() != null else n.get_child(0).name])
	return out


func _initialize() -> void:
	Career.path = "user://zp_test_usercopy_career.json"
	SaveGame.path = "user://zp_test_usercopy_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ui() -> String:
	var u = g.console_ui
	return "" if u == null or not is_instance_valid(u) else str(u.get_script().resource_path).get_file()


func _click_at(at: Vector2) -> void:
	at = root.get_final_transform() * at
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await _frames(2)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
		await _frames(2)


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		root.push_input(ev)
		await _frames(2)


func _home() -> void:
	if _ui() != "terminal.gd":
		if g.console_ui != null and is_instance_valid(g.console_ui) and g.console_ui.has_method("close"):
			g.console_ui.close()
			await _frames(20)
		g.open_console("terminal")
	await _frames(40)
	g.console_ui.set_tab(-1)
	await _frames(40)


func _run() -> void:
	Txt.zh = true
	Career.data = {}
	Career.load_or_new()
	print("career loaded: %d keys, money %s, rep %s" % [Career.data.size(), Career.data.get("money", "?"), Career.data.get("rep", "?")])
	print("usable=%s counter_seen=%s walked_power=%s ok_store=%s ok_grid=%s" % [Career.usable(), StoreBook.counter_seen(), RemoteOps._walked("power"), RemoteOps.ok("store"), RemoteOps.ok("grid")])
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(60)
	Txt.dev = true
	Txt.zh = true
	if "bench" in OS.get_cmdline_user_args():
		DevPanel.workbench_open = true
		print("workbench open")
	print("after load: usable=%s ok_store=%s ok_grid=%s state=%s menu_open=%s" % [Career.usable(), RemoteOps.ok("store"), RemoteOps.ok("grid"), g.state, g.menu_open])
	await _home()
	var term = g.console_ui
	print("terminal: ", _ui(), " remote_box visible=", term.remote_box.visible)
	for b in term.remote_box.get_children():
		var c: Vector2 = b.get_global_rect().get_center()
		var mv := InputEventMouseMotion.new()
		mv.position = root.get_final_transform() * c
		mv.global_position = mv.position
		root.push_input(mv)
		await _frames(2)
		var h := root.gui_get_hovered_control()
		print("  %s disabled=%s locked=%s under=%s" % [b.name, b.disabled, b.get_meta("locked", false), h.get_path() if h != null else "-"])
	var step := 0
	for kind in ["grid", "store", "grid", "store"]:
		await _home()
		term = g.console_ui
		var b: Button = term.remote_box.get_node_or_null("Remote_" + kind)
		await _click_at(b.get_global_rect().get_center())
		await _frames(30)
		step += 1
		print("CLICK %s -> %s  (msg: %s) layers above 60: %s" % [kind, _ui(), term.msg if is_instance_valid(term) else "", _ghosts()])
		Cap.save(root, "res://tests/out/usercopy_step%d_%s.png" % [step, kind])
		await _key(KEY_ESCAPE)
		await _frames(30)
		print("  after Esc -> %s  layers above 60: %s" % [_ui(), _ghosts()])
		Cap.save(root, "res://tests/out/usercopy_step%d_back.png" % step)
	for k in [[KEY_F3, "F3"], [KEY_F5, "F5"], [KEY_F8, "F8"]]:
		await _home()
		await _key(k[0])
		await _frames(30)
		print("KEY %s -> %s" % [k[1], _ui()])
		await _key(KEY_ESCAPE)
		await _frames(30)
	quit()
