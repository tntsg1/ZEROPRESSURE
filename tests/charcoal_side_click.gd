extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑推广（港区侧栏）: every key on the districts' business consoles answers a real
# mouse click (pushed into the viewport — the OS pointer is never moved), and Esc closes the page.
# Own test saves only.
#   tools/run_test.sh tests/charcoal_side_click.gd --fixed-fps 60 -- [zones] [stage]


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_click_career.json"
	SaveGame.path = "user://zp_test_charcoal_click_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _click(b: Control) -> void:
	var anc = b.get_parent()
	while anc != null and not anc is ScrollContainer:
		anc = anc.get_parent()
	if anc is ScrollContainer:
		anc.ensure_control_visible(b)
	await _frames(4)
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


func _keys() -> Array:
	var out: Array = []
	if g.console_ui == null:
		return out
	for b in g.console_ui.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.has_meta("bfx_skip"):
			out.append(b)
	out.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	return out


func _open(z: String) -> void:
	if g.console_ui != null:
		if g.console_ui.has_method("close"):
			g.console_ui.close()
		else:
			g.console_ui.on_close.call()
		await _frames(10)
	if g.console_ui != null:
		g.console_ui = null
	preload("res://scripts/ui_back.gd").reset()
	g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot(z)
	await _frames(6)
	g.open_district(z)
	await _frames(70)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zones := (args[0] if args.size() > 0 else "cargo,power,process,tug,trade,ring").split(",")
	var st := int(args[1]) if args.size() > 1 else 1
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = float(args[2]) if args.size() > 2 else 2000.0
	var port := {}
	for z in ["power", "salvage", "process", "tug", "trade", "cargo", "ring"]:
		port[z] = st
	Career.data.port = port
	Career.save()
	await _spawn()
	await _frames(20)
	for z in zones:
		await _open(z)
		var n := _keys().size()
		print("KEYS ", z, " ", _keys().map(func(k): return k.text.left(16)), " all=", g.console_ui.find_children("*", "Button", true, false).map(func(k): return "%s|%s|%s" % [k.text.left(10), k.is_visible_in_tree(), k.has_meta("bfx_skip")]))
		check(n >= 1, "%s: has keys (%d)" % [z, n])
		for i in 16:
			await _open(z)
			var ks := _keys()
			if i >= ks.size():
				break
			var b: Button = ks[i]
			var name := b.text.replace("\n", " ").left(28)
			if b.disabled:
				check(true, "%s: [%s] shut (disabled)" % [z, name])
				continue
			var hit := [false]
			var cb := func(): hit[0] = true
			b.pressed.connect(cb)
			# a toggled key (a CheckButton) flips: it counts as pressed too
			var was := b.button_pressed
			await _click(b)
			var ok: bool = hit[0] or (is_instance_valid(b) and b.toggle_mode and b.button_pressed != was)
			check(ok, "%s: a real click on [%s] reaches it" % [z, name])
			if is_instance_valid(b) and b.pressed.is_connected(cb):
				b.pressed.disconnect(cb)
			# whatever it opened (an exchange, a confirmation), shut it before the next key
			for k in 3:
				if g.console_ui != null and g.console_ui.get_script() != null and not str(g.console_ui.get_script().resource_path).ends_with("district_panel.gd"):
					var e := InputEventKey.new()
					e.physical_keycode = KEY_ESCAPE
					e.keycode = KEY_ESCAPE
					e.pressed = true
					root.push_input(e)
					await _frames(12)
		# Esc closes the page
		await _open(z)
		var e2 := InputEventKey.new()
		e2.physical_keycode = KEY_ESCAPE
		e2.keycode = KEY_ESCAPE
		e2.pressed = true
		# (a fold the page remembers open shuts first, then the page: BenchFx #052)
		for k in 3:
			if g.console_ui == null:
				break
			root.push_input(e2)
			await _frames(20)
		check(g.console_ui == null, "%s: Esc closes it" % z)
	print("SIDECLICK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
