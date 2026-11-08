extends "res://tests/berth_layout_check.gd"
# 方案 A before / after: a berth (50 m unless a number is given after --) in the 0-key panorama, the old way (Dock.DROP_ON false: out sideways
# under the cargo district) and the new (hung under the port on its bridge), side by side. Own test saves.
#   tools/run_test.sh tests/berth_compare_shot.gd --fixed-fps 60

func _run() -> void:
	var tier := 50.0
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			tier = float(a)
	var shots: Array = []
	for on in [false, true]:
		Dock.DROP_ON = on
		await _layout(tier)
		g.port_view = true
		_ui(false)
		for i in 90:
			await _frames(1)
		shots.append(_grab())
		g.port_view = false
	Dock.DROP_ON = true
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var out := Image.create(w * 2 + 24, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.04, 0.045, 0.05))
	out.blit_rect(shots[0], Rect2i(0, 0, w, h), Vector2i(0, 0))
	out.blit_rect(shots[1], Rect2i(0, 0, w, h), Vector2i(w + 24, 0))
	out.save_png(ProjectSettings.globalize_path("res://tests/out/berth_layout_before_after_%d.png" % int(tier)))
	g.queue_free()
	await _frames(4)
	quit()
