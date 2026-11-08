class_name Mainline
# The main line (design/…/28_新手教程引导与主线, Q16–Q21; player 2026-10-24: "there should be
# a guide to the next main-line task, so the player knows where to go"). Fixed chapters; inside
# each, the next step is worked out from the real state. A step says what to do and where it
# leads (`go`): "guide:<task>[:<target>]" starts the on-site guide, "contracts" opens the
# contracts, "wait" only shows progress. Chapter names and step lines are interface text;
# Liang's words at a chapter's start and end are the author's (L_main_<id>_start / _done).

# 128 号 第 3 段 (user 2026-11-05, design/…/128_港区从头设计 §五 §十二): the berth first, then the port a
# district at a time, each opened by the need the player really runs into — "逐步先完成修船厂，然后再
# 扩展到其他的部分". Chapter names are that need. The numbers are fixed; the strip points at the first
# chapter (by number) whose need has come up and which is not done (C), so nothing that can be mended
# now is hidden behind a chapter still waiting. "修" works at any time; the main line only leads.
const CHAPTERS := ["opening", "lights", "furnace", "trade", "process", "cargo", "power", "tug", "berth88", "ring", "ark"]
const NAMES := {
	"opening": ["第一艘船", "THE FIRST HULK"],
	"lights": ["船坞太暗了", "THE BERTH IS DARK"],
	"furnace": ["碎料白白漏掉", "THE SCRAP GOES TO WASTE"],
	"trade": ["回收站只给六成", "THE RECYCLER PAYS SIXTY PER CENT"],
	"process": ["钢锭攒够了", "ENOUGH INGOTS"],
	"cargo": ["仓库快满了", "THE STORES ARE NEARLY FULL"],
	"power": ["电不够用了", "SHORT OF POWER"],
	"tug": ["船太大，拖不动", "TOO BIG TO TOW"],
	"berth88": ["船坞放不下了", "THE BERTH IS TOO SHORT"],
	"ring": ["让中央转运环重新转起来", "GET THE TRANSFER RING TURNING AGAIN"],
	"ark": ["远航者", "THE ARK"],
}
const CARGO_FULL := 0.8          # the stores this full: the cargo district's chapter begins
const INGOT_T := 2.0             # ingots in store: the processing district's chapter begins

const Exchange = preload("res://scripts/industrial_exchange.gd")


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func name_of(id: String) -> String:
	return NAMES.get(id, [id, id])[0 if Txt.zh else 1]


# 126 号 (user 2026-11-04 "炼出钢坯就算"): a heat's billets received into the warehouse — the
# rolling mill may take them on to plate at once ("连续轧", the processing queue), so selling them
# could never be counted on; a billet sold before still counts
static func _billet_made() -> bool:
	for m in Career.data.get("material_batches", []):
		if str(m.get("material", "")) == "steel_billet" and str(m.get("state", "")) == "product_received":
			return true
	return _billet_sold()


static func _billet_sold() -> bool:
	for trade in Career.data.get("exchange", {}).get("trades", []):
		# sold is sold: paid on the sale (37 号), or an older delivered sale
		if trade.get("seller", "") == Exchange.PLAYER and (trade.get("state", "") == "delivered" or trade.get("paid", false)) and str(trade.get("item", "")) == "steel_billet":
			return true
	return false


static func done(id: String) -> bool:
	var d := Career.data
	var up: Dictionary = d.get("upgrades", {})
	match id:
		# the first hulk stripped, its haul in the stores and the first sale made (128 号 第 1 段)
		"opening": return d.get("market", false) and (not StoreBook.live() or d.get("seen", {}).has("store_guide_done") or d.get("history", []).size() >= 2)
		"lights": return up.has("lights")
		"furnace": return up.has("furnace_main") and up.has("net_fix")
		"trade": return Port.stage("trade") >= 1
		"process": return Port.stage("process") >= 1 and _billet_made()
		"cargo": return Port.stage("cargo") >= 1
		"power": return Port.stage("power") >= 1
		"tug": return Port.stage("tug") >= 1
		"berth88": return up.has("berth88")
		"ring": return Port.stage("ring") >= 2
	return false


