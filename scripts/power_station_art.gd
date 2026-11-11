extends RefCounted
# 100 号: the power district drawn as the plant it is (scripts/power_works.gd runs it). Box-local
# metres, 60 × 28, floor at 26.8, the door and the business console at the bottom in the middle.
#   upper left: three reactor bays in their shields — the vessel (closure head, rod drives, the
#     core's assemblies glowing with the heat it makes, the rods as deep as they stand), the steam
#     generator (drum, U-tubes, tube sheet), the pressuriser with its heaters, the main coolant pump
#     on the cold leg. The third bay stands empty, scaffolded, until stage 2.
#   upper middle: the main control screen over the console — out against capacity, frequency,
#     the loops' temperatures, the shore line, the last changeovers.
#   upper right: the turbine-generator on its deck — stop and governor valves on the steam main,
#     HP and LP casings and the crossover, bearings, the generator and exciter; the condenser under
#     the deck.
#   lower: the emergency fuel-cell set and the feed pumps at the left; the switchgear (the units'
#     incomer, the shore incomer, a feeder for each district) and the radiator pumps at the right.
#   ceiling and floor: the steam main and the radiator supply overhead; the condensate, the
#     radiator return and the outgoing feeders in the floor trench.
# Still parts are one mesh a stage and detail level; moving parts are small meshes placed every
# frame, flow dots, and the plates' text (scripts/mesh_pen.gd, as the tug station 96 号).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const CA = preload("res://scripts/console_art.gd")
const W = preload("res://scripts/power_works.gd")

const FLOOR := 26.8
const BAY_X := [0.8, 10.4, 20.0]
const BAY_W := 9.4
const BAY_Y := Vector2(3.2, 17.6)
const VX := 2.8                       # in a bay: the vessel's axis
const VR := 1.5
const SX := 6.6                       # the steam generator's axis
const PX := 8.5                       # the pressuriser's axis
const FX := 9.15                      # the feed line's riser (in the shield wall)
const CORE_Y := 11.2
const SCREEN := Rect2(30.2, 3.6, 6.6, 9.6)
const TY := 8.6                       # the turbine's shaft line
const DECK := Vector2(11.4, 12.6)
const COND := Rect2(43.0, 12.6, 6.6, 3.8)
const VALVE_X := 37.0
const GEN := Rect2(51.0, 6.6, 4.4, 4.0)
const FC := Rect2(0.8, 19.6, 8.0, 7.2)
const FW_C := [11.6, 15.0, 18.4]      # the feed pumps' motors' centres
const FW_Y := 24.8
const SG_X := 38.6                    # the switchgear's left end
const CUB := 2.15
const SG_Y := Vector2(18.6, 26.8)
const RP_C := [55.6, 57.8]            # the radiator pumps
const STEAM_Y := 1.6
const RAD_Y := 0.8
const FEED_Y := 18.95
const BUS_Y := 17.55
const SHORE_Y := 17.95
const TRENCH := [27.15, 27.45, 27.75] # outgoing feeders, condensate, radiator return
const RAD_OUT := 7.8                  # where the radiator headers leave the walls (the booms outside)
const RAD_IN := 20.2
const FEEDER_OUT := 34.0              # where the outgoing feeders go down through the slab (beside the door)

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)
const CONC := Color(0.085, 0.088, 0.094)

var font: Font
var r := Rect2()
var m := 1.0
var _meshes := {}
var _paths := {}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ink(a: float) -> Color:
	return Pal.ink(a)


func _p(v: Vector2) -> Vector2:
	return r.position + v * m


func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


func _put(ci: CanvasItem, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE, k := 1.0) -> void:
	if mesh.get_surface_count() == 0:
		return
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(m * k, m * k), 0.0, _p(at)), mod)


func _text(ci, at: Vector2, s: String, size_m: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	ci.draw_string(font, _p(at), s, align, width_m * m if width_m > 0.0 else -1.0, int(size_m * m), col)


static func lamp_col(state: String, t: float) -> Color:
	match state:
		"ok": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work": return Pal.heat(0.65 + 0.35 * absf(sin(t * 4.0)), 1.3)
		"warn": return Color(1.0, 0.3, 0.22, 0.6 + 0.4 * absf(sin(t * 2.5)))
	return Pal.ink(0.22)


# a plate: its board and words (the slow layer), its lamp (every frame, it may blink)
func plate(ci: CanvasItem, at: Vector2, width: float, name: String, st: Array, _t: float) -> void:
	if not Pal.labels:
		return
	var rr := Rect2(_p(at), Vector2(width, 0.9) * m)
	ci.draw_rect(rr, Color(0.02, 0.022, 0.026, 0.9))
	_text(ci, at + Vector2(0.75, 0.64), name, 0.44, _ink(0.92))
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.44 * m)).x / m
	_text(ci, at + Vector2(1.1 + nw, 0.64), str(st[0]), 0.38, _ink(0.66), HORIZONTAL_ALIGNMENT_LEFT, width - 1.3 - nw)


func plate_lamp(ci: CanvasItem, at: Vector2, st: Array, t: float) -> void:
	var lc := lamp_col(str(st[1]), t)
	ci.draw_rect(Rect2(_p(at), Vector2(0.12, 0.9) * m), lc)
	FastDraw.circle(ci, _p(at + Vector2(0.42, 0.45)), 0.15 * m, lc)


# every plate now: [at, width, name, [state, lamp]]
func _plates(stage: int) -> Array:
	var n := W.unit_count(stage)
	var out: Array = []
	for i in 3:
		out.append([Vector2(BAY_X[i], 2.25), BAY_W, (w("反应堆 %s", "REACTOR %s") % ["A", "B", "C"][i]) if i < n or i < 2 else w("机位 C", "BAY C"), W.unit_state(i)])
	out.append([PLATES.turbine[0], PLATES.turbine[1], w("汽轮发电机", "TURBINE-GENERATOR"), W.turbine_state()])
	out.append([PLATES.fc[0], PLATES.fc[1], w("燃料电池", "FUEL CELLS"), W.fc_state()])
	out.append([PLATES.feed[0], PLATES.feed[1], w("给水泵", "FEED PUMPS"), W.feed_state()])
	out.append([PLATES.rad[0], PLATES.rad[1], w("散热泵", "RAD PUMPS"), W.rad_state()])
	out.append([PLATES.switch[0], PLATES.switch[1], w("配电柜", "SWITCHGEAR"), [w("全港在用 %.1f · 其中电池 %.1f", "IN USE %.1f · BATTERIES %.1f") % [W.own + W.shore, preload("res://scripts/power_supply.gd").batt_now], "ok"]])
	# a changeover being shown: a plate by the machine, amber, put right by the automatics
	if not W.fault.is_empty():
		var fa := W.fault_at()
		var txt := W.fault_text()
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.38 * m)).x / m + 1.6
		var at := Vector2(fa.x - tw, fa.y) if str(W.fault.kind) == "rad" else fa
		out.append([at, tw, "", [txt, "ok" if float(W.fault.t) >= 4.0 else "warn"]])
	return out


const PLATES := {
	"turbine": [Vector2(38.0, 2.4), 19.6], "fc": [Vector2(0.8, 18.55), 8.6], "feed": [Vector2(10.0, 21.2), 10.4],
	"switch": [Vector2(38.6, 16.55), 15.1], "rad": [Vector2(53.9, 18.55), 5.9],
}


# ================================================================== the loops' paths (box-local m)
func paths(stage: int) -> Dictionary:
	if _paths.has(stage):
		return _paths[stage]
	var out := {"hot": [], "cold": [], "steam": [], "feed": [], "cond": [], "rad_out": [], "rad_back": []}
	var n := W.unit_count(stage)
	for i in 3:
		var bx: float = BAY_X[i]
		if i >= n:
			continue
		out.hot.append(PackedVector2Array([Vector2(bx + VX + VR, 8.8), Vector2(bx + 4.9, 8.8), Vector2(bx + 4.9, 15.0), Vector2(bx + SX - 0.45, 15.0), Vector2(bx + SX - 0.45, 14.3)]))
		out.cold.append(PackedVector2Array([Vector2(bx + SX + 0.45, 14.3), Vector2(bx + SX + 0.45, 16.3), Vector2(bx + 8.4, 16.3), Vector2(bx + 8.4, 16.95), Vector2(bx + 0.75, 16.95), Vector2(bx + 0.75, 10.2), Vector2(bx + VX - VR, 10.2)]))
		out.steam.append(PackedVector2Array([Vector2(bx + SX, 3.1), Vector2(bx + SX, STEAM_Y), Vector2(VALVE_X, STEAM_Y), Vector2(VALVE_X, TY), Vector2(38.6, TY)]))
		out.feed.append(PackedVector2Array([Vector2(FW_C[0] + 0.8, FEED_Y), Vector2(bx + FX, FEED_Y), Vector2(bx + FX, 6.8), Vector2(bx + SX + 1.2, 6.8)]))
	out.cond.append(PackedVector2Array([Vector2(COND.position.x + 0.2, COND.end.y - 0.1), Vector2(37.9, COND.end.y - 0.1), Vector2(37.9, TRENCH[1]), Vector2(FW_C[0] + 0.8, TRENCH[1]), Vector2(FW_C[0] + 0.8, 25.7)]))
	out.rad_out.append(PackedVector2Array([Vector2(COND.end.x, 13.0), Vector2(58.4, 13.0), Vector2(58.4, RAD_OUT), Vector2(60.0, RAD_OUT)]))
	out.rad_out.append(PackedVector2Array([Vector2(58.4, RAD_OUT), Vector2(58.4, RAD_Y), Vector2(0.3, RAD_Y), Vector2(0.3, RAD_OUT), Vector2(0.0, RAD_OUT)]))
	out.rad_back.append(PackedVector2Array([Vector2(60.0, RAD_IN), Vector2(59.3, RAD_IN), Vector2(59.3, 25.9), Vector2(RP_C[0], 25.9), Vector2(RP_C[0], 24.6), Vector2(RP_C[0] - 0.75, 24.6), Vector2(RP_C[0] - 0.75, 19.3), Vector2(54.2, 19.3), Vector2(54.2, 15.4), Vector2(COND.end.x, 15.4)]))
	out.rad_back.append(PackedVector2Array([Vector2(0.0, RAD_IN), Vector2(0.3, RAD_IN), Vector2(0.3, TRENCH[2]), Vector2(59.3, TRENCH[2]), Vector2(59.3, 25.9)]))
	# 接驳站穿模修复: the trench's lines stop either side of the door in the floor (the shuttle's track
	# comes up through it) and dive into the page there: an elbow each side, drawn in _pipes
	out["dives"] = []
	for key in ["cond", "rad_back"]:
		var cut: Array = []
		for pl: PackedVector2Array in out[key]:
			cut.append_array(_around_door(pl, out.dives))
		out[key] = cut
	_paths[stage] = out
	return out


