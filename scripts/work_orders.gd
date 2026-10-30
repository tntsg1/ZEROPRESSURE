extends RefCounted
# Three authored engineering commissions. Field receipts contain actual recovery
# events. Career.apply_report is called inside the settlement transaction.
const IDS := ["access","rigging","heavy"]
const SPECS := {
	"access":{"name":["开舱作业","OPEN THE HOLD"],"targets":["C-03"],"mount":"","fee":3000.0,"lend":{},
		"goal":["完整回收 C-03 货箱，完整度至少 85%；选择通道，再解除固定。","Recover cargo C-03 intact, at least 85% condition. Choose an exit before releasing its locks."],
		"next":["开放锁索支撑；下一项借用牵引锚与探头，连底板一起取件。","Unlock cable locking. Next: borrow an anchor and probe to recover a mounted section."]},
	"rigging":{"name":["稳住再拆","SECURE BEFORE SEPARATION"],"targets":["C-02"],"mount":"FP-C2","fee":3000.0,"lend":{"anchor":1,"probe":1},
		"goal":["C-02 完整度至少 85%，保持与 FP-C2 底板相连且底板未切碎；整组脱离后稳定 1 秒再送设备口。","Keep C-02 at least 85% intact on uncut floor plate FP-C2. Stabilize the free assembly for one second, then deliver it to equipment recovery."],
		"next":["获得自有牵引锚；下一项可分件搬运，或借吊机整件交付并恢复设施。","Earn an owned anchor. Next: transport separate units or rent a crane for whole-assembly delivery and restore a facility."]},
	"heavy":{"name":["重载交付","HEAVY ENGINEERING DELIVERY"],"targets":["CP-E","RAD"],"mount":"","whole_mount":"K4","fee":4500.0,"lend":{"anchor":1},
		"goal":["CP-E 泵与 RAD 散热器完整度均至少 85%。可分件交给搬运机，或保留 K4 底座用吊机整运。","Deliver pump CP-E and radiator RAD intact, each at least 85% condition. Haul them separately, or keep cradle K4 and lift the whole assembly."],
		"next":["用交付换取一项当前可用的船坞修缮；整件交付免装配费。","Exchange the delivery for a usable berth repair. Whole-assembly delivery waives assembly costs."]}
}
var game
var id := ""
var receipts: Array = []
var previous: Array = []
var sell := false
var stable := false
var stable_time := 0.0
var stable_body := 0
var last_reason := ""

func _init(g) -> void:
	game = g
	id = str(g.job.get("work_order",""))
	previous = Career.data.get("work_orders",{}).get("stock",{}).get(id,[]).duplicate(true)

static func text(id: String, field: String = "name") -> String:
	var s: Dictionary = SPECS.get(id,{})
	var v: Array = s.get(field,["",""])
	return str(v[0] if Txt.zh else v[1])

static func done(id: String) -> bool:
	return Career.data.get("work_orders",{}).get("done",{}).has(id)

static func track(id: String) -> String:
	var before := Career.data
	Career.data = before.duplicate(true)
	var state: Dictionary = Career.data.get("work_orders",{})
	state.tracked = id
	Career.data.work_orders = state
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""

static func reason(id: String) -> String:
	if not SPECS.has(id): return Txt.t("rp_unknown")
	if done(id): return Txt.t("tm_trial_done")
	var n: int = IDS.find(id)
	if n > 0 and not done(IDS[n-1]): return ("先完成：" if Txt.zh else "COMPLETE FIRST: ")+text(IDS[n-1])
	if not Career.active().is_empty(): return Txt.t("trial_busy")
	if Dock.owned(Career.data.get("upgrades",{})) < 48.0: return Txt.t("tm_needs") % "48 m"
	return ""

static func reward_options() -> Array:
	var result: Array = []
	for item in Repair.ITEMS:
		if float(item[3]) > 50000.0 or Repair.done(str(item[0])) or not Port.power_ok(str(item[0])): continue
		var ready := true
		for dep in item[1]:
			if not Repair.done(str(dep)): ready = false
		if ready: result.append(str(item[0]))
	if result.is_empty(): result.append("field_stock")
	elif result.has("buffer"):
		result.erase("buffer")
		result.push_front("buffer")
	return result

