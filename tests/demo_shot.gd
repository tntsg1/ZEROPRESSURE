extends SceneTree
# Stills of the playtest build: the activation gate over the title and the end card.
# Writes tests/out/demo_gate.png, demo_end.png. Uses its own files and no network.
#   tools/run_test.sh tests/demo_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const Gt = preload("res://scripts/demo.gd")


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Gt.forced = true
	Gt.apply()
	Txt.zh = true
	var gate = preload("res://scripts/demo_gate.gd").new()
	root.add_child(gate)
	await _frames(5)
	gate._show("code", "")
	gate.code_in.text = "ZP-"
	await _frames(20)
	Cap.save(root, "res://tests/out/demo_gate.png")
	gate.queue_free()
	await _frames(3)
	var card = preload("res://scripts/demo_end.gd").new()
	root.add_child(card)
	await _frames(20)
	card.liked.text = "第一次把绞车整件送进回收口"
	await _frames(10)
	Cap.save(root, "res://tests/out/demo_end.png")
	paused = false
	quit()
