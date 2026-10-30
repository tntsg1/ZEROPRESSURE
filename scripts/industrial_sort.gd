extends "res://scripts/industrial_heat.gd"
# Cold company preprocessing reuses the proven native courier and the existing
# Scrapline mechanical/parcel model. A separator does not certify steel chemistry.
const Line = preload("res://scripts/scrapline.gd")
var _empty_points: Array = []


# 73 号: the sorting line's feed is not held back for the forklifts
func _wh_key() -> String:
	return ""
func heat() -> Dictionary: return Career.data.get("industrial_sort",{})
func line(): return plant().scrapline if plant() != null else game.dock.scrapline
func _set_line(l) -> void:
	if plant() != null: plant().scrapline = l
	else: game.dock.scrapline = l
func _feed_key() -> String: return Exchange.lot_key("mixed_metal",0)
func site() -> Vector2: return Vector2(_furnace_x()+8.0,_floor()+1.5)*Geom.M
func _transport_mass() -> float:
	return float(heat().outputs[int(heat().output_index)].quantity) if heat().state == "product_transport" else float(heat().quantity)
func _cargo_key() -> String:
	return str(heat().id)+("/RAW" if heat().state in ["raw_transport","raw_return"] else "/"+str(heat().outputs[int(heat().output_index)].suffix))
func _output_at() -> Vector2:
	var magnetic: bool = heat().outputs[int(heat().output_index)].magnetic
	return Vector2(_furnace_x()+(0.7 if magnetic else 5.92),_floor()+(6.08 if magnetic else 6.04))*Geom.M
func _ready() -> void:
	_setup_transport()
	intake.name = "IndustrialSortingIntake"
	intake.global_position = Vector2(_furnace_x(),_floor()+furnace().DY+0.8)*Geom.M
	var batch := heat()
	if batch.is_empty() or not game.in_berth(): return
	if batch.state in ["processing","product_transport","complete"]:
		if not batch.get("line",{}) is Dictionary or not line().restore_company(batch.get("line",{})) or absf(line().company_input-float(batch.quantity)) > Exchange.EPS:
			fault = "分选设备存档校验失败，保留现场与账本"
		elif line().company_id != str(batch.id) or not batch.get("profile",null) is Dictionary or absf(line().company_nonferrous_share-float(batch.profile.get("nonmagnetic_share",-1.0)))>Exchange.EPS: fault = "分选机构与实际来源身份不一致"
		elif batch.state in ["product_transport","complete"] and not line().company_complete(): fault = "产物阶段缺少实际分选出料记录"
		elif batch.state in ["product_transport","complete"] and not _outputs_valid(batch): fault = "分选产物质量或交接记录不一致"
		waiting = fault
		if fault == "" and batch.state == "complete": line().company_mode = false
func _outputs_valid(batch: Dictionary) -> bool:
	if not batch.get("outputs",null) is Array or not batch.get("received",null) is Array or not (batch.get("output_index",null) is int or batch.get("output_index",null) is float): return false
	var index := int(batch.output_index)
	if index < 0 or index > batch.outputs.size() or float(index) != float(batch.output_index): return false
	if batch.state == "complete" and index != batch.outputs.size(): return false
	if batch.state == "product_transport" and index >= batch.outputs.size(): return false
	var expected := _outputs()
	if not _same_outputs(batch.outputs,expected) or batch.received.size() != index: return false
	var released_fe := 0.0
	var released_nf := 0.0
	for i in expected.size():
		var output: Dictionary = expected[i]
		if i < index:
			var identity := str(batch.id)+"/"+str(output.suffix)
			if batch.received[i] != identity: return false
			var actor: Dictionary = Career.data.get("exchange",{}).get("actors",{}).get("company",{})
			var lot: Dictionary = actor.get("lots",{}).get(identity,{})
			var source: Dictionary = Career.data.exchange.get("sources",{}).get(identity,{})
			if lot.get("key","") != Exchange.lot_key(str(output.item),0) or absf(float(lot.get("total",-1.0))-float(output.quantity))>Exchange.EPS: return false
			if source.get("item","") != output.item or int(source.get("grade",-1)) != 0 or absf(float(source.get("quantity",-1.0))-float(output.quantity))>Exchange.EPS: return false
			var material: Array = Career.data.get("material_batches",[]).filter(func(row):return row.get("id","") == identity)
			if material.size() != 1 or material[0].get("sort_id","") != batch.id or material[0].get("material","") != output.item or absf(float(material[0].get("mass_t",-1.0))-float(output.quantity))>Exchange.EPS: return false
		if i < index or (i == index and batch.state == "product_transport" and batch.transport.get("claimed",false)):
			if output.magnetic: released_fe += float(output.quantity)
			else: released_nf += float(output.quantity)
	return absf(line().company_released_fe-released_fe)<Exchange.EPS and absf(line().company_released_nf-released_nf)<Exchange.EPS
