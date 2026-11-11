extends Node2D
# The freight pier off the warehouse yard (design/…/31 号; 23 Q9 Q10 Q18 Q22 Q23 Q27 Q30): the
# freighters of scripts/shipping.gd at true scale (40–80 m), coming in from the east, braking,
# mooring at their berth; the goods real bodies in the hold. Until the cargo district is mended
# the operator hauls them through the yard's east gate into the warehouse receiver (selling: from
# the pier's loading table into the hull's hold); after it, the pier crane does pieces up to 3 t.
# A ship still holding goods is unloaded onto the apron by its crew when the next ship needs its
# berth; goods on the apron are not stock until they reach the receiver.
# The node also runs the shipping clock in every career scene: ships fly during contracts (Q25).

const CanvasBatch = preload("res://scripts/canvas_batch.gd")
const Loads = preload("res://scripts/load_motion.gd")
const DECK_Y := -0.625        # m from the yard's centre: the deck's axis, level with the yard's east gate
const DECK_HALF := 1.5
const DECK_X0 := 6.1          # m: the yard's east wall
const SLOT_X := 36.0          # m: where the first berths begin
const APPROACH_S := 22.0      # s: in from the east and brake
const LEAVE_S := 18.0
const CRANE := 4.0            # m/s: the pier crane's trolley

var game
var yard: Node2D                    # exchange_logistics: the yard, its warehouse receiver
var hulls := {}                     # ship id → {body: StaticBody2D, hold: Area2D, t (s since docking seen)}
var leaving := {}                   # ship id → {at: Vector2, len, t} drawn flying off
var bodies := {}                    # piece key → FreeBody
var crane := {}                     # {key, path: Array, i} the piece the crane has
var _save_t := 0.0
var _dirty := false
var _market_t := 9.0
var font: Font
var deck_layer: Node2D
var _deck_key := ""
var _deck_pen: RefCounted


func active() -> bool:
	return game != null and game.in_berth() and game.career() and Career.usable()


func _ready() -> void:
	z_index = 2
	font = Fonts.get_font("Medium")
	process_physics_priority = 5
	deck_layer = Node2D.new()
	deck_layer.show_behind_parent = true
	deck_layer.draw.connect(_draw_deck_static)
	add_child(deck_layer)


# ---------------------------------------------------------------- geometry (yard-local metres → world px)

func _px(m: Vector2) -> Vector2:
	return yard.global_position + m * Geom.M


static func hull_h(length: float) -> float:
	return length * 0.17


# a berth's ship centre (m, yard-local): all three north of the deck, one after another
# eastwards (south of it is the berth's top truss)
const SLOT_PITCH := 85.0
func slot_centre(k: int, length: float) -> Vector2:
	var h := hull_h(length)
	return Vector2(SLOT_X + SLOT_PITCH * k + length * 0.5, DECK_Y - DECK_HALF - 1.0 - h * 0.5)


# the hold: [rect (m, yard-local), the side that opens onto the deck (+1 south, -1 north)]
func hold_of(k: int, length: float) -> Array:
	var c := slot_centre(k, length)
	var h := hull_h(length)
	var size := Vector2(length * 0.45, h * 0.62)
	var face := 1.0
	var top := c.y + face * h * 0.5 - size.y
	return [Rect2(Vector2(c.x - size.x * 0.5, top), size), face]


# the deck runs as far as the berths the cargo district has opened
func _deck_x1() -> float:
	return SLOT_X + SLOT_PITCH * Shipping.slots() - 5.0


func apron_at(i: int) -> Vector2:
	return Vector2(10.0 + float(i % 8) * 2.4, DECK_Y + DECK_HALF + 1.4 + float(i / 8) * 2.4)


func table_at(i: int) -> Vector2:
	return Vector2(10.0 + float(i % 8) * 2.4, DECK_Y - DECK_HALF - 1.4 - float(i / 8) * 2.4)


# ---------------------------------------------------------------- per frame

