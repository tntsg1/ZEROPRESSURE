extends Node2D
# Company-owned batch custody around the existing Dock.Smelter. Material only
# changes custody at actual native receivers; Smelter remains the process truth.
const Exchange = preload("res://scripts/industrial_exchange.gd")
const Loads = preload("res://scripts/load_motion.gd")
const SmelterModel = preload("res://scripts/smelter.gd")
const SPEED := 288.0
const GRIP := Vector2(0,60)
const POWER_PRICE := 100.0 # credits/MWh, provisional balance value
var game
var intake: Area2D
var robot: CharacterBody2D
var body: FreeBody
var waiting := ""
var fault := ""
var _issued: Dictionary = {}
var _retry := 0.0
var _checkpoint := 0.0
var _reconstruct := true

func heat() -> Dictionary: return Career.data.get("industrial_heat",{})
# the works a batch runs on: the processing district's own (design/…/30_加工区搬家) where
# they stand; the berth's furnace only in a game without them (old fixtures)
func plant():
	var p = game.get("plant")
	return p if p != null and is_instance_valid(p) else null
func furnace(): return plant().smelter if plant() != null else game.dock.smelter
func _set_furnace(s) -> void:
	if plant() != null: plant().smelter = s
	else: game.dock.smelter = s
# the training run's batches run on the port authority's power (30 号)
# 34 号: the port's own sets at fuel cost, the shore line dear (scripts/grid.gd)
func _power_price() -> float: return Grid.price(heat())
# the overhead rail runs a trolley twice the floor courier's pace (30 号)
# 124 号 (user "太慢了"): the overhead rail at 30 m/s (was 12) — about 8 s along its 236 m
func _speed() -> float: return 30.0*Geom.M if plant() != null else SPEED
# 36 号: one press melts — charging on, the arcs struck, and the power runs itself from then on
# (full until the charge is liquid and hot enough, then holding just above tapping heat)
func start_melt() -> Dictionary:
	var batch := heat()
	if batch.is_empty() or str(batch.get("state","")) != "processing":
		return {"ok":false,"reason":"炉里还没有料"}
	if batch.get("grid",{}).is_empty():
		return {"ok":false,"reason":"等电：" + Grid.wait_text(game)}
	var r: Dictionary = command("power",1.0)
	if not r.ok: return r
	r = command("feed",1.0)
	if not r.ok: return r
	# the commands commit by replacing the career's record: mark the batch in the new one
	heat().auto = true
	checkpoint()
	return {"ok":true}
# 39 号: with the auto sample-and-tap fitted, a liquid, hot charge is sampled and tapped unattended
func _auto_tap(batch: Dictionary) -> void:
	if not (HeatAuto.on() or str(batch.get("queue","")) != "") or plant() == null or str(batch.get("state","")) != "processing" or batch.get("grid",{}).is_empty(): return
	var f = furnace()
	if str(f.phase) not in ["hold","melt"] or float(f.m_l) < 0.05 or float(f.m_s) > 0.000001 or float(f.bunker) > 0.000001 or float(f.T) < SmelterModel.T_TAP: return
	if float(f.dip) > 0.0001 or str(f.lance_phase) != "idle": return
	if int(f.sample_count) == 0 or float(f.tc_age) > 60.0:
		f.manual_command("sample")
	elif f.manual_command("tap").ok:
		checkpoint()
func _auto_power() -> void:
	var batch := heat()
	if not batch.get("auto",false) or str(batch.get("state","")) != "processing": return
	var f = furnace()
	if str(f.phase) in ["tilt","pour","back"]: return
	var solid: float = float(f.m_s)+float(f.bunker)
	if solid > 0.000001 or float(f.T) < SmelterModel.T_TAP+10.0: f.manual_power = 1.0
	elif float(f.T) > SmelterModel.T_TAP+25.0: f.manual_power = 0.0
# 34 号: a heat waiting for power may start on the shore line (own spare + up to 12 MW, the
# shore part at the shore price); asked for here, admitted by the grid on the next frame
func ask_shore() -> Dictionary:
	var batch := heat()
	if batch.is_empty() or str(batch.get("state","")) != "processing" or batch.get("shore_asked",false) or batch.get("grid",{}).get("free",false):
		return {"ok":false,"reason":"现在不用买外购电"}
	if str(Grid.ctl().line) == "own_only":
		return {"ok":false,"reason":"动力控制屏设成了“只用自家发的电”，不能买外购电"}
	batch.shore_asked = true
	if not checkpoint(): return {"ok":false,"reason":"保存失败"}
	return {"ok":true}
func _floor() -> float: return plant().F if plant() != null else Dock.FLOOR_Y
func _feed_key() -> String: return Exchange.lot_key("ferrous_scrap",1)
func _transport_mass() -> float: return float(heat().quantity)
func _furnace_x() -> float:
	if plant() != null: return plant().X
	return game.dock.furnace_x if is_finite(game.dock.furnace_x) else Dock.metal_home
const ConsoleArt = preload("res://scripts/console_art.gd")
func site() -> Vector2:
	# 128 号 第 4 段: the furnace's terminal is in the gallery (the company's works only)
	if plant() != null and preload("res://scripts/process_gallery.gd").on(): return preload("res://scripts/process_gallery.gd").term("furnace")
	return Vector2(_furnace_x()-4.0,_floor()+2.8)*Geom.M


