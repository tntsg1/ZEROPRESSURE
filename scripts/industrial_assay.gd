extends Node2D
# The assay bench (G5.1, design/…/19_G5.1_留料与检验): beside the sorting desk under the
# berth floor. A lot in the company warehouse is locked while a sample of it is read on
# the spectrometer; the tonnes stay where they are (an assay reads a sample, it does not
# carry the lot). What it finds follows from where the material came from, so the same
# source always reads the same:
#   ferrous scrap, unrated → impurity ≤ LIMIT: the whole lot becomes grade 1 furnace feed
#                            above it: the lot stays unrated, with its certificate
#   mixed metal with no material record (old receipts) → its non-magnetic share is
#                            measured and recorded, so the sorting line will take it
# The bench is worked on site (Q30); a fixed provisional fee per lot (to be balanced).
const ConsoleArt = preload("res://scripts/console_art.gd")
const Exchange = preload("res://scripts/industrial_exchange.gd")
const FEE := 120.0
const DURATION := 30.0          # seconds of game time on the spectrometer
const LIMIT := 0.03             # grade 1 furnace feed: impurity at most 3 %
const OLD_SHARE := 0.20         # an old receipt with no record: read as this non-magnetic share
const CARBON := 0.004           # what is neither iron nor impurity in the reading (C, Si, Mn)

var game
var fault := ""
var waiting := ""
var _save_retry := 0.0


func data() -> Dictionary:
	return Career.data.get("assay", {})


func running() -> bool:
	return str(data().get("state", "")) == "running"


# the training run's reading is on the port authority (30 号)
static func fee() -> float:
	return 0.0 if Drill.active() else FEE


func _plant():
	var p = game.get("plant")
	return p if p != null and is_instance_valid(p) else null


# beside the sorting line: in the processing district's works where they stand (30 号)
func _furnace_x() -> float:
	if _plant() != null:
		return _plant().X
	return game.dock.furnace_x if is_finite(game.dock.furnace_x) else Dock.metal_home


func site() -> Vector2:
	return Vector2(_furnace_x() + 20.0, (_plant().F if _plant() != null else Dock.FLOOR_Y) + 1.5) * Geom.M


func near() -> bool:
	return game.in_berth() and game.drone.global_position.distance_to(site()) < 6.0 * Geom.M


# ---------------------------------------------------------------- what it reads

# the non-magnetic share behind a lot: its own record, or what its parents recorded
static func share_of(actor: Dictionary, lot: Dictionary) -> float:
	var parents = lot.get("parents", [])
	if parents is Array and not parents.is_empty():
		var total := 0.0
		for p in parents:
			total += float(p.get("quantity", 0.0))
		var prof := Exchange.source_profile(actor, parents, total)
		if prof.ok:
			return float(prof.profile.nonmagnetic_share)
	var own = lot.get("material_profile", {})
	if own is Dictionary and int(own.get("version", 0)) == 1 and str(own.get("basis", "")) != "magnetic_separation_unassayed":
		return clampf(float(own.get("nonmagnetic_share", OLD_SHARE)), 0.0, 1.0)
	return OLD_SHARE


# the magnetic stream carries a little of what it was separated from
static func impurity_of(share: float) -> float:
	return 0.006 + 0.10 * share


static func described(lot: Dictionary) -> bool:
	var p = lot.get("material_profile", {})
	return p is Dictionary and int(p.get("version", 0)) == 1 and (p.get("nonmagnetic_share", null) is float or p.get("nonmagnetic_share", null) is int)


# the lots the bench can take: [{id, key, quantity, kind ("grade" | "describe"), origin}]
static func candidates() -> Array:
	var out: Array = []
	var actor: Dictionary = Career.data.get("exchange", {}).get("actors", {}).get(Exchange.PLAYER, {})
	var lots: Dictionary = actor.get("lots", {})
	for id in lots:
		var lot: Dictionary = lots[id]
		if float(lot.get("available", 0.0)) <= Exchange.EPS or lot.has("assay"):
			continue
		if str(lot.get("key", "")) == Exchange.lot_key("ferrous_scrap", 0):
			out.append({"id": str(id), "key": lot.key, "quantity": float(lot.available), "kind": "grade", "origin": str(lot.get("origin", ""))})
		elif str(lot.get("key", "")) == Exchange.lot_key("mixed_metal", 0) and not described(lot):
			out.append({"id": str(id), "key": lot.key, "quantity": float(lot.available), "kind": "describe", "origin": str(lot.get("origin", ""))})
	out.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return out


# ---------------------------------------------------------------- commands

