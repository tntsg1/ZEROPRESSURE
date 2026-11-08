class_name ProcessQueue
# 106 号 (10-29 问答 Q2 A): the ingots a settlement kept to be processed, by the ship they came
# from. The processing district takes them in turn by itself: the arc furnace melts them into
# billet a heat at a time (scripts/industrial_heat.gd, the same heats the furnace desk runs), the
# rolling mill rolls that billet into plate; the baskets, the stacks and the racks are labelled
# with the ship. Nothing else of the books changes: the ingots stay the company's lots until a
# heat takes them, as they would for a heat started by hand.
#   Career.data.process_queue = [{lot, ship, job, t, melted, rolled}]   t: tonnes of ingot

const HEAT_T := 2.0          # t a heat (the furnace desk's own most)
const HEAT_MIN := 0.25       # t: what is less than a heat's least is left in the warehouse


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func entries() -> Array:
	return Career.data.get("process_queue", []) if not Career.data.is_empty() else []


static func add(lot: String, ship: String, job: String, t: float) -> void:
	var q: Array = Career.data.get("process_queue", [])
	q.append({"lot": lot, "ship": ship, "job": job, "t": snappedf(t, 0.001), "melted": 0.0, "rolled": 0.0, "use": {"kind": "keep"}, "mould": "billet", "added": _clock()})
	Career.data.process_queue = q


# 128 号 第 4 段: a batch from the warehouse ("炼成钢坯" / an order card): no lot of its own — the heat
# takes the company's free ingots — with its use (order / sell / keep) and its mould
static func add_job(key: String, t: float, use: Dictionary, mould: String) -> Dictionary:
	var q: Array = Career.data.get("process_queue", [])
	var n := int(Career.data.get("pq_seq", 0)) + 1
	Career.data.pq_seq = n
	var e := {"lot": "PQ%d" % n, "key": key, "ship": "", "job": "", "t": snappedf(t, 0.001), "melted": 0.0, "rolled": 0.0, "use": use, "mould": mould, "added": _clock()}
	q.append(e)
	Career.data.process_queue = q
	return e


static func _clock() -> float:
	return float(Time.get_ticks_msec()) / 1000.0 + float(Career.data.get("pq_seq", 0)) * 0.001


static func open_entries() -> Array:
	return entries().filter(func(e): return not finished(e))


# 128 号 第 4 段: drag a batch to place `to` among those still to do
static func move_to(lot: String, to: int) -> int:
	var q: Array = Career.data.get("process_queue", [])
	var open: Array = q.filter(func(e): return not finished(e))
	var e := _entry(lot)
	var at := open.find(e)
	if at < 0:
		return -1
	to = clampi(to, 0, open.size() - 1)
	if to == at:
		return to
	open.remove_at(at)
	open.insert(to, e)
	var done: Array = q.filter(func(x): return finished(x))
	Career.data.process_queue = done + open
	return to


# the first entry with ingot still to melt
static func next_melt() -> Dictionary:
	for e in entries():
		if float(e.t) - float(e.melted) >= HEAT_MIN:
			return e
	return {}


# 108 号 (remote, the processing queue): move a batch among those still to do — dir -1 up, 1 down,
# -99 to the front; returns its new place among them (-1: nothing moved)
static func move(lot: String, dir: int) -> int:
	var q: Array = Career.data.get("process_queue", [])
	var open: Array = q.filter(func(e): return not finished(e))
	var e := _entry(lot)
	var at := open.find(e)
	if at < 0:
		return -1
	var to := 0 if dir == -99 else clampi(at + dir, 0, open.size() - 1)
	if to == at:
		return -1
	var other: Dictionary = open[to]
	q.erase(e)
	var k := q.find(other)
	q.insert(k if to < at else k + 1, e)
	Career.data.process_queue = q
	return to


# the label the works hang on a basket / a stack: "GR-7 · 12.4 t"
static func tag(e: Dictionary) -> String:
	if e.is_empty():
		return ""
	if str(e.get("ship", "")) == "":
		return w("钢锭 %.1f t", "INGOT %.1f t") % float(e.get("t", 0.0))
	return "%s · %.1f t" % [Methods.ship_label(str(e.get("ship", ""))), float(e.get("t", 0.0))]


static func _entry(lot: String) -> Dictionary:
	for e in entries():
		if str(e.lot) == lot:
			return e
	return {}


# a heat took t of the lot into the furnace (scripts/industrial_heat.gd begin)
static func charged(lot: String, t: float) -> void:
	var e := _entry(lot)
	if not e.is_empty():
		e.melted = snappedf(minf(float(e.t), float(e.melted) + t), 0.001)


# a heat of the lot was tapped and its billet received in the warehouse
static func tapped(lot: String, t: float, grade: int) -> void:
	var e := _entry(lot)
	if e.is_empty():
		return
	e.billet = snappedf(float(e.get("billet", 0.0)) + t, 0.001)
	# 128 号 第 4 段: only square billet feeds the mill; a batch kept from the warehouse is not rolled
	if grade == 1 and str(e.get("mould", "billet")) == "billet" and str(e.get("key", "")) == "":
		e.billet1 = snappedf(float(e.get("billet1", 0.0)) + t, 0.001)


# the first entry with a tonne of its grade-1 billet still to roll (the mill's feed)
static func next_roll() -> Dictionary:
	for e in entries():
		if float(e.get("billet1", 0.0)) - float(e.get("rolled", 0.0)) >= Mill.BATCH - 0.0001:
			return e
	return {}


static func rolled(lot: String, t: float) -> void:
	var e := _entry(lot)
	if not e.is_empty():
		e.rolled = snappedf(float(e.get("rolled", 0.0)) + t, 0.001)


# all melted and rolled (what can be): off the list after a while, kept for the books meanwhile
static func finished(e: Dictionary) -> bool:
	return float(e.t) - float(e.melted) < HEAT_MIN and float(e.get("billet1", 0.0)) - float(e.get("rolled", 0.0)) < Mill.BATCH - 0.0001 and float(e.get("billet", 0.0)) >= float(e.melted) - 0.001


# the queue's state in a line, for the district's boards: "GR-7 · 12.4 t：已熔 4.0 t，已轧 2.0 t"
static func line(e: Dictionary) -> String:
	return w("%s：已熔 %.1f t · 已轧钢板 %.1f t", "%s: %.1f t melted · %.1f t rolled") % [tag(e), float(e.melted), float(e.get("rolled", 0.0))]


# the entry the mill or the furnace works on now (for the labels)
static func of_lot(lot: String) -> Dictionary:
	return _entry(lot)
