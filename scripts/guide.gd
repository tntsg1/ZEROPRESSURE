class_name Guide
extends Node
# The on-site task guide (design/…/27_现场任务引导; player 2026-10-24: "click one of these and
# it has to guide me … at least there must be a guide"). A task — sort, assay, furnace, client
# shipment, buying feed — walks the operator through its machine one step at a time. Every step
# is worked out from the real state each frame (where the drone is, which panel is open, what
# the batch and the furnace are doing), never from a counter, so it cannot drift from the game.
# The HUD draws the step card, the arrow and the ring on the target; the machine panel's button
# to press next is lit; the big machine read-out plates step back while a guide runs.
const Exchange = preload("res://scripts/industrial_exchange.gd")
const Assay = preload("res://scripts/industrial_assay.gd")
const GuideCopy = preload("res://scripts/onboarding_text.gd")
const Smelter = preload("res://scripts/smelter.gd")
const TASKS := ["sort", "assay", "heat", "clients", "buy_feed", "repair", "build", "transit", "trade", "retain", "collect"]

static var quiet := false      # the dock's machine read-out plates are not drawn (Jev A 1.00)

var game
var task := ""
var start := {}                # what was there when the task began: batch ids, deliveries
var step := {}                 # {task, n, of, title, text, target, name, purpose, button, action}
var note := ""                 # "done: …, next: …" for a few seconds
var note_t := 0.0
var _hl := StyleBoxFlat.new()  # the lit button's frame
var _t := 0.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	# the terminal pauses the tree; the guide still lights its buttons
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hl.bg_color = Color(0.2, 0.13, 0.08)
	_hl.set_border_width_all(3)
	_hl.set_content_margin_all(10)
	_hl.content_margin_left = 44
	var saved := str(Career.data.get("guide_task", ""))
	if saved in TASKS:
		task = saved
		start = Career.data.get("guide_start", {}).duplicate(true)


# ---------------------------------------------------------------- which task a decision starts

static func _stock(key: String) -> float:
	return float(Career.data.get("exchange", {}).get("actors", {}).get(Exchange.PLAYER, {}).get("stock", {}).get(key, 0.0))


static func _sortable() -> float:
	var t := _stock(Exchange.lot_key("mixed_metal", 0))
	for c in Assay.candidates():
		if c.kind == "describe":
			t -= float(c.quantity)
	return t


static func _assay_grade() -> bool:
	return Assay.candidates().any(func(c): return c.kind == "grade")


# the decision's `go` (scripts/ops.gd) -> a task ("" when it is not a site job)
static func task_for(go: String) -> String:
	match go:
		"site:sort": return "sort"
		"site:assay": return "assay"
		"site:heat": return "heat"
		"site:pier": return "collect"
		"clients": return first_for_clients()
	return ""


# a client order short: start from where the company's own steel stands now
static func first_for_clients() -> String:
	var heat: Dictionary = Career.data.get("industrial_heat", {})
	if _stock(Exchange.lot_key("steel_billet", 1)) > Exchange.EPS:
		return "clients"
	if Ops._busy(heat) or _stock(Exchange.lot_key("ferrous_scrap", 1)) >= 0.25:
		return "heat"
	if _assay_grade() or str(Career.data.get("assay", {}).get("state", "")) == "running":
		return "assay"
	if _sortable() >= 0.25 or Ops._busy(Career.data.get("industrial_sort", {})):
		return "sort"
	return "buy_feed"


func begin(t: String, target: String = "") -> void:
	if not t in TASKS:
		return
	task = t
	start = {
		"target": target,
		"sort": str(Career.data.get("industrial_sort", {}).get("id", "")),
		"heat": str(Career.data.get("industrial_heat", {}).get("id", "")),
		"assay": str(Career.data.get("assay", {}).get("id", "")),
		"delivered": _delivered(),
		"clock": float(Career.data.get("exchange", {}).get("clock", 0.0)),
		"fixed": _fixed(),
		"stages": Port.total_stages(),
		"buys": _buys(),
		"rode": false,
	}
	Career.data.guide_task = task
	Career.data.guide_start = start.duplicate(true)
	Career.save()
	step = {}
	_t = 9.0


func stop() -> void:
	task = ""
	step = {}
	quiet = false
	Career.data.erase("guide_task")
	Career.data.erase("guide_start")
	Career.save()
	_light("")


func active() -> bool:
	return task != ""


static func _fixed() -> int:
	var n := 0
	for it in Repair.ITEMS:
		if Career.data.get("upgrades", {}).has(it[0]):
			n += 1
	return n


static func _buys() -> int:
	var n := 0
	for trade in Career.data.get("exchange", {}).get("trades", []):
		if trade.get("buyer", "") == Exchange.PLAYER:
			n += 1
	return n


