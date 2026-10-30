class_name Methods
# 104 号 (user 2026-10-28): growth is new ways to strip a ship, not bigger numbers. Nine
# dismantling methods, each a real tool and what it lets you do. A method is learned by the
# borrow job that lends its tool (taken from the methods page, never expiring), or by its
# achievement on any ship; the two berth facilities (the hauler, the gantry crane) are learned
# when the crew has built them. Learned, its tiers are bought with money; the old skill
# volumes' numbers live on as those tiers (the rest are gone: the drone's base is fixed).
# Career.data.methods: id -> tier bought (1..3). A career from before keeps what it owns.

const ORDER := ["section", "pump", "field", "auto", "probe", "crane", "prop", "cutter", "precise"]
# settled contracts before each one's borrow job opens: the opening three, then every 2–3
const OPEN_AT := [3, 5, 8, 10, 13, 15, 18, 20, 23]
const FIELD_N := 100              # scrap pieces into the furnace on one job: the field grapple's achievement
const FIELD_MIN_T := 0.5          # t: lighter than this the debris net takes it by itself; not counted
const PRECISE_V := 500000.0       # equipment delivered whole, all jobs together: precision inspection's
const WINCH_K := [1.0, 1.0, 1.5, 2.0]
const PROP_T := [60.0, 60.0, 90.0, 120.0]
const CRANE_T := [12.0, 12.0, 16.0]

