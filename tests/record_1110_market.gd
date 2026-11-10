extends "res://tests/guide_check.gd"
# Video (2026-11-10): the endless hulk market — scrolled down on and on, a deep listing opened and
# inspected. Set-up of tests/ship_market_feed_check.gd; test saves only.
#   tools/run_test.sh tests/record_1110_market.gd --write-movie G:/temp/zp_rec_20261110/market.avi --fixed-fps 60

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_market_career.json"
	SaveGame.path = "user://zp_test_rec1110_market_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 5000000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"starmap_tour": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(60)
	g.open_ship_market()
	await _frames(60)
	var ui = g.console_ui
	kit.keep(true, "market")
	await _frames(120)
	# scrolling down, easing up to a brisk pace, on and on
	var v := 0.0
	for i in 600:
		v = minf(v + 0.25, 26.0)
		ui._scroll.scroll_vertical += int(v)
		await process_frame
	for i in 60:
		v = maxf(v - 0.45, 0.0)
		ui._scroll.scroll_vertical += int(v)
		await process_frame
	await _frames(60)
	# a deep listing opened, then checked
	var deep := ""
	for c in ui.feed_area.get_children():
		if c.visible and str(c.get_meta("id", "")).begins_with("SM-F") and not c.disabled:
			deep = str(c.get_meta("id"))
			break
	print("deep listing %s" % deep)
	ui._open(deep)
	await _frames(180)
	ShipMarket.inspect(deep, "structure")
	ui._detail()
	await _frames(120)
	ShipMarket.inspect(deep, "systems")
	ui._detail()
	await _frames(180)
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()
