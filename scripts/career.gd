class_name Career
# The salvage business between contracts: money, the loan, reputation,
# upgrades and stock, the three offers on the market, the contract in
# progress and the books of every contract done. Its own file next to the
# contract save, written the same way (checksum, tmp swap, .bak fallback).
# A new career moves the old one aside, never deletes it.

const PATH := "user://zeropower_career.json"
const VERSION := 1
const LOAN_START := 0.0           # no debt at the start: debt only comes from a job gone wrong
                                  # (a loss the funds can't cover, or a contract fee borrowed)
const INSTALLMENT := 20000.0      # taken at every settlement
const INTEREST := 0.02            # of the principal still owed, every settlement
const BONUS := 0.2                # of the net profit, finished within the standard time
const FAST_BONUS := 0.30          # the same on a fast-recovery job (its standard time is a quarter shorter)
const FIRST := "GR-001"           # the hand-made Heron; the market opens after it
# 开局第一关（第一单合同）结算完，白送一台初级搬运无人机：新手第二单就能用上拖运，
# 不用先攒 45,000。改这个数字就能挪到别的关后面（0 = 不送，2 = 第二关之后……）。
# After this many settled contracts the basic hauling drone is fitted for free, once.
const GIFT_HAULER_AFTER := 1
const GIFT_HAULER := "hauler"
# The fixed contracts a new berth works through, in order, before the market
# opens (design/体验打磨定案.md: training → the work tug → S-09 Swift → GR-001).
# intro / outro: Liang's lines when the ship comes in (_1.._3) and when it is done.
# 26 号 (player 2026-10-24): the three opening hulks are unowned, towed in from the belt by your
# own tug: nobody's fee, everything on them yours (the Heron's was $9,000 before)
const OPENING := [
	{"id": "TUG-001", "ship": "tug", "fee": 0.0, "time": 10.0 * 60.0, "intro": "L_tug_in", "outro": "L_tug_done", "owner": "salvage"},
	{"id": "S09-001", "ship": "s09", "fee": 0.0, "time": 14.0 * 60.0, "intro": "L_swift_in", "outro": "L_swift_done", "owner": "salvage"},
	{"id": FIRST, "ship": "gr7", "first": true, "fee": 0.0, "owner": "salvage"},
]
# reputation points per settlement grade (fail, pass, good, excellent) and the levels
const REP_GAIN := [-1, 1, 2, 3]
const LEVELS := [["trainee", 0], ["certified", 6], ["senior", 16], ["chief", 30]]

static var path := PATH           # tests point this at their own file
static var data: Dictionary = {}
# three save slots, each a career with its own contract and training files;
# slot 1 keeps the file names from before slots, so an old career is slot 1
const SLOTS := 3
static var slot := 1


static func slot_files(n: int) -> Array:
	if n <= 1:
		return [PATH, SaveGame.PATH, SaveGame.TRAIN_PATH]
	return ["user://zp_slot%d_career.json" % n, "user://zp_slot%d_save.json" % n, "user://zp_slot%d_training.json" % n]


static func use_slot(n: int) -> void:
	var f := slot_files(n)
	slot = n
	path = f[0]
	SaveGame.path = f[1]
	SaveGame.train_path = f[2]
	data = {}


# what a slot card shows, read without switching to it ({} when empty;
# a test run never looks at the player's files)
static func peek(n: int) -> Dictionary:
	if _test_run():
		return {}
	var f := slot_files(n)
	if SaveGame.exists(f[0]):
		var d := SaveGame.read_career(f[0])
		if not d.is_empty():
			return d
	if SaveGame.exists(f[1]) or SaveGame.exists(f[2]):
		return {"done": 0, "money": 0.0, "loan": LOAN_START, "time": 0.0, "certified": SaveGame.exists(f[1])}
	return {}


# a slot emptied: its files are moved aside (.old), never deleted
static func clear_slot(n: int) -> void:
	if _test_run():
		return
	for f in slot_files(n):
		for ext in ["", ".bak"]:
			if FileAccess.file_exists(f + ext):
				var full := ProjectSettings.globalize_path(f + ext)
				if FileAccess.file_exists(f + ext + ".old"):
					DirAccess.remove_absolute(full + ".old")
				DirAccess.rename_absolute(full, full + ".old")
	if slot == n:
		data = {}


# a test run never touches the player's own career file
static func _test_run() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.find("tests/") >= 0:
			return true
	return false


# A company batch (industrial heat or sorting) that has not reached a terminal state.
# It only ever runs at the empty berth: its line and furnace are restored from the
# batch's own snapshot there, a contract or sandbox scene gets fresh plant. So it
# reserves the berth's metal mouth and trough through plant_reserved(), and never
# blocks taking contracts (2026-10-24, Jev A 0.97: the player's save sat on a
# product_transport batch and every contract and every scrap mouth was refused).
static func production_busy() -> bool:
	for key in ["industrial_heat","industrial_sort"]:
		var heat: Dictionary = data.get(key,{})
		if not heat.is_empty() and heat.get("state","") not in ["complete","cancelled","written_off"]: return true
	return false