# name, what it lets you do (one line), how it is learned, the tool it lends or the facility,
# its achievement, the tiers [price, points]; tier 1 comes with learning it
const SPEC := {
	"section": {"name": ["整段拖走", "WHOLE SECTIONS"],
		"does": ["在一整段船体上打牵引锚，切断连接后绞盘把整段拖进熔炉", "Shoot an anchor into a whole section; cut it free and the winch hauls it into the furnace"],
		"learn": "order", "order": "rigging", "gear": "anchor", "feat": "section",
		"tiers": [[0.0, [["1 根牵引锚", "One towing anchor"]]],
			[24000.0, [["第二根牵引锚：两段同时拖", "A second anchor: two sections at once"], ["绞盘 1.5 倍快", "Winch 1.5× faster"]]],
			[90000.0, [["绞盘 2 倍快", "Winch 2× faster"]]]]},
	"pump": {"name": ["不接口抽气液", "PUMP WITHOUT A PORT"],
		"does": ["独立泵直接贴在带压舱壁或罐上抽，不用找接口", "Stick a pump straight on a pressurised wall or tank; no port needed"],
		"learn": "borrow", "ships": ["gr7"], "seed": 930001, "traps": ["wrong_valve"], "lend": {"pump": 1}, "gear": "pump", "feat": "pressure",
		"tiers": [[0.0, [["1 台独立泵", "One independent pump"]]],
			[22000.0, [["分罐：氧罐、氢罐各装一瓶带回，不混成一批", "Bottled apart: each single-gas tank comes home on its own"], ["泵速 2 倍", "Pumps 2×"], ["接管距离 5.5 m", "Hose reach 5.5 m"]]],
			[81000.0, [["泵速 2.8 倍", "Pumps 2.8×"], ["接管距离 7 m", "Hose reach 7 m"]]]]},
	"field": {"name": ["范围抓钩", "FIELD GRAPPLE"],
		"does": ["按 X 一次吸起一片铁碎料，各自保持质量和碰撞", "X catches a patch of iron scrap at once, each piece keeping its mass and collisions"],
		"learn": "borrow", "ships": ["m14", "tw64", "gr7"], "seed": 940001, "kit": {"skill_grapple_multi": 1}, "feat": "field",
		"tiers": [[0.0, [["一次 4 件，半径 2.5 m", "4 pieces, 2.5 m radius"]]],
			[70000.0, [["按材质挑着抓：X 切换全部 / 只抓钢 / 只抓设备", "Pick by material: X steps all / steel / machines"], ["一次 7 件，半径 3.5 m", "7 pieces, 3.5 m radius"], ["单抓 5 t，更稳", "Single grab 5 t, steadier"]]],
			[360000.0, [["一次 11 件，半径 4.5 m", "11 pieces, 4.5 m radius"], ["单抓 6.5 t，最稳", "Single grab 6.5 t, steadiest"]]]]},
	"auto": {"name": ["自动送口", "MACHINES FEED THE MOUTHS"],
		"does": ["标记一下，搬运无人机或机械臂自己把件送进接收口", "Mark a piece and a hauling drone or the arm takes it to its mouth"],
		"learn": "build", "builds": ["hauler", "hauler2", "arm"],
		"tiers": [[0.0, [["1 台搬运无人机，1.5 t 以内", "A hauling drone, up to 1.5 t"]]],
			[0.0, [["第二台搬运无人机", "A second hauling drone"], ["一扳手同时拧 2 颗", "One wrench pass takes 2 fixings"]]],
			[0.0, [["机械臂自动喂熔炉", "The arm feeds the furnace"], ["一扳手同时拧 3 颗", "One wrench pass takes 3 fixings"]]]]},
	"probe": {"name": ["长时监测", "LEFT-ON PROBES"],
		"does": ["探针留在测点上一直读数，数值一变就用无线电报", "A probe left on a test point keeps reading and calls out any real change"],
		"learn": "borrow", "ships": ["fr26", "cl104", "ic120"], "seed": 950001, "lend": {"probe": 2}, "gear": "probe", "feat": "watch",
		"tiers": [[0.0, [["1 根探针", "One probe"]]],
			[39000.0, [["越线停切：读数一变，正在切的激光自动停下", "Stops the beam: a reading changes, the cut halts"], ["远程读数 8 m", "Remote reading 8 m"]]],
			[120000.0, [["远程读数 10 m", "Remote reading 10 m"]]]]},
	"crane": {"name": ["整件吊走", "LIFT IT WHOLE"],
		"does": ["门式吊车把大件整件吊进接收口，不用切小", "The gantry crane lifts big pieces whole into their mouth; no cutting them small"],
		"learn": "build", "builds": ["crane"],
		"tiers": [[0.0, [["12 t 以内整件吊走", "Whole pieces up to 12 t"]]],
			[120000.0, [["吊重 16 t", "Lifts 16 t"]]]]},
	"prop": {"name": ["撑住先抢里侧", "PROP IT, EMPTY THE INSIDE"],
		"does": ["撑杆立在船坞地面顶住结构，先卸里面值钱的", "A prop stood on the berth floor holds the structure while the inside is emptied first"],
		"learn": "borrow", "ships": ["cf90"], "seed": 960001, "lend": {"prop": 2}, "gear": "prop", "feat": "propped",
		"tiers": [[0.0, [["撑杆额定 60 t", "Props rated 60 t"]]],
			[30000.0, [["额定 90 t", "Rated 90 t"], ["超载 3 秒才折", "3 s overloaded before it buckles"]]],
			[90000.0, [["额定 120 t", "Rated 120 t"]]]]},
	"cutter": {"name": ["按方案自动切", "THE CUTTER FOLLOWS YOUR PLAN"],
		"does": ["同型号的船，切割机照你上次的切法自动切", "On a ship of a type you have stripped, the cutter works your last plan"],
		"learn": "borrow", "ships": [], "seed": 970001, "kit": {"cutter": 1}, "feat": "replay",
		"tiers": [[0.0, [["切割机照上次的方案切", "The cutter works your last plan"]]],
			[75000.0, [["方案能改：回放时 Shift+方案键跳过一刀，自己补的刀记进下次方案", "Edit the plan: Shift + the plan key skips a cut; cuts you add go into the next plan"], ["切割 1.25 倍快", "Cuts 1.25× faster"], ["切口更细", "Finer kerf"]]],
			[300000.0, [["切割 1.6 倍快", "Cuts 1.6× faster"]]]]},
	"precise": {"name": ["精密检测", "PRECISION INSPECTION"],
		"does": ["查裂纹和设备完好度，看懂高价值船再决定怎么下刀", "Find cracks and equipment condition: read a valuable ship before you cut"],
		"learn": "borrow", "ships": ["ob90", "dc84", "ev55", "qc30"], "seed": 980001, "kit": {"skill_meter_speed": 1}, "feat": "precise",
		"tiers": [[0.0, [["查裂纹和设备完好度", "Cracks and equipment condition"]]],
			[69000.0, [["剩余寿命：测设备时显示还能用几年、修缮用不用得上", "Service life: a machine's reading says the years it has left, and if a repair can use it"], ["检测更快", "Faster probing"], ["读数距离 10 m", "Reading reach 10 m"]]],
			[390000.0, [["检测最快", "Fastest probing"], ["读数距离 12 m", "Reading reach 12 m"]]]]},
}
# 108 号 Q14/Q6 (the outside review: a method learned should get a job that shows what it is for):
# once a method is learned, the ship market lists one ship laid out for it, marked "试试新拆法";
# taking it is the player's choice. The ship each one is shown on (the cutter: a type already
# stripped, so its plan exists); the borrow job's own arrangement (seed, traps) where it has one
const SHOWCASE := {"section": "gr7", "pump": "gr7", "field": "m14", "auto": "tw64", "probe": "fr26",
	"crane": "m14", "prop": "cf90", "cutter": "", "precise": "ob90"}


