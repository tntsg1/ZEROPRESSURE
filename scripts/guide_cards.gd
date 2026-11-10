extends RefCounted
# 132 号 情境引导 (design/132_控制台规范与情境引导_草图稿_2026-11-07.md §二; user 2026-11-07 "全按推荐"):
# the first time something happens — a district entered, the first strip, the first whole machine,
# the stores nearly full, the first listing, the first short of power, an order about to lapse, the
# first mould change, the first overload trip, the first time at a console — the game pauses and one
# card in the middle of the screen says it: a moving drawing (scripts/guide_card.gd, the codex's
# manner) and at most three lines — what happened, why, where to do it — with "带我去 [Enter]" and
# "知道了 [Esc]". Each once (Career.data.guide_seen); the book's "讲解" tab shows them again. While a
# card is up the main line's strip, its target mark, the next-step marks and the first-meeting card
# step aside (scripts/hud.gd asks showing()), and come back when it is closed. A setting turns the
# cards off (Txt.guide_cards). The words are in data/台词.txt ("G_<id>_t", "G_<id>_1…3").
#
# Driven by the HUD twice a second (tick). The cards wait for the other guides (the port walk, the
# first-ship coach, the stores guide, the old guide, the tour), for a page to close (but the console
# cards, which come with their page), and the district cards for the drone to stop.

const PortStructure = preload("res://scripts/port_structure.gd")
const PS5 = preload("res://scripts/power_supply.gd")
const Card = preload("res://scripts/guide_card.gd")

const GAP_S := 20.0            # game seconds between two cards
const STOP_MS := 0.5           # a district card waits for the drone below this (m/s)
const ZONES := ["power", "trade", "process", "cargo", "tug", "ring"]
const ORDER := ["power_short", "first_trip", "store_full", "order_due", "first_listing", "first_mould", "first_equip", "first_strip",
	"zone_power", "zone_trade", "zone_process", "zone_cargo", "zone_tug", "zone_ring"]
const CONSOLES := ["console_trade", "console_hall", "console_queue", "console_gas", "console_heat", "console_mill"]

