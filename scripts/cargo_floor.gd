extends Node2D
# The cargo district's floor (85 号, user 2026-10-26: "怎么直接收东西？工程台里难道不应该有这么大一个
# 台子？我应该搬左边的箱。左边的这个柜台就显示左边柜台的东西，右边柜台显示右边柜台的东西"): the
# receiving counter left of the hatch, where clients' crates come up (scripts/depot.gd); the drone
# lifts one with E (it hangs under it on a line and swings as the drone moves), flies it to the
# lit mouth under its rack and sets it down with E. A mouth under each rack: E there with nothing
# hung opens that side's racks only (scripts/shelf_panel.gd). Clients' crates stand on their row.

const PortStructure = preload("res://scripts/port_structure.gd")
const ConsoleArt = preload("res://scripts/console_art.gd")
var game
var t := 0.0
var held: Array = []            # [lot id, crate index, tonnes, client, row] while one hangs
var swing := Vector2.ZERO       # m: where the hung crate is, under the drone
var swing_v := Vector2.ZERO
var _said := ""
var _said_t := 99.0
const REACH := 3.0              # m: a crate or a mouth this close is in reach
const LINE := 2.6               # m of line under the drone
# box-local metres (the cargo district's top-left)
const COUNTER := Rect2(18.5, 23.0, 9.4, 0.7)
const MOUTH := {"A": Vector2(11.0, 23.6), "B": Vector2(47.0, 23.6)}
const CRATE := Vector2(2.3, 1.8)


func active() -> bool:
	return game != null and game.in_berth() and game.career() and Career.usable()


static func _o() -> Vector2:
	return PortStructure.box("cargo").position


static func at(local: Vector2) -> Vector2:
	return _o() + local * PortStructure.M()


static func mouth(side: String) -> Vector2:
	return at(MOUTH[side])


static func side_of(row: int) -> String:
	return "A" if row < 4 else "B"


# a crate's place on the counter (its slot), box-local
static func slot(i: int) -> Vector2:
	return Vector2(COUNTER.position.x + 0.5 + (i % 3) * 3.0 + CRATE.x * 0.5, COUNTER.position.y - CRATE.y * 0.5 - (i / 3) * CRATE.y)


func _drone() -> Vector2:
	return game.drone.global_position if game.drone != null else Vector2.INF


func near_crate() -> int:
	var cs := Depot.dock_crates()
	var best := -1
	var bd := REACH * Geom.M
	for i in cs.size():
		if not held.is_empty() and str(cs[i][0]) == str(held[0]) and int(cs[i][1]) == int(held[1]):
			continue
		var d := _drone().distance_to(at(slot(i)))
		if d < bd:
			bd = d
			best = i
	return best


func near_mouth() -> String:
	for s in MOUTH:
		if _drone().distance_to(mouth(s)) <= REACH * Geom.M:
			return s
	return ""


func near_counter() -> bool:
	var r := Rect2(at(COUNTER.position), COUNTER.size * PortStructure.M()).grow(REACH * Geom.M)
	return r.has_point(_drone())


func _say(s: String) -> void:
	_said = s
	_said_t = 0.0
	if game.has_method("say_text"):
		game.say_text(s, _drone() + Vector2(0, -44))


