class_name Mill
# The processing district's rolling mill (74 号; 69 号 Q8 C): a tonne of grade-1 billet off its
# rack, rolled into plate or sections, back onto the racks. 8 MW on the grid's processing group;
# at full power about 40 s a tonne. Run from the district's business console.
#   Career.data.mill = {product, qty, state: "fetch" | "roll", left, total}
# 85 号 (user 2026-10-26: "怎么碾钢板……学学戴森球"): the mill stands in the district and is run at
# its own panel (scripts/mill_panel.gd): a recipe picked, one pass or rolling on while billet lasts.
#   Career.data.mill_cfg = {product, loop, made}

const PRODUCTS := {"plate": "steel_plate:1", "section": "steel_section:1"}
const FEED := "steel_billet:1"
const MW := 8.0
const ROLL_S := 40.0                   # s a tonne at full power
const BATCH := 1.0                     # t a pass


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func job() -> Dictionary:
	return Career.data.get("mill", {}) if Career.usable() and not Career.data.is_empty() else {}


static func busy() -> bool:
	return not job().is_empty()


static func _stock() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})


static func product_name(p: String) -> String:
	return w("钢板", "PLATE") if p == "plate" else w("型材", "SECTIONS")


# why a pass cannot start ("" = it can)
static func block(product: String) -> String:
	if Port.stage("process") < 1:
		return w("加工区还没修好", "THE PROCESSING DISTRICT IS NOT MENDED")
	if busy():
		return w("轧机正在轧%s", "THE MILL IS ROLLING %s") % product_name(str(job().product))
	if not PRODUCTS.has(product):
		return w("轧机只轧钢板和型材", "PLATE OR SECTIONS ONLY")
	if float(_stock().get(FEED, 0.0)) < BATCH - 0.0001:
		return w("仓库里钢坯（等级 1）不到 1 吨：先在加工区把钢锭炼成钢坯", "UNDER A TONNE OF GRADE-1 BILLET: MELT INGOTS INTO BILLETS FIRST")
	return ""


# a pass: the billet comes down from its rack first (73 号), then it is rolled
static func start(product: String) -> Dictionary:
	var why := block(product)
	if why != "":
		return {"ok": false, "reason": why}
	var before := Career.data
	Career.data = before.duplicate(true)
	var st := _stock()
	st[FEED] = float(st.get(FEED, 0.0)) - BATCH
	Career.data.mill = {"product": product, "qty": BATCH, "state": "fetch", "left": ROLL_S * BATCH, "total": ROLL_S * BATCH, "id": "MILL-%d" % int(Career.data.get("mill_n", 0))}
	Career.data.mill_n = int(Career.data.get("mill_n", 0)) + 1
	if Career.data.get("exchange", {}).has("actors"):
		Career.data.exchange.actors.company.stock = st
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true}


static func k(game) -> float:
	if game == null or not is_instance_valid(game):
		return 1.0
	return Grid.k(game, "mill")


static func cfg() -> Dictionary:
	if not Career.usable() or Career.data.is_empty():
		return {"product": "plate", "loop": false, "made": 0.0}
	if not Career.data.has("mill_cfg"):
		Career.data.mill_cfg = {"product": "plate", "loop": false, "made": 0.0}
	return Career.data.mill_cfg


static func set_product(p: String) -> void:
	if PRODUCTS.has(p):
		cfg().product = p
		Career.save()


static func set_loop(on: bool) -> void:
	cfg().loop = on
	Career.save()


static func feed_t() -> float:
	return float(_stock().get(FEED, 0.0))


static func made_t(p: String) -> float:
	return float(_stock().get(PRODUCTS.get(p, ""), 0.0))


# the pass under way, 0..1 (the rolling part; 0 while the billet is coming)
static func progress() -> float:
	var j := job()
	if j.is_empty() or str(j.state) != "roll":
		return 0.0
	return clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)


# t a minute at the power the mill has now
static func rate(game) -> float:
	return 60.0 / ROLL_S * BATCH * k(game)


# the machine's lamp and its reason, as a DSP-style building reads: run / wait / short / idle / off
static func lamp(game) -> Array:
	if Port.stage("process") < 1:
		return ["off", w("加工区还没修好", "THE DISTRICT IS NOT MENDED")]
	var j := job()
	if not j.is_empty():
		if str(j.state) == "fetch":
			return ["wait", w("等叉车送钢坯", "WAITING FOR THE BILLET")]
		if k(game) < 0.98:
			# 106 号: why, at the machine
			return ["short", Grid.short_text(game, "mill")]
		return ["run", w("正在轧%s", "ROLLING %s") % product_name(str(j.product))]
	if bool(cfg().loop) and feed_t() < BATCH - 0.0001:
		return ["wait", w("连续轧：仓库里钢坯不到 1 t，等钢坯", "ROLLING ON: UNDER A TONNE OF BILLET")]
	return ["idle", w("空闲", "IDLE")]


# the pass goes on; true when a tonne came off the mill
static func advance(game, dt: float) -> bool:
	var j := job()
	if j.is_empty():
		if Career.usable() and not Career.data.is_empty() and bool(cfg().loop) and block(str(cfg().product)) == "":
			start(str(cfg().product))
		elif Career.usable() and not Career.data.is_empty():
			_queue_pass()
		return false
	if str(j.state) == "fetch":
		var jid := "MILL:" + str(j.id)
		Warehouse.ask_out(jid, FEED, float(j.qty))
		if not Warehouse.ready(jid):
			return false
		Warehouse.consume(jid)
		j.state = "roll"
	j.left = float(j.left) - dt * k(game)
	if game != null and is_instance_valid(game):
		Grid.bill(game, "mill", dt)
	if float(j.left) > 0.0:
		return false
	var st := _stock()
	var key: String = PRODUCTS[str(j.product)]
	st[key] = float(st.get(key, 0.0)) + float(j.qty)
	if str(j.get("queue", "")) != "":
		ProcessQueue.rolled(str(j.queue), float(j.qty))
	Career.data.erase("mill")
	var c := cfg()
	c.made = float(c.get("made", 0.0)) + float(j.qty)
	# rolling on: the next pass as soon as there is billet
	if bool(c.loop) and block(str(c.product)) == "":
		start(str(c.product))
	Career.save()
	return true


# 106 号: a pass of a kept batch's billet into plate, by itself, when the mill has nothing else
static func _queue_pass() -> void:
	var e := ProcessQueue.next_roll()
	if e.is_empty() or block("plate") != "":
		return
	if start("plate").ok:
		Career.data.mill.queue = str(e.lot)
		Career.data.mill.ship = str(e.get("ship", ""))
		Career.save()


static func status() -> String:
	var j := job()
	if j.is_empty():
		return w("轧机空闲", "THE MILL IS IDLE")
	if str(j.state) == "fetch":
		var wt := Warehouse.wait_text("MILL:" + str(j.id))
		return w("轧机等钢坯：%s", "THE MILL WAITS FOR BILLET: %s") % (wt if wt != "" else w("叉车马上送到", "COMING"))
	return w("轧机正在轧%s · %d%% · 还剩约 %d 秒", "ROLLING %s · %d%% · ~%d s") % [product_name(str(j.product)), int(100.0 * (1.0 - float(j.left) / maxf(0.01, float(j.total)))), ceili(float(j.left))]


static func grid_loads() -> Array:
	var j := job()
	if j.is_empty() or str(j.state) != "roll":
		return []
	return [{"id": "mill", "name": w("轧机", "ROLLING MILL"), "group": "process", "rated": MW, "demand": MW, "mw_now": -1.0, "state": "run"}]
