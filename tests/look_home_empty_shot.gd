extends SceneTree
# 91 号 (user: "也没感觉到你控制台变得怎么样了"): the terminal's home with the berth empty — the berth
# drawn as it stands, its facilities broken / fixed, the tug yard's hulks; the port walk's card
# kept off the page
#   tools/run_test.sh tests/look_home_empty_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_lookhomeempty_career.json"
	SaveGame.path = "user://zp_test_lookhomeempty_save.json"
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
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true}
	Career.data.money = 2428.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.upgrades["net_fix"] = true
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	g.open_console("terminal")
	await _frames(20)
	g.console_ui.set_tab(-1)
	await _frames(70)
	var fails := 0
	var bv = g.console_ui.berth_view
	if bv == null or bv.mode != "empty" or bv.facilities.is_empty():
		print("FAIL the empty berth isn't drawn (", bv.mode if bv != null else "-", ")")
		fails += 1
	if g.port_walk != null and g.port_walk.layer != null and g.port_walk.layer.visible:
		print("FAIL the port walk's card is over the terminal")
		fails += 1
	Cap.save(root, "res://tests/out/look_home_empty.png")
	print("home_empty: %d fails" % fails)
	quit(fails)