static func _delivered() -> float:
	var t := 0.0
	for trade in Career.data.get("exchange", {}).get("trades", []):
		if trade.get("seller", "") == Exchange.PLAYER and trade.get("state", "") == "delivered":
			t += float(trade.get("quantity", 0.0))
	return t


# ---------------------------------------------------------------- the steps

func _panel(path: String) -> bool:
	return game.console_ui != null and is_instance_valid(game.console_ui) and game.console_ui.get_script() != null and game.console_ui.get_script().resource_path == path


# go there, open it, press this: the three shapes of a machine step
func _at(service, path: String, name: String, purpose: String, n: int, of: int, title: String, button: String) -> Dictionary:
	var s := {"n": n, "of": of, "target": service.site(), "name": name, "purpose": purpose, "button": button}
	if _panel(path):
		s.title = title
		s.text = purpose
	elif service.near():
		s.title = w("按 %s 打开%s", "PRESS %s FOR THE %s") % [Keys.label("use"), name]
		s.text = purpose
		s.button = ""
	else:
		s.title = w("飞到%s", "FLY TO THE %s") % name
		s.text = w("出船坞闸口就是拆船区站，按 %s 坐接驳车到加工区；也可以跟着屏幕边上的箭头飞过去。", "Out of the berth's gate is the salvage stop: %s calls the shuttle to the processing district; or follow the arrow at the screen's edge.") % Keys.label("use")
		s.button = ""
	return s


func _wait(service, name: String, purpose: String, n: int, of: int, title: String, text: String) -> Dictionary:
	return {"n": n, "of": of, "target": service.site(), "name": name, "purpose": purpose, "button": "", "title": title, "text": text}


# 37 号: the through line — one press, the line runs to the furnace by itself
func _sort() -> Dictionary:
	var srv = game.industrial_sort
	var name := w("分选台", "SORTING DESK")
	var purpose := w("整线加工：分选 → 线上化验 → 黑色料直接进电弧炉；有色料回仓库", "The through line: sorted, assayed in line, straight into the arc furnace")
	var path := "res://scripts/sort_panel.gd"
	var b: Dictionary = Career.data.get("industrial_sort", {})
	match str(b.get("state", "")):
		"raw_transport":
			return _wait(srv, name, purpose, 2, 4, w("等原料沿吊轨运到分选线", "WAIT FOR THE FEED"), w("搬运车正从仓库把料运过来。", "The courier is bringing the feed."))
		"raw_return":
			return _wait(srv, name, purpose, 2, 4, w("等原料退回仓库", "FEED GOING BACK"), w("撤回的原料正运回仓库。", "The withdrawn feed is going back."))
		"processing":
			if not bool(game.industrial_sort.line().company_powered) and not b.get("through", false):
				return _at(srv, path, name, purpose, 3, 4, w("按『启动分选驱动』", "PRESS START DRIVES"), "启动分选驱动")
			return _wait(srv, name, purpose, 3, 4, w("压块 → 撕碎 → 磁选进行中", "PRESSING, SHREDDING, SEPARATING"), w("机器自己在跑，不用守着。", "It runs on its own."))
		"product_transport":
			if srv._through_now():
				return _wait(srv, name, purpose, 4, 4, w("黑色料过线上化验，进电弧炉", "FERROUS THROUGH THE ASSAY INTO THE FURNACE"), w("化验位读数约 30 秒，合格的直接进炉，炉子自己通电。", "A 30 s reading; then into the furnace, which starts itself."))
			return _wait(srv, name, purpose, 4, 4, w("产物运回仓库", "OUTPUT GOING BACK"), "")
	if str(b.get("id", "")) != str(start.get("sort", "")) and str(b.get("state", "")) == "complete":
		return {"done": w("分选完成", "SORTED")}
	if _sortable() >= 0.3:
		return _at(srv, path, name, purpose, 1, 4, w("按『整线加工』", "PRESS RUN THE LINE"), "整线加工")
	return {"done": w("仓库里没有可分选的金属", "NOTHING TO SORT"), "end": true}


