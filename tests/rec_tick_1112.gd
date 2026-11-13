extends Node
# Recording helper (2026-11-12 update video): counts written frames, prints "REC_T <frame>" every half
# second so the run's own prints can be placed on the timeline, and runs an optional per-frame hook.
var frame := 0
var follow: Callable = Callable()


func _ready() -> void:
	process_priority = -1000


func _process(_dt: float) -> void:
	frame += 1
	if frame % 30 == 0:
		print("REC_T %d" % frame)
	if follow.is_valid():
		follow.call()


func keep(on: bool, label := "") -> void:
	print("REC_KEEP %d %d %s" % [frame, 1 if on else 0, label])