static func selected_reward(job: Dictionary) -> String:
	var options := reward_options()
	var selected := str(job.get("order_reward",""))
	return selected if options.has(selected) else str(options[0])

static func take(id: String, reward: String = "", whole: bool = false) -> String:
	var why := reason(id)
	if why != "": return why
	if id == "heavy" and not reward_options().has(reward): return Txt.t("rp_unknown")
	var before := Career.data
	Career.data = before.duplicate(true)
	var data := Career.data
	var orders: Dictionary = data.get("work_orders",{})
	var attempts: Dictionary = orders.get("attempts",{})
	attempts[id] = int(attempts.get(id,0))+1
	orders.attempts = attempts
	orders.tracked = id
	data.work_orders = orders
	var s: Dictionary = SPECS[id]
	var base := Ship.load_data("gr7")
	var job := {"id":"G4-%s-%04d" % [id.to_upper(),attempts[id]],"reg":"GR-7 / ENGINEERING","ship":"gr7","work_order":id,"order_reward":reward,"order_whole":whole,
		"fee":float(s.fee),"fee_paid":true,"borrowed":0.0,"time":1800.0,"stars":1,"scope":"full","goal":"","traps":[],"logs":[],
		"value":float(base.get("value",{}).get("total",0.0)),"named":Market._named(base),"kit":data.get("upgrades",{}).duplicate(),"items":data.get("items",{}).duplicate(),
		"lend":s.lend.duplicate(),"notes":data.get("archive",{}).get("gr7",{}).duplicate(true),"rigging_hold":id != "access"}
	job.kit.hauler = 1 # Contract-provided machinery is returned; never a permanent upgrade.
	if id == "heavy": job.kit.crane = 1
	job.desk = data.get("desk",{}).duplicate()
	data.desk = {}
	var fee: float = s.fee
	var short := maxf(0.0,fee-float(data.money))
	data.money = maxf(0.0,float(data.money)-fee)
	data.loan = float(data.loan)+short
	job.borrowed = short
	if short > 0: data.in_debt = true
	Career.gear_out(job)
	data.active = job
	data.offers = []
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""

func active() -> bool:
	return SPECS.has(id)

func owns(p) -> bool:
	if not active(): return false
	var s: Dictionary = SPECS[id]
	return s.targets.has(p.key) or p.key == str(s.mount) or p.key == str(s.get("whole_mount",""))

func preserve_keys() -> Array:
	if not active(): return []
	var s: Dictionary = SPECS[id]
	var keys: Array = s.targets.duplicate()
	if s.mount != "": keys.append(s.mount)
	if game.job.get("order_whole",false) and s.get("whole_mount","") != "": keys.append(s.whole_mount)
	return keys

func _keys(b) -> Array:
	var keys: Array = []
	for p in b.pieces:
		if not p.gone: keys.append(p.key)
	return keys

func accepts_assembly(b) -> bool:
	if id != "heavy" or not is_instance_valid(b): return false
	var keys := _keys(b)
	if not keys.has("K4") or not _mount_whole(b,"K4"): return false
	for key in SPECS.heavy.targets:
		var valid := false
		for p in b.pieces:
			if not p.gone and p.key == key and p.intact and p.cond >= 0.85: valid = true
		if not valid: return false
	return true

func _mount_whole(b, key: String) -> bool:
	var base := Ship.load_data(game.ship_id)
	for p in b.pieces:
		if p.key != key: continue
		for factory in base.pieces:
			if factory.key != key: continue
			var polygon := PackedVector2Array()
			for q in factory.poly: polygon.append(Vector2(q[0],q[1])*Geom.M)
			return Geom.area(p.poly) >= Geom.area(polygon)*0.98
	return false

func tick(dt: float) -> void:
	if id != "rigging" or stable or game.paused_sim or game.state != "play": return
	for b in game.world.bodies:
		if not is_instance_valid(b) or b.capture != null: continue
		var keys := _keys(b)
		if not keys.has("C-02") or not keys.has("FP-C2"): continue
		if not _mount_whole(b,"FP-C2"): continue
		var instance: int = b.get_instance_id()
		if instance != stable_body:
			stable_body = instance
			stable_time = 0.0
		if b.linear_velocity.length() <= 0.25*Geom.M and absf(b.angular_velocity) <= 0.12:
			stable_time += dt
		else: stable_time = 0.0
		stable = stable_time >= 1.0
		return