static func showcase_ship(id: String) -> String:
	if id == "cutter":
		var plans: Dictionary = Career.data.get("plans", {})
		for h in Career.data.get("history", []).duplicate():
			if plans.has(str(h.get("ship", ""))):
				return str(h.ship)
		return ""
	return str(SHOWCASE.get(id, ""))


# the next learned method whose showcase has not been listed yet ("" = none)
static func showcase_due() -> String:
	if Career.data.is_empty():
		return ""
	var done: Dictionary = Career.data.get("showcases", {})
	for id in ORDER:
		if not learned(id) or done.has(id):
			continue
		var ship := showcase_ship(id)
		if ship != "" and Market.fits(ship, Career.data):
			return id
	return ""


# what the job did with the method, in a line, from the settlement report's "uses"
static func use_text(id: String, u: Dictionary) -> String:
	match id:
		"section": return _t(["打了 %d 根牵引锚", "%d anchors set"]) % int(u.get("anchor", 0))
		"pump": return _t(["贴了 %d 台独立泵", "%d pumps set"]) % int(u.get("pump", 0))
		"field": return _t(["%d 块碎料送进熔炉", "%d loads into the furnace"]) % int(u.get("furnace", 0))
		"auto": return _t(["机器送口 %d 趟", "%d loads by machine"]) % int(u.get("arm", 0))
		"probe": return _t(["留了 %d 根探针", "%d probes left on"]) % int(u.get("probe", 0))
		"crane": return _t(["吊车整件吊走 %d 件", "%d pieces lifted whole"]) % int(u.get("crane", 0))
		"prop": return _t(["立了 %d 根撑杆", "%d props set"]) % int(u.get("prop", 0))
		"cutter": return _t(["切割机照方案做了 %d 步", "%d plan steps by machine"]) % int(u.get("plan", 0))
		"precise": return _t(["整件交付设备 %s", "%s of machines delivered whole"]) % Pal.money(float(u.get("equip_v", 0.0)))
	return ""


# 108 号 Q15: tiers that bring a tool of their own (id -> {tier: gear type})
const TIER_GEAR := {"section": {2: "anchor"}}
# the old skill volumes each tier stands for (Growth.TRACKS levels; scripts/growth.gd reads them)
const KIT := {
	"pump": [{}, {}, {"skill_pump_rate": 1, "skill_hose_range": 1}, {"skill_pump_rate": 2, "skill_hose_range": 2}],
	"field": [{}, {"skill_grapple_multi": 1}, {"skill_grapple_multi": 2, "skill_grapple_mass": 1, "skill_grapple_stable": 1},
		{"skill_grapple_multi": 3, "skill_grapple_mass": 2, "skill_grapple_stable": 2}],
	"auto": [{}, {}, {"skill_wrench_multi": 1}, {"skill_wrench_multi": 2}],
	"probe": [{}, {}, {"skill_meter_range": 1}, {"skill_meter_range": 2}],
	"cutter": [{}, {"cutter": 1}, {"cutter": 1, "skill_laser_power": 1, "skill_laser_kerf": 1}, {"cutter": 1, "skill_laser_power": 2, "skill_laser_kerf": 1}],
	"precise": [{}, {"skill_meter_speed": 1, "scan_kit": 1}, {"skill_meter_speed": 2, "skill_meter_range": 2, "scan_kit": 1},
		{"skill_meter_speed": 3, "skill_meter_range": 3, "scan_kit": 1}],
}


static func _t(pair: Array) -> String:
	return str(pair[0]) if Txt.zh else str(pair[1])


static func name_of(id: String) -> String:
	return _t(SPEC[id].name) if SPEC.has(id) else id


static func does(id: String) -> String:
	return _t(SPEC[id].does) if SPEC.has(id) else ""


static func tiers(id: String) -> int:
	return SPEC[id].tiers.size() if SPEC.has(id) else 0


static func points(id: String, tier: int) -> Array:
	var out: Array = []
	if not SPEC.has(id) or tier < 1 or tier > tiers(id):
		return out
	for p in SPEC[id].tiers[tier - 1][1]:
		out.append(_t(p))
	return out


