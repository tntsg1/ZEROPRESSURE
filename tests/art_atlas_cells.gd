extends "res://tests/art_atlas.gd"
# 零件图鉴 single cells (2026-11-11, the dedicated-drawing batches): renders only the named
# kinds, one cell per (name_key, the art its ship files give it) — the 图鉴's frozen key — so
# each existing cell can be swapped one for one without re-rendering the whole atlas. The
# drawing itself still goes through Art.draw (whatever BY_NAME now picks).
# tools/run_test.sh tests/art_atlas_cells.gd -- <out_dir> <name_key,name_key,...>

var only: PackedStringArray


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	only = a[1].split(",") if a.size() > 1 else PackedStringArray()
	super._initialize()


# group by the piece's own art, not the redrawn one (that is the 图鉴's key)
func _route(_nk: String, art: String) -> Array:
	return [art, "own"]


func _collect() -> void:
	super._collect()
	entries = entries.filter(func(e): return e.name_key in only)
