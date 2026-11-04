extends "res://tests/guide_check.gd"
# 127 号: the power pages say it in plain words; the figures folded. Shots of the power district's
# console (details open) and the power control screen. Own test saves only.
#   tools/run_test.sh tests/jargon127_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_jargon127_career.json"
	SaveGame.path = "user://zp_test_jargon127_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _texts(n: Node) -> String:
	var out := PackedStringArray()
	for l in n.find_children("*", "", true, false):
		if (l is Label or l is Button) and l.is_visible_in_tree():
			out.append(str(l.text))
	return "\n".join(out)


class Fake extends Node:
	var group := "salvage"
	var mw := 3.0
	func grid_loads() -> Array:
		return [{"id": "fake_" + group, "name": "FAKE", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}]


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(10)
	g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot("power")
	await _frames(60)
	g.open_district("power")
	await _frames(30)
	var tx := _texts(g.console_ui)
	for bad in ["岸电", "自发", "补贴线路", "MWh", "母线"]:
		check(not tx.contains(bad), "console: no '%s'" % bad)
	var rows := str(g.console_ui.readout.rows)
	check(rows.contains("电够用") or rows.contains("电不够") or rows.contains("电刚好"), "console: the verdict on top")
	check(not rows.contains("岸电") and not rows.contains("自发"), "console: no jargon on the readout")
	Cap.save(root, "res://tests/out/jargon127_console.png")
	g.console_ui.detail_key.pressed.emit()
	await _frames(10)
	check(g.console_ui.detail_box.visible, "console: details open")
	Cap.save(root, "res://tests/out/jargon127_console_details.png")
	g.console_ui.close()
	await _frames(10)
	g.open_power_screen()
	await _frames(40)
	var ui = g.console_ui
	tx = _texts(ui)
	check(tx.contains("电够用") or tx.contains("电不够") or tx.contains("电刚好"), "screen: the verdict")
	for bad in ["岸电", "自发", "补贴线路", "MWh", "母线", "合闸", "基础负荷"]:
		check(not tx.contains(bad), "screen: no '%s'" % bad)
	Cap.save(root, "res://tests/out/jargon127_power_screen.png")
	# short of power: the band turns, the ways out appear on it
	for gp in [["salvage", 3.0], ["process", 5.0]]:
		var f := Fake.new()
		f.group = gp[0]
		f.mw = gp[1]
		g.add_child(f)
		Grid.add_load_source(f)
	await _frames(30)
	check(not ui.banner.ok, "short: the band says so (%s)" % ui.banner.head)
	check(ui.fixes.get_child_count() >= 1, "short: a way out on the band (%d)" % ui.fixes.get_child_count())
	Cap.save(root, "res://tests/out/jargon127_power_short.png")
	ui.details_key.pressed.emit()
	await _frames(20)
	check(ui.details.visible, "details open")
	Cap.save(root, "res://tests/out/jargon127_power_details.png")
	# the band's "mend the power district" takes you to that console
	var mend: Button = null
	for b in ui.fixes.get_children():
		if str(b.text).begins_with("去修动力区"):
			mend = b
	check(mend != null, "short at stage 0: mend the power district on the band")
	if mend != null:
		mend.pressed.emit()
		await _frames(20)
		check(g.console_ui != null and str(g.console_ui.get_script().resource_path).ends_with("district_panel.gd"), "it opens the power district's console")
	print("JARGON127 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
