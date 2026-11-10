extends Node
# TB-180 seen turning — drawing only, scripts/tether.gd keeps every number and the ship stays where
# the game has it (图鉴 cx_m_tether: "两个吊舱由系绳连接，整体以 2.0 rpm 的速度旋转，张紧器还提供 8 kN
# 的额外张力"，"旋转时切断系绳，两个吊舱会沿切线方向甩出。如果不打开冷却就制动，滚轮在 6 秒后会
# 打滑"，"制动失效时，需要使用 B 舱的姿态控制系统反向喷射"，"系绳张力 = 40 kN × (rpm/2)² + 张紧器
# 提供的 8 kN"，"磨损段只剩 5/7 股").
#   The view turns with the pair (Jev 0.88: a co-rotating frame — what is drawn is where it is cut):
#   everything past the berth — stars, planet, port — wheels round the screen the other way at
#   the pair's rpm and visibly slows as the brake takes it off; at rest it holds still. On the ship:
#   the pods trail speed lines along their tangent; the tether hums, a standing wave on it as tight
#   as its pull; the worn segment's broken strands fray out of it. Braking: the rollers turn and
#   glow, dry they smoke and spark more as they heat toward slipping; slipped, they spin free with
#   a screech of sparks. The RCS firing: B pod's quads jet against the spin. Cut while turning: the
#   two halves of the tether lash out and the pods' speed lines streak off along the tangent.

const Kit = preload("res://scripts/mech_fx_kit.gd")

var te
var game
var world
var node: Node2D
var glow: Node2D
var ang := 0.0                # rad the outside has turned (the view's rotation)
var _roll := 0.0
var _thrown_t := -1.0
var _was_thrown := false
var _was_snapped := false
var _seg_line := PackedVector2Array()
var _hub := Vector2.ZERO
var _t := 0.0


func setup(t) -> void:
	te = t
	game = t.game
	world = t.world
	node = Kit.node(world, false, _draw)
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)
	_was_thrown = te.thrown
	_was_snapped = te.snapped
	var segs: Array = te.cfg.get("segments", [])
	var a := Vector2.INF
	var b := Vector2.INF
	for s in segs:
		var p = world.tag(str(s))
		if p == null:
			continue
		var bb := Geom.bbox(p.poly)
		if a == Vector2.INF or bb.position.x < a.x:
			a = Vector2(bb.position.x, bb.get_center().y)
		if b == Vector2.INF or bb.end.x > b.x:
			b = Vector2(bb.end.x, bb.get_center().y)
	if a != Vector2.INF:
		_seg_line = PackedVector2Array([a, b])
		_hub = (a + b) * 0.5


func _w() -> float:
	return te.rpm * TAU / 60.0 if not te.thrown else 0.0


func _process(dt: float) -> void:
	if te == null or not te.active() or game == null:
		return
	if not (game.paused_sim or game.state != "play"):
		_t += dt
		ang -= _w() * dt
		var braking: bool = game.sys.on(str(te.cfg.get("brake", {}).get("switch", ""))) and te.rpm > 0.0
		_roll += (_w() * 40.0) * dt * (1.0 if braking or te.slipped else 0.3)
		if braking and fmod(_t, 0.08) < dt:
			var cool: bool = game.sys.on(str(te.cfg.brake.get("cool", "")))
			for r in te.cfg.brake.get("rollers", []):
				var q = world.tag(str(r))
				if q == null or q.gone:
					continue
				var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
				if te.slipped:
					game.fx.sparks(at, Vector2.RIGHT, 2, Pal.heat(1.0, 2.4), 300.0, 0.3, 0.6)
				elif not cool and te.heat > 1.0:
					game.fx.puff(at, Vector2(0, -30), 1.4, 4.0, 18.0 + 4.0 * te.heat, Pal.ink(0.12 + 0.03 * te.heat))
					if te.heat > 3.0 and randf() < 0.4:
						game.fx.sparks(at, Vector2.RIGHT, 1, Pal.heat(1.0, 2.0), 200.0, 0.25, 0.8)
				elif cool:
					game.fx.puff(at, Vector2(0, -20), 1.0, 3.0, 12.0, Pal.tint(Pal.AIR, 0.15, 1.0))
		# the RCS jetting against the spin
		var rc: Dictionary = te.cfg.get("rcs", {})
		if game.sys.on(str(rc.get("switch", ""))) and te.rpm > 0.0 and te.rcs_ready() and fmod(_t, 0.04) < dt:
			for qt in ["RCS-1", "RCS-2"]:
				var q2 = world.tag(qt)
				if q2 != null and not q2.gone:
					var at2: Vector2 = world.frame(q2) * Geom.centroid(q2.poly)
					var out := Vector2(0.0, signf(at2.y - _hub.y))
					game.fx.puff(at2, out * 260.0 + Vector2(randf_range(-20, 20), 0), 0.5, 3.0, 22.0, Color(1.0, 0.8, 0.55, 0.5))
	if te.thrown and not _was_thrown:
		_thrown_t = 0.0
		if world.rope_fx != null and _seg_line.size() == 2:
			var cut: Vector2 = game.tools.front if game.tools != null else _hub
			var p0 := PackedVector2Array([_seg_line[0] + Vector2(0, -3), _seg_line[1] + Vector2(0, -3), _seg_line[1] + Vector2(0, 3), _seg_line[0] + Vector2(0, 3)])
			world.rope_fx.snap_member(p0, cut, 1.0)
	_was_thrown = te.thrown
	if _thrown_t >= 0.0:
		_thrown_t += dt
	# the outside turning with us
	var bd = game.get("backdrop")
	if bd != null and game.cam != null:
		var c: Vector2 = game.cam.position
		bd.transform = Transform2D(ang, c) * Transform2D(0.0, -c)
	node.queue_redraw()
	glow.queue_redraw()


