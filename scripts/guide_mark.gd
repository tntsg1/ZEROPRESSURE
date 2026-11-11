extends RefCounted
# How the guides show the way (user 2026-10-28: "这个箭头太难看了…右上角这几个箭头、引导，也很难看";
# Q: keep an arrow from the drone, but thinner and quieter). One drawing for the belt prologue,
# the first ship and the port walk, in the world, every size fixed on the screen whatever the zoom:
#   target  four thin corner brackets round the spot, breathing a little, a dot at its heart; the
#           name beside it on a short leader, outlined instead of boxed
#   arrow   from just off the drone toward the target: a hairline that fades in, a slim solid head
# Callers pass the canvas item, the camera zoom and the guide's colour.
const FastDraw = preload("res://scripts/fast_draw.gd")


# r: the brackets' half-size on the screen (px); t: the guide's clock; big: >1 when the player is stuck
static func target(ci: CanvasItem, at: Vector2, z: float, col: Color, t: float, label: String = "", r: float = 26.0, big: float = 1.0) -> void:
	var s := 1.0 / maxf(z, 0.02)
	var breathe := 0.5 + 0.5 * sin(t * 3.2)
	var h := (r + 4.0 * breathe) * big * s
	var arm := minf(11.0 * s, h * 0.6)
	var w := 1.6 * s
	var c := Color(col.r, col.g, col.b, 0.75 + 0.25 * breathe)
	var shade := Color(0, 0, 0, 0.45)
	var segs := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = at + corner * h
		segs.append_array([p, p - Vector2(corner.x * arm, 0.0), p, p - Vector2(0.0, corner.y * arm)])
	# a dark edge under the light one: it reads on bright plates as well as on the dark
	ci.draw_multiline(segs, shade, w + 2.0 * s)
	ci.draw_multiline(segs, c, w)
	FastDraw.circle(ci, at, 2.6 * s, shade)
	FastDraw.circle(ci, at, 1.6 * s, c)
	if label == "":
		return
	var font: Font = Fonts.get_font("Medium")
	var fs := 15
	var lead0 := at + Vector2(h, -h)
	var lead1 := lead0 + Vector2(10.0, -10.0) * s
	ci.draw_line(lead0, lead1, Color(c, 0.6), 1.0 * s)
	var lp := lead1 + Vector2(4.0, 4.0) * s
	ci.draw_set_transform(lp, 0.0, Vector2(s, s))
	ci.draw_string_outline(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.02, 0.022, 0.028, 0.85))
	ci.draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.95))
	ci.draw_set_transform(Vector2.ZERO)


# from: where the drone is drawn; shown only while the target is farther than near_px on the screen
static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, z: float, col: Color, t: float, near_px: float = 160.0) -> void:
	var s := 1.0 / maxf(z, 0.02)
	var d := to - from
	if d.length() < near_px * s:
		return
	var dir := d.normalized()
	var side := dir.orthogonal()
	var start := from + dir * 34.0 * s
	var tip := from + dir * 96.0 * s
	var head := 13.0 * s
	var base := tip - dir * head
	# the shaft: a hairline that fades in from the drone, a little brighter in a slow pulse
	var pulse := 0.85 + 0.15 * sin(t * 4.0)
	var n := 6
	for i in n:
		var a := start.lerp(base, float(i) / n)
		var b := start.lerp(base, float(i + 1) / n)
		ci.draw_line(a, b, Color(col.r, col.g, col.b, 0.75 * pulse * float(i + 1) / n), 1.4 * s)
	# the head: slim, solid, a dark rim so it reads on anything
	var pts := PackedVector2Array([tip + dir * 1.5 * s, base + side * 6.5 * s - dir * 1.0 * s, base + dir * 3.0 * s, base - side * 6.5 * s - dir * 1.0 * s])
	var rim := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	ci.draw_polyline(rim, Color(0, 0, 0, 0.45), 2.4 * s)
	var head_pts := PackedVector2Array([tip, base + side * 5.5 * s, base + dir * 3.0 * s, base - side * 5.5 * s])
	FastDraw.poly(ci, PackedVector2Array([head_pts[0], head_pts[1], head_pts[2]]), Color(col, pulse))
	FastDraw.poly(ci, PackedVector2Array([head_pts[0], head_pts[2], head_pts[3]]), Color(col, pulse))


# the guide's card (top right): a dark plate with a thin rule of the guide's colour along its top,
# square-ish corners, no side bar; the same for the three guides
static func card_box(col: Color) -> StyleBoxFlat:
	# 2026-11-11 炭黑: the charcoal plate (as the prologue's card) with the guide's colour along its top
	var b := Charcoal.side_box(18.0)
	b.border_width_top = 3
	b.border_color = Color(col.r, col.g, col.b, 1.0)
	b.content_margin_left = 20
	b.content_margin_right = 18
	b.content_margin_top = 12
	b.content_margin_bottom = 14
	return b