# the plant is reserved for the company batch only where that batch's plant is live
static func plant_reserved(game) -> bool:
	# 30 号: the processing district's own works — the berth's furnace stays the contract's
	if game != null and game.get("plant") != null:
		return false
	return production_busy() and game != null and game.in_berth()


static func usable() -> bool:
	return path != PATH or not _test_run()


static func fresh() -> Dictionary:
	return {
		"version": VERSION,
		"money": 0.0,
		"loan": LOAN_START,
		"in_debt": false,
		"debt_rule": 2,
		"rep": 0,
		"upgrades": {},
		"growth_goal": "",
		"route_goals": [],         # up to two pinned on the route page (Route.pins)
		"items": {},
		"done": 0,
		"history": [],
		"offers": [],
		"active": opening(0),
		"market": false,           # opens once the first contract is done
		"story_job": {},           # the next opening contract, pinned on the market until taken
		"opening_v": 2,            # 2: the market opens after the tug (2026-10-17)
		"seed": randi(),
		"archive": {},
		"log": [],
		"company": "",
		"time": 0.0,               # seconds played on this slot (training included)
		"certified": false,        # through the training course, or skipped it
		"first_gift": false,       # the opening drone was handed over (GIFT_HAULER_AFTER)
		"clues": [],               # story clues filed (each save has its own)
		"chapter_done": false,
		"exam_grade": "",
		"plans": {},               # ship type -> successful recorded work order
		"plan_notes": {},          # ship type -> latest settlement's recording result
		"gear": {},                # field gear on the shelf: type -> count (scripts/gear.gd)
		"loadout": {"mods": [], "deploy": {}},   # the last configuration taken out
		"feats": {},               # engineering achievements: id -> {ship, job, at, measure}
		"methods": {},             # 104 号: dismantling method -> tier bought (scripts/methods.gd)
		"methods_v": 1,            # a career from before 104 号 lacks it: what it owns is learned
		"trials": {},              # trial contract id -> times settled
		"parts": [],               # the parts shelf (scripts/repair.gd)
		"material_batches": [],    # G5 raw receipts only; legacy saves start empty
		"structure_t": 0.0,        # structure on the shelf, tonnes
		"repairs": [],             # the repair log
		"repaired_pending": [],    # repairs made at the terminal, shown next time the berth is in view
		"berth_v": 2,              # 2: the run-down berth (G2)
		"port": {},                # Zero Pressure Port: zone -> stages built (G6, scripts/port.gd)
		"consum": Consum.fresh_state().consum,   # retired legacy field; empty in new careers
		"fitted": Consum.fresh_state().fitted,   # basic tools no longer require fitted parts
	}


static func exists() -> bool:
	return usable() and SaveGame.exists(path)


static func load_or_new() -> Dictionary:
	if data.is_empty():
		var d := SaveGame.read_career(path) if usable() else {}
		data = d if not d.is_empty() else fresh()
		# a career from before slots: whoever had one had passed or skipped training
		if not d.is_empty() and not d.has("certified"):
			data.certified = true
		# and its story so far was kept in the settings, before each save had its own
		# careers from before the debt rule began with a berth loan: that loan is written off
		if not d.is_empty() and not d.has("debt_rule"):
			data.loan = 0.0
			data.erase("paid_off")
			data.in_debt = false
			data.debt_rule = 2
		if not d.is_empty() and not d.has("clues"):
			data.clues = Txt.clues.duplicate()
			data.chapter_done = Txt.chapter_done
			data.exam_grade = Txt.exam_grade
		# a career from before the market opened early: the market's lines were
		# all said when it opened, Liang's among them
		if not d.is_empty() and not d.has("opening_v"):
			var seen: Dictionary = data.get("seen", {})
			if seen.has("market"):
				seen["market_liang"] = true
				data.seen = seen
		var before_methods: bool = not d.is_empty() and not data.has("methods_v")
		for k in fresh():
			if not data.has(k):
				data[k] = fresh()[k]
		_normalize()
		if before_methods:
			Methods.migrate()
		Repair.migrate()
		_refund_mods()
		Consum.migrate()
		Growth.refund_all()
		Port.migrate()
		_open_market_early()
		sync_story()
		# a save from before the special courses: the families of ship it has already
		# worked through come certified, without the bonus (scripts/codex.gd)
		if not data.get("certs_checked", false):
			Codex.grant_veteran()
			data["certs_checked"] = true
	return data


# the drone modules of G1 were dropped (player 2026-10-21): whatever a career bought is paid back
static func _refund_mods() -> void:
	var g: Dictionary = data.get("gear", {})
	var back := 0.0
	for type in Gear.OLD_MODS:
		var n := int(g.get(type, 0))
		if n > 0:
			back += n * Gear.price(type)
		g.erase(type)
	data.gear = g
	var ld: Dictionary = data.get("loadout", {})
	ld.mods = []
	data.loadout = ld
	if back > 0.0:
		data.money = float(data.money) + back
		data["mods_refunded"] = float(data.get("mods_refunded", 0.0)) + back


# ---------------------------------------------------------------- the loan (G2: credit the berth can draw on)

# what the berth may owe at each reputation level, and the interest each settlement takes
const LIMITS := [50000.0, 150000.0, 400000.0, 1000000.0]
const RATES := [0.03, 0.025, 0.015, 0.01]


