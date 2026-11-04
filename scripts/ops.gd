class_name Ops
# The port's operations overview (design/成长版本/G5-G7_工业港成长重设计_2026-10-22/22_*):
# four cells for what the port is doing now (grid, shipping, berth, production) and
# the few things waiting on the operator. Everything is read from the career and,
# when the berth scene is up, from its live machines; nothing here is invented.
# A cell or a decision carries `go`, where the terminal takes the operator:
#   "tab:N"          a terminal page          "route:KEY"  a node on the growth page
#   "exchange"       the exchange             "clients"    the exchange's industrial clients
#   "site:heat|sort" a machine on site (said, not opened: Q30 wants hands on it)

const Exchange = preload("res://scripts/industrial_exchange.gd")
const Assay = preload("res://scripts/industrial_assay.gd")
const SORT_MW := 0.24          # the sorting line's rated drive (scripts/sort_panel.gd)
const DONE := ["complete", "cancelled", "written_off"]
const MAX_DECISIONS := 5

enum { DANGER, TODO, CHANCE }


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func item_name(key: String) -> String:
	var item := key.split(":")[0]
	var grade := key.split(":")[1] if key.find(":") >= 0 else "0"
	var names := {"mixed_metal": ["未分选金属", "MIXED METAL"], "ferrous_scrap": ["黑色炉料", "FERROUS SCRAP"], "nonferrous_mix": ["有色混合", "NONFERROUS MIX"], "steel_billet": ["钢坯", "STEEL BILLET"], "steel_plate": ["钢板", "STEEL PLATE"], "steel_section": ["型材", "STEEL SECTIONS"]}
	# 64 号: the grade-1 ferrous feed is the berth's cast ingot, called so
	if key == Exchange.INGOT and Exchange.INGOTS:
		return w("钢锭", "STEEL INGOT")
	var n: Array = names.get(item, [item, item])
	return "%s %s" % [n[0] if Txt.zh else n[1], (w("未评级", "UNRATED") if grade == "0" else w("等级 ", "GRADE ") + grade)]


static func batch_state(b: Dictionary) -> String:
	if b.is_empty():
		return w("空闲", "IDLE")
	var phases := {"raw_transport": ["原料运输", "FEED IN TRANSIT"], "raw_return": ["原料返仓", "FEED RETURNING"], "processing": ["加工中", "PROCESSING"], "product_transport": ["产物返仓", "PRODUCT RETURNING"], "complete": ["空闲", "IDLE"], "cancelled": ["空闲", "IDLE"], "written_off": ["空闲", "IDLE"]}
	var p: Array = phases.get(str(b.get("state", "")), [str(b.get("state", "")), str(b.get("state", "")).to_upper()])
	return p[0] if Txt.zh else p[1]


static func _busy(b: Dictionary) -> bool:
	return not b.is_empty() and str(b.get("state", "")) not in DONE


# 61 号 (60 号 Q8): what the home shows — only what is actually wrong, each in one plain sentence
static func problems(game) -> Array:
	var out: Array = []
	for d in decisions(game):
		if int(d.get("level", TODO)) == DANGER:
			out.append(d)
	return out


static func _stock() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {}).get(Exchange.PLAYER, {}).get("stock", {})


static func _stock_t(key: String) -> float:
	return float(_stock().get(key, 0.0))


# the company's matched trades not yet delivered: [incoming, outgoing]
static func transit() -> Array:
	var inc := 0
	var out := 0
	for t in Career.data.get("exchange", {}).get("trades", []):
		if str(t.get("state", "")) == "delivered":
			continue
		if t.get("buyer", "") == Exchange.PLAYER:
			inc += 1
		elif t.get("seller", "") == Exchange.PLAYER:
			out += 1
	return [inc, out]


static func energy_due() -> float:
	var due := 0.0
	for key in ["industrial_heat", "industrial_sort"]:
		var b: Dictionary = Career.data.get(key, {})
		if _busy(b):
			due += float(b.get("energy_debt", 0.0))
	return due


