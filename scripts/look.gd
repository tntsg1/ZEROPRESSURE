class_name Look
extends Node2D
# 91 号画面升级（用户 2026-10-27：极简画风，但做工和动画都要精美到惊艳）。
# One node per game holding what the picture adds on top of the simulation:
#  - real 2D lights where real light is: the laser's front, the furnace mouth, the
#    floodlights on the boom, the drone's head lamp; they light the plates and lines round them
#  - the full-screen pass (layer 15, above the glow, under the HUD): vignette, and with the
#    "film" setting a fine grain and a slight colour fringe toward the edges
#  - the far belt: three layers of rock silhouettes with a lit rim, slow parallax
#  - the small notes in the scene (what a part of the berth is) shown only near the cursor
#    or with the measuring tool out (Q4)
#  - the clock: every slow-down keeps the physics step at 1/120 s (fewer steps per second,
#    not longer ones), so a slow-motion moment never changes what happens (Q11)
const FastDraw = preload("res://scripts/fast_draw.gd")   # 60 FPS: the cheap circle / arc / polyline

const LIGHT_DIR := Vector2(-0.45, -0.89)   # where the berth's light comes from (up, a little left)
const SLOW := 0.25                         # the big-piece slow motion (30 physics steps a second)
const SLOW_T := 0.6                        # its length, real seconds
const SLOW_MASS := 3.0                     # t: a piece this heavy coming free is a moment
const TICKS := 120

var game
var post: CanvasLayer
var post_mat: ShaderMaterial
var laser: PointLight2D
var lamp: PointLight2D
var furnace: PointLight2D
var floods: Array = []
var notes_node: Node2D
# 91 号 遥控与沉浸（DECISIONS 2026-10-27 遥控与太空沉浸定案）
var dark: CanvasModulate          # Q3 B: space is dark, the plates read only as outlines until lit
var beam: PointLight2D            # the head lamp's beam, along where the drone looks
var beam_fx: Node2D               # the beam seen in the dust, and the dust in it
var motes: Array = []             # [pos (px, round the drone), drift, phase]
var osd: CanvasLayer              # Q1 A: the camera feed's on-screen display
var osd_c: Control
var cam_offset := Vector2.ZERO    # Q5 a: the camera on the drone lags its starts and runs on at its stops
var cam_roll := 0.0               # Q5 b: and leans a little into a sideways push
var _dv := Vector2.ZERO
var _last_v := Vector2.ZERO
var _co_v := Vector2.ZERO
var signal_k := 1.0               # Q2 A: 1 clean, 0 lost (only the picture suffers, never the controls)
var _sig_t := 0.0
# user 2026-10-28 ("一进到内部屏幕就不停地闪…闪一两下就够了"): the picture tears only as the link
# drops (into the hull, behind plating, out of range) — two short glitches, then a steady picture;
# the weak link stays on the OSD's signal bars. -1: no glitch running
var glitch_t := -1.0
var _glitch_k := 0.0
var _glitch_cd := 0.0
const GLITCH := [[0.0, 0.1], [0.2, 0.3]]   # s: the two tears of a drop
const GLITCH_CD := 1.5                      # s: a link flickering on an edge does not glitch again till then
var _last_zoom := -1.0
var focus := 0.0                  # Q5 c: the lens breathing as it zooms
var feed_t := 0.0
var _osd_t := -1.0               # the OSD and the beam redraw at 30 Hz (a drone OSD's own rate)
var _rects := {}
var _rects_t := -1.0
var focus_v := 0.0                # the focus hunts: it overshoots and settles (a spring)
var _focus_drive := 0.0
var beam_ang := 0.0               # the lamp's heading: it swings round on its mount, not instantly
var beam_av := 0.0
var _hover_k := {}                # the overlay's parts under the pointer, eased
const SIG_N := 120
var _sig_hist: Array = []         # the link's strength, last 12 s
var _sig_hist_t := 0.0
var _t := 0.0

static var on := true           # Ctrl+Shift+L: the new picture or the old one, side by side in play (not saved)
static var notes := {}          # canvas item instance id -> [[world pos, text, size, colour, align, font], ...]
static var _soft: Texture2D
static var _cone: Texture2D


# ---------------------------------------------------------------- the clock

# every change of game speed goes through here: the step stays 1/120 s
static func time_k(k: float) -> void:
	var ticks := maxi(1, roundi(TICKS * k))
	Engine.physics_ticks_per_second = ticks
	Engine.time_scale = ticks / float(TICKS)


# ---------------------------------------------------------------- load profile

