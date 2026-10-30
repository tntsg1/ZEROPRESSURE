extends Node2D
# The company's own works in the processing district (design/…/30_加工区搬家; 23 号 Q14/Q24/Q32):
# a furnace and a pre-processing line of their own — the same machines as under the berth
# (scripts/smelter.gd, scripts/scrapline.gd) — standing inside the district, with the sorting
# desk, the assay bench and the furnace desk beside them. The berth's furnace only takes the
# contract's scrap now, so salvage and production no longer wait on each other. Stock comes
# from the cargo district's warehouse along a visible rail through the corridors and the hub.

const CanvasBatch = preload("res://scripts/canvas_batch.gd")
var game
# 36 号: an electric arc furnace of its own, not the berth's induction furnace
var smelter = preload("res://scripts/arc_furnace.gd").new()
var scrapline = preload("res://scripts/scrapline.gd").new()
var X := 0.0          # m: the furnace's axis, as Dock.furnace_x is for the berth's
var F := 0.0          # m: the line's floor, as Dock.FLOOR_Y is for the berth's
var shapes: Node2D
var line_shapes: Node2D
var _line_z := 0.0
var _line_idle := 0
var texts: Node2D
var glow: Node2D
var font: Font
var font_b: Font
var _glow_tex: Texture2D
var rail_line: Node2D
var _text_t := 0.0
var _shape_z := 0.0
var _idle_drawn := 0
var _text_z := 0.0
var caught_up_s := 0.0        # the time last made good (tests and the operator's note)
const CATCH_DT := 0.25        # s: the catch-up's step
var shapes_us := 0.0          # tests: the furnace's and the line's shapes, their step (µs, smoothed)
var step_us := 0.0
var split_us := Vector4.ZERO     # tests: furnace meshes, furnace batch, line (µs, smoothed)
var line_draws := 0              # tests: how often the line's layer was drawn


static func box_m() -> Rect2:
	var b := PortStructure.box("process")
	return Rect2(b.position / Geom.M, b.size / Geom.M)


static func axis() -> Vector2:
	var b := box_m()
	return Vector2(b.position.x + 16.0, b.position.y + 8.0)


# the overhead rail from the works to the warehouse yard, world px (Q32): in from the
# district's door, down its corridor, across the hub, up the cargo corridor, round the
# cargo district's bays and down through its floor hatch to just above the yard
static func rail() -> Array:
	var c := PortStructure.centre()
	var m := PortStructure.M()
	var pd: Array = PortStructure.door("process")
	var cd: Array = PortStructure.door("cargo")
	var cb := PortStructure.box("cargo")
	var p0: Vector2 = pd[0]
	var c0: Vector2 = cd[0]
	var c_in: Vector2 = c0 + (cd[1] as Vector2) * 4.0 * m
	var top := cb.position.y + 9.0 * m
	var hx := cb.get_center().x
	return [p0 + (pd[1] as Vector2) * 12.0 * m, p0, c + (p0 - c).normalized() * PortArt.HUB_R * m,
		c + (c0 - c).normalized() * PortArt.HUB_R * m, c0, c_in, Vector2(c_in.x, top), Vector2(hx, top), Vector2(hx, cb.end.y - 2.0 * m)]


func _ready() -> void:
	z_index = 1
	var a := axis()
	X = a.x
	F = a.y
	smelter.X = X
	smelter.crane_basket = true
	smelter.meshes = true
	smelter.begin_manual()
	scrapline.X = X
	scrapline.game = game
	scrapline.smelter = smelter
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	_glow_tex = Fx.make_glow_texture(1.6)
	shapes = Node2D.new()
	shapes.draw.connect(_draw_shapes)
	add_child(shapes)
	# 101 号: the line on a layer of its own — it redrew with the furnace every frame of a heat, idle
	# or not (over a millisecond)
	line_shapes = Node2D.new()
	line_shapes.draw.connect(_draw_line_shapes)
	add_child(line_shapes)
	texts = Node2D.new()
	texts.draw.connect(_draw_texts)
	add_child(texts)
	glow = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.draw.connect(_draw_glow)
	add_child(glow)
	rail_line = Node2D.new()
	rail_line.z_index = 2
	rail_line.draw.connect(_draw_rail)
	add_child(rail_line)
	visible = Port.stage("process") >= 1


