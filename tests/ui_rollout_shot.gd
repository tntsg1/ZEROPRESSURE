extends "res://tests/guide_check.gd"
# 51 号: the new look across the pages, and the home screen showing only what exists. A fresh
# port's home (the berth alone, filling the row), the heat desk, a district's business console,
# the pause menu. Own test saves only.
#   tools/run_test.sh tests/ui_rollout_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_ui_rollout_career.json"
	SaveGame.path = "user://zp_test_ui_rollout_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = {}
	Career.start_new()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.money = 60000.0
	Career.data.port["salvage"] = 1
	Career.data.port["trade"] = 1
	Career.save()
	await _spawn()
	await _frames(10)
	# the fresh home: only the berth
	g.open_console("terminal")
	await _frames(8)
	var term: Node = g.console_ui
	term._skip_boot()
	await _frames(60)
	# 61 号: the home's cells gave way to one next-step card filling the row
	check(term._ops_cells.is_empty(), "a fresh port's home: no cells, the next-step card instead")
	var area: Rect2 = term._home_area()
	check(absf(term._next_rect().size.x - area.size.x) < 1.0, "and the card fills the row")
	Cap.save(root, "res://tests/out/ui_home_fresh_zh.png")
	term.close()
	await _frames(6)
	# built up: the heat desk and a business console in the new look
	Career.data.port["process"] = 1
	Career.data.port["power"] = 1
	Career.save()
	g.queue_free()
	await _frames(4)
	await _spawn()
	await _frames(20)
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	g.open_heat()
	await _frames(40)
	check(g.console_ui != null and g.console_ui.theme != null and g.console_ui.theme.has_stylebox("panel", "PanelContainer"), "the heat desk wears the new theme")
	Cap.save(root, "res://tests/out/ui_heat_desk_zh.png")
	g.console_ui.close()
	await _frames(6)
	g.open_district("power")
	await _frames(40)
	Cap.save(root, "res://tests/out/ui_district_zh.png")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(6)
	g.toggle_menu()
	await _frames(40)
	Cap.save(root, "res://tests/out/ui_pause_zh.png")
	g.toggle_menu()
	await _frames(60)
	# 54 号: the field HUD's panels are the new skin's rounded panel
	check(UiSkin.box("panel", 1.0).corner_radius_top_left == 14, "UI.panel draws the new skin's rounded panel")
	Cap.save(root, "res://tests/out/ui_hud_zh.png")
	# the settings page
	g.settings_panel.open()
	await _frames(40)
	Cap.save(root, "res://tests/out/ui_settings_zh.png")
	g.settings_panel.close()
	await _frames(20)
	# the star map
	Career.data.market = true
	g.open_star_map()
	await _frames(40)
	var ground := false
	if g.console_ui != null:
		for ch in g.console_ui.get_children():
			ground = ground or ch is UiSkin.Ground
	check(ground, "the star map sits on the new ground")
	Cap.save(root, "res://tests/out/ui_star_map_zh.png")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(6)
	g.queue_free()
	await _frames(4)
	print("UI ROLLOUT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