# where entering a ship goes (ZP_PROF=1 in the environment prints it)
static var _mark_t := 0
static var async_in_tests := false
static var test_mouse := Vector2.INF  # screenshots: where the pointer is taken to be (tests never move the real one)   # load probes: entering a ship the way play does
static var _marks: Array = []
static func mark(label: String) -> void:
	var now := Time.get_ticks_usec()
	_marks.append("  [ready] %-22s %6.1f ms" % [label, (now - _mark_t) / 1000.0])
	_mark_t = now
	if label == "career_services":
		if OS.get_environment("ZP_PROF") == "1":
			print("
".join(_marks))
		_marks.clear()


# ---------------------------------------------------------------- notes

static func clear_notes(n: CanvasItem) -> void:
	notes.erase(n.get_instance_id())


static func note(n: CanvasItem, font: Font, pos: Vector2, text: String, align: int, size: int, col: Color) -> void:
	var id := n.get_instance_id()
	if not notes.has(id):
		notes[id] = []
	notes[id].append([n.get_global_transform() * pos, text, size, col, align, font])


# ---------------------------------------------------------------- set up

func setup(g) -> void:
	game = g
	name = "Look"
	z_index = 60
	z_as_relative = false
	if _soft == null:
		_soft = _radial(256)
		_cone = _cone_tex(128, 256)
	laser = _light(Color(1.0, 0.55, 0.22), 1.9, 5.0)
	lamp = _light(Color(0.75, 0.88, 1.0), 0.55, 4.5)
	furnace = _light(Color(1.0, 0.45, 0.16), 1.2, 9.0)
	for i in Dock.FLOODS.size():
		var f := _light(Color(0.92, 0.95, 1.0), 0.9, 1.0)
		f.texture = _cone
		f.offset = Vector2(0, _cone.get_height() * 0.5)
		f.texture_scale = 9.5 * Geom.M / _cone.get_height()
		floods.append(f)
	notes_node = Node2D.new()
	notes_node.name = "Notes"
	notes_node.draw.connect(_draw_notes)
	add_child(notes_node)
	dark = CanvasModulate.new()
	dark.color = Color(1, 1, 1)
	add_child(dark)
	beam = _light(Color(0.86, 0.93, 1.0), 1.5, 1.0)
	beam.texture = _cone
	beam.offset = Vector2(0, _cone.get_height() * 0.5)
	beam.texture_scale = 11.0 * Geom.M / _cone.get_height()
	beam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	beam_fx = Node2D.new()
	beam_fx.name = "Beam"
	beam_fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var bm := CanvasItemMaterial.new()
	bm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	beam_fx.material = bm
	beam_fx.draw.connect(_draw_beam)
	add_child(beam_fx)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	for i in 90:
		motes.append([Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 12.0 * Geom.M, Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 6.0, rng.randf() * TAU])
	osd = CanvasLayer.new()
	osd.layer = 21
	osd.name = "FeedOSD"
	osd_c = Control.new()
	osd_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	osd_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	osd_c.draw.connect(_draw_osd)
	osd.add_child(osd_c)
	add_child(osd)
	post = CanvasLayer.new()
	post.layer = 15
	post.name = "Post"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = preload("res://scripts/look_post.gdshader")
	rect.material = post_mat
	post.add_child(rect)
	add_child(post)
	apply_settings()


func apply_settings() -> void:
	if post_mat == null:
		return
	var film := Txt.film and Txt.quality == "high"
	post_mat.set_shader_parameter("grain", 0.012 if film else 0.0)
	post_mat.set_shader_parameter("fringe", 0.00025 if film else 0.0)
	post_mat.set_shader_parameter("vignette", 0.42)


func _light(c: Color, energy: float, radius_m: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _soft
	l.color = c
	l.energy = energy
	l.texture_scale = radius_m * Geom.M * 2.0 / _soft.get_width()
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.shadow_enabled = false
	l.enabled = false
	add_child(l)
	return l


static func _radial(n: int) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = n
	t.height = n
	return t


# a floodlight's beam: bright at the lamp (top middle), widening and fading downward
static func _cone_tex(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var k := float(y) / (h - 1)
		var half := 0.06 + 0.44 * k
		for x in w:
			var u := absf((x + 0.5) / w - 0.5) / half
			var a := 0.0
			if u < 1.0:
				a = pow(1.0 - k, 1.6) * (1.0 - u * u) * smoothstep(0.0, 0.05, k)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- every frame

# user 2026-10-27 "无人机这灯怎么一抖一抖的", 10-28 "不抖了但不丝滑，一卡一卡": the drone is drawn
# between its last two physics positions (physics interpolation); the lamp and its cone now sit at
# that same point every frame, worked out here — the position at the start of this physics step
# (_lamp_prev, which is where the step before left it) blended toward the newest by the engine's
# own fraction — and the cone and its dust are drawn again every frame (they were at 30 Hz).
# Both nodes are taken out of the engine's interpolation: they are placed exactly each frame.
var _lamp_prev := Vector2.INF


func _physics_process(_dt: float) -> void:
	if game == null or game.drone == null:
		return
	_lamp_prev = game.drone.global_position


func lamp_pos() -> Vector2:
	var now: Vector2 = game.drone.global_position
	if _lamp_prev == Vector2.INF or not game.drone.is_physics_interpolated_and_enabled():
		return now
	return _lamp_prev.lerp(now, Engine.get_physics_interpolation_fraction())


func _process(dt: float) -> void:
	if game == null:
		return
	_t += dt / maxf(Engine.time_scale, 0.01)
	_step_folds(dt / maxf(Engine.time_scale, 0.01))
	post_mat.set_shader_parameter("t", fposmod(_t, 100.0))
	var high := Txt.quality == "high" and on
	post.visible = on
	var tools = game.tools
	# the laser's front: the plate it is burning glows round it
	laser.enabled = high and tools != null and tools.cutting
	if laser.enabled:
		laser.position = tools.front
		laser.energy = 1.7 + 0.35 * sin(_t * 47.0) + 0.2 * sin(_t * 113.0)
	# the drone's head lamp, a little ahead of it
	var d = game.drone
	lamp.enabled = high and d != null and d.alive and game.state == "play"
	if lamp.enabled:
		lamp.position = d.global_position
	# the furnace mouth, warm and unsteady
	var dock = game.dock
	var berth: bool = dock != null and dock.visible
	furnace.enabled = high and berth and dock.has_method("_furnace_seen") and dock._furnace_seen()
	if furnace.enabled:
		furnace.position = Dock.zpos("metal") + Vector2(0, -0.6 * Geom.M)
		furnace.energy = 0.9 + 0.12 * sin(_t * 5.3) + 0.07 * sin(_t * 13.1)
	# the floodlights on the boom (only the first burns, flickering, before the lights are repaired)
	var lit: bool = game.has_upgrade("lights")
	for i in floods.size():
		var f: PointLight2D = floods[i]
		f.enabled = high and berth and (lit or i == 0)
		if f.enabled:
			f.position = Vector2(Dock.FLOODS[i], Dock.RAIL_Y + 0.1) * Geom.M
			f.energy = 0.8 if lit else 0.35 + 0.1 * sin(_t * 23.0) + 0.07 * sin(_t * 7.3)
	_step_feed(dt / maxf(Engine.time_scale, 0.01), high)
	_step_lamps(dt / maxf(Engine.time_scale, 0.01), on and _on_site())
	_step_ship(dt / maxf(Engine.time_scale, 0.01))
	notes_node.queue_redraw()


# ---------------------------------------------------------------- 遥控与沉浸

func _on_site() -> bool:
	return game.state == "play" and game.drone != null and game.drone.alive and not game.belt


func _step_feed(rdt: float, high: bool) -> void:
	feed_t += rdt
	var site := on and _on_site()
	# Q3 B: dark, but the outlines still read; the lamps bring the plates up
	var want := (Color(1, 1, 1) if _in_port() else Color(0.86, 0.87, 0.9)) if site and high else Color(1, 1, 1)
	dark.color = dark.color.lerp(want, 1.0 - exp(-3.0 * rdt))
	# the head lamp's beam along where the drone looks
	var d = game.drone
	beam.enabled = site and high
	if beam.enabled:
		var dir: Vector2 = game.aim - d.global_position
		if dir.length() < 8.0:
			dir = Vector2.from_angle(d.heading)
		# user: "头灯转向感觉转太快了" — the lamp swings on its mount: a damped spring, never
		# faster than about 150°/s
		var bl := minf(rdt, 0.1)
		while bl > 0.0:
			var bh := minf(bl, 1.0 / 120.0)
			var err := wrapf(dir.angle() - beam_ang, -PI, PI)
			beam_av += (err * 140.0 - beam_av * 22.0) * bh
			beam_av = clampf(beam_av, -9.0, 9.0)
			beam_ang = wrapf(beam_ang + beam_av * bh, -PI, PI)
			bl -= bh
		beam.rotation = beam_ang - PI * 0.5
		beam.energy = 1.45
		beam.position = lamp_pos()
		beam_fx.position = beam.position
	beam_fx.visible = beam.enabled and Txt.anim_level() >= 1
	var tick := feed_t - _osd_t >= 1.0 / 30.0
	if tick:
		_osd_t = feed_t
	if beam_fx.visible:
		beam_fx.queue_redraw()
	# Q5 a/b: the camera rides the drone — it lags a start, runs on at a stop, leans into a push
	var v: Vector2 = d.linear_velocity if d != null else Vector2.ZERO
	if rdt > 0.0:
		_dv = _dv.lerp((v - _last_v) / rdt, 1.0 - exp(-12.0 * rdt))
	_last_v = v
	var feel: bool = site and game.cam_override == null and not Txt.no_flash()
	var want_off := (-_dv * 0.003).limit_length(10.0) if feel else Vector2.ZERO
	# a spring, so it settles with a little give rather than snapping
	# (user 2026-10-28: "切着切着还发抖……丢失视野": one long frame, a cut's hitch, and the plain
	# step went unstable — it shook, grew, and blew the camera off to infinity. Small steps, a cap
	# on a stall, and back to rest if it ever goes non-finite)
	var left := minf(rdt, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_co_v += ((want_off - cam_offset) * 60.0 - _co_v * 11.0) * h
		cam_offset += _co_v * h
		left -= h
	if not cam_offset.is_finite() or not _co_v.is_finite():
		cam_offset = Vector2.ZERO
		_co_v = Vector2.ZERO
	cam_roll = 0.0
	# Q2 A: the link to the bay — farther and behind plating, the picture breaks up
	_sig_t -= rdt
	if _sig_t <= 0.0 and d != null:
		_sig_t = 0.15
		# Q2 B: the nearest mast carries the feed — the berth's, or in the port a district's
		var best := INF
		for bs in _bases():
			var bd: float = d.global_position.distance_to(bs[1]) / Geom.M
			if bd < best:
				best = bd
				link_name = bs[0]
		var dist: float = best
		var k := 1.0 - 0.45 * smoothstep(25.0, 70.0, dist)
		if game.world != null:
			for n in game.world.rooms:
				var r = game.world.rooms[n]
				if r.bbox.has_point(d.global_position) and Geometry2D.is_point_in_polygon(d.global_position, r.poly):
					k -= 0.5
					break
		k = clampf(k, 0.0, 1.0)
		# a real drop (or the link slipping under the tearing line): one glitch
		if site and _glitch_cd <= 0.0 and (k < signal_k - 0.15 or (k < 0.62 and signal_k >= 0.62)) and not Txt.no_flash():
			glitch_t = 0.0
			_glitch_k = clampf((0.62 - k) / 0.62, 0.5, 1.0)
			_glitch_cd = GLITCH_CD
		signal_k = k
	_sig_hist_t -= rdt
	if _sig_hist_t <= 0.0:
		_sig_hist_t = 0.1
		_sig_hist.append(signal_k + randf_range(-0.02, 0.02))
		if _sig_hist.size() > SIG_N:
			_sig_hist.pop_front()
	# Q5 c: the lens breathing while the zoom changes
	var z: float = game.cam_zoom()
	if _last_zoom > 0.0 and rdt > 0.0:
		var rate := absf(z - _last_zoom) / maxf(z, 0.05) / rdt
		# only a real turn of the wheel, not the zoom easing in after it (that tail kept the glitch on)
		_focus_drive = maxf(_focus_drive * exp(-12.0 * rdt), clampf((rate - 0.6) * 1.0, 0.0, 1.0))
	# user: "滚动的时候……没有相机信号那种糊": the lens loses focus while the zoom moves and
	# hunts back in (a little past, then sharp) once it stops
	# (small steps, as the camera's spring above: a long frame would set it ringing)
	var fl := minf(rdt, 0.1)
	while fl > 0.0:
		var fh := minf(fl, 1.0 / 120.0)
		focus_v += ((_focus_drive - focus) * 90.0 - focus_v * 16.0) * fh
		focus = clampf(focus + focus_v * fh, -0.35, 1.0)
		fl -= fh
	if is_nan(focus) or not is_finite(focus_v):
		focus = 0.0
		focus_v = 0.0
	_last_zoom = z
	_glitch_cd -= rdt
	var interf := 0.0
	if glitch_t >= 0.0:
		for g in GLITCH:
			if glitch_t >= float(g[0]) and glitch_t < float(g[1]):
				interf = _glitch_k
		glitch_t += rdt
		if glitch_t > float(GLITCH[GLITCH.size() - 1][1]) or not site:
			glitch_t = -1.0
	post_mat.set_shader_parameter("interference", interf)
	post_mat.set_shader_parameter("focus", absf(focus) if Txt.anim_level() >= 1 else 0.0)
	post_mat.set_shader_parameter("feed", 1.0 if site and Txt.film else 0.0)
	osd.visible = site
	# user 2026-10-28: the speed and height either side of the scale stepped (30 Hz): every frame now
	if osd.visible:
		osd_c.queue_redraw()


func _draw_beam() -> void:
	var d = game.drone
	var dir: Vector2 = Vector2.from_angle(beam.rotation + PI * 0.5)
	var wp: Vector2 = beam_fx.position   # where the lamp is in the world (the motes drift past it)
	var p0 := Vector2.ZERO
	var L := 10.0 * Geom.M
	var side := dir.orthogonal()
	# the beam made visible by what floats in it: faint, widening, fading out
	# two lengths: a brighter core near the lamp, fading out within a third of the reach,
	# and the faint full cone (the falloff reads as light in thin dust, not a grey wedge)
	for layer in [[0.35, 0.05], [1.0, 0.018]]:
		var l2: float = L * layer[0]
		var w2: float = 6.0 + l2 * 0.42
		var pts := PackedVector2Array([p0 + side * 4.0, p0 - side * 4.0, p0 + dir * l2 - side * w2, p0 + dir * l2 + side * w2])
		var c0 := Color(0.9, 0.95, 1.0, layer[1])
		var c1 := Color(0.9, 0.95, 1.0, 0.0)
		beam_fx.draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
	# dust and ice glinting where the beam crosses it, drifting slowly round the drone
	var z: float = maxf(game.cam_zoom(), 0.05)
	var span := 24.0 * Geom.M
	for m in motes:
		var w: Vector2 = m[0] + m[1] * feed_t - wp * 0.15
		var rel := Vector2(fposmod(w.x, span) - span * 0.5, fposmod(w.y, span) - span * 0.5)
		var along := rel.dot(dir)
		if along < 0.0 or along > L:
			continue
		var across := absf(rel.dot(side)) / (6.0 + along * 0.42)
		if across > 1.0:
			continue
		var k := (1.0 - along / L) * (1.0 - across * across)
		var tw := 0.6 + 0.4 * sin(feed_t * 3.0 + m[2])
		var rs := 2.2 / z
		beam_fx.draw_rect(Rect2(p0 + rel - Vector2(rs, rs) * 0.5, Vector2(rs, rs)), Color(1.4, 1.45, 1.6, 0.55 * k * tw))


func _draw_osd() -> void:
	var c := osd_c
	var vs := c.size
	var m: Vector2 = c.get_local_mouse_position() if test_mouse == Vector2.INF else test_mouse
	var dt := get_process_delta_time()
	var fb: Font = Fonts.get_font("Medium")
	var fr: Font = Fonts.get_font("Regular")
	var ink := Color(0.92, 0.95, 1.0, 0.92)
	var dim := Color(0.92, 0.95, 1.0, 0.5)
	var hot := Color(UiSkin.ACCENT)
	var d = game.drone
	var dist := INF
	for bs in _bases():
		dist = minf(dist, d.global_position.distance_to(bs[1]) / Geom.M)
	# ---- the link, top middle: what the feed is coming over
	var pt: float = game.playtime
	var tc := "T+%02d:%02d:%02d.%02d" % [int(pt / 3600.0), int(pt / 60.0) % 60, int(pt) % 60, int(fposmod(pt, 1.0) * 30.0)]
	var cx := vs.x * 0.5
	var bar := Rect2(cx - 330.0, 14.0, 660.0, 40.0)
	var over_link := bar.grow(6.0).has_point(m)
	_hover_k["link"] = Pal.damp(float(_hover_k.get("link", 0.0)), 1.0 if over_link else 0.0, 14.0, dt)
	var hl: float = _hover_k["link"]
	if hl > 0.02:
		c.draw_rect(bar, Color(0, 0, 0, 0.45 * hl))
	var y := bar.position.y + 27.0
	var rec_on := fposmod(feed_t, 1.2) < 0.75
	FastDraw.circle(c, Vector2(bar.position.x + 18.0, y - 6.0), 5.0, Color(1.0, 0.3, 0.22, 0.95 if rec_on else 0.25))
	_ot(c, fb, Vector2(bar.position.x + 30.0, y), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	_ot(c, fb, Vector2(bar.position.x + 80.0, y), "CAM-1 · R-02", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	_ot(c, fr, Vector2(bar.position.x + 210.0, y), tc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
	var bx := bar.position.x + 390.0
	var bars := int(ceil(signal_k * 5.0))
	var weak := signal_k < 0.45
	for i in 5:
		var h := 5.0 + i * 3.6
		var bc := ink if not weak else hot
		c.draw_rect(Rect2(bx + i * 7.0, y - h, 4.5, h), bc if i < bars else Color(1, 1, 1, 0.14))
	var dbm := -48.0 - (1.0 - signal_k) * 46.0 + sin(feed_t * 7.0) * 1.5
	_ot(c, fr, Vector2(bx + 44.0, y), "%d dBm" % int(dbm), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink if not weak else hot)
	_ot(c, fr, Vector2(bx + 128.0, y), "%d m  ·  %s" % [int(dist), link_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
	_ot(c, fr, Vector2(bar.end.x - 26.0, y), "▾" if hl < 0.5 else "▴", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35 + 0.5 * hl))
	if weak and fposmod(feed_t, 0.8) < 0.5:
		_ot(c, fb, Vector2(cx, bar.end.y + 22.0), Ops.w("信号弱", "SIGNAL WEAK"), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, hot)
	# the link opened out under the pointer: its history and what it is carrying
	if hl > 0.02:
		var pr := Rect2(bar.position.x, bar.end.y + 4.0, bar.size.x, 150.0 * Pal.ease_out(hl))
		c.draw_rect(pr, Color(0, 0, 0, 0.55 * hl))
		c.draw_rect(Rect2(pr.position.x, pr.end.y - 1.0, pr.size.x, 1.0), Color(1, 1, 1, 0.12 * hl))
		if pr.size.y > 60.0:
			var a := hl
			var gr := Rect2(pr.position.x + 18.0, pr.position.y + 22.0, 300.0, pr.size.y - 44.0)
			_ot(c, fr, gr.position + Vector2(0, -6), Ops.w("信号 · 近 12 秒", "LINK · LAST 12 s"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5 * a))
			c.draw_line(Vector2(gr.position.x, gr.end.y), gr.end, Color(1, 1, 1, 0.15 * a), 1.0)
			if _sig_hist.size() > 1:
				var pts := PackedVector2Array()
				for i in _sig_hist.size():
					pts.append(Vector2(gr.position.x + gr.size.x * i / float(SIG_N - 1), gr.end.y - gr.size.y * float(_sig_hist[i])))
				FastDraw.polyline(c, pts, Color(UiSkin.DATA, 0.9 * a), 1.6, true)
			var lat := 18.0 + dist * 0.35 + (1.0 - signal_k) * 90.0 + absf(sin(feed_t * 5.3)) * 4.0
			var rate := 24.0 * pow(signal_k, 1.5) + sin(feed_t * 3.1) * 0.6
			var loss := pow(1.0 - signal_k, 2.0) * 30.0
			var brg := rad_to_deg(fposmod((Dock.BAY * Geom.M - d.global_position).angle() + PI * 0.5, TAU))
			var rows := [[Ops.w("码率", "BITRATE"), "%.1f Mbps" % rate], [Ops.w("时延", "LATENCY"), "%d ms" % int(lat)],
				[Ops.w("丢包", "LOSS"), "%.1f %%" % loss], [Ops.w("天线方位", "ANTENNA"), "%03d°" % int(brg)]]
			for i in rows.size():
				var rx := pr.position.x + 350.0 + (i % 2) * 150.0
				var ry := pr.position.y + 38.0 + (i / 2) * 50.0
				_ot(c, fr, Vector2(rx, ry), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5 * a))
				_ot(c, fb, Vector2(rx, ry + 22.0), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.92 * a))
	# ---- the heading tape under the link
	var hd: float = rad_to_deg(fposmod(d.heading + PI * 0.5, TAU))
	var tape_w := 360.0
	var ty := bar.end.y + 6.0 + (154.0 * Pal.ease_out(hl) if hl > 0.02 else 0.0)
	for k in range(-30, 31, 5):
		var deg := int(round(hd / 5.0) * 5.0) + k
		var x := cx + (deg - hd) * tape_w / 60.0
		if absf(x - cx) > tape_w * 0.5:
			continue
		var fade := 1.0 - absf(x - cx) / (tape_w * 0.5)
		var big := posmod(deg, 15) == 0
		c.draw_line(Vector2(x, ty), Vector2(x, ty + (8.0 if big else 4.0)), Color(1, 1, 1, 0.45 * fade), 1.0)
		if posmod(deg, 45) == 0:
			_ot(c, fr, Vector2(x - 12, ty + 22), "%03d" % posmod(deg, 360), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5 * fade))
	c.draw_line(Vector2(cx, ty - 3), Vector2(cx, ty + 10), Color(1.0, 0.6, 0.3, 0.9), 1.6)
	# ---- the lens: its centre
	var cc := vs * 0.5
	for s2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		c.draw_line(cc + s2 * 7.0, cc + s2 * 14.0, Color(1, 1, 1, 0.22), 1.0)
	# ---- the flight HUD: viewfinder corners, tapes, flight-path marker, the target box
	_draw_flight(c, vs, fb, fr)
	# ---- round the panels: what part of the drone's picture each one is, and more under the pointer
	var rects: Dictionary = _feed_rects()
	var names := {"task": ["TASK", "任务"], "ledger": ["LEDGER", "收益"], "unit": ["UNIT R-02", "机体遥测"], "payload": ["PAYLOAD", "载荷"], "nav": ["NAV", "导航"]}
	for key in rects:
		var r: Rect2 = rects[key]
		var over := r.grow(4.0).has_point(m)
		_hover_k[key] = Pal.damp(float(_hover_k.get(key, 0.0)), 1.0 if over else 0.0, 14.0, dt)
		var k: float = _hover_k[key]
		var col := Color(1, 1, 1, 0.3 + 0.5 * k).lerp(Color(hot.r, hot.g, hot.b, 0.95), k * 0.6)
		_brackets(c, r.grow(1.0 + 4.0 * k), 12.0 + 6.0 * k, col, 1.2 + 0.6 * k)
		var label: String = names[key][0] + "  ·  " + names[key][1]
		var above: bool = r.position.y > vs.y * 0.5
		var lp := Vector2(r.position.x + 4.0, r.position.y - 12.0) if above else Vector2(r.position.x + 4.0, r.end.y + 22.0)
		_ot(c, fb, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.r, col.g, col.b, 0.6 + 0.4 * k))
		var extra := _region_line(key)
		if extra != "":
			var ep := Vector2(lp.x + fb.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, lp.y)
			_ot(c, fr, ep, extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45 + 0.5 * k))
		if key == "unit":
			_unit_dial(c, Vector2(r.end.x + 46.0, r.get_center().y), 30.0 + 4.0 * k, k)
		elif key == "nav":
			_nav_sweep(c, r, k)
		elif key == "payload":
			# the camera HUD's payload strip: each slot marked off by its own corner ticks
			var n := int(round((r.size.x + 10.0) / 142.0))
			for i in n:
				var sr := Rect2(r.position.x + i * 142.0, r.position.y + 14.0, 132.0, 70.0)
				var on: bool = game.tools.tool == i + 1
				_brackets(c, sr, 8.0, Color(hot.r, hot.g, hot.b, 0.95) if on else Color(1, 1, 1, 0.35), 1.6 if on else 1.0)


func _feed_rects() -> Dictionary:
	if feed_t - _rects_t > 0.25 or _rects_t < 0.0:
		_rects_t = feed_t
		_rects = game.hud.feed_rects() if game.hud != null and game.hud.has_method("feed_rects") else {}
	return _rects


static func _brackets(c: CanvasItem, r: Rect2, l: float, col: Color, w: float) -> void:
	for cn in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = cn[0]
		var s: Vector2 = cn[1]
		c.draw_line(p, p + Vector2(l * s.x, 0), col, w)
		c.draw_line(p, p + Vector2(0, l * s.y), col, w)


# the live line beside a panel's name
func _region_line(key: String) -> String:
	var d = game.drone
	match key:
		"task":
			var p: Vector2 = (d.global_position - Dock.BAY * Geom.M) / Geom.M
			return "X %+.1f  Y %+.1f m" % [p.x, -p.y]
		"ledger":
			var per := float(game.earned()) / maxf(float(game.playtime), 1.0) * 60.0 if game.has_method("earned") else 0.0
			return Ops.w("每分钟 %s", "%s / MIN") % Pal.money(per)
		"unit":
			var thr := clampf(_dv.length() / 900.0, 0.0, 1.0)
			return Ops.w("推力 %d%%  ·  完好 %d%%", "THRUST %d%%  ·  HULL %d%%") % [int(thr * 100.0), int(d.integrity)]
		"payload":
			var tl = game.tools
			if tl.cutting:
				var mat := ""
				if tl.cut_mat != null and str(tl.cut_mat.mat) != "":
					mat = "  ·  " + Mat.name_of(str(tl.cut_mat.mat))
				return (Ops.w("激光 · 出光", "LASER · FIRING") if tl.in_material else Ops.w("激光 · 空切", "LASER · OPEN AIR")) + mat
			if tl.held_body != null and is_instance_valid(tl.held_body):
				var m: float = tl.held_body.total_mass()
				var st: String = Ops.w("超重", "TOO HEAVY") if tl.overweight else (Ops.w("拉紧", "TAUT") if tl.tether_force > 0.25 else Ops.w("松", "SLACK"))
				return Ops.w("抓钩 · %.2f / %.1f t · %s", "GRAPPLE · %.2f / %.1f t · %s") % [m, float(game.grab_max()), st]
			if not tl.job.is_empty():
				return Ops.w("作业中", "WORKING")
			return Ops.w("待命", "READY")
		"nav":
			return Ops.w("扫描中", "SCANNING")
	return ""


# beside the unit's panel: the drone seen from above its own camera — which way it faces,
# which way it is going and how fast, the push of its jets
func _unit_dial(c: CanvasItem, p: Vector2, r: float, k: float) -> void:
	var d = game.drone
	FastDraw.arc(c, p, r, 0.0, TAU, 40, Color(1, 1, 1, 0.25 + 0.3 * k), 1.2, true)
	for i in 12:
		var a := TAU * i / 12.0
		c.draw_line(p + Vector2.from_angle(a) * (r - 3.0), p + Vector2.from_angle(a) * r, Color(1, 1, 1, 0.3), 1.0)
	var hdv := Vector2.from_angle(d.heading)
	c.draw_line(p, p + hdv * (r - 4.0), Color(1, 1, 1, 0.85), 1.6, true)
	var v: Vector2 = d.linear_velocity / Geom.M
	if v.length() > 0.05:
		var vl := clampf(v.length() / 8.0, 0.0, 1.0) * (r - 2.0)
		c.draw_line(p, p + v.normalized() * vl, Color(UiSkin.DATA, 0.95), 2.0, true)
		FastDraw.circle(c, p + v.normalized() * vl, 2.4, Color(UiSkin.DATA, 0.95))
	var push := (-_dv).limit_length(900.0) / 900.0
	if push.length() > 0.05:
		c.draw_line(p, p + push * (r - 6.0), Color(UiSkin.ACCENT, 0.8), 1.2, true)
	FastDraw.circle(c, p, 2.0, Color(1, 1, 1, 0.9))


# over the berth map: a sweep going round, the way a scanning map refreshes
func _nav_sweep(c: CanvasItem, r: Rect2, k: float) -> void:
	var ctr := r.get_center()
	var rad := r.size.length() * 0.5
	var a := fposmod(feed_t * 1.4, TAU)
	for i in 10:
		var a0 := a - i * 0.06
		var al := 0.12 * (1.0 - i / 10.0) * (0.6 + 0.4 * k)
		var tip := ctr + Vector2.from_angle(a0) * rad
		var cl := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([ctr, tip]), PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		for seg in cl:
			FastDraw.polyline(c, seg, Color(UiSkin.DATA, al), 2.0)

# OSD text: burned into the picture, outlined in black like a drone's on-screen display
static func _ot(c: CanvasItem, f: Font, pos: Vector2, s: String, al: int, w: float, size: int, col: Color) -> void:
	if col.a <= 0.01:
		return
	c.draw_string_outline(f, pos, s, al, w, size, 4, Color(0, 0, 0, 0.85 * col.a))
	c.draw_string(f, pos, s, al, w, size, col)


# user: “界面和 HUD 还是没有那种无人机的感觉” — what makes a drone's feed read as one: the
# viewfinder's corners, the speed and height tapes either side of the picture, the flight-path
# marker showing where the machine is going, and whatever the pointer rests on boxed and ranged
func _draw_flight(c: CanvasItem, vs: Vector2, fb: Font, fr: Font) -> void:
	var d = game.drone
	var ink := Color(0.92, 0.95, 1.0, 0.9)
	# the viewfinder's four corners
	# (user: the bottom-left marks overlapped) — a corner that already has a panel's own marks by
	# it is left to them
	var m := 10.0
	var rects: Dictionary = _feed_rects()
	for cn in [[Vector2(m, m), Vector2(1, 1)], [Vector2(vs.x - m, m), Vector2(-1, 1)], [Vector2(m, vs.y - m), Vector2(1, -1)], [vs - Vector2(m, m), Vector2(-1, -1)]]:
		var p: Vector2 = cn[0]
		var busy := false
		for key in rects:
			if (rects[key] as Rect2).grow(90.0).has_point(p):
				busy = true
				break
		if busy:
			continue
		var sd: Vector2 = cn[1]
		c.draw_line(p, p + Vector2(56.0 * sd.x, 0), Color(1, 1, 1, 0.42), 2.0)
		c.draw_line(p, p + Vector2(0, 56.0 * sd.y), Color(1, 1, 1, 0.42), 2.0)
	var cc := vs * 0.5
	# the tapes: speed on the left, height above the berth floor on the right
	var hs: float = d.linear_velocity.length() / Geom.M
	var alt: float = (Dock.FLOOR_Y * Geom.M - lamp_pos().y) / Geom.M
	_tape(c, Vector2(_hs_x(cc), cc.y), hs, 0.5, "HS", "m/s", true, fb, fr)
	_tape(c, Vector2(cc.x + 760.0, cc.y), alt, 1.0, "ALT", "m", false, fb, fr)
	# the flight-path marker: where the drone is heading, off the middle by its speed
	var v: Vector2 = d.linear_velocity
	var fp := cc + (v * 0.22).limit_length(160.0)
	var fa := clampf(v.length() / 60.0, 0.0, 1.0)
	# user 2026-10-28 (the cyan ring with wings: "也难看"): a small hollow diamond in the OSD's ink,
	# a dark edge under it, no wings
	if fa > 0.02:
		var col := Color(0.92, 0.95, 1.0, 0.7 * fa)
		var r := 5.5
		var dia := PackedVector2Array([fp + Vector2(0, -r), fp + Vector2(r, 0), fp + Vector2(0, r), fp + Vector2(-r, 0), fp + Vector2(0, -r)])
		FastDraw.polyline(c, dia, Color(0, 0, 0, 0.5 * fa), 3.2)
		FastDraw.polyline(c, dia, col, 1.3)
	_designator(c, cc, fb, fr)
	_job_bar(c, fb, fr)


# a measurement or a repair under way: its progress where the work is, as the OSD's segmented
# bar under the spot, with what it is and how far along (replaces the ring at the pointer)
func _job_bar(c: CanvasItem, fb: Font, fr: Font) -> void:
	var tl = game.tools
	if tl == null or tl.job.is_empty() or float(tl.job.get("dur", 0.0)) <= 0.0:
		return
	var k := clampf(float(tl.job.get("t", 0.0)) / float(tl.job.dur), 0.0, 1.0)
	var p: Vector2 = game.get_viewport().get_canvas_transform() * (tl.job.get("pos", game.drone.global_position) as Vector2)
	# the spot being worked, boxed small in the accent
	var pulse := 0.7 + 0.3 * sin(feed_t * 8.0)
	_brackets(c, Rect2(p - Vector2(13, 13), Vector2(26, 26)), 7.0, Color(0, 0, 0, 0.6), 4.0)
	_brackets(c, Rect2(p - Vector2(13, 13), Vector2(26, 26)), 7.0, Color(UiSkin.ACCENT.r, UiSkin.ACCENT.g, UiSkin.ACCENT.b, pulse), 1.8)
	var n := 12
	var w := 8.0
	var gap := 2.0
	var x0 := p.x - (n * (w + gap) - gap) * 0.5
	var y := p.y + 24.0
	for i in n:
		var r := Rect2(x0 + i * (w + gap), y, w, 6.0)
		var lit := (i + 1) / float(n) <= k + 0.0001
		c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6))
		c.draw_rect(r, Color(1, 1, 1, 0.95) if lit else Color(1, 1, 1, 0.18))
	var what := Ops.w("测量", "MEASURE") if str(tl.job.get("kind", "")) == "measure" else Ops.w("作业", "WORK")
	_ot(c, fb, Vector2(x0, y + 24.0), "%s  %d%%" % [what, int(k * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.95))


# 110 号 (the core asset board grew a "next step" line and reached down over the speed tape): the
# speed tape steps out to the right of the board while they would overlap, gliding there and back
var _hs_at := -1.0
func _hs_x(cc: Vector2) -> float:
	var home := cc.x - 760.0
	var want := home
	var ar: Rect2 = game.hud.get("asset_rect") if game.hud != null and game.hud.get("asset_rect") != null else Rect2()
	# what the tape covers: its tick numbers on the left, the reading's box on the right, its title on top
	var tape := Rect2(home - 60.0, cc.y - 170.0, 140.0, 330.0)
	if ar.has_area() and ar.grow(10.0).intersects(tape):
		want = ar.end.x + 70.0
	_hs_at = want if _hs_at < 0.0 else lerpf(_hs_at, want, 0.18)
	if absf(_hs_at - want) < 0.5:
		_hs_at = want
	return _hs_at


# a vertical tape: the scale slides past a fixed pointer holding the value
func _tape(c: CanvasItem, at: Vector2, value: float, step: float, label: String, unit: String, left: bool, fb: Font, fr: Font) -> void:
	var h := 300.0
	var px_per := 26.0 / step
	var s := 1.0 if left else -1.0
	var top := at.y - h * 0.5
	c.draw_line(Vector2(at.x, top), Vector2(at.x, top + h), Color(1, 1, 1, 0.3), 1.0)
	var first := floorf((value - h * 0.5 / px_per) / step) * step
	var k := 0
	var x := first
	while x <= value + h * 0.5 / px_per and k < 60:
		var y := at.y - (x - value) * px_per
		if y >= top and y <= top + h:
			var fade := 1.0 - absf(y - at.y) / (h * 0.5)
			var major := is_zero_approx(fposmod(x, step * 4.0)) or absf(fposmod(x + step * 0.01, step * 4.0)) < step * 0.02
			c.draw_line(Vector2(at.x, y), Vector2(at.x - s * (12.0 if major else 6.0), y), Color(1, 1, 1, 0.5 * fade), 1.0)
			if major:
				_ot(c, fr, Vector2(at.x - s * 18.0 - (36.0 if left else 0.0), y + 5.0), "%.0f" % x if step >= 1.0 else "%.1f" % x, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55 * fade))
		x += step
		k += 1
	# the pointer box holding the reading
	var bw := 70.0
	var bx := at.x + s * 8.0 - (0.0 if left else bw)
	var box := Rect2(bx, at.y - 14.0, bw, 28.0)
	c.draw_rect(box, Color(0, 0, 0, 0.45))
	c.draw_rect(box, Color(1, 1, 1, 0.75), false, 1.2)
	_ot(c, fb, Vector2(box.position.x + 8.0, at.y + 6.0), "%.1f" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.95))
	_ot(c, fr, Vector2(at.x - (bw if left else 0.0) * 0.0 + s * 8.0 - (0.0 if left else 40.0), top - 10.0), label + "  " + unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))


