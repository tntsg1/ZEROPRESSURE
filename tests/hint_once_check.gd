extends "res://tests/guide_check.gd"
# user 2026-10-26 ("新手引导等内容，只在我第一次玩的时候出现"): a one-off hint shows once per
# career, not again with every contract; the save keeps it; a new career sees it again. Own saves only.
#   tools/run_test.sh tests/hint_once_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_hint_once_career.json"
	SaveGame.path = "user://zp_test_hint_once_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	var tier := Txt.hint_tier
	Txt.hint_tier = "guided"
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.save()
	await _spawn()
	check(g.career(), "in the career's berth")
	g.hint("field")
	check(g.hint_log.size() == 1, "the first time: the hint shows")
	check(Career.data.get("hints_once", {}).has("field"), "and the career keeps it")
	Career.save()
	g.queue_free()
	await _frames(4)
	Career.data = {}
	Career.load_or_new()
	await _spawn()
	g.hint("field")
	check(g.hint_log.is_empty(), "the next contract (game reloaded): not again")
	g.queue_free()
	await _frames(4)
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.save()
	await _spawn()
	g.hint("field")
	check(g.hint_log.size() == 1, "a new career sees it again")
	g.queue_free()
	await _frames(4)
	Txt.hint_tier = tier
	print("HINT ONCE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