# 42 号: a save keeps 15 significant digits, so tonnes worked out again from the saved share
# differ in the last bit; same goods, same way, same tonnes to 1e-9 is the same record
const SAME := 1e-9
func _same_outputs(saved: Array, expected: Array) -> bool:
	if saved.size() != expected.size(): return false
	for i in saved.size():
		var a = saved[i]
		var b: Dictionary = expected[i]
		if not a is Dictionary or str(a.get("item","")) != str(b.item) or bool(a.get("magnetic",false)) != bool(b.magnetic) or str(a.get("suffix","")) != str(b.suffix): return false
		if absf(float(a.get("quantity",-1.0))-float(b.quantity)) > SAME: return false
	return true
func _same_profile(a, b) -> bool:
	if not a is Dictionary or not b is Dictionary or a.keys().size() != b.keys().size(): return false
	for k in a:
		if not b.has(k): return false
		if (a[k] is float or a[k] is int) and (b[k] is float or b[k] is int):
			if absf(float(a[k])-float(b[k])) > SAME: return false
		elif a[k] != b[k]: return false
	return true
func _outputs() -> Array:
	var result: Array = []
	var nf: float = line().company_input*line().company_nonferrous_share
	for entry in [{"item":"ferrous_scrap","magnetic":true,"quantity":line().company_input-nf,"suffix":"FE"},{"item":"nonferrous_mix","magnetic":false,"quantity":nf,"suffix":"NF"}]:
		if float(entry.quantity) > Exchange.EPS: result.append(entry)
	return result
const XRF_S := 30.0           # s: the in-line assay's reading
# 37 号 (player 2026-10-25: "sorted, back to the warehouse, assayed, out of the warehouse again —
# that is daft"): the through line — feed in, sorted, the ferrous read by the in-line assay on its way
# and straight into the arc furnace, which strikes its arcs by itself; only the nonferrous mix (and
# ferrous that fails its reading) goes back to the warehouse
func begin(quantity: float, through: bool = false) -> Dictionary:
	if fault != "": return {"ok":false,"reason":fault}
	if through:
		var hs = game.industrial_heat
		var old: Dictionary = hs.historical_debt()
		if not old.ok or float(old.total) > 0.000001 or float(hs.heat().get("energy_debt",0.0)) > 0.000001: return {"ok":false,"reason":"请先结清炉子的待缴电费"}
		if hs.furnace().phase in ["tilt","pour","back"]: return {"ok":false,"reason":"等电弧炉出完这一炉"}
		if quantity < 0.3: return {"ok":false,"reason":"整线加工至少 0.3 t"}
	if not near() or (plant() == null and not Career.active().is_empty()) or Career.production_busy(): return {"ok":false,"reason":"请到分选操作台开始批次，等设备空闲"}
	if Port.stage("process") < 1: return {"ok":false,"reason":"请先恢复加工区"}
	if float(heat().get("energy_debt",0.0)) > Exchange.EPS: return {"ok":false,"reason":"请先结清分选电费"}
	if not is_finite(quantity) or quantity < 0.25 or quantity > 2.0: return {"ok":false,"reason":"分选批次范围 0.25–2 t"}
	if line().in_process_mass() > Exchange.EPS or line().company_fe+line().company_nf > Exchange.EPS: return {"ok":false,"reason":"等待旧料或已分选货物离开设备"}
	if plant() == null and (not game.dock.conveying.is_empty() or game.dock.swallowing.any(func(entry):return Dock.kind(str(entry[1])) == "metal")): return {"ok":false,"reason":"等待旧金属完成输送与交接"}
	var viewed := Exchange.command("view")
	if not viewed.ok: return viewed
	var before := Career.data
	Career.data = before.duplicate(true)
	var state: Dictionary = Career.data.exchange
	var actor: Dictionary = state.actors.company
	if float(actor.stock.get(_feed_key(),0.0)) < quantity:
		Career.data = before
		return {"ok":false,"reason":"仓库未分选金属不足，待运货物不可投料"}
	var slices := Exchange._reserve_lots(actor,_feed_key(),quantity,true)
	var profile := Exchange.source_profile(actor,slices,quantity)
	if slices.is_empty() or not profile.ok:
		Career.data = before
		return {"ok":false,"reason":"这批旧料缺少实际材料描述，不能用默认配方冒充检验；库存仍保留"}
	actor.stock[_feed_key()] = float(actor.stock[_feed_key()])-quantity
	if not heat().is_empty():
		var history: Array = Career.data.get("sorting_history",[])
		if not history.any(func(entry):return entry.id == heat().id): history.append(heat().duplicate(true))
		Career.data.sorting_history = history
	var identity := Exchange._id(state,"SORT")
	Career.data.industrial_sort = {"id":identity,"state":"raw_transport","quantity":quantity,"source_lots":slices,"profile":profile.profile,"line":{},"outputs":[],"output_index":0,"received":[],"transport":{},"energy_meter_j":0.0,"energy_cost":0.0,"energy_debt":0.0,"drill":Drill.active(),"through":through}
	Exchange.sync_batches(Career.data,state)
	if not Career.save():
		Career.data = before
		return {"ok":false,"reason":"保存失败，分选未启动"}
	waiting = ""
	return {"ok":true}
