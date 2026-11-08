extends SceneTree
const Cap = preload("res://tests/cap.gd")
var failures := 0

func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_load_card_career.json"
	SaveGame.path = "user://zp_test_load_card_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + what)
	if not ok:
		failures += 1

func _run() -> void:
	Game.course_then = ""
	Game.course_chain = []
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	game.ship_id = "sp_load"
	root.add_child(game)
	await _frames(10)
	var hud: TutorialHud
	for child in game.get_children():
		if child is TutorialHud:
			hud = child
	_check(hud != null and game.tutorial != null, "load course and HUD")
	if hud == null or game.tutorial == null:
		quit(1)
		return
	hud.intro = 2
	game.tutorial.set_process(false)
	game.tutorial.set_physics_process(false)
	game.tutorial.lesson_i = 1
	var lesson: Dictionary = game.tutorial.lesson()
	_check(lesson.title.zh == "拆除预紧折叠臂", "lesson title updated")
	for i in [1, 2, 3]:
		game.tutorial.step_i = i
		_check(str(game.tutorial.step().id) == ["", "bleed", "pins", "pivot"][i], "step %d follows actual course progress" % i)
		await _frames(4)
		if DisplayServer.get_name() != "headless":
			Cap.save(root, "res://tests/out/load_lesson_card_%d.png" % i)
	game.queue_free()
	await _frames(4)
	quit(1 if failures else 0)
