extends Node2D
# 128 号 第 6 段 (user 2026-11-07): F12 开发者工作台 → “显示碰撞”。Every shape the drone can
# bump into is laid over the port in a translucent colour by what it is, so the art can be held
# against the real collision: what is drawn solid but lets the drone through, what looks empty
# but stops it. A dev view only — it draws, it never changes a body.
#   cyan     港区墙、设备外壳（层 4）
#   magenta  加工区观察廊等只挡无人机的墙（层 16）
#   amber    泊位里挂着的船（层 8）
#   green    其他会动的东西：零件、拖船、货箱、吊车……（层 1）

static var on := false

var game
var _bodies: Array = []
var _scan := 0.0
var _legend: CanvasLayer


# the view in this game (made the first time it is asked for)
static func ensure(g) -> Node2D:
	if g == null or not is_instance_valid(g):
		return null
	var v = g.get_node_or_null("CollisionView")
	if v == null:
		v = load("res://scripts/collision_view.gd").new()
		v.name = "CollisionView"
		v.game = g
		g.add_child(v)
	return v


const COLS := {4: Color(0.2, 0.95, 1.0), 16: Color(1.0, 0.3, 0.95), 8: Color(1.0, 0.75, 0.2), 1: Color(0.4, 1.0, 0.45)}


# the shapes are drawn on their own layer that follows the camera: above every district's art
# (some draw on layers of their own), under the drone-feed OSD
var _layer: CanvasLayer
var _pen: Node2D


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 19
	_layer.follow_viewport_enabled = true
	add_child(_layer)
	_pen = Node2D.new()
	_pen.draw.connect(_paint)
	_layer.add_child(_pen)
	_legend = CanvasLayer.new()
	_legend.layer = 120
	add_child(_legend)
	var l := Label.new()
	l.name = "Legend"
	l.position = Vector2(24, 900)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.text = "显示碰撞（F12 工作台）\n青  港区墙 / 设备外壳\n品红  只挡无人机的墙\n琥珀  泊位里的船\n绿  零件 / 拖船 / 货箱等会动的东西\n橙虚线  船坞牵引力场：只拦零件，无人机不受"
	_legend.add_child(l)


func _mask() -> int:
	if game != null and game.get("drone") != null and is_instance_valid(game.drone):
		return int(game.drone.collision_mask)
	return 1 | 4 | 8 | 16


func _drone_layer() -> int:
	if game != null and game.get("drone") != null and is_instance_valid(game.drone):
		return int(game.drone.collision_layer)
	return 2


# every body the drone can touch now (the drone's own body left out)
func bodies() -> Array:
	var out: Array = []
	var mask := _mask()
	var dl := _drone_layer()
	for b in get_tree().root.find_children("*", "PhysicsBody2D", true, false):
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if game != null and b == game.get("drone"):
			continue
		if b.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if (int(b.collision_layer) & mask) == 0 and (int(b.collision_mask) & dl) == 0:
			continue
		out.append(b)
	return out


func _colour(b: PhysicsBody2D) -> Color:
	var l := int(b.collision_layer)
	for k in [4, 16, 8, 1]:
		if l & k:
			return COLS[k]
	return Color(1, 1, 1)


func _process(dt: float) -> void:
	visible = on
	if _layer != null:
		_layer.visible = on
	if _legend != null:
		_legend.visible = on
	if not on:
		_bodies = []
		_scan = 0.0
		return
	_scan -= dt
	if _scan <= 0.0 or _bodies.is_empty():
		_scan = 0.5
		_bodies = bodies()
	_pen.queue_redraw()