# what the berth's machines draw now (MW); only real, running loads
static func load_mw(game) -> float:
	var mw := 0.0
	if game == null or not is_instance_valid(game):
		return mw
	# the company's works: the processing district's (30 号), else the berth's
	var dock = game.get("plant")
	if dock == null or not is_instance_valid(dock):
		dock = game.get("dock")
	if dock == null:
		return mw
	var sm = dock.get("smelter")
	if sm != null and _busy(Career.data.get("industrial_heat", {})):
		mw += float(sm.get("power"))
	var line = dock.get("scrapline")
	if line != null and bool(line.get("company_powered")):
		mw += SORT_MW
	return mw


static func _fixed() -> int:
	var n := 0
	for it in Repair.ITEMS:
		if Career.data.get("upgrades", {}).has(it[0]):
			n += 1
	return n


# ---------------------------------------------------------------- the four cells
# {id, code, title, value, lines, lamp ("ok" | "warn" | "danger" | "idle"), go}
# 51 号 (player 2026-10-25: "at the start I only want the salvage — the rest isn't built yet"):
# a system's cell appears once it exists; the berth from the start
static func cells(game = null) -> Array:
	var out: Array = []
	if Port.stage("power") >= 1:
		out.append(_grid(game))
	if _shipping_seen():
		out.append(_shipping())
	out.append(_berth())
	if Port.stage("process") >= 1:
		out.append(_production())
	return out


static func _shipping_seen() -> bool:
	if Port.stage("tug") >= 1 or not Career.data.get("ship_market", {}).get("assets", []).is_empty():
		return true
	for t in Career.data.get("exchange", {}).get("trades", []):
		if Shipping.orbital(t):
			return true
	return false


static func _grid(game) -> Dictionary:
	var d := Career.data
	var stage := Port.stage("power")
	var powered := 0
	for id in Port.POWER_ITEMS:
		if Port.power_ok(id):
			powered += 1
	# 34 号: the real bus — own generation, what is drawn, what is spoken for, who waits
	var mw := 0.0
	for l in Grid.loads(game):
		mw += float(l.mw)
	var due := energy_due()
	var waits := Grid.wait_text(game)
	var lines: Array = [
		w("自家能发 %.0f · 已分出去 %.1f · 还空着 %.1f 兆瓦", "WE MAKE %.0f · GIVEN OUT %.1f · FREE %.1f MW") % [Grid.capacity(), Grid.reserved(game), Grid.headroom(game)],
		w("动力区 %d / 2 期 · 大设备 %d / %d 有电", "POWER DISTRICT %d / 2 · BIG MACHINES %d / %d POWERED") % [stage, powered, Port.POWER_ITEMS.size()],
	]
	if Grid.shore_mw(game) > 0.0:
		lines.insert(1, w("外购电 %.1f 兆瓦", "BOUGHT %.1f MW") % Grid.shore_mw(game))
	if waits != "":
		lines.push_front(w("电弧炉电不够，熔得慢", "THE FURNACE IS SHORT OF POWER"))
	if due > 0.005:
		lines.push_front(w("待缴电费 %s", "POWER DUE %s") % Pal.money(due))
	var lamp := "danger" if due > 0.005 else ("warn" if waits != "" or Grid.headroom(game) < 1.0 else "ok")
	return {"id": "grid", "code": "PWR", "title": w("港区电网", "PORT GRID"), "value": "%.1f / %.0f MW" % [mw, Grid.capacity()],
		"lines": lines, "lamp": lamp, "go": "route:port:power"}


static func _shipping() -> Dictionary:
	var d := Career.data
	var tr := transit()
	var lines: Array = []
	var held: Dictionary = d.get("held", {})
	if not held.is_empty():
		lines.append(w("排队大船 %s · 下次开市可接", "QUEUED SHIP %s · NEXT MARKET") % str(held.get("reg", held.get("ship", ""))))
	lines.append(w("拖运费：派拖船时付，自家拖船待命时半价", "TOWING: PAID WHEN THE TUG GOES, HALF WITH YOUR OWN TUG"))
	lines.append(w("作业艇停在 %s", "WORK BOAT AT %s") % WorkBoat.pad_name(str(d.get("boat_pad", "berth"))))
	var value := w("%d 批在途", "%d IN TRANSIT") % (tr[0] + tr[1]) if tr[0] + tr[1] > 0 else w("无在途", "NONE MOVING")
	if tr[0] + tr[1] > 0:
		lines.push_front(w("进港 %d · 出港 %d", "INBOUND %d · OUTBOUND %d") % [tr[0], tr[1]])
	return {"id": "ship", "code": "TUG", "title": w("船舶运输", "SHIPPING"), "value": value, "lines": lines,
		"lamp": "ok" if tr[0] + tr[1] > 0 or not held.is_empty() else "idle", "go": "exchange"}


