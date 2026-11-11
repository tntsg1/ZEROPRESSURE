extends "res://tests/guide_check.gd"
# 2026-11-11 炭黑: a guide card drawn with GuideMark.card_box (the port walk's), one shot. Own test saves.
#   tools/run_test.sh tests/charcoal_walkcard_shot.gd --fixed-fps 60 -- tag=before lang=zh
var tag := "after"
var lang := "zh"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("lang="):
			lang = a.substr(5)
	Career.path = "user://zp_test_charcoal_walkcard_career.json"
	SaveGame.path = "user://zp_test_charcoal_walkcard_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = lang == "zh"
	Career.data = {}
	Career.start_new()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.save()
	await _spawn()
	Txt.zh = lang == "zh"
	await _frames(20)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	g.start_port_walk(false)
	await _frames(90)
	check(g.walk_on(), "the port walk is on")
	Cap.save(root, "res://tests/out/charcoal_walkcard_%s_%s.png" % [tag, lang])
	print("CHARCOAL WALKCARD SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
