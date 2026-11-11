extends SceneTree
# 2026-11-10: screenshots of the training card with the longest steps (both languages), 1080p:
#   tools/run_test.sh tests/course_card_shot.gd --fixed-fps 60
# Writes tests/out/course_card_<ship>_<which>_<lang>.png and prints the card's measured bottom edge.

const Cap = preload("res://tests/cap.gd")
const CASES := [["sp_cryo", 2, "long"], ["sp_fluid", 1, "long"], ["sp_fluid", 2, "short"], ["sp_cryo", 1, "safety"]]
var game
var frame := 0
var case_i := 0
var lang_i := 0


func _initialize() -> void:
	Txt.test_zh = true
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_load(CASES[0][0])


func _load(ship: String) -> void:
	if game != null:
		game.queue_free()
	Game.course_then = ""
	Game.course_chain = []
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(900, -300), "lmb": false, "move": Vector2.ZERO}
	scene.ship_id = ship
	root.add_child(scene)
	game = scene
	frame = 0


func _hud():
	for ch in game.get_children():
		if ch is TutorialHud:
			return ch
	return null


func _pick(l: Dictionary, which: String) -> int:
	var best := 0
	var key := -1
	for i in l.steps.size():
		var n: int = maxi(str(l.steps[i].text.zh).length(), str(l.steps[i].text.en).length() / 2)
		if which == "short":
			n = 1000 - n
		if which == "safety":
			n = 1000 if l.steps[i].get("id", "") == "valve" else 0
		if n > key:
			key = n
			best = i
	return best


func _process(_dt: float) -> bool:
	frame += 1
	var h = _hud()
	if h == null:
		return false
	if frame == 80:
		h.intro = 2
		var tut = game.tutorial
		var cs: Array = CASES[case_i]
		tut.lesson_i = cs[1]
		tut.step_i = _pick(tut.lessons()[cs[1]], cs[2])
		tut.done = false
		Txt.zh = lang_i == 0
		h.row_shift = 0.0
		h.tick_t = 9.0
	if frame == 100:
		var cs: Array = CASES[case_i]
		var tag := "%s_%s_%s" % [cs[0], cs[2], "zh" if lang_i == 0 else "en"]
		print("card ", tag, " step ", game.tutorial.step_i, " button y ", h.overview_now.position.y)
		Cap.save(root, "res://tests/out/course_card_%s.png" % tag)
		lang_i += 1
		if lang_i == 2:
			lang_i = 0
			case_i += 1
			if case_i >= CASES.size():
				quit(0)
				return true
			_load(CASES[case_i][0])
		else:
			frame = 79
	return false