static func _berth() -> Dictionary:
	var d := Career.data
	var a: Dictionary = Career.active()
	var lines: Array = []
	var fixed := _fixed()
	lines.append(w("修缮 %d / %d 项", "REPAIRS %d / %d") % [fixed, Repair.ITEMS.size()])
	var offers: Array = d.get("offers", [])
	if d.get("market", false):
		lines.append(w("市场报价 %d 张", "%d OFFERS ON THE MARKET") % offers.size())
	var value := w("空闲", "EMPTY")
	var lamp := "idle"
	if not a.is_empty():
		value = str(a.get("id", ""))
		lamp = "warn"
		lines.push_front(w("在手合同，未完工", "CONTRACT IN HAND"))
	elif not Career.story_job().is_empty():
		value = w("待接开局合同", "OPENING JOB WAITING")
		lamp = "warn"
	return {"id": "berth", "code": "BTH-07", "title": w("拆船泊位", "SALVAGE BERTH"), "value": value, "lines": lines, "lamp": lamp,
		"go": "tab:0"}


static func _production() -> Dictionary:
	var d := Career.data
	var sort: Dictionary = d.get("industrial_sort", {})
	var heat: Dictionary = d.get("industrial_heat", {})
	var stored := 0.0
	for k in _stock():
		stored += maxf(0.0, float(_stock()[k]))
	var lines: Array = [
		w("分选线 %s", "SORTING %s") % batch_state(sort),
		w("炉体 %s", "FURNACE %s") % batch_state(heat),
		w("仓库 %.2f t", "WAREHOUSE %.2f t") % stored,
	]
	var busy := _busy(sort) or _busy(heat)
	var value := w("运行中", "RUNNING") if busy else w("停机", "IDLE")
	if _busy(heat) and str(heat.get("state", "")) == "processing":
		value = w("炉次进行中", "HEAT ON")
	return {"id": "prod", "code": "PRC", "title": w("加工生产", "PRODUCTION"), "value": value, "lines": lines,
		"lamp": "ok" if busy else "idle", "go": "clients"}


