extends SceneTree
# 游戏内近景 (2026-11-11, the dedicated-drawing batches): builds a ship the way the berth draws
# it, opens every room, puts the camera on the first piece of a name_key and photographs it
# close up and at the berth's working zoom (two 960x600 crops). Reads ships/*.json only;
# touches no save.
# tools/run_test.sh tests/art_named_aux_shots.gd -- <ship> <name_key> <out_png> [zoom]
# tools/run_test.sh tests/art_named_aux_shots.gd -- list <file>   (lines: ship name_key out_png_without_.png)

var jobs: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	root.add_child(preload("res://tests/test_window.gd").new())
	if a.size() > 1 and a[0] == "list":
		for ln in FileAccess.get_file_as_string(a[1]).split("\n"):
			var f := ln.strip_edges().split(" ", false, 2)
			if f.size() == 3:
				jobs.append([f[0], f[1], f[2] + ".png", -1.0])
	else:
		jobs.append([a[0], a[1], a[2], float(a[3]) if a.size() > 3 else -1.0])
	_run()


func _run() -> void:
	for j in jobs:
		await _shot(j[0], j[1], j[2], j[3])
	quit()


func _shot(sid: String, nk: String, out: String, zoom: float) -> void:
	var w := World.new()
	root.add_child(w)
	Ship.build(w, Ship.load_data(sid))
	w.finalize()
	for n in w.rooms:
		w.rooms[n].revealed = true
		w.rooms[n].reveal_t = 1.0
	w.back_layer.queue_redraw()
	w.cover_layer.queue_redraw()
	var hit = null
	for k in w.pieces:
		var p = w.pieces[k]
		if p.name_key == nk:
			hit = p
			break
	if hit == null:
		print("NO PIECE ", nk, " on ", sid)
		w.queue_free()
		await process_frame
		return
	var ext: Vector2 = hit.art_size   # already in pixels on the piece
	var close: float = zoom if zoom > 0.0 else clampf(minf(520.0 / ext.x, 330.0 / ext.y), 1.5, 8.0)
	var cam := Camera2D.new()
	cam.position = hit.center_world()
	root.add_child(cam)
	await process_frame
	cam.make_current()
	# the close-up, then the same spot at the berth's working zoom for context
	for zz in [[close, "近景"], [1.5, "环境"]]:
		cam.zoom = Vector2(zz[0], zz[0])
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = load("res://tests/cap.gd").to_srgb8(root.get_texture().get_image())
		var sz := img.get_size()
		var crop := img.get_region(Rect2i(sz.x / 2 - 480, sz.y / 2 - 300, 960, 600))
		var fn: String = out.replace(".png", "_%s.png" % zz[1])
		crop.save_png(fn)
		print("SHOT ", sid, " ", nk, " ", hit.tag, " zoom ", snappedf(zz[0], 0.01), " -> ", fn)
	cam.queue_free()
	w.queue_free()
	for i in 3:
		await process_frame
