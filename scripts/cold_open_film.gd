extends CanvasLayer
# 开局重做 样片 (design/开局重做_方案_20261110.md): the cold open's film, about 12 s, before the player
# gets the drone at the hulk. Four shots, all drawn from the game's own art, letterboxed:
#   A 0.0–3.6   the port, every district lit, the camera pushing in on Berth 07
#   B 3.6–7.6   a giant ship (HG-170's own pieces) towed in past the berth's gantries
#   C 7.6–10.4  close on a seam: the laser's front running down it, sparks, the plate blown off
#   D 10.4–12.2 the title, then the black lifts off the game itself (the drone already at the hulk)
# Narration only as the owner's placeholders (data/台词.txt L_cold_1..4; empty shows nothing, or
# its slot when show_slots). Any key or click skips (a short fade, never a hard cut).
# 60 FPS: the port, the far yards and the big hull are each drawn once into their own canvas item
# and only moved and scaled after (a full PortArt redraw is ~25 ms a frame); the game under the
# film is hidden while the film covers it (scripts/cold_open.gd).

const LENGTH := 12.2
const A_END := 3.6
const B_END := 7.6
const C_END := 10.4
const REVEAL := 0.8             # s at the end: the black lifts and the game shows through
const BIG_SHIP := "hg170"
var on_done: Callable
var on_reveal: Callable         # the game under the film may be drawn again
var show_slots := false         # set by scripts/cold_open.gd (ColdOpen.SHOW_SLOTS)
var t := 0.0
var _out := -1.0                # skipping: the fade's own clock
var _done := false
var _revealed := false
var _bg: Control
var _vista: Node2D
var _port: Node2D
var _hull: Node2D
var _fg: Control
var _glow: Texture2D
var _vig: Texture2D
var _ship: Array = []           # [poly (m, centred), kind]
var _rooms: Array = []          # the ship's compartments (m, centred): their back walls, filled
var _ship_len := 170.0
var _ship_box := Rect2()
var _port_m := 1.0              # the scale the port was drawn at
var _hull_sc := 1.0
var _sparks: Array = []         # [pos, vel, life, max, hot]
var _puffs: Array = []          # [pos, vel, life, max, r]
var _bits: Array = []           # [pos, vel, rot, spin, size, life]: steel flakes off the cut
var _cues_done := {}
var sfx = null                  # the game's Sfx (scripts/cold_open.gd sets it): existing sounds only
var _stars: Array = []
var _font: Font
var _bold: Font
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	_glow = Fx.make_glow_texture(1.6)
	# the lens: corners darkened (a radial gradient drawn over every shot)
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 256
	gt.height = 256
	var gd := Gradient.new()
	gd.set_color(0, Color(0, 0, 0, 0))
	gd.set_color(1, Color(0, 0, 0, 0.9))
	gd.add_point(0.55, Color(0, 0, 0, 0))
	gt.gradient = gd
	_vig = gt
	_font = Fonts.get_font("Medium")
	_bold = Fonts.get_font("SemiBold")
	var d := Ship.load_data(BIG_SHIP)
	_ship_len = maxf(20.0, float(d.get("length", 170.0)))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var raw: Array = []
	for pd in d.get("pieces", []):
		var pts := PackedVector2Array()
		for q in pd.get("poly", []):
			var v := Vector2(float(q[0]), float(q[1]))
			pts.append(v)
			lo = lo.min(v)
			hi = hi.max(v)
		if pts.size() >= 3:
			raw.append([pts, str(pd.get("kind", ""))])
	_ship_box = Rect2(lo, hi - lo)
	var mid := _ship_box.get_center()
	for e in raw:
		var out := PackedVector2Array()
		for q in e[0]:
			out.append(q - mid)
		_ship.append([out, e[1]])
	for rd in d.get("rooms", []):
		var rp := PackedVector2Array()
		for q in rd.get("poly", []):
			rp.append(Vector2(float(q[0]), float(q[1])) - mid)
		if rp.size() >= 3:
			_rooms.append(rp)
	for i in 160:
		_stars.append([Vector2(_rng.randf(), _rng.randf()), _rng.randf_range(0.3, 1.0), _rng.randf()])
	var vs := get_viewport().get_visible_rect().size
	_bg = _ctl(_draw_bg)
	_vista = _node(func(): FarVista.draw(_vista, Transform2D.IDENTITY, 0.0, 0.0, vs.x * 4.0, 0.0))
	_port_m = minf(vs.x / 420.0, vs.y / 260.0)
	_port = _node(func(): PortArt.draw(_port, Vector2.ZERO, _port_m, 0.8, 0.0, {"power": 2, "tug": 2, "process": 2, "trade": 2, "cargo": 2, "salvage": 2, "ring": 1}))
	_hull_sc = vs.x * 1.25 / _ship_len
	_hull = _node(_draw_hull)
	_fg = _ctl(_draw_fg)
	_fg.mouse_filter = Control.MOUSE_FILTER_STOP
	_fg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: skip())
	_place()


