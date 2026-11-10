extends Node2D
# The cargo district's floor (85 号, user 2026-10-26: "左边的这个柜台就显示左边柜台的东西，右边柜台显示右边
# 柜台的东西"): a mouth under each rack: E there opens the stores (scripts/shelf_panel.gd before 128 号).
# 128 号 第 6 段 (user 2026-11-07): the third-party storage is gone, and with it the receiving
# counter and the clients' crates the drone carried from it.

const PortStructure = preload("res://scripts/port_structure.gd")
const ConsoleArt = preload("res://scripts/console_art.gd")
var game
var t := 0.0
const REACH := 3.0              # m: a mouth this close is in reach
# box-local metres (the cargo district's top-left)
const MOUTH := {"A": Vector2(11.0, 23.6), "B": Vector2(47.0, 23.6)}


func active() -> bool:
	return game != null and game.in_berth() and game.career() and Career.usable()


static func _o() -> Vector2:
	return PortStructure.box("cargo").position


static func at(local: Vector2) -> Vector2:
	return _o() + local * PortStructure.M()


static func mouth(side: String) -> Vector2:
	return at(MOUTH[side])


func _drone() -> Vector2:
	return game.drone.global_position if game.drone != null else Vector2.INF


func near_mouth() -> String:
	for s in MOUTH:
		if _drone().distance_to(mouth(s)) <= REACH * Geom.M:
			return s
	return ""


# E at a rack's mouth opens the stores; true if taken
func use() -> bool:
	if not active() or game.drone == null or not game.drone.alive:
		return false
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
	visible = active()
	if not visible:
		return
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "cargo", 30.0):
		queue_redraw()


func _draw() -> void:
	if not active():
		return
	var m := PortStructure.M()
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	# the rack mouths: a floor plate under each rack
	var nm := near_mouth()
	for s in MOUTH:
		var p := mouth(s)
		var col := Pal.tint(Pal.AIR, 1.0 if nm == s else 0.6, 1.3)
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
		var hint := ""
		if nm == s:
			hint = Ops.w("[%s] 打开仓库", "[%s] OPEN THE STORES") if StoreBook.live() else Ops.w("[%s] 打开这一边的货架", "[%s] OPEN THIS SIDE'S RACKS")
			hint = hint.replace("%s", Keys.label("use")) if hint.contains("%s") else hint
		var plate := Ops.w("仓库货架", "STORES RACKS") if StoreBook.live() else Ops.w("货架口 %s（%s）", "RACK MOUTH %s (%s)") % [s, Ops.w("左边 A1–A4", "LEFT A1–A4") if s == "A" else Ops.w("右边 B1–B4", "RIGHT B1–B4")]
		# the plate only while the drone is at this mouth (user 2026-11-10: every console's plate)
		if nm == s:
			ConsoleArt._name_plate(self, p + Vector2(0.0, -2.7) * m, plate, hint, "ok", true, t, z)
