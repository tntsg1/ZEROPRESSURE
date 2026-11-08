extends Node2D
# 128 号 第 4 段 (user 2026-11-07, 方案 A 改 — tests/out/seg4_layouts/layout_A2.png): the processing
# district's observation gallery. A raised walkway runs the hall's whole length; over it the corridor is
# left empty, so the drone comes in at the shuttle's stop, rises past the gallery's right end and flies the
# hall end to end without touching anything. The machines' terminals are low consoles on the walkway's
# front railing, each straight over its machine (the arc furnace, casting and the mould change, the baler,
# the mill, the district's business terminal), under the flight line. Under the walkway's edge a band of
# slanted glass shuts the machine floor off; the machines work below it and the hall crane runs on its
# runway under the gallery. The freight spur's stop on the right is the arrival lane: glass on its left,
# the spur's deck under it. The walkway, the gallery's right end, the glass under it and the lane's glass
# and deck are solid to the drone (PortStructure, layer LAYER) and to nothing else (the trains and the
# freight trolley run on). Dark while the district is not mended; its lamps light from the door along
# the walkway when it is (scripts/district_revive.gd, the "process" plan). Box-local metres (60 × 28).

const X0 := 0.6            # the walkway's left end, at the hall's wall
const X1 := 57.0           # its right end: past it the drone rises from the arrival lane
const CEIL := 1.9          # the corridor's top (under the roof's lamps)
const DECK := 7.4          # the walkway's top: the floor the consoles stand on
const DECK_B := 7.8        # its underside
const GLASS_B := 8.9       # the slanted glass's bottom edge
const FLOOR := DECK        # (the consoles' floor, scripts/console_art.gd)
const FLY_Y := 3.2         # the flight line, half way between the roof lamps and the consoles' tops
const LANE_X := 36.8       # the arrival lane's glass on its left
const LANE_FLOOR := 15.8   # the freight spur's deck under the lane
const LAYER := 16          # solid to the drone only (drone.gd collision_mask)
const HEAD := 1.2          # a console's spot (its screen's foot) over the walkway
# the consoles along the railing, each over its machine: [id, x]
const TERMS := [["furnace", 15.0], ["cast", 22.4], ["press", 34.1], ["mill", 50.6], ["business", 56.0]]
const ConsoleArt = preload("res://scripts/console_art.gd")
const REACH := 3.2         # m: how close counts for the casting and baler consoles (the others keep theirs)
static var ON := true      # the old layout's tests switch it off (desks where they were)

var game
var t := 0.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func on() -> bool:
	return ON and not ProcessLine.LEGACY_DESKS


static func at(local: Vector2) -> Vector2:
	return PortStructure.box("process").position + local * PortStructure.M()


# a console's spot, world px (the screen stands over it, the walkway HEAD below)
static func term(id: String) -> Vector2:
	for tr in TERMS:
		if str(tr[0]) == id:
			return at(Vector2(float(tr[1]), DECK - HEAD))
	return Vector2.INF


# metres from a console's spot down to the walkway
static func foot() -> float:
	return HEAD


# on the walkway (world px)?
static func inside(p: Vector2) -> bool:
	var l := (p - PortStructure.box("process").position) / PortStructure.M()
	return l.x > X0 - 0.2 and l.x < X1 + 0.5 and l.y > CEIL - 0.5 and l.y < DECK + 0.3


# the solid edges, world px: [a, b] pairs — the walkway's top and its right end, the glass's bottom over
# the lane, the lane's glass and the spur's deck
static func edges() -> Array:
	return [[at(Vector2(X0, DECK)), at(Vector2(X1, DECK))], [at(Vector2(X1, DECK)), at(Vector2(X1, GLASS_B))],
		[at(Vector2(LANE_X, GLASS_B)), at(Vector2(X1, GLASS_B))], [at(Vector2(LANE_X, GLASS_B)), at(Vector2(LANE_X, LANE_FLOOR))],
		[at(Vector2(LANE_X, LANE_FLOOR)), at(Vector2(60.0, LANE_FLOOR))]]