# the part under the pointer: boxed, named, its range from the drone and its weight
func _designator(c: CanvasItem, cc: Vector2, fb: Font, fr: Font) -> void:
	var tl = game.tools
	if tl == null or tl.hover.is_empty() or tl.tool == 2:
		return
	var h: Dictionary = tl.hover
	if not str(h.get("kind", "")) in ["piece", "inspect"] or h.get("piece") == null:
		return
	var p = h.piece
	if p.gone:
		return
	var xf: Transform2D = game.get_viewport().get_canvas_transform()
	var wp: PackedVector2Array = game.world.world_poly(p)
	if wp.is_empty():
		return
	var r := Rect2(xf * wp[0], Vector2.ZERO)
	for q in wp:
		r = r.expand(xf * q)
	r = r.grow(8.0)
	var ok: bool = h.get("ok", true)
	var hot := Color(UiSkin.ACCENT) if ok else Color(1.0, 0.35, 0.25)
	var pulse := 0.75 + 0.25 * sin(feed_t * 6.0)
	_brackets(c, r, minf(18.0, r.size.x * 0.3), Color(0, 0, 0, 0.6), 4.0)
	_brackets(c, r, minf(18.0, r.size.x * 0.3), Color(hot.r, hot.g, hot.b, pulse), 1.8)
	# the line of sight from the lens's middle to it, faint
	c.draw_line(cc, r.get_center(), Color(1, 1, 1, 0.12), 1.0)
	var d = game.drone
	var rng: float = d.global_position.distance_to(Geom.centroid(wp)) / Geom.M
	var mass: float = game.world.group_mass(p)
	_ot(c, fb, Vector2(r.position.x, r.position.y - 26.0), "TGT  " + Txt.piece_name(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))
	var line2 := "RNG %.1f m    MASS %.2f t" % [rng, mass]
	if not ok:
		line2 = game.txt(str(h.get("reason", ""))) if str(h.get("reason", "")) != "" else line2
	_ot(c, fr, Vector2(r.position.x, r.position.y - 8.0), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(hot.r, hot.g, hot.b, 0.95) if not ok else Color(1, 1, 1, 0.7))

