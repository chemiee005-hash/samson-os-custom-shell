extends Node
## LevelManager.gd  (AUTOLOAD singleton named "LevelManager" - registered in project.godot)
##
## TASK 3 - Keeping the main thread responsive
##
## Problem: if we load/reset a whole arena synchronously, the main thread stalls and the window freezes.
## Solutions used here:
##   1) ResourceLoader.load_threaded_request(): the .tscn is read & parsed on a WORKER thread. We poll
##      progress in _process() (a cheap check per frame) and keep rendering a loading indicator.
##   2) call_deferred(): the actual scene swap / round reset runs at a safe point at the end of the frame
##      (never in the middle of physics callbacks), and fades are done with await + Tween, which yield
##      back to the engine instead of blocking.
##
## This node is an autoload so it survives scene changes (the overlay stays on screen while Main.tscn
## is replaced).

signal transition_started
signal transition_finished
signal load_progress_changed(progress: float)

const FADE_TIME := 0.25

var busy := false

var _layer: CanvasLayer
var _root: Control
var _label: Label
var _bar: ProgressBar
var _status_text := "Loading"

var _loading := false
var _loading_path := ""
var _progress: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the game is paused
	_build_overlay()


func is_busy() -> bool:
	return busy


# ---------------------------------------------------------------------------
# Simple LOADING / TRANSITION INDICATOR (built in code so it is a drop-in file)
# ---------------------------------------------------------------------------
func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_root = Control.new()
	_root.visible = false
	_layer.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	center.add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(300, 16)
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.visible = false
	box.add_child(_bar)


func _fade(target_alpha: float) -> void:
	_root.visible = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", target_alpha, FADE_TIME)
	await tw.finished          # await yields to the engine -> NOT a blocking wait
	if target_alpha <= 0.0:
		_root.visible = false


# ---------------------------------------------------------------------------
# Round reset: fade out -> run `mid_action` (deferred) -> fade in. Game never freezes.
# ---------------------------------------------------------------------------
func round_transition(mid_action: Callable, text: String = "Next round") -> void:
	if busy:
		return
	busy = true
	_status_text = text
	_bar.visible = false
	transition_started.emit()

	_root.modulate.a = 0.0
	await _fade(1.0)

	mid_action.call_deferred()                 # safe point: end of the current frame
	await get_tree().process_frame
	await get_tree().process_frame             # make sure the deferred call has run
	await get_tree().create_timer(0.25).timeout

	await _fade(0.0)
	busy = false
	transition_finished.emit()


# ---------------------------------------------------------------------------
# Scene (re)load for rematches / arena changes - threaded
# ---------------------------------------------------------------------------
func change_scene_threaded(path: String, text: String = "Loading") -> void:
	if busy:
		return
	busy = true
	get_tree().paused = false
	_status_text = text
	_bar.value = 0.0
	_bar.visible = true
	transition_started.emit()

	_root.modulate.a = 0.0
	await _fade(1.0)

	var err := ResourceLoader.load_threaded_request(path)   # starts loading on a worker thread
	if err != OK:
		push_error("LevelManager: could not start loading %s (error %d)" % [path, err])
		await _fade(0.0)
		busy = false
		return
	_loading_path = path
	_loading = true            # _process() now polls the loader each frame


func _process(_delta: float) -> void:
	# Animated "Loading..." dots (non-physics, per-frame UI work).
	if _root.visible:
		_label.text = _status_text + ".".repeat(int(Time.get_ticks_msec() / 300.0) % 4)

	if not _loading:
		return

	# Cheap non-blocking poll of the worker thread.
	var status := ResourceLoader.load_threaded_get_status(_loading_path, _progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _progress.size() > 0:
				_bar.value = _progress[0] * 100.0
				load_progress_changed.emit(_progress[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading = false
			_bar.value = 100.0
			var packed := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
			_finish_scene_change(packed)
		_:   # FAILED or INVALID_RESOURCE
			_loading = false
			push_error("LevelManager: threaded load failed for %s" % _loading_path)
			_finish_scene_change(null)


func _finish_scene_change(packed: PackedScene) -> void:
	if packed:
		# call_deferred: swap scenes at the end of the frame, not inside this _process call.
		get_tree().call_deferred("change_scene_to_packed", packed)
		await get_tree().process_frame
		await get_tree().process_frame
	await _fade(0.0)
	busy = false
	transition_finished.emit()
