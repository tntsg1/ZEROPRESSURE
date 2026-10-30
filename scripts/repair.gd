class_name Repair
# The run-down berth (G2, design/成长系统重设计 §13 and DECISIONS「grilling 第二轮定案」):
# BERTH 07 starts half wrecked. Everything the berth could have is on one damage
# list, each item with the parts it takes to put right. Parts are the whole
# pieces of equipment the drone brings to the equipment bay (classed power /
# thermal / drive) and structure by the tonne (what goes through the furnace).
# A repair with parts costs half the listed money; with money alone, the whole of it.
# Career.data keeps: "parts" (the warehouse, [{uid, cls, tag, nk, cond, value, ship, job}]),
# "structure_t" (tonnes on the shelf), "repairs" (the log), "repaired_pending" (to show).
# What is repaired is written into Career.data.upgrades, so every has_upgrade() check
# in the game keeps working as it did when these were bought.

const CLASSES := ["power", "thermal", "drive", "structure"]
const PARTS_SHARE := 0.25          # of the listed price, when the parts are brought (74 号: the crew's wages only)
const PLATE := "steel_plate:1"     # 74 号: rolled plate in the warehouse counts as hull plate
const SECTION := "steel_section:1" # 74 号: rolled sections, for the big frames
const COND_MIN := 0.6              # a part below this must be refurbished first (G2: sold or kept)
const PART_MIN_VALUE := 1500.0     # cheaper equipment is paid out as before, never shelved
# id, prerequisites, what it takes {class: n | "structure": tonnes}, listed price, name key
const ITEMS := [
	["lights", [], {"power": 2}, 14000.0, "rp_lights"],
	["net_fix", [], {"structure": 5.0}, 12000.0, "rp_net_fix"],
	["furnace_main", [], {"thermal": 2}, 24000.0, "rp_furnace"],
	["hauler", ["lights"], {"drive": 2}, 45000.0, "fa_hauler"],
	["port2", ["lights"], {"power": 1, "drive": 1}, 50000.0, "fa_port2"],
	["mouth_rail", ["furnace_main"], {"drive": 1, "structure": 3.0}, 30000.0, "fa_rail"],
	["buffer", [], {"structure": 6.0}, 30000.0, "fa_buffer"],
	["zones", ["lights"], {"drive": 1}, 20000.0, "fa_zones"],
	["net05", ["net_fix"], {"structure": 4.0}, 18000.0, "fa_net"],
	["hauler2", ["hauler"], {"drive": 2}, 60000.0, "fa_hauler2"],
	["arm", ["lights"], {"drive": 2, "power": 1}, 65000.0, "fa_arm"],
	["crane", ["lights", "buffer"], {"drive": 3, "structure": 10.0}, 150000.0, "fa_crane"],
	["berth88", [], {"structure": 25.0, "section": 15.0}, 240000.0, "fa_berth"],
	["berth120", ["berth88"], {"structure": 60.0}, 520000.0, "fa_berth120"],
	["berth200", ["berth120"], {"structure": 120.0}, 1200000.0, "fa_berth200"],
	["berth620", ["berth200"], {"structure": 400.0}, 4500000.0, "fa_berth620"],
	# 76 号: the processing district's gas line and the LOX tank (they also need the districts: see reason)
	["gas_line", [], {"thermal": 2, "structure": 8.0, "section": 6.0}, 80000.0, "fa_gas_line"],
	["lox_tank", ["gas_line"], {"thermal": 1, "structure": 10.0, "section": 4.0}, 60000.0, "fa_lox_tank"],
]
# the three the berth cannot work properly without: new careers start with them broken
const BASE := ["lights", "net_fix", "furnace_main"]
# 86 号: those three are really broken and are found on site (the drone within FIND_M of one);
# everything else on the list is a plan — new equipment or an extension, shown once its
# prerequisites are done
const FAULTS := BASE
const FIND_M := 8.0
# plans with no place in the berth itself (the card does not frame the map; "" = a function)
const NO_PLACE := {"zones": "", "gas_line": "process", "lox_tank": "process"}
# equipment classes by what the piece is (ship files: name_key and hazard)
const POWER_KEYS := ["p_gen", "p_battery", "p_s_bat", "p_cap", "p_s_cap", "p_fuelcell", "p_swb", "p_s_swb", "p_aux", "p_pdu", "p_inverter", "p_reactor", "p_rtg", "p_solar"]
const THERMAL_KEYS := ["p_pump", "p_radiator", "p_s_rad", "p_env", "p_life", "p_heater", "p_chiller", "p_cooler", "p_hx", "p_boiler", "p_compressor", "p_cryo"]
const DRIVE_KEYS := ["p_engt", "p_engf", "p_engc", "p_engn", "p_main", "p_rcs_q", "p_nav", "p_avionics", "p_console", "p_tow_console", "p_armctl", "p_load_mon", "p_cylinder", "p_winch", "p_s_arm", "p_tow_arm", "p_tow_tel", "p_tow_head", "p_dock", "p_att", "p_brake", "p_motor", "p_servo", "p_gyro", "p_actuator", "p_hydraulic"]
const THERMAL_WORDS := ["rad", "pump", "cool", "heat", "chill", "cryo", "boil", "exch", "hvac", "compress", "therm"]
const DRIVE_WORDS := ["eng", "thrust", "motor", "nav", "avionic", "console", "ctl", "cylinder", "hydraul", "winch", "actuat", "servo", "gyro", "dock", "drive", "gear"]