const DOOR_GAP := Vector2(26.7, 33.3)   # m: the door in the floor (30 ± 3) and a little more


static func _around_door(pl: PackedVector2Array, dives: Array) -> Array:
	var outs: Array = []
	var cur := PackedVector2Array([pl[0]])
	for i in range(1, pl.size()):
		var a: Vector2 = pl[i - 1]
		var b: Vector2 = pl[i]
		var lo := minf(a.x, b.x)
		var hi := maxf(a.x, b.x)
		if absf(a.y - b.y) < 0.01 and a.y > FLOOR and lo < DOOR_GAP.x and hi > DOOR_GAP.y:
			var s := signf(b.x - a.x)
			var e0 := Vector2(DOOR_GAP.x if s > 0.0 else DOOR_GAP.y, a.y)
			var e1 := Vector2(DOOR_GAP.y if s > 0.0 else DOOR_GAP.x, a.y)
			cur.append(e0)
			outs.append(cur)
			dives.append(e0)
			dives.append(e1)
			cur = PackedVector2Array([e1])
		cur.append(b)
	outs.append(cur)
	return outs


# ================================================================== the still parts
func still(ci: CanvasItem, stage: int, lod: int) -> void:
	# the layer's bounds (a canvas item culls a draw_mesh by its untransformed box; tram 97 号)
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	_put(ci, _mesh("still/%d/%d" % [stage, lod], func(p): _still(p, stage, lod)), Vector2.ZERO)
	if not Pal.labels:
		return
	var n := W.unit_count(stage)
	for i in 3:
		var bx: float = BAY_X[i]
		if i < n or i < 2:
			_text(ci, Vector2(bx + 0.6, BAY_Y.y - 0.3), w("屏蔽墙 · 混凝土 1.2 m", "SHIELD · 1.2 m CONCRETE"), 0.28, _ink(0.38))
			if lod >= 1:
				_text(ci, Vector2(bx + SX - 0.75, 9.6), w("蒸汽", "STEAM"), 0.3, _ink(0.5))
				_text(ci, Vector2(bx + SX - 0.75, 10.0), w("发生器", "GEN."), 0.3, _ink(0.5))
				_text(ci, Vector2(bx + PX - 0.36, 4.95), w("稳压器", "PZR"), 0.26, _ink(0.55))
				_text(ci, Vector2(bx + 7.4, 15.5), w("主泵", "RCP"), 0.28, _ink(0.55))
		else:
			# a stencil on the bay's wall (background, CA.bg): not a sign to read from afar
			_text(ci, Vector2(bx + 1.2, 9.4), w("第 3 套机组机位", "UNIT 3 BAY"), 0.42, CA.bg(_ink(0.55)))
			_text(ci, Vector2(bx + 1.2, 10.0), w("扩建动力区第 2 期时安装", "FITTED AT POWER STAGE 2"), 0.28, CA.bg(Pal.heat(0.7, 1.0)))
	_text(ci, Vector2(39.0, 6.25), w("高压缸", "HP"), 0.34, _ink(0.55))
	_text(ci, Vector2(44.6, 5.55), w("低压缸", "LP"), 0.34, _ink(0.55))
	_text(ci, Vector2(GEN.position.x + 0.2, GEN.position.y - 0.2), w("发电机", "GENERATOR"), 0.34, _ink(0.6))
	_text(ci, Vector2(55.4, 7.1), w("励磁机", "EXC."), 0.28, _ink(0.5))
	_text(ci, Vector2(VALVE_X + 0.55, 3.5), w("主汽门", "STOP"), 0.28, _ink(0.5))
	_text(ci, Vector2(VALVE_X + 0.55, 5.2), w("调节阀", "GOVERNOR"), 0.28, _ink(0.5))
	_text(ci, Vector2(COND.position.x + 0.3, COND.position.y + 0.75), w("冷凝器", "CONDENSER"), 0.36, _ink(0.6))
	_text(ci, Vector2(1.0, RAD_Y - 0.15), w("散热回路 → 外部散热板", "RADIATOR SUPPLY → BOOMS"), 0.28, Pal.heat(0.45, 1.0))
	_text(ci, Vector2(12.0, STEAM_Y - 0.15), w("主蒸汽管", "STEAM MAIN"), 0.28, _ink(0.55))
	_text(ci, Vector2(12.6, FEED_Y - 0.15), w("给水母管", "FEED HEADER"), 0.28, Pal.tint(Pal.AIR, 0.6, 1.0))
	_text(ci, Vector2(12.0, TRENCH[0] + 0.0), w("地沟：馈线 / 凝结水 / 散热回水", "TRENCH: FEEDERS / CONDENSATE / RADIATOR RETURN"), 0.24, _ink(0.4))
	_text(ci, Vector2(FC.position.x + 0.3, FC.position.y + 6.9), w("应急燃料电池组 · 6 MW", "EMERGENCY FUEL CELLS · 6 MW"), 0.28, _ink(0.5))
	_text(ci, Vector2(FC.position.x + 5.35, FC.position.y + 1.9), "H₂", 0.42, Color(0.05, 0.05, 0.05))
	_text(ci, Vector2(FC.position.x + 6.95, FC.position.y + 1.9), "O₂", 0.42, Color(0.05, 0.05, 0.05))
	for i in 3:
		_text(ci, Vector2(FW_C[i] - 1.0, 23.4), "FW-%d" % (i + 1), 0.32, _ink(0.6))
	for i in 2:
		_text(ci, Vector2(RP_C[i] - 0.55, 20.75), "RP-%d" % (i + 1), 0.28, _ink(0.6))
	var names := [["机组进线", "UNITS"], ["电池进线", "BATTERIES"], ["基础·港心", "BASE"], ["拆船坞", "BERTH"], ["加工区", "PROCESS"], ["货运区", "CARGO"], ["拖船站", "TUG"]]
	for i in W.FEEDERS.size():
		var x := SG_X + i * CUB
		_text(ci, Vector2(x + 0.12, SG_Y.x + 1.15), names[i][0] if Txt.zh else names[i][1], 0.3, _ink(0.85), HORIZONTAL_ALIGNMENT_LEFT, CUB - 0.2)
	_text(ci, Vector2(SG_X, SG_Y.x - 0.2), w("10 kV 配电柜 · 每面一条馈线", "10 kV SWITCHGEAR · A FEEDER EACH"), 0.3, _ink(0.6))


func _still(p, stage: int, lod: int) -> void:
	var on := stage >= 1
	_pipes(p, stage, lod)
	for i in 3:
		_bay(p, i, stage, lod)
	_screen_frame(p, lod)
	_turbine(p, on, lod)
	_condenser(p, on, lod)
	_fuel_cells(p, lod)
	for i in 3:
		_feed_pump_base(p, i, lod)
	_switchgear(p, lod)
	for i in 2:
		_rad_pump_base(p, i, lod)


# a pipe: a dark shell, its colour, flanges at the corners
func _pipe(p, pts: PackedVector2Array, wm: float, col: Color, lod: int) -> void:
	p.polyline(pts, Color(0.02, 0.022, 0.026), wm + 0.12)
	p.polyline(pts, col, wm)
	p.polyline(pts, Color(1, 1, 1, 0.08), wm * 0.3)
	if lod >= 1:
		for i in range(1, pts.size() - 1):
			p.rect(Rect2(pts[i] - Vector2(wm, wm) * 0.75, Vector2(wm, wm) * 1.5), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a))


