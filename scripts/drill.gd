class_name Drill
# The port authority's subsidised training run (design/…/28 Q2/Q9/Q10/Q14/Q15, 30 号): once the
# market is open, a tonne of mixed metal on the house, its power and its assay free, taken
# through sorting → assay → the furnace → an industrial client on the real works with the
# guide all the way; the client's money is the player's. Pinned first among the terminal's
# decisions until done, and the other production items wait behind it.

const Exchange = preload("res://scripts/industrial_exchange.gd")
const LOT := "DRILL-1"
const TONNES := 1.0
const SHARE := 0.10           # the grant's non-magnetic share: one pass of the separator clears it


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func _d() -> Dictionary:
	return Career.data.get("drill", {})


# "" (not yet: before the market), "open" (offered or under way), "done"
static func state() -> String:
	var d := Career.data
	if not d.get("market", false):
		return ""
	# a career begun before the new-player run (no staged terminal): it has been through the old way
	if not Onboarding.tracked():
		return "done"
	# through once billets have reached a client (and an old career that already sold
	# billets has no use for it)
	if _d().get("done", false) or Mainline._billet_sold():
		return "done"
	return "open"


static func open() -> bool:
	return state() == "open"


static func granted() -> bool:
	return _d().get("granted", false)


# a batch begun now is the drill's: its power is on the port authority
static func active() -> bool:
	return open() and granted()


# the tonne handed over: a receipt in the company's own name, in the warehouse's stock
static func grant() -> Dictionary:
	if not open() or granted():
		return {"ok": false, "reason": "already"}
	var viewed := Exchange.command("view")
	if not viewed.ok:
		return viewed
	var before := Career.data
	Career.data = before.duplicate(true)
	var receipt := {"id": LOT, "mass_t": TONNES, "material": "ungraded_scrap", "grade": 0, "state": "raw_received", "storage": "exchange",
		"material_profile": {"version": 1, "nonmagnetic_share": SHARE, "basis": "port_authority_grant"}, "origin": "port_authority_grant"}
	var batches: Array = Career.data.get("material_batches", [])
	batches.append(receipt)
	Career.data.material_batches = batches
	Exchange.import_received(Career.data.exchange, [receipt])
	Exchange.sync_batches(Career.data, Career.data.exchange)
	Career.data.drill = {"granted": true, "done": false}
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，训练单未发放", "SAVE FAILED, NOTHING HANDED OVER")}
	return {"ok": true}


# the terminal's pinned decision: what to do next, and where it leads
static func step() -> Dictionary:
	if Port.stage("process") < 1:
		return {"text": w("训练单：先把加工区修到 1 阶，公司炉和分选线在那里", "TRAINING RUN: MEND THE PROCESSING DISTRICT FIRST"), "go": "guide:build:process"}
	if not granted():
		return {"text": w("训练单：港务局送 1 t 未分选金属，电费、化验费全免", "TRAINING RUN: 1 t OF MIXED METAL ON THE PORT, POWER AND ASSAY FREE"), "go": "drill"}
	var t := Guide.first_for_clients()
	var txt := {"clients": w("训练单：把钢坯交给工业客户", "TRAINING RUN: SHIP THE BILLETS"), "heat": w("训练单：到炉台炼钢坯", "TRAINING RUN: MELT THE FEED"),
		"assay": w("训练单：到化验位给炉料定级", "TRAINING RUN: GRADE THE FEED"), "sort": w("训练单：到分选台按『整线加工』", "TRAINING RUN: RUN THE LINE ON THE TONNE"),
		"buy_feed": w("训练单：到分选台分选那 1 t", "TRAINING RUN: SORT THE TONNE")}
	return {"text": str(txt.get(t, "")), "go": "guide:" + ("sort" if t == "buy_feed" else t)}


# the decision's click: hand the tonne over first, then the guide takes it from there
static func take(game) -> String:
	var st := step()
	var go := str(st.go)
	if go == "drill":
		var r := grant()
		if not r.ok:
			return str(r.get("reason", ""))
		go = str(step().go)
	Mainline.take_me(game, go)
	return ""
