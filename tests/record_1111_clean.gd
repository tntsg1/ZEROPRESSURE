extends SceneTree
# Video (2026-11-11, 认真拆有奖励 first step): GR-7's machines into the equipment mouth — three empty ones
# in a row (clean ✓ ×1 ×2 ×3 and the streak chip), the charged battery (an arc, thrown out, drawn back),
# a gas bottle at 1.8 MPa (it flies on its own jet), a pump staged with water (a ball of it). Test saves only.
#   tools/run_test.sh tests/record_1111_clean.gd --write-movie G:/temp/zp_rec_20261110/clean1111.avi --fixed-fps 60
#   python tools/rec_1110.py cut clean_1111 - clean1111
const M := Geom.M
var g: Node
var kit: Node
var track = null
var cam := Vector2.INF
var zoom := 1.0
var hold_at := Vector2.INF


func _initialize() -> void:
	SaveGame.path = "user://zp_test_rec1111_clean_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_rec1111_clean_career.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	kit.follow = _follow
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _follow() -> void:
	if g == null or not is_instance_valid(g):
		return
	if g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()
	g.tutorial = null
	var at: Vector2 = hold_at
	if track != null and not track.gone and track.body != null and is_instance_valid(track.body):
		at = at.lerp(track.body.global_position, 0.55) if hold_at != Vector2.INF else track.body.global_position
	if at == Vector2.INF:
		return
	cam = at if cam == Vector2.INF else cam.lerp(at, 0.06)
	g.cam_override = cam
	g.cam_pos = cam
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom
	g.zoom_override = zoom


func _loose(p, at: Vector2, turn := 0.0):
	for l in g.world.lines_of(p).duplicate():
		g.world.kill_line(l, g.world.line_end_world(l, 0 if l.a == p.id else 1))
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	var w := 0
	while p.body == null and w < 30:
		await physics_frame
		w += 1
	var b = p.body
	if b == null:
		return null
	b.freeze = true
	b.global_position = at
	b.rotation = turn
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0
	b.reset_physics_interpolation()
	return b


func _go(b, v := Vector2.ZERO) -> void:
	b.freeze = false
	b.linear_velocity = v
	b.angular_velocity = 0.0


func _wait_gone(p, n: int) -> void:
	for i in n:
		await process_frame
		if p.gone:
			return


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "gr7"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	var face: Vector2 = Dock.ZONES.equip.face
	var mouth: Vector2 = Dock.zpos("equip")
	var side := Vector2(-face.y, face.x)
	g.drone.global_position = mouth + face * 9.0 * M + side * 6.0 * M
	g.drone.linear_velocity = Vector2.ZERO
	hold_at = mouth + face * 2.4 * M
	zoom = 2.6
	# the parts off the ship, parked out of the mouth's reach
	var park := mouth + face * 12.0 * M
	var names := ["CON-A", "BB-01", "ENV-B", "B-01", "TK-B1", "CP-E"]
	var bodies := {}
	var i := 0
	for t in names:
		var p = g.world.tag(t)
		if p == null:
			print("missing ", t)
			continue
		bodies[t] = await _loose(p, park + side * (i - 2.5) * 3.0 * M)
		i += 1
	# the pump, staged with water (GR-7 carries none): 0.25 m³ in it
	g.sys.fvol["demo_water"] = {"fluid": "water", "amount": 0.25, "piece": "CP-E", "full": 0.25}
	g.clean._snapshot()
	await _frames(60)
	kit.keep(true, "认真拆：干净送进设备口，叠连击")
	# three clean ones, one after the other
	for t in ["CON-A", "BB-01", "ENV-B"]:
		var b = bodies[t]
		b.global_position = mouth + face * 2.6 * M
		b.reset_physics_interpolation()
		_go(b, -face * 60.0)
		await _wait_gone(g.world.tag(t), 240)
		await _frames(40)
	await _frames(70)
	kit.keep(false)
	# the battery, still charged
	kit.keep(true, "电池没放电：电弧把它弹出来，泄完电再收")
	var bt = bodies["B-01"]
	bt.global_position = mouth + face * 2.6 * M
	bt.reset_physics_interpolation()
	_go(bt, -face * 60.0)
	track = g.world.tag("B-01")
	await _wait_gone(track, 600)
	await _frames(50)
	kit.keep(false)
	# the bottle at 1.8 MPa
	kit.keep(true, "气罐没泄压：喷着气满场乱窜")
	zoom = 1.5
	var gb = bodies["TK-B1"]
	gb.global_position = mouth + face * 2.8 * M
	gb.reset_physics_interpolation()
	_go(gb, -face * 60.0)
	track = g.world.tag("TK-B1")
	await _wait_gone(track, 900)
	await _frames(50)
	kit.keep(false)
	# the pump with water in it
	kit.keep(true, "泵里还有水：喷出一团液球")
	zoom = 2.4
	track = null
	var pb = bodies["CP-E"]
	pb.global_position = mouth + face * 2.6 * M
	pb.reset_physics_interpolation()
	_go(pb, -face * 60.0)
	track = g.world.tag("CP-E")
	await _wait_gone(track, 600)
	await _frames(90)
	kit.keep(false)
	print("REC clean=%d best=%d mishaps=%d bonus=%.0f grade=%s" % [g.clean.clean_n, g.clean.best, g.clean.mishaps.size(), g.clean.bonus_cash, g.clean.grade()])
	await _frames(10)
	quit(0)
