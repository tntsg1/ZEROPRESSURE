extends "res://tests/record108.gd"
# The work boat, for the owner (2026-11-05, "作业艇怎么开"): about 40 s, the keys on every caption.
# The drone boards at the rack (E); the boat driven by its own thrust (WASD, coasting, Shift, Space);
# the docking assist; the transit list (B) and the autopilot round the outer lane, taken over by a
# direction key; DS-1 hitched at its eye (T), towed (slack, then taut, the hull swinging round), cast
# off in the delivery box and taken; home to the berth pad and out (E). Every move is simulated input
# (the game's bot stick and key events); nothing in the game is changed; the real mouse is never
# touched. Long legs run fast (said on the caption). Test saves only.
#   tools/run_test.sh tests/record_workboat.gd --write-movie recordings/record_workboat.avi --fixed-fps 30

const BoatTow = preload("res://scripts/boat_tow.gd")
var tw
var notes: Array = []          # what looked wrong, for the report


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_workboat_career.json"
	SaveGame.path = "user://zp_test_record_workboat_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
		await process_frame


func _tick() -> void:
	cap_t += 1.0 / FPS
	cap.queue_redraw()
	await process_frame


# the boat steered by its stick toward p: thrust toward the wanted velocity, nothing set by hand.
# stop_m: done this close; vmax m/s; dash: Shift held; easy: no thrust while the line is hard
func _drive(p: Vector2, vmax: float, limit_frames: int, stop_m := 6.0, dash := false, easy := false) -> bool:
	var b = g.boat
	var M := Geom.M
	for f in limit_frames:
		var d: Vector2 = p - b.global_position
		if d.length() < stop_m * M:
			g.bot.move = Vector2.ZERO
			g.bot.dash = false
			return true
		var want := d.normalized() * minf(vmax * M, sqrt(2.0 * 2.0 * M * d.length()))
		var err: Vector2 = want - b.linear_velocity
		var hard: bool = easy and tw != null and tw.tension > 20.0
		g.bot.move = err.normalized() if err.length() > 0.3 * M and not hard else Vector2.ZERO
		g.bot.dash = dash
		g.bot.brake = false
		await _tick()
	g.bot.move = Vector2.ZERO
	g.bot.dash = false
	notes.append("drive to %s did not arrive (left %.0f m)" % [str(p / M), (p - b.global_position).length() / M])
	return false


func _brake(limit_frames: int) -> void:
	var b = g.boat
	g.bot.brake = true
	for f in limit_frames:
		if b.linear_velocity.length() < 0.2 * Geom.M:
			break
		await _tick()
	g.bot.brake = false


func _hands_off(n: int) -> void:
	g.bot.move = Vector2.ZERO
	g.bot.brake = false
	g.bot.dash = false
	for f in n:
		await _tick()


# up to a pad and hands off: the assist settles it (the boat brakes to a crawl first)
func _dock(id: String, fast: float) -> void:
	var p: Vector2 = WorkBoat.pad_at(id)
	_speed(fast)
	await _drive(p, 9.0, 900, 10.0)
	_speed(2.5)
	await _brake(150)
	await _drive(p, 2.0, 200, 5.0)
	await _brake(60)
	await _hands_off(90)
	_speed(1.0)


func _speed(k: float) -> void:
	# faster through the game's own clock (Look.time_k, as its warp key): the step stays 1/120 s
	Look.time_k(k)
	Engine.max_physics_steps_per_frame = maxi(8, int(ceil(k * 5.0)))


