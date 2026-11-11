extends SceneTree
# 2026-11-10 外观款式：每款画一架的 CPU 时间（录制绘制命令）对比原版 H1。
# 每款每帧画 200 架、跑 60 帧取中位数；游戏里每帧只画 1 架，所以看的是相对原版的倍数。
#   tools/run_test.sh tests/drone_skins_bench.gd --fixed-fps 60
const Skins = preload("res://scripts/drone_skins.gd")
const Art = preload("res://scripts/drone_art.gd")
const N := 200
var node: Node2D
var cur := ""
var samples := {}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	node = Node2D.new()
	node.draw.connect(_draw)
	root.add_child(node)
	_run.call_deferred()


func _draw() -> void:
	if cur == "":
		return
	var t0 := Time.get_ticks_usec()
	Art.set_scale(2.4)
	for i in N:
		var xf := Transform2D(0.0, Vector2(2.4, 2.4), 0.0, Vector2(100 + (i % 20) * 85, 100 + (i / 20) * 90))
		node.draw_set_transform_matrix(xf)
		Skins.draw(node, cur, {"heading": i * 0.03, "tool": 3, "open": 0.8, "t": i * 0.016, "thrust": Vector2(0.8, 0.3), "dash": false, "boot": 1.0, "base_xf": xf})
	node.draw_set_transform_matrix(Transform2D.IDENTITY)
	Art.lite = false
	samples[cur].append(Time.get_ticks_usec() - t0)


func _run() -> void:
	for id in Skins.ORDER:
		cur = id
		samples[id] = []
		for f in 60:
			node.queue_redraw()
			await process_frame
	cur = ""
	var base := 0.0
	for id in Skins.ORDER:
		var s: Array = samples[id]
		s.sort()
		var med := float(s[s.size() / 2]) / N
		if id == "arrowring":
			base = med
		print("BENCH %-10s %6.1f us/drone  x%.2f of H1" % [id, med, med / maxf(base, 0.001)])
	quit()