# 125/126 号 (user 2026-11-04: "引导文字和机器画面应当说的是同一件事"): where the heat really is, in
# one place — the guide, the furnace desk, the furnace's own label and the power screens all read
# this. {key, n (of 8), title, text, press ("" = nothing to press: wait), eta (s, -1 unknown)}
#   key: idle | pick | courier | power_wait | deferred | debt | start | melting | starved | probe |
#        sample | tap | tapping | cooling | returning | done | fault
func info() -> Dictionary:
	var h := heat()
	var st := str(h.get("state",""))
	var f = furnace()
	if fault != "":
		return {"key":"fault","n":0,"title":fault,"text":"","press":"","eta":-1.0}
	match st:
		"raw_transport":
			if _wh_wait:
				return {"key":"pick","n":2,"title":_w("叉车正在从货架取钢锭","THE FORKLIFT IS FETCHING THE INGOTS"),"text":waiting,"press":"","eta":-1.0}
			var left := _route_left()
			return {"key":"courier","n":2,"title":_w("吊轨车正把钢锭送到炉口","THE TROLLEY IS BRINGING THE INGOTS"),"text":_w("还有约 %d 秒到炉口，不用按什么。","About %d s to the furnace; nothing to press.") % int(ceil(left)),"press":"","eta":left}
		"raw_return":
			return {"key":"returning","n":2,"title":_w("钢锭正在退回仓库","THE INGOTS ARE GOING BACK"),"text":"","press":"","eta":-1.0}
		"product_transport":
			var left2 := _route_left()
			return {"key":"returning","n":8,"title":_w("钢坯正运回仓库","THE BILLETS ARE GOING TO THE WAREHOUSE"),"text":_w("%.2f t 钢坯，还有约 %d 秒入库。","%.2f t of billet, about %d s to the warehouse.") % [float(h.get("quantity",0.0)),int(ceil(left2))],"press":"","eta":left2}
		"processing":
			pass
		_:
			# 128 号 第 4 段: after the first heat the furnace works the queue by itself
			if ProcessLine.first_done() and not ProcessLine.LEGACY_DESKS:
				if ProcessLine.changing():
					return {"key":"idle","n":1,"title":_w("换模中，还要约 %d 秒","CHANGING THE MOULD, ~%d s") % int(ceil(ProcessLine.change_left())),"text":"","press":"","eta":ProcessLine.change_left()}
				return {"key":"idle","n":1,"title":_w("空闲：加工队列有批次就自己开炉","IDLE: IT STARTS BY ITSELF WHEN THE QUEUE HAS A BATCH"),"text":"","press":"","eta":-1.0}
			return {"key":"idle","n":1,"title":_w("填好吨数，按『把仓库炉料送到炉口』","SET THE TONNES AND SEND THE FEED"),"text":"","press":"send","eta":-1.0}
	var charge := float(f.m_s)+float(f.m_l)+float(f.bunker)
	if str(f.phase) in ["tilt","pour","back"]:
		return {"key":"tapping","n":7,"title":_w("倾炉出钢中","TAPPING"),"text":_w("钢水浇进锭模，铸成钢坯。","The melt runs into the moulds and casts billets."),"press":"","eta":-1.0}
	if charge <= 0.000001:
		# the melt is out: the billets cool on the casting line, then the trolley takes them home
		var eta := _cool_left()
		return {"key":"cooling","n":7,"title":_w("钢坯在铸造线上冷却","THE BILLETS ARE COOLING ON THE LINE"),"text":_w("炉里已经空了，所以不通电。钢坯凉到 200 °C 以下自动运回仓库，还要约 %d 秒。","The furnace is empty, so it draws no power. Below 200 °C the billets go to the warehouse by themselves: about %d s.") % int(ceil(eta)),"press":"","eta":eta}
	if float(h.get("energy_debt",0.0)) > 0.000001:
		return {"key":"debt","n":3,"title":_w("电费没付清，已停止供电","POWER BILL UNPAID: SUPPLY STOPPED"),"text":_w("资金补上后自动恢复。","It comes back once there is cash."),"press":"","eta":-1.0}
	if h.get("grid",{}).is_empty():
		var why := Grid.wait_text(game)
		return {"key":"deferred" if Grid.ctl().defer else "power_wait","n":3,"title":_w("电弧炉已暂停（供电屏）","FURNACE PAUSED (POWER SCREEN)") if Grid.ctl().defer else _w("等电网分电","WAITING FOR A SHARE OF THE GRID"),"text":why,"press":"","eta":-1.0}

	if not h.get("auto",false) and (float(f.manual_power) < 0.5 or (float(f.bunker) > 0.0001 and not bool(f.manual_feed))):
		return {"key":"start","n":3,"title":_w("按『通电熔化』","PRESS 'STRIKE THE ARCS'"),"text":_w("料已在炉口。一按就装炉、起弧，温度自己控。","The feed is at the furnace: one press charges it, strikes the arcs and holds the temperature."),"press":"melt","eta":-1.0}
	var given := float(f.manual_supply_mw)
	var used := float(f.power)
	var melting: bool = float(f.m_s) > 0.000001 or float(f.bunker) > 0.000001 or float(f.T) < SmelterModel.T_TAP
	if melting:
		if used <= 0.05:
			var why2 := Grid.wait_text(game)
			if why2 == "":
				why2 = _w("电网现在没分给电弧炉电。","The grid gives the furnace nothing now.")
			return {"key":"starved","n":5,"title":_w("没在加热：电弧炉没分到电","NOT HEATING: NO POWER FOR THE FURNACE"),"text":_w("%d °C，温度在降。%s","%d °C and falling. %s") % [int(f.T),why2],"press":"shore" if _shore_ok() else "","eta":-1.0}
		var eta2 := _melt_left()
		var line := _w("实际在用 %.1f MW（分到 %.1f / %.0f MW）· 未熔 %.2f t · 出钢要 %d °C 以上，别超过 1710 °C","DRAWING %.1f MW (GIVEN %.1f / %.0f MW) · %.2f t UNMELTED · TAP AT %d °C+, NOT OVER 1710 °C") % [used,given,Grid.furnace_cap(),float(f.m_s)+float(f.bunker),int(SmelterModel.T_TAP)]
		if eta2 > 0.0:
			line += _w(" · 约 %s 后能出钢"," · ready to tap in about %s") % _span(eta2)
		var short := Grid.wait_text(game)
		if short != "":
			line += "
" + short
		return {"key":"melting","n":5,"title":_w("加热熔化中：%d °C","MELTING: %d °C") % int(f.T),"text":line,"press":"shore" if short != "" and _shore_ok() else "","eta":eta2}
	if float(f.dip) > 0.0001 or str(f.lance_phase) != "idle":
		return {"key":"probe","n":6,"title":_w("等测温探头收回","WAITING FOR THE PROBE"),"text":_w("探头收回才能倾炉出钢。","The furnace tilts only once the probe is up."),"press":"","eta":-1.0}
	if (HeatAuto.on() or str(h.get("queue","")) != "") and plant() != null:
		return {"key":"probe","n":6,"title":_w("自动装置在测温、出钢","THE AUTO UNIT IS SAMPLING AND TAPPING"),"text":"","press":"","eta":-1.0}
	if int(f.sample_count) == 0 or float(f.tc_age) > 60.0:
		return {"key":"sample","n":6,"title":_w("全熔了：按『测温取样』","ALL MELTED: PRESS 'TAKE A SAMPLE'"),"text":_w("%d °C，钢水 %.2f t。","%d °C, %.2f t of melt.") % [int(f.T),float(f.m_l)],"press":"sample","eta":-1.0}
	return {"key":"tap","n":7,"title":_w("可以出钢：按『倾炉出钢』","READY: PRESS 'TILT AND TAP'"),"text":_w("%d °C，钢水 %.2f t。","%d °C, %.2f t of melt.") % [int(f.T),float(f.m_l)],"press":"tap","eta":-1.0}


func _w(zh: String, en: String) -> String: return zh if Txt.zh else en


