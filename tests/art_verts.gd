extends SceneTree
# How much a ship's equipment art costs to replay, without timer noise (2026-11-12, the
# dedicated-drawing batches): every piece with art drawn once through Art.draw into the
# batch the strips use, then the triangle vertices counted — overall and by drawing.
# Reads ships/*.json only; touches no save.
# tools/run_test.sh tests/art_verts.gd -- [ship=ark01] [top=12]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sid: String = a[0] if a.size() > 0 else "ark01"
	var top: int = int(a[1]) if a.size() > 1 else 12
	root.add_child(preload("res://tests/test_window.gd").new())
	Art.EQ.ext = Art.SH
	Art.EQ.detail = Art.DT
	var w := World.new()
	root.add_child(w)
	Ship.build(w, Ship.load_data(sid))
	w.finalize()
	var node := Node2D.new()
	root.add_child(node)
	var font := Fonts.get_font("Regular")
	var by := {}
	var total := 0
	var n := 0
	for k in w.pieces:
		var p = w.pieces[k]
		if p.art == "":
			continue
		Art.EQ.batch_begin()
		Art.EQ.bxf = Transform2D.IDENTITY
		Art.draw(node, p.art, p.art_size, p, font)
		var c: int = (Art.EQ._batch[0] as PackedVector2Array).size()
		Art.EQ._batch = null
		total += c
		n += 1
		var key: String = "%s|%s" % [p.name_key, p.art]
		if not by.has(key):
			by[key] = [0, 0]
		by[key][0] += 1
		by[key][1] += c
	var ks := by.keys()
	ks.sort_custom(func(x, y): return by[x][1] > by[y][1])
	print("VERTS %s %d pieces %d vertices" % [sid, n, total])
	for i in mini(top, ks.size()):
		print("  %s x%d = %d" % [ks[i], by[ks[i]][0], by[ks[i]][1]])
	quit()
