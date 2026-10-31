extends SceneTree
# The prologue's first card, for reading the author's longer lines in place: tests/out/prologue_card.png
#   tools/run_test.sh tests/prologue_card_shot.gd --fixed-fps 60

var g


func _initialize() -> void:
	Career.path = "user://zp_test_prologue_shot_career.json"
	SaveGame.path = "user://zp_test_prologue_shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.term_open = {}
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 240:
		await process_frame
	var p = g.prologue
	print("step ", p.STEPS[p.step], " title w ", p.title.size.x, " | ", p.count.text, " | ", p.title.text)
	preload("res://tests/cap.gd").save(root, "res://tests/out/prologue_card.png")
	quit()
