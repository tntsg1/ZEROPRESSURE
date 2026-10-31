extends CanvasLayer
# The opening's first hulk, found and towed in (design/…/28_新手教程引导与主线, Q7/Q13; player
# 2026-10-24: "I start by hauling wrecks in from the asteroid belt"): before the very first
# ship of a new career comes into BERTH 07, about 13 s out in the belt — drifting rock, the
# hulk turning slowly (drawn from its own ship file, piece by piece), your tug's lights coming
# up, the tow cable, the long haul home. Once per career; Esc / Space / Enter / a click skips.
# The berth's own tow-in intro follows as before.

const LENGTH := 13.0
var ship := "tug"
var on_done: Callable
var t := 0.0
var _rocks: Array = []        # [pos (0..1 of a wide band), radius, sides seed, parallax, spin]
var _pieces: Array = []       # the hulk's piece outlines, metres
var _span := 16.0
var _done := false
var _c: Control
var _glow: Texture2D


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 70:
		_rocks.append([Vector2(rng.randf() * 1.6 - 0.3, rng.randf()), rng.randf_range(4.0, 46.0), rng.randi(), rng.randf_range(0.15, 1.0), rng.randf_range(-0.2, 0.2)])
	var d := Ship.load_data(ship)
	_span = maxf(4.0, float(d.get("length", 16.0)))
	for pd in d.get("pieces", []):
		var pts := PackedVector2Array()
		for q in pd.get("poly", []):
			pts.append(Vector2(float(q[0]), float(q[1])))
		if pts.size() >= 3:
			_pieces.append(pts)
	_glow = Fx.make_glow_texture(1.6)
	_c = Control.new()
	_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.draw.connect(_draw_scene)
	_c.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: finish())
	add_child(_c)


func _process(dt: float) -> void:
	t += dt
	_c.queue_redraw()
	if t >= LENGTH:
		finish()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	if on_done.is_valid():
		on_done.call()
	queue_free()


func _k(a: float, b: float) -> float:
	return Pal.ease_io(clampf((t - a) / maxf(0.001, b - a), 0.0, 1.0))