# Q25: the play time owed since the berth was last in view (the contract's, Career.settle),
# made good on the works — the continuous parts only: the furnace's bath and power, the
# line's drums. A step that wants the operator waits for them, as it would have.
func catch_up() -> void:
	var owed := float(Career.data.get("plant_owed_s", 0.0))
	if owed <= 0.0 or not Career.usable():
		return
	Career.data.plant_owed_s = 0.0
	var heat_on: bool = game.industrial_heat != null and game.industrial_heat.fault == "" and not Career.data.get("industrial_heat", {}).is_empty() and smelter.manual
	var sort_on: bool = game.industrial_sort != null and game.industrial_sort.fault == "" and str(Career.data.get("industrial_sort", {}).get("state", "")) == "processing"
	# the contract's berth furnace had its share first (34 号): the company heat ran on the rest
	var supply_was: float = smelter.manual_supply_mw
	if heat_on:
		smelter.manual_supply_mw = Grid.contract_supply(Career.data.industrial_heat)
	var t := 0.0
	while t < owed and (heat_on or sort_on):
		var dt := minf(CATCH_DT, owed - t)
		if heat_on:
			smelter.step(dt)
		if sort_on:
			scrapline.step(dt)
			if scrapline.company_complete():
				sort_on = false
		t += dt
	caught_up_s = owed
	smelter.manual_supply_mw = supply_was
	if heat_on:
		game.industrial_heat.checkpoint()
	if game.industrial_sort != null and str(Career.data.get("industrial_sort", {}).get("state", "")) != "":
		game.industrial_sort.checkpoint()
	Career.save()


func _process(dt: float) -> void:
	if game == null or not game.in_berth() or game.paused_sim:
		return
	visible = Port.stage("process") >= 1
	smelter.X = X
	# idle works cost nothing a frame: the furnace steps while a heat is on or it is still warm,
	# the line while a batch or anything of one is in it
	if (game.industrial_heat == null or game.industrial_heat.fault == "") and (_heat_on() or float(smelter.T) > 40.0):
		smelter.step(dt)
	scrapline.X = X
	scrapline.game = game
	scrapline.smelter = smelter
	scrapline.floor_y = F
	scrapline.quiet = true
	if (game.industrial_sort == null or game.industrial_sort.fault == "") and (scrapline.company_mode or scrapline.in_process_mass() > 0.0 or scrapline.busy() > 0):
		scrapline.step(dt)
	var hot: bool = _heat_on() or float(smelter.T) > 40.0
	var sorting: bool = scrapline.company_mode or scrapline.in_process_mass() > 0.0 or scrapline.busy() > 0
	var running: bool = hot or sorting
	var seen := _seen()
	if seen and (sorting or absf(game.cam_zoom() - _line_z) > 0.001 or _line_idle < 2):
		_line_idle = 0 if sorting else _line_idle + 1
		_line_z = game.cam_zoom()
		line_shapes.queue_redraw()
	if seen and (running or absf(game.cam_zoom() - _shape_z) > 0.001 or _idle_drawn < 2):
		# the drawing stays as it was while nothing moves and the zoom holds (Godot keeps it)
		_idle_drawn = 0 if running else _idle_drawn + 1
		_shape_z = game.cam_zoom()
		if hot or _idle_drawn > 0 or absf(game.cam_zoom() - _shape_z) > 0.001 or not sorting:
			shapes.queue_redraw()
		glow.queue_redraw()
		# the read-outs and labels: shaped text is dear; four times a second, or when the zoom moves
		_text_t += dt
		var z: float = game.cam_zoom()
		if _text_t > 0.25 or absf(z - _text_z) > 0.001:
			_text_t = 0.0
			_text_z = z
			texts.queue_redraw()
	rail_line.queue_redraw()


func _heat_on() -> bool:
	var h: Dictionary = Career.data.get("industrial_heat", {})
	return not h.is_empty() and str(h.get("state", "")) not in ["complete", "cancelled", "written_off"]


