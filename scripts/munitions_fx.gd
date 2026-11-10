extends Node
# PT-34's rounds seen cooking and the magazine seen flooding — drawing only, scripts/munitions.gd
# keeps every number (图鉴 cx_m_munitions: "在弹药附近切割会持续加热弹药，直至弹药起爆；一发弹药
# 爆炸后，附近的弹药会接连殉爆"，"打开注水阀淹没弹库，使弹药报废").
#   A round the beam heats glows with its heat, dull red to orange; near its cook-off point it
#   flashes a warning and its casing shimmers. A round about to go off in a chain flares white
#   with sparks for the moment before it does. A flood valve opened: water spreads through the
#   magazine from the valve (free fall: a front of water, not a level) until the room is full,
#   bubbles drifting in it; the rounds in it wet, their casings sheened.

const Kit = preload("res://scripts/mech_fx_kit.gd")
const LC = preload("res://scripts/liquid_colors.gd")   # real liquid colours
const FLOOD_S := 3.2

var mu
var game
var world
var glow: Node2D
var water: Node2D
var _flood_t := {}            # room -> s since it was flooded (99 = before this run)
var _rounds: Array = []
var _sig := -1
var _t := 0.0


func setup(m) -> void:
	mu = m
	game = m.game
	world = m.world
	glow = Kit.node(world, true, _draw_glow)
	water = Kit.node(world, false, _draw_water)
	game.add_child(self)


func _process(dt: float) -> void:
	if mu == null or not mu.active() or game == null:
		return
	if not (game.paused_sim or game.state != "play"):
		_t += dt
	var sig: int = world.gone_n * 31 + world.order.size()
	if sig != _sig:
		_sig = sig
		_rounds.clear()
		for id in world.order:
			var p = world.pieces[id]
			if not p.gone and str(p.hazard) == "explosive":
				_rounds.append(p)
	for r in mu.flooded:
		if not _flood_t.has(r):
			# flooded before this run (a load): already full
			_flood_t[r] = 0.0 if _t > 0.5 else 99.0
		_flood_t[r] = float(_flood_t[r]) + dt
	# the round about to go off: sparks off it
	for e in mu.pending:
		var q = world.pieces.get(e[0])
		if q != null and not q.gone:
			var c: Vector2 = world.frame(q) * Geom.centroid(q.poly)
			game.fx.sparks(c, Vector2.UP, 3, Pal.heat(1.0, 2.6), 380.0, 0.35, PI)
	glow.queue_redraw()
	water.queue_redraw()


func _draw_glow() -> void:
	if mu == null or not mu.active():
		return
	var at: float = float(mu.cfg.get("cook", {}).get("at", mu.COOK_AT))
	var pend := {}
	for e in mu.pending:
		pend[e[0]] = true
	for p in _rounds:
		if p.gone or not mu.live(p):
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		var c := Geom.centroid(poly)
		var bb := Geom.bbox(poly)
		var r := maxf(bb.size.x, bb.size.y) * 0.6 + 6.0
		if pend.has(p.id):
			# about to go: white-hot
			Kit.disc(glow, c, r * 2.2, Color(1.0, 0.85, 0.6, 0.85))
			Kit.outline(glow, poly, Color(1.0, 0.9, 0.7, 1.0), 2.0)
			continue
		var k := clampf((float(p.temp) - 30.0) / maxf(1.0, at - 30.0), 0.0, 1.0)
		if k <= 0.01:
			continue
		var col := Kit.hot(k)
		var fl := 0.85 + 0.15 * sin(_t * 9.0 + c.x)
		# the casing itself glowing, a halo only once it is really hot
		Kit.fill(glow, poly, Color(col.r, col.g, col.b, (0.08 + 0.45 * k) * fl))
		if k > 0.45:
			Kit.disc(glow, c, r * 0.9, Color(col.r, col.g, col.b, 0.35 * (k - 0.45) / 0.55 * fl))
		Kit.outline(glow, poly, Color(col.r, col.g, col.b, 0.3 + 0.6 * k), 1.4)
		# close to cooking off: a warning flashing faster and faster
		if k > 0.7:
			var rate := lerpf(3.0, 12.0, (k - 0.7) / 0.3)
			if fmod(_t * rate, 1.0) < 0.5:
				Kit.ring(glow, c, r * 1.6, Pal.heat(0.8, 1.6), 1.6)


func _draw_water() -> void:
	if mu == null or not mu.active():
		return
	for room in _flood_t:
		var rp := Kit.room_poly(world, room)
		if rp.size() < 3:
			continue
		var f := clampf(float(_flood_t[room]) / FLOOD_S, 0.0, 1.0)
		var from := Geom.centroid(rp)
		for cid in mu.cfg.get("flood", {}):
			if str(mu.cfg.flood[cid]) == room and world.ctrls.has(cid):
				from = world.ctrl_world(world.ctrls[cid])
		var col := Pal.tint(LC.of("water"), 0.16 + 0.06 * sin(_t * 1.3), 0.8)
		for q in Kit.room_fill(rp, from, Pal.ease_out(f), _t):
			Kit.fill(water, q, col)
			Kit.outline(water, q, Pal.tint(LC.of("water"), 0.55 if f < 1.0 else 0.25, 1.2), 1.2 if f < 1.0 else 1.0)
		# bubbles drifting in it
		var bb := Geom.bbox(rp)
		for i in 10:
			var u := fposmod(_t * 0.12 + i * 0.137, 1.0)
			var p := bb.position + Vector2(bb.size.x * fposmod(i * 0.61 + 0.1, 1.0) + sin(_t * 0.7 + i) * 8.0, bb.size.y * (1.0 - u))
			if Geometry2D.is_point_in_polygon(p, rp) and p.distance_to(from) < bb.size.length() * f:
				water.draw_arc(p, 2.0 + (i % 3), 0.0, TAU, 10, Pal.tint(LC.of("water"), 0.5, 1.3), 1.0)
		# the rounds in it wet: a sheen on their casings
		if f >= 1.0:
			for p in _rounds:
				if not p.gone and mu.wet.has(p.id) and p.room == room:
					Kit.outline(water, world.world_poly(p), Pal.tint(LC.of("water"), 0.45, 1.2), 1.0)