func command(action: String,_value: float = 0.0) -> Dictionary:
	if fault != "": return {"ok":false,"reason":fault}
	if not near() or heat().get("state","") != "processing": return {"ok":false,"reason":"请等待原料到达，再在分选台操作"}
	if action not in ["start","stop"]: return {"ok":false,"reason":"unknown_command"}
	var previous: bool = line().company_powered
	var before := Career.data
	Career.data = before.duplicate(true)
	line().company_powered = action == "start" and float(heat().energy_debt) <= Exchange.EPS
	if not checkpoint():
		Career.data = before
		line().company_powered = previous
		return {"ok":false,"reason":"保存失败，驱动指令未提交"}
	return {"ok":true}
func checkpoint() -> bool:
	if fault != "": return false
	if not heat().is_empty() and line().company_mode and line().company_id == heat().id: heat().line = line().company_snapshot()
	return Career.save()
func _prepare_transport() -> bool:
	if heat().state != "product_transport" or heat().transport.get("claimed",false): return true
	var before := Career.data
	var model: Dictionary = line().company_snapshot()
	Career.data = before.duplicate(true)
	var output: Dictionary = heat().outputs[int(heat().output_index)]
	if not line().claim_company(bool(output.magnetic),float(output.quantity)):
		Career.data = before
		waiting = "出料缓冲与搬运质量不一致，保留现场"
		return false
	heat().transport.claimed = true
	if not checkpoint():
		Career.data = before
		line().restore_company(model)
		waiting = "出料交接保存失败，货物停留原位"
		return false
	return true
func _move_empty(dt: float) -> void:
	if _empty_points.is_empty():
		super._move_empty(dt)
		return
	var target: Vector2 = _empty_points[0]
	var delta: Vector2 = (target-robot.global_position).limit_length(_speed()*dt)
	if robot.test_move(robot.global_transform,delta): waiting = "空载搬运机构等待通道"; return
	robot.global_position += delta
	if robot.global_position.distance_to(target) < 0.01: _empty_points.pop_front()
	robot.queue_redraw()
# the through line's ferrous output: past the assay bench and into the furnace's mouth
func _through_now() -> bool:
	var b := heat()
	return b.get("through",false) and str(b.get("state","")) == "product_transport" and int(b.output_index) < b.outputs.size() and bool(b.outputs[int(b.output_index)].magnetic)
func _path() -> Array:
	if _through_now():
		var xrf := Vector2(game.industrial_assay.site().x,intake.global_position.y)
		return [xrf,intake.global_position]
	return super._path()