func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.ctrl_pressed and ev.shift_pressed and ev.physical_keycode == KEY_L:
		on = not on
		if game.world != null:
			game.world.redraw_all(true)
		if game.hud != null and game.hud.has_method("show_hint"):
			game.hud.show_hint("画面：新（91 号）" if on else "画面：旧（对比用）")
		get_viewport().set_input_as_handled()


func _draw_notes() -> void:
	if notes.is_empty() or game == null:
		return
	var z: float = game.cam_zoom()
	var m: Vector2 = get_global_mouse_position()
	var all: bool = not on or (game.tools != null and game.tools.tool == 1)
	var near := 140.0 / maxf(z, 0.05)
	var far := 320.0 / maxf(z, 0.05)
	for id in notes.keys():
		if not is_instance_id_valid(id):
			notes.erase(id)
			continue
		for n in notes[id]:
			var k := 1.0 if all else 1.0 - smoothstep(near, far, (n[0] as Vector2).distance_to(m))
			if k <= 0.01:
				continue
			var c: Color = n[3]
			notes_node.draw_string(n[5], n[0], n[1], n[4], -1, n[2], Color(c.r, c.g, c.b, c.a * k))


# ---------------------------------------------------------------- a big piece comes free

# 91 号 Q5 b: the weight of it — the view draws in toward it, the kerf breathes out a cloud of
# fine grit and vapour that drifts off, a low groan of the structure letting go
func big_free(b, com: Vector2, m: float) -> void:
	var k := clampf((m - SLOW_MASS) / 12.0, 0.0, 1.0)
	game.zoom_kick = maxf(game.zoom_kick, 0.05 + 0.04 * k)
	game.kick_at = com
	var fx = game.fx
	var away: Vector2 = (b.global_position - game.SHIP_CENTER).normalized()
	for i in 14 + int(10 * k):
		var dir := away.rotated(randf_range(-1.3, 1.3))
		var at := com + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Geom.M * (1.0 + k)
		fx.puff(at, dir * randf_range(14.0, 60.0), randf_range(1.4, 2.6), randf_range(6.0, 12.0), randf_range(40.0, 90.0) * (1.0 + k), Pal.ink(randf_range(0.05, 0.11)))
	fx.ring(com, 20.0, 220.0 + 160.0 * k, 0.7, Pal.ink(0.35, 1.4), 2.0)
	fx.ring(com, 10.0, 130.0 + 90.0 * k, 0.5, Pal.heat(0.5, 2.0), 1.4)
	game.sfx.play("crack", com, 0.55 + 0.35 * k, 0.72 - 0.12 * k)


