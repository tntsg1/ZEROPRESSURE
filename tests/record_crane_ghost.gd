extends "res://tests/guide_check.gd"
# Crane ghost (user 2026-11-08): ~30 s for the owner — FR-26, T-1's LNG drawn off, the empty tank
# (7 t) unbolted inside its jacket ring; marked for the crane, it is lifted straight out through the
# ring and the hull and set into the receiving mouth. Own test saves only.
#   tools/run_test.sh tests/record_crane_ghost.gd --write-movie recordings/zeropressure_crane_ghost.avi --fixed-fps 30


func _initialize() -> void:
	Career.path = "user://zp_test_recghost_career.json"
	SaveGame.path = "user://zp_test_recghost_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fold() -> void:
	if g != null and g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()


var focus := Vector2.ZERO


# the view rides with the crane's hook (wide enough to show the ship and the mouth ahead)
func _cam() -> void:
	if g == null or g.crane == null: return
	var at: Vector2 = g.crane.pos if focus == Vector2.ZERO else focus
	g.cam_override = at + Vector2(0, 4.0 * Geom.M)
	g.zoom_override = 0.42


func _secs(s: float) -> void:
	for i in int(s * 30.0):
		_fold()
		_cam()
		await _frames(1)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "fr26"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": 1}}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	g.drone.global_position = Vector2(-10, -16) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	# T-1's LNG drawn off, its bolts and its pipe undone: an empty tank loose inside its jacket ring
	g.sys.set_fluid("lng1", 0.0)
	var t1 = g.world.tag("T-1")
	for j in g.world.joints_of(t1):
		g.world.kill_joint(j)
	for l in g.world.lines_of(t1):
		g.world.kill_line(l)
	g.world.make_body([t1], null)
	await _frames(5)
	var body = t1.body
	print("T-1 body %.1f t, mouth %s" % [body.total_mass(), g.crane._zone_for(body)])
	focus = body.global_position
	g.cam_pos = focus
	await _secs(2.5)
	focus = Vector2.ZERO
	var key: String = g.crane.toggle(body)
	print("crane: %s" % key)
	g.say(key, body.global_position + Vector2(0, -40))
	var reasons := {}
	var frames := 0
	while not t1.gone and frames < 30 * 75:
		if g.crane.wait_reason != "": reasons[g.crane.wait_reason] = true
		_fold()
		_cam()
		await _frames(1)
		frames += 1
		if frames % 90 == 0: print("  %.0fs state %s hook %s path %s body %s zone %s drop %s" % [frames/30.0, g.crane.state, str((g.crane.pos/Geom.M).round()), str(g.crane.path.size()), str((body.global_position/Geom.M).round()) if is_instance_valid(body) else "-", g.crane.zone, str((g.crane._drop_point(g.crane.zone)/Geom.M).round())])
	focus = g.crane.pos
	print("T-1 delivered=%s after %.1f s, wait reasons %s, income $%d" % [str(t1.gone), frames / 30.0, str(reasons.keys()), int(g.income_equip)])
	await _secs(2.5)
	quit()
