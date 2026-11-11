class_name GasLine
# The processing district's gas line (76 号, G6.3; 02 号 §5): what the hoses really took off a
# ship, by species, comes home as a batch of known mixed gas (no longer cashed at settlement);
# known mixed gas is also bought from a belt supplier. A batch is purified and separated (6 MW)
# into oxygen, nitrogen and what is left — mass in = mass out, to the gram; contamination lowers
# the purity, a culture-tainted source can never be life-support grade, hydrogen stops the batch
# (fuel hazard: controlled disposal only). Oxygen is liquefied (4 MW) into the LOX tank — the
# phase changes, the mass does not; a full tank stops the liquefier. The tank always leaks heat:
# the cold box (0.3 MW) recondenses the boil-off while it has power, without it the oxygen boils
# off and is vented (logged). 132 号 (user 2026-11-07 "燃料外运也删了"; 128 号 §六): no passing ships
# buy gas any more — LOX and LH2 are sold by the exchange and the orders; an old save's supply
# orders and what they held back are dropped as it is read.
#   Career.data.gas = {batches, o2: {ind, ok, ls}, n2, residue, waste, lox: {kg, grade}, job,
#                      auto, made, vented, disposed, supplier, t, n, log}

const SEP_MW := 6.0
const SEP_S_PER_T := 30.0          # s to separate a tonne at full power
const LIQ_MW := 4.0
const LIQ_S_PER_T := 25.0          # s to liquefy a tonne of oxygen at full power
const HOLD_MW := 0.3               # the cold box holding the tank
const TANK_CAP := 20000.0          # kg of LOX the tank takes
const BOIL := 0.0008               # of the tank's LOX a second boiling off with no cooling
const O2_RECOVERY := 0.9           # of the oxygen in a batch the column gets out as product
const N2_RECOVERY := 0.95
const IND_PURITY := 0.99
const LS_PURITY := 0.995
const LS_TEST_FEE := 300.0
const LS_TEST_S := 10.0
const DISPOSE_PER_T := 400.0       # $ a tonne of tainted or fuel-bearing gas, controlled disposal
const MIXED_PRICE := 60.0          # $ a tonne of known mixed gas from the belt supplier
const SUPPLY_MAX_T := 10.0         # t an order
const SUPPLY_S := 60.0             # s the supplier's freighter takes
const AUTO_AFTER := 2              # batches separated by hand before automation may be set
# 2026-11-11 (user: "我在拆船厂拆船收集的气体，存进罐子后，会通过管道流到加工区"): a ship's gas
# goes from the berth's recovery receiver along the port's pipe rack to the line's feed drum
# (scripts/gas_pipes.gd draws it); it can be separated once it has arrived. 0: at once (old tests).
static var TRANSIT_S := 30.0
# 2026-11-11 (user: "要，按我说的改"): the tug station's cryo collection tanks (TugYard.cryo) are
# piped on to the line's LH2 / LOX tanks, CRYO_S s a charge; d.cryo_pipe = [{kind, kg, t_left, t_total}]
static var CRYO_S := 25.0
const LH2_CAP := 8000.0            # kg the line's LH2 tank takes (the console's gauge)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func built() -> bool:
	return Career.usable() and not Career.data.is_empty() and Repair.done("gas_line")


static func tank_built() -> bool:
	return Career.usable() and not Career.data.is_empty() and Repair.done("lox_tank")


static func keeping() -> bool:
	return built()


static func data() -> Dictionary:
	if not Career.data.has("gas") or Career.data.gas.is_empty():
		Career.data.gas = {"batches": [], "o2": {"ind": 0.0, "ok": 0.0, "ls": 0.0}, "n2": 0.0, "residue": 0.0, "waste": 0.0,
			"lox": {"kg": 0.0, "grade": "ls"}, "job": {}, "liq": {}, "auto": {"process": false, "liquefy": false, "keep_o2": 500.0,
			}, "made": 0, "vented": 0.0, "disposed": 0.0,
			"supplier": {"stock": 30.0, "t": 0.0}, "orders": [], "t": 0.0, "n": 0, "log": [], "test": {}, "earned": 0.0, "spent": 0.0}
	var d: Dictionary = Career.data.gas
	# 132 号: an old save's passing-ship orders (and the LOX and gas they held back) are dropped
	if d.has("callers"):
		d.erase("callers")
		for k in ["supply", "min_price", "max_open", "keep_lox"]:
			d.get("auto", {}).erase(k)
	# 132 号 (user 2026-11-07): no automatic feed buying either — an old save's switch and bounds go
	for k in ["buy", "buy_max_price", "buy_t", "cash_floor"]:
		d.get("auto", {}).erase(k)
	return d


