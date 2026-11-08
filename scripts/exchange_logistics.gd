extends Node2D
# First ordinary local-cargo service. These merchants' opening inventory is
# held at the local trade port; this is not the later orbital shipping system.
# One native carrier, full colliding cargo, actual receiver, then durable payout.
const Exchange = preload("res://scripts/industrial_exchange.gd")
const Loads = preload("res://scripts/load_motion.gd")
const SPEED := 100.0
const RATING := 5.0
const LEFT := Vector2(-180,0)
const RIGHT := Vector2(180,0)
const GRIP := Vector2(0,100)
var game
var robot: CharacterBody2D
var warehouse: Area2D
var client: Area2D
var body: FreeBody
var active := ""
var waiting := ""
var _retry := 0.0
var _reconstruct := true
var _spawned: Dictionary = {}
var production_lane := false # native warehouse lane reserved by the furnace carrier

# Stored in the same atomic field snapshot as the actual bodies. A missing
# body after materialization is a loss/damage state, not permission to mint
# another full consignment. Old fields lacking this manifest remain readable.
func field_state() -> Dictionary:
	return {"version":1,"materialized":_spawned.duplicate()}

func restore_field(state: Dictionary) -> void:
	if int(state.get("version",0)) != 1: return
	var materialized: Variant = state.get("materialized",{})
	if not materialized is Dictionary: return
	for identity in materialized:
		if materialized[identity] == true: _spawned[str(identity)] = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 3
	position = yard_at()
	# Physical walls with an actual opening, not backdrop strokes.
	# the east wall opens onto the freight pier (31 号)
	for rect in [Rect2(-292,-112,12,264),Rect2(280,40,12,112),Rect2(-280,140,560,12),Rect2(-280,-112,220,12),Rect2(60,-112,220,12)]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 4
		wall.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		wall.add_child(shape)
		add_child(wall)
	warehouse = _receiver("Warehouse",LEFT,"warehouse")
	client = _receiver("LocalFreightBerth",RIGHT,"client")
	robot = CharacterBody2D.new()
	robot.collision_layer = 4
	robot.collision_mask = FreeBody.MASK
	var robot_shape := CollisionShape2D.new()
	var robot_box := RectangleShape2D.new()
	robot_box.size = Vector2(48,18)
	robot_shape.shape = robot_box
	robot.add_child(robot_shape)
	robot.position = LEFT+GRIP
	robot.draw.connect(func():
		robot.draw_rect(Rect2(-24,-9,48,18),Color(0.06,0.08,0.09))
		robot.draw_rect(Rect2(-24,-9,48,18),Pal.ink(0.9),false,1.3)
		for x in [-17,17]: robot.draw_circle(Vector2(x,0),4,Pal.tint(Pal.AIR,0.8))
		if is_instance_valid(body):
			var local := robot.to_local(body.global_position)
			robot.draw_line(Vector2.ZERO,local,Pal.ink(0.7),2.0)
			robot.draw_polyline(PackedVector2Array([local+Vector2(-14,-4),local+Vector2(-14,5),local+Vector2(14,5),local+Vector2(14,-4)]),Pal.ink(0.9),2.0))
	add_child(robot)

func _receiver(label: String, at: Vector2, side: String) -> Area2D:
	var area := Area2D.new()
	area.name = label
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 1
	area.set_meta("exchange_receiver",true)
	area.set_meta("exchange_side",side)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = Vector2(140,190)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	return area

func _trade() -> Dictionary:
	for trade in Career.data.get("exchange",{}).get("trades",[]):
		if trade.id == active: return trade
	return {}
func _endpoints(trade: Dictionary) -> Array:
	return [RIGHT,LEFT] if trade.buyer == Exchange.PLAYER else [LEFT,RIGHT]