func _rock(ci: CanvasItem, c: Vector2, r: float, seed: int, spin: float, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := 7 + rng.randi() % 5
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n + spin
		pts.append(c + Vector2.from_angle(a) * r * rng.randf_range(0.7, 1.15))
	ci.draw_colored_polygon(pts, Color(0.045, 0.047, 0.055))
	pts.append(pts[0])
	ci.draw_polyline(pts, col, 1.2, true)


func _draw_scene() -> void:
	var ci := _c
	var s := ci.size
	var fade_in := _k(0.0, 0.8)
	var fade_out := 1.0 - _k(LENGTH - 1.0, LENGTH)
	var a := fade_in * fade_out
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.014, 0.018))
	# a far sun low on the left, the belt's dust lit by it
	var sun := Vector2(-s.x * 0.05, s.y * 0.3)
	var gr := s.y * 1.1
	ci.draw_texture_rect(_glow, Rect2(sun - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.82, 0.62, 0.10 * a))
	# the camera drifts along the belt: rocks slide at their depth
	var pan := t * 0.018
	for r in _rocks:
		var p: Vector2 = r[0]
		var depth: float = r[3]
		var x := fposmod(p.x - pan * depth, 1.6) - 0.3
		var c := Vector2(x * s.x, p.y * s.y)
		_rock(ci, c, float(r[1]) * (0.5 + depth * 0.6), int(r[2]), t * float(r[4]), Pal.ink(0.08 + 0.14 * depth * a))
	# the hulk: its own pieces, turning slowly until the cable takes it, then hauled off right
	var scale := s.y * 0.30 / _span
	var hook := _k(6.0, 7.0)
	var haul := _k(8.0, LENGTH - 0.5)
	var hc := Vector2(s.x * (0.56 + 0.5 * haul), s.y * (0.5 - 0.06 * haul))
	var rot := 0.35 + t * 0.08 * (1.0 - hook)
	var xf := Transform2D(rot, Vector2(scale, scale), 0.0, hc)
	var centre := Vector2(_span * 0.5, 0.0)
	for pts in _pieces:
		var out := PackedVector2Array()
		for q in pts:
			out.append(xf * (q - centre))
		ci.draw_colored_polygon(out, Color(0.04, 0.042, 0.05, a))
		out.append(out[0])
		ci.draw_polyline(out, Pal.ink(0.55 * a), 1.0, true)
	# your tug: lights first, then the shape, then the cable, then the haul
	var arrive := _k(2.6, 6.0)
	var tug := Vector2(lerpf(s.x * 1.15, hc.x + s.y * 0.22, arrive), lerpf(s.y * 0.30, hc.y - s.y * 0.02, arrive))
	if haul > 0.0:
		tug = hc + Vector2(s.y * 0.22 + 40.0 * haul, -s.y * 0.02)
	var blink := fmod(t, 1.0) < 0.5
	if t > 2.6:
		var body := PackedVector2Array([tug + Vector2(-40, -14), tug + Vector2(26, -14), tug + Vector2(44, 0), tug + Vector2(26, 14), tug + Vector2(-40, 14)])
		ci.draw_colored_polygon(body, Color(0.05, 0.055, 0.065, a))
		body.append(body[0])
		ci.draw_polyline(body, Pal.ink(0.8 * a), 1.4, true)
		ci.draw_line(tug + Vector2(-12, -14), tug + Vector2(-12, 14), Pal.ink(0.5 * a), 1.0)
		ci.draw_rect(Rect2(tug + Vector2(8, -7), Vector2(12, 14)), Pal.tint(Pal.AIR, 0.5 * a, 1.2), false, 1.0)
		ci.draw_circle(tug + Vector2(-44, -8), 4.0, Pal.heat((1.0 if blink else 0.3) * a, 1.6))
		ci.draw_circle(tug + Vector2(-44, 8), 4.0, Pal.tint(Pal.AIR, (0.3 if blink else 1.0) * a, 1.4))
		if haul > 0.0:
			# the drive burning, pulling the hulk along
			ci.draw_line(tug + Vector2(44, 0), tug + Vector2(80 + 40 * haul, 0), Pal.heat(0.7 * a, 1.8), 5.0)
	if hook > 0.0:
		var from := tug + Vector2(-40, 0)
		var to := xf * (Vector2(_span, 0.0) - centre)
		ci.draw_line(from, from.lerp(to, hook), Pal.ink(0.75 * a), 1.6, true)
	# the captions: where and what, typed in
	var font := Fonts.get_font("Medium")
	var lines := [
		[0.6, Ops.w("小行星带巡航区 · 距零压港 2,400 公里，方位：北", "ASTEROID BELT PATROL ZONE · 2,400 KM NORTH OF ZERO PRESSURE PORT")],
		[3.2, Ops.w("例行巡航途中，拖船发现一艘无人驾驶的漂流船。经查询，该船的船籍登记早已注销。", "DURING A ROUTINE PATROL, YOUR TUG DISCOVERS AN UNCREWED VESSEL DRIFTING THROUGH THE BELT. REGISTRY CHECK CONFIRMS THE SHIP WAS DECOMMISSIONED LONG AGO.")],
		[6.2, Ops.w("挂缆", "CABLE ON")],
		[8.4, Ops.w("目标船舶已确认，准备拖回零压港。目的地：七号坞。", "VESSEL IDENTIFIED AND READY FOR RECOVERY. DESTINATION: ZERO PRESSURE PORT, BERTH 07.")],
	]
	var y := s.y - 150.0
	for ln in lines:
		var start: float = ln[0]
		if t < start:
			continue
		var txt: String = ln[1]
		var n := int(clampf((t - start) / 1.2, 0.0, 1.0) * txt.length())
		# 2026-10-30: a long line comes down a size or two rather than run off the screen
		var fs := 22
		while fs > 14 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > s.x - 160.0:
			fs -= 1
		ci.draw_string(font, Vector2(80, y), txt.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.9 * a))
		y += 34.0
	ci.draw_string(Fonts.get_font("Regular"), Vector2(s.x - 80, s.y - 40), Ops.w("Esc 跳过", "Esc to skip"), HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Pal.ink(0.4 * a))