# E in the district: lift a crate, set it down at its rack, or open a rack's side; true if taken
func use() -> bool:
	if not active() or game.drone == null or not game.drone.alive:
		return false
	if not held.is_empty():
		var want := side_of(int(held[4]))
		var m := near_mouth()
		if m == want:
			var r := Depot.put(str(held[0]), int(held[1]))
			held = []
			if r.ok:
				game.sfx.play("switch")
				_say(Ops.w("放上 %s 排了。", "SET ON ROW %s.") % Warehouse.ROWS[int(r.row)] + (Ops.w("这批全部上架，开始计租。", " ALL UP: THE RENT STARTS.") if int(r.left) == 0 else Ops.w("这批还有 %d 箱。", " %d MORE OF THIS LOT.") % int(r.left)))
			else:
				_say(str(r.reason))
			return true
		if m != "":
			_say(Ops.w("这箱要放 %s 排（%s货架）。", "THIS ONE GOES ON ROW %s (%s RACK).") % [Warehouse.ROWS[int(held[4])], Ops.w("左边", "LEFT") if want == "A" else Ops.w("右边", "RIGHT")])
			return true
		if near_counter():
			held = []
			game.sfx.play("switch")
			_say(Ops.w("放回收货台了。", "BACK ON THE COUNTER."))
			return true
		_say(Ops.w("飞到亮着的货架口再按 %s 放下。", "FLY TO THE LIT RACK MOUTH AND PRESS %s.") % Keys.label("use"))
		return true
	var c := near_crate()
	if c >= 0:
		held = Depot.dock_crates()[c]
		swing = Vector2(0, LINE)
		swing_v = Vector2.ZERO
		game.sfx.play("switch")
		_say(Ops.w("吊起来了：%.0f t，送到 %s 排（%s货架口）。", "LIFTED: %.0f t FOR ROW %s (%s RACK MOUTH).") % [float(held[2]), Warehouse.ROWS[int(held[4])], Ops.w("左边", "LEFT") if side_of(int(held[4])) == "A" else Ops.w("右边", "RIGHT")])
		return true
	var m2 := near_mouth()
	if m2 != "":
		# 128 号 (user 2026-11-04): the racks open the same stores page as the counter; the racks on
		# site only show what is on them
		if StoreBook.live():
			game.open_counter()
		else:
			game.open_shelf(m2)
		return true
	return false


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func _process(dt: float) -> void:
	t += dt
	_said_t += dt
	visible = active()
	if not visible:
		held = []
		return
	# the hung crate swings: a pendulum on the line, pushed by the drone's own motion
	if not held.is_empty() and game.drone != null:
		var v: Vector2 = game.drone.linear_velocity / Geom.M
		var target := Vector2(-v.x * 0.12, LINE)
		swing_v += ((target - swing) * 9.0 - swing_v * 2.2) * dt
		swing += swing_v * dt
		swing = swing.limit_length(LINE * 1.2)
		# the lot was taken off by the forklift option or is gone: let go
		if Depot.lot(str(held[0])).is_empty():
			held = []
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "cargo", 30.0):
		queue_redraw()


