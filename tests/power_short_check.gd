extends "res://tests/guide_check.gd"
# 106 号 (Q3 A): short of power, a machine says why at the machine and offers the way to the power
# control screen. Power district at stage 0 (6 MW, 2 MW of it the base): the 8 MW mill rolls at
# half speed; its lamp, its briefing and its panel say "供电 50%：动力区只发 6 MW"; the panel's
# button opens the power control screen; with the plant mended the reason is gone.
#   godot --headless --fixed-fps 60 -s tests/power_short_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_powershort_career.json"
	SaveGame.path = "user://zp_test_powershort_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 100000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 0, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.mill = {"product": "plate", "qty": 1.0, "state": "roll", "left": 40.0, "total": 40.0, "id": "MILL-T"}
	Career.save()
	# 2026-11-10: power hints only once the power district is open (128 第 7 段); this checks the hint itself
	Mainline.power_open_in_tests = true
	await _spawn()
	await _frames(10)
	var kk := Mill.k(g)
	check(kk > 0.3 and kk < 0.98, "the mill runs short of power (%.0f %%)" % (kk * 100.0))
	var lamp: Array = Mill.lamp(g)
	check(str(lamp[0]) == "short" and str(lamp[1]).find("动力区只发 6 MW") >= 0, "its lamp says why: %s" % str(lamp[1]))
	check(Grid.short_text(g, "mill").find("供电 %d%%" % int(kk * 100.0)) >= 0, "with the share it gets")
	g.drone.global_position = preload("res://scripts/mill_line.gd").pedestal()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(5)
	g.open_mill()
	await _frames(10)
	var p = g.console_ui
	check(p != null and p.power_b.visible and p.lamp_label.text.find("动力区只发") >= 0 and p.power_l.text.find("动力控制屏") >= 0, "the panel: the reason and what to do (%s / %s)" % ([p.lamp_label.text, p.power_l.text] if p != null else ["-", "-"]))
	p.power_b.pressed.emit()
	await _frames(10)
	check(g.console_ui != null and str(g.console_ui.get_script().resource_path).ends_with("power_panel.gd"), "its button opens the power control screen")
	g.console_ui.on_close.call()
	await _frames(5)
	Career.data.port.power = 1
	await _frames(10)
	check(Mill.k(g) >= 0.98 and Grid.short_text(g, "mill") == "" and str(Mill.lamp(g)[0]) == "run", "with the plant mended the mill runs full and says nothing of power")
	print("POWER SHORT CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