func _assay() -> Dictionary:
	var srv = game.industrial_assay
	var name := w("化验位", "ASSAY BENCH")
	var purpose := w("只读样品、定等级，和旁边的熔炉无关：杂质 ≤ 3% 的黑色炉料整批升为等级 1 才能进炉", "Reads a sample and grades the lot (nothing to do with the furnace beside it): ≤ 3% impurity makes grade 1 feed")
	var a: Dictionary = Career.data.get("assay", {})
	if str(a.get("state", "")) == "running":
		var r: Array = srv.reading()
		return _wait(srv, name, purpose, 2, 2, w("光谱读数中 %d%%", "READING %d%%") % int(round(float(r[2]) * 100.0)), w("约 30 秒，读完自动入账；不用守着。", "About 30 s; it books itself."))
	if str(a.get("id", "")) != str(start.get("assay", "")) and str(a.get("state", "")) == "complete":
		match str(a.get("result", "")):
			"grade_1": return {"done": w("化验合格：整批升为等级 1 炉料", "PASSED: the lot is grade 1 feed")}
			"unrated": return {"done": w("化验不合格：杂质太高，只能按未评级卖", "FAILED: too much impurity, sell it unrated"), "end": true}
			_: return {"done": w("化验完成：旧料有了材料描述，可以分选", "READ: the old lot can now be sorted")}
	if not Assay.candidates().is_empty():
		var first: Dictionary = Assay.candidates()[0]
		var label := "定级" if first.kind == "grade" else "测材料描述"
		return _at(srv, "res://scripts/assay_panel.gd", name, purpose, 1, 2, w("按『%s …』", "PRESS %s") % label, label)
	return {"done": w("仓库里没有要化验的料", "NOTHING TO ASSAY"), "end": true}


func _heat() -> Dictionary:
	var srv = game.industrial_heat
	var name := w("炉台", "FURNACE DESK")
	var purpose := w("把钢锭重新熔成钢水、浇成钢坯，卖给工业客户", "Melts grade 1 feed and casts billets for industrial clients")
	var path := "res://scripts/heat_panel.gd"
	var h: Dictionary = Career.data.get("industrial_heat", {})
	# 125/126 号: the furnace's own state, the same words the desk and the machine say
	var inf: Dictionary = srv.info()
	if str(inf.key) not in ["idle", "fault"] and str(h.get("state", "")) not in ["complete", "cancelled", "written_off"]:
		var press: String = str({"melt": GuideCopy.text("heat.melt"), "sample": "测温取样", "tap": "倾炉出钢"}.get(str(inf.press), ""))
		if press != "":
			return _at(srv, path, name, purpose, int(inf.n), 8, str(inf.title), press)
		return _wait(srv, name, purpose, int(inf.n), 8, str(inf.title), str(inf.text))
	if str(h.get("id", "")) != str(start.get("heat", "")) and str(h.get("state", "")) == "complete":
		return {"done": w("出钢完成：钢坯已入库", "TAPPED: billets in the warehouse")}
	if _stock(Exchange.lot_key("ferrous_scrap", 1)) >= 0.25:
		var s1 := _at(srv, path, name, purpose, 1, 8, w("填炉料吨数，按『把仓库炉料送到炉口』", "SEND THE FEED"), GuideCopy.text("heat.send_feed"))
		# 124 号 (user "提速＋在路上就能送"): sent from right here, it travels while you fly over
		if not _panel(path):
			s1.action = "heat_send"
			s1.title = w("送 %.2f t 钢锭去炉口（在哪都能按）", "SEND %.2f t OF INGOT TO THE FURNACE (FROM ANYWHERE)") % minf(2.0, _stock(Exchange.lot_key("ferrous_scrap", 1)))
			s1.text = w("按卡片上的按钮就开始送，你飞过去的路上料也在走；到了炉台再按『通电熔化』。", "The card's button starts it; the feed travels while you fly over. At the desk, strike the arcs.")
		return s1
	return {"done": w("仓库里没有钢锭", "NO GRADE 1 FEED"), "end": true}


# 37 号: selling is a listing — the client buys it, the money is there on the sale, the courier delivers
func _clients() -> Dictionary:
	var ex: Dictionary = Career.data.get("exchange", {})
	var open: bool = game.console_ui != null and is_instance_valid(game.console_ui) and game.console_ui.get_script() == preload("res://scripts/exchange_panel.gd")
	for trade in ex.get("trades", []):
		if trade.get("seller", "") == Exchange.PLAYER and trade.get("paid", false) and float(trade.get("matched", -1.0)) >= float(start.get("clock", 0.0)):
			return {"done": w("钢坯卖出去了，钱已到账", "THE BILLETS SOLD; PAID"), "end": true}
	if _delivered() > float(start.get("delivered", 0.0)) + Exchange.EPS:
		return {"done": w("钢坯卖出去了，钱已到账", "THE BILLETS SOLD; PAID"), "end": true}
	var s := {"n": 1, "of": 1, "target": Vector2.INF, "name": "", "purpose": "", "button": "", "action": "" if open else "clients"}
	# 45 号: the clients are the high bids on the sell window's chart
	s.title = w("在『出售』点钢坯，按『上架』", "UNDER SELL: PICK THE BILLETS, PRESS LIST IT")
	s.text = w("价格默认就是客户的收价，上架当场成交、钱当场到账，货由搬运车送，不用你发货。", "The price starts at the client's bid: sold and paid at once, delivered for you.") if open else w("点卡片上的按钮打开交易行。", "Use the button on this card to open the exchange.")
	s.button = w("上架", "LIST IT") if open else ""
	return s


