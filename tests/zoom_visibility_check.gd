extends "res://tests/guide_check.gd"
# 货船穿模 追加 (user: "经常这个货的火车会突然让我视角拉一下，远一下就会消失不见"; and the trade port's freighter
# "一过来就消失"): from the closest zoom out to the furthest (and the port view's), at every step the freight
# train and the freighter alongside the trade port are really on the screen. Checked by the picture, not
# a counter: the frame is captured with the layer shown and again with it hidden, and the pixels round
# where it is must differ (a canvas item can count itself drawn and still not reach the screen).
# Own test saves only.
#   tools/run_test.sh tests/zoom_visibility_check.gd --fixed-fps 60

const PS = preload("res://scripts/port_structure.gd")
const CS = preload("res://scripts/client_ships.gd")
const FW = preload("res://scripts/freight_works.gd")
const ZOOMS := [2.6, 1.6, 1.0, 0.7, 0.45, 0.3, 0.2, 0.13, 0.09, 0.06]


func _initialize() -> void:
	Career.path = "user://zp_test_zoomvis_career.json"
	SaveGame.path = "user://zp_test_zoomvis_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1, "cargo": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.money = 60000.0
	Career.data.migrations = [{"id": "128_hall"}]
	Career.save()


func _grab() -> Image:
	var img := root.get_texture().get_image()
	return img


# pixels round the screen point that change when `node` is hidden
func _diff(node: CanvasItem, world: Vector2, half_px: float) -> int:
	var a := _grab()
	# only the node's own drawing (the bodies), not its children's (floor lifts, cards): with the children
	# counted a layer that drew none of its trains still "showed" (火车看不见 2026-11-10)
	node.self_modulate.a = 0.0
	await _frames(2)
	var b := _grab()
	node.self_modulate.a = 1.0
	await _frames(2)
	var sp: Vector2 = g.get_viewport().get_canvas_transform() * world
	var sz := Vector2(a.get_width(), a.get_height())
	var r := Rect2i(Vector2i(sp - Vector2(half_px, half_px)), Vector2i(Vector2(half_px, half_px) * 2.0)).intersection(Rect2i(Vector2i.ZERO, Vector2i(sz)))
	var n := 0
	for y in range(r.position.y, r.end.y, 1):
		for x in range(r.position.x, r.end.x, 1):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.02:
				n += 1
	return n


func _set_zoom(z: float, at: Vector2) -> void:
	g.zoom_override = z
	g.cam_override = at
	for i in 70:
		g.zoom_now = z
		await process_frame


func _sweep(what: String, node: CanvasItem, where: Callable, len_m: float) -> void:
	var misses: Array = []
	for z in ZOOMS + [-1.0]:
		var zz: float = z if z > 0.0 else Backdrop.port_zoom(g.get_viewport().get_visible_rect().size)
		await _set_zoom(zz, where.call())
		var half := clampf(len_m * Geom.M * zz * 0.7, 6.0, 260.0)
		var n: int = await _diff(node, where.call(), half)
		print("  %s at zoom %.3f: %d px differ" % [what, zz, n])
		if n < 3:
			misses.append("%.3f" % zz)
	check(misses.is_empty(), "%s on the screen at every zoom from 2.6 out to the port view (missing at %s)" % [what, str(misses)])


func _run() -> void:
	Txt.zh = true
	_career()
	_spawn()
	await _frames(20)
	HallMarket.tick(0.1)
	FW.on = true
	# 1. a freight train (it has trains once the cargo and trade districts are open)
	var tries := 0
	while FW.trains.is_empty() and tries < 600:
		await process_frame
		tries += 1
	check(not FW.trains.is_empty() and g.get("freight") != null, "the freight trains are running (%d)" % FW.trains.size())
	if not FW.trains.is_empty():
		var tr: Dictionary = FW.trains[0]
		await _sweep("the freight train", g.freight, func() -> Vector2: return FW.behind(tr, 4.0 * Geom.M), 12.0)
	# 2. the freighter alongside the trade port (something bought, coming with its crates)
	HallMarket.buy("p_battery", 2)
	var id := str(HallMarket.deliveries()[0].id)
	for i in 60 * 30:
		await process_frame
		var d := HallMarket.delivery(id)
		if HallMarket.clock() - float(d.get("ship_at", 1e9)) >= HallMarket.SHIP_IN + 0.5:
			break
	var at_ship := func() -> Vector2:
		for e in CS.ships():
			if str(e.oid) == id:
				return PS.box("trade").position + (e.at as Vector2) * PS.M()
		return PS.box("trade").position + CS.berth() * PS.M()
	await _sweep("the freighter at the trade port", g.client_ships, at_ship, 16.5)
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	print("zoom_visibility_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