func _draw() -> void:
	if not active():
		return
	var m := PortStructure.M()
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var font := Fonts.get_font("Medium")
	var edge := Pal.ink(0.75)
	# 105 号: the receiving counter is a weighing table — the deck on four load cells over a braced
	# frame, hazard edges, the scale's read-out on the front apron (no higher than it was: the
	# forklifts' plates and bays are above and beside it)
	var crates := Depot.dock_crates()
	var top := Rect2(at(COUNTER.position), COUNTER.size * m)
	var frame_y := COUNTER.end.y + 0.32
	draw_rect(top, Color(0.1, 0.105, 0.115))
	for k in int(COUNTER.size.x / 0.6):
		draw_line(at(Vector2(COUNTER.position.x + 0.3 + k * 0.6, COUNTER.position.y + 0.12)), at(Vector2(COUNTER.position.x + 0.5 + k * 0.6, COUNTER.position.y + 0.32)), Pal.ink(0.22), lw)
	for ex in [COUNTER.position.x, COUNTER.end.x - 0.45]:
		var hz := Rect2(at(Vector2(ex, COUNTER.position.y)), Vector2(0.45, COUNTER.size.y) * m)
		draw_rect(hz, Pal.heat(0.55, 1.0))
		draw_line(hz.position + Vector2(0.1, hz.size.y) * Vector2(m, 1.0), hz.position + Vector2(0.35 * m, 0.0), Color(0.05, 0.05, 0.05), 2.0 * lw)
	draw_rect(top, edge, false, 2.0 * lw)
	# the load cells under the deck, the frame, its legs and braces
	for cx in [COUNTER.position.x + 0.9, COUNTER.position.x + 3.6, COUNTER.end.x - 3.6, COUNTER.end.x - 0.9]:
		draw_rect(Rect2(at(Vector2(cx - 0.25, COUNTER.end.y)), Vector2(0.5, 0.32) * m), Color(0.16, 0.17, 0.18))
		draw_rect(Rect2(at(Vector2(cx - 0.25, COUNTER.end.y)), Vector2(0.5, 0.32) * m), Pal.ink(0.5), false, lw)
	draw_rect(Rect2(at(Vector2(COUNTER.position.x + 0.2, frame_y)), Vector2(COUNTER.size.x - 0.4, 0.3) * m), Color(0.08, 0.085, 0.095))
	draw_rect(Rect2(at(Vector2(COUNTER.position.x + 0.2, frame_y)), Vector2(COUNTER.size.x - 0.4, 0.3) * m), Pal.ink(0.55), false, lw)
	var legs := [COUNTER.position.x + 0.5, COUNTER.position.x + 1.3, COUNTER.end.x - 1.3, COUNTER.end.x - 0.5]
	for lx in legs:
		draw_line(at(Vector2(lx, frame_y + 0.3)), at(Vector2(lx, COUNTER.end.y + 2.6)), Pal.ink(0.5), 3.0 * lw)
		draw_rect(Rect2(at(Vector2(lx - 0.25, COUNTER.end.y + 2.5)), Vector2(0.5, 0.12) * m), Pal.ink(0.45))
	for pair in [[legs[0], legs[1]], [legs[2], legs[3]]]:
		draw_line(at(Vector2(pair[0], frame_y + 0.4)), at(Vector2(pair[1], COUNTER.end.y + 2.4)), Pal.ink(0.3), lw)
		draw_line(at(Vector2(pair[1], frame_y + 0.4)), at(Vector2(pair[0], COUNTER.end.y + 2.4)), Pal.ink(0.3), lw)
	# the scale's read-out on the apron: the tonnes on the deck, a lamp
	var tons := 0.0
	for c in crates:
		tons += float(c[2])
	var ro := Rect2(at(Vector2(COUNTER.position.x + 2.0, frame_y + 0.45)), Vector2(2.4, 0.75) * m)
	draw_rect(ro, Color(0.02, 0.025, 0.03))
	draw_rect(ro, Pal.ink(0.6), false, lw)
	draw_circle(ro.position + Vector2(ro.size.x - 0.18 * m, 0.18 * m), 0.08 * m, Pal.heat(0.9, 1.3) if not crates.is_empty() else Pal.tint(Pal.FLUID, 0.9, 1.2))
	if m * z >= 9.0:
		draw_set_transform(ro.position + Vector2(0.15, 0.55) * m, 0, Vector2.ONE / z)
		draw_string(font, Vector2.ZERO, "%.2f t" % tons, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(7, int(0.4 * m * z)), Pal.tint(Pal.FLUID, 0.95, 1.3))
		draw_set_transform(Vector2.ZERO)
	for i in crates.size():
		var c: Array = crates[i]
		if not held.is_empty() and str(c[0]) == str(held[0]) and int(c[1]) == int(held[1]):
			continue
		_crate(at(slot(i)), c, lw, z, font, near_crate() == i and held.is_empty())
	# the rack mouths: a floor plate under each rack
	var want := side_of(int(held[4])) if not held.is_empty() else ""
	var nm := near_mouth()
	for s in MOUTH:
		var p := mouth(s)
		var lit: bool = s == want
		var col := Pal.heat(0.95, 1.5) if lit else Pal.tint(Pal.AIR, 1.0 if nm == s else 0.6, 1.3)
		# 105 号: a portal: the floor plate with its arrows, two hazard-striped posts, the lamp head over it
		var pr := Rect2(p - Vector2(1.6, 0.35) * m, Vector2(3.2, 0.7) * m)
		draw_rect(pr, Color(0.03, 0.04, 0.05, 0.95))
		draw_rect(pr, col, false, 1.6 * lw)
		for ax in [-0.7, 0.0, 0.7]:
			var ac := p + Vector2(ax, 0.0) * m
			draw_line(ac + Vector2(-0.2, 0.15) * m, ac + Vector2(0.0, -0.15) * m, Color(col, 0.7), 1.5 * lw)
			draw_line(ac + Vector2(0.2, 0.15) * m, ac + Vector2(0.0, -0.15) * m, Color(col, 0.7), 1.5 * lw)
		for px in [-1.75, 1.55]:
			var post := Rect2(p + Vector2(px, -2.4) * m, Vector2(0.2, 2.05) * m)
			draw_rect(post, Color(0.1, 0.105, 0.115))
			var hy := post.position.y
			while hy < post.end.y - 0.2 * m:
				draw_line(Vector2(post.position.x, hy + 0.2 * m), Vector2(post.end.x, hy), Pal.heat(0.6, 1.0), 2.0 * lw)
				hy += 0.4 * m
			draw_rect(post, Pal.ink(0.55), false, lw)
		draw_rect(Rect2(p + Vector2(-1.75, -2.6) * m, Vector2(3.5, 0.22) * m), Color(0.1, 0.105, 0.115))
		draw_rect(Rect2(p + Vector2(-1.75, -2.6) * m, Vector2(3.5, 0.22) * m), Pal.ink(0.55), false, lw)
		draw_circle(p + Vector2(0.0, -2.45) * m, 0.14 * m, col)
		if lit:
			draw_arc(p, (1.8 + 0.25 * sin(t * 5.0)) * m, 0.0, TAU, 40, col, 2.0 * lw, true)
			# the row it goes on, outlined on the rack
			var ra: Vector2 = Warehouse.ROW_AT[int(held[4])]
			draw_rect(Rect2(at(Vector2(ra.x, ra.y - 2.8)), Vector2(10.0, 2.8) * m), Color(col, 0.6 + 0.3 * sin(t * 5.0)), false, 2.0 * lw)
		var hint := ""
		if nm == s:
			hint = Ops.w("[%s] 放下", "[%s] SET IT DOWN") if lit else (((Ops.w("[%s] 打开仓库", "[%s] OPEN THE STORES") if StoreBook.live() else Ops.w("[%s] 打开这一边的货架", "[%s] OPEN THIS SIDE'S RACKS"))) if held.is_empty() else Ops.w("这箱不放这边", "NOT THIS SIDE"))
			hint = hint.replace("%s", Keys.label("use")) if hint.contains("%s") else hint
		var plate := Ops.w("仓库货架", "STORES RACKS") if StoreBook.live() else Ops.w("货架口 %s（%s）", "RACK MOUTH %s (%s)") % [s, Ops.w("左边 A1–A4", "LEFT A1–A4") if s == "A" else Ops.w("右边 B1–B4", "RIGHT B1–B4")]
		ConsoleArt._name_plate(self, p + Vector2(0.0, -2.7) * m, plate, hint,
			"work" if lit else "ok", nm == s or lit, t, z)
	# clients' crates on their rows
	for row in Warehouse.ROWS.size():
		var list := Depot.row_crates(row)
		var ra: Vector2 = Warehouse.ROW_AT[row]
		for k in mini(list.size(), 3):
			var r := Rect2(at(Vector2(ra.x + 9.6 - (k + 1) * 2.0, ra.y - 1.5)), Vector2(1.8, 1.4) * m)
			draw_rect(r, Color(0.16, 0.13, 0.08))
			draw_rect(r, Pal.heat(0.6, 1.0), false, lw)
	# the counter's name
	# the counter's plate under its deck (the forklifts' plates are over it)
	var ctitle := Ops.w("收货台 · %d 箱" % crates.size(), "RECEIVING COUNTER · %d CRATES" % crates.size()) if not crates.is_empty() else Ops.w("收货台 · 没有货箱（在业务终端接寄存单）", "RECEIVING COUNTER · NO CRATES (TAKE STORAGE AT THE CONSOLE)")
	var chint := Ops.w("[%s] 吊起这箱", "[%s] LIFT THIS CRATE") % Keys.label("use") if held.is_empty() and near_crate() >= 0 else ""
	ConsoleArt._name_plate(self, at(Vector2(COUNTER.position.x + 7.0, COUNTER.end.y + 2.45)), ctitle, chint, "work" if not crates.is_empty() else "ok", near_counter(), t, z)
	# the hung one: the line from the drone, the crate swinging on it
	if not held.is_empty() and game.drone != null:
		var d := _drone()
		var cp := d + swing * Geom.M
		draw_line(d, cp, Pal.ink(0.8), 1.5 * lw)
		_crate(cp + Vector2(0, CRATE.y * 0.5 * m), held, lw, z, font, true)


func _crate(c: Vector2, info: Array, lw: float, z: float, font: Font, lit: bool) -> void:
	var m := PortStructure.M()
	var r := Rect2(c - CRATE * 0.5 * m, CRATE * m)
	draw_rect(r, Color(0.2, 0.16, 0.1))
	draw_rect(r, Pal.heat(0.95 if lit else 0.6, 1.3), false, (2.0 if lit else 1.2) * lw)
	draw_line(r.position, r.end, Pal.heat(0.4, 1.0), lw)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Pal.heat(0.4, 1.0), lw)
	if z >= 0.25 or lit:
		draw_set_transform(c, 0, Vector2.ONE / z)
		draw_string(font, Vector2(-40, -4), "%s" % str(info[3]), HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Pal.ink(0.9))
		draw_string(font, Vector2(-40, 10), "%.0f t · %s" % [float(info[2]), Warehouse.ROWS[int(info[4])]], HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Pal.ink(0.7))
		draw_set_transform(Vector2.ZERO)
