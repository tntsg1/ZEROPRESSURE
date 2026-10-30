extends SceneTree
# which node draws the hollow boxes above / below the berth in the OB-90 build cine

const Cap = preload("res://tests/cap.gd")
var g: Node


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_findbox_career.json"
	SaveGame.path = "user://zp_test_findbox_save.json"
	Game.cine_in_tests = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _lum(img: Image, pts: Array) -> float:
	var s := 0.0
	for p in pts:
		var c := img.get_pixelv(p)
		s += c.r + c.g + c.b
	return s


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.certified = true
	Career.data.prologue_done = true
	Career.save()
	var D = load("res://scripts/dev.gd")
	D.b_ship = "ob90"
	var r: Dictionary = D.build({"rep": 30, "done": 6})
	var o: Dictionary = r.offer.duplicate(true)
	o.dev = true
	o.dev_from = "title"
	o.fee = 0.0
	Game.contract = o
	Game.start_ship = "ob90"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 600:
		await process_frame
		if str(g.state) == "build" and i > 30:
			break
	for i in 90:
		await process_frame
	Engine.time_scale = 0.0
	await process_frame
	await process_frame
	Cap.save(root, "res://tests/out/findbox_base.png")
	print("cam ", g.cam.position, " zoom ", g.cam_zoom(), " career ", g.career(), " M ", Geom.M)
	var pts := []
	for y in range(634, 650, 2):
		pts.append(Vector2i(1160, y))
		pts.append(Vector2i(1200, y))
	for y in range(674, 684, 2):
		pts.append(Vector2i(1142, y))
		pts.append(Vector2i(1174, y))
		pts.append(Vector2i(1228, y))
	var base := _lum(root.get_texture().get_image(), pts)
	print("base ", base)
	var cands: Array = []
	var stack: Array = [g]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
			if ch is CanvasItem and ch.visible:
				cands.append(ch)
	print("candidates ", cands.size())
	for c in cands:
		c.visible = false
		await process_frame
		await process_frame
		var v := _lum(root.get_texture().get_image(), pts)
		c.visible = true
		if v < base * 0.6:
			print("HIT ", c.get_path(), " ", c.get_script().resource_path if c.get_script() else "", " ", v)
	await process_frame
	print("FINDBOX DONE")
	quit(0)