func _exit_tree() -> void:
	var bd = game.get("backdrop") if game != null else null
	if bd != null and is_instance_valid(bd):
		bd.transform = Transform2D.IDENTITY


func _draw() -> void:
	if te == null or not te.active() or _seg_line.size() != 2:
		return
	var a := _seg_line[0]
	var b := _seg_line[1]
	var L := a.distance_to(b)
	# the tether humming: a standing wave on it, as tight as its pull (stiffer = faster, smaller)
	var pull: float = te.pull()
	if pull > 0.5 and not te.snapped:
		var amp := clampf(pull / 48.0, 0.0, 1.0) * 3.0
		var pts := PackedVector2Array()
		var n := 60
		for i in n + 1:
			var u := float(i) / n
			var y := sin(u * PI * 7.0) * sin(_t * (18.0 + pull * 0.3)) * amp
			pts.append(a.lerp(b, u) + Vector2(0.0, y))
		node.draw_polyline(pts, Pal.ink(0.25 + 0.3 * clampf(pull / 48.0, 0.0, 1.0)), 1.0)
	# the worn segment's broken strands
	var w = world.tag(str(te.cfg.get("worn", "")))
	if w != null and not w.gone and not te.snapped:
		var bb := Geom.bbox(w.poly)
		var st: Array = te.cfg.get("strands", [7, 7])
		var broken := int(st[1]) - int(st[0])
		for k in broken * 3:
			var x := bb.position.x + bb.size.x * (0.3 + 0.12 * k)
			var side := 1.0 if k % 2 == 0 else -1.0
			var tip := Vector2(x + 10.0, bb.get_center().y + side * (8.0 + 3.0 * sin(_t * 6.0 + k)))
			node.draw_line(Vector2(x, bb.get_center().y + side * 2.0), tip, Pal.ink(0.55), 1.0)
	# the brake's rollers turning
	for r in te.cfg.get("brake", {}).get("rollers", []):
		var q = world.tag(str(r))
		if q == null or q.gone:
			continue
		var c: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		var rad := maxf(4.0, Geom.bbox(q.poly).size.x * 0.45)
		for s in 3:
			var aa := _roll + s * TAU / 3.0
			node.draw_line(c, c + Vector2.from_angle(aa) * rad, Pal.ink(0.6), 1.0)
	# the pods' speed: lines trailing along their tangent, as fast as the spin
	var sp := clampf(te.rpm / 2.0, 0.0, 1.0)
	if sp > 0.01 and not te.thrown:
		for e0 in [a, b]:
			var end: Vector2 = e0
			var r := end - _hub
			var tang := r.orthogonal().normalized() * signf(-_w())
			for k in 7:
				var off := Vector2(0.0, (k - 3) * 22.0) + r.normalized() * (12.0 + 8.0 * (k % 3))
				var u := fposmod(_t * 2.0 + k * 0.37, 1.0)
				var p0: Vector2 = end + off
				var ln := (80.0 + 220.0 * sp) * (0.4 + 0.6 * u)
				node.draw_line(p0 - tang * ln * 0.2, p0 - tang * ln, Pal.ink(0.2 + 0.4 * sp * (1.0 - u)), 1.3)
	# thrown: the pods' last speed streaking off along their tangents
	if _thrown_t >= 0.0 and _thrown_t < 1.2:
		var k2 := 1.0 - _thrown_t / 1.2
		for e1 in [a, b]:
			var end: Vector2 = e1
			var r2 := end - _hub
			var tg := r2.orthogonal().normalized()
			for m in 5:
				var o := Vector2(0.0, (m - 2) * 30.0)
				node.draw_line(end + o, end + o + tg * 300.0 * _thrown_t * (1.0 if m % 2 == 0 else -1.0), Pal.ink(0.7 * k2), 1.4)


func _draw_glow() -> void:
	if te == null or not te.active():
		return
	var b: Dictionary = te.cfg.get("brake", {})
	var braking: bool = game.sys.on(str(b.get("switch", ""))) and te.rpm > 0.0
	var hk := clampf(te.heat / float(b.get("slip", 6.0)), 0.0, 1.0)
	for r in b.get("rollers", []):
		var q = world.tag(str(r))
		if q == null or q.gone:
			continue
		var c: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		if hk > 0.02 or braking:
			Kit.disc(glow, c, 14.0 + 16.0 * hk, Pal.heat(0.12 + 0.4 * hk, 1.0 + 1.2 * hk))
	# the tension in the line: it brightens with the pull (the formula's 40 kN × (rpm/2)² + 8)
	var pull: float = te.pull()
	if pull > 0.5 and not te.snapped and _seg_line.size() == 2:
		var k := clampf(pull / 48.0, 0.0, 1.0)
		glow.draw_line(_seg_line[0], _seg_line[1], Pal.tint(Pal.AIR, 0.12 + 0.25 * k * (0.85 + 0.15 * sin(_t * 30.0)), 1.1), 1.4)