static func level_index() -> int:
	var n := 0
	for i in LEVELS.size():
		if int(data.get("rep", 0)) >= LEVELS[i][1]:
			n = i
	return n


static func rate() -> float:
	return RATES[level_index()] if not data.is_empty() else INTEREST


static func credit_limit() -> float:
	return LIMITS[level_index()] if not data.is_empty() else 0.0


static func credit_left() -> float:
	return maxf(0.0, credit_limit() - float(data.get("loan", 0.0)))


# draw on the credit: into the funds now, onto the loan; returns what was lent
static func borrow(amount: float) -> float:
	var take := minf(amount, credit_left())
	if take <= 0.0:
		return 0.0
	var before := data.duplicate(true)
	data.money = float(data.money) + take
	data.loan = float(data.loan) + take
	data.in_debt = true
	data["borrowed_total"] = float(data.get("borrowed_total", 0.0)) + take
	data["loan_at_limit"] = credit_left() <= 0.5
	if not save():
		data = before
		return 0.0
	return take


# JSON gives every number back as a float: counts, levels and seeds are whole
static func _normalize() -> void:
	for k in ["rep", "done", "seed", "version"]:
		data[k] = int(data.get(k, 0))
	for bag in ["items", "upgrades", "gear", "trials"]:
		var b: Dictionary = data.get(bag, {})
		for k in b:
			b[k] = int(b[k])
	# counts and tallies (stock, kit, the desk's log, the archive) are whole, wherever they sit
	var act: Dictionary = data.get("active", {})
	for k in ["items", "kit", "desk", "notes"]:
		if act.has(k):
			act[k] = _whole(act[k])
	for k in ["desk", "archive"]:
		if data.has(k):
			data[k] = _whole(data[k])
	for o in data.get("offers", []) + [data.get("active", {})]:
		for k in ["stars", "variant"]:
			if o.has(k):
				o[k] = int(o[k])


static func _whole(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Dictionary:
		for k in v:
			v[k] = _whole(v[k])
	elif v is Array:
		for i in v.size():
			v[i] = _whole(v[i])
	return v


# a new career: the old one is kept beside it as .old
static func start_new() -> void:
	if usable() and FileAccess.file_exists(path):
		var full := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path + ".old"):
			DirAccess.remove_absolute(full + ".old")
		DirAccess.rename_absolute(full, full + ".old")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(full + ".bak")
	data = fresh()
	data.repair_migrated = true     # a new career starts with the run-down berth (scripts/repair.gd)
	data.onboard = "on"             # 80 号: a new career is walked through its first half hour (scripts/onboard.gd)
	sync_story()
	save()


# through training (or past it): this slot goes straight to the berth from now on
static func certify(kind: String = "") -> void:
	if data.is_empty() or not usable():
		return
	data.certified = true
	if kind != "" and data.get("cert_kind", "") != "full":
		data.cert_kind = kind
	save()


# a save's own story progress is what the game reads (never another save's)
static func sync_story() -> void:
	if data.is_empty():
		return
	Txt.clues = data.get("clues", []).duplicate()
	Txt.chapter_done = bool(data.get("chapter_done", false))
	Txt.exam_grade = str(data.get("exam_grade", ""))


static func store_story() -> void:
	if data.is_empty() or not usable():
		return
	data.clues = Txt.clues.duplicate()
	data.chapter_done = Txt.chapter_done
	data.exam_grade = Txt.exam_grade
	save()


static func save() -> bool:
	if data.is_empty() or not usable():
		return false
	return SaveGame.write_file(path, data)


# user 2026-10-26: a guide shows once per career, and one cut short (the game quit part-way)
# goes on next time from the step it reached
static func guide_at(key: String) -> int:
	return int(data.get("guide_at", {}).get(key, 0))


static func guide_keep(key: String, n: int) -> void:
	if data.is_empty() or not usable():
		return
	var at: Dictionary = data.get("guide_at", {})
	if int(at.get(key, -1)) == n:
		return
	at[key] = n
	data.guide_at = at
	save()


# a one-off hint already shown in this career (it used to come back with every contract)
static func hint_once(key: String) -> bool:
	if data.is_empty() or not usable():
		return true
	var h: Dictionary = data.get("hints_once", {})
	if h.has(key):
		return false
	h[key] = true
	data.hints_once = h
	return true


static func level() -> String:
	var lv: String = LEVELS[0][0]
	for l in LEVELS:
		if int(data.get("rep", 0)) >= l[1]:
			lv = l[0]
	return lv


# points still needed for the next level (0 at the top)
static func to_next() -> int:
	for l in LEVELS:
		if int(data.get("rep", 0)) < l[1]:
			return l[1] - int(data.rep)
	return 0


static func active() -> Dictionary:
	return data.get("active", {})


# the opening contract pinned on the market ({} once the opening is through)
static func story_job() -> Dictionary:
	return data.get("story_job", {})


# take the pinned story contract: it becomes the contract in hand, kitted out now
static func take_story() -> Dictionary:
	var s: Dictionary = story_job()
	if s.is_empty() or not active().is_empty():
		return {}
	data.story_job = {}
	data.active = s
	return sign_active()


