extends "res://tests/guide_check.gd"
# The power district screen's load curve (user 2026-10-27, screenshot: the curve ran out of the top
# of its box, up through the single-line diagram). The scale now fits the last five minutes' peak as
# well as the own capacity: a spike three times the capacity stays inside. Own test saves only.
#   tools/run_test.sh tests/power_trend_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_power_trend_career.json"
	SaveGame.path = "user://zp_test_power_trend_save.json"
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
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 0, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	var cap := Grid.capacity()
	# five minutes of load: base, then a long spike at three times the own sets (shore power), back down
	var h: Array = []
	for i in 300:
		h.append(2.0 if i < 120 or i > 220 else cap * 3.0)
	Grid.history = h
	g.open_power_screen()
	await _frames(30)
	var tr = g.console_ui.trend
	# the curve's highest point, as the screen draws it, is inside the box
	var peak := cap * 3.0
	var top := maxf(maxf(cap, peak) * 1.15, 0.1)
	var y_peak: float = tr.size.y - 18.0 - (tr.size.y - 30.0) * peak / top
	check(y_peak >= 0.0 and y_peak <= tr.size.y, "a spike of %.0f MW (capacity %.0f) is drawn inside the box (y %.0f of %.0f)" % [peak, cap, y_peak, tr.size.y])
	Grid.history = h
	await _frames(4)
	Cap.save(root, "res://tests/out/power_trend_spike_zh.png")
	g.console_ui.close()
	await _frames(4)
	print("POWER TREND %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
