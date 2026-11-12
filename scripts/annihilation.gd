extends Node2D
# AX-40 逆火 · the antimatter trap losing its power (design/新船点子_10艘_详细版_20261111.md §4; user
# 2026-11-11: "反物质要设计成核弹一样，只要一断电，正反物质马上爆炸；特效要做得特别华丽，和核弹
# 完全不同"). The detonation (scripts/nuke.gd) is brute force — white flash, fireball, debris shell,
# every district burnt; this is the opposite: precise, cold, beautiful. Cold white, cyan, pale violet;
# a little warm orange only at the very end.
#   unbind    0.0–0.6  the trap's breathing ring goes out segment by segment, the field lines writhe,
#                      knot and snap; the world slows
#   collapse  0.6–1.2  everything is drawn in toward one point and wound round it (scripts/look_post
#                      a_pull), a thin lens ring, light and grit streaming in; the sound sucked out
#   bang      1.2–1.5  a pin-point star, not a fireball; one razor-thin shell of light races out and
#                      prints the hull as a negative for a frame
#   spectrum  1.5–4.0  the signature: thousands of electron–positron pairs curling out in the field
#                      left behind, a bubble-chamber photograph drawn live, pion tracks straight through
#   afterglow 4.0–7.4  the berth burnt into glowing outlines that go out cell by cell, the ship's ghost
#                      edge by edge; a slow violet ring opening far out; last, a few warm embers
#   card      black: what is lost; any key carries on to the settlement (as the detonation's)
# The tracks are baked once into one mesh (prebake(), on a worker thread when an AX-40 is loaded)
# and played back by scripts/anni_tracks.gdshader: the CPU only sets a time each frame.
# Any key or click past the first second skips to the card. Settles like the detonation: the drone
# and the berth are lost, the berth is rebuilt (game.end_nuke), the contract fails.

const M := 48.0
const T_UNBIND := 0.6
const T_BANG := 1.2
const T_SPEC := 1.5
const T_GLOW := 4.0
const T_CARD := 7.6
const T_FADE := 0.9
const SHELL_V := 520.0        # m/s on screen: the gamma shell
const PAIR_V := 140.0         # m/s: how far out the photons convert, as time
const R_RING := 1.9           # m: the trap's indicator ring (scripts/antimatter.gd RING_R)
const FINE := 300000.0        # 【占位】 the antimatter accident's fine
const BERTH_REBUILD := 250000.0
const N_PAIRS := 820
const N_SINGLE := 220
const N_PIONS := 34

# baked once per run (the tracks don't depend on the ship: local to the trap)
static var _task := -1
static var _arrays: Array = []
static var _mesh: ArrayMesh = null

var game
var at := Vector2.ZERO
var t := 0.0
var card := false
var finished := false
var layer: CanvasLayer         # the overlay: flash, letterbox, captions, violet ring, embers, card
var ui: Control
var fx_layer: CanvasLayer      # world space above the post pass: the tracks, the star, the shell
var fx_node: Node2D
var tracks: MeshInstance2D
var tracks_halo: MeshInstance2D
var ghost: MeshInstance2D
var ghost_halo: MeshInstance2D
var mats: Array = []
var lobes: Array = []          # the field lines: PackedVector2Array each, local
var motes: Array = []          # [angle, r0, spin, len, phase]
var embers: Array = []         # [offset (local), drift, phase, size]
var cues := {}
var _hidden := false
var _shake_bang := false
var _post: ShaderMaterial
var _zc := 1.0


# ---------------------------------------------------------------- the baked spectrum

static func prebake() -> void:
	if _mesh != null or _task >= 0:
		return
	_task = WorkerThreadPool.add_task(_bake, false, "anni_tracks")


# the first draw of a new material compiles its pipeline (a 40–100 ms hitch): drawn once, off to
# the side and with nothing passing its time test, while the ship is still being looked over
static func warm(parent: Node) -> void:
	var m := track_mesh()
	var cl := CanvasLayer.new()
	cl.layer = 16
	parent.add_child(cl)
	for halo in [false, true]:
		var mi := MeshInstance2D.new()
		mi.mesh = m
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://scripts/anni_tracks.gdshader")
		mat.set_shader_parameter("halo", 1.0 if halo else 0.0)
		mat.set_shader_parameter("T", 0.0)
		mi.material = mat
		cl.add_child(mi)
	var tree := parent.get_tree()
	for i in 3:
		await tree.process_frame
	if is_instance_valid(cl):
		cl.queue_free()


