extends SceneTree
# Declared collision fixture using the real cutter rigid body and Godot physics.
# This does not claim whole-ship replay, material cutting or human playtesting.
var checks := 0
var failures := 0
class PauseContext:
	extends RefCounted
	var state := "play"
	var paused_sim := false
	var auto_paused := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func frames(n: int) -> void:
	for k in n: await physics_frame
func wall(parent: Node2D,at: Vector2,size: Vector2) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	node.shape = shape
	body.add_child(node)
	parent.add_child(body)
	return node
func run() -> void:
	var space := Node2D.new()
	root.add_child(space)
	var robot = load("res://scripts/cutter_drone.gd").new()
	space.add_child(robot)
	await frames(3)
	robot.move_to(Vector2(100,0))
	await frames(8)
	check(robot.global_position.x > 0.0 and robot.global_position.x < 90.0,"real finite thrust moves without teleporting to goal")
	# Project physics runs at 120 Hz: allow 2.5 simulated seconds for travel
	# and settling; the distance/speed and tool safety assertions stay strict.
	await frames(300)
	print("SETTLE pos=",robot.global_position," velocity=",robot.linear_velocity," state=",robot.reason)
	check(robot.settled_at(Vector2(100,0)),"actual rigid body brakes and stabilizes at work position")
	var target := wall(space,Vector2(170,0),Vector2(12,80))
	await frames(3)
	check(robot.aim_tool(Vector2(164,0),[target]),"authorized actual target collision shape permits tool ray")
	check(not robot.aim_tool(Vector2(100,-60),[target]),"nonempty authorization cannot fire into empty space without hitting its target")
	check(not robot.aim_tool(Vector2(174,0),[target]),"target authorization cannot shoot through its near surface to its far side")
	var blocker := wall(space,Vector2(135,0),Vector2(10,80))
	await frames(3)
	check(not robot.aim_tool(Vector2(164,0),[target]) and not robot.beam_on,"a real intervening wall stops the tool")
	blocker.get_parent().queue_free()
	await frames(4)
	check(robot.aim_tool(Vector2(164,0),[target]),"removing the real obstacle restores line of sight")
	var shared_wall := CollisionShape2D.new()
	var shared_shape := RectangleShape2D.new()
	shared_shape.size = Vector2(10,80)
	shared_wall.shape = shared_shape
	shared_wall.position = Vector2(-35,0)
	target.get_parent().add_child(shared_wall)
	await frames(3)
	check(not robot.aim_tool(Vector2(164,0),[target]),"a different shape on the SAME ship collider still blocks the beam")
	shared_wall.queue_free()
	await frames(4)
	check(robot.aim_tool(Vector2(164,0),[target]),"only the authorized shape is permitted after shared-collider obstruction clears")
	var context := PauseContext.new()
	robot.game = context
	context.paused_sim = true
	check(not robot.aim_tool(Vector2(164,0),[target]),"simulation pause blocks fresh tool authorization")
	context.paused_sim = false
	context.auto_paused = true
	check(not robot.aim_tool(Vector2(164,0),[target]),"automation pause also blocks fresh tool authorization")
	context.auto_paused = false
	context.state = "ended"
	check(not robot.aim_tool(Vector2(164,0),[target]),"settled contract cannot reignite the tool")
	robot.game = null
	check(not robot.aim_tool(Vector2(400,0),[target]),"tool cannot reach a distant target")
	check(not robot.aim_tool(Vector2(164,0),[]),"missing target authorization never permits firing")
	robot.aim_tool(Vector2(164,0),[target])
	await frames(3)
	check(not robot.beam_on,"fire authorization expires instead of persisting unchecked")
	robot.move_to(Vector2(240,0))
	await frames(180)
	check(robot.global_position.x < 151.0 and robot.reason == "route_blocked","full body collision prevents crossing a sealed wall")
	robot.stop()
	check(not robot.commanded and not robot.beam_on,"cancellation immediately revokes travel and tool commands")
	check(not robot.aim_tool(Vector2(164,0),[target]),"a cancelled machine cannot reignite without a new movement/work command")
	var saved: Dictionary = robot.save_state()
	var restored = load("res://scripts/cutter_drone.gd").new()
	space.add_child(restored)
	restored.load_state(saved)
	check(restored.global_position.distance_to(robot.global_position) < 0.001 and not restored.commanded and not restored.beam_on,"machine snapshot restores location with motion and ignition disabled")
	space.queue_free()
	await frames(5)
	print("G4 CUTTER BODY FIXTURE: %d checks, %d failures; no whole-ship verdict" % [checks,failures])
	quit(1 if failures else 0)