func _ctl(f: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(f)
	add_child(c)
	return c


# drawn once; only its transform changes after
func _node(f: Callable) -> Node2D:
	var n := Node2D.new()
	n.draw.connect(f)
	add_child(n)
	return n


func _process(dt: float) -> void:
	t += dt
	if _out >= 0.0:
		_out += dt
		if _out >= 0.35:
			finish()
			return
	if not _revealed and t >= LENGTH - REVEAL:
		_reveal()
	_sim(dt)
	_cues()
	_place()
	_bg.queue_redraw()
	_fg.queue_redraw()
	if t >= LENGTH:
		finish()


func _input(ev: InputEvent) -> void:
	if _done:
		return
	if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventJoypadButton and ev.pressed):
		get_viewport().set_input_as_handled()
		if t > 0.25:
			skip()


# any key: a short fade, then the game
func skip() -> void:
	if _out < 0.0 and not _done:
		_out = 0.0
		_reveal()


func _reveal() -> void:
	if _revealed:
		return
	_revealed = true
	if on_reveal.is_valid():
		on_reveal.call()


func finish() -> void:
	if _done:
		return
	_done = true
	_reveal()
	if on_done.is_valid():
		on_done.call()
	queue_free()


# the film's sounds: the game's own (assets/audio through Sfx.play), each once at its moment
const CUES := [
	[0.2, "radio_on", 0.45, 0.8], [3.62, "tow_start", 0.9, 0.85], [5.4, "clamp", 0.55, 0.7],
	[7.62, "scale_beep", 0.6, 1.0], [7.9, "ignite", 0.9, 1.0], [8.25, "hiss", 0.45, 1.1], [8.7, "hiss", 0.45, 1.0],
	[9.15, "hiss", 0.5, 0.95], [9.5, "blowout", 1.0, 1.0], [9.52, "hull_break", 0.85, 0.9], [9.75, "debris", 0.6, 1.0],
	[10.42, "stamp", 0.8, 0.8], [11.45, "reveal", 0.55, 1.0]]

func _cues() -> void:
	if sfx == null or not is_instance_valid(sfx) or _out >= 0.0:
		return
	for i in CUES.size():
		var c: Array = CUES[i]
		if t >= float(c[0]) and not _cues_done.has(i):
			_cues_done[i] = true
			if t - float(c[0]) < 0.25:
				sfx.play(str(c[1]), Vector2.INF, float(c[2]), float(c[3]))


func _k(a: float, b: float) -> float:
	return Pal.ease_io(clampf((t - a) / maxf(0.001, b - a), 0.0, 1.0))


func caption(id: String) -> String:
	var p: Array = Lines.get_pair(id)
	if p.is_empty():
		return ""
	return str(p[0]) if Txt.zh else str(p[1] if str(p[1]) != "" else p[0])


# ---------------------------------------------------------------- the camera on the cached items

func _port_view(s: Vector2) -> Array:
	var k := clampf(t / A_END, 0.0, 1.0)
	var zoom := _port_m * lerpf(0.92, 1.18, Pal.ease_io(k))
	var berth := PortArt.district_at("salvage")
	var c := s * 0.5 + Vector2(0, -30) - berth * zoom * 0.08 * Pal.ease_io(k)
	return [c, zoom]


func _hull_xf(s: Vector2) -> Transform2D:
	var k := (t - A_END) / (B_END - A_END)
	# the bow comes in from the right; the hull slides left at a giant's pace
	var c := Vector2(lerpf(s.x * 1.2, s.x * 0.66, k), s.y * 0.53)
	return Transform2D(-0.018 + 0.01 * k, Vector2.ONE, 0.0, c)