func _buy_feed() -> Dictionary:
	if _stock(Exchange.lot_key("ferrous_scrap", 1)) >= 0.25:
		return {"done": w("钢锭到货了", "GRADE 1 FEED IS IN")}
	var open: bool = game.console_ui != null and is_instance_valid(game.console_ui) and game.console_ui.get_script() == preload("res://scripts/exchange_panel.gd")
	for trade in Career.data.get("exchange", {}).get("trades", []):
		if trade.get("buyer", "") == Exchange.PLAYER and trade.get("state", "") != "delivered" and str(trade.get("item", "")) == "ferrous_scrap":
			return {"n": 2, "of": 2, "target": Vector2.INF, "name": "", "purpose": "", "button": "", "action": "", "title": w("炉料在路上", "FEED ON ITS WAY"), "text": w("进了仓库才能装炉。", "Usable once it is in the warehouse.")}
	return {"n": 1, "of": 2, "target": Vector2.INF, "name": "", "purpose": "", "button": "购买" if open else "", "action": "" if open else "feed",
		"title": w("在交易行选『黑色炉料』等级 1，点一家卖方的『购买』", "BUY GRADE 1 FERROUS FEED FROM A SELLER"),
		"text": w("没有自己的料时，先买合格炉料开炉。", "No feed of your own yet: buy grade 1 to run a heat.")}


func _term(tab: int) -> bool:
	return game.console_ui != null and is_instance_valid(game.console_ui) and game.console_ui.get("tab") == tab


func _card(n: int, of: int, title: String, text: String, action: String = "", button: String = "") -> Dictionary:
	return {"n": n, "of": of, "target": Vector2.INF, "name": "", "purpose": "", "button": button, "action": action, "title": title, "text": text}


# one repair as the guide and the main line see it: ready, or what it lacks and where from
static func repair_info(id: String) -> Dictionary:
	var pf := Repair.parts_for(id)
	var lack: Array = []
	var ships: Array = []
	for dep in Repair.find(id)[1] if not Repair.find(id).is_empty() else []:
		if not Repair.done(str(dep)):
			lack.append(Ops.w("先修「%s」", "FIRST %s") % Repair.name_of(str(dep)))
	for cls in pf.missing:
		lack.append(Repair.lack_text(cls, float(pf.missing[cls])))
		for sh in Repair.ships_with(cls):
			if not sh in ships:
				ships.append(sh)
	if pf.tons_missing > 0.001:
		lack.append(Repair.lack_text("structure", pf.tons_missing))
	var cost := Repair.price(id, true)
	var short := maxf(0.0, cost - float(Career.data.get("money", 0.0)))
	if lack.is_empty() and short > 0.5:
		lack.append(Ops.w("还差 %s 钱", "%s MORE MONEY") % Pal.money(short))
	return {"id": id, "name": Repair.name_of(id), "lack": ("、" if Txt.zh else ", ").join(lack), "ships": ships.slice(0, 3), "short": short, "ready": lack.is_empty()}


