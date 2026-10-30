extends SceneTree
const Cap = preload("res://tests/cap.gd")
var g: Node
var fails := 0
func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: fails += 1
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	SaveGame.path = "user://zp_test_laser_player.json"
	Career.path = "user://zp_test_laser_player_career.json"
	# Same contract/variant as the report; use a fresh wall because the player's
	# later autosave has already opened this compartment. Never read live saves.
	Game.contract = {"id":"039-EV-90","reg":"EV-90","ship":"ev55","variant":1498002416,"scope":"full","stars":3}
	Game.start_ship = "ev55"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	SaveGame.allow_test = false
	await frames(5)
	g.tutorial = null
	g.tools.set_tool(2,true)
	var pilot := Vector2(1685,150)
	# Restore the still-unrevealed side shown in the report; the saved copy is later.
	g.world.rooms.H.revealed = true
	g.world.rooms.E.revealed = false
	g.drone.global_position = pilot
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.drone.freeze = true
	g.tools._reveal_cut_opening(Vector2(1739.999,150))
	check(not g.world.rooms.E.revealed,"an intact wall never reveals the hidden room")
	# Keep visibility independent of the coarse gas-grid update in this check.
	g.sys.set_physics_process(false)
	g.bot.aim = Vector2(1770,150)
	g.cam_override = pilot
	g.zoom_override = 2.6
	g.cam_pos = pilot
	g.cam_vel = Vector2.ZERO
	g.zoom_now = 2.6
	await frames(5)
	await RenderingServer.frame_post_draw
	Cap.save(root,"res://proofs/laser_player_before.png")
	g.bot.lmb = true
	for i in 70:
		await frames(1)
		if g.world.rooms.E.revealed: break
	g.bot.lmb = false
	g.tools._finish_cut()
	g.paused_sim = true
	var sample := Vector2(1739.8,150)
	var blocked := false
	for p in g.world.pieces_at(sample):
		if p.barrier: blocked = true
	print("BOUNDARY front=",g.tools.front," hidden=",g.world.hidden(g.tools.front)," remaining_back_face=",blocked," revealed=",g.world.rooms.E.revealed," links=",g.sys.links)
	check(not blocked,"holding the laser cuts the last layer at the room boundary")
	check(g.world.rooms.E.revealed,"a physically open fine kerf reveals the room without requiring a gas-grid opening")
	var equipment = g.world.tag("PT-E")
	check(equipment != null and equipment.intact,"hidden equipment stays intact until the opening is revealed")
	await RenderingServer.frame_post_draw
	Cap.save(root,"res://proofs/laser_player_after.png")
	g.world.rooms.E.revealed = false
	var cover = g.world.add_piece("hull",PackedVector2Array([Vector2(1710,145),Vector2(1712,145),Vector2(1712,155),Vector2(1710,155)]),{})
	g.tools._reveal_cut_opening(Vector2(1739.999,150))
	check(not g.world.rooms.E.revealed,"a second layer blocking the slit prevents reveal")
	g.world.remove_piece(cover)
	g.drone.global_position = Vector2(1400,150)
	g.tools._reveal_cut_opening(Vector2(1739.999,150))
	check(not g.world.rooms.E.revealed,"a distant opening cannot be revealed beyond tool range")
	g.drone.global_position = pilot
	g.paused_sim = false
	g.bot.lmb = false
	await frames(3)
	g.bot.lmb = true
	await frames(2)
	check(g.world.rooms.E.revealed,"a new stroke recognizes an existing slit from an older save")
	g.bot.lmb = false
	g.queue_free()
	await frames(3)
	print("LASER BOUNDARY %s (%d failures)" % ["PASS" if fails == 0 else "FAIL",fails])
	quit(0 if fails == 0 else 1)