# id: title, three lines (zh, en), the drawing, where "带我去" leads ("" none)
const CARDS := {
	"zone_power": {"t": ["动力区", "POWER DISTRICT"], "art": "zone", "zone": "power", "go": "district:power", "l": [
		["全港的电从这儿出。", "The port's power comes from here."],
		["电力不足时，炉子、吊车、叉车都按功率百分比干活。", "Underpowered, the furnace, cranes and forklifts work at that per cent."],
		["修好发电机，或者先买块电池顶着。", "Mend the sets, or buy a battery block meanwhile."]]},
	"zone_trade": {"t": ["贸易港", "TRADE PORT"], "art": "zone", "zone": "trade", "go": "district:trade", "l": [
		["买卖都在这儿做。", "Buying and selling happen here."],
		["没修好以前，东西只能卖给回收站，打六折。", "Until it is mended, goods go to the recycler at sixty per cent."],
		["修好它，按市价卖。", "Mend it and sell at market."]]},
	"zone_process": {"t": ["加工区", "PROCESSING"], "art": "zone", "zone": "process", "go": "district:process", "l": [
		["钢锭在这儿炼成钢坯，再轧成钢板。", "Ingots become billets here, billets become plate."],
		["炼过的比原料值钱。", "Worked steel pays more than raw."],
		["先去最左边的炉台，排一炉。", "Go to the furnace desk at the far left and queue a heat."]]},
	"zone_cargo": {"t": ["货运区", "CARGO DISTRICT"], "art": "zone", "zone": "cargo", "go": "store", "l": [
		["拆回来的东西都放这儿。", "Everything you salvage is kept here."],
		["格子满了，下一艘就拆不了。", "When the cells are full, the next ship cannot be taken."],
		["到两边货架口按 E 看库存。", "Press E at a rack mouth to see the stock."]]},
	"zone_tug": {"t": ["拖船站", "TUG STATION"], "art": "zone", "zone": "tug", "go": "district:tug", "l": [
		["拖船从这儿出去，把船拖回来。", "Tugs leave from here and bring hulks home."],
		["租的拖船只拖得动 44 米以下的。", "A rented tug tows nothing over 44 m."],
		["修好它，大船自己拖。", "Mend it and tow the big ones yourself."]]},
	"zone_ring": {"t": ["中央转运环", "CENTRAL RING"], "art": "zone", "zone": "ring", "go": "district:ring", "l": [
		["六条走廊在这儿碰头。", "Six corridors meet here."],
		["坐接驳车，去哪个区都是 10 秒左右。", "The shuttle takes you to any district in about 10 s."],
		["最后要让它重新转起来。", "In the end it has to turn again."]]},
	"first_strip": {"t": ["开工", "FIRST STRIP"], "art": "strip", "go": "", "l": [
		["先断电，再泄压，最后动刀。", "Power off, then vent, then cut."],
		["左上角一条一条告诉你下一步。", "The top left tells you each next step."],
		["拆坏了扣钱，慢点没事。", "Breaking things costs money. Slow is fine."]]},
	"first_equip": {"t": ["整件设备", "A WHOLE MACHINE"], "art": "equip", "go": "", "l": [
		["整件拆下来的比碎料值钱。", "A machine taken off whole is worth more than scrap."],
		["送设备回收口，按设备价算。", "The equipment mouth pays the machine's price."],
		["结算时留着修港，或者直接卖。", "At settlement keep it for mending, or sell it."]]},
	"store_full": {"t": ["仓库快满了", "STORES NEARLY FULL"], "art": "store", "go": "store", "l": [
		["仓库用了八成。", "The stores are 80 % full."],
		["再拆一艘，可能放不下。", "The next ship may not fit."],
		["卖掉一些，或者修货运区扩仓。", "Sell some, or mend the cargo district for more room."]]},
	"first_listing": {"t": ["挂上了", "LISTED"], "art": "listing", "go": "hall:sell", "l": [
		["货挂到交易行了。", "It is on the exchange."],
		["有人买就成交，钱当场到账。", "When someone buys, the cash is in at once."],
		["价挂太高没人买，看旁边的市价。", "Asked too high, nobody buys. Watch the market price beside it."]]},
	"power_short": {"t": ["电力不足—功率 {n}%", "UNDERPOWERED — {n}% POWER"], "art": "power", "go": "district:power", "l": [
		["发电机顶不住，全港功率只有 {n}%。", "The sets cannot keep up: the port has {n}% of its power."],
		["{who}", "{who}"],
		["去动力区，买块电池，或者修发电机。", "Go to the power district: buy a battery, or mend the sets."]]},
	"order_due": {"t": ["订单快到期", "ORDER ABOUT TO LAPSE"], "art": "order", "go": "hall:orders", "l": [
		["{client}那单还剩 {m} 分钟。", "{client}'s order has {m} min left."],
		["过期这单就没了，长期合同还扣信誉。", "Lapsed, it is gone; a standing contract also costs reputation."],
		["仓库有货就去交，没货就排一炉。", "Deliver from stock, or queue a heat."]]},
	"first_mould": {"t": ["换模", "MOULD CHANGE"], "art": "mould", "go": "queue", "l": [
		["下一炉要的模具不一样，吊车在换。", "The next heat wants another mould; the crane is changing it."],
		["换一次，炉子停十来秒。", "Each change stops the furnace about ten seconds."],
		["同一种排在一起炼，少换几次。", "Queue the same mould together and change less."]]},
	"first_trip": {"t": ["发电机跳闸了", "A SET HAS TRIPPED"], "art": "trip", "go": "trip", "l": [
		["超载太久，发电机烧热停了。", "Overloaded too long, the set overheated and stopped."],
		["不修它不会自己起来。", "It will not come back by itself."],
		["飞过去，拿维护工具（4）修一下。", "Fly there and use the maintenance tool (4) on it."]]},
	"console_trade": {"t": ["贸易港终端", "TRADE PORT CONSOLE"], "art": "console", "go": "", "l": [
		["码头来客人，在这儿谈。", "Visitors at the pier are dealt with here."],
		["三家公司的长期合同，也在这儿签。", "The three companies' standing contracts are signed here."],
		["顶上那行说“用得上”再来，平时不用管。", "Come when the top line says it is worth it. Otherwise leave it."]]},
	"console_hall": {"t": ["交易行", "THE EXCHANGE"], "art": "console", "go": "", "l": [
		["卖货、买零件、交订单，都在这儿。", "Sell, buy parts and fill orders here."],
		["卖：挑货，填价，挂出去。", "Sell: pick it, set the price, list it."],
		["订单是别人点名要的货，比市价高。", "Orders are goods someone asks for, above market."]]},
	"console_queue": {"t": ["加工队列", "PROCESSING QUEUE"], "art": "console", "go": "", "l": [
		["炉子按这张单子一炉一炉炼。", "The furnace works down this list, heat by heat."],
		["排一炉，炉子自己装料、熔化、浇铸。", "Queue a heat: it charges, melts and casts by itself."],
		["拖动换先后，同一种模具排一起。", "Drag to reorder; keep the same mould together."]]},
	"console_gas": {"t": ["气体线", "GAS LINE"], "art": "console", "go": "", "l": [
		["拆船抽回来的气，在这儿分离、液化。", "Gas drawn from ships is separated and liquefied here."],
		["液氧、液氢在交易行卖，接订单也行。", "LOX and LH2 are sold on the exchange, or to orders."],
		["平时不用管，顶上那行亮了再来。", "Leave it until the top line lights up."]]},
	"console_heat": {"t": ["炉台", "FURNACE DESK"], "art": "console", "go": "", "l": [
		["电弧炉的现场开关。", "The arc furnace's own desk."],
		["排好的炉子自己炼，这儿看温度、出钢。", "Queued heats run by themselves; here you watch the heat and tap."],
		["第一炉要你在这儿亲手出一次钢。", "The first heat is tapped by hand, here."]]},
	"console_mill": {"t": ["轧机", "ROLLING MILL"], "art": "console", "go": "", "l": [
		["钢坯在这儿轧成钢板或型材。", "Billets are rolled into plate or sections here."],
		["点一种，按 Enter 开轧。", "Pick one and press Enter to roll."],
		["开着连续轧，钢坯一到就轧。", "With rolling on, each billet is rolled as it comes."]]},
}

