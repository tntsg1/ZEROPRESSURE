extends "res://tests/perf_stress_check.gd"
# 工业剖面 rollout: the same 87-7 stress scene (250 loose pieces, the field grapple, 30 lines
# whipping, ARK-01) with the OLD line picture (Pal.solid off), to compare against
# tests/perf_stress_check.gd run with the new picture (the default). Own test saves only.
#   tools/run_test.sh tests/perf_stress_old_look.gd --fixed-fps 60


func _initialize() -> void:
	Pal.solid = false
	super._initialize()