# the berth's next repair (scripts/repair.gd): fix it now, or the ships that carry what it lacks
func _repair() -> Dictionary:
	var target := str(start.get("target", ""))
	if target != "" and Repair.done(target):
		return {"done": w("修好了「%s」", "%s MENDED") % Repair.name_of(target), "end": true}
	if target == "" and _fixed() > int(start.get("fixed", 0)):
		return {"done": w("船坞又修好一项", "ANOTHER BERTH REPAIR DONE"), "end": true}
	# user 2026-10-27: the crew already on it took the parts — "still 2 short" was wrong; say it is being built
	var wj := Works.current()
	if not wj.is_empty() and str(wj.get("kind", "")) == "repair" and (target == "" or str(wj.get("id", "")) == target):
		if Works.held == "lockout":
			return _card(2, 2, w("施工暂停：无人机离吊装区远一点", "WORK STOPPED: MOVE THE DRONE OUT OF THE LIFT ZONE"), w("吊装时无人机在 %d m 内，施工队不能吊。", "The crew cannot lift with the drone within %d m.") % int(Works.LOCKOUT_M))
		return _card(2, 2, w("施工队在修「%s」：还要约 %d 秒", "THE CREW IS ON %s: ~%d s") % [Works.name_of(wj), int(ceil(float(wj.get("left", 0.0))))], w("零件已经交给施工队了，等它修完就能用。", "The parts are with the crew; it works once they are done."))
	# 86 号 Q9: a fault not seen yet — fly to it; close up it is logged and the step moves on
	if target != "" and not Repair.found(target):
		return {"n": 1, "of": 2, "target": RepairShow.spot(target), "name": Repair.name_of(target), "purpose": "", "button": "",
			"title": w("飞去看看「%s」", "FLY OVER TO THE %s") % Repair.name_of(target), "text": w("跟着箭头，飞近就会记进报修。", "Follow the arrow: close up, it is logged.")}
	var sg := Repair.suggestion() if target == "" else repair_info(target)
	if target != "":
		sg.lack = [sg.lack] if str(sg.lack) != "" else []
	if sg.is_empty():
		return {"done": w("船坞十六项都修好了", "ALL SIXTEEN BERTH REPAIRS DONE"), "end": true}
	if sg.get("ready", false):
		var parts: bool = Repair.parts_for(str(sg.id)).ok
		var press := Txt.t("rp_fix_parts") if parts else Txt.t("rp_fix_cash")
		if _term(1):
			return _card(2, 2, w("按『%s』修好「%s」", "PRESS %s FOR %s") % [press, str(sg.name)], w("修好后回船坞就能看到施工。", "You will see the work done back at the berth."), "", press)
		return _card(1, 2, w("修「%s」：零件和钱都够了", "%s: PARTS AND MONEY ARE THERE") % str(sg.name), w("点卡片上的按钮打开船坞修缮页。", "Open the berth repairs with the button on this card."), "repair")
	var lack := ", ".join(sg.get("lack", []))
	var ships := ("、" if Txt.zh else ", ").join((sg.get("ships", []) as Array).slice(0, 2))
	if float(sg.get("short", 0.0)) > 0.5 and lack == "":
		return _card(1, 2, w("修「%s」还差 %s", "%s: %s SHORT") % [str(sg.name), Pal.money(float(sg.short))], w("接一单合同挣钱，或在账本里借款。", "Take a job, or borrow on the ledger."), "contracts")
	var how := (w("去拆：%s", "Strip: %s") % ships) if ships != "" else w("拆下的船壳送熔炉攒吨数", "Hull into the furnace counts")
	return _card(1, 2, w("修「%s」还缺 %s", "%s NEEDS %s") % [str(sg.name), _short(lack)], how, "contracts")


# "从船上拆回 1 件供电设备（电池、发电机这一类）" -> "1 件供电设备"
static func _short(s: String) -> String:
	var out := []
	for part in s.split(", "):
		var p := str(part)
		var cut := p.find("（")
		if cut < 0:
			cut = p.find(" (")
		if cut > 0:
			p = p.substr(0, cut)
		out.append(p.replace("从船上拆回 ", "").replace("从船上拆回", "").strip_edges())
	return "、".join(out) if Txt.zh else ", ".join(out)


# the port's next district stage (scripts/port.gd)
func _build() -> Dictionary:
	if Port.total_stages() > int(start.get("stages", 0)):
		return {"done": w("港区又修好一阶", "A PORT STAGE BUILT"), "end": true}
	var best := str(start.get("target", ""))
	# a district asked for by name: the one it waits on comes first
	while best != "" and not Port.deps_ok(best):
		var first := ""
		for dep in Port.DEPS.get(best, []):
			if Port.stage(str(dep[0])) < int(dep[1]):
				first = str(dep[0])
		best = first
	if best != "" and Port.stage(best) >= 2:
		best = ""
	if best == "":
		for z in Port.ZONES:
			if Port.stage(z) < 2 and Port.deps_ok(z) and (best == "" or Port.stage(z) < Port.stage(best)):
				best = z
	if best == "":
		return {"done": w("能修的港区都修好了", "EVERY PORT STAGE THAT CAN BE BUILT IS BUILT"), "end": true}
	var node := Route.port_node(best)
	var why := Route.missing(node)
	if node.get("ready", false):
		if _term(5):
			return _card(2, 2, w("按『%s』或『%s』修%s", "PRESS %s OR %s FOR THE %s") % [Txt.t("rp_fix_parts"), Txt.t("rp_fix_cash"), Port.name_of(best)], Port.desc_of(best, Port.stage(best) + 1), "", Txt.t("rp_fix_parts"))
		return _card(1, 2, w("开始建设%s（%s期）", "BUILD %s, PART %s") % [Port.name_of(best), Works.cn_num(Port.stage(best) + 1) if Txt.zh else str(Port.stage(best) + 1)], w("点击任务卡上的按钮，打开港区建设菜单。", "Open the port works with the button on this card."), "build:" + best)
	return _card(1, 2, w("修%s %d 阶还缺：%s", "%s STAGE %d NEEDS: %s") % [Port.name_of(best), Port.stage(best) + 1, why], w("接合同攒零件、结构吨和钱。", "Take jobs for parts, structure and money."), "contracts")