func _place() -> void:
	var s := _fg.size if _fg != null and _fg.size.x > 0 else get_viewport().get_visible_rect().size
	var a := t < A_END and _out < 0.0
	var b := t >= A_END and t < B_END and _out < 0.0
	_vista.visible = a or b
	_port.visible = a
	_hull.visible = b
	if a:
		var pv := _port_view(s)
		_port.position = pv[0]
		_port.scale = Vector2.ONE * (float(pv[1]) / _port_m)
		_vista.position = Vector2(s.x * 0.5 - 3300.0 - t * 22.0, s.y * 0.62)
	elif b:
		_hull.transform = _hull_xf(s)
		_vista.position = Vector2(-(t - A_END) * 60.0 - 900.0, s.y * 0.30)


const STRUCT := ["hull", "deck", "hatch", "door", "beam", "strut"]

# her machinery faint behind, then the structure: a silhouette with its insides just showing
func _draw_hull() -> void:
	var sc := _hull_sc
	# the cutaway sample's back walls: every compartment a lit volume, lighter at its top
	var hy := _ship_box.size.y * 0.5
	for rp in _rooms:
		var out := PackedVector2Array()
		var cols := PackedColorArray()
		for q in rp:
			out.append(q * sc)
			var k := clampf((q.y + hy) / _ship_box.size.y, 0.0, 1.0)
			cols.append(Pal.ROOM_LIT.lerp(Pal.SHELL_DK, 0.6 * (1.0 - k)).lerp(Color(0.02, 0.021, 0.025), 0.5 * k))
		_hull.draw_polygon(out, cols)
	for pass_i in 2:
		for e in _ship:
			var st: bool = STRUCT.has(e[1])
			if st != (pass_i == 1):
				continue
			var out := PackedVector2Array()
			for q in e[0]:
				out.append(q * sc)
			var hull: bool = e[1] == "hull"
			if hull:
				# lit from above: the hull's own grey on top, shaded below
				var cols := PackedColorArray()
				for q in out:
					var k := clampf((q.y / sc + _ship_box.size.y * 0.5) / _ship_box.size.y, 0.0, 1.0)
					cols.append(Pal.SHELL_DK.lerp(Pal.SHELL, 0.42 * (1.0 - k)).lerp(Color.BLACK, 0.25 * k))
				_hull.draw_polygon(out, cols)
			else:
				_hull.draw_colored_polygon(out, Color(0.05, 0.052, 0.06) if st else Color(0.04, 0.042, 0.048))
			out.append(out[0])
			_hull.draw_polyline(out, Pal.ink(0.78 if hull else (0.36 if st else 0.13)), 1.4 if hull else 1.0, true)


# ---------------------------------------------------------------- particles (shot C)

func _front(s: Vector2) -> Vector2:
	# the laser's front down the seam, 7.9 → 9.5 s
	var k := clampf((t - 7.9) / 1.6, 0.0, 1.0)
	return Vector2(s.x * 0.5, lerpf(s.y * 0.2, s.y * 0.8, Pal.ease_io(k)))


func _sim(dt: float) -> void:
	var s := _fg.size
	if t > 7.9 and t < 9.55:
		var f := _front(s)
		for i in 7:
			var a := _rng.randf_range(-0.3, 1.9)
			var sp := _rng.randf_range(220.0, 900.0)
			_sparks.append([f, Vector2.from_angle(a) * sp, 0.0, _rng.randf_range(0.25, 0.9), _rng.randf()])
	# the plate goes: the air in the room behind it, out through the gap
	if t > 9.5 and t < 10.3:
		for i in 5:
			var y := _rng.randf_range(s.y * 0.18, s.y * 0.82)
			_puffs.append([Vector2(s.x * 0.5, y), Vector2(_rng.randf_range(400, 1300), _rng.randf_range(-200, 200)), 0.0, _rng.randf_range(0.4, 0.9), _rng.randf_range(20, 70)])
	if t > 9.5 and _bits.is_empty():
		for i in 14:
			var y := _rng.randf_range(s.y * 0.2, s.y * 0.8)
			_bits.append([Vector2(s.x * 0.5, y), Vector2(_rng.randf_range(300, 1100), _rng.randf_range(-300, 300)), _rng.randf() * TAU, _rng.randf_range(-9, 9), _rng.randf_range(4, 11), 0.0])
	for b in _bits:
		b[0] += b[1] * dt
		b[2] += b[3] * dt
		b[5] += dt
	for p in _sparks:
		p[0] += p[1] * dt
		p[1] *= 1.0 - 0.4 * dt         # nothing slows them out here but their own cooling
		p[2] += dt
	for p in _puffs:
		p[0] += p[1] * dt
		p[1] *= 1.0 - 1.6 * dt
		p[2] += dt
	_sparks = _sparks.filter(func(p): return p[2] < p[3])
	_puffs = _puffs.filter(func(p): return p[2] < p[3])