# a career saved under the old opening (each opening contract handed straight
# over): one not started yet goes onto the market as the pinned story card
static func _open_market_early() -> void:
	var a: Dictionary = active()
	if data.get("market", false) or a.is_empty() or a.has("kit"):
		return
	if opening_index(a) >= 1:
		data.story_job = a
		data.active = {}
		data.market = true
		data.offers = []


# ---------------------------------------------------------------- the market

# take an offer: the contract fee is paid now (what money can't cover is borrowed)
# the contract in hand goes to work with what the berth owns now (an opening
# contract is not signed at the market, so it gets its kit when it is started)
static func sign_active() -> Dictionary:
	var a: Dictionary = active()
	if a.is_empty() or a.has("kit"):
		return a
	a.kit = data.get("upgrades", {}).duplicate()
	a.items = data.get("items", {}).duplicate()
	a.notes = data.get("archive", {}).get(a.get("ship", ""), {}).duplicate(true)
	a.desk = data.get("desk", {}).duplicate()
	data.desk = {}
	gear_out(a)
	data.active = a
	save()
	return a


# a queued big ship (one tug, G6): the offer is held and comes back on the next market, ready
static func hold(i: int) -> bool:
	var offers: Array = data.get("offers", [])
	if i < 0 or i >= offers.size() or not offers[i].get("queued", false) or not data.get("held", {}).is_empty():
		return false
	var o: Dictionary = offers[i].duplicate(true)
	o.erase("queued")
	o.held = true
	data.held = o
	offers.remove_at(i)
	data.offers = offers
	save()
	return true


static func accept(i: int) -> Dictionary:
	var offers: Array = data.get("offers", [])
	if i < 0 or i >= offers.size() or not active().is_empty() or offers[i].get("queued", false):
		return {}
	var o: Dictionary = offers[i].duplicate(true)
	var fee: float = o.get("fee", 0.0)
	var short := maxf(0.0, fee - float(data.money))
	data.money = float(data.money) - fee + short
	data.loan = float(data.loan) + short
	if short > 0.0:
		data.in_debt = true
	o.fee_paid = true
	o.borrowed = short
	# the berth goes to work with what it owns at signing
	o.kit = data.get("upgrades", {}).duplicate()
	o.items = data.get("items", {}).duplicate()
	o.notes = data.get("archive", {}).get(o.get("ship", ""), {}).duplicate(true)
	# what was bought at the terminal since the last contract goes on this one's log
	o.desk = data.get("desk", {}).duplicate()
	data.desk = {}
	gear_out(o)
	data.active = o
	data.offers = []
	save()
	return o


# ---------------------------------------------------------------- field gear (scripts/gear.gd, G1)

# The contract in hand takes the saved loadout out of the warehouse, as far as
# the shelf and the slots allow, plus whatever the contract lends. Out now,
# back at settlement (what came back).
static func gear_out(job: Dictionary) -> void:
	if job.is_empty():
		return
	# Basic tools no longer carry consumable parts. Legacy snapshots remain
	# readable through Consum's retired compatibility adapter.
	if job.has("gear"):
		return
	var ld: Dictionary = data.get("loadout", {})
	var r := _fit_loadout(ld.get("mods", []), ld.get("deploy", {}))
	job.gear = {"mods": r.mods, "deploy": r.deploy, "lent": job.get("lend", {}).duplicate()}
	_warehouse_take(job.gear)


# a wanted configuration cut down to the shelf and the slots
static func _fit_loadout(mods_in: Array, deploy_in: Dictionary) -> Dictionary:
	var stock: Dictionary = data.get("gear", {}).duplicate()
	var mods: Array = []
	for m in mods_in:
		var t := str(m)
		if Gear.is_mod(t) and int(stock.get(t, 0)) > 0 and mods.size() < Gear.MOD_SLOTS:
			mods.append(t)
			stock[t] = int(stock[t]) - 1
	var slots := Gear.deploy_slots(mods)
	var deploy := {}
	var n := 0
	for t in deploy_in:
		var ts := str(t)
		var can := mini(int(deploy_in[t]), int(stock.get(ts, 0)))
		can = mini(can, slots - n)
		if Gear.is_deploy(ts) and can > 0:
			deploy[ts] = can
			n += can
			stock[ts] = int(stock[ts]) - can
	return {"mods": mods, "deploy": deploy}


static func _warehouse_take(g: Dictionary) -> void:
	var w: Dictionary = data.get("gear", {})
	for m in g.get("mods", []):
		w[m] = int(w.get(m, 0)) - 1
	for t in g.get("deploy", {}):
		w[t] = int(w.get(t, 0)) - int(g.deploy[t])
	data.gear = w


static func _warehouse_back(g: Dictionary) -> void:
	var w: Dictionary = data.get("gear", {})
	for m in g.get("mods", []):
		w[m] = int(w.get(m, 0)) + 1
	for t in g.get("deploy", {}):
		w[t] = int(w.get(t, 0)) + int(g.deploy[t])
	data.gear = w