static func _cash(delta: float) -> void:
	var d := data()
	if delta >= 0.0:
		d.earned = float(d.get("earned", 0.0)) + delta
	else:
		d.spent = float(d.get("spent", 0.0)) - delta
	Career.data.money = float(Career.data.get("money", 0.0)) + delta
	if Career.data.get("exchange", {}).get("actors", {}).has("company"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)


static func _say(s: String) -> void:
	var d := data()
	d.log.append(s)
	if d.log.size() > 8:
		d.log = d.log.slice(d.log.size() - 8)


static func mass(b: Dictionary) -> float:
	var m := 0.0
	for sp in b.kg:
		m += float(b.kg[sp])
	return m + float(b.get("bio", 0.0))


static func batch(id: String) -> Dictionary:
	for b in data().batches:
		if str(b.id) == id:
			return b
	return {}


# ---------------------------------------------------------------- where the gas comes from

# a ship's hoses at settlement: one batch, with where it came from and what is in it
static func receive(take: Dictionary, src: String, by_pipe := true) -> Dictionary:
	var kg := {}
	for sp in ["o2", "n2", "ar", "co2", "h2", "he"]:
		if float(take.get(sp, 0.0)) > 0.0:
			kg[sp] = float(take[sp])
	if kg.is_empty():
		return {}
	var d := data()
	d.n = int(d.n) + 1
	var b := {"id": "GAS-%03d" % int(d.n), "src": src, "kg": kg, "bio": float(take.get("bio", 0.0)), "certified": false,
		"hazard": "fuel" if float(kg.get("h2", 0.0)) > 0.0 else "", "state": "raw"}
	if by_pipe and TRANSIT_S > 0.0:
		b.state = "transit"
		b.t_left = TRANSIT_S
		b.t_total = TRANSIT_S
	d.batches.append(b)
	return b


# known mixed gas bought from the belt supplier: certified air, on its way for a minute
static func buy_block(t: float) -> String:
	if not built():
		return w("先修好加工区的气体线", "BUILD THE GAS LINE FIRST")
	if t <= 0.0 or t > SUPPLY_MAX_T:
		return w("一次最多订 %.0f 吨", "UP TO %.0f t AN ORDER") % SUPPLY_MAX_T
	if float(data().supplier.stock) < t:
		return w("供应商只剩 %.1f 吨", "THE SUPPLIER HAS %.1f t LEFT") % float(data().supplier.stock)
	if float(Career.data.get("money", 0.0)) < t * MIXED_PRICE:
		return w("钱不够", "NOT ENOUGH CASH")
	return ""


static func buy_mixed(t: float) -> Dictionary:
	var why := buy_block(t)
	if why != "":
		return {"ok": false, "reason": why}
	var d := data()
	d.supplier.stock = float(d.supplier.stock) - t
	_cash(-t * MIXED_PRICE)
	d.orders.append({"t": t, "left": SUPPLY_S})
	Career.save()
	return {"ok": true}


# ---------------------------------------------------------------- separation

static func assess(b: Dictionary) -> Dictionary:
	var m := maxf(mass(b), 0.001)
	var taint := float(b.get("bio", 0.0)) / m
	var purity := clampf(0.996 - taint * 5.0, 0.0, 0.996)
	return {"taint": taint, "purity": purity, "ls_ok": b.get("certified", false) and float(b.get("bio", 0.0)) <= 0.0 and purity >= LS_PURITY}


static func sep_block(id: String) -> String:
	var b := batch(id)
	if not built():
		return w("先修好加工区的气体线", "BUILD THE GAS LINE FIRST")
	if b.is_empty() or str(b.state) != "raw":
		return w("这一批不在待处理状态", "THAT BATCH IS NOT WAITING")
	if str(b.hazard) == "fuel":
		return w("燃料危险：含氢，不能按普通空气分离，只能受控处置", "FUEL HAZARD: HYDROGEN — CONTROLLED DISPOSAL ONLY")
	if assess(b).taint > 0.02:
		return w("污染超限（%.1f%%）：只能受控处置", "TOO TAINTED (%.1f%%): CONTROLLED DISPOSAL ONLY") % (assess(b).taint * 100.0)
	if not data().job.is_empty():
		return w("气体线正在%s", "THE GAS LINE IS BUSY: %s") % job_text()
	return ""