func _lane_wait() -> bool: return not _through_now()
func _hold(index: int,dt: float) -> bool:
	if not _through_now() or index != 1: return false
	var t := float(heat().transport.get("xrf",0.0))
	if t >= XRF_S: return false
	heat().transport.xrf = t+dt
	waiting = "线上化验：读数中 %d / %d s" % [int(t),int(XRF_S)]
	if t+dt >= XRF_S: waiting = ""
	return true
func _receive() -> bool:
	if fault != "": return false
	var batch := heat()
	var raw: bool = batch.state == "raw_transport"
	var returned: bool = batch.state == "raw_return"
	var through := _through_now()
	_through_model = {}
	if not _inside(intake if raw or through else game.exchange_logistics.warehouse): return false
	if body.pieces.size() != 1 or body.pieces[0].key != _cargo_key() or absf(body.total_mass()-_transport_mass()) > Exchange.EPS: return false
	var before := Career.data
	Career.data = before.duplicate(true)
	batch = heat()
	var state: Dictionary = Career.data.exchange
	var actor: Dictionary = state.actors.company
	var candidate = null
	if raw:
		if not _sources_valid(actor,batch.source_lots,float(batch.quantity)):
			Career.data = before
			return false
		var profile := Exchange.source_profile(actor,batch.source_lots,float(batch.quantity))
		if not profile.ok or not _same_profile(profile.profile,batch.profile):
			Career.data = before
			return false
		candidate = Line.new()
		candidate.X = _furnace_x()
		for field in Line.COMPANY_FIELDS:
			var value = line().get(field)
			candidate.set(field,value.duplicate(true) if value is Array or value is Dictionary else value)
		var polys: Array = []
		for piece in body.pieces:
			var polygon := PackedVector2Array()
			for point in piece.poly: polygon.append(point/Geom.M)
			polys.append(polygon)
		if not candidate.begin_company(str(batch.id),polys,float(batch.quantity),float(batch.profile.nonmagnetic_share),str(batch.id).hash()):
			Career.data = before
			return false
		for slice in batch.source_lots:
			actor.lots[str(slice.source_id)].consumed = float(actor.lots[str(slice.source_id)].get("consumed",0.0))+float(slice.quantity)
		batch.state = "processing"
		batch.line = candidate.company_snapshot()
	elif returned:
		if not _return_sources_valid(actor,batch.source_lots,float(batch.quantity)):
			Career.data = before
			return false
		for slice in batch.source_lots: actor.lots[str(slice.source_id)].available = float(actor.lots[str(slice.source_id)].available)+float(slice.quantity)
		actor.stock[_feed_key()] = float(actor.stock.get(_feed_key(),0.0))+float(batch.quantity)
		batch.state = "cancelled"
	else:
		if not batch.transport.get("claimed",false) or not line().company_complete() or float(batch.energy_debt) > Exchange.EPS:
			Career.data = before
			return false
		var output: Dictionary = batch.outputs[int(batch.output_index)]
		var identity := str(batch.id)+"/"+str(output.suffix)
		if actor.lots.has(identity):
			Career.data = before
			return false
		var key := Exchange.lot_key(str(output.item),0)
		actor.lots[identity] = {"id":identity,"key":key,"available":float(output.quantity),"total":float(output.quantity),"origin":"magnetic_separation","parents":batch.source_lots.duplicate(true),"material_profile":{"version":1,"nonmagnetic_share":0.0 if output.magnetic else 1.0,"basis":"magnetic_separation_unassayed"}}
		actor.stock[key] = float(actor.stock.get(key,0.0))+float(output.quantity)
		state.sources[identity] = {"quantity":float(output.quantity),"item":str(output.item),"grade":0}
		Career.data.material_batches.append({"id":identity,"mass_t":float(output.quantity),"material":str(output.item),"grade":0,"state":"raw_received","storage":"exchange","sort_id":str(batch.id),"quality":{"method":"magnetic_separation","chemical_assay":false}})
		batch.received.append(identity)
		if through and not _charge_through(actor,state,identity,float(output.quantity),key):
			Career.data = before
			return false
		batch.output_index = int(batch.output_index)+1
		if int(batch.output_index) >= batch.outputs.size(): batch.state = "complete"
	batch.transport = {}
	Exchange.sync_batches(Career.data,state)
	state.revision = int(state.revision)+1
	if not Career.save():
		Career.data = before
		if through and not _through_model.is_empty(): game.industrial_heat.furnace().restore_manual(_through_model)
		waiting = "保存失败，分选交接未提交"
		return false
	if candidate != null: _set_line(candidate)
	if batch.state in ["complete","cancelled"]:
		game.exchange_logistics.production_lane = false
		if batch.state == "complete": line().company_mode = false
	game.world.remove_body(body)
	body = null
	robot.visible = false
	robot.collision_layer = 0
	if batch.state == "product_transport":
		_empty_points = _path().duplicate()
		_empty_points.reverse()
		_empty_points.append(_output_at())
		for i in _empty_points.size(): _empty_points[i] += GRIP
	waiting = ""
	return true