# 第 3 段: has the need that starts this chapter come up? Once it has, it stays (Career.data.need_hit)
static func hit(id: String) -> bool:
	if done(id):
		return true
	var nh: Dictionary = Career.data.get("need_hit", {})
	if nh.has(id):
		return true
	var d := Career.data
	match id:
		"opening": return true
		"lights", "furnace": return d.get("market", false)
		"trade": return done("lights") and done("furnace")
		"process": return float(StoreBook.raw_stock().get(Exchange.INGOT, 0.0)) >= INGOT_T - 0.001 or Port.stage("process") >= 1
		"cargo": return StoreBook.live() and StoreBook.cap() > 0 and float(StoreBook.used()) >= CARGO_FULL * StoreBook.cap()
		"power": return false            # set by watch(): the first slowdown for want of power
		"tug": return _found_longer(TugYard.MAX_LEN[0])
		"berth88": return _found_longer(Dock.STANDARD)
		"ring": return done("tug") and done("berth88") and done("power") and done("cargo")
		"ark": return done("ring")
	return false


static func _found_longer(m: float) -> bool:
	for o in Career.data.get("offers", []):
		if o.get("find", false) and float(Market.type_of(str(o.get("ship", ""))).get("length", 0.0)) > m:
			return true
	if Career.data.has("ship_market"):
		for a in ShipMarket.data().assets:
			if float(Market.type_of(TugYard.ship_of(a)).get("length", 0.0)) > m:
				return true
	return false


static func _remember(id: String) -> void:
	var nh: Dictionary = Career.data.get("need_hit", {})
	if nh.has(id):
		return
	nh[id] = int(Time.get_unix_time_from_system())
	Career.data.need_hit = nh
	Career.save()


# twice a second from the HUD: a need that came up is kept, so a chapter never goes away again (the
# stores emptied again, the power back) — and the power's shortage can only be seen with the game
static func watch(game) -> void:
	if not Career.usable() or Career.data.is_empty():
		return
	for id in CHAPTERS:
		if id != "opening" and not done(id) and not Career.data.get("need_hit", {}).has(id) and hit(id):
			_remember(id)
	if not done("power") and not Career.data.get("need_hit", {}).has("power") and game != null and Port.stage("process") >= 1:
		var v: Dictionary = Grid.verdict(game)
		if not bool(v.get("ok", true)):
			_remember("power")


# the chapter the career is in: the first not done
static func chapter() -> String:
	for id in CHAPTERS:
		if not done(id) and hit(id):
			return id
	return ""


# the first chapter not done, whether its need has come up or not ("" all done): what is next
static func next_open() -> String:
	for id in CHAPTERS:
		if not done(id):
			return id
	return ""


# what starts a chapter, for the chapter list's dim rows
static func trigger_text(id: String) -> String:
	match id:
		"lights", "furnace": return w("拆完第一艘船以后", "Once the first hulk is stripped")
		"trade": return w("船坞修好以后", "Once the berth is mended")
		"process": return w("仓库里钢锭攒到 %.0f 吨时", "When %.0f t of ingots are in store") % INGOT_T
		"cargo": return w("仓库用到八成时", "When the stores are 80 % full")
		"power": return w("第一次因为缺电，炉子或叉车变慢时", "The first time the furnace or the forklifts slow for want of power")
		"tug": return w("星图扫到超过 %d m 的船时", "When the star map finds a hulk over %d m") % int(TugYard.MAX_LEN[0])
		"berth88": return w("扫到超过 %d m、船坞放不下的船时", "When a hulk over %d m turns up, too long for the berth") % int(Dock.STANDARD)
		"ring": return w("前面几区都修好以后", "Once the districts before it are mended")
		"ark": return w("中央转运环修好以后", "Once the transfer ring turns")
	return ""