func capture(b, zone: String) -> void:
	if not active(): return
	var s: Dictionary = SPECS[id]
	var keys := _keys(b)
	if not s.targets.any(func(key):return keys.has(key)): return
	if zone != "equip":
		_reject("g4_order_wrong_zone")
		return
	if id == "rigging":
		if not keys.has(s.mount) or not _mount_whole(b,str(s.mount)):
			_reject("g4_order_mount")
			return
		if not stable:
			_reject("g4_order_unstable")
			return
	var fresh: Array = []
	var full_module := accepts_assembly(b)
	last_reason = ""
	for key in s.targets:
		if not keys.has(key): continue
		if not full_module and (previous+receipts).any(func(r):return r.keys.has(key)): continue
		for p in b.pieces:
			if p.key == key:
				if p.intact and p.cond >= 0.85: fresh.append(key)
				else: _reject("g4_order_damaged")
	if fresh.is_empty(): return
	var assembled: bool = s.targets.all(func(key):return fresh.has(key))
	if s.mount != "":
		assembled = assembled and keys.has(s.mount) and _mount_whole(b,str(s.mount))
		if not assembled: return
		fresh.append(s.mount)
	if s.get("whole_mount","") != "":
		assembled = assembled and keys.has(s.whole_mount) and _mount_whole(b,str(s.whole_mount))
		if assembled: fresh.append(s.whole_mount)
	var value := 0.0
	for p in b.pieces:
		if fresh.has(p.key): value += game.piece_value(p,zone)
	receipts.append({"keys":fresh,"value":value,"assembled":assembled,"stable":stable,"source":str(game.job.get("id",""))})
	game.say("g4_order_received",game.drone.global_position,", ".join(fresh))

func _reject(reason: String) -> void:
	last_reason = reason
	game.say(reason,game.drone.global_position)

func reserved_value() -> float:
	if sell: return 0.0
	var result := 0.0
	for r in receipts: result += float(r.value)
	return result

func stock_sale_value() -> float:
	if not sell: return 0.0
	var result := 0.0
	for r in previous: result += float(r.value)
	return result

static func assembly_receipt(r: Dictionary) -> bool:
	return r.get("assembled",false) and ["CP-E","RAD","K4"].all(func(key):return r.get("keys",[]).has(key))

static func surplus_from(records: Array) -> float:
	var used := -1
	for i in records.size():
		if assembly_receipt(records[i]): used = i
	if used < 0: return 0.0
	var result := 0.0
	for i in records.size():
		if i != used: result += maxf(0.0,float(records[i].get("value",0.0)))
	return result

func surplus_value() -> float:
	return surplus_from(previous+receipts) if id == "heavy" and not sell else 0.0

func complete() -> bool:
	return not sell and ready_for_engineering()

func ready_for_engineering() -> bool:
	if not active(): return false
	return SPECS[id].targets.all(func(key):return (previous+receipts).any(func(r):return r.keys.has(key)))

func assembly_cost(selling: bool) -> float:
	if selling or id != "heavy" or not ready_for_engineering(): return 0.0
	if (previous+receipts).any(func(r):return assembly_receipt(r)): return 0.0
	var reward := selected_reward(game.job)
	return 0.0 if reward == "field_stock" else float(Repair.find(reward)[3])*0.2

func cash_from_goods(selling: bool) -> float:
	if not selling: return surplus_from(previous+receipts) if id == "heavy" else 0.0
	var result := 0.0
	for r in previous+receipts: result += float(r.value)
	return result

func status_line() -> String:
	if not active(): return ""
	var received := 0
	for key in SPECS[id].targets:
		if (previous+receipts).any(func(r):return r.keys.has(key)): received += 1
	var status := (("待售 %d / %d" if sell else "已预留 %d / %d") if Txt.zh else ("FOR SALE %d / %d" if sell else "RESERVED %d / %d")) % [received,SPECS[id].targets.size()]
	if id == "rigging" and not complete(): status += (" · 已稳定" if stable else " · 待稳定 1 秒") if Txt.zh else (" · STABLE" if stable else " · STABILIZE FOR 1s")
	return status

