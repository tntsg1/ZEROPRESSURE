extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑 v2: the on-site desks (heat, mill, the power screen), the pause menu and the settings
# page, one shot each, before/after. Own test saves only.
#   tools/run_test.sh tests/charcoal_desk_shot.gd --fixed-fps 60 -- tag=before lang=zh
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_desk_career.json"
	SaveGame.path = "user://zp_test_charcoal_desk_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(name: String) -> void:
	Cap.save(root, "res://tests/out/charcoal_desk_%s_%s_%s.png" % [tag, lang, name])


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.data = {}
	Career.start_new()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.money = 160000.0
	for k in ["salvage", "trade", "process", "power"]:
		Career.data.port[k] = 1
	Career.save()
	await _spawn()
	Txt.zh = lang == "zh"
	await _frames(20)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	g.open_heat()
	await _frames(110)
	check(g.console_ui != null, "the heat desk opens")
	_shot("heat")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(8)
	# a heat on: the arcs struck, the scrap going down into the melt
	if Career.data.get("exchange", {}).is_empty():
		Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	var f = g.plant.smelter
	f.begin_manual()
	f.manual_charge(1.0)
	Career.data.industrial_heat = {"id": "H-EAF", "state": "processing", "quantity": 1.0, "source_lots": [], "furnace": f.manual_snapshot(),
		"transport": {}, "electric_paid_j": float(f.electrical_j), "energy_cost": 0.0, "created": 0.0}
	await _frames(10)
	g.open_heat()
	await _frames(20)
	if g.console_ui != null:
		g.console_ui.main.pressed.emit()
	await _frames(20)
	print("heat_run: ui=", g.console_ui, " heat=", str(Career.data.industrial_heat.get("state", "")))
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(880)
	print("heat_run later: ui=", g.console_ui, " heat=", str(Career.data.industrial_heat.get("state", "")))
	if g.console_ui == null:
		g.open_heat()
		await _frames(60)
	_shot("heat_run")
	if g.console_ui != null:
		g.console_ui.close()
	Career.data.industrial_heat = {}
	await _frames(8)
	g.open_mill()
	await _frames(110)
	check(g.console_ui != null, "the mill desk opens")
	_shot("mill")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(8)
	# a pass running, rolling on: the billet on the rollers
	Mill.set_loop(true)
	Career.data.mill = {"product": "plate", "qty": Mill.BATCH, "state": "roll", "left": Mill.ROLL_S * Mill.BATCH * 0.45, "total": Mill.ROLL_S * Mill.BATCH, "id": "MILL-0"}
	g.open_mill()
	await _frames(110)
	_shot("mill_run")
	if g.console_ui != null:
		g.console_ui.close()
	Mill.set_loop(false)
	Career.data.mill = {}
	await _frames(8)
	g.open_power_screen()
	await _frames(110)
	_shot("power")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(8)
	g.toggle_menu()
	await _frames(40)
	_shot("pause")
	g.toggle_menu()
	await _frames(20)
	g.settings_panel.open()
	await _frames(40)
	_shot("settings")
	print("CHARCOAL DESK SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
