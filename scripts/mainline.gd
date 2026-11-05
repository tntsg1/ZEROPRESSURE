class_name Mainline
# The main line (design/…/28_新手教程引导与主线, Q16–Q21; player 2026-10-24: "there should be
# a guide to the next main-line task, so the player knows where to go"). Fixed chapters; inside
# each, the next step is worked out from the real state. A step says what to do and where it
# leads (`go`): "guide:<task>[:<target>]" starts the on-site guide, "contracts" opens the
# contracts, "wait" only shows progress. Chapter names and step lines are interface text;
# Liang's words at a chapter's start and end are the author's (L_main_<id>_start / _done).

# 123 号 (user 2026-11-04 "先修拖船站"): the tug station before the 88 m berth — the rented tug tows
# 44 m at most (72 号), so a bigger berth before it would wait for ships it cannot get
const CHAPTERS := ["opening", "lights", "furnace", "trade", "steel", "industry", "power_tug", "berth88", "ring", "ark"]
const NAMES := {
	"opening": ["把开局那三艘漂流船拆掉", "STRIP THE THREE DRIFTING HULKS YOU STARTED WITH"],
	"lights": ["修好船坞的照明", "GET THE BERTH'S LIGHTS WORKING"],
	"furnace": ["修好熔炉和接碎料的网", "MEND THE FURNACE AND THE DEBRIS NET"],
	"trade": ["修复贸易区，恢复交易", "REOPEN THE TRADE DISTRICT AND START SELLING"],
	"steel": ["第一次炼出钢坯", "MAKE STEEL BILLETS FOR THE FIRST TIME"],
	"industry": ["修好货运区", "MEND THE CARGO DISTRICT"],
	"berth88": ["把船坞扩到 88 米，能拆更大的船", "EXTEND THE BERTH TO 88 m FOR BIGGER SHIPS"],
	"power_tug": ["修好动力区和拖船站", "MEND THE POWER DISTRICT AND THE TUG STATION"],
	"ring": ["让中央转运环重新转起来", "GET THE TRANSFER RING TURNING AGAIN"],
	"ark": ["远航者", "THE ARK"],
}

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
		"opening": return d.get("market", false)
		"lights": return up.has("lights")
		"furnace": return up.has("furnace_main") and up.has("net_fix")
		"trade": return Port.stage("trade") >= 1
		"steel": return _billet_made()
		"industry": return Port.stage("process") >= 1 and Port.stage("cargo") >= 1
		"berth88": return up.has("berth88")
		"power_tug": return Port.stage("power") >= 1 and Port.stage("tug") >= 1
		"ring": return Port.stage("ring") >= 2
	return false


# the chapter the career is in: the first not done
static func chapter() -> String:
	for id in CHAPTERS:
		if not done(id):
			return id
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
	var node := Route.port_node(zone)
	if node.get("ready", false):
		return {"text": w("去修%s（%s期）：都够了。", "Mend the %s (part %s): all there.") % [Port.name_of(zone), Works.cn_num(Port.stage(zone) + 1) if Txt.zh else str(Port.stage(zone) + 1)], "go": "guide:build:" + zone}
	return {"text": w("修%s（%s期）还需要：%s。", "To mend the %s (part %s) you still need: %s.") % [Port.name_of(zone), Works.cn_num(Port.stage(zone) + 1) if Txt.zh else str(Port.stage(zone) + 1), Route.missing(node)], "go": "guide:build:" + zone}


# 68 号: "strip another ship" — start the one at the berth, or the tug on its way, or sweep the belt
static func _next_ship(why: String) -> Dictionary:
	if not Scan.ON:
		return {"text": why, "go": "contracts"}
	for a in ShipMarket.data().assets if Career.data.has("ship_market") else []:
		if str(a.state) == "arrived" or str(a.state) == "berth":
			return {"text": why + w(" 船到港了：%s 开终端，在“找船”里开工。", " A hulk is home: %s, start it under Find Ships.") % Keys.label("terminal"), "go": "contracts"}
	if not ShipMarket.on_the_way().is_empty():
		return {"text": why + w(" 拖船在路上，约 %d 秒到港。", " The tug is on its way: about %d s.") % int(float(ShipMarket.on_the_way()[0].left_s)), "go": "wait"}
	if not Scan.found().is_empty():
		return {"text": why + w(" 已找到船：%s 开星图，派拖船。", " A hulk is found: %s, send the tug.") % Keys.label("starmap"), "go": "scan"}
	return {"text": why + w(" %s 开星图，扫描找船。", " %s: sweep for hulks.") % Keys.label("starmap"), "go": "scan"}


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
		"steel":
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
		"industry": return _build_step("process" if Port.stage("process") < 1 else "cargo")
		"berth88": return _repair_step("berth88")
		"power_tug": return _build_step("power" if Port.stage("power") < 1 else "tug")
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
	elif go == "contracts":
		game.open_console("terminal")
		if game.console_ui != null:
			game.console_ui._skip_boot()
			game.console_ui.set_tab(0)
