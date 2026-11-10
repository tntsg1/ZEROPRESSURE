extends SceneTree
# 128 号 第 7 段: where the ingots of the seg7 test career are (test save only)
func _initialize() -> void:
	Career.path = "user://zp_test_seg7_career.json"
	SaveGame.path = "user://zp_test_seg7_save.json"
	Career.load_or_new()
	print("raw_stock ", StoreBook.raw_stock())
	print("ingot_batches ", Career.data.get("ingot_batches", []).map(func(b): return [b.get("id"), b.get("mass_t"), b.get("state", "")]))
	print("store used ", StoreBook.used(), "/", StoreBook.cap(), " inbox ", StoreBook.inbox().size())
	var cats := {}
	for u in StoreBook.units():
		var k := str(u.get("cat", "?")) + "/" + str(u.get("name", ""))
		cats[k] = int(cats.get(k, 0)) + int(u.get("w", 1)) * int(u.get("h", 1))
	print("cells by kind ", cats)
	print("first_for_clients ", Guide.first_for_clients(), " exchange_usable ", StoreBook.exchange_usable())
	print("history ", Career.data.get("history", []).map(func(h): return [h.get("ship", ""), h.get("ingot_t", 0.0)]))
	quit(0)
