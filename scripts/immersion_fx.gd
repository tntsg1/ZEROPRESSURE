extends Node
# DC-84's racks seen standing in their coolant — drawing only, scripts/immersion.gd keeps every
# number (图鉴 cx_m_immersion: "十二个机柜分别安装在装有绝缘冷却液的液槽中"，"先通过每个液槽的接口抽干
# 冷却液"，"在失重环境中，洒出的液体会形成液团，并漂向相邻机柜").
#   Each rack's tank shows the dielectric round it, faintly tinted, a few motes drifting in it.
#   Drawn down at its port: in free fall the liquid keeps to the walls, so a bubble of gas opens
#   in the middle of the tank and grows as it empties (its area what has been drawn off), the
#   liquid running out toward the port. Empty, the rack stands dry. (The spill when a full one is
#   lifted is liquids.gd's globules, as before.)

const Kit = preload("res://scripts/mech_fx_kit.gd")
const LC = preload("res://scripts/liquid_colors.gd")   # real liquid colours

var im
var game
var world
var node: Node2D
var _full := {}               # vol -> the most it has held
var _was := {}
var _flow := {}
var _t := 0.0


func setup(m) -> void:
	im = m
	game = m.game
	world = m.world
	node = Kit.node(world, false, _draw)
	game.add_child(self)


func _process(dt: float) -> void:
	if im == null or not im.active() or game == null:
		return
	if not (game.paused_sim or game.state != "play"):
		_t += dt
	for rack in im.cfg.get("tanks", {}):
		var vk := str(im.cfg.tanks[rack].get("vol", ""))
		var now: float = game.sys.fluid(vk)
		_full[vk] = maxf(float(_full.get(vk, 0.0)), now)
		var drawn := float(_was.get(vk, now)) - now
		_was[vk] = now
		_flow[vk] = Pal.damp(float(_flow.get(vk, 0.0)), 1.0 if drawn > 0.000001 else 0.0, 3.0, dt)
	node.queue_redraw()


func _draw() -> void:
	if im == null or not im.active():
		return
	for rack in im.cfg.get("tanks", {}):
		var p = world.tag(rack)
		if p == null or p.gone or p.body != null:
			continue
		var vk := str(im.cfg.tanks[rack].get("vol", ""))
		var full: float = float(_full.get(vk, 0.0))
		if full <= 0.0:
			continue
		var f := clampf(game.sys.fluid(vk) / full, 0.0, 1.0)
		if f <= 0.01:
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		var bb := Geom.bbox(poly)
		var c := bb.get_center()
		var col := Pal.tint(LC.of("glycol"), 0.10 + 0.08 * f, 0.9)
		var parts: Array = [poly]
		if f < 0.995:
			# the gas the draining has let in: a bubble in the middle, its area what is gone
			var a := Geom.area(poly) * (1.0 - f)
			var r := sqrt(a / PI)
			var bub := Kit.blob(c, r, _t * 0.6, 0.05, 28)
			var sx := bb.size.x / maxf(1.0, maxf(bb.size.x, bb.size.y))
			var sy := bb.size.y / maxf(1.0, maxf(bb.size.x, bb.size.y))
			for i in bub.size():
				var d := bub[i] - c
				bub[i] = c + Vector2(d.x * sqrt(sx / sy), d.y * sqrt(sy / sx))
			# a hairline slit from the bubble to the tank's top edge: the clip then leaves one
			# outline (a bubble wholly inside comes back as an outline and a hole)
			var slit := PackedVector2Array([c + Vector2(-0.6, 0.0), c + Vector2(0.6, 0.0), Vector2(c.x + 0.6, bb.position.y - 4.0), Vector2(c.x - 0.6, bb.position.y - 4.0)])
			var cut: Array = Geometry2D.merge_polygons(bub, slit)
			parts = Geometry2D.clip_polygons(poly, cut[0]) if not cut.is_empty() else [poly]
			# the liquid's surface round the bubble, only where it is in the tank
			var ring := bub.duplicate()
			ring.append(bub[0])
			for seg in Geometry2D.intersect_polyline_with_polygon(ring, poly):
				node.draw_polyline(seg, Pal.tint(LC.of("glycol"), 0.45, 1.2), 1.0)
		for q in parts:
			if not Geometry2D.is_polygon_clockwise(q) == Geometry2D.is_polygon_clockwise(poly):
				continue
			Kit.fill(node, q, col)
		# motes drifting in the liquid
		for i in 5:
			var mp := c + Vector2(sin(_t * 0.4 + i * 1.9) * bb.size.x * 0.4, cos(_t * 0.33 + i * 2.7) * bb.size.y * 0.42)
			if f >= 0.995 or mp.distance_to(c) > sqrt(Geom.area(poly) * (1.0 - f) / PI) + 3.0:
				node.draw_rect(Rect2(mp - Vector2(1, 1), Vector2(2, 2)), Pal.tint(LC.of("glycol"), 0.5, 1.2))
		# drawing down: the liquid running to the tank's port
		var fl: float = float(_flow.get(vk, 0.0))
		if fl > 0.05:
			var port := Vector2.INF
			for cid in world.ctrls:
				var cc = world.ctrls[cid]
				if cc.kind == "port" and str(cc.target) == vk:
					port = world.ctrl_world(cc)
			if port != Vector2.INF:
				for k in 4:
					var u := fposmod(_t * 1.2 + k * 0.25, 1.0)
					node.draw_circle(c.lerp(port, u), 2.5, Pal.tint(LC.of("glycol"), 0.7 * fl * (1.0 - u * 0.5), 1.3))