static func separate(id: String) -> Dictionary:
	var why := sep_block(id)
	if why != "":
		return {"ok": false, "reason": why}
	var b := batch(id)
	b.state = "processing"
	var t := mass(b) / 1000.0
	data().job = {"kind": "sep", "id": id, "left": SEP_S_PER_T * t, "total": SEP_S_PER_T * t}
	Career.save()
	return {"ok": true}


# the column's split: every gram into a product, the residue or the tainted waste
static func split(b: Dictionary) -> Dictionary:
	var a := assess(b)
	var o2 := float(b.kg.get("o2", 0.0))
	var n2 := float(b.kg.get("n2", 0.0))
	var o2_out := o2 * O2_RECOVERY if a.purity >= IND_PURITY else 0.0
	var n2_out := n2 * N2_RECOVERY
	var waste := float(b.get("bio", 0.0))
	var residue := mass(b) - o2_out - n2_out - waste
	return {"o2": o2_out, "n2": n2_out, "residue": residue, "waste": waste, "purity": a.purity, "ls_ok": a.ls_ok}


static func _finish_sep(b: Dictionary) -> void:
	var r := split(b)
	var d := data()
	if bool(r.ls_ok):
		d.o2.ok = float(d.o2.ok) + float(r.o2)
	else:
		d.o2.ind = float(d.o2.ind) + float(r.o2)
	d.n2 = float(d.n2) + float(r.n2)
	d.residue = float(d.residue) + float(r.residue)
	d.waste = float(d.waste) + float(r.waste)
	b.state = "done"
	b.out = r
	d.made = int(d.made) + 1
	_say(w("%s 分离完：氧 %.0f kg（纯度 %.2f%%）、氮 %.0f kg、剩余气 %.0f kg", "%s SEPARATED: O₂ %.0f kg (%.2f%%), N₂ %.0f kg, RESIDUE %.0f kg") % [str(b.id), float(r.o2), float(r.purity) * 100.0, float(r.n2), float(r.residue)])


# a tainted or fuel-bearing batch, or the tainted waste: handed over for controlled disposal
static func dispose(id: String) -> Dictionary:
	var b := batch(id)
	if b.is_empty() or str(b.state) != "raw":
		return {"ok": false, "reason": w("这一批不在待处理状态", "NOT WAITING")}
	var fee := mass(b) / 1000.0 * DISPOSE_PER_T
	if float(Career.data.get("money", 0.0)) < fee:
		return {"ok": false, "reason": w("处置费 %s，钱不够", "DISPOSAL %s: NOT ENOUGH CASH") % Pal.money(fee)}
	_cash(-fee)
	b.state = "disposed"
	data().disposed = float(data().disposed) + mass(b)
	Career.save()
	return {"ok": true, "fee": fee}


static func dispose_waste() -> Dictionary:
	var d := data()
	var fee := float(d.waste) / 1000.0 * DISPOSE_PER_T
	if float(d.waste) <= 0.0:
		return {"ok": false, "reason": w("没有污染剩余物", "NO TAINTED WASTE")}
	if float(Career.data.get("money", 0.0)) < fee:
		return {"ok": false, "reason": w("钱不够", "NOT ENOUGH CASH")}
	_cash(-fee)
	d.disposed = float(d.disposed) + float(d.waste)
	d.waste = 0.0
	Career.save()
	return {"ok": true, "fee": fee}


# the harmless residue (argon, CO₂, the oxygen the column lets go) may be vented: it is logged
static func vent_residue() -> Dictionary:
	var d := data()
	if float(d.residue) <= 0.0:
		return {"ok": false, "reason": w("没有剩余气", "NO RESIDUE")}
	d.vented = float(d.vented) + float(d.residue)
	d.residue = 0.0
	Career.save()
	return {"ok": true}


# the life-support test: oxygen from a certified, clean source, tested, becomes life-support grade
static func ls_test() -> Dictionary:
	var d := data()
	if float(d.o2.ok) <= 0.0:
		return {"ok": false, "reason": w("没有可以送检的氧（要来源有认证、无生物污染、纯度 ≥ 99.5%）", "NO OXYGEN FIT FOR THE TEST")}
	if not d.test.is_empty():
		return {"ok": false, "reason": w("正在检测", "TESTING")}
	if float(Career.data.get("money", 0.0)) < LS_TEST_FEE:
		return {"ok": false, "reason": w("检测费不够", "NOT ENOUGH CASH")}
	_cash(-LS_TEST_FEE)
	d.test = {"kg": float(d.o2.ok), "left": LS_TEST_S}
	d.o2.ok = 0.0
	Career.save()
	return {"ok": true}