func _pipes(p, stage: int, lod: int) -> void:
	var on := stage >= 1
	var pa := paths(stage)
	# 128 号 第 6 段: pipes are not solid: dim and thin (the steam main read as a wall under the roof)
	var steam := _ink(0.34) if on else _ink(0.18)
	var feed := Pal.tint(Pal.AIR, 0.3, 1.0) if on else _ink(0.16)
	var warm := Pal.heat(0.16, 0.7)
	var cool := Pal.tint(Pal.AIR, 0.22, 1.0)
	for pl in pa.rad_out:
		_pipe(p, pl, 0.22, warm, lod)
	for pl in pa.rad_back:
		_pipe(p, pl, 0.24, cool, lod)
	for pl in pa.cond:
		_pipe(p, pl, 0.22, feed, lod)
	# where the trench's lines dive into the page beside the door: an elbow's flange, end on
	for dv: Vector2 in pa.dives:
		p.circle(dv, 0.2, Color(0.02, 0.022, 0.026), 12)
		p.ring(dv, 0.2, _ink(0.5), 0.05, 12)
		p.circle(dv, 0.07, _ink(0.35), 8)
	for pl in pa.feed:
		_pipe(p, pl, 0.2, feed, lod)
	# the feed pumps' risers into the header
	for i in 3:
		_pipe(p, PackedVector2Array([Vector2(FW_C[i] + 0.8, 24.0), Vector2(FW_C[i] + 0.8, FEED_Y)]), 0.18, feed, lod)
		_pipe(p, PackedVector2Array([Vector2(FW_C[i] + 0.8, TRENCH[1]), Vector2(FW_C[i] + 0.8, 25.7)]), 0.16, feed, lod)
	for pl in pa.steam:
		_pipe(p, pl, 0.3, steam, lod)
	if pa.steam.is_empty():
		_pipe(p, PackedVector2Array([Vector2(BAY_X[0] + SX, STEAM_Y), Vector2(VALVE_X, STEAM_Y), Vector2(VALVE_X, TY), Vector2(38.6, TY)]), 0.3, steam, lod)
	# the radiator pumps' discharges
	_pipe(p, PackedVector2Array([Vector2(RP_C[1], 25.9), Vector2(RP_C[1], 24.6), Vector2(RP_C[1] - 0.75, 24.6), Vector2(RP_C[1] - 0.75, 19.3), Vector2(RP_C[0] - 0.75, 19.3)]), 0.34, cool, lod)
	# the generator's bus duct to its incomer, the shore cable down the right wall
	var volt := Pal.tint(Pal.VOLT, 0.55 if on else 0.2, 1.0)
	p.polyline(PackedVector2Array([Vector2(53.2, GEN.end.y), Vector2(53.2, BUS_Y), Vector2(SG_X + 1.07, BUS_Y), Vector2(SG_X + 1.07, SG_Y.x)]), Color(0.02, 0.022, 0.026), 0.55)
	p.polyline(PackedVector2Array([Vector2(53.2, GEN.end.y), Vector2(53.2, BUS_Y), Vector2(SG_X + 1.07, BUS_Y), Vector2(SG_X + 1.07, SG_Y.x)]), FACE2, 0.42)
	p.polyline(PackedVector2Array([Vector2(53.2, GEN.end.y), Vector2(53.2, BUS_Y), Vector2(SG_X + 1.07, BUS_Y), Vector2(SG_X + 1.07, SG_Y.x)]), volt, 0.08)
	p.polyline(PackedVector2Array([Vector2(59.5, 0.0), Vector2(59.5, SHORE_Y), Vector2(SG_X + CUB + 1.07, SHORE_Y), Vector2(SG_X + CUB + 1.07, SG_Y.x)]), Color(0.02, 0.022, 0.026), 0.24)
	p.polyline(PackedVector2Array([Vector2(59.5, 0.0), Vector2(59.5, SHORE_Y), Vector2(SG_X + CUB + 1.07, SHORE_Y), Vector2(SG_X + CUB + 1.07, SG_Y.x)]), Pal.tint(Pal.VOLT, 0.35, 1.0), 0.12)
	# the outgoing feeders down into the trench and out through the door
	for i in range(2, W.FEEDERS.size()):
		var x := SG_X + i * CUB + 1.07
		p.line(Vector2(x, SG_Y.y), Vector2(x, TRENCH[0]), Pal.tint(Pal.VOLT, 0.35, 1.0), 0.1)
	# (接驳站穿模修复: they went out through the door at 30.4 m, across the shuttle's track: now down
	# through the slab beside it)
	p.line(Vector2(FEEDER_OUT, TRENCH[0]), Vector2(SG_X + 6 * CUB + 1.07, TRENCH[0]), Pal.tint(Pal.VOLT, 0.35, 1.0), 0.14)
	p.line(Vector2(FEEDER_OUT, TRENCH[0]), Vector2(FEEDER_OUT, 28.0), Pal.tint(Pal.VOLT, 0.35, 1.0), 0.14)
	# the trench's covers (none over the door)
	if lod >= 1:
		var x2 := 0.0
		while x2 < 60.0:
			if x2 < DOOR_GAP.x or x2 > DOOR_GAP.y:
				p.line(Vector2(x2, 26.95), Vector2(x2, 27.95), Color(0.12, 0.125, 0.135), 0.04)
			x2 += 1.5


# a reactor bay: the shield, the vessel and core, the rod drives, the steam generator, the
# pressuriser, the main coolant pump, the legs. Or the empty bay with its scaffold (stage < 2)
func _bay(p, i: int, stage: int, lod: int) -> void:
	var bx: float = BAY_X[i]
	var live := i < W.unit_count(stage)
	var shell := Rect2(bx, BAY_Y.x, BAY_W, BAY_Y.y - BAY_Y.x)
	p.rect(shell, CONC)
	p.rect(shell.grow(-0.45), VOID)
	p.rect(shell, _ink(0.45), false, 0.12)
	p.rect(shell.grow(-0.45), _ink(0.25), false, 0.05)
	if lod >= 1:
		# the concrete's rebar ties and the wall's formwork joints
		var y := BAY_Y.x + 1.5
		while y < BAY_Y.y - 0.5:
			p.line(Vector2(bx + 0.05, y), Vector2(bx + 0.4, y), Color(0.13, 0.135, 0.14), 0.04)
			p.line(Vector2(bx + BAY_W - 0.4, y), Vector2(bx + BAY_W - 0.05, y), Color(0.13, 0.135, 0.14), 0.04)
			y += 1.5
	if i == 2 and stage < 2:
		# 128 号 第 6 段: the empty bay is a closed shielded room (solid): a light fill, a bright edge
		p.rect(shell.grow(-0.45), Color(0.075, 0.079, 0.088))
		p.rect(shell, _ink(0.7), false, 0.12)
		_empty_bay(p, bx, lod)
		return
	var edge := _ink(0.78) if live else _ink(0.45)
	var hot := Pal.heat(0.75, 1.0) if live else _ink(0.25)
	var cold := Pal.heat(0.45, 0.9) if live else _ink(0.22)
	var hot_pl := PackedVector2Array([Vector2(bx + VX + VR, 8.8), Vector2(bx + 4.9, 8.8), Vector2(bx + 4.9, 15.0), Vector2(bx + SX - 0.45, 15.0), Vector2(bx + SX - 0.45, 14.3)])
	var cold_pl := PackedVector2Array([Vector2(bx + SX + 0.45, 14.3), Vector2(bx + SX + 0.45, 16.3), Vector2(bx + 8.4, 16.3), Vector2(bx + 8.4, 16.95), Vector2(bx + 0.75, 16.95), Vector2(bx + 0.75, 10.2), Vector2(bx + VX - VR, 10.2)])
	# the surge line behind the steam generator
	_pipe(p, PackedVector2Array([Vector2(bx + PX, 12.6), Vector2(bx + PX, 13.2), Vector2(bx + 4.9, 13.2)]), 0.14, hot, lod)
	_pipe(p, hot_pl, 0.46, hot, lod)
	_pipe(p, cold_pl, 0.42, cold, lod)
	# the vessel: shell, dished heads, the closure flange with its studs
	var vx := bx + VX
	p.rect(Rect2(vx - VR, 6.6, VR * 2.0, 7.6), Color(0.12, 0.126, 0.135))
	p.circle(Vector2(vx, 6.6), VR, Color(0.12, 0.126, 0.135), 24)
	p.circle(Vector2(vx, 14.2), VR, Color(0.12, 0.126, 0.135), 24)
	p.arc(Vector2(vx, 6.6), VR, PI, TAU, edge, 0.12, 20)
	p.arc(Vector2(vx, 14.2), VR, 0.0, PI, edge, 0.12, 20)
	p.line(Vector2(vx - VR, 6.6), Vector2(vx - VR, 14.2), edge, 0.12)
	p.line(Vector2(vx + VR, 6.6), Vector2(vx + VR, 14.2), edge, 0.12)
	# the core barrel and the upper internals' guide tubes
	p.rect(Rect2(vx - 1.35, 10.95, 2.7, 2.45), Color(0.07, 0.074, 0.08))
	p.rect(Rect2(vx - 1.35, 10.95, 2.7, 2.45), _ink(0.35), false, 0.05)
	for k in 4:
		var gx := vx - 0.99 + k * 0.66
		p.line(Vector2(gx, 7.3), Vector2(gx, 10.95), _ink(0.2), 0.12)
	p.rect(Rect2(vx - VR - 0.5, 6.3, VR * 2.0 + 1.0, 0.6), FACE2)
	p.rect(Rect2(vx - VR - 0.5, 6.3, VR * 2.0 + 1.0, 0.6), edge, false, 0.05)
	if lod >= 1:
		for k in 7:
			p.bolt(Vector2(vx - VR - 0.3 + k * (VR * 2.0 + 0.6) / 6.0, 6.6), 0.09, _ink(0.6))
	# the rod drives: four housings on the head, their coil stacks
	for k in 4:
		var hx := vx - 0.99 + k * 0.66
		p.rect(Rect2(hx - 0.2, 3.8, 0.4, 2.5), Color(0.15, 0.16, 0.17))
		p.rect(Rect2(hx - 0.2, 3.8, 0.4, 2.5), edge, false, 0.04)
		if lod >= 1:
			for c in 4:
				p.rect(Rect2(hx - 0.24, 4.3 + c * 0.42, 0.48, 0.24), Color(0.2, 0.21, 0.22))
		p.circle(Vector2(hx, 3.8), 0.2, Color(0.15, 0.16, 0.17), 10)
	# the steam generator: the drum with its dome, the shell, the U-tubes, the tube sheet, the plenum
	var sx := bx + SX
	p.circle(Vector2(sx, 4.3), 1.2, Color(0.13, 0.137, 0.147), 22)
	p.rect(Rect2(sx - 1.2, 4.3, 2.4, 3.3), Color(0.13, 0.137, 0.147))
	p.poly(PackedVector2Array([Vector2(sx - 1.2, 7.6), Vector2(sx + 1.2, 7.6), Vector2(sx + 0.95, 8.3), Vector2(sx - 0.95, 8.3)]), Color(0.13, 0.137, 0.147))
	p.rect(Rect2(sx - 0.95, 8.3, 1.9, 5.3), Color(0.115, 0.12, 0.13))
	p.circle(Vector2(sx, 13.6), 0.95, Color(0.115, 0.12, 0.13), 18)
	p.arc(Vector2(sx, 4.3), 1.2, PI, TAU, edge, 0.1, 18)
	p.polyline(PackedVector2Array([Vector2(sx - 1.2, 4.3), Vector2(sx - 1.2, 7.6), Vector2(sx - 0.95, 8.3), Vector2(sx - 0.95, 13.6)]), edge, 0.1)
	p.polyline(PackedVector2Array([Vector2(sx + 1.2, 4.3), Vector2(sx + 1.2, 7.6), Vector2(sx + 0.95, 8.3), Vector2(sx + 0.95, 13.6)]), edge, 0.1)
	p.arc(Vector2(sx, 13.6), 0.95, 0.0, PI, edge, 0.1, 16)
	p.line(Vector2(sx - 0.95, 13.6), Vector2(sx + 0.95, 13.6), edge, 0.14)
	p.line(Vector2(sx, 13.6), Vector2(sx, 14.55), _ink(0.4), 0.06)
	var tubes := 4 if lod >= 1 else 2
	for k in tubes:
		var rr := 0.2 + k * (0.65 / tubes)
		p.line(Vector2(sx - rr, 13.6), Vector2(sx - rr, 9.0), Pal.heat(0.25, 1.0) if live else _ink(0.18), 0.05)
		p.line(Vector2(sx + rr, 13.6), Vector2(sx + rr, 9.0), Pal.tint(Pal.AIR, 0.25, 1.0) if live else _ink(0.18), 0.05)
		p.arc(Vector2(sx, 9.0), rr, PI, TAU, _ink(0.3), 0.05, 10)
	if lod >= 1:
		# the moisture separators in the drum, the feed ring
		for k in 3:
			p.rect(Rect2(sx - 0.8 + k * 0.6, 4.6, 0.4, 1.5), Color(0.09, 0.095, 0.1))
			p.rect(Rect2(sx - 0.8 + k * 0.6, 4.6, 0.4, 1.5), _ink(0.35), false, 0.03)
		p.line(Vector2(sx - 1.1, 6.8), Vector2(sx + 1.1, 6.8), Pal.tint(Pal.AIR, 0.4, 1.0), 0.06)
	# the pressuriser: a tall capsule, its heaters at the bottom, the relief valve on top
	var px := bx + PX
	p.rect(Rect2(px - 0.4, 5.6, 0.8, 6.6), Color(0.13, 0.137, 0.147))
	p.circle(Vector2(px, 5.6), 0.4, Color(0.13, 0.137, 0.147), 12)
	p.circle(Vector2(px, 12.2), 0.4, Color(0.13, 0.137, 0.147), 12)
	p.arc(Vector2(px, 5.6), 0.4, PI, TAU, edge, 0.07, 10)
	p.arc(Vector2(px, 12.2), 0.4, 0.0, PI, edge, 0.07, 10)
	p.line(Vector2(px - 0.4, 5.6), Vector2(px - 0.4, 12.2), edge, 0.07)
	p.line(Vector2(px + 0.4, 5.6), Vector2(px + 0.4, 12.2), edge, 0.07)
	p.rect(Rect2(px - 0.12, 4.75, 0.24, 0.45), FACE2)
	p.line(Vector2(px, 4.75), Vector2(px + 0.45, 4.75), _ink(0.5), 0.06)
	if lod >= 1:
		for k in 3:
			p.line(Vector2(px - 0.25 + k * 0.25, 11.2), Vector2(px - 0.25 + k * 0.25, 12.4), _ink(0.3), 0.05)
		# its level glass
		p.rect(Rect2(px + 0.42, 7.0, 0.1, 3.4), Color(0.05, 0.06, 0.07))
	# the main coolant pump: motor on its stand, coupling, the volute on the cold leg
	var mpx := bx + 8.4
	p.rect(Rect2(mpx - 0.45, 14.4, 0.9, 1.3), Color(0.15, 0.16, 0.17))
	p.rect(Rect2(mpx - 0.45, 14.4, 0.9, 1.3), edge, false, 0.05)
	if lod >= 1:
		for k in 4:
			p.line(Vector2(mpx - 0.45, 14.6 + k * 0.28), Vector2(mpx + 0.45, 14.6 + k * 0.28), _ink(0.28), 0.03)
	p.line(Vector2(mpx, 15.7), Vector2(mpx, 15.95), _ink(0.6), 0.12)
	p.circle(Vector2(mpx, 16.35), 0.48, Color(0.12, 0.125, 0.135), 16)
	p.ring(Vector2(mpx, 16.35), 0.48, cold if live else edge, 0.07, 16)


