class_name Port
# Zero Pressure Port (G6, design/成长版本/G6_零压港六区.md): six districts and the
# central transfer ring behind the berth, dark at the start. Each has two stages of
# works, paid with the parts on the shelf, structure by the tonne and money (the
# materials of G5 come later and take over the costs). Each stage finished lights
# the district a little more in the backdrop and changes something real:
#   power    stage 1 the second equipment bay and the crane may be repaired (prerequisite)
#   salvage  the berth district: stage 2 opens the second berth later (G7)
#   process  the furnace district: stage 1 scrap pays 5 % more, stage 2 10 %
#   tug      the tug station: stage 1 no more towing fee on a contract
#   trade    the trade port: stage 1 equipment sells 10 % better, stage 2 20 %
#   cargo    the cargo district (player's sketch 2026-10-21): stage 1 a third deploy slot,
#            stage 2 the shelf restocks a cheap part of each consumable at settlement
#   ring     the transfer ring: the long goal; stage 2 is the end of the main line (G7)
# Promised effects (Jev 2026-10-21): the power district is a hard prerequisite of the heavy
# berth repairs (POWER_ITEMS); the trade port weights the market's star rolls (star_weight_of);
# the tug station below stage 2 queues any ship longer than the standard berth for one
# contract (queues_big / Career.hold).
# Career.data.port = {zone: stages done}; a stage finished is queued on
# repaired_pending as "port:<zone>:<n>" for the show back at the berth.

const ZONES := ["power", "salvage", "process", "tug", "trade", "cargo", "ring"]
# per zone: two stages, each {class: n | "structure": t, "cash": money}
const STAGES := {
	"power": [{"power": 2, "cash": 20000.0}, {"power": 2, "drive": 1, "cash": 45000.0}],
	"salvage": [{"structure": 10.0, "cash": 15000.0}, {"structure": 20.0, "drive": 2, "cash": 60000.0}],
	"process": [{"thermal": 2, "cash": 25000.0}, {"thermal": 2, "structure": 15.0, "cash": 55000.0}],
	"tug": [{"drive": 2, "cash": 30000.0}, {"drive": 3, "power": 1, "cash": 70000.0}],
	"trade": [{"structure": 15.0, "cash": 40000.0}, {"drive": 2, "power": 2, "cash": 90000.0}],
	"cargo": [{"structure": 12.0, "cash": 25000.0}, {"drive": 1, "structure": 10.0, "section": 10.0, "cash": 50000.0}],
	"ring": [{"structure": 40.0, "power": 2, "cash": 120000.0}, {"structure": 50.0, "section": 30.0, "drive": 3, "thermal": 2, "cash": 250000.0}],
}
# a stage that needs another zone's stage first: zone -> [[other zone, stage], ...] for its stage 1
const DEPS := {"trade": [["salvage", 1]], "ring": [["power", 1], ["tug", 1]]}
const TOW_FEE := 1500.0           # per contract while the tug station is down
const PARTS_SHARE := 0.25          # 74 号: with the materials brought, the crew's wages only
# the berth repairs that draw on the port's grid: they wait for the power district's stage 1
const POWER_ITEMS := ["crane", "port2", "arm", "hauler2"]


static func stage(zone: String) -> int:
	return int(Career.data.get("port", {}).get(zone, 0))


static func name_of(zone: String) -> String:
	return Txt.t("pt_" + zone)


static func desc_of(zone: String, n: int) -> String:
	return Txt.t("pt_%s_%d" % [zone, clampi(n, 1, 2)])


static func needs(zone: String, n: int) -> Dictionary:
	var out: Dictionary = (STAGES[zone][clampi(n, 1, 2) - 1] as Dictionary).duplicate()
	out.erase("cash")
	return out


static func cash(zone: String, n: int, with_parts: bool) -> float:
	return float(STAGES[zone][clampi(n, 1, 2) - 1].cash) * (PARTS_SHARE if with_parts else 1.0)


static func deps_ok(zone: String) -> bool:
	for d in DEPS.get(zone, []):
		if stage(str(d[0])) < int(d[1]):
			return false
	return true