func _adopt(trade: Dictionary) -> bool:
	# An observed loss is company business state too: leaving the current
	# salvage contract must not turn it back into a fresh full consignment.
	if trade.get("transport",{}).get("issue","") == "cargo_missing": return false
	var piece = game.world.key_piece(str(trade.get("cargo_key","")))
	if piece != null and piece.body != null:
		body = piece.body
	else:
		# Reconstructing a scene is legitimate; replacing destroyed or cut cargo
		# inside a running scene would mint its reserved material a second time.
		if _spawned.has(active): return false
		for prior in game.world.pieces.values():
			if prior.key == str(trade.get("cargo_key","")): return false
		var at := to_global(_endpoints(trade)[0])
		if trade.has("transport") and trade.transport.has("at"):
			at = to_global(Vector2(float(trade.transport.at[0]),float(trade.transport.at[1])))
		# Packing footprint is fixed by quantity, never reduced to fit obstacles.
		var side := Geom.M*sqrt(float(trade.quantity))
		if not Loads.clear_spawn(get_world_2d().direct_space_state,at,Vector2.ONE*side):
			waiting = "cargo_slot_occupied"
			return false
		piece = game.world.add_piece("cargo",Geom.rect_poly(Rect2(at-Vector2.ONE*side*0.5,Vector2.ONE*side)),{"key":str(trade.cargo_key),"cls":"equip","mass":float(trade.quantity),"scope":false,"value":0.0,"label":"FREIGHT"})
		game.world.make_body([piece],null)
		body = piece.body
	if not is_instance_valid(body): return false
	# Cargo belongs to the station, so the current salvage hull's tow-out
	# transform must not drag it away with the scrapped ship.
	if body.get_parent() != self: body.reparent(self,true)
	_spawned[active] = true
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.capture = "exchange"
	body.set_meta("exchange_trade",active)
	body.ghost = 0.0
	body.collision_mask = FreeBody.MASK
	if _reconstruct:
		# Recreate the machine's attached pose, taking the actual field cargo
		# transform as authority when that snapshot is newer than the career.
		robot.global_position = body.global_position+GRIP if trade.state == "in_transit" else to_global(Vector2(float(trade.transport.get("robot",[LEFT.x+GRIP.x,LEFT.y+GRIP.y])[0]),float(trade.transport.get("robot",[LEFT.x+GRIP.x,LEFT.y+GRIP.y])[1])))
		_reconstruct = false
	return true

func _missing(trade: Dictionary) -> void:
	waiting = "cargo_missing"
	trade.transport.issue = "cargo_missing"
	# Retry a failed checkpoint, but never replace material while waiting.
	if not trade.transport.get("issue_saved",false):
		trade.transport.issue_saved = true
		if not Career.save():
			trade.transport.issue_saved = false
			waiting = "save_failed"
		_retry = 1.0

func _start() -> void:
	if production_lane: return
	var state: Dictionary = Career.data.get("exchange",{})
	if state.is_empty(): return
	# Retire only cargo backed by an already durable receipt after a crash window.
	for trade in state.trades:
		if trade.state != "delivered": continue
		var old = game.world.key_piece(str(trade.get("cargo_key","")))
		if old != null and old.body != null: game.world.remove_body(old.body)
	# the belt's merchants ship by freighter (scripts/shipping.gd, 31 号); only the port's own counters come here
	var choices: Array = state.trades.filter(func(trade):return trade.state in ["loading","in_transit","awaiting_dispatch"] and float(trade.quantity) <= RATING and not Shipping.orbital(trade))
	if choices.is_empty(): return
	choices.sort_custom(func(a,b):
		var started_a: bool = a.state != "awaiting_dispatch"
		var started_b: bool = b.state != "awaiting_dispatch"
		if started_a != started_b: return started_a
		var ap: bool = a.buyer == Exchange.PLAYER or a.seller == Exchange.PLAYER
		var bp: bool = b.buyer == Exchange.PLAYER or b.seller == Exchange.PLAYER
		return ap if ap != bp else str(a.id) < str(b.id))
	var chosen: Dictionary = choices[0]
	# 73 号: goods the company sells come down from the racks first
	if chosen.state == "awaiting_dispatch" and Warehouse.ON and chosen.get("seller", "") == Exchange.PLAYER:
		var jid := "TR:" + str(chosen.id)
		Warehouse.ask_out(jid, "%s:%d" % [str(chosen.get("item", "")), int(chosen.get("grade", 0))], float(chosen.get("quantity", 0.0)))
		if not Warehouse.ready(jid):
			waiting = Warehouse.wait_text(jid)
			return
		Warehouse.consume(jid)
	active = str(chosen.id)
	if chosen.state == "awaiting_dispatch":
		var before := Career.data
		Career.data = before.duplicate(true)
		chosen = _trade()
		chosen.cargo_key = "EXCARGO:"+active
		var point: Vector2 = _endpoints(chosen)[0]
		chosen.transport = {"at":[point.x,point.y],"robot":[robot.position.x,robot.position.y],"scope":"local_trade_port"}
		chosen.state = "loading"
		if not Career.save():
			Career.data = before
			active = ""
			waiting = "save_failed"
			_retry = 1.0
			return
	_adopt(chosen)

# the cargo district's yard under its hatch, world px: it moves with the port (方案 A, 2026-11-08: a berth
# grown or shrunk in the scene moves the port over it)
static func yard_at() -> Vector2:
	return Backdrop.port_centre_px()+(PortArt.district_at("cargo")+Vector2(0,PortArt.BOX.y*0.5+9))*PortArt.PM*Geom.M