func _empty_bay(p, bx: float, lod: int) -> void:
	# scaffold towers, cover plates over the vessel pit, the capped stubs of the steam and feed lines
	var col := _ink(0.28)
	for sxx in [bx + 1.2, bx + 4.6, bx + 8.0]:
		p.line(Vector2(sxx, 4.2), Vector2(sxx, 16.6), col, 0.1)
	var y := 4.6
	while y < 16.4:
		p.line(Vector2(bx + 1.2, y), Vector2(bx + 8.0, y), col, 0.06)
		if lod >= 1:
			p.line(Vector2(bx + 1.2, y), Vector2(bx + 4.6, y + 2.0), _ink(0.16), 0.04)
			p.line(Vector2(bx + 4.6, y), Vector2(bx + 8.0, y + 2.0), _ink(0.16), 0.04)
		y += 2.0
	for k in 3:
		p.rect(Rect2(bx + 1.0 + k * 2.5, 16.4, 2.3, 0.6), FACE)
		p.rect(Rect2(bx + 1.0 + k * 2.5, 16.4, 2.3, 0.6), _ink(0.4), false, 0.04)
	p.hatch(Rect2(bx + 0.6, 16.95, BAY_W - 1.2, 0.18), Pal.heat(0.5, 1.0), 0.06, 0.4)
	for at in [Vector2(bx + SX, 3.1), Vector2(bx + FX, 7.0)]:
		p.rect(Rect2(at - Vector2(0.35, 0.12), Vector2(0.7, 0.24)), Pal.heat(0.55, 1.0))


# the main control screen's frame (its content is drawn live). 2026-11-10 (user: what nobody can use must
# read as background): set into the wall like a gauge panel — a flat plate bolted flush, no hangers, no
# bright bezel; the console under it is the one to use (scripts/console_art.gd has the two looks)
func _screen_frame(p, lod: int) -> void:
	p.rect(SCREEN.grow(0.45), FACE)
	p.rect(SCREEN.grow(0.45), _ink(0.2), false, 0.05)
	p.rect(SCREEN, CA.BG_GLASS)
	p.rect(SCREEN, _ink(0.14), false, 0.04)
	if lod >= 1:
		for c in [SCREEN.position, Vector2(SCREEN.end.x, SCREEN.position.y), SCREEN.end, Vector2(SCREEN.position.x, SCREEN.end.y)]:
			p.bolt(c + (SCREEN.get_center() - c).normalized() * -0.3, 0.06, _ink(0.3))


