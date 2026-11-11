extends "res://tests/guide_check.gd"
# 2026-11-10 炭黑 v2: the settlement — the sheet (the haul, the prices, the cells, the one button), its
# details open, and its second page (the stores over the settlement). TUG-001 played by the bot in a
# fresh career; own test saves only.
#   tools/run_test.sh tests/charcoal_settle_shot.gd --fixed-fps 60 -- tag=before lang=zh

const Bot = preload("res://tests/salvage_bot.gd")
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_settle_career.json"
	SaveGame.path = "user://zp_test_charcoal_settle_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(name: String) -> void:
	await _frames(2)
	Cap.save(root, "res://tests/out/charcoal_settle_%s_%s_%s.png" % [tag, lang, name])


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true}
	Career.data.active = Career.opening(0)
	Career.save()
	Game.contract = Career.active()
	Game.start_ship = str(Game.contract.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	Txt.zh = lang == "zh"
	await _frames(12)
	g.tutorial = null
	var bot = Bot.new(g)
	while not bot.step():
		await process_frame
	Engine.time_scale = 1.0
	await _frames(20)
	check(g.state == "ending", "TUG-001 stripped by the bot (%s)" % g.state)
	g.hud.end_t = 9.0
	await _frames(40)
	check(g.hud.stores_page(), "the settlement is the haul page")
	await _shot("sheet")
	g.hud.end_detail = true
	await _frames(20)
	await _shot("detail")
	g.hud.end_detail = false
	g.open_store_settle()
	await _frames(60)
	await _shot("store")
	print("CHARCOAL SETTLE SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