func _process(dt: float) -> void:
	if game.is_queued_for_deletion() or fault != "" or not game.in_berth() or game.state != "play" or game.menu_open or game.paused_sim: return
	_materialize_disposals()
	intake.global_position = Vector2(_furnace_x(),_floor()+furnace().DY+0.8)*Geom.M
	var batch := heat()
	if batch.is_empty(): return
	# Remove a stale field body only against this same batch's durable receiver
	# record. A failed batch never silently deletes its remaining geometry.
	if batch.state != "written_off":
		var retired: Array = batch.get("received",[]).duplicate()
		if batch.state not in ["raw_transport","raw_return"]: retired.append(str(batch.id)+"/RAW")
		for identity in retired:
			var piece = game.world.key_piece(str(identity))
			if piece != null and piece.body != null and piece.body != body: game.world.remove_body(piece.body)
	var terminal: bool = batch.state in ["complete","cancelled","written_off"]
	if not terminal: game.exchange_logistics.production_lane = batch.state in ["product_transport","raw_return"] or (batch.state == "raw_transport" and int(batch.transport.get("waypoint",0)) < 2)
	elif Career.data.get("industrial_heat",{}).get("state","complete") in ["complete","cancelled","written_off"]: game.exchange_logistics.production_lane = false
	# Drive meter is model-owned, money is company-owned. Empty transports and
	# cold stop consume no unrecorded process energy; no heat or metal is created.
	if batch.state in ["processing","product_transport"]:
		var meter: float = line().company_energy_j
		var charge := maxf(0.0,meter-float(batch.energy_meter_j))/3.6e9*_power_price()
		batch.energy_meter_j = meter
		batch.energy_cost = float(batch.energy_cost)+charge
		batch.energy_debt = float(batch.energy_debt)+charge
	var payment := minf(maxf(0.0,float(Career.data.money)),float(batch.energy_debt))
	Career.data.money = float(Career.data.money)-payment
	batch.energy_debt = maxf(0.0,float(batch.energy_debt)-payment)
	Career.data.exchange.actors.company.cash = float(Career.data.money)
	if float(batch.energy_debt) > Exchange.EPS:
		line().company_powered = false
		waiting = "分选电费余额不足，驱动已停止；补足资金后可现场重启"
	elif waiting == "分选电费余额不足，驱动已停止；补足资金后可现场重启": waiting = ""
	# the through line starts its own drives when the feed is in
	if batch.get("through",false) and batch.state == "processing" and not batch.get("drive_on",false) and not line().company_powered and float(batch.energy_debt) <= Exchange.EPS:
		if command("start").ok:
			heat().drive_on = true
			batch = heat()
	if batch.state == "processing" and line().company_complete():
		line().company_powered = false
		batch.outputs = _outputs()
		batch.output_index = 0
		batch.state = "product_transport"
		batch.transport = {}
		checkpoint()
	if line().company_mode and not terminal: batch.line = line().company_snapshot()
	_checkpoint += dt
	if _checkpoint > 5.0:
		_checkpoint = 0.0
		checkpoint()
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "process", 30.0):
		queue_redraw()