# E at the casting or the baler console: what it is doing, said where the drone is (the queue itself opens
# only at the furnace console and from the stores' note — 2026-11-07)
func use(id: String) -> void:
	var s := ""
	if id == "cast":
		var rack: Array = []
		for k in ProcessLine.casting().get("rack", []):
			if str(k) != "":
				rack.append(ProcessLine.mould_name(str(k)))
		s = (w("换模中：还要 %d 秒", "CHANGING THE MOULD: %d s MORE") % int(ceil(ProcessLine.change_left()))) if ProcessLine.changing() else w("座上：%s模 · 架上：%s", "IN THE SEAT: %s · ON THE RACK: %s") % [ProcessLine.mould_name(ProcessLine.line_mould()), "、".join(rack) if not rack.is_empty() else w("空", "none")]
		s += w(" · 排产、换模在炉体控制台的加工队列里", " · ORDER AND MOULDS: THE QUEUE AT THE FURNACE CONSOLE")
	else:
		var ph: Array = ProcessLine.press_phase()
		var waiting: int = ProcessLine.press().get("jobs", []).size()
		s = (w("压块机空闲", "THE BALER IS IDLE") if str(ph[0]) == "idle" else w("压块机：%s · %d%%", "BALER: %s · %d%%") % [_press_line(ph), int(float(ph[1]) * 100.0)]) + (w(" · 还有 %d 件在等", " · %d WAITING") % waiting if waiting > 0 else "")
		s += w(" · 要压什么：在仓库里选中物品点“压块”", " · TO PRESS: SELECT IT IN THE STORES, 'BALE'")
	game.say_text(s, game.drone.global_position)
	game.sfx.play("switch")


# the console of its own the drone is at ("cast", "press"; "" none)
func near() -> String:
	if not on() or game == null or game.drone == null or not game.in_berth():
		return ""
	for id in ["cast", "press"]:
		if game.drone.global_position.distance_to(term(id)) <= REACH * Geom.M:
			return id
	return ""


func _ready() -> void:
	# over the district's machines (their front layer is 3): the crane's carriage runs behind the glass
	z_index = 4
	z_as_relative = false


func _process(dt: float) -> void:
	t += dt
	visible = on() and game != null and game.in_berth() and game.career()
	if visible and ViewCull.sees_zone(game, "process", 10.0):
		queue_redraw()


# how far the lighting-up has come along the walkway from the door (0 … 1; 1 mended)
func _lit_k() -> float:
	var held := preload("res://scripts/district_revive.gd").held("process")
	if held >= 0.0:
		return held
	return 1.0 if Port.stage("process") >= 1 else 0.0


