extends SceneTree
# Author a reference from the unchanged GR-7 factory structure. This is a data
# authoring tool, not a gameplay test: pressure safety is checked at execution.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	SaveGame.allow_test = false
	Game.contract = {}
	Game.start_ship = "gr7"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	var operations: Array = []
	for x in [13.0,15.0]:
		var p = g.world.key_piece("p7")
		var points := PackedVector2Array([Vector2(x,-4.12)*Geom.M,Vector2(x,-3.48)*Geom.M])
		var context: Dictionary = g.plan.cut_context(p)
		var result: Dictionary = g.world.commit_cut(p,points,World.KERF)
		assert(not result.gone)
		operations.append({"do":"cut","key":"p7","pl":[[points[0].x,points[0].y],[points[1].x,points[1].y]],
			"rooms":["C"],"pre":[{"key":"P-C01","kind":"pressure","val":0.0}],
			"before":context.shape,"links":context.links,"after":g.plan._shape(p),"kerf":World.KERF})
	var definition := {"id":"gr7:roof:access","version":1,"ship":"gr7","kind":"verified","label_zh":"货舱上蒙皮 · 检修开口","label_en":"CARGO SKIN · SERVICE OPENING",
		"targets":["p7"],"protected":["C-01"],"deps":["preset:gr7:preparation"],"steps":operations,
		"purpose_zh":"切离两处连接之间的上蒙皮，保留货箱。导轨与设备脱离仍由你处理。",
		"purpose_en":"Free the skin section between two verified kerfs; preserve the cargo. Rail clearance and equipment detachment remain manual."}
	DirAccess.make_dir_recursive_absolute("res://data/workplans")
	var file := FileAccess.open("res://data/workplans/gr7_roof.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(definition,"\t"))
	file.close()
	g.queue_free()
	for k in 4: await process_frame
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < drain: await process_frame
	print("G4 ROOF REFERENCE AUTHORED (2 kerfs; execution still requires live safety checks)")
	quit(0)