# ---------------------------------------------------------------- drawing

# behind the cached items: the black, the stars, a far sun
func _draw_bg() -> void:
	var ci := _bg
	var s := ci.size
	var a := 1.0 - _k(LENGTH - REVEAL, LENGTH) if t >= C_END else 1.0
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.008, 0.009, 0.012, a))
	if t < A_END:
		_starfield(ci, s, Vector2(-t * 6.0, 0.0), 1.0)
		var sun := Vector2(s.x * 0.86, s.y * 0.22)
		var gr := s.y * 0.9
		ci.draw_texture_rect(_glow, Rect2(sun - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.78, 0.6, 0.07))
	elif t < B_END:
		_starfield(ci, s, Vector2(-(t - A_END) * 30.0, 0.0), 0.8)


func _draw_fg() -> void:
	var ci := _fg
	var s := ci.size
	if t < A_END:
		_shot_port(ci, s)
	elif t < B_END:
		_shot_ship(ci, s)
	elif t < C_END:
		_shot_cut(ci, s)
	else:
		_shot_title(ci, s)
	# the cuts between shots: a few frames of black, never a fade-through
	for cut in [A_END, B_END, C_END]:
		if absf(t - cut) < 0.07:
			ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 1.0))
	if t < C_END:
		ci.draw_texture_rect(_vig, Rect2(Vector2.ZERO, s), false, Color(1, 1, 1, 0.85))
	_bars(ci, s)
	_captions(ci, s)
	# the way out, small, the whole time
	var hint := Ops.w("任意键跳过", "ANY KEY TO SKIP")
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	ci.draw_string(_font, Vector2(s.x - 64 - hw, s.y - 26), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.32 * (1.0 - _k(LENGTH - 1.0, LENGTH))))
	# the open: from black at the start, or the skip's fade
	var a_in := 1.0 - _k(0.0, 0.7)
	if a_in > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, a_in))
	if _out >= 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(_out / 0.3, 0.0, 1.0)))


# the letterbox: closed in over the film, drawn back as it hands over to the game
func _bars(ci: CanvasItem, s: Vector2) -> void:
	var h := s.y * 0.12 * (1.0 - _k(LENGTH - REVEAL, LENGTH))
	ci.draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
	ci.draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))


func _starfield(ci: CanvasItem, s: Vector2, drift: Vector2, a: float) -> void:
	for st in _stars:
		var p: Vector2 = st[0]
		var d: float = st[1]
		var q := Vector2(fposmod(p.x * s.x + drift.x * d, s.x), fposmod(p.y * s.y + drift.y * d, s.y))
		var tw := 0.6 + 0.4 * sin(t * 2.0 + float(st[2]) * 20.0)
		ci.draw_rect(Rect2(q, Vector2(1.5, 1.5) * d), Pal.ink(0.35 * d * tw * a))


