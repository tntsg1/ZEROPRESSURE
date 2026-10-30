extends SceneTree
# 107 号 Q3/Q4: the terminal's home — the next-step card as tall as its words, the empty berth drawn
# finer with its list in two columns, the three keys' screens live (radar with swept signals, the
# berth's section, the methods). No stray lamp by the breadcrumb, nothing over the exchange key.
#   tools/run_test.sh tests/home107_shot.gd --fixed-fps 60 -- tag=v1
const Cap = preload("res://tests/cap.gd")
var tag := "v1"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.path = "user://zp_test_home107_career.json"
	SaveGame.path = "user://zp_test_home107_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true}
	Career.data.money = 111377.0
	Career.data.history = [{"id": "TUG-001"}]
	for id in ["lights", "net_fix", "furnace_main", "hauler"]:
		Career.data.upgrades[id] = true
	Career.save()
	# two sectors swept so the radar has blips
	for k in 2:
		var i: int = Scan.order()[k]
		Scan.sweep(i)
		Scan.finish()
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	g.open_console("terminal")
	await _frames(20)
	g.console_ui.set_tab(-1)
	await _frames(80)
	var fails := 0
	var bv = g.console_ui.berth_view
	if bv == null or bv.mode != "empty":
		print("FAIL the empty berth isn't drawn")
		fails += 1
	Cap.save(root, "res://tests/out/home107_%s.png" % tag)
	print("HOME107 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
