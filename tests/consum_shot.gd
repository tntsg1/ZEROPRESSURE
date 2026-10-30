extends SceneTree
# G3 pictures for review: the techniques-and-parts page, the loadout page with the
# parts section, the site with the parts' wear in the toolbar.
# tools/run_test.sh tests/consum_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "consum": true}
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_consumshot_career.json"
	SaveGame.path = "user://zp_test_consumshot_save.json"
	SaveGame.train_path = "user://zp_test_consumshot_training.json"
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
	d.done = 4
	d.money = 31000.0
	d.story_job = {}
	d.active = {}
	d.feats = {"section": {"ship": "gr7", "job": "G1B-001", "at": 3, "measure": 13.5}}
	d.gear = {"anchor": 1, "probe": 1}
	Career.save()
	Consum.buy("lens", 0)
	Consum.buy("cap", 2)
	Consum.fitted("probe").left = 9.0
	Career.save()
	# ---- the terminal: the techniques-and-parts page
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	term.loadout_in_tests = true
	root.add_child(term)
	await _frames(3)
	term._skip_boot()
	await _frames(10)
	term.set_tab(3)
	await _frames(30)
	Cap.save(root, "res://tests/out/consum_tech_zh.png")
	# the loadout page, opened for a trial
	term.set_tab(0)
	term.toggle_trials()
	await _frames(5)
	term.take(0)
	await _frames(30)
	Cap.save(root, "res://tests/out/consum_loadout_zh.png")
	if term.loadout != null:
		term.loadout.cancel()
	await _frames(5)
	term.queue_free()
	await _frames(3)
	# ---- on site: the toolbar's wear bars, the probe nearly worn out
	var a: Dictionary = Career.active()
	Game.start_ship = a.get("ship", "gr7")
	Game.contract = a
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await _frames(5)
	g.tools.set_tool(2, true)
	g.drone.global_position = Vector2(18.0, -6.0) * Geom.M
	g.bot.aim = Vector2(18.0, -3.78) * Geom.M
	g.zoom_target = 1.0
	g.zoom_now = 1.0
	g.cam_pos = Vector2(18.0, -2.0) * Geom.M
	await _frames(40)
	Cap.save(root, "res://tests/out/consum_site_zh.png")
	g.queue_free()
	await _frames(3)
	finished = true