static func find(id: String) -> Array:
	for it in ITEMS:
		if it[0] == id:
			return it
	return []


static func name_of(id: String) -> String:
	var it := find(id)
	return Txt.t(it[4]) if not it.is_empty() else id


static func desc_of(id: String) -> String:
	var it := find(id)
	if it.is_empty():
		return ""
	var k: String = it[4] + "_d"
	return Txt.t(k) if Txt.has(k) else ""


static func class_name_of(cls: String) -> String:
	return Txt.t("rp_cls_" + cls)


# 61 号: what is still needed, in plain words — "从船上拆回 2 件供电设备（…）", "5.0 吨船体钢板"
# 74 号: and where the plate and the sections come from
static func lack_text(cls: String, n: float) -> String:
	if cls == "structure":
		return Ops.w("%.1f 吨%s（拆船时留下整块船壳，或在加工区把钢坯轧成钢板，或去交易行买钢板）", "%.1f t of %s (hull plate kept from a strip, plate rolled from billet, or bought)") % [n, class_name_of(cls)]
	if cls == "section":
		return Ops.w("%.1f 吨%s（在加工区把钢坯轧成型材，或去交易行买）", "%.1f t of %s (rolled from billet in the processing district, or bought)") % [n, class_name_of(cls)]
	return Ops.w("从船上拆回 %d 件%s", "%d pieces of %s from the ships you strip") % [int(n), class_name_of(cls)]


# ---------------------------------------------------------------- what a piece is

# the repair class of a piece of equipment ("" when it is only worth money)
static func class_of(p, sys = null) -> String:
	if p == null or p.cls != "equip" or not p.intact or p.tag == "" or float(p.value) < PART_MIN_VALUE:
		return ""
	var nk: String = str(p.name_key)
	# 87-4: a furled light-sail roll: shelved as cargo of its own, to keep or to sell
	if nk == "p_sail_roll":
		return "sail"
	if p.hazard in ["gen", "battery", "cap"] or nk in POWER_KEYS or (sys != null and sys.src.has(p.tag)):
		return "power"
	if nk in THERMAL_KEYS or (sys != null and sys.heat.get("pieces", {}).has(p.tag)):
		return "thermal"
	if nk in DRIVE_KEYS:
		return "drive"
	for w in THERMAL_WORDS:
		if nk.find(w) >= 0:
			return "thermal"
	for w in DRIVE_WORDS:
		if nk.find(w) >= 0:
			return "drive"
	return ""


