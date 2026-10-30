extends RefCounted
# The liquid layer's small polygons and strokes, in their original draw order,
# submitted as one triangle array. Widths, arc samples and clamped miter joins
# match Godot's non-antialiased canvas primitives; viewport MSAA still applies.
var vertices := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

func flush(node: CanvasItem) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), indices, vertices, colors)

func draw_colored_polygon(points: PackedVector2Array, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(points)
	if tris.is_empty(): return
	var base := vertices.size()
	vertices.append_array(points)
	for i in points.size(): colors.append(col)
	for i in tris: indices.append(base + i)

func _join(next: Vector2, prev: Vector2) -> Vector2:
	var bisector := (prev * next.length() - next * prev.length()).normalized()
	var sine := sin(atan2(bisector.cross(prev), bisector.dot(prev)))
	var length := 1.0
	if not is_zero_approx(sine) and not next.is_equal_approx(prev):
		length = clampf(1.0 / sine, -3.0, 3.0)
	else:
		bisector = next.orthogonal()
	if bisector.is_zero_approx(): bisector = next.orthogonal()
	return bisector * length

func draw_polyline(points: PackedVector2Array, col: Color, width: float, _aa: bool = false) -> void:
	if points.size() < 2: return
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	for i in range(1, points.size()):
		first = (points[i] - points[i - 1]).normalized()
		if not first.is_zero_approx(): break
	for i in range(points.size() - 1, 0, -1):
		last = (points[i] - points[i - 1]).normalized()
		if not last.is_zero_approx(): break
	var loop := points[0].is_equal_approx(points[-1])
	var prev := Vector2.ZERO
	var base := vertices.size()
	for i in points.size():
		var direction := prev if i == points.size() - 1 else (points[i + 1] - points[i]).normalized()
		if direction.is_zero_approx(): direction = prev
		if i == 0 and loop: prev = last
		elif i == points.size() - 1 and loop: prev = first
		var offset: Vector2
		if i == 0 and not loop: offset = first.orthogonal()
		elif i == points.size() - 1 and not loop: offset = last.orthogonal()
		else: offset = _join(direction, prev)
		offset *= width * 0.5
		vertices.append(points[i] + offset)
		vertices.append(points[i] - offset)
		colors.append(col)
		colors.append(col)
		if i > 0:
			var k := base + i * 2
			indices.append_array([k - 2, k - 1, k, k, k - 1, k + 1])
		prev = direction

func draw_line(a: Vector2, b: Vector2, col: Color, width: float, aa: bool = false) -> void:
	draw_polyline(PackedVector2Array([a, b]), col, width, aa)

func draw_arc(center: Vector2, radius: float, start: float, end: float, count: int, col: Color, width: float, aa: bool = false) -> void:
	var points := PackedVector2Array()
	for i in count:
		points.append(center + Vector2.from_angle(lerpf(start, end, float(i) / (count - 1))) * radius)
	draw_polyline(points, col, width, aa)

func draw_rect(rect: Rect2, col: Color) -> void:
	var a := rect.position
	var b := rect.end
	var base := vertices.size()
	vertices.append_array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
	for i in 4: colors.append(col)
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