# ---------------------------------------------------------------- what waits on the operator
# {level, title, why, go}; the worst first, at most MAX_DECISIONS
static func decisions(game = null) -> Array:
	var d := Career.data
	var out: Array = []
	var due := energy_due()
	if due > 0.005:
		out.append({"level": DANGER, "title": w("欠了 %s 电费，机器停了", "%s OF POWER UNPAID: THE MACHINES STOPPED") % Pal.money(due),
			"why": w("去那台机器的面板上把电费交了，再开机。", "Pay at the machine's panel, then start it again."), "go": "site:heat" if _busy(d.get("industrial_heat", {})) and float(d.industrial_heat.get("energy_debt", 0.0)) > 0.0 else "site:sort"})
	var due_loan := minf(Career.INSTALLMENT, float(d.get("loan", 0.0))) + snappedf(float(d.get("loan", 0.0)) * Career.rate(), 1.0)
	if float(d.get("loan", 0.0)) > 0.0 and float(d.get("money", 0.0)) < due_loan:
		out.append({"level": DANGER, "title": w("下次结算要还 %s 欠款，现在的钱不够", "%s OF DEBT IS DUE AT THE NEXT SETTLEMENT: NOT ENOUGH CASH") % Pal.money(due_loan),
			"why": w("拆完下一艘船结算时会自动扣。先拆一艘船，或者把仓库里的东西卖掉。", "It is taken when the next ship is settled. Strip a ship, or sell what is in the warehouse."), "go": "tab:0"})
	var heat: Dictionary = d.get("industrial_heat", {})
	var power_wait := Grid.wait_text(game)
	if power_wait != "":
		out.append({"level": TODO, "title": w("炉次 %s 电不够，熔得慢", "HEAT %s IS SHORT OF POWER") % str(heat.get("id", "")),
			"why": power_wait, "go": "route:port:power"})
	elif str(heat.get("state", "")) == "processing" and not HeatAuto.on():
		out.append({"level": TODO, "title": w("炉次 %s 等你到炉台", "HEAT %s NEEDS YOU AT THE FURNACE") % str(heat.get("id", "")),
			"why": w("测温取样、倾炉出钢要在现场亲手做。", "Sampling and tapping are done by hand on site."), "go": "site:heat"})
	var sort: Dictionary = d.get("industrial_sort", {})
	if str(sort.get("state", "")) == "processing":
		out.append({"level": TODO, "title": w("分选批次 %s 原料已到", "SORTING BATCH %s IS AT THE LINE") % str(sort.get("id", "")),
			"why": w("在分选台启动驱动，粉碎、磁选后两路产物返仓。", "Start the drives at the sorting desk."), "go": "site:sort"})
	var ex: Dictionary = d.get("exchange", {})
	# 39 号: a client's rush bid — a job when there are billets, a chance when there are not
	var rush: Dictionary = {} if ex.is_empty() else Exchange.rush_order(ex)
	if not rush.is_empty():
		var bil := _stock_t(Exchange.lot_key("steel_billet", 1))
		var who := str(ex.actors.get(str(rush.owner), {}).get("name", rush.owner))
		out.append({"level": TODO if bil > Exchange.EPS else CHANCE,
			"title": w("加急：%s 收 %.2f t 钢坯 %s/t，还剩 %d 分钟", "RUSH: %s WANTS %.2f t BILLET AT %s / t, %d MIN") % [who, float(rush.remaining), Pal.money(float(rush.price)), Exchange.rush_minutes(ex)],
			"why": (w("你库里有 %.2f t：到工业客户页按加急价挂牌，当场到账。", "You have %.2f t: list at the rush price, paid at once.") % bil) if bil > Exchange.EPS else w("库里没有钢坯；赶在到期前炼一炉。过期不扣钱。", "No billets in stock; a heat might make it. No penalty if it lapses."),
			"go": "clients"})
	if HeatAuto.offer():
		out.append({"level": CHANCE, "title": w("可以给炉子装自动装置了（%s）", "THE FURNACE CAN TAKE AN AUTO UNIT NOW (%s)") % Pal.money(HeatAuto.PRICE),
			"why": w("你已经亲手炼了 %d 炉钢。花 %s 给炉子装上自动装置，以后炉子烧到温度会自己测温、自己把钢水倒出来。去炉台点“更多”安装。", "You have melted %d heats by hand. For %s the furnace can take the temperature and pour by itself. Install it under More at the furnace desk.") % [HeatAuto.count(), Pal.money(HeatAuto.PRICE)], "go": "site:heat"})
	var gaps: Array = []
	if not ex.is_empty():
		for id in Exchange.CUSTOMER_OFFERS:
			var st: Dictionary = Exchange.customer_status(ex, id)
			if not st.ok:
				continue
			var offer: Dictionary = Exchange.CUSTOMER_OFFERS[id]
			var key := Exchange.lot_key(str(offer.item), int(offer.grade))
			if st.state == "active" and float(st.remaining) > Exchange.EPS:
				var have := _stock_t(key)
				gaps.append(key)
				out.append({"level": TODO, "title": w("%s 还差 %.2f t", "%s SHORT %.2f t") % [str(offer.name) if Txt.zh else id, float(st.remaining)],
					"why": w("仓库有 %s %.2f t。", "%.2f t of %s in stock.") % ([item_name(key), have] if Txt.zh else [have, item_name(key)]) + (w("够卖一批：到客户页按客户价挂牌，当场到账。", " Enough to sell: list it at the client's price, paid at once.") if have > Exchange.EPS else w("先炼一炉钢坯。", " Run a heat first.")), "go": "clients"})
	var queued_ready := false
	for o in d.get("offers", []):
		if o.get("held", false):
			queued_ready = true
	if queued_ready:
		out.append({"level": TODO, "title": w("排队的大船到了", "THE QUEUED BIG SHIP IS IN"), "why": w("它在合同页最后一张，可以直接接。", "It is the last card on the contracts page."), "go": "tab:0"})
	var ferrous := _stock_t(Exchange.lot_key("ferrous_scrap", 1))
	if ferrous > Exchange.EPS and not _busy(heat) and not gaps.is_empty():
		out.append({"level": CHANCE, "title": w("%.2f 吨钢锭可以开炉", "%.2f t OF GRADE 1 FEED READY") % ferrous,
			"why": w("炉台在加工区公司炉左侧，按 E 装炉。", "The furnace desk is beside the company furnace in the processing district; press E there."), "go": "site:heat"})
	var assay := Assay.candidates()
	var to_grade := 0.0
	var to_describe := 0.0
	for c in assay:
		if c.kind == "grade":
			to_grade += float(c.quantity)
		else:
			to_describe += float(c.quantity)
	var mixed := maxf(0.0, _stock_t(Exchange.lot_key("mixed_metal", 0)) - to_describe)
	if mixed > Exchange.EPS and not _busy(sort):
		out.append({"level": CHANCE, "title": w("仓库有 %.2f t 未分选金属", "%.2f t OF MIXED METAL IN STOCK") % mixed,
			"why": w("到分选台按『整线加工』：分选后黑色料直接进电弧炉炼成钢坯；或者直接挂牌卖。", "Run the line: sorted and straight into the arc furnace; or list it as is."), "go": "site:sort"})
	if to_grade > Exchange.EPS and not Career.data.get("assay", {}).get("state", "") == "running":
		out.append({"level": CHANCE, "title": w("%.2f t 未评级黑色炉料可以化验", "%.2f t OF UNRATED FERROUS FEED TO ASSAY") % to_grade,
			"why": w("化验位在分选台右侧 12 m；杂质够低就整批升为等级 1，能进炉。", "The assay bench is 12 m right of the sorting desk; low enough impurity makes it grade 1."), "go": "site:assay"})
	if to_describe > Exchange.EPS:
		out.append({"level": CHANCE, "title": w("%.2f t 旧料缺材料描述", "%.2f t OF OLD STOCK WITH NO RECORD") % to_describe,
			"why": w("分选台不收来路不明的料；先到化验位测一次。", "The sorting line refuses it until the assay bench has read it."), "go": "site:assay"})
	var tr := transit()
	var sc := Shipping.counts()
	if int(sc.to_haul) + int(sc.apron) > 0:
		out.append({"level": TODO, "title": w("码头有 %d 件货等你搬", "%d PIECES WAITING AT THE PIER") % (int(sc.to_haul) + int(sc.apron)),
			"why": w("货船靠在货运区码头；拖进仓库收货口才算入库。", "A freighter is at the cargo pier; stock once inside the receiver."), "go": "site:pier"})
	if tr[0] > 0:
		out.append({"level": CHANCE, "title": w("%d 批货在路上", "%d CONSIGNMENTS INBOUND") % tr[0],
			"why": w("到库后才能投料；星图上看货船沿轨道飞到哪了。", "Usable once received; the star map shows each freighter on its arc."), "go": "starmap"})
	if ex.is_empty() == false and gaps.is_empty() and Port.stage("trade") >= 1:
		for id in Exchange.CUSTOMER_OFFERS:
			var st2: Dictionary = Exchange.customer_status(ex, id)
			if st2.ok and st2.state == "available":
				var of2: Dictionary = Exchange.CUSTOMER_OFFERS[id]
				out.append({"level": CHANCE, "title": w("可承接：%s %.1f t", "OPEN ORDER: %s %.1f t") % [str(of2.name) if Txt.zh else id, float(of2.quantity)],
					"why": w("出价 %s/t：挂牌卖给他，当场到账。", "%s / t: list to it, paid at once.") % Pal.money(float(of2.price)), "go": "clients"})
				break
	var gs := Route.goals()
	if not gs.is_empty():
		var n: Dictionary = gs[0]
		var title := w("下一个升级目标：", "NEXT UPGRADE: ") if n.get("purchase_kind", "") == "upgrade" else w("下一个建设目标：", "NEXT BUILD: ")
		out.append({"level": CHANCE if not n.get("ready", false) else TODO, "title": ("★ " if n.get("pinned", false) else "") + title + str(n.name).split(" · ")[0],
			"why": Route.missing(n), "go": "route:" + str(n.key)})
	out.sort_custom(func(a, b): return int(a.level) < int(b.level))
	# the training run, pinned first; the other production items wait behind it (28 号 Q15)
	if Drill.open():
		out = out.filter(func(o): return int(o.level) == DANGER or not (str(o.go) in ["site:heat", "site:sort", "site:assay", "clients"]))
		var st := Drill.step()
		out.push_front({"level": TODO, "title": w("经营补贴训练单", "SUBSIDISED TRAINING RUN"), "why": str(st.text), "go": "drill"})
	return out.slice(0, MAX_DECISIONS)