# ---------------------------------------------------------------- liquefaction and the tank

static func o2_free(grade: String = "any") -> float:
	var d := data()
	if grade == "ls":
		return maxf(0.0, float(d.o2.ls))
	return maxf(0.0, float(d.o2.ind) + float(d.o2.ok) + float(d.o2.ls))


static func space() -> float:
	return maxf(0.0, TANK_CAP - float(data().lox.kg))


static func liq_block(kg: float) -> String:
	if not tank_built():
		return w("先修好液氧储罐", "BUILD THE LOX TANK FIRST")
	if not data().get("liq", {}).is_empty():
		return w("冷箱正在液化", "THE COLD BOX IS BUSY")
	if space() < kg - 0.01:
		return w("储罐满了（还能装 %.0f kg）", "THE TANK IS FULL (%.0f kg OF ROOM)") % space()
	if o2_free() < kg - 0.01:
		return w("气态氧不够 %.0f kg（预留给客户的不能动）", "UNDER %.0f kg OF OXYGEN FREE") % kg
	return ""


# a quantity of oxygen into the cold box: industrial first, the life-support last
static func liquefy(kg: float) -> Dictionary:
	var why := liq_block(kg)
	if why != "":
		return {"ok": false, "reason": why}
	var d := data()
	var left := kg
	var grade := "ls"
	for g in ["ind", "ok", "ls"]:
		var take := minf(left, float(d.o2[g]))
		if take > 0.0:
			d.o2[g] = float(d.o2[g]) - take
			left -= take
			if g != "ls":
				grade = "ind"
	# the cold box is its own machine: it runs while the column separates the next batch
	d.liq = {"kind": "liq", "kg": kg, "grade": grade, "left": LIQ_S_PER_T * kg / 1000.0, "total": LIQ_S_PER_T * kg / 1000.0}
	Career.save()
	return {"ok": true}


static func _finish_liq(j: Dictionary) -> void:
	var d := data()
	var kg := float(j.kg)
	# the tank takes what fits; what does not stays oxygen gas (nothing made out of nothing)
	var fit := minf(kg, space())
	if float(d.lox.kg) <= 0.0:
		d.lox.grade = str(j.grade)
	elif str(j.grade) == "ind":
		d.lox.grade = "ind"
	d.lox.kg = float(d.lox.kg) + fit
	d.o2.ind = float(d.o2.ind) + (kg - fit)
	_say(w("液化 %.0f kg 进储罐（%s）", "%.0f kg LIQUEFIED (%s)") % [fit, grade_name(str(d.lox.grade))])


static func grade_name(g: String) -> String:
	return w("生命支持级", "LIFE-SUPPORT") if g == "ls" else w("工业级", "INDUSTRIAL")


# ---------------------------------------------------------------- the grid

static func grid_loads() -> Array:
	var out: Array = []
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("gas"):
		return out
	var d := data()
	if not d.job.is_empty():
		out.append({"id": "gas_sep", "name": w("气体分离", "GAS SEPARATION"), "group": "process", "rated": SEP_MW, "demand": SEP_MW, "mw_now": -1.0, "state": "run"})
	if not d.get("liq", {}).is_empty():
		out.append({"id": "gas_liq", "name": w("液化冷箱", "LIQUEFIER"), "group": "process", "rated": LIQ_MW, "demand": LIQ_MW, "mw_now": -1.0, "state": "run"})
	if float(d.lox.kg) > 0.0:
		out.append({"id": "lox_hold", "name": w("液氧储罐保冷", "LOX TANK COOLING"), "group": "process", "rated": HOLD_MW, "demand": HOLD_MW, "mw_now": -1.0, "state": "run"})
	return out


static func k(game, id: String) -> float:
	if game == null or not is_instance_valid(game):
		return 1.0
	return Grid.k(game, id)


# ---------------------------------------------------------------- the clock