func _physics_process(dt: float) -> void:
	var ya := yard_at()
	if position.distance_squared_to(ya) > 1.0:
		position = ya
	if game == null or game.state != "play" or game.menu_open or game.paused_sim: return
	_retry = maxf(0.0,_retry-dt)
	if _retry > 0.0: return
	if active == "": _start()
	if active == "": return
	var trade := _trade()
	if trade.is_empty(): return
	if is_instance_valid(body) and (body.pieces.is_empty() or body.pieces.any(func(piece):return piece.gone)):
		body = null
	if not is_instance_valid(body) and not _adopt(trade):
		if waiting == "cargo_slot_occupied": return
		# Relinking a cut may temporarily leave the retained fragment without
		# a body. Damage is not evidence that all material disappeared.
		if game.world.key_piece(str(trade.cargo_key)) != null:
			waiting = "cargo_damaged"
		else: _missing(trade)
		return
	if body.pieces.size() != 1 or str(body.pieces[0].key) != str(trade.cargo_key) or absf(body.total_mass()-float(trade.quantity)) > 0.000001:
		waiting = "cargo_damaged"
		return
	var endpoint: Vector2 = _endpoints(trade)[1]
	var target := body.global_position+GRIP if trade.state == "loading" else to_global(endpoint)+GRIP
	var delta := (target-robot.global_position).limit_length(SPEED*dt)
	if delta.length_squared() > 0.00001:
		if robot.test_move(robot.global_transform,delta):
			waiting = "carrier_obstructed"
			return
		if trade.state == "in_transit" and not Loads.move(body,delta):
			waiting = "cargo_obstructed"
			return
		robot.global_position += delta
		waiting = ""
	trade.transport.robot = [robot.position.x,robot.position.y]
	var local := to_local(body.global_position)
	trade.transport.at = [local.x,local.y]
	if trade.state == "loading" and robot.global_position.distance_to(body.global_position+GRIP) < 0.01:
		trade.state = "in_transit"
	if trade.state == "in_transit" and body.global_position.distance_to(to_global(endpoint)) < 0.01:
		var receiver := warehouse if trade.buyer == Exchange.PLAYER else client
		var result := Exchange.confirm_local_receipt(active,body,receiver)
		if result.ok:
			game.world.remove_body(body)
			body = null
			active = ""
			waiting = ""
		else:
			waiting = str(result.reason)
			_retry = 0.1 if waiting == "delivery_geometry" else 1.0
	robot.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var col := Pal.ink(0.6)
	draw_rect(Rect2(-292,-112,584,264),Color(0.025,0.03,0.034))
	draw_rect(Rect2(-292,-112,584,264),col,false,1.5)
	# the gate onto the freight pier
	draw_line(Vector2(286,-110),Vector2(286,38),Color(0.025,0.03,0.034),8.0)
	for gy in [-112,40]: draw_line(Vector2(280,gy),Vector2(300,gy),Pal.tint(Pal.AIR,0.7,1.3),3.0)
	for x in range(-260,281,40):
		draw_line(Vector2(x,122),Vector2(x+20,122),col,2)
	for at in [LEFT,RIGHT]:
		draw_rect(Rect2(at-Vector2(70,95),Vector2(140,190)),Pal.tint(Pal.AIR,0.4),false,1.0)
		for y in [-76,76]: draw_line(at+Vector2(-48,y),at+Vector2(48,y),col,1.0)
	var font := Fonts.get_font("Medium")
	draw_string(font,Vector2(-260,-130),"CARGO / LOCAL FREIGHT",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Pal.ink(0.9))
	draw_string(font,LEFT+Vector2(-60,-55),"WAREHOUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,col)
	draw_string(font,RIGHT+Vector2(-60,-55),"TRANSFER",HORIZONTAL_ALIGNMENT_LEFT,-1,12,col)
	if waiting != "":
		var notices := {
			"cargo_slot_occupied":["等待空闲装卸位","Waiting for a free cargo berth"],
			"cargo_missing":["货物缺失，等待现场处理","Cargo missing; inspection required"],
			"cargo_damaged":["货物受损，等待重新验收","Cargo damaged; inspection required"],
			"carrier_obstructed":["搬运机构受阻，请清理通道","Carrier blocked; clear the lane"],
			"cargo_obstructed":["货物通道受阻，请检查现场","Cargo blocked; inspect the lane"],
			"save_failed":["记录保存失败，货物暂存","Save failed; cargo held safely"],
			"delivery_geometry":["正在对位验收","Aligning cargo for inspection"],
		}
		var notice: Array = notices.get(waiting,["装运暂停，请检查货运区","Freight paused; inspect the cargo district"])
		draw_string(font,Vector2(-240,180),str(notice[0 if Txt.zh else 1]),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Pal.heat(0.7))
