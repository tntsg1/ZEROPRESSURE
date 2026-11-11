extends "res://tests/guide_check.gd"
# 2026-11-11 炭黑 v2: the cargo district's racks (shelf_panel.gd) and the parts rack (parts_rack_panel.gd),
# one shot each, some stock on the racks and some parts kept. Own test saves only.
#   tools/run_test.sh tests/charcoal_shelf_shot.gd --fixed-fps 60 -- tag=before lang=zh
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_shelf_career.json"
	SaveGame.path = "user://zp_test_charcoal_shelf_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(name: String) -> void:
	Cap.save(root, "res://tests/out/charcoal_%s_%s_%s.png" % [name, tag, lang])


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.data = {}
	Career.start_new()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.money = 90000.0
	for k in ["salvage", "trade", "process", "power", "cargo"]:
		Career.data.port[k] = 1
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(90000.0)
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st["steel_billet:1"] = 3.5
	st["steel_plate:1"] = 2.0
	st["ferrous_scrap:1"] = 6.25
	# parts on every shelf class: one listed, one below the repair line
	Career.data.parts = [
		{"uid": "s1", "nk": "p_battery", "cls": "power", "cond": 0.92, "value": 2000.0, "ship": "tug", "tag": "BAT-T", "mass": 0.4, "job": "TUG-001"},
		{"uid": "s2", "nk": "p_battery", "cls": "power", "cond": 0.35, "value": 1800.0, "ship": "tug", "tag": "BAT-2", "mass": 0.4, "job": "TUG-001"},
		{"uid": "s3", "nk": "p_nav", "cls": "sail", "cond": 0.8, "value": 4000.0, "ship": "tug", "tag": "NAV-T", "mass": 0.25, "job": "TUG-001", "listed": {"t": 30.0}},
		{"uid": "s4", "nk": "p_pump", "cls": "thermal", "cond": 0.7, "value": 2600.0, "ship": "tug", "tag": "PMP-1", "mass": 0.5, "job": "TUG-001"},
		{"uid": "s5", "nk": "p_motor", "cls": "drive", "cond": 0.88, "value": 3100.0, "ship": "tug", "tag": "MOT-1", "mass": 0.6, "job": "TUG-001"}]
	Career.save()
	await _spawn()
	Txt.zh = lang == "zh"
	await _frames(20)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	g.open_shelf("A")
	await _frames(110)
	check(g.console_ui != null, "the racks open")
	_shot("shelf")
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(10)
	g.open_parts_rack()
	await _frames(110)
	check(g.console_ui != null, "the parts rack opens")
	_shot("rack")
	print("CHARCOAL SHELF SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