static func _built(id: String) -> bool:
	return not Career.data.is_empty() and Career.data.get("upgrades", {}).has(id)


# the tier the career has: 0 = not learned. A facility method is the facilities built.
static func level(id: String) -> int:
	if Career.data.is_empty() or not SPEC.has(id):
		return 0
	var s: Dictionary = SPEC[id]
	var bought := int(Career.data.get("methods", {}).get(id, 0))
	if s.learn == "build":
		var b: Array = s.builds
		if not _built(str(b[0])):
			return 0
		if id == "auto":
			var n := 1
			for k in b.slice(1):
				if _built(str(k)):
					n += 1
			return n
		return clampi(maxi(1, bought), 1, tiers(id))
	return clampi(bought, 0, tiers(id))


static func learned(id: String) -> bool:
	return level(id) >= 1


# the next one to learn, in the agreed order ("" once all are)
static func next_id() -> String:
	for id in ORDER:
		if not learned(id):
			return id
	return ""


# settled contracts still to go before its borrow job opens (0 = open)
static func wait(id: String) -> int:
	var i := ORDER.find(id)
	if i < 0 or Career.data.is_empty():
		return 0
	return maxi(0, int(OPEN_AT[i]) - int(Career.data.get("done", 0)))


# the ship its borrow job comes on: the first of its ships that fits the berth (for the cutter,
# a type the career has a plan for); "" when none does yet
static func ship_for(id: String) -> String:
	var ships: Array = SPEC[id].get("ships", [])
	if id == "cutter":
		ships = Career.data.get("plans", {}).keys()
	for s in ships:
		if Market.fits(str(s), Career.data):
			return str(s)
	return ""


static func ship_label(ship: String) -> String:
	if ship == "":
		return "—"
	return str(Ship.load_data(ship).get("name", ship.to_upper())).split(" ")[0]


# the berth length its borrow job's first ship needs (m; 0 when one fits)
static func berth_needed(id: String) -> float:
	if ship_for(id) != "":
		return 0.0
	var ships: Array = SPEC[id].get("ships", [])
	if ships.is_empty():
		return 0.0
	return float(Market.type_of(str(ships[0])).get("length", 0.0)) + 6.0


# why its borrow job cannot be taken now ("" when it can)
static func borrow_reason(id: String) -> String:
	if not SPEC.has(id):
		return Txt.t("rp_unknown")
	var s: Dictionary = SPEC[id]
	if learned(id):
		return _t(["已学会", "LEARNED"])
	if s.learn == "build":
		return _t(["让施工队修建：%s", "HAVE THE CREW BUILD: %s"]) % Txt.t(Repair.find(str(s.builds[0]))[4])
	if wait(id) > 0:
		return _t(["再完成 %d 单开放", "OPENS AFTER %d MORE JOBS"]) % wait(id)
	if not Career.active().is_empty():
		return Txt.t("trial_busy")
	if s.learn == "order":
		return load("res://scripts/work_orders.gd").reason(str(s.order))
	if id == "cutter" and Career.data.get("plans", {}).is_empty():
		return _t(["先完整拆完一艘船，留下方案", "STRIP A SHIP FIRST TO LEAVE A PLAN"])
	if ship_for(id) == "":
		return _t(["船坞要扩到 %d m", "NEEDS A %d m BERTH"]) % int(berth_needed(id))
	return ""


# its borrow job: a fixed job on its ship, the tool lent (or its skill fitted for the job), no fee:
# the maker lends the tool and pays the tow to see it used
static func borrow_offer(id: String) -> Dictionary:
	var s: Dictionary = SPEC.get(id, {})
	if s.get("learn", "") != "borrow":
		return {}
	var ship := ship_for(id)
	if ship == "":
		return {}
	var o: Dictionary = Career.fixed_offer(ship, int(s.seed), s.get("traps", null))
	if o.is_empty():
		return {}
	o.fee = 0.0
	o.owner = "salvage"
	o.id = "BR-%s-%03d" % [id.to_upper(), int(Career.data.get("borrows", {}).get(id, 0)) + 1]
	o.borrow = id
	o.lend = s.get("lend", {}).duplicate()
	o.kit_lend = s.get("kit", {}).duplicate()
	return o


static func take(id: String) -> String:
	var why := borrow_reason(id)
	if why != "":
		return why
	var s: Dictionary = SPEC[id]
	if s.learn == "order":
		return load("res://scripts/work_orders.gd").take(str(s.order))
	var before := Career.data
	Career.data = before.duplicate(true)
	var b: Dictionary = Career.data.get("borrows", {})
	b[id] = int(b.get(id, 0)) + 1
	Career.data.borrows = b
	if Career.take_fixed(borrow_offer(id)).is_empty():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# the next tier's price, or why it cannot be bought ("" when it can)
