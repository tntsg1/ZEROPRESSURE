extends SceneTree
# 游戏内近景 (2026-11-11, E002–E016 dedicated drawings): builds one ship the way the berth draws
# it, opens every room, puts the camera on the first piece of a name_key and photographs it
# close up (the full frame and a crop). Reads ships/*.json only; touches no save.
# tools/run_test.sh tests/art_named_aux_shots.gd -- <ship> <name_key> <out_png> [zoom]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sid: String = a[0]
	var nk: String = a[1]
	var out: String = a[2]
	root.add_child(preload("res://tests/test_window.gd").new())
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
		quit(1)
		return
	var ext: Vector2 = hit.art_size   # already in pixels on the piece
	var close: float = float(a[3]) if a.size() > 3 else clampf(minf(520.0 / ext.x, 330.0 / ext.y), 1.5, 8.0)
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
	quit()
