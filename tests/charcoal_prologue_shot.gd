extends "res://tests/guide_check.gd"
# 2026-11-11 炭黑 v2: the prologue's guide (its card, the target ring and the arrow from the drone) in
# the belt, a fresh career, no opening film. Own test saves only.
#   tools/run_test.sh tests/charcoal_prologue_shot.gd --fixed-fps 60 -- tag=before lang=zh
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_prologue_career.json"
	SaveGame.path = "user://zp_test_charcoal_prologue_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.start_new()
	Career.data.seen = {"intro": true}
	Career.save()
	Game.opening_in_tests = false
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	Txt.zh = lang == "zh"
	await _frames(120)
	check(g.prologue != null, "the belt prologue is on")
	Cap.save(root, "res://tests/out/charcoal_prologue_%s_%s.png" % [tag, lang])
	print("CHARCOAL PROLOGUE SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