func _physics_process(dt: float) -> void:
	if game == null or not game.career() or not Career.usable():
		return
	if game.state != "play" or game.menu_open or game.paused_sim:
		return
	if Shipping.tick(dt):
		_dirty = true
	Grid.sample(game, dt)
	# the hulk market keeps its listings and its tows on the same clock (33 号)
	_market_t += dt
	if _market_t > 1.0:
		_market_t = 0.0
		var listed := ShipMarket.refresh()
		var towing: Array = []
		for a in ShipMarket.data().assets if Career.data.has("ship_market") else []:
			if str(a.get("state", "")) == "towing":
				towing.append(str(a.id))
		if ShipMarket.tick() or listed:
			_dirty = true
		# user 2026-10-26: "它到了，那我应该怎么去接它？" — a hulk come home is announced on the spot
		for a in ShipMarket.data().assets if Career.data.has("ship_market") else []:
			if towing.has(str(a.id)) and str(a.get("state", "")) in ["arrived", "held"]:
				game.hulk_home(a)
	_save_t += dt
	if _dirty and _save_t > 2.0:
		_save_t = 0.0
		_dirty = false
		Career.save()
	visible = active()
	if not visible or yard == null:
		return
	deck_layer.visible = ViewCull.sees(game, Rect2(_px(Vector2(DECK_X0, DECK_Y - 12.0)), Vector2(_deck_x1() - DECK_X0 + 80.0, 24.0) * Geom.M))
	var key := str([yard.global_position, _deck_x1(), Shipping.slots(), roundi(log(maxf(game.cam_zoom(), 0.02)) * 200.0), Txt.zh])
	if deck_layer.visible and key != _deck_key:
		_deck_key = key
		deck_layer.queue_redraw()
	_sync_hulls(dt)
	_sync_pieces()
	_receive()
	_crane(dt)
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	# (the freighters come in from far east of the yard: a wide margin)
	if ViewCull.sees_zone(game, "cargo", 160.0):
		queue_redraw()


func _sync_hulls(dt: float) -> void:
	var seen := {}
	for s in Shipping.at_pier():
		var id := str(s.id)
		seen[id] = true
		if not hulls.has(id):
			hulls[id] = _make_hull(s)
			# a ship that docked while the operator was here comes in from the east
			hulls[id].t = 0.0 if Shipping.day() - float(s.get("docked_day", 0.0)) < APPROACH_S * Orbits.DAYS_PER_S else APPROACH_S
		hulls[id].t = float(hulls[id].t) + dt
	for id in hulls.keys():
		if not seen.has(id):
			var hd: Dictionary = hulls[id]
			leaving[id] = {"at": hd.centre, "len": hd.len, "t": 0.0, "slot": hd.slot}
			hd.body.queue_free()
			hd.hold.queue_free()
			hulls.erase(id)
	for id in leaving.keys():
		leaving[id].t = float(leaving[id].t) + dt
		if float(leaving[id].t) > LEAVE_S:
			leaving.erase(id)


# the hull at its berth: solid round the hold, the hold open to the deck
func _make_hull(s: Dictionary) -> Dictionary:
	var k := int(s.slot)
	var length := float(s.length)
	var c := slot_centre(k, length)
	var h := hull_h(length)
	var hold: Array = hold_of(k, length)
	var hr: Rect2 = hold[0]
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var hull := Rect2(c - Vector2(length, h) * 0.5, Vector2(length, h))
	# fore and aft of the hold, and the hold's back wall
	var parts := [Rect2(hull.position, Vector2(hr.position.x - hull.position.x, h)),
		Rect2(Vector2(hr.end.x, hull.position.y), Vector2(hull.end.x - hr.end.x, h))]
	if float(hold[1]) > 0.0:
		parts.append(Rect2(Vector2(hr.position.x, hull.position.y), Vector2(hr.size.x, hr.position.y - hull.position.y)))
	else:
		parts.append(Rect2(Vector2(hr.position.x, hr.end.y), Vector2(hr.size.x, hull.end.y - hr.end.y)))
	for r in parts:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size * Geom.M
		cs.shape = sh
		cs.position = _px(r.get_center()) - global_position
		body.add_child(cs)
	add_child(body)
	var area := Area2D.new()
	area.name = "Hold_" + str(s.id)
	area.collision_layer = 0
	area.collision_mask = 1
	var acs := CollisionShape2D.new()
	acs.name = "Shape"
	var ash := RectangleShape2D.new()
	ash.size = hr.size * Geom.M
	acs.shape = ash
	area.position = _px(hr.get_center()) - global_position
	area.add_child(acs)
	add_child(area)
	return {"body": body, "hold": area, "hold_rect": hr, "centre": c, "len": length, "slot": k, "t": 0.0}