# what a chapter opens, for the list and the opening card
static func opens_text(id: String) -> String:
	match id:
		"opening": return w("仓库 · 回收站", "Stores · recycling station")
		"lights": return w("修船坞照明 → 看得清、切得快", "Mend the berth's lights: clear readings, faster cutting")
		"furnace": return w("修熔炉和接碎料的网 → 碎料炼成钢锭", "Mend the furnace and the net: scrap becomes ingots")
		"trade": return w("修贸易港一期 → 交易行、订单板（即将开放）", "Mend the trade port: exchange and order board (opening soon)")
		"process": return w("修加工区一期 → 钢锭炼成钢坯", "Mend the processing district: ingots into billets")
		"cargo": return w("修货运区 → 仓库 8×32 变 8×48", "Mend the cargo district: the stores grow 8×32 → 8×48")
		"power": return w("修动力区 → 自家发电，炉子和叉车不再变慢", "Mend the power district: your own power, no more slowdowns")
		"tug": return w("修拖船站 → 能拖超过 %d m 的船", "Mend the tug station: tow hulks over %d m") % int(TugYard.MAX_LEN[0])
		"berth88": return w("把船坞扩到 88 m → 能拆更大的船", "Extend the berth to 88 m for bigger hulks")
		"ring": return w("修中央转运环", "Mend the transfer ring")
		"ark": return w("以后的版本开放", "In a later version")
	return ""


static func index(id: String) -> int:
	return CHAPTERS.find(id) + 1


# a repair step: fix it now, or what it lacks and where that comes from
static func _repair_step(id: String) -> Dictionary:
	# 86 号 Q9: a fault not seen yet — go and look first (seen, it is logged and the step moves on)
	if not Repair.found(id):
		return {"text": w("先飞去看「%s」坏在哪（飞近就记下）。", "Fly over and look at the %s (close up logs it).") % Repair.name_of(id), "go": "guide:repair:" + id}
	var info := Guide.repair_info(id)
	if info.get("ready", false):
		return {"text": w("去修「%s」：零件和钱都够了。", "Mend %s: parts and money are there.") % str(info.name), "go": "guide:repair:" + id}
	return {"text": w("修「%s」还需要：%s。", "To mend %s you still need: %s.") % [str(info.name), str(info.lack)], "go": "guide:repair:" + id}


# a district step: build its next stage (or the one it waits on first)
static func _build_step(zone: String) -> Dictionary:
	for dep in Port.DEPS.get(zone, []):
		if Port.stage(str(dep[0])) < int(dep[1]):
			return _build_step(str(dep[0]))
	if Port.RepairBill.ON:
		var b: Dictionary = Port.RepairBill.of(zone)
		var nm := "%s（%s期）" % [Port.name_of(zone), Works.cn_num(Port.stage(zone) + 1)] if Txt.zh else "%s (part %d)" % [Port.name_of(zone), Port.stage(zone) + 1]
		var why := Port.reason(zone, true)
		if why == "":
			var buy := float(b.get("buy_cash", 0.0))
			var tail := w("仓库里的材料都够。", "The stores have it all.") if buy < 0.5 else w("缺的按市价买齐 %s。", "The rest bought at market, %s.") % Pal.money(buy)
			return {"text": w("修%s：飞到它的业务终端按 %s，点“修”。%s", "Mend the %s: %s at its business console, then MEND. %s") % [nm, Keys.label("use"), tail], "go": "guide:build:" + zone}
		return {"text": w("修%s：%s。先拆船攒钱，或者卖掉仓库里的东西。", "Mend the %s: %s. Strip hulks or sell from the stores first.") % [nm, why], "go": "guide:build:" + zone}
	var node := Route.port_node(zone)
	if node.get("ready", false):
		return {"text": w("去修%s（%s期）：都够了。", "Mend the %s (part %s): all there.") % [Port.name_of(zone), Works.cn_num(Port.stage(zone) + 1) if Txt.zh else str(Port.stage(zone) + 1)], "go": "guide:build:" + zone}
	return {"text": w("修%s（%s期）还需要：%s。", "To mend the %s (part %s) you still need: %s.") % [Port.name_of(zone), Works.cn_num(Port.stage(zone) + 1) if Txt.zh else str(Port.stage(zone) + 1), Route.missing(node)], "go": "guide:build:" + zone}


