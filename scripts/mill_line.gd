extends Node2D
# The rolling mill standing in the processing district (85 号, user 2026-10-26: "怎么碾钢板、碾型材
# ……学学戴森球"): a feed table, the stand with its two rolls and drive, a run-out table, and the
# operator's pedestal below. A pass is seen: the billet glows on the feed table while it comes,
# runs through the rolls at the speed the grid allows, and leaves as plate or a section onto the
# run-out, where the tonnes rolled this session stack up. Near it the drone sees a briefing over
# the stand (as a DSP building's hover card): its state, its reason, the pass. E at the pedestal
# opens its panel (scripts/mill_panel.gd). Only at the empty berth of a career.

const PortStructure = preload("res://scripts/port_structure.gd")
var game
var t := 0.0
var spin := 0.0
var art                          # 101 号: scripts/process_art.gd
const REACH := 3.5               # m: how close to the pedestal counts
const BRIEF := 10.0              # m: the briefing shows this close to the stand
# box-local metres (the processing district's top-left), the free floor right of the flue
const FEED := Rect2(43.4, 9.5, 3.8, 0.8)
const STAND := Rect2(47.5, 5.4, 2.6, 6.8)
const RUNOUT := Rect2(50.4, 9.5, 5.0, 0.8)
# the lower roll's top is the tables' top; the upper roll leaves the plate's thickness above it
const ROLL_Y := [8.53, 10.12]
const ROLL_R := 0.62
const PEDESTAL := Vector2(48.8, 14.6)


func active() -> bool:
	return game != null and game.in_berth() and game.career() and Career.usable()


static func _o() -> Vector2:
	return PortStructure.box("process").position


static func at(local: Vector2) -> Vector2:
	return _o() + local * PortStructure.M()


static func pedestal() -> Vector2:
	return at(PEDESTAL)


static func centre() -> Vector2:
	return at(STAND.get_center())


func near() -> bool:
	if not active() or game.drone == null or not game.drone.alive:
		return false
	return game.drone.global_position.distance_to(pedestal()) <= REACH * Geom.M


func _ready() -> void:
	z_index = 2
	z_as_relative = false


func _process(dt: float) -> void:
	t += dt
	visible = active()
	if not visible:
		return
	if Mill.progress() > 0.0:
		spin += dt * 6.0 * Mill.k(game)
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "process", 30.0):
		queue_redraw()


func _r(r: Rect2) -> Rect2:
	var m := PortStructure.M()
	return Rect2(_o() + r.position * m, r.size * m)


func _draw() -> void:
	if not active():
		return
	var m := PortStructure.M()
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var on := Port.stage("process") >= 1
	# 101 号: the tables' rollers, the four-high stand's rolls and the pass (scripts/process_art.gd);
	# the frames, housings and the reheating furnace stand in the district's still hall
	if art == null:
		art = preload("res://scripts/process_art.gd").new()
		art.font = Fonts.get_font("Medium")
	art.r = PortStructure.box("process")
	art.m = m
	art.mill(self, t, on, game)
	# what has come off this session: a stack at the run-out's end (one plate a tonne, up to six)
	var made := int(round(float(Mill.cfg().get("made", 0.0))))
	for i in mini(made, 6):
		var r2 := Rect2(RUNOUT.end.x - 3.2, RUNOUT.position.y - 0.28 * (i + 1), 2.9, 0.24)
		draw_rect(_r(r2), Color(0.32, 0.34, 0.37))
		draw_rect(_r(r2), Pal.ink(0.75), false, lw)
	# 106 号: a kept batch's billet carries its ship's name through the stand
	var mj := Mill.job()
	if str(mj.get("ship", "")) != "":
		var e := ProcessQueue.of_lot(str(mj.get("queue", "")))
		var label := Methods.ship_label(str(mj.ship)) + Ops.w(" · 轧钢板 %.0f/%.0f t", " · PLATE %.0f/%.0f t") % [float(e.get("rolled", 0.0)), floorf(float(e.get("billet1", 0.0)))]
		preload("res://scripts/industrial_heat.gd").ship_tag(self, at(Vector2(RUNOUT.get_center().x, RUNOUT.position.y - 0.3)), label, z)
	# 103 号: the pedestal is a console like every other (scripts/console_art.gd): the mill's state on
	# its screen, the name over it, the key's hint when close
	var pp := pedestal()
	var near_now := near()
	var lamp: Array = Mill.lamp(game)
	var floor_m := (PortStructure.box("process").end.y - 1.2 * m - pp.y) / m
	var info := {"lines": [[Ops.w("轧机", "MILL"), Pal.tint(Pal.AIR, 0.95, 1.2)], [str(lamp[1]), Pal.ink(0.75)]], "bar": -1.0,
		"lamp": {"run": "ok", "wait": "work", "short": "work", "idle": "idle", "off": "off"}.get(str(lamp[0]), "ok")}
	preload("res://scripts/console_art.gd").draw(self, pp, floor_m, Ops.w("轧机操作台", "MILL PEDESTAL"), Ops.w("[%s] 打开轧机", "[%s] OPEN THE MILL") % Keys.label("use"), near_now, info, t)
	var font := Fonts.get_font("Medium")
	_brief(z, font)


static func _lamp_col(s: String) -> Color:
	match s:
		"run": return Color("7be38f")
		"wait", "short": return Pal.heat(0.95, 1.4)
		"off": return Pal.ink(0.25)
	return Pal.tint(Pal.AIR, 0.8, 1.2)


# the hover card over the stand while the drone is near (screen-sized whatever the zoom)
func _brief(z: float, font: Font) -> void:
	if game.drone == null or game.drone.global_position.distance_to(centre()) > BRIEF * Geom.M:
		return
	var lamp: Array = Mill.lamp(game)
	var top := at(Vector2(STAND.get_center().x, STAND.position.y - 2.6))
	draw_set_transform(top, 0, Vector2.ONE / z)
	var wd := 300.0
	var box := Rect2(Vector2(-wd * 0.5, -78), Vector2(wd, 70))
	draw_rect(box, Color(0.06, 0.07, 0.08, 0.95))
	draw_rect(box, Pal.ink(0.35), false, 1.0)
	draw_circle(box.position + Vector2(16, 20), 6.0, _lamp_col(str(lamp[0])))
	draw_string(font, box.position + Vector2(30, 26), str(lamp[1]), HORIZONTAL_ALIGNMENT_LEFT, wd - 40, 15, Pal.ink(0.95))
	var bar := Rect2(box.position + Vector2(14, 40), Vector2(wd - 28, 8))
	draw_rect(bar, Pal.ink(0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * Mill.progress(), bar.size.y)), _lamp_col(str(lamp[0])))
	draw_string(font, box.position + Vector2(14, 64), Ops.w("钢坯 %.1f t · 配方：%s · %s", "BILLET %.1f t · %s · %s") % [Mill.feed_t(), Mill.product_name(str(Mill.cfg().product)), Ops.w("连续轧", "ROLLING ON") if bool(Mill.cfg().loop) else Ops.w("单次", "ONE PASS")], HORIZONTAL_ALIGNMENT_LEFT, wd - 28, 12, Pal.ink(0.65))
	draw_set_transform(Vector2.ZERO)
