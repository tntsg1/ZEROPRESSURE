extends SceneTree
const Cap = preload("res://tests/cap.gd")
var g: Node
func _initialize() -> void:
	_run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func _run() -> void:
	Txt.test_zh = true
	SaveGame.path = "user://zp_test_plant_motion.json"
	Career.path = "user://zp_test_plant_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"move":Vector2.ZERO,"aim":Vector2.ZERO,"lmb":false}
	root.add_child(g)
	await frames(30)
	var line = g.dock.scrapline
	var sm = g.dock.smelter
	sm.phase = "melt"
	sm.m_l = 8
	sm.m_s = 0.2
	sm.T = 1570
	sm.bunker = 10
	sm.lance_t = 39.5
	var x: float = g.dock.furnace_x
	var y: float = Dock.FLOOR_Y
	g.cam_override = Vector2(x - 2.9,y + 4.7) * 48
	g.zoom_override = 1.03
	await frames(25)
	var plate := PackedVector2Array([Vector2(-3,-0.9),Vector2(3,-0.9),Vector2(3,0.9),Vector2(-3,0.9)])
	var frame_l := PackedVector2Array([Vector2(-0.8,-0.7),Vector2(0.8,-0.7),Vector2(0.8,-0.4),Vector2(-0.4,-0.4),Vector2(-0.4,0.7),Vector2(-0.8,0.7)])
	var box := PackedVector2Array([Vector2.ZERO,Vector2(0.6,0),Vector2(0.6,0.5),Vector2(0,0.5)])
	line.take([plate],1.0,["hull"],x)
	line.take([frame_l,box],0.6,["rib","equip"],x)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/plant_motion_frames"))
	for i in 320:
		await frames(3)
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/plant_motion_frames/%03d.png" % i)
	print("PLANT RECORD: blocks=%d shred=%.3f iron=%.3f nonferrous=%.3f kg samples=%d" % [line.pucks_made,line.shredded,line.ferrous,line.nonferrous,sm.sample_count])
	line.take([plate],1.0,["hull"],x)
	line.take([frame_l,box],0.6,["rib","equip"],x)
	await frames(180)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stamp := Time.get_ticks_usec()
	await frames(120)
	print("ACTIVE PLANT RENDER %.2f ms/frame, 1280x720" % [(Time.get_ticks_usec() - stamp) / 120000.0])
	g.queue_free()
	await frames(3)
	quit()
