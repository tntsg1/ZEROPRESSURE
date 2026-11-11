extends Node2D
# The gas line's plant, built against the processing district's left wall (2026-11-10, user: "这里
# 气体分离到底在哪里分离的呀？……你尽量做得精致一点，和这个加工区内部一样精致才行啊。我得看到动画
# 呀！"). Drawing only: every number is scripts/gas_line.gd's (the batch, the column's job, the
# liquefier's charge, the LOX tank) and scripts/power_supply.gd's (the LH2 stock, the cryo tug).
# Jev: where — an open steel bay on the hall's left wall, roof stand reached by a riser (A 0.70);
# the column — the port has no gravity, so the "column" is a stack of rotating packed beds (HiGee):
# their spin flings the liquid out through the packing while the gas works inward (A 0.66).
#   Feed: a batch home from a ship's hoses or the belt supplier comes in at the receiving coupling
#   into the buffer drum V-101; the main air compressor C-101 (motor, gearbox, centrifugal stage)
#   pushes it through the aftercooler E-101 into the molecular sieves (one adsorbing, the other
#   heated to regenerate, swapping), into the cold box: the main heat exchanger cools it, the four
#   rotating stages part oxygen (out at the rim, gathered in the sump) from nitrogen and the rest
#   (vented at the stack); the oxygen goes warm again through the exchanger to the GOX sphere.
#   Liquefying: oxygen from the sphere back through the cold box, the turboexpander making the
#   cold, into the vacuum-jacketed LOX tank. LH2 stands in its own jacketed tank (the tug station's
#   tanks, power_supply.gd). Shipping: the cryo tug at the roof stand — both risers flowing.
# Everything in the district box's metres (x < 0: the bay), the still parts one mesh, the moving
# ones meshes placed each frame, the liquids drawn as the tanks on the ships are (tank_fill_fx).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const LC = preload("res://scripts/liquid_colors.gd")
const TF = preload("res://scripts/tank_fill_fx.gd")
const PS = preload("res://scripts/power_supply.gd")
const PA = preload("res://scripts/process_art.gd")

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)
const STEEL := Color(0.09, 0.094, 0.104)
const PERLITE := Color(0.085, 0.088, 0.094)

const BAY := Rect2(-38.4, 0.8, 38.4, 26.8)    # the bay's frame
const FLOOR := 26.8
const DECK := 13.4                             # the mezzanine's top
const V101 := Rect2(-37.0, 17.6, 3.2, 8.8)    # feed buffer drum
const COMP := Vector2(-31.2, 23.6)            # the compressor's volute centre
const COMP_R := 1.6
const GEAR := Rect2(-29.0, 22.6, 1.5, 2.8)
const MOTOR := Rect2(-27.0, 22.0, 3.4, 3.8)
const MFAN := Vector2(-23.4, 23.9)            # the motor's cooling fan, behind its cowl
const E101 := Rect2(-33.2, 18.4, 10.0, 1.9)   # aftercooler (shell and tube)
const SIEVE := [Rect2(-21.6, 17.8, 1.9, 8.4), Rect2(-19.2, 17.8, 1.9, 8.4)]
const HEATER := Rect2(-21.6, 15.4, 4.3, 0.8)
const CBOX := Rect2(-16.6, 2.4, 9.8, 24.4)    # the cold box
const HX := Rect2(-16.0, 4.0, 1.8, 12.4)
const STAGES := [Vector2(-11.6, 5.4), Vector2(-11.6, 9.2), Vector2(-11.6, 13.0), Vector2(-11.6, 16.8)]
const ST_R := 1.7
const SUMP := Rect2(-14.4, 19.6, 5.6, 2.4)
const EXP := Vector2(-11.2, 24.0)              # turboexpander
const EXP_R := 0.95
const LOXT := Rect2(-6.0, 4.6, 5.4, 21.6)      # LOX tank, outer jacket
const GOX := Vector2(-33.4, 8.4)               # GOX sphere
const GOX_R := 3.6
const LH2T := Rect2(-28.4, 7.4, 10.0, 5.0)     # LH2 tank, outer jacket (lying)
const VAPOR := Rect2(-37.0, -3.6, 6.0, 4.4)    # ambient vaporiser bank on the roof
const STACK_X := -25.6
const STACK_TOP := -8.6
const STAND_X := 2.4                           # the roof stand's riser (power_supply_view.gd)
const READOUT := Rect2(-19.35, 3.3, 2.6, 2.0)   # the line's readout board

# the pipes' centre lines (box m): what runs in them is drawn along them
const P_FEED_IN := [Vector2(-38.4, 25.0), Vector2(-37.0, 25.0)]
const P_SUCT := [Vector2(-33.8, 23.6), Vector2(-32.8, 23.6)]
const P_DISCH := [Vector2(-30.2, 22.2), Vector2(-30.2, 20.3)]
const P_TO_SIEVE := [Vector2(-23.2, 19.35), Vector2(-22.4, 19.35), Vector2(-22.4, 16.9), Vector2(-17.3, 16.9)]
const P_SIEVE_OUT := [Vector2(-18.25, 26.2), Vector2(-18.25, 26.4), Vector2(-17.2, 26.4), Vector2(-17.2, 25.6), Vector2(-15.1, 25.6), Vector2(-15.1, 16.4)]
const P_FEED_COL := [Vector2(-15.1, 4.0), Vector2(-15.1, 3.3), Vector2(-13.6, 3.3), Vector2(-13.6, 11.1), Vector2(-13.3, 11.1)]
const P_O2_SUMP := [Vector2(-11.6, 18.5), Vector2(-11.6, 19.6)]
const P_GOX := [Vector2(-14.4, 20.8), Vector2(-15.6, 20.8), Vector2(-15.6, 4.0), Vector2(-15.6, 2.0), Vector2(-33.4, 2.0), Vector2(-33.4, 4.8)]
const P_VENT := [Vector2(-11.6, 3.7), Vector2(-11.6, 2.8), Vector2(STACK_X, 2.8), Vector2(STACK_X, STACK_TOP)]
const P_LIQ := [Vector2(-33.4, 12.0), Vector2(-33.4, 14.6), Vector2(-16.3, 14.6), Vector2(-16.3, 22.9), Vector2(-12.15, 22.9), Vector2(-12.15, 24.0)]
const P_LOX_IN := [Vector2(-10.25, 24.0), Vector2(-8.0, 24.0), Vector2(-8.0, 21.0), Vector2(-6.0, 21.0)]
const P_LOX_UP := [Vector2(-3.3, 4.6), Vector2(-3.3, -0.6), Vector2(STAND_X, -0.6)]
const P_LH2_UP := [Vector2(-19.6, 7.4), Vector2(-19.6, -1.3), Vector2(STAND_X, -1.3)]
const P_BOIL := [Vector2(-1.9, 4.6), Vector2(-1.9, 1.4), Vector2(-24.9, 1.4), Vector2(-24.9, 0.8)]

var game
var font: Font
var glow: Node2D
var still_node: Node2D             # the still plant: one mesh, redrawn only when its detail changes
var _still_lod := -1
var tf                             # a tank_fill_fx used for its liquid drawing (not in the tree)
var _meshes := {}
var _t := 0.0
var _tanks := {}                   # name -> tank_fill record (px round the box's origin)
var _comp_a := 0.0                 # angles (rad) of what turns
var _rot_a := 0.0
var _exp_a := 0.0
var _fan_a := 0.0
var _comp_w := 0.0                 # 0..1 how fast each is turning
var _rot_w := 0.0
var _exp_w := 0.0
var _sep := 0.0                    # 0..1 eased: the column separating, the liquefier, the tug filling
var _liq := 0.0
var _ship := 0.0
var _cold := 0.0                   # the cold box's frost
var _feed_pulse := 0.0             # a batch just come in
var _raw_n := -1
var _vented0 := -1.0
var _plume := 0.0
var _valves := {}                  # name -> 0..1 how open (eased)
var _mist: Array = []              # [pos box m, vel m/s, age, life, size m]
var us := Vector3.ZERO             # µs this frame: process, draw, glow (perf tests)
var prof := {}                     # µs by part (perf tests)
var debug_skip_main := false       # perf tests: the main layer draws nothing
var debug_every := 1               # perf tests: redraw every n frames
var dbg := {}                      # perf tests: parts switched off by name
var _lap_t := 0


func _ready() -> void:
	z_index = 2
	z_as_relative = false
	font = Fonts.get_font("Regular")
	glow = Node2D.new()
	glow.z_index = 3
	glow.z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.draw.connect(_draw_glow)
	add_child(glow)
	still_node = Node2D.new()
	still_node.z_index = 2
	still_node.z_as_relative = false
	still_node.show_behind_parent = true
	still_node.draw.connect(_draw_still)
	add_child(still_node)
	tf = TF.new()
	tf.game = game
	tf._ready()


