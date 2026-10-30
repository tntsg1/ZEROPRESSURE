extends SceneTree
# Controlled physical cable fixture; no teleport/freeze is used to simulate the
# cable response. The winch post is positioned explicitly for measurable forces.
var g: Node
var fails := 0
var checks := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool,what: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",what])
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g4_cable_career.json"
	Career.data = Career.fresh()
	SaveGame.allow_test = false
	Game.start_ship = "pod"
	Game.contract = {"id":"G4-CABLE-FIXTURE","ship":"pod","rigging_hold":true,"kit":{},"gear":{"deploy":{"anchor":1},"lent":{}}}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(6)
	g.tutorial = null
	g.gear.set_physics_process(false)
	var at := Vector2(30,-6)*Geom.M
	var p = g.world.add_piece("hull",PackedVector2Array([at+Vector2(-12,-12),at+Vector2(12,-12),at+Vector2(12,12),at+Vector2(-12,12)]),{"key":"CABLE-LOAD","mass":0.5})
	g.world.make_body([p],null)
	g.gear.act({"kind":"place","type":"anchor","piece":p,"pos":at})
	check(g.gear.units.size() == 1 and g.gear.units[0].mode == "hold","the actual deployed anchor records the selected cable-lock mode")
	var u: Dictionary = g.gear.units[0]
	var body = p.body
	u.post = at+Vector2(120,0)
	u.rest = 200.0
	body.linear_velocity = Vector2.ZERO
	var before: Vector2 = body.global_position
	for k in 10:
		g.gear._step_anchor(u,p,1.0/60.0)
		await physics_frame
	check(body.global_position.distance_to(before) < 0.5,"a slack cable supplies no fictitious supporting force")
	u.rest = 100.0
	before = body.global_position
	for k in 40:
		g.gear._step_anchor(u,p,1.0/60.0)
		await physics_frame
	check(body.global_position.x > before.x+2.0,"a taut locked cable pulls the load through actual physics")
	check(not body.freeze and body.linear_velocity.length() < 150.0,"cable tension is bounded and does not freeze or fling the load")
	var state := JSON.parse_string(JSON.stringify(g.gear.save_state())) as Dictionary
	var restored := Gear.new()
	restored.setup(g)
	restored.load_state(state)
	check(restored.hold_mode and restored.units[0].mode == "hold" and is_equal_approx(float(restored.units[0].rest),100.0),"cable mode and locked length survive serialization")
	state.erase("hold_mode")
	for saved in state.units:
		saved.erase("mode")
		saved.erase("rest")
	restored.load_state(state)
	check(not restored.hold_mode and restored.units[0].get("mode","reel") == "reel","old anchors retain their original reel-to-trough behavior")
	restored.free()
	g.open_plan_panel()
	await frames(4)
	check(g.console_ui != null and g.console_ui.anchor_mode_button != null,"the deploy mode is controllable in the actual authorization panel")
	if g.console_ui != null:
		g.console_ui.toggle_anchor_mode()
		check(not g.gear.hold_mode,"the player can explicitly return new anchors to reel mode")
		g.console_ui.close()
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 LOCKED CABLE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
