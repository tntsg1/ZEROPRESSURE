extends "res://tests/record_guide_way.gd"
# 131 号 (user 2026-11-05: "不都有列车吗？我为什么不能在拆船厂上等车？"): about 20 s. The port walk's new
# first steps: out to the berth's own shuttle stop by the gate, E calls the car, the ride to the
# central ring (the corridor going by), off at the ring — the carousel and the corridors. The drone
# flies on simulated input; the real mouse is never touched. Test saves only.
#   tools/run_test.sh tests/record_walk_shuttle.gd --write-movie recordings/record_walk_shuttle.avi --fixed-fps 30


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_walk_shuttle_career.json"
	SaveGame.path = "user://zp_test_record_walk_shuttle_save.json"
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
	g.zoom_target = 0.6
	g.drone.global_position = Vector2(Tram.station_at("salvage").x - 10.0 * M, Dock.RAIL_Y * M + 7.0 * M)
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_pos = g.drone.global_position
	g.cam_vel = Vector2.ZERO
	g.start_port_walk(true)
	await _secs(0.3)
	var wk = g.port_walk
	# ---- 1: out to the berth's own stop
	_beat(1, "先到拆船区接驳站", "出坞就是站台：地上的箭头带你过去，不用自己飞走廊")
	await _secs(0.6)
	await _fly_to(Tram.station_at("salvage"), 4.0, 0.8)
	await _secs(0.6)
	# ---- 2: E calls the car, the ring picked
	_beat(2, "按 E 叫车，选「中央转运环」", "车不在这一站会先开过来接你")
	await _key(KEY_E)
	await _secs(1.4)
	var ok := false
	if g.console_ui != null:
		for bt in g.console_ui.find_children("*", "Button", true, false):
			if str(bt.text).begins_with(Port.name_of("ring")) and not bt.disabled:
				bt.pressed.emit()
				ok = true
				break
	if not ok:
		print("NOTE: no button for the ring on the stops list")
	await _secs(0.4)
	# ---- 3: aboard: the corridor going by (faster through the game's own clock)
	var f := 0
	while not g.tram.riding and f < 30 * 20:
		await _secs(1.0 / FPS)
		f += 1
	_beat(3, "车上看沿途（2 倍速）", "什么都不用按，接驳车沿走廊开进中央环，到站自己下车")
	Look.time_k(2.0)
	Engine.max_physics_steps_per_frame = 16
	f = 0
	while wk.kind() == "ride" and f < 30 * 30:
		await _secs(1.0 / FPS)
		f += 1
	Look.time_k(1.0)
	# ---- 4: off at the ring
	_beat(4, "在中央环下车", "中间是转盘，六条走廊通六个区；之后坐车去别的区，飞只是可选")
	g.zoom_target = 0.45
	await _secs(4.0)
	print("WALK step ", wk.step, " ", wk.kind(), " ", wk.zone())
	print("RECORD WALK SHUTTLE DONE")
	quit()
