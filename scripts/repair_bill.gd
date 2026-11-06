extends RefCounted
# 128 号 第 3 段 §八 三角洲式修缮: one "修" button. What a district's next stage takes is named
# (Jev A 0.99: "泵 2 台 · 发电机 1 台 · 修缮钢材 15 t"): the warehouse's own machines and repair
# steel go first, what is short is bought at market in the same click (the exchange's book is the
# second segment's; till it opens this is a straight buy at market, no listing), and the crew is
# free — only the materials cost. A machine is a material as it is: any machine of the named kind
# in the warehouse counts, the best kept first.
# NEEDS: zone → its two stages, each {"steel": t, "kinds": [[name_key, n], ...]}. Draft figures for
# the sketch; to be calibrated with the bot (TUG-001 and the next hulks) before the full build.

const NEEDS := {
	"trade": [{"steel": 12.0, "kinds": [["p_battery", 2], ["p_nav", 1]]}, {"steel": 20.0, "kinds": [["p_generator", 1], ["p_swb", 2]]}],
	"process": [{"steel": 10.0, "kinds": [["p_pump", 1], ["p_radiator", 1]]}, {"steel": 18.0, "kinds": [["p_compressor", 1], ["p_pump", 2]]}],
	"cargo": [{"steel": 14.0, "kinds": [["p_winch", 1], ["p_battery", 1]]}, {"steel": 22.0, "kinds": [["p_winch", 1], ["p_engine", 1]]}],
	"power": [{"steel": 8.0, "kinds": [["p_generator", 1], ["p_battery", 2]]}, {"steel": 16.0, "kinds": [["p_generator", 2], ["p_radiator", 2]]}],
	"tug": [{"steel": 10.0, "kinds": [["p_rcs", 2], ["p_fueltank", 1]]}, {"steel": 18.0, "kinds": [["p_engine", 2], ["p_nav", 1]]}],
	"salvage": [{"steel": 10.0, "kinds": []}, {"steel": 20.0, "kinds": [["p_rcs", 2]]}],
	"ring": [{"steel": 40.0, "kinds": [["p_generator", 2], ["p_swb", 2]]}, {"steel": 60.0, "kinds": [["p_engine", 3], ["p_radiator", 2]]}],
}
static var ON := true             # 第 3 段 one-key mending (legacy tests switch it off: parts or cash)
const STEEL_PRICE := 900.0        # $ a tonne of repair steel bought (draft: plate at market)
const SECS_BASE := 20.0           # the crew's time: a base and a little per thing (draft)
const SECS_EACH := 6.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func kind_name(nk: String) -> String:
	return Txt.t(nk) if Txt.has(nk) else nk


# what one of a kind costs at market: the middle of that kind's whole machines in the real ship files
# (training courses and test hulls left out), the price the warehouse would show for a sound one
static var _price := {}
static func kind_price(nk: String) -> float:
	if _price.has(nk):
		return float(_price[nk])
	var vals: Array = []
	for f in DirAccess.get_files_at(Ship.DIR):
		var base := f.get_basename()
		if not f.ends_with(".json") or base.begins_with("sp_") or base in ["arktest", "belt", "berth"] or base.begins_with("e07") or base.ends_with("_course"):
			continue
		# a file that is not a whole hulk (no pieces of its own) is left out before it is read as one
		if FileAccess.get_file_as_string(Ship.DIR + f).find("\"pieces\"") < 0:
			continue
		for pd in Ship.load_data(base).get("pieces", []):
			if str(pd.get("name_key", "")) == nk and float(pd.get("value", 0.0)) > 0.0:
				vals.append(float(pd.value))
	vals.sort()
	var v := snappedf(float(vals[vals.size() / 2]), 10.0) if not vals.is_empty() else 4000.0
	_price[nk] = v
	return v


# the warehouse's machines of a kind, the best kept first: [{id, name, worth}]
static func own_of(nk: String) -> Array:
	var out: Array = []
	for p in Career.data.get("parts", []):
		if str(p.get("nk", "")) == nk and not p.has("listed"):
			out.append({"id": "p:" + str(p.uid), "worth": Repair.part_worth(p), "cond": float(p.get("cond", 1.0))})
	for gd in Career.data.get("goods", []):
		if str(gd.get("nk", "")) == nk and str(gd.get("cat", "")) == "equip":
			out.append({"id": "g:" + str(gd.uid), "worth": float(gd.get("value", 0.0)), "cond": 1.0})
	out.sort_custom(func(a, b): return float(a.cond) > float(b.cond))
	return out


# 128 号 第 2 段: what is short is bought at market until the exchange opens; from then on from the
# exchange's buy page, at its price (other companies' goods, dearer than one's own salvage)
static func buy_price(nk: String) -> float:
	if HallMarket.open():
		return HallMarket.buy_each(nk)
	return STEEL_PRICE if nk == HallMarket.STEEL else kind_price(nk)