# a shelf entry for a piece delivered whole
static func part_of(p, cls: String, ship: String, job: String) -> Dictionary:
	return {"uid": "%s:%s:%d" % [job, p.tag, p.id], "cls": cls, "tag": p.tag, "nk": p.name_key, "cond": snappedf(clampf(float(p.cond), 0.0, 1.0), 0.01),
		"value": float(p.value), "ship": ship, "job": job}


static func part_worth(part: Dictionary) -> float:
	return snappedf(float(part.value) * clampf(float(part.cond), 0.0, 1.0), 1.0)


# ---------------------------------------------------------------- the state of the berth

static func done(id: String) -> bool:
	return Career.data.get("upgrades", {}).has(id)


static func is_fault(id: String) -> bool:
	return id in FAULTS


# a fault seen on site (a plan or a repaired fault always counts as known)
static func found(id: String) -> bool:
	return not is_fault(id) or done(id) or Career.data.get("faults_found", {}).has(id)


# the drone got close to it: true the first time
static func find_fault(id: String) -> bool:
	if found(id) or Career.data.is_empty():
		return false
	var f: Dictionary = Career.data.get("faults_found", {})
	f[id] = true
	Career.data.faults_found = f
	return not is_fault(id) or done(id) or Career.data.get("faults_found", {}).has(id)


# the expansion plans on show: not built, their prerequisites done (86 号 Q10)
static func plans() -> Array:
	var out: Array = []
	for it in ITEMS:
		if not is_fault(it[0]) and not done(it[0]) and deps_ok(it[0]):
			out.append(it[0])
	return out


# what it is for once built, one line (the text after "修好：" when the description has it)
static func use_line(id: String) -> String:
	var d := desc_of(id)
	for mark in ["修好：", "Repaired: "]:
		var at := d.find(mark)
		if at >= 0:
			return d.substr(at + mark.length())
	return d


static func deps_ok(id: String) -> bool:
	for d in find(id)[1]:
		if not done(d):
			return false
	return not is_fault(id) or done(id) or Career.data.get("faults_found", {}).has(id)


# the parts on the shelf that would go into this repair: {class: [parts]}, and the tonnes
static func parts_for(id: String) -> Dictionary:
	var it := find(id)
	if it.is_empty():
		return {"ok": false, "picked": {}, "missing": {}, "tons": 0.0, "tons_missing": 0.0}
	return parts_for_needs(it[2])


# the same for any list of needs (the port's works, G6)
static func parts_for_needs(needs: Dictionary) -> Dictionary:
	var out := {"ok": true, "picked": {}, "missing": {}, "tons": 0.0, "tons_missing": 0.0}
	var shelf: Array = Career.data.get("parts", []).duplicate()
	shelf.sort_custom(func(a, b): return float(a.cond) > float(b.cond))
	out.section = 0.0
	out.section_missing = 0.0
	for cls in needs:
		if cls == "structure":
			var want := float(needs[cls])
			# 74 号: the hull plate kept from strips, then rolled plate on the racks
			var have := float(Career.data.get("structure_t", 0.0)) + _stock_t(PLATE)
			out.tons = minf(want, have)
			if have < want - 0.001:
				out.tons_missing = want - have
				out.ok = false
			continue
		if cls == "section":
			var want_s := float(needs[cls])
			var have_s := _stock_t(SECTION)
			out.section = minf(want_s, have_s)
			if have_s < want_s - 0.001:
				out.section_missing = want_s - have_s
				out.ok = false
			continue
		var picked: Array = []
		for part in shelf:
			if part.cls == cls and float(part.cond) >= COND_MIN and picked.size() < int(needs[cls]):
				picked.append(part)
		out.picked[cls] = picked
		if picked.size() < int(needs[cls]):
			out.missing[cls] = int(needs[cls]) - picked.size()
			out.ok = false
	return out


static func price(id: String, with_parts: bool) -> float:
	var it := find(id)
	if it.is_empty():
		return 0.0
	return float(it[3]) * (PARTS_SHARE if with_parts else 1.0)