# G5.1 (19 号): the contract in hand keeps its structural scrap as company raw material
# instead of selling it at the furnace mouth. The whole job, chosen on the loadout page.
# The contract pays for the salvage rate; the scrap's cash was ours to give up.
# 64 号 (60 号 Q5 A): the furnace's scrap is cast into ingots for the warehouse, never cash
static var INGOTS := true   # tests of the older feed chain switch it off


static func can_retain(a: Dictionary) -> bool:
	if INGOTS:
		return false
	return not a.is_empty() and data.get("market", false) and str(a.get("scope", "full")) != "rescue" and str(a.get("id", "")) != ""


static func retaining() -> bool:
	return preload("res://scripts/material_batches.gd").retains(active())


# no save here: the loadout page saves with the configuration (set_loadout)
static func set_retain(on: bool) -> void:
	var a: Dictionary = active()
	if not can_retain(a):
		return
	if on:
		a.material_policy = {"version": 1, "metal": "retain", "owner": "company", "asset_id": str(a.id)}
	else:
		a.erase("material_policy")
	data.active = a


# the loadout page: this configuration is the one taken out (the contract in hand, if
# there is one, gives back what it took first). Nothing is spent on a failed write.
static func set_loadout(mods: Array, deploy: Dictionary) -> String:
	var before := data.duplicate(true)
	var a: Dictionary = active()
	if not a.is_empty() and a.has("gear"):
		_warehouse_back(a.gear)
	var r := _fit_loadout(mods, deploy)
	data.loadout = {"mods": r.mods.duplicate(), "deploy": r.deploy.duplicate()}
	if not a.is_empty():
		a.gear = {"mods": r.mods, "deploy": r.deploy, "lent": a.get("lend", {}).duplicate()}
		_warehouse_take(a.gear)
		data.active = a
	if not save():
		data = before
		return Txt.t("gr_save_failed")
	return ""


# the books of a contract's gear: what came back goes on the shelf, what was lost is
# priced, a first achievement opens its type and puts one unit on the shelf
static func _settle_gear(a: Dictionary, gr: Dictionary) -> Dictionary:
	var w: Dictionary = data.get("gear", {})
	var back: Array = []
	var lost: Array = []
	var lent_lost: Array = []
	var lost_cost := 0.0
	for it in gr.get("back", []):
		if not it.lent:
			w[it.type] = int(w.get(it.type, 0)) + 1
			back.append(it.type)
	for it in gr.get("lost", []):
		if it.lent:
			lent_lost.append(it.type)
		else:
			lost.append(it.type)
			lost_cost += Gear.price(it.type)
	var feats: Dictionary = data.get("feats", {})
	var feats_new: Array = []
	var grants: Array = []
	for f in gr.get("feats", {}):
		if feats.has(f):
			continue
		feats[f] = {"ship": a.get("ship", ""), "job": a.get("id", ""), "at": int(data.get("done", 0)), "measure": float(gr.feats[f])}
		feats_new.append(f)
		var g: String = Gear.FEAT_GRANT.get(f, "")
		if g != "":
			w[g] = int(w.get(g, 0)) + 1
			grants.append(g)
	data.feats = feats
	data.gear = w
	return {"back": back, "lost": lost, "lent_lost": lent_lost, "lost_cost": lost_cost, "feats": feats_new, "grants": grants}


# ---------------------------------------------------------------- the trial contracts (G1)

# Fixed jobs on the training page, taken as often as the player likes: the ship, a
# fixed set of traps and what the berth lends for it. Drawn from a fixed seed, the
# first draw past the contract validator.
const TRIALS := {
	"g1a": {"ship": "s09", "seed": 910001, "traps": null, "lend": {}, "repair": "lights"},
	"g1b": {"ship": "gr7", "seed": 920001, "traps": [], "lend": {"anchor": 1}, "repair": "net_fix"},
	"g1c": {"ship": "gr7", "seed": 930001, "traps": ["wrong_valve"], "lend": {"pump": 1}, "repair": "furnace_main"},
}


static func trial_offer(id: String) -> Dictionary:
	var spec: Dictionary = TRIALS.get(id, {})
	if spec.is_empty():
		return {}
	var o := fixed_offer(str(spec.ship), int(spec.seed), spec.traps)
	if o.is_empty():
		return {}
	o.fee = snappedf(float(o.value) * 0.12, 500.0)
	o.id = "%s-%03d" % [id.to_upper(), int(data.get("trials", {}).get(id, 0)) + 1]
	o.trial = id
	o.lend = (spec.lend as Dictionary).duplicate()
	o.repair = str(spec.get("repair", ""))
	o.intro = "L_trial_%s_in" % id     # Liang's lines as it comes in: L_trial_g1a_in_1..3 (the author's)
	return o


# a fixed full job on a ship type from a fixed seed (traps: null = as drawn), the first draw past
# the contract validator; trials and the borrow jobs (scripts/methods.gd) are made from it
static func fixed_offer(ship: String, seed: int, traps = null) -> Dictionary:
	var base := Ship.load_data(ship)
	for k in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + k
		var o := Market.offer(rng, data, 1, {}, "full", ship)
		o.erase("_ship")
		o.goal = ""
		o.time = snappedf(Market.base_time(ship), 30.0)
		if traps != null:
			o.traps = (traps as Array).duplicate()
		var d := Variant.make(base, o)
		if not ContractValidator.check(d).ok:
			continue
		o.value = snappedf(float(d.value.total), 100.0)
		o.named = Market._named(d)
		o.logs = Market._logs(rng, o.traps)
		var cargo: Array = []
		for c in Variant.containers(d):
			if Variant.piece(d, c) != null:
				cargo.append([c, d.labels.get(c, "")])
		o.cargo = cargo
		return o
	return {}


