extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := Sfx.new()
	root.add_child(s)
	var failures: Array[String] = []
	for file in ResourceLoader.list_directory("res://assets/audio"):
		if not file.ends_with(".ogg"):
			continue
		var cue := file.get_basename()
		var folder := "audio_trial" if cue in ["swallow_equip", "wrench"] else "audio"
		var expected := "res://assets/%s/%s" % [folder, file]
		var stream: AudioStream = s.streams.get(cue)
		if stream == null or stream.resource_path != expected:
			failures.append(cue)
	for cue in s.streams:
		var stream: AudioStream = s.streams[cue]
		if stream.resource_path.begins_with("res://assets/audio_trial/") and cue not in ["swallow_equip", "wrench"]:
			failures.append(cue)
	for cue in ["swallow_equip", "wrench"]:
		var stream: AudioStream = s.streams.get(cue)
		if stream == null or stream.resource_path != "res://assets/audio_trial/%s.ogg" % cue:
			failures.append(cue)
	if s._equip_variants.size() != 2:
		failures.append("swallow_equip variants")
	var button := Button.new()
	root.add_child(button)
	button.pressed.emit()
	await process_frame
	if s.last_play.has("menu"):
		failures.append("automatic button sound")
	print("AUDIO ROLLBACK ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
