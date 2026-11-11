extends SceneTree
# 2026-11-10 (user: "电网调度……右上角都已经弄出去了"): the grid screen opened from the power
# district's console, so its close key reads "返回动力区操作台 [Esc]" / "BACK TO … CONSOLE [Esc]";
# a shot of the whole screen and the key must lie inside the screen.
#   tools/run_test.sh tests/power_head_shot.gd --fixed-fps 60 -- tag=after [en]
const Cap = preload("res://tests/cap.gd")
const Back := preload("res://scripts/ui_back.gd")
var g


func _initialize() -> void:
	Career.path = "user://zp_test_powerhead_career.json"
	SaveGame.path = "user://zp_test_powerhead_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var tag := "after"
	var en := "en" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "walk_power": true, "store_counter": true}
	Career.data.money = 714573.0
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(50)
	Txt.zh = not en
	var nm := Port.name_of("power")
	Back.go(Back.entry("district:power", [nm + "操作台", nm + " CONSOLE"], func(): g.open_district("power")), "power", func(): g.open_power_screen())
	var ft: Array = []
	var last := Time.get_ticks_usec()
	for i in 60:
		await process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
	ft.sort()
	print("POWER_FRAMES %s mean=%.2f p95=%.2f" % [tag, ft.reduce(func(x, y): return x + y, 0.0) / ft.size(), ft[int(ft.size() * 0.95)]])
	await _frames(30)
	var p = g.console_ui
	var worst := 0.0
	if p != null:
		for b in p.find_children("*", "Button", true, false):
			if b.is_visible_in_tree():
				worst = maxf(worst, b.get_global_rect().end.x)
	print("POWER_HEAD %s %s: rightmost key edge %.0f of %.0f -> %s" % [tag, "en" if en else "zh", worst, root.get_visible_rect().size.x, "FAIL" if worst > root.get_visible_rect().size.x - 4.0 else "PASS"])
	Cap.save(root, "res://tests/out/power_head_%s_%s.png" % [tag, "en" if en else "zh"])
	quit()
