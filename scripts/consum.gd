class_name Consum
# Retired tool-part economy. Kept as a compatibility adapter for old saves,
# recordings and callers. Basic tools no longer need fitted consumable parts.
const ENABLED := false
const TOOLS := ["probe", "lens", "cap"]
const TOOL_SLOT := {"probe": 1, "lens": 2, "cap": 3}
const TIERS := ["cheap", "std", "fine"]
const SPEC := {
	"lens": {"price": [800.0, 2400.0, 6000.0], "cap": [40.0, 120.0, 300.0], "unit": "m", "risk": 0.08},
	"cap": {"price": [600.0, 1800.0, 4500.0], "cap": [30.0, 100.0, 250.0], "unit": "t", "risk": 0.06},
	"probe": {"price": [300.0, 900.0, 2200.0], "cap": [40.0, 120.0, 300.0], "unit": "", "risk": 0.15},
}
const START_TIER := 1              # a new berth comes with a standard part in each tool
const FINE_KERF := 2.4             # px: the fine lens's kerf (the plain one cuts 3.4)
const FINE_WARN := 1.6             # the fine lens warns of equipment this much earlier
const FINE_GRAB := 5.0             # t: the fine capacitor's grab
const CAP_MIN := 0.3               # t: the least a grab costs the capacitor
const SLIP_T := [1.5, 3.0]         # s after a cheap capacitor's grab before it may let go
const BURST_HURT := 18.0           # integrity a bursting lens costs the drone
const BURST_DENT := 0.3            # condition the piece under the beam loses
static var force_fail := false     # tests: a cheap part always fails



static func name_of(tool: String) -> String: return Txt.t("cs_"+tool)
static func tier_name(tier: int) -> String: return Txt.t("cs_tier_"+TIERS[clampi(tier,0,2)])
static func desc(tool: String,tier: int) -> String: return Txt.t("cs_%s_%s" % [tool,TIERS[clampi(tier,0,2)]])
static func price(tool: String,tier: int) -> float: return float(SPEC[tool].price[clampi(tier,0,2)])
static func capacity(tool: String,tier: int) -> float: return float(SPEC[tool].cap[clampi(tier,0,2)])
static func unit(tool: String) -> String: return str(SPEC[tool].unit) if str(SPEC[tool].unit) != "" else Txt.t("cs_unit_reads")
static func fresh_part(tool: String,tier: int) -> Dictionary: return {"tier":tier,"left":capacity(tool,tier)}
static func shelf(tool: String) -> Array: return Career.data.get("consum",{}).get(tool,[])
static func fitted(tool: String) -> Dictionary: return Career.data.get("fitted",{}).get(tool,{})
static func reason_buy(_tool: String,_tier: int) -> String:
	return "工具持续可用，无需购买配件。" if Txt.zh else "TOOLS ARE CONTINUOUSLY AVAILABLE; NO PARTS REQUIRED."
static func buy(tool: String,tier: int) -> String: return reason_buy(tool,tier)
static func fit(tool: String,_index: int) -> String: return reason_buy(tool,0)
static func fit_later(tool: String,_index: int,_job: Dictionary) -> String: return reason_buy(tool,0)
static func apply_pending(_game) -> void: pass
static func _counts(_game) -> bool: return false
static func job_part(game,tool: String) -> Dictionary: return game.job.get("consum",{}).get(tool,{})
static func tier(_game,_tool: String) -> int: return -1
static func left(_game,_tool: String) -> float: return INF
static func ready(_game,_tool: String) -> bool: return true
static func use(_game,_tool: String,_amount: float) -> bool: return true
static func fails(_game,_tool: String) -> bool: return false
static func is_fine(_game,_tool: String) -> bool: return false
static func is_cheap(_game,_tool: String) -> bool: return false
static func wear_out(_game,_tool: String) -> void: pass
static func restock() -> Array: return []
static func settle_job(_job: Dictionary) -> void: pass

static func noisy_text(text: String, noise: float) -> String:
	var re := RegEx.new()
	re.compile("-?\\d+(\\.\\d+)?")
	var m := re.search(text)
	if m == null:
		return text
	var s := m.get_string()
	var v := float(s) * (1.0 + noise)
	var out := ("%.1f" % v) if s.find(".") >= 0 else str(int(round(v)))
	return text.substr(0, m.get_start()) + out + text.substr(m.get_end())



static func fresh_state() -> Dictionary:
	return {"consum":{},"fitted":{}}

static func _residual(tool: String,part: Dictionary) -> float:
	var level := int(part.get("tier",-1))
	var remaining := float(part.get("left",0.0))
	if level < 0 or level > 2 or not is_finite(remaining): return 0.0
	return price(tool,level)*clampf(remaining/capacity(tool,level),0.0,1.0)

static func migrate() -> bool:
	if Career.data.is_empty() or Career.data.get("tool_parts_retirement",{}).get("version",0) == 1: return true
	var before := Career.data
	var shelves = before.get("consum",{})
	var installed = before.get("fitted",{})
	if not shelves is Dictionary or not installed is Dictionary: return false
	var refund := 0.0
	for tool in TOOLS:
		var parts: Array = []
		if shelves.get(tool,[]) is Array: parts.append_array(shelves.get(tool,[]))
		if installed.get(tool,{}) is Dictionary and not installed.get(tool,{}).is_empty(): parts.append(installed[tool])
		var value := 0.0
		var starter := 0.0
		for part in parts:
			if not part is Dictionary: continue
			var residual := _residual(tool,part)
			value += residual
			# Original careers received one standard part per tool for free.
			# No purchase provenance exists: conservatively exclude one such
			# remaining part, rather than inventing a full historical refund.
			if int(part.get("tier",-1)) == START_TIER: starter = maxf(starter,residual)
		refund += maxf(0.0,value-starter)
	var next := before.duplicate(true)
	next.tool_parts_retirement = {"version":1,"refund":refund,"shelf":shelves.duplicate(true),"fitted":installed.duplicate(true),"active":next.get("active",{}).get("consum",{}).duplicate(true),"pending":next.get("active",{}).get("fit_pending",{}).duplicate(true)}
	next.money = float(next.get("money",0.0))+refund
	next.consum = {}
	next.fitted = {}
	var active: Dictionary = next.get("active",{})
	active.erase("consum")
	active.erase("fit_pending")
	if next.get("exchange",{}).get("actors",{}).has("company"):
		next.exchange.actors.company.cash = float(next.money)
	Career.data = next
	if not Career.save():
		Career.data = before
		return false
	return true
