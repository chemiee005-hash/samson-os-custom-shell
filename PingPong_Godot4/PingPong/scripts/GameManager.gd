extends Node
class_name GameManager
## GameManager.gd  (attach to: GameManager (Node) in Main.tscn)
##
## Owns match state, score, serve, pause, power-up effects.
##
## TASK 4 - Signals as interrupts
##   * CUSTOM signals declared below with the `signal` keyword.
##   * Goal Area2D.body_entered is connected IN CODE with .connect() in _ready().
##   A signal works like a hardware interrupt: GameManager does NOT poll "did the ball reach the goal?"
##   every frame. The physics engine "interrupts" us by calling _on_goal_body_entered() exactly when the
##   event happens, and we sleep the rest of the time.
##
## TASK 5 - Input
##   Event-driven: Esc (pause), Space (serve / rematch), M (extra multiball) in _unhandled_input().
##   They are single discrete presses -> we only want a callback at the moment of the press.
##
## TASK 2 - Game loop
##   _process(): power-up spawn timer, debug timer (non-physics). No physics work in here.

# --- TASK 4: custom signals -------------------------------------------------
signal point_scored(player_id: int, score_p1: int, score_p2: int)
signal match_over(winner_id: int)
signal paused_changed(is_paused: bool)
signal state_changed(new_state: int)

enum State { WAITING_SERVE, PLAYING, ROUND_RESET, MATCH_OVER }

@export var win_score: int = 5
@export var multiball_mode: bool = true          # serve = 1 main ball + 2 extra = 3 balls in play
@export var powerup_interval: float = 5.0
@export var max_powerups: int = 3
@export var debug_interval: float = 2.0

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

# Fallback so the game works even before you add the actions in Project Settings.
# (Anything you already defined in the Input Map is left untouched.)
const DEFAULT_ACTIONS := {
	"p1_up": [KEY_W],
	"p1_down": [KEY_S],
	"p1_boost": [KEY_D],
	"p2_up": [KEY_UP],
	"p2_down": [KEY_DOWN],
	"p2_boost": [KEY_LEFT],
	"serve": [KEY_SPACE],
	"pause": [KEY_ESCAPE],
	"multiball": [KEY_M],
}

var state: State = State.WAITING_SERVE
var scores := {1: 0, 2: 0}
var winner_id := 0
var main_ball: Ball = null

var _serve_dir := 1.0
var _powerup_timer := 3.0
var _debug_timer := 0.0

@onready var spawner: BallSpawner = $"../BallSpawner"
@onready var paddle1: Paddle = $"../Paddle1"
@onready var paddle2: Paddle = $"../Paddle2"
@onready var goal_left: Area2D = $"../GoalLeft"
@onready var goal_right: Area2D = $"../GoalRight"
@onready var ui: GameUI = $"../UI"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # must still receive the Esc key while paused
	_ensure_input_actions()

	# --- TASK 4: programmatic connections with .connect() ----------------------------------
	# Left goal = ball got past Player 1 -> Player 2 scores. Right goal -> Player 1 scores.
	# .bind(player) appends an extra argument to the callback.
	goal_left.body_entered.connect(_on_goal_body_entered.bind(2))
	goal_right.body_entered.connect(_on_goal_body_entered.bind(1))
	spawner.powerup_collected.connect(_on_powerup_collected)   # custom signal from BallSpawner
	ui.restart_requested.connect(request_rematch)               # UI button "pressed" -> custom signal
	ui.resume_requested.connect(func() -> void: set_paused(false))

	_prepare_round()


# ---------------------------------------------------------------------------
# INPUT STYLE #2: EVENT-DRIVEN (discrete actions)
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("serve"):
		if state == State.WAITING_SERVE and not get_tree().paused:
			serve()
		elif state == State.MATCH_OVER:
			request_rematch()
	elif event.is_action_pressed("multiball"):
		if state == State.PLAYING and not get_tree().paused:
			spawner.spawn_multiball(3)