# 126 号 (user: "本次加工完成：获得 X 吨钢坯，已放入仓库。【查看仓库】"): what the heat came to, and where it
# is — and if the mill takes it on at once (rolling on, or a kept batch's plate), said so
func _result_card(t: float, grade: int, queued: bool, mould := "billet") -> void:
	if game == null or game.get("hud") == null or game.get("testing") and not Game.cine_in_tests:
		return
	var key := ProcessLine.product_key(mould,grade)
	# 128 号 第 4 段: a batch the queue ran says so in one line (no card for every heat)
	if queued and ProcessLine.first_done():
		ProcessLine.events.append({"text":_w("出钢入库：%.2f t %s（等级 %d）· %s","CAST AND STORED: %.2f t %s (GRADE %d) · %s") % [t,ProcessLine.mould_name(mould),grade,ProcessLine.use_text(heat())],"bad":false})
		return
	var body := _w("获得 %.2f 吨%s（等级 %d），已放进仓库。以后在仓库里点钢锭“炼成钢坯”，炉子会按加工队列自己炼。", "%.2f t of %s (grade %d), in the stores. From now on pick ingots in the stores and press 'cast': the furnace works the queue by itself.") % [t,ProcessLine.mould_name(mould),grade]
	if bool(Mill.cfg().get("loop",false)):
		body += _w("
轧机开着“连续轧”：它会接着把这批钢坯轧成%s。要留着卖钢坯，去轧机操作台关掉连续轧。", "
The mill is rolling on: it will roll this billet into %s next. To keep billet, switch rolling on off at the mill.") % Mill.product_name(str(Mill.cfg().get("product","plate")))
	elif queued:
		body += _w("
这批是结算时留着加工的钢锭：轧机会接着把它轧成钢板。", "
This was a batch kept at settlement: the mill rolls it into plate next.")
	var g = game
	ResultCard.pop(game.hud, _w("本次加工完成", "THE HEAT IS DONE"), body, _w("查看仓库  [F3]", "SEE THE STORES  [F3]"), func(): g.open_store("product", "m:" + key))


func _shore_ok() -> bool:
	var h := heat()
	return not h.get("shore_asked",false) and str(Grid.ctl().line) != "own_only" and not h.get("grid",{}).get("free",false)


func _span(s: float) -> String:
	if s < 90.0: return _w("%d 秒","%d s") % int(ceil(s))
	return _w("%d 分钟","%d min") % int(ceil(s/60.0))


# s still to run along the courier's route (its waypoints from the one it is making for)
func _route_left() -> float:
	if not is_instance_valid(body): return -1.0
	var path := _path()
	var i := int(heat().get("transport",{}).get("waypoint",0))
	var d := 0.0
	var at: Vector2 = body.global_position
	for k in range(i,path.size()):
		d += at.distance_to(path[k])
		at = path[k]
	return d/maxf(1.0,_speed())


# s until the last billet on the casting line is below 200 °C (they cool as T-25 ~ e^(-t/70))
func _cool_left() -> float:
	var hot := 0.0
	for ig in furnace().ingots:
		hot = maxf(hot,float(ig[1]))
	if hot <= 200.0: return 2.0
	return SmelterModel.COOL_TAU*log((hot-25.0)/175.0)+2.0


# s to all-liquid at tapping heat at the power drawn now (the heat balance the furnace runs on)
func _melt_left() -> float:
	var f = furnace()
	var mass: float = (float(f.m_s)+float(f.m_l)+float(f.bunker))*1000.0
	var need: float = SmelterModel.LINING_C*(SmelterModel.T_TAP-20.0)+mass*(SmelterModel.C_S*(SmelterModel.T_LIQ-20.0)+SmelterModel.L_FUS+SmelterModel.C_L*(SmelterModel.T_TAP-SmelterModel.T_LIQ))
	var have: float = f.manual_enthalpy()
	var net: float = float(f.power)*SmelterModel.ETA-maxf(0.0,f.q_wall())-maxf(0.0,f.q_rad())
	if net <= 0.01: return -1.0
	return maxf(0.0,need-have)/(net*1e6)
func near() -> bool: return game.in_berth() and game.drone.global_position.distance_to(site()) < 6.0*Geom.M
func field_state() -> Dictionary: return {"version":1,"issued":_issued.duplicate()}
func restore_field(state: Dictionary) -> void:
	if int(state.get("version",0)) == 1 and state.get("issued",{}) is Dictionary: _issued = state.get("issued",{}).duplicate()
func _setup_transport() -> void:
	intake = Area2D.new()
	intake.name = "IndustrialFurnaceIntake"
	intake.collision_layer = 0
	intake.collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = Vector2(100,100)
	shape.shape = box
	intake.add_child(shape)
	add_child(intake)
	robot = CharacterBody2D.new()
	# Inactive service handles are hidden at the warehouse, not deployed robots.
	# Only the currently deployed native robot occupies the physical lane.
	robot.collision_layer = 0
	robot.collision_mask = FreeBody.MASK
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48,18)
	collision.shape = rect
	robot.add_child(collision)
	add_child(robot)
	robot.global_position = _raw_at()+GRIP
	robot.draw.connect(func():
		robot.draw_rect(Rect2(-24,-9,48,18),Color(0.05,0.07,0.08))
		robot.draw_rect(Rect2(-24,-9,48,18),Pal.ink(0.8),false,1.5)
		for x in [-17,17]: robot.draw_circle(Vector2(x,0),4,Pal.tint(Pal.AIR,0.8))
		if is_instance_valid(body): robot.draw_line(Vector2.ZERO,robot.to_local(body.global_position),Pal.ink(0.7),2.0))
	robot.visible = false

func _ready() -> void:
	_setup_transport()
	var current := heat()
	if game.in_berth() and not current.is_empty():
		if not current.get("furnace",{}) is Dictionary or not furnace().restore_manual(current.get("furnace",{})):
			fault = "炉体存档校验失败，请保留现场并恢复有效备份"
			waiting = fault
		elif current.get("state","") in ["product_transport","complete"] and (furnace().manual_shipped_t < float(current.quantity)-0.000001 or absf(furnace().input_t-float(current.quantity)) > 0.000001):
			fault = "成品阶段与炉体出料凭证不一致，请保留现场"
			waiting = fault
		elif current.get("state","") in ["raw_transport","raw_return"] and furnace().input_t > 0.000001:
			fault = "未投料阶段与炉体物料凭证不一致，请保留现场"
			waiting = fault
		if fault == "" and current.get("state","") == "product_transport": current.quality = furnace().quality_certificate()
	elif game.in_berth() and Port.stage("process") >= 1:
		# Empty, restored industrial berth: start a cold, unowned chamber before
		# its first rendered frame. The salvage display's random heel is not an
		# actual retained asset and must not disappear mid-command or be sold.
		furnace().begin_manual()
	robot.visible = false

# 106 号: queued: a lot the settlement kept to be processed (scripts/process_queue.gd) — the heat
# starts itself, takes that lot first, melts and taps unattended and carries the ship's name
var _queued := {}
func begin_queued(quantity: float, queued: Dictionary) -> Dictionary:
	_queued = queued
	var r := begin(quantity)
	_queued = {}
	return r
func begin(quantity: float, remote := false) -> Dictionary:
	var queued := _queued
	if fault != "": return {"ok":false,"reason":fault}
	var old_debt := historical_debt()
	if not old_debt.ok: return old_debt
	if float(old_debt.total) > 0.000001: return {"ok":false,"reason":"请先结清历史炉次待缴电费，不能用新炉次覆盖欠款"}
	if float(heat().get("energy_debt",0.0)) > 0.000001: return {"ok":false,"reason":"请先结清上一炉待缴电费，不能用新炉次覆盖欠款"}
	# 30 号: the district's own furnace does not wait on a contract taken (Q24)
	# 124 号: sent from the guide's card it need not be at the desk (remote)
	if (queued.is_empty() and not near() and not remote) or (plant() == null and not Career.active().is_empty()) or Career.production_busy(): return {"ok":false,"reason":"请先结束当前作业，等设备空闲后，到炉台开炉。"}
	if Port.stage("process") < 1: return {"ok":false,"reason":"请先修复加工区基础设施"}
	if not is_finite(quantity) or quantity < 0.25 or quantity > 2.0: return {"ok":false,"reason":"首期单炉范围 0.25–2 t"}
	var line = plant().scrapline if plant() != null else game.dock.scrapline
	if plant() == null and (not game.dock.conveying.is_empty() or game.dock.swallowing.any(func(entry):return Dock.kind(str(entry[1])) == "metal")):
		return {"ok":false,"reason":"等待旧金属完成输送与交接"}
	if line.busy() > 0 or not line.pucks.is_empty() or not line.fines.is_empty() or not line.frags.is_empty() or furnace().phase in ["tilt","pour","back"]:
		return {"ok":false,"reason":"等待上一批拆船料通过设备"}
	var viewed := Exchange.command("view")
	if not viewed.ok: return viewed
	var before := Career.data
	Career.data = before.duplicate(true)
	# Before replacing the authoritative current heat, commit its final balance
	# into every historical copy. Otherwise a stale copy can resurrect paid debt
	# as soon as this ID becomes historical on the next frame.
	var previous_heat := heat()
	for historic in Career.data.get("industrial_history",[]):
		if str(historic.get("id","")) == str(previous_heat.get("id","")):
			historic.energy_debt = float(previous_heat.get("energy_debt",0.0))
			historic.energy_cost = float(previous_heat.get("energy_cost",0.0))
	var state: Dictionary = Career.data.exchange
	var actor: Dictionary = state.actors.company
	var key := Exchange.lot_key("ferrous_scrap",1)
	if float(actor.stock.get(key,0.0)) < quantity:
		Career.data = before
		var have := float(actor.stock.get(key,0.0))
		if have >= 0.25: return {"ok":false,"reason":"仓库只有 %.2f 吨钢锭：把数量改成 %.2f 吨以下再送。" % [have, have]}
		return {"ok":false,"reason":"仓库里没有钢锭了。再拆一艘船，碎料会在熔炉里炼成钢锭进仓库。"}
	var slices: Array = []
	var own: Dictionary = actor.lots.get(str(queued.get("lot","")),{})
	if not queued.is_empty() and str(own.get("key","")) == key and float(own.get("available",0.0)) >= quantity-0.000001:
		own.available = maxf(0.0,float(own.available)-quantity)
		slices = [{"source_id":str(own.id),"quantity":quantity}]
	else:
		slices = Exchange._reserve_lots(actor,key,quantity)
	if slices.is_empty():
		Career.data = before
		return {"ok":false,"reason":"炉料来源记录不完整"}
	var previous: Dictionary = furnace().manual_snapshot()
	if furnace().manual:
		if not furnace().next_manual_batch():
			Career.data = before
			return {"ok":false,"reason":"上一炉尚未清空设备"}
	else: furnace().begin_manual()
	actor.stock[key] = float(actor.stock[key])-quantity
	var identity := Exchange._id(state,"HEAT")
	Career.data.industrial_heat = {"id":identity,"state":"raw_transport","quantity":quantity,"source_lots":slices,"furnace":furnace().manual_snapshot(),"transport":{},"electric_paid_j":0.0,"energy_cost":0.0,"created":float(state.clock),"drill":Drill.active()}
	Career.data.industrial_heat.mould = ProcessLine.line_mould()
	if not queued.is_empty():
		Career.data.industrial_heat.use = queued.get("use",{}).duplicate(true)
		Career.data.industrial_heat.through = true
		Career.data.industrial_heat.queue = str(queued.lot)
		Career.data.industrial_heat.ship = str(queued.get("ship",""))
		ProcessQueue.charged(str(queued.lot), quantity)
	Exchange.sync_batches(Career.data,state)
	if not Career.save():
		Career.data = before
		if not previous.is_empty(): furnace().restore_manual(previous)
		else: _set_furnace(preload("res://scripts/arc_furnace.gd").new() if plant() != null else preload("res://scripts/smelter.gd").new())
		return {"ok":false,"reason":"保存失败，未启动炉次"}
	waiting = ""
	return {"ok":true}

func command(action: String,value: float = 0.0) -> Dictionary:
	if fault != "": return {"ok":false,"reason":fault}
	if not near(): return {"ok":false,"reason":"关键工序必须在炉旁操作"}
	if heat().get("state","") != "processing": return {"ok":false,"reason":"等待原料实际入炉"}
	var saved: Dictionary = furnace().manual_snapshot()
	var before := Career.data
	Career.data = before.duplicate(true)
	var result: Dictionary = furnace().manual_command(action,value)
	if not result.ok:
		Career.data = before
		return result
	if not checkpoint():
		Career.data = before
		furnace().restore_manual(saved)
		return {"ok":false,"reason":"保存失败，操作未提交"}
	return result

func cancel() -> Dictionary:
	if fault != "": return {"ok":false,"reason":fault}
	if not near(): return {"ok":false,"reason":"请在炉旁撤回批次"}
	if heat().get("state","") not in ["raw_transport","raw_return"]: return {"ok":false,"reason":"已投炉材料不能退回冷料；可停机保料或完成出钢"}
	if heat().transport.get("lost",false): return {"ok":false,"reason":"货物缺失，需要先处理现场异常"}
	if not _return_sources_valid(Career.data.exchange.actors.company,heat().source_lots,float(heat().quantity)):
		return {"ok":false,"reason":"炉料来源记录不一致，撤回未提交"}
	var key := _cargo_key()
	if _issued.get(key,false) or heat().transport.has("at"):
		var actual = game.world.key_piece(key)
		if actual == null or actual.body == null or actual.body.pieces.size() != 1 or actual.body.pieces[0].gone or actual.body.pieces[0].key != key or absf(actual.body.total_mass()-float(heat().quantity)) > 0.000001:
			return {"ok":false,"reason":"货物缺失或受损，请先检查现场"}
	if heat().state == "raw_return": return {"ok":true}
	var path := _path()
	var index := int(heat().transport.get("waypoint",0))
	var before := Career.data
	Career.data = before.duplicate(true)
	var batch := heat()
	if _issued.get(key,false) or batch.transport.has("at") or game.world.key_piece(key) != null:
		# Reverse only the route actually traversed, preserving the actual cargo.
		var reverse := path.slice(0,index)
		reverse.reverse()
		reverse.append(_raw_at())
		var points: Array = []
		for at in reverse: points.append([at.x,at.y])
		batch.state = "raw_return"
		batch.transport.return_path = points
		batch.transport.waypoint = 0
	else:
		var actor: Dictionary = Career.data.exchange.actors.company
		for slice in batch.source_lots:
			actor.lots[str(slice.source_id)].available = float(actor.lots[str(slice.source_id)].available)+float(slice.quantity)
		var stock_key := _feed_key()
		actor.stock[stock_key] = float(actor.stock.get(stock_key,0.0))+float(batch.quantity)
		batch.state = "cancelled"
	Exchange.sync_batches(Career.data,Career.data.exchange)
	if not checkpoint():
		Career.data = before
		return {"ok":false,"reason":"保存失败，撤回未提交"}
	return {"ok":true}

func checkpoint() -> bool:
	if fault != "": return false
	if heat().is_empty() or not furnace().manual: return true
	heat().furnace = furnace().manual_snapshot()
	return Career.save()

func _sources_valid(actor: Dictionary,slices: Array,quantity: float) -> bool:
	var seen := {}
	var total := 0.0
	for slice in slices:
		if not slice is Dictionary: return false
		var identity := str(slice.get("source_id",""))
		var amount := float(slice.get("quantity",0.0))
		if identity == "" or seen.has(identity) or not is_finite(amount) or amount <= 0.0: return false
		seen[identity] = true
		var lot: Dictionary = actor.lots.get(identity,{})
		if lot.is_empty() or lot.key != _feed_key() or float(lot.get("consumed",0.0))+amount > float(lot.total)+0.000001: return false
		total += amount
	return is_finite(quantity) and absf(total-quantity) < 0.000001

func _return_sources_valid(actor: Dictionary,slices: Array,quantity: float) -> bool:
	if not _sources_valid(actor,slices,quantity): return false
	for slice in slices:
		var source: Dictionary = actor.lots[str(slice.source_id)]
		if float(source.available)+float(slice.quantity)+float(source.get("consumed",0.0)) > float(source.total)+0.000001: return false
	return true

func write_off() -> Dictionary:
	if fault != "": return {"ok":false,"reason":fault}
	if not near() or heat().get("state","") not in ["raw_transport","raw_return","product_transport"]:
		return {"ok":false,"reason":"只能在现场报损运输中的本批货物"}
	if not _issued.get(_cargo_key(),false) and not heat().transport.has("at") and game.world.key_piece(_cargo_key()) == null:
		return {"ok":false,"reason":"货物尚未交给搬运机构，可免费撤回，无需报损"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var batch := heat()
	if batch.state in ["raw_transport","raw_return"]:
		if not _sources_valid(Career.data.exchange.actors.company,batch.source_lots,float(batch.quantity)):
			Career.data = before
			return {"ok":false,"reason":"原料损失来源记录不一致"}
		for slice in batch.source_lots:
			var lot: Dictionary = Career.data.exchange.actors.company.lots[str(slice.source_id)]
			if float(lot.get("consumed",0.0))+float(slice.quantity) > float(lot.total)+0.000001:
				Career.data = before
				return {"ok":false,"reason":"原料损失账目不一致"}
			lot.consumed = float(lot.get("consumed",0.0))+float(slice.quantity)
	batch.state = "written_off"
	batch.loss = {"mass_t":float(batch.quantity),"refund":0.0,"reason":"operator_write_off","at":float(Career.data.exchange.clock),"source_lots":batch.source_lots.duplicate(true)}
	batch.furnace = furnace().manual_snapshot()
	var history: Array = Career.data.get("industrial_history",[])
	history.append(batch.duplicate(true))
	Career.data.industrial_history = history
	Exchange.sync_batches(Career.data,Career.data.exchange)
	if not Career.save():
		Career.data = before
		return {"ok":false,"reason":"保存失败，报损未提交"}
	# A write-off is a failed asset, not a receipt or deletion of geometry.
	for piece in game.world.pieces.values():
		if piece.gone or not piece.key.begins_with(str(batch.id)+":"): continue
		piece.label = "报损废料"
		if piece.body != null:
			piece.body.capture = null
			piece.body.freeze = false
	body = null
	robot.visible = false
	robot.collision_layer = 0
	game.exchange_logistics.production_lane = false
	waiting = "本批已报损，无退款；遗留实物需现场清理"
	return {"ok":true}

func _cargo_key() -> String:
	return str(heat().id)+(":RAW" if heat().state in ["raw_transport","raw_return"] else ":PRODUCT")
func _raw_at() -> Vector2:
	return game.exchange_logistics.warehouse.global_position
func _output_at() -> Vector2:
	return Vector2(_furnace_x()+furnace().LINE_X1,_floor()+furnace().DY+6.4)*Geom.M
func _path() -> Array:
	if heat().state == "raw_return":
		var result: Array = []
		for point in heat().transport.return_path: result.append(Vector2(float(point[0]),float(point[1])))
		return result
	var freight = game.exchange_logistics
	var mouth := intake.global_position
	if plant() != null:
		# 30 号: along the overhead rail, warehouse yard ⇄ cargo district ⇄ hub ⇄ the works
		var rail: Array = plant().rail()
		var r0: Vector2 = rail[0]
		var up: Vector2 = freight.global_position+Vector2(0,-300)
		if heat().state == "raw_transport":
			var back := rail.duplicate()
			back.reverse()
			return [freight.global_position,up]+back+[Vector2(r0.x,mouth.y),mouth]
		return [Vector2(r0.x,_output_at().y),r0]+rail+[up,freight.global_position,_raw_at()]
	var outside := Vector2((Dock.FLOOR_X1+12.0)*Geom.M,mouth.y)
	# 2026-10-24: no climb to RAIL_Y-12 m any more (it went up and straight back down);
	# the compact port's walls (scripts/port_structure.gd) stand there and blocked the courier
	var exit: Vector2 = freight.global_position+Vector2(0,-300)
	if heat().state == "raw_transport":
		return [freight.global_position,exit,Vector2(outside.x,exit.y),outside,mouth]
	return [Vector2(outside.x,_output_at().y),outside,Vector2(outside.x,exit.y),exit,freight.global_position,_raw_at()]

# 73 号: what the feed is on the racks (the sorting line, which shares this courier, waits for none)
func _wh_key() -> String:
	return "ferrous_scrap:1"


var _wh_wait := false
func _adopt() -> bool:
	var key := _cargo_key()
	var p = game.world.key_piece(key)
	if p != null and p.body != null: body = p.body
	else:
		if _issued.get(key,false) or heat().transport.get("lost",false): return false
		if heat().state == "raw_transport" and game.exchange_logistics.active != "":
			waiting = "等待装卸位"
			return false
		# 73 号: the feed comes down from its rack first (not the training run's subsidised tonne)
		if heat().state == "raw_transport" and Warehouse.ON and not heat().get("drill", false) and _wh_key() != "":
			var jid := "HEAT:" + str(heat().id)
			Warehouse.ask_out(jid, _wh_key(), float(heat().get("quantity", 0.0)))
			if not Warehouse.ready(jid):
				waiting = Warehouse.wait_text(jid)
				_wh_wait = true
				return false
			_wh_wait = false
			Warehouse.consume(jid)
		var at := _raw_at() if heat().state == "raw_transport" else _output_at()
		var location: Array = heat().transport.get("at",[at.x,at.y])
		at = Vector2(float(location[0]),float(location[1]))
		var side := Geom.M*sqrt(_transport_mass())
		if not Loads.clear_spawn(get_world_2d().direct_space_state,at,Vector2.ONE*side):
			waiting = "等待装卸位"
			return false
		p = game.world.add_piece("cargo",Geom.rect_poly(Rect2(at-Vector2.ONE*side*0.5,Vector2.ONE*side)),{"key":key,"mass":_transport_mass(),"cls":"equip","scope":false,"value":0.0,"label":"FEED" if heat().state == "raw_transport" else "BILLET"})
		game.world.make_body([p],null)
		body = p.body
	_issued[key] = true
	if body.get_parent() != self: body.reparent(self,true)
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.capture = "industrial"
	body.ghost = 0.0
	body.collision_mask = FreeBody.MASK
	_migrate_route()
	if _reconstruct:
		robot.global_position = body.global_position+GRIP
		_reconstruct = false
	robot.visible = true
	robot.collision_layer = 4
	return true

# an old save's cargo on the berth's route (under the berth floor): once, back to where its
# leg starts, to take the rail from there (30 号)
func _migrate_route() -> void:
	if plant() == null or heat().is_empty() or int(heat().transport.get("route",1)) >= 2: return
	var batch := heat()
	if batch.state == "raw_return":
		body.global_position = _raw_at()
		batch.transport.return_path = [[_raw_at().x,_raw_at().y]]
	elif int(batch.transport.get("waypoint",0)) > 0:
		body.global_position = _raw_at() if batch.state == "raw_transport" else _output_at()
	batch.transport.waypoint = 0
	batch.transport.route = 2
	batch.transport.at = [body.global_position.x,body.global_position.y]
	_reconstruct = true

func _inside(receiver: Area2D) -> bool:
	if not is_instance_valid(body) or not receiver.overlaps_body(body): return false
	var shape = receiver.get_node("Shape").shape
	return Rect2(receiver.global_position-shape.size*0.5,shape.size).encloses(Loads.bounds(body)) and body.collision_mask == FreeBody.MASK

func _prepare_transport() -> bool: return true
# 37 号: a stop on the way (the in-line assay), and whether the leg ends in the warehouse's lane
func _hold(_index: int,_dt: float) -> bool: return false
func _lane_wait() -> bool: return true
func _move_empty(dt: float) -> void:
	var target: Vector2 = body.global_position+GRIP
	var empty_move: Vector2 = (target-robot.global_position).limit_length(_speed()*dt)
	if not robot.test_move(robot.global_transform,empty_move): robot.global_position += empty_move
	else:
		# the load itself is in the way (a big batch): round its side, then under it
		var half: float = Loads.bounds(body).size.x*0.5+30.0
		var side := signf(robot.global_position.x-body.global_position.x)
		if side == 0.0: side = 1.0
		var clear_x: float = body.global_position.x+side*half
		var detour := Vector2.ZERO
		if absf(robot.global_position.x-clear_x) > 0.5 and absf(robot.global_position.x-body.global_position.x) < half:
			detour = Vector2(clear_x-robot.global_position.x,0.0).limit_length(_speed()*dt)
		elif absf(robot.global_position.y-target.y) > 0.5:
			detour = Vector2(0.0,target.y-robot.global_position.y).limit_length(_speed()*dt)
		if detour != Vector2.ZERO and not robot.test_move(robot.global_transform,detour): robot.global_position += detour
		else: waiting = "搬运机构等待通道"
	robot.queue_redraw()

func _receive() -> bool:
	if fault != "" or not furnace().manual: return false
	var raw: bool = heat().state == "raw_transport"
	var returned: bool = heat().state == "raw_return"
	var receiver: Area2D = intake if raw else game.exchange_logistics.warehouse
	if not _inside(receiver): return false
	if body.pieces.size() != 1 or str(body.pieces[0].key) != _cargo_key() or absf(body.total_mass()-float(heat().quantity)) > 0.000001: return false
	var before := Career.data
	var model: Dictionary = furnace().manual_snapshot()
	Career.data = before.duplicate(true)
	var batch := heat()
	var state: Dictionary = Career.data.exchange
	var actor: Dictionary = state.actors.company
	if raw:
		if not _sources_valid(actor,batch.source_lots,float(batch.quantity)):
			Career.data = before
			return false
		var source_mass := 0.0
		for slice in batch.source_lots:
			var source: Dictionary = actor.lots.get(str(slice.source_id),{})
			if source.is_empty() or float(source.get("consumed",0.0))+float(slice.quantity) > float(source.total)+0.000001:
				Career.data = before
				return false
			source_mass += float(slice.quantity)
		if absf(source_mass-float(batch.quantity)) > 0.000001:
			Career.data = before
			return false
		for slice in batch.source_lots:
			var lot: Dictionary = actor.lots[str(slice.source_id)]
			lot.consumed = float(lot.get("consumed",0.0))+float(slice.quantity)
		if not furnace().manual_charge(float(batch.quantity)):
			Career.data = before
			return false
		batch.state = "processing"
	elif returned:
		if not _return_sources_valid(actor,batch.source_lots,float(batch.quantity)):
			Career.data = before
			waiting = "返仓来源记录不一致，未增加库存"
			return false
		for slice in batch.source_lots:
			actor.lots[str(slice.source_id)].available = float(actor.lots[str(slice.source_id)].available)+float(slice.quantity)
		var raw_key := Exchange.lot_key("ferrous_scrap",1)
		actor.stock[raw_key] = float(actor.stock.get(raw_key,0.0))+float(batch.quantity)
		batch.state = "cancelled"
	else:
		if furnace().manual_shipped_t < float(batch.quantity)-0.000001 or furnace().input_t < float(batch.quantity)-0.000001:
			Career.data = before
			waiting = "炉体出料记录尚未满足本批次验收"
			return false
		if float(batch.get("energy_debt",0.0)) > 0.000001:
			Career.data = before
			waiting = "待结清本炉电费后验收入库"
			return false
		var quality: Dictionary = furnace().quality_certificate()
		if not quality.ready:
			Career.data = before
			return false
		batch.quality = quality
		var output_grade := int(quality.grade)
		var identity := str(batch.id)+":PRODUCT"
		# 128 号 第 4 段: the mould it was cast in names the product (方坯 / 板坯 / 小锭)
		var item := ProcessLine.item_of(str(batch.get("mould","billet")))
		var key := Exchange.lot_key(item,output_grade)
		actor.lots[identity] = {"id":identity,"key":key,"available":float(batch.quantity),"total":float(batch.quantity),"origin":"manufactured","parents":batch.source_lots.duplicate(true)}
		actor.stock[key] = float(actor.stock.get(key,0.0))+float(batch.quantity)
		state.sources[identity] = {"quantity":float(batch.quantity),"item":item,"grade":output_grade}
		Career.data.material_batches.append({"id":identity,"mass_t":float(batch.quantity),"material":"steel_billet","form":item,"grade":output_grade,"state":"product_received","storage":"exchange","heat_id":str(batch.id),"quality":quality.duplicate(true)})
		batch.state = "complete"
		batch.completed = float(state.clock)
		if str(batch.get("queue","")) != "":
			ProcessQueue.tapped(str(batch.queue), float(batch.quantity), output_grade)
			actor.lots[identity].ship = str(batch.get("ship",""))
		# 39 号: the arc furnace's tapped heats, toward its first automation
		if plant() != null: Career.data.heat_count = int(Career.data.get("heat_count",0))+1
		_result_card(float(batch.quantity),output_grade,str(batch.get("queue","")) != "",str(batch.get("mould","billet")))
	batch.furnace = furnace().manual_snapshot()
	batch.receipt = {"key":str(body.pieces[0].key),"mass_t":body.total_mass(),"receiver":str(receiver.name)}
	batch.transport = {}
	if not raw:
		var history: Array = Career.data.get("industrial_history",[])
		history.append(batch.duplicate(true))
		Career.data.industrial_history = history
	Exchange.sync_batches(Career.data,state)
	state.revision = int(state.revision)+1
	if not Career.save():
		Career.data = before
		furnace().restore_manual(model)
		waiting = "保存失败，货物暂存"
		_retry = 1.0
		return false
	game.world.remove_body(body)
	body = null
	robot.visible = false
	robot.collision_layer = 0
	waiting = ""
	return true

func historical_debt() -> Dictionary:
	# The current heat is authoritative for its own ID. Duplicate historical
	# copies are one obligation, never a second bill. Conflicting copies need
	# recovery instead of silently choosing a balance and charging the player.
	var debts := {}
	var current := str(heat().get("id",""))
	var history = Career.data.get("industrial_history",[])
	if not history is Array: return {"ok":false,"reason":"历史炉次账本格式错误，请保留存档"}
	for entry in history:
		if not entry is Dictionary: return {"ok":false,"reason":"历史炉次账本格式错误，请保留存档"}
		var raw = entry.get("energy_debt",0.0)
		if not (raw is float or raw is int): return {"ok":false,"reason":"历史炉次欠费格式错误，请保留存档"}
		var amount := float(raw)
		var identity := str(entry.get("id",""))
		if not is_finite(amount) or amount < 0.0 or (amount > 0.000001 and identity == ""):
			return {"ok":false,"reason":"历史炉次欠费记录无效，请保留存档"}
		if identity == current: continue
		if debts.has(identity) and absf(float(debts[identity])-amount) > 0.000001:
			return {"ok":false,"reason":"同一历史炉次的欠费记录冲突，请保留存档核查"}
		debts[identity] = amount
	var total := 0.0
	for amount in debts.values(): total += float(amount)
	return {"ok":true,"total":total,"debts":debts}

func _pay_history() -> bool:
	var ledger := historical_debt()
	if not ledger.ok:
		waiting = str(ledger.reason)
		return false
	if float(ledger.total) <= 0.000001: return true
	if float(Career.data.money) <= 0.0:
		waiting = "历史炉次电费待缴，可先完成其他业务筹款"
		return true
	var before := Career.data
	Career.data = before.duplicate(true)
	var budget := maxf(0.0,float(Career.data.money))
	for identity in ledger.debts:
		var payment := minf(budget,float(ledger.debts[identity]))
		budget -= payment
		for entry in Career.data.industrial_history:
			if str(entry.get("id","")) == identity: entry.energy_debt = maxf(0.0,float(ledger.debts[identity])-payment)
	Career.data.money = budget
	Career.data.exchange.actors.company.cash = budget
	# Save debt reduction and cash together, including when there is no current
	# heat and therefore no ordinary furnace checkpoint to flush these changes.
	if not Career.save():
		Career.data = before
		waiting = "历史电费结算保存失败，未扣款"
		return false
	if waiting == "历史炉次电费待缴，可先完成其他业务筹款": waiting = ""
	return true

func _process(dt: float) -> void:
	if game.is_queued_for_deletion(): return
	if fault != "": return
	if not game.in_berth() or game.state != "play" or game.menu_open or game.paused_sim: return
	if not _pay_history(): return
	intake.global_position = Vector2(_furnace_x(),_floor()+furnace().DY+0.8)*Geom.M
	var batch := heat()
	# 106 号: the next kept batch, once the furnace is free
	ProcessLine.tick_change(dt)
	furnace().mould = ProcessLine.line_mould()
	_queue_t -= dt
	if _queue_t <= 0.0:
		_queue_t = 2.0
		if _queue_next(): batch = heat()
	if batch.is_empty():
		queue_redraw()
		return
	var sorting: Dictionary = Career.data.get("industrial_sort",{})
	if sorting.get("state","complete") in ["complete","cancelled","written_off"]:
		game.exchange_logistics.production_lane = batch.state in ["product_transport","raw_return"] or (batch.state == "raw_transport" and int(batch.transport.get("waypoint",0)) < 2)
	# Older field snapshots may contain cargo already durably received by the
	# furnace/warehouse. Retire only against that matching custody record.
	for suffix in [":RAW",":PRODUCT"]:
		if batch.state == "written_off": continue
		if suffix == ":RAW" and batch.state in ["raw_transport","raw_return"]: continue
		if suffix == ":PRODUCT" and batch.state != "complete": continue
		var old = game.world.key_piece(str(batch.id)+suffix)
		if old != null and old.body != null and old.body != body: game.world.remove_body(old.body)
	# Meter deltas remain payable even if another business spent the last cash
	# in the same frame. Stop supply and retain the small accrued obligation;
	# never discard consumed energy or grant product while its bill is unpaid.
	var meter: float = furnace().electrical_j
	var due := maxf(0.0,meter-float(batch.electric_paid_j))/3.6e9*_power_price()
	batch.energy_cost = float(batch.energy_cost)+due
	batch.electric_paid_j = meter
	var owed := float(batch.get("energy_debt",0.0))+due
	var payment := minf(maxf(0.0,float(Career.data.money)),owed)
	Career.data.money = float(Career.data.money)-payment
	batch.energy_debt = maxf(0.0,owed-payment)
	if payment > 0.0 and batch.state in ["complete","cancelled","written_off"]:
		for historic in Career.data.get("industrial_history",[]):
			if historic.id == batch.id:
				historic.energy_debt = batch.energy_debt
				historic.energy_cost = batch.energy_cost
	Career.data.exchange.actors.company.cash = float(Career.data.money)
	# 34 号: the furnace is fed only while its heat holds a share of the grid; a heat whose
	# feed is in asks for one, and waits for power when the district has none to spare
	var supply := 0.0
	if batch.state == "processing":
		if batch.get("grid",{}).is_empty():
			var share := Grid.admit_heat(game,batch)
			if not share.is_empty():
				batch.grid = share
				checkpoint()
		# 70 号: no queue — the heat runs on what the dispatch gives it now (never above the cap)
		if not batch.get("grid",{}).is_empty():
			supply = Grid.heat_supply(game,batch)
	if batch.get("through",false) and batch.state == "processing" and not batch.get("auto",false) and not batch.get("grid",{}).is_empty() and float(batch.energy_debt) <= 0.000001:
		# the through line's furnace starts itself (no one need stand at the desk for this step)
		if furnace().manual_command("power",1.0).ok and furnace().manual_command("feed",1.0).ok:
			batch.auto = true
			checkpoint()
	_auto_power()
	_auto_tap(batch)
	furnace().manual_supply_mw = supply if float(batch.energy_debt) <= 0.000001 else 0.0
	if float(batch.energy_debt) > 0.000001: waiting = "电费余额不足，已停止新增供电"
	elif batch.state == "processing" and batch.get("grid",{}).is_empty(): waiting = "等电：" + Grid.wait_text(game)
	# 125 号: short of power only while there is a charge to heat (not while the billets cool)
	elif batch.state == "processing" and Grid.wait_text(game) != "" and float(furnace().m_s)+float(furnace().m_l)+float(furnace().bunker) > 0.000001: waiting = Grid.wait_text(game)
	elif batch.state == "processing" and float(furnace().m_s)+float(furnace().m_l)+float(furnace().bunker) <= 0.000001 and (waiting.begins_with("电不够") or waiting.begins_with("SHORT")): waiting = ""
	elif waiting == "电费余额不足，已停止新增供电" or waiting.begins_with("等电：") or waiting.begins_with("电不够"): waiting = ""
	if batch.state == "processing":
		if furnace().manual_shipped_t >= float(batch.quantity)-0.000001 and furnace().phase == "hold":
			batch.quality = furnace().quality_certificate()
			batch.state = "product_transport"
			batch.transport = {}
			checkpoint()
	batch.furnace = furnace().manual_snapshot()
	_checkpoint += dt
	if _checkpoint > 5.0:
		_checkpoint = 0.0
		if not checkpoint(): waiting = "保存失败，请保留现场"
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "process", 30.0):
		queue_redraw()

var _queue_t := 0.0
# a heat for the queue's next lot when nothing else holds the furnace or the line
func _queue_next() -> bool:
	if plant() == null or Port.stage("process") < 1 or Career.production_busy(): return false
	if float(heat().get("energy_debt",0.0)) > 0.000001 or furnace().phase in ["tilt","pour","back"]: return false
	var e := ProcessQueue.next_melt()
	if e.is_empty(): return false
	# 128 号 第 4 段: a batch for another mould waits for the crane to change the block in the seat
	if ProcessLine.changing(): return false
	var want := str(e.get("mould","billet"))
	if want != ProcessLine.line_mould():
		if furnace().ingots.is_empty() and float(furnace().cast_t) <= 0.0:
			ProcessLine.start_change(want)
			Career.save()
		return false
	var actor: Dictionary = Career.data.get("exchange",{}).get("actors",{}).get("company",{})
	var have := float(actor.get("lots",{}).get(str(e.lot),{}).get("available",0.0))
	if str(e.get("key","")) != "":
		have = float(actor.get("stock",{}).get(str(e.key),0.0))
	var q := minf(ProcessQueue.HEAT_T,minf(float(e.t)-float(e.melted),have))
	if q < ProcessQueue.HEAT_MIN:
		# the rest of the lot went elsewhere (sold on the exchange, or used): nothing more to melt
		ProcessQueue.charged(str(e.lot),float(e.t)-float(e.melted))
		Career.save()
		return false
	return bool(begin_queued(snappedf(q,0.001),e).ok)


func _physics_process(dt: float) -> void:
	if game.is_queued_for_deletion(): return
	if fault != "": return
	if not game.in_berth() or game.state != "play" or game.menu_open or game.paused_sim: return
	_retry = maxf(0.0,_retry-dt)
	if _retry > 0.0 or heat().get("state","") not in ["raw_transport","raw_return","product_transport"]: return
	if not is_instance_valid(body) or body.pieces.is_empty():
		body = null
		if not _adopt():
			# 106 号: the feed still coming down from its rack is not lost cargo
			if waiting == "等待装卸位" or _wh_wait: return
			waiting = "货物缺失，等待现场处理"
			heat().transport.lost = true
			checkpoint()
			_retry = 1.0
			return
	if not _prepare_transport(): return
	if robot.global_position.distance_to(body.global_position+GRIP) > 0.01:
		_move_empty(dt)
		return
	if body.pieces.size() != 1 or body.pieces[0].key != _cargo_key() or absf(body.total_mass()-_transport_mass()) > 0.000001:
		waiting = "货物受损，等待重新验收"
		return
	var path := _path()
	var index := int(heat().transport.get("waypoint",0))
	if _hold(index,dt): return
	if heat().state == "product_transport" and _lane_wait() and index >= path.size()-3 and game.exchange_logistics.active != "":
		waiting = "等待仓库接收通道"
		return
	if index < path.size():
		var delta: Vector2 = (path[index]-body.global_position).limit_length(_speed()*dt)
		if robot.test_move(robot.global_transform,delta) or not Loads.move(body,delta):
			waiting = "搬运通道受阻，请检查现场"
			return
		robot.global_position += delta
		if body.global_position.distance_to(path[index]) < 0.01: heat().transport.waypoint = index+1
		waiting = ""
	else: _receive()
	if is_instance_valid(body): heat().transport.at = [body.global_position.x,body.global_position.y]
	robot.queue_redraw()

# 105 号: the desk is drawn on a layer of its own over the plant (the machines' front layers would
# hide it otherwise); this node keeps its place in the scene
var _desk: Node2D
func _draw() -> void:
	if _desk == null:
		_desk = Node2D.new()
		_desk.z_index = 4
		_desk.z_as_relative = false
		add_child(_desk)
		_desk.draw.connect(func(): _draw_desk(_desk))
		# redrawn every frame on its own: this node's _process returns early while idle
		get_tree().process_frame.connect(_desk_tick)
	_desk_tick()


func _desk_tick() -> void:
	if _desk == null or not is_instance_valid(_desk):
		return
	_desk.visible = game != null and game.in_berth()
	if _desk.visible:
		_desk.queue_redraw()


func _draw_desk(ci: CanvasItem) -> void:
	if not game.in_berth(): return
	# 105 号: a furnace desk (scripts/console_art.gd): its batch, the furnace's power, the port's glow
	var at := site()
	var b := heat()
	var mw := float(furnace().power) if furnace() != null else 0.0
	var info := {"lines": [[Ops.batch_state(b), Pal.tint(Pal.AIR, 0.95, 1.2)], [("%.1f t · %.1f MW" % [float(b.get("quantity", 0.0)), mw]) if not b.is_empty() else Ops.w("没有炉次", "NO HEAT"), Pal.ink(0.75)]],
		"bar": clampf(mw / Grid.FURNACE_MW, 0.0, 1.0), "lamp": "work" if str(b.get("state", "")) == "processing" else "ok", "glow": mw / Grid.FURNACE_MW}
	# 106 号: a kept batch carries its ship's name — on the desk, over the cargo on its way, over
	# the furnace while it melts
	var ship := str(b.get("ship", ""))
	var live := ship != "" and not str(b.get("state", "")) in ["complete", "cancelled", "written_off"]
	if live:
		info.lines[1][0] = Methods.ship_label(ship) + " · " + str(info.lines[1][0])
	# 128 号 第 4 段: after the first heat by hand the desk opens the processing queue
	var desk_key := Ops.w("[%s] 加工队列", "[%s] PROCESSING QUEUE") if ProcessLine.first_done() and not ProcessLine.LEGACY_DESKS else Ops.w("[%s] 炉体操作", "[%s] FURNACE CONTROLS")
	ConsoleArt.draw(ci, at, ConsoleArt.foot_at(at), Ops.w("炉体操作台", "FURNACE DESK"), desk_key % Keys.label("use"), near(), info, Time.get_ticks_msec() * 0.001, "furnace")
	if not live:
		return
	var tag := "%s · %.1f t" % [Methods.ship_label(ship), float(b.get("quantity", 0.0))]
	var over: Vector2 = body.global_position + Vector2(0, -1.6 * Geom.M) if is_instance_valid(body) else Vector2(_furnace_x(), _floor() - 10.5) * Geom.M
	ship_tag(ci, over, tag, game.cam_zoom())


# a ship's name tag on a load (106 号): a dark plate, the name, a tick down to the load; screen-sized
# whatever the zoom
static func ship_tag(ci: CanvasItem, at: Vector2, text: String, zoom: float) -> void:
	var f: Font = Fonts.get_font("SemiBold")
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	ci.draw_set_transform(at, 0.0, Vector2.ONE / maxf(zoom, 0.02))
	var r := Rect2(Vector2(-sz.x * 0.5 - 8.0, -sz.y - 16.0), Vector2(sz.x + 16.0, sz.y + 6.0))
	ci.draw_rect(r, Color(0.02, 0.025, 0.03, 0.85))
	ci.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Pal.tint(Pal.AIR, 0.95, 1.2))
	ci.draw_line(Vector2(0.0, r.end.y), Vector2.ZERO, Pal.ink(0.5), 1.0)
	ci.draw_string(f, Vector2(r.position.x + 9.0, r.end.y - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.95))
	ci.draw_set_transform(Vector2.ZERO)