# the rail shuttle: walk to a stop, call it, ride
func _transit() -> Dictionary:
	var tram = game.get("tram")
	if tram == null:
		return {"done": w("这里没有接驳车", "NO SHUTTLE HERE"), "end": true}
	if bool(tram.riding):
		start.rode = true
		return _card(3, 3, w("接驳车运行中", "RIDING"), w("到站自动开门放你出来。", "It lets you out at the stop."))
	if bool(start.get("rode", false)):
		return {"done": w("坐过一次接驳车了：任何站台按 E 都能叫车", "YOU HAVE RIDDEN IT: E AT ANY STOP CALLS IT"), "end": true}
	var here: String = tram.near_station()
	# 123 号 (user 2026-11-04: "现在要求到中央转运环才能坐车，但我现在已经有拆船站的车了"): the
	# nearest stop, which from the berth is the salvage district's stop right over its gate (97 号)
	var to := nearest_stop(game)
	var st := {"n": 1, "of": 3, "target": Tram.station_at(to), "name": _stop_name(to), "purpose": w("接驳车沿走廊轨道连通六区，比飞快", "The shuttle runs the corridors to every district"), "button": "", "action": ""}
	if game.console_ui != null and is_instance_valid(game.console_ui) and game.console_ui.get("mode") == "tram":
		st.n = 2
		st.title = w("点一个要去的区", "PICK A DISTRICT")
		st.text = w("车会先开到你这一站接你。", "The car comes to your stop first.")
		return st
	if here != "":
		st.target = Tram.station_at(here)
		st.title = w("按 %s 叫接驳车", "PRESS %s TO CALL THE SHUTTLE") % Keys.label("use")
		st.text = st.purpose
		return st
	st.title = w("飞到%s", "FLY TO THE %s") % st.name
	st.text = w("从船坞顶上的闸口出去，站台就在闸口正上方。", "Out through the gate above the berth: the stop is right over it.") if to == "salvage" else w("跟着屏幕边上的箭头。", "Follow the arrow at the screen's edge.")
	return st


# the stop nearest the drone among those it can use (the berth's and the hub's from the start)
static func nearest_stop(g) -> String:
	var best := "salvage"
	if g == null or g.get("drone") == null:
		return best
	var bd := INF
	for z in Tram.found():
		var dd: float = (g.drone.global_position as Vector2).distance_to(Tram.station_at(str(z)))
		if dd < bd:
			bd = dd
			best = str(z)
	return best


func _stop_name(z: String) -> String:
	if z == "ring":
		return w("中央环站台", "HUB STOP")
	return w("%s站", "%s STOP") % Port.name_of(z)


# buying on the exchange: one seller's listing, a quantity, confirm
func _trade() -> Dictionary:
	if _buys() > int(start.get("buys", 0)):
		return {"done": w("成交了：货会实际运进仓库，到了才能用", "BOUGHT: THE GOODS ARE SHIPPED IN, USABLE ON ARRIVAL"), "end": true}
	var ui = game.console_ui
	if ui != null and is_instance_valid(ui) and ui.get_script() == preload("res://scripts/exchange_panel.gd"):
		if ui.purchase != null and ui.purchase.visible:
			return _card(3, 3, w("选数量，按『确认购买』", "SET THE QUANTITY AND CONFIRM"), w("只按这一家的价格和余量成交。", "Only this seller's price and stock."), "", "确认购买")
		return _card(2, 3, w("点一种货的卡片，再点一家卖方的『购买』", "PICK THE GOODS' CARD, THEN BUY FROM ONE SELLER"), w("每行是一家卖方的实际报价和余量，写着货从哪来、多久到。", "Each row is one seller's real offer, where from and how soon."), "", "购买")
	return _card(1, 3, w("打开交易行", "OPEN THE EXCHANGE"), w("买原料、卖产品、接工业客户都在这里。", "Buy feed, sell products, serve clients."), "exchange")


# the loadout page's scrap switch (19 号)
func _retain() -> Dictionary:
	if Career.retaining():
		return {"done": w("这一单的结构钢会记成公司原料进仓库", "THIS JOB'S STRUCTURAL STEEL GOES TO THE WAREHOUSE"), "end": true}
	var ui = game.console_ui
	if ui != null and is_instance_valid(ui) and ui.get("loadout") != null:
		return _card(2, 2, w("打开『废金属留作原料』，再按开工", "SWITCH ON KEEP THE SCRAP, THEN GO"), w("代价：这部分回收价不付现金，也不算修缮用的结构吨。", "It costs the scrap's cash and its repair tonnes."), "", "废金属留作原料")
	return _card(1, 2, w("接一单合同", "TAKE A JOB"), w("接单后弹出的配装页里有留料开关。", "The switch is on the loadout page after you sign."), "contracts")