# why this repair cannot be made now, by route ("" when it can)
static func reason(id: String, with_parts: bool) -> String:
	var it := find(id)
	if it.is_empty():
		return Txt.t("rp_unknown")
	if done(id):
		return Txt.t("tm_owned")
	for d in it[1]:
		if not done(d):
			return Txt.t("tm_needs") % name_of(d)
	if not Port.power_ok(id):
		return Txt.t("rp_need_power")
	if id == "gas_line" and (Port.stage("process") < 1 or Port.stage("power") < 1):
		return Ops.w("气体线要先修好加工区和动力区（各 1 阶）", "THE GAS LINE NEEDS THE PROCESSING AND POWER DISTRICTS (STAGE 1)")
	if with_parts:
		var pf := parts_for(id)
		if not pf.ok:
			var parts: Array = []
			for cls in pf.missing:
				parts.append("%s ×%d" % [class_name_of(cls), int(pf.missing[cls])])
			if pf.tons_missing > 0.001:
				parts.append(lack_text("structure", pf.tons_missing))
			if float(pf.get("section_missing", 0.0)) > 0.001:
				parts.append(lack_text("section", float(pf.section_missing)))
			return Txt.t("rp_missing") % ", ".join(parts)
	var cost := price(id, with_parts)
	if float(Career.data.get("money", 0.0)) < cost:
		return Txt.t("tm_short") % Pal.money(cost - float(Career.data.money))
	return ""


static func _stock_t(key: String) -> float:
	return float(Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {}).get(key, 0.0))


static func _take_stock(key: String, t: float) -> void:
	if t <= 0.0 or not Career.data.get("exchange", {}).get("actors", {}).has("company"):
		return
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st[key] = maxf(0.0, float(st.get(key, 0.0)) - t)


# take the parts and tonnes a list of needs picks off the shelf (Career.data as it is now)
static func take_needs(needs: Dictionary) -> Array:
	var d := Career.data
	var pf := parts_for_needs(needs)
	var used: Array = []
	var shelf: Array = d.get("parts", [])
	for cls in pf.picked:
		for part in pf.picked[cls]:
			for i in shelf.size():
				if shelf[i].uid == part.uid:
					used.append(shelf[i])
					shelf.remove_at(i)
					break
	d.parts = shelf
	# 74 号: the kept hull plate first, the rolled plate for the rest; the sections off their rack
	var kept := float(d.get("structure_t", 0.0))
	d.structure_t = maxf(0.0, kept - float(pf.tons))
	_take_stock(PLATE, maxf(0.0, float(pf.tons) - kept))
	_take_stock(SECTION, float(pf.get("section", 0.0)))
	return used


# make the repair: the parts (or not) and the money go, the facility is the berth's.
# Nothing changes on a failed write.
static func fix(id: String, with_parts: bool) -> String:
	var why := reason(id, with_parts)
	if why != "":
		return why
	var before := Career.data
	Career.data = before.duplicate(true)
	var d := Career.data
	var used: Array = []
	if with_parts:
		used = take_needs(find(id)[2])
	d.money = float(d.money) - price(id, with_parts)
	if id.begins_with("berth") and not d.has("berth_seen"):
		d["berth_seen"] = Dock.owned(d.get("upgrades", {}))
	d.upgrades[id] = 1
	var log: Array = d.get("repairs", [])
	log.append({"id": id, "at": int(d.get("done", 0)), "parts": used.map(func(u): return u.tag), "cash": price(id, with_parts), "with_parts": with_parts})
	d.repairs = log
	var pend: Array = d.get("repaired_pending", [])
	pend.append(id)
	d.repaired_pending = pend
	var desk: Dictionary = d.get("desk", {})
	desk.buy = int(desk.get("buy", 0)) + 1
	d.desk = desk
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# sell a part off the shelf for what it is worth now
static func sell(uid: String) -> String:
	var before := Career.data
	Career.data = before.duplicate(true)
	var shelf: Array = Career.data.get("parts", [])
	for i in shelf.size():
		if shelf[i].uid == uid and not shelf[i].has("listed"):
			Career.data.money = float(Career.data.money) + part_worth(shelf[i])
			shelf.remove_at(i)
			Career.data.parts = shelf
			if not Career.save():
				Career.data = before
				return Txt.t("gr_save_failed")
			return ""
	Career.data = before
	return Txt.t("rp_unknown")