# ---------------------------------------------------------------- the console opening

# 91 号 (seamless): the terminal is the drone's screen — it opens out of the drone as a bright
# line that runs out across the view and then opens to its full height, the berth still there
# round it until it covers it; closing folds it back into the drone over the live berth.
const OPEN_T := 0.36
const CLOSE_T := 0.28
var folds: Array = []    # [clip, frame, at, t, opening, layer, done]


func screen_of(world_pos: Vector2) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	if world_pos == Vector2.INF:
		return vs * 0.5
	var p := get_viewport().get_canvas_transform() * world_pos
	return Vector2(clampf(p.x, 0.0, vs.x), clampf(p.y, 0.0, vs.y))


func console_open(layer: CanvasLayer, term: Control, at: Vector2, done: Callable) -> void:
	var clip := Control.new()
	clip.name = "Fold"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(clip)
	clip.add_child(term)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)
	var f := [clip, frame, at, 0.0, true, layer, done]
	frame.draw.connect(_draw_fold.bind(f))
	folds.append(f)
	_fold_layout(f)


func console_close(layer: CanvasLayer, at: Vector2) -> void:
	var clip: Control = layer.get_node_or_null("Fold")
	if clip == null:
		layer.queue_free()
		return
	for f in folds:
		if f[5] == layer:
			folds.erase(f)
			break
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)
	var f := [clip, frame, at, 0.0, false, layer, Callable()]
	frame.draw.connect(_draw_fold.bind(f))
	folds.append(f)
	_fold_layout(f)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


