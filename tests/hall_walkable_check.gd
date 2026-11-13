extends "res://tests/guide_check.gd"
# 2026-11-12 (user: "我能走的地方应该没有柱子才对，是空的"): no hall structure in the open air. Each
# district's hall (scripts/district_style.gd) is drawn into a null canvas with its structure helpers
# noting their rects; every point of every rect must lie on the shell (FRAME in from the end walls),
# above the ceiling, below the floor, or inside something that really collides (scripts/port_solids.gd,
# the floor, the port's MACHINES, the interiors' SOLIDS). Static: no game, no saves.
#   tools/run_test.sh tests/hall_walkable_check.gd


const PortSolids = preload("res://scripts/port_solids.gd")


class NullCanvas:
	func draw_rect(_r, _c, _f = true, _w = -1.0, _aa = false) -> void:
		pass
	func draw_line(_a, _b, _c, _w = -1.0, _aa = false) -> void:
		pass
	func draw_polygon(_p, _c, _u = null, _t = null) -> void:
		pass
	func draw_colored_polygon(_p, _c, _u = null, _t = null) -> void:
		pass
	func draw_circle(_p, _r, _c, _f = true, _w = -1.0, _aa = false) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


# the processing hall's columns as process_art draws them now (with the halls on: only where solid)
func _process_cols() -> Array:
	var out: Array = []
	var pa = preload("res://scripts/process_art.gd")
	for cx in pa.HALL_COLS:
		for sp: Vector2 in DistrictStyle.column_spans("process", cx, 7.8, 26.8):
			out.append(Rect2(cx - 0.3, sp.x, 0.6, sp.y - sp.x))
	return out


func _cargo_cols() -> Array:
	var out: Array = []
	for cx in preload("res://scripts/cargo_art.gd").HALL_COLS:
		var spans: Array = [Vector2(1.3, 26.8)] if cx < 1.0 or cx > 59.0 else DistrictStyle.column_spans("cargo", cx, 1.3, 26.8)
		for sp: Vector2 in spans:
			out.append(Rect2(cx - 0.3, sp.x, 0.6, sp.y - sp.x))
	return out


func _solids(zone: String) -> Array:
	var out: Array = []
	out.append_array(PortSolids.rects(zone))
	out.append_array(PortSolids.floor_rects(zone))
	for mc in PortStructure.MACHINES.get(zone, []):
		out.append(Rect2(mc[1], mc[2]))
	for s in preload("res://scripts/district_interiors.gd").SOLIDS.get(zone, []):
		out.append(Rect2(s[1], s[2]))
	return out


func _allowed(p: Vector2, solids: Array) -> bool:
	if p.x <= DistrictStyle.FRAME + 0.001 or p.x >= 60.0 - DistrictStyle.FRAME - 0.001:
		return true
	if p.y <= DistrictStyle.CEIL + 0.001 or p.y >= DistrictStyle.FLOOR_Y - 0.001:
		return true
	for s in solids:
		if (s as Rect2).grow(0.02).has_point(p):
			return true
	return false


func _run() -> void:
	var nc := NullCanvas.new()
	var r := Rect2(Vector2.ZERO, Vector2(60.0, 28.0))
	for zone in ["trade", "process", "cargo", "power"]:
		DistrictStyle.noted = []
		DistrictStyle.noting = true
		match zone:
			"trade":
				DistrictStyle.trade_hall(nc, r, 1.0, true)
			"process":
				DistrictStyle.process_hall(nc, r, 1.0, true)
			"cargo":
				DistrictStyle.cargo_hall(nc, r, 1.0, true)
			"power":
				DistrictStyle.power_hall(nc, r, 1.0, true)
		DistrictStyle.noting = false
		var solids := _solids(zone)
		var bad: Array = []
		for rr in DistrictStyle.noted:
			var rect := rr as Rect2
			var hit := false
			for i in 9:
				for j in 9:
					var p := rect.position + rect.size * Vector2(i / 8.0, j / 8.0)
					if not _allowed(p, solids):
						hit = true
			if hit:
				bad.append(rect)
		for b in bad.slice(0, 6):
			print("    %s: in the open air %s" % [zone, b])
		check(DistrictStyle.noted.size() > 0 and bad.is_empty(), "%s: hall structure only on the shell, ceiling, floor or real solids (%d pieces, %d in the open)" % [zone, DistrictStyle.noted.size(), bad.size()])
	# the districts' own art: its columns (box-local m) against the same rule. The districts done in
	# this rollout must pass; the others are listed (what is left to fix there)
	var art_cols := {
		"process": _process_cols(),
		"trade": [Rect2(21.7, 16.4, 0.6, 10.4), Rect2(34.2, 16.4, 0.6, 10.4), Rect2(44.7, 16.4, 0.6, 10.4)],
		"cargo": _cargo_cols(),
		"power": [38.2, 42.4, 50.3, 57.4].map(func(x): return Rect2(x - 0.3, 12.6, 0.6, 3.9)),
		"tug": [Rect2(22.68, 11.5, 0.64, 15.3), Rect2(37.28, 11.5, 0.64, 15.3), Rect2(52.19, 0.2, 0.52, 11.5)],
	}
	var done := ["trade", "process", "cargo", "power"]
	for zone in art_cols:
		var sol := DistrictStyle.solids(zone)
		var open_cols: Array = []
		for rc in art_cols[zone]:
			var rect := rc as Rect2
			var free := 0.0
			for i in 41:
				var p := Vector2(rect.get_center().x, rect.position.y + rect.size.y * i / 40.0)
				if not _allowed(p, sol):
					free += rect.size.y / 40.0
			if free > 0.3:
				open_cols.append("x %.1f (%.1f m of it in the open)" % [rect.get_center().x, free])
		if zone in done:
			check(open_cols.is_empty(), "%s: the art's columns stand only in what collides (%s)" % [zone, ", ".join(open_cols) if not open_cols.is_empty() else "all"])
		else:
			print("    to fix later — %s: %s" % [zone, ", ".join(open_cols) if not open_cols.is_empty() else "none"])
	# the check itself: a column stood in the open (the first trade hall's) is caught
	DistrictStyle.noted = []
	DistrictStyle.noting = true
	DistrictStyle._column(nc, r, 1.0, 30.0, 0.9, 26.8, 1.2)
	DistrictStyle.noting = false
	var caught := false
	var sol := _solids("trade")
	for i in 9:
		var p := (DistrictStyle.noted[0] as Rect2).position + (DistrictStyle.noted[0] as Rect2).size * Vector2(0.5, i / 8.0)
		if not _allowed(p, sol):
			caught = true
	check(caught, "a column in the open air is caught")
	print("HALL WALKABLE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
