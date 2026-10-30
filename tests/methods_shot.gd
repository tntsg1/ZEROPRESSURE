extends SceneTree
# 104 号: the methods page (the terminal's growth page, methods first). Three stills: a new
# career (the next one only), a career with a few learned (tiers, the next tier), the borrow
# job's detail. Writes tests/out/methods_*.png. Own saves only.
#   tools/run_test.sh tests/methods_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var g


func _initialize() -> void:
	Career.path = "user://zp_test_methods_shot_career.json"
	SaveGame.path = "user://zp_test_methods_shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _career(done: int, methods: Dictionary, ups: Dictionary) -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.done = done
	Career.data.money = 180000.0
	Career.data.methods = methods
	Career.data.upgrades = ups
	Career.data.port = {"trade": 1, "process": 1}
	Career.save()


func _page(name: String, key: String) -> void:
	g.open_console("terminal")
	await _frames(6)
	var terminal = g.console_ui
	terminal.set_tab(5)
	await _frames(4)
	terminal.route_panel.select_category(6)
	if key != "":
		terminal.route_panel.select_key(key)
	await _frames(20)
	Cap.save(root, "res://tests/out/methods_%s.png" % name)
	if g.console_ui != null:
		g.console_ui.on_close.call()
	await _frames(40)


func _run() -> void:
	Txt.zh = true
	_career(3, {}, {})
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(120)
	await _page("1_new", "")
	_career(9, {"section": 2, "pump": 1, "field": 1}, {"lights": 1, "hauler": 1, "berth88": 1})
	await _page("2_learned", "method:field")
	await _page("3_borrow", "method:probe")
	quit()
