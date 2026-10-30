extends "res://tests/record108.gd"
# 核爆动画精细化 (user 2026-10-30: "反应堆爆炸的时候动画优化精细一点"): about 30 s, the beam into the core
# and the whole cinematic to the bill. Captions up top, clear of the cinematic's own at the bottom.
# Own test saves only.
#   tools/run_test.sh tests/record_nuke_polish.gd --write-movie recordings/record_nuke_polish.avi --fixed-fps 30


func _initialize() -> void:
	Career.path = "user://zp_test_recnuke_career.json"
	SaveGame.path = "user://zp_test_recnuke_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _park(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _until_t(nk, tt: float) -> void:
	while nk.t < tt and not nk.finished:
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame


func _run() -> void:
	Txt.zh = true
	cap_total = 4
	_caption_layer()
	cap_layer.offset = Vector2(0, -760)
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "nr95"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10:
		await process_frame
	g.job = {"id": "nuke-rec", "ship": "nr95"}
	for i in 30:
		await process_frame
	for i in 4:
		var c = g.world.ctrls["DL-%d" % (i + 1)]
		g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
	var core = g.world.tag("CORE")
	var hw: Vector2 = g.world.frame(core) * Geom.centroid(core.poly)
	var top := hw + Vector2(0, -1.4) * Geom.M
	g.cam_override = hw + Vector2(0, -1.5) * Geom.M
	g.zoom_override = 1.0
	g.bot.aim = top + Vector2(0, -1.0) * Geom.M
	g.bot.lmb = true
	_beat(1, "激光切进堆芯", "离核心一米时先报警，切穿中心直接核爆")
	for i in int(3.5 * FPS):
		_park(top + Vector2(0, -3.2) * Geom.M)
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	g.bot.aim = top + Vector2(0, 0.8) * Geom.M
	while g.state != "nuke":
		_park(top + Vector2(0, -3.2) * Geom.M)
		await process_frame
	g.bot.lmb = false
	var nk = g.nuke
	_beat(2, "闪光、火球、等离子细丝", "白热火球变黄变橙再变红，中间先变薄，边缘拖出细丝；镜头上留下横向光痕")
	await _until_t(nk, nk.T_CLOSE)
	_beat(3, "碎片前沿扫过港区", "热碎片组成的冲击带；破洞一个个撕开、边缘烧红、裂纹蔓延、舱内空气喷出")
	await _until_t(nk, nk.t_card - 0.5)
	_beat(4, "整个港区烧毁，然后账单", "")
	await _until_t(nk, nk.t_card + nk.T_FADE + 7.0)
	print("RECORD NUKE DONE")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
