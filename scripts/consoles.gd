class_name Consoles
extends Node2D
# The berth's two computers (the user, 2026-10-17): mounted on the tower wall at
# the berth's near end, one for the equipment shop and one for berth management.
# Fly the drone up to one and press the use key: the terminal's page opens over
# the berth (play stops while it is open, Esc closes it). What is bought there
# counts from the next contract. Only on a career's contracts.

# one computer now (player 2026-10-18: "two computers opening the same thing is
# odd"): the berth terminal, the same device the terminal key opens anywhere
const SPOTS := [["terminal", Vector2(-6.2, -2.4)]]   # m: the screen's top-left
const SIZE := Vector2(1.3, 1.5)    # m
const REACH := 2.6                 # m from the screen's centre
# 86 号 Q11: the parts rack under the terminal (E opens scripts/parts_rack_panel.gd); once the cargo
# district is mended the parts live on its racks instead and this one is gone
const RACK := Vector2(-6.4, 0.3)   # m: the rack's top-left
const RACK_SIZE := Vector2(1.6, 1.6)


static func rack_on() -> bool:
	# 128 号: the rack is the warehouse counter now, there from the start, whatever is mended
	if StoreBook.ON:
		return Career.usable() and not Career.data.is_empty()
	return Career.usable() and not Career.data.is_empty() and Port.stage("cargo") < 1


static func rack_centre() -> Vector2:
	return (RACK + RACK_SIZE * 0.5) * Geom.M

const ConsoleArt = preload("res://scripts/console_art.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")

var game: Game
var t := 0.0


func _init() -> void:
	z_index = 2
	z_as_relative = false


static func centre(i: int) -> Vector2:
	return (SPOTS[i][1] + SIZE * 0.5) * Geom.M


# which console the drone is at ("" for none)
func near() -> String:
	if game == null or game.drone == null or not game.drone.alive:
		return ""
	for i in SPOTS.size():
		if game.drone.global_position.distance_to(centre(i)) < REACH * Geom.M:
			return SPOTS[i][0]
	if rack_on() and game.career() and game.drone.global_position.distance_to(rack_centre()) < REACH * Geom.M:
		return "rack"
	return ""


func _process(dt: float) -> void:
	t += dt
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "salvage", 20.0):
		queue_redraw()


# 105 号: the berth terminal is a cabinet on the tower wall and the parts rack a frame of cubbies
# (scripts/console_art.gd: the name plate, the screen, the glow when close)
func _draw() -> void:
	var at := near()
	var M := Geom.M
	for i in SPOTS.size():
		var id: String = SPOTS[i][0]
		var on := at == id
		var info := {"lines": _screen_lines(), "lamp": "ok"}
		ConsoleArt.draw(self, centre(i) + Vector2(0.55, 0.0) * M, 0.0, game.txt("cn_" + id),
			"[%s] %s · %s" % [Keys.label("use"), game.txt("cn_open") + game.txt("cn_" + id), game.txt("cn_anytime") % Keys.label("terminal")], on, info, t, "wall")
	if rack_on() and game.career():
		var n: int = Career.data.get("parts", []).size()
		var rc := rack_centre() + Vector2(0.2, 0.0) * M
		if StoreBook.ON:
			var wait := not StoreBook.inbox().is_empty()
			ConsoleArt.draw(self, rc, 0.0, ("仓库柜台 · %d/%d 格" % [StoreBook.used(), StoreBook.cap()]) if Txt.zh else ("STORES COUNTER · %d/%d" % [StoreBook.used(), StoreBook.cap()]),
				("[%s] 打开仓库" if Txt.zh else "[%s] OPEN THE STORES") % Keys.label("use"), at == "rack", {"lamp": "warn" if wait else "ok"}, t, "rack")
		else:
			ConsoleArt.draw(self, rc, 0.0, ("零件架 · %d 件" % n) if Txt.zh else ("PARTS RACK · %d" % n), ("[%s] 打开零件架" if Txt.zh else "[%s] OPEN THE PARTS RACK") % Keys.label("use"),
				at == "rack", {"lamp": "ok" if n > 0 else "off"}, t, "rack")
		# 107 号 Q2 A: a shelf per class (as the rack's page), its crates side by side and stacked two
		# high; what does not fit is counted on the beam's end
		var by := Repair.shelf_by_class()
		var cols := [Color(UiSkin.DATA), Pal.heat(1.0, 1.15), Color(1.0, 0.78, 0.35), Pal.tint(Pal.FLUID, 1.0, 1.1)]
		var font := Fonts.get_font("SemiBold")
		var z: float = get_canvas_transform().get_scale().x
		for row in 4:
			var parts: Array = by.get(["sail", "power", "thermal", "drive"][row], [])
			var floor_y := -1.0 + (row + 1) * 0.5 - 0.05
			for k in mini(parts.size(), 10):
				var cr := Rect2(rc + Vector2(-0.94 + (k % 5) * 0.375, floor_y - 0.21 * (k / 5 + 1)) * M, Vector2(0.34, 0.2) * M)
				var ok: bool = float(parts[k].get("cond", 0.0)) >= Repair.COND_MIN
				draw_rect(cr, Color(0.26, 0.27, 0.285) if ok else Color(0.17, 0.175, 0.185))
				draw_rect(Rect2(cr.position, Vector2(cr.size.x, 0.035 * M)), Color(1, 1, 1, 0.12))
				draw_rect(Rect2(cr.position + Vector2(0.03, 0.05) * M, Vector2(0.025 * M, cr.size.y - 0.08 * M)), cols[row] * Color(1, 1, 1, 1.0 if ok else 0.4))
				draw_rect(cr, Pal.ink(0.62), false, 1.0)
				if parts[k].has("listed"):
					FastDraw.circle(self, cr.position + Vector2(cr.size.x - 0.06 * M, 0.06 * M), 0.035 * M, Color(UiSkin.DATA))
			if parts.size() > 10 and M * z >= 14.0:
				draw_set_transform(rc + Vector2(1.12, floor_y - 0.08) * M, 0, Vector2.ONE / z)
				draw_string(font, Vector2.ZERO, "+%d" % (parts.size() - 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.85))
				draw_set_transform(Vector2.ZERO)


# what the berth terminal's screen shows: the company's cash and what waits
func _screen_lines() -> Array:
	if not Career.usable() or Career.data.is_empty():
		return [[("船坞终端" if Txt.zh else "BERTH TERMINAL"), Pal.tint(Pal.AIR, 0.95, 1.2)]]
	var job: Dictionary = Career.active()
	return [[Pal.money(float(Career.data.get("money", 0.0))), Pal.tint(Pal.AIR, 0.95, 1.2)],
		[(("合同 " if Txt.zh else "JOB ") + str(job.get("id", ""))) if not job.is_empty() else ("没有在做的合同" if Txt.zh else "NO JOB ON"), Pal.ink(0.7)]]