static func price(id: String) -> float:
	var n := level(id)
	return float(SPEC[id].tiers[n][0]) if SPEC.has(id) and n >= 1 and n < tiers(id) else 0.0


static func buy_reason(id: String) -> String:
	if not learned(id):
		return _t(["还没学会", "NOT LEARNED YET"])
	if level(id) >= tiers(id):
		return _t(["已到最高档", "TOP TIER"])
	if id == "auto":
		return _t(["让施工队修建：%s", "HAVE THE CREW BUILD: %s"]) % Txt.t(Repair.find(str(SPEC.auto.builds[level(id)]))[4])
	if float(Career.data.get("money", 0.0)) < price(id):
		return Txt.t("tm_short") % Pal.money(price(id) - float(Career.data.money))
	return ""


static func buy(id: String) -> String:
	var why := buy_reason(id)
	if why != "":
		return why
	var before := Career.data
	Career.data = before.duplicate(true)
	Career.data.money = float(Career.data.money) - price(id)
	var m: Dictionary = Career.data.get("methods", {})
	m[id] = level(id) + 1
	Career.data.methods = m
	# 108 号 Q15: a tier that is a tool, not a number, puts the tool on the shelf
	var tool: String = TIER_GEAR.get(id, {}).get(int(m[id]), "")
	if tool != "":
		var gw: Dictionary = Career.data.get("gear", {})
		gw[tool] = int(gw.get(tool, 0)) + 1
		Career.data.gear = gw
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# learn it (tier 1); its tool's first unit goes on the shelf unless it came with the feat already
static func learn(id: String, grant: bool) -> bool:
	if not SPEC.has(id) or learned(id) or SPEC[id].learn == "build":
		return false
	var m: Dictionary = Career.data.get("methods", {})
	m[id] = 1
	Career.data.methods = m
	var g: String = SPEC[id].get("gear", "")
	if grant and g != "":
		var w: Dictionary = Career.data.get("gear", {})
		w[g] = int(w.get(g, 0)) + 1
		Career.data.gear = w
	return true


# at settlement (inside Career.settle's transaction): a borrow job passed, the rigging order
# done, or an achievement teaches its method; returns the ids learned
static func settle(a: Dictionary, r: Dictionary, grade: int, feats_new: Array, order: Dictionary) -> Array:
	var out: Array = []
	var bid := str(a.get("borrow", ""))
	if bid != "" and grade >= 1:
		if learn(bid, true):
			out.append(bid)
	if order.get("completed", false) and str(order.get("id", "")) == "rigging" and learn("section", false):
		out.append("section")
	# the achievements read at settlement: a clean job on a cold ship (every hull is pressurised, so
	# that alone would teach it on the first Heron); a type stripped a second time on jobs of your
	# own (the opening, the orders, the trials and the borrow jobs don't count); equipment
	# delivered whole, all jobs together
	var feats: Dictionary = Career.data.get("feats", {})
	var gr: Dictionary = r.get("gear", {})
	var stats: Dictionary = Career.data.get("method_stats", {})
	stats.equip_v = float(stats.get("equip_v", 0.0)) + float(gr.get("equip_v", 0.0))
	Career.data.method_stats = stats
	var add := func(f: String) -> void:
		if not feats.has(f) and not feats_new.has(f):
			feats[f] = {"ship": a.get("ship", ""), "job": a.get("id", ""), "at": int(Career.data.get("done", 0)), "measure": 0.0}
			feats_new.append(f)
	if grade >= 2 and r.get("incidents", []).is_empty() and a.get("scope", "full") == "full" and _cold(str(a.get("ship", ""))):
		add.call("watch")
	var own: bool = not (a.has("borrow") or a.has("work_order") or a.has("trial") or Career.opening_index(a) >= 0)
	if own and str(a.get("ship", "")) != "":
		var strips: Dictionary = stats.get("strips", {})
		strips[str(a.ship)] = int(strips.get(str(a.ship), 0)) + 1
		stats.strips = strips
		if int(strips[str(a.ship)]) >= 2:
			add.call("replay")
	if float(stats.equip_v) >= PRECISE_V:
		add.call("precise")
	Career.data.feats = feats
	for f in feats_new:
		for id in ORDER:
			if str(SPEC[id].get("feat", "")) == str(f) and learn(id, not Gear.FEAT_GRANT.has(str(f))):
				out.append(id)
	return out


