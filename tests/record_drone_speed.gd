extends "res://tests/record108.gd"
# The drone sped up (user 2026-11-05, "把无人机的最高速度提高"): about 20 s. Out of the berth gate and up
# the corridor to the hub at the new top speed, then Shift, then a burn against the drift (Space) to
# show the inertia kept. Simulated input only; the real mouse is never touched. Test saves only.
#   tools/run_test.sh tests/record_drone_speed.gd --write-movie recordings/record_drone_speed.avi --fixed-fps 30


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_dspeed_career.json"
	SaveGame.path = "user://zp_test_record_dspeed_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fly(dir: Vector2, dash: bool, frames: int) -> void:
	for f in frames:
		g.bot.move = dir
		g.bot.dash = dash
		g.bot.brake = false
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame


func _brake(frames: int) -> void:
	for f in frames:
		g.bot.move = Vector2.ZERO
		g.bot.dash = false
		g.bot.brake = true
		cap_t += 1.0 / FPS
		cap.queue_redraw()
		await process_frame
	g.bot.brake = false


func _run() -> void:
	cap_total = 3
	_caption_layer()
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "port_walk_started": true, "starmap_tour": true, "store_guide_done": true}
	Career.data.prologue_done = true
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
	# out in the open off the berth's boat pad, flying away from the station: nothing in the way
	var start: Vector2 = WorkBoat.pad_at("berth") + Vector2(0, 14.0) * Geom.M
	var away: Vector2 = (start - Backdrop.port_centre_px()).normalized()
	g.drone.global_position = start
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_pos = start
	g.cam_vel = Vector2.ZERO
	g.zoom_target = 0.45
	await _secs(1.0)
	_beat(1, "最高速度提高 1.5 倍", "平时 430 → 645，惯性不变：推多久就加速多久")
	await _fly(away, false, int(5.0 * FPS))
	_beat(2, "Shift 加力：780 → 1170", "背景的星空和港口飞快后退")
	await _fly(away, true, int(4.0 * FPS))
	_beat(3, "空格反推刹车", "速度越快，刹停要的距离越长，提前松手")
	await _brake(int(3.5 * FPS))
	await _secs(1.5)
	print("DRONE SPEED RECORDED")
	quit()
