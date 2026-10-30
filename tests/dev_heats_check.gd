extends "res://tests/guide_check.gd"
# The developer entry "tapped heats to 3" (39 号): on site and at the terminal it counts three arc
# furnace heats, so the furnace desk offers the auto sample-and-tap. Own test saves only.
#   tools/run_test.sh tests/dev_heats_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_dev_heats_career.json"
	SaveGame.path = "user://zp_test_dev_heats_save.json"
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
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	var dev: DevPanel = null
	for ch in g.get_children():
		if ch is DevPanel:
			dev = ch
	check(dev != null, "the developer panel is there")
	var n := -1
	for i in dev.rows().size():
		if str(dev.rows()[i][1]) == "dev_heats":
			n = i + 1
	check(n > 0 and dev._row_label(dev.rows()[n - 1]).find("出钢炉数") >= 0, "on site it lists \"%s\"" % (dev._row_label(dev.rows()[n - 1]) if n > 0 else "?"))
	check(not HeatAuto.offer(), "no auto sample-and-tap before")
	dev.run(n)
	check(int(Career.data.get("heat_count", 0)) == 3 and HeatAuto.offer(), "three heats counted: the auto sample-and-tap is offered")
	Career.data.heat_count = 7
	dev.run(n)
	check(int(Career.data.heat_count) == 7, "it never lowers a real count")
	dev.where = "terminal"
	var m := -1
	for i in dev.rows().size():
		if str(dev.rows()[i][1]) == "dev_heats":
			m = i + 1
	Career.data.heat_count = 0
	dev.run(m)
	check(m > 0 and int(Career.data.heat_count) == 3, "and at the terminal")
	dev.where = "game"
	g.queue_free()
	await _frames(4)
	print("DEV HEATS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
