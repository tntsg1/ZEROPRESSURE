extends "res://tests/guide_check.gd"
# 130 号: what working out a freight train's candidate routes costs (µs), and where in it the time goes.
#   tools/run_test.sh tests/freight_route_bench.gd
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")
const Tram = preload("res://scripts/tram.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_freight_bench_career.json"
	SaveGame.path = "user://zp_test_freight_bench_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	W.reset()
	W.stage = 2
	FW.reset()
	FW.on = true
	for i in 3:
		FW.tick(1.0 / 60.0)
	for tr in FW.trains:
		var z := str(tr.home)
		for pair in [["h:" + z, [0, 1]], ["h:" + z, [0]], ["d:" + z, []]]:
			FW._routes.clear()
			var t0 := Time.get_ticks_usec()
			var rs: Array = FW.routes(tr, pair[0], pair[1])
			var t1 := Time.get_ticks_usec()
			var n := 0
			for rt in rs:
				n += FW.rc_of(rt).size()
			var t2 := Time.get_ticks_usec()
			print("  #%d %s -> %s %s: %d candidates, build %d µs, all cells %d µs (%d cells)" % [tr.id, tr.place, pair[0], str(pair[1]), rs.size(), t1 - t0, t2 - t1, n])
	var t3 := Time.get_ticks_usec()
	for k in 20:
		FW.cells(FW.pass_pts())
	print("  cells of the passing loop x20: %d µs" % (Time.get_ticks_usec() - t3))
	var t4 := Time.get_ticks_usec()
	for k in 20:
		Tram._arc(0.0, 1.0, PI)
	print("  half a loop's arc x20: %d µs" % (Time.get_ticks_usec() - t4))
	quit(0)