# the turbine-generator on its deck: HP and LP casings with the crossover, bearings, the shaft, the
# coupling, the generator with its core, the exciter; the stop and governor valves on the steam main
func _turbine(p, on: bool, lod: int) -> void:
	var edge := _ink(0.8) if on else _ink(0.5)
	# the deck and its columns
	p.rect(Rect2(37.6, DECK.x, 20.4, DECK.y - DECK.x), CONC)
	p.rect(Rect2(37.6, DECK.x, 20.4, DECK.y - DECK.x), _ink(0.45), false, 0.08)
	for cx in [38.2, 42.4, 50.3, 57.4]:
		p.rect(Rect2(cx - 0.3, DECK.y, 0.6, 3.9), CONC)
	# the exhaust neck under the LP casing into the condenser
	p.poly(PackedVector2Array([Vector2(44.0, TY + 2.4), Vector2(48.8, TY + 2.4), Vector2(49.2, DECK.y), Vector2(43.4, DECK.y)]), Color(0.1, 0.105, 0.112))
	# the valves: stop valve, then the governor valve with its actuator yoke (the stem is live)
	p.rect(Rect2(VALVE_X - 0.5, 3.0, 1.0, 1.0), FACE2)
	p.rect(Rect2(VALVE_X - 0.5, 3.0, 1.0, 1.0), edge, false, 0.05)
	p.circle(Vector2(VALVE_X, 3.5), 0.28, Color(0.08, 0.085, 0.09), 12)
	p.rect(Rect2(VALVE_X - 0.55, 5.0, 1.1, 1.1), FACE2)
	p.rect(Rect2(VALVE_X - 0.55, 5.0, 1.1, 1.1), edge, false, 0.05)
	p.line(Vector2(VALVE_X - 0.5, 4.2), Vector2(VALVE_X - 0.5, 5.0), _ink(0.5), 0.06)
	p.line(Vector2(VALVE_X + 0.5, 4.2), Vector2(VALVE_X + 0.5, 5.0), _ink(0.5), 0.06)
	p.rect(Rect2(VALVE_X - 0.6, 4.05, 1.2, 0.18), _ink(0.5))
	# HP casing, crossover, LP casing
	var hp := PackedVector2Array([Vector2(38.6, TY - 1.0), Vector2(42.6, TY - 1.7), Vector2(42.6, TY + 1.7), Vector2(38.6, TY + 1.0)])
	var lp := PackedVector2Array([Vector2(43.0, TY - 1.7), Vector2(49.6, TY - 2.8), Vector2(49.6, TY + 2.4), Vector2(43.0, TY + 1.7)])
	p.poly(hp, Color(0.15, 0.16, 0.17))
	p.polyline(hp, edge, 0.1, true)
	p.poly(lp, Color(0.14, 0.15, 0.16))
	p.polyline(lp, edge, 0.1, true)
	p.polyline(PackedVector2Array([Vector2(41.8, TY - 1.55), Vector2(41.8, 5.4), Vector2(44.6, 5.4), Vector2(44.6, TY - 1.95)]), Color(0.02, 0.022, 0.026), 0.62)
	p.polyline(PackedVector2Array([Vector2(41.8, TY - 1.55), Vector2(41.8, 5.4), Vector2(44.6, 5.4), Vector2(44.6, TY - 1.95)]), _ink(0.5) if on else _ink(0.25), 0.5)
	# the blade rows seen through the casings' cut: stages growing towards the exhaust
	var rows := 8 if lod >= 1 else 4
	for k in rows:
		var bxx := 39.0 + k * (3.4 / rows)
		var hh := 0.7 + k * 0.08
		p.line(Vector2(bxx, TY - hh), Vector2(bxx, TY + hh), _ink(0.32), 0.05)
	for k in rows:
		var bxx := 43.5 + k * (5.8 / rows)
		var hh := 1.2 + k * (1.3 / rows)
		p.line(Vector2(bxx, TY - hh), Vector2(bxx, TY + hh), _ink(0.32), 0.06)
	# bearings on their pedestals, the shaft, the coupling
	for bxx in [38.2, 42.8, 50.3, 55.6, 57.6]:
		p.rect(Rect2(bxx - 0.35, TY + 0.3, 0.7, DECK.x - TY - 0.3), FACE)
		p.rect(Rect2(bxx - 0.35, TY + 0.3, 0.7, DECK.x - TY - 0.3), _ink(0.4), false, 0.04)
	p.line(Vector2(37.9, TY), Vector2(57.9, TY), _ink(0.72), 0.2)
	p.circle(Vector2(50.3, TY), 0.62, Color(0.12, 0.12, 0.13), 16)
	p.ring(Vector2(50.3, TY), 0.62, edge, 0.08, 16)
	# the generator: its frame, the stator core's slots, the cooler on top
	p.rect(GEN, Color(0.13, 0.14, 0.15))
	p.rect(GEN, Pal.tint(Pal.VOLT, 0.6, 1.0) if on else edge, false, 0.1)
	var slots := 10 if lod >= 1 else 5
	for k in slots:
		var gx := GEN.position.x + 0.3 + k * (GEN.size.x - 0.6) / (slots - 1)
		p.line(Vector2(gx, GEN.position.y + 0.3), Vector2(gx, GEN.end.y - 0.3), _ink(0.22), 0.05)
	p.rect(Rect2(GEN.position.x + 0.6, GEN.position.y - 0.7, GEN.size.x - 1.2, 0.7), FACE)
	p.rect(Rect2(GEN.position.x + 0.6, GEN.position.y - 0.7, GEN.size.x - 1.2, 0.7), _ink(0.4), false, 0.04)
	if lod >= 1:
		for k in 6:
			p.line(Vector2(GEN.position.x + 0.8 + k * 0.5, GEN.position.y - 0.6), Vector2(GEN.position.x + 0.8 + k * 0.5, GEN.position.y - 0.1), _ink(0.3), 0.04)
	# the exciter
	p.circle(Vector2(56.6, TY), 0.8, Color(0.12, 0.12, 0.13), 18)
	p.ring(Vector2(56.6, TY), 0.8, edge, 0.08, 18)


func _condenser(p, on: bool, lod: int) -> void:
	var edge := _ink(0.7) if on else _ink(0.45)
	p.rect(COND, Color(0.1, 0.115, 0.13))
	p.rect(COND, edge, false, 0.08)
	# the tube bundle, the hotwell under it
	if lod >= 1:
		for i in 9:
			for j in 3:
				p.ring(Vector2(COND.position.x + 0.6 + i * 0.68, COND.position.y + 1.4 + j * 0.6), 0.2, Pal.tint(Pal.AIR, 0.35, 1.0), 0.04, 8)
	else:
		p.rect(Rect2(COND.position.x + 0.4, COND.position.y + 1.1, COND.size.x - 0.8, 1.7), Pal.tint(Pal.AIR, 0.12, 1.0))
	p.rect(Rect2(COND.position.x + 0.2, COND.end.y - 0.55, COND.size.x - 0.4, 0.4), Color(0.06, 0.08, 0.1))


func _fuel_cells(p, lod: int) -> void:
	var edge := _ink(0.65)
	var cab := Rect2(FC.position.x + 0.2, FC.position.y + 0.9, 4.3, 5.6)
	p.rect(cab, FACE)
	p.rect(cab, edge, false, 0.06)
	# three stacks of cells, their end plates and tie rods
	for k in 3:
		var sr := Rect2(cab.position.x + 0.3 + k * 1.35, cab.position.y + 1.2, 1.1, 3.9)
		p.rect(sr, Color(0.09, 0.1, 0.11))
		var n := 14 if lod >= 1 else 6
		for c in n:
			p.line(Vector2(sr.position.x + 0.1, sr.position.y + 0.2 + c * (3.5 / n)), Vector2(sr.end.x - 0.1, sr.position.y + 0.2 + c * (3.5 / n)), _ink(0.28), 0.04)
		p.rect(Rect2(sr.position.x, sr.position.y - 0.15, 1.1, 0.15), _ink(0.5))
		p.rect(Rect2(sr.position.x, sr.end.y, 1.1, 0.15), _ink(0.5))
	# the fans' housings on top (their blades are live)
	for k in 2:
		p.circle(Vector2(cab.position.x + 1.2 + k * 1.9, cab.position.y + 0.55), 0.48, Color(0.05, 0.055, 0.06), 16)
		p.ring(Vector2(cab.position.x + 1.2 + k * 1.9, cab.position.y + 0.55), 0.48, edge, 0.05, 16)
	# the H2 and O2 bottles
	for k in 2:
		var bx := FC.position.x + 5.0 + k * 1.6
		var col := Pal.tint(Pal.AIR, 0.55, 1.0) if k == 0 else Pal.ink(0.6)
		p.rect(Rect2(bx, FC.position.y + 1.4, 1.3, 5.2), col)
		p.circle(Vector2(bx + 0.65, FC.position.y + 1.4), 0.65, col, 14)
		p.rect(Rect2(bx + 0.5, FC.position.y + 0.3, 0.3, 0.5), _ink(0.6))
		p.line(Vector2(bx + 0.65, FC.position.y + 0.3), Vector2(bx + 0.65, cab.position.y + 0.1), _ink(0.4), 0.05)
	p.line(Vector2(FC.position.x + 5.65, cab.position.y + 0.1), Vector2(cab.end.x, cab.position.y + 0.1), _ink(0.4), 0.05)
	# the inverter's cable to the bus
	p.line(Vector2(cab.end.x - 0.4, cab.position.y), Vector2(cab.end.x - 0.4, FC.position.y - 0.6), Pal.tint(Pal.VOLT, 0.4, 1.0), 0.1)


func _feed_pump_base(p, i: int, lod: int) -> void:
	var c: float = FW_C[i]
	p.rect(Rect2(c - 1.6, 25.9, 3.4, 0.9), CONC)
	p.rect(Rect2(c - 1.6, 25.9, 3.4, 0.9), _ink(0.35), false, 0.04)
	if lod >= 1:
		for k in 4:
			p.bolt(Vector2(c - 1.35 + k * 0.95, 26.1), 0.07, _ink(0.5))


func _rad_pump_base(p, i: int, lod: int) -> void:
	var c: float = RP_C[i]
	p.rect(Rect2(c - 0.9, 25.6, 1.8, 1.2), CONC)
	p.rect(Rect2(c - 0.9, 25.6, 1.8, 1.2), _ink(0.35), false, 0.04)


func _switchgear(p, lod: int) -> void:
	var edge := _ink(0.6)
	var all := Rect2(SG_X, SG_Y.x, CUB * W.FEEDERS.size(), SG_Y.y - SG_Y.x)
	p.rect(all, Color(0.09, 0.095, 0.1))
	# the busbar chamber along the top, three phases
	p.rect(Rect2(SG_X, SG_Y.x, all.size.x, 0.7), Color(0.06, 0.064, 0.07))
	for k in 3:
		p.line(Vector2(SG_X + 0.1, SG_Y.x + 0.18 + k * 0.17), Vector2(all.end.x - 0.1, SG_Y.x + 0.18 + k * 0.17), Pal.tint(Pal.VOLT, 0.55, 1.0), 0.07)
	for i in W.FEEDERS.size():
		var x := SG_X + i * CUB
		var door := Rect2(x + 0.06, SG_Y.x + 0.75, CUB - 0.12, 6.9)
		p.rect(door, Color(0.12, 0.128, 0.138))
		p.rect(door, edge, false, 0.05)
		# the breaker's window (its truck is live), the ammeter's dial, the vents
		p.rect(Rect2(x + 0.25, SG_Y.x + 2.6, CUB - 0.5, 1.7), Color(0.03, 0.033, 0.038))
		p.rect(Rect2(x + 0.25, SG_Y.x + 2.6, CUB - 0.5, 1.7), _ink(0.35), false, 0.03)
		p.circle(Vector2(x + CUB * 0.5, SG_Y.x + 5.3), 0.62, Color(0.85, 0.86, 0.84), 18)
		p.arc(Vector2(x + CUB * 0.5, SG_Y.x + 5.3), 0.5, PI * 1.15, PI * 1.85, Color(0.1, 0.1, 0.1), 0.05, 10)
		p.arc(Vector2(x + CUB * 0.5, SG_Y.x + 5.3), 0.5, PI * 1.7, PI * 1.85, Pal.heat(0.9, 1.0), 0.06, 4)
		if lod >= 1:
			for k in 5:
				p.line(Vector2(x + 0.4, SG_Y.x + 6.5 + k * 0.18), Vector2(x + CUB - 0.4, SG_Y.x + 6.5 + k * 0.18), _ink(0.25), 0.04)
			p.rect(Rect2(x + CUB - 0.35, SG_Y.x + 3.0, 0.12, 0.8), _ink(0.5))
	p.rect(all, edge, false, 0.06)


