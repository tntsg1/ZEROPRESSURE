extends "res://tests/guide_check.gd"
# 106 号: the ingots a settlement kept are processed by the district on its own. A kept batch is
# queued with its ship; at the berth the arc furnace takes that lot (not another) a heat at a time,
# starts and taps it unattended, the billet is received and booked to the batch; the next heat
# follows; the mill rolls the batch's billet into plate by itself. Own test saves only.
#   godot --headless --fixed-fps 60 -s tests/process_queue_check.gd
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_pqueue_career.json"
	SaveGame.path = "user://zp_test_pqueue_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _heat() -> Dictionary:
	return Career.data.get("industrial_heat", {})


func _until(cond: Callable, limit: int) -> bool:
	for i in limit:
		await _frames(1)
		if cond.call():
			return true
		if i % 6000 == 5999:
			print("  … waiting: heat %s %s · %s" % [str(_heat().get("state", "")), str(_heat().get("quantity", "")), g.industrial_heat.waiting])
	return false


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 2, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	check(Ex.command("view").ok, "the exchange is open")
	# somebody else's ingots in the warehouse first: the queue must take its own lot
	Career.data.active = {"id": "PQ-0", "ship": "s09", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "PQ-0", "earned": 1000.0, "grade": 1, "ingot_value": 300.0, "ingot_t": 2.5})
	Disposal.apply("keep", [])
	Career.data.process_queue = []          # kept, but not queued: like ingots of an older save
	Career.data.active = {"id": "PQ-1", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "PQ-1", "earned": 5000.0, "grade": 2, "ingot_value": 400.0, "ingot_t": 3.0})
	check(Disposal.apply("keep", []).ok and ProcessQueue.entries().size() == 1, "3 t of GR-7 ingots queued")
	await _spawn()
	check(await _until(func(): return str(_heat().get("queue", "")) == "ingot:PQ-1", 600), "the furnace takes the queued batch by itself")
	var h := _heat()
	check(bool(h.get("through", false)) and str(h.get("ship", "")) == "gr7" and is_equal_approx(float(h.quantity), 2.0), "a 2 t heat that starts itself, labelled GR-7")
	check(h.source_lots.size() == 1 and str(h.source_lots[0].source_id) == "ingot:PQ-1", "from the GR-7 lot, not the older ingots (%s)" % str(h.source_lots))
	check(is_equal_approx(float(ProcessQueue.entries()[0].melted), 2.0), "the queue counts 2 t charged")
	check(await _until(func(): return str(_heat().get("state", "")) == "processing", 40000), "the batch reaches the furnace")
	check(await _until(func(): return str(_heat().get("state", "")) == "complete", 90000), "melted, tapped and received without anyone at the desk")
	var e: Dictionary = ProcessQueue.entries()[0]
	check(is_equal_approx(float(e.get("billet", 0.0)), 2.0), "2 t of billet booked to the GR-7 batch (%s)" % str(e))
	var lot: Dictionary = Career.data.exchange.actors.company.lots.get(str(_heat().id) + ":PRODUCT", {})
	check(str(lot.get("ship", "")) == "gr7", "the billet lot carries the ship")
	check(await _until(func(): return str(_heat().get("queue", "")) == "ingot:PQ-1" and is_equal_approx(float(_heat().quantity), 1.0), 1200), "the last tonne follows in a heat of its own")
	if float(e.get("billet1", 0.0)) >= 1.0:
		check(await _until(func(): return str(Mill.job().get("queue", "")) == "ingot:PQ-1", 1200), "the mill rolls the batch's billet by itself")
		check(await _until(func(): return float(ProcessQueue.entries()[0].get("rolled", 0.0)) >= 1.0, 20000), "a tonne of GR-7 plate rolled")
	else:
		print("  (the billet came out of grade %s: the mill takes grade 1 only)" % str(_heat().get("quality", {}).get("grade", "?")))
	print("PROCESS QUEUE CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