func _exit_tree() -> void:
	if tf != null and is_instance_valid(tf):
		tf.free()


# shown wherever the port is, the empty berth or a ship being stripped (its gas comes this way)
func active() -> bool:
	return game != null and game.career() and GasLine.built()


var _m := 0.0                      # px a metre and the box's corner, cached each frame
var _o := Vector2.ZERO


func m() -> float:
	if _m <= 0.0:
		_cache_frame()
	return _m


func org() -> Vector2:
	if _m <= 0.0:
		_cache_frame()
	return _o


func _cache_frame() -> void:
	_m = PortStructure.M()
	_o = PortStructure.box("process").position


func _p(v: Vector2) -> Vector2:
	return _o + v * _m


# the bay and what stands over its roof, world px (for cameras and culling)
func view_rect() -> Rect2:
	return Rect2(_p(Vector2(BAY.position.x, STACK_TOP - 1.0)), Vector2(BAY.size.x + 4.0, FLOOR + 1.0 - STACK_TOP + 1.0) * m())


func _on_screen() -> bool:
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var s: Vector2 = get_viewport().get_visible_rect().size
	var r := Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * s)
	return r.intersects(view_rect())


# ---------------------------------------------------------------- state

func _job_k() -> float:
	var j: Dictionary = GasLine.data().job
	if j.is_empty():
		return 0.0
	return clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)


func _liq_k() -> float:
	var j: Dictionary = GasLine.data().get("liq", {})
	if j.is_empty():
		return 0.0
	return clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)


func _cryo_phase() -> String:
	if not PS.ENABLED:
		return "home"
	return str(PS.d().get("cryo", {}).get("phase", "home"))


func _raw_kg() -> float:
	var kg := 0.0
	for b in GasLine.data().batches:
		if str(b.state) in ["raw", "processing"]:
			var mb: float = GasLine.mass(b)
			if str(b.state) == "processing":
				mb *= 1.0 - _job_k()
			kg += mb
	return kg


func _o2_kg() -> float:
	var o2: Dictionary = GasLine.data().o2
	return float(o2.ind) + float(o2.ok) + float(o2.ls)


func _lh2_kg() -> float:
	return float(GasLine.data().get("lh2", {}).get("kg", 0.0))


func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_process_now(dt)
	us.x = Time.get_ticks_usec() - t0


func _process_now(dt: float) -> void:
	_cache_frame()
	visible = active()
	if not visible:
		return
	_t += dt
	var d := GasLine.data()
	var sep_on: bool = not d.job.is_empty() and GasLine.k(game, "gas_sep") > 0.01
	var liq_on: bool = not d.get("liq", {}).is_empty() and GasLine.k(game, "gas_liq") > 0.01
	var ph := _cryo_phase()
	var ship_on: bool = ph in ["p_precool", "p_fill", "p_close"]
	_sep = Pal.damp(_sep, 1.0 if sep_on else 0.0, 1.5, dt)
	_liq = Pal.damp(_liq, 1.0 if liq_on else 0.0, 1.5, dt)
	_ship = Pal.damp(_ship, 1.0 if ship_on else 0.0, 2.0, dt)
	# machines spin up and run down, never jump
	_comp_w = move_toward(_comp_w, 1.0 if (sep_on or liq_on) else 0.0, dt / (3.0 if sep_on or liq_on else 6.0))
	_rot_w = move_toward(_rot_w, 1.0 if sep_on else 0.0, dt / (2.5 if sep_on else 5.0))
	_exp_w = move_toward(_exp_w, 1.0 if liq_on else (0.35 if sep_on else 0.0), dt / 3.0)
	_comp_a = fposmod(_comp_a + dt * _comp_w * 26.0, TAU)
	_fan_a = fposmod(_fan_a + dt * _comp_w * 18.0, TAU)
	_rot_a = fposmod(_rot_a + dt * _rot_w * 9.0, TAU)
	_exp_a = fposmod(_exp_a + dt * _exp_w * 34.0, TAU)
	var cold_to := 1.0 if (sep_on or liq_on) else (0.35 if float(d.lox.kg) > 0.0 else 0.0)
	_cold = move_toward(_cold, cold_to, dt / (25.0 if cold_to > _cold else 60.0))
	# valves: open as their lines run
	var want := {"V-FEED": sep_on, "V-SIEVE-A": sep_on and _bed() == 0, "V-SIEVE-B": sep_on and _bed() == 1,
		"V-GOX": sep_on, "V-VENT": sep_on, "V-LIQ": liq_on, "V-LOX-IN": liq_on,
		"V-LOX-OUT": ph == "p_fill", "V-LH2-OUT": ph == "p_fill"}
	for k in want:
		_valves[k] = move_toward(float(_valves.get(k, 0.0)), 1.0 if want[k] else 0.0, dt / 1.2)
	# a batch just come home: a pulse in at the coupling
	var n := 0
	for b in d.batches:
		if str(b.state) == "raw":
			n += 1
	if _raw_n >= 0 and n > _raw_n:
		_feed_pulse = 1.0
	_raw_n = n
	_feed_pulse = maxf(0.0, _feed_pulse - dt / 4.0)
	if _vented0 < 0.0:
		_vented0 = float(d.vented)
	if float(d.vented) > _vented0 + 0.01:
		_plume = 1.0
	_vented0 = float(d.vented)
	_plume = maxf(_plume - dt * 0.4, 0.6 * _sep)
	_tick_mist(dt)
	_tick_tanks(dt)
	if _on_screen() and Engine.get_process_frames() % debug_every == 0:
		queue_redraw()
		glow.queue_redraw()


# which sieve is adsorbing (they swap every 20 s on line)
func _bed() -> int:
	return int(_t / 20.0) % 2


# the cold box breathes mist at its seams while cold (no gravity: it drifts out and thins)
func _tick_mist(dt: float) -> void:
	_lap("frost")
	for q in _mist:
		q[0] = (q[0] as Vector2) + (q[1] as Vector2) * dt
		q[1] = (q[1] as Vector2) * (1.0 - 0.4 * dt)
		q[2] = float(q[2]) + dt
	_mist = _mist.filter(func(q): return float(q[2]) < float(q[3]))
	var rate := 3.0 * _cold * (0.5 + 0.5 * maxf(_sep, _liq)) + 6.0 * _ship
	if randf() < rate * dt and _mist.size() < 24:
		var src: Vector2
		var out: Vector2
		var r := randf()
		if _ship > 0.3 and r < 0.4:
			src = Vector2(-3.3 + randf_range(-0.3, 0.3), 4.4)
			out = Vector2(randf_range(-0.3, 0.3), -1.0)
		elif r < 0.7:
			src = Vector2(CBOX.position.x, randf_range(CBOX.position.y + 2.0, CBOX.end.y - 2.0))
			out = Vector2(-1.0, randf_range(-0.4, 0.4))
		else:
			src = Vector2(CBOX.end.x, randf_range(CBOX.position.y + 2.0, CBOX.end.y - 4.0))
			out = Vector2(1.0, randf_range(-0.4, 0.4))
		_mist.append([src, out.normalized() * randf_range(0.25, 0.7), 0.0, randf_range(2.5, 5.0), randf_range(0.3, 0.8)])


# ---------------------------------------------------------------- the tanks' liquid (zero g)

func _tick_tanks(dt: float) -> void:
	if _tanks.is_empty():
		_make_tanks()
	tf._t = _t
	var d := GasLine.data()
	var ph := _cryo_phase()
	_set_tank("lox", float(d.lox.kg) / GasLine.TANK_CAP, ph == "p_fill", dt)
	_set_tank("lh2", _lh2_kg() / 8000.0, ph == "p_fill", dt)
	_set_tank("sump", _job_k() * 0.9 * _sep, false, dt)


func _set_tank(name: String, k: float, drawing: bool, dt: float) -> void:
	var e: Dictionary = _tanks.get(name, {})
	if e.is_empty():
		return
	e["k_now"] = clampf(k, 0.0, 1.0)
	e.flow = Pal.damp(float(e.flow), 1.0 if drawing else 0.0, 3.0, dt)