# ================================================================== the moving parts
func moving(ci: CanvasItem, t: float, stage: int, lod: int) -> void:
	var pa := paths(stage)
	var n := W.unit_count(stage)
	var step := 1.6 if lod >= 1 else 3.2
	# the flow: dots along each loop at its own pace
	for pl in pa.hot:
		_dots(ci, pl, W.flow[0] * 3.0, step, Pal.heat(0.95, 1.4), 0.13)
	for pl in pa.cold:
		_dots(ci, pl, W.flow[0] * 3.0, step, Pal.heat(0.6, 1.1), 0.12)
	for pl in pa.steam:
		_dots(ci, pl, W.flow[1] * 5.0, step * 1.4, _ink(0.55), 0.09)
	if W.flow[1] > 0.0 and W.units > 0:
		for pl in pa.feed:
			_dots(ci, pl, W.flow[1] * 2.5, step, Pal.tint(Pal.AIR, 0.95, 1.3), 0.11)
		for pl in pa.cond:
			_dots(ci, pl, W.flow[1] * 2.5, step, Pal.tint(Pal.AIR, 0.75, 1.2), 0.1)
	for pl in pa.rad_out:
		_dots(ci, pl, W.flow[2] * 3.0, step * 1.3, Pal.heat(0.3 + 0.4 * clampf((W.rad_t - 20.0) / 90.0, 0.0, 1.0), 1.1), 0.1)
	for pl in pa.rad_back:
		_dots(ci, pl, W.flow[2] * 3.0, step * 1.3, Pal.tint(Pal.AIR, 0.7, 1.2), 0.11)
	for i in 3:
		if i < n or (i < 2):
			_bay_moving(ci, i, t, i < n, lod)
	_turbine_moving(ci, t, lod)
	_fc_moving(ci, t)
	_pumps_moving(ci, t)
	_switch_moving(ci, t)
	for pl in _plates(stage):
		plate_lamp(ci, pl[0], pl[3], t)


# the words that change (plates, the screen, the meters' figures): a slow layer, five times a second
func words(ci: CanvasItem, t: float, stage: int, lod: int) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	_screen(ci, t, stage)
	for pl in _plates(stage):
		plate(ci, pl[0], pl[1], pl[2], pl[3], t)
	var n := W.unit_count(stage)
	if lod >= 1:
		for i in mini(n, 3):
			var bx: float = BAY_X[i]
			_text(ci, Vector2(bx + 0.95, 8.55), "%.0f°" % W.t_hot[i], 0.34, Pal.heat(0.9, 1.2))
			_text(ci, Vector2(bx + 0.95, 11.2), "%.0f°" % W.t_cold[i], 0.3, Pal.heat(0.6, 1.0))
		_text(ci, Vector2(51.2, TY + 0.25), "%.2f Hz" % W.hz, 0.42, Pal.tint(Pal.VOLT, 0.95, 1.3) if W.units > 0 else _ink(0.4))
		_text(ci, Vector2(VALVE_X + 0.65, 5.85), "%d%%" % int(W.valve * 100.0), 0.3, Pal.heat(0.8, 1.1))
		_text(ci, Vector2(COND.position.x + 0.3, COND.end.y - 0.7), "%.0f °C" % W.t_cond, 0.34, Pal.tint(Pal.AIR, 0.85, 1.1) if W.units > 0 else _ink(0.4))
	if W.fc > 0.05:
		_text(ci, Vector2(FC.position.x + 0.5, FC.position.y + 6.45), "%.1f MW" % W.fc, 0.42, Pal.tint(Pal.VOLT, 0.95, 1.3))
	for i in W.FEEDERS.size():
		var k: String = W.FEEDERS[i]
		var x := SG_X + i * CUB
		var closed := float(W.breaker.get(k, 0.0)) >= 0.99
		_text(ci, Vector2(x + 0.65, SG_Y.x + 2.05), "I" if closed else "O", 0.36, Pal.tint(Pal.FLUID, 0.95, 1.3) if closed else Pal.heat(0.5, 1.0))
		var mw := W.feeder_mw(k)
		_text(ci, Vector2(x + 0.12, SG_Y.x + 7.25), ("%.1f" % mw) if mw > 0.005 else "—", 0.36, Pal.tint(Pal.VOLT, 0.95, 1.2) if mw > 0.005 else _ink(0.4), HORIZONTAL_ALIGNMENT_CENTER, CUB - 0.24)


func _dots(ci: CanvasItem, pl: PackedVector2Array, run: float, step: float, col: Color, rad: float) -> void:
	var d := fposmod(run, step)
	var s := 0.0
	for i in range(1, pl.size()):
		var a: Vector2 = pl[i - 1]
		var b: Vector2 = pl[i]
		var seg := a.distance_to(b)
		while d < s + seg:
			FastDraw.circle(ci, _p(a.lerp(b, (d - s) / seg)), rad * m, col)
			d += step
		s += seg


func _core_mesh() -> ArrayMesh:
	return _mesh("core", func(p):
		for i in 4:
			for j in 3:
				p.rect(Rect2(-1.32 + i * 0.66, j * 0.66, 0.6, 0.6), Color.WHITE)
				p.rect(Rect2(-1.32 + i * 0.66, j * 0.66, 0.6, 0.6), Color(0.3, 0.3, 0.3), false, 0.04))


func _bay_moving(ci: CanvasItem, i: int, t: float, live: bool, lod: int) -> void:
	var bx: float = BAY_X[i]
	var vx := bx + VX
	var q := float(W.q_th[i]) / maxf(1.0, W.cap / maxf(1, W.units) / W.ETA) if live else 0.0
	var glow := Pal.heat(0.18 + 0.75 * q, 1.0 + 0.6 * q) if live else Color(0.12, 0.12, 0.12)
	_put(ci, _core_mesh(), Vector2(vx, CORE_Y), 0.0, glow)
	# Cherenkov-blue over the core while it makes heat
	if live and q > 0.02:
		ci.draw_rect(Rect2(_p(Vector2(vx - 1.35, CORE_Y - 0.25)), Vector2(2.7, 2.4) * m), Pal.tint(Pal.AIR, 0.06 + 0.12 * q * (0.85 + 0.15 * sin(t * 2.0 + i)), 1.4))
	# the rods: in as deep as they stand; the drives' position marks
	var tip := CORE_Y + 1.92 * (1.0 - float(W.rods[i])) + 0.0
	for k in 4:
		var hx := vx - 0.99 + k * 0.66
		ci.draw_line(_p(Vector2(hx, 6.9)), _p(Vector2(hx, tip)), _ink(0.85), maxf(1.0, 0.1 * m))
		ci.draw_rect(Rect2(_p(Vector2(hx - 0.14, 3.9 + 2.2 * (1.0 - float(W.rods[i])))), Vector2(0.28, 0.12) * m), Pal.tint(Pal.FLUID, 0.9, 1.3) if live else _ink(0.4))
	# the pressuriser's heaters, glowing as they work; its level
	var px := bx + PX
	if live:
		ci.draw_rect(Rect2(_p(Vector2(px - 0.3, 11.1)), Vector2(0.6, 1.2) * m), Pal.heat(0.15 + 0.6 * float(W.pzr[i]), 1.3))
		var lvl := 0.4 + 0.2 * clampf(float(W.q_th[i]) / maxf(1.0, W.cap / maxf(1, W.units) / W.ETA), 0.0, 1.0)
		ci.draw_rect(Rect2(_p(Vector2(px + 0.42, 10.4 - 3.4 * lvl)), Vector2(0.1, 3.4 * lvl) * m), Pal.tint(Pal.AIR, 0.8, 1.2))
	# the main coolant pump's impeller turning
	var mpx := bx + 8.4
	var a0 := t * 14.0 * float(W.mcp[i])
	for k in 3:
		var a := a0 + TAU * k / 3.0
		ci.draw_line(_p(Vector2(mpx, 16.35)), _p(Vector2(mpx, 16.35)) + Vector2.from_angle(a) * 0.38 * m, _ink(0.75), maxf(1.0, 0.07 * m))


func _valve_mesh() -> ArrayMesh:
	return _mesh("stem", func(p):
		p.rect(Rect2(-0.08, -0.9, 0.16, 0.9), Pal.ink(0.75))
		p.rect(Rect2(-0.35, -1.05, 0.7, 0.18), Pal.heat(0.7, 1.0)))


func _turbine_moving(ci: CanvasItem, t: float, lod: int) -> void:
	# the governor valve's stem: up as it opens
	_put(ci, _valve_mesh(), Vector2(VALVE_X, 5.0 - 0.55 * W.valve))
	# the shaft's marks on the coupling and the exciter
	for c in [Vector2(50.3, TY), Vector2(56.6, TY)]:
		for k in 3:
			var a := W.spin * 10.0 + TAU * k / 3.0
			ci.draw_line(_p(c), _p(c) + Vector2.from_angle(a) * 0.55 * m, _ink(0.55 + 0.35 * clampf(W.hz / 50.0, 0.0, 1.0)), maxf(1.0, 0.09 * m))
	# the generator's core warming with its load
	if W.units > 0:
		ci.draw_rect(Rect2(_p(GEN.position + Vector2(0.15, 0.15)), (GEN.size - Vector2(0.3, 0.3)) * m), Pal.tint(Pal.VOLT, 0.02 + 0.08 * W.frac(), 1.2))
	# steam in the casings
	if W.units > 0 and W.valve > 0.01:
		var k2 := 0.05 + 0.1 * W.valve
		ci.draw_rect(Rect2(_p(Vector2(38.8, TY - 0.8)), Vector2(3.6, 1.6) * m), Color(1, 1, 1, k2))
		ci.draw_rect(Rect2(_p(Vector2(43.2, TY - 1.4)), Vector2(6.2, 2.8) * m), Color(1, 1, 1, k2 * 0.7))