# the in-line reading and the furnace's new heat, in the same commit as the receipt: the sorted
# ferrous lot is read (its record says how much nonmagnetic is left in it), made grade 1, and
# charged as a heat of its own; a failed reading leaves it unrated in stock (it is the warehouse's)
func _charge_through(actor: Dictionary,state: Dictionary,identity: String,q: float,key0: String) -> bool:
	var Assay = preload("res://scripts/industrial_assay.gd")
	var hs = game.industrial_heat
	var lot: Dictionary = actor.lots[identity]
	var share := float(lot.material_profile.get("nonmagnetic_share",0.0))
	var impurity := 0.006+0.1*share
	var cert := {"assay":"XRF-"+identity,"fe":1.0-impurity-Assay.CARBON,"impurity":impurity,"share":share,"limit":Assay.LIMIT,"pass":impurity <= Assay.LIMIT,"method":"inline_xrf"}
	lot.assay = cert
	if not cert.pass: return true
	var a1 := identity+"/A1"
	var key1 := Exchange.lot_key("ferrous_scrap",1)
	lot.consumed = float(lot.get("consumed",0.0))+q
	lot.available = maxf(0.0,float(lot.available)-q)
	actor.stock[key0] = maxf(0.0,float(actor.stock.get(key0,0.0))-q)
	actor.lots[a1] = {"id":a1,"key":key1,"available":0.0,"total":q,"consumed":q,"origin":"assay","parents":[{"source_id":identity,"quantity":q}],"assay":cert}
	state.sources[a1] = {"quantity":q,"item":"ferrous_scrap","grade":1}
	Career.data.material_batches.append({"id":a1,"material":"ferrous_scrap","grade":1,"mass_t":q,"state":"assayed","assay_id":str(cert.assay),"parent":identity})
	# the furnace takes it: a heat of its own, already charged
	var previous_heat: Dictionary = Career.data.get("industrial_heat",{})
	for historic in Career.data.get("industrial_history",[]):
		if str(historic.get("id","")) == str(previous_heat.get("id","")):
			historic.energy_debt = float(previous_heat.get("energy_debt",0.0))
			historic.energy_cost = float(previous_heat.get("energy_cost",0.0))
	var f = hs.furnace()
	_through_model = f.manual_snapshot()
	if f.manual:
		if not f.next_manual_batch(): return false
	else: f.begin_manual()
	if not f.manual_charge(q):
		f.restore_manual(_through_model)
		return false
	Career.data.industrial_heat = {"id":Exchange._id(state,"HEAT"),"state":"processing","quantity":q,"source_lots":[{"source_id":a1,"quantity":q}],"furnace":f.manual_snapshot(),"transport":{},"electric_paid_j":float(f.electrical_j),"energy_cost":0.0,"created":float(state.clock),"drill":heat().get("drill",false),"through":true}
	return true
