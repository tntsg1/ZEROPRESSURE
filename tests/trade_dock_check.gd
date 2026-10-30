extends SceneTree
# 98 号: the trade port's hand-over dock and visitors, run on their own (no scene). A sale to a port
# company: the lighter comes in, every crate comes out of the intake, is weighed (the reading
# adds up to the trade's tonnes) and sealed, and is swung into the hold; then it leaves. A buy:
# the lighter comes in loaded and every crate goes the other way into the warehouse. A visitor:
# the ship berths, the gangway runs out, the cart brings him to the business console; gone, it
# all goes back. The price history: one point a minute, never more than 60. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/trade_dock_check.gd
const TW = preload("res://scripts/trade_works.gd")
const Ex = preload("res://scripts/industrial_exchange.gd")
const COMPANIES := ["merchant_00", "merchant_01", "merchant_02"]
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_tradedock_career.json"
	SaveGame.path = "user://zp_test_tradedock_save.json"
	SaveGame.allow_test = true
	_run()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _run_trade(tr: Dictionary, secs: float) -> float:
	var t := 0.0
	var came := false
	while t < secs:
		TW.tick(1.0 / 30.0, tr if not TW.job.is_empty() and not bool(TW.job.get("done", false)) or t < 1.0 else {}, "", COMPANIES)
		t += 1.0 / 30.0
		came = came or TW.lighter_k >= 1.0
		if came and TW.lighter_k <= 0.0:
			break
	return t


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"trade": 1}
	Career.data.market = true
	Career.save()
	Ex.command("view")
	TW.reset()
	# a sale: 2 t of billets to 天衡物流
	var sale := {"id": "T-1", "seller": Ex.PLAYER, "buyer": "merchant_01", "item": "steel_billet", "grade": 1, "quantity": 2.0, "unit_price": 1000.0, "state": "loading"}
	var weighs := 0
	var max_hold := 0
	var t := 0.0
	var came := false
	while t < 240.0:
		TW.tick(1.0 / 30.0, sale if t < 200.0 and (TW.job.is_empty() or not bool(TW.job.done)) else {}, "", COMPANIES)
		t += 1.0 / 30.0
		came = came or TW.lighter_k >= 1.0
		max_hold = maxi(max_hold, TW.hold)
		for e in TW.events:
			if str(e[0]) == "scale_beep":
				weighs += 1
		TW.events.clear()
		if came and TW.lighter_k <= 0.0:
			break
	check(came, "selling: the client lighter comes alongside")
	check(int(TW.job.get("n", 0)) == 4 and weighs == 4, "4 crates for 2 t, each weighed (%d)" % weighs)
	check(absf(TW.weigh_to - 2.0) < 1e-6, "the weighbridge adds up to the trade's 2.00 t (%.2f)" % TW.weigh_to)
	check(max_hold == 4 and bool(TW.job.get("done", false)) and TW.handed == 1, "all 4 swung into the hold; the hand-over done")
	check(TW.lighter_k <= 0.0, "then it leaves (%.0f s in all)" % t)
	# a buy: 1 t of scrap from 恒岳工业
	var buy := {"id": "T-2", "seller": "merchant_00", "buyer": Ex.PLAYER, "item": "ferrous_scrap", "grade": 1, "quantity": 1.0, "unit_price": 300.0, "state": "loading"}
	t = 0.0
	came = false
	var into := 0
	while t < 240.0:
		var before := TW.crates.size()
		TW.tick(1.0 / 30.0, buy if TW.job.is_empty() or str(TW.job.id) != "T-2" or not bool(TW.job.done) else {}, "", COMPANIES)
		t += 1.0 / 30.0
		came = came or TW.lighter_k >= 1.0
		TW.events.clear()
		if came and TW.lighter_k <= 0.0:
			break
	check(came and str(TW.job.id) == "T-2" and bool(TW.job.done) and TW.hold == 0 and TW.crates.is_empty(), "buying: the lighter comes in loaded and both crates go into the warehouse")
	# a visitor
	Career.data.port = {"trade": 1}
	var v := TradePeople.arrive()
	t = 0.0
	while t < 40.0:
		TW.tick(1.0 / 30.0, {}, "", COMPANIES)
		t += 1.0 / 30.0
	var e: Dictionary = TW.visitors.get(str(v.id), {})
	check(not e.is_empty() and float(e.k) >= 1.0 and float(e.g) >= 1.0 and float(e.c) >= 1.0, "a visitor: ship berthed, gangway out, the cart at the business console")
	v.state = "gone"
	t = 0.0
	while t < 40.0 and TW.visitors.has(str(v.id)):
		TW.tick(1.0 / 30.0, {}, "", COMPANIES)
		t += 1.0 / 30.0
	check(not TW.visitors.has(str(v.id)), "gone: the cart back, the gangway in, the ship away (%.0f s)" % t)
	# the history
	check(Career.data.has("exchange") and not preload("res://scripts/trade_hall.gd").board().is_empty(), "the exchange is open, the board has rows")
	Career.data.exchange.erase("hist")
	for i in 70:
		TW.record()
	var any := ""
	for k in Career.data.exchange.get("hist", {}):
		any = k
	check(any != "" and TW.history(any).size() == TW.HIST_N, "price history: 70 points recorded, the last 60 kept")
	print("TRADE DOCK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