func _make_tanks() -> void:
	var lox_in := Rect2(LOXT.position + Vector2(0.5, 0.6), LOXT.size - Vector2(1.0, 1.2))
	var lh2_in := Rect2(LH2T.position + Vector2(0.5, 0.5), LH2T.size - Vector2(1.0, 1.0))
	_tanks["lox"] = tf._tank("", null, _cap_px(lox_in, false), Transform2D(0.0, org()), "lox", 1.0, _cap_px(LOXT, false), "")
	_tanks["lh2"] = tf._tank("", null, _cap_px(lh2_in, true), Transform2D(0.0, org()), "lh2", 1.0, _cap_px(LH2T, true), "")
	_tanks["sump"] = tf._tank("", null, _cap_px(SUMP, true), Transform2D(0.0, org()), "lox", 1.0, PackedVector2Array(), "")
	_tanks["sump"]["frost"] = PackedVector2Array()
	_tanks["sump"]["boil_k"] = 0.0
	_tanks["lox"]["boil_k"] = 0.2
	_tanks["lh2"]["boil_k"] = 0.25
	for k in ["lox", "lh2", "sump"]:
		_tanks[k]["slow"] = true
	_tanks.lox["pd"] = Vector2.UP          # the outlet: the riser off its top
	_tanks.lh2["pd"] = Vector2.UP
	_tanks.sump["pd"] = Vector2.LEFT
	for k in _tanks:
		tf._levels(_tanks[k])


# a vessel with dished heads, in px from the box's origin
func _cap_px(r: Rect2, lying: bool) -> PackedVector2Array:
	var pts: PackedVector2Array = tf._capsule(Rect2(r.position * m(), r.size * m()), lying)
	return pts


# ---------------------------------------------------------------- meshes

func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


# 60 FPS: the moving meshes are not drawn one by one (a draw call each) but laid into one
# triangle list a frame — each mesh expanded once into unindexed triangles, placed with one
# native transform; a mesh built in white takes its colour from mod
var _flat := {}
var _fv := PackedVector2Array()
var _fc := PackedColorArray()


func _flat_of(key: String, mesh: ArrayMesh) -> Array:
	if not _flat.has(key):
		var a: Array = mesh.surface_get_arrays(0)
		var v: PackedVector2Array = a[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var fv := PackedVector2Array()
		var fc := PackedColorArray()
		fv.resize(ix.size())
		fc.resize(ix.size())
		for i in ix.size():
			fv[i] = v[ix[i]]
			fc[i] = c[ix[i]]
		_flat[key] = [fv, fc]
	return _flat[key]


func _lay(key: String, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE, k := 1.0) -> void:
	var f: Array = _flat_of(key, mesh)
	_fv.append_array(Transform2D(rot, Vector2(m() * k, m() * k), 0.0, _p(at)) * (f[0] as PackedVector2Array))
	if mod == Color.WHITE:
		_fc.append_array(f[1])
	else:
		var n := (f[1] as PackedColorArray).size()
		var c := PackedColorArray()
		c.resize(n)
		c.fill(mod)
		_fc.append_array(c)


func _flush(ci: CanvasItem) -> void:
	if not _fv.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), _fv, _fc)
	_fv = PackedVector2Array()
	_fc = PackedColorArray()


func _put(ci: CanvasItem, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE) -> void:
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(m(), m()), 0.0, _p(at)), mod)


func _ink(a: float) -> Color:
	return Pal.ink(a)


func _lod() -> int:
	var z := get_viewport().get_canvas_transform().get_scale().x
	return 1 if m() * z >= 9.0 else 0