static func _bake() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	var polys: Array = []      # [pts, taus, kind, par, col, halfw]
	for i in N_PAIRS:
		var th := rng.randf() * TAU
		var r0 := 0.0 if rng.randf() < 0.12 else minf(-log(1.0 - rng.randf() * 0.995) * 8.0, 30.0)
		var tb := T_BANG + 0.03 + r0 / PAIR_V + (rng.randf() * rng.randf() * 1.1 if rng.randf() < 0.45 else 0.0)
		var e := clampf(exp(rng.randfn(1.25, 0.7)), 0.35, 20.0)
		var u := rng.randf_range(0.12, 0.88)
		var p0 := Vector2.from_angle(th) * r0 * M
		var op := rng.randf_range(0.01, 0.07)
		polys.append(_spiral(rng, p0, th + op, e * u * M, 1.0, tb, 0))
		polys.append(_spiral(rng, p0, th - op, e * (1.0 - u) * M, -1.0, tb, 1))
	for i in N_SINGLE:
		var th := rng.randf() * TAU
		var r0 := minf(-log(1.0 - rng.randf() * 0.995) * 7.0, 28.0)
		var tb := T_BANG + 0.03 + r0 / PAIR_V + rng.randf() * 0.5
		var kd := rng.randi() % 2
		polys.append(_spiral(rng, Vector2.from_angle(th) * r0 * M, th + rng.randf_range(-1.2, 1.2), rng.randf_range(0.25, 1.8) * M, 1.0 if kd == 0 else -1.0, tb, kd))
	for i in N_PIONS:
		var th := TAU * (i + rng.randf() * 0.8) / N_PIONS
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		var L := rng.randf_range(45.0, 130.0) * M
		var pi_ := _arc(rng, Vector2.from_angle(th) * 0.3 * M, th, rng.randf_range(250.0, 800.0) * M, sgn, L, T_BANG + 0.02, rng.randf_range(0.28, 0.5), 2, rng.randf_range(0.9, 1.5), Color(0.62, 0.66, 0.74), 0.7)
		var pts: PackedVector2Array = pi_[0]
		var taus: PackedFloat32Array = pi_[1]
		# the decay: a kink and a fainter muon carrying on
		if rng.randf() < 0.35:
			var k := int(pts.size() * rng.randf_range(0.35, 0.8))
			var dir := (pts[k] - pts[k - 1]).angle() + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.18, 0.55)
			pi_[0] = pts.slice(0, k + 1)
			pi_[1] = taus.slice(0, k + 1)
			polys.append(_arc(rng, pts[k], dir, rng.randf_range(120.0, 300.0) * M, -sgn, rng.randf_range(25.0, 70.0) * M, taus[k], rng.randf_range(0.3, 0.6), 2, rng.randf_range(0.8, 1.3), Color(0.5, 0.6, 0.72), 0.6))
		polys.append(pi_)
		# knock-on electrons: tiny tight curls off the pion's track
		for j in rng.randi_range(0, 3):
			var q := rng.randi_range(2, (pi_[0] as PackedVector2Array).size() - 2)
			var pp: PackedVector2Array = pi_[0]
			var dd := (pp[q + 1] - pp[q]).angle() + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.9, 1.4)
			polys.append(_spiral(rng, pp[q], dd, rng.randf_range(0.2, 0.8) * M, -1.0 if rng.randf() < 0.5 else 1.0, (pi_[1] as PackedFloat32Array)[q], 1))
	_arrays = _assemble(polys)


# a charged track losing energy in the field: its radius shrinks as it goes, a tightening spiral
static func _spiral(rng: RandomNumberGenerator, p0: Vector2, ang: float, r0: float, sgn: float, tb: float, kind: int) -> Array:
	r0 = maxf(r0, 6.0)
	var rmin := maxf(r0 * rng.randf_range(0.07, 0.14), 3.0)
	var L := r0 * rng.randf_range(1.4, 3.0)
	var S := L * log(r0 / rmin)
	var tg := rng.randf_range(0.55, 1.4) * clampf(sqrt(S / (20.0 * M)), 0.45, 1.6)
	var pts := PackedVector2Array([p0])
	var taus := PackedFloat32Array([tb])
	var s := 0.0
	var p := p0
	var n := 0
	while s < S and n < 360:
		var R := r0 * exp(-s / L)
		var ds := clampf(R * 0.25, 2.0, 0.35 * M)
		ang += sgn * ds / R + rng.randfn(0.0, 0.006)
		p += Vector2(cos(ang), sin(ang)) * ds
		s += ds
		n += 1
		pts.append(p)
		taus.append(tb + tg * pow(minf(1.0, s / S), 0.55))
	var col := Color(0.5, 0.78, 0.95) if kind == 0 else Color(0.7, 0.62, 0.95)
	col *= rng.randf_range(0.45, 0.85)
	return [pts, taus, kind, rng.randf_range(0.55, 1.3), col, 0.65]