static var card = null                 # the card on screen
static var test_pause_ok := true       # tests: whether the card may pause the tree
static var _gap := GAP_S               # game seconds since the last card closed
static var _t := 0.0
static var _pend := {}                 # id -> args, raised by signals
static var _hooked = null
static var _last_console = null
static var shown_log: Array = []       # tests: the ids shown, in order


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# a test run sees no cards unless it asks for them (the older tests press Enter and Esc on their pages)
static var force_on := false
static var test_due := {}              # tests: id -> args, a moment made by hand


static func on() -> bool:
	if Career._test_run() and not force_on:
		return false
	return Txt.guide_cards


static func showing() -> bool:
	return card != null and is_instance_valid(card) and card.is_inside_tree()


static func seen(id: String) -> bool:
	return not Career.data.is_empty() and Career.data.get("guide_seen", {}).has(id)


static func seen_ids() -> Array:
	var out: Array = []
	var gs: Dictionary = Career.data.get("guide_seen", {}) if not Career.data.is_empty() else {}
	for id in ORDER + CONSOLES:
		if gs.has(id):
			out.append(id)
	return out


static func mark(id: String) -> void:
	if Career.data.is_empty():
		return
	var gs: Dictionary = Career.data.get("guide_seen", {})
	if gs.has(id):
		return
	gs[id] = int(Time.get_unix_time_from_system())
	Career.data.guide_seen = gs
	# 合并: the main line's own card for the same moment is not opened as well
	var ch: String = {"power_short": "power", "store_full": "cargo"}.get(id, "")
	if ch != "":
		var mc: Dictionary = Career.data.get("main_card", {})
		mc[ch] = true
		Career.data.main_card = mc
	Career.save()


# would this card come up now if its moment came (on, not seen yet)? — the overload's own
# message line stays quiet then (the card says it)
static func will_show(id: String) -> bool:
	return on() and Career.usable() and not seen(id)


# the words, the author's file first ("G_<id>_t", "G_<id>_1…3"), placeholders filled
static func _pick(pair: Array) -> String:
	return str(pair[0]) if Txt.zh else str(pair[1])


static func _fill(s: String, args: Dictionary) -> String:
	for k in args:
		s = s.replace("{%s}" % k, str(args[k]))
	return s


static func title(id: String, args := {}) -> String:
	var p: Array = Lines.get_pair("G_%s_t" % id)
	var s := str(p[0] if Txt.zh else (p[1] if str(p[1]) != "" else p[0])) if p.size() == 2 and str(p[0]) != "" else _pick(CARDS[id].t)
	return _fill(s, args)


static func lines(id: String, args := {}) -> Array:
	var out: Array = []
	for i in 3:
		var p: Array = Lines.get_pair("G_%s_%d" % [id, i + 1])
		var s := str(p[0] if Txt.zh else (p[1] if str(p[1]) != "" else p[0])) if p.size() == 2 and str(p[0]) != "" else _pick(CARDS[id].l[i])
		s = _fill(s, args)
		if s.strip_edges() != "":
			out.append(s)
	return out


