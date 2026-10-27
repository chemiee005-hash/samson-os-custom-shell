extends CanvasLayer
class_name GameUI
## UI.gd  (attach to: UI (CanvasLayer) in UI.tscn)
##
## Labels are refreshed in _process() (non-physics). Buttons are wired with .connect() and
## forward to custom signals that GameManager listens to (signals = interrupts).

signal restart_requested
signal resume_requested

@onready var score_p1: Label = $ScoreP1
@onready var score_p2: Label = $ScoreP2
@onready var message: Label = $Message
@onready var debug_label: Label = $DebugLabel
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/Buttons/ResumeButton
@onready var restart_button: Button = $PauseMenu/Buttons/RestartButton
@onready var game_manager: Node = $"../GameManager"

var _flash_text := ""
var _flash_left := 0.0


func _ready() -> void:
	# UI "Restart" button -> programmatic .connect() (TASK 4)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	game_manager.paused_changed.connect(_on_paused_changed)
	game_manager.point_scored.connect(_on_point_scored)


func _process(delta: float) -> void:
	score_p1.text = str(game_manager.scores[1])
	score_p2.text = str(game_manager.scores[2])

	if _flash_left > 0.0:
		_flash_left -= delta

	match game_manager.state:
		GameManager.State.WAITING_SERVE:
			message.text = "Press SPACE to serve"
		GameManager.State.MATCH_OVER:
			message.text = "Player %d wins!\nPress SPACE for rematch" % game_manager.winner_id
		_:
			message.text = _flash_text if _flash_left > 0.0 else ""

	debug_label.text = "FPS %d | nodes %d | balls %d | power-ups %d" % [
		Engine.get_frames_per_second(),
		get_tree().get_node_count(),
		get_tree().get_nodes_in_group("balls").size(),
		get_tree().get_nodes_in_group("powerups").size()]


func _on_point_scored(player_id: int, _s1: int, _s2: int) -> void:
	_flash_text = "Player %d scores!" % player_id
	_flash_left = 1.0


func _on_paused_changed(is_paused: bool) -> void:
	pause_menu.visible = is_paused


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()
