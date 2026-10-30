extends SceneTree
# Render the same existing machinery in physically simulated manual states.
# These are model/render fixtures, not a player-operated production line.
const Furnace = preload("res://scripts/smelter.gd")
const Cap = preload("res://tests/cap.gd")
const Batch = preload("res://scripts/canvas_batch.gd")
var f = Furnace.new(false)
var renderer: Node2D
func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func tick(seconds: float) -> void:
	for i in int(seconds*120.0): f.step(1.0/120.0)
func shot(label: String) -> void:
	renderer.queue_redraw()
	await frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/g5_manual_"+label+".png")
	print("RENDER ",label," T=",f.T," liquid=",f.m_l," probe=",f.dip," tilt=",f.tilt)
func run() -> void:
	Txt.zh = true
	renderer = Node2D.new()
	renderer.position = Vector2(300,30)
	root.add_child(renderer)
	f.X = 0.0
	f.begin_manual()
	renderer.draw.connect(func():
		var batch := Batch.new(renderer)
		f.draw(batch,0.0,0.0,Fonts.get_font("Regular"),Fonts.get_font("Medium"),1.0,Txt.t)
		batch.flush())
	await shot("cold")
	f.manual_charge(3.0)
	f.manual_command("feed",1.0)
	f.manual_command("power",1.0)
	for second in 600:
		tick(1.0)
		if f.T > 1680.0 and f.m_l > 2.99999: break
	await shot("hot")
	if not f.manual_command("sample").ok: quit(1);return
	tick(2.0)
	await shot("probe")
	tick(3.0)
	if not f.manual_command("tap").ok: quit(1);return
	tick(10.0)
	await shot("pour")
	print("G5 MANUAL FURNACE RENDER PASS")
	renderer.queue_free()
	await frames(5)
	quit(0)
