extends "res://tests/record108.gd"
# 108 号 第 5 件 (the economy, user "C 折中"), about 30 s for the owner: the settlement's second
# page with a GR-7's ingots — sold now at $300 a tonne, or kept for billet at $550 (about 1.6 times
# after the power); the exchange's prices; a heavy-hulled ship's contract card at $150 a tonne of
# structure. Own test saves only.
#   tools/run_test.sh tests/record108c.gd --write-movie recordings/record108c.avi --fixed-fps 30


func _run() -> void:
	Txt.zh = true
	cap_total = 4
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 120000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 0, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "port_walk": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.walk_v = 2
	Career.data.prologue_done = true
	Career.save()
	Exchange.command("view")
	# a GR-7 stripped: its 98 t of structure cast into ingots, the scrap at $150 a tonne
	var t := 98.4
	Career.data.active = {"id": "GR-108", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "GR-108", "earned": 125000.0, "grade": 2, "ingot_value": t * Ship.SCRAP_PER_T, "ingot_t": t, "parts": [], "parts_value": 0.0})
	await _scene("berth", {}, {})

	# ---- 1: sold now
	_beat(1, "钢锭直卖：每吨 $300，现在到账", "GR-7 拆下 98 吨船体，熔成钢锭直接卖")
	g.open_disposal()
	await _secs(0.8)
	var page = g.disposal_ui
	page._metal("sell")
	await _secs(6.2)

	# ---- 2: kept for billet
	_beat(2, "留着加工：钢坯每吨 $550，约为直卖 1.6 倍", "要等电炉和轧机排队、要付电费；缺钱时直卖，不缺时加工")
	page._metal("keep")
	await _secs(7.0)
	page.on_back.call()
	await _secs(0.3)

	# ---- 3: the exchange's prices
	_beat(3, "交易行参考价一起改了", "钢锭 $300 · 钢坯 $550 · 钢板 $750（钢锭不再比废钢便宜）")
	g.open_exchange()
	await _secs(0.6)
	var ui = g.console_ui
	if ui != null and ui.has_method("_tab"):
		ui._tab("sell")
	await _secs(5.9)
	if ui != null and ui.has_method("close"):
		ui.close()
	elif ui != null and ui.get("on_close") != null:
		ui.on_close.call()
	await _secs(0.3)

	# ---- 4: a heavy hull's contract card
	_beat(4, "船体废钢统一每吨 $150 估值", "以前每艘船手写一个价（$21–$371/吨），船体重的船被低估")
	var o := Career.fixed_offer("cf90", 960001, null)
	o.id = "CF-108"
	o.fee = 0.0
	Career.data.offers = [o]
	Career.save()
	g.open_console("terminal")
	await _secs(0.6)
	g.console_ui._open_app(0)
	await _secs(6.0)
	print("RECORD108C DONE")
	quit()
