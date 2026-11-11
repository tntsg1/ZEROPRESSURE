extends SceneTree
# 炭黑 rollout, batch 1: the terminal's pages besides the home (find ships, berth, methods and
# build, drone upgrades) and the loadout page, in Chinese or English, plus the frame times while
# each page opens — the same career every run so before/after line up.
#   tools/run_test.sh tests/charcoal_pages_shot.gd -- tag=before [lang=en] [frames]
const Cap = preload("res://tests/cap.gd")
const PAGES := [[1, "berth"], [5, "methods"], [8, "drone"], [0, "market"]]
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
	Career.path = "user://zp_test_charcoal_pages_career.json"
	SaveGame.path = "user://zp_test_charcoal_pages_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
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
	# some of the berth mended, some not, so the berth page has both
	for id in ["lights", "net_fix", "furnace_main", "hauler"]:
		Career.data.upgrades[id] = true
	# hulks on the market, so the find-ships page is the market rather than the star map
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Career.data.offers = []
	for sh in ["gr7", "qc30", "m14"]:
		var o: Dictionary = Market.offer(rng, Career.data, 1, {}, "full", sh)
		o.erase("_ship")
		Career.data.offers.append(o)
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
	Txt.zh = not en
	g.open_console("terminal")
	await _frames(30)
	var term = g.console_ui
	var lang := "en" if en else "zh"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for p in PAGES:
		term.set_tab(int(p[0]))
		var all: Array = []
		var last := Time.get_ticks_usec()
		for i in 60:
			await process_frame
			var now := Time.get_ticks_usec()
			all.append((now - last) / 1000.0)
			last = now
		all.sort()
		var mean := 0.0
		for v in all:
			mean += v
		mean /= all.size()
		print("PAGE_FRAMES %s %s mean=%.2f p95=%.2f max=%.2f" % [tag, p[1], mean, all[int(all.size() * 0.95)], all[-1]])
		if not frames_only:
			await _frames(30)
			Cap.save(root, "res://tests/out/charcoal_pg_%s_%s_%s.png" % [tag, lang, p[1]])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if not frames_only:
		# the loadout page, over the market
		term.set_tab(0)
		await _frames(20)
		term.loadout_in_tests = true
		term._open_loadout(Callable())
		await _frames(60)
		Cap.save(root, "res://tests/out/charcoal_pg_%s_%s_loadout.png" % [tag, lang])
	quit()