# the goods as bodies: in the hold, on the apron, on the loading table — once each
func _sync_pieces() -> void:
	var space := get_world_2d().direct_space_state
	var apron_i := 0
	var table_i := 0
	for s in Shipping.data().ships:
		for p in s.pieces:
			var key := str(p.key)
			var where := str(p.where)
			if where in ["received", "loaded"]:
				if bodies.has(key):
					if is_instance_valid(bodies[key]):
						game.world.remove_body(bodies[key])
					bodies.erase(key)
				continue
			if where == "apron":
				apron_i += 1
			elif where == "deck":
				table_i += 1
			if bodies.has(key) and is_instance_valid(bodies[key]):
				continue
			# only at the pier: in the hold of a hull that has come in, or out on the deck
			if where == "hold" and (str(s.state) != "docked" or not hulls.has(str(s.id)) or float(hulls[str(s.id)].t) < APPROACH_S):
				continue
			if where == "deck" and str(s.state) != "docked":
				continue
			var found = game.world.key_piece(key)
			if found != null and found.body != null:
				bodies[key] = found.body
				_tag(found.body, s, key)
				continue
			var at: Vector2
			match where:
				"hold":
					var hr: Rect2 = hulls[str(s.id)].hold_rect
					var idx: int = s.pieces.find(p)
					at = Vector2(hr.position.x + 1.4 + float(idx % 6) * 2.3, hr.get_center().y + (float(idx / 6) - 0.5) * 2.3)
				"apron":
					at = apron_at(apron_i - 1)
				_:
					at = table_at(table_i - 1)
			var side := sqrt(float(p.mass)) * Geom.M
			var wpos := _px(at)
			if not Loads.clear_spawn(space, wpos, Vector2.ONE * side):
				continue
			var piece = game.world.add_piece("cargo", Geom.rect_poly(Rect2(wpos - Vector2.ONE * side * 0.5, Vector2.ONE * side)), {"key": key, "cls": "equip", "mass": float(p.mass), "scope": false, "value": 0.0, "label": "FREIGHT"})
			game.world.make_body([piece], null)
			if piece.body == null:
				continue
			bodies[key] = piece.body
			_tag(piece.body, s, key)


func _tag(b, s: Dictionary, key: String) -> void:
	b.set_meta("ship_piece", key)
	b.set_meta("exchange_trade", str(s.trade))
	b.collision_mask = FreeBody.MASK


func _ship_of_piece(key: String) -> Dictionary:
	for s in Shipping.data().ships:
		for p in s.pieces:
			if str(p.key) == key:
				return s
	return {}


func _encloses(area: Area2D, b) -> bool:
	var sh = area.get_node("Shape").shape
	return Rect2(area.global_position - sh.size * 0.5, sh.size).encloses(Loads.bounds(b))


# a piece fully inside its receiver: the warehouse's (goods in) or its hull's hold (goods out)
func _receive() -> void:
	for key in bodies.keys():
		var b = bodies[key]
		if not is_instance_valid(b) or b.pieces.is_empty():
			bodies.erase(key)
			continue
		var s := _ship_of_piece(key)
		if s.is_empty():
			continue
		var target: Area2D = yard.warehouse if str(s.dir) == "in" else (hulls[str(s.id)].hold if hulls.has(str(s.id)) else null)
		if target == null or not _encloses(target, b):
			continue
		if game.tools.held_body == b:
			game.tools.release_grab(false)
		var r := Shipping.piece_done(s, key)
		if not r.ok:
			continue
		if crane.get("key", "") == key:
			crane = {}
		game.world.remove_body(b)
		bodies.erase(key)
		game.sfx.play("menu", b.global_position, 0.7)
		if r.get("complete", false) and str(s.dir) == "in":
			game.say_text(Shipping.w("货已入库：%s %.2f t", "IN STOCK: %s %.2f t") % [Ops.item_name(_key(s)), float(s.quantity)], b.global_position)


static func _key(s: Dictionary) -> String:
	return "%s:%d" % [str(s.item), int(s.grade)]


