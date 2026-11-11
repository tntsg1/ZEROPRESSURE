extends SceneTree
# The terminal's home in the A-暗1 炭黑 look: Chinese with 1–4 selected, English with 1, and the
# frame times while the terminal opens (the boot played, vsync off), so a before/after can be
# compared with the same setup.
#   tools/run_test.sh tests/charcoal_home_shot.gd -- tag=after [lang=en] [frames]
const Cap = preload("res://tests/cap.gd")
var tag := "after"
var en := false
var frames_only := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		elif a == "lang=en":
			en = true
		elif a == "frames":
			frames_only = true
	Career.path = "user://zp_test_charcoal_career.json"
	SaveGame.path = "user://zp_test_charcoal_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = not en
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "level": "senior"}
	Career.data.money = 714573.0
	Career.data.rep = 27
	Career.data.history = [{"id": "TUG-001"}]
	# every facility mended, the berth itself left at its first length
	for it in Repair.ITEMS:
		if not str(it[0]).begins_with("berth"):
			Career.data.upgrades[it[0]] = true
	Career.save()
	for k in 2:
		var i: int = Scan.order()[k]
		Scan.sweep(i)
		Scan.finish()
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	Txt.zh = not en    # the game's own settings load with the scene
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# frame times across an opening (the deal and the panels settling); run it a few times
	var all: Array = []
	g.open_console("terminal")
	var term = g.console_ui
	term.set_tab(-1)
	term.deal_t = 0.0
	var last := Time.get_ticks_usec()
	for i in 150:
		await process_frame
		var now := Time.get_ticks_usec()
		all.append((now - last) / 1000.0)
		last = now
	all.sort()
	var mean := 0.0
	for v in all:
		mean += v
	mean /= all.size()
	print("OPEN_FRAMES %s n=%d mean=%.2f p95=%.2f p99=%.2f max=%.2f ms" % [tag, all.size(), mean, all[int(all.size() * 0.95)], all[int(all.size() * 0.99)], all[-1]])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if frames_only:
		quit()
		return
	var t2 = g.console_ui
	await _frames(60)
	var lang := "en" if en else "zh"
	for s in (4 if not en else 1):
		t2.sel = s
		await _frames(40)
		Cap.save(root, "res://tests/out/charcoal_%s_%s_sel%d.png" % [tag, lang, s + 1])
	quit()