# a fast heavy track: hardly bent, no slowing to speak of
static func _arc(rng: RandomNumberGenerator, p0: Vector2, ang: float, R: float, sgn: float, length: float, tb: float, tg: float, kind: int, par: float, col: Color, w: float) -> Array:
	var pts := PackedVector2Array([p0])
	var taus := PackedFloat32Array([tb])
	var s := 0.0
	var p := p0
	var ds := 1.2 * M
	while s < length:
		ang += sgn * ds / R + rng.randfn(0.0, 0.002)
		p += Vector2(cos(ang), sin(ang)) * ds
		s += ds
		pts.append(p)
		taus.append(tb + tg * (s / length))
	return [pts, taus, kind, par, col, w]


# polylines into one strip mesh: two vertices a point, offset along the normal in the shader
static func _assemble(polys: Array) -> Array:
	var nv := 0
	var ni := 0
	for pl in polys:
		var n: int = (pl[0] as PackedVector2Array).size()
		if n < 2:
			continue
		nv += n * 2
		ni += (n - 1) * 6
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var cu := PackedFloat32Array()
	var idx := PackedInt32Array()
	v.resize(nv)
	uv.resize(nv)
	col.resize(nv)
	cu.resize(nv * 4)
	idx.resize(ni)
	var k := 0
	var q := 0
	for pl in polys:
		var pts: PackedVector2Array = pl[0]
		var taus: PackedFloat32Array = pl[1]
		var n := pts.size()
		if n < 2:
			continue
		var kind := float(pl[2])
		var par := float(pl[3])
		var c: Color = pl[4]
		var w := float(pl[5])
		var base := k
		for i in n:
			var tg := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			var nr := tg.orthogonal().normalized() * w
			v[k] = pts[i]
			v[k + 1] = pts[i]
			uv[k] = nr
			uv[k + 1] = -nr
			col[k] = c
			col[k + 1] = c
			var o := k * 4
			cu[o] = taus[i]
			cu[o + 1] = kind
			cu[o + 2] = par
			cu[o + 3] = 1.0
			cu[o + 4] = taus[i]
			cu[o + 5] = kind
			cu[o + 6] = par
			cu[o + 7] = 0.0
			k += 2
		for i in n - 1:
			var a := base + i * 2
			idx[q] = a
			idx[q + 1] = a + 1
			idx[q + 2] = a + 2
			idx[q + 3] = a + 1
			idx[q + 4] = a + 3
			idx[q + 5] = a + 2
			q += 6
	return [v, uv, col, cu, idx]


static func _make_mesh(arr: Array) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = arr[0]
	a[Mesh.ARRAY_TEX_UV] = arr[1]
	a[Mesh.ARRAY_COLOR] = arr[2]
	a[Mesh.ARRAY_CUSTOM0] = arr[3]
	a[Mesh.ARRAY_INDEX] = arr[4]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return m


# the AX-40 left (or the game is closing): the baked spectrum is let go (about 20 MB); an
# unfinished bake is waited for first
static func release() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_arrays = []
	_mesh = null


static func track_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	if _task < 0:
		_bake()
	else:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mesh = _make_mesh(_arrays)
	_arrays = []
	return _mesh


# the ship's ghost: every piece's outline as its own short strokes, lit as the shell passes and put
# out one by one, the far ones last
func _ghost_mesh() -> ArrayMesh:
	var w = game.world
	var polys: Array = []
	var dmax := 1.0
	var segs: Array = []
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		var wp: PackedVector2Array = w.world_poly(p)
		var n := wp.size()
		if n < 3:
			continue
		var step := maxi(1, n / 18)
		var prev := wp[0] - at
		for i in range(step, n + step, step):
			var cur := wp[i % n] - at
			if prev.distance_to(cur) > 2.0:
				segs.append([prev, cur])
				dmax = maxf(dmax, cur.length())
			prev = cur
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for s in segs:
		var mid: Vector2 = (s[0] + s[1]) * 0.5
		var dk := mid.length() / dmax
		var lit := T_BANG + mid.length() / (SHELL_V * M)
		var out := T_GLOW + 0.5 + 1.6 * dk + rng.randf() * 1.3
		polys.append([PackedVector2Array([s[0], s[1]]), PackedFloat32Array([lit, lit]), 3, out, Color(0.5, 0.88, 1.0), 0.8])
	if polys.is_empty():
		return null
	return _make_mesh(_assemble(polys))


