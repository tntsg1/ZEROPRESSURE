extends "res://tests/guide_check.gd"
# 多掉一次头 (2026-11-10): a freight train leaving a hub hatch for its own district changes ends; before the
# fix it changed ends where a switch was still under it and its lead car was drawn a metre off the rails.
# The moment it changes ends, framed close, with how far its bogies stand off the rails.
#   tools/run_test.sh tests/freight_turn_shots.gd --fixed-fps 60 -- before|after
#   → tests/out/freight_turn_<tag>.png ("before" switches FreightWorks.push_pull_fix off)
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")
const OUT := "res://tests/out/freight_turn_%s.png"
var segs: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_freightturn_career.json"
	SaveGame.path = "user://zp_test_freightturn_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _off(p: Vector2) -> float:
	var best := INF
	for sg in segs:
		best = minf(best, _seg_d(p, sg[0], sg[1]))
	return best / Geom.M


func _worst(tr: Dictionary) -> float:
	var w := 0.0
	for car in g.freight.poses(tr):
		for b in car[4]:
			w = maxf(w, _off(b[0]))
	return w


static func _abs_z(n: Node) -> int:
	var z := 0
	var c: Node = n
	while c != null:
		if c is CanvasItem:
			z += (c as CanvasItem).z_index
			if not (c as CanvasItem).z_as_relative:
				break
		c = c.get_parent()
	return z


func _covers() -> void:
	var fz := _abs_z(g.freight)
	var out := []
	for n in g.find_children("*", "Node2D", true, false):
		var ci := n as CanvasItem
		if ci == null or not ci.is_visible_in_tree():
			continue
		var z := _abs_z(n)
		if z > fz:
			out.append("%s(%s) z%d" % [str(n.name), str(n.get_script().resource_path.get_file()) if n.get_script() != null else n.get_class(), z])
	print("  freight z %d; drawn above it: %s" % [fz, str(out.slice(0, 40))])


func _run() -> void:
	Txt.zh = true
	var args := OS.get_cmdline_user_args()
	var tag: String = str(args[0]) if not args.is_empty() else "after"
	FW.push_pull_fix = tag != "before"
	var lift := "lift" in args
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(30)
	for l in g.tram.track_lines:
		for i in range(1, (l as Array).size()):
			segs.append([l[i - 1], l[i]])
	W.demo = true
	g.zoom_override = 1920.0 / ((110.0 if "wide" in args else 40.0) * Geom.M)
	g.cam_override = PortStructure.centre()
	var was := {}
	var shot := false
	var worst_all := 0.0
	for f in 60 * 300:
		await process_frame
		for tr in FW.trains:
			var w := _worst(tr)
			worst_all = maxf(worst_all, w)
			var key := str(tr.step.get("place", ""))
			var id := int(tr.id)
			var r := ((tr.pos as Vector2) - PortStructure.centre()).length() / Geom.M
			# just changed ends on the loop (by a hub hatch), bound for a district's stop
			if not shot and key.begins_with("d:") and was.has(id) and bool(was[id]) != bool(tr.lf) and absf(r - Tram.LOOP_R) < 1.5 and float(tr.speed) < 0.05 * Geom.M:
				shot = true
				g.cam_override = tr.pos
				for k in 8:
					g.cam_pos = tr.pos
					g.cam_vel = Vector2.ZERO
					g.zoom_now = g.zoom_override
					await process_frame
				var w2 := _worst(tr)
				if lift:
					g.freight.z_index = 50
					await _frames(2)
				Cap.save(root, OUT % (tag + ("_lift" if lift else "") + ("_wide" if "wide" in args else "")))
				var ia := root.get_texture().get_image()
				g.freight.self_modulate.a = 0.0
				await _frames(2)
				var ib := root.get_texture().get_image()
				g.freight.self_modulate.a = 1.0
				var sp: Vector2 = g.get_viewport().get_canvas_transform() * (tr.pos as Vector2)
				var nd := 0
				var bx := Rect2i(Vector2i(sp) - Vector2i(300, 300), Vector2i(600, 600)).intersection(Rect2i(0, 0, ia.get_width(), ia.get_height()))
				for yy in range(bx.position.y, bx.end.y, 2):
					for xx in range(bx.position.x, bx.end.x, 2):
						var ca := ia.get_pixel(xx, yy)
						var cb := ib.get_pixel(xx, yy)
						if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.02:
							nd += 1
				print("  train on screen at %s: %d sampled pixels change when the freight layer's own drawing is hidden" % [str(sp), nd])
				var cc := PortStructure.centre()
				print("  train at %s, camera at %s zoom %.3f, freight layer visible %s, trains %d" % [str(((tr.pos as Vector2) - cc) / Geom.M), str((g.cam.global_position - cc) / Geom.M), g.cam_zoom(), str(g.freight.visible), FW.trains.size()])
				var fv: Node2D = g.freight
				var view: Rect2 = (fv.get_canvas_transform().affine_inverse() * fv.get_viewport_rect()).grow(8.0 * Geom.M)
				_covers()
				print("  freight view rect %s (m from centre), head in %s, tail in %s, active %s, draw_us %.0f, still/low visible %s/%s" % [str(Rect2((view.position - cc) / Geom.M, view.size / Geom.M)), str(view.has_point(tr.pos)), str(view.has_point(FW.behind(tr, 8.7 * Geom.M))), str(fv.active()), float(fv.draw_us), str(fv.still.visible), str(fv.low.visible)])
				print("SHOT %s: train #%d changing ends on the loop at %.0f° for %s, its bogies at most %.2f m off the rails" % [tag, id, rad_to_deg(((tr.pos as Vector2) - PortStructure.centre()).angle()), key, w2])
			was[id] = bool(tr.lf)
		if shot:
			break
	print("worst bogie off the rails while watching: %.2f m (fix %s)" % [worst_all, str(FW.push_pull_fix)])
	W.demo = false
	FW.push_pull_fix = true
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	quit(0)
