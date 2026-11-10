extends Node2D
# MF-126's furnace core seen hot — drawing only, scripts/furnace.gd keeps every number
# (design/机制动画缺口_20261110.md: "760 °C and only a probe knows").
#   The core glows with its temperature (the same colours as EV-55's hull, thermal_fx.gd):
#   bright through its middle, its edges cooler; with the heat exchange running a cold
#   shimmer runs round its edges as the loop draws the heat off. Cracked by thermal
#   shock, the cracks glow through it.

const ThermalFx = preload("res://scripts/thermal_fx.gd")

var fu
var game
var world
var _t := 0.0
var _cracks := PackedVector2Array()


func setup(f) -> void:
	fu = f
	game = f.game
	world = f.world
	z_index = 4
	z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	world.add_child(self)


func _process(dt: float) -> void:
	if fu == null or not fu.active() or game == null:
		return
	if not (game.paused_sim or game.state != "play"):
		_t += dt
	queue_redraw()


func _draw() -> void:
	var p = world.tag(str(fu.cfg.get("core", "")))
	if p == null or p.gone:
		return
	var k := ThermalFx.glow_k(fu.T)
	if k <= 0.001:
		return
	draw_set_transform_matrix(world.frame(p))
	var poly: PackedVector2Array = p.poly
	var c := Geom.centroid(poly)
	var col := ThermalFx.glow_col(k)
	var fl := 0.9 + 0.1 * sin(_t * 1.3) * sin(_t * 2.9)
	# the body: a soft glow through its middle, fading out toward its walls
	var bb := Geom.bbox(poly)
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([Color(col.r, col.g * 1.2, col.b, (0.22 + 0.42 * k) * fl)])
	var idx := PackedInt32Array()
	var n := poly.size()
	var m := 28
	for i in m:
		var d := Vector2.from_angle(TAU * i / m)
		pts.append(c + Vector2(d.x * bb.size.x * 0.46, d.y * bb.size.y * 0.42))
		cols.append(Color(col.r, col.g, col.b, 0.0))
	for i in m:
		idx.append_array([0, 1 + i, 1 + (i + 1) % m])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	# its outline: the heat leaving it
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(col.r, col.g, col.b, 0.12 + 0.3 * k), 1.2)
	# the loop drawing the heat off: a cold shimmer running round the edge
	if fu.cooling():
		var L := 0.0
		for i in n:
			L += poly[i].distance_to(poly[(i + 1) % n])
		for s in 4:
			var at := fposmod(_t * 0.18 + s * 0.25, 1.0) * L
			var acc := 0.0
			for i in n:
				var a := poly[i]
				var b := poly[(i + 1) % n]
				var d := a.distance_to(b)
				if at <= acc + d:
					var q := a.lerp(b, (at - acc) / maxf(d, 0.001))
					var dir := (b - a).normalized()
					draw_line(q - dir * 28.0, q + dir * 28.0, Pal.tint(Pal.AIR, 0.5, 1.2), 1.6)
					break
				acc += d
	# cracked by the shock: the cracks glowing through it
	if fu.cracked:
		if _cracks.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = 126
			for j in 6:
				var cur := c + Vector2(rng.randf_range(-0.2, 0.2) * bb.size.x, rng.randf_range(-0.2, 0.2) * bb.size.y)
				var dir := Vector2.from_angle(rng.randf() * TAU)
				for s in 6:
					var nx := cur + dir.rotated(rng.randf_range(-0.5, 0.5)) * rng.randf_range(10.0, 26.0)
					if not Geometry2D.is_point_in_polygon(nx, poly):
						break
					_cracks.append(cur)
					_cracks.append(nx)
					cur = nx
		draw_multiline(_cracks, Color(1.0, 0.75, 0.3, 0.4 + 0.5 * k), 1.3)
	draw_set_transform_matrix(Transform2D.IDENTITY)
