extends Node
# a steady leak for the perf probe: four globules a frame from a few holes round the hull
var g
var k := 0
func _process(_dt: float) -> void:
	if g == null or g.liquids == null:
		return
	k += 1
	var at := Vector2((16.0 + (k % 5) * 3.0) * Geom.M, (-6.0 + (k % 3) * 2.0) * Geom.M)
	g.liquids.spill(at, Vector2.from_angle(k * 0.7), 0.004, "water", 4, PI, 1.5, false)