func _fan_mesh() -> ArrayMesh:
	return _mesh("fan", func(p):
		for k in 5:
			var a := TAU * k / 5.0
			p.poly(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.18) * 0.42, Vector2.from_angle(a + 0.22) * 0.42]), Pal.ink(0.55))
		p.circle(Vector2.ZERO, 0.1, Pal.ink(0.8), 8))


func _fc_moving(ci: CanvasItem, t: float) -> void:
	var cab := Rect2(FC.position.x + 0.2, FC.position.y + 0.9, 4.3, 5.6)
	for k in 2:
		_put(ci, _fan_mesh(), Vector2(cab.position.x + 1.2 + k * 1.9, cab.position.y + 0.55), t * 18.0 * W.fc_fan + k)
	if W.fc > 0.05:
		var q := clampf(W.fc / 6.0, 0.0, 1.0)
		for k in 3:
			ci.draw_rect(Rect2(_p(Vector2(cab.position.x + 0.3 + k * 1.35, cab.position.y + 1.2)), Vector2(1.1, 3.9) * m), Pal.heat(0.05 + 0.18 * q, 1.2))


func _feed_pump_mesh() -> ArrayMesh:
	return _mesh("fwpump", func(p):
		# origin: the shaft line's middle over the skid; motor left, pump right
		p.rect(Rect2(-1.45, -0.95, 1.6, 1.9), Color(0.15, 0.16, 0.17))
		p.rect(Rect2(-1.45, -0.95, 1.6, 1.9), Pal.ink(0.65), false, 0.05)
		for k in 5:
			p.line(Vector2(-1.35 + k * 0.32, -0.95), Vector2(-1.35 + k * 0.32, 0.95), Pal.ink(0.25), 0.04)
		p.rect(Rect2(0.15, -0.18, 0.35, 0.36), Pal.ink(0.5))
		p.circle(Vector2(0.95, 0.0), 0.75, Color(0.12, 0.125, 0.135), 18)
		p.ring(Vector2(0.95, 0.0), 0.75, Pal.tint(Pal.AIR, 0.6, 1.0), 0.07, 18)
		p.rect(Rect2(0.75, -1.2, 0.4, 0.45), Color(0.12, 0.125, 0.135))
		p.rect(Rect2(-1.5, 0.95, 3.2, 0.12), Pal.ink(0.4)))


func _rad_pump_mesh() -> ArrayMesh:
	return _mesh("rppump", func(p):
		# origin: the volute's centre; the motor stands on top
		p.rect(Rect2(-0.55, -3.6, 1.1, 2.6), Color(0.15, 0.16, 0.17))
		p.rect(Rect2(-0.55, -3.6, 1.1, 2.6), Pal.ink(0.65), false, 0.05)
		for k in 6:
			p.line(Vector2(-0.55, -3.4 + k * 0.4), Vector2(0.55, -3.4 + k * 0.4), Pal.ink(0.25), 0.04)
		p.rect(Rect2(-0.25, -1.0, 0.5, 0.35), Pal.ink(0.45))
		p.circle(Vector2.ZERO, 0.62, Color(0.12, 0.125, 0.135), 16)
		p.ring(Vector2.ZERO, 0.62, Pal.heat(0.4, 0.9), 0.07, 16))


func _pumps_moving(ci: CanvasItem, t: float) -> void:
	for i in 3:
		var shake := Vector2(sin(t * 61.0), cos(t * 47.0)) * 0.05 * float(W.vib[i])
		var at := Vector2(FW_C[i], FW_Y) + shake
		_put(ci, _feed_pump_mesh(), at)
		var sp := float(W.fw[i])
		for k in 3:
			var a := t * 16.0 * sp + TAU * k / 3.0
			ci.draw_line(_p(at + Vector2(0.95, 0.0)), _p(at + Vector2(0.95, 0.0)) + Vector2.from_angle(a) * 0.6 * m, _ink(0.75), maxf(1.0, 0.07 * m))
		var st := "warn" if float(W.vib[i]) > 0.05 else ("ok" if sp > 0.1 else "off")
		FastDraw.circle(ci, _p(Vector2(FW_C[i] - 1.25, 23.95)), 0.16 * m, lamp_col(st, t))
	for i in 2:
		var shake2 := Vector2(sin(t * 59.0), cos(t * 43.0)) * 0.05 * float(W.rp_vib[i])
		var at2 := Vector2(RP_C[i], 24.6) + shake2
		_put(ci, _rad_pump_mesh(), at2)
		var sp2 := float(W.rp[i])
		for k in 3:
			var a2 := t * 15.0 * sp2 + TAU * k / 3.0
			ci.draw_line(_p(at2), _p(at2) + Vector2.from_angle(a2) * 0.5 * m, _ink(0.75), maxf(1.0, 0.07 * m))
		var st2 := "warn" if float(W.rp_vib[i]) > 0.05 else ("ok" if sp2 > 0.1 else "off")
		FastDraw.circle(ci, _p(Vector2(RP_C[i], 20.5)), 0.15 * m, lamp_col(st2, t))


func _truck_mesh() -> ArrayMesh:
	return _mesh("truck", func(p):
		# the breaker's truck seen through the window: its body and the three pole contacts
		p.rect(Rect2(-0.55, 0.0, 1.1, 1.2), Color(0.18, 0.19, 0.2))
		p.rect(Rect2(-0.55, 0.0, 1.1, 1.2), Pal.ink(0.6), false, 0.04)
		for k in 3:
			p.rect(Rect2(-0.45 + k * 0.35, -0.35, 0.2, 0.35), Pal.ink(0.75)))


func _switch_moving(ci: CanvasItem, t: float) -> void:
	for i in W.FEEDERS.size():
		var k: String = W.FEEDERS[i]
		var x := SG_X + i * CUB
		var b := float(W.breaker.get(k, 0.0))
		# the truck rises into the contacts as it closes
		_put(ci, _truck_mesh(), Vector2(x + CUB * 0.5, SG_Y.x + 3.0 - 0.3 * b))
		var closed := b >= 0.99
		var lc := Pal.tint(Pal.FLUID, 0.95, 1.3) if closed else (Pal.heat(0.9, 1.3) if b > 0.0 else Pal.heat(0.4, 1.0))
		FastDraw.circle(ci, _p(Vector2(x + 0.35, SG_Y.x + 1.9)), 0.17 * m, lc)
		# the ammeter: full scale by the feeder's rating
		var mw := W.feeder_mw(k)
		var full: float = {"gen": maxf(6.0, W.cap), "shore": Grid.SHORE_MAX, "base": 4.0, "salvage": 30.0, "process": 30.0, "cargo": 6.0, "tug": 10.0}.get(k, 10.0)
		var a := lerpf(PI * 1.15, PI * 1.85, clampf(mw / full, 0.0, 1.0))
		var c := _p(Vector2(x + CUB * 0.5, SG_Y.x + 5.3))
		ci.draw_line(c, c + Vector2.from_angle(a) * 0.5 * m, Color(0.1, 0.1, 0.1), maxf(1.0, 0.05 * m))


# the main control screen: the plant in figures, the last changeovers
func _screen(ci: CanvasItem, t: float, stage: int) -> void:
	var x := SCREEN.position.x + 0.35
	var y := SCREEN.position.y + 0.8
	var dim := _ink(0.55)
	if stage < 1:
		_bt(ci, Vector2(x, y), w("反应堆停堆", "REACTORS DOWN"), 0.6, Color(1.0, 0.45, 0.35))
		_bt(ci, Vector2(x, y + 0.85), w("应急燃料电池供电", "ON THE FUEL CELLS"), 0.42, Pal.heat(0.85, 1.1))
		_bt(ci, Vector2(x, y + 1.85), "%.1f / 6 MW" % W.fc, 0.62, Pal.tint(Pal.VOLT, 0.95, 1.2))
		_bar(ci, Vector2(x, y + 2.25), SCREEN.size.x - 0.7, clampf(W.fc / 6.0, 0.0, 1.0))
		_bt(ci, Vector2(x, y + 3.3), w("修好动力区（第 1 期）：", "MEND THE POWER DISTRICT (STAGE 1):"), 0.34, _ink(0.8), HORIZONTAL_ALIGNMENT_LEFT, SCREEN.size.x - 0.6)
		_bt(ci, Vector2(x, y + 3.85), w("两座堆启动 → 30 MW", "TWO REACTORS → 30 MW"), 0.34, _ink(0.8))
		_bt(ci, Vector2(x, y + 4.4), w("各区有电，干活更快", "THE DISTRICTS RUN FASTER"), 0.34, _ink(0.8))
		_bt(ci, Vector2(x, y + 5.3), w("船坞终端 → 成长与建设", "BERTH TERMINAL → GROWTH"), 0.32, Color(UiSkin.ACCENT))
		_bt(ci, Vector2(x, y + 5.75), w("→ 零压港 → 动力区", "→ THE PORT → POWER"), 0.32, Color(UiSkin.ACCENT))
	else:
		_bt(ci, Vector2(x, y), w("运行中 · %d 套机组", "RUNNING · %d UNITS") % W.units, 0.5, Color(UiSkin.DATA))
		_bt(ci, Vector2(x, y + 1.0), "%.1f / %.0f MW" % [W.own, W.cap], 0.62, Pal.tint(Pal.VOLT, 0.95, 1.2))
		_bar(ci, Vector2(x, y + 1.4), SCREEN.size.x - 0.7, W.frac())
		_bt(ci, Vector2(x, y + 2.45), w("负荷 %d%% · %.2f Hz", "LOAD %d%% · %.2f Hz") % [int(round(W.frac() * 100.0)), W.hz], 0.36, _ink(0.85))
		var q := 0.0
		for i in 3:
			q += float(W.q_th[i])
		_bt(ci, Vector2(x, y + 3.05), w("堆热功率 %.0f MWt", "REACTOR HEAT %.0f MWt") % q, 0.34, Pal.heat(0.85, 1.1))
		_bt(ci, Vector2(x, y + 3.6), w("蒸汽 %.0f kg/s · 冷凝器 %.0f °C", "STEAM %.0f kg/s · COND %.0f °C") % [W.steam_kgs(), W.t_cond], 0.32, _ink(0.75))
		_bt(ci, Vector2(x, y + 4.1), w("散热板 %.0f °C · 排热 %.0f MW", "RADIATORS %.0f °C · %.0f MW OUT") % [W.rad_t, W.rejected()], 0.32, _ink(0.75))
		_bt(ci, Vector2(x, y + 4.65), w("电池 %.1f MW", "BATTERIES %.1f MW") % preload("res://scripts/power_supply.gd").batt_now if preload("res://scripts/power_supply.gd").batt_now > 0.05 else w("电池 未用", "BATTERIES IDLE"), 0.34, Pal.heat(0.85, 1.1) if W.shore > 0.05 else dim)
		_bt(ci, Vector2(x, y + 5.45), w("最近切换", "LAST CHANGEOVERS"), 0.3, dim)
		var ly := y + 5.95
		if W.log.is_empty():
			_bt(ci, Vector2(x, ly), w("无", "NONE"), 0.28, dim)
		for e in W.log:
			var ago := int((W.t - float(e[0])) / 60.0)
			_bt(ci, Vector2(x, ly), w("%d 分钟前 · %s", "%d MIN AGO · %s") % [ago, str(e[1])], 0.26, _ink(0.7), HORIZONTAL_ALIGNMENT_LEFT, SCREEN.size.x - 0.6)
			ly += 0.85


