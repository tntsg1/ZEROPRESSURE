extends "res://tests/art_atlas.gd"
# Render the eight requested devices through the game's real Art.draw path.
# No career/save access. Includes every fleet size and both display modes.
const KEYS := ["p_apu", "p_ark_amp", "p_aux", "p_ax_gamma_monitor", "p_bl_feeder", "p_bl_humidifier", "p_bl_mister", "p_comms"]
const NAMES := ["辅助动力 APU", "功率放大器", "辅助推进器", "伽马辐射监测仪", "自动投饵机", "加湿器", "喷雾器", "通信台"]
var variants := []
var checked := false


func _collect() -> void:
	super._collect()
	entries = entries.filter(func(e): return e.name_key in KEYS)
	# Keep every actual size for a drawing smoke check, choose the screenshot's
	# small communication console as the representative rather than a bigger rack.
	variants = entries.duplicate()
	var chosen := []
	for key in KEYS:
		var candidates := entries.filter(func(e): return e.name_key == key)
		assert(not candidates.is_empty(), "Missing fleet device: " + key)
		var e = candidates[0]
		if key == "p_comms":
			var ship = JSON.parse_string(FileAccess.get_file_as_string("res://ships/ax40.json"))
			for pd in ship.pieces:
				if pd.get("name_key", "") == key:
					e = e.duplicate(true)
					e.pick = pd
					e.best = "1.0x0.7"
					e.raw_arts = {"aux": 1}
					break
		chosen.append(e)
	entries = chosen


func _fit(p) -> Array:
	var s: float = minf(390.0 / maxf(p.art_size.x * M, 1), 230.0 / maxf(p.art_size.y * M, 1))
	# Larger than the atlas, so the small devices' construction can be inspected.
	var centre: Vector2 = p.art_xf * (p.art_size * M * 0.5)
	return [s, Vector2(240, 135) - centre * s]


func _paint() -> void:
	for i in batch.size():
		var org := Vector2((i % COLS) * CW, (i / COLS) * CH)
		node.draw_rect(Rect2(org, Vector2(CW, CH)), Color(0.052, 0.055, 0.063))
		var p = batch[i].p
		var fit: Array = batch[i].fit
		var size: Vector2 = p.art_size * M * float(fit[0])
		node.draw_set_transform(org + Vector2(240, 135) - size * 0.5)
		Art.draw(node, str(batch[i].raw_arts.keys()[0]), size, p, font)
		node.draw_set_transform(Vector2.ZERO)
		batch[i].scale_used = fit[0]
		node.draw_string(font, org + Vector2(20, 285), NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, 440, 24, Pal.ink(0.95))
		node.draw_string(font, org + Vector2(20, 315), batch[i].name_key + "  /  " + batch[i].best + " m", HORIZONTAL_ALIGNMENT_LEFT, 440, 15, Pal.ink(0.5))
		node.draw_line(org + Vector2(10, 345), org + Vector2(470, 345), Pal.ink(0.15))
	# Exercise the actual art sizes in both styles (outside the capture), including
	# tall communication consoles, not just enlarged square thumbnails.
	if not checked:
		var renders := 0
		for mode in [false, true]:
			Pal.solid = mode
			for v in variants:
				for size in v.sizes:
					var a: PackedStringArray = size.split("x")
					var p = _piece(v.pick, str(v.raw_arts.keys()[0]))
					p.art_size = Vector2(float(a[0]), float(a[1]))
					node.draw_set_transform(Vector2(-20000, -20000))
					Art.draw(node, p.art, p.art_size * M, p, font)
					renders += 1
		Pal.solid = true
		node.draw_set_transform(Vector2.ZERO)
		checked = true
		print("EQUIPMENT IDENTITY: ", renders, " fleet-size/style renders, 8 named devices")