# returns lines worth telling
static func advance(game, dt: float) -> Array:
	var said: Array = []
	if not Career.usable() or Career.data.is_empty() or not built():
		return said
	var d := data()
	# the supplier's freighters
	d.supplier.t = float(d.supplier.t) + dt
	if float(d.supplier.t) >= 300.0:
		d.supplier.t = 0.0
		d.supplier.stock = minf(30.0, float(d.supplier.stock) + 10.0)
	for o in d.orders.duplicate():
		o.left = float(o.left) - dt
		if float(o.left) <= 0.0:
			d.orders.erase(o)
			var tkg := float(o.t) * 1000.0
			var b := receive({"o2": tkg * 0.21, "n2": tkg * 0.78, "ar": tkg * 0.01}, w("小行星带气体供应商", "BELT GAS SUPPLIER"), false)
			b.certified = true
			said.append(w("外购的 %.1f 吨混合气到了：%s", "%.1f t OF MIXED GAS IN: %s") % [float(o.t), str(b.id)])
	_cryo_pipe(dt, said)
	# a ship's gas on its way along the pipe rack to the feed drum
	for b in d.batches:
		if str(b.state) == "transit":
			b.t_left = float(b.get("t_left", 0.0)) - dt
			if float(b.t_left) <= 0.0:
				b.state = "raw"
				b.erase("t_left")
				said.append(w("%s 经管道送到加工区进气罐", "%s IN AT THE FEED DRUM") % str(b.id))
	# what its machines draw is paid for (own sets at fuel cost, the shore line dear)
	if game != null and is_instance_valid(game):
		for l in grid_loads():
			d.spent = float(d.get("spent", 0.0)) + Grid.bill(game, str(l.id), dt)
	# the column's batch and the cold box's charge, each at what the grid gives it
	var j: Dictionary = d.job
	if not j.is_empty():
		j.left = float(j.left) - dt * k(game, "gas_sep")
		if float(j.left) <= 0.0:
			d.job = {}
			var b2 := batch(str(j.id))
			if not b2.is_empty():
				_finish_sep(b2)
			said.append(str(d.log.back()))
	if not d.has("liq"):
		d.liq = {}
	var lj: Dictionary = d.liq
	if not lj.is_empty():
		lj.left = float(lj.left) - dt * k(game, "gas_liq")
		if float(lj.left) <= 0.0:
			d.liq = {}
			_finish_liq(lj)
			said.append(str(d.log.back()))
	# the life-support test
	if not d.test.is_empty():
		d.test.left = float(d.test.left) - dt
		if float(d.test.left) <= 0.0:
			d.o2.ls = float(d.o2.ls) + float(d.test.kg)
			said.append(w("生命支持检测通过：%.0f kg 氧", "LIFE-SUPPORT TEST PASSED: %.0f kg") % float(d.test.kg))
			d.test = {}
	# the tank: heat leaks in all the time; the cold box takes it back out while it has power
	if float(d.lox.kg) > 0.0:
		var boil := float(d.lox.kg) * BOIL * dt
		var lost := boil * (1.0 - k(game, "lox_hold"))
		if lost > 0.0:
			d.lox.kg = maxf(0.0, float(d.lox.kg) - lost)
			d.vented = float(d.vented) + lost
	_auto(game)
	return said


# ---------------------------------------------------------------- automation (within the player's bounds)

static func auto_block(key: String) -> String:
	if key == "process" and int(data().made) < AUTO_AFTER:
		return w("先手动处理 %d 批（已处理 %d 批）", "SEPARATE %d BATCHES BY HAND FIRST (%d DONE)") % [AUTO_AFTER, int(data().made)]
	if key == "liquefy" and not tank_built():
		return w("先修好液氧储罐", "BUILD THE LOX TANK FIRST")
	return ""


static func set_auto(key: String, value) -> Dictionary:
	var a: Dictionary = data().auto
	if not key in ["process", "liquefy"] and not a.has(key):
		return {"ok": false, "reason": "?"}
	if value is bool and value:
		var why := auto_block(key)
		if why != "":
			return {"ok": false, "reason": why}
	a[key] = value
	Career.save()
	return {"ok": true}


# a standard batch is known air, no fuel, under the taint limit; anything else waits for the player
static func standard(b: Dictionary) -> bool:
	return str(b.state) == "raw" and str(b.hazard) == "" and assess(b).taint <= 0.02 and float(b.kg.get("o2", 0.0)) > 0.0


static func _auto(_game) -> void:
	var d := data()
	var a: Dictionary = d.auto
	if a.process and d.job.is_empty():
		for b in d.batches:
			if standard(b):
				separate(str(b.id))
				break
	if a.liquefy and tank_built() and d.get("liq", {}).is_empty():
		var spare := o2_free() - float(a.keep_o2)
		var room := space() - TANK_CAP * 0.1
		var kg := minf(1000.0, minf(spare, room))
		if kg >= 200.0:
			liquefy(kg)
			return



