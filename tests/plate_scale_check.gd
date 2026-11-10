extends SceneTree
# 船坞终端名牌回归（2026-11-10 用户：大船时名牌变糊；自动化时别挂名牌）。测试存档。
#  1. 大船（ic120）在船坞，无人机不在终端跟前：船坞终端和仓库终端都不画名牌
#  2. 无人机到船坞终端跟前，镜头 0.35–2.4 倍：名牌每帧重画，屏幕字号 = 14 px
#     （按画它时的画布缩放与当前画布缩放之比算；旧的 bug 是名牌不重画、被镜头拉大）
# tools/run_test.sh tests/plate_scale_check.gd --fixed-fps 60

const ConsoleArt = preload("res://scripts/console_art.gd")
const M := 48.0
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_plate_career.json"
	SaveGame.path = "user://zp_test_plate_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _put(g, at: Vector2) -> void:
	g.drone.alive = true
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _run() -> void:
	Career.data = {}
	Career.start_new()
	Career.data.money = 41250.0
	Career.save()
	Game.contract = Career.sign_active()
	Game.contract.ship = "ic120"
	Game.start_ship = "ic120"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	var c: Vector2 = g.consoles.centre(0)
	var title: String = g.txt("cn_terminal")
	g.cam_override = c + Vector2(2.0 * M, 1.0 * M)
	g.cam_pos = g.cam_override
	# 1. away from the terminals: no plate at all
	_put(g, c + Vector2(18.0 * M, 2.0 * M))
	g.zoom_override = 0.6
	await _frames(30)
	ConsoleArt.plates.clear()
	await _frames(20)
	_check(g.consoles.near() == "", "drone away from the terminals (near: \"%s\")" % g.consoles.near())
	_check(ConsoleArt.plates.is_empty(), "no name plate while nobody is at a terminal (%s)" % str(ConsoleArt.plates.keys()))
	# 2. at the berth terminal: drawn every frame at 14 screen px, whatever the zoom
	for zz in [0.35, 0.8, 1.6, 2.4]:
		_put(g, c + Vector2(0.55 * M, 0.0))
		g.zoom_override = zz
		await _frames(45)
		_put(g, c + Vector2(0.55 * M, 0.0))
		ConsoleArt.plates.clear()
		await _frames(3)
		var p = ConsoleArt.plates.get(title)
		var now: float = g.consoles.get_canvas_transform().get_scale().x
		if p == null:
			_check(false, "zoom %.2f: plate \"%s\" drawn (near: \"%s\")" % [zz, title, g.consoles.near()])
			continue
		var px := 14.0 * now / float(p[1])
		_check(Engine.get_process_frames() - int(p[0]) <= 2, "zoom %.2f: plate redrawn this frame (drawn %d, now %d)" % [zz, p[0], Engine.get_process_frames()])
		_check(absf(px - 14.0) < 0.3, "zoom %.2f: plate font on screen %.2f px (14)" % [zz, px])
		_check(not ConsoleArt.plates.keys().any(func(k): return str(k) != title), "zoom %.2f: only the terminal in use has a plate (%s)" % [zz, str(ConsoleArt.plates.keys())])
	print("plate_scale_check: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
