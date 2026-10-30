class_name RepairShow
extends Node2D
# A repair made at the terminal is shown the next time the berth is in view (G2):
# the camera goes to the facility, sparks and a flash, the lamp comes on, a plate
# names it. One item after another, a few seconds each. Driven by the game's
# "build" state like the berth extension (step / cam / finish).

const PER := 3.2            # s per item
var game
var ids: Array = []
var i := 0
var t := 0.0
var font: Font
var font_b: Font


func _init() -> void:
	z_index = 9
	z_as_relative = false


func setup(g, list: Array) -> void:
	game = g
	ids = list.duplicate()
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("SemiBold")


# where a facility sits in the berth (px), for the camera and the sparks
static func spot(id: String) -> Vector2:
	var M := Geom.M
	if id.begins_with("port:"):
		var zone := id.split(":")[1]
		return Backdrop.port_centre_px() + PortArt.district_at(zone) * PortArt.PM * M
	match id:
		"lights": return Vector2(Dock.FLOODS[1], Dock.RAIL_Y + 0.4) * M
		"net_fix", "net05": return Dock.NET * M
		"furnace_main", "mouth_rail": return Dock.zpos("metal")
		"hauler", "hauler2": return (Dock.BAY + Vector2(2.0, -2.0)) * M
		"port2": return Vector2(Dock.FLOOR_X1 - 10.0, -8.4 - Dock.LIFT) * M
		"buffer": return Dock.BUFFER.get_center() * M
		"zones": return Dock.centre() * M
		"arm": return Vector2((Dock.TOWER_X + Dock.ARM_X1) * 0.5, Dock.RAIL_Y + 0.6) * M
		"crane": return Vector2(Dock.centre().x, Dock.RAIL_Y - 1.0) * M
	return Dock.centre() * M


func current() -> String:
	return ids[i] if i < ids.size() else ""


func total() -> float:
	return PER * ids.size()


func step(dt: float) -> bool:
	if i >= ids.size():
		return true
	t += dt
	var at := spot(current())
	if fmod(t, 0.18) < dt and t < PER * 0.7:
		game.fx.sparks(at + Vector2(randf_range(-30, 30), randf_range(-16, 16)), Vector2.UP, 4, Pal.heat(1.0, 2.0), 180.0, 0.4, PI)
	if absf(t - PER * 0.7) < dt:
		game.fx.flash(at, 160.0, 0.5, Pal.ink(0.9, 2.0))
		game.fx.ring(at, 10.0, 140.0, 0.5, Pal.ink(0.8, 1.6), 2.0)
		game.sfx.play("ok")
		# the author's lines (design/台词待写_成长体系.md): the first repair ever, this one, all of them
		if Career.usable():
			var seen: Dictionary = Career.data.get("seen", {})
			if not seen.has("repair_first"):
				seen["repair_first"] = true
				Career.data.seen = seen
				Copy.say(game.radio, "L_repair_first")
			Copy.say(game.radio, "L_repair_" + current().replace(":", "_"))
			var all := true
			for it in Repair.ITEMS:
				if not Repair.done(it[0]):
					all = false
			if all and not seen.has("repair_all"):
				seen["repair_all"] = true
				Career.data.seen = seen
				Copy.say(game.radio, "L_repair_all")
	if t >= PER:
		t = 0.0
		i += 1
	queue_redraw()
	return i >= ids.size()


func cam(_size: Vector2) -> Array:
	var at := spot(current()) if current() != "" else Dock.centre() * Geom.M
	if current().begins_with("port:"):
		var zone := current().split(":")[1]
		return [at, 0.16 if zone == "ring" else 0.24]
	return [at + Vector2(0, -20), 1.15]


func finish() -> void:
	pass


static func _title(id: String) -> String:
	if id.begins_with("port:"):
		var parts := id.split(":")
		return "%s · %s %s" % [Port.name_of(parts[1]), Txt.t("pt_stage"), parts[2]]
	return Repair.name_of(id)


func _draw() -> void:
	var id := current()
	if id == "":
		return
	var at := spot(id)
	var k := clampf(t / 0.3, 0.0, 1.0)
	var w := 420.0
	var r := Rect2(at + Vector2(-w * 0.5, -140), Vector2(w, 64))
	draw_rect(r, Color(0.02, 0.022, 0.026, 0.92 * k))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Pal.heat(k, 1.3))
	var done: bool = t >= PER * 0.7
	draw_string(font, r.position + Vector2(18, 24), Txt.t("rp_show_done") if done else Txt.t("rp_show_working"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.55 * k))
	draw_string(font_b, r.position + Vector2(18, 50), _title(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.95 * k))
	var frac := clampf(t / (PER * 0.7), 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x * frac, 3)), Pal.heat(0.9 * k, 1.2))
	draw_line(at + Vector2(0, -76), at + Vector2(0, -30), Pal.ink(0.5 * k), 1.0, true)
	draw_arc(at, 22.0 + 6.0 * sin(t * 6.0), 0.0, TAU, 32, Pal.heat(0.8 * k, 1.3), 1.6, true)