# a site job said in words (the machines are worked by hand, Q30)
static func site_text(go: String) -> String:
	match go:
		"site:heat":
			return w("炉台在加工区公司炉左侧（中央枢纽往左的走廊进去）。关掉终端飞过去，按 %s 打开炉体操作。", "The furnace desk is left of the company furnace in the processing district (the corridor left of the hub). Close the terminal, fly there and press %s.") % Keys.label("use")
		"site:sort":
			return w("分选台在加工区，炉台右侧 12 m。关掉终端飞过去，按 %s 打开分选操作。", "The sorting desk is in the processing district, 12 m right of the furnace desk. Close the terminal, fly there and press %s.") % Keys.label("use")
		"site:assay":
			return w("化验位在加工区，分选台右侧 12 m。关掉终端飞过去，按 %s 打开化验。", "The assay bench is in the processing district, 12 m right of the sorting desk. Close the terminal, fly there and press %s.") % Keys.label("use")
	return ""


# the one next step of the company's own steel, from what is really in stock (19 号 §3):
# {text, go}; the getting-started page and the overview both say it
static func next_step() -> Dictionary:
	var d := Career.data
	var heat: Dictionary = d.get("industrial_heat", {})
	var sort: Dictionary = d.get("industrial_sort", {})
	if str(heat.get("state", "")) == "processing":
		return {"text": w("炉次在炉里：到炉台测温取样、倾炉出钢。", "A heat is on: sample and tap at the furnace desk."), "go": "site:heat"}
	if _busy(heat) or _busy(sort):
		return {"text": w("设备在搬运或加工，等它把货送回仓库。", "The plant is moving or working stock; wait for it to reach the warehouse."), "go": ""}
	var billets := _stock_t(Exchange.lot_key("steel_billet", 1))
	if billets > Exchange.EPS:
		return {"text": w("仓库有 %.2f t 合格钢坯：去交易行“工业客户”承接或发运。", "%.2f t of grade 1 billets: take or ship a client order on the exchange.") % billets, "go": "clients"}
	var feed := _stock_t(Exchange.lot_key("ferrous_scrap", 1))
	if feed >= 0.25:
		return {"text": w("仓库有 %.2f 吨钢锭：去加工区炉台，炼成钢坯。", "%.2f t of grade 1 feed: charge the furnace.") % feed, "go": "site:heat"}
	if str(d.get("assay", {}).get("state", "")) == "running":
		return {"text": w("化验位正在读样品，读完自动入账。", "The assay bench is reading a sample; the result books itself."), "go": "site:assay"}
	for c in Assay.candidates():
		if c.kind == "grade":
			return {"text": w("仓库有未评级黑色炉料：到化验位定级，合格的整批升为等级 1。", "Unrated ferrous feed in stock: grade it at the assay bench."), "go": "site:assay"}
	var mixed := _stock_t(Exchange.lot_key("mixed_metal", 0))
	for c in Assay.candidates():
		if c.kind == "describe":
			mixed -= float(c.quantity)
	if mixed >= 0.25:
		return {"text": w("仓库有 %.2f t 未分选金属：到分选台分成黑色炉料和有色混合。", "%.2f t of mixed metal: sort it at the sorting desk.") % mixed, "go": "site:sort"}
	if not Assay.candidates().is_empty():
		return {"text": w("仓库有缺材料描述的旧料：先到化验位测一次，再能分选。", "Old stock with no record: read it at the assay bench before sorting."), "go": "site:assay"}
	return {"text": w("接下一单时在配装页打开“废金属留作原料”，拆下的结构钢就成了公司自己的原料；也可以在交易行买料。", "On the next job, switch on \"keep the scrap as raw material\" on the loadout page, or buy feed on the exchange."), "go": "tab:0"}
