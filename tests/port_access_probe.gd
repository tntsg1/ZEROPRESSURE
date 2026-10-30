extends SceneTree
const Cap = preload("res://tests/cap.gd")
var g: Node
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func place(p: Vector2) -> void:
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_port_access_career.json"
	SaveGame.path = "user://zp_test_port_access_save.json"
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.repaired_pending = []
	for zone in Port.ZONES: Career.data.port[zone] = 2
	Career.data.upgrades.lights = true
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(5)
	g.tutorial = null
	var x: float = Dock.centre().x * Geom.M
	g.bot.move = Vector2.UP
	g.bot.dash = true
	place(Vector2(x,(Dock.RAIL_Y + 3) * Geom.M))
	await frames(300)
	print("UNDER BOOM pilot_m=",g.drone.global_position / Geom.M," rail_y_m=",Dock.RAIL_Y)
	# Isolate the field from the solid boom by starting above its collision.
	place(Vector2(x,(Dock.BOUNDS.position.y + 1) * Geom.M))
	var min_y: float = g.drone.global_position.y
	for i in 900:
		await process_frame
		min_y = minf(min_y,g.drone.global_position.y)
	var hub: Vector2 = Backdrop.port_centre_px()
	var power := hub + PortArt.district_at("power") * PortArt.PM * Geom.M
	print("ABOVE BOOM best_y_m=",min_y / Geom.M," resting_m=",g.drone.global_position / Geom.M)
	print("HUB_m=",hub / Geom.M," POWER_m=",power / Geom.M)
	print("FIELD at HUB acceleration=",g.dock.field_pull(hub) * 3," dash thrust acceleration=",Drone.ACCEL * Drone.DASH_K)
	print("PORT access all_stages=",Port.total_stages()," cannot_reach_hub=",min_y > hub.y)
	g.bot.move = Vector2.ZERO
	g.bot.dash = false
	g.port_view = true
	await frames(150)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/port_access_panorama.png")
	g.queue_free()
	await frames(4)
	quit()
