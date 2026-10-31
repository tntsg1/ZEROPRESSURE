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
		return {"ok": false, "reason": w("存档失败，训练任务未能发放，请重试。", "SAVE FAILED. TRAINING ORDER COULD NOT BE ISSUED. PLEASE TRY AGAIN.")}
	return {"ok": true}


# the terminal's pinned decision: what to do next, and where it leads
static func step() -> Dictionary:
	if Port.stage("process") < 1:
		return {"text": w("训练任务：先将加工区修复至 1 级，恢复工业熔炉和材料分选线的运行。", "TRAINING ORDER: RESTORE THE PROCESSING DISTRICT TO LEVEL 1 AND BRING THE INDUSTRIAL FURNACE AND SORTING LINE BACK ONLINE."), "go": "guide:build:process"}
	if not granted():
		return {"text": w("训练任务：港务局已提供 1 吨混合废金属供你加工。本次训练的电费和材料检测费由港务局承担。", "TRAINING ORDER: THE PORT AUTHORITY HAS PROVIDED 1 TONNE OF MIXED SCRAP METAL FOR PROCESSING. ELECTRICITY AND MATERIAL ASSAY COSTS ARE COVERED FOR THIS TRAINING RUN."), "go": "drill"}
	var t := Guide.first_for_clients()
	var txt := {"clients": w("训练任务：将加工完成的钢坯交付工业客户，完成本次订单。", "TRAINING ORDER: DELIVER THE FINISHED STEEL BILLETS TO THE INDUSTRIAL CLIENT TO COMPLETE THE ORDER."), "heat": w("训练任务：前往工业炉台，将处理好的金属炉料熔炼成钢坯。", "TRAINING ORDER: HEAD TO THE INDUSTRIAL FURNACE AND SMELT THE PREPARED METAL FEED INTO STEEL BILLETS."),
		"assay": w("训练任务：前往材料化验台，检测炉料成分并确认材料等级。", "TRAINING ORDER: TAKE THE METAL FEED TO THE ASSAY STATION TO ANALYZE ITS COMPOSITION AND DETERMINE ITS GRADE."), "sort": w("训练任务：前往材料分选台，选择「整线加工」，将这批金属送入分选线处理。", "TRAINING ORDER: GO TO THE SORTING STATION AND SELECT \"PROCESS FULL BATCH\" TO RUN THE METAL THROUGH THE SORTING LINE."),
		"buy_feed": w("训练任务：前往材料分选台，将提供的 1 吨混合废金属完成分选。", "TRAINING ORDER: GO TO THE SORTING STATION AND SORT THE 1 TONNE OF MIXED SCRAP METAL PROVIDED BY THE PORT AUTHORITY.")}
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