static func _cold(ship: String) -> bool:
	return ship != "" and _pressurised_d(Ship.load_data(ship), true)


# a career from before 104 号: what it owns is learned (user Q5 A)
static func migrate() -> void:
	var d := Career.data
	var m: Dictionary = d.get("methods", {})
	var gear: Dictionary = d.get("gear", {})
	var feats: Dictionary = d.get("feats", {})
	var ups: Dictionary = d.get("upgrades", {})
	var orders: Dictionary = d.get("work_orders", {})
	if int(gear.get("anchor", 0)) > 0 or feats.has("section") or orders.get("done", {}).has("rigging"):
		m.section = maxi(1, int(m.get("section", 0)))
	if int(gear.get("pump", 0)) > 0 or feats.has("pressure") or ups.has("pump2"):
		m.pump = maxi(2 if ups.has("pump2") else 1, int(m.get("pump", 0)))
	if int(gear.get("probe", 0)) > 0:
		m.probe = maxi(1, int(m.get("probe", 0)))
	if int(gear.get("prop", 0)) > 0:
		m.prop = maxi(1, int(m.get("prop", 0)))
	if ups.has("scan_kit"):
		m.precise = maxi(1, int(m.get("precise", 0)))
	if not d.get("plans", {}).is_empty():
		m.cutter = maxi(1, int(m.get("cutter", 0)))
	d.methods = m
	d.methods_v = 1


# the skill levels the career's methods stand for (merged over a job's kit; scripts/game.gd)
static func kit() -> Dictionary:
	var out := {}
	for id in KIT:
		var n := level(id)
		if n <= 0:
			continue
		var k: Dictionary = KIT[id][clampi(n, 0, KIT[id].size() - 1)]
		for key in k:
			out[key] = maxi(int(out.get(key, 0)), int(k[key]))
	return out


static func winch_k() -> float:
	return WINCH_K[clampi(level("section"), 0, 3)]


static func prop_t() -> float:
	return PROP_T[clampi(level("prop"), 0, 3)]


static func prop_give() -> float:
	return 3.0 if level("prop") >= 2 else Gear.PROP_GIVE


static func crane_t() -> float:
	return CRANE_T[clampi(level("crane"), 0, 2)]


# the method a field tool belongs to ("" for none)
static func of_gear(type: String) -> String:
	for id in ORDER:
		if str(SPEC[id].get("gear", "")) == type:
			return id
	return ""


# 104 号 Q4 C: the methods this ship has a use for (the contract card): a whole section to haul,
# a charged bottle, a lot of scrap, a cold or hot store to watch, a heavy fitting to lift, a
# container wall, a type with a plan of yours, a valuable ship to read
static func useful(g) -> Array:
	var out: Array = []
	if g == null or g.ship.is_empty() or g.world == null:
		return out
	var heavy := false
	var lift := false
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone:
			continue
		if p.mass >= Gear.SECTION_T:
			heavy = true
		if p.cls == "equip" and p.mass > 1.5 and p.mass <= CRANE_T[2]:
			lift = true
	if heavy:
		out.append("section")
	if _pressurised_d(g.ship, false):
		out.append("pump")
	if g.ship.has("ore") or g.world.order.size() >= 220:
		out.append("field")
	if _pressurised_d(g.ship, true):
		out.append("probe")
	if lift:
		out.append("crane")
	if g.boxbeam != null and g.boxbeam.active():
		out.append("prop")
	if not Career.data.is_empty() and Career.data.get("plans", {}).has(g.ship_id):
		out.append("cutter")
	if float(g.ship.get("value", {}).get("total", 0.0)) >= PRECISE_V:
		out.append("precise")
	return out


static func useful_text(g) -> String:
	if Career.data.is_empty() or not g.career():
		return ""
	var parts: Array = []
	for id in useful(g):
		parts.append(("✓ " if learned(id) else "○ ") + name_of(id))
	if parts.is_empty():
		return ""
	return _t(["用得上的拆法：", "METHODS THIS SHIP CAN USE: "]) + "   ".join(parts)


static func _pressurised_d(d: Dictionary, cold: bool) -> bool:
	if cold:
		return d.has("cold") or d.has("ice") or d.has("cryo") or d.has("boiloff")
	for v in d.get("gas", {}).get("vessels", {}).values():
		if float(v.get("kpa", 0.0)) >= Gear.PRESSURE_KPA:
			return true
	return false