# Q10: once the cargo district stands, the pier crane takes pieces up to 3 t on its own
# 37 号 (player 2026-10-25: "selling is listing, nothing more"): what the company sold is loaded
# by the buyer's own crew whatever the cargo district's state; goods coming in wait for the crane
func _crane(dt: float) -> void:
	var own_crane := Port.stage("cargo") >= 1
	if crane.is_empty():
		for key in bodies:
			var s := _ship_of_piece(key)
			var b = bodies[key]
			if s.is_empty() or not is_instance_valid(b) or game.tools.held_body == b or b.total_mass() > Shipping.AUTO_MAX_T:
				continue
			if str(s.dir) == "in" and not own_crane:
				continue
			var p := yard.to_local(b.global_position) / Geom.M
			var path: Array = []
			if str(s.dir) == "in":
				var wh: Vector2 = yard.warehouse.position / Geom.M
				path = [Vector2(p.x, DECK_Y), Vector2(DECK_X0 - 0.5, DECK_Y), Vector2(wh.x, DECK_Y)]
				path.append(wh)
			elif hulls.has(str(s.id)):
				var hr: Rect2 = hulls[str(s.id)].hold_rect
				path = [Vector2(p.x, DECK_Y), Vector2(hr.get_center().x, DECK_Y), hr.get_center()]
			if path.is_empty():
				continue
			crane = {"key": key, "path": path, "i": 0}
			b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
			b.freeze = true
			break
	if crane.is_empty():
		return
	var b = bodies.get(crane.key)
	if b == null or not is_instance_valid(b) or game.tools.held_body == b:
		crane = {}
		return
	var path: Array = crane.path
	var i := int(crane.i)
	if i >= path.size():
		return
	var target := _px(path[i])
	b.global_position = b.global_position.move_toward(target, CRANE * Geom.M * dt)
	if b.global_position.distance_to(target) < 0.5:
		crane.i = i + 1


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not active() or yard == null:
		return
	var m := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var ink := Pal.ink(0.5)
	if ViewCull.sees(game, Rect2(_px(Vector2(DECK_X0, DECK_Y - 12.0)), Vector2(_deck_x1() - DECK_X0 + 80.0, 24.0) * m)):
		_draw_deck(z)
	# the hulls
	for id in hulls:
		var hd: Dictionary = hulls[id]
		var k := minf(1.0, float(hd.t) / APPROACH_S)
		var ease := 1.0 - pow(1.0 - k, 3.0)
		var off := Vector2((1.0 - ease) * 700.0, 0.0)
		var s := _ship(id)
		_hull(_px(hd.centre + off) - global_position, float(hd.len), int(hd.slot), s, k < 1.0, false, z)
	for id in leaving:
		var lv: Dictionary = leaving[id]
		var k2 := float(lv.t) / LEAVE_S
		var off2 := Vector2(k2 * k2 * 700.0, -k2 * 40.0)
		_hull(_px(lv.at + off2) - global_position, float(lv.len), int(lv.slot), {}, true, true, z)
	# the queue off the pier (Q23)
	var qi := 0
	for s in Shipping.live():
		if str(s.state) != "queued":
			continue
		var at := Vector2(_deck_x1() + 40.0 + qi * 70.0, DECK_Y - 40.0)
		_hull(_px(at) - global_position, float(s.length), 0, s, false, false, z)
		if z >= 0.08:
			_label(_px(at + Vector2(-float(s.length) * 0.5, -hull_h(float(s.length)) * 0.5 - 2.0)) - global_position, Shipping.w("排队等船位 · %s", "WAITING FOR A BERTH · %s") % str(s.id), Pal.heat(0.8, 1.2), z)
		qi += 1


func _draw_deck(z: float) -> void:
	var m := Geom.M
	var lw := 1.0 / z
	# the crane's gantry over the deck once the cargo district stands
	if Port.stage("cargo") >= 1:
		var g0 := _px(Vector2(DECK_X0, DECK_Y)) - global_position
		var g1 := _px(Vector2(_deck_x1(), DECK_Y)) - global_position
		draw_line(g0, g1, Pal.heat(0.35, 1.0), 2.0 * lw)
		if not crane.is_empty() and bodies.has(crane.key) and is_instance_valid(bodies[crane.key]):
			var bp: Vector2 = bodies[crane.key].global_position - global_position
			var tp := Vector2(bp.x, g0.y)
			draw_rect(Rect2(tp - Vector2(0.8, 0.4) * m, Vector2(1.6, 0.8) * m), Pal.heat(0.8, 1.3))
			draw_line(tp, bp, Pal.ink(0.7), lw * 1.5)


