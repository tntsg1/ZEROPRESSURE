extends SceneTree
# 2026-11-05 图鉴示意图总览：全部条目的 draw_art 缩略图（编号 + 名字），每页 117 张，存成
# tests/out/codex_sheet_<页>.png，用来逐条找画得别扭的。时间固定在 t = 1.3 s（动画的一个中间帧）。
#   tools/run_test.sh tests/codex_sheet_shot.gd

const Cap = preload("res://tests/cap.gd")
const COLS := 13
const ROWS := 9


class Sheet extends Control:
	var ids: Array = []
	var font: Font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.017, 0.02))
		var cw := size.x / COLS
		var ch := size.y / ROWS
		for i in ids.size():
			var id: String = ids[i]
			var cell := Rect2(Vector2((i % COLS) * cw, (i / COLS) * ch), Vector2(cw, ch))
			var box := Rect2(cell.position + Vector2(8, 6), Vector2(cw - 16, ch - 30))
			CodexHud.draw_art(self, id, box, font, 1.0, 1.3)
			UI.text(self, font, CodexFx.code(id) + " " + Codex.title(id), cell.position + Vector2(8, ch - 9), 11, Pal.ink(0.75))
			draw_rect(Rect2(cell.position + Vector2(cw - 14, ch - 18), Vector2(3, 3)), Pal.heat(1.0, 1.2) if CodexFx.level(id) >= 3 else Color(0, 0, 0, 0))


var sheet: Sheet
var page := 0
var frame := 0


func _initialize() -> void:
	Txt.zh = true
	root.add_child(preload("res://tests/test_window.gd").new())
	sheet = Sheet.new()
	sheet.font = Fonts.get_font("Regular")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	_show(0)


func _show(p: int) -> void:
	page = p
	var all: Array = CodexData.E.keys()
	sheet.ids = all.slice(p * COLS * ROWS, (p + 1) * COLS * ROWS)
	sheet.queue_redraw()


func _process(_dt: float) -> bool:
	frame += 1
	if frame % 20 == 0:
		Cap.save(root, "res://tests/out/codex_sheet_%d.png" % (page + 1))
		if (page + 1) * COLS * ROWS >= CodexData.E.size():
			print("CODEX SHEET %d pages" % (page + 1))
			return true
		_show(page + 1)
	return false