# Start the ship at the berth, follow its tow, or look for the next one.
static func _next_ship(why: String) -> Dictionary:
	var lead := why + " " if why != "" else ""
	if not Scan.ON:
		return {"title": w("找下一艘船", "FIND THE NEXT SHIP"), "text": lead + w("打开终端，查看能接的船。", "Open the terminal to see available ships."), "go": "contracts"}
	for a in ShipMarket.data().assets if Career.data.has("ship_market") else []:
		if str(a.state) in ["arrived", "berth", "held"]:
			return {"title": w("船已到港", "SHIP IN PORT"), "text": lead + w("按 %s 打开终端，在“找船”里开工。", "Press %s to open the terminal and start under Find Ships.") % Keys.label("terminal"), "go": "contracts"}
	var towing := ShipMarket.on_the_way()
	if not towing.is_empty():
		return {"title": w("拖船在路上", "TOW IN PROGRESS"), "text": lead + w("预计 %d 秒后到港。", "The ship arrives in about %d s.") % int(ceil(float(towing[0].left_s))), "go": "wait"}
	if not Scan.found().is_empty():
		return {"title": w("星图上有船", "SHIP FOUND"), "text": lead + w("打开星图，查看船况和拖运条件。", "Open the star map to check the ship and its tow requirements."), "go": "scan"}
	return {"title": w("找下一艘船", "FIND THE NEXT SHIP"), "text": lead + w("去星图扫描，或到二手船市挑一艘。", "Sweep the star map or pick a ship on the used market."), "go": "scan"}


# 第 3 段: no chapter's need is up — strip another hulk (the next chapter starts on its own)
static func waiting_step() -> Dictionary:
	if next_open() == "":
		return {}
	if Works.busy():
		var st := step()
		st.title = w("施工进度", "WORKS PROGRESS")
		return st
	if StoreBook.blocks_next_job():
		return {"title": w("处理待入库货物", "HANDLE WAITING GOODS"), "text": w("腾出位置入库，或卖给回收站回款，再接下一艘。", "Make room in the stores or sell the goods to the recycler before taking another ship."), "go": "store"}
	return _next_ship("")


