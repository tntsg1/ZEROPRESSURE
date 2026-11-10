extends SceneTree
# Video (2026-11-10): the berth terminal's name plate — it shows when the drone comes up to the
# terminal, goes when it leaves, and stays sharp at any zoom with a big ship (IC-120) in the berth.
# Set-up of tests/plate_scale_check.gd; test saves only.
#   tools/run_test.sh tests/record_1110_plate.gd --write-movie G:/temp/zp_rec_20261110/plate.avi --fixed-fps 60

const M := 48.0
var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_plate_career.json"
	SaveGame.path = "user://zp_test_rec1110_plate_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put(g, at: Vector2) -> void:
	g.drone.alive = true
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO


# the drone glides from a to b over n frames (eased), held there every frame
func _glide(g, a: Vector2, b: Vector2, n: int) -> void:
	for i in n:
		var k := (i + 1.0) / n
		k = k * k * (3.0 - 2.0 * k)
		_put(g, a.lerp(b, k))
		await process_frame


func _hold(g, at: Vector2, n: int) -> void:
	for i in n:
		_put(g, at)
		await process_frame


func _zoom_to(g, z0: float, z1: float, n: int, at: Vector2) -> void:
	for i in n:
		var k := (i + 1.0) / n
		k = k * k * (3.0 - 2.0 * k)
		g.zoom_override = lerpf(z0, z1, k)
		_put(g, at)
		await process_frame


func _run() -> void:
	Txt.zh = true
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
	kit.follow = func():
		g.tutorial = null
		if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
			g.hud.voice.fold()
	var c: Vector2 = g.consoles.centre(0)
	var far := c + Vector2(18.0 * M, -3.0 * M)
	var at := c + Vector2(0.55 * M, 0.0)
	g.cam_override = c + Vector2(6.0 * M, 0.0)
	g.cam_pos = g.cam_override
	g.zoom_override = 0.8
	await _hold(g, far, 60)
	# 1. the drone flies up to the terminal: the plate comes up; it flies off: the plate goes
	kit.keep(true, "near")
	await _hold(g, far, 60)
	await _glide(g, far, at, 180)
	await _hold(g, at, 150)
	await _glide(g, at, far, 180)
	await _hold(g, far, 90)
	# 2. back at the terminal, the camera pulled out to the big ship and in close: still sharp
	await _glide(g, far, at, 150)
	g.cam_override = c + Vector2(2.0 * M, 1.0 * M)
	await _hold(g, at, 60)
	await _zoom_to(g, 0.8, 0.4, 150, at)
	await _hold(g, at, 90)
	await _zoom_to(g, 0.4, 2.4, 200, at)
	await _hold(g, at, 120)
	kit.keep(false, "end")
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()