# ---------------------------------------------------------------------------
# GAME LOOP (non-physics): timers + debug output
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if get_tree().paused:
		return

	if state == State.PLAYING:
		_powerup_timer -= delta
		if _powerup_timer <= 0.0:
			_powerup_timer = powerup_interval
			if get_tree().get_nodes_in_group("powerups").size() < max_powerups:
				spawner.spawn_powerup(spawner.random_table_position())

	# TASK 6 DEBUG SNIPPET: watch this in the Output panel. When balls/power-ups are freed
	# the node count drops; it must NOT keep growing over time.
	_debug_timer += delta
	if _debug_timer >= debug_interval:
		_debug_timer = 0.0
		print_debug_counts()


func print_debug_counts() -> void:
	print("[Debug] total nodes=%d | balls=%d | powerups=%d" % [
		get_tree().get_node_count(),
		get_tree().get_nodes_in_group("balls").size(),
		get_tree().get_nodes_in_group("powerups").size()])


# ---------------------------------------------------------------------------
# Round flow
# ---------------------------------------------------------------------------
func _prepare_round() -> void:
	spawner.clear_all()                         # TASK 6: old instances are queue_free()'d
	paddle1.reset_paddle()
	paddle2.reset_paddle()
	main_ball = spawner.spawn_ball(spawner.arena_center(), false)   # waits at centre until served
	_powerup_timer = 3.0
	_set_state(State.WAITING_SERVE)


func serve() -> void:
	if not is_instance_valid(main_ball):
		return
	_set_state(State.PLAYING)
	main_ball.launch(Vector2(_serve_dir, randf_range(-0.4, 0.4)))
	if multiball_mode:
		spawner.spawn_multiball(2)              # main + 2 extras = 3 Ball instances alive


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)


func set_paused(value: bool) -> void:
	if state == State.ROUND_RESET or LevelManager.is_busy():
		return
	get_tree().paused = value
	paused_changed.emit(value)


func request_rematch() -> void:
	# TASK 3: threaded load + deferred scene swap -> no freeze.
	LevelManager.change_scene_threaded(MAIN_SCENE_PATH, "Starting rematch")


# ---------------------------------------------------------------------------
# TASK 4: signal handlers ("interrupt service routines")
# ---------------------------------------------------------------------------
func _on_goal_body_entered(body: Node2D, scoring_player: int) -> void:
	if state != State.PLAYING or not (body is Ball):
		return
	var ball := body as Ball

	scores[scoring_player] += 1
	point_scored.emit(scoring_player, scores[1], scores[2])   # custom signal -> UI etc. react

	if ball.is_extra:
		ball.despawn("scored in goal")          # TASK 6: extra ball is consumed -> queue_free()
		return

	# The MAIN ball scored: round is over.
	ball.stop()
	_serve_dir = 1.0 if scoring_player == 1 else -1.0   # serve toward the player who conceded
	if scores[scoring_player] >= win_score:
		winner_id = scoring_player
		_set_state(State.MATCH_OVER)
		match_over.emit(winner_id)
	else:
		_set_state(State.ROUND_RESET)
		LevelManager.round_transition(_prepare_round, "Next round")   # non-blocking


func _on_powerup_collected(type: int, player_id: int, pos: Vector2) -> void:
	var mine := paddle1 if player_id == 1 else paddle2
	var theirs := paddle2 if player_id == 1 else paddle1
	match type:
		PowerUp.Type.GROW_PADDLE:
			mine.apply_size_effect(1.6, 8.0)
		PowerUp.Type.SHRINK_OPPONENT:
			theirs.apply_size_effect(0.6, 8.0)
		PowerUp.Type.MULTIBALL:
			spawner.spawn_multiball(2, pos)


func _ensure_input_actions() -> void:
	for action in DEFAULT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEFAULT_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