# ---------------------------------------------------------------- the moments

static func _power_args(game) -> Dictionary:
	var n := Grid.pct(game)
	var gn := Grid.groups_now(game)
	var parts: Array = []
	var groups: Array = []
	var first := true
	for g in Grid.order():
		if not gn.has(g) or float(gn[g].want) <= 0.01 or str(g) == "base":
			continue
		var p := Grid.pct(game, str(g))
		groups.append([Grid.group_name(str(g)), p])
		if first:
			parts.append(w("%s排第一，先拿满" if p >= 100 else "%s排第一，也只有 %d%%", "%s comes first and gets all it asks" if p >= 100 else "%s comes first and still gets %d%%") % ([Grid.group_name(str(g))] if p >= 100 else [Grid.group_name(str(g)), p]))
			first = false
		else:
			parts.append(w("%s功率 %d%%", "%s at %d%%") % [Grid.group_name(str(g)), p])
	var who := ""
	if not parts.is_empty():
		who = str(parts[0]) + (w("；", "; ") + w("，", ", ").join(PackedStringArray(parts.slice(1))) if parts.size() > 1 else "") + w("。", ".")
	return {"n": n, "who": who, "groups": groups}


static func _order_args() -> Dictionary:
	if HallMarket.open():
		for o in HallMarket.live_orders():
			if str(o.state) in ["open", "taken"] and HallMarket.mins_left(o) <= 3:
				return {"client": str(o.client), "m": HallMarket.mins_left(o), "kind": str(o.kind)}
	for who in TradePeople.orgs():
		var c: Dictionary = TradePeople.orgs()[who].get("contract", {})
		if c.is_empty():
			continue
		var have := float(Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {}).get(str(c.key), 0.0))
		if float(c.next_in) <= 60.0 and have < float(c.qty):
			return {"client": TradePeople.org_name(str(who)), "m": 1, "kind": str(c.key)}
	return {}


static func _trip_id() -> String:
	if not PS5.ENABLED:
		return ""
	for id in PS5.d().get("gens", {}):
		if bool(PS5.d().gens[id].get("trip", false)):
			return str(id)
	return ""


# the moment for a card now, with what it says ({} when it is not its moment)
static func _due(game, id: String) -> Variant:
	if test_due.has(id):
		return test_due[id]
	match id:
		"power_short":
			if not Grid.applies(game) or not Mainline.power_open():
				return null
			var v := Grid.verdict(game)
			return null if bool(v.ok) else _power_args(game)
		"first_trip":
			var tid := _trip_id()
			return {"gen": tid} if tid != "" else null
		"store_full":
			return {"pct": int(round(100.0 * StoreBook.used() / maxf(1.0, StoreBook.cap())))} if StoreBook.live() and StoreBook.cap() > 0 and float(StoreBook.used()) >= 0.8 * StoreBook.cap() else null
		"order_due":
			var a := _order_args()
			return a if not a.is_empty() else null
		"first_listing":
			return {} if Port.stage("trade") >= 1 and HallMarket.open() and not HallMarket.listings().is_empty() else null
		"first_mould":
			return {} if ProcessLine.changing() else null
		"first_equip":
			return _pend.get("first_equip", null)
		"first_strip":
			return {} if not game.in_berth() and not game.job.is_empty() and game.career() else null
	if id.begins_with("zone_"):
		var z := id.substr(5)
		if game.drone == null or game.walk_on():
			return null
		if PortStructure.zone_at(game.drone.global_position) != z:
			return null
		return {} if game.drone.linear_velocity.length() < STOP_MS * Geom.M else null
	return null


# the guides that speak for themselves; a card waits for them
static func _quiet(game) -> bool:
	if game.state != "play" or game.menu_open or game.training or game.exam != null:
		return false
	if game.walk_on() or game.coach_on() or game.store_guide_on():
		return false
	if game.guide != null and game.guide.active():
		return false
	if game.port_tour != null and is_instance_valid(game.port_tour):
		return false
	if game.prologue != null and is_instance_valid(game.prologue) and not game.prologue.done:
		return false
	if game.get_tree().paused:
		return false
	return true


