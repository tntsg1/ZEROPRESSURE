extends "res://tests/guide_check.gd"
# 90 号: the port walk cut short does not start over as the forced first walk. The first start is
# forced (no way to end it) and is noted as started; cut short (the game reloaded before its end),
# it comes back as a walk the player may end, headed "continued"; ended, it is seen and never due
# again. Own test saves only.
#   tools/run_test.sh tests/port_walk_repeat_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_port_walk_repeat_career.json"
	SaveGame.path = "user://zp_test_port_walk_repeat_save.json"
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
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true}
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.money = 20000.0
	Career.save()
	var PW = preload("res://scripts/port_walk.gd")
	await _spawn()
	await _frames(20)
	# the first time: forced, and noted as started
	g.start_port_walk(true)
	await _frames(10)
	var wk = g.port_walk
	check(wk != null and g.walk_on() and not wk.close_b.visible, "the first walk is forced: no way to end it")
	check(Career.data.get("seen", {}).has("port_walk_started") and not Career.data.seen.has("port_walk"), "it is noted as started, not yet as seen")
	# cut short: the game goes (a reload) before the walk's end
	g.queue_free()
	await _frames(6)
	Career.data = {}
	Career.load_or_new()
	check(PW.due(), "unfinished, it is due again")
	await _spawn()
	await _frames(20)
	g.start_port_walk(true)
	await _frames(10)
	wk = g.port_walk
	check(wk != null and g.walk_on() and wk.close_b.visible and not wk.forced, "the second time it is not forced: “关掉导览” is there")
	check(str(wk.count.text).begins_with("接着上次"), "and its card says it is continued (%s)" % str(wk.count.text))
	# ended by the player: seen, never due again
	wk.close_b.pressed.emit()
	await _frames(6)
	check(not g.walk_on() and Career.data.get("seen", {}).has("port_walk"), "“关掉导览” ends it and marks it seen")
	g.queue_free()
	await _frames(6)
	Career.data = {}
	Career.load_or_new()
	check(not PW.due(), "after that a reload does not bring it back")
	print("PORT WALK REPEAT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