func _draw_deck_static() -> void:
	if not active() or yard == null:
		return
	_deck_pen = CanvasBatch.new(deck_layer)
	var z: float = maxf(game.cam_zoom(), 0.02)
	var m := Geom.M
	var lw := 1.0 / z
	var ink := Pal.ink(0.5)
	# the deck: a girder walkway with bollards
	var d0 := _px(Vector2(DECK_X0, DECK_Y - DECK_HALF)) - global_position
	var d1 := _px(Vector2(_deck_x1(), DECK_Y + DECK_HALF)) - global_position
	_deck_pen.draw_rect(Rect2(d0, d1 - d0), Color(0.04, 0.045, 0.05))
	_deck_pen.draw_rect(Rect2(d0, d1 - d0), ink, false, 1.5 * lw)
	var x := DECK_X0 + 2.0
	while x < _deck_x1():
		var a := _px(Vector2(x, DECK_Y - DECK_HALF)) - global_position
		_deck_pen.draw_line(a, a + Vector2(0, DECK_HALF * 2.0 * m), Pal.ink(0.12), lw)
		x += 3.0
	# the apron and the loading table
	for r in [Rect2(Vector2(8.6, DECK_Y + DECK_HALF + 0.2), Vector2(19.6, 6.0)), Rect2(Vector2(8.6, DECK_Y - DECK_HALF - 6.2), Vector2(19.6, 6.0))]:
		var pr := Rect2(_px(r.position) - global_position, r.size * m)
		_deck_pen.draw_rect(pr, Color(0.035, 0.04, 0.045))
		_deck_pen.draw_rect(pr, Pal.ink(0.3), false, lw)
		var hx := pr.position.x
		while hx < pr.end.x - 0.6 * m:
			_deck_pen.draw_line(Vector2(hx, pr.end.y - 0.3 * m), Vector2(hx + 0.6 * m, pr.end.y), Pal.heat(0.3, 1.0), lw)
			hx += 1.6 * m
	if z >= 0.12:
		_deck_label(_px(Vector2(9.0, DECK_Y + DECK_HALF + 6.9)) - global_position, Shipping.w("卸货平台 · 待入库", "UNLOADING APRON · NOT YET STOCK"), Pal.ink(0.6), z)
		_deck_label(_px(Vector2(9.0, DECK_Y - DECK_HALF - 6.6)) - global_position, Shipping.w("出货台", "LOADING TABLE"), Pal.ink(0.6), z)
		# 46 号: the pier says what it is
		_deck_label(_px(Vector2(30.0, DECK_Y - DECK_HALF - 1.2)) - global_position, Shipping.w("货运码头 · 栈桥", "CARGO PIER"), Pal.tint(Pal.AIR, 0.7, 1.2), z)
	# the berths
	for k in Shipping.slots():
		var bx := _px(Vector2(SLOT_X + SLOT_PITCH * k, DECK_Y + DECK_HALF)) - global_position
		_deck_pen.draw_line(bx, bx + Vector2(80.0 * m, 0), Pal.tint(Pal.AIR, 0.35, 1.2), 2.0 * lw)
		if z >= 0.12:
			_deck_label(bx + Vector2(0, 1.6 * m), Shipping.w("%d 号船位", "BERTH %d") % (k + 1), Pal.tint(Pal.AIR, 0.7, 1.2), z)
	_deck_pen.flush()
	_deck_pen = null


func _ship(id: String) -> Dictionary:
	for s in Shipping.data().ships:
		if str(s.id) == id:
			return s
	return {}


