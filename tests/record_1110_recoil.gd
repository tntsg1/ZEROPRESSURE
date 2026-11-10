extends "res://tests/recoil_check.gd"
# Video (2026-11-10): containers pushed off by their own jet (scripts/recoil.gd) — the scenes of
# tests/recoil_check.gd with the camera riding along with the container. Test saves only.
#   tools/run_test.sh tests/record_1110_recoil.gd --write-movie G:/temp/zp_rec_20261110/recoil.avi --fixed-fps 60

var kit: Node
var track = null
var cur_g: Node = null
var cap := ""
var zoom := 1.1
var cam := Vector2.INF
var hold := 120


func _initialize() -> void:
	SaveGame.path = "user://zp_test_rec1110_recoil_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_rec1110_recoil_career.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	kit.follow = _follow
	_run.call_deferred()


func _follow() -> void:
	var g = cur_g
	if g == null or not is_instance_valid(g):
		return
	if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()
	g.tutorial = null
	if track == null:
		return
	var at: Vector2 = track.body.global_position if track.body != null and is_instance_valid(track.body) else g.world.frame(track) * Geom.centroid(track.poly)
	cam = at if cam == Vector2.INF else cam.lerp(at, 0.12)
	g.cam_override = cam
	g.cam_pos = cam
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom
	g.zoom_override = zoom


func _game(ship: String):
	Txt.zh = true
	var g = await super(ship)
	cur_g = g
	track = null
	cam = Vector2.INF
	return g


func _shot(_g, _at: Vector2, _zoom: float, _name: String) -> void:
	pass


# no long venting on the record: the vessel let down to just under kpa at once
func _vent(g, port_id: String, kpa: float) -> float:
	var c = g.world.ctrls[port_id]
	var v := str(c.target)
	for i in 6:
		var p: float = g.sys.P(v)
		if p <= kpa:
			break
		g.sys.vols[v].n = float(g.sys.vols[v].n) * (kpa * 0.97) / p
		await physics_frame
	return g.sys.P(v)


func _loose(g, p, at: Vector2, turn := 0.0):
	var b = await super(g, p, at, turn)
	track = p
	cam = Vector2.INF
	_follow()
	await process_frame
	kit.keep(true, cap)
	return b


func _yank(g, p, dir: Vector2) -> bool:
	track = p
	cam = Vector2.INF
	g.drone.global_position = _centre(g, p) - dir * 2.0 * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	_follow()
	await _frames(20)
	kit.keep(true, cap)
	await _frames(70)
	return await super(g, p, dir)


func _done(g) -> void:
	await _frames(hold)
	kit.keep(false, "end")
	track = null
	cur_g = null
	await super(g)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	cap = "拽断瓶阀：气瓶被自己的喷流推走"
	zoom = 1.6
	await _s1()
	cap = "撞断瓶阀：撞上船壳后反向飞出"
	zoom = 1.2
	hold = 240
	await _s3()
	cap = "切开小口：从切口喷气，被推离切口"
	zoom = 1.6
	hold = 420
	await _s5()
	cap = "液罐漏液：液体喷出的反推"
	zoom = 1.5
	hold = 480
	await _s6()
	cap = "扯断接头：软管处喷气"
	zoom = 1.3
	hold = 300
	await _s8(false)
	print("recoil video: %d checks failed (the record is not a test)" % fails)
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	quit()
