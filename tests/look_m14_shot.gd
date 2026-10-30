extends SceneTree
# 91 号画面升级样片：M-14 在船坞里，全景 + 激光切割特写 + 切开一刀后。
# 前后对比用同一机位：tools/run_test.sh tests/look_m14_shot.gd --fixed-fps 60 -- tag=before
const Cap = preload("res://tests/cap.gd")
var tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.path = "user://zp_test_look_career.json"
	SaveGame.path = "user://zp_test_look_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	var hull = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "hull" and p.body == null and not g.world.hidden(g.world.frame(p) * Geom.centroid(p.poly)):
			hull = p
			break
	var hc: Vector2 = g.world.frame(hull) * Geom.centroid(hull.poly)
	var ship_c := Vector2.ZERO
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and p.body == null:
			ship_c += g.world.frame(p) * Geom.centroid(p.poly)
			n += 1
	ship_c /= maxf(n, 1)
	g.cam_override = ship_c
	g.zoom_override = 0.42
	await _frames(60)
	Cap.save(root, "res://tests/out/look_m14_%s_0_wide.png" % tag)
	g.tools.tool = 2
	g.drone.global_position = hc + Vector2(-1.0 * Geom.M, -4.0 * Geom.M)
	g.bot.aim = hc + Vector2(-1.0 * Geom.M, 1.0 * Geom.M)
	g.bot.lmb = true
	g.bot.gauge = true
	g.cam_override = hc + Vector2(-1.0 * Geom.M, -1.0 * Geom.M)
	g.zoom_override = 1.3
	await _frames(60)
	g.bot.gauge_at = g.get_viewport().get_canvas_transform() * g.bot.aim
	await _frames(10)
	Cap.save(root, "res://tests/out/look_m14_%s_1_cut.png" % tag)
	for k in 3:
		g.bot.aim = hc + Vector2((k - 1) * 1.6 * Geom.M, 1.0 * Geom.M)
		await _frames(50)
	g.zoom_override = 0.8
	await _frames(40)
	Cap.save(root, "res://tests/out/look_m14_%s_2_mid.png" % tag)
	g.bot.lmb = false
	quit()