# a vessel with dished heads (box m), as a polygon
func _vessel(r: Rect2, lying: bool, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if lying:
		var dh: float = minf(r.size.y * 0.3, r.size.x * 0.2)
		var cy := r.get_center().y
		for k in n + 1:
			var a: float = -PI * 0.5 + PI * k / n
			pts.append(Vector2(r.end.x - dh + cos(a) * dh, cy + sin(a) * r.size.y * 0.5))
		for k in n + 1:
			var a: float = PI * 0.5 + PI * k / n
			pts.append(Vector2(r.position.x + dh + cos(a) * dh, cy + sin(a) * r.size.y * 0.5))
	else:
		var dh: float = minf(r.size.x * 0.3, r.size.y * 0.2)
		var cx := r.get_center().x
		for k in n + 1:
			var a: float = PI + PI * k / n
			pts.append(Vector2(cx + cos(a) * r.size.x * 0.5, r.position.y + dh + sin(a) * dh))
		for k in n + 1:
			var a: float = PI * k / n
			pts.append(Vector2(cx + cos(a) * r.size.x * 0.5, r.end.y - dh + sin(a) * dh))
	return pts


func _pipe(p, pts: Array, w: float, col := Color(0.16, 0.168, 0.182)) -> void:
	var pv := PackedVector2Array(pts)
	p.polyline(pv, _ink(0.42), w + 0.08)
	p.polyline(pv, col, w)
	p.polyline(pv, Color(1, 1, 1, 0.05), w * 0.25)
	# flanges at each bend
	for i in range(1, pv.size() - 1):
		p.circle(pv[i], w * 0.75, FACE2, 8)
		p.ring(pv[i], w * 0.75, _ink(0.35), 0.03, 8)


# a vacuum-jacketed line: the jacket, its convolutions
func _vj(p, pts: Array, w: float) -> void:
	var pv := PackedVector2Array(pts)
	p.polyline(pv, _ink(0.5), w + 0.08)
	p.polyline(pv, DARK, w)
	p.polyline(pv, Color(0.2, 0.24, 0.3), w * 0.3)
	for i in range(1, pv.size()):
		var a := pv[i - 1]
		var b := pv[i]
		var L := a.distance_to(b)
		var nrm := (b - a).normalized().orthogonal()
		var n := int(L / 0.6)
		for k in n:
			var c := a.lerp(b, (k + 0.5) / maxf(1.0, n))
			p.line(c - nrm * (w * 0.6), c + nrm * (w * 0.6), _ink(0.3), 0.03)


func _gauge(p, c: Vector2, r: float) -> void:
	p.circle(c, r + 0.06, _ink(0.45), 14)
	p.circle(c, r, VOID, 14)
	for k in 7:
		var a := lerpf(PI * 0.75, PI * 2.25, k / 6.0)
		p.line(c + Vector2.from_angle(a) * r * 0.7, c + Vector2.from_angle(a) * r * 0.92, _ink(0.45), 0.02)


func _valve_body(p, c: Vector2, vert: bool) -> void:
	var a := Vector2(0.0, 0.22) if vert else Vector2(0.22, 0.0)
	var o := a.orthogonal()
	p.poly(PackedVector2Array([c - a + o, c, c - a - o]), FACE2)
	p.poly(PackedVector2Array([c + a + o, c, c + a - o]), FACE2)
	p.polyline(PackedVector2Array([c - a + o, c + a - o, c + a + o, c - a - o, c - a + o]), _ink(0.5), 0.03)
	p.line(c, c + Vector2(0.0, -0.36) if not vert else c + Vector2(-0.36, 0.0), _ink(0.45), 0.04)


# ---------------------------------------------------------------- the still plant

func _still(p, lod: int) -> void:
	# the bay: its back wall panels, the steel frame, the mezzanine, the roof truss
	p.rect(Rect2(BAY.position.x, BAY.position.y, BAY.size.x, BAY.size.y), Color(0.032, 0.034, 0.04))
	var x := BAY.position.x
	while x < 0.0:
		p.line(Vector2(x, BAY.position.y + 1.0), Vector2(x, FLOOR), Color(1, 1, 1, 0.025), 0.04)
		x += 2.4
	for cx: float in [BAY.position.x + 0.3, -24.9]:
		p.rect(Rect2(cx - 0.25, BAY.position.y, 0.5, FLOOR - BAY.position.y), STEEL)
		p.line(Vector2(cx - 0.25, BAY.position.y), Vector2(cx - 0.25, FLOOR), _ink(0.35), 0.04)
		p.line(Vector2(cx + 0.25, BAY.position.y), Vector2(cx + 0.25, FLOOR), _ink(0.35), 0.04)
		p.line(Vector2(cx, BAY.position.y), Vector2(cx, FLOOR), _ink(0.12), 0.06)
	# the floor: a deck on the hall's level, grating
	p.rect(Rect2(BAY.position.x, FLOOR, BAY.size.x, 0.8), STEEL)
	p.line(Vector2(BAY.position.x, FLOOR), Vector2(0.0, FLOOR), _ink(0.55), 0.06)
	if lod > 0:
		p.hatch(Rect2(BAY.position.x, FLOOR + 0.1, BAY.size.x, 0.6), _ink(0.12), 0.03, 0.35)
	# the mezzanine over the compressor train: the deck, its rail, a ladder
	p.rect(Rect2(BAY.position.x, DECK, CBOX.position.x - 0.4 - BAY.position.x, 0.45), STEEL)
	p.line(Vector2(BAY.position.x, DECK), Vector2(CBOX.position.x - 0.4, DECK), _ink(0.5), 0.05)
	var rx := BAY.position.x + 0.6
	while rx < CBOX.position.x - 0.6:
		p.line(Vector2(rx, DECK), Vector2(rx, DECK - 1.0), _ink(0.22), 0.03)
		rx += 1.6
	p.line(Vector2(BAY.position.x + 0.6, DECK - 1.0), Vector2(CBOX.position.x - 0.6, DECK - 1.0), _ink(0.25), 0.035)
	for side: float in [-0.35, 0.35]:
		p.line(Vector2(-37.4 + side, DECK + 0.45), Vector2(-37.4 + side, V101.position.y - 0.4), _ink(0.3), 0.04)
	var ly := DECK + 1.0
	while ly < V101.position.y - 0.4:
		p.line(Vector2(-37.75, ly), Vector2(-37.05, ly), _ink(0.25), 0.03)
		ly += 0.5
	# the roof truss
	p.rect(Rect2(BAY.position.x, BAY.position.y, BAY.size.x, 0.25), STEEL)
	p.rect(Rect2(BAY.position.x, BAY.position.y + 1.0, BAY.size.x, 0.2), STEEL)
	p.line(Vector2(BAY.position.x, BAY.position.y), Vector2(0.0, BAY.position.y), _ink(0.5), 0.05)
	var tx := BAY.position.x
	var up := true
	while tx < -0.5:
		p.line(Vector2(tx, BAY.position.y + (1.1 if up else 0.15)), Vector2(tx + 1.2, BAY.position.y + (0.15 if up else 1.1)), _ink(0.22), 0.04)
		tx += 1.2
		up = not up
	# the wall it is built on: the hall's own left wall, a seam where the bay meets it
	p.line(Vector2(-0.15, BAY.position.y), Vector2(-0.15, FLOOR + 0.8), _ink(0.4), 0.05)
	_feed(p, lod)
	_compressor(p, lod)
	_sieves(p, lod)
	_cold_box(p, lod)
	_lox_tank(p, lod)
	_upper(p, lod)
	_roof(p, lod)
	_pipes(p, lod)


func _feed(p, lod: int) -> void:
	# the receiving coupling on the bay's outer wall: where a batch comes in
	p.rect(Rect2(-38.9, 24.3, 0.6, 1.4), FACE2)
	p.rect(Rect2(-38.9, 24.3, 0.6, 1.4), _ink(0.5), false, 0.04)
	for k in 3:
		p.bolt(Vector2(-38.6, 24.55 + k * 0.45), 0.07, _ink(0.45))
	# V-101: the feed buffer drum on its legs
	var v := _vessel(V101, false)
	p.poly(v, FACE)
	p.polyline(v, _ink(0.55), 0.06, true)
	for k in 3:
		var y := V101.position.y + 2.0 + k * 2.2
		p.line(Vector2(V101.position.x, y), Vector2(V101.end.x, y), _ink(0.14), 0.04)
	for lx: float in [V101.position.x + 0.5, V101.end.x - 0.5]:
		p.line(Vector2(lx, V101.end.y - 0.4), Vector2(lx, FLOOR), _ink(0.4), 0.1)
	_gauge(p, Vector2(V101.get_center().x, V101.position.y + 3.2), 0.42)
	# the relief valve and its tail pipe on top
	p.rect(Rect2(V101.get_center().x - 0.15, V101.position.y - 0.7, 0.3, 0.7), FACE2)
	p.line(Vector2(V101.get_center().x, V101.position.y - 0.7), Vector2(V101.get_center().x, V101.position.y - 1.4), _ink(0.4), 0.06)


func _compressor(p, lod: int) -> void:
	# the skid
	p.rect(Rect2(-33.4, 25.6, 11.0, 1.2), STEEL)
	p.rect(Rect2(-33.4, 25.6, 11.0, 1.2), _ink(0.45), false, 0.04)
	for k in 6:
		p.bolt(Vector2(-32.8 + k * 1.9, 26.2), 0.08, _ink(0.4))
	# the volute: its scroll, the casing bolts, the eye (the impeller turns, drawn each frame)
	var scroll := PackedVector2Array()
	for k in 33:
		var a := -PI * 0.5 + TAU * k / 32.0
		scroll.append(COMP + Vector2.from_angle(a) * (COMP_R * (0.86 + 0.14 * k / 32.0)))
	scroll.append(COMP + Vector2(1.0, -COMP_R * 1.05))
	p.poly(scroll, FACE)
	p.polyline(scroll, _ink(0.55), 0.06, true)
	for k in 12:
		p.bolt(COMP + Vector2.from_angle(TAU * k / 12.0) * (COMP_R * 0.92), 0.06, _ink(0.45))
	p.circle(COMP, COMP_R * 0.72, VOID, 24)
	p.ring(COMP, COMP_R * 0.72, _ink(0.35), 0.04, 24)
	# the gearbox and the coupling guard
	p.rect(GEAR, FACE2)
	p.rect(GEAR, _ink(0.5), false, 0.05)
	p.line(Vector2(GEAR.position.x, GEAR.position.y + 1.0), Vector2(GEAR.end.x, GEAR.position.y + 1.0), _ink(0.25), 0.03)
	p.rect(Rect2(GEAR.end.x, 23.5, MOTOR.position.x - GEAR.end.x, 0.8), DARK)
	p.hatch(Rect2(GEAR.end.x, 23.5, MOTOR.position.x - GEAR.end.x, 0.8), Pal.tint(Pal.heat(0.6, 1.0), 0.35, 1.0), 0.06, 0.25)
	# the motor: the frame with its fins, the terminal box, the fan cowl
	p.rect(MOTOR, FACE)
	p.rect(MOTOR, _ink(0.55), false, 0.05)
	var fx := MOTOR.position.x + 0.3
	while fx < MOTOR.end.x - 0.2:
		p.line(Vector2(fx, MOTOR.position.y + 0.2), Vector2(fx, MOTOR.end.y - 0.2), _ink(0.16), 0.05)
		fx += 0.3
	p.rect(Rect2(MOTOR.position.x + 1.0, MOTOR.position.y - 0.7, 1.4, 0.7), FACE2)
	p.rect(Rect2(MOTOR.position.x + 1.0, MOTOR.position.y - 0.7, 1.4, 0.7), _ink(0.45), false, 0.03)
	p.circle(MFAN, 0.85, DARK, 20)
	p.ring(MFAN, 0.85, _ink(0.5), 0.05, 20)
	# E-101: the aftercooler, shell and tube, its water nozzles, the tube sheets
	var e := _vessel(E101, true)
	p.poly(e, FACE)
	p.polyline(e, _ink(0.55), 0.06, true)
	for tx: float in [E101.position.x + 1.1, E101.end.x - 1.1]:
		p.line(Vector2(tx, E101.position.y), Vector2(tx, E101.end.y), _ink(0.4), 0.05)
	if lod > 0:
		for k in 5:
			var y := E101.position.y + 0.35 + k * 0.3
			p.line(Vector2(E101.position.x + 1.2, y), Vector2(E101.end.x - 1.2, y), _ink(0.09), 0.03)
	for nx: float in [E101.position.x + 2.6, E101.end.x - 2.6]:
		p.rect(Rect2(nx - 0.15, E101.position.y - 0.6, 0.3, 0.6), FACE2)
		p.line(Vector2(nx, E101.position.y - 0.6), Vector2(nx, DECK + 0.45), Color(0.2, 0.3, 0.38), 0.12)
	for sx: float in [E101.position.x + 1.6, E101.end.x - 1.6]:
		p.poly(PackedVector2Array([Vector2(sx - 0.5, E101.end.y + 0.9), Vector2(sx - 0.3, E101.end.y - 0.1), Vector2(sx + 0.3, E101.end.y - 0.1), Vector2(sx + 0.5, E101.end.y + 0.9)]), STEEL)
	_gauge(p, Vector2(-29.4, 21.0), 0.34)


func _sieves(p, lod: int) -> void:
	for i in 2:
		var r: Rect2 = SIEVE[i]
		var v := _vessel(r, false)
		p.poly(v, FACE)
		p.polyline(v, _ink(0.55), 0.06, true)
		# the cut-away: the bed of sieve beads behind a window
		var win := Rect2(r.position.x + 0.35, r.position.y + 1.4, r.size.x - 0.7, r.size.y - 2.8)
		p.rect(win, VOID)
		if lod > 0:
			var k := 0
			var by := win.position.y + 0.15
			while by < win.end.y - 0.1:
				var bx := win.position.x + 0.12 + (0.1 if k % 2 == 0 else 0.0)
				while bx < win.end.x - 0.08:
					p.circle(Vector2(bx, by), 0.07, Color(0.22, 0.21, 0.19), 5)
					bx += 0.2
				by += 0.18
				k += 1
		p.rect(win, _ink(0.4), false, 0.04)
		for sy: float in [win.position.y - 0.25, win.end.y + 0.25]:
			p.line(Vector2(r.position.x + 0.2, sy), Vector2(r.end.x - 0.2, sy), _ink(0.3), 0.05)
		for lx: float in [r.position.x + 0.3, r.end.x - 0.3]:
			p.line(Vector2(lx, r.end.y - 0.4), Vector2(lx, FLOOR), _ink(0.4), 0.08)
	# the regeneration heater over them
	p.rect(HEATER, FACE2)
	p.rect(HEATER, _ink(0.5), false, 0.04)
	for k in 8:
		p.line(Vector2(HEATER.position.x + 0.3 + k * 0.5, HEATER.position.y + 0.15), Vector2(HEATER.position.x + 0.3 + k * 0.5, HEATER.end.y - 0.15), _ink(0.2), 0.04)


func _cold_box(p, lod: int) -> void:
	var c := CBOX
	p.rect(c, STEEL)
	p.rect(c, _ink(0.6), false, 0.08)
	# its stiffeners
	var sy := c.position.y + 1.5
	while sy < c.end.y - 0.5:
		p.line(Vector2(c.position.x, sy), Vector2(c.position.x + 0.35, sy), _ink(0.35), 0.06)
		p.line(Vector2(c.end.x - 0.35, sy), Vector2(c.end.x, sy), _ink(0.35), 0.06)
		sy += 1.5
	# the cut-away: perlite packed round everything inside
	var win := Rect2(c.position.x + 0.45, c.position.y + 0.45, c.size.x - 0.9, c.size.y - 0.9)
	p.rect(win, PERLITE)
	if lod > 0:
		for k in 260:
			var h1 := fposmod(sin(k * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(k * 78.233) * 12345.678, 1.0)
			p.circle(win.position + Vector2(h1, h2) * win.size, 0.04, Color(0.16, 0.165, 0.17), 4)
	p.rect(win, _ink(0.35), false, 0.04)
	# the main heat exchanger: a brazed plate-fin block, its headers
	p.rect(HX, FACE)
	if lod > 0:
		p.hatch(HX, _ink(0.12), 0.03, 0.22)
	for k in 6:
		var y := HX.position.y + 1.0 + k * 2.1
		p.line(Vector2(HX.position.x, y), Vector2(HX.end.x, y), _ink(0.3), 0.04)
	p.rect(HX, _ink(0.55), false, 0.05)
	for hy: float in [HX.position.y + 0.7, HX.end.y - 0.7, HX.get_center().y]:
		p.arc(Vector2(HX.end.x, hy), 0.35, -PI * 0.5, PI * 0.5, _ink(0.5), 0.05, 8)
	# the rotating stages: each a casing seen end on, its packing ring (turned each frame), the
	# liquid gathered at the rim; between them the vapour risers and liquid downcomers
	for i in STAGES.size():
		var sc: Vector2 = STAGES[i]
		p.circle(sc, ST_R + 0.12, _ink(0.5), 28)
		p.circle(sc, ST_R, Color(0.07, 0.074, 0.084), 28)
		p.ring(sc, ST_R - 0.12, _ink(0.2), 0.04, 28)
		p.circle(sc, 0.32, FACE2, 12)
		p.ring(sc, 0.32, _ink(0.5), 0.04, 12)
		if i < STAGES.size() - 1:
			var nx: Vector2 = STAGES[i + 1]
			p.rect(Rect2(sc.x - 1.25, sc.y + ST_R - 0.05, 0.4, nx.y - sc.y - 2.0 * ST_R + 0.1), FACE2)
			p.rect(Rect2(sc.x + 0.85, sc.y + ST_R - 0.05, 0.4, nx.y - sc.y - 2.0 * ST_R + 0.1), FACE2)
	# the drive shaft down the stack's spine, its motor under the cold box's roof
	p.line(Vector2(STAGES[0].x + ST_R + 0.6, STAGES[0].y), Vector2(STAGES[3].x + ST_R + 0.6, STAGES[3].y), _ink(0.4), 0.12)
	for sc: Vector2 in STAGES:
		p.line(sc + Vector2(ST_R, 0.0), sc + Vector2(ST_R + 0.6, 0.0), _ink(0.35), 0.1)
	p.rect(Rect2(STAGES[0].x + ST_R + 0.2, STAGES[0].y - 2.2, 0.8, 1.6), FACE2)
	p.rect(Rect2(STAGES[0].x + ST_R + 0.2, STAGES[0].y - 2.2, 0.8, 1.6), _ink(0.45), false, 0.03)
	# the sump the stages drain to (its liquid drawn each frame)
	var s := _vessel(SUMP, true)
	p.poly(s, Color(0.05, 0.055, 0.065))
	p.polyline(s, _ink(0.55), 0.06, true)
	# the turboexpander: its scroll and the brake generator outside the box
	p.circle(EXP, EXP_R + 0.25, FACE, 20)
	p.ring(EXP, EXP_R + 0.25, _ink(0.55), 0.05, 20)
	p.circle(EXP, EXP_R * 0.85, VOID, 18)
	p.rect(Rect2(EXP.x + EXP_R + 0.25, EXP.y - 0.3, 0.5, 0.6), DARK)
	p.rect(Rect2(EXP.x + EXP_R + 0.75, EXP.y - 0.75, 1.3, 1.5), FACE2)
	p.rect(Rect2(EXP.x + EXP_R + 0.75, EXP.y - 0.75, 1.3, 1.5), _ink(0.5), false, 0.04)
	# the readout board hung beside it, over the mezzanine (its numbers drawn each frame)
	p.rect(READOUT, Color(0.02, 0.025, 0.03))
	p.rect(READOUT, _ink(0.45), false, 0.04)
	p.line(Vector2(READOUT.position.x + 0.4, READOUT.position.y), Vector2(READOUT.position.x + 0.4, BAY.position.y + 1.2), _ink(0.3), 0.04)
	p.line(Vector2(READOUT.end.x - 0.4, READOUT.position.y), Vector2(READOUT.end.x - 0.4, BAY.position.y + 1.2), _ink(0.3), 0.04)


func _lox_tank(p, lod: int) -> void:
	var outer := _vessel(LOXT, false, 14)
	var inner := _vessel(Rect2(LOXT.position + Vector2(0.5, 0.6), LOXT.size - Vector2(1.0, 1.2)), false, 14)
	p.poly(outer, STEEL)
	p.polyline(outer, _ink(0.6), 0.07, true)
	p.poly(inner, Color(0.04, 0.044, 0.052))
	p.polyline(inner, _ink(0.4), 0.04, true)
	# the vacuum annulus: supports and the multi-layer insulation, faint
	if lod > 0:
		for k in 14:
			var y := LOXT.position.y + 2.0 + k * 1.4
			p.line(Vector2(LOXT.position.x + 0.08, y), Vector2(LOXT.position.x + 0.42, y + 0.3), _ink(0.14), 0.025)
			p.line(Vector2(LOXT.end.x - 0.08, y), Vector2(LOXT.end.x - 0.42, y + 0.3), _ink(0.14), 0.025)
	# the skirt, the level gauge's dP legs, the relief valves on top
	p.poly(PackedVector2Array([Vector2(LOXT.position.x + 0.6, LOXT.end.y - 0.6), Vector2(LOXT.end.x - 0.6, LOXT.end.y - 0.6), Vector2(LOXT.end.x - 0.3, FLOOR), Vector2(LOXT.position.x + 0.3, FLOOR)]), STEEL)
	p.line(Vector2(LOXT.end.x + 0.25, LOXT.position.y + 2.0), Vector2(LOXT.end.x + 0.25, LOXT.end.y - 2.0), _ink(0.3), 0.05)
	for rx: float in [LOXT.get_center().x + 0.9, LOXT.get_center().x + 1.6]:
		p.rect(Rect2(rx - 0.14, LOXT.position.y - 0.55, 0.28, 0.55), FACE2)
	_gauge(p, Vector2(LOXT.end.x + 0.25, LOXT.end.y - 1.2), 0.32)


func _upper(p, lod: int) -> void:
	# the GOX sphere on its legs
	for lx: float in [-2.6, -1.0, 1.0, 2.6]:
		p.line(GOX + Vector2(lx, GOX_R * 0.6), Vector2(GOX.x + lx * 1.1, DECK), _ink(0.4), 0.1)
	p.circle(GOX, GOX_R, FACE, 32)
	p.ring(GOX, GOX_R, _ink(0.55), 0.07, 32)
	p.arc(GOX, GOX_R * 0.98, PI * 1.05, PI * 1.45, Color(1, 1, 1, 0.06), 0.25, 10)
	p.line(GOX + Vector2(-GOX_R, 0.0), GOX + Vector2(GOX_R, 0.0), _ink(0.3), 0.05)
	for k in 10:
		p.bolt(GOX + Vector2(-GOX_R + 0.3 + k * 0.72, 0.0), 0.06, _ink(0.4))
	_gauge(p, GOX + Vector2(GOX_R + 0.7, 1.4), 0.38)
	# the LH2 tank: jacketed, lying in its saddles
	var outer := _vessel(LH2T, true, 12)
	var inner := _vessel(Rect2(LH2T.position + Vector2(0.5, 0.5), LH2T.size - Vector2(1.0, 1.0)), true, 12)
	p.poly(outer, STEEL)
	p.polyline(outer, _ink(0.6), 0.07, true)
	p.poly(inner, Color(0.04, 0.044, 0.052))
	p.polyline(inner, _ink(0.4), 0.04, true)
	for sx: float in [LH2T.position.x + 2.0, LH2T.end.x - 2.0]:
		p.poly(PackedVector2Array([Vector2(sx - 0.8, DECK), Vector2(sx - 0.5, LH2T.end.y - 0.4), Vector2(sx + 0.5, LH2T.end.y - 0.4), Vector2(sx + 0.8, DECK)]), STEEL)
		p.line(Vector2(sx - 0.9, DECK), Vector2(sx + 0.9, DECK), _ink(0.4), 0.06)
	# a warning band (hydrogen): hatched, faint
	p.hatch(Rect2(LH2T.position.x + 3.6, LH2T.position.y + 0.08, 0.9, 0.35), Pal.tint(Pal.heat(0.6, 1.0), 0.35, 1.0), 0.05, 0.18)


func _roof(p, lod: int) -> void:
	# the ambient vaporiser: a bank of star-finned tubes between headers
	var v := VAPOR
	p.rect(Rect2(v.position.x, v.end.y - 0.3, v.size.x, 0.3), STEEL)
	p.rect(Rect2(v.position.x, v.position.y, v.size.x, 0.3), STEEL)
	for k in 8:
		var x := v.position.x + 0.4 + k * 0.74
		p.line(Vector2(x, v.position.y + 0.3), Vector2(x, v.end.y - 0.3), _ink(0.45), 0.12)
		if lod > 0:
			var y := v.position.y + 0.5
			while y < v.end.y - 0.4:
				p.line(Vector2(x - 0.28, y), Vector2(x + 0.28, y), _ink(0.16), 0.025)
				y += 0.2
	p.rect(v, _ink(0.35), false, 0.04)
	# the vent stack: its silencer, the rain cap's flare-out
	p.rect(Rect2(STACK_X - 0.25, STACK_TOP, 0.5, BAY.position.y - STACK_TOP), STEEL)
	p.line(Vector2(STACK_X - 0.25, STACK_TOP), Vector2(STACK_X - 0.25, BAY.position.y), _ink(0.45), 0.04)
	p.line(Vector2(STACK_X + 0.25, STACK_TOP), Vector2(STACK_X + 0.25, BAY.position.y), _ink(0.45), 0.04)
	p.rect(Rect2(STACK_X - 0.6, -5.4, 1.2, 2.2), FACE2)
	p.rect(Rect2(STACK_X - 0.6, -5.4, 1.2, 2.2), _ink(0.5), false, 0.04)
	p.poly(PackedVector2Array([Vector2(STACK_X - 0.25, STACK_TOP), Vector2(STACK_X + 0.25, STACK_TOP), Vector2(STACK_X + 0.5, STACK_TOP - 0.5), Vector2(STACK_X - 0.5, STACK_TOP - 0.5)]), FACE2)
	# the risers' supports on the hall's roof
	for sx: float in [-1.0, 0.6, 2.0]:
		p.rect(Rect2(sx - 0.15, -1.8, 0.3, 1.8), STEEL)


func _pipes(p, lod: int) -> void:
	_pipe(p, P_FEED_IN, 0.3)
	_pipe(p, P_SUCT, 0.42)
	_pipe(p, P_DISCH, 0.36)
	_pipe(p, P_TO_SIEVE, 0.32)
	_pipe(p, [SIEVE[0].get_center() + Vector2(0.0, -4.2 - 0.5), Vector2(SIEVE[0].get_center().x, 16.9)], 0.24)
	_pipe(p, [SIEVE[1].get_center() + Vector2(0.0, -4.2 - 0.5), Vector2(SIEVE[1].get_center().x, 16.9)], 0.24)
	_pipe(p, [Vector2(SIEVE[0].get_center().x, 26.2), Vector2(SIEVE[0].get_center().x, 26.4), Vector2(-18.25, 26.4)], 0.24)
	_pipe(p, P_SIEVE_OUT, 0.3)
	_pipe(p, P_FEED_COL, 0.24)
	_pipe(p, P_O2_SUMP, 0.2)
	_pipe(p, P_GOX, 0.26)
	_pipe(p, P_VENT, 0.34)
	_pipe(p, P_LIQ, 0.26)
	_vj(p, P_LOX_IN, 0.32)
	_vj(p, P_LOX_UP, 0.4)
	_vj(p, P_LH2_UP, 0.4)
	_pipe(p, P_BOIL, 0.16)
	_vj(p, [Vector2(VAPOR.end.x, VAPOR.get_center().y), Vector2(-24.9, VAPOR.get_center().y), Vector2(-24.9, 0.8)], 0.24)
	# the valves on the lines (their handles drawn each frame)
	for v in _valve_spots():
		_valve_body(p, v[1], bool(v[2]))


# [name, where, on a vertical run]
func _valve_spots() -> Array:
	return [["V-FEED", Vector2(-37.7, 25.0), false], ["V-SIEVE-A", Vector2(SIEVE[0].get_center().x, 17.3), true],
		["V-SIEVE-B", Vector2(SIEVE[1].get_center().x, 17.3), true], ["V-GOX", Vector2(-26.0, 2.0), false],
		["V-VENT", Vector2(-20.0, 2.8), false], ["V-LIQ", Vector2(-24.0, 14.6), false], ["V-LOX-IN", Vector2(-7.0, 21.0), false],
		["V-LOX-OUT", Vector2(-3.3, 2.6), true], ["V-LH2-OUT", Vector2(-19.6, 4.6), true]]


# ---------------------------------------------------------------- the moving parts

func _impeller() -> ArrayMesh:
	return _mesh("impeller", func(p):
		p.circle(Vector2.ZERO, COMP_R * 0.66, Color(0.13, 0.136, 0.15), 22)
		for k in 9:
			var a := TAU * k / 9.0
			var pts := PackedVector2Array()
			for s in 6:
				var u := s / 5.0
				pts.append(Vector2.from_angle(a + u * 0.9) * lerpf(0.25, COMP_R * 0.64, u))
			p.polyline(pts, _ink(0.6), 0.06)
		p.circle(Vector2.ZERO, 0.24, FACE2, 10)
		p.ring(Vector2.ZERO, 0.24, _ink(0.6), 0.04, 10))


func _rotor() -> ArrayMesh:
	return _mesh("rotor", func(p):
		# the packing ring: wire mesh, its spokes, the liquid distributor at the eye
		p.ring(Vector2.ZERO, 0.95, Color(0.17, 0.175, 0.185), 0.7, 28)
		for k in 36:
			var a := TAU * k / 36.0
			p.line(Vector2.from_angle(a) * 0.62, Vector2.from_angle(a + 0.12) * 1.28, _ink(0.22), 0.025)
		for k in 6:
			p.line(Vector2.from_angle(TAU * k / 6.0) * 0.32, Vector2.from_angle(TAU * k / 6.0) * 1.32, _ink(0.45), 0.05)
		p.ring(Vector2.ZERO, 0.6, _ink(0.45), 0.03, 24)
		p.ring(Vector2.ZERO, 1.3, _ink(0.5), 0.04, 28))


func _wheel() -> ArrayMesh:
	return _mesh("wheel", func(p):
		p.circle(Vector2.ZERO, EXP_R * 0.8, Color(0.14, 0.145, 0.16), 18)
		for k in 11:
			var a := TAU * k / 11.0
			p.line(Vector2.from_angle(a) * 0.15, Vector2.from_angle(a - 0.7) * EXP_R * 0.78, _ink(0.6), 0.05)
		p.circle(Vector2.ZERO, 0.16, FACE2, 8))


func _fan() -> ArrayMesh:
	return _mesh("fan", func(p):
		for k in 5:
			var a := TAU * k / 5.0
			p.poly(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.2) * 0.75, Vector2.from_angle(a + 0.25) * 0.7]), Color(0.2, 0.205, 0.22))
		p.circle(Vector2.ZERO, 0.18, FACE2, 8))