func report() -> Dictionary:
	return {"id":id,"receipts":receipts.duplicate(true),"sell":sell,"complete":complete(),"reward":str(game.job.get("order_reward","")),"whole":(previous+receipts).any(func(r):return r.get("assembled",false))}

func save_state() -> Dictionary:
	return {"id":id,"receipts":receipts.duplicate(true),"previous":previous.duplicate(true),"sell":sell,"stable":stable,"stable_time":stable_time,"last_reason":last_reason}

func load_state(d: Dictionary) -> void:
	if str(d.get("id","")) != id: return
	receipts = d.get("receipts",[]).duplicate(true)
	previous = d.get("previous",previous).duplicate(true)
	sell = bool(d.get("sell",false))
	stable = bool(d.get("stable",false))
	stable_time = float(d.get("stable_time",0.0))
	last_reason = str(d.get("last_reason",""))

static func apply_report(job: Dictionary, report: Dictionary) -> Dictionary:
	var id := str(job.get("work_order",""))
	if not SPECS.has(id) or report.get("id","") != id or done(id): return {}
	var orders: Dictionary = Career.data.get("work_orders",{}).duplicate(true)
	var stock: Dictionary = orders.get("stock",{})
	var collected: Array = stock.get(id,[]).duplicate(true)
	for r in report.get("receipts",[]):
		if not r is Dictionary or not r.get("keys",null) is Array: continue
		if id == "rigging" and (not r.get("stable",false) or not r.get("assembled",false) or not r.keys.has("FP-C2") or not r.keys.has("C-02")): continue
		collected.append(r.duplicate(true))
	if report.get("sell",false):
		stock[id] = []
		orders.stock = stock
		Career.data.work_orders = orders
		return {"id":id,"sold":true}
	stock[id] = collected
	orders.stock = stock
	Career.data.work_orders = orders
	# All supplied stock must actually cover the named equipment, independently
	# of the field's display flag.
	if not SPECS[id].targets.all(func(key):return collected.any(func(r):return r.keys.has(key))): return {"id":id,"pending":true}
	if id == "rigging" and not collected.any(func(r):return r.get("stable",false) and r.get("assembled",false) and r.keys.has("FP-C2") and r.keys.has("C-02")): return {"id":id,"pending":true}
	var whole: bool = id == "heavy" and collected.any(func(r):return assembly_receipt(r))
	var completed: Dictionary = orders.get("done",{})
	completed[id] = {"job":str(job.get("id","")),"whole":whole}
	orders.done = completed
	orders.stock[id] = []
	var methods: Dictionary = orders.get("methods",{})
	methods.locked_anchor = true
	orders.methods = methods
	Career.data.work_orders = orders
	var result := {"id":id,"completed":true,"cash_cost":0.0,"reward":"","whole":whole}
	# If the player switches from a partial delivery to a full module, consume
	# the actual complete module. Earlier reserved devices are surplus, not
	# quietly destroyed or counted again as part of that module.
	if whole:
		result.surplus_cash = surplus_from(collected)
		Career.data.money = float(Career.data.money)+float(result.surplus_cash)
	var gear: Dictionary = Career.data.get("gear",{})
	if id == "access": gear.probe = int(gear.get("probe",0))+1
	elif id == "rigging": gear.anchor = int(gear.get("anchor",0))+1
	else:
		var reward := selected_reward(job)
		result.reward = reward
		if reward == "field_stock":
			gear.anchor = int(gear.get("anchor",0))+1
			gear.probe = int(gear.get("probe",0))+1
		else:
			var item := Repair.find(reward)
			var cost := 0.0 if whole else float(item[3])*0.2
			var short := maxf(0.0,cost-float(Career.data.money))
			Career.data.money = maxf(0.0,float(Career.data.money)-cost)
			Career.data.loan = float(Career.data.loan)+short
			if short > 0: Career.data.in_debt = true
			Career.data.upgrades[reward] = 1
			var pending: Array = Career.data.get("repaired_pending",[])
			pending.append(reward)
			Career.data.repaired_pending = pending
			var repairs: Array = Career.data.get("repairs",[])
			repairs.append({"id":reward,"at":int(Career.data.done),"parts":[],"cash":cost,"with_parts":false,"work_order":id})
			Career.data.repairs = repairs
			result.cash_cost = cost
	Career.data.gear = gear
	return result