# 87-7: a sail roll of grade B or better can be listed for the sail-makers instead of sold to the
# yard's buyers: asking its fair price (value x grade) plus LIST_K, it finds a buyer after LIST_T s
# of play and pays that less the exchange's fee, once. Withdrawn, it is back on the rack as it was.
const LIST_K := 0.08
const LIST_T := 120.0
const LIST_FEE := 0.02
const LIST_MIN := 0.7


static func can_list(part: Dictionary) -> bool:
	return str(part.get("cls", "")) == "sail" and float(part.get("cond", 0.0)) >= LIST_MIN


static func list_price(part: Dictionary) -> float:
	return snappedf(part_worth(part) * (1.0 + LIST_K), 1.0)


static func list_part(uid: String, on: bool) -> String:
	var before := Career.data
	Career.data = before.duplicate(true)
	for part in Career.data.get("parts", []):
		if str(part.uid) != uid:
			continue
		if on and not can_list(part):
			Career.data = before
			return Ops.w("只有 B 级以上的光帆卷能挂牌", "ONLY SAIL ROLLS OF GRADE B OR BETTER CAN BE LISTED")
		if on:
			part["listed"] = {"ask": list_price(part), "t": 0.0}
		else:
			part.erase("listed")
		if not Career.save():
			Career.data = before
			return Txt.t("gr_save_failed")
		return ""
	Career.data = before
	return Txt.t("rp_unknown")


# the listings' clock (game time): the names of what sold now
static func advance_listings(dt: float) -> Array:
	if not Career.usable() or Career.data.is_empty() or dt <= 0.0:
		return []
	var shelf: Array = Career.data.get("parts", [])
	var sold: Array = []
	var keep: Array = []
	var got := 0.0
	var any := false
	for part in shelf:
		if part.has("listed"):
			any = true
			part.listed.t = float(part.listed.t) + dt
			if float(part.listed.t) >= LIST_T:
				got += float(part.listed.ask) * (1.0 - LIST_FEE)
				sold.append(str(part.tag))
				continue
		keep.append(part)
	if not any or sold.is_empty():
		return sold
	var before := Career.data.duplicate(true)
	Career.data.parts = keep
	Career.data.money = float(Career.data.money) + got
	if not Career.save():
		Career.data = before
		return []
	return sold


static func sell_all() -> float:
	var before := Career.data
	Career.data = before.duplicate(true)
	var total := 0.0
	var kept: Array = []
	for part in Career.data.get("parts", []):
		# a listed roll stays listed: "sell all" sells what is on the rack
		if part.has("listed"):
			kept.append(part)
			continue
		total += part_worth(part)
	Career.data.money = float(Career.data.money) + total
	Career.data.parts = kept
	if not Career.save():
		Career.data = before
		return 0.0
	return total


# ---------------------------------------------------------------- the books

# the shelf, by class: {cls: [parts]}
static func shelf_by_class() -> Dictionary:
	var out := {}
	for cls in CLASSES:
		out[cls] = []
	out["sail"] = []
	for part in Career.data.get("parts", []):
		if not out.has(part.cls):
			out[part.cls] = []
		out[part.cls].append(part)
	return out


# the items not yet repaired whose prerequisites are met, nearest to done first
static func open_items() -> Array:
	var out: Array = []
	for it in ITEMS:
		if done(it[0]) or not deps_ok(it[0]) or not found(it[0]):
			continue
		out.append({"id": it[0], "gap": gap(it[0])})
	out.sort_custom(func(a, b): return a.gap < b.gap)
	return out


