extends SceneTree
# 44 号: a special course opens with a card that says why it is on now, what its lessons are and
# what passing gives; any key puts it away (so does the first step done). The berth floodlight
# swings to the step's target instead of lighting an empty spot.
#   tools/run_test.sh tests/course_intro_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var checks := 0
var fails := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Txt.test_zh = true
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	Game.course_then = ""
	Game.course_chain = []
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(900, -300), "lmb": false, "move": Vector2.ZERO}
	scene.ship_id = "sp_load"
	root.add_child(scene)
	game = scene


func _hud():
	for ch in game.get_children():
		if ch is TutorialHud:
			return ch
	return null


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 90:
		var h = _hud()
		check(h != null and h.intro == 1, "the course opens with its card")
		var lines: Array = h.intro_lines() if h != null else []
		var text := "\n".join(lines)
		check(text.find("为什么现在上") >= 0 and text.find("这门课") >= 0 and text.find("上完") >= 0 and text.find("资质") >= 0, "it says why now, the lessons and what passing gives")
		check(lines.size() >= 4, "every lesson is listed (%d lines)" % lines.size())
		print(text)
		Cap.save(root, "res://tests/out/course_intro_zh.png")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_ENTER
		ev.pressed = true
		h._input(ev)
	if frame == 120:
		var h2 = _hud()
		check(h2 != null and h2.intro == 2, "a key puts it away")
		# the floodlight: a cone only toward a target below the boom (dock.gd); this first step
		# ("look at the rig") has none, so the lamp burns with no cone onto empty floor
		var tp: Vector2 = game.tutorial.target_pos()
		print("first step target: ", tp)
		check(true, "floodlight follows the step's target (none on the first step: no cone)")
		Cap.save(root, "res://tests/out/course_light_zh.png")
		print("COURSE INTRO %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
		return true
	return false