# the bill for a zone's next stage:
#   {zone, stage, rows: [{nk, name, need, own, buy, each}], steel: {need, own, buy, each},
#    own_n, buy_n, buy_cash, secs, cash_ok}
static func of(zone: String) -> Dictionary:
	var st := Port.stage(zone) + 1
	var out := {"zone": zone, "stage": st, "rows": [], "own_n": 0, "buy_n": 0, "buy_cash": 0.0}
	if st > 2 or not NEEDS.has(zone):
		return out
	var need: Dictionary = NEEDS[zone][st - 1]
	for k in need.kinds:
		var nk := str(k[0])
		var want := int(k[1])
		var own := mini(want, own_of(nk).size())
		var each := buy_price(nk)
		out.rows.append({"nk": nk, "name": kind_name(nk), "need": want, "own": own, "buy": want - own, "each": each})
		out.own_n += own
		out.buy_n += want - own
		out.buy_cash += (want - own) * each
	var have := float(Career.data.get("structure_t", 0.0))
	var steel := float(need.steel)
	var own_t := minf(steel, have)
	var steel_each := buy_price(HallMarket.STEEL)
	out.steel = {"need": steel, "own": own_t, "buy": steel - own_t, "each": steel_each}
	out.buy_cash += (steel - own_t) * steel_each
	out.at_hall = HallMarket.open()
	out.buy_cash = snappedf(out.buy_cash, 1.0)
	out.secs = SECS_BASE + SECS_EACH * (out.own_n + out.buy_n)
	out.cash_ok = float(Career.data.get("money", 0.0)) + 0.5 >= float(out.buy_cash)
	return out


# the one line of the confirmation (§八): "自有 X 件 · 要买 Y 件 $… · 合计 $… · 约 N 秒完工"
static func line(b: Dictionary) -> String:
	var steel: Dictionary = b.get("steel", {})
	var own := w("自有 %d 件", "%d OWN") % int(b.own_n)
	if float(steel.get("own", 0.0)) > 0.05:
		own += w(" + 钢材 %.1f t", " + %.1f t STEEL") % float(steel.own)
	var buy := w("要买 %d 件", "BUY %d") % int(b.buy_n)
	if float(steel.get("buy", 0.0)) > 0.05:
		buy += w(" + 钢材 %.1f t", " + %.1f t STEEL") % float(steel.buy)
	return w("%s · %s %s · 合计 %s · 约 %d 秒完工", "%s · %s %s · TOTAL %s · DONE IN ~%d s") % [own, buy, Pal.money(float(b.buy_cash)), Pal.money(float(b.buy_cash)), int(b.secs)]


# the one "修": the warehouse's own machines and repair steel taken, what is short bought at market,
# the cash paid. Nothing changes on a failure. -> "" or why not
static func pay(zone: String) -> String:
	var b := of(zone)
	if int(b.get("stage", 3)) > 2:
		return Txt.t("pt_done")
	if not Port.deps_ok(zone) and Port.stage(zone) == 0:
		var parts: Array = []
		for d in Port.DEPS.get(zone, []):
			parts.append(Port.name_of(str(d[0])))
		return Txt.t("tm_needs") % ", ".join(parts)
	if not bool(b.cash_ok):
		return w("现金不够：还差 %s", "NOT ENOUGH CASH: %s SHORT") % Pal.money(float(b.buy_cash) - float(Career.data.get("money", 0.0)))
	var before := Career.data
	Career.data = before.duplicate(true)
	var d := Career.data
	var taken: Array = []
	for row in b.rows:
		var mine := own_of(str(row.nk)).slice(0, int(row.own))
		for m in mine:
			var id := str(m.id)
			taken.append(id)
			if id.begins_with("p:"):
				d.parts = d.get("parts", []).filter(func(p): return "p:" + str(p.uid) != id)
			else:
				d.goods = d.get("goods", []).filter(func(gd): return "g:" + str(gd.uid) != id)
	var pos: Dictionary = d.get("store_pos", {})
	for id in taken:
		pos.erase(id)
	d.store_pos = pos
	d.structure_t = maxf(0.0, float(d.get("structure_t", 0.0)) - float(b.steel.own))
	d.money = float(d.get("money", 0.0)) - float(b.buy_cash)
	if bool(b.get("at_hall", false)):
		HallMarket.log_repair_buys(b.rows, float(b.steel.buy))
	if d.get("exchange", {}).get("actors", {}).has(StoreBook.Exchange.PLAYER):
		d.exchange.actors[StoreBook.Exchange.PLAYER].cash = float(d.money)
	var log: Array = d.get("repairs", [])
	log.append({"id": "port:%s:%d" % [zone, int(b.stage)], "at": int(d.get("done", 0)), "parts": taken, "cash": float(b.buy_cash), "steel_t": float(b.steel.need), "bought": int(b.buy_n)})
	d.repairs = log
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# the materials in one short line: "电池 2 · 导航电脑 1 · 钢材 12 t（要买 1 件）"
static func short_line(b: Dictionary) -> String:
	var parts: Array = []
	for row in b.get("rows", []):
		parts.append("%s %d" % [str(row.name), int(row.need)])
	if b.has("steel"):
		parts.append(w("钢材 %.0f t", "steel %.0f t") % float(b.steel.need))
	var s := " · ".join(parts)
	if int(b.get("buy_n", 0)) > 0 or float(b.get("steel", {}).get("buy", 0.0)) > 0.05:
		if bool(b.get("at_hall", false)):
			s += w("（缺的从交易行买 %s）", " (the rest bought on the exchange, %s)") % Pal.money(float(b.get("buy_cash", 0.0)))
		else:
			s += w("（缺的按市价买 %s）", " (the rest bought at market, %s)") % Pal.money(float(b.get("buy_cash", 0.0)))
	else:
		s += w("（仓库里都有）", " (all in the stores)")
	return s