# freight at the pier (31 号): fly to the hull, grapple a piece, haul it through the yard's
# east gate into the warehouse receiver (selling: from the loading table into the hold)
func _collect() -> Dictionary:
	var pier = game.get("freight_pier")
	if pier == null or pier.yard == null:
		return {"done": w("这里没有码头", "NO PIER HERE"), "end": true}
	var key := ""
	var ship := {}
	for s in Shipping.data().ships:
		for p in s.pieces:
			var wh := str(p.where)
			if (wh in ["hold", "deck"] and str(s.state) == "docked") or wh == "apron":
				if pier.bodies.has(str(p.key)) and is_instance_valid(pier.bodies[str(p.key)]):
					key = str(p.key)
					ship = s
					break
		if key != "":
			break
	if key == "":
		start.hauled = true if start.get("seen", false) else start.get("hauled", false)
		if start.get("seen", false):
			return {"done": w("码头上的货都搬完了", "THE PIER IS CLEAR"), "end": true}
		var c := Shipping.counts()
		if int(c.inbound) + int(c.queued) > 0:
			return _card(1, 3, w("货船在路上", "THE FREIGHTER IS ON ITS WAY"), w("到港后会靠上货运区码头；星图上能看它沿转移轨道飞。", "It will moor at the cargo pier; follow its arc on the star map."), "starmap")
		return {"done": w("没有待领的货", "NOTHING TO COLLECT"), "end": true}
	start.seen = true
	var b = pier.bodies[key]
	var goods_in := str(ship.dir) == "in"
	var st := {"n": 2, "of": 3, "name": w("码头", "PIER"), "purpose": w("货是实物：进了收货口才算入库", "Goods are real: stock once inside the receiver"), "button": "", "action": ""}
	if Port.stage("cargo") >= 1 and b.total_mass() <= Shipping.AUTO_MAX_T:
		st.target = b.global_position
		st.title = w("码头吊车在搬", "THE PIER CRANE HAS IT")
		st.text = w("货运区修好了，3 t 以下的件吊车自动搬。", "With the cargo district mended the crane takes pieces under 3 t.")
		return st
	if game.tools.held_body == b:
		st.n = 3
		if goods_in:
			st.target = pier.yard.warehouse.global_position
			st.title = w("拖进仓库收货口", "INTO THE WAREHOUSE RECEIVER")
			st.text = w("从院子东门进去，整件放进左边 WAREHOUSE 框里松开。", "Through the yard's east gate; let go with the whole piece inside the WAREHOUSE frame.")
		else:
			var hd = pier.hulls.get(str(ship.id), null)
			st.target = hd.hold.global_position if hd != null else b.global_position
			st.title = w("拖进货舱", "INTO THE HOLD")
			st.text = w("整件放进货舱里松开，装满就起航。", "Let go with the whole piece inside the hold; it sails when loaded.")
		return st
	st.target = b.global_position
	if not goods_in:
		st.title = w("飞到出货台，抓住一件货", "GRAPPLE A PIECE ON THE LOADING TABLE")
	elif int(ship.slot) >= 0 and str(ship.state) == "docked":
		st.title = w("飞到 %d 号船位，抓住一件货", "FLY TO BERTH %d, GRAPPLE A PIECE") % (int(ship.slot) + 1)
	else:
		st.title = w("飞到码头空地，抓住一件货", "FLY TO THE APRON, GRAPPLE A PIECE")
	st.text = w("码头在货运区下方仓库院子的东边。", "The pier runs east from the warehouse yard under the cargo district.")
	return st


# what comes after a task is done, and why
func _next(after: String) -> Array:
	match after:
		"sort":
			# the through line's heat is already in the furnace
			if Ops._busy(Career.data.get("industrial_heat", {})):
				return ["heat", w("黑色料已经在电弧炉里，去炉台测温、出钢", "the ferrous is in the furnace: sample and tap")]
			if _assay_grade():
				return ["assay", w("黑色炉料还没评级，要先化验", "the feed is unrated: assay it")]
		"assay":
			if _stock(Exchange.lot_key("ferrous_scrap", 1)) >= 0.25:
				return ["heat", w("钢锭可以开炉了", "grade 1 feed: run a heat")]
		"heat":
			if _stock(Exchange.lot_key("steel_billet", 1)) > Exchange.EPS:
				return ["clients", w("钢坯交给工业客户", "billets for the client")]
		"buy_feed":
			return ["heat", w("钢锭到了，开炉", "the feed is in: run a heat")]
	return ["", ""]


