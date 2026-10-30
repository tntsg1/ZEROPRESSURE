extends SceneTree
# 91 号 控制台 UI 统一（外部画面定案 Q3 A）：每个控制台打开一次截图，前后对比。
#   tools/run_test.sh tests/look_console_shot.gd --fixed-fps 60 -- tag=before
const Cap = preload("res://tests/cap.gd")
var tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.path = "user://zp_test_lookconsole_career.json"
	SaveGame.path = "user://zp_test_lookconsole_save.json"
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
	Career.data.money = 90000.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	var shots := [["power", func(): g.open_power_screen()], ["mill", func(): g.open_mill()], ["district_cargo", func(): g.open_district("cargo")],
		["district_tug", func(): g.open_district("tug")], ["heat", func(): g.open_heat()], ["sort", func(): g.open_sort()], ["assay", func(): g.open_assay()],
		["rack", func(): g.open_parts_rack()], ["shelf", func(): g.open_shelf("A")], ["exchange", func(): g.open_exchange()], ["ship_market", func(): g.open_ship_market()]]
	for s in shots:
		s[1].call()
		await _frames(40)
		if g.console_ui == null:
			print("not opened: ", s[0])
			continue
		Cap.save(root, "res://tests/out/look_console_%s_%s.png" % [tag, s[0]])
		print("shot ", s[0])
		if g.console_ui.has_method("close"):
			g.console_ui.close()
		elif g.console_ui.has_method("_close"):
			g.console_ui._close()
		await _frames(20)
		if g.console_ui != null:
			print("still open after close: ", s[0])
			g.console_ui = null
			get_root().get_tree().paused = false
			g.paused_sim = false
	quit()
