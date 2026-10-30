extends SceneTree
# one-off: the user's slot-3 career (copied to a test path) — what does play_career load?
func _initialize() -> void:
	Career.path = "user://zp_test_pod_career.json"
	SaveGame.path = "user://zp_test_pod_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Career.load_or_new()
	print("active: ", Career.active().get("id", ""), " ship ", Career.active().get("ship", ""))
	print("sign_active: ", str(Career.sign_active()).substr(0, 160))
	var saved := SaveGame.read(SaveGame.path) if SaveGame.exists() else {}
	print("berth save job: ", str(saved.get("job", {})).substr(0, 120), " ship ", saved.get("ship", ""))
	Game.play_career(self)
	for i in 120:
		await process_frame
	var g = root.get_node_or_null("Main")
	if g == null:
		for c in root.get_children():
			if c.get("ship_id") != null:
				g = c
	print("scene: ", current_scene.name if current_scene != null else "?", " ship_id ", g.get("ship_id") if g != null else "?", " in_berth ", g.in_berth() if g != null else "?", " state ", g.get("state") if g != null else "?")
	for i in 600:
		await process_frame
	print("after 10 s: state ", g.get("state") if g != null else "?", " in_berth ", g.in_berth() if g != null else "?")
	quit()