static func task_name(t: String) -> String:
	return {"sort": ["分选", "SORTING"], "assay": ["化验", "ASSAY"], "heat": ["炉台炼钢", "FURNACE"], "clients": ["客户发运", "CLIENT SHIPMENT"], "buy_feed": ["买炉料", "BUY FEED"],
		"repair": ["船坞修缮", "BERTH REPAIR"], "build": ["港区建设", "PORT WORKS"], "transit": ["接驳车", "SHUTTLE"], "trade": ["交易行买货", "BUYING"], "retain": ["留料开关", "KEEP THE SCRAP"],
		"collect": ["码头领货", "COLLECTING FREIGHT"]}.get(t, ["", ""])[0 if Txt.zh else 1]


func _compute() -> Dictionary:
	match task:
		"sort": return _sort()
		"assay": return _assay()
		"heat": return _heat()
		"clients": return _clients()
		"buy_feed": return _buy_feed()
		"repair": return _repair()
		"build": return _build()
		"transit": return _transit()
		"trade": return _trade()
		"retain": return _retain()
		"collect": return _collect()
	return {}


func _process(dt: float) -> void:
	note_t += dt
	if task == "" or game == null:
		quiet = false
		return
	if not game.in_berth():
		quiet = false
		return
	_t += dt
	if _t < 0.15:
		_pulse()
		return
	_t = 0.0
	var s := _compute()
	if s.has("done"):
		var nx := [] if s.get("end", false) else _next(task)
		if nx.is_empty() or str(nx[0]) == "":
			note = w("完成：%s", "DONE: %s") % str(s.done)
			note_t = 0.0
			stop()
			return
		note = w("完成：%s · 接着：%s（%s）", "DONE: %s · NEXT: %s (%s)") % [str(s.done), task_name(str(nx[0])), str(nx[1])]
		note_t = 0.0
		begin(str(nx[0]))
		s = _compute()
	s.task = task
	step = s
	quiet = true
	_light(str(step.get("button", "")))
	_pulse()


# the open panel's button to press next gets a pulsing heat frame
func _light(prefix: String) -> void:
	var ui = game.console_ui if game != null else null
	if ui == null or not is_instance_valid(ui):
		return
	for b in ui.find_children("*", "Button", true, false):
		var hit: bool = prefix != "" and str(b.text).begins_with(prefix) and not b.disabled
		if hit:
			for st in ["normal", "hover", "focus"]:
				b.add_theme_stylebox_override(st, _hl)
			b.set_meta("guide_lit", true)
		elif b.has_meta("guide_lit"):
			for st in ["normal", "hover", "focus"]:
				b.remove_theme_stylebox_override(st)
			b.remove_meta("guide_lit")


func _pulse() -> void:
	var k := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.005))
	_hl.border_color = Pal.heat(k, 1.6)


func _exit_tree() -> void:
	quiet = false


# the card's action button: open the exchange where the step needs it
func act() -> void:
	var a := str(step.get("action", ""))
	if game.console_ui != null:
		return
	match a:
		"starmap":
			game.open_star_map()
		"clients":
			game.open_exchange("clients")
		"feed":
			game.open_exchange("feed")
		"exchange":
			game.open_exchange()
		"heat_send":
			var q := minf(2.0, floorf(_stock(Exchange.lot_key("ferrous_scrap", 1)) * 100.0) / 100.0)
			var r: Dictionary = game.industrial_heat.begin(q, true)
			if r.get("ok", false):
				game.hud.show_hint(w("钢锭出库了：%.2f t 正送往炉口", "THE INGOTS ARE ON THEIR WAY: %.2f t") % q)
				if game.get("sfx") != null:
					game.sfx.play("menu")
			else:
				game.hud.show_hint(str(r.get("reason", "")))
				if game.get("sfx") != null:
					game.sfx.play("deny")
		"contracts":
			game.open_console("terminal")
			if game.console_ui != null:
				game.console_ui._skip_boot()
				game.console_ui.set_tab(0)
		"repair":
			game.open_console("terminal")
			if game.console_ui != null:
				game.console_ui._skip_boot()
				game.console_ui.set_tab(1)
				var id := str(start.get("target", ""))
				if id == "":
					id = str(Repair.suggestion().get("id", ""))
				if id != "" and game.console_ui.repair_panel != null and game.console_ui.repair_panel.has_method("_pick"):
					game.console_ui.repair_panel._pick(id)
		_:
			if a.begins_with("build:"):
				game.open_console("port:" + a.substr(6))