# why the zone's next stage cannot be built now ("" when it can)
static func reason(zone: String, with_parts: bool) -> String:
	var n := stage(zone)
	if n >= 2:
		return Txt.t("pt_done")
	if n == 0 and not deps_ok(zone):
		var parts: Array = []
		for d in DEPS.get(zone, []):
			parts.append(name_of(str(d[0])))
		return Txt.t("tm_needs") % ", ".join(parts)
	if with_parts:
		var pf := Repair.parts_for_needs(needs(zone, n + 1))
		if not pf.ok:
			var lack: Array = []
			for cls in pf.missing:
				lack.append(Repair.lack_text(cls, float(pf.missing[cls])))
			if pf.tons_missing > 0.001:
				lack.append(Repair.lack_text("structure", pf.tons_missing))
			if float(pf.get("section_missing", 0.0)) > 0.001:
				lack.append(Repair.lack_text("section", float(pf.section_missing)))
			return Txt.t("rp_missing") % ("、" if Txt.zh else ", ").join(lack)
	var cost := cash(zone, n + 1, with_parts)
	if float(Career.data.get("money", 0.0)) < cost:
		return Txt.t("tm_short") % Pal.money(cost - float(Career.data.money))
	return ""


# build the zone's next stage; nothing changes on a failed write
static func fix(zone: String, with_parts: bool) -> String:
	var why := reason(zone, with_parts)
	if why != "":
		return why
	var n := stage(zone) + 1
	var before := Career.data
	Career.data = before.duplicate(true)
	var d := Career.data
	if with_parts:
		Repair.take_needs(needs(zone, n))
	d.money = float(d.money) - cash(zone, n, with_parts)
	var pt: Dictionary = d.get("port", {})
	pt[zone] = n
	d.port = pt
	var log: Array = d.get("repairs", [])
	log.append({"id": "port:%s:%d" % [zone, n], "at": int(d.get("done", 0)), "parts": [], "cash": cash(zone, n, with_parts), "with_parts": with_parts})
	d.repairs = log
	var pend: Array = d.get("repaired_pending", [])
	pend.append("port:%s:%d" % [zone, n])
	d.repaired_pending = pend
	if not Career.save():
		Career.data = before
		return Txt.t("gr_save_failed")
	return ""


# ---------------------------------------------------------------- what the port does for the berth

static func trade_k() -> float:
	return 1.0 + 0.1 * stage("trade")


# 123 号: the processing district's 5 / 10 % was never paid since scrap became ingots (64 号);
# its stages open the furnace, the sorting line and the mill instead (pt_process_1)
static func scrap_k() -> float:
	return 1.0


static func power_ok(item: String) -> bool:
	return item not in POWER_ITEMS or stage("power") >= 1


# a third deploy slot once the cargo district runs
static func deploy_bonus() -> int:
	return 1 if stage("cargo") >= 1 else 0


# the market's star rolls lean to the top the more of the trade port is open: 1, 2, 3
static func star_weight_of(career: Dictionary) -> int:
	return 1 + int(career.get("port", {}).get("trade", 0))


# a ship longer than the standard berth queues for a contract while only one tug runs
static func queues_big(career: Dictionary, length: float) -> bool:
	return length > Dock.STANDARD and int(career.get("port", {}).get("tug", 0)) < 2


# 123 号 (user 2026-11-04, 72 号's rule): the tow is paid once, when the tug is sent (TugYard /
# ShipMarket.tow_terms, the company's own tug at half price); no second fee at the settlement
static func tow_fee() -> float:
	return 0.0


# the zones lit, for the backdrop: zone -> 0..2
static func lit() -> Dictionary:
	var out := {}
	for z in ZONES:
		out[z] = stage(z)
	return out


static func total_stages() -> int:
	var n := 0
	for z in ZONES:
		n += stage(z)
	return n


static func migrate() -> void:
	if Career.data.is_empty():
		return
	if not Career.data.has("port"):
		Career.data.port = {}
