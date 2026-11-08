extends Node2D
# The gas line's works outside the processing district (76 号): the purifier column and its
# compressor, the cold box, the LOX tank with its level and frost, the vent stack (a plume when
# the tank boils off or the residue is vented). (132 号: no supply berth — passing ships no longer buy
# gas; LOX and LH2 go by the exchange and the orders.) Drawn in the port's metres from the game's own
# state; redrawn when it changes.

var game
var font: Font
var _sig := ""
var _t := 0.0
var _vented0 := -1.0
var plume := 0.0


func _ready() -> void:
	z_index = 2
	z_as_relative = false
	font = Fonts.get_font("Regular")


func active() -> bool:
	return game != null and game.in_berth() and game.career() and GasLine.built()


# the works' origin (m in world px): left of the processing district, at its floor's height
static func origin() -> Vector2:
	var b := PortStructure.box("process")
	return Vector2(b.position.x - 46.0 * PortStructure.M(), b.position.y + 2.0 * PortStructure.M())


func _process(dt: float) -> void:
	visible = active()
	if not visible:
		return
	_t += dt
	var d := GasLine.data()
	if _vented0 < 0.0:
		_vented0 = float(d.vented)
	if float(d.vented) > _vented0 + 0.01:
		plume = 1.0
	_vented0 = float(d.vented)
	plume = maxf(0.0, plume - dt * 0.5)
	var sig := "%d/%s/%d/%d" % [int(float(d.lox.kg) / 200.0), str(d.job.is_empty()) + str(d.get("liq", {}).is_empty()), int(plume * 10.0), int(_t * 4.0) if not d.job.is_empty() or not d.get("liq", {}).is_empty() else 0]
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _p(m: Vector2) -> Vector2:
	return origin() + m * PortStructure.M()


func _draw() -> void:
	if not active():
		return
	var M := PortStructure.M()
	var d := GasLine.data()
	var lw := 0.12 * M
	var ink := Pal.ink(0.6)
	var fill := Color(0.06, 0.065, 0.075)
	var running: bool = not d.job.is_empty()
	var liq_on: bool = not d.get("liq", {}).is_empty()
	# the skid it all stands on, bolted to the district's wall
	draw_rect(Rect2(_p(Vector2(-2, 24)), Vector2(46, 1.2) * M), fill)
	draw_rect(Rect2(_p(Vector2(-2, 24)), Vector2(46, 1.2) * M), ink, false, lw)
	draw_line(_p(Vector2(44, 24.6)), _p(Vector2(46, 24.6)), ink, lw * 2.0)
	# the purifier column (adsorber + the separation column), with its trays
	var col := Rect2(_p(Vector2(2, 4)), Vector2(4, 20) * M)
	draw_rect(col, fill)
	draw_rect(col, ink, false, lw)
	for i in 8:
		draw_line(_p(Vector2(2, 6.0 + i * 2.2)), _p(Vector2(6, 6.0 + i * 2.2)), Pal.ink(0.3), lw * 0.6)
	if running:
		var k := fmod(_t * 0.8, 1.0)
		draw_rect(Rect2(_p(Vector2(2.4, 22.0 - k * 17.0)), Vector2(3.2, 0.5) * M), Pal.tint(Pal.AIR, 0.7, 1.2))
	if Pal.labels: draw_string(font, _p(Vector2(1.5, 3.2)), Ops.w("净化分离塔", "PURIFIER / COLUMN"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.9 * M), Pal.ink(0.7))
	# the compressor
	var cp := _p(Vector2(10, 20))
	draw_rect(Rect2(cp, Vector2(6, 4) * M), fill)
	draw_rect(Rect2(cp, Vector2(6, 4) * M), ink, false, lw)
	draw_arc(cp + Vector2(3, 2) * M, 1.4 * M, 0.0, TAU, 18, ink, lw)
	var ang := _t * 6.0 if running or liq_on else 0.0
	draw_line(cp + Vector2(3, 2) * M, cp + Vector2(3, 2) * M + Vector2.from_angle(ang) * 1.2 * M, ink, lw)
	if Pal.labels: draw_string(font, cp + Vector2(0, -0.6) * M, Ops.w("压缩机", "COMPRESSOR"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.8 * M), Pal.ink(0.6))
	# the cold box
	var cb := Rect2(_p(Vector2(19, 9)), Vector2(6, 15) * M)
	draw_rect(cb, fill)
	draw_rect(cb, Pal.tint(Pal.AIR, 0.5, 1.0) if liq_on else ink, false, lw)
	for i in 5:
		draw_line(_p(Vector2(19.6, 11.0 + i * 2.5)), _p(Vector2(24.4, 12.0 + i * 2.5)), Pal.ink(0.3), lw * 0.6)
	if Pal.labels: draw_string(font, _p(Vector2(18.5, 8.2)), Ops.w("液化冷箱", "COLD BOX"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.8 * M), Pal.ink(0.6))
	# pipes column → compressor → cold box → tank
	for seg in [[Vector2(6, 21), Vector2(10, 21)], [Vector2(16, 21), Vector2(19, 21)], [Vector2(25, 12), Vector2(29, 12)]]:
		draw_line(_p(seg[0]), _p(seg[1]), Pal.ink(0.5), lw * 1.6)
	# the LOX tank: an upright vacuum-jacketed vessel, its level, frost on it while it holds LOX
	if GasLine.tank_built():
		var tr := Rect2(_p(Vector2(29, 5)), Vector2(8, 19) * M)
		draw_rect(tr, fill)
		var lv := clampf(float(d.lox.kg) / GasLine.TANK_CAP, 0.0, 1.0)
		draw_rect(Rect2(_p(Vector2(29.6, 24.0 - 18.4 * lv)), Vector2(6.8, 18.4 * lv) * M), Color(0.35, 0.55, 0.85, 0.55))
		draw_rect(tr, Pal.tint(Pal.AIR, 0.7, 1.1) if lv > 0.0 else ink, false, lw * (1.6 if lv > 0.0 else 1.0))
		draw_string(font, _p(Vector2(28.5, 4.2)), Ops.w("液氧储罐 %.1f / %.0f t", "LOX %.1f / %.0f t") % [float(d.lox.kg) / 1000.0, GasLine.TANK_CAP / 1000.0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.85 * M), Pal.tint(Pal.AIR, 0.8, 1.1))
		# the vent stack and its plume when it boils off or the residue goes
		draw_line(_p(Vector2(36, 5)), _p(Vector2(36, 1)), ink, lw * 1.4)
		if plume > 0.0:
			for i in 4:
				var r := (0.6 + i * 0.7) * M
				draw_circle(_p(Vector2(36 + i * 0.6, 0.5 - i * 1.2)), r, Color(0.8, 0.85, 0.9, 0.18 * plume))
