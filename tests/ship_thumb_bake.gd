extends SceneTree
# 135 号: bake the hulk market's ship pictures (scripts/ship_thumbs.gd) — every ship type the market
# can list, drawn the way the berth draws it — into assets/ship_thumbs/<id>.res (lossless) with
# index.json (each ship file's md5), and lay them all out in one overview with their names:
# tests/out/ship_thumbs_all.png. Run again after a ship or its art changes. Own test saves only.
#   tools/run_test.sh tests/ship_thumb_bake.gd [-- id,id]   (no ids: every type in the market)

const Thumbs := preload("res://scripts/ship_thumbs.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_thumb_bake_career.json"
	SaveGame.path = "user://zp_test_thumb_bake_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		ids.append_array(Array(a.split(",")).filter(func(x): return x != ""))
	var only := not ids.is_empty()
	if ids.is_empty():
		for e in Market.POOL:
			if Ship.available(str(e[0])) and not str(e[0]) in ids:
				ids.append(str(e[0]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Thumbs.DIR))
	var index := {}
	var f0 := FileAccess.open(Thumbs.DIR + "index.json", FileAccess.READ)
	if f0 != null:
		var d0 = JSON.parse_string(f0.get_as_text())
		if d0 is Dictionary:
			index = d0
		f0 = null
	var shots := {}
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var img: Image = await Thumbs.render(root, str(id))
		if img == null:
			print("SKIP %s (no ship file)" % id)
			continue
		var tex := PortableCompressedTexture2D.new()
		tex.keep_compressed_buffer = true
		tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		var err := ResourceSaver.save(tex, Thumbs.DIR + str(id) + ".res")
		index[str(id)] = Thumbs.ship_md5(str(id))
		shots[id] = img
		print("BAKED %s %dx%d in %d ms (%s)" % [id, img.get_width(), img.get_height(), Time.get_ticks_msec() - t0, error_string(err)])
	var f := FileAccess.open(Thumbs.DIR + "index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t", true))
	f = null
	# the overview: four to a row, each on the card's own dark window with its name under it
	var cols := 4
	var cw := Thumbs.SIZE.x + 24
	var ch := Thumbs.SIZE.y + 44
	var rows := int(ceil(shots.size() / float(cols)))
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * cw + 24, rows * ch + 24)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var board := Board.new()
	board.shots = shots
	board.cols = cols
	board.cell = Vector2(cw, ch)
	board.size = Vector2(vp.size)
	vp.add_child(board)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := "res://tests/out/ship_thumbs_all%s.png" % ("_some" if only else "")
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("OVERVIEW %s (%d types)" % [out, shots.size()])
	quit(0)


class Board extends Control:
	var shots := {}
	var cols := 4
	var cell := Vector2.ZERO
	var _texs := {}     # kept: a texture made inside _draw and dropped draws white

	func _draw() -> void:
		Charcoal.ground(self, size)
		var font := Fonts.get_font("Medium")
		var k := 0
		for id in shots:
			var p := Vector2(12 + (k % cols) * cell.x, 12 + (k / cols) * cell.y)
			var r := Rect2(p + Vector2(6, 6), Vector2(cell.x - 12, cell.y - 44))
			Charcoal.display(self, r, 1.0, 7)
			if not _texs.has(id):
				_texs[id] = ImageTexture.create_from_image(shots[id])
			var tex: Texture2D = _texs[id]
			draw_texture_rect(tex, r.grow(-4.0), false)
			var ty: Dictionary = Market.type_of(str(id))
			var nm := "%s · %s · %d m" % [str(id), str(ty.name[0]) if ty.has("name") else str(id), int(ty.get("length", 0))]
			draw_string(font, p + Vector2(10, cell.y - 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Charcoal.ink(1.0, 2))
			k += 1