# where the opening is at: [rect of the screen shown, how bright its edge]
func _fold_rect(f: Array) -> Array:
	var vs := get_viewport().get_visible_rect().size
	var at: Vector2 = f[2]
	var k: float
	var w: float
	var h: float
	if f[4]:
		k = f[3] / OPEN_T
		w = _ease(k / 0.42)
		h = _ease((k - 0.3) / 0.7)
	else:
		k = f[3] / CLOSE_T
		h = 1.0 - _ease(k / 0.55)
		w = 1.0 - _ease((k - 0.45) / 0.55)
	var line := 2.0
	var cx := lerpf(at.x, vs.x * 0.5, w)
	var cy := lerpf(at.y, vs.y * 0.5, h)
	var rw := maxf(lerpf(0.0, vs.x, w), 2.0)
	var rh := maxf(lerpf(line, vs.y, h), line)
	return [Rect2(cx - rw * 0.5, cy - rh * 0.5, rw, rh), 1.0 - clampf(k, 0.0, 1.0)]


func _fold_layout(f: Array) -> void:
	var vs := get_viewport().get_visible_rect().size
	var clip: Control = f[0]
	var r: Rect2 = _fold_rect(f)[0]
	clip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	clip.position = r.position
	clip.size = r.size
	for ch in clip.get_children():
		if ch is Control:
			ch.set_anchors_preset(Control.PRESET_TOP_LEFT)
			ch.position = -r.position
			ch.size = vs
	(f[1] as Control).queue_redraw()


