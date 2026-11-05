extends "res://tests/record108.gd"
# 131 号: about 30 s for the owner. The stores terminal in the berth and its line, the camera running
# along the cable to the cargo district; the port walk's step 2 flown out of the berth — the floor
# arrows flowing, "中央转运环 · 还有 N m" counting down on the screen's edge; folded away on arrival;
# the terminal with the walk's step on the berth key and the main line one grey line. The drone flies
# on simulated input; the real mouse is never touched. Test saves only.
#   tools/run_test.sh tests/record_guide_way.gd --write-movie recordings/record_guide_way.avi --fixed-fps 30

const StoreLine = preload("res://scripts/store_line.gd")


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_guide_way_career.json"
	SaveGame.path = "user://zp_test_record_guide_way_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the drone flown by its own stick toward a point, braking to stop on it (strict inertia: it pushes
# and counter-pushes, nothing is set by hand)
func _fly_to(p: Vector2, secs: float, stop_m := 2.0) -> void:
	var M := Geom.M
	for i in int(secs * FPS):
		var d: Vector2 = p - g.drone.global_position
		var v: Vector2 = g.drone.linear_velocity
		var want := d.normalized() * minf(9.0 * M, sqrt(2.0 * 5.0 * M * d.length()) * 0.8)
		var mv := (want - v) / (3.0 * M)
		g.bot.move = mv.limit_length(1.0) if d.length() > stop_m * M or v.length() > 0.5 * M else Vector2.ZERO
		g.bot.aim = g.drone.global_position
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	g.bot.move = Vector2.ZERO


# the camera along a polyline (world px) in secs, the zoom easing between two values
func _pan_along(pts: PackedVector2Array, secs: float, z0: float, z1: float) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var n := int(secs * FPS)
	for f in n:
		var u := 0.5 - 0.5 * cos(PI * float(f) / n)
		var s := u * total
		var at := pts[0]
		for i in range(1, pts.size()):
			var l := pts[i - 1].distance_to(pts[i])
			if s <= l:
				at = pts[i - 1].lerp(pts[i], s / maxf(l, 0.001))
				break
			s -= l
			at = pts[i]
		g.cam_override = at
		g.zoom_override = lerpf(z0, z1, u)
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame


func _run() -> void:
	cap_total = 4
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "store_guide_done": true}
	Career.data.money = 20000.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	await _secs(0.5)
	g.tutorial = null
	var M := Geom.M
	# ---- 1: the terminal and its line
	g.drone.global_position = Consoles.kiosk_at() + Vector2(2.6, 1.2) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_pos = Consoles.kiosk_at()
	g.cam_override = Consoles.kiosk_at() + Vector2(1.2, -0.6) * M
	g.zoom_override = 1.25
	await _secs(1.0)
	_beat(1, "柜台换成了仓库终端", "开局就在塔墙上；一根线缆沿桁架通向货运区——主仓库在那边")
	await _secs(3.0)
	var run: PackedVector2Array = StoreLine.run().pts
	var pts := PackedVector2Array([Consoles.kiosk_at() + Vector2(1.2, -0.6) * M])
	pts.append_array(run.slice(2))
	await _pan_along(pts, 6.0, 1.25, 0.42)
	await _secs(0.8)
	# ---- 2: the port walk's step 2, flown out of the berth
	g.cam_override = null
	g.zoom_override = -1.0
	g.zoom_target = 0.75
	g.drone.global_position = Vector2(clampf(Dock.centre().x, Dock.TOWER_X + 3.0, Dock.ARM_X1 - 3.0) * M - 3.0 * M, Dock.RAIL_Y * M + 7.0 * M)
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_pos = g.drone.global_position
	g.cam_vel = Vector2.ZERO
	g.start_port_walk(true)
	await _secs(0.3)
	var wk = g.port_walk
	var gate := Vector2(wk._gate_x(), wk._rail_y() - 8.0 * M)
	_beat(2, "地上的箭头带路，屏幕边上报距离", "沿真实可飞的走廊流向目标；目标在屏幕外时，边缘写着还有多少米")
	await _fly_to(gate, 2.5, 3.0)
	await _fly_to(PortStructure.centre() + Vector2(0.0, PortArt.HUB_R - 5.0) * PortStructure.M(), 7.0, 2.0)
	# the next step (the ring's console): flown to, and on arrival everything folds away
	var st: Vector2 = wk.target()
	if st != Vector2.INF:
		await _fly_to(st, 3.5, 0.8)
	# ---- 3: arrived — the way folds away
	_beat(3, "到了就收起", "飞到目标跟前，箭头、边缘指示和标题里的方向自动收掉；镜头从不自己乱跑")
	g.bot.brake = true
	await _secs(3.0)
	g.bot.brake = false
	# ---- 4: the terminal: the walk's step on the berth key, the main line one grey line
	for i in wk.steps.size():
		if str(wk.steps[i][0]) == "repair":
			wk.step = i
	wk._begin()
	await _secs(0.3)
	g.open_console("terminal")
	await _secs(1.2)
	_beat(4, "终端里只有一个声音", "导览直接标在「船坞」卡上并默认选中，按 Enter 就开；主线收成一行灰字")
	await _secs(4.5)
	print("RECORD GUIDE WAY DONE")
	quit()