# ---------------------------------------------------------------- setup

func setup(g, at_: Vector2) -> void:
	game = g
	at = at_
	z_index = 100
	z_as_relative = false
	game.slowmo = 0.0
	Look.time_k(0.25)
	game.tools.release_grab(false)
	if game.tools.cutting:
		game.tools._finish_cut()
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	_zc = vs.y / (22.0 * M)
	_post = game.look.post_mat if game.look != null else null
	# the field lines round the ring magnet: dipole lobes above and below the trap
	for j in 6:
		var L := (4.2 + j * 1.9) * M
		for side in [1.0, -1.0]:
			var pl := PackedVector2Array()
			for i in 73:
				var ph := lerpf(0.12, PI - 0.12, i / 72.0)
				var r := L * sin(ph) * sin(ph)
				pl.append(Vector2(cos(ph) * r * 1.25, -side * sin(ph) * r))
			lobes.append(pl)
	for i in 420:
		motes.append([randf() * TAU, randf_range(5.0, 30.0) * M, randf_range(0.6, 2.2) * (1.0 if randf() < 0.75 else -1.0), randf_range(0.2, 1.2) * M, randf()])
	for i in 16:
		embers.append([Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 16.0 * M, Vector2.from_angle(randf() * TAU) * randf_range(4.0, 22.0), randf() * TAU, randf_range(0.6, 1.6)])
	# above the post pass, in the world's own frame: the spectrum, the ghost, the star and its shell
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 16
	fx_layer.follow_viewport_enabled = true
	add_child(fx_layer)
	var gm := _ghost_mesh()
	var tm := track_mesh()
	ghost_halo = _mesh_node(gm, true, 5.0, 0.12)
	ghost = _mesh_node(gm, false, 1.0, 1.0)
	tracks_halo = _mesh_node(tm, true, 4.5, 0.06)
	tracks = _mesh_node(tm, false, 1.0, 1.0)
	fx_node = Node2D.new()
	fx_node.draw.connect(_draw_fx)
	fx_layer.add_child(fx_node)
	layer = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)
	_cue("anni_unbind")


func _mesh_node(m: Mesh, halo: bool, wk: float, gain: float) -> MeshInstance2D:
	var mi := MeshInstance2D.new()
	mi.mesh = m
	mi.position = at
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/anni_tracks.gdshader")
	mat.set_shader_parameter("halo", 1.0 if halo else 0.0)
	mat.set_shader_parameter("width_k", wk)
	mat.set_shader_parameter("gain", gain)
	mat.set_shader_parameter("T", 0.0)
	mi.material = mat
	mi.visible = false
	fx_layer.add_child(mi)
	mats.append(mat)
	return mi


# sound hooks: placeholders until the AI-made cues are dropped into assets/audio (anni_*.ogg);
# a missing cue is silent (scripts/sfx.gd play)
func _cue(name: String, vol: float = 1.0) -> void:
	if cues.has(name):
		return
	cues[name] = t
	if game.sfx != null:
		game.sfx.play(name, Vector2.INF, vol, 1.0)


# ---------------------------------------------------------------- every frame

func step(dt: float) -> void:
	if finished:
		return
	t += dt
	if t >= T_UNBIND:
		_cue("anni_collapse")
	if t >= T_BANG:
		_cue("anni_flash")
		if not _shake_bang:
			_shake_bang = true
			Look.time_k(1.0)
			game.shake(0.9)
	if t >= T_SPEC:
		_cue("anni_spectrum")
	if t >= T_GLOW:
		_cue("anni_afterglow")
	if t > T_BANG + 0.05 and not _hidden:
		_hidden = true
		game.world.visible = false
		if game.drone.alive:
			game.drone.alive = false
			game.incident("drone_lost")
		game.drone.visible = false
	if t >= T_CARD and not card:
		card = true
		game.dock.visible = false
		_cue("anni_card")
	_camera()
	var z: float = maxf(0.005, game.cam_zoom())
	var on := t >= T_BANG
	for mi in [tracks, tracks_halo, ghost, ghost_halo]:
		if mi != null:
			mi.visible = on and mi.mesh != null
	var tf := 1.0 - clampf((t - 3.6) / 1.4, 0.0, 1.0)
	for m in mats:
		m.set_shader_parameter("T", t)
		m.set_shader_parameter("zoom", z)
	(tracks.material as ShaderMaterial).set_shader_parameter("fade", tf)
	(tracks_halo.material as ShaderMaterial).set_shader_parameter("fade", tf)
	fx_layer.visible = t < T_CARD + T_FADE
	_post_params(z)
	queue_redraw()
	fx_node.queue_redraw()
	ui.queue_redraw()