var _through_model := {}
func write_off() -> Dictionary:
	if fault != "" or not near() or heat().get("state","") not in ["raw_transport","raw_return","product_transport"]: return {"ok":false,"reason":"只能在分选台报损已发运货物"}
	if not _issued.get(_cargo_key(),false) and not heat().transport.has("at"): return {"ok":false,"reason":"未发运原料可直接撤回；产物尚在设备内，不可凭空报损"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var batch := heat()
	var model = null
	var disposals: Array = []
	if batch.state in ["raw_transport","raw_return"]:
		if not _sources_valid(Career.data.exchange.actors.company,batch.source_lots,float(batch.quantity)):
			Career.data = before
			return {"ok":false,"reason":"损失来源记录不一致"}
		for slice in batch.source_lots:
			var lot: Dictionary = Career.data.exchange.actors.company.lots[str(slice.source_id)]
			lot.consumed = float(lot.get("consumed",0.0))+float(slice.quantity)
	var loss := float(batch.quantity)
	if batch.state == "product_transport":
		loss = 0.0
		for i in range(int(batch.output_index),batch.outputs.size()): loss += float(batch.outputs[i].quantity)
		model = Line.new()
		if not model.restore_company(line().company_snapshot()):
			Career.data = before
			return {"ok":false,"reason":"分选缓冲记录无效，保留现场"}
		for output in batch.outputs:
			var held: float = model.company_fe if output.magnetic else model.company_nf
			if held <= Exchange.EPS: continue
			var at := Vector2(_furnace_x()+(0.7 if output.magnetic else 5.92),_floor()+(6.08 if output.magnetic else 6.04))*Geom.M
			if not Loads.clear_spawn(get_world_2d().direct_space_state,at,Vector2.ONE*Geom.M*sqrt(held)) or not model.claim_company(bool(output.magnetic),held):
				Career.data = before
				return {"ok":false,"reason":"请先清空弃料出口，缓冲内实物尚未弃置"}
			disposals.append({"id":str(batch.id)+"/WASTE/"+str(output.suffix),"quantity":held,"at":[at.x,at.y],"materialized":false})
		batch.line = model.company_snapshot()
	var records: Array = Career.data.get("sorting_disposals",[])
	records.append_array(disposals)
	Career.data.sorting_disposals = records
	batch.state = "written_off"
	batch.loss = {"mass_t":loss,"refund":0.0,"reason":"operator_write_off"}
	Exchange.sync_batches(Career.data,Career.data.exchange)
	if not Career.save():
		Career.data = before
		return {"ok":false,"reason":"保存失败，未报损"}
	if model != null: _set_line(model)
	for piece in game.world.pieces.values():
		if not piece.gone and piece.key.begins_with(str(batch.id)+"/") and piece.body != null:
			piece.body.capture = null
			piece.body.freeze = false
	# Remaining in-machine coproducts become native unpaid waste at their actual
	# outlets. Loss is explicit; no refund/product credit/instant deletion.
	line().company_powered = false
	line().company_mode = false
	_materialize_disposals()
	body = null
	robot.visible = false
	robot.collision_layer = 0
	game.exchange_logistics.production_lane = false
	return {"ok":true}
func _materialize_disposals() -> void:
	var records: Array = Career.data.get("sorting_disposals",[])
	for index in records.size():
		var record: Dictionary = Career.data.sorting_disposals[index]
		if record.get("issued",record.get("materialized",false)): continue
		var piece = game.world.key_piece(str(record.id))
		var fragments: Array = game.world.pieces.values().filter(func(entry):return not entry.gone and entry.key.begins_with(str(record.id)+"~"))
		if not fragments.is_empty():
			waiting = "待交接弃料已有切割碎片，未生成整批替代货物"
			continue
		if piece != null and (piece.body == null or piece.body.pieces.size() != 1 or absf(piece.body.total_mass()-float(record.quantity))>Exchange.EPS):
			waiting = "弃料现场与待交接质量不符，未生成替代货物"
			continue
		var at := Vector2(float(record.at[0]),float(record.at[1]))
		var side := Geom.M*sqrt(float(record.quantity))
		if piece == null and not Loads.clear_spawn(get_world_2d().direct_space_state,at,Vector2.ONE*side): continue
		# Persist the one-time generation authorization BEFORE exposing native
		# waste. A failed write generates nothing. Issued lost/destroyed waste is
		# already a declared loss, never an entitlement to replacement material.
		var before := Career.data
		Career.data = before.duplicate(true)
		record = Career.data.sorting_disposals[index]
		record.issued = true
		if not Career.save():
			Career.data = before
			waiting = "弃料交接保存失败，未生成新实体"
			continue
		if piece == null:
			piece = game.world.add_piece("cargo",Geom.rect_poly(Rect2(at-Vector2.ONE*side*0.5,Vector2.ONE*side)),{"key":str(record.id),"mass":float(record.quantity),"scope":false,"value":0.0,"cls":"equip","label":"报损弃料"})
			game.world.make_body([piece],null)
func _draw_desk(ci: CanvasItem) -> void:
	if not game.in_berth(): return
	# 105 号: a sorting desk (scripts/console_art.gd): its batch and the line
	var at := site()
	var b := heat()
	var info := {"lines": [[Ops.batch_state(b), Pal.tint(Pal.AIR, 0.95, 1.2)], [("%.1f t" % float(b.get("quantity", 0.0))) if not b.is_empty() else Ops.w("没有批次", "NO BATCH"), Pal.ink(0.75)],
		[Ops.w("分选线运行", "LINE RUNNING") if line() != null and bool(line().company_powered) else Ops.w("分选线停", "LINE STOPPED"), Pal.ink(0.6)]],
		"lamp": "work" if str(b.get("state", "")) == "processing" else "ok"}
	ConsoleArt.draw(ci, at, ConsoleArt.foot_at(at), Ops.w("分选台", "SORTING DESK"), Ops.w("[%s] 分选操作", "[%s] SORTING CONTROLS") % Keys.label("use"), near(), info, Time.get_ticks_msec() * 0.001, "sort")