func _fold_done(f: Array) -> void:
	folds.erase(f)
	(f[1] as Control).queue_free()
	if f[4]:
		# open: the screen is the screen again, following the window as before
		var clip: Control = f[0]
		clip.set_anchors_preset(Control.PRESET_FULL_RECT)
		clip.position = Vector2.ZERO
		clip.size = get_viewport().get_visible_rect().size
		for ch in clip.get_children():
			if ch is Control:
				ch.set_anchors_preset(Control.PRESET_FULL_RECT)
				ch.position = Vector2.ZERO
				ch.size = clip.size
		if (f[6] as Callable).is_valid():
			(f[6] as Callable).call()
	else:
		(f[5] as CanvasLayer).queue_free()


func _step_folds(rdt: float) -> void:
	for f in folds.duplicate():
		if not is_instance_valid(f[0]) or not is_instance_valid(f[5]):
			folds.erase(f)
			continue
		# a long frame (the screen being built) doesn't eat the motion
		f[3] += minf(rdt, 1.0 / 30.0)
		if f[3] >= (OPEN_T if f[4] else CLOSE_T):
			_fold_done(f)
		else:
			_fold_layout(f)


func _draw_fold(f: Array) -> void:
	var fr: Control = f[1]
	var rr: Array = _fold_rect(f)
	var r: Rect2 = rr[0]
	var a: float = rr[1]
	var hot := Color(1.0, 0.62, 0.32, 0.9 * a)
	var white := Color(1.0, 0.97, 0.92, a)
	# the running line: bright core, warm halo
	if r.size.y < 6.0:
		fr.draw_rect(Rect2(r.position.x, r.get_center().y - 5.0, r.size.x, 10.0), Color(1.0, 0.55, 0.25, 0.18 * a))
		fr.draw_rect(Rect2(r.position.x, r.get_center().y - 1.0, r.size.x, 2.0), white)
		FastDraw.circle(fr, f[2], 6.0 + 10.0 * a, Color(1.0, 0.6, 0.3, 0.25 * a))
		return
	# the opening's edges, brightest at the top and bottom where it is moving
	fr.draw_rect(Rect2(r.position.x, r.position.y - 1.0, r.size.x, 2.0), white)
	fr.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 2.0), white)
	fr.draw_rect(Rect2(r.position.x, r.position.y - 6.0, r.size.x, 12.0), Color(hot.r, hot.g, hot.b, 0.12 * a))
	fr.draw_rect(Rect2(r.position.x, r.end.y - 6.0, r.size.x, 12.0), Color(hot.r, hot.g, hot.b, 0.12 * a))
	fr.draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y), hot)
	fr.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y), hot)


# ---------------------------------------------------------------- the far belt

# drawn by the backdrop right after the planet's limb: rock, darker the farther, lit on the
# side the light comes from; three layers moving at a thirtieth to a tenth of the camera
const BELT := [[0.025, 0.055, 46, 7.0], [0.05, 0.075, 30, 11.0], [0.09, 0.10, 18, 16.0]]
const BELT_TILE := Vector2(5200, 3000)
static var _belt: Array = []   # per layer: [tri points, tri colours, rim segment points, rim colours]


static func _rock(rng: RandomNumberGenerator, c: Vector2, r: float) -> PackedVector2Array:
	var n := rng.randi_range(7, 11)
	var pts := PackedVector2Array()
	var squash := rng.randf_range(0.55, 0.9)
	var rot := rng.randf() * TAU
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var rr := r * rng.randf_range(0.72, 1.08)
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * squash).rotated(rot))
	return pts


static func _build_belt() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for layer in BELT:
		var tp := PackedVector2Array()
		var tc := PackedColorArray()
		var lp := PackedVector2Array()
		var lc := PackedColorArray()
		var base: float = layer[1]
		for i in int(layer[2]):
			# the rocks lie in a band across the lower two thirds of the tile
			var c := Vector2(rng.randf() * BELT_TILE.x, BELT_TILE.y * (0.3 + 0.65 * pow(rng.randf(), 0.8)))
			var r: float = layer[3] * rng.randf_range(2.0, 9.0) * (2.2 if rng.randf() < 0.12 else 1.0)
			var poly := _rock(rng, c, r)
			var tri := Geometry2D.triangulate_polygon(poly)
			for k in tri:
				var v := poly[k]
				var lk := clampf((v - c).dot(LIGHT_DIR) / r, -1.0, 1.0)
				var g := base * (0.75 + 0.45 * lk)
				tp.append(v)
				tc.append(Color(g, g * 1.02, g * 1.12))
			# the rim on the lit side
			for j in poly.size():
				var a := poly[j]
				var b := poly[(j + 1) % poly.size()]
				var nrm := (b - a).orthogonal().normalized()
				var face := -nrm.dot(LIGHT_DIR)
				if face > 0.15:
					lp.append(a)
					lp.append(b)
					var w := base * 2.4 * face
					lc.append(Color(w, w, w * 1.05))
		_belt.append([tp, tc, lp, lc])