func _run() -> void:
	cap_total = 7
	_caption_layer()
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "port_walk_started": true, "starmap_tour": true, "store_guide_done": true}
	Career.data.prologue_done = true
	Career.data.money = 10000.0
	Career.data.boat_visited = ["berth", "power"]
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
	tw = g.boat_tow
	var b = g.boat
	print("BOAT at %s pad %s; DS-1 %s; box %s" % [str(b.global_position / M), b.pad, str(tw.hulk.global_position / M) if tw.hulk != null else "-", str(BoatTow.deliver_point() / M)])
	# ---- 1: E at the rack
	g.zoom_target = 0.9
	g.drone.global_position = b.global_position + Vector2(-9.0, -5.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_pos = b.global_position
	g.cam_vel = Vector2.ZERO
	await _secs(0.6)
	_beat(1, "E 上艇", "无人机飞到闸门外的作业艇机架旁，按 E 钻进机架")
	for f in 45:
		var d: Vector2 = b.global_position - g.drone.global_position
		g.bot.move = ((d.normalized() * minf(5.0 * M, d.length() * 1.5)) - g.drone.linear_velocity) / (3.0 * M)
		g.bot.move = g.bot.move.limit_length(1.0)
		g.bot.aim = g.drone.global_position
		await _tick()
	g.bot.move = Vector2.ZERO
	await _secs(0.4)
	await _key(KEY_E)
	await _secs(1.0)
	if not b.aboard:
		notes.append("E at the rack did not board (drone %.1f m from the boat)" % (g.drone.global_position.distance_to(b.global_position) / M))
		b.board()
	# ---- 2: thrust, coast, Shift, Space
	g.zoom_target = 0.55
	_beat(2, "WASD 推进 · 松手滑行 · Shift 加力 · 空格 刹车", "严格惯性：推一下就一直滑，反推才停；加力推得更猛")
	g.bot.move = Vector2(-1, 0)
	for f in 60:
		await _tick()
	g.bot.move = Vector2.ZERO
	for f in 40:
		await _tick()
	g.bot.move = Vector2(-1, -0.3)
	g.bot.dash = true
	for f in 50:
		await _tick()
	g.bot.move = Vector2.ZERO
	g.bot.dash = false
	for f in 15:
		await _tick()
	await _brake(90)
	# ---- 3: to the tug yard's pad (fast), hands off: the docking assist
	_beat(3, "靠近停靠点松手：自动对准靠泊", "开到拖船区停靠点（快进）；松开按键，作业艇自己对准停稳")
	_speed(4.0)
	var tug_pad: Vector2 = WorkBoat.pad_at("tug")
	_speed(6.0)
	await _drive(Vector2(-125.0, -45.0) * M, 10.0, 600, 10.0)
	await _dock("tug", 6.0)
	if b.pad != "tug":
		notes.append("docking assist at the tug pad: pad '%s', %.1f m off, %.1f m/s" % [b.pad, b.global_position.distance_to(tug_pad) / M, b.linear_velocity.length() / M])
	# ---- 4: B, a pad visited before: the autopilot round the outer lane; a key takes over
	_beat(4, "B 打开转运面板：选去过的停靠点", "作业艇沿外圈自己开过去；中途按任意方向键立刻接管")
	await _key(KEY_B)
	await _secs(1.2)
	var panel = g.console_ui
	var pressed := false
	if panel != null:
		for bt in panel.find_children("*", "Button", true, false):
			if str(bt.text).begins_with(WorkBoat.pad_name("berth")) and not bt.disabled:
				bt.pressed.emit()
				pressed = true
				break
	if not pressed:
		notes.append("the transit list had no live button for the berth pad")
	await _secs(0.3)
	if b.route.is_empty():
		notes.append("the autopilot did not start a route")
	for f in 75:
		await _tick()
	_beat(4, "按方向键接管", "← 一按，自动驾驶让出，回到手动")
	g.bot.move = Vector2(-1, 0)
	for f in 12:
		await _tick()
	g.bot.move = Vector2.ZERO
	if not b.route.is_empty():
		notes.append("a direction key did not take over from the autopilot")
	_speed(2.0)
	await _brake(120)
	# ---- 5: DS-1: slow to the eye, T, the line takes up, the hull swings round
	_beat(5, "慢慢靠近拖眼，T 挂拖缆", "废弃船体 DS-1（28 吨）：船尾对准拖眼、相对速度够慢才挂得上")
	_speed(3.0)
	var eye: Vector2 = tw.eye()
	var ed: Vector2 = (eye - tw.hulk.global_position).normalized()
	await _drive(eye + ed * 7.5 * M, 8.0, 900, 1.0)
	_speed(2.5)
	await _brake(150)
	_speed(1.0)
	# pull away along the eye's line at a crawl: the hull swings round behind the push, the stern
	# comes round to the eye; T while the stern is within reach and the boat is slow
	for f in 240:
		var near_eye: bool = tw.stern().distance_to(tw.eye()) < 5.0 * M
		if near_eye and Vector2.from_angle(b.heading).dot(ed) > 0.85:
			break
		var want: Vector2 = ed * 1.1 * M
		var err: Vector2 = want - (b.linear_velocity - tw.hulk.linear_velocity)
		g.bot.move = err.normalized() * 0.6 if err.length() > 0.15 * M else Vector2.ZERO
		await _tick()
	g.bot.move = Vector2.ZERO
	var why: String = tw.hitch_reason()
	await _key(KEY_T)
	await _secs(0.5)
	if not tw.hitched:
		notes.append("T at the eye did not hitch: %s (stern %.1f m from the eye, rel %.1f m/s)" % [why, tw.stern().distance_to(tw.eye()) / M, (b.linear_velocity - tw.hulk.linear_velocity).length() / M])
	_beat(5, "缆绳先松后绷，拖着它走", "船体被拖眼拽着，从后面甩过来跟上")
	g.zoom_target = 0.42
	var p0: Vector2 = tw.hulk.global_position
	await _drive(tw.hulk.global_position + Vector2(-6.0, 40.0) * M, 2.0, 140, 30.0, false, true)
	# ---- 6: towed home (fast), cast off in the box, taken
	_beat(6, "拖进交付区（快进）", "绕过加工区，拖到船坞外的交付区")
	_speed(8.0)
	var dp: Vector2 = BoatTow.deliver_point()
	for wp in [Vector2(-150.0, -50.0) * M, Vector2(-85.0, -44.0) * M, dp + Vector2(10.0, 4.0) * M]:
		await _drive(wp, 3.0, 900, 6.0, false, true)
	await _brake(120)
	if tw.hulk != null:
		print("towed: hulk %.0f m from the box, moved %.0f m, peak %.1f kN" % [tw.hulk.global_position.distance_to(dp) / M, tw.hulk.global_position.distance_to(p0) / M, tw.peak])
	var money0 := float(Career.data.money)
	var steel0 := float(Career.data.get("structure_t", 0.0))
	_beat(6, "T 解缆，停稳就交付", "交付区把船体缓缓停住：付清理费，钢材入账")
	_speed(2.0)
	await _key(KEY_T)
	for f in 150:
		if tw.done:
			break
		await _tick()
	if not tw.done:
		notes.append("cast off in the box but not taken within 5 s (hulk %.0f m from the box, %.1f m/s)" % [tw.hulk.global_position.distance_to(dp) / M if tw.hulk != null else -1.0, tw.hulk.linear_velocity.length() / M if tw.hulk != null else -1.0])
	_speed(1.0)
	await _secs(1.5)
	print("delivered %s: money +%.0f, steel +%.1f t" % [str(tw.done), float(Career.data.money) - money0, float(Career.data.get("structure_t", 0.0)) - steel0])
	# ---- 7: home, E
	_beat(7, "回泊位停稳，E 下艇", "靠近船坞泊位松手自动靠泊，停稳后按 E，无人机出舱")
	var bp: Vector2 = WorkBoat.pad_at("berth")
	await _dock("berth", 2.0)
	if b.pad != "berth":
		notes.append("docking assist at the berth pad: pad '%s', %.1f m off" % [b.pad, b.global_position.distance_to(bp) / M])
	await _key(KEY_E)
	await _secs(2.0)
	if b.aboard:
		notes.append("E at the berth pad did not let the drone out")
	print("NOTES ", JSON.stringify(notes))
	print("RECORD WORKBOAT DONE")
	quit()


var _f0 := 0
func _beat(n: int, title: String, sub: String) -> void:
	print("BEAT %d at frame %d (+%d)" % [n, Engine.get_process_frames(), Engine.get_process_frames() - _f0])
	_f0 = Engine.get_process_frames()
	super(n, title, sub)