func _draw() -> void:
	var m := PortStructure.M()
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var lit := _lit_k()
	var P := func(v: Vector2) -> Vector2: return at(v)
	var steel := Color(0.12, 0.126, 0.138)
	var steel2 := Color(0.155, 0.162, 0.176)
	var dark := Color(0.05, 0.054, 0.062)
	var edge := Pal.ink(0.62)
	# ---- the slanted glass under the walkway's edge: a frame every 3 m, each pane with its glints, the sill
	var gr := Rect2(P.call(Vector2(X0, DECK_B)), Vector2(X1 - X0, GLASS_B - DECK_B) * m)
	draw_rect(gr, Color(0.42, 0.62, 0.74, 0.07))
	# the top of each pane leans out (darker), the foot lighter: it reads as slanting away
	draw_rect(Rect2(gr.position, Vector2(gr.size.x, gr.size.y * 0.35)), Color(0.0, 0.0, 0.0, 0.18))
	var fx := X0
	while fx < X1 - 0.01:
		var nx := minf(fx + 3.0, X1)
		draw_line(P.call(Vector2(fx, DECK_B)), P.call(Vector2(fx, GLASS_B)), steel2, maxf(1.0, 0.12 * m))
		draw_line(P.call(Vector2(fx, DECK_B)), P.call(Vector2(fx, GLASS_B)), Pal.ink(0.35), lw)
		for k in 2:
			var gx := fx + 0.6 + k * 1.3
			draw_line(P.call(Vector2(gx, DECK_B + 0.15)), P.call(Vector2(gx + 0.45, GLASS_B - 0.15)), Color(0.8, 0.9, 1.0, 0.16), maxf(1.0, 0.05 * m))
		fx = nx
	draw_line(P.call(Vector2(X1, DECK_B)), P.call(Vector2(X1, GLASS_B)), Pal.ink(0.5), maxf(1.0, 0.12 * m))
	draw_rect(Rect2(P.call(Vector2(X0, GLASS_B - 0.1)), Vector2(X1 - X0, 0.16) * m), steel2)
	draw_line(P.call(Vector2(X0, GLASS_B + 0.06)), P.call(Vector2(X1, GLASS_B + 0.06)), edge, lw)
	# ---- the walkway: a grating on its stringer, the toe board and the floor lamps
	draw_rect(Rect2(P.call(Vector2(X0, DECK)), Vector2(X1 - X0, DECK_B - DECK) * m), steel)
	var gx2 := X0 + 0.15
	while gx2 < X1:
		draw_line(P.call(Vector2(gx2, DECK + 0.06)), P.call(Vector2(gx2, DECK + 0.2)), Pal.ink(0.2), lw)
		gx2 += 0.25
	draw_line(P.call(Vector2(X0, DECK + 0.24)), P.call(Vector2(X1, DECK + 0.24)), Pal.ink(0.3), lw)
	draw_line(P.call(Vector2(X0, DECK)), P.call(Vector2(X1, DECK)), edge, 1.4 * lw)
	draw_line(P.call(Vector2(X0, DECK_B)), P.call(Vector2(X1, DECK_B)), Pal.ink(0.4), lw)
	# the stringer's bolts and the hangers' plates every 3 m
	if z * m >= 10.0:
		var bx := X0 + 1.5
		while bx < X1:
			draw_circle(P.call(Vector2(bx - 0.3, DECK + 0.32)), 0.04 * m, Pal.ink(0.5))
			draw_circle(P.call(Vector2(bx + 0.3, DECK + 0.32)), 0.04 * m, Pal.ink(0.5))
			bx += 3.0
	# ---- the railing on the walkway's front edge: top rail, knee rail, posts, toe board
	var rail_y := DECK - 1.05
	draw_rect(Rect2(P.call(Vector2(X0, DECK - 0.14)), Vector2(X1 - X0, 0.14) * m), steel2)
	draw_line(P.call(Vector2(X0, rail_y)), P.call(Vector2(X1, rail_y)), Pal.ink(0.55), maxf(1.0, 0.07 * m))
	draw_line(P.call(Vector2(X0, DECK - 0.55)), P.call(Vector2(X1, DECK - 0.55)), Pal.ink(0.3), maxf(1.0, 0.04 * m))
	var px := X0 + 0.1
	while px < X1 + 0.01:
		draw_line(P.call(Vector2(px, rail_y)), P.call(Vector2(px, DECK - 0.14)), Pal.ink(0.42), maxf(1.0, 0.06 * m))
		px += 1.5
	# the walkway's right end: an end post, the rail turning down, a yellow-black edge where it stops
	draw_line(P.call(Vector2(X1, rail_y)), P.call(Vector2(X1, DECK_B)), Pal.ink(0.6), maxf(1.0, 0.08 * m))
	for k in 4:
		var hy := DECK + 0.05 + k * 0.18
		draw_line(P.call(Vector2(X1 - 0.02, hy)), P.call(Vector2(X1 - 0.02, hy + 0.09)), Pal.heat(0.6, 0.9), maxf(1.0, 0.1 * m))
	# the floor lamps: a strip in the toe board every 3 m, lit from the door inwards; their light on the grating
	var lx := X1 - 1.5
	while lx > X0:
		var on_k := clampf((lit * (X1 - X0 + 6.0) - (X1 - lx)) / 3.0, 0.0, 1.0)
		var lamp := Rect2(P.call(Vector2(lx - 0.45, DECK - 0.1)), Vector2(0.9, 0.06) * m)
		draw_rect(lamp, Color(0.9, 0.96, 1.0, 0.95).lerp(Pal.ink(0.16), 1.0 - on_k))
		if on_k > 0.01:
			draw_polygon(PackedVector2Array([lamp.position, lamp.position + Vector2(lamp.size.x, 0.0), lamp.position + Vector2(lamp.size.x + 0.5 * m, -1.3 * m), lamp.position + Vector2(-0.5 * m, -1.3 * m)]),
				PackedColorArray([Color(0.85, 0.92, 1.0, 0.07 * on_k), Color(0.85, 0.92, 1.0, 0.07 * on_k), Color(0.85, 0.92, 1.0, 0.0), Color(0.85, 0.92, 1.0, 0.0)]))
		lx -= 3.0
	# where each console stands: a pad on the grating, lit while the district is
	for tr in TERMS:
		var tx := float(tr[1])
		draw_rect(Rect2(P.call(Vector2(tx - 0.8, DECK - 0.04)), Vector2(1.6, 0.04) * m), Color(UiSkin.ACCENT, 0.15 + 0.4 * lit))
	# ---- the arrival lane: the glass on its left, the spur's deck girder under it
	var lane := Rect2(P.call(Vector2(LANE_X - 0.12, GLASS_B)), Vector2(0.12, LANE_FLOOR - GLASS_B) * m)
	draw_rect(lane, Color(0.42, 0.62, 0.74, 0.1))
	draw_line(P.call(Vector2(LANE_X, GLASS_B)), P.call(Vector2(LANE_X, LANE_FLOOR)), Pal.ink(0.55), maxf(1.0, 0.06 * m))
	var my := GLASS_B + 1.6
	while my < LANE_FLOOR - 0.5:
		draw_line(P.call(Vector2(LANE_X - 0.25, my)), P.call(Vector2(LANE_X + 0.05, my)), Pal.ink(0.4), maxf(1.0, 0.05 * m))
		my += 2.0
	draw_line(P.call(Vector2(LANE_X - 0.06, GLASS_B + 0.6)), P.call(Vector2(LANE_X - 0.06, GLASS_B + 2.2)), Color(1, 1, 1, 0.16), lw)
	draw_rect(Rect2(P.call(Vector2(LANE_X, LANE_FLOOR)), Vector2(60.0 - LANE_X, 0.45) * m), steel)
	draw_line(P.call(Vector2(LANE_X, LANE_FLOOR)), P.call(Vector2(60.0, LANE_FLOOR)), edge, 1.4 * lw)
	draw_line(P.call(Vector2(LANE_X, LANE_FLOOR + 0.45)), P.call(Vector2(60.0, LANE_FLOOR + 0.45)), Pal.ink(0.35), lw)
	var sx := LANE_X + 0.6
	while sx < 59.6:
		draw_line(P.call(Vector2(sx, LANE_FLOOR + 0.05)), P.call(Vector2(sx + 0.45, LANE_FLOOR + 0.4)), Pal.ink(0.16), lw)
		sx += 0.9
	# ---- the casting and the baler consoles (the furnace's, the mill's and the business console are
	# drawn by their services, all of them railing consoles here — scripts/console_art.gd)
	var info_c := {"lines": [[w("浇铸 · 换模", "CASTING"), Pal.tint(Pal.AIR, 0.95, 1.2)], [_cast_line(), Pal.ink(0.75)]], "bar": -1.0, "lamp": "work" if ProcessLine.changing() else "ok"}
	ConsoleArt.draw(self, term("cast"), foot(), w("浇铸 · 换模终端", "CASTING TERMINAL"), w("[%s] 看状态", "[%s] STATUS") % Keys.label("use"), near() == "cast", info_c, t)
	var ph: Array = ProcessLine.press_phase()
	var info_p := {"lines": [[w("打包压块机", "BALER"), Pal.tint(Pal.AIR, 0.95, 1.2)], [_press_line(ph), Pal.ink(0.75)]], "bar": -1.0, "lamp": "idle" if str(ph[0]) == "idle" else ("warn" if str(ph[0]) in ["probe", "reject"] else "work")}
	ConsoleArt.draw(self, term("press"), foot(), w("压块机终端", "BALER TERMINAL"), w("[%s] 看状态", "[%s] STATUS") % Keys.label("use"), near() == "press", info_p, t)


func _cast_line() -> String:
	if ProcessLine.changing():
		return w("换模 %d s", "CHANGING %d s") % int(ceil(ProcessLine.change_left()))
	return w("%s模", "%s MOULD") % ProcessLine.mould_name(ProcessLine.line_mould())


func _press_line(ph: Array) -> String:
	match str(ph[0]):
		"idle": return w("空闲", "IDLE")
		"probe", "reject": return w("拒收", "REJECTED")
		"press": return w("压制中", "PRESSING")
	return w("工作中", "WORKING")
