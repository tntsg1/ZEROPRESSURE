extends "res://tests/guide_check.gd"
# 106 号: the settlement's second page. A settled job leaves its ingots and whole equipment to be
# decided; nothing is sold before the page is confirmed; the ingots as one batch (sold: the
# furnace's cash, out of the warehouse; kept: queued for processing with their ship); each part
# sold or kept (the default keeps what an unfinished repair would use); the metal choice is the
# next page's default; the page builds, shows the defaults and confirms.
#   godot --headless --fixed-fps 60 -s tests/disposal_check.gd
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_disposal_career.json"
	SaveGame.path = "user://zp_test_disposal_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _part(uid: String, cls: String, cond: float, value: float) -> Dictionary:
	return {"uid": uid, "cls": cls, "tag": uid.to_upper(), "nk": "p_motor", "cond": cond, "value": value, "ship": "gr7", "job": "DSP-1"}


func _stock() -> float:
	return float(Career.data.exchange.actors.company.stock.get(Ex.INGOT, 0.0))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 100000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	check(Ex.command("view").ok, "the exchange is open")
	# ---- a settlement leaves the choices open and sells nothing
	Career.data.active = {"id": "DSP-1", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	var good := _part("dsp_a", "drive", 0.9, 20000.0)
	var worn := _part("dsp_b", "power", 0.4, 5000.0)
	var stock0 := _stock()
	Career.settle({"job_id": "DSP-1", "earned": 30000.0, "grade": 2, "ingot_value": 1500.0, "ingot_t": 12.0, "parts": [good, worn], "parts_value": 25000.0})
	var d := Disposal.pending()
	check(not d.is_empty() and absf(float(d.ingot_t) - 12.0) < 0.001 and d.uids.size() == 2 and str(d.ship) == "gr7", "the settlement leaves 12 t and 2 parts to decide (%s)" % str(d))
	check(absf(_stock() - stock0 - 12.0) < 0.01 and Disposal.parts().size() == 2, "until confirmed everything is in the warehouse and on the rack")
	check(str(Career.data.exchange.actors.company.lots.get("ingot:DSP-1", {}).get("ship", "")) == "gr7", "the ingot lot knows its ship")
	check(Disposal.metal_default() == "keep", "a first page starts on keeping the metal")
	var want := Disposal.wanted()
	check(Disposal.part_default(good, want) == "keep" and want.has("dsp_a"), "a drive part a repair still needs is kept by default (%s)" % Disposal.part_note(good, want))
	check(Disposal.part_default(worn, want) == "sell" and Disposal.part_note(worn, want).find("成色") >= 0, "a worn part no repair can use is sold by default (%s)" % Disposal.part_note(worn, want))
	var kv := Disposal.keep_value(d)
	check(float(kv.value) > Disposal.sell_cash(d) and float(kv.power) > 0.0 and float(kv.power) < float(kv.value), "processing is worth more than selling, less its power (%s / %s, power %s)" % [Pal.money(float(kv.value)), Pal.money(Disposal.sell_cash(d)), Pal.money(float(kv.power))])
	# ---- the page
	await _spawn()
	g.open_disposal()
	await _frames(5)
	var p = g.disposal_ui
	check(p != null and p.metal == "keep" and p.sell.get("dsp_b", false) and not p.sell.get("dsp_a", true), "the page opens on the defaults")
	check(absf(p.cash_now() - Repair.part_worth(worn)) < 1.0, "cash now: the worn part only (%s)" % Pal.money(p.cash_now()))
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.pressed = true
	p._unhandled_input(ev)
	check(p.metal == "sell" and absf(p.cash_now() - Disposal.sell_cash(d) - Repair.part_worth(worn)) < 1.0, "1 picks selling the metal, and the sum follows")
	p._part("dsp_b", false)
	check(absf(p.cash_now() - Disposal.sell_cash(d)) < 1.0, "a part switched to keep leaves the sum")
	p._part("dsp_b", true)
	var done := [false]
	p.on_done = func(): done[0] = true
	var cash0 := float(Career.data.money)
	var stock1 := _stock()
	p.confirm()
	check(done[0] and Disposal.pending().is_empty(), "confirmed and closed")
	check(absf(float(Career.data.money) - cash0 - Disposal.sell_cash(d) - Repair.part_worth(worn)) < 1.0, "paid the ingots' price (108 号: $300 a tonne) and the worn part (%s)" % Pal.money(float(Career.data.money) - cash0))
	check(absf(stock1 - _stock() - 12.0) < 0.01 and not Career.data.exchange.actors.company.lots.has("ingot:DSP-1"), "the sold ingots left the warehouse")
	var ids: Array = []
	for b in Career.data.get("ingot_batches", []):
		ids.append(str(b.id))
	check(not "ingot:DSP-1" in ids, "and the ingot books")
	var uids: Array = []
	for part in Career.data.parts:
		uids.append(str(part.uid))
	check("dsp_a" in uids and not "dsp_b" in uids, "the kept part is on the rack, the sold one gone")
	check(Disposal.metal_default() == "sell", "the choice is remembered for the next page")
	var saved := FileAccess.get_file_as_string(Career.path)
	check(saved.find("\"disposal_metal\": \"sell\"") >= 0 or saved.find("\"disposal_metal\":\"sell\"") >= 0, "and saved")
	# ---- a second contract: kept to be processed
	Career.data.active = {"id": "DSP-2", "ship": "m14", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "DSP-2", "earned": 10000.0, "grade": 1, "ingot_value": 700.0, "ingot_t": 5.0})
	cash0 = float(Career.data.money)
	var r := Disposal.apply("keep", [])
	var q := ProcessQueue.entries()
	check(r.ok and absf(float(Career.data.money) - cash0) < 0.5, "keeping pays nothing now")
	check(q.size() == 1 and str(q[0].ship) == "m14" and absf(float(q[0].t) - 5.0) < 0.001 and str(q[0].lot) == "ingot:DSP-2", "the batch is queued for processing with its ship (%s)" % str(q))
	check(ProcessQueue.tag(q[0]).begins_with("M-14") or ProcessQueue.tag(q[0]).find("5.0 t") >= 0, "its label: %s" % ProcessQueue.tag(q[0]))
	check(Career.data.exchange.actors.company.lots.has("ingot:DSP-2"), "the kept ingots stay the company's lot")
	check(not Disposal.apply("sell", []).ok, "a page is decided once")
	# ---- nothing to decide: no page
	Career.data.active = {"id": "DSP-3", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "DSP-3", "earned": 1000.0, "grade": 1})
	check(Disposal.pending().is_empty(), "a job with no ingots and no parts leaves nothing to decide")
	print("DISPOSAL CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
