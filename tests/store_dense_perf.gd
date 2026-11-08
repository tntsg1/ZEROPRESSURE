extends SceneTree
const Exchange = preload("res://scripts/industrial_exchange.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Career.path = "user://zp_dense_perf_career.json"
	SaveGame.path = "user://zp_dense_perf_save.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.port = {"cargo": 2, "trade": 1}
	Career.data.money = 1000000.0
	Career.data.goods = []
	StoreBook._add_raw(Exchange.INGOT, 480.0, "dense-perf", "")
	var ui = load("res://scripts/company_store.gd").new()
	root.add_child(ui)
	ui.kind = "raw"
	for i in 30:
		await process_frame
	var samples: Array = []
	for i in 180:
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	var sum := 0.0
	for ms in samples: sum += ms
	print("DENSE STORE items=%d used=%d/%d mean=%.2f p95=%.2f max=%.2f ms" % [ui.items.size(), StoreBook.used(), StoreBook.cap(), sum / samples.size(), samples[int(samples.size() * 0.95)], samples.back()])
	quit()