# how far a repair is from done, 0 (ready) .. 1 (nothing yet), parts and money together
static func gap(id: String) -> float:
	var it := find(id)
	if it.is_empty():
		return 1.0
	var pf := parts_for(id)
	var needs: Dictionary = it[2]
	var want := 0.0
	var have := 0.0
	for cls in needs:
		if cls == "structure":
			want += 1.0
			have += clampf(pf.tons / maxf(0.001, float(needs[cls])), 0.0, 1.0)
		else:
			want += 1.0
			have += 1.0 - float(pf.missing.get(cls, 0)) / maxf(1.0, float(needs[cls]))
	want += 1.0
	have += clampf(float(Career.data.get("money", 0.0)) / maxf(1.0, price(id, true)), 0.0, 1.0)
	return 1.0 - have / want


# what to work for next: the nearest open repair, what it still lacks, and which ship
# types carry such parts (for the settlement and the terminal)
static func suggestion() -> Dictionary:
	var items := open_items()
	if items.is_empty():
		return {}
	var id: String = items[0].id
	var pf := parts_for(id)
	var lack: Array = []
	var ships: Array = []
	for cls in pf.missing:
		lack.append("%s ×%d" % [class_name_of(cls), int(pf.missing[cls])])
		for s in ships_with(cls):
			if not s in ships:
				ships.append(s)
	if pf.tons_missing > 0.001:
		lack.append("%s %.1f t" % [class_name_of("structure"), pf.tons_missing])
	var cost := price(id, true)
	var short := cost - float(Career.data.get("money", 0.0))
	return {"id": id, "name": name_of(id), "lack": lack, "ships": ships.slice(0, 3), "cash": cost, "short": maxf(0.0, short), "ready": pf.ok and short <= 0.0}


static var _ships_cache := {}


# the ship types on the market that carry parts of a class (by their files)
static func ships_with(cls: String) -> Array:
	if _ships_cache.has(cls):
		return _ships_cache[cls]
	var out: Array = []
	for e in Market.POOL:
		var d := Ship.load_data(str(e[0]))
		for pd in d.get("pieces", []):
			if pd.get("cls", "") != "equip" or pd.get("tag", "") == "" or float(pd.get("value", 0.0)) < PART_MIN_VALUE:
				continue
			var fake := {"cls": "equip", "intact": true, "tag": pd.tag, "value": float(pd.value), "name_key": str(pd.get("name_key", "")), "hazard": str(pd.get("hazard", ""))}
			if _class_of_data(fake) == cls:
				var ty := Market.type_of(str(e[0]))
				out.append(str(ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else str(e[0]))
				break
	_ships_cache[cls] = out
	return out


static func _class_of_data(d: Dictionary) -> String:
	var nk: String = d.name_key
	if d.hazard in ["gen", "battery", "cap"] or nk in POWER_KEYS:
		return "power"
	if nk in THERMAL_KEYS:
		return "thermal"
	if nk in DRIVE_KEYS:
		return "drive"
	for w in THERMAL_WORDS:
		if nk.find(w) >= 0:
			return "thermal"
	for w in DRIVE_WORDS:
		if nk.find(w) >= 0:
			return "drive"
	return ""


# ---------------------------------------------------------------- old careers

# a career from before the run-down berth: it has been working with the base
# facilities all along, so it keeps them; the shelf starts empty
static func migrate() -> void:
	var d := Career.data
	if d.is_empty():
		return
	if not d.has("parts"):
		d.parts = []
	if not d.has("structure_t"):
		d.structure_t = 0.0
	if not d.has("repairs"):
		d.repairs = []
	if not d.has("repaired_pending"):
		d.repaired_pending = []
	# 86 号 Q12: a career past its first ship knew the three faults already
	if not d.has("faults_found"):
		d.faults_found = {}
		if not d.get("history", []).is_empty():
			for id in FAULTS:
				d.faults_found[id] = true
	if not d.has("repair_migrated"):
		d.repair_migrated = true
		if int(d.get("done", 0)) > 0:
			for id in BASE:
				d.upgrades[id] = 1
