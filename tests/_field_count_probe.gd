extends SceneTree
# 104 号 probe: how many metal pieces over the debris net's limit each ship starts with (the
# scale for the field grapple's achievement). Own saves only; prints only.
var ships := ["tug", "s09", "gr7", "h22", "jd38", "m14", "tw64", "cf90", "ob90"]


func _initialize() -> void:
	SaveGame.path = "user://zp_test_fieldprobe_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	for s in ships:
		Game.contract = {}
		Game.start_ship = s
		var g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		for i in 3:
			await process_frame
		var n := 0
		var all := 0
		for id in g.world.order:
			var p = g.world.pieces[id]
			if p.cls == "metal" or p.cls == "ore":
				all += 1
				if p.mass > Methods.FIELD_MIN_T:
					n += 1
		print("FIELD %s metal %d over0.5t %d" % [s, all, n])
		g.queue_free()
		for i in 3:
			await process_frame
	quit()
