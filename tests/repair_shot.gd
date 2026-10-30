extends SceneTree
# G2 pictures for review: the run-down berth (dead lamp, torn net, wreck outlines),
# the repair page with parts on the shelf, the finance page with the credit, and the
# repair show. A dedicated test career and a non-focusing window; no player save is touched.
# tools/run_test.sh tests/repair_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_repairshot_career.json"
	SaveGame.path = "user://zp_test_repairshot_save.json"
	SaveGame.train_path = "user://zp_test_repairshot_training.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = {}
	Career.start_new()
	var d := Career.data
	d.market = true
	d.done = 2
	d.money = 23000.0
	d.story_job = {}
	d.active = {}
	d.parts = [
		{"uid": "a:G-01:1", "cls": "power", "tag": "G-01", "nk": "p_gen", "cond": 0.82, "value": 16000.0, "ship": "gr7", "job": "G1C-001"},
		{"uid": "a:B-01:2", "cls": "power", "tag": "B-01", "nk": "p_battery", "cond": 0.55, "value": 2000.0, "ship": "gr7", "job": "G1C-001"},
		{"uid": "a:CP-E:3", "cls": "thermal", "tag": "CP-E", "nk": "p_pump", "cond": 0.9, "value": 4000.0, "ship": "gr7", "job": "G1C-001"},
		{"uid": "a:ENG-C:4", "cls": "drive", "tag": "ENG-C", "nk": "p_engc", "cond": 0.74, "value": 11000.0, "ship": "gr7", "job": "G1C-001"},
		{"uid": "a:CAP-01:5", "cls": "power", "tag": "CAP-01", "nk": "p_cap", "cond": 0.71, "value": 1500.0, "ship": "gr7", "job": "G1C-001"},
	]
	d.structure_t = 13.5
	Career.save()
	# ---- the berth, run down: lamp out, torn net, wrecks outlined
	Game.start_ship = "berth"
	Game.contract = {}
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(5)
	g.zoom_target = 0.62
	g.zoom_now = 0.62
	g.cam_pos = Dock.centre() * Geom.M
	await _frames(40)
	Cap.save(root, "res://tests/out/repair_berth_zh.png")
	g.queue_free()
	await _frames(3)
	# ---- the terminal: the repair page and the finance page
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	term._skip_boot()
	await _frames(10)
	term.set_tab(1)
	await _frames(30)
	Cap.save(root, "res://tests/out/repair_page_zh.png")
	term.set_tab(2)
	term.repay_amt = 20000.0
	await _frames(30)
	Cap.save(root, "res://tests/out/repair_finance_zh.png")
	term.queue_free()
	await _frames(3)
	# ---- the show: lighting repaired at the terminal, seen back at the berth
	var why := Repair.fix("lights", true)
	print("fix lights: '", why, "' pending ", Career.data.repaired_pending)
	Game.start_ship = "berth"
	Game.contract = {}
	Game.cine_in_tests = true
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(130)
	print("show state: ", g.state, " pending: ", Career.data.repaired_pending)
	Cap.save(root, "res://tests/out/repair_show_zh.png")
	await _frames(200)
	Cap.save(root, "res://tests/out/repair_berth_lit_zh.png")
	g.queue_free()
	await _frames(3)
	finished = true