# the console the page on screen is (its card's id), "" none
static func console_of(ui) -> String:
	if ui == null or not is_instance_valid(ui) or ui.get_script() == null:
		return ""
	match ui.get_script().resource_path.get_file():
		"district_panel.gd":
			if str(ui.zone) == "trade" and Port.stage("trade") >= 1:
				return "console_trade"
			if str(ui.zone) == "process" and Port.stage("process") >= 1:
				return "console_gas"
		"hall_panel.gd": return "console_hall"
		"process_queue_panel.gd": return "console_queue"
		"heat_panel.gd": return "console_heat"
		"mill_panel.gd": return "console_mill"
	return ""


static func _hook(game) -> void:
	if _hooked == game:
		return
	_hooked = game
	_pend = {}
	if game.has_signal("load_received"):
		game.load_received.connect(func(_keys, zone, _v, _job):
			if str(zone) == "equip" and not game.training and not seen("first_equip"):
				_pend["first_equip"] = {})


# from the HUD each frame
static func tick(game, dt: float) -> void:
	if game == null or not is_instance_valid(game) or not Career.usable() or Career.data.is_empty() or not game.career():
		return
	_hook(game)
	if showing():
		return
	_gap += dt
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	if not on():
		return
	# the console cards come with their page, the first time it opens
	var cid := console_of(game.console_ui)
	if cid != "" and game.console_ui != _last_console:
		_last_console = game.console_ui
		if not seen(cid) and not game.walk_on():
			show(game, cid, {})
			return
	if game.console_ui == null:
		_last_console = null
	if game.console_ui != null or not _quiet(game) or _gap < GAP_S:
		return
	for id in ORDER:
		if seen(id):
			continue
		var a = _due(game, id)
		if a == null:
			continue
		show(game, str(id), a)
		return


# up on the screen: the tree paused, the card on top
static func show(game, id: String, args: Dictionary, replay := false, host: Node = null) -> void:
	if showing() or not CARDS.has(id):
		return
	if not replay:
		mark(id)
		_pend.erase(id)
		shown_log.append(id)
	var c = Card.new()
	c.id = id
	c.args = args
	c.game = game
	c.replay = replay
	c.title = title(id, args)
	c.lines = lines(id, args)
	c.go = "" if replay else str(CARDS[id].get("go", ""))
	c.art = str(CARDS[id].art)
	c.zone = str(CARDS[id].get("zone", ""))
	var layer := CanvasLayer.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var at: Node = host if host != null else (game if game != null and is_instance_valid(game) else null)
	if at == null:
		return
	at.add_child(layer)
	layer.add_child(c)
	c.was_paused = at.get_tree().paused
	if test_pause_ok:
		at.get_tree().paused = true
	if game != null and is_instance_valid(game) and not replay:
		c.was_sim = game.paused_sim
		game.paused_sim = true
	card = c


# the card closed: the tree as it was, the gap starts, "带我去" goes
static func closed(c, take: bool) -> void:
	if c == card:
		card = null
	_gap = 0.0
	var tree: SceneTree = c.get_tree()
	if tree != null:
		tree.paused = c.was_paused
	var game = c.game
	if game != null and is_instance_valid(game) and not c.replay:
		game.paused_sim = c.was_sim
	var layer = c.get_parent()
	if layer != null:
		layer.queue_free()
	# 2026-11-09 (owner): the cards have no "带我去" any more; only the tripped set, which can trip
	# anywhere, still gets its arrow — on its own, as the card closes
	if (take or str(c.go) == "trip") and str(c.go) != "" and not c.replay and game != null and is_instance_valid(game):
		(func(): take_me(game, str(c.go), c.args)).call_deferred()


static func take_me(game, go: String, args: Dictionary) -> void:
	if go.begins_with("district:"):
		if game.console_ui == null:
			game.open_district(go.substr(9))
	elif go == "store":
		game.open_store()
	elif go.begins_with("hall:"):
		game.open_hall(go.substr(5), str(args.get("kind", "")) if go == "hall:orders" else "")
	elif go == "queue":
		game.open_queue_panel()
	elif go == "trip":
		var tid := str(args.get("gen", "tg"))
		var lead = preload("res://scripts/guide_lead.gd").new()
		lead.game = game
		lead.target = PortStructure.box("power").position + PS5.repair_at(tid) * PortStructure.M()
		lead.label = PS5.gen_name(tid)
		game.add_child(lead)


# tests: everything back to the start
static func reset() -> void:
	card = null
	_gap = GAP_S
	_t = 0.0
	_pend = {}
	_hooked = null
	_last_console = null
	shown_log = []
	test_due = {}
