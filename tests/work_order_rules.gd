extends SceneTree
# Transaction/stock rules, using declared receipt fixtures. Physical recovery is
# deliberately a separate integration gate; these are not playthrough claims.
const Orders = preload("res://scripts/work_orders.gd")
var checks := 0
var fails := 0
const FILE := "user://zp_test_g4_order_rules.json"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,what: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",what])
func receipt(keys: Array, assembled: bool = false, stable: bool = false) -> Dictionary:
	return {"keys":keys,"value":1000.0,"assembled":assembled,"stable":stable,"source":"fixture"}
func settle(id: String, records: Array, sold: bool = false, whole: bool = false) -> Dictionary:
	return Career.settle({"job_id":Career.active().id,"earned":0.0,"grade":1,"fee":Career.active().fee,"used":{},"work_order":{"id":id,"receipts":records,"sell":sold,"whole":whole,"complete":true}})
func _run() -> void:
	Career.path = FILE
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.loan = 0.0
	Career.data.done = 10
	Career.data.upgrades = {"lights":1}
	Career.save()
	check(Orders.reason("access") == "" and Orders.reason("rigging") != "","the first commission is directly available and the mounted-section goal has a real prerequisite")
	var before := JSON.stringify(Career.data)
	Career.path = "user://zp_g4_rules_missing_%d/slot.json" % Time.get_ticks_usec()
	check(Orders.take("access") != "" and JSON.stringify(Career.data) == before,"failed contract signing rolls back fee, loan, attempt counter and gear together")
	Career.path = FILE
	check(Orders.take("access") == "","a fixed GR-7 source is available without rolling random offers")
	check(Career.active().work_order == "access" and Career.active().kit.has("hauler") and not Career.data.upgrades.has("hauler"),"contract machinery is temporary rather than a silent permanent unlock")
	var first_id := str(Career.active().id)
	var sale := settle("access",[receipt(["C-03"])],true)
	check(sale.work_order.get("sold",false) and not Orders.done("access"),"choosing sale cannot also complete the engineering delivery")
	check(Career.data.work_orders.stock.access.is_empty(),"sold receipts are removed from engineering stock")
	Orders.take("access")
	check(str(Career.active().id) != first_id,"a repeated attempt has a distinct durable job identity")
	var first := settle("access",[receipt(["C-03"])])
	check(first.work_order.get("completed",false) and Orders.done("access"),"a complete reserved receipt advances the engineering chain")
	check(Career.data.work_orders.methods.locked_anchor and int(Career.data.gear.probe) == 1,"the first goal grants a usable method and an owned probe")
	# 104 号: buying anchors opens with the method 整段拖走, taught by the next order (稳住再拆), not this one
	check(Gear.locked_by("anchor") != "" and not Career.data.get("feats",{}).has("section"),"the intro order alone does not open anchor purchase, nor forge the old heavy-section feat")
	check(Orders.take("rigging") == "","the next authored task opens immediately after the verified milestone")
	check(int(Career.active().gear.lent.anchor) == 1 and int(Career.active().gear.lent.probe) == 1 and Career.active().rigging_hold,"the mounted-section task actually lends its required tools and selects cable lock")
	var invalid := settle("rigging",[receipt(["C-02","FP-C2"],true,false)])
	check(not Orders.done("rigging") and invalid.work_order.get("pending",false),"a mounted delivery without stability evidence cannot complete the task")
	check(Career.data.work_orders.stock.rigging.is_empty(),"invalid evidence does not poison the reservation stock or block a later valid attempt")
	Orders.take("rigging")
	var mounted := settle("rigging",[receipt(["C-02","FP-C2"],true,true)])
	check(mounted.work_order.get("completed",false) and int(Career.data.gear.anchor) == 1,"a stable intact mounted section awards the owned anchor")
	check(Methods.learned("section") and Gear.locked_by("anchor") == "","and teaches 整段拖走: anchors can be bought from now on")
	check(Orders.reward_options().has("buffer"),"a currently usable unbuilt facility can be the final engineering reward")
	check(Orders.take("heavy","buffer") == "" and Career.active().kit.has("crane"),"the heavy commission supplies a real temporary crane")
	var partial := settle("heavy",[receipt(["CP-E"])])
	check(partial.work_order.get("pending",false) and Career.data.work_orders.stock.heavy.size() == 1,"a partial delivery persists across contracts without losing its reserved equipment")
	var reservation = Orders.new({"job":{"work_order":"heavy"}})
	reservation.receipts = [receipt(["RAD"])]
	check(reservation.reserved_value() == 1000.0 and reservation.stock_sale_value() == 0.0,"reserving only subtracts the newly recovered value, not stock already paid for on a previous contract")
	reservation.sell = true
	check(reservation.reserved_value() == 0.0 and reservation.stock_sale_value() == 1000.0,"changing to sale releases prior stock once and does not subtract the new recovery")
	Orders.take("heavy","buffer")
	var assembled_before := float(Career.data.money)
	var pending_before := JSON.stringify(Career.data)
	Career.path = "user://zp_g4_delivery_missing_%d/slot.json" % Time.get_ticks_usec()
	var failed_delivery := settle("heavy",[receipt(["RAD"])])
	check(failed_delivery.get("save_failed",false) and JSON.stringify(Career.data) == pending_before,"failed delivery persistence restores prior reserved stock, fee, facility and progress together")
	Career.path = FILE
	var split := settle("heavy",[receipt(["RAD"])],false,true)
	check(Orders.done("heavy") and Career.data.upgrades.has("buffer"),"the remaining equipment completes the same engineering need and restores the chosen facility")
	check(float(split.work_order.cash_cost) == Repair.price("buffer",false)*0.2,"an unverified whole-delivery display flag cannot waive separate-unit assembly cost")
	check(float(Career.data.money) == assembled_before-float(split.tow)-float(split.work_order.cash_cost) and float(split.money) == float(Career.data.money),"assembly payment, existing towing fee and the displayed balance use the same committed amount")
	check(Career.data.repaired_pending.has("buffer") and Career.data.work_orders.stock.heavy.is_empty(),"the restoration is staged for the visible berth and consumes its engineering stock")
	var completed := JSON.stringify(Career.data)
	var duplicate: Dictionary = Career.settle({"job_id":Career.data.history[-1].id,"earned":999999.0})
	check(duplicate.get("already_settled",false) and JSON.stringify(Career.data) == completed,"the same delivery cannot restore or pay twice")
	Career.data.work_orders.done.erase("heavy")
	Career.data.upgrades.erase("buffer")
	Orders.take("heavy","buffer",true)
	var whole := settle("heavy",[receipt(["CP-E","RAD","K4"],true)])
	check(whole.work_order.get("whole",false) and float(whole.work_order.cash_cost) == 0.0 and Career.data.upgrades.has("buffer"),"the supplied whole-assembly evidence waives installation cost and restores the same facility")
	Career.data.work_orders.done.erase("heavy")
	Career.data.upgrades.erase("buffer")
	Orders.take("heavy","buffer")
	settle("heavy",[receipt(["CP-E"])])
	Orders.take("heavy","buffer",true)
	var surplus_before: float = Career.data.money
	var switched := settle("heavy",[receipt(["CP-E","RAD","K4"],true)])
	check(switched.work_order.whole and float(switched.work_order.surplus_cash) == 1000.0,"switching from partial stock to a complete module refunds the earlier extra device rather than consuming it twice")
	check(is_equal_approx(float(Career.data.money),surplus_before-float(switched.tow)+1000.0),"surplus refund, whole-delivery fee waiver and final cash commit in the same transaction")
	var refund_state := JSON.stringify(Career.data)
	Career.settle({"job_id":Career.data.history[-1].id,"earned":0.0})
	check(JSON.stringify(Career.data) == refund_state,"reloading the completed contract cannot refund the old reservation again")
	# A separate old-career fixture: all eligible facilities already exist.
	Career.data.active = {}
	Career.data.work_orders.done.erase("heavy")
	for item in Repair.ITEMS: Career.data.upgrades[str(item[0])] = 1
	check(Orders.reward_options() == ["field_stock"],"a fully restored older career receives useful field stock rather than being forced to rebuild")
	Orders.take("heavy","field_stock",true)
	var stock_before: int = Career.data.gear.anchor
	var legacy := settle("heavy",[receipt(["CP-E","RAD","K4"],true)])
	check(legacy.work_order.reward == "field_stock" and int(Career.data.gear.anchor) == stock_before+1,"the old-career fallback actually grants reusable physical equipment")
	check(Orders.track("") == "" and Career.data.work_orders.tracked == "","tracking can be hidden without erasing permanent engineering progress")
	print("WORK ORDER RULES %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