# the next step of the chapter: {text, go}
static func step(id: String = "") -> Dictionary:
	if id == "":
		id = chapter()
	var d := Career.data
	# 65 号: while the crew builds, that is the step
	if Works.busy():
		var wj := Works.current()
		# user 2026-10-27 ("施工队施工好久啊，到底怎么回事"): the crew stops for the drone in the lift
		# zone — said here, where the player looks, not only on the sign at the site
		if Works.held == "lockout":
			return {"text": w("施工暂停：无人机在吊装区（%d m 内）。飞远些就接着干（还要约 %d 秒）。", "WORK STOPPED: THE DRONE IS IN THE LIFT ZONE (%d m). MOVE AWAY (~%d s LEFT).") % [int(Works.LOCKOUT_M), int(ceil(float(wj.get("left", 0.0))))], "go": "wait"}
		if WorksPlan.at(wj)[0] >= 0:
			# 82 号: which step the crew is on, and that it can be watched
			return {"text": w("%s施工中 · %s · 剩余 %d 秒", "%s UNDER WORKS · %s · %d s LEFT") % [Works.name_of(wj), WorksPlan.line(wj), int(ceil(float(wj.get("left", 0.0))))], "go": "wait"}
		return {"text": w("%s施工中 · 剩余 %d 秒", "%s UNDER WORKS · %d s LEFT") % [Works.name_of(Works.current()), int(ceil(float(Works.current().get("left", 0.0))))], "go": "wait"}
	# 80 号: a new career's first half hour says its own next step
	Onboard.finish_if_done()
	var ob := Onboard.step()
	if not ob.is_empty():
		return ob
	match id:
		"opening":
			var a: Dictionary = Career.active()
			if not a.is_empty():
				return {"text": w("开始拆 %s：%s 开终端，在“找船”里开工。", "Start on %s: %s, pick it under Find Ships.") % [str(a.get("id", "")), Keys.label("terminal")], "go": "contracts"}
			var sj: Dictionary = Career.story_job()
			return {"text": w("%s 开终端，在“找船”里接 %s。", "%s: take %s under Find Ships.") % [Keys.label("terminal"), str(sj.get("id", ""))], "go": "contracts"}
		"lights":
			var ls := _repair_step("lights")
			if Repair.found("lights"):
				ls.text = w("照明坏了：看不清读数、切得慢。", "The lights are out: poor readings, slow cutting. ") + str(ls.text)
			return ls
		"furnace": return _repair_step("furnace_main" if not d.get("upgrades", {}).has("furnace_main") else "net_fix")
		"trade": return _build_step("trade")
		"process":
			if Port.stage("process") < 1:
				return _build_step("process")
			if Drill.open():
				var ds := Drill.step()
				return {"text": str(ds.text), "go": "drill" if str(ds.go) == "drill" else str(ds.go)}
			var t := Guide.first_for_clients()
			# 128 号: the exchange shut, the billets wait in the warehouse (F3 sells them to the recycler)
			if t == "store":
				return {"text": w("钢坯已入库：按 F3 打开仓库，可以卖给回收站或留着。", "Billets in store: F3 opens the warehouse — sell to the recycler or keep."), "go": ""}
			var txt := {"clients": w("有钢坯了：去交易行挂价卖。", "Billets in stock: list them on the exchange."),
				"heat": w("去加工区炉台，把钢锭炼成钢坯。", "To the furnace desk: melt the ingots into billets."),
				"assay": w("去加工区化验台，测废铁杂质。", "To the assay bench: test the scrap."),
				"sort": w("去加工区分选台，把混合金属分开。", "To the sorting desk: separate the mixed metal."),
				"buy_feed": w("仓库没有钢锭：再拆一艘船，碎料会炼成钢锭。", "No ingots: strip another ship; its scrap becomes ingots.")}
			# 64 号: no more buying feed — the ingots come from the next ship
			if t == "buy_feed" and Career.INGOTS:
				return _next_ship(str(txt.buy_feed))
			return {"text": str(txt.get(t, "")), "go": "guide:" + t}
		"cargo": return _build_step("cargo")
		"power": return _build_step("power")
		"tug": return _build_step("tug")
		"berth88": return _repair_step("berth88")
		"ring": return _build_step("ring")
		"ark": return {"text": w("远航者工程还没做好，以后的版本开放。", "The Ark project comes in a later version."), "go": "wait"}
	return {"text": "", "go": "wait"}


# Liang's line when a chapter begins (the author's; empty says nothing)
static func announce(radio) -> void:
	var id := chapter()
	if id == "":
		return
	var seen: Dictionary = Career.data.get("main_seen", {})
	if seen.has(id):
		return
	var prev := CHAPTERS.find(id) - 1
	if prev >= 0:
		Copy.say(radio, "L_main_%s_done" % CHAPTERS[prev])
	Copy.say(radio, "L_main_%s_start" % id)
	seen[id] = true
	Career.data.main_seen = seen
	Career.save()


# "take me": what the step's go does, in the berth (game) or at the terminal
# a card on the find-ships page to act on (a hulk home, a found one, a job in hand)
static func _cards_waiting() -> bool:
	if not Career.active().is_empty() or not Career.story_job().is_empty():
		return true
	for a in Career.data.get("ship_market", {}).get("assets", []):
		if str(a.get("state", "")) in ["arrived", "berth", "held"]:
			return true
	return not Career.data.get("offers", []).is_empty()


static func take_me(game, go: String) -> void:
	if game == null:
		return
	if go == "drill":
		var r := Drill.grant()
		if r.ok:
			go = str(Drill.step().go)
	if go.begins_with("guide:") and game.get("guide") != null:
		var parts := go.split(":")
		game.guide.begin(parts[1], parts[2] if parts.size() > 2 else "")
		if parts[1] in ["clients", "buy_feed"]:
			game.open_exchange.call_deferred("clients" if parts[1] == "clients" else "feed")
	elif go == "scan" or (go == "contracts" and Scan.ON and not _cards_waiting()):
		# user 2026-10-26: "船市里面没有东西，直接跑到星图扫描里面"
		game.open_star_map("find")
	elif go == "store":
		game.open_store()
	elif go == "contracts":
		game.open_console("terminal")
		if game.console_ui != null:
			game.console_ui._skip_boot()
			game.console_ui.set_tab(0)
