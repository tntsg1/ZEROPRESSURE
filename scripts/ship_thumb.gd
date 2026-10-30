extends Control
class_name ShipThumb
# A ship's side view on a card (45 号, the hulk market's cards): its structure outline as the
# ship file draws it (the terminal's contract cards do the same, scripts/terminal.gd _thumb),
# scaled into the control. Worked out once per offer and kept.

static var _cache := {}         # offer id -> {outline, len, h, mid}
var offer: Dictionary = {}
var tags: Array = []            # short notes drawn on the picture (what an inspection found)
var dim := false


func _init(o: Dictionary = {}) -> void:
	offer = o
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func shape_of(o: Dictionary) -> Dictionary:
	var id := str(o.get("id", o.get("ship", "")))
	if _cache.has(id):
		return _cache[id]
	var th := {"outline": [], "len": 40.0, "h": 8.0, "mid": 0.0}
	var data := Ship.load_data(str(o.get("ship", "")))
	if not data.is_empty():
		var d := Variant.make(data, o)
		var y0 := 0.0
		var y1 := 0.0
		for pd in d.pieces:
			if pd.kind in ["hull", "hatch", "keel", "beam", "strut", "rail", "deck", "bulkhead"]:
				var pts := PackedVector2Array()
				for q in pd.poly:
					pts.append(Vector2(q[0], q[1]))
					y0 = minf(y0, q[1])
					y1 = maxf(y1, q[1])
				if pts.size() > 1:
					pts.append(pts[0])
					th.outline.append(pts)
		th.len = float(d.get("length", 40.0))
		th.h = maxf(6.0, y1 - y0 + 1.0)
		th.mid = (y0 + y1) * 0.5
	_cache[id] = th
	return th


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-6.0)
	draw_style_box(UiSkin.box("screen", 1.0), Rect2(Vector2.ZERO, size))
	if offer.is_empty():
		return
	var th := shape_of(offer)
	var L: float = th.len
	var sc := minf(r.size.x / L, r.size.y / th.h)
	var org := Vector2(r.position.x + (r.size.x - L * sc) * 0.5, r.get_center().y - float(th.mid) * sc)
	var col := Pal.ink(0.35 if dim else 0.7)
	for pts in th.outline:
		var sp := PackedVector2Array()
		for v in pts:
			sp.append(org + v * sc)
		draw_polyline(sp, col, 1.0, true)
	var font := Fonts.get_font("Medium")
	var y := 18.0
	for t in tags:
		draw_string(font, Vector2(8, y), "⚠ " + str(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.heat(0.9, 1.2))
		y += 18.0