# any of the works in the camera's view
func _seen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var inv := get_global_transform_with_canvas().affine_inverse()
	var r := vp.get_visible_rect()
	var view := Rect2(inv * r.position, inv * r.end - inv * r.position).abs()
	return view.intersects(Rect2(Vector2(X - 14.0, F - 3.0) * Geom.M, Vector2(36.0, 16.0) * Geom.M))


func _draw_shapes() -> void:
	if not _seen():
		return
	var z: float = game.cam_zoom() if game != null else 1.0
	var tx := func(k: String) -> String: return Txt.t(k)
	var t0 := Time.get_ticks_usec()
	# 101 号: the furnace's vessel, roof, mast and arms are meshes, drawn before the batch so the bath,
	# the scrap and the line go over them; a frame round the works keeps the layer from being culled
	shapes.draw_rect(Rect2(Vector2(X - 14.0, F - 3.0) * Geom.M, Vector2(36.0, 16.0) * Geom.M), Color(0, 0, 0, 0), false, 1.0)
	smelter.draw_meshes(shapes, F, 1 if z * Geom.M >= 14.0 else 0)
	var cb = CanvasBatch.new(shapes)
	cb.no_text = true
	var t1 := Time.get_ticks_usec()
	smelter.draw(cb, F, X, font, font_b, z, tx)
	cb.flush()
	var t2 := Time.get_ticks_usec()
	shapes_us = lerpf(shapes_us, float(t2 - t0), 0.1)
	split_us.x = lerpf(split_us.x, float(t1 - t0), 0.1)
	split_us.y = lerpf(split_us.y, float(t2 - t1), 0.1)


func _draw_line_shapes() -> void:
	if not _seen():
		return
	var z: float = game.cam_zoom() if game != null else 1.0
	var tx := func(k: String) -> String: return Txt.t(k)
	var t0 := Time.get_ticks_usec()
	line_shapes.draw_rect(Rect2(Vector2(X - 14.0, F - 3.0) * Geom.M, Vector2(36.0, 16.0) * Geom.M), Color(0, 0, 0, 0), false, 1.0)
	var cb = CanvasBatch.new(line_shapes)
	cb.no_text = true
	scrapline.draw(cb, F, X, font, font_b, z, tx)
	cb.flush()
	split_us.z = lerpf(split_us.z, float(Time.get_ticks_usec() - t0), 0.1)
	line_draws += 1


func _draw_texts() -> void:
	if not _seen():
		return
	var z: float = game.cam_zoom() if game != null else 1.0
	if z >= 0.5:
		var fb := font_b
		# a world-size name: far in it would shrink under a few pixels (and to 0, which the engine refuses)
		if int(13.0 / maxf(z, 0.3)) >= 4:
			texts.draw_string(fb, Vector2(X + 5.0, F - 1.2) * Geom.M, Txt.t("eaf_line"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 / maxf(z, 0.3)), Pal.ink(0.6))
	var tx := func(k: String) -> String: return Txt.t(k)
	var cb = CanvasBatch.new(texts)
	cb.no_shapes = true
	smelter.draw(cb, F, X, font, font_b, z, tx)
	scrapline.draw(cb, F, X, font, font_b, z, tx)
	cb.flush()


# the rail as a girder under the corridors' ceiling: two rails, hangers every 4 m
func _draw_rail() -> void:
	if game == null or not game.in_berth():
		return
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var pts: Array = rail()
	var col := Pal.ink(0.42)
	var m := PortStructure.M()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := (b - a).normalized().orthogonal() * 0.22 * m
		rail_line.draw_line(a + n, b + n, col, 1.6 * lw)
		rail_line.draw_line(a - n, b - n, col, 1.6 * lw)
		var steps := int(a.distance_to(b) / (4.0 * m))
		for k in steps + 1:
			var p := a.lerp(b, float(k) / maxf(1.0, float(steps)))
			rail_line.draw_line(p - n * 1.8, p + n * 1.8, Pal.ink(0.3), lw)
	for p in [pts[0], pts[pts.size() - 1]]:
		rail_line.draw_circle(p, 0.35 * m, Pal.tint(Pal.AIR, 0.6, 1.3))


func _draw_glow() -> void:
	if not _seen():
		return
	smelter.draw_add(glow, F, _glow_tex)
