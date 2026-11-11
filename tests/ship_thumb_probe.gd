extends SceneTree
# probe: a ship built in a World inside an off-screen SubViewport, framed whole, rendered big and
# shrunk; saved to tests/out/thumb_probe_<id>.png. Own test saves only.
#   tools/run_test.sh tests/ship_thumb_probe.gd -- gr7,nr95,vt80

func _initialize() -> void:
	Career.path = "user://zp_test_thumb_probe_career.json"
	SaveGame.path = "user://zp_test_thumb_probe_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		ids.append_array(a.split(","))
	if ids.is_empty():
		ids = ["gr7", "nr95", "vt80"]
	var W := 1920
	var H := 560
	for id in ids:
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		root.add_child(vp)
		var bg := ColorRect.new()
		bg.color = Color(0.012, 0.013, 0.015)
		bg.size = Vector2(W, H)
		vp.add_child(bg)
		var w = World.new()
		vp.add_child(w)
		var data := Ship.load_data(str(id))
		var d := Variant.make(data, {"ship": id, "traps": [], "id": "THUMB-" + str(id)})
		Ship.build(w, d)
		for rn in w.rooms:
			w.rooms[rn].revealed = true
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for id2 in w.pieces:
			for q in w.pieces[id2].poly:
				lo = lo.min(q)
				hi = hi.max(q)
		var box := Rect2(lo, hi - lo).grow(24.0)
		var sc := minf(W / box.size.x, H / box.size.y)
		vp.canvas_transform = Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(W, H) * 0.5 - box.get_center() * sc)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tests/out/thumb_probe_%s.png" % id))
		if id == "gr7":
			for ln in ["back_layer", "light_layer", "line_layer", "cover_layer", "heat_layer", "cut_light", "rope_fx", "tether_layer"]:
				var n = w.get(ln)
				if n == null:
					continue
				n.visible = false
				for i in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/thumb_probe_gr7_no_%s.png" % ln))
				n.visible = true
		print("thumb %s: %d pieces, box %s, scale %.3f" % [id, w.pieces.size(), str(box.size), sc])
		vp.queue_free()
		await process_frame
	quit(0)
