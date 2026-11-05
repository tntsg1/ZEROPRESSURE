extends SceneTree
# 128 号 第 3 段: the first hulks' economy against the new order (the berth's lights, furnace and net
# first, then the trade port, the processing district…). A fresh career; the salvage bot strips the
# opening hulks one after another; after each settlement the haul is put away and a plain player's
# policy runs: keep the machines a repair names, sell the rest to the recycling station, mend what
# the main line points at whenever it can be paid. Prints, per hulk, what came home, the cash, and
# which chapter the career is in — to calibrate scripts/repair_bill.gd so nothing stalls. Own test
# saves only.   tools/run_test.sh tests/seg3_econ_probe.gd --fixed-fps 60 [-- n=3]

const Bot = preload("res://tests/salvage_bot.gd")
const RepairBill = preload("res://scripts/repair_bill.gd")
var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_seg3econ_career.json"
	SaveGame.path = "user://zp_test_seg3econ_save.json"
	SaveGame.allow_test = true
	Works.BUILD_TIME = false
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _kinds_named() -> Array:
	var out: Array = []
	for z in RepairBill.NEEDS:
		for st in RepairBill.NEEDS[z]:
			for k in st.kinds:
				if not str(k[0]) in out:
					out.append(str(k[0]))
	return out


func _play(job: Dictionary) -> void:
	Career.data.active = job
	Career.save()
	Game.contract = Career.active()
	Game.start_ship = str(Game.contract.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null
	var bot = Bot.new(g, {})
	var f := 0
	while not bot.step() and f < 60 * 60 * 12:
		f += 1
		await process_frame
	await _frames(30)
	g.queue_free()
	await _frames(5)


# the plain player's policy after a settlement
func _policy() -> Array:
	var did: Array = []
	for it in StoreBook.inbox().duplicate():
		var r := StoreBook.admit(str(it.uid))
		if not bool(r.get("ok", true)):
			StoreBook.sell("i:" + str(it.uid))
	var keep := _kinds_named()
	var sold := 0.0
	for u in StoreBook.units():
		var nk := str(u.get("part", u.get("good", {})).get("nk", ""))
		var cls := str(u.get("part", {}).get("cls", ""))
		if str(u.cat) in ["equip", "special", "part"] and not nk in keep and cls == "":
			var r2 := StoreBook.sell(str(u.id))
			if bool(r2.get("ok", false)):
				sold += float(r2.cash)
	did.append("sold $%.0f" % sold)
	for i in 6:
		var ch := Mainline.chapter()
		var why := ""
		match ch:
			"lights", "furnace":
				var id := "lights" if ch == "lights" else ("furnace_main" if not Repair.done("furnace_main") else "net_fix")
				Repair.find_fault(id)
				why = Repair.fix(id, true)
				if why != "":
					why = Repair.fix(id, false)
				if why == "":
					did.append("mended " + id)
			"trade", "process", "cargo", "power", "tug":
				if Port.stage(ch) < 1:
					var b := RepairBill.of(ch)
					why = Works.order_port(ch, true)
					if why == "":
						did.append("mended %s (bought %d, $%.0f)" % [ch, int(b.buy_n), float(b.buy_cash)])
				else:
					why = "stage done, chapter waits on something else"
			_:
				why = "chapter %s" % ch
		if why != "":
			did.append("stuck at %s: %s" % [ch, why])
			break
	return did


func _run() -> void:
	Txt.zh = true
	var n := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "store_guide_done": true, "store_counter": true}
	Career.save()
	for i in n:
		var job: Dictionary = Career.opening(i) if i < Career.OPENING.size() else {}
		if job.is_empty():
			break
		var m0 := float(Career.data.get("money", 0.0))
		await _play(job)
		var inbox := StoreBook.inbox().size()
		print("==== hulk %d %s: cash %.0f -> %.0f, inbox %d, repair steel %.1f t, ingots %.1f t" % [i + 1, str(job.id), m0, float(Career.data.money), inbox, float(Career.data.get("structure_t", 0.0)), float(StoreBook.raw_stock().get(StoreBook.Exchange.INGOT, 0.0))])
		var kinds := {}
		for p in Career.data.get("parts", []):
			kinds[str(p.get("nk", "?"))] = int(kinds.get(str(p.get("nk", "?")), 0)) + 1
		print("     machines kept for repairs: ", kinds)
		print("     policy: ", _policy())
		print("     after: cash %.0f, chapter %s (next %s), stages %s, upgrades %s, store %d/%d" % [float(Career.data.money), Mainline.chapter(), Mainline.next_open(), str(Career.data.get("port", {})), str(Career.data.get("upgrades", {}).keys()), StoreBook.used(), StoreBook.cap()])
		for z in ["trade", "process", "cargo"]:
			if Port.stage(z) < 1:
				print("     bill %s: %s" % [z, RepairBill.line(RepairBill.of(z))])
	quit(0)