# the liquid film at a stage's rim: thin while it holds little, the thicker band while it spins
func _rim() -> ArrayMesh:
	return _mesh("rim", func(p): p.ring(Vector2.ZERO, ST_R - 0.17, Color.WHITE, 0.06, 40))


func _rim2() -> ArrayMesh:
	return _mesh("rim2", func(p): p.ring(Vector2.ZERO, ST_R - 0.27, Color.WHITE, 0.2, 40))


# the cold box's frost: ticks off both its sides, laid down once
func _frost_mesh() -> ArrayMesh:
	return _mesh("frost", func(p):
		var c := CBOX
		for k in 90:
			var h1 := fposmod(sin(k * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(k * 78.233) * 12345.678, 1.0)
			var on_left := k % 2 == 0
			var a := Vector2(c.position.x if on_left else c.end.x, c.position.y + 0.5 + h1 * (c.size.y - 1.0))
			var out := Vector2(-1.0 if on_left else 1.0, 0.0).rotated((h2 - 0.5) * 1.4)
			p.line(a, a + out * (0.15 + 0.35 * h2), Color.WHITE, 0.035)
		for pnt: Vector2 in [Vector2(-3.3, -0.6), Vector2(-19.6, -1.3), Vector2(-8.0, 21.0), Vector2(-8.0, 24.0)]:
			p.ring(pnt, 0.35, Color.WHITE, 0.08, 14))


# a puff of mist (its alpha falls off by rings)
func _puff() -> ArrayMesh:
	return _mesh("puff", func(p):
		p.circle(Vector2.ZERO, 1.0, Color(1, 1, 1, 0.35), 16)
		p.circle(Vector2.ZERO, 0.66, Color(1, 1, 1, 0.5), 14)
		p.circle(Vector2.ZERO, 0.33, Color(1, 1, 1, 0.6), 12))


func _handle() -> ArrayMesh:
	return _mesh("handle", func(p):
		p.line(Vector2(-0.34, 0.0), Vector2(0.34, 0.0), Pal.ink(0.75), 0.07)
		p.circle(Vector2.ZERO, 0.08, Pal.ink(0.75), 8))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_now()
	us.y = Time.get_ticks_usec() - t0


func _lap(name: String) -> void:
	var now := Time.get_ticks_usec()
	prof[name] = float(prof.get(name, 0.0)) * 0.95 + float(now - _lap_t) * 0.05
	_lap_t = now


func _draw_now() -> void:
	_lap_t = Time.get_ticks_usec()
	if not active() or not _on_screen() or debug_skip_main:
		return
	var lod := _lod()
	var M := m()
	# the layer's bounds (a draw_mesh alone is culled by its untransformed box)
	draw_rect(view_rect(), Color(0, 0, 0, 0), false, 1.0)
	if lod != _still_lod:
		_still_lod = lod
		still_node.queue_redraw()
	var d := GasLine.data()
	# the feed drum and the GOX sphere: their gas, as dense as the stock in them
	var feed_k := clampf(_raw_kg() / 12000.0, 0.0, 1.0)
	if feed_k > 0.0 and dbg.get("gas", true):
		_lay("v101gas", _mesh("v101gas", func(p): p.poly(_vessel(V101.grow(-0.15), false), Color.WHITE)), Vector2.ZERO, 0.0, Color(0.85, 0.86, 0.88, 0.005 + 0.02 * feed_k))
	var gox_k := clampf(_o2_kg() / 5000.0, 0.0, 1.0)
	if gox_k > 0.0 and dbg.get("gas", true):
		_lay("goxgas", _mesh("goxgas", func(p): p.circle(Vector2.ZERO, GOX_R - 0.15, Color.WHITE, 32)), GOX, 0.0, Color(LC.of("lox").r, LC.of("lox").g, LC.of("lox").b, 0.004 + 0.016 * gox_k))
	_lap("still")
	# what turns
	if not dbg.get("turn", true):
		_fv = PackedVector2Array()
		_fc = PackedColorArray()
	_lay("impeller", _impeller(), COMP, _comp_a)
	_lay("fan", _fan(), MFAN, _fan_a)
	_lay("wheel", _wheel(), EXP, -_exp_a)
	for sc: Vector2 in STAGES:
		_lay("rotor", _rotor(), sc, _rot_a)
	for v in (_valve_spots() if lod > 0 else []):
		var o := float(_valves.get(v[0], 0.0))
		var hp: Vector2 = (v[1] as Vector2) + (Vector2(-0.36, 0.0) if bool(v[2]) else Vector2(0.0, -0.36))
		_lay("handle", _handle(), hp, (0.0 if bool(v[2]) else PI * 0.5) + o * PI * 0.5)
	if dbg.get("turn", true):
		_flush(self)
	else:
		_fv = PackedVector2Array()
		_fc = PackedColorArray()
	_lap("turning")
	# the liquids (LOX tank, LH2 tank, the column's sump), as on the ships
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for k in (["lox", "lh2", "sump"] if dbg.get("tanks", true) else []):
		var e: Dictionary = _tanks.get(k, {})
		if not e.is_empty():
			e["boil_k"] = 0.0 if lod == 0 or k == "sump" else (0.2 if k == "lox" else 0.25)
			# each tank its own list: its triangles kept once (tank_fill_fx)
			verts = PackedVector2Array()
			cols = PackedColorArray()
			idx = PackedInt32Array()
			tf.emit_liquid(e, e.xf, self, verts, cols, idx)
			if not idx.is_empty() and dbg.get("liq", true):
				RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	# the stages: liquid flung out through the packing, gathered as a film at the casing's rim
	_lap("liquids")
	if dbg.get("stage", true):
		_stage_liquid(lod)
	_lap("stages")
	# the needles (too small to read far out)
	if lod == 0:
		if dbg.get("frost", true):
			_frost()
		_flush(self)
		_lap("needles")
		return
	_needle(Vector2(V101.get_center().x, V101.position.y + 3.2), 0.42, feed_k)
	_needle(Vector2(-29.4, 21.0), 0.34, _comp_w * (0.75 + 0.05 * sin(_t * 3.0)))
	_needle(GOX + Vector2(GOX_R + 0.7, 1.4), 0.38, gox_k)
	_needle(Vector2(LOXT.end.x + 0.25, LOXT.end.y - 1.2), 0.32, clampf(float(d.lox.kg) / GasLine.TANK_CAP, 0.0, 1.0))
	# frost on the cold box and the jacketed lines, the mist
	_lap("needles")
	_frost()
	_flush(self)
	if lod > 0:
		for q in _mist:
			var u: float = float(q[2]) / float(q[3])
			var sz: float = float(q[4]) * (0.5 + 0.7 * u)
			draw_mesh(_puff(), null, Transform2D(0.0, Vector2(sz * M, sz * M), 0.0, _p(q[0])), Color(0.88, 0.92, 0.96, 0.03 * sin(u * PI)))
	# the readout on the cold box: what the terminal says, here
	_lap("mist")
	_readout()
	_lap("readout")
	if Pal.labels:
		_tags()


func _draw_still() -> void:
	if not active():
		return
	var lod := maxi(_still_lod, 0)
	still_node.draw_rect(view_rect(), Color(0, 0, 0, 0), false, 1.0)
	_put(still_node, _mesh("still%d" % lod, func(p): _still(p, lod)), Vector2.ZERO)


func _px(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(_p(v))
	return out


func _needle(c: Vector2, r: float, k: float) -> void:
	var a := lerpf(PI * 0.75, PI * 2.25, clampf(k, 0.0, 1.0))
	draw_line(_p(c), _p(c + Vector2.from_angle(a) * r * 0.82), Pal.heat(0.8, 1.2), maxf(1.0, 0.04 * m()))


func _stage_liquid(lod: int) -> void:
	var M := m()
	var lox := LC.of("lox")
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	for i in STAGES.size():
		var c: Vector2 = STAGES[i]
		# the rim film: what the stage holds while it runs (it drains when it stops)
		var film := 0.6 + 0.4 * sin(_t * 0.7 + i)
		if _rot_w > 0.02 or _sep > 0.02:
			var hold := maxf(_rot_w, _sep)
			_lay("rim", _rim(), c, 0.0, Color(lox.r, lox.g, lox.b, 0.18 * hold))
			if lod > 0:
				_lay("rim2", _rim2(), c, 0.0, Color(lox.r, lox.g, lox.b, 0.16 * hold * _rot_w * film))
		# the drops flung out along the spin, the vapour spiralling in
		if _rot_w > 0.05:
			for k in 10:
				var u := fposmod(_t * 1.6 + k * 0.1 + i * 0.27, 1.0)
				var a := _rot_a + TAU * k / 10.0 + u * 0.9
				var r0 := lerpf(0.4, 1.35, u)
				segs.append(_p(c + Vector2.from_angle(a) * r0))
				segs.append(_p(c + Vector2.from_angle(a + 0.25) * (r0 + 0.18)))
				sc.append(Color(lox.r, lox.g, lox.b, 0.55 * _rot_w * (1.0 - u * 0.5)))
	if not segs.is_empty():
		draw_multiline_colors(segs, sc, -1.0)


func _frost() -> void:
	if _cold <= 0.01:
		return
	_lay("frost", _frost_mesh(), Vector2.ZERO, 0.0, Color(0.9, 0.95, 1.0, 0.35 * _cold))


func _readout() -> void:
	var M := m()
	var at := READOUT.position + Vector2(0.15, 0.5)
	var d := GasLine.data()
	var lines: Array = []
	var cols: Array = []
	if not d.job.is_empty():
		lines.append("SEP %s %d%%" % [str(d.job.id), int(_job_k() * 100.0)])
		cols.append(Pal.heat(0.85, 1.3))
	else:
		lines.append("SEP --")
		cols.append(Pal.ink(0.35))
	var lj: Dictionary = d.get("liq", {})
	if not lj.is_empty():
		lines.append("LIQ %.0f kg %d%%" % [float(lj.kg), int(_liq_k() * 100.0)])
		cols.append(Pal.tint(LC.of("lox"), 0.95, 1.3))
	else:
		lines.append("LIQ --")
		cols.append(Pal.ink(0.35))
	lines.append("LOX %.1f t" % (float(d.lox.kg) / 1000.0))
	cols.append(Pal.ink(0.6))
	for i in lines.size():
		draw_string(font, _p(at + Vector2(0.0, 0.55 * i)), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.3 * M), cols[i])


func _tags() -> void:
	var M := m()
	for t in [[V101.position + Vector2(0.2, -0.3), "V-101"], [Vector2(-33.0, 21.6), "C-101"], [E101.position + Vector2(1.4, -0.25), "E-101"],
			[SIEVE[0].position + Vector2(0.0, -1.1), "MS-101 A/B"], [CBOX.position + Vector2(0.6, 1.4), "CB-101"],
			[LOXT.position + Vector2(0.4, -0.8), "T-201 LOX"], [LH2T.position + Vector2(0.6, -0.3), "T-202 LH2"],
			[GOX + Vector2(-1.4, -GOX_R - 0.3), "V-201 GOX"]]:
		draw_string(font, _p(t[0]), str(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.42 * M), Pal.ink(0.5))


# ---------------------------------------------------------------- the additive layer

func _draw_glow() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_glow_now()
	us.z = Time.get_ticks_usec() - t0


func _draw_glow_now() -> void:
	if not active() or not _on_screen():
		return
	var M := m()
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	var grey := Color(0.86, 0.87, 0.9)
	var o2 := LC.of("lox")
	var h2 := LC.of("lh2")
	var ph := _cryo_phase()
	# what runs in the lines, in its own colour: the mixed gas grey-white, oxygen pale blue,
	# nitrogen and the rest grey to the stack, hydrogen all but colourless
	_flow(segs, sc, P_FEED_IN, grey, maxf(_feed_pulse, _sep * 0.5), 2.0)
	_flow(segs, sc, P_SUCT, grey, _sep, 4.0)
	_flow(segs, sc, P_DISCH, grey, _sep, 5.0)
	_flow(segs, sc, P_TO_SIEVE, grey, _sep, 4.0)
	_flow(segs, sc, P_SIEVE_OUT, grey, _sep, 3.0)
	_flow(segs, sc, P_FEED_COL, grey, _sep, 3.0)
	_flow(segs, sc, P_O2_SUMP, o2, _sep, 1.5)
	_flow(segs, sc, P_GOX, o2, _sep, 3.0)
	_flow(segs, sc, P_VENT, Color(0.7, 0.72, 0.76), _sep * 0.7, 4.0)
	_flow(segs, sc, P_LIQ, o2, _liq, 2.5)
	_flow(segs, sc, P_LOX_IN, o2, _liq, 1.5)
	_flow(segs, sc, P_LOX_UP, o2, _ship * (1.0 if ph == "p_fill" else 0.25), 2.5)
	_flow(segs, sc, P_LH2_UP, Color(h2.r, h2.g, h2.b), _ship * (0.6 if ph == "p_fill" else 0.15), 2.5)
	if not segs.is_empty():
		# (the dashes as one triangle list: wide lines cost the renderer per segment)
		var hw := maxf(0.6, 0.045 * M)
		var tv := PackedVector2Array()
		var tc := PackedColorArray()
		tv.resize(segs.size() * 3)
		tc.resize(segs.size() * 3)
		for i in range(0, segs.size(), 2):
			var a: Vector2 = segs[i]
			var b: Vector2 = segs[i + 1]
			var n := (b - a).normalized().orthogonal() * hw
			var c: Color = sc[i / 2]
			var j := i * 3
			tv[j] = a - n
			tv[j + 1] = b - n
			tv[j + 2] = b + n
			tv[j + 3] = a - n
			tv[j + 4] = b + n
			tv[j + 5] = a + n
			for q in 6:
				tc[j + q] = c
		RenderingServer.canvas_item_add_triangle_array(glow.get_canvas_item(), PackedInt32Array(), tv, tc)
	# the regenerating sieve's heater, glowing
	if _sep > 0.02:
		var hr := Rect2(_p(HEATER.position), HEATER.size * M)
		glow.draw_rect(hr, Pal.heat(0.25 * _sep * (0.8 + 0.2 * sin(_t * 2.0)), 1.0))
		var r: Rect2 = SIEVE[1 - _bed()]
		glow.draw_rect(Rect2(_p(r.position + Vector2(0.35, 1.4)), (r.size - Vector2(0.7, 2.8)) * M), Pal.heat(0.12 * _sep, 1.0))
	# the liquids' glints and outflow (close in)
	var gs := PackedVector2Array()
	var gc := PackedColorArray()
	for k in (["lox", "lh2", "sump"] if _lod() > 0 else []):
		var e: Dictionary = _tanks.get(k, {})
		if not e.is_empty():
			tf.emit_glow(e, e.xf, glow, gs, gc)
	if not gs.is_empty():
		glow.draw_multiline_colors(gs, gc, 1.4)
	# status lamps on each machine: amber working, blue holding, dark idle
	var lamps := [[Vector2(MOTOR.end.x - 0.4, MOTOR.position.y - 0.4), "work" if _comp_w > 0.05 else ""],
		[Vector2(HEATER.end.x + 0.3, HEATER.position.y + 0.4), "work" if _sep > 0.05 else ""],
		[Vector2(CBOX.end.x - 0.6, CBOX.position.y + 0.9), "work" if (_sep > 0.05 or _liq > 0.05) else ("ok" if float(GasLine.data().lox.kg) > 0.0 else "")],
		[Vector2(LOXT.end.x - 0.6, LOXT.position.y + 1.2), "work" if ph == "p_fill" else ("ok" if float(GasLine.data().lox.kg) > 0.0 else "")]]
	for l in lamps:
		var col := PA.lamp_col(str(l[1]), _t)
		glow.draw_circle(_p(l[0]), 0.16 * M, col)
		if str(l[1]) != "":
			glow.draw_circle(_p(l[0]), 0.45 * M, Color(col.r, col.g, col.b, 0.12))
	# the vent stack's plume: nitrogen and the rest while the column runs, boil-off when vented
	if _plume > 0.02:
		for i in 5:
			var u := fposmod(_t * 0.25 + i * 0.2, 1.0)
			glow.draw_circle(_p(Vector2(STACK_X + sin(i * 2.3) * 0.6 * u, STACK_TOP - 0.6 - u * 4.0)), (0.4 + 1.4 * u) * M, Color(0.8, 0.82, 0.86, 0.06 * _plume * (1.0 - u)))


# dashes running along a line (box m), as hard as k, at speed m/s (one pass along its runs)
func _flow(segs: PackedVector2Array, sc: PackedColorArray, path: Array, col: Color, k: float, speed: float) -> void:
	if k < 0.02:
		return
	var c := Color(col.r, col.g, col.b, 0.7 * k)
	var off := fposmod(_t * speed, 1.1)
	var s0 := 0.0
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var L := a.distance_to(b)
		if L < 0.0001:
			continue
		var pa := _p(a)
		var dp := (_p(b) - pa) / L
		var x := fposmod(off - s0, 1.1)
		while x < L:
			segs.append(pa + dp * x)
			segs.append(pa + dp * minf(L, x + 0.4))
			sc.append(c)
			x += 1.1
		s0 += L


func _along(path: Array, s: float) -> Vector2:
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var L := a.distance_to(b)
		if s <= L:
			return a.lerp(b, s / maxf(0.0001, L))
		s -= L
	return path[path.size() - 1]