# A: over the cached port — the traffic in the approaches, Berth 07 found
func _shot_port(ci: CanvasItem, s: Vector2) -> void:
	var pv := _port_view(s)
	var c: Vector2 = pv[0]
	var zoom: float = pv[1]
	for i in 7:
		var lane := float(i) / 7.0
		var x := fposmod(lane * 977.0 + t * (40.0 + 25.0 * lane) * (1.0 if i % 2 == 0 else -1.0), s.x + 200.0) - 100.0
		var y := s.y * (0.24 + 0.55 * fposmod(lane * 1.618, 1.0))
		var blink := fmod(t * 1.3 + lane * 3.0, 1.0) < 0.18
		ci.draw_circle(Vector2(x, y), 2.0, Pal.ink(0.7))
		if blink:
			ci.draw_texture_rect(_glow, Rect2(Vector2(x, y) - Vector2(10, 10), Vector2(20, 20)), false, Pal.heat(0.8, 1.6))
	ci.draw_string(_font, Vector2(64, s.y * 0.12 + 44), "ZERO PRESSURE PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.55 * _k(0.6, 1.2)))


# B: over the cached hull — the floodlight, her running lights, the tug, the gantries racing by
func _shot_ship(ci: CanvasItem, s: Vector2) -> void:
	var lt := t - A_END
	var xf := _hull_xf(s)
	var sc := _hull_sc
	var lp := Vector2(s.x * 0.62, s.y * 0.48)
	ci.draw_texture_rect(_glow, Rect2(lp - Vector2(s.y * 0.7, s.y * 0.4), Vector2(s.y * 1.4, s.y * 0.8)), false, Color(0.9, 0.95, 1.0, 0.05))
	var half := _ship_box.size * 0.5
	for i in 9:
		var p := xf * (Vector2(lerpf(-half.x, half.x, (i + 0.5) / 9.0), -half.y + 0.6) * sc)
		if p.x < -20 or p.x > s.x + 20:
			continue
		var on := fmod(t * 0.9 + i * 0.37, 1.0) < 0.25
		ci.draw_circle(p, 2.5, Pal.heat(0.9, 1.4) if i % 3 == 0 else Pal.tint(Pal.AIR, 0.8, 1.2))
		if on:
			ci.draw_texture_rect(_glow, Rect2(p - Vector2(18, 18), Vector2(36, 36)), false, Pal.heat(0.7, 1.8) if i % 3 == 0 else Pal.tint(Pal.AIR, 0.6, 1.6))
	var bow := xf * (Vector2(-half.x, 0.0) * sc)
	var tug := bow + Vector2(-s.x * 0.12, -s.y * 0.02)
	if tug.x > -80:
		ci.draw_line(tug + Vector2(30, 0), bow + Vector2(14, 6), Pal.ink(0.6), 1.6, true)
		var body := PackedVector2Array([tug + Vector2(-34, -11), tug + Vector2(22, -11), tug + Vector2(36, 0), tug + Vector2(22, 11), tug + Vector2(-34, 11)])
		ci.draw_colored_polygon(body, Color(0.06, 0.064, 0.074))
		body.append(body[0])
		ci.draw_polyline(body, Pal.ink(0.85), 1.4, true)
		var fl := 50.0 + 14.0 * sin(t * 40.0)
		ci.draw_line(tug + Vector2(-36, 0), tug + Vector2(-36 - fl, 0), Pal.heat(0.85, 2.0), 5.0)
		ci.draw_texture_rect(_glow, Rect2(tug + Vector2(-60 - fl * 0.5, -24), Vector2(48 + fl * 0.5, 48)), false, Pal.heat(0.5, 1.6))
	var gap := s.x * 0.55
	var gx := fposmod(s.x - lt * s.x * 0.5, gap) - gap
	while gx < s.x + gap:
		var wd := 22.0
		ci.draw_rect(Rect2(gx, 0, wd, s.y), Color(0.006, 0.007, 0.009, 0.92))
		ci.draw_line(Vector2(gx, 0), Vector2(gx, s.y), Pal.ink(0.2), 1.0)
		ci.draw_line(Vector2(gx + wd, 0), Vector2(gx + wd, s.y), Pal.ink(0.2), 1.0)
		var y := 0.0
		var flip := false
		while y < s.y:
			ci.draw_line(Vector2(gx + (wd if flip else 0.0), y), Vector2(gx + (0.0 if flip else wd), y + 40.0), Pal.ink(0.13), 1.0)
			y += 40.0
			flip = not flip
		gx += gap
	ci.draw_string(_font, Vector2(64, s.y * 0.12 + 44), "HG-170 · 172 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.55 * _k(A_END + 0.6, A_END + 1.2)))


# C: macro on the seam (owner 2026-11-10: the plate solid, with its thickness — the cutaway sample's
# way: the hull's own grey, a lit face and a shaded one, raised stiffeners, rivet heads, a weld bead).
# The beam comes in from the drone off the top left; the front runs down, the kerf white behind it
# and cooling to red; sparks fly straight in vacuum; then the room's 98 kPa takes the right-hand
# plate away, turning, its edge showing how thick it is, the room behind it opened.
const PLATE_T := Vector2(18.0, 12.0)     # px: the plate's thickness as the camera sees its edge

func _shot_cut(ci: CanvasItem, s: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.006, 0.007, 0.009))
	var lt := t - B_END
	var blow := clampf((t - 9.5) / 0.9, 0.0, 1.0)
	var shake := Vector2(sin(t * 91.0), cos(t * 73.0)) * 12.0 * (1.0 - blow) * (1.0 if blow > 0.0 else 0.0)
	# a slow handheld drift
	var cam := Vector2(-lt * 10.0 + sin(t * 1.3) * 3.0, cos(t * 1.1) * 2.0) + shake
	var seam_x := s.x * 0.5
	var y0 := s.y * 0.08
	var y1 := s.y * 0.92
	var f := _front(s)
	var hot_at := f + cam
	var heat := 1.0 if t > 7.9 and t < 9.55 else 0.0
	# the room behind, seen once the plate goes
	if blow > 0.0:
		_room(ci, Rect2(seam_x + cam.x, y0 + cam.y, s.x, y1 - y0), blow)
	_plate(ci, Rect2(Vector2(-60, y0), Vector2(seam_x + 60, y1 - y0)), cam, 0.0, Vector2.ZERO, hot_at, heat, (1.0 - blow) if blow > 0.0 else 0.0, false)
	var go := Pal.ease_out(blow)
	_plate(ci, Rect2(Vector2(seam_x + 4.0, y0), Vector2(s.x * 0.62, y1 - y0)), cam + Vector2(go * s.x * 0.62, go * s.y * 0.16), go * 0.42, Vector2(seam_x, s.y * 0.5), hot_at, heat, (1.0 - blow) if blow > 0.0 else 0.0, true)
	# the kerf: white just behind the front, red further up, dark at the top
	var top := s.y * 0.2
	var steps := 48
	for i in steps:
		var a0 := lerpf(top, s.y * 0.8, float(i) / steps)
		var a1 := lerpf(top, s.y * 0.8, float(i + 1) / steps)
		if a0 > f.y or blow > 0.0:
			break
		var age := (f.y - a0) / (s.y * 0.6) * 1.6
		var hot := clampf(1.0 - age * 0.9, 0.0, 1.0)
		var p0 := Vector2(seam_x + 2.0, a0) + cam
		var p1 := Vector2(seam_x + 2.0, minf(a1, f.y)) + cam
		ci.draw_line(p0, p1, Color(0.0, 0.0, 0.0, 0.9), 5.0)
		ci.draw_line(p0 - Vector2(3, 0), p1 - Vector2(3, 0), Pal.heat(0.3 + 0.7 * hot, 1.0 + 2.6 * hot), 1.6 + 1.5 * hot)
		ci.draw_line(p0 + Vector2(3, 0), p1 + Vector2(3, 0), Pal.heat(0.2 + 0.6 * hot, 1.0 + 2.0 * hot), 1.2 + 1.2 * hot)
	if heat > 0.0:
		var src := Vector2(-s.x * 0.12, -s.y * 0.35)
		ci.draw_line(src, hot_at, Pal.heat(0.18, 1.6), 7.0)
		ci.draw_line(src, hot_at, Pal.heat(0.95, 3.2), 1.4)
		var gr := 44.0 + 10.0 * sin(t * 53.0)
		ci.draw_texture_rect(_glow, Rect2(hot_at - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Pal.heat(0.85, 2.6))
		ci.draw_texture_rect(_glow, Rect2(hot_at - Vector2(gr, gr) * 2.6, Vector2(gr, gr) * 5.2), false, Pal.heat(0.12, 1.4))
		ci.draw_circle(hot_at, 5.0, Pal.ink(1.0, 3.2))
	for p in _sparks:
		var a: float = 1.0 - p[2] / p[3]
		var v: Vector2 = p[1]
		ci.draw_line(p[0] + cam, p[0] + cam - v * 0.022, Pal.heat(a, 1.4 + 2.2 * a * float(p[4])), 1.4 + float(p[4]))
	for b in _bits:
		var a3: float = clampf(1.0 - float(b[5]) / 1.2, 0.0, 1.0)
		var bx := Transform2D(float(b[2]), b[0] + cam)
		var h: float = b[4]
		var q := PackedVector2Array([bx * Vector2(-h, -h * 0.4), bx * Vector2(h, -h * 0.3), bx * Vector2(h * 0.7, h * 0.4), bx * Vector2(-h * 0.8, h * 0.35)])
		ci.draw_colored_polygon(q, Color(0.16, 0.165, 0.18, a3))
		ci.draw_line(q[0], q[1], Pal.heat(0.8 * a3, 1.8), 1.2)
	for p in _puffs:
		var a2: float = 1.0 - p[2] / p[3]
		var r: float = p[4] * (1.0 + p[2] * 3.0)
		ci.draw_texture_rect(_glow, Rect2(p[0] + cam - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.tint(Pal.AIR, 0.2 * a2, 1.3))
	var fl := 1.0 - clampf((t - 9.5) / 0.14, 0.0, 1.0)
	if t > 9.5 and fl > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.6 * fl))
	# the reading that said so, before it went
	var rk := _k(B_END + 0.3, B_END + 0.7) * (1.0 - clampf(blow * 3.0, 0.0, 1.0))
	if rk > 0.0:
		var pr := Vector2(seam_x + 90, s.y * 0.3) + cam
		ci.draw_circle(pr, 4.0, Pal.tint(Pal.AIR, rk, 1.4))
		ci.draw_line(pr, pr + Vector2(46, -46), Pal.tint(Pal.AIR, 0.8 * rk), 1.2)
		ci.draw_line(pr + Vector2(46, -46), pr + Vector2(220, -46), Pal.tint(Pal.AIR, 0.5 * rk), 1.0)
		ci.draw_string(_font, pr + Vector2(54, -54), Ops.w("舱内 98 kPa", "INSIDE 98 kPa"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.tint(Pal.AIR, rk, 1.3))


# the machinery room behind the plate, opened: dark, its engine and pipes caught by the heat
func _room(ci: CanvasItem, r: Rect2, k: float) -> void:
	ci.draw_rect(r, Color(0.028, 0.03, 0.036))
	var c := r.position + Vector2(r.size.x * 0.32, r.size.y * 0.62)
	ci.draw_arc(c, r.size.y * 0.22, 0.0, TAU, 48, Pal.ink(0.16 * k), 2.0, true)
	ci.draw_arc(c, r.size.y * 0.14, 0.0, TAU, 40, Pal.ink(0.1 * k), 1.5, true)
	for i in 3:
		var y := r.position.y + r.size.y * (0.18 + 0.08 * i)
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Pal.ink(0.1 * k), 3.0)
	ci.draw_texture_rect(_glow, Rect2(r.position + Vector2(-r.size.y * 0.4, 0), Vector2(r.size.y * 0.8, r.size.y)), false, Pal.heat(0.25 * k, 1.4))


# A hull plate as solid steel: its edge (the thickness) behind, the face lit from the top left,
# raised stiffeners with a lit and a shaded side, rivet heads, a weld bead along its seam edge,
# the beam's heat glowing on it. `seam_left`: the seam is this plate's left edge.
func _plate(ci: CanvasItem, r: Rect2, off: Vector2, rot: float, pivot: Vector2, hot_at: Vector2, heat: float, hot_edge: float, seam_left: bool) -> void:
	var xf := Transform2D(rot, pivot + off) * Transform2D(0.0, -pivot)
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var face := PackedVector2Array()
	for q in c:
		face.append(xf * q)
	# the thickness: the face pushed back, its sides drawn dark
	var tv := xf.basis_xform(PLATE_T)
	var back := PackedVector2Array()
	for q in face:
		back.append(q + tv)
	for i in 4:
		var e := PackedVector2Array([face[i], face[(i + 1) % 4], back[(i + 1) % 4], back[i]])
		ci.draw_colored_polygon(e, Color(0.045, 0.047, 0.053))
		ci.draw_line(back[i], back[(i + 1) % 4], Pal.ink(0.12), 1.0)
	var lit := Pal.SHELL.lerp(Pal.SHELL_DK, 0.45)
	var dk := Pal.SHELL_DK.lerp(Color.BLACK, 0.35)
	ci.draw_polygon(face, PackedColorArray([lit, lit.lerp(dk, 0.45), dk, lit.lerp(dk, 0.6)]))
	# the edge catching the light
	ci.draw_line(face[0], face[1], Pal.ink(0.55), 2.0)
	ci.draw_line(face[0], face[3], Pal.ink(0.32), 1.5)
	ci.draw_line(face[1], face[2], Color(0, 0, 0, 0.6), 2.0)
	ci.draw_line(face[2], face[3], Color(0, 0, 0, 0.6), 2.0)
	# stiffeners: raised flat bars, their shadow cast to the right
	var side := xf.basis_xform(Vector2(1, 0))
	var n := int(r.size.x / 150.0)
	for i in range(1, n + 1):
		var x := r.position.x + r.size.x * i / (n + 1)
		var a := xf * Vector2(x, r.position.y + 6)
		var b := xf * Vector2(x, r.end.y - 6)
		ci.draw_line(a + side * 10.0, b + side * 10.0, Color(0, 0, 0, 0.35), 8.0)
		ci.draw_line(a, b, Pal.SHELL.lerp(Pal.SHELL_DK, 0.3), 12.0)
		ci.draw_line(a - side * 6.0, b - side * 6.0, Pal.ink(0.42), 1.2)
		ci.draw_line(a + side * 6.0, b + side * 6.0, Color(0, 0, 0, 0.55), 1.2)
	# rivet heads in rows along the top and bottom
	var m := int(r.size.x / 42.0)
	for i in m:
		for yy in [r.position.y + 96.0, r.end.y - 96.0]:
			var p := xf * Vector2(r.position.x + 20.0 + i * 42.0, yy)
			ci.draw_circle(p, 4.0, Pal.SHELL_DK.lerp(Color.BLACK, 0.3))
			ci.draw_circle(p - Vector2(1.2, 1.2), 2.2, Pal.ink(0.38))
	# the weld bead down the seam edge: a raised, rippled strip
	var sx := r.position.x + 7.0 if seam_left else r.end.x - 7.0
	var ya := r.position.y
	while ya < r.end.y:
		ci.draw_arc(xf * Vector2(sx, ya), 6.0, PI * 0.1, PI * 0.9, 6, Pal.ink(0.26), 1.2)
		ya += 7.0
	ci.draw_line(xf * Vector2(sx - 6.5, r.position.y), xf * Vector2(sx - 6.5, r.end.y), Color(0, 0, 0, 0.5), 1.0)
	# the cut edge still glowing as it goes
	if hot_edge > 0.0:
		var ex := r.position.x if seam_left else r.end.x
		ci.draw_line(xf * Vector2(ex, r.position.y + 40), xf * Vector2(ex, r.end.y - 40), Pal.heat(0.9 * hot_edge, 1.0 + 1.6 * hot_edge), 3.0)
	# the beam's heat on the steel round the spot
	if heat > 0.0:
		var g := 240.0
		ci.draw_texture_rect(_glow, Rect2(hot_at - Vector2(g, g), Vector2(g, g) * 2.0), false, Pal.heat(0.16, 1.2))


# D: the title on black; then the black lifts and the game is there
func _shot_title(ci: CanvasItem, s: Vector2) -> void:
	var lt := t - C_END
	var a := _k(C_END, C_END + 0.35) * (1.0 - _k(LENGTH - REVEAL, LENGTH - 0.1))
	var title := Ops.w("零压", "ZERO PRESSURE")
	var fs := 120 if Txt.zh else 92
	var tw := _bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var c := s * 0.5 + Vector2(0, -10)
	var gg := 260.0 + 40.0 * Pal.ease_out(clampf(lt / 0.6, 0.0, 1.0))
	ci.draw_texture_rect(_glow, Rect2(c - Vector2(gg * 1.6, gg * 0.7), Vector2(gg * 3.2, gg * 1.4)), false, Pal.tint(UiSkin.ACCENT, 0.07 * a, 1.2))
	ci.draw_string(_bold, Vector2(c.x - tw * 0.5, c.y + fs * 0.35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(a))
	var line := 360.0 * Pal.ease_out(clampf(lt / 0.8, 0.0, 1.0))
	ci.draw_rect(Rect2(c.x - line * 0.5, c.y + fs * 0.55, line, 3), Pal.tint(UiSkin.ACCENT, a, 1.3))
	var sub := "ZERO PRESSURE  ·  SHIPBREAKING" if Txt.zh else "SHIPBREAKING"
	ci.draw_string(_font, Vector2(c.x - 400, c.y + fs * 0.55 + 40), sub, HORIZONTAL_ALIGNMENT_CENTER, 800, 16, Pal.ink(0.55 * a))


func _captions(ci: CanvasItem, s: Vector2) -> void:
	var id := ""
	var start := 0.0
	var stop := 0.0
	if t < A_END:
		id = "L_cold_1"; start = 0.6; stop = A_END
	elif t < B_END:
		id = "L_cold_2"; start = A_END + 0.3; stop = B_END
	elif t < C_END:
		id = "L_cold_3"; start = B_END + 0.2; stop = C_END
	else:
		id = "L_cold_4"; start = C_END + 0.6; stop = LENGTH - REVEAL
	var txt := caption(id)
	var slot := txt == "" and show_slots
	if txt == "" and not slot:
		return
	var a := clampf((t - start) / 0.3, 0.0, 1.0) * clampf((stop - t) / 0.3, 0.0, 1.0)
	if a <= 0.0:
		return
	if slot:
		txt = "〔旁白占位 %s〕" % id
	var y := s.y * 0.88 + 34.0 if id != "L_cold_4" else s.y * 0.5 + 150.0
	ci.draw_string(_font, Vector2(s.x * 0.5 - 600, y), txt, HORIZONTAL_ALIGNMENT_CENTER, 1200, 22, Pal.tint(UiSkin.ACCENT, 0.7 * a) if slot else Pal.ink(0.92 * a))