func _paint() -> void:
	if not on:
		return
	var z: float = maxf(game.cam_zoom(), 0.02) if game != null and game.has_method("cam_zoom") else 1.0
	for b in _bodies:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		var col := _colour(b)
		for s in b.get_children():
			if s is CollisionShape2D and not s.disabled and s.shape != null:
				_shape(s.global_transform, s.shape, col, z)
			elif s is CollisionPolygon2D and not s.disabled and s.polygon.size() >= 2:
				_poly(s.global_transform, s.polygon, col, z, s.build_mode == CollisionPolygon2D.BUILD_SEGMENTS)
	# 128 号 第 6 段追加: the berth's tractor field is no shape but it stops the pieces (only them): its
	# box as an orange dashed line, so nothing that stops a piece is left unseen
	if game != null and game.get("dock") != null and is_instance_valid(game.dock) and game.dock.visible:
		var fr: Rect2 = Dock.field_rect()
		_pen.draw_set_transform_matrix(game.dock.get_global_transform())
		var oc := Color(1.0, 0.55, 0.12, 0.9)
		var corners := [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var n := int(a.distance_to(b) / 24.0)
			for k in n:
				if k % 2 == 0:
					_pen.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), oc, 2.5 / z)
	_pen.draw_set_transform_matrix(Transform2D.IDENTITY)


func _shape(xf: Transform2D, sh: Shape2D, col: Color, z: float) -> void:
	_pen.draw_set_transform_matrix(xf)
	var sc := maxf(xf.get_scale().x, 0.001)
	var lw := 3.0 / z / sc
	var fill := Color(col, 0.28)
	var edge := Color(col, 0.95)
	if sh is RectangleShape2D:
		var r := Rect2(-sh.size * 0.5, sh.size)
		_pen.draw_rect(r, fill)
		_pen.draw_rect(r, edge, false, lw)
	elif sh is CircleShape2D:
		_pen.draw_circle(Vector2.ZERO, sh.radius, fill)
		_pen.draw_arc(Vector2.ZERO, sh.radius, 0.0, TAU, 32, edge, lw)
	elif sh is CapsuleShape2D:
		var r: float = sh.radius
		var h: float = maxf(sh.height * 0.5 - r, 0.0)
		_pen.draw_rect(Rect2(-r, -h, 2.0 * r, 2.0 * h), fill)
		_pen.draw_circle(Vector2(0, -h), r, fill)
		_pen.draw_circle(Vector2(0, h), r, fill)
		_pen.draw_arc(Vector2(0, -h), r, PI, TAU, 16, edge, lw)
		_pen.draw_arc(Vector2(0, h), r, 0.0, PI, 16, edge, lw)
		_pen.draw_line(Vector2(-r, -h), Vector2(-r, h), edge, lw)
		_pen.draw_line(Vector2(r, -h), Vector2(r, h), edge, lw)
	elif sh is SegmentShape2D:
		_pen.draw_line(sh.a, sh.b, edge, lw * 2.0)
	elif sh is ConvexPolygonShape2D:
		_outline(sh.points, fill, edge, lw, true)
	elif sh is ConcavePolygonShape2D:
		var seg: PackedVector2Array = sh.segments
		for i in range(0, seg.size() - 1, 2):
			_pen.draw_line(seg[i], seg[i + 1], edge, lw * 2.0)
	elif sh is WorldBoundaryShape2D:
		var n: Vector2 = sh.normal
		var p: Vector2 = n * sh.distance
		_pen.draw_line(p - n.orthogonal() * 1e5, p + n.orthogonal() * 1e5, edge, lw * 2.0)


func _poly(xf: Transform2D, pts: PackedVector2Array, col: Color, z: float, segments: bool) -> void:
	_pen.draw_set_transform_matrix(xf)
	var lw := 2.0 / z / maxf(xf.get_scale().x, 0.001)
	if segments:
		for i in pts.size() - 1:
			_pen.draw_line(pts[i], pts[i + 1], Color(col, 0.95), lw * 2.0)
	else:
		_outline(pts, Color(col, 0.28), Color(col, 0.95), lw, true)


func _outline(pts: PackedVector2Array, fill: Color, edge: Color, lw: float, closed: bool) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		_pen.draw_colored_polygon(pts, fill)
	for i in pts.size():
		if i == pts.size() - 1 and not closed:
			break
		_pen.draw_line(pts[i], pts[(i + 1) % pts.size()], edge, lw)