# take a trial: like accepting an offer, with the lent gear on top of the loadout
static func take_trial(id: String) -> Dictionary:
	if not active().is_empty():
		return {}
	return take_fixed(trial_offer(id))


# take a fixed job (a trial, a borrow job): like accepting an offer, the lent gear on top of the loadout
static func take_fixed(o: Dictionary) -> Dictionary:
	if o.is_empty() or not active().is_empty():
		return {}
	var fee: float = o.get("fee", 0.0)
	var short := maxf(0.0, fee - float(data.money))
	data.money = float(data.money) - fee + short
	data.loan = float(data.loan) + short
	if short > 0.0:
		data.in_debt = true
	o.fee_paid = true
	o.borrowed = short
	o.kit = data.get("upgrades", {}).duplicate()
	o.items = data.get("items", {}).duplicate()
	o.notes = data.get("archive", {}).get(o.get("ship", ""), {}).duplicate(true)
	o.desk = data.get("desk", {}).duplicate()
	data.desk = {}
	gear_out(o)
	data.active = o
	data.offers = []
	save()
	return o


# ---------------------------------------------------------------- the engineering archive

# what was checked by hand on a ship goes into the type's notes (newest wins)
static func file_notes(ship: String, verified: Dictionary) -> void:
	var arch: Dictionary = data.get("archive", {})
	var n: Dictionary = arch.get(ship, {"pieces": {}, "ports": {}, "lines": {}, "ctrls": {}, "ships": 0})
	for k in ["pieces", "ports", "lines", "ctrls"]:
		var into: Dictionary = n.get(k, {})
		for id in verified.get(k, {}):
			into[id] = verified[k][id]
		n[k] = into
	n.ships = int(n.get("ships", 0)) + 1
	arch[ship] = n
	data.archive = arch


# ---------------------------------------------------------------- the books

# the time bonus: +20% of a positive net profit within the standard time,
# falling off in a straight line to nothing at twice the standard time
static func time_bonus(net: float, secs: float, standard: float, share: float = BONUS) -> float:
	if standard <= 0.0 or net <= 0.0:
		return 0.0
	return snappedf(net * share * clampf((2.0 * standard - secs) / standard, 0.0, 1.0), 1.0)


# pay off part of the loan from funds now; returns what was paid
static func repay(amount: float) -> float:
	var pay := minf(amount, minf(float(data.money), float(data.loan)))
	if pay <= 0.0:
		return 0.0
	data.money = float(data.money) - pay
	data.loan = float(data.loan) - pay
	_paid_off()
	save()
	return pay


# the loan is gone: BERTH 07 is the operator's (once; later ship types hang on this)
# (only a debt that was really run up: a career that never owed anything has nothing to clear)
static func _paid_off() -> bool:
	if float(data.loan) > 0.5 or not data.get("in_debt", false):
		return false
	data.in_debt = false
	data.loan = 0.0
	if data.get("paid_off", false):
		return false
	data.paid_off = true
	data.paid_off_at = int(data.get("done", 0))
	return true


# the i-th opening contract, ready to play ({} past the last)
static func opening(i: int) -> Dictionary:
	if i < 0 or i >= OPENING.size():
		return {}
	var o: Dictionary = OPENING[i].duplicate(true)
	o.opening = i
	o.fee_paid = false
	return o


# where a contract sits in the opening (by id: a career saved before the tug and
# the Swift were added has GR-001 as its opening 0), -1 when it is a market job
static func opening_index(job: Dictionary) -> int:
	if not job.has("opening"):
		return -1
	for i in OPENING.size():
		if OPENING[i].id == job.get("id", ""):
			return i
	return int(job.opening)


# A short job on part of a ship carries the installment and interest in
# proportion to its standard time against a full contract's (never under 30%).
static func due_share(job: Dictionary) -> float:
	if job.get("scope", "full") == "full":
		return 1.0
	return clampf(float(job.get("time", Market.BASE_TIME)) / Market.BASE_TIME, 0.3, 1.0)


# what a contract would take for the loan at settlement, at today's loan
static func due_for(job: Dictionary) -> float:
	var loan := float(data.get("loan", 0.0))
	var k := due_share(job)
	return minf(INSTALLMENT * k, loan) + snappedf(loan * rate() * k, 1.0)


