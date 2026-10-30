extends SceneTree
# 31 号: the shipping's two-body mechanics against textbook values (no game, no saves).
#   godot --headless --path . -s tests/orbits_check.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	var mu := Orbits.MU
	# Earth (1 AU circle) to Mars' mean distance (1.524 AU): Hohmann 258.9 d, Δv 2.94 + 2.65 km/s
	var r1 := 1.0
	var r2 := 1.524
	var at := (r1 + r2) * 0.5
	var tof := PI * sqrt(at * at * at / mu)
	check(absf(tof - 258.9) < 1.0, "Hohmann time to Mars %.1f d" % tof)
	# the long way round (270°) and nearly across (160°): each arc arrives on time
	for ang in [deg_to_rad(160.0), deg_to_rad(270.0)]:
		var tgt := [r2 * cos(ang), r2 * sin(ang)]
		var v := Orbits.lambert([r1, 0.0], tgt, 200.0)
		var end := Orbits.propagate([r1, 0.0], [v[0], v[1]], 200.0)
		check(Vector2(end[0], end[1]).distance_to(Vector2(tgt[0], tgt[1])) < 1e-4, "a %d° arc lands on its target" % int(rad_to_deg(ang)))
	# a 90° transfer in 120 d: the arc found reaches r2 in exactly that time
	var a := [2.5, 0.0]
	var b := [0.0, 2.8]
	var w := Orbits.lambert(a, b, 120.0)
	var e2 := Orbits.propagate(a, [w[0], w[1]], 120.0)
	check(Vector2(e2[0], e2[1]).distance_to(Vector2(0.0, 2.8)) < 1e-4, "a 120-day 90° Lambert arc arrives on time")
	# Kepler: a body comes back after a period; Ceres' period ~1680 d
	var ceres: Array = Orbits.STATIONS[0]
	check(absf(Orbits.period(ceres) - 1680.0) < 15.0, "Ceres' period %.0f d" % Orbits.period(ceres))
	check(Orbits.pos(ceres, 0.0).distance_to(Orbits.pos(ceres, Orbits.period(ceres))) < 1e-4, "an orbit closes after one period")
	var st := Orbits.state(ceres, 37.0)
	var r := sqrt(st[0] * st[0] + st[1] * st[1])
	var vis := sqrt(mu * (2.0 / r - 1.0 / float(ceres[3])))
	check(absf(sqrt(st[2] * st[2] + st[3] * st[3]) - vis) < 1e-7, "the speed obeys vis-viva")
	# every station from the port: a sane run
	var worst := 0.0
	var longest := 0.0
	var shortest := 1e9
	for i in Orbits.STATIONS.size():
		for day in [0.0, 400.0, 1300.0]:
			var tr := Orbits.transfer(Orbits.station(i), Orbits.PORT, day)
			worst = maxf(worst, float(tr.dv1) + float(tr.dv2))
			longest = maxf(longest, float(tr.tof))
			shortest = minf(shortest, float(tr.tof))
			var arrive := Orbits.on_transfer(tr, 1.0)
			if arrive.distance_to(Orbits.pos(Orbits.PORT, day + float(tr.tof))) > 1e-3:
				check(false, "station %d day %d: the arc misses the port" % [i, day])
	print("transfers: %.0f–%.0f d, worst Δv %.1f km/s" % [shortest, longest, worst])
	check(shortest >= 45.0 and longest <= Orbits.STRETCH_MAX + 0.01, "every run between 45 days and the stretched cap (57 号)")
	check(worst < 75.0, "Δv stays in a fusion freighter's range")
	print("ORBITS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