# a freighter: drive section aft (west, its back to the station), the hold amidships, the
# bridge forward; running lights, and the drive burning while it brakes or leaves
func _hull(c: Vector2, length: float, slot: int, s: Dictionary, burning: bool, outbound: bool, z: float) -> void:
	var m := Geom.M
	var h := hull_h(length)
	if not ViewCull.sees(game, Rect2(c + global_position - Vector2(length * 0.5 + 12.0, h * 0.5 + 5.0) * m, Vector2(length + 24.0, h + 10.0) * m)):
		return
	var lw := 1.0 / z
	var hull := Rect2(c - Vector2(length, h) * 0.5 * m, Vector2(length, h) * m)
	var col := Color(0.075, 0.08, 0.09)
	var poly := PackedVector2Array([hull.position + Vector2(0, h * 0.18 * m), hull.position + Vector2(length * 0.08 * m, 0), Vector2(hull.end.x - length * 0.12 * m, hull.position.y),
		Vector2(hull.end.x, c.y), Vector2(hull.end.x - length * 0.12 * m, hull.end.y), Vector2(hull.position.x + length * 0.08 * m, hull.end.y), Vector2(hull.position.x, hull.end.y - h * 0.18 * m)])
	draw_colored_polygon(poly, col)
	poly.append(poly[0])
	draw_polyline(poly, Pal.ink(0.55), 1.5 * lw)
	# the hold, open to the deck, and its doors folded back
	var hr := Rect2(c - Vector2(length * 0.45, h * 0.62) * 0.5 * m, Vector2(length * 0.45, h * 0.62) * m)
	var face := 1.0
	hr.position.y = c.y + face * h * 0.5 * m - hr.size.y
	draw_rect(hr, Color(0.02, 0.022, 0.026))
	draw_rect(hr, Pal.ink(0.35), false, lw)
	var lip := c.y + face * h * 0.5 * m
	draw_line(Vector2(hr.position.x, lip), Vector2(hr.position.x - 4.0 * m, lip + face * 2.0 * m), Pal.ink(0.5), 1.5 * lw)
	draw_line(Vector2(hr.end.x, lip), Vector2(hr.end.x + 4.0 * m, lip + face * 2.0 * m), Pal.ink(0.5), 1.5 * lw)
	# frames
	var fx := hull.position.x + length * 0.1 * m
	while fx < hull.end.x - length * 0.12 * m:
		draw_line(Vector2(fx, hull.position.y + 0.3 * m), Vector2(fx, hull.end.y - 0.3 * m), Pal.ink(0.1), lw)
		fx += 4.0 * m
	# the bridge forward, the drive bells aft
	draw_rect(Rect2(Vector2(hull.end.x - length * 0.2 * m, c.y - h * 0.3 * m), Vector2(length * 0.07 * m, h * 0.25 * m)), Pal.tint(Pal.AIR, 0.35, 1.2))
	for k in 2:
		var by := c.y + (k - 0.5) * h * 0.45 * m
		var bell := PackedVector2Array([Vector2(hull.position.x, by - 0.8 * m), Vector2(hull.position.x - 3.0 * m, by - 1.6 * m), Vector2(hull.position.x - 3.0 * m, by + 1.6 * m), Vector2(hull.position.x, by + 0.8 * m)])
		draw_colored_polygon(bell, Color(0.1, 0.1, 0.11))
		if burning:
			# braking flies drive-first towards the pier: the plume points the way it came
			var dir := -1.0 if outbound else -1.0
			var plume := PackedVector2Array([Vector2(hull.position.x - 3.0 * m, by - 1.3 * m), Vector2(hull.position.x - 3.0 * m + dir * 14.0 * m, by), Vector2(hull.position.x - 3.0 * m, by + 1.3 * m)])
			draw_colored_polygon(plume, Pal.tint(Pal.AIR, 0.55, 2.2))
	# running lights
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	draw_circle(Vector2(hull.end.x, c.y), 0.35 * m, Pal.heat(blink, 1.6))
	draw_circle(Vector2(hull.position.x, hull.position.y), 0.3 * m, Pal.tint(Pal.AIR, blink, 1.6))
	if not s.is_empty() and z >= 0.1:
		var sta: Array = Orbits.station(int(s.station))
		var line := "%s %s · %s · %s %.2f t" % [str(s.id), str(s.name), Orbits.name_of(sta), Ops.item_name(_key(s)), float(s.quantity)]
		_label(Vector2(hull.position.x, hull.position.y - 1.0 * m), line, Pal.ink(0.85), z)


func _label(at: Vector2, text: String, col: Color, z: float) -> void:
	draw_set_transform(at, 0, Vector2.ONE / z)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	draw_set_transform(Vector2.ZERO)


func _deck_label(at: Vector2, text: String, col: Color, z: float) -> void:
	_deck_pen.draw_set_transform(at, 0, Vector2.ONE / z)
	_deck_pen.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	_deck_pen.draw_set_transform(Vector2.ZERO)