# A contract is over. r: {earned, losses, rate, grade, time, fee, bonus}. Returns
# what the settlement shows.
static func settle(r: Dictionary) -> Dictionary:
	var a: Dictionary = active()
	var job_id := str(r.get("job_id", a.get("id", "")))
	# A report for another live contract must not commit under a fresh cache key.
	# An empty active contract may still recover its already-settled result below.
	if str(a.get("id", "")) != "" and job_id != str(a.id):
		return {"save_failed":true, "reason":"settlement_job_mismatch"}
	var settled: Dictionary = data.get("settled_jobs", {})
	if job_id != "" and settled.has(job_id):
		var cached: Dictionary = settled[job_id].duplicate(true)
		cached.already_settled = true
		return cached
	var before := data
	data = before.duplicate(true)
	var material_result: Dictionary = preload("res://scripts/material_batches.gd").apply_report(data, a, r.get("material_receipts", []))
	if not material_result.ok:
		data = before
		return {"save_failed":true, "reason":material_result.get("reason", "material_receipt")}
	var fee: float = r.get("fee", a.get("fee", 0.0))
	var prepaid: bool = a.get("fee_paid", false)
	var bonus: float = float(r.get("bonus", 0.0))
	# the port (G6): the trade port sells better, the tug station spares the towing fee
	var trade_bonus := snappedf(float(r.get("earned", 0.0)) * (Port.trade_k() - 1.0), 1.0)
	var tow := Port.tow_fee() if a.get("scope", "full") == "full" else 0.0
	# 80 号 Q2: a tow taken on credit comes out of the next settlement
	var tow_owed := float(data.get("tow_owed", 0.0))
	data.tow_owed = 0.0
	var gross: float = float(r.get("earned", 0.0)) - float(r.get("losses", 0.0)) + bonus + trade_bonus - tow - tow_owed
	# the parts shelved for the berth's repairs are worth money, but it is not cash now
	var parts_value := float(r.get("parts_value", 0.0))
	# 64 号: the scrap the furnace took is ingots in the warehouse, not cash
	# 108 号: a hopper's ore is paid in cash; only the structure's scrap is cast into ingots
	var ingot_value := maxf(0.0, float(r.get("ingot_value", 0.0)) - float(r.get("ore_value", 0.0))) if INGOTS else 0.0
	var ingot_t := float(r.get("ingot_t", 0.0)) if INGOTS else 0.0
	# 108 号: the first machine bought on the spot is in the account already
	var spot_paid := float(r.get("spot_paid", 0.0))
	var money_in := gross - parts_value - ingot_value - spot_paid - (0.0 if prepaid else fee)
	data.roll_from = {"money": float(data.money), "loan": float(data.loan)}
	var cash: float = float(data.money) + money_in
	# the loan: a fixed installment and interest on what is still owed (a short job's share of them)
	var loan: float = float(data.loan)
	var share := due_share(a)
	var interest := snappedf(loan * rate() * share, 1.0) if loan > 0.0 else 0.0
	var inst := minf(INSTALLMENT * share, loan)
	var due := inst + interest
	var paid := minf(due, maxf(cash, 0.0))
	var short := due - paid
	cash -= paid
	loan = loan - inst + short
	if cash < 0.0:
		# a loss bigger than the cash goes onto the loan too
		loan += -cash
		short += -cash
		cash = 0.0
	var rep_before: String = level()
	var grade: int = int(r.get("grade", 0))
	data.rep = maxi(0, int(data.rep) + REP_GAIN[clampi(grade, 0, 3)])
	data.money = cash
	data.loan = maxf(0.0, loan)
	if float(data.loan) > 0.5:
		data.in_debt = true
	data.done = int(data.done) + 1
	# 76 号: the gas the hoses took comes home as a batch of known mixed gas
	if not r.get("gas_take", {}).is_empty():
		GasLine.receive(r.gas_take, job_id)
	# 108 号: the pump's second tier brought single-gas tanks home in their own bottles
	for v in r.get("gas_tanks", {}):
		GasLine.receive(r.gas_tanks[v], "%s · %s" % [job_id, v])
	if ingot_t > 0.0005:
		var ib: Array = data.get("ingot_batches", [])
		ib.append({"id": "ingot:" + job_id, "job_id": job_id, "ship": str(a.get("ship", "")), "mass_t": snappedf(ingot_t, 0.001), "value": ingot_value})
		data.ingot_batches = ib
		if not data.get("exchange", {}).is_empty():
			preload("res://scripts/industrial_exchange.gd").import_ingots(data.exchange, ib)
	# 开局第一关过了：白送一台初级搬运无人机（一副生涯只送这一次）
	var granted: Array = []
	if GIFT_HAULER_AFTER > 0 and int(data.done) == GIFT_HAULER_AFTER and not data.get("upgrades", {}).has(GIFT_HAULER):
		var up: Dictionary = data.get("upgrades", {})
		up[GIFT_HAULER] = 1
		data.upgrades = up
		data.first_gift = true
		granted.append(GIFT_HAULER)
	# consumables used on the contract come out of stock
	var used: Dictionary = r.get("used", {})
	for k in used:
		data.items[k] = maxi(0, int(data.items.get(k, 0)) - int(used[k]))
	# the field gear: back on the shelf, lost, achieved (scripts/gear.gd)
	var gear_res := _settle_gear(a, r.get("gear", {}))
	var first_gear_loss: bool = not gear_res.get("lost",[]).is_empty() and not data.get("seen",{}).get("gear_lost",false)
	if first_gear_loss:
		var seen: Dictionary = data.get("seen",{})
		seen.gear_lost = true
		data.seen = seen
	# the parts for the berth (scripts/repair.gd): onto the shelf, the structure by the tonne
	var parts_res := _settle_parts(r)
	# 106 号: what is still to be decided on the settlement's second page (sold or kept)
	Disposal.open_for(job_id, str(a.get("ship", "")), ingot_t, ingot_value, r.get("parts", []))
	var order_result: Dictionary = load("res://scripts/work_orders.gd").apply_report(a,r.get("work_order",{}))
	# 104 号: a borrow job done, or an achievement, teaches a dismantling method
	var learned: Array = Methods.settle(a, r, grade, gear_res.get("feats", []), order_result)
	# the cargo district restocks the consumables' shelf (G6)
	var restocked: Array = Consum.restock()
	if a.has("trial"):
		var tr: Dictionary = data.get("trials", {})
		tr[a.trial] = int(tr.get(a.trial, 0)) + 1
		data.trials = tr
	# 108 号 Q6 A: a showcase job says what the method did, against the same type stripped before
	# (the last time without it) or the job's standard time and the broker's value
	var showcase := {}
	if str(a.get("showcase", "")) != "":
		var sid := str(a.showcase)
		showcase = {"id": sid, "use": Methods.use_text(sid, r.get("uses", {})), "time": float(r.get("time", 0.0)), "net": gross - fee}
		for h in data.get("history", []).duplicate():
			if str(h.get("ship", "")) == str(a.get("ship", "")):
				showcase.before = {"time": float(h.get("time", 0.0)), "net": float(h.get("net", 0.0))}
		showcase.std_time = float(a.get("time", 0.0))
		showcase.value = float(a.get("value", 0.0))
		var shc: Dictionary = data.get("showcases", {})
		shc[sid] = "done"
		data.showcases = shc
	data.history.append({"id": a.get("id", "?"), "ship": a.get("ship", "gr7"), "net": gross - fee, "rate": r.get("rate", 0.0),
		"grade": grade, "time": r.get("time", 0.0), "stars": a.get("stars", 0), "bonus": bonus, "loan": data.loan, "ops": r.get("ops", {}),
		"goal": a.get("goal", ""), "scope": a.get("scope", "full"), "bonuses": r.get("bonuses", []), "incidents": r.get("incidents", []), "time_by": r.get("time_by", {})})
	# the opening contracts follow one another, but the market opens after the
	# first (player 2026-10-17: "after a contract I can't pick a ship any more"):
	# the next one waits on it as a pinned story card, taken when the player likes
	var oi := opening_index(a)
	if oi >= 0:
		data.story_job = opening(oi + 1) if oi + 1 < OPENING.size() else {}
	data.active = {}
	# the core's heart was cut (scripts/nuke.gd): the berth is built again before the next contract
	if r.get("nuke", false):
		data.berth_rebuild = true
	# 30 号 Q25: the works ran on while the ship was stripped — the play time, made good
	# when the berth is next in view (scripts/process_plant.gd catch_up)
	data.plant_owed_s = minf(7200.0, float(data.get("plant_owed_s", 0.0)) + float(r.get("time", 0.0)))
	data.market = true
	data.offers = []
	var paid_off := _paid_off()
	var result := {"installment": inst, "interest": interest, "paid": paid, "gross": gross, "prepaid": prepaid, "fee": fee, "bonus": bonus,
		"short": short, "money": float(data.money), "loan": data.loan, "level_up": level() != rep_before, "level": level(), "paid_off": paid_off, "used": used, "granted": granted,"materials":material_result,"work_order":order_result,
		"gear": gear_res, "gear_first_lost":first_gear_loss, "parts": parts_res, "suggest": Repair.suggestion(), "trade_bonus": trade_bonus, "tow": tow, "tow_owed": tow_owed, "spot_paid": spot_paid, "showcase": showcase, "restock": restocked,
		"retained_value": preload("res://scripts/material_batches.gd").recovery_value(r.get("material_receipts", [])),
		"ingot_t": ingot_t, "ingot_value": ingot_value, "learned": learned}
	if job_id != "":
		var completed: Dictionary = data.get("settled_jobs", {})
		completed[job_id] = result.duplicate(true)
		data.settled_jobs = completed
	if not save():
		data = before
		return {"save_failed":true}
	return result


static func _settle_parts(r: Dictionary) -> Dictionary:
	var shelf: Array = data.get("parts", [])
	var tags: Array = []
	for part in r.get("parts", []):
		shelf.append(part)
		tags.append(str(part.tag))
	data.parts = shelf
	var tons := float(r.get("structure_t", 0.0))
	data.structure_t = float(data.get("structure_t", 0.0)) + tons
	return {"tags": tags, "value": float(r.get("parts_value", 0.0)), "tons": tons}


static func ensure_offers(make: Callable) -> void:
	if not data.get("offers", []).is_empty() or not active().is_empty():
		return
	data.seed = int(data.get("seed", 0)) + 1
	data.offers = make.call(int(data.seed), data)
	# a held big ship takes the last card, its queue done
	var held: Dictionary = data.get("held", {})
	if not held.is_empty():
		data.held = {}
		if data.offers.is_empty():
			data.offers.append(held)
		else:
			data.offers[data.offers.size() - 1] = held
	save()
