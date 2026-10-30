extends SceneTree
# 80 号 Q2/Q4: a tow is never a dead end. The first one is on Liang; after that, short of cash,
# one hulk at a time goes on credit and the next settlement takes it back; a second credit is
# refused with the reason; with the cash it is paid as before. Own saves only.
#   tools/run_test.sh tests/tow_credit_check.gd --fixed-fps 60
var fails := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func _initialize() -> void:
	Scan.ON = false
	Career.path = "user://zp_test_tow_credit_career.json"
	SaveGame.path = "user://zp_test_tow_credit_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = Market.make(4242, Career.data)
	Career.data.money = 0.0
	Career.save()
	check(Career.data.offers.size() >= 3, "three finds to tow (%d)" % Career.data.offers.size())
	# ---- the first tow, with no money at all: free
	var o0: Dictionary = Career.data.offers[0]
	var t0 := ShipMarket.tow_terms(o0)
	check(t0.ok and t0.free and float(t0.pay) == 0.0 and "免费" in str(t0.text), "first tow with $0: free, the card says so (%s)" % str(t0.text))
	var r0 := ShipMarket.tow_find(0)
	check(r0.ok and r0.free and float(Career.data.money) == 0.0 and float(Career.data.get("tow_owed", 0.0)) == 0.0, "the first tug goes, nothing paid, nothing owed")
	# ---- the yard full: free the berth for the next (a second yard berth)
	Career.data.port["tug"] = 1
	# ---- the second, still $0: on credit
	var o1: Dictionary = Career.data.offers[0]
	var t1 := ShipMarket.tow_terms(o1)
	check(t1.ok and not t1.free and float(t1.owe) > 0.0 and "赊" in str(t1.text), "second tow with $0: on credit (%s)" % str(t1.text))
	var r1 := ShipMarket.tow_find(0)
	var owed := float(Career.data.get("tow_owed", 0.0))
	check(r1.ok and float(Career.data.money) == 0.0 and owed > 0.0 and is_equal_approx(owed, float(t1.owe)), "it goes; %s on credit, the cash untouched" % Pal.money(owed))
	# ---- a third, still broke, one already on credit: refused with the reason, nothing taken
	if Career.data.offers.is_empty():
		Career.data.offers = Market.make(77, Career.data)
	Career.data.port["tug"] = 2
	var n_before: int = Career.data.offers.size()
	var t2 := ShipMarket.tow_terms(Career.data.offers[0])
	var r2 := ShipMarket.tow_find(0)
	check(not t2.ok and not r2.ok and "还赊着" in str(r2.reason) and Career.data.offers.size() == n_before, "a second credit is refused and says why: %s" % str(r2.get("reason", "")))
	# ---- the next settlement takes it back: the same job settled without the debt pays that much more
	Career.data.active = {"id": "TC-1", "ship": "tug", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.data.money = 0.0
	var snap: Dictionary = Career.data.duplicate(true)
	Career.data.tow_owed = 0.0
	var clean: Dictionary = Career.settle({"earned": 20000.0, "losses": 0.0, "job_id": "TC-1", "grade": 2, "rate": 0.9})
	Career.data = snap
	var res: Dictionary = Career.settle({"earned": 20000.0, "losses": 0.0, "job_id": "TC-1", "grade": 2, "rate": 0.9})
	check(float(res.get("tow_owed", 0.0)) == owed and float(Career.data.get("tow_owed", 0.0)) == 0.0, "the settlement takes the %s back and clears the debt" % Pal.money(owed))
	check(absf(float(clean.money) - float(res.money) - owed) < 1.0, "the cash after it is short by exactly the tow (%s vs %s)" % [Pal.money(float(res.money)), Pal.money(float(clean.money))])
	# ---- with the cash, paid as before
	Career.data.money = 500000.0
	if Career.data.offers.is_empty():
		Career.data.offers = Market.make(91, Career.data)
	var o3: Dictionary = Career.data.offers[0]
	var t3 := ShipMarket.tow_terms(o3)
	check(t3.ok and float(t3.pay) > 0.0 and float(t3.owe) == 0.0, "with the money the tow is simply paid (%s)" % Pal.money(float(t3.pay)))
	print("TOW CREDIT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