func _bar(ci: CanvasItem, at: Vector2, width: float, k: float) -> void:
	var rr := Rect2(_p(at), Vector2(width, 0.2) * m)
	ci.draw_rect(rr, _ink(0.07))
	ci.draw_rect(Rect2(rr.position, Vector2(rr.size.x * k, rr.size.y)), CA.bg(Pal.heat(0.9, 1.2) if k > 0.85 else Color(UiSkin.DATA)))


# the wall panel's words: smaller, and in the background instrument's dim cool grey (CA.bg)
func _bt(ci, at: Vector2, s: String, size_m: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	_text(ci, at, s, size_m * 0.72, CA.bg(col), align, width_m)


# ================================================================== the hover cards
func hover_items(stage: int) -> Array:
	var out: Array = []
	var add := func(rects: Array, title: String, use: String, now: Array, can: String) -> void:
		for rr in rects:
			out.append({"rect": Rect2(_p((rr as Rect2).position), (rr as Rect2).size * m), "title": title, "use": use, "now": str(now[0]), "can": can, "lamp": str(now[1])})
	var n := W.unit_count(stage)
	var grow := w("扩建动力区（船坞终端 → 成长与建设 → 零压港 → 动力区）。", "Build on the power district (berth terminal → growth → the port → power).")
	for i in 3:
		var bay := Rect2(BAY_X[i], 2.25, BAY_W, BAY_Y.y - 2.25)
		if i == 2 and stage < 2:
			add.call([bay], w("第 3 套机组机位", "UNIT 3 BAY"), w("留给第 3 套机组的屏蔽隔间：现在只有脚手架和盖板。", "The shielded bay kept for a third unit: scaffold and cover plates for now."),
				W.unit_state(i), w("动力区第 2 期装上第 3 套机组，容量从 30 MW 升到 80 MW。", "Power stage 2 fits the third unit: 30 MW becomes 80 MW."))
			continue
		add.call([bay], w("反应堆 %s", "REACTOR %s") % ["A", "B", "C"][i],
			w("压水堆：堆芯的热把一回路的水加热到三百多度（高压不沸腾），在蒸汽发生器里把二回路的水烧成蒸汽去推汽轮机。控制棒抽出越多，堆越热。稳压器保持压力，主泵让水循环。",
				"A pressurised-water reactor: the core heats the primary water past 300 °C (kept liquid by pressure); the steam generator boils the secondary water to drive the turbine. The further out the rods, the hotter the core. The pressuriser holds the pressure; the main pump circulates."),
			W.unit_state(i),
			(w("不用操作：棒位自动跟着全港用电走。", "Nothing to do: the rods follow the port's load by themselves.") if i < n else w("修好动力区（第 1 期）就会启动。", "Mending the power district (stage 1) starts it.")))
	add.call([Rect2(PLATES.turbine[0], Vector2(PLATES.turbine[1], 0.9)), Rect2(36.4, 2.9, 21.6, DECK.y - 2.9)], w("汽轮发电机", "TURBINE-GENERATOR"),
		w("蒸汽经主汽门、调节阀进高压缸、低压缸推动转子，带发电机发电。负荷一加上，转速和频率先往下掉，调节阀开大补上，几秒后回到 50 Hz。", "Steam through the stop and governor valves drives the HP and LP casings and the generator. A load put on drops the speed and frequency until the governor valve opens to match; in a few seconds it is back at 50 Hz."),
		W.turbine_state(), w("在业务终端的动力控制屏可以给电弧炉设功率上限、排%s时的先后顺序。" % Grid.short_label(0).get_slice("—", 0), "The power control screen at the business console sets the furnace's cap and who comes first when short."))
	add.call([COND], w("冷凝器", "CONDENSER"),
		w("把汽轮机排出的蒸汽冷成水，再由给水泵送回蒸汽发生器。它的热由散热回路带到外面的散热板排到太空。", "Turns the turbine's exhaust back into water for the feed pumps; its heat goes by the radiator loop to the radiators outside, out into space."),
		[w("%.0f °C" % W.t_cond, "%.0f °C" % W.t_cond), "ok" if W.units > 0 else "off"], w("不用操作。", "Nothing to do."))
	add.call([Rect2(PLATES.fc[0], Vector2(PLATES.fc[1], 0.9)), FC], w("应急燃料电池组", "EMERGENCY FUEL CELLS"),
		w("氢氧燃料电池，最多 6 MW：动力区没修好时全港靠它，修好后转为备用。", "Hydrogen-oxygen fuel cells, up to 6 MW: the port lives on them until the power district is mended, then they stand by."),
		W.fc_state(), grow if stage < 1 else w("不用操作。", "Nothing to do."))
	add.call([Rect2(PLATES.feed[0], Vector2(PLATES.feed[1], 0.9)), Rect2(10.0, 23.4, 10.4, 3.4)], w("给水泵 FW-1/2/3", "FEED PUMPS FW-1/2/3"),
		w("把冷凝器里的凝结水加压送回蒸汽发生器：两台运行一台备用，振动偏高时自动切换。", "Pump the condensate back into the steam generators: two run, one stands by, changed over automatically when one vibrates."),
		W.feed_state(), w("不用操作：切换是自动的，不影响供电。", "Nothing to do: the changeover is automatic and the supply carries on."))
	add.call([Rect2(PLATES.rad[0], Vector2(PLATES.rad[1], 0.9)), Rect2(54.4, 19.4, 5.2, 7.4)], w("散热泵 RP-1/2", "RADIATOR PUMPS RP-1/2"),
		w("推动散热回路：把冷凝器的热送到两侧吊臂上的散热板。太空里没有空气和水，热只能辐射出去。", "Drive the radiator loop: the condenser's heat out to the radiators on the booms. In vacuum heat can only be radiated away."),
		W.rad_state(), w("不用操作。站外看散热板越红，排的热越多。", "Nothing to do. Outside, the redder the radiators, the more heat goes out."))
	add.call([Rect2(PLATES.switch[0], Vector2(PLATES.switch[1], 0.9)), Rect2(SG_X, SG_Y.x, CUB * W.FEEDERS.size(), SG_Y.y - SG_Y.x)], w("配电柜", "SWITCHGEAR"),
		w("全港的电从这里分出去：发电机和电池泊位的电进来，再每区一条线送出去。哪个区开始用电，它的开关就合上（I），表针指着它现在用的电。", "Where the port's power is shared out: the units' incomer, the shore incomer, then a feeder for each district. A district starting to draw closes its breaker (I); its ammeter shows what it draws."),
		[w("全港在用 %.1f · 自家发 %.1f 兆瓦" % [W.own + W.shore, W.own], "BUS %.1f MW · OWN %.1f · SHORE %.1f" % [W.own + W.shore, W.own, W.shore]), "ok"],
		w("%s时谁先用：业务终端 → 动力控制屏里调顺序，发电机不够时到供电屏买电池块。" % Grid.short_label(0).get_slice("—", 0), "Who comes first when short: the business console's power control screen, where the supply line is chosen too."))
	add.call([Rect2(SCREEN.position - Vector2(0.25, 0.25), SCREEN.size + Vector2(0.5, 0.5))], w("主控屏", "MAIN CONTROL SCREEN"),
		w("整座电站的读数：输出 / 容量、频率、堆热功率、蒸汽、冷凝器、散热板、电池，以及最近几次自动切换。", "The plant in figures: out against capacity, frequency, reactor heat, steam, condenser, radiators, shore power, and the last automatic changeovers."),
		[w("%.1f / %.0f MW" % [W.own, W.cap], "%.1f / %.0f MW" % [W.own, W.cap]), "ok" if stage >= 1 else "warn"], w("详细控制在下面的业务终端（按 B 附近打开）。", "The controls are at the business console below."))
	return out
