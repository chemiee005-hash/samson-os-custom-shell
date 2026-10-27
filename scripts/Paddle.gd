extends CharacterBody2D
class_name Paddle
## Paddle.gd  (attach to: Paddle (CharacterBody2D) in Paddle.tscn)
##
## TASK 2 - Game loop separation
##   _physics_process(delta) -> movement + collision (fixed timestep, in sync with physics engine)
##   _process(delta)         -> timers, visuals, cooldowns (runs once per rendered frame)
##
## TASK 5 - Input
##   POLLING       : Input.get_axis() in _physics_process -> "what is held RIGHT NOW?" Continuous
##                   movement needs a fresh answer every physics tick, so we poll.
##   EVENT-DRIVEN  : _unhandled_input() for the discrete "boost" button press -> we only want to
##                   react ONCE when the key goes down, not ask every frame whether it is down.

@export var player_id: int = 1
@export var move_speed: float = 480.0
@export var boost_multiplier: float = 1.9
@export var boost_duration: float = 0.25
@export var boost_cooldown: float = 1.5

const BASE_HALF_HEIGHT := 50.0   # must match the RectangleShape2D (16 x 100) in Paddle.tscn
const HALF_WIDTH := 8.0

var up_action := ""
var down_action := ""
var boost_action := ""

var _boost_time_left := 0.0
var _boost_cooldown_left := 0.0
var _size_time_left := 0.0
var _target_scale_y := 1.0
var _base_color := Color.WHITE
var _start_y := 324.0


func _ready() -> void:
	add_to_group("paddles")
	# Player 1 -> p1_up / p1_down / p1_boost ; Player 2 -> p2_up / p2_down / p2_boost
	up_action = "p%d_up" % player_id
	down_action = "p%d_down" % player_id
	boost_action = "p%d_boost" % player_id
	_base_color = Color(0.4, 0.9, 1.0) if player_id == 1 else Color(1.0, 0.65, 0.3)
	modulate = _base_color
	_start_y = get_viewport_rect().size.y * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-HALF_WIDTH, -BASE_HALF_HEIGHT, HALF_WIDTH * 2.0, BASE_HALF_HEIGHT * 2.0), Color.WHITE)


# ---------------------------------------------------------------------------
# PHYSICS LOOP  (fixed timestep) - movement + collision-related logic
# ---------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	# INPUT STYLE #1: POLLING. Asked every physics tick: "how far is the stick/keys held?"
	var axis := Input.get_axis(up_action, down_action)   # -1 (up) .. +1 (down)

	# Movement belongs in _physics_process so it is frame-rate independent and stays
	# synchronized with the ball's collision checks.
	var speed := move_speed * (boost_multiplier if _boost_time_left > 0.0 else 1.0)
	velocity = Vector2(0.0, axis * speed)
	move_and_slide()

	# Keep the paddle on the table.
	var half_h := get_half_height()
	position.y = clampf(position.y, half_h, get_viewport_rect().size.y - half_h)


# ---------------------------------------------------------------------------
# GAME LOOP (per-frame) - NON-physics logic: timers, cooldowns, visuals
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Timers/cooldowns are plain bookkeeping -> _process (physics reads the result next tick).
	_boost_time_left = maxf(_boost_time_left - delta, 0.0)
	_boost_cooldown_left = maxf(_boost_cooldown_left - delta, 0.0)

	if _size_time_left > 0.0:
		_size_time_left -= delta
		if _size_time_left <= 0.0:
			_target_scale_y = 1.0   # power-up expired

	# Smoothly animate toward the target size (visual polish).
	scale.y = lerpf(scale.y, _target_scale_y, minf(10.0 * delta, 1.0))

	# Visual feedback while boosting.
	modulate = _base_color.lerp(Color.WHITE, 0.6) if _boost_time_left > 0.0 else _base_color


# ---------------------------------------------------------------------------
# INPUT STYLE #2: EVENT-DRIVEN. Called by the engine only when an input event occurs.
# Perfect for one-shot actions: we react to the key-DOWN edge exactly once.
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(boost_action) and _boost_cooldown_left <= 0.0:
		_boost_time_left = boost_duration
		_boost_cooldown_left = boost_cooldown


# ---------------------------------------------------------------------------
# Public API (called by GameManager)
# ---------------------------------------------------------------------------
func get_half_height() -> float:
	return BASE_HALF_HEIGHT * scale.y


## factor > 1 grows the paddle, factor < 1 shrinks it. Only sets targets; _process applies them
## (this can be called from a physics callback, so we avoid touching the body directly).
func apply_size_effect(factor: float, duration: float) -> void:
	_target_scale_y = factor
	_size_time_left = duration


func reset_paddle() -> void:
	position.y = _start_y
	scale.y = 1.0
	_target_scale_y = 1.0
	_size_time_left = 0.0
	_boost_time_left = 0.0
	_boost_cooldown_left = 0.0