func begin(lot_id: String) -> Dictionary:
	if fault != "":
		return {"ok": false, "reason": fault}
	if not near() or (_plant() == null and not Career.active().is_empty()):
		return {"ok": false, "reason": "请在化验位操作"}
	if running():
		return {"ok": false, "reason": "化验位正在读上一批样品"}
	var fee := fee()
	if float(Career.data.get("money", 0.0)) < fee:
		return {"ok": false, "reason": "化验费 %s，资金不足" % Pal.money(fee)}
	var viewed := Exchange.command("view")
	if not viewed.ok:
		return viewed
	var pick: Array = candidates().filter(func(c): return c.id == lot_id)
	if pick.is_empty():
		return {"ok": false, "reason": "这批料不在仓库，或已经化验过"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var state: Dictionary = Career.data.exchange
	var actor: Dictionary = state.actors[Exchange.PLAYER]
	var lot: Dictionary = actor.lots[lot_id]
	var quantity := float(lot.available)
	var key := str(lot.key)
	lot.available = 0.0
	actor.stock[key] = maxf(0.0, float(actor.stock.get(key, 0.0)) - quantity)
	Career.data.money = float(Career.data.money) - fee
	actor.cash = float(Career.data.money)
	var previous := data()
	if not previous.is_empty():
		var history: Array = Career.data.get("assay_history", [])
		history.append(previous.duplicate(true))
		Career.data.assay_history = history
	Career.data.assay = {"id": Exchange._id(state, "ASY"), "lot": lot_id, "key": key, "quantity": quantity, "kind": str(pick[0].kind),
		"state": "running", "elapsed": 0.0, "fee": fee}
	Exchange.sync_batches(Career.data, state)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": "保存失败，化验未开始"}
	waiting = ""
	return {"ok": true}


# the lot back in stock, the fee kept (the sample was taken)
func cancel() -> Dictionary:
	if not running():
		return {"ok": false, "reason": "没有正在化验的批次"}
	if not near():
		return {"ok": false, "reason": "请在化验位操作"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var a: Dictionary = Career.data.assay
	var actor: Dictionary = Career.data.exchange.actors[Exchange.PLAYER]
	var lot: Dictionary = actor.lots.get(str(a.lot), {})
	if lot.is_empty():
		Career.data = before
		return {"ok": false, "reason": "批次记录缺失"}
	lot.available = float(lot.available) + float(a.quantity)
	actor.stock[str(a.key)] = float(actor.stock.get(str(a.key), 0.0)) + float(a.quantity)
	a.state = "cancelled"
	Exchange.sync_batches(Career.data, Career.data.exchange)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": "保存失败"}
	return {"ok": true}


# the reading so far: [fe, impurity, settled 0..1]; it closes in on the true value
func reading() -> Array:
	var a := data()
	if a.is_empty():
		return [0.0, 0.0, 0.0]
	var k := clampf(float(a.get("elapsed", 0.0)) / DURATION, 0.0, 1.0) if running() else 1.0
	var truth := _truth(a)
	var t := float(a.get("elapsed", 0.0))
	# counting noise: proportional, so a clean lot never reads as zero and a dirty one wanders
	var wobble := (1.0 - k) * (0.45 * sin(t * 3.1) + 0.25 * sin(t * 7.9 + 1.3))
	var imp := maxf(0.0, float(truth.impurity) * (1.0 + wobble))
	return [1.0 - imp - CARBON, imp, k]


func _truth(a: Dictionary) -> Dictionary:
	var actor: Dictionary = Career.data.get("exchange", {}).get("actors", {}).get(Exchange.PLAYER, {})
	var lot: Dictionary = actor.get("lots", {}).get(str(a.get("lot", "")), {})
	if str(a.get("kind", "")) == "describe":
		var s := OLD_SHARE
		return {"share": s, "impurity": s, "pass": false}
	var share := share_of(actor, lot)
	var imp := impurity_of(share)
	return {"share": share, "impurity": imp, "pass": imp <= LIMIT + 1e-9}


func _complete() -> bool:
	var before := Career.data
	Career.data = before.duplicate(true)
	var a: Dictionary = Career.data.assay
	var state: Dictionary = Career.data.exchange
	var actor: Dictionary = state.actors[Exchange.PLAYER]
	var lot: Dictionary = actor.lots.get(str(a.lot), {})
	if lot.is_empty():
		Career.data = before
		fault = "化验批次的库存记录缺失，保留现场与账本"
		return false
	var truth := _truth(a)
	var q := float(a.quantity)
	var cert := {"assay": str(a.id), "fe": 1.0 - float(truth.impurity) - CARBON, "impurity": float(truth.impurity), "share": float(truth.share), "limit": LIMIT, "pass": bool(truth.pass)}
	if str(a.kind) == "describe":
		# the record it lacked: now it can be sorted (still unrated)
		lot.material_profile = {"version": 1, "nonmagnetic_share": float(truth.share), "basis": "assay_conservative"}
		lot.assay = cert
		lot.available = float(lot.available) + q
		actor.stock[str(lot.key)] = float(actor.stock.get(str(lot.key), 0.0)) + q
		a.result = "described"
	elif truth.pass:
		var identity := str(a.lot) + "/A1"
		var key := Exchange.lot_key("ferrous_scrap", 1)
		lot.consumed = float(lot.get("consumed", 0.0)) + q
		lot.assay = cert
		actor.lots[identity] = {"id": identity, "key": key, "available": q, "total": q, "origin": "assay", "parents": [{"source_id": str(a.lot), "quantity": q}], "assay": cert}
		actor.stock[key] = float(actor.stock.get(key, 0.0)) + q
		state.sources[identity] = {"quantity": q, "item": "ferrous_scrap", "grade": 1}
		var rows: Array = Career.data.get("material_batches", [])
		rows.append({"id": identity, "material": "ferrous_scrap", "grade": 1, "mass_t": q, "state": "assayed", "assay_id": str(a.id), "parent": str(a.lot)})
		Career.data.material_batches = rows
		a.result = "grade_1"
	else:
		lot.assay = cert
		lot.available = float(lot.available) + q
		actor.stock[str(lot.key)] = float(actor.stock.get(str(lot.key), 0.0)) + q
		a.result = "unrated"
	a.cert = cert
	a.state = "complete"
	a.elapsed = DURATION
	Exchange.sync_batches(Career.data, state)
	if not Career.save():
		Career.data = before
		waiting = "保存失败，化验结果未提交，稍后重试"
		return false
	waiting = ""
	return true


# the bench's state as the HUD/overview/tests read it
func checkpoint() -> bool:
	return Career.save() if running() else true


func _process(dt: float) -> void:
	if game == null or not game.in_berth() or fault != "":
		return
	if running():
		var a: Dictionary = Career.data.assay
		a.elapsed = minf(DURATION, float(a.get("elapsed", 0.0)) + dt)
		if float(a.elapsed) >= DURATION:
			_save_retry -= dt
			if _save_retry <= 0.0 and not _complete():
				_save_retry = 2.0
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "process", 30.0):
		queue_redraw()


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
	if game == null or not game.in_berth():
		return
	# 105 号: an assay bench (scripts/console_art.gd): the spectrometer's read-out is its screen, the
	# sample carousel turns on the bench top
	var at := site()
	var M := Geom.M
	var r := reading()
	var on := running()
	var t := float(data().get("elapsed", 0.0))
	var have := not data().is_empty()
	var spectrum := func(ci: CanvasItem, win: Rect2) -> void:
		# the emission lines, Fe strong; they settle as the reading does
		for i in 9:
			var x := win.position.x + (i + 0.5) * win.size.x / 9.0
			var h := 0.25 + 0.6 * absf(sin(i * 1.7 + 0.4))
			if i == 3 or i == 5:
				h = 0.95 * float(r[0]) if have else 0.2
			if on:
				h *= 0.75 + 0.25 * absf(sin(t * 6.0 + i))
			var col := Pal.tint(Pal.FLUID, 0.9, 1.3) if (i == 3 or i == 5) else Pal.tint(Pal.AIR, 0.45, 1.1)
			ci.draw_line(Vector2(x, win.end.y - 2), Vector2(x, win.end.y - 2 - h * win.size.y * 0.55), col, maxf(1.0, 0.04 * M))
	var work := not candidates().is_empty() and not on
	var info := {"screen": spectrum, "lines": [[Ops.w("铁 %.1f%%", "Fe %.1f%%") % (float(r[0]) * 100.0) if have else Ops.w("没有样品", "NO SAMPLE"), Pal.tint(Pal.AIR, 0.95, 1.2)],
		[Ops.w("杂质 %.1f%%", "IMPURITY %.1f%%") % (float(r[1]) * 100.0) if have else (Ops.w("有 %d 批待化验", "%d LOTS TO ASSAY") % candidates().size()), Pal.ink(0.7)]],
		"bar": float(r[2]) if on else -1.0, "lamp": "work" if on or work else "ok"}
	ConsoleArt.draw(ci, at, ConsoleArt.foot_at(at), Ops.w("化验位", "ASSAY BENCH"), Ops.w("[%s] 打开化验", "[%s] OPEN THE ASSAY") % Keys.label("use"), near(), info, Time.get_ticks_msec() * 0.001, "assay")
	# the carousel: six sample cups, the one being read lit
	var cc := at + Vector2(1.65, -0.22) * M
	ci.draw_arc(cc, 0.42 * M, 0.0, TAU, 24, Pal.ink(0.55), maxf(1.0, 0.04 * M), true)
	for i in 6:
		var a2 := TAU * i / 6.0 + (t * 0.6 if on else 0.0)
		var cp := cc + Vector2(cos(a2), sin(a2)) * 0.28 * M
		ci.draw_circle(cp, 0.08 * M, Pal.heat(1.0, 1.6) if on and i == 0 else Pal.ink(0.35))