static func draw_far(ci: CanvasItem, cam: Vector2, z: float, view: Vector2) -> void:
	if not on:
		return
	if _belt.is_empty():
		_build_belt()
	for li in BELT.size():
		var par: float = BELT[li][0]
		var data: Array = _belt[li]
		# the layer scrolls at its own rate and repeats; drawn at screen scale round the camera
		var off: Vector2 = -cam * par * z
		off = Vector2(fposmod(off.x, BELT_TILE.x), fposmod(off.y + BELT_TILE.y * 0.15, BELT_TILE.y))
		var tl := cam - view * 0.5
		for ty in [-1, 0]:
			for tx in [-1, 0, 1]:
				var o := off + Vector2(tx, ty) * BELT_TILE
				if o.x > view.x * z or o.x + BELT_TILE.x < 0.0 or o.y > view.y * z or o.y + BELT_TILE.y < 0.0:
					continue
				ci.draw_set_transform(tl + o / z, 0.0, Vector2.ONE / z)
				RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), data[0], data[1])
				ci.draw_multiline_colors(data[2], data[3], -1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- 外部：港区（DECISIONS 外部画面定案）

const CODES := {"power": "PWR-0", "salvage": "SLV-0", "process": "PRC-0", "tug": "TUG-0", "trade": "TRD-0", "cargo": "CGO-0"}
var lamp_pool: Array = []         # the station's own lamps nearest the drone, as real lights
var _lamp_t := 0.0
var link_name := "BAY-07"         # Q2 B: the antenna the feed is coming in over


func _in_port() -> bool:
	if game == null or not game.in_berth() or game.drone == null:
		return false
	var b := Rect2(Dock.BOUNDS.position * Geom.M, Dock.BOUNDS.size * Geom.M)
	return not b.has_point(game.drone.global_position)


# the bases the drone's link can ride: the berth's own mast, and in the port each district's
func _bases() -> Array:
	var out: Array = [["BAY-07", Dock.BAY * Geom.M]]
	if game != null and game.in_berth() and game.career() and not PortArt.lamps.is_empty():
		for z in CODES:
			out.append([CODES[z], PortStructure.box(z).get_center()])
	return out


func _step_lamps(rdt: float, on_site: bool) -> void:
	if lamp_pool.is_empty():
		for i in 6:
			var l := _light(Color(1, 1, 1), 0.8, 6.0)
			lamp_pool.append(l)
	_lamp_t -= rdt
	if _lamp_t > 0.0:
		return
	_lamp_t = 0.25
	var use := on_site and _in_port() and Txt.quality == "high"
	var near: Array = []
	if use:
		var dp: Vector2 = game.drone.global_position
		for l in PortArt.lamps:
			var d: float = (l[0] as Vector2).distance_to(dp)
			if d < 60.0 * Geom.M:
				near.append([d, l])
		near.sort_custom(func(a, b): return a[0] < b[0])
	for i in lamp_pool.size():
		var pl: PointLight2D = lamp_pool[i]
		if i < near.size():
			var l: Array = near[i][1]
			pl.enabled = true
			pl.position = l[0]
			var c: Color = l[2]
			pl.color = Color(clampf(c.r, 0.3, 1.0), clampf(c.g, 0.3, 1.0), clampf(c.b, 0.3, 1.0))
			pl.texture_scale = maxf(float(l[1]) * 3.0, 8.0 * Geom.M) * 2.0 / _soft.get_width()
			pl.energy = 0.75
		else:
			pl.enabled = false


# drawn by the backdrop under the port's lines: the station as solid blocks — each district's
# shell, the ring, the spokes — lit from the same side as everything else
static func draw_station(ci: CanvasItem) -> void:
	if not on:
		return
	var M := PortStructure.M()
	var c := PortStructure.centre()
	# the spokes first, under the blocks
	for z in CODES:
		if z == "salvage":
			continue
		var to: Vector2 = PortStructure.box(z).get_center()
		ci.draw_line(c, to, Color(0.055, 0.058, 0.066), PortStructure.HALF * 2.0 * M)
	for z in CODES:
		# the salvage district is the berth itself: its look stays as it was approved
		if z == "salvage":
			continue
		var r: Rect2 = PortStructure.box(z)
		var hi := Color(0.13, 0.135, 0.15)
		var lo := Color(0.05, 0.052, 0.06)
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		ci.draw_polygon(pts, PackedColorArray([hi, hi.lerp(lo, 0.45), lo, hi.lerp(lo, 0.55)]))
		# a lit top edge and a shadowed bottom edge give the block its thickness
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 0.5 * M)), Color(0.24, 0.245, 0.27))
		ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 0.6 * M), Vector2(r.size.x, 0.6 * M)), Color(0.025, 0.026, 0.03))
	# the ring: an outer wall, the inner ring, the core
	FastDraw.circle(ci, c, PortArt.HUB_R * M, Color(0.085, 0.088, 0.1))
	FastDraw.arc(ci, c, PortArt.HUB_R * M - 0.4 * M, PI * 0.95, PI * 1.75, 48, Color(0.22, 0.225, 0.25), 0.8 * M, true)
	FastDraw.circle(ci, c, PortArt.HUB_R2 * M, Color(0.05, 0.052, 0.06))
	FastDraw.circle(ci, c, PortArt.CORE_R * M, Color(0.11, 0.115, 0.13))


# ---------------------------------------------------------------- 外部：船的外观（外部画面定案 Q4 a+b+c）

var ship_fx: Node2D
var _ship_t := 0.0
var _ship_bb := Rect2()
var _bow := Vector2.INF            # the hull's foremost and aftmost corners, where its lights sit
var _stern := Vector2.INF
var _nozzles: Array = []          # nozzle pieces still on the hull
var _powered := false
var _ship_dirty := true          # the hull's ends and nozzles found again only when a piece comes off
var _ship_wpos := Vector2.INF


func _ensure_ship_fx() -> void:
	if ship_fx != null:
		return
	ship_fx = Node2D.new()
	ship_fx.name = "ShipLights"
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ship_fx.material = m
	ship_fx.draw.connect(_draw_ship_fx)
	add_child(ship_fx)
	if game.world != null:
		game.world.piece_freed.connect(func(_b) -> void: _ship_dirty = true)


func _step_ship(rdt: float) -> void:
	_ensure_ship_fx()
	var w = game.world
	ship_fx.visible = on and w != null and not w.order.is_empty() and game.dock != null and game.dock.visible
	if not ship_fx.visible:
		return
	_ship_t -= rdt
	if _ship_t <= 0.0:
		_ship_t = 1.0
		# 60 FPS (ARK-01: walking its 2,000 parts every second was a spike): the hull's ends and
		# its nozzles again only after a piece has come off
		# (and while the hull is still being pushed in, it moves)
		if _ship_dirty or w.position != _ship_wpos:
			_ship_wpos = w.position
			_ship_scan(w)
		_powered = false
		if game.sys != null:
			for k in game.sys.src:
				var e: Dictionary = game.sys.src[k]
				if bool(e.get("running", false)) or float(e.get("charge", 0.0)) > 0.05:
					_powered = true
					break
	ship_fx.queue_redraw()


# where the hull is now and which nozzles are still on it
func _ship_scan(w) -> void:
	_ship_dirty = false
	var bb := Rect2()
	var first := true
	_bow = Vector2.INF
	_stern = Vector2.INF
	_nozzles.clear()
	for id in w.order:
		var p = w.pieces[id]
		if p.gone or p.body != null:
			continue
		if p.kind in ["hull", "keel", "hatch"]:
			var wpoly: PackedVector2Array = w.frame(p) * p.poly
			var pb := Geom.bbox(wpoly)
			bb = pb if first else bb.merge(pb)
			first = false
			for v in wpoly:
				if _bow == Vector2.INF or v.x < _bow.x - 0.5 or (absf(v.x - _bow.x) <= 0.5 and v.y < _bow.y):
					_bow = v
				if _stern == Vector2.INF or v.x > _stern.x + 0.5 or (absf(v.x - _stern.x) <= 0.5 and v.y < _stern.y):
					_stern = v
		if p.art in ["nozzle", "engine_s", "eng_front"] and p.cls == "equip":
			_nozzles.append(p)
	_ship_bb = bb


func _draw_ship_fx() -> void:
	var t := feed_t
	var w = game.world
	# b: the navigation lights at the hull's two ends — only with power aboard; a dead ship is dark
	if _powered and _bow != Vector2.INF and _stern != Vector2.INF:
		var bow := _bow
		var stern := _stern
		var ph := fposmod(t, 1.6)
		var red := 1.0 if ph < 0.08 or (ph > 0.22 and ph < 0.3) else 0.0
		var wht := 1.0 if fposmod(t + 0.8, 1.6) < 0.06 else 0.0
		for spot in [[bow, Color(1.6, 0.25, 0.18), red], [stern, Color(1.6, 1.6, 1.7), wht]]:
			var k: float = spot[2]
			var c: Color = spot[1]
			FastDraw.circle(ship_fx, spot[0], 3.6, Color(c.r, c.g, c.b, 0.55 + 0.45 * k))
			if k > 0.0:
				ship_fx.draw_texture_rect(_soft, Rect2(spot[0] - Vector2(28, 28), Vector2(56, 56)), false, Color(c.r, c.g, c.b, 0.45 * k))
	# c: the nozzles still holding the heat of the last burn, cooling as the job goes on
	var heat := exp(-float(game.playtime) / 900.0)
	if heat > 0.05:
		for p in _nozzles:
			if p.gone or p.body != null:
				continue
			var pb := Geom.bbox(w.frame(p) * p.poly)
			var breathe := 0.85 + 0.15 * sin(t * 0.9 + p.id)
			ship_fx.draw_texture_rect(_soft, pb.grow(pb.size.length() * 0.15), false, Color(1.0, 0.38, 0.12, 0.22 * heat * breathe))