func _camera() -> void:
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var z := _zc
	if t < T_UNBIND:
		z = _zc * lerpf(1.0, 1.1, Pal.ease_io(t / T_UNBIND))
	elif t < T_BANG:
		var u := (t - T_UNBIND) / (T_BANG - T_UNBIND)
		z = _zc * lerpf(1.1, 1.38, u * u)
	elif t < T_SPEC:
		z = _zc * 1.38
	elif t < T_GLOW:
		z = lerpf(_zc * 1.38, vs.y / (56.0 * M), Pal.ease_out((t - T_SPEC) / (T_GLOW - T_SPEC)))
	else:
		z = lerpf(vs.y / (56.0 * M), vs.y / (86.0 * M), Pal.ease_io(clampf((t - T_GLOW) / (T_CARD - T_GLOW), 0.0, 1.0)))
	game.cam_override = at
	game.zoom_override = z


func _post_params(z: float) -> void:
	if _post == null:
		return
	var vp: Viewport = game.get_viewport()
	var vs: Vector2 = vp.get_visible_rect().size
	var ct: Transform2D = vp.get_canvas_transform()
	var sp: Vector2 = ct * at
	_post.set_shader_parameter("a_c", sp / vs)
	var pull := 0.0
	if t > 0.5 and t < T_BANG:
		var u := (t - 0.5) / (T_BANG - 0.5)
		pull = u * u * u
	elif t >= T_BANG and t < T_BANG + 0.3:
		pull = -0.9 * (1.0 - (t - T_BANG) / 0.3)
	_post.set_shader_parameter("a_pull", pull)
	# the shell's negative: on for the first frames as it races out over the hull
	var inv := 1.0 if t >= T_BANG and t < T_BANG + 0.045 else 0.0
	_post.set_shader_parameter("a_inv", inv)
	_post.set_shader_parameter("a_inv_r", (t - T_BANG + 0.02) * SHELL_V * M * z / vs.y)
	var dark := 0.0
	if t >= T_BANG + 0.045:
		dark = clampf((t - T_BANG - 0.045) / 0.15, 0.0, 1.0)
	_post.set_shader_parameter("a_dark", dark)
	_post.set_shader_parameter("a_edge", clampf((t - 3.7) / 0.7, 0.0, 1.0))
	_post.set_shader_parameter("a_cut", clampf((t - 4.7) / 2.4, 0.0, 1.05))
	var inv_ct := ct.affine_inverse()
	var wo: Vector2 = inv_ct * Vector2.ZERO
	_post.set_shader_parameter("a_wo", wo)
	_post.set_shader_parameter("a_ws", (inv_ct * vs) - wo)
	_post.set_shader_parameter("a_wc", at)
	_post.set_shader_parameter("a_rmax", 70.0 * M)


func _clear_post() -> void:
	if _post == null:
		return
	for k in ["a_pull", "a_inv", "a_dark", "a_edge", "a_cut"]:
		_post.set_shader_parameter(k, 0.0)


func _exit_tree() -> void:
	_clear_post()
	# left mid-way (a menu, a test): the world's clock back to normal
	Look.time_k(1.0)


# ---------------------------------------------------------------- drawn in the world (under the post pass)