static func status() -> String:
	if not built():
		return w("气体线没修", "NO GAS LINE")
	var d := data()
	return w("气态氧 %.0f kg（其中生命支持级 %.0f）· 氮 %.0f kg · 液氧 %.0f / %.0f kg（%s）· 剩余气 %.0f kg · 污染剩余 %.0f kg", "O₂ %.0f kg (LS %.0f) · N₂ %.0f kg · LOX %.0f / %.0f kg (%s) · RESIDUE %.0f kg · TAINTED %.0f kg") % [
		float(d.o2.ind) + float(d.o2.ok) + float(d.o2.ls), float(d.o2.ls), float(d.n2), float(d.lox.kg), TANK_CAP, grade_name(str(d.lox.grade)), float(d.residue), float(d.waste)]


# the tug station's LH2 / LOX on their way to the line's tanks (kg), by kind
static func cryo_piping(kind: String) -> float:
	var kg := 0.0
	for c in data().get("cryo_pipe", []):
		if str(c.kind) == kind:
			kg += float(c.kg)
	return kg


static func _room(kind: String) -> float:
	var d := data()
	if kind == "lox":
		return 0.0 if not tank_built() else maxf(0.0, TANK_CAP - float(d.lox.kg) - cryo_piping("lox"))
	return maxf(0.0, LH2_CAP - float(d.get("lh2", {}).get("kg", 0.0)) - cryo_piping("lh2"))


static func _cryo_pipe(dt: float, said: Array) -> void:
	var d := data()
	if not d.has("cryo_pipe"):
		d.cryo_pipe = []
	# a tank with something in it and nothing of its kind on the way: it is sent, what fits
	for kind in ["lh2", "lox"]:
		var have := float(TugYard.cryo()[kind])
		if have < 1.0 or cryo_piping(kind) > 0.0:
			continue
		var kg := minf(have, _room(kind))
		if kg < 1.0:
			continue
		TugYard.set_cryo(kind, have - kg)
		d.cryo_pipe.append({"kind": kind, "kg": kg, "t_left": CRYO_S, "t_total": CRYO_S})
	for c in d.cryo_pipe.duplicate():
		c.t_left = float(c.t_left) - dt
		if float(c.t_left) > 0.0:
			continue
		d.cryo_pipe.erase(c)
		if str(c.kind) == "lox":
			d.lox.grade = "ind"           # off a hulk: industrial until tested
			d.lox.kg = float(d.lox.kg) + float(c.kg)
		else:
			if not d.has("lh2"):
				d.lh2 = {"kg": 0.0}
			d.lh2.kg = float(d.lh2.get("kg", 0.0)) + float(c.kg)
		said.append(w("拖船站的%s %.0f kg 经管道送到加工区储罐", "%.0f kg OF %s IN FROM THE TUG STATION") % ([("液氢" if str(c.kind) == "lh2" else "液氧"), float(c.kg)] if Txt.zh else [float(c.kg), str(c.kind).to_upper()]))


static func job_text() -> String:
	var parts: Array = []
	for c in data().get("cryo_pipe", []):
		parts.append(w("管道转运 %s %.0f kg · %d%%", "PIPING %s %.0f kg · %d%%") % [("液氢" if str(c.kind) == "lh2" else "液氧") if Txt.zh else str(c.kind).to_upper(), float(c.kg), int(100.0 * (1.0 - float(c.t_left) / maxf(0.01, float(c.t_total))))])
	for b in data().batches:
		if str(b.state) == "transit":
			parts.append(w("管道转运 %s · %d%%", "PIPING %s · %d%%") % [str(b.id), int(100.0 * (1.0 - float(b.get("t_left", 0.0)) / maxf(0.01, float(b.get("t_total", TRANSIT_S)))))])
	var j: Dictionary = data().job
	if not j.is_empty():
		parts.append(w("分离 %s · %d%%", "SEPARATING %s · %d%%") % [str(j.id), int(100.0 * (1.0 - float(j.left) / maxf(0.01, float(j.total))))])
	var lj: Dictionary = data().get("liq", {})
	if not lj.is_empty():
		parts.append(w("液化 %.0f kg · %d%%", "LIQUEFYING %.0f kg · %d%%") % [float(lj.kg), int(100.0 * (1.0 - float(lj.left) / maxf(0.01, float(lj.total))))])
	return w("空闲", "IDLE") if parts.is_empty() else "；".join(parts)
