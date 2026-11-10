extends Node
# Recording helper for the 2026-11-10 videos (tests/record_1110_*.gd): counts the frames the
# Movie Maker writes and prints keep marks ("REC_KEEP <frame> 1|0") so tools/rec_1110.py can cut
# out the loading and set-up stretches. Test saves only; it changes nothing in the game.

var frame := 0
var follow: Callable = Callable()


func _ready() -> void:
	process_priority = -1000


func _process(_dt: float) -> void:
	frame += 1
	if follow.is_valid():
		follow.call()


func keep(on: bool, label := "") -> void:
	print("REC_KEEP %d %d %s" % [frame, 1 if on else 0, label])