func _draw() -> void:
	if t >= T_BANG + 0.05:
		return
	var z: float = maxf(0.005, game.cam_zoom())
	var px := 1.0 / z
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	# the trap's ring: lit segments breathing, put out one after another round the ring
	var nseg := 18
	for i in nseg:
		var a0 := TAU * i / nseg - PI * 0.5
		var a1 := a0 + TAU / nseg * 0.82
		var off_t := 0.04 + 0.46 * float(i) / nseg
		var col: Color
		if t < off_t:
			var br := 0.85 + 0.15 * sin(t * 2.2)
			col = Color(0.45 * br, 0.95 * br, 1.5 * br, 1.0)
		elif t < off_t + 0.06:
			col = Color(2.6, 2.8, 3.0, 1.0)
		else:
			col = Color(0.12, 0.14, 0.18, 1.0)
		draw_arc(at, R_RING * M, a0, a1, 10, col, 3.0 * px)
	if tex != null and t < 0.5:
		var gr := R_RING * M * 1.6
		draw_texture_rect(tex, Rect2(at - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(0.4, 0.75, 1.2, 0.35 * (1.0 - t / 0.5)))
	# the field lines: smooth loops, then writhing, knotting, snapping into loose ends
	var k := clampf((t - 0.08) / 0.5, 0.0, 1.0)
	var brk := clampf((t - 0.3) / 0.45, 0.0, 0.92)
	var fa := clampf(1.0 - (t - 0.85) / 0.35, 0.0, 1.0)
	if fa > 0.0:
		var seg := PackedVector2Array()
		var segc := PackedColorArray()
		for li in lobes.size():
			var pl: PackedVector2Array = lobes[li]
			var knot_u := fposmod(li * 0.37 + 0.2, 0.6) + 0.2
			var prev := Vector2.ZERO
			for i in pl.size():
				var u := float(i) / (pl.size() - 1)
				var b := pl[i]
				var nrm := b.normalized().orthogonal()
				var wob := sin(u * 23.0 + li * 1.7 + t * 9.0) * 0.6 + sin(u * 51.0 - t * 14.0 + li) * 0.35
				var p := at + b + nrm * wob * k * 0.9 * M
				var kb := exp(-pow((u - knot_u) / 0.05, 2.0)) * k
				var wa := u * 90.0 + t * 20.0
				p += Vector2(cos(wa), sin(wa)) * kb * 0.55 * M
				if i > 0:
					var h := fposmod(sin(li * 12.9898 + i * 78.233) * 43758.5453, 1.0)
					if h >= brk:
						seg.append_array([prev, p])
						var hot := 1.0 + 1.6 * k * kb
						segc.append(Color(0.45 * hot, 0.8 * hot, 1.15 * hot, 0.55 * fa))
				prev = p
		if not seg.is_empty():
			draw_multiline_colors(seg, segc, 1.4 * px)
	# the collapse: grit and light streaming in, winding round, faster as it goes
	if t > 0.45 and t < T_BANG + 0.02:
		var u := clampf((t - 0.45) / (T_BANG - 0.45), 0.0, 1.0)
		var ms := PackedVector2Array()
		var mc := PackedColorArray()
		for m in motes:
			var uu := clampf(u * (0.8 + 0.4 * float(m[4])), 0.0, 1.0)
			var rk := pow(1.0 - uu, 2.2)
			var r := float(m[1]) * rk
			if r < 4.0:
				continue
			var a := float(m[0]) + float(m[2]) * (1.0 - rk) * 2.4
			var dir := Vector2(cos(a), sin(a))
			var p := at + dir * r
			var tail := dir.rotated(float(m[2]) * 0.25) * minf(float(m[3]) * (0.4 + 3.0 * uu), r * 0.6)
			ms.append_array([p, p + tail])
			var hot := 0.6 + 1.8 * uu
			mc.append(Color(0.55 * hot, 0.8 * hot, 1.2 * hot, 0.7))
		if not ms.is_empty():
			draw_multiline_colors(ms, mc, 1.3 * px)
		# the heart growing tight and bright before it goes
		if tex != null:
			var cr := maxf(0.5, 2.6 * (1.0 - u)) * M
			draw_texture_rect(tex, Rect2(at - Vector2(cr, cr), Vector2(cr, cr) * 2.0), false, Color(0.6, 0.6, 1.4, 0.25 + 0.6 * u))


# ---------------------------------------------------------------- the star and the shell (above the post pass)

func _draw_fx() -> void:
	if t < T_BANG:
		return
	var z: float = maxf(0.005, game.cam_zoom())
	var px := 1.0 / z
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	var age := t - T_BANG
	# the pin-point star: tiny and searing, thin diffraction spikes, dying away under the spectrum
	var sk := exp(-age / 0.35)
	var sl := exp(-age / 2.0)
	if tex != null:
		var r1 := 70.0 * px * (0.5 + sk)
		fx_node.draw_texture_rect(tex, Rect2(at - Vector2(r1, r1), Vector2(r1, r1) * 2.0), false, Color(0.45, 0.75, 1.3, 0.55 * sl))
		var r2 := 9.0 * px
		fx_node.draw_texture_rect(tex, Rect2(at - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(3.0, 3.2, 3.6, minf(1.0, 0.4 + sl)))
	fx_node.draw_circle(at, 2.2 * px, Color(4.0, 4.2, 4.6, minf(1.0, 0.3 + sl)))
	var spikes := PackedVector2Array()
	var sc := PackedColorArray()
	for i in 6:
		var a := i * PI / 3.0 + 0.26
		var L := (520.0 * sk + 90.0 * sl) * px * (1.0 if i % 3 == 0 else 0.55)
		var d := Vector2(cos(a), sin(a))
		spikes.append_array([at, at + d * L, at, at - d * L])
		var c := Color(1.4, 1.7, 2.3, 0.75 * (0.3 + sk))
		sc.append_array([c, c])
	fx_node.draw_multiline_colors(spikes, sc, 1.2 * px)
	# the gamma shell: one razor-thin ring of light, a violet fringe just behind it
	var R := age * SHELL_V * M
	if age < 0.45:
		var sa := 1.0 - age / 0.45
		fx_node.draw_arc(at, R, 0.0, TAU, 256, Color(0.6, 0.9, 1.3, 0.14 * sa), 16.0 * px)
		fx_node.draw_arc(at, R * 0.985, 0.0, TAU, 256, Color(1.1, 0.8, 1.9, 0.6 * sa), 1.5 * px)
		fx_node.draw_arc(at, R, 0.0, TAU, 256, Color(3.5, 3.8, 4.4, sa), 1.6 * px)


# ---------------------------------------------------------------- the overlay

func _draw_ui() -> void:
	var s: Vector2 = ui.size
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	var vp: Viewport = game.get_viewport()
	var ct: Transform2D = vp.get_canvas_transform()
	var sp: Vector2 = ct * at
	var z: float = maxf(0.005, game.cam_zoom())
	# the cold flash: short, blue-white, out from the point (no full white-out: that's the detonation)
	if t >= T_BANG:
		var fl := exp(-(t - T_BANG) / 0.07)
		if fl > 0.01:
			ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.78, 0.9, 1.0, 0.45 * fl))
			if tex != null:
				var gr := s.x * 0.7
				ui.draw_texture_rect(tex, Rect2(sp - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(0.8, 0.92, 1.2, minf(1.0, fl * 1.4)))
	# the afterglow: a slow pale violet ring opening far out, then the only warmth, a few embers
	if t > T_GLOW - 0.4:
		var u := clampf((t - (T_GLOW - 0.4)) / (T_CARD - T_GLOW + 0.4), 0.0, 1.0)
		var rr := (18.0 + 46.0 * Pal.ease_out(u)) * M * z
		var ra := sin(u * PI) * 0.9
		ui.draw_arc(sp, rr, 0.0, TAU, 160, Color(0.55, 0.42, 0.95, 0.10 * ra), 34.0)
		ui.draw_arc(sp, rr * 0.995, 0.0, TAU, 160, Color(0.75, 0.6, 1.25, 0.18 * ra), 8.0)
		ui.draw_arc(sp, rr, 0.0, TAU, 160, Color(1.0, 0.85, 1.6, 0.55 * ra), 1.4)
	if t > 5.6 and tex != null:
		var ea := clampf((t - 5.6) / 0.8, 0.0, 1.0) * clampf(1.0 - (t - T_CARD) / 0.6, 0.0, 1.0)
		for e in embers:
			var age := t - 5.6
			var p: Vector2 = ct * (at + (e[0] as Vector2) + (e[1] as Vector2) * age)
			var fk := 0.5 + 0.5 * sin(t * 5.0 + float(e[2])) * sin(t * 1.7 + float(e[2]) * 2.3)
			var er := 4.5 * float(e[3]) * (0.7 + 0.5 * fk)
			ui.draw_texture_rect(tex, Rect2(p - Vector2(er, er), Vector2(er, er) * 2.0), false, Color(1.7, 0.62, 0.2, ea * (0.25 + 0.6 * fk)))
			ui.draw_circle(p, 1.2, Color(2.0, 1.0, 0.45, ea * (0.4 + 0.6 * fk)))
	# letterbox
	var bh := s.y * 0.1 * Pal.ease_io(clampf(t / 0.5, 0.0, 1.0))
	ui.draw_rect(Rect2(0, 0, s.x, bh), Color(0, 0, 0, 1))
	ui.draw_rect(Rect2(0, s.y - bh, s.x, bh), Color(0, 0, 0, 1))
	if not card:
		var cap := "约束失效" if Txt.zh else "CONFINEMENT LOST"
		var sub := ""
		if t < T_BANG:
			sub = ("T − %.2f s · 磁约束断电" if Txt.zh else "T − %.2f s · TRAP UNPOWERED") % maxf(0.0, T_BANG - t)
		elif t < T_GLOW:
			cap = "正反物质湮灭" if Txt.zh else "ANNIHILATION"
			sub = ("T + %.2f s · 电子对谱" if Txt.zh else "T + %.2f s · PAIR SPECTRUM") % (t - T_BANG)
		else:
			cap = "正反物质湮灭" if Txt.zh else "ANNIHILATION"
			sub = "船体与船坞一同蒸发" if Txt.zh else "THE HULL AND THE BERTH, GONE"
		if bh > 20.0:
			var cc := Color(0.75, 0.92, 1.25)
			ui.draw_string(font, Vector2(48, s.y - bh * 0.42), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, cc)
			ui.draw_string(font, Vector2(48 + font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 24, s.y - bh * 0.42), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.8))
		return
	_draw_card(s, font)


func _draw_card(s: Vector2, font: Font) -> void:
	var ct := t - T_CARD
	ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, clampf(ct / T_FADE, 0.0, 0.94)))
	if ct < T_FADE * 0.6:
		return
	var a := clampf((ct - T_FADE * 0.6) / 0.6, 0.0, 1.0)
	var title := "正 反 物 质 湮 灭" if Txt.zh else "ANNIHILATION"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	var y := s.y * 0.3
	ui.draw_string(font, Vector2((s.x - tw) * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.7, 0.9, 1.3, a))
	var sub := "储存阱断电，约束失效。合同作废。" if Txt.zh else "THE TRAP LOST POWER. THE CONTRACT IS VOID."
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	ui.draw_string(font, Vector2((s.x - sw) * 0.5, y + 44), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.85 * a))
	var rows: Array = [
		["船体与储存阱" if Txt.zh else "HULL AND TRAP", "湮灭" if Txt.zh else "ANNIHILATED"],
		["无人机" if Txt.zh else "DRONE", "%s · %s" % ["损毁" if Txt.zh else "LOST", Pal.money(game.DRONE_FEE)]],
		["拆船坞" if Txt.zh else "BERTH", "%s · %s" % ["全毁，重建" if Txt.zh else "DESTROYED, REBUILT", Pal.money(BERTH_REBUILD)]],
		["反物质事故罚款" if Txt.zh else "ANTIMATTER FINE", Pal.money(FINE)],
	]
	var y0 := y + 110.0
	var x0 := s.x * 0.5 - 300.0
	for i in rows.size():
		var ra := clampf((ct - T_FADE - 0.25 * i) / 0.4, 0.0, 1.0)
		if ra <= 0.0:
			break
		ui.draw_string(font, Vector2(x0, y0 + i * 38), str(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.7 * ra))
		ui.draw_string(font, Vector2(x0, y0 + i * 38), str(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 600, 22, Color(0.75, 0.85, 1.3, ra))
	if ct > T_FADE + 1.4:
		var k := 0.55 + 0.45 * sin(ct * 3.0)
		var cont := "任意键继续" if Txt.zh else "ANY KEY TO CONTINUE"
		var cw := font.get_string_size(cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		ui.draw_string(font, Vector2((s.x - cw) * 0.5, s.y * 0.86), cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.75 * k))


# a key or a click: past the first second, straight to the card; on the card, on to the settlement
func skip() -> void:
	if finished:
		return
	if card:
		if t - T_CARD > T_FADE + 0.8:
			finish()
		return
	if t < 1.0:
		return
	t = T_CARD
	step(0.0)


func finish() -> void:
	if finished:
		return
	finished = true
	Look.time_k(1.0)
	_clear_post()
	game.lose("loss_drone", game.DRONE_FEE, at)
	game.lose("loss_berth_rebuild", BERTH_REBUILD, at)
	game.lose("loss_anni", FINE, at)
	layer.queue_free()
	fx_layer.queue_free()
	game.end_nuke()
